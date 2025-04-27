# lib/tools/parallel Knowledge

## Purpose

The `lib/tools/parallel` module provides functionality to execute Firmo test files concurrently by launching multiple, independent Lua processes. The primary goal is to leverage multi-core processors to potentially speed up the overall execution time of a test suite compared to running files sequentially in a single process. This feature is primarily accessed through the main Firmo command-line interface via the `--parallel` (or `-p`) flag.

## Key Concepts

- **Process-Based Parallelism:** The fundamental approach is to run each test file in its own operating system process. A new `lua` interpreter instance is launched for each file. This provides strong isolation between test files (no shared Lua state) but incurs overhead for process creation and communication (primarily via capturing output). This differs from concurrency models using threads or coroutines within a single process.

- **Worker Management (`M.run_tests`):** This is the core function that orchestrates parallel execution. It manages a pool of worker processes, up to the limit specified by the `workers` configuration option. It iterates through the list of test files, launching a new worker process (via the internal `run_test_file` function) for each file as workers become available. It waits for workers to complete and aggregates their results.

- **Configuration (`M.configure`):** Key settings influencing parallel runs are managed via `lib.core.central_config` and can be overridden by specific CLI flags. The main options include:
    - `workers` (number, default: 4): The maximum number of concurrent Lua processes to launch. Set via `--workers <num>`.
    - `timeout` (number, default: 60): The maximum time in seconds allowed for a single test file's process to complete before being potentially terminated by the OS `timeout` command. Set via `--timeout <sec>`.
    - `fail_fast` (boolean, default: false): If `true`, the entire parallel run stops immediately after the first worker process reports a failure (non-zero exit code or failed tests). Set via `--fail-fast`.
    - `show_worker_output` (boolean, default: true): If `true`, the captured standard output and standard error from each worker process is printed to the console after the worker finishes. Use `--no-worker-output` to disable.
    - `aggregate_coverage` (boolean, default: true): If `true` and coverage is enabled (`--coverage`), the module attempts to merge coverage data reported by individual workers. Use `--no-aggregate-coverage` to disable. **Note:** Reliability depends on accurate result parsing (see below).
    - `verbose`, `debug` (boolean): Control the level of diagnostic logging from the parallel module itself. Set via `--verbose-parallel`.

- **Worker Execution (`run_test_file` - internal):** This internal helper function handles launching and monitoring a single test file process:
    1.  **Command Construction:** It builds an OS command string like `timeout <N> lua <test_file> [options] --results-format json`, including flags passed down like `--coverage`, `--tag`, `--filter`.
    2.  **Output Redirection:** It redirects both stdout and stderr of the worker command to a temporary file created using `lib.tools.filesystem.temp_file`.
    3.  **Execution:** It runs the command using `os.execute`.
    4.  **Output Capture:** After execution, it reads the content of the temporary output file.
    5.  **Result Parsing (Known Issue):** **CRITICAL:** Although the worker is invoked with `--results-format json`, the current implementation of `run_test_file` **ignores the JSON output** and instead **parses the captured plain text output** using simple string matching for lines containing "PASS", "FAIL", "SKIP", "PENDING" to count test results. It also attempts to extract basic failure messages. This text parsing is fragile and prone to errors if the test runner's output format changes or if tests produce complex output. It also means rich details like individual test timings or structured errors from workers are lost.
    6.  **Return Value:** Returns a table containing the parsed/approximated results (`total`, `passed`, `failed`, etc.), the raw captured output string, the total time elapsed for the worker process, and a success flag based on the `os.execute` exit code.

- **Result Aggregation (`Results` class):** An internal helper class (`Results`) is used within `M.run_tests` to accumulate the results from all completed workers. It sums the test counts (`passed`, `failed`, etc.), tracks the total elapsed time, collects basic error messages parsed from worker output, and stores the raw output strings from each worker. It also contains logic to merge coverage data tables if `aggregate_coverage` is enabled, although the effectiveness is limited by the unreliable text-based result parsing which might not correctly provide the per-worker coverage data.

- **CLI Integration (`register_with_firmo`):** This function enables the parallel feature in the main `test.lua` script. It patches the `firmo.cli_run` function. When the `--parallel` or `-p` flag is detected:
    1.  The patched `cli_run` parses parallel-specific arguments (`--workers`, `--timeout`, etc.).
    2.  It discovers test files using `firmo.discover` if none were explicitly provided.
    3.  It invokes `parallel.run_tests` with the file list and combined options.
    4.  After `run_tests` completes, it prints the aggregated summary results (counts, total time) to the console.
    5.  If coverage was enabled and aggregated, it attempts to trigger coverage report generation via `firmo.reporting`.
    6.  It returns an overall status (`true` if `aggregated_results.failed == 0`, `false` otherwise).
    The function also patches `firmo.show_help` to include documentation for the parallel-related CLI flags.

- **Unimplemented Features:** A significant number of functions documented in the source code's `@class parallel_module` header are currently **placeholders and NOT IMPLEMENTED**. These include potentially useful features like: `get_optimal_workers`, `run_file` (as a public API), `aggregate_results` (as a public API), `cancel_all`, `is_running`, `get_active_processes`, `combine_coverage` (as a public API), `monitor_process`, `test_runner`. Users should not rely on these functions.

## Usage Examples / Patterns

The primary way to use this module is through the command line:

### Pattern 1: Basic Parallel Run

```bash
# Run all tests in ./tests using default parallel settings (4 workers)
lua test.lua --parallel
# or shorthand:
lua test.lua -p
```

### Pattern 2: Specifying Worker Count and Fail Fast

```bash
# Run tests using 8 worker processes and stop immediately on the first failure
lua test.lua --parallel --workers 8 --fail-fast
# or shorthand:
lua test.lua -p -w 8 --fail-fast
```

### Pattern 3: Parallel Run with Coverage

```bash
# Run tests in parallel and attempt to aggregate coverage data
lua test.lua --parallel --coverage tests/unit/
# or shorthand:
lua test.lua -p -c tests/unit/

# Run parallel coverage but disable aggregation (useful if aggregation fails)
lua test.lua -p -c --no-aggregate-coverage
```

### Pattern 4: Programmatic Use (Less Common)

```lua
--[[
  Directly calling run_tests (requires careful setup).
  Note: This bypasses CLI integration and assumes necessary modules are loaded.
]]
local parallel = require("lib.tools.parallel")
local error_handler = require("lib.tools.error_handler")
local discover = require("lib.tools.discover") -- Needed to find files

-- Assume necessary modules (runner, etc.) are available
-- Assume configuration is done via central_config or parallel.configure()

local files_to_run, find_err = error_handler.try(discover.discover, "tests/")
if not files_to_run then
  print("Failed to discover files: " .. find_err.message)
  return
end

if #files_to_run.files == 0 then
  print("No test files found.")
  return
end

local results, run_err = error_handler.try(parallel.run_tests, files_to_run.files, {
  workers = 2,
  timeout = 30,
  coverage = true,
  -- other options...
})

if not results then
  print("Parallel execution failed critically: " .. run_err.message)
else
  print("Parallel run completed.")
  print("  Passed:", results.passed)
  print("  Failed:", results.failed)
  -- Process aggregated results
end
```

## Related Components / Modules

- **`lib/tools/parallel/init.lua`**: The source code implementation.
- **`lib/tools/cli/knowledge.md`**: Handles initial CLI flag parsing and invokes the parallel execution logic via the patched `cli_run`.
- **`scripts/runner.lua` Knowledge**: The main script environment that parallel mode operates within, replacing the normal sequential execution loop. Parallel mode relies on this environment having loaded core modules like `runner` and `discover`.
- **`lib/tools/discover/knowledge.md`**: Used by the patched CLI logic to find test files to distribute to workers.
- **`lib/tools/filesystem/knowledge.md` (`temp_file.lua`)**: Used internally by `run_test_file` to create temporary files for capturing worker process output.
- **`lib/tools/error_handler/knowledge.md`**: Used for handling errors during the setup and orchestration of parallel runs (though errors *within* workers are mostly inferred from exit codes and output).
- **`lib/tools/logging/knowledge.md`**: Used to log the progress and status of the parallel execution manager and potential errors.
- **`lib/core/central_config/knowledge.md`**: Manages configuration settings like `workers`, `timeout`, etc.
- **`lib/reporting/knowledge.md`**: The reporting system might be invoked by the patched CLI logic to generate reports from aggregated coverage data (if enabled and successfully aggregated).

## Best Practices / Critical Rules (Optional)

- **Use via CLI:** The most robust and intended way to use parallel execution is via the main script: `lua test.lua --parallel [options]`. Programmatic use requires more careful setup.
- **Tune Worker Count (`--workers`):** The optimal number of workers depends heavily on the number of CPU cores, the nature of the tests (CPU-bound vs I/O-bound), and system resources. Start with a number close to the physical core count and experiment. Too many workers can decrease performance due to context switching and resource contention.
- **Understand Overhead:** Creating separate processes for each test file introduces overhead. Parallel mode is most likely to provide speed benefits for:
    - Test suites with a large number of files.
    - Tests that are CPU-intensive.
    - Tests that involve significant waiting for I/O (network, disk).
    Very short/fast test files might actually run slower overall in parallel mode.
- **Ensure Test Isolation:** Tests intended for parallel execution **must be fully independent**. They cannot rely on shared Lua state, modify the same files without coordination, or interact with shared external resources (like databases) in ways that cause conflicts or race conditions. Non-isolated tests will likely become flaky when run in parallel.

## Troubleshooting / Common Pitfalls (Optional)

- **Inaccurate Results / Missing Coverage:** **MAJOR KNOWN ISSUE:** The current implementation relies on fragile text parsing of worker output instead of the intended JSON results. This can lead to incorrect counts of passed/failed/skipped tests and frequently causes coverage aggregation to fail or produce incomplete reports. **Workaround:** If accurate counts or coverage are critical, avoid using parallel mode or use `--no-aggregate-coverage` and potentially merge coverage data manually using external tools if needed.
- **Timeout Issues / Hung Processes:**
    - The `timeout` command used internally might not exist or work reliably on all operating systems (especially Windows without coreutils installed). Tests might exceed their intended timeout.
    - A worker process might hang indefinitely due to an issue in the test code itself.
    - **Debugging:** Increase the timeout (`--timeout <large_number>`). Use `--show-worker-output` and `--verbose-parallel` to identify which file might be causing hangs.
- **Coverage Aggregation Failure:** Often a symptom of the result parsing issue. Coverage data might not be correctly extracted from the worker output. **Workaround:** Run coverage non-parallelly, or use `--no-aggregate-coverage`.
- **Debugging Worker Failures:** If a test fails only in parallel mode:
    - Use `--show-worker-output` to see if the worker printed any specific errors.
    - Use `--fail-fast` to stop after the first failure.
    - Try running the specific failing file non-parallelly (`lua test.lua <failing_file>`) to see if the error is reproducible.
    - Suspect potential state isolation issues or race conditions if the failure only occurs randomly during parallel runs.
- **Resource Contention:** If the system becomes slow or unresponsive during parallel runs, try reducing the number of workers (`--workers <num>`).
- **Unimplemented Features:** Do not attempt to use functions like `cancel_all`, `monitor_process`, etc., as they are not implemented.
