-- Test runner for firmo
-- A universal test runner that can:
-- 1. Run a single test file
-- 2. Run all tests in a directory (recursively)
-- 3. Run tests matching a pattern
-- 4. Support a standardized set of command-line arguments
local runner = {}

-- Import required modules
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Set error handler to test mode since we're running tests
error_handler.set_test_mode(true)

-- Try to load watcher module if available
local watcher
local has_watcher = pcall(function()
  watcher = require("lib.tools.watcher")
end)

-- Initialize logger for runner module
local logger = logging.get_logger("runner")
logging.configure_from_config("runner")

-- Try to load module_reset for enhanced isolation
local module_reset_loaded, module_reset = pcall(require, "lib.core.module_reset")
if not module_reset_loaded then
  logger.warn("Module reset system unavailable", { fallback = "using basic isolation" })
end

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
---   - test_results: TestResult[] Array of structured test results
---   - test_errors: table[] Array of test errors
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
  local test_definition = require("lib.core.test_definition")
  if test_definition and test_definition.reset then
    test_definition.reset()

    -- Enable debug mode for test_definition if verbose is enabled
    if options.verbose and test_definition.set_debug_mode then
      test_definition.set_debug_mode(true)
    end
  end

  logger.info("Running file", { file_path = file_path })

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
  local original_logger_info = logger.info
  local original_logger_error = logger.error

  logger.info = function(message, context)
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

  logger.error = function(message, context)
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
  local temp_file_integration_loaded, temp_file_integration_module = pcall(require, "lib.tools.temp_file_integration")
  if temp_file_integration_loaded then
    temp_file_integration = temp_file_integration_module

    -- Also load the temp_file module
    local temp_file_loaded, temp_file_module = pcall(require, "lib.tools.temp_file")
    if temp_file_loaded then
      temp_file = temp_file_module

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
    end
  end

  -- Execute the test file
  local start_time = os.clock()
  local success, err = pcall(function()
    -- Verify file exists
    if not fs.file_exists(file_path) then
      error("Test file does not exist: " .. file_path)
    end

    -- Ensure proper package path for test file
    local save_path = package.path
    local dir = fs.get_directory_name(file_path)
    if dir and dir ~= "" then
      package.path = fs.join_paths(dir, "?.lua") .. ";" .. fs.join_paths(dir, "../?.lua") .. ";" .. package.path
    end

    dofile(file_path)

    package.path = save_path
  end)
  local elapsed_time = os.clock() - start_time

  -- Restore original print function
  _G.print = original_print

  -- Restore original logger functions
  logger.info = original_logger_info
  logger.error = original_logger_error

  -- Clean up temporary files
  if temp_file_integration and temp_file then
    -- Clean up any temporary files created during test execution
    logger.debug("Cleaning up temporary files after test execution", { file_path = file_path })

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
  local test_definition = require("lib.core.test_definition")
  if test_definition and test_definition.get_state then
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
  local test_definition = require("lib.core.test_definition")
  if test_definition and test_definition.get_state then
    local state = test_definition.get_state()
    if state and state.test_results and #state.test_results > 0 then
      -- Use file_test_results which now has the test_definition results
      results.test_results = file_test_results
      results.passes = state.passes or 0
      results.errors = state.errors or 0
      results.skipped = state.skipped or 0

      logger.debug("Using test_definition state for test results", {
        file = file_path,
        result_count = #state.test_results,
        passes = state.passes,
        errors = state.errors,
        skipped = state.skipped,
      })
    end
  else
    -- Fall back to traditional counters if we couldn't get structured results
    results.passes = pass_count > 0 and pass_count or (firmo.passes - prev_passes)
    results.errors = fail_count > 0 and fail_count or (firmo.errors - prev_errors)
    results.skipped = skip_count > 0 and skip_count or (firmo.skipped - prev_skipped)
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
    logger.error("Execution error", { error = err })
    table.insert(results.test_errors, {
      message = tostring(err),
      file = file_path,
      traceback = debug.traceback(),
    })

    -- CRITICAL FIX: Ensure execution errors are counted as failures
    -- This way, even if a test file has syntax errors or errors in describe blocks,
    -- it will still be properly counted as a failure
    results.errors = results.errors + 1
  end

  -- Always show the completion status with test counts
  -- Use consistent terminology
  logger.info("Test completed", {
    passes = results.passes,
    failures = results.errors,
    skipped = results.skipped,
    tests_passed = results.passes, -- Add for consistency with run_all
    tests_failed = results.errors, -- Add for consistency with run_all
  })

  -- Output JSON results if requested
  if options.json_output or options.results_format == "json" then
    -- Try to load JSON module
    local json_module
    local ok, mod = pcall(require, "lib.reporting.json")
    if not ok then
      ok, mod = pcall(require, "../lib/reporting/json")
    end

    if ok then
      json_module = mod

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
      logger.info("JSON results", { results = "RESULTS_JSON_BEGIN" .. json_results .. "RESULTS_JSON_END" })
    end
  end

  return results
end

-- Find test files in a directory
function runner.find_test_files(dir_path, options)
  options = options or {}
  local pattern = options.pattern or "*.lua"
  local filter = options.filter
  local exclude_patterns = options.exclude_patterns or { "fixtures/*" }

  logger.info("Finding test files", {
    directory = dir_path,
    pattern = pattern,
    filter = filter,
    exclude_patterns = table.concat(exclude_patterns, ", "),
  })

  -- Handle directory existence check properly
  -- The fs.normalize_path() function automatically removes trailing slashes
  -- but fs.directory_exists() works fine with or without trailing slashes

  -- Simply check if directory exists
  if not fs.directory_exists(dir_path) then
    logger.error("Directory not found", { directory = dir_path })
    return {}
  end

  -- Use filesystem module to find test files
  local files, err = fs.discover_files({ dir_path }, { pattern }, exclude_patterns)

  if not files then
    logger.error("Failed to discover test files", {
      error = error_handler.format_error(err),
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

    logger.info("Filtered test files", {
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
---@param files_or_dir string|string[] Either a directory path or array of file paths
---@param firmo table The firmo module instance
---@param options table Options for running the tests
---@return boolean Whether all tests passed
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

  logger.info("Running test files", { count = #files })

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
    logger.info("Module reset system activated", { feature = "enhanced test isolation" })
  end

  -- Coverage should be already initialized in runner.main and passed in options.coverage_instance
  -- We just need to log that we're using the pre-initialized coverage
  if options.coverage then
    if options.coverage_instance then
      logger.debug("Using pre-initialized coverage instance from main function", {
        operation = "run_all",
        coverage_instance_valid = options.coverage_instance ~= nil,
      })

      -- Ensure coverage instance is active
      if options.coverage_instance.is_active and not options.coverage_instance.is_active() then
        logger.warn("Coverage instance is not active, trying to start it", {
          operation = "run_all",
        })

        -- Try to start coverage if it's not active
        local ok, err = pcall(function()
          options.coverage_instance.start()
        end)

        if not ok then
          logger.error("Failed to start coverage in run_all", {
            error = error_handler.format_error(err),
            operation = "run_all.start_coverage",
          })
        end
      end
    else
      logger.warn("Coverage enabled but no coverage instance was passed", {
        operation = "run_all",
        solution = "Coverage instance should be initialized in main and passed in options",
      })
    end
  else
    logger.debug("Coverage not enabled in options", { coverage_option = options.coverage })
  end

  -- Try to load quality module
  local quality_loaded, quality
  if options.quality then
    quality_loaded, quality = pcall(require, "lib.quality")
    if quality_loaded then
      logger.info("Quality module loaded", { purpose = "test quality analysis" })
      -- Configure quality validation
      quality.init({
        enabled = true,
        level = options.quality_level or 3,
        debug = options.verbose == true,
        threshold = options.threshold or 80,
      })
    else
      logger.error("Failed to load quality module", {
        error = error_handler.format_error(quality),
      })
    end
  end

  for _, file in ipairs(files) do
    -- IMPORTANT: Reset the test counts for each file to correctly capture them
    local results = runner.run_file(file, firmo, options)

    -- Count passed/failed files
    -- CRITICAL FIX: Consider a file failed if:
    -- 1. There was an execution error (results.success is false), OR
    -- 2. There were test failures (results.errors > 0)
    if results.success and results.errors == 0 then
      passed_files = passed_files + 1
    else
      failed_files = failed_files + 1
      -- Log failure reason for debugging
      logger.debug("File marked as failed", {
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
      local test_definition = require("lib.core.test_definition")
      if test_definition and test_definition.get_state then
        local state = test_definition.get_state()
        file_passes = state.passes or 0
        file_errors = state.errors or 0
        file_skipped = state.skipped or 0

        -- Log that we're using state directly for debugging
        logger.debug("Using test_definition state for counts", {
          file = file,
          state_passes = file_passes,
          state_errors = file_errors,
          state_skipped = file_skipped,
        })
      end
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

      logger.debug("Collected structured test results", {
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
    logger.debug("Accumulated test counts", {
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
  logger.info("Test run summary", {
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
      logger.debug("Test timing statistics", timing_stats)
    end
  end

  local all_passed = failed_files == 0
  if not all_passed then
    logger.error("Test run failed", {
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
        logger.debug("Failed tests", { failed_tests = failed_tests })
      end
    end
  else
    logger.info("Test run successful", {
      all_passed = true,
      test_count = total_passes + total_skipped,
    })
  end

  -- Generate coverage reports if enabled
  -- Check if we should generate coverage reports
  logger.debug("Checking coverage conditions:", {
    coverage_loaded = coverage_loaded,
    has_coverage_object = coverage ~= nil,
    coverage_option_set = options.coverage,
  })

  if coverage_loaded and coverage and options.coverage then
    logger.info("Coverage conditions met - will generate reports")

    -- Stop coverage tracking
    logger.info("Stopping coverage tracking")
    if coverage.stop then
      coverage.stop()
      logger.info("Coverage tracking stopped successfully")
    else
      logger.error("Function not found", { function_name = "coverage.stop" })
    end

    -- Calculate and save coverage reports
    logger.info("Generating coverage report")

    -- get_report_data() handles stats computation internally
    -- Generate reports in different formats
    local report_dir = options.report_dir or "./coverage-reports"
    fs.ensure_directory_exists(report_dir)
    local formats = { "html", "json", "lcov", "cobertura" }

    -- Try to load the reporting module
    local reporting_loaded, reporting
    reporting_loaded, reporting = pcall(require, "lib.reporting")

    if not reporting_loaded then
      logger.error("Failed to load reporting module", {
        error = error_handler.format_error(reporting),
      })
    end

    -- Get coverage report data
    logger.info("Getting coverage report data")
    local report_data = coverage.get_report_data()

    if not report_data then
      logger.error("Failed to get coverage report data")
    else
      -- Get file count safely with manual counting
      local file_count = 0
      if report_data.files then
        for _ in pairs(report_data.files) do
          file_count = file_count + 1
        end
      end

      logger.info("Successfully got coverage report data", {
        has_summary = report_data.summary ~= nil,
        has_files = report_data.files ~= nil,
        files_count = file_count,
      })

      if reporting_loaded and reporting then
        logger.info("Reporting module loaded, generating reports")

        -- Use reporting module to generate reports
        for _, format in ipairs(formats) do
          local report_path = fs.join_paths(report_dir, "coverage-report." .. format)
          logger.info("Generating report", { format = format, path = report_path })

          local success, err = reporting.save_coverage_report(report_path, report_data, format)
          if success then
            logger.info("Generated coverage report", { format = format, path = report_path })
          else
            logger.error("Failed to generate coverage report", {
              format = format,
              error = err and error_handler.format_error(err) or "Unknown error",
            })
          end
        end
      else
        logger.error("Reporting module not available for generating reports")
      end
    end

    -- Print coverage summary
    local summary = report_data and report_data.summary
    if summary then
      -- Print detailed coverage data for debugging
      if options.debug then
        print("\nDEBUG: Coverage summary data:")
        print("  Overall coverage: " .. string.format("%.2f", summary.overall_coverage_percent or 0) .. "%")
        print("  Line coverage: " .. string.format("%.2f", summary.line_coverage_percent or 0) .. "%")
        print("  Function coverage: " .. string.format("%.2f", summary.function_coverage_percent or 0) .. "%")
        print("  File coverage: " .. string.format("%.2f", summary.file_coverage_percent or 0) .. "%")

        -- Print raw values for debugging
        print("\nDEBUG: Raw coverage values:")
        print("  Overall coverage (raw): " .. tostring(summary.overall_coverage_percent))
        print("  Line coverage (raw): " .. tostring(summary.line_coverage_percent))
        print("  Function coverage (raw): " .. tostring(summary.function_coverage_percent))
        print("  File coverage (raw): " .. tostring(summary.file_coverage_percent))
      end

      -- Use the numeric values for the logger to ensure proper display
      -- Convert percentages to strings with formatting to ensure consistent display
      logger.info("Coverage summary", {
        overall = string.format("%.2f%%", summary.overall_coverage_percent or 0),
        lines = string.format("%.2f%%", summary.line_coverage_percent or 0),
        functions = string.format("%.2f%%", summary.function_coverage_percent or 0),
        files = string.format("%.2f%%", summary.file_coverage_percent or 0),
      })

      -- Debug: Print raw values
      logger.debug("Raw coverage percentage values:", {
        overall_percent = summary.overall_coverage_percent,
        line_percent = summary.line_coverage_percent,
        function_percent = summary.function_coverage_percent,
        file_percent = summary.file_coverage_percent,
      })
    else
      logger.error("Failed to get coverage summary from report data")
    end
  end

  -- Generate quality reports if enabled
  if quality_loaded and quality and options.quality then
    logger.info("Generating quality report")
    quality.calculate_stats()

    -- Generate quality reports in different formats
    local report_dir = options.report_dir or "./coverage-reports"
    fs.ensure_directory_exists(report_dir)

    -- Use the reporting module if available, otherwise fall back to quality.save_report
    local reporting_loaded, reporting = pcall(require, "lib.reporting")

    if reporting_loaded and reporting then
      -- Get quality report data
      local quality_data = quality.get_report_data()

      if quality_data then
        -- Generate HTML quality report
        local success, err =
          reporting.save_quality_report(fs.join_paths(report_dir, "quality-report.html"), quality_data, "html")

        if success then
          logger.info("Generated HTML quality report")
        else
          logger.error("Failed to generate HTML quality report", {
            error = err and error_handler.format_error(err) or "Unknown error",
          })
        end

        -- Generate JSON quality report
        success, err =
          reporting.save_quality_report(fs.join_paths(report_dir, "quality-report.json"), quality_data, "json")

        if success then
          logger.info("Generated JSON quality report")
        else
          logger.error("Failed to generate JSON quality report", {
            error = err and error_handler.format_error(err) or "Unknown error",
          })
        end
      else
        logger.error("Failed to get quality report data")
      end
    else
      -- Fall back to legacy approach
      logger.warn("Reporting module not available, using legacy quality.save_report")

      -- Generate HTML quality report
      local success = quality.save_report(fs.join_paths(report_dir, "quality-report.html"), "html")
      if success then
        logger.info("Generated HTML quality report")
      end

      -- Generate JSON quality report
      success = quality.save_report(fs.join_paths(report_dir, "quality-report.json"), "json")
      if success then
        logger.info("Generated JSON quality report")
      end
    end

    -- Print quality summary
    local report = quality.summary_report()
    logger.info("Quality summary", {
      score = string.format("%.2f%%", report.quality_score),
      tests_analyzed = report.tests_analyzed,
      level = report.level,
      level_name = report.level_name,
    })
  end

  -- Output overall JSON results if requested
  if options.json_output or options.results_format == "json" then
    -- Try to load JSON module
    local json_module
    local ok, mod = pcall(require, "lib.reporting.json")
    if not ok then
      ok, mod = pcall(require, "../lib/reporting/json")
    end

    if ok then
      json_module = mod

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

        logger.debug("Added structured test cases to JSON output", {
          test_case_count = #test_results.test_cases,
        })
      end

      -- Format as JSON with markers for parallel execution
      local json_results = json_module.encode(test_results)
      logger.info("Overall JSON results", { results = "RESULTS_JSON_BEGIN" .. json_results .. "RESULTS_JSON_END" })
    end
  end

  return all_passed
end

-- Watch mode for continuous testing
function runner.watch_mode(path, firmo, options)
  if not has_watcher then
    logger.error("Watch mode unavailable", { reason = "Watcher module not found" })
    return false
  end

  options = options or {}
  local exclude_patterns = options.exclude_patterns or { "node_modules", "%.git" }
  local watch_interval = options.interval or 1.0

  -- Initialize the file watcher
  logger.info("Watch mode activated")
  logger.info("Press Ctrl+C to exit")

  -- Determine what to watch based on path type
  local directories = {}
  local files = {}

  -- Check if path is a directory or file
  if fs.directory_exists(path) then
    -- Watch the directory and run tests in it
    table.insert(directories, path)

    -- Find test files in the directory
    local test_pattern = options.pattern or "*_test.lua"
    local found = fs.discover_files({ path }, { test_pattern }, exclude_patterns)

    if found then
      for _, file in ipairs(found) do
        table.insert(files, file)
      end
    end

    logger.info("Watching directory", { path = path, files_found = #files })
  elseif fs.file_exists(path) then
    -- Watch the file's directory and run the specific file
    local dir = fs.get_directory_name(path)
    table.insert(directories, dir)
    table.insert(files, path)

    logger.info("Watching file", { file = path, directory = dir })
  else
    logger.error("Path not found for watch mode", { path = path })
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

      logger.info("File changes detected", { files = #changed_files })
      for _, file in ipairs(changed_files) do
        logger.info("Changed file", { path = file })
      end
    end

    -- Run tests if needed and after debounce period
    if need_to_run and current_time - last_change_time >= debounce_time then
      logger.info("Running tests", { timestamp = os.date("%Y-%m-%d %H:%M:%S") })

      -- Clear terminal
      io.write("\027[2J\027[H")

      firmo.reset()

      -- Run tests based on the files we found earlier
      if #files > 0 then
        run_success = runner.run_all(files, firmo, runner_options)
      else
        logger.warn("No test files found to run")
        run_success = true
      end

      last_run_time = current_time
      need_to_run = false

      logger.info("Watching for changes")
    end

    -- Small sleep to prevent CPU hogging
    os.execute("sleep 0.1")
  end

  return run_success
end

-- Parse command-line arguments
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

-- Print usage information
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
  print("  --help, -h            Show this help message")
  print("")
  print("Examples:")
  print("  lua scripts/runner.lua tests/coverage_test.lua     Run a single test file")
  print("  lua scripts/runner.lua tests/                      Run all tests in directory")
  print("  lua scripts/runner.lua --pattern=coverage tests/   Run coverage-related tests")
  print("  lua scripts/runner.lua --coverage tests/           Run tests with coverage")
end

-- Main function to run tests from command line
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
    logger.error("No path specified", { usage = "lua scripts/runner.lua [options] [path]" })
    runner.print_usage()
    return false
  end

  -- Try to load firmo
  local firmo_loaded, firmo = pcall(require, "firmo")
  if not firmo_loaded then
    -- Try again with relative path
    firmo_loaded, firmo = pcall(require, "firmo")
    if not firmo_loaded then
      logger.error("Failed to load firmo", { error = error_handler.format_error(firmo) })
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
  local central_config
  local central_config_loaded, central_config_result = pcall(require, "lib.core.central_config")
  if central_config_loaded then
    central_config = central_config_result
    logger.info("Central configuration loaded successfully")

    -- Try to load from .firmo-config.lua if it exists
    if fs.file_exists(".firmo-config.lua") then
      local config_loaded, config_err = central_config.load_from_file(".firmo-config.lua")
      if config_loaded then
        logger.info("Loaded configuration from .firmo-config.lua")
      else
        logger.warn("Failed to load .firmo-config.lua", {
          error = error_handler.format_error(config_err),
        })
      end
    end
  else
    logger.warn("Central configuration module not available", {
      error = error_handler.format_error(central_config_result),
    })
  end

  if options.coverage then
    -- Load coverage module
    local coverage_loaded
    coverage_loaded, coverage = pcall(require, "lib.coverage")

    if not coverage_loaded then
      -- Initialize coverage with the merged configuration
      coverage.init(coverage_config)

      -- Start coverage tracking
      coverage.start()

      -- Apply config from central configuration if available
      if central_config then
        local file_config = central_config.get("coverage", {})

        -- Merge include/exclude from config file
        if file_config.include then
          coverage_config.include = file_config.include
        end

        if file_config.exclude then
          coverage_config.exclude = file_config.exclude
        end
        
        -- Apply debug setting from config if not overridden by command line
        if file_config.debug ~= nil and not options.coverage_debug then
          coverage_config.debug = file_config.debug
        end

        logger.debug("Applied coverage settings from config file", {
          include_patterns = #(coverage_config.include or {}),
          exclude_patterns = #(coverage_config.exclude or {}),
        })
      else
        -- Fallback to reasonable defaults if no config file
        coverage_config.include = coverage_config.include
          or {
            "**/*.lua", -- All Lua files by default
            "lib/**/*.lua", -- Library code
            "firmo.lua", -- Main module
          }

        coverage_config.exclude = coverage_config.exclude
          or {
            "**/tests/**/*.lua", -- Test files

      -- Initialize coverage with the merged configuration
      -- Initialize coverage with the merged configuration
      coverage.init(coverage_config)

      -- Start coverage tracking
      coverage.start()
      -- Debug output of final configuration
      logger.debug("Coverage initialized with configuration", {
        include_patterns = coverage_config.include and table.concat(coverage_config.include, ", ") or "none",
        exclude_patterns = coverage_config.exclude and table.concat(coverage_config.exclude, ", ") or "none",
        debug_mode = coverage_config.debug,
      })
    end)

    if not ok then
      logger.error("Failed to initialize or start coverage", {
        error = error_handler.format_error(err),
      })
      coverage_init_success = false
    else
      logger.info("Coverage tracking started successfully")
    end

    -- Always store coverage in options so it can be passed to both run_file and run_all
    options.coverage_instance = coverage
  end

  -- Check if path is a file or directory
  -- We can automatically detect directories without a flag
  local test_success = false

  if fs.directory_exists(path) then
    -- Run all tests in directory
    logger.info("Detected directory path", { path = path })
    test_success = runner.run_all(path, firmo, options)

    -- CRITICAL FIX: Ensure test failures cause the process to fail
    if not test_success then
      logger.error("Test failures detected in directory", { path = path })
      -- Continue to generate reports, but remember to return false at the end
    end
  elseif fs.file_exists(path) then
    -- Run a single test file with the same options (including coverage)
    logger.info("Detected file path", { path = path })
    local result = runner.run_file(path, firmo, options)
    test_success = result.success and result.errors == 0

    -- CRITICAL FIX: Ensure test failures cause the process to fail
    if not test_success then
      logger.error("Test failures detected in file", {
        path = path,
        success = result.success,
        errors = result.errors,
        test_errors = #(result.test_errors or {}),
      })

      -- Print specific error details
      if result.test_errors and #result.test_errors > 0 then
        for i, err in ipairs(result.test_errors) do
          logger.error(string.format("Test error #%d: %s", i, err.message), {
            test_name = err.test_name,
            file = err.file,
          })
        end
      end

      -- Continue to generate reports, but remember to return false at the end
    end
  else
    -- Path not found
    logger.error("Path not found", { path = path })
    return false
  end

  -- Generate coverage reports if needed
  local report_success = true

  if options.coverage and coverage and coverage_init_success then
    -- Stop coverage tracking
    local ok, err = pcall(function()
      coverage.stop()
    end)

    if not ok then
      logger.error("Failed to stop coverage tracking", {
        error = error_handler.format_error(err),
      })
      report_success = false
    end

    -- Get coverage report data
    -- Get coverage report data
    local report_data
    -- Get coverage report data
    local report_data
    local report_data
    ok, report_data = pcall(function()
      return coverage.get_report_data()
    end)
    
    if ok and report_data then
      local file_count = 0

      -- Count files in the coverage data
      if report_data.files then
        for _ in pairs(report_data.files) do
          file_count = file_count + 1
        end
      end
          operation = "coverage tracking",
        })
        report_success = false
      else
        -- Create reports directory
        local report_dir = options.report_dir or "./coverage-reports"
        fs.ensure_directory_exists(report_dir)

        -- Generate reports
        local formats = options.formats or { "html", "json", "lcov", "cobertura" }
        -- Use the reporting module
        -- Generate reports
        local formats = options.formats or { "html", "json", "lcov", "cobertura" }
        logger.info("Using reporting module for coverage report generation")
        
        -- Load the reporting module
        local reporting
        ok, reporting = pcall(require, "lib.reporting")

        if not ok then
          logger.error("Failed to load reporting module")
          report_success = false
        else
          -- Generate reports with the reporting module
          for _, format in ipairs(formats) do
            local report_path = fs.join_paths(report_dir, "coverage-report." .. format)
            local format_success, err = reporting.save_coverage_report(report_path, report_data, format)

            if not format_success then
              logger.error("Failed to generate " .. format .. " report", {
                error = tostring(err),
                format = format,
              })
              report_success = false
            end
          end
        end
          -- Calculate actual file counts manually
          local file_count = 0
          local covered_file_count = 0
          local total_lines = 0
          local covered_lines = 0

          for file_path, file_data in pairs(report_data.files or {}) do
            file_count = file_count + 1
            covered_file_count = covered_file_count + 1 -- All files with data are considered covered

          -- Process line data
          for _, file_data in pairs(report_data.files or {}) do
            for _, line_data in pairs(file_data.lines or {}) do
              if type(line_data) == "table" and line_data.executable then
                total_lines = total_lines + 1
                if line_data.covered or line_data.executed then
                  covered_lines = covered_lines + 1
                end
              end
            end
          end

          -- Calculate percentages
          local file_percent = file_count > 0 and (covered_file_count / file_count * 100) or 0
          local line_percent = total_lines > 0 and (covered_lines / total_lines * 100) or 0

          -- Also update the summary values directly to ensure they're consistent everywhere
          report_data.summary.line_coverage_percent = line_percent
          report_data.summary.file_coverage_percent = file_percent
          report_data.summary.overall_coverage_percent = (
            file_percent
            + line_percent
            + (report_data.summary.function_coverage_percent or 0)
          ) / 3

          local overall_percent = (file_percent + line_percent + (report_data.summary.function_coverage_percent or 0))
            / 3

          -- Print report with manually calculated values
            overall = string.format("%.2f%%", overall_percent),
            lines = string.format("%.2f%%", line_percent),
            functions = string.format("%.2f%%", report_data.summary.function_coverage_percent or 0),
            files = string.format("%.2f%%", file_percent),
          })
          })

          -- Debug output for manual calculation
          logger.debug("Manual coverage calculation", {
            file_count = file_count,
            covered_file_count = covered_file_count,
            total_lines = total_lines,
            covered_lines = covered_lines,
          })
        end
      end
    end
  end

  -- CRITICAL FIX: Return success only if all operations succeeded AND no test failures
  local final_success = test_success and coverage_init_success and report_success

  -- Add more detailed logging about the exit status
  logger.debug("Exit status components", {
    test_success = test_success,
    coverage_init_success = coverage_init_success,
    report_success = report_success,
    final_success = final_success,
  })

  -- Add additional debug logging for coverage data if coverage was enabled
  if options.coverage and coverage and coverage_init_success then
    -- Check if we have report data that includes coverage metrics
    local has_report_data = false
    local line_coverage_percent = 0
    local function_coverage_percent = 0
    local file_coverage_percent = 0

    -- Try to safely extract coverage percentages for validation
    local success, report_data = pcall(function()
      return coverage.get_report_data()
    end)

    if success and report_data and report_data.summary then
      has_report_data = true
      line_coverage_percent = report_data.summary.line_coverage_percent or 0
      function_coverage_percent = report_data.summary.function_coverage_percent or 0
      file_coverage_percent = report_data.summary.file_coverage_percent or 0
    end

    logger.debug("Coverage data consistency check", {
      is_coverage_enabled = options.coverage == true,
      coverage_object_valid = coverage ~= nil,
      is_coverage_enabled = options.coverage == true,
      coverage_object_valid = coverage ~= nil,
      function_coverage_percent = string.format("%.2f%%", function_coverage_percent),
      file_coverage_percent = string.format("%.2f%%", file_coverage_percent),

  -- Log a clear error message if tests failed
  if not test_success then
    logger.error("TESTS FAILED! Returning non-zero exit code", {
      reason = "Tests had failures or execution errors",
      exit_code = 1,
    })
  end

  -- Return the combined success status
  return final_success
end

-- If this script is being run directly, execute main function
if arg and arg[0]:match("runner%.lua$") then
  -- Create a clean args table (without script name)
  local args = {}
  for i = 1, #arg do
    args[i] = arg[i]
  end

  -- CRITICAL FIX: Run the main function and always exit with appropriate code
  -- This ensures test failures are properly propagated to the OS exit code
  local success = runner.main(args)

  -- Log the exit code to ensure transparency
  logger.info("Exiting with code", {
    success = success,
    exit_code = success and 0 or 1,
    reason = success and "All tests passed" or "Test failures detected",
  })

  -- Always exit with appropriate code
  os.exit(success and 0 or 1)
end

return runner
