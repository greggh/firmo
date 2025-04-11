-- Debug test file for structured test results

local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

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
