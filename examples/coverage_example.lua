--- coverage_example.lua
--
-- This file provides an example module (`MathUtilities`) and associated tests
-- specifically designed to demonstrate various code coverage scenarios when
-- analyzed by Firmo's coverage tool.
--
-- Running this file with `lua test.lua --coverage examples/coverage_example.lua`
-- will generate coverage reports (e.g., HTML, Cobertura) showing:
-- - Fully covered functions (`is_even`, `is_odd`).
-- - Partially covered functions (`categorize_number`, missing the "large positive" branch).
-- - Completely uncovered functions (`unused_function`).
--
-- This helps verify that the coverage reporting accurately reflects different
-- execution paths and misses within the codebase.
--

local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("CoverageExample")

-- Extract testing functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- OS detection helper function (needed for browser opening)
local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

--- A sample module with various functions designed to illustrate
-- different code coverage states (covered, partially covered, uncovered).
local MathUtilities = {}

--- Checks if a given number is even. Includes input validation.
-- @param n number The number to check.
-- @return boolean|nil True if even, false if odd, or nil on error.
-- @return table|nil An error object if the input is not a number.
MathUtilities.is_even = function(n)
  if type(n) ~= "number" then
    return nil, error_handler.validation_error("Input must be a number", { parameter = "n", provided_type = type(n) })
  end
  return n % 2 == 0
end

--- Checks if a given number is odd. Includes input validation.
-- @param n number The number to check.
-- @return boolean|nil True if odd, false if even, or nil on error.
-- @return table|nil An error object if the input is not a number.
MathUtilities.is_odd = function(n)
  if type(n) ~= "number" then
    return nil, error_handler.validation_error("Input must be a number", { parameter = "n", provided_type = type(n) })
  end
  return n % 2 ~= 0
end

--- Categorizes a number based on its value (negative, zero, small positive, large positive).
-- Intentionally designed with branches that might not be fully covered by tests
-- to demonstrate branch coverage reporting.
-- @param n any The value to categorize.
-- @return string category A string describing the number's category.
MathUtilities.categorize_number = function(n)
  if type(n) ~= "number" then
    return "not a number"
  end

  if n < 0 then
    return "negative"
  elseif n == 0 then
    return "zero"
  elseif n > 0 and n < 10 then
    return "small positive"
  else
    return "large positive"
  end
end

--- An example function that is intentionally not called by any tests.
-- This is included to demonstrate how uncovered functions appear in coverage reports.
-- @param n number Input number.
-- @return number The square of the input number.
MathUtilities.unused_function = function(n)
  -- Intentionally empty and uncovered
end

-- Tests for the math utilities module
--- Test suite for the MathUtilities module.
describe("MathUtilities Module Tests", function()
  --- Tests for the `MathUtilities.is_even` function.
  describe("is_even", function()
    it("correctly identifies even numbers", function()
      expect(MathUtilities.is_even(2)).to.equal(true)
      expect(MathUtilities.is_even(4)).to.equal(true)
      expect(MathUtilities.is_even(0)).to.equal(true)
    end)

    it("correctly identifies non-even numbers", function()
      expect(MathUtilities.is_even(1)).to.equal(false)
      expect(MathUtilities.is_even(3)).to.equal(false)
      expect(MathUtilities.is_even(-5)).to.equal(false)
    end)

    it("handles invalid input", function()
      expect(function()
        MathUtilities.is_even("not a number")
      end).to.fail.with("must be a number")
    end)
  end) -- Close describe("is_even", ...)

  --- Tests for the `MathUtilities.is_odd` function.
  describe("is_odd", function()
    it("correctly identifies odd numbers", function()
      expect(MathUtilities.is_odd(1)).to.equal(true)
      expect(MathUtilities.is_odd(3)).to.equal(true)
      expect(MathUtilities.is_odd(-7)).to.equal(true)
    end)

    it("correctly identifies non-odd numbers", function()
      expect(MathUtilities.is_odd(2)).to.equal(false)
      expect(MathUtilities.is_odd(4)).to.equal(false)
      expect(MathUtilities.is_odd(0)).to.equal(false)
    end)

    it("handles invalid input", function()
      expect(function()
        MathUtilities.is_odd({})
      end).to.fail.with("must be a number")
    end)
  end)

  --- Tests for the `MathUtilities.categorize_number` function.
  -- Note: These tests intentionally do not cover all branches to demonstrate
  -- partial coverage reporting.
  describe("categorize_number", function()
    it("handles invalid input type", function()
      expect(MathUtilities.categorize_number("hello")).to.equal("not a number")
      expect(MathUtilities.categorize_number({})).to.equal("not a number")
      expect(MathUtilities.categorize_number(nil)).to.equal("not a number")
    end)

    it("identifies negative numbers", function()
      expect(MathUtilities.categorize_number(-1)).to.equal("negative")
      expect(MathUtilities.categorize_number(-10)).to.equal("negative")
    end)

    it("identifies zero", function()
      expect(MathUtilities.categorize_number(0)).to.equal("zero")
    end)

    it("identifies small positive numbers", function()
      expect(MathUtilities.categorize_number(5)).to.equal("small positive")
    end)

    -- Note: We don't test the "large positive" branch
    -- This will intentionally show up as incomplete coverage
  end)

  -- Note: We don't test unused_function at all
  -- This will show up as a completely uncovered function

  -- Log information about running coverage
  logger.info("\n=== Coverage Example ===")
  logger.info("To run this example with coverage enabled, use the command:")
  logger.info("lua test.lua --coverage --pattern=MathUtilities examples/coverage_example.lua")
  logger.info("\nThis will generate a coverage report showing:")
  logger.info("1. Fully covered functions (is_even, is_odd)")
  logger.info("2. Partially covered function (categorize_number)")
  logger.info("3. Completely uncovered function (unused_function)")
  logger.info("\nThe coverage report will show:")
  logger.info("- Line-by-line execution counts")
  logger.info("- Branch coverage gaps")
  logger.info("- Overall coverage percentage")
  logger.info("- Files that aren't covered at all\n")
end) -- Close main describe block
