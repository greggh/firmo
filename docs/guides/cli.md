# Command Line Interface Guide


This guide explains how to use Firmo's command-line interface for running tests, watch mode, and other test-related operations.

## Introduction


Firmo provides a powerful command-line interface (CLI) for running and managing tests. The CLI allows you to run tests with various options, watch files for changes, and use an interactive mode for more complex testing workflows.
The command-line interface is invoked through the central `test.lua` script in the project root.

## Basic Usage


### Running All Tests


To run all tests in your project:


```bash
lua test.lua tests/
```


This searches for test files in the specified directory (in this case, `tests/`) and runs them.

### Running Specific Tests


You can run specific test files directly:


```bash
lua test.lua tests/unit/calculator_test.lua
```


Or use wildcard patterns with your shell:


```bash
lua test.lua tests/unit/*_test.lua
```



### Getting Help


To see all available options:


```bash
lua test.lua --help
```



## Command Line Options


### Test Filtering Options


| Option | Description |
|--------|-------------|
| `--tags TAG1,TAG2,...` | Run only tests with specific tags |
| `--filter PATTERN` | Run only tests with names matching pattern |
| `--pattern PATTERN` | Pattern to match test files (default: *_test.lua) |

### Output Formatting Options


| Option | Description |
|--------|-------------|
| `--format FORMAT` | Set output format (detailed, compact, dot, summary) |
| `--no-color` | Disable colored output |
| `--indent STYLE` | Set indentation style (tabs, spaces, N) |

### Execution Mode Options


| Option | Description |
|--------|-------------|
| `--watch` | Enable watch mode for continuous testing |
| `--interactive`, `-i` | Start interactive CLI mode |
| `--coverage` | Enable code coverage tracking |
| `--quality` | Enable test quality validation |

## Test Filtering


### Filtering by Tags


Tags allow you to categorize tests and run specific categories:


```bash

# Run only tests tagged as "unit"


lua test.lua --tags unit tests/

# Run tests tagged as either "unit" or "integration"


lua test.lua --tags unit+integration tests/

# Run tests tagged as "api" but not "slow"


lua test.lua --tags api,-slow tests/
```



### Filtering by Name


You can filter tests based on their names using Lua patterns:


```bash

# Run tests with "validate" in their name


lua test.lua --filter validate tests/

# Run tests starting with "should"


lua test.lua --filter "^should" tests/
```



### Combining Filters


You can combine tag and name filters for precise test selection:


```bash

# Run "unit" tests with "validation" in the name


lua test.lua --tags unit --filter validation tests/
```



## Output Formatting


### Format Options


You can control how test results are displayed:


```bash

# Use compact output format


lua test.lua --format compact tests/

# Use dot notation (. for pass, F for fail)


lua test.lua --format dot tests/

# Show only the summary


lua test.lua --format summary tests/

# Use detailed output (default)


lua test.lua --format detailed tests/
```



### Color Control


Toggle colored output:


```bash

# Disable colored output (for CI or non-ANSI terminals)


lua test.lua --no-color tests/
```



### Indentation Control


Configure indentation:


```bash

# Use 2 spaces for indentation


lua test.lua --indent 2 tests/

# Use tabs for indentation


lua test.lua --indent tabs tests/
```



## Watch Mode


Watch mode automatically re-runs tests when files change, providing immediate feedback during development.

### Basic Watch Mode



```bash

# Run tests in watch mode


lua test.lua --watch tests/
```



### Customizing Watch Mode



```bash

# Watch specific test file


lua test.lua --watch tests/unit/calculator_test.lua

# Watch with specific tags


lua test.lua --watch --tags unit tests/
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


lua test.lua --interactive
```



### Interactive Commands


Once in interactive mode, you can:
| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `run [file]` | Run all tests or a specific test file |
| `list` | List available test files |
| `filter <pattern>` | Filter tests by name pattern |
| `tags <tag1,tag2>` | Run tests with specific tags |
| `watch <on|off>` | Toggle watch mode |
| `clear` | Clear the screen |
| `status` | Show current settings |
| `exit` | Exit the interactive CLI |

### Interactive Mode Workflow


A typical interactive session might look like:


```text
$ lua test.lua --interactive
Firmo Interactive CLI
Type 'help' for available commands
-------------------------------
> list
Available test files:


  1. tests/unit/calculator_test.lua
  2. tests/unit/user_test.lua
  3. tests/integration/api_test.lua

> tags unit
Tag filter set to: unit
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


lua test.lua --coverage tests/

# Specify output format for coverage report


lua test.lua --coverage --format html tests/
```


Coverage reports are saved to the `coverage-reports` directory by default.

## Test Quality Validation


Firmo can validate the quality of your tests:


```bash

# Run with quality validation


lua test.lua --quality tests/

# Set quality validation level (1-3)


lua test.lua --quality --quality-level 2 tests/
```



## Continuous Integration


For CI environments, you might want to disable colors and set appropriate formatting:


```bash

# CI-friendly test command


lua test.lua --no-color --format plain tests/
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
          luaVersion: "5.3"


      - name: Run unit tests

        run: lua test.lua --tags unit --no-color tests/


      - name: Run integration tests

        run: lua test.lua --tags integration --no-color tests/
```



## Advanced Usage


### Environment-based Test Selection


You can use environment variables with the CLI:


```bash

# Run tests based on environment variable


TEST_TYPE=unit lua test.lua --tags $TEST_TYPE tests/
```



### Custom Test Runner Script


You can create a custom test runner script:


```lua
#!/usr/bin/env lua
-- custom_runner.lua
local args = {...}
local test_args = {"test.lua"}
-- Add default options
table.insert(test_args, "--format")
table.insert(test_args, "compact")
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
lua custom_runner.lua --tags unit
```



## Best Practices



1. **Tag Tests Consistently**: Use a consistent tagging strategy (e.g., "unit", "integration", "slow") throughout your project.
2. **Use Watch Mode During Development**: Enable watch mode for immediate feedback during active development.
3. **Use Interactive Mode for Complex Workflows**: When you need to run different test combinations, use interactive mode.
4. **CI Integration**: Configure CI to run different test subsets with appropriate tags.
5. **Coverage Reports**: Regularly generate coverage reports to identify untested code.
6. **Clear Naming**: Use descriptive test names to make --filter results more meaningful.
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
