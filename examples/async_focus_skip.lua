--- examples/async_focus_skip.lua
--- Demonstrates focus (fdescribe_async, fit_async) and skip (xdescribe_async, xit_async) features.
--- Uncomment sections or run with focus filters to see the behavior.

local firmo = require("firmo")
local describe_async, fdescribe_async, xdescribe_async = firmo.describe_async, firmo.fdescribe_async, firmo.xdescribe_async
local it_async, fit_async, xit_async = firmo.it_async, firmo.fit_async, firmo.xit_async
local expect, await = firmo.expect, firmo.await

print("--- Running examples/async_focus_skip.lua ---")

--[[ -- Uncomment this block to test fdescribe_async focus
fdescribe_async("FOCUS: Suite A (Focused with fdescribe_async)", function()
  it_async("Test A1 (runs because suite is focused)", function()
    print("    >> Running Test A1 (fdescribe_async)")
    await(5)
    expect(true).to.be_truthy()
  end)
end)
]]

describe_async("Suite B (Regular Suite)", function()
  it_async("Test B1 (skipped if focus mode active)", function()
    print("    >> Running Test B1 (should be skipped in focus mode)")
    await(5)
    expect(true).to.be_truthy()
  end)

  --[[ -- Uncomment this line to test fit_async focus
  fit_async("Test B2 (FOCUS: Focused with fit_async)", function()
    print("    >> Running Test B2 (fit_async)")
    await(5)
    expect(true).to.be_truthy()
  end)
  ]]

  it_async("Test B3 (skipped if focus mode active due to fit_async)", function()
    print("    >> Running Test B3 (should be skipped in focus mode)")
    await(5)
    expect(true).to.be_truthy()
  end)
end)

xdescribe_async("Suite C (SKIP: Skipped with xdescribe_async)", function()
  it_async("Test C1 (will not run)", function()
    print("    !! ERROR: Test C1 ran but should be skipped (xdescribe_async)")
    await(5)
    error("This test should have been skipped")
  end)
end)

describe_async("Suite D (Contains Skipped Test)", function()
  xit_async("Test D1 (SKIP: Skipped with xit_async)", function()
    print("    !! ERROR: Test D1 ran but should be skipped (xit_async)")
    await(5)
    error("This test should have been skipped")
  end)

  it_async("Test D2 (runs normally)", function()
    print("    >> Running Test D2 (should run)")
    await(5)
    expect(true).to.be_truthy()
  end)
end)

print("--- Finished examples/async_focus_skip.lua ---")

