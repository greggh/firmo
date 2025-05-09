# Quality Module Knowledge

## Purpose

This document outlines key internal concepts, implementation patterns, and design considerations for the `lib/quality` module, intended for developers working on or understanding Firmo's test quality validation system. This module has been significantly developed and integrated, with its core features now functional.

## Key Concepts

- **Quality Levels (1-5):** The module defines five levels of increasing test quality requirements, from Basic (level 1) to Complete (level 5).
- **Level Checkers (`level_checkers.lua`):** This file contains functions (`check_level_1`, `check_level_2`, etc.) that implement the specific validation rules for each quality level. These checks analyze collected test data (assertion counts, coverage, etc.).
- **Data Collection:** The `init.lua` module provides functions called by the test runner and assertion system to gather metrics.
  - `M.start_test`, `M.end_test`: Called by `lib/core/test_definition.lua` around `it` blocks.
  - `M.track_assertion`: Called by `lib/assertion/init.lua` for dynamic assertion tracking.
  - `M.track_spy_created`, `M.track_spy_restored`: Called by `lib/mocking/spy.lua` to track spy lifecycles for restoration checks.
  - `M.start_describe`, `M.end_describe`: Called by `lib/core/test_definition.lua` to track `describe` block structure and identify empty subtrees.
- **File Analysis:** Functions like `analyze_file` process test files primarily for structural properties (describe/it blocks, hooks). Assertion counting and detailed type analysis are now handled dynamically via `M.track_assertion`. `check_file` and `validate_test_quality` use the collected dynamic data and structural info to evaluate against quality levels.
- **Reporting Integration:** The `quality.report(format)` function generates report content (summary/markdown, json, html) by summarizing collected data and validation results. It integrates with `lib/reporting` for file saving.
  The HTML formatter (`lib/reporting/formatters/html.lua`) for quality reports is particularly feature-rich, now including:
  - Interactive "fix-it" examples for common issues.
  - A light/dark theme toggle with preference persistence.
  - A responsive pie chart visualizing summary statistics.
  - Conceptual syntax highlighting for Lua code examples (note: current implementation is a JS placeholder; full library integration like Prism.js is a future enhancement).
- **Configuration:** Uses `central_config` and `quality.configure` (internally `M.init`) to manage settings like `enabled`, target `level`, `strict` mode, and potential `custom_rules`.
- **CLI for Quality Reports:** When using the test runner (`scripts/runner.lua`):
  - Enable quality analysis with `--quality`.
  - Specify the desired report format(s) using the global `--format=<format_name>` flag (e.g., `--format=html`, `--format=json`, `--format=md`). The quality module supports `html`, `json`, and `summary` (which produces Markdown `.md` files).
  - Specify the output directory with the global `--report-dir=<path_to_directory>` flag.
  - Note: Quality-specific CLI flags like `--quality-format` or `--quality-output` are _not_ implemented; use the global flags. The runner handles passing these to the reporting system for quality reports.
- **Advanced Structural Checks:**
  - _Mock/Spy Restoration_: For relevant quality levels (typically Level 3+), the system now checks if spies created via `firmo.spy.on()` are correctly restored using their `:restore()` method by the end of the test. This uses data from `M.track_spy_created` and `M.track_spy_restored`. An issue is logged for the test if unrestored spies are detected.
  - _Empty Describe Block (Subtree)_: The system identifies `describe` blocks that are entirely empty, meaning neither the block itself nor any of its nested `describe` children contain any `it` test cases. Such empty describe trees are reported as a global issue, helping to maintain a clean test structure. This uses data from `M.start_describe`, `M.end_describe`, and `M.start_test`.

## Usage Examples / Patterns

### Configuring Quality Module

```lua
--[[
  Demonstrates different ways to configure the quality module.
]]
local quality = require("lib.quality")
local central_config = require("lib.core.central_config")

-- Option 1: Via central_config (e.g., in .firmo-config.lua)
-- return { quality = { enabled = true, level = 3, strict = false } }

-- Option 2: Programmatically via central_config
central_config.set("quality.enabled", true)
central_config.set("quality.level", 3) -- Comprehensive
quality.init() -- Reads from central_config

-- Option 3: Directly via quality.configure (merges with others)
quality.configure({ level = 4, strict = true, verbose = true })
```

### Data Collection & Validation (Conceptual Flow)

```lua
--[[
  Illustrates data collection during a test run (typically done by runner)
  and checking results afterwards using implemented functions.
]]
local quality = require("lib.quality")
local firmo = require("firmo") -- For test functions
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

quality.configure({ enabled = true, level = 3 })
quality.reset() -- Reset stats before a test file run

describe("Example Quality Tracking", function()
  before(function() quality.start_test("Test 1") end) -- Name matches 'it' block
  it("Test 1", function()
    -- Note: quality.track_assertion() is now called automatically by expect() assertions.
    -- Manual calls are generally not needed in test scripts.
    expect(1).to.equal(1)
    expect(true).to.be_truthy()
  end)
  after(function() quality.end_test() end) -- Records duration, finalizes data

  -- Add another test...
  before(function() quality.start_test("Test 2") end)
  it("Test 2", function()
    expect("a").to.be.a("string")
  end)
  after(function() quality.end_test() end)
end)

-- After tests run, check overall level or generate report
local meets_level_3 = quality.meets_level(3)
print("Meets Level 3:", meets_level_3)

local summary = quality.report("summary") -- Get summary text
if summary then print(summary) end

-- Check a specific file (might re-analyze or use collected data)
local file_meets, issues = quality.check_file("path/to/the/test_file.lua", 3)
if not file_meets then
  print("File failed level 3 checks.")
end
```

### Quality Level Examples (Conceptual)

```lua
--[[
  Conceptual examples of tests aiming for different quality levels.
  Note: Automated checking for all criteria might be limited in the current implementation.
]]

-- Level 1: Basic Syntax
describe("Basic Quality", function()
  it("has assertions", function()
    expect(true).to.be_truthy()
  end)
end)

-- Level 2: Coverage (Requires running with --coverage)
describe("Coverage Quality", function()
  it("tests edge cases", function()
    expect(process_number(-1)).to.equal(0) -- Assuming process_number exists
    expect(process_number(0)).to.equal(0)
    expect(process_number(1)).to.equal(1)
  end)
end)

-- Level 3: Assertions
describe("Assertion Quality", function()
  it("uses specific assertions", function()
    local result = { status = "success", data = { id = 123 } } -- Example result
    expect(result.status).to.equal("success")
    expect(result.data).to.be.a("table")
    expect(result.data.id).to.be_greater_than(0)
  end)
end)

-- Level 4: Error Handling
describe("Error Quality", function()
  local test_helper = require("lib.tools.test_helper")
  it("verifies error conditions", { expect_error = true }, function()
    local risky_operation = function() error("Bad data") end -- Example func
    local result, err = test_helper.with_error_capture(risky_operation)()
    expect(err).to.exist()
    -- expect(err.category).to.equal("VALIDATION") -- Assuming error has category
  end)
end)

-- Level 5: Documentation (Manual Check Needed)
describe("Documentation Quality", function()
  -- Code has JSDoc comments (checked manually or by external tools)
  it("authenticates users", function()
    -- Test implementation
  end)
end)
```

### Error Handling

Functions like `check_file` and `report` return standard `result, error_object` pairs on failure (e.g., file not found, invalid format).

```lua
-- Example checking error from report generation
local report_output = quality.report("invalid-format-that-will-fail-fallback") -- Use a more specific non-existent format
if type(report_output) == "table" and report_output.report_type == "quality" then
  -- This branch is hit if formatting fails and raw data is returned
  print("Failed to generate formatted report, received raw data instead. Tests analyzed: " .. (report_output.summary and report_output.summary.tests_analyzed or "N/A"))
elseif type(report_output) == "string" then
  -- This branch could be hit if it successfully fell back to 'summary' format
  print("Report generation fell back to summary (or was successful):")
  print(report_output)
else
  -- This case implies an even more severe failure if report_output is nil
  print("Report generation failed, and no raw data or fallback was returned.")
end
```

## Related Components / Modules

- **Source:** [`lib/quality/init.lua`](init.lua), [`lib/quality/level_checkers.lua`](level_checkers.lua)
- **Usage Guide:** [`docs/guides/quality.md`](../../docs/guides/quality.md)
- **API Reference:** [`docs/api/quality.md`](../../docs/api/quality.md)
- **Reporting:** [`lib/reporting/init.lua`](../reporting/init.lua) - Used to format and save quality reports.
- **Parser:** [`lib/tools/parser/init.lua`](../tools/parser/init.lua) - Potentially used by `analyze_file` for static checks.
- **Test Definition:** [`lib/core/test_definition.lua`](../core/test_definition.lua) - Provides test structure and data used for quality checks.
- **Configuration:** [`lib/core/central_config.lua`](../core/central_config.lua) - Provides configuration settings.
