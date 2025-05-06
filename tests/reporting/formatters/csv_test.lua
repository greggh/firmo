--- CSV Formatter Tests
---
---@diagnostic disable: unused-local
---
--- Tests the functionality of the CSV formatter for test results and coverage data.
--- Validates proper handling of custom columns, delimiters, headers, special characters,
--- and nested test data.
---
--- @author Firmo Team
--- @test

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

-- Import modules needed for testing
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")
local reporting = require("lib.reporting")

-- Sample data for testing formatters
-- Creates a sample test results data table for testing CSV formatter
local function create_sample_results_data()
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
        failure = {
          message = "Expected 5 but got 4",
          type = "Assertion",
          details = "test_file.lua:25: assertion failed",
        },
        error_message = "Expected 5 but got 4",
      },
      {
        name = "test_skipped",
        classname = "example_test",
        time = 0,
        status = "skipped",
      },
      {
        name = "test_with_special_chars",
        classname = "example_test",
        time = 0.018,
        status = "pass",
        description = "Test with \"quotes\", commas, and\nnewlines",
      },
      {
        name = "test_with_nested_tests",
        classname = "nested_test_suite",
        time = 0.020,
        status = "pass",
        tests = {
          {
            name = "nested_test_1",
            time = 0.008,
            status = "pass",
          },
          {
            name = "nested_test_2",
            time = 0.012,
            status = "fail",
            error_message = "Nested test failure"
          }
        }
      }
    },
  }
end

-- Creates a sample coverage data table for testing the CSV formatter
local function create_sample_coverage_data()
  return {
    files = {
      ["test1.lua"] = {
        summary = {
          total_lines = 6,
          covered_lines = 3,
          executed_lines = 0,
          not_covered_lines = 3,
          coverage_percent = 50.0,
          execution_percent = 50.0,
        },
        lines = {
          ["1"] = { covered = true, executed = false, execution_count = 0 },
          ["2"] = { covered = true, executed = false, execution_count = 0 },
          ["3"] = { covered = true, executed = false, execution_count = 0 },
          ["5"] = { covered = false, executed = false, execution_count = 0 },
          ["6"] = { covered = false, executed = false, execution_count = 0 },
          ["7"] = { covered = false, executed = false, execution_count = 0 },
        },
        source = "local function add(a, b)\n  return a + b\nend\n\nlocal function subtract(a, b)\n  return a - b\nend",
      },
      ["test2.lua"] = {
        summary = {
          total_lines = 2,
          covered_lines = 2,
          executed_lines = 0,
          not_covered_lines = 0,
          coverage_percent = 100.0,
          execution_percent = 100.0,
        },
        lines = {
          ["1"] = { covered = true, executed = false, execution_count = 0 },
          ["2"] = { covered = true, executed = false, execution_count = 0 },
        },
        source = "local function multiply(a, b)\n  return a * b",
      },
    },
    summary = {
      total_files = 2,
      covered_files = 2,
      files_percent = 100,
      total_lines = 8,
      covered_lines = 5,
      not_covered_lines = 3,
      executed_lines = 0,
      coverage_percent = 62.5,
      execution_percent = 62.5,
    },
  }
end

describe("CSV formatter", function()
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
  end)

  describe("Test results formatting", function()
    it("formats basic test results correctly", function()
      local results_data = create_sample_results_data()

      -- Format with CSV formatter using default settings
      local output = reporting.format_results(results_data, "csv")
      expect(output).to.exist()

      -- Validate CSV header and basic structure
      if type(output) == "string" then
        -- Verify header with default columns
        expect(output).to.match("test_id,test_suite,test_name,status,duration,error_message")
        
        -- Verify content matches test data
        expect(output).to.match("example_test,test_success,pass,0.012")
        expect(output).to.match("example_test,test_failure,fail,0.015,Expected 5 but got 4")
        expect(output).to.match("example_test,test_skipped,skipped,0")
      elseif type(output) == "table" and output.output then
        -- For newer formatters that return structured data
        expect(output.output).to.match("test_id,test_suite,test_name,status,duration,error_message")
        expect(output.output).to.match("example_test,test_success,pass,0.012")
        expect(output.output).to.match("example_test,test_failure,fail,0.015,Expected 5 but got 4")
        expect(output.output).to.match("example_test,test_skipped,skipped,0")
      end

      -- Save to file and verify
      local test_file = temp_dir .. "/test_results.csv"
      local success = reporting.write_file(test_file, output)
      expect(success).to.be_truthy()
      expect(fs.file_exists(test_file)).to.be_truthy()
    end)

    it("supports custom column selection and ordering", function()
      local results_data = create_sample_results_data()

      -- Define custom columns
      local custom_columns = {
        { name = "Test ID", field = "id" },
        { name = "Test Name", field = "name" },
        { name = "Result", field = "status" },
        { name = "Time", field = "time" },
      }

      -- Format with custom columns
      local output = reporting.format_results(results_data, "csv", {
        columns = custom_columns
      })
      expect(output).to.exist()

      -- Verify custom headers and ordering
      if type(output) == "string" then
        expect(output).to.match("Test ID,Test Name,Result,Time")
        
        -- Order should match our column definition
        local first_line = output:match("[^\n]+\n([^\n]+)")
        expect(first_line).to.match("^.-,test_success,pass,0.012")
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match("Test ID,Test Name,Result,Time")
        local first_line = output.output:match("[^\n]+\n([^\n]+)")
        expect(first_line).to.match("^.-,test_success,pass,0.012")
      end
    end)

    it("supports custom delimiter configuration", function()
      local results_data = create_sample_results_data()

      -- Format with semicolon delimiter
      local output = reporting.format_results(results_data, "csv", {
        delimiter = ";"
      })
      expect(output).to.exist()

      -- Verify semicolon delimiter is used
      if type(output) == "string" then
        expect(output).to.match("test_id;test_suite;test_name;status;duration;error_message")
        expect(output).to.match("example_test;test_success;pass;0.012")
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match("test_id;test_suite;test_name;status;duration;error_message")
        expect(output.output).to.match("example_test;test_success;pass;0.012")
      end

      -- Format with tab delimiter
      output = reporting.format_results(results_data, "csv", {
        delimiter = "\t"
      })
      expect(output).to.exist()

      -- Verify tab delimiter is used
      if type(output) == "string" then
        expect(output).to.match("test_id\ttest_suite\ttest_name\tstatus\tduration\terror_message")
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match("test_id\ttest_suite\ttest_name\tstatus\tduration\terror_message")
      end
    end)

    it("can format with or without headers", function()
      local results_data = create_sample_results_data()

      -- Format with headers (default)
      local output_with_headers = reporting.format_results(results_data, "csv")
      expect(output_with_headers).to.exist()

      -- Format without headers
      local output_without_headers = reporting.format_results(results_data, "csv", {
        include_header = false
      })
      expect(output_without_headers).to.exist()

      -- Verify headers are included in first output
      if type(output_with_headers) == "string" then
        expect(output_with_headers).to.match("^test_id,test_suite,test_name,status,duration,error_message\n")
      elseif type(output_with_headers) == "table" and output_with_headers.output then
        expect(output_with_headers.output).to.match("^test_id,test_suite,test_name,status,duration,error_message\n")
      end

      -- Verify headers are not included in second output
      if type(output_without_headers) == "string" then
        expect(output_without_headers).not_to.match("^test_id,test_suite,test_name,status,duration,error_message\n")
        -- Should start with actual data
        expect(output_without_headers).to.match("^.-,example_test,test_success,pass,0.012")
      elseif type(output_without_headers) == "table" and output_without_headers.output then
        expect(output_without_headers.output).not_to.match("^test_id,test_suite,test_name,status,duration,error_message\n")
        expect(output_without_headers.output).to.match("^.-,example_test,test_success,pass,0.012")
      end
    end)

    it("properly escapes special characters in CSV fields", function()
      local results_data = create_sample_results_data()
      
      -- The test data includes a test with special characters:
      -- "Test with \"quotes\", commas, and\nnewlines"

      local output = reporting.format_results(results_data, "csv")
      expect(output).to.exist()

      -- Verify special characters are properly escaped
      if type(output) == "string" then
        -- Double quotes should be doubled, and field wrapped in quotes
        expect(output).to.match('Test with ""quotes"", commas, and%s+newlines')
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match('Test with ""quotes"", commas, and%s+newlines')
      end
    end)

    it("processes nested test cases correctly", function()
      local results_data = create_sample_results_data()
      
      -- Our sample data includes a test with nested tests

      local output = reporting.format_results(results_data, "csv")
      expect(output).to.exist()

      -- Verify both parent and nested tests are included
      if type(output) == "string" then
        -- Parent test
        expect(output).to.match("nested_test_suite,test_with_nested_tests,pass,0.02")
        
        -- Child tests
        expect(output).to.match("nested_test_suite,nested_test_1,pass,0.008")
        expect(output).to.match("nested_test_suite,nested_test_2,fail,0.012,Nested test failure")
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match("nested_test_suite,test_with_nested_tests,pass,0.02")
        expect(output.output).to.match("nested_test_suite,nested_test_1,pass,0.008")
        expect(output.output).to.match("nested_test_suite,nested_test_2,fail,0.012,Nested test failure")
      end
    end)
  end)

  describe("Coverage data formatting", function()
    it("formats file-level coverage data", function()
      local coverage_data = create_sample_coverage_data()

      -- Format with CSV formatter for file-level coverage
      local output = reporting.format_coverage(coverage_data, "csv", {
        level = "file" -- Default, but explicit for test
      })
      expect(output).to.exist()

      -- Verify file-level CSV structure
      if type(output) == "string" then
        -- Should include header
        expect(output).to.match("File,Lines,Covered Lines")
        
        -- Should include file data
        expect(output).to.match("test1.lua,6,3")
        expect(output).to.match("test2.lua,2,2")
        
        -- Should have coverage percentage
        expect(output).to.match("test1.lua.-50%%")
        expect(output).to.match("test2.lua.-100%%")
        
        -- Should include summary data
        expect(output).to.match("Summary,8,5,62.5%%")
      elseif type(output) == "table" and output.output then
        -- Should include header
        expect(output.output).to.match("File,Lines,Covered Lines")
        
        -- Should include file data
        expect(output.output).to.match("test1.lua,6,3")
        expect(output.output).to.match("test2.lua,2,2")
        
        -- Should have coverage percentage
        expect(output.output).to.match("test1.lua.-50%%")
        expect(output.output).to.match("test2.lua.-100%%")
        
        -- Should include summary data
        expect(output.output).to.match("Summary,8,5,62.5%%")
      end
    end)
    
    it("formats line-level coverage data", function()
      local coverage_data = create_sample_coverage_data()
      
      -- Format with CSV formatter for line-level coverage
      local output = reporting.format_coverage(coverage_data, "csv", {
        level = "line"
      })
      expect(output).to.exist()
      
      -- Verify line-level CSV structure
      if type(output) == "string" then
        -- Should include header for line-level data
        expect(output).to.match("File,Line Number,Status")
        
        -- Should include line data for test1.lua
        expect(output).to.match("test1.lua,1,Covered")
        expect(output).to.match("test1.lua,2,Covered")
        expect(output).to.match("test1.lua,3,Covered")
        expect(output).to.match("test1.lua,5,Not Covered")
        expect(output).to.match("test1.lua,6,Not Covered")
        expect(output).to.match("test1.lua,7,Not Covered")
        
        -- Should include line data for test2.lua
        expect(output).to.match("test2.lua,1,Covered")
        expect(output).to.match("test2.lua,2,Covered")
      elseif type(output) == "table" and output.output then
        -- Should include header for line-level data
        expect(output.output).to.match("File,Line Number,Status")
        
        -- Should include line data for test1.lua
        expect(output.output).to.match("test1.lua,1,Covered")
        expect(output.output).to.match("test1.lua,2,Covered")
        expect(output.output).to.match("test1.lua,3,Covered")
        expect(output.output).to.match("test1.lua,5,Not Covered")
        expect(output.output).to.match("test1.lua,6,Not Covered")
        expect(output.output).to.match("test1.lua,7,Not Covered")
        
        -- Should include line data for test2.lua
        expect(output.output).to.match("test2.lua,1,Covered")
        expect(output.output).to.match("test2.lua,2,Covered")
      end
    end)
    
    it("handles custom coverage data columns", function()
      local coverage_data = create_sample_coverage_data()
      
      -- Format with custom columns
      local output = reporting.format_coverage(coverage_data, "csv", {
        columns = {
          { name = "Filename", field = "file" },
          { name = "Total", field = "total_lines" },
          { name = "Coverage %", field = "coverage_percent" }
        }
      })
      expect(output).to.exist()
      
      -- Verify custom columns are used
      if type(output) == "string" then
        expect(output).to.match("Filename,Total,Coverage %%")
        expect(output).to.match("test1.lua,6,50")
        expect(output).to.match("test2.lua,2,100")
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match("Filename,Total,Coverage %%")
        expect(output.output).to.match("test1.lua,6,50")
        expect(output.output).to.match("test2.lua,2,100")
      end
    end)
  end)
end)
