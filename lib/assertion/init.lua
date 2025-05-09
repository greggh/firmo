---@class AssertionModule The public API of the assertion module.
---@field eq fun(t1: any, t2: any, eps?: number, visited?: table): boolean Performs a deep equality check between two values, handling cycles and optional epsilon for numbers.
---@field isa fun(v: any, x: string|table): boolean, string, string Checks if value `v` is of type `x` (string) or inherits from class/metatable `x` (table). Returns success, success message, failure message.
---@field expect fun(v: any): ExpectChain Creates an assertion chain (`ExpectChain`) for the given value `v`. This is the main entry point for expect-style assertions.
---@field paths table The internal table defining assertion chains and their test functions. Exposed primarily for potential extension or inspection (use with caution).
---@field assertion_count number A counter incremented each time `expect()` is called. Used for test quality metrics.

--- Assertion Module for the Firmo testing framework
---
--- This module provides the core assertion logic for Firmo, focusing on the `expect()`
--- style chainable API. It is designed to be relatively standalone to avoid circular
--- dependencies with other core modules like logging or error handling, using lazy-loading
--- where necessary.
---
--- Features:
--- - Fluent, chainable assertion API via `expect(value)`.
--- - Deep equality comparison (`eq`) with cycle detection.
--- - Type checking (`isa`) including metatable/class checks.
--- - Detailed stringification (`stringify`) and diffing (`diff_values`) for error messages.
--- - Negation via `.to_not` chain.
--- - Integration with coverage system to mark asserted lines as 'covered'.
--- - Lazy-loading of dependencies like error_handler and logging.
---
--- @module lib.assertion
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

local M = {}

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack = table.unpack or _G.unpack

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging, _firmo, _coverage, _date, _quality_module

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the error handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

--- Get the logging module with lazy loading to avoid circular dependencies
---@return table|nil The logging module or nil if not available
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end

--- Get a logger instance for this module
---@return table A logger instance (either real or stub)
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("assertion")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

local function get_date()
  if not _date then
    _date = try_require("lib.tools.date")
  end
  return _date
end

--- Get the coverage module with lazy loading to avoid circular dependencies
---@return table|nil The coverage module or nil if not available
local function get_coverage()
  if not _coverage then
    _coverage = try_require("lib.coverage")
  end
  return _coverage
end

--- Get the quality module with lazy loading
---@return table|nil The quality module or nil if not available
local function get_quality_module()
  if not _quality_module then
    _quality_module = try_require("lib.quality")
  end
  return _quality_module
end

-- Utility functions

--- Checks if a table contains a specific value among its values.
--- Performs a simple linear search using `pairs`.
---@param t table|nil The table to search in. Handles `nil` input gracefully.
---@param x any The value to search for using direct equality (`==`).
---@return boolean `true` if the value `x` is found among the values of `t`, `false` otherwise.
---@private
local function has(t, x)
  if not t then
    return false
  end
  if type(t) ~= "table" then
    return false
  end
  for _, v in pairs(t) do
    if v == x then
      return true
    end
  end
  return false
end

--- Enhanced stringify function with better formatting for different types
--- and protection against cyclic references
--- Converts any Lua value into a readable string representation.
--- Handles tables recursively with indentation and cycle detection.
--- Uses custom formatting for strings (quotes) and attempts `__tostring` metamethods.
---@param t any The value to convert to a string.
---@param depth? number Internal recursion depth tracker (default 0).
---@param visited? table Internal table to track visited tables for cycle detection.
---@return string A string representation of the value `t`.
---@private
local function stringify(t, depth, visited)
  depth = depth or 0
  visited = visited or {}
  local indent_str = string.rep("  ", depth)

  -- Handle basic types directly
  if type(t) == "string" then
    return "'" .. tostring(t) .. "'"
  elseif type(t) == "number" or type(t) == "boolean" or type(t) == "nil" then
    return tostring(t)
  elseif type(t) ~= "table" then -- Handle other non-tables (functions, userdata)
    return tostring(t)
  elseif getmetatable(t) and getmetatable(t).__tostring then -- Handle tables with __tostring
    local success, result = pcall(tostring, t)
    if success then
      return result
    else
      -- Fallback if __tostring errors, try basic table representation
      local result_str
      if type(result) == "string" then
        result_str = result
      elseif type(result) == "table" and result.message and type(result.message) == "string" then
        result_str = result.message -- Common for error objects
      else
        result_str = "unstringifiable error object"
      end
      return "table: (error in __tostring: " .. result_str .. ")"
    end
  end
  -- If it's a table without __tostring, it will proceed to detailed table formatting.

  -- Handle cyclic references
  if visited[t] then
    return "[Circular Reference]"
  end

  -- Mark this table as visited
  visited[t] = true

  -- Handle empty tables
  if next(t) == nil then
    return "{}"
  end

  -- Handle tables with careful formatting
  local strings = {}
  local multiline = false

  -- Format array part first
  ---@diagnostic disable-next-line: unused-local
  for i, v in ipairs(t) do
    if type(v) == "table" and next(v) ~= nil and depth < 2 then
      multiline = true
      strings[#strings + 1] = indent_str .. "  " .. stringify(v, depth + 1, visited)
    else
      strings[#strings + 1] = stringify(v, depth + 1, visited)
    end
  end

  -- Format hash part next
  local hash_entries = {}
  for k, v in pairs(t) do
    if type(k) ~= "number" or k > #t or k < 1 then
      local key_str = type(k) == "string" and k or "[" .. stringify(k, depth + 1, visited) .. "]"

      if type(v) == "table" and next(v) ~= nil and depth < 2 then
        multiline = true
        hash_entries[#hash_entries + 1] = indent_str .. "  " .. key_str .. " = " .. stringify(v, depth + 1, visited)
      else
        hash_entries[#hash_entries + 1] = key_str .. " = " .. stringify(v, depth + 1, visited)
      end
    end
  end

  -- Combine array and hash parts
  for _, entry in ipairs(hash_entries) do
    strings[#strings + 1] = entry
  end

  -- Format based on content complexity
  if multiline and depth == 0 then
    return "{\n  " .. table.concat(strings, ",\n  ") .. "\n" .. indent_str .. "}"
  elseif #strings > 5 or multiline then
    return "{ " .. table.concat(strings, ", ") .. " }"
  else
    return "{ " .. table.concat(strings, ", ") .. " }"
  end
end

--- Generate a simple diff between two values
--- Generates a simple human-readable diff string between two values.
--- Primarily intended for showing differences between tables in assertion failure messages.
--- Uses `stringify` for representing values.
---@param v1 any The first value (typically the actual value).
---@param v2 any The second value (typically the expected value).
---@return string A string describing the differences, or a fallback message if no specific difference is found but `M.eq` returned false.
---@private
local function diff_values(v1, v2)
  -- Create a shared visited table for cyclic reference detection within stringify
  local visited = {}

  -- If types differ, show simple comparison

  if type(v1) ~= "table" or type(v2) ~= "table" then
    return "Expected: " .. stringify(v2, 0, visited) .. "\nGot:      " .. stringify(v1, 0, visited)
  end

  local differences = {}

  -- Check for missing keys in v1
  for k, v in pairs(v2) do
    if v1[k] == nil then
      table.insert(
        differences,
        "Different value for key "
          .. stringify(k, 0, visited)
          .. ": expected "
          .. stringify(v, 0, visited)
          .. ", got "
          .. stringify(v1[k], 0, visited)
      )
    elseif not M.eq(v1[k], v, 0) then
      table.insert(
        differences,
        "Different value for key "
          .. stringify(k, 0, visited)
          .. ": expected "
          .. stringify(v, 0, visited)
          .. ", got "
          .. stringify(v1[k], 0, visited)
      )
    end
  end

  if #differences > 0 then
    return "Differences:\n  " .. table.concat(differences, "\n  ")
  end

  return "Values appear equal but are not identical (may be due to metatable differences)"
end

--- Deep equality check function with cycle detection
---@param t1 any First value to compare
---@param t2 any Second value to compare
---@param eps? number Epsilon tolerance for floating-point number comparison (default 0).
---@param visited? table Internal table to track visited table pairs for cycle detection during recursion.
---@return boolean `true` if `t1` and `t2` are considered deeply equal, `false` otherwise.
function M.eq(t1, t2, eps, visited)
  -- Initialize visited table on the initial call
  visited = visited or {}

  -- Direct reference equality check for identical tables
  if t1 == t2 then
    return true
  end

  -- Create a unique key for this comparison pair to detect cycles
  local pair_key
  if type(t1) == "table" and type(t2) == "table" then
    -- Create a string that uniquely identifies this pair
    pair_key = tostring(t1) .. ":" .. tostring(t2)

    -- If we've seen this pair before, we're in a cycle
    if visited[pair_key] then
      return true -- Assume equality for cyclic structures
    end

    -- Mark this pair as visited
    visited[pair_key] = true
  end

  -- Special case for strings and numbers
  if (type(t1) == "string" and type(t2) == "number") or (type(t1) == "number" and type(t2) == "string") then
    -- Try string comparison
    if tostring(t1) == tostring(t2) then
      return true
    end

    -- Try number comparison if possible
    local n1 = type(t1) == "string" and tonumber(t1) or t1
    local n2 = type(t2) == "string" and tonumber(t2) or t2

    if type(n1) == "number" and type(n2) == "number" then
      local ok, result = pcall(function()
        return math.abs(n1 - n2) <= (eps or 0)
      end)
      if ok then
        return result
      end
    end

    return false
  end

  -- If types are different, return false
  if type(t1) ~= type(t2) then
    return false
  end

  -- For numbers, do epsilon comparison
  if type(t1) == "number" then
    local ok, result = pcall(function()
      return math.abs(t1 - t2) <= (eps or 0)
    end)

    -- If comparison failed (e.g., NaN), fall back to direct equality
    if not ok then
      return t1 == t2
    end

    return result
  end

  -- For non-tables, simple equality
  if type(t1) ~= "table" then
    return t1 == t2
  end

  -- For tables, recursive equality check
  for k, v in pairs(t1) do
    if not M.eq(v, t2[k], eps, visited) then
      return false
    end
  end

  ---@diagnostic disable-next-line: unused-local
  for k, v in pairs(t2) do
    if t1[k] == nil then
      return false
    end
  end

  return true
end

--- Type checking function that checks if a value is of a specific type
--- Checks if a value `v` is of a specific type or class `x`.
--- If `x` is a string, it checks `type(v) == x`.
--- If `x` is a table, it checks if `v`'s metatable chain includes `x`.
---@param v any The value to check.
---@param x string|table The expected type name (string) or class/metatable (table).
---@return boolean success True if the check passes, false otherwise.
---@return string success_message Message template for a successful assertion (e.g., "expected {v} to be a {x}").
---@return string failure_message Message template for a failed assertion (e.g., "expected {v} to not be a {x}").
---@throws string If `x` is not a string or table.
function M.isa(v, x)
  if type(x) == "string" then
    local success = type(v) == x
    return success, "expected " .. tostring(v) .. " to be a " .. x, "expected " .. tostring(v) .. " to not be a " .. x
  elseif type(x) == "table" then
    if type(v) ~= "table" then
      return false,
        "expected " .. tostring(v) .. " to be a " .. tostring(x),
        "expected " .. tostring(v) .. " to not be a " .. tostring(x)
    end

    local seen = {}
    local meta = v
    while meta and not seen[meta] do
      if meta == x then
        return true
      end
      seen[meta] = true
      meta = getmetatable(meta) and getmetatable(meta).__index
    end

    return false,
      "expected " .. tostring(v) .. " to be a " .. tostring(x),
      "expected " .. tostring(v) .. " to not be a " .. tostring(x)
  end

  error("invalid type " .. tostring(x))
end

-- ==========================================
-- Assertion Path Definitions
-- ==========================================

--- Define all the assertion paths
--- These form the chain of methods that can be called on the expect() assertion object
--- @type table<string, table|function> Table of assertion paths and their test functions
local paths = {
  [""] = { "to", "to_not" },
  to = {
    "have",
    "equal",
    "be",
    "exist",
    "fail",
    "match",
    "contain",
    "start_with",
    "end_with",
    "be_type",
    "be_greater_than",
    "be_less_than",
    "be_between",
    "be_near", -- Added
    "be_approximately", -- Alias for be_near
    "throw",
    "satisfy",
    "implement_interface",
    "be_truthy",
    "be_falsy",
    "be_falsey",
    "is_exact_type",
    "is_instance_of",
    "implements",
    "have_length",
    "have_size",
    "have_property",
    "match_schema",
    "change",
    "increase",
    "decrease",
    "deep_equal",
    "match_regex",
    "match_with_options", -- Added
    "be_date",
    "be_iso_date",
    "be_before",
    "be_after",
    "be_same_day_as",
    "be_between_dates", -- Added
    "complete",
    "complete_within",
    "resolve_with",
    "reject",
    "be_nil",
  },
  to_not = {
    "have",
    "equal",
    "be",
    "exist",
    "fail",
    "match",
    "contain",
    "start_with",
    "end_with",
    "be_type",
    "be_greater_than",
    "be_less_than",
    "be_between",
    "be_near", -- Added
    "be_approximately", -- Alias for be_near
    "throw",
    "satisfy",
    "implement_interface",
    "be_truthy",
    "be_falsy",
    "be_falsey",
    "is_exact_type",
    "is_instance_of",
    "implements",
    "have_length",
    "have_size",
    "have_property",
    "match_schema",
    "change",
    "increase",
    "decrease",
    "deep_equal",
    "match_regex",
    "match_with_options", -- Added
    "be_date",
    "be_iso_date",
    "be_before",
    "be_after",
    "be_same_day_as",
    "be_between_dates", -- Added
    "complete",
    "complete_within",
    "be_nil",
    chain = function(a)
      -- Set negation state to true
      -- This explicitly sets the negation state rather than toggling it
      rawset(a, "negate", true)

      -- Return the assertion object to enable chaining
      return a
    end,
  },
  --- Alias for `isa`. Checks type or class inheritance.
  ---@field test fun(v: any, x: string|table): boolean, string, string The `M.isa` function.
  a = { test = M.isa },
  --- Alias for `isa`. Checks type or class inheritance.
  ---@field test fun(v: any, x: string|table): boolean, string, string The `M.isa` function.
  an = { test = M.isa },
  --- Tests if a value is "falsey" (evaluates to `false` or `nil` in a conditional).
  ---@field test fun(v: any): boolean, string, string
  falsey = {
    ---@param v any The value to check.
    ---@return boolean success True if `v` is `false` or `nil`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v)
      return not v, "expected " .. tostring(v) .. " to be falsey", "expected " .. tostring(v) .. " to not be falsey"
    end,
  },
  --- Chain link for various `be.*` assertions. Also performs direct equality check if called.
  ---@field test fun(v: any, x: any): boolean, string, string Performs `v == x` check.
  be = {
    "a",
    "an",
    "truthy",
    "falsy",
    "falsey",
    "nil",
    "type",
    "at_least",
    "greater_than",
    "less_than",
    "empty",
    "positive",
    "negative",
    "integer",
    "uppercase",
    "lowercase",
    "lowercase",
    --- Performs a direct equality check (`v == x`).
    ---@param v any The actual value.
    ---@param x any The expected value.
    ---@return boolean success True if `v == x`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v, x)
      return v == x,
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to be the same",
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to not be the same"
    end,
  },

  --- Tests if a number `v` is greater than or equal to `x`.
  ---@field test fun(v: number, x: number): boolean, string, string
  at_least = {
    ---@param v number The actual number.
    ---@param x number The threshold number.
    ---@return boolean success True if `v >= x`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    ---@throws string If `v` or `x` are not numbers.
    test = function(v, x)
      if type(v) ~= "number" or type(x) ~= "number" then
        error("expected both values to be numbers for at_least comparison")
      end
      return v >= x,
        "expected " .. tostring(v) .. " to be at least " .. tostring(x),
        "expected " .. tostring(v) .. " to not be at least " .. tostring(x)
    end,
  },

  --- Tests if a number `v` is strictly greater than `x`.
  ---@field test fun(v: number, x: number): boolean, string, string
  greater_than = {
    ---@param v number The actual number.
    ---@param x number The threshold number.
    ---@return boolean success True if `v > x`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    ---@throws string If `v` or `x` are not numbers.
    test = function(v, x)
      if type(v) ~= "number" or type(x) ~= "number" then
        error("expected both values to be numbers for greater_than comparison")
      end
      return v > x,
        "expected " .. tostring(v) .. " to be greater than " .. tostring(x),
        "expected " .. tostring(v) .. " to not be greater than " .. tostring(x)
    end,
  },

  --- Tests if a number `v` is strictly less than `x`.
  ---@field test fun(v: number, x: number): boolean, string, string
  less_than = {
    ---@param v number The actual number.
    ---@param x number The threshold number.
    ---@return boolean success True if `v < x`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    ---@throws string If `v` or `x` are not numbers.
    test = function(v, x)
      if type(v) ~= "number" or type(x) ~= "number" then
        error("expected both values to be numbers for less_than comparison")
      end
      return v < x,
        "expected " .. tostring(v) .. " to be less than " .. tostring(x),
        "expected " .. tostring(v) .. " to not be less than " .. tostring(x)
    end,
  },
  --- Test if a value exists (is not nil)
  --- Tests if a value exists (is not `nil`).
  ---@field test fun(v: any): boolean, string, string
  exist = {
    ---@param v any The value to check.
    ---@return boolean success True if `v` is not `nil`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v)
      return v ~= nil, "expected value to exist", "expected value to not exist"
    end,
  },

  --- Tests if a value is "truthy" (evaluates to true in a conditional, i.e., not `false` or `nil`).
  ---@field test fun(v: any): boolean, string, string
  truthy = {
    ---@param v any The value to check.
    ---@return boolean success True if `v` is neither `false` nor `nil`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v)
      return v and true or false, -- Explicitly return boolean true/false
        "expected " .. tostring(v) .. " to be truthy",
        "expected " .. tostring(v) .. " to not be truthy"
    end,
  },

  --- Tests if a value is "falsy" (evaluates to `false` or `nil` in a conditional).
  --- Note: This is duplicated by the `falsey` entry; consider standardizing.
  ---@field test fun(v: any): boolean, string, string
  falsy = {
    ---@param v any The value to check.
    ---@return boolean success True if `v` is `false` or `nil`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v)
      return not v and true or false, -- Explicitly return boolean true/false
        "expected " .. tostring(v) .. " to be falsy",
        "expected " .. tostring(v) .. " to not be falsy"
    end,
  },

  --- Tests if a value is exactly `nil`.
  ---@field test fun(v: any): boolean, string, string
  ["nil"] = { -- Using string key because 'nil' is a keyword
    ---@param v any The value to check.
    ---@return boolean success True if `v == nil`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v)
      return v == nil,
        "expected " .. stringify(v, 0, {}) .. " to be nil",
        "expected " .. stringify(v, 0, {}) .. " to not be nil"
    end,
  },

  --- Tests if value `v` is exactly `nil`.
  ---@field test fun(v: any): boolean, string, string
  be_nil = {
    ---@param v any The value to check.
    ---@return boolean success True if `v == nil`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v)
      return v == nil,
        "expected " .. stringify(v, 0, {}) .. " to be nil",
        "expected " .. stringify(v, 0, {}) .. " to not be nil"
    end,
  },

  --- Tests if a value is of a specific Lua base type using `type()`.
  ---@field test fun(v: any, expected_type: string): boolean, string, string
  type = {
    ---@param v any The value to check.
    ---@param expected_type string The expected type name (e.g., "string", "number", "table").
    ---@return boolean success True if `type(v) == expected_type`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v, expected_type)
      return type(v) == expected_type,
        "expected " .. tostring(v) .. " to be of type " .. expected_type .. ", got " .. type(v),
        "expected " .. tostring(v) .. " to not be of type " .. expected_type
    end,
  },
  --- Tests if two values are deeply equal using `M.eq`. Provides a diff in the failure message.
  ---@field test fun(v: any, x: any, eps?: number): boolean, string, string
  equal = {
    ---@param v any The actual value.
    ---@param x any The expected value.
    ---@param eps? number Optional epsilon for floating-point comparisons within `M.eq`.
    ---@return boolean success True if `M.eq(v, x, eps)` returns true.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure, potentially including a diff.
    test = function(v, x, eps)
      local equal = M.eq(v, x, eps)
      local comparison = ""

      if not equal then
        if type(v) == "table" or type(x) == "table" then
          -- For tables, generate a detailed diff
          comparison = "\n" .. diff_values(v, x)
        else
          -- For primitive types, show a simple comparison
          comparison = "\n" .. "Expected: " .. stringify(x) .. "\n" .. "Got:      " .. stringify(v)
        end
      end

      return equal,
        "expected " .. stringify(v) .. " to equal " .. stringify(x) .. comparison,
        "expected " .. stringify(v) .. " to not equal " .. stringify(x)
    end,
  },
  --- Tests if a table `v` contains the value `x` among its values (uses `has` helper).
  ---@field test fun(v: table, x: any): boolean, string, string
  have = {
    ---@param v table The table to check.
    ---@param x any The value to look for.
    ---@return boolean success True if `v` contains `x`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    ---@throws string If `v` is not a table.
    test = function(v, x)
      if type(v) ~= "table" then
        error("expected " .. stringify(v) .. " to be a table")
      end

      -- Create a formatted table representation for better error messages
      local table_str = stringify(v)
      local content_preview = #table_str > 70 and table_str:sub(1, 67) .. "..." or table_str

      return has(v, x),
        "expected table to contain " .. stringify(x) .. "\nTable contents: " .. content_preview,
        "expected table not to contain " .. stringify(x) .. " but it was found\nTable contents: " .. content_preview
    end,
  },

  --- Tests if calling function `v` results in an error (using `pcall`).
  ---@field test fun(v: function): boolean, string, string
  fail = {
    "with",
    ---@param v function The function to call.
    ---@return boolean success True if `pcall(v)` returns `false`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v)
      return not pcall(v), "expected " .. tostring(v) .. " to fail", "expected " .. tostring(v) .. " to not fail"
    end,
  },
  --- Tests if calling function `v` results in an error whose message matches `pattern`. Used after `.fail`.
  ---@field test fun(v: function, pattern: string): boolean, string, string
  with = {
    ---@param v function The function to call.
    ---@param pattern string The Lua pattern to match against the error message.
    ---@return boolean success True if `pcall(v)` returns `false` and the error message matches `pattern`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v, pattern)
      local ok, message = pcall(v)
      -- Ensure message is a string before matching
      if type(message) == "table" then
        message = message.message or message[1] or message[2] or message[3] or message[4]
      end
      if type(message) ~= "string" then
        message = tostring(message)
      end

      return not ok and message:match(pattern),
        "expected " .. tostring(v) .. ' to fail with error matching "' .. pattern .. '"',
        "expected " .. tostring(v) .. ' to not fail with error matching "' .. pattern .. '"'
    end,
  },
  --- Tests if a string `v` contains a match for the Lua pattern `p`.
  ---@field test fun(v: any, p: string): boolean, string, string
  match = {
    "fully", -- marker for match.fully chain
    "any_of", -- marker for match.any_of chain
    "all_of", -- marker for match.all_of chain

    ---@param v any The value to check (will be converted to string).
    ---@param p string The Lua pattern.
    ---@return boolean success True if `tostring(v)` contains a match for `p`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v, p)
      local v_str
      if type(v) ~= "string" then
        local s, r = pcall(tostring, v) -- Safely convert v to string
        if not s then
          v_str = "<unstringifiable_value>"
        else
          v_str = r
        end
      else
        v_str = v
      end
      local result = string.find(v_str, p) ~= nil
      local display_v = stringify(v, 0, {}) -- Use stringify for messages
      return result,
        'expected "' .. display_v .. '" to match pattern "' .. p .. '"',
        'expected "' .. display_v .. '" to not match pattern "' .. p .. '"'
    end,
  },

  -- Interface implementation checking
  implement_interface = {
    test = function(v, interface)
      if type(v) ~= "table" then
        return false, "expected " .. tostring(v) .. " to be a table", nil
      end

      if type(interface) ~= "table" then
        return false, "expected interface to be a table", nil
      end

      local missing_keys = {}
      local wrong_types = {}

      for key, expected in pairs(interface) do
        local actual = v[key]

        if actual == nil then
          table.insert(missing_keys, key)
        elseif type(expected) == "function" and type(actual) ~= "function" then
          table.insert(wrong_types, key .. " (expected function, got " .. type(actual) .. ")")
        end
      end

      if #missing_keys > 0 or #wrong_types > 0 then
        local msg = "expected object to implement interface, but: "
        if #missing_keys > 0 then
          msg = msg .. "missing: " .. table.concat(missing_keys, ", ")
        end
        if #wrong_types > 0 then
          if #missing_keys > 0 then
            msg = msg .. "; "
          end
          msg = msg .. "wrong types: " .. table.concat(wrong_types, ", ")
        end

        return false, msg, "expected object not to implement interface"
      end

      return true, "expected object to implement interface", "expected object not to implement interface"
    end,
  },

  -- Table inspection assertions
  contain = {
    "keys",
    "values",
    "key",
    "value",
    "subset",
    "exactly",
    "deep_key", -- Added
    "exact_keys", -- Added
    test = function(v, x)
      -- Simple implementation first
      if type(v) == "string" then
        -- Handle string containment
        local x_str = tostring(x)
        return string.find(v, x_str, 1, true) ~= nil,
          'expected string "' .. v .. '" to contain "' .. x_str .. '"',
          'expected string "' .. v .. '" to not contain "' .. x_str .. '"'
      elseif type(v) == "table" then
        -- Handle table containment
        return has(v, x),
          "expected " .. tostring(v) .. " to contain " .. tostring(x),
          "expected " .. tostring(v) .. " to not contain " .. tostring(x)
      else
        -- Error for unsupported types
        error("cannot check containment in a " .. type(v))
      end
    end,
  },

  -- Length assertion for strings and tables
  have_length = {
    test = function(v, expected_length)
      local length
      if type(v) == "string" then
        length = string.len(v)
      elseif type(v) == "table" then
        length = #v
      else
        error("expected a string or table for length check, got " .. type(v))
      end

      return length == expected_length,
        "expected " .. stringify(v) .. " to have length " .. tostring(expected_length) .. ", got " .. tostring(length),
        "expected " .. stringify(v) .. " to not have length " .. tostring(expected_length)
    end,
  },

  -- Alias for have_length
  --- Alias for `have_length`. Tests string/table size.
  ---@field test fun(v: string|table, expected_size: number): boolean, string, string
  have_size = {
    ---@param v string|table The value to check the size of.
    ---@param expected_size number The expected size/length.
    ---@return boolean success True if the size matches.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    ---@throws string If `v` is not a string or table, or if `expected_size` is not a number.
    test = function(v, expected_size)
      if type(expected_size) ~= "number" then
        error("expected size must be a number", 2)
      end
      local length
      if type(v) == "string" then
        length = string.len(v)
      elseif type(v) == "table" then
        length = #v
      else
        error("expected a string or table for size check, got " .. type(v))
      end

      return length == expected_size,
        "expected " .. stringify(v) .. " to have size " .. tostring(expected_size) .. ", got " .. tostring(length),
        "expected " .. stringify(v) .. " to not have size " .. tostring(expected_size)
    end,
  },

  -- Property existence and value checking
  --- Tests if a table `v` has a property `property_name`. Optionally checks if the property's value equals `expected_value` using `M.eq`.
  ---@field test fun(v: table, property_name: any, expected_value?: any): boolean, string, string
  have_property = {
    ---@param v table The table to check.
    ---@param property_name any The key of the property to check for.
    ---@param expected_value? any If provided, the value the property should have (checked using `M.eq`).
    ---@return boolean success True if the property exists and (optionally) has the expected value.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    ---@throws string If `v` is not a table.
    test = function(v, property_name, expected_value)
      if type(v) ~= "table" then
        error("expected a table for property check, got " .. type(v))
      end

      local has_property = v[property_name] ~= nil

      -- If we're just checking for property existence
      if expected_value == nil then
        return has_property,
          "expected " .. stringify(v) .. " to have property " .. tostring(property_name),
          "expected " .. stringify(v) .. " to not have property " .. tostring(property_name)
      end

      -- If we're checking for property value
      local property_matches = has_property and M.eq(v[property_name], expected_value)

      return property_matches,
        "expected " .. stringify(v) .. " to have property " .. tostring(property_name) .. " with value " .. stringify(
          expected_value
        ) .. ", got " .. (has_property and stringify(v[property_name]) or "undefined"),
        "expected "
          .. stringify(v)
          .. " to not have property "
          .. tostring(property_name)
          .. " with value "
          .. stringify(expected_value)
    end,
  },

  -- Schema validation
  --- Tests if a table `v` matches a given `schema`. Checks for key presence, type matching, and optional exact value matching.
  ---@field test fun(v: table, schema: table): boolean, string, string
  match_schema = {
    ---@param v table The table to validate.
    ---@param schema table The schema definition. Keys are property names. Values can be type strings ("string", "number", etc.) or exact values to match against.
    ---@return boolean success True if `v` matches the `schema`.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure, detailing mismatches.
    ---@throws string If `v` or `schema` are not tables.
    test = function(v, schema)
      if type(v) ~= "table" then
        error("expected a table for schema validation, got " .. type(v))
      end

      if type(schema) ~= "table" then
        error("expected a table schema, got " .. type(schema))
      end

      local missing_props = {}
      local type_mismatches = {}
      local value_mismatches = {}

      for prop_name, prop_def in pairs(schema) do
        -- Handle missing properties first
        if v[prop_name] == nil then
          table.insert(missing_props, prop_name)
        -- Handle type check schema (e.g., {name = "string"})
        elseif
          type(prop_def) == "string"
          and prop_def:match("^[a-z]+$")
          and (
            prop_def == "string"
            or prop_def == "number"
            or prop_def == "boolean"
            or prop_def == "table"
            or prop_def == "function"
            or prop_def == "thread"
            or prop_def == "userdata"
            or prop_def == "nil"
          )
        then
          if type(v[prop_name]) ~= prop_def then
            table.insert(
              type_mismatches,
              prop_name .. " (expected " .. prop_def .. ", got " .. type(v[prop_name]) .. ")"
            )
          end
        -- Handle exact value schema (e.g., {status = "active"})
        elseif prop_def ~= nil then
          if not M.eq(v[prop_name], prop_def) then
            table.insert(
              value_mismatches,
              prop_name .. " (expected " .. stringify(prop_def) .. ", got " .. stringify(v[prop_name]) .. ")"
            )
          end
        end
      end

      local valid = #missing_props == 0 and #type_mismatches == 0 and #value_mismatches == 0

      local error_msg = "expected object to match schema, but:\n"
      if #missing_props > 0 then
        error_msg = error_msg .. "  Missing properties: " .. table.concat(missing_props, ", ") .. "\n"
      end
      if #type_mismatches > 0 then
        error_msg = error_msg .. "  Type mismatches: " .. table.concat(type_mismatches, ", ") .. "\n"
      end
      if #value_mismatches > 0 then
        error_msg = error_msg .. "  Value mismatches: " .. table.concat(value_mismatches, ", ") .. "\n"
      end

      return valid, error_msg, "expected object to not match schema"
    end,
  },

  -- Function behavior assertions
  --- Tests if executing function `fn` causes a change in the value returned by `value_fn`. Optionally uses `change_fn` to define the criteria for change.
  ---@field test fun(fn: function, value_fn: function, change_fn?: fun(before: any, after: any): boolean): boolean, string, string
  change = {
    ---@param fn function The function to execute that might cause a change.
    ---@param value_fn function A function that returns the value to monitor for changes. Called before and after `fn`.
    ---@param change_fn? fun(before: any, after: any): boolean Optional function to determine if a change occurred. Defaults to `not M.eq(before, after)`.
    ---@return boolean success True if the value changed according to the criteria.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    ---@throws string If `fn` or `value_fn` are not functions, or if `fn` throws an error.
    test = function(fn, value_fn, change_fn)
      if type(fn) ~= "function" then
        error("expected a function to execute, got " .. type(fn))
      end

      if type(value_fn) ~= "function" then
        error("expected a function that returns value to check, got " .. type(value_fn))
      end

      local before_value = value_fn()
      local success, result = pcall(fn)

      if not success then
        error("function being tested threw an error: " .. tostring(result))
      end

      local after_value = value_fn()

      -- If a specific change function was provided, use it
      if change_fn and type(change_fn) == "function" then
        local changed = change_fn(before_value, after_value)
        return changed,
          "expected function to change value according to criteria, but it didn't",
          "expected function to not change value according to criteria, but it did"
      end

      -- Otherwise just check for any change
      local changed = not M.eq(before_value, after_value)

      return changed,
        "expected function to change value (before: " .. stringify(before_value) .. ", after: " .. stringify(
          after_value
        ) .. ")",
        "expected function to not change value, but it did change from "
          .. stringify(before_value)
          .. " to "
          .. stringify(after_value)
    end,
  },

  -- Check if a function increases a value
  --- Tests if executing function `fn` increases the numerical value returned by `value_fn`.
  ---@field test fun(fn: function, value_fn: function): boolean, string, string
  increase = {
    ---@param fn function The function to execute.
    ---@param value_fn function Function returning the numerical value to check. Called before and after `fn`.
    ---@return boolean success True if the value returned by `value_fn` increased after `fn` executed.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    ---@throws string If `fn` or `value_fn` are not functions, if `value_fn` does not return a number, or if `fn` throws an error.
    test = function(fn, value_fn)
      if type(fn) ~= "function" then
        error("expected a function to execute, got " .. type(fn))
      end

      if type(value_fn) ~= "function" then
        error("expected a function that returns value to check, got " .. type(value_fn))
      end

      local before_value = value_fn()

      -- Validate that the before value is numeric
      if type(before_value) ~= "number" then
        error("expected value_fn to return a number, got " .. type(before_value))
      end

      local success, result = pcall(fn)

      if not success then
        error("function being tested threw an error: " .. tostring(result))
      end

      local after_value = value_fn()

      -- Validate that the after value is numeric
      if type(after_value) ~= "number" then
        error("expected value_fn to return a number after function call, got " .. type(after_value))
      end

      local increased = after_value > before_value

      return increased,
        "expected function to increase value from " .. tostring(before_value) .. " but got " .. tostring(after_value),
        "expected function to not increase value from "
          .. tostring(before_value)
          .. " but it did increase to "
          .. tostring(after_value)
    end,
  },

  -- Check if a function decreases a value
  --- Tests if executing function `fn` decreases the numerical value returned by `value_fn`.
  ---@field test fun(fn: function, value_fn: function): boolean, string, string
  decrease = {
    ---@param fn function The function to execute.
    ---@param value_fn function Function returning the numerical value to check. Called before and after `fn`.
    ---@return boolean success True if the value returned by `value_fn` decreased after `fn` executed.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    ---@throws string If `fn` or `value_fn` are not functions, if `value_fn` does not return a number, or if `fn` throws an error.
    test = function(fn, value_fn)
      if type(fn) ~= "function" then
        error("expected a function to execute, got " .. type(fn))
      end

      if type(value_fn) ~= "function" then
        error("expected a function that returns value to check, got " .. type(value_fn))
      end

      local before_value = value_fn()

      -- Validate that the before value is numeric
      if type(before_value) ~= "number" then
        error("expected value_fn to return a number, got " .. type(before_value))
      end

      local success, result = pcall(fn)

      if not success then
        error("function being tested threw an error: " .. tostring(result))
      end

      local after_value = value_fn()

      -- Validate that the after value is numeric
      if type(after_value) ~= "number" then
        error("expected value_fn to return a number after function call, got " .. type(after_value))
      end

      local decreased = after_value < before_value

      return decreased,
        "expected function to decrease value from " .. tostring(before_value) .. " but got " .. tostring(after_value),
        "expected function to not decrease value from "
          .. tostring(before_value)
          .. " but it did decrease to "
          .. tostring(after_value)
    end,
  },

  -- Alias for equal with clearer name for deep comparison
  --- Alias for `equal`. Tests deep equality using `M.eq`.
  ---@field test fun(v: any, x: any, eps?: number): boolean, string, string
  deep_equal = {
    ---@param v any The actual value.
    ---@param x any The expected value.
    ---@param eps? number Optional epsilon for floating-point comparisons.
    ---@return boolean success True if `M.eq(v, x, eps)` is true.
    ---@return string success_message Message for success.
    ---@return string failure_message Message for failure.
    test = function(v, x, eps)
      return M.eq(v, x, eps),
        "expected " .. stringify(v) .. " to deeply equal " .. stringify(x),
        "expected " .. stringify(v) .. " to not deeply equal " .. stringify(x)
    end,
  },
}

--- Tests if string `v` matches Lua pattern `pattern`, with optional flags.
---@field test fun(v: string, pattern: string, options?: {case_insensitive?: boolean, multiline?: boolean}): boolean, string, string
paths.match_regex = {
  ---@param v string The string to test.
  ---@param pattern string The Lua pattern to match against.
  ---@param options? {case_insensitive?: boolean, multiline?: boolean} Optional flags. `case_insensitive` converts both string and pattern to lowercase. `multiline` handles `^` matching start of lines differently.
  ---@return boolean success True if `v` matches `pattern` with options.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` or `pattern` are not strings, or `options` is not a table.
  test = function(v, pattern, options)
    if type(v) ~= "string" then
      error("Expected a string, got " .. type(v))
    end

    if type(pattern) ~= "string" then
      error("Expected a string pattern, got " .. type(pattern))
    end

    if options ~= nil and type(options) ~= "table" then
      error("Expected options to be a table, got " .. type(options))
    end

    options = options or {}
    local case_insensitive = options.case_insensitive or false
    local multiline = options.multiline or false

    -- Apply case insensitivity by converting to lowercase if requested
    local compare_v = v
    local compare_pattern = pattern

    if case_insensitive then
      compare_v = string.lower(compare_v)
      compare_pattern = string.lower(compare_pattern)
    end

    -- Create user-friendly options string for error messages
    local options_str = ""
    if next(options) then
      local opts = {}
      if options.case_insensitive then
        table.insert(opts, "case_insensitive")
      end
      if options.multiline then
        table.insert(opts, "multiline")
      end
      options_str = " (with options: " .. table.concat(opts, ", ") .. ")"
    end

    -- Handle multiline flag
    if multiline then
      -- For multiline matching, we need to handle patterns and input line by line
      local result = false

      -- For multiline patterns, we need a completely different approach
      if string.find(pattern, "\n") then
        -- Split both the pattern and input by newlines
        local pattern_lines = {}
        local input_lines = {}

        -- Extract pattern lines
        pattern:gsub("([^\n]*)\n?", function(line)
          if line ~= "" or #pattern_lines == 0 then
            table.insert(pattern_lines, line)
          end
        end)

        -- Extract input lines
        compare_v:gsub("([^\n]*)\n?", function(line)
          if line ~= "" or #input_lines == 0 then
            table.insert(input_lines, line)
          end
        end)

        -- If pattern has more lines than input, it can't match
        if #pattern_lines > #input_lines then
          return false,
            'expected "' .. v .. '" to match regex pattern "' .. pattern .. '"' .. options_str,
            'expected "' .. v .. '" to not match regex pattern "' .. pattern .. '"' .. options_str
        end

        -- Try to find a match starting at each possible position in input_lines
        for start_pos = 1, #input_lines - #pattern_lines + 1 do
          local all_lines_match = true

          -- Check if pattern_lines match input_lines starting at start_pos
          for i = 1, #pattern_lines do
            local pattern_line = pattern_lines[i]
            local input_line = input_lines[start_pos + i - 1]

            -- Handle ^ anchors in the pattern
            local has_start_anchor = pattern_line:sub(1, 1) == "^"
            local actual_pattern = has_start_anchor and pattern_line or ".*" .. pattern_line

            -- Actually perform the match
            local line_match = string.find(input_line, actual_pattern) ~= nil

            if not line_match then
              all_lines_match = false
              break
            end
          end

          if all_lines_match then
            return true,
              'expected "' .. v .. '" to match regex pattern "' .. pattern .. '"' .. options_str,
              'expected "' .. v .. '" to not match regex pattern "' .. pattern .. '"' .. options_str
          end
        end

        -- If we get here, no match was found
        return false,
          'expected "' .. v .. '" to match regex pattern "' .. pattern .. '"' .. options_str,
          'expected "' .. v .. '" to not match regex pattern "' .. pattern .. '"' .. options_str
      else
        -- For single-line patterns with multiline flag,
        -- We need to check if the pattern matches any line when ^ anchors the start of a line
        local lines = {}
        compare_v:gsub("([^\n]*)\n?", function(line)
          if line ~= "" or #lines == 0 then
            table.insert(lines, line)
          end
        end)

        -- Check if pattern starts with ^
        local has_start_anchor = compare_pattern:sub(1, 1) == "^"

        for _, line in ipairs(lines) do
          if has_start_anchor then
            -- Pattern must match from start of line
            if string.find(line, compare_pattern) == 1 then
              return true,
                'expected "' .. v .. '" to match regex pattern "' .. pattern .. '"' .. options_str,
                'expected "' .. v .. '" to not match regex pattern "' .. pattern .. '"' .. options_str
            end
          else
            -- Pattern can match anywhere in line
            if string.find(line, compare_pattern) then
              return true,
                'expected "' .. v .. '" to match regex pattern "' .. pattern .. '"' .. options_str,
                'expected "' .. v .. '" to not match regex pattern "' .. pattern .. '"' .. options_str
            end
          end
        end

        -- No match found
        return false,
          'expected "' .. v .. '" to match regex pattern "' .. pattern .. '"' .. options_str,
          'expected "' .. v .. '" to not match regex pattern "' .. pattern .. '"' .. options_str
      end
    else
      -- Regular (non-multiline) pattern matching
      local result = string.find(compare_v, compare_pattern) ~= nil

      return result,
        'expected "' .. v .. '" to match regex pattern "' .. pattern .. '"' .. options_str,
        'expected "' .. v .. '" to not match regex pattern "' .. pattern .. '"' .. options_str
    end
  end,
}

--- Tests if a string fully matches a pattern (from start to end)
---@field test fun(v: string, pattern: string): boolean, string, string
paths.fully = {
  ---@param v string The string to test
  ---@param pattern string The Lua pattern to match against
  ---@return boolean success True if the entire string matches the pattern
  ---@return string success_message Message for success
  ---@return string failure_message Message for failure
  test = function(v, pattern)
    if type(v) ~= "string" then
      error("Expected a string to match fully, got " .. type(v))
    end

    if type(pattern) ~= "string" then
      error("Expected a string pattern, got " .. type(pattern))
    end

    -- For full matching, we need to anchor the pattern with ^ and $
    local anchored_pattern = "^" .. pattern .. "$"
    local result = string.match(v, anchored_pattern) ~= nil

    return result,
      'expected "' .. v .. '" to fully match pattern "' .. pattern .. '"',
      'expected "' .. v .. '" to not fully match pattern "' .. pattern .. '"'
  end,
}

--- Tests if a string matches any pattern in an array of patterns
---@field test fun(v: string, patterns: table): boolean, string, string
paths.any_of = {
  ---@param v string The string to test
  ---@param patterns table An array of Lua patterns to match against
  ---@return boolean success True if the string matches any pattern in the array
  ---@return string success_message Message for success
  ---@return string failure_message Message for failure
  test = function(v, patterns)
    if type(v) ~= "string" then
      error("Expected a string to match against patterns, got " .. type(v))
    end

    if type(patterns) ~= "table" then
      error("Expected an array of patterns, got " .. type(patterns))
    end

    if #patterns == 0 then
      error("Pattern array cannot be empty")
    end

    -- Check if the string matches any of the patterns
    for _, pattern in ipairs(patterns) do
      if type(pattern) ~= "string" then
        error("Expected string pattern in array, got " .. type(pattern))
      end

      if string.find(v, pattern) then
        return true,
          'expected "' .. v .. '" to match any of the patterns: ' .. stringify(patterns),
          'expected "' .. v .. '" to not match any of the patterns: ' .. stringify(patterns)
      end
    end

    return false,
      'expected "' .. v .. '" to match any of the patterns: ' .. stringify(patterns),
      'expected "' .. v .. '" to not match any of the patterns: ' .. stringify(patterns)
  end,
}

--- Tests if a string matches all patterns in an array of patterns
---@field test fun(v: string, patterns: table): boolean, string, string
paths.all_of = {
  ---@param v string The string to test
  ---@param patterns table An array of Lua patterns to match against
  ---@return boolean success True if the string matches all patterns in the array
  ---@return string success_message Message for success
  ---@return string failure_message Message for failure
  test = function(v, patterns)
    if type(v) ~= "string" then
      error("Expected a string to match against patterns, got " .. type(v))
    end

    if type(patterns) ~= "table" then
      error("Expected an array of patterns, got " .. type(patterns))
    end

    if #patterns == 0 then
      error("Pattern array cannot be empty")
    end

    -- Check if the string matches all of the patterns
    for _, pattern in ipairs(patterns) do
      if type(pattern) ~= "string" then
        error("Expected string pattern in array, got " .. type(pattern))
      end

      if not string.find(v, pattern) then
        return false,
          'expected "' .. v .. '" to match all of the patterns: ' .. stringify(patterns),
          'expected "' .. v .. '" to not match all of the patterns: ' .. stringify(patterns)
      end
    end

    return true,
      'expected "' .. v .. '" to match all of the patterns: ' .. stringify(patterns),
      'expected "' .. v .. '" to not match all of the patterns: ' .. stringify(patterns)
  end,
}

--- Tests if string `v` matches Lua pattern `pattern`, with custom options
---@field test fun(v: string, pattern: string, options: table): boolean, string, string
paths.match_with_options = {
  ---@param v string The string to test
  ---@param pattern string The Lua pattern to match against
  ---@param options table Options for matching (full: boolean, ignore_case: boolean)
  ---@return boolean success True if the string matches according to the options
  ---@return string success_message Message for success
  ---@return string failure_message Message for failure
  test = function(v, pattern, options)
    if type(v) ~= "string" then
      error("Expected a string to match, got " .. type(v))
    end

    if type(pattern) ~= "string" then
      error("Expected a string pattern, got " .. type(pattern))
    end

    if options ~= nil and type(options) ~= "table" then
      error("Expected options to be a table, got " .. type(options))
    end

    options = options or {}
    local full = options.full or false
    local case_insensitive = options.case_insensitive or false

    -- Apply case insensitivity if requested
    local compare_v = v
    local compare_pattern = pattern

    if case_insensitive then
      compare_v = string.lower(compare_v)
      compare_pattern = string.lower(compare_pattern)
    end

    -- For full matching, we need to anchor the pattern
    if full then
      compare_pattern = "^" .. compare_pattern .. "$"
    end

    -- Create user-friendly options string for error messages
    local options_str = ""
    if next(options) then
      local opts = {}
      if options.full then
        table.insert(opts, "full")
      end
      if options.case_insensitive then
        table.insert(opts, "case_insensitive")
      end
      options_str = " (with options: " .. table.concat(opts, ", ") .. ")"
    end

    local result = string.find(compare_v, compare_pattern) ~= nil

    return result,
      'expected "' .. v .. '" to match pattern "' .. pattern .. '"' .. options_str,
      'expected "' .. v .. '" to not match pattern "' .. pattern .. '"' .. options_str
  end,
}

---@field test fun(v: string): boolean, string, string
paths.be_date = {
  ---@param v string The string to test.
  ---@return boolean success True if `get_date()(v)` succeeds without error.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  test = function(v)
    if type(v) ~= "string" then
      return false, "expected a string to check if it's a date, got " .. type(v), "expected not a string" -- Less useful negated message
    end

    local success, _ = pcall(function()
      return get_date()(v)
    end)
    return success,
      'expected "' .. v .. '" to be a valid date string',
      'expected "' .. v .. '" to not be a valid date string'
  end,
}

--- Tests if string `value` conforms to common ISO 8601 date/time formats AND represents a valid date.
---@field test fun(value: string): boolean, string, string
paths.be_iso_date = {
  ---@param value string The string to test.
  ---@return boolean success True if `value` matches an ISO pattern and is a valid date according to `lib.tools.date`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (either format mismatch or invalid date components).
  test = function(value)
    if type(value) ~= "string" then
      return false, "expected string for ISO date format, got " .. type(value), "expected not a string"
    end

    -- Basic ISO 8601 patterns
    local patterns = {
      -- Basic date: YYYY-MM-DD
      "^%d%d%d%d%-%d%d%-%d%d$",
      -- Date with time: YYYY-MM-DDThh:mm:ss
      "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d$",
      -- Date with time and fractions: YYYY-MM-DDThh:mm:ss.sss
      "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d+$",
      -- Date with time and UTC indicator: YYYY-MM-DDThh:mm:ssZ
      "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$",
      -- Date with time, fractions and UTC indicator: YYYY-MM-DDThh:mm:ss.sssZ
      "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d+Z$",
      -- Date with time and timezone: YYYY-MM-DDThh:mm:ss±hh:mm
      "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d[%+%-]%d%d:%d%d$",
      -- Date with time, fractions and timezone: YYYY-MM-DDThh:mm:ss.sss±hh:mm
      "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d+[%+%-]%d%d:%d%d$",
      -- Date with time and short timezone: YYYY-MM-DDThh:mm:ss±hh
      "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d[%+%-]%d%d$",
      -- Date with time, fractions and short timezone: YYYY-MM-DDThh:mm:ss.sss±hh
      "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d+[%+%-]%d%d$",
    }

    -- Check if the input matches any of the ISO 8601 patterns
    local format_valid = false
    for _, pattern in ipairs(patterns) do
      if string.match(value, pattern) then
        format_valid = true
        break
      end
    end

    if not format_valid then
      return false, "expected ISO 8601 date format, got " .. value, "expected not to be in ISO 8601 date format"
    end

    -- Use the date module to validate the date
    local success, date_obj = pcall(function()
      return get_date()(value)
    end)

    if not success then
      return false, "invalid ISO 8601 date: " .. value .. " (date parsing failed)", "expected date to be invalid"
    end

    -- Additional validation for date components
    local year, month, day
    if date_obj then
      year, month, day = date_obj:getdate()

      -- Validate month range
      if month < 1 or month > 12 then
        return false, "expected month between 1 and 12, got " .. month, "expected month not to be valid"
      end

      -- Validate day range based on month
      local max_days = 31
      if month == 4 or month == 6 or month == 9 or month == 11 then
        max_days = 30
      elseif month == 2 then
        -- February: account for leap years
        max_days = get_date().isleapyear(year) and 29 or 28
      end

      if day < 1 or day > max_days then
        return false,
          "expected day between 1 and " .. max_days .. " for month " .. month .. ", got " .. day,
          "expected day not to be valid"
      end
    end

    return true,
      "expected " .. value .. " to be a valid ISO 8601 date",
      "expected " .. value .. " to not be a valid ISO 8601 date"
  end,
}

--- Tests if date `a` is chronologically before date `b`. Parses `a` and `b` using `lib.tools.date`.
---@field test fun(a: string, b: string): boolean, string, string
paths.be_before = {
  ---@param a string The first date string.
  ---@param b string The second date string.
  ---@return boolean success True if `a` parses to a date strictly before `b`.
  ---@return string success_message Message for success.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (including parsing errors).
  test = function(a, b)
    -- ensure both values are date objects
    local d1, r1 = get_date()(a)
    local d2, r2 = get_date()(b)
    if not (d1 and d2) then
      return false,
        "expected dates for comparison, got " .. type(a) .. " and " .. type(b),
        "expected dates not to be before each other"
    end
    return d1 < d2,
      "expected " .. tostring(d1) .. " to be before " .. tostring(d2),
      "expected " .. tostring(d1) .. " to not be before " .. tostring(d2)
  end,
}

--- Tests if date `a` is chronologically after date `b`. Parses `a` and `b` using `lib.tools.date`.
---@field test fun(a: string, b: string): boolean, string, string
paths.be_after = {
  ---@param a string The first date string.
  ---@param b string The second date string.
  ---@return boolean success True if `a` parses to a date strictly after `b`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (including parsing errors).
  test = function(a, b)
    -- ensure both values are date objects
    local d1, r1 = get_date()(a)
    local d2, r2 = get_date()(b)
    if not (d1 and d2) then
      return false,
        "expected dates for comparison, got " .. type(a) .. " and " .. type(b),
        "expected dates not to be after each other"
    end
    return d1 > d2,
      "expected " .. tostring(d1) .. " to be after " .. tostring(d2),
      "expected " .. tostring(d1) .. " to not be after " .. tostring(d2)
  end,
}

--- Tests if date string `v` represents the same calendar day as `expected_date`. Parses both using `lib.tools.date`.
---@field test fun(v: string, expected_date: string): boolean, string, string
paths.be_same_day_as = {
  ---@param v string The first date string.
  ---@param expected_date string The second date string.
  ---@return boolean success True if both parse and represent the same year, month, and day.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (including parsing errors).
  test = function(v, expected_date)
    if type(v) ~= "string" or type(expected_date) ~= "string" then
      return false, "Expected a date string, got " .. type(v), "Expected a non-date string"
    end

    local success1, date1 = pcall(function()
      return get_date()(v)
    end)
    local success2, date2 = pcall(function()
      return get_date()(expected_date)
    end)

    if not (success1 and success2) then
      return false,
        'expected "' .. v .. '" and "' .. expected_date .. '" to be valid dates for comparison',
        'expected "' .. v .. '" and "' .. expected_date .. '" to not be valid dates for comparison'
    end

    return date1:getyear() == date2:getyear()
      and date1:getmonth() == date2:getmonth()
      and date1:getday() == date2:getday(),
      'expected "' .. v .. '" to be the same day as "' .. expected_date .. '"',
      'expected "' .. v .. '" to not be the same day as "' .. expected_date .. '"'
  end,
}

--- Tests if date string `v` is between two other date strings, `start_date` and `end_date`. Parses all dates using `lib.tools.date`.
---@field test fun(v: string, start_date: string, end_date: string, inclusive?: boolean): boolean, string, string
paths.be_between_dates = {
  ---@param v string The date string to check.
  ---@param start_date string The start date string.
  ---@param end_date string The end date string.
  ---@param inclusive boolean Whether the comparison should be inclusive (>=, <=) instead of exclusive (>, <). Default is true.
  ---@return boolean success True if `v` is chronologically between `start_date` and `end_date`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (including parsing errors).
  test = function(v, start_date, end_date, inclusive)
    if type(v) ~= "string" or type(start_date) ~= "string" or type(end_date) ~= "string" then
      return false,
        "expected date strings for comparison, got " .. type(v) .. ", " .. type(start_date) .. ", " .. type(end_date),
        "expected invalid date strings"
    end

    -- Default to inclusive comparisons
    if inclusive == nil then
      inclusive = true
    end

    local success1, date_v = pcall(function()
      return get_date()(v)
    end)
    local success2, date_start = pcall(function()
      return get_date()(start_date)
    end)
    local success3, date_end = pcall(function()
      return get_date()(end_date)
    end)

    if not (success1 and success2 and success3) then
      return false,
        'expected "' .. v .. '", "' .. start_date .. '", and "' .. end_date .. '" to be valid dates for comparison',
        'expected at least one invalid date among "' .. v .. '", "' .. start_date .. '", and "' .. end_date .. '"'
    end

    local result
    if inclusive then
      result = date_v >= date_start and date_v <= date_end
    else
      result = date_v > date_start and date_v < date_end
    end

    local inclusive_str = inclusive and " (inclusive)" or " (exclusive)"

    return result,
      'expected "' .. v .. '" to be between "' .. start_date .. '" and "' .. end_date .. '"' .. inclusive_str,
      'expected "' .. v .. '" to not be between "' .. start_date .. '" and "' .. end_date .. '"' .. inclusive_str
  end,
}

--- Tests if an async function `async_fn` (which accepts a `done` callback) completes within the given `timeout`. Requires `lib.async`.
---@field test fun(async_fn: fun(done: function), timeout?: number): boolean, string, string
paths.complete = {
  ---@param async_fn fun(done: function) The async function to test. Must call `done()` on completion.
  ---@param timeout? number Optional timeout in milliseconds (default 1000).
  ---@return boolean success True if `done()` is called within `timeout`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (timeout or internal error).
  ---@throws string If called outside an async context, or if `async_fn` is not a function.
  test = function(async_fn, timeout)
    if type(async_fn) ~= "function" then
      error("Expected an async function, got " .. type(async_fn))
    end

    timeout = timeout or 1000 -- Default 1 second timeout

    -- Check if we're in an async context
    local async_module = package.loaded["lib.async"] or package.loaded["lib.async.init"]
    if not async_module or not async_module.is_in_async_context then
      error("Async assertions can only be used in async test contexts")
    end

    if not async_module.is_in_async_context() then
      error("Async assertions can only be used in async test contexts")
    end

    local completed = false
    local result_value
    local error_value

    -- Function to capture the result
    local function capture_result(...)
      completed = true
      if select("#", ...) > 0 then
        result_value = ...
      end
    end

    -- Start the async operation
    local success, err = pcall(function()
      -- Start the async function and pass the capture function as a callback
      async_fn(capture_result)
    end)

    if not success then
      error_value = err
      completed = true
    end

    -- Wait for the async operation to complete or timeout
    local wait_result = pcall(function()
      async_module.wait_until(function()
        return completed
      end, timeout)
    end)

    -- If there was an error running the function, throw it
    if error_value then
      error(error_value)
    end

    -- If wait_until timed out, wait_result will be false
    return wait_result,
      "async operation did not complete within " .. timeout .. "ms",
      "async operation completed when it was expected to timeout"
  end,
}

--- Tests if an async function `async_fn` completes within the specific `timeout`. Alias for `complete`. Requires `lib.async`.
---@field test fun(async_fn: fun(done: function), timeout: number): boolean, string, string
paths.complete_within = {
  ---@param async_fn fun(done: function) The async function to test.
  ---@param timeout number The required timeout in milliseconds.
  ---@return boolean success True if `done()` is called within `timeout`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If called outside an async context, if `async_fn` is not a function, or if `timeout` is not a positive number.
  test = function(async_fn, timeout)
    if type(async_fn) ~= "function" then
      error("Expected an async function, got " .. type(async_fn))
    end

    if type(timeout) ~= "number" or timeout <= 0 then
      error("timeout must be a positive number")
    end

    -- Check if we're in an async context
    local async_module = package.loaded["lib.async"] or package.loaded["lib.async.init"]
    if not async_module or not async_module.is_in_async_context then
      error("Async assertions can only be used in async test contexts")
    end

    if not async_module.is_in_async_context() then
      error("Async assertions can only be used in async test contexts")
    end

    local completed = false
    local start_time = os.clock() * 1000
    local result_value
    local error_value

    -- Function to capture the result
    local function capture_result(...)
      completed = true
      if select("#", ...) > 0 then
        result_value = ...
      end
    end

    -- Start the async operation
    local success, err = pcall(function()
      -- Start the async function and pass the capture function as a callback
      async_fn(capture_result)
    end)

    if not success then
      error_value = err
      completed = true
    end

    -- Wait for the async operation to complete or timeout
    local wait_result = pcall(function()
      async_module.wait_until(function()
        return completed
      end, timeout)
    end)

    -- If there was an error running the function, throw it
    if error_value then
      error(error_value)
    end

    local elapsed = (os.clock() * 1000) - start_time

    -- If wait_until timed out, wait_result will be false
    return wait_result,
      "async operation did not complete within " .. timeout .. "ms",
      "async operation completed within " .. timeout .. "ms when it was expected to timeout"
  end,
}

--- Tests if an async function `async_fn` completes successfully and calls its `done` callback with a value deeply equal to `expected_value`. Requires `lib.async`.
---@field test fun(async_fn: fun(done: fun(err?: any, result?: any)), expected_value: any, timeout?: number): boolean, string, string
paths.resolve_with = {
  ---@param async_fn fun(done: fun(err?: any, result?: any)) The async function. `done` typically called as `done(nil, result)`.
  ---@param expected_value any The value expected to be passed to `done`.
  ---@param timeout? number Optional timeout in milliseconds (default 1000).
  ---@return boolean success True if completed successfully with the expected value.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (timeout, error, or wrong value).
  ---@throws string If called outside an async context, or if `async_fn` is not a function.
  test = function(async_fn, expected_value, timeout)
    if type(async_fn) ~= "function" then
      error("Expected an async function, got " .. type(async_fn))
    end

    timeout = timeout or 1000 -- Default 1 second timeout

    -- Check if we're in an async context
    local async_module = package.loaded["lib.async"] or package.loaded["lib.async.init"]
    if not async_module or not async_module.is_in_async_context then
      error("Async assertions can only be used in async test contexts")
    end

    if not async_module.is_in_async_context() then
      error("Async assertions can only be used in async test contexts")
    end

    local completed = false
    local result_value
    local error_value

    -- Function to capture the result
    local function capture_result(...)
      completed = true
      if select("#", ...) > 0 then
        result_value = ...
      end
    end

    -- Start the async operation
    local success, err = pcall(function()
      -- Start the async function and pass the capture function as a callback
      async_fn(capture_result)
    end)

    if not success then
      error_value = err
      completed = true
    end

    -- Wait for the async operation to complete or timeout
    local wait_result = pcall(function()
      async_module.wait_until(function()
        return completed
      end, timeout)
    end)

    -- If there was an error running the function, throw it
    if error_value then
      error(error_value)
    end

    -- If wait_until timed out
    if not wait_result then
      return false, "async operation did not complete within " .. timeout .. "ms", nil
    end

    -- Check if the result value matches the expected value
    return M.eq(result_value, expected_value),
      "expected async operation to resolve with " .. stringify(expected_value) .. " but got " .. stringify(result_value),
      "expected async operation to not resolve with " .. stringify(expected_value)
  end,
}

--- Tests if an async function `async_fn` calls its `done` callback with an error. Optionally checks if the error message matches `error_pattern`. Requires `lib.async`.
---@field test fun(async_fn: fun(done: fun(err?: any)), error_pattern?: string, timeout?: number): boolean, string, string
paths.reject = {
  ---@param async_fn fun(done: fun(err?: any)) The async function. `done` typically called as `done(err)`.
  ---@param error_pattern? string Optional Lua pattern to match against the error message passed to `done`.
  ---@param timeout? number Optional timeout in milliseconds (default 1000).
  ---@return boolean success True if completed by calling `done` with an error (and optionally matching pattern).
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (timeout, no error, or pattern mismatch).
  ---@throws string If called outside an async context, or if `async_fn` is not a function.
  test = function(async_fn, error_pattern, timeout)
    if type(async_fn) ~= "function" then
      error("Expected an async function, got " .. type(async_fn))
    end

    timeout = timeout or 1000 -- Default 1 second timeout

    -- Check if we're in an async context
    local async_module = package.loaded["lib.async"] or package.loaded["lib.async.init"]
    if not async_module or not async_module.is_in_async_context then
      error("Async assertions can only be used in async test contexts")
    end

    if not async_module.is_in_async_context() then
      error("Async assertions can only be used in async test contexts")
    end

    local completed = false
    local rejected = false
    local error_message

    -- Function to capture success
    local function success_callback()
      completed = true
    end

    -- Function to capture error
    local function error_callback(err)
      completed = true
      rejected = true
      error_message = err
    end

    -- Start the async operation
    local success, err = pcall(function()
      -- Start the async function with success and error callbacks
      async_fn(success_callback, error_callback)
    end)

    if not success then
      -- The function itself threw an error (not an async rejection)
      rejected = true
      error_message = err
      completed = true
    end

    -- Wait for the async operation to complete or timeout
    local wait_result = pcall(function()
      async_module.wait_until(function()
        return completed
      end, timeout)
    end)

    -- If wait_until timed out
    if not wait_result then
      return false, "async operation did not complete within " .. timeout .. "ms", nil
    end

    -- If error pattern is provided, check that the error matches
    if error_pattern and rejected then
      local matches_pattern = type(error_message) == "string" and string.find(error_message, error_pattern) ~= nil

      if not matches_pattern then
        return false,
          "expected async operation to reject with error matching "
            .. stringify(error_pattern)
            .. " but got "
            .. stringify(error_message),
          nil
      end
    end

    return rejected,
      "expected async operation to reject with an error"
        .. (error_pattern and " matching " .. stringify(error_pattern) or ""),
      "expected async operation to not reject with an error"
  end,
}

--- Tests if table `v` contains *all* keys listed in table `x`.
---@field test fun(v: table, x: table): boolean, string, string
paths.keys = {
  ---@param v table The table to check.
  ---@param x table An array-like table listing the keys expected to be present in `v`.
  ---@return boolean success True if all keys in `x` exist in `v`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` or `x` are not tables.
  test = function(v, x)
    if type(v) ~= "table" then
      error("expected " .. tostring(v) .. " to be a table")
    end

    if type(x) ~= "table" then
      error("expected " .. tostring(x) .. " to be a table containing keys to check for")
    end

    for _, key in ipairs(x) do
      if v[key] == nil then
        return false,
          "expected " .. stringify(v) .. " to contain key " .. tostring(key),
          "expected " .. stringify(v) .. " to not contain key " .. tostring(key)
      end
    end

    return true,
      "expected " .. stringify(v) .. " to contain keys " .. stringify(x),
      "expected " .. stringify(v) .. " to not contain keys " .. stringify(x)
  end,
}

--- Tests if table `v` contains the specific key `x`.
---@field test fun(v: table, x: any): boolean, string, string
paths.key = {
  ---@param v table The table to check.
  ---@param x any The key to look for.
  ---@return boolean success True if `v[x]` is not `nil`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` is not a table.
  test = function(v, x)
    if type(v) ~= "table" then
      error("expected " .. tostring(v) .. " to be a table")
    end

    return v[x] ~= nil,
      "expected " .. stringify(v) .. " to contain key " .. tostring(x),
      "expected " .. stringify(v) .. " to not contain key " .. tostring(x)
  end,
}

--- Helper function to get a deeply nested value from a table.
---@param tbl table The table to traverse.
---@param key_path string|table The path to the value. Can be a dot-separated string ("a.b.c") or a table of keys ({ "a", "b", "c" }).
---@return any|nil value The value found at the path, or nil if the path is invalid or the value doesn't exist.
---@return boolean exists True if the full path was valid and the value exists (even if nil), false otherwise.
---@private
local function _get_deep_value(tbl, key_path)
  if type(tbl) ~= "table" then
    return nil, false
  end

  local path_parts = {}
  if type(key_path) == "string" then
    for part in string.gmatch(key_path, "[^.]+") do
      table.insert(path_parts, part)
    end
  elseif type(key_path) == "table" then
    path_parts = key_path
  else
    return nil, false -- Invalid path type
  end

  if #path_parts == 0 then
    return nil, false -- Empty path
  end

  local current_value = tbl
  for i, part in ipairs(path_parts) do
    if type(current_value) ~= "table" then
      return nil, false -- Invalid path, encountered non-table intermediate value
    end
    -- Check if the key exists before accessing
    if current_value[part] == nil and i < #path_parts then
      -- Intermediate key doesn't exist
      return nil, false
    end
    current_value = current_value[part]
    if current_value == nil and i < #path_parts then
      return nil, false -- Path doesn't exist fully
    end
  end

  -- If we reached here, the path was valid. Check if the final key exists.
  local final_part = path_parts[#path_parts]
  local parent_value = tbl
  for i = 1, #path_parts - 1 do
    parent_value = parent_value[path_parts[i]]
  end

  local key_exists = false
  if type(parent_value) == "table" then
    for k, _ in pairs(parent_value) do
      if k == final_part then
        key_exists = true
        break
      end
    end
  end

  return current_value, key_exists -- Return the final value and whether the key existed
end

--- Tests if a table `v` has a deeply nested key specified by `key_path`.
---@field test fun(v: table, key_path: string|table): boolean, string, string
paths.deep_key = {
  ---@param v table The table to check.
  ---@param key_path string|table The path to the key (e.g., "a.b.c" or {"a", "b", "c"}).
  ---@return boolean success True if the deep key exists.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` is not a table or `key_path` is invalid.
  test = function(v, key_path)
    if type(v) ~= "table" then
      error("expected a table for deep key check, got " .. type(v))
    end
    local _, exists = _get_deep_value(v, key_path)
    local path_str = type(key_path) == "string" and key_path or table.concat(key_path, ".")

    return exists,
      "expected " .. stringify(v) .. ' to have deep key "' .. path_str .. '"',
      "expected " .. stringify(v) .. ' to not have deep key "' .. path_str .. '"'
  end,
}

--- Tests if a table `v` contains *exactly* the keys listed in `expected_keys` and no others.
---@field test fun(v: table, expected_keys: table): boolean, string, string
paths.exact_keys = {
  ---@param v table The table to check.
  ---@param expected_keys table An array-like table listing the keys expected to be present exclusively.
  ---@return boolean success True if `v` contains exactly the keys in `expected_keys`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure, detailing missing or extra keys.
  ---@throws string If `v` or `expected_keys` are not tables.
  test = function(v, expected_keys)
    if type(v) ~= "table" then
      error("expected a table for exact keys check, got " .. type(v))
    end
    if type(expected_keys) ~= "table" then
      error("expected keys must be a table, got " .. type(expected_keys))
    end

    local actual_keys = {}
    local actual_key_count = 0
    for k, _ in pairs(v) do
      actual_keys[k] = true
      actual_key_count = actual_key_count + 1
    end

    local expected_key_map = {}
    local expected_key_count = 0
    for _, k in ipairs(expected_keys) do
      expected_key_map[k] = true
      expected_key_count = expected_key_count + 1
    end

    local missing_keys = {}
    for k, _ in pairs(expected_key_map) do
      if not actual_keys[k] then
        table.insert(missing_keys, stringify(k))
      end
    end

    local extra_keys = {}
    for k, _ in pairs(actual_keys) do
      if not expected_key_map[k] then
        table.insert(extra_keys, stringify(k))
      end
    end

    local success = #missing_keys == 0 and #extra_keys == 0

    local failure_msg = "expected table to have exact keys " .. stringify(expected_keys) .. ", but:"
    if #missing_keys > 0 then
      failure_msg = failure_msg .. "\n  Missing keys: " .. table.concat(missing_keys, ", ")
    end
    if #extra_keys > 0 then
      failure_msg = failure_msg .. "\n  Extra keys: " .. table.concat(extra_keys, ", ")
    end

    return success, "expected table to have exact keys " .. stringify(expected_keys), failure_msg
  end,
}

--- Tests if number `v` is strictly greater than number `x`.
---@field test fun(v: number, x: number): boolean, string, string
paths.be_greater_than = {
  ---@param v number The actual number.
  ---@param x number The threshold number.
  ---@return boolean success True if `v > x`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` or `x` are not numbers.
  test = function(v, x)
    if type(v) ~= "number" then
      error("expected " .. tostring(v) .. " to be a number")
    end

    if type(x) ~= "number" then
      error("expected " .. tostring(x) .. " to be a number")
    end

    return v > x,
      "expected " .. tostring(v) .. " to be greater than " .. tostring(x),
      "expected " .. tostring(v) .. " to not be greater than " .. tostring(x)
  end,
}

--- Tests if number `v` is negative (`v < 0`).
---@field test fun(v: number): boolean, string, string
paths.negative = {
  ---@param v number The number to check.
  ---@return boolean success True if `v < 0`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` is not a number.
  test = function(v)
    if type(v) ~= "number" then
      error("expected " .. tostring(v) .. " to be a number")
    end

    return v < 0, "expected " .. tostring(v) .. " to be negative", "expected " .. tostring(v) .. " to not be negative"
  end,
}

--- Tests if number `v` is an integer (has no fractional part).
---@field test fun(v: number): boolean, string, string
paths.integer = {
  ---@param v number The number to check.
  ---@return boolean success True if `v == math.floor(v)`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` is not a number.
  test = function(v)
    if type(v) ~= "number" then
      error("expected " .. tostring(v) .. " to be a number")
    end

    return v == math.floor(v),
      "expected " .. tostring(v) .. " to be an integer",
      "expected " .. tostring(v) .. " to not be an integer"
  end,
}

--- Tests if string `v` consists entirely of uppercase characters.
---@field test fun(v: string): boolean, string, string
paths.uppercase = {
  ---@param v string The string to check.
  ---@return boolean success True if `v == string.upper(v)`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` is not a string.
  test = function(v)
    if type(v) ~= "string" then
      error("expected " .. tostring(v) .. " to be a string")
    end

    return v == string.upper(v),
      'expected string "' .. v .. '" to be uppercase',
      'expected string "' .. v .. '" to not be uppercase'
  end,
}

--- Tests if string `v` consists entirely of lowercase characters.
---@field test fun(v: string): boolean, string, string
paths.lowercase = {
  ---@param v string The string to check.
  ---@return boolean success True if `v == string.lower(v)`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` is not a string.
  test = function(v)
    if type(v) ~= "string" then
      error("expected " .. tostring(v) .. " to be a string")
    end

    return v == string.lower(v),
      'expected string "' .. v .. '" to be lowercase',
      'expected string "' .. v .. '" to not be lowercase'
  end,
}

--- Tests if value `v` satisfies a custom `predicate` function.
---@field test fun(v: any, predicate: fun(v: any): boolean): boolean, string, string
paths.satisfy = {
  ---@param v any The value to test.
  ---@param predicate fun(v: any): boolean A function that receives `v` and returns `true` if satisfied, `false` otherwise.
  ---@return boolean success The result returned by `predicate(v)`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `predicate` is not a function or if `predicate(v)` throws an error.
  test = function(v, predicate)
    if type(predicate) ~= "function" then
      error("expected predicate to be a function, got " .. type(predicate))
    end

    local success, result = pcall(predicate, v)
    if not success then
      error("predicate function failed with error: " .. tostring(result))
    end

    return result,
      "expected value to satisfy the given predicate function",
      "expected value to not satisfy the given predicate function"
  end,
}

-- String assertions
--- Tests if string `v` starts with the prefix string `x`.
---@field test fun(v: string, x: string): boolean, string, string
paths.start_with = {
  ---@param v string The string to check.
  ---@param x string The expected prefix.
  ---@return boolean success True if `v` starts with `x`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` or `x` are not strings.
  test = function(v, x)
    if type(v) ~= "string" then
      error("expected " .. tostring(v) .. " to be a string")
    end

    if type(x) ~= "string" then
      error("expected " .. tostring(x) .. " to be a string")
    end

    return v:sub(1, #x) == x,
      'expected "' .. v .. '" to start with "' .. x .. '"',
      'expected "' .. v .. '" to not start with "' .. x .. '"'
  end,
}

--- Tests if string `v` ends with the suffix string `x`.
---@field test fun(v: string, x: string): boolean, string, string
paths.end_with = {
  ---@param v string The string to check.
  ---@param x string The expected suffix.
  ---@return boolean success True if `v` ends with `x`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` or `x` are not strings.
  test = function(v, x)
    if type(v) ~= "string" then
      error("expected " .. tostring(v) .. " to be a string")
    end

    if type(x) ~= "string" then
      error("expected " .. tostring(x) .. " to be a string")
    end

    return v:sub(-#x) == x,
      'expected "' .. v .. '" to end with "' .. x .. '"',
      'expected "' .. v .. '" to not end with "' .. x .. '"'
  end,
}

-- Type checking assertions
paths.be_type = {
  callable = true, -- Marker for chaining
  comparable = true, -- Marker for chaining
  iterable = true, -- Marker for chaining
  test = function(v, expected_type)
    if expected_type == "callable" then
      -- Check if it's a function or a table with __call metamethod
      local is_callable = type(v) == "function" or (type(v) == "table" and getmetatable(v) and getmetatable(v).__call)
      return is_callable,
        "expected " .. tostring(v) .. " to be callable",
        "expected " .. tostring(v) .. " to not be callable"
    elseif expected_type == "comparable" then
      local success = pcall(function()
        return v < v
      end)
      return success,
        "expected " .. tostring(v) .. " to be comparable",
        "expected " .. tostring(v) .. " to not be comparable"
    elseif expected_type == "iterable" then
      local success = pcall(function()
        for _ in pairs(v) do
          break
        end
      end)
      return success,
        "expected " .. tostring(v) .. " to be iterable",
        "expected " .. tostring(v) .. " to not be iterable"
    else
      error("unknown type check: " .. tostring(expected_type))
    end
  end,
}

-- Enhanced error assertions
paths.throw = {
  error = true,
  error_matching = true, -- Marker for chaining
  error_type = true, -- Marker for chaining
  --- Base test for `throw` chain. Tests if calling function `v` throws any error.
  ---@param v function The function to call.
  ---@return boolean success True if `pcall(v)` returns `false`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` is not a function.
  test = function(v)
    if type(v) ~= "function" then
      error("expected " .. tostring(v) .. " to be a function")
    end

    ---@diagnostic disable-next-line: unused-local
    local ok, err = pcall(v)
    return not ok, "expected function to throw an error", "expected function to not throw an error"
  end,
}

--- Tests if number `v` is close to `expected` within a given `tolerance`. Uses `M.eq` for comparison.
---@field test fun(v: number, expected: number, tolerance?: number): boolean, string, string
paths.be_near = {
  ---@param v number The actual number.
  ---@param expected number The expected number.
  ---@param tolerance? number The maximum allowed difference (default 0.0001).
  ---@return boolean success True if `abs(v - expected) <= tolerance`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v`, `expected`, or `tolerance` are not numbers.
  test = function(v, expected, tolerance)
    if type(v) ~= "number" then
      error("expected actual value to be a number, got " .. type(v))
    end
    if type(expected) ~= "number" then
      error("expected target value to be a number, got " .. type(expected))
    end
    tolerance = tolerance or 0.0001 -- Default tolerance
    if type(tolerance) ~= "number" or tolerance < 0 then
      error("tolerance must be a non-negative number")
    end

    local is_near = M.eq(v, expected, tolerance)

    return is_near,
      "expected " .. tostring(v) .. " to be near " .. tostring(expected) .. " (within " .. tostring(tolerance) .. ")",
      "expected "
        .. tostring(v)
        .. " to not be near "
        .. tostring(expected)
        .. " (within "
        .. tostring(tolerance)
        .. ")"
  end,
}

--- Alias for `be_near`.
---@field test fun(v: number, expected: number, tolerance?: number): boolean, string, string
paths.be_approximately = paths.be_near

--- Alias for `throw`. Tests if function `v` throws an error.
---@field test fun(v: function): boolean, string, string
paths.error = {
  ---@param v function The function to call.
  ---@return boolean success True if `pcall(v)` returns `false`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure.
  ---@throws string If `v` is not a function.
  test = function(v)
    if type(v) ~= "function" then
      error("expected " .. tostring(v) .. " to be a function")
    end

    ---@diagnostic disable-next-line: unused-local
    local ok, err = pcall(v)
    return not ok, "expected function to throw an error", "expected function to not throw an error"
  end,
}

--- Tests if function `v` throws an error whose message matches `pattern`. Used after `.throw`.
---@field test fun(v: function, pattern: string): boolean, string, string
paths.error_matching = {
  ---@param v function The function to call.
  ---@param pattern string The Lua pattern to match against the error message.
  ---@return boolean success True if `v` throws and the message matches `pattern`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (no error, or message mismatch).
  ---@throws string If `v` is not a function or `pattern` is not a string.
  test = function(v, pattern)
    if type(v) ~= "function" then
      error("expected " .. tostring(v) .. " to be a function")
    end

    if type(pattern) ~= "string" then
      error("expected pattern to be a string")
    end

    local ok, err = pcall(v)
    if ok then
      return false,
        'expected function to throw an error matching pattern "' .. pattern .. '"',
        'expected function to not throw an error matching pattern "' .. pattern .. '"'
    end

    err = tostring(err)
    return err:match(pattern) ~= nil,
      'expected error "' .. err .. '" to match pattern "' .. pattern .. '"',
      'expected error "' .. err .. '" to not match pattern "' .. pattern .. '"'
  end,
}

--- Tests if function `v` throws an error of a specific type `expected_type`. Used after `.throw`.
---@field test fun(v: function, expected_type: string): boolean, string, string
paths.error_type = {
  ---@param v function The function to call.
  ---@param expected_type string The expected type of the error (e.g., "string", "table"). Attempts basic type detection.
  ---@return boolean success True if `v` throws an error matching `expected_type`.
  ---@return string success_message Message for success.
  ---@return string failure_message Message for failure (no error, or type mismatch).
  ---@throws string If `v` is not a function.
  test = function(v, expected_type)
    if type(v) ~= "function" then
      error("expected " .. tostring(v) .. " to be a function")
    end

    local ok, err = pcall(v)
    if ok then
      return false,
        "expected function to throw an error of type " .. tostring(expected_type),
        "expected function to not throw an error of type " .. tostring(expected_type)
    end

    -- Try to determine the error type
    local error_type
    if type(err) == "string" then
      error_type = "string"
    elseif type(err) == "table" then
      error_type = err.__name or "table"
    else
      error_type = type(err)
    end

    return error_type == expected_type,
      "expected error of type " .. error_type .. " to be of type " .. expected_type,
      "expected error of type " .. error_type .. " to not be of type " .. expected_type
  end,
}

---@class ExpectChain The object returned by `expect()` allowing for fluent, chainable assertions.
--- It manages the value under test (`val`), the current assertion path (`action`), and the negation state (`negate`).
--- Accessing properties like `.to` or `.be` returns the chain itself for readability.
--- Accessing a valid assertion method (e.g., `.equal`, `.exist`) returns the chain.
--- Calling an assertion method (e.g., `expect(x).to.equal(y)`) executes the corresponding test function from the `paths` table.
---@field val any The actual value passed to `expect()`. Internal.
---@field negate boolean Whether the next assertion should be negated (set by `.to_not`). Internal.
---@field action string The current step in the assertion chain (e.g., "equal", "be_greater_than"). Internal.
---@field to ExpectChain Syntactic sugar, returns self.
---@field to_not ExpectChain Syntactic sugar and sets `negate` flag, returns self.
---@field be ExpectChain Syntactic sugar, returns self.
---@field a ExpectChain Syntactic sugar, returns self.
---@field an ExpectChain Syntactic sugar, returns self.
---@field have ExpectChain Syntactic sugar, returns self.
---@field has ExpectChain Syntactic sugar (potential future use), returns self.
---@field deep ExpectChain Modifier (potential future use, currently handled within `equal`), returns self.
---@field only ExpectChain Modifier (potential future use), returns self.
---@field any ExpectChain Modifier (potential future use), returns self.
---@field all ExpectChain Modifier (potential future use), returns self.
---@field equal fun(self: ExpectChain, expected: any, eps?: number): ExpectChain Asserts deep equality.
---@field deep_equal fun(self: ExpectChain, expected: any, eps?: number): ExpectChain Alias for `equal`.
---@field exist fun(self: ExpectChain): ExpectChain Asserts value is not nil.
---@field be_a fun(self: ExpectChain, type_or_class: string|table): ExpectChain Asserts type or class inheritance via `M.isa`.
---@field be_an fun(self: ExpectChain, type_or_class: string|table): ExpectChain Alias for `be_a`.
---@field be_truthy fun(self: ExpectChain): ExpectChain Asserts value is truthy (not false or nil).
---@field be_falsy fun(self: ExpectChain): ExpectChain Asserts value is falsy (false or nil).
---@field be_falsey fun(self: ExpectChain): ExpectChain Alias for `be_falsy`.
---@field be_nil fun(self: ExpectChain): ExpectChain Asserts value is nil.
---@field be_type fun(self: ExpectChain, expected_type: string): ExpectChain Asserts `type(value) == expected_type`. Also supports advanced types "callable", "comparable", "iterable".
---@field be_greater_than fun(self: ExpectChain, threshold: number): ExpectChain Asserts `value > threshold`.
---@field be_less_than fun(self: ExpectChain, threshold: number): ExpectChain Asserts `value < threshold`.
---@field be_at_least fun(self: ExpectChain, threshold: number): ExpectChain Asserts `value >= threshold`.
---@field fail fun(self: ExpectChain): ExpectChain Asserts function call fails (throws error).
---@field fail_with fun(self: ExpectChain, pattern: string): ExpectChain Asserts function fails with error message matching pattern.
---@field match fun(self: ExpectChain, pattern: string): ExpectChain Asserts string matches Lua pattern.
---@field implement_interface fun(self: ExpectChain, interface: table): ExpectChain Asserts table implements interface.
---@field contain fun(self: ExpectChain, value: any): ExpectChain Asserts string contains substring or table contains value.
---@field have_length fun(self: ExpectChain, length: number): ExpectChain Asserts string or table length.
---@field have_size fun(self: ExpectChain, size: number): ExpectChain Alias for `have_length`.
---@field have_property fun(self: ExpectChain, property_name: any, expected_value?: any): ExpectChain Asserts table has property (and optionally checks value).
---@field have_keys fun(self: ExpectChain, keys: table): ExpectChain Asserts table has all keys listed in the `keys` table.
---@field have_key fun(self: ExpectChain, key: any): ExpectChain Asserts table has the specified key.
---@field deep_key fun(self: ExpectChain, key_path: string|table): ExpectChain Asserts table has a deep key specified by path.
---@field have_exact_keys fun(self: ExpectChain, keys: table): ExpectChain Asserts table has exactly the specified keys and no others.
---@field match_schema fun(self: ExpectChain, schema: table): ExpectChain Asserts table matches schema definition.
---@field change fun(self: ExpectChain, value_fn: function, change_fn?: fun(before: any, after: any): boolean): ExpectChain Asserts executing the (function) value changes the result of `value_fn`.
---@field increase fun(self: ExpectChain, value_fn: function): ExpectChain Asserts executing the (function) value increases the numeric result of `value_fn`.
---@field decrease fun(self: ExpectChain, value_fn: function): ExpectChain Asserts executing the (function) value decreases the numeric result of `value_fn`.
---@field match_regex fun(self: ExpectChain, pattern: string, options?: {case_insensitive?: boolean, multiline?: boolean}): ExpectChain Asserts string matches Lua pattern with options.
---@field be_date fun(self: ExpectChain): ExpectChain Asserts string is a valid date parsable by `lib.tools.date`.
---@field be_iso_date fun(self: ExpectChain): ExpectChain Asserts string is a valid ISO 8601 date.
---@field be_before fun(self: ExpectChain, date_str: string): ExpectChain Asserts date string is before another date string.
---@field be_after fun(self: ExpectChain, date_str: string): ExpectChain Asserts date string is after another date string.
---@field be_same_day_as fun(self: ExpectChain, date_str: string): ExpectChain Asserts date string represents the same calendar day as another.
---@field be_near fun(self: ExpectChain, expected: number, tolerance?: number): ExpectChain Asserts number is near expected value within tolerance.
---@field be_approximately fun(self: ExpectChain, expected: number, tolerance?: number): ExpectChain Alias for `be_near`.
---@field complete fun(self: ExpectChain, timeout?: number): ExpectChain Asserts async function completes within timeout.
---@field complete_within fun(self: ExpectChain, timeout: number): ExpectChain Asserts async function completes within specific timeout.
---@field resolve_with fun(self: ExpectChain, expected_value: any, timeout?: number): ExpectChain Asserts async function completes successfully with expected value.
---@field reject fun(self: ExpectChain, error_pattern?: string, timeout?: number): ExpectChain Asserts async function completes with an error (optionally matching pattern).
---@field negative fun(self: ExpectChain): ExpectChain Asserts number is negative.
---@field integer fun(self: ExpectChain): ExpectChain Asserts number is an integer.
---@field uppercase fun(self: ExpectChain): ExpectChain Asserts string is uppercase.
---@field lowercase fun(self: ExpectChain): ExpectChain Asserts string is lowercase.
---@field satisfy fun(self: ExpectChain, predicate: fun(v: any): boolean): ExpectChain Asserts value satisfies custom predicate function.
---@field start_with fun(self: ExpectChain, prefix: string): ExpectChain Asserts string starts with prefix.
---@field end_with fun(self: ExpectChain, suffix: string): ExpectChain Asserts string ends with suffix.
---@field throw fun(self: ExpectChain): ExpectChain Asserts function throws an error.
---@field throw_error fun(self: ExpectChain): ExpectChain Alias for `throw`.
---@field throw_error_matching fun(self: ExpectChain, pattern: string): ExpectChain Asserts function throws error matching pattern.
---@field throw_error_type fun(self: ExpectChain, expected_type: string): ExpectChain Asserts function throws error of specific type.

--- Main expect function for creating assertions
--- Creates an assertion chain (`ExpectChain`) for a given value.
--- This is the primary entry point for using Firmo's expect-style assertions.
--- Increments the global `M.assertion_count`.
---@param v any The value to make assertions about.
---@return ExpectChain The newly created assertion chain object, ready for chaining methods like `.to`, `.to_not`, `.equal`, etc.
---@example expect(1 + 1).to.equal(2)
---@example expect(my_string).to_not.contain("error")
function M.expect(v)
  local logger = get_logger() -- Moved logger up for the trace
  logger.trace("Enter M.expect in assertion.lua", { value_v_type = type(v) }) -- Reverted from print

  ---@diagnostic disable-next-line: unused-local
  local error_handler = get_error_handler()

  -- Track assertion count (for test quality metrics)
  M.assertion_count = (M.assertion_count or 0) + 1

  logger.trace("Assertion started", {
    value = tostring(v),
    type = type(v),
    assertion_count = M.assertion_count,
  })

  local assertion = {}
  assertion.val = v
  assertion.action = ""
  assertion.negate = false

  setmetatable(
    assertion,
    {
      __index = function(t, k)
        -- Always check if key is one of the base paths first (to, to_not)
        -- This ensures these paths are always accessible regardless of state
        if has(paths[""], k) then
          local current_negate = rawget(t, "negate")

          -- Set the action to the base path
          rawset(t, "action", k)

          -- Handle to_not specially for negation
          if k == "to_not" then
            rawset(t, "negate", true)
          else
            -- For "to" path, preserve the current negation state
            rawset(t, "negate", current_negate)
          end

          return t
        end

        local current_action = rawget(t, "action")
        local path_entry = paths[current_action]

        -- Check if the key is valid for the current path
        local valid_key = false

        if path_entry then
          if type(path_entry) == "table" then
            if #path_entry > 0 then
              -- Array-style path entry (like paths[""] = {"to", "to_not"})
              for _, valid_path in ipairs(path_entry) do
                if valid_path == k then
                  valid_key = true
                  break
                end
              end
            else
              -- Map-style path entry
              valid_key = path_entry[k] ~= nil
            end
          end
        end

        if valid_key then
          -- Store the previous action for proper chaining context
          local prev_action = current_action
          -- Store the current negation state
          local current_negate = rawget(t, "negate")

          -- Set the new action, preserving the negation state
          rawset(t, "action", k)

          -- Run chain function if it exists (e.g., for to_not)
          local action = rawget(t, "action")
          local path_entry = action and paths[action]
          local chain = path_entry and type(path_entry) == "table" and path_entry.chain
          if chain then
            chain(t)
          else
            -- Explicitly preserve the negation state when no chain function exists
            rawset(t, "negate", current_negate)
          end

          return t
        end
        return rawget(t, k)
      end,
      __call = function(t, ...)
        local logger = get_logger() -- Ensure logger is available
        logger.trace("[ASSERTION __CALL] Entered", { action = t.action, val_type = type(t.val), negate = t.negate })
        local path_entry = paths[t.action]
        if path_entry and type(path_entry) == "table" and path_entry.test then
          local success, err, nerr

          -- Use error_handler.try if available for structured error handling
          if get_error_handler() then
            local args_for_log = { ... }
            logger.trace("[ASSERTION __CALL] About to call test function", {
              action = t.action,
              val_is_table = type(t.val) == "table",
              val_tostring = tostring(t.val),
              arg_count = #args_for_log,
              first_arg_type = #args_for_log > 0 and type(args_for_log[1]) or nil,
            })
            local args = { ... }
            -- Temporarily use direct pcall to isolate error_handler.try
            local try_success, try_result
            local pcall_func = function()
              local res, e, ne = paths[t.action].test(t.val, unpack(args))
              return { res = res, err = e, nerr = ne }
            end
            try_success, try_result = pcall(pcall_func)
            logger.trace("[ASSERTION __CALL] pcall result for test function", {
              action = t.action,
              try_success = try_success,
              try_result_type = type(try_result),
              try_result_error_message = (try_success == false and type(try_result) == "table" and try_result.message)
                or (try_success == false and type(try_result) == "string" and try_result or nil),
              try_result_is_table_with_res = (
                try_success == true
                and type(try_result) == "table"
                and try_result.res ~= nil
              ),
            })

            if try_success and type(try_result) ~= "table" then
              get_logger().error("Assertion test function did not return a table as expected via pcall", {
                returned_type = type(try_result),
              })
              try_success = false
              try_result = (type(try_result) == "string" or type(try_result) == "table") and try_result
                or "Internal error in assertion test function"
            end

            if try_success then
              success, err, nerr = try_result.res, try_result.err, try_result.nerr
              logger.trace("INTERNAL_ASSERTION_RESULT", {
                action = t.action,
                val_type = type(t.val),
                raw_test_success = success,
                is_negated = rawget(t, "negate"),
              })
            else
              -- Handle error in test function (error came from pcall_func or paths[t.action].test)
              local formatted_err = "Unknown error in assertion test function"
              if get_error_handler() and type(try_result) == "table" then -- if try_result is an error object
                formatted_err = get_error_handler().format_error(try_result)
              elseif type(try_result) == "string" then
                formatted_err = try_result
              end
              logger.error("INTERNAL ASSERTION TEST ERROR (pcall path)", {
                action = t.action,
                value_type_for_log = type(t.val),
                negated = rawget(t, "negate"),
                error_details = formatted_err,
              })
              error((type(try_result) == "table" and try_result.message) or formatted_err, 2)
            end
          else
            -- Fallback if error_handler is not available
            local args = { ... }
            success, err, nerr = paths[t.action].test(t.val, unpack(args))
          end

          -- Use t.negate instead of assertion.negate for consistency
          -- Apply negation if needed
          local negate_flag = rawget(t, "negate")
          if negate_flag then
            -- Invert the success flag for negated assertions
            success = not success
            -- For negated assertions, use the nerr error message if available
            if nerr then
              err = nerr
            end
          end
          if not success then
            if error_handler then
              -- Create a structured error
              local context = {
                expected = select(1, ...),
                actual = t.val,
                action = t.action,
                negate = rawget(t, "negate"), -- Use rawget to ensure direct access
              }

              -- Add debug info about the negation state to help with troubleshooting
              get_logger().debug("Creating assertion error", {
                negate = rawget(t, "negate"), -- Use rawget to ensure direct access
                error_message = err or "Assertion failed",
                val = tostring(t.val),
                action = t.action,
              })
              local error_obj = error_handler.create(
                err or "Assertion failed",
                error_handler.CATEGORY.VALIDATION,
                error_handler.SEVERITY.ERROR,
                context
              )

              get_logger().debug("Assertion failed", {
                error = get_error_handler().format_error(error_obj, false),
              })

              error(get_error_handler().format_error(error_obj, false), 2)
            else
              -- Fallback without error_handler
              error(err or "unknown failure", 2)
            end
          else
            logger.trace("Assertion passed", {
              action = t.action,
              value = tostring(t.val),
            })

            -- Mark the code involved in this assertion as covered
            local coverage_mod = get_coverage()
            if coverage_mod and coverage_mod.mark_line_covered then
              local info = debug.getinfo(3, "Sl") -- 3 is the caller of the assertion
              if info and info.source and info.currentline then
                local file_path = info.source:sub(2) -- Remove the '@' prefix
                local cov_success, cov_err = pcall(function()
                  coverage_mod.mark_line_covered(file_path, info.currentline)
                end)
                if not cov_success then
                  logger.warn(
                    "Failed to mark line as covered for coverage module",
                    { action = t.action, error = cov_err }
                  )
                end
              end
            end

            -- Track assertion for quality module
            local quality_mod = get_quality_module()
            if quality_mod and quality_mod.config and quality_mod.config.enabled then
              logger.trace("[ASSERTION __CALL] About to track_assertion with quality_mod", {
                action = t.action,
                val_type = type(t.val),
              })
              -- Use pcall for safety, as quality module might not be fully initialized or could error
              local track_success, track_err = pcall(function()
                local current_test_name_from_quality = "unavailable_ctx_in_pcall"
                -- Attempt to get current test name from quality module itself if possible
                if quality_mod.get_current_test_name then -- Check if function exists
                  current_test_name_from_quality = quality_mod.get_current_test_name()
                    or "nil_test_name_from_quality_mod"
                end

                -- Log extended info about the assertion being tracked
                local val_type_for_log = type(t.val)
                if val_type_for_log == "table" and get_error_handler() and get_error_handler().is_error(t.val) then
                  val_type_for_log = "error_object" -- More specific type
                end

                get_logger().trace("Inside PCall: Calling quality_mod.track_assertion", { -- Changed from INFO to TRACE
                  action = t.action,
                  val_type_for_log = val_type_for_log, -- Use the refined val_type
                  current_test_from_quality = current_test_name_from_quality, -- Log the current test context from quality's perspective
                  is_negated = rawget(t, "negate") or false, -- Ensure negate is always boolean
                })
                quality_mod.track_assertion(t.action) -- Pass only action name
              end)
              if not track_success then
                -- Revert to warn for actual failures in tracking
                logger.warn("Failed to track assertion for quality module", {
                  action = t.action,
                  error = track_err,
                })
              end
            end
          end

          -- Store the current negate state
          local current_negate = rawget(t, "negate")

          -- Reset the action to enable proper chaining but preserve negation state
          rawset(t, "action", "")
          rawset(t, "negate", current_negate)

          -- Simple debug logging
          get_logger().trace("Assertion passed and reset for chaining", {
            value = tostring(t.val),
            negate = t.negate,
          })

          -- Return the assertion object to enable chaining
          return t
        end
      end, -- Close the __call function entry
    } -- Close the metatable definition
  )

  return assertion
end

-- Export paths to allow extensions
M.paths = paths

-- Return the module
return M
