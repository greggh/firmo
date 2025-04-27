# tests/quality Knowledge

## Purpose

The `tests/quality/` directory contains tests specifically for validating Firmo's test quality analysis system, which is implemented in the `lib/quality` module. These tests ensure that the quality module correctly analyzes data gathered during test runs (like assertion counts and types, potentially coverage metrics), accurately evaluates tests against the defined rules for different quality levels (1-5), calculates quality metrics, and generates appropriate report data.

## Key Concepts

The tests in this directory cover the different aspects of the quality validation system:

- **Main API & Metric Tracking (`quality_test.lua`):** This file likely tests the core public API of the `lib/quality` module. This includes:
    - Initialization and configuration (`quality.init`, `quality.configure`).
    - Resetting state (`quality.reset`, `quality.full_reset`).
    - Tracking test execution events (`quality.start_test`, `quality.end_test`).
    - Tracking assertion usage (`quality.track_assertion`).
    - Verifying the internal statistics (`quality.stats`) are correctly updated based on tracked events.
    - Testing the generation of structured report data (`quality.get_report_data`).

- **Level Rule Validation (`level_*.lua` Files):** Each file named `level_X_test.lua` (e.g., `level_1_test.lua`, `level_2_test.lua`, etc.) is designed to test the validation logic for that specific quality level. These tests likely contain minimal `describe` and `it` blocks that are carefully crafted to either *just meet* or *just fail* the requirements defined for that level in `lib/quality/level_checkers.lua`.
    - **Example (Level 1):** Tests might check if `quality.validate_test_quality` correctly passes a test with at least one assertion but fails a test with zero assertions.
    - **Example (Level 2):** Tests might simulate providing different coverage data (potentially mocked) to the quality module and verify if the pass/fail status matches the Level 2 coverage requirements.
    - **Example (Higher Levels):** Tests might check for the presence of specific assertion types (tracked via `track_assertion`), error handling patterns, setup/teardown hooks, etc., as defined by the rules for levels 3, 4, and 5.

## Usage Examples / Patterns (Illustrative Test Snippets)

### Testing API and Metric Tracking (Conceptual from `quality_test.lua`)

```lua
--[[
  Example test verifying basic API calls and stats updates.
]]
local quality = require("lib.quality")
local expect = require("lib.assertion.expect").expect

describe("Quality Module API", function()
  before_each(quality.reset) -- Ensure clean state

  it("should track tests and assertions", function()
    quality.init({ enabled = true, level = 1 })

    quality.start_test("Test 1")
    quality.track_assertion("equality") -- Simulate an assertion
    quality.end_test()

    quality.start_test("Test 2")
    quality.track_assertion("truth")
    quality.track_assertion("type_checking")
    quality.end_test()

    local report_data = quality.get_report_data()
    local summary = report_data.summary

    expect(summary.tests_analyzed).to.equal(2)
    expect(summary.assertions_total).to.equal(3)
    expect(summary.assertions_per_test_avg).to.equal(1.5)
    expect(summary.tests_passing_quality).to.equal(2) -- Assuming both meet Level 1
    expect(report_data.level).to.equal(1) -- Assuming both met Level 1
  end)
end)
```

### Testing Level Rule Failure (Conceptual from `level_1_test.lua`)

```lua
--[[
  Example test verifying that a test with no assertions fails Level 1.
]]
local quality = require("lib.quality")
local expect = require("lib.assertion.expect").expect

describe("Quality Level 1 Rules", function()
  before_each(quality.reset)

  it("fails level 1 if no assertions are tracked", function()
    quality.init({ enabled = true, level = 1 })
    quality.start_test("No Assertion Test")
    -- No calls to quality.track_assertion()
    quality.end_test()

    -- Validate the quality of the tracked test data
    local meets, issues = quality.validate_test_quality("No Assertion Test", { level = 1 })

    expect(meets).to.be_falsey("Test should fail Level 1")
    expect(issues).to.be.a("table")
    expect(#issues).to.be.greater_than(0)
    expect(issues[1]).to.match("[Tt]oo few assertions")
  end)
end)
```

### Testing Level Rule Pass (Conceptual from `level_1_test.lua`)

```lua
--[[
  Example test verifying that a test with assertions passes Level 1.
]]
local quality = require("lib.quality")
local expect = require("lib.assertion.expect").expect

describe("Quality Level 1 Rules", function()
  before_each(quality.reset)

  it("passes level 1 if at least one assertion is tracked", function()
    quality.init({ enabled = true, level = 1 })
    quality.start_test("Assertion Test")
    quality.track_assertion("some_assertion_type") -- Track one assertion
    quality.end_test()

    local meets, issues = quality.validate_test_quality("Assertion Test", { level = 1 })

    expect(meets).to.be_truthy("Test should pass Level 1")
    expect(#(issues or {})).to.equal(0)
  end)
end)
```

**Note:** The examples in the previous version of this file showing direct configuration like `firmo.quality_options` or metrics retrieval like `quality.get_metrics()` were inaccurate representations of the likely API and test structure.

## Related Components / Modules

- **Module Under Test:**
    - `lib/quality/knowledge.md` (Overview)
    - `lib/quality/init.lua` (Main API, statistics, evaluation logic)
    - `lib/quality/level_checkers.lua` (Defines the rules for each quality level)
- **Test Files:**
    - `tests/quality/quality_test.lua`
    - `tests/quality/level_1_test.lua`
    - `tests/quality/level_2_test.lua`
    - `tests/quality/level_3_test.lua`
    - `tests/quality/level_4_test.lua`
    - `tests/quality/level_5_test.lua`
- **Dependencies (Analyzed by Quality Rules):**
    - `lib/coverage/knowledge.md`: Coverage data is often a component of higher quality levels.
    - `lib/assertion/knowledge.md`: Assertion counts and types are key inputs for quality rules.
- **Helper Modules:**
    - `lib/tools/test_helper/knowledge.md`: May be used for setting up specific test conditions.
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Targeted Level Tests:** Each `level_*.lua` test file should contain clear and minimal examples demonstrating the pass/fail boundary conditions for the specific rules of that level.
- **Test Configuration Effects:** `quality_test.lua` should verify how different settings in `quality.init()` (e.g., changing `level`, `strict` mode) affect the outcome of quality validation.
- **Mock Dependencies:** When testing rules that rely on external data (e.g., coverage metrics), use mock data or mock the dependency (like `lib/coverage`) to provide consistent, predictable input to the quality module, isolating the test to the quality rule logic itself.
- **Verify Report Data:** Tests should validate the structure and key values within the data returned by `quality.get_report_data()` to ensure it is suitable for consumption by reporting formatters.

## Troubleshooting / Common Pitfalls (Optional)

- **Incorrect Quality Level Assigned / Validation Failure:**
    - **Cause 1:** The logic within the specific rule checker function in `lib/quality/level_checkers.lua` for the relevant level might be flawed.
    - **Cause 2:** The test data being analyzed (`test_data[test_name]`) is incorrect. Was `track_assertion` called the expected number of times? If testing coverage rules, was the correct mock coverage data provided?
    - **Debugging:** Add logging within the specific level checker function to see the input data and intermediate calculations. Check the contents of `quality.stats` and the detailed `test_data` table after the test run.
- **Metric Calculation Errors (`quality.stats`):**
    - **Cause:** The aggregation logic in `quality.end_test` or the final calculation in `quality.get_report_data` might be incorrect (e.g., average calculation, summation).
    - **Debugging:** Step through or add logging to `end_test` and `get_report_data` to trace how statistics are accumulated and calculated.
- **Coverage Rule Integration Issues:**
    - **Cause:** The quality module might not be correctly accessing or interpreting coverage data from `lib/coverage` (or the mock).
    - **Debugging:** Verify how `M.config.coverage_data` is set during `quality.init`. Check the mock data structure if mocking, or ensure the live coverage module provides data in the expected format. Add logging where coverage data is accessed in the level checker.
