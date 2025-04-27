--- Firmo Test Runner Script
---
--- This script serves as the main entry point for running Firmo tests. It handles:
--- 1. Parsing command-line arguments.
--- 2. Discovering test files in directories or running single files.
--- 3. Running tests sequentially or in watch mode.
--- 4. Optionally enabling and managing code coverage.
--- 5. Generating reports based on test results and coverage data.
---
--- Usage: lua scripts/runner.lua [options] [path]
---
--- @author Firmo Team
--- @version 1.2.0
--- @script

--- @class TestResult (from test_definition) Standard structure for a single test result.
--- @field name string Test name.
--- @field status string Test status ("pass", "fail", "skip", "pending").
--- @field path string[] Array of describe/it block names leading to the test.
--- @field path_string string String representation of the test path.
--- @field error_message? string Error message if status is "fail".
--- @field error? any Raw error value if status is "fail".
--- @field reason? string Reason if status is "skip" or "pending".
--- @field execution_time? number Execution time in seconds.
--- @field file_path? string Path to the test file where this result occurred.
--- @field expect_error? boolean True if this test was expected to fail via `it.errors`.
--- @field options? table Options passed to the `it` block.

--- @class RunFileResult Structure returned by `runner.run_file`.
--- @field success boolean Whether the file executed without pcall errors.
--- @field error? any The error caught by pcall during file execution, if any.
--- @field passes number Number of passing tests within the file.
--- @field errors number Number of failing tests within the file (includes execution errors).
--- @field skipped number Number of skipped/pending tests within the file.
--- @field total number Total number of tests executed within the file (passes + errors + skipped).
--- @field elapsed number Execution time for the file in seconds.
--- @field output string Captured standard output from the file execution.
--- @field test_results TestResult[] Array of structured test results from the file.
--- @field file string Path to the test file.
--- @field test_errors? table[] Array of error details extracted from failed tests or execution errors.

--- @class RunnerOptions Parsed command-line options for the runner.
--- @field verbose? boolean Verbose output (default false).
--- @field memory? boolean Track memory usage (default false).
--- @field performance? boolean Show performance stats (default false).
--- @field coverage? boolean Enable coverage tracking (default false).
--- @field coverage_debug? boolean Enable debug output for coverage (default false).
--- @field quality? boolean Enable quality validation (default false).
--- @field quality_level? number Quality validation level (default 3).
--- @field watch? boolean Enable watch mode (default false).
--- @field json_output? boolean Output JSON results (default false).
--- @field pattern? string Pattern for test files (default nil).
--- @field filter? string Filter pattern for tests (default nil).
--- @field report_dir? string Directory for reports (default "./coverage-reports").
--- @field formats? string[] Report formats (default {"html", "json", ...}).
--- @field threshold? number Coverage/quality threshold (default 80).
--- @field exclude_patterns? string[] Patterns to exclude (default {"fixtures/*"}).
--- @field coverage_instance? table Instance of the coverage module if initialized.
--- @field results_format? string Specific format for test results output (e.g., "json").
--- @field interval? number Watch mode interval (default 1.0).

local runner = {}

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

local version = try_require("lib.core.version")
local watcher = try_require("lib.tools.watcher")

-- Set error handler to test mode since we're running tests
get_error_handler().set_test_mode(true)

local module_reset = try_require("lib.core.module_reset")

-- ANSI color codes (keep them for compatibility with existing code)
local red = string.char(27) .. "[31m"
local green = string.char(27) .. "[32m"
local yellow = string.char(27) .. "[33m"
local cyan = string.char(27) .. "[36m"
local normal = string.char(27) .. "[0m"

--- Run a specific test file and return structured results
---@param file_path string The path to the test file to run
---@param firmo table The firmo module instance
---@param options table Options for running the test
---@return table Table containing test results including:
---   - success: boolean Whether the file executed without errors
---   - error: any Any execution error that occurred
---   - passes: number Number of passing tests
---   - errors: number Number of failing tests
---   - skipped: number Number of skipped tests
---   - total: number Total number of tests
---   - elapsed: number Execution time in seconds
---   - file: string Path to the test file
---   - test_results: TestResult[] Array of structured test results from the file.
---   - test_errors: table[] Array of error details extracted from failed tests or execution errors.
--- @throws error If required modules (`fs`, `test_definition`) cannot be loaded or if critical errors occur outside `pcall`.
--- @usage
---   local results = runner.run_file("tests/my_test.lua", require("firmo"), { coverage = true })
function runner.run_file(file_path, firmo, options)
  options = options or {}
  -- Always initialize counter properties for this test file
  -- We want to capture just this file's results, so reset them each time
  firmo.passes = 0
  firmo.errors = 0
  firmo.skipped = 0

  -- Since we're resetting each time, these are always zero
  local prev_passes = 0
  local prev_errors = 0
  local prev_skipped = 0

  -- Reset test_definition module state if available
  local test_definition = try_require("lib.core.test_definition")
  test_definition.reset()

  -- Enable debug mode for test_definition if verbose is enabled
  if options.verbose and test_definition.set_debug_mode then
    test_definition.set_debug_mode(true)
  end

  get_logger().info("Running file", { file_path = file_path })

  -- Count PASS/FAIL from test output
  local pass_count = 0
  local fail_count = 0
  local skip_count = 0

  -- Keep track of the original print function
  local original_print = print
  local output_buffer = {}

  -- Override print to capture output for diagnostics
  _G.print = function(...)
    -- Convert arguments to strings first to handle booleans and other non-string values
    local args = { ... }
    local string_args = {}

    for i, v in ipairs(args) do
      string_args[i] = tostring(v)
    end

    -- Use compatibility unpack
    local unpack_table = table.unpack or unpack
    local output = table.concat(string_args, " ")
    table.insert(output_buffer, output)

    -- Still show output
    original_print(...)
  end

  -- Create a collection of structured test results for this file
  -- This will be populated from test_definition's test_results
  ---@type TestResult[]
  local file_test_results = {}

  -- Intercept logger calls to capture structured test results
  local original_logger_info = get_logger().info
  local original_logger_error = get_logger().error

  get_logger().info = function(message, context)
    -- Look for structured test result objects
    if context and context.test_result and type(context.test_result) == "table" then
      local result = context.test_result

      -- Store the result for reporting
      table.insert(file_test_results, result)

      -- Count based on status
      if result.status == "pass" then
        pass_count = pass_count + 1

        -- Display the test result
        if result.expect_error then
          -- Expected error test pass
          original_print(green .. "PASS " .. result.name .. " (expected error)" .. normal)
        else
          -- Normal test pass
          original_print(green .. "PASS " .. result.name .. normal)
        end
      elseif result.status == "skip" or result.status == "pending" then
        skip_count = skip_count + 1

        -- Display skip reason
        local reason = result.reason and (" - " .. result.reason) or ""
        original_print(yellow .. "SKIP " .. result.name .. reason .. normal)
      end
    end

    return original_logger_info(message, context)
  end

  get_logger().error = function(message, context)
    -- Look for structured test result objects
    if context and context.test_result and type(context.test_result) == "table" then
      local result = context.test_result

      -- Store the result for reporting
      table.insert(file_test_results, result)

      -- Count based on status
      if result.status == "fail" then
        fail_count = fail_count + 1

        -- Display the failure
        local error_message = result.error_message or message
        original_print(red .. "FAIL " .. result.name .. " - " .. error_message .. normal)
      end
    end

    return original_logger_error(message, context)
  end

  -- Try to load temp_file integration for test file context
  local temp_file_integration
  local temp_file

  -- Try to load temp_file_integration if available
  local temp_file_integration = try_require("lib.tools.filesystem.temp_file_integration")

  -- Also load the temp_file module
  local temp_file = try_require("lib.tools.filesystem.temp_file")

  -- Create a test context for this file
  local file_context = {
    type = "file",
    name = file_path,
    file_path = file_path,
  }

  -- Set the current test context
  if firmo.set_current_test_context then
    firmo.set_current_test_context(file_context)
  end

  -- Also set global context
  _G._current_temp_file_context = file_context

  -- Execute the test file
  local start_time = os.clock()
  local success, err = pcall(function()
    -- Verify file exists
    if not get_fs().file_exists(file_path) then
      error("Test file does not exist: " .. file_path)
    end

    -- Ensure proper package path for test file
    local save_path = package.path
    local dir = get_fs().get_directory_name(file_path)
    if dir and dir ~= "" then
      package.path = get_fs().join_paths(dir, "?.lua")
        .. ";"
        .. get_fs().join_paths(dir, "../?.lua")
        .. ";"
        .. package.path
    end

    dofile(file_path)

    package.path = save_path
  end)
  local elapsed_time = os.clock() - start_time

  -- Restore original print function
  _G.print = original_print

  -- Restore original logger functions
  get_logger().info = original_logger_info
  get_logger().error = original_logger_error

  -- Clean up temporary files
  if temp_file_integration and temp_file then
    -- Clean up any temporary files created during test execution
    get_logger().debug("Cleaning up temporary files after test execution", { file_path = file_path })

    -- Try to clean up, but don't let cleanup failures affect test results
    pcall(function()
      temp_file.cleanup_all()
    end)

    -- Clear test context
    if firmo.set_current_test_context then
      firmo.set_current_test_context(nil)
    end

    -- Also clear global context
    _G._current_temp_file_context = nil
  end

  -- Always copy test results from test_definition
  local test_definition = try_require("lib.core.test_definition")
  local state = test_definition.get_state()
  if state and state.test_results then
    -- Copy test_definition results into file_test_results for more reliable collection
    for _, result in ipairs(state.test_results) do
      table.insert(file_test_results, result)
    end

    -- Debug output only in verbose mode
    if options.verbose then
      print(string.format("\n%sStructured Test Result Collection:%s", cyan, normal))
      print(string.format("  File test results count: %d", #file_test_results))
      print(string.format("  Counts: pass=%d, fail=%d, skip=%d", pass_count, fail_count, skip_count))
      print(string.format("  Test definition results count: %d", #state.test_results))
      print(
        string.format(
          "  Test definition counters: passes=%d, errors=%d, skipped=%d",
          state.passes or 0,
          state.errors or 0,
          state.skipped or 0
        )
      )
      print(string.format("  Copied %d results from test_definition to file_test_results", #state.test_results))
    end
  end

  -- Use structured test results collected via intercepted logger calls
  local results = {
    success = success,
    error = err,
    passes = pass_count,
    errors = fail_count,
    skipped = skip_count,
    total = 0,
    elapsed = elapsed_time,
    output = table.concat(output_buffer, "\n"),
    test_results = file_test_results, -- Include the full structured test results
    file = file_path,
  }

  -- Get test results directly from test_definition, which is more reliable
  local test_definition = try_require("lib.core.test_definition")
  local state = test_definition.get_state()
  if state and state.test_results and #state.test_results > 0 then
    -- Use file_test_results which now has the test_definition results
    results.test_results = file_test_results
    results.passes = state.passes or 0
    results.errors = state.errors or 0
    results.skipped = state.skipped or 0

    get_logger().debug("Using test_definition state for test results", {
      file = file_path,
      result_count = #state.test_results,
      passes = state.passes,
      errors = state.errors,
      skipped = state.skipped,
    })
  end

  -- Calculate total tests
  results.total = results.passes + results.errors + results.skipped

  -- Add test errors from structured results
  results.test_errors = {}
  for _, result in ipairs(results.test_results or {}) do
    if result.status == "fail" then
      table.insert(results.test_errors, {
        message = result.error_message or "Test failed: " .. result.name,
        file = file_path,
        test_name = result.name,
        test_path = result.path_string,
        error = result.error,
      })
    end
  end

  -- If we don't have structured test errors, try to parse from output (legacy)
  if #results.test_errors == 0 then
    for line in results.output:gmatch("[^\r\n]+") do
      if line:match("FAIL") then
        local name = line:match("FAIL%s+(.+)")
        if name then
          table.insert(results.test_errors, {
            message = "Test failed: " .. name,
            file = file_path,
          })
        end
      end
    end
  end

  if not success then
    get_logger().error("Execution error", { error = err })
    table.insert(results.test_errors, {
      message = tostring(err),
      file = file_path,
      traceback = debug.traceback(),
    })

    results.errors = results.errors + 1
  end

  -- Always show the completion status with test counts
  -- Use consistent terminology
  get_logger().info("Test completed", {
    passes = results.passes,
    failures = results.errors,
    skipped = results.skipped,
    tests_passed = results.passes, -- Add for consistency with run_all
    tests_failed = results.errors, -- Add for consistency with run_all
  })

  -- Output JSON results if requested
  if options.json_output or options.results_format == "json" then
    -- Try to load JSON module
    local json_module = try_require("lib.tools.json")

    -- Create test results data structure
    local test_results = {
      name = file_path:match("([^/\\]+)$") or file_path,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
      tests = results.total,
      failures = results.errors,
      errors = success and 0 or 1,
      skipped = results.skipped,
      time = results.elapsed,
      test_cases = {},
      file = file_path,
      success = success and results.errors == 0,
    }

    -- Extract test cases if possible
    for line in results.output:gmatch("[^\r\n]+") do
      if line:match("PASS%s+") or line:match("FAIL%s+") or line:match("SKIP%s+") or line:match("PENDING%s+") then
        local status, name
        if line:match("PASS%s+") then
          status = "pass"
          name = line:match("PASS%s+(.+)")
        elseif line:match("FAIL%s+") then
          status = "fail"
          name = line:match("FAIL%s+(.+)")
        elseif line:match("SKIP%s+") then
          status = "skipped"
          name = line:match("SKIP%s+(.+)")
        elseif line:match("PENDING%s+") then
          status = "pending"
          name = line:match("PENDING:%s+(.+)")
        end

        if name then
          local test_case = {
            name = name,
            classname = file_path:match("([^/\\]+)$"):gsub("%.lua$", ""),
            time = 0, -- We don't have individual test timing
            status = status,
          }

          -- Add failure details if available
          if status == "fail" then
            test_case.failure = {
              message = "Test failed: " .. name,
              type = "Assertion",
              details = "",
            }
          end

          table.insert(test_results.test_cases, test_case)
        end
      end
    end

    -- If we couldn't extract individual tests, add a single summary test case
    if #test_results.test_cases == 0 then
      table.insert(test_results.test_cases, {
        name = file_path:match("([^/\\]+)$"):gsub("%.lua$", ""),
        classname = file_path:match("([^/\\]+)$"):gsub("%.lua$", ""),
        time = results.elapsed,
        status = (success and results.errors == 0) and "pass" or "fail",
      })
    end

    -- Format as JSON with markers for parallel execution
    local json_results = json_module.encode(test_results)
    get_logger().info("JSON results", { results = "RESULTS_JSON_BEGIN" .. json_results .. "RESULTS_JSON_END" })
  end

  return results
end

--- Finds test files in a directory based on configuration.
---@param dir_path string The directory path to search.
---@param options? {pattern?: string, filter?: string, exclude_patterns?: string[]} Options:
---  - `pattern` (string): Glob pattern for files (e.g., "*_test.lua").
---  - `filter` (string): Additional Lua pattern to filter file paths.
---  - `exclude_patterns` (string[]): Array of glob patterns to exclude.
---@return string[] files An array of sorted, found file paths. Returns empty table on error.
function runner.find_test_files(dir_path, options)
  options = options or {}
  local pattern = options.pattern or "*.lua"
  local filter = options.filter
  local exclude_patterns = options.exclude_patterns or { "fixtures/*" }

  get_logger().info("Finding test files", {
    directory = dir_path,
    pattern = pattern,
    filter = filter,
    exclude_patterns = table.concat(exclude_patterns, ", "),
  })

  -- Handle directory existence check properly
  -- The get_fs().normalize_path() function automatically removes trailing slashes
  -- but get_fs().directory_exists() works fine with or without trailing slashes

  -- Simply check if directory exists
  if not get_fs().directory_exists(dir_path) then
    get_logger().error("Directory not found", { directory = dir_path })
    return {}
  end

  -- Use filesystem module to find test files
  local files, err = get_fs().discover_files({ dir_path }, { pattern }, exclude_patterns)

  if not files then
    get_logger().error("Failed to discover test files", {
      error = get_error_handler().format_error(err),
      directory = dir_path,
      pattern = pattern,
    })
    return {}
  end

  -- Apply filter if specified
  if filter and filter ~= "" then
    local filtered_files = {}
    for _, file in ipairs(files) do
      if file:match(filter) then
        table.insert(filtered_files, file)
      end
    end

    get_logger().info("Filtered test files", {
      count = #filtered_files,
      original_count = #files,
      filter = filter,
    })

    files = filtered_files
  end

  -- Sort files for consistent execution order
  table.sort(files)

  return files
end

--- Run tests in a directory or file list and aggregate results
---@param files_or_dir string|string[] Either a directory path or an array of file paths.
---@param firmo table The firmo module instance.
---@param options RunnerOptions Options for running the tests (passed to `run_file`).
---@return boolean all_passed `true` if all tests in all files passed, `false` otherwise.
---@throws error If required modules fail to load or if critical errors occur outside `runner.run_file` calls.
function runner.run_all(files_or_dir, firmo, options)
  options = options or {}
  local files

  -- If files_or_dir is a string, treat it as a directory
  if type(files_or_dir) == "string" then
    files = runner.find_test_files(files_or_dir, options)
  else
    files = files_or_dir
  end

  -- Print debugging info if verbose
  if options.verbose then
    print(string.format("\n%sRunning %d test files with structured result tracking%s\n", cyan, #files, normal))
  end

  get_logger().info("Running test files", { count = #files })

  local passed_files = 0
  local failed_files = 0
  local total_passes = 0
  local total_failures = 0
  local total_skipped = 0
  local start_time = os.clock()
  -- Collection to aggregate test results from all files
  ---@type TestResult[]
  local all_test_results = {}

  -- Initialize module reset if available
  if module_reset_loaded and module_reset then
    module_reset.register_with_firmo(firmo)

    -- Configure isolation options
    module_reset.configure({
      reset_modules = true,
      verbose = options.verbose == true,
    })
    get_logger().info("Module reset system activated", { feature = "enhanced test isolation" })
  end

  -- Coverage should be already initialized in runner.main and passed in options.coverage_instance
  -- We just need to log that we're using the pre-initialized coverage
  if options.coverage then
    if options.coverage_instance then
      get_logger().debug("Using pre-initialized coverage instance from main function", {
        operation = "run_all",
        coverage_instance_valid = options.coverage_instance ~= nil,
      })

      -- Ensure coverage instance is active
      if options.coverage_instance.is_active and not options.coverage_instance.is_active() then
        get_logger().warn("Coverage instance is not active, trying to start it", {
          operation = "run_all",
        })

        -- Try to start coverage if it's not active
        local ok, err = pcall(function()
          options.coverage_instance.start()
        end)

        if not ok then
          get_logger().error("Failed to start coverage in run_all", {
            error = get_error_handler().format_error(err),
            operation = "run_all.start_coverage",
          })
        end
      end
    else
      get_logger().warn("Coverage enabled but no coverage instance was passed", {
        operation = "run_all",
        solution = "Coverage instance should be initialized in main and passed in options",
      })
    end
  else
    get_logger().debug("Coverage not enabled in options", { coverage_option = options.coverage })
  end

  for _, file in ipairs(files) do
    -- IMPORTANT: Reset the test counts for each file to correctly capture them
    local results = runner.run_file(file, firmo, options)

    -- Count passed/failed files
    if results.success and results.errors == 0 then
      passed_files = passed_files + 1
    else
      failed_files = failed_files + 1
      -- Log failure reason for debugging
      get_logger().debug("File marked as failed", {
        file = file,
        execution_success = results.success,
        test_errors = results.errors,
        reason = not results.success and "Execution error" or "Test failures",
      })
    end

    -- Get the actual test counts from the results
    local file_passes = results.passes
    local file_errors = results.errors
    local file_skipped = results.skipped or 0

    -- If we're getting zero counts back but the test ran successfully,
    -- try to extract counts from the firmo state
    if file_passes == 0 and file_errors == 0 and results.success then
      -- Try to get test definition state if available
      local test_definition = try_require("lib.core.test_definition")
      local state = test_definition.get_state()
      file_passes = state.passes or 0
      file_errors = state.errors or 0
      file_skipped = state.skipped or 0

      -- Log that we're using state directly for debugging
      get_logger().debug("Using test_definition state for counts", {
        file = file,
        state_passes = file_passes,
        state_errors = file_errors,
        state_skipped = file_skipped,
      })
    end

    -- Collect all structured test results from this file
    if results.test_results and #results.test_results > 0 then
      if options.verbose then
        print(
          string.format(
            "\n%sCollecting %d structured test results from %s%s",
            cyan,
            #results.test_results,
            file,
            normal
          )
        )
      end

      for _, result in ipairs(results.test_results) do
        -- Add the file path to each result for easier tracking
        result.file_path = file
        table.insert(all_test_results, result)

        if options.verbose then
          print(string.format("  - Added result: %s [%s]", result.name, result.status:upper()))
        end
      end

      get_logger().debug("Collected structured test results", {
        file = file,
        result_count = #results.test_results,
        total_collected = #all_test_results,
      })
    else
      if options.verbose then
        print(string.format("\n%sNo structured test results found in %s%s", red, file, normal))
      end
    end

    -- Count total tests
    total_passes = total_passes + file_passes
    total_failures = total_failures + file_errors
    total_skipped = total_skipped + file_skipped

    -- Log collected counts after each file
    get_logger().debug("Accumulated test counts", {
      current_file = file,
      file_passes = file_passes,
      file_failures = file_errors,
      file_skipped = file_skipped,
      running_total_passes = total_passes,
      running_total_failures = total_failures,
      running_total_skipped = total_skipped,
    })

    -- Print out the structured test results from this file for debugging
    if options.verbose and results.test_results and #results.test_results > 0 then
      print("\nStructured test results from " .. file .. ":")
      for i, result in ipairs(results.test_results) do
        local status_color = ""
        if result.status == "pass" then
          status_color = green
        elseif result.status == "fail" then
          status_color = red
        else
          status_color = yellow
        end

        print(
          string.format(
            "  %d. %s[%s]%s %s (%s)",
            i,
            status_color,
            result.status:upper(),
            normal,
            result.name,
            result.path_string or ""
          )
        )

        if result.expect_error then
          print(string.format("     Expected error: %s", tostring(result.error or "")))
        end

        if result.execution_time then
          print(string.format("     Time: %.4f seconds", result.execution_time))
        end
      end
      print("")
    end
  end

  local elapsed_time = os.clock() - start_time

  -- Show collected test results in verbose mode
  if options.verbose and #all_test_results > 0 then
    print(string.format("\n%sAll collected test results: %d%s", cyan, #all_test_results, normal))
    for i, result in ipairs(all_test_results) do
      if i <= 10 then -- Only show first 10 to avoid flooding the output
        local status_color = ""
        if result.status == "pass" then
          status_color = green
        elseif result.status == "fail" then
          status_color = red
        else
          status_color = yellow
        end

        print(
          string.format(
            "  %d. %s[%s]%s %s (%s)",
            i,
            status_color,
            result.status:upper(),
            normal,
            result.name,
            result.file_path or ""
          )
        )
      end
    end

    if #all_test_results > 10 then
      print(string.format("  ... and %d more", #all_test_results - 10))
    end
    print("")
  end

  -- In the summary, use consistent terminology:
  -- - passes/failures => individual test cases passed/failed
  -- - files_passed/files_failed => test files that passed/failed
  get_logger().info("Test run summary", {
    files_passed = passed_files,
    files_failed = failed_files,
    tests_passed = total_passes, -- Same as 'passes'
    tests_failed = total_failures, -- Same as 'failures'
    tests_skipped = total_skipped,
    passes = total_passes, -- Add these for consistency
    failures = total_failures, -- Add these for consistency
    elapsed_time_seconds = string.format("%.2f", elapsed_time),
    structured_results_count = #all_test_results,
  })

  -- Calculate statistics on test execution time if available
  local timing_stats = {}
  if #all_test_results > 0 then
    local slowest_tests = {}
    local total_execution_time = 0
    local count_with_execution_time = 0

    for _, result in ipairs(all_test_results) do
      if result.execution_time then
        total_execution_time = total_execution_time + result.execution_time
        count_with_execution_time = count_with_execution_time + 1

        -- Track slowest tests
        if #slowest_tests < 5 then
          table.insert(slowest_tests, result)
          -- Sort by execution time (descending)
          table.sort(slowest_tests, function(a, b)
            return (a.execution_time or 0) > (b.execution_time or 0)
          end)
        elseif result.execution_time > (slowest_tests[5].execution_time or 0) then
          -- Replace the fastest of our 5 slowest
          slowest_tests[5] = result
          -- Resort
          table.sort(slowest_tests, function(a, b)
            return (a.execution_time or 0) > (b.execution_time or 0)
          end)
        end
      end
    end

    -- Calculate average execution time
    if count_with_execution_time > 0 then
      timing_stats = {
        total_test_execution_time = total_execution_time,
        average_test_execution_time = total_execution_time / count_with_execution_time,
        tests_with_timing = count_with_execution_time,
        slowest_tests = {},
      }

      -- Add info about slowest tests
      for i, slow_test in ipairs(slowest_tests) do
        table.insert(timing_stats.slowest_tests, {
          name = slow_test.name,
          path = slow_test.path_string,
          execution_time = slow_test.execution_time,
          file = slow_test.file_path,
        })
      end

      -- Log timing stats at debug level
      get_logger().debug("Test timing statistics", timing_stats)
    end
  end

  local all_passed = failed_files == 0
  if not all_passed then
    get_logger().error("Test run failed", {
      failed_files = failed_files,
      failed_tests = total_failures,
    })

    -- Show detailed failure information
    if #all_test_results > 0 then
      local failed_tests = {}
      for _, result in ipairs(all_test_results) do
        if result.status == "fail" then
          table.insert(failed_tests, {
            name = result.name,
            path = result.path_string,
            file = result.file_path,
            error_message = result.error_message,
          })
        end
      end

      if #failed_tests > 0 then
        get_logger().debug("Failed tests", { failed_tests = failed_tests })
      end
    end
  else
    get_logger().info("Test run successful", {
      all_passed = true,
      test_count = total_passes + total_skipped,
    })
  end

  -- Output overall JSON results if requested
  if options.json_output or options.results_format == "json" then
    -- Try to load JSON module
    local json_module = try_require("lib.tools.json")

    -- Create aggregated test results
    local test_results = {
      name = "firmo-tests",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
      tests = total_passes + total_failures + total_skipped,
      failures = total_failures,
      errors = 0,
      skipped = total_skipped,
      time = elapsed_time,
      files_tested = #files,
      files_passed = passed_files,
      files_failed = failed_files,
      success = all_passed,
      test_cases = {},
    }

    -- Add individual test cases from structured results if available
    if #all_test_results > 0 then
      for _, result in ipairs(all_test_results) do
        local test_case = {
          name = result.name,
          path = result.path_string,
          status = result.status,
          file = result.file_path,
          time = result.execution_time or 0,
        }

        -- Add error details for failed tests
        if result.status == "fail" and result.error_message then
          test_case.failure = {
            message = result.error_message,
            type = "Assertion",
          }
        end

        -- Add metadata
        if result.options then
          test_case.metadata = result.options
        end

        table.insert(test_results.test_cases, test_case)
      end

      get_logger().debug("Added structured test cases to JSON output", {
        test_case_count = #test_results.test_cases,
      })
    end

    -- Format as JSON with markers for parallel execution
    local json_results = json_module.encode(test_results)
    get_logger().info("Overall JSON results", { results = "RESULTS_JSON_BEGIN" .. json_results .. "RESULTS_JSON_END" })
  end

  return all_passed
end

--- Runs tests in watch mode, re-running when files change.
--- Requires the `lib.tools.watcher` module to be available.
---@param path string The directory or file path to watch.
---@param firmo table The firmo module instance.
---@param options? RunnerOptions Options for test execution and watching:
---  - `interval` (number, default 1.0): Check interval in seconds.
---  - `exclude_patterns` (string[]): Patterns to exclude from watching.
---@return boolean run_success True if the initial run and subsequent runs were successful (exited cleanly or no failures), false otherwise.
function runner.watch_mode(path, firmo, options)
  if not watcher then
    get_logger().error("Watch mode unavailable", { reason = "Watcher module not found" })
    return false
  end

  options = options or {}
  local exclude_patterns = options.exclude_patterns or { "node_modules", "%.git" }
  local watch_interval = options.interval or 1.0

  -- Initialize the file watcher
  get_logger().info("Watch mode activated")
  get_logger().info("Press Ctrl+C to exit")

  -- Determine what to watch based on path type
  local directories = {}
  local files = {}

  -- Check if path is a directory or file
  if get_fs().directory_exists(path) then
    -- Watch the directory and run tests in it
    table.insert(directories, path)

    -- Find test files in the directory
    local test_pattern = options.pattern or "*_test.lua"
    local found = get_fs().discover_files({ path }, { test_pattern }, exclude_patterns)

    if found then
      for _, file in ipairs(found) do
        table.insert(files, file)
      end
    end

    get_logger().info("Watching directory", { path = path, files_found = #files })
  elseif get_fs().file_exists(path) then
    -- Watch the file's directory and run the specific file
    local dir = get_fs().get_directory_name(path)
    table.insert(directories, dir)
    table.insert(files, path)

    get_logger().info("Watching file", { file = path, directory = dir })
  else
    get_logger().error("Path not found for watch mode", { path = path })
    return false
  end

  watcher.set_check_interval(watch_interval)
  watcher.init(directories, exclude_patterns)

  local last_run_time = os.time()
  local debounce_time = 0.5 -- seconds to wait after changes before running tests
  local last_change_time = 0
  local need_to_run = true
  local run_success = true

  -- Create a copy of options for the runner
  local runner_options = {}
  for k, v in pairs(options) do
    runner_options[k] = v
  end

  -- Watch loop
  while true do
    local current_time = os.time()

    -- Check for file changes
    local changed_files = watcher.check_for_changes()
    if changed_files then
      last_change_time = current_time
      need_to_run = true

      get_logger().info("File changes detected", { files = #changed_files })
      for _, file in ipairs(changed_files) do
        get_logger().info("Changed file", { path = file })
      end
    end

    -- Run tests if needed and after debounce period
    if need_to_run and current_time - last_change_time >= debounce_time then
      get_logger().info("Running tests", { timestamp = os.date("%Y-%m-%d %H:%M:%S") })

      -- Clear terminal
      io.write("\027[2J\027[H")

      firmo.reset()

      -- Run tests based on the files we found earlier
      if #files > 0 then
        run_success = runner.run_all(files, firmo, runner_options)
      else
        get_logger().warn("No test files found to run")
        run_success = true
      end

      last_run_time = current_time
      need_to_run = false

      get_logger().info("Watching for changes")
    end

    -- Small sleep to prevent CPU hogging
    os.execute("sleep 0.1")
  end

  return run_success
end

--- Parses command-line arguments into an options table.
---@param args string[] Array of command-line arguments (like global `arg`).
---@return string|nil path The primary path argument (file or directory), or nil if none found.
---@return RunnerOptions options A table containing parsed options.
function runner.parse_arguments(args)
  local options = {
    verbose = false, -- Verbose output
    memory = false, -- Track memory usage
    performance = false, -- Show performance stats
    coverage = false, -- Enable coverage tracking
    coverage_debug = false, -- Enable debug output for coverage
    quality = false, -- Enable quality validation
    quality_level = 3, -- Quality validation level
    watch = false, -- Enable watch mode
    json_output = false, -- Output JSON results
    pattern = nil, -- Pattern for test files
    filter = nil, -- Filter pattern for tests
    report_dir = "./coverage-reports", -- Directory for reports
    formats = { "html", "json", "lcov", "cobertura" }, -- Report formats
    threshold = 80, -- Coverage/quality threshold
    exclude_patterns = { "fixtures/*" }, -- Patterns to exclude
  }

  print("Parse arguments input:")
  for i, arg in ipairs(args) do
    print(i, arg)
  end

  local path = nil
  local i = 1

  while i <= #args do
    local arg = args[i]

    -- Boolean flags
    if arg == "--verbose" or arg == "-v" then
      options.verbose = true
    elseif arg == "--version" or arg == "-V" then
      print("firmo - Version " .. version.string)
      os.exit(0)
    elseif arg == "--memory" or arg == "-m" then
      options.memory = true
    elseif arg == "--performance" or arg == "-p" then
      options.performance = true
    elseif arg == "--coverage" or arg == "-c" then
      options.coverage = true
      print("SET COVERAGE OPTION TO TRUE")
    elseif arg == "--coverage-debug" or arg == "-cd" then
      options.coverage_debug = true
    elseif arg == "--quality" or arg == "-q" then
      options.quality = true
    elseif arg == "--watch" or arg == "-w" then
      options.watch = true
    elseif arg == "--json" or arg == "-j" then
      options.json_output = true

    -- Options with values (format: --option=value or --option value)
    elseif arg:match("^%-%-pattern=(.+)$") then
      options.pattern = arg:match("^%-%-pattern=(.+)$")
    elseif arg:match("^%-%-filter=(.+)$") then
      options.filter = arg:match("^%-%-filter=(.+)$")
    elseif arg:match("^%-%-report%-dir=(.+)$") then
      options.report_dir = arg:match("^%-%-report%-dir=(.+)$")
    elseif arg:match("^%-%-quality%-level=(%d+)$") then
      options.quality_level = tonumber(arg:match("^%-%-quality%-level=(%d+)$"))
    elseif arg:match("^%-%-threshold=(%d+)$") then
      options.threshold = tonumber(arg:match("^%-%-threshold=(%d+)$"))
    elseif arg:match("^%-%-format=(.+)$") then
      options.formats = { arg:match("^%-%-format=(.+)$") }

    -- Options with values (separate argument)
    elseif arg == "--pattern" and i < #args then
      i = i + 1
      options.pattern = args[i]
    elseif arg == "--filter" and i < #args then
      i = i + 1
      options.filter = args[i]
    elseif arg == "--report-dir" and i < #args then
      i = i + 1
      options.report_dir = args[i]
    elseif arg == "--quality-level" and i < #args then
      i = i + 1
      options.quality_level = tonumber(args[i])
    elseif arg == "--threshold" and i < #args then
      i = i + 1
      options.threshold = tonumber(args[i])
    elseif arg == "--format" and i < #args then
      i = i + 1
      options.formats = { args[i] }

    -- Help flag
    elseif arg == "--help" or arg == "-h" then
      runner.print_usage()
      os.exit(0)

    -- First non-flag argument is considered the path
    elseif not arg:match("^%-") and not path then
      path = arg
    end

    i = i + 1
  end

  return path, options
end

--- Prints usage information to standard output.
---@return nil
---@private
function runner.print_usage()
  print("Usage: lua scripts/runner.lua [options] [path]")
  print("")
  print("Where path can be a file or directory, and options include:")
  print("  --pattern=<pattern>   Only run test files matching pattern (e.g., '*_test.lua')")
  print("  --filter=<filter>     Only run tests matching filter (by tag or description)")
  print("  --format=<format>     Output format (summary, tap, junit, etc.)")
  print("  --report-dir=<path>   Save reports to specified directory")
  print("  --coverage, -c        Enable coverage tracking")
  print("  --coverage-debug, -cd Enable debug output for coverage")
  print("  --quality, -q         Enable quality validation")
  print("  --quality-level=<n>   Set quality validation level (1-5)")
  print("  --threshold=<n>       Set coverage/quality threshold (0-100)")
  print("  --verbose, -v         Enable verbose output")
  print("  --memory, -m          Track memory usage")
  print("  --performance, -p     Show performance metrics")
  print("  --watch, -w           Enable watch mode for continuous testing")
  print("  --json, -j            Output JSON results")
  print("  --version, -V         Show version")
  print("  --help, -h            Show this help message")
  print("")
  print("Examples:")
  print("  lua scripts/runner.lua tests/coverage_test.lua     Run a single test file")
  print("  lua scripts/runner.lua tests/                      Run all tests in directory")
  print("  lua scripts/runner.lua --pattern=coverage tests/   Run coverage-related tests")
  print("  lua scripts/runner.lua --coverage tests/           Run tests with coverage")
end

--- Main entry point when the script is executed directly.
--- Parses arguments, loads firmo, initializes coverage/watch mode if requested,
--- runs tests, generates reports, and sets the process exit code.
---@param args string[] Array of command-line arguments (typically `_G.arg`).
---@return boolean final_success True if tests passed and reports generated successfully, false otherwise.
---@throws error If critical modules cannot be loaded.
function runner.main(args)
  -- Print all args for debugging
  print("Runner.main called with arguments:")
  for i, arg in ipairs(args) do
    print(i, arg)
  end

  -- Parse command-line arguments
  local path, options = runner.parse_arguments(args)

  -- Print options for debugging
  print("Parsed options:")
  print("  path:", path)
  print("  coverage:", options.coverage)
  print("  report_dir:", options.report_dir)

  -- Make sure we have a path
  if not path then
    get_logger().error("No path specified", { usage = "lua scripts/runner.lua [options] [path]" })
    runner.print_usage()
    return false
  end

  -- Try to load firmo
  local firmo_loaded, firmo = pcall(require, "firmo")
  if not firmo_loaded then
    -- Try again with relative path
    firmo_loaded, firmo = pcall(require, "firmo")
    if not firmo_loaded then
      get_logger().error("Failed to load firmo", { error = get_error_handler().format_error(firmo) })
      return false
    end
  end

  -- Check if we're running in watch mode
  if options.watch then
    -- Setup watch mode for continuous testing
    return runner.watch_mode(path, firmo, options)
  end

  -- Initialize coverage if running with --coverage flag
  local coverage_init_success = true
  local coverage = nil

  -- Try to load the central configuration
  local central_config = try_require("lib.core.central_config")
  get_logger().info("Central configuration loaded successfully")

  -- Try to load from .firmo-config.lua if it exists
  if get_fs().file_exists(".firmo-config.lua") then
    local config_loaded, config_err = central_config.load_from_file(".firmo-config.lua")
    if config_loaded then
      get_logger().info("Loaded configuration from .firmo-config.lua")
    else
      get_logger().warn("Failed to load .firmo-config.lua", {
        error = get_error_handler().format_error(config_err),
      })
    end
  end

  if options.coverage then
    -- Load coverage module
    local coverage = try_require("lib.coverage")

    -- Create a coverage configuration matching the schema
    local coverage_config = {
      enabled = true,
      include = { "%.lua$" }, -- Include all Lua files by default
      exclude = {
        "tests/",
        "test%.lua$",
        "examples/",
        "docs/",
      },
      statsfile = ".coverage-stats",
      savestepsize = 100,
      tick = false,
      codefromstrings = false,
      threshold = 90,
    }

    -- Only apply command line debug if specified
    if options.coverage_debug then
      coverage_config.debug = true
      get_logger().debug("Enabling debug mode for coverage from command line")
    end

    -- Let central_config override our defaults if available
    if central_config then
      local config_success, current_config = pcall(function()
        return central_config.get("coverage")
      end)

      if config_success and current_config then
        -- Merge with our defaults, preferring central_config values
        for k, v in pairs(current_config) do
          coverage_config[k] = v
        end

        get_logger().debug("Using coverage settings from central configuration", {
          include_count = current_config.include and #current_config.include or 0,
          exclude_count = current_config.exclude and #current_config.exclude or 0,
          enabled = current_config.enabled,
          statsfile = current_config.statsfile,
        })
      end
    end

    -- Initialize coverage with the merged configuration
    local ok, err = pcall(function()
      coverage.init(coverage_config)

      -- Start coverage tracking
      coverage.start()

      -- Debug output of final configuration
      get_logger().debug("Coverage initialized with configuration", {
        include_patterns = coverage_config.include and table.concat(coverage_config.include, ", ") or "none",
        exclude_patterns = coverage_config.exclude and table.concat(coverage_config.exclude, ", ") or "none",
        debug_mode = coverage_config.debug,
      })
    end)

    if not ok then
      get_logger().error("Failed to initialize or start coverage", {
        error = get_error_handler().format_error(err),
      })
      coverage_init_success = false
    else
      get_logger().info("Coverage tracking started successfully")
    end

    -- Always store coverage in options so it can be passed to both run_file and run_all
    options.coverage_instance = coverage
  end

  -- Check if path is a file or directory
  -- We can automatically detect directories without a flag
  local test_success = false

  if get_fs().directory_exists(path) then
    -- Run all tests in directory
    get_logger().info("Detected directory path", { path = path })
    test_success = runner.run_all(path, firmo, options)

    if not test_success then
      get_logger().error("Test failures detected in directory", { path = path })
      -- Continue to generate reports, but remember to return false at the end
    end
  elseif get_fs().file_exists(path) then
    -- Run a single test file with the same options (including coverage)
    get_logger().info("Detected file path", { path = path })
    local result = runner.run_file(path, firmo, options)
    test_success = result.success and result.errors == 0

    if not test_success then
      get_logger().error("Test failures detected in file", {
        path = path,
        success = result.success,
        errors = result.errors,
        test_errors = #(result.test_errors or {}),
      })

      -- Print specific error details
      if result.test_errors and #result.test_errors > 0 then
        for i, err in ipairs(result.test_errors) do
          get_logger().error(string.format("Test error #%d: %s", i, err.message), {
            test_name = err.test_name,
            file = err.file,
          })
        end
      end

      -- Continue to generate reports, but remember to return false at the end
    end
  else
    -- Path not found
    get_logger().error("Path not found", { path = path })
    return false
  end

  -- Handle coverage if it was enabled
  local report_success = true

  if options.coverage and coverage and coverage_init_success then
    -- Stop coverage tracking
    local ok, err = pcall(function()
      coverage.shutdown()
    end)

    if not ok then
      get_logger().error("Failed to stop coverage tracking", {
        error = get_error_handler().format_error(err),
      })
      report_success = false
    end

    -- Try to safely extract coverage stats
    local success, stats = pcall(function()
      return coverage.load_stats()
    end)
    if success and stats then
      -- Create report directory
      local report_dir = options.report_dir or "./coverage-reports"
      get_fs().ensure_directory_exists(report_dir)

      -- Generate reports through reporting module
      local reporting = try_require("lib.reporting")

      -- Let reporting module handle all formatting and report generation
      local formats = options.formats or { "html", "json", "lcov", "cobertura", "tap", "csv", "junit", "summary" }
      get_logger().info("Using reporting system for coverage report generation")

      for _, format in ipairs(formats) do
        local report_path = get_fs().join_paths(report_dir, "coverage-report." .. format)
        local success, err = reporting.save_coverage_report(report_path, stats, format)
        if not success then
          get_logger().error("Failed to generate " .. format .. " report", {
            error = tostring(err),
            format = format,
          })
          report_success = false
        else
          get_logger().info("Generated coverage report", {
            format = format,
            path = report_path,
          })
        end
      end
    else
      get_logger().error("Failed to load coverage stats", {
        operation = "coverage tracking",
      })
      report_success = false
    end
  end
  -- Simplified debug logging for coverage tracking
  if options.coverage then
    get_logger().debug("Coverage tracking status", {
      coverage_enabled = options.coverage == true,
      coverage_initialized = coverage_init_success,
      reports_generated = report_success,
    })
  end

  -- Log a clear error message if tests failed
  if not test_success then
    get_logger().error("TESTS FAILED! Returning non-zero exit code", {
      reason = "Tests had failures or execution errors",
      exit_code = 1,
    })
  end

  -- Return the combined success status
  local final_success = test_success and coverage_init_success and report_success
  return final_success
end

-- If this script is being run directly, execute main function
if arg and arg[0]:match("runner%.lua$") then
  -- Create a clean args table (without script name)
  local args = {}
  for i = 1, #arg do
    args[i] = arg[i]
  end

  local success = runner.main(args)

  -- Log the exit code to ensure transparency
  get_logger().info("Exiting with code", {
    success = success,
    exit_code = success and 0 or 1,
    reason = success and "All tests passed" or "Test failures detected",
  })

  -- Always exit with appropriate code
  os.exit(success and 0 or 1)
end

return runner
