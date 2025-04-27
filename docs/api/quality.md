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
quality.LEVEL_BASIC         -- 1
quality.LEVEL_STRUCTURED    -- 2
quality.LEVEL_COMPREHENSIVE -- 3
quality.LEVEL_ADVANCED      -- 4
quality.LEVEL_COMPLETE      -- 5



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
### configure(options)

Configures the quality module, merging provided options with defaults and central configuration.
Updates logger settings based on debug/verbose flags.

```lua
quality.configure({
  level = 3,
  strict = true,
  verbose = true
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| options.enabled | boolean | Enable/disable quality validation |
| options.level | number | Set the required quality level (1-5) |
| options.strict | boolean | Enable/disable strict mode |
| options.custom_rules | table | Define custom quality rules |
| options.coverage_data | table | Provide coverage data for validation |
| options.debug | boolean | Enable debug logging for the module |
| options.verbose | boolean | Enable verbose logging for the module |
**Returns:** The quality module for method chaining
**Example:**

```lua
-- Enable quality level 3 and verbose logging
quality.configure({ level = 3, verbose = true })
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
