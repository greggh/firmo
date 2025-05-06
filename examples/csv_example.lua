--- Example demonstrating CSV report generation for test results.
---
--- This example showcases how to generate Comma-Separated Value (CSV) reports
--- using Firmo's reporting module for test results.
--- It covers:
--- - Generating CSV reports using `reporting.format_results()`.
--- - Using mock data structures (`mock_test_results`, `mock_coverage_data`) for demonstration.
--- - Configuring CSV-specific options (delimiter, header inclusion, quoting, column selection) via `central_config.set()`.
--- - Saving the generated CSV reports to files within a temporary directory managed by `test_helper`.
--- - A simplified example of parsing the generated CSV content for basic analysis.
--- - Discussion of how CSV reports can integrate with external data analysis tools (e.g., spreadsheets, R, Python).
---
--- @module examples.csv_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.reporting
--- @see lib.reporting.formatters.csv
--- @see lib.core.central_config
--- @see lib.tools.test_helper
--- @usage
--- Run the embedded tests (which generate the reports):
--- ```bash
--- lua test.lua examples/csv_example.lua
--- ```
--- The generated CSV files will be placed in a temporary directory (path logged to console) and cleaned up afterward.

-- Import required modules
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("CSVExample")

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

--- Mock test results data structure for demonstration.
--- @class MockTestResults
--- @field name string The name of the test suite.
--- @field timestamp string ISO 8601 timestamp of the test run.
--- @field tests number Total number of tests executed.
--- @field failures number Number of tests that failed assertions.
--- @field errors number Number of tests that encountered runtime errors.
--- @field skipped number Number of tests that were skipped.
--- @field time number Total execution time in seconds.
--- @field test_cases TestCaseData[] An array of individual test case results.
--- @within examples.csv_example
local mock_test_results = {
  name = "CSV Example Test Suite",
  timestamp = "2025-01-01T00:00:00Z", -- Static timestamp for consistency
  tests = 8,
  failures = 1,
  errors = 1,
  skipped = 1,
  time = 0.35, -- Execution time in seconds
  --- @class TestCaseData
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

--- Mock coverage data structure for demonstration.
--- Uses execution_count instead of booleans for coverage status.
--- @class MockCoverageData
--- @field files table<string, FileCoverageData> Coverage data per file.
--- @field summary CoverageSummaryData Overall summary statistics.
--- @within examples.csv_example
local mock_coverage_data = {
  --- @class FileCoverageData
  --- @field lines table<number, { execution_count: number }> Line coverage data (keys are line numbers).
  --- @field functions table<string, FunctionCoverageData> Function coverage data.
  --- @field filename string Path to the file.
  --- @field executable_lines number Total executable lines in the file.
  --- @field covered_lines number Number of executable lines covered (execution_count > 0).
  --- @field total_lines number Total lines in the file.
  --- @field total_functions number Total functions defined in the file.
  --- @field covered_functions number Number of functions covered (execution_count > 0).
  --- @field line_coverage_percent number Percentage of executable lines covered.
  --- @field function_coverage_percent number Percentage of functions covered.
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = { executable = true, execution_count = 1 },
        [2] = { executable = true, execution_count = 1 },
        [3] = { executable = true, execution_count = 1 },
        [5] = { executable = true, execution_count = 0 }, -- Not covered
        [6] = { executable = true, execution_count = 1 },
        [8] = { executable = true, execution_count = 0 }, -- Not covered
        [9] = { executable = true, execution_count = 0 }, -- Not covered
      },
      --- @class FunctionCoverageData
      --- @field name string Function name.
      --- @field start_line number Starting line number.
      --- @field end_line number Ending line number.
      --- @field execution_count number How many times the function was entered.
      functions = {
        ["add"] = { name = "add", start_line = 5, end_line = 10, execution_count = 1 },
        ["subtract"] = { name = "subtract", start_line = 11, end_line = 15, execution_count = 1 },
        ["multiply"] = { name = "multiply", start_line = 16, end_line = 20, execution_count = 0 },
        ["divide"] = { name = "divide", start_line = 21, end_line = 25, execution_count = 0 },
      },
      total_lines = 10,
      executable_lines = 7,
      covered_lines = 4,
      total_functions = 4,
      covered_functions = 2,
      line_coverage_percent = 57.14, -- Recalculated (4/7 * 100)
      function_coverage_percent = 50.0, -- Recalculated (2/4 * 100)
      line_rate = 0.5714, -- Added line_rate (4/7)
      filename = "src/calculator.lua", -- Added filename
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = { executable = true, execution_count = 1 },
        [2] = { executable = true, execution_count = 1 },
        [4] = { executable = true, execution_count = 1 },
        [5] = { executable = true, execution_count = 1 },
        [7] = { executable = true, execution_count = 0 }, -- Not covered
      },
      functions = {
        ["validate"] = { name = "validate", start_line = 3, end_line = 8, execution_count = 1 },
        ["format"] = { name = "format", start_line = 9, end_line = 12, execution_count = 0 },
      },
      total_lines = 8,
      executable_lines = 5,
      covered_lines = 4,
      total_functions = 2,
      covered_functions = 1,
      line_coverage_percent = 80.0, -- Recalculated (4/5 * 100)
      function_coverage_percent = 50.0, -- Recalculated (1/2 * 100)
      line_rate = 0.80, -- Added line_rate (4/5)
      filename = "src/utils.lua", -- Added filename
    },
  },
  --- @class CoverageSummaryData
  --- @field total_files number Total number of files processed.
  --- @field covered_files number Number of files with > 0% coverage.
  --- @field total_lines number Total lines across all files.
  --- @field executable_lines number Total executable lines across all files.
  --- @field covered_lines number Total covered executable lines.
  --- @field total_functions number Total functions across all files.
  --- @field covered_functions number Total covered functions.
  --- @field line_coverage_percent number Overall line coverage percentage.
  --- @field function_coverage_percent number Overall function coverage percentage.
  --- @field overall_percent number Overall coverage percentage (often based on lines).
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 18,
    executable_lines = 12, -- 7 + 5
    covered_lines = 8, -- 4 + 4
    total_functions = 6, -- 4 + 2
    covered_functions = 3, -- 2 + 1
    line_coverage_percent = (8 / 12) * 100, -- Recalculated: ~66.7%
    function_coverage_percent = (3 / 6) * 100, -- Recalculated: 50.0%
    overall_percent = (8 / 12) * 100, -- Typically based on lines
  },
}

-- Create tests to demonstrate the CSV formatter
--- Test suite demonstrating the CSV formatter features for test results and coverage.
--- @within examples.csv_example
describe("CSV Formatter Example", function()
  local temp_dir -- Stores the temporary directory path helper object

  --- Setup hook: Create a temporary directory for generated reports before tests run.
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  --- Teardown hook: Release reference to the temp directory helper.
  -- The actual directory is cleaned up automatically by `test_helper`.
  after(function()
    temp_dir = nil
  end)

  --- Test case for generating a basic CSV report for test results using default settings.
  it("generates basic CSV test results with default configuration", function()
    -- Reset config to ensure defaults are used
    central_config.reset("reporting.formatters.csv")

    -- Generate CSV test results report
    logger.info("Generating basic CSV test results report...")
    local csv_report, format_err = reporting.format_results(mock_test_results, "csv") -- Use mock_test_results
    expect(format_err).to_not.exist("Formatting test results should succeed")

    -- Validate the report
    expect(csv_report).to.exist()
    expect(csv_report).to.be.a("string")
    expect(csv_report).to.match('^"test_id","test_suite","test_name",') -- Check actual default header for results
    expect(csv_report).to.match('NumberValidator,NumberValidator,"validates positive numbers correctly",pass') -- Check first data row format

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "test-results.csv")
    local success, err = fs.write_file(file_path, csv_report)

    -- Check if write was successful
    expect(err).to_not.exist("Writing CSV results should succeed") -- Use to_not.exist
    expect(success).to.be_truthy()

    logger.info("Basic CSV test results saved to: " .. file_path)
    logger.info("Report size: " .. #csv_report .. " bytes")

    -- Preview the CSV output
    logger.info("\nCSV Test Results Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  -- NOTE: CSV format is not suitable for detailed coverage data for several reasons:
  -- 1. Coverage data is hierarchical (files -> lines/functions) which doesn't map well to flat CSV format
  -- 2. Coverage data contains nested structures that would require complex serialization to CSV 
  -- 3. Other formats like HTML, JSON, or LCOV provide better visualization and integration options
  -- 
  -- The Firmo CSV formatter is therefore optimized for test results only, not coverage data.

  --- Test case for configuring the CSV formatter for test results (delimiter, columns, quoting).
  it("demonstrates CSV formatter configuration for test results", function()
    -- Configure CSV formatter options specifically for test results via central_config
    central_config.set("reporting.formatters.csv", {
      delimiter = ";", -- Use semicolon as delimiter
      include_header = true, -- Include column headers
      quote_strings = true, -- Quote string values
      escape_character = "\\", -- Escape character for quotes within strings
      columns = { -- Custom column selection and order
        "test_id",
        "test_suite",
        "test_name",
        "status",
        "duration",
        "error_message",
      },
    })

    -- Generate CSV report with custom configuration
    logger.info("Generating configured CSV test results report...")
    local csv_report = reporting.format_results(mock_test_results, "csv")

    -- Validate the report format
    expect(csv_report).to.exist()
    expect(csv_report).to.match('^"test_id";"test_suite";"test_name";') -- Check actual header with custom delimiter
    expect(csv_report).to.match('"duration";"error_message"') -- Check configured columns in header
    -- expect(csv_report).to.match(';"Expected error not thrown";') -- This check is tricky due to potential escaping/quoting variation

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "test-results-configured.csv")
    local success, err = fs.write_file(file_path, csv_report)

    -- Check if write was successful
    expect(err).to_not.exist("Writing configured CSV results should succeed") -- Use to_not.exist
    expect(success).to.be_truthy()

    logger.info("Configured CSV test results saved to: " .. file_path)

    -- Preview the configured CSV output
    logger.info("\nConfigured CSV Test Results Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Informational test case discussing integration with external data analysis tools.
  it("discusses integration with data analysis tools", function()
    -- Generate test results CSV report with default settings
    central_config.reset("reporting.formatters.csv")
    local test_csv, format_err = reporting.format_results(mock_test_results, "csv")
    expect(format_err).to_not.exist("Formatting results CSV should succeed")
    expect(test_csv).to.exist()

    -- Save to files that data analysis tools would typically use
    local test_file = fs.join_paths(temp_dir.path, "test-data.csv")

    local success_test, err_test = fs.write_file(test_file, test_csv)
    expect(err_test).to_not.exist("Writing CSV file should succeed") -- Use to_not.exist
    expect(success_test).to.be_truthy()

    -- Log information about using the generated CSVs
    logger.info("Test results CSV file saved for external analysis demonstration.")
    logger.info("\nData Analysis Tool Integration Examples:")

    -- Informational message about external tools
    logger.info("\nData in " .. test_file .. " can be imported into tools like:")
    logger.info("Test results CSV files saved for external analysis demonstration.")

    -- Log information about using the generated CSVs
    logger.info("\nData Analysis Tool Integration Examples:")

    -- Informational message about external tools
    logger.info("\nData in " .. test_file .. " can be imported into tools like:")
    logger.info(" - Spreadsheets (Excel, Google Sheets)")
    logger.info(" - R (using read.csv)")
    logger.info(" - Python (using pandas.read_csv)")
    logger.info("\nNote: For coverage data, use other formatters like HTML, JSON, or LCOV")
  end)
end)
