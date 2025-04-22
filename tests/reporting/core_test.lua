-- Core testing for the reporting module
---@diagnostic disable: unused-local

-- Import firmo test framework
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import modules needed for testing
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")

-- Initialize logging if available
local logging, logger
local function initialize_logger()
  if not logger then
    local success, log_module = pcall(require, "lib.tools.logging")
    if success then
      logging = log_module
      logger = logging.get_logger("test.reporting")
      if logger and logger.debug then
        logger.debug("Reporting core test initialized", {
          module = "test.reporting",
          test_type = "unit",
          test_focus = "core API",
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

describe("lib.reporting", function()
  local reporting
  local temp_dir

  before(function()
    -- Load the reporting module before each test
    reporting = load_reporting_module()
    expect(reporting).to.exist()

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

  describe("error handling", function()
    -- Sample coverage data shared between tests
    local sample_coverage_data = {
      files = { ["test.lua"] = { lines = {} } },
      summary = { total_files = 1 },
    }

    it("formatter throws expected error when called directly", { expect_error = true }, function()
      -- Create an error-throwing formatter for direct testing
      local error_formatter = function(coverage_data)
        error("Deliberate error in formatter")
      end

      -- Test the formatter directly with expect_error
      local err = test_helper.expect_error(function()
        error_formatter(sample_coverage_data)
      end)

      -- Verify error details
      expect(err).to.exist()
      expect(err.message).to.match("Deliberate error in formatter")
    end)

    it("reporting module handles formatter errors gracefully", { expect_error = true }, function()
      -- Register a formatter that throws an error
      local error_thrown = false
      local error_formatter = function(coverage_data)
        error_thrown = true
        error("Deliberate error in formatter")
      end

      reporting.register_coverage_formatter("error_formatter", error_formatter)

      -- Verify the reporting module handles the error gracefully
      local result = reporting.format_coverage(sample_coverage_data, "error_formatter")

      -- Formatter should have been called (and triggered an error internally)
      expect(error_thrown).to.be_truthy()

      -- Should fall back to a different formatter when there's an error
      expect(result).to.exist()

      -- Check output format properly based on its type
      if type(result) == "string" then
        -- If result is a string, it should contain "summary" text
        expect(result).to.match("summary")
      elseif type(result) == "table" then
        -- If result is a table, it should have appropriate fields
        if result.output then
          -- Some formatters return {output = "string"} structure
          expect(result.output).to.be.a("string")
        end

        -- The table should have some coverage data fields
        local has_coverage_fields = (
          result.total_files ~= nil
          or result.files ~= nil
          or result.summary ~= nil
          or result.overall_pct ~= nil
        )
        expect(has_coverage_fields).to.be_truthy("Result should contain coverage data fields")
      end
    end)
  end)

  describe("configuration", function()
    it("can be configured with options", function()
      -- Configure with debug option
      local result = reporting.configure({ debug = true })

      -- Should return self for chaining
      expect(result).to.equal(reporting)

      -- Get current config
      local config = reporting.debug_config()
      expect(config).to.be.a("table")
      expect(config.local_config).to.be.a("table")
      expect(config.local_config.debug).to.equal(true)
    end)

    it("can configure specific formatters", function()
      -- Configure HTML formatter
      local result = reporting.configure_formatter("html", {
        theme = "light",
        show_line_numbers = false,
      })

      -- Should return self for chaining
      expect(result).to.equal(reporting)

      -- Get formatter config
      local html_config = reporting.get_formatter_config("html")
      expect(html_config).to.be.a("table")
      expect(html_config.theme).to.equal("light")
      expect(html_config.show_line_numbers).to.equal(false)
    end)

    it("can configure multiple formatters at once", function()
      -- Configure multiple formatters
      local result = reporting.configure_formatters({
        html = { theme = "dark" },
        json = { pretty = true },
      })

      -- Should return self for chaining
      expect(result).to.equal(reporting)

      -- Get formatter configs
      local html_config = reporting.get_formatter_config("html")
      local json_config = reporting.get_formatter_config("json")

      expect(html_config).to.be.a("table")
      expect(html_config.theme).to.equal("dark")

      expect(json_config).to.be.a("table")
      expect(json_config.pretty).to.equal(true)
    end)

    it("can be reset to defaults", function()
      -- First change configuration
      reporting.configure({ debug = true, verbose = true })

      -- Then reset
      local result = reporting.reset()

      -- Should return self for chaining
      expect(result).to.equal(reporting)

      -- Check config is reset
      local config = reporting.debug_config()
      expect(config.local_config.debug).to.be_falsy()
      expect(config.local_config.verbose).to.be_falsy()
    end)
  end)

  describe("formatter registration", function()
    it("can register a custom coverage formatter", function()
      -- Create a simple formatter function
      local my_formatter = function(coverage_data)
        return "TEST COVERAGE OUTPUT"
      end

      -- Register the formatter
      local success = reporting.register_coverage_formatter("test_format", my_formatter)
      expect(success).to.be_truthy()

      -- Get available formatters
      local formatters = reporting.get_available_formatters()
      expect(formatters).to.be.a("table")
      expect(formatters.coverage).to.be.a("table")

      -- Find our formatter in the list
      local found = false
      for _, name in ipairs(formatters.coverage) do
        if name == "test_format" then
          found = true
          break
        end
      end
      expect(found).to.be_truthy()
    end)

    it("can register a custom quality formatter", function()
      -- Create a simple formatter function
      local my_formatter = function(quality_data)
        return "TEST QUALITY OUTPUT"
      end

      -- Register the formatter
      local success = reporting.register_quality_formatter("test_quality", my_formatter)
      expect(success).to.be_truthy()

      -- Get available formatters
      local formatters = reporting.get_available_formatters()
      expect(formatters.quality).to.be.a("table")

      -- Find our formatter in the list
      local found = false
      for _, name in ipairs(formatters.quality) do
        if name == "test_quality" then
          found = true
          break
        end
      end
      expect(found).to.be_truthy()
    end)

    it("can register a custom results formatter", function()
      -- Create a simple formatter function
      local my_formatter = function(results_data)
        return "TEST RESULTS OUTPUT"
      end

      -- Register the formatter
      local success = reporting.register_results_formatter("test_results", my_formatter)
      expect(success).to.be_truthy()

      -- Get available formatters
      local formatters = reporting.get_available_formatters()
      expect(formatters.results).to.be.a("table")

      -- Find our formatter in the list
      local found = false
      for _, name in ipairs(formatters.results) do
        if name == "test_results" then
          found = true
          break
        end
      end
      expect(found).to.be.truthy()
    end)

    it("rejects registration with invalid formatter function", { expect_error = true }, function()
      -- Try to register with invalid formatter (not a function)
      local err = test_helper.expect_error(function()
        reporting.register_coverage_formatter("invalid_formatter", "not a function")
      end)

      -- Verify error details
      expect(err).to.exist()
      expect(err.message).to.match("must be a function")
      expect(err.context).to.exist()
      expect(err.context.provided_type).to.equal("string")
    end)
  end)

  describe("formatter usage", function()
    it("can format coverage data", function()
      -- First register a test formatter
      local test_formatter = function(coverage_data)
        return "TEST FORMATTER OUTPUT: "
          .. (coverage_data and coverage_data.summary and coverage_data.summary.total_files or "no data")
      end

      reporting.register_coverage_formatter("test_formatter", test_formatter)

      -- Create sample coverage data
      -- Create sample coverage data
      local coverage_data = {
        files = {
          ["test.lua"] = {
            lines = { [1] = 1, [2] = 0, [3] = 1 },
            total_lines = 3,
            covered_lines = 2,
            line_coverage_percent = 66.67,
          },
        },
        summary = {
          total_files = 1,
          covered_files = 1,
          total_lines = 3,
          covered_lines = 2,
          line_coverage_percent = 66.67,
        },
      }

      -- Format with our test formatter
      local output = reporting.format_coverage(coverage_data, "test_formatter")
      expect(output).to.be.a("string")
      expect(output).to.match("TEST FORMATTER OUTPUT: 1")

      -- Should fall back to default for unknown formatter
      local fallback_output = reporting.format_coverage(coverage_data, "nonexistent_formatter")
      expect(fallback_output).to.exist()
    end)
  end)

  describe("file operations", function()
    it("can write content to a file", function()
      local test_file = temp_dir .. "/test-write.txt"
      local test_content = "Test content"

      -- Write to file
      local success = reporting.write_file(test_file, test_content)
      expect(success).to.be_truthy()

      -- Verify file exists and has correct content
      expect(fs.file_exists(test_file)).to.be_truthy()
      local content = fs.read_file(test_file)
      expect(content).to.equal(test_content)
    end)

    it("rejects invalid or nil file paths", { expect_error = true }, function()
      -- Try with nil path
      local err = test_helper.expect_error(function()
        reporting.write_file(nil, "content")
      end)

      -- Verify error details
      expect(err).to.exist()
      expect(err.message).to.match("path")
      expect(err.context).to.exist()
      expect(err.context.provided_type).to.equal("nil")
    end)

    it("rejects invalid or nil content", { expect_error = true }, function()
      -- Try with nil content
      local err = test_helper.expect_error(function()
        reporting.write_file(temp_dir .. "/empty.txt", nil)
      end)

      -- Verify error details
      expect(err).to.exist()
      expect(err.message).to.match("content")
      expect(err.context).to.exist()
      expect(err.context.provided_type).to.equal("nil")
    end)
  end)

  describe("validation", function()
    it("validates coverage data structure", function()
      -- Create valid coverage data
      local valid_data = {
        files = {
          ["test.lua"] = {
            lines = { [1] = 1, [2] = 0, [3] = 1 },
            total_lines = 3,
            covered_lines = 2,
            line_coverage_percent = 66.67,
          },
        },
        summary = {
          total_files = 1,
          covered_files = 1,
          total_lines = 3,
          covered_lines = 2,
          line_coverage_percent = 66.67,
        },
      }

      -- Validate data (may pass or have warnings depending on validation implementation)
      local is_valid, issues = reporting.validate_coverage_data(valid_data)
      -- We don't make strong assertions about validity since the validation is complex
      expect(is_valid).to.exist()
      expect(is_valid).to.be_truthy()
    end)

    it("rejects invalid coverage data structure", { expect_error = true }, function()
      -- Create data with missing required fields
      local invalid_data = {
        files = {},
        -- missing summary
      }

      -- Attempt to validate invalid data with strict option
      local err = test_helper.expect_error(function()
        reporting.validate_coverage_data(invalid_data, { strict = true })
      end)

      -- Verify error details
      expect(err).to.exist()
      expect(err.message).to.match("validation")
      expect(err.context).to.exist()
      expect(err.context.errors).to.exist()
    end)
  end)

  describe("error handling", function()
    it("falls back to summary formatter when requested formatter not found", function()
      local coverage_data = {
        files = {
          ["test.lua"] = {
            lines = {},
            total_lines = 0,
            covered_lines = 0,
            line_coverage_percent = 0,
          },
        },
        summary = {
          total_files = 1,
          total_lines = 0,
          covered_lines = 0,
          line_coverage_percent = 0,
        },
      }

      -- Format with non-existent formatter
      local output = reporting.format_coverage(coverage_data, "nonexistent_formatter")

      -- Verify output exists
      expect(output).to.exist()

      -- Check output format properly based on its type
      if type(output) == "string" then
        -- If result is a string, it should contain "summary" text
        expect(output).to.match("summary")
      elseif type(output) == "table" then
        -- If result is a table, it should have appropriate fields
        if output.output then
          -- Some formatters return {output = "string"} structure
          expect(output.output).to.be.a("string")
        end

        -- The table should have some coverage data fields
        local has_coverage_fields = (
          output.total_files ~= nil
          or output.files ~= nil
          or output.summary ~= nil
          or output.overall_pct ~= nil
        )
        expect(has_coverage_fields).to.be_truthy("Result should contain coverage data fields")
      end
    end)

    it("handles missing files gracefully", { expect_error = true }, function()
      local coverage_data = {
        files = { ["test.lua"] = { lines = {} } },
        summary = { total_files = 1 },
      }

      local err = test_helper.expect_error(function()
        reporting.save_coverage_report("/nonexistent/directory/path/report.html", coverage_data, "html")
      end)

      expect(err).to.exist()
      expect(err.message).to.match("directory")
    end)

    it("handles validation errors properly", { expect_error = true }, function()
      -- Create invalid coverage data
      local invalid_data = {} -- completely empty, missing required fields

      -- Attempt to save with strict validation to ensure it fails
      local err = test_helper.expect_error(function()
        reporting.save_coverage_report(
          temp_dir .. "/invalid-report.html",
          invalid_data,
          "html",
          { strict_validation = true }
        )
      end)

      -- Should fail with validation error
      expect(err).to.exist()
      expect(err.message).to.match("validation")
      expect(err.context).to.exist()
    end)

    it("handles configuration errors", { expect_error = true }, function()
      -- Attempt to configure with invalid values
      local err = test_helper.expect_error(function()
        reporting.configure_formatter("nonexistent", "not a table")
      end)

      -- Verify error details
      expect(err).to.exist()
      expect(err.message).to.match("configuration")
      expect(err.context).to.exist()
      expect(err.context.provided_type).to.equal("string")

      -- Validate formatter was not registered with invalid configuration
      local formatters = reporting.get_available_formatters()
      local found = false
      for _, name in ipairs(formatters.coverage) do
        if name == "nonexistent" then
          found = true
          break
        end
      end
      expect(found).to.be_falsy()
    end)
  end)
end)
