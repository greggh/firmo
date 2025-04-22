# Parallel Testing Guide


This guide explains how to use Firmo's parallel testing features to speed up your test execution by running test files concurrently.

## Introduction


When working with large test suites, running tests sequentially can be time-consuming. Firmo's parallel module allows you to distribute test execution across multiple processes, significantly reducing the total test execution time.

## Getting Started


### Basic Setup


To use parallel testing, you need to:


1. Load the parallel module
2. Register it with Firmo
3. Run your tests with the parallel flag

Here's a minimal example:


```lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")
-- Register parallel with Firmo
parallel.register_with_firmo(firmo)
-- Now you can use parallel features
```



### Command Line Usage


The simplest way to use parallel testing is through the command line:


```bash

# Run all tests in parallel with 4 workers


lua test.lua --parallel tests/

# Specify the number of worker processes


lua test.lua --parallel --workers 8 tests/

# Run specific test files in parallel


lua test.lua --parallel tests/module1_test.lua tests/module2_test.lua
```



## Configuration Options


### Setting Worker Count


The number of worker processes determines how many test files can be executed concurrently:


```lua
-- Set via configuration
parallel.configure({
  workers = 8  -- Use 8 worker processes
})
-- Alternatively, via command line
-- lua test.lua --parallel --workers 8 tests/
```


For optimal performance, set the worker count based on your CPU cores. A good starting point is:


- For CPU-bound tests: Use the number of physical cores
- For I/O-bound tests: Use 1.5-2x the number of physical cores


### Timeout Configuration


Set timeouts to prevent tests from running indefinitely:


```lua
parallel.configure({
  timeout = 30  -- 30 second timeout per test file
})
-- Via command line
-- lua test.lua --parallel --timeout 30 tests/
```



### Output Control


Control how worker process output is displayed:


```lua
parallel.configure({
  show_worker_output = true,  -- Show output from each worker process
  verbose = false             -- Don't show verbose logging
})
-- Via command line
-- lua test.lua --parallel --no-worker-output tests/
-- lua test.lua --parallel --verbose-parallel tests/
```



### Failure Handling


Configure how test failures are handled:


```lua
parallel.configure({
  fail_fast = true  -- Stop testing on first failure
})
-- Via command line
-- lua test.lua --parallel --fail-fast tests/
```



### Coverage Integration


Control how coverage data is aggregated:


```lua
parallel.configure({
  aggregate_coverage = true  -- Combine coverage data from all workers
})
-- Via command line
-- lua test.lua --parallel --coverage tests/
-- lua test.lua --parallel --no-aggregate-coverage --coverage tests/
```



## Programmatic Usage


### Running Tests Programmatically


You can run tests in parallel programmatically:


```lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")
-- Register parallel with Firmo
parallel.register_with_firmo(firmo)
-- Define test files
local test_files = {
  "tests/module1_test.lua",
  "tests/module2_test.lua",
  "tests/module3_test.lua"
}
-- Run tests in parallel
local results = parallel.run_tests(test_files, {
  workers = 4,
  timeout = 30,
  show_worker_output = true,
  fail_fast = false
})
-- Display summary results
print("Tests completed: " .. results.total)
print("Passed: " .. results.passed)
print("Failed: " .. results.failed)
print("Skipped: " .. results.skipped)
print("Total time: " .. string.format("%.2f", results.elapsed) .. " seconds")
```



### Integrating with Test Discovery


Combine parallel testing with Firmo's test discovery:


```lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")
local fs = require("lib.tools.filesystem")
-- Register parallel with Firmo
parallel.register_with_firmo(firmo)
-- Discover tests
local test_files = firmo.discover("./tests", "*_test.lua")
-- Run discovered tests in parallel
local results = parallel.run_tests(test_files)
```



## Best Practices


### Test Independence


For parallel testing to work correctly, your tests must be independent:


1. Tests should not depend on the state from other test files
2. Tests should clean up after themselves (use `after` and `after_each` hooks)
3. Tests should not assume a specific execution order

Example of good test isolation:


```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
describe("Independent test", function()
  local temp_file
  -- Set up test environment
  before(function()
    temp_file = os.tmpname()
    local f = io.open(temp_file, "w")
    f:write("test data")
    f:close()
  end)
  -- Clean up after tests
  after(function()
    os.remove(temp_file)
  end)
  it("does something with the test environment", function()
    -- Test using temp_file
  end)
end)
```



### Optimizing Test Performance


To get the most out of parallel testing:


1. **Organize tests effectively**: Group related tests in the same file, but split large test files
2. **Minimize shared setup**: Use `before` instead of global setup when possible
3. **Balance test files**: Try to make test files take similar time to execute
4. **Tune worker count**: Experiment with different worker counts to find the optimal setting
5. **Combine with coverage**: Use `--parallel --coverage` to get both speed and coverage information


### Handling Resource Constraints


Be aware of resource constraints when running tests in parallel:


1. **Memory usage**: Each worker process consumes memory; reduce workers if memory is limited
2. **Database connections**: Use separate test databases or namespaces for concurrent tests
3. **External services**: Consider mocking external services to avoid connection limits
4. **File access**: Use unique temporary files/directories to avoid conflicts


## Troubleshooting


### Common Issues


#### Tests Timeout Unexpectedly


If tests timeout when running in parallel but not sequentially:


1. Increase the timeout value: `--timeout 120`
2. Check for resource contention between tests
3. Reduce the number of worker processes: `--workers 2`


#### Inconsistent Test Results


If tests pass when run sequentially but fail in parallel:


1. Check for test interdependencies
2. Look for race conditions in your tests
3. Verify resource cleanup between tests


#### Performance Not Improving


If parallel execution isn't significantly faster:


1. Check that tests are CPU-bound, not I/O-bound
2. Ensure test files are balanced in execution time
3. Verify that there are enough test files to benefit from parallelization


### Debugging Parallel Execution


To debug issues with parallel execution:


```lua
-- Enable verbose mode and show all worker output
parallel.configure({
  verbose = true,
  show_worker_output = true,
  debug = true
})
-- Dump configuration for inspection
local config = parallel.debug_config()
print("Using central config: " .. tostring(config.using_central_config))
print("Workers: " .. config.local_config.workers)
```


Via command line:


```bash
lua test.lua --parallel --verbose-parallel --workers 2 tests/
```



## Integration with Central Configuration


You can configure parallel testing via the central configuration system:


```lua
local central_config = require("lib.core.central_config")
-- Set parallel configuration
central_config.set("parallel", {
  workers = 6,
  timeout = 45,
  fail_fast = true,
  show_worker_output = true
})
```



## Conclusion


Parallel testing can dramatically reduce the execution time of your test suite, especially for larger projects. By following the best practices outlined in this guide, you can effectively leverage Firmo's parallel testing capabilities while avoiding common pitfalls.
