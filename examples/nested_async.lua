--- Firmo Nested Async Example
---
--- Demonstrates the behavior of nested asynchronous test suites (`describe_async`)
--- and the execution order of setup (`before`) and teardown (`after`) hooks
--- in relation to nested suites and tests. It logs hook executions and verifies
--- the counts in a final test.
---
--- @module examples.nested_async
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @usage
--- Run embedded tests:
--- ```bash
--- lua test.lua examples/nested_async.lua
--- ```
--- Observe the printed log messages to understand the hook execution order.

local firmo = require("firmo")
local describe_async, it_async, it, expect, before, after, await =
  firmo.describe_async, firmo.it_async, firmo.it, firmo.expect, firmo.before, firmo.after, firmo.await

print("--- Running examples/nested_async.lua ---")

local hook_log = {}

--- Defines the outer asynchronous test suite.
--- @async
describe_async("Outer Async Suite", function()
  --- Setup hook for the outer suite. Runs before each test in the outer *and* inner suites.
  before(function()
    print("  [Outer Before]")
    table.insert(hook_log, "Outer Before")
  end)

  --- Teardown hook for the outer suite. Runs after each test in the outer *and* inner suites.
  after(function()
    print("  [Outer After]")
    table.insert(hook_log, "Outer After")
  end)

  --- An asynchronous test case in the outer suite.
  --- @async
  it_async("Outer Test 1", function()
    print("    Starting Outer Test 1...")
    await(10)
    print("    ...Outer Test 1 finished")
    expect(true).to.be_truthy()
  end)

  --- Defines a nested asynchronous test suite.
  --- @async
  describe_async("Inner Async Suite", function()
    --- Setup hook for the inner suite. Runs before each test *only* within this inner suite.
    before(function()
      print("    [Inner Before]")
      table.insert(hook_log, "Inner Before")
    end)

    --- Teardown hook for the inner suite. Runs after each test *only* within this inner suite.
    after(function()
      print("    [Inner After]")
      table.insert(hook_log, "Inner After")
    end)

    --- An asynchronous test case within the inner suite.
    --- @async
    it_async("Inner Test 1", function()
      print("      Starting Inner Test 1...")
      await(5)
      print("      ...Inner Test 1 finished")
      expect(true).to.be_truthy()
    end)

    --- Another asynchronous test case within the inner suite.
    --- @async
    it_async("Inner Test 2", function()
      print("      Starting Inner Test 2...")
      await(5)
      print("      ...Inner Test 2 finished")
      expect(true).to.be_truthy()
    end)
  end)

  --- Another asynchronous test case in the outer suite.
  --- @async
  it_async("Outer Test 2", function()
    print("    Starting Outer Test 2...")
    await(10)
    print("    ...Outer Test 2 finished")
    expect(true).to.be_truthy()
  end)

  -- Synchronous test to check hook log state at the end
  --- Synchronous test that verifies the number of times each hook was executed.
  --- Demonstrates the expected execution counts based on nesting.
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
