# HTML Formatter API Reference


The HTML formatter generates rich, interactive coverage reports with syntax highlighting, line-by-line execution information, and visual tracking of coverage statistics.

## Overview


The HTML formatter creates browser-viewable reports with these key features:


- Interactive file navigation with collapsible tree view
- Syntax highlighting for Lua source code
- Line-by-line coverage visualization with execution counts
- Three-state coverage model (covered, executed, not covered)
- Theme support (light/dark)
- Detailed statistics and summaries
- Filter and sort capabilities


## Class Reference


### Inheritance



```text
Formatter (Base)
  └── HTMLFormatter
```



### Class Definition



```lua
---@class HTMLFormatter : Formatter
---@field _VERSION string Version information
local HTMLFormatter = Formatter.extend("html", "html")
```



## Core Methods


### format(data, options)


Formats coverage data into HTML.


```lua
---@param data table Normalized coverage data
---@param options table|nil Formatting options
---@return string html HTML report content
---@return table|nil error Error object if formatting failed
function HTMLFormatter:format(data, options)
```



### generate(data, output_path, options)


Generate and save a complete HTML report.


```lua
---@param data table Coverage data
---@param output_path string Path to save the report
---@param options table|nil Formatting options
---@return boolean success Whether the operation succeeded
---@return string|table result Path to saved file or error object
function HTMLFormatter:generate(data, output_path, options)
```



## Configuration Options


The HTML formatter supports these configuration options:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `theme` | string | `"dark"` | Color theme (`"dark"` or `"light"`) |
| `show_line_numbers` | boolean | `true` | Display line numbers in source code |
| `syntax_highlighting` | boolean | `true` | Enable syntax highlighting for code |
| `simplified_large_files` | boolean | `true` | Use simplified view for files >1000 lines |
| `max_lines_display` | number | `200` | Max lines to display per file (0 for unlimited) |
| `show_execution_counts` | boolean | `true` | Show execution counts for lines |
| `show_uncovered_files` | boolean | `true` | Include files with 0% coverage |
| `sort_files_by` | string | `"coverage"` | How to sort files (`"coverage"`, `"name"`, or `"path"`) |
| `title` | string | `"Coverage Report"` | Report title |
| `include_timestamp` | boolean | `true` | Include generation timestamp |
| `custom_css` | string | `nil` | Path to custom CSS file |
| `custom_js` | string | `nil` | Path to custom JavaScript file |
| `inline_assets` | boolean | `true` | Embed CSS and JS in HTML file |
| `include_source` | boolean | `true` | Include source code content |
| `file_filter_pattern` | string | `nil` | Pattern to filter files (Lua pattern) |
| `min_coverage_percent` | number | `0` | Only show files with coverage >= this percent |

### Configuration Example



```lua
local reporting = require("lib.reporting")
reporting.configure_formatter("html", {
  theme = "light",
  show_line_numbers = true,
  syntax_highlighting = true,
  title = "My Project Coverage",
  sort_files_by = "path",
  file_filter_pattern = "^src/"
})
```



## Syntax Highlighting


The HTML formatter includes an integrated syntax highlighter for Lua code that supports:


- Keywords, literals, and operators
- Strings and comments
- Function and variable names
- Block indicators
- Proper handling of long strings and comments
- Number literal highlighting


### Highlighting Configuration



```lua
reporting.configure_formatter("html", {
  syntax_highlighting = true,         -- Enable/disable highlighting
  highlight_strings = true,           -- Highlight string literals
  highlight_comments = true,          -- Highlight comments
  highlight_keywords = true,          -- Highlight Lua keywords
  highlight_numbers = true,           -- Highlight numeric literals
  highlight_functions = true,         -- Highlight function names
  prefer_performance = false          -- Favor performance over accuracy
})
```



## Interactive Features


The HTML formatter includes several interactive features accessible through the browser:

### File Navigation



- Collapsible file tree organized by directories
- Breadcrumb navigation showing current location
- Quick jump to files with search functionality
- Sorting by name, path, or coverage percentage


### Coverage Visualization



- Color-coded lines showing covered, executed, and uncovered code
- Hover tooltips showing execution counts
- Click to expand/collapse file sections
- Toggle between full and summary views


### Theming



- Support for light and dark themes
- Automatic system preference detection via `prefers-color-scheme`
- Theme toggle button in the UI
- Persistent theme choice via localStorage


## Usage Example



```lua
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")
-- Configure the HTML formatter
reporting.configure_formatter("html", {
  theme = "dark",
  show_line_numbers = true,
  title = "Project Coverage Report"
})
-- Run tests with coverage
coverage.start()
-- Run tests here...
coverage.stop()
-- Generate HTML report
local data = coverage.get_data()
local html_content = reporting.format_coverage(data, "html")
-- Save the report
reporting.write_file("coverage-report.html", html_content)
-- Or in one step:
reporting.save_coverage_report("coverage-report.html", data, "html")
```



## Error Handling


The HTML formatter implements robust error handling for common issues:


1. **Invalid Data Structure**: Reports detailed validation errors in the data 
2. **File Access Issues**: Reports errors when files can't be read or written
3. **Resource Limitations**: Gracefully handles large files with simplified rendering
4. **Missing Source Files**: Reports warnings but continues to generate report
5. **Template Rendering Issues**: Provides detailed error context for debugging


### Error Response Example



```lua
local success, result_or_error = reporting.save_coverage_report("report.html", invalid_data, "html")
if not success then
  print("Error type: " .. result_or_error.category)
  print("Error message: " .. result_or_error.message)
  if result_or_error.context then
    print("Error context: " .. require("cjson").encode(result_or_error.context))
  end
end
```



## Validation Rules


The HTML formatter validates input data according to these rules:


1. **Data Structure**: Must be a table with `files` and `summary` fields
2. **File Entries**: Each file must have `path`, `lines`, and `summary` fields
3. **Line Information**: Each line must have `line_number`, `executed`, and `covered` fields
4. **Summary Information**: Must include coverage statistics fields
5. **Coverage Integrity**: Line counts must match between summary and details


### Validation Example



```lua
local HTMLFormatter = require("lib.reporting.formatters.html")
local formatter = HTMLFormatter.new()
-- Validate data before formatting
local is_valid, validation_issues = formatter:validate(coverage_data)
if not is_valid then
  for _, issue in ipairs(validation_issues) do
    print(string.format("Validation issue: %s at %s", issue.message, issue.path or "unknown"))
  end
end
```



## Integration Notes


### CI/CD Integration


To use HTML reports in CI/CD environments:


1. Generate reports with `inline_assets = true` to ensure all resources are bundled
2. Use the `title` option to include build-specific information
3. Consider using the light theme for better printing/screenshots
4. Set `file_filter_pattern` to focus on relevant code paths


### Browser Compatibility


The HTML formatter is tested and compatible with:


- Chrome/Edge (Chromium-based browsers) 88+
- Firefox 85+
- Safari 14+

For older browsers:


- Set `simplified_rendering = true`
- Disable `syntax_highlighting` for better performance


## See Also



- [HTML Formatter Guide](../../guides/configuration-details/html_formatter.md)
- [Reporting API](../reporting.md)
- [Coverage API](../coverage.md)
