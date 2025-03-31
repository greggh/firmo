-- Source map for mapping instrumented code back to original source
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.instrumentation.sourcemap")

---@class coverage_v3_instrumentation_sourcemap
---@field create fun(path: string, original_content: string, instrumented_content: string): table|nil Create a source map
---@field get_instrumented_line fun(map: table, original_line: number): number|nil Map original line to instrumented line
---@field get_original_line fun(map: table, instrumented_line: number): number|nil Map instrumented line to original line
---@field serialize fun(map: table): string Serialize source map to string
---@field deserialize fun(serialized: string): table|nil Deserialize source map from string
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Validate inputs
local function validate_inputs(path, original_content, instrumented_content)
  if not path or type(path) ~= "string" or path == "" then
    return nil, error_handler.validation_error(
      "Invalid path",
      { path = path }
    )
  end
  if not original_content or type(original_content) ~= "string" then
    return nil, error_handler.validation_error(
      "Invalid content",
      { content = original_content }
    )
  end
  if not instrumented_content or type(instrumented_content) ~= "string" then
    return nil, error_handler.validation_error(
      "Invalid content",
      { content = instrumented_content }
    )
  end
  return true
end

-- Create a source map
---@param path string Path to the original file
---@param original_content string Content of original file
---@param instrumented_content string Content of instrumented file
---@return table|nil map Source map object, or nil if creation failed
---@return string? error Error message if creation failed
function M.create(path, original_content, instrumented_content)
  -- Validate inputs
  local ok, err = validate_inputs(path, original_content, instrumented_content)
  if not ok then
    return nil, err
  end

  -- Create map structure
  local map = {
    path = fs.normalize_path(path),
    original_to_instrumented = {},  -- Map original lines to instrumented lines
    instrumented_to_original = {},  -- Map instrumented lines to original lines
  }

  -- Split content into lines
  local original_lines = {}
  for line in original_content:gmatch("[^\n]*") do
    table.insert(original_lines, line)
  end
  local instrumented_lines = {}
  for line in instrumented_content:gmatch("[^\n]*") do
    table.insert(instrumented_lines, line)
  end

  -- Build line mappings by matching non-tracking lines
  local orig_idx = 1
  local inst_idx = 1
  while orig_idx <= #original_lines and inst_idx <= #instrumented_lines do
    local orig_line = original_lines[orig_idx]
    local inst_line = instrumented_lines[inst_idx]

    -- Skip tracking lines in instrumented code
    if inst_line:match("_firmo_coverage%.track") then
      inst_idx = inst_idx + 1
    -- Lines match (ignoring whitespace)
    elseif orig_line:gsub("%s+", "") == inst_line:gsub("%s+", "") then
      map.original_to_instrumented[orig_idx] = inst_idx
      map.instrumented_to_original[inst_idx] = orig_idx
      orig_idx = orig_idx + 1
      inst_idx = inst_idx + 1
    -- Lines don't match, try next instrumented line
    else
      inst_idx = inst_idx + 1
    end
  end

  logger.debug("Created source map", {
    path = path,
    original_lines = #original_lines,
    instrumented_lines = #instrumented_lines,
    mappings = #map.original_to_instrumented
  })

  return map
end

-- Map original line to instrumented line
---@param map table Source map object
---@param original_line number Line number in original file
---@return number|nil instrumented_line Line number in instrumented file, or nil if not found
---@return string? error Error message if mapping failed
function M.get_instrumented_line(map, original_line)
  if not map or type(map) ~= "table" then
    return nil, error_handler.validation_error("Invalid source map")
  end
  if not original_line or type(original_line) ~= "number" then
    return nil, error_handler.validation_error("Invalid line number")
  end

  local instrumented_line = map.original_to_instrumented[original_line]
  if not instrumented_line then
    return nil, error_handler.not_found_error(
      "Invalid line number",
      { line = original_line }
    )
  end

  return instrumented_line
end

-- Map instrumented line to original line
---@param map table Source map object
---@param instrumented_line number Line number in instrumented file
---@return number|nil original_line Line number in original file, or nil if not found
---@return string? error Error message if mapping failed
function M.get_original_line(map, instrumented_line)
  if not map or type(map) ~= "table" then
    return nil, error_handler.validation_error("Invalid source map")
  end
  if not instrumented_line or type(instrumented_line) ~= "number" then
    return nil, error_handler.validation_error("Invalid line number")
  end

  local original_line = map.instrumented_to_original[instrumented_line]
  if not original_line then
    return nil, error_handler.not_found_error(
      "Invalid line number",
      { line = instrumented_line }
    )
  end

  return original_line
end

-- Serialize source map to string
---@param map table Source map object
---@return string serialized Serialized source map
function M.serialize(map)
  return error_handler.serialize(map)
end

-- Deserialize source map from string
---@param serialized string Serialized source map
---@return table|nil map Source map object, or nil if deserialization failed
---@return string? error Error message if deserialization failed
function M.deserialize(serialized)
  return error_handler.deserialize(serialized)
end

return M