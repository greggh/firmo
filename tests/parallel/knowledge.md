# tests/parallel Knowledge

## Purpose

The `tests/parallel/` directory contains tests for validating Firmo's experimental parallel test execution feature, implemented in `lib/tools/parallel`. These tests focus on the module's core capability: running multiple test files concurrently as separate Lua processes. Key aspects tested include managing the configured number of worker processes, enforcing timeouts, applying fail-fast logic, capturing worker output, and aggregating basic test results based on parsing the text output from each worker process.

## Key Concepts

The main test file, `parallel_test.lua`, verifies the implemented features of `lib/tools/parallel`:

- **Core `run_tests` Functionality:** Tests exercise the `parallel.run_tests` function, providing it with lists of test files (typically created temporarily using `test_helper`) and varying the configured number of workers (`--workers` option) to ensure the correct number of processes are managed.
- **Timeout Enforcement (`--timeout`):** Tests verify that if a worker process (running a single test file) exceeds the specified timeout duration, the `parallel` module correctly identifies this (likely based on the exit code from `os.execute` combined with the OS `timeout` command) and reports it as a failure. This often involves creating temporary test files designed to hang or sleep longer than the timeout.
- **Fail Fast (`--fail-fast`):** Tests confirm that if the `--fail-fast` option is enabled, the entire parallel run terminates shortly after the first worker process reports a failure, rather than waiting for all other workers to complete.
- **Result Aggregation (from Text Output):** A significant focus is testing the aggregation of basic pass/fail/skip/pending counts. **Crucially**, these tests must account for the known limitation that `lib/tools/parallel` currently parses the *plain text output* captured from worker processes (looking for simple keywords like "PASS", "FAIL"), rather than using the structured JSON output it requests from the workers. Tests verify if these text-based counts are summed correctly.
- **Worker Output Capturing (`--show-worker-output`):** Tests check that the stdout/stderr streams from worker processes are captured into temporary files and can be retrieved or displayed.
- **Coverage Aggregation Attempt (`--aggregate-coverage`):** Includes tests for the code path attempting to merge coverage data from workers, while acknowledging this is likely unreliable due to the text-based result parsing potentially failing to extract the necessary coverage data.
- **Test Environment:** The tests make extensive use of `lib/tools/test_helper` (specifically `with_temp_test_directory` and `create_temp_test_directory`) to create controlled environments with temporary test files designed to exhibit specific behaviors (pass, fail with `error()`, hang, produce specific output) needed for validation.

## Usage Examples / Patterns (Illustrative Test Snippets from `parallel_test.lua`)

### Basic Parallel Run Test (Checking Aggregated Counts)

```lua
--[[
  Conceptual test verifying basic parallel execution and result aggregation (from text).
]]
local test_helper = require("lib.tools.test_helper")
local parallel = require("lib.tools.parallel")
local expect = require("lib.assertion.expect").expect

it("should run multiple tests in parallel and aggregate results", function()
  local files_map = {
    ["pass_test.lua"] = [[ it("passes", function() expect(true):to.be_truthy() end) print("PASS") ]], -- Needs text marker
    ["fail_test.lua"] = [[ it("fails", function() error("Failure!") end) print("FAIL") ]],          -- Needs text marker
    ["pass_also.lua"] = [[ it("passes too", function() expect(1).to.equal(1) end) print("PASS") ]],    -- Needs text marker
  }
  test_helper.with_temp_test_directory(files_map, function(dir_path, file_paths)
    -- Run with 2 workers
    local results, err = parallel.run_tests(file_paths, { workers = 2 })

    expect(err).to_not.exist()
    expect(results).to.exist()
    -- Asserts based on text parsing logic:
    expect(results.passed).to.equal(2)
    expect(results.failed).to.equal(1)
    expect(results.skipped).to.equal(0)
    expect(results.total).to.equal(3) -- Based on number of files run
  end)
end)
```

### Fail Fast Test

```lua
--[[
  Conceptual test verifying fail-fast behavior.
]]
local test_helper = require("lib.tools.test_helper")
local parallel = require("lib.tools.parallel")
local expect = require("lib.assertion.expect").expect

it("should stop early when fail_fast is enabled", function()
  local files_map = {
    ["fail_quick.lua"] = [[ print("FAIL") error("Quick fail") ]],
    ["pass_slow.lua"] = [[ os.execute("sleep 2") print("PASS") it("passes", function() end) ]], -- Sleep added
  }
  test_helper.with_temp_test_directory(files_map, function(dir_path, file_paths)
    local start_time = os.clock()
    local results, err = parallel.run_tests(file_paths, { workers = 2, fail_fast = true })
    local duration = os.clock() - start_time

    expect(err).to_not.exist() -- run_tests itself shouldn't error here
    expect(results).to.exist()
    expect(results.failed).to.be.greater_than_or_equal_to(1)
    -- Check that duration is short, indicating early exit
    expect(duration).to.be.less_than(1.9) -- Should stop before the 2s sleep finishes
  end)
end)
```

### Timeout Test

```lua
--[[
  Conceptual test verifying timeout enforcement.
]]
local test_helper = require("lib.tools.test_helper")
local parallel = require("lib.tools.parallel")
local expect = require("lib.assertion.expect").expect

it("should report failure for tests exceeding timeout", function()
  local files_map = {
    ["timeout_test.lua"] = [[ print("Starting sleep...") os.execute("sleep 3") print("Should not get here") ]],
  }
  test_helper.with_temp_test_directory(files_map, function(dir_path, file_paths)
    -- Run with 1 worker and a 1-second timeout
    local results, err = parallel.run_tests(file_paths, { workers = 1, timeout = 1 })

    expect(err).to_not.exist()
    expect(results).to.exist()
    expect(results.failed).to.be.greater_than_or_equal_to(1)
    -- Optionally, check results.errors or worker output for timeout indication
    -- (Depends on how the module reports timeout vs. other failures)
  end)
end)
```

**Note:** Examples using functions like `parallel.map`, `parallel.run_with_timeout`, `firmo.get_process_id` are **not valid** for the current `lib/tools/parallel` implementation and should be disregarded.

## Related Components / Modules

- **Module Under Test:** `lib/tools/parallel/knowledge.md` (and `lib/tools/parallel/init.lua`)
- **Test File:** `tests/parallel/parallel_test.lua`
- **Helper Modules:**
    - **`lib/tools/test_helper/knowledge.md`**: Essential for creating the temporary test files (`*.lua`) with specific pass/fail/hang behaviors needed to validate the parallel runner.
    - **`lib/tools/filesystem/knowledge.md`**: Used by `lib/tools/parallel` internally to manage temporary files for worker output capture, and by `test_helper` for test setup.
    - **`lib/tools/error_handler/knowledge.md`**: Used by `lib/tools/parallel` for handling errors during the orchestration of the parallel run.
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Test Implemented Features:** Focus tests on verifying the features that are actually implemented in `lib/tools/parallel`, such as process launching, timeout via `os.execute`, fail-fast logic, and the text-based result aggregation.
- **Control Worker Output for Parsing:** When testing result aggregation, the temporary test files created must produce simple, predictable text output (e.g., lines containing "PASS" or "FAIL") that aligns with the fragile parsing logic currently used in `lib/tools/parallel/init.lua`.
- **Isolate via `test_helper`:** Rely heavily on `with_temp_test_directory` to ensure each parallel test scenario runs with a clean, independent set of temporary test files.

## Troubleshooting / Common Pitfalls (Optional)

- **Incorrect Aggregated Counts:** This is the most likely area for failures due to the reliance on text-output parsing.
    - **Debugging:** Run the failing test with the `--show-worker-output` option enabled (if test setup allows passing it down) or modify the test to capture/print the `results.outputs` table. Compare the actual text output from workers with the parsing logic in `lib/tools/parallel/init.lua`. Ensure the temporary test files produce the exact expected keywords/patterns.
- **Timeout Test Failures:**
    - **Cause:** The OS `timeout` command might not be available or might behave differently across platforms. The way `os.execute` reports the timeout status might vary. Delays introduced via `os.execute("sleep ...")` can also have slight timing variations.
    - **Debugging:** Check if the `timeout` command exists and works manually on the test system. Inspect the exit code returned by `os.execute` in the test. Add logging within `lib/tools/parallel/init.lua` to see how timeouts are detected. Increase timeout duration slightly to account for system variance.
- **Coverage Aggregation Tests Failing:**
    - **Cause:** Very likely due to the unreliable text-parsing failing to extract coverage data tables correctly from worker output.
    - **Debugging:** This feature may be inherently flaky until the result communication is switched to use the intended JSON format. Focus on ensuring the *attempt* to aggregate runs, rather than the perfect correctness of the merged data.
- **Debugging Worker Process Errors:** Identifying why a separate `lua` process failed can be hard.
    - **Solution:** Use `--show-worker-output`. Ensure the temporary test files used in the failing scenario produce clear error messages to stderr/stdout if they fail intentionally. Temporarily run the problematic temporary test file directly (`lua /tmp/path/to/temp_test.lua`) to debug its specific error.
