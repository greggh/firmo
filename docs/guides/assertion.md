# Assertion Module Usage Guide

## Introduction

The assertion module provides a comprehensive system for making assertions in tests using an expect-style syntax. It features a rich set of chainable assertions, deep equality comparisons, and structured error reporting, all in a standalone module that avoids circular dependencies.

## Key Concepts

### Expect-Style Assertions

The assertion module uses an expect-style syntax, which reads naturally from left to right:

```lua
expect(actual_value).to.equal(expected_value)
```

This syntax follows the intuitive pattern of "expect what you have to equal what you want" and is designed to make tests more readable and maintainable.

### Chainable API

The assertion module provides a chainable API that allows you to express complex assertions in a natural, fluent manner:

```lua
expect(user)
  .to.exist()                 -- Check the user exists
  .to.be.a("table")           -- Check it's a table
  .to.have_property("name")   -- Check it has a name property
```

### Assertion Negation

To negate assertions, use the `to_not` property instead of `to`:

```lua
expect(value).to_not.equal(other_value)
expect(value).to_not.be_truthy()
```

### Structured Error Reporting

When an assertion fails, the module provides detailed error messages that make it clear what went wrong:

```text
Values are not equal:
Expected: { id = 1, name = "John" }
Got:      { id = 1, name = "Jane" }
Different value for key name:
  Expected: "John"
  Got:      "Jane"
```

## Basic Usage

### Importing the Module

```lua
local assertion = require("lib.assertion")
-- Or if used within firmo tests:
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
```

### Making Simple Assertions

```lua
-- Basic equality check
assertion.expect(1 + 1).to.equal(2)
-- Type checking
assertion.expect("hello").to.be.a("string")
-- Existence check
assertion.expect(user).to.exist()
-- Truthiness check
assertion.expect(is_valid).to.be_truthy()
```

### Testing Collections

```lua
-- Check array length
assertion.expect({"a", "b", "c"}).to.have_length(3)
-- Check if table has a key
assertion.expect({name = "John"}).to.have_property("name")
-- Check if table has a key with a specific value
assertion.expect({name = "John"}).to.have_property("name", "John")
-- Check if collection contains a value
assertion.expect({"a", "b", "c"}).to.contain("b")
```

### Testing Functions

```lua
-- Check if a function throws an error
assertion.expect(function() error("Bad input") end).to.fail()
-- Check if the error message matches a pattern
assertion.expect(function() error("Bad input") end).to.fail.with("Bad")
-- Test if a function changes a value
local obj = {count = 0}
assertion.expect(function() obj.count = obj.count + 1 end).to.change(function() return obj.count end)
-- Test if a function increases a value
assertion.expect(function() obj.count = obj.count + 1 end).to.increase(function() return obj.count end)
```

## Advanced Usage

### Object Schema Validation

The `match_schema` assertion provides a powerful way to validate object structures:

```lua
local user = {
  id = 123,
  name = "John",
  email = "john@example.com",
  active = true,
  created_at = "2023-05-01T12:34:56Z"
}
-- Validate types
assertion.expect(user).to.match_schema({
  id = "number",
  name = "string",
  email = "string",
  active = "boolean",
  created_at = "string"
})
-- Mix type checks and value checks
assertion.expect(user).to.match_schema({
  active = true,           -- Exact value match
  name = "string",         -- Type check
  email = "string"         -- Type check
})
```

### Date Assertions

Test date strings with specialized date assertions:

```lua
-- Basic date validation
assertion.expect("2023-05-01").to.be_date()
-- ISO date validation
assertion.expect("2023-05-01T12:34:56Z").to.be_iso_date()
-- Date comparison
assertion.expect("2023-01-01").to.be_after("2022-12-31")
assertion.expect("2022-12-31").to.be_before("2023-01-01")
assertion.expect("2023-01-01T10:00:00Z").to.be_same_day_as("2023-01-01T15:30:00Z")
```

### Advanced Pattern Matching

For more complex pattern matching needs, the assertion module provides several enhanced matching methods:

```lua
-- Using match_with_options for case-insensitive matching
expect("Hello World").to.match_with_options("hello", { case_insensitive = true })

-- Match the entire string with match.fully
expect("abc123").to.match.fully("%a+%d+") -- Matches
expect("abc123def").to_not.match.fully("%a+%d+") -- Fails, needs to match entire string

-- Match any of multiple patterns with match.any_of
expect("123").to.match.any_of({ "%a+", "%d+", "%p+" })
expect("abc123").to_not.match.any_of({ "%a+$", "%p+$" })

-- Match all of multiple patterns with match.all_of
expect("Password123!").to.match.all_of({ "%a", "%d", "%p" })
expect("abc").to_not.match.all_of({ "%a", "%d" })
```

### Date Assertions

Test date strings with specialized date assertions:

```lua
-- Basic date validation
assertion.expect("2023-05-01").to.be_date()
-- ISO date validation
assertion.expect("2023-05-01T12:34:56Z").to.be_iso_date()
-- Date comparison
assertion.expect("2023-01-01").to.be_after("2022-12-31")
assertion.expect("2022-12-31").to.be_before("2023-01-01")
-- Check if dates represent the same calendar day
assertion.expect("2023-01-01T10:00:00Z").to.be_same_day_as("2023-01-01T15:30:00Z")
-- Check if a date is within a range
assertion.expect("2023-05-15").to.be_between_dates("2023-05-01", "2023-05-31")
assertion.expect("2023-05-01").to.be_between_dates("2023-05-01", "2023-05-31", true) -- Inclusive by default
```

### Async Assertions

When testing asynchronous code within an async context:

```lua
local async = require("lib.async")
async.test(function()
  -- Test if an async function completes
  assertion.expect(function(resolve)
    async.set_timeout(function() resolve("done") end, 10)
  end).to.complete()

  -- Test if it completes within a time limit
  assertion.expect(function(resolve)
    async.set_timeout(function() resolve("done") end, 10)
  end).to.complete_within(50)

  -- Test the resolved value
  assertion.expect(function(resolve)
    async.set_timeout(function() resolve("expected result") end, 10)
  end).to.resolve_with("expected result")

  -- Test rejection
  assertion.expect(function(_, reject)
    async.set_timeout(function() reject("error message") end, 10)
  end).to.reject("error")
end)
```

### Custom Assertions

You can extend the assertion module with custom assertions:

```lua
-- Add a custom assertion for even numbers
assertion.paths.to.be_even = {
  test = function(v)
    if type(v) ~= "number" then
      error("Expected a number, got " .. type(v))
    end

    return v % 2 == 0,
      "expected " .. tostring(v) .. " to be even",
      "expected " .. tostring(v) .. " to not be even"
  end
}
-- Now you can use it
assertion.expect(4).to.be_even()
assertion.expect(5).to_not.be_even()
```

## Best Practices

### 1. Use the Right Assertion for the Job

Choose assertions that best express your intent:

```lua
-- GOOD: Clear intent, specific error message
expect(value).to.be.a("string")
-- BAD: Works but less clear, generic error message 
expect(type(value) == "string").to.be_truthy()
```

### 2. Check for Existence Before Checking Properties

When dealing with potentially nil values, check for existence first:

```lua
-- GOOD: Graceful handling of nil
expect(result).to.exist()
if result then
  expect(result.status).to.equal("success")
end
-- BAD: Will error if result is nil
expect(result.status).to.equal("success")
```

### 3. Use Descriptive Variable Names in Tests

Make your tests more readable with descriptive variable names:

```lua
-- GOOD: Clear what's being tested
local actual_count = calculate_total(items)
expect(actual_count).to.equal(expected_count)
-- BAD: Generic names don't convey meaning
local a = calculate_total(items)
expect(a).to.equal(b)
```

### 4. Group Related Assertions

Group related assertions to make test intent clear:

```lua
-- Testing a user object
expect(user).to.be.a("table")
expect(user.id).to.be.a("number")
expect(user.name).to.be.a("string")
expect(user.email).to.match("%w+@%w+%.%w+")
```

### 5. Use match_schema for Complex Object Validation

For complex objects, use schema validation instead of multiple separate assertions:

```lua
-- GOOD: Concise schema validation
expect(user).to.match_schema({
  id = "number",
  name = "string",
  email = "string",
  active = "boolean"
})
-- LESS GOOD: Multiple separate assertions
expect(user.id).to.be.a("number")
expect(user.name).to.be.a("string")
expect(user.email).to.be.a("string")
expect(user.active).to.be.a("boolean")
```

### 6. Testing Error Conditions

Use the standardized error testing pattern with `expect_error` flag:

```lua
-- Import the test helper
local test_helper = require("lib.tools.test_helper")
-- Test for errors with the expect_error flag
it("should handle invalid input", { expect_error = true }, function()
  -- Use with_error_capture to safely call functions that may throw errors
  local result, err = test_helper.with_error_capture(function()
    return function_that_should_error()
  end)()
  -- Make assertions about the error
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("expected pattern")
end)
```

### 7. Avoid Brittle Assertions

Focus assertions on behavior, not implementation details:

```lua
-- GOOD: Tests the behavior
expect(calculator.add(2, 3)).to.equal(5)
-- BAD: Tests implementation details
expect(calculator.internal_sum_buffer).to.equal(5)
```

## Common Mistakes and How to Avoid Them

### Incorrect Negation Syntax

```lua
-- WRONG: "not_to" is not valid
expect(value).not_to.equal(other_value)
-- CORRECT: Use "to_not" instead
expect(value).to_not.equal(other_value)
```

### Incorrect Member Access Syntax

```lua
-- WRONG: "to_be" is not a valid method
expect(value).to_be(true)
-- CORRECT: Use "to.be" instead
expect(value).to.be(true)
```

### Inconsistent Parameter Order

```lua
-- WRONG: Parameters reversed
expect(expected_value).to.equal(actual_value)
-- CORRECT: First what you have, then what you expect
expect(actual_value).to.equal(expected_value)
```

### Forgetting to Check for Existence First

```lua
-- WRONG: Will error if value is nil
expect(value.property).to.equal("expected")
-- CORRECT: Check existence first
expect(value).to.exist()
if value then
  expect(value.property).to.equal("expected")
end
```

### Using the Wrong Assertion Type

```lua
-- WRONG: Using truthiness for equality
expect(value == expected).to.be_truthy()
-- CORRECT: Use equality assertion
expect(value).to.equal(expected)
```

## Error Handling

### Structured Error Objects

The assertion module integrates with the error_handler module to provide structured error objects:

```lua
{
  message = "expected 5 to equal 6",
  category = "VALIDATION",
  severity = "ERROR",
  context = {
    expected = 6,
    actual = 5,
    action = "equal",
    negate = false
  }
}
```

### Custom Error Messages

You can provide better context by creating custom errors with more information:

```lua
if not is_valid then
  local err = error_handler.validation_error(
    "Invalid user data",
    {
      details = "Name cannot be empty",
      field = "name",
      value = user.name
    }
  )
  error(error_handler.format_error(err))
end
```

## Integration with firmo

The standalone assertion module is seamlessly integrated with firmo:

```lua
-- Import firmo
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
-- The expect function is the same as assertion.expect
describe("Calculator", function()
  it("should add numbers correctly", function()
    expect(1 + 1).to.equal(2)
  end)

  it("should handle negative numbers", function()
    expect(-1 + (-1)).to.equal(-2)
  end)
end)
```

## Conclusion

The assertion module provides a powerful, flexible system for making assertions in tests. By using the expect-style syntax and chainable API, you can write tests that are both expressive and maintainable.
For a complete reference of all available assertions, see the [Assertion Module API Reference](/docs/api/assertion.md).
For practical examples, see the [Assertion Examples](/examples/assertion_examples.md).
