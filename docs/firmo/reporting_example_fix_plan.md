# Reporting Example Fix Plan

## Problem Overview

The `examples/reporting_filesystem_integration.lua` example has been facing multiple issues due to inconsistent coverage data structures that fail validation checks when generating reports in different formats (HTML, JSON, LCOV, Cobertura). The main issues include:

1. Coverage data not properly structured for each specific format's schema requirements
2. Version fields as numbers instead of strings (required to be strings)
3. Missing required fields like `covered_lines` and `total_lines` in data structures
4. File paths in coverage data not matching actual created temporary test files
5. Inconsistency in data types between coverage formats
6. Improper configuration through `central_config.get()` vs. `central_config.get_config()`

## Schema Requirements Analysis

Based on the schema validation requirements in `lib/reporting/schema.lua`, each format has specific data structure requirements:

### Base Coverage Schema Requirements

All coverage formats require these core elements:
- `version` (string) - Coverage data format version
- `files` (table) - Mapping of file paths to file-specific coverage data 
- `summary` (table) - Overall coverage statistics
  - `total_files` (number) - Count of files analyzed
  - `covered_files` (number) - Count of files with at least one covered line
  - `total_lines` (number) - Total line count across all files
  - `covered_lines` (number) - Count of lines covered across all files

### HTML Coverage Format Requirements

- Each file entry must include:
  - `lines` (array) - With objects containing:
    - `number` (number) - Line number
    - `executable` (boolean) - Whether the line is executable
    - `execution_count` (number) - How many times the line was executed

### JSON Coverage Format Requirements

- Each file entry must include:
  - `lines` (array) - With objects containing:
    - `line_number` (number) - Line number 
    - `count` (number) - Execution count
    - `covered` (boolean) - Whether the line was covered
  - `metrics` (object) - With coverage statistics including:
    - `statements`, `functions`, `lines`, `branches` objects, each containing:
      - `total` (number)
      - `covered` (number)
      - `pct` (number) - Percentage coverage

### LCOV Coverage Format Requirements

- Each file entry must include:
  - `lines` (array) - With objects containing:
    - `line` (number) - Line number
    - `count` (number) - Execution count

### Cobertura Coverage Format Requirements

- Specific `packages` structure required, containing:
  - Classes organized by package
  - Each class needs:
    - `lines_valid`, `lines_covered`, etc.
    - Each line must have `number`, `hits`, and `covered` properties

## Implementation Plan

### 1. Update File Structure

The example should be restructured following this outline:

```
1. Load required modules
2. Define utility functions (like deepcopy)
3. Create describe block for test
   a. Create setup/teardown (before/after) for temp directory and files
   b. Define test case for generating multiple formats
      i. Create properly structured format-specific coverage data
      ii. Configure reporting options
      iii. Generate and validate reports for each format
```

### 2. Create Valid Data Structures

For each format, create dedicated coverage data objects with the specific fields required:

- `base_coverage_data` - With common fields
- `html_coverage_data` - Format-specific for HTML
- `json_coverage_data` - Format-specific for JSON
- `lcov_coverage_data` - Format-specific for LCOV
- `cobertura_coverage_data` - Format-specific for Cobertura, including packages structure

### 3. Ensure Consistent File Path Referencing

- Create actual files in a temporary test directory
- Use consistent path referencing in all coverage data
- Register files with temp_file for proper cleanup

### 4. Proper Configuration Management

- Use `central_config.get()` consistently
- Follow proper configuration patterns from central_config docs

### 5. Format-Specific Report Generation

- Use `reporting.save_coverage_report()` for each format
- Use proper error handling with `test_helper.with_error_capture()`

### 6. Validation and Error Checks

- Verify reports were created successfully
- Verify file existence
- Check file content basics where appropriate

## Code Samples for Critical Sections

### 1. Creating Format-Specific Coverage Data

```lua
-- Base coverage data with common fields
local base_coverage_data = {
  -- Common metadata
  version = "1.0", -- Must be a string
  timestamp = os.date("%Y-%m-%dT%H:%M:%SZ"),
  generated_by = "reporting_filesystem_integration.lua",
  project_name = "firmo_example",
  source_root = temp_dir.path,
  
  -- Required root level summary
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 16,
    covered_lines = 13,
    executable_lines = 16,
    total_functions = 3,
    covered_functions = 2,
    line_coverage_percent = 81.25,
    function_coverage_percent = 66.7,
    branch_coverage_percent = 0.0,
    metrics = {
      complexity = 1.0,
      statement = { total = 16, covered = 13, percentage = 81.25 },
      branch = { total = 0, covered = 0, percentage = 0.0 },
      ["function"] = { total = 3, covered = 2, percentage = 66.7 },
      line = { total = 16, covered = 13, percentage = 81.25 }
    }
  },
  
  -- Files with different format requirements per format
  files = {}
}

-- HTML format requires executable and execution_count fields
local html_coverage_data = table.deepcopy(base_coverage_data)
html_coverage_data.format = "html"
html_coverage_data.files = {
  [example_files.example_file] = {
    name = fs.basename(example_files.example_file),
    path = example_files.example_file,
    total_lines = 10,
    executable_lines = 8,
    covered_lines = 6,
    line_coverage_percent = 75.0,
    source = "...",
    lines = {
      -- HTML format specifically requires 'executable' and 'execution_count'
      { number = 1, executable = true, execution_count = 10, content = "..." },
      -- More lines...
    },
    functions = {
      { name = "add", line = 1, execution_count = 10 },
      { name = "subtract", line = 4, execution_count = 0 }
    }
  },
  -- Another file entry...
}

-- JSON format structure
local json_coverage_data = table.deepcopy(base_coverage_data)
json_coverage_data.format = "json"
json_coverage_data.files = {
  [example_files.example_file] = {
    -- File properties...
    lines = {
      -- JSON format uses 'line_number', 'count', and 'covered'
      { line_number = 1, count = 10, covered = true, source = "..." },
      -- More lines...
    },
    metrics = {
      statements = { total = 10, covered = 6, pct = 60.0 },
      functions = { total = 2, covered = 1, pct = 50.0 },
      lines = { total = 10, covered = 6, pct = 60.0 },
      branches = { total = 0, covered = 0, pct = 0.0 }
    }
  },
  -- Another file entry...
}

-- Similar structures for LCOV and Cobertura formats
```

### 2. Save Reports with Proper Error Handling

```lua
-- Save HTML coverage report
local html_options = table.deepcopy(report_options)
html_options.format_options = {
  html = {
    theme = "dark",
    show_line_numbers = true,
    collapsible_sections = true,
    highlight_syntax = true,
    include_legend = true,
  }
}
local html_success, html_result = test_helper.with_error_capture(function()
  return reporting.save_coverage_report(html_coverage_data, "html", html_options)
end)

-- Verify success
if html_success and html_result then
  expect(html_result.success).to.be_truthy("HTML report should be generated successfully")
  expect(fs.directory_exists(html_result.path)).to.be_truthy("HTML report directory should exist")
else
  logger.error("HTML report failed:", html_result and html_result.error or "unknown error")
  expect(html_success).to.be_truthy("HTML report generation should succeed")
end

-- Repeat similar pattern for other formats
```

## Implementation Guidelines

1. Create format-specific data structures that match the exact requirements for each format
2. Ensure all version fields are strings, not numbers
3. Create and reference actual test files within a temporary directory
4. Use consistent error handling through `test_helper.with_error_capture()`
5. Access configuration correctly through `central_config.get()`
6. Use proper filesystem operations for creating, writing, and validating files
7. Validate results to ensure reports were generated as expected

By implementing these changes, the `reporting_filesystem_integration.lua` example will function correctly, pass all validations, and demonstrate proper usage of the reporting module for generating coverage reports in multiple formats.

