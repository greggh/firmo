-- Path mapping between original and instrumented files
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.path_mapping")

---@class coverage_v3_path_mapping
---@field register_path_pair fun(original_path: string, temp_path: string): boolean Register a mapping between original and temp paths
---@field get_original_path fun(temp_path: string): string|nil, string? Get original path from temp path
---@field get_temp_path fun(original_path: string): string|nil, string? Get temp path from original path
---@field clear fun(): boolean Clear all path mappings
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Store path mappings
local temp_to_original = {}  -- Map temp paths to original paths
local original_to_temp = {}  -- Map original paths to temp paths

-- Validate path
local function validate_path(path)
  if not path or type(path) ~= "string" or path == "" then
    return nil, error_handler.validation_error(
      "Invalid path",
      { path = path }
    )
  end
  return true
end

-- Register a mapping between original and temp paths
---@param original_path string Path to original file
---@param temp_path string Path to temp file
---@return boolean success Whether mapping was registered
---@return string? error Error message if registration failed
function M.register_path_pair(original_path, temp_path)
  -- Validate inputs
  local ok, err = validate_path(original_path)
  if not ok then
    return false, err
  end
  ok, err = validate_path(temp_path)
  if not ok then
    return false, err
  end

  -- Normalize paths
  original_path = fs.normalize_path(original_path)
  temp_path = fs.normalize_path(temp_path)

  -- Store mappings
  temp_to_original[temp_path] = original_path
  original_to_temp[original_path] = temp_path

  logger.debug("Registered path mapping", {
    original = original_path,
    temp = temp_path
  })

  return true
end

-- Get original path from temp path
---@param temp_path string Path to temp file
---@return string|nil original_path Path to original file, or nil if not found
---@return string? error Error message if lookup failed
function M.get_original_path(temp_path)
  -- Validate input
  local ok, err = validate_path(temp_path)
  if not ok then
    return nil, err
  end

  -- Normalize path
  temp_path = fs.normalize_path(temp_path)

  -- Look up mapping
  local original_path = temp_to_original[temp_path]
  if not original_path then
    return nil, error_handler.not_found_error(
      "No mapping found for temp path",
      { temp_path = temp_path }
    )
  end

  return original_path
end

-- Get temp path from original path
---@param original_path string Path to original file
---@return string|nil temp_path Path to temp file, or nil if not found
---@return string? error Error message if lookup failed
function M.get_temp_path(original_path)
  -- Validate input
  local ok, err = validate_path(original_path)
  if not ok then
    return nil, err
  end

  -- Normalize path
  original_path = fs.normalize_path(original_path)

  -- Look up mapping
  local temp_path = original_to_temp[original_path]
  if not temp_path then
    return nil, error_handler.not_found_error(
      "No mapping found for original path",
      { original_path = original_path }
    )
  end

  return temp_path
end

-- Clear all path mappings
---@return boolean success Whether mappings were cleared
function M.clear()
  temp_to_original = {}
  original_to_temp = {}
  logger.debug("Cleared all path mappings")
  return true
end

return M