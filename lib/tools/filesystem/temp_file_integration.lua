--- Temporary File Integration for Firmo Test Runners
---
--- Integrates `lib.tools.filesystem.temp_file` with test runners (specifically `firmo`
--- and `lib.core.runner`) to provide automatic context tracking and cleanup for
--- temporary files and directories created during tests.
---
--- Patches core runner/framework functions (`execute_test`, `run_all_tests`, `it`, `describe`)
--- to set/clear the current test context in the `temp_file` module, enabling it to
--- associate temporary resources with specific tests or files for targeted cleanup.
---
--- @module lib.tools.filesystem.temp_file_integration
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class temp_file_integration The public API for the temp file integration module.
---@field _VERSION string Module version (following semantic versioning).
---@field patch_runner fun(runner: table): boolean, string? Patches `runner.execute_test` for context management. Returns `success, error_message?`.
---@field cleanup_all fun(max_attempts?: number): boolean, table?, table? Runs cleanup via `temp_file.cleanup_all` with retries. Returns `success, errors?, stats?`.
---@field add_final_cleanup fun(runner: table): boolean Patches `runner.run_all_tests` to add a final cleanup step.
---@field patch_firmo fun(firmo: table): boolean Patches `firmo.it` and `firmo.describe` to manage context via `temp_file.set/clear_current_test_context`.
---@field initialize fun(firmo_instance?: table): boolean Initializes the integration, typically patching the global `_G.firmo` if found.
---@field register_test_start fun(...) [Not Implemented] Register a callback to be called at the start of each test.
---@field register_test_end fun(...) [Not Implemented] Register a callback to be called at the end of each test.
---@field register_suite_end fun(...) [Not Implemented] Register a callback to be called at the end of a test suite.
---@field get_stats fun(...) [Not Implemented] Get statistics about temp file management.
---@field extract_context fun(...) [Not Implemented] Extract context information from a test object.
---@field register_for_cleanup fun(...) [Not Implemented] Register a file for cleanup with a specific context.
---@field set_cleanup_policy fun(...) [Not Implemented] Set the cleanup policy.
---@field cleanup_for_context fun(...) [Not Implemented] Clean up files for a specific test context.
---@field get_test_contexts fun(...) [Not Implemented] Get all registered test contexts with detailed statistics.
---@field configure fun(...) [Not Implemented] Configure the integration module.

local M = {}

--- Module version
M._VERSION = "1.0.0"

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
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
    return logging.get_logger("temp_file_integration")
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

local temp_file = try_require("lib.tools.filesystem.temp_file")

--- Extracts a string representation of the test context for logging and tracking.
--- Handles both table (uses `name` or `description`) and non-table inputs (`tostring`).
---@param test table|string The test object or string identifier.
---@return string context A string representation of the context.
---@private
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
---@param runner table The test runner instance (`lib.core.runner`) to patch.
---@return boolean success `true` if patching was successful, `false` otherwise (e.g., `execute_test` not found).
---@return string? error_message An error message if patching failed.
function M.patch_runner(runner)
  -- Save original execute_test function
  if runner.execute_test then
    runner._original_execute_test = runner.execute_test

    -- Replace with our version that handles temp file cleanup
    runner.execute_test = function(test, ...)
      -- Set the current test context
      temp_file.set_current_test_context(test)

      get_logger().debug("Setting test context for temp file tracking", {
        test = get_context_string(test),
      })

      -- Execute the test
      local success, result = runner._original_execute_test(test, ...)

      -- Clean up temporary files for this test
      local cleanup_success, cleanup_errors = temp_file.cleanup_test_context(test)

      if not cleanup_success and cleanup_errors and #cleanup_errors > 0 then
        -- Log cleanup issues but don't fail the test
        get_logger().warn("Failed to clean up some temporary files", {
          test = get_context_string(test),
          error_count = #cleanup_errors,
        })
      end

      -- Clear the test context
      temp_file.clear_current_test_context()

      return success, result
    end

    get_logger().info("Successfully patched runner.execute_test for temp file tracking")
    return true
  else
    get_logger().error("Failed to patch runner - execute_test function not found")
    return false
  end
end

--- Clean up all managed temporary files with retries for resilience
--- Performs multiple cleanup attempts to handle files that might be temporarily locked or in use.
--- Logs detailed information about cleanup success/failure and resources cleaned.
---@param max_attempts? number Number of cleanup attempts (default: 2).
---@return boolean success Whether the cleanup was completely successful (`true` if `errors` is empty).
---@return table? errors List of resources `{path, type}` that could not be cleaned up after retries.
---@return table? stats Statistics about the cleanup operation returned by `temp_file.cleanup_all`.
function M.cleanup_all(max_attempts)
  get_logger().info("Performing final cleanup of all temporary files")

  max_attempts = max_attempts or 2
  local success, errors, stats

  -- Make multiple cleanup attempts to handle files that might be temporarily locked
  for attempt = 1, max_attempts do
    success, errors, stats = temp_file.cleanup_all()

    -- If completely successful or no errors left, we're done
    if success or (errors and #errors == 0) then
      get_logger().info("Temporary file cleanup successful", {
        attempt = attempt,
        max_attempts = max_attempts,
      })
      break
    end

    -- If we still have errors but have more attempts left
    if errors and #errors > 0 and attempt < max_attempts then
      get_logger().debug("Cleanup attempt " .. attempt .. " had issues, trying again", {
        error_count = #errors,
      })

      -- Wait a short time before trying again (increasing delay for each attempt)
      os.execute("sleep " .. tostring(0.5 * attempt))
    end
  end

  -- Log final status after all attempts
  if not success and errors and #errors > 0 then
    get_logger().warn("Failed to clean up some temporary files during final cleanup", {
      error_count = #errors,
      attempts = max_attempts,
    })

    -- Log detailed info about each failed resource at debug level
    for i, resource in ipairs(errors) do
      get_logger().debug("Failed to clean up resource " .. i, {
        path = resource.path,
        type = resource.type,
      })
    end
  end

  if stats then
    get_logger().info("Temporary file cleanup statistics", {
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
---@param runner table The test runner instance (`lib.core.runner`) to patch.
---@return boolean success `true` if the `run_all_tests` function was successfully patched, `false` otherwise.
function M.add_final_cleanup(runner)
  if runner.run_all_tests then
    runner._original_run_all_tests = runner.run_all_tests

    runner.run_all_tests = function(...)
      local success, result = runner._original_run_all_tests(...)

      -- Final cleanup of any remaining temporary files
      local stats = temp_file.get_stats()

      if stats.total_resources > 0 then
        get_logger().warn("Found uncleaned temporary files after all tests", {
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
        get_logger().warn("Still have uncleaned resources after final cleanup", {
          total_resources = stats.total_resources,
        })
      else
        get_logger().info("All temporary resources successfully cleaned up")
      end

      return success, result
    end

    get_logger().info("Successfully added final cleanup step to runner")
    return true
  else
    get_logger().error("Failed to add final cleanup - run_all_tests function not found")
    return false
  end
end

--- Patch the firmo framework instance to integrate temp file management
--- Adds test context tracking to the firmo framework by wrapping the describe and it functions.
--- This enables accurate tracking of which temporary files are created by which tests, ensuring
--- proper cleanup and preventing resource leaks between tests. The patching preserves all
--- original functionality while adding transparent temp file tracking.
---@param firmo table The firmo framework instance (`firmo.lua`).
---@return boolean success `true` if patching was successful (or already done), `false` if `firmo` instance is invalid.
---@throws error If the original `it` or `describe` function being wrapped throws an error, that error is propagated.
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

      get_logger().info("Successfully patched firmo.it for temp file tracking")
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

      get_logger().info("Successfully patched firmo.describe for temp file tracking")
    end

    get_logger().info("Successfully patched firmo for temp file tracking")
    return true
  else
    get_logger().error("Failed to patch firmo - module not provided")
    return false
  end
end

--- Initializes the temp file integration by patching the appropriate framework instance
--- (`firmo_instance` if provided, otherwise `_G.firmo` if found and not already patched).
--- Ensures that test context tracking is set up for `temp_file` usage.
---@param firmo_instance? table Optional `firmo` instance to patch directly.
---@return boolean success `true` if initialization/patching was performed or determined unnecessary, `false` if patching failed due to missing instance.
function M.initialize(firmo_instance)
  get_logger().info("Initializing temp file integration")

  -- First check if firmo instance was directly provided
  if firmo_instance then
    get_logger().debug("Using explicitly provided firmo instance")
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
      get_logger().info("Firmo test context tracking already initialized")
      should_initialize = false
    else
      -- We need to patch the global firmo
      get_logger().debug("Patching global firmo instance")
      M.patch_firmo(_G.firmo)
    end
  else
    get_logger().debug("No global firmo instance found - initialization deferred until patch_firmo is called directly")
  end

  return true
end

return M
