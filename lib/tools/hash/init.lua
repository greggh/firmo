--- Hashing Utilities
---
--- Provides functions for generating simple hashes for strings and files.
--- Uses the FNV-1a algorithm for speed.
---
--- @module lib.tools.hash
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging, _fs

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the filesystem module with lazy loading to avoid circular dependencies
---@return table|nil The filesystem module or nil if not available
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
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
    return logging.get_logger("tools.hash")
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

---@class tools_hash
---@field hash_string fun(str: string): string Generates a 32-bit FNV-1a hash hex string for a string. @throws table If input is not a string.
---@field hash_file fun(path: string): string|nil, table? Generates a 32-bit FNV-1a hash hex string for a file's contents. Returns `hash_string, nil` or `nil, error_object`.
---@field _VERSION string Module version.
local M = {
  _VERSION = "1.0.0",
}

--- Helper to convert a byte string to its hexadecimal representation.
---@param str string The input byte string.
---@return string The hexadecimal string.
---@private
local function bytes_to_hex(str)
  return (str:gsub(".", function(c)
    return string.format("%02x", string.byte(c))
  end))
end

-- Generate a hash for a string using a simple but fast algorithm
---@param str string The string to hash
---@return string hash The 32-bit FNV-1a hash formatted as an 8-character hexadecimal string.
---@throws table If `str` is not a string (via `get_error_handler().validation_error`).
function M.hash_string(str)
  if type(str) ~= "string" then
    error(get_error_handler().validation_error("Input must be a string", { provided_type = type(str) }))
  end

  -- Use a simple FNV-1a hash algorithm
  local hash = 2166136261 -- FNV offset basis
  for i = 1, #str do
    hash = hash ~ string.byte(str, i)
    hash = (hash * 16777619) & 0xFFFFFFFF -- FNV prime
  end

  -- Convert to hex string
  return string.format("%08x", hash)
end

-- Generate a hash for a file's contents
---@param path string Path to the file
---@return string|nil hash The 32-bit FNV-1a hash hex string of the file content, or `nil` if the file could not be read.
---@return table? error An `error_handler` object if reading the file failed.
---@throws table If `hash_string` fails validation (if content is somehow not a string - highly unlikely).
function M.hash_file(path)
  -- Validate input
  if type(path) ~= "string" then
    return nil, get_error_handler().validation_error("File path must be a string", { provided_type = type(path) })
  end

  -- Read the file
  local content, err = get_fs().read_file(path)
  if not content then
    -- Create a proper error object using error_handler
    local error_obj = get_error_handler().operation_error("Failed to read file for hashing", {
      path = path,
      operation = "hash_file",
      original_error = err,
    })

    get_logger().error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Hash the content
  return M.hash_string(content)
end

return M
