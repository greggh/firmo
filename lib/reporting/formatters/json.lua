--- JSON Formatter for Coverage Reports
---
--- Generates coverage reports in JSON format, supporting optional pretty-printing.
--- Inherits from the base Formatter class.
---
--- @module lib.reporting.formatters.json
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

--- @class CoverageReportFileStats Simplified structure expected by this formatter.
--- @field name string File path.
--- @field lines table<number, number> Map of line number to hit count.
--- @field total_lines number Total lines in file.
--- @field covered_lines number Covered lines in file.
--- @field line_coverage_percent number Coverage percentage for file.

--- @class CoverageReportSummary Simplified structure expected by this formatter.
--- @field total_files number Total number of files.
--- @field covered_files number Number of covered files.
--- @field total_lines number Total lines across all files.
--- @field covered_lines number Total covered lines across all files.
--- @field line_coverage_percent number Overall line coverage percentage.

--- @class CoverageReportData Expected structure for coverage data input (simplified).
--- @field summary CoverageReportSummary Overall summary statistics.
--- @field files table<string, CoverageReportFileStats> Map of file paths to file statistics.

---@class JSONFormatter : Formatter JSON Formatter for coverage reports.
--- Generates JSON reports with configurable pretty-printing.
---@field _VERSION string Module version.
---@field validate fun(self: JSONFormatter, coverage_data: CoverageReportData): boolean, table? Validates coverage data. Returns `true` or `false, error`.
---@field format fun(self: JSONFormatter, coverage_data: CoverageReportData, options?: { pretty_print?: boolean, indent_size?: number, stream?: boolean }): string|nil, table? Formats coverage data as a JSON string. Returns `json_string, nil` or `nil, error`.
---@field build_json fun(self: JSONFormatter, data: CoverageReportData, options: table): string Builds the JSON content. Returns JSON string.
---@field build_json_streaming fun(self: JSONFormatter, data: CoverageReportData, options: table): string Placeholder for streaming JSON generation. Returns JSON string.
---@field encode_json_value fun(self: JSONFormatter, value: any, pretty: boolean, indent_size: number, level: number): string Encodes a single Lua value to its JSON string representation. Returns JSON string. @private
---@field encode_json_object fun(self: JSONFormatter, obj: table, pretty: boolean, indent_size: number, level: number): string Encodes a Lua table (as a JSON object) to its JSON string representation. Returns JSON string. @private
---@field encode_json_array fun(self: JSONFormatter, arr: table, pretty: boolean, indent_size: number, level: number): string Encodes a Lua array to its JSON string representation. Returns JSON string. @private
---@field write fun(self: JSONFormatter, json_content: string, output_path: string, options?: table): boolean, table? Writes the JSON content to a file. Returns `true, nil` or `false, error`. @throws table If writing fails critically.
---@field register fun(formatters: table): boolean, table? Registers the JSON formatter with the main registry. Returns `true, nil` or `false, error`. @throws table If validation fails.

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler

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

local Formatter = try_require("lib.reporting.formatters.base")

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

--- Escapes a string for safe inclusion in a JSON string.
--- Handles quotes, backslashes, and control characters.
---@param s string The input string.
---@return string The escaped string.
---@private
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

--- Validates the coverage data structure. Inherits base validation.
---@param self JSONFormatter The formatter instance.
---@param coverage_data CoverageReportData The coverage data to validate.
---@return boolean success `true` if validation passes.
---@return table? error Error object if validation failed.
function JSONFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end

  -- Additional JSON-specific validation if needed

  return true
end

--- Formats coverage data into a JSON string based on the specified options.
---@param self JSONFormatter The formatter instance.
---@param coverage_data CoverageReportData The coverage data structure.
---@param options? { pretty_print?: boolean, indent_size?: number, stream?: boolean } Formatting options:
---  - `pretty_print` (boolean, default true): Enable indentation and newlines.
---  - `indent_size` (number, default 2): Number of spaces per indentation level.
---  - `stream` (boolean, default false): Use streaming (currently placeholder).
---@return string|nil json_content The generated JSON content as a single string, or `nil` on validation error.
---@return table? error Error object if validation failed.
function JSONFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, get_error_handler().validation_error("Coverage data is required", { formatter = self.name })
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

--- Builds the JSON content string using standard in-memory encoding.
---@param self JSONFormatter The formatter instance.
---@param data CoverageReportData The normalized coverage data (requires `summary`, `files`).
---@param options table Formatting options including `pretty_print`, `indent_size`.
---@return string json_content The generated JSON string.
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

--- Placeholder for building JSON using a streaming approach.
--- Currently calls the standard `build_json` method.
---@param self JSONFormatter The formatter instance.
---@param data CoverageReportData The normalized coverage data.
---@param options table Formatting options.
---@return string json_content The generated JSON string (using non-streaming method).
function JSONFormatter:build_json_streaming(data, options)
  -- For now, this is a placeholder that just uses the standard approach
  -- In a real implementation, this would use a streaming JSON encoder
  -- to handle very large datasets efficiently
  return self:build_json(data, options)
end

--- Encodes a single Lua value (nil, boolean, number, string, table) into its JSON string representation.
--- Handles pretty-printing indentation.
---@param self JSONFormatter The formatter instance.
---@param value any The Lua value to encode.
---@param pretty boolean Whether to pretty-print.
---@param indent_size number Number of spaces per indent level.
---@param level? number Current indentation level (default 0).
---@return string json_string The JSON string representation of the value.
---@private
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

--- Encodes a Lua table assumed to be a JSON object into its JSON string representation.
--- Handles pretty-printing indentation and sorts keys for deterministic output.
---@param self JSONFormatter The formatter instance.
---@param obj table The Lua table to encode as an object.
---@param pretty boolean Whether to pretty-print.
---@param indent_size number Number of spaces per indent level.
---@param level? number Current indentation level (default 0).
---@return string json_string The JSON object string representation.
---@private
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

--- Encodes a Lua table assumed to be a JSON array into its JSON string representation.
--- Handles pretty-printing indentation.
---@param self JSONFormatter The formatter instance.
---@param arr table The Lua array (sequential 1-based integer keys) to encode.
---@param pretty boolean Whether to pretty-print.
---@param indent_size number Number of spaces per indent level.
---@param level? number Current indentation level (default 0).
---@return string json_string The JSON array string representation.
---@private
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

--- Writes the generated JSON content to a file.
--- Inherits the write logic (including directory creation) from the base `Formatter`.
---@param self JSONFormatter The formatter instance.
---@param json_content string The JSON content string to write.
---@param output_path string The path to the output file.
---@param options? table Optional options passed to the base `write` method (currently unused by base).
---@return boolean success `true` if writing succeeded.
---@return table? error Error object if writing failed.
---@throws table If writing fails critically.
function JSONFormatter:write(json_content, output_path, options)
  return Formatter.write(self, json_content, output_path, options)
end

-- @param formatters table The formatters registry
---@param formatters table The main formatters registry object (must contain `coverage`, `quality`, `results` tables).
---@return boolean success `true` if registration succeeded.
---@return table? error Error object if validation failed.
---@throws table If validation fails critically.
function JSONFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    local err = get_error_handler().validation_error("Invalid formatters registry", {
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
