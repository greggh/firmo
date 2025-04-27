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
-- **Note:** This quality level filtering is *not* standard Firmo functionality
-- but is presented here as an illustration of advanced test organization.
--
-- Run embedded tests: lua test.lua examples/quality_example.lua
--

local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("QualityExample")

-- Extract test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

--- A simple calculator module used for demonstrating tests at different quality levels.
local calculator = {}

--- Adds two numbers.
-- @param a number First number.
-- @param b number Second number.
-- @return number Sum of a and b.
calculator.add = function(a, b)
  return a + b
end

--- Subtracts the second number from the first.
-- @param a number First number.
-- @param b number Second number.
-- @return number Difference of a and b.
calculator.subtract = function(a, b)
  return a - b
end

--- Multiplies two numbers.
-- @param a number First number.
-- @param b number Second number.
-- @return number Product of a and b.
calculator.multiply = function(a, b)
  return a * b
end

--- Divides the first number by the second. Handles division by zero.
-- @param a number Numerator.
-- @param b number Denominator.
-- @return number|nil Quotient on success, or nil.
-- @return table|nil err Error object if b is zero.
calculator.divide = function(a, b)
  if b == 0 then
    return nil, error_handler.validation_error(
      "Division by zero",
      {operation = "divide", b = b}
    )
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

--- Conceptual: Level 1 tests - Basic tests with minimal assertions.
describe("Calculator - Level 1 (Basic)", function()
  -- This test has only one assertion
  it("adds two numbers", function()
    expect(calculator.add(2, 3)).to.equal(5)
  end)
end)

--- Conceptual: Level 2 tests - Standard tests with more assertions and setup/teardown.
describe("Calculator - Level 2 (Standard)", function()
  it("should add two positive numbers correctly", function()
    expect(calculator.add(2, 3)).to.equal(5)
    expect(calculator.add(0, 5)).to.equal(5)
    expect(calculator.add(10, 20)).to.equal(30, "10 + 20 should equal 30")
  end)

  it("should subtract properly", function()
    expect(calculator.subtract(5, 3)).to.equal(2)
    expect(calculator.subtract(10, 5)).to.equal(5)
  end)

  -- Setup and teardown functions
  before(function()
    -- Set up any test environment needed
    logger.debug("Setting up test environment")
  end)

  after(function()
    -- Clean up after tests
    logger.debug("Cleaning up test environment")
  end)
end)

--- Conceptual: Level 3 tests - Comprehensive tests including edge cases and error handling.
describe("Calculator - Level 3 (Comprehensive)", function()
  --- Tests focused on the division operation, including edge cases.
  describe("when performing division", function()
    it("should divide two numbers", function()
      expect(calculator.divide(10, 2)).to.equal(5)
      expect(calculator.divide(7, 2)).to.equal(3.5)
      expect(calculator.divide(10, 2)).to.be.a("number", "Result should be a number")
    end)

    it("should handle division with edge cases", function()
      expect(calculator.divide(0, 5)).to.equal(0)
      expect(calculator.divide(-10, 2)).to.equal(-5)
      expect(calculator.divide(1, 3)).to.be_near(0.333333, 0.001)
    end)

    it("should return error for division by zero", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return calculator.divide(10, 0)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Division by zero")
    end)
  end)
  -- Removed empty before/after hooks
end)

--- Conceptual: Level 4 tests - Advanced tests including boundary conditions and basic mocking (spy).
describe("Calculator - Level 4 (Advanced)", function()
  --- Tests focused on the power operation, including boundary conditions and call tracking.
  describe("when performing power operations", function()
    it("should calculate powers with various exponents", function()
      expect(calculator.power(2, 3)).to.equal(8)
      expect(calculator.power(5, 2)).to.equal(25)
      expect(calculator.power(10, 0)).to.equal(1)
      expect(calculator.power(2, 1)).to.equal(2)
    end)

    it("should handle boundary conditions", function()
      -- Testing upper bounds
      local result = calculator.power(2, 10)
      expect(result).to.equal(1024)
      expect(result).to.be_less_than(2 ^ 11, "Result should be less than 2^11")

      -- Testing lower bounds
      local small_result = calculator.power(2, -2)
      expect(small_result).to.be_near(0.25, 0.0001)
    end)

    it("should handle negative exponents correctly", function()
      expect(calculator.power(2, -1)).to.be_near(0.5, 0.0001)
      expect(calculator.power(4, -2)).to.be_near(0.0625, 0.0001)
    end)

    -- Mock test with call verification
    it("should track power calculations", function()
      local original_power = calculator.power

      -- Create a spy that tracks calls to the power function
      local spy = firmo.spy(calculator, "power")

      calculator.power(3, 2)
      calculator.power(2, 8)

      -- Verify spy was called
      expect(spy.call_count).to.equal(2, "Power function should be called twice")
      expect(spy:called_with(3, 2)).to.be_truthy("Should be called with 3, 2")
      expect(spy:called_with(2, 8)).to.be_truthy("Should be called with 2, 8")

      -- Restore original function
      calculator.power = original_power
    end)
  end)
  -- Removed empty before/after hooks
end)

--- Conceptual: Level 5 tests - Complete tests including non-functional aspects
-- like security considerations and performance checks.
describe("Calculator - Level 5 (Complete)", function()
  --- Tests related to security aspects of the calculator functions.
  describe("when considering security implications", function()
    it("should validate inputs to prevent overflow", function()
      -- Security test: very large inputs
      local large_result = calculator.power(2, 20)
      expect(large_result).to.be_greater_than(0, "Result should be positive")
      expect(large_result).to.be_less_than(2 ^ 30, "Result should be within safe range")
      expect(large_result).to.be.a("number", "Result should remain a number")
      expect(tostring(large_result):match("inf")).to_not.exist("Result should not be infinity")
      expect(tostring(large_result):match("nan")).to_not.exist("Result should not be NaN")
    end)

    it("should sanitize inputs from external sources", function()
      -- Simulating external input validation
      local input_a = "10" -- String input
      local input_b = "5" -- String input

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

  --- Tests related to the performance of calculator functions.
  describe("when measuring performance", function()
    it("should calculate power efficiently", function()
      -- Performance test: measure execution time
      local start_time = os.clock()
      calculator.power(2, 20)
      local end_time = os.clock()
      local execution_time = end_time - start_time

      -- Verify performance is within acceptable range
      expect(execution_time).to.be_less_than(0.01, "Power calculation should be fast")
      expect(execution_time).to.be_greater_than_or_equal_to(0, "Execution time should be non-negative")
      expect(execution_time).to.be.a("number", "Execution time should be a number")
      expect(tostring(execution_time):match("nan")).to_not.exist("Execution time should not be NaN")
      expect(tostring(execution_time):match("inf")).to_not.exist("Execution time should not be infinity")
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
