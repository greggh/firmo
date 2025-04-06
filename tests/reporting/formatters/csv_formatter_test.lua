--- Tests for CSV formatter
-- @module tests.reporting.formatters.csv_formatter_test
-- @author Firmo Team

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Import reporting module directly for testing
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")

describe("CSV Formatter", function()
  -- Create test data that will be used for all tests
  local coverage_data = {
    files = {
      ["/path/to/example.lua"] = {
        summary = {
          total_lines = 100,
          covered_lines = 80,
          executed_lines = 0,
          not_covered_lines = 20,
          coverage_percent = 80,
          execution_percent = 80
        },
        lines = {
          [1] = { line_number = 1, executed = true, covered = true, execution_count = 1 },
          [2] = { line_number = 2, executed = true, covered = true, execution_count = 5 },
          [3] = { line_number = 3, executed = false, covered = false, execution_count = 0 }
        },
        functions = {
          ["test_func"] = {
            name = "test_func",
            start_line = 1,
            end_line = 3,
            executed = true,
            covered = true,
            execution_count = 5
          }
        },
        source = "local function test_func()\n  return true\nend"
      },
      ["/path/to/another.lua"] = {
        summary = {
          total_lines = 50,
          covered_lines = 25,
          executed_lines = 5,
          not_covered_lines = 20,
          coverage_percent = 50,
          execution_percent = 60
        },
        lines = {
          [1] = { line_number = 1, executed = true, covered = true, execution_count = 1 },
          [2] = { line_number = 2, executed = true, covered = false, execution_count = 3 },
          [3] = { line_number = 3, executed = false, covered = false, execution_count = 0 }
        },
        functions = {
          ["another_func"] = {
            name = "another_func",
            start_line = 1,
            end_line = 3,
            executed = true,
            covered = false,
            execution_count = 3
          }
        },
        source = "local function another_func()\n  print('test')\nend"
      }
    },
    summary = {
      total_files = 2,
      total_lines = 150,
      covered_lines = 105,
      executed_lines = 5,
      not_covered_lines = 40,
      coverage_percent = 70,
      execution_percent = 73.33
    },
    data = {} -- Required by formatter.validate
  }
  
  -- Test directory for file tests
  local test_dir = "./test-tmp-csv-formatter"
  
  -- Setup/teardown test directory
  before(function()
    if fs.directory_exists(test_dir) then
      fs.delete_directory(test_dir, true)
    end
    fs.create_directory(test_dir)
    
    -- Reset configuration before each test
    central_config.delete("reporting.formatters.csv")
  end)
  
  after(function()
    if fs.directory_exists(test_dir) then
      fs.delete_directory(test_dir, true)
    end
    
    -- Reset configuration after each test
    central_config.delete("reporting.formatters.csv")
  end)
  
  it("generates valid file-level CSV format with default options", function()
    local csv_output = reporting.format_coverage(coverage_data, "csv")
    
    -- Check basic structure
    expect(csv_output).to.exist()
    expect(type(csv_output)).to.equal("string")
    
    -- Basic CSV validation - should have header and data
    local lines = {}
    for line in csv_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    -- Should have at least 3 lines (header + 2 files)
    expect(#lines).to.be_greater_than_or_equal_to(3)
    
    -- First line should be header
    expect(lines[1]).to.match("File,Lines,Covered Lines")
    
    -- Should contain both files
    expect(csv_output).to.match("/path/to/example%.lua")
    expect(csv_output).to.match("/path/to/another%.lua")
    
    -- Should contain coverage percentages
    expect(csv_output).to.match("80%.00")  -- 80.00% for example.lua
    expect(csv_output).to.match("50%.00")  -- 50.00% for another.lua
  end)
  
  it("generates valid line-level CSV format", function()
    -- Configure formatter for line-level output
    central_config.set("reporting.formatters.csv", {
      level = "line"
    })
    
    local csv_output = reporting.format_coverage(coverage_data, "csv")
    
    -- Check basic structure
    expect(csv_output).to.exist()
    expect(type(csv_output)).to.equal("string")
    
    -- Basic CSV validation for line-level format
    local lines = {}
    for line in csv_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    -- Should have at least 7 lines (header + 3 lines per file)
    expect(#lines).to.be_greater_than_or_equal_to(7)
    
    -- First line should have line-level header
    expect(lines[1]).to.match("File,Line,Executed,Covered,Execution Count")
    
    -- Should contain execution counts
    expect(csv_output).to.match(",5,") -- Line 2 of example.lua has execution count 5
    expect(csv_output).to.match(",3,") -- Line 2 of another.lua has execution count 3
    
    -- Should include content if source is available
    expect(csv_output).to.match("return true")
    expect(csv_output).to.match("print%('test'%)")
  end)
  
  it("correctly escapes special characters in CSV", function()
    -- Add file with special characters in path and content
    local test_data = test_helper.deep_copy(coverage_data)
    test_data.files["/path/with,quotes\"and,commas.lua"] = {
      summary = {
        total_lines = 10,
        covered_lines = 8,
        executed_lines = 0,
        not_covered_lines = 2,
        coverage_percent = 80,
        execution_percent = 80
      },
      lines = {
        [1] = { 
          line_number = 1, 
          executed = true, 
          covered = true, 
          execution_count = 1 
        }
      },
      source = "local csv_data = \"This, has \"quotes\" and, commas\""
    }
    
    -- File level should escape the path
    local file_csv = reporting.format_coverage(test_data, "csv")
    expect(file_csv).to.match('"[^"]*quotes[^"]*commas[^"]*"')
    
    -- Line level should escape the content
    central_config.set("reporting.formatters.csv", {
      level = "line"
    })
    local line_csv = reporting.format_coverage(test_data, "csv")
    expect(line_csv).to.match('"[^"]*This, has ""quotes"" and, commas[^"]*"')
    
    -- Verify double quotes are escaped by doubling them
    expect(line_csv).to.match('""quotes""')
  end)
  
  it("supports custom column separators", function()
    -- Configure formatter to use semicolon separator
    central_config.set("reporting.formatters.csv", {
      separator = ";"
    })
    
    local csv_output = reporting.format_coverage(coverage_data, "csv")
    
    -- Check basic structure with semicolon separator
    local lines = {}
    for line in csv_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    -- Header should use semicolons
    expect(lines[1]).to.match("File;Lines;Covered Lines")
    
    -- Data should use semicolons
    expect(csv_output).to.match("/path/to/example%.lua;100;80")
  end)
  
  it("handles custom column configuration", function()
    -- Configure formatter with custom columns
    central_config.set("reporting.formatters.csv", {
      columns = {
        { name = "Path", field = "path" },
        { name = "Total", field = "summary.total_lines" },
        { name = "Coverage", field = "summary.coverage_percent", format = "%.1f" }
      }
    })
    
    local csv_output = reporting.format_coverage(coverage_data, "csv")
    
    -- Check for custom headers
    expect(csv_output).to.match("Path,Total,Coverage")
    
    -- Check for custom formatted data
    expect(csv_output).to.match("80%.1") -- 80.0 with 1 decimal place
    expect(csv_output).to.match("50%.1") -- 50.0 with 1 decimal place
    
    -- Shouldn't include the standard columns that weren't specified
    expect(csv_output).to_not.match("Covered Lines")
    expect(csv_output).to_not.match("Executed Lines")
  end)
  
  it("can include summary row", function()
    -- Configure formatter to include summary
    central_config.set("reporting.formatters.csv", {
      include_summary = true
    })
    
    local csv_output = reporting.format_coverage(coverage_data, "csv")
    
    -- Check for summary row
    expect(csv_output).to.match("SUMMARY,150,105")
    expect(csv_output).to.match("70%.00") -- Overall coverage 70.00%
  end)
  
  it("can disable headers", function()
    -- Configure formatter without headers
    central_config.set("reporting.formatters.csv", {
      include_header = false
    })
    
    local csv_output = reporting.format_coverage(coverage_data, "csv")
    
    -- First line should be data, not header
    local lines = {}
    for line in csv_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    -- Should not contain the header
    expect(lines[1]).to_not.match("File,Lines,Covered Lines")
    
    -- Should start directly with data
    expect(lines[1]).to.match("/path/to/[^,]+,")
  end)
  
  it("handles missing nested fields", function()
    -- Create test data with missing fields
    local incomplete_data = test_helper.deep_copy(coverage_data)
    incomplete_data.files["/path/to/missing.lua"] = {
      -- Missing summary but has path
      lines = {
        [1] = { line_number = 1, executed = true, covered = true, execution_count = 1 }
      }
    }
    
    local csv_output = reporting.format_coverage(incomplete_data, "csv")
    
    -- Should still include the file but with empty values for missing fields
    expect(csv_output).to.match("/path/to/missing%.lua,")
    
    -- Configure for line level
    central_config.set("reporting.formatters.csv", {
      level = "line"
    })
    
    csv_output = reporting.format_coverage(incomplete_data, "csv")
    
    -- Should include the file's line even with missing data
    expect(csv_output).to.match("/path/to/missing%.lua,1,true")
  end)
  
  it("handles empty coverage data gracefully", function()
    local empty_data = {
      files = {},
      summary = {
        total_files = 0,
        total_lines = 0,
        covered_lines = 0,
        executed_lines = 0,
        not_covered_lines = 0,
        coverage_percent = 0,
        execution_percent = 0
      },
      data = {} -- Required by formatter.validate
    }
    
    local csv_output = reporting.format_coverage(empty_data, "csv")
    
    -- Should still return valid CSV
    expect(csv_output).to.exist()
    expect(type(csv_output)).to.equal("string")
    
    -- Should have a header but no data rows
    local lines = {}
    for line in csv_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    expect(#lines).to.equal(1) -- Only header, no data rows
    expect(lines[1]).to.match("File,Lines,Covered Lines")
    
    -- Line level should also handle empty data
    central_config.set("reporting.formatters.csv", {
      level = "line"
    })
    
    csv_output = reporting.format_coverage(empty_data, "csv")
    
    lines = {}
    for line in csv_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    expect(#lines).to.equal(1) -- Only header, no data rows
    expect(lines[1]).to.match("File,Line,Executed")
  end)
  
  it("handles nil coverage data", { expect_error = true }, function()
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_coverage(nil, "csv")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with CSV format
      expect(type(result)).to.equal("string")
      -- First line should still be header
      expect(result).to.match("File,Lines,Covered Lines")
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
    end
  end)
  
  it("handles malformed coverage data gracefully", { expect_error = true }, function()
    -- Test with incomplete coverage data
    local malformed_data = {
      -- Missing summary field
      files = {
        ["/path/to/malformed.lua"] = {
          -- Missing required fields
        }
      }
      -- Missing data field required by formatter.validate
    }
    
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_coverage(malformed_data, "csv")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with CSV format
      expect(type(result)).to.equal("string")
      expect(result).to.match("File,Lines,Covered Lines")
      -- Should include the malformed file
      expect(result).to.match("/path/to/malformed%.lua")
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
      -- Specific validation error checking
      expect(err.message).to.match("Coverage data must contain 'data' field")
    end
  end)
  
  it("handles file operation errors properly", { expect_error = true }, function()
    -- Generate CSV and save it to a file
    local file_path = test_dir .. "/coverage.csv"
    local success = reporting.save_coverage_report(file_path, coverage_data, "csv")
    
    -- Should succeed
    expect(success).to.equal(true)
    expect(fs.file_exists(file_path)).to.equal(true)
    
    -- Try to save to an invalid path
    local invalid_path = "/tmp/firmo-test*?<>|/coverage.csv"
    
    -- Use error_capture to handle expected errors
    local success_invalid_save, save_err = test_helper.with_error_capture(function()
      local result, err = reporting.save_coverage_report(invalid_path, coverage_data, "csv")
      if err then
        return false, err
      else
        return result
      end
    end)()
    
    -- Should fail due to invalid path
    expect(success_invalid_save).to.equal(false)
    expect(save_err).to.exist()
    
    -- Try to save with nil data
    local nil_success, nil_err = test_helper.with_error_capture(function()
      return reporting.save_coverage_report(file_path, nil, "csv")
    end)()
    
    -- Should fail with nil data
    expect(nil_success).to.equal(false)
    
    -- The test passes implicitly if we reach this point without crashing
  end)
  
  it("ensures data structure normalization", function()
    -- Create incomplete data that needs normalization
    local incomplete_data = {
      files = {
        ["/path/to/normalize.lua"] = {
          -- Minimal data that should be normalized by the formatter
          lines = {
            [1] = { line_number = 1 }, -- Missing executed and covered fields
            [2] = {} -- Completely empty line data
          },
          functions = {
            ["normalize_func"] = { name = "normalize_func" } -- Missing other fields
          }
        }
      },
      -- No summary, should be created by normalization
      data = {}
    }
    
    -- Process with CSV formatter
    local csv_output = reporting.format_coverage(incomplete_data, "csv")
    
    -- Check if output was generated despite incomplete data
    expect(csv_output).to.exist()
    expect(type(csv_output)).to.equal("string")
    
    -- The output should have a header and data for the file
    expect(csv_output).to.match("File,Lines,Covered Lines")
    expect(csv_output).to.match("/path/to/normalize%.lua")
    
    -- Line level should also normalize data
    central_config.set("reporting.formatters.csv", {
      level = "line"
    })
    
    csv_output = reporting.format_coverage(incomplete_data, "csv")
    
    -- Check if line-level output includes normalized values
    expect(csv_output).to.match("File,Line,Executed,Covered")
    expect(csv_output).to.match("/path/to/normalize%.lua,1")
    expect(csv_output).to.match("/path/to/normalize%.lua,2")
  end)
  
  it("handles large datasets efficiently", function()
    -- Create large test data with many files and lines
    local large_data = {
      files = {},
      summary = {
        total_files = 100,
        total_lines = 10000,
        covered_lines = 7500,
        executed_lines = 500,
        not_covered_lines = 2000,
        coverage_percent = 75,
        execution_percent = 80
      },
      data = {}
    }
    
    -- Add 100 files with similar structure
    for i = 1, 100 do
      local file_path = "/path/to/large_file_" .. i .. ".lua"
      large_data.files[file_path] = {
        summary = {
          total_lines = 100,
          covered_lines = 75,
          executed_lines = 5,
          not_covered_lines = 20,
          coverage_percent = 75,
          execution_percent = 80
        },
        lines = {},
        functions = {}
      }
      
      -- Add a few lines per file (we don't need all 100 for performance testing)
      for j = 1, 10 do
        large_data.files[file_path].lines[j] = {
          line_number = j,
          executed = j % 4 ~= 0, -- 75% coverage
          covered = j % 4 ~= 0,
          execution_count = j % 4 ~= 0 and 1 or 0
        }
      end
    end
    
    -- Start measuring time for file-level output
    local start_time = os.clock()
    
    -- Format the large dataset
    local csv_output = reporting.format_coverage(large_data, "csv")
    
    -- End measuring time
    local end_time = os.clock()
    local file_execution_time = end_time - start_time
    
    -- Check output validity
    expect(csv_output).to.exist()
    expect(type(csv_output)).to.equal("string")
    
    -- Should have 101 lines (header + 100 files)
    local lines = {}
    for line in csv_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    expect(#lines).to.equal(101)
    
    -- Configure for line-level output and test performance
    central_config.set("reporting.formatters.csv", {
      level = "line"
    })
    
    -- Start measuring time for line-level output
    start_time = os.clock()
    
    -- Format the large dataset
    csv_output = reporting.format_coverage(large_data, "csv")
    
    -- End measuring time
    end_time = os.clock()
    local line_execution_time = end_time - start_time
    
    -- Check output validity
    expect(csv_output).to.exist()
    expect(type(csv_output)).to.equal("string")
    
    -- Should have 1001 lines (header + 10 lines * 100 files)
    lines = {}
    for line in csv_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    expect(#lines).to.equal(1001)
    
    -- Performance should be reasonable - file level should be faster than line level
    expect(file_execution_time).to.be_less_than(1.0)
    expect(line_execution_time).to.be_less_than_or_equal_to(file_execution_time * 10)
  end)
end)
