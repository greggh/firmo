--- Example demonstrating advanced features of the HTML coverage report formatter.
---
--- This example showcases:
--- - Generating HTML reports using `reporting.auto_save_reports`.
--- - Configuring HTML formatter options via `central_config` (theme, syntax highlighting, line numbers, etc.).
--- - Demonstration of dark/light themes.
--- - Verification of syntax highlighting for keywords, strings, comments, numbers.
--- - Illustration of interactive features like collapsible sections and execution counts.
---
--- **Important Note:**
--- This example uses **mock processed coverage data** passed directly to the reporting
--- functions (`reporting.auto_save_reports`). It does **not** perform actual test
--- execution or coverage collection. Its purpose is solely to demonstrate the
--- various configuration *options* and *output features* of the HTML formatter.
--- In a real project, coverage data is collected via `lua firmo.lua --coverage ...`
--- and reports are generated based on the configuration in `.firmo-config.lua`
--- or command-line flags (`--format=html`).
---
--- @module examples.html_formatter_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.reporting.formatters.html
--- @see lib.reporting
--- @see lib.core.central_config
--- @usage
--- Run embedded tests (uses mock data):
--- ```bash
--- lua firmo.lua examples/html_formatter_example.lua
--- ```
--- Run with runner coverage (results may differ slightly from internal demo):
--- ```bash
--- lua firmo.lua --coverage examples/html_formatter_example.lua
--- ```

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
local mock, spy, stub, with_mocks = firmo.mock, firmo.spy, firmo.stub, firmo.with_mocks
local before, after = firmo.before, firmo.after -- Add this line
-- Import required modules
local reporting = require("lib.reporting")
-- local coverage = require("lib.coverage") -- Removed: Using mock data
local fs = require("lib.tools.filesystem") -- Needed to read report content for verification
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config") -- Added missing require
local test_helper = require("lib.tools.test_helper") -- Added missing require

-- Setup logger
local logger = logging.get_logger("HTMLFormatterExample")

-- Mock processed coverage data structure for demonstration purposes.
-- This simulates the data structure the reporting module expects as input.
-- Based conceptually on the syntax_examples module.
local mock_processed_data = {
  files = {
    ["examples/html_formatter_example.lua"] = { -- Use this example file itself
      filename = "examples/html_formatter_example.lua", -- Adjust path if needed
      lines = { -- line_num (string) = { hits=count }
        ["72"] = { hits = 2 }, -- options = options or {}
        ["82"] = { hits = 2 }, -- type check (hit twice)
        ["92"] = { hits = 2 }, -- pairs loop (entered twice)
        ["93"] = { hits = 4 }, -- inner type check (hit 4 times for str/num/else)
        ["95"] = { hits = 2 }, -- string processing
        ["96"] = { hits = 1 }, -- number processing
        ["98"] = { hits = 1 }, -- value > 0 (true once)
        ["99"] = { hits = 1 }, -- value * 2
        ["101"] = { hits = 0 }, -- else 0 (not hit)
        ["105"] = { hits = 1 }, -- default case
        ["124"] = { hits = 2 }, -- process_text type check
        ["129"] = { hits = 2 }, -- gsub
        ["136"] = { hits = 2 }, -- more gsub
        ["138"] = { hits = 2 }, -- return processed
      },
      functions = { -- func_name = { name, start_line, execution_count }
        ["advanced_function"] = { name = "advanced_function", start_line = 70, execution_count = 2 },
        ["process_text"] = { name = "process_text", start_line = 122, execution_count = 2 },
      },
      branches = { -- line_num (string) = { { hits=count }, { hits=count } }
        ["82"] = { { hits = 2 }, { hits = 0 } }, -- type(input) ~= "table" (true 0, false 2)
        ["93"] = { { hits = 2 }, { hits = 1 }, { hits = 1 } }, -- Type checks: string, number, else
        ["98"] = { { hits = 1 }, { hits = 0 } }, -- value > 0 (true 1, false 0)
      },
      -- Example summary values for this file
      executable_lines = 14, -- Approx count of lines above
      covered_lines = 13,
      line_rate = 13 / 14,
      line_coverage_percent = (13 / 14) * 100,
      total_lines = 408, -- File total
      total_functions = 2,
      covered_functions = 2,
      function_coverage_percent = 100.0,
      total_branches = 6, -- 2 + 3 + 1 = 6 outcomes
      covered_branches = 4, -- Hit: not table(f), is table(t), is str(t), is num(t), >0(t), default(t) | Missed: >0(f), is table(f)
      branch_coverage_percent = (4 / 6) * 100,
    },
  },
  summary = {
    -- Overall summary values based on the single file
    executable_lines = 14,
    covered_lines = 13,
    line_coverage_percent = (13 / 14) * 100,
    total_lines = 408,
    total_functions = 2,
    covered_functions = 2,
    function_coverage_percent = 100.0,
    total_branches = 6,
    covered_branches = 4,
    branch_coverage_percent = (4 / 6) * 100,
    total_files = 1,
    covered_files = 1,
    overall_percent = (13 / 14) * 100,
  },
}

--- Example code module with features designed to demonstrate
-- HTML formatter capabilities like syntax highlighting and branch coverage.
--- @class SyntaxExamples
--- @field advanced_function fun(input: table, options?: table): table|nil, table|nil Processes a table with nested conditions.
--- @field process_text fun(text: string): string Processes text with string operations.
--- @within examples.html_formatter_example
local syntax_examples = {
  --- Example function with comments, strings, and nested conditional blocks.
  -- @param input table The input table to process.
  -- @param options? table Optional settings (e.g., `debug: boolean`).
  -- @return table|nil result The processed table (`{ [key]=processed_value }`), or `nil` on error.
  -- @return table|nil err A validation error object if `input` is not a table.
  advanced_function = function(input, options)
    -- Default options
    options = options or {}

    -- Multi-line string example
    local multiline_string = [[
      This is a multi-line string
      that will be highlighted differently
      in the HTML formatter output.
    ]]

    -- Conditional blocks for branch coverage
    if type(input) ~= "table" then
      return nil,
        error_handler.validation_error("Input must be a table", {
          provided = type(input),
          expected = "table",
        })
    end

    -- Loop with nested conditions
    local result = {}
    for key, value in pairs(input) do
      if type(value) == "string" then
        -- String processing
        result[key] = value:upper()
      elseif type(value) == "number" then
        -- Numeric processing with nested condition
        if value > 0 then
          result[key] = value * 2
        else
          result[key] = 0 -- This line may not be covered
        end
      else
        -- Default case
        result[key] = value
      end
    end

    -- This function contains lines that may not be executed,
    -- perfect for demonstrating coverage visualization
    if options.debug then
      logger.debug("Debug output", { multiline_string = multiline_string })
      logger.debug("Result", { result = result })
    end

    return result
  end,

  --- Example function with string operations (gsub, escapes) to demonstrate syntax highlighting.
  -- @param text string The input text.
  -- @return string processed The processed text (escaped, trimmed, spaces normalized). Returns empty string if input is invalid.
  process_text = function(text)
    -- Check input
    if not text or type(text) ~= "string" then
      return ""
    end

    -- String operations with escapes
    local escaped = text:gsub('["\\\n]', {
      ['"'] = '\\"',
      ["\\"] = "\\\\",
      ["\n"] = "\\n",
    })

    -- More string processing
    local processed = escaped:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    return processed
  end,
}

--- Basic tests for the `syntax_examples` module to generate coverage data.
--- @within examples.html_formatter_example
describe("Syntax example tests", function()
  --- Tests the successful execution path of `advanced_function`.
  it("should process advanced functions correctly", function()
    -- Test the function to generate coverage
    local input = {
      name = "test",
      value = 10,
      items = { "one", "two" },
    }

    local result = syntax_examples.advanced_function(input)
    expect(result).to.exist()
    expect(result.name).to.equal("TEST")
    expect(result.value).to.equal(20)
    expect(result.items).to.deep_equal({ "one", "two" })
  end)

  --- Tests the error handling path of `advanced_function` for invalid input.
  it("should handle non-table input gracefully", { expect_error = true }, function()
    local result, err = syntax_examples.advanced_function("not a table")
    expect(result).to.be_nil()
    expect(err).to.exist()
    expect(err.message).to.match("must be a table")
  end)

  --- Tests the `process_text` function.
  it("should process text correctly", function()
    local input = '  Hello "world" \n with   spaces  '
    local result = syntax_examples.process_text(input)
    expect(result).to.equal('Hello \\"world\\" \\n with spaces')
  end)
end)

--- Tests demonstrating specific HTML formatter features and configurations.
--- @within examples.html_formatter_example
describe("HTML formatter features", function()
  local temp_dir -- Stores the temporary directory helper object

  --- Setup hook: Create a temporary directory for reports.
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  --- Teardown hook: Release reference. Directory cleaned automatically.
  after(function()
    temp_dir = nil
  end)

  --- Tests generating reports with both dark and light themes.
  it("demonstrates dark/light theme support", function()
    -- Use the mock processed data
    local data = mock_processed_data

    -- Generate dark theme report using auto_save_reports
    logger.info("Generating dark theme report...")
    local dark_config = {
      report_dir = temp_dir.path,
      formats = { "html" },
      coverage_path_template = "{format}/dark-theme-report.{format}",
      html = {
        theme = "dark",
        show_line_numbers = true,
        syntax_highlighting = true,
        title = "Dark Theme Example",
      },
    }
    -- Coverage data is the 1st argument for auto_save_reports
    local dark_results = reporting.auto_save_reports(data, nil, nil, dark_config)
    expect(dark_results.html.success).to.be_truthy("Dark theme report failed to save")
    if dark_results.html.success then
      logger.info(
        "Created dark theme HTML report",
        { path = dark_results.html.path, size = fs.get_file_size(dark_results.html.path) }
      )
      local dark_content, dark_read_err = fs.read_file(dark_results.html.path)
      expect(dark_read_err).to_not.exist()
      expect(dark_content).to.match('theme="dark"')
    end

    -- Generate light theme report using auto_save_reports
    logger.info("Generating light theme report...")
    local light_config = {
      report_dir = temp_dir.path,
      formats = { "html" },
      coverage_path_template = "{format}/light-theme-report.{format}",
      html = {
        theme = "light",
        show_line_numbers = true,
        syntax_highlighting = true,
        title = "Light Theme Example",
      },
    }
    -- Coverage data is the 1st argument for auto_save_reports
    local light_results = reporting.auto_save_reports(data, nil, nil, light_config)
    expect(light_results.html.success).to.be_truthy("Light theme report failed to save")
    if light_results.html.success then
      logger.info(
        "Created light theme HTML report",
        { path = light_results.html.path, size = fs.get_file_size(light_results.html.path) }
      )
      local light_content, light_read_err = fs.read_file(light_results.html.path)
      expect(light_read_err).to_not.exist()
      expect(light_content).to.match('theme="light"')
    end
  end)

  --- Tests syntax highlighting features for various Lua constructs and line detail display.
  it("demonstrates syntax highlighting and line details", function()
    -- Use the mock processed data
    local data = mock_processed_data

    -- Configure and generate using auto_save_reports
    local config = {
      report_dir = temp_dir.path,
      formats = { "html" },
      coverage_path_template = "{format}/syntax-highlighted-report.{format}",
      html = {
        show_line_numbers = true,
        syntax_highlighting = true,
        highlight_keywords = true,
        highlight_strings = true,
        highlight_comments = true,
        highlight_functions = true,
        highlight_numbers = true,
        show_execution_counts = true,
        include_source = true,
      },
    }

    logger.info("Generating syntax-highlighted report...")
    -- Coverage data is the 1st argument for auto_save_reports
    local results = reporting.auto_save_reports(data, nil, nil, config)

    expect(results.html.success).to.be_truthy("Syntax report save failed")
    if results.html.success then
      logger.info(
        "Created syntax-highlighted HTML report",
        { path = results.html.path, size = fs.get_file_size(results.html.path) }
      )

      -- Verify syntax highlighting is applied by checking the file content
      local report_content, read_err = fs.read_file(results.html.path)
      expect(read_err).to_not.exist()
      expect(report_content).to.match('<span class="keyword">local</span>')
      expect(report_content).to.match('<span class="string">')
      expect(report_content).to.match('<span class="comment">') -- More general check
      expect(report_content).to.match('<span class="number">')
    else
      logger.error("Failed to save syntax report", { error = results.html.error })
    end
  end)

  --- Tests interactive elements like collapsible sections, execution counts, and sorting.
  it("demonstrates interactive features", function()
    -- Use the mock processed data
    local data = mock_processed_data

    -- Configure and generate using auto_save_reports
    local config = {
      report_dir = temp_dir.path,
      formats = { "html" },
      coverage_path_template = "{format}/interactive-report.{format}",
      html = {
        show_line_numbers = true,
        syntax_highlighting = true,
        collapsible_sections = true, -- Enable collapsible file sections
        include_timestamp = true, -- Add timestamp to report
        show_execution_counts = true, -- Show how many times each line executed
        show_uncovered_files = true, -- Include files with 0% coverage
        sort_files_by = "coverage", -- Sort files by coverage percentage
        include_function_coverage = true, -- Include function-level coverage info
      },
    }

    logger.info("Generating interactive report...")
    -- Coverage data is the 1st argument for auto_save_reports
    local results = reporting.auto_save_reports(data, nil, nil, config)

    expect(results.html.success).to.be_truthy("Interactive report save failed")
    if results.html.success then
      logger.info(
        "Created interactive HTML report",
        { path = results.html.path, size = fs.get_file_size(results.html.path) }
      )

      -- Verify interactive features are present
      local report_content, read_err = fs.read_file(results.html.path)
      expect(read_err).to_not.exist()
      expect(report_content).to.match('class="collapsible"')
      expect(report_content).to.match("data-count") -- Check for data-count attribute
      expect(report_content).to.match("report-timestamp") -- Check for report-timestamp class or id
    else
      logger.error("Failed to save interactive report", { error = results.html.error })
    end
  end)
end)

--- Informational block describing how to use the generated HTML report.
--- @within examples.html_formatter_example
describe("HTML report instructions", function()
  --- Logs instructions and explanations of the HTML report's features to the console.
  it("describes how to use the HTML reports", function()
    logger.info("HTML Report Instructions: To view the generated HTML reports, open them in a browser.")

    logger.info("Interactive Features include:")
    logger.info("- Click on directory names to expand/collapse file lists")
    logger.info("- Click on file names to show/hide source code")
    logger.info("- Hover over lines to see execution counts")
    logger.info("- Toggle between dark and light themes with the theme button")
    logger.info("- Use the search box to filter files by name")
    logger.info("- Click column headers to sort files differently")

    logger.info("Understanding Coverage Colors:")
    logger.info("- Green: Lines executed and covered by assertions")
    logger.info("- Yellow: Lines executed but not verified by assertions")
    logger.info("- Red: Lines that were never executed")
    logger.info("- Gray: Non-executable lines (comments, whitespace, etc.)")
  end)
end)

-- Run this example with:
-- lua firmo.lua --coverage examples/html_formatter_example.lua
