--- Firmo Async Focus and Skip Example
---
--- Demonstrates how to focus execution on specific asynchronous tests/suites using:
--- - `fdescribe_async()`: Focuses on all tests within the described suite.
--- - `fit_async()`: Focuses on a single asynchronous test.
---
--- Also shows how to skip execution of specific asynchronous tests/suites using:
--- - `xdescribe_async()`: Skips all tests within the described suite.
--- - `xit_async()`: Skips a single asynchronous test.
---
--- Note: The focused blocks (`fdescribe_async`, `fit_async`) are commented out by default.
---       Uncomment them individually to observe their behavior and how they affect which
---       tests are executed. When focus is active, only focused tests/suites run.
---       Skipped blocks (`xdescribe_async`, `xit_async`) will never run.
---
--- @module examples.async_focus_skip
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @usage
--- Run embedded tests:
--- ```bash
--- lua firmo.lua examples/async_focus_skip.lua
--- ```
--- To test focus, uncomment the `fdescribe_async` or `fit_async` blocks in the file before running.

local firmo = require("firmo")
local describe_async, fdescribe_async, xdescribe_async =
  firmo.describe_async, firmo.fdescribe_async, firmo.xdescribe_async
local it_async, fit_async, xit_async = firmo.it_async, firmo.fit_async, firmo.xit_async
local expect, await = firmo.expect, firmo.await

print("--- Running examples/async_focus_skip.lua ---")

--[[ -- Uncomment this block to test fdescribe_async focus
fdescribe_async("FOCUS: Suite A (Focused with fdescribe_async)", function()
--- A test within the focused suite A.
--- @async
  it_async("Test A1 (runs because suite is focused)", function()
    print("    >> Running Test A1 (fdescribe_async)")
    await(5)
    expect(true).to.be_truthy()
  end)
end)
]]

describe_async("Suite B (Regular Suite)", function()
  --- A regular test in Suite B. Skipped if focus mode is active elsewhere.
  --- @async
  it_async("Test B1 (skipped if focus mode active)", function()
    print("    >> Running Test B1 (should be skipped in focus mode)")
    await(5)
    expect(true).to.be_truthy()
  end)

  --[[ -- Uncomment this line to test fit_async focus
--- A focused test within Suite B. If uncommented (and Suite A is not focused),
--- only this test will run.
--- @async
  fit_async("Test B2 (FOCUS: Focused with fit_async)", function()
    print("    >> Running Test B2 (fit_async)")
    await(5)
    expect(true).to.be_truthy()
  end)
  ]]

  --- Another regular test in Suite B. Skipped if focus mode is active elsewhere (e.g., on Test B2).
  --- @async
  it_async("Test B3 (skipped if focus mode active due to fit_async)", function()
    print("    >> Running Test B3 (should be skipped in focus mode)")
    await(5)
    expect(true).to.be_truthy()
  end)
end)

xdescribe_async("Suite C (SKIP: Skipped with xdescribe_async)", function()
  --- A test within the skipped Suite C. Will not run.
  --- @async
  it_async("Test C1 (will not run)", function()
    print("    !! ERROR: Test C1 ran but should be skipped (xdescribe_async)")
    await(5)
    error("This test should have been skipped")
  end)
end)

describe_async("Suite D (Contains Skipped Test)", function()
  --- A skipped test within Suite D. Will not run.
  --- @async
  xit_async("Test D1 (SKIP: Skipped with xit_async)", function()
    print("    !! ERROR: Test D1 ran but should be skipped (xit_async)")
    await(5)
    error("This test should have been skipped")
  end)

  --- A regular test within Suite D. Will run normally unless focus is active elsewhere.
  --- @async
  it_async("Test D2 (runs normally)", function()
    print("    >> Running Test D2 (should run)")
    await(5)
    expect(true).to.be_truthy()
  end)
end)

print("--- Finished examples/async_focus_skip.lua ---")
