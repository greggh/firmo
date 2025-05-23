# Benchmark Usage Guide

## Introduction

The benchmark module in Firmo provides tools for measuring and analyzing the performance of your code. Whether you're optimizing critical code paths, comparing different implementation approaches, or testing how your code scales, this module offers a comprehensive set of utilities to help you make informed decisions.

## Getting Started

### Basic Benchmarking

The simplest way to benchmark a function is using the `measure` function:

```lua
local benchmark = require("lib.tools.benchmark")
local function calculate_sum(n)
  local sum = 0
  for i = 1, n do
    sum = sum + i
  end
  return sum
end
local result = benchmark.measure(calculate_sum, {1000000}, {
  iterations = 5,  -- Run the function 5 times
  label = "Sum calculation"
})
-- Print the results
benchmark.print_result(result)
```

This measures the execution time and memory usage of the `calculate_sum` function, running it multiple times to provide statistical information.

### Understanding Results

The `measure` function returns a detailed results table:

```lua
-- Hypothetical output (abbreviated)
{
  times = {0.0543, 0.0541, 0.0544, 0.0542, 0.0540},  -- Individual run times
  memory = {0.23, 0.21, 0.22, 0.21, 0.22},           -- Memory usage per run (KB)
  label = "Sum calculation",
  iterations = 5,
  warmup = 1,
  time_stats = {
    mean = 0.0542,    -- Average execution time (seconds)
    min = 0.0540,     -- Fastest run
    max = 0.0544,     -- Slowest run
    std_dev = 0.00015 -- Standard deviation (lower means more consistent)
  },
  memory_stats = {
    mean = 0.218,     -- Average memory usage (KB)
    min = 0.21,       -- Minimum memory usage
    max = 0.23,       -- Maximum memory usage
    std_dev = 0.0084  -- Standard deviation
  }
}
```

The `print_result` function formats these results for human readability:

```text
Mean execution time: 54.20 ms
Min: 54.00 ms  Max: 54.40 ms
Std Dev: 0.15 ms (0.3%)
Mean memory delta: 0.22 KB
Memory Min: 0.21 KB  Max: 0.23 KB
```

## Advanced Usage

### Comparing Implementations

One of the most common use cases is comparing different implementations:

```lua
-- String concatenation approach
local concat_result = benchmark.measure(function(size)
  local result = ""
  for i = 1, size do
    result = result .. "a"
  end
  return result
end, {10000}, {label = "String concatenation"})
-- Table concat approach
local table_result = benchmark.measure(function(size)
  local parts = {}
  for i = 1, size do
    parts[i] = "a"
  end
  return table.concat(parts)
end, {10000}, {label = "Table concat"})
-- Compare the results
benchmark.compare(concat_result, table_result)
```

The `compare` function will output detailed information about the relative performance:

```text
Benchmark Comparison: String concatenation vs Table concat
--------------------------------------------------------------------------------
Execution Time:
  String concatenation: 18.24 ms
  Table concat: 0.87 ms
  Ratio: 20.97x
  Table concat is 95.2% faster
Memory Usage:
  String concatenation: 532.45 KB
  Table concat: 156.78 KB
  Ratio: 3.40x
  Table concat uses 70.6% less memory
```

### Running Benchmark Suites

For more complex scenarios, you can define a benchmark suite:

```lua
local suite_results = benchmark.suite({
  name = "String Processing Techniques",
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
      args = {10000}
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
      args = {10000}
    },
    {
      name = "String format with repeat",
      func = function(size)
        return string.rep("a", size)
      end,
      args = {10000}
    }
  }
}, {
  iterations = 5,
  warmup = 2
})
```

This makes it easy to compare multiple approaches in a single operation.

### Generating Test Suites

For testing the performance of larger test suites, you can use the test suite generator:

```lua
local suite = benchmark.generate_large_test_suite({
  file_count = 10,            -- Create 10 test files
  tests_per_file = 20,        -- Each with 20 tests
  nesting_level = 3,          -- With 3 levels of nesting
  output_dir = "/tmp/tests"   -- In this directory
})
print("Generated " .. suite.total_tests .. " tests in " .. suite.output_dir)
```

This is especially useful for evaluating test runner performance or optimizing large test suites.

## Best Practices

### 1. Use Warmup Iterations

Always use warmup iterations (at least 1-2) to allow the Lua VM to optimize code before measuring:

```lua
local result = benchmark.measure(my_function, args, {
  iterations = 10,
  warmup = 3  -- Three warmup iterations before measuring
})
```

This is especially important when using LuaJIT, as the JIT compiler needs some iterations to optimize the code.

### 2. Run Multiple Iterations

Single measurements can be misleading due to system variability. Always use multiple iterations to get statistical information:

```lua
local result = benchmark.measure(my_function, args, {
  iterations = 20  -- More iterations give more reliable statistics
})
-- Check the standard deviation to see consistency
print("Standard deviation: " .. result.time_stats.std_dev)
```

A high standard deviation relative to the mean indicates inconsistent performance, which might require investigation.

### 3. Control Garbage Collection

Memory allocation can significantly impact benchmark results. Use the `gc_before` option to control when garbage collection happens:

```lua
local result = benchmark.measure(my_function, args, {
  gc_before = true  -- Force GC before each run
})
```

You might want to run benchmarks both with and without forced GC to understand the impact of memory management on your code.

### 4. Isolate What You're Measuring

Make sure you're only measuring what you intend to measure:

```lua
-- BAD: Setup work contaminates the measurement
local result = benchmark.measure(function()
  -- Setup work
  local data = prepare_large_data_structure()

  -- Actual work we want to measure
  return process_data(data)
end)
-- GOOD: Only measure the specific operation
local data = prepare_large_data_structure()
local result = benchmark.measure(function(input_data)
  return process_data(input_data)
end, {data})
```

### 5. Consider System Load

System load can affect benchmark results. For critical measurements:

- Close other applications
- Run the benchmark multiple times
- Be aware of background processes or services

## Integration with Firmo

The benchmark module can be registered with the Firmo framework for easier usage in tests:

```lua
local firmo = require("firmo")
local benchmark = require("lib.tools.benchmark")
-- Register with Firmo
benchmark.register_with_firmo(firmo)
-- Now you can use it directly
describe("Performance tests", function()
  it("should process data efficiently", function()
    local result = firmo.benchmark.measure(function()
      -- Code to benchmark
    end)

    expect(result.time_stats.mean).to.be_less_than(0.1)  -- Assert it's fast enough
  end)
end)
```

## Troubleshooting

### Inconsistent Results

If you're seeing highly variable results (high standard deviation):

1. **Increase iterations**: More samples provide better statistical information
2. **Check for external factors**: Background processes, system load, etc.
3. **Isolate your code**: Make sure external resources aren't affecting the measurement
4. **Warm up more**: Try increasing warmup iterations, especially for JIT-compiled code

### Memory Measurement Issues

Memory measurement depends on Lua's `collectgarbage("count")` function, which has some limitations:

1. It only reports Lua-allocated memory, not external resources
2. The resolution is in kilobytes
3. It may not capture short-lived allocations between GC cycles

For more precise memory measurement, consider using:

```lua
-- Measure memory growth over multiple iterations
local function measure_memory_growth(func, iterations)
  collectgarbage("collect")
  local start = collectgarbage("count")

  for i = 1, iterations do
    func()
  end

  collectgarbage("collect")
  local finish = collectgarbage("count")

  return (finish - start) / iterations  -- Average growth per iteration
end
```

### Benchmarking Asynchronous Code

The benchmark module is designed for synchronous code. For asynchronous operations, you'll need to adapt:

```lua
local async_results = {}
-- Start timing
local start_time = os.time()
-- Run the async function with a callback that records completion time
my_async_function(function(result)
  local end_time = os.time()
  table.insert(async_results, {
    duration = end_time - start_time,
    result = result
  })

  -- If we've collected all results, calculate statistics
  if #async_results == total_expected then
    -- Process results...
  end
end)
```

## Conclusion

The benchmark module provides a powerful toolkit for measuring and optimizing your code's performance. By using the techniques described in this guide, you can make informed decisions about implementation approaches, identify bottlenecks, and ensure your code meets performance requirements.
Remember that performance optimization should typically come after correctness and maintainability. Benchmark to identify real issues, not to prematurely optimize working code.
