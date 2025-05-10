--- This example demonstrates generating JUnit XML format test result reports using
--- Firmo's reporting module, specifically focusing on the `auto_save_reports`
-- function and configuring JUnit options via `central_config`.
--
-- It shows:
-- - Generating a JUnit XML report using `reporting.auto_save_reports`.
-- - Passing mock test result data to the function.
-- - Configuring JUnit-specific options within the `auto_save_reports` call.
--- - Using `test_helper` to manage the temporary output directory.
---
--- @module examples.junit_report_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.reporting
--- @see lib.reporting.formatters.junit
--- @see lib.tools.test_helper
--- @usage
--- Run embedded tests: lua firmo.lua examples/junit_report_example.lua
---

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after

-- Import required modules
local reporting = require("lib.reporting")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")
local temp_file = require("lib.tools.filesystem.temp_file") -- For cleanup

-- Setup logger
local logger = logging.get_logger("JUnitReportExample")

-- Mock test results data structure for demonstration.
--- @class MockTestResults
--- @field name string The name of the test suite.
--- @field timestamp string ISO 8601 timestamp of the test run.
--- @field tests number Total number of tests executed.
--- @field failures number Number of tests that failed assertions.
--- @field errors number Number of tests that encountered runtime errors.
--- @field skipped number Number of tests that were skipped.
--- @field time number Total execution time in seconds.
--- @field test_cases TestCaseData[] An array of individual test case results.
--- @within examples.junit_report_example

--- @class TestCaseData
--- @field name string Name of the test case.
--- @field classname string Name of the test suite/class containing the test.
--- @field time number Execution time for this test case in seconds.
--- @field status "pass"|"fail"|"error"|"skipped"|"pending" The status of the test.
--- @field failure? { message: string, type: string, details?: string } Failure details if status is "fail".
--- @field error? { message: string, type: string, details?: string } Error details if status is "error".
--- @field skip_message? string Reason for skipping if status is "skipped".
--- @within examples.junit_report_example

local test_results = {
  name = "JUnit Report Example",
  timestamp = "2025-01-01T00:00:00Z", -- Static timestamp
  tests = 8,
  failures = 1,
  errors = 1,
  skipped = 1,
  time = 0.15, -- Execution time in seconds
  --- @class TestCaseData
  --- @field name string Name of the test case.
  --- @field classname string Name of the test suite/class containing the test.
  --- @field time number Execution time for this test case in seconds.
  --- @field status "pass"|"fail"|"error"|"skipped"|"pending" The status of the test.
  --- @field failure? { message: string, type: string, details?: string } Failure details if status is "fail".
  --- @field error? { message: string, type: string, details?: string } Error details if status is "error".
  --- @field skip_message? string Reason for skipping if status is "skipped".
  test_cases = {
    {
      name = "addition works correctly",
      classname = "Calculator.BasicMath",
      time = 0.001,
      status = "pass",
    },
    {
      name = "subtraction works correctly",
      classname = "Calculator.BasicMath",
      time = 0.001,
      status = "pass",
    },
    {
      name = "multiplication works correctly",
      classname = "Calculator.BasicMath",
      time = 0.001,
      status = "pass",
    },
    {
      name = "division works correctly",
      classname = "Calculator.BasicMath",
      time = 0.001,
      status = "pass",
    },
    {
      name = "division by zero throws error",
      classname = "Calculator.ErrorHandling",
      time = 0.002,
      status = "fail",
      failure = {
        message = "Expected error not thrown",
        type = "AssertionError",
        details = "Expected function to throw 'Division by zero' error\nBut no error was thrown",
      },
    },
    {
      name = "square root of negative numbers",
      classname = "Calculator.AdvancedMath",
      time = 0.001,
      status = "error",
      error = {
        message = "Runtime error in test",
        type = "Error",
        details = "attempt to call nil value (method 'sqrt')",
      },
    },
    {
      name = "logarithm calculations",
      classname = "Calculator.AdvancedMath",
      time = 0.000,
      status = "skipped",
      skip_message = "Advanced math module not implemented",
    },
    {
      name = "rounding behavior",
      classname = "Calculator.AdvancedMath",
      time = 0.001,
      status = "pass",
    },
  },
}

--- Test suite demonstrating JUnit XML report generation for test results using `auto_save_reports`.
--- @within examples.junit_report_example
describe("JUnit Report Generator", function()
  local temp_dir -- Stores the temporary directory helper object

  --- Setup hook: Create a temporary directory for the report.
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  --- Teardown hook: Release reference. Directory cleaned automatically by `test_helper`.
  after(function()
    temp_dir = nil
  end)

  --- Tests generating a JUnit XML report using `reporting.auto_save_reports` and custom configuration.
  it("generates test results report using auto_save_reports with custom config", function()
    -- Configure report options based on the documentation
    local config = {
      report_dir = temp_dir.path,
      formats = {
        results = {
          default = "junit"  -- Just set the default format for results
        }
      },
      formatters = {
        junit = {  -- JUnit-specific config
          include_timestamps = true,
          include_properties = true
        }
      }
    }

    logger.info("Generating JUnit test results report using auto_save_reports...")
    local results = reporting.auto_save_reports(nil, nil, test_results, config)

    -- Verify the results
    expect(results.junit).to.exist("JUnit results entry should exist")
    expect(results.junit.success).to.be_truthy("JUnit report saving should succeed")
    expect(results.junit.path).to.be.a("string", "JUnit report path should be returned")

    if results.junit.success then
      logger.info("JUnit report generation successful.")
      logger.info("Report saved to: " .. results.junit.path)
    else
      logger.error("Failed to generate JUnit report", { error = results.junit.error })
    end
  end)
end)

-- Cleanup is handled automatically by test_helper registration
