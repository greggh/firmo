---@class TestDiscovery The public API of the test discovery module.
---@field _VERSION string Module version identifier.
---@field discover fun(dir?: string, pattern?: string): {files: string[], matched: number, total: number}|nil, table? Discovers test files. Returns results table or `nil, error`. @throws table If filesystem ops fail critically.
---@field is_test_file fun(path: string): boolean Checks if a file path matches configured test file patterns and extensions.
---@field add_include_pattern fun(pattern: string): TestDiscovery Adds a pattern to the include list. Returns self for chaining.
---@field add_exclude_pattern fun(pattern: string): TestDiscovery Adds a pattern to the exclude list. Returns self for chaining.
---@field configure fun(options: {ignore?: string[], include?: string[], exclude?: string[], recursive?: boolean, extensions?: string[]}): TestDiscovery Configures discovery options. Returns self for chaining. @throws table If validation fails.
--- Firmo Test Discovery Module
---
--- Finds test files in directories based on configurable patterns, extensions,
--- and exclusion rules. Integrates with the filesystem module.
---
--- Features:
--- - Configurable include/exclude patterns using glob-like syntax.
--- - Recursive or non-recursive directory searching.
--- - Filtering by file extension.
--- - Optional additional filtering pattern.
--- - Structured results with file list and counts.
--- - Error handling and logging.
---
--- @module lib.tools.discover
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.1.0

local M = {}

-- Module version
M._VERSION = "0.1.0"

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

--- Discovery configuration options.
---@class DiscoveryConfig
---@field ignore string[] Directory names (not paths) to ignore during traversal (e.g., "node_modules").
---@field include string[] Glob-like patterns for filenames to include (e.g., "*_test.lua").
---@field exclude string[] Glob-like patterns for filenames to exclude.
---@field recursive boolean If `true`, search subdirectories recursively.
---@field extensions string[] Allowed file extensions (e.g., {".lua"}).

-- Configuration with defaults
local config = {
  ignore = { "node_modules", ".git", "vendor" },
  include = { "*_test.lua", "*_spec.lua", "test_*.lua", "spec_*.lua" },
  exclude = {},
  recursive = true,
  extensions = { ".lua" },
}

--- Configure discovery options for customizing test file discovery
---@param options {ignore?: string[], include?: string[], exclude?: string[], recursive?: boolean, extensions?: string[]} Configuration options table.
---@return TestDiscovery self The module instance (`M`) for chaining.
---@throws table If validation of options fails (currently validation is minimal).
function M.configure(options)
  options = options or {}

  -- Update configuration
  if options.ignore then
    config.ignore = options.ignore
  end

  if options.include then
    config.include = options.include
  end

  if options.exclude then
    config.exclude = options.exclude
  end

  if options.recursive ~= nil then
    config.recursive = options.recursive
  end

  if options.extensions then
    config.extensions = options.extensions
  end

  return M
end

--- Add a pattern to include in test file discovery
---@param pattern string Glob-like pattern to include (e.g. "*_test.lua", "test_*.lua").
---@return TestDiscovery self The module instance (`M`) for method chaining.
function M.add_include_pattern(pattern)
  table.insert(config.include, pattern)
  return M
end

--- Add a pattern to exclude from test file discovery
---@param pattern string Glob-like pattern to exclude (e.g. "temp_*.lua", "*_fixture.lua").
---@return TestDiscovery self The module instance (`M`) for method chaining.
function M.add_exclude_pattern(pattern)
  table.insert(config.exclude, pattern)
  return M
end

--- Converts a simple glob pattern (using `*`) into a Lua pattern.
--- Escapes magic characters and replaces `*` with `.*`.
---@param glob string Glob pattern (*).
---@return string Lua pattern (.*).
---@private
local function glob_to_pattern(glob)
  return glob
    :gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1") -- Escape special chars
    :gsub("%*", ".*") -- Convert * to .*
end

--- Checks if a file path should be excluded based on `config.exclude` patterns
--- and `config.ignore` directory names.
---@param path string File path to check.
---@return boolean excluded `true` if the path matches an exclusion rule, `false` otherwise.
---@private
local function should_exclude(path)
  -- Parameter validation
  if not path or type(path) ~= "string" then
    get_logger().warn("Invalid path provided to should_exclude", {
      path = path,
      type = type(path),
    })
    return true -- Exclude invalid paths
  end

  -- Check exclusion patterns
  for _, pattern in ipairs(config.exclude) do
    local lua_pattern = glob_to_pattern(pattern)
    if path:match(lua_pattern) then
      return true
    end
  end

  -- Check ignored directories
  for _, dir in ipairs(config.ignore) do
    if path:match("/" .. dir .. "/") or path:match("^" .. dir .. "/") then
      return true
    end
  end

  return false
end

--- Checks if a file path matches any of the `config.include` patterns.
---@param path string File path to check.
---@return boolean matches `true` if the path matches at least one include pattern, `false` otherwise.
---@private
local function matches_include_pattern(path)
  -- Parameter validation
  if not path or type(path) ~= "string" then
    get_logger().warn("Invalid path provided to matches_include_pattern", {
      path = path,
      type = type(path),
    })
    return false -- Don't include invalid paths
  end

  for _, pattern in ipairs(config.include) do
    local lua_pattern = glob_to_pattern(pattern)
    if path:match(lua_pattern) then
      return true
    end
  end

  return false
end

--- Checks if a file path ends with any of the extensions listed in `config.extensions`.
---@param path string File path to check.
---@return boolean valid `true` if the path has a valid extension, `false` otherwise.
---@private
local function has_valid_extension(path)
  -- Parameter validation
  if not path or type(path) ~= "string" then
    get_logger().warn("Invalid path provided to has_valid_extension", {
      path = path,
      type = type(path),
    })
    return false -- Don't include invalid paths
  end

  for _, ext in ipairs(config.extensions) do
    if path:match(ext .. "$") then
      return true
    end
  end

  return false
end

--- Check if a file is a test file based on configured name patterns and extensions
---@param path string File path to check against include/exclude patterns and extensions
---@return boolean Whether the file is considered a valid test file based on current configuration
function M.is_test_file(path)
  -- Skip files that match exclusion patterns
  if should_exclude(path) then
    return false
  end

  -- Check if file has valid extension
  if not has_valid_extension(path) then
    return false
  end

  -- Check if file matches include patterns
  return matches_include_pattern(path)
end

--- Discover test files in a directory based on configured patterns
---@param dir? string Directory to search in (default: "tests").
---@param pattern? string Optional Lua pattern to further filter matched files by path.
---@return {files: string[], matched: number, total: number}|nil discovery_result Table with `files` (array of absolute paths), `matched` (count after pattern filter), `total` (count before pattern filter), or `nil` if directory listing failed.
---@return table|nil error Error object if directory validation or file listing failed.
---@throws table If filesystem operations fail critically (though handled by `get_error_handler().try`).
function M.discover(dir, pattern)
  dir = dir or "tests"
  pattern = pattern or nil

  -- Check if directory exists
  if not get_fs().is_directory(dir) then
    local err = get_error_handler().io_error("Directory not found", { directory = dir, operation = "discover" })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().info("Discovering test files", {
    directory = dir,
    pattern = pattern,
    recursive = config.recursive,
  })

  -- List files and apply filters
  local all_files = {}
  local success, result, err = get_error_handler().try(function()
    if config.recursive then
      return get_fs().list_files_recursive(dir)
    else
      return get_fs().list_files(dir)
    end
  end)

  if not success then
    local error_obj =
      get_error_handler().io_error("Failed to list files in directory", { directory = dir, operation = "discover" }, result)
    get_logger().error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  all_files = result

  -- Filter test files
  local test_files = {}
  local test_count = 0

  for _, file in ipairs(all_files) do
    -- Check if file is a test file
    if M.is_test_file(file) then
      test_count = test_count + 1

      -- Apply pattern filter if specified
      if not pattern or file:match(glob_to_pattern(pattern)) then
        table.insert(test_files, file)
      end
    end
  end

  -- Sort test files for consistent order
  table.sort(test_files)

  get_logger().info("Test discovery completed", {
    total_files = #all_files,
    test_files = test_count,
    matched_files = #test_files,
    directory = dir,
    pattern = pattern,
  })

  -- Return discovery results
  return {
    files = test_files,
    matched = #test_files,
    total = #test_files, -- Use the actual count of matched files after filtering
  }
end

-- Return the module
return M
