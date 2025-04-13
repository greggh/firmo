--[[
  summary_example.lua
  
  Example demonstrating text-based summary output for both test results and coverage data with firmo.
  
  This example shows how to:
  - Generate text-based summary reports for terminal output
  - Configure summary-specific formatting options like colors and verbosity
  - Save summary reports to disk using the filesystem module
  - Customize terminal output for different environments and needs
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

-- Create tests to demonstrate the Summary formatter
describe("Summary Formatter Example", function()
  -- Create directories for reports
  local reports_dir = "test-reports/summary"
  fs.ensure_directory_exists(reports_dir)
  
  it("generates basic summary test results", function()
    -- Generate basic summary test results
    print("Generating basic summary test results output...")
    local summary_report = reporting.format_results(mock_test_results, "summary")
    
    -- Validate the report
    expect(summary_report).to.exist()
    expect(summary_report).to.be.a("string")
    expect(summary_report).to.match("Test Results")
    expect(summary_report).to.match("Total:%s+8")
    expect(summary_report).to.match("Passed:%s+5")
    expect(summary_report).to.match("Failed:%s+1")
    
    -- Save to file
    local file_path = fs.join_paths(reports_dir, "test-results.txt")
    local success, err = fs.write_file(file_path, summary_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Basic summary test results saved to:", file_path)
    print("Report size:", #summary_report, "bytes")
    
    -- Preview the summary output
    print("\nSummary Test Results Preview:")
    print(summary_report)
  end)
  
  it("generates basic summary coverage report", function()
    -- Generate basic summary coverage report
    print("Generating basic summary coverage report...")
    local summary_report = reporting.format_coverage(mock_coverage_data, "summary")
    
    -- Validate the report
    expect(summary_report).to.exist()
    expect(summary_report).to.be.a("string")
    expect(summary_report).to.match("Coverage Summary")
    expect(summary_report).to.match("Overall:%s+%d+.%d+%%")
    expect(summary_report).to.match("Files:%s+%d+/%d+")
    
    -- Save to file
    local file_path = fs.join_paths(reports_dir, "coverage-summary.txt")
    local success, err = fs.write_file(file_path, summary_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Basic summary coverage report saved to:", file_path)
    print("Report size:", #summary_report, "bytes")
    
    -- Preview the summary output
    print("\nSummary Coverage Report Preview:")
    print(summary_report)
  end)
  
  it("demonstrates summary formatter with color configuration", function()
    -- Configure summary formatter with colors enabled
    central_config.set("reporting.formatters.summary", {
      use_colors = true,            -- Enable colored output
      color_scheme = {              -- Custom color scheme
        header = "bright blue",     -- Headers in bright blue
        pass = "green",             -- Passing tests in green
        fail = "bright red",        -- Failing tests in bright red
        error = "magenta",          -- Errors in magenta
        skip = "yellow",            -- Skipped tests in yellow
        info = "cyan",              -- Info text in cyan
        good = "green",             -- Good metrics in green (e.g., high coverage)
        warning = "yellow",         -- Warning metrics in yellow (e.g., medium coverage)
        critical = "red"            -- Critical metrics in red (e.g., low coverage)
      },
      terminal_width = 80,          -- Target terminal width
      unicode_symbols = true,       -- Use Unicode symbols (✓, ✗, etc.)
      show_time = true              -- Show execution time for tests
    })
    
    -- Generate the colored summary report for test results
    print("\nGenerating colored summary test results...")
    local summary_report = reporting.format_results(mock_test_results, "summary")
    
    -- Note: We can't validate colors directly in the string content
    expect(summary_report).to.exist()
    
    -- Save to file (note that colors will likely be saved as ANSI escape sequences)
    local file_path = fs.join_paths(reports_dir, "test-results-colored.txt")
    local success, err = fs.write_file(file_path, summary_report)
    expect(success).to.be_truthy()
    
    print("Colored summary test results saved to:", file_path)
    print("\nNote: Terminal will show colors when viewing directly")
    
    -- Generate the colored summary report for coverage
    print("\nGenerating colored summary coverage report...")
    local coverage_report = reporting.format_coverage(mock_coverage_data, "summary")
    
    -- Save to file
    file_path = fs.join_paths(reports_dir, "coverage-summary-colored.txt")
    success, err = fs.write_file(file_path, coverage_report)
    expect(success).to.be_truthy()
    
    print("Colored summary coverage report saved to:", file_path)
  end)
  
  it("demonstrates summary formatter with verbosity levels", function()
    -- Configure for minimal output
    central_config.set("reporting.formatters.summary", {
      use_colors = true,            -- Keep colors enabled
      verbosity = "minimal",        -- Minimal verbosity level
      unicode_symbols = false,      -- Don't use Unicode symbols
      show_time = false,            -- Don't show execution time
      terminal_width = 60,          -- Narrow terminal width
    })
    
    print("\nGenerating minimal verbosity summary...")
    local minimal_report = reporting.format_results(mock_test_results, "summary")
    
    expect(minimal_report).to.exist()
    
    -- Configure for normal output
    central_config.set("reporting.formatters.summary", {
      verbosity = "normal",         -- Normal verbosity level
    })
    
    print("\nGenerating normal verbosity summary...")
    local normal_report = reporting.format_results(mock_test_results, "summary")
    
    expect(normal_report).to.exist()
    
    -- Configure for detailed output
    central_config.set("reporting.formatters.summary", {
      verbosity = "detailed",       -- Detailed verbosity level
      show_file_details = true,     -- Show details for each file in coverage
      show_function_details = true, -- Show function details in coverage
    })
    
    print("\nGenerating detailed verbosity summary...")
    local detailed_report = reporting.format_results(mock_test_results, "summary")
    
    expect(detailed_report).to.exist()
    
    -- Save all three verbosity levels
    local minimal_path = fs.join_paths(reports_dir, "test-results-minimal.txt")
    local normal_path = fs.join_paths(reports_dir, "test-results-normal.txt")
    local detailed_path = fs.join_paths(reports_dir, "test-results-detailed.txt")
    
    fs.write_file(minimal_path, minimal_report)
    fs.write_file(normal_path, normal_report)
    fs.write_file(detailed_path, detailed_report)
    
    print("\nSaved summary reports with different verbosity levels:")
    print("Minimal:", minimal_path)
    print("Normal:", normal_path)
    print("Detailed:", detailed_path)
    
    -- Show relative sizes to demonstrate verbosity difference
    print("\nSummary size comparison:")
    print(string.format("Minimal: %d bytes", #minimal_report))
    print(string.format("Normal: %d bytes", #normal_report))
    print(string.format("Detailed: %d bytes", #detailed_report))
    
    -- Display preview of minimal report
    print("\nMinimal verbosity preview:")
    print(minimal_report)
  end)
  
  it("demonstrates summary formatter with custom sections and formatting", function()
    -- Configure custom summary sections
    central_config.set("reporting.formatters.summary", {
      use_colors = true,                  -- Enable colored output
      verbosity = "normal",               -- Normal verbosity
      terminal_width = 80,                -- Standard terminal width
      unicode_symbols = true,             -- Use Unicode symbols
      sections = {                        -- Custom section configuration
        header = true,                    -- Include header section
        summary = true,                   -- Include summary section
        overview = true,                  -- Include overview section
        failures = true,                  -- Include failures section
        files = true,                     -- Include files section for coverage
        conclusion = true,                -- Include conclusion section
      },
      show_execution_time = true,         -- Show execution time
      threshold_good = 80,                -- Coverage threshold for "good" rating (%)
      threshold_warning = 50,             -- Coverage threshold for "warning" rating (%)
      sort_files_by = "coverage",         -- Sort files by coverage (low to high)
      max_files_to_show = 5,              -- Maximum number of files to show in summary
      custom_header = "FIRMO TEST REPORT" -- Custom header text
    })
    
    -- Generate summary for test results with custom configuration
    print("\nGenerating custom formatted summary test results...")
    local test_summary = reporting.format_results(mock_test_results, "summary")
    
    expect(test_summary).to.exist()
    
    -- Generate summary for coverage with custom configuration
    print("\nGenerating custom formatted summary coverage report...")
    local coverage_summary = reporting.format_coverage(mock_coverage_data, "summary")
    
    expect(coverage_summary).to.exist()
    
    -- Save custom formatted reports
    local test_path = fs.join_paths(reports_dir, "test-results-custom.txt")
    local coverage_path = fs.join_paths(reports_dir, "coverage-summary-custom.txt")
    
    fs.write_file(test_path, test_summary)
    fs.write_file(coverage_path, coverage_summary)
    
    print("\nSaved custom formatted summary reports:")
    print("Test results:", test_path)
    print("Coverage summary:", coverage_path)
    
    -- Display preview of custom coverage summary
    print("\nCustom coverage summary preview:")
    print(coverage_summary)
  end)
  
  it("demonstrates terminal integration and viewing summary reports", function()
    -- Set default configuration for summary reports
    central_config.set("reporting.formatters.summary", {
      use_colors = true,            -- Enable colored output (if terminal supports it)
      verbosity = "normal",         -- Standard verbosity level
      terminal_width = 80,          -- Default terminal width
      unicode_symbols = true,       -- Use Unicode symbols if supported
    })
    
    -- Generate both test and coverage summaries
    local test_summary = reporting.format_results(mock_test_results, "summary")
    local coverage_summary = reporting.format_coverage(mock_coverage_data, "summary")
    
    -- Show example shell commands for viewing reports in terminal
    print("\nTerminal viewing examples:")
    print("1. Direct test execution with summary output:")
    print("   $ lua test.lua --format=summary tests/")
    
    print("\n2. Coverage report with summary output:")
    print("   $ lua test.lua --coverage --format=summary tests/")
    
    print("\n3. Viewing saved summary files in terminal:")
    print("   $ cat test-reports/summary/test-results.txt")
    print("   $ cat test-reports/summary/coverage-summary.txt")
    
    print("\n4. Using terminal tools for better display:")
    print("   $ cat test-reports/summary/test-results.txt | less -R  # Preserves colors")
    print("   $ cat test-reports/summary/coverage-summary.txt | more")
    
    print("\nSummary reports generated and ready for viewing!")
  end)
end)

print("\n=== Summary Formatter Example ===")
print("This example demonstrates how to generate terminal-friendly text-based summary reports.")
print("Summary format is ideal for quick feedback in CI/CD systems and local development.")

print("\nTo run this example directly:")
print("  lua examples/summary_example.lua")

print("\nOr run it with firmo's test runner:")
print("  lua test.lua examples/summary_example.lua")

print("\nCommon summary configurations:")
print("- use_colors: true|false - Enable terminal colors")
print("- verbosity: minimal|normal|detailed - Control output detail level")
print("- unicode_symbols: true|false - Use fancy symbols if terminal supports it")
print("- terminal_width: number - Target width for formatting")
print("- sections: table - Enable/disable specific sections")

print("\nExample complete!")

