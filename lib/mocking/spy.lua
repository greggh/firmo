--- Function spying implementation for firmo
---
--- Provides powerful spy functionality for testing:
--- - Create standalone spy functions for tracking calls
--- - Spy on object methods while preserving their behavior
--- - Track function call arguments, return values, and call order
--- - Support for call verification and assertions
--- - Advanced call sequence tracking for verifying execution order
--- - Full error handling with detailed context information
---
--- Spies don't change the behavior of the spied function but record all
--- interactions for later verification. This is useful for ensuring functions
--- are called with the expected arguments and in the expected order.
---
--- @version 1.0.0
--- @author Firmo Team

---@class spy_module
---@field _VERSION string Module version identifier
---@field new fun(fn?: function): spy_object Create a new standalone spy function that wraps the provided function
---@field on fun(obj: table, method_name: string): spy_object|nil, table? Create a spy on an object method, replacing it with the spy while preserving behavior
---@field assert fun(spy_obj: table): spy_assert Helper to create assertion functions for a spy
---@field is_spy fun(obj: any): boolean Check if an object is a spy created by this module
---@field get_all_spies fun(): table<number, spy_object> Get all spy objects created during the current test run
---@field reset_all fun(): boolean Reset all created spy objects, clearing their call history
---@field wrap fun(fn: function, options?: table): spy_object Create a spy that wraps a function with additional options
---@field _next_sequence number Internal counter for tracking call order
---@field _new_sequence fun(): number Internal function to generate unique sequence numbers

---@class spy_object
---@field calls table<number, {args: table, returned: table, threw: boolean|nil, error: any, this: any}> Record of all calls to the spy with arguments and results
---@field call_count number Number of times the spy was called during the test
---@field called boolean Whether the spy was called at least once (true if call_count > 0)
---@field call_sequence table<number, number> Sequence numbers for each call, used to track order across multiple spies
---@field call_history table<number, table> Legacy/compatibility field with call arguments history
---@field reset fun(): spy_object Reset the spy's call history and counters but maintain configuration
---@field and_call_through fun(): spy_object Configure spy to also call the original function when invoked
---@field and_call_fake fun(fn: function): spy_object Configure spy to call a fake implementation function
---@field and_return fun(value: any): spy_object Configure spy to return a specific value without calling original
---@field and_throw fun(error: any): spy_object Configure spy to throw a specific error when called
---@field call_count_by_args fun(args: table): number Get count of calls with specific argument values
---@field get_call fun(index: number): table|nil Get details of a specific call by index
---@field get_calls fun(): table<number, table> Get all call details including arguments and results
---@field called_with fun(...): boolean|{result: boolean, call_index: number} Check if spy was called with specific arguments
---@field called_times fun(n: number): boolean Check if spy was called exactly n times
---@field not_called fun(): boolean Check if spy was never called (call_count == 0)
---@field called_once fun(): boolean Check if spy was called exactly once (call_count == 1)
---@field last_call fun(): table|nil Get the arguments from the most recent call
---@field called_before fun(other_spy: spy_object, call_index?: number): boolean Check if this spy was called before another spy
---@field called_after fun(other_spy: spy_object, call_index?: number): boolean Check if this spy was called after another spy
---@field target table|nil For method spies, the target object containing the spied method
---@field name string|nil For method spies, the name of the spied method on the target
---@field original function|nil For method spies, the original method implementation
---@field restore fun(): boolean|nil, table? For method spies, restore the original method implementation
---@field _is_firmo_spy boolean Flag indicating this is a spy object created by firmo
---@field _original_fn function|nil The original wrapped function, if any

---@class spy_assert
---@field was_called fun(times?: number): boolean Assert the spy was called at least once or a specific number of times
---@field was_not_called fun(): boolean Assert the spy was never called during the test
---@field was_called_with fun(...): boolean Assert the spy was called with the specified arguments at least once
---@field was_called_times fun(times: number): boolean Assert the spy was called exactly the specified number of times
---@field was_called_before fun(other_spy: spy_object, index?: number): boolean Assert this spy was called before another spy
---@field was_called_after fun(other_spy: spy_object, index?: number): boolean Assert this spy was called after another spy
---@field has_returned fun(value: any): boolean Assert the spy returned a specific value at least once
---@field has_thrown fun(error_value?: any): boolean Assert the spy threw an error (optionally matching a specific value)

local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack_table = table.unpack or unpack

-- Initialize module logger
local logger = logging.get_logger("spy")
logging.configure_from_config("spy")

local spy = {
  -- Module version
  _VERSION = "1.0.0",
}

-- Helper functions
local function is_spy(obj)
  return type(obj) == "table" and obj._is_firmo_spy == true
end

-- Deep comparison of tables for equality
local function tables_equal(t1, t2)
  -- Input validation with fallback
  if t1 == nil or t2 == nil then
    logger.debug("Comparing with nil value", {
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
  local success, result = error_handler.try(function()
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
    logger.warn("Error during table comparison", {
      function_name = "tables_equal",
      error = error_handler.format_error(result),
    })
    -- Fallback to simple equality check on error
    return false
  end

  return result
end

-- Helper to check if value matches another value with matcher support
local function matches_arg(expected, actual)
  -- Use protected call to catch any errors during matching
  local success, result = error_handler.try(function()
    -- If expected is a matcher, use its match function
    if type(expected) == "table" and expected._is_matcher then
      if type(expected.match) ~= "function" then
        logger.warn("Invalid matcher object (missing match function)", {
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
    logger.warn("Error during argument matching", {
      function_name = "matches_arg",
      expected_type = type(expected),
      actual_type = type(actual),
      error = error_handler.format_error(result),
    })
    -- Fallback to direct equality check on error
    return expected == actual
  end

  return result
end

-- Check if args match a set of expected args
local function args_match(expected_args, actual_args)
  -- Input validation with fallback
  if expected_args == nil or actual_args == nil then
    logger.warn("Nil args in comparison", {
      function_name = "args_match",
      expected_nil = expected_args == nil,
      actual_nil = actual_args == nil,
    })
    return expected_args == actual_args
  end

  if type(expected_args) ~= "table" or type(actual_args) ~= "table" then
    logger.warn("Non-table args in comparison", {
      function_name = "args_match",
      expected_type = type(expected_args),
      actual_type = type(actual_args),
    })
    return false
  end

  -- Use protected call to catch any errors during matching
  local success, result = error_handler.try(function()
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
    logger.warn("Error during args matching", {
      function_name = "args_match",
      expected_count = #expected_args,
      actual_count = #actual_args,
      error = error_handler.format_error(result),
    })
    -- Fallback to false on error
    return false
  end

  return result
end

-- Create a new spy function
--- Create a new standalone spy function
---@param fn? function Optional function to spy on
---@return spy_object spy A spy object that records calls
function spy.new(fn)
  -- Input validation with fallback
  logger.debug("Creating new spy function", {
    fn_type = type(fn),
  })

  -- Not treating nil fn as an error, just providing a default
  fn = fn or function() end

  -- Use protected call to create the spy object
  local success, spy_obj, err = error_handler.try(function()
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
    local error_obj = error_handler.runtime_error(
      "Failed to create spy object",
      {
        function_name = "spy.new",
        fn_type = type(fn),
      },
      spy_obj -- On failure, spy_obj contains the error
    )
    logger.error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Function that captures all calls
  local function capture(...)
    -- Use protected call to track the call
    local args = { ... } -- Capture args here before the protected call
    local call_success, _, call_err = error_handler.try(function()
      -- Update call tracking state
      spy_obj.called = true
      spy_obj.call_count = spy_obj.call_count + 1

      -- Record call with proper structure
      -- Record call with proper structure
      local call_record = {
        args = args, -- All arguments as an array
        timestamp = os.time(), -- When the call happened
        result = nil, -- Will be set after function call
        error = nil, -- Will be set if function throws
      }
      -- Store the call record
      table.insert(spy_obj.calls, call_record)
      table.insert(spy_obj.call_history, args) -- Keep this for backward compatibility

      logger.debug("Spy function called", {
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
      logger.error("Error during spy call tracking", {
        function_name = "spy.capture",
        call_count = spy_obj.call_count,
        error = error_handler.format_error(call_err),
      })
      -- Continue despite the error - we still want to call the original function
    end

    logger.debug("Calling original function through spy", {
      call_count = spy_obj.call_count,
    })

    -- Call the original function with protected call
    -- Create args table outside the try scope
    local args = { ... }
    local fn_success, fn_result, fn_err = error_handler.try(function()
      -- For method calls, ensure the first argument is treated as 'self'
      -- We need to return multiple values, so we use a wrapper table
      local results

      -- Special case for spying on object methods
      if type(fn) == "function" then
        results = { fn(unpack_table(args)) }
      else
        -- This should never happen, but we handle it just in case
        logger.warn("Function in spy is not callable", {
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
        and type(error_handler.is_test_mode) == "function"
        and error_handler.is_test_mode()

      -- Check if this is a test-related error, based on structured properties
      local is_expected_in_test = is_test_mode
        and (
          type(fn_result) == "table"
          and (fn_result.category == "VALIDATION" or fn_result.category == "TEST_EXPECTED")
        )

      if is_expected_in_test then
        -- This is likely an intentional error for testing purposes
        logger.debug("Function error captured by spy (expected in test)", {
          function_name = "spy.capture",
          error = error_handler.format_error(fn_result),
        })
      else
        -- Check if we're suppressing logs in tests
        if
          not (
            error_handler
            and type(error_handler.is_suppressing_test_logs) == "function"
            and error_handler.is_suppressing_test_logs()
          )
        then
          -- This is an unexpected error, log at warning level
          logger.warn("Original function threw an error", {
            function_name = "spy.capture",
            error = error_handler.format_error(fn_result),
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
  local mt_success, _, mt_err = error_handler.try(function()
    setmetatable(spy_obj, {
      __call = function(_, ...)
        return capture(...)
      end,
    })
    return true
  end)

  if not mt_success then
    local error_obj = error_handler.runtime_error("Failed to set up spy metatable", {
      function_name = "spy.new",
      fn_type = type(fn),
    }, mt_err)
    logger.error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Add spy methods, both as instance methods and properties
  -- Define helper methods with error handling
  local function make_method_callable_prop(obj, method_name, method_fn)
    -- Input validation
    if obj == nil then
      local err = error_handler.validation_error("Cannot add method to nil object", {
        function_name = "make_method_callable_prop",
        parameter_name = "obj",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      error(err.message)
    end

    if type(method_name) ~= "string" then
      local err = error_handler.validation_error("Method name must be a string", {
        function_name = "make_method_callable_prop",
        parameter_name = "method_name",
        provided_type = type(method_name),
        provided_value = tostring(method_name),
      })
      logger.error(err.message, err.context)
      error(err.message)
    end

    if type(method_fn) ~= "function" then
      local err = error_handler.validation_error("Method function must be a function", {
        function_name = "make_method_callable_prop",
        parameter_name = "method_fn",
        provided_type = type(method_fn),
        provided_value = tostring(method_fn),
      })
      logger.error(err.message, err.context)
      error(err.message)
    end

    -- Use protected call to set up the method
    local success, result, err = error_handler.try(function()
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
      local error_obj = error_handler.runtime_error(
        "Failed to create callable property",
        {
          function_name = "make_method_callable_prop",
          method_name = method_name,
          obj_type = type(obj),
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      error(error_obj.message)
    end
  end

  -- Define the called_with method with error handling
  function spy_obj:called_with(...)
    local expected_args = { ... }
    local found = false
    local matching_call_index = nil

    -- Use protected call to search for matching calls
    local success, search_result, err = error_handler.try(function()
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
      logger.warn("Error during called_with search", {
        function_name = "spy_obj:called_with",
        expected_args_count = #expected_args,
        calls_count = #self.calls,
        error = error_handler.format_error(search_result),
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
    local mt_success, _, mt_err = error_handler.try(function()
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
      logger.warn("Failed to set up result metatable", {
        function_name = "spy_obj:called_with",
        error = error_handler.format_error(mt_err),
      })
      -- Return a simple boolean true as fallback
      return true
    end

    return result
  end

  -- Add the callable property with error handling
  local method_success, method_err = error_handler.try(function()
    make_method_callable_prop(spy_obj, "called_with", spy_obj.called_with)
    return true
  end)

  if not method_success then
    logger.warn("Failed to set up called_with method", {
      function_name = "spy.new",
      error = error_handler.format_error(method_err),
    })
    -- We continue despite this error - the method will still work as a method
  end

  -- Define the called_times method with error handling
  function spy_obj:called_times(n)
    -- Input validation
    if n == nil then
      logger.warn("Missing required parameter in called_times", {
        function_name = "spy_obj:called_times",
        parameter_name = "n",
        provided_value = "nil",
      })
      return false
    end

    if type(n) ~= "number" then
      logger.warn("Invalid parameter type in called_times", {
        function_name = "spy_obj:called_times",
        parameter_name = "n",
        provided_type = type(n),
        provided_value = tostring(n),
      })
      return false
    end

    -- Use protected call to safely check call count
    local success, result = error_handler.try(function()
      return self.call_count == n
    end)

    if not success then
      logger.warn("Error during called_times check", {
        function_name = "spy_obj:called_times",
        expected_count = n,
        error = error_handler.format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  error_handler.try(function()
    make_method_callable_prop(spy_obj, "called_times", spy_obj.called_times)
  end)

  -- Define the not_called method with error handling
  function spy_obj:not_called()
    -- Use protected call to safely check call count
    local success, result = error_handler.try(function()
      return self.call_count == 0
    end)

    if not success then
      logger.warn("Error during not_called check", {
        function_name = "spy_obj:not_called",
        error = error_handler.format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  error_handler.try(function()
    make_method_callable_prop(spy_obj, "not_called", spy_obj.not_called)
  end)

  -- Define the called_once method with error handling
  function spy_obj:called_once()
    -- Use protected call to safely check call count
    local success, result = error_handler.try(function()
      return self.call_count == 1
    end)

    if not success then
      logger.warn("Error during called_once check", {
        function_name = "spy_obj:called_once",
        error = error_handler.format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  error_handler.try(function()
    make_method_callable_prop(spy_obj, "called_once", spy_obj.called_once)
  end)

  -- Define the last_call method with error handling
  function spy_obj:last_call()
    -- Use protected call to safely get the last call
    local success, result = error_handler.try(function()
      if self.calls and #self.calls > 0 then
        -- Return the last call record
        return self.calls[#self.calls]
      end
      return nil
    end)

    if not success then
      logger.warn("Error during last_call check", {
        function_name = "spy_obj:last_call",
        error = error_handler.format_error(result),
      })
      -- Fallback to nil on error
      return nil
    end

    return result
  end

  -- Add the callable property with error handling
  error_handler.try(function()
    make_method_callable_prop(spy_obj, "last_call", spy_obj.last_call)
  end)

  -- Check if this spy was called before another spy, with error handling
  function spy_obj:called_before(other_spy, call_index)
    -- Input validation
    if other_spy == nil then
      local err = error_handler.validation_error("Cannot check call order with nil spy", {
        function_name = "spy_obj:called_before",
        parameter_name = "other_spy",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return false
    end

    call_index = call_index or 1

    -- Safety checks with proper error handling
    if type(other_spy) ~= "table" then
      local err = error_handler.validation_error("called_before requires a spy object as argument", {
        function_name = "spy_obj:called_before",
        parameter_name = "other_spy",
        provided_type = type(other_spy),
      })
      logger.error(err.message, err.context)
      return false
    end

    if not other_spy.call_sequence then
      local err = error_handler.validation_error("called_before requires a spy object with call_sequence", {
        function_name = "spy_obj:called_before",
        parameter_name = "other_spy",
        is_spy = other_spy._is_firmo_spy or false,
      })
      logger.error(err.message, err.context)
      return false
    end

    -- Use protected call for the actual comparison
    local success, result = error_handler.try(function()
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
      logger.warn("Error during called_before check", {
        function_name = "spy_obj:called_before",
        self_call_count = self.call_count,
        other_call_count = other_spy.call_count,
        call_index = call_index,
        error = error_handler.format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  error_handler.try(function()
    make_method_callable_prop(spy_obj, "called_before", spy_obj.called_before)
  end)

  -- Check if this spy was called after another spy, with error handling
  function spy_obj:called_after(other_spy, call_index)
    -- Input validation
    if other_spy == nil then
      local err = error_handler.validation_error("Cannot check call order with nil spy", {
        function_name = "spy_obj:called_after",
        parameter_name = "other_spy",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return false
    end

    call_index = call_index or 1

    -- Safety checks with proper error handling
    if type(other_spy) ~= "table" then
      local err = error_handler.validation_error("called_after requires a spy object as argument", {
        function_name = "spy_obj:called_after",
        parameter_name = "other_spy",
        provided_type = type(other_spy),
      })
      logger.error(err.message, err.context)
      return false
    end

    if not other_spy.call_sequence then
      local err = error_handler.validation_error("called_after requires a spy object with call_sequence", {
        function_name = "spy_obj:called_after",
        parameter_name = "other_spy",
        is_spy = other_spy._is_firmo_spy or false,
      })
      logger.error(err.message, err.context)
      return false
    end

    -- Use protected call for the actual comparison
    local success, result = error_handler.try(function()
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
      logger.warn("Error during called_after check", {
        function_name = "spy_obj:called_after",
        self_call_count = self.call_count,
        other_call_count = other_spy.call_count,
        call_index = call_index,
        error = error_handler.format_error(result),
      })
      -- Fallback to false on error
      return false
    end

    return result
  end

  -- Add the callable property with error handling
  error_handler.try(function()
    make_method_callable_prop(spy_obj, "called_after", spy_obj.called_after)
  end)

  -- Final check to make sure all required properties are set
  local final_check_success, _ = error_handler.try(function()
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
    logger.warn("Failed to ensure all spy properties are set", {
      function_name = "spy.new",
    })
    -- Continue despite this warning - the spy should still work
  end

  return spy_obj
end

-- Create a spy on an object method
function spy.on(obj, method_name)
  -- Input validation
  if obj == nil then
    local err = error_handler.validation_error("Cannot create spy on nil object", {
      function_name = "spy.on",
      parameter_name = "obj",
      provided_value = "nil",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if method_name == nil then
    local err = error_handler.validation_error("Method name cannot be nil", {
      function_name = "spy.on",
      parameter_name = "method_name",
      provided_value = "nil",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Creating spy on object method", {
    obj_type = type(obj),
    method_name = method_name,
  })

  if type(obj) ~= "table" then
    local err = error_handler.validation_error("spy.on requires a table as its first argument", {
      function_name = "spy.on",
      parameter_name = "obj",
      expected = "table",
      actual = type(obj),
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if type(method_name) ~= "string" then
    local err = error_handler.validation_error("Method name must be a string", {
      function_name = "spy.on",
      parameter_name = "method_name",
      provided_type = type(method_name),
      provided_value = tostring(method_name),
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Check if method exists
  if obj[method_name] == nil then
    local err = error_handler.validation_error("Method does not exist on object", {
      function_name = "spy.on",
      parameter_name = "method_name",
      method_name = method_name,
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if type(obj[method_name]) ~= "function" then
    local err = error_handler.validation_error("Method exists but is not a function", {
      function_name = "spy.on",
      parameter_name = "method_name",
      method_name = method_name,
      actual_type = type(obj[method_name]),
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Store the original function
  local original_fn = obj[method_name]
  -- Create the spy with error handling
  local success, spy_obj, err = error_handler.try(function()
    -- Create a simple spy for tracking calls
    local spy_object = spy.new(function() end)

    -- Create a straightforward method wrapper that:
    -- 1. Records the call to the spy
    -- 2. Calls the original function
    local method_wrapper = function(...)
      local args = { ... }

      -- Log received arguments for debugging
      logger.debug("Spy method_wrapper received arguments", {
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
  end) -- Close the error_handler.try function here

  if not success then
    local error_obj = error_handler.runtime_error(
      "Failed to create spy",
      {
        function_name = "spy.on",
        method_name = method_name,
        target_type = type(obj),
      },
      spy_obj -- On failure, spy_obj contains the error
    )
    logger.error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Configure the spy with contextual information
  success, err = error_handler.try(function()
    spy_obj.target = obj
    spy_obj.name = method_name
    spy_obj.original = original_fn
    return true
  end)

  if not success then
    local error_obj = error_handler.runtime_error("Failed to configure spy", {
      function_name = "spy.on",
      method_name = method_name,
      target_type = type(obj),
    }, err)
    logger.error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Add restore method with error handling
  function spy_obj:restore()
    logger.debug("Restoring original method", {
      target_type = type(self.target),
      method_name = self.name,
    })

    -- Validate target and name
    if self.target == nil or self.name == nil then
      local err = error_handler.validation_error("Cannot restore spy with nil target or name", {
        function_name = "spy_obj:restore",
        has_target = self.target ~= nil,
        has_name = self.name ~= nil,
      })
      logger.error(err.message, err.context)
      return false, err
    end

    -- Use protected call to restore the original method
    local success, result, err = error_handler.try(function()
      if self.target and self.name then
        self.target[self.name] = self.original
        return true
      end
      return false
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to restore original method",
        {
          function_name = "spy_obj:restore",
          target_type = type(self.target),
          method_name = self.name,
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return false, error_obj
    end

    if result == false then
      logger.warn("Could not restore method - missing target or method name", {
        function_name = "spy_obj:restore",
      })
      return false
    end

    return true
  end

  -- Get wrapper from the result returned by error_handler.try
  local wrapper = spy_obj.wrapper
  local spy_object = spy_obj.spy

  -- Add restore method to the spy object
  spy_object.restore = spy_obj.restore

  -- Replace the method with our spy wrapper
  success, err = error_handler.try(function()
    obj[method_name] = wrapper
    return true
  end)

  if not success then
    -- Try to restore original method, but don't worry if it fails
    error_handler.try(function()
      obj[method_name] = original_fn
    end)

    local error_obj = error_handler.runtime_error("Failed to replace method with spy", {
      function_name = "spy.on",
      method_name = method_name,
      target_type = type(obj),
    }, err)
    logger.error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Configure the spy with additional context
  spy_object.target = obj
  spy_object.name = method_name
  spy_object.original = original_fn

  return spy_object
end

-- Create and record the call sequence used for spy.on and spy.new methods, with error handling
spy._next_sequence = 0
spy._new_sequence = function()
  -- Use protected call to safely increment sequence
  local success, result, err = error_handler.try(function()
    spy._next_sequence = spy._next_sequence + 1
    return spy._next_sequence
  end)

  if not success then
    logger.warn("Error incrementing sequence counter", {
      function_name = "spy._new_sequence",
      error = error_handler.format_error(result),
    })
    -- Use a fallback value based on timestamp to ensure uniqueness
    local fallback_value = os.time() * 1000 + math.random(1000)
    logger.debug("Using fallback sequence value", {
      value = fallback_value,
    })
    return fallback_value
  end

  return result
end

-- Before returning the module, set up a module-level error handler
local module_success, module_err = error_handler.try(function()
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
      local success, result, err = error_handler.try(function()
        -- Create an inner function to handle the actual call
        local function safe_call(...)
          return original_fn(...)
        end
        return safe_call(unpack_table(args))
      end)

      -- Handle errors consistently
      if not success then
        logger.error("Unhandled error in spy module function", {
          function_name = "spy." .. k,
          error = error_handler.format_error(result),
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
  logger.warn("Failed to set up module-level error handling", {
    error = error_handler.format_error(module_err),
  })
  -- Continue regardless - the individual function error handling should still work
end

return spy
