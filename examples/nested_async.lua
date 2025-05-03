--- examples/nested_async.lua
--- Demonstrates nested describe_async blocks and hook execution order.

local firmo = require("firmo")
local describe_async, it_async, it, expect, before, after, await =
  firmo.describe_async, firmo.it_async, firmo.it, firmo.expect, firmo.before, firmo.after, firmo.await

print("--- Running examples/nested_async.lua ---")

local hook_log = {}

describe_async("Outer Async Suite", function()
  before(function()
    print("  [Outer Before]")
    table.insert(hook_log, "Outer Before")
  end)

  after(function()
    print("  [Outer After]")
    table.insert(hook_log, "Outer After")
  end)

  it_async("Outer Test 1", function()
    print("    Starting Outer Test 1...")
    await(10)
    print("    ...Outer Test 1 finished")
    expect(true).to.be_truthy()
  end)

  describe_async("Inner Async Suite", function()
    before(function()
      print("    [Inner Before]")
      table.insert(hook_log, "Inner Before")
    end)

    after(function()
      print("    [Inner After]")
      table.insert(hook_log, "Inner After")
    end)

    it_async("Inner Test 1", function()
      print("      Starting Inner Test 1...")
      await(5)
      print("      ...Inner Test 1 finished")
      expect(true).to.be_truthy()
    end)

    it_async("Inner Test 2", function()
      print("      Starting Inner Test 2...")
      await(5)
      print("      ...Inner Test 2 finished")
      expect(true).to.be_truthy()
    end)
  end)

  it_async("Outer Test 2", function()
    print("    Starting Outer Test 2...")
    await(10)
    print("    ...Outer Test 2 finished")
    expect(true).to.be_truthy()
  end)

  -- Synchronous test to check hook log state at the end
  it("Verifies Hook Execution", function()
    print("    Verifying hook log...")
    -- Expected: OuterBefore, OuterTest1, OuterAfter,
    --           OuterBefore, InnerBefore, InnerTest1, InnerAfter, OuterAfter,
    --           OuterBefore, InnerBefore, InnerTest2, InnerAfter, OuterAfter,
    --           OuterBefore, OuterTest2, OuterAfter
    --           OuterBefore (for this test)
    -- Exact order isn't guaranteed between tests, but counts should be right.
    local counts = {}
    for _, entry in ipairs(hook_log) do
      counts[entry] = (counts[entry] or 0) + 1
    end

    -- Outer hooks run for Outer1, Inner1, Inner2, Outer2, and this sync test = 5 times
    expect(counts["Outer Before"]).to.equal(5)
    -- Outer After hasn't run for *this* test yet, so count is 4
    expect(counts["Outer After"]).to.equal(4)

    -- Inner hooks run only for Inner1, Inner2 = 2 times
    expect(counts["Inner Before"]).to.equal(2)
    expect(counts["Inner After"]).to.equal(2)
  end)
end)

