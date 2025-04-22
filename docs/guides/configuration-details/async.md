# Async Module Configuration


This document describes the comprehensive configuration options for the firmo asynchronous testing system, which enables testing and controlling asynchronous operations.

## Overview


The async module provides a robust system for handling asynchronous operations with support for:


- Configurable timeouts for async operations
- Adjustable polling intervals for condition checking
- Parallel operation execution
- Promise-like deferred objects
- Condition waiting with configurable checks
- Task scheduling and management
- Integration with the central configuration system


## Configuration Options


### Core Options


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `default_timeout` | number | `1000` | Default timeout in milliseconds for async operations. Must be greater than 0. |
| `check_interval` | number | `10` | Interval in milliseconds for checking wait conditions. Must be greater than 0. |
| `debug` | boolean | `false` | Enable debug logging for the async module. |
| `verbose` | boolean | `false` | Enable verbose logging with detailed operation information. |

## Configuration in .firmo-config.lua


You can configure the async module in your `.firmo-config.lua` file:


```lua
return {
  -- Async testing configuration
  async = {
    -- Timing configuration
    default_timeout = 5000,     -- 5 second default timeout
    check_interval = 20,        -- 20ms check interval

    -- Debugging options
    debug = false,
    verbose = false
  }
}
```



## Programmatic Configuration


You can also configure the async module programmatically:


```lua
local async = require("lib.async")
-- Basic configuration
async.configure({
  default_timeout = 2000,  -- 2 second timeout
  check_interval = 50      -- 50ms check interval
})
-- Individual option configuration (fluent interface)
async.set_timeout(3000)        -- 3 second timeout
     .set_check_interval(100)  -- 100ms check interval
```



## Timeout Configuration


Timeouts control how long async operations will wait before failing:


```lua
-- Set global default timeout
async.set_timeout(5000)  -- 5 seconds
-- Get current default timeout
local timeout = async.get_timeout()  -- returns timeout in ms
-- Use specific timeout for an operation
await(async.wait_until(condition, 10000))  -- 10 second timeout
-- Configure through central configuration
central_config.set("async.default_timeout", 3000)
```



### Timeout Considerations


When setting timeouts, consider these factors:


1. **Test Environment**: CI environments may need longer timeouts than local development
2. **Operation Type**: Network operations need longer timeouts than local operations
3. **Test Stability**: Too-short timeouts cause flaky tests; too-long timeouts slow test execution
4. **Resource Constraints**: Longer timeouts consume more resources during test execution


## Check Interval Configuration


The check interval determines how frequently condition functions are polled:


```lua
-- Set global check interval
async.set_check_interval(50)  -- 50ms
-- Use specific check interval for a wait operation
await(async.wait_until(condition, 5000, 100))  -- 100ms check interval
-- Configure through central configuration
central_config.set("async.check_interval", 25)
```



### Check Interval Considerations


When setting check intervals:


1. For CPU-intensive conditions, use longer intervals (50-100ms)
2. For time-sensitive operations, use shorter intervals (5-20ms)
3. Very short intervals (<5ms) can consume excessive CPU
4. For most tests, the default 10ms provides a good balance


## Debug Configuration


For troubleshooting async operations:


```lua
-- Enable debug and verbose logging
async.configure({
  debug = true,
  verbose = true
})
-- Get current configuration
local config = async.debug_config()
print("Default timeout:", config.local_config.default_timeout)
print("Check interval:", config.local_config.check_interval)
print("In async context:", config.in_async_context)
```



## Advanced Usage


### Timeout Testing Mode


For testing timeout-specific behavior:


```lua
-- Enable timeout testing mode (for unit tests of timeout handling)
local restore = async.enable_timeout_testing()
-- Run tests that expect timeouts
-- ...
-- Restore normal behavior after testing
restore()
-- Check if in timeout testing mode
if async.is_timeout_testing() then
  -- Special timeout handling
end
```



### Custom Promise Timeout Behavior


Configure timeout behavior for promise-like operations:


```lua
-- Create promise with custom timeout
local promise = async.timeout(deferred.promise, 2000)
-- Configure global timeout behavior
async.configure({
  throw_on_timeout = true  -- Throw error instead of rejecting promise
})
-- Create promise that will time out
local promise = deferred.promise
async.timeout(promise, 500)
```



## Integration with Test Runner


The async module integrates with Firmo's test runner system:


```lua
-- Create async-aware test
it_async("should complete async operation", function()
  local result = await(async_operation())
  expect(result).to.equal("expected value")
end, 5000)  -- 5 second timeout
-- Using wait_until in tests
it_async("should meet condition eventually", function()
  -- Start operation that will change state
  start_operation()

  -- Wait for condition with custom timeout
  local success = await(async.wait_until(function()
    return get_state() == "completed"
  end, 2000))

  expect(success).to.be_truthy()
end)
```



## Error Handling


The async module provides detailed error information for timeouts:


```lua
-- Catch timeout errors
local success, err = pcall(function()
  await(async.wait_until(function() 
    return false -- never succeeds
  end, 1000))
end)
if not success then
  print("Error:", err)
  -- Will contain detailed timeout information
end
-- Using error handler
local error_handler = require("lib.tools.error_handler")
local success, result, err = error_handler.try(function()
  return await(async_operation())
end)
if not success then
  print("Category:", err.category)
  print("Message:", err.message)
  -- Will be categorized as TIMEOUT if a timeout occurred
end
```



## Best Practices


### Setting Appropriate Timeouts



```lua
-- General recommendations:
-- - Simple local operations: 500-1000ms
-- - Database operations: 2000-5000ms
-- - Network operations: 5000-10000ms
-- - Integration tests: 10000-30000ms
-- Local operation
async.wait_until(local_condition, 1000)
-- Database operation
async.wait_until(database_condition, 5000)
-- Network operation
async.wait_until(network_condition, 10000)
```



### Optimizing Check Intervals



```lua
-- For operations where timing is critical
async.wait_until(time_critical_condition, 1000, 5)  -- 5ms checks
-- For normal operations
async.wait_until(normal_condition, 1000, 10)  -- 10ms checks (default)
-- For resource-intensive conditions
async.wait_until(expensive_condition, 1000, 50)  -- 50ms checks
```



### Environment-Specific Configuration


For different environments:


```lua
-- Determine environment
local env = os.getenv("ENV") or "development"
-- Load environment-specific config
local config_file = ".firmo-config." .. env .. ".lua"
-- Or configure programmatically
if env == "development" then
  async.configure({
    default_timeout = 2000,  -- Shorter timeouts for development
    check_interval = 10
  })
elseif env == "ci" then
  async.configure({
    default_timeout = 10000,  -- Longer timeouts for CI
    check_interval = 50,      -- Less frequent checks to reduce CI resource usage
    debug = true              -- More debugging for CI failures
  })
end
```



## Troubleshooting


### Common Issues



1. **Flaky tests due to timeouts**:
   - Increase the `default_timeout` value
   - Use environment-specific timeout values
   - Check for resource contention in testing environment
2. **High CPU usage**:
   - Increase the `check_interval` value
   - Optimize condition function performance
   - Check for infinite loops in async code
3. **Timeout errors without useful context**:
   - Enable `debug` and `verbose` logging
   - Use error handler to capture detailed context
   - Add explicit context information to async operations
4. **Unexpected timeouts in CI**:
   - Set longer timeouts for CI environments
   - Check for resource limitations in CI environment
   - Consider dedicated async settings for CI


## Example Configuration Files


### Basic Configuration



```lua
-- .firmo-config.lua
return {
  async = {
    default_timeout = 2000,
    check_interval = 10,
    debug = false,
    verbose = false
  }
}
```



### Development Configuration



```lua
-- .firmo-config.development.lua
return {
  async = {
    default_timeout = 1000,    -- Short timeout for fast feedback
    check_interval = 10,
    debug = true,              -- Enable debugging during development
    verbose = true
  }
}
```



### CI Configuration



```lua
-- .firmo-config.ci.lua
return {
  async = {
    default_timeout = 10000,   -- Long timeout for CI environment
    check_interval = 50,       -- Less frequent checks to reduce CPU usage
    debug = true,              -- Full debug info for CI failures
    verbose = true
  }
}
```



### Production Test Configuration



```lua
-- .firmo-config.production.lua
return {
  async = {
    default_timeout = 5000,    -- Moderate timeout for production tests
    check_interval = 25,       -- Balance between responsiveness and resource usage
    debug = false,             -- No debug output in production
    verbose = false
  }
}
```


These configuration options give you complete control over asynchronous testing behavior, allowing you to optimize for your specific testing needs and environment constraints.
