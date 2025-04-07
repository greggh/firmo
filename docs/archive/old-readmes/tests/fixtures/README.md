# Test Fixtures

This directory contains common test fixtures and utilities used across multiple test files in the firmo project.

## Directory Contents

- **common_errors.lua** - Common error scenarios for testing error handling
- **modules/** - Test modules used for module-related tests
  - **test_math.lua** - Math operations for testing module functionality

## Purpose

Test fixtures provide:

- Consistent test data across multiple test files
- Reusable test utilities and helpers
- Mock implementations for testing
- Sample code for coverage and instrumentation tests
- Example modules for testing module-related functionality

## Common Fixtures

The fixtures include various examples:

- **Function fixtures** - Functions with known behavior for testing
- **Error fixtures** - Code that generates specific errors
- **Module fixtures** - Modules with specific behaviors for testing
- **Data fixtures** - Test data structures with known properties

## Usage Patterns

Fixtures are used in tests like this:

```lua
local common_errors = require "tests.fixtures.common_errors"
local test_math = require "tests.fixtures.modules.test_math"

-- Using a common error fixture
it("should handle division by zero", function()
  expect(function()
    common_errors.divide_by_zero()
  end).to.fail()
end)

-- Using a module fixture
it("should calculate square root correctly", function()
  expect(test_math.sqrt(25)).to.equal(5)
end)
```

## Creating New Fixtures

When creating new fixtures:

- Place them in the appropriate subdirectory
- Document their purpose and behavior
- Make them reusable across multiple tests
- Keep them simple and focused
- Avoid external dependencies when possible

## Directory Structure

- **modules/** - Contains test modules for module-related tests
- **data/** - Contains test data structures (when added)
- **mocks/** - Contains mock implementations (when added)

See the [Testing Guide](/docs/coverage_repair/testing_guide.md) for more information on how to effectively use test fixtures.