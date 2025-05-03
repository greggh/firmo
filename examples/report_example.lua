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
--- **Important Note on Coverage:**
--- Similar to other reporting examples, this file intentionally bypasses the standard Firmo
--- test runner's coverage handling (violating Rule ySVa5TBNltJZQjpbZzXWfP / HgnQwB8GQ5BqLAH8MkKpay)
--- by directly calling `coverage.start()`, `coverage.stop()`, and `coverage.get_data()`
--- within the test file. **This is strictly for demonstration purposes** to show how the
--- reporting module consumes coverage data. In a real project, coverage should **always** be
--- managed by the test runner (`lua test.lua --coverage ...`).
---
--- @module examples.report_example
--- @see lib.reporting
--- @see lib.coverage
--- @see lib.core.central_config
--- @usage
--- Run embedded tests (coverage is handled internally for demo):
--- ```bash
--- lua test.lua examples/report_example.lua
--- ```
--- Run with runner coverage (results may differ slightly from internal demo):
--- ```bash
--- lua test.lua --coverage examples/report_example.lua
--- ```

local firmo = require("firmo")

-- Import helper modules
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Load required modules
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")
local central_config = require("lib.core.central_config")

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

      if not success and firmo.log then
        firmo.log.warn("Failed to remove test file: " .. tostring(err), {
          file_path = file_path,
        })
      end
    end
    test_files = {}
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
    temp_dir = test_helper.create_temp_test_directory()
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
  --- Generates coverage data and creates reports using all 8 built-in formatters.
  it("demonstrates all 8 supported formatters", function()
    -- NOTE: Bypassing standard runner coverage for demonstration (Rule ySVa5TBNltJZQjpbZzXWfP)
    coverage.start()

    -- Run some code to generate coverage data
    calculator.add(5, 10)
    calculator.subtract(20, 5)
    calculator.multiply(3, 4)

    -- NOTE: Bypassing standard runner coverage for demonstration (Rule ySVa5TBNltJZQjpbZzXWfP)
    coverage.stop()
    local coverage_data = coverage.get_data()

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
      -- Generate the report
      local report = reporting.format_coverage(coverage_data, format)
      expect(report).to.exist()

      -- Save to file
      local file_ext = format
      if format == "cobertura" then
        file_ext = "xml"
      end

      local report_path = fs.join_paths(temp_dir.path, "coverage-" .. format .. "." .. file_ext)
      local success, err = reporting.write_file(report_path, report)

      -- Record for cleanup
      if success then
        table.insert(report_files, report_path)
        firmo.log.info("Created " .. format .. " coverage report", {
          path = report_path,
          size = #report,
        })
      else
        firmo.log.warn("Failed to write " .. format .. " report", {
          error = tostring(err.message),
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

    -- Test coverage with configured formatters
    -- NOTE: Bypassing standard runner coverage for demonstration (Rule ySVa5TBNltJZQjpbZzXWfP)
    coverage.start()
    calculator.divide(10, 2)
    calculator.multiply(4, 4)
    coverage.stop()

    -- Get coverage data
    local data = coverage.get_data()

    -- Generate configured reports
    local html_report = reporting.format_coverage(data, "html")
    local json_report = reporting.format_coverage(data, "json")
    local csv_report = reporting.format_coverage(data, "csv")

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

    -- Generate coverage data and use the formatter
    -- NOTE: Bypassing standard runner coverage for demonstration (Rule ySVa5TBNltJZQjpbZzXWfP)
    coverage.start()
    calculator.add(1, 1)
    coverage.stop()

    local data = coverage.get_data()
    local simple_report = reporting.format_coverage(data, "simple")

    -- Verify the output
    expect(simple_report).to.match("Coverage Summary:")
    expect(simple_report).to.match("Files:")
    expect(simple_report).to.match("Coverage:")
  end)

  --- Demonstrates using `reporting.auto_save_reports` with advanced configuration,
  -- including custom filename templates and multiple formats.
  it("demonstrates advanced report configuration and auto-saving", function()
    -- NOTE: Bypassing standard runner coverage for demonstration (Rule ySVa5TBNltJZQjpbZzXWfP)
    coverage.start()

    -- Add some test coverage
    calculator.add(5, 5)
    calculator.subtract(10, 3)
    calculator.multiply(2, 6)
    calculator.divide(10, 2)

    -- NOTE: Bypassing standard runner coverage for demonstration (Rule ySVa5TBNltJZQjpbZzXWfP)
    coverage.stop()

    -- Get the coverage data
    local data = coverage.get_data()

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

    -- Auto-save all reports
    local results = reporting.auto_save_reports(data, nil, nil, config)

    -- Verify results
    expect(results.html.success).to.be_truthy()
    expect(results.json.success).to.be_truthy()
    expect(results.lcov.success).to.be_truthy()
    expect(results.cobertura.success).to.be_truthy()
  end)
end)
