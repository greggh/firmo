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
lua firmo.lua path/to/test_file.lua
```

This command executes the specified test file and reports the results.

### Running All Tests in a Directory

To run all test files in a directory:

```bash
lua firmo.lua path/to/test/directory
```

By default, this will execute all files matching the `*_test.lua` pattern in the specified directory.

### Running Tests with Pattern Matching

To run only tests matching a specific pattern:

```bash
lua firmo.lua --pattern=*_unit_test.lua tests/
```

This runs only files that match the specified pattern.

## Testing Modes

### Standard Run Mode

The standard run mode executes tests once and exits with a status code indicating success or failure:

```bash
lua firmo.lua tests/
```

### Watch Mode

Watch mode continuously monitors your project files and automatically reruns tests when changes are detected:

```bash
lua firmo.lua --watch tests/
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
lua firmo.lua --coverage tests/
```

This generates coverage reports that help identify untested code.

### Verbose Output

For more detailed test output:

```bash
lua firmo.lua --verbose tests/
```

This shows additional information about each test case, including execution time and details about passed tests.

### Custom Report Directory

Specify where to save test reports:

```bash
lua firmo.lua --coverage --report-dir=my-reports tests/
```

### Quality Validation

Enable quality validation to analyze test completeness:

```bash
lua firmo.lua --quality --quality-level=3 tests/
```

Quality levels range from 1 (basic) to 5 (strict), with higher levels enforcing more comprehensive testing.

### Parallel Execution

Run tests in parallel for faster execution:

```bash
lua firmo.lua --parallel tests/
```

Note that parallel execution requires test isolation to be effective.

## Advanced Usage Patterns

### Running Specific Test Files

Run a subset of test files by specifying multiple paths:

```bash
lua firmo.lua tests/unit/module1_test.lua tests/unit/module2_test.lua
```

### Filtering Tests by Name

Run only tests matching a specific filter:

```bash
lua firmo.lua --filter="should handle invalid input" tests/
```

This runs only test cases whose descriptions match the filter.
## Using Tags (Programmatically)

Tags can be used to categorize tests (see [Filtering Guide](./filtering.md)), but filtering by tags is done programmatically, not via a dedicated `--tags` CLI flag.

```lua
-- In a setup script or custom runner:
local firmo = require("firmo")
firmo.only_tags("unit", "fast")
-- Then run tests: lua firmo.lua tests/
```
You might also achieve pseudo-tag filtering using the `--filter` flag if your tags are part of the test names.
This runs only tests tagged with "unit" and "fast".

### Customizing Test Timeout

Set a custom timeout for tests (primarily relevant for parallel execution, configured programmatically or via central config):

```lua
-- Programmatic configuration
local parallel = require("lib.tools.parallel")
parallel.configure({ timeout = 10 }) -- 10 seconds
```
There is no direct `--timeout` flag for the main runner script (`test.lua`).

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
lua firmo.lua --watch tests/
```

Watch mode behavior (directories, interval, exclusions) is configured programmatically or via central configuration, not directly via command-line flags like `--watch-interval`.

### Excluding Files from Watch

You can exclude certain files or directories from being watched:

```bash
lua firmo.lua --watch --exclude="%.git" --exclude="node_modules" tests/
```

This prevents unnecessary test reruns when files in git metadata or node_modules change.

## Integrating with Coverage Tracking

Code coverage tracking identifies which parts of your code are executed during tests:

### Basic Coverage

Enable basic coverage tracking:

```bash
lua firmo.lua --coverage tests/
```

This tracks which lines of code are executed and generates reports.

### Coverage Options

You can customize coverage tracking behavior:

```bash
lua firmo.lua --coverage --coverage-debug tests/
```

This enables:

- Coverage tracking
- Detailed debug output about coverage

(Note: `--discover-uncovered` is not an implemented flag).

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

```text
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

```text
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

lua firmo.lua tests/unit/

# Run integration tests with coverage

lua firmo.lua --coverage tests/integration/

# Run performance tests with specific options

lua firmo.lua --timeout=30000 tests/performance/
```

### Pattern: Test Setup and Teardown

Use the test runner with `before`/`after` hooks to ensure proper test isolation:

```lua
describe("Database tests", function()
  local db

  before(function()
    -- Create a fresh database connection for each test
    -- NOTE: Module reset uses require("lib.core.module_reset") system,
    -- often configured globally. This example focuses on setup/teardown.
    db = require("app.database") -- Placeholder
    db.connect({in_memory = true})
  end)

  after(function()
    -- Clean up after each test
    if db then db.disconnect() end
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

Create environment-specific test configurations, potentially using `--filter` or separate test directories/scripts:

```bash
# Development environment tests (filter by name)
lua firmo.lua --filter dev tests/

# Production environment tests (filter by name)
lua firmo.lua --filter prod tests/

# CI environment tests (using a different directory or config)
# Assumes unit tests are separated or tagged programmatically
lua firmo.lua tests/unit --coverage --report-dir=reports
```

### Best Practice: Test-Driven Development (TDD) with Watch Mode

1. Write a failing test
2. Start watch mode: `lua firmo.lua --watch tests/`
3. Implement the code until the test passes
4. Refactor while keeping tests green
5. Repeat for the next feature

Watch mode provides immediate feedback during this cycle.

### Best Practice: Coverage-driven Testing

1. Run tests with coverage: `lua firmo.lua --coverage tests/`
2. Identify untested code paths in the coverage report
3. Write tests for those paths
4. Rerun with coverage to confirm improvement
5. Repeat until desired coverage level is achieved

### Best Practice: CI Integration

In your CI pipeline, run tests with comprehensive validation:

```bash
lua firmo.lua --coverage --quality --parallel tests/
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

lua firmo.lua tests/

# Run a specific test file

lua firmo.lua tests/unit/module_test.lua

# Run with coverage

lua firmo.lua --coverage tests/

# Run with custom pattern

lua firmo.lua --pattern="*_spec.lua" tests/

# Run in watch mode

lua firmo.lua --watch tests/

# Run with multiple options

lua firmo.lua --coverage --verbose --report-dir=reports tests/
```

### Example: Makefile Integration

```makefile
.PHONY: test test-unit test-integration test-coverage
test:
	lua firmo.lua tests/
test-unit:
	lua firmo.lua tests/unit/
test-integration:
	lua firmo.lua tests/integration/
test-coverage:
	lua firmo.lua --coverage --report-dir=coverage-reports tests/
test-watch:
	lua firmo.lua --watch tests/
ci-test:
	lua firmo.lua --coverage --parallel --report-dir=reports tests/
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
