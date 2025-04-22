---@class TestDiscovery
---@field discover fun(dir?: string, pattern?: string): {files: string[], matched: number, total: number}|nil, table? Discover test files in a directory based on configured patterns. Returns a table with discovered files and counts, or nil and an error object if discovery failed.
---@field is_test_file fun(path: string): boolean Check if a file is a test file based on configured name patterns and extensions.
---@field add_include_pattern fun(pattern: string): TestDiscovery Add a pattern to include in test file discovery. Returns the module instance for method chaining.
---@field add_exclude_pattern fun(pattern: string): TestDiscovery Add a pattern to exclude from test file discovery. Returns the module instance for method chaining.
---@field configure fun(options: {ignore?: string[], include?: string[], exclude?: string[], recursive?: boolean, extensions?: string[]}): TestDiscovery Configure discovery options for customizing test file discovery. Returns the module instance for method chaining.
---@field _VERSION string Module version identifier

--- Test discovery module for firmo
--- Finds test files in directories based on patterns and file extensions.
--- 
--- Features:
--- - Configurable include/exclude patterns for test file identification
--- - Directory recursion control for deep directory structures
--- - Pattern-based filtering for targeted test discovery
--- - Detailed logging of discovery process
--- - Error handling with structured error objects
--- - Method chaining for fluent configuration

local M = {}

-- Module version
M._VERSION = "0.1.0"

-- Load required modules
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("TestDiscovery")

-- Try to load filesystem module - this is required
local fs
local success, module = pcall(require, "lib.tools.filesystem")
if not success then
  logger.error("Failed to load required filesystem module", {
    error = tostring(module),
  })
  error("TestDiscovery module requires the filesystem module")
else
  fs = module
end

--- Discovery configuration options
---@class DiscoveryConfig
---@field ignore string[] Directories to ignore during discovery
---@field include string[] Patterns to include as test files
---@field exclude string[] Patterns to exclude from test files
---@field recursive boolean Whether to search subdirectories recursively
---@field extensions string[] Valid file extensions for test files

-- Configuration with defaults
local config = {
  ignore = {"node_modules", ".git", "vendor"},
  include = {"*_test.lua", "*_spec.lua", "test_*.lua", "spec_*.lua"},
  exclude = {},
  recursive = true,
  extensions = {".lua"}
}

--- Configure discovery options for customizing test file discovery
---@param options {ignore?: string[], include?: string[], exclude?: string[], recursive?: boolean, extensions?: string[]} Configuration options
---@field options.ignore string[] Directories to ignore during discovery
---@field options.include string[] Patterns to include as test files
---@field options.exclude string[] Patterns to exclude from test files
---@field options.recursive boolean Whether to search subdirectories recursively
---@field options.extensions string[] Valid file extensions for test files
---@return table The module instance
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
---@param pattern string Pattern to include (e.g. "*_test.lua", "test_*.lua")
---@return table The module instance for method chaining
function M.add_include_pattern(pattern)
  table.insert(config.include, pattern)
  return M
end

--- Add a pattern to exclude from test file discovery
---@param pattern string Pattern to exclude (e.g. "temp_*.lua", "*_fixture.lua")
---@return table The module instance for method chaining
function M.add_exclude_pattern(pattern)
  table.insert(config.exclude, pattern)
  return M
end
-- Convert glob pattern to Lua pattern
local function glob_to_pattern(glob)
  return glob:gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1") -- Escape special chars
            :gsub("%*", ".*") -- Convert * to .*
end

--- Check if a file should be excluded based on patterns
---@param path string File path to check
---@return boolean Whether the file should be excluded
local function should_exclude(path)
  -- Parameter validation
  if not path or type(path) ~= "string" then
    logger.warn("Invalid path provided to should_exclude", {
      path = path,
      type = type(path)
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

--- Check if a file matches include patterns
---@param path string File path to check
---@return boolean Whether the file matches include patterns
local function matches_include_pattern(path)
  -- Parameter validation
  if not path or type(path) ~= "string" then
    logger.warn("Invalid path provided to matches_include_pattern", {
      path = path,
      type = type(path)
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

--- Check if a file has a valid extension
---@param path string File path to check
---@return boolean Whether the file has a valid extension
local function has_valid_extension(path)
  -- Parameter validation
  if not path or type(path) ~= "string" then
    logger.warn("Invalid path provided to has_valid_extension", {
      path = path,
      type = type(path)
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
---@param dir? string Directory to search in (default: "tests")
---@param pattern? string Additional pattern to filter test files by (optional)
---@return {files: string[], matched: number, total: number}|nil discovery_result Table with discovered files and counts, or nil if failed
---@return table|nil error Error object if discovery failed
function M.discover(dir, pattern)
  dir = dir or "tests"
  pattern = pattern or nil
  
  -- Check if directory exists
  if not fs.is_directory(dir) then
    local err = error_handler.io_error(
      "Directory not found", 
      {directory = dir, operation = "discover"}
    )
    logger.error(err.message, err.context)
    return nil, err
  end
  
  logger.info("Discovering test files", {
    directory = dir,
    pattern = pattern,
    recursive = config.recursive
  })
  
  -- List files and apply filters
  local all_files = {}
  local success, result, err = error_handler.try(function()
    if config.recursive then
      return fs.list_files_recursive(dir)
    else
      return fs.list_files(dir)
    end
  end)
  
  if not success then
    local error_obj = error_handler.io_error(
      "Failed to list files in directory", 
      {directory = dir, operation = "discover"},
      result
    )
    logger.error(error_obj.message, error_obj.context)
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
  
  logger.info("Test discovery completed", {
    total_files = #all_files,
    test_files = test_count,
    matched_files = #test_files,
    directory = dir,
    pattern = pattern
  })
  
  -- Return discovery results
  return {
    files = test_files,
    matched = #test_files,
    total = #test_files  -- Use the actual count of matched files after filtering
  }
end

-- Return the module
return M