--- JSON Encode/Decode Utilities
---
--- Provides functions for encoding Lua values to JSON strings and decoding
--- JSON strings back into Lua values. Includes basic error handling.
---
--- @module lib.tools.json
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the success handler module with lazy loading to avoid circular dependencies
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
    return logging.get_logger("tools.json")
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

---@class tools_json
---@field encode fun(value: any): string|nil, table? Encode a Lua value to JSON string
---@field decode fun(json: string): any|nil, table? Decode a JSON string to Lua value
---@field _VERSION string Module version
local M = {
  _VERSION = "1.0.0",
}

-- Forward declarations for recursive functions
local encode_value
local decode_value

-- Helper to escape special characters in strings
local escape_char_map = {
  ["\\"] = "\\\\",
  ['"'] = '\\"',
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

--- Helper for JSON string escaping.
---@param c string Single character to escape.
---@return string Escaped character or unicode escape.
---@private
local function escape_char(c)
  return escape_char_map[c] or string.format("\\u%04x", c:byte())
end

--- Encodes a Lua string into a JSON string literal.
---@param val string Input string.
---@return string JSON string literal.
---@private
local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

--- Encodes a Lua table into a JSON array or object literal.
--- Detects if it's a sequence (array) or map (object).
---@param val table Input table.
---@return string JSON array or object literal.
---@private
local function encode_table(val)
  local is_array = true
  local max_index = 0

  -- Check if table is an array
  for k, _ in pairs(val) do
    if type(k) == "number" and k > 0 and math.floor(k) == k then
      max_index = math.max(max_index, k)
    else
      is_array = false
      break
    end
  end

  -- Encode as array
  if is_array then
    local parts = {}
    for i = 1, max_index do
      parts[i] = encode_value(val[i])
    end
    return "[" .. table.concat(parts, ",") .. "]"
  end

  -- Encode as object
  local parts = {}
  for k, v in pairs(val) do
    if type(k) == "string" then
      table.insert(parts, encode_string(k) .. ":" .. encode_value(v))
    end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

--- Encodes a single Lua value into its JSON string representation.
--- Handles nil, boolean, number (including NaN/Infinity as null), string, and table types.
---@param val any The Lua value to encode.
---@return string|nil json_value Encoded JSON value string, or nil on error.
---@return table? error Error object if value type is unsupported.
---@private
function encode_value(val)
  local val_type = type(val)
  if val_type == "nil" then
    return "null"
  elseif val_type == "boolean" then
    return tostring(val)
  elseif val_type == "number" then
    -- Handle special cases
    if val ~= val then -- NaN
      return "null"
    elseif val >= math.huge then -- Infinity
      return "null"
    elseif val <= -math.huge then -- -Infinity
      return "null"
    else
      return string.format("%.14g", val)
    end
  elseif val_type == "string" then
    return encode_string(val)
  elseif val_type == "table" then
    return encode_table(val)
  else
    return nil, error_handler.validation_error("Cannot encode value of type " .. val_type, { provided_type = val_type })
  end
end

-- Encode a Lua value to JSON string
---@param value any The Lua value to encode.
---@return string|nil json The JSON string, or `nil` on error.
---@return table? error An `error_handler` object if encoding failed (e.g., unsupported type).
function M.encode(value)
  local success, result = get_error_handler().try(function()
    return encode_value(value)
  end)

  if not success then
    get_logger().error("Failed to encode JSON", {
      error = error_handler.format_error(result),
    })
    return nil, result
  end

  return result
end

--- Skips whitespace and returns the next non-whitespace character and position.
---@param str string Input string.
---@param pos number Current position.
---@return number|nil next_pos New position after non-whitespace char, or nil if end reached.
---@return string? char The next non-whitespace character, or nil if end reached.
---@private
local function next_char(str, pos)
  pos = pos + #str:match("^%s*", pos)
  return pos, str:sub(pos, pos)
end

--- Parses a JSON string literal from the input string, handling escapes.
--- Note: Currently throws an error for unsupported Unicode escapes (`\uXXXX`).
---@param str string Input JSON string.
---@param pos number Starting position (at the opening quote).
---@return number|nil next_pos Position after the closing quote, or `nil` on error.
---@return string? value The parsed string value, or `nil` on error.
---@return table? error Error object if parsing failed (e.g., missing closing quote, unsupported escape).
---@private
local function parse_string(str, pos)
  local has_unicode_escape = false
  local has_escape = false
  local end_pos = pos + 1
  local quote_type = str:sub(pos, pos)

  while end_pos <= #str do
    local c = str:sub(end_pos, end_pos)

    if c == quote_type then
      if has_unicode_escape then
        return nil, get_error_handler().validation_error("Unicode escape sequences not supported", { position = pos })
      end

      local content = str:sub(pos + 1, end_pos - 1)
      if has_escape then
        content = content:gsub("\\.", {
          ['\\"'] = '"',
          ["\\\\"] = "\\",
          ["\\/"] = "/",
          ["\\b"] = "\b",
          ["\\f"] = "\f",
          ["\\n"] = "\n",
          ["\\r"] = "\r",
          ["\\t"] = "\t",
        })
      end

      return end_pos + 1, content
    end

    if c == "\\" then
      has_escape = true
      local next_c = str:sub(end_pos + 1, end_pos + 1)
      if next_c == "u" then
        has_unicode_escape = true
      end
      end_pos = end_pos + 1
    end

    end_pos = end_pos + 1
  end

  return nil, get_error_handler().validation_error("Expected closing quote for string", { position = pos })
end

--- Parses a JSON number literal from the input string.
---@param str string Input JSON string.
---@param pos number Starting position (at the number).
---@return number|nil next_pos Position after the number, or `nil` on error.
---@return number? value The parsed number value, or `nil` on error.
---@return table? error Error object if parsing failed (invalid number format).
---@private
local function parse_number(str, pos)
  local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
  local end_pos = pos + #num_str
  local num = tonumber(num_str)
  if not num then
    return nil, get_error_handler().validation_error("Invalid number", { position = pos })
  end
  return end_pos, num
end

--- Parses any JSON value (null, boolean, number, string, array, object) from the input string.
--- This is the core recursive descent parser.
---@param str string Input JSON string.
---@param pos number Current position.
---@return number|nil next_pos Position after the parsed value, or `nil` on error.
---@return any? value The parsed Lua value, or `nil` on error.
---@return table? error Error object if parsing failed (invalid JSON syntax or value).
---@private
function decode_value(str, pos)
  pos, char = next_char(str, pos)

  if char == "n" then
    if str:sub(pos, pos + 3) == "null" then
      return pos + 4, nil
    end
  elseif char == "t" then
    if str:sub(pos, pos + 3) == "true" then
      return pos + 4, true
    end
  elseif char == "f" then
    if str:sub(pos, pos + 4) == "false" then
      return pos + 5, false
    end
  elseif char == '"' then
    return parse_string(str, pos)
  elseif char == "-" or char:match("%d") then
    return parse_number(str, pos)
  elseif char == "[" then
    local arr = {}
    local arr_pos = pos + 1

    arr_pos, char = next_char(str, arr_pos)
    if char == "]" then
      return arr_pos + 1, arr
    end

    while true do
      local val
      arr_pos, val = decode_value(str, arr_pos)
      if not arr_pos then
        return nil
      end
      table.insert(arr, val)

      arr_pos, char = next_char(str, arr_pos)
      if char == "]" then
        return arr_pos + 1, arr
      end
      if char ~= "," then
        return nil
      end
      arr_pos = arr_pos + 1
    end
  elseif char == "{" then
    local obj = {}
    local obj_pos = pos + 1

    obj_pos, char = next_char(str, obj_pos)
    if char == "}" then
      return obj_pos + 1, obj
    end

    while true do
      local key
      obj_pos, char = next_char(str, obj_pos)
      if char ~= '"' then
        return nil
      end
      obj_pos, key = parse_string(str, obj_pos)
      if not obj_pos then
        return nil
      end

      obj_pos, char = next_char(str, obj_pos)
      if char ~= ":" then
        return nil
      end

      local val
      obj_pos, val = decode_value(str, obj_pos + 1)
      if not obj_pos then
        return nil
      end
      obj[key] = val

      obj_pos, char = next_char(str, obj_pos)
      if char == "}" then
        return obj_pos + 1, obj
      end
      if char ~= "," then
        return nil
      end
      obj_pos = obj_pos + 1
    end
  end

  return nil, get_error_handler().validation_error("Invalid JSON value", { position = pos })
end

-- Decode a JSON string to Lua value
---@param json string The JSON string to decode
---@return any|nil value The decoded Lua value, or nil on error
---@return table? error An `error_handler` object if decoding failed (e.g., invalid JSON syntax, unsupported value).
---@throws table If input validation fails (e.g., `json` is not a string).
function M.decode(json)
  if type(json) ~= "string" then
    return nil, get_error_handler().validation_error("Expected string", { provided_type = type(json) })
  end

  local success, pos, result = error_handler.try(function()
    local pos, result = decode_value(json, 1)
    if not pos then
      return nil, get_error_handler().validation_error("Invalid JSON", { json = json })
    end
    return pos, result
  end)

  if not success then
    get_logger().error("Failed to decode JSON", {
      error = get_error_handler().format_error(pos),
    })
    return nil, pos
  end

  return result
end

return M
