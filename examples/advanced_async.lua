--- Firmo Advanced Async Example
---
--- Demonstrates more complex asynchronous testing scenarios, including:
--- - Nested `describe_async` blocks.
--- - Focused (`fit_async`, `fdescribe_async`) and skipped (`xit_async`, `xdescribe_async`) tests/suites.
--- - Usage of `firmo.parallel_async` within a test (currently skipped).
--- - Usage of `firmo.wait_until` for polling conditions.
--- - Handling expected asynchronous errors using `test_helper.expect_async_error`.
--- - Basic setup (`before`) and teardown (`after`) within an async suite.
---
--- Note: Some blocks are commented out (`--[[ ... ]]`). Uncomment the `fdescribe_async` block
---       to see focus behavior in action (only focused tests within that block will run).
---
--- @module examples.advanced_async
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
local firmo = require("firmo")
local describe_async, fdescribe_async, xdescribe_async =
  firmo.describe_async, firmo.fdescribe_async, firmo.xdescribe_async
local it_async, fit_async, xit_async = firmo.it_async, firmo.fit_async, firmo.xit_async
local it, expect, before, after = firmo.it, firmo.expect, firmo.before, firmo.after
local await, parallel_async, wait_until = firmo.await, firmo.parallel_async, firmo.wait_until
local test_helper = require("lib.tools.test_helper")

print("--- Running examples/advanced_async.lua ---")

--[[ -- Uncomment to focus on this advanced suite
--- Defines the main suite demonstrating advanced async features.
--- @async
fdescribe_async("Advanced Async Scenarios", function()
  local shared_state = {}

--- Sets up shared state before tests in the advanced suite run.
  before(function()
    print("  [Advanced Before]")
    shared_state.setup = true
  end)

--- Cleans up shared state after tests in the advanced suite run.
  after(function()
    print("  [Advanced After]")
    shared_state = {} -- Clean up
  end)

--- A basic synchronous test to verify the 'before' hook ran.
  it("basic sync check", function()
    expect(shared_state.setup).to.be_truthy()
  end)

--- A skipped asynchronous test demonstrating `parallel_async`.
--- This test will not execute because it starts with 'x'.
--- @async
  xit_async("a skipped test using parallel", function()
    print("  !! ERROR: Skipped test ran")
    local op1 = async.async(function() await(10); return 1 end)
    local op2 = async.async(function() await(5); return 2 end)
    local results = parallel_async({ op1(), op2() })
    expect(results).to.equal({ 1, 2 }) -- This code won't run
  end)

--- Defines a nested suite focusing on specific async utilities.
--- @async
  describe_async("Nested Operations", function()
    local condition = false

--- Demonstrates using `wait_until` to poll for a condition set by another async operation.
--- @async
    it_async("uses wait_until", function()
      print("    Starting wait_until test...")
      local setter = async.async(function()
        await(30)
        condition = true
        print("    Condition set to true")
      end)
      setter()() -- Start the async setter

      print("    Waiting for condition...")
      local success = wait_until(function() return condition == true end, 100)
      expect(success).to.be_truthy()
      expect(condition).to.be_truthy()
      print("    ...wait_until test finished")
    end)

    -- Focus on this specific error handling test
--- A focused test demonstrating `test_helper.expect_async_error` to catch expected errors.
--- If the outer `fdescribe_async` is uncommented, only this test within the nested suite will run.
--- @async
    fit_async("handles expected errors with helper", function()
      print("    Starting focused error test...")
      local failing_op = async.async(function()
        await(15)
        error("Advanced deliberate error")
      end)
      local err = test_helper.expect_async_error(failing_op, 50, "deliberate error")
      expect(err).to.exist()
      expect(err.message).to.match("Advanced deliberate error")
      print("    ...focused error test finished")
    end)

--- Another standard async test. It will be skipped if focus mode is active elsewhere.
--- @async
    it_async("another test (skipped in focus mode)", function()
       print("  !! ERROR: Non-focused test ran")
       await(5)
       expect(true).to.be_truthy()
    end)
  end)

--- A final simple async test in the main suite.
--- @async
  it_async("final async check", function()
    expect(shared_state.setup).to.be_truthy()
    await(5)
  end)
end)
]]

-- Add a non-focused block to show it gets skipped when the above is uncommented
--- A regular async suite defined outside the focused block.
--- Used to demonstrate that it gets skipped when focus mode is active elsewhere.
--- @async
describe_async("Regular Suite (Should Be Skipped if Focus Active)", function()
  --- A regular async test within the non-focused suite.
  --- Should not run if focus is active in the commented-out block above.
  --- @async
  it_async("Regular Test", function()
    print("  !! ERROR: Regular suite test ran during focus mode!")
    await(1)
    expect(true).to.be_truthy()
  end)
end)

print("--- Finished examples/advanced_async.lua ---")
print("(Note: Uncomment focused blocks in the file to test focus behavior)")
