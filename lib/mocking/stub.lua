--[[
    stub.lua - Function stubbing implementation for the Firmo testing framework

    This module provides robust function stubbing capabilities for test isolation and behavior verification.
    Stubs replace real functions with test doubles that have pre-programmed behavior.

    Features:
    - Create standalone stub functions that return specified values
    - Replace object methods with stubs that can be restored later
    - Configure stubs to throw errors for testing error handling
    - Return values in sequence to simulate changing behavior over time
    - Advanced sequence control with cycling and exhaustion handling
    - Integration with the spy system for call tracking and verification
    - Automatic restoration of original methods

    @module stub
    @author Firmo Team
    @license MIT
    @copyright 2023-2025
]]

---@class stub_module
---@field _VERSION string Module version
---@field new fun(value_or_fn?: any): stub_object Create a new stub function that returns a specified value or uses custom implementation
---@field on fun(obj: table, method_name: string, return_value_or_implementation: any): stub_object Replace an object's method with a stub
---@field create fun(implementation?: function): stub_object Create a new stub with a custom implementation (alias for new)
---@field sequence fun(values: table): stub_object Create a stub that returns values in sequence
---@field from_spy fun(spy_obj: table): stub_object Create a stub from an existing spy object
---@field is_stub fun(obj: any): boolean Check if an object is a stub
---@field reset_all fun(): boolean Reset all created stubs to their initial state

---@class stub_object : spy_object
---@field _is_firmo_stub boolean Flag indicating this is a stub object
---@field returns fun(value: any): stub_object Configure stub to return the given value
---@field returns_self fun(): stub_object Configure stub to return itself (chaining helper)
---@field returns_in_sequence fun(values: any[]): stub_object Configure stub to return values in sequence
---@field cycle_sequence fun(should_cycle: boolean): stub_object Configure sequence to cycle (repeat) after exhausted
---@field reset fun(): stub_object Reset the stub's call count and history
---@field throws fun(error: any): stub_object Configure stub to throw the specified error when called
---@field when_exhausted fun(mode: string, value?: any): stub_object Configure what happens when sequence is exhausted
---@field when fun(matcher_fn: function): stub_object Set a function that matches arguments for conditional behavior
---@field when_called_with fun(...): stub_object Set specific arguments to match for conditional behavior
---@field original function|nil The original function that was stubbed (for restoration)
---@field restore fun(): nil Restore the original function (for object method stubs)
---@field target table|nil The object containing the stubbed method
---@field name string|nil The name of the stubbed method
---@field _is_on_stub boolean|nil Flag indicating this is an object method stub
---@field reset_sequence fun(): stub_object Reset sequence to the beginning
---@field returns_async fun(value: any, delay?: number): stub_object Configure stub to return a value asynchronously
---@field set_sequence_behavior fun(options: {cycles?: boolean, exhausted_behavior?: string, exhausted_value?: any}): stub_object Configure sequence behavior
---@field restore fun(): void Restore the original method (for stubs created with stub.on)
---@field target table|nil The object that contains the stubbed method
---@field name string|nil Name of the method being stubbed
---@field original function|nil Original method implementation before stubbing
---@field _is_firmo_stub boolean Flag indicating this is a stub object
---@field _sequence_values table|nil Values to return in sequence
---@field _sequence_index number Current index in the sequence
---@field _sequence_cycles boolean Whether the sequence should cycle when exhausted
---@field _sequence_exhausted_behavior string Behavior when sequence is exhausted ("nil", "fallback", "custom")
---@field _sequence_exhausted_value any Value to return when sequence is exhausted
---@field _original_implementation function Original implementation function

local spy = require("lib.mocking.spy")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("stub")
logging.configure_from_config("stub")

-- Track all created stubs
local all_stubs = {}

local stub = {
  -- Module version
  _VERSION = "1.0.0",
}

---@private
---@param stub_obj stub_object The stub object to modify
---@param implementation function The original implementation function
---@param sequence_table table|nil Table of values to return in sequence
---@return function sequence_implementation Function that implements sequence behavior
--- Helper function to add sequential return values implementation
--- Creates a function that returns values from sequence_table one by one.
--- This sophisticated sequence handler provides:
--- - Returns values from the sequence in order
--- - Configurable cycling behavior (restart from beginning when exhausted)
--- - Custom exhaustion behavior (nil, fallback to original, custom value)
--- - Support for function values in the sequence (called with arguments)
--- - Error handling and detailed logging
local function add_sequence_methods(stub_obj, implementation, sequence_table)
  logger.debug("Setting up sequence methods for stub", {
    sequence_length = sequence_table and #sequence_table or 0,
  })
    
  -- Initialize sequence properties on the stub object
  stub_obj._sequence_values = sequence_table
  stub_obj._sequence_index = 1
  stub_obj._sequence_cycles = false
  stub_obj._sequence_exhausted_behavior = "nil"
  stub_obj._sequence_exhausted_value = nil
  stub_obj._original_implementation = implementation
    
  return implementation
end

-- Add stub-specific methods
--- Create a standalone stub function that returns a specified value or uses a custom implementation
--- This is the primary function for creating stubs that aren't attached to existing objects.
--- The created stub inherits all spy functionality and adds stub-specific methods.
---
--- @param return_value_or_implementation any Value to return when stub is called, or function to use as implementation
--- @return stub_object stub A new stub function object that can be called like a normal function
---
--- @usage
--- -- Create a stub that returns a fixed value
--- local my_stub = stub.new("fixed value")
---
--- -- Create a stub with custom implementation
--- local custom_stub = stub.new(function(arg1, arg2)
---   return arg1 * arg2
--- end)
---
--- -- Configure further with chaining
--- local advanced_stub = stub.new()
---   :returns_in_sequence({1, 2, 3})
---   :cycle_sequence(true)
function stub.new(return_value_or_implementation)
  logger.debug("Creating new stub", {
    value_type = type(return_value_or_implementation),
  })

  local implementation
  if type(return_value_or_implementation) == "function" then
    implementation = return_value_or_implementation
    logger.debug("Using provided function as implementation")
  else
    implementation = function()
      return return_value_or_implementation
    end
    logger.debug("Creating function to return provided value", {
      return_value_type = type(return_value_or_implementation),
    })
  end

  -- Create a spy object with the implementation
  local spy_obj = spy.new(implementation)
  
  -- Initialize stub-specific properties
  spy_obj._matchers = {}
  spy_obj._is_firmo_stub = true
  spy_obj._is_function = true  -- Flag to help with type checking in tests
  
  -- Get the spy's metatable
  local mt = getmetatable(spy_obj)
  local orig_call = mt.__call
  
  -- Make the table appear function-like in tests
  -- Note: Lua's native type() function can't be overridden with metamethods
  -- but our tests might be using a custom type checking mechanism
  
  -- Replace the call handler with one that adds stub-specific functionality
  mt.__call = function(self, ...)
    -- Check for argument matchers first
    for _, matcher in ipairs(self._matchers or {}) do
      if matcher.fn(...) then
        -- Record the call with spy functionality
        orig_call(self, ...)

        if matcher.throw_error then
          error(matcher.throw_error, 2)
        elseif matcher.return_fn then
          return matcher.return_fn(...)
        else
          return matcher.return_value
        end
      end
    end

    -- Handle sequence values if present
    if self._sequence_values and #self._sequence_values > 0 then
      -- Get the current value from the sequence
      local current_index = self._sequence_index

      logger.debug("Sequence stub called", {
        current_index = current_index,
        sequence_length = #self._sequence_values,
        cycles_enabled = self._sequence_cycles,
      })

      -- Handle cycling and sequence exhaustion
      if current_index > #self._sequence_values then
        logger.debug("Sequence exhausted", {
          exhausted_behavior = self._sequence_exhausted_behavior,
          has_fallback = self._original_implementation ~= nil,
          has_custom_value = self._sequence_exhausted_value ~= nil,
        })

        if self._sequence_cycles then
          -- Wrap around to beginning of sequence
          current_index = ((current_index - 1) % #self._sequence_values) + 1
          self._sequence_index = current_index
          logger.debug("Cycling to beginning of sequence", {
            new_index = current_index,
          })
        else
          -- If not cycling and sequence is exhausted, handle according to config
          if self._sequence_exhausted_behavior == "fallback" and self._original_implementation then
            logger.debug("Using fallback implementation")

            -- Track the call with the original spy call handler
            orig_call(self, ...)

            -- Return the result from the original implementation
            return self._original_implementation(...)
          elseif self._sequence_exhausted_behavior == "custom" and self._sequence_exhausted_value ~= nil then
            logger.debug("Using custom exhausted value", {
              value_type = type(self._sequence_exhausted_value),
            })

            -- Track the call with the original spy call handler
            orig_call(self, ...)

            return self._sequence_exhausted_value
          elseif self._sequence_exhausted_behavior == "error" then
            logger.debug("Raising error for exhausted sequence")

            -- Track the call with the original spy call handler
            orig_call(self, ...)

            error("Stub sequence exhausted", 2)
          else
            -- Default behavior: return nil when exhausted
            logger.debug("Sequence exhausted, returning nil")
            self._sequence_index = current_index + 1

            -- Track the call with the original spy call handler
            orig_call(self, ...)

            return nil
          end
        end
      end

      -- Get the sequence value
      local value = self._sequence_values[current_index]

      -- Advance to the next value in the sequence
      self._sequence_index = current_index + 1

      logger.debug("Returning sequence value", {
        index = current_index,
        value_type = type(value),
        next_index = self._sequence_index,
      })

      -- Track the call with the original spy call handler
      orig_call(self, ...)

      -- If value is a function, call it with the arguments
      if type(value) == "function" then
        logger.debug("Executing function from sequence")
        return value(...)
      else
        return value
      end
    end

    -- If we have a custom matcher, check it
    if self._custom_return_fn or self._custom_return_value ~= nil then
      -- Track the call with the original spy call handler
      orig_call(self, ...)

      if self._custom_return_fn then
        return self._custom_return_fn(...)
      else
        return self._custom_return_value
      end
    end

    -- Default behavior: use the original call handler
    return orig_call(self, ...)
  end

  -- Add to all_stubs registry
  table.insert(all_stubs, spy_obj)
  
  -- Add missing methods
  --- Reset the stub's call history and counters
  --- @return stub_object The same stub object for method chaining
  function spy_obj:reset()
    logger.debug("Resetting stub call history")
    self.calls = {}
    self.call_count = 0
    self.called = false
    self.call_sequence = {}
    self.call_history = {}
    return self
  end
  
  --- Specify behavior when a sequence is exhausted (no more values to return)
  --- Controls what the stub returns after all sequence values have been used
  --- and cycling is disabled. Three options are available:
  --- - "nil": Return nil (default behavior)
  --- - "fallback": Use the original implementation
  --- - "custom": Return a custom value
  ---
  --- @param behavior string The behavior when sequence is exhausted: "nil", "fallback", or "custom"
  --- @param custom_value any The value to return when behavior is "custom"
  --- @return stub_object The same stub object for method chaining
  function spy_obj:when_exhausted(behavior, custom_value)
    if behavior == "nil" then
      self._sequence_exhausted_behavior = "nil"
      self._sequence_exhausted_value = nil
    elseif behavior == "fallback" then
      self._sequence_exhausted_behavior = "fallback"
    elseif behavior == "custom" then
      self._sequence_exhausted_behavior = "custom"
      self._sequence_exhausted_value = custom_value
    elseif behavior == "error" then
      self._sequence_exhausted_behavior = "error"
    else
      error("Invalid exhausted behavior. Use 'nil', 'fallback', 'custom', or 'error'")
    end
    return self
  end
  
  --- Configure the stub to return a specific value when called with specific arguments
  --- @param ... any The arguments to match
  --- @return stub_object A stub configured for the specific arguments
  function spy_obj:when_called_with(...)
    logger.debug("Setting up stub for specific arguments")
    local args = { ... }

    -- Function to match exact arguments
    local matcher_fn = function(...)
      local call_args = { ... }

      -- If argument count differs, not a match
      if #call_args ~= #args then
        return false
      end

      -- Compare each argument
      for i, arg in ipairs(args) do
        if call_args[i] ~= arg then
          return false
        end
      end

      return true
    end

    -- Use the general when method with our specific matcher
    return self:when(matcher_fn)
  end
  
  --- Configure the stub to use a custom matcher function
  --- @param matcher_fn function Function that takes the same arguments as the stub and returns true if they match
  --- @return stub_object A stub configured with the custom matcher
  function spy_obj:when(matcher_fn)
    logger.debug("Setting up stub with custom matcher function")

    -- Initialize matchers table if it doesn't exist
    self._matchers = self._matchers or {}

    -- Create a new matcher
    local matcher = {
      fn = matcher_fn,
      return_value = nil,
      return_fn = nil,
      throw_error = nil,
    }

    -- Insert at the beginning to take precedence
    table.insert(self._matchers, 1, matcher)

    -- We'll return the same stub for chaining
    local new_stub = self

    -- Initialize with defaults
    new_stub._custom_return_value = nil
    new_stub._custom_return_fn = nil

    -- Override returns to store the return value for this matcher
    local orig_returns = new_stub.returns
    new_stub.returns = function(self, value)
      matcher.return_value = value
      return self
    end

    -- Override throws to store error behavior for this matcher
    local orig_throws = new_stub.throws
    new_stub.throws = function(self, error_msg)
      matcher.throw_error = error_msg
      return self
    end

    return new_stub
  end

  --- Configure the stub to throw an error when called
  --- Creates a new stub that throws the specified error message or object
  --- Used for testing error handling code paths
  ---
  --- @param error_message string|table The error message or error object to throw
  --- @return stub_object A new stub configured to throw the specified error
  -- cycle_sequence is already implemented above
  
  function spy_obj:throws(error_message)
    logger.debug("Creating stub that throws error", {
      error_message = error_message,
    })

    -- Create a function that throws the error
    local new_impl = function()
      error(error_message, 2)
    end

    -- Create a new stub with the implementation
    local new_stub = stub.new(new_impl)

    -- Copy important properties
    for k, v in pairs(self) do
      if k ~= "calls" and k ~= "call_count" and k ~= "called" and k ~= "call_sequence" then
        new_stub[k] = v
      end
    end

    logger.debug("Created and configured error-throwing stub")
    return new_stub
  end

  --- Configure the stub to return values from a sequence in order
  --- Creates a new stub that returns each value from the provided table in sequence,
  --- one value per call. Useful for simulating changing behavior over time.
  ---
  --- @param values table An array of values to return in sequence
  --- @return stub_object A new stub configured with sequence behavior
  ---
  --- @usage
  --- -- Create a stub that returns values in sequence
  --- local seq_stub = stub.new():returns_in_sequence({"first", "second", "third"})
  ---
  --- -- By default, returns nil after the sequence is exhausted
  --- print(seq_stub()) -- "first"
  --- print(seq_stub()) -- "second"
  --- print(seq_stub()) -- "third"
  --- print(seq_stub()) -- nil (sequence exhausted)
  ---
  --- -- Can be combined with other sequence options:
  --- local cycling_stub = stub.new()
  ---   :returns_in_sequence({1, 2, 3})
  ---   :cycle_sequence(true)
  function spy_obj:returns_in_sequence(values)
    logger.debug("Creating stub with sequence of return values", {
      is_table = type(values) == "table",
      values_count = type(values) == "table" and #values or 0,
    })

    if type(values) ~= "table" then
      logger.error("Invalid argument type for returns_in_sequence", {
        expected = "table",
        received = type(values),
      })
      error("returns_in_sequence requires a table of values")
    end
    -- Add sequence methods to the stub object
    -- Add sequence methods to the stub object
    local sequence_impl = add_sequence_methods(self, implementation, values)

    -- Create a new stub that will use the sequence values
    local new_stub = stub.new(implementation)

    -- Copy sequence properties
    new_stub._sequence_values = values
    new_stub._sequence_index = 1
    new_stub._original_implementation = implementation
    -- Copy other important properties
    for k, v in pairs(self) do
      if
        k ~= "calls"
        and k ~= "call_count"
        and k ~= "called"
        and k ~= "call_sequence"
        and k ~= "_sequence_values"
        and k ~= "_sequence_index"
        and k ~= "_original_implementation"
      then
        new_stub[k] = v
      end
    end

    logger.debug("Created and configured sequence return stub", {
      sequence_length = #values,
    })

    return new_stub
  end

  --- Configure whether the sequence of return values should cycle
  --- When enabled, after the last value in the sequence is returned,
  --- the stub will start again from the first value. When disabled,
  --- the exhausted behavior determines what happens when the sequence ends.
  ---
  --- @param enable boolean Whether to enable cycling (defaults to true)
  --- @return stub_object The same stub object for method chaining
  function spy_obj:cycle_sequence(enable)
    if enable == nil then
      enable = true
    end
    self._sequence_cycles = enable
    return self
  end
  
  return spy_obj
end

--- Create a stub for an object method, replacing the original method temporarily
--- This function replaces a method on an object with a stub that tracks calls and provides
--- pre-programmed behavior. The original method is preserved and can be restored later.
---
--- @param obj table The object containing the method to stub
--- @param method_name string The name of the method to stub
--- @param return_value_or_implementation any Value to return when stub is called, or function to use as implementation
--- @return stub_object stub A stub object that tracks calls and controls method behavior
---
--- @usage
--- -- Replace a method with a stub that returns 42
--- local my_obj = { calculate = function() return 10 end }
--- local calc_stub = stub.on(my_obj, "calculate", 42)
---
--- -- Replace with custom implementation
--- stub.on(logger, "warn", function(msg) print("STUBBED: " .. msg) end)
---
--- -- Create a stub that throws an error
--- local error_stub = stub.on(file_system, "read", function()
---   error("Simulated IO error")
--- end)
---
--- -- Restore the original method
--- calc_stub:restore()
function stub.on(obj, method_name, return_value_or_implementation)
  logger.debug("Creating stub on object method", {
    obj_type = type(obj),
    method_name = method_name,
    return_value_type = type(return_value_or_implementation),
  })

  if type(obj) ~= "table" then
    logger.error("Invalid object type for stub.on", {
      expected = "table",
      actual = type(obj),
    })
    error("stub.on requires a table as its first argument")
  end

  if not obj[method_name] then
    logger.error("Method not found on target object", {
      method_name = method_name,
    })
    error("stub.on requires a method name that exists on the object")
  end

  local original_fn = obj[method_name]
  logger.debug("Original method found", {
    method_name = method_name,
    original_type = type(original_fn),
  })

  -- Create an implementation that delegates to the original function
  local implementation = function()
    return return_value_or_implementation
  end

  -- Create a spy object with the implementation
  local spy_obj = spy.new(implementation)

  -- Use the spy_obj directly as our stub_obj
  local stub_obj = spy_obj

  -- Initialize matcher table
  stub_obj._matchers = {}
  stub_obj.target = obj
  stub_obj.name = method_name
  stub_obj._is_on_stub = true

  -- Store original function for restoration
  stub_obj.original = original_fn

  -- Add to all_stubs registry
  table.insert(all_stubs, stub_obj)

  --- Restore the original method that was replaced by the stub
  --- This undoes the stubbing, replacing the stub with the original method
  --- implementation that existed before stubbing. After restoration, calling
  --- the method will execute the original behavior.
  ---
  --- @return nil
  function stub_obj:restore()
    logger.debug("Restoring original method", {
      target_type = type(self.target),
      method_name = self.name,
    })

    if self.target and self.name then
      self.target[self.name] = self.original
      logger.debug("Original method restored successfully")
    else
      logger.warn("Could not restore method - missing target or method name")
    end
  end

  -- Add stub-specific methods

  --- Configure the stub to return a specific fixed value
  --- Creates a new stub that returns the specified value regardless of arguments
  ---
  --- @param value any The value to return when the stub is called
  --- @return stub_object A new stub configured to return the specified value
  function stub_obj:returns(value)
    -- Create a new stub
    local new_stub = stub.on(obj, method_name, function()
      return value
    end)
    return new_stub
  end

  --- Configure the stub to throw an error when called
  --- Creates a new stub that throws the specified error message or object
  --- Uses structured error objects with TEST_EXPECTED category when error_handler is available
  ---
  --- @param error_message string|table The error message or error object to throw
  --- @return stub_object A new stub configured to throw the specified error
  function stub_obj:throws(error_message)
    -- Create a new stub using structured error objects with TEST_EXPECTED category
    local new_stub = stub.on(obj, method_name, function()
      local err
      if error_handler and type(error_handler.test_expected_error) == "function" then
        -- Create a structured test error if error_handler is available
        err = error_handler.test_expected_error(error_message, {
          stub_name = method_name,
          stub_type = "throws",
        })
        error(err, 2)
      else
        -- Fallback to simple error for backward compatibility
        error(error_message, 2)
      end
    end)
    return new_stub
  end

  --- Configure the stub to return values from a sequence in order
  --- Creates a new stub that returns each value from the provided table in sequence,
  --- one value per call. Useful for simulating changing behavior over time.
  ---
  --- @param values table An array of values to return in sequence
  --- @return stub_object A new stub configured with sequence behavior
  function stub_obj:returns_in_sequence(values)
    if type(values) ~= "table" then
      error("returns_in_sequence requires a table of values")
    end

    -- Create a new stub
    local new_stub = stub.on(obj, method_name, implementation)

    -- Add sequence methods to the stub object
    add_sequence_methods(new_stub, implementation, values)

    -- Copy sequence properties
    new_stub._sequence_values = values
    new_stub._sequence_index = 1
    new_stub._original_implementation = implementation

    return new_stub
  end

  --- Configure whether the sequence of return values should cycle
  --- When enabled, after the last value in the sequence is returned,
  --- the stub will start again from the first value. When disabled,
  --- the exhausted behavior determines what happens when the sequence ends.
  ---
  --- @param enable boolean Whether to enable cycling (defaults to true)
  --- @return stub_object The same stub object for method chaining
  function stub_obj:cycle_sequence(enable)
    if enable == nil then
      enable = true
    end
    self._sequence_cycles = enable
    return self
  end

  --- Specify behavior when a sequence is exhausted (no more values to return)
  --- Controls what the stub returns after all sequence values have been used
  --- and cycling is disabled. Three options are available:
  --- - "nil": Return nil (default behavior)
  --- - "fallback": Use the original implementation
  --- - "custom": Return a custom value
  ---
  --- @param behavior string The behavior when sequence is exhausted: "nil", "fallback", or "custom"
  --- @param custom_value any The value to return when behavior is "custom"
  --- @return stub_object The same stub object for method chaining
  function stub_obj:when_exhausted(behavior, custom_value)
    if behavior == "nil" then
      self._sequence_exhausted_behavior = "nil"
      self._sequence_exhausted_value = nil
    elseif behavior == "fallback" then
      self._sequence_exhausted_behavior = "fallback"
    elseif behavior == "custom" then
      self._sequence_exhausted_behavior = "custom"
      self._sequence_exhausted_value = custom_value
    else
      error("Invalid exhausted behavior. Use 'nil', 'fallback', or 'custom'")
    end
    return self
  end

  --- Reset sequence to the beginning
  --- Sets the sequence index back to 1, so the next call will return
  --- the first value in the sequence again.
  ---
  --- @return stub_object The same stub object for method chaining
  function stub_obj:reset_sequence()
    self._sequence_index = 1
    return self
  end

  -- Replace the method with our stub
  obj[method_name] = stub_obj

  return stub_obj
end

--- Check if an object is a stub created by this module
--- @param obj any The object to check
--- @return boolean True if the object is a stub, false otherwise
function stub.is_stub(obj)
  if type(obj) ~= "table" then
    return false
  end

  return obj._is_firmo_stub == true
end

--- Reset all stubs created during the current test run
--- Clears the call history and counters of all stubs
--- @return boolean True if successful
function stub.reset_all()
  logger.debug("Resetting all stubs", { count = #all_stubs })

  for _, stub_obj in ipairs(all_stubs) do
    if type(stub_obj.reset) == "function" then
      stub_obj:reset()
    end
  end

  return true
end

return stub
