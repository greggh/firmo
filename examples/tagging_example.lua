--- Example demonstrating test tagging and filtering with Firmo.
---
--- This example shows how to apply tags to `describe` blocks and `it` blocks
--- using `firmo.tags()`. These tags can then be used with the test runner's
--- command-line flags (`--tags`, `--exclude-tags`, `--filter`) to selectively
--- run specific groups of tests.
---
--- @module examples.tagging_example
--- @see firmo.tags
--- @see docs/guides/cli.md (for runner flags)
--- @usage
--- Run tests using tags or filters:
--- ```bash
--- # Run all tests in this file
--- lua test.lua examples/tagging_example.lua
---
--- # Run only tests tagged 'unit'
--- lua test.lua --tags unit examples/tagging_example.lua
---
--- # Run only tests tagged 'api'
--- lua test.lua --tags api examples/tagging_example.lua
---
--- # Run tests tagged 'unit' but NOT 'error-handling'
--- lua test.lua --tags unit --exclude-tags error-handling examples/tagging_example.lua
---
--- # Run tests with 'calc' in their name (suite or case name)
--- lua test.lua --filter calc examples/tagging_example.lua
--- ```

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

-- This represents a simple calculator API we're testing
--- @class CalculatorAPI
--- @field add fun(a: number, b: number): number
--- @field subtract fun(a: number, b: number): number
--- @field multiply fun(a: number, b: number): number
--- @field divide fun(a: number, b: number): number|error
--- @within examples.tagging_example
local calculator = {
  add = function(a, b)
    return a + b
  end,
  subtract = function(a, b)
    return a - b
  end,
  multiply = function(a, b)
    return a * b
  end,
  divide = function(a, b)
    if b == 0 then
      error("Cannot divide by zero")
    end
    return a / b
  end,
}

--- Main test suite for the calculator.
--- @within examples.tagging_example
describe("Calculator Tests", function()
  --- Suite for basic operations, tagged 'unit' and 'fast'.
  --- @within examples.tagging_example
  describe("Basic Operations", function()
    -- Apply tags to all tests within this describe block
    firmo.tags("unit", "fast")

    --- Tests addition. Inherits 'unit', 'fast' tags.
    it("adds two numbers correctly", function()
      expect(calculator.add(2, 3)).to.equal(5)
    end)

    --- Tests subtraction. Inherits 'unit', 'fast' tags.
    it("subtracts two numbers correctly", function()
      expect(calculator.subtract(5, 3)).to.equal(2)
    end)

    --- Tests multiplication. Inherits 'unit', 'fast' tags.
    it("multiplies two numbers correctly", function()
      expect(calculator.multiply(2, 3)).to.equal(6)
    end)

    --- Tests division. Inherits 'unit', 'fast' tags.
    it("divides two numbers correctly", function()
      expect(calculator.divide(6, 2)).to.equal(3)
    end)
  end)

  --- Suite for error handling tests, tagged 'unit' and 'error-handling'.
  --- @within examples.tagging_example
  describe("Error Handling", function()
    firmo.tags("unit", "error-handling") -- Apply tags to this block

    --- Tests division by zero error. Inherits 'unit', 'error-handling' tags.
    it("throws error when dividing by zero", function()
      expect(function()
        calculator.divide(5, 0)
      end).to.fail.with("Cannot divide by zero")
    end)
  end)

  --- Suite for more complex tests, tagged 'api' and 'slow'.
  --- @within examples.tagging_example
  describe("Advanced Calculations", function()
    firmo.tags("api", "slow") -- Apply tags to this block

    --- Tests a sequence of operations. Inherits 'api', 'slow' tags.
    it("performs complex calculation pipeline", function()
      local result = calculator.add(calculator.multiply(3, 4), calculator.divide(10, 2))
      expect(result).to.equal(17)
    end)

    --- Tests operations with negative numbers. Inherits 'api', 'slow' tags.
    it("handles negative number operations", function()
      expect(calculator.add(-5, 3)).to.equal(-2)
      expect(calculator.multiply(-2, -3)).to.equal(6)
    end)
  end)
end)
