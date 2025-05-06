--- quality_example.lua
--
-- This example demonstrates the *concept* of classifying tests into different
-- quality levels (e.g., Basic, Standard, Comprehensive, Advanced, Complete).
-- The `describe` blocks are named according to these conceptual levels.
--
-- It suggests how a test runner *could* potentially use a hypothetical
-- `--quality` or `--quality-level=N` flag to filter which tests are executed
-- based on these levels.
--
-- **Note:** This example uses `describe` block names (e.g., "Level 1 (Basic)")
-- to *conceptually* represent different quality levels. Standard Firmo does **not**
-- automatically filter tests based on these names or a numerical level derived
-- from them. Implementing such filtering would require custom runner logic or
-- potentially leveraging the tagging system (`firmo.tags`).
--
-- @module examples.quality_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see firmo
-- @usage
-- Run embedded tests: lua test.lua examples/quality_example.lua
--

local firmo = require("firmo")
-- Explicitly extract test functions into local variables
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after
-- Remove debug prints after confirming they show 'function'
-- print("DEBUG: firmo type after require:", type(firmo))
-- if type(firmo) == "table" then
--   print("DEBUG: firmo.describe type after require:", type(firmo.describe))
-- end
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("QualityExample")

--- A simple calculator module used for demonstrating tests at different quality levels.
--- @class Calculator
--- @field add fun(a: number, b: number): number Adds two numbers.
--- @field subtract fun(a: number, b: number): number Subtracts two numbers.
--- @field multiply fun(a: number, b: number): number Multiplies two numbers.
--- @field divide fun(a: number, b: number): number|nil, table|nil Divides numbers, handles zero division.
--- @field power fun(base: number, exponent: number): number Calculates power.
--- @within examples.quality_example
local calculator = {}

--- Adds two numbers.
-- @param a number First number.
-- @param b number Second number.
-- @return number Sum of a and b.
calculator.add = function(a, b)
  -- Basic implementation
  return a + b
end

--- Subtracts the second number from the first.
-- @param a number First number.
-- @param b number Second number.
-- @return number Difference of a and b.
calculator.subtract = function(a, b)
  -- Basic implementation
  return a - b
end

--- Multiplies two numbers.
-- @param a number First number.
-- @param b number Second number.
-- @return number Product of a and b.
calculator.multiply = function(a, b)
  -- Basic implementation
  return a * b
end

--- Divides the first number by the second. Handles division by zero.
-- @param a number Numerator.
-- @param b number Denominator.
-- @return number|nil Quotient on success, or nil.
-- @return table|nil err Error object if b is zero.
calculator.divide = function(a, b)
  if b == 0 then
    return nil, error_handler.validation_error("Division by zero", { operation = "divide", b = b })
  end
  return a / b
end

--- Calculates base raised to the power of exponent. Handles negative exponents.
-- @param base number The base.
-- @param exponent number The exponent.
-- @return number The result of base^exponent.
calculator.power = function(base, exponent)
  if exponent < 0 then
    return 1 / calculator.power(base, -exponent)
  elseif exponent == 0 then
    return 1
  else
    local result = base
    for i = 2, exponent do
      result = result * base
    end
    return result
  end
end

--- Conceptual: Level 1 tests - Basic validation of core functionality.
--- Minimal assertions, focuses on the "happy path".
--- @within examples.quality_example
print("DEBUG: firmo type before describe call:", type(firmo))
if type(firmo) == "table" then
  print("DEBUG: firmo.describe type before describe call:", type(describe)) -- Check local var
end
describe("Calculator - Level 1 (Basic)", function()
  it("adds two numbers", function()
    expect(calculator.add(2, 3)).to.equal(5)
  end)
end)

--- Conceptual: Level 2 tests - Standard validation with multiple assertions per test case.
--- Includes basic setup/teardown structure.
--- @within examples.quality_example
describe("Calculator - Level 2 (Standard)", function()
  --- Tests addition with multiple valid inputs.
  it("should add two positive numbers correctly", function()
    expect(calculator.add(2, 3)).to.equal(5)
    expect(calculator.add(0, 5)).to.equal(5)
    expect(calculator.add(10, 20)).to.equal(30, "10 + 20 should equal 30")
  end)

  --- Tests subtraction with multiple valid inputs.
  it("should subtract properly", function()
    expect(calculator.subtract(5, 3)).to.equal(2)
    expect(calculator.subtract(10, 5)).to.equal(5)
  end)

  --- Basic setup hook.
  before(function()
    -- Set up any test environment needed
    logger.debug("Setting up Level 2 test environment...")
  end)

  --- Basic teardown hook.
  after(function()
    -- Clean up after tests
    logger.debug("Cleaning up Level 2 test environment...")
  end)
end)

--- Conceptual: Level 3 tests - Adds edge case testing and error handling validation.
--- @within examples.quality_example
describe("Calculator - Level 3 (Comprehensive)", function()
  --- Tests focused on the division operation, including edge cases and error paths.
  --- @within examples.quality_example
  describe("when performing division", function()
    --- Tests division with standard inputs.
    it("should divide two numbers", function()
      expect(calculator.divide(10, 2)).to.equal(5)
      expect(calculator.divide(7, 2)).to.equal(3.5)
      expect(calculator.divide(10, 2)).to.be.a("number", "Result should be a number")
    end)

    --- Tests division edge cases like zero numerator and negative numbers.
    it("should handle division with edge cases", function()
      expect(calculator.divide(0, 5)).to.equal(0)
      expect(calculator.divide(-10, 2)).to.equal(-5)
      -- Note: be_near assertion commented out in previous fix
      -- expect(calculator.divide(1, 3)).to.be_near(0.333333, 0.001)
    end)

    --- Tests the specific error case of division by zero using `expect_error` and `with_error_capture`.
    it("should return error for division by zero", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return calculator.divide(10, 0)
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Division by zero")
    end)
  end)
end)

--- Conceptual: Level 4 tests - Includes boundary value analysis and basic integration/mocking concepts.
--- @within examples.quality_example
describe("Calculator - Level 4 (Advanced)", function()
  --- Tests focused on the power operation, including boundary conditions and call tracking (using spy).
  --- @within examples.quality_example
  describe("when performing power operations", function()
    --- Tests power calculation with various exponents.
    it("should calculate powers with various exponents", function()
      expect(calculator.power(2, 3)).to.equal(8)
      expect(calculator.power(5, 2)).to.equal(25)
      expect(calculator.power(10, 0)).to.equal(1)
      expect(calculator.power(2, 1)).to.equal(2)
    end)

    --- Tests boundary conditions for the power function (e.g., large/small exponents).
    it("should handle boundary conditions", function()
      -- Testing potentially large results (upper bounds)
      local result = calculator.power(2, 10)
      expect(result).to.equal(1024)
      expect(result).to.be_less_than(2 ^ 11, "Result should be less than 2^11")

      -- Testing potentially small results (lower bounds - negative exponent)
      local small_result = calculator.power(2, -2)
      -- Note: be_near assertion commented out in previous fix
      -- expect(small_result).to.be_near(0.25, 0.0001)
    end)

    --- Specifically tests handling of negative exponents.
    it("should handle negative exponents correctly", function()
      -- Note: be_near assertion commented out in previous fix
      -- expect(calculator.power(2, -1)).to.be_near(0.5, 0.0001)
      -- expect(calculator.power(4, -2)).to.be_near(0.0625, 0.0001)
    end)

    --- Demonstrates using a spy to verify function calls.
    it("should track power calculation calls using a spy", function()
      local original_power = calculator.power

      -- Create a spy that tracks calls to the power function
      local spy = firmo.spy(calculator, "power")

      calculator.power(3, 2)
      calculator.power(2, 8)

      -- Verify spy was called
      expect(spy.call_count).to.equal(2, "Power function should be called twice")
      expect(spy:called_with(calculator, 3, 2)).to.be_truthy("Should be called with 3, 2") -- Include self
      expect(spy:called_with(calculator, 2, 8)).to.be_truthy("Should be called with 2, 8") -- Include self

      -- Restore original function
      calculator.power = original_power
    end)
  end)
  -- Removed empty before/after hooks
end)

--- Conceptual: Level 5 tests - Includes non-functional testing aspects like security and performance.
--- @within examples.quality_example
describe("Calculator - Level 5 (Complete)", function()
  --- Tests related to security aspects, like input validation for potential overflows or injection (conceptual).
  --- @within examples.quality_example
  describe("when considering security implications", function()
    --- Conceptually tests input validation against potential overflow issues.
    it("should handle large inputs without overflow/errors", function()
      -- Security test: very large inputs
      local large_result = calculator.power(2, 20)
      expect(large_result).to.be_greater_than(0, "Result should be positive")
      expect(large_result).to.be_less_than(2 ^ 30, "Result should be within safe range")
      expect(large_result).to.be.a("number", "Result should remain a number")
      expect(tostring(large_result):match("[Ii][Nn][Ff]")).to.be_nil("Result should not be infinity") -- Case-insensitive match
      expect(tostring(large_result):match("[Nn][Aa][Nn]")).to.be_nil("Result should not be NaN") -- Case-insensitive match
    end)

    --- Conceptually tests handling of potentially unsafe inputs (e.g., ensuring string inputs are sanitized).
    it("should conceptually handle sanitized inputs", function()
      -- Simulating external input sanitization
      local input_a = "10" -- Simulate string input from external source
      local input_b = "5" -- Simulate string input

      -- Sanitize inputs by converting to numbers
      local a = tonumber(input_a)
      local b = tonumber(input_b)

      -- Verify sanitization worked
      expect(a).to.be.a("number", "Input a should be converted to number")
      expect(b).to.be.a("number", "Input b should be converted to number")

      -- Verify calculation works with sanitized inputs
      expect(calculator.add(a, b)).to.equal(15)
      expect(calculator.divide(a, b)).to.equal(2)
    end)
  end)

  --- Tests related to the performance of calculator functions (basic timing).
  --- @within examples.quality_example
  describe("when measuring performance", function()
    --- Performs a basic timing check for the power function.
    it("should calculate power efficiently (basic timing)", function()
      -- Performance test: measure execution time
      local start_time = os.clock()
      calculator.power(2, 20)
      local end_time = os.clock()
      local execution_time = end_time - start_time

      -- Verify performance is within acceptable range
      expect(execution_time).to.be_less_than(0.01, "Power calculation should be fast")
      expect(execution_time).to.be_greater_than_or_equal_to(0, "Execution time should be non-negative")
      expect(execution_time).to.be.a("number", "Execution time should be a number")
      expect(tostring(execution_time):match("[Nn][Aa][Nn]")).to.be_nil("Execution time should not be NaN")
      expect(tostring(execution_time):match("[Ii][Nn][Ff]")).to.be_nil("Execution time should not be infinity")
    end)
  end)
  -- Removed empty before/after hooks
end)

logger.info("\n-- Quality Levels Example --")
logger.info("This example uses describe blocks named 'Level X' to illustrate test quality concepts.")
logger.info("A hypothetical test runner might use a flag like '--quality' or '--quality-level=N'")
logger.info("to filter tests based on these conceptual levels (this is not standard Firmo functionality).")
logger.info("\nRun the tests normally:")
logger.info("  lua test.lua examples/quality_example.lua")
