---@diagnostic disable: missing-parameter, param-type-mismatch
--- Debug Test for Structured Results
---
--- Contains various test cases (pass, fail, expected error, skipped) to help debug
--- the structured test result collection and reporting within Firmo's
--- `test_definition` module. Includes an `after` hook to print final state.
---
--- @author Firmo Team
--- @test

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after

local test_helper = require("lib.tools.test_helper")

describe("Structured Results Debug", function()
  it("should pass normally", function()
    expect(1).to.equal(1)
  end)

  it("should fail", { expect_error = true }, function()
    expect(1).to.equal(2) -- This should fail
  end)

  it("should handle expected errors", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      error("This is an expected error")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
  end)

  it("should be skipped", { excluded = true }, function()
    expect(true).to.be_truthy()
  end)

  -- Print out test_definition state
  after(function()
    local test_definition = require("lib.core.test_definition")
    if test_definition and test_definition.get_state then
      local state = test_definition.get_state()
      print("\nTEST DEFINITION STATE:")
      print(string.format("  Results count: %d", #state.test_results))
      print(string.format("  Passes: %d", state.passes))
      print(string.format("  Errors: %d", state.errors))
      print(string.format("  Skipped: %d", state.skipped))
    end
  end)
end)
