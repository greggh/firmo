# Benchmark Module Configuration

This document describes the comprehensive configuration options for the firmo benchmark module, which provides precise performance measurement and analysis tools for code optimization.

## Overview

The benchmark module provides a robust system for measuring code performance with support for:

- Multiple iteration benchmarking with statistical analysis
- Memory usage tracking
- Warmup iterations to prime caches and JIT
- Comparative benchmarking of multiple implementations
- Human-readable formatting of results
- Integration with the central configuration system

## Configuration Options

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `iterations` | number | `5` | Default number of iterations for each benchmark. |
| `warmup` | number | `1` | Number of warmup iterations before measurement. |
| `precision` | number | `6` | Decimal precision for timing values. |
| `report_memory` | boolean | `true` | Report memory usage in benchmark results. |
| `report_stats` | boolean | `true` | Report statistical information (median, min/max, etc.). |
| `gc_before` | boolean | `true` | Force garbage collection before benchmarks. |
| `include_warmup` | boolean | `false` | Include warmup iterations in results. |

## Configuration in .firmo-config.lua

You can configure the benchmark module in your `.firmo-config.lua` file:

```lua
return {
  -- Benchmark configuration
  benchmark = {
    -- Core measurement options
    iterations = 10,            -- Run 10 iterations for more reliable results
    warmup = 3,                 -- Run 3 warmup iterations
    precision = 8,              -- Higher precision for timing values

    -- Reporting options
    report_memory = true,       -- Report memory usage
    report_stats = true,        -- Include statistical data

    -- Runtime behavior
    gc_before = true,           -- Force GC before benchmarks
    include_warmup = false,     -- Don't include warmup in results

    -- Default output format
    output_format = "markdown", -- Generate markdown-formatted output
    save_results = true,        -- Automatically save results
    results_dir = "benchmarks"  -- Directory for benchmark results
  }
}
```

## Programmatic Configuration

You can also configure the benchmark module programmatically:

```lua
local benchmark = require("lib.tools.benchmark")
-- Basic configuration
benchmark.configure({
  iterations = 10,
  warmup = 2,
  report_memory = true
})
-- Reset to defaults
benchmark.reset()
```

## Benchmark Execution 

Control how benchmarks execute:

```lua
-- Run a benchmark with custom options
local results = benchmark.run("my_benchmark", function()
  -- Code to benchmark
  local result = 0
  for i = 1, 1000 do
    result = result + i
  end
  return result
end, {
  iterations = 20,        -- More iterations for this specific benchmark
  warmup = 5,             -- More warmup runs
  gc_before = true,       -- Force GC before running
  report_memory = true    -- Track memory usage
})
-- Access benchmark results
print("Mean time: " .. results.time)
print("Median time: " .. results.median)
print("Memory used: " .. results.memory_used .. " KB")
print("Standard deviation: " .. results.stddev)
```

## Comparative Benchmarking

Configure how benchmark comparisons work:

```lua
-- Create a benchmark suite for comparison
local suite_results = benchmark.suite("String Concatenation", {
  ["String concat"] = function()
    local result = ""
    for i = 1, 1000 do
      result = result .. tostring(i)
    end
    return result
  end,

  ["Table insert + concat"] = function()
    local parts = {}
    for i = 1, 1000 do
      table.insert(parts, tostring(i))
    end
    return table.concat(parts)
  end
}, {
  iterations = 10,
  warmup = 3,
  report_memory = true
})
-- Compare results
local comparison = benchmark.compare(suite_results)
-- Get the fastest implementation
print("Fastest: " .. comparison.fastest)
-- Get the most memory efficient
print("Memory efficient: " .. comparison.memory_efficient)
-- Check if differences are statistically significant
for name, significant in pairs(comparison.statistical_significance) do
  print(name .. " significant: " .. tostring(significant))
end
```

## Result Formatting

Configure how benchmark results are formatted:

```lua
-- Configure output formatting
benchmark.configure({
  output_format = "markdown",   -- Format for saved results
  precision = 8,                -- Decimal precision
  time_unit = "auto"            -- Automatically choose appropriate time unit
})
-- Print results in various formats
benchmark.print_results(results, "text")    -- Plain text
benchmark.print_results(results, "markdown") -- Markdown table
benchmark.print_results(results, "json")    -- JSON format
-- Save results to file
benchmark.save_results(results, "benchmark-results.md", "markdown")
```

## Memory Tracking

Configure memory usage tracking:

```lua
-- Enable memory tracking
benchmark.configure({
  report_memory = true,         -- Track memory usage
  track_memory_allocations = true, -- Track memory allocation counts
  memory_unit = "kb"            -- Use kilobytes for memory reporting
})
-- Manually track memory usage
local before = benchmark.memory()
-- Run some code that allocates memory
local after = benchmark.memory()
print("Memory used: " .. (after - before) .. " KB")
```

## Statistical Analysis

Configure statistical analysis of benchmark results:

```lua
-- Enable statistical reporting
benchmark.configure({
  report_stats = true,          -- Include statistical data
  confidence_interval = 0.95,   -- 95% confidence interval
  show_min_max = true,          -- Show minimum and maximum times
  show_median = true,           -- Show median time
  show_stddev = true            -- Show standard deviation
})
-- Calculate statistics manually
local stats = benchmark.stats(results)
print("Mean: " .. stats.mean)
print("Median: " .. stats.median)
print("StdDev: " .. stats.stddev)
print("95% CI: " .. stats.confidence_interval.lower .. " - " .. stats.confidence_interval.upper)
```

## Performance Visualization

Configure benchmark visualization:

```lua
-- Configure visualization options
benchmark.configure({
  plot_style = "ascii",         -- ASCII charts for terminal
  histogram_buckets = 10,       -- Number of buckets for histograms
  plot_height = 15              -- Height of generated plots
})
-- Generate ASCII chart
local chart = benchmark.plot(results, {
  title = "Performance Comparison",
  style = "ascii",
  sort = "time"                 -- Sort by execution time
})
print(chart)
-- Generate histogram
local histogram = benchmark.histogram(results.samples, 10)
local hist_chart = benchmark.plot(histogram, {
  title = "Time Distribution",
  style = "histogram"
})
print(hist_chart)
```

## Integration with Test Runner

The benchmark module integrates with Firmo's test framework:

```lua
-- In test files
local benchmark = require("lib.tools.benchmark")
describe("Performance Tests", function()
  it("should efficiently concatenate strings", function()
    -- Run benchmark
    local results = benchmark.run("string_concat", function()
      -- Code to benchmark
      local s = ""
      for i = 1, 1000 do
        s = s .. i
      end
      return s
    }, {
      iterations = 5,
      warmup = 2
    })

    -- Assert on performance
    expect(results.time).to.be_less_than(0.1) -- 100ms maximum
  end)

  it("should compare different implementations", function()
    -- Define implementations to compare
    local implementations = {
      ["Method A"] = function() /* ... */ end,
      ["Method B"] = function() /* ... */ end
    }

    -- Run comparative benchmark
    local results = benchmark.suite("Comparison", implementations)
    local comparison = benchmark.compare(results)

    -- Print results
    benchmark.print_results(results)

    -- Assert the expected fastest method
    expect(comparison.fastest).to.equal("Method B")
  end)
end)
```

## Best Practices

### Setting Appropriate Iterations

```lua
-- For quick initial benchmarks
benchmark.configure({
  iterations = 3,
  warmup = 1
})
-- For stable, production benchmarks
benchmark.configure({
  iterations = 30,
  warmup = 10
})
-- For microbenchmarks (very fast operations)
benchmark.configure({
  iterations = 100,
  warmup = 20
})
```

### Memory Management

```lua
-- Before I/O bound benchmarks
benchmark.configure({
  gc_before = false,         -- No need for GC in I/O benchmarks
  report_memory = false      -- Memory tracking less relevant
})
-- For memory-critical code
benchmark.configure({
  gc_before = true,
  report_memory = true,
  track_memory_allocations = true
})
```

### Statistically Valid Benchmarks

```lua
-- For high-variance operations
benchmark.configure({
  iterations = 50,             -- Many iterations for better statistics
  confidence_interval = 0.99,  -- Higher confidence interval
  show_stddev = true,          -- Show standard deviation
  outlier_rejection = true     -- Reject statistical outliers
})
-- Check if results are statistically significant
local is_significant = benchmark.is_significant(results1, results2, 0.95)
if is_significant then
  print("The performance difference is statistically significant")
else
  print("The performance difference is not statistically significant")
end
```

## Troubleshooting

### Common Issues

1. **High variance in results**:
   - Increase the number of iterations with `iterations = 30` or higher
   - Add more warmup iterations with `warmup = 10` or higher
   - Ensure the system is otherwise idle during benchmarking
   - Check for background processes or services
2. **Memory tracking inaccuracies**:
   - Force garbage collection before measurements with `gc_before = true`
   - Run multiple iterations and use the median with `report_stats = true`
   - Check if external factors are affecting memory (e.g., other processes)
3. **Benchmarks too slow**:
   - Reduce the number of iterations with `iterations = 5`
   - Reduce warmup with `warmup = 1`
   - Use smaller data sets for benchmarking
   - Profile the benchmark code itself for optimization
4. **Results not comparable between runs**:
   - Ensure consistent system state before benchmarking
   - Run benchmarks with the same configuration options
   - Save and compare benchmark results from controlled environments
   - Use statistical analysis to check significance of differences

## Example Configuration Files

### Development Configuration

```lua
-- .firmo-config.development.lua
return {
  benchmark = {
    -- Quick benchmarks for development
    iterations = 5,
    warmup = 1,
    report_memory = true,
    report_stats = true,
    gc_before = true,
    precision = 6,
    output_format = "text"
  }
}
```

### CI Configuration

```lua
-- .firmo-config.ci.lua
return {
  benchmark = {
    -- More thorough benchmarks for CI
    iterations = 20,
    warmup = 5,
    report_memory = true,
    report_stats = true,
    gc_before = true,
    precision = 8,
    confidence_interval = 0.95,
    output_format = "markdown",
    save_results = true,
    results_dir = "ci-benchmarks"
  }
}
```

### Performance Testing Configuration

```lua
-- .firmo-config.performance.lua
return {
  benchmark = {
    -- Comprehensive benchmarks for performance testing
    iterations = 50,
    warmup = 10,
    report_memory = true,
    report_stats = true,
    gc_before = true,
    include_warmup = false,
    track_memory_allocations = true,
    precision = 10,
    confidence_interval = 0.99,
    output_format = "json",
    save_results = true,
    results_dir = "performance-benchmarks"
  }
}
```

These configuration options give you complete control over the benchmarking process, allowing you to balance between quick development feedback and comprehensive performance analysis.
