---@class TestRunner The public API of the test runner module.
---@field run_file fun(file: string): {success: boolean, passes: number, errors: number, skipped: number, file: string}, table|nil Runs a single test file. Returns results table and optional error object.
---@field run_discovered fun(dir?: string, pattern?: string): boolean, table|nil Discovers and runs test files. Returns overall success flag and optional error object.
---@field run_tests fun(files: string[], options?: {parallel?: boolean, coverage?: boolean, verbose?: boolean, timeout?: number}): boolean Runs a list of test files. Returns overall success flag.
---@field execute_test fun(...) [Not Implemented] Execute a single test case and return success status and results.
---@field run_all_tests fun(...) [Not Implemented] Run all tests in multiple files and aggregate results.
---@field configure fun(options: {format?: FormatOptions, parallel?: boolean, coverage?: boolean, verbose?: boolean, timeout?: number, cleanup_temp_files?: boolean}): TestRunner Configures the test runner.
---@field format fun(options: FormatOptions): TestRunner Configures output formatting options.
---@field format_options FormatOptions Current output formatting options.
---@field nocolor fun(): TestRunner Disables colored output.
---@field before_file_run fun(...) [Not Implemented] Register a callback to run before executing each test file.
---@field after_file_run fun(...) [Not Implemented] Register a callback to run after executing each test file.
---@field on_test_error fun(...) [Not Implemented] Register a callback for test execution errors.
---@field get_stats fun(...) [Not Implemented] Get test execution statistics.
---@field set_environment fun(...) [Not Implemented] Set environment variables for test execution.

--- Test Runner Module for Firmo
---
--- This module manages the execution of test files, provides output formatting,
--- and coordinates test lifecycle operations. It serves as the central coordinator
--- for the testing framework, handling test discovery, execution, result collection,
--- and potentially interacting with reporting, coverage, and parallel execution modules.
---
--- Features:
--- - Test file discovery (via `lib.tools.discover` or `lib.tools.filesystem`) and execution.
--- - Basic sequential execution of test files.
--- - Optional parallel execution via `lib.tools.parallel` (if available and configured).
--- - Test state management via `lib.core.test_definition`.
--- - Configurable output formatting (`use_color`, `indent`, `dot_mode`, `summary_only`).
--- - Integration with `lib.tools.error_handler` for structured errors.
--- - Integration with `lib.tools.filesystem.temp_file` for context setting.
--- - Basic summary reporting to the console.
---
--- @module lib.core.runner
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.4.0

local M = {}

-- Load required modules
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
    return logging.get_logger("runner")
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

-- Load mandatory modules with fatal error handling
local discover_module = try_require("lib.tools.discover")
local test_definition = try_require("lib.core.test_definition")
local central_config = try_require("lib.core.central_config")
local parallel_module = try_require("lib.tools.parallel")
local temp_file = try_require("lib.tools.filesystem.temp_file")

--- Output formatting options used by the test runner.
---@field use_color boolean Whether to use ANSI color codes in console output.
---@field indent_char string Character(s) used for one level of indentation (e.g., `"\t"` or `"  "`).
---@field indent_size number Number of `indent_char` repetitions per indentation level.
---@field show_trace boolean If `true`, show stack traces for test failures.
---@field show_success_detail boolean If `true`, show details even for successful tests (usually just the name). If `false`, successful tests might be hidden depending on other options.
---@field compact boolean If `true`, use a more compact output format (implementation specific, may interact with `dot_mode`).
---@field dot_mode boolean If `true`, display `.` for passed tests, `F` for failed, `S` for skipped, reducing output verbosity significantly.
---@field summary_only boolean If `true`, suppress individual test results and only display the final summary counts.

-- Set up default formatter options
M.format_options = {
  use_color = true, -- Whether to use color codes in output
  indent_char = "\t", -- Character to use for indentation (tab or spaces)
  indent_size = 1, -- How many indent_chars to use per level
  show_trace = false, -- Show stack traces for errors
  show_success_detail = true, -- Show details for successful tests
  compact = false, -- Use compact output format (less verbose)
  dot_mode = false, -- Use dot mode (. for pass, F for fail)
  summary_only = false, -- Show only summary, not individual tests
}

-- Set up colors based on format options
--- ANSI color code for red text
---@type string
local red = string.char(27) .. "[31m"

--- ANSI color code for green text
---@type string
local green = string.char(27) .. "[32m"

--- ANSI color code for yellow text
---@type string
local yellow = string.char(27) .. "[33m"

--- ANSI color code for blue text
---@type string
-- Removed unused blue variable
-- local blue = string.char(27) .. "[34m"

--- ANSI color code for magenta text
---@type string
-- Removed unused magenta variable
-- local magenta = string.char(27) .. "[35m"

--- ANSI color code for cyan text
---@type string
local cyan = string.char(27) .. "[36m"

--- ANSI color code to reset text formatting
---@type string
local normal = string.char(27) .. "[0m"

--- Generates an indentation string based on the current test nesting level.
--- Uses the `indent_char` and `indent_size` from `M.format_options`.
--- Retrieves the current level from `test_definition` if available.
---@param level? number Optional indentation level override. Defaults to the current level from `test_definition` or 0.
---@return string The generated indentation string.
---@private
local function indent(level)
  level = level or (test_definition and test_definition.get_state().level or 0)
  local indent_char = M.format_options.indent_char
  local indent_size = M.format_options.indent_size
  return string.rep(indent_char, level * indent_size)
end

--- Disables ANSI color codes in the output by setting `M.format_options.use_color` to false
--- and clearing the internal color variables.
---@return TestRunner The module instance (`M`) for method chaining.
---@throws table If an error occurs while applying the setting (unlikely but possible).
function M.nocolor()
  -- No need for parameter validation as this function takes no parameters
  get_logger().debug("Disabling colors in output", {
    function_name = "nocolor",
  })

  -- Apply change with error handling in case of any terminal-related issues
  local success, err = get_error_handler().try(function()
    M.format_options.use_color = false
    ---@diagnostic disable-next-line: unused-local
    red, green, yellow, blue, magenta, cyan, normal = "", "", "", "", "", "", ""
    return true
  end)

  if not success then
    get_logger().error("Failed to disable colors", {
      error = get_error_handler().format_error(err),
      function_name = "nocolor",
    })
    get_error_handler().throw(
      "Failed to disable colors: " .. get_error_handler().format_error(err),
      get_error_handler().CATEGORY.RUNTIME,
      get_error_handler().SEVERITY.ERROR,
      { function_name = "nocolor" }
    )
  end

  return M
end

--- Configure output formatting options for test result display
--- This function customizes how test results are displayed in the console output.
--- It allows configuration of colors, indentation, verbosity, and output style to
--- suit different terminal environments and user preferences. The function supports
--- method chaining for a fluent configuration API.
---
---@param options {use_color?: boolean, indent_char?: string, indent_size?: number, show_trace?: boolean, show_success_detail?: boolean, compact?: boolean, dot_mode?: boolean, summary_only?: boolean} Formatting options
---@field options.use_color boolean? Whether to use ANSI color codes in output
---@field options.indent_char string? Character to use for indentation (tab or spaces)
---@field options.indent_size number? How many indent_chars to use per level
---@field options.show_trace boolean? Show stack traces for errors
---@field options.show_success_detail boolean? Show details for successful tests
---@field options.compact boolean? Use compact output format (less verbose)
---@field options.dot_mode boolean? Use dot mode (. for pass, F for fail)
---@field options.summary_only boolean? Show only summary, not individual tests
---@return TestRunner The module instance (`M`) for method chaining.
---@throws table If `options` validation fails or applying options fails.
---
---@usage
--- -- Configure runner with colored output
--- runner.format({
---   use_color = true,
---   indent_char = "  ",  -- Two spaces for indentation
---   indent_size = 1,
---   show_trace = true,   -- Show stack traces for errors
---   compact = false      -- Use detailed output
--- })
---
--- -- Configure runner for CI environments (no color, minimal output)
--- runner.format({
---   use_color = false,
---   summary_only = true  -- Only show test counts and final result
--- })
---
--- -- Use dot mode for large test suites
--- runner.format({
---   dot_mode = true      -- Display "." for passed tests, "F" for failed
--- })
---
--- -- Method chaining
--- runner
---   .format({ use_color = true, show_trace = true })
---   .configure({ coverage = true })
---   .run_discovered("tests")
---@param options FormatOptions A table containing formatting options to apply. See `FormatOptions` class definition.
function M.format(options)
  -- Parameter validation
  if options == nil then
    local err = get_error_handler().validation_error("Options cannot be nil", {
      parameter = "options",
      function_name = "format",
    })

    get_logger().error("Parameter validation failed", {
      error = get_error_handler().format_error(err),
      operation = "format",
    })

    get_error_handler().throw(err.message, err.category, err.severity, err.context)
  end

  if type(options) ~= "table" then
    local err = get_error_handler().validation_error("Options must be a table", {
      parameter = "options",
      provided_type = type(options),
      function_name = "format",
    })

    get_logger().error("Parameter validation failed", {
      error = get_error_handler().format_error(err),
      operation = "format",
    })

    get_error_handler().throw(err.message, err.category, err.severity, err.context)
  end

  get_logger().debug("Configuring format options", {
    function_name = "format",
    option_count = (options and type(options) == "table") and #options or 0,
  })

  -- Apply format options with error handling
  local unknown_options = {}
  local success, apply_err = get_error_handler().try(function()
    for k, v in pairs(options) do
      if M.format_options[k] ~= nil then
        M.format_options[k] = v
      else
        table.insert(unknown_options, k)
      end
    end
    return true
  end)

  -- Handle unknown options
  if #unknown_options > 0 then
    local err =
      get_error_handler().validation_error("Unknown format option(s): " .. table.concat(unknown_options, ", "), {
        function_name = "format",
        unknown_options = unknown_options,
        valid_options = (function()
          local opts = {}
          for k, _ in pairs(M.format_options) do
            table.insert(opts, k)
          end
          return table.concat(opts, ", ")
        end)(),
      })

    get_logger().error("Unknown format options provided", {
      error = get_error_handler().format_error(err),
      operation = "format",
      unknown_options = unknown_options,
    })

    get_error_handler().throw(err.message, err.category, err.severity, err.context)
  end

  -- Handle general application errors
  if not success then
    get_logger().error("Failed to apply format options", {
      error = get_error_handler().format_error(apply_err),
      operation = "format",
    })

    get_error_handler().throw(
      "Failed to apply format options: " .. get_error_handler().format_error(apply_err),
      get_error_handler().CATEGORY.RUNTIME,
      get_error_handler().SEVERITY.ERROR,
      { function_name = "format" }
    )
  end

  -- Update colors if needed
  local color_success, color_err = get_error_handler().try(function()
    if not M.format_options.use_color then
      -- Call nocolor but catch errors explicitly here
      M.format_options.use_color = false
      -- Only reset colors that are actually used
      red, green, yellow, cyan, normal = "", "", "", "", ""
    else
      red = string.char(27) .. "[31m"
      green = string.char(27) .. "[32m"
      yellow = string.char(27) .. "[33m"
      -- Removed unused color variables
      cyan = string.char(27) .. "[36m"
      normal = string.char(27) .. "[0m"
    end
    return true
  end)

  if not color_success then
    get_logger().error("Failed to update color settings", {
      error = get_error_handler().format_error(color_err),
      operation = "format",
      use_color = M.format_options.use_color,
    })

    get_error_handler().throw(
      "Failed to update color settings: " .. get_error_handler().format_error(color_err),
      get_error_handler().CATEGORY.RUNTIME,
      get_error_handler().SEVERITY.ERROR,
      { function_name = "format", use_color = M.format_options.use_color }
    )
  end

  get_logger().debug("Format options configured successfully", {
    function_name = "format",
    use_color = M.format_options.use_color,
    show_trace = M.format_options.show_trace,
    indent_char = M.format_options.indent_char == "\t" and "tab" or "space",
  })

  return M
end

--- Configure the test runner with execution and feature options
--- This function sets up the test runner with various execution options,
--- including parallel execution, coverage tracking, verbosity, timeouts,
--- and temporary file management. It coordinates multiple subsystems to
--- create a cohesive testing environment based on the provided configuration.
---
---@param options {format?: table, parallel?: boolean, coverage?: boolean, verbose?: boolean, timeout?: number, cleanup_temp_files?: boolean} Configuration options
---@field options.format table? Output format options for test results (see format() function)
---@field options.parallel boolean? Whether to run tests in parallel across processes
---@field options.coverage boolean? Whether to track code coverage during test execution
---@field options.verbose boolean? Whether to show verbose output including test details
---@field options.timeout number? Timeout in milliseconds for test execution (default: 30000)
---@field options.cleanup_temp_files boolean? Whether to automatically clean up temporary files created via `lib.tools.filesystem.temp_file` (defaults to `true`).
---@return TestRunner The module instance (`M`) for method chaining.
---@throws table If configuration fails (e.g., applying format options, configuring parallel module, configuring temp file system).
---
---@usage
--- -- Basic configuration with coverage
--- runner.configure({
---   coverage = true,
---   verbose = true
--- })
---
--- -- Configure for parallel test execution
--- runner.configure({
---   parallel = true,
---   timeout = 10000,  -- 10 second timeout per test file
---   coverage = true,  -- Track coverage in parallel mode
---   verbose = false   -- Reduce output noise in parallel mode
--- })
---
--- -- Configure with formatting options
--- runner.configure({
---   format = {
---     use_color = true,
---     show_trace = true,
---     dot_mode = false
---   },
---   verbose = true,
---   cleanup_temp_files = true
--- })
---
--- -- Method chaining with both configure and run
--- runner
---   .configure({ coverage = true, parallel = true })
---   .run_discovered("tests", "*_test.lua")
---@param options {format?: FormatOptions, parallel?: boolean, coverage?: boolean, verbose?: boolean, timeout?: number, cleanup_temp_files?: boolean} Configuration options.
function M.configure(options)
  options = options or {}
  -- Apply configuration options with error handling
  local success, err = get_error_handler().try(function()
    -- Configure formatting options
    if options.format then
      M.format(options.format)
    end

    -- Configure parallel execution if available
    if parallel_module and options.parallel then
      parallel_module.configure({
        combine_coverage = options.coverage,
        print_output = options.verbose,
        timeout = options.timeout or 30000,
        show_progress = true,
        isolate_state = true,
      })
    end

    -- Configure temp file system if available
    if temp_file and type(temp_file.configure) == "function" and options.cleanup_temp_files ~= false then -- <<< MODIFIED CONDITION
      temp_file.configure({
        auto_cleanup = true,
        track_files = true,
      })
    elseif temp_file and options.cleanup_temp_files ~= false then
      -- Log a warning if temp_file exists but .configure doesn't, and we intended to call it.
      get_logger().debug(
        "temp_file module loaded but does not have a .configure method. Skipping temp_file configuration.",
        {
          temp_file_type = type(temp_file),
        }
      )
    end

    return true
  end)

  if not success then
    get_logger().error("Failed to configure test runner", {
      error = get_error_handler().format_error(err),
      operation = "configure",
    })

    get_error_handler().throw(
      "Failed to configure test runner: " .. get_error_handler().format_error(err),
      get_error_handler().CATEGORY.CONFIGURATION,
      get_error_handler().SEVERITY.ERROR,
      { function_name = "configure" }
    )
  end

  return M
end

--- Run a single test file and collect test results
--- This function executes a single test file, handling the complete test lifecycle
--- including state setup, file loading, test execution, result collection, temporary
--- file management, and error handling. It provides detailed results about the
--- executed tests, including counts of passed, failed, and skipped tests.
---
---@param file string The path to the test file to execute. Should preferably be an absolute path.
---@return {success: boolean, passes: number, errors: number, skipped: number, file: string}, table|nil results Test execution results (counts and file path), and an optional error object if execution failed catastrophically (e.g., file not found, syntax error).
---@throws table If the `file` parameter validation fails (nil or not a string).
---
---@usage
--- -- Run a single test file and handle results
--- local results, err = runner.run_file("/path/to/my_test.lua")
--- if err then
---   print("Error running test file: " .. err.message)
---   return false
--- end
---
--- if results.success then
---   print("All tests passed: " .. results.passes .. " tests")
--- else
---   print("Test failures: " .. results.errors .. " failed tests")
--- end
---
--- -- Run a file and analyze results
--- local results = runner.run_file("tests/unit/core_test.lua")
--- print(string.format(
---   "Executed %d tests: %d passed, %d failed, %d skipped",
---   results.passes + results.errors + results.skipped,
---   results.passes,
---   results.errors,
---   results.skipped
--- ))
function M.run_file(file)
  -- Parameter validation
  if not file then
    local err = get_error_handler().validation_error("File path cannot be nil", {
      parameter = "file",
      function_name = "run_file",
    })

    get_logger().error("Parameter validation failed", {
      error = get_error_handler().format_error(err),
      operation = "run_file",
    })
    return { success = false, errors = 1 }, err
  end

  if type(file) ~= "string" then
    local err = get_error_handler().validation_error("File path must be a string", {
      parameter = "file",
      provided_type = type(file),
      function_name = "run_file",
    })

    get_logger().error("Parameter validation failed", {
      error = get_error_handler().format_error(err),
      operation = "run_file",
    })
    return { success = false, errors = 1 }, err
  end

  -- Reset test state if test_definition module is available
  if test_definition and test_definition.reset then
    test_definition.reset()
    print("[RUNNER_DEBUG] M.run_file: test_definition.reset() CALLED for file: " .. file)
    if test_definition.get_state then
      local current_state_after_reset = test_definition.get_state() -- Call get_state once
      print(
        string.format(
          "[RUNNER_DEBUG] M.run_file: state AFTER reset for %s: passes=%d, errors=%d, skipped=%d",
          file,
          current_state_after_reset.passes,
          current_state_after_reset.errors,
          current_state_after_reset.skipped
        )
      )
    end
  end

  get_logger().debug("Running test file", {
    file = file,
  })

  -- Load the test file using get_error_handler().try
  local success, result = get_error_handler().try(function()
    -- First check if the file exists
    ---@diagnostic disable-next-line: need-check-nil
    local exists, exists_err = get_fs().file_exists(file)
    if not exists then
      return nil, get_error_handler().io_error("Test file does not exist", {
        file = file,
      }, exists_err)
    end

    if not M.format_options.summary_only and not M.format_options.dot_mode then
      print("Running test file: " .. file)
    end

    -- Set context for temp file tracking
    temp_file.set_current_test_context({
      type = "file",
      path = file,
    })

    -- Load and execute the test file
    local chunk, chunk_err = loadfile(file)
    if not chunk then
      return nil,
        get_error_handler().runtime_error("Failed to load test file", {
          file = file,
          error = tostring(chunk_err),
        })
    end

    -- Execute the chunk
    local exec_success, exec_result = pcall(chunk)
    if not exec_success then
      return nil,
        get_error_handler().runtime_error("Error executing test file", {
          file = file,
          error = tostring(exec_result),
        })
    end

    -- Clear temp file context
    temp_file.set_current_test_context(nil)

    -- Get test results
    local test_state = {
      passes = 0,
      errors = 0,
      skipped = 0,
    }

    if test_definition and test_definition.get_state then
      test_state = test_definition.get_state()
    end
    print(
      string.format(
        "[RUNNER_DEBUG] M.run_file: For file %s, final test_state before returning result: passes=%d, errors=%d, skipped=%d. Calculated success: %s",
        file,
        test_state.passes,
        test_state.errors,
        test_state.skipped,
        tostring(test_state.errors == 0)
      )
    )
    return {
      success = test_state.errors == 0,
      passes = test_state.passes,
      errors = test_state.errors,
      skipped = test_state.skipped,
      file = file,
    }
  end)

  if not success then
    print(
      string.format(
        "[RUNNER_DEBUG] M.run_file: ERROR during pcall(chunk) for file %s. Error: %s",
        file,
        get_error_handler().format_error(result)
      )
    )
    -- Handle errors during file execution
    get_logger().error("Failed to run test file", {
      file = file,
      error = get_error_handler().format_error(result),
    })

    if not M.format_options.summary_only then
      print(red .. "ERROR" .. normal .. " Failed to run test file: " .. file)
      print(red .. get_error_handler().format_error(result) .. normal)
    end

    return {
      success = false,
      errors = 1,
      passes = 0,
      skipped = 0,
      file = file,
    },
      result
  end

  -- Return the test results
  return result
end

--- Run all automatically discovered test files in a directory
--- This function searches for test files in a specified directory that match a given
--- pattern, then executes all discovered files. It uses either the dedicated discovery
--- module or falls back to filesystem search capabilities. This provides a convenient
--- way to run all tests in a project without explicitly listing each file.
---
---@param dir? string Directory to search for test files (default: "tests")
---@param pattern? string Pattern to filter test files (default: "*_test.lua")
---@return boolean success Overall success status (`true` if all tests in all discovered files passed, `false` otherwise).
---@return table|nil error An error object if discovery or parameter validation failed, otherwise `nil`. Note: Individual test failures do not populate this error return; check the boolean `success` flag for test failures.
---@throws table If parameter validation fails.
---
---@usage
--- -- Run all tests in the default directory
--- local success = runner.run_discovered()
--- if success then
---   print("All tests passed!")
--- end
---
--- -- Run tests in a specific directory
--- local success, err = runner.run_discovered("tests/unit")
--- if not success then
---   if err then
---     print("Error discovering or running tests: " .. err.message)
---   else
---     print("Some tests failed")
---   end
--- end
---
--- -- Run tests matching a specific pattern
--- local success = runner.run_discovered("tests", "auth_.*_test%.lua")
--- -- Only runs test files that start with "auth_" and end with "_test.lua"
---
--- -- Configure and run tests
--- runner.configure({ coverage = true, parallel = true })
---   .run_discovered("tests/integration")
function M.run_discovered(dir, pattern)
  -- Parameter validation
  if dir ~= nil and type(dir) ~= "string" then
    local err = get_error_handler().validation_error("Directory must be a string", {
      parameter = "dir",
      provided_type = type(dir),
      function_name = "run_discovered",
    })

    get_logger().error("Parameter validation failed", {
      error = get_error_handler().format_error(err),
      operation = "run_discovered",
    })
    return false, err
  end

  if pattern ~= nil and type(pattern) ~= "string" then
    local err = get_error_handler().validation_error("Pattern must be a string", {
      parameter = "pattern",
      provided_type = type(pattern),
      function_name = "run_discovered",
    })

    get_logger().error("Parameter validation failed", {
      error = get_error_handler().format_error(err),
      operation = "run_discovered",
    })
    return false, err
  end

  -- Set default directory and pattern
  dir = dir or "tests"
  pattern = pattern or "*_test.lua"

  get_logger().info("Running discovered tests", {
    directory = dir,
    pattern = pattern,
  })

  local files
  local discover_err

  -- Use discover_module if available, otherwise fallback to get_fs().discover_files
  if discover_module and discover_module.discover then
    local result = discover_module.discover(dir, pattern)
    if result then
      files = result.files
    else
      discover_err = get_error_handler().io_error("Failed to discover test files", {
        directory = dir,
        pattern = pattern,
      })
    end
  elseif fs and get_fs().discover_files then
    files, discover_err = get_fs().discover_files(dir, pattern)
  else
    discover_err = get_error_handler().configuration_error("No test discovery mechanism available", {
      directory = dir,
      pattern = pattern,
    })
  end

  if not files or #files == 0 then
    get_logger().error("No test files found", {
      directory = dir,
      pattern = pattern,
      error = discover_err and get_error_handler().format_error(discover_err) or nil,
    })

    if not M.format_options.summary_only then
      print(red .. "ERROR" .. normal .. " No test files found in " .. dir .. " matching " .. pattern)
    end

    return false, discover_err
  end

  get_logger().info("Found test files", {
    directory = dir,
    pattern = pattern,
    count = #files,
  })

  if not M.format_options.summary_only and not M.format_options.dot_mode then
    print("Found " .. #files .. " test files in " .. dir .. " matching " .. pattern)
  end

  -- Run the files
  return M.run_tests(files)
end

--- Run a list of test files with specified options
--- This function executes multiple test files, either sequentially or in parallel
--- based on configuration. It aggregates results from all test files and provides
--- a summary of test execution. The function can be configured for code coverage
--- tracking, parallel execution, verbosity, and custom timeouts.
---
---@param files string[] List of test file paths to run
---@param options? {parallel?: boolean, coverage?: boolean, verbose?: boolean, timeout?: number} Additional options for test execution
---@field options.parallel boolean Whether to run tests in parallel using parallel_module
---@field options.coverage boolean Whether to track code coverage
---@field options.verbose boolean If `true`, enable more detailed output during execution (may depend on parallel execution settings).
---@field options.timeout number Timeout in milliseconds for parallel test execution (default: 30000).
---@return table results Test execution results, including success status, counts of passed, failed, and skipped tests, and elapsed time.
---@throws table If the `files` parameter validation fails.
---
---@usage
--- -- Run a list of test files sequentially
--- local test_files = {
---   "tests/unit/module1_test.lua",
---   "tests/unit/module2_test.lua"
--- }
--- local success = runner.run_tests(test_files)
---
--- -- Run tests in parallel with coverage
--- local all_passed = runner.run_tests(test_files, {
---   parallel = true,
---   coverage = true,
---   timeout = 60000  -- 60 second timeout per file
--- })
---
--- -- Run tests with custom options
--- runner.run_tests(test_files, {
---   parallel = os.getenv("CI") == "true",  -- Parallel in CI environment
---   coverage = true,
---   verbose = false,                       -- Minimal output
---   timeout = 10000                        -- 10 second timeout
--- })
---@param files string[] An array of test file paths to execute.
---@param options? {parallel?: boolean, coverage?: boolean, verbose?: boolean, timeout?: number} Optional configuration for this run.
function M.run_tests(files, firmo_instance, options)
  -- Parameter validation
  if not files then
    local err = get_error_handler().validation_error("Files cannot be nil", {
      parameter = "files",
      function_name = "run_tests",
    })

    get_logger().error("Parameter validation failed", {
      error = get_error_handler().format_error(err),
      operation = "run_tests",
    })
    -- Return a table indicating failure, consistent with other return paths
    return {
      success = false,
      passes = 0,
      errors = 1,
      skipped = 0,
      total = 1,
      elapsed = 0,
      files_tested = 0,
      files_passed = 0,
      files_failed = 1,
    }
  end

  if type(files) ~= "table" then
    local err = get_error_handler().validation_error("Files must be a table", {
      parameter = "files",
      provided_type = type(files),
      function_name = "run_tests",
    })

    get_logger().error("Parameter validation failed", {
      error = get_error_handler().format_error(err),
      operation = "run_tests",
    })
    return {
      success = false,
      passes = 0,
      errors = 1,
      skipped = 0,
      total = 1,
      elapsed = 0,
      files_tested = 0,
      files_passed = 0,
      files_failed = 1,
    }
  end

  options = options or {}
  local total_passes = 0
  local total_errors = 0
  local total_skipped = 0
  local all_success = true -- Tracks if all files executed successfully and had no test errors
  local passed_files = 0
  local failed_files = 0

  local start_time = os.clock() -- <<< ADDED: Start timer for the whole M.run_tests execution

  -- Use parallel execution if available and requested
  if parallel_module and (options.parallel or (central_config and central_config.get("runner.parallel"))) then
    -- Configure parallel execution
    parallel_module.configure({
      combine_coverage = options.coverage,
      print_output = options.verbose or false,
      timeout = options.timeout or 30000,
      show_progress = true,
      isolate_state = true,
    })

    get_logger().info("Running tests in parallel", {
      file_count = #files,
    })

    -- Pass relevant options to parallel.run_tests
    local parallel_run_opts = {
      workers = parallel_module.options.workers,
      timeout = parallel_module.options.timeout,
      verbose = parallel_module.options.verbose,
      show_worker_output = parallel_module.options.show_worker_output,
      fail_fast = parallel_module.options.fail_fast,
      aggregate_coverage = parallel_module.options.aggregate_coverage,
      coverage = options.coverage,
      tags = options.tags,
      filter = options.filter,
    }

    local aggregated_results = parallel_module.run_tests(files, parallel_run_opts)

    -- Process the single aggregated_results object from parallel execution
    if aggregated_results then
      total_passes = aggregated_results.passed or 0
      total_errors = aggregated_results.failed or 0 -- 'failed' field from parallel.Results object
      total_skipped = aggregated_results.skipped or 0

      -- Determine overall success based on parallel run's aggregated failures
      all_success = ((aggregated_results.failed or 0) == 0)
      -- Additionally, parallel.Results has an 'errors' table for execution errors, not test failures.
      -- If that error table is populated, it's also not a full success.
      if aggregated_results.errors and #aggregated_results.errors > 0 then
        all_success = false
      end

      -- The 'elapsed' time for the whole parallel run is in aggregated_results.elapsed
      -- We will use the elapsed_time calculated at the end of M.run_tests for overall timing.
      -- However, if you want parallel's specific elapsed time, you could use it here:
      -- elapsed_time = aggregated_results.elapsed or elapsed_time

      -- parallel.Results does not directly give files_passed/files_failed count.
      -- Approximate based on all_success and total files.
      if all_success then
        passed_files = #files
        failed_files = 0
      else
        -- If not all_success, it means at least one test in one file failed, or an execution error.
        -- We can't know exactly how many *files* passed/failed without more detail from parallel_module.
        -- For now, if any test failed (total_errors > 0), mark at least one file as failed.
        if total_errors > 0 then
          failed_files = 1 -- At least one file had test failures.
          -- A more sophisticated approach would be needed if you want exact file pass/fail counts here.
          -- Let's assume if any test fails, we mark all files as "involved" in failure for simplicity,
          -- or just one file failed. For summary purposes, total_errors > 0 means not all files passed.
          -- To be consistent with sequential, let's try:
          if #files > 0 then
            failed_files = (total_errors > 0) and 1 or 0 -- Crude, assumes 1 failing file if any test fails
            -- A better approximation if many files but few errors:
            if total_errors > 0 and failed_files == 0 then
              failed_files = 1
            end
            if #files > 0 and failed_files == 0 and not all_success then
              failed_files = 1
            end -- if success is false for other reasons

            passed_files = #files - failed_files
            -- This is still an approximation. A truly accurate passed_files/failed_files count
            -- would require parallel_module.run_tests to return per-file success status.
            -- For now, if overall not success, say 1 file failed.
            if not all_success and #files > 0 then
              failed_files = math.max(failed_files, 1) -- ensure at least 1 failed file if not all_success
              passed_files = #files - failed_files
            end
          end
        else -- No test errors, but all_success might be false due to parallel execution errors
          if not all_success and #files > 0 then
            failed_files = 1 -- At least one file had an issue
            passed_files = #files - 1
          else
            passed_files = #files
            failed_files = 0
          end
        end
      end
      get_logger().debug("Processed results from parallel execution", aggregated_results)
    else
      get_logger().error("Parallel execution did not return results. Assuming failure for all files.")
      all_success = false
      failed_files = #files -- Assume all files failed if parallel module itself failed
      passed_files = 0
    end
  else
    -- Run files sequentially
    get_logger().info("Running tests sequentially", {
      file_count = #files,
    })

    for _, file_path_str in ipairs(files) do -- Renamed 'file' to 'file_path_str' to avoid conflict with 'file' table key later
      local result_table, run_file_err = M.run_file(file_path_str) -- M.run_file already returns a table

      if result_table then -- Check if M.run_file returned a result
        total_passes = total_passes + (result_table.passes or 0)
        total_errors = total_errors + (result_table.errors or 0)
        total_skipped = total_skipped + (result_table.skipped or 0)

        if result_table.success and (result_table.errors or 0) == 0 then
          passed_files = passed_files + 1
        else
          all_success = false
          failed_files = failed_files + 1
        end
      else -- M.run_file itself failed to return a result (e.g., critical error)
        all_success = false
        failed_files = failed_files + 1
        -- Optionally log run_file_err here
        get_logger().error("M.run_file did not return a result table for: " .. file_path_str, { error = run_file_err })
      end
    end
  end

  local elapsed_time = os.clock() - start_time -- <<< ADDED: Calculate elapsed time

  -- This specific log for individual file failures is less relevant here as 'file' is not in scope
  -- The overall all_success flag handles if any file caused a failure.
  -- if total_errors > 0 then
  --   get_logger().error("Test failures detected during run_tests", {
  --     success = false, -- This should be all_success
  --     errors = total_errors
  --   })
  -- end

  return {
    success = all_success,
    passes = total_passes,
    errors = total_errors,
    skipped = total_skipped,
    total = total_passes + total_errors + total_skipped,
    elapsed = elapsed_time, -- Now elapsed_time is defined
    files_tested = #files,
    files_passed = passed_files, -- Now tracking this
    files_failed = failed_files, -- Now tracking this
  }
end

-- Return the module
return M
