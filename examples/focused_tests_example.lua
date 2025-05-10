--- This example demonstrates Firmo's focus (`fit`, `fdescribe`) and exclude
--- (`xit`, `xdescribe`) features, which allow developers to selectively run
-- or skip specific tests or test suites.
--
-- It also includes a test designed to fail with a table comparison to show
-- the enhanced diff output provided by Firmo's assertion library.
--
-- @module examples.focused_tests_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see firmo
-- @usage
-- Run embedded tests: lua firmo.lua examples/focused_tests_example.lua
--

local firmo = require("firmo")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("FocusedExample")

-- Extract the functions we need, including focused/excluded variants
local describe, fdescribe, xdescribe = firmo.describe, firmo.fdescribe, firmo.xdescribe
local it = firmo.it
local fit = firmo.fit
local xit = firmo.xit
local expect = firmo.expect

-- Create a counter to verify excluded tests don't run (still useful for demonstration)
local excluded_test_ran = false

-- Standard describe block
--- A standard test suite containing a mix of normal, focused (`fit`), and excluded (`xit`) tests.
--- @within examples.focused_tests_example
describe("Standard tests", function()
  --- A regular test case that runs unless focus mode is active elsewhere.
  it("runs normally (if no fit/fdescribe is active)", function()
    logger.info("Executing 'runs normally' test...")
    expect(1 + 1).to.equal(2)
  end)

  --- Another regular test case.
  it("also runs normally (if no fit/fdescribe is active)", function()
    logger.info("Executing 'also runs normally' test...")
    expect("test").to.be.a("string")
  end)

  --- A focused test case (`fit`). If any `fit` or `fdescribe` exists, only focused items run.
  fit("is focused using 'fit' and WILL run", function()
    logger.info("Executing FOCUSED 'fit' test...")
    expect(true).to.be_truthy()
  end)

  --- An excluded test case (`xit`). This test will always be skipped.
  xit("is excluded using 'xit' and WILL NOT run", function()
    excluded_test_ran = true
    expect(false).to.be.truthy() -- This would fail if it ran
  end)
end)

-- Focused describe block - all tests inside will run because the suite is focused
--- A focused test suite (`fdescribe`). All tests within this block WILL run
-- because the suite itself is focused (unless individually excluded with `xit`).
--- @within examples.focused_tests_example
fdescribe("Focused test group (fdescribe)", function()
  --- A regular `it` within an `fdescribe` WILL run.
  it("will run because parent suite is focused", function()
    logger.info("Executing test within FOCUSED 'fdescribe'...")
    expect({ 1, 2, 3 }).to.contain(2)
  end)

  --- Another regular `it` within an `fdescribe` WILL run.
  it("also runs because parent suite is focused", function()
    logger.info("Executing another test within FOCUSED 'fdescribe'...")
    expect("hello").to.match("he..o")
  end)

  --- An excluded test (`xit`) within an `fdescribe` WILL NOT run.
  xit("is excluded using 'xit' despite focused parent suite", function()
    expect(nil).to.exist() -- Would fail if it ran
  end)
end)

-- Excluded describe block - none of these tests will run
--- An excluded test suite (`xdescribe`). No tests within this block WILL run,
-- regardless of focus mode or individual test focus (`fit`).
--- @within examples.focused_tests_example
xdescribe("Excluded test group (xdescribe)", function()
  --- A regular `it` within an `xdescribe` WILL NOT run.
  it("will NOT run because parent suite is excluded", function()
    excluded_test_ran = true
    expect(1).to.be(2) -- Would fail if it ran
  end)

  --- A focused `fit` within an `xdescribe` WILL NOT run.
  fit("is focused using 'fit' but WILL NOT run due to excluded parent suite", function()
    excluded_test_ran = true
    expect(false).to.be.truthy() -- Would fail if it ran
  end)
end)

-- Example of better error messages
--- A test suite demonstrating enhanced error messages from assertions, specifically table diffs.
--- This test *will* run in focus mode because of the `fit` and `fdescribe` above.
--- @within examples.focused_tests_example
describe("Enhanced error messages", function()
  --- This test is INTENTIONALLY designed to FAIL to demonstrate the detailed diff output
  -- provided by Firmo when comparing tables with `to.equal`.
  it("shows detailed table diffs on failure", function()
    local expected = {
      name = "example",
      values = { 1, 2, 3, 4 },
      nested = {
        key = "value",
        another = true,
      },
    }

    local actual = {
      name = "example",
      values = { 1, 2, 3, 5 }, -- Different value here (5 instead of 4)
      nested = {
        key = "wrong", -- Different value here
        extra = "field", -- Extra field here
      },
    }

    -- This assertion is INTENDED TO FAIL to demonstrate the detailed diff output.
    expect(actual).to.equal(expected)
  end)
end)

-- Log usage instructions and expected outcome
logger.info("\n-- Focused Tests Example --")
logger.info("Run this example using the standard test runner:")
logger.info("  lua firmo.lua examples/focused_tests_example.lua")
logger.info("\nExpected behavior:")
logger.info("- Only tests marked with 'fit' or inside 'fdescribe' blocks will run.")
logger.info("- Tests marked with 'xit' or inside 'xdescribe' blocks will be skipped.")
logger.info("- One test ('shows detailed diffs for tables') is designed to fail to show the diff output.")
logger.info("- Verification check: 'Excluded test ran' should be false => " .. tostring(not excluded_test_ran))
