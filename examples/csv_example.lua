--- csv_example.lua
--
-- This example demonstrates generating Comma-Separated Value (CSV) format reports
-- for both test results and coverage data using Firmo's reporting module.
-- It shows how to:
-- - Generate CSV reports using `reporting.format_results` and `reporting.format_coverage`.
-- - Configure CSV-specific options (delimiter, header, columns) via `central_config`.
-- - Save CSV reports to a temporary directory managed by `test_helper`.
-- - Perform basic parsing and analysis of the generated CSV data (example implementation).
-- - Discuss integration with external data analysis tools.
--
-- Run embedded tests: lua test.lua examples/csv_example.lua
--

-- Import firmo (no direct coverage module usage per project rules)
local firmo = require("firmo")

-- Import required modules
local error_handler = require("lib.tools.error_handler")
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("CSVExample")

-- Import test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Mock test results data (consistent with other examples)
local mock_test_results = {
  name = "CSV Example Test Suite",
  timestamp = "2025-01-01T00:00:00Z", -- Static timestamp for consistency
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
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = true, -- This line was covered
        [2] = true, -- This line was covered
        [3] = true, -- This line was covered
        [5] = false, -- This line was not covered
        [6] = true, -- This line was covered
        [8] = false, -- This line was not covered
        [9] = false, -- This line was not covered
      },
      functions = {
        ["add"] = true, -- This function was covered
        ["subtract"] = true, -- This function was covered
        ["multiply"] = false, -- This function was not covered
        ["divide"] = false, -- This function was not covered
      },
      total_lines = 10,
      covered_lines = 4,
      total_functions = 4,
      covered_functions = 2,
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = true, -- This line was covered
        [2] = true, -- This line was covered
        [4] = true, -- This line was covered
        [5] = true, -- This line was covered
        [7] = false, -- This line was not covered
      },
      functions = {
        ["validate"] = true, -- This function was covered
        ["format"] = false, -- This function was not covered
      },
      total_lines = 8,
      covered_lines = 4,
      total_functions = 2,
      covered_functions = 1,
    },
  },
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 18,
    covered_lines = 8,
    total_functions = 6,
    covered_functions = 3,
    line_coverage_percent = 44.4, -- 8/18
    function_coverage_percent = 50.0, -- 3/6
    overall_percent = 47.2, -- (44.4 + 50.0) / 2
  },
}

-- Create tests to demonstrate the CSV formatter
--- Test suite demonstrating the CSV formatter features.
describe("CSV Formatter Example", function()
  local temp_dir

  -- Setup: Create a temporary directory for reports before tests run
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  -- Teardown: Release reference (directory cleaned up by test_helper)
  after(function()
    temp_dir = nil
  end)

  --- Test case for generating a basic CSV report for test results.
  it("generates basic CSV test results", function()
    -- Generate CSV test results report
    logger.info("Generating basic CSV test results report...")
    local csv_report = reporting.format_results(mock_test_results, "csv")

    -- Validate the report
    expect(csv_report).to.exist()
    expect(csv_report).to.be.a("string")
    expect(csv_report).to.match("test_id,test_suite,test_name,status") -- Should have header
    expect(csv_report).to.match("NumberValidator,validates positive numbers correctly,pass")

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "test-results.csv")
    local success, err = fs.write_file(file_path, csv_report)

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

    -- Check if write was successful
    expect(success).to.be_truthy()

    logger.info("Basic CSV coverage report saved to: " .. file_path)
    logger.info("Report size: " .. #csv_report .. " bytes")

    -- Preview the CSV output
    logger.info("\nCSV Coverage Report Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Test case for configuring the CSV formatter (delimiter, columns) for test results.
  it("demonstrates CSV formatter configuration for test results", function()
    -- Configure CSV formatter options via central_config
    central_config.set("reporting.formatters.csv", {
      delimiter = ";", -- Use semicolon as delimiter (common in Europe)
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
    expect(csv_report).to.match("duration;error_message") -- Should include custom columns

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "test-results-configured.csv")
    local success, err = fs.write_file(file_path, csv_report)

    -- Check if write was successful
    expect(success).to.be_truthy()

    logger.info("Configured CSV test results saved to: " .. file_path)

    -- Preview the configured CSV output
    logger.info("\nConfigured CSV Test Results Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Test case for configuring the CSV formatter (including function data) for coverage reports.
  it("demonstrates CSV formatter configuration for coverage data", function()
    -- Configure CSV formatter options for coverage data
    central_config.set("reporting.formatters.csv", {
      delimiter = ",", -- Use comma as delimiter (standard)
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

    -- Check if write was successful
    expect(success).to.be_truthy()

    logger.info("Configured CSV coverage report saved to: " .. file_path)

    -- Preview the configured CSV output
    logger.info("\nConfigured CSV Coverage Report Preview:")
    print(csv_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Test case demonstrating basic parsing and analysis of the generated CSV data.
  it("demonstrates post-processing CSV data for analysis", function()
    -- Generate CSV coverage report
    local csv_report = reporting.format_coverage(mock_coverage_data, "csv")

    -- Parse CSV data (simplified example)
    logger.info("Demonstrating basic CSV parsing and analysis...")

    --- Simple CSV parser for demonstration.
    -- @param csv_string string The CSV content as a string.
    -- @return table headers A list of header strings.
    -- @return table data A list of tables, where each inner table represents a row (header -> value).
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

  --- Test case discussing integration with external data analysis tools.
  it("demonstrates integration with data analysis tools", function()
    -- Generate both test and coverage CSV reports
    local test_csv = reporting.format_results(mock_test_results, "csv")
    local coverage_csv = reporting.format_coverage(mock_coverage_data, "csv")

    -- Save to files that data analysis tools would typically use
    local test_file = fs.join_paths(temp_dir.path, "test-data.csv")
    local coverage_file = fs.join_paths(temp_dir.path, "coverage-data.csv")

    fs.write_file(test_file, test_csv)
    fs.write_file(coverage_file, coverage_csv)

    -- Show example commands for data analysis tools
    logger.info("\nData Analysis Tool Integration Examples:")

    -- R examples
    logger.info("\nData can be imported into tools like R, Python (pandas), or spreadsheets.")
    -- Removed incomplete R example code block
  end)
end)
