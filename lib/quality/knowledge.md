# Quality Module Knowledge

## Purpose

This document outlines key internal concepts, implementation patterns, and design considerations for the `lib/quality` module, intended for developers working on or understanding Firmo's test quality validation system. Note that this module is partially implemented, and some documented features may not be fully functional.

## Key Concepts

-   **Quality Levels (1-5):** The module defines five levels of increasing test quality requirements, from Basic (level 1) to Complete (level 5).
-   **Level Checkers (`level_checkers.lua`):** This file contains functions (`check_level_1`, `check_level_2`, etc.) that implement the specific validation rules for each quality level. These checks analyze collected test data (assertion counts, coverage, etc.).
-   **Data Collection:** The `init.lua` module provides functions (`start_test`, `track_assertion`, `end_test`) intended to be called by the test runner or test definition system during test execution to gather metrics like assertion types used and test duration.
-   **File Analysis:** Functions like `check_file` (implemented) and `analyze_file` (implemented) process collected data and potentially use the parser (`lib/tools/parser`) to evaluate static aspects of test files against the configured quality level. `validate_test_quality` is marked unimplemented in the header but seems used internally.
-   **Reporting Integration:** The `quality.report(format)` function (implemented) generates report content (summary, json, html) by summarizing the collected data and validation results, integrating with the main `lib/reporting` system for file saving.
-   **Configuration:** Uses `central_config` and `quality.configure` to manage settings like `enabled`, target `level`, `strict` mode, and potential `custom_rules`.

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
    expect(1).to.equal(1)
    quality.track_assertion("equal") -- Track assertion type
    expect(true).to.be_truthy()
    quality.track_assertion("be_truthy")
  end)
  after(function() quality.end_test() end) -- Records duration, finalizes data

  -- Add another test...
  before(function() quality.start_test("Test 2") end)
  it("Test 2", function()
    expect("a").to.be.a("string")
    quality.track_assertion("be_a")
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
local report_content, err = quality.report("invalid-format")

if not report_content then
  print("Failed to generate report:", err.message)
  -- Handle error (e.g., log it, use default report)
end
```

## Related Components / Modules

-   **Source:** [`lib/quality/init.lua`](init.lua), [`lib/quality/level_checkers.lua`](level_checkers.lua)
-   **Usage Guide:** [`docs/guides/quality.md`](../../docs/guides/quality.md)
-   **API Reference:** [`docs/api/quality.md`](../../docs/api/quality.md)
-   **Reporting:** [`lib/reporting/init.lua`](../reporting/init.lua) - Used to format and save quality reports.
-   **Parser:** [`lib/tools/parser/init.lua`](../tools/parser/init.lua) - Potentially used by `analyze_file` for static checks.
-   **Test Definition:** [`lib/core/test_definition.lua`](../core/test_definition.lua) - Provides test structure and data used for quality checks.
-   **Configuration:** [`lib/core/central_config.lua`](../core/central_config.lua) - Provides configuration settings.
