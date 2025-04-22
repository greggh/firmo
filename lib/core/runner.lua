---@class TestRunner
---@field run_file fun(file: string): table, table|nil Run a single test file and return test results and any error information
---@field run_discovered fun(dir?: string, pattern?: string): boolean, table|nil Run all discovered test files in a directory matching a pattern
---@field run_tests fun(files: table, options?: {coverage?: boolean, watch?: boolean, quality?: boolean, quality_level?: number, clean?: boolean, format?: string, report_dir?: string, dry_run?: boolean, fail_fast?: boolean, parallel?: boolean}): boolean, table Run a list of test files with various execution options
---@field execute_test fun(test: table): boolean, table|nil Execute a single test case and return success status and results
---@field run_all_tests fun(files: table, options?: table): boolean, table Run all tests in multiple files and aggregate results
---@field configure fun(options: {coverage?: boolean, watch?: boolean, quality?: boolean, quality_level?: number, clean?: boolean, format?: string, report_dir?: string, dry_run?: boolean, fail_fast?: boolean, parallel?: boolean}): TestRunner Configure the test runner with various options
---@field format fun(options: {use_color?: boolean, indent_char?: string, indent_size?: number, show_trace?: boolean, show_success_detail?: boolean, compact?: boolean, dot_mode?: boolean, summary_only?: boolean}): TestRunner Configure output formatting options
---@field format_options FormatOptions Current output formatting options 
---@field nocolor fun(): TestRunner Disable colors in the output (for terminals that don't support ANSI color codes)
---@field before_file_run fun(callback: fun(file_path: string)): TestRunner Register a callback to run before executing each test file
---@field after_file_run fun(callback: fun(file_path: string, results: table)): TestRunner Register a callback to run after executing each test file
---@field on_test_error fun(callback: fun(test: table, error: table)): TestRunner Register a callback for test execution errors
---@field get_stats fun(): {files: number, tests: number, executed: number, passed: number, failed: number, skipped: number, time: number} Get test execution statistics
---@field set_environment fun(env_variables: table<string, string>): TestRunner Set environment variables for test execution

--- Test runner module for Firmo
--- This module manages the execution of test files, provides output formatting,
--- and coordinates test lifecycle operations. It serves as the central coordinator
--- for the testing framework, handling test discovery, execution, result collection,
--- and reporting. The runner can execute tests in parallel or sequentially,
--- with various configuration options for output formatting and test execution.
---
--- Features:
--- - Test file discovery and execution
--- - Test environment preparation and cleanup
--- - Output formatting with color, indentation, and verbosity options
--- - Test result collection and reporting
--- - Integration with coverage, quality, and reporting modules
--- - Support for parallel test execution
--- - Temporary file cleanup and tracking
--- - Extensibility via callbacks for test lifecycle events
---
--- @version 0.4.0
--- @author Firmo Team

local M = {}

-- Load required modules
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("TestRunner")

--- Safely require a module without raising an error if it doesn't exist
---@param name string The name of the module to require
---@return table|nil The loaded module or nil if it couldn't be loaded
local function try_require(name)
  local success, mod = pcall(require, name)
  if success then return mod end
  return nil
end

-- Load filesystem module
local fs = try_require("lib.tools.filesystem")
if not fs then
  error_handler.throw(
    "Required module 'lib.tools.filesystem' could not be loaded",
    error_handler.CATEGORY.CONFIGURATION,
    error_handler.SEVERITY.FATAL,
    { module = "test_runner" }
  )
end

-- Try to load optional modules
local discover_module = try_require("lib.tools.discover")
local test_definition = try_require("lib.core.test_definition")
local central_config = try_require("lib.core.central_config")
local parallel_module = try_require("lib.tools.parallel")
local temp_file = try_require("lib.tools.filesystem.temp_file")

--- Output formatting options for the test runner
---@class FormatOptions
---@field use_color boolean Whether to use color codes in output
---@field indent_char string Character to use for indentation (tab or spaces)
---@field indent_size number How many indent_chars to use per level
---@field show_trace boolean Show stack traces for errors
---@field show_success_detail boolean Show details for successful tests
---@field compact boolean Use compact output format (less verbose)
---@field dot_mode boolean Use dot mode (. for pass, F for fail)
---@field summary_only boolean Show only summary, not individual tests

-- Set up default formatter options
M.format_options = {
  use_color = true,       -- Whether to use color codes in output
  indent_char = "\t",     -- Character to use for indentation (tab or spaces)
  indent_size = 1,        -- How many indent_chars to use per level
  show_trace = false,     -- Show stack traces for errors
  show_success_detail = true, -- Show details for successful tests
  compact = false,        -- Use compact output format (less verbose)
  dot_mode = false,       -- Use dot mode (. for pass, F for fail)
  summary_only = false,   -- Show only summary, not individual tests
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

-- Helper function for indentation with configurable char and size
--- Generate indentation string based on the current level
---@param level? number The indentation level (defaults to current test level)
---@return string The indentation string
local function indent(level)
  level = level or (test_definition and test_definition.get_state().level or 0)
  local indent_char = M.format_options.indent_char
  local indent_size = M.format_options.indent_size
  return string.rep(indent_char, level * indent_size)
end

--- Disable colors in output for non-terminal output or color-blind users
---@return nil
function M.nocolor()
  -- No need for parameter validation as this function takes no parameters

  logger.debug("Disabling colors in output", {
    function_name = "nocolor",
  })

  -- Apply change with error handling in case of any terminal-related issues
  local success, err = error_handler.try(function()
    M.format_options.use_color = false
    ---@diagnostic disable-next-line: unused-local
    red, green, yellow, blue, magenta, cyan, normal = "", "", "", "", "", "", ""
    return true
  end)

  if not success then
    logger.error("Failed to disable colors", {
      error = error_handler.format_error(err),
      function_name = "nocolor",
    })
    error_handler.throw(
      "Failed to disable colors: " .. error_handler.format_error(err),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
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
---@return TestRunner The module instance for method chaining
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
function M.format(options)
  -- Parameter validation
  if options == nil then
    local err = error_handler.validation_error("Options cannot be nil", {
      parameter = "options",
      function_name = "format",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "format",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if type(options) ~= "table" then
    local err = error_handler.validation_error("Options must be a table", {
      parameter = "options",
      provided_type = type(options),
      function_name = "format",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "format",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  logger.debug("Configuring format options", {
    function_name = "format",
    option_count = (options and type(options) == "table") and #options or 0,
  })

  -- Apply format options with error handling
  local unknown_options = {}
  local success, apply_err = error_handler.try(function()
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
    local err = error_handler.validation_error("Unknown format option(s): " .. table.concat(unknown_options, ", "), {
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

    logger.error("Unknown format options provided", {
      error = error_handler.format_error(err),
      operation = "format",
      unknown_options = unknown_options,
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  -- Handle general application errors
  if not success then
    logger.error("Failed to apply format options", {
      error = error_handler.format_error(apply_err),
      operation = "format",
    })

    error_handler.throw(
      "Failed to apply format options: " .. error_handler.format_error(apply_err),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "format" }
    )
  end

  -- Update colors if needed
  local color_success, color_err = error_handler.try(function()
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
    logger.error("Failed to update color settings", {
      error = error_handler.format_error(color_err),
      operation = "format",
      use_color = M.format_options.use_color,
    })

    error_handler.throw(
      "Failed to update color settings: " .. error_handler.format_error(color_err),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "format", use_color = M.format_options.use_color }
    )
  end

  logger.debug("Format options configured successfully", {
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
---@field options.cleanup_temp_files boolean? Whether to clean up temporary files (defaults to true)
---@return TestRunner The module instance for method chaining
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
function M.configure(options)
  options = options or {}
  
  -- Apply configuration options with error handling
  local success, err = error_handler.try(function()
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
        isolate_state = true
      })
    end
    
    -- Configure temp file system if available
    if temp_file and options.cleanup_temp_files ~= false then
      temp_file.configure({
        auto_cleanup = true,
        track_files = true
      })
    end
    
    return true
  end)
  
  if not success then
    logger.error("Failed to configure test runner", {
      error = error_handler.format_error(err),
      operation = "configure",
    })
    
    error_handler.throw(
      "Failed to configure test runner: " .. error_handler.format_error(err),
      error_handler.CATEGORY.CONFIGURATION,
      error_handler.SEVERITY.ERROR,
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
---@param file string The absolute path to the test file to run
---@return {success: boolean, passes: number, errors: number, skipped: number, file: string} results Test execution results with counts
---@return table|nil error Error information if execution failed
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
    local err = error_handler.validation_error("File path cannot be nil", {
      parameter = "file",
      function_name = "run_file",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "run_file",
    })
    return { success = false, errors = 1 }, err
  end

  if type(file) ~= "string" then
    local err = error_handler.validation_error("File path must be a string", {
      parameter = "file",
      provided_type = type(file),
      function_name = "run_file",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "run_file",
    })
    return { success = false, errors = 1 }, err
  end

  -- Reset test state if test_definition module is available
  if test_definition and test_definition.reset then
    test_definition.reset()
  end

  logger.debug("Running test file", {
    file = file,
  })

  -- Load the test file using error_handler.try
  local success, result = error_handler.try(function()
    -- First check if the file exists
    ---@diagnostic disable-next-line: need-check-nil
    local exists, exists_err = fs.file_exists(file)
    if not exists then
      return nil, error_handler.io_error("Test file does not exist", {
        file = file,
      }, exists_err)
    end

    if not M.format_options.summary_only and not M.format_options.dot_mode then
      print("Running test file: " .. file)
    end

    -- Set context for temp file tracking if available
    if temp_file and temp_file.set_current_test_context then
      temp_file.set_current_test_context({
        type = "file",
        path = file,
      })
    end

    -- Load and execute the test file
    local chunk, chunk_err = loadfile(file)
    if not chunk then
      return nil, error_handler.runtime_error("Failed to load test file", {
        file = file,
        error = tostring(chunk_err),
      })
    end

    -- Execute the chunk
    local exec_success, exec_result = pcall(chunk)
    if not exec_success then
      return nil, error_handler.runtime_error("Error executing test file", {
        file = file,
        error = tostring(exec_result),
      })
    end

    -- Clear temp file context
    if temp_file and temp_file.set_current_test_context then
      temp_file.set_current_test_context(nil)
    end

    -- Get test results
    local test_state = {
      passes = 0,
      errors = 0,
      skipped = 0,
    }

    if test_definition and test_definition.get_state then
      test_state = test_definition.get_state()
    end

    return {
      success = test_state.errors == 0,
      passes = test_state.passes,
      errors = test_state.errors,
      skipped = test_state.skipped,
      file = file,
    }
  end)

  if not success then
    -- Handle errors during file execution
    logger.error("Failed to run test file", {
      file = file,
      error = error_handler.format_error(result),
    })

    if not M.format_options.summary_only then
      print(red .. "ERROR" .. normal .. " Failed to run test file: " .. file)
      print(red .. error_handler.format_error(result) .. normal)
    end

    return {
      success = false,
      errors = 1,
      passes = 0,
      skipped = 0,
      file = file,
    }, result
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
---@return boolean success Whether all discovered tests passed successfully
---@return table|nil error Error information if discovery or execution failed
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
    local err = error_handler.validation_error("Directory must be a string", {
      parameter = "dir",
      provided_type = type(dir),
      function_name = "run_discovered",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "run_discovered",
    })
    return false, err
  end

  if pattern ~= nil and type(pattern) ~= "string" then
    local err = error_handler.validation_error("Pattern must be a string", {
      parameter = "pattern",
      provided_type = type(pattern),
      function_name = "run_discovered",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "run_discovered",
    })
    return false, err
  end

  -- Set default directory and pattern
  dir = dir or "tests"
  pattern = pattern or "*_test.lua"

  logger.info("Running discovered tests", {
    directory = dir,
    pattern = pattern,
  })

  local files
  local discover_err

  -- Use discover_module if available, otherwise fallback to fs.discover_files
  if discover_module and discover_module.discover then
    local result = discover_module.discover(dir, pattern)
    if result then
      files = result.files
    else
      discover_err = error_handler.io_error("Failed to discover test files", {
        directory = dir,
        pattern = pattern,
      })
    end
  elseif fs and fs.discover_files then
    files, discover_err = fs.discover_files(dir, pattern)
  else
    discover_err = error_handler.configuration_error("No test discovery mechanism available", {
      directory = dir,
      pattern = pattern,
    })
  end

  if not files or #files == 0 then
    logger.error("No test files found", {
      directory = dir,
      pattern = pattern,
      error = discover_err and error_handler.format_error(discover_err) or nil,
    })

    if not M.format_options.summary_only then
      print(red .. "ERROR" .. normal .. " No test files found in " .. dir .. " matching " .. pattern)
    end

    return false, discover_err
  end

  logger.info("Found test files", {
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
---@field options.verbose boolean Whether to show verbose output
---@field options.timeout number Timeout in milliseconds for test execution (default: 30000)
---@return boolean success Whether all tests passed successfully
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
function M.run_tests(files, options)
  -- Parameter validation
  if not files then
    local err = error_handler.validation_error("Files cannot be nil", {
      parameter = "files",
      function_name = "run_tests",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "run_tests",
    })
    return false
  end

  if type(files) ~= "table" then
    local err = error_handler.validation_error("Files must be a table", {
      parameter = "files",
      provided_type = type(files),
      function_name = "run_tests",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "run_tests",
    })
    return false
  end

  options = options or {}
  local total_passes = 0
  local total_errors = 0
  local total_skipped = 0
  local all_success = true

  -- Use parallel execution if available and requested
  if parallel_module and (options.parallel or (central_config and central_config.get("runner.parallel"))) then
    -- Configure parallel execution
    parallel_module.configure({
      combine_coverage = options.coverage,
      print_output = options.verbose or false,
      timeout = options.timeout or 30000,
      show_progress = true,
      isolate_state = true
    })

    -- Run files in parallel
    logger.info("Running tests in parallel", {
      file_count = #files,
    })

    local results = parallel_module.run_files(files)
    
    -- Process results
    for _, result in ipairs(results) do
      if result.success then
        total_passes = total_passes + (result.passes or 0)
      else
        all_success = false
        total_errors = total_errors + (result.errors or 1)
      end
      total_skipped = total_skipped + (result.skipped or 0)
    end
  else
    -- Run files sequentially
    logger.info("Running tests sequentially", {
      file_count = #files,
    })

    for _, file in ipairs(files) do
      local result, _ = M.run_file(file)
      
      total_passes = total_passes + (result.passes or 0)
      total_errors = total_errors + (result.errors or 0)
      total_skipped = total_skipped + (result.skipped or 0)
      
      if not result.success or result.errors > 0 then
        all_success = false
      end
    end
  end

  -- Print summary
  if not M.format_options.dot_mode then
    print("\nTest Results:")
    print("- Passes:  " .. green .. total_passes .. normal)
    print("- Failures: " .. (total_errors > 0 and red or normal) .. total_errors .. normal)
    print("- Skipped:  " .. yellow .. total_skipped .. normal)
    print("- Total:    " .. (total_passes + total_errors + total_skipped))
    print(all_success and green .. "All tests passed!" .. normal or red .. "There were test failures!" .. normal)
  else
    print("\n" .. (all_success and green .. "All tests passed!" .. normal or red .. "There were test failures!" .. normal))
    print("Passes: " .. total_passes .. ", Failures: " .. total_errors .. ", Skipped: " .. total_skipped)
  end

  if total_errors > 0 then
    logger.error("Test failures detected in file", {
      success = false,
      errors = total_errors,
      path = file,
      test_errors = total_errors
    })
  end

  return all_success
end

-- Return the module
return M