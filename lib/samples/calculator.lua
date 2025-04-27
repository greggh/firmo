--- Simple Calculator Module
---
--- This module provides basic arithmetic operations (add, subtract, multiply, divide).
--- It is primarily used for testing coverage functionality within the Firmo project.
---
--- @module lib.samples.calculator
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class Calculator Basic arithmetic operations.
---@field add fun(a: number, b: number): number Adds two numbers.
---@field subtract fun(a: number, b: number): number Subtracts the second number from the first.
---@field multiply fun(a: number, b: number): number Multiplies two numbers.
---@field divide fun(a: number, b: number): number Divides the first number by the second. Throws error on division by zero.
local calculator = {}

--- Adds two numbers.
---@param a number The first number.
---@param b number The second number.
---@return number The sum of a and b.
function calculator.add(a, b)
    local result = a + b
    return result
end

--- Subtracts the second number from the first.
---@param a number The first number (minuend).
---@param b number The second number (subtrahend).
---@return number The difference (a - b).
function calculator.subtract(a, b)
    local result = a - b
    return result
end

--- Multiplies two numbers.
---@param a number The first number.
---@param b number The second number.
---@return number The product of a and b.
function calculator.multiply(a, b)
    local result = a * b
    return result
end

--- Divides the first number by the second.
---@param a number The first number (dividend).
---@param b number The second number (divisor).
---@return number The quotient (a / b).
---@throws string If the divisor `b` is zero ("Division by zero").
function calculator.divide(a, b)
    if b == 0 then
        error("Division by zero")
    end
    local result = a / b
    return result
end

return calculator