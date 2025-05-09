--- Firmo Mocking System Integration
---
--- This module provides a comprehensive mocking system for test isolation and verification.
--- It integrates the spy, stub, and mock subsystems into a unified API with enhanced error
--- handling and automatic cleanup. The mocking system is a key component for writing
--- reliable and maintainable tests.
---
--- Features:
--- - Unified API for spy, stub, and mock capabilities.
--- - Dual interface supporting functional (`mocking.spy(fn)`) and object-oriented (`mocking.spy.on(...)`) styles.
--- - Spies for tracking function calls without changing behavior.
--- - Stubs for replacing functions with controlled implementations or return values.
--- - Mocks for creating complete test doubles with method stubbing and expectation verification.
--- - Automatic cleanup and restoration of original behavior via `mocking.mock.restore_all()` or hooks.
--- - Integration with test lifecycle via `register_cleanup_hook`.
--- - Comprehensive error handling using `lib.tools.error_handler`.
--- - Context manager for guaranteed mock cleanup (`with_mocks`).
---
--- @module lib.mocking
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class mocking The public API of the mocking integration module. Provides access to spy, stub, and mock functionalities with integrated error handling and cleanup.
---@field _VERSION string Module version string.
---@field spy table fun(target: table|function, name?: string): table|nil, table|nil) Provides `spy.on(obj, name)` and `spy.new(fn)` methods, and can be called directly as `mocking.spy(target, name?)`. Returns `spy_object|nil, error|nil`. @see lib.mocking.spy
---@field stub table fun(value_or_fn?: any): table|nil, table|nil) Provides `stub.on(obj, name, impl)` and `stub.new(impl)` methods, and can be called directly as `mocking.stub(impl?)`. Returns `stub_object|nil, error|nil`. @see lib.mocking.stub
---@field mock table fun(target: table, method_or_options?: string|table, impl_or_value?: any): table|nil, table|nil) Provides `mock.create(target, options)`, `mock.restore_all()`, `mock.with_mocks(fn)`. Can be called directly as `mocking.mock(target, method?, impl?)` or `mocking.mock(target, options?)`. Returns `mock_object|nil, error|nil`. @see lib.mocking.mock
---@field with_mocks fun(fn: function): any, table|nil Executes a function with automatic mock cleanup via `mock.with_mocks`. Returns `result|nil, error|nil`.
---@field register_cleanup_hook fun(after_test_fn?: function): function Registers a composite cleanup hook that runs the optional `after_test_fn` then `mock.restore_all()`. Returns the composite function. @throws table If validation fails.
---@field reset_all fun(): boolean, table|nil Resets all spies, stubs, and mocks by calling `mock.restore_all()`. Returns `success, error|nil`. @throws table If reset fails critically.
---@field create_spy fun(fn?: function): table|nil, table|nil Creates a standalone spy function via `spy.new`. Returns `spy_object|nil, error|nil`. @throws table If creation fails.
---@field create_stub fun(return_value?: any): table|nil, table|nil Creates a standalone stub function via `stub.new`. Returns `stub_object|nil, error|nil`. @throws table If creation fails.
---@field create_mock fun(methods?: table<string, function|any>): table|nil, table|nil Creates a mock object from scratch via `mock.create` (target is implicitly `{}`). Returns `mock_object|nil, error|nil`. @throws table If creation fails.
---@field is_spy fun(obj: any): boolean Checks if an object is a spy created by this system (via `spy.is_spy`).
---@field is_stub fun(obj: any): boolean Checks if an object is a stub created by this system (via `stub.is_stub`).
---@field is_mock fun(obj: any): boolean Checks if an object is a mock created by this system (via `mock.is_mock`).
---@field get_all_mocks fun(): table<number, table> Gets a list of all active mocks tracked by `lib.mocking.mock`.
---@field safe_mock fun(...) [Not Implemented] Create a safe mock that won't cause infinite recursion.
---@field verify fun(mock_obj: table): boolean, table|nil Verifies expectations for a specific mock object via `mock.verify`. Returns `success, error|nil`. @throws table If validation or verification fails critically.
---@field configure fun(options: table): mocking Configures the mocking system (placeholder, currently no options implemented here). Returns self.

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
    return logging.get_logger("mocking")
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
local mock = try_require("lib.mocking.mock")

local mocking = {
  -- Module version
  _VERSION = "1.0.0",
}
-- Export the spy module with compatibility for both object-oriented and functional API
mocking.spy = setmetatable({
  on = spy.on,
  new = spy.new,
}, {
  ---@param _ any The table being used as a function
  ---@param target table|function The target to spy on (table or function)
  ---@param name? string Optional name of the method to spy on (for table targets)
  ---@return table|nil spy The created spy object or function wrapper, or nil on error. (`spy_object` type may be defined in `spy.lua`)
  ---@return table|nil error Error object if creation failed.
  ---@throws table If validation or spy creation fails critically.
  __call = function(_, target, name)
    -- Input validation with error handling
    if target == nil then
      local err = get_error_handler().validation_error("Cannot create spy on nil target", {
        function_name = "mocking.spy",
        parameter_name = "target",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if type(target) == "table" and name ~= nil then
      -- Called as spy(obj, "method") - spy on an object method

      -- Validate method name
      if type(name) ~= "string" then
        local err = get_error_handler().validation_error("Method name must be a string", {
          function_name = "mocking.spy",
          parameter_name = "name",
          provided_type = type(name),
          provided_value = tostring(name),
        })
        get_logger().error(err.message, err.context)
        return nil, err
      end

      -- Validate method exists on target
      if target[name] == nil then
        local err = get_error_handler().validation_error("Method does not exist on target object", {
          function_name = "mocking.spy",
          parameter_name = "name",
          method_name = name,
          target_type = type(target),
        })
        get_logger().error(err.message, err.context)
        return nil, err
      end

      get_logger().debug("Creating spy on object method", {
        target_type = type(target),
        method_name = name,
      })

      -- Use error handling to safely create the spy
      ---@diagnostic disable-next-line: unused-local
      local success, spy_obj, err = get_error_handler().try(function()
        return spy.on(target, name)
      end)

      if not success then
        local error_obj = get_error_handler().runtime_error(
          "Failed to create spy on object method",
          {
            function_name = "mocking.spy",
            target_type = type(target),
            method_name = name,
          },
          spy_obj -- On failure, spy_obj contains the error
        )
        get_logger().error(error_obj.message, error_obj.context)
        return nil, error_obj
      end

      -- Make sure the wrapper gets all properties from the spy with error handling
      local success, _, err = get_error_handler().try(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        for k, v in pairs(spy_obj) do
          if type(target[name]) == "table" then
            target[name][k] = v
          end
        end

        -- Make sure callback works
        if type(target[name]) == "table" then
          target[name].called_with = function(_, ...)
            return spy_obj:called_with(...)
          end
        end

        return true
      end)

      if not success then
        local error_obj = get_error_handler().runtime_error("Failed to set properties on spied method", {
          function_name = "mocking.spy",
          target_type = type(target),
          method_name = name,
        }, err)
        get_logger().error(error_obj.message, error_obj.context)
        -- We continue anyway - this is a non-critical error
        get_logger().warn("Continuing with partially configured spy")
      end

      get_logger().debug("Spy created successfully on object method", {
        target_type = type(target),
        method_name = name,
      })

      return target[name] -- Return the method wrapper
    else
      -- Called as spy(fn) - spy on a function

      -- Validate function
      if type(target) ~= "function" then
        local err = get_error_handler().validation_error("Target must be a function when creating standalone spy", {
          function_name = "mocking.spy",
          parameter_name = "target",
          provided_type = type(target),
        })
        get_logger().error(err.message, err.context)
        return nil, err
      end

      get_logger().debug("Creating spy on function", {
        target_type = type(target),
      })

      -- Use error handling to safely create the spy
      ---@diagnostic disable-next-line: unused-local
      local success, spy_obj, err = get_error_handler().try(function()
        return spy.new(target)
      end)

      if not success then
        local error_obj = get_error_handler().runtime_error(
          "Failed to create spy on function",
          {
            function_name = "mocking.spy",
            target_type = type(target),
          },
          spy_obj -- On failure, spy_obj contains the error
        )
        get_logger().error(error_obj.message, error_obj.context)
        return nil, error_obj
      end

      return spy_obj
    end
  end,
})

-- Export the stub module with compatibility for both object-oriented and functional API
mocking.stub = setmetatable({
  ---@param target table The object to stub a method on
  ---@param name string The name of the method to stub
  ---@param value_or_impl any The value or function implementation for the stub
  ---@return table|nil stub The created stub, or nil on error
  ---@return table|nil error Error object if creation failed.
  ---@throws table If validation or stub creation fails critically.
  on = function(target, name, value_or_impl)
    -- Input validation
    if target == nil then
      local err = get_error_handler().validation_error("Cannot create stub on nil target", {
        function_name = "mocking.stub.on",
        parameter_name = "target",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = get_error_handler().validation_error("Method name must be a string", {
        function_name = "mocking.stub.on",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Creating stub on object method", {
      target_type = type(target),
      method_name = name,
      value_type = type(value_or_impl),
    })

    -- Use error handling to safely create the stub
    ---@diagnostic disable-next-line: unused-local
    local success, stub_obj, err = get_error_handler().try(function()
      return stub.on(target, name, value_or_impl)
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to create stub on object method",
        {
          function_name = "mocking.stub.on",
          target_type = type(target),
          method_name = name,
          value_type = type(value_or_impl),
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    get_logger().debug("Stub created successfully on object method", {
      target_type = type(target),
      method_name = name,
    })

    return stub_obj
  end,

  ---@param value_or_fn? any The value or function implementation for the stub
  ---@return table|nil stub The created stub, or nil on error
  ---@return table|nil error Error object if creation failed.
  ---@throws table If stub creation fails critically.
  new = function(value_or_fn)
    get_logger().debug("Creating new stub function", {
      value_type = type(value_or_fn),
    })

    -- Use error handling to safely create the stub
    ---@diagnostic disable-next-line: unused-local
    local success, stub_obj, err = get_error_handler().try(function()
      return stub.new(value_or_fn)
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to create new stub function",
        {
          function_name = "mocking.stub.new",
          value_type = type(value_or_fn),
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    return stub_obj
  end,
}, {
  ---@param _ any The table being used as a function
  ---@param value_or_fn? any The value or function implementation for the stub
  ---@return table|nil stub The created stub object, or nil on error. (`stub_object` type may be defined in `stub.lua`)
  ---@return table|nil error Error object if creation failed.
  ---@throws table If validation or stub creation fails critically.
  __call = function(_, value_or_fn)
    -- Input validation (optional, as stub can be called without arguments)
    if
      value_or_fn ~= nil
      and type(value_or_fn) ~= "function"
      and type(value_or_fn) ~= "table"
      and type(value_or_fn) ~= "string"
      and type(value_or_fn) ~= "number"
      and type(value_or_fn) ~= "boolean"
    then
      local err =
        get_error_handler().validation_error("Stub value must be a function, table, string, number, boolean or nil", {
          function_name = "mocking.stub",
          parameter_name = "value_or_fn",
          provided_type = type(value_or_fn),
          provided_value = tostring(value_or_fn),
        })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Creating new stub", {
      value_type = value_or_fn and type(value_or_fn) or "nil",
    })

    -- Use error handling to safely create the stub
    ---@diagnostic disable-next-line: unused-local
    local success, stub_obj, err = get_error_handler().try(function()
      return stub.new(value_or_fn)
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to create stub",
        {
          function_name = "mocking.stub",
          value_type = value_or_fn and type(value_or_fn) or "nil",
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    return stub_obj
  end,
})

-- Export the mock module with compatibility for functional API
mocking.mock = setmetatable({
  ---@param target table The object to create a mock of
  ---@param options? table Optional configuration { verify_all_expectations?: boolean }
  ---@return table|nil mock The created mock object, or nil on error
  ---@return table|nil error Error object if creation failed.
  ---@throws table If validation or mock creation fails critically.
  create = function(target, options)
    -- Input validation
    if target == nil then
      local err = get_error_handler().validation_error("Cannot create mock on nil target", {
        function_name = "mocking.mock.create",
        parameter_name = "target",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if options ~= nil and type(options) ~= "table" then
      local err = get_error_handler().validation_error("Options must be a table or nil", {
        function_name = "mocking.mock.create",
        parameter_name = "options",
        provided_type = type(options),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Creating mock object", {
      target_type = type(target),
      options = options or {},
    })

    -- Use error handling to safely create the mock
    ---@diagnostic disable-next-line: unused-local
    local success, mock_obj, err = get_error_handler().try(function()
      return mock.create(target, options)
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to create mock object",
        {
          function_name = "mocking.mock.create",
          target_type = type(target),
          options_type = options and type(options) or "nil",
        },
        mock_obj -- On failure, mock_obj contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    get_logger().debug("Mock object created successfully", {
      target_type = type(target),
      verify_all = mock_obj._verify_all_expectations_called,
    })

    return mock_obj
  end,

  ---@return boolean success Whether all mocks were successfully restored
  ---@return boolean success Whether restoration succeeded.
  ---@return table|nil error Error object if restoration failed.
  ---@throws table If restoration fails critically.
  restore_all = function()
    get_logger().debug("Restoring all mocks")

    -- Use error handling to safely restore all mocks
    local success, err = get_error_handler().try(function()
      mock.restore_all()
      return true
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error("Failed to restore all mocks", {
        function_name = "mocking.mock.restore_all",
      }, err)
      get_logger().error(error_obj.message, error_obj.context)
      return false, error_obj
    end

    get_logger().debug("All mocks restored successfully")
    return true
  end,

  ---@param fn function The function to execute with automatic mock cleanup
  ---@return any result The result from the function execution
  ---@return any result The result returned by the provided function `fn`, or `nil` on error.
  ---@return table|nil error Error object if execution failed.
  ---@throws table If validation or execution fails critically.
  with_mocks = function(fn)
    -- Input validation
    if type(fn) ~= "function" then
      local err = get_error_handler().validation_error("with_mocks requires a function argument", {
        function_name = "mocking.mock.with_mocks",
        parameter_name = "fn",
        provided_type = type(fn),
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    get_logger().debug("Starting with_mocks context manager")

    -- Use error handling to safely execute the with_mocks function
    ---@diagnostic disable-next-line: unused-local
    local success, result, err = get_error_handler().try(function()
      return mock.with_mocks(fn)
    end)

    if not success then
      local error_obj = get_error_handler().runtime_error(
        "Failed to execute with_mocks context manager",
        {
          function_name = "mocking.mock.with_mocks",
        },
        result -- On failure, result contains the error
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    get_logger().debug("with_mocks context manager completed successfully")
    return result
  end,
}, {
  ---@param _ any The table being used as a function
  ---@param target table The object to create a mock of
  ---@param method_or_options? string|table Either a method name to stub or options table
  ---@param impl_or_value? any The implementation or return value for the stub (when method specified)
  ---@return table|nil mock The created mock object, or nil on error
  ---@return table|nil error Error object if creation failed.
  ---@throws table If validation or mock creation fails critically.
  __call = function(_, target, method_or_options, impl_or_value)
    -- Input validation
    if target == nil then
      local err = get_error_handler().validation_error("Cannot create mock on nil target", {
        function_name = "mocking.mock",
        parameter_name = "target",
        provided_value = "nil",
      })
      get_logger().error(err.message, err.context)
      return nil, err
    end

    if type(method_or_options) == "string" then
      -- Called as mock(obj, "method", value_or_function)
      -- Validate method name
      if method_or_options == "" then
        local err = get_error_handler().validation_error("Method name cannot be empty", {
          function_name = "mocking.mock",
          parameter_name = "method_or_options",
          provided_value = method_or_options,
        })
        get_logger().error(err.message, err.context)
        return nil, err
      end

      get_logger().debug("Creating mock with method stub", {
        target_type = type(target),
        method = method_or_options,
        implementation_type = type(impl_or_value),
      })

      -- Use error handling to safely create the mock
      ---@diagnostic disable-next-line: unused-local
      local success, mock_obj, err = get_error_handler().try(function()
        local m = mock.create(target)
        ---@diagnostic disable-next-line: need-check-nil
        return m, m:stub(method_or_options, impl_or_value)
      end)

      if not success then
        local error_obj = get_error_handler().runtime_error(
          "Failed to create mock with method stub",
          {
            function_name = "mocking.mock",
            target_type = type(target),
            method = method_or_options,
            implementation_type = type(impl_or_value),
          },
          mock_obj -- On failure, mock_obj contains the error
        )
        get_logger().error(error_obj.message, error_obj.context)
        return nil, error_obj
      end

      return mock_obj
    else
      -- Called as mock(obj, options)
      -- Validate options
      if method_or_options ~= nil and type(method_or_options) ~= "table" then
        local err = get_error_handler().validation_error("Options must be a table or nil", {
          function_name = "mocking.mock",
          parameter_name = "method_or_options",
          provided_type = type(method_or_options),
        })
        get_logger().error(err.message, err.context)
        return nil, err
      end

      get_logger().debug("Creating mock with options", {
        target_type = type(target),
        options_type = type(method_or_options),
      })

      -- Use error handling to safely create the mock
      ---@diagnostic disable-next-line: unused-local
      local success, mock_obj, err = get_error_handler().try(function()
        return mock.create(target, method_or_options)
      end)

      if not success then
        local error_obj = get_error_handler().runtime_error(
          "Failed to create mock with options",
          {
            function_name = "mocking.mock",
            target_type = type(target),
            options_type = method_or_options and type(method_or_options) or "nil",
          },
          mock_obj -- On failure, mock_obj contains the error
        )
        get_logger().error(error_obj.message, error_obj.context)
        return nil, error_obj
      end

      return mock_obj
    end
  end,
})

-- Export the with_mocks context manager through our enhanced version
mocking.with_mocks = mocking.mock.with_mocks

--- Register a cleanup hook for mocks that runs after each test
--- Creates a composite hook function that restores all mocks after running
--- the provided hook function. This ensures that tests don't leak mocked state
--- to subsequent tests, preventing hard-to-debug test interactions.
---
--- @param after_test_fn? function Function to call after each test (optional)
--- @return function hook The cleanup hook function to use with firmo's after_each
---
--- @return function hook The composite cleanup hook function.
--- @throws table If validation fails (e.g., `after_test_fn` is provided but not a function).
---
--- @usage
--- -- In your test setup (e.g., a shared setup file or main test runner)
--- local firmo = require("firmo")
--- local mocking = require("lib.mocking")
---
--- -- Wrap the existing after hook (or use directly if none exists)
--- firmo.after = mocking.register_cleanup_hook(firmo.after) -- Assuming firmo.after exists
function mocking.register_cleanup_hook(after_test_fn)
  get_logger().debug("Registering mock cleanup hook")

  -- Use empty function as fallback
  local original_fn

  if after_test_fn ~= nil and type(after_test_fn) ~= "function" then
    local err = get_error_handler().validation_error("Cleanup hook must be a function or nil", {
      function_name = "mocking.register_cleanup_hook",
      parameter_name = "after_test_fn",
      provided_type = type(after_test_fn),
    })
    get_logger().error(err.message, err.context)

    -- Use fallback empty function
    original_fn = function() end
  else
    original_fn = after_test_fn or function() end
  end

  -- Return the cleanup hook function with error handling
  return function(name)
    get_logger().debug("Running test cleanup hook", {
      test_name = name,
    })

    -- Call the original after function first with error handling
    ---@diagnostic disable-next-line: unused-local
    local success, result, err = get_error_handler().try(function()
      ---@diagnostic disable-next-line: redundant-parameter
      return original_fn(name)
    end)

    if not success then
      get_logger().error("Original test cleanup hook failed", {
        test_name = name,
        error = get_error_handler().format_error(result),
      })
      -- We continue with mock restoration despite the error
    end

    -- Then restore all mocks with error handling
    get_logger().debug("Restoring all mocks")
    ---@diagnostic disable-next-line: unused-local
    local mock_success, mock_err = get_error_handler().try(function()
      mock.restore_all()
      return true
    end)

    if not mock_success then
      get_logger().error("Failed to restore mocks in cleanup hook", {
        test_name = name,
        error = get_error_handler().format_error(mock_success),
      })
      -- We still return the original result despite the error
    end

    -- Return the result from the original function
    if success then
      return result
    else
      -- If the original function failed, we return nil
      return nil
    end
  end
end

-- Add direct exports for submodule functions if not already exposed via metatables
--- Resets all spies, stubs, and mocks by calling `mock.restore_all()`.
---@return boolean success Whether restoration succeeded.
---@return table|nil error Error object if restoration failed.
---@throws table If restoration fails critically.
mocking.reset_all = mocking.mock.restore_all

--- Checks if an object is a spy created by this system.
---@param obj any Object to check.
---@return boolean
mocking.is_spy = spy.is_spy

--- Checks if an object is a stub created by this system.
---@param obj any Object to check.
---@return boolean
mocking.is_stub = stub.is_stub

--- Checks if an object is a mock created by this system.
---@param obj any Object to check.
---@return boolean
mocking.is_mock = mock.is_mock

--- Gets a list of all active mocks tracked by `lib.mocking.mock`.
---@return table<number, table> List of mock objects.
mocking.get_all_mocks = mock.get_all_mocks

--- Verifies expectations for a specific mock object.
---@param mock_obj table The mock object to verify.
---@return boolean success True if verification passes.
---@return table|nil error Error object if verification fails.
---@throws table If validation or verification fails critically.
mocking.verify = mock.verify

--- Configures the mocking system (placeholder).
---@param options table Configuration options (currently none defined).
---@return mocking The module instance for chaining.
mocking.configure = function(options)
  get_logger().warn("mocking.configure is currently a placeholder and accepts no options.", { provided = options })
  return mocking
end

--- Creates a standalone spy function.
---@param fn? function Optional function to wrap with the spy.
---@return table|nil spy_object The created spy object.
---@return table|nil error Error object if creation fails.
---@throws table If creation fails critically.
mocking.create_spy = mocking.spy.new

--- Creates a standalone stub function.
---@param return_value? any Optional value or function for the stub to return/execute.
---@return table|nil stub_object The created stub object.
---@return table|nil error Error object if creation fails.
---@throws table If creation fails critically.
mocking.create_stub = mocking.stub.new

--- Creates a mock object from scratch (no target).
---@param methods? table<string, function|any> Optional table defining methods and their implementations/return values.
---@return table|nil mock_object The created mock object.
---@return table|nil error Error object if creation fails.
---@throws table If creation fails critically.
mocking.create_mock = function(methods)
  -- mock.create expects a target, use an empty table for scratch mocks
  return mocking.mock.create(methods or {})
end

return mocking
