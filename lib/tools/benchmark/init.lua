--- Firmo Benchmarking Module
---
--- Provides utilities for measuring and analyzing code performance with statistical
--- analysis, memory tracking (basic), and comparison capabilities.
---
--- Features:
--- - Measure function execution time over multiple iterations (`measure`).
--- - Statistical analysis (mean, min, max, stddev).
--- - Optional memory usage tracking using `collectgarbage("count")`.
--- - Warmup runs.
--- - Run benchmark suites defined in tables (`suite`).
--- - Compare results of two benchmarks (`compare`).
--- - Basic console output for results (`print_result`).
--- - Generate large dummy test suites for benchmarking the framework (`generate_large_test_suite`).
---
--- @module lib.tools.benchmark
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class benchmark_module
---@field _VERSION string Module version (following semantic versioning).
---@field options {iterations: number, warmup: number, precision: number, report_memory: boolean, report_stats: boolean, gc_before: boolean, include_warmup: boolean} Default configuration options.
---@field measure fun(func: function, args?: table, options?: {iterations?: number, warmup?: number, gc_before?: boolean, include_warmup?: boolean, label?: string}): table|nil, table? Measures performance of a function. Returns results table or `nil, error`. @throws table If validation fails critically.
---@field suite fun(suite_def: { name?: string, benchmarks: {name?: string, func: function, args?: table, options?: table}[] }, options?: { quiet?: boolean }): table Runs a suite of benchmarks. Returns suite results table. @throws table If validation fails critically.
---@field compare fun(benchmark1: table, benchmark2: table, options?: { silent?: boolean }): table|nil, table? Compares results of two benchmarks. Returns comparison table or `nil, error`. @throws table If validation fails critically.
---@field print_result fun(result: table, options?: { precision?: number, report_memory?: boolean, report_stats?: boolean, quiet?: boolean }): nil Prints a single benchmark result to console. @throws table If validation fails.
---@field generate_large_test_suite fun(options?: { file_count?: number, tests_per_file?: number, nesting_level?: number, output_dir?: string, silent?: boolean }): table|nil, table? Generates a large set of test files for benchmarking the test runner. Returns summary table or `nil, error`. @throws table If validation or IO fails critically.
---@field register_with_firmo fun(firmo: table): table Registers the benchmark module with the firmo instance. @throws table If validation fails.
---@field time fun(...) [Not Implemented] Measure execution time of a function.
---@field run fun(...) [Not Implemented] Run a named benchmark.
---@field print_results fun(...) [Not Implemented] Print formatted benchmark results.
---@field save_results fun(...) [Not Implemented] Save benchmark results to a file.
---@field load_results fun(...) [Not Implemented] Load benchmark results from a file.
---@field gc fun(...) [Not Implemented] Force garbage collection.
---@field memory fun(...) [Not Implemented] Get current memory usage.
---@field configure fun(...) [Not Implemented] Configure benchmark options.
---@field reset fun(...) [Not Implemented] Reset benchmark options.
---@field stats fun(...) [Not Implemented] Calculate comprehensive statistics.
---@field async_time fun(...) [Not Implemented] Measure execution time asynchronously.
---@field human_size fun(...) [Not Implemented] Format size in bytes.
---@field human_time fun(...) [Not Implemented] Format time value (use `format_time` instead, currently internal).
---@field measure_call_overhead fun(...) [Not Implemented] Measure function call overhead.
---@field histogram fun(...) [Not Implemented] Generate a histogram.
---@field is_significant fun(...) [Not Implemented] Determine statistical significance.
---@field plot fun(...) [Not Implemented] Generate chart of results.

local benchmark = {}

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging, _fs

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the filesystem module with lazy loading to avoid circular dependencies
---@return table|nil The filesystem module or nil if not available
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
end

--- Get the success handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

--- Get the logging module with lazy loading to avoid circular dependencies
---@return table|nil The logging module or nil if not available
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end

--- Get a logger instance for this module
---@return table A logger instance (either real or stub)
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("benchmark")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack_table = table.unpack or unpack

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

--- Gets high-resolution time using socket.gettime() if available, falling back to os.clock().
--- Handles potential errors during socket call.
---@return number time Time in seconds. Precision depends on availability (socket > os.clock > os.time).
---@private
local function high_res_time()
  ---@diagnostic disable-next-line: unused-local
  local success, time, err = get_error_handler().try(function()
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
    get_logger().warn("Failed to get high-resolution time", {
      error = get_error_handler().format_error(time),
      fallback = "using os.time()",
    })
    return os.time()
  end

  return time
end

--- Calculates basic statistics (mean, min, max, stddev, count, total) for an array of numbers.
--- Handles empty/invalid input and calculation errors gracefully.
---@param measurements number[] Array of numerical measurements.
---@return {mean: number, min: number, max: number, std_dev: number, count: number, total: number} stats A table containing calculated statistics. Returns zeros if input is empty or calculations fail.
---@private
local function calculate_stats(measurements)
  if not measurements or #measurements == 0 then
    return {
      mean = 0,
      min = 0,
      max = 0,
      std_dev = 0,
      count = 0,
      total = 0,
    }
  end

  local success, stats = get_error_handler().try(function()
    local sum = 0
    local min = measurements[1]
    local max = measurements[1]

    for _, value in ipairs(measurements) do
      sum = sum + value
      min = math.min(min, value)
      max = math.max(max, value)
    end

    local mean = sum / #measurements

    -- Calculate standard deviation
    local variance = 0
    for _, value in ipairs(measurements) do
      variance = variance + (value - mean) ^ 2
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
    get_logger().error("Failed to calculate statistics", {
      error = get_error_handler().format_error(stats),
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

--- Performs a deep clone (recursive copy) of a table.
--- Handles nested tables but currently does **not** handle cycles.
---@param t table The table to clone.
---@return table copy The deep copy of the table. Returns an empty table if cloning fails.
---@private
local function deep_clone(t)
  if type(t) ~= "table" then
    return t
  end

  ---@diagnostic disable-next-line: unused-local
  local success, copy, err = get_error_handler().try(function()
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
    get_logger().warn("Failed to deep clone table", {
      error = get_error_handler().format_error(copy),
      table_type = type(t),
      fallback = "returning empty table",
    })
    return {} -- Return an empty table as fallback
  end

  return copy
end

--- Measure the execution time and performance metrics of a function
---@param func function The function to benchmark
---@param args? table Array-like table of arguments to pass to `func`.
---@param options? {iterations?: number, warmup?: number, gc_before?: boolean, include_warmup?: boolean, label?: string} Optional benchmarking settings:
---  - `iterations`: Number of times to run the main measurement loop.
---  - `warmup`: Number of initial runs to discard (for JIT, cache).
---  - `gc_before`: If true, run `collectgarbage` before each iteration.
---  - `include_warmup`: If true, include warmup runs in the final statistics.
---  - `label`: A name for this specific benchmark run.
---@return table|nil results A table containing raw times (`times`), memory deltas (`memory`), configuration (`label`, `iterations`, `warmup`), and calculated statistics (`time_stats`, `memory_stats`). Returns `nil` if critical validation fails.
---@return table? error Error object if measurement or calculation failed critically.
---@throws table If `func` validation fails critically (via `error_handler.assert`).
---
--- The function safely measures both execution time and memory usage with robust
--- error handling for memory measurement. If memory measurement fails, appropriate
--- fallback values are used and warnings are logged.
function benchmark.measure(func, args, options)
  -- Validate required parameters
  get_error_handler().assert(
    func ~= nil,
    "benchmark.measure requires a function to benchmark",
    get_error_handler().CATEGORY.VALIDATION,
    { func_provided = func ~= nil }
  )

  get_error_handler().assert(
    type(func) == "function",
    "benchmark.measure requires a function to benchmark",
    get_error_handler().CATEGORY.VALIDATION,
    { func_type = type(func) }
  )

  -- Initialize options with defaults
  local process_options_success, processed_options = get_error_handler().try(function()
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
    get_logger().warn("Failed to process benchmark options", {
      error = get_error_handler().format_error(processed_options),
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
  get_logger().debug("Starting benchmark execution", {
    label = label,
    iterations = iterations,
    warmup = warmup,
    include_warmup = include_warmup,
    gc_before = gc_before,
  })

  -- Warmup phase
  for i = 1, warmup do
    if gc_before then
      get_error_handler().try(function()
        collectgarbage("collect")
      end)
    end

    -- Measure execution
    local start_time = high_res_time()

    -- Properly handle start memory measurement
    local start_memory_success, start_memory_value = get_error_handler().try(function()
      return collectgarbage("count")
    end)

    -- Use start_memory_value only when successful and numeric, otherwise default to 0
    local start_memory = start_memory_success and type(start_memory_value) == "number" and start_memory_value or 0

    if not start_memory_success or type(start_memory_value) ~= "number" then
      get_logger().warn("Failed to measure start memory", {
        label = label,
        iteration = i,
        memory_success = start_memory_success,
        memory_type = type(start_memory_value),
        fallback = "using default 0 value",
      })
    end

    -- Execute function with arguments
    ---@diagnostic disable-next-line: unused-local
    local success, result, exec_err = get_error_handler().try(function()
      ---@diagnostic disable-next-line: param-type-mismatch
      return func(unpack_table(args_clone))
    end)

    if not success then
      get_logger().warn("Benchmark function execution failed", {
        error = get_error_handler().format_error(result),
        label = label,
        iteration = i,
      })
    end

    local end_time = high_res_time()

    -- Properly handle end memory measurement
    local end_memory_success, end_memory_value = get_error_handler().try(function()
      return collectgarbage("count")
    end)

    -- Use end_memory_value only when successful and numeric, otherwise fallback to start_memory
    local end_memory = end_memory_success and type(end_memory_value) == "number" and end_memory_value or start_memory

    if not end_memory_success or type(end_memory_value) ~= "number" then
      get_logger().warn("Failed to measure end memory", {
        label = label,
        iteration = i,
        memory_success = end_memory_success,
        memory_type = type(end_memory_value),
        fallback = "using start_memory value",
      })
    end

    -- Validate both memory values before arithmetic
    local memory_diff = type(end_memory) == "number" and type(start_memory) == "number" and (end_memory - start_memory)
      or 0

    if type(end_memory) ~= "number" or type(start_memory) ~= "number" then
      get_logger().warn("Invalid memory measurement values during warmup", {
        label = label,
        iteration = i,
        warmup = true,
        end_memory_type = type(end_memory),
        start_memory_type = type(start_memory),
        fallback = "using 0 as memory difference",
      })
    end

    -- Store results with validated numeric values
    table.insert(results.times, end_time - start_time)
    table.insert(results.memory, memory_diff)

    -- Store results if including warmup
    if include_warmup then
      table.insert(results.times, end_time - start_time)
      table.insert(results.memory, end_memory - start_memory)
    end
  end

  -- Main benchmark phase
  for i = 1, iterations do
    if gc_before then
      get_error_handler().try(function()
        collectgarbage("collect")
      end)
    end

    -- Measure execution
    local start_time = high_res_time()

    -- Properly handle start memory measurement
    local start_memory_success, start_memory_value = get_error_handler().try(function()
      return collectgarbage("count")
    end)

    -- Use start_memory_value only when successful and numeric, otherwise default to 0
    local start_memory = start_memory_success and type(start_memory_value) == "number" and start_memory_value or 0

    if not start_memory_success or type(start_memory_value) ~= "number" then
      get_logger().warn("Failed to measure start memory", {
        label = label,
        iteration = i,
        memory_success = start_memory_success,
        memory_type = type(start_memory_value),
        fallback = "using default 0 value",
      })
    end

    -- Execute function with arguments
    ---@diagnostic disable-next-line: unused-local
    local success, result, exec_err = get_error_handler().try(function()
      ---@diagnostic disable-next-line: param-type-mismatch
      return func(unpack_table(args_clone))
    end)

    if not success then
      get_logger().warn("Benchmark function execution failed", {
        error = get_error_handler().format_error(result),
        label = label,
        iteration = i,
      })
    end

    local end_time = high_res_time()

    -- Properly handle end memory measurement
    local end_memory_success, end_memory_value = get_error_handler().try(function()
      return collectgarbage("count")
    end)

    -- Use end_memory_value only when successful and numeric, otherwise fallback to start_memory
    local end_memory = end_memory_success and type(end_memory_value) == "number" and end_memory_value or start_memory

    if not end_memory_success or type(end_memory_value) ~= "number" then
      get_logger().warn("Failed to measure end memory", {
        label = label,
        iteration = i,
        memory_success = end_memory_success,
        memory_type = type(end_memory_value),
        fallback = "using start_memory value",
      })
    end

    -- Validate both memory values before arithmetic
    local memory_diff = type(end_memory) == "number" and type(start_memory) == "number" and (end_memory - start_memory)
      or 0

    if type(end_memory) ~= "number" or type(start_memory) ~= "number" then
      get_logger().warn("Invalid memory measurement values", {
        label = label,
        iteration = i,
        end_memory_type = type(end_memory),
        start_memory_type = type(start_memory),
        fallback = "using 0 as memory difference",
      })
    end

    -- Store results with validated numeric values
    table.insert(results.times, end_time - start_time)
    table.insert(results.memory, memory_diff)
  end

  -- Calculate statistics
  local time_stats_success, time_stats = get_error_handler().try(function()
    return calculate_stats(results.times)
  end)

  if not time_stats_success then
    get_logger().error("Failed to calculate time statistics", {
      error = get_error_handler().format_error(time_stats),
      times_count = #results.times,
    })
    time_stats = {
      mean = 0,
      min = 0,
      max = 0,
      std_dev = 0,
      count = #results.times,
      total = 0,
    }
  end

  -- Calculate memory statistics
  local memory_stats_success, memory_stats = get_error_handler().try(function()
    return calculate_stats(results.memory)
  end)

  if not memory_stats_success then
    get_logger().error("Failed to calculate memory statistics", {
      error = get_error_handler().format_error(memory_stats),
      memory_samples_count = #results.memory,
    })
    memory_stats = {
      mean = 0,
      min = 0,
      max = 0,
      std_dev = 0,
      count = #results.memory,
      total = 0,
    }
  end

  -- Add stats to results
  results.time_stats = time_stats
  results.memory_stats = memory_stats

  return results
end

--- Runs a suite of benchmarks defined in a table.
--- Each benchmark in the suite can have its own function, arguments, and options,
--- merged with suite-level options. Prints results to console unless `options.quiet` is true.
---@param suite_def { name?: string, benchmarks: {name?: string, func: function, args?: table, options?: table}[] } Definition of the suite. `benchmarks` is an array of benchmark definitions.
---@param options? { quiet?: boolean } Options for the suite run. `quiet` suppresses console output.
---@return table results A table summarizing the suite run: `{ name, benchmarks = {benchmark_results[]}, start_time, options, errors = {error_details[]}, end_time, duration }`.
---@throws table If validation of `suite_def` or benchmark definitions fails critically.
function benchmark.suite(suite_def, options)
  -- Validate suite definition
  get_error_handler().assert(
    suite_def ~= nil,
    "suite_def must be provided",
    get_error_handler().CATEGORY.VALIDATION,
    { suite_def_provided = suite_def ~= nil }
  )

  get_error_handler().assert(
    type(suite_def) == "table",
    "suite_def must be a table",
    get_error_handler().CATEGORY.VALIDATION,
    { suite_def_type = type(suite_def) }
  )

  -- Process options and suite definition
  local success, config = get_error_handler().try(function()
    options = options or {}
    local suite_name = suite_def.name or "Benchmark Suite"
    local benchmarks = suite_def.benchmarks or {}

    get_error_handler().assert(
      type(benchmarks) == "table",
      "suite_def.benchmarks must be a table",
      get_error_handler().CATEGORY.VALIDATION,
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
    get_logger().error("Failed to process benchmark suite configuration", {
      error = get_error_handler().format_error(config),
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
  get_logger().info("Running benchmark suite", { name = config.suite_name })

  -- Print header for console output using safe output
  if not config.quiet then
    local io_success = get_error_handler().safe_io_operation(function()
      io.write("\n" .. string.rep("-", 80) .. "\n")
      io.write("Running benchmark suite: " .. config.suite_name .. "\n")
      io.write(string.rep("-", 80) .. "\n")
    end, "console", { operation = "write_header" })

    if not io_success then
      get_logger().warn("Failed to write benchmark header to console")
    end
  end

  -- Run each benchmark
  for idx, benchmark_def in ipairs(config.benchmarks) do
    local bench_success, bench_result = get_error_handler().try(function()
      -- Extract benchmark definition
      local name = (benchmark_def.name or "Benchmark #") .. idx

      get_error_handler().assert(
        benchmark_def.func ~= nil,
        "Benchmark function is required",
        get_error_handler().CATEGORY.VALIDATION,
        { benchmark_name = name }
      )

      get_error_handler().assert(
        type(benchmark_def.func) == "function",
        "Benchmark function must be a function",
        get_error_handler().CATEGORY.VALIDATION,
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
      get_logger().debug("Running benchmark", { name = name, index = idx })

      -- Print to console if not quiet
      if not config.quiet then
        get_error_handler().safe_io_operation(function()
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
      get_logger().error("Failed to execute benchmark", {
        index = idx,
        error = get_error_handler().format_error(bench_result),
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
  get_logger().info("Benchmark suite completed", {
    name = config.suite_name,
    duration_seconds = results.duration,
    benchmark_count = #results.benchmarks,
    error_count = #results.errors,
  })

  -- Print suite summary to console if not quiet
  if not config.quiet then
    get_error_handler().safe_io_operation(function()
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

--- Compare two benchmark results and calculate performance differences
---@param benchmark1 table Benchmark result table (output from `benchmark.measure`).
---@param benchmark2 table Second benchmark result table.
---@param options? { silent?: boolean } Comparison options. `silent` suppresses console output.
---@return table|nil comparison A table summarizing the comparison: `{ benchmarks, time_ratio, memory_ratio, faster, less_memory, time_percent, memory_percent }`, or `nil` on error.
---@return table? error Error object if validation or comparison calculation fails.
---@throws table If validation fails critically (via `error_handler.assert`).
function benchmark.compare(benchmark1, benchmark2, options)
  -- Validate required parameters
  get_error_handler().assert(
    benchmark1 ~= nil,
    "benchmark.compare requires two benchmark results to compare",
    get_error_handler().CATEGORY.VALIDATION,
    { benchmark1_provided = benchmark1 ~= nil }
  )

  get_error_handler().assert(
    benchmark2 ~= nil,
    "benchmark.compare requires two benchmark results to compare",
    get_error_handler().CATEGORY.VALIDATION,
    { benchmark2_provided = benchmark2 ~= nil }
  )

  -- Process options
  local success, config = get_error_handler().try(function()
    options = options or {}

    -- Validate benchmark objects
    get_error_handler().assert(
      type(benchmark1) == "table",
      "benchmark1 must be a benchmark result table",
      get_error_handler().CATEGORY.VALIDATION,
      { benchmark1_type = type(benchmark1) }
    )

    get_error_handler().assert(
      type(benchmark2) == "table",
      "benchmark2 must be a benchmark result table",
      get_error_handler().CATEGORY.VALIDATION,
      { benchmark2_type = type(benchmark2) }
    )

    get_error_handler().assert(
      type(benchmark1.time_stats) == "table",
      "benchmark1.time_stats must be a table",
      get_error_handler().CATEGORY.VALIDATION,
      { has_time_stats = type(benchmark1.time_stats) == "table" }
    )

    get_error_handler().assert(
      type(benchmark2.time_stats) == "table",
      "benchmark2.time_stats must be a table",
      get_error_handler().CATEGORY.VALIDATION,
      { has_time_stats = type(benchmark2.time_stats) == "table" }
    )

    get_error_handler().assert(
      type(benchmark1.memory_stats) == "table",
      "benchmark1.memory_stats must be a table",
      get_error_handler().CATEGORY.VALIDATION,
      { has_memory_stats = type(benchmark1.memory_stats) == "table" }
    )

    get_error_handler().assert(
      type(benchmark2.memory_stats) == "table",
      "benchmark2.memory_stats must be a table",
      get_error_handler().CATEGORY.VALIDATION,
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
    get_logger().error("Failed to process benchmark comparison parameters", {
      error = get_error_handler().format_error(config),
    })

    -- Return an error result
    return nil,
      get_error_handler().create(
        "Failed to process benchmark comparison parameters",
        get_error_handler().CATEGORY.VALIDATION,
        get_error_handler().SEVERITY.ERROR,
        { original_error = config }
      )
  end

  -- Calculate comparison
  local compare_success, comparison = get_error_handler().try(function()
    -- Ensure stats have mean values
    get_error_handler().assert(
      type(config.benchmark1.time_stats.mean) == "number",
      "benchmark1.time_stats.mean must be a number",
      get_error_handler().CATEGORY.VALIDATION,
      { mean_type = type(config.benchmark1.time_stats.mean) }
    )

    get_error_handler().assert(
      type(config.benchmark2.time_stats.mean) == "number",
      "benchmark2.time_stats.mean must be a number",
      get_error_handler().CATEGORY.VALIDATION,
      { mean_type = type(config.benchmark2.time_stats.mean) }
    )

    get_error_handler().assert(
      type(config.benchmark1.memory_stats.mean) == "number",
      "benchmark1.memory_stats.mean must be a number",
      get_error_handler().CATEGORY.VALIDATION,
      { mean_type = type(config.benchmark1.memory_stats.mean) }
    )

    get_error_handler().assert(
      type(config.benchmark2.memory_stats.mean) == "number",
      "benchmark2.memory_stats.mean must be a number",
      get_error_handler().CATEGORY.VALIDATION,
      { mean_type = type(config.benchmark2.memory_stats.mean) }
    )

    -- Avoid division by zero
    get_error_handler().assert(
      config.benchmark2.time_stats.mean ~= 0,
      "benchmark2.time_stats.mean cannot be zero",
      get_error_handler().CATEGORY.VALIDATION,
      { mean = config.benchmark2.time_stats.mean }
    )

    get_error_handler().assert(
      config.benchmark2.memory_stats.mean ~= 0,
      "benchmark2.memory_stats.mean cannot be zero",
      get_error_handler().CATEGORY.VALIDATION,
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
    get_logger().error("Failed to calculate benchmark comparison", {
      error = get_error_handler().format_error(comparison),
    })

    -- Return an error result
    return nil,
      get_error_handler().create(
        "Failed to calculate benchmark comparison",
        get_error_handler().CATEGORY.RUNTIME,
        get_error_handler().SEVERITY.ERROR,
        { original_error = comparison }
      )
  end

  -- Log comparison results
  get_logger().info("Benchmark comparison", {
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
    get_error_handler().safe_io_operation(function()
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

--- Print formatted benchmark results to the console
---@param result table Benchmark result table (output from `benchmark.measure`).
---@param options? { precision?: number, report_memory?: boolean, report_stats?: boolean, quiet?: boolean } Formatting options:
---  - `precision`: Decimal places for time/memory values.
---  - `report_memory`: Include memory stats in output.
---  - `report_stats`: Include min/max/stddev stats in output.
---  - `quiet`: Suppress console output completely.
---@return nil
---@throws table If `result` validation fails critically.
function benchmark.print_result(result, options)
  -- Validate required parameters
  get_error_handler().assert(
    result ~= nil,
    "benchmark.print_result requires a result table",
    get_error_handler().CATEGORY.VALIDATION,
    { result_provided = result ~= nil }
  )

  -- Process options and validate result
  local success, config = get_error_handler().try(function()
    options = options or {}

    get_error_handler().assert(
      type(result) == "table",
      "result must be a table",
      get_error_handler().CATEGORY.VALIDATION,
      { result_type = type(result) }
    )

    get_error_handler().assert(
      type(result.time_stats) == "table",
      "result.time_stats must be a table",
      get_error_handler().CATEGORY.VALIDATION,
      { has_time_stats = type(result.time_stats) == "table" }
    )

    get_error_handler().assert(
      type(result.memory_stats) == "table",
      "result.memory_stats must be a table",
      get_error_handler().CATEGORY.VALIDATION,
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
    get_logger().error("Failed to process benchmark result printing parameters", {
      error = get_error_handler().format_error(config),
    })

    -- Cannot proceed with invalid parameters
    return
  end

  -- Log benchmark results using safe access
  local log_success = get_error_handler().try(function()
    get_logger().debug("Benchmark result", {
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
    get_logger().warn("Failed to log benchmark result details", {
      label = config.label,
    })
  end

  -- If quiet mode, don't print to console
  if config.quiet then
    return
  end

  -- Print results using safe I/O operations
  get_error_handler().safe_io_operation(function()
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

--- Generates a potentially large number of dummy Lua test files containing nested
--- `describe` and `it` blocks. Useful for benchmarking the test runner itself.
--- Writes files to the specified `output_dir`.
---@param options? { file_count?: number, tests_per_file?: number, nesting_level?: number, output_dir?: string, silent?: boolean } Generation options:
---  - `file_count`: Number of test files to generate.
---  - `tests_per_file`: Target number of `it` blocks per file (approximate due to nesting).
---  - `nesting_level`: Depth of nested `describe` blocks.
---  - `output_dir`: Directory to write the generated files into.
---  - `silent`: Suppress console output during generation.
---@return table|nil summary A table summarizing the generation: `{ output_dir, file_count, successful_files, failed_files, tests_per_file, total_tests }`, or `nil` on error.
---@return table? error Error object if validation or file I/O fails.
---@throws table If validation or critical file I/O operations fail.
function benchmark.generate_large_test_suite(options)
  -- Process options
  local success, config = get_error_handler().try(function()
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
    get_logger().error("Failed to process benchmark test suite generation options", {
      error = get_error_handler().format_error(config),
    })

    -- Return error
    return nil,
      get_error_handler().create(
        "Failed to process benchmark test suite generation options",
        get_error_handler().CATEGORY.VALIDATION,
        get_error_handler().SEVERITY.ERROR,
        { original_error = config }
      )
  end

  -- Log generation start
  get_logger().debug("Generating benchmark test suite", {
    file_count = config.file_count,
    tests_per_file = config.tests_per_file,
    nesting_level = config.nesting_level,
    output_dir = config.output_dir,
  })

  -- Ensure output directory exists
  local dir_success, dir_err = get_error_handler().safe_io_operation(function()
    return get_fs().ensure_directory_exists(config.output_dir)
  end, config.output_dir, { operation = "ensure_directory_exists" })

  if not dir_success then
    local error_obj = get_error_handler().io_error("Failed to create output directory", get_error_handler().SEVERITY.ERROR, {
      directory = config.output_dir,
      operation = "ensure_directory_exists",
      original_error = dir_err,
    })

    get_logger().error("Failed to create output directory", {
      directory = config.output_dir,
      error = get_error_handler().format_error(error_obj),
    })

    return nil, error_obj
  end

  -- Create test generator function with error handling
  local function generate_tests(level, prefix)
    return get_error_handler().try(function()
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
    local file_path_success, file_path = get_error_handler().try(function()
      return get_fs().join_paths(config.output_dir, "test_" .. i .. ".lua")
    end)

    if not file_path_success then
      get_logger().error("Failed to generate file path", {
        index = i,
        output_dir = config.output_dir,
        error = get_error_handler().format_error(file_path),
      })
      failure_count = failure_count + 1
      goto continue
    end

    -- Generate file content
    local content_success, content = get_error_handler().try(function()
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
      get_logger().error("Failed to generate test file content", {
        index = i,
        file_path = file_path,
        error = get_error_handler().format_error(content),
      })
      failure_count = failure_count + 1
      goto continue
    end

    -- Write the file
    get_logger().debug("Writing benchmark test file", {
      file_path = file_path,
      content_size = #content,
    })

    local write_success, write_err = get_error_handler().safe_io_operation(function()
      return get_fs().write_file(file_path, content)
    end, file_path, { operation = "write_file", content_size = #content })

    if not write_success then
      get_logger().error("Failed to write test file", {
        path = file_path,
        error = get_error_handler().format_error(write_err),
      })
      failure_count = failure_count + 1
    else
      success_count = success_count + 1
    end

    ::continue::
  end

  -- Log test generation results
  get_logger().info("Generated test files for benchmark", {
    file_count = config.file_count,
    successful_files = success_count,
    failed_files = failure_count,
    test_count = success_count * config.tests_per_file,
    output_dir = config.output_dir,
  })

  -- Print to console if not silent
  if not config.silent then
    get_error_handler().safe_io_operation(function()
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

--- Register benchmark functionality with the firmo framework
---@param firmo table The firmo framework instance.
---@return table firmo The `firmo` instance passed in (potentially modified if registration adds `firmo.benchmark`). Returns input `firmo` even on failure.
---@throws table If `firmo` validation fails critically (via `error_handler.assert`).
function benchmark.register_with_firmo(firmo)
  -- Validate input
  get_error_handler().assert(
    firmo ~= nil,
    "firmo must be provided",
    get_error_handler().CATEGORY.VALIDATION,
    { firmo_provided = firmo ~= nil }
  )

  get_error_handler().assert(
    type(firmo) == "table",
    "firmo must be a table",
    get_error_handler().CATEGORY.VALIDATION,
    { firmo_type = type(firmo) }
  )

  -- Store reference to firmo
  benchmark.firmo = firmo

  -- Add benchmarking capabilities to firmo
  local success = get_error_handler().try(function()
    firmo.benchmark = benchmark
    return true
  end)

  if not success then
    get_logger().error("Failed to register benchmark module with firmo")
    return firmo
  end

  get_logger().debug("Benchmark module registered with firmo")
  return firmo
end

return benchmark
