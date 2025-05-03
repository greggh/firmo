--- Basic example demonstrating the fundamental structure of a Firmo test suite.
---
--- This example showcases:
--- - Importing the Firmo framework and extracting core functions (`describe`, `it`, `expect`, `before`, `after`).
--- - Defining a test suite using `describe`.
--- - Setting up preconditions using `before`.
--- - Cleaning up resources using `after`.
--- - Writing individual test cases using `it`.
--- - Making assertions using `expect`.
--- - Organizing tests with nested `describe` blocks.
--- - Testing for expected errors using `test_helper.with_error_capture` and the `expect_error` option.
---
--- @module examples.basic_example
--- @see firmo
--- @see lib.tools.test_helper
--- @see lib.tools.error_handler
--- @usage
--- Run embedded tests:
--- ```bash
--- lua test.lua examples/basic_example.lua
--- ```

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after

-- Optional: Import error handling utilities for testing errors
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

local logger = logging.get_logger("BasicExample")

--- A simple calculator module to be tested.
--- @class Calculator
--- @field add fun(a: number, b: number): number Adds two numbers.
--- @field subtract fun(a: number, b: number): number Subtracts two numbers.
--- @field multiply fun(a: number, b: number): number Multiplies two numbers.
--- @field divide fun(a: number, b: number): number|nil, table|nil Divides two numbers, returns error on division by zero.
--- @within examples.basic_example
local calculator = {
  --- Adds two numbers.
  -- @param a number First number.
  -- @param b number Second number.
  -- @return number The sum.
  add = function(a, b)
    return a + b
  end,
  --- Subtracts the second number from the first.
  -- @param a number The number to subtract from.
  -- @param b number The number to subtract.
  -- @return number The difference.
  subtract = function(a, b)
    return a - b
  end,
  --- Multiplies two numbers.
  -- @param a number First number.
  -- @param b number Second number.
  -- @return number The product.
  multiply = function(a, b)
    return a * b
  end,
  --- Divides the first number by the second.
  -- @param a number The dividend.
  -- @param b number The divisor.
  -- @return number|nil The quotient, or `nil` on error.
  -- @return table|nil err A validation error object if `b` is 0.
  divide = function(a, b)
    if b == 0 then
      return nil, error_handler.validation_error("Cannot divide by zero", { parameter = "b", provided_value = b })
    end
    return a / b
  end,
}

-- Test suite using nested describe blocks
--- Defines the main test suite for the simple calculator module.
--- @within examples.basic_example
describe("Calculator", function()
  --- Setup function that runs before each `it` block within this `describe` block.
  before(function()
    -- Use structured logging
    logger.info("Setting up test for calculator", { module = "calculator" })
  end)
  -- Removed extra end)

  --- Teardown function that runs after each `it` block within this `describe` block.
  after(function()
    logger.info("Cleaning up test for calculator", { module = "calculator" })
  end) -- Added missing end)

  --- Groups tests related to basic arithmetic operations.
  --- @within examples.basic_example
  describe("Basic Operations", function()
    --- Tests for the addition functionality.
    --- @within examples.basic_example
    describe("addition", function()
      --- Tests adding two positive numbers.
      it("adds two positive numbers", function()
        expect(calculator.add(2, 3)).to.equal(5)
      end)

      --- Tests adding a positive and a negative number.
      it("adds a positive and a negative number", function()
        expect(calculator.add(2, -3)).to.equal(-1)
      end)
    end) -- Closes describe("addition", ...)

    --- Tests for the subtraction functionality.
    --- @within examples.basic_example
    describe("subtraction", function()
      --- Tests subtracting two numbers.
      it("subtracts two numbers", function()
        expect(calculator.subtract(5, 3)).to.equal(2)
      end)
    end) -- Closes describe("subtraction", ...)

    --- Tests for the multiplication functionality.
    --- @within examples.basic_example
    describe("multiplication", function()
      --- Tests multiplying two numbers.
      it("multiplies two numbers", function()
        expect(calculator.multiply(2, 3)).to.equal(6)
      end)
    end) -- Closes describe("multiplication", ...)
  end) -- Closes describe("Basic Operations", ...)

  --- Groups tests related to more complex operations or error handling.
  --- @within examples.basic_example
  describe("Advanced Operations", function()
    --- Tests for the division functionality, including error handling.
    --- @within examples.basic_example
    describe("division", function()
      --- Tests dividing two numbers.
      it("divides two numbers", function()
        expect(calculator.divide(6, 3)).to.equal(2)
      end)

      -- Example of proper error testing using the `expect_error` option
      --- Tests that division by zero returns an appropriate error.
      it("handles division by zero", { expect_error = true }, function()
        -- Use test_helper.with_error_capture to safely call the function
        local result, err = test_helper.with_error_capture(function()
          return calculator.divide(5, 0)
        end)()

        -- Make assertions about the error
        expect(result).to_not.exist()
        expect(err).to.exist()
        expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
        expect(err.message).to.match("divide by zero")
      end)
    end) -- Closes describe("division", ...)
  end) -- Closes describe("Advanced Operations", ...)
end) -- Closes describe("Calculator", ...)

-- NOTE: Run this example using the standard test runner:
-- lua test.lua examples/basic_example.lua
