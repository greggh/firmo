# Quality Validation Guide


This guide explains how to use Firmo's quality validation system to ensure your tests meet specific quality standards beyond simple code coverage.

## Introduction


Code coverage alone isn't enough to guarantee effective tests. Firmo's quality module helps ensure your tests are comprehensive, well-structured, and properly validate your code. The quality system evaluates tests across multiple dimensions:


- **Assertion coverage**: Are you testing the right things with appropriate assertions?
- **Test organization**: Are tests structured properly with describe/it blocks and proper naming?
- **Edge case testing**: Do tests verify boundary conditions and special cases?
- **Error handling**: Are error paths and validation properly tested?
- **Mock verification**: Are mocks and stubs properly verified?

The quality module grades tests on a 1-5 scale, allowing you to set minimum quality requirements for your project.

## Basic Usage


### Enabling Quality Validation


To enable quality validation for your tests:


```lua
-- In your test file or setup module
local quality = require("lib.quality")
-- Initialize and enable via direct call (less common)
quality.init({
  enabled = true,
  level = 3 -- Comprehensive level
})
```

Using the central configuration system (Recommended):
})
```


Using the central configuration system:


```lua
-- In your .firmo-config.lua file
return {
  quality = {
    enabled = true,
    level = 3
  }
}
```


From the command line:


```bash

# Run tests with quality validation at level 3


lua test.lua --quality --quality-level=3 tests/
```



### Understanding Quality Levels


Firmo's quality validation provides five progressive quality levels:


1. **Basic (Level 1)**
   - At least one assertion per test
   - Proper test and describe block structure
   - Basic test naming
2. **Standard (Level 2)**
   - Multiple assertions per test (at least 2)
   - Testing equality, truth value, and type checking 
   - Clear test organization and naming
3. **Comprehensive (Level 3)**
   - Multiple assertion types (at least 3 different types)
   - Edge case testing
   - Setup/teardown with before/after hooks
   - Context nesting for organized tests
4. **Advanced (Level 4)**
   - Boundary condition testing
   - Mock verification
   - Integration and unit test separation
   - Performance validation where applicable
5. **Complete (Level 5)**
   - High branch coverage (90% threshold)
   - Security validation
   - Comprehensive API contract testing
   - Multiple assertion types (at least 5 different types)
   - Performance testing requirements


### Configuring Quality Options

You can configure quality validation primarily through the central configuration system (`.firmo-config.lua` or using `central_config.set`). Alternatively, use `quality.configure({})` programmatically.


```lua
-- In .firmo-config.lua
return {
  quality = {
    enabled = true,                -- Enable quality validation
    level = 3,                     -- Quality level to enforce (1-5)
    strict = false,                -- Fail on first issue
    custom_rules = {               -- Custom quality rules
      require_describe_block = true,
      min_assertions_per_test = 3
    }
  },
  reporting = {
    formats = {
      quality = {
        default = "html"           -- Default format for quality reports
      }
    },
    templates = {
      quality = "./reports/quality-{timestamp}.{format}"  -- Report path template
    }
  }
}
```


Or directly in your code:


```lua
local quality = require("lib.quality")
local central_config = require("lib.core.central_config")

-- Example: Update config settings via central_config
central_config.set("quality.enabled", true)
central_config.set("quality.level", 3)
central_config.set("quality.strict", false)

-- Example: Configure directly using the quality module API
-- This merges with existing config (central or default)
quality.configure({
  level = 4,         -- Override level
  verbose = true     -- Enable verbose logging for quality module
})
```
## Generating Quality Reports

Quality reports are typically generated as part of the overall test run when the `--quality` flag is used, leveraging the reporting system. The format is specified using the general `--format` flag, and the output directory using `--report-dir` or central configuration.

```bash
# Run tests with quality checks and generate an HTML quality report
# The report will usually be saved in ./coverage-reports/quality-report.html
lua test.lua --quality --format=html tests/

# Generate a JSON report instead
lua test.lua --quality --format=json --report-dir=./my-reports tests/
```

You can also generate report content programmatically using `quality.report()`:

```lua
local quality = require("lib.quality")
local reporting = require("lib.reporting") -- Needed for file writing

-- Assume quality data has been collected...

-- Get HTML report content
local html_content = quality.report("html")
if html_content then
  reporting.write_file("./reports/quality.html", html_content)
end

-- Get JSON report data
local json_data = quality.report("json")
if json_data then
  reporting.write_file("./reports/quality.json", json_data) -- write_file handles JSON encoding
end

-- Get summary report text
local summary_text = quality.report("summary")
if summary_text then
  print(summary_text)
end
```

### Interpreting Quality Reports


Quality reports provide information about:


- Overall quality level achieved
- Test count and assertion statistics
- Which quality standards were met or missed
- Specific recommendations for improvement
- Assertion type distribution
- Quality scores by test file or module


## Advanced Quality Configuration


### Custom Rules


You can define custom quality rules for specific project needs:
The `custom_rules` configuration option accepts a table where keys are rule names and values are typically booleans to enable/disable built-in checks or potentially functions for custom validation logic (check source for specific implementation). Example structure:

```lua
local central_config = require("lib.core.central_config")
central_config.set("quality.custom_rules", {
  -- These are illustrative examples; actual rule keys may differ.
  require_describe_block = true,
  min_assertions_per_test = 2,
  -- You might define a custom function:
  -- custom_check_naming = function(test_data) ... return boolean, message ... end
})
```
Consult the source code (`lib/quality/init.lua` and `level_checkers.lua`) for the exact built-in custom rules available and how to define new ones.

### Integration with CI/CD


Quality validation can be integrated into CI/CD pipelines to enforce quality standards:
```bash



# In CI script


lua test.lua --quality --quality-level=3 --quality-format=json --quality-output=./quality-report.json tests/

# Optional: Fail the build if quality level isn't met
# This requires a custom script (`check_quality_level.lua`) to parse the report
# and check the achieved level against the target (e.g., level 3).
# if ! lua scripts/check_quality_level.lua ./coverage-reports/quality-report.json 3; then
#   echo "Quality validation failed!"
#   exit 1
# fi


```text

### Programmatic Quality Checking


You can check quality programmatically:
```lua
local quality = require("lib.quality")
local test_helper = require("lib.tools.test_helper") -- For error capture example

-- Example: Check quality of a specific file
local meets, issues = quality.check_file("tests/my_test.lua", 3) -- Check against level 3

if not meets then
  print("File does not meet quality level 3:")
  for _, issue in ipairs(issues or {}) do
    print(string.format("  Test '%s': %s", issue.test or "N/A", issue.issue or "Unknown issue"))
  end
end

-- Example: Programmatically check if the overall collected data meets a level
-- (Assumes quality.init() was called and tests were run)
local overall_meets = quality.meets_level(3)
if overall_meets then
  print("Overall quality meets level 3 standards!")
else
  print("Overall quality does not meet level 3 standards.")
  -- Get report data for analysis
  local report_data = quality.report("json") -- Get data as Lua table
  if report_data and report_data.summary and report_data.summary.issues then
     print("Issues found:")
     for _, issue_category in ipairs(report_data.summary.issues) do
        print(string.format("  - %s: %d occurrences (%s)", issue_category.category, issue_category.count, issue_category.severity))
     end
  end
end

```
## Error Handling

The quality module functions typically return success status and potential issues or errors.

-   `check_file` returns `meets (boolean), issues (table|nil)`.
-   `validate_test_quality` returns `meets (boolean), issues (table|nil)`.
-   `report` returns `content (string|table|nil), error (table|nil)`.

Check the return values to handle potential problems:

```lua
local quality = require("lib.quality")
local test_helper = require("lib.tools.test_helper")
local expect = require("firmo").expect -- Assuming Firmo's expect

it("should handle missing files gracefully", function()
  -- check_file returns false, issues for missing files
  local meets, issues = quality.check_file("non_existent_file.lua", 1)

  expect(meets).to.equal(false)
  -- Issues table might contain details, depending on implementation
  -- expect(issues).to.exist()
end)

it("should handle report generation errors", function()
  -- Simulate condition where report generation might fail (e.g., invalid format)
  local report_content, err = quality.report("invalid-format")

  expect(report_content).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("Unknown report format")
end)
```
