# Command Line Interface Guide

This guide explains how to use Firmo's command-line interface for running tests, watch mode, and other test-related operations.

## Introduction

Firmo provides a powerful command-line interface (CLI) for running and managing tests. The CLI allows you to run tests with various options, watch files for changes, and use an interactive mode for more complex testing workflows.
The command-line interface is invoked through the main `firmo.lua` script in the project root, which utilizes the `lib/tools/cli` module.

## Basic Usage

### Running All Tests

To run all tests in your project (assuming they are in the default `tests/` directory or a configured `base_test_dir`):

```bash
lua firmo.lua
```

Or, to specify the directory explicitly:

```bash
lua firmo.lua ./tests/
```

This searches for test files in the specified directory and runs them, based on the configured file discovery pattern (default: `*_test.lua`).

### Running Specific Tests

You can run specific test files or directories directly:

```bash
lua firmo.lua ./tests/unit/calculator_test.lua
lua firmo.lua ./tests/integration/
```

Or use wildcard patterns with your shell (your shell expands this, Firmo receives a list of files):

```bash
lua firmo.lua tests/unit/*_test.lua
```

### Getting Help

To see all available options:

```bash
lua firmo.lua --help
```

## Command Line Options

The `lua firmo.lua` command accepts various options to control test discovery, execution, and reporting, primarily parsed by the `lib/tools/cli` module. Key options include:

| Option                     | Alias | Description                                                                                    | Default (from `default_options`) |
|----------------------------|-------|------------------------------------------------------------------------------------------------|----------------------------------|
| *paths...*                 |       | One or more file or directory paths to test. First dir may set base.                           | (Uses `base_test_dir`)           |
| `--help`                   | `-h`  | Show help message and exit.                                                                    | `false`                          |
| `--version`                | `-V`  | Show Firmo version and exit.                                                                   | `false`                          |
| `--verbose`                | `-v`  | Enable verbose logging output.                                                                 | `false`                          |
| `--config=<path>`          |       | Load a specific Firmo configuration file.                                                      | `nil`                            |
| `--create-config`          |       | Create a default '.firmo-config.lua' file and exit.                                            | `false`                          |
| `--<key>=<value>`          |       | Set a `central_config` value directly.                                                         | N/A                              |
| `--pattern=<glob>`         |       | Glob pattern for test file discovery (e.g., `'*_spec.lua'`).                                   | `"*_test.lua"`                   |
| `--filter=<lua_pattern>`   |       | Lua pattern to filter tests by their names/descriptions.                                       | `nil`                            |
| `--parallel`               | `-p`  | Enable parallel test execution (if `lib/tools/parallel` is integrated).                        | `false`                          |
| `--output-json-file=<path>`|       | (For internal parallel worker use) Worker writes JSON results to this file.                    | `nil`                            |
| `--watch`                  | `-w`  | Enable watch mode to re-run tests on file changes.                                             | `false`                          |
| `--interactive`            | `-i`  | Enable interactive REPL mode.                                                                  | `false`                          |
| `--coverage`               | `-c`  | Enable code coverage analysis.                                                                 | `false`                          |
| `--coverage-debug`         |       | Enable debug logging for the coverage module.                                                  | `false`                          |
| `--threshold=<0-100>`      |       | Set coverage threshold percentage (primarily for coverage reports).                              | `70`                             |
| `--quality`                | `-q`  | Enable test quality validation.                                                                | `false`                          |
| `--quality-level=<1-5>`    |       | Set target quality level for validation.                                                       | `3`                              |
| `--report`                 | `-r`  | Generate configured file reports after tests run.                                              | `false`                          |
| `--console-format=<type>`  |       | Set console output style: `default`, `dot`, `summary`, `json_dump_internal`.                     | `"default"`                      |
| `--report-formats=<list>`  |       | Comma-separated list of report file formats (e.g., `html,json,md,lcov`).                       | `[]` (empty table)               |
| `--report-dir=<path>`      |       | Output directory for all generated report files.                                               | `"./firmo-reports"`              |
| `--json`                   |       | Shorthand for `--console-format=json_dump_internal`. Outputs JSON results to console.          | `false`                          |

**Note:** Parallel execution (`--parallel` or `-p`) requires the `lib/tools/parallel` module to be available and correctly integrated.

## Test Filtering

### Filtering by File Path Pattern (`--pattern`)

You can control which files are discovered using a glob pattern:
```bash
# Only run files ending in _spec.lua in the unit directory
lua firmo.lua --pattern="unit/*_spec.lua"
```

### Filtering by Test/Describe Name (`--filter`)

You can filter tests based on their names (including `describe` block names) using Lua patterns with the `--filter` option:

```bash
# Run tests with "validate" in their name
lua firmo.lua --filter validate ./tests/

# Run tests starting with "should"
lua firmo.lua --filter "^should" ./tests/
```

Filtering by tags directly via the command line (`--tags`) is **not** currently supported. To run specific tag groups in CI, you might:
- Use `--filter` if your tags are reflected in test names (less precise).
- Set up separate CI jobs/steps that configure Firmo programmatically using `firmo.only_tags(...)` before running `lua firmo.lua ./tests/`.

## Console Output

The standard console output shows basic PASS/FAIL/SKIP status for each test, usually with color highlighting. The style can be controlled using the `--console-format` option:

- **`default`**: Standard detailed output.
- **`dot`**: Outputs a character for each test (`.` for pass, `F` for fail, `S` for skip).
- **`summary`**: Shows only the final summary.
- **`json_dump_internal`**: Outputs the raw JSON results object to the console (used by `--json` flag or for programmatic consumption).

```text
// Example with --console-format=default
PASS Test Name One
PASS Another Test
FAIL Test That Failed - Assertion failed: Expected 1 but got 2
SKIP Skipped Test - Reason for skipping

// Example with --console-format=dot
..FS

Test Execution Summary:
...
```

The `--verbose` (`-v`) flag can be used to show more detailed internal logging from the framework itself, regardless of the console format.

**Note:** The `--report-formats` flag controls the type of **report files** generated (e.g., `--report-formats=junit,html`), not the console output style during the run. Use `--report` to trigger file generation.

## Watch Mode

Watch mode automatically re-runs tests when files change, providing immediate feedback during development.

### Basic Watch Mode

```bash
# Run tests in watch mode (watches default test directory)
lua firmo.lua --watch
# Or specify a directory
lua firmo.lua --watch ./tests/
```

### Customizing Watch Mode

```bash
# Watch specific test file
lua firmo.lua --watch ./tests/unit/calculator_test.lua

# Watch with a name filter
lua firmo.lua --watch --filter unit ./tests/
```

### Watch Mode Controls

Once in watch mode, you can typically use these keyboard controls (behavior depends on the `lib/tools/watcher` module):
- Press `r` to re-run all tests.
- Press `f` to run only failed tests (if supported by watcher/runner).
- Press `q` or `Ctrl+C` to exit watch mode.

## Interactive Mode

Interactive mode provides a command shell for running tests with more control.
**(Note: This mode's full implementation status and features depend on `lib/tools/interactive`.)**

```bash
# Start interactive mode
lua firmo.lua --interactive
```

### Interactive Commands (Example)

Once in interactive mode, available commands might include (refer to the interactive module's specific help):
| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `run [file]` | Run all tests or a specific test file |
| `list` | List available test files |
| `filter <pattern>` | Filter tests by name pattern |
| `watch <on|off>` | Toggle watch mode |
| `clear` | Clear the screen |
| `status` | Show current settings |
| `exit` | Exit the interactive CLI |

## Coverage Tracking

Firmo can track code coverage during test runs.

```bash
# Run tests with coverage tracking
lua firmo.lua --coverage ./tests/

# Enable coverage and generate an HTML report file
lua firmo.lua --coverage --report --report-formats=html ./tests/
```

Coverage reports are saved to the directory specified by `--report-dir` (default: `./firmo-reports`). You can specify multiple report formats like `lcov,html,json`.

## Test Quality Validation

Firmo can validate the quality of your tests.

```bash
# Run with quality validation
lua firmo.lua --quality ./tests/

# Set quality validation level (1-5)
lua firmo.lua --quality --quality-level=2 ./tests/

# Enable quality validation and generate an HTML report file
lua firmo.lua --quality --report --report-formats=html ./tests/
```
Quality reports are also saved to the `--report-dir`.

## Continuous Integration

For CI environments, you'll often want to generate machine-readable reports.

```bash
# Example CI command, generating a JUnit report file
lua firmo.lua ./tests/ --report --report-formats=junit
```

### Example GitHub Actions Workflow

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Lua
        uses: leafo/gh-actions-lua@v8
        with:
          luaVersion: "5.3" # Adjust as needed

      - name: Run unit tests
        # Use --filter to select tests based on name pattern
        # Use --report and --report-formats for JUnit report
        run: lua firmo.lua ./tests/ --filter unit --report --report-formats=junit

      - name: Run integration tests
        run: lua firmo.lua ./tests/ --filter integration --report --report-formats=junit
```

## Advanced Usage

### Environment-based Test Selection

You can use environment variables with the CLI, typically by having your shell expand them:

```bash
# Run tests filtering by name based on environment variable
TEST_TYPE=unit lua firmo.lua --filter "$TEST_TYPE" ./tests/
```

## Best Practices

1.  **Organize Tests**: Structure tests logically in directories (e.g., `tests/unit`, `tests/integration`).
2.  **Use Watch Mode During Development**: Enable watch mode (`--watch`) for immediate feedback.
3.  **Use `--filter` for Specific Runs**: Use `--filter` to quickly run tests related to a specific feature or module name during development.
4.  **CI Integration**: Configure CI to run tests automatically. Use `--report --report-formats=junit` or similar for CI-parsable report files. Consider using `--filter` or programmatic filtering for different CI stages.
5.  **Coverage and Quality**: Use `--coverage` and `--quality` flags in CI or periodically to monitor test effectiveness.
6.  **Clear Naming**: Use descriptive test and describe block names to make filtering (`--filter`) more effective and console output easier to understand.
7.  **Quality Validation**: Use the `--quality` flag to ensure your tests meet quality standards.

## Troubleshooting

### No Tests Found

If no tests are found:
1. Check the path(s) you're providing to `lua firmo.lua`.
2. Verify your test files match the discovery pattern (default `*_test.lua`, or custom via `--pattern`).
3. Ensure the `base_test_dir` is correct if no paths are provided.

### Tests Not Running as Expected

If tests don't run as expected:
1. Use `--verbose` to see more detailed framework logging.
2. Check your `--filter` pattern if used.
3. Try running a specific test file directly to isolate issues.

### Watch Mode Not Detecting Changes

If watch mode isn't detecting changes:
1. Verify file permissions in the watched directories.
2. Check that the modified file is included in the watch path and not ignored.
3. Some file systems or editors might have unusual save behaviors; try a more direct save.

## Conclusion

The Firmo command-line interface provides powerful tools for running, filtering, and monitoring tests. By understanding and effectively using these features, you can create an efficient testing workflow tailored to your project's needs.
For practical examples, see the [CLI examples](/examples/cli_examples.md) file (if it exists and is up-to-date).
```

# Command Line Interface Guide


This guide explains how to use Firmo's command-line interface for running tests, watch mode, and other test-related operations.

## Introduction


Firmo provides a powerful command-line interface (CLI) for running and managing tests. The CLI allows you to run tests with various options, watch files for changes, and use an interactive mode for more complex testing workflows.
The command-line interface is invoked through the central `test.lua` script in the project root.

## Basic Usage


### Running All Tests


To run all tests in your project:


```bash
lua firmo.lua tests/
```


This searches for test files in the specified directory (in this case, `tests/`) and runs them.

### Running Specific Tests


You can run specific test files directly:


```bash
lua firmo.lua tests/unit/calculator_test.lua
```


Or use wildcard patterns with your shell:


```bash
lua firmo.lua tests/unit/*_test.lua
```



### Getting Help


To see all available options:


```bash
lua firmo.lua --help
```



## Command Line Options

The `lua firmo.lua` command accepts various options to control test discovery, execution, and reporting. Options parsed by `scripts/runner.lua`:

| Option                     | Alias | Description                                                              |
|----------------------------|-------|--------------------------------------------------------------------------|
| `--pattern=<pattern>`      |       | Only run test files matching Lua pattern (e.g., `"core_.*_test.lua"`)   |
| `--filter=<filter>`        |       | Only run tests/describes with names matching Lua pattern                 |
| `--format=<format>`        |       | Set **report file format** (e.g., `html`, `json`, `junit`, `lcov`)        |
| `--report-dir=<path>`      |       | Directory to save generated reports (default: `./coverage-reports`)      |
| `--coverage`               | `-c`  | Enable code coverage tracking                                            |
| `--coverage-debug`         | `-cd` | Enable debug output for coverage module                                |
| `--quality`                | `-q`  | Enable test quality validation                                           |
| `--quality-level=<n>`      |       | Set quality validation level (1-5, default: 3)                           |
| `--threshold=<n>`          |       | Set coverage/quality threshold percentage (0-100, default: 80)         |
| `--verbose`                | `-v`  | Enable verbose output from runner and framework modules                    |
| `--memory`                 | `-m`  | Track memory usage during test runs                                      |
| `--performance`            | `-p`  | Show performance metrics (Note: `-p` may also be used by `--parallel`)     |
| `--watch`                  | `-w`  | Enable watch mode for continuous testing                                 |
| `--interactive`            | `-i`  | Start interactive CLI mode (Not fully implemented)                       |
| `--json`                   | `-j`  | Output final results summary as JSON to stdout                           |
| `--version`                | `-V`  | Show Firmo version                                                       |
| `--help`                   | `-h`  | Show help message                                                        |
| *path*                     |       | File or directory path to run tests from (default: `tests/`)             |

**Note:** Parallel execution (`--parallel`, `--workers`) might be available if the `lib/tools/parallel` module is integrated via `register_with_firmo`.

## Test Filtering

### Filtering by Name (`--filter`)


You can filter tests based on their names (including `describe` block names) using Lua patterns with the `--filter` option:

```bash
# Run tests with "validate" in their name
lua firmo.lua --filter validate tests/

# Run tests starting with "should"
lua firmo.lua --filter "^should" tests/
```

Filtering by tags directly via the command line (`--tags`) is **not** currently supported. To run specific tag groups in CI, you might:
- Use `--filter` if your tags are reflected in test names (less precise).
- Set up separate CI jobs/steps that configure Firmo programmatically using `firmo.only_tags(...)` before running `lua firmo.lua tests/`.

## Console Output

The standard console output shows basic PASS/FAIL/SKIP status for each test, usually with color highlighting.

```text
PASS Test Name One
PASS Another Test
FAIL Test That Failed - Assertion failed: Expected 1 but got 2
SKIP Skipped Test - Reason for skipping
```

Currently, there are **limited CLI options** to control the *style* of this console output (like dot mode, compact mode, summary only, indentation, or forcing colors off). The `--verbose` (`-v`) flag can be used to show more detailed internal logging from the framework.

**Note:** The `--format <format>` flag controls the type of **report files** generated (e.g., `--format=junit`, `--format=html`), not the console output style.

## Watch Mode


Watch mode automatically re-runs tests when files change, providing immediate feedback during development.

### Basic Watch Mode



```bash

# Run tests in watch mode


lua firmo.lua --watch tests/
```



### Customizing Watch Mode



```bash

# Watch specific test file


lua firmo.lua --watch tests/unit/calculator_test.lua

# Watch with a name filter
lua firmo.lua --watch --filter unit tests/
```


### Watch Mode Controls


Once in watch mode, you can:


- Press `r` to re-run all tests
- Press `f` to run only failed tests
- Press `q` or `Ctrl+C` to exit watch mode


## Interactive Mode


Interactive mode provides a command shell for running tests with more control:


```bash

# Start interactive mode


lua firmo.lua --interactive
```



### Interactive Commands


Once in interactive mode, you can:
| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `run [file]` | Run all tests or a specific test file |
| `list` | List available test files |
|| `filter <pattern>` | Filter tests by name pattern |
|| `watch <on|off>` | Toggle watch mode |
| `clear` | Clear the screen |
| `status` | Show current settings |
| `exit` | Exit the interactive CLI |

### Interactive Mode Workflow


A typical interactive session might look like:


```text
$ lua firmo.lua --interactive
Firmo Interactive CLI
Type 'help' for available commands
-------------------------------
> list
Available test files:


  1. tests/unit/calculator_test.lua
  2. tests/unit/user_test.lua
  3. tests/integration/api_test.lua

> filter unit
Test filter set to: unit
> run
Running 2 test files...
All tests passed!
> filter calculator
Test filter set to: calculator
> run
Running 1 test file...
All tests passed!
> watch on
Watch mode enabled
Watching for changes...
```



## Coverage Tracking


Firmo can track code coverage during test runs:


```bash

# Run tests with coverage tracking


lua firmo.lua --coverage tests/

# Specify the report file format for coverage report (e.g., HTML)
lua firmo.lua --coverage --format=html tests/
```

Coverage reports are saved to the `coverage-reports` directory by default.

## Test Quality Validation


Firmo can validate the quality of your tests:


```bash

# Run with quality validation


lua firmo.lua --quality tests/

# Set quality validation level (1-3)


lua firmo.lua --quality --quality-level 2 tests/
```



## Continuous Integration


For CI environments, you might want to disable colors and set appropriate formatting:


```bash

# Example CI command, potentially generating a JUnit report file
lua firmo.lua tests/ --format=junit
```
(Note: `--no-color` and `--format plain` for console are not implemented flags)



### Example GitHub Actions Workflow



```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:


      - uses: actions/checkout@v2
      - name: Install Lua

        uses: leafo/gh-actions-lua@v8
        with:
          luaVersion: "5.3"

      - name: Run unit tests

        # Use --filter to select tests based on name pattern
        # Use --format=junit if JUnit report generation is configured
        run: lua firmo.lua tests/ --filter unit --format=junit

      - name: Run integration tests

        # Use --filter to select tests based on name pattern
        run: lua firmo.lua tests/ --filter integration --format=junit
```



## Advanced Usage


### Environment-based Test Selection


You can use environment variables with the CLI:


```bash

# Run tests filtering by name based on environment variable
TEST_TYPE=unit lua firmo.lua --filter $TEST_TYPE tests/
```


### Custom Test Runner Script


You can create a custom test runner script:


```lua
#!/usr/bin/env lua
-- custom_runner.lua
local args = {...}
local test_args = {"test.lua"}
-- Add default options (use actual flags like --verbose or --format=junit)
table.insert(test_args, "--verbose")
-- Add user args
for _, arg in ipairs(args) do
  table.insert(test_args, arg)
end
-- Add default test directory if none specified
local has_path = false
for _, arg in ipairs(args) do
  if arg:match("^[^-]") then
    has_path = true
    break
  end
end
if not has_path then
  table.insert(test_args, "tests/")
end
-- Execute test command
os.execute("lua " .. table.concat(test_args, " "))
```


Then use it:

```bash
lua custom_runner.lua --filter unit
```



## Best Practices

1.  **Organize Tests**: Structure tests logically in directories (e.g., `tests/unit`, `tests/integration`).
2.  **Use Watch Mode During Development**: Enable watch mode (`--watch`) for immediate feedback.
3.  **Use `--filter` for Specific Runs**: Use `--filter` to quickly run tests related to a specific feature or module name during development.
4.  **CI Integration**: Configure CI to run tests automatically. Use `--format=junit` or similar for CI-parsable report files. Consider using `--filter` or programmatic filtering for different CI stages (e.g., quick unit tests vs. longer integration tests).
5.  **Coverage and Quality**: Use `--coverage` and `--quality` flags in CI or periodically to monitor test effectiveness.
6.  **Clear Naming**: Use descriptive test and describe block names to make filtering (`--filter`) more effective and console output easier to understand.
7. **Quality Validation**: Use the --quality flag to ensure your tests meet quality standards.


## Troubleshooting


### No Tests Found


If no tests are found:


1. Check the path you're providing to test.lua
2. Verify your test files match the default pattern (*_test.lua)
3. If using custom patterns, ensure they're correct with --pattern


### Tests Not Running as Expected


If tests don't run as expected:


1. Use --format detailed to see more output
2. Check your tag and filter combinations
3. Try running a specific test file directly


### Watch Mode Not Detecting Changes


If watch mode isn't detecting changes:


1. Verify file permissions
2. Check that the file is included in the watch path
3. Try saving with a more significant change


## Conclusion


The Firmo command-line interface provides powerful tools for running, filtering, and monitoring tests. By understanding and effectively using these features, you can create an efficient testing workflow tailored to your project's needs.
For practical examples, see the [CLI examples](/examples/cli_examples.md) file.
