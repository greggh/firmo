--- Example demonstrating the Firmo reporting module and its various formatters.
---
--- This example showcases:
--- - Basic test structure using Firmo's BDD syntax (`describe`, `it`) and `expect` assertions.
--- - Generating coverage data for a simple module (`calculator`).
--- - Using `reporting.format_coverage` to generate reports in all 8 supported formats (html, json, lcov, tap, csv, junit, cobertura, summary).
--- - Saving generated reports to files using `reporting.write_file`.
--- - Configuring formatters (e.g., HTML theme, JSON pretty print) via `central_config`.
--- - Registering and using a custom report formatter.
--- - Using `reporting.auto_save_reports` for streamlined multi-format report generation.
---
--- **Important Note:**
--- This example uses **mock processed coverage data** passed directly to the reporting
--- functions. It does **not** perform actual test execution or coverage collection.
--- Its purpose is solely to demonstrate generating reports in various formats using
--- `reporting.format_coverage` and `reporting.auto_save_reports` with mock data.
--- In a real project, coverage data is collected via `lua test.lua --coverage ...`
--- and reports are generated based on the configuration.
---
--- @module examples.report_example
--- @see lib.reporting
--- @see lib.core.central_config
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @usage
--- Run embedded tests (coverage is handled internally for demo):
--- ```bash
--- lua test.lua examples/report_example.lua
--- ```
--- Run with runner coverage (results may differ slightly from internal demo):
--- ```bash
--- lua test.lua --coverage examples/report_example.lua
--- ```

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

-- Import helper modules
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging") -- Added missing require

-- Load required modules
local reporting = require("lib.reporting")
-- local coverage = require("lib.coverage") -- Removed: Using mock data
local central_config = require("lib.core.central_config")

-- Setup logger
local logger = logging.get_logger("ReportExample")

-- Mock processed coverage data structure for demonstration purposes.
local mock_processed_data = {
  files = {
    ["examples/report_example.lua"] = { -- Use this file conceptually
      filename = "examples/report_example.lua",
      lines = { -- line_num (string) = { hits=count }
        ["69"] = { hits = 1 }, -- calc.add
        ["77"] = { hits = 1 }, -- calc.subtract
        ["85"] = { hits = 1 }, -- calc.multiply
        ["94"] = { hits = 1 }, -- calc.divide (if branch)
        ["97"] = { hits = 1 }, -- calc.divide (return)
        ["105"] = { hits = 0 }, -- calc.power (not called)
      },
      functions = { -- func_name = { name, start_line, execution_count }
        ["add"] = { name = "add", start_line = 68, execution_count = 1 },
        ["subtract"] = { name = "subtract", start_line = 76, execution_count = 1 },
        ["multiply"] = { name = "multiply", start_line = 84, execution_count = 1 },
        ["divide"] = { name = "divide", start_line = 93, execution_count = 1 },
        ["power"] = { name = "power", start_line = 104, execution_count = 0 },
      },
      branches = { -- line_num (string) = { { hits=count }, { hits=count } }
        ["94"] = { { hits = 1 }, { hits = 0 } }, -- divide by zero check (false path hit)
      },
      executable_lines = 6,
      covered_lines = 5,
      line_rate = 5 / 6,
      line_coverage_percent = (5 / 6) * 100,
      total_lines = 442, -- Approx file total
      total_functions = 5,
      covered_functions = 4,
      function_coverage_percent = (4 / 5) * 100,
      total_branches = 1,
      covered_branches = 1, -- The 'false' path of the 'if b==0' was hit
      branch_coverage_percent = 100.0,
    },
  },
  summary = {
    executable_lines = 6,
    covered_lines = 5,
    line_coverage_percent = (5 / 6) * 100,
    total_lines = 442,
    total_functions = 5,
    covered_functions = 4,
    function_coverage_percent = (4 / 5) * 100,
    total_branches = 1,
    covered_branches = 1,
    branch_coverage_percent = 100.0,
    total_files = 1,
    covered_files = 1,
    overall_percent = (5 / 6) * 100,
  },
}

-- Some sample code to test coverage
--- Simple calculator module for testing.
--- @class Calculator
--- @field add fun(a: number, b: number): number Adds two numbers.
--- @field subtract fun(a: number, b: number): number Subtracts two numbers.
--- @field multiply fun(a: number, b: number): number Multiplies two numbers.
--- @field divide fun(a: number, b: number): number|nil, table|nil Divides two numbers, returns error on division by zero.
--- @field power fun(a: number, b: number): number Calculates `a` to the power of `b`.
--- @within examples.report_example
local calculator = {
  --- Adds two numbers.
  -- @param a number First number.
  -- @param b number Second number.
  -- @return number The sum.
  add = function(a, b)
    return a + b
  end,

  --- Subtracts the second number from the first.
  -- @param a number The number to subtract from.
  -- @param b number The number to subtract.
  -- @return number The difference.
  subtract = function(a, b)
    return a - b
  end,

  --- Multiplies two numbers.
  -- @param a number First number.
  -- @param b number Second number.
  -- @return number The product.
  multiply = function(a, b)
    return a * b
  end,

  --- Divides the first number by the second.
  -- @param a number The dividend.
  -- @param b number The divisor.
  -- @return number|nil The quotient, or `nil` on error.
  -- @return table|nil err A validation error object if `b` is 0.
  divide = function(a, b)
    if b == 0 then
      return nil, error_handler.validation_error("Cannot divide by zero", { parameter = "b", provided_value = b })
    end
    return a / b
  end,

  --- Calculates the first number raised to the power of the second.
  -- @param a number The base.
  -- @param b number The exponent.
  -- @return number The result of `a ^ b`.
  power = function(a, b)
    return a ^ b
  end,
}

-- Example tests using expect-style assertions (not assert style)
--- Test suite for the calculator module.
--- @within examples.report_example
describe("Report Example - Calculator", function()
  -- Track any resources that need cleanup
  local test_files = {}

  -- Cleanup any resources after tests
  after(function()
    for _, file_path in ipairs(test_files) do
      local success, err = pcall(function()
        if fs.file_exists(file_path) then
          fs.delete_file(file_path)
        end
      end)

      if not success then -- Check if firmo.log exists before calling
        logger.warn("Failed to remove test file: " .. tostring(err), {
          file_path = file_path,
        })
      end
    end
    test_files = {}
    temp_dir = nil -- Release reference
    -- temp_file module handles actual directory cleanup
  end)

  --- Tests for basic arithmetic operations.
  --- @within examples.report_example
  describe("Basic functions", function()
    --- Tests the `add` function.
    it("should add two numbers correctly", function()
      expect(calculator.add(2, 3)).to.equal(5)
      expect(calculator.add(-2, 2)).to.equal(0)
      expect(calculator.add(-5, -5)).to.equal(-10)
    end)

    --- Tests the `subtract` function.
    it("should subtract two numbers correctly", function()
      expect(calculator.subtract(10, 5)).to.equal(5)
      expect(calculator.subtract(5, 10)).to.equal(-5)
      expect(calculator.subtract(5, 5)).to.equal(0)
    end)

    --- Tests the `multiply` function.
    it("should multiply two numbers correctly", function()
      expect(calculator.multiply(2, 3)).to.equal(6)
      expect(calculator.multiply(-2, 3)).to.equal(-6)
      expect(calculator.multiply(-2, -3)).to.equal(6)
    end)
  end)

  --- Tests for more complex or error-prone operations.
  --- @within examples.report_example
  describe("Advanced functions", function()
    --- Tests the `divide` function with valid inputs.
    it("should divide two numbers correctly", function()
      expect(calculator.divide(10, 5)).to.equal(2)
      expect(calculator.divide(-10, 5)).to.equal(-2)

      -- Example of approximate comparison
      local result = calculator.divide(1, 3)
      expect(math.abs(result - 0.33333) < 0.001).to.be_truthy()
    end)

    -- Example of proper error testing using expect_error flag
    --- Tests that `divide` correctly returns an error when dividing by zero.
    it("should handle division by zero", { expect_error = true }, function()
      -- Use with_error_capture to safely call functions that may return errors
      local result, err = test_helper.with_error_capture(function()
        return calculator.divide(5, 0)
      end)()

      -- Make assertions about the error
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("divide by zero")
    end)
  end)

  -- The power function isn't tested, so coverage won't be 100%
end)

-- Examples of how to work with the reporting module
--- Test suite demonstrating various features of the reporting module.
--- @within examples.report_example
describe("Reporting Module Examples", function()
  -- Configuration for examples
  local temp_dir
  local report_files = {}

  -- Create a temp directory before tests
  before(function()
    temp_dir = test_helper.create_temp_test_directory("report_example_") -- Add prefix
    logger.info("Created temporary directory: " .. temp_dir.path)
  end)

  -- Clean up files after tests
  after(function()
    for _, file_path in ipairs(report_files) do
      if fs.file_exists(file_path) then
        fs.delete_file(file_path)
      end
    end
    report_files = {}
  end)

  -- Example demonstrating all 8 formatters
  --- Generates coverage reports using mock data and all 8 built-in formatters.
  it("demonstrates all 8 supported formatters", function()
    -- Use mock data instead of generating live coverage
    local coverage_data = mock_processed_data

    -- The 8 supported formatters
    local formatters = {
      "html", -- Interactive HTML with syntax highlighting
      "json", -- Machine-readable JSON format
      "lcov", -- Standard LCOV format for CI tools
      "tap", -- Test Anything Protocol format
      "csv", -- Comma-separated values for data analysis
      "junit", -- JUnit XML format for CI systems
      "cobertura", -- Cobertura XML format for CI/tools
      "summary", -- Text-based summary for terminal output
    }

    -- Generate and verify reports for each formatter
    for _, format in ipairs(formatters) do
      -- Generate the report using mock data
      local report, format_err = reporting.format_coverage(mock_processed_data, format)
      expect(format_err).to.be_nil("Formatting " .. format .. " should succeed")
      expect(report).to.exist()

      -- Save to file
      local file_ext = format
      if format == "cobertura" then
        file_ext = "xml"
      end

      local report_path = fs.join_paths(temp_dir.path, "coverage-" .. format .. "." .. file_ext)
      -- Note: reporting.write_file might not exist, use fs.write_file
      local success, err_str = fs.write_file(report_path, report)

      -- Record for cleanup
      if success then
        table.insert(report_files, report_path)
        firmo.log.info("Created " .. format .. " coverage report", {
          path = report_path,
          size = #report,
        })
      else
        logger.warn("Failed to write " .. format .. " report", {
          error = tostring(err_str), -- Use the error string
        })
      end
    end
  end)

  --- Shows how to configure formatter options (like HTML theme, JSON pretty print)
  -- using the `central_config` module.
  it("demonstrates formatter configuration via central_config", function()
    -- Configure formatters using central_config
    central_config.set("reporting.formatters.html", {
      theme = "dark",
      show_line_numbers = true,
      syntax_highlighting = true,
      simplified_large_files = true,
      max_lines_display = 200,
    })

    central_config.set("reporting.formatters.json", {
      pretty = true,
      indent = 2,
      include_source = false,
    })

    central_config.set("reporting.formatters.csv", {
      include_header = true,
      delimiter = ",",
      columns = {
        "path",
        "total_lines",
        "covered_lines",
        "coverage_percent",
      },
    })

    -- Use mock coverage data
    local data = mock_processed_data

    -- Generate configured reports using mock data
    local html_report, html_err = reporting.format_coverage(mock_processed_data, "html")
    local json_report, json_err = reporting.format_coverage(mock_processed_data, "json")
    local csv_report, csv_err = reporting.format_coverage(mock_processed_data, "csv")
    expect(html_err).to.be_nil()
    expect(json_err).to.be_nil()
    expect(csv_err).to.be_nil()

    -- Verify configuration was applied
    expect(html_report).to.match('theme="dark"')
    expect(json_report).to.match("  ") -- Indentation implies pretty=true
    expect(csv_report).to.match("path,total_lines,covered_lines,coverage_percent")
  end)

  --- Demonstrates how to create, register, and use a custom report formatter
  -- by extending the base `Formatter` class.
  it("demonstrates formatter registry and validation", function()
    -- Import the formatter base class
    local Formatter = require("lib.reporting.formatters.base")

    -- Create a custom formatter extending the base class
    ---@class MySimpleFormatter : Formatter
    local MyFormatter = Formatter.extend("simple", "txt")

    --- Implements the format method for the custom formatter.
    -- @param self MySimpleFormatter The formatter instance.
    -- @param data table Normalized coverage data.
    -- @param options? table Formatting options (unused in this example).
    -- @return string|nil formatted_data The formatted report string, or `nil` on error.
    -- @return table|nil error Error object if formatting or validation failed.
    function MyFormatter:format(data, options)
      options = options or {}

      -- Validate input data using base class method
      local is_valid, issues = self:validate(data) -- Uses base class validation
      if not is_valid then
        return nil,
          error_handler.validation_error("Invalid coverage data for custom formatter", {
            issues = issues,
          })
      end

      -- Create a simple text summary
      local result = "Coverage Summary:\n"
      result = result .. "Files: " .. data.summary.total_files .. "\n"
      result = result .. "Coverage: " .. string.format("%.1f%%", data.summary.coverage_percent) .. "\n"
      return result
    end

    --- Registration function for the custom formatter.
    -- @param formatters table The central formatter registry table.
    -- @return boolean success Always returns `true`.
    function MyFormatter.register(formatters)
      local formatter = MyFormatter.new()
      formatters.coverage = formatters.coverage or {}
      -- Register the format method under the 'simple' key for coverage reports
      formatters.coverage.simple = function(data, options)
        return formatter:format(data, options)
      end
      return true
    end

    -- Register the custom formatter
    local success = reporting.register_formatter(MyFormatter)
    expect(success).to.be_truthy()

    -- Get available formatters to confirm registration
    local available = reporting.get_available_formatters()
    expect(available.coverage).to.contain("simple")

    -- Use mock coverage data and the formatter
    local data = mock_processed_data
    local simple_report, format_err = reporting.format_coverage(mock_processed_data, "simple")
    expect(format_err).to.be_nil()

    -- Verify the output
    expect(simple_report).to.match("Coverage Summary:")
    expect(simple_report).to.match("Files:")
    expect(simple_report).to.match("Coverage:")
  end)

  --- Demonstrates using `reporting.auto_save_reports` with advanced configuration,
  -- including custom filename templates and multiple formats.
  it("demonstrates advanced report configuration and auto-saving", function()
    -- Use mock coverage data
    local data = mock_processed_data

    -- Example of advanced configuration with templates
    local config = {
      report_dir = temp_dir.path,
      formats = { "html", "json", "lcov", "cobertura", "summary" },
      timestamp_format = "%Y-%m-%d_%H-%M-%S",
      report_suffix = "-full",
      coverage_path_template = "{format}/coverage-{timestamp}{suffix}.{format}",
      validate = true,
      validate_output = true,
      validation_report = true,
      validation_report_path = fs.join_paths(temp_dir.path, "validation-report.json"),
    }

    -- Auto-save all reports (pass nil for results, data for coverage, nil for quality)
    local results = reporting.auto_save_reports(nil, data, nil, config)

    -- Verify results
    expect(results.html.success).to.be_truthy("HTML auto-save failed")
    expect(results.json.success).to.be_truthy()
    expect(results.lcov.success).to.be_truthy()
    expect(results.cobertura.success).to.be_truthy()
  end)
end)
