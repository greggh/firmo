# Firmo Tests

This directory contains the test suite for the firmo testing framework. The tests are organized by component to improve maintainability and navigability.

## Directory Structure

- **assertions/** - Tests for the assertion system
- **async/** - Tests for asynchronous testing functionality
- **core/** - Tests for core framework components
- **coverage/** - Tests for code coverage tracking
  - **hooks/** - Tests for debug hook functionality
  - **instrumentation/** - Tests for code instrumentation
- **discovery/** - Tests for test file discovery
- **fixtures/** - Common test fixtures and utilities
- **integration/** - Cross-component integration tests
- **mocking/** - Tests for the mocking system
- **parallel/** - Tests for parallel execution functionality
- **performance/** - Tests for performance benchmarking
- **quality/** - Tests for test quality validation
- **reporting/** - Tests for result and coverage reporting
  - **formatters/** - Tests for specific formatters
- **tools/** - Tests for utility modules
  - **filesystem/** - Tests for filesystem operations
  - **logging/** - Tests for logging system
  - **watcher/** - Tests for file watching system

## Running Tests

All tests can be run using the standard test.lua entry point:

```
# Run all tests
lua test.lua tests/

# Run tests in a specific component
lua test.lua tests/core/

# Run a specific test file
lua test.lua tests/core/config_test.lua

# Run tests with specific options
lua test.lua --coverage --verbose tests/
```

## Test Naming Conventions

- Test files should be named descriptively with a `_test.lua` suffix
- Test file names should indicate the component being tested
- Integration tests should indicate the components being integrated
- Performance tests should include `_performance` in the name when focusing on performance aspects

## Test File Organization

Test files should follow this general structure:

1. Module imports
2. Local test utilities (if needed)
3. Describe blocks for logical grouping
4. Individual test cases using `it` blocks
5. Any cleanup code (if needed)

Example:
```lua
local firmo = require "firmo"
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Module name", function()
  describe("Function name", function()
    it("should do something specific", function()
      expect(something).to.equal(expected)
    end)
  end)
end)
```

## Test Guidelines

- Each test should focus on a single behavior or feature
- Tests should be isolated and not depend on other tests
- Use appropriate assertion methods following the firmo style guide
- Prefer `.to.be_truthy()` over `.to.be(true)` for boolean assertions
- Use `.to.exist()` instead of `.to_not.be(nil)` for existence checks
- Always clean up resources created during tests
- Avoid external dependencies when possible
- Use mocks and stubs to isolate the code being tested
- Add comments when test logic is complex or non-obvious

See the [Testing Guide](/docs/coverage_repair/testing_guide.md) for more detailed information.