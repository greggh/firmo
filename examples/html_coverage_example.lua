--- html_coverage_example.lua
--
-- This example provides a sample module (`Calculator`) and associated tests
-- specifically designed to demonstrate how different code execution states are
-- visualized in Firmo's HTML coverage reports.
--
-- Running this file with `lua test.lua --coverage --format=html ...` will generate
-- an HTML report clearly showing:
--   1. **Covered code (green):** Code executed and validated by assertions.
--   2. **Executed-but-not-covered code (yellow):** Code executed during tests but not validated by assertions.
--   3. **Uncovered code (red):** Code never executed during tests.
--
-- This helps users understand the nuances of coverage reporting beyond simple line execution.
--
-- Run embedded tests: lua test.lua --coverage --format=html examples/html_coverage_example.lua
--

--[[
  html_coverage_example.lua

  Example that demonstrates HTML coverage reports with execution vs. coverage distinction.
  This example is designed to clearly show the difference between:

  1. Code that is executed and validated by tests (covered)
  2. Code that is executed but not validated (executed-not-covered)
  3. Code that is never executed (uncovered)
]]

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("HTMLCoverageExample")

--- Sample Calculator module implementation used to demonstrate different coverage states.
--- @class Calculator
--- @field add fun(a: number, b: number): number|nil, string|nil Adds two numbers (fully covered).
--- @field subtract fun(a: number, b: number): number|nil, string|nil Subtracts two numbers (executed-not-covered).
--- @field multiply fun(a: number, b: number): number|nil, string|nil Multiplies two numbers (uncovered).
--- @within examples.html_coverage_example
local Calculator = {}

--- Adds two numbers. Includes validation.
--- This function is designed to be fully covered by tests (green in HTML report).
--- @param a number The first number.
--- @param b number The second number.
--- @return number|nil The sum, or `nil` on error.
--- @return string|nil An error message if inputs are invalid.
function Calculator.add(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a + b
end

--- Subtracts two numbers. Includes validation.
--- This function is designed to be executed but *not* validated by tests,
--- demonstrating the 'executed-but-not-covered' state (yellow in HTML report).
--- @param a number The first number.
--- @param b number The second number.
--- @return number|nil The difference, or `nil` on error.
--- @return string|nil An error message if inputs are invalid.
function Calculator.subtract(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a - b
end

--- Multiplies two numbers. Includes validation.
--- This function is designed to be completely *uncovered* by tests (red in HTML report).
--- @param a number The first number.
--- @param b number The second number.
--- @return number|nil The product, or `nil` on error.
--- @return string|nil An error message if inputs are invalid.
function Calculator.multiply(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a * b
end

-- Run tests with coverage tracking
--- Test suite for the Calculator module, designed to generate specific coverage states
-- for demonstration in the HTML report.
--- @within examples.html_coverage_example
describe("HTML Coverage Report Example", function()
  --- Tests for the `Calculator.add` function. These tests execute
  -- the function and validate its output using `expect`, resulting in 'covered' (green) lines.
  --- @within examples.html_coverage_example
  describe("add function (Covered)", function()
    --- Tests the happy path for addition.
    it("correctly adds two numbers", function()
      local result = Calculator.add(5, 3)
      expect(result).to.equal(8) -- This validates the execution
    end)

    --- Tests the error handling path for addition.
    it("handles invalid inputs", function()
      local result, err = Calculator.add("string", 10)
      expect(result).to_not.exist() -- Validates nil return
      expect(err).to.equal("Both arguments must be numbers") -- Validates error message
    end)
  end)

  --- Tests for the `Calculator.subtract` function. These tests execute
  -- the function but do *not* validate its output using `expect`, resulting in
  -- 'executed-but-not-covered' (yellow) lines.
  --- @within examples.html_coverage_example
  describe("subtract function (Executed-Not-Covered)", function()
    --- Executes subtract but has no `expect` calls.
    it("executes the subtract function without validating its result", function()
      local result = Calculator.subtract(10, 4)
      -- No validations here, so this is executed but not covered
    end)
  end)

  -- No tests for multiply function, so it will not be executed at all
end)

-- Display instructions
logger.info("\nRunning this example with the coverage flag will generate an HTML report.")
logger.info("Execute the following command to see the HTML coverage report:")
logger.info("\n  lua test.lua --coverage --format=html examples/html_coverage_example.lua\n")
logger.info("The HTML report will show:")
logger.info("1. add function: Covered (green) - executed and validated by tests")
logger.info("2. subtract function: Executed-but-not-covered (yellow) - executed but not validated")
logger.info("3. multiply function: Uncovered (red) - never executed during tests")
logger.info("\nAfter running the command, open the generated HTML file in a web browser.\n")
