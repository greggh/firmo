# Command Line Interface
This document describes the command-line interface (CLI) provided by Firmo.

## Overview
Firmo can be run directly from the command line to discover and run tests. This provides a convenient way to run tests without writing test runner scripts. The CLI now supports three modes of operation:

1. **Standard Mode**: Run tests and exit
2. **Watch Mode**: Continuously run tests when files change
3. **Interactive Mode**: A full-featured interactive shell for running tests and configuring test options

## Basic Usage

```bash

# Run all tests in the default directory (./tests)
lua scripts/run_tests.lua

# Run tests in a specific directory
lua scripts/run_tests.lua --dir path/to/tests

# Run a specific test file
lua scripts/run_tests.lua path/to/test_file.lua

# Run tests in watch mode (continuous testing)
lua scripts/run_tests.lua --watch

# Start interactive CLI mode
lua scripts/run_tests.lua --interactive

```

## Command Line Options

### Basic Options
| Option | Description |
|--------|-------------|
| `--dir DIRECTORY` | Directory to search for test files (default: ./tests) |
| `--pattern PATTERN` | Pattern to match test files (default: *_test.lua) |
| `--tags TAG1,TAG2,...` | Run only tests with specific tags |
| `--filter PATTERN` | Run only tests with names matching pattern |
| `--help`, `-h` | Show help message |
| `--interactive`, `-i` | Start interactive CLI mode |

### Watch Mode Options
| Option | Description |
|--------|-------------|
| `--watch` | Enable watch mode for continuous testing |
| `--watch-dir DIRECTORY` | Directory to watch for changes (can specify multiple) |
| `--watch-interval SECONDS` | Interval between file checks (default: 1.0) |
| `--exclude PATTERN` | Pattern to exclude from watching (can specify multiple) |

### Code Quality Options
| Option | Description |
|--------|-------------|
| `--fix [DIRECTORY]` | Run code fixing on directory (default: .) |
| `--check DIRECTORY` | Check for code issues without fixing |

## Examples

### Running Tests

```bash

# Run all tests
lua scripts/run_tests.lua

# Run a specific test file
lua scripts/run_tests.lua tests/specific_test.lua

# Run tests with custom pattern
lua scripts/run_tests.lua --dir src --pattern "*_spec.lua"

# Run tests with specific tags
lua scripts/run_tests.lua --tags unit,fast

```

### Using Watch Mode

```bash

# Basic watch mode
lua scripts/run_tests.lua --watch

# Watch specific directories
lua scripts/run_tests.lua --watch --watch-dir src --watch-dir lib

# Watch with faster check interval
lua scripts/run_tests.lua --watch --watch-interval 0.5

# Watch with exclusions
lua scripts/run_tests.lua --watch --exclude "build/.*" --exclude "%.git"

# Watch a specific test file
lua scripts/run_tests.lua --watch tests/specific_test.lua

```

### Code Fixing

```bash

# Fix code issues in current directory
lua scripts/run_tests.lua --fix

# Fix code issues in specific directory
lua scripts/run_tests.lua --fix src

# Check for issues without fixing
lua scripts/run_tests.lua --check src

```

## Watch Mode
Watch mode is a powerful feature that continuously monitors your project files for changes and automatically re-runs tests when changes are detected. This is particularly useful during development as it provides immediate feedback.

### How Watch Mode Works

1. Tests are run initially to establish baseline
2. File system is monitored for changes to relevant files
3. When changes are detected, tests are automatically re-run
4. Results are displayed, and monitoring continues
5. Process repeats until terminated (Ctrl+C)

### Benefits of Watch Mode

- **Immediate Feedback**: See test results as soon as you save files
- **Focused Development**: Keep your focus on code, not on running tests
- **Faster Development Cycles**: Shortens the feedback loop in test-driven development
- **Increased Confidence**: Continuous verification that your code still works

### Watch Mode Options
The watch mode can be customized with several options:

- **Watch Directories**: Specify which directories to monitor for changes
- **Check Interval**: Adjust how frequently to check for changes
- **Exclusion Patterns**: Ignore changes in specific files or directories

### Example Watch Mode Session

```
$ lua scripts/run_tests.lua --watch
--- WATCH MODE ACTIVE ---
Press Ctrl+C to exit
Watching directory: .
Watching 142 files for changes
Running 5 test files
...
Test Summary: 5 passed, 0 failed
✓ All tests passed
--- WATCHING FOR CHANGES ---
File changes detected:

  - ./src/module.lua
  - ./tests/module_test.lua
--- RUNNING TESTS ---
2025-03-07 14:23:45
Running 5 test files
...
Test Summary: 5 passed, 0 failed
✓ All tests passed
--- WATCHING FOR CHANGES ---

```

## Exit Codes
Firmo sets the process exit code based on the test results:

- **0**: All tests passed
- **1**: One or more tests failed, or an error occurred during test execution
This is useful for integration with CI systems.

## Environment Variables
Firmo doesn't use environment variables directly, but you can create wrapper scripts that use environment variables to configure test runs.
**Example:**

```bash
#!/bin/bash

# run_tests.sh

# Get test type from environment variable, default to "unit"
TEST_TYPE=${TEST_TYPE:-unit}

# Run tests with appropriate tags
lua scripts/run_tests.lua --tags $TEST_TYPE

```
Then you can run specific test types with:

```bash
TEST_TYPE=integration ./run_tests.sh

```

## Integration with Make
You can integrate Firmo with Make for more complex test workflows:

```makefile
.PHONY: test test-unit test-watch
test:
	lua scripts/run_tests.lua
test-unit:
	lua scripts/run_tests.lua --tags unit
test-watch:
	lua scripts/run_tests.lua --watch
test-coverage:
	lua scripts/run_tests.lua --coverage

```

## Interactive Mode
Interactive mode provides a powerful command-line interface for running tests and configuring test options. It's ideal for development workflows where you need more flexibility than watch mode alone provides.

### Starting Interactive Mode

```bash

# Start interactive mode
lua scripts/run_tests.lua --interactive

```

### Available Commands
| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `run [file]` | Run all tests or a specific test file |
| `list` | List available test files |
| `filter <pattern>` | Filter tests by name pattern |
| `focus <name>` | Focus on specific test (partial name match) |
| `tags <tag1,tag2>` | Run tests with specific tags |
| `watch <on|off>` | Toggle watch mode |
| `watch-dir <path>` | Add directory to watch |
| `watch-exclude <pat>` | Add exclusion pattern for watch |
| `codefix <cmd> <dir>` | Run codefix (check|fix) on directory |
| `dir <path>` | Set test directory |
| `pattern <pat>` | Set test file pattern |
| `clear` | Clear the screen |
| `status` | Show current settings |
| `history` | Show command history |
| `exit` | Exit the interactive CLI |

### Example Interactive Session

```
$ lua scripts/run_tests.lua -i
Firmo Interactive CLI
Type 'help' for available commands
------------------------------------------------------------
Current settings:
  Test directory:     ./tests
  Test pattern:       *_test.lua
  Focus filter:       none
  Tag filter:         none
  Watch mode:         disabled
  Codefix:            disabled
  Available tests:    12
------------------------------------------------------------
> list
Available test files:

  1. ./tests/assertions_test.lua
  2. ./tests/async_test.lua
  3. ./tests/discovery_test.lua
  4. ./tests/expect_assertions_test.lua
  5. ./tests/firmo_test.lua
  6. ./tests/mocking_test.lua
  7. ./tests/tagging_test.lua
  8. ./tests/truthy_falsey_test.lua
  9. ./tests/type_checking_test.lua
  10. ./tests/watch_mode_test.lua
------------------------------------------------------------
> tags unit,fast
Tag filter set to: unit,fast
> run
Running 3 test files...
Test Summary: 3 passed, 0 failed
✓ All tests passed
> focus "should handle nested"
Test focus set to: should handle nested
> run
Running 3 test files...
Test Summary: 1 passed, 0 failed
✓ All tests passed
> watch on
Watch mode enabled
Starting watch mode...
Watching directories: .

```

### Interactive Mode Benefits

1. **Live Configuration**: Change test filters, tags, and watch settings without restarting
2. **Workflow Flexibility**: Combine watch mode with dynamic test filtering for focused development
3. **Quick Navigation**: Easily run specific tests or groups of tests with minimal typing
4. **Clear Status**: Get immediate feedback on current settings and available tests
5. **Command History**: Recall previous commands using history feature

### Using Interactive Mode in Scripts
You can also start interactive mode programmatically:

```lua
local firmo = require("firmo")
local interactive = require("src.interactive")
-- Run your tests...
-- Start interactive mode
interactive.start(firmo, {
  test_dir = "./tests",
  pattern = "*_test.lua",
  watch_mode = false
})

```
See `examples/interactive_mode_example.lua` for a complete example.

## Integration with CI Systems

### GitHub Actions Example

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:

    - uses: actions/checkout@v2
    - name: Set up Lua
      uses: leafo/gh-actions-lua@v8
      with:
        luaVersion: "5.3"

    - name: Install dependencies
      run: |
        luarocks install luafilesystem

    - name: Run unit tests
      run: lua scripts/run_tests.lua --tags unit

    - name: Run integration tests
      run: lua scripts/run_tests.lua --tags integration

```

## Creating Custom Test Runners
You can create custom test runners that use Firmo's API. See the `scripts/runner.lua` file for an example of how to implement a custom runner with watch mode support.

## Best Practices

1. **Use Interactive Mode for Development**: Use interactive mode during development for maximum flexibility
2. **Use Watch Mode for Continuous Feedback**: Enable watch mode when focusing on specific test areas
3. **Use Tags Consistently**: Establish a convention for tag names (e.g., "unit", "integration", "slow") 
4. **Group Related Options**: When running tests, group related command-line options together
5. **CI Integration**: Set up your CI system to run different test subsets using tags
6. **Exit Codes**: Use exit codes in scripts to indicate test success or failure
7. **Custom Runners**: For complex requirements, create custom test runners using the Firmo API

