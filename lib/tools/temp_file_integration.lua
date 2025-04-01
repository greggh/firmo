--[[
Temporary File Integration for test runners

This module integrates the temp_file module with test runners to provide automatic temporary file
management for tests. It patches test runner functionality to track file creation and cleanup
within test contexts, ensuring all temporary resources are properly cleaned up after tests complete.

Features:
- Automatic tracking of temporary files by test context
- Customizable cleanup policies (immediate, end-of-test, end-of-suite)
- Integration with firmo test framework
- Multiple cleanup attempts for resilience against locked files
- Comprehensive logging and statistics tracking
]]

---@class temp_file_integration
---@field _VERSION string Module version (following semantic versioning)
---@field patch_runner fun(runner: table): boolean, string? Patch a test runner to handle temp file cleanup automatically
---@field register_test_start fun(callback: fun(context: string)): boolean Register a callback to be called at the start of each test
---@field register_test_end fun(callback: fun(context: string, success: boolean, duration: number)): boolean Register a callback to be called at the end of each test
---@field register_suite_end fun(callback: fun(stats: {tests: number, passed: number, failed: number, skipped: number, duration: number})): boolean Register a callback to be called at the end of a test suite
---@field cleanup_all fun(max_attempts?: number): boolean, table?, table? Clean up all managed temporary files with multiple attempts if needed
---@field get_stats fun(): {registered_callbacks: number, test_starts: number, test_ends: number, suite_ends: number, cleanup_operations: number, cleanup_errors: number, files_cleaned: number, bytes_cleaned: number} Get statistics about temp file management
---@field integrate_with_firmo fun(firmo: table): boolean Integrate with the firmo test framework
---@field extract_context fun(test: table): string Extract context information from a test object
---@field register_for_cleanup fun(file_path: string, context: string): boolean Register a file for cleanup with a specific context
---@field set_cleanup_policy fun(policy: string): boolean Set the cleanup policy ("immediate", "end-of-test", "end-of-suite")
---@field cleanup_for_context fun(context: string): number, table?, table? Clean up files for a specific test context
---@field get_test_contexts fun(): table<string, {files: number, directories: number, created: number, cleaned: boolean, last_access: number}> Get all registered test contexts with detailed statistics
---@field configure fun(options: {auto_register?: boolean, cleanup_policy?: string, cleanup_on_suite_end?: boolean, cleanup_on_test_failure?: boolean, max_cleanup_attempts?: number}): temp_file_integration Configure the integration module
---@field add_final_cleanup fun(runner: table): boolean Add final cleanup hooks to a test runner
---@field patch_firmo fun(firmo: table): boolean Patch the firmo framework instance to integrate temp file management
---@field initialize fun(firmo_instance?: table): boolean Initialize the temp file integration module

local M = {}
local temp_file = require("lib.tools.temp_file")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("temp_file_integration")

---@private
---@param test table|string The test object or string identifier
---@return string context A string representation of the test context for tracking
-- Extract context info from a test object or convert to string
local function get_context_string(test)
  if type(test) == "table" then
    if test.name then
      return test.name
    elseif test.description then
      return test.description
    end
  end

  return tostring(test)
end

--- Patch the runner.lua file's execute_test function to handle temp file tracking and cleanup
--- Creates a wrapper around the original execute_test function that sets/clears the test context
--- and ensures proper cleanup of temporary files after each test execution.
---@param runner table The test runner instance to patch
---@return boolean success Whether the patching was successful
---@return string? error Error message if patching failed
---@return string|nil error_message Error message if patching failed
function M.patch_runner(runner)
  -- Save original execute_test function
  if runner.execute_test then
    runner._original_execute_test = runner.execute_test

    -- Replace with our version that handles temp file cleanup
    runner.execute_test = function(test, ...)
      -- Set the current test context
      temp_file.set_current_test_context(test)

      logger.debug("Setting test context for temp file tracking", {
        test = get_context_string(test),
      })

      -- Execute the test
      local success, result = runner._original_execute_test(test, ...)

      -- Clean up temporary files for this test
      local cleanup_success, cleanup_errors = temp_file.cleanup_test_context(test)

      if not cleanup_success and cleanup_errors and #cleanup_errors > 0 then
        -- Log cleanup issues but don't fail the test
        logger.warn("Failed to clean up some temporary files", {
          test = get_context_string(test),
          error_count = #cleanup_errors,
        })
      end

      -- Clear the test context
      temp_file.clear_current_test_context()

      return success, result
    end

    logger.info("Successfully patched runner.execute_test for temp file tracking")
    return true
  else
    logger.error("Failed to patch runner - execute_test function not found")
    return false
  end
end

--- Clean up all managed temporary files with retries for resilience
--- Performs multiple cleanup attempts to handle files that might be temporarily locked or in use.
--- Logs detailed information about cleanup success/failure and resources cleaned.
---@param max_attempts? number Number of cleanup attempts to make (default: 2)
---@return boolean success Whether the cleanup was completely successful
---@return table|nil errors List of resources that could not be cleaned up
---@return table|nil stats Statistics about the cleanup operation
function M.cleanup_all(max_attempts)
  logger.info("Performing final cleanup of all temporary files")

  max_attempts = max_attempts or 2
  local success, errors, stats

  -- Make multiple cleanup attempts to handle files that might be temporarily locked
  for attempt = 1, max_attempts do
    success, errors, stats = temp_file.cleanup_all()

    -- If completely successful or no errors left, we're done
    if success or (errors and #errors == 0) then
      logger.info("Temporary file cleanup successful", {
        attempt = attempt,
        max_attempts = max_attempts,
      })
      break
    end

    -- If we still have errors but have more attempts left
    if errors and #errors > 0 and attempt < max_attempts then
      logger.debug("Cleanup attempt " .. attempt .. " had issues, trying again", {
        error_count = #errors,
      })

      -- Wait a short time before trying again (increasing delay for each attempt)
      os.execute("sleep " .. tostring(0.5 * attempt))
    end
  end

  -- Log final status after all attempts
  if not success and errors and #errors > 0 then
    logger.warn("Failed to clean up some temporary files during final cleanup", {
      error_count = #errors,
      attempts = max_attempts,
    })

    -- Log detailed info about each failed resource at debug level
    for i, resource in ipairs(errors) do
      logger.debug("Failed to clean up resource " .. i, {
        path = resource.path,
        type = resource.type,
      })
    end
  end

  if stats then
    logger.info("Temporary file cleanup statistics", {
      contexts = stats.contexts,
      total_resources = stats.total_resources,
      files = stats.files,
      directories = stats.directories,
    })
  end

  return success, errors, stats
end

--- Add final cleanup hooks to a test runner
--- Patches the run_all_tests function to perform comprehensive cleanup after all tests complete.
--- This is a crucial integration point that ensures no temporary files are left behind after a test run.
--- The final cleanup includes multiple attempts and detailed logging of any remaining resources.
---@param runner table The test runner instance to patch
---@return boolean success Whether the hooks were added successfully
function M.add_final_cleanup(runner)
  if runner.run_all_tests then
    runner._original_run_all_tests = runner.run_all_tests

    runner.run_all_tests = function(...)
      local success, result = runner._original_run_all_tests(...)

      -- Final cleanup of any remaining temporary files
      local stats = temp_file.get_stats()

      if stats.total_resources > 0 then
        logger.warn("Found uncleaned temporary files after all tests", {
          total_resources = stats.total_resources,
          files = stats.files,
          directories = stats.directories,
        })

        -- Force cleanup of all remaining files with multiple attempts
        -- Use 3 attempts for final cleanup to be more thorough
        M.cleanup_all(3)
      end

      -- Double-check if there are still resources after cleanup
      stats = temp_file.get_stats()
      if stats.total_resources > 0 then
        logger.warn("Still have uncleaned resources after final cleanup", {
          total_resources = stats.total_resources,
        })
      else
        logger.info("All temporary resources successfully cleaned up")
      end

      return success, result
    end

    logger.info("Successfully added final cleanup step to runner")
    return true
  else
    logger.error("Failed to add final cleanup - run_all_tests function not found")
    return false
  end
end

--- Patch the firmo framework instance to integrate temp file management
--- Adds test context tracking to the firmo framework by wrapping the describe and it functions.
--- This enables accurate tracking of which temporary files are created by which tests, ensuring
--- proper cleanup and preventing resource leaks between tests. The patching preserves all
--- original functionality while adding transparent temp file tracking.
---@param firmo table The firmo framework instance to patch
---@return boolean success Whether the patching was successful
function M.patch_firmo(firmo)
  if firmo then
    -- Add test context tracking
    if not firmo._current_test_context then
      firmo._current_test_context = nil
    end

    -- Add get_current_test_context function if it doesn't exist
    if not firmo.get_current_test_context then
      firmo.get_current_test_context = function()
        return firmo._current_test_context
      end
    end

    -- Add test context setting for it() function
    if firmo.it and not firmo._original_it then
      firmo._original_it = firmo.it

      firmo.it = function(description, ...)
        -- Get the remaining arguments
        local args = { ... }

        -- Find the function argument (last argument or second-to-last if there are options)
        local fn_index = #args
        local options = nil

        -- Check if the second argument is a table (options)
        if #args > 1 and type(args[1]) == "table" then
          options = args[1]
          fn_index = 2
        end

        -- Ensure we have a function
        if type(args[fn_index]) ~= "function" then
          return firmo._original_it(description, ...)
        end

        -- Replace the function with our wrapper
        local original_fn = args[fn_index]
        args[fn_index] = function(...)
          -- Create a test context object with name
          local test_context = {
            type = "it",
            name = description,
            options = options,
          }

          -- Set as current test context
          local prev_context = firmo._current_test_context
          firmo._current_test_context = test_context

          -- Call the original function
          local success, result = pcall(original_fn, ...)

          -- Restore previous context
          firmo._current_test_context = prev_context

          -- Propagate any errors
          if not success then
            error(result)
          end

          return result
        end

        -- Call the original it function with our wrapped function
        if options then
          return firmo._original_it(description, options, args[fn_index])
        else
          return firmo._original_it(description, args[fn_index])
        end
      end

      logger.info("Successfully patched firmo.it for temp file tracking")
    end

    -- Add test context setting for describe() function
    if firmo.describe and not firmo._original_describe then
      firmo._original_describe = firmo.describe

      firmo.describe = function(description, ...)
        -- Get the remaining arguments
        local args = { ... }

        -- Find the function argument (last argument or second-to-last if there are options)
        local fn_index = #args
        local options = nil

        -- Check if the second argument is a table (options)
        if #args > 1 and type(args[1]) == "table" then
          options = args[1]
          fn_index = 2
        end

        -- Ensure we have a function
        if type(args[fn_index]) ~= "function" then
          return firmo._original_describe(description, ...)
        end

        -- Replace the function with our wrapper
        local original_fn = args[fn_index]
        args[fn_index] = function(...)
          -- Create a test context object with name
          local test_context = {
            type = "describe",
            name = description,
            options = options,
          }

          -- Set as current test context (for nested describes)
          local prev_context = firmo._current_test_context
          firmo._current_test_context = test_context

          -- Call the original function
          local success, result = pcall(original_fn, ...)

          -- Restore previous context
          firmo._current_test_context = prev_context

          -- Propagate any errors
          if not success then
            error(result)
          end

          return result
        end

        -- Call the original describe function with our wrapped function
        if options then
          return firmo._original_describe(description, options, args[fn_index])
        else
          return firmo._original_describe(description, args[fn_index])
        end
      end

      logger.info("Successfully patched firmo.describe for temp file tracking")
    end

    logger.info("Successfully patched firmo for temp file tracking")
    return true
  else
    logger.error("Failed to patch firmo - module not provided")
    return false
  end
end

--- Initialize the temp file integration module
--- Sets up the integration between temporary file management and the test framework.
--- This function can work with or without an explicit firmo instance:
--- - If firmo_instance is provided, it will patch that instance directly
--- - If no instance is provided, it will check for a global firmo instance (_G.firmo)
--- - If a global instance exists but already has context tracking, it will not patch again
---
--- This flexibility allows the integration to work in various testing scenarios while
--- preventing duplicate patches that could lead to unexpected behavior.
---@param firmo_instance? table Optional firmo instance to patch directly
---@return boolean success Whether the initialization was successful
function M.initialize(firmo_instance)
  logger.info("Initializing temp file integration")

  -- First check if firmo instance was directly provided
  if firmo_instance then
    logger.debug("Using explicitly provided firmo instance")
    M.patch_firmo(firmo_instance)
    return true
  end

  -- Check if we're already running within the test system via global firmo
  local should_initialize = true

  -- Check if we're already running within the test system
  if _G.firmo and _G.firmo.describe and _G.firmo.it and _G.firmo.expect then
    -- We're already running in the firmo test system
    -- Check if we already have the test context functionality
    if _G.firmo._current_test_context ~= nil or _G.firmo.get_current_test_context then
      -- We already have context tracking set up, no need to patch again
      logger.info("Firmo test context tracking already initialized")
      should_initialize = false
    else
      -- We need to patch the global firmo
      logger.debug("Patching global firmo instance")
      M.patch_firmo(_G.firmo)
    end
  else
    logger.debug("No global firmo instance found - initialization deferred until patch_firmo is called directly")
  end

  return true
end

return M
