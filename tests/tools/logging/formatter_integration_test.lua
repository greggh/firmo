-- Logging Formatter Integration Module Tests
-- Tests for the logging formatter integration functionality

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local formatter_integration = require("lib.tools.logging.formatter_integration")
local logging = require("lib.tools.logging")

describe("Logging Formatter Integration Module", function()
  it("enhances formatters with logging capabilities", function()
    -- Create a mock formatters module
    local formatters = {
      available_formatters = {
        test = {
          type = "test",
          name = "test",
        },
      },
      init = function()
        return true
      end,
    }

    -- Mock the try_require function to return our mock formatters
    local original_try_require = _G.try_require
    _G.try_require = function(name)
      if name == "lib.reporting.formatters" then
        return formatters
      end
      return nil
    end

    -- Test enhancement
    local result, err = formatter_integration.enhance_formatters()

    -- Restore original function
    _G.try_require = original_try_require

    -- Verify enhancement
    expect(err).to_not.exist()
    expect(result).to.exist()
    expect(formatters.available_formatters.test._logger).to.exist()
    expect(formatters.available_formatters.test.log_debug).to.be.a("function")
    expect(formatters.available_formatters.test.log_info).to.be.a("function")
    expect(formatters.available_formatters.test.log_error).to.be.a("function")
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
    -- Skip test if reporting module is not available
    if not pcall(require, "lib.reporting") then
      return
    end

    local result = formatter_integration.integrate_with_reporting()
    expect(result).to.exist()
    
    -- Verify enhanced reporting functions
    local reporting = require("lib.reporting")
    expect(reporting.test_start).to.be.a("function")
    expect(reporting.test_end).to.be.a("function")
    expect(reporting.generate).to.be.a("function")
  end)
  
  it("creates JSON formatted output", function()
    local temp_dir = require("lib.tools.test_helper").create_temp_test_directory()
    local output_file = temp_dir.create_file("test_results.json", "")
    
    local formatter = formatter_integration.create_log_formatter()
    expect(formatter).to.exist()
    
    formatter:init({ format = "json", output_file = output_file })
    
    local result = formatter:format({
      tests = {
        { name = "test1", status = "passed", duration = 100 }
      },
      total = 1,
      passed = 1,
      failed = 0,
      pending = 0,
      success_percent = 100,
      duration = 100
    })
    
    expect(result).to.exist()
    expect(result.output_file).to.exist()
  end)

  -- Add more tests for other formatter integration functionality
end)
end)
