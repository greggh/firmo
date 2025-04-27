--- Firmo Parallel Test Execution Module
---
--- Provides functionality to run test files in parallel using separate Lua processes,
--- potentially speeding up test execution time on multi-core systems.
--- Includes configuration for worker count, timeouts, output buffering, and coverage aggregation.
--- Integrates with the `firmo` CLI and core runner.
---
--- @module lib.tools.parallel
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
---@class parallel_module The public API for the parallel execution module.
---@field _VERSION string Module version.
---@field options {workers: number, timeout: number, output_buffer_size: number, verbose: boolean, show_worker_output: boolean, fail_fast: boolean, aggregate_coverage: boolean, debug: boolean} Current configuration options.
---@field run_tests fun(files: string[], options?: {workers?: number, timeout?: number, verbose?: boolean, show_worker_output?: boolean, fail_fast?: boolean, aggregate_coverage?: boolean, coverage?: boolean, tags?: string[], filter?: string}): {passed: number, failed: number, skipped: number, pending: number, total: number, errors: table[], elapsed: number, coverage: table, files_run: string[], worker_outputs: string[]} Runs multiple test files in parallel. Returns aggregated results. @throws table If validation or critical worker execution fails.
---@field configure fun(options?: {workers?: number, timeout?: number, output_buffer_size?: number, verbose?: boolean, show_worker_output?: boolean, fail_fast?: boolean, aggregate_coverage?: boolean, debug?: boolean}): parallel_module Configures the parallel module. Returns self.
---@field reset fun(): parallel_module Resets local configuration to defaults. Returns self.
---@field full_reset fun(): parallel_module Resets local and central configuration. Returns self.
---@field debug_config fun(): table Returns a table with current configuration and state for debugging.
---@field register_with_firmo fun(firmo: table): parallel_module Registers parallel functionality with the Firmo instance. Returns self. @throws table If validation fails.
---@field get_optimal_workers fun(...) [Not Implemented] Get the optimal number of worker processes.
---@field run_file fun(...) [Not Implemented] Run a single test file in a worker process.
---@field aggregate_results fun(...) [Not Implemented] Combine results from multiple worker processes.
---@field cancel_all fun(...) [Not Implemented] Cancel all running processes.
---@field is_running fun(...) [Not Implemented] Check if parallel processes are running.
---@field get_active_processes fun(...) [Not Implemented] Get number of active worker processes.
---@field combine_coverage fun(...) [Not Implemented] Combine coverage data from multiple processes.
---@field monitor_process fun(...) [Not Implemented] Set up process monitoring with callback.
---@field test_runner fun(...) [Not Implemented] Get the currently configured test runner.

local parallel = {}

--- Module version
parallel._VERSION = "1.0.0"

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
    return logging.get_logger("parallel")
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

-- Default configuration
local DEFAULT_CONFIG = {
  workers = 4, -- Default number of worker processes
  timeout = 60, -- Default timeout in seconds per test file
  output_buffer_size = 10240, -- Buffer size for capturing output
  verbose = false, -- Verbose output flag
  show_worker_output = true, -- Show output from worker processes
  fail_fast = false, -- Stop on first failure
  aggregate_coverage = true, -- Combine coverage data from all workers
  debug = false, -- Debug mode
}

-- Current configuration (will be synchronized with central config)
parallel.options = {
  workers = DEFAULT_CONFIG.workers,
  timeout = DEFAULT_CONFIG.timeout,
  output_buffer_size = DEFAULT_CONFIG.output_buffer_size,
  verbose = DEFAULT_CONFIG.verbose,
  show_worker_output = DEFAULT_CONFIG.show_worker_output,
  fail_fast = DEFAULT_CONFIG.fail_fast,
  aggregate_coverage = DEFAULT_CONFIG.aggregate_coverage,
  debug = DEFAULT_CONFIG.debug,
}

local central_config = try_require("lib.core.central_config")

-- Register this module with central_config
central_config.register_module("parallel", {
  -- Schema
  field_types = {
    workers = "number",
    timeout = "number",
    output_buffer_size = "number",
    verbose = "boolean",
    show_worker_output = "boolean",
    fail_fast = "boolean",
    aggregate_coverage = "boolean",
    debug = "boolean",
  },
  field_ranges = {
    workers = { min = 1, max = 64 },
    timeout = { min = 1 },
    output_buffer_size = { min = 1024 },
  },
}, DEFAULT_CONFIG)

--- Registers a listener with central_config to update local config cache when parallel settings change.
---@return boolean success `true` if the listener was registered, `false` otherwise.
---@private
local function register_change_listener()
  -- Register change listener for parallel configuration
  central_config.on_change("parallel", function(path, old_value, new_value)
    get_logger().debug("Configuration change detected", {
      path = path,
      changed_by = "central_config",
    })

    -- Update local configuration from central_config
    local parallel_config = central_config.get("parallel")
    if parallel_config then
      -- Update configuration values
      for key, value in pairs(parallel_config) do
        if parallel.options[key] ~= nil and parallel.options[key] ~= value then
          parallel.options[key] = value
          get_logger().debug("Updated configuration from central_config", {
            key = key,
            value = value,
          })
        end
      end

      -- Update logging configuration if debug/verbose changed
      if parallel.options.debug ~= nil or parallel.options.verbose ~= nil then
        get_logging().configure_from_options("parallel", {
          debug = parallel.options.debug,
          verbose = parallel.options.verbose,
        })
      end

      get_logger().debug("Applied configuration changes from central_config")
    end
  end)

  get_logger().debug("Registered change listener for central configuration")
  return true
end

--- Configures the parallel module, merging provided options with defaults and central config.
---@param options? {workers?: number, timeout?: number, output_buffer_size?: number, verbose?: boolean, show_worker_output?: boolean, fail_fast?: boolean, aggregate_coverage?: boolean, debug?: boolean} Configuration options.
---@return parallel_module self The module instance (`parallel`) for chaining.
function parallel.configure(options)
  options = options or {}

  get_logger().debug("Configuring parallel module", {
    options = options,
  })

  -- Get existing central config values
  local parallel_config = central_config.get("parallel")

  -- Apply central configuration (with defaults as fallback)
  if parallel_config then
    get_logger().debug("Using central_config values for initialization", {
      workers = parallel_config.workers,
      timeout = parallel_config.timeout,
    })

    -- Apply each configuration option with fallbacks to defaults
    for key, default_value in pairs(DEFAULT_CONFIG) do
      parallel.options[key] = parallel_config[key] ~= nil and parallel_config[key] or default_value
    end
  else
    get_logger().debug("No central_config values found, using defaults")
    -- Reset to defaults
    for key, value in pairs(DEFAULT_CONFIG) do
      parallel.options[key] = value
    end
  end

  -- Register change listener if not already done
  register_change_listener()

  -- Apply user options (highest priority) and update central config
  for key, value in pairs(options) do
    if parallel.options[key] ~= nil then
      -- Apply local option
      parallel.options[key] = value

      -- Update central_config if available
      if central_config then
        central_config.set("parallel." .. key, value)
      end
    end
  end

  -- Configure logging
  get_logging().configure_from_options("parallel", {
    debug = parallel.options.debug,
    verbose = parallel.options.verbose,
  })

  get_logger().debug("Parallel module configuration complete", {
    workers = parallel.options.workers,
    timeout = parallel.options.timeout,
    output_buffer_size = parallel.options.output_buffer_size,
    verbose = parallel.options.verbose,
    show_worker_output = parallel.options.show_worker_output,
    fail_fast = parallel.options.fail_fast,
    aggregate_coverage = parallel.options.aggregate_coverage,
    debug = parallel.options.debug,
    using_central_config = central_config ~= nil,
  })

  return parallel
end

-- Initialize the module
parallel.configure()

-- Store reference to firmo
parallel.firmo = nil

-- Test result aggregation class
---@class Results A helper class to aggregate results from multiple parallel test runs.
---@field passed number Total passed tests.
---@field failed number Total failed tests.
---@field skipped number Total skipped tests.
---@field pending number Total pending tests.
---@field total number Total tests executed/counted.
---@field errors table[] List of error details `{file, message, traceback}`.
---@field elapsed number Total elapsed time for the entire parallel run.
---@field coverage table Aggregated coverage data (if enabled).
---@field files_run string[] List of files that were executed.
---@field worker_outputs string[] List of raw outputs captured from worker processes.
local Results = {}
Results.__index = Results

--- Creates a new, empty Results aggregation object.
---@return Results instance
function Results.new()
  local self = setmetatable({}, Results)
  self.passed = 0
  self.failed = 0
  self.skipped = 0
  self.pending = 0
  self.total = 0
  self.errors = {}
  self.elapsed = 0
  self.coverage = {}
  self.files_run = {}
  self.worker_outputs = {} -- Store the outputs from each worker
  return self
end

--- Adds the results and output from a single worker process (test file run) to the aggregated results.
---@param self Results The aggregation object.
---@param file string The path of the file that was run.
---@param result {total: number, passed: number, failed: number, skipped: number, pending: number, errors?: table[], elapsed?: number, coverage?: table, success: boolean} The result summary from the worker.
---@param output? string The captured stdout/stderr from the worker process.
---@return nil
function Results:add_file_result(file, result, output)
  self.total = self.total + (result.total or 0)
  self.passed = self.passed + (result.passed or 0)
  self.failed = self.failed + result.failed
  self.skipped = self.skipped + result.skipped
  self.pending = self.pending + result.pending

  if result.elapsed then
    self.elapsed = self.elapsed + result.elapsed
  end

  -- Add file to list of run files
  table.insert(self.files_run, file)

  -- Store the worker output
  if output then
    table.insert(self.worker_outputs, output)
  end

  -- Add any errors
  if result.errors and #result.errors > 0 then
    for _, err in ipairs(result.errors) do
      table.insert(self.errors, {
        file = file,
        message = err.message,
        traceback = err.traceback,
      })
    end
  end

  -- Add coverage data if available
  if result.coverage and parallel.options.aggregate_coverage then
    for file_path, file_data in pairs(result.coverage) do
      -- Merge coverage data
      if not self.coverage[file_path] then
        self.coverage[file_path] = file_data
      else
        -- Merge line coverage
        if file_data.lines then
          for line, count in pairs(file_data.lines) do
            self.coverage[file_path].lines[line] = (self.coverage[file_path].lines[line] or 0) + count
          end
        end

        -- Merge function coverage
        if file_data.functions then
          for func, count in pairs(file_data.functions) do
            self.coverage[file_path].functions[func] = (self.coverage[file_path].functions[func] or 0) + count
          end
        end
      end
    end
  end
end

--- Executes a single test file in a separate Lua process.
--- Builds the command line arguments based on options (coverage, tags, filter, timeout).
--- Captures stdout/stderr, parses basic results from output, and returns them.
---@param file string Absolute path to the test file.
---@param options {coverage?: boolean, tags?: string[], filter?: string, timeout?: number, verbose?: boolean} Options for the run.
---@return {result: {total: number, passed: number, failed: number, skipped: number, pending: number, errors: table[], elapsed: number, success: boolean}, output: string, elapsed: number, success: boolean} Results table containing parsed counts, captured output, total time, and process success flag.
---@private
local function run_test_file(file, options)
  -- Build command to run test file
  local cmd = "lua " .. file

  -- Add coverage option if enabled
  if options.coverage then
    cmd = cmd .. " --coverage"
  end

  -- Add tag filters if specified
  if options.tags and #options.tags > 0 then
    for _, tag in ipairs(options.tags) do
      cmd = cmd .. " --tag " .. tag
    end
  end

  -- Add filter pattern if specified
  if options.filter then
    cmd = cmd .. ' --filter "' .. options.filter .. '"'
  end

  -- Add option to output results as JSON for parsing
  cmd = cmd .. " --results-format json"

  -- Add timeout
  local timeout_cmd = ""
  if package.config:sub(1, 1) == "\\" then
    -- Windows - timeout not directly available, but we can use timeout.exe from coreutils if available
    timeout_cmd = "timeout " .. options.timeout .. " "
  else
    -- Unix systems have timeout command
    timeout_cmd = "timeout " .. options.timeout .. " "
  end

  -- Combine commands
  cmd = timeout_cmd .. cmd

  -- Execute command and capture output
  local start_time = os.clock()
  local temp_file = try_require("lib.tools.filesystem.temp_file")
  local result_file = temp_file.generate_temp_path("out")
  temp_file.register_file(result_file)

  -- Redirect output to temporary file to capture it
  cmd = cmd .. " > " .. result_file .. " 2>&1"

  if options.verbose then
    get_logger().debug("Running test file", { command = cmd, file = file })
    -- Keep console output for verbose mode
    io.write("Running: " .. cmd .. "\n")
  else
    get_logger().debug("Running test file", { file = file })
  end

  -- Execute the command
  local exit_code = os.execute(cmd)
  local elapsed = os.clock() - start_time

  -- Read the command output
  local output = ""
  local content, err = get_fs().read_file(result_file)
  if content then
    output = content
    -- No need to delete the file manually - it will be automatically cleaned up
    -- by the temp_file management system
  else
    get_logger().warn("Failed to read result file", { file = result_file, error = err })
  end

  -- Parse the JSON results from the output
  local result = {
    total = 0,
    passed = 0,
    failed = 0,
    skipped = 0,
    pending = 0,
    errors = {},
    elapsed = elapsed,
    success = exit_code == 0 or exit_code == true,
  }

  -- Extract JSON data from the output if present
  local json_data = output:match("RESULTS_JSON_BEGIN(.-)RESULTS_JSON_END")

  -- Alternative approach: Count results directly from the output
  local clean_output = output:gsub("\027%[[^m]*m", "") -- Remove ANSI color codes
  local pass_count = 0
  local fail_count = 0
  local skip_count = 0

  for line in clean_output:gmatch("[^\r\n]+") do
    if line:match("PASS%s+should") then
      pass_count = pass_count + 1
    elseif line:match("FAIL%s+should") then
      fail_count = fail_count + 1
    elseif line:match("SKIP%s+should") or line:match("PENDING:%s+") then
      skip_count = skip_count + 1
    end
  end

  -- Update result with counted data
  result.total = pass_count + fail_count + skip_count
  result.passed = pass_count
  result.failed = fail_count
  result.skipped = skip_count

  -- Also try to extract error messages
  for line in clean_output:gmatch("[^\r\n]+") do
    if line:match("FAIL%s+should") then
      local error_msg = line:match("FAIL%s+(.*)")
      if error_msg then
        table.insert(result.errors, {
          message = "Test failed: " .. error_msg,
          traceback = "",
        })
      end
    end
  end

  return {
    result = result,
    output = output,
    elapsed = elapsed,
    success = exit_code == 0 or exit_code == true,
  }
end

--- Runs multiple test files in parallel using separate Lua processes.
--- Manages worker execution, aggregates results, handles timeouts and fail-fast logic.
---@param files string[] Array of absolute file paths to run.
---@param options? {workers?: number, timeout?: number, verbose?: boolean, show_worker_output?: boolean, fail_fast?: boolean, aggregate_coverage?: boolean, coverage?: boolean, tags?: string[], filter?: string} Run options, merged with module defaults.
---@return Results aggregated_results An object containing the combined results from all test runs.
---@throws table If critical errors occur during setup or worker execution (though many errors are caught and added to results.errors).
function parallel.run_tests(files, options)
  options = options or {}

  -- Merge with default options
  for k, v in pairs(parallel.options) do
    if options[k] == nil then
      options[k] = v
    end
  end

  get_logger().info("Starting parallel test execution", {
    file_count = #files,
    worker_count = options.workers,
    timeout = options.timeout,
    fail_fast = options.fail_fast,
  })

  if options.verbose then
    io.write("Running " .. #files .. " test files with " .. options.workers .. " workers\n")
  end

  -- Create results object
  local results = Results.new()
  local start_time = os.clock()

  -- Set up worker tracking
  local next_file = 1
  local active_workers = 0
  local failures = 0

  -- Process test files in batches
  while next_file <= #files or active_workers > 0 do
    -- Start new workers until we reach the maximum or run out of files
    while active_workers < options.workers and next_file <= #files do
      local file = files[next_file]
      next_file = next_file + 1
      active_workers = active_workers + 1

      if options.verbose then
        get_logger().debug("Starting worker", { file = file, worker_id = active_workers })
        io.write("Starting worker for: " .. file .. "\n")
      end

      -- Run the test file and process results
      local worker_result = run_test_file(file, options)

      -- Log worker completion
      get_logger().debug("Worker completed", {
        file = file,
        success = worker_result.success,
        elapsed = worker_result.elapsed,
      })

      -- Show worker output if requested
      if options.show_worker_output then
        io.write("\n--- Output from " .. file .. " ---\n")
        io.write(worker_result.output .. "\n")
        io.write("--- End output from " .. file .. " ---\n\n")
      end

      -- Add results to aggregated results
      results:add_file_result(file, worker_result.result, worker_result.output)

      -- Check for failure
      if not worker_result.success then
        failures = failures + 1
        if options.fail_fast and failures > 0 then
          get_logger().warn("Stopping parallel execution due to failure", {
            fail_fast = true,
            failure_count = failures,
            file = file,
          })

          if options.verbose then
            io.write("Stopping due to failure (fail_fast is enabled)\n")
          end
          break
        end
      end

      -- Decrement active workers counter
      active_workers = active_workers - 1

      -- Add a small sleep to allow other processes to run
      local function sleep(ms)
        local start = os.clock()
        while os.clock() - start < ms / 1000 do
        end
      end
      sleep(10) -- 10ms
    end

    -- If we're stopping due to failure, break the loop
    if options.fail_fast and failures > 0 then
      break
    end

    -- Small sleep to prevent CPU hogging
    if active_workers > 0 then
      local function sleep(ms)
        local start = os.clock()
        while os.clock() - start < ms / 1000 do
        end
      end
      sleep(50) -- 50ms
    end
  end

  -- Calculate total elapsed time
  results.elapsed = os.clock() - start_time

  return results
end

--- Registers the parallel module with the Firmo instance, adding CLI options and patching `cli_run`.
---@param firmo table The Firmo framework instance.
---@return parallel_module self The parallel module instance (`parallel`).
---@throws table If `firmo` validation fails critically.
function parallel.register_with_firmo(firmo)
  -- Store reference to firmo
  parallel.firmo = firmo

  -- Add parallel functionality to firmo
  firmo.parallel = parallel

  -- Add CLI options for parallel execution
  local original_cli_run = firmo.cli_run
  if original_cli_run then
    firmo.cli_run = function(args)
      -- Parse for parallel-specific options
      local parallel_options = {
        enabled = false,
        workers = parallel.options.workers,
        timeout = parallel.options.timeout,
        verbose = parallel.options.verbose,
        show_worker_output = parallel.options.show_worker_output,
        fail_fast = parallel.options.fail_fast,
        aggregate_coverage = parallel.options.aggregate_coverage,
      }

      local i = 1
      while i <= #args do
        local arg = args[i]

        if arg == "--parallel" or arg == "-p" then
          parallel_options.enabled = true
          i = i + 1
        elseif arg == "--workers" or arg == "-w" and args[i + 1] then
          parallel_options.workers = tonumber(args[i + 1]) or parallel.options.workers
          -- Update central_config if available
          if central_config and parallel_options.workers then
            central_config.set("parallel.workers", parallel_options.workers)
            get_logger().debug("Updated workers in central_config from CLI", {
              workers = parallel_options.workers,
            })
          end
          i = i + 2
        elseif arg == "--timeout" and args[i + 1] then
          parallel_options.timeout = tonumber(args[i + 1]) or parallel.options.timeout
          -- Update central_config if available
          if central_config and parallel_options.timeout then
            central_config.set("parallel.timeout", parallel_options.timeout)
            get_logger().debug("Updated timeout in central_config from CLI", {
              timeout = parallel_options.timeout,
            })
          end
          i = i + 2
        elseif arg == "--verbose-parallel" then
          parallel_options.verbose = true
          -- Update central_config if available
          if central_config then
            central_config.set("parallel.verbose", true)
            get_logger().debug("Updated verbose in central_config from CLI")
          end
          i = i + 1
        elseif arg == "--no-worker-output" then
          parallel_options.show_worker_output = false
          -- Update central_config if available
          if central_config then
            central_config.set("parallel.show_worker_output", false)
            get_logger().debug("Updated show_worker_output in central_config from CLI")
          end
          i = i + 1
        elseif arg == "--fail-fast" then
          parallel_options.fail_fast = true
          -- Update central_config if available
          if central_config then
            central_config.set("parallel.fail_fast", true)
            get_logger().debug("Updated fail_fast in central_config from CLI")
          end
          i = i + 1
        elseif arg == "--no-aggregate-coverage" then
          parallel_options.aggregate_coverage = false
          central_config.set("parallel.aggregate_coverage", false)
          get_logger().debug("Updated aggregate_coverage in central_config from CLI")
          i = i + 1
        else
          i = i + 1
        end
      end

      -- If parallel mode is not enabled, use the original cli_run
      if not parallel_options.enabled then
        return original_cli_run(args)
      end

      -- If we get here, we're running in parallel mode
      local options = firmo.parse_cli_options(args)

      -- Discover test files
      local files
      if #options.files > 0 then
        files = options.files
      else
        files = firmo.discover(options.dir, options.pattern)
      end

      if #files == 0 then
        get_logger().warn("No test files found for parallel execution")
        io.write("No test files found\n")
        return false
      end

      get_logger().info("Starting CLI parallel test execution", {
        file_count = #files,
        worker_count = parallel_options.workers,
        timeout = parallel_options.timeout,
        coverage_enabled = options.coverage,
        tags = options.tags,
        filter = options.filter,
      })

      io.write("Running " .. #files .. " test files in parallel with " .. parallel_options.workers .. " workers\n")

      -- Run tests in parallel
      local results = parallel.run_tests(files, {
        workers = parallel_options.workers,
        timeout = parallel_options.timeout,
        verbose = parallel_options.verbose,
        show_worker_output = parallel_options.show_worker_output,
        fail_fast = parallel_options.fail_fast,
        aggregate_coverage = parallel_options.aggregate_coverage,
        coverage = options.coverage,
        tags = options.tags,
        filter = options.filter,
      })

      -- Log summary results
      get_logger().info("Parallel test execution completed", {
        files_tested = #results.files_run,
        total = results.total,
        passed = results.passed,
        failed = results.failed,
        skipped = results.skipped,
        pending = results.pending,
        elapsed_seconds = results.elapsed,
        error_count = #results.errors,
      })

      -- Display summary for console
      io.write("\nParallel Test Summary:\n")
      io.write("  Files tested: " .. #results.files_run .. "\n")
      io.write("  Total tests: " .. results.total .. "\n")
      io.write("  Passed: " .. results.passed .. "\n")
      io.write("  Failed: " .. results.failed .. "\n")
      io.write("  Skipped: " .. results.skipped .. "\n")
      io.write("  Pending: " .. results.pending .. "\n")
      io.write("  Total time: " .. string.format("%.2f", results.elapsed) .. " seconds\n")

      -- Log and display errors
      if #results.errors > 0 then
        -- Log errors with detailed information
        for i, err in ipairs(results.errors) do
          get_logger().error("Test failure in parallel execution", {
            index = i,
            file = err.file,
            message = err.message,
            traceback = err.traceback,
          })
        end

        -- Display errors in console
        io.write("\nErrors:\n")
        for i, err in ipairs(results.errors) do
          io.write("  " .. i .. ". In file: " .. err.file .. "\n")
          io.write("     " .. err.message .. "\n")
          if parallel_options.verbose and err.traceback then
            io.write("     " .. err.traceback .. "\n")
          end
        end
      end

      -- Generate reports if coverage was enabled
      if options.coverage and parallel_options.aggregate_coverage and firmo.coverage then
        -- Convert coverage data to the format expected by the reporting module
        local coverage_data = {
          files = results.coverage,
          summary = {
            total_files = 0,
            covered_files = 0,
            total_lines = 0,
            covered_lines = 0,
            total_functions = 0,
            covered_functions = 0,
          },
        }

        -- Generate reports
        if firmo.reporting then
          local report_config = firmo.report_config or {}

          get_logger().info("Generating coverage reports from parallel execution", {
            report_config = report_config,
            files_to_report = coverage_data.summary.total_files,
          })

          firmo.reporting.auto_save_reports(coverage_data, nil, nil, report_config)
          io.write("\nCoverage reports generated from parallel execution\n")
        end
      end

      -- Return success status
      return results.failed == 0
    end
  end

  -- Parse CLI options - helper function used by parallel mode
  function firmo.parse_cli_options(args)
    local options = {
      dir = "./tests",
      pattern = "*_test.lua",
      files = {},
      tags = {},
      filter = nil,
      coverage = false,
      quality = false,
      quality_level = 1,
      watch = false,
      interactive = false,
      format = "html",
      report_dir = "./coverage-reports",
      report_suffix = "",
      coverage_path_template = nil,
      quality_path_template = nil,
      results_path_template = nil,
      timestamp_format = "%Y-%m-%d",
      verbose = false,
      formatter_module = nil,
      coverage_format = nil,
      quality_format = nil,
      results_format = nil,
    }

    local i = 1
    while i <= #args do
      local arg = args[i]

      if arg == "--coverage" or arg == "-c" then
        options.coverage = true
        i = i + 1
      elseif arg == "--quality" or arg == "-q" then
        options.quality = true
        i = i + 1
      elseif arg == "--quality-level" or arg == "-ql" then
        if args[i + 1] then
          options.quality_level = tonumber(args[i + 1]) or 1
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--watch" or arg == "-w" then
        options.watch = true
        i = i + 1
      elseif arg == "--interactive" or arg == "-i" then
        options.interactive = true
        i = i + 1
      elseif arg == "--format" or arg == "-f" then
        if args[i + 1] then
          options.format = args[i + 1]
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--dir" or arg == "-d" then
        if args[i + 1] then
          options.dir = args[i + 1]
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--pattern" or arg == "-p" then
        if args[i + 1] then
          options.pattern = args[i + 1]
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--tag" or arg == "-t" then
        if args[i + 1] then
          table.insert(options.tags, args[i + 1])
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--filter" and args[i + 1] then
        options.filter = args[i + 1]
        i = i + 2
      -- Report configuration options
      elseif arg == "--output-dir" and args[i + 1] then
        options.report_dir = args[i + 1]
        i = i + 2
      elseif arg == "--report-suffix" and args[i + 1] then
        options.report_suffix = args[i + 1]
        i = i + 2
      elseif arg == "--coverage-path" and args[i + 1] then
        options.coverage_path_template = args[i + 1]
        i = i + 2
      elseif arg == "--quality-path" and args[i + 1] then
        options.quality_path_template = args[i + 1]
        i = i + 2
      elseif arg == "--results-path" and args[i + 1] then
        options.results_path_template = args[i + 1]
        i = i + 2
      elseif arg == "--timestamp-format" and args[i + 1] then
        options.timestamp_format = args[i + 1]
        i = i + 2
      elseif arg == "--verbose-reports" then
        options.verbose = true
        i = i + 1
      -- Custom formatter options
      elseif arg == "--coverage-format" and args[i + 1] then
        options.coverage_format = args[i + 1]
        i = i + 2
      elseif arg == "--quality-format" and args[i + 1] then
        options.quality_format = args[i + 1]
        i = i + 2
      elseif arg == "--results-format" and args[i + 1] then
        options.results_format = args[i + 1]
        i = i + 2
      elseif arg == "--formatter-module" and args[i + 1] then
        options.formatter_module = args[i + 1]
        i = i + 2
      elseif arg == "--help" or arg == "-h" then
        i = i + 1
      elseif not arg:match("^%-") then
        -- Not a flag, assume it's a file
        table.insert(options.files, arg)
        i = i + 1
      else
        -- Skip unknown options
        i = i + 1
      end
    end

    return options
  end

  -- Extend help text to include parallel options
  local original_show_help = firmo.show_help
  if original_show_help then
    firmo.show_help = function()
      original_show_help()

      get_logger().debug("Displaying parallel execution help options")

      logging.info("\nParallel Execution Options:")
      logging.info("  --parallel, -p            Run tests in parallel")
      logging.info("  --workers, -w <num>       Number of worker processes (default: 4)")
      logging.info("  --timeout <seconds>       Timeout for each test file (default: 60)")
      logging.info("  --verbose-parallel        Show verbose output from parallel execution")
      logging.info("  --no-worker-output        Hide output from worker processes")
      logging.info("  --fail-fast               Stop on first test failure")
      logging.info("  --no-aggregate-coverage   Don't combine coverage data from workers")
    end
  end

  return firmo
end

--- Resets the parallel module's local configuration to defaults.
---@return parallel_module self The module instance (`parallel`) for method chaining.
function parallel.reset()
  get_logger().debug("Resetting parallel module configuration to defaults")

  -- Reset configuration to defaults
  for key, value in pairs(DEFAULT_CONFIG) do
    parallel.options[key] = value
  end

  return parallel
end

--- Resets local configuration (`parallel.reset()`) and attempts to reset the "parallel"
--- section in the central configuration system. Also clears `file_timestamps`.
---@return parallel_module self The module instance (`parallel`) for method chaining.
function parallel.full_reset()
  -- Reset local configuration
  parallel.reset()

  central_config.reset("parallel")
  get_logger().debug("Reset central configuration for parallel module")

  return parallel
end

--- Returns a table containing the current configuration settings (local cache and central config) for debugging.
---@return table debug_info Detailed information: `{ local_config, using_central_config, central_config }`.
function parallel.debug_config()
  local debug_info = {
    local_config = {},
    using_central_config = false,
    central_config = nil,
  }

  -- Copy local configuration
  for key, value in pairs(parallel.options) do
    debug_info.local_config[key] = value
  end

  debug_info.using_central_config = true
  debug_info.central_config = central_config.get("parallel")

  -- Display configuration
  get_logger().info("Parallel module configuration", debug_info)

  return debug_info
end

-- Return the module
return parallel
