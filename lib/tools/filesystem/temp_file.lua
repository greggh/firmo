--- Temporary File Management Utility
---
--- Provides functions for creating and managing temporary files and directories
--- during tests, with automatic tracking, registration, and cleanup.
--- Integrates with the test runner (via `temp_file_integration`) to associate
--- temp files with specific tests and ensure cleanup after test completion.
---
--- @module lib.tools.filesystem.temp_file
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class TempFileModule The public API for the temporary file management module.
---@field _VERSION string Module version (following semantic versioning).
---@field create_with_content fun(content: string, extension?: string): string|nil, table? Creates a temporary file, writes content, registers it, and returns the path. Returns `path, nil` or `nil, error`. @throws string If unique filename generation fails.
---@field create_temp_directory fun(): string|nil, table? Creates a temporary directory and registers it. Returns `path, nil` or `nil, error`. @throws string If unique directory name generation fails.
---@field get_temp_dir fun(): string [Not Implemented] Get the base temporary directory path.
---@field register_file fun(file_path: string): string Registers an existing file for automatic cleanup. Returns the path.
---@field register_directory fun(dir_path: string): string Registers an existing directory for automatic cleanup. Returns the path.
---@field remove fun(file_path: string): boolean, string? Safely removes a temporary file. Returns `success, error_message?`. @throws table If validation fails.
---@field remove_directory fun(dir_path: string): boolean, string? Safely removes a temporary directory recursively. Returns `success, error_message?`. @throws table If validation fails.
---@field with_temp_file fun(content: string, callback: fun(temp_path: string): any, extension?: string): any|nil, table? Creates, uses (via callback), and cleans up a temporary file. Returns `callback_result, nil` or `nil, error`. @throws string If `create_with_content` fails critically.
---@field with_temp_directory fun(callback: fun(dir_path: string): any): any|nil, table? Creates, uses (via callback), and cleans up a temporary directory. Returns `callback_result, nil` or `nil, error`. @throws string If `create_temp_directory` fails critically.
---@field cleanup_test_context fun(context?: string|table): boolean, table[] Cleans up resources associated with a context (currently hardcoded). Returns `success, errors_array`.
---@field cleanup_all fun(): boolean, table[], table Cleans up all registered resources. Returns `success, errors_array, stats_table`.
---@field get_stats fun(): {contexts: number, total_resources: number, files: number, directories: number, resources_by_context: table<string, {files: number, directories: number, total: number}>} Gets statistics about registered resources.
---@field set_current_test_context fun(context: table|string): nil Sets the current test context globally for implicit registration.
---@field clear_current_test_context fun(): nil Clears the current test context.
---@field configure fun(options: {temp_dir?: string, force_cleanup?: boolean, file_prefix?: string, auto_register?: boolean, cleanup_on_exit?: boolean, track_orphans?: boolean, cleanup_delay?: number}): TempFileModule [Not Implemented] Configure temp file behavior. Returns self.
---@field set_temp_dir fun(dir_path: string): boolean, string? [Not Implemented] Set a custom temporary directory path.
---@field get_registered_files fun(): table<string, {context: string, created: number, size: number, accessed: number, modified: number}> [Not Implemented] Get details of registered files.
---@field get_registered_directories fun(): table<string, {context: string, created: number, file_count: number, total_size: number}> [Not Implemented] Get details of registered directories.
---@field create_nested_directory fun(path: string): string|nil, table? [Not Implemented] Create a nested directory in temp.
---@field is_registered fun(path: string): boolean [Not Implemented] Check if registered.
---@field get_context_for_file fun(file_path: string): string|nil [Not Implemented] Get context for a file.
---@field get_current_test_context fun(): string|table|nil [Not Implemented] Get current test context.
---@field copy_to_temp fun(source_path: string, extension?: string): string|nil, table? [Not Implemented] Copy file to temp location.
---@field find_orphans fun(): table [Not Implemented] Find orphaned temp files.
---@field generate_temp_path fun(extension?: string): string Generates a unique temporary file path. @throws string If unable to generate unique name.

local M = {}

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
    return logging.get_logger("filesystem")
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

-- Global registry of temporary files by test context
-- Using weak keys so test contexts can be garbage collected
local _temp_file_registry = setmetatable({}, { __mode = "k" })

--- Returns the current test context identifier.
--- NOTE: This implementation is simplified and always returns a hardcoded string.
--- Full context tracking is intended to be managed by `temp_file_integration`.
---@return string context The hardcoded test context identifier ("_SIMPLE_STRING_CONTEXT_").
---@private
local function get_current_test_context()
  -- For simplicity, we've moved to using a single hardcoded context
  -- This avoids complexity and potential issues with different context types
  get_logger().debug("Using hardcoded test context")
  return "_SIMPLE_STRING_CONTEXT_"
end

--- Register a file with the current test context for automatic cleanup
---@param file_path string Path to the file to register.
---@return string registered_path The `file_path` passed in.
function M.register_file(file_path)
  get_logger().trace("Inside temp_file.register_file", { received_path = file_path })
  get_logger().debug("Registering file", { path = file_path })

  -- Create simple string context to avoid complex objects
  -- Note: We're hardcoding this to avoid potential issues with table serialization
  local context = "_SIMPLE_STRING_CONTEXT_"

  -- Initialize the registry for this context if needed
  _temp_file_registry[context] = _temp_file_registry[context] or {}

  -- Add the file to the registry
  table.insert(_temp_file_registry[context], {
    path = file_path,
    type = "file",
  })

  return file_path
end

--- Register a directory with the current test context for automatic cleanup
---@param dir_path string Path to the directory to register.
---@return string registered_path The `dir_path` passed in.
function M.register_directory(dir_path)
  get_logger().debug("Registering directory", { path = dir_path })

  -- Use same simplified context as register_file
  local context = "_SIMPLE_STRING_CONTEXT_"

  -- Initialize registry if needed
  _temp_file_registry[context] = _temp_file_registry[context] or {}

  -- Add directory to registry
  table.insert(_temp_file_registry[context], {
    path = dir_path,
    type = "directory",
  })

  return dir_path
end

--- Generates a unique temporary file path based on `os.tmpname()`.
--- Tries multiple times with random suffixes if collisions occur.
---@param extension? string File extension (without the dot, default "tmp").
---@return string temp_path The generated unique temporary file path.
---@throws string If unable to generate a unique filename after multiple attempts.
---@private
function M.generate_temp_path(extension)
  extension = extension or "tmp"
  -- Ensure extension doesn't start with a dot
  if extension:sub(1, 1) == "." then
    extension = extension:sub(2)
  end

  -- Maximum number of attempts to generate a unique filename
  local max_attempts = 10
  local temp_path = nil

  for attempt = 1, max_attempts do
    temp_path = os.tmpname()

    -- Some os.tmpname() implementations include an extension, remove it
    if temp_path:match("%.") then
      temp_path = temp_path:gsub("%.[^%.]+$", "")
    end

    -- Add our extension
    temp_path = temp_path .. "." .. extension

    -- Check if the file already exists
    if not get_fs().file_exists(temp_path) and not get_fs().directory_exists(temp_path) then
      get_logger().debug("Generated unique temp path", { path = temp_path, attempt = attempt })
      return temp_path
    end

    -- If we're having collisions, add a random suffix to increase uniqueness
    if attempt > 1 then
      -- Use time and random number to create more unique filenames
      local suffix = tostring(os.time()) .. "_" .. tostring(math.random(10000))
      temp_path = temp_path:gsub("%." .. extension .. "$", "_" .. suffix .. "." .. extension)

      -- Check again after adding the random suffix
      if not get_fs().file_exists(temp_path) and not get_fs().directory_exists(temp_path) then
        get_logger().debug("Generated unique temp path with suffix", {
          path = temp_path,
          attempt = attempt,
          suffix = suffix,
        })
        return temp_path
      end
    end

    get_logger().debug("Temp path collision, retrying", { path = temp_path, attempt = attempt })
  end

  -- If we've exhausted our attempts, throw an error
  error("Unable to generate a unique filename after " .. max_attempts .. " attempts")
end

---@param content string Content to write to the file
---@param extension? string File extension (without the dot)
---@return string|nil temp_path Path to the created temporary file, or nil on error
---@return table? error Error object from `error_handler.try` if writing or registration failed.
---@throws string If `generate_temp_path` fails to create a unique path.
function M.create_with_content(content, extension)
  local temp_path = M.generate_temp_path(extension)

  local success, result, err = get_error_handler().try(function()
    local ok, write_err = get_fs().write_file(temp_path, content)
    if not ok then
      return nil, write_err or get_error_handler().io_error("Failed to write to temporary file", { file_path = temp_path })
    end

    -- Register the file for automatic cleanup
    M.register_file(temp_path)

    return temp_path
  end)

  if not success then
    return nil, result -- Result contains the error in this case
  end

  return result -- Result contains the path in success case
end

---@return string|nil dir_path Path to the created temporary directory, or nil on error
---@return table? error Error object if directory creation failed
---@return table? error Error object from `error_handler.try` if directory creation or registration failed.
---@throws string If `os.tmpname` fails (unlikely) or if directory name generation has persistent collisions (highly unlikely).
function M.create_temp_directory()
  -- Generate a potential path using os.tmpname()
  local temp_dir = M.generate_temp_path("dir") -- Use generate_temp_path for uniqueness retry logic

  local success, result, err = get_error_handler().try(function()
    local ok, mkdir_err = get_fs().create_directory(temp_dir)
    if not ok then
      return nil,
        mkdir_err or get_error_handler().io_error("Failed to create temporary directory", { directory_path = temp_dir })
    end

    -- Register the directory for automatic cleanup
    M.register_directory(temp_dir)

    return temp_dir
  end)

  if not success then
    return nil, result -- Result contains the error in this case
  end

  return result -- Result contains the path in success case
end

---@param file_path string Path to the temporary file to remove
---@return boolean success Whether the file was successfully removed
---@return string? error Error message string from `get_fs().delete_file` if removal failed.
---@throws table If `file_path` validation fails (e.g., nil).
function M.remove(file_path)
  if not file_path then
    return false,
      get_error_handler().validation_error("Missing file path for temporary file removal", { operation = "remove_temp_file" })
  end

  return get_fs().delete_file(file_path)
end

---@param dir_path string Path to the temporary directory to remove
---@return boolean success Whether the directory was successfully removed
---@return string? error Error message string from `get_fs().delete_directory` if removal failed.
---@throws table If `dir_path` validation fails (e.g., nil).
function M.remove_directory(dir_path)
  if not dir_path then
    return false,
      get_error_handler().validation_error(
        "Missing directory path for temporary directory removal",
        { operation = "remove_temp_directory" }
      )
  end

  -- Use the standard function name - this should always exist
  return get_fs().delete_directory(dir_path, true) -- Use recursive deletion
end

---@param content string Content to write to the file
---@param callback fun(temp_path: string): any Function to call with the temporary file path
---@param extension? string File extension (without the dot)
---@return any|nil result Result from the callback function, or nil on error
---@return table? error Error object if creation, callback execution, or cleanup (non-critical) failed.
---@throws string If `create_with_content` fails critically (e.g., generating unique path).
function M.with_temp_file(content, callback, extension)
  local temp_path, create_err = M.create_with_content(content, extension)
  if not temp_path then
    return nil, create_err
  end

  local success, result, err = get_error_handler().try(function()
    return callback(temp_path)
  end)

  -- Always try to clean up, even if callback failed
  local _, remove_err = M.remove(temp_path)
  if remove_err then
    -- Just log the error, don't fail the operation due to cleanup issues
    -- This is a best-effort cleanup
    get_error_handler().log_error(remove_err, get_error_handler().LOG_LEVEL.DEBUG)
  end

  if not success then
    return nil, err
  end

  return result
end

---@param callback fun(dir_path: string): any Function to call with the temporary directory path
---@return any|nil result Result from the callback function, or nil on error
---@return table? error Error object if creation, callback execution, or cleanup (non-critical) failed.
---@throws string If `create_temp_directory` fails critically.
function M.with_temp_directory(callback)
  local dir_path, create_err = M.create_temp_directory()
  if not dir_path then
    return nil, create_err
  end

  local success, result, err = get_error_handler().try(function()
    return callback(dir_path)
  end)

  -- Always try to clean up, even if callback failed
  local _, remove_err = M.remove_directory(dir_path)
  if remove_err then
    -- Just log the error, don't fail the operation due to cleanup issues
    get_error_handler().log_error(remove_err, get_error_handler().LOG_LEVEL.DEBUG)
  end

  if not success then
    return nil, err
  end

  return result
end

---@param path string Path to file or directory to remove
---@param resource_type string "file" or "directory"
---@param max_retries number Maximum number of retries
---@return boolean success Whether the resource was successfully removed
---@return string? err Error message string if removal failed after retries.
---@private
local function remove_with_retry(path, resource_type, max_retries)
  max_retries = max_retries or 3
  local success = false
  local err

  for retry = 1, max_retries do
    if resource_type == "file" then
      -- For files, try with both os.remove and get_fs().delete_file
      -- os.remove is often more reliable for temp files
      local ok1 = os.remove(path)
      if ok1 then
        success = true
        break
      end

      -- If os.remove failed, try get_fs().delete_file
      local ok2, delete_err = get_fs().delete_file(path)
      if ok2 then
        success = true
        break
      end
      err = delete_err or "Failed to remove file"
    else
      -- For directories, always use recursive deletion
      local ok, delete_err = get_fs().delete_directory(path, true)
      if ok then
        success = true
        break
      end
      err = delete_err or "Failed to remove directory"
    end

    if not success and retry < max_retries then
      -- Wait briefly before retrying (increasing delay)
      local delay = 0.1 * retry
      get_logger().debug(
        "Retry " .. retry .. " failed for " .. resource_type .. ", waiting " .. delay .. "s",
        { path = path }
      )

      -- Sleep using os.execute("sleep") for cross-platform compatibility
      if delay > 0 then
        os.execute("sleep " .. tostring(delay))
      end
    end
  end

  return success, err
end

---@param context? string|table Optional test context identifier (currently ignored, uses hardcoded context).
---@return boolean success `true` if all registered resources for the context were successfully removed.
---@return table[] errors Array of tables `{path, type}` for resources that could not be cleaned up.
function M.cleanup_test_context(context)
  get_logger().debug("Cleaning up test context")

  -- Use hardcoded context to match our simplified registration
  context = "_SIMPLE_STRING_CONTEXT_"

  local resources = _temp_file_registry[context] or {}

  get_logger().debug("Found resources to clean up", { count = #resources })

  local errors = {}

  -- Sort resources to ensure directories are deleted after their contained files
  -- This helps with nested directory structure cleanup
  table.sort(resources, function(a, b)
    -- If one is a file and one is a directory, process files first
    if a.type ~= b.type then
      return a.type == "file"
    end

    -- For directories, sort by path depth (delete deeper paths first)
    if a.type == "directory" and b.type == "directory" then
      local depth_a = select(2, string.gsub(a.path, "/", ""))
      local depth_b = select(2, string.gsub(b.path, "/", ""))
      return depth_a > depth_b
    end

    -- Otherwise, keep original order
    return false
  end)

  -- Try to remove all resources with retry logic
  for i = #resources, 1, -1 do
    local resource = resources[i]

    -- Check if the resource still exists before attempting removal
    local exists = false
    if resource.type == "file" then
      exists = get_fs().file_exists(resource.path)
    else
      exists = get_fs().directory_exists(resource.path)
    end

    local success = not exists -- Consider it successful if the resource doesn't exist

    if exists then
      -- Try to remove with retry
      success, _ = remove_with_retry(resource.path, resource.type, 3)
    end

    if not success then
      table.insert(errors, {
        path = resource.path,
        type = resource.type,
      })
      get_logger().debug("Failed to clean up resource", {
        path = resource.path,
        type = resource.type,
      })
    else
      -- Remove from the registry
      table.remove(resources, i)
    end
  end

  -- Clear the registry for this context if all resources were removed
  if #resources == 0 then
    _temp_file_registry[context] = nil
    get_logger().debug("All resources cleaned up, removed context from registry")
  end

  return #errors == 0, errors
end

--- Gets statistics about currently registered temporary files and directories across all contexts.
---@return {contexts: number, total_resources: number, files: number, directories: number, resources_by_context: table<string, {files: number, directories: number, total: number}>} stats Statistics table.
function M.get_stats()
  local stats = {
    contexts = 0,
    total_resources = 0,
    files = 0,
    directories = 0,
    resources_by_context = {},
  }

  for context, resources in pairs(_temp_file_registry) do
    stats.contexts = stats.contexts + 1

    local context_stats = {
      files = 0,
      directories = 0,
      total = #resources,
    }

    for _, resource in ipairs(resources) do
      stats.total_resources = stats.total_resources + 1

      if resource.type == "file" then
        stats.files = stats.files + 1
        context_stats.files = context_stats.files + 1
      else
        stats.directories = stats.directories + 1
        context_stats.directories = context_stats.directories + 1
      end
    end

    stats.resources_by_context[tostring(context)] = context_stats
  end

  return stats
end

---@return table stats A simplified statistics table `{ total_resources, cleaned }`.
---@return table[] errors Array of resources that could not be cleaned up.
function M.cleanup_all()
  get_logger().debug("Cleaning up all temporary files")

  -- Simplified version that just calls cleanup_test_context with our hardcoded context
  local success, errors = M.cleanup_test_context("_SIMPLE_STRING_CONTEXT_")

  -- Return stats
  local stats = {
    total_resources = errors and #errors or 0,
    cleaned = success,
  }

  return success, errors, stats
end

-- Set the current test context (for use by test runners)
---@param context table|string The test context to set (e.g., `{ type="test", name="..." }` or a simple string).
---@return nil
function M.set_current_test_context(context)
  -- If we can modify firmo, use it
  if _G.firmo and _G.firmo.set_current_test_context then
    _G.firmo.set_current_test_context(context)
  end

  -- Also set a global for fallback
  _G._current_temp_file_context = context
end

-- Clear the current test context (for use by test runners)
---@return nil
function M.clear_current_test_context()
  -- If we can modify firmo, use it
  if _G.firmo then
    _G.firmo._current_test_context = nil
  end

  -- Also clear the global fallback
  _G._current_temp_file_context = nil
end

return M
