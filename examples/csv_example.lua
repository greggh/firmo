--[[
  csv_example.lua
  
  Example demonstrating CSV format generation for both test results and coverage data with firmo.
  
  This example shows how to:
  - Generate CSV reports for both test results and coverage data
  - Configure CSV-specific options like delimiters and headers
  - Save CSV reports to disk using the filesystem module
  - Process CSV data for analysis and visualization
  - Integrate with data analysis tools and workflows
]]

-- Import firmo (no direct coverage module usage per project rules)
local firmo = require("firmo")

-- Import required modules
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Mock test results data (consistent with other examples)
local mock_test_results = {
  name = "CSV Example Test Suite",
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
      status = "pass"
    },
    {
      name = "validates negative numbers correctly",
      classname = "NumberValidator",
      time = 0.003,
      status = "pass"
    },
    {
      name = "validates zero correctly",
      classname = "NumberValidator",
      time = 0.001,
      status = "pass"
    },
    {
      name = "rejects non-numeric inputs",
      classname = "NumberValidator",
      time = 0.002,
      status = "pass"
    },
    {
      name = "handles boundary values correctly",
      classname = "NumberValidator",
      time = 0.015,
      status = "fail",
      failure = {
        message = "Expected validation to pass for MAX_INT but it failed",
        type = "AssertionError",
        details = "test/number_validator_test.lua:42: Expected isValid(9223372036854775807) to be true, got false"
      }
    },
    {
      name = "throws appropriate error for invalid format",
      classname = "NumberValidator",
      time = 0.005,
      status = "error",
      error = {
        message = "Runtime error in test",
        type = "Error",
        details = "test/number_validator_test.lua:53: attempt to call nil value (method 'formatError')"
      }
    },
    {
      name = "validates scientific notation",
      classname = "NumberValidator",
      time = 0.000,
      status = "skipped",
      skip_message = "Scientific notation validation not implemented yet"
    },
    {
      name = "validates decimal precision correctly",
      classname = "NumberValidator",
      time = 0.002,
      status = "pass"
    }
  }
}

-- Mock coverage data (consistent with other examples)
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = true,  -- This line was covered
        [2] = true,  -- This line was covered 
        [3] = true,  -- This line was covered
        [5] = false, -- This line was not covered
        [6] = true,  -- This line was covered
        [8] = false, -- This line was not covered
        [9] = false, -- This line was not covered
      },
      functions = {
        ["add"] = true,      -- This function was covered
        ["subtract"] = true, -- This function was covered
        ["multiply"] = false, -- This function was not covered
        ["divide"] = false,  -- This function was not covered
      },
      total_lines = 10,
      covered_lines = 4,
      total_functions = 4,
      covered_functions = 2,
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = true,  -- This line was covered
        [2] = true,  -- This line was covered
        [4] = true,  -- This line was covered
        [5] = true,  -- This line was covered
        [7] = false, -- This line was not covered
      },
      functions = {
        ["validate"] = true, -- This function was covered
        ["format"] = false,  -- This function was not covered
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
describe("CSV Formatter Example", function()
  -- Create directories for reports
  local test_reports_dir = "test-reports/csv"
  local coverage_reports_dir = "coverage-reports/csv"
  fs.ensure_directory_exists(test_reports_dir)
  fs.ensure_directory_exists(coverage_reports_dir)
  
  it("generates basic CSV test results", function()
    -- Generate CSV test results report
    print("Generating basic CSV test results report...")
    local csv_report = reporting.format_results(mock_test_results, "csv")
    
    -- Validate the report
    expect(csv_report).to.exist()
    expect(csv_report).to.be.a("string")
    expect(csv_report).to.match("test_id,test_suite,test_name,status")  -- Should have header
    expect(csv_report).to.match("NumberValidator,validates positive numbers correctly,pass")
    
    -- Save to file
    local file_path = fs.join_paths(test_reports_dir, "test-results.csv")
    local success, err = fs.write_file(file_path, csv_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Basic CSV test results saved to:", file_path)
    print("Report size:", #csv_report, "bytes")
    
    -- Preview the CSV output
    print("\nCSV Test Results Preview:")
    print(csv_report:sub(1, 300) .. "...\n")
  end)
  
  it("generates basic CSV coverage report", function()
    -- Generate CSV coverage report
    print("Generating basic CSV coverage report...")
    local csv_report = reporting.format_coverage(mock_coverage_data, "csv")
    
    -- Validate the report
    expect(csv_report).to.exist()
    expect(csv_report).to.be.a("string")
    expect(csv_report).to.match("file,total_lines,covered_lines,coverage_percent")  -- Should have header
    
    -- Save to file
    local file_path = fs.join_paths(coverage_reports_dir, "coverage-report.csv")
    local success, err = fs.write_file(file_path, csv_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Basic CSV coverage report saved to:", file_path)
    print("Report size:", #csv_report, "bytes")
    
    -- Preview the CSV output
    print("\nCSV Coverage Report Preview:")
    print(csv_report:sub(1, 300) .. "...\n")
  end)
  
  it("demonstrates CSV formatter configuration for test results", function()
    -- Configure CSV formatter options via central_config
    central_config.set("reporting.formatters.csv", {
      delimiter = ";",              -- Use semicolon as delimiter (common in Europe)
      include_header = true,        -- Include column headers
      quote_strings = true,         -- Quote string values
      escape_character = "\\",      -- Escape character for quotes within strings
      columns = {                   -- Custom column selection and order
        "test_id", 
        "test_suite", 
        "test_name", 
        "status",
        "duration", 
        "error_message"
      }
    })
    
    -- Generate CSV report with custom configuration
    print("Generating configured CSV test results report...")
    local csv_report = reporting.format_results(mock_test_results, "csv")
    
    -- Validate the report format
    expect(csv_report).to.exist()
    expect(csv_report).to.match("test_id;test_suite;test_name")  -- Should use semicolon delimiter
    expect(csv_report).to.match("duration;error_message")        -- Should include custom columns
    
    -- Save to file
    local file_path = fs.join_paths(test_reports_dir, "test-results-configured.csv")
    local success, err = fs.write_file(file_path, csv_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Configured CSV test results saved to:", file_path)
    
    -- Preview the configured CSV output
    print("\nConfigured CSV Test Results Preview:")
    print(csv_report:sub(1, 300) .. "...\n")
  end)
  
  it("demonstrates CSV formatter configuration for coverage data", function()
    -- Configure CSV formatter options for coverage data
    central_config.set("reporting.formatters.csv", {
      delimiter = ",",              -- Use comma as delimiter (standard)
      include_header = true,        -- Include column headers
      include_functions = true,     -- Include function coverage details
      include_uncovered = true,     -- Include uncovered files/lines
      columns = {                   -- Custom column selection and order
        "file", 
        "total_lines", 
        "covered_lines", 
        "coverage_percent",
        "total_functions",
        "covered_functions",
        "function_coverage_percent"
      }
    })
    
    -- Generate CSV report with custom configuration
    print("Generating configured CSV coverage report...")
    local csv_report = reporting.format_coverage(mock_coverage_data, "csv")
    
    -- Validate the report format
    expect(csv_report).to.exist()
    expect(csv_report).to.match("function_coverage_percent")  -- Should include function data
    
    -- Save to file
    local file_path = fs.join_paths(coverage_reports_dir, "coverage-report-configured.csv")
    local success, err = fs.write_file(file_path, csv_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Configured CSV coverage report saved to:", file_path)
    
    -- Preview the configured CSV output
    print("\nConfigured CSV Coverage Report Preview:")
    print(csv_report:sub(1, 300) .. "...\n")
  end)
  
  it("demonstrates post-processing CSV data for analysis", function()
    -- Generate CSV coverage report
    local csv_report = reporting.format_coverage(mock_coverage_data, "csv")
    
    -- Parse CSV data (simplified example)
    print("Demonstrating basic CSV parsing and analysis...")
    
    -- Parse headers
    local headers = {}
    local first_line = csv_report:match("([^\n]+)")
    for header in first_line:gmatch("([^,]+)") do
      table.insert(headers, header)
    end
    
    -- Parse data lines
    local data = {}
    local line_num = 0
    for line in csv_report:gmatch("([^\n]+)") do
      line_num = line_num + 1
      if line_num > 1 then  -- Skip header line
        local row = {}
        local col_idx = 1
        for value in line:gmatch("([^,]+)") do
          row[headers[col_idx]] = value
          col_idx = col_idx + 1
        end
        table.insert(data, row)
      end
    end
    
    -- Simple analysis: Calculate average coverage
    local total_coverage = 0
    for _, row in ipairs(data) do
      total_coverage = total_coverage + tonumber(row.coverage_percent)
    end
    local avg_coverage = total_coverage / #data
    
    print(string.format("Parsed %d data rows with %d columns", #data, #headers))
    print(string.format("Average coverage: %.2f%%", avg_coverage))
    
    -- Example of generating derived metrics
    print("\nExample derived metrics from CSV data:")
    print("1. Files below 50% coverage:")
    for _, row in ipairs(data) do
      if tonumber(row.coverage_percent) < 50 then
        print(string.format("  - %s: %.1f%%", row.file, tonumber(row.coverage_percent)))
      end
    end
    
    -- Demonstrate export to another format (e.g., JSON for visualization)
    print("\nExample of exporting to JSON for visualization tools:")
    local json_example = [[
{
  "coverage_data": [
    { "file": "src/calculator.lua", "coverage": 40.0, "color": "#ff6666" },
    { "file": "src/utils.lua", "coverage": 50.0, "color": "#ffcc66" }
  ],
  "metadata": {
    "timestamp": "]] .. os.date("%Y-%m-%dT%H:%M:%S") .. [[",
    "avg_coverage": ]] .. string.format("%.1f", avg_coverage) .. [[
  }
}]]
    print(json_example)
  end)
  
  it("demonstrates integration with data analysis tools", function()
    -- Generate both test and coverage CSV reports
    local test_csv = reporting.format_results(mock_test_results, "csv")
    local coverage_csv = reporting.format_coverage(mock_coverage_data, "csv")
    
    -- Save to files that data analysis tools would typically use
    local test_file = fs.join_paths(test_reports_dir, "test-data.csv")
    local coverage_file = fs.join_paths(coverage_reports_dir, "coverage-data.csv")
    
    fs.write_file(test_file, test_csv)
    fs.write_file(coverage_file, coverage_csv)
    
    -- Show example commands for data analysis tools
    print("\nData Analysis Tool Integration Examples:")
    
    -- R examples
    print("\nR Data Analysis Example:")
    print([[
# R script example for coverage trend analysis
library(readr)
library(dplyr)
library(ggplot2)

# Read the CSV file
coverage_data <- read_csv("]] .. coverage_file .. [[")

# Calculate statistics
summary_stats <- coverage_data %>%
  summarize(
    avg_coverage = mean(coverage_percent),
    min_coverage = min(coverage_percent),
    max_coverage = max(coverage_percent)
  )

# Plot coverage distribution
ggplot(coverage_data, aes(x = file, y = coverage_percent)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  geom_hline(yintercept = 80, linetype = "dashed", color = "red") +
  labs(title = "Code Coverage by

