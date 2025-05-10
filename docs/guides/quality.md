# Quality Validation Guide

This guide explains how to use Firmo's quality validation system (`lib.quality`) to ensure your tests meet specific quality standards.

**Note:** This module is under active development. Some features described might be partially implemented or subject to change.

## Introduction

Firmo's quality module helps ensure your tests are comprehensive, well-structured, and properly validate your code. The quality system evaluates tests across multiple dimensions, such as:

- Assertion coverage and types
- Test organization and naming
- Edge case and boundary condition testing (partially inferred, relies on patterns)
- Error handling patterns
- Mock verification patterns
- Code coverage integration (if coverage module is active)

The quality module grades tests on a 1-5 scale, allowing you to set minimum quality requirements.

## Basic Usage

### Enabling Quality Validation

Quality validation is typically enabled and configured via the command line or the central configuration file.

1.  **Via `.firmo-config.lua` (Recommended):**

    ```lua
    -- In your .firmo-config.lua file
    return {
      -- ... other configurations
      quality = {
        enabled = true,
        level = 3, -- Target Quality Level (e.g., Comprehensive)
        strict = false -- If true, test suite might fail if quality level isn't met
      },
      -- ...
    }
    ```

2.  **Via Command Line:**

    ```bash
    # Run tests with quality validation, aiming for level 3
    lua firmo.lua --quality --quality-level=3 tests/
    # Note: --quality-level is optional; defaults from .firmo-config.lua or to level 3 if not set anywhere.
    ```

3.  **Programmatically (e.g., in a test setup script, less common for global enabling):**

    ```lua
    local quality = require("lib.quality")
    quality.init({
      enabled = true,
      level = quality.LEVEL_COMPREHENSIVE -- Use defined constants
    })
    ```

The test runner (`scripts/runner.lua`) will use these settings to initialize `lib.quality` automatically.

### Understanding Quality Levels

Firmo's quality validation provides five progressive quality levels. The exact checks for each level are detailed in `lib/quality/level_checkers.lua`.

| Level | Constant (`lib.quality`) | Name (in reports) | General Description (from `lib/quality/init.lua`)                                                                                                           |
| ----- | ------------------------ | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1     | `LEVEL_BASIC`            | Basic             | Basic tests with at least one assertion per test and proper structure                                                                                       |
| 2     | `LEVEL_STRUCTURED`       | Standard          | Standard tests with multiple assertions, proper naming, and error handling                                                                                  |
| 3     | `LEVEL_COMPREHENSIVE`    | Comprehensive     | Comprehensive tests with edge cases, type checking, isolated setup, and **mock/spy restoration**.                                                           |
| 4     | `LEVEL_ADVANCED`         | Advanced          | Advanced tests with boundary conditions, mock verification (including **restoration**), and context organization.                                           |
| 5     | `LEVEL_COMPLETE`         | Complete          | Complete tests with 100% branch coverage, security validation, performance testing, and **rigorous mock/spy lifecycle management (including restoration)**. |

### Configuring Quality Options

Configuration is primarily handled by `.firmo-config.lua` or CLI arguments, which are then passed to `quality.init()` by the runner.

**Example `.firmo-config.lua`:**

```lua
return {
  -- ...
  quality = {
    enabled = false,                -- Default: false. Set to true to enable.
    level = 3,                      -- Default: 3 (Comprehensive). Quality level to enforce (1-5).
    strict = false,                 -- Default: false. If true, the runner might treat quality failures as test failures.
    -- custom_rules = {}            -- Placeholder for future extensions. Limited effect currently.
  },
  reporting = {
    formats = {
      quality = {
        default = "html"            -- Default format for quality reports if --format is not given
      }
    },
    templates = {
      -- Example: Default path template for quality reports.
      -- Placeholders: {test_file_slug}, {format}, {type}, {date}, {datetime}, {suffix}
      quality = "./coverage-reports/quality-{test_file_slug}-{datetime}.{format}"
    },
    -- report_dir can also be set here to override the default ./coverage-reports/
    -- report_dir = "./my-custom-reports/"
  }
  -- ...
}
```

Programmatic overrides after initial `quality.init()` by the runner can be done via `central_config.set()` if needed, which `lib.quality` listens to:

```lua
local central_config = require("lib.core.central_config")

-- Example: Update config settings via central_config
-- These changes will be picked up by the quality module if it's already initialized.
central_config.set("quality.level", 4)
central_config.set("quality.strict", true)

-- Direct re-initialization or configuration with quality.init() is also possible
-- but typically the runner handles the first init() call.
-- local quality = require("lib.quality")
-- quality.init({ level = 4, verbose = true }) -- This will merge with existing config.
```

## Generating Quality Reports

Quality reports are generated by the test runner when `--quality` is active.
Use the standard `--format` and `--report-dir` CLI flags.

```bash
# Run tests with quality checks, generate an HTML quality report
# Output usually to default directory (e.g., ./coverage-reports/quality-mytest.html)
lua firmo.lua --quality --format=html tests/

# Generate a JSON report to a custom directory
lua firmo.lua --quality --format=json --report-dir=./my-reports tests/

# Generate a summary report (Markdown format, e.g., ./coverage-reports/quality-mytest.md)
lua firmo.lua --quality --format=summary tests/
```

You can also generate report content programmatically using `quality.report()` if data has been collected:

```lua
local quality = require("lib.quality")
local fs = require("lib.tools.filesystem") -- For writing files

-- Assume quality.init() was called and tests were run, so data is collected.

-- Get HTML report content
local html_content = quality.report("html")
if type(html_content) == "string" then
  fs.write_file("./custom-reports/quality.html", html_content)
end

-- Get JSON report data (returns a JSON string directly from the formatter)
local json_string = quality.report("json")
if type(json_string) == "string" then
  fs.write_file("./custom-reports/quality.json", json_string)
end
-- Note: `quality.report('json')` returns a JSON string because the JSONFormatter's `format` method
-- itself handles the conversion of the Lua quality data table into a JSON string.

-- Get summary report text
local summary_text = quality.report("summary")
if type(summary_text) == "string" then
  print(summary_text)
end
```

### Interpreting Quality Reports

Quality reports provide information about:

- Overall achieved quality level and target level.
- Statistics: tests analyzed, tests passing quality, assertion counts.
- Assertion type distribution.
- A list of issues found, often per test, detailing why a certain quality requirement was not met.
- Per-test achieved quality levels.

Review reports to identify areas for improving test comprehensiveness and structure.

#### Empty Describe Blocks

The quality system will also identify `describe` blocks that are entirely devoid of tests. A `describe` block is flagged if neither it nor any of its nested `describe` blocks contain any `it` test cases. This check helps in cleaning up unused structural elements from your test suite, ensuring that all defined `describe` contexts serve a purpose by ultimately organizing active tests. Such issues will be listed in the "Overall Issues" section of the reports.

### Interactive Fix Examples in HTML Report

The HTML quality report provides an "Overall Issues" section listing all quality concerns identified in your tests. To make these reports more actionable, for many common issues, you'll find a **"Show Example"** button to the right of the issue description.

Clicking this button will expand a panel directly below the issue. This panel includes:

- **A Title**: A brief description of the fix or improvement.
- **A Code Snippet**: A generic Lua code example illustrating how to address the specific quality issue or demonstrating a better practice.

You can click the button again (which will now read "Hide Example") to collapse the panel. These examples are designed to provide quick, actionable guidance on improving your test quality directly within the report.

### Other HTML Report Enhancements

Beyond the interactive fix examples, the HTML quality report interface includes several other features for better usability and visual clarity:

- **Light/Dark Theme Toggle**:
  Located in the top-right corner of the report, you'll find a toggle switch (🌑/☀️) allowing you to switch between a dark theme (default) and a light theme. Your preference is automatically saved in your browser's `localStorage` and will be applied the next time you open a Firmo HTML quality report.

- **Summary Pie Chart**:
  The "Summary Statistics" section now includes a responsive pie chart. This chart visually represents the proportion of "Tests Meeting Configured Level" compared to those that do not. A legend below the chart provides details on the segments, including counts and percentages. On wider screens, the chart appears next to the text statistics; on smaller screens, it stacks below for optimal viewing.

- **Syntax Highlighting for Examples**:
  The Lua code snippets shown in the "Show Example" panels feature basic syntax highlighting. This makes the example code easier to read and understand by visually differentiating keywords, comments, strings, and other language elements. (Note: This is a conceptual implementation; a more robust third-party library may be integrated in the future).

## Advanced Quality Configuration

### Custom Rules

The `M.config.custom_rules` table in `lib/quality/init.lua` is a placeholder for future, more advanced custom rule definitions. Currently, the primary way to customize quality checks is by modifying the logic within `lib/quality/level_checkers.lua` or by adjusting the patterns in `lib/quality/init.lua` used for static analysis.

The existing level checkers evaluate a predefined set of criteria. True ad-hoc custom rule functions are not deeply supported by the current infrastructure without code changes to these core files.

### Integration with CI/CD

Quality validation can be integrated into CI/CD pipelines:

```bash
# In CI script: Run tests with quality checks and generate a JSON report
lua firmo.lua --quality --quality-level=3 --format=json --report-dir=./ci-reports tests/

# Check the exit code of `test.lua`. The runner exits with 0 if tests pass and
# report generation succeeds. The `strict = true` setting in `.firmo-config.lua` (under `quality`)
# influences how `lib/quality/level_checkers.lua` evaluates if a test 'passes'
# its target quality level (by potentially stopping evaluation at the first failed level if it's at or below target).
# It does not directly cause the `test.lua` runner to exit with a non-zero code based on quality metrics.
# For CI, you would typically parse the generated JSON quality report
# (e.g., ./ci-reports/quality-mytest.json) and determine if the achieved
# quality level (from report_data.level or report_data.summary.quality_level_achieved)
# or `report_data.summary.tests_passing_quality` meets your CI threshold.

# Example pseudo-script to check report:
# local report_content = read_json_file("./ci-reports/quality-report-....json")
# if report_content.level < 3 then
#   print("Quality level below target!")
#   exit 1
# fi
```

### Programmatic Quality Checking

You can use the quality module's API for programmatic checks:

```lua
local quality = require("lib.quality")

-- Ensure quality module is initialized (e.g. by runner or manually for specific tasks)
quality.init({ enabled = true, level = 3 })
quality.reset() -- Reset stats if running checks multiple times

-- Example: Check quality of a specific file (performs static analysis)
local meets_lvl_3, issues = quality.check_file("tests/specific_module_test.lua", 3)

if not meets_lvl_3 then
  print("File tests/specific_module_test.lua does not meet quality level 3:")
  for _, issue_detail in ipairs(issues or {}) do
    print(string.format("  Test '%s': %s", issue_detail.test or "N/A", issue_detail.issue or "Unknown issue"))
  end
end

-- Example: Programmatically check if the overall collected data meets a level
-- This assumes tests have been run and data collected (e.g., via test_definition.lua hooks)

-- Simulate test run for demonstration:
quality.start_test("Demo Test 1")
-- In real tests, quality.track_assertion("action_name") is called by expect()
quality.track_assertion("equality")
quality.end_test()

local overall_meets_target = quality.meets_level(quality.LEVEL_COMPREHENSIVE) -- Checks against configured level or provided level
if overall_meets_target then
  print("Overall quality meets configured/target standards!")
else
  print("Overall quality does NOT meet configured/target standards.")
  local report_data = quality.get_report_data() -- Get data as Lua table
  if report_data and report_data.summary and report_data.summary.issues then
     print("Issues found:")
     for _, issue_item in ipairs(report_data.summary.issues) do
        print(string.format("  Test '%s': %s", issue_item.test, issue_item.issue))
     end
  end
end
```

## Error Handling

Many quality module functions that perform significant operations (like file I/O or calling formatters)
use `pcall` internally and return success status along with results or error objects/messages.

- `check_file` returns `meets (boolean), issues (table)`. `issues` can indicate problems.
- `report` returns `content (string|table)` on success. If formatting fails, it might return the raw data table.
- `save_report` returns `success (boolean), error_message (string|nil)`.

Always check return values.

```lua
local quality = require("lib.quality")
local firmo = require("firmo") -- For expect and test_helper
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")

quality.init({ enabled = true }) -- Ensure it's enabled for these examples

describe("Quality Module Error Handling", function()
  it("should handle check_file for non-existent files", function()
    -- Assuming fs.read_file (used by quality.check_file's read_file) returns nil for non-existent files
    -- and check_file handles this by likely returning false and perhaps an issue.
    local meets, issues = quality.check_file("path/to/non_existent_file.lua", 1)
    expect(meets).to.equal(false)
    -- The exact content of 'issues' would depend on error handling within check_file
    -- For example, it might add an issue like "File not found" or simply have no specific issues if analysis can't proceed.
    -- expect(#issues).to.be_greater_than(0) -- This assertion is speculative
  end)

  it("should handle report generation with invalid format", function()
    -- quality.report attempts to use lib.reporting.format_quality.
    -- If format_quality fails (e.g., formatter for "invalid-format" not found),
    -- quality.report should return the raw data table instead of a formatted string/table.
    local report_output = quality.report("invalid-format-that-does-not-exist")

    expect(type(report_output)).to.equal("table") -- Should be the raw data table
    expect(report_output.report_type).to.equal("quality") -- Raw data has report_type
  end)

  it("should handle save_report errors", function()
    -- Simulate a scenario where saving might fail (e.g., invalid path for some OS, or mock fs.write_file to fail)
    -- For this example, we'll assume an unwriteable path.
    -- Note: Actual behavior depends on fs.write_file and os-level permissions.
    local success, err_msg = quality.save_report("/hopefully/invalid/path/report.html", "html")
    expect(success).to.equal(false)
    expect(err_msg).to.be.a("string")
    -- expect(err_msg).to.match("Failed to save report") -- Or a more specific OS error
  end)
end)
```
