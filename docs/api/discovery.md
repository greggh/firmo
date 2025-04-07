# Test Discovery API
This document describes the test discovery capabilities provided by Firmo.

## Overview
Firmo provides automatic test discovery functionality that finds and runs test files without requiring you to manually list all test files. This is particularly useful for larger projects with many test files.

## Discovery Functions

### firmo.discover(root_dir, pattern)
Finds test files matching the specified pattern in the given directory.
**Parameters:**

- `root_dir` (string, optional): Directory to search for test files. Defaults to "."
- `pattern` (string, optional): File pattern to match. Defaults to "**/*_test.lua"
**Returns:**

- A table of paths to discovered test files
**Example:**

```lua
-- Find all test files in the current directory
local test_files = firmo.discover()
-- Find test files in a specific directory
local test_files = firmo.discover("./src/tests")
-- Find files with a specific pattern
local test_files = firmo.discover("./tests", "*_spec.lua")

```

### firmo.run_discovered(root_dir, pattern, options)
Discovers and runs test files matching the specified pattern in the given directory.
**Parameters:**

- `root_dir` (string, optional): Directory to search for test files. Defaults to "./tests"
- `pattern` (string, optional): File pattern to match. Defaults to "**/*_test.lua"
- `options` (table, optional): Options for test execution, including:
  - `tags` (table|string): Tags to filter by
  - `filter` (string): Pattern to filter test names by
**Returns:**

- A table with test results, including:
  - `total_files` (number): Total number of test files found
  - `passed_files` (number): Number of files with all tests passing
  - `failed_files` (number): Number of files with at least one failure
  - `total_tests` (number): Total number of tests run
  - `passed_tests` (number): Number of passing tests
  - `failed_tests` (number): Number of failing tests
  - `skipped_tests` (number): Number of skipped tests
  - `failures` (table): List of test failures
**Example:**

```lua
-- Run all discovered tests in the default directory
local results = firmo.run_discovered()
-- Run tests in a specific directory
local results = firmo.run_discovered("./src/tests")
-- Run tests with filtering options
local results = firmo.run_discovered("./tests", "*_test.lua", {
  tags = {"unit", "fast"},
  filter = "validation"
})
-- Check results
print("Passed: " .. results.passed_tests .. "/" .. results.total_tests)

```

### firmo.run_file(file_path)
Runs a single test file.
**Parameters:**

- `file_path` (string): Path to the test file to run
**Returns:**

- A table with test results, including:
  - `success` (boolean): Whether the file loaded without errors
  - `error` (string): Error message if file failed to load
  - `passes` (number): Number of passing tests
  - `errors` (number): Number of failing tests
  - `skipped` (number): Number of skipped tests
**Example:**

```lua
-- Run a specific test file
local result = firmo.run_file("./tests/user_test.lua")
-- Check results
if result.success then
  print("File ran successfully with " .. result.passes .. " passes and " .. result.errors .. " failures")
else
  print("Failed to load file: " .. result.error)
end

```

### firmo.cli_run(dir, options)
Command-line runner that finds and runs tests. This is primarily used internally when Firmo is invoked from the command line.
**Parameters:**

- `dir` (string, optional): Directory to search for test files. Defaults to "./tests"
- `options` (table, optional): Options for test execution, including:
  - `tags` (table|string): Tags to filter by
  - `filter` (string): Pattern to filter test names by
**Returns:**

- `true` if all tests passed, `false` otherwise
**Example:**

```lua
-- Run all tests from the command line
local success = firmo.cli_run()
-- Run with custom options
local success = firmo.cli_run("./tests", {
  tags = {"unit"},
  filter = "user"
})
-- Use exit code for CI systems
os.exit(success and 0 or 1)

```

## Command Line Usage
Firmo can be run directly from the command line to discover and run tests.

```bash

# Run all tests in the ./tests directory
lua test.lua tests/

# Run tests in a specific directory
lua test.lua src/tests/

# Run a specific test file
lua test.lua ./tests/user_test.lua

# Run tests with tag filtering
lua test.lua tests/ --tags unit

# Run tests with multiple tags
lua test.lua tests/ --tags unit,fast

# Run tests with name filtering
lua test.lua tests/ --filter validation

# Run tests with both tag and name filtering
lua test.lua tests/ --tags unit --filter validation

# Show help
lua test.lua --help

```

## Test File Naming Conventions
By default, Firmo looks for files matching the pattern `*_test.lua`. This is a common convention in many testing frameworks.
Some common naming conventions include:

- `module_test.lua`: Tests for a module named `module.lua`
- `test_module.lua`: Alternative naming style for tests
- `module_spec.lua`: Specification-style tests
You can customize the pattern when calling `discover` or `run_discovered` to match your preferred naming convention.

## Examples

### Basic Test Discovery

```lua
local firmo = require("firmo")
-- Find all test files and run them
local results = firmo.run_discovered()
-- Print summary
print("Files: " .. results.passed_files .. "/" .. results.total_files .. " passed")
print("Tests: " .. results.passed_tests .. "/" .. results.total_tests .. " passed")

```

### Custom Discovery Pattern

```lua
local firmo = require("firmo")
-- Find and run tests that match a specific pattern
local results = firmo.run_discovered("./specs", "*_spec.lua")
-- Print summary
print("Found " .. results.total_files .. " spec files")
print("Ran " .. results.total_tests .. " specs")

```

### Dynamic Test Directory

```lua
local firmo = require("firmo")
-- Determine test directory based on environment
local env = os.getenv("TEST_ENV") or "development"
local test_dir = "./tests"
if env == "integration" then
  test_dir = "./integration_tests"
elseif env == "system" then
  test_dir = "./system_tests"
end
-- Run tests in the appropriate directory
local results = firmo.run_discovered(test_dir)

```

### Conditional CLI Execution

```lua
local firmo = require("firmo")
-- Only run CLI runner when script is executed directly
local is_main = arg and arg[0]:match("run_tests.lua$")
if is_main then
  -- Parse command-line args
  local dir = "./tests"
  local options = {}
  -- Process args
  for i = 1, #arg do
    if arg[i] == "--dir" and arg[i+1] then
      dir = arg[i+1]
      i = i + 1
    elseif arg[i] == "--tags" and arg[i+1] then
      options.tags = {}
      for tag in arg[i+1]:gmatch("[^,]+") do
        table.insert(options.tags, tag)
      end
      i = i + 1
    elseif arg[i] == "--filter" and arg[i+1] then
      options.filter = arg[i+1]
      i = i + 1
    end
  end
  -- Run tests and exit with appropriate status code
  local success = firmo.cli_run(dir, options)
  os.exit(success and 0 or 1)
end

```

## Best Practices

1. **Consistent naming**: Use a consistent naming convention for your test files (e.g., `*_test.lua`) to make discovery reliable.
1. **Organized directory structure**: Group related test files in directories that mirror your source code structure.
1. **Test file per module**: Create one test file per source file or module to keep tests focused and easier to maintain.
1. **Avoid side effects**: Test files should be self-contained and not have side effects that could affect other tests during discovery.
1. **Use filters wisely**: Combine test discovery with filtering to create targeted test runs for different scenarios.

