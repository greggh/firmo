--- Logging Formatter Integration Module Tests
---
--- Verifies the functionality of the `lib.tools.logging.formatter_integration` module, including:
--- - Enhancing formatter objects with logging methods (`enhance_formatters`).
--- - Creating test-specific loggers with context (`create_test_logger`).
--- - Creating step-specific loggers (`logger.step`).
--- - Creating a standalone log formatter (`create_log_formatter`).
--- - Integrating logging with the reporting module (`integrate_with_reporting`).
--- Uses mock objects and `test_helper` for setup and verification.
---
--- @author Firmo Team
--- @test

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

local formatter_integration = require("lib.tools.logging.formatter_integration")
local logging = require("lib.tools.logging")
local test_helper = require("lib.tools.test_helper")

describe("Logging Formatter Integration Module", function()
  it("enhances formatters with logging capabilities", function()
    -- Create a local logger for debugging
    local test_logger = logging.get_logger("test.formatter_integration")
    -- Set log level to debug to ensure we see all messages
    if test_logger.set_level then
      test_logger.set_level("debug")
    elseif test_logger.level then
      test_logger.level = "debug"
    end
    test_logger.info("Created test logger with debug level")

    -- Create a mock formatters module that matches the real structure
    local formatters = {
      -- Registry for each type of formatter
      coverage = {
        test = {
          type = "coverage",
          name = "test",
        },
      },
      quality = {
        test_quality = {
          type = "quality",
          name = "test_quality",
        },
      },
      results = {},
      init = function()
        return true
      end,
    }

    if formatters.coverage then
      test_logger.info("- coverage registry content:")
      for name, formatter in pairs(formatters.coverage) do
        test_logger.info("  - formatter: " .. name .. ", type: " .. type(formatter))
        if formatter.type then
          test_logger.info("    - formatter.type: " .. formatter.type)
        end
        if formatter.name then
          test_logger.info("    - formatter.name: " .. formatter.name)
        end
      end
    end
    -- Mock the try_require function to return our mock formatters
    local original_try_require = _G.try_require
    _G.try_require = function(name)
      test_logger.info("try_require called with name: " .. name)

      if name == "lib.reporting.formatters" then
        test_logger.info("Returning mock formatters object")

        -- Additional verification before returning
        test_logger.info("- Before return: has coverage? " .. tostring(formatters.coverage ~= nil))
        test_logger.info(
          "- Before return: has test in coverage? " .. tostring(formatters.coverage and formatters.coverage.test ~= nil)
        )

        return formatters
      end

      test_logger.info("Returning nil for module: " .. name)
      return nil
    end

    -- Test enhancement
    local enhanced_formatters, err = formatter_integration.enhance_formatters()

    -- If we have a coverage registry but no test formatter, log the keys that exist
    if enhanced_formatters and enhanced_formatters.coverage and not enhanced_formatters.coverage.test then
      test_logger.info("Available keys in coverage registry:")
      for k, _ in pairs(enhanced_formatters.coverage) do
        test_logger.info("- Key: " .. tostring(k))
      end
    end

    -- Restore original function
    _G.try_require = original_try_require
    -- Verify enhancement
    expect(err).to_not.exist()
    expect(enhanced_formatters).to.exist()

    -- Check the returned object has been enhanced in each registry
    expect(enhanced_formatters.coverage.test._logger).to.exist()
    expect(enhanced_formatters.coverage.test.log_debug).to.be.a("function")
    expect(enhanced_formatters.coverage.test.log_info).to.be.a("function")
    expect(enhanced_formatters.coverage.test.log_error).to.be.a("function")

    -- Check the quality formatter was also enhanced
    expect(enhanced_formatters.quality.test_quality._logger).to.exist()
    expect(enhanced_formatters.quality.test_quality.log_debug).to.be.a("function")
  end)

  it("creates test-specific loggers", function()
    local test_logger = formatter_integration.create_test_logger("Test Name", { component = "test" })

    expect(test_logger).to.exist()
    expect(test_logger.info).to.be.a("function")
    expect(test_logger.debug).to.be.a("function")
    expect(test_logger.error).to.be.a("function")
    expect(test_logger.warn).to.be.a("function")
    expect(test_logger.with_context).to.be.a("function")
    expect(test_logger.step).to.be.a("function")
  end)

  it("creates step-specific loggers", function()
    local test_logger = formatter_integration.create_test_logger("Test Name", { component = "test" })

    local step_logger = test_logger.step("Step 1")

    expect(step_logger).to.exist()
    expect(step_logger.info).to.be.a("function")

    -- Try logging with the step logger
    step_logger.info("Step message")

    -- No assertions here since we can't easily verify the log output
    -- But we can ensure the function doesn't throw errors
  end)

  it("creates a log formatter", function()
    local log_formatter = formatter_integration.create_log_formatter()

    expect(log_formatter).to.exist()
    expect(log_formatter.init).to.be.a("function")
    expect(log_formatter.format).to.be.a("function")
    expect(log_formatter.format_json).to.be.a("function")
    expect(log_formatter.format_text).to.be.a("function")
  end)

  it("integrates with the reporting system", function()
    local reporting = require("lib.reporting")

    local result = formatter_integration.integrate_with_reporting()
    expect(result).to.exist()

    -- Verify enhanced reporting functions
    expect(reporting.test_start).to.be.a("function")
    expect(reporting.test_end).to.be.a("function")
    expect(reporting.generate).to.be.a("function")
  end)

  it("creates JSON formatted output", function()
    local temp_dir = test_helper.create_temp_test_directory()
    local output_file = temp_dir:create_file("test_results.json", "")

    local formatter = formatter_integration.create_log_formatter()
    expect(formatter).to.exist()

    formatter:init({ format = "json", output_file = output_file })

    local result = formatter:format({
      tests = {
        { name = "test1", status = "passed", duration = 100 },
      },
      total = 1,
      passed = 1,
      failed = 0,
      pending = 0,
      success_percent = 100,
      duration = 100,
    })

    expect(result).to.exist()
    expect(result.output_file).to.exist()
  end)

  -- Add more tests for other formatter integration functionality
end)
