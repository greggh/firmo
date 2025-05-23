---@diagnostic disable: missing-parameter, param-type-mismatch
--- Comprehensive Expect Assertion Tests
---
--- Provides thorough tests for Firmo's `expect` assertion system, covering:
--- - Basic assertions (equality, existence, truthiness, falsiness)
--- - Negative assertions (`to_not`)
--- - Function assertions (`to.fail`, `to_not.fail`, `to.fail.with`)
--- - Table assertions (`to.have`, `to_not.have`)
--- - Additional assertions (`to.match`, `to.be.a`)
--- - Assertion error messages
--- - Integration with `test_helper.expect_error`
--- - Internal state reset (`test_definition.reset`)
--- - Uses optional logging for debugging.
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

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")

-- Try to load the logging module
local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.expect_assertions")

describe("Expect Assertion System", function()
  if logger then
    logger.info("Beginning expect assertion system tests", {
      test_group = "expect",
      total_describe_blocks = 6,
      test_coverage = "comprehensive",
    })
  end

  describe("Basic Assertions", function()
    if log then
      logger.debug("Testing basic assertions")
    end

    it("checks for equality", function()
      expect(5).to.equal(5)
      expect("hello").to.equal("hello")
      expect(true).to.equal(true)
      expect({ a = 1, b = 2 }).to.equal({ a = 1, b = 2 })
    end)

    it("compares values with equality", function()
      expect(5).to.equal(5)
      expect("hello").to.equal("hello")
      expect(true).to.equal(true)
    end)

    it("checks for existence", function()
      expect(5).to.exist()
      expect("hello").to.exist()
      expect(true).to.exist()
      expect({}).to.exist()
    end)

    it("checks for truthiness", function()
      expect(5).to.be.truthy()
      expect("hello").to.be.truthy()
      expect(true).to.be.truthy()
      expect({}).to.be.truthy()
    end)

    it("checks for falsiness", function()
      expect(nil).to.be.falsey()
      expect(false).to.be.falsey()
    end)

    it("fails when values are not equal", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        expect(5).to.equal(6)
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("expected.*to equal")
    end)

    it("fails when checking existence of nil", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        expect(nil).to.exist()
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("expected.*to exist")
    end)
  end)

  describe("Negative Assertions", function()
    if log then
      logger.debug("Testing negative assertions")
    end

    it("checks for inequality", function()
      expect(5).to_not.equal(6)
      expect("hello").to_not.equal("world")
      expect(true).to_not.equal(false)
      expect({ a = 1 }).to_not.equal({ a = 2 })
    end)

    it("compares values with to_not.equal", function()
      expect(5).to_not.equal(6)
      expect("hello").to_not.equal("world")
      expect(true).to_not.equal(false)
    end)

    it("checks for non-existence", function()
      expect(nil).to_not.exist()
      expect(false).to.exist() -- false exists, it's not nil
    end)

    it("checks for non-truthiness", function()
      expect(nil).to_not.be.truthy()
      expect(false).to_not.be.truthy()
    end)

    it("checks for non-falsiness", function()
      expect(5).to_not.be.falsey()
      expect("hello").to_not.be.falsey()
      expect(true).to_not.be.falsey()
      expect({}).to_not.be.falsey()
    end)
  end)

  describe("Function Testing", function()
    if log then
      logger.debug("Testing function assertions")
    end

    it("checks for function failure", { expect_error = true }, function()
      local function fails()
        error("This function fails")
      end
      expect(fails).to.fail()
    end)

    it("checks for function success", function()
      local function succeeds()
        return true
      end
      expect(succeeds).to_not.fail()
    end)

    it("checks for error message", { expect_error = true }, function()
      local function fails_with_message()
        error("Expected message")
      end
      expect(fails_with_message).to.fail.with("Expected message")
    end)

    it("can use test_helper for error checking", { expect_error = true }, function()
      local function fails_with_custom_message()
        error("Custom error message")
      end

      -- Verify the function throws with a specific message
      local err = test_helper.expect_error(fails_with_custom_message, "Custom error message")

      expect(err).to.exist()
      expect(err.message).to.match("Custom error message")
    end)
  end)

  describe("Table Assertions", function()
    if log then
      logger.debug("Testing table assertions")
    end

    it("checks for value in table", function()
      local t = { 1, 2, 3, "hello" }
      expect(t).to.have(1)
      expect(t).to.have(2)
      expect(t).to.have("hello")
    end)

    it("checks for absence of value in table", function()
      local t = { 1, 2, 3 }
      expect(t).to_not.have(4)
      expect(t).to_not.have("hello")
    end)
  end)

  describe("Additional Assertions", function()
    if log then
      logger.debug("Testing additional assertions")
    end

    it("checks string matching", function()
      expect("hello world").to.match("world")
      expect("hello world").to_not.match("universe")
    end)

    it("checks for type", function()
      expect(5).to.be.a("number")
      expect("hello").to.be.a("string")
      expect(true).to.be.a("boolean")
      expect({}).to.be.a("table")
      expect(function() end).to.be.a("function")
    end)

    it("fails when string does not match pattern", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        expect("hello world").to.match("universe")
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("expected.*to match")
    end)

    it("fails when type does not match", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        expect(5).to.be.a("string")
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("expected.*to be a")
    end)
  end)
  describe("Reset Function", function()
    if log then
      logger.debug("Testing reset functionality")
    end

    local test_definition = require("lib.core.test_definition")

    it("has important API functions", function()
      expect(type(firmo.reset)).to.equal("function")
      expect(type(firmo.describe)).to.equal("function")
      expect(type(firmo.it)).to.equal("function")
      expect(type(firmo.expect)).to.equal("function")
    end)

    it("properly handles reset", function()
      -- Get initial state
      local initial_state = test_definition.get_state()
      local initial_passes = initial_state.passes

      -- Add a test result to create some state
      test_definition.add_test_result({
        status = test_definition.STATUS.PASS,
        name = "test pass",
        timestamp = os.time(),
      })

      -- Verify state changed
      local mid_state = test_definition.get_state()
      expect(mid_state.passes).to.be_greater_than(initial_passes)

      -- Reset state
      test_definition.reset()

      -- Verify state is cleared
      local final_state = test_definition.get_state()
      expect(final_state.passes).to.equal(0)
      expect(final_state.errors).to.equal(0)
      expect(final_state.skipped).to.equal(0)
    end)
  end)

  if log then
    logger.info("Expect assertion system tests completed", {
      status = "success",
      test_group = "expect",
    })
  end
end)
