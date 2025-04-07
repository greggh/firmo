# Test Runner API Reference

This document provides a comprehensive reference for firmo's test runner system, which manages test discovery, execution, and reporting.

## Overview

The test runner system handles the end-to-end process of running tests, from discovering test files to executing tests and generating reports. It consists of multiple components:

1. **Main Test Entry Point** (`test.lua`): A simple redirector that serves as the primary entry point for running tests.
2. **Core Runner Module** (`lib/core/runner.lua`): The central logic for executing tests with configurable options.
3. **Runner Script** (`scripts/runner.lua`): A command-line interface that provides complete test execution functionality.

These components work together to provide a seamless experience for running tests individually or in batches, with various options such as coverage tracking, watching for file changes, and generating reports.

## Test Entry Point Functions

### Running Tests from Command Line

The main entry point for running tests is the `test.lua` file at the project root. This file forwards all arguments to the runner script and is invoked as follows:

```bash
lua test.lua [options] [path]
```

Any arguments passed to `test.lua` are forwarded to `scripts/runner.lua`, maintaining the same options and behavior.

## Core Runner API

The core runner module (`lib/core/runner.lua`) provides the following functions:

### runner.format(options)

Configures output formatting options for test result display.

**Parameters:**
- `options` (table): Formatting options
  - `use_color` (boolean, optional): Whether to use ANSI color codes in output
  - `indent_char` (string, optional): Character to use for indentation (tab or spaces)
  - `indent_size` (number, optional): How many indent_chars to use per level
  - `show_trace` (boolean, optional): Show stack traces for errors
  - `show_success_detail` (boolean, optional): Show details for successful tests
  - `compact` (boolean, optional): Use compact output format (less verbose)
  - `dot_mode` (boolean, optional): Use dot mode (. for pass, F for fail)
  - `summary_only` (boolean, optional): Show only summary, not individual tests

**Returns:**
- (TestRunner): The runner instance for method chaining

**Example:**
```lua
local runner = require("lib.core.runner")
runner.format({
  use_color = true,
  indent_char = "  ",  -- Two spaces for indentation
  indent_size = 1,
  show_trace = true,   -- Show stack traces for errors
  compact = false      -- Use detailed output
})
```

### runner.configure(options)

Configures the test runner with execution and feature options.

**Parameters:**
- `options` (table): Configuration options
  - `format` (table, optional): Output format options for test results
  - `parallel` (boolean, optional): Whether to run tests in parallel across processes
  - `coverage` (boolean, optional): Whether to track code coverage during test execution
  - `verbose` (boolean, optional): Whether to show verbose output including test details
  - `timeout` (number, optional): Timeout in milliseconds for test execution (default: 30000)
  - `cleanup_temp_files` (boolean, optional): Whether to clean up temporary files (defaults to true)

**Returns:**
- (TestRunner): The module instance for method chaining

**Example:**
```lua
runner.configure({
  coverage = true,
  parallel = true,
  timeout = 10000,  -- 10 second timeout per test file
  verbose = false   -- Reduce output noise in parallel mode
})
```

### runner.run_file(file)

Runs a single test file and collects test results.

**Parameters:**
- `file` (string): The absolute path to the test file to run

**Returns:**
- (table): Test execution results with counts
  - `success` (boolean): Whether all tests passed
  - `passes` (number): Number of passing tests
  - `errors` (number): Number of failing tests
  - `skipped` (number): Number of skipped tests
  - `file` (string): Path to the test file
- (table, optional): Error information if execution failed

**Example:**
```lua
local results, err = runner.run_file("/path/to/my_test.lua")
if err then
  print("Error running test file: " .. err.message)
  return false
end

if results.success then
  print("All tests passed: " .. results.passes .. " tests")
else
  print("Test failures: " .. results.errors .. " failed tests")
end
```

### runner.run_discovered(dir, pattern)

Runs all automatically discovered test files in a directory.

**Parameters:**
- `dir` (string, optional): Directory to search for test files (default: "tests")
- `pattern` (string, optional): Pattern to filter test files (default: "*_test.lua")

**Returns:**
- (boolean): Whether all discovered tests passed successfully
- (table, optional): Error information if discovery or execution failed

**Example:**
```lua
-- Run all tests in the default directory
local success = runner.run_discovered()
if success then
  print("All tests passed!")
end

-- Run tests in a specific directory
local success, err = runner.run_discovered("tests/unit")
if not success then
  if err then
    print("Error discovering or running tests: " .. err.message)
  else
    print("Some tests failed")
  end
end
```

### runner.run_tests(files, options)

Runs a list of test files with specified options.

**Parameters:**
- `files` (table): List of test file paths to run
- `options` (table, optional): Additional options for test execution
  - `parallel` (boolean, optional): Whether to run tests in parallel
  - `coverage` (boolean, optional): Whether to track code coverage
  - `verbose` (boolean, optional): Whether to show verbose output
  - `timeout` (number, optional): Timeout in milliseconds (default: 30000)

**Returns:**
- (boolean): Whether all tests passed successfully

**Example:**
```lua
local test_files = {
  "tests/unit/module1_test.lua",
  "tests/unit/module2_test.lua"
}

local all_passed = runner.run_tests(test_files, {
  parallel = true,
  coverage = true,
  timeout = 60000  -- 60 second timeout per file
})

if all_passed then
  print("All tests passed successfully")
else
  print("Some tests failed")
end
```

### runner.nocolor()

Disables colors in the output, useful for terminals that don't support ANSI color codes.

**Returns:**
- (TestRunner): The runner instance for method chaining

**Example:**
```lua
runner.nocolor().run_discovered("tests")
```

## Runner Script API

The runner script (`scripts/runner.lua`) provides the following functions:

### runner.run_file(file_path, firmo, options)

Runs a specific test file and returns structured results.

**Parameters:**
- `file_path` (string): The path to the test file to run
- `firmo` (table): The firmo module instance
- `options` (table, optional): Options for running the test
  - `verbose` (boolean, optional): Whether to show verbose output
  - `coverage` (boolean, optional): Whether to track code coverage
  - `json_output` (boolean, optional): Whether to output JSON results

**Returns:**
- (table): Test execution results with detailed information
  - `success` (boolean): Whether the file executed without errors
  - `error` (any): Any execution error that occurred
  - `passes` (number): Number of passing tests
  - `errors` (number): Number of failing tests
  - `skipped` (number): Number of skipped tests
  - `total` (number): Total number of tests
  - `elapsed` (number): Execution time in seconds
  - `file` (string): Path to the test file
  - `test_results` (table): Array of structured test results
  - `test_errors` (table): Array of test errors

**Example:**
```lua
local firmo = require("firmo")
local runner = require("scripts.runner")

local results = runner.run_file("tests/unit/module_test.lua", firmo, {
  verbose = true
})

print(string.format(
  "Executed %d tests: %d passed, %d failed, %d skipped",
  results.total,
  results.passes,
  results.errors,
  results.skipped
))
```

### runner.find_test_files(dir_path, options)

Finds test files in a directory based on specified options.

**Parameters:**
- `dir_path` (string): The path to the directory to search
- `options` (table, optional): Options for finding test files
  - `pattern` (string, optional): Pattern to match test files (default: "*.lua")
  - `filter` (string, optional): Filter to apply to found files
  - `exclude_patterns` (table, optional): Patterns to exclude from results

**Returns:**
- (table): Array of file paths matching the criteria

**Example:**
```lua
local runner = require("scripts.runner")
local files = runner.find_test_files("tests/unit", {
  pattern = "*_test.lua",
  exclude_patterns = { "fixtures/*" }
})

print("Found " .. #files .. " test files")
for _, file in ipairs(files) do
  print("- " .. file)
end
```

### runner.run_all(files_or_dir, firmo, options)

Runs tests in a directory or file list and aggregates results.

**Parameters:**
- `files_or_dir` (string|table): Either a directory path or array of file paths
- `firmo` (table): The firmo module instance
- `options` (table, optional): Options for running the tests
  - `verbose` (boolean, optional): Whether to show verbose output
  - `coverage` (boolean, optional): Whether to track code coverage
  - `pattern` (string, optional): Pattern to match test files
  - `filter` (string, optional): Filter to apply to found files
  - `quality` (boolean, optional): Whether to run quality validation
  - `quality_level` (number, optional): Quality validation level
  - `report_dir` (string, optional): Directory to save reports

**Returns:**
- (boolean): Whether all tests passed

**Example:**
```lua
local firmo = require("firmo")
local runner = require("scripts.runner")

-- Run all tests in a directory
local success = runner.run_all("tests", firmo, {
  coverage = true,
  verbose = true,
  report_dir = "reports"
})

if success then
  print("All tests passed")
else
  print("Some tests failed")
end
```

### runner.watch_mode(path, firmo, options)

Runs tests in watch mode, automatically rerunning tests when files change.

**Parameters:**
- `path` (string): The path to watch (file or directory)
- `firmo` (table): The firmo module instance
- `options` (table, optional): Options for watch mode
  - `exclude_patterns` (table, optional): Patterns to exclude from watching
  - `interval` (number, optional): Watch interval in seconds (default: 1.0)
  - `coverage` (boolean, optional): Whether to track code coverage
  - `verbose` (boolean, optional): Whether to show verbose output

**Returns:**
- (boolean): Whether the last test run was successful

**Example:**
```lua
local firmo = require("firmo")
local runner = require("scripts.runner")

-- Watch a directory
runner.watch_mode("tests/unit", firmo, {
  exclude_patterns = { "node_modules", "%.git" },
  interval = 0.5
})
```

### runner.parse_arguments(args)

Parses command-line arguments for test running options.

**Parameters:**
- `args` (table): Array of command-line arguments

**Returns:**
- (string): The path to run tests from
- (table): Options parsed from arguments

**Example:**
```lua
local runner = require("scripts.runner")
local path, options = runner.parse_arguments({
  "--coverage",
  "--verbose",
  "tests/unit"
})

print("Path: " .. path)
print("Coverage enabled: " .. tostring(options.coverage))
```

### runner.print_usage()

Prints the usage instructions for the runner script.

**Example:**
```lua
local runner = require("scripts.runner")
runner.print_usage()
```

### runner.main(args)

Main function to run tests from command line arguments.

**Parameters:**
- `args` (table): Array of command-line arguments

**Returns:**
- (boolean): Whether all tests passed

**Example:**
```lua
local runner = require("scripts.runner")
local success = runner.main({
  "--coverage",
  "--verbose",
  "tests/unit"
})

os.exit(success and 0 or 1)
```

## Integration with Other Modules

### Central Configuration Integration

The test runner integrates with the central configuration system to load options from `.firmo-config.lua`:

```lua
-- Example .firmo-config.lua
return {
  runner = {
    parallel = true,
    pattern = "*_test.lua",
    exclude_patterns = { "fixtures/*" }
  },
  coverage = {
    include = { "lib/**/*.lua" },
    exclude = { "tests/**/*.lua" },
    track_blocks = true
  }
}
```

### Coverage Integration

The test runner can automatically initialize and manage code coverage:

```lua
-- Run tests with coverage from command line
lua test.lua --coverage tests/

-- Or programmatically
local runner = require("lib.core.runner")
runner.configure({ coverage = true })
      .run_discovered("tests")
```

### Module Reset Integration

The test runner automatically uses module_reset if available to ensure test isolation:

```lua
-- This happens automatically, but can be configured:
local module_reset = require("lib.core.module_reset")
module_reset.register_with_firmo(firmo)
module_reset.configure({
  reset_modules = true,
  verbose = options.verbose
})
```

## Error Handling

The test runner includes comprehensive error handling for various scenarios:

1. **File not found errors**: When specified test files don't exist
2. **Test execution errors**: When a test file has syntax errors or runtime errors
3. **Coverage initialization errors**: When coverage tracking fails to initialize
4. **Report generation errors**: When generating reports fails

All errors are handled with proper error objects containing detailed context information, and errors are logged with the logging system for easier debugging.

## Command Line Interface

The test runner can be invoked from the command line with various options:

```bash
lua test.lua [options] [path]
```

Where `[options]` can include:

- `--coverage`, `-c`: Enable coverage tracking
- `--verbose`, `-v`: Show verbose output
- `--pattern=<pattern>`: Only run test files matching pattern
- `--filter=<filter>`: Only run tests matching filter
- `--watch`, `-w`: Enable watch mode for continuous testing
- `--report-dir=<path>`: Save reports to specified directory
- `--quality`, `-q`: Enable quality validation
- `--quality-level=<n>`: Set quality validation level (1-5)
- `--memory`, `-m`: Track memory usage
- `--performance`, `-p`: Show performance metrics
- `--help`, `-h`: Show help message

And `[path]` can be a file or directory path.

## Examples

### Basic Test Running

```lua
local runner = require("lib.core.runner")

-- Run a specific test file
runner.run_file("tests/unit/module_test.lua")

-- Run all tests in a directory
runner.run_discovered("tests/unit")

-- Run tests with a specific pattern
runner.run_discovered("tests", "*_unit_test.lua")

-- Run tests with custom options
runner.configure({
  coverage = true,
  verbose = true,
  timeout = 5000
}).run_tests({
  "tests/unit/module1_test.lua",
  "tests/unit/module2_test.lua"
})
```

### Creating a Custom Test Runner

```lua
local firmo = require("firmo")
local runner = require("scripts.runner")

-- Parse command line arguments
local args = {...} -- script arguments
local path, options = runner.parse_arguments(args)

-- Run tests with custom handling
if options.watch then
  -- Watch mode with custom settings
  runner.watch_mode(path, firmo, {
    interval = 0.5,
    exclude_patterns = { "%.git", "node_modules" },
    coverage = options.coverage
  })
else
  -- Regular mode with custom settings
  local success
  if path and path:match("%.lua$") then
    -- Single file
    local results = runner.run_file(path, firmo, options)
    success = results.success and results.errors == 0
  else
    -- Directory
    success = runner.run_all(path, firmo, options)
  end
  
  os.exit(success and 0 or 1)
end
```

## See Also

- [Test Runner Guide](../guides/test_runner.md): Practical guide for using the test runner
- [Test Runner Examples](../../examples/test_runner_examples.md): Real-world examples of test runner usage
- [CLI Documentation](./cli.md): Documentation for the command line interface
- [Coverage API](./coverage.md): Documentation for the coverage tracking API