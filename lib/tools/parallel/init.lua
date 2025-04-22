-- Parallel test execution module for firmo
-- Provides functionality to run test files in parallel for better resource utilization

---@class parallel_module
---@field _VERSION string Module version
---@field options {workers?: number, timeout?: number, print_output?: boolean, combine_coverage?: boolean, isolate_state?: boolean, memory_limit?: number, show_progress?: boolean, fail_fast?: boolean, randomize?: boolean} Configuration options for parallel execution
---@field run_files fun(files: string[], options?: {workers?: number, timeout?: number, print_output?: boolean, combine_coverage?: boolean}): {results: table<string, {success: boolean, duration: number, error?: string, tests: number, failures: number, errors: number, skipped: number, test_list: table<number, table>}>, summary: {total_files: number, successful_files: number, failed_files: number, total_duration: number, total_tests: number, total_failures: number, total_errors: number, total_skipped: number}} Run multiple test files in parallel
---@field configure fun(options?: {workers?: number, timeout?: number, print_output?: boolean, combine_coverage?: boolean, isolate_state?: boolean, memory_limit?: number, show_progress?: boolean}): parallel_module Configure the parallel module
---@field reset fun(): parallel_module Reset the module to default configuration
---@field full_reset fun(): parallel_module Fully reset both local and central configuration
---@field debug_config fun(): {workers: number, timeout: number, print_output: boolean, combine_coverage: boolean, isolate_state: boolean, memory_limit: number, show_progress: boolean, fail_fast: boolean, randomize: boolean, using_central_config: boolean, central_config: table|nil} Debug helper to show current configuration
---@field get_optimal_workers fun(): number Get the optimal number of worker processes for the current system
---@field run_file fun(file_path: string, options?: {timeout?: number, print_output?: boolean, isolate_state?: boolean, args?: table}): {success: boolean, duration: number, error?: string, tests: number, failures: number, errors: number, skipped: number, test_list: table<number, table>}|nil, string? Run a single test file in a worker process
---@field aggregate_results fun(results: table<string, table>): {summary: {total_files: number, successful_files: number, failed_files: number, total_duration: number, total_tests: number, total_failures: number, total_errors: number, total_skipped: number}, results: table<string, table>} Combine results from multiple worker processes
---@field cancel_all fun(): boolean Cancel all running processes
---@field is_running fun(): boolean Check if parallel processes are running
---@field get_active_processes fun(): number Get number of active worker processes
---@field combine_coverage fun(coverage_data_list: table[]): table Combine coverage data from multiple processes
---@field monitor_process fun(process_id: string, callback: function): boolean Set up process monitoring with callback
---@field test_runner fun(): table Get the currently configured test runner

local parallel = {}
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

-- Initialize module logger
local logger = logging.get_logger("parallel")

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

-- Lazy loading of central_config to avoid circular dependencies
local _central_config

local function get_central_config()
  if not _central_config then
    -- Use pcall to safely attempt loading central_config
    local success, central_config = pcall(require, "lib.core.central_config")
    if success then
      _central_config = central_config

      -- Register this module with central_config
      _central_config.register_module("parallel", {
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

      logger.debug("Successfully loaded central_config", {
        module = "parallel",
      })
    else
      logger.debug("Failed to load central_config", {
        error = tostring(central_config),
      })
    end
  end

  return _central_config
end

-- Set up change listener for central configuration
local function register_change_listener()
  local central_config = get_central_config()
  if not central_config then
    logger.debug("Cannot register change listener - central_config not available")
    return false
  end

  -- Register change listener for parallel configuration
  central_config.on_change("parallel", function(path, old_value, new_value)
    logger.debug("Configuration change detected", {
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
          logger.debug("Updated configuration from central_config", {
            key = key,
            value = value,
          })
        end
      end

      -- Update logging configuration if debug/verbose changed
      if parallel.options.debug ~= nil or parallel.options.verbose ~= nil then
        logging.configure_from_options("parallel", {
          debug = parallel.options.debug,
          verbose = parallel.options.verbose,
        })
      end

      logger.debug("Applied configuration changes from central_config")
    end
  end)

  logger.debug("Registered change listener for central configuration")
  return true
end

-- Configure the module
--- Configure the parallel module with custom options
---@param options? table Configuration options to override defaults
---@return parallel_module The module instance for method chaining
function parallel.configure(options)
  options = options or {}

  logger.debug("Configuring parallel module", {
    options = options,
  })

  -- Check for central configuration first
  local central_config = get_central_config()
  if central_config then
    -- Get existing central config values
    local parallel_config = central_config.get("parallel")

    -- Apply central configuration (with defaults as fallback)
    if parallel_config then
      logger.debug("Using central_config values for initialization", {
        workers = parallel_config.workers,
        timeout = parallel_config.timeout,
      })

      -- Apply each configuration option with fallbacks to defaults
      for key, default_value in pairs(DEFAULT_CONFIG) do
        parallel.options[key] = parallel_config[key] ~= nil and parallel_config[key] or default_value
      end
    else
      logger.debug("No central_config values found, using defaults")
      -- Reset to defaults
      for key, value in pairs(DEFAULT_CONFIG) do
        parallel.options[key] = value
      end
    end

    -- Register change listener if not already done
    register_change_listener()
  else
    logger.debug("central_config not available, using defaults")
    -- Apply defaults
    for key, value in pairs(DEFAULT_CONFIG) do
      parallel.options[key] = value
    end
  end

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
  logging.configure_from_options("parallel", {
    debug = parallel.options.debug,
    verbose = parallel.options.verbose,
  })

  logger.debug("Parallel module configuration complete", {
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

-- Test result aggregation
local Results = {}
Results.__index = Results

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

function Results:add_file_result(file, result, output)
  self.total = self.total + result.total
  self.passed = self.passed + result.passed
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

-- Helper function to run a test file in a separate process
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
  local temp_file = require("lib.tools.filesystem.temp_file")
  local result_file = temp_file.generate_temp_path("out")
  temp_file.register_file(result_file)

  -- Redirect output to temporary file to capture it
  cmd = cmd .. " > " .. result_file .. " 2>&1"

  if options.verbose then
    logger.debug("Running test file", { command = cmd, file = file })
    -- Keep console output for verbose mode
    io.write("Running: " .. cmd .. "\n")
  else
    logger.debug("Running test file", { file = file })
  end

  -- Execute the command
  local exit_code = os.execute(cmd)
  local elapsed = os.clock() - start_time

  -- Read the command output
  local output = ""
  local content, err = fs.read_file(result_file)
  if content then
    output = content
    -- No need to delete the file manually - it will be automatically cleaned up
    -- by the temp_file management system
  else
    logger.warn("Failed to read result file", { file = result_file, error = err })
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

-- Run tests in parallel across multiple processes
--- Run multiple test files in parallel worker processes
---@param files table Array of file paths to run
---@param options? table Run options
---@return table results Combined results from all test runs
function parallel.run_tests(files, options)
  options = options or {}

  -- Merge with default options
  for k, v in pairs(parallel.options) do
    if options[k] == nil then
      options[k] = v
    end
  end

  logger.info("Starting parallel test execution", {
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
        logger.debug("Starting worker", { file = file, worker_id = active_workers })
        io.write("Starting worker for: " .. file .. "\n")
      end

      -- Run the test file and process results
      local worker_result = run_test_file(file, options)

      -- Log worker completion
      logger.debug("Worker completed", {
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
          logger.warn("Stopping parallel execution due to failure", {
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

-- Register with firmo
--- Register parallel testing functionality with the firmo framework
---@param firmo table The firmo framework instance
---@return parallel_module The parallel module instance
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
          local central_config = get_central_config()
          if central_config and parallel_options.workers then
            central_config.set("parallel.workers", parallel_options.workers)
            logger.debug("Updated workers in central_config from CLI", {
              workers = parallel_options.workers,
            })
          end
          i = i + 2
        elseif arg == "--timeout" and args[i + 1] then
          parallel_options.timeout = tonumber(args[i + 1]) or parallel.options.timeout
          -- Update central_config if available
          local central_config = get_central_config()
          if central_config and parallel_options.timeout then
            central_config.set("parallel.timeout", parallel_options.timeout)
            logger.debug("Updated timeout in central_config from CLI", {
              timeout = parallel_options.timeout,
            })
          end
          i = i + 2
        elseif arg == "--verbose-parallel" then
          parallel_options.verbose = true
          -- Update central_config if available
          local central_config = get_central_config()
          if central_config then
            central_config.set("parallel.verbose", true)
            logger.debug("Updated verbose in central_config from CLI")
          end
          i = i + 1
        elseif arg == "--no-worker-output" then
          parallel_options.show_worker_output = false
          -- Update central_config if available
          local central_config = get_central_config()
          if central_config then
            central_config.set("parallel.show_worker_output", false)
            logger.debug("Updated show_worker_output in central_config from CLI")
          end
          i = i + 1
        elseif arg == "--fail-fast" then
          parallel_options.fail_fast = true
          -- Update central_config if available
          local central_config = get_central_config()
          if central_config then
            central_config.set("parallel.fail_fast", true)
            logger.debug("Updated fail_fast in central_config from CLI")
          end
          i = i + 1
        elseif arg == "--no-aggregate-coverage" then
          parallel_options.aggregate_coverage = false
          -- Update central_config if available
          local central_config = get_central_config()
          if central_config then
            central_config.set("parallel.aggregate_coverage", false)
            logger.debug("Updated aggregate_coverage in central_config from CLI")
          end
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
        logger.warn("No test files found for parallel execution")
        io.write("No test files found\n")
        return false
      end

      logger.info("Starting CLI parallel test execution", {
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
      logger.info("Parallel test execution completed", {
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
          logger.error("Test failure in parallel execution", {
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

          logger.info("Generating coverage reports from parallel execution", {
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

      logger.debug("Displaying parallel execution help options")

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

-- Reset the module configuration to defaults
--- Reset the module to default configuration
---@return parallel_module The module instance for method chaining
function parallel.reset()
  logger.debug("Resetting parallel module configuration to defaults")

  -- Reset configuration to defaults
  for key, value in pairs(DEFAULT_CONFIG) do
    parallel.options[key] = value
  end

  return parallel
end

-- Fully reset both local and central configuration
--- Fully reset both local and central configuration
---@return parallel_module The module instance for method chaining
function parallel.full_reset()
  -- Reset local configuration
  parallel.reset()

  -- Reset central configuration if available
  local central_config = get_central_config()
  if central_config then
    central_config.reset("parallel")
    logger.debug("Reset central configuration for parallel module")
  end

  return parallel
end

-- Debug helper to show current configuration
--- Debug helper to show current configuration
---@return table debug_info Detailed information about the current configuration
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

  -- Check for central_config
  local central_config = get_central_config()
  if central_config then
    debug_info.using_central_config = true
    debug_info.central_config = central_config.get("parallel")
  end

  -- Display configuration
  logger.info("Parallel module configuration", debug_info)

  return debug_info
end

-- Return the module
return parallel
