--- Enhanced Type Checking Utilities for Firmo
---
--- This module provides sophisticated type checking capabilities beyond Lua's basic `type()` function:
--- - Strict type validation with custom error messages (`is_exact_type`).
--- - Object-oriented class/instance relationship validation (`is_instance_of`).
--- - Interface implementation verification (`implements`).
--- - Container membership checking for tables and strings (`contains`).
--- - Error generation validation (`has_error`).
---
--- Functions in this module generally throw errors upon validation failure, making them suitable
--- for runtime assertions and validation within function guards.
---
--- @module lib.core.type_checking
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.2.3

---@class type_checking
---@field is_exact_type fun(value: any, expected_type: string, message?: string): boolean|nil Checks if a value is exactly of the specified primitive type. Returns `true` on success, throws error and potentially returns `nil, error_object` on failure.
---@field is_instance_of fun(object: table, class: table, message?: string): boolean|nil Checks if an object is an instance of a class (supports metatable inheritance). Returns `true` on success, throws error and potentially returns `nil, error_object` on failure.
---@field implements fun(object: table, interface: table, message?: string): boolean|nil Checks if an object implements all required interface methods/properties. Returns `true` on success, throws error and potentially returns `nil, error_object` on failure.
---@field contains fun(container: table|string, item: any, message?: string): boolean|nil Checks if a container (table or string) contains the specified item. Returns `true` on success, throws error and potentially returns `nil, error_object` on failure.
---@field has_error fun(fn: function, message?: string): any|nil Checks if a function throws an error. Returns the captured error on success, throws error and potentially returns `nil, error_object` if the function doesn't throw or validation fails.
---@field _VERSION string Module version identifier
local type_checking = {}

-- Module version
type_checking._VERSION = "0.2.3"

--- Validates that a value is exactly of the specified Lua primitive type
--- This function checks if a value's type (as returned by Lua's type() function) is
--- exactly the same as the expected_type. If they don't match, the function throws
--- an error with a descriptive message. This is useful for runtime type validation
--- and for asserting function parameter types.
---
--- @param value any The value to check the type of
--- @param expected_type string The expected type name (e.g., 'string', 'number', 'table')
--- @param message? string Optional custom error message to use if validation fails
--- @return boolean|nil true If the type matches, nil on error.
--- @return table? error Error object if validation fails.
--- @throws table If type doesn't match the `expected_type`.
---
--- @usage
--- -- Basic type validation
--- local tc = require("lib.core.type_checking")
--- tc.is_exact_type("hello", "string") -- returns true
---
--- -- Handling nested functions with custom error message
--- function process_user(user_data)
---   tc.is_exact_type(user_data, "table", "User data must be a table")
---   -- Process the user data safely...
--- end
---
--- -- Using as a guard in functions
--- function calculate_area(width, height)
---   tc.is_exact_type(width, "number", "Width must be a number")
---   tc.is_exact_type(height, "number", "Height must be a number")
---   return width * height
--- end
function type_checking.is_exact_type(value, expected_type, message)
  local actual_type = type(value)

  if actual_type ~= expected_type then
    local default_message =
      string.format("Expected value to be exactly of type '%s', but got '%s'", expected_type, actual_type)
    error(message or default_message, 2)
  end

  return true
end

--- Validates that an object is an instance of a specific class
--- This function performs a sophisticated check to determine if an object is an
--- instance of a given class, accounting for Lua's metatable inheritance system.
--- It checks both direct metatable relationships and inheritance chains, including
--- both metatable.__index inheritance and meta-inheritance (metatables of metatables).
---
--- @param object table The object to check
--- @param class table The class/metatable to check against
--- @param message? string Optional custom error message to use if validation fails
--- @return boolean|nil true If object is instance, nil on error.
--- @return table? error Error object if validation fails.
--- @throws table If object is not an instance of `class`.
---
--- @usage
--- -- Basic class instance checking
--- local tc = require("lib.core.type_checking")
--- local Animal = {} -- Base class
--- Animal.__index = Animal
---
--- local Dog = setmetatable({}, Animal) -- Inherited class
--- Dog.__index = Dog
---
--- local my_dog = setmetatable({name = "Rex"}, Dog)
---
--- tc.is_instance_of(my_dog, Dog) -- returns true
--- tc.is_instance_of(my_dog, Animal) -- also returns true (inheritance)
---
--- -- With custom error message
--- function pet_animal(animal)
---   tc.is_instance_of(animal, Animal, "Expected an Animal instance")
---   -- Safe to use animal methods...
---   print("Petting " .. animal.name)
--- end
function type_checking.is_instance_of(object, class, message)
  -- Validate arguments
  if type(object) ~= "table" then
    ---@diagnostic disable-next-line: ambiguity-1
    error(message or "Expected object to be a table (got " .. type(object) .. ")", 2)
  end

  if type(class) ~= "table" then
    ---@diagnostic disable-next-line: ambiguity-1
    error(message or "Expected class to be a metatable (got " .. type(class) .. ")", 2)
  end

  -- Get object's metatable
  local mt = getmetatable(object)

  -- No metatable means it's not an instance of anything
  if not mt then
    local default_message =
      string.format("Expected object to be an instance of %s, but it has no metatable", class.__name or tostring(class))
    error(message or default_message, 2)
    return false
  end

  -- Check if object's metatable matches the class directly
  if mt == class then
    return true
  end

  -- Handle inheritance: Check if any metatable in the hierarchy is the class
  -- Check both metatable.__index (for inheritance) and getmetatable(metatable) for inheritance
  --- Recursively checks if a metatable (`meta`) is or inherits from a `target_class`.
  --- Handles `__index` inheritance and parent metatable inheritance, preventing cycles.
  ---@param meta table The metatable to check.
  ---@param target_class table The target class/metatable to look for in the inheritance chain.
  ---@param seen? table Internal table to track visited metatables to prevent infinite recursion in cyclic metatable structures.
  ---@return boolean `true` if `meta` is or inherits from `target_class`, `false` otherwise.
  ---@private
  local function check_inheritance_chain(meta, target_class, seen)
    seen = seen or {}
    if not meta or seen[meta] then
      return false
    end
    seen[meta] = true

    -- Check direct match
    if meta == target_class then
      return true
    end

    -- Check __index (for inheritance via __index)
    if type(meta.__index) == "table" then
      if meta.__index == target_class then
        return true
      end
      if check_inheritance_chain(meta.__index, target_class, seen) then
        return true
      end
    end

    -- Check parent metatable (for meta-inheritance)
    local parent_mt = getmetatable(meta)
    if parent_mt then
      if parent_mt == target_class then
        return true
      end
      if check_inheritance_chain(parent_mt, target_class, seen) then
        return true
      end
    end

    return false
  end

  -- Check all inheritance paths
  if check_inheritance_chain(mt, class) then
    return true
  end

  -- If we got here, the object is not an instance of the class
  local class_name = class.__name or tostring(class)
  local object_class = mt.__name or tostring(mt)
  local default_message =
    string.format("Expected object to be an instance of %s, but it is an instance of %s", class_name, object_class)

  error(message or default_message, 2)
end

--- Validates that an object implements a specified interface
--- This function checks if an object implements all required methods and properties
--- defined in an interface table. It verifies both the existence of required keys
--- and that their types match the expected types. This is useful for implementing
--- duck typing in Lua with runtime validation.
---
--- @param object table The object to check against the interface
--- @param interface table Table defining the required methods and properties
--- @param message? string Optional custom error message to use if validation fails
--- @return boolean|nil true If implements, nil on error.
--- @return table? error Error object if validation fails.
--- @throws table If object doesn't implement all interface requirements (missing keys or type mismatches).
---
--- @usage
--- -- Define an interface for file-like objects
--- local tc = require("lib.core.type_checking")
--- local FileInterface = {
---   read = function() end,
---   write = function() end,
---   close = function() end,
---   path = ""
--- }
---
--- -- Validate an object against the interface
--- function process_file(file_obj)
---   tc.implements(file_obj, FileInterface, "Invalid file object")
---
---   -- Now safe to use file methods
---   local content = file_obj.read()
---   file_obj.write("new content")
--- end
---
--- -- Check custom objects
--- local my_file = {
---   read = function() return "file content" end,
---   write = function(content) print("Writing: " .. content) end,
---   close = function() print("File closed") end,
---   path = "/path/to/file.txt"
--- }
---
--- tc.implements(my_file, FileInterface) -- returns true
function type_checking.implements(object, interface, message)
  -- Validate arguments
  if type(object) ~= "table" then
    ---@diagnostic disable-next-line: ambiguity-1
    error(message or "Expected object to be a table (got " .. type(object) .. ")", 2)
  end

  if type(interface) ~= "table" then
    ---@diagnostic disable-next-line: ambiguity-1
    error(message or "Expected interface to be a table (got " .. type(interface) .. ")", 2)
  end

  local missing_keys = {}
  local wrong_types = {}

  -- Check all interface requirements
  for key, expected in pairs(interface) do
    local actual = object[key]

    if actual == nil then
      table.insert(missing_keys, key)
    elseif type(expected) ~= type(actual) then
      table.insert(wrong_types, key)
    end
  end

  -- If we found any issues, report them
  if #missing_keys > 0 or #wrong_types > 0 then
    local default_message = "Object does not implement interface: "

    if #missing_keys > 0 then
      default_message = default_message .. "missing: " .. table.concat(missing_keys, ", ")
    end

    if #wrong_types > 0 then
      if #missing_keys > 0 then
        default_message = default_message .. "; "
      end
      default_message = default_message .. "wrong types: " .. table.concat(wrong_types, ", ")
    end

    error(message or default_message, 2)
  end

  return true
end

--- Validates that a container (table or string) contains a specific item
--- This versatile function checks for item containment in both tables and strings.
--- For tables, it checks if the item exists as a value (using value equality).
--- For strings, it checks if the string contains the item as a substring.
--- The function throws an error with a detailed message if the item is not found.
---
--- @param container table|string The container to check (either a table or string)
--- @param item any The item to look for in the container
--- @param message? string Optional custom error message to use if validation fails
--- @return boolean|nil true If contains, nil on error.
--- @return table? error Error object if validation fails.
--- @throws table If `container` doesn't contain `item` or if `container` type is invalid.
---
--- @usage
--- -- Table containment checking
--- local tc = require("lib.core.type_checking")
--- local fruits = {"apple", "banana", "orange"}
--- tc.contains(fruits, "banana") -- returns true
---
--- -- String containment checking
--- local text = "The quick brown fox jumps over the lazy dog"
--- tc.contains(text, "fox") -- returns true
---
--- -- With custom error message
--- function process_config(config, required_setting)
---   tc.contains(config, required_setting,
---     "Configuration is missing required setting: " .. required_setting)
---   -- Process configuration safely...
--- end
---
--- -- Using in validations
--- function validate_permissions(user, required_permission)
---   tc.contains(user.permissions, required_permission,
---     "User lacks required permission: " .. required_permission)
---   return true -- User has permission
--- end
function type_checking.contains(container, item, message)
  -- For tables, check if the item exists as a value
  if type(container) == "table" then
    for _, value in pairs(container) do
      if value == item then
        return true
      end
    end

    -- If we got here, the item wasn't found
    local default_message = string.format("Expected table to contain %s", tostring(item))
    error(message or default_message, 2)

  -- For strings, check substring containment
  elseif type(container) == "string" then
    -- Convert item to string if needed
    local item_str = tostring(item)

    if not string.find(container, item_str, 1, true) then
      local default_message = string.format("Expected string '%s' to contain '%s'", container, item_str)
      error(message or default_message, 2)
    end

    return true
  else
    error("Cannot check containment in a " .. type(container), 2)
  end
end

--- Validates that a function throws an error when called
--- This function is used for testing error conditions. It executes the provided function
--- within a protected call (pcall) and verifies that it throws an error. If the function
--- executes without throwing an error, has_error will throw its own error. This is
--- particularly useful for validating error handling in test suites.
---
--- @param fn function The function to test (should throw an error when called)
--- @param message? string Optional custom error message if function doesn't throw
--- @return any|nil captured_error The error value thrown by `fn`, or `nil` if no error was thrown or validation failed.
--- @return table? error Error object if validation fails (e.g., `fn` not a function) or if `fn` didn't throw an error when expected.
--- @throws table If `fn` is not a function or if `fn` doesn't throw an error when executed.
---
--- @usage
--- -- Basic error checking
--- local tc = require("lib.core.type_checking")
--- local function divide(a, b)
---   if b == 0 then error("Division by zero") end
---   return a / b
--- end
---
--- -- Test that divide throws on division by zero
--- local err = tc.has_error(function() divide(10, 0) end)
--- print("Got expected error: " .. err) -- prints "Got expected error: Division by zero"
---
--- -- With custom error message
--- function test_validation_error()
---   local err = tc.has_error(
---     function() validate_email("not-an-email") end,
---     "Email validation should fail for invalid inputs"
---   )
---   -- Now we can make assertions about the error
---   assert(err:match("Invalid email format"))
--- end
---
--- -- In combination with other type checks
--- function test_safe_calculation()
---   -- Should not throw for valid input
---   local result = calculate_area(10, 20)
---   assert(result == 200)
---
---   -- Should throw for invalid input
---   tc.has_error(function() calculate_area(-5, 10) end)
--- end
function type_checking.has_error(fn, message)
  if type(fn) ~= "function" then
    error("Expected a function to test for errors", 2)
  end

  local ok, err = pcall(fn)

  if ok then
    error(message or "Expected function to throw an error, but it did not", 2)
  end

  return err
end

return type_checking
