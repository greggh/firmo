# Reporting Module API

The reporting module in firmo provides a centralized system for generating, formatting, and saving reports from test data.

## Overview

The reporting module handles the entire reporting pipeline from raw data to formatted output files, including:

- Unified interface for generating coverage, quality, and test results reports
- Support for multiple output formats (HTML, JSON, XML, CSV, TAP, etc.)
- Class-based formatter system with inheritance and extensibility
- File saving with appropriate error handling and validation
- Integration with central configuration system
- Automatic directory creation and path management
- Data normalization and validation

## Architecture

The reporting module uses a class-based arc#### `reporting.get_available_formatters(type)`

Get list of available formatters for the specified type or all types.

Parameters:
- `type` (string, optional): Type of formatters to retrieve ("coverage", "quality", or "results")

Returns:
- `available_formatters` (table): Table with lists of formatters by type {coverage={}, quality={}, results={}} or a list of available formatters for the specified type
ves with the registry for discovery
- **Data Normalization**: Input data is normalized before formatting for consistent results
- **Error Handling**: Robust error handling at all stages of the reporting pipeline
- **Central Configuration**: Integration with the central configuration system for configuration

## Module Functions

### Module Configuration

#### `reporting.configure(options)`

Configure the reporting module with custom options.

Parameters:
- `options` (table): Configuration options for the reporting module

Returns:
- The reporting module for method chaining

#### `reporting.configure_formatter(formatter_name, formatter_config)`

Configure a specific formatter.

Parameters:
- `formatter_name` (string): Name of the formatter to configure
- `formatter_config` (table): Configuration options for the formatter

Returns:
- The reporting module for method chaining

#### `reporting.configure_formatters(formatters_config)`

Configure multiple formatters at once.

Parameters:
- `formatters_config` (table): Table of formatter configurations {formatter_name = config, ...}

Returns:
- The reporting module for method chaining

#### `reporting.get_formatter_config(formatter_name)`

Get configuration for a specific formatter.

Parameters:
- `formatter_name` (string): Name of the formatter to get configuration for

Returns:
- `formatter_config` (table): Configuration for the formatter or nil if not found

### Report Formatting Functions

#### `reporting.format_coverage(coverage_data, format)`

Format coverage data into the specified output format.

Parameters:
- `coverage_data` (table): Coverage data structure from the coverage module
- `format` (string): Output format (html, json, lcov, cobertura, etc.)

Returns:
- The formatted report content (string or table depending on format)

#### `reporting.format_quality(quality_data, format)`

Format quality data into the specified output format.

Parameters:
- `quality_data` (table): Quality data structure from the quality module
- `format` (string): Output format (html, json, summary)

Returns:
- The formatted report content (string or table depending on format)

#### `reporting.format_results(results_data, format)`

Format test results data into the specified output format.

Parameters:
- `results_data` (table): Test results data structure
- `format` (string): Output format (junit, tap, csv)

Returns:
- The formatted report content (string or table depending on format)

### File I/O Functions

#### `reporting.write_file(file_path, content)`

Write content to a file, creating directories as needed.

Parameters:
- `file_path` (string): Path to the file to write
- `content` (string or table): Content to write to the file

Returns:
- `success` (boolean): True if the file was written successfully
- `error` (table, optional): Error object if the operation failed

#### `reporting.save_coverage_report(file_path, coverage_data, format, options)`

Format and save a coverage report.

Parameters:
- `file_path` (string): Path to save the report
- `coverage_data` (table): Coverage data structure
- `format` (string): Output format (html, json, lcov, cobertura, etc.)
- `options` (table, optional): Options for saving the report:
  - `validate` (boolean): Whether to validate the data before saving (default: true)
  - `strict_validation` (boolean): Whether to abort if validation fails (default: false)
  - `validate_format` (boolean): Whether to validate the formatted output (default: true)

Returns:
- `success` (boolean): True if the report was saved successfully
- `error` (table, optional): Error object if the operation failed

#### `reporting.save_quality_report(file_path, quality_data, format)`

Format and save a quality report.

Parameters:
- `file_path` (string): Path to save the report
- `quality_data` (table): Quality data structure
- `format` (string): Output format (html, json, summary)

Returns:
- `success` (boolean): True if the report was saved successfully
- `error` (table, optional): Error object if the operation failed

#### `reporting.save_results_report(file_path, results_data, format)`

Format and save a test results report.

Parameters:
- `file_path` (string): Path to save the report
- `results_data` (table): Test results data structure
- `format` (string): Output format (junit, tap, csv)

Returns:
- `success` (boolean): True if the report was saved successfully
- `error` (table, optional): Error object if the operation failed

#### `reporting.auto_save_reports(coverage_data, quality_data, results_data, options)`

Automatically save multiple report formats to a directory with configurable paths.

Parameters:
- `coverage_data` (table, optional): Coverage data structure
- `quality_data` (table, optional): Quality data structure
- `results_data` (table, optional): Test results data structure
- `options` (string or table):
  - If string: Base directory path (backward compatibility)
  - If table: Configuration options with the following properties:
    - `report_dir` (string): Base directory for reports (default: "./coverage-reports")
    - `report_suffix` (string, optional): Suffix to add to all report filenames
    - `coverage_path_template` (string, optional): Path template for coverage reports
    - `quality_path_template` (string, optional): Path template for quality reports
    - `results_path_template` (string, optional): Path template for test results reports
    - `timestamp_format` (string, optional): Format string for timestamps (default: "%Y-%m-%d")
    - `verbose` (boolean, optional): Enable verbose debugging output
    - `validate` (boolean, optional): Whether to validate reports before saving (default: true)
    - `strict_validation` (boolean, optional): If true, don't save invalid reports (default: false)
    - `validation_report` (boolean, optional): If true, generate validation report (default: false)
    - `validation_report_path` (string, optional): Path for validation report

Path templates support the following placeholders:
- `{format}`: Output format (html, json, lcov, etc.)
- `{type}`: Report type (coverage, quality, results)
- `{date}`: Current date using timestamp format
- `{datetime}`: Current date and time (%Y-%m-%d_%H-%M-%S)
- `{suffix}`: The report suffix if specified

Returns:
- `results` (table): Table of results for each saved report with success/error information

### Formatter Management Functions

#### `reporting.register_formatter(formatter)`

Register a custom formatter class or module.

Parameters:
- `formatter` (table): A formatter class or module that implements the formatter interface

Returns:
- `success` (boolean): True if formatter was registered successfully
- `error` (table, optional): Error object if registration failed

#### `reporting.create_formatter(type, name, options)`

Create a new formatter instance of the specified type.

Parameters:
- `type` (string): Type of formatter ("coverage", "quality", or "results")
- `name` (string): Name of the formatter to create
- `options` (table, optional): Options for the formatter

Returns:
- `formatter` (table): A formatter instance or nil if creation failed
- `error` (table, optional): Error object if creation failed

#### `reporting.load_formatters(formatter_module)`

Load formatters from a module (table with format functions).

Parameters:
- `formatter_module` (table): Module containing formatters {coverage={}, quality={}, results={}}

Returns:
- `registered` (number): Number of formatters registered
- `error` (table, optional): Error object if some formatters failed to register

#### `reporting.get_available_formatters()`

Get list of available formatters for each type.

Returns:
- `available_formatters` (table): Table with lists of formatters by type {coverage={}, quality={}, results={}}

### Validation Functions

#### `reporting.validate_coverage_data(coverage_data)`

Validate coverage data before saving.

Parameters:
- `coverage_data` (table): Coverage data structure from the coverage module

Returns:
- `is_valid` (boolean): True if the data is valid
- `issues` (table): List of validation issues if any

#### `reporting.validate_report_format(formatted_data, format)`

Validate formatted report output.

Parameters:
- `formatted_data` (string or table): Formatted report content
- `format` (string): Output format name

Returns:
- `is_valid` (boolean): True if the format is valid
- `error_message` (string): Error message if validation failed

#### `reporting.validate_report(coverage_data, formatted_output, format)`

Perform comprehensive validation of a coverage report.

Parameters:
- `coverage_data` (table): Coverage data structure
- `formatted_output` (string or table, optional): Formatted report content
- `format` (string, optional): Output format name

Returns:
- `result` (table): Validation results with analysis information

### Utility Functions

#### `reporting.reset()`

Reset the module to default configuration (local config only).

Returns:
- The reporting module for method chaining

#### `reporting.full_reset()`

Fully reset both local and central configuration.

Returns:
- The reporting module for method chaining

#### `reporting.debug_config()`

Show current configuration for debugging.

Returns:
- `debug_info` (table): Current configuration information

## Built-in Formatters

### Coverage Report Formatters

- **HTML**: Interactive HTML report with syntax highlighting and file details
- **JSON**: Machine-readable format for CI integration
- **LCOV**: Industry-standard format compatible with coverage tools
- **Cobertura**: XML format compatible with Jenkins and other CI systems
- **Summary**: Text-based overview of coverage results with colorization support
- **CSV**: Tabular format for data a### Quality Data Structure

```lua
{
  type = "quality",  -- Type identifier
  level = 3,
  level_name = "Comprehensive",
  tests = {
    ["path/to/test.lua"] = {
      path = "path/to/test.lua### Test Results Data Structure

```lua
{
  type = "results",  -- Type identifier 
  name = "TestSuite",
  timestamp = "2025-03-26T14:30:00",
  tests = 100,
  failures = 5,
  errors = 2,
  skipped = 3,
  time = 1.234,
  test_cases = {
    {
      name = "should add two numbers",
      classname = "calculator_test",
      time = 0.001,
      status = "pass",
      assertio## Formatter Class Architecture

### Base Formatter Class

The `Formatter` class is the foundation for all formatters:

```lua
-- Create a new formatter class
local MyFormatter = Formatter.extend("myformat", "my")

-- Implement format method
function MyFormatter:format(data, options)
  -- Format the data
  return formatted_string
end

-- Register the formatter
function MyFormatter.register(formatters)
  local formatter = MyFormatter.new()
  formatters.coverage.myformat = function(data, options)
    return formatter:format(data, options)
  end
  return true
end
```

### Formatter Methods

All formatters inherit these methods:

- `validate(data)`: Validates input data
- `format(data, options)`: Formats data into output format
- `write(formatted_data, output_path, options)`: Writes formatted data to a file
- `generate(data, output_path, options)`: End-to-end report generation
- `normalize_coverage_data(data)`: Normalizes coverage data structure

## Data Structures

### Normalized Coverage Data Structure

```lua
{
  files = {
    ["path/to/file.lua"] = {
      path = "path/to/file.lua",
      summary = {
        total_lines = 100,
        covered_lines = 65,
        executed_lines = 10,
        not_covered_lines = 25,
        coverage_percent = 65.0,
        execution_percent = 75.0
      },
      lines = {
        [1] = { 
          line_number = 1,
          executed = true, 
          covered = true, 
          execution_count = 5, 
          content = "function add(a, b)",
          assertions = { -- Optional assertions that covered this line
            { id = "test1", count = 2 },
            { id = "test2", count = 3 }
          }
        },
        -- more lines...
      },
      functions = {
        ["add"] = {
          name = "add",
          start_line = 1,
          end_line = 3,
          executed = true,
          covered = true,
          execution_count = 5
        },
        -- more functions...
      }
    },
    -- more files...
  },
  summary = {
    total_files = 10,
    total_lines = 1000,
    covered_lines = 650,
    executed_lines = 100,
    not_covered_lines = 250,
    coverage_percent = 65.0,
    execution_percent = 75.0
  }
}
```

### Quality Data Structure

```lua
{
  level = 3,
  level_name = "Comprehensive",
  tests = {
    ["path/to/test.lua"] = {
      path = "path/to/test.lua",
      total_tests = 15,
      quality_compliant_tests = 12,
      total_assertions = 45,
      assertions_per_test = 3.0,
      coverage_percent = 80.0,
      issues = {
        { line = 10, test = "should validate input", issue = "No error case assertions", severity = "warning" },
        -- more issues...
      }
    },
    -- more test files...
  },
  summary = {
    tests_analyzed = 100,
    tests_passing_quality = 85,
    quality_percent = 85.0,
    assertions_total = 350,
    assertions_per_test_avg = 3.5,
    issues = {
      { category = "missing_error_case", count = 15, severity = "warning" },
      { category = "single_assertion", count = 10, severity = "warning" },
      -- more issue categories...
    }
  }
}
```

### Test Results Data Structure

```lua
{
  name = "TestSuite",
  timestamp = "2025-03-26T14:30:00",
  tests = 100,
  failures = 5,
  errors = 2,
  skipped = 3,
  time = 1.234,
  test_cases = {
    {
      name = "should add two numbers",
      classname = "calculator_test",
      time = 0.001,
      status = "pass"
    },
    {
      name = "should handle division by zero",
      classname = "calculator_test",
      time = 0.002,
      status = "fail",
      failure = {
        message = "Expected error message to match 'division by zero'",
        type = "Assertion",
        details = "calculator_test.lua:45: Expected error message to match 'division by zero', got 'cannot divide by zero'"
      }
    },
    -- more test cases...
  }
}
```

## See Also

- [Reporting Module Guide](../guides/reporting.md) - Practical guide with usage examples and best practices
- [Reporting Examples](../../examples/reporting_examples.md) - Complete code examples for common reporting tasks