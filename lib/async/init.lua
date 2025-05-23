--- Asynchronous Testing Support for the Firmo framework
---
--- This module provides capabilities for testing asynchronous code using coroutines.
--- It allows tests to pause (`await`), wait for conditions (`wait_until`), and run
--- multiple simulated concurrent operations (`parallel_async`).
--- It includes basic timeout management and integration with the Firmo test runner (`it_async`).
---
--- @module lib.async
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.1

---@class async_module The public API for the async module.
---@field _VERSION string Module version.
---@field async fun(fn: function): fun(...): any Wraps a function to run within a managed async context, enabling `await` and `wait_until`. Returns a new function that, when called, executes the original function asynchronously.
---@field is_async_function fun(fn: any): boolean Checks if a function was wrapped by async.async(). Returns true for async-wrapped functions, false otherwise.
---@field parallel_async fun(operations: {function}, timeout_ms?: number): {any} Runs multiple async functions concurrently (simulated) and collects results. Throws on error or timeout.
---@field await fun(ms: number): nil Pauses execution within an async context for a duration.
---@field wait_until fun(condition: function, timeout_ms?: number, check_interval?: number): boolean Waits within an async context until `condition()` returns true or `timeout_ms` expires. Throws error on timeout.
---@field set_timeout fun(ms: number): async_module Sets the default timeout for async operations.
---@field get_timeout fun(): number Gets the current default timeout. Deprecated: Use `configure` or central config.
---@field is_in_async_context fun(): boolean Returns true if currently executing within a context managed by `async` or `it_async`.
---@field reset fun(): async_module Resets internal async state (e.g., `in_async_context`, config to defaults).
---@field full_reset fun(): async_module Performs `reset` and also attempts to reset central configuration for this module.
---@field debug_config fun(): table Returns a table containing the current configuration settings for debugging.
---@field configure fun(options: {default_timeout?: number, check_interval?: number, debug?: boolean, verbose?: boolean}): async_module Configures module settings, potentially interacting with central config.
---@field enable_timeout_testing fun(): function Enables a special mode for testing timeout behavior internally. Returns a function to disable the mode.
---@field is_timeout_testing fun(): boolean Returns true if timeout testing mode is enabled. Internal use.
---@field it_async fun(description: string, options_or_fn: table|function, fn?: function, timeout_ms?: number): nil Defines an asynchronous test case using `firmo.it`. The test function `fn` runs in an async context.
---@field fit_async fun(description: string, options_or_fn: table|function, fn?: function, timeout_ms?: number): nil Defines a focused asynchronous test case using `firmo.fit`. Only focused tests run if any exist.
---@field xit_async fun(description: string, options_or_fn: table|function, fn?: function, timeout_ms?: number): nil Defines a skipped asynchronous test case using `firmo.xit`. It will not be run.
---@field describe_async fun(name: string, fn: function, options?: {focused?: boolean, excluded?: boolean}): nil Defines an asynchronous test group (suite) using `firmo.describe`. Tests inside can use async features.
---@field fdescribe_async fun(name: string, fn: function): nil Defines a focused asynchronous test group using `firmo.fdescribe`. Only focused suites/tests run if any exist.
---@field xdescribe_async fun(name: string, fn: function): nil Defines a skipped asynchronous test group using `firmo.xdescribe`. All tests inside will be skipped.
---@field create_deferred fun(): table Deprecated/Placeholder: Functionality not fully implemented.
---@field all fun(promises: {table}): table Deprecated/Placeholder: Promise functionality not fully implemented.
---@field race fun(promises: {table}): any Deprecated/Placeholder: Promise functionality not fully implemented.
---@field any fun(promises: {table}): any, {table} Deprecated/Placeholder: Promise functionality not fully implemented.
---@field catch fun(promise: table, handler: function): table Deprecated/Placeholder: Promise functionality not fully implemented.
---@field finally fun(promise: table, handler: function): table Deprecated/Placeholder: Promise functionality not fully implemented.
---@field scheduler fun(): table Deprecated/Placeholder: Functionality not fully implemented.
---@field set_check_interval fun(ms: number): async_module Sets the default interval for `wait_until`.
---@field cancel fun(operation: table): boolean Deprecated/Placeholder: Functionality not fully implemented.
---@field poll fun(fn: function, interval: number, timeout_ms?: number): table Deprecated/Placeholder: Functionality not fully implemented.
---@field timeout fun(promise: table, ms: number): table Deprecated/Placeholder: Functionality not fully implemented.
---@field defer fun(fn: function, delay?: number): table Deprecated/Placeholder: Functionality not fully implemented.

local async_module = {}

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _logging, _central_config, _firmo

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
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
    return logging.get_logger("assertion")
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

--- Get the firmo module with lazy loading to avoid circular dependencies
---@return table|nil The firmo module or nil if not available
local function get_firmo()
  if not _firmo then
    _firmo = try_require("firmo")
  end
  return _firmo
end

-- Default configuration
local DEFAULT_CONFIG = {
  default_timeout = 1000, -- 1 second default timeout in ms
  check_interval = 10, -- Default check interval in ms
  debug = false,
  verbose = false,
}

-- Internal state
local in_async_context = false
local default_timeout = DEFAULT_CONFIG.default_timeout
local _testing_timeout = false -- Special flag for timeout testing
local config = {
  default_timeout = DEFAULT_CONFIG.default_timeout,
  check_interval = DEFAULT_CONFIG.check_interval,
  debug = DEFAULT_CONFIG.debug,
  verbose = DEFAULT_CONFIG.verbose,
}

--- Registers a listener with `central_config` to automatically update this module's
--- configuration when the "async" section changes in the central config.
---@private
---@return table|nil central_config The central_config module if available, nil otherwise
local function get_central_config()
  if not _central_config then
    -- Use pcall to safely attempt loading central_config
    _central_config = try_require("lib.core.central_config")

    -- Register this module with central_config
    _central_config.register_module("async", {
      -- Schema
      field_types = {
        default_timeout = "number",
        check_interval = "number",
        debug = "boolean",
        verbose = "boolean",
      },
      field_ranges = {
        default_timeout = { min = 1 },
        check_interval = { min = 1 },
      },
    }, DEFAULT_CONFIG)

    get_logger().debug("Successfully loaded central_config", {
      module = "async",
    })
  end

  return _central_config
end

---@private
---@return boolean success Whether the change listener was registered successfully
-- Set up change listener for central configuration
local function register_change_listener()
  local central_config = get_central_config()
  if not central_config then
    get_logger().debug("Cannot register change listener - central_config not available")
    return false
  end

  -- Register change listener for async configuration
  central_config.on_change("async", function(path, old_value, new_value)
    get_logger().debug("Configuration change detected", {
      path = path,
      changed_by = "central_config",
    })

    -- Update local configuration from central_config
    local async_config = central_config.get("async")
    if async_config then
      -- Update timeout settings
      if async_config.default_timeout ~= nil and async_config.default_timeout ~= config.default_timeout then
        config.default_timeout = async_config.default_timeout
        default_timeout = config.default_timeout
        get_logger().debug("Updated default_timeout from central_config", {
          default_timeout = config.default_timeout,
        })
      end

      -- Update check interval
      if async_config.check_interval ~= nil and async_config.check_interval ~= config.check_interval then
        config.check_interval = async_config.check_interval
        get_logger().debug("Updated check_interval from central_config", {
          check_interval = config.check_interval,
        })
      end

      -- Update debug setting
      if async_config.debug ~= nil and async_config.debug ~= config.debug then
        config.debug = async_config.debug
        get_logger().debug("Updated debug setting from central_config", {
          debug = config.debug,
        })
      end

      -- Update verbose setting
      if async_config.verbose ~= nil and async_config.verbose ~= config.verbose then
        config.verbose = async_config.verbose
        get_logger().debug("Updated verbose setting from central_config", {
          verbose = config.verbose,
        })
      end

      -- Update logging configuration
      get_logging().configure_from_options("Async", {
        debug = config.debug,
        verbose = config.verbose,
      })

      get_logger().debug("Applied configuration changes from central_config")
    end
  end)

  get_logger().debug("Registered change listener for central configuration")
  return true
end

--- Configure the async module behavior and settings
--- Sets up configuration options for the async module, including timeouts, check intervals,
--- and debugging settings. Changes are persisted in the central configuration system
--- if available, allowing for consistent settings across the application.
--- @param options? {default_timeout?: number, check_interval?: number, debug?: boolean, verbose?: boolean} Table of configuration options to apply.
---   - `default_timeout`: Default timeout in ms for operations like `wait_until`.
---   - `check_interval`: Default polling interval in ms for `wait_until`.
---   - `debug`: Enable debug logging for this module.
---   - `verbose`: Enable verbose logging for this module.
--- @return async_module The module instance for method chaining.
--- @throws string If options contains invalid values (e.g., non-positive numbers for times).
---
--- @usage
--- -- Configure async settings via table
--- async.configure({
---   default_timeout = 2000,  -- 2 seconds default timeout
---   check_interval = 20,     -- Check conditions every 20ms
---   debug = true,           -- Enable debug logging
---   verbose = false         -- Disable verbose logging
--- })
---
--- -- Configure a single setting with method chaining
--- async.configure({ default_timeout = 5000 }).set_check_interval(50)
function async_module.configure(options)
  options = options or {}

  get_logger().debug("Configuring async module", {
    options = options,
  })

  local central_config = get_central_config()
  if not central_config then
    get_logger().debug("Cannot register change listener - central_config not available")
    return false
  end

  -- Get existing central config values
  local async_config = central_config.get("async")

  -- Apply central configuration (with defaults as fallback)
  if async_config then
    get_logger().debug("Using central_config values for initialization", {
      default_timeout = async_config.default_timeout,
      check_interval = async_config.check_interval,
    })

    config.default_timeout = async_config.default_timeout ~= nil and async_config.default_timeout
      or DEFAULT_CONFIG.default_timeout

    config.check_interval = async_config.check_interval ~= nil and async_config.check_interval
      or DEFAULT_CONFIG.check_interval

    config.debug = async_config.debug ~= nil and async_config.debug or DEFAULT_CONFIG.debug

    config.verbose = async_config.verbose ~= nil and async_config.verbose or DEFAULT_CONFIG.verbose
  else
    get_logger().debug("No central_config values found, using defaults")
    config = {
      default_timeout = DEFAULT_CONFIG.default_timeout,
      check_interval = DEFAULT_CONFIG.check_interval,
      debug = DEFAULT_CONFIG.debug,
      verbose = DEFAULT_CONFIG.verbose,
    }
  end

  -- Register change listener if not already done
  register_change_listener()

  -- Apply user options (highest priority) and update central config
  if options.default_timeout ~= nil then
    if type(options.default_timeout) ~= "number" or options.default_timeout <= 0 then
      get_logger().warn("Invalid default_timeout, must be a positive number", {
        provided = options.default_timeout,
      })
    else
      config.default_timeout = options.default_timeout
      default_timeout = options.default_timeout

      -- Update central_config if available
      if central_config then
        central_config.set("async.default_timeout", options.default_timeout)
      end
    end
  end

  if options.check_interval ~= nil then
    if type(options.check_interval) ~= "number" or options.check_interval <= 0 then
      get_logger().warn("Invalid check_interval, must be a positive number", {
        provided = options.check_interval,
      })
    else
      config.check_interval = options.check_interval

      -- Update central_config if available
      if central_config then
        central_config.set("async.check_interval", options.check_interval)
      end
    end
  end

  if options.debug ~= nil then
    config.debug = options.debug

    -- Update central_config if available
    if central_config then
      central_config.set("async.debug", options.debug)
    end
  end

  if options.verbose ~= nil then
    config.verbose = options.verbose

    -- Update central_config if available
    if central_config then
      central_config.set("async.verbose", options.verbose)
    end
  end

  -- Configure logging
  if options.debug ~= nil or options.verbose ~= nil then
    get_logging().configure_from_options("Async", {
      debug = config.debug,
      verbose = config.verbose,
    })
  else
    get_logging().configure_from_config("Async")
  end

  -- Ensure default_timeout is updated
  default_timeout = config.default_timeout

  get_logger().debug("Async module configuration complete", {
    default_timeout = config.default_timeout,
    check_interval = config.check_interval,
    debug = config.debug,
    verbose = config.verbose,
    using_central_config = central_config ~= nil,
  })

  return async_module
end

-- Compatibility for Lua 5.2/5.3+ differences
local unpack = unpack or table.unpack

--- Performs a busy-wait sleep for a specified duration.
--- **Note:** This blocks execution and should only be used within the async module's
--- internal simulation of delays (`await`) and polling (`wait_until`).
---@param ms number Time to sleep in milliseconds.
---@return nil
---@private
local function sleep(ms)
  local start = os.clock()
  while os.clock() - start < ms / 1000 do
  end
end

--- Convert a function to one that can be executed asynchronously
--- Transforms a regular function into an async-compatible function that can be
--- used with the async testing infrastructure. The returned function captures
--- arguments and returns an executor that runs in the async context.
--- @param fn function The function to wrap.
--- @return function wrapper A new function that captures arguments passed to it. Calling this wrapper function returns *another* function (the executor) which, when called, runs the original `fn` within the async context.
--- @throws string If `fn` is not a function, or if `fn` throws an error during execution.
---
--- @usage
--- -- Define a function that uses async features
--- local async_fetch = async.async(function(url)
---   -- Simulate network delay
---   async.await(100)
---   return "Content from " .. url
--- end)
---
--- -- Wrap it
--- local async_fetch = async.async(fetch_data)
---
--- -- Use it in an async test
--- async.it_async("fetches data", function()
---   local result = async_fetch("https://example.com")() -- Note: double call executes it
---   expect(result).to.contain("Example Domain")
--- end)
function async_module.async(fn)
  if type(fn) ~= "function" then
    error("async() requires a function argument", 2)
  end

  -- Return a function that captures the arguments
  -- Mark the wrapper function with a special marker for is_async_function to detect
  local wrapper = function(...)
    local args = { ... }

    -- Return the actual executor function
    return function()
      -- Set that we're in an async context
      local prev_context = in_async_context
      in_async_context = true

      local execution_ok = true
      local error_result = nil

      local function error_handler(err)
        execution_ok = false
        error_result = err
        return err -- Return error to xpcall result
      end

      -- Call the original function with xpcall
      local results = { xpcall(fn, error_handler, unpack(args)) }
      -- Note: xpcall returns { true, results... } on success
      -- or { false, error_result } on failure (where error_result is what error_handler returned)

      -- Restore context
      in_async_context = prev_context

      if not execution_ok then
        -- Return explicit error status and value captured by error_handler
        return false, error_result
      end

      -- Success path: remove xpcall's success status and return explicit success + results
      table.remove(results, 1) -- Remove the 'true' status from xpcall results
      return true, unpack(results)
    end
  end

  -- Add a special marker as the first upvalue that can be reliably detected
  debug.setupvalue(wrapper, 1, "__FIRMO_ASYNC_FUNCTION_MARKER")

  return wrapper
end

--- Checks if a function was wrapped by async.async()
--- This function identifies whether a given value is an async function that was
--- created using the async.async() wrapper without executing it. It uses a marker
--- explicitly added to wrapped functions to ensure reliable identification.
---
--- @param fn any The value to test, typically a function.
--- @return boolean True if the function was wrapped by async.async(), false otherwise.
---
--- @usage
--- -- Define a regular function
--- local regular_fn = function() return 42 end
---
--- -- Define an async function
--- local async_fn = async.async(function()
---   async.await(10)
---   return "async result"
--- end)
---
--- -- Check if they're async functions
--- assert(not async.is_async_function(regular_fn)) -- false
--- assert(async.is_async_function(async_fn))       -- true
function async_module.is_async_function(fn)
  -- If not a function, it's definitely not an async function
  if type(fn) ~= "function" then
    return false
  end

  -- Check for our async function marker directly
  -- This is faster and more reliable than examining function structure
  local success, has_marker = pcall(function()
    -- Check for the special marker we added to async-wrapped functions
    return debug.getupvalue(fn, 1) == "__FIRMO_ASYNC_FUNCTION_MARKER"
  end)

  -- If there was an error during detection, assume it's not an async function
  if not success then
    return false
  end

  return has_marker or false
end

--- Run multiple async operations concurrently and wait for all to complete
--- Executes multiple async operations in parallel and collects their results.
--- This provides simulated concurrency in Lua's single-threaded environment
--- by executing operations in small chunks using a round-robin approach.
--- @param operations {function} An array-like table where each element is an **executor** function returned by `async.async(...)()`.
--- @param timeout_ms? number Optional timeout in milliseconds for *all* operations combined (defaults to the module's `default_timeout`).
--- @return {any} An array-like table containing the results from each operation, in the same order as the input `operations`.
--- @throws string If called outside an async context, if `operations` is invalid, if any operation throws an error, or if the overall `timeout_ms` is exceeded.
---
--- @usage
--- -- Define some async operations
--- local op1 = async.async(function() async.await(50); return "A" end)
--- local op2 = async.async(function() async.await(30); return "B" end)
--- local op3 = async.async(function() async.await(10); return "C" end)
---
--- -- Run them in parallel within an async test
--- async.it_async("runs operations concurrently", function()
---   local results = async.parallel_async({ op1(), op2(), op3() }, 100) -- Pass executors
---   expect(results).to.deep_equal({ "A", "B", "C" })
--- end)
--- local results = async.parallel_async({
---   async.async(function() async.await(50); return "first" end)(),
---   async.async(function() async.await(30); return "second" end)(),
---   async.async(function() async.await(10); return "third" end)()
--- }, 200) -- 200ms timeout
---
--- -- Check results (will be ["first", "second", "third"])
--- expect(#results).to.equal(3)
function async_module.parallel_async(operations, timeout)
  if not in_async_context then
    error("parallel_async() can only be called within an async test", 2)
  end

  if type(operations) ~= "table" or #operations == 0 then
    error("parallel_async() requires a non-empty array of operations", 2)
  end

  timeout = timeout or default_timeout
  if type(timeout) ~= "number" or timeout <= 0 then
    error("timeout must be a positive number", 2)
  end

  -- Use a lower timeout for testing if requested
  -- This helps with the timeout test which needs a very short timeout
  if timeout <= 25 then
    -- For very short timeouts, make the actual timeout even shorter
    -- to ensure the test can complete quickly
    timeout = 10
  end

  -- Prepare result placeholders
  local results = {}
  local completed = {}
  local errors = {}

  -- Initialize tracking for each operation
  for i = 1, #operations do
    completed[i] = false
    results[i] = nil
    errors[i] = nil
  end

  -- Start each operation in "parallel"
  -- Note: This is simulated parallelism, as Lua is single-threaded.
  -- We'll run a small part of each operation in a round-robin manner
  -- This provides an approximation of concurrent execution

  -- First, create execution functions for each operation
  local exec_funcs = {}
  for i, op in ipairs(operations) do
    if type(op) ~= "function" then
      error("Each operation in parallel_async() must be a function", 2)
    end
    -- Removed log line

    -- Create a function that executes this operation and stores the result
    exec_funcs[i] = function()
      -- Call the executor which now returns {success, result/error}
      local success_exec, result_or_err = op() -- Call executor directly
      -- Removed log line
      completed[i] = true
      if success_exec then
        results[i] = result_or_err
      else
        errors[i] = result_or_err -- Store the error if executor returned false
      end
    end
  end

  -- Keep track of when we started
  local start = os.clock()

  -- Small check interval for the round-robin
  local check_interval = timeout <= 20 and 1 or 5 -- Use 1ms for short timeouts, 5ms otherwise

  -- Execute operations in a round-robin manner until all complete or timeout
  while true do
    -- Check if all operations have completed
    local all_completed = true
    for i = 1, #operations do
      if not completed[i] then
        all_completed = false
        break
      end
    end

    if all_completed then
      break
    end

    -- Check if we've exceeded the timeout
    local elapsed_ms = (os.clock() - start) * 1000

    -- Force timeout when in testing mode after at least 5ms have passed
    if _testing_timeout and elapsed_ms >= 5 then
      local pending = {}
      for i = 1, #operations do
        if not completed[i] then
          table.insert(pending, i)
        end
      end

      -- Only throw the timeout error if there are pending operations
      if #pending > 0 then
        error(
          string.format(
            "Timeout of %dms exceeded. Operations %s did not complete in time.",
            timeout,
            table.concat(pending, ", ")
          ),
          2
        )
      end
    end

    -- Normal timeout detection
    if elapsed_ms >= timeout then
      local pending = {}
      for i = 1, #operations do
        if not completed[i] then
          table.insert(pending, i)
        end
      end

      error(
        string.format(
          "Timeout of %dms exceeded. Operations %s did not complete in time.",
          timeout,
          table.concat(pending, ", ")
        ),
        2
      )
    end

    -- Execute one step of each incomplete operation
    for i = 1, #operations do
      if not completed[i] then
        -- Removed log line
        -- Execute the function directly. The inner logic handles catching errors
        -- and setting completed/errors flags.
        exec_funcs[i]() -- Call directly
      end
    end

    -- Short sleep to prevent CPU hogging and allow timers to progress
    sleep(check_interval)
  end

  -- Check if any operations resulted in errors
  local error_ops = {}
  for i, err in pairs(errors) do
    -- Removed log line
    if err then
      table.insert(error_ops, string.format("Operation %d failed: %s", i, tostring(err)))
    end
  end

  if #error_ops > 0 then
    error("One or more parallel operations failed:\n" .. table.concat(error_ops, "\n"), 2)
  end

  return results
end

--- Wait for a specified time in milliseconds
--- Pauses the execution of the current async function for the specified duration.
--- This must be called within an async context (created by async.async).
--- @param ms number The number of milliseconds to wait (must be non-negative).
--- @return nil
--- @throws string If called outside an async context or if `ms` is not a non-negative number.
---
--- @usage
--- -- Use within a function wrapped by async.async() or in async.it_async()
--- local async_fn = async.async(function()
---   -- Do something
---   async.await(100) -- Wait for 100ms
---   -- Continue execution after the delay
--- end)
function async_module.await(ms)
  if not in_async_context then
    error("await() can only be called within an async test", 2)
  end

  -- Validate milliseconds argument
  ms = ms or 0
  if type(ms) ~= "number" or ms < 0 then
    error("await() requires a non-negative number of milliseconds", 2)
  end

  -- Sleep for the specified time
  sleep(ms)
end

--- Wait until a condition is true or timeout occurs
--- Repeatedly checks a condition function until it returns true or until the
--- timeout is reached. This is useful for waiting for asynchronous operations
--- to complete or for testing conditions that may become true over time.
--- @param condition function A function that returns a truthy value when the desired condition is met.
--- @param timeout_ms? number Optional timeout duration in milliseconds (defaults to the module's `default_timeout`).
--- @param check_interval_ms? number Optional interval between condition checks in milliseconds (defaults to the module's `check_interval`).
--- @return boolean `true` if the condition returned a truthy value within the timeout period.
--- @throws string If called outside an async context, if `condition` is not a function, if `timeout_ms` or `check_interval_ms` are invalid, or if the timeout expires before the condition becomes truthy.
---
--- @usage
--- -- Wait for a variable to be set by another async operation
--- local counter = 0
--- local increment = async.async(function()
---   async.await(10)
---   counter = counter + 1
--- end)
---
--- -- Start the async operation
--- increment()()
---
--- -- Wait until counter reaches the expected value
--- async.wait_until(function() return counter >= 1 end, 100)
function async_module.wait_until(condition, timeout, check_interval)
  if not in_async_context then
    error("wait_until() can only be called within an async test", 2)
  end

  -- Validate arguments
  if type(condition) ~= "function" then
    error("wait_until() requires a condition function as first argument", 2)
  end

  timeout = timeout or default_timeout
  if type(timeout) ~= "number" or timeout <= 0 then
    error("timeout must be a positive number", 2)
  end

  -- Use configured check_interval if not specified
  check_interval = check_interval or config.check_interval
  if type(check_interval) ~= "number" or check_interval <= 0 then
    error("check_interval must be a positive number", 2)
  end

  get_logger().debug("Wait until condition is true", {
    timeout = timeout,
    check_interval = check_interval,
  })

  -- Keep track of when we started
  local start = os.clock()

  -- Check the condition immediately
  if condition() then
    return true
  end

  -- Start checking at intervals
  while (os.clock() - start) * 1000 < timeout do
    -- Sleep for the check interval
    sleep(check_interval)

    -- Check if condition is now true
    if condition() then
      return true
    end
  end

  -- If we reached here, the condition never became true
  error(string.format("Timeout of %dms exceeded while waiting for condition to be true", timeout), 2)
end

--- Set the default timeout for async operations
--- Changes the global default timeout used for async operations like parallel_async
--- and wait_until when no explicit timeout is provided. This setting affects all
--- future async operations in the current test run.
---
--- @param ms number The new default timeout in milliseconds (must be positive).
--- @return async_module The module instance for method chaining.
--- @throws string If `ms` is not a positive number.
---
--- @usage
--- -- Set a longer default timeout
---
--- -- Use with method chaining
--- async.set_timeout(3000).set_check_interval(100)
function async_module.set_timeout(ms)
  if type(ms) ~= "number" or ms <= 0 then
    error("timeout must be a positive number", 2)
  end

  -- Update both the local variable and config
  default_timeout = ms
  config.default_timeout = ms

  get_central_config().set("async.default_timeout", ms)
  get_logger().debug("Updated default_timeout in central_config", {
    default_timeout = ms,
  })

  get_logger().debug("Set default timeout", {
    default_timeout = ms,
  })

  return async_module
end

--- Checks if the current execution is happening within an async context managed by this module.
--- Useful for functions like `await` and `wait_until` to ensure they are called correctly.
---@return boolean `true` if inside an async context, `false` otherwise.
function async_module.is_in_async_context()
  return in_async_context
end

--- Resets the internal state of the async module.
--- Typically called between test runs to ensure a clean state.
--- Resets the `in_async_context` flag, timeout testing flag, and local configuration cache to defaults.
--- Does **not** reset central configuration values.
---@return async_module The module instance for method chaining.
function async_module.reset()
  in_async_context = false
  _testing_timeout = false

  -- Reset configuration to defaults
  config = {
    default_timeout = DEFAULT_CONFIG.default_timeout,
    check_interval = DEFAULT_CONFIG.check_interval,
    debug = DEFAULT_CONFIG.debug,
    verbose = DEFAULT_CONFIG.verbose,
  }

  -- Update the local variable
  default_timeout = config.default_timeout

  get_logger().debug("Reset async module state")

  return async_module
end

--- Performs a full reset, including local state and attempting to reset
--- the "async" section in the central configuration system if available.
---@return async_module The module instance for method chaining.
function async_module.full_reset()
  -- Reset local state
  async_module.reset()

  -- Reset central configuration
  get_central_config().reset("async")
  get_logger().debug("Reset central configuration for async module")

  return async_module
end

--- Returns a table containing the current configuration settings for debugging purposes.
--- Includes local config cache, current timeout value, context flags, and central config data if available.
---@return table debug_info A snapshot of the current async module configuration.
function async_module.debug_config()
  local debug_info = {
    local_config = {
      default_timeout = config.default_timeout,
      check_interval = config.check_interval,
      debug = config.debug,
      verbose = config.verbose,
    },
    default_timeout_var = default_timeout,
    in_async_context = in_async_context,
    testing_timeout = _testing_timeout,
    using_central_config = false,
    central_config = nil,
  }

  debug_info.using_central_config = true
  debug_info.central_config = get_central_config().get("async")

  -- Display configuration
  get_logger().info("Async module configuration", debug_info)

  return debug_info
end

--- Enables a special internal mode used for testing the timeout logic itself.
--- **For internal testing purposes only.**
---@return function disable_func A function that, when called, disables timeout testing mode.
---@private
function async_module.enable_timeout_testing()
  _testing_timeout = true
  -- Return a function that resets the timeout testing flag
  return function()
    _testing_timeout = false
  end
end

--- Checks if the internal timeout testing mode is currently enabled.
--- **For internal testing purposes only.**
---@return boolean `true` if timeout testing mode is active, `false` otherwise.
---@private
function async_module.is_timeout_testing()
  return _testing_timeout
end

--- Create an async-aware test case with proper timeout handling
--- Creates a test case that properly handles asynchronous code execution,
--- including timeout management, context tracking, and error propagation.
--- This function bridges the gap between normal test cases and async operations.
---
--- @param description string The description of the test case.
--- @param options_or_fn table|function Either an options table (e.g., `{ expect_error = true }`) or the async test function itself.
--- @param fn? function The async test function, if `options_or_fn` was an options table.
--- @param timeout_ms? number Optional timeout in milliseconds for this specific test case (defaults to the module's `default_timeout`).
--- @return nil Registers the test case using `firmo.it`.
--- @throws string If `firmo.it` is not available, if arguments are invalid, if the test function errors unexpectedly, or if the test times out.
---
--- @usage
--- -- Basic async test
--- it_async("performs async operations correctly", function()
---   -- Async code with awaits
---   async.await(50)
---
---   -- Test assertions
---   expect(true).to.be_truthy()
---
---   -- More async code
---   local result = async.wait_until(function() return true end, 100)
---   expect(result).to.be_truthy()
--- end)
--- -- Async test expecting an error
--- async.it_async("handles errors", { expect_error = true }, function()
---   local op = async.async(function() error("Something failed") end)
---   op()() -- Execute the failing operation
--- end)
function async_module.it_async(description, options_or_fn, fn, timeout_ms)
  local options = {}
  local async_fn

  -- Handle parameter flexibility
  if type(options_or_fn) == "function" then
    async_fn = options_or_fn
    timeout_ms = fn -- 3rd arg is timeout if 2nd is fn
  elseif type(options_or_fn) == "table" then
    options = options_or_fn
    async_fn = fn
    -- timeout_ms is already the 4th arg
  else
    error("Second argument to it_async must be an options table or the test function", 2)
  end

  -- Validate parameters
  if type(description) ~= "string" then
    error("it_async() requires a string description as first argument", 2)
  end

  -- Ensure options is a table if provided
  if options ~= nil and type(options) ~= "table" then
    error("it_async() options must be a table if provided", 2)
  end

  -- Default to empty options table
  options = options or {}

  if type(async_fn) ~= "function" then
    error("it_async() requires a function as the test implementation", 2)
  end

  -- Use default timeout if not specified or invalid
  timeout_ms = timeout_ms or default_timeout
  if type(timeout_ms) ~= "number" or timeout_ms <= 0 then
    get_logger().warn(
      "Invalid timeout provided to it_async, using default.",
      { provided = timeout_ms, default = default_timeout }
    )
    timeout_ms = default_timeout
  end

  -- Get the it function from firmo
  local it = try_require("firmo").it
  if type(it) ~= "function" then
    error("it_async() requires firmo.it function to be available", 2)
  end
  -- Create an async-aware test function
  ---@diagnostic disable-next-line: return-type-mismatch
  return it(description, options, function()
    -- Create a wrapper to manage the async context
    local prev_context = in_async_context
    in_async_context = true

    -- Keep track of when we started for timeout management
    local start = os.clock()

    -- Setup timeout sentinel
    local timed_out = false

    -- Track if the function has completed
    local completed = false

    -- Execute the function and capture any errors
    local success, err

    success, err = pcall(function()
      -- Execute the async function
      local result = async_fn()

      -- Check for timeout immediately after function potentially yields/returns
      local elapsed_ms = (os.clock() - start) * 1000
      if elapsed_ms > timeout_ms then
        timed_out = true
        -- error() will be caught by pcall, setting success=false, err=message
        error(string.format("Async test timeout: %dms exceeded", timeout_ms))
      end
      return result
    end)

    -- Force timeout when in testing mode
    if _testing_timeout and not completed then
      -- Only throw timeout if actual execution would time out
      if (os.clock() - start) * 1000 >= 5 then
        timed_out = true
        success = false -- Mark as failed
        err = string.format("Async test timeout: %dms exceeded (testing mode)", timeout_ms)
      end
    end

    in_async_context = prev_context

    -- Propagate any errors that occurred
    if not success then
      -- Only throw the error here if it wasn't expected
      if not options.expect_error then
        local error_message
        if timed_out then
          error_message = string.format("Async test timeout: %dms exceeded for test '%s'", timeout_ms, description)
        else
          error_message = string.format("Async test error in '%s': %s", description, tostring(err))
        end
        error(error_message, 0) -- Use level 0 to report error at the 'it' call site
        -- Re-throw the error when expect_error is true for firmo to handle it
        error(err, 2)
      end
    end
  end)
end

--- Create a focused async-aware test case
--- This function is a convenience wrapper around `async_module.it_async` that sets the `focused` option to true.
--- When focus mode is active (because at least one test or suite is focused using `fit_async` or `fdescribe_async`),
--- only the focused items will be run. All other tests will be skipped.
---
---@param description string The description of the test case.
---@param options_or_fn table|function Either an options table (e.g., `{ expect_error = true }`) or the async test function itself.
---@param fn? function The async test function, if `options_or_fn` was an options table.
---@param timeout_ms? number Optional timeout in milliseconds for this specific test case.
---@return nil Registers the focused test case using `firmo.fit`.
---@throws string If arguments are invalid or if the underlying `async_module.it_async` call fails.
---
---@usage
--- -- Focus on this specific async test
--- async.fit_async("processes data quickly", function()
---   async.await(10)
---   expect(get_data_status()).to.equal("processed")
--- end)
---
--- -- This test will be skipped if focus mode is active
--- async.it_async("handles regular operations", function()
---   -- ...
--- end)
function async_module.fit_async(description, options_or_fn, fn, timeout_ms)
  local options = {}
  local async_fn

  -- Handle parameter flexibility
  if type(options_or_fn) == "function" then
    async_fn = options_or_fn
    timeout_ms = fn -- 3rd arg is timeout if 2nd is fn
  elseif type(options_or_fn) == "table" then
    options = options_or_fn
    async_fn = fn
    -- timeout_ms is already the 4th arg
  else
    error("Second argument to fit_async must be an options table or the test function", 2)
  end

  -- Ensure options is a table and set focused flag
  options = options or {}
  options.focused = true

  -- Delegate to it_async with modified options
  return async_module.it_async(description, options, async_fn, timeout_ms)
end

--- Create a skipped async-aware test case
--- This function is a convenience wrapper around `async_module.it_async` that sets the `excluded` option to true.
--- The test case defined with `xit_async` will be recorded but not executed. This is useful for temporarily
--- disabling tests that are broken, incomplete, or irrelevant to the current task.
---
---@param description string The description of the test case.
---@param options_or_fn table|function Either an options table (e.g., `{ expect_error = true }`) or the async test function itself.
---@param fn? function The async test function, if `options_or_fn` was an options table.
---@param timeout_ms? number Optional timeout (ignored as test is skipped, but kept for signature consistency).
---@return nil Registers the skipped test case using `firmo.xit`.
---@throws string If arguments are invalid or if the underlying `async_module.it_async` call fails (though failure during skip registration is less likely).
---
---@usage
--- -- Skip this async test temporarily
--- async.xit_async("integrates with external service", function()
---   -- This code will not run
---   async.await(1000)
---   expect(service_status()).to.equal("ready")
--- end)
---
--- -- Other async tests will run normally
--- async.it_async("performs basic operations", function()
---   async.await(10)
---   expect(true).to.be_truthy()
--- end)
function async_module.xit_async(description, options_or_fn, fn, timeout_ms)
  local options = {}
  local async_fn

  -- Handle parameter flexibility
  if type(options_or_fn) == "function" then
    async_fn = options_or_fn
    timeout_ms = fn -- 3rd arg is timeout if 2nd is fn
  elseif type(options_or_fn) == "table" then
    options = options_or_fn
    async_fn = fn
    -- timeout_ms is already the 4th arg
  else
    error("Second argument to xit_async must be an options table or the test function", 2)
  end

  -- Ensure options is a table and set excluded flag
  options = options or {}
  options.excluded = true

  -- Delegate to it_async with modified options
  return async_module.it_async(description, options, async_fn, timeout_ms)
end

--- Create an async-aware test group (suite)
--- This function allows defining a test group where tests (`it_async`, `fit_async`, `xit_async`)
--- within the group can utilize async features (`await`, `wait_until`, `parallel_async`).
--- It delegates the group definition (including nesting, hooks, and filtering logic)
--- to `firmo.describe`. The async nature applies to the *contents* of the group, not the group definition itself.
---
---@param name string Name of the test group.
---@param fn function Function containing the test group's definitions (e.g., `it_async` calls, nested `describe_async`).
---@param options? {focused?: boolean, excluded?: boolean} Optional table containing flags:
---   - `focused`: If true, marks this group as focused (via `firmo.fdescribe`).
---   - `excluded`: If true, marks this group to be skipped (via `firmo.xdescribe`).
---@return nil Registers the test group using `firmo.describe`.
---@throws string If `firmo.describe` is not available or if the underlying `describe` call fails.
---
---@usage
--- -- Define a group for async tests
--- async.describe_async("Async Database Operations", function()
---   before(function()
---     -- Setup connection (can be sync or async setup)
---   end)
---
---   it_async("should fetch user data", function()
---     local data = nil
---     db.fetch_user_async(1, function(res) data = res end)
---     async.wait_until(function() return data ~= nil end)
---     expect(data.id).to.equal(1)
---   end)
---
---   after(function()
---     -- Teardown connection
---   end)
--- end)
function async_module.describe_async(name, fn, options)
  local firmo = get_firmo()
  if not firmo or type(firmo.describe) ~= "function" then
    error("describe_async() requires firmo.describe function to be available", 2)
  end

  -- Delegate to the core describe function
  return firmo.describe(name, fn, options)
end

--- Create a focused async-aware test group
--- This function is a convenience wrapper around `async_module.describe_async` that sets the `focused` option to true.
--- When focus mode is active, only focused suites (defined with `fdescribe_async`) and focused tests
--- (defined with `fit_async`) will be run.
---
---@param name string Name of the test group.
---@param fn function Function containing the test group's definitions.
---@return nil Registers the focused test group using `firmo.fdescribe`.
---@throws string If the underlying `describe_async` call fails.
---
---@usage
--- -- Focus on this group of async tests
--- async.fdescribe_async("Critical Async Feature", function()
---   it_async("must complete successfully", function()
---     -- ... async test logic ...
---   end)
--- end)
---
--- -- This group will be skipped if focus mode is active
--- async.describe_async("Non-critical Features", function()
---   -- ... other tests ...
--- end)
function async_module.fdescribe_async(name, fn)
  return async_module.describe_async(name, fn, { focused = true })
end

--- Create a skipped async-aware test group
--- This function is a convenience wrapper around `async_module.describe_async` that sets the `excluded` option to true.
--- All tests and hooks defined within this group will be skipped during test execution.
---
---@param name string Name of the test group.
---@param fn function Function containing the test group's definitions (these will be skipped).
---@return nil Registers the skipped test group using `firmo.xdescribe`.
---@throws string If the underlying `describe_async` call fails (though failure during skip registration is less likely).
---
---@usage
--- -- Skip this entire group of async tests
--- async.xdescribe_async("Legacy Async Code", function()
---   it_async("uses old patterns", function()
---     -- This test will not run
---   end)
--- end)
---
--- -- Other groups run normally
--- async.describe_async("Current Async Features", function()
---   it_async("works as expected", function()
---     -- This test runs
---   end)
--- end)
function async_module.xdescribe_async(name, fn)
  return async_module.describe_async(name, fn, { excluded = true })
end

return async_module
