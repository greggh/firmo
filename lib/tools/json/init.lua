-- JSON encoding/decoding module for firmo
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("tools.json")

---@class tools_json
---@field encode fun(value: any): string|nil, table? Encode a Lua value to JSON string
---@field decode fun(json: string): any|nil, table? Decode a JSON string to Lua value
---@field _VERSION string Module version
local M = {
  _VERSION = "1.0.0"
}

-- Forward declarations for recursive functions
local encode_value
local decode_value

-- Helper to escape special characters in strings
local escape_char_map = {
  ["\\"] = "\\\\",
  ["\""] = "\\\"",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t"
}

local function escape_char(c)
  return escape_char_map[c] or string.format("\\u%04x", c:byte())
end

-- Encode a string value
local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

-- Encode a table value
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

-- Encode any Lua value
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
    return nil, error_handler.validation_error(
      "Cannot encode value of type " .. val_type,
      {provided_type = val_type}
    )
  end
end

-- Encode a Lua value to JSON string
---@param value any The Lua value to encode
---@return string|nil json The JSON string, or nil on error
---@return table? error Error information if encoding failed
function M.encode(value)
  local success, result = error_handler.try(function()
    return encode_value(value)
  end)
  
  if not success then
    logger.error("Failed to encode JSON", {
      error = error_handler.format_error(result)
    })
    return nil, result
  end
  
  return result
end

-- Helper to find the next character in a string
local function next_char(str, pos)
  pos = pos + #str:match("^%s*", pos)
  return pos, str:sub(pos, pos)
end

-- Helper to parse a string value
local function parse_string(str, pos)
  local has_unicode_escape = false
  local has_escape = false
  local end_pos = pos + 1
  local quote_type = str:sub(pos, pos)
  
  while end_pos <= #str do
    local c = str:sub(end_pos, end_pos)
    
    if c == quote_type then
      if has_unicode_escape then
        return nil, error_handler.validation_error(
          "Unicode escape sequences not supported",
          {position = pos}
        )
      end
      
      local content = str:sub(pos + 1, end_pos - 1)
      if has_escape then
        content = content:gsub("\\.", {
          ["\\\""] = "\"",
          ["\\\\"] = "\\",
          ["\\/"] = "/",
          ["\\b"] = "\b",
          ["\\f"] = "\f",
          ["\\n"] = "\n",
          ["\\r"] = "\r",
          ["\\t"] = "\t"
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
  
  return nil, error_handler.validation_error(
    "Expected closing quote for string",
    {position = pos}
  )
end

-- Helper to parse a number value
local function parse_number(str, pos)
  local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
  local end_pos = pos + #num_str
  local num = tonumber(num_str)
  if not num then
    return nil, error_handler.validation_error(
      "Invalid number",
      {position = pos}
    )
  end
  return end_pos, num
end

-- Parse any JSON value
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
  elseif char == "\"" then
    return parse_string(str, pos)
  elseif char == "-" or char:match("%d") then
    return parse_number(str, pos)
  elseif char == "[" then
    local arr = {}
    local arr_pos = pos + 1
    
    arr_pos, char = next_char(str, arr_pos)
    if char == "]" then return arr_pos + 1, arr end
    
    while true do
      local val
      arr_pos, val = decode_value(str, arr_pos)
      if not arr_pos then return nil end
      table.insert(arr, val)
      
      arr_pos, char = next_char(str, arr_pos)
      if char == "]" then return arr_pos + 1, arr end
      if char ~= "," then return nil end
      arr_pos = arr_pos + 1
    end
  elseif char == "{" then
    local obj = {}
    local obj_pos = pos + 1
    
    obj_pos, char = next_char(str, obj_pos)
    if char == "}" then return obj_pos + 1, obj end
    
    while true do
      local key
      obj_pos, char = next_char(str, obj_pos)
      if char ~= "\"" then return nil end
      obj_pos, key = parse_string(str, obj_pos)
      if not obj_pos then return nil end
      
      obj_pos, char = next_char(str, obj_pos)
      if char ~= ":" then return nil end
      
      local val
      obj_pos, val = decode_value(str, obj_pos + 1)
      if not obj_pos then return nil end
      obj[key] = val
      
      obj_pos, char = next_char(str, obj_pos)
      if char == "}" then return obj_pos + 1, obj end
      if char ~= "," then return nil end
      obj_pos = obj_pos + 1
    end
  end
  
  return nil, error_handler.validation_error(
    "Invalid JSON value",
    {position = pos}
  )
end

-- Decode a JSON string to Lua value
---@param json string The JSON string to decode
---@return any|nil value The decoded Lua value, or nil on error
---@return table? error Error information if decoding failed
function M.decode(json)
  if type(json) ~= "string" then
    return nil, error_handler.validation_error(
      "Expected string",
      {provided_type = type(json)}
    )
  end
  
  local success, pos, result = error_handler.try(function()
    local pos, result = decode_value(json, 1)
    if not pos then
      return nil, error_handler.validation_error(
        "Invalid JSON",
        {json = json}
      )
    end
    return pos, result
  end)
  
  if not success then
    logger.error("Failed to decode JSON", {
      error = error_handler.format_error(pos)
    })
    return nil, pos
  end
  
  return result
end

return M