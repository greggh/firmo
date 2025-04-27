--- async_watch_example.lua
--
-- This example demonstrates running Firmo's asynchronous tests (`it_async`, `await`,
-- `wait_until`) within the test runner's `--watch` mode. It shows that watch
-- mode correctly handles and re-runs asynchronous tests when file changes
-- are detected.
--
-- Run with: lua test.lua --watch examples/async_watch_example.lua
--

---@diagnostic disable: undefined-global

-- Load firmo with async support
---@type Firmo
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
---@type fun(description: string, options: table|nil, callback: function) it Test case function with optional parameters
---@type fun(value: any) expect Assertion generator function
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
---@type fun(description: string, timeout: number?, callback: function) it_async Asynchronous test case function
local it_async = firmo.it_async
---@diagnostic disable-next-line: unused-local
---@type fun(ms: number): nil await Function to pause execution for a specified number of milliseconds
local await = firmo.await
local wait_until = firmo.wait_until

--- Main test suite demonstrating async tests running in watch mode.
describe("Async Watch Mode Example", function()
  -- Simple passing test
  it("runs standard synchronous tests", function()
    expect(1 + 1).to.equal(2)
  end)

  -- Async test with await
  it_async("waits for a specific time", function()
    local start_time = os.clock()

    -- Wait for 100ms
    await(100)

    -- Calculate elapsed time
    local elapsed = (os.clock() - start_time) * 1000

    -- Verify we waited approximately the right amount of time
    expect(elapsed).to.be_greater_than(90) -- Allow small timing variations
  end)

  -- Async test with wait_until
  it_async("waits for a condition", function()
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

  -- Test error handling
  it_async("handles errors in async tests", function()
    -- Wait a bit before checking an assertion that will pass
    await(50)
    expect(true).to.be.truthy()
    -- This test would fail if uncommented:
    -- error("Test failure")
  end)

  -- Test timeout handling (uncomment to see timeout error)
  -- it_async("demonstrates timeout behavior", function()
  --   local condition_never_true = function() return false end
  --
  --   -- This will timeout after 100ms
  --   wait_until(condition_never_true, 100)
  --
  --   -- This line won't execute due to timeout
  --   expect(true).to.be.truthy()
  -- end)
end)

-- If running this file directly, print usage instructions
if arg[0]:match("async_watch_example%.lua$") then
  print("\nAsync Watch Mode Example")
  print("=======================")
  print("This file demonstrates async testing with watch mode for continuous testing.")
  print("")
  print("To run with watch mode, use:")
  print("  lua test.lua --watch examples/async_watch_example.lua")
  print("")
  print("Watch mode with async will:")
  print("1. Run the async tests in this file")
  print("2. Watch for changes to any files")
  print("3. Automatically re-run tests when changes are detected")
  print("4. Continue until you press Ctrl+C")
  print("")
  print("Try editing this file while watch mode is running to see the tests automatically re-run.")
  print("")
  print("Tips:")
  print("- Uncomment the 'timeout' section to see timeout error handling")
  print("- Change the wait times to see how it affects test execution")
  print("- Try adding more complex async tests with multiple await calls")
  print("- Experiment with different condition functions in wait_until")
end
