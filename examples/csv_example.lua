--- Example demonstrating CSV report generation for test results and coverage data.
---
--- This example showcases how to generate Comma-Separated Value (CSV) reports
--- using Firmo's reporting module for both test results and code coverage.
--- It covers:
--- - Generating CSV reports using `reporting.format_results()` and `reporting.format_coverage()`.
--- - Using mock data structures (`mock_test_results`, `mock_coverage_data`) for demonstration.
--- - Configuring CSV-specific options (delimiter, header inclusion, quoting, column selection) via `central_config.set()`.
--- - Saving the generated CSV reports to files within a temporary directory managed by `test_helper`.
--- - A simplified example of parsing the generated CSV content for basic analysis.
--- - Discussion of how CSV reports can integrate with external data analysis tools (e.g., spreadsheets, R, Python).
---
--- @module examples.csv_example
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
  --- @field lines table<number, { executable: boolean, execution_count: number }> Line coverage data.
  --- @field functions table<string, FunctionCoverageData> Function coverage data.
  --- @field total_lines number Total lines in the file.
  --- @field executable_lines number Total executable lines in the file.
  --- @field covered_lines number Number of executable lines covered (execution_count > 0).
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
      executable_lines = 7, -- Based on lines table keys
      covered_lines = 4, -- Based on execution_count > 0
      total_functions = 4,
      covered_functions = 2, -- Based on execution_count > 0
      line_coverage_percent = (4 / 7) * 100, -- Recalculated
      function_coverage_percent = (2 / 4) * 100, -- Recalculated
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
      executable_lines = 5, -- Based on lines table keys
      covered_lines = 4, -- Based on execution_count > 0
      total_functions = 2,
      covered_functions = 1, -- Based on execution_count > 0
      line_coverage_percent = (4 / 5) * 100, -- Recalculated
      function_coverage_percent = (1 / 2) * 100, -- Recalculated
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
    local csv_report = reporting.format_results(mock_test_results, "csv")

    -- Validate the report
    expect(csv_report).to.exist()
    expect(csv_report).to.be.a("string")
    expect(csv_report).to.match("test_id,test_suite,test_name,status") -- Should have header
    expect(csv_report).to.match("NumberValidator,validates positive numbers correctly,pass")
    local success, err = fs.write_file(file_path, csv_report)

    -- Check if write was successful
    expect(err).to.be_nil() -- Check for nil error string
    expect(success).to.be_truthy()

    logger.info("Basic CSV test results saved to: " .. file_path)
    logger.info("Report size: " .. #csv_report .. " bytes")

    -- Preview the CSV output
    logger.info("\nCSV Test Results Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Test case for generating a basic CSV report for coverage data using default settings.
  it("generates basic CSV coverage report with default configuration", function()
    -- Reset config to ensure defaults are used
    central_config.reset("reporting.formatters.csv")

    -- Generate CSV coverage report
    logger.info("Generating basic CSV coverage report...")

    -- Check if write was successful
    expect(success).to.be_truthy()

    logger.info("Basic CSV test results saved to: " .. file_path)
    logger.info("Report size: " .. #csv_report .. " bytes")

    -- Preview the CSV output
    logger.info("\nCSV Test Results Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Test case for generating a basic CSV report for coverage data.
  it("generates basic CSV coverage report", function()
    -- Generate CSV coverage report
    logger.info("Generating basic CSV coverage report...")
    local csv_report = reporting.format_coverage(mock_coverage_data, "csv")

    -- Validate the report
    expect(csv_report).to.exist()
    expect(csv_report).to.be.a("string")
    expect(csv_report).to.match("file,total_lines,covered_lines,coverage_percent") -- Should have header

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-report.csv")
    local success, err = fs.write_file(file_path, csv_report)

    local success, err = fs.write_file(file_path, csv_report)

    -- Check if write was successful
    expect(err).to.be_nil() -- Check for nil error string
    expect(success).to.be_truthy()

    logger.info("Basic CSV coverage report saved to: " .. file_path)
    logger.info("Report size: " .. #csv_report .. " bytes")

    -- Preview the CSV output
    logger.info("\nCSV Coverage Report Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

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
    expect(csv_report).to.match("test_id;test_suite;test_name") -- Should use semicolon delimiter
    expect(csv_report).to.match("duration;error_message") -- Should include configured columns
    expect(csv_report).to.match(';"Expected error not thrown";') -- Check quoted message with semicolon

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "test-results-configured.csv")
    local success, err = fs.write_file(file_path, csv_report)

    -- Check if write was successful
    expect(err).to.be_nil() -- Check for nil error string
    expect(success).to.be_truthy()

    logger.info("Configured CSV test results saved to: " .. file_path)

    -- Preview the configured CSV output
    logger.info("\nConfigured CSV Test Results Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Test case for configuring the CSV formatter for coverage reports (columns, function details).
  it("demonstrates CSV formatter configuration for coverage data", function()
    -- Configure CSV formatter options specifically for coverage via central_config
    central_config.set("reporting.formatters.csv", {
      delimiter = ",", -- Back to comma
      include_header = true, -- Include column headers
      include_functions = true, -- Include function coverage details
      include_uncovered = true, -- Include uncovered files/lines
      columns = { -- Custom column selection and order
        "file",
        "total_lines",
        "covered_lines",
        "coverage_percent",
        "total_functions",
        "covered_functions",
        "function_coverage_percent",
      },
    })

    -- Generate CSV report with custom configuration
    logger.info("Generating configured CSV coverage report...")
    local csv_report = reporting.format_coverage(mock_coverage_data, "csv")

    -- Validate the report format
    expect(csv_report).to.exist()
    expect(csv_report).to.match("function_coverage_percent") -- Should include function data

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-report-configured.csv")
    local success, err = fs.write_file(file_path, csv_report)
    local success, err = fs.write_file(file_path, csv_report)

    -- Check if write was successful
    expect(err).to.be_nil() -- Check for nil error string
    expect(success).to.be_truthy()

    logger.info("Configured CSV coverage report saved to: " .. file_path)

    -- Preview the configured CSV output
    logger.info("\nConfigured CSV Coverage Report Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Test case demonstrating simplified parsing and analysis of generated CSV data.
  it("demonstrates post-processing CSV data for analysis", function()
    -- Generate CSV coverage report using default settings for this test
    central_config.reset("reporting.formatters.csv")
    local csv_report = reporting.format_coverage(mock_coverage_data, "csv")
    expect(csv_report).to.exist("CSV report should be generated")

    -- Parse CSV data (simplified example, assumes comma delimiter, no complex quoting/escaping)
    logger.info("Demonstrating basic CSV parsing and analysis...")

    --- Simple CSV parser for demonstration purposes.
    --- NOTE: This is a basic parser and does not handle quoted fields, escaped delimiters, etc.
    --- @param csv_string string The CSV content as a string.
    --- @return table|nil headers An array of header strings, or `nil` if parsing fails.
    --- @return table|nil data An array of tables, where each inner table maps header -> value, or `nil` if parsing fails.
    --- @within examples.csv_example
    local function parse_csv(csv_string)
      local headers = {}
      local data = {}
      local line_num = 0
      for line in csv_string:gmatch("([^\n]+)") do
        line_num = line_num + 1
        local row = {}
        local col_idx = 1
        for value in line:gmatch("([^,]+)") do -- Assumes comma delimiter, no escaping
          if line_num == 1 then
            table.insert(headers, value)
          else
            row[headers[col_idx]] = value
          end
          col_idx = col_idx + 1
        end
        if line_num > 1 then
          table.insert(data, row)
        end
      end
      return headers, data
    end

    -- Parse coverage report
    local headers, data = parse_csv(csv_report)
    -- NOTE: The parser above is a simplified example. For robust parsing,
    -- consider a dedicated CSV library if available, or handle quotes/escapes.

    -- Simple analysis: Calculate average coverage
    local total_coverage = 0
    for _, row in ipairs(data) do
      total_coverage = total_coverage + tonumber(row.coverage_percent)
    end
    local avg_coverage = total_coverage / #data

    logger.info(string.format("Parsed %d data rows with %d columns", #data, #headers))
    logger.info(string.format("Average coverage: %.2f%%", avg_coverage))

    -- Example of generating derived metrics
    logger.info("\nExample derived metrics from CSV data:")
    print("1. Files below 50% coverage:")
    for _, row in ipairs(data) do
      if tonumber(row.coverage_percent) < 50 then
        print(string.format("  - %s: %.1f%%", row.file, tonumber(row.coverage_percent)))
      end
    end

    -- Demonstrate export to another format (e.g., JSON for visualization)
    logger.info("\nExample of exporting to JSON for visualization tools:")
    local json_example = [[
{
  "coverage_data": [
    { "file": "src/calculator.lua", "coverage": 40.0, "color": "#ff6666" },
    { "file": "src/utils.lua", "coverage": 50.0, "color": "#ffcc66" }
  ],
  "metadata": {
    "timestamp": "2025-01-01T00:00:00Z", -- Static timestamp
    "avg_coverage": ]] .. string.format("%.1f", avg_coverage) .. [[
  }
}]]
    print(json_example)
  end)

  --- Informational test case discussing integration with external data analysis tools.
  it("discusses integration with data analysis tools", function()
    -- Generate both test and coverage CSV reports with default settings
    central_config.reset("reporting.formatters.csv")
    local test_csv = reporting.format_results(mock_test_results, "csv")
    local coverage_csv = reporting.format_coverage(mock_coverage_data, "csv")

    -- Save to files that data analysis tools would typically use
    local test_file = fs.join_paths(temp_dir.path, "test-data.csv")
    local coverage_file = fs.join_paths(temp_dir.path, "coverage-data.csv")

    local success_test, err_test = fs.write_file(test_file, test_csv)
    local success_cov, err_cov = fs.write_file(coverage_file, coverage_csv)
    expect(err_test).to.be_nil()
    expect(err_cov).to.be_nil()
    logger.info("Test and coverage CSV files saved for external analysis demonstration.")

    -- Log information about using the generated CSVs
    logger.info("\nData Analysis Tool Integration Examples:")

    -- R examples
    logger.info("\nData can be imported into tools like R, Python (pandas), or spreadsheets.")
    -- Removed incomplete R example code block
  end)
end)
