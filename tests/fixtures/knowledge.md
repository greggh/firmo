# tests/fixtures Knowledge

## Purpose

The `tests/fixtures/` directory serves as a repository for shared resources used across multiple different test files within the Firmo project. Fixtures are predefined states, data sets, helper functions, mock modules, or any other artifact used to establish a consistent baseline or provide reusable components for running tests. Using fixtures helps reduce code duplication in tests and separates test setup logic from the actual test assertions.

## Key Concepts

- **Types of Fixtures:** This directory can house various kinds of test fixtures:
    - **Helper Modules:** Reusable Lua modules providing utility functions or data structures commonly needed by tests. Examples include functions to generate specific errors or mock implementations of simple dependencies.
    - **Data Fixtures:** Files containing sample data (e.g., JSON, text, configuration snippets) that can be loaded and used as input for tests. (Currently, mainly Lua modules seem present).
- **Benefits:** Using fixtures promotes:
    - **Consistency:** Ensures multiple tests run against the same baseline data or helper logic.
    - **Reusability:** Avoids duplicating complex setup code or common utility functions across many test files.
    - **Maintainability:** Centralizes shared test resources, making updates easier.
    - **Clarity:** Separates the setup/utility code (in fixtures) from the specific logic being tested.
- **Current Structure:**
    - `common_errors.lua`: Provides a collection of functions, each designed to intentionally trigger a specific common Lua runtime error (e.g., nil access, type error, division by zero). This is particularly useful for testing Firmo's error handling and reporting mechanisms.
    - `modules/`: A subdirectory intended to hold simple Lua modules that can be used as mock dependencies or targets for testing framework features (like module resetting or discovery). Currently contains `test_math.lua`.

## Usage Examples / Patterns

### Using Fixture Modules in Tests

```lua
--[[
  Illustrates how to require and use fixtures within a Firmo test file.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")

-- Require the error fixture module
local common_errors = require("tests.fixtures.common_errors")
-- Require a mock module fixture
local test_math = require("tests.fixtures.modules.test_math")

describe("Using Fixtures", function()
  it("can test error handling using common_errors fixture", function()
    -- Use expect_error to verify the fixture function throws as expected
    test_helper.expect_error(common_errors.nil_access, "attempt to index a nil value")
    test_helper.expect_error(common_errors.type_error, "attempt to call a number value")
    test_helper.expect_error(common_errors.arithmetic_error, "attempt to divide by zero")
  end)

  it("can use the test_math module fixture", function()
    expect(test_math.add(5, 3)).to.equal(8)
    expect(test_math.subtract(5, 3)).to.equal(2)
  end)
end)
```

## Related Components / Modules

- **Fixture Files:**
    - `tests/fixtures/common_errors.lua`
- **Fixture Subdirectories:**
    - `tests/fixtures/modules/knowledge.md` (Contains `test_math.lua`)
- **Supporting Modules:**
    - `lib/tools/test_helper/knowledge.md`: Often used in conjunction with fixtures, especially for testing error conditions triggered by fixtures or for setting up temporary environments where fixtures might be used.
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Keep Fixtures Simple and Focused:** Each fixture should ideally serve a single, well-defined purpose (e.g., provide specific data, trigger a specific error, mock a specific interface). Avoid creating overly complex or multi-purpose fixtures.
- **Document Fixtures:** Ensure the purpose, usage, and any potential side effects of a fixture are clearly documented, either through comments within the Lua file or via a dedicated `knowledge.md` file if the fixture is complex or part of a subdirectory.
- **Avoid Test Logic in Fixtures:** Fixtures should provide setup, data, or utilities. The actual test assertions and complex validation logic should reside within the test files (`it` blocks) that *use* the fixtures.
- **Use Correct `require` Paths:** When requiring a fixture from a test file, use the correct path relative to the `tests` directory (which is typically on the Lua path when running tests), e.g., `require("tests.fixtures.common_errors")`.

## Troubleshooting / Common Pitfalls (Optional)

- **`require` Errors:** If a test fails with `module 'tests.fixtures....' not found`, double-check the path used in the `require()` statement within the test file. Ensure it correctly points to the fixture file relative to the `tests/` directory.
- **Bugs within Fixtures:** Fixtures are code too and can contain bugs. If multiple tests using the same fixture start failing unexpectedly, investigate the fixture's code itself to ensure it behaves as intended.
- **State Leakage (Less Common for Simple Fixtures):** If a fixture module maintains internal state (generally discouraged for simple fixtures), ensure that state doesn't leak between different tests that use it. Consider making fixtures stateless or providing reset functions if state is unavoidable.
