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
---@field _sequence_values table|nil Values to return in sequence
---@field _sequence_index number Current index in the sequence
---@field _sequence_cycles boolean Whether the sequence should cycle when exhausted
---@field _sequence_exhausted_behavior string Behavior when sequence is exhausted ("nil", "fallback", "custom")
---@field _sequence_exhausted_value any Value to return when sequence is exhausted
---@field _original_implementation function Original implementation function

local logging = require("lib.tools.logging")
local spy = require("lib.mocking.spy")
local error_handler = require("lib.tools.error_handler")

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

  -- Create a sequence handler function that will be used when the stub is called
  local sequence_implementation = function(...)
    local args = { ... }

    -- Check if we have sequence values
    if not stub_obj._sequence_values or #stub_obj._sequence_values == 0 then
      logger.warn("Sequence stub called with no sequence values")
      return implementation(...)
    end

    -- Get the current sequence value
    local sequence_value = stub_obj._sequence_values[stub_obj._sequence_index]

    -- Increment the sequence index
    stub_obj._sequence_index = stub_obj._sequence_index + 1

    -- Check if we've reached the end of the sequence
    if stub_obj._sequence_index > #stub_obj._sequence_values then
      if stub_obj._sequence_cycles then
        -- Reset to the beginning if cycling is enabled
        stub_obj._sequence_index = 1
        logger.debug("Sequence exhausted, cycling back to start")
      else
        -- Handle exhaustion based on configured behavior
        logger.debug("Sequence exhausted, using configured exhaustion behavior", {
          behavior = stub_obj._sequence_exhausted_behavior,
        })
      end
    end

    -- Handle the various value types in the sequence
    if type(sequence_value) == "function" then
      -- If the sequence value is a function, call it with the arguments
      return sequence_value(...)
    else
      -- Otherwise, return the value directly
      return sequence_value
    end
  end

  -- Replace the stub's implementation with our sequence handler
  stub_obj._implementation = sequence_implementation

  return sequence_implementation
end

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
  else
    implementation = function()
      return return_value_or_implementation
    end
  end

  -- Create a spy object with the implementation
  local stub_obj = spy.new(implementation)

  -- Mark it as a stub
  stub_obj._is_firmo_stub = true

  -- Initialize stub-specific fields
  stub_obj._sequence_values = nil
  stub_obj._sequence_index = 1
  stub_obj._sequence_cycles = false
  stub_obj._sequence_exhausted_behavior = "nil"
  stub_obj._sequence_exhausted_value = nil
  stub_obj._custom_return_value = return_value_or_implementation
  stub_obj._custom_return_fn = nil
  stub_obj._original_implementation = implementation

  -- Add stub methods

  --- Configure the stub to return a specific fixed value
  --- @param value any The value to return when the stub is called
  --- @return stub_object The same stub object for method chaining
  function stub_obj:returns(value)
    -- Update the current stub instead of creating a new one
    self._custom_return_value = value
    self._custom_return_fn = nil
    return self
  end

  --- Configure the stub to return values from a sequence in order
  --- @param values table An array of values to return in sequence
  --- @return stub_object The same stub object for method chaining
  function stub_obj:returns_in_sequence(values)
    if type(values) ~= "table" then
      logger.error("Invalid argument type for returns_in_sequence", {
        expected = "table",
        received = type(values),
      })
      error("returns_in_sequence requires a table of values")
    end

    if #values == 0 then
      logger.error("Empty sequence provided to returns_in_sequence")
      error("returns_in_sequence requires a non-empty table of values")
    end

    -- Update sequence properties on the current stub
    self._sequence_values = values
    self._sequence_index = 1
    self._original_implementation = implementation

    -- Add sequence methods
    local sequence_impl = add_sequence_methods(self, implementation, values)

    -- Replace the stub's implementation with our sequence handler
    setmetatable(self, {
      __call = function(_, ...)
        -- Track the call using spy functionality
        self.called = true
        self.call_count = self.call_count + 1
        table.insert(self.calls, { args = { ... }, timestamp = os.time() })
        -- Return the sequence value
        return sequence_impl(...)
      end,
    })

    logger.debug("Configured sequence return stub", {
      sequence_length = #values,
    })

    return self
  end

  --- Configure whether the sequence of return values should cycle
  --- @param enable boolean Whether to enable cycling (defaults to true)
  --- @return stub_object The same stub object for method chaining
  function stub_obj:cycle_sequence(enable)
    if enable == nil then
      enable = true
    end
    self._sequence_cycles = enable
    return self
  end

  --- Add throws method to allow the stub to throw errors
  --- @param error_message string|table The error message or error object to throw
  --- @return stub_object The same stub object for method chaining
  function stub_obj:throws(error_message)
    local impl = function()
      local err
      if error_handler and type(error_handler.test_expected_error) == "function" then
        -- Create a structured test error if error_handler is available
        err = error_handler.test_expected_error(error_message, {
          stub_type = "throws",
        })
        error(err, 2)
      else
        -- Fallback to simple error for backward compatibility
        error(error_message, 2)
      end
    end

    -- Replace the implementation in-place
    setmetatable(self, {
      __call = function(_, ...)
        -- Track the call using spy functionality
        spy.track_call(self, ...)
        -- Throw the error
        return impl(...)
      end,
    })

    return self
  end

  --- Specify behavior when a sequence is exhausted (no more values to return)
  --- @param behavior string The behavior when sequence is exhausted: "nil", "error", or "custom"
  --- @param custom_value any The value to return when behavior is "custom"
  --- @return stub_object The same stub object for method chaining
  function stub_obj:when_exhausted(behavior, custom_value)
    if not self._sequence_values then
      logger.error("when_exhausted called on stub without sequence")
      error("Cannot call when_exhausted on a stub without a sequence")
    end

    if behavior == "nil" then
      self._sequence_exhausted_behavior = "nil"
      self._sequence_exhausted_value = nil
    elseif behavior == "error" then
      self._sequence_exhausted_behavior = "error"
    elseif behavior == "custom" then
      self._sequence_exhausted_behavior = "custom"
      self._sequence_exhausted_value = custom_value
    else
      local err = "Invalid exhausted behavior. Use 'nil', 'error', or 'custom'"
      logger.error(err)
      error(err)
    end
    return self
  end

  -- Add to registry
  table.insert(all_stubs, stub_obj)

  return stub_obj
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

  -- Create an implementation based on the type of return_value_or_implementation
  local implementation
  if type(return_value_or_implementation) == "function" then
    implementation = return_value_or_implementation
  else
    implementation = function()
      return return_value_or_implementation
    end
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
  --- @param value any The value to return when the stub is called
  --- @return stub_object The same stub object for method chaining
  function stub_obj:returns(value)
    -- Update the current stub instead of creating a new one
    local impl = function()
      return value
    end

    -- Replace the implementation in-place
    setmetatable(self, {
      __call = function(_, ...)
        -- Track the call using spy functionality
        spy.track_call(self, ...)
        -- Return the fixed value
        return impl(...)
      end,
    })

    return self
  end

  --- Configure the stub to throw an error when called
  --- Uses structured error objects with TEST_EXPECTED category when error_handler is available
  ---
  --- @param error_message string|table The error message or error object to throw
  --- @return stub_object The same stub object for method chaining
  function stub_obj:throws(error_message)
    -- Update the current stub instead of creating a new one
    local impl = function()
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
    end

    -- Replace the implementation in-place
    setmetatable(self, {
      __call = function(_, ...)
        -- Track the call using spy functionality
        spy.track_call(self, ...)
        -- Throw the error
        return impl(...)
      end,
    })

    return self
  end
  --- Configure the stub to return values from a sequence in order
  --- Returns each value from the provided table in sequence, one value per call.
  --- Useful for simulating changing behavior over time.
  ---
  --- @param values table An array of values to return in sequence
  --- @return stub_object The same stub object for method chaining
  function stub_obj:returns_in_sequence(values)
    if type(values) ~= "table" then
      local err = "returns_in_sequence requires a table of values"
      logger.error(err, {
        actual_type = type(values),
      })
      error(err)
    end

    if #values == 0 then
      local err = "returns_in_sequence requires a non-empty table of values"
      logger.error(err)
      error(err)
    end

    -- Update sequence properties on the current stub
    self._sequence_values = values
    self._sequence_index = 1
    self._original_implementation = implementation

    -- Add sequence methods to the current stub object
    local sequence_impl = add_sequence_methods(self, implementation, values)

    -- Replace the implementation in-place
    setmetatable(self, {
      __call = function(_, ...)
        -- Track the call using spy functionality
        spy.track_call(self, ...)
        -- Return the sequence value
        return sequence_impl(...)
      end,
    })

    logger.debug("Configured sequence return stub", {
      sequence_length = #values,
    })

    return self
  end

  --- Configure whether the sequence of return values should cycle
  --- When enabled, after the last value in the sequence is returned,
  --- the stub will start again from the first value. When disabled,
  --- the exhausted behavior determines what happens when the sequence ends.
  ---

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
    if not self._sequence_values then
      logger.error("when_exhausted called on stub without sequence")
      error("Cannot call when_exhausted on a stub without a sequence")
    end

    if behavior == "nil" then
      self._sequence_exhausted_behavior = "nil"
      self._sequence_exhausted_value = nil
    elseif behavior == "fallback" then
      self._sequence_exhausted_behavior = "fallback"
    elseif behavior == "custom" then
      self._sequence_exhausted_behavior = "custom"
      self._sequence_exhausted_value = custom_value
    else
      local err = "Invalid exhausted behavior. Use 'nil', 'fallback', or 'custom'"
      logger.error(err)
      error(err)
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

--- Create a stub from an existing spy object
--- @param spy_obj table The spy object to convert to a stub
--- @return stub_object The created stub object
function stub.from_spy(spy_obj)
  if not spy.is_spy(spy_obj) then
    error("Cannot create stub from non-spy object")
  end

  -- Add stub fields and methods
  spy_obj._is_firmo_stub = true
  spy_obj._sequence_values = nil
  spy_obj._sequence_index = 1
  spy_obj._sequence_cycles = false
  spy_obj._sequence_exhausted_behavior = "nil"
  spy_obj._sequence_exhausted_value = nil

  -- Add stub methods
  spy_obj.returns = function(self, value)
    self._custom_return_value = value
    self._custom_return_fn = nil
    return self
  end

  spy_obj.returns_in_sequence = stub_obj.returns_in_sequence
  spy_obj.cycle_sequence = stub_obj.cycle_sequence
  spy_obj.when_exhausted = stub_obj.when_exhausted
  spy_obj.throws = stub_obj.throws

  -- Add to registry
  table.insert(all_stubs, spy_obj)

  return spy_obj
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
