---@diagnostic disable: missing-parameter, param-type-mismatch
--- Assertion Module Integration Test
---
--- Verifies that the standalone assertion module (`lib.assertion`) provides
--- an API and behavior identical to the built-in `firmo.expect` system.
--- Checks both successful assertions and error handling for consistency.
---
--- @author Firmo Team
--- @test

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Explicitly require the standalone assertion module
local assertion = require("lib.assertion")

describe("Assertion Module Integration", function()
  describe("API Compatibility", function()
    it("should have the same behavior as firmo expect", function()
      -- Set up test values
      local num = 42
      local str = "test"
      local tbl = { 1, 2, 3 }

      -- Test basic assertions with both modules
      -- Equality
      expect(num).to.equal(42)
      assertion.expect(num).to.equal(42)

      -- Type assertions
      expect(num).to.be.a("number")
      assertion.expect(num).to.be.a("number")

      expect(str).to.be.a("string")
      assertion.expect(str).to.be.a("string")

      expect(tbl).to.be.a("table")
      assertion.expect(tbl).to.be.a("table")

      -- Truthiness
      expect(num).to.be_truthy()
      assertion.expect(num).to.be_truthy()

      expect(false).to_not.be_truthy()
      assertion.expect(false).to_not.be_truthy()

      -- Existence
      expect(num).to.exist()
      assertion.expect(num).to.exist()

      expect(nil).to_not.exist()
      assertion.expect(nil).to_not.exist()

      -- Pattern matching
      expect(str).to.match("te")
      assertion.expect(str).to.match("te")

      -- Table containment
      expect(tbl).to.contain(2)
      assertion.expect(tbl).to.contain(2)

      -- Numeric comparisons
      expect(num).to.be_greater_than(10)
      assertion.expect(num).to.be_greater_than(10)

      expect(num).to.be_less_than(100)
      assertion.expect(num).to.be_less_than(100)

      -- If we get here without errors, both implementations behave the same way
      expect(true).to.be_truthy() -- Just to have an explicit assertion
    end)

    it("should handle error cases in the same way", { expect_error = true }, function()
      local test_helper = require("lib.tools.test_helper")

      -- Capture firmo error
      local firmo_fn = test_helper.with_error_capture(function()
        expect(5).to.equal(6)
      end)
      local _, firmo_error = firmo_fn()

      -- Capture assertion module error
      local assertion_fn = test_helper.with_error_capture(function()
        assertion.expect(5).to.equal(6)
      end)
      local _, assertion_error = assertion_fn()

      -- Verify errors are captured
      expect(firmo_error).to.exist("Firmo assertion should generate error")
      expect(assertion_error).to.exist("Standalone assertion should generate error")

      -- Verify error messages
      expect(firmo_error.message).to.exist("Firmo error should have message")
      expect(assertion_error.message).to.exist("Assertion error should have message")

      -- Verify error messages indicate the same issue
      expect(firmo_error.message).to.match("not equal", "Firmo error should indicate values not equal")
      expect(assertion_error.message).to.match("not equal", "Assertion error should indicate values not equal")

      -- Compare error structures
      expect(type(firmo_error)).to.equal(type(assertion_error), "Error types should match")
      expect(type(firmo_error.message)).to.equal(type(assertion_error.message), "Error message types should match")
    end)
  end)
end)
