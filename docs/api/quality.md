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
local quality = require("lib.quality")
-- OR, if firmo main object is used to expose sub-modules:
-- local firmo = require("firmo")
-- local quality = firmo.quality -- Assuming firmo.lua would set this up
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

Initializes and configures the quality module. This is the primary method for setup and is typically called by the test runner based on CLI arguments or central configuration. It merges provided options with defaults and central configuration values.

```lua
quality.init({
  enabled = true,                -- Enable quality validation
  level = 3,                     -- Required quality level (1-5)
  strict = false,                -- Strict mode (test suite might fail if quality level isn't met)
  coverage_data = coverage_module_instance, -- Optional: instance of the coverage module or its report data
  debug = false,                 -- Enable debug logging for the quality module
  verbose = false                -- Enable verbose (trace) logging for the quality module
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| options.enabled | boolean | Whether quality validation is enabled. Defaults to `false` or value from `central_config`. |
| options.level | number | Required quality level (1-5). Defaults to `3` (Comprehensive) or value from `central_config`. |
| options.strict | boolean | If true, tests might fail if they don't meet the quality level (behavior depends on runner integration). Defaults to `false` or value from `central_config`. |
| options.coverage_data | table | Optional: Instance of the coverage module or its report data, used for coverage-related quality checks. |
| options.debug | boolean | Enable debug level logging for the quality module. |
| options.verbose | boolean | Enable verbose (trace) level logging for the quality module. |
**Returns:** The quality module (`M`) for method chaining.
**Example:**

```lua
quality.init({
  enabled = true,
  level = quality.LEVEL_COMPREHENSIVE, -- Level 3
})
```
### configure(options)

Alias for `quality.init(options)`. Configures the quality module by merging provided options with defaults and central configuration.

```lua
quality.configure({
  level = 3,
  strict = true,
  verbose = true
})
```

*Refer to `quality.init(options)` for parameters and details.*

**Returns:** The quality module (`M`) for method chaining.

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

Tracks an assertion dynamically. This function is called by the assertion system (`lib/assertion/init.lua`) when an assertion (e.g., `expect(...).to.equal(...)`) is executed. The quality module maps the `action_name` to a broader category (e.g., 'equality', 'truth') for analysis.

```lua
-- Typically called internally by the assertion library:
-- quality.track_assertion("equal", "current_test_name_here")
```

| Parameter | Type | Description |
|-----------|------|-------------|
| action_name | string | The specific assertion method used (e.g., "equal", "exist", "be_nil"). |
| test_name_override | string | Optional. Name of the test; used if `current_test` is nil (should be rare with dynamic tracking). |
**Returns:** The quality module (`M`) for method chaining.
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

Performs static analysis on a test file primarily for its structural properties (describe/it blocks, hooks, nesting levels). Assertion metrics (count, types) are now determined dynamically via `track_assertion`.
**Important:** This function calls `quality.start_test` and `quality.end_test` internally for each test (`it` block) it discovers via parsing. If used on a file that is also run via the normal test execution flow, tests might be processed twice by the quality module.

```lua
local structural_analysis = quality.analyze_file("tests/my_test.lua")
```

| Parameter | Type | Description |
|-----------|------|-------------|
| file_path | string | Path to the test file to analyze |
**Returns:** A table containing structural analysis results (e.g., `tests` found, `has_describe`, `nesting_level`).
**Example:**

```lua
local analysis = quality.analyze_file("tests/my_test.lua")
print("File analysis found " .. #analysis.tests .. " tests.")
print("Max nesting level: " .. analysis.nesting_level)
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
-- Configuration for quality module itself (via `quality.init` or central_config `quality.*`):
--   enabled = true
--   level = 3
--   strict = false
-- Configuration for reporting of quality data (via central_config `reporting.*`):
--   reporting.formats.quality.default = "html"
--   reporting.templates.quality = "./custom_reports/quality-{test_file_slug}.{format}"
```

Note: The section previously titled "API Reference" detailing `firmo.quality_options`, `firmo.start_quality()`, etc., has been removed as it described an API pattern not primarily used by the framework. The quality module is typically accessed via `local quality = require("lib.quality")`, and its API methods like `quality.init()`, `quality.get_report_data()`, `quality.report()` are documented above. Test runner integration handles most direct interactions.

## Custom Rules

You can influence quality rules by configuring the quality `level` and using `strict` mode. The `custom_rules` field in the configuration is a conceptual placeholder; actual rule definitions and enforcement are managed by `lib/quality/level_checkers.lua`.

```lua
-- Example configuration in .firmo-config.lua:
-- return {
--   quality = {
--     enabled = true,
--     level = 3, -- Or a specific level that uses custom checks from level_checkers.lua
--     -- custom_rules = { -- This field is not directly processed by current logic
--     --   require_describe_block = true, 
--     --   min_assertions_per_test = 2
--     -- }
--   }
-- }

-- Or programmatically (typically done by runner):
local quality = require("lib.quality")
quality.init({
  level = 3
  -- custom_rules = { -- Note: Custom rule application depends on level_checkers.lua logic
  --   min_assertions_per_test = 3 
  -- }
})
```
Note: The `custom_rules` field in the configuration is a placeholder concept. Actual rule enforcement and quality level definitions are primarily managed by the hardcoded structures and logic within `lib/quality/level_checkers.lua`. Customization typically involves modifying `level_checkers.lua` or contributing new checkers.

## Examples

### Basic Quality Validation

Quality validation is typically enabled and configured via CLI arguments when using the `test.lua` runner.

```bash
# Run tests with quality validation at level 2
lua firmo.lua --quality --quality-level=2 tests/

# Generate an HTML report
lua firmo.lua --quality --quality-level=2 --format=html --report-dir=./reports tests/
```

Programmatic example (simplified, as the runner handles most details):
```lua
local quality = require("lib.quality")
local central_config = require("lib.core.central_config")
local reporting = require("lib.reporting")

-- Mimic runner enabling quality
-- In a real scenario, this would be set by CLI parsing or .firmo-config.lua
central_config.set("quality.enabled", true)
central_config.set("quality.level", 2)
quality.init() -- Initializes with settings from central_config

-- During test execution (handled by test_definition.lua and assertion.lua):
-- quality.start_test("Test / example test should pass")
-- quality.track_assertion("equal") -- Called by expect(...).to.equal(...)
-- quality.end_test()

-- After all tests run:
local report_data = quality.get_report_data()
reporting.save_quality_report("./reports/quality-report.html", report_data, "html")
```

### Custom Quality Configuration

Configure quality module settings, typically through `.firmo-config.lua` or programmatically via `quality.init()`.

```lua
-- In .firmo-config.lua
-- return {
--   quality = {
--     enabled = true,
--     level = 4,
--     strict = true,
--     -- custom_rules = { min_assertions_per_test = 3 } -- See note on custom_rules
--   }
-- }

-- Or programmatically:
local quality = require("lib.quality")
local central_config = require("lib.core.central_config")

quality.init({
  level = 4,
  strict = true,
  -- custom_rules = { min_assertions_per_test = 3 } -- See note above about custom_rules implementation
})
central_config.set("quality.enabled", true) -- Ensure it's active for test hooks

-- Simulate a test run...
-- (Test execution would call quality.start_test, quality.track_assertion, quality.end_test)

-- After tests:
if quality.meets_level(4) then -- quality.meets_level is available
  print("Meets quality level 4!")
else
  print("Below quality level 4!")
end

local report_data = quality.get_report_data()
local reporting = require("lib.reporting")
reporting.save_quality_report("./quality/report.html", report_data, "html")
reporting.save_quality_report("./quality/report.json", report_data, "json")
```

### Command Line Usage

```bash
# Run tests with quality validation enabled (uses configured default level, e.g., from .firmo-config.lua)
lua firmo.lua --quality tests/

# Specify quality level to enforce
lua firmo.lua --quality --quality-level=3 tests/

# Enable strict mode (via .firmo-config.lua: quality.strict = true)
# Note: --quality-strict CLI flag is not currently implemented.
# lua firmo.lua --quality --quality-level=3 tests/ (and ensure strict=true in config)

# Set report format and output directory
lua firmo.lua --quality --format=html --report-dir=./reports tests/
# Note: Specific output filenames within the report directory are typically auto-generated 
# (e.g., quality-mytest.html). The exact naming can be influenced by 
# `reporting.templates.quality` in `.firmo-config.lua`.

# Run with both quality and coverage
lua firmo.lua --quality --quality-level=3 --coverage tests/
```
