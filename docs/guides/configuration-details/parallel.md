# Parallel Execution Configuration

This document describes the comprehensive configuration options for the firmo parallel execution system, which enables running tests across multiple worker processes for improved performance.

## Overview

The parallel execution module provides a powerful system for running tests across multiple worker processes with support for:

- Configurable number of worker processes
- Individual test file timeouts
- Coverage data aggregation
- Worker output visibility control
- Fail-fast execution mode
- Integration with the central configuration system
- Command-line configuration options

## Configuration Options

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `workers` | number | `4` | Number of parallel worker processes. Must be between 1 and 64. |
| `timeout` | number | `60` | Default timeout in seconds per test file. Must be greater than 1. |
| `output_buffer_size` | number | `10240` | Buffer size in bytes for capturing worker output. |
| `verbose` | boolean | `false` | Enables verbose output for detailed logging. |
| `show_worker_output` | boolean | `true` | Whether to show output from worker processes. |
| `fail_fast` | boolean | `false` | Stop execution on first failure. |
| `aggregate_coverage` | boolean | `true` | Combine coverage data from all workers. |
| `debug` | boolean | `false` | Enable debug mode with additional logging. |

## Configuration in .firmo-config.lua

You can configure the parallel execution system in your `.firmo-config.lua` file:

```lua
return {
  -- Parallel execution configuration
  parallel = {
    -- Process configuration
    workers = 8,                    -- Use 8 worker processes
    timeout = 120,                  -- 2 minute timeout per file

    -- Output options
    output_buffer_size = 20480,     -- 20KB output buffer
    show_worker_output = false,     -- Hide worker output for cleaner logs
    verbose = false,                -- Disable verbose logging

    -- Execution behavior
    fail_fast = true,               -- Stop on first failure
    aggregate_coverage = true,      -- Combine coverage data
    debug = false                   -- Disable debug mode
  }
}
```

## Programmatic Configuration

You can also configure the parallel execution system programmatically:

```lua
local parallel = require("lib.tools.parallel")
-- Basic configuration
parallel.configure({
  workers = 8,
  timeout = 120,
  fail_fast = true
})
-- Reset to defaults
parallel.reset()
-- Full reset (including central config)
parallel.full_reset()
-- Get current configuration
local config = parallel.debug_config()
print("Using", config.local_config.workers, "workers with", config.local_config.timeout, "second timeout")
```

## Command Line Integration

The parallel execution module integrates with Firmo's command-line interface:

```bash

# Basic parallel execution

lua firmo.lua --parallel tests/

# Set number of workers

lua firmo.lua --parallel --workers 6 tests/

# Set timeout per file

lua firmo.lua --parallel --timeout 120 tests/

# Enable verbose output

lua firmo.lua --parallel --verbose-parallel tests/

# Hide worker output

lua firmo.lua --parallel --no-worker-output tests/

# Stop on first failure

lua firmo.lua --parallel --fail-fast tests/

# Don't combine coverage data

lua firmo.lua --parallel --no-aggregate-coverage tests/
```

## Performance Considerations

### Selecting the Optimal Number of Workers

The optimal number of worker processes depends on your system resources:

```lua
-- General recommendations:
-- - CPU-bound tests: workers = number of CPU cores
-- - I/O-bound tests: workers = 1.5-2x number of CPU cores
-- - Memory-intensive tests: workers = CPU cores / 2 (to avoid memory pressure)
-- Set workers based on CPU cores
local num_cores = 8  -- Replace with actual detection
local workers = num_cores
-- Configure based on test characteristics
if test_is_io_bound then
  workers = math.min(24, num_cores * 2)  -- Cap at 24 for very high core counts
elseif test_is_memory_intensive then
  workers = math.max(2, math.floor(num_cores / 2))  -- At least 2 workers
end
parallel.configure({ workers = workers })
```

### Timeout Management

Set timeouts appropriate for your test suite:

```lua
-- Example for different test types
parallel.configure({
  timeout = 300  -- 5 minutes for complex integration tests
})
-- For quick unit tests
parallel.configure({
  timeout = 30  -- 30 seconds is enough for unit tests
})
```

## Coverage Data Aggregation

When running tests in parallel, coverage data from each worker process can be combined:

```lua
-- Enable coverage aggregation (default)
parallel.configure({
  aggregate_coverage = true
})
-- Disable coverage aggregation for isolated test runs
parallel.configure({
  aggregate_coverage = false
})
```

The coverage aggregation combines:

1. Line execution counts across all processes
2. Function call counts from all processes
3. Branch execution data if available

## Integration with Test Runner

The parallel execution module integrates with Firmo's test runner system:

```lua
-- In your test runner
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")
-- Register parallel execution with firmo
parallel.register_with_firmo(firmo)
-- Run tests in parallel (called by CLI)
local results = parallel.run_tests(files, {
  workers = 8,
  timeout = 60,
  coverage = true,  -- Enable coverage tracking
  tags = {"unit"},  -- Only run tests with this tag
  filter = "database"  -- Only run tests matching this pattern
})
```

## Advanced Usage

### Custom Worker Configuration

For specialized test scenarios, you can customize worker behavior:

```lua
local parallel = require("lib.tools.parallel")
local central_config = require("lib.core.central_config")
-- Configure through central config
central_config.set("parallel", {
  workers = 6,
  timeout = 120,
  show_worker_output = false,

  -- Performance options
  output_buffer_size = 20480,

  -- Execution behavior
  fail_fast = true
})
-- Apply configuration from central config
parallel.configure_from_config()
```

### Fail-Fast Mode

To stop testing at the first failure:

```lua
-- Enable fail-fast mode
parallel.configure({
  fail_fast = true
})
-- In .firmo-config.lua
return {
  parallel = {
    fail_fast = true
  }
}
-- Via command line
-- lua firmo.lua --parallel --fail-fast tests/
```

### Output Control

Managing test output for readability:

```lua
-- Hide individual worker output for cleaner logs
parallel.configure({
  show_worker_output = false
})
-- Show verbose output for debugging
parallel.configure({
  verbose = true,
  show_worker_output = true
})
-- Increase output buffer for verbose tests
parallel.configure({
  output_buffer_size = 51200  -- 50KB buffer
})
```

## Debugging Parallel Execution

The parallel execution module includes debugging tools:

```lua
-- Enable debug mode
parallel.configure({
  debug = true,
  verbose = true
})
-- Get configuration debug info
local config_info = parallel.debug_config()
print("Worker count:", config_info.local_config.workers)
print("Using central config:", config_info.using_central_config)
-- Check central config values (if available)
if config_info.central_config then
  print("Central config workers:", config_info.central_config.workers)
end
```

## Error Handling

The parallel execution module implements comprehensive error handling and reporting:

```lua
-- Run with proper error handling
local success, results = pcall(function()
  return parallel.run_tests(files, {
    workers = 8,
    timeout = 60
  })
end)
if not success then
  print("Parallel execution failed:", results)
  -- Handle error
else
  -- Process results
  print("Successful files:", results.successful_files)
  print("Failed files:", results.failed_files)

  -- Check for test failures
  for file_path, file_result in pairs(results.results) do
    if not file_result.success then
      print("File failed:", file_path)
      print("Error:", file_result.error)
    end
  end
end
```

## Worker Result Processing

Results from worker processes include:

- Success/failure status per file
- Execution duration
- Test counts (total, passed, failed, skipped)
- Detailed error information
- Test outputs
- Coverage data (if enabled)

```lua
-- Example of processing worker results
local function process_results(results)
  -- Display summary
  print("Files tested:", #results.files_run)
  print("Total tests:", results.total)
  print("Passed:", results.passed)
  print("Failed:", results.failed)
  print("Skipped:", results.skipped)

  -- Calculate success rate
  local success_rate = results.total > 0 
    and (results.passed / results.total) * 100 
    or 0
  print("Success rate:", string.format("%.1f%%", success_rate))

  -- Process coverage data if available
  if results.coverage and next(results.coverage) then
    -- Generate reports or process coverage data
    -- ...
  end
end
```

## Best Practices

### Setting the Right Number of Workers

```lua
-- General guidelines:
-- - For CPU-bound tests: Use number of CPU cores
-- - For I/O-bound tests: Use 1.5-2x number of CPU cores
-- - For mixed workloads: Start with number of CPU cores and adjust
-- Example automatic configuration
local function get_optimal_workers()
  -- This is a simple way to get CPU cores on many systems
  -- For more robust detection, use a system-specific approach
  local cores = 4  -- Default fallback

  -- Try to detect cores (Unix-like systems)
  local handle = io.popen("nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4")
  if handle then
    local result = handle:read("*a")
    handle:close()
    cores = tonumber(result) or cores
  end

  return cores
end
parallel.configure({
  workers = get_optimal_workers()
})
```

### Memory Considerations

```lua
-- For memory-intensive tests
local cores = get_optimal_workers()
local available_memory = 8  -- GB (example)
-- Estimate memory per worker
local memory_per_worker = 512  -- MB (example)
local max_workers_by_memory = math.floor((available_memory * 1024) / memory_per_worker)
-- Use the lower of CPU-based or memory-based worker count
local optimal_workers = math.min(cores, max_workers_by_memory)
parallel.configure({
  workers = optimal_workers
})
```

### CI/CD Integration

For continuous integration environments:

```lua
-- In .firmo-config.ci.lua
return {
  parallel = {
    -- CI-specific settings
    workers = 2,  -- Conservative for CI environments
    timeout = 300,  -- Higher timeout for CI
    fail_fast = true,  -- Stop on first failure
    show_worker_output = true,  -- Show outputs for debugging
    aggregate_coverage = true  -- Combine coverage for reports
  }
}
-- Load different config in CI
local env = os.getenv("CI") and "ci" or "dev"
local config_file = ".firmo-config." .. env .. ".lua"
```

## Troubleshooting

### Common Issues

1. **Workers time out unexpectedly**:
   - Increase the `timeout` value
   - Check for resource contention
   - Consider reducing the number of workers
2. **Memory pressure**:
   - Reduce the number of workers
   - Check for memory leaks in tests
   - Increase system swap space if available
3. **Missing test output**:
   - Enable `show_worker_output`
   - Increase `output_buffer_size` for verbose tests
   - Enable `verbose` mode for additional logging
4. **Coverage data issues**:
   - Verify `aggregate_coverage` is enabled
   - Check for file path consistency across workers
   - Ensure coverage is enabled for all workers

## Command Line Reference

| Option | Description |
|--------|-------------|
| `--parallel`, `-p` | Enable parallel execution |
| `--workers <num>`, `-w <num>` | Set number of worker processes |
| `--timeout <seconds>` | Set timeout per test file |
| `--verbose-parallel` | Enable verbose output |
| `--no-worker-output` | Hide worker output |
| `--fail-fast` | Stop on first failure |
| `--no-aggregate-coverage` | Don't combine coverage data |

## Example Configuration Files

### Basic Configuration

```lua
-- .firmo-config.lua
return {
  parallel = {
    workers = 8,
    timeout = 60,
    show_worker_output = true,
    fail_fast = false
  }
}
```

### High-Performance Configuration

```lua
-- .firmo-config-high-perf.lua
return {
  parallel = {
    workers = 16,
    timeout = 30,
    show_worker_output = false,
    output_buffer_size = 4096,  -- Smaller buffer for performance
    fail_fast = true
  }
}
```

### Debug Configuration

```lua
-- .firmo-config-debug.lua
return {
  parallel = {
    workers = 2,  -- Fewer workers for easier debugging
    timeout = 300,  -- Longer timeout
    show_worker_output = true,
    verbose = true,
    debug = true,
    fail_fast = false  -- Allow all tests to run
  }
}
```

These configuration options give you complete control over parallel test execution, allowing you to optimize for your specific testing needs and system environment.
