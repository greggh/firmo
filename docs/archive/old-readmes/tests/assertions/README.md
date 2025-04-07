# Assertion Tests

This directory contains tests for the firmo assertion system. Assertions are the foundation of the testing framework, allowing clear validation of expected behaviors.

## Directory Contents

- **assertions_test.lua** - Tests for basic assertion functionality and custom assertions
- **expect_assertions_test.lua** - Tests for the expect-style assertion chain
- **truthy_falsey_test.lua** - Tests for boolean and truthiness evaluation

## Assertion Patterns

The firmo framework uses expect-style assertions with chainable syntax:

```lua
expect(value).to.exist()
expect(value).to.be.a("string")
expect(value).to.equal(expected)
expect(value).to.be_truthy()
expect(value).to_not.equal(unexpected)
```

## Standard Assertion Guidelines

- Use `.to.be_truthy()` instead of `.to.be(true)` for boolean checks
- Use `.to_not.be_truthy()` instead of `.to.be(false)` for boolean checks
- Use `.to.exist()` instead of `.to_not.be(nil)` for existence checks
- Use `.to_not.exist()` instead of `.to.be(nil)` for non-existence checks

## Running Tests

To run all assertion tests:
```
lua test.lua tests/assertions/
```

To run a specific assertion test:
```
lua test.lua tests/assertions/assertions_test.lua
```

See the [Testing Guide](/docs/coverage_repair/testing_guide.md) for more information.