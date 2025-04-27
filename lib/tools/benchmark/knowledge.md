# lib/tools/benchmark Knowledge

## Purpose

The `lib/tools/benchmark` module provides utilities for measuring and analyzing the performance of Lua code within the Firmo ecosystem. It allows developers to measure function execution time, track basic memory usage changes, organize benchmarks into suites, compare the results of different runs, and even generate large sets of dummy test files specifically for benchmarking the performance of the Firmo test runner itself.

## Key Concepts

- **`measure` Function:** This is the core function for performance measurement. It runs a target function multiple times, handling warmup iterations (to account for JIT compilation or caching effects), optional garbage collection calls before runs, and timing using high-resolution timers (`socket.gettime` or `os.clock`) when available. It also tracks approximate memory usage changes by comparing `collectgarbage("count")` before and after execution. The function returns a results table containing raw timings, memory deltas, and calculated statistics (mean, min, max, standard deviation).
- **`suite` Function:** Allows grouping multiple related benchmarks defined in a table structure. It manages the execution of each benchmark within the suite, merges configuration options, and provides a consolidated output.
- **`compare` Function:** Takes the result tables from two separate `benchmark.measure` runs and calculates the difference in performance, reporting ratios and percentage changes for both execution time and memory usage.
- **`generate_large_test_suite` Function:** A specialized utility designed to create a large number of `.lua` files containing nested `describe` and `it` blocks. This is primarily used for stress-testing and analyzing the performance characteristics of the Firmo test discovery and execution engine.
- **Basic Memory Tracking:** It's important to note that the memory tracking performed by `measure` relies on `collectgarbage("count")`. This provides a basic indication of memory change but might not capture the full complexity of memory allocation patterns, especially with complex data structures or frequent allocations/deallocations.
- **Integration:** The benchmark module relies heavily on other Firmo tools:
    - `lib.tools.logging` for structured output and debugging information.
    - `lib.tools.error_handler` for robust operation, validation, and safe execution of benchmarked functions and I/O operations.
    - `lib.tools.filesystem` for creating directories and writing files when using `generate_large_test_suite`.
- **Unimplemented Features:** Several functions are documented in the source code (`init.lua`)'s `@class benchmark_module` section (e.g., `save_results`, `load_results`, `plot`, `histogram`, `async_time`) but are currently placeholders and are **not implemented**.

## Usage Examples / Patterns

### Pattern 1: Measuring a Simple Function

```lua
--[[
  Demonstrates using benchmark.measure to time a simple function.
]]
local benchmark = require("lib.tools.benchmark")

local function calculate_sum(n)
  local sum = 0
  for i = 1, n do
    sum = sum + i
  end
  return sum
end

-- Measure the function, running it 10 times after 2 warmup runs
local results = benchmark.measure(calculate_sum, {1000}, {
  iterations = 10,
  warmup = 2,
  label = "Sum Calculation Benchmark"
})

-- Print the results to the console
benchmark.print_result(results)
```

### Pattern 2: Running a Benchmark Suite

```lua
--[[
  Shows how to define and run a suite of benchmarks.
]]
local benchmark = require("lib.tools.benchmark")

local function string_concat(count)
  local s = ""
  for i = 1, count do
    s = s .. "a"
  end
  return s
end

local function table_insert(count)
  local t = {}
  for i = 1, count do
    table.insert(t, "a")
  end
  return table.concat(t)
end

local my_suite = {
  name = "String vs Table Concatenation",
  benchmarks = {
    {
      name = "String Concatenation",
      func = string_concat,
      args = { 500 },
      options = { iterations = 5 }
    },
    {
      name = "Table Insert/Concat",
      func = table_insert,
      args = { 500 },
      options = { iterations = 5 }
    },
  }
}

-- Run the suite (results will be printed to console by default)
local suite_results = benchmark.suite(my_suite)
```

### Pattern 3: Comparing Two Benchmark Results

```lua
--[[
  Example of comparing the results from two measure calls.
]]
local benchmark = require("lib.tools.benchmark")

local function method_a() os.execute("sleep 0.1") end
local function method_b() os.execute("sleep 0.2") end

local result_a = benchmark.measure(method_a, {}, { iterations = 3, label = "Method A" })
local result_b = benchmark.measure(method_b, {}, { iterations = 3, label = "Method B" })

-- Compare the results (comparison printed to console by default)
local comparison = benchmark.compare(result_a, result_b)

-- Access comparison data if needed
-- print(string.format("Time Ratio: %.2fx", comparison.time_ratio))
```

### Pattern 4: Generating a Large Test Suite

```lua
--[[
  Basic example of generating dummy test files for runner benchmarking.
]]
local benchmark = require("lib.tools.benchmark")

-- Generate 10 files, each aiming for ~20 tests, 2 levels deep
-- Files will be created in './benchmark_tests' by default
local generation_summary = benchmark.generate_large_test_suite({
  file_count = 10,
  tests_per_file = 20,
  nesting_level = 2,
  -- output_dir = "./my_generated_tests" -- Optional: specify output dir
})

-- generation_summary contains details like { output_dir, file_count, successful_files, ... }
if generation_summary then
  print("Generated " .. generation_summary.successful_files .. " benchmark test files.")
end
```

## Related Components / Modules

- **`lib/tools/benchmark/init.lua`**: The source code implementation of this module.
- **`docs/api/tools/logging.md`**: The benchmark module uses the logging system for output. (Or link `lib/tools/logging/knowledge.md` if preferred)
- **`docs/api/tools/error_handler.md`**: Used extensively for robust operations and input validation. (Or link `lib/tools/error_handler/knowledge.md`)
- **`docs/api/tools/filesystem.md`**: Used by `generate_large_test_suite` for file and directory operations. (Or link `lib/tools/filesystem/knowledge.md`)
