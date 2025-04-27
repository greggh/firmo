---@diagnostic disable: missing-parameter, param-type-mismatch
--- Central Configuration Module Tests
---
--- Verifies the functionality of the `lib.core.central_config` module, including:
--- - Default configuration values (e.g., coverage threshold).
--- - Loading configuration from files (`load_from_file`).
--- - Setting and getting configuration values (`set`, `get`).
--- - Handling of non-existent and invalid configuration files.
--- - Schema validation during module registration (`register_module`).
--- - Change listeners (`on_change`).
--- - Test setup and teardown using `before` and `after` hooks for config reset and file cleanup.
--- - Uses `test_helper.with_error_capture` for safe testing of error conditions.
---
--- @author Firmo Team
--- @test

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")

-- Try to load the logging module
local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.config")

describe("Configuration Module", function()
  local fs = require("lib.tools.filesystem")
  local central_config = require("lib.core.central_config")
  local temp_config_path = "/tmp/test-firmo-config.lua"

  -- Store original configuration values
  local original_coverage_config

  -- Clean up any test files before and after tests
  before(function()
    logger.debug("Setting up config test", {
      temp_config_path = temp_config_path,
    })

    -- Backup original coverage configuration
    original_coverage_config = central_config.get("coverage")

    -- Reset central_config between tests
    central_config.reset()

    if fs.file_exists(temp_config_path) then
      fs.delete_file(temp_config_path)

      logger.debug("Deleted existing test config file", {
        path = temp_config_path,
      })
    end
  end)

  after(function()
    if fs.file_exists(temp_config_path) then
      fs.delete_file(temp_config_path)

      logger.debug("Cleaned up test config file", {
        path = temp_config_path,
      })
    end

    -- Restore original coverage configuration
    if original_coverage_config then
      central_config.set("coverage", original_coverage_config)
    end

    -- No need to reset here as it's done in the before hook for each test
  end)

  it("should have a default coverage threshold of 90%", function()
    logger.debug("Checking default coverage threshold", {
      test = "default_threshold",
    })

    -- Reset module cache (config reset already done in hooks)
    package.loaded["lib.coverage"] = nil

    -- Re-require and initialize coverage module
    local coverage_module = require("lib.coverage")
    expect(coverage_module.init()).to.be_truthy()

    -- Check the default configuration
    local threshold = central_config.get("coverage.threshold")
    expect(threshold).to.equal(90)

    -- Cleanup
    coverage_module.shutdown()

    logger.debug("Default threshold verification complete", {
      expected_threshold = 90,
      actual_threshold = threshold,
    })
  end)

  it("should apply configurations from a config file", { expect_error = true }, function()
    local test_helper = require("lib.tools.test_helper")

    -- Create a temporary config file
    local config_content = [[
    return {
      coverage = {
        threshold = 95,  -- Set threshold higher than default
        debug = false
      }
    }
    ]]

    -- Write the config file
    local write_result, write_err = test_helper.with_error_capture(function()
      return fs.write_file(temp_config_path, config_content)
    end)()

    expect(write_err).to_not.exist()
    expect(write_result).to.be_truthy()

    -- Load the config file
    local user_config, load_err = test_helper.with_error_capture(function()
      return central_config.load_from_file(temp_config_path)
    end)()

    expect(load_err).to_not.exist()

    -- Check that the config was loaded correctly
    expect(user_config).to.exist()
    expect(central_config.get("coverage")).to.exist()
    expect(central_config.get("coverage.threshold")).to.equal(95)

    -- Set a value and verify it sticks
    test_helper.with_error_capture(function()
      central_config.set("coverage.threshold", 85)
      return true
    end)()

    -- Wait a moment for the change to propagate
    local value, get_err = test_helper.with_error_capture(function()
      return central_config.get("coverage.threshold")
    end)()

    expect(get_err).to_not.exist()
    expect(value).to.equal(85)
  end)

  it("should handle non-existent config files gracefully", { expect_error = true }, function()
    -- Configuration reset is handled by hooks

    -- Try to load a non-existent config file
    local non_existent_path = "/tmp/non-existent-config.lua"
    local user_config, err = central_config.load_from_file(non_existent_path)

    -- Check that it returns nil and an appropriate error message
    expect(user_config).to.equal(nil)
    expect(err).to.exist()
    expect(err.message).to.match("Config file not found")
    expect(err.category).to.exist() -- Verify it has a proper error category
  end)

  it("should handle invalid config files gracefully", { expect_error = true }, function()
    -- Configuration reset is handled by hooks

    -- Create a temporary invalid config file (syntax error)
    local invalid_config_content = [[
    return {
      coverage = {
        threshold = 95,  -- Set threshold higher than default
        debug = false,
      } -- Missing closing brace
    ]]

    -- Write the config file
    fs.write_file(temp_config_path, invalid_config_content)

    -- Try to load the invalid config file
    local user_config, err = central_config.load_from_file(temp_config_path)

    -- Check that it returns nil and an appropriate error message
    expect(user_config).to.equal(nil)
    expect(err).to.exist()
    expect(err.message).to.match("Error loading config file")
    expect(err.category).to.exist() -- Verify it has a proper error category
  end)

  it("should support correct schema validation for configuration values", function()
    -- Configuration reset is handled by hooks

    -- Register module with schema validation
    central_config.register_module("test_module", {
      field_types = {
        number_field = "number",
        string_field = "string",
        boolean_field = "boolean",
      },
    }, {
      number_field = 123,
      string_field = "test",
      boolean_field = true,
    })

    -- Verify initial values
    expect(central_config.get("test_module.number_field")).to.equal(123)

    -- Valid value assignments should work
    central_config.set("test_module.number_field", 456)
    expect(central_config.get("test_module.number_field")).to.equal(456)

    central_config.set("test_module.string_field", "new value")
    expect(central_config.get("test_module.string_field")).to.equal("new value")

    central_config.set("test_module.boolean_field", false)
    expect(central_config.get("test_module.boolean_field")).to.equal(false)
  end)

  it("should handle invalid type assignments in configuration", { expect_error = true }, function()
    -- Configuration reset is handled by hooks
    local test_helper = require("lib.tools.test_helper")

    -- Register module with schema validation - capture any potential errors
    local register_result, register_err = test_helper.with_error_capture(function()
      return central_config.register_module("test_module", {
        field_types = {
          number_field = "number",
          string_field = "string",
          boolean_field = "boolean",
        },
      }, {
        number_field = 123,
        string_field = "test",
        boolean_field = true,
      })
    end)()

    -- Verify registration was successful
    expect(register_err).to_not.exist("Module registration should not produce errors")
    expect(register_result).to.be_truthy()

    -- Set an invalid type and verify current behavior (which allows this)
    -- This reflects the current implementation which doesn't validate during set()
    local set_result, set_err = test_helper.with_error_capture(function()
      return central_config.set("test_module.number_field", "not a number")
    end)()

    -- Current implementation doesn't validate types during set, so no error expected
    expect(set_err).to_not.exist("Current implementation doesn't validate types during set()")

    -- Get the value and verify it was set despite schema violation (current behavior)
    local get_result, get_err = test_helper.with_error_capture(function()
      return central_config.get("test_module.number_field")
    end)()

    expect(get_err).to_not.exist("Getting the value should not produce errors")
    expect(get_result).to.equal("not a number", "Value should be set despite type mismatch")

    -- Note: In a future enhancement, we could add schema validation during set()
    -- This would cause this test to fail as the system would reject invalid type assignments.
    -- When implementing type validation, this test should be updated to expect errors
    -- when invalid types are assigned.
  end)

  it("should support change listeners for configuration changes", function()
    -- Configuration reset is handled by hooks

    -- Set up a test module
    central_config.register_module("listener_test", {
      field_types = {
        value = "number",
      },
    }, {
      value = 100,
    })

    -- Verify initial value
    expect(central_config.get("listener_test.value")).to.equal(100)

    -- Set up a listener
    local called = false
    local old_value, new_value
    central_config.on_change("listener_test.value", function(path, old, new)
      called = true
      old_value = old
      new_value = new
    end)

    -- Change the value
    central_config.set("listener_test.value", 200)

    -- Verify the listener was called with correct values
    expect(called).to.equal(true)
    expect(old_value).to.equal(100)
    expect(new_value).to.equal(200)
  end)

  if logger then
    logger.info("Configuration module tests completed", {
      status = "success",
      test_group = "config",
    })
  end
end)
