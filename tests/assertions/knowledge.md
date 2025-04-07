# Assertions Knowledge

## Purpose
Test the assertion system that validates expected behaviors.

## Assertion Patterns
```lua
-- Basic assertions
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
expect(value).to.be_truthy()
expect(value).to.match("pattern")
expect(fn).to.fail()

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

## Standard Assertion Guidelines
- Use `.to.be_truthy()` instead of `.to.be(true)` for boolean checks
- Use `.to_not.be_truthy()` instead of `.to.be(false)` for boolean checks
- Use `.to.exist()` instead of `.to_not.be(nil)` for existence checks
- Use `.to_not.exist()` instead of `.to.be(nil)` for non-existence checks

## Error Testing Pattern
```lua
-- Testing for specific errors
it("handles validation errors", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return validate_input(nil)
  end)()
  
  expect(err).to.exist()
  expect(err.category).to.equal("VALIDATION")
  expect(err.message).to.match("invalid input")
end)

-- Testing error properties
it("provides error context", { expect_error = true }, function()
  local _, err = test_helper.with_error_capture(function()
    return process_data({invalid = true})
  end)()
  
  expect(err).to.exist()
  expect(err.context).to.be.a("table")
  expect(err.context.provided_data).to.exist()
end)
```

## Critical Rules
- Use expect-style assertions
- Always test error cases
- Verify error properties
- Clean up resources
- Document assertions

## Best Practices
- One assertion per test
- Clear error messages
- Test edge cases
- Document patterns
- Handle cleanup
- Use helper functions
- Keep focused
- Test thoroughly

## Common Mistakes
```lua
-- WRONG:
assert.is_not_nil(value)         -- busted-style
assert.equals(expected, actual)  -- wrong parameter order
expect(value).not_to.equal(x)    -- wrong negation syntax

-- CORRECT:
expect(value).to.exist()         -- firmo-style
expect(actual).to.equal(expected)  -- correct order
expect(value).to_not.equal(x)    -- correct negation
```