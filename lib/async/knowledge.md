# Async Module Knowledge

## Purpose

This document outlines key internal concepts, implementation patterns, and considerations for the `lib/async` module, intended for developers working on or understanding Firmo's asynchronous testing capabilities.

## Key Concepts

-   **Async Context:** Tests involving asynchronous operations must run within an async context. This is established automatically by `it_async` or can be created explicitly using `async.async(fn, timeout)`. The context manages timers and the event loop.
-   **Cooperative Event Loop:** The async module uses a simple, cooperative event loop based on timers (`os.clock`) and periodic polling (`wait_until`). It does *not* use native threads or complex event libraries. This means long-running synchronous operations within an async test will block the loop.
-   **`await(ms)`:** Pauses the current async execution path for a given number of milliseconds by scheduling a resume operation on the internal timer queue.
-   **`wait_until(condition_fn, timeout_ms?, check_interval_ms?)`:** Periodically calls `condition_fn` until it returns true or `timeout_ms` is reached. The polling frequency is determined by `check_interval_ms`. Execution continues after the condition is met or the timeout expires. It does *not* take a callback for handling the result.
-   **`parallel_async(functions)`:** Executes an array of functions concurrently within the async context. Each function can use `await` or other async operations. `parallel_async` completes when all functions in the array have finished. It returns an array containing the results of each function in the same order.
-   **`done()` Callback:** The function passed to `it_async` receives a `done` callback. This callback **must** be called exactly once when the asynchronous test logic is complete to signal the test runner. Failure to call `done` will result in a timeout. Passing an error to `done` is generally discouraged; prefer standard error handling patterns.
-   **Timeouts:** Async tests have a default timeout (configurable via `async.configure`). Timeouts can also be set per-test using the `it_async` options table or via the `timeout_ms` parameter in `wait_until`.

## Usage Examples / Patterns

*(Note: Examples assume `firmo`, `describe`, `it_async`, `expect`, `before`, `after`, `await`, `wait_until`, `parallel_async`, `test_helper`, `error_handler` are available in scope, typically via `require` statements.)*

### Basic Async Test (`it_async`)

```lua
-- Basic async test using the done callback
it_async("completes async operation", function(done)
  start_async_operation(function(result) -- Placeholder for your async func
    expect(result).to.exist()
    done() -- Must call done() on completion
  end)
end)
```

### Using `wait_until`

```lua
-- Using wait_until for conditions
it_async("waits for condition", function()
  local value = false
  -- Simulate async work setting value after 50ms
  await(50)
  value = true

  -- Wait up to 200ms for value to become true
  wait_until(function()
    return value
  end, 200)

  -- Check the state after waiting
  expect(value).to.be_truthy()
  -- Note: No callback to wait_until, execution resumes here
end)
```

### Custom Timeouts

```lua
-- Setting timeout for a specific test
it_async("tests with custom timeout", function()
  await(500) -- Simulate work
  expect(true).to.be_truthy()
end, 1000) -- Test times out after 1000ms (1 second)
```

### Complex Async Scenario (Concurrent Callbacks)

```lua
describe("Database operations", function()
  local db -- Placeholder

  before(function()
    db = require("database") -- Placeholder
    db.connect()
  end)

  it_async("handles concurrent operations", function(done)
    local results = {}
    local pending = 3

    local function check_done()
      pending = pending - 1
      if pending == 0 then
        expect(#results).to.equal(3)
        done() -- Signal completion only after all callbacks are done
      end
    end

    -- Start multiple async operations (using callbacks)
    db.query("SELECT 1", function(err, result)
      if not err then table.insert(results, result) end
      check_done()
    end)
    db.query("SELECT 2", function(err, result)
      if not err then table.insert(results, result) end
      check_done()
    end)
    db.query("SELECT 3", function(err, result)
      if not err then table.insert(results, result) end
      check_done()
    end)
  end)

  after(function()
    if db then db.disconnect() end
  end)
end)
```

### Async Error Handling

```lua
-- Async error handling using test_helper
it_async("handles async errors", { expect_error = true }, function()
  -- Use with_error_capture around the async logic initiation
  local _, err = test_helper.with_error_capture(function()
     -- Define an operation that will fail asynchronously
     local op = function()
       await(10)
       error("async failure")
     end
     -- Run it concurrently (or await it directly)
     parallel_async({op})
  end)() -- Note: with_error_capture wrapper returns a function, call it immediately

  -- Assert the error occurred
  expect(err).to.exist()
  expect(err.message).to.match("async failure")
  -- No done() needed here as the test function itself completes synchronously
  -- after the error is caught by with_error_capture's immediate call.
end)
```

### Timeout Handling (`wait_until`)

```lua
-- Demonstrating wait_until timeout
it_async("handles timeouts", function()
  local condition_met = false
  local check_condition = function() return condition_met end

  -- Wait for condition with a short timeout
  wait_until(check_condition, 100) -- Wait only 100ms

  -- Since condition_met is still false, the wait timed out.
  -- Test execution continues here.
  -- We can assert that the condition is still false.
  expect(check_condition()).to.be_falsy()
end, 200) -- Test timeout (must be >= wait_until timeout)
```

### Resource Cleanup

```lua
-- Resource cleanup using after hook
it_async("cleans up resources", function(done)
  local resources = {}
  local resource = create_resource() -- Placeholder
  table.insert(resources, resource)

  after(function()
    -- This runs AFTER the test completes (after done() is called)
    for _, res in ipairs(resources) do
      res:cleanup() -- Placeholder cleanup
    end
  end)

  -- Test code using the resource...
  await(50) -- Simulate async work

  done() -- Signal test completion
end)
```

## Related Components / Modules

-   **Source:** [`lib/async/init.lua`](init.lua)
-   **Usage Guide:** [`docs/guides/async.md`](../../docs/guides/async.md)
-   **API Reference:** [`docs/api/async.md`](../../docs/api/async.md)
-   **Error Handling:** [`lib/core/error_handler/init.lua`](../core/error_handler/init.lua) - Used for internal error handling.
-   **Test Definition:** [`lib/core/test_definition.lua`](../core/test_definition.lua) - Provides `it_async`.
