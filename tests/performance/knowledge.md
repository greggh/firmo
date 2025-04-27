# tests/performance Knowledge

## Purpose

The `tests/performance/` directory contains tests specifically focused on measuring and analyzing the performance characteristics of the Firmo framework and its core components. These tests aim to quantify the overhead introduced by certain features (like module resetting or error handling), assess the framework's behavior under load (e.g., processing large files with code coverage enabled), and potentially establish performance baselines to track regressions or improvements over time.

## Key Concepts

The existing tests in this directory investigate several specific performance aspects:

- **Coverage Performance (`large_file_test.lua`):** This test measures the performance and memory usage of the `lib/coverage` system, particularly when processing a large Lua source file (`firmo.lua`). It uses manual timing via `os.clock()` and basic memory checks via `collectgarbage("count")` to assess the overhead of coverage initialization, runtime tracking during file execution, and statistics saving/loading.

- **Module Reset Overhead (`performance_test.lua`):** This test leverages the `lib.tools.benchmark.measure` function to compare the execution time impact of enabling versus disabling Firmo's module reset feature (`lib/core/module_reset`). It likely runs a series of module loads and modifications under both conditions and analyzes the difference in mean execution times.

- **Test Suite Size Impact (`performance_test.lua`):** This test uses `lib.tools.benchmark.generate_large_test_suite` to create sets of dummy test files representing small and large projects. It then employs `lib.tools.benchmark.measure` to quantify the time and memory resources consumed while running these different-sized suites, potentially also comparing the effect of enabling module reset.

- **Error Handling Performance (`performance_test.lua`):** This test uses `lib.tools.benchmark.measure` to evaluate the performance overhead associated with Firmo's error handling, specifically the common pattern of using `error_handler.try`. It likely benchmarks a function that repeatedly triggers and catches expected errors using fixtures from `tests/fixtures/common_errors.lua`.

## Usage Examples / Patterns (Illustrative Test Snippets)

### Manual Timing/Memory Measurement (like `large_file_test.lua`)

```lua
--[[
  Conceptual example of manual performance measurement within a test.
]]
local coverage = require("lib.coverage")
local expect = require("lib.assertion.expect").expect

it("measures coverage processing time and memory", function()
  local file_to_process = "firmo.lua" -- Example large file
  local start_mem = collectgarbage("count")
  local start_time = os.clock()

  -- Operation to measure (e.g., full coverage cycle)
  coverage.init()
  coverage.resume()
  local ok, err = pcall(dofile, file_to_process) -- Execute file
  coverage.save_stats()
  local loaded_stats = coverage.load_stats()
  coverage.shutdown()

  local end_time = os.clock()
  collectgarbage("collect") -- Run GC before final measurement
  local end_mem = collectgarbage("count")

  local duration = end_time - start_time
  local mem_increase = end_mem - start_mem

  print(string.format("Duration: %.4f s, Memory Increase: %.2f KB", duration, mem_increase))

  -- Assert against expected performance thresholds (adjust values as needed)
  expect(ok).to.be_truthy("dofile should succeed")
  expect(duration).to.be.less_than(5.0) -- Example threshold: 5 seconds
  expect(mem_increase).to.be.less_than(2048) -- Example threshold: 2 MB
end)
```

### Comparative Benchmarking (like `performance_test.lua`)

```lua
--[[
  Conceptual example using benchmark.measure for comparison.
]]
local benchmark = require("lib.tools.benchmark")
local expect = require("lib.assertion.expect").expect
local module_reset = require("lib.core.module_reset")

local function run_tasks_with_reset()
  module_reset.configure({ reset_modules = true })
  -- ... load modules, perform actions ...
  module_reset.reset() -- Simulate end of test
end

local function run_tasks_without_reset()
  module_reset.configure({ reset_modules = false })
   -- ... load modules, perform actions ...
   -- No module reset here
end

it("compares performance with and without module reset", function()
  local options = { iterations = 5, warmup = 1, label = "With Reset" }
  local results_with = benchmark.measure(run_tasks_with_reset, nil, options)

  options.label = "Without Reset"
  local results_without = benchmark.measure(run_tasks_without_reset, nil, options)

  expect(results_with).to.exist()
  expect(results_without).to.exist()

  -- Optional: Use compare function for detailed analysis
  local comparison = benchmark.compare(results_with, results_without)
  expect(comparison).to.exist()
  -- Assert based on comparison results (e.g., expect reset to be slower)
  expect(comparison.time_ratio).to.be.greater_than(1.0) -- Expect 'With Reset' (bench1) > 'Without Reset' (bench2)
end)
```

### Generating Test Suites (like `performance_test.lua`)

```lua
--[[
  Example using benchmark.generate_large_test_suite.
]]
local benchmark = require("lib.tools.benchmark")
local expect = require("lib.assertion.expect").expect

it("generates a test suite for benchmarking", function()
  local output_dir = "/tmp/generated_perf_tests"
  local summary, err = benchmark.generate_large_test_suite({
    file_count = 10,
    tests_per_file = 5,
    nesting_level = 2,
    output_dir = output_dir,
  })

  expect(err).to_not.exist()
  expect(summary).to.exist()
  expect(summary.successful_files).to.equal(10)
  expect(summary.output_dir).to.equal(output_dir)
  -- Clean up generated files afterwards...
  require("lib.tools.filesystem").delete_directory(output_dir)
end)
```

**Note:** Examples using unimplemented functions like `benchmark.new`, `benchmark.run`, `benchmark.track_memory` are **incorrect** and should be disregarded.

## Related Components / Modules

- **Modules Being Tested / Used:**
    - `lib/tools/benchmark/knowledge.md`: Provides the `measure`, `compare`, `generate_large_test_suite` functions used in `performance_test.lua`.
    - `lib/coverage/knowledge.md`: The coverage system whose performance is analyzed in `large_file_test.lua`.
    - `lib/core/module_reset/knowledge.md`: The module reset feature whose overhead is measured in `performance_test.lua`.
    - `lib/tools/error_handler/knowledge.md`: The error handling system whose performance is measured in `performance_test.lua`.
- **Test Files:**
    - `tests/performance/large_file_test.lua`
    - `tests/performance/performance_test.lua`
- **Fixtures:**
    - `tests/fixtures/common_errors.lua`: Used by `performance_test.lua` to trigger errors repeatedly.
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Interpret Results Carefully:** Performance measurements are sensitive to the host machine's hardware and current load. Focus on *relative* differences (e.g., Feature A is 10% slower than Feature B on *this* machine) rather than absolute time values. Run tests on a relatively idle machine for more stable results.
- **Use `lib/tools/benchmark` for Comparisons:** When comparing the performance of two approaches, prefer using `benchmark.measure` for both and then `benchmark.compare`. This provides better statistical analysis (mean, stddev) than simple manual timing with `os.clock()`.
- **Warmup Runs:** Leverage the `warmup` option in `benchmark.measure` to mitigate the impact of LuaJIT compilation, caching, or other initial setup costs on the measured results.
- **Document Baselines/Regressions:** If performance is critical, establish baseline measurements. Rerun performance tests periodically or in CI to detect significant regressions. Document expected performance characteristics or thresholds where applicable.

## Troubleshooting / Common Pitfalls (Optional)

- **High Variability in Results:** Performance tests can be "noisy".
    - **Cause:** System background activity, inconsistent CPU C-state transitions, GC timing variations, JIT behavior.
    - **Mitigation:** Run tests multiple times or increase the `iterations` count in `benchmark.measure`. Analyze the `mean` and `std_dev` (standard deviation) reported by the benchmark tool. A high `std_dev` relative to the `mean` indicates high variability. Run tests on a less loaded machine if possible.
- **Benchmark Tool Errors:**
    - **Cause:** Incorrect usage of `benchmark.measure`, `compare`, or `generate_large_test_suite`. Passing invalid arguments (e.g., non-functions to `measure`, non-result tables to `compare`).
    - **Solution:** Refer to `lib/tools/benchmark/knowledge.md` for correct API usage. Check the error messages returned by the benchmark functions.
- **Misinterpreting `collectgarbage("count")`:**
    - **Cause:** Treating the value from `collectgarbage("count")` as precise memory allocation. It only reflects memory used by the Lua state and is heavily influenced by when the garbage collector last ran.
    - **Solution:** Use this metric primarily for detecting *large* relative differences or potential memory leaks over many operations, not for fine-grained allocation tracking. Run `collectgarbage("collect")` before taking measurements for slightly more consistency, but understand its limitations.
- **Feature Interactions Affecting Performance:** A performance issue might not be in the feature being directly tested but in how it interacts with another system (e.g., coverage hooks slowing down code execution during a module reset test). Try isolating the features being benchmarked as much as possible or test specific combinations deliberately.
