# Quality Module API

The quality module provides test quality validation with support for multiple quality levels,
reporting integration, and centralized configuration.

## Key Features
- 5-level quality validation system
- Integration with coverage and reporting modules
- Centralized configuration support
- Multiple report format output
- Test quality metrics and analysis

## Installation
The quality module is part of the firmo test framework and is available by default:

```lua
local firmo = require("firmo")
local quality = require("lib.quality")
```

## Quality Level System

The quality module supports 5 quality levels, each with increasing requirements:

| Level | Name | Description |
|-------|------|-------------|
| 1 | Basic | Basic tests with at least one assertion per test and proper structure |
| 2 | Standard | Standard tests with multiple assertions, proper naming, and error handling |
| 3 | Comprehensive | Comprehensive tests with edge cases, type checking, and isolated setup |
| 4 | Advanced | Advanced tests with boundary conditions, mock verification, and context organization |
| 5 | Complete | Complete tests with 100% branch coverage, security validation, and performance testing |

Level constants are provided for ease of use:
```lua
quality.LEVEL_BASIC -- 1
quality.LEVEL_STRUCTURED -- 2
quality.LEVEL_COMPREHENSIVE -- 3
quality.LEVEL_ADVANCED -- 4
quality.LEVEL_COMPLETE -- 5
```

## Configuration API

### init(options)
Initialize quality module with specified options.

```lua
quality.init({
  enabled = true,                -- Enable quality validation
  level = 3,                     -- Required quality level (1-5)
  strict = false,                -- Strict mode (fail on first issue)
  coverage_data = coverage_data, -- Reference to coverage module data
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| options.enabled | boolean | Whether quality validation is enabled |
| options.level | number | Required quality level (1-5) |
| options.strict | boolean | Strict mode (fail on first issue) |
| options.coverage_data | table | Reference to coverage module data |

**Returns:** The quality module for method chaining

**Example:**
```lua
quality.init({
  enabled = true,
  level = quality.LEVEL_COMPREHENSIVE, -- Level 3
})
```

### reset()
Reset quality data while preserving configuration.

```lua
quality.reset()
```

**Returns:** The quality module for method chaining

### full_reset()
Full reset (clears all data and resets configuration to defaults).

```lua
quality.full_reset()
```

**Returns:** The quality module for method chaining

### debug_config()
Print debug information about the current quality module configuration.

```lua
quality.debug_config()
```

**Returns:** The quality module for method chaining

## Quality Validation API

### check_file(file_path, level)
Check if a test file meets quality requirements for a specific level.

```lua
local meets, issues = quality.check_file("tests/my_test.lua", 3)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| file_path | string | Path to the test file to check |
| level | number | Quality level to check against (defaults to configured level) |

**Returns:**
- `meets` (boolean): Whether the file meets the quality requirements
- `issues` (table): Any quality issues found in the file

**Example:**
```lua
local meets, issues = quality.check_file("tests/my_test.lua", 3)
if not meets then
  print("File doesn't meet quality level 3 requirements:")
  for _, issue in ipairs(issues) do
    print("- " .. issue.test .. ": " .. issue.issue)
  end
end
```

### validate_test_quality(test_name, options)
Validate a test against quality standards with detailed feedback.

```lua
local meets, issues = quality.validate_test_quality("should properly validate user input", {level = 3})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| test_name | string | Name of the test to validate |
| options.level | number | Quality level to check against (defaults to configured level) |
| options.strict | boolean | Strict mode (fail on first issue) |

**Returns:**
- `meets` (boolean): Whether the test meets the quality requirements
- `issues` (table): Any quality issues found in the test

**Example:**
```lua
-- After running a test
quality.start_test("should properly validate user input")
quality.track_assertion("equality")
quality.track_assertion("type_checking")
quality.end_test()

-- Validate the test meets level 3 requirements
local meets, issues = quality.validate_test_quality("should properly validate user input", {level = 3})
if not meets then
  print("Test doesn't meet level 3 requirements:")
  for _, issue in ipairs(issues) do
    print("- " .. issue)
  end
end
```

### track_assertion(type_name, test_name)
Track assertion usage in a specific test.

```lua
quality.track_assertion("equality", "should properly validate user input")
```

| Parameter | Type | Description |
|-----------|------|-------------|
| type_name | string | Type of assertion being tracked |
| test_name | string | Name of the test (optional, uses current test if not provided) |

**Returns:** The quality module for method chaining

**Example:**
```lua
quality.start_test("should properly validate user input")
quality.track_assertion("equality")
quality.track_assertion("type_checking")
quality.end_test()
```

### start_test(test_name)
Start test analysis for a specific test and register timing.

```lua
quality.start_test("should properly validate user input")
```

| Parameter | Type | Description |
|-----------|------|-------------|
| test_name | string | Name of the test to analyze |

**Returns:** The quality module for method chaining

### end_test()
End test analysis and record final results including duration.

```lua
quality.end_test()
```

**Returns:** The quality module for method chaining

### analyze_file(file_path)
Analyze test file statically for quality metrics.

```lua
local analysis = quality.analyze_file("tests/my_test.lua")
```

| Parameter | Type | Description |
|-----------|------|-------------|
| file_path | string | Path to the test file to analyze |

**Returns:** Analysis results table with metrics

**Example:**
```lua
local analysis = quality.analyze_file("tests/my_test.lua")
print("Test file has " .. analysis.assertion_count .. " assertions")
print("Quality level: " .. analysis.quality_level)
```

## Reporting Integration

### report(format)
Generate a quality report in the specified format.

```lua
local report = quality.report("html")
```

| Parameter | Type | Description |
|-----------|------|-------------|
| format | string | Report format ("summary", "json", "html") |

**Returns:** Formatted report as string or table depending on format

**Example:**
```lua
-- Generate a summary report
local summary = quality.report("summary")
print(summary)

-- Generate a JSON report
local json_data = quality.report("json")

-- Generate an HTML report
local html = quality.report("html")
fs.write_file("quality-report.html", html)
```

### save_report(file_path, format)
Save a quality report to a file in the specified format.

```lua
local success, err = quality.save_report("quality-report.html", "html")
```

| Parameter | Type | Description |
|-----------|------|-------------|
| file_path | string | The path where to save the quality report |
| format | string | Report format ("summary", "json", "html") |

**Returns:**
- `success` (boolean): Whether the report was successfully saved
- `error` (string, optional): Error message if saving failed

**Example:**
```lua
-- Save a quality report in HTML format
local success, err = quality.save_report("quality-report.html", "html")
if not success then
  print("Failed to save report: " .. err)
end

-- Save a quality report using defaults from central configuration
local success = quality.save_report("quality-report.json")
```

### get_report_data()
Get structured data for quality report generation.

```lua
local data = quality.get_report_data()
```

**Returns:** Quality report data structure

**Example:**
```lua
local data = quality.get_report_data()
print("Overall quality level: " .. data.level)
print("Tests analyzed: " .. data.summary.tests_analyzed)
print("Quality percentage: " .. data.summary.quality_percent .. "%")
```

### summary_report()
Generate a simplified summary report with key metrics.

```lua
local summary = quality.summary_report()
```

**Returns:** Summary report as table

**Example:**
```lua
local summary = quality.summary_report()
print("Quality level: " .. summary.level_name)
print("Tests passing: " .. summary.tests_passing_quality .. "/" .. summary.tests_analyzed)
print("Quality score: " .. summary.quality_pct .. "%")
```

## Helper Functions

### get_level_name(level)
Get the descriptive name for a quality level.

```lua
local name = quality.get_level_name(3)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| level | number | Quality level number (1-5) |

**Returns:** Level name as string

**Example:**
```lua
local name = quality.get_level_name(3)
print(name) -- "comprehensive"
```

### meets_level(level)
Check if quality metrics meet a specific level requirement.

```lua
local meets = quality.meets_level(3)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| level | number | Quality level to check against (defaults to configured level) |

**Returns:** Whether the quality meets the specified level requirement

**Example:**
```lua
if quality.meets_level(3) then
  print("Quality meets level 3 standards!")
else
  print("Quality does not meet level 3 standards")
end
```

### get_level_requirements(level)
Get requirements for a specific quality level.

```lua
local requirements = quality.get_level_requirements(3)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| level | number | Quality level to get requirements for |

**Returns:** Requirements table for the specified level

**Example:**
```lua
local requirements = quality.get_level_requirements(3)
print("Level 3 requires " .. requirements.min_assertions_per_test .. " assertions per test")
```

## Integration with Other Modules

### Central Configuration Integration

The quality module integrates with the centralized configuration system:

```lua
-- In .firmo-config.lua
return {
  quality = {
    enabled = true,
    level = 3,
    strict = false
  },
  reporting = {
    formats = {
      quality = {
        default = "html"
      }
    }
  }
}
```

### Coverage Integration

The quality module can validate against coverage thresholds:

```lua
-- Initialize quality with coverage data
local coverage = require("lib.coverage")
quality.init({
  enabled = true,
  level = 3,
  coverage_data = coverage
})

-- Coverage threshold is checked when validating at higher quality levels
local meets, issues = quality.check_file("tests/my_test.lua", 5)
```

### Reporting Integration

The quality module uses the reporting module for output:

```lua
-- Generate a report in the format configured in central_config
local report = quality.report()

-- Save a report using the reporting module
local success = quality.save_report("quality-report.html", "html")
```

# Quality Module API
The quality module in firmo provides test quality validation with customizable levels and reporting capabilities.

## Overview
The quality module analyzes test structure, assertions, and organization to validate that tests meet specified quality criteria. It supports five quality levels (from basic to complete) and can generate reports highlighting areas for improvement.

## Basic Usage

```lua
-- Enable quality validation in a test file
local firmo = require('firmo')
firmo.quality_options.enabled = true
firmo.quality_options.level = 3 -- Comprehensive quality level
-- Run tests with quality validation
firmo.run_discovered('./tests')
-- Generate a quality report
local report = firmo.generate_quality_report('html', './quality-report.html')

```
From the command line:

```bash

# Run tests with quality validation at level 3
lua firmo.lua --quality --quality-level 3 tests/

```

## Quality Levels
The quality module defines five progressive quality levels:

1. **Basic (Level 1)**
   - At least one assertion per test
   - Proper test and describe block naming
   - No empty test blocks
1. **Standard (Level 2)**
   - Multiple assertions per test
   - Testing of basic functionality
   - Error case handling
   - Clear test organization
1. **Comprehensive (Level 3)**
   - Edge case testing
   - Type checking assertions
   - Proper mock/stub usage
   - Isolated test setup and teardown
1. **Advanced (Level 4)**
   - Boundary condition testing
   - Complete mock verification
   - Integration and unit test separation
   - Performance validation where applicable
1. **Complete (Level 5)**
   - 100% branch coverage
   - Security vulnerability testing
   - Comprehensive API contract testing
   - Full dependency isolation

## Configuration Options
The quality module can be configured through the `firmo.quality_options` table:

```lua
firmo.quality_options = {
  enabled = true,        -- Enable quality validation (default: false)
  level = 3,             -- Quality level to enforce (1-5, default: 1)
  format = "html",       -- Default format for reports (html, json, summary)
  output = "./quality",  -- Default output location for reports
  strict = false,        -- Strict mode - fail on first issue (default: false)
  custom_rules = {       -- Custom quality rules
    require_describe_block = true,
    min_assertions_per_test = 2
  }
}

```

## API Reference

### `firmo.quality_options`
Configuration table for quality options:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable quality validation |
| `level` | number | `1` | Quality level to enforce (1-5) |
| `format` | string | `"summary"` | Default format for reports (html, json, summary) |
| `output` | string | `nil` | Default output location for reports |
| `strict` | boolean | `false` | Strict mode - fail on first issue |
| `custom_rules` | table | `{}` | Custom quality rules |

### `firmo.with_quality(options, fn)`
Run a function with quality validation:

```lua
firmo.with_quality({
  level = 3,
  strict = true
}, function()
  -- Run tests here
  firmo.run_discovered('./tests')
end)

```

### `firmo.start_quality(options)`
Start quality validation with the given options:

```lua
firmo.start_quality({
  level = 4,
  strict = false
})
-- Run tests
firmo.run_discovered('./tests')
-- Stop quality validation
firmo.stop_quality()

```

### `firmo.stop_quality()`
Stop quality validation and finalize data collection.

### `firmo.get_quality_data()`
Get the collected quality data as a structured table:

```lua
local quality_data = firmo.get_quality_data()

```

### `firmo.generate_quality_report(format, output_path)`
Generate a quality report:

```lua
-- Generate an HTML report
firmo.generate_quality_report("html", "./quality-report.html")
-- Generate a JSON report
firmo.generate_quality_report("json", "./quality-report.json")
-- Generate a summary report (returns text, doesn't write to file)
local summary = firmo.generate_quality_report("summary")

```
Parameters:

- `format` (string): Output format (html, json, summary)
- `output_path` (string): Path to save the report (optional for summary format)

### `firmo.quality_meets_level(level)`
Check if tests meet the specified quality level:

```lua
if firmo.quality_meets_level(3) then
  print("Quality is good!")
else
  print("Quality is below level 3!")
end

```
Parameters:

- `level` (number): Quality level threshold (1-5)

## Custom Rules
You can define custom quality rules through the `custom_rules` option:

```lua
firmo.quality_options.custom_rules = {
  require_describe_block = true,       -- Tests must be in describe blocks
  min_assertions_per_test = 2,         -- Minimum number of assertions per test
  require_error_assertions = true,     -- Tests must include error assertions
  require_mock_verification = true,    -- Mocks must be verified
  max_test_name_length = 60,           -- Maximum test name length
  require_setup_teardown = true,       -- Tests must use setup/teardown
  naming_pattern = "^should_.*$",      -- Test name pattern requirement
  max_nesting_level = 3                -- Maximum nesting level for describes
}

```

## Examples

### Basic Quality Validation

```lua
local firmo = require('firmo')
-- Enable quality validation
firmo.quality_options.enabled = true
firmo.quality_options.level = 2 -- Standard quality level
-- Run tests
firmo.run_discovered('./tests')
-- Generate report
firmo.generate_quality_report("html", "./quality-report.html")

```

### Custom Quality Configuration

```lua
local firmo = require('firmo')
-- Start quality validation with custom configuration
firmo.start_quality({
  level = 4,
  strict = true,
  custom_rules = {
    min_assertions_per_test = 3,
    require_mock_verification = true,
    require_error_assertions = true
  }
})
-- Run specific tests
firmo.run_file("tests/api_tests.lua")
-- Stop quality validation
firmo.stop_quality()
-- Check if quality meets level
if firmo.quality_meets_level(4) then
  print("Meets quality level 4!")
else
  print("Below quality level 4!")
end
-- Generate reports in different formats
firmo.generate_quality_report("html", "./quality/report.html")
firmo.generate_quality_report("json", "./quality/report.json")

```

### Command Line Usage

```bash

# Run tests with basic quality validation
lua firmo.lua --quality tests/

# Specify quality level
lua firmo.lua --quality --quality-level 3 tests/

# Enable strict mode
lua firmo.lua --quality --quality-level 3 --quality-strict tests/

# Set custom output file
lua firmo.lua --quality --quality-format html --quality-output ./reports/quality.html tests/

# Run with both quality and coverage
lua firmo.lua --quality --quality-level 3 --coverage tests/

```

