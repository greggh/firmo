# Reporting Module Guide


This guide provides practical information about the firmo reporting module, which handles formatting and saving reports for coverage, quality, and test results data.

## Introduction


The reporting module centralizes all reporting functionality in the firmo framework, providing:


- A unified interface for generating different types of reports
- Support for multiple output formats (HTML, JSON, XML, CSV, TAP, etc.)
- Class-based formatter system with inheritance and extensibility
- File I/O operations with robust error handling
- Automatic directory creation and management
- Integration with the central configuration system
- Data normalization and validation


## Architecture Overview


The reporting module uses an object-oriented architecture with class inheritance:


- **Base Formatter**: All formatters extend from a common base `Formatter` class
- **Formatter Registry**: Formatters register themselves via a `register` method
- **Normalized Data**: Input data is automatically normalized for consistent processing
- **Central Configuration**: Formatters read configuration from the central config system
- **Inheritance**: Custom formatters can extend built-in ones to add functionality


## Basic Usage


### Generating Coverage Reports


The most common use case is generating coverage reports from test execution:


```lua
local firmo = require('firmo')
local reporting = require('lib.reporting')
-- Run tests with coverage
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')
-- Get coverage data
local coverage_data = firmo.get_coverage_data()
-- Format coverage data as HTML
local html_report = reporting.format_coverage(coverage_data, "html")
-- Save the report to a file
reporting.write_file("./reports/coverage-report.html", html_report)
```


You can also use the more direct formatter API for greater control:


```lua
local firmo = require('firmo')
local html_formatter = require('lib.reporting.formatters.html')
-- Run tests with coverage
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')
-- Get coverage data
local coverage_data = firmo.get_coverage_data()
-- Create formatter instance with options
local formatter = html_formatter.new({
  theme = "dark",
  show_line_numbers = true
})
-- Format and generate report in one step
local success, result = formatter:generate(
  coverage_data,
  "./reports/coverage-report.html"
)
if success then
  print("Report generated successfully at: " .. result)
else
  print("Failed to generate report: " .. result.message)
end
```


From the command line:


```bash

# Run tests with coverage and generate HTML report


lua firmo.lua --coverage --format=html tests/
```



### Multi-Format Reporting


You can generate multiple report formats at once:


```lua
local firmo = require('firmo')
local reporting = require('lib.reporting')
-- Run tests with coverage
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')
-- Get coverage data
local coverage_data = firmo.get_coverage_data()
-- Generate different report formats
local html_report = reporting.format_coverage(coverage_data, "html")
local json_report = reporting.format_coverage(coverage_data, "json")
local lcov_report = reporting.format_coverage(coverage_data, "lcov")
-- Save reports to files
reporting.write_file("./reports/coverage.html", html_report)
reporting.write_file("./reports/coverage.json", json_report)
reporting.write_file("./reports/coverage.lcov", lcov_report)
```



### Using Auto-Save Functionality


For convenience, the reporting module offers auto-save functionality:


```lua
local firmo = require('firmo')
local reporting = require('lib.reporting')
-- Run tests with coverage
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')
-- Auto-save reports in multiple formats
reporting.auto_save_reports(
  firmo.get_coverage_data(),  -- coverage data
  nil,                        -- quality data (none in this example)
  nil,                        -- test results data (none in this example)
  "./reports"                 -- output directory
)
```


This will create:


- `./reports/coverage-report.html`
- `./reports/coverage-report.json`
- `./reports/coverage-report.lcov`
- `./reports/coverage-report.cobertura.xml`


## Advanced Usage


### Configuring the Reporting Module


You can configure the reporting module directly:


```lua
local reporting = require('lib.reporting')
-- Configure the reporting module
reporting.configure({
  debug = true,               -- Enable debug logging
  verbose = true,             -- Enable verbose output
  report_dir = "./reports",   -- Set default report directory
  report_suffix = "-v1.0"     -- Add a suffix to all report filenames
})
-- Configure specific formatters
reporting.configure_formatter("html", {
  theme = "light",            -- Use light theme for HTML reports
  show_line_numbers = true,   -- Show line numbers in HTML reports
  highlight_syntax = true     -- Enable syntax highlighting
})
-- Configure multiple formatters at once
reporting.configure_formatters({
  html = { theme = "light" },
  json = { pretty = true }
})
```



### Custom Report Paths with Templates


You can use path templates for more control over report file names:


```lua
local reporting = require('lib.reporting')
-- Advanced usage with path templates
reporting.auto_save_reports(
  coverage_data,
  quality_data,
  results_data,
  {
    report_dir = "./reports",
    report_suffix = "-v1.0",
    coverage_path_template = "coverage-{date}.{format}",
    quality_path_template = "quality/report-{date}.{format}",
    results_path_template = "test-results-{datetime}.{format}",
    timestamp_format = "%Y-%m-%d",
    verbose = true
  }
)
```


Path templates support the following placeholders:


- `{format}`: Output format (html, json, lcov, etc.)
- `{type}`: Report type (coverage, quality, results)
- `{date}`: Current date using timestamp format
- `{datetime}`: Current date and time (%Y-%m-%d_%H-%M-%S)
- `{suffix}`: The report suffix if specified


### Using Formatter Classes Directly


Each formatter can be used directly for more control:


```lua
local summary_formatter = require('lib.reporting.formatters.summary')
local json_formatter = require('lib.reporting.formatters.json')
-- Create formatter instances
local summary = summary_formatter.new({
  colorize = true,
  detailed = true
})
local json = json_formatter.new({
  pretty_print = true,
  indent_size = 4
})
-- Generate reports
local success1, path1 = summary:generate(
  coverage_data, 
  "./reports/coverage-summary.txt"
)
local success2, path2 = json:generate(
  coverage_data, 
  "./reports/coverage-data.json"
)
```


Path templates support the following placeholders:


- `{format}`: Output format (html, json, lcov, etc.)
- `{type}`: Report type (coverage, quality, results)
- `{date}`: Current date using timestamp format
- `{datetime}`: Current date and time (%Y-%m-%d_%H-%M-%S)
- `{suffix}`: The report suffix if specified


### Test Results Reporting


You can generate reports for test results:


```lua
local firmo = require('firmo')
local reporting = require('lib.reporting')
-- Run tests
firmo.run_discovered('./tests')
-- Get test results data
local results_data = firmo.get_test_results()
-- Generate different report formats
local junit_report = reporting.format_results(results_data, "junit")
local tap_report = reporting.format_results(results_data, "tap")
local csv_report = reporting.format_results(results_data, "csv")
-- Save reports to files
reporting.write_file("./reports/test-results.xml", junit_report)
reporting.write_file("./reports/test-results.tap", tap_report)
reporting.write_file("./reports/test-results.csv", csv_report)
```



### Combined Coverage and Quality Reporting


You can generate reports for both coverage and quality:


```lua
local firmo = require('firmo')
local reporting = require('lib.reporting')
-- Enable both coverage and quality
firmo.coverage_options.enabled = true
firmo.quality_options.enabled = true
firmo.quality_options.level = 3
-- Run tests
firmo.run_discovered('./tests')
-- Get both data sets
local coverage_data = firmo.get_coverage_data()
local quality_data = firmo.get_quality_data()
-- Save all reports to the configured directory
reporting.auto_save_reports(coverage_data, quality_data, nil, "./reports")
```



### Validating Reports


The reporting module includes validation functionality:


```lua
local firmo = require('firmo')
local reporting = require('lib.reporting')
-- Get coverage data
local coverage_data = firmo.get_coverage_data()
-- Validate coverage data
local is_valid, issues = reporting.validate_coverage_data(coverage_data)
if not is_valid then
  print("Coverage data validation failed:")
  for _, issue in ipairs(issues) do
    print("- " .. issue.message)
  end
end
-- Format data with validation
local html_report = reporting.format_coverage(coverage_data, "html")
local format_valid, error_message = reporting.validate_report_format(html_report, "html")
-- Save with validation options
reporting.save_coverage_report(
  "./reports/coverage.html", 
  coverage_data, 
  "html", 
  {
    validate = true,             -- Validate data before saving
    strict_validation = false,   -- Continue even if validation fails
    validate_format = true       -- Validate the formatted output
  }
)
```



## Report Formats


### Coverage Report Formats


The reporting module supports several coverage report formats:

#### HTML


The HTML format provides an interactive, visual representation of coverage data:


```lua
local html_report = reporting.format_coverage(coverage_data, "html")
reporting.write_file("./reports/coverage.html", html_report)
```


Features:


- Color-coded line coverage (green for covered, orange for executed, red for not covered)
- File-by-file breakdown with coverage percentages
- Syntax highlighting for source code
- Collapsible file view
- Dark and light theme options


#### JSON


The JSON format provides machine-readable coverage data:


```lua
local json_report = reporting.format_coverage(coverage_data, "json")
reporting.write_file("./reports/coverage.json", json_report)
```


This format is useful for:


- Integration with other tools
- Storing coverage data for historical comparison
- Custom processing and visualization


#### LCOV


The LCOV format is compatible with many coverage tools:


```lua
local lcov_report = reporting.format_coverage(coverage_data, "lcov")
reporting.write_file("./reports/coverage.lcov", lcov_report)
```


This format is useful for:


- Integration with CI/CD systems
- Coverage trend analysis
- Third-party coverage tools


#### Cobertura XML


The Cobertura XML format is compatible with Jenkins and other CI systems:


```lua
local cobertura_report = reporting.format_coverage(coverage_data, "cobertura")
reporting.write_file("./reports/coverage.xml", cobertura_report)
```



### Test Results Formats


The reporting module supports several test results formats:

#### JUnit XML


JUnit XML is a standard format for test results:


```lua
local junit_report = reporting.format_results(results_data, "junit")
reporting.write_file("./reports/test-results.xml", junit_report)
```


Features:


- Compatible with most CI/CD systems
- Includes test case details, durations, and failures
- Structured format for automated processing


#### TAP (Test Anything Protocol)


TAP is a simple text-based format for test results:


```lua
local tap_report = reporting.format_results(results_data, "tap")
reporting.write_file("./reports/test-results.tap", tap_report)
```


Features:


- Human-readable format
- Compatible with TAP consumers
- Simple to parse and generate


#### CSV (Comma-Separated Values)


CSV provides tabular test results data:


```lua
local csv_report = reporting.format_results(results_data, "csv")
reporting.write_file("./reports/test-results.csv", csv_report)
```


Features:


- Easy import into spreadsheets
- Simple data analysis and filtering
- Widely supported format


## Command Line Integration


The reporting functionality can be controlled through command-line options:


```bash

# Run tests with coverage and generate HTML report


lua firmo.lua --coverage --format=html tests/

# Set custom output directory


lua firmo.lua --coverage --output-dir=./reports tests/

# Generate multiple report formats


lua firmo.lua --coverage --format=html,json,lcov tests/

# Add a suffix to report filenames


lua firmo.lua --coverage --report-suffix="-$(date +%Y%m%d)" tests/

# Set custom path templates


lua firmo.lua --coverage --coverage-path="coverage-{date}.{format}" tests/

# Enable verbose output


lua firmo.lua --coverage --verbose-reports tests/
```



## Custom Formatters


### Creating Custom Formatters with Class Inheritance


The new reporting system uses a class-based approach for formatters. You can create custom formatters by extending the base formatter class:


```lua
local Formatter = require('lib.reporting.formatters.base')
local error_handler = require('lib.tools.error_handler')
-- Create a custom Markdown formatter by extending the base formatter
local MarkdownFormatter = Formatter.extend("markdown", "md")
-- Set version
MarkdownFormatter._VERSION = "1.0.0"
-- Implement the format method (required)
function MarkdownFormatter:format(coverage_data, options)
  -- Normalize data for consistent structure
  local data = self:normalize_coverage_data(coverage_data)

  -- Build markdown content
  local md = "# Coverage Report\n\n"
  md = md .. "## Summary\n\n"
  md = md .. "- Files: " .. data.summary.total_files .. "\n"
  md = md .. "- Line Coverage: " .. string.format("%.2f", data.summary.coverage_percent) .. "%\n"

  md = md .. "\n## Files\n\n"

  -- Sort files by path for consistent output
  local file_paths = {}
  for path, _ in pairs(data.files) do
    table.insert(file_paths, path)
  end
  table.sort(file_paths)

  -- Add each file's coverage info
  for _, path in ipairs(file_paths) do
    local file_data = data.files[path]
    md = md .. "- **" .. path .. "**: " 
       .. string.format("%.2f", file_data.summary.coverage_percent) .. "%\n"
  end

  return md
end
-- Register the formatter
function MarkdownFormatter.register(formatters)
  -- Validate formatters parameter
  if not formatters or type(formatters) ~= "table" then
    return false, error_handler.validation_error(
      "Invalid formatters registry", 
      {formatter = "markdown"}
    )
  end

  -- Create an instance of the formatter
  local formatter = MarkdownFormatter.new()

  -- Register with the formatters registry
  formatters.coverage = formatters.coverage or {}
  formatters.coverage.markdown = function(data, options)
    return formatter:format(data, options)
  end

  return true
end
return MarkdownFormatter
```



### Registering and Using Custom Formatters


Register and use your custom formatter:


```lua
local reporting = require('lib.reporting')
local markdown_formatter = require('path.to.markdown_formatter')
-- Register the custom formatter
reporting.register_formatter(markdown_formatter)
-- Use the custom formatter
local markdown_report = reporting.format_coverage(coverage_data, "markdown")
reporting.write_file("./reports/coverage.md", markdown_report)
```



### Simple Custom Formatters


For simple cases, you can still use the function-based approach:


```lua
local reporting = require('lib.reporting')
-- Register a simple custom formatter function
reporting.register_coverage_formatter("simple", function(coverage_data)
  -- Simple text formatter that just shows overall percentage
  return "Overall coverage: " .. 
    string.format("%.2f%%", coverage_data.summary.coverage_percent)
end)
-- Use the custom formatter
local simple_report = reporting.format_coverage(coverage_data, "simple")
print(simple_report)
```



## Best Practices


### Error Handling


The reporting module provides comprehensive error handling using the error_handler system:


```lua
-- Using the reporting module functions
local success, err = reporting.save_coverage_report(
  "./reports/coverage.html", 
  coverage_data, 
  "html"
)
if not success then
  print("Failed to save report: " .. err.message)
  if err.context then
    print("Error details: " .. require('lib.tools.error_handler').format_error(err))
  end
  -- Handle the error appropriately
end
-- Using formatter objects directly
local html_formatter = require('lib.reporting.formatters.html')
local formatter = html_formatter.new()
-- Validate data
local is_valid, validation_err = formatter:validate(coverage_data)
if not is_valid then
  print("Validation failed: " .. validation_err.message)
  return
end
-- Format the data
local formatted_data, format_err = formatter:format(coverage_data)
if not formatted_data then
  print("Formatting failed: " .. format_err.message)
  return
end
-- Write the formatted data
local write_success, write_err = formatter:write(
  formatted_data, 
  "./reports/coverage.html"
)
if not write_success then
  print("Write failed: " .. write_err.message)
  return
end
-- Or use generate() for all steps in one call with comprehensive error handling
local gen_success, result_or_err = formatter:generate(
  coverage_data, 
  "./reports/coverage.html"
)
if not gen_success then
  print("Report generation failed: " .. result_or_err.message)
end
```



### Data Normalization and Validation


Formatters automatically normalize data to ensure consistent structure:


```lua
local formatter = require('lib.reporting.formatters.html').new()
-- Normalize data (this happens automatically in format/generate)
local normalized_data = formatter:normalize_coverage_data(coverage_data)
-- Check if file paths use consistent format
for file_path, _ in pairs(normalized_data.files) do
  if not file_path:match("^/") then
    print("Warning: Relative path found: " .. file_path)
  end
end
-- Validate data explicitly
local is_valid, validation_error = formatter:validate(coverage_data)
if not is_valid then
  print("Validation error: " .. validation_error.message)
  if validation_error.context then
    for k, v in pairs(validation_error.context) do
      print("  " .. k .. ": " .. tostring(v))
    end
  end
end
-- Run comprehensive validation via the reporting module
local validation_result = reporting.validate_report(coverage_data)
if not validation_result.validation.is_valid then
  print("Report validation failed:")
  for _, issue in ipairs(validation_result.validation.issues) do
    print("- " .. issue.message)
  end
  -- Handle validation issues
end
```


For CI integration, use the LCOV or Cobertura formats:


```bash

# Run in CI environment


lua firmo.lua --coverage --format=lcov tests/

# Upload coverage to a service like Codecov


codecov -f ./coverage-reports/coverage-report.lcov
```



### Report Validation


Validate reports before publishing them:


```lua
-- Run comprehensive validation
local validation_result = reporting.validate_report(coverage_data)
if not validation_result.validation.is_valid then
  print("Report validation failed:")
  for _, issue in ipairs(validation_result.validation.issues) do
    print("- " .. issue.message)
  end
  -- Handle validation issues
end
```


   end
   ```


1. **Missing coverage data**:

   ```lua
   -- Check if coverage data is valid
   if not coverage_data or not coverage_data.files or not next(coverage_data.files) then
     print("No coverage data available. Did you enable coverage tracking?")
   end
   ```


2. **Report formatting errors**:

   ```lua
   -- Use error handling for report formatting
   local ok, formatted_report = pcall(function()
     return reporting.format_coverage(coverage_data, "html") 
   end)

   if not ok then
     print("Error formatting report: " .. tostring(formatted_report))
   end
   ```

### Debugging


The reporting module includes a debug mode:


```lua
-- Enable debug mode
reporting.configure({ debug = true, verbose = true })
-- Get configuration debug info
local config_info = reporting.debug_config()
print("Using central config:", config_info.using_central_config)
print("Debug mode:", config_info.local_config.debug)
```



## See Also



- [Reporting Module API](../api/reporting.md) - Complete API reference with all functions and parameters
- [Coverage Report Formatters](./configuration-details/formatters.md) - Comprehensive documentation of all formatter options
- [File Watcher Configuration](./configuration-details/watcher.md) - Detailed configuration options for file watching
- [Parallel Execution Configuration](./configuration-details/parallel.md) - Configure parallel test execution
- [Error Handler Configuration](./configuration-details/error_handler.md) - Configure error handling behavior
- [Quality Validation Configuration](./configuration-details/quality.md) - Configure test quality standards
- [Reporting Examples](../../examples/reporting_examples.md) - More comprehensive examples for various use cases
