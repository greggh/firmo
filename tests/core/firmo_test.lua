---@diagnostic disable: missing-parameter, param-type-mismatch
--- Firmo Core API Tests
---
--- Verifies the presence and basic functionality of core Firmo API functions
--- (`describe`, `it`, `expect`, `spy`). Includes tests for graceful handling
--- of non-existent functions and simple assertion passes. Also includes tests
--- for basic spy creation, usage, and error handling.
---
--- @author Firmo Team
--- @test
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
---@diagnostic disable-next-line: unused-local
local before, after = firmo.before, firmo.after



-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")

-- Try to load the logging module
local logging = require("lib.tools.logging")
-- Initialize logger
local logger = logging.get_logger("firmo_test")

describe("firmo", function()
  logger.info("Beginning firmo core tests", {
    test_group = "firmo_core",
    test_focus = "API functions",
  })

  it("has required functions", function()
    expect(firmo.describe).to.be.a("function")
    expect(firmo.it).to.be.a("function")
    expect(firmo.expect).to.be.a("function")
    expect(firmo.spy).to.exist()
  end)

  it("gracefully handles access to non-existent functions", { expect_error = true }, function()
    logger.debug("Testing access to non-existent functions")

    local err = test_helper.expect_error(function()
      -- This should fail gracefully and not cause a hard crash
      expect(firmo.non_existent_function).to.be.a("function")
    end)

    expect(err).to.exist()
    expect(err.message).to.match("expected.*to be a function")
  end)

  it("passes simple tests", function()
    logger.debug("Testing basic assertions")
    expect(1).to.equal(1)
    expect("hello").to.equal("hello")
    expect({ 1, 2 }).to.equal({ 1, 2 })
  end)

  it("has spy functionality", function()
    logger.debug("Testing spy functionality")
    -- Test the spy functionality which is now implemented
    expect(firmo.spy).to.exist()
    -- The spy is a module with new and on functions
    expect(firmo.spy.new).to.be.a("function")
    expect(firmo.spy.on).to.be.a("function")

    -- Test basic spy functionality with proper error handling
    local test_fn = function(a, b)
      return a + b
    end

    -- Create spy with proper error handling
    local spied, spy_err = test_helper.with_error_capture(function()
      return firmo.spy.new(test_fn)
    end)()

    expect(spy_err).to_not.exist("Creating a spy should not produce errors")
    expect(spied).to.exist()

    -- Spy should work like the original function
    local result, call_err = test_helper.with_error_capture(function()
      return spied(2, 3)
    end)()

    expect(call_err).to_not.exist("Calling a spy should not produce errors")
    expect(result).to.equal(5)

    -- Spy should track calls
    expect(spied.calls).to.be.a("table")
    expect(#spied.calls).to.equal(1)
    expect(spied.calls[1][1]).to.equal(2)
    expect(spied.calls[1][2]).to.equal(3)
    expect(spied.call_count).to.equal(1)
  end)

  it("handles spy errors gracefully", { expect_error = true }, function()
    logger.debug("Testing spy error handling")

    -- Test spying on nil
    local err1 = test_helper.expect_error(function()
      return firmo.spy.new(nil)
    end)

    expect(err1).to.exist()
    expect(err1.message).to.match("Cannot spy on nil")

    -- Test spying on non-function
    local err2 = test_helper.expect_error(function()
      return firmo.spy.new("not a function")
    end)

    expect(err2).to.exist()
    expect(err2.message).to.match("Cannot spy on non-function")

    -- Test spy.on with non-table
    local err3 = test_helper.expect_error(function()
      return firmo.spy.on("not a table", "method")
    end)

    expect(err3).to.exist()
    expect(err3.message).to.match("first argument must be a table")

    -- Test spy.on with non-existent method
    local obj = {
      method = function()
        return true
      end,
    }
    local err4 = test_helper.expect_error(function()
      return firmo.spy.on(obj, "non_existent_method")
    end)

    expect(err4).to.exist()
    expect(err4.message).to.match("Method.*does not exist")

    -- Test spy.on with success
    local spy_result, spy_err = test_helper.with_error_capture(function()
      return firmo.spy.on(obj, "method")
    end)()

    expect(spy_err).to_not.exist("Spying on a valid method should not produce errors")
    expect(spy_result).to.exist()

    -- Test the spy tracks calls
    local call_result = obj.method()
    expect(call_result).to.equal(true)
    expect(obj.method.call_count).to.equal(1)
  end)

  logger.info("Firmo core tests completed", {
    status = "success",
    test_group = "firmo_core",
  })
end)
