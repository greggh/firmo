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

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after -- Import before/after for setup

-- Import required modules
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem") -- Keep for path joining if needed
local reporting = require("lib.reporting")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config") -- For consistency
local temp_file = require("lib.tools.filesystem.temp_file") -- For cleanup

-- Setup logger
local logger = logging.get_logger("HTMLReportExample")

-- Mock test results data
local test_results = {
  name = "HTML Report Example",
  timestamp = "2025-01-01T00:00:00Z", -- Static timestamp
  tests = 8,
  failures = 1,
  errors = 1,
  skipped = 1,
  time = 0.15, -- Execution time in seconds
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

--- Test suite demonstrating HTML report generation for test results.
describe("HTML Report Generator", function()
  local temp_dir

  -- Create a temp directory before tests
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  -- Clean up temp directory reference after tests
  after(function()
    temp_dir = nil
  end)

  it("generates HTML report using auto_save_reports with config", function()
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

    if results.html.success then
      logger.info("HTML report saved to directory: " .. temp_dir.path)
      logger.info("HTML report file: " .. results.html.path)
    else
      logger.error("Failed to generate HTML report", { error = results.html.error })
    end
  end)
end)

-- Add cleanup for temp_file module at the end
temp_file.cleanup_all()
