---@diagnostic disable: param-type-mismatch
--- Firmo Mock Object Implementation
---
--- This module provides comprehensive mocking capabilities for replacing real objects
--- with controllable test doubles (mocks). Mocks allow stubbing methods/properties
--- and verifying interactions (expectations).
---
--- Features:
--- - Create mock objects wrapping existing tables (`mock.create`).
--- - Stub methods with fixed values or custom functions (`mock_obj:stub`).
--- - Stub methods to return values sequentially (`mock_obj:stub_in_sequence`).
--- - Stub properties with fixed values (`mock_obj:stub_property`).
--- - Spy on methods without changing behavior (`mock_obj:spy`).
--- - Set expectations for method calls (`mock_obj:expect`).
--- - Verify expectations (`mock_obj:verify`).
--- - Restore individual or all stubbed methods/properties (`mock_obj:restore_stub`, `mock_obj:restore`).
--- - Global restoration of all mocks (`mock.restore_all`, `mock.reset_all`).
--- - Context manager for automatic cleanup (`mock.with_mocks`).
--- - Integration with `lib.mocking.spy` and `lib.mocking.stub`.
--- - Comprehensive error handling via `lib.tools.error_handler`.
---
--- @module lib.mocking.mock
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

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

local spy = try_require("lib.mocking.spy")
local stub = try_require("lib.mocking.stub")

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack_table = table.unpack or unpack

---@class mockable_object
---@field _is_firmo_mock boolean Flag indicating this is a firmo mock object
---@field target table The original object being mocked
---@field _stubs table<string, table> Table of stubbed methods
---@field _originals table<string, function> Table of original methods
---@field _expectations table Table of expected calls
---@field _verify_all_expectations_called boolean Whether to verify all expectations are called
---@field stub fun(self: mockable_object, name: string, implementation_or_value: any): mockable_object|nil, table? Stub a method with a return value or implementation
---@field stub fun(self: mockable_object, name: string, implementation_or_value: any): mockable_object|nil, table? Stub a method. Returns self for chaining, or nil on error, plus optional error object. @throws table If validation or stub creation fails critically.
---@field spy fun(self: mockable_object, name: string): mockable_object|nil, table? Spies on a method without changing behavior. Returns self or nil, error. @throws table If validation or spy creation fails critically.
---@field expect fun(self: mockable_object, name: string): table|nil, table? Creates an expectation for a method call. Returns expectation object or nil, error. @throws table If validation or expectation creation fails critically.
---@field stub_property fun(self: mockable_object, name: string, value: any): mockable_object|nil, table? Stubs a property with a value. Returns self or nil, error. @throws table If validation or stubbing fails critically.
---@field stub_in_sequence fun(self: mockable_object, name: string, sequence_values: table): table|nil, table? Stub a method to return values in sequence. Returns the created sequence stub object for further configuration, or nil on error, plus optional error object. (`stub_object` type defined in `lib.mocking.stub`). @throws table If validation or stub creation fails critically.
---@field restore_stub fun(self: mockable_object, name: string): mockable_object|nil, table? Restore a specific stubbed method/property. Returns self for chaining, or nil on error, plus optional error object. @throws table If restoration fails critically.
---@field restore fun(self: mockable_object): mockable_object|nil, table? Restore all stubbed methods/properties. Returns self for chaining, or nil on error, plus optional error object. @throws table If restoration fails critically.
---@field reset fun(self: mockable_object): mockable_object|nil, table? Resets the mock by restoring all stubs/properties. Alias for `restore`. Returns self or nil, error. @throws table If reset fails critically.
---@field verify fun(self: mockable_object): boolean|nil, table? Verify expectations were met. Returns true if verification passes, false if it fails, or nil on critical error, plus optional error object. @throws table If verification fails critically.

---@class mock The public API of the mock implementation module.
---@field _VERSION string Module version string.
---@field restore_all fun(): boolean, table? Restores all mocks created by this module. Returns `true` on success, `false` on failure, plus optional error object. @throws table If restoration fails critically.
---@field create fun(target: table, options?: {verify_all_expectations_called?: boolean}): mockable_object|nil, table? Creates a mock object wrapping `target`. Returns the mock object, or `nil` on error, plus optional error object. @throws table If validation or creation fails critically.
---@field with_mocks fun(fn: function): any, table? Executes `fn` within a context ensuring automatic mock restoration. Returns the result of `fn`, or `nil` on error, plus optional error object from execution or restoration. @throws table If validation or execution fails critically.
---@field is_mock fun(obj: any): boolean Checks if an object is a firmo mock created by this module.
---@field reset_all fun(): boolean, table? Alias for `restore_all`. Returns `success, error?`. @throws table If reset fails critically.

local mock = {
  -- Module version
  _VERSION = "1.0.0",
}
local _mocks = {}

--- Checks if a value is a mock object created by this module.
---@param obj any The value to check.
---@return boolean is_mock `true` if `obj` is a table with `_is_firmo_mock == true`, `false` otherwise.
---@private
local function is_mock(obj)
  return type(obj) == "table" and obj._is_firmo_mock == true
end

--- Check if an object is a mock created by the mock module
--- Uses the _is_firmo_mock flag to determine if an object was created
--- by the mock.create function. This is useful for functions that need
--- to distinguish between mock objects and regular objects.
---
--- @param obj any The object to check
--- @return boolean is_mock Whether the object is a mock
---
--- @usage
--- -- Check if an object is a mock
--- if mock.is_mock(obj) then
---   print("This is a mock object")
--- else
---   print("This is a regular object")
--- end
function mock.is_mock(obj)
  return is_mock(obj)
end

--- Registers a newly created mock object in the internal `_mocks` list for global cleanup (`restore_all`).
---@param mock_obj table The mock object (`mockable_object`) to register.
---@return table|nil mock_obj The registered mock object if validation passes, otherwise `nil`.
---@return table|nil error Error object if validation or registration fails.
---@throws table If validation or registration fails critically.
---@private
local function register_mock(mock_obj)
  -- Input validation
  if mock_obj == nil then
    local err = get_error_handler().validation_error("Cannot register nil mock object", {
      function_name = "register_mock",
      parameter_name = "mock_obj",
      provided_value = "nil",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if not is_mock(mock_obj) then
    local err = get_error_handler().validation_error("Object is not a valid mock", {
      function_name = "register_mock",
      parameter_name = "mock_obj",
      provided_type = type(mock_obj),
      is_table = type(mock_obj) == "table",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Registering mock for cleanup", {
    target_type = type(mock_obj.target),
    stubs_count = mock_obj._stubs and #mock_obj._stubs or 0,
  })

  -- Use try to safely insert the mock object
  local success, result, err = get_error_handler().try(function()
    table.insert(_mocks, mock_obj)
    return mock_obj
  end)

  if not success then
    local error_obj = get_error_handler().runtime_error(
      "Failed to register mock for cleanup",
      {
        function_name = "register_mock",
        target_type = type(mock_obj.target),
      },
      result -- On failure, result contains the error
    )
    get_logger().error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  return mock_obj
end
--- Restore all mocks to their original state
--- Global cleanup function that restores all mocks created through the mock.create function.
--- This is especially useful for cleaning up mocks created outside of the with_mocks context
--- manager, or as a safety mechanism in test teardown functions.
---
--- @return boolean success Whether all mocks were successfully restored. Returns `false` if any restoration failed.
--- @return table? error Combined error object if restoration failed for one or more mocks, contains details in `error.context.errors`.
--- @throws table If the restoration process itself fails critically (e.g., error iterating mocks).
---
--- @usage
--- -- Create some mocks in different scopes/functions
--- local mock1 = mock.create(obj1)
--- local mock2 = mock.create(obj2)
---
--- -- Later, cleanup everything at once
--- local success, err = mock.restore_all()
--- if not success then
---   print("Warning: Some mocks could not be restored: " .. err.message)
--- end
function mock.restore_all()
  get_logger().debug("Restoring all registered mocks", {
    count = #_mocks,
  })

  local errors = {}

  local errors = {}

  for i, mock_obj in ipairs(_mocks) do
    get_logger().debug("Restoring mock", {
      index = i,
      target_type = type(mock_obj.target),
    })

    -- Use protected call to ensure one failure doesn't prevent other mocks from being restored
    local success, result, err = get_error_handler().try(function()
      if type(mock_obj) == "table" and type(mock_obj.restore) == "function" then
        mock_obj:restore()
        return true
      else
        return false,
          get_error_handler().validation_error("Invalid mock object (missing restore method)", {
            function_name = "mock.restore_all",
            mock_index = i,
            mock_type = type(mock_obj),
            has_restore = type(mock_obj) == "table" and type(mock_obj.restore) == "function",
          })
      end
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to restore mock",
        {
          function_name = "mock.restore_all",
          mock_index = i,
          target_type = type(mock_obj) == "table" and type(mock_obj.target) or "unknown",
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      table.insert(errors, error_obj)
    elseif result == false then
      -- The try function succeeded but the restore validation failed
      table.insert(errors, err)
    end
  end

  -- Reset the mocks registry even if there were errors
  _mocks = {}

  -- If there were errors, report them but continue
  if #errors > 0 then
    get_logger().warn("Completed mock restoration with errors", {
      error_count = #errors,
    })

    -- Return a structured error summary
    return false,
      get_error_handler().runtime_error("Completed mock restoration with " .. #errors .. " errors", {
        function_name = "mock.restore_all",
        error_count = #errors,
        errors = errors,
      })
  end

  get_logger().debug("All mocks restored successfully")
  return true
end

--- Reset all mocks to their original state
--- Global cleanup function that resets all mocks created through the mock.create function.
--- This is an alias for restore_all() with a more intuitive name for users coming from other
--- mocking frameworks.
---
--- @return boolean success Whether all mocks were successfully reset.
--- @return table? error Error object if reset failed (same return as `restore_all`).
--- @throws table If reset fails critically (same throws as `restore_all`).
---
--- @usage
--- -- Create some mocks in different scopes/functions
--- local mock1 = mock.create(obj1)
--- local mock2 = mock.create(obj2)
---
--- -- Later, reset everything at once
--- local success, err = mock.reset_all()
--- if not success then
---   print("Warning: Some mocks could not be reset: " .. err.message)
--- end
function mock.reset_all()
  return mock.restore_all()
end

--- Converts a Lua value to a string representation suitable for error messages.
--- Handles tables recursively up to `max_depth` and recognizes Firmo matcher objects.
---@param value any The value to convert.
---@param max_depth? number Maximum recursion depth for tables (default: 3).
---@return string representation A string representation of the value.
---@private
local function value_to_string(value, max_depth)
  -- Input validation with fallback
  if max_depth ~= nil and type(max_depth) ~= "number" then
    get_logger().warn("Invalid max_depth parameter type", {
      function_name = "value_to_string",
      parameter_name = "max_depth",
      provided_type = type(max_depth),
      provided_value = tostring(max_depth),
    })
    max_depth = 3 -- Default fallback
  end

  max_depth = max_depth or 3
  if max_depth < 0 then
    return "..."
  end

  -- Use protected call to catch errors during string conversion
  local success, result = get_error_handler().try(function()
    if value == nil then
      return "nil"
    elseif type(value) == "string" then
      return '"' .. value .. '"'
    elseif type(value) == "table" then
      if max_depth == 0 then
        return "{...}"
      end

      local parts = {}
      for k, v in pairs(value) do
        -- Check for special metatable-based formatting
        if k == "_is_matcher" and v == true and value.description then
          return value.description
        end

        local key_str = type(k) == "string" and k or "[" .. tostring(k) .. "]"
        table.insert(parts, key_str .. " = " .. value_to_string(v, max_depth - 1))
      end
      return "{ " .. table.concat(parts, ", ") .. " }"
    elseif type(value) == "function" then
      return "function(...)"
    else
      return tostring(value)
    end
  end)

  if not success then
    get_logger().warn("Error during string conversion", {
      function_name = "value_to_string",
      value_type = type(value),
      error = get_error_handler().format_error(result),
    })
    return "[Error during conversion: " .. get_error_handler().format_error(result) .. "]"
  end

  return result
end

--- Formats a table of function arguments into a comma-separated string for display.
--- Uses `value_to_string` for individual argument representation.
---@param args table|nil The array-like table of arguments. Handles `nil` input.
---@return string formatted_args String representation like `"arg1", 2, { ... }`. Returns `"nil"` if input is nil.
---@private
local function format_args(args)
  -- Input validation with fallback
  if args == nil then
    get_logger().warn("Nil args parameter", {
      function_name = "format_args",
    })
    return "nil"
  end

  if type(args) ~= "table" then
    get_logger().warn("Invalid args parameter type", {
      function_name = "format_args",
      parameter_name = "args",
      provided_type = type(args),
      provided_value = tostring(args),
    })
    return tostring(args)
  end

  -- Use protected call to catch errors during args formatting
  local success, result = get_error_handler().try(function()
    local parts = {}
    for i, arg in ipairs(args) do
      if type(arg) == "table" and arg._is_matcher then
        table.insert(parts, arg.description)
      else
        table.insert(parts, value_to_string(arg))
      end
    end
    return table.concat(parts, ", ")
  end)

  if not success then
    get_logger().warn("Error during args formatting", {
      function_name = "format_args",
      args_count = #args,
      error = get_error_handler().format_error(result),
    })
    return "[Error during args formatting: " .. get_error_handler().format_error(result) .. "]"
  end

  return result
end

--- Create a mock object with verifiable behavior
--- Creates a mock wrapper around an existing object that lets you stub methods
--- and verify that they were called. This is the primary function for setting up mocks.
---
--- @param target table The object to create a mock of
--- @param options? {verify_all_expectations_called?: boolean} Optional configuration
--- @return mockable_object|nil mock_obj The created mock object (`mockable_object`), or `nil` on error.
--- @return table|nil error Error object if creation failed.
--- @throws table If validation or creation fails critically.
---
--- @usage
--- -- Create a basic mock
--- local file_system = {
---   read_file = function(path) return io.open(path, "r"):read("*a") end,
---   write_file = function(path, content) local f = io.open(path, "w"); f:write(content); f:close() end
--- }
--- local mock_fs = mock.create(file_system)
---
--- -- Create a mock with custom options
--- local mock_fs_no_verify = mock.create(file_system, { verify_all_expectations_called = false })
function mock.create(target, options)
  -- Input validation
  if target == nil then
    local err = get_error_handler().validation_error("Cannot create mock with nil target", {
      function_name = "mock.create",
      parameter_name = "target",
      provided_value = "nil",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if options ~= nil and type(options) ~= "table" then
    local err = get_error_handler().validation_error("Options must be a table or nil", {
      function_name = "mock.create",
      parameter_name = "options",
      provided_type = type(options),
      provided_value = tostring(options),
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Creating mock object", {
    target_type = type(target),
    options = options or {},
  })

  options = options or {}

  -- Use protected call to create the mock object
  local success, mock_obj, err = get_error_handler().try(function()
    local obj = {
      _is_firmo_mock = true,
      target = target,
      _stubs = {},
      _originals = {},
      _spies = {},
      _expectations = {},
      _properties = {}, -- Track stubbed properties
      _verify_all_expectations_called = options.verify_all_expectations_called ~= false,
    }

    get_logger().debug("Mock object initialized", {
      verify_all_expectations = obj._verify_all_expectations_called,
    })

    return obj
  end)

  if success then
    -- Automatically spy on all methods in target object
    local auto_spy_success, auto_spy_result = get_error_handler().try(function()
      local method_count = 0

      for name, value in pairs(target) do
        if type(value) == "function" then
          -- Create spy directly using spy.on instead of mock_obj:spy
          local spy_obj = spy.on(target, name)
          if spy_obj then
            mock_obj._spies[name] = spy_obj
            method_count = method_count + 1
          end
        end
      end
      return method_count
    end)

    if auto_spy_success then
      get_logger().debug("Auto-spied on methods", {
        function_name = "mock.create",
        method_count = auto_spy_result,
      })
    else
      get_logger().warn("Error during automatic method spying", {
        function_name = "mock.create",
        error = get_error_handler().format_error(auto_spy_result),
      })
    end
  end

  if not success then
    local error_obj = get_error_handler().runtime_error(
      "Failed to create mock object",
      {
        function_name = "mock.create",
        target_type = type(target),
        options_provided = options ~= nil,
      },
      mock_obj -- On failure, mock_obj contains the error
    )
    get_logger().error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  --- Stub a function with a return value or implementation
  --- Replaces a method on the mocked object with a stub that returns a fixed value
  --- or executes a custom implementation. The original method is preserved and can
  --- be restored later.
  ---
  --- @param name string The method name to stub
  --- @param implementation_or_value any The implementation function or return value
  --- @return mockable_object|nil self Returns the mock object (`self`) for chaining, or `nil` on error.
  --- @return table|nil error Error object if stubbing failed.
  --- @throws table If validation or stub creation fails critically.
  ---
  --- @usage
  --- -- Mock a logger to capture calls without side effects
  --- local mock_logger = mock.create(logger)
  ---
  --- -- Stub with a simple value
  --- mock_logger:stub("is_debug_enabled", true)
  ---
  --- -- Stub with a custom implementation
  --- mock_logger:stub("info", function(message)
  ---   print("STUBBED INFO: " .. message)
  --- end)
  ---
  --- -- Chain multiple stubs
  --- mock_logger:stub("error", function() end)
  ---   :stub("warn", function() end)
  function mock_obj:stub(name, implementation_or_value)
    -- Input validation
    if name == nil then
      local err = get_error_handler().validation_error("Method name cannot be nil", {
        function_name = "mock_obj:stub",
        parameter_name = "name",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Stubbing method", {
      method_name = name,
      value_type = type(implementation_or_value),
    })

    -- Validate method existence
    if self.target[name] == nil then
      local err = get_error_handler().validation_error("Cannot stub non-existent method", {
        function_name = "mock_obj:stub",
        parameter_name = "name",
        method_name = name,
        target_type = type(self.target),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Saving original method", {
      method_name = name,
      original_type = type(self.target[name]),
    })

    -- Use protected call to save the original method
    get_logger().debug("Saving original method", {
      method_name = name,
      original_type = type(self.target[name]),
    })

    -- Use protected call to save the original method
    local success, result, err = get_error_handler().try(function()
      -- Only save if we haven't already stored this original
      if self._originals[name] == nil then
        self._originals[name] = self.target[name]
        get_logger().debug("Original method saved", {
          method_name = name,
          original_type = type(self._originals[name]),
        })
      else
        get_logger().debug("Original method already saved", {
          method_name = name,
        })
      end
      return true
    end)

    -- Create the stub with error handling
    local stub_obj, stub_err

    if type(implementation_or_value) == "function" then
      success, stub_obj, err = get_error_handler().try(function()
        return stub.on(self.target, name, function(...)
          local original_args = { ... }

          -- Always try with original arguments first - no special handling for nil
          local status, result = pcall(function()
            return implementation_or_value(unpack_table(original_args))
          end)

          -- Only if we get a concatenation error, retry with nil converted to empty string
          if not status and string.find(result or "", "attempt to concatenate") then
            -- Create a new table with nil values replaced by empty strings
            local safe_args = {}
            for i = 1, #original_args do
              safe_args[i] = original_args[i] == nil and "" or original_args[i]
            end
            return implementation_or_value(unpack_table(safe_args))
          elseif not status then
            -- For other errors, re-raise them
            error(result, 2)
          else
            -- If the call succeeded (even with nil args), return the result
            return result
          end
        end)
      end)
    else
      get_logger().debug("Creating stub with return value", {
        return_value_type = type(implementation_or_value),
      })
      success, stub_obj, err = get_error_handler().try(function()
        -- For value stubs, ignore all arguments and just return the fixed value
        return stub.on(self.target, name, function()
          return implementation_or_value
        end)
      end)
    end
    if not success then
      -- Restore the original method since stub creation failed
      local restore_success, _ = get_error_handler().try(function()
        self.target[name] = self._originals[name]
        self._originals[name] = nil
        return true
      end)

      if not restore_success then
        get_logger().warn("Failed to restore original method after stub creation failure", {
          method_name = name,
        })
      end

      local error_obj = get_error_handler().runtime_error(
        "Failed to create stub",
        {
          function_name = "mock_obj:stub",
          method_name = name,
          implementation_type = type(implementation_or_value),
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Store the stub with error handling
    success, result, err = get_error_handler().try(function()
      self._stubs[name] = stub_obj
      return true
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to store stub in mock object",
        {
          function_name = "mock_obj:stub",
          method_name = name,
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    get_logger().debug("Method successfully stubbed", {
      method_name = name,
    })
    return self
  end

  --- Spy on a method of the target without changing its behavior
  --- Creates a spy on a method of the target object that tracks calls without
  --- modifying the original behavior. This is useful for verifying a method is
  --- called with the expected arguments while allowing it to perform its normal function.
  ---
  --- @param name string The method name to spy on
  --- @return mockable_object|nil self Returns the mock object (`self`) for chaining, or `nil` on error.
  --- @return table|nil error Error object if spying failed.
  --- @throws table If validation or spy creation fails critically.
  ---
  --- @usage
  --- -- Create a mock and spy on a method
  --- local mock_obj = mock.create(api)
  --- mock_obj:spy("fetch_data")
  ---
  --- -- Call the method through the original object
  --- local result = api.fetch_data("some_id")
  ---
  --- -- Original behavior is preserved
  --- expect(result).to.equal("expected_data")
  ---
  --- -- But calls are tracked
  --- local method_spy = mock_obj._spies.fetch_data
  --- expect(method_spy.call_count).to.equal(1)
  --- expect(method_spy.calls[1].args[2]).to.equal("some_id")
  function mock_obj:spy(name)
    -- Input validation
    if name == nil then
      local err = get_error_handler().validation_error("Method name cannot be nil", {
        function_name = "mock_obj:spy",
        parameter_name = "name",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = get_error_handler().validation_error("Method name must be a string", {
        function_name = "mock_obj:spy",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Spying on method", {
      method_name = name,
    })

    -- Validate method existence
    if self.target[name] == nil then
      local err = get_error_handler().validation_error("Cannot spy on non-existent method", {
        function_name = "mock_obj:spy",
        parameter_name = "name",
        method_name = name,
        target_type = type(self.target),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    -- Create the spy with error handling
    local success, spy_obj, err = get_error_handler().try(function()
      return spy.on(self.target, name)
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to create spy",
        {
          function_name = "mock_obj:spy",
          method_name = name,
          target_type = type(self.target),
        },
        spy_obj -- On failure, spy_obj contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Store the spy with error handling
    success, result, err = get_error_handler().try(function()
      self._spies[name] = spy_obj
      return true
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to store spy in mock object",
        {
          function_name = "mock_obj:spy",
          method_name = name,
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    get_logger().debug("Method successfully spied on", {
      method_name = name,
    })
    return self
  end

  --- Create an expectation for a method call
  --- Sets up an expectation that a method will be called with specific
  --- arguments. This is useful for verifying that methods are called
  --- in the expected way during tests.
  ---
  --- @param name string The method name to expect
  --- @return table expectation A chainable expectation object (internal structure with methods like `with`, `to.be.called`). Returns `nil` on error.
  --- @return table|nil error Error object if expectation creation failed.
  --- @throws table If validation or expectation creation fails critically.
  ---
  --- @usage
  --- -- Create a mock and expect a method to be called
  --- local mock_obj = mock.create(api)
  --- mock_obj:expect("fetch_data").to.be.called(1)
  ---
  --- -- More complex expectation with arguments
  --- mock_obj:expect("fetch_data").with("user123").to.be.called.at_least(1)
  function mock_obj:expect(name)
    -- Input validation
    if name == nil then
      local err = get_error_handler().validation_error("Method name cannot be nil", {
        function_name = "mock_obj:expect",
        parameter_name = "name",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = get_error_handler().validation_error("Method name must be a string", {
        function_name = "mock_obj:expect",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    -- Validate method existence
    if self.target[name] == nil then
      local err = get_error_handler().validation_error("Cannot expect non-existent method", {
        function_name = "mock_obj:expect",
        parameter_name = "name",
        method_name = name,
        target_type = type(self.target),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Creating expectation for method", {
      method_name = name,
    })

    -- Create a new expectation with error handling
    local success, exp_interface, err = get_error_handler().try(function()
      -- Create a new expectation object
      local expectation = {
        method_name = name,
        call_count = 0,
        min_calls = 0,
        max_calls = nil, -- nil means no maximum
        exact_calls = nil, -- nil means no exact requirement
        never_called = false,
        args_matcher = nil, -- nil means any args
        with_args = nil, -- specific args to match
      }

      -- Add a spy to track calls to the method if it doesn't exist
      if not self._spies[name] then
        self:spy(name)
      end

      -- Create the chainable interface first, before using it in method definitions
      local exp_interface = {}

      -- Define convenience function to make sure all methods return the chainable interface
      local function chain_return(fn)
        return function(...)
          fn(...)
          return exp_interface
        end
      end

      -- Create called object with proper metatable for both direct calls and property access
      local called_obj = {}
      setmetatable(called_obj, {
        __call = function(_, count)
          expectation.exact_calls = count or 1
          return exp_interface
        end,
      })

      -- Add methods to called
      called_obj.at_least = function(count)
        expectation.min_calls = count or 1
        expectation.exact_calls = nil
        return exp_interface
      end

      called_obj.at_most = function(count)
        expectation.max_calls = count or 1
        expectation.exact_calls = nil
        return exp_interface
      end

      called_obj.times = function(count)
        expectation.exact_calls = count
        return exp_interface
      end

      -- Build the full chaining structure
      exp_interface.to = {
        be = {
          called = called_obj,
          truthy = function()
            return exp_interface
          end,
        },
        never = {
          be = {
            called = function()
              expectation.never_called = true
              return exp_interface
            end,
          },
        },
      }

      exp_interface.with = function(...)
        local args = { ... }
        if type(args[1]) == "function" then
          -- Custom matcher function
          expectation.args_matcher = args[1]
        else
          -- Specific arguments to match
          expectation.with_args = args
        end
        return exp_interface
      end

      -- Store the expectation
      if not self._expectations[name] then
        self._expectations[name] = {}
      end
      table.insert(self._expectations[name], expectation)

      return exp_interface
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to create expectation",
        {
          function_name = "mock_obj:expect",
          method_name = name,
          target_type = type(self.target),
        },
        exp_interface -- On failure, exp_interface contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    return exp_interface
  end -- Close the expect function that started at line 740

  --- Stub a property with a specific value
  --- Replaces a property on the mocked object with a stubbed value.
  --- The original value is preserved and can be restored later.
  ---
  --- @param name string The property name to stub
  --- @param value any The value to replace the property with
  --- @return mockable_object|nil self Returns the mock object (`self`) for chaining, or `nil` on error.
  --- @return table|nil error Error object if stubbing failed.
  --- @throws table If validation or stubbing fails critically.
  ---
  --- @usage
  --- -- Create a mock and stub a property
  --- local mock_obj = mock.create(config)
  --- mock_obj:stub_property("debug_mode", true)
  ---
  --- -- Now accessing config.debug_mode will return true
  --- assert(config.debug_mode == true)
  ---
  --- -- Chain multiple property stubs
  --- mock_obj:stub_property("version", "1.0.0")
  ---   :stub_property("api_url", "https://api.example.com")
  function mock_obj:stub_property(name, value)
    -- Input validation
    if name == nil then
      local err = get_error_handler().validation_error("Property name cannot be nil", {
        function_name = "mock_obj:stub_property",
        parameter_name = "name",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = get_error_handler().validation_error("Property name must be a string", {
        function_name = "mock_obj:stub_property",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Stubbing property", {
      property_name = name,
      value_type = type(value),
    })

    -- Validate property existence
    if self.target[name] == nil then
      local err = get_error_handler().validation_error("Cannot stub non-existent property", {
        function_name = "mock_obj:stub_property",
        parameter_name = "name",
        property_name = name,
        target_type = type(self.target),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    -- Use protected call to save the original property and set new value
    local success, result, err = get_error_handler().try(function()
      -- Save original value
      self._properties[name] = self.target[name]

      -- Set new value
      self.target[name] = value
      return true
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to stub property",
        {
          function_name = "mock_obj:stub_property",
          property_name = name,
          value_type = type(value),
          target_type = type(self.target),
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    get_logger().debug("Property successfully stubbed", {
      property_name = name,
    })
    return self
  end

  --- Stub a function with sequential return values
  --- Replaces a method on the mocked object with a stub that returns values
  --- from a sequence, one value per call. This is useful for simulating methods
  --- that return different values over time, like API calls or stateful operations.
  ---
  --- @param name string The method name to stub
  --- @param sequence_values table Array of values to return in sequence
  --- @return table|nil stub The created stub object (from `lib.mocking.stub`) for further sequence configuration (e.g., `:cycle_sequence`), or `nil` on error.
  --- @return table|nil error Error object if stubbing failed.
  --- @throws table If validation or stub creation/configuration fails critically.
  ---
  --- @usage
  --- -- Create a mock with a sequence of return values
  --- local mock_db = mock.create(database)
  --- local query_stub = mock_db:stub_in_sequence("query", {
  ---   { id = 1, name = "First" },
  ---   { id = 2, name = "Second" },
  ---   { id = 3, name = "Third" }
  --- })
  ---
  --- -- Configure sequence behavior
  --- query_stub:cycle_sequence(true)  -- Restart from beginning when exhausted
  --- -- OR
  --- query_stub:when_exhausted("custom", { error = "No more results" })
  function mock_obj:stub_in_sequence(name, sequence_values)
    -- Input validation
    if name == nil then
      local err = get_error_handler().validation_error("Method name cannot be nil", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "name",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = get_error_handler().validation_error("Method name must be a string", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    -- Validate method existence
    if self.target[name] == nil then
      local err = get_error_handler().validation_error("Cannot stub non-existent method", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "name",
        method_name = name,
        target_type = type(self.target),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    -- Validate sequence values
    if sequence_values == nil then
      local err = get_error_handler().validation_error("Sequence values cannot be nil", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "sequence_values",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if type(sequence_values) ~= "table" then
      local err = get_error_handler().validation_error("stub_in_sequence requires a table of values", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "sequence_values",
        provided_type = type(sequence_values),
        provided_value = tostring(sequence_values),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Creating sequence stub", {
      method_name = name,
      sequence_length = #sequence_values,
    })

    -- Use protected call to save the original method
    local success, result, err = get_error_handler().try(function()
      self._originals[name] = self.target[name]
      return true
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to save original method",
        {
          function_name = "mock_obj:stub_in_sequence",
          method_name = name,
          original_type = type(self.target[name]),
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Create the stub with error handling
    local stub_obj

    -- First create the basic stub
    success, stub_obj, err = get_error_handler().try(function()
      return stub.on(self.target, name, function() end)
    end)

    if not success then
      -- Restore the original method since stub creation failed
      local restore_success, _ = get_error_handler().try(function()
        self.target[name] = self._originals[name]
        self._originals[name] = nil
        return true
      end)

      if not restore_success then
        get_logger().warn("Failed to restore original method after stub creation failure", {
          method_name = name,
        })
      end

      local error_obj = get_error_handler().runtime_error(
        "Failed to create sequence stub",
        {
          function_name = "mock_obj:stub_in_sequence",
          method_name = name,
          sequence_length = #sequence_values,
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Now configure the sequence
    success, result, err = get_error_handler().try(function()
      return stub_obj:returns_in_sequence(sequence_values)
    end)

    if not success then
      -- Restore the original method since sequence configuration failed
      local restore_success, _ = get_error_handler().try(function()
        self.target[name] = self._originals[name]
        self._originals[name] = nil
        return true
      end)

      if not restore_success then
        get_logger().warn("Failed to restore original method after sequence configuration failure", {
          method_name = name,
        })
      end

      local error_obj = get_error_handler().runtime_error(
        "Failed to configure sequence returns",
        {
          function_name = "mock_obj:stub_in_sequence",
          method_name = name,
          sequence_length = #sequence_values,
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Update stub_obj with the configured sequence stub
    stub_obj = result

    -- Store the stub with error handling
    success, result, err = get_error_handler().try(function()
      self._stubs[name] = stub_obj
      return true
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to store sequence stub in mock object",
        {
          function_name = "mock_obj:stub_in_sequence",
          method_name = name,
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    get_logger().debug("Method successfully stubbed with sequence values", {
      method_name = name,
      sequence_length = #sequence_values,
    })

    return stub_obj -- Return the stub for method chaining
  end

  --- Restore a specific stubbed method to its original implementation
  --- Returns a single method to its original behavior, removing the stub. This is useful
  --- when you want to keep some stubs active while restoring others. After restoration,
  --- calls to the method will execute the original implementation.
  ---
  --- @param name string The method name to restore
  --- @return mockable_object|nil self Returns the mock object (`self`) for chaining, or `nil` on error.
  --- @return table|nil error Error object if restoration failed.
  --- @throws table If restoration fails critically.
  ---
  --- @usage
  --- -- Set up multiple stubs
  --- local mock_fs = mock.create(file_system)
  --- mock_fs:stub("read_file", function() return "mock content" end)
  --- mock_fs:stub("write_file", function() return true end)
  ---
  --- -- Later, restore just one method
  --- mock_fs:restore_stub("read_file")  -- Only read_file is restored
  --- -- write_file is still stubbed
  function mock_obj:restore_stub(name)
    -- Input validation
    if name == nil then
      local err = get_error_handler().validation_error("Method name cannot be nil", {
        function_name = "mock_obj:restore_stub",
        parameter_name = "name",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = get_error_handler().validation_error("Method name must be a string", {
        function_name = "mock_obj:restore_stub",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Attempting to restore stub", {
      method_name = name,
      has_original = self._originals[name] ~= nil,
    })

    if not self._originals[name] then
      get_logger().warn("No original method found to restore", {
        function_name = "mock_obj:restore_stub",
        method_name = name,
      })
      return self
    end

    -- Use protected call to restore the original method
    local success, result, err = get_error_handler().try(function()
      -- Keep a reference to the original method
      local original = self._originals[name]

      get_logger().debug("Restoring original method", {
        method_name = name,
        original_type = type(original),
        is_nil = original == nil,
      })

      -- Restore the original method
      self.target[name] = original

      -- Remove the stub reference
      if self._stubs[name] then
        self._stubs[name] = nil
      end

      -- Remove the original reference
      self._originals[name] = nil

      -- Remove any spy reference
      if self._spies[name] then
        self._spies[name] = nil
      end

      return true
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to restore original method",
        {
          function_name = "mock_obj:restore_stub",
          method_name = name,
          target_type = type(self.target),
          original_type = type(self._originals[name]),
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    if not success then
      get_logger().warn("Failed to clean up references after restoration", {
        method_name = name,
        error = get_error_handler().format_error(result),
      })
      -- We continue despite this error because the restoration was successful
    end

    get_logger().debug("Successfully restored original method", {
      method_name = name,
    })
    return self
  end

  --- Reset a mock object, restoring original methods and clearing all tracking
  --- Reset the mock to its initial state, removing all stubs and spies.
  --- This is a convenience method equivalent to calling restore() but with a
  --- more standard naming convention.
  ---
  ---
  --- @return mockable_object|nil self Returns the mock object (`self`) for chaining, or `nil` on error.
  --- @return table|nil error Error object if reset failed (inherits from `restore`).
  --- @throws table If reset fails critically (inherits from `restore`).
  ---
  --- @usage
  --- -- Create a mock with stubs and expectations
  --- local mock_obj = mock.create(target)
  --- mock_obj:stub("method", function() end)
  --- mock_obj:expect("other").to.be.called(1)
  ---
  --- -- Reset the mock to clear all stubs and expectations
  --- mock_obj:reset()
  function mock_obj:reset()
    get_logger().debug("Resetting mock object to original state")
    return self:restore()
  end

  --- Restore all stubs for this mock to their original implementations
  --- Completely restores the original object by replacing all stubbed methods
  --- with their original implementations. After calling this method, the mock
  --- object becomes a simple wrapper with no active stubs.
  ---
  --- @return mockable_object|nil self Returns the mock object (`self`) for chaining, or `nil` if restoration encounters critical errors.
  --- @return table|nil error Combined error object if restoration of one or more methods failed. Contains details in `error.context.errors`.
  --- @throws table If the restoration process itself fails critically (e.g., error iterating originals).
  ---
  --- @usage
  --- local mock_fs = mock.create(file_system)
  --- mock_fs:stub("read_file", function() return "mock content" end)
  --- mock_fs:stub("write_file", function() return true end)
  ---
  --- -- Test code using the mocks...
  ---
  --- -- Completely restore the original file_system
  --- mock_fs:restore()
  --- -- Completely restore the original file_system
  --- mock_fs:restore()
  function mock_obj:restore()
    get_logger().debug("Restoring all stubs for mock", {
      stub_count = self._stubs and #self._stubs or 0,
      original_count = self._originals and #self._originals or 0,
    })

    local errors = {}

    -- Log the originals for debugging
    for name, original in pairs(self._originals) do
      get_logger().debug("Found original to restore", {
        method_name = name,
        original_type = type(original),
        is_nil = original == nil,
      })
    end

    -- Use protected iteration for safety
    local success, originals = get_error_handler().try(function()
      -- Make a copy of the keys to allow modification during iteration
      local keys = {}
      for name, _ in pairs(self._originals) do
        table.insert(keys, name)
      end
      return keys
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to create list of methods to restore",
        {
          function_name = "mock_obj:restore",
          target_type = type(self.target),
        },
        originals -- On failure, originals contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Restore each method individually
    for _, name in ipairs(originals) do
      get_logger().debug("Restoring original method", {
        method_name = name,
        target_type = type(self.target),
      })

      -- Use protected call to restore the original method
      -- Use protected call to restore the original method
      local restore_success, result, err = get_error_handler().try(function()
        if self._originals[name] ~= nil then
          -- Store a reference to the original function first
          local original_fn = self._originals[name]

          get_logger().debug("Restoring original method", {
            method_name = name,
            original_type = type(original_fn),
            is_nil = original_fn == nil,
          })

          -- Make sure it's actually a function
          if type(original_fn) ~= "function" then
            get_logger().warn("Original value is not a function", {
              method_name = name,
              original_type = type(original_fn),
            })
            -- Just restore the original directly if it's not a function
            self.target[name] = original_fn
            return true
          end

          -- Create a safety wrapper that handles nil arguments consistently
          local safe_original = function(...)
            local args = { ... }

            -- Normalize args first - any explicit nil values are converted to empty strings
            local normalized_args = {}
            for i = 1, 10 do -- Support up to 10 arguments
              -- This handles both missing arguments and explicit nil values
              normalized_args[i] = args[i] == nil and "" or args[i]
            end

            -- First try with normalized arguments to prevent concatenation errors
            local status, result = pcall(function()
              return original_fn(unpack_table(normalized_args, 1, 10))
            end)

            if not status then
              -- If there was still an error, try with original arguments
              -- This preserves original errors that weren't concatenation-related
              local orig_status, orig_result = pcall(function()
                return original_fn(unpack_table(args))
              end)

              if not orig_status then
                -- Only convert nil to empty string if it's a concatenation error
                if string.find(orig_result or "", "attempt to concatenate") then
                  -- Already tried normalized args, use that result
                  error(result, 2)
                else
                  -- For other errors, preserve the original error
                  error(orig_result, 2)
                end
              else
                -- Original args worked despite our normalization attempt failing
                return orig_result
              end
            else
              -- Normalized args worked fine
              return result
            end
          end -- Close the safe_original function
          -- Replace with the safety-wrapped original method
          self.target[name] = safe_original
          return true
        end
      end) -- Close the try function

      if not restore_success then
        local error_obj = get_error_handler().runtime_error(
          "Failed to restore mock",
          {
            function_name = "mock_obj:restore",
            method_name = name,
            target_type = type(self.target),
          },
          result -- On failure, result contains the error
        )
        get_logger().error(error_obj.message, error_obj.context)
        table.insert(errors, error_obj)
      end
    end
    -- Clean up all references with error handling
    -- Clean up all references with error handling
    ---@diagnostic disable-next-line: lowercase-global, unused-local
    success, result, err = get_error_handler().try(function()
      -- Clear our tracking collections now that everything is restored
      self._stubs = {}
      self._originals = {}
      self._spies = {}
      -- Also restore any stubbed properties
      for prop_name, original_value in pairs(self._properties or {}) do
        self.target[prop_name] = original_value
      end
      self._properties = {}
      return true
    end)

    if #errors > 0 then
      return self, errors
    end

    return self
  end -- Close the restore function

  --- Verify all expected stubs were called
  --- Checks that all stubbed methods were called at least once. This is useful
  --- for verifying that expected behaviors occurred during a test. By default,
  --- all stubbed methods are expected to be called, but this can be disabled with
  --- the verify_all_expectations_called option when creating the mock.
  ---
  --- @return boolean|nil success `true` if verification passes, `false` if expectations were not met, `nil` on critical error during verification.
  --- @return table|nil error Error object if verification failed (either unmet expectations or critical error). `error.context.failures` lists unmet expectations.
  --- @throws table If the verification process itself fails critically.
  ---
  --- @usage
  --- -- Create a mock and stub some methods
  --- local mock_logger = mock.create(logger)
  --- mock_logger:stub("info", function() end)
  --- mock_logger:stub("error", function() end)
  ---
  --- -- After test code runs, verify expectations
  --- local success, err = mock_logger:verify()
  --- if not success then
  ---   print("Verification failed: " .. err.message)
  --- end
  function mock_obj:verify()
    get_logger().debug("Verifying mock expectations", {
      stub_count = self._stubs and #self._stubs or 0,
      verify_all = self._verify_all_expectations_called,
    })

    local failures = {}

    -- Use protected verification for safety
    local success, result, err = get_error_handler().try(function()
      if self._verify_all_expectations_called then
        for name, stub in pairs(self._stubs) do
          get_logger().debug("Checking if method was called", {
            method_name = name,
            was_called = stub and stub.called,
          })

          if not stub or not stub.called then
            -- Check if we're in test mode and should suppress logging
            if
              not (
                error_handler
                and type(get_error_handler().is_suppressing_test_logs) == "function"
                and get_error_handler().is_suppressing_test_logs()
              )
            then
              -- For verification failures, use warning level since this is potentially
              -- useful information in tests that are checking verification behavior
              get_logger().warn("Expected method was not called", {
                method_name = name,
              })
            else
              -- In test mode, only log at debug level
              get_logger().debug("Expected method was not called (test mode)", {
                method_name = name,
              })
            end
            table.insert(failures, "Expected '" .. name .. "' to be called, but it was not")
          end
        end
      end

      return failures
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Error during mock verification",
        {
          function_name = "mock_obj:verify",
          verify_all = self._verify_all_expectations_called,
          stub_count = self._stubs and #self._stubs or 0,
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Check for verification failures
    if #failures > 0 then
      local error_message = "Mock verification failed:\n  " .. table.concat(failures, "\n  ")

      -- Check if we're in test mode and should suppress logging
      if
        not (
          error_handler
          and type(get_error_handler().is_suppressing_test_logs) == "function"
          and get_error_handler().is_suppressing_test_logs()
        )
      then
        -- For mock verification failures, use error level only if not in test mode
        get_logger().error("Mock verification failed", {
          failure_count = #failures,
          failures = table.concat(failures, "; "),
        })
      else
        -- In test mode, only log at debug level
        get_logger().debug("Mock verification failed (test mode)", {
          failure_count = #failures,
          failures = table.concat(failures, "; "),
        })
      end

      local error_obj = get_error_handler().validation_error(error_message, {
        function_name = "mock_obj:verify",
        failure_count = #failures,
        failures = failures,
      })

      -- We're returning the error object instead of throwing it
      -- This makes the API consistent with the rest of the error handling
      return false, error_obj
    end

    get_logger().debug("Mock verification passed")
    return true
  end

  -- Register for auto-cleanup
  register_mock(mock_obj)

  return mock_obj
end

--- Context manager for mocks that auto-restores
--- Executes a function with mock context and automatically restores all mocks
--- when the function completes, even if an error occurs. This ensures that mocks
--- are always cleaned up properly, preventing test leakage.
---
--- The function receives enhanced mock, spy, and stub creators that automatically
--- track and clean up all created test doubles.
---
--- @param fn function The function to execute with mock context
--- @return any result The result returned by the executed function `fn`, or `nil` if `fn` failed.
--- @return table? error Error object if `fn` failed during execution or if mock restoration failed afterwards. The primary error (from `fn`) is prioritized.
--- @throws table If validation of `fn` fails critically or if a critical error occurs during execution/restoration that isn't caught by `error_handler.try`.
---
--- @usage
--- -- Using the context manager with the modern style
--- mock.with_mocks(function(mock_fn, spy, stub)
---   -- Create mocks that will be auto-restored
---   local mock_logger = mock.create(logger)
---   mock_logger:stub("info", function() end)
---
---   -- Create spies that will be auto-restored
---   local file_spy = spy.on(file_system, "read_file")
---
---   -- Test code using mocks and spies
---   my_module.process_data()
---
---   -- Verify expectations
---   assert(file_spy.called, "read_file should have been called")
--- end)
---
--- -- Using the context manager with the legacy style
--- mock.with_mocks(function(mock_fn)
---   -- Legacy usage with simpler API
---   mock_fn(logger, "info", function() end)
---   mock_fn(logger, "error", function() end)
---
---   -- Run test code
---   my_module.process_error()
--- end)
function mock.with_mocks(fn)
  -- Input validation
  if fn == nil then
    local err = get_error_handler().validation_error("Function argument cannot be nil", {
      function_name = "mock.with_mocks",
      parameter_name = "fn",
      provided_value = "nil",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if type(fn) ~= "function" then
    local err = get_error_handler().validation_error("Function argument must be a function", {
      function_name = "mock.with_mocks",
      parameter_name = "fn",
      provided_type = type(fn),
      provided_value = tostring(fn),
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Starting mock context manager")

  -- Keep a local registry of all mocks created within this context
  local context_mocks = {}

  -- Track function result and errors
  local ok, result, error_during_execution, errors_during_restore

  get_logger().debug("Initializing context-specific mock tracking")

  -- Create a mock function wrapper compatible with example usage
  local mock_fn = function(target, method_name, impl_or_value)
    -- Input validation with graceful degradation
    if target == nil then
      local err = get_error_handler().validation_error("Cannot create mock with nil target", {
        function_name = "mock_fn",
        parameter_name = "target",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      error(err.message)
    end

    -- Use protected calls for mock creation and manipulation
    local success, mock_obj, err = get_error_handler().try(function()
      if method_name then
        -- Called as mock_fn(obj, "method", impl)
        -- First create the mock object
        local mock_obj = mock.create(target)

        -- Then stub the method
        if type(method_name) == "string" then
          mock_obj:stub(method_name, impl_or_value)
        else
          get_logger().warn("Method name must be a string, skipping stubbing", {
            provided_type = type(method_name),
          })
        end

        table.insert(context_mocks, mock_obj)
        return mock_obj
      else
        -- Called as mock_fn(obj)
        local mock_obj = mock.create(target)
        table.insert(context_mocks, mock_obj)
        return mock_obj
      end
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to create or configure mock",
        {
          function_name = "mock_fn",
          target_type = type(target),
          method_name = method_name and tostring(method_name) or "nil",
          has_impl = impl_or_value ~= nil,
        },
        mock_obj -- On failure, mock_obj contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      error(error_obj.message)
    end

    return mock_obj
  end

  -- Run the function with mocking modules using get_error_handler().try
  local fn_success, fn_result, fn_err = get_error_handler().try(function()
    -- Create context-specific spy wrapper
    local context_spy = {
      new = function(...)
        local args = { ... }
        local success, spy_obj, err = get_error_handler().try(function()
          return spy.new(table.unpack(args))
        end)

        if not success then
          local error_obj = get_error_handler().runtime_error(
            "Failed to create spy",
            {
              function_name = "context_spy.new",
              arg_count = select("#", ...),
            },
            spy_obj -- On failure, spy_obj contains the error
          )
          get_logger().error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, spy_obj)
        return spy_obj
      end,

      on = function(obj, method_name)
        -- Input validation
        if obj == nil then
          local err = get_error_handler().validation_error("Cannot spy on nil object", {
            function_name = "context_spy.on",
            parameter_name = "obj",
            provided_value = "nil",
          })
          get_logger().error(err.message, err.context)
          error(err.message)
        end

        if type(method_name) ~= "string" then
          local err = get_error_handler().validation_error("Method name must be a string", {
            function_name = "context_spy.on",
            parameter_name = "method_name",
            provided_type = type(method_name),
            provided_value = tostring(method_name),
          })
          get_logger().error(err.message, err.context)
          error(err.message)
        end

        -- Create spy with error handling
        local success, spy_obj, err = get_error_handler().try(function()
          return spy.on(obj, method_name)
        end)

        if not success then
          local error_obj = get_error_handler().runtime_error(
            "Failed to create spy on object method",
            {
              function_name = "context_spy.on",
              target_type = type(obj),
              method_name = method_name,
            },
            spy_obj -- On failure, spy_obj contains the error
          )
          get_logger().error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, spy_obj)
        return spy_obj
      end,
    }

    -- Create context-specific stub wrapper
    local context_stub = {
      new = function(...)
        local args = { ... }
        local success, stub_obj, err = get_error_handler().try(function()
          return stub.new(table.unpack(args))
        end)

        if not success then
          local error_obj = get_error_handler().runtime_error(
            "Failed to create stub",
            {
              function_name = "context_stub.new",
              arg_count = select("#", ...),
            },
            stub_obj -- On failure, stub_obj contains the error
          )
          get_logger().error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, stub_obj)
        return stub_obj
      end,

      on = function(obj, method_name, value_or_impl)
        -- Input validation
        if obj == nil then
          local err = get_error_handler().validation_error("Cannot stub nil object", {
            function_name = "context_stub.on",
            parameter_name = "obj",
            provided_value = "nil",
          })
          get_logger().error(err.message, err.context)
          error(err.message)
        end

        if type(method_name) ~= "string" then
          local err = get_error_handler().validation_error("Method name must be a string", {
            function_name = "context_stub.on",
            parameter_name = "method_name",
            provided_type = type(method_name),
            provided_value = tostring(method_name),
          })
          get_logger().error(err.message, err.context)
          error(err.message)
        end

        -- Create stub with error handling
        local success, stub_obj, err = get_error_handler().try(function()
          return stub.on(obj, method_name, value_or_impl)
        end)

        if not success then
          local error_obj = get_error_handler().runtime_error(
            "Failed to create stub on object method",
            {
              function_name = "context_stub.on",
              target_type = type(obj),
              method_name = method_name,
              value_type = type(value_or_impl),
            },
            stub_obj -- On failure, stub_obj contains the error
          )
          get_logger().error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, stub_obj)
        return stub_obj
      end,
    }

    -- Create context-specific mock wrapper
    local context_mock = {
      create = function(target, options)
        -- Input validation
        if target == nil then
          local err = get_error_handler().validation_error("Cannot create mock with nil target", {
            function_name = "context_mock.create",
            parameter_name = "target",
            provided_value = "nil",
          })
          get_logger().error(err.message, err.context)
          error(err.message)
        end

        -- Create mock with error handling
        local success, mock_obj, err = get_error_handler().try(function()
          return mock.create(target, options)
        end)

        if not success then
          local error_obj = get_error_handler().runtime_error(
            "Failed to create mock object",
            {
              function_name = "context_mock.create",
              target_type = type(target),
              options_provided = options ~= nil,
            },
            mock_obj -- On failure, mock_obj contains the error
          )
          get_logger().error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, mock_obj)
        return mock_obj
      end,

      restore_all = function()
        local success, result, err = get_error_handler().try(function()
          mock.restore_all()
          return true
        end)

        if not success then
          local error_obj = get_error_handler().runtime_error(
            "Failed to restore all mocks",
            {
              function_name = "context_mock.restore_all",
            },
            result -- On failure, result contains the error
          )
          get_logger().error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        return true
      end,
    }

    -- Call the function with our wrappers
    -- Support both calling styles:
    -- with_mocks(function(mock_fn)) -- for old/example style
    -- with_mocks(function(mock, spy, stub)) -- for new style
    return fn(mock_fn, context_spy, context_stub)
  end)

  -- Set up results for proper error handling
  if fn_success then
    ok = true
    result = fn_result
  else
    ok = false
    error_during_execution = fn_result -- On failure, fn_result contains the error
  end

  -- Always restore mocks, even on failure
  get_logger().debug("Restoring context mocks", {
    mock_count = #context_mocks,
  })

  errors_during_restore = {}

  for i, mock_obj in ipairs(context_mocks) do
    -- Use get_error_handler().try to ensure we restore all mocks even if one fails
    get_logger().debug("Restoring context mock", {
      index = i,
      has_restore = mock_obj and type(mock_obj) == "table" and type(mock_obj.restore) == "function",
    })

    local restore_success, restore_result = get_error_handler().try(function()
      if mock_obj and type(mock_obj) == "table" and type(mock_obj.restore) == "function" then
        mock_obj:restore()
        return true
      else
        get_logger().debug("Cannot restore object (not a valid mock)", {
          index = i,
          obj_type = type(mock_obj),
        })
        return false,
          get_error_handler().validation_error("Cannot restore object (not a valid mock)", {
            function_name = "mock.with_mocks/restore",
            index = i,
            obj_type = type(mock_obj),
          })
      end
    end)

    -- If restoration fails, capture the error but continue
    if not restore_success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to restore mock",
        {
          function_name = "mock.with_mocks/restore",
          index = i,
          mock_type = type(mock_obj),
        },
        restore_result -- On failure, restore_result contains the error
      )
      -- Use debug level instead of error to avoid confusing test output
      get_logger().debug("Failed to restore mock during test", error_obj.context)
      table.insert(errors_during_restore, error_obj)
    elseif restore_result == false then
      -- The try function succeeded but the validation failed
      get_logger().debug("Skipped restoration of invalid mock object", {
        index = i,
        error = "Not a valid mock with restore method",
      })
    end
  end

  get_logger().debug("Context mocks restoration complete", {
    success = #errors_during_restore == 0,
    error_count = #errors_during_restore,
  })

  -- If there was an error during the function execution
  if not ok then
    local error_message = "Error during mock context execution"

    -- Extract more information from the error if possible
    if error_during_execution then
      if type(error_during_execution) == "table" and error_during_execution.message then
        error_message = error_message .. ": " .. error_during_execution.message
      elseif type(error_during_execution) == "string" then
        error_message = error_message .. ": " .. error_during_execution
      end
    end

    local error_obj = get_error_handler().runtime_error(error_message, {
      function_name = "mock.with_mocks",
    }, error_during_execution)

    -- Properly detect test mode through the error handler
    local is_test_mode = error_handler
      and type(error_handler) == "table"
      and type(get_error_handler().is_test_mode) == "function"
      and get_error_handler().is_test_mode()

    -- Check if this appears to be a test-related error based on structured error properties
    local is_expected_in_test = is_test_mode
      and error_during_execution
      and type(error_during_execution) == "table"
      and (error_during_execution.category == "VALIDATION" or error_during_execution.category == "TEST_EXPECTED")

    if is_expected_in_test then
      -- If it's a validation error from an assertion, it's likely part of the test
      get_logger().debug("Test assertion failure in mock context", {
        error = error_message,
      })
    else
      -- For actual unexpected errors, check if we should log
      if
        not (
          error_handler
          and type(get_error_handler().is_suppressing_test_logs) == "function"
          and get_error_handler().is_suppressing_test_logs()
        )
      then
        get_logger().error("Error during mock context execution", {
          error = error_message,
        })
      end
    end

    -- If there were also errors during restoration, log them but prioritize the execution error
    if #errors_during_restore > 0 then
      get_logger().warn("Additional errors occurred during mock restoration", {
        error_count = #errors_during_restore,
      })
    end

    return nil, error_obj
  end

  -- If there were errors during mock restoration, report them
  if #errors_during_restore > 0 then
    local error_messages = {}
    for i, err in ipairs(errors_during_restore) do
      table.insert(error_messages, get_error_handler().format_error(err))
    end

    local error_obj = get_error_handler().runtime_error("Errors occurred during mock restoration", {
      function_name = "mock.with_mocks",
      error_count = #errors_during_restore,
      errors = error_messages,
    })
    -- Use debug level to avoid confusing test output
    get_logger().debug("Mock restoration issues during test", {
      error_count = #errors_during_restore,
    })

    -- Since the main function executed successfully, we return both the result and the error
    return result, #errors_during_restore > 0 and error_obj or nil
  end

  get_logger().debug("Mock context completed successfully")
  return result
end

return mock
