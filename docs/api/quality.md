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

