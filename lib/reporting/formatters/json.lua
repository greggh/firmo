--- JSON Formatter for Coverage Reports
-- Generates JSON coverage reports with proper JSON structure and formatting
-- @module reporting.formatters.json
-- @author Firmo Team
-- @version 1.0.0

local Formatter = require("lib.reporting.formatters.base")
local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")

-- Create JSON formatter class
local JSONFormatter = Formatter.extend("json", "json")

--- JSON Formatter version
JSONFormatter._VERSION = "1.0.0"

-- JSON escape sequences
local json_escape_chars = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["/"] = "\\/",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

-- Escape a string for JSON output
local function json_escape(s)
  if type(s) ~= "string" then
    s = tostring(s)
  end

  return (s:gsub('["\\/\b\f\n\r\t]', json_escape_chars))
    -- Also escape Unicode characters
    :gsub("[\x00-\x1F\x7F-\xFF]", function(c)
      return string.format("\\u%04x", string.byte(c))
    end)
end

-- Validate coverage data structure for JSON formatter
function JSONFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end

  -- Additional JSON-specific validation if needed

  return true
end

-- Format coverage data as JSON
function JSONFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, error_handler.validation_error("Coverage data is required", { formatter = self.name })
  end

  -- Apply options with defaults
  options = options or {}
  options.pretty_print = options.pretty_print ~= false -- Default to true
  options.indent_size = options.indent_size or 2

  -- Normalize the coverage data
  local normalized_data = self:normalize_coverage_data(coverage_data)

  -- Begin building JSON content
  local json

  -- Use streaming approach for large data sets
  if options.stream then
    json = self:build_json_streaming(normalized_data, options)
  else
    json = self:build_json(normalized_data, options)
  end

  return json
end

-- Build JSON using standard approach (all in memory)
function JSONFormatter:build_json(data, options)
  -- Determine indentation
  local indent = ""
  local pretty = options.pretty_print
  local newline = pretty and "\n" or ""

  if pretty then
    indent = string.rep(" ", options.indent_size or 2)
  end

  -- Build coverage report JSON
  return self:encode_json_object({
    version = self._VERSION,
    timestamp = os.time(),
    generated_at = os.date("%Y-%m-%dT%H:%M:%SZ", os.time()),
    metadata = {
      tool = "Firmo Coverage",
      format = "json",
    },
    summary = data.summary,
    files = data.files,
  }, pretty, options.indent_size or 2)
end

-- Build JSON using streaming approach for large datasets
function JSONFormatter:build_json_streaming(data, options)
  -- For now, this is a placeholder that just uses the standard approach
  -- In a real implementation, this would use a streaming JSON encoder
  -- to handle very large datasets efficiently
  return self:build_json(data, options)
end

-- JSON encoder functions
function JSONFormatter:encode_json_value(value, pretty, indent_size, level)
  level = level or 0
  local indent = pretty and string.rep(" ", level * indent_size) or ""
  local indent_next = pretty and string.rep(" ", (level + 1) * indent_size) or ""
  local newline = pretty and "\n" or ""

  -- Handle nil
  if value == nil then
    return "null"
  -- Handle booleans
  elseif type(value) == "boolean" then
    return value and "true" or "false"
  -- Handle numbers
  elseif type(value) == "number" then
    -- Handle NaN and Infinity
    if value ~= value then -- NaN
      return "null"
    elseif value >= math.huge then -- Infinity
      return "null"
    elseif value <= -math.huge then -- -Infinity
      return "null"
    else
      return tostring(value)
    end
  -- Handle strings
  elseif type(value) == "string" then
    return '"' .. json_escape(value) .. '"'
  -- Handle tables
  elseif type(value) == "table" then
    -- Check if it's an array
    local is_array = true
    local max_index = 0
    for k, _ in pairs(value) do
      if type(k) ~= "number" or k < 1 or k > #value or math.floor(k) ~= k then
        is_array = false
        break
      end
      max_index = math.max(max_index, k)
    end

    is_array = is_array and max_index == #value

    if is_array then
      return self:encode_json_array(value, pretty, indent_size, level)
    else
      return self:encode_json_object(value, pretty, indent_size, level)
    end
  -- Handle other types (functions, userdata, etc.)
  else
    return "null"
  end
end

function JSONFormatter:encode_json_object(obj, pretty, indent_size, level)
  level = level or 0
  local indent = pretty and string.rep(" ", level * indent_size) or ""
  local indent_next = pretty and string.rep(" ", (level + 1) * indent_size) or ""
  local newline = pretty and "\n" or ""

  -- Empty object
  if not obj or not next(obj) then
    return "{}"
  end

  -- Start object
  local result = "{" .. newline

  -- Sort keys for deterministic output
  local keys = {}
  for k in pairs(obj) do
    table.insert(keys, k)
  end
  table.sort(keys)

  -- Add key-value pairs
  for i, k in ipairs(keys) do
    local v = obj[k]
    result = result
      .. indent_next
      .. '"'
      .. json_escape(k)
      .. '": '
      .. self:encode_json_value(v, pretty, indent_size, level + 1)

    if i < #keys then
      result = result .. ","
    end

    result = result .. newline
  end

  -- End object
  result = result .. indent .. "}"

  return result
end

function JSONFormatter:encode_json_array(arr, pretty, indent_size, level)
  level = level or 0
  local indent = pretty and string.rep(" ", level * indent_size) or ""
  local indent_next = pretty and string.rep(" ", (level + 1) * indent_size) or ""
  local newline = pretty and "\n" or ""

  -- Empty array
  if #arr == 0 then
    return "[]"
  end

  -- Start array
  local result = "[" .. newline

  -- Add values
  for i, v in ipairs(arr) do
    result = result .. indent_next .. self:encode_json_value(v, pretty, indent_size, level + 1)

    if i < #arr then
      result = result .. ","
    end

    result = result .. newline
  end

  -- End array
  result = result .. indent .. "]"

  return result
end

-- Write the report to the filesystem
function JSONFormatter:write(json_content, output_path, options)
  return Formatter.write(self, json_content, output_path, options)
end

--- Register the JSON formatter with the formatters registry
-- @param formatters table The formatters registry
-- @return boolean success Whether registration was successful
function JSONFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    local err = error_handler.validation_error("Invalid formatters registry", {
      operation = "register",
      formatter = "json",
      provided_type = type(formatters),
    })
    return false, err
  end

  -- Create a new instance of the formatter
  local formatter = JSONFormatter.new()

  -- Register format_coverage function
  formatters.coverage.json = function(coverage_data, options)
    return formatter:format(coverage_data, options)
  end

  return true
end

return JSONFormatter
