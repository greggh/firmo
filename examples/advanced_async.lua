--- examples/advanced_async.lua
--- Demonstrates more complex scenarios combining nesting, focus/skip, parallel, wait, and error handling.

local firmo = require("firmo")
local describe_async, fdescribe_async, xdescribe_async = firmo.describe_async, firmo.fdescribe_async, firmo.xdescribe_async
local it_async, fit_async, xit_async = firmo.it_async, firmo.fit_async, firmo.xit_async
local it, expect, before, after = firmo.it, firmo.expect, firmo.before, firmo.after
local await, parallel_async, wait_until = firmo.await, firmo.parallel_async, firmo.wait_until
local test_helper = require("lib.tools.test_helper")

print("--- Running examples/advanced_async.lua ---")

--[[ -- Uncomment to focus on this advanced suite
fdescribe_async("Advanced Async Scenarios", function()
  local shared_state = {}

  before(function()
    print("  [Advanced Before]")
    shared_state.setup = true
  end)

  after(function()
    print("  [Advanced After]")
    shared_state = {} -- Clean up
  end)

  it("basic sync check", function()
    expect(shared_state.setup).to.be_truthy()
  end)

  xit_async("a skipped test using parallel", function()
    print("  !! ERROR: Skipped test ran")
    local op1 = async.async(function() await(10); return 1 end)
    local op2 = async.async(function() await(5); return 2 end)
    local results = parallel_async({ op1(), op2() })
    expect(results).to.equal({ 1, 2 }) -- This code won't run
  end)

  describe_async("Nested Operations", function()
    local condition = false

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

    it_async("another test (skipped in focus mode)", function()
       print("  !! ERROR: Non-focused test ran")
       await(5)
       expect(true).to.be_truthy()
    end)
  end)

  it_async("final async check", function()
    expect(shared_state.setup).to.be_truthy()
    await(5)
  end)
end)
]]

-- Add a non-focused block to show it gets skipped when the above is uncommented
describe_async("Regular Suite (Should Be Skipped if Focus Active)", function()
  it_async("Regular Test", function()
    print("  !! ERROR: Regular suite test ran during focus mode!")
    await(1)
    expect(true).to.be_truthy()
  end)
end)

print("--- Finished examples/advanced_async.lua ---")
print("(Note: Uncomment focused blocks in the file to test focus behavior)")

