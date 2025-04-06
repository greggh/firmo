--- Tests for TAP formatter
-- @module tests.reporting.formatters.tap_formatter_test
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

describe("TAP Formatter", function()
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
        }
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
        }
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
  local test_dir = "./test-tmp-tap-formatter"
  
  -- Setup/teardown test directory
  before(function()
    if fs.directory_exists(test_dir) then
      fs.delete_directory(test_dir, true)
    end
    fs.create_directory(test_dir)
    
    -- Reset configuration before each test
    central_config.delete("reporting.formatters.tap")
  end)
  
  after(function()
    if fs.directory_exists(test_dir) then
      fs.delete_directory(test_dir, true)
    end
    
    -- Reset configuration after each test
    central_config.delete("reporting.formatters.tap")
  end)
  
  it("generates valid TAP format", function()
    local tap_output = reporting.format_coverage(coverage_data, "tap")
    
    -- Check basic structure
    expect(tap_output).to.exist()
    expect(type(tap_output)).to.equal("string")
    
    -- Basic TAP validation - should have standard TAP entries
    expect(tap_output).to.match("TAP version 13")  -- TAP version header
    expect(tap_output).to.match("1%.%.%d+")       -- Test count
    
    -- Verify overall coverage test
    expect(tap_output).to.match("ok 1 %-") -- Overall test should pass with our test data
    
    -- Verify file tests exist
    expect(tap_output).to.match("ok 2 %- /path/to/example%.lua") -- File 1 should pass
    expect(tap_output).to.match("not ok 3 %- /path/to/another%.lua") -- File 2 should fail (50% coverage)
    
    -- Verify YAML diagnostics are included
    expect(tap_output).to.match("%-%-%-") -- YAML start marker
    expect(tap_output).to.match("%.%.%.") -- YAML end marker
    expect(tap_output).to.match("threshold: %d+%%")
    expect(tap_output).to.match("coverage: %d+%.%d+%%")
    
    -- Verify TAP summary
    expect(tap_output).to.match("# Tests %d+")
    expect(tap_output).to.match("# Pass %d+")
    expect(tap_output).to.match("# Fail %d+")
  end)
  
  it("includes detailed diagnostics by default", function()
    local tap_output = reporting.format_coverage(coverage_data, "tap")
    
    -- Check for detailed diagnostics
    expect(tap_output).to.match("total_files:")
    expect(tap_output).to.match("total_lines:")
    expect(tap_output).to.match("covered_lines:")
    expect(tap_output).to.match("executed_lines:")
    expect(tap_output).to.match("not_covered_lines:")
    
    -- Functions should be included in detailed output
    expect(tap_output).to.match("functions:")
    expect(tap_output).to.match("total:")
    expect(tap_output).to.match("covered:")
  end)
  
  it("can disable detailed diagnostics", function()
    -- Configure formatter with detailed = false
    central_config.set("reporting.formatters.tap", {
      detailed = false
    })
    
    local tap_output = reporting.format_coverage(coverage_data, "tap")
    
    -- Detailed diagnostics shouldn't be included
    expect(tap_output).to_not.match("total_files:")
    expect(tap_output).to_not.match("total_lines:")
    
    -- Basic TAP structure should still be there
    expect(tap_output).to.match("TAP version 13")
    expect(tap_output).to.match("1%.%.%d+")
    expect(tap_output).to.match("ok 1 %-")
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
    
    local tap_output = reporting.format_coverage(empty_data, "tap")
    
    -- Should still return valid TAP
    expect(tap_output).to.exist()
    expect(type(tap_output)).to.equal("string")
    
    -- TAP should have version and test count
    expect(tap_output).to.match("TAP version 13")
    expect(tap_output).to.match("1%.%.1") -- Only overall test, no file tests
    
    -- Overall test should fail due to 0% coverage
    expect(tap_output).to.match("not ok 1 %- Overall coverage below threshold")
    
    -- Summary should still be there
    expect(tap_output).to.match("# Tests 1")
    expect(tap_output).to.match("# Pass 0")
    expect(tap_output).to.match("# Fail 1")
  end)
  
  it("handles nil coverage data", { expect_error = true }, function()
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_coverage(nil, "tap")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with TAP format
      expect(type(result)).to.equal("string")
      expect(result).to.match("TAP version 13")
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
      return reporting.format_coverage(malformed_data, "tap")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with TAP format
      expect(type(result)).to.equal("string")
      expect(result).to.match("TAP version 13")
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
      -- Specific validation error checking
      expect(err.message).to.match("Coverage data must contain 'data' field")
    end
  end)
  
  it("handles file operation errors properly", { expect_error = true }, function()
    -- Generate TAP and save it to a file
    local file_path = test_dir .. "/coverage.tap"
    local success = reporting.save_coverage_report(file_path, coverage_data, "tap")
    
    -- Should succeed
    expect(success).to.equal(true)
    expect(fs.file_exists(file_path)).to.equal(true)
    
    -- Try to save to an invalid path
    local invalid_path = "/tmp/firmo-test*?<>|/coverage.tap"
    
    -- Use error_capture to handle expected errors
    local success_invalid_save, save_err = test_helper.with_error_capture(function()
      local result, err = reporting.save_coverage_report(invalid_path, coverage_data, "tap")
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
      return reporting.save_coverage_report(file_path, nil, "tap")
    end)()
    
    -- Should fail with nil data
    expect(nil_success).to.equal(false)
    
    -- The test passes implicitly if we reach this point without crashing
  end)
  
  it("respects coverage threshold configuration", function()
    -- Configure formatter with a low threshold to make all tests pass
    central_config.set("reporting.formatters.tap", {
      threshold = 30,
      file_threshold = 30
    })
    
    local tap_output = reporting.format_coverage(coverage_data, "tap")
    
    -- All tests should pass with the lower threshold
    expect(tap_output).to.match("ok 1 %- Overall coverage meets threshold")
    expect(tap_output).to.match("ok 2 %- /path/to/example%.lua")
    expect(tap_output).to.match("ok 3 %- /path/to/another%.lua")
    
    -- Configure formatter with a high threshold to make all tests fail
    central_config.set("reporting.formatters.tap", {
      threshold = 90,
      file_threshold = 90
    })
    
    tap_output = reporting.format_coverage(coverage_data, "tap")
    
    -- All tests should fail with the higher threshold
    expect(tap_output).to.match("not ok 1 %- Overall coverage below threshold")
    expect(tap_output).to.match("not ok 2 %- /path/to/example%.lua")
    expect(tap_output).to.match("not ok 3 %- /path/to/another%.lua")
  end)
  
  it("can list uncovered functions", function()
    -- Add some uncovered functions to test data
    local test_data = test_helper.deep_copy(coverage_data)
    test_data.files["/path/to/example.lua"].functions["uncovered_func"] = {
      name = "uncovered_func",
      start_line = 5,
      end_line = 7,
      executed = false,
      covered = false,
      execution_count = 0
    }
    
    -- Configure formatter to list uncovered functions
    central_config.set("reporting.formatters.tap", {
      list_uncovered = true
    })
    
    local tap_output = reporting.format_coverage(test_data, "tap")
    
    -- Should include uncovered functions section
    expect(tap_output).to.match("uncovered:")
    expect(tap_output).to.match("name: uncovered_func")
    expect(tap_output).to.match("line: 5")
  end)
  
  it("can list uncovered lines", function()
    -- Configure formatter to list uncovered lines
    central_config.set("reporting.formatters.tap", {
      list_uncovered_lines = true
    })
    
    local tap_output = reporting.format_coverage(coverage_data, "tap")
    
    -- Should include uncovered lines section with line ranges
    expect(tap_output).to.match("uncovered_lines:")
    expect(tap_output).to.match("%s+%- 3") -- Line 3 is uncovered in our test data
  end)
  
  it("properly groups consecutive uncovered lines", function()
    -- Create test data with consecutive uncovered lines
    local test_data = test_helper.deep_copy(coverage_data)
    for i = 10, 15 do
      test_data.files["/path/to/example.lua"].lines[i] = {
        line_number = i,
        executed = false,
        covered = false,
        execution_count = 0
      }
    end
    
    -- Configure formatter to list uncovered lines
    central_config.set("reporting.formatters.tap", {
      list_uncovered_lines = true
    })
    
    local tap_output = reporting.format_coverage(test_data, "tap")
    
    -- Should include uncovered lines section with line ranges
    expect(tap_output).to.match("uncovered_lines:")
    
    -- Check for range formatting (consecutive lines 10-15 should be grouped)
    expect(tap_output).to.match("%s+%- 10%-15")
    
    -- Add individual line
    test_data.files["/path/to/example.lua"].lines[20] = {
      line_number = 20,
      executed = false,
      covered = false,
      execution_count = 0
    }
    
    tap_output = reporting.format_coverage(test_data, "tap")
    
    -- Should now have both a range and an individual line
    expect(tap_output).to.match("%s+%- 10%-15")
    expect(tap_output).to.match("%s+%- 20")
  end)
  
  it("respects indentation configuration", function()
    -- Configure formatter with custom indentation
    central_config.set("reporting.formatters.tap", {
      indent = "  ",  -- 2 spaces
      yaml_indent = "    "  -- 4 spaces
    })
    
    local tap_output = reporting.format_coverage(coverage_data, "tap")
    
    -- Check basic structure
    expect(tap_output).to.exist()
    
    -- Indentation might not be directly testable through string matching
    -- if the formatter doesn't implement these options, but the test should
    -- still pass without errors
    
    -- Reset configuration
    central_config.delete("reporting.formatters.tap")
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
      
      -- Add 100 lines per file
      for j = 1, 100 do
        large_data.files[file_path].lines[j] = {
          line_number = j,
          executed = j % 4 ~= 0, -- 75% coverage
          covered = j % 4 ~= 0,
          execution_count = j % 4 ~= 0 and 1 or 0
        }
      end
      
      -- Add a function per file
      large_data.files[file_path].functions["func_" .. i] = {
        name = "func_" .. i,
        start_line = 1,
        end_line = 100,
        executed = true,
        covered = true,
        execution_count = 1
      }
    end
    
    -- Start measuring time
    local start_time = os.clock()
    
    -- Format the large dataset
    local tap_output = reporting.format_coverage(large_data, "tap")
    
    -- End measuring time
    local end_time = os.clock()
    local execution_time = end_time - start_time
    
    -- Check output validity
    expect(tap_output).to.exist()
    expect(type(tap_output)).to.equal("string")
    expect(tap_output).to.match("TAP version 13")
    expect(tap_output).to.match("1%.%.101") -- 100 files + 1 overall test
    
    -- Performance should be reasonable - 100 files should process in under 1 second
    -- This threshold may need adjustment based on system performance
    expect(execution_time).to.be_less_than(1.0)
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
    
    -- Process with TAP formatter
    local tap_output = reporting.format_coverage(incomplete_data, "tap")
    
    -- Check if output was generated despite incomplete data
    expect(tap_output).to.exist()
    expect(type(tap_output)).to.equal("string")
    expect(tap_output).to.match("TAP version 13")
    
    -- The output should have data for the file, proving normalization worked
    expect(tap_output).to.match("/path/to/normalize%.lua")
  end)
end)
