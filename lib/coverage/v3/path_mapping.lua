--- Path mapping between original and instrumented files.
-- @module lib.coverage.v3.path_mapping
-- @description Handles path mapping between original source files and their instrumented temporary versions. 
-- This module manages the bidirectional mapping, resolving paths, handling symlinks,
-- and providing lookup functionality to convert between original and instrumented paths.
-- @copyright Firmo 2023
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.path_mapping")

---@class coverage_v3_path_mapping
---@field register_path_pair fun(original_path: string, temp_path: string): boolean, string? Register a mapping between original and temp paths
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

--- Validate path string.
-- @local
-- @param path any Value to validate as a path
-- @return boolean|nil success Whether path is valid
-- @return string? error Error message if validation failed
local function validate_path(path)
  if not path or type(path) ~= "string" or path == "" then
    local err = error_handler.validation_error(
      "Invalid path",
      { path = path }
    )
    logger.error("Path validation failed", { path = path, error = err.message })
    return nil, err
  end
  return true
end

--- Helper function to get table keys for debugging.
-- @local
-- @param t table Table to get keys from
-- @return string[] Array of keys as strings
local function get_table_keys(t)
  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, tostring(k))
  end
  return keys
end

--- Resolve and normalize a path, handling symlinks and special path patterns.
-- @local
-- @param path string Path to resolve and normalize
-- @return string|nil resolved_path Fully resolved and normalized path
-- @return string? error Error message if resolution failed
local function resolve_path(path)
  -- Validate input path
  local ok, err = validate_path(path)
  if not ok then
    return nil, err
  end

  logger.debug("Resolving path", { path = path })

  -- First normalize the path to handle special cases like ./file.lua and dir/../file.lua
  local normalized_path = fs.normalize_path(path)
  if path ~= normalized_path then
    logger.debug("Path normalized", { 
      original = path, 
      normalized = normalized_path 
    })
  end

  -- Then resolve any symlinks using the filesystem module's function
  local resolved_path, symlink_err = fs.resolve_symlink(normalized_path)
  if symlink_err then
    logger.warn("Error resolving symlink, using normalized path instead", {
      path = normalized_path,
      error = symlink_err
    })
    return normalized_path, nil
  end
  
  -- If the path was a symlink
  if resolved_path and resolved_path ~= normalized_path then
    logger.debug("Resolved symlink", {
      original = path,
      normalized = normalized_path,
      resolved = resolved_path
    })
  end
  
  return resolved_path
end

--- Register a mapping between original and temp paths.
-- This function creates a bidirectional mapping between the original source file path
-- and its instrumented temporary version. The paths are normalized and symlinks resolved.
-- @param original_path string Path to original file
-- @param temp_path string Path to temp file
-- @return boolean success Whether mapping was registered
-- @return string? error Error message if registration failed
function M.register_path_pair(original_path, temp_path)
  logger.debug("Registering path pair", {
    original = original_path,
    temp = temp_path
  })

  -- Validate inputs
  local ok, err = validate_path(original_path)
  if not ok then
    return false, err
  end
  
  ok, err = validate_path(temp_path)
  if not ok then
    return false, err
  end

  -- Resolve and normalize paths using our helper function
  local resolved_original, original_err = resolve_path(original_path)
  if not resolved_original then
    logger.error("Failed to resolve original path", { 
      path = original_path, 
      error = original_err 
    })
    return false, error_handler.io_error(
      "Failed to resolve original path",
      { path = original_path, error = original_err }
    )
  end
  
  local resolved_temp, temp_err = resolve_path(temp_path)
  if not resolved_temp then
    logger.error("Failed to resolve temp path", { 
      path = temp_path, 
      error = temp_err 
    })
    return false, error_handler.io_error(
      "Failed to resolve temp path",
      { path = temp_path, error = temp_err }
    )
  end

  -- Store mappings
  temp_to_original[resolved_temp] = resolved_original
  original_to_temp[resolved_original] = resolved_temp

  logger.info("Registered path mapping", {
    original = {
      raw = original_path,
      resolved = resolved_original
    },
    temp = {
      raw = temp_path,
      resolved = resolved_temp
    }
  })

  return true
end

--- Get original path from temp path.
-- Looks up the original source file path corresponding to an instrumented temporary file.
-- Paths are normalized and resolved before lookup.
-- @param temp_path string Path to temp file
-- @return string|nil original_path Path to original file, or nil if not found
-- @return string? error Error message if lookup failed
function M.get_original_path(temp_path)
  logger.debug("Looking up original path", { temp_path = temp_path })
  
  -- Validate input
  local ok, err = validate_path(temp_path)
  if not ok then
    return nil, err
  end

  -- Resolve and normalize path using our helper function
  local resolved_temp, resolve_err = resolve_path(temp_path)
  if not resolved_temp then
    logger.error("Failed to resolve temp path for lookup", { 
      path = temp_path, 
      error = resolve_err 
    })
    return nil, error_handler.io_error(
      "Failed to resolve temp path for lookup",
      { path = temp_path, error = resolve_err }
    )
  end

  -- Look up mapping using the resolved path
  local original_path = temp_to_original[resolved_temp]
  if not original_path then
    -- Try with just normalized path as fallback
    local normalized = fs.normalize_path(temp_path)
    original_path = temp_to_original[normalized]
    
    if not original_path then
      logger.warn("No mapping found for temp path", { 
        temp_path = temp_path, 
        resolved = resolved_temp,
        available_keys = get_table_keys(temp_to_original)
      })
      return nil, error_handler.not_found_error(
        "No mapping found for temp path",
        { 
          temp_path = temp_path,
          resolved_path = resolved_temp
        }
      )
    end
    
    logger.debug("Found mapping using normalized path fallback", {
      temp_path = temp_path,
      normalized = normalized,
      original = original_path
    })
  else
    logger.debug("Found mapping", {
      temp_path = temp_path,
      resolved = resolved_temp,
      original = original_path
    })
  end

  return original_path
end

-- Get temp path from original path
---@param original_path string Path to original file
---@return string|nil temp_path Path to temp file, or nil if not found
---@return string? error Error message if lookup failed
function M.get_temp_path(original_path)
  logger.debug("Looking up temp path", { original_path = original_path })
  
  -- Validate input
  local ok, err = validate_path(original_path)
  if not ok then
    return nil, err
  end

  -- Resolve and normalize path using our helper function
  local resolved_original, resolve_err = resolve_path(original_path)
  if not resolved_original then
    logger.error("Failed to resolve original path for lookup", { 
      path = original_path, 
      error = resolve_err 
    })
    return nil, error_handler.io_error(
      "Failed to resolve original path for lookup",
      { path = original_path, error = resolve_err }
    )
  end

  -- Look up mapping using the resolved path
  local temp_path = original_to_temp[resolved_original]
  if not temp_path then
    -- Try with just normalized path as fallback
    local normalized = fs.normalize_path(original_path)
    temp_path = original_to_temp[normalized]
    
    if not temp_path then
      logger.warn("No mapping found for original path", { 
        original_path = original_path, 
        resolved = resolved_original,
        available_keys = get_table_keys(original_to_temp)
      })
      return nil, error_handler.not_found_error(
        "No mapping found for original path",
        { 
          original_path = original_path,
          resolved_path = resolved_original
        }
      )
    end
    
    logger.debug("Found mapping using normalized path fallback", {
      original_path = original_path,
      normalized = normalized,
      temp = temp_path
    })
  else
    logger.debug("Found mapping", {
      original_path = original_path,
      resolved = resolved_original,
      temp = temp_path
    })
  end

  return temp_path
end


-- Clear all path mappings
---@return boolean success Whether mappings were cleared
function M.clear()
  local orig_count = 0
  local temp_count = 0
  
  -- Count existing mappings for logging
  for _ in pairs(original_to_temp) do orig_count = orig_count + 1 end
  for _ in pairs(temp_to_original) do temp_count = temp_count + 1 end
  
  -- Clear the mappings
  temp_to_original = {}
  original_to_temp = {}
  
  -- Log with counts for better diagnostics
  logger.info("Cleared all path mappings", { 
    original_count = orig_count, 
    temp_count = temp_count 
  })
  
  return true
end

return M
