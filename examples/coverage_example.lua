--- Example demonstrating code coverage analysis with Firmo.
---
--- This file provides a sample module (`MathUtilities`) and associated tests
--- specifically designed to illustrate various code coverage scenarios when
--- analyzed by Firmo's coverage tool (`lua test.lua --coverage ...`).
---
--- It demonstrates how Firmo's coverage reports visualize:
--- - Fully covered functions (`is_even`, `is_odd`).
--- - Partially covered functions with uncovered branches (`categorize_number`).
--- - Completely uncovered functions (`unused_function`).
---
--- Running this example with coverage enabled helps verify that the reporting
--- accurately reflects execution paths and identifies untested code sections.
---
--- @module examples.coverage_example
--- @see lib.coverage
--- @see docs/guides/coverage.md
--- @usage
--- Run tests with coverage analysis:
--- ```bash
--- lua test.lua --coverage examples/coverage_example.lua
--- ```
--- View the generated HTML report (usually in `coverage-report/index.html`) to see the results.

local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("CoverageExample")

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after

--- A sample module with various functions designed to illustrate
-- different code coverage states (fully covered, partially covered, uncovered).
--- @class MathUtilities
--- @field is_even fun(n: number): boolean|nil, table|nil Checks if a number is even.
--- @field is_odd fun(n: number): boolean|nil, table|nil Checks if a number is odd.
--- @field categorize_number fun(n: any): string Categorizes a number.
--- @field unused_function fun(n: number): nil An intentionally uncovered function.
--- @within examples.coverage_example
local MathUtilities = {}

--- Checks if a given number is even. Includes input validation.
--- This function aims for full coverage in tests.
--- @param n number The number to check.
--- @return boolean|nil `true` if even, `false` if odd, or `nil` on error.
--- @return table|nil err A validation error object if the input `n` is not a number.
MathUtilities.is_even = function(n)
  if type(n) ~= "number" then
    return nil, error_handler.validation_error("Input must be a number", { parameter = "n", provided_type = type(n) })
  end
  return n % 2 == 0
end

--- Checks if a given number is odd. Includes input validation.
--- This function aims for full coverage in tests.
--- @param n number The number to check.
--- @return boolean|nil `true` if odd, `false` if even, or `nil` on error.
--- @return table|nil err A validation error object if the input `n` is not a number.
MathUtilities.is_odd = function(n)
  if type(n) ~= "number" then
    return nil, error_handler.validation_error("Input must be a number", { parameter = "n", provided_type = type(n) })
  end
  return n % 2 ~= 0
end

--- Categorizes a number based on its value (negative, zero, small positive, large positive).
-- Intentionally designed with branches that might not be fully covered by tests
-- to demonstrate partial branch coverage reporting.
--- @param n any The value to categorize (expected number, but handles other types).
--- @return string category A string describing the number's category ("negative", "zero", "small positive", "large positive", "not a number").
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
-- This function is intentionally left untested to demonstrate 0% coverage in reports.
--- @param n number Input number (unused).
--- @return nil
MathUtilities.unused_function = function(n)
  logger.warn("This function (unused_function) should not be called during tests.")
  -- Intentionally empty and uncovered.
end

-- Tests for the math utilities module
--- Test suite for the MathUtilities module.
--- @within examples.coverage_example
describe("MathUtilities Module Tests", function()
  --- Tests for the `MathUtilities.is_even` function. Aims for full coverage.
  --- @within examples.coverage_example
  describe("is_even", function()
    --- Tests `is_even` with even numbers.
    it("correctly identifies even numbers", function()
      expect(MathUtilities.is_even(2)).to.equal(true)
      expect(MathUtilities.is_even(4)).to.equal(true)
      expect(MathUtilities.is_even(0)).to.equal(true)
    end)

    --- Tests `is_even` with odd numbers.
    it("correctly identifies non-even (odd) numbers", function()
      expect(MathUtilities.is_even(1)).to.equal(false)
      expect(MathUtilities.is_even(3)).to.equal(false)
      expect(MathUtilities.is_even(-5)).to.equal(false) -- Negative odd
    end)

    --- Tests that `is_even` returns an error for non-numeric input.
    it("handles invalid non-numeric input", { expect_error = true }, function()
      local res, err = test_helper.with_error_capture(function()
        return MathUtilities.is_even("not a number")
      end)()
      expect(res).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("must be a number")
    end)
  end)

  --- Tests for the `MathUtilities.is_odd` function. Aims for full coverage.
  --- @within examples.coverage_example
  describe("is_odd", function()
    --- Tests `is_odd` with odd numbers.
    it("correctly identifies odd numbers", function()
      expect(MathUtilities.is_odd(1)).to.equal(true)
      expect(MathUtilities.is_odd(3)).to.equal(true)
      expect(MathUtilities.is_odd(-7)).to.equal(true) -- Negative odd
    end)

    --- Tests `is_odd` with even numbers.
    it("correctly identifies non-odd (even) numbers", function()
      expect(MathUtilities.is_odd(2)).to.equal(false)
      expect(MathUtilities.is_odd(4)).to.equal(false)
      expect(MathUtilities.is_odd(0)).to.equal(false)
    end)

    --- Tests that `is_odd` returns an error for non-numeric input.
    it("handles invalid non-numeric input", { expect_error = true }, function()
      local res, err = test_helper.with_error_capture(function()
        return MathUtilities.is_odd({}) -- Use a table as invalid input
      end)()
      expect(res).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("must be a number")
    end)
  end)

  --- Tests for the `MathUtilities.categorize_number` function.
  -- Note: These tests intentionally *do not cover all branches* (specifically the 'large positive' case)
  -- to demonstrate partial branch coverage reporting in the output.
  --- @within examples.coverage_example
  describe("categorize_number (Partial Coverage Example)", function()
    --- Tests the handling of non-numeric input.
    it("handles invalid non-numeric input type", function()
      expect(MathUtilities.categorize_number("hello")).to.equal("not a number")
      expect(MathUtilities.categorize_number({})).to.equal("not a number")
      expect(MathUtilities.categorize_number(nil)).to.equal("not a number")
    end)

    --- Tests the 'negative' branch.
    it("identifies negative numbers", function()
      expect(MathUtilities.categorize_number(-1)).to.equal("negative")
      expect(MathUtilities.categorize_number(-10)).to.equal("negative")
    end)

    --- Tests the 'zero' branch.
    it("identifies zero", function()
      expect(MathUtilities.categorize_number(0)).to.equal("zero")
    end)

    --- Tests the 'small positive' branch.
    it("identifies small positive numbers (0 < n < 10)", function()
      expect(MathUtilities.categorize_number(5)).to.equal("small positive")
      expect(MathUtilities.categorize_number(1)).to.equal("small positive")
      expect(MathUtilities.categorize_number(9)).to.equal("small positive")
    end)

    -- INTENTIONALLY OMITTED: Test for the 'large positive' (n >= 10) branch.
    -- This ensures the function shows as partially covered in the report.
    -- To achieve full coverage, add:
    -- it("identifies large positive numbers", function()
    --   expect(MathUtilities.categorize_number(10)).to.equal("large positive")
    --   expect(MathUtilities.categorize_number(100)).to.equal("large positive")
    -- end)
  end)

  -- Log information about running coverage after tests are defined
  after(function()
    -- This runs once after all tests in this describe block finish
    logger.info("\n--- Coverage Example Notes ---")
    logger.info("Run with: `lua test.lua --coverage examples/coverage_example.lua`")
    logger.info("Expected coverage results:")
    logger.info(" - `is_even`, `is_odd`: Should show high/full coverage.")
    logger.info(" - `categorize_number`: Should show partial coverage (missing 'large positive' branch).")
    logger.info(" - `unused_function`: Should show 0% coverage.")
    logger.info("Check the generated report (e.g., HTML) for details.")
  end)
end)
