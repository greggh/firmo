--- Firmo CodeFix Module
---
--- Implementation of code quality checking and fixing capabilities.
--- Provides tools for integrating with external linters/formatters (StyLua, Luacheck)
--- and applying custom automated code fixes (e.g., trailing whitespace, unused variables).
---
--- @module lib.tools.codefix
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
---@class codefix_module
---@class codefix_module The public API of the codefix module.
---@field _VERSION string Module version.
---@field config { enabled: boolean, verbose: boolean, debug: boolean, use_stylua: boolean, stylua_path: string, stylua_config: string|nil, use_luacheck: boolean, luacheck_path: string, luacheck_config: string|nil, custom_fixers: { trailing_whitespace: boolean, unused_variables: boolean, string_concat: boolean, type_annotations: boolean, lua_version_compat: boolean }, include: string[], exclude: string[], backup: boolean, backup_ext: string } Configuration options.
---@field init fun(options?: table): codefix_module Initialize module with configuration. Returns self.
---@field check_stylua fun(): boolean Check if StyLua executable is available.
---@field find_stylua_config fun(dir?: string): string|nil Find StyLua configuration file (`stylua.toml` or `.stylua.toml`).
---@field run_stylua fun(file_path: string, config_file?: string): boolean, string? Runs StyLua on a file. Returns `success, error_message?`. @throws table If validation fails.
---@field check_luacheck fun(): boolean Check if Luacheck executable is available.
---@field find_luacheck_config fun(dir?: string): string|nil Find Luacheck configuration file (`.luacheckrc`).
---@field parse_luacheck_output fun(output: string): table[] Parses Luacheck raw output into an array of issue tables.
---@field run_luacheck fun(file_path: string, config_file?: string): boolean, table[] Runs Luacheck on a file. Returns `success, issues`. @throws table If validation fails.
---@field fix_trailing_whitespace fun(content: string): string Removes trailing whitespace from multiline string literals.
---@field fix_unused_variables fun(file_path: string, issues?: table): boolean Fixes unused variables based on Luacheck output by prefixing with `_`. Returns `true` if modified. @throws table If validation or file IO fails critically.
---@field fix_string_concat fun(content: string): string Optimizes string concatenation operations.
---@field fix_type_annotations fun(content: string): string Adds basic type annotations to function docs (experimental).
---@field fix_lua_version_compat fun(content: string, target_version?: string): string Applies basic fixes for Lua 5.1 compatibility (e.g., comments out `goto`).
---@field run_custom_fixers fun(file_path: string, issues?: table): boolean Runs all enabled custom fixers on a file. Returns `true` if modified. @throws table If validation or file IO fails critically.
---@field fix_file fun(file_path: string): boolean Applies all configured fixes (Luacheck -> Custom Fixers -> StyLua) to a single file. Returns overall success. @throws table If validation, IO, or sub-processes fail critically.
---@field register_custom_fixer fun(name: string, options: {name: string, fix: function, description?: string}): boolean Registers a custom fixer function. @throws table If validation fails.
---@field fix_files fun(file_paths: string[]): boolean, table Fixes multiple files. Returns `success, results_table`. @throws table If validation fails.
---@field fix_lua_files fun(directory?: string, options?: { include?: string[], exclude?: string[], limit?: number, sort_by_mtime?: boolean, generate_report?: boolean, report_file?: string }): boolean, table Finds and fixes Lua files in a directory. Returns `success, results_table`. @throws table If validation fails.
---@field run_cli fun(args?: table): boolean Command line interface entry point. Returns success.
---@field register_with_firmo fun(firmo: table): codefix_module Registers the module and CLI commands with a Firmo instance. Returns self. @throws table If validation fails.
---@field fix_directory fun(...) [Not Implemented] Fix all Lua files in a directory.
---@field unregister_custom_fixer fun(...) [Not Implemented] Remove a custom code fixer.
---@field backup_file fun(file_path: string): boolean, table? Creates a backup file. Returns `success, error?`. @throws table If validation fails. (Note: Internal helper `backup_file` exists, but not exported directly on M).
---@field restore_backup fun(...) [Not Implemented] Restore a file from backup.
---@field get_custom_fixers fun(...) [Not Implemented] Get all registered custom fixers.
---@field validate_lua_syntax fun(...) [Not Implemented] Check if Lua code has valid syntax.
---@field format_issues fun(...) [Not Implemented] Format Luacheck issues as readable text.

local M = {}

--- Module version
M._VERSION = "1.0.0"

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
    return logging.get_logger("codefix")
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

local parser = try_require("lib.tools.parser")
local json = try_require("lib.tools.json") -- Use the more complete JSON tool module

-- Configuration options
M.config = {
  -- General options
  enabled = false, -- Enable code fixing functionality
  verbose = false, -- Enable verbose output
  debug = false, -- Enable debug output

  -- StyLua options
  use_stylua = true, -- Use StyLua for formatting
  stylua_path = "stylua", -- Path to StyLua executable
  stylua_config = nil, -- Path to StyLua config file

  -- Luacheck options
  use_luacheck = true, -- Use Luacheck for linting
  luacheck_path = "luacheck", -- Path to Luacheck executable
  luacheck_config = nil, -- Path to Luacheck config file

  -- Custom fixers
  custom_fixers = {
    trailing_whitespace = true, -- Fix trailing whitespace in strings
    unused_variables = true, -- Fix unused variables by prefixing with underscore
    string_concat = true, -- Optimize string concatenation
    type_annotations = false, -- Add type annotations (disabled by default)
    lua_version_compat = false, -- Fix Lua version compatibility issues (disabled by default)
  },

  -- Input/output
  include = { "%.lua$" }, -- File patterns to include
  exclude = { "_test%.lua$", "_spec%.lua$", "test/", "tests/", "spec/" }, -- File patterns to exclude
  backup = true, -- Create backup files when fixing
  backup_ext = ".bak", -- Extension for backup files
}

---@param command string The shell command to execute
---@return string|nil output Command output or nil on error
---@return boolean success Whether the command succeeded
---@return number exit_code Exit code from the command.
---@return table? error_object Error object if execution failed critically, otherwise `nil`.
---@throws table If `command` validation fails.
---@private
local function execute_command(command)
  -- Validate required parameters
  get_error_handler().assert(
    command ~= nil and type(command) == "string",
    "Command must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { command_type = type(command) }
  )

  get_error_handler().assert(
    command:len() > 0,
    "Command cannot be empty",
    get_error_handler().CATEGORY.VALIDATION,
    { command_length = command:len() }
  )

  get_logger().debug("Executing command", {
    command = command,
    debug_mode = M.config.debug,
  })

  -- Execute command with proper error handling
  local handle_success, handle, handle_err = get_error_handler().safe_io_operation(function()
    return io.popen(command .. " 2>&1", "r")
  end, "command", { operation = "popen", command = command })

  if not handle_success or not handle then
    local err_obj = get_error_handler().io_error("Failed to execute command", get_error_handler().SEVERITY.ERROR, {
      command = command,
      error = handle_err or "I/O operation failed",
    })

    get_logger().error("Failed to execute command", {
      command = command,
      error = get_error_handler().format_error(err_obj),
    })

    return nil, false, -1, err_obj
  end

  -- Read output with error handling
  local read_success, result, read_err = get_error_handler().safe_io_operation(function()
    return handle:read("*a")
  end, "command_output", { operation = "read", command = command })

  if not read_success then
    local err_obj = get_error_handler().io_error("Failed to read command output", get_error_handler().SEVERITY.ERROR, {
      command = command,
      error = read_err or "Read operation failed",
    })

    get_logger().error("Failed to read command output", {
      command = command,
      error = get_error_handler().format_error(err_obj),
    })

    -- Try to close handle to avoid resource leaks
    get_error_handler().try(function()
      handle:close()
    end)

    return nil, false, -1, err_obj
  end

  -- Close handle with error handling
  local close_success, close_result, close_err = get_error_handler().safe_io_operation(function()
    return handle:close()
  end, "command_close", { operation = "close", command = command })

  local success, reason, code

  if close_success then
    success, reason, code = table.unpack(close_result)
  else
    success = false
    reason = close_err or "Close operation failed"
    code = -1

    get_logger().warn("Failed to close command handle properly", {
      command = command,
      error = reason,
    })
  end

  code = code or 0

  get_logger().debug("Command execution completed", {
    command = command,
    exit_code = code,
    output_length = result and #result or 0,
    success = success,
  })

  return result, success, code, reason
end

-- Get the operating system name with error handling
---@return "windows"|"macos"|"linux"|"bsd"|"unix" os_name The detected operating system name.
---@private
local function get_os()
  -- Use path separator to detect OS type (cross-platform approach)
  local success, os_info = get_error_handler().try(function()
    local is_windows = package.config:sub(1, 1) == "\\"

    if is_windows then
      return { name = "windows", source = "path_separator" }
    end

    -- For Unix-like systems, we can differentiate further if needed
    -- Try to use filesystem module for platform detection first
    if fs and get_fs()._PLATFORM then
      local platform = get_fs()._PLATFORM:lower()

      if platform:match("darwin") then
        return { name = "macos", source = "filesystem_module" }
      elseif platform:match("linux") then
        return { name = "linux", source = "filesystem_module" }
      elseif platform:match("bsd") then
        return { name = "bsd", source = "filesystem_module" }
      end
    end

    -- Fall back to uname command for Unix-like systems
    local uname_success, result = get_error_handler().safe_io_operation(function()
      local popen_cmd = "uname -s"
      local handle = io.popen(popen_cmd)
      if not handle then
        return nil, "Failed to open uname command"
      end

      local os_name = handle:read("*l")
      handle:close()

      if not os_name then
        return nil, "Failed to read OS name from uname"
      end

      return os_name:lower()
    end, "uname_command", { operation = "get_os_name" })

    if uname_success and result then
      if result:match("darwin") then
        return { name = "macos", source = "uname_command" }
      elseif result:match("linux") then
        return { name = "linux", source = "uname_command" }
      elseif result:match("bsd") then
        return { name = "bsd", source = "uname_command" }
      end
    end

    -- Default to detecting based on path separator
    return { name = "unix", source = "path_separator_fallback" }
  end)

  if not success then
    get_logger().warn("Failed to detect operating system", {
      error = get_error_handler().format_error(os_info),
      fallback = "unix",
    })
    return "unix"
  end

  get_logger().debug("Detected operating system", {
    os = os_info.name,
    detection_source = os_info.source,
  })

  return os_info.name
end

--- Logs info message if verbose or debug is enabled.
---@param message string Log message.
---@param context? table Additional structured data.
---@private
local function log_info(message, context)
  if M.config.verbose or M.config.debug then
    if type(context) == "table" then
      get_logger().info(message, context)
    else
      get_logger().info(message, { raw_message = message })
    end
  end
end

--- Logs debug message if debug is enabled.
---@param message string Log message.
---@param context? table Additional structured data.
---@private
local function log_debug(message, context)
  if M.config.debug then
    if type(context) == "table" then
      get_logger().debug(message, context)
    else
      get_logger().debug(message, { raw_message = message })
    end
  end
end

--- Logs warning message.
---@param message string Log message.
---@param context? table Additional structured data.
---@private
local function log_warning(message, context)
  if type(context) == "table" then
    get_logger().warn(message, context)
  else
    get_logger().warn(message, { raw_message = message })
  end
end

--- Logs error message.
---@param message string Log message.
---@param context? table Additional structured data.
---@private
local function log_error(message, context)
  if type(context) == "table" then
    get_logger().error(message, context)
  else
    get_logger().error(message, { raw_message = message })
  end
end

--- Logs success message (at INFO level) and prints to console.
---@param message string Log message.
---@param context? table Additional structured data.
---@private
local function log_success(message, context)
  -- Log at info level with structured data
  if type(context) == "table" then
    get_logger().info(message, context)
  else
    get_logger().info(message, { raw_message = message, success = true })
  end

  -- Also print to console for user feedback with [SUCCESS] prefix using safe I/O
  get_error_handler().safe_io_operation(function()
    io.write("[SUCCESS] " .. message .. "\n")
  end, "console", { operation = "write_success", message = message })
end

-- Filesystem module was already loaded at the top of the file
get_logger().debug("Filesystem module configuration", {
  version = get_fs()._VERSION,
  platform = get_fs()._PLATFORM,
  module_path = package.searchpath("lib.tools.filesystem", package.path),
})

--- Checks if a file exists using the filesystem module.
---@param path string Path to check.
---@return boolean exists `true` if file exists, `false` otherwise or on error.
---@throws table If `path` validation fails.
---@private
local function file_exists(path)
  -- Validate required parameters
  get_error_handler().assert(
    path ~= nil and type(path) == "string",
    "Path must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { path_type = type(path) }
  )

  get_error_handler().assert(
    path:len() > 0,
    "Path cannot be empty",
    get_error_handler().CATEGORY.VALIDATION,
    { path_length = path:len() }
  )

  local success, result, err = get_error_handler().safe_io_operation(function()
    return get_fs().file_exists(path)
  end, path, { operation = "file_exists" })

  if not success then
    log_warning("Failed to check if file exists", {
      path = path,
      error = get_error_handler().format_error(result),
    })
    return false
  end

  return result
end

--- Reads file content using the filesystem module.
---@param path string Path to read.
---@return string|nil content File content string, or `nil` on error.
---@return table? error Error object if reading failed.
---@throws table If `path` validation fails.
---@private
local function read_file(path)
  -- Validate required parameters
  get_error_handler().assert(
    path ~= nil and type(path) == "string",
    "Path must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { path_type = type(path) }
  )

  get_error_handler().assert(
    path:len() > 0,
    "Path cannot be empty",
    get_error_handler().CATEGORY.VALIDATION,
    { path_length = path:len() }
  )

  local success, content, err = get_error_handler().safe_io_operation(function()
    return get_fs().read_file(path)
  end, path, { operation = "read_file" })

  if not success then
    local error_obj = get_error_handler().io_error("Failed to read file", get_error_handler().SEVERITY.ERROR, {
      path = path,
      operation = "read_file",
      error = err,
    })

    log_error("Failed to read file", {
      path = path,
      error = get_error_handler().format_error(error_obj),
    })

    return nil, error_obj
  end

  log_debug("Successfully read file", {
    path = path,
    content_size = content and #content or 0,
  })

  return content
end

--- Writes content to a file using the filesystem module.
---@param path string Path to write to.
---@param content string Content to write.
---@return boolean success `true` if write succeeded.
---@return table? error Error object if writing failed.
---@throws table If `path` or `content` validation fails.
---@private
local function write_file(path, content)
  -- Validate required parameters
  get_error_handler().assert(
    path ~= nil and type(path) == "string",
    "Path must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { path_type = type(path) }
  )

  get_error_handler().assert(
    path:len() > 0,
    "Path cannot be empty",
    get_error_handler().CATEGORY.VALIDATION,
    { path_length = path:len() }
  )

  get_error_handler().assert(
    content ~= nil,
    "Content cannot be nil",
    get_error_handler().CATEGORY.VALIDATION,
    { content_type = type(content) }
  )

  local success, result, err = get_error_handler().safe_io_operation(function()
    return get_fs().write_file(path, content)
  end, path, { operation = "write_file", content_size = type(content) == "string" and #content or 0 })

  if not success then
    local error_obj = get_error_handler().io_error("Failed to write file", get_error_handler().SEVERITY.ERROR, {
      path = path,
      operation = "write_file",
      error = err,
    })

    log_error("Failed to write file", {
      path = path,
      error = get_error_handler().format_error(error_obj),
    })

    return false, error_obj
  end

  log_debug("Successfully wrote file", {
    path = path,
    content_size = type(content) == "string" and #content or 0,
  })

  return true
end

--- Creates a backup copy of a file if backups are enabled in config.
---@param path string Path to the file to back up.
---@return boolean success `true` if backup was created successfully or skipped, `false` on error.
---@return table? error Error object if backup failed.
---@throws table If `path` validation fails.
---@private
local function backup_file(path)
  -- Skip if backups are disabled
  if not M.config.backup then
    log_debug("Backup is disabled, skipping", {
      path = path,
    })
    return true
  end

  -- Validate required parameters
  get_error_handler().assert(
    path ~= nil and type(path) == "string",
    "Path must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { path_type = type(path) }
  )

  get_error_handler().assert(
    path:len() > 0,
    "Path cannot be empty",
    get_error_handler().CATEGORY.VALIDATION,
    { path_length = path:len() }
  )

  get_error_handler().assert(
    M.config.backup_ext ~= nil and type(M.config.backup_ext) == "string",
    "Backup extension must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { backup_ext_type = type(M.config.backup_ext) }
  )

  log_debug("Creating backup of file", {
    path = path,
    backup_ext = M.config.backup_ext,
  })

  -- Check if file exists before backing up
  local file_check_success, file_exists_result = get_error_handler().try(function()
    return get_fs().file_exists(path)
  end)

  if not file_check_success or not file_exists_result then
    local error_obj = get_error_handler().io_error(
      "Source file does not exist or cannot be accessed",
      get_error_handler().SEVERITY.ERROR,
      {
        path = path,
        operation = "backup_file",
      }
    )

    log_error("Failed to backup file", {
      path = path,
      reason = "source file does not exist or cannot be accessed",
      error = get_error_handler().format_error(error_obj),
    })

    return false, error_obj
  end

  -- Create backup with error handling
  local backup_path = path .. M.config.backup_ext

  local success, result, err = get_error_handler().safe_io_operation(function()
    return get_fs().copy_file(path, backup_path)
  end, path, { operation = "copy_file", backup_path = backup_path })

  if not success then
    local error_obj = get_error_handler().io_error("Failed to create backup file", get_error_handler().SEVERITY.ERROR, {
      path = path,
      backup_path = backup_path,
      operation = "backup_file",
      error = err,
    })

    log_error("Failed to create backup file", {
      path = path,
      backup_path = backup_path,
      error = get_error_handler().format_error(error_obj),
    })

    return false, error_obj
  end

  log_debug("Backup file created successfully", {
    path = backup_path,
  })

  return true
end

--- Checks if a shell command exists using platform-appropriate methods (`where` or `command -v`).
---@param cmd string Command name to check.
---@return boolean exists `true` if the command is found in the system path.
---@throws table If `cmd` validation fails.
---@private
local function command_exists(cmd)
  -- Validate required parameters
  get_error_handler().assert(
    cmd ~= nil and type(cmd) == "string",
    "Command must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { cmd_type = type(cmd) }
  )

  get_error_handler().assert(
    cmd:len() > 0,
    "Command cannot be empty",
    get_error_handler().CATEGORY.VALIDATION,
    { cmd_length = cmd:len() }
  )

  local command_check_success, os_name_or_err = get_error_handler().try(function()
    return get_os()
  end)

  if not command_check_success then
    log_warning("Failed to get OS type for command check", {
      error = get_error_handler().format_error(os_name_or_err),
      cmd = cmd,
      fallback = "unix",
    })
    os_name_or_err = "unix"
  end

  local os_name = os_name_or_err
  local test_cmd

  log_debug("Checking if command exists", {
    cmd = cmd,
    os = os_name,
  })

  -- Construct platform-appropriate command check
  if os_name == "windows" then
    test_cmd = string.format("where %s 2>nul", cmd)
  else
    test_cmd = string.format("command -v %s 2>/dev/null", cmd)
  end

  -- Execute check with error handling
  local result, success, code, reason = execute_command(test_cmd)

  -- Check result with proper validation
  local cmd_exists = success and result and result:len() > 0

  log_debug("Command existence check result", {
    cmd = cmd,
    exists = cmd_exists,
    exit_code = code,
    result_length = result and result:len() or 0,
  })

  return cmd_exists
end

--- Finds a configuration file by searching upwards from a starting directory.
---@param filename string The name of the configuration file to find.
---@param start_dir? string The directory to start searching from (defaults to ".").
---@return string|nil config_path The absolute path to the found file, or `nil` if not found or on error.
---@throws table If `filename` or `start_dir` validation fails.
---@private
local function find_config_file(filename, start_dir)
  -- Validate required parameters
  get_error_handler().assert(
    filename ~= nil and type(filename) == "string",
    "Filename must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { filename_type = type(filename) }
  )

  get_error_handler().assert(
    filename:len() > 0,
    "Filename cannot be empty",
    get_error_handler().CATEGORY.VALIDATION,
    { filename_length = filename:len() }
  )

  -- Process optional parameters with defaults
  start_dir = start_dir or "."

  get_error_handler().assert(
    type(start_dir) == "string",
    "Start directory must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { start_dir_type = type(start_dir) }
  )

  log_debug("Searching for config file", {
    filename = filename,
    start_dir = start_dir,
  })

  -- Use try/catch pattern for the entire search process
  local search_success, search_result = get_error_handler().try(function()
    local current_dir = start_dir

    -- Get absolute path with error handling
    local abs_success, abs_path = get_error_handler().try(function()
      return get_fs().get_absolute_path(current_dir)
    end)

    if abs_success and abs_path then
      current_dir = abs_path
    else
      -- Fallback for absolute path using shell command if filesystem module fails
      log_warning("Failed to get absolute path with filesystem module", {
        dir = current_dir,
        error = get_error_handler().format_error(abs_path),
        fallback = "using shell pwd command",
      })

      if not current_dir:match("^[/\\]") and get_os() ~= "windows" then
        local pwd_result, pwd_success = execute_command("pwd")
        if pwd_success and pwd_result then
          current_dir = pwd_result:gsub("%s+$", "") .. "/" .. current_dir
        end
      end
    end

    log_debug("Starting config file search from directory", {
      absolute_dir = current_dir,
    })

    local iteration_count = 0
    local max_iterations = 50 -- Safety limit to prevent infinite loops

    -- Walk up the directory tree with proper error handling
    while current_dir and current_dir ~= "" and iteration_count < max_iterations do
      iteration_count = iteration_count + 1

      -- Construct config path with error handling
      local config_path
      local join_success, joined_path = get_error_handler().try(function()
        return get_fs().join_paths(current_dir, filename)
      end)

      if join_success and joined_path then
        config_path = joined_path
      else
        -- Fallback for path joining if filesystem module fails
        log_warning("Failed to join paths with filesystem module", {
          dir = current_dir,
          filename = filename,
          error = get_error_handler().format_error(joined_path),
          fallback = "using string concatenation",
        })

        config_path = current_dir .. "/" .. filename
      end

      -- Check if file exists with error handling
      local exists_success, file_exists_result = get_error_handler().try(function()
        return file_exists(config_path)
      end)

      if exists_success and file_exists_result then
        log_debug("Found config file", {
          path = config_path,
          iterations = iteration_count,
        })
        return config_path
      end

      -- Move up one directory with error handling
      local parent_success, parent_dir = get_error_handler().try(function()
        return get_fs().get_directory_name(current_dir)
      end)

      if not parent_success or not parent_dir then
        -- Fallback for get_directory_name if filesystem module fails
        log_warning("Failed to get parent directory with filesystem module", {
          dir = current_dir,
          error = get_error_handler().format_error(parent_dir),
          fallback = "using string pattern matching",
        })

        parent_dir = current_dir:match("(.+)[/\\][^/\\]+$")
      end

      -- Check if we've reached the root directory
      if not parent_dir or current_dir == parent_dir then
        log_debug("Reached root directory without finding config file", {
          current_dir = current_dir,
          filename = filename,
          iterations = iteration_count,
        })
        break
      end

      current_dir = parent_dir
    end

    -- Handle hitting max iterations
    if iteration_count >= max_iterations then
      log_warning("Hit maximum directory traversal limit without finding config file", {
        max_iterations = max_iterations,
        filename = filename,
        start_dir = start_dir,
      })
    end

    -- Not found case
    log_debug("Config file not found", {
      filename = filename,
      start_dir = start_dir,
      iterations = iteration_count,
    })

    return nil
  end)

  if not search_success then
    log_error("Error while searching for config file", {
      filename = filename,
      start_dir = start_dir,
      error = get_error_handler().format_error(search_result),
    })
    return nil
  end

  return search_result
end

--- Finds files matching include/exclude patterns using `get_fs().discover_files` or a Lua-based fallback.
---@param include_patterns string[] Array of Lua patterns to include.
---@param exclude_patterns string[] Array of Lua patterns to exclude.
---@param start_dir string Directory to start the search from.
---@return string[] files A table containing absolute paths of matching files. Returns empty table on error.
---@throws table If parameter validation fails.
---@private
local function find_files(include_patterns, exclude_patterns, start_dir)
  -- Validate and process parameters
  get_error_handler().assert(
    include_patterns ~= nil,
    "Include patterns parameter is required",
    get_error_handler().CATEGORY.VALIDATION,
    { include_patterns_type = type(include_patterns) }
  )

  if type(include_patterns) == "string" then
    include_patterns = { include_patterns }
  end

  get_error_handler().assert(
    type(include_patterns) == "table",
    "Include patterns must be a table or string",
    get_error_handler().CATEGORY.VALIDATION,
    { include_patterns_type = type(include_patterns) }
  )

  if exclude_patterns ~= nil then
    if type(exclude_patterns) == "string" then
      exclude_patterns = { exclude_patterns }
    end

    get_error_handler().assert(
      type(exclude_patterns) == "table",
      "Exclude patterns must be a table or string",
      get_error_handler().CATEGORY.VALIDATION,
      { exclude_patterns_type = type(exclude_patterns) }
    )
  else
    exclude_patterns = {}
  end

  start_dir = start_dir or "."

  get_error_handler().assert(
    type(start_dir) == "string",
    "Start directory must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { start_dir_type = type(start_dir) }
  )

  log_debug("Using filesystem module to find files", {
    directory = start_dir,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns,
  })

  -- Use try/catch pattern for the entire file finding process
  local find_success, result = get_error_handler().try(function()
    -- Normalize path with error handling
    local norm_success, normalized_dir = get_error_handler().try(function()
      return get_fs().normalize_path(start_dir)
    end)

    if not norm_success or not normalized_dir then
      log_warning("Failed to normalize directory path", {
        directory = start_dir,
        error = get_error_handler().format_error(normalized_dir),
        fallback = "using original path",
      })
      normalized_dir = start_dir
    end

    -- Get absolute path with error handling
    local abs_success, absolute_dir = get_error_handler().try(function()
      return get_fs().get_absolute_path(normalized_dir)
    end)

    if not abs_success or not absolute_dir then
      log_warning("Failed to get absolute directory path", {
        directory = normalized_dir,
        error = get_error_handler().format_error(absolute_dir),
        fallback = "using normalized path",
      })
      absolute_dir = normalized_dir
    end

    log_debug("Finding files in normalized directory", {
      normalized_dir = normalized_dir,
      absolute_dir = absolute_dir,
    })

    -- Use filesystem discover_files function with error handling
    local discover_success, files = get_error_handler().try(function()
      return get_fs().discover_files({ absolute_dir }, include_patterns, exclude_patterns)
    end)

    if not discover_success or not files then
      local error_obj = get_error_handler().create(
        "Failed to discover files using filesystem module",
        get_error_handler().CATEGORY.IO,
        get_error_handler().SEVERITY.ERROR,
        {
          directory = absolute_dir,
          error = get_error_handler().format_error(files),
        }
      )

      log_error("Failed to discover files", {
        directory = absolute_dir,
        error = get_error_handler().format_error(error_obj),
        fallback = "falling back to Lua-based file discovery",
      })

      -- Try fallback method
      ---@diagnostic disable-next-line: undefined-global
      return find_files_lua(include_patterns, exclude_patterns, absolute_dir)
    end

    log_info("Found files using filesystem module", {
      file_count = #files,
      directory = absolute_dir,
    })

    return files
  end)

  if not find_success then
    log_error("Error during file discovery", {
      directory = start_dir,
      error = get_error_handler().format_error(result),
      fallback = "returning empty file list",
    })
    return {}
  end

  return result
end

--- Lua-based fallback for finding files recursively using `fs.scan_directory` and pattern matching.
---@param include_patterns string[] Array of Lua patterns to include.
---@param exclude_patterns string[] Array of Lua patterns to exclude.
---@param dir string The absolute directory path to start scanning from.
---@return string[] files A table containing absolute paths of matching files. Returns empty table on error.
---@throws table If parameter validation fails.
---@private
local function find_files_lua(include_patterns, exclude_patterns, dir)
  -- Validate and process parameters
  get_error_handler().assert(
    include_patterns ~= nil,
    "Include patterns parameter is required",
    get_error_handler().CATEGORY.VALIDATION,
    { include_patterns_type = type(include_patterns) }
  )

  if type(include_patterns) == "string" then
    include_patterns = { include_patterns }
  end

  get_error_handler().assert(
    type(include_patterns) == "table",
    "Include patterns must be a table or string",
    get_error_handler().CATEGORY.VALIDATION,
    { include_patterns_type = type(include_patterns) }
  )

  if exclude_patterns ~= nil then
    if type(exclude_patterns) == "string" then
      exclude_patterns = { exclude_patterns }
    end

    get_error_handler().assert(
      type(exclude_patterns) == "table",
      "Exclude patterns must be a table or string",
      get_error_handler().CATEGORY.VALIDATION,
      { exclude_patterns_type = type(exclude_patterns) }
    )
  else
    exclude_patterns = {}
  end

  get_error_handler().assert(
    dir ~= nil and type(dir) == "string",
    "Directory must be a string",
    get_error_handler().CATEGORY.VALIDATION,
    { dir_type = type(dir) }
  )

  log_debug("Using filesystem module for Lua-based file discovery", {
    directory = dir,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns,
  })

  -- Use try/catch pattern for the file finding process
  local find_success, result = get_error_handler().try(function()
    -- Normalize directory path with error handling
    local norm_success, normalized_dir = get_error_handler().try(function()
      return get_fs().normalize_path(dir)
    end)

    if not norm_success or not normalized_dir then
      log_warning("Failed to normalize directory path", {
        directory = dir,
        error = get_error_handler().format_error(normalized_dir),
        fallback = "using original path",
      })
      normalized_dir = dir
    end

    -- Use scan_directory to get all files recursively with error handling
    local scan_success, all_files = get_error_handler().try(function()
      return get_fs().scan_directory(normalized_dir, true)
    end)

    if not scan_success or not all_files then
      local error_obj = get_error_handler().io_error("Failed to scan directory", get_error_handler().SEVERITY.ERROR, {
        directory = normalized_dir,
        error = get_error_handler().format_error(all_files),
      })

      log_error("Failed to scan directory for files", {
        directory = normalized_dir,
        error = get_error_handler().format_error(error_obj),
        fallback = "returning empty file list",
      })

      return {}
    end

    local files = {}
    local error_count = 0
    local max_errors = 10 -- Limit errors to avoid flooding logs

    -- Filter files using include and exclude patterns
    for _, file_path in ipairs(all_files) do
      local include_file = false

      -- Check include patterns with error handling
      local include_success, include_result = get_error_handler().try(function()
        for _, pattern in ipairs(include_patterns) do
          if file_path:match(pattern) then
            return true
          end
        end
        return false
      end)

      if not include_success then
        if error_count < max_errors then
          log_warning("Error while checking include patterns", {
            file = file_path,
            error = get_error_handler().format_error(include_result),
          })
          error_count = error_count + 1
        elseif error_count == max_errors then
          log_warning("Too many pattern matching errors, suppressing further messages")
          error_count = error_count + 1
        end
        include_result = false
      end

      include_file = include_result

      -- Check exclude patterns with error handling if file is included
      if include_file then
        local exclude_success, exclude_result = get_error_handler().try(function()
          for _, pattern in ipairs(exclude_patterns) do
            -- Get relative path with error handling
            local rel_path
            local rel_success, rel_path_result = get_error_handler().try(function()
              return get_fs().get_relative_path(file_path, normalized_dir)
            end)

            if rel_success and rel_path_result then
              rel_path = rel_path_result
              if rel_path and rel_path:match(pattern) then
                return true -- Should exclude
              end
            end
          end
          return false -- Don't exclude
        end)

        if not exclude_success then
          if error_count < max_errors then
            log_warning("Error while checking exclude patterns", {
              file = file_path,
              error = get_error_handler().format_error(exclude_result),
            })
            error_count = error_count + 1
          elseif error_count == max_errors then
            log_warning("Too many pattern matching errors, suppressing further messages")
            error_count = error_count + 1
          end
          -- Be conservative on errors - don't include the file
          include_file = false
        else
          -- If exclude_result is true, we should exclude the file
          include_file = not exclude_result
        end
      end

      if include_file then
        log_debug("Including file in results", {
          file = file_path,
        })
        table.insert(files, file_path)
      end
    end

    log_info("Found files using Lua-based file discovery", {
      file_count = #files,
      directory = normalized_dir,
      errors = error_count,
    })

    return files
  end)

  if not find_success then
    log_error("Error during Lua-based file discovery", {
      directory = dir,
      error = get_error_handler().format_error(result),
      fallback = "returning empty file list",
    })
    return {}
  end

  return result
end

--- Initializes the codefix module, merging provided options with defaults.
---@param options? table Custom configuration options to override defaults (structure matches `M.config`).
---@return codefix_module self The module instance (`M`) for method chaining.
function M.init(options)
  options = options or {}

  -- Apply custom options over defaults
  for k, v in pairs(options) do
    if type(v) == "table" and type(M.config[k]) == "table" then
      -- Merge tables
      for k2, v2 in pairs(v) do
        M.config[k][k2] = v2
      end
    else
      M.config[k] = v
    end
  end

  return M
end

----------------------------------
-- StyLua Integration Functions --
----------------------------------

--- Checks if the StyLua executable (specified by `M.config.stylua_path`) exists and is executable.
---@return boolean available `true` if StyLua is found, `false` otherwise.
function M.check_stylua()
  if not command_exists(M.config.stylua_path) then
    log_warning("StyLua not found at: " .. M.config.stylua_path)
    return false
  end

  log_debug("StyLua found at: " .. M.config.stylua_path)
  return true
end

--- Finds a StyLua configuration file (`stylua.toml` or `.stylua.toml`) by searching upwards from a directory.
---@param dir? string Directory to start searching from (defaults to current directory ".").
---@return string|nil config_path Absolute path to the found configuration file, or `nil` if not found.
function M.find_stylua_config(dir)
  local config_file = M.config.stylua_config

  if not config_file then
    -- Try to find configuration files
    config_file = find_config_file("stylua.toml", dir) or find_config_file(".stylua.toml", dir)
  end

  if config_file then
    log_debug("Found StyLua config at: " .. config_file)
  else
    log_debug("No StyLua config found")
  end

  return config_file
end

--- Run StyLua on a file to format it
---@param file_path string Path to the file to format
---@param config_file? string Optional path to a specific StyLua configuration file to use.
---@return boolean success `true` if StyLua ran successfully (exit code 0), `false` otherwise.
---@return string? error_message Raw output from StyLua if it failed, `nil` otherwise.
---@throws table If `file_path` validation fails.
function M.run_stylua(file_path, config_file)
  if not M.config.use_stylua then
    log_debug("StyLua is disabled, skipping")
    return true
  end

  if not M.check_stylua() then
    return false, "StyLua not available"
  end

  config_file = config_file or M.find_stylua_config(file_path:match("(.+)/[^/]+$"))

  local cmd = M.config.stylua_path

  if config_file then
    cmd = cmd .. string.format(' --config-path "%s"', config_file)
  end

  -- Make backup before running
  if M.config.backup then
    local success, err = backup_file(file_path)
    if not success then
      log_warning("Failed to create backup for " .. file_path .. ": " .. (err or "unknown error"))
    end
  end

  -- Run StyLua
  cmd = cmd .. string.format(' "%s"', file_path)
  log_info("Running StyLua on " .. file_path)

  local result, success, code = execute_command(cmd)

  if not success or code ~= 0 then
    log_error("StyLua failed on " .. file_path .. ": " .. (result or "unknown error"))
    return false, result
  end

  log_success("StyLua formatted " .. file_path)
  return true
end

-----------------------------------
-- Luacheck Integration Functions --
-----------------------------------

--- Checks if the Luacheck executable (specified by `M.config.luacheck_path`) exists and is executable.
---@return boolean available `true` if Luacheck is found, `false` otherwise.
function M.check_luacheck()
  if not command_exists(M.config.luacheck_path) then
    log_warning("Luacheck not found at: " .. M.config.luacheck_path)
    return false
  end

  log_debug("Luacheck found at: " .. M.config.luacheck_path)
  return true
end

--- Finds a Luacheck configuration file (`.luacheckrc` or `luacheck.rc`) by searching upwards from a directory.
---@param dir? string Directory to start searching from (defaults to current directory ".").
---@return string|nil config_path Absolute path to the found configuration file, or `nil` if not found.
function M.find_luacheck_config(dir)
  local config_file = M.config.luacheck_config

  if not config_file then
    -- Try to find configuration files
    config_file = find_config_file(".luacheckrc", dir) or find_config_file("luacheck.rc", dir)
  end

  if config_file then
    log_debug("Found Luacheck config at: " .. config_file)
  else
    log_debug("No Luacheck config found")
  end

  return config_file
end

--- Parse Luacheck output into a structured format
--- Parses the raw text output from the `luacheck --codes` command into a structured array of issues.
---@param output string The raw output string from Luacheck.
---@return table[] issues An array of issue tables, each containing `{ file, line, col, code, message }`. Returns empty table if output is nil or unparseable.
function M.parse_luacheck_output(output)
  if not output then
    return {}
  end

  local issues = {}

  -- Parse each line
  for line in output:gmatch("[^\r\n]+") do
    -- Look for format: filename:line:col: (code) message
    local file, line, col, code, message = line:match("([^:]+):(%d+):(%d+): %(([%w_]+)%) (.*)")

    if file and line and col and code and message then
      table.insert(issues, {
        file = file,
        line = tonumber(line),
        col = tonumber(col),
        code = code,
        message = message,
      })
    end
  end

  return issues
end

--- Run Luacheck on a file to check for issues
---@param file_path string Path to the file to check
---@param config_file? string Optional path to a specific Luacheck configuration file to use.
---@return boolean success `true` if Luacheck ran without errors (exit code 0 or 1), `false` if errors occurred (exit code > 1) or if Luacheck is unavailable.
---@return table[] issues An array of issue tables parsed from Luacheck's output.
---@throws table If `file_path` validation fails.
function M.run_luacheck(file_path, config_file)
  if not M.config.use_luacheck then
    log_debug("Luacheck is disabled, skipping")
    return true
  end

  if not M.check_luacheck() then
    return false, "Luacheck not available"
  end

  config_file = config_file or M.find_luacheck_config(file_path:match("(.+)/[^/]+$"))

  local cmd = M.config.luacheck_path .. " --codes --no-color"

  -- Luacheck automatically finds .luacheckrc in parent directories
  -- We don't need to specify the config file explicitly

  -- Run Luacheck
  cmd = cmd .. string.format(' "%s"', file_path)
  log_info("Running Luacheck on " .. file_path)

  local result, success, code = execute_command(cmd)

  -- Parse the output
  local issues = M.parse_luacheck_output(result)

  -- Code 0 = no issues
  -- Code 1 = only warnings
  -- Code 2+ = errors
  if code > 1 then
    log_error("Luacheck found " .. #issues .. " issues in " .. file_path)
    return false, issues
  elseif code == 1 then
    log_warning("Luacheck found " .. #issues .. " warnings in " .. file_path)
    return true, issues
  end

  log_success("Luacheck verified " .. file_path)
  return true, issues
end

-----------------------------
-- Custom Fixer Functions --
-----------------------------

--- Removes trailing whitespace found within Lua multiline string literals (`[[...]]`).
---@param content string The source code content to fix.
---@return string fixed_content The content with trailing whitespace potentially removed from multiline strings.
function M.fix_trailing_whitespace(content)
  if not M.config.custom_fixers.trailing_whitespace then
    return content
  end

  log_debug("Fixing trailing whitespace in multiline strings")

  -- Find multiline strings with trailing whitespace
  local fixed_content = content:gsub("(%[%[.-([%s]+)\n.-]%])", function(match, spaces)
    return match:gsub(spaces .. "\n", "\n")
  end)

  return fixed_content
end

--- Attempts to fix unused local variables and arguments reported by Luacheck by prefixing their names with an underscore (`_`).
--- Reads the file content, applies changes based on issue locations, and writes the file back if modified.
---@param file_path string Path to the file to fix.
---@param issues? table[] Optional array of issues from a previous Luacheck run. If not provided, this fixer does nothing.
---@return boolean modified `true` if the file content was modified and saved, `false` otherwise.
---@throws table If `file_path` validation or critical file I/O fails.
function M.fix_unused_variables(file_path, issues)
  if not M.config.custom_fixers.unused_variables or not issues then
    return false
  end

  log_debug("Fixing unused variables in " .. file_path)

  local content, err = read_file(file_path)
  if not content then
    log_error("Failed to read file for unused variable fixing: " .. (err or "unknown error"))
    return false
  end

  local fixed = false
  local lines = {}

  -- Split content into lines
  for line in content:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end

  -- Look for unused variable issues
  for _, issue in ipairs(issues) do
    if issue.code == "212" or issue.code == "213" then -- Unused variable/argument codes
      local var_name = issue.message:match("unused variable '([^']+)'")
        or issue.message:match("unused argument '([^']+)'")

      if var_name and issue.line and issue.line <= #lines then
        local line = lines[issue.line]
        -- Replace the variable only if it's not already prefixed with underscore
        if not line:match("_" .. var_name) then
          lines[issue.line] = line:gsub("([%s,%(])(" .. var_name .. ")([%s,%)%.])", "%1_%2%3")
          fixed = true
        end
      end
    end
  end

  -- Only save if fixes were made
  if fixed then
    -- Reconstruct content
    local fixed_content = table.concat(lines, "\n")
    if fixed_content:sub(-1) ~= "\n" and content:sub(-1) == "\n" then
      fixed_content = fixed_content .. "\n"
    end

    local success, err = write_file(file_path, fixed_content)
    if not success then
      log_error("Failed to write fixed unused variables: " .. (err or "unknown error"))
      return false
    end

    log_success("Fixed unused variables in " .. file_path)
    return true
  end

  return false
end

--- Performs basic optimizations on string concatenations (`..`).
--- Merges consecutive string literals being concatenated.
---@param content string The source code content to fix.
---@return string fixed_content The content with potential concatenation optimizations applied.
function M.fix_string_concat(content)
  if not M.config.custom_fixers.string_concat then
    return content
  end

  log_debug("Optimizing string concatenation")

  -- Replace multiple consecutive string concatenations with a single one
  local fixed_content = content:gsub("(['\"])%s*%.%.%s*(['\"])", "%1%2")

  -- Replace concatenations of string literals with a single string
  fixed_content = fixed_content:gsub("(['\"])([^'\"]+)%1%s*%.%.%s*(['\"])([^'\"]+)%3", "%1%2%4%3")

  return fixed_content
end

--- **Experimental:** Attempts to add basic JSDoc type annotations (`---@param name any`, `---@return any`) to function definitions that lack them.
--- May produce incorrect or incomplete annotations. Disabled by default.
---@param content string The source code content to modify.
---@return string fixed_content The content with potential annotations added.
function M.fix_type_annotations(content)
  if not M.config.custom_fixers.type_annotations then
    return content
  end

  log_debug("Adding type annotations to function documentation")

  -- This is a complex task that requires parsing function signatures and existing comments
  -- For now, we'll implement a basic version that adds annotations to functions without them

  -- Find function definitions without type annotations in comments
  local fixed_content = content:gsub("([^\n]-function%s+[%w_:%.]+%s*%(([^%)]+)%)[^\n]-\n)", function(func_def, params)
    -- Skip if there's already a type annotation comment
    if func_def:match("%-%-%-.*@param") or func_def:match("%-%-.*@param") then
      return func_def
    end

    -- Parse parameters
    local param_list = {}
    for param in params:gmatch("([%w_]+)[%s,]*") do
      if param ~= "" then
        table.insert(param_list, param)
      end
    end

    -- Skip if no parameters
    if #param_list == 0 then
      return func_def
    end

    -- Generate annotation comment
    local annotation = "--- Function documentation\n"
    for _, param in ipairs(param_list) do
      annotation = annotation .. "-- @param " .. param .. " any\n"
    end
    annotation = annotation .. "-- @return any\n"

    -- Add annotation before function
    return annotation .. func_def
  end)

  return fixed_content
end

--- Applies basic transformations to Lua code to improve compatibility with older versions (currently targets Lua 5.1).
--- Comments out `goto` and labels, replaces `table.pack`, replaces `bit32` calls with `bit` calls. Disabled by default.
---@param content string The source code content to fix.
---@param target_version? string Target Lua version string (default: "5.1"). Only "5.1" is currently supported.
---@return string fixed_content The content with potential compatibility fixes applied.
function M.fix_lua_version_compat(content, target_version)
  if not M.config.custom_fixers.lua_version_compat then
    return content
  end

  target_version = target_version or "5.1" -- Default to Lua 5.1 compatibility

  log_debug("Fixing Lua version compatibility issues for Lua " .. target_version)

  local fixed_content = content

  if target_version == "5.1" then
    -- Replace 5.2+ features with 5.1 compatible versions

    -- Replace goto statements with alternative logic (simple cases only)
    fixed_content = fixed_content:gsub("goto%s+([%w_]+)", "-- goto %1 (replaced for Lua 5.1 compatibility)")
    fixed_content = fixed_content:gsub("::([%w_]+)::", "-- ::%1:: (removed for Lua 5.1 compatibility)")

    -- Replace table.pack with a compatible implementation
    fixed_content =
      fixed_content:gsub("table%.pack%s*(%b())", "({...}) -- table.pack replaced for Lua 5.1 compatibility")

    -- Replace bit32 library with bit if available
    fixed_content =
      fixed_content:gsub("bit32%.([%w_]+)%s*(%b())", "bit.%1%2 -- bit32 replaced with bit for Lua 5.1 compatibility")
  end

  return fixed_content
end

--- Runs all enabled custom fixers (`fix_trailing_whitespace`, `fix_string_concat`, `fix_type_annotations`, `fix_lua_version_compat`, `fix_unused_variables`) on a file's content.
--- Reads the file, applies fixes sequentially, and writes back if modified.
---@param file_path string Path to the file to fix.
---@param issues? table[] Optional array of issues from Luacheck (used by `fix_unused_variables`).
---@return boolean modified `true` if any fixer modified the content and the file was saved, `false` otherwise.
---@throws table If `file_path` validation or critical file I/O fails.
function M.run_custom_fixers(file_path, issues)
  log_info("Running custom fixers on " .. file_path)

  local content, err = read_file(file_path)
  if not content then
    log_error("Failed to read file for custom fixing: " .. (err or "unknown error"))
    return false
  end

  -- Make backup before modifying
  if M.config.backup then
    local success, err = backup_file(file_path)
    if not success then
      log_warning("Failed to create backup for " .. file_path .. ": " .. (err or "unknown error"))
    end
  end

  -- Apply fixers in sequence
  local modified = false

  -- Fix trailing whitespace in multiline strings
  local fixed_content = M.fix_trailing_whitespace(content)
  if fixed_content ~= content then
    modified = true
    content = fixed_content
  end

  -- Fix string concatenation
  fixed_content = M.fix_string_concat(content)
  if fixed_content ~= content then
    modified = true
    content = fixed_content
  end

  -- Fix type annotations
  fixed_content = M.fix_type_annotations(content)
  if fixed_content ~= content then
    modified = true
    content = fixed_content
  end

  -- Fix Lua version compatibility issues
  fixed_content = M.fix_lua_version_compat(content)
  if fixed_content ~= content then
    modified = true
    content = fixed_content
  end

  -- Only save the file if changes were made
  if modified then
    local success, err = write_file(file_path, content)
    if not success then
      log_error("Failed to write fixed content: " .. (err or "unknown error"))
      return false
    end

    log_success("Applied custom fixes to " .. file_path)
  else
    log_info("No custom fixes needed for " .. file_path)
  end

  -- Fix unused variables (uses issues from Luacheck)
  local unused_fixed = M.fix_unused_variables(file_path, issues)
  if unused_fixed then
    modified = true
  end

  return modified
end

--- Applies the full code fixing process to a single file: Luacheck (optional) -> Custom Fixers -> StyLua (optional) -> Luacheck verification (optional).
--- Creates backups if enabled. Logs progress and results.
---@param file_path string Path to the file to fix.
---@return boolean success `true` if all enabled steps completed successfully (Luacheck may have warnings but not errors), `false` otherwise.
---@throws table If validation, file I/O, or external tool execution fails critically.
function M.fix_file(file_path)
  if not M.config.enabled then
    log_debug("Codefix is disabled, skipping")
    return true
  end

  if not file_exists(file_path) then
    log_error("File does not exist: " .. file_path)
    return false
  end

  log_info("Fixing " .. file_path)

  -- Make backup before any modifications
  if M.config.backup then
    local success, err = backup_file(file_path)
    if not success then
      log_warning("Failed to create backup for " .. file_path .. ": " .. (err or "unknown error"))
    end
  end

  -- Run Luacheck first to get issues
  local luacheck_success, issues = M.run_luacheck(file_path)

  -- Run custom fixers
  local fixers_modified = M.run_custom_fixers(file_path, issues)

  -- Run StyLua after custom fixers
  local stylua_success = M.run_stylua(file_path)

  -- Run Luacheck again to verify fixes
  if fixers_modified or not stylua_success then
    log_info("Verifying fixes with Luacheck")
    luacheck_success, issues = M.run_luacheck(file_path)
  end

  return stylua_success and luacheck_success
end

--- Fixes multiple files by calling `M.fix_file` for each path in the input array.
--- Logs overall progress and summary statistics.
---@param file_paths string[] Array of file paths to fix.
---@return boolean success `true` if *all* files were fixed successfully, `false` otherwise.
---@return table results An array of result tables, one for each file: `{ file: string, success: boolean, error?: string }`.
---@throws table If `file_paths` validation fails.
function M.fix_files(file_paths)
  if not M.config.enabled then
    log_debug("Codefix is disabled, skipping")
    return true
  end

  if type(file_paths) ~= "table" or #file_paths == 0 then
    log_warning("No files provided to fix")
    return false
  end

  log_info(string.format("Fixing %d files", #file_paths))

  local success_count = 0
  local failure_count = 0
  local results = {}

  for i, file_path in ipairs(file_paths) do
    log_info(string.format("Processing file %d/%d: %s", i, #file_paths, file_path))

    -- Check if file exists before attempting to fix
    if not file_exists(file_path) then
      log_error(string.format("File does not exist: %s", file_path))
      failure_count = failure_count + 1
      table.insert(results, {
        file = file_path,
        success = false,
        error = "File not found",
      })
    else
      local success = M.fix_file(file_path)

      if success then
        success_count = success_count + 1
        table.insert(results, {
          file = file_path,
          success = true,
        })
      else
        failure_count = failure_count + 1
        table.insert(results, {
          file = file_path,
          success = false,
          error = "Failed to fix file",
        })
      end
    end

    -- Provide progress update for large batches
    if #file_paths > 10 and (i % 10 == 0 or i == #file_paths) then
      log_info(string.format("Progress: %d/%d files processed (%.1f%%)", i, #file_paths, (i / #file_paths) * 100))
    end
  end

  -- Generate summary
  log_info(string.rep("-", 40))
  log_info(string.format("Fix summary: %d successful, %d failed, %d total", success_count, failure_count, #file_paths))

  if success_count > 0 then
    log_success(string.format("Successfully fixed %d files", success_count))
  end

  if failure_count > 0 then
    log_warning(string.format("Failed to fix %d files", failure_count))
  end

  return failure_count == 0, results
end

--- Finds Lua files in a directory (using include/exclude patterns) and fixes them using `M.fix_files`.
--- Optionally generates a JSON report of the results.
---@param directory? string Directory to search for Lua files (default: current directory ".").
---@param options? { include?: string[], exclude?: string[], limit?: number, sort_by_mtime?: boolean, generate_report?: boolean, report_file?: string } Options for filtering and fixing:
---  - `include`: Array of include patterns (defaults to `M.config.include`).
---  - `exclude`: Array of exclude patterns (defaults to `M.config.exclude`).
---  - `limit`: Maximum number of files to process.
---  - `sort_by_mtime`: Sort files by modification time (newest first) before processing.
---  - `generate_report`: Generate a JSON report file.
---  - `report_file`: Path for the JSON report file (default "codefix_report.json").
---@return boolean success `true` if file discovery and fixing of all found files succeeded, `false` otherwise.
---@return table results The results table returned by `M.fix_files`.
---@throws table If validation or file discovery/fixing fails critically.
function M.fix_lua_files(directory, options)
  directory = directory or "."
  options = options or {}

  if not M.config.enabled then
    log_debug("Codefix is disabled, skipping")
    return true
  end

  -- Allow for custom include/exclude patterns
  local include_patterns = options.include or M.config.include
  local exclude_patterns = options.exclude or M.config.exclude

  log_info("Finding Lua files in " .. directory)

  local files = find_files(include_patterns, exclude_patterns, directory)

  log_info(string.format("Found %d Lua files to fix", #files))

  if #files == 0 then
    log_warning("No matching files found in " .. directory)
    return true
  end

  -- Allow for limiting the number of files processed
  if options.limit and options.limit > 0 and options.limit < #files then
    log_info(string.format("Limiting to %d files (out of %d found)", options.limit, #files))
    local limited_files = {}
    for i = 1, options.limit do
      table.insert(limited_files, files[i])
    end
    files = limited_files
  end

  -- Sort files by modification time if requested
  if options.sort_by_mtime then
    log_info("Sorting files by modification time")
    local file_times = {}

    for _, file in ipairs(files) do
      local mtime
      local os_name = get_os()

      if os_name == "windows" then
        local result = execute_command(string.format('dir "%s" /TC /B', file))
        if result then
          mtime = result:match("(%d+/%d+/%d+%s+%d+:%d+%s+%a+)")
        end
      else
        local result = execute_command(string.format('stat -c "%%Y" "%s"', file))
        if result then
          mtime = tonumber(result:match("%d+"))
        end
      end

      mtime = mtime or 0
      table.insert(file_times, { file = file, mtime = mtime })
    end

    table.sort(file_times, function(a, b)
      return a.mtime > b.mtime
    end)

    files = {}
    for _, entry in ipairs(file_times) do
      table.insert(files, entry.file)
    end
  end

  -- Run the file fixing
  local success, results = M.fix_files(files)

  -- Generate a detailed report if requested
  if options.generate_report and json then
    local report = {
      timestamp = os.time(),
      directory = directory,
      total_files = #files,
      successful = 0,
      failed = 0,
      results = results,
    }

    for _, result in ipairs(results) do
      if result.success then
        report.successful = report.successful + 1
      else
        report.failed = report.failed + 1
      end
    end

    local report_file = options.report_file or "codefix_report.json"
    local json_content = json.encode(report)

    get_logger().debug("Generating report file", {
      report_file = report_file,
      report_size = #json_content,
      successful_files = report.successful,
      failed_files = report.failed,
    })

    local success, err = get_fs().write_file(report_file, json_content)
    if success then
      log_info("Wrote detailed report to " .. report_file)
    else
      log_error("Failed to write report to " .. report_file .. ": " .. (err or "unknown error"))
    end
  end

  return success, results
end

--- Command line interface entry point for the codefix tool.
--- Parses arguments for `fix`, `check`, `find`, and `help` commands and executes the corresponding action.
---@param args? table Optional array of arguments (defaults to global `arg`). Args should typically start with the command name (e.g., `{ "fix", "src/" }`).
---@return boolean success Whether the CLI command executed successfully.
function M.run_cli(args)
  args = args or {}

  -- Enable module
  M.config.enabled = true

  -- Parse arguments
  local command = args[1] or "fix"
  local target = nil
  local options = {
    include = M.config.include,
    exclude = M.config.exclude,
    limit = 0,
    sort_by_mtime = false,
    generate_report = false,
    report_file = "codefix_report.json",
    include_patterns = {},
    exclude_patterns = {},
  }

  -- Extract target and options from args
  for i = 2, #args do
    local arg = args[i]

    -- Skip flags when looking for target
    if not arg:match("^%-") and not target then
      target = arg
    end

    -- Handle flags
    if arg == "--verbose" or arg == "-v" then
      M.config.verbose = true
    elseif arg == "--debug" or arg == "-d" then
      M.config.debug = true
      M.config.verbose = true
    elseif arg == "--no-backup" or arg == "-nb" then
      M.config.backup = false
    elseif arg == "--no-stylua" or arg == "-ns" then
      M.config.use_stylua = false
    elseif arg == "--no-luacheck" or arg == "-nl" then
      M.config.use_luacheck = false
    elseif arg == "--sort-by-mtime" or arg == "-s" then
      options.sort_by_mtime = true
    elseif arg == "--generate-report" or arg == "-r" then
      options.generate_report = true
    elseif arg == "--limit" or arg == "-l" then
      if args[i + 1] and tonumber(args[i + 1]) then
        options.limit = tonumber(args[i + 1])
      end
    elseif arg == "--report-file" then
      if args[i + 1] then
        options.report_file = args[i + 1]
      end
    elseif arg == "--include" or arg == "-i" then
      if args[i + 1] and not args[i + 1]:match("^%-") then
        table.insert(options.include_patterns, args[i + 1])
      end
    elseif arg == "--exclude" or arg == "-e" then
      if args[i + 1] and not args[i + 1]:match("^%-") then
        table.insert(options.exclude_patterns, args[i + 1])
      end
    end
  end

  -- Set default target if not specified
  target = target or "."

  -- Apply custom include/exclude patterns if specified
  if #options.include_patterns > 0 then
    options.include = options.include_patterns
  end

  if #options.exclude_patterns > 0 then
    options.exclude = options.exclude_patterns
  end

  -- Run the appropriate command
  if command == "fix" then
    -- Check if target is a directory or file
    if target:match("%.lua$") and file_exists(target) then
      return M.fix_file(target)
    else
      return M.fix_lua_files(target, options)
    end
  elseif command == "check" then
    -- Only run checks, don't fix
    M.config.use_stylua = false

    if target:match("%.lua$") and file_exists(target) then
      return M.run_luacheck(target)
    else
      -- Allow checking multiple files without fixing
      options.check_only = true
      local files = find_files(options.include, options.exclude, target)

      if #files == 0 then
        log_warning("No matching files found")
        return true
      end

      log_info(string.format("Checking %d files...", #files))

      local issues_count = 0
      for _, file in ipairs(files) do
        local _, issues = M.run_luacheck(file)
        if issues and #issues > 0 then
          issues_count = issues_count + #issues
        end
      end

      log_info(string.format("Found %d issues in %d files", issues_count, #files))
      return issues_count == 0
    end
  elseif command == "find" then
    -- Just find and list matching files
    local files = find_files(options.include, options.exclude, target)

    if #files == 0 then
      log_warning("No matching files found")
    else
      log_info(string.format("Found %d matching files:", #files))
      for _, file in ipairs(files) do
        -- Log at debug level, but use direct io.write for console output
        get_logger().debug("Found matching file", { path = file })
        io.write(file .. "\n")
      end
    end

    return true
  elseif command == "help" then
    get_logger().debug("Displaying codefix help text")

    -- Use the logging module's info function for consistent help text display
    logging.info("firmo codefix usage:")
    logging.info("  fix [directory or file] - Fix Lua files")
    logging.info("  check [directory or file] - Check Lua files without fixing")
    logging.info("  find [directory] - Find Lua files matching patterns")
    logging.info("  help - Show this help message")
    logging.info("")
    logging.info("Options:")
    logging.info("  --verbose, -v       - Enable verbose output")
    logging.info("  --debug, -d         - Enable debug output")
    logging.info("  --no-backup, -nb    - Disable backup files")
    logging.info("  --no-stylua, -ns    - Disable StyLua formatting")
    logging.info("  --no-luacheck, -nl  - Disable Luacheck verification")
    logging.info("  --sort-by-mtime, -s - Sort files by modification time (newest first)")
    logging.info("  --generate-report, -r - Generate a JSON report file")
    logging.info("  --report-file FILE  - Specify report file name (default: codefix_report.json)")
    logging.info("  --limit N, -l N     - Limit processing to N files")
    logging.info("  --include PATTERN, -i PATTERN - Add file pattern to include (can be used multiple times)")
    logging.info("  --exclude PATTERN, -e PATTERN - Add file pattern to exclude (can be used multiple times)")
    logging.info("")
    logging.info("Examples:")
    logging.info("  fix src/ --no-stylua")
    logging.info('  check src/ --include "%.lua$" --exclude "_spec%.lua$"')
    logging.info("  fix . --sort-by-mtime --limit 10")
    logging.info("  fix . --generate-report --report-file codefix_results.json")
    return true
  else
    log_error("Unknown command: " .. command)
    return false
  end
end

--- Registers the codefix module and its commands with a Firmo framework instance.
--- Adds `firmo.codefix_options`, `firmo.fix_file`, `firmo.fix_files`, `firmo.fix_lua_files`,
--- `firmo.codefix` namespace, and CLI commands (`fix`, `check`, `find`).
--- Also registers a custom reporter to potentially run codefix after tests.
---@param firmo table The Firmo instance to register with.
---@return codefix_module self The codefix module instance (`M`).
---@throws table If `firmo` validation fails critically (via `error_handler.assert`).
function M.register_with_firmo(firmo)
  if not firmo then
    return
  end

  -- Add codefix configuration to firmo
  firmo.codefix_options = M.config

  -- Add codefix functions to firmo
  firmo.fix_file = M.fix_file
  firmo.fix_files = M.fix_files
  firmo.fix_lua_files = M.fix_lua_files

  -- Add the full codefix module as a namespace for advanced usage
  firmo.codefix = M

  -- Add CLI commands
  firmo.commands = firmo.commands or {}
  firmo.commands.fix = function(args)
    return M.run_cli(args)
  end

  firmo.commands.check = function(args)
    table.insert(args, 1, "check")
    return M.run_cli(args)
  end

  firmo.commands.find = function(args)
    table.insert(args, 1, "find")
    return M.run_cli(args)
  end

  -- Register a custom reporter for code quality
  if firmo.register_reporter then
    firmo.register_reporter("codefix", function(results, options)
      options = options or {}

      -- Check if codefix should be run
      if not options.codefix then
        return
      end

      get_logger().debug("Codefix reporter initialized", {
        test_count = #results.tests,
        options = options,
      })

      -- Find all source files in the test files
      local test_files = {}
      for _, test in ipairs(results.tests) do
        if test.source_file and not test_files[test.source_file] then
          test_files[test.source_file] = true
          get_logger().debug("Found source file in test results", {
            source_file = test.source_file,
          })
        end
      end

      -- Convert to array
      local files_to_fix = {}
      for file in pairs(test_files) do
        table.insert(files_to_fix, file)
      end

      -- Run codefix on all test files
      if #files_to_fix > 0 then
        io.write(string.format("\nRunning codefix on %d source files...\n", #files_to_fix))
        M.config.enabled = true
        M.config.verbose = options.verbose or false

        get_logger().info("Running codefix on test source files", {
          file_count = #files_to_fix,
          verbose = M.config.verbose,
        })

        local success, fix_results = M.fix_files(files_to_fix)

        if success then
          get_logger().info("All files fixed successfully", {
            file_count = #files_to_fix,
          })
          io.write("✅ All files fixed successfully\n")
        else
          -- Count successful and failed files
          local successful = 0
          local failed = 0

          for _, result in ipairs(fix_results or {}) do
            if result.success then
              successful = successful + 1
            else
              failed = failed + 1
            end
          end

          get_logger().warn("Some files could not be fixed", {
            total_files = #files_to_fix,
            successful_files = successful,
            failed_files = failed,
          })
          io.write("⚠️ Some files could not be fixed\n")
        end
      end
    end)
  end

  --- Registers a custom fixer function or object.
  --- The fixer function receives `(content, file_path, issues?)` and should return the modified content string.
  ---@param name string A unique name for the custom fixer.
  ---@param options {name: string, fix: function, description?: string} A table containing the fixer's name, the fixer function (`fix`), and an optional description.
  ---@return boolean success `true` if registration was successful.
  ---@throws table If validation fails (e.g., missing `name` or `fix` function).
  function M.register_custom_fixer(name, options)
    if not options or not options.fix or not options.name then
      log_error("Custom fixer requires a name and fix function")
      return false
    end

    -- Add to custom fixers table
    if type(options.fix) == "function" then
      -- Register as a named function
      M.config.custom_fixers[name] = options.fix
    else
      -- Register as an object with metadata
      M.config.custom_fixers[name] = options
    end

    log_info("Registered custom fixer: " .. options.name)
    return true
  end

  local markdown = try_require("lib.tools.markdown")
  markdown.register_with_codefix(M)
  if M.config.verbose then
    get_logger().info("Registered markdown fixing capabilities")
  end

  return M
end

-- Return the module
return M
