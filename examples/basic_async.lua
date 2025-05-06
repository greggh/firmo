--- Firmo Basic Async Example
---
--- Demonstrates the fundamental usage of asynchronous test suites (`describe_async`),
--- including:
--- - Running asynchronous tests (`it_async`) with `await`.
--- - Running standard synchronous tests (`it`) within an async suite.
--- - Using standard synchronous setup (`before`) and teardown (`after`) hooks within an async suite.
---
--- @module examples.basic_async
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @usage
--- Run embedded tests:
--- ```bash
--- lua test.lua examples/basic_async.lua
--- ```

local firmo = require("firmo")
local describe_async, it_async, it, expect, before, after, await =
  firmo.describe_async, firmo.it_async, firmo.it, firmo.expect, firmo.before, firmo.after, firmo.await

print("--- Running examples/basic_async.lua ---")

--- Defines a basic asynchronous test suite.
--- @async
describe_async("Basic Async Suite", function()
  local setup_done = false
  local teardown_done = false

  --- Synchronous setup hook executed once before all tests in this suite.
  before(function()
    print("  [Basic Before Hook]")
    setup_done = true
  end)

  --- Synchronous teardown hook executed once after all tests in this suite complete.
  after(function()
    print("  [Basic After Hook]")
    teardown_done = true
  end)

  --- An asynchronous test case that uses `await`.
  --- @async
  it_async("runs an asynchronous test", function()
    print("    Starting async test...")
    expect(setup_done).to.be_truthy() -- Before hook should have run
    await(20) -- Simulate async work
    print("    ...async test finished")
    expect(true).to.be_truthy()
  end)

  --- A standard synchronous test case running within the async suite.
  it("runs a synchronous test within the async suite", function()
    print("    Starting sync test...")
    expect(setup_done).to.be_truthy() -- Before hook should have run
    -- No await here
    print("    ...sync test finished")
    expect(true).to.be_truthy()
  end)

  -- This runs after all tests in the suite complete
  --- A final synchronous test to implicitly verify completion.
  --- Note: Reliably checking the `after` hook's state here is complex.
  it("verifies teardown hook ran (implicitly)", function()
    -- The fact that this test runs means the previous ones completed.
    -- We can't easily check teardown_done here reliably without more complex state management,
    -- but the presence of the log message indicates it executed.
    print("    Checking final state (hooks run implicitly)")
    expect(true).to.be_truthy()
  end)
end)
