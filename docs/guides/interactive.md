# Interactive CLI User Guide


The Interactive CLI is a powerful tool for interacting with the Firmo testing framework through a command-line interface. This guide explains how to use the interactive CLI effectively for test development, debugging, and maintaining code quality.

## Table of Contents



- [Getting Started](#getting-started)
- [Basic Commands](#basic-commands)
- [Running Tests](#running-tests)
- [Filtering Tests](#filtering-tests)
- [Watch Mode](#watch-mode)
- [Code Quality with Codefix](#code-quality-with-codefix)
- [Command History](#command-history)
- [Configuration Tips](#configuration-tips)
- [Integration with Other Tools](#integration-with-other-tools)
- [Troubleshooting](#troubleshooting)


## Getting Started


### Launching the CLI


The Interactive CLI can be launched using the main Firmo module:


```lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")
-- Start the interactive CLI
interactive.start(firmo)
```


When launched, you'll see a welcome screen and prompt:


```text
Firmo Interactive CLI
Type 'help' for available commands
------------------------------------------------------------
> 
```



### Initial Configuration


Before starting, you can configure the CLI with options:


```lua
interactive.configure({
  test_dir = "tests/unit",
  test_pattern = "*_test.lua",
  watch_mode = false,
  colorized_output = true
})
interactive.start(firmo)
```



## Basic Commands


The CLI provides several basic commands:

### Help


Display available commands:


```text
> help
```



### Status


Show current settings:


```text
> status
```


Example output:


```text
Current settings:
  Test directory:     ./tests
  Test pattern:       *_test.lua
  Focus filter:       none
  Watch mode:         disabled
  Codefix:            disabled
  Available tests:    24
------------------------------------------------------------
```



### List Test Files


Display available test files:


```text
> list
```


Example output:


```text
Available test files:


  1. tests/core/config_test.lua
  2. tests/core/lifecycle_test.lua
  3. tests/tools/filesystem_test.lua

  ...
------------------------------------------------------------
```



### Clear Screen


Clear the terminal screen:


```text
> clear
```



### Exit


Exit the interactive CLI:


```text
> exit
```


or


```text
> quit
```



## Running Tests


### Run All Tests


Run all discovered test files:


```text
> run
```



### Run Specific Test File

|| `filter <pattern>` | Filter tests by name pattern |
|| `focus <pattern>` | Focus on tests matching pattern |
|| `pattern <pattern>` | Set the test file discovery pattern |
|| `watch <on|off>` | Toggle watch mode |
|| `watch-dir <dir>` | Add directory to watch |
|| `watch-exclude <pattern>` | Add pattern to exclude from watching |
|| `codefix <cmd> [path]` | Run codefix operations (e.g., `check`, `fix`) |


You can also run a file by its number from the list:


```text
> run 1
```



### Setting Test Directory


Change the test directory:


```text
> dir tests/unit
```


This will update the test directory and rediscover test files.

### Setting Test Pattern


Change the pattern used to find test files:


```text
> pattern *_spec.lua
```


This will update the test file pattern and rediscover test files.

## Filtering Tests


The interactive CLI offers several ways to filter which tests are run.

### Filter by Name


Filter tests by name pattern:


```text
> filter string_utils
```


This will only run tests whose descriptions match "string_utils".
To clear the filter:


```text
> filter
```



### Focus on Specific Tests


Focus on a specific test or group:


```text
> focus "should validate input"
```


This will only run tests that match the given description.
To clear the focus:


```text
> focus
```

### Setting Test File Pattern

Change the pattern used to find test files:

```text
> pattern *_spec.lua
```

This will update the test file pattern and rediscover test files. To clear and use the default (`*_test.lua`):

```text
> pattern
```

## Watch Mode


Watch mode monitors files for changes and automatically reruns tests when changes are detected.

### Enable/Disable Watch Mode


Toggle watch mode:


```text
> watch
```


Or explicitly enable/disable:


```text
> watch on
> watch off
```



### Configure Watch Directories


Add directories to watch:


```text
> watch-dir src
```


If you add more than one, all will be watched:


```text
> watch-dir lib
> watch-dir tests
```



### Exclude Patterns


Add patterns to exclude from watching:


```text
> watch-exclude node_modules
> watch-exclude %.git
```



### Using Watch Mode


Once in watch mode:


1. Tests will run automatically when files change
2. The screen will clear and show which files changed
3. Press Enter to return to the interactive prompt

Example watch mode session:


```text
--- WATCHING FOR CHANGES (Press Enter to return to interactive mode) ---
File changes detected:


  - src/utils/string_utils.lua

--- RUNNING TESTS ---
2025-03-26 10:45:23
Running tests/utils/string_utils_test.lua
✓ Suite: String Utils
  ✓ should trim whitespace
  ✓ should capitalize first letter
  ✓ should handle empty string
3 passing (0.003s)
--- WATCHING FOR CHANGES (Press Enter to return to interactive mode) ---
```



## Code Quality with Codefix


The interactive CLI integrates with the codefix module to provide code quality checks and fixes.

### Check Code


Check code for issues without modifying files:


```text
> codefix check src
```



### Fix Code


Fix code quality issues:


```text
> codefix fix src
```


The codefix command supports subcommands like `check` and `fix` along with a path, allowing you to run code quality checks directly (e.g., `codefix check src`, `codefix fix src/my_module.lua`).

## Command History


### View History


Show previously entered commands:


```text
> history
```


Example output:


```text
Command History:


  1. run
  2. filter string_utils
  3. watch on
  4. watch off
  5. codefix check src

```



### Navigate History


Use Up and Down arrow keys to navigate through command history.

## Configuration Tips


### Optimal Workflow Configuration


For the best development workflow, configure the CLI as follows:


```lua
interactive.configure({
  test_dir = "tests",
  test_pattern = "*_test.lua",
  watch_mode = true,
  watch_dirs = { "src", "tests" },
  exclude_patterns = { "node_modules", "%.git", "%.vscode" },
  watch_interval = 0.5,
  colorized_output = true
})
```


This configuration:


- Watches both source and test files
- Excludes common directories that shouldn't trigger test runs
- Uses a faster check interval (0.5 seconds)
- Enables colorized output for better readability


### Using Central Configuration


If your project uses central_config, you can set interactive CLI options there:


```lua
local central_config = require("lib.core.central_config")
central_config.set("interactive", {
  test_dir = "tests",
  watch_mode = true,
  watch_dirs = { "src", "tests" },
  exclude_patterns = { "node_modules", "%.git" }
})
```


The interactive CLI will automatically use these settings.

## Integration with Other Tools


### CI/CD Integration


For continuous integration pipelines, you can use the interactive CLI in non-interactive mode:
```lua
-- Example for running tests programmatically (suitable for CI)
-- This typically involves using the main runner script directly
local runner = require("scripts.runner")

-- Run all tests found in 'tests/' directory
local success = runner.main({"tests/"})
if not success then
  os.exit(1) -- Exit with error code if tests failed
end
```



### Pre-commit Hooks


You can use the interactive CLI in pre-commit hooks to ensure tests pass before committing:


```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running codefix check..."
# Use lua -e to invoke the CLI check command on staged files or the whole project
# Using '.' checks the whole project here for simplicity
lua -e 'require("lib.tools.codefix").run_cli({"check", "."})'
check_exit_code=$?

if [ $check_exit_code -ne 0 ]; then
  echo "Codefix check failed. Please fix issues before committing."
  exit 1
fi

echo "Codefix check passed."

# Optionally, run quick unit tests
# echo "Running unit tests..."
# lua firmo.lua tests/ --filter unit
# test_exit_code=$?
# if [ $test_exit_code -ne 0 ]; then
#   echo "Unit tests failed. Please fix tests before committing."
#   exit 1
# fi
# echo "Unit tests passed."

exit 0
```
*(Note: The Lua `run_cli` function might need adjustment to return a non-zero exit code on failure for the hook to work correctly).*



## Troubleshooting


### Common Issues and Solutions


#### Tests Not Being Found


If tests aren't being discovered:


```text
> status
```


Check that the test directory and pattern are correct. If not, update them:


```text
> dir tests
> pattern *_test.lua
```


Then list tests to verify:


```text
> list
```



#### Watch Mode Not Detecting Changes


If watch mode isn't detecting changes, check:


1. That you're modifying files in the watched directories
2. That the files aren't excluded by patterns
3. The watch interval may be too long

You can adjust these settings:


```text
> watch-dir src
> watch-exclude node_modules
```



#### Colorized Output Issues


If colorized output looks strange in your terminal:

This is usually configured programmatically before starting the interactive session:
```lua
interactive.configure({ colorized_output = false })
```
There is no direct interactive command to toggle colors during a session.



#### CLI Not Responding


If the CLI stops responding:


1. Press Ctrl+C to exit
2. Restart with different options
3. Check if another process is consuming system resources


### Getting Help


For detailed error information, enable debug mode:


```lua
interactive.configure({
  debug = true,
  verbose = true
})
```


This will provide more detailed logging information to help diagnose issues.
