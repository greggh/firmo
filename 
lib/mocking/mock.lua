      _stubs = {},
      _originals = {},
      _spies = {},
      _expectations = {},
      _verify_all_expectations_called = options.verify_all_expectations_called ~= false,
      _properties = {}, -- Track stubbed properties
    }
    return self
  end
  
  --- Create an expectation for a method call
  --- Sets up an expectation that a method will be called with specific
  --- arguments. This is useful for verifying that methods are called
  --- in the expected way during tests.
  ---
  --- @param name string The method name to expect
  --- @return table expectation A chainable expectation object
  --- @return table? error Error information if expectation creation failed
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
      local err = error_handler.validation_error("Method name cannot be nil", {
        function_name = "mock_obj:expect",
        parameter_name = "name",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = error_handler.validation_error("Method name must be a string", {
        function_name = "mock_obj:expect",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    -- Validate method existence
    if self.target[name] == nil then
      local err = error_handler.validation_error("Cannot expect non-existent method", {
        function_name = "mock_obj:expect",
        parameter_name = "name",
        method_name = name,
        target_type = type(self.target),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Creating expectation for method", {
      method_name = name,
    })

    -- Create a new expectation with error handling
    local success, expectation, err = error_handler.try(function()
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

      -- Add a spy to track calls to the method
      self:spy(name)

      -- Create a chainable interface
      local exp_interface = {
        -- to -> with -> be -> called
        to = {
          be = {
            called = function(count)
              expectation.exact_calls = count or 1
              return exp_interface
            end,
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
        },
        with = function(...)
          local args = {...}
          if type(args[1]) == "function" then
            -- Custom matcher function
            expectation.args_matcher = args[1]
          else
            -- Specific arguments to match
            expectation.with_args = args
          end
          return exp_interface
        end,
      }

      -- Add convenience property for called to handle called.at_least, called.at_most
      exp_interface.to.be.called.at_least = function(count)
        expectation.min_calls = count or 1
        expectation.exact_calls = nil
        return exp_interface
      end

      exp_interface.to.be.called.at_most = function(count)
        expectation.max_calls = count or 1
        expectation.exact_calls = nil
        return exp_interface
      end

      exp_interface.to.be.called.times = function(count)
        expectation.exact_calls = count
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
      local error_obj = error_handler.runtime_error(
        "Failed to create expectation",
        {
          function_name = "mock_obj:expect",
          method_name = name,
          target_type = type(self.target),
        },
        expectation -- On failure, expectation contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    return expectation
  end

  --- Stub a property with a specific value
  --- Replaces a property on the mocked object with a stubbed value.
  --- The original value is preserved and can be restored later.
  ---
  --- @param name string The property name to stub
  --- @param value any The value to replace the property with
  --- @return mockable_object|nil self The mock object for method chaining, or nil on error
  --- @return table? error Error information if stubbing failed
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
      local err = error_handler.validation_error("Property name cannot be nil", {
        function_name = "mock_obj:stub_property",
        parameter_name = "name",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = error_handler.validation_error("Property name must be a string", {
        function_name = "mock_obj:stub_property",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Stubbing property", {
      property_name = name,
      value_type = type(value),
    })

    -- Validate property existence
    if self.target[name] == nil then
      local err = error_handler.validation_error("Cannot stub non-existent property", {
        function_name = "mock_obj:stub_property",
        parameter_name = "name",
        property_name = name,
        target_type = type(self.target),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    -- Use protected call to save the original property and set new value
    local success, result, err = error_handler.try(function()
      -- Save original value
      self._properties[name] = self.target[name]
      
      -- Set new value
      self.target[name] = value
      return true
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to stub property",
        {
          function_name = "mock_obj:stub_property",
          property_name = name,
          value_type = type(value),
          target_type = type(self.target),
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    logger.debug("Property successfully stubbed", {
      property_name = name,
    })
    return self
  end

  --- Stub a function with sequential return values
    -- Clean up all references with error handling
    ---@diagnostic disable-next-line: lowercase-global, unused-local
    success, result, err = error_handler.try(function()
      self._stubs = {}
      self._originals = {}
      self._spies = {}
      
      -- Also restore any stubbed properties
      for prop_name, original_value in pairs(self._properties or {}) do
        self.target[prop_name] = original_value
      end
      self._properties = {}
      
      return true
