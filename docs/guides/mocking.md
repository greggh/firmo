# Mocking System Usage Guide

This guide explains how to effectively use Firmo's mocking system to improve your tests. The mocking system provides tools for isolating components, controlling their behavior, and verifying their interactions during testing.

## Introduction

Mocking helps you replace real dependencies with test doubles that you can control. This allows you to:

- Test components in isolation
- Control the behavior of dependencies
- Verify interaction patterns
- Test error conditions
- Speed up tests by avoiding expensive operations

The Firmo mocking system provides three main types of test doubles:

- **Spies**: Track function calls without changing behavior
- **Stubs**: Replace functions with controlled implementations
- **Mocks**: Complete mock objects with verification capabilities

## When to Use Each Type of Test Double

Each type of test double serves a specific purpose:

| Type | Purpose | Use When |
|------|---------|----------|
| **Spy** | Track calls to a function | You want to verify a function was called with specific arguments, but still want the real implementation to execute |
| **Stub** | Replace a function with a controlled implementation | You want to control what a function returns or does, without calling the real implementation |
| **Mock** | Create a complete mock object with verification | You want to replace an entire object and verify multiple method calls on it |

## Basic Usage Examples

### Creating and Using Spies

Spies let you track calls to functions without changing their behavior:

```lua
-- Import Firmo
local firmo = require("firmo")
local spy = firmo.spy

-- Spy on a function
local calculate = function(a, b) return a + b end
local spy_calculate = spy(calculate)

-- Call the spied function
local result = spy_calculate(5, 3)

-- Function still works normally
assert(result == 8)

-- But calls are tracked
assert(spy_calculate.called == true)
assert(spy_calculate.call_count == 1)
assert(spy_calculate.calls[1][1] == 5)
assert(spy_calculate.calls[1][2] == 3)
```

### Creating and Using Stubs

Stubs replace real functions with controlled implementations:

```lua
-- Import Firmo
local firmo = require("firmo")
local stub = firmo.stub

-- Create a stub that returns a fixed value
local getUser = stub({ id = 1, name = "Test User" })

-- Call the stub function
local user = getUser()

-- Returns our specified value
assert(user.id == 1)
assert(user.name == "Test User")

-- Create a stub with a dynamic implementation
local calculateStub = stub(function(a, b)
  return a * b  -- Different from real add function
end)

-- Call the stub
local result = calculateStub(5, 3)

-- Returns result from our stub implementation
assert(result == 15)  -- 5 * 3, not 5 + 3
```

### Creating and Using Mock Objects

Mock objects replace entire objects and provide verification:

```lua
-- Import Firmo
local firmo = require("firmo")
local mock = firmo.mock

-- Create a sample database object
local database = {
  connect = function() return { connected = true } end,
  query = function(query_string) 
    -- Complex database query in real implementation
    return { rows = {} } 
  end,
  disconnect = function() end
}

-- Create a mock of the database
local mock_db = mock(database)

-- Stub methods on the mock
mock_db:stub("connect", function()
  return { connected = true, mock = true }
end)

mock_db:stub("query", function(query)
  return { rows = {{ id = 1, name = "Mock Result" }} }
end)

-- No need to stub disconnect if it's not important for the test

-- Use the mock in your code
local connection = database.connect()
local result = database.query("SELECT * FROM users")
database.disconnect()

-- Verify expected methods were called
assert(mock_db._stubs.connect.called == true)
assert(mock_db._stubs.query.called == true)
assert(mock_db._stubs.query.calls[1][1] == "SELECT * FROM users")

-- Can also use the mock's verify method
local success = mock_db:verify()
assert(success == true)

-- Clean up by restoring original methods
mock_db:restore()
```

## Advanced Features

### Sequential Return Values

You can configure stubs to return different values on successive calls:

```lua
-- Create a stub that returns different values in sequence
local statusStub = stub():returns_in_sequence({
  "connecting",
  "authenticating",
  "connected"
})

-- First call
assert(statusStub() == "connecting")

-- Second call
assert(statusStub() == "authenticating")

-- Third call
assert(statusStub() == "connected")

-- Fourth call (sequence exhausted)
assert(statusStub() == nil)
```

### Cycling Sequences

For repeating patterns, you can make sequences cycle back to the beginning:

```lua
-- Create a cycling stub for traffic light states
local lightStub = stub()
  :returns_in_sequence({"red", "yellow", "green"})
  :cycle_sequence(true)

-- Cycle through values
assert(lightStub() == "red")
assert(lightStub() == "yellow")
assert(lightStub() == "green")

-- Cycles back to beginning
assert(lightStub() == "red")
assert(lightStub() == "yellow")
```

### Custom Behavior When Sequence Is Exhausted

Control what happens when a sequence is exhausted:

```lua
-- Define an API client
local api_client = {
  get_status = function() return "real status" end
}

-- Create a mock with sequence that falls back to real implementation
local mock_api = mock(api_client)
mock_api:stub_in_sequence("get_status", {"offline", "connecting"})
  :when_exhausted("fallback")

-- Use first two values from sequence
assert(api_client.get_status() == "offline")
assert(api_client.get_status() == "connecting")

-- Then falls back to original implementation
assert(api_client.get_status() == "real status")
```

Or return a custom value when exhausted:

```lua
local stub = firmo.stub():returns_in_sequence({"first", "second"})
  :when_exhausted("custom", "sequence ended")

assert(stub() == "first")
assert(stub() == "second")
assert(stub() == "sequence ended")
```

### Simulating Errors

Test error handling by making stubs throw errors:

```lua
-- Create a stub that throws an error
local errorStub = stub():throws("Test error message")

-- Calling the stub will throw an error
local success, error_message = pcall(function()
  errorStub()
end)

assert(success == false)
assert(string.match(error_message, "Test error message"))
```

### Tracking Call Order

Verify the sequence of calls:

```lua
-- Create spies for multiple functions
local spy1 = spy(function() return "first" end)
local spy2 = spy(function() return "second" end)
local spy3 = spy(function() return "third" end)

-- Call them in a specific order
spy1()
spy2()
spy3()

-- Verify the order
assert(spy1:called_before(spy2) == true)
assert(spy2:called_before(spy3) == true)
assert(spy1:called_before(spy3) == true)
assert(spy3:called_after(spy1) == true)
```

## Using the Context Manager

The `with_mocks` context manager automatically cleans up all mocks created within it, even if an error occurs:

```lua
-- Define test objects
local service = {
  getData = function() return "real data" end,
  processData = function(data) return "processed: " .. data end
}

-- Use with_mocks context
firmo.with_mocks(function(mock_fn, spy, stub)
  -- Create a mock
  local mock_service = mock_fn(service)
  
  -- Stub methods
  mock_service:stub("getData", function() return "mock data" end)
  mock_service:stub("processData", function(data) return "mock processed: " .. data end)
  
  -- Use the mock
  local data = service.getData()
  local result = service.processData(data)
  
  -- Verification
  assert(data == "mock data")
  assert(result == "mock processed: mock data")
  assert(mock_service._stubs.getData.called == true)
  assert(mock_service._stubs.processData.called == true)
  
  -- No need to restore, happens automatically
end)

-- Outside the context, original methods are restored
assert(service.getData() == "real data")
```

## Integration with Expect

The mocking system integrates with Firmo's expectation system for more readable tests:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local spy, stub, mock = firmo.spy, firmo.stub, firmo.mock

describe("User Service", function()
  it("processes user data correctly", function()
    local db = {
      query = function() return { rows = {} } end
    }
    
    local db_spy = spy(db, "query")
    
    -- Call the function under test
    process_user_data(db, "test_user")
    
    -- Expectations for the spy
    expect(db_spy).to.be.called()
    expect(db_spy).to.be.called.with("SELECT * FROM users WHERE username = ?", "test_user")
    expect(db_spy).to.be.called.once()
  end)
  
  it("handles database errors appropriately", function()
    local db = {
      query = function() return { rows = {} } end
    }
    
    -- Replace query with error-throwing stub
    local db_mock = mock(db)
    db_mock:stub("query", function()
      error("Database connection lost")
    end)
    
    -- Use expect for error handling
    expect(function()
      process_user_data(db, "test_user")
    end).to.throw("Database connection lost")
  end)
end)
```

## Testing Patterns

### Testing Database-Dependent Code

```lua
describe("User Repository", function()
  it("retrieves users from database", function()
    -- Set up mock database
    local db = {
      connect = function() end,
      query = function() end,
      disconnect = function() end
    }
    
    with_mocks(function(mock_fn)
      -- Create mock
      local mock_db = mock_fn(db)
      
      -- Configure stubs
      mock_db:stub("connect", function() return { connected = true } end)
      mock_db:stub("query", function(query)
        -- Return mock data that matches the query pattern
        if query:match("FROM users") then
          return { rows = {
            { id = 1, name = "User 1" },
            { id = 2, name = "User 2" }
          }}
        end
        return { rows = {} }
      end)
      
      -- Create user repository with the mock database
      local user_repo = UserRepository:new(db)
      
      -- Test the method
      local users = user_repo:get_all_users()
      
      -- Verify results
      expect(users).to.exist()
      expect(#users).to.equal(2)
      expect(users[1].name).to.equal("User 1")
      
      -- Verify interactions
      expect(mock_db._stubs.connect.called).to.be_truthy()
      expect(mock_db._stubs.query.called).to.be_truthy()
      expect(mock_db._stubs.query.calls[1][1]).to.match("FROM users")
    end)
  end)
end)
```

### Testing API Clients

```lua
describe("Weather API Client", function()
  it("processes weather data correctly", function()
    -- Real HTTP client
    local http_client = {
      get = function(url) 
        -- Would make a real HTTP request
      end
    }
    
    -- Create weather client that uses the HTTP client
    local weather_client = WeatherClient:new(http_client)
    
    with_mocks(function(mock_fn)
      -- Mock the HTTP client
      local mock_http = mock_fn(http_client)
      
      -- Stub the get method to return test data
      mock_http:stub("get", function(url)
        expect(url).to.match("api.weather.example")
        
        return {
          status = 200,
          body = {
            temperature = 25,
            conditions = "sunny",
            location = "Test City"
          }
        }
      end)
      
      -- Test the weather client method
      local weather = weather_client:get_current_weather("Test City")
      
      -- Verify results
      expect(weather).to.exist()
      expect(weather.temperature).to.equal(25)
      expect(weather.conditions).to.equal("sunny")
      
      -- Verify HTTP client was called correctly
      expect(mock_http._stubs.get.called).to.be_truthy()
      expect(mock_http._stubs.get.calls[1][1]).to.match("Test City")
    end)
  end)
  
  it("handles API errors gracefully", function()
    -- Real HTTP client
    local http_client = {
      get = function(url) end
    }
    
    -- Create weather client that uses the HTTP client
    local weather_client = WeatherClient:new(http_client)
    
    with_mocks(function(mock_fn)
      -- Mock the HTTP client
      local mock_http = mock_fn(http_client)
      
      -- Stub the get method to return an error
      mock_http:stub("get", function()
        return {
          status = 500,
          body = { error = "Internal server error" }
        }
      end)
      
      -- Test the weather client method
      local weather, error_info = weather_client:get_current_weather("Test City")
      
      -- Verify error handling
      expect(weather).to_not.exist()
      expect(error_info).to.exist()
      expect(error_info.message).to.match("server error")
    end)
  end)
end)
```

### Testing Asynchronous Code

```lua
describe("Async Task Manager", function()
  it("processes tasks in the correct order", function()
    -- Task manager dependencies
    local scheduler = {
      schedule = function(task, delay) end,
      cancel = function(task_id) end
    }
    
    local logger = {
      log = function(message) end
    }
    
    with_mocks(function(mock_fn)
      -- Create mocks
      local mock_scheduler = mock_fn(scheduler)
      local mock_logger = mock_fn(logger)
      
      -- Track task execution order
      local executed_tasks = {}
      
      -- Stub scheduler to immediately execute tasks
      mock_scheduler:stub("schedule", function(task, delay)
        table.insert(executed_tasks, { task = task, delay = delay })
        task() -- Execute immediately for testing
        return #executed_tasks -- Return task ID
      end)
      
      -- Stub logger
      mock_logger:stub("log", function(message)
        -- Do nothing in test
      end)
      
      -- Create task manager with mocks
      local task_manager = AsyncTaskManager:new(scheduler, logger)
      
      -- Add tasks
      task_manager:add_task("task1", function() return "result1" end, 100)
      task_manager:add_task("task2", function() return "result2" end, 50)
      task_manager:add_task("task3", function() return "result3" end, 200)
      
      -- Verify tasks were scheduled with correct delays
      expect(mock_scheduler._stubs.schedule.call_count).to.equal(3)
      expect(executed_tasks[1].delay).to.equal(100)
      expect(executed_tasks[2].delay).to.equal(50)
      expect(executed_tasks[3].delay).to.equal(200)
      
      -- Verify task results
      local results = task_manager:get_completed_results()
      expect(#results).to.equal(3)
      
      -- Even though tasks had different delays, in our test they executed in the order added
      -- In real code with actual async behavior, this would be different
    end)
  end)
end)
```

## Best Practices

### Do's and Don'ts

| Do | Don't |
|----|-------|
| Clean up mocks after use | Leave mocks in place after tests |
| Mock at the right level of abstraction | Create unnecessarily complex mocks |
| Keep stub implementations simple | Add complex logic to stubs |
| Verify meaningful interactions | Verify implementation details that might change |
| Match the real API surface | Add methods that don't exist in the real object |
| Use with_mocks context for automatic cleanup | Manually track and restore multiple mocks |
| Validate inputs and outputs | Trust that mock implementation is correct |
| Test one behavior at a time | Create monolithic tests with many mocks |

### Always Clean Up Your Mocks

Failing to clean up mocks can cause tests to interfere with each other. Always restore mocks or use the `with_mocks` context manager:

```lua
-- BAD: No cleanup
local obj = { method = function() return "original" end }
local mock_obj = mock(obj)
mock_obj:stub("method", function() return "stubbed" end)
-- Other tests will now see the stubbed method!

-- GOOD: Manual cleanup
local obj = { method = function() return "original" end }
local mock_obj = mock(obj)
mock_obj:stub("method", function() return "stubbed" end)
-- Run test...
mock_obj:restore() -- Restore original method

-- BEST: Automatic cleanup with context manager
with_mocks(function(mock_fn)
  local mock_obj = mock_fn(obj)
  mock_obj:stub("method", function() return "stubbed" end)
  -- Run test...
  -- No need for manual cleanup, happens automatically
end)
```

### Keep Stub Implementations Simple

Stubs should be simple and deterministic. Avoid complex logic that could make your tests brittle:

```lua
-- BAD: Complex stub with side effects
local calculateStub = stub(function(a, b)
  print("calculating")
  math.randomseed(os.time())
  return a * b * math.random()
end)

-- GOOD: Simple, deterministic stub
local calculateStub = stub(function(a, b)
  return a * b
end)
```

### Verify Meaningful Interactions

Focus verification on the interactions that matter for the test, not implementation details:

```lua
-- BAD: Testing implementation details
expect(mock_db._stubs.connect.calls[1][2]).to.equal(5432) -- Port number might change

-- GOOD: Testing meaningful interaction
expect(mock_db._stubs.connect.called).to.be_truthy()
expect(mock_db._stubs.query.called_with("SELECT * FROM users")).to.be_truthy()
```

### Isolate Tests

Each test should create its own fresh mocks to avoid interference between tests:

```lua
-- BAD: Shared mock across tests
local mock_db = mock(database)

it("test 1", function()
  mock_db:stub("query", function() return {rows = {}} end)
  -- Test using mock_db
end)

it("test 2", function()
  -- This test is affected by stubs from test 1!
  -- Test using the same mock_db
end)

-- GOOD: Fresh mocks for each test
it("test 1", function()
  local mock_db = mock(database)
  mock_db:stub("query", function() return {rows = {}} end)
  -- Test using mock_db
  mock_db:restore()
end)

it("test 2", function()
  local mock_db = mock(database)
  mock_db:stub("query", function() return {count = 5} end)
  -- Test using fresh mock_db
  mock_db:restore()
end)

-- BEST: With automatic cleanup
it("test 1", function()
  with_mocks(function(mock_fn)
    local mock_db = mock_fn(database)
    mock_db:stub("query", function() return {rows = {}} end)
    -- Test using mock_db
  end)
end)

it("test 2", function()
  with_mocks(function(mock_fn)
    local mock_db = mock_fn(database)
    mock_db:stub("query", function() return {count = 5} end)
    -- Test using fresh mock_db
  end)
end)
```

## Troubleshooting

### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| Original method not restored | Use `with_mocks` context or manually call `restore()` |
| Mock verification fails | Check that expected methods were called with correct arguments |
| Unexpected behavior in stubs | Verify stub implementation and sequence configuration |
| Error: "attempt to call a nil value" | Ensure you're mocking a method that exists on the object |
| Stub not called | Verify you're using the mocked object in your test |
| Cannot spy on property | Spies only work on functions, not properties |

### Debugging Mocks

If you're having trouble with mocks, use these debugging techniques:

```lua
-- Print all calls to a spy
local function print_spy_calls(spy_obj)
  print("Call count: " .. spy_obj.call_count)
  for i, call in ipairs(spy_obj.calls) do
    print("Call " .. i .. " arguments:")
    for j, arg in ipairs(call) do
      print("  Arg " .. j .. ": " .. tostring(arg))
    end
  end
end

-- Usage
local fn = function() end
local spy_fn = spy(fn)
spy_fn("hello", 123)
spy_fn("world")
print_spy_calls(spy_fn)
```

### Restore Original Implementation If Test Fails

Make sure to restore original methods even if a test fails, to avoid affecting other tests:

```lua
-- Using pcall for error handling
local obj = { method = function() return "original" end }
local mock_obj = mock(obj)
mock_obj:stub("method", function() return "stubbed" end)

local success, err = pcall(function()
  -- Test that might fail...
  error("Test error")
end)

-- Always restore, even if test failed
mock_obj:restore()

if not success then
  -- Re-raise the error
  error(err)
end
```

Or better, use the `with_mocks` context manager which handles this automatically:

```lua
with_mocks(function(mock_fn)
  local mock_obj = mock_fn(obj)
  mock_obj:stub("method", function() return "stubbed" end)
  
  -- Even if this error occurs, mocks will still be restored
  error("Test error")
end)
```

## Conclusion

The Firmo mocking system provides powerful tools for isolated testing. By following the patterns and best practices in this guide, you can write more reliable and maintainable tests.

For more detailed API information, see the [Mocking API Reference](/docs/api/mocking.md), and for practical examples, see the [Mocking Examples](/examples/mocking_examples.md) file.