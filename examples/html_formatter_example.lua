-- html_formatter_example.lua
-- Example demonstrating the HTML formatter's advanced features
-- Including themes, interactive elements, syntax highlighting, and coverage visualization

-- Import the firmo framework
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import required modules
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Example code with features that demonstrate HTML formatter capabilities
local syntax_examples = {
  -- Function with comments, strings, and nested blocks
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
      return nil, error_handler.validation_error("Input must be a table", {
        provided = type(input),
        expected = "table"
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
      print("Debug output:", multiline_string)
      print("Result:", result)
    end
    
    return result
  end,
  
  -- Function with string operations to show syntax highlighting
  process_text = function(text)
    -- Check input
    if not text or type(text) ~= "string" then
      return ""
    end
    
    -- String operations with escapes
    local escaped = text:gsub('["\\\n]', {
      ['"'] = '\\"',
      ['\\'] = '\\\\',
      ['\n'] = '\\n'
    })
    
    -- More string processing
    local processed = escaped:gsub("%s+", " ")
                             :gsub("^%s+", "")
                             :gsub("%s+$", "")
    
    return processed
  end
}

-- Example tests to generate coverage
describe("HTML Formatter Example", function()
  -- Resources to clean up
  local temp_dir
  local report_files = {}
  
  -- Create a temp directory before tests
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)
  
  -- Clean up after tests
  after(function()
    for _, file_path in ipairs(report_files) do
      if fs.file_exists(file_path) then
        fs.delete_file(file_path)
      end
    end
    
    -- Optionally, try to clean up temp directory
    if temp_dir and temp_dir.path and fs.dir_exists(temp_dir.path) then
      fs.delete_directory(temp_dir.path)
    end
  end)
  
  describe("Syntax example tests", function()
    it("should process a table input correctly", function()
      -- Test the function to generate coverage
      local input = {
        name = "test",
        value = 10,
        items = { "one", "two" }
      }
      
      local result = syntax_examples.advanced_function(input)
      expect(result).to.exist()
      expect(result.name).to.equal("TEST")
      expect(result.value).to.equal(20)
      expect(result.items).to.deep_equal({ "one", "two" })
    end)
    
    it("should handle non-table input gracefully", { expect_error = true }, function()
      local result, err = syntax_examples.advanced_function("not a table")
      expect(result).to.be_nil()
      expect(err).to.exist()
      expect(err.message).to.match("must be a table")
    end)
    
    it("should process text correctly", function()
      local input = '  Hello "world" \n with   spaces  '
      local result = syntax_examples.process_text(input)
      expect(result).to.equal('Hello \\"world\\" \\n with spaces')
    end)
  end)
  
  describe("HTML formatter features", function()
    it("demonstrates dark/light theme support", function()
      -- Start coverage
      coverage.start()
      
      -- Generate some coverage data
      syntax_examples.advanced_function({
        test = "value",
        number = 42
      })
      
      syntax_examples.process_text("Test string with\nnewlines")
      
      -- Stop coverage
      coverage.stop()
      
      -- Get the coverage data
      local data = coverage.get_data()
      
      -- Generate dark theme report
      reporting.configure_formatter("html", {
        theme = "dark",
        show_line_numbers = true,
        syntax_highlighting = true,
        title = "Dark Theme Example"
      })
      
      local dark_report = reporting.format_coverage(data, "html")
      local dark_report_path = fs.join_paths(temp_dir.path, "dark-theme-report.html")
      local dark_success = reporting.write_file(dark_report_path, dark_report)
      
      if dark_success then
        table.insert(report_files, dark_report_path)
        firmo.log.info("Created dark theme HTML report", {
          path = dark_report_path,
          size = #dark_report
        })
      end
      
      -- Generate light theme report
      reporting.configure_formatter("html", {
        theme = "light",
        show_line_numbers = true,
        syntax_highlighting = true,
        title = "Light Theme Example"
      })
      
      local light_report = reporting.format_coverage(data, "html")
      local light_report_path = fs.join_paths(temp_dir.path, "light-theme-report.html")
      local light_success = reporting.write_file(light_report_path, light_report)
      
      if light_success then
        table.insert(report_files, light_report_path)
        firmo.log.info("Created light theme HTML report", {
          path = light_report_path,
          size = #light_report
        })
      end
      
      -- Verify theme settings were applied
      expect(dark_report).to.match('theme="dark"')
      expect(light_report).to.match('theme="light"')
    end)
    
    it("demonstrates syntax highlighting and line details", function()
      -- Start coverage
      coverage.start()
      
      -- Generate some coverage data
      syntax_examples.advanced_function({
        str = "test string",
        num = 42,
        bool = true,
        mix = "mixed value"
      })
      
      -- Stop coverage
      coverage.stop()
      
      -- Get the coverage data
      local data = coverage.get_data()
      
      -- Configure HTML formatter with syntax highlighting options
      reporting.configure_formatter("html", {
        show_line_numbers = true,
        syntax_highlighting = true,
        highlight_keywords = true,
        highlight_strings = true,
        highlight_comments = true,
        highlight_functions = true,
        highlight_numbers = true,
        show_execution_counts = true,
        include_source = true
      })
      
      -- Generate the report
      local report = reporting.format_coverage(data, "html")
      local report_path = fs.join_paths(temp_dir.path, "syntax-highlighted-report.html")
      local success = reporting.write_file(report_path, report)
      
      if success then
        table.insert(report_files, report_path)
        firmo.log.info("Created syntax-highlighted HTML report", {
          path = report_path,
          size = #report
        })
      end
      
      -- Verify syntax highlighting is applied
      expect(report).to.match('<span class="keyword">local</span>')
      expect(report).to.match('<span class="string">')
      expect(report).to.match('<span class="comment">%-%-%s')
      expect(report).to.match('<span class="number">')
    end)
    
    it("demonstrates interactive features", function()
      -- Start coverage
      coverage.start()
      
      -- Generate some coverage data
      syntax_examples.advanced_function({
        name = "interactive",
        value = 100
      })
      
      syntax_examples.process_text("Another test")
      
      -- Stop coverage
      coverage.stop()
      
      -- Get the coverage data
      local data = coverage.get_data()
      
      -- Configure HTML formatter with interactive features
      reporting.configure_formatter("html", {
        show_line_numbers = true,
        syntax_highlighting = true,
        collapsible_sections = true,     -- Enable collapsible file sections
        include_timestamp = true,        -- Add timestamp to report
        show_execution_counts = true,    -- Show how many times each line executed
        show_uncovered_files = true,     -- Include files with 0% coverage
        sort_files_by = "coverage",      -- Sort files by coverage percentage
        include_function_coverage = true -- Include function-level coverage info
      })
      
      -- Generate the report
      local report = reporting.format_coverage(data, "html")
      local report_path = fs.join_paths(temp_dir.path, "interactive-report.html")
      local success = reporting.write_file(report_path, report)
      
      if success then
        table.insert(report_files, report_path)
        firmo.log.info("Created interactive HTML report", {
          path = report_path,
          size = #report
        })
      end
      
      -- Verify interactive features are present
      expect(report).to.match('class="collapsible"')
      expect(report).to.match('execution%-count')
      expect(report).to.match('timestamp=')
    end)
  end)
  
  describe("HTML report instructions", function()
    it("describes how to use the HTML reports", function()
      firmo.log.info("HTML Report Instructions", {
        message = "To view the generated HTML reports, open them in a browser."
      })
      
      firmo.log.info("Interactive Features", {
        features = {
          "Click on directory names to expand/collapse file lists",
          "Click on file names to show/hide source code",
          "Hover over lines to see execution counts",
          "Toggle between dark and light themes with the theme button",
          "Use the search box to filter files by name",
          "Click column headers to sort files differently"
        }
      })
      
      firmo.log.info("Understanding Coverage Colors", {
        green = "Lines executed and covered by assertions",
        yellow = "Lines executed but not verified by assertions",
        red = "Lines that were never executed",
        gray = "Non-executable lines (comments, whitespace, etc.)"
      })
    end)
  end)
end)

-- Run this example with:
-- lua test.lua --coverage examples/html_formatter_example.lua

