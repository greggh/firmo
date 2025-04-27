# Async Testing Guide


## Introduction


Asynchronous testing is crucial for validating code that involves timers, callbacks, network operations, and other non-immediate processes. The Firmo framework provides comprehensive support for asynchronous testing through its async module.
This guide explains how to write effective asynchronous tests, handle common async patterns, and avoid common pitfalls.

## Core Concepts


### Async Context


The async module uses the concept of an "async context" to manage asynchronous test execution. An async context is an execution environment where async operations can be performed safely with appropriate timeout handling and error propagation.
Key points about async context:


- Created implicitly when using `it_async()` or explicitly with `async()`
- Required for using `await()`, `wait_until()`, and other async operations
- Tracks the execution state and provides proper error handling


### Async Flow Control


The async module provides several mechanisms for controlling async flow:


1. **`await()`**: Pauses execution for a specified time
2. **`wait_until()`**: Waits for a condition to become true
3. **`parallel_async()`**: Runs multiple async operations concurrently

These functions allow for fine-grained control over the execution of async tests, making it possible to test complex asynchronous code effectively.

## Basic Usage Patterns


### Writing Simple Async Tests


The simplest way to write an async test is using the `it_async()` function:


```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
describe("User Service", function()
  it_async("fetches user data asynchronously", function()
    -- Start async operation
    local user_data = nil
    start_fetch_user(function(data)
      user_data = data
    end)
    -- Wait for operation to complete
    firmo.wait_until(function() return user_data ~= nil end)
    -- Assert on the results
    expect(user_data).to.exist()
    expect(user_data.id).to.be.a("number")
    expect(user_data.name).to.be.a("string")
  end)
end)
```



### Using await for Timed Delays


When you need to wait for a specific amount of time:


```lua
it_async("processes data after a delay", function()
  -- Start operation
  start_delayed_process()
  -- Wait for 100ms
  firmo.await(100)
  -- Check result (should be ready after 100ms)
  expect(get_process_result()).to.exist()
end)
```



### Using wait_until for Conditional Waiting


For more precise control, use `wait_until()` to wait for a specific condition:


```lua
it_async("waits for a specific condition", function()
  -- Start process that takes variable time
  start_variable_process()
  -- Wait for specific condition rather than fixed time
  firmo.wait_until(function()
    return get_process_state() == "completed"
  end, 1000) -- 1 second timeout
  -- Now safe to check results
  expect(get_process_result()).to.equal("success")
end)
```



### Handling Timeouts


Async tests have timeouts to prevent hanging. You can customize these timeouts:


```lua
-- Set longer timeout for a specific test
it_async("completes a long operation", function()
  -- Start long operation
  start_long_operation()
  -- Wait with longer timeout
  firmo.wait_until(function()
    return operation_complete()
  end, 5000) -- 5 second timeout
  expect(get_operation_result()).to.exist()
end, 6000) -- 6 second test timeout
-- Or set default timeout for all tests
before_all(function()
  local async_module = require("lib.async")
  -- Use configure to set options like default_timeout or check_interval
  async_module.configure({ default_timeout = 3000 }) -- 3 seconds default
end)
```
The primary function for setting options after loading the module is `async.configure({ default_timeout = ..., check_interval = ... })`.



## Advanced Usage Patterns


### Parallel Operations


For testing multiple concurrent operations:


```lua
it_async("handles multiple concurrent operations", function()
  -- Define async operations
  local fetch_users = function()
    firmo.await(50)
    return { {id = 1, name = "User 1"}, {id = 2, name = "User 2"} }
  end
  local fetch_posts = function()
    firmo.await(70)
    return { {id = 1, title = "Post 1"}, {id = 2, title = "Post 2"} }
  end
  -- Run both in parallel (completes in ~70ms, not 120ms)
  local results = firmo.parallel_async({fetch_users, fetch_posts})
  -- Check results (returned in same order as functions)
  expect(#results[1]).to.equal(2) -- Two users
  expect(#results[2]).to.equal(2) -- Two posts
end)
```



### Testing Callbacks


Many async APIs use callbacks. Here's how to test them:


```lua
it_async("tests callback-based API", function()
  local result = nil
  -- Call function that accepts callback
  api.fetch_data(function(data, error)
    if error then
      result = {success = false, error = error}
    else
      result = {success = true, data = data}
    end
  end)
  -- Wait for callback to be called
  firmo.wait_until(function() return result ~= nil end)
  -- Check results
  expect(result.success).to.be_truthy()
  expect(result.data).to.exist()
end)
```


### Testing Async Error Handling


For testing error conditions in async code:


```lua
it_async("handles async errors correctly", { expect_error = true }, function()
  -- Call function that will fail
  local result, error = pcall(function()
    local fail_operation = function()
      firmo.await(10)
      error("Operation failed")
    end
    firmo.parallel_async({ fail_operation })
  end)
  -- Verify error was thrown
  expect(result).to.equal(false)
  expect(error).to.match("Operation failed")
end)
```



## Integration with Other Modules


### Using Async with Mocks


Combining async testing with mocking:


```lua
it_async("tests async function with mocked dependencies", function()
  -- Create mock with spy
  local api_mock = firmo.mock({
    fetch_data = function(callback)
      -- Mock will call callback after delay
      firmo.set_timeout(function()
        callback({success = true, data = "mocked data"})
      end, 10)
    end
  })
  -- Call code that uses the mocked API
  local result = nil
  my_service.get_data(api_mock, function(data)
    result = data
  end)
  -- Wait for operation to complete
  firmo.wait_until(function() return result ~= nil end)
  -- Verify results
  expect(result.success).to.be_truthy()
  expect(result.data).to.equal("mocked data")
  -- Verify mock was called correctly
  expect(api_mock.fetch_data.called).to.be_truthy()
  expect(api_mock.fetch_data.calls[1]).to.exist()
end)
```



### Using Async with Filesystem Operations


For testing async filesystem operations:


```lua
it_async("tests async file operations", function()
  -- Create temporary file
  local path = "/tmp/test-" .. os.time()
  -- Write to file asynchronously
  fs.write_file_async(path, "test data", function(success)
    expect(success).to.be_truthy()
  end)
  -- Wait for file to exist
  firmo.wait_until(function()
    return fs.file_exists(path)
  end)
  -- Read file
  local content = fs.read_file(path)
  expect(content).to.equal("test data")
  -- Clean up
  fs.delete_file(path)
end)
```



## Best Practices


### 1. Always Call done() or Complete Test Flow


When using callback-style async tests, always call `done()` or ensure your test flow completes by returning or reaching the end of the test function:


```lua
it_async("always completes test flow", function(done)
  start_operation(function()
    -- Always call done() in each code path
    expect(true).to.be_truthy()
    done()
  end)
})
```



### 2. Set Appropriate Timeouts


Always set timeouts based on the expected operation duration, not too short or too long:


```lua
-- Bad: timeout too short, may fail intermittently
firmo.wait_until(condition, 10)
-- Bad: timeout too long, test will hang if broken
firmo.wait_until(condition, 60000)
-- Good: reasonable timeout based on expected behavior
firmo.wait_until(condition, 2000)
```



### 3. Clean Up Resources


Always clean up resources created during async tests:


```lua
it_async("cleans up resources", function()
  local resources = {}
  -- Register cleanup function
  after(function()
    for _, resource in pairs(resources) do
      resource:cleanup()
    end
  end)
  -- Create resource
  local resource = create_resource()
  table.insert(resources, resource)
  -- Use resource in test...
end)
```



### 4. Use wait_until Instead of Fixed Delays


Prefer `wait_until` over fixed `await` times when possible:


```lua
-- Bad: uses fixed delay
firmo.await(500) -- Might be too short or too long
-- Good: waits for actual condition
firmo.wait_until(function() return operation_complete() end)
```



### 5. Handle Both Success and Error Cases


Test both success and error conditions:


```lua
it_async("handles both success and error", function()
  -- Test success case
  let success_result = get_async_success()
  firmo.wait_until(function() return success_result.complete end)
  expect(success_result.value).to.exist()
  -- Test error case
  let error_result = get_async_error()
  firmo.wait_until(function() return error_result.complete end)
  expect(error_result.error).to.exist()
end)
```



### 6. Avoid Nested Callbacks


Avoid deeply nested callbacks that make tests hard to follow:


```lua
-- Bad: deeply nested callbacks
it_async("has nested callbacks", function()
  operation1(function(result1) {
    operation2(result1, function(result2) {
      operation3(result2, function(result3) {
        expect(result3).to.exist() // Hard to follow
      })
    })
  })
})
-- Good: sequential async operations
it_async("uses sequential async flow", function()
  -- Run first operation
  local result1 = nil
  operation1(function(res) { result1 = res })
  firmo.wait_until(function() return result1 ~= nil end)
  -- Run second operation
  local result2 = nil
  operation2(result1, function(res) { result2 = res })
  firmo.wait_until(function() return result2 ~= nil end)
  -- Run third operation
  local result3 = nil
  operation3(result2, function(res) { result3 = res })
  firmo.wait_until(function() return result3 ~= nil end)
  -- Verify final result
  expect(result3).to.exist()
end)
```



### 7. Isolate Tests


Make sure each async test is independent and doesn't rely on state from other tests:


```lua
-- Each test initializes its own state
before(function()
  test_state = create_clean_state()
})
-- Each test cleans up afterward
after(function()
  test_state:cleanup()
})
```



## Common Pitfalls and Solutions


### Forgetting to Wait for Async Operations


**Problem**: Assertions run before async operations complete.
**Solution**: Always use `wait_until` to ensure operations finish before assertions:


```lua
-- Problem: assertion may run before callback
it_async("might fail intermittently", function()
  let result = nil
  async_operation(function(res) { result = res })
  expect(result).to.exist() // May fail if callback hasn't happened yet!
})
-- Solution: wait until callback completes
it_async("waits properly", function()
  let result = nil
  async_operation(function(res) { result = res })
  firmo.wait_until(function() return result ~= nil end)
  expect(result).to.exist() // Safe to check now
})
```



### Timeout Too Short


**Problem**: Test fails with timeout because the operation takes longer than expected.
**Solution**: Set appropriate timeouts based on the operation:


```lua
-- Problem: timeout too short
firmo.wait_until(condition, 100) // Only 100ms timeout
-- Solution: more realistic timeout
firmo.wait_until(condition, 2000) // 2 second timeout
```



### Not Cleaning Up Resources


**Problem**: Resources from one test affect other tests.
**Solution**: Always clean up in after() hooks:


```lua
it_async("properly cleans up", function()
  -- Register cleanup to run after test
  after(function()
    cleanup_resources()
  end)
  -- Test code...
})
```



### Leaking Async Operations


**Problem**: Starting async operations that continue running after the test completes.
**Solution**: Save references to operations and cancel them in cleanup:


```lua
it_async("cleans up ongoing operations", function()
  -- Store reference
  local operation = start_async_operation()
  -- Clean up even if test fails
  after(function()
    if operation then
      operation:cancel()
    }
  })
  -- Test code...
})
```



## Performance Considerations


### Setting Appropriate Check Intervals


The `check_interval` parameter in `wait_until` determines how frequently the condition is checked. Balance between responsiveness and CPU usage:


```lua
-- Check condition every 50ms instead of default 10ms
-- Less CPU intensive but slightly less responsive
firmo.wait_until(condition, 2000, 50)
```



### Using parallel_async for Independent Operations


When testing multiple operations that don't depend on each other, use `parallel_async` for better performance:


```lua
-- Sequential (slower)
local result1 = operation1()
local result2 = operation2()
local result3 = operation3()
-- Parallel (faster)
local results = firmo.parallel_async({operation1, operation2, operation3})
local result1, result2, result3 = results[1], results[2], results[3]
```



### Batch Assertions When Possible


Group related assertions together to minimize the number of async waits:


```lua
-- Inefficient: multiple wait_until calls
firmo.wait_until(function() return user.name ~= nil end)
expect(user.name).to.be.a("string")
firmo.wait_until(function() return user.email ~= nil end)
expect(user.email).to.be.a("string")
-- More efficient: single wait for all data
firmo.wait_until(function()
  return user.name ~= nil and user.email ~= nil
end)
expect(user.name).to.be.a("string")
expect(user.email).to.be.a("string")
```



## Conclusion


Asynchronous testing is essential for validating code with delayed execution or callbacks. The Firmo async module provides powerful tools for writing clear, reliable async tests.
Key takeaways:


- Use `it_async()` for simple async tests
- Use `wait_until()` for conditional waiting
- Use `parallel_async()` for concurrent operations
- Always set appropriate timeouts
- Always clean up resources
- Handle both success and error cases

For complete API details, refer to the [Async Module API Reference](/docs/api/async.md).
For practical examples, see the [Async Examples](/examples/async_examples.md).
