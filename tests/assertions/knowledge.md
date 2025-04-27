# tests/assertions Knowledge

## Purpose

The `tests/assertions/` directory contains unit and integration tests specifically designed to validate the correctness and robustness of Firmo's assertion library. This includes the core `expect()` function, the standard set of matchers (like `.to.equal`, `.to.exist`, `.to.be.a`, `.to.match`), negation (`.to_not`), and any extended or specialized matchers provided by the `lib/assertion` module.

## Key Concepts

The tests within this directory aim to cover various aspects of the assertion library:
- **Core `expect` Functionality:** Verifying the basic behavior of `expect(value)` calls, correct chaining, and the implementation of fundamental matchers. See `expect_assertions_test.lua`.
- **Matcher Categories:** Dedicated tests often exist for specific groups of matchers to ensure they work correctly across different data types and edge cases (e.g., truthiness, numbers, strings, tables, collections). See `truthy_falsey_test.lua`, `extended_assertions_test.lua`, `specialized_assertions_test.lua`.
- **Negation (`.to_not`):** Ensuring that the negation mechanism works consistently across different matchers.
- **Error Handling & Messages:** Testing that assertions produce clear, informative, and correct error messages when expectations fail. This often involves using `lib/tools/test_helper.expect_error` to check the failure messages.
- **Integration:** Verifying that the assertion library integrates correctly with the broader Firmo test execution environment. See `assertion_module_integration_test.lua`.

## Usage Examples / Patterns

### Common Assertion Examples (Firmo Style)

```lua
-- Basic assertions
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
expect(value).to.be_truthy()
expect(value).to.match("pattern")
expect(fn).to.fail() -- Use test_helper.expect_error for more control

-- Negation
expect(value).to_not.exist()
expect(actual).to_not.equal(unexpected)
expect(value).to_not.be_truthy()

-- Collection assertions
expect("hello").to.have_length(5)
expect({1, 2, 3}).to.have_length(3)
expect({}).to.be.empty()
expect({"a", "b"}).to.contain("a")

-- Numeric assertions
expect(5).to.be.positive()
expect(-5).to.be.negative()
expect(10).to.be.integer()
expect(3.14).to.be.near(3.1415, 0.01)

-- String assertions
expect("HELLO").to.be.uppercase()
expect("hello").to.be.lowercase()
expect("hello world").to.start_with("hello")
expect("hello world").to.end_with("world")

-- Table assertions
expect({name = "John"}).to.have_property("name")
expect({name = "John"}).to.have_property("name", "John")
expect({1, 2, 3}).to.have_items({2, 3})
```

### Error Testing Pattern (Verifying Assertion Failures)

```lua
--[[
  Testing that an assertion fails correctly using test_helper.expect_error
]]
local test_helper = require("lib.tools.test_helper")
local expect = require("lib.assertion.expect").expect

it("should fail with a specific message when equal assertion fails", function()
  local err = test_helper.expect_error(function()
    expect(1).to.equal(2)
  end, "Expected%s*1%s*to equal%s*2") -- Pattern matching error message

  -- Optionally inspect the captured error further
  expect(err).to.exist()
  expect(err.category).to.equal(error_handler.CATEGORY.TEST_EXPECTED)
end)
```

### Incorrect Usage Examples (Avoid These)

```lua
-- INCORRECT: Using non-Firmo styles or wrong syntax
assert.is_not_nil(value)         -- Busted-style, use expect(value).to.exist()
assert.equals(expected, actual)  -- Busted-style and wrong param order
assert.True(value)               -- Busted-style, use expect(value).to.be_truthy()
expect(value).not_to.equal(x)    -- Incorrect negation syntax for Firmo

-- CORRECT: Firmo expect-style
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be_truthy()
expect(value).to_not.equal(x)    -- Correct negation syntax
```

## Related Components / Modules

- **Module Under Test:** `lib/assertion/knowledge.md` (and specifically `lib/assertion/expect.lua` and files in `lib/assertion/matchers/`)
- **Key Test Files:**
    - `tests/assertions/expect_assertions_test.lua`
    - `tests/assertions/truthy_falsey_test.lua`
    - `tests/assertions/extended_assertions_test.lua`
    - `tests/assertions/specialized_assertions_test.lua`
    - `tests/assertions/assertion_module_integration_test.lua`
    - *(List other relevant test files here)*
- **Helper Module:** `lib/tools/test_helper/knowledge.md` (Provides `expect_error`, `with_error_capture` used extensively in these tests).
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

When writing or reviewing tests in this directory (and using assertions elsewhere):
- **Use `expect` Style:** Strictly adhere to Firmo's `expect(value).to...` assertion syntax. Avoid older `assert.*` styles.
- **Prefer Specific Matchers:** Use the most specific matcher available for clarity (e.g., `.to.exist()` is clearer than `.to_not.equal(nil)`).
- **Boolean/Nil Checks:** Use `.to.be_truthy()` / `.to_not.be_truthy()` for boolean values and `.to.exist()` / `.to_not.exist()` for checking against `nil`.
- **Correct Order:** Ensure parameters are correct, especially for equality checks: `expect(actual).to.equal(expected)`.
- **Test Failure Messages:** When testing the assertion library itself, use `test_helper.expect_error` with a message pattern to verify that failed assertions produce the correct, informative error messages.
- **Edge Cases:** Include tests for edge cases like `nil` inputs, empty tables/strings, different numeric types, etc., for each matcher.

## Troubleshooting / Common Pitfalls (Optional)

- **Test Failures:** A failure in a test within this directory usually indicates a bug in the `lib/assertion` implementation (either the `expect` logic or a specific matcher).
- **Debugging:**
    1.  Identify the failing test case (`it` block) and the specific assertion within it.
    2.  Examine the error message provided by the failing assertion.
    3.  Step through or add logging to the corresponding matcher implementation in `lib/assertion/matchers/` or the core `expect.lua` logic to understand why the assertion produced the incorrect result or error message.
    4.  Verify the input values used in the test case are correct and represent the intended scenario.
