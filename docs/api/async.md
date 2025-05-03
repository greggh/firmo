# Async Module API Reference

The async module provides asynchronous testing capabilities, enabling tests to work with time-dependent operations using `await`, `wait_until`, and `parallel_async`. It integrates with Firmo via `it_async`.

## Core Functions

### async.async(fn)

Converts a function to one that can be executed asynchronously. Transforms a regular function into an async-compatible function that can be used with the async testing infrastructure.
**Parameters:**

- `fn` (function): The function to convert to an async function

**Returns:**

- A wrapper function that captures arguments. Calling the wrapper returns an _executor_ function which, when called, runs the original `fn` within the async context.

**Example:**

```lua
-- Create an async version of a function
local async_fetch = async.async(function(url)
  -- Simulate network delay
  async.await(100)
  return "Content from " .. url
end)
-- Use it in a test
it("fetches data asynchronously", function()
  local result = async_fetch("https://example.com")() -- Note the double call to execute
  expect(result).to.match("Content from")
end)
```

### async.await(ms)

Pauses execution for the specified number of milliseconds. This must be called within an async context (created by async.async).
**Parameters:**

- `ms` (number): The number of milliseconds to wait (must be non-negative)

**Returns:** None
**Throws:**

- Error if called outside an async context
- Error if ms is not a non-negative number

**Example:**

```lua
-- Use in an async function
local async_fn = async.async(function()
  -- Do something
  async.await(100) -- Wait for 100ms
  -- Continue execution after the delay
end)
```

### async.wait_until(condition, [timeout], [check_interval])

Repeatedly checks a condition function until it returns true or until the timeout is reached. This is useful for waiting for asynchronous operations to complete or for testing conditions that may become true over time.
**Parameters:**

- `condition` (function): Function that returns true when the condition is met
- `timeout_ms` (number, optional): Maximum time in milliseconds before failing (default: configured default_timeout)
- `check_interval_ms` (number, optional): Interval in milliseconds between condition checks (default: configured check_interval)

**Returns:**

- `boolean`: True if the condition was met before the timeout

**Throws:**

- Error if the timeout is exceeded before the condition is met
- Error if called outside an async context
- Error if arguments are invalid

**Example:**

```lua
-- Wait for an asynchronous condition
local counter = 0
local increment = async.async(function()
  async.await(10)
  counter = counter + 1
end)
-- Start the async operation
increment()()
-- Wait until counter reaches the expected value
async.wait_until(function() return counter >= 1 end, 100)
```

### async.parallel_async(operations, [timeout])

Runs multiple async operations concurrently and waits for all to complete. This provides simulated concurrency in Lua's single-threaded environment by executing operations in small chunks using a round-robin approach.
**Parameters:**

- `operations` ({function}): An array-like table where each element is an **executor** function returned by calling the result of `async.async(...)` (e.g., `my_async_func(args)()` ).
- `timeout_ms` (number, optional): Maximum time in milliseconds before failing (default: configured default_timeout)

**Returns:**

- Array of results from each operation in the same order as the input operations

**Throws:**

- Error if any operation fails
- Error if the timeout is exceeded
- Error if called outside an async context
- Error if arguments are invalid

**Example:**

```lua
-- Run multiple async operations concurrently
local results = async.parallel_async({
  async.async(function() async.await(50); return "first" end)(),
  async.async(function() async.await(30); return "second" end)(),
  async.async(function() async.await(10); return "third" end)()
}, 200) -- 200ms timeout
-- Check results (will be ["first", "second", "third"])
expect(#results).to.equal(3)
```

## Configuration Functions

### async.configure(options)

Configures the async module behavior and settings. Sets up configuration options including timeouts, check intervals, and debugging settings.
**Parameters:**

- `options` (table, optional): Configuration options object with the following optional fields:
  - `default_timeout` (number): Default timeout in milliseconds for async operations
  - `check_interval` (number): Interval in milliseconds for checking conditions
  - `debug` (boolean): Enable debug logging
  - `verbose` (boolean): Enable verbose logging

**Returns:**

- The async_module for method chaining

**Example:**

```lua
-- Configure async settings
async.configure({
  default_timeout = 2000,  -- 2 seconds default timeout
  check_interval = 20,     -- Check conditions every 20ms
  debug = true,            -- Enable debug logging
  verbose = false          -- Disable verbose logging
})
-- Configure a single setting with method chaining
async.configure({ default_timeout = 5000 }).set_check_interval(50)
```

### async.set_timeout(ms)

Sets the default timeout for all async operations. Changes the global default timeout used for async operations like parallel_async and wait_until when no explicit timeout is provided.
**Parameters:**

- `ms` (number): The timeout in milliseconds (must be a positive number)

**Returns:**

- The async_module for method chaining

**Example:**

```lua
-- Set a longer default timeout for all async operations
async.set_timeout(5000)  -- 5 seconds
-- Use with method chaining
async.set_timeout(3000).set_check_interval(100)
```

### async.set_check_interval(ms)

Sets the polling interval for wait_until conditions. This determines how frequently the condition function is checked.
**Parameters:**

- `ms` (number): The interval in milliseconds (must be a positive number)

**Returns:**

- The async_module for method chaining

**Example:**

```lua
-- Set a longer check interval
async.set_check_interval(100)  -- Check every 100ms
-- Use with method chaining
async.set_check_interval(20).set_timeout(2000)
```

## State Management Functions

### async.reset()

Resets the async state between test runs. This preserves configuration but clears internal state like the async context flag.
**Returns:**

- The async_module for method chaining

**Example:**

```lua
-- Reset after tests to ensure a clean state
after_each(function()
  async.reset()
end)
```

### async.full_reset()

Completely resets module state including configuration. Reverts all settings to default values.
**Returns:**

- The async_module for method chaining

**Example:**

```lua
-- Completely reset async module for tests
before_all(function()
  async.full_reset()
end)
```

## Information Functions

### async.is_in_async_context()

Checks if code is currently executing in an async context.
**Returns:**

- `boolean`: True if in an async context, false otherwise

**Example:**

```lua
-- Check if we're in an async context before using async functions
if async.is_in_async_context() then
  async.await(100)
else
  -- Use alternative approach for non-async context
end
```

### async.get_timeout()

Gets the current default timeout for async operations in milliseconds.
**Deprecated:** This function is deprecated. Check configuration using `async.debug_config()` or access directly via central configuration if needed.
**Returns:**

- `number`: The current default timeout in milliseconds

**Example:**

```lua
-- Get the current timeout setting
local timeout = async.get_timeout()
print("Current timeout:", timeout, "ms")
```

### async.debug_config()

Displays the current configuration for debugging purposes. Useful for troubleshooting and ensuring appropriate settings.
**Returns:**

- A table containing configuration information

**Example:**

```lua
-- Inspect current configuration
local config = async.debug_config()
print("Default timeout:", config.local_config.default_timeout)
print("Check interval:", config.local_config.check_interval)
print("Using central_config:", config.using_central_config)
```

## Integration with firmo

When using the async module through the firmo framework, the following convenience functions are available:

### firmo.it_async(description, [async_fn], [timeout])

Creates an async-aware test case with proper timeout handling. This is a convenience wrapper around `it()` and `async()`.
**Parameters:**

- `description` (string): The test case description.
- `options_or_fn` (table|function): Either an options table (e.g., `{ expect_error = true }`) or the async test function itself.
- `fn` (function, optional): The async test function, if `options_or_fn` was an options table.
- `timeout_ms` (number, optional): Maximum time in milliseconds before failing (defaults to `async.configure` setting).

**Example:**

```lua
firmo.it_async("performs async operation", function()
  firmo.await(100)
  expect(true).to.be_truthy()
end, 2000) -- 2 second timeout
```

### firmo.fit_async(description, options_or_fn, fn?, timeout_ms?)

Defines a focused asynchronous test case using `firmo.fit`. Only focused tests run if any exist. This function is a convenience wrapper around `async_module.it_async` that sets the `focused` option to true.

**Parameters:**

- `description` (string): The description of the test case.
- `options_or_fn` (table|function): Either an options table (e.g., `{ expect_error = true }`) or the async test function itself.
- `fn` (function, optional): The async test function, if `options_or_fn` was an options table.
- `timeout_ms` (number, optional): Optional timeout in milliseconds for this specific test case.

**Returns:** None

**Throws:**

- Error if arguments are invalid or if the underlying `it_async` call fails.

**Example:**

```lua
-- Focus on this specific async test
firmo.fit_async("processes data quickly", function()
  firmo.await(10)
  expect(get_data_status()).to.equal("processed")
end)

-- This test will be skipped if focus mode is active
firmo.it_async("handles regular operations", function()
  -- ...
end)
```

### firmo.xit_async(description, options_or_fn, fn?, timeout_ms?)

Defines a skipped asynchronous test case using `firmo.xit`. It will not be run. This function is a convenience wrapper around `async_module.it_async` that sets the `excluded` option to true.

**Parameters:**

- `description` (string): The description of the test case.
- `options_or_fn` (table|function): Either an options table (e.g., `{ expect_error = true }`) or the async test function itself.
- `fn` (function, optional): The async test function, if `options_or_fn` was an options table.
- `timeout_ms` (number, optional): Optional timeout (ignored as test is skipped, but kept for signature consistency).

**Returns:** None

**Throws:**

- Error if arguments are invalid.

**Example:**

```lua
-- Skip this async test temporarily
firmo.xit_async("integrates with external service", function()
  -- This code will not run
  firmo.await(1000)
  expect(service_status()).to.equal("ready")
end)

-- Other async tests will run normally
firmo.it_async("performs basic operations", function()
  firmo.await(10)
  expect(true).to.be_truthy()
end)
```

### firmo.describe_async(name, fn, options?)

Defines an asynchronous test group (suite) using `firmo.describe`. Tests inside can use async features (`it_async`, `await`, etc.). It delegates the group definition (including nesting, hooks, and filtering logic) to `firmo.describe`.

**Parameters:**

- `name` (string): Name of the test group.
- `fn` (function): Function containing the test group's definitions (e.g., `it_async` calls, nested `describe_async`).
- `options` (table, optional): Optional table containing flags:
  - `focused` (boolean): If true, marks this group as focused (via `firmo.fdescribe`).
  - `excluded` (boolean): If true, marks this group to be skipped (via `firmo.xdescribe`).

**Returns:** None

**Throws:**

- Error if `firmo.describe` is not available or if the underlying `describe` call fails.

**Example:**

```lua
firmo.describe_async("Async Database Operations", function()
  firmo.before(function() -- Setup can be sync or async
     -- db_connect()
  end)

  firmo.it_async("should fetch user data", function()
    local data = nil
    -- db.fetch_user_async(1, function(res) data = res end)
    firmo.await(10) -- Simulate fetch
    data = { id = 1 }
    firmo.wait_until(function() return data ~= nil end)
    expect(data.id).to.equal(1)
  end)

  firmo.after(function()
    -- db_disconnect()
  end)
end)
```

### firmo.fdescribe_async(name, fn)

Defines a focused asynchronous test group using `firmo.fdescribe`. When focus mode is active, only focused suites and focused tests will be run. This is a convenience wrapper around `describe_async` that sets the `focused` option to true.

**Parameters:**

- `name` (string): Name of the test group.
- `fn` (function): Function containing the test group's definitions.

**Returns:** None

**Throws:**

- Error if the underlying `describe_async` call fails.

**Example:**

```lua
-- Focus on this group of async tests
firmo.fdescribe_async("Critical Async Feature", function()
  firmo.it_async("must complete successfully", function()
    -- ... async test logic ...
    firmo.await(10)
    expect(true).to.be_truthy()
  end)
end)

-- This group will be skipped if focus mode is active
firmo.describe_async("Non-critical Features", function()
  -- ... other tests ...
end)
```

### firmo.xdescribe_async(name, fn)

Defines a skipped asynchronous test group using `firmo.xdescribe`. All tests and hooks defined within this group will be skipped during test execution. This is a convenience wrapper around `describe_async` that sets the `excluded` option to true.

**Parameters:**

- `name` (string): Name of the test group.
- `fn` (function): Function containing the test group's definitions (these will be skipped).

**Returns:** None

**Throws:**

- Error if the underlying `describe_async` call fails.

**Example:**

```lua
-- Skip this entire group of async tests
firmo.xdescribe_async("Legacy Async Code", function()
  firmo.it_async("uses old patterns", function()
    -- This test will not run
  end)
end)

-- Other groups run normally
firmo.describe_async("Current Async Features", function()
  firmo.it_async("works as expected", function()
    -- This test runs
    firmo.await(5)
    expect(true).to.be_truthy()
  end)
end)
```

## Advanced Functions

## Error Handling

The async module integrates with the error_handler module to provide structured error objects. When errors occur in async operations, they include:

- Clear error messages with timing information
- Context information about what operation failed
- References to the operations that did not complete
- Proper propagation of errors through the async chain

This structured error reporting makes it much easier to diagnose issues in asynchronous tests.

## Best Practices

1. Always set appropriate timeouts based on the expected operation duration
2. Prefer wait_until() instead of fixed await() times when waiting for conditions
3. Use parallel_async() for independent operations that can run concurrently
4. Always run async operations within an async context created by async()
5. Clean up resources in after() hooks to avoid cross-test contamination
6. Use the configure() method at the beginning of tests for consistent behavior

## Placeholder Promise/Scheduler Functions

The `async` module's JSDoc lists several functions related to promises (`all`, `race`, `catch`, `finally`, `timeout`) and scheduling (`scheduler`, `cancel`, `poll`, `defer`). Please note that these functions are currently placeholders or deprecated and **are not fully implemented**. Their functionality should not be relied upon.
