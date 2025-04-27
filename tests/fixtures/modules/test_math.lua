--- Simple Math Module Fixture
---
--- A basic module providing standard arithmetic functions (add, subtract, multiply).
--- Used primarily for testing coverage instrumentation and module interaction.
---
--- @module tests.fixtures.modules.test_math
--- @author Firmo Team
--- @fixture

---@class TestMath Basic math operations for testing.
---@field add fun(a: number, b: number): number Adds two numbers.
---@field subtract fun(a: number, b: number): number Subtracts the second number from the first.
---@field multiply fun(a: number, b: number): number Multiplies two numbers.
local M = {}

--- Adds two numbers.
---@param a number The first number.
---@param b number The second number.
---@return number The sum of a and b.
function M.add(a, b)
    return a + b
end

--- Subtracts the second number from the first.
---@param a number The first number (minuend).
---@param b number The second number (subtrahend).
---@return number The difference (a - b).
function M.subtract(a, b)
    return a - b
end

--- Multiplies two numbers.
---@param a number The first number.
---@param b number The second number.
---@return number The product of a and b.
function M.multiply(a, b)
    return a * b
end

return M