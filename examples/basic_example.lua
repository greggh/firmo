--- basic_example.lua
--
-- This file demonstrates the fundamental structure and usage patterns of the
-- Firmo testing framework. It covers:
-- - Basic BDD syntax (`describe`, `it`).
-- - Setup and teardown hooks (`before`, `after`).
-- - Making assertions using `expect`.
-- - Nested test suites.
-- - Basic error testing patterns using `test_helper` and `error_handler`.
--
-- Run with: lua test.lua examples/basic_example.lua
--

-- Import the firmo framework
local firmo = require("firmo")

-- Extract testing functions (preferred way to import)
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Optional: Import error handling utilities for testing errors
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

local logger = logging.get_logger("BasicExample")

-- A simple calculator module to test
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b)
    if b == 0 then 
      return nil, error_handler.validation_error(
        "Cannot divide by zero", 
        {parameter = "b", provided_value = b}
      )
    end
    return a / b
  end
}

-- Test suite using nested describe blocks
--- Defines the main test suite for the simple calculator module.
describe("Calculator", function()
  -- Setup that runs before each test
  before(function()
    -- Use structured logging
    logger.info("Setting up test for calculator", { module = "calculator" })
  end)
  
  -- Cleanup that runs after each test
  after(function()
    logger.info("Cleaning up test for calculator", { module = "calculator" })
  end)
  describe("Basic Operations", function()
    --- Tests for the addition functionality.
    describe("addition", function()
      it("adds two positive numbers", function()
        expect(calculator.add(2, 3)).to.equal(5)
      end)
      
      it("adds a positive and a negative number", function()
        expect(calculator.add(2, -3)).to.equal(-1)
      end)
    end)
    
    --- Tests for the subtraction functionality.
    describe("subtraction", function()
      it("subtracts two numbers", function()
        expect(calculator.subtract(5, 3)).to.equal(2)
      end)
    end)
    
    --- Tests for the multiplication functionality.
    describe("multiplication", function()
      it("multiplies two numbers", function()
        expect(calculator.multiply(2, 3)).to.equal(6)
      end)
    end)
  end)
  
  --- Groups tests related to more complex operations or error handling.
  describe("Advanced Operations", function()
    --- Tests for the division functionality, including error handling.
    describe("division", function()
      it("divides two numbers", function()
        expect(calculator.divide(6, 3)).to.equal(2)
      end)
      
      -- Example of proper error testing using expect_error flag
      it("handles division by zero", { expect_error = true }, function()
        -- Use with_error_capture to safely call functions that may return errors
        local result, err = test_helper.with_error_capture(function()
          return calculator.divide(5, 0)
        end)()
        
        -- Make assertions about the error
        expect(result).to_not.exist()
        expect(err).to.exist()
        expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
        expect(err.message).to.match("divide by zero")
      end)
    end)
  end)
end)

-- NOTE: Run this example using the standard test runner:
-- lua test.lua examples/basic_example.lua
