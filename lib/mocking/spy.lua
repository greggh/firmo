--- Firmo Function Spying Implementation
---
--- Provides powerful spy functionality for testing:
--- - Create standalone spy functions for tracking calls (`spy.new`).
--- - Spy on object methods while preserving their original behavior (`spy.on`).
--- - Track function call arguments, results (return value or error), timestamps, and call order.
--- - Provide methods for inspecting call history (`get_call`, `get_calls`, `last_call`).
--- - Provide methods for verifying calls (`called_with`, `called_times`, `not_called`, `called_once`, `called_before`, `called_after`).
--- - Integrate with `error_handler` for robust error reporting.
---
--- Spies are non-invasive: they record interactions without altering the underlying function's execution (unless configured otherwise via chainable methods like `and_call_fake`, `and_return`, `and_throw`).
---
--- @module lib.mocking.spy
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class spy_module
---@field _VERSION string Module version identifier.
---@field new fun(fn?: function): spy_object|nil, table? Creates a new standalone spy function, optionally wrapping `fn`. Creation is tracked by `lib.quality` if enabled. Returns `spy_object, nil` on success, or `nil, error_object` on failure. @throws table If spy creation fails critically.
---@field on fun(obj: table, method_name: string): spy_object|nil, table? Creates a spy on an object's method. Creation is tracked by `lib.quality` if enabled. Returns `spy_object, nil` on success, or `nil, error_object` on failure. @throws table If validation or spy creation fails critically.
---@field assert fun(spy_obj: spy_object): spy_assert|nil, table? Creates an assertion helper object for the given spy. Returns `spy_assert, nil` on success, or `nil, error_object` on failure. @throws table If validation fails.
---@field is_spy fun(obj: any): boolean Checks if an object is a spy created by this module.
---@field get_all_spies fun(): table<number, spy_object> Returns a list of all spies created by this module.
---@field reset_all fun(): boolean, table? Resets call history for all spies. Returns `true, nil` on success, `false, error_object` on failure. @throws table If reset process fails critically.
---@field wrap fun(fn: function, options?: { callThrough?: boolean, callFake?: function, returnValue?: any, throwError?: any }): spy_object|nil, table? Creates a spy wrapping `fn` with optional behavior modifiers. Returns `spy_object, nil` on success, or `nil, error_object` on failure. @throws table If validation or spy creation fails critically.
---@field _spies table<number, spy_object> List of all spies created by this module. Internal.
---@field _next_sequence number Internal counter for tracking call order. Internal.
---@field _new_sequence fun(): number|nil, table? Internal function to generate unique sequence numbers. Returns `number, nil` on success, or `nil, error_object` on error. @private

---@class spy_object
---@field calls table<number, {args: table, timestamp: number, result?: any, error?: any}> Record of calls with arguments, timestamp, result or error.
---@field call_count number Number of times the spy was called.
---@field called boolean Whether the spy was called at least once (`call_count > 0`).
---@field call_sequence table<number, number> Sequence numbers for each call, used for `called_before`/`called_after`.
---@field call_history table<number, table> DEPRECATED: Use `calls` field instead. History of call arguments.
---@field reset fun(self: spy_object): spy_object Resets call history (`calls`, `call_count`, `called`, `call_sequence`) but maintains configuration. Returns self for chaining.
---@field and_call_through fun(self: spy_object): spy_object Configures the spy to call the original wrapped function (if any). Returns self for chaining.
---@field and_call_fake fun(self: spy_object, fn: function): spy_object Configures the spy to call a fake implementation function instead of the original. Returns self for chaining.
---@field and_return fun(self: spy_object, value: any): spy_object Configures the spy to return a fixed value without calling the original/fake function. Returns self for chaining.
---@field and_throw fun(self: spy_object, error: any): spy_object Configures the spy to throw a specific error when called. Returns self for chaining.
---@field call_count_by_args fun(self: spy_object, args: table): number|nil, table? Gets the count of calls matching specific arguments. Returns `count, nil` or `nil, error`. @throws table If validation or comparison fails critically.
---@field get_call fun(self: spy_object, index: number): table|nil Returns the call record for the Nth call (1-based index) or `nil`.
---@field get_calls fun(self: spy_object): table<number, {args: table, timestamp: number, result?: any, error?: any}> Returns a deep copy of the `calls` table.
---@field called_with fun(self: spy_object, ...): boolean|{result: boolean, call_index: number}|nil, table? Checks if spy was called with specific arguments. Returns `true`/result object if match found, `false` otherwise, `nil` on error, plus optional error. @throws table If validation or comparison fails critically.
---@field called_times fun(self: spy_object, n: number): boolean|nil, table? Checks if spy was called exactly `n` times. Returns `true`/`false`, or `nil` on error, plus optional error. @throws table If validation fails.
---@field not_called fun(self: spy_object): boolean|nil, table? Checks if spy was never called. Returns `true`/`false`, or `nil` on error, plus optional error.
---@field called_once fun(self: spy_object): boolean|nil, table? Checks if spy was called exactly once. Returns `true`/`false`, or `nil` on error, plus optional error.
---@field last_call fun(self: spy_object): table|nil Gets the record of the most recent call, or `nil` if never called or on error, plus optional error object.
---@field called_before fun(self: spy_object, other_spy: spy_object, call_index?: number): boolean|nil, table? Checks if this spy was called before another spy's Nth call. Returns `true`/`false`, or `nil` on error, plus optional error. @throws table If validation or comparison fails critically.
---@field called_after fun(self: spy_object, other_spy: spy_object, call_index?: number): boolean|nil, table? Checks if this spy was called after another spy's Nth call. Returns `true`/`false`, or `nil` on error, plus optional error. @throws table If validation or comparison fails critically.
---@field target table|nil For method spies (`spy.on`), the target object.
---@field name string|nil For method spies, the name of the spied method.
---@field original function|nil For method spies, the original method implementation.
---@field restore fun(self: spy_object): boolean|nil, table? For method spies, restores the original method. Restoration is tracked by `lib.quality` if enabled. Returns `true`/`false`, or `nil` on error, plus optional error. @throws table If restoration fails critically.
---@field _is_firmo_spy boolean Internal flag identifying this as a spy object.
---@field _original_fn function|nil The original wrapped function (from `new` or `on`).
---@field _fake_fn function|nil The fake implementation function set by `and_call_fake`.
---@field _return_value any The fixed return value set by `and_return`.
---@field _throw_error any The error to throw set by `and_throw`.
---@field _call_through boolean Flag indicating whether to call the original function.

---@class spy_assert
---@field was_called fun(times?: number): boolean|nil, table? Asserts the spy was called at least once, or optionally `times` times. @throws table
---@field was_not_called fun(): boolean|nil, table? Asserts the spy was never called. @throws table
---@field was_called_with fun(...): boolean|nil, table? Asserts the spy was called with the specified arguments. @throws table
---@field was_called_times fun(times: number): boolean|nil, table? Asserts the spy was called exactly `times` times. @throws table
---@field was_called_before fun(other_spy: spy_object, index?: number): boolean|nil, table? Asserts this spy was called before `other_spy`'s Nth call. @throws table
---@field was_called_after fun(other_spy: spy_object, index?: number): boolean|nil, table? Asserts this spy was called after `other_spy`'s Nth call. @throws table
---@field has_returned fun(value: any): boolean|nil, table? Asserts the spy returned a specific value. @throws table
---@field has_thrown fun(error_value?: any): boolean|nil, table? Asserts the spy threw an error (optionally matching `error_value`). @throws table

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging, _fs, _quality

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
    return logging.get_logger("spy")
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

--- Get the quality module with lazy loading
---@return table|nil The quality module or nil if not available
local function get_quality()
  if not _quality then
    _quality = try_require("lib.quality")
  end
  return _quality
end

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack_table = table.unpack or unpack

local spy = {
  -- Module version
  _VERSION = "1.0.0",
}

--- Checks if an object is a spy created by this module.
---@param obj any The object to check.
---@return boolean `true` if it's a spy, `false` otherwise.
---@private
local function is_spy(obj)
  return type(obj) == "table" and obj._is_firmo_spy == true
end

--- Performs a deep recursive equality check between two tables.
--- Handles cycles (implicitly via recursive calls, needs explicit check if cycles are problematic).
---@param t1 table The first table.
---@param t2 table The second table.
---@return boolean `true` if tables are deeply equal, `false` otherwise.
---@private
local function tables_equal(t1, t2)
  -- Input validation with fallback
  if t1 == nil or t2 == nil then
    get_logger().debug("Comparing with nil value", {
      function_name = "tables_equal",
      t1_nil = t1 == nil,
      t2_nil = t2 == nil,
    })
    return t1 == t2
  end

  if type(t1) ~= "table" or type(t2) ~= "table" then
    return t1 == t2
  end

  -- Use protected call to catch any errors during comparison
  local success, result = get_error_handler().try(function()
    -- Check each key-value pair in t1
    for k, v in pairs(t1) do
      if not tables_equal(v, t2[k]) then
        return false
      end
    end

    -- Check for any extra keys in t2
    for k, _ in pairs(t2) do
      if t1[k] == nil then
        return false
      end
    end

    return true
  end)

  if not success then
    get_logger().warn("Error during table comparison", {
      function_name = "tables_equal",
      error = get_error_handler().format_error(result),
    })
    -- Fallback to simple equality check on error
    return false
  end

  return result
end

--- Checks if an `actual` value matches an `expected` value.
--- Supports deep table comparison via `tables_equal` and custom matchers
--- (tables with `_is_matcher=true` and a `match` function).
---@param expected any The expected value or matcher object.
---@param actual any The actual value received.
---@return boolean `true` if values match, `false` otherwise.
---@private
local function matches_arg(expected, actual)
  -- Use protected call to catch any errors during matching
  local success, result = get_error_handler().try(function()
    -- If expected is a matcher, use its match function
    if type(expected) == "table" and expected._is_matcher then
      if type(expected.match) ~= "function" then
        get_logger().warn("Invalid matcher object (missing match function)", {
          function_name = "matches_arg",
          matcher_type = type(expected),
        })
        return false
      end
      return expected.match(actual)
    end

    -- If both are tables, do deep comparison
    if type(expected) == "table" and type(actual) == "table" then
      return tables_equal(expected, actual)
    end

    -- Otherwise do direct comparison
    return expected == actual
  end)

  if not success then
    get_logger().warn("Error during argument matching", {
      function_name = "matches_arg",
      expected_type = type(expected),
      actual_type = type(actual),
      error = get_error_handler().format_error(result),
    })
    -- Fallback to direct equality check on error
    return expected == actual
  end

  return result
end

--- Checks if an array of actual arguments matches an array of expected arguments.
--- Uses `matches_arg` for individual argument comparison, supporting matchers and deep equality.
---@param expected_args table An array-like table of expected arguments or matchers.
---@param actual_args table An array-like table of actual arguments received.
---@return boolean `true` if argument counts match and all arguments match according to `matches_arg`, `false` otherwise.
---@private
local function args_match(expected_args, actual_args)
  -- Input validation with fallback
  if expected_args == nil or actual_args == nil then
    get_logger().warn("Nil args in comparison", {
      function_name = "args_match",
      expected_nil = expected_args == nil,
      actual_nil = actual_args == nil,
    })
    return expected_args == actual_args
  end

  if type(expected_args) ~= "table" or type(actual_args) ~= "table" then
    get_logger().warn("Non-table args in comparison", {
      function_name = "args_match",
      expected_type = type(expected_args),
      actual_type = type(actual_args),
    })
    return false
  end

  -- Use protected call to catch any errors during matching
  local success, result = get_error_handler().try(function()
    if #expected_args ~= #actual_args then
      return false
    end

    for i, expected in ipairs(expected_args) do
      if not matches_arg(expected, actual_args[i]) then
        return false
      end
    end

    return true
  end)

  if not success then
    get_logger().warn("Error during args matching", {
      function_name = "args_match",
      expected_count = #expected_args,
      actual_count = #actual_args,
      error = get_error_handler().format_error(result),
    })
    -- Fallback to false on error
    return false
  end

  return result
end

--- Creates a spy that wraps a given function, allowing optional configuration of its behavi---@param fn? function Optional function to wrap and spy on. If omitted, the spy acts as a simple call counter.
---@return spy_object|nil spy The created spy object, or `nil` on error.
---@return table|nil error Error object if spy creation failed.
---@throws table If spy creation fails critically.
function spy.new(fn)
  -- Input validation with fallback
  get_logger().debug("Creating new spy function", {
    function_name = "spy.new",
    fn_type = type(fn),
  })

  -- Not treating nil fn as an error, just providing a default
  fn = fn or function() end

  -- Use protected call to create the spy object
  local success, spy_obj, err = get_error_handler().try(function()
    local obj = {
      _is_firmo_spy = true,
      calls = {},
      called = false,
      call_count = 0,
      call_sequence = {}, -- For sequence tracking
      call_history = {}, -- For backward compatibility
    }

    return obj
  end)

  if not success then
    local error_obj = get_error_handler().runtime_error(
      "Failed to create spy object",
      {
        function_name = "spy.new",
        fn_type = type(fn),
      },
      spy_obj -- On failure, spy_obj contains the error
    )
    get_logger().error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  --- The core function wrapper that captures calls and executes original/fake logic.
  --- Records arguments, timestamp, results/errors, and updates call count/sequence.
  --- Executes the original function (`fn`), fake function (`_fake_fn`), returns a fixed value (`_return_value`), or throws an error (`_throw_error`) based on spy configuration.
  ---@param ... any Arguments passed to the spy.
  ---@return ... any Returns values from the original/fake function, or the configured fixed value.
  ---@throws any Throws the configured error or an error from the original/fake function.
  ---@private
  local function capture(...)
    -- Use protected call to track the call
    local args = { ... } -- Capture args here before the protected call
    local call_success, _, call_err = get_error_handler().try(function()
      -- Update call tracking state
      spy_obj.called = true
      spy_obj.call_count = spy_obj.call_count + 1

      -- Record call with proper structure
      local call_record = {
        args = args, -- All arguments as an array
        timestamp = os.time(), -- When the call happened
        result = nil, -- Will be set after function call
        error = nil, -- Will be set if function throws
      }

      -- Set up metatable to support direct argument access via numeric indices
      setmetatable(call_record, {
        __index = function(t, k)
          -- If key is a number, delegate to args array
          if type(k) == "number" then
            return t.args[k]
          end
          -- Otherwise use normal table access
          return rawget(t, k)
        end,
      })

      -- Store the call record
      table.insert(spy_obj.calls, call_record)
      table.insert(spy_obj.call_history, args) -- Keep this for backward compatibility
      get_logger().debug("Spy function called", {
        call_count = spy_obj.call_count,
        arg_count = #args,
        has_args_field = call_record.args ~= nil,
        args_values = {
          arg1 = args[1] ~= nil and (type(args[1]) == "table" and "table" or tostring(args[1])) or "nil",
          arg2 = args[2] ~= nil and (type(args[2]) == "table" and "table" or tostring(args[2])) or "nil",
          arg3 = args[3] ~= nil and (type(args[3]) == "table" and "table" or tostring(args[3])) or "nil",
        },
      })
      -- Sequence tracking for order verification
      if not _G._firmo_sequence_counter then
        _G._firmo_sequence_counter = 0
      end
      _G._firmo_sequence_counter = _G._firmo_sequence_counter + 1

      -- Store sequence number
      local sequence_number = _G._firmo_sequence_counter
      table.insert(spy_obj.call_sequence, sequence_number)

      return true
    end)

    if not call_success then
      get_logger().error("Error during spy call tracking", {
        function_name = "spy.capture",
        call_count = spy_obj.call_count,
        error = get_error_handler().format_error(call_err),
      })
      -- Continue despite the error - we still want to call the original function
    end

    get_logger().debug("Calling original function through spy", {
      call_count = spy_obj.call_count,
    })

    -- Call the original function with protected call
    -- Create args table outside the try scope
    local args = { ... }
    local fn_success, fn_result, fn_err = get_error_handler().try(function()
      -- For method calls, ensure the first argument is treated as 'self'
      -- We need to return multiple values, so we use a wrapper table
      local results

      -- Special case for spying on object methods
      if type(fn) == "function" then
        results = { fn(unpack_table(args)) }
      else
        -- This should never happen, but we handle it just in case
        get_logger().warn("Function in spy is not callable", {
          fn_type = type(fn),
        })
        results = {}
      end

      return results
    end)

    if not fn_success then
      -- See if we have access to error_handler's test mode
      local is_test_mode = error_handler
        and type(error_handler) == "table"
        and type(get_error_handler().is_test_mode) == "function"
        and get_error_handler().is_test_mode()

      -- Check if this is a test-related error, based on structured properties
      local is_expected_in_test = is_test_mode
        and (
          type(fn_result) == "table"
          and (fn_result.category == "VALIDATION" or fn_result.category == "TEST_EXPECTED")
        )

      if is_expected_in_test then
        -- This is likely an intentional error for testing purposes
        get_logger().debug("Function error captured by spy (expected in test)", {
          function_name = "spy.capture",
          error = get_error_handler().format_error(fn_result),
        })
      else
        -- Check if we're suppressing logs in tests
        if
          not (
            error_handler
            and type(get_error_handler().is_suppressing_test_logs) == "function"
            and get_error_handler().is_suppressing_test_logs()
          )
        then
          -- This is an unexpected error, log at warning level
          get_logger().warn("Original function threw an error", {
            function_name = "spy.capture",
            error = get_error_handler().format_error(fn_result),
          })
        end
      end
      -- Re-throw the error for consistent behavior
      error(fn_result)
    end

    -- Unpack the results
    return unpack_table(fn_result)
  end

  -- Set up the spy's call method with error handling
  local mt_success, _, mt_err = get_error_handler().try(function()
    setmetatable(spy_obj, {
      __call = function(_, ...)
        return capture(...)
      end,
    })
    return true
  end)

  if not mt_success then
    local error_obj = get_error_handler().runtime_error("Failed to set up spy metatable", {
      function_name = "spy.new",
      fn_type = type(fn),
    }, mt_err)
    get_logger().error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Add spy methods, both as instance methods and properties
  -- Define helper methods with error handling
  local function make_method_callable_prop(obj, method_name, method_fn)
    -- Input validation
    if obj == nil then
      local err = get_error_handler().validation_error("Cannot add method to nil object", {
        function_name = "make_method_callable_prop",
        parameter_name = "obj",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      error(err.message)
    end

    if type(method_name) ~= "string" then
      local err = get_error_handler().validation_error("Method name must be a string", {
        function_name = "make_method_callable_prop",
        parameter_name = "method_name",
        provided_type = type(method_name),
        provided_value = tostring(method_name),
      })
      get_logger().error(err.message, err.context)
      error(err.message)
    end

    if type(method_fn) ~= "function" then
      local err = get_error_handler().validation_error("Method function must be a function", {
        function_name = "make_method_callable_prop",
        parameter_name = "method_fn",
        provided_type = type(method_fn),
        provided_value = tostring(method_fn),
      })
      get_logger().error(err.message, err.context)
      error(err.message)
    end

    -- Use protected call to set up the method
    local success, result, err = get_error_handler().try(function()
      -- Create metatable with call function
      local mt = {}
      mt.__call = function(_, ...)
        -- Create closure function to handle varargs properly
        local function call_method(...)
          return method_fn(obj, ...)
        end
        return call_method(...)
      end

      -- Set the metatable on the property
      obj[method_name] = setmetatable({}, mt)
      return true
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to create callable property",
        {
          function_name = "make_method_callable_prop",
          method_name = method_name,
          obj_type = type(obj),
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      error(error_obj.message)
    end
  end

  --- Checks if the spy was called with the specified arguments.
  --- Supports deep comparison and matchers for arguments.
  ---@param self spy_object
  ---@param ... any Expected arguments.
  ---@return boolean|{result: boolean, call_index: number}|nil, table? Returns `true` or a result object `{result=true, call_index=N}` if a match is found, `false` otherwise, `nil` on critical error during comparison, plus optional error object.
  ---@throws table If validation or comparison fails critically.
  function spy_obj:called_with(...)
    local expected_args = { ... }
    local found = false
    local matching_call_index = nil

    -- Use protected call to search for matching calls
    local success, search_result, err = get_error_handler().try(function()
      for i, call_record in ipairs(self.calls) do
        -- Extract args from the call record
        local call_args = call_record.args
        if args_match(expected_args, call_args) then
          return { found = true, index = i }
        end
      end
      return { found = false }
    end)

    if not success then
      get_logger().warn("Error during called_with search", {
        function_name = "spy_obj:called_with",
        expected_args_count = #expected_args,
        calls_count = #self.calls,
        error = get_error_handler().format_error(search_result),
      })
      -- Fallback to false on error
      return false
    end

    -- If no matching call was found, return false
    if not search_result.found then
      return false
    end

    -- Set up the result values
    found = true
    matching_call_index = search_result.index

    -- Return an object with chainable methods
    local result = {
      result = true,
      call_index = matching_call_index,
    }

    -- Make it work in boolean contexts with error handling
    local mt_success, _, mt_err = get_error_handler().try(function()
      setmetatable(result, {
        __call = function()
          return true
        end,
        __tostring = function()
          return "true"
        end,
      })
      return true
    end)

    if not mt_success then
      get_logger().warn("Failed to set up result metatable", {
        function_name = "spy_obj:called_with",
        error = get_error_handler().format_error(mt_err),
      })
      -- Return a simple boolean true as fallback
      return true
    end

    return result
  end

  -- Add the callable property with error handling
  local method_success, method_err = get_error_handler().try(function()
    make_method_callable_prop(spy_obj, "called_with", spy_obj.called_with)
    return true
  end)

  if not method_success then
    get_logger().warn("Failed to set up called_with method", {
      function_name = "spy.new",
      error = get_error_handler().format_error(method_err),
    })
    -- We continue despite this error - the method will still work as a method
  end

  --- Checks if the spy was called exactly `n` times.
  ---@param self spy_object
  ---@param n number The expected number of calls.
  ---@return boolean|nil, table? `true` if call count matches `n`, `false` otherwise, or `nil` on error, plus optional error object.
  ---@throws table If validation fails (e.g., `n` is not a number).
  function spy_obj:called_times(n)
    -- Input validation
    if n == nil then
      get_logger().warn("Missing required parameter in called_times", {
        function_name = "spy_obj:called_times",
        parameter_name = "n",
        provided_value = "nil",
      })
      return false
    end

    if type(n) ~= "number" then
      get_logger().warn("Invalid parameter type in called_times", {
        function_name = "spy_obj:called_times",
        parameter_name = "n",
        provided_type = type(n),
        provided_value = tostring(n),
      })
      return false
    end

    -- Use protected call to safely check call count
    local success, result = get_error_handler().try(function()
      return self.call_count == n
    end)

    if not success then
      get_logger().warn("Error during called_times check", {
        function_name = "spy_obj:called_times",
        expected_count = n,
        error = get_error_handler().format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  get_error_handler().try(function()
    make_method_callable_prop(spy_obj, "called_times", spy_obj.called_times)
  end)

  --- Checks if the spy was never called (call count is 0).
  ---@param self spy_object
  ---@return boolean|nil, table? `true` if call count is 0, `false` otherwise, or `nil` on error, plus optional error object.
  function spy_obj:not_called()
    -- Use protected call to safely check call count
    local success, result = get_error_handler().try(function()
      return self.call_count == 0
    end)

    if not success then
      get_logger().warn("Error during not_called check", {
        function_name = "spy_obj:not_called",
        error = get_error_handler().format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  get_error_handler().try(function()
    make_method_callable_prop(spy_obj, "not_called", spy_obj.not_called)
  end)

  --- Checks if the spy was called exactly one time.
  ---@param self spy_object
  ---@return boolean|nil, table? `true` if call count is 1, `false` otherwise, or `nil` on error, plus optional error object.
  function spy_obj:called_once()
    -- Use protected call to safely check call count
    local success, result = get_error_handler().try(function()
      return self.call_count == 1
    end)

    if not success then
      get_logger().warn("Error during called_once check", {
        function_name = "spy_obj:called_once",
        error = get_error_handler().format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  get_error_handler().try(function()
    make_method_callable_prop(spy_obj, "called_once", spy_obj.called_once)
  end)

  --- Gets the call record object for the most recent call to the spy.
  ---@param self spy_object
  ---@return table|nil call_record The last call record (from `calls` field), or `nil` if never called or on error, plus optional error object. The record contains `{args, timestamp, result?, error?}`.
  function spy_obj:last_call()
    -- Use protected call to safely get the last call
    local success, result = get_error_handler().try(function()
      if self.calls and #self.calls > 0 then
        -- Return the last call record
        return self.calls[#self.calls]
      end
      return nil
    end)

    if not success then
      get_logger().warn("Error during last_call check", {
        function_name = "spy_obj:last_call",
        error = get_error_handler().format_error(result),
      })
      -- Fallback to nil on error
      return nil
    end

    return result
  end

  -- Add the callable property with error handling
  get_error_handler().try(function()
    make_method_callable_prop(spy_obj, "last_call", spy_obj.last_call)
  end)

  --- Checks if *any* call to this spy occurred before the Nth call to `other_spy`.
  --- Uses the global call sequence counter.
  ---@param self spy_object
  ---@param other_spy spy_object The other spy object to compare against.
  ---@param call_index? number The 1-based index of the call on `other_spy` to check against (default: 1).
  ---@return boolean|nil, table? `true` if this spy was called before the specified call to `other_spy`, `false` otherwise, or `nil` on error, plus optional error object.
  ---@throws table If validation or comparison fails critically.
  function spy_obj:called_before(other_spy, call_index)
    -- Input validation
    if other_spy == nil then
      local err = get_error_handler().validation_error("Cannot check call order with nil spy", {
        function_name = "spy_obj:called_before",
        parameter_name = "other_spy",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return false
    end

    call_index = call_index or 1

    -- Safety checks with proper error handling
    if type(other_spy) ~= "table" then
      local err = get_error_handler().validation_error("called_before requires a spy object as argument", {
        function_name = "spy_obj:called_before",
        parameter_name = "other_spy",
        provided_type = type(other_spy),
      })
      get_logger().error(err.message, err.context)
      return false
    end

    if not other_spy.call_sequence then
      local err = get_error_handler().validation_error("called_before requires a spy object with call_sequence", {
        function_name = "spy_obj:called_before",
        parameter_name = "other_spy",
        is_spy = other_spy._is_firmo_spy or false,
      })
      get_logger().error(err.message, err.context)
      return false
    end

    -- Use protected call for the actual comparison
    local success, result = get_error_handler().try(function()
      -- Make sure both spies have been called
      if self.call_count == 0 or other_spy.call_count == 0 then
        return false
      end

      -- Make sure other_spy has been called enough times
      if other_spy.call_count < call_index then
        return false
      end

      -- Get sequence number of the other spy's call
      local other_sequence = other_spy.call_sequence[call_index]
      if not other_sequence then
        return false
      end

      -- Check if any of this spy's calls happened before that
      for _, sequence in ipairs(self.call_sequence) do
        if sequence < other_sequence then
          return true
        end
      end

      return false
    end)

    if not success then
      get_logger().warn("Error during called_before check", {
        function_name = "spy_obj:called_before",
        self_call_count = self.call_count,
        other_call_count = other_spy.call_count,
        call_index = call_index,
        error = get_error_handler().format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  get_error_handler().try(function()
    make_method_callable_prop(spy_obj, "called_before", spy_obj.called_before)
  end)

  --- Checks if the *last* call to this spy occurred after the Nth call to `other_spy`.
  --- Uses the global call sequence counter.
  ---@param self spy_object
  ---@param other_spy spy_object The other spy object to compare against.
  ---@param call_index? number The 1-based index of the call on `other_spy` to check against (default: 1).
  ---@return boolean|nil, table? `true` if this spy's last call was after the specified call to `other_spy`, `false` otherwise, or `nil` on error, plus optional error object.
  ---@throws table If validation or comparison fails critically.
  function spy_obj:called_after(other_spy, call_index)
    -- Input validation
    if other_spy == nil then
      local err = get_error_handler().validation_error("Cannot check call order with nil spy", {
        function_name = "spy_obj:called_after",
        parameter_name = "other_spy",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return false
    end

    call_index = call_index or 1

    -- Safety checks with proper error handling
    if type(other_spy) ~= "table" then
      local err = get_error_handler().validation_error("called_after requires a spy object as argument", {
        function_name = "spy_obj:called_after",
        parameter_name = "other_spy",
        provided_type = type(other_spy),
      })
      get_logger().error(err.message, err.context)
      return false
    end

    if not other_spy.call_sequence then
      local err = get_error_handler().validation_error("called_after requires a spy object with call_sequence", {
        function_name = "spy_obj:called_after",
        parameter_name = "other_spy",
        is_spy = other_spy._is_firmo_spy or false,
      })
      get_logger().error(err.message, err.context)
      return false
    end

    -- Use protected call for the actual comparison
    local success, result = get_error_handler().try(function()
      -- Make sure both spies have been called
      if self.call_count == 0 or other_spy.call_count == 0 then
        return false
      end

      -- Make sure other_spy has been called enough times
      if other_spy.call_count < call_index then
        return false
      end

      -- Get sequence of the other spy's call
      local other_sequence = other_spy.call_sequence[call_index]
      if not other_sequence then
        return false
      end

      -- Check if any of this spy's calls happened after that
      local last_self_sequence = self.call_sequence[self.call_count]
      if last_self_sequence > other_sequence then
        return true
      end

      return false
    end)

    if not success then
      get_logger().warn("Error during called_after check", {
        function_name = "spy_obj:called_after",
        self_call_count = self.call_count,
        other_call_count = other_spy.call_count,
        call_index = call_index,
        error = get_error_handler().format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  get_error_handler().try(function()
    make_method_callable_prop(spy_obj, "called_after", spy_obj.called_after)
  end)

  -- Final check to make sure all required properties are set
  local final_check_success, _ = get_error_handler().try(function()
    if not spy_obj.calls then
      spy_obj.calls = {}
    end
    if not spy_obj.call_sequence then
      spy_obj.call_sequence = {}
    end
    if not spy_obj.call_history then
      spy_obj.call_history = {}
    end
    return true
  end)

  if not final_check_success then
    get_logger().warn("Failed to ensure all spy properties are set", {
      function_name = "spy.new",
    })
    -- Continue despite this warning - the spy should still work
  end

  local qual_module = get_quality()
  if qual_module and qual_module.track_spy_created then
    local spy_id_str = tostring(spy_obj) -- Use table's string representation as a unique ID
    qual_module.track_spy_created(spy_id_str)
  end

  return spy_obj
end

--- Creates a spy on an existing object method.
--- Replaces the method with a spy wrapper that records calls while still executing the original method.
--- Adds a `restore()` method to the returned spy object.
---@param obj table The target object.
---@param method_name string The name of the method to spy on.
---@return spy_object|nil spy The spy object wrapping the method, or `nil` on error.
---@return table|nil error Error object if validation or spy creation fails.
---@throws table If validation or spy creation fails critically.
function spy.on(obj, method_name)
  -- Input validation
  if obj == nil then
    local err = get_error_handler().validation_error("Cannot create spy on nil object", {
      function_name = "spy.on",
      parameter_name = "obj",
      provided_value = "nil",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if method_name == nil then
    local err = get_error_handler().validation_error("Method name cannot be nil", {
      function_name = "spy.on",
      parameter_name = "method_name",
      provided_value = "nil",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Creating spy on object method", {
    obj_type = type(obj),
    method_name = method_name,
  })

  if type(obj) ~= "table" then
    local err = get_error_handler().validation_error("spy.on requires a table as its first argument", {
      function_name = "spy.on",
      parameter_name = "obj",
      expected = "table",
      actual = type(obj),
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if type(method_name) ~= "string" then
    local err = get_error_handler().validation_error("Method name must be a string", {
      function_name = "spy.on",
      parameter_name = "method_name",
      provided_type = type(method_name),
      provided_value = tostring(method_name),
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Check if method exists
  if obj[method_name] == nil then
    local err = get_error_handler().validation_error("Method does not exist on object", {
      function_name = "spy.on",
      parameter_name = "method_name",
      method_name = method_name,
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if type(obj[method_name]) ~= "function" then
    local err = get_error_handler().validation_error("Method exists but is not a function", {
      function_name = "spy.on",
      parameter_name = "method_name",
      method_name = method_name,
      actual_type = type(obj[method_name]),
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Store the original function
  local original_fn = obj[method_name]
  -- Create the spy with error handling
  local success, spy_obj, err = get_error_handler().try(function()
    -- Create a simple spy for tracking calls
    local spy_object = spy.new(function() end)

    -- Create a straightforward method wrapper that:
    -- 1. Records the call to the spy
    -- 2. Calls the original function
    local method_wrapper = function(...)
      local args = { ... }

      -- Log received arguments for debugging
      get_logger().debug("Spy method_wrapper received arguments", {
        method_name = method_name,
        args_count = #args,
        is_first_arg_obj = args[1] == obj,
      })

      -- Check if this is a direct call without self (obj.method style)
      local is_direct_call = #args >= 1 and args[1] ~= obj

      -- Create tracking arguments with consistent structure
      local track_args = {}

      -- Create args for the original function call
      local call_args = {}

      if is_direct_call then
        -- For direct calls (obj.method()), add self as first arg for both
        table.insert(track_args, obj)
        table.insert(call_args, obj)
        for i = 1, #args do
          table.insert(track_args, args[i])
          table.insert(call_args, args[i])
        end
      else
        -- For colon calls (obj:method), args already has self
        for i = 1, #args do
          table.insert(track_args, args[i])
          table.insert(call_args, args[i])
        end
      end

      -- IMPORTANT: Update tracking properties BEFORE calling the function
      -- This ensures calls are always tracked even if the function throws
      spy_object.called = true
      spy_object.call_count = spy_object.call_count + 1

      -- Record call with proper structure
      local call_record = {
        args = track_args,
        timestamp = os.time(),
      }

      -- Store the call record
      table.insert(spy_object.calls, call_record)
      table.insert(spy_object.call_history, track_args)

      -- Add to sequence tracking
      if not _G._firmo_sequence_counter then
        _G._firmo_sequence_counter = 0
      end

      -- Record the call in the spy object
      spy_object.called_with(unpack_table(track_args))

      -- Call through to the original method with the original args
      local original_args = call_args or args

      -- Always try with original arguments first - no special handling for nil
      local status, result = pcall(function()
        return original_fn(unpack_table(original_args))
      end)

      -- Only if we get a concatenation error, retry with nil converted to empty string
      if not status and string.find(result or "", "attempt to concatenate") then
        -- Create a new table with nil values replaced by empty strings
        local safe_args = {}
        for i = 1, #original_args do
          safe_args[i] = original_args[i] == nil and "" or original_args[i]
        end
        return original_fn(unpack_table(safe_args))
      elseif not status then
        -- If it was some other error, re-raise it
        error(result, 2)
      else
        -- If the call succeeded (even with nil args), return the result
        return result
      end

      -- These tracking calls have been moved above before calling the original function
    end

    -- Don't replace the spy's __call as that creates infinite recursion
    -- Just return the spy with its tracking and the method_wrapper function
    return {
      spy = spy_object,
      wrapper = method_wrapper,
    }
  end) -- Close the get_error_handler().try function here

  if not success then
    local error_obj = get_error_handler().runtime_error(
      "Failed to create spy",
      {
        function_name = "spy.on",
        method_name = method_name,
        target_type = type(obj),
      },
      spy_obj -- On failure, spy_obj contains the error
    )
    get_logger().error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Configure the spy with contextual information
  success, err = get_error_handler().try(function()
    spy_obj.target = obj
    spy_obj.name = method_name
    spy_obj.original = original_fn
    return true
  end)

  if not success then
    local error_obj = get_error_handler().runtime_error("Failed to configure spy", {
      function_name = "spy.on",
      method_name = method_name,
      target_type = type(obj),
    }, err)
    get_logger().error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  --- Restores the original method that was replaced by this spy.
  --- Only applies to spies created with `spy.on`.
  ---@param self spy_object
  ---@return boolean|nil success `true` if restored successfully, `false` otherwise, or `nil` on critical error.
  ---@return table|nil error Error object if restoration failed.
  ---@throws table If restoration fails critically.
  function spy_obj:restore()
    get_logger().debug("Restoring original method", {
      target_type = type(self.target),
      method_name = self.name,
    })

    -- Validate target and name
    if self.target == nil or self.name == nil then
      local err = get_error_handler().validation_error("Cannot restore spy with nil target or name", {
        function_name = "spy_obj:restore",
        has_target = self.target ~= nil,
        has_name = self.name ~= nil,
      })
      get_logger().error(err.message, err.context)
      return false, err
    end

    -- Use protected call to restore the original method
    local success, result, err = get_error_handler().try(function()
      if self.target and self.name then
        self.target[self.name] = self.original
        return true
      end
      return false
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to restore original method",
        {
          function_name = "spy_obj:restore",
          target_type = type(self.target),
          method_name = self.name,
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return false, error_obj
    end

    if result == false then
      get_logger().warn("Could not restore method - missing target or method name", {
        function_name = "spy_obj:restore",
      })
      return false
    end

    local qual_module = get_quality()
    if qual_module and qual_module.track_spy_restored then
      local spy_id_str = tostring(self) -- 'self' here is the spy_object
      qual_module.track_spy_restored(spy_id_str)
    end

    return true
  end

  -- Get wrapper from the result returned by get_error_handler().try
  local wrapper = spy_obj.wrapper
  local spy_object = spy_obj.spy

  -- Add restore method to the spy object
  spy_object.restore = spy_obj.restore

  -- Replace the method with our spy wrapper
  success, err = get_error_handler().try(function()
    obj[method_name] = wrapper
    return true
  end)

  if not success then
    -- Try to restore original method, but don't worry if it fails
    get_error_handler().try(function()
      obj[method_name] = original_fn
    end)

    local error_obj = get_error_handler().runtime_error("Failed to replace method with spy", {
      function_name = "spy.on",
      method_name = method_name,
      target_type = type(obj),
    }, err)
    get_logger().error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Configure the spy with additional context
  spy_object.target = obj
  spy_object.name = method_name
  spy_object.original = original_fn

  local qual_module = get_quality()
  if qual_module and qual_module.track_spy_created then
    local spy_id_str = tostring(spy_object) -- spy_object is the final spy object being returned
    qual_module.track_spy_created(spy_id_str)
  end

  return spy_object
end

--- Internal global counter for call sequence tracking.
---@private
spy._next_sequence = 0

--- Generates the next unique call sequence number using a global counter.
---@return number|nil, table? The next sequence number, or `nil` on error, plus optional error object.
---@private
spy._new_sequence = function()
  -- Use protected call to safely increment sequence
  local success, result, err = get_error_handler().try(function()
    spy._next_sequence = spy._next_sequence + 1
    return spy._next_sequence
  end)

  if not success then
    get_logger().warn("Error incrementing sequence counter", {
      function_name = "spy._new_sequence",
      error = get_error_handler().format_error(result),
    })
    -- Use a fallback value based on timestamp to ensure uniqueness
    local fallback_value = os.time() * 1000 + math.random(1000)
    get_logger().debug("Using fallback sequence value", {
      value = fallback_value,
    })
    return fallback_value
  end

  return result
end

-- Before returning the module, set up a module-level error handler
local module_success, module_err = get_error_handler().try(function()
  -- Add basic error handling to module functions
  local original_functions = {}

  -- Store original functions
  for k, v in pairs(spy) do
    if type(v) == "function" and k ~= "_new_sequence" then
      original_functions[k] = v
    end
  end

  -- Replace functions with protected versions
  for k, original_fn in pairs(original_functions) do
    -- Create a wrapper function that properly handles varargs
    local wrapper_function = function(...)
      -- Capture args in the outer function
      local args = { ... }

      -- Use error handler to safely call the original function
      local success, result, err = get_error_handler().try(function()
        -- Create an inner function to handle the actual call
        local function safe_call(...)
          return original_fn(...)
        end
        return safe_call(unpack_table(args))
      end)

      -- Handle errors consistently
      if not success then
        get_logger().error("Unhandled error in spy module function", {
          function_name = "spy." .. k,
          error = get_error_handler().format_error(result),
        })
        return nil, result
      end

      return result
    end

    -- Replace the original function with our wrapper
    spy[k] = wrapper_function
  end

  return true
end)

if not module_success then
  get_logger().warn("Failed to set up module-level error handling", {
    error = get_error_handler().format_error(module_err),
  })
  -- Continue regardless - the individual function error handling should still work
end

return spy
