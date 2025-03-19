-- Benchmarking module for firmo
-- Provides utilities for measuring and analyzing test performance

local benchmark = {}
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack_table = table.unpack or unpack

-- Initialize module logger
local logger = logging.get_logger("benchmark")
logging.configure_from_config("benchmark")

-- Default configuration
benchmark.options = {
  iterations = 5, -- Default iterations for each benchmark
  warmup = 1, -- Warmup iterations
  precision = 6, -- Decimal precision for times
  report_memory = true, -- Report memory usage
  report_stats = true, -- Report statistical information
  gc_before = true, -- Force GC before benchmarks
  include_warmup = false, -- Include warmup iterations in results
}

-- Return high-resolution time (with nanosecond precision if available)
local has_socket, socket = pcall(require, "socket")
---@diagnostic disable-next-line: unused-local
local has_ffi, ffi = pcall(require, "ffi")

local function high_res_time()
  ---@diagnostic disable-next-line: unused-local
  local success, time, err = error_handler.try(function()
    if has_socket then
      return socket.gettime()
    elseif has_ffi then
      -- Use os.clock() as a fallback
      return os.clock()
    else
      -- If neither is available, use os.time() (low precision)
      return os.time()
    end
  end)

  if not success then
    logger.warn("Failed to get high-resolution time", {
      error = error_handler.format_error(time),
      fallback = "using os.time()",
    })
    return os.time()
  end

  return time
end

-- Format time value with proper units
local function format_time(time_seconds)
  -- Validate input
  error_handler.assert(
    type(time_seconds) == "number",
    "time_seconds must be a number",
    error_handler.CATEGORY.VALIDATION,
    { time_type = type(time_seconds), value = tostring(time_seconds) }
  )

  ---@diagnostic disable-next-line: unused-local
  local success, formatted, err = error_handler.try(function()
    if time_seconds < 0.000001 then
      return string.format("%.2f ns", time_seconds * 1e9)
    elseif time_seconds < 0.001 then
      return string.format("%.2f µs", time_seconds * 1e6)
    elseif time_seconds < 1 then
      return string.format("%.2f ms", time_seconds * 1e3)
    else
      return string.format("%.4f s", time_seconds)
    end
  end)

  if not success then
    logger.warn("Failed to format time", {
      error = error_handler.format_error(formatted),
      time_seconds = time_seconds,
      fallback = "using default format",
    })
    return string.format("%.4f s", time_seconds)
  end

  return formatted
end

-- Calculate stats from a set of measurements
local function calculate_stats(measurements)
  -- Validate input
  error_handler.assert(
    type(measurements) == "table",
    "measurements must be a table",
    error_handler.CATEGORY.VALIDATION,
    { measurements_type = type(measurements) }
  )

  error_handler.assert(
    #measurements > 0,
    "measurements table must not be empty",
    error_handler.CATEGORY.VALIDATION,
    { measurements_count = #measurements }
  )

  ---@diagnostic disable-next-line: unused-local
  local success, stats, err = error_handler.try(function()
    local sum = 0
    local min = math.huge
    local max = -math.huge

    for idx, time in ipairs(measurements) do
      error_handler.assert(
        type(time) == "number",
        "measurement value must be a number",
        error_handler.CATEGORY.VALIDATION,
        { index = idx, value_type = type(time), value = tostring(time) }
      )

      sum = sum + time
      min = math.min(min, time)
      max = math.max(max, time)
    end

    local mean = sum / #measurements

    -- Calculate standard deviation
    local variance = 0
    for _, time in ipairs(measurements) do
      variance = variance + (time - mean) ^ 2
    end
    variance = variance / #measurements
    local std_dev = math.sqrt(variance)

    return {
      mean = mean,
      min = min,
      max = max,
      std_dev = std_dev,
      count = #measurements,
      total = sum,
    }
  end)

  if not success then
    logger.error("Failed to calculate statistics", {
      error = error_handler.format_error(stats),
      measurements_count = #measurements,
    })

    -- Return safe fallback values
    return {
      mean = 0,
      min = 0,
      max = 0,
      std_dev = 0,
      count = #measurements,
      total = 0,
    }
  end

  return stats
end

-- Deep table clone helper
local function deep_clone(t)
  if type(t) ~= "table" then
    return t
  end

  ---@diagnostic disable-next-line: unused-local
  local success, copy, err = error_handler.try(function()
    local result = {}
    for k, v in pairs(t) do
      if type(v) == "table" then
        result[k] = deep_clone(v)
      else
        result[k] = v
      end
    end
    return result
  end)

  if not success then
    logger.warn("Failed to deep clone table", {
      error = error_handler.format_error(copy),
      table_type = type(t),
      fallback = "returning empty table",
    })
    return {} -- Return an empty table as fallback
  end

  return copy
end

-- Measure function execution time
function benchmark.measure(func, args, options)
  -- Validate required parameters
  error_handler.assert(
    func ~= nil,
    "benchmark.measure requires a function to benchmark",
    error_handler.CATEGORY.VALIDATION,
    { func_provided = func ~= nil }
  )

  error_handler.assert(
    type(func) == "function",
    "benchmark.measure requires a function to benchmark",
    error_handler.CATEGORY.VALIDATION,
    { func_type = type(func) }
  )

  -- Initialize options with defaults
  local process_options_success, processed_options = error_handler.try(function()
    options = options or {}

    return {
      iterations = options.iterations or benchmark.options.iterations,
      warmup = options.warmup or benchmark.options.warmup,
      gc_before = options.gc_before ~= nil and options.gc_before or benchmark.options.gc_before,
      include_warmup = options.include_warmup ~= nil and options.include_warmup or benchmark.options.include_warmup,
      label = options.label or "Benchmark",
    }
  end)

  if not process_options_success then
    logger.warn("Failed to process benchmark options", {
      error = error_handler.format_error(processed_options),
      fallback = "using default options",
    })

    -- Fallback to default options
    processed_options = {
      iterations = benchmark.options.iterations,
      warmup = benchmark.options.warmup,
      gc_before = benchmark.options.gc_before,
      include_warmup = benchmark.options.include_warmup,
      label = "Benchmark",
    }
  end

  local iterations = processed_options.iterations
  local warmup = processed_options.warmup
  local gc_before = processed_options.gc_before
  local include_warmup = processed_options.include_warmup
  local label = processed_options.label

  -- Clone arguments to ensure consistent state between runs
  local args_clone = args and deep_clone(args) or {}

  -- Prepare results container
  local results = {
    times = {},
    memory = {},
    label = label,
    iterations = iterations,
    warmup = warmup,
  }

  -- Log benchmark start
  logger.debug("Starting benchmark execution", {
    label = label,
    iterations = iterations,
    warmup = warmup,
    include_warmup = include_warmup,
    gc_before = gc_before,
  })

  -- Warmup phase
  for i = 1, warmup do
    if gc_before then
      error_handler.try(function()
        collectgarbage("collect")
      end)
    end

    -- Measure warmup execution
    local start_time = high_res_time()
    local start_memory = error_handler.try(function()
      return collectgarbage("count")
    end) or 0

    -- Execute function with arguments
    ---@diagnostic disable-next-line: unused-local
    local success, result, exec_err = error_handler.try(function()
      ---@diagnostic disable-next-line: param-type-mismatch
      return func(unpack_table(args_clone))
    end)

    if not success then
      logger.warn("Benchmark function execution failed during warmup", {
        error = error_handler.format_error(result),
        label = label,
        iteration = i,
        warmup = true,
      })
    end

    local end_time = high_res_time()
    local end_memory = error_handler.try(function()
      return collectgarbage("count")
    end) or start_memory

    -- Store results if including warmup
    if include_warmup then
      table.insert(results.times, end_time - start_time)
      table.insert(results.memory, end_memory - start_memory)
    end
  end

  -- Main benchmark phase
  for i = 1, iterations do
    if gc_before then
      error_handler.try(function()
        collectgarbage("collect")
      end)
    end

    -- Measure execution
    local start_time = high_res_time()
    local start_memory = error_handler.try(function()
      return collectgarbage("count")
    end) or 0

    -- Execute function with arguments
    ---@diagnostic disable-next-line: unused-local
    local success, result, exec_err = error_handler.try(function()
      ---@diagnostic disable-next-line: param-type-mismatch
      return func(unpack_table(args_clone))
    end)

    if not success then
      logger.warn("Benchmark function execution failed", {
        error = error_handler.format_error(result),
        label = label,
        iteration = i,
      })
    end

    local end_time = high_res_time()
    local end_memory = error_handler.try(function()
      return collectgarbage("count")
    end) or start_memory

    -- Store results
    table.insert(results.times, end_time - start_time)
    table.insert(results.memory, end_memory - start_memory)
  end

  -- Calculate statistics
  local time_stats_success, time_stats = error_handler.try(function()
    return calculate_stats(results.times)
  end)

  local memory_stats_success, memory_stats = error_handler.try(function()
    return calculate_stats(results.memory)
  end)

  results.time_stats = time_stats_success and time_stats
    or {
      mean = 0,
      min = 0,
      max = 0,
      std_dev = 0,
      count = #results.times,
      total = 0,
    }

  results.memory_stats = memory_stats_success and memory_stats
    or {
      mean = 0,
      min = 0,
      max = 0,
      std_dev = 0,
      count = #results.memory,
      total = 0,
    }

  logger.debug("Benchmark execution completed", {
    label = label,
    mean_time = results.time_stats.mean,
    mean_memory = results.memory_stats.mean,
  })

  return results
end

-- Run a suite of benchmarks
function benchmark.suite(suite_def, options)
  -- Validate required parameters
  error_handler.assert(
    suite_def ~= nil,
    "benchmark.suite requires a suite definition table",
    error_handler.CATEGORY.VALIDATION,
    { suite_def_provided = suite_def ~= nil }
  )

  error_handler.assert(
    type(suite_def) == "table",
    "suite_def must be a table",
    error_handler.CATEGORY.VALIDATION,
    { suite_def_type = type(suite_def) }
  )

  -- Process options and suite definition
  local success, config = error_handler.try(function()
    options = options or {}
    local suite_name = suite_def.name or "Benchmark Suite"
    local benchmarks = suite_def.benchmarks or {}

    error_handler.assert(
      type(benchmarks) == "table",
      "suite_def.benchmarks must be a table",
      error_handler.CATEGORY.VALIDATION,
      { benchmarks_type = type(benchmarks) }
    )

    return {
      options = options,
      suite_name = suite_name,
      benchmarks = benchmarks,
      quiet = options.quiet or false,
    }
  end)

  if not success then
    logger.error("Failed to process benchmark suite configuration", {
      error = error_handler.format_error(config),
      fallback = "using default values",
    })

    -- Fallback configuration
    config = {
      options = options or {},
      suite_name = "Benchmark Suite (Error Recovery)",
      benchmarks = {},
      quiet = false,
    }
  end

  -- Prepare results container
  local results = {
    name = config.suite_name,
    benchmarks = {},
    start_time = os.time(),
    options = deep_clone(config.options),
    errors = {},
  }

  -- Log suite start
  logger.info("Running benchmark suite", { name = config.suite_name })

  -- Print header for console output using safe output
  if not config.quiet then
    local io_success = error_handler.safe_io_operation(function()
      io.write("\n" .. string.rep("-", 80) .. "\n")
      io.write("Running benchmark suite: " .. config.suite_name .. "\n")
      io.write(string.rep("-", 80) .. "\n")
    end, "console", { operation = "write_header" })

    if not io_success then
      logger.warn("Failed to write benchmark header to console")
    end
  end

  -- Run each benchmark
  for idx, benchmark_def in ipairs(config.benchmarks) do
    local bench_success, bench_result = error_handler.try(function()
      -- Extract benchmark definition
      local name = (benchmark_def.name or "Benchmark #") .. idx

      error_handler.assert(
        benchmark_def.func ~= nil,
        "Benchmark function is required",
        error_handler.CATEGORY.VALIDATION,
        { benchmark_name = name }
      )

      error_handler.assert(
        type(benchmark_def.func) == "function",
        "Benchmark function must be a function",
        error_handler.CATEGORY.VALIDATION,
        { benchmark_name = name, func_type = type(benchmark_def.func) }
      )

      local func = benchmark_def.func
      local args = benchmark_def.args or {}

      -- Merge suite options with benchmark options
      local bench_options = deep_clone(config.options)
      for k, v in pairs(benchmark_def.options or {}) do
        bench_options[k] = v
      end
      bench_options.label = name

      -- Log benchmark start
      logger.debug("Running benchmark", { name = name, index = idx })

      -- Print to console if not quiet
      if not config.quiet then
        error_handler.safe_io_operation(function()
          io.write("\nRunning: " .. name .. "\n")
        end, "console", { operation = "write_benchmark_name", benchmark_name = name })
      end

      -- Execute the benchmark
      local benchmark_result = benchmark.measure(func, args, bench_options)
      table.insert(results.benchmarks, benchmark_result)

      -- Print results
      benchmark.print_result(benchmark_result, { quiet = config.quiet })

      return benchmark_result
    end)

    if not bench_success then
      logger.error("Failed to execute benchmark", {
        index = idx,
        error = error_handler.format_error(bench_result),
      })

      -- Record the error
      table.insert(results.errors, {
        index = idx,
        error = bench_result,
      })
    end
  end

  -- Complete the suite
  results.end_time = os.time()
  results.duration = results.end_time - results.start_time

  -- Log suite completion
  logger.info("Benchmark suite completed", {
    name = config.suite_name,
    duration_seconds = results.duration,
    benchmark_count = #results.benchmarks,
    error_count = #results.errors,
  })

  -- Print suite summary to console if not quiet
  if not config.quiet then
    error_handler.safe_io_operation(function()
      io.write("\n" .. string.rep("-", 80) .. "\n")
      io.write("Suite complete: " .. config.suite_name .. "\n")
      io.write("Total runtime: " .. results.duration .. " seconds\n")
      if #results.errors > 0 then
        io.write("Errors encountered: " .. #results.errors .. "\n")
      end
      io.write(string.rep("-", 80) .. "\n")
    end, "console", { operation = "write_summary" })
  end

  return results
end

-- Comparison function for benchmarks
function benchmark.compare(benchmark1, benchmark2, options)
  -- Validate required parameters
  error_handler.assert(
    benchmark1 ~= nil,
    "benchmark.compare requires two benchmark results to compare",
    error_handler.CATEGORY.VALIDATION,
    { benchmark1_provided = benchmark1 ~= nil }
  )

  error_handler.assert(
    benchmark2 ~= nil,
    "benchmark.compare requires two benchmark results to compare",
    error_handler.CATEGORY.VALIDATION,
    { benchmark2_provided = benchmark2 ~= nil }
  )

  -- Process options
  local success, config = error_handler.try(function()
    options = options or {}

    -- Validate benchmark objects
    error_handler.assert(
      type(benchmark1) == "table",
      "benchmark1 must be a benchmark result table",
      error_handler.CATEGORY.VALIDATION,
      { benchmark1_type = type(benchmark1) }
    )

    error_handler.assert(
      type(benchmark2) == "table",
      "benchmark2 must be a benchmark result table",
      error_handler.CATEGORY.VALIDATION,
      { benchmark2_type = type(benchmark2) }
    )

    error_handler.assert(
      type(benchmark1.time_stats) == "table",
      "benchmark1.time_stats must be a table",
      error_handler.CATEGORY.VALIDATION,
      { has_time_stats = type(benchmark1.time_stats) == "table" }
    )

    error_handler.assert(
      type(benchmark2.time_stats) == "table",
      "benchmark2.time_stats must be a table",
      error_handler.CATEGORY.VALIDATION,
      { has_time_stats = type(benchmark2.time_stats) == "table" }
    )

    error_handler.assert(
      type(benchmark1.memory_stats) == "table",
      "benchmark1.memory_stats must be a table",
      error_handler.CATEGORY.VALIDATION,
      { has_memory_stats = type(benchmark1.memory_stats) == "table" }
    )

    error_handler.assert(
      type(benchmark2.memory_stats) == "table",
      "benchmark2.memory_stats must be a table",
      error_handler.CATEGORY.VALIDATION,
      { has_memory_stats = type(benchmark2.memory_stats) == "table" }
    )

    return {
      options = options,
      benchmark1 = benchmark1,
      benchmark2 = benchmark2,
      label1 = benchmark1.label or "Benchmark 1",
      label2 = benchmark2.label or "Benchmark 2",
      silent = options.silent or false,
    }
  end)

  if not success then
    logger.error("Failed to process benchmark comparison parameters", {
      error = error_handler.format_error(config),
    })

    -- Return an error result
    return nil,
      error_handler.create(
        "Failed to process benchmark comparison parameters",
        error_handler.CATEGORY.VALIDATION,
        error_handler.SEVERITY.ERROR,
        { original_error = config }
      )
  end

  -- Calculate comparison
  local compare_success, comparison = error_handler.try(function()
    -- Ensure stats have mean values
    error_handler.assert(
      type(config.benchmark1.time_stats.mean) == "number",
      "benchmark1.time_stats.mean must be a number",
      error_handler.CATEGORY.VALIDATION,
      { mean_type = type(config.benchmark1.time_stats.mean) }
    )

    error_handler.assert(
      type(config.benchmark2.time_stats.mean) == "number",
      "benchmark2.time_stats.mean must be a number",
      error_handler.CATEGORY.VALIDATION,
      { mean_type = type(config.benchmark2.time_stats.mean) }
    )

    error_handler.assert(
      type(config.benchmark1.memory_stats.mean) == "number",
      "benchmark1.memory_stats.mean must be a number",
      error_handler.CATEGORY.VALIDATION,
      { mean_type = type(config.benchmark1.memory_stats.mean) }
    )

    error_handler.assert(
      type(config.benchmark2.memory_stats.mean) == "number",
      "benchmark2.memory_stats.mean must be a number",
      error_handler.CATEGORY.VALIDATION,
      { mean_type = type(config.benchmark2.memory_stats.mean) }
    )

    -- Avoid division by zero
    error_handler.assert(
      config.benchmark2.time_stats.mean ~= 0,
      "benchmark2.time_stats.mean cannot be zero",
      error_handler.CATEGORY.VALIDATION,
      { mean = config.benchmark2.time_stats.mean }
    )

    error_handler.assert(
      config.benchmark2.memory_stats.mean ~= 0,
      "benchmark2.memory_stats.mean cannot be zero",
      error_handler.CATEGORY.VALIDATION,
      { mean = config.benchmark2.memory_stats.mean }
    )

    local time_ratio = config.benchmark1.time_stats.mean / config.benchmark2.time_stats.mean
    local memory_ratio = config.benchmark1.memory_stats.mean / config.benchmark2.memory_stats.mean

    return {
      benchmarks = { config.benchmark1, config.benchmark2 },
      time_ratio = time_ratio,
      memory_ratio = memory_ratio,
      faster = time_ratio < 1 and config.label1 or config.label2,
      less_memory = memory_ratio < 1 and config.label1 or config.label2,
      time_percent = time_ratio < 1 and (1 - time_ratio) * 100 or (time_ratio - 1) * 100,
      memory_percent = memory_ratio < 1 and (1 - memory_ratio) * 100 or (memory_ratio - 1) * 100,
    }
  end)

  if not compare_success then
    logger.error("Failed to calculate benchmark comparison", {
      error = error_handler.format_error(comparison),
    })

    -- Return an error result
    return nil,
      error_handler.create(
        "Failed to calculate benchmark comparison",
        error_handler.CATEGORY.RUNTIME,
        error_handler.SEVERITY.ERROR,
        { original_error = comparison }
      )
  end

  -- Log comparison results
  logger.info("Benchmark comparison", {
    benchmark1 = config.label1,
    benchmark2 = config.label2,
    time_ratio = comparison.time_ratio,
    memory_ratio = comparison.memory_ratio,
    faster = comparison.faster,
    time_percent = comparison.time_percent,
    less_memory = comparison.less_memory,
    memory_percent = comparison.memory_percent,
  })

  -- Print comparison to console if not silent
  if not config.silent then
    error_handler.safe_io_operation(function()
      io.write("\n" .. string.rep("-", 80) .. "\n")
      io.write("Benchmark Comparison: " .. config.label1 .. " vs " .. config.label2 .. "\n")
      io.write(string.rep("-", 80) .. "\n")

      io.write("\nExecution Time:\n")
      io.write(string.format("  %s: %s\n", config.label1, format_time(config.benchmark1.time_stats.mean)))
      io.write(string.format("  %s: %s\n", config.label2, format_time(config.benchmark2.time_stats.mean)))
      io.write(string.format("  Ratio: %.2fx\n", comparison.time_ratio))
      io.write(
        string.format(
          "  %s is %.1f%% %s\n",
          comparison.faster,
          comparison.time_percent,
          comparison.time_ratio < 1 and "faster" or "slower"
        )
      )

      io.write("\nMemory Usage:\n")
      io.write(string.format("  %s: %.2f KB\n", config.label1, config.benchmark1.memory_stats.mean))
      io.write(string.format("  %s: %.2f KB\n", config.label2, config.benchmark2.memory_stats.mean))
      io.write(string.format("  Ratio: %.2fx\n", comparison.memory_ratio))
      io.write(
        string.format(
          "  %s uses %.1f%% %s memory\n",
          comparison.less_memory,
          comparison.memory_percent,
          comparison.memory_ratio < 1 and "less" or "more"
        )
      )

      io.write(string.rep("-", 80) .. "\n")
    end, "console", { operation = "write_comparison" })
  end

  return comparison
end

-- Print benchmark results
function benchmark.print_result(result, options)
  -- Validate required parameters
  error_handler.assert(
    result ~= nil,
    "benchmark.print_result requires a result table",
    error_handler.CATEGORY.VALIDATION,
    { result_provided = result ~= nil }
  )

  -- Process options and validate result
  local success, config = error_handler.try(function()
    options = options or {}

    error_handler.assert(
      type(result) == "table",
      "result must be a table",
      error_handler.CATEGORY.VALIDATION,
      { result_type = type(result) }
    )

    error_handler.assert(
      type(result.time_stats) == "table",
      "result.time_stats must be a table",
      error_handler.CATEGORY.VALIDATION,
      { has_time_stats = type(result.time_stats) == "table" }
    )

    error_handler.assert(
      type(result.memory_stats) == "table",
      "result.memory_stats must be a table",
      error_handler.CATEGORY.VALIDATION,
      { has_memory_stats = type(result.memory_stats) == "table" }
    )

    -- Extract configuration
    return {
      precision = options.precision or benchmark.options.precision,
      report_memory = options.report_memory ~= nil and options.report_memory or benchmark.options.report_memory,
      report_stats = options.report_stats ~= nil and options.report_stats or benchmark.options.report_stats,
      quiet = options.quiet or false,
      label = result.label or "Benchmark",
      result = result,
    }
  end)

  if not success then
    logger.error("Failed to process benchmark result printing parameters", {
      error = error_handler.format_error(config),
    })

    -- Cannot proceed with invalid parameters
    return
  end

  -- Log benchmark results using safe access
  local log_success = error_handler.try(function()
    logger.debug("Benchmark result", {
      label = config.label,
      mean_time_seconds = config.result.time_stats.mean,
      min_time_seconds = config.result.time_stats.min,
      max_time_seconds = config.result.time_stats.max,
      std_dev_seconds = config.result.time_stats.std_dev,
      mean_memory_kb = config.result.memory_stats.mean,
      min_memory_kb = config.result.memory_stats.min,
      max_memory_kb = config.result.memory_stats.max,
    })
  end)

  if not log_success then
    logger.warn("Failed to log benchmark result details", {
      label = config.label,
    })
  end

  -- If quiet mode, don't print to console
  if config.quiet then
    return
  end

  -- Print results using safe I/O operations
  error_handler.safe_io_operation(function()
    -- Basic execution time
    io.write(string.format("  Mean execution time: %s\n", format_time(config.result.time_stats.mean)))

    if config.report_stats then
      io.write(
        string.format(
          "  Min: %s  Max: %s\n",
          format_time(config.result.time_stats.min),
          format_time(config.result.time_stats.max)
        )
      )

      -- Calculate percentage with division by zero protection
      local percent = 0
      if config.result.time_stats.mean ~= 0 then
        percent = (config.result.time_stats.std_dev / config.result.time_stats.mean) * 100
      end

      io.write(string.format("  Std Dev: %s (%.1f%%)\n", format_time(config.result.time_stats.std_dev), percent))
    end

    -- Memory stats
    if config.report_memory then
      io.write(string.format("  Mean memory delta: %.2f KB\n", config.result.memory_stats.mean))

      if config.report_stats then
        io.write(
          string.format(
            "  Memory Min: %.2f KB  Max: %.2f KB\n",
            config.result.memory_stats.min,
            config.result.memory_stats.max
          )
        )
      end
    end
  end, "console", { operation = "write_benchmark_result", label = config.label })
end

-- Load the filesystem module has been moved to the top of the file

-- Generate benchmark data for large test suites
function benchmark.generate_large_test_suite(options)
  -- Process options
  local success, config = error_handler.try(function()
    options = options or {}

    return {
      file_count = options.file_count or 100,
      tests_per_file = options.tests_per_file or 50,
      nesting_level = options.nesting_level or 3,
      output_dir = options.output_dir or "./benchmark_tests",
      silent = options.silent or false,
    }
  end)

  if not success then
    logger.error("Failed to process benchmark test suite generation options", {
      error = error_handler.format_error(config),
    })

    -- Return error
    return nil,
      error_handler.create(
        "Failed to process benchmark test suite generation options",
        error_handler.CATEGORY.VALIDATION,
        error_handler.SEVERITY.ERROR,
        { original_error = config }
      )
  end

  -- Log generation start
  logger.debug("Generating benchmark test suite", {
    file_count = config.file_count,
    tests_per_file = config.tests_per_file,
    nesting_level = config.nesting_level,
    output_dir = config.output_dir,
  })

  -- Ensure output directory exists
  local dir_success, dir_err = error_handler.safe_io_operation(function()
    return fs.ensure_directory_exists(config.output_dir)
  end, config.output_dir, { operation = "ensure_directory_exists" })

  if not dir_success then
    local error_obj = error_handler.io_error("Failed to create output directory", error_handler.SEVERITY.ERROR, {
      directory = config.output_dir,
      operation = "ensure_directory_exists",
      original_error = dir_err,
    })

    logger.error("Failed to create output directory", {
      directory = config.output_dir,
      error = error_handler.format_error(error_obj),
    })

    return nil, error_obj
  end

  -- Create test generator function with error handling
  local function generate_tests(level, prefix)
    return error_handler.try(function()
      if level <= 0 then
        return ""
      end

      local tests_at_level = level == config.nesting_level and config.tests_per_file
        or math.ceil(config.tests_per_file / level)
      local test_content = ""

      for j = 1, tests_at_level do
        if level == config.nesting_level then
          -- Leaf test case
          test_content = test_content .. string.rep("  ", config.nesting_level - level)
          test_content = test_content .. "it('test " .. prefix .. "." .. j .. "', function()\n"
          test_content = test_content .. string.rep("  ", config.nesting_level - level + 1)
          test_content = test_content .. "expect(1 + 1).to.equal(2)\n"
          test_content = test_content .. string.rep("  ", config.nesting_level - level)
          test_content = test_content .. "end)\n\n"
        else
          -- Nested describe block
          test_content = test_content .. string.rep("  ", config.nesting_level - level)
          test_content = test_content .. "describe('suite " .. prefix .. "." .. j .. "', function()\n"

          -- Generate nested tests with error handling
          local nested_success, nested_content = generate_tests(level - 1, prefix .. "." .. j)
          test_content = test_content .. (nested_success and nested_content or "-- Error generating nested tests\n")

          test_content = test_content .. string.rep("  ", config.nesting_level - level)
          test_content = test_content .. "end)\n\n"
        end
      end

      return test_content
    end)
  end

  -- Track success and failure counts
  local success_count = 0
  local failure_count = 0

  -- Create test files
  for i = 1, config.file_count do
    -- Generate file path
    local file_path_success, file_path = error_handler.try(function()
      return fs.join_paths(config.output_dir, "test_" .. i .. ".lua")
    end)

    if not file_path_success then
      logger.error("Failed to generate file path", {
        index = i,
        output_dir = config.output_dir,
        error = error_handler.format_error(file_path),
      })
      failure_count = failure_count + 1
      goto continue
    end

    -- Generate file content
    local content_success, content = error_handler.try(function()
      local header = "-- Generated large test suite file #"
        .. i
        .. "\n"
        .. "local firmo = require('firmo')\n"
        .. "local describe, it, expect = firmo.describe, firmo.it, firmo.expect\n\n"

      -- Start the top level describe block
      local file_content = header .. "describe('benchmark test file " .. i .. "', function()\n"

      -- Generate test content with error handling
      local tests_success, tests_content = generate_tests(config.nesting_level, i)
      file_content = file_content .. (tests_success and tests_content or "-- Error generating tests\n")

      file_content = file_content .. "end)\n"

      return file_content
    end)

    if not content_success then
      logger.error("Failed to generate test file content", {
        index = i,
        file_path = file_path,
        error = error_handler.format_error(content),
      })
      failure_count = failure_count + 1
      goto continue
    end

    -- Write the file
    logger.debug("Writing benchmark test file", {
      file_path = file_path,
      content_size = #content,
    })

    local write_success, write_err = error_handler.safe_io_operation(function()
      return fs.write_file(file_path, content)
    end, file_path, { operation = "write_file", content_size = #content })

    if not write_success then
      logger.error("Failed to write test file", {
        path = file_path,
        error = error_handler.format_error(write_err),
      })
      failure_count = failure_count + 1
    else
      success_count = success_count + 1
    end

    ::continue::
  end

  -- Log test generation results
  logger.info("Generated test files for benchmark", {
    file_count = config.file_count,
    successful_files = success_count,
    failed_files = failure_count,
    test_count = success_count * config.tests_per_file,
    output_dir = config.output_dir,
  })

  -- Print to console if not silent
  if not config.silent then
    error_handler.safe_io_operation(function()
      io.write(
        "Generated "
          .. success_count
          .. " test files with approximately "
          .. (success_count * config.tests_per_file)
          .. " total tests in "
          .. config.output_dir
          .. "\n"
      )

      if failure_count > 0 then
        io.write("Failed to generate " .. failure_count .. " files\n")
      end
    end, "console", { operation = "write_generation_summary" })
  end

  return {
    output_dir = config.output_dir,
    file_count = config.file_count,
    successful_files = success_count,
    failed_files = failure_count,
    tests_per_file = config.tests_per_file,
    total_tests = success_count * config.tests_per_file,
  }
end

-- Register the module with firmo
function benchmark.register_with_firmo(firmo)
  -- Validate input
  error_handler.assert(
    firmo ~= nil,
    "firmo must be provided",
    error_handler.CATEGORY.VALIDATION,
    { firmo_provided = firmo ~= nil }
  )

  error_handler.assert(
    type(firmo) == "table",
    "firmo must be a table",
    error_handler.CATEGORY.VALIDATION,
    { firmo_type = type(firmo) }
  )

  -- Store reference to firmo
  benchmark.firmo = firmo

  -- Add benchmarking capabilities to firmo
  local success = error_handler.try(function()
    firmo.benchmark = benchmark
    return true
  end)

  if not success then
    logger.error("Failed to register benchmark module with firmo")
    return firmo
  end

  logger.debug("Benchmark module registered with firmo")
  return firmo
end

return benchmark
