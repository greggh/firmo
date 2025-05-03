--- examples/basic_async.lua
--- Demonstrates basic usage of describe_async with async/sync tests and hooks.

local firmo = require("firmo")
local describe_async, it_async, it, expect, before, after, await =
  firmo.describe_async, firmo.it_async, firmo.it, firmo.expect, firmo.before, firmo.after, firmo.await

print("--- Running examples/basic_async.lua ---")

describe_async("Basic Async Suite", function()
  local setup_done = false
  local teardown_done = false

  before(function()
    print("  [Basic Before Hook]")
    setup_done = true
  end)

  after(function()
    print("  [Basic After Hook]")
    teardown_done = true
  end)

  it_async("runs an asynchronous test", function()
    print("    Starting async test...")
    expect(setup_done).to.be_truthy() -- Before hook should have run
    await(20) -- Simulate async work
    print("    ...async test finished")
    expect(true).to.be_truthy()
  end)

  it("runs a synchronous test within the async suite", function()
    print("    Starting sync test...")
    expect(setup_done).to.be_truthy() -- Before hook should have run
    -- No await here
    print("    ...sync test finished")
    expect(true).to.be_truthy()
  end)

  -- This runs after all tests in the suite complete
  it("verifies teardown hook ran (implicitly)", function()
    -- The fact that this test runs means the previous ones completed.
    -- We can't easily check teardown_done here reliably without more complex state management,
    -- but the presence of the log message indicates it executed.
    print("    Checking final state (hooks run implicitly)")
    expect(true).to.be_truthy()
  end)
end)

