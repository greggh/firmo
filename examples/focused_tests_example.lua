--- focused_tests_example.lua
--
-- This example demonstrates Firmo's focus (`fit`, `fdescribe`) and exclude
-- (`xit`, `xdescribe`) features, which allow developers to selectively run
-- or skip specific tests or test suites.
--
-- It also includes a test designed to fail with a table comparison to show
-- the enhanced diff output provided by Firmo's assertion library.
--
-- Run embedded tests: lua test.lua examples/focused_tests_example.lua
--

local error_handler = require("lib.tools.error_handler")
local firmo = require("firmo")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("FocusedExample")

-- Extract the functions we need
local describe = firmo.describe
local fdescribe = firmo.fdescribe
local xdescribe = firmo.xdescribe
local it = firmo.it
local fit = firmo.fit
local xit = firmo.xit
local expect = firmo.expect

-- Create a counter to verify excluded tests don't run (still useful for demonstration)
local excluded_test_ran = false

-- Standard describe block
--- A standard test suite containing a mix of normal, focused, and excluded tests.
describe("Standard tests", function()
  it("runs normally", function()
    expect(1 + 1).to.equal(2)
  end)

  it("also runs normally", function()
    expect("test").to.be.a("string")
  end)

  -- Focused test - only this will run if we're in focus mode
  fit("is focused and will always run", function()
    expect(true).to.be.truthy()
  end)

  -- Excluded test - this will be skipped
  xit("is excluded and will not run", function()
    excluded_test_ran = true
    expect(false).to.be.truthy() -- This would fail if it ran
  end)
end)

-- Focused describe block - all tests inside will run even in focus mode
--- A focused test suite (`fdescribe`). All tests within this block will run
-- when focus mode is active (i.e., if any `fit` or `fdescribe` exists).
fdescribe("Focused test group", function()
  it("will run because parent is focused", function()
    expect({ 1, 2, 3 }).to.contain(2)
  end)

  it("also runs because parent is focused", function()
    expect("hello").to.match("he..o")
  end)

  -- Excluded test still doesn't run even in focused parent
  xit("is excluded despite focused parent", function()
    expect(nil).to.exist() -- Would fail if it ran
  end)
end)

-- Excluded describe block - none of these tests will run
--- An excluded test suite (`xdescribe`). No tests within this block will run,
-- regardless of focus mode or individual test focus (`fit`).
xdescribe("Excluded test group", function()
  it("will not run because parent is excluded", function()
    expect(1).to.be(2) -- Would fail if it ran
  end)

  fit("focused but parent is excluded so still won't run", function()
    expect(false).to.be.truthy() -- Would fail if it ran
  end)
end)

-- Example of better error messages
--- A test suite demonstrating enhanced error messages, specifically table diffs.
describe("Enhanced error messages", function()
  it("shows detailed diffs for tables", function()
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
logger.info("  lua test.lua examples/focused_tests_example.lua")
logger.info("\nExpected behavior:")
logger.info("- Only tests marked with 'fit' or inside 'fdescribe' blocks will run.")
logger.info("- Tests marked with 'xit' or inside 'xdescribe' blocks will be skipped.")
logger.info("- One test ('shows detailed diffs for tables') is designed to fail to show the diff output.")
logger.info("- Verification check: 'Excluded test ran' should be false => " .. tostring(not excluded_test_ran))
