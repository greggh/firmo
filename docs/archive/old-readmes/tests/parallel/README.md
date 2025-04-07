# Parallel Execution Tests

This directory contains tests for the firmo parallel execution system. The parallel module enables running tests across multiple processes for improved performance and isolation.

## Directory Contents

- **parallel_test.lua** - Tests for parallel execution functionality

## Parallel Execution Features

The firmo parallel execution system provides:

- Multi-process test execution
- Results aggregation from parallel runs
- Coverage data merging from multiple processes
- Configurable process count
- Load balancing across available cores
- Error isolation between processes
- Support for different operating systems

## Parallel Execution Patterns

Parallel execution can be enabled via:

```lua
-- Command-line
lua test.lua --parallel tests/

-- API
firmo.run_tests({
  path = "tests/",
  parallel = true,
  process_count = 4
})
```

## Common Challenges

Parallel testing introduces specific considerations:

- Ensuring tests don't rely on global state
- Handling shared resources (files, databases)
- Managing timeouts appropriately
- Consolidating test output from multiple processes
- Merging coverage data accurately

## Running Tests

To run all parallel execution tests:
```
lua test.lua tests/parallel/
```

To run a specific parallel execution test:
```
lua test.lua tests/parallel/parallel_test.lua
```

See the [Parallel API Documentation](/docs/api/parallel.md) for more information.