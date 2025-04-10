-- Comprehensive tests for the expect assertion system

local firmo = require('firmo')
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")

-- Try to load the logging module
local logging, logger
local function try_load_logger()
  if not logger then
    local log_module, err = test_helper.with_error_capture(function()
      return require("lib.tools.logging")
    end)()
    
    if log_module then
      logging = log_module
      logger = logging.get_logger("test.expect_assertions")
      
      if logger and logger.debug then
        logger.debug("Expect assertions test initialized", {
          module = "test.expect_assertions",
          test_type = "unit",
          assertion_focus = "expect API"
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

describe('Expect Assertion System', function()
  if log then
    log.info("Beginning expect assertion system tests", {
      test_group = "expect",
      total_describe_blocks = 6,
      test_coverage = "comprehensive"
    })
  end
  
  describe('Basic Assertions', function()
    if log then log.debug("Testing basic assertions") end
    
    it('checks for equality', function()
      expect(5).to.equal(5)
      expect("hello").to.equal("hello")
      expect(true).to.equal(true)
      expect({a = 1, b = 2}).to.equal({a = 1, b = 2})
    end)
    
    it('compares values with equality', function()
      expect(5).to.equal(5)
      expect("hello").to.equal("hello")
      expect(true).to.equal(true)
    end)
    
    it('checks for existence', function()
      expect(5).to.exist()
      expect("hello").to.exist()
      expect(true).to.exist()
      expect({}).to.exist()
    end)
    
    it('checks for truthiness', function()
      expect(5).to.be.truthy()
      expect("hello").to.be.truthy()
      expect(true).to.be.truthy()
      expect({}).to.be.truthy()
    end)
    
    it('checks for falsiness', function()
      expect(nil).to.be.falsey()
      expect(false).to.be.falsey()
    end)
    
    it('fails when values are not equal', { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        expect(5).to.equal(6)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("expected.*to equal")
    end)

    it('fails when checking existence of nil', { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        expect(nil).to.exist()
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("expected.*to exist")
    end)
  end)
  
  describe('Negative Assertions', function()
    if log then log.debug("Testing negative assertions") end
    
    it('checks for inequality', function()
      expect(5).to_not.equal(6)
      expect("hello").to_not.equal("world")
      expect(true).to_not.equal(false)
      expect({a = 1}).to_not.equal({a = 2})
    end)
    
    it('compares values with to_not.equal', function()
      expect(5).to_not.equal(6)
      expect("hello").to_not.equal("world")
      expect(true).to_not.equal(false)
    end)
    
    it('checks for non-existence', function()
      expect(nil).to_not.exist()
      expect(false).to.exist() -- false exists, it's not nil
    end)
    
    it('checks for non-truthiness', function()
      expect(nil).to_not.be.truthy()
      expect(false).to_not.be.truthy()
    end)
    
    it('checks for non-falsiness', function()
      expect(5).to_not.be.falsey()
      expect("hello").to_not.be.falsey()
      expect(true).to_not.be.falsey()
      expect({}).to_not.be.falsey()
    end)
  end)
  
  describe('Function Testing', function()
    if log then log.debug("Testing function assertions") end
    
    it('checks for function failure', { expect_error = true }, function()
      local function fails() error("This function fails") end
      expect(fails).to.fail()
    end)
    
    it('checks for function success', function()
      local function succeeds() return true end
      expect(succeeds).to_not.fail()
    end)
    
    it('checks for error message', { expect_error = true }, function()
      local function fails_with_message() error("Expected message") end
      expect(fails_with_message).to.fail.with("Expected message")
    end)
    
    it('can use test_helper for error checking', { expect_error = true }, function()
      local function fails_with_custom_message() error("Custom error message") end
      
      -- Verify the function throws with a specific message
      local err = test_helper.expect_error(
        fails_with_custom_message,
        "Custom error message"
      )
      
      expect(err).to.exist()
      expect(err.message).to.match("Custom error message")
    end)
  end)
  
  describe('Table Assertions', function()
    if log then log.debug("Testing table assertions") end
    
    it('checks for value in table', function()
      local t = {1, 2, 3, "hello"}
      expect(t).to.have(1)
      expect(t).to.have(2)
      expect(t).to.have("hello")
    end)
    
    it('checks for absence of value in table', function()
      local t = {1, 2, 3}
      expect(t).to_not.have(4)
      expect(t).to_not.have("hello")
    end)
  end)
  
  describe('Additional Assertions', function()
    if log then log.debug("Testing additional assertions") end
    
    it('checks string matching', function()
      expect("hello world").to.match("world")
      expect("hello world").to_not.match("universe")
    end)
    
    it('checks for type', function()
      expect(5).to.be.a("number")
      expect("hello").to.be.a("string")
      expect(true).to.be.a("boolean")
      expect({}).to.be.a("table")
      expect(function() end).to.be.a("function")
    end)
    
    it('fails when string does not match pattern', { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        expect("hello world").to.match("universe")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("expected.*to match")
    end)

    it('fails when type does not match', { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        expect(5).to.be.a("string")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("expected.*to be a")
    end)
  end)
  describe('Reset Function', function()
    if log then log.debug("Testing reset functionality") end
    
    it('allows chaining syntax', function()
      -- Create a local function to avoid affecting main tests
      local function test_reset_chaining()
        -- If we get to here without errors, it means reset() supports chaining
        -- since reset() is called in the chain below
        firmo.reset().describe('test', function() end)
        return true
      end
      
      -- If test_reset_chaining succeeds, this will pass
      expect(test_reset_chaining()).to.be.truthy()
    end)
    
    it('has important API functions', function()
      -- Just check that the main API functions exist and are proper types
      expect(type(firmo.reset)).to.equal("function")
      expect(type(firmo.describe)).to.equal("function")
      expect(type(firmo.it)).to.equal("function")
      expect(type(firmo.expect)).to.equal("function")
    end)
  end)
  
  if log then
    log.info("Expect assertion system tests completed", {
      status = "success",
      test_group = "expect"
    })
  end
end)

-- Tests are run by run_all_tests.lua or scripts/runner.lua
-- No need to call firmo() explicitly here
