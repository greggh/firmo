# Parallel Module API Reference


The parallel module in Firmo provides functionality to run test files in parallel for better resource utilization and faster test execution.

## Overview


The parallel module allows you to execute multiple test files concurrently across separate worker processes. This can significantly reduce the total test execution time, especially for test suites with many independent test files.

## Module Interface



```lua
local parallel = require("lib.tools.parallel")
parallel.register_with_firmo(firmo)
```



### Configuration Options


The parallel module can be configured through the `parallel.options` table:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `workers` | number | `4` | Number of worker processes to use |
| `timeout` | number | `60` | Timeout in seconds for each test file |
| `output_buffer_size` | number | `10240` | Size of output buffer for capturing test output |
| `verbose` | boolean | `false` | Enable verbose logging |
| `show_worker_output` | boolean | `true` | Display output from worker processes |
| `fail_fast` | boolean | `false` | Stop on first test failure |
| `aggregate_coverage` | boolean | `true` | Combine coverage data from worker processes |
| `debug` | boolean | `false` | Enable debug mode |

## Core Functions


### `parallel.configure(options)`


Configure the parallel module with custom options.


```lua
parallel.configure({
  workers = 8,
  timeout = 30,
  fail_fast = true
})
```


**Parameters:**


- `options` (table, optional): Configuration options to override defaults

**Returns:**


- The parallel module instance (for method chaining)


### `parallel.run_tests(files, options)`


Run multiple test files in parallel worker processes.


```lua
local results = parallel.run_tests({
  "tests/module1_test.lua",
  "tests/module2_test.lua"
}, {
  workers = 4,
  timeout = 30,
  show_worker_output = true
})
```


**Parameters:**


- `files` (table): Array of file paths to run
- `options` (table, optional): Run options that override module configuration

**Returns:**

- `results` (table): An aggregated results object (instance of `Results` class) containing:
  - `passed` (number): Total count of passed tests across all files.
  - `failed` (number): Total count of failed tests across all files.
  - `skipped` (number): Total count of skipped tests across all files.
  - `pending` (number): Total count of pending tests across all files.
  - `total` (number): Total count of tests executed/counted across all files.
  - `errors` (table): Array of error detail tables, each containing `{file, message, traceback}` for failures.
  - `elapsed` (number): Total wall-clock time for the entire parallel execution in seconds.
  - `coverage` (table): Aggregated coverage data table (if coverage and aggregation are enabled). Structure depends on coverage module.
  - `files_run` (string[]): Array of file paths that were executed by workers.
  - `worker_outputs` (string[]): Array containing the raw stdout/stderr captured from each worker process.

### `parallel.register_with_firmo(firmo)`


Register parallel testing functionality with the Firmo framework.


```lua
local firmo = require("firmo")
parallel.register_with_firmo(firmo)
```


**Parameters:**


- `firmo` (table): The Firmo framework instance

**Returns:**


- The parallel module instance

This function also adds CLI options for parallel execution to Firmo, allowing you to run:


```text
lua test.lua --parallel --workers 4 tests/
```



### `parallel.reset()`


Reset the module to default configuration.


```lua
parallel.reset()
```


**Returns:**


- The parallel module instance (for method chaining)


### `parallel.full_reset()`


Fully reset both local and central configuration.


```lua
parallel.full_reset()
```


**Returns:**


- The parallel module instance (for method chaining)


### `parallel.debug_config()`


Debug helper to show current configuration.


```lua
local config_info = parallel.debug_config()
```


**Returns:**


- `debug_info` (table): Detailed information about the current configuration:
  - `local_config` (table): Local configuration values
  - `using_central_config` (boolean): Whether central configuration is in use
  - `central_config` (table): Central configuration values (if available)


## Integration with Central Configuration


The parallel module integrates with Firmo's central configuration system, if available:


```lua
-- Configuration will be stored in the central config system
local central_config = require("lib.core.central_config")
central_config.set("parallel.workers", 8)
```



## CLI Options


When registered with Firmo, the following command-line options become available:
| Option | Description |
|--------|-------------|
| `--parallel, -p` | Run tests in parallel |
| `--workers, -w <num>` | Number of worker processes (default: 4) |
| `--timeout <seconds>` | Timeout for each test file (default: 60) |
| `--verbose-parallel` | Show verbose output from parallel execution |
| `--no-worker-output` | Hide output from worker processes |
| `--fail-fast` | Stop on first test failure |
| `--no-aggregate-coverage` | Don't combine coverage data from workers |

## Example Usage



```lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")
-- Register parallel with firmo
parallel.register_with_firmo(firmo)
-- Configure parallel options
parallel.configure({
  workers = 8,
  timeout = 30,
  fail_fast = true,
  verbose = false
})
-- Discover test files
local files = firmo.discover("./tests", "*_test.lua")
-- Run tests in parallel
local results = parallel.run_tests(files)
-- Display results
print("Tests run: " .. #results.files_run)
print("Total tests: " .. results.total)
print("Passed: " .. results.passed)
print("Failed: " .. results.failed)
print("Skipped: " .. results.skipped)
print("Total time: " .. string.format("%.2f", results.elapsed) .. " seconds")
```



## Result Structure


The results table returned by `parallel.run_tests()` has the following structure:


```lua
{
  passed = 42,           -- Number of passed tests
  failed = 2,            -- Number of failed tests
  skipped = 1,           -- Number of skipped tests
  pending = 0,           -- Number of pending tests
  total = 45,            -- Total number of tests
  elapsed = 12.5,        -- Total execution time in seconds
  files_run = {          -- Array of executed file paths
    "tests/file1_test.lua",
    "tests/file2_test.lua"
  },
  errors = {             -- Array of error objects
    {
      file = "tests/file2_test.lua",
      message = "expected 2 but got 3",
      traceback = "stack trace..."
    }
  },
  coverage = {           -- Combined coverage data (if enabled)
    ["lib/module1.lua"] = {
      lines = { [1] = 1, [2] = 1, ... },
      functions = { ... }
    }
  },
  worker_outputs = {     -- Raw output from worker processes
    "Output from worker 1...",
    "Output from worker 2..."
  }
}
```
