--- Example demonstrating asynchronous tests running in Firmo's watch mode.
---
--- This example showcases how Firmo's asynchronous testing features (`it_async`,
--- `await`, `wait_until`) work correctly when using the `--watch` mode of the
--- test runner. Watch mode detects file changes and automatically re-runs tests,
--- including asynchronous ones.
---
--- @module examples.async_watch_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see firmo.it_async
--- @see firmo.await
--- @see firmo.wait_until
--- @usage
--- To see watch mode in action with async tests, run:
--- ```bash
--- lua firmo.lua --watch examples/async_watch_example.lua
--- ```
--- Then, try modifying and saving this file to see the tests re-run automatically.

-- Load firmo with async support
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(description: string, callback: function, timeout: number?) it_async Asynchronous test case function
local it_async = firmo.it_async
---@diagnostic disable-next-line: unused-local
---@type fun(ms: number): nil await Function to pause execution for a specified number of milliseconds
local await = firmo.await
local wait_until = firmo.wait_until

--- Main test suite demonstrating async tests running in watch mode.
--- @within examples.async_watch_example
describe("Async Watch Mode Example", function()
  --- A standard synchronous test case.
  it("runs standard synchronous tests", function()
    expect(1 + 1).to.equal(2)
  end)

  --- An asynchronous test using `await` to pause execution.
  it_async("waits for a specific time using await", function()
    local start_time = os.clock()

    -- Wait for 100ms
    await(100)

    -- Calculate elapsed time
    local elapsed = (os.clock() - start_time) * 1000

    -- Verify we waited approximately the right amount of time
    expect(elapsed).to.be_greater_than(90) -- Allow small timing variations
  end)
end)

--- An asynchronous test using `wait_until` to wait for a condition to become true.
it_async("waits for a condition using wait_until", function()
  local result = nil

  -- Simulate an async operation starting
  local start_time = os.clock() * 1000

  -- Create a condition that becomes true after 50ms
  local function condition()
    if os.clock() * 1000 - start_time >= 50 then
      result = "success"
      return true
    end
    return false
  end

  -- Wait for the condition to become true (with timeout)
  wait_until(condition, 200, 10)

  -- Now make assertions
  expect(result).to.equal("success")
end)

--- Demonstrates basic error handling within an async test (no error thrown here).
it_async("handles errors in async tests (no error case)", function()
  -- Wait a bit before checking an assertion that will pass
  await(50)
  expect(true).to.be.truthy()
  -- This test would fail if uncommented:
  -- error("Test failure")
end)

-- Test timeout handling (uncomment the `it_async` block below to see a timeout error)
--[[
  it_async("demonstrates timeout behavior", function()
    local condition_never_true = function() return false end

    -- This will timeout after 100ms because the condition never becomes true
    wait_until(condition_never_true, 100)

    -- This line won't execute due to timeout
    expect(true).to.be_truthy()
  end)
  --]]

-- If running this file directly (not via test runner), print usage instructions.
if arg and arg[0] and arg[0]:match("async_watch_example%.lua$") then
  print("\nAsync Watch Mode Example")
  print("=======================")
  print("This file demonstrates async testing with watch mode for continuous testing.")
  print("")
  print("To run with watch mode, use:")
  print("  lua firmo.lua --watch examples/async_watch_example.lua")
  print("")
  print("Watch mode with async will:")
  print("1. Run the async tests in this file.")
  print("2. Watch for changes to this or dependent files.")
  print("3. Automatically re-run tests when changes are detected.")
  print("4. Continue until you press Ctrl+C.")
  print("")
  print("Try editing this file while watch mode is running to see the tests automatically re-run.")
  print("")
  print("Tips:")
  print("- Uncomment the 'timeout' section (`it_async` block around line 89) to see timeout error handling.")
  print("- Change the wait times in `await()` calls to see how it affects test execution time.")
  print("- Experiment with different condition functions in `wait_until`.")
end
