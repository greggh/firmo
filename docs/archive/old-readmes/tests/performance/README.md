# Performance Tests

This directory contains tests for the firmo performance benchmarking capabilities. The performance module enables measuring execution time and memory usage of code.

## Directory Contents

- **large_file_test.lua** - Tests for handling large file performance
- **performance_test.lua** - Tests for the performance benchmarking module

## Performance Testing Features

The firmo performance module provides:

- Time-based benchmarking
- Memory usage tracking
- Function execution timing
- Statistical analysis of multiple runs
- Performance comparison between implementations
- Configurable warmup runs
- Support for async performance testing

## Performance Testing Patterns

```lua
-- Basic benchmarking
local benchmark = firmo.benchmark.new("operation_name")
benchmark.run(function()
  -- Code to benchmark
end)
benchmark.report()

-- Advanced benchmarking with options
local benchmark = firmo.benchmark.new("operation_name", {
  iterations = 1000,
  warmup = 100,
  report_memory = true
})
```

## Common Metrics

Performance tests track multiple metrics:

- Total execution time
- Average execution time
- Median execution time
- Standard deviation
- Memory usage
- Garbage collections
- CPU utilization

## Running Tests

To run all performance tests:
```
lua test.lua tests/performance/
```

To run a specific performance test:
```
lua test.lua tests/performance/performance_test.lua
```

See the [Performance API Documentation](/docs/api/benchmark.md) for more information.