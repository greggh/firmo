--- html_report_example.lua
--
-- This example demonstrates generating HTML format test result reports using
-- Firmo's reporting module, specifically focusing on the `auto_save_reports`
-- function and configuring HTML options via `central_config`.
--
-- It shows:
-- - Generating an HTML report using `reporting.auto_save_reports`.
-- - Passing mock test result data to the function.
-- - Configuring HTML-specific options (theme, title) within the `auto_save_reports` call.
-- - Using `test_helper` to manage the temporary output directory.
--
-- Run embedded tests: lua test.lua examples/html_report_example.lua
--

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
local logger = logging.get_logger("HTMLReportExample")

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
--- @within examples.html_report_example
local test_results = {
  name = "HTML Report Example",
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

--- Test suite demonstrating HTML report generation for test results using `auto_save_reports`.
--- @within examples.html_report_example
describe("HTML Report Generator", function()
  local temp_dir -- Stores the temporary directory helper object

  --- Setup hook: Create a temporary directory for the report.
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  --- Teardown hook: Release reference. Directory cleaned automatically by `test_helper`.
  after(function()
    temp_dir = nil
  end)

  --- Tests generating an HTML report using `reporting.auto_save_reports` and custom configuration.
  it("generates HTML report using auto_save_reports with custom config", function()
    -- Configure HTML report options
    local config = {
      report_dir = temp_dir.path,
      formats = { "html" }, -- Only generate HTML
      results_path_template = "test-results-{format}", -- Custom filename pattern
      html = {
        theme = "dark",
        title = "HTML Test Results",
        syntax_highlighting = false, -- Example: disable syntax highlighting
      },
    }

    -- Save HTML report using auto_save_reports
    -- Pass nil for coverage/quality data, pass test_results data, pass config
    logger.info("Generating HTML report using auto_save_reports...")
    local results = reporting.auto_save_reports(nil, nil, test_results, config)

    -- Verify the HTML report was created successfully
    expect(results.html).to.exist("HTML results entry should exist")
    expect(results.html.success).to.be_truthy("HTML report saving should succeed")
    expect(results.html.path).to.be.a("string", "HTML report path should be returned")

    if results.html.success then
      logger.info("HTML report generation successful.")
      logger.info("Report saved to: " .. results.html.path)
    else
      logger.error("Failed to generate HTML report", { error = results.html.error })
    end
  end)
end)

-- Add cleanup for temp_file module at the end
temp_file.cleanup_all()
