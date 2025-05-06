--- Reporting Module Tests - CSV Formatter
---
---@diagnostic disable: unused-local
---
--- Tests the functionality of the CSV formatter for test results within the `lib.reporting`
--- module. Verifies the formatter correctly generates CSV output for test results with
--- proper header format, data escaping, and handling of nested test cases.
---
--- @author Firmo Team
--- @test

-- Extract the testing functions we need
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import modules needed for testing
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")

-- Initialize logging if available
local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.reporting.csv")

-- Import the reporting module
local reporting = require("lib.reporting")

-- Test data helper functions
--- Creates sample test results data for formatter testing.
--- @return table sample_data Sample test results data.
local function create_sample_test_results()
  return {
    name = "TestSuite",
    timestamp = "2025-04-06T20:45:00",
    tests = 4,
    failures = 1,
    errors = 0,
    skipped = 1,
    time = 0.042,
    test_cases = {
      {
        name = "test_success",
        classname = "example_test",
        time = 0.012,
        status = "pass",
      },
      {
        name = "test_failure",
        classname = "example_test",
        time = 0.015,
        status = "fail",
        error_message = "Expected 5 but got 4",
        failure = {
          type = "Assertion",
          details = "test_file.lua:25: assertion failed",
        },
      },
      {
        name = "test_skipped",
        classname = "example_test",
        time = 0,
        status = "skipped",
      },
      {
        name = "test_another_success",
        classname = "example_test",
        time = 0.015,
        status = "pass",
      },
    },
  }
end

--- Creates sample test results with nested tests.
--- @return table sample_data Sample test results with nested tests.
local function create_nested_test_results()
  return {
    name = "NestedTestSuite",
    timestamp = "2025-04-06T21:00:00",
    tests = 3,
    failures = 1,
    errors = 0,
    skipped = 0,
    time = 0.075,
    test_cases = {
      {
        name = "suite_one",
        classname = "nested_test",
        time = 0.045,
        status = "pass",
        tests = {
          {
            name = "nested_success_1",
            time = 0.010,
            status = "pass",
          },
          {
            name = "nested_success_2",
            time = 0.015,
            status = "pass",
          },
        },
      },
      {
        name = "suite_two",
        classname = "nested_test",
        time = 0.030,
        status = "fail",
        tests = {
          {
            name = "nested_fail",
            time = 0.020,
            status = "fail",
            error_message = "Nested assertion failed",
          },
          {
            name = "nested_success_3",
            time = 0.010,
            status = "pass",
          },
        },
      },
    },
  }
end

--- Creates sample test results with data requiring escaping.
--- @return table sample_data Sample test results with data requiring escaping.
local function create_test_results_with_escaping()
  return {
    name = "EscapeTestSuite",
    timestamp = "2025-04-06T21:15:00",
    tests = 3,
    failures = 2,
    errors = 0,
    skipped = 0,
    time = 0.032,
    test_cases = {
      {
        name = "test with, comma",
        classname = "escape_test",
        time = 0.010,
        status = "fail",
        error_message = "Error with \"quoted text\"",
        failure = {
          type = "Assertion",
          details = "test_file.lua:42: assertion failed",
        },
      },
      {
        name = "test with \"quotes\"",
        classname = "escape_test",
        time = 0.012,
        status = "fail",
        error_message = "Line 1\nLine 2",
        failure = {
          type = "Assertion",
          details = "test_file.lua:55: assertion failed",
        },
      },
      {
        name = "normal test name",
        classname = "escape_test",
        time = 0.010,
        status = "pass",
      },
    },
  }
end

describe("CSV formatter for test results", function()
  local temp_dir

  before(function()
    -- Create a temporary directory for test output
    temp_dir = temp_file.create_temp_directory()
    expect(temp_dir).to.exist()
    expect(fs.directory_exists(temp_dir)).to.be_truthy()
  end)

  after(function()
    -- Clean up the temporary directory
    if temp_dir and fs.directory_exists(temp_dir) then
      fs.remove_directory(temp_dir, true)
    end
    
    -- Reset any custom formatter configurations
    reporting.reset()
  end)

  -- Reset formatter before each test to avoid configuration bleed-over
  before(function()
    reporting.reset()
  end)

  it("formats basic test results correctly", function()
    local test_results = create_sample_test_results()
    
    -- Format with CSV formatter
    local output = reporting.format_results(test_results, "csv")
    expect(output).to.exist()
    
    -- Validate output is a string
    expect(output).to.be.a("string")
    
    -- Validate basic CSV structure (has rows and appropriate delimiters)
    expect(output:find("\n")).to.be_truthy("CSV should have multiple rows")
    expect(output:find(",")).to.be_truthy("CSV should use commas as delimiters")
    
    -- Save to a file for further inspection
    local test_file = temp_dir .. "/basic_results.csv"
    local success = reporting.write_file(test_file, output)
    expect(success).to.be_truthy()
    expect(fs.file_exists(test_file)).to.be_truthy()
    
    -- Read back the content for validation
    local content = fs.read_file(test_file)
    expect(content).to.equal(output)
  end)
  
  it("includes the expected header fields for test results", function()
    local test_results = create_sample_test_results()
    
    -- Format with CSV formatter
    local output = reporting.format_results(test_results, "csv")
    expect(output).to.exist()
    
    -- Expected header string
    local expected_header = "test_id,test_suite,test_name,status,duration,error_message"
    
    -- Get first line (header)
    local first_line = output:match("^([^\n]*)\n")
    expect(first_line).to.exist()
    
    -- Check exact header match
    expect(first_line).to.equal(expected_header)
  end)
  
  it("properly escapes CSV fields with special characters", function()
    local test_results = create_test_results_with_escaping()
    
    -- Format with CSV formatter
    local output = reporting.format_results(test_results, "csv")
    expect(output).to.exist()
    
    -- Check for proper quoting of fields with commas
    expect(output).to.match('"test with, comma"')
    
    -- Check for proper escaping of quotes within quoted fields
    expect(output).to.match('"test with ""quotes"""')
    expect(output).to.match('Error with ""quoted text""')
    
    -- Check for proper quoting of fields with newlines
    expect(output).to.match('"Line 1\nLine 2"')
    
    -- Save to a file for further inspection
    local test_file = temp_dir .. "/escaped_results.csv"
    local success = reporting.write_file(test_file, output)
    expect(success).to.be_truthy()
    
    -- Read back the content and confirm it's valid
    local content = fs.read_file(test_file)
    expect(content).to.equal(output)
  end)
  
  it("properly handles nested test cases", function()
    local test_results = create_nested_test_results()
    
    -- Format with CSV formatter
    local output = reporting.format_results(test_results, "csv")
    expect(output).to.exist()
    
    -- Count the number of lines in the output
    local line_count = 0
    for _ in output:gmatch("\n") do
      line_count = line_count + 1
    end
    
    -- Should have header + parent test cases + nested test cases
    -- Header (1) + parent test cases (2) + nested tests (2+2) = 7
    expect(line_count).to.be.at_least(6, "CSV should include parent and nested test cases")
    
    -- Check for presence of nested test names
    expect(output).to.match("nested_success_1")
    expect(output).to.match("nested_success_2")
    expect(output).to.match("nested_fail")
    expect(output).to.match("nested_success_3")
    
    -- Save to a file for further inspection
    local test_file = temp_dir .. "/nested_results.csv"
    local success = reporting.write_file(test_file, output)
    expect(success).to.be_truthy()
  end)
  
  it("correctly constructs test IDs from classname and test name", function()
    local test_results = create_sample_test_results()
    
    -- Format with CSV formatter
    local output = reporting.format_results(test_results, "csv")
    expect(output).to.exist()
    
    -- Verify each test has an ID that combines classname and test name
    expect(output).to.match("example_test.test_success")
    expect(output).to.match("example_test.test_failure")
    expect(output).to.match("example_test.test_skipped")
    expect(output).to.match("example_test.test_another_success")
  end)
  
  it("supports custom column selection and ordering", function()
    local test_results = create_sample_test_results()
    
    -- Reset first to ensure no previous config affects this test
    reporting.reset()
    
    -- Configure formatter with custom columns
    reporting.configure_formatter("csv", {
      columns = {
        { name = "Test Name", field = "name" },
        { name = "Result", field = "status" },
        { name = "Time", field = "time", format = "%.4f" }
      }
    })
    
    -- Format with CSV formatter
    local output = reporting.format_results(test_results, "csv")
    expect(output).to.exist()
    
    -- Create the exact expected CSV output
    local expected_csv = "Test Name,Result,Time\n" ..
                        "test_success,pass,0.0120\n" ..
                        "test_failure,fail,0.0150\n" ..
                        "test_skipped,skipped,0.0000\n" ..
                        "test_another_success,pass,0.0150"
    
    -- Verify exact output
    expect(output).to.equal(expected_csv)
    
    -- Reset formatter config
    reporting.reset()
  end)
  
  it("supports custom field separators", function()
    local test_results = create_sample_test_results()
    
    -- Reset first
    reporting.reset()
    
    -- Configure formatter with custom separator
    reporting.configure_formatter("csv", {
      delimiter = ";"
    })
    
    -- Format with CSV formatter
    local output = reporting.format_results(test_results, "csv")
    expect(output).to.exist()
    
    -- Create exact expected CSV with semicolons
    local expected_csv = 
      "test_id;test_suite;test_name;status;duration;error_message\n" ..
      "example_test.test_success;example_test;test_success;pass;0.012;\n" ..
      "example_test.test_failure;example_test;test_failure;fail;0.015;Expected 5 but got 4\n" ..
      "example_test.test_skipped;example_test;test_skipped;skipped;0;\n" ..
      "example_test.test_another_success;example_test;test_another_success;pass;0.015;"
    
    -- Verify exact output with semicolons
    expect(output).to.equal(expected_csv)
    
    -- Reset formatter config
    reporting.reset()
  end)
  
  it("can format with or without headers", function()
    local test_results = create_sample_test_results()
    
    -- Reset first to ensure clean state
    reporting.reset()
    
    -- Configure formatter to exclude headers
    reporting.configure_formatter("csv", {
      include_header = false
    })
    
    -- Format with CSV formatter
    local output = reporting.format_results(test_results, "csv")
    expect(output).to.exist()
    
    -- Create exact expected CSV without headers
    local expected_csv_no_header = 
      "example_test.test_success,example_test,test_success,pass,0.012,\n" ..
      "example_test.test_failure,example_test,test_failure,fail,0.015,Expected 5 but got 4\n" ..
      "example_test.test_skipped,example_test,test_skipped,skipped,0,\n" ..
      "example_test.test_another_success,example_test,test_another_success,pass,0.015,"
    
    -- Verify exact output without headers
    expect(output).to.equal(expected_csv_no_header)
    
    -- Reset formatter config
    reporting.reset()
    
    -- Format again with default settings (headers included)
    local output_with_headers = reporting.format_results(test_results, "csv")
    expect(output_with_headers).to.exist()
    
    -- Create exact expected CSV with headers
    local expected_csv_with_header = 
      "test_id,test_suite,test_name,status,duration,error_message\n" ..
      "example_test.test_success,example_test,test_success,pass,0.012,\n" ..
      "example_test.test_failure,example_test,test_failure,fail,0.015,Expected 5 but got 4\n" ..
      "example_test.test_skipped,example_test,test_skipped,skipped,0,\n" ..
      "example_test.test_another_success,example_test,test_another_success,pass,0.015,"
    
    -- Verify exact output with headers
    expect(output_with_headers).to.equal(expected_csv_with_header)
  end)
end)

