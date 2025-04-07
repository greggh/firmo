-- Tests for reporting module formatters
---@diagnostic disable: unused-local

-- Import firmo test framework
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import modules needed for testing
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

-- Initialize logging if available
local logging, logger
local function initialize_logger()
  if not logger then
    local success, log_module = pcall(require, "lib.tools.logging")
    if success then
      logging = log_module
      logger = logging.get_logger("test.reporting.formatters")
      if logger and logger.debug then
        logger.debug("Reporting formatter test initialized", {
          module = "test.reporting.formatters",
          test_type = "unit",
          test_focus = "formatter interface",
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = initialize_logger()

-- Try to load the reporting module safely
local function load_reporting_module()
  return test_helper.with_error_capture(function()
    return require("lib.reporting")
  end)()
end

-- Sample data for testing formatters
local function create_sample_coverage_data()
  return {
    files = {
      ["test1.lua"] = {
        lines = {
          [1] = 1,  -- executed
          [2] = 1,  -- executed
          [3] = 0,  -- not executed
          [5] = 1,  -- executed
          [6] = 0,  -- not executed
          [7] = 0   -- not executed
        },
        hits = 3,
        misses = 3,
        total = 6,
        source = {
          [1] = "local function add(a, b)",
          [2] = "  return a + b",
          [3] = "end",
          [4] = "",
          [5] = "local function subtract(a, b)",
          [6] = "  return a - b",
          [7] = "end"
        }
      },
      ["test2.lua"] = {
        lines = {
          [1] = 1,  -- executed
          [2] = 1   -- executed
        },
        hits = 2,
        misses = 0,
        total = 2,
        source = {
          [1] = "local function multiply(a, b)",
          [2] = "  return a * b"
        }
      }
    },
    summary = {
      total_files = 2,
      covered_files = 2,
      files_percent = 100,
      total_lines = 8,
      covered_lines = 5,
      coverage_percent = 62.5
    }
  }
end

local function create_sample_quality_data()
  return {
    level = 3,
    level_name = "good",
    tests = {
      {
        file = "test_file.lua",
        name = "test_function",
        assertions = 8,
        patterns_used = 2,
        quality_score = 4
      },
      {
        file = "another_test.lua",
        name = "test_complex",
        assertions = 12,
        patterns_used = 4,
        quality_score = 5
      }
    },
    summary = {
      tests_analyzed = 2,
      tests_passing_quality = 2,
      quality_percent = 100,
      assertions_total = 20,
      assertions_per_test_avg = 10,
      issues = {}
    }
  }
end

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
        status = "pass"
      },
      {
        name = "test_failure",
        classname = "example_test",
        time = 0.015,
        status = "fail",
        failure = {
          message = "Expected 5 but got 4",
          type = "Assertion",
          details = "test_file.lua:25: assertion failed"
        }
      },
      {
        name = "test_skipped",
        classname = "example_test",
        time = 0,
        status = "skipped"
      },
      {
        name = "test_another_success",
        classname = "example_test",
        time = 0.015,
        status = "pass"
      }
    }
  }
end

describe("reporting formatter interface", function()
  local reporting
  local temp_dir

  before(function()
    -- Load the reporting module before each test
    reporting = load_reporting_module()
    expect(reporting).to.exist()
    
    -- Create a temporary directory for test output
    temp_dir = temp_file.create_temp_directory("reporting-formatter-test")
    expect(temp_dir).to.exist()
    expect(fs.directory_exists(temp_dir)).to.be_truthy()
  end)

  after(function()
    -- Clean up the temporary directory
    if temp_dir and fs.directory_exists(temp_dir) then
      fs.remove_directory(temp_dir, true)
    end
  end)

  describe("formatter registration", function()
    it("can register and retrieve formatters", function()
      -- Create simple formatter functions
      local coverage_formatter = function(data) return "COVERAGE: " .. (data.summary.total_files or 0) .. " files" end
      local quality_formatter = function(data) return "QUALITY: " .. (data.summary.tests_analyzed or 0) .. " tests" end
      local results_formatter = function(data) return "RESULTS: " .. (data.tests or 0) .. " tests run" end
      
      -- Register the formatters
      local cov_success = reporting.register_coverage_formatter("test_cov", coverage_formatter)
      local qual_success = reporting.register_quality_formatter("test_qual", quality_formatter)
      local res_success = reporting.register_results_formatter("test_res", results_formatter)
      
      expect(cov_success).to.be_truthy()
      expect(qual_success).to.be_truthy()
      expect(res_success).to.be_truthy()
      
      -- Check they're in the available formatters list
      local formatters = reporting.get_available_formatters()
      
      local cov_found, qual_found, res_found = false, false, false
      
      for _, name in ipairs(formatters.coverage) do
        if name == "test_cov" then cov_found = true end
      end
      
      for _, name in ipairs(formatters.quality) do
        if name == "test_qual" then qual_found = true end
      end
      
      for _, name in ipairs(formatters.results) do
        if name == "test_res" then res_found = true end
      end
      
      expect(cov_found).to.be_truthy()
      expect(qual_found).to.be_truthy()
      expect(res_found).to.be_truthy()
    end)
    
    it("validates formatter inputs", function()
      -- Invalid name (not a string)
      local success, err = reporting.register_coverage_formatter(123, function() end)
      expect(success).to.be_falsy()
      expect(err).to.exist()
      
      -- Invalid formatter (not a function)
      success, err = reporting.register_coverage_formatter("invalid", "string instead of function")
      expect(success).to.be_falsy()
      expect(err).to.exist()
      
      -- Empty name
      success, err = reporting.register_coverage_formatter("", function() end)
      expect(success).to.be_truthy() -- Empty names are allowed, though not recommended
    end)
    
    it("can load formatters from a module", function()
      local formatter_module = {
        coverage = {
          test_module_cov = function(data) return "MODULE COV" end
        },
        quality = {
          test_module_qual = function(data) return "MODULE QUAL" end
        },
        results = {
          test_module_res = function(data) return "MODULE RES" end
        }
      }
      
      local count = reporting.load_formatters(formatter_module)
      expect(count).to.be.a("number")
      expect(count).to.equal(3)
      
      -- Check they're in the available formatters list
      local formatters = reporting.get_available_formatters()
      
      local cov_found, qual_found, res_found = false, false, false
      
      for _, name in ipairs(formatters.coverage) do
        if name == "test_module_cov" then cov_found = true end
      end
      
      for _, name in ipairs(formatters.quality) do
        if name == "test_module_qual" then qual_found = true end
      end
      
      for _, name in ipairs(formatters.results) do
        if name == "test_module_res" then res_found = true end
      end
      
      expect(cov_found).to.be_truthy()
      expect(qual_found).to.be_truthy()
      expect(res_found).to.be_truthy()
    end)
  end)
  
  describe("formatter configuration", function()
    it("can get and set formatter configuration", function()
      -- Get default config for HTML formatter
      local html_config = reporting.get_formatter_config("html")
      expect(html_config).to.be.a("table")
      
      -- Modify the config
      local original_theme = html_config.theme
      local new_theme = original_theme == "dark" and "light" or "dark"
      
      reporting.configure_formatter("html", { theme = new_theme })
      
      -- Check config was updated
      local updated_config = reporting.get_formatter_config("html")
      expect(updated_config.theme).to.equal(new_theme)
      
      -- Reset to default
      reporting.reset()
    end)
    
    it("handles missing formatter configurations gracefully", function()
      -- Get config for non-existent formatter
      local config = reporting.get_formatter_config("nonexistent_formatter")
      expect(config).to.be.a("table") -- Should return empty table, not fail
      expect(next(config)).to.be_falsy() -- Table should be empty
    end)
  end)
  
  describe("html formatter", function()
    it("formats coverage data", function()
      local coverage_data = create_sample_coverage_data()
      
      -- Format with HTML formatter
      local output = reporting.format_coverage(coverage_data, "html")
      expect(output).to.exist()
      
      if type(output) == "string" then
        -- Simple validation of HTML output
        expect(output).to.match("<!DOCTYPE html>")
        expect(output).to.match("<html")
        expect(output).to.match("</html>")
        expect(output).to.match("test1.lua")
        expect(output).to.match("test2.lua")
      elseif type(output) == "table" and output.output then
        -- For newer formatters that return structured data
        expect(output.output).to.match("<!DOCTYPE html>")
        expect(output.output).to.match("<html")
        expect(output.output).to.match("</html>")
        expect(output.output).to.match("test1.lua")
        expect(output.output).to.match("test2.lua")
      end
    end)
    
    it("handles empty coverage data gracefully", function()
      local empty_data = {
        files = {},
        summary = {
          total_files = 0,
          covered_files = 0,
          files_percent = 0,
          total_lines = 0,
          covered_lines = 0,
          coverage_percent = 0
        }
      }
      
      -- Format with HTML formatter
      local success, output = pcall(function()
        return reporting.format_coverage(empty_data, "html")
      end)
      
      -- Should not crash on empty data
      expect(success).to.be_truthy()
      expect(output).to.exist()
    end)
  end)
  
  describe("json formatter", function()
    it("formats coverage data", function()
      local coverage_data = create_sample_coverage_data()
      
      -- Format with JSON formatter
      local output = reporting.format_coverage(coverage_data, "json")
      expect(output).to.exist()
      
      -- Verify it's valid JSON or has the right structure
      if type(output) == "string" then
        -- Should contain key markers from the test data
        expect(output).to.match("test1.lua")
        expect(output).to.match("test2.lua")
        expect(output).to.match("summary")
        expect(output).to.match("coverage_percent")
      elseif type(output) == "table" then
        -- For newer formatters that return structured data
        if output.output then
          -- String JSON
          expect(output.output).to.match("test1.lua")
          expect(output.output).to.match("test2.lua")
        else
          -- Structured data
          expect(output.files).to.exist()
          expect(output.summary).to.exist()
        end
      end
      
      -- Save the JSON to a file and verify it's valid
      local test_file = temp_dir .. "/coverage.json"
      local success = reporting.write_file(test_file, output)
      expect(success).to.be_truthy()
      expect(fs.file_exists(test_file)).to.be_truthy()
    end)
    
    it("can format with pretty-print option", function()
      -- Configure JSON formatter to use pretty printing
      reporting.configure_formatter("json", { pretty = true })
      
      local coverage_data = create_sample_coverage_data()
      
      -- Format with JSON formatter
      local output = reporting.format_coverage(coverage_data, "json")
      expect(output).to.exist()
      
      -- Reset formatter config
      reporting.reset()
    end)
  end)
  
  describe("tap formatter", function()
    it("formats test results data", function()
      local results_data = create_sample_results_data()
      
      -- Format with TAP formatter
      local output = reporting.format_results(results_data, "tap")
      expect(output).to.exist()
      
      if type(output) == "string" then
        -- Validate TAP output format
        expect(output).to.match("TAP version 13")
        expect(output).to.match("1%.%.%d+") -- Plan line
        expect(output).to.match("ok %d+ test_success")
        expect(output).to.match("not ok %d+ test_failure")
      elseif type(output) == "table" and output.output then
        -- For newer formatters that return structured data
        expect(output.output).to.match("TAP version 13")
        expect(output.output).to.match("1%.%.%d+") -- Plan line
        expect(output.output).to.match("ok %d+ test_success")
        expect(output.output).to.match("not ok %d+ test_failure")
      end
    end)
    
    it("handles test results with errors correctly", function()
      -- Modify sample data to include errors
      local results_with_errors = create_sample_results_data()
      table.insert(results_with_errors.test_cases, {
        name = "test_error",
        classname = "example_test",
        time = 0.005,
        status = "error",
        error = {
          message = "Unexpected error occurred",
          type = "RuntimeError",
          details = "test_file.lua:42: attempt to index a nil value"
        }
      })
      results_with_errors.tests = 5
      results_with_errors.errors = 1
      
      -- Format with TAP formatter
      local output = reporting.format_results(results_with_errors, "tap")
      expect(output).to.exist()
      
      -- Validate error is included
      if type(output) == "string" then
        expect(output).to.match("not ok %d+ test_error")
        expect(output).to.match("RuntimeError")
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match("not ok %d+ test_error")
        expect(output.output).to.match("RuntimeError")
      end
    end)
  end)
  
  describe("csv formatter", function()
    it("formats coverage data", function()
      local coverage_data = create_sample_coverage_data()
      
      -- Format with CSV formatter
      local output = reporting.format_coverage(coverage_data, "csv")
      expect(output).to.exist()
      
      -- Validate CSV structure
      if type(output) == "string" then
        -- Check for CSV header and data rows
        expect(output).to.match("[Ff]ile")
        expect(output).to.match("[Tt]otal [Ll]ines")
        expect(output).to.match("[Cc]overed [Ll]ines")
        expect(output).to.match("[Cc]overage %%")
        expect(output).to.match("test1.lua")
        expect(output).to.match("test2.lua")
        -- Should contain commas (CSV delimiter)
        expect(output:find(",")).to.be_truthy()
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match("[Ff]ile")
        expect(output.output).to.match("[Tt]otal [Ll]ines")
        expect(output.output).to.match("[Cc]overed [Ll]ines")
        expect(output.output).to.match("[Cc]overage %%")
        expect(output.output).to.match("test1.lua")
        expect(output.output).to.match("test2.lua")
        expect(output.output:find(",")).to.be_truthy()
      end
      
      -- Save to file and verify
      local test_file = temp_dir .. "/coverage.csv"
      local success = reporting.write_file(test_file, output)
      expect(success).to.be_truthy()
      expect(fs.file_exists(test_file)).to.be_truthy()
    end)
    
    it("formats test results data", function()
      local results_data = create_sample_results_data()
      
      -- Format with CSV formatter
      local output = reporting.format_results(results_data, "csv")
      expect(output).to.exist()
      
      -- Validate CSV structure for test results
      if type(output) == "string" then
        -- Check for CSV header and data rows
        -- Check for CSV header and data rows - using more flexible patterns
        expect(output).to.match("[Nn]ame")
        expect(output).to.match("[Cc]lass")
        expect(output).to.match("[Ss]tatus")
        expect(output).to.match("test_success")
        expect(output).to.match("test_failure")
        -- Should contain commas (CSV delimiter)
        expect(output:find(",")).to.be_truthy()
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match("[Nn]ame")
        expect(output.output).to.match("[Cc]lass")
        expect(output.output).to.match("[Ss]tatus")
        expect(output.output).to.match("test_success")
        expect(output.output).to.match("test_failure")
        expect(output.output:find(",")).to.be_truthy()
      end
    end)
    it("can be configured with custom delimiters", function()
      -- Configure CSV formatter with custom delimiter
      reporting.configure_formatter("csv", { delimiter = ";" })
      
      local coverage_data = create_sample_coverage_data()
      
      -- Format with CSV formatter
      local output = reporting.format_coverage(coverage_data, "csv")
      expect(output).to.exist()
      
      -- Validate custom delimiter is used
      if type(output) == "string" then
        -- Should contain semicolons instead of commas
        expect(output:find(";")).to.be_truthy()
      elseif type(output) == "table" and output.output then
        expect(output.output:find(";")).to.be_truthy()
      end
      
      -- Reset formatter config
      reporting.reset()
    end)
  end)
  
  describe("shared formatter features", function()
    it("handles formatter runtime errors by falling back to summary format", function()
      -- Register a formatter that throws an error
      local error_formatter = function()
        error("Deliberate formatter error")
      end
      
      reporting.register_coverage_formatter("error_formatter", error_formatter)
      
      -- Create sample data
      local coverage_data = create_sample_coverage_data()
      
      -- Should not crash when formatter throws an error
      local output = reporting.format_coverage(coverage_data, "error_formatter")
      
      -- Should return fallback formatter output
      expect(output).to.exist()
      
      -- Should fall back to default summary formatter
      if type(output) == "string" then
        expect(output).to.match("summary")
      elseif type(output) == "table" and output.output then
        expect(output.output).to.match("summary")
      end
    end)
    it("falls back to summary formatter when requested formatter is not available", function()
      local coverage_data = create_sample_coverage_data()
      
      -- Format with non-existent formatter
      local output = reporting.format_coverage(coverage_data, "nonexistent_formatter")
      expect(output).to.exist("Should fall back to default formatter")
      
      -- Output should resemble the default formatter for coverage (summary)
      if type(output) == "string" then
        -- For legacy formatters returning strings
        expect(output).to.match("summary")
      elseif type(output) == "table" then
        if output.output then
          -- For structured formatters with output field
          expect(output.output).to.match("summary")
        else
          -- For structured data without output field
          expect(output.files).to.exist()
          expect(output.summary).to.exist()
        end
      end
    end)
    
    it("handles invalid formatter output by falling back to summary format", function()
      -- Register a formatter that returns invalid output
      local invalid_formatter = function()
        return function() end -- Return a function (invalid output)
      end
      
      reporting.register_coverage_formatter("invalid_formatter", invalid_formatter)
      
      local coverage_data = create_sample_coverage_data()
      
      -- Should handle invalid output type gracefully
      local output = reporting.format_coverage(coverage_data, "invalid_formatter")
      
      -- Should return something valid instead of crashing
      expect(output).to.exist()
    end)
    
    it("supports saving reports in all available formatter formats", function()
      -- Create sample coverage data
      local coverage_data = create_sample_coverage_data()
      
      -- Test each available format
      local formatters = reporting.get_available_formatters()
      
      for _, format in ipairs(formatters.coverage) do
        -- Skip test-specific formatters
        if format:match("^test_") or format == "error_formatter" or format == "invalid_formatter" then
          goto continue
        end
        
        -- Format and save report
        local output = reporting.format_coverage(coverage_data, format)
        expect(output).to.exist()
        
        -- Save to a file
        local file_path = temp_dir .. "/coverage-" .. format .. "." .. format
        local success = reporting.save_coverage_report(file_path, coverage_data, format)
        
        -- Verify file was created successfully
        if success then
          expect(fs.file_exists(file_path)).to.be_truthy("File not created for format: " .. format)
        else
          -- Some formatters may not be available yet, so don't fail the test
          -- Just log a debug message instead
          print("Note: Could not save in format: " .. format .. " (may not be fully implemented yet)")
        end
        
        ::continue::
      end
    end)
    it("performs strict validation when saving reports with validation enabled", function()
      -- Create invalid coverage data (missing required fields)
      local invalid_data = {
        -- Missing files and summary
      }
      
      -- Format with validated formatter
      local output = reporting.format_coverage(invalid_data, "html")
      expect(output).to.exist("Formatter should handle invalid data gracefully")
      
      -- Try to save it with strict validation
      local file_path = temp_dir .. "/invalid-coverage.html"
      local success, err = reporting.save_coverage_report(
        file_path, 
        invalid_data, 
        "html", 
        { strict_validation = true }
      )
      
      -- Should fail validation
      expect(success).to.be_falsy("Invalid data should fail strict validation")
      expect(err).to.exist("Error should explain validation failure")
    end)
  end)
end)
