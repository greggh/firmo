# Test Runner Guide

This guide explains how to use the firmo test runner to discover, execute, and monitor tests in your Lua projects.

## Why Use the Firmo Test Runner

Firmo's test runner provides a comprehensive solution for test execution with features like:

1. **Automatic Discovery**: Automatically find and run tests based on patterns
2. **Watch Mode**: Continuously execute tests when files change
3. **Code Coverage**: Track which lines of code are executed during tests
4. **Quality Validation**: Analyze test quality and completeness
5. **Flexibility**: Run specific tests or entire test suites
6. **Parallel Execution**: Run tests in parallel for faster execution

This streamlined approach saves time and ensures consistent test execution across different environments.

## Basic Usage

### Running a Single Test File

To run a single test file:

```bash
lua test.lua path/to/test_file.lua
```

This command executes the specified test file and reports the results.

### Running All Tests in a Directory

To run all test files in a directory:

```bash
lua test.lua path/to/test/directory
```

By default, this will execute all files matching the `*_test.lua` pattern in the specified directory.

### Running Tests with Pattern Matching

To run only tests matching a specific pattern:

```bash
lua test.lua --pattern="*_unit_test.lua" tests/
```

This runs only files that match the specified pattern.

## Testing Modes

### Standard Run Mode

The standard run mode executes tests once and exits with a status code indicating success or failure:

```bash
lua test.lua tests/
```

### Watch Mode

Watch mode continuously monitors your project files and automatically reruns tests when changes are detected:

```bash
lua test.lua --watch tests/
```

In watch mode:
- Tests are run immediately when you start
- Any changes to source files trigger test reruns
- The program continues running until you press Ctrl+C

This creates a tight feedback loop during development.

## Common Test Runner Options

### Coverage Tracking

Enable code coverage tracking to see which lines of code are executed during your tests:

```bash
lua test.lua --coverage tests/
```

This generates coverage reports that help identify untested code.

### Verbose Output

For more detailed test output:

```bash
lua test.lua --verbose tests/
```

This shows additional information about each test case, including execution time and details about passed tests.

### Custom Report Directory

Specify where to save test reports:

```bash
lua test.lua --coverage --report-dir=my-reports tests/
```

### Quality Validation

Enable quality validation to analyze test completeness:

```bash
lua test.lua --quality --quality-level=3 tests/
```

Quality levels range from 1 (basic) to 5 (strict), with higher levels enforcing more comprehensive testing.

### Parallel Execution

Run tests in parallel for faster execution:

```bash
lua test.lua --parallel tests/
```

Note that parallel execution requires test isolation to be effective.

## Advanced Usage Patterns

### Running Specific Test Files

Run a subset of test files by specifying multiple paths:

```bash
lua test.lua tests/unit/module1_test.lua tests/unit/module2_test.lua
```

### Filtering Tests by Name

Run only tests matching a specific filter:

```bash
lua test.lua --filter="should handle invalid input" tests/
```

This runs only test cases whose descriptions match the filter.

### Using Tags to Organize Tests

Tags can be used to categorize tests and run specific subsets:

```bash
lua test.lua --tags="unit,fast" tests/
```

This runs only tests tagged with "unit" and "fast".

### Customizing Test Timeout

Set a custom timeout for tests:

```bash
lua test.lua --timeout=10000 tests/
```

This sets a 10-second timeout for each test file.

## Watch Mode in Depth

Watch mode is particularly useful during development as it provides immediate feedback when you change your code.

### How Watch Mode Works

1. The test runner starts by executing all relevant tests
2. It monitors your source files for changes
3. When changes are detected, it automatically reruns the affected tests
4. This cycle continues until you terminate the process

### Configuring Watch Mode

You can customize watch mode behavior:

```bash
lua test.lua --watch --watch-interval=0.5 --watch-dir=src --watch-dir=lib tests/
```

This configures watch mode to:
- Check for changes every 0.5 seconds
- Watch the "src" and "lib" directories for changes
- Run tests in the "tests" directory when changes occur

### Excluding Files from Watch

You can exclude certain files or directories from being watched:

```bash
lua test.lua --watch --exclude="%.git" --exclude="node_modules" tests/
```

This prevents unnecessary test reruns when files in git metadata or node_modules change.

## Integrating with Coverage Tracking

Code coverage tracking identifies which parts of your code are executed during tests:

### Basic Coverage

Enable basic coverage tracking:

```bash
lua test.lua --coverage tests/
```

This tracks which lines of code are executed and generates reports.

### Coverage Options

You can customize coverage tracking behavior:

```bash
lua test.lua --coverage --coverage-debug --discover-uncovered tests/
```

This enables:
- Coverage tracking
- Detailed debug output about coverage
- Discovery of files that aren't executed during tests

### Understanding Coverage Reports

Coverage reports typically include:
- Overall coverage percentage
- Line coverage (which lines were executed)
- Function coverage (which functions were called)
- File coverage (which files were loaded)

### Interpreting Coverage Colors

In HTML coverage reports:
- **Green**: Line is covered by tests (executed and verified by assertions)
- **Orange**: Line is executed but not verified by assertions
- **Red**: Line is not executed at all

## Understanding Test Results

The test runner provides a summary of test results:

```
Test Results:
- Passes:  42
- Failures: 2
- Skipped:  3
- Total:    47
There were test failures!
```

### Exit Codes

The test runner sets the process exit code based on results:
- **0**: All tests passed
- **1**: One or more tests failed or an error occurred

This is useful for CI/CD integration.

## Common Patterns and Best Practices

### Pattern: Test Suite Organization

Organize your tests in a structured directory hierarchy:

```
tests/
├── unit/              # Fast, isolated unit tests
│   ├── module1_test.lua
│   └── module2_test.lua
├── integration/       # Tests that interact with external systems
│   └── database_test.lua
└── performance/       # Performance benchmarks
    └── benchmark_test.lua
```

Then run specific test categories as needed:

```bash
# Run just unit tests
lua test.lua tests/unit/

# Run integration tests with coverage
lua test.lua --coverage tests/integration/

# Run performance tests with specific options
lua test.lua --timeout=30000 tests/performance/
```

### Pattern: Test Setup and Teardown

Use the test runner with beforeEach/afterEach hooks to ensure proper test isolation:

```lua
describe("Database tests", function()
  local db
  
  before_each(function()
    -- Create a fresh database connection for each test
    db = firmo.reset_module("app.database")
    db.connect({in_memory = true})
  end)
  
  after_each(function()
    -- Clean up after each test
    db.disconnect()
  end)
  
  it("creates a record", function()
    -- Test database creation
    expect(db.create({id = 1, name = "Test"})).to.be_truthy()
  end)
  
  it("reads a record", function()
    -- Test database reading
    db.create({id = 1, name = "Test"})
    local record = db.get(1)
    expect(record.name).to.equal("Test")
  end)
end)
```

### Pattern: Environment-specific Testing

Create environment-specific test configurations:

```bash
# Development environment tests
lua test.lua --tags="dev" tests/

# Production environment tests
lua test.lua --tags="prod" tests/

# CI environment tests
lua test.lua --tags="ci" --coverage --report-dir=reports tests/
```

### Best Practice: Test-Driven Development (TDD) with Watch Mode

1. Write a failing test
2. Start watch mode: `lua test.lua --watch tests/`
3. Implement the code until the test passes
4. Refactor while keeping tests green
5. Repeat for the next feature

Watch mode provides immediate feedback during this cycle.

### Best Practice: Coverage-driven Testing

1. Run tests with coverage: `lua test.lua --coverage tests/`
2. Identify untested code paths in the coverage report
3. Write tests for those paths
4. Rerun with coverage to confirm improvement
5. Repeat until desired coverage level is achieved

### Best Practice: CI Integration

In your CI pipeline, run tests with comprehensive validation:

```bash
lua test.lua --coverage --quality --parallel tests/
```

Set up the CI to fail if tests fail or coverage falls below a threshold.

## Troubleshooting

### Common Issues and Solutions

#### Tests Not Being Discovered

**Problem**: Your tests aren't being found by the runner.

**Solutions**:
- Ensure test files match the expected pattern (default: `*_test.lua`)
- Check that you're specifying the correct directory
- Use `--pattern` to customize the file pattern

#### Slow Test Execution

**Problem**: Tests take too long to run.

**Solutions**:
- Use `--parallel` to run tests in parallel
- Run only specific test categories when developing
- Profile your tests to identify slow tests
- Use watch mode to only run affected tests

#### Inconsistent Test Results

**Problem**: Tests pass sometimes and fail other times.

**Solutions**:
- Ensure proper test isolation
- Use `firmo.reset_module` to reset module state between tests
- Check for test interference through global state
- Look for timing issues in asynchronous tests

#### Coverage Reports Show Unexpected Results

**Problem**: Coverage reports don't match your expectations.

**Solutions**:
- Verify that you're running all relevant tests
- Check for excluded files in your coverage configuration
- Ensure that your tests exercise all code paths
- Use `--coverage-debug` for more detailed coverage information

## Examples

### Basic Command-Line Examples

```bash
# Run all tests
lua test.lua tests/

# Run a specific test file
lua test.lua tests/unit/module_test.lua

# Run with coverage
lua test.lua --coverage tests/

# Run with custom pattern
lua test.lua --pattern="*_spec.lua" tests/

# Run in watch mode
lua test.lua --watch tests/

# Run with multiple options
lua test.lua --coverage --verbose --report-dir=reports tests/
```

### Example: Makefile Integration

```makefile
.PHONY: test test-unit test-integration test-coverage

test:
	lua test.lua tests/

test-unit:
	lua test.lua tests/unit/

test-integration:
	lua test.lua tests/integration/

test-coverage:
	lua test.lua --coverage --report-dir=coverage-reports tests/

test-watch:
	lua test.lua --watch tests/

ci-test:
	lua test.lua --coverage --parallel --report-dir=reports tests/
```

### Example: Custom Test Runner

For specialized needs, you can create a custom test runner:

```lua
-- custom_runner.lua
local firmo = require("firmo")
local runner = require("scripts.runner")

-- Custom configuration
local path = "tests/"
local options = {
  coverage = true,
  verbose = true,
  report_dir = "custom-reports",
  pattern = "*_test.lua"
}

-- Initialize modules
local module_reset = require("lib.core.module_reset")
module_reset.register_with_firmo(firmo)
module_reset.configure({ reset_modules = true })

-- Run tests
return runner.run_all(path, firmo, options)
```

You can then run this custom runner:

```bash
lua custom_runner.lua
```

## Summary

The firmo test runner provides a powerful and flexible system for test execution, with features like automatic discovery, watch mode, coverage tracking, and quality validation. By understanding and utilizing these features, you can create an efficient testing workflow that improves code quality and development speed.

For more information, refer to:

- [Test Runner API Reference](../api/test_runner.md): Complete technical documentation
- [Test Runner Examples](../../examples/test_runner_examples.md): Detailed code examples
- [CLI Documentation](../api/cli.md): Command-line interface details