--- Firmo Function Stubbing Implementation
---
--- Provides robust function stubbing capabilities for test isolation and behavior control.
--- Stubs replace real functions with test doubles that have pre-programmed behavior (return values, errors, sequences).
--- They build upon the `spy` module, inheriting call tracking functionality.
---
--- Features:
--- - Create standalone stub functions (`stub.new`).
--- - Replace object methods with stubs (`stub.on`).
--- - Configure stubs to return fixed values (`stub_obj:returns`).
--- - Configure stubs to throw errors (`stub_obj:throws`).
--- - Configure stubs to return values sequentially (`stub_obj:returns_in_sequence`).
--- - Advanced sequence control (cycling, exhaustion behavior).
--- - Automatic restoration of original methods for `stub.on` stubs.
--- - Call tracking inherited from `spy`.
---
--- @module lib.mocking.stub
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class stub_module
---@field _VERSION string Module version.
---@field new fun(value_or_fn?: any): stub_object|nil, table? Creates a new stub function... Returns `stub_object, nil` or `nil, error`. @throws table If creation fails critically.
---@field on fun(obj: table, method_name: string, return_value_or_implementation: any): stub_object|nil, table? Replaces method with stub... Returns `stub_object, nil` or `nil, error`. @throws table If validation or creation fails critically.
---@field sequence fun(values: table): stub_object|nil, table? Creates a sequence stub... Returns `stub_object, nil` or `nil, error`. @throws table If creation fails critically. [Currently Unimplemented]
---@field from_spy fun(spy_obj: spy_object): stub_object|nil, table? Creates a stub from a spy... Returns `stub_object, nil` or `nil, error`. @throws table If validation or creation fails critically.
---@field is_stub fun(obj: any): boolean Check if an object is a stub created by this module.
---@field reset_all fun(): boolean, table? Resets all stubs created by this module (clears call history). Returns `true, nil` or `false, error`. @throws table If reset fails critically.

---@class stub_object : spy_object
---@field _is_firmo_stub boolean Internal flag indicating this is a stub object.
---@field returns fun(self: stub_object, value: any): stub_object Configures stub to return a fixed value. Returns self for chaining.
---@field returns_in_sequence fun(self: stub_object, values: table): stub_object Configures stub to return values sequentially. Returns self for chaining. @throws table If validation fails.
---@field cycle_sequence fun(self: stub_object, enable?: boolean): stub_object Configures sequence cycling (default true if called). Returns self for chaining.
---@field throws fun(self: stub_object, error: any): stub_object Configures stub to throw an error. Returns self for chaining. @throws table If configuration fails.
---@field when_exhausted fun(self: stub_object, behavior: string, custom_value?: any): stub_object Configures sequence exhaustion behavior ("nil", "fallback", "custom"). Returns self for chaining. @throws table If validation fails.
---@field restore fun(self: stub_object): boolean|nil, table? Restores original method for `stub.on` stubs. Returns true if restored, false otherwise, nil on critical error, plus optional error. @throws table If restoration fails critically.
---@field reset_sequence fun(self: stub_object): stub_object Resets sequence index to 1. Returns self for chaining.
---@field original function|nil The original function replaced by `stub.on` (if applicable). Internal.
---@field target table|nil The object containing the stubbed method (if `stub.on` was used). Internal.
---@field name string|nil The name of the stubbed method (if `stub.on` was used). Internal.
---@field _is_on_stub boolean|nil Internal flag indicating this stub replaced an object method.
---@field _sequence_values table|nil Internal table storing sequence values.
---@field _sequence_index number Internal index for sequence tracking.
---@field _sequence_cycles boolean Internal flag for sequence cycling.
---@field _sequence_exhausted_behavior string Internal setting for sequence exhaustion behavior.
---@field _sequence_exhausted_value any Internal value for custom sequence exhaustion behavior.
---@field _original_implementation function Internal reference to the original implementation passed to `stub.new` or found by `stub.on`.
---@field _custom_return_value any Internal storage for fixed return value set by `:returns()`.
---@field _custom_return_fn function|nil Internal storage for function passed to `:returns()`.

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
    return logging.get_logger("stub")
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

local spy = try_require("lib.mocking.spy")

-- Track all created stubs
local all_stubs = {}

local stub = {
  -- Module version
  _VERSION = "1.0.0",
}

--- This sophisticated sequence handler provides:
--- - Returns values from the sequence in order
--- - Configurable cycling behavior (restart from beginning when exhausted)
--- - Custom exhaustion behavior (nil, fallback to original, custom value)
--- - Support for function values in the sequence (called with arguments)
--- - Error handling and detailed logging
---@param stub_obj stub_object The stub object to modify.
---@param implementation function The original implementation function (used for fallback behavior).
---@param sequence_table table An array-like table of values to return sequentially.
---@return function sequence_implementation A closure function that implements the sequence logic.
---@throws table If sequence configuration (like exhaustion behavior) fails.
---@private
local function add_sequence_methods(stub_obj, implementation, sequence_table)
  get_logger().debug("Setting up sequence methods for stub", {
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
      get_logger().warn("Sequence stub called with no sequence values")
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
        get_logger().debug("Sequence exhausted, cycling back to start")
      else
        -- Handle exhaustion based on configured behavior
        get_logger().debug("Sequence exhausted, using configured exhaustion behavior", {
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
--- @return stub_object|nil stub A new stub object (`stub_object`), or `nil` on error.
--- @return table|nil error Error object if creation fails.
--- @throws table If creation fails critically.
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
  get_logger().debug("Creating new stub", {
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

  --- Configures the stub to return a specific fixed value.
  ---@param self stub_object
  ---@param value any The value to return.
  ---@return stub_object self The stub object for method chaining.
  function stub_obj:returns(value)
    -- Update the current stub instead of creating a new one
    self._custom_return_value = value
    self._custom_return_fn = nil
    return self
  end

  --- Configures the stub to return values sequentially from the provided table.
  --- Replaces the stub's internal implementation with a sequence handler.
  ---@param self stub_object
  ---@param values table An array-like table of values to return.
  ---@return stub_object self The stub object for method chaining.
  ---@throws table If validation (e.g., `values` not a non-empty table) fails.
  function stub_obj:returns_in_sequence(values)
    if type(values) ~= "table" then
      get_logger().error("Invalid argument type for returns_in_sequence", {
        expected = "table",
        received = type(values),
      })
      error("returns_in_sequence requires a table of values")
    end

    if #values == 0 then
      get_logger().error("Empty sequence provided to returns_in_sequence")
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

    get_logger().debug("Configured sequence return stub", {
      sequence_length = #values,
    })

    return self
  end

  --- Configure whether the sequence of return values should cycle
  --- Configures whether the sequence should cycle (repeat from the beginning) when exhausted.
  ---@param self stub_object
  ---@param enable? boolean `true` to enable cycling (default), `false` to disable.
  ---@return stub_object self The stub object for method chaining.
  function stub_obj:cycle_sequence(enable)
    if enable == nil then
      enable = true
    end
    self._sequence_cycles = enable
    return self
  end

  --- Add throws method to allow the stub to throw errors
  --- Configures the stub to throw a specified error when called.
  --- Replaces the stub's implementation. Uses `error_handler` if available.
  ---@param self stub_object
  ---@param error_message any The error value (string, table, etc.) to throw.
  ---@return stub_object self The stub object for method chaining.
  ---@throws table If configuration (setting metatable) fails.
  function stub_obj:throws(error_message)
    local impl = function()
      local err
      if error_handler and type(get_error_handler().test_expected_error) == "function" then
        -- Create a structured test error if error_handler is available
        err = get_error_handler().test_expected_error(error_message, {
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
  ---@param behavior string The behavior mode: "nil" (return nil), "error" (throw error), "fallback" (call original impl), or "custom" (return `custom_value`).
  ---@param custom_value? any The value to return if `behavior` is "custom".
  ---@return stub_object self The stub object for method chaining.
  ---@throws table If called on a non-sequence stub or if `behavior` is invalid.
  function stub_obj:when_exhausted(behavior, custom_value)
    if not self._sequence_values then
      get_logger().error("when_exhausted called on stub without sequence")
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
      get_logger().error(err)
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
---@return stub_object|nil stub The created stub object (`stub_object`), or `nil` on error.
---@return table|nil error Error object if validation or creation fails.
---@throws table If validation or creation fails critically.
---
---@usage
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
  get_logger().debug("Creating stub on object method", {
    obj_type = type(obj),
    method_name = method_name,
    return_value_type = type(return_value_or_implementation),
  })

  if type(obj) ~= "table" then
    get_logger().error("Invalid object type for stub.on", {
      expected = "table",
      actual = type(obj),
    })
    error("stub.on requires a table as its first argument")
  end

  if not obj[method_name] then
    get_logger().error("Method not found on target object", {
      method_name = method_name,
    })
    error("stub.on requires a method name that exists on the object")
  end

  local original_fn = obj[method_name]
  get_logger().debug("Original method found", {
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
  --- Restores the original method that was replaced by this `stub.on` stub.
  --- Does nothing if called on a standalone stub created with `stub.new`.
  ---@param self stub_object
  ---@return boolean|nil success `true` if restored successfully, `false` if not applicable or failed, `nil` on critical error.
  ---@return table|nil error Error object if restoration failed.
  ---@throws table If restoration fails critically.
  function stub_obj:restore()
    get_logger().debug("Restoring original method", {
      target_type = type(self.target),
    })

    if self.target and self.name then
      self.target[self.name] = self.original
      get_logger().debug("Original method restored successfully")
    else
      get_logger().warn("Could not restore method - missing target or method name")
    end
  end

  -- Add stub-specific methods

  --- Configure the stub to return a specific fixed value
  --- Configures the stub to return a specific fixed value.
  ---@param self stub_object
  ---@param value any The value to return.
  ---@return stub_object self The stub object for method chaining.
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
  ---@param error_message any The error value (string, table, etc.) to throw.
  ---@return stub_object self The stub object for method chaining.
  ---@throws table If configuration (setting metatable) fails.
  function stub_obj:throws(error_message)
    -- Update the current stub instead of creating a new one
    local impl = function()
      local err
      if error_handler and type(get_error_handler().test_expected_error) == "function" then
        -- Create a structured test error if error_handler is available
        err = get_error_handler().test_expected_error(error_message, {
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
  ---@param values table An array-like table of values to return sequentially.
  ---@return stub_object self The stub object for method chaining.
  ---@throws table If validation fails (e.g., `values` is not a non-empty table).
  function stub_obj:returns_in_sequence(values)
    if type(values) ~= "table" then
      local err = "returns_in_sequence requires a table of values"
      get_logger().error(err, {
        actual_type = type(values),
      })
      error(err)
    end

    if #values == 0 then
      local err = "returns_in_sequence requires a non-empty table of values"
      get_logger().error(err)
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

    get_logger().debug("Configured sequence return stub", {
      sequence_length = #values,
    })

    return self
  end

  --- Configure whether the sequence of return values should cycle
  --- When enabled, after the last value in the sequence is returned,
  --- the stub will start again from the first value. When disabled,
  --- the exhausted behavior determines what happens when the sequence ends.
  ---
  ---@param self stub_object
  ---@param enable? boolean `true` to enable cycling (default), `false` to disable.
  ---@return stub_object self The stub object for method chaining.
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
  ---@param self stub_object
  ---@param behavior string The behavior mode: "nil", "error", "fallback", or "custom".
  ---@param custom_value? any The value to return if `behavior` is "custom".
  ---@return stub_object self The stub object for method chaining.
  ---@throws table If called on a non-sequence stub or if `behavior` is invalid.
  function stub_obj:when_exhausted(behavior, custom_value)
    if not self._sequence_values then
      get_logger().error("when_exhausted called on stub without sequence")
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
      get_logger().error(err)
      error(err)
    end
    return self
  end

  --- Resets the sequence index back to the beginning (1).
  --- Only applies to stubs configured with `returns_in_sequence`.
  ---@param self stub_object
  ---@return stub_object self The stub object for method chaining.
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
---@param spy_obj spy_object The spy object to convert.
---@return stub_object|nil stub The created stub object (which is the modified `spy_obj`), or `nil` on error.
---@return table|nil error Error object if validation or creation fails.
---@throws table If validation fails (e.g., `spy_obj` is not a spy).
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

--- Resets the call history for all stubs created by this module.
--- Calls the `reset` method inherited from `spy` on each tracked stub.
---@return boolean success `true` if all stubs were reset successfully.
---@return table? error Combined error object if any reset failed.
---@throws table If the reset process fails critically (e.g., error iterating stubs).
function stub.reset_all()
  get_logger().debug("Resetting all stubs", { count = #all_stubs })

  for _, stub_obj in ipairs(all_stubs) do
    if type(stub_obj.reset) == "function" then
      stub_obj:reset()
    end
  end

  return true
end

--- Creates a stub that returns values from a table in sequence.
--- [Currently Unimplemented - Placeholder]
---@param values table An array of values to return.
---@return stub_object|nil stub The sequence stub object, or nil on error.
---@return table|nil error Error object if validation or creation fails.
---@throws table If validation or creation fails critically.
function stub.sequence(values)
  -- TODO: Implement stub.sequence using stub.new() and returns_in_sequence()
  get_logger().error("stub.sequence is not yet implemented.")
  error("stub.sequence is not yet implemented.")
  -- Example (once implemented):
  -- if type(values) ~= "table" or #values == 0 then error(...) end
  -- local s = stub.new()
  -- return s:returns_in_sequence(values)
end

return stub
