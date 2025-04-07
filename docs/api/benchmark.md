# Benchmark API Reference

## Overview

The Benchmark module provides comprehensive utilities for measuring and analyzing the performance of Lua code. It offers statistical analysis, memory tracking, and comparative benchmarking capabilities to help identify bottlenecks and optimize performance.

## Module: `lib.tools.benchmark`

```lua
local benchmark = require("lib.tools.benchmark")
```

### Configuration Options

The benchmark module provides several configuration options that control its behavior:

```lua
benchmark.options = {
  iterations = 5,      -- Default iterations for each benchmark
  warmup = 1,          -- Warmup iterations
  precision = 6,       -- Decimal precision for times
  report_memory = true, -- Report memory usage
  report_stats = true,  -- Report statistical information
  gc_before = true,     -- Force GC before benchmarks
  include_warmup = false, -- Include warmup iterations in results
}
```

## Core Functions

### `benchmark.measure(func, args, options)`

Measures the execution time and performance metrics of a function.

**Parameters:**
- `func` (function): The function to benchmark
- `args` (table, optional): Arguments to pass to the function
- `options` (table, optional): Benchmark options
  - `iterations` (number): Number of iterations to run (default: 5)
  - `warmup` (number): Number of warmup iterations (default: 1)
  - `gc_before` (boolean): Force garbage collection before each run (default: true)
  - `include_warmup` (boolean): Include warmup iterations in results (default: false)
  - `label` (string): Name for this benchmark (default: "Benchmark")

**Returns:**
- `results` (table): Detailed benchmark results including:
  - `times` (table): Array of execution times for each iteration
  - `memory` (table): Array of memory usage deltas for each iteration
  - `label` (string): Benchmark name
  - `iterations` (number): Number of iterations run
  - `warmup` (number): Number of warmup iterations run
  - `time_stats` (table): Statistical analysis of execution times
    - `mean` (number): Average execution time
    - `min` (number): Minimum execution time
    - `max` (number): Maximum execution time
    - `std_dev` (number): Standard deviation of execution times
    - `count` (number): Number of samples
    - `total` (number): Total execution time
  - `memory_stats` (table): Statistical analysis of memory usage
    - `mean` (number): Average memory usage in KB
    - `min` (number): Minimum memory usage in KB
    - `max` (number): Maximum memory usage in KB
    - `std_dev` (number): Standard deviation of memory usage
    - `count` (number): Number of samples
    - `total` (number): Total memory usage

**Example:**

```lua
local function test_function(iterations)
  local sum = 0
  for i = 1, iterations do
    sum = sum + i
  end
  return sum
end

local results = benchmark.measure(test_function, {1000}, {
  iterations = 10,
  label = "Sum calculation"
})

print("Average execution time: " .. results.time_stats.mean .. " seconds")
```

### `benchmark.suite(suite_def, options)`

Runs a benchmark suite containing multiple benchmark cases.

**Parameters:**
- `suite_def` (table): Suite definition with name and test cases
  - `name` (string): Name of the benchmark suite
  - `benchmarks` (table): Array of benchmark definitions
    - Each benchmark should have:
      - `name` (string): Benchmark name
      - `func` (function): Function to benchmark
      - `args` (table, optional): Arguments to pass to the function
      - `options` (table, optional): Per-benchmark options
- `options` (table, optional): Global options for all benchmarks in the suite

**Returns:**
- `results` (table): Combined results from all benchmark cases
  - `name` (string): Suite name
  - `benchmarks` (table): Array of individual benchmark results
  - `start_time` (number): Suite start timestamp
  - `end_time` (number): Suite end timestamp
  - `duration` (number): Total duration in seconds
  - `options` (table): Options used for the suite
  - `errors` (table): Any errors encountered

**Example:**

```lua
local suite_results = benchmark.suite({
  name = "String Operations",
  benchmarks = {
    {
      name = "String concatenation",
      func = function(size)
        local result = ""
        for i = 1, size do
          result = result .. "a"
        end
        return result
      end,
      args = {1000}
    },
    {
      name = "Table concat",
      func = function(size)
        local parts = {}
        for i = 1, size do
          parts[i] = "a"
        end
        return table.concat(parts)
      end,
      args = {1000}
    }
  }
}, {
  iterations = 5,
  warmup = 2
})
```

### `benchmark.compare(benchmark1, benchmark2, options)`

Compares two benchmark results and calculates performance differences.

**Parameters:**
- `benchmark1` (table): First benchmark result (from `benchmark.measure`)
- `benchmark2` (table): Second benchmark result (from `benchmark.measure`)
- `options` (table, optional): Comparison options
  - `silent` (boolean): Don't print results to console (default: false)

**Returns:**
- `comparison` (table): Detailed comparison between benchmarks
  - `benchmarks` (table): Array of the two benchmark results
  - `time_ratio` (number): Ratio of execution times (benchmark1 / benchmark2)
  - `memory_ratio` (number): Ratio of memory usage (benchmark1 / benchmark2)
  - `faster` (string): Label of the faster benchmark
  - `less_memory` (string): Label of the benchmark using less memory
  - `time_percent` (number): Percentage difference in execution time
  - `memory_percent` (number): Percentage difference in memory usage

**Example:**

```lua
local string_concat = benchmark.measure(function(size)
  local result = ""
  for i = 1, size do
    result = result .. "a"
  end
  return result
end, {1000}, {label = "String concatenation"})

local table_concat = benchmark.measure(function(size)
  local parts = {}
  for i = 1, size do
    parts[i] = "a"
  end
  return table.concat(parts)
end, {1000}, {label = "Table concat"})

local comparison = benchmark.compare(string_concat, table_concat)
print(comparison.faster .. " is " .. comparison.time_percent .. "% faster")
```

### `benchmark.print_result(result, options)`

Prints formatted benchmark results to the console.

**Parameters:**
- `result` (table): Benchmark result from `benchmark.measure`
- `options` (table, optional): Formatting options
  - `precision` (number): Decimal precision for formatting (default: 6)
  - `report_memory` (boolean): Include memory usage (default: true)
  - `report_stats` (boolean): Include statistical information (default: true)
  - `quiet` (boolean): Don't print to console (default: false)

**Example:**

```lua
local result = benchmark.measure(function()
  -- Code to benchmark
  local sum = 0
  for i = 1, 1000000 do
    sum = sum + i
  end
  return sum
end, {}, {label = "Sum calculation"})

benchmark.print_result(result, {report_stats = true})
```

### `benchmark.generate_large_test_suite(options)`

Generates a large test suite for benchmarking purposes.

**Parameters:**
- `options` (table, optional): Generation options
  - `file_count` (number): Number of test files to generate (default: 100)
  - `tests_per_file` (number): Number of tests per file (default: 50)
  - `nesting_level` (number): Depth of nested describe blocks (default: 3)
  - `output_dir` (string): Directory for generated files (default: "./benchmark_tests")
  - `silent` (boolean): Don't print console output (default: false)

**Returns:**
- `suite` (table): Generated test suite definition
  - `output_dir` (string): Output directory path
  - `file_count` (number): Number of files requested
  - `successful_files` (number): Number of files successfully created
  - `failed_files` (number): Number of files that failed to create
  - `tests_per_file` (number): Tests per file
  - `total_tests` (number): Total number of tests generated

**Example:**

```lua
local suite = benchmark.generate_large_test_suite({
  file_count = 10,
  tests_per_file = 20,
  output_dir = "/tmp/benchmark_tests"
})

print("Generated " .. suite.total_tests .. " tests in " .. suite.output_dir)
```

### `benchmark.register_with_firmo(firmo)`

Registers benchmark functionality with the firmo framework.

**Parameters:**
- `firmo` (table): The firmo framework instance

**Returns:**
- The firmo instance with the benchmark module attached

**Example:**

```lua
local firmo = require("firmo")
local benchmark = require("lib.tools.benchmark")

benchmark.register_with_firmo(firmo)

-- Now benchmark can be accessed via firmo.benchmark
firmo.benchmark.measure(function() return 1 + 1 end)
```

## Utility Functions

### `format_time(time_seconds)`

*Internal function that formats time values with appropriate units.*

### `calculate_stats(measurements)`

*Internal function that calculates statistical metrics from measurement data.*

### `deep_clone(t)`

*Internal function that creates a deep copy of a table.*

### `high_res_time()`

*Internal function that returns high-resolution time with the best available precision.*

## Error Handling

The benchmark module has comprehensive error handling for all operations:

1. **Input Validation**: All public functions validate their inputs and return appropriate error messages for invalid parameters.

2. **Safe Execution**: Benchmark code execution is protected to prevent crashes if the benchmarked function throws errors.

3. **Resource Protection**: Memory measurement operations are protected against failures.

4. **Fallback Mechanisms**: When high-precision timing is unavailable, the module falls back to lower-precision alternatives.

5. **Safe I/O**: Console output operations use protected I/O functions to prevent crashes.

## Performance Considerations

1. **Warmup Iterations**: The module supports warmup iterations to prime caches and JIT compilation before measurement.

2. **Garbage Collection**: Optionally forces garbage collection before benchmarks to reduce interference.

3. **Statistical Analysis**: Calculates mean, min, max, and standard deviation to help identify performance variability.

4. **Memory Tracking**: Measures memory usage changes during benchmark execution.

## Version Information

The benchmark module follows semantic versioning and includes a `_VERSION` field with the current version.