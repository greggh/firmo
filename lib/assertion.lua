---@class AssertionModule
---@field create_expectation fun(value: any): ExpectChain Create an expectation chain for value assertions
---@field eq fun(v1: any, v2: any, depth?: number): boolean Deep equality comparison between two values
---@field type_of fun(value: any, expected_type: string): boolean Type checking with enhanced type detection
---@field same fun(v1: any, v2: any): boolean Shallow equality comparison (alias for ==)
---@field isa fun(value: any, expected_class: string|table): boolean Check if value is instance of class
---@field near fun(v1: number, v2: number, tolerance?: number): boolean Check if numbers are close within tolerance
---@field has_error fun(fn: function, expected_error?: string): boolean Check if function raises expected error
---@field has_key fun(tbl: table, key: any): boolean Check if table has specific key
---@field has_keys fun(tbl: table, keys: table): boolean Check if table has all specified keys
---@field contains fun(tbl: table, value: any): boolean Check if table contains value
---@field contains_all fun(tbl: table, values: table): boolean Check if table contains all specified values
---@field matches fun(str: string, pattern: string): boolean Check if string matches Lua pattern
---@field is_callable fun(value: any): boolean Check if value is callable (function or has __call metatable)
---@field normalize_type fun(value: any): string Get normalized type including metatable-based types
---@field array_contains fun(array: table, value: any): boolean Check if array contains specific value
---@field is_array fun(value: any): boolean Check if value is an array-like table
---@field is_empty fun(value: table|string): boolean Check if collection is empty
---@field has_metatable fun(value: any, mt: table): boolean Check if value has specific metatable
---@field register_assertion fun(name: string, fn: function): boolean Register a custom assertion function
---@field stringify fun(value: any, depth?: number, visited?: table): string Convert any value to a readable string
---@field check_and_throw fun(condition: boolean, message: string, category?: string): boolean Check condition and throw error if false
---@field diff_values fun(v1: any, v2: any): string Generate a human-readable diff between values

--[[
    Assertion Module for the Firmo testing framework
    
    This is a standalone module for assertions that resolves circular dependencies
    and provides consistent error handling patterns. It implements the expect-style
    assertion chain API and includes comprehensive equality testing, type checking,
    and formatted error messages for test failures.
    
    Features:
    - Fluent, chainable assertion API with expect() function
    - Deep equality comparison with cycle detection and diff generation
    - Enhanced type checking beyond Lua's basic types (detects class instances)
    - Rich error messages with detailed value formatting
    - Support for custom assertions through registration
    - Collection and string validation utilities
    - Metatable-aware comparison operations
    - Expectation negation through to_not chain
    - Structured error reporting with categories and context
    - Enhanced diff algorithm for readable failure messages
    
    @module assertion
    @author Firmo Team
    @license MIT
    @copyright 2023-2025
    @version 1.0.0
]]

local M = {}

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack = table.unpack or _G.unpack

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging, _firmo, _coverage

--- Get the error handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    local success, error_handler = pcall(require, "lib.tools.error_handler")
    _error_handler = success and error_handler or nil
  end
  return _error_handler
end

--- Get the logging module with lazy loading to avoid circular dependencies
---@return table|nil The logging module or nil if not available
local function get_logging()
  if not _logging then
    local success, logging = pcall(require, "lib.tools.logging")
    _logging = success and logging or nil
  end
  return _logging
end

--- Get the coverage module with lazy loading to avoid circular dependencies
---@return table|nil The coverage module or nil if not available
local function get_coverage()
  if not _coverage then
    local success, coverage = pcall(require, "lib.coverage")
    _coverage = success and coverage or nil
  end
  return _coverage
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

---@diagnostic disable-next-line: unused-local
local logger = get_logger()

-- Utility functions

--- Check if a table contains a specific value
---@param t table The table to search in
---@param x any The value to search for
---@return boolean True if the value is found, false otherwise
local function has(t, x)
  for _, v in pairs(t) do
    if v == x then
      return true
    end
  end
  return false
end

--- Enhanced stringify function with better formatting for different types
--- and protection against cyclic references
---@param t any The value to stringify
---@param depth? number The current depth level (for recursive calls)
---@param visited? table Table of already visited objects (for cycle detection)
---@return string A string representation of the value
local function stringify(t, depth, visited)
  depth = depth or 0
  visited = visited or {}
  local indent_str = string.rep("  ", depth)

  -- Handle basic types directly
  if type(t) == "string" then
    return "'" .. tostring(t) .. "'"
  elseif type(t) == "number" or type(t) == "boolean" or type(t) == "nil" then
    return tostring(t)
  elseif type(t) ~= "table" or (getmetatable(t) and getmetatable(t).__tostring) then
    return tostring(t)
  end
  
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
---@param v1 any The first value to compare
---@param v2 any The second value to compare
---@return string A string representation of the differences
local function diff_values(v1, v2)
  -- Create a shared visited table for cyclic reference detection
  local visited = {}
  
  if type(v1) ~= "table" or type(v2) ~= "table" then
    return "Expected: " .. stringify(v2, 0, visited) .. "\nGot:      " .. stringify(v1, 0, visited)
  end

  local differences = {}

  -- Check for missing keys in v1
  for k, v in pairs(v2) do
    if v1[k] == nil then
      table.insert(differences, "Missing key: " .. stringify(k, 0, visited) .. " (expected " .. stringify(v, 0, visited) .. ")")
    elseif not M.eq(v1[k], v, 0) then
      table.insert(
        differences,
        "Different value for key "
          .. stringify(k, 0, visited)
          .. ":\n  Expected: "
          .. stringify(v, 0, visited)
          .. "\n  Got:      "
          .. stringify(v1[k], 0, visited)
      )
    end
  end

  -- Check for extra keys in v1
  for k, v in pairs(v1) do
    if v2[k] == nil then
      table.insert(differences, "Extra key: " .. stringify(k, 0, visited) .. " = " .. stringify(v, 0, visited))
    end
  end

  if #differences == 0 then
    return "Values appear equal but are not identical (may be due to metatable differences)"
  end

  return "Differences:\n  " .. table.concat(differences, "\n  ")
end

--- Deep equality check function with cycle detection
---@param t1 any First value to compare
---@param t2 any Second value to compare
---@param eps? number Epsilon for floating point comparison (default 0)
---@param visited? table Table to track visited objects for cycle detection
---@return boolean True if the values are considered equal
function M.eq(t1, t2, eps, visited)
  -- Initialize visited tables on first call
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
---@param v any The value to check
---@param x string|table The type string or metatable to check against
---@return boolean, string, string success, success_message, failure_message
function M.isa(v, x)
  if type(x) == "string" then
    return type(v) == x,
      "expected " .. tostring(v) .. " to be a " .. x,
      "expected " .. tostring(v) .. " to not be a " .. x
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
    "be_approximately",
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
    "be_date",
    "be_iso_date",
    "be_before",
    "be_after",
    "be_same_day_as",
    "complete",
    "complete_within",
    "resolve_with",
    "reject",
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
    "be_approximately",
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
    "be_date",
    "be_iso_date",
    "be_before",
    "be_after",
    "be_same_day_as",
    "complete",
    "complete_within",
    "resolve_with",
    "reject",
    chain = function(a)
      a.negate = not a.negate
    end,
  },
  a = { test = M.isa },
  an = { test = M.isa },
  falsey = {
    test = function(v)
      return not v, "expected " .. tostring(v) .. " to be falsey", "expected " .. tostring(v) .. " to not be falsey"
    end,
  },
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
    test = function(v, x)
      return v == x,
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to be the same",
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to not be the same"
    end,
  },

  at_least = {
    test = function(v, x)
      if type(v) ~= "number" or type(x) ~= "number" then
        error("expected both values to be numbers for at_least comparison")
      end
      return v >= x,
        "expected " .. tostring(v) .. " to be at least " .. tostring(x),
        "expected " .. tostring(v) .. " to not be at least " .. tostring(x)
    end,
  },

  greater_than = {
    test = function(v, x)
      if type(v) ~= "number" or type(x) ~= "number" then
        error("expected both values to be numbers for greater_than comparison")
      end
      return v > x,
        "expected " .. tostring(v) .. " to be greater than " .. tostring(x),
        "expected " .. tostring(v) .. " to not be greater than " .. tostring(x)
    end,
  },

  less_than = {
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
  exist = {
    --- @param v any The value to check for existence
    --- @return boolean, string, string result, success_message, failure_message
    test = function(v)
      return v ~= nil, "expected " .. tostring(v) .. " to exist", "expected " .. tostring(v) .. " to not exist"
    end,
  },
  
  --- Test if a value is truthy
  truthy = {
    --- @param v any The value to check if truthy
    --- @return boolean, string, string result, success_message, failure_message
    test = function(v)
      return v and true or false,
        "expected " .. tostring(v) .. " to be truthy",
        "expected " .. tostring(v) .. " to not be truthy"
    end,
  },
  
  --- Test if a value is falsy
  falsy = {
    --- @param v any The value to check if falsy
    --- @return boolean, string, string result, success_message, failure_message
    test = function(v)
      return not v and true or false,
        "expected " .. tostring(v) .. " to be falsy",
        "expected " .. tostring(v) .. " to not be falsy"
    end,
  },
  
  --- Test if a value is nil
  ["nil"] = {
    --- @param v any The value to check if nil
    --- @return boolean, string, string result, success_message, failure_message
    test = function(v)
      return v == nil, "expected " .. tostring(v) .. " to be nil", "expected " .. tostring(v) .. " to not be nil"
    end,
  },
  
  --- Test if a value is of a specific type
  type = {
    --- @param v any The value to check the type of
    --- @param expected_type string The expected type string
    --- @return boolean, string, string result, success_message, failure_message
    test = function(v, expected_type)
      return type(v) == expected_type,
        "expected " .. tostring(v) .. " to be of type " .. expected_type .. ", got " .. type(v),
        "expected " .. tostring(v) .. " to not be of type " .. expected_type
    end,
  },
  --- Test if two values are equal using deep equality comparison
  equal = {
    --- @param v any The actual value to check
    --- @param x any The expected value to compare against
    --- @param eps? number Optional epsilon for floating-point comparisons
    --- @return boolean, string, string result, success_message, failure_message
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
        "Values are not equal: " .. comparison,
        "expected " .. stringify(v) .. " and " .. stringify(x) .. " to not be equal"
    end,
  },
  have = {
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
  fail = {
    "with",
    test = function(v)
      return not pcall(v), "expected " .. tostring(v) .. " to fail", "expected " .. tostring(v) .. " to not fail"
    end,
  },
  with = {
    test = function(v, pattern)
      local ok, message = pcall(v)
      return not ok and message:match(pattern),
        "expected " .. tostring(v) .. ' to fail with error matching "' .. pattern .. '"',
        "expected " .. tostring(v) .. ' to not fail with error matching "' .. pattern .. '"'
    end,
  },
  match = {
    test = function(v, p)
      if type(v) ~= "string" then
        v = tostring(v)
      end
      local result = string.find(v, p) ~= nil
      return result,
        'expected "' .. v .. '" to match pattern "' .. p .. '"',
        'expected "' .. v .. '" to not match pattern "' .. p .. '"'
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
  have_size = {
    test = function(v, expected_size)
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
  have_property = {
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
        "expected " .. stringify(v) .. " to have property " .. tostring(property_name) .. 
        " with value " .. stringify(expected_value) .. ", got " .. 
        (has_property and stringify(v[property_name]) or "undefined"),
        "expected " .. stringify(v) .. " to not have property " .. tostring(property_name) .. 
        " with value " .. stringify(expected_value)
    end,
  },
  
  -- Schema validation
  match_schema = {
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
        elseif type(prop_def) == "string" and prop_def:match("^[a-z]+$") and 
               (prop_def == "string" or prop_def == "number" or prop_def == "boolean" or 
                prop_def == "table" or prop_def == "function" or prop_def == "thread" or 
                prop_def == "userdata" or prop_def == "nil") then
          if type(v[prop_name]) ~= prop_def then
            table.insert(type_mismatches, prop_name .. " (expected " .. prop_def .. 
                         ", got " .. type(v[prop_name]) .. ")")
          end
        -- Handle exact value schema (e.g., {status = "active"})
        elseif prop_def ~= nil then
          if not M.eq(v[prop_name], prop_def) then
            table.insert(value_mismatches, prop_name .. " (expected " .. 
                         stringify(prop_def) .. ", got " .. stringify(v[prop_name]) .. ")")
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
  change = {
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
        "expected function to change value (before: " .. stringify(before_value) .. 
        ", after: " .. stringify(after_value) .. ")",
        "expected function to not change value, but it did change from " .. 
        stringify(before_value) .. " to " .. stringify(after_value)
    end,
  },
  
  -- Check if a function increases a value
  increase = {
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
        "expected function to increase value from " .. tostring(before_value) .. 
        " but got " .. tostring(after_value),
        "expected function to not increase value from " .. tostring(before_value) .. 
        " but it did increase to " .. tostring(after_value)
    end,
  },
  
  -- Check if a function decreases a value
  decrease = {
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
        "expected function to decrease value from " .. tostring(before_value) .. 
        " but got " .. tostring(after_value),
        "expected function to not decrease value from " .. tostring(before_value) .. 
        " but it did decrease to " .. tostring(after_value)
    end,
  },
  
  -- Alias for equal with clearer name for deep comparison
  deep_equal = {
    test = function(v, x, eps)
      return M.eq(v, x, eps),
        "expected " .. stringify(v) .. " to deeply equal " .. stringify(x),
        "expected " .. stringify(v) .. " to not deeply equal " .. stringify(x)
    end
  }
}

-- Advanced regex matching with options
paths.match_regex = {
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
    
    -- Handle multiline flag
    if multiline then
      -- In multiline mode, ^ and $ match the start/end of each line
      -- Replace with markers that accomplish this in Lua patterns
      compare_pattern = compare_pattern:gsub("%^", "(^|\n)")
      compare_pattern = compare_pattern:gsub("%$", "($|\n)")
    end
    
    -- Perform the match
    local result = string.find(compare_v, compare_pattern) ~= nil
    
    -- Create user-friendly options string for error messages
    local options_str = ""
    if next(options) then
      local opts = {}
      if options.case_insensitive then table.insert(opts, "case_insensitive") end
      if options.multiline then table.insert(opts, "multiline") end
      options_str = " (with options: " .. table.concat(opts, ", ") .. ")"
    end
    
    return result,
      'expected "' .. v .. '" to match regex pattern "' .. pattern .. '"' .. options_str,
      'expected "' .. v .. '" to not match regex pattern "' .. pattern .. '"' .. options_str
  end
}
  
-- Date validation
paths.be_date = {
    test = function(v)
      -- Check if the value is a string that can be parsed as a date
      if type(v) ~= "string" then
        return false, 
          "expected " .. stringify(v) .. " to be a valid date string", 
          "expected " .. stringify(v) .. " to not be a valid date string"
      end
      
      -- Try to parse as a date using various formats
      local year, month, day
      
      -- Try YYYY-MM-DD format with optional time
      year, month, day = v:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
      if not year then
        -- Try MM/DD/YYYY format
        month, day, year = v:match("^(%d%d)/(%d%d)/(%d%d%d%d)")
      end
      if not year then
        -- Try DD/MM/YYYY format
        day, month, year = v:match("^(%d%d)/(%d%d)/(%d%d%d%d)")
      end
      
      if not (year and month and day) then
        return false,
          'expected "' .. v .. '" to be a valid date string',
          'expected "' .. v .. '" to not be a valid date string'
      end
      
      -- Convert to numbers
      year, month, day = tonumber(year), tonumber(month), tonumber(day)
      
      -- Basic validation of date components
      if month < 1 or month > 12 or day < 1 or day > 31 then
        return false,
          'expected "' .. v .. '" to be a valid date (invalid month or day)',
          'expected "' .. v .. '" to not be a valid date'
      end
      
      -- Additional validation for days in month
      local days_in_month = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
      
      -- Adjust February for leap years
      if month == 2 and (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) then
        days_in_month[2] = 29
      end
      
      if day > days_in_month[month] then
        return false,
          'expected "' .. v .. '" to be a valid date (invalid days for month)',
          'expected "' .. v .. '" to not be a valid date'
      end
      
      return true,
        'expected "' .. v .. '" to be a valid date',
        'expected "' .. v .. '" to not be a valid date'
    end
}

-- ISO date format validation
paths.be_iso_date = {
    test = function(v)
      if type(v) ~= "string" then
        return false, 
          "expected " .. stringify(v) .. " to be a valid ISO date string", 
          "expected " .. stringify(v) .. " to not be a valid ISO date string"
      end
      
      -- Check for ISO 8601 format (YYYY-MM-DDTHH:MM:SS.sssZ)
      local year, month, day, hour, minute, second = 
        v:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[Tt](%d%d):(%d%d):(%d%d)")
      
      -- If no match, check for simple ISO date (YYYY-MM-DD)
      if not year then
        year, month, day = v:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
        hour, minute, second = "00", "00", "00"
      end
      
      if not (year and month and day) then
        return false,
          'expected "' .. v .. '" to be a valid ISO date string',
          'expected "' .. v .. '" to not be a valid ISO date string'
      end
      
      -- Convert to numbers
      year, month, day = tonumber(year), tonumber(month), tonumber(day)
      hour = hour and tonumber(hour) or 0
      minute = minute and tonumber(minute) or 0
      second = second and tonumber(second) or 0
      
      -- Validate date components
      if month < 1 or month > 12 or day < 1 or day > 31 then
        return false,
          'expected "' .. v .. '" to be a valid ISO date (invalid month or day)',
          'expected "' .. v .. '" to not be a valid ISO date'
      end
      
      -- Validate time components if present
      if hour and (hour < 0 or hour > 23) then
        return false,
          'expected "' .. v .. '" to be a valid ISO date (invalid hour)',
          'expected "' .. v .. '" to not be a valid ISO date'
      end
      
      if minute and (minute < 0 or minute > 59) then
        return false,
          'expected "' .. v .. '" to be a valid ISO date (invalid minute)',
          'expected "' .. v .. '" to not be a valid ISO date'
      end
      
      if second and (second < 0 or second > 59) then
        return false,
          'expected "' .. v .. '" to be a valid ISO date (invalid second)',
          'expected "' .. v .. '" to not be a valid ISO date'
      end
      
      -- Check days in month
      local days_in_month = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
      
      -- Adjust February for leap years
      if month == 2 and (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) then
        days_in_month[2] = 29
      end
      
      if day > days_in_month[month] then
        return false,
          'expected "' .. v .. '" to be a valid ISO date (invalid days for month)',
          'expected "' .. v .. '" to not be a valid ISO date'
      end
      
      return true,
        'expected "' .. v .. '" to be a valid ISO date',
        'expected "' .. v .. '" to not be a valid ISO date'
    end
}

-- Helper function to parse date strings into components
local function parse_date(date_string)
  if type(date_string) ~= "string" then
    return nil
  end
  
  local year, month, day, hour, minute, second
  
  -- Try ISO format (YYYY-MM-DDTHH:MM:SS)
  year, month, day, hour, minute, second = 
    date_string:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[Tt](%d%d):(%d%d):(%d%d)")
  
  -- If no match, try simple ISO date (YYYY-MM-DD)
  if not year then
    year, month, day = date_string:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    hour, minute, second = "00", "00", "00"
  end
  
  -- If still no match, try MM/DD/YYYY format
  if not year then
    month, day, year = date_string:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    hour, minute, second = "00", "00", "00"
  end
  
  -- If still no match, try DD/MM/YYYY format
  if not year then
    day, month, year = date_string:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    hour, minute, second = "00", "00", "00"
  end
  
  if not (year and month and day) then
    return nil
  end
  
  return {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = hour and tonumber(hour) or 0,
    minute = minute and tonumber(minute) or 0,
    second = second and tonumber(second) or 0
  }
end

-- Helper function to compare dates
local function compare_dates(date1, date2)
  local d1 = parse_date(date1)
  local d2 = parse_date(date2)
  
  if not d1 or not d2 then
    return nil
  end
  
  -- Compare full timestamps
  if d1.year ~= d2.year then return d1.year - d2.year end
  if d1.month ~= d2.month then return d1.month - d2.month end
  if d1.day ~= d2.day then return d1.day - d2.day end
  if d1.hour ~= d2.hour then return d1.hour - d2.hour end
  if d1.minute ~= d2.minute then return d1.minute - d2.minute end
  return d1.second - d2.second
end

-- Add date and async assertions to the paths table
paths.be_before = {
  test = function(v, expected_date)
    if type(v) ~= "string" or type(expected_date) ~= "string" then
      return false, 
        "Expected a date string, got " .. type(v),
        "Expected a non-date string"
    end
    
    local result = compare_dates(v, expected_date)
    
    if result == nil then
      return false,
        'expected "' .. v .. '" and "' .. expected_date .. '" to be valid dates for comparison',
        'expected "' .. v .. '" and "' .. expected_date .. '" to not be valid dates for comparison'
    end
    
    return result < 0,
      'expected "' .. v .. '" to be before "' .. expected_date .. '"',
      'expected "' .. v .. '" to not be before "' .. expected_date .. '"'
  end
}

paths.be_after = {
  test = function(v, expected_date)
    if type(v) ~= "string" or type(expected_date) ~= "string" then
      return false, 
        "Expected a date string, got " .. type(v),
        "Expected a non-date string"
    end
    
    local result = compare_dates(v, expected_date)
    
    if result == nil then
      return false,
        'expected "' .. v .. '" and "' .. expected_date .. '" to be valid dates for comparison',
        'expected "' .. v .. '" and "' .. expected_date .. '" to not be valid dates for comparison'
    end
    
    return result > 0,
      'expected "' .. v .. '" to be after "' .. expected_date .. '"',
      'expected "' .. v .. '" to not be after "' .. expected_date .. '"'
  end
}

paths.be_same_day_as = {
  test = function(v, expected_date)
    if type(v) ~= "string" or type(expected_date) ~= "string" then
      return false, 
        "Expected a date string, got " .. type(v),
        "Expected a non-date string"
    end
    
    local d1 = parse_date(v)
    local d2 = parse_date(expected_date)
    
    if not d1 or not d2 then
      return false,
        'expected "' .. v .. '" and "' .. expected_date .. '" to be valid dates for comparison',
        'expected "' .. v .. '" and "' .. expected_date .. '" to not be valid dates for comparison'
    end
    
    return d1.year == d2.year and d1.month == d2.month and d1.day == d2.day,
      'expected "' .. v .. '" to be the same day as "' .. expected_date .. '"',
      'expected "' .. v .. '" to not be the same day as "' .. expected_date .. '"'
  end
}

-- Async assertions
paths.complete = {
  test = function(async_fn, timeout)
    if type(async_fn) ~= "function" then
      error("Expected a promise, got " .. type(async_fn))
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
      if select('#', ...) > 0 then
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
      async_module.wait_until(function() return completed end, timeout)
    end)
    
    -- If there was an error running the function, throw it
    if error_value then
      error(error_value)
    end
    
    -- If wait_until timed out, wait_result will be false
    return wait_result,
      "async operation did not complete within " .. timeout .. "ms",
      "async operation completed when it was expected to timeout"
  end
}

paths.complete_within = {
  test = function(async_fn, timeout)
    if type(async_fn) ~= "function" then
      error("Expected a promise, got " .. type(async_fn))
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
      if select('#', ...) > 0 then
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
      async_module.wait_until(function() return completed end, timeout)
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
  end
}

paths.resolve_with = {
  test = function(async_fn, expected_value, timeout)
    if type(async_fn) ~= "function" then
      error("Expected a promise, got " .. type(async_fn))
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
      if select('#', ...) > 0 then
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
      async_module.wait_until(function() return completed end, timeout)
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
      "expected async operation to resolve with " .. stringify(expected_value) .. 
      " but got " .. stringify(result_value),
      "expected async operation to not resolve with " .. stringify(expected_value)
  end
}

paths.reject = {
  test = function(async_fn, error_pattern, timeout)
    if type(async_fn) ~= "function" then
      error("Expected a promise, got " .. type(async_fn))
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
      async_module.wait_until(function() return completed end, timeout)
    end)
    
    -- If wait_until timed out
    if not wait_result then
      return false, "async operation did not complete within " .. timeout .. "ms", nil
    end
    
    -- If error pattern is provided, check that the error matches
    if error_pattern and rejected then
      local matches_pattern = type(error_message) == "string" and 
                            string.find(error_message, error_pattern) ~= nil
      
      if not matches_pattern then
        return false, 
          "expected async operation to reject with error matching " .. 
          stringify(error_pattern) .. " but got " .. stringify(error_message),
          nil
      end
    end
    
    return rejected,
      "expected async operation to reject with an error" .. 
      (error_pattern and " matching " .. stringify(error_pattern) or ""),
      "expected async operation to not reject with an error"
  end
}

-- Continue adding assertions to the paths table

-- Check if a table contains all specified keys 
paths.keys = {
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
  end
}

-- Check if a table contains a specific key
paths.key = {
  test = function(v, x)
    if type(v) ~= "table" then
      error("expected " .. tostring(v) .. " to be a table")
    end

    return v[x] ~= nil,
      "expected " .. stringify(v) .. " to contain key " .. tostring(x),
      "expected " .. stringify(v) .. " to not contain key " .. tostring(x)
  end
}

-- Numeric comparison assertions
paths.be_greater_than = {
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
  end
}

paths.be_less_than = {
  test = function(v, x)
    if type(v) ~= "number" then
      error("expected " .. tostring(v) .. " to be a number")
    end

    if type(x) ~= "number" then
      error("expected " .. tostring(x) .. " to be a number")
    end

    return v < x,
      "expected " .. tostring(v) .. " to be less than " .. tostring(x),
      "expected " .. tostring(v) .. " to not be less than " .. tostring(x)
  end
}
  
-- Check if a value is empty (string, table)
paths.empty = {
  test = function(v)
    if type(v) == "string" then
      return v == "",
        'expected string "' .. v .. '" to be empty',
        'expected string to not be empty'
    elseif type(v) == "table" then
      return next(v) == nil,
        "expected table to be empty, but it has " .. 
        (function() 
          local count = 0
          for _ in pairs(v) do count = count + 1 end
          return count
        end)() .. " elements",
        "expected table to not be empty"
    else
      error("cannot check emptiness of a " .. type(v))
    end
  end
}
  
-- Check if a number is positive
paths.positive = {
  test = function(v)
    if type(v) ~= "number" then
      error("expected " .. tostring(v) .. " to be a number")
    end
    
    return v > 0,
      "expected " .. tostring(v) .. " to be positive",
      "expected " .. tostring(v) .. " to not be positive"
  end
}
  
-- Check if a number is negative
paths.negative = {
  test = function(v)
    if type(v) ~= "number" then
      error("expected " .. tostring(v) .. " to be a number")
    end
    
    return v < 0,
      "expected " .. tostring(v) .. " to be negative",
      "expected " .. tostring(v) .. " to not be negative"
  end
}
  
-- Check if a number is an integer
paths.integer = {
  test = function(v)
    if type(v) ~= "number" then
      error("expected " .. tostring(v) .. " to be a number")
    end
    
    return v == math.floor(v),
      "expected " .. tostring(v) .. " to be an integer",
      "expected " .. tostring(v) .. " to not be an integer"
  end
}
  
-- Check if a string is all uppercase
paths.uppercase = {
  test = function(v)
    if type(v) ~= "string" then
      error("expected " .. tostring(v) .. " to be a string")
    end
    
    return v == string.upper(v),
      'expected string "' .. v .. '" to be uppercase',
      'expected string "' .. v .. '" to not be uppercase'
  end
}
  
-- Check if a string is all lowercase
paths.lowercase = {
  test = function(v)
    if type(v) ~= "string" then
      error("expected " .. tostring(v) .. " to be a string")
    end
    
    return v == string.lower(v),
      'expected string "' .. v .. '" to be lowercase',
      'expected string "' .. v .. '" to not be lowercase'
  end
}

paths.be_between = {
  test = function(v, min, max)
    if type(v) ~= "number" then
      error("expected " .. tostring(v) .. " to be a number")
    end

    if type(min) ~= "number" or type(max) ~= "number" then
      error("expected min and max to be numbers")
    end

    return v >= min and v <= max,
      "expected " .. tostring(v) .. " to be between " .. tostring(min) .. " and " .. tostring(max),
      "expected " .. tostring(v) .. " to not be between " .. tostring(min) .. " and " .. tostring(max)
  end
}

paths.be_truthy = {
  test = function(v)
    return v and true or false,
      "expected " .. tostring(v) .. " to be truthy",
      "expected " .. tostring(v) .. " to not be truthy"
  end
}

paths.be_falsy = {
  test = function(v)
    return not v, "expected " .. tostring(v) .. " to be falsy", "expected " .. tostring(v) .. " to not be falsy"
  end
}

paths.be_falsey = {
  test = function(v)
    return not v, "expected " .. tostring(v) .. " to be falsey", "expected " .. tostring(v) .. " to not be falsey"
  end
}

paths.be_approximately = {
  test = function(v, x, delta)
    if type(v) ~= "number" then
      error("expected " .. tostring(v) .. " to be a number")
    end

    if type(x) ~= "number" then
      error("expected " .. tostring(x) .. " to be a number")
    end

    delta = delta or 0.0001

    return math.abs(v - x) <= delta,
      "expected " .. tostring(v) .. " to be approximately " .. tostring(x) .. " (±" .. tostring(delta) .. ")",
      "expected " .. tostring(v) .. " to not be approximately " .. tostring(x) .. " (±" .. tostring(delta) .. ")"
  end
}

-- Satisfy assertion for custom predicates
paths.satisfy = {
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
  end
}

-- String assertions
paths.start_with = {
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
  end
}

paths.end_with = {
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
  end
}

-- Type checking assertions
paths.be_type = {
  callable = true,
  comparable = true,
  iterable = true,
  test = function(v, expected_type)
    if expected_type == "callable" then
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
  end
}

-- Enhanced error assertions
paths.throw = {
  error = true,
  error_matching = true,
  error_type = true,
  test = function(v)
    if type(v) ~= "function" then
      error("expected " .. tostring(v) .. " to be a function")
    end

    ---@diagnostic disable-next-line: unused-local
    local ok, err = pcall(v)
    return not ok, "expected function to throw an error", "expected function to not throw an error"
  end
}

paths.error = {
  test = function(v)
    if type(v) ~= "function" then
      error("expected " .. tostring(v) .. " to be a function")
    end

    ---@diagnostic disable-next-line: unused-local
    local ok, err = pcall(v)
    return not ok, "expected function to throw an error", "expected function to not throw an error"
  end
}

paths.error_matching = {
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
  end
}

paths.error_type = {
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
  end
}

---@class ExpectChain
---@field val any The value being tested
---@field action string The current assertion action
---@field negate boolean Whether the assertion is negated
---@field to ExpectChain Reference to self for chaining positive assertions
---@field to_not ExpectChain Reference to self for chaining negated assertions
---@field a fun(type: string): ExpectChain Assert value is of specified type (shorthand for be.a)
---@field an fun(type: string): ExpectChain Assert value is of specified type (alias for a)
---@field be table<string, function> Group of assertions for value state/type
---@field be.a fun(type: string): ExpectChain Assert value is of specified type
---@field be.truthy fun(): ExpectChain Assert value is truthy (evaluates to true in a conditional)
---@field be.falsy fun(): ExpectChain Assert value is falsy (evaluates to false in a conditional)
---@field be.empty fun(): ExpectChain Assert value is an empty collection
---@field be.positive fun(): ExpectChain Assert value is a positive number
---@field be.negative fun(): ExpectChain Assert value is a negative number
---@field be.integer fun(): ExpectChain Assert value is an integer (no decimal component)
---@field be.uppercase fun(): ExpectChain Assert string is all uppercase
---@field be.lowercase fun(): ExpectChain Assert string is all lowercase
---@field equal fun(expected: any): ExpectChain Assert deep equality with expected value
---@field exist fun(): ExpectChain Assert value is not nil
---@field match fun(pattern: string): ExpectChain Assert string matches Lua pattern
---@field contain fun(value: any): ExpectChain Assert collection contains value
---@field have fun(key: any): ExpectChain Assert table has specific key
---@field have_length fun(length: number): ExpectChain Assert collection has specific length
---@field have_property fun(property: string, value?: any): ExpectChain Assert object has property with optional value
---@field be_type fun(type: string): ExpectChain Assert value is of specified type
---@field be_greater_than fun(value: number): ExpectChain Assert number is greater than value
---@field be_less_than fun(value: number): ExpectChain Assert number is less than value
---@field be_between fun(min: number, max: number): ExpectChain Assert number is between min and max
---@field start_with fun(prefix: string): ExpectChain Assert string starts with prefix
---@field end_with fun(suffix: string): ExpectChain Assert string ends with suffix
---@field throw fun(): ExpectChain Assert function throws an error
---@field throw.error fun(): ExpectChain Assert function throws an error (alias)
---@field throw.error_matching fun(pattern: string): ExpectChain Assert function throws error matching pattern
---@field throw.error_type fun(type: string): ExpectChain Assert function throws error of specific type
---@field match_schema fun(schema: table): ExpectChain Assert object matches specified schema
---@field change fun(getter: function): ExpectChain Assert function changes value returned by getter
---@field increase fun(getter: function): ExpectChain Assert function increases value returned by getter
---@field decrease fun(getter: function): ExpectChain Assert function decreases value returned by getter

--- Main expect function for creating assertions
---@param v any The value to create assertions for
---@return ExpectChain An assertion object with chainable assertion methods
function M.expect(v)
  ---@diagnostic disable-next-line: unused-local
  local error_handler = get_error_handler()
  local logger = get_logger()

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

  setmetatable(assertion, {
    __index = function(t, k)
      if has(paths[rawget(t, "action")], k) then
        rawset(t, "action", k)
        local chain = paths[rawget(t, "action")].chain
        if chain then
          chain(t)
        end
        return t
      end
      return rawget(t, k)
    end,
    __call = function(t, ...)
      if paths[t.action].test then
        local success, err, nerr

        -- Use error_handler.try if available for structured error handling
        local error_handler = get_error_handler()
        if error_handler then
          local args = { ... }
          local try_success, try_result = error_handler.try(function()
            local res, e, ne = paths[t.action].test(t.val, unpack(args))
            return { res = res, err = e, nerr = ne }
          end)

          if try_success then
            success, err, nerr = try_result.res, try_result.err, try_result.nerr
          else
            -- Handle error in test function
            logger.error("Error in assertion test function", {
              action = t.action,
              error = error_handler.format_error(try_result),
            })
            error(try_result.message or "Error in assertion test function", 2)
          end
        else
          -- Fallback if error_handler is not available
          local args = { ... }
          success, err, nerr = paths[t.action].test(t.val, unpack(args))
        end

        if assertion.negate then
          success = not success
          err = nerr or err
        end

        if not success then
          if error_handler then
            -- Create a structured error
            local context = {
              expected = select(1, ...),
              actual = t.val,
              action = t.action,
              negate = assertion.negate,
            }

            local error_obj = error_handler.create(
              err or "Assertion failed",
              error_handler.CATEGORY.VALIDATION,
              error_handler.SEVERITY.ERROR,
              context
            )

            logger.debug("Assertion failed", {
              error = error_handler.format_error(error_obj, false),
            })

            error(error_handler.format_error(error_obj, false), 2)
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
          -- This is what creates the distinction between "executed" and "covered" in the coverage report
          local coverage = get_coverage()
          if coverage and coverage.mark_line_covered then
            -- Get the current stack frame to find where the assertion is happening
            local info = debug.getinfo(3, "Sl") -- 3 is the caller of the assertion
            if info and info.source and info.currentline then
              local file_path = info.source:sub(2) -- Remove the '@' prefix
              
              -- Use the public API to mark the line as covered, which is safe and general
              local success, err = pcall(function()
                coverage.mark_line_covered(file_path, info.currentline)
              end)
              
              -- Disable logging to improve performance
              -- Log was causing excessive output and performance issues
              -- if success then
              --   logger.debug("Marked line as covered from assertion", {
              --     file_path = file_path,
              --     line_number = info.currentline
              --   })
              -- else
              --   logger.debug("Failed to mark line as covered", {
              --     file_path = file_path,
              --     line_number = info.currentline,
              --     error = tostring(err)
              --   })
              -- end
            end
          end
        end
      end
    end,
  })

  return assertion
end

-- Export paths to allow extensions
M.paths = paths

-- Return the module
return M
