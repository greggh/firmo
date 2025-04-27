#!/usr/bin/env lua
--- Find Print Statements Script
---
--- Scans Lua files in the project (excluding configured directories and files)
--- to find `print` function calls that should ideally be replaced with the
--- Firmo logging system (`logger.info`, `logger.debug`, etc.).
--- Reports the count and location of found `print` statements, grouped by directory.
---
--- Usage: lua scripts/find_print_statements.lua
---
--- @author Firmo Team
--- @version 1.0.0
--- @script

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _logging, _fs

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
    return logging.get_logger("find_print_statements")
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

--- Script configuration.
local config = {
  root_dir = ".",
  excluded_dirs = {
    "%.git",
    "node_modules",
    "coverage%-reports",
    "logs",
    "output%-reports",
    "report%-examples",
    "reports%-example",
    "temp%-reports%-demo",
    "html%-report%-examples",
  },
  included_extensions = {
    "%.lua$",
  },
  -- Patterns to search for
  patterns = {
    "print%s*%(", -- Simple print call
    "print%s*%([^)]*%)", -- Print with arguments
    "print%s*%(['\"]", -- Print with string
    "print%(%...%)", -- Print with table args
  },
  -- Files to ignore (these legitimately need print functions)
  ignore_files = {
    "%.firmo%-next%-config%.lua%.template$",
    "logging%.lua$", -- Logging module itself
  },
}

--- Checks if a file path matches any of the patterns in `config.ignore_files`.
---@param file_path string The file path to check.
---@return boolean True if the file should be ignored, false otherwise.
---@private
local function should_ignore_file(file_path)
  for _, pattern in ipairs(config.ignore_files) do
    if file_path:match(pattern) then
      return true
    end
  end
  return false
end

--- Finds all relevant Lua files in a directory using the filesystem module.
--- Respects `config.included_extensions`, `config.excluded_dirs`, and `config.ignore_files`.
---@param dir string The starting directory path.
---@param files? string[] Optional table to accumulate results (for recursion, not used currently).
---@return string[] files An array of relevant Lua file paths found. Returns empty table on filesystem error.
---@private
local function find_lua_files(dir, files)
  files = files or {}
  get_logger().debug("Finding Lua files using filesystem module", {
    directory = dir,
  })

  -- Use filesystem module to discover files
  local include_patterns = config.included_extensions
  local exclude_patterns = config.excluded_dirs

  local all_files = get_fs().discover_files({ dir }, include_patterns, exclude_patterns)

  -- Apply additional filters
  for _, file_path in ipairs(all_files) do
    -- Check if file should be ignored
    if not should_ignore_file(file_path) then
      table.insert(files, file_path)
    end
  end

  get_logger().debug("Found Lua files", {
    count = #files,
  })

  return files
end

--- Counts potential print statements in a file's content.
--- Matches configured patterns and attempts to exclude `logger.*` calls that contain "print".
---@param file_path string The path to the file to analyze.
---@return number count The number of potential print statements found. Returns 0 if file cannot be read.
---@private
local function count_print_statements(file_path)
  local content, err = get_fs().read_file(file_path)
  if not content then
    get_logger().error("Could not read file: " .. file_path .. " - " .. (err or "unknown error"))
    return 0
  end

  -- Count matches for each pattern
  local count = 0
  for _, pattern in ipairs(config.patterns) do
    for _ in content:gmatch(pattern) do
      count = count + 1
    end
  end

  -- Avoid false positives by checking for get_logger().xxx calls that contain "print"
  local logger_count = 0
  for _ in content:gmatch("logger%.[^(]*%(.-print") do
    logger_count = logger_count + 1
  end

  -- Return the actual count
  return count - logger_count
end

--- Main function for the script. Finds Lua files, counts print statements in each,
--- and reports the results grouped by directory.
---@return nil
---@private
local function find_print_statements()
  get_logger().info("Finding Lua files with print statements...")
  -- Find all Lua files
  local files = find_lua_files(config.root_dir)
  get_logger().info("Found " .. #files .. " Lua files to check")

  -- Check each file for print statements
  local files_with_print = {}
  local total_prints = 0

  for _, file in ipairs(files) do
    local count = count_print_statements(file)
    if count > 0 then
      table.insert(files_with_print, {
        path = file,
        count = count,
      })
      total_prints = total_prints + count
    end
  end

  -- Sort by count (descending)
  table.sort(files_with_print, function(a, b)
    return a.count > b.count
  end)

  -- Report results
  get_logger().info("----------------------------------------------------")
  get_logger().info("Found " .. #files_with_print .. " files with print statements")
  get_logger().info("Total print statements: " .. total_prints)
  get_logger().info("----------------------------------------------------")

  -- Group by directory for better organization
  local by_directory = {}
  for _, file in ipairs(files_with_print) do
    -- Extract directory
    local dir = file.path:match("^(.+)/[^/]+$") or "."

    -- Initialize directory entry if not exists
    by_directory[dir] = by_directory[dir] or {
      total = 0,
      files = {},
    }

    -- Add file info
    table.insert(by_directory[dir].files, {
      name = file.path:match("/([^/]+)$") or file.path,
      path = file.path,
      count = file.count,
    })
    by_directory[dir].total = by_directory[dir].total + file.count
  end

  -- Sort directories by total count
  local dirs = {}
  for dir, info in pairs(by_directory) do
    table.insert(dirs, {
      path = dir,
      total = info.total,
      files = info.files,
    })
  end

  table.sort(dirs, function(a, b)
    return a.total > b.total
  end)

  -- Print results by directory
  for _, dir in ipairs(dirs) do
    get_logger().info("\nDirectory: " .. dir.path .. " (" .. dir.total .. " prints)")

    -- Sort files in directory by count
    table.sort(dir.files, function(a, b)
      return a.count > b.count
    end)

    -- Print file details
    for _, file in ipairs(dir.files) do
      get_logger().info(string.format("  %-40s %3d prints", file.name, file.count))
    end
  end

  get_logger().info("\nRun this tool periodically to track progress in converting print statements to logging.")
end

-- Run the main function
find_print_statements()
