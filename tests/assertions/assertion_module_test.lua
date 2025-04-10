-- Tests for the dedicated assertion module
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Explicitly require the standalone assertion module
local assertion = require("lib.assertion")
local test_helper = require("lib.tools.test_helper")

describe("Assertion Module", function()
  describe("Basic functionality", function()
    it("should export an expect function", function()
      expect(assertion.expect).to.be.a("function")
    end)

    it("should export utility functions", function()
      expect(assertion.eq).to.be.a("function")
      expect(assertion.isa).to.be.a("function")
    end)

    it("should export paths for extension", function()
      expect(assertion.paths).to.be.a("table")
      expect(assertion.paths.to).to.be.a("table")
      expect(assertion.paths.to_not).to.be.a("table")
    end)
  end)

  describe("expect() function", function()
    it("should return an assertion object", function()
      local result = assertion.expect(42)
      expect(result).to.be.a("table")
      expect(result.val).to.equal(42)
    end)

    it("should support chaining assertions", function()
      -- Test both positive and negative chains through actual assertions
      assertion.expect(42).to.equal(42) -- Verify 'to' chain works
      assertion.expect(42).to_not.equal(43) -- Verify 'to_not' chain works

      -- Verify multiple assertions in each chain
      assertion.expect("test").to.be.a("string").to.match("es")
      assertion.expect(5).to_not.equal(6).to_not.be.a("string")

      -- Verify chain switching
      local value = assertion.expect(true)
      value.to.be_truthy() -- Use 'to' chain
      value.to_not.be_falsy() -- Switch to 'to_not' chain
    end)
  end)

  describe("Basic assertions", function()
    it("should support equality assertions", { expect_error = true }, function()
      -- This assertion should pass
      assertion.expect(42).to.equal(42)

      -- This assertion should fail
      assertion.expect(42).to.equal(43)
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)

    it("should support type assertions for valid types", function()
      -- These assertions should pass
      assertion.expect(42).to.be.a("number")
      assertion.expect("test").to.be.a("string")
      assertion.expect({}).to.be.a("table")
    end)

    it("should fail for incorrect type assertions", { expect_error = true }, function()
      -- This assertion should fail with proper error message
      assertion.expect(42).to.be.a("string")
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)

    it("should support correct truthiness assertions", function()
      -- These assertions should pass
      assertion.expect(true).to.be_truthy()
      assertion.expect(1).to.be_truthy()
      assertion.expect("test").to.be_truthy()

      assertion.expect(false).to_not.be_truthy()
      assertion.expect(nil).to_not.be_truthy()
    end)

    it("should fail for incorrect truthiness assertions", { expect_error = true }, function()
      -- This assertion should fail with proper error message
      assertion.expect(false).to.be_truthy()
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)

    it("should support correct existence assertions", function()
      -- These assertions should pass
      assertion.expect(42).to.exist()
      assertion.expect("").to.exist()
      assertion.expect(false).to.exist()

      assertion.expect(nil).to_not.exist()
    end)

    it("should fail for incorrect existence assertions", { expect_error = true }, function()
      -- This assertion should fail with proper error message
      assertion.expect(nil).to.exist()
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)
  end)

  describe("Advanced assertions", function()
    it("should support correct matching assertions", function()
      -- These assertions should pass
      assertion.expect("hello world").to.match("world")
      assertion.expect("12345").to.match("%d+")
    end)

    it("should fail for incorrect matching assertions", { expect_error = true }, function()
      -- This assertion should fail with proper error message
      assertion.expect("hello").to.match("world")
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)

    it("should support correct table containment assertions", function()
      -- These assertions should pass
      assertion.expect({ 1, 2, 3 }).to.contain(2)

      -- Test table key existence with have
      local test_table = { a = 1, b = 2 }
      assertion.expect(test_table).to.have_property("a") -- Use have_property instead
    end)

    it("should fail for incorrect table containment assertions", { expect_error = true }, function()
      -- This assertion should fail with proper error message
      assertion.expect({ 1, 2, 3 }).to.contain(4)
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)

    it("should support correct numeric comparison assertions", function()
      -- These assertions should pass
      assertion.expect(5).to.be_greater_than(3)
      assertion.expect(3).to.be_less_than(5)
      assertion.expect(5).to.be_between(3, 7)
    end)

    it("should fail for incorrect numeric comparison assertions", { expect_error = true }, function()
      -- This assertion should fail with proper error message
      assertion.expect(3).to.be_greater_than(5)
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)
  end)

  describe("Error handling", function()
    it("should properly handle errors in test functions", { expect_error = true }, function()
      -- This should be caught and reported properly by expect_error
      assertion.expect("not a table").to.have.key("foo")
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)

    it("should handle errors in custom predicates", function()
      -- Use test_helper to capture the intentional error
      local test_fn = test_helper.with_error_capture(function()
        assertion.expect(5).to.satisfy(function(v)
          error("Intentional error")
        end)
      end)

      -- Execute and verify the error was captured properly
      local success, err = test_fn()

      -- Verify the error handling
      expect(success).to.be_falsy("Predicate should have failed")
      expect(err).to.exist("Error should be captured")
      expect(err.message).to.match("Intentional error", "Error should contain the expected message")
    end)
  end)

  describe("Negation support", function()
    it("should support correct negated assertions with to_not", function()
      -- These assertions should pass
      assertion.expect(42).to_not.equal(43)
      assertion.expect("test").to_not.be.a("number")
      assertion.expect(false).to_not.be_truthy()
    end)

    it("should fail for incorrect negated assertions", { expect_error = true }, function()
      -- This assertion should fail with proper error message
      assertion.expect(42).to_not.equal(42)
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)
  end)

  describe("Table comparisons", function()
    it("should support correct deep equality assertions", function()
      -- These assertions should pass
      assertion.expect({ 1, 2, 3 }).to.equal({ 1, 2, 3 })
      assertion.expect({ a = 1, b = { c = 2 } }).to.equal({ a = 1, b = { c = 2 } })
    end)

    it("should fail for incorrect deep equality assertions", { expect_error = true }, function()
      -- This assertion should fail with proper error message
      assertion.expect({ 1, 2, 3 }).to.equal({ 1, 2, 4 })
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)

    it("should provide detailed diffs for table differences", { expect_error = true }, function()
      -- This should provide a detailed diff
      assertion.expect({ a = 1, b = 2 }).to.equal({ a = 1, b = 3 })
      -- The test should never reach here due to the above assertion failing
      -- The { expect_error = true } option will handle the assertion error properly
    end)
  end)
end)
