--- Example demonstrating Firmo's asynchronous testing capabilities.
---
--- This example showcases:
--- - Defining asynchronous tests using `it_async()` and `firmo.async()`.
--- - Pausing execution using `await(milliseconds)`.
--- - Waiting for a condition to become true using `wait_until(condition_fn, timeout, interval)`.
--- - Handling test timeouts (conceptually, as direct promise testing is removed).
---
--- @module examples.async_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.async
--- @see firmo.it_async
--- @see firmo.await
--- @see firmo.wait_until
--- @usage
--- Run embedded tests:
--- ```bash
--- lua test.lua examples/async_example.lua
--- ```

local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(description: string, callback: function, timeout: number?) it_async Asynchronous test case function
local it_async = firmo.it_async

-- Extract async testing functions
local await = firmo.await
local wait_until = firmo.wait_until
-- NOTE: Do not define a local `async = firmo.async` as it might cause confusion.
-- Use `firmo.async()` directly if needed.

-- Removed AsyncAPI simulation as underlying promise functions are not implemented

--- Main test suite demonstrating Firmo's async testing features.
--- @within examples.async_example
describe("Async Testing Demo", function()
  --- Tests for basic `await(milliseconds)` and `wait_until(condition)` functionality.
  --- @within examples.async_example
  describe("Basic await and wait_until", function()
    --- Tests that `await(ms)` pauses execution for approximately the specified duration.
    it_async("waits for a specified time using await(ms)", function()
      local start_time = os.clock()

      -- Wait for 100ms
      await(100)

      local elapsed = (os.clock() - start_time) * 1000
      expect(elapsed).to.exist()
      expect(elapsed).to.be_greater_than(90) -- Allow for timing variations
    end)

    --- Demonstrates making assertions after an `await` call.
    it_async("can perform assertions after waiting", function()
      local value = 0

      -- Simulate an async operation that changes a value after 50ms
      await(50)
      value = 42

      -- Now we can make assertions on the updated value
      expect(value).to.equal(42)
    end)

    --- Tests `wait_until` by waiting for a flag to be set asynchronously.
    it_async("waits until a condition is met using wait_until", function()
      local flag = false
      -- Simulate setting the flag after a delay
      await(75) -- Simulate delay before setting flag
      flag = true

      -- Wait until the flag becomes true (up to 200ms timeout)
      local condition_met = wait_until(function()
        return flag -- The condition function checks the flag
      end, 200) -- Specify timeout

      expect(condition_met).to.be_truthy() -- wait_until returns true if condition met before timeout
      expect(flag).to.equal(true) -- Verify the flag was actually set
    end)
  end)

  -- Removed describe block for "Simulated API testing with Promises" as the
  -- underlying promise functions (create_promise, etc.) are not implemented.

  --- Tests demonstrating the explicit use of `firmo.async()` wrapper for test functions.
  --- @within examples.async_example
  describe("Using firmo.async() wrapper directly", function()
    --- Runs an async test function wrapped in `firmo.async()` manually.
    -- Note: `it_async` is generally preferred as it handles this wrapping automatically.
    it(
      "runs an async test manually wrapped in firmo.async()",
      firmo.async(function() -- Manually wrap the test function
        local start_time = os.clock()
        await(100)
        local elapsed = (os.clock() - start_time) * 1000
        expect(elapsed).to.be_greater_than(90)
      end)
    )

    --- Demonstrates nested `await` calls within a test manually wrapped by `firmo.async()`.
    it(
      "supports nested awaits within manually wrapped firmo.async()",
      firmo.async(function() -- Manually wrap
        local value = 0
        await(50) -- First await
        value = value + 1
        await(50) -- Second await
        value = value + 1
        expect(value).to.equal(2) -- Final assertion
      end)
    )
  end)
end)
