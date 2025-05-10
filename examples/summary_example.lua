--- summary_example.lua
---
--- Example demonstrating text-based summary output for both test results and coverage data with firmo.
---
--- This example shows how to:
--- - Generate text-based summary reports using `reporting.format_coverage`.
--- - Configure summary-specific formatting options (colors, verbosity, sections, etc.) via `central_config.set()`.
--- - Save summary reports to disk using `fs.write_file`.
--- - Use `test_helper` for managing temporary output files.
--- - Discuss terminal integration and viewing practices.
---
--- @module examples.summary_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.reporting.formatters.summary
--- @see lib.core.central_config
--- @see lib.tools.test_helper
--- @usage
--- Run embedded tests:
--- ```bash
--- lua firmo.lua examples/summary_example.lua
--- ```
--- The generated text reports will be saved to a temporary directory.
---

-- Import required modules
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local test_helper = require("lib.tools.test_helper") -- Added missing require
local logging = require("lib.tools.logging") -- Added missing require

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
local before = firmo.before -- Added missing require
local after = firmo.after -- Added missing require

-- Setup logger
local logger = logging.get_logger("SummaryExample")

-- Mock test results data (consistent with other examples)
--- @type MockTestResults (See csv_example.lua for definition)
local mock_test_results = {
  name = "Summary Example Test Suite",
  timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
  tests = 8,
  failures = 1,
  errors = 1,
  skipped = 1,
  time = 0.35, -- Execution time in seconds
  test_cases = {
    {
      name = "validates positive numbers correctly",
      classname = "NumberValidator",
      time = 0.001,
      status = "pass",
    },
    {
      name = "validates negative numbers correctly",
      classname = "NumberValidator",
      time = 0.003,
      status = "pass",
    },
    {
      name = "validates zero correctly",
      classname = "NumberValidator",
      time = 0.001,
      status = "pass",
    },
    {
      name = "rejects non-numeric inputs",
      classname = "NumberValidator",
      time = 0.002,
      status = "pass",
    },
    {
      name = "handles boundary values correctly",
      classname = "NumberValidator",
      time = 0.015,
      status = "fail",
      failure = {
        message = "Expected validation to pass for MAX_INT but it failed",
        type = "AssertionError",
        details = "test/number_validator_test.lua:42: Expected isValid(9223372036854775807) to be true, got false",
      },
    },
    {
      name = "throws appropriate error for invalid format",
      classname = "NumberValidator",
      time = 0.005,
      status = "error",
      error = {
        message = "Runtime error in test",
        type = "Error",
        details = "test/number_validator_test.lua:53: attempt to call nil value (method 'formatError')",
      },
    },
    {
      name = "validates scientific notation",
      classname = "NumberValidator",
      time = 0.000,
      status = "skipped",
      skip_message = "Scientific notation validation not implemented yet",
    },
    {
      name = "validates decimal precision correctly",
      classname = "NumberValidator",
      time = 0.002,
      status = "pass",
    },
  },
}

-- Mock coverage data (consistent with other examples)
--- @type MockCoverageData (See json_example.lua for definition)
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = { hits = 1 },
        [2] = { hits = 1 },
        [3] = { hits = 1 },
        [5] = { hits = 0 },
        [6] = { hits = 1 },
        [8] = { hits = 0 },
        [9] = { hits = 0 },
      },
      functions = {
        ["add"] = { execution_count = 1 },
        ["subtract"] = { execution_count = 1 },
        ["multiply"] = { execution_count = 0 },
        ["divide"] = { execution_count = 0 },
      },
      total_lines = 10,
      executable_lines = 7,
      covered_lines = 4,
      total_functions = 4,
      covered_functions = 2,
      line_coverage_percent = (4 / 7) * 100,
      function_coverage_percent = (2 / 4) * 100,
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = { hits = 1 },
        [2] = { hits = 1 },
        [4] = { hits = 1 },
        [5] = { hits = 1 },
        [7] = { hits = 0 },
      },
      functions = {
        ["validate"] = { execution_count = 1 },
        ["format"] = { execution_count = 0 },
      },
      total_lines = 8,
      executable_lines = 5,
      covered_lines = 4,
      total_functions = 2,
      covered_functions = 1,
      line_coverage_percent = (4 / 5) * 100,
      function_coverage_percent = (1 / 2) * 100,
    },
  },
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 18,
    executable_lines = 12,
    covered_lines = 8,
    total_functions = 6,
    covered_functions = 3,
    line_coverage_percent = (8 / 12) * 100,
    function_coverage_percent = (3 / 6) * 100,
    overall_percent = (8 / 12) * 100,
  },
}

-- Create tests to demonstrate the Summary formatter
--- Test suite demonstrating the summary report formatter.
--- @within examples.summary_example
describe("Summary Formatter Example", function()
  local temp_dir -- Temp dir helper from test_helper

  --- Setup: Create temp directory.
  before(function()
    temp_dir = test_helper.create_temp_test_directory("summary_example_")
  end)

  --- Teardown: Release temp dir reference.
  after(function()
    temp_dir = nil
end)

  --- Tests basic summary report generation for coverage data.
  it("generates basic summary coverage report", function()
    -- Reset config
    central_config.reset("reporting.formatters.summary")

    -- Generate basic summary coverage report
    logger.info("Generating basic summary coverage report...")
    local summary_report, format_err = reporting.format_coverage(mock_coverage_data, "summary")
    expect(format_err).to_not.exist("Formatting should succeed") -- Use to_not.exist instead of to.be.nil

    -- Validate the report
    expect(summary_report).to.exist()
    expect(summary_report).to.be.a("table") -- Expect table with output field
    expect(summary_report.output).to.be.a("string")
    expect(summary_report.output).to.match("Coverage Summary")
    expect(summary_report.output).to.match("Overall Coverage:") -- Update pattern to match actual output
    expect(summary_report.output).to.match("Files:")

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-summary.txt") -- Use temp_dir
    local success, err_str = fs.write_file(file_path, summary_report.output) -- Use .output field

    -- Check if write was successful
    expect(err_str).to_not.exist("Writing coverage summary should succeed")
    expect(success).to.be_truthy()

    -- Log with proper string formatting
    logger.info("Basic summary coverage report saved to: " .. file_path)
    logger.info("Report size: " .. #summary_report.output .. " bytes")

    -- Preview the summary output
    print("\nSummary Coverage Report Preview:")
    print(summary_report.output) -- Use .output field
  end)

end) -- Close describe block for "Summary Formatter Example"

logger.info("\n=== Summary Formatter Example ===")
logger.info("This example demonstrates how to generate terminal-friendly text-based summary reports.")
logger.info("Summary format is ideal for quick feedback in CI/CD systems and local development.")

logger.info("\nTo run this example directly:")
logger.info("  lua examples/summary_example.lua")

logger.info("\nOr run it with firmo's test runner:")
logger.info("  lua firmo.lua examples/summary_example.lua")

logger.info("\nCommon summary configurations:")
logger.info("- use_colors: true|false - Enable terminal colors")
logger.info("- verbosity: minimal|normal|detailed - Control output detail level")
logger.info("- unicode_symbols: true|false - Use fancy symbols if terminal supports it")
logger.info("- terminal_width: number - Target width for formatting")
logger.info("- sections: table - Enable/disable specific sections")

logger.info("\nExample complete!")
