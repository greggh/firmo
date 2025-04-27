# Firmo JSDoc Style Guide

This document outlines the standards for JSDoc documentation within the firmo project. Consistency in documentation is crucial for maintainability and understanding.

## General Rules

1.  **Prefix:** All JSDoc lines MUST start with `---`.
2.  **Luau Types:** Use Luau-style type annotations (e.g., `string`, `number`, `boolean`, `table`, `function`, `any`, `nil`, `ClassName`, `Type1|Type2`, `fun(arg1: type1): returntype`).

## File Header Documentation

1.  **Module/Class Description:** Each file representing a module or class SHOULD start with a JSDoc block comment describing the file's purpose and functionality.
2.  **Metadata Tags:** This header block MAY include tags like `@module ModuleName`, `@author Author Name`, `@version x.y.z`, `@license MIT`, `@copyright Year(s)`.
3.  **Class Definition:** If the file primarily defines a class, it MUST include a `---@class ClassName` tag.
4.  **Field/Method Summary:** Immediately following the `---@class` tag, all public fields and methods of the class MUST be documented using `---@field name type|fun(...) Description`. This provides a quick overview of the class structure.

    ```lua
    ---@class MyClass
    ---@field public_prop string A public property.
    ---@field _internal_prop number Internal state (use underscore prefix).
    ---@field do_something fun(arg1: string): boolean Does something important.

    local MyClass = {}
    MyClass.__index = MyClass

    --- Initializes a new instance.
    ---@param initial_value string The initial value for the property.
    ---@return MyClass
    function MyClass:new(initial_value)
      -- ...
    end

    --- Does something important.
    ---@param arg1 string An argument.
    ---@return boolean Success status.
    function MyClass:do_something(arg1)
        -- ...
    end

    return MyClass
    ```

## Function Documentation

1.  **Requirement:** All exported/public functions MUST have a JSDoc block immediately preceding their definition. Internal/private functions SHOULD also be documented.
2.  **Description:** Include a brief `--- Description` summarizing the function's purpose and behavior.
3.  **Parameters (`@param`):**
    *   Use `---@param name type Description` for each parameter.
    *   Clearly state the expected Luau `type`.
    *   Optional parameters are indicated with `?` after the name (e.g., `name?`).
    *   Provide a concise `Description`.
4.  **Return Values (`@return`):**
    *   Use `---@return type Description` for a single return value.
    *   For multiple return values, use `---@return type1, type2 Description1, Description2`.
    *   Use `nil` as the type if the function does not explicitly return anything.
    *   Provide a clear `Description` of what is returned.
5.  **Throws (`@throws`):** Use `---@throws type Description` if the function is expected to throw errors under certain conditions. Describe the error `type` (e.g., `string`, `table`) and the `Description` of when it occurs.
6.  **Deprecated (`@deprecated`):** Use `---@deprecated Description` for functions that are deprecated. Explain why and what should be used instead.
7.  **Private (`@private`):** Use `---@private` for internal helper functions not intended for public use.

    ```lua
    --- Calculates the sum of two numbers.
    ---@param a number The first number.
    ---@param b number The second number.
    ---@return number The sum of a and b.
    ---@throws string If inputs are not numbers.
    local function add_numbers(a, b)
      if type(a) ~= "number" or type(b) ~= "number" then
        error("Inputs must be numbers")
      end
      return a + b
    end
    ```

## Formatting and Style

1.  **Consistency:** Maintain consistent spacing and alignment within JSDoc blocks.
2.  **Clarity:** Write clear and concise descriptions. Avoid jargon where possible.
3.  **Completeness:** Ensure all relevant aspects (parameters, return values, side effects, errors) are documented.

## Special Cases

1.  **Diagnostic Comments:** Existing `---@diagnostic disable-next-line: rule-name` comments MUST be preserved. Do not remove them unless the code they apply to is removed.
2.  **Polymorphism:** If a function accepts parameters of multiple types or behaves differently based on input types (polymorphism), document this clearly.
    *   Use union types (`Type1|Type2`).
    *   Use multiple `@param` or `@return` tags if signatures differ significantly.
    *   Explain the different behaviors in the description.

    ```lua
    --- Processes input, which can be a string or a number.
    ---@param input string|number The input value.
    ---@return string|nil Processed string or nil if invalid.
    function process_input(input)
      if type(input) == "string" then
        return "Processed string: " .. input
      elseif type(input) == "number" then
        return "Processed number: " .. tostring(input)
      else
        return nil -- Invalid input type
      end
    end
    ```

