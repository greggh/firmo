-- firmo codefix module
-- Implementation of code quality checking and fixing capabilities
-- Provides tools for linting, formatting, and automatically fixing common issues

---@class codefix_module
---@field _VERSION string Module version
---@field config {stylua_enabled: boolean, luacheck_enabled: boolean, fix_trailing_whitespace: boolean, fix_unused_variables: boolean, fix_string_concat: boolean, fix_type_annotations: boolean, fix_lua_version_compat: boolean, lua_version_target: string, custom_fixers_enabled: boolean, verbose_output: boolean, auto_backup: boolean, include_patterns: string[], exclude_patterns: string[]} Configuration options for the codefix module
---@field init fun(options?: table): codefix_module Initialize module with configuration
---@field check_stylua fun(): boolean Check if StyLua is available
---@field find_stylua_config fun(dir?: string): string|nil Find StyLua configuration file
---@field run_stylua fun(file_path: string, config_file?: string): boolean, string? Run StyLua on a file
---@field check_luacheck fun(): boolean Check if Luacheck is available
---@field find_luacheck_config fun(dir?: string): string|nil Find Luacheck configuration file
---@field parse_luacheck_output fun(output: string): {issues: table[], summary: {files: number, warnings: number, errors: number}} Parse Luacheck output
---@field run_luacheck fun(file_path: string, config_file?: string): boolean, table Run Luacheck on a file
---@field fix_trailing_whitespace fun(content: string): string Fix trailing whitespace in multiline strings
---@field fix_unused_variables fun(file_path: string, issues?: table): boolean Fix unused variables by prefixing with underscore
---@field fix_string_concat fun(content: string): string Fix string concatenation (optimize .. operator usage)
---@field fix_type_annotations fun(content: string): string Add type annotations in function documentation
---@field fix_lua_version_compat fun(content: string, target_version?: string): string Fix code for Lua version compatibility issues
---@field run_custom_fixers fun(file_path: string, issues?: table): boolean Run all custom fixers on a file
---@field fix_file fun(file_path: string): boolean, table? Main function to fix a file
---@field fix_directory fun(dir_path: string, recursive?: boolean): {fixed: number, total: number, errors: number} Fix all Lua files in a directory
---@field register_custom_fixer fun(name: string, fixer_fn: fun(content: string, file_path: string, issues?: table): string): boolean Register a custom code fixer
---@field unregister_custom_fixer fun(name: string): boolean Remove a custom code fixer
---@field backup_file fun(file_path: string): string|nil, string? Create a backup of a file before modifying
---@field restore_backup fun(backup_path: string): boolean, string? Restore a file from backup
---@field get_custom_fixers fun(): table<string, function> Get all registered custom fixers
---@field validate_lua_syntax fun(content: string): boolean, string? Check if Lua code has valid syntax
---@field format_issues fun(issues: table): string Format Luacheck issues as readable text
---@field fix_files fun(file_paths: string[]): boolean, table Fix multiple files
---@field fix_lua_files fun(directory?: string, options?: table): boolean, table Find and fix Lua files
---@field run_cli fun(args?: table): boolean Command line interface
---@field register_with_firmo fun(firmo: table): codefix_module Module interface with firmo
---@field register_custom_fixer fun(name: string, options: table): boolean Register a custom fixer with codefix

local M = {}
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")

-- Initialize module logger
local logger = logging.get_logger("codefix")
logging.configure_from_config("codefix")

-- Try to load JSON module with proper error handling
local json
local function load_json_module()
  return error_handler.try(function()
    -- Try loading JSON module from firmo first
    local loaded_json = require("lib.reporting.json")
    logger.debug("Loaded JSON module from firmo", {
      module_path = "lib.reporting.json",
    })
    return loaded_json
  end)
end

local success, loaded_json_or_error = load_json_module()
if success then
  json = loaded_json_or_error
else
  logger.debug("Failed to load JSON module from firmo", {
    error = error_handler.format_error(loaded_json_or_error),
  })

  -- Try loading from system libraries
  success, loaded_json_or_error = error_handler.try(function()
    local system_json = require("json")
    logger.debug("Loaded JSON module from system libraries", {
      module_type = type(system_json),
    })
    return system_json
  end)

  if success then
    json = loaded_json_or_error
  else
    logger.warn("Failed to load any JSON module, JSON-related features will be unavailable", {
      error = error_handler.format_error(loaded_json_or_error),
    })
  end
end

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

---@private
---@param command string The shell command to execute
---@return string|nil output Command output or nil on error
---@return boolean success Whether the command succeeded
---@return number exit_code Exit code from the command
---@return string|nil error_message Error message if the command failed
-- Helper function to execute shell commands with robust error handling
local function execute_command(command)
  -- Validate required parameters
  error_handler.assert(
    command ~= nil and type(command) == "string",
    "Command must be a string",
    error_handler.CATEGORY.VALIDATION,
    { command_type = type(command) }
  )

  error_handler.assert(
    command:len() > 0,
    "Command cannot be empty",
    error_handler.CATEGORY.VALIDATION,
    { command_length = command:len() }
  )

  logger.debug("Executing command", {
    command = command,
    debug_mode = M.config.debug,
  })

  -- Execute command with proper error handling
  local handle_success, handle, handle_err = error_handler.safe_io_operation(function()
    return io.popen(command .. " 2>&1", "r")
  end, "command", { operation = "popen", command = command })

  if not handle_success or not handle then
    local err_obj = error_handler.io_error("Failed to execute command", error_handler.SEVERITY.ERROR, {
      command = command,
      error = handle_err or "I/O operation failed",
    })

    logger.error("Failed to execute command", {
      command = command,
      error = error_handler.format_error(err_obj),
    })

    return nil, false, -1, err_obj
  end

  -- Read output with error handling
  local read_success, result, read_err = error_handler.safe_io_operation(function()
    return handle:read("*a")
  end, "command_output", { operation = "read", command = command })

  if not read_success then
    local err_obj = error_handler.io_error("Failed to read command output", error_handler.SEVERITY.ERROR, {
      command = command,
      error = read_err or "Read operation failed",
    })

    logger.error("Failed to read command output", {
      command = command,
      error = error_handler.format_error(err_obj),
    })

    -- Try to close handle to avoid resource leaks
    error_handler.try(function()
      handle:close()
    end)

    return nil, false, -1, err_obj
  end

  -- Close handle with error handling
  local close_success, close_result, close_err = error_handler.safe_io_operation(function()
    return handle:close()
  end, "command_close", { operation = "close", command = command })

  local success, reason, code

  if close_success then
    success, reason, code = table.unpack(close_result)
  else
    success = false
    reason = close_err or "Close operation failed"
    code = -1

    logger.warn("Failed to close command handle properly", {
      command = command,
      error = reason,
    })
  end

  code = code or 0

  logger.debug("Command execution completed", {
    command = command,
    exit_code = code,
    output_length = result and #result or 0,
    success = success,
  })

  return result, success, code, reason
end

---@private
---@return string os_name The detected operating system name (windows, macos, linux, bsd, or unix)
-- Get the operating system name with error handling
local function get_os()
  -- Use path separator to detect OS type (cross-platform approach)
  local success, os_info = error_handler.try(function()
    local is_windows = package.config:sub(1, 1) == "\\"

    if is_windows then
      return { name = "windows", source = "path_separator" }
    end

    -- For Unix-like systems, we can differentiate further if needed
    -- Try to use filesystem module for platform detection first
    if fs and fs._PLATFORM then
      local platform = fs._PLATFORM:lower()

      if platform:match("darwin") then
        return { name = "macos", source = "filesystem_module" }
      elseif platform:match("linux") then
        return { name = "linux", source = "filesystem_module" }
      elseif platform:match("bsd") then
        return { name = "bsd", source = "filesystem_module" }
      end
    end

    -- Fall back to uname command for Unix-like systems
    local uname_success, result = error_handler.safe_io_operation(function()
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
    logger.warn("Failed to detect operating system", {
      error = error_handler.format_error(os_info),
      fallback = "unix",
    })
    return "unix"
  end

  logger.debug("Detected operating system", {
    os = os_info.name,
    detection_source = os_info.source,
  })

  return os_info.name
end

-- Logger functions - redirected to central logging system with structured logging
local function log_info(message, context)
  if M.config.verbose or M.config.debug then
    if type(context) == "table" then
      logger.info(message, context)
    else
      logger.info(message, { raw_message = message })
    end
  end
end

local function log_debug(message, context)
  if M.config.debug then
    if type(context) == "table" then
      logger.debug(message, context)
    else
      logger.debug(message, { raw_message = message })
    end
  end
end

local function log_warning(message, context)
  if type(context) == "table" then
    logger.warn(message, context)
  else
    logger.warn(message, { raw_message = message })
  end
end

local function log_error(message, context)
  if type(context) == "table" then
    logger.error(message, context)
  else
    logger.error(message, { raw_message = message })
  end
end

local function log_success(message, context)
  -- Log at info level with structured data
  if type(context) == "table" then
    logger.info(message, context)
  else
    logger.info(message, { raw_message = message, success = true })
  end

  -- Also print to console for user feedback with [SUCCESS] prefix using safe I/O
  error_handler.safe_io_operation(function()
    io.write("[SUCCESS] " .. message .. "\n")
  end, "console", { operation = "write_success", message = message })
end

-- Filesystem module was already loaded at the top of the file
logger.debug("Filesystem module configuration", {
  version = fs._VERSION,
  platform = fs._PLATFORM,
  module_path = package.searchpath("lib.tools.filesystem", package.path),
})

-- Check if a file exists with error handling
local function file_exists(path)
  -- Validate required parameters
  error_handler.assert(
    path ~= nil and type(path) == "string",
    "Path must be a string",
    error_handler.CATEGORY.VALIDATION,
    { path_type = type(path) }
  )

  error_handler.assert(
    path:len() > 0,
    "Path cannot be empty",
    error_handler.CATEGORY.VALIDATION,
    { path_length = path:len() }
  )

  local success, result, err = error_handler.safe_io_operation(function()
    return fs.file_exists(path)
  end, path, { operation = "file_exists" })

  if not success then
    log_warning("Failed to check if file exists", {
      path = path,
      error = error_handler.format_error(result),
    })
    return false
  end

  return result
end

-- Read a file into a string with error handling
local function read_file(path)
  -- Validate required parameters
  error_handler.assert(
    path ~= nil and type(path) == "string",
    "Path must be a string",
    error_handler.CATEGORY.VALIDATION,
    { path_type = type(path) }
  )

  error_handler.assert(
    path:len() > 0,
    "Path cannot be empty",
    error_handler.CATEGORY.VALIDATION,
    { path_length = path:len() }
  )

  local success, content, err = error_handler.safe_io_operation(function()
    return fs.read_file(path)
  end, path, { operation = "read_file" })

  if not success then
    local error_obj = error_handler.io_error("Failed to read file", error_handler.SEVERITY.ERROR, {
      path = path,
      operation = "read_file",
      error = err,
    })

    log_error("Failed to read file", {
      path = path,
      error = error_handler.format_error(error_obj),
    })

    return nil, error_obj
  end

  log_debug("Successfully read file", {
    path = path,
    content_size = content and #content or 0,
  })

  return content
end

-- Write a string to a file with error handling
local function write_file(path, content)
  -- Validate required parameters
  error_handler.assert(
    path ~= nil and type(path) == "string",
    "Path must be a string",
    error_handler.CATEGORY.VALIDATION,
    { path_type = type(path) }
  )

  error_handler.assert(
    path:len() > 0,
    "Path cannot be empty",
    error_handler.CATEGORY.VALIDATION,
    { path_length = path:len() }
  )

  error_handler.assert(
    content ~= nil,
    "Content cannot be nil",
    error_handler.CATEGORY.VALIDATION,
    { content_type = type(content) }
  )

  local success, result, err = error_handler.safe_io_operation(function()
    return fs.write_file(path, content)
  end, path, { operation = "write_file", content_size = type(content) == "string" and #content or 0 })

  if not success then
    local error_obj = error_handler.io_error("Failed to write file", error_handler.SEVERITY.ERROR, {
      path = path,
      operation = "write_file",
      error = err,
    })

    log_error("Failed to write file", {
      path = path,
      error = error_handler.format_error(error_obj),
    })

    return false, error_obj
  end

  log_debug("Successfully wrote file", {
    path = path,
    content_size = type(content) == "string" and #content or 0,
  })

  return true
end

-- Create a backup of a file with error handling
local function backup_file(path)
  -- Skip if backups are disabled
  if not M.config.backup then
    log_debug("Backup is disabled, skipping", {
      path = path,
    })
    return true
  end

  -- Validate required parameters
  error_handler.assert(
    path ~= nil and type(path) == "string",
    "Path must be a string",
    error_handler.CATEGORY.VALIDATION,
    { path_type = type(path) }
  )

  error_handler.assert(
    path:len() > 0,
    "Path cannot be empty",
    error_handler.CATEGORY.VALIDATION,
    { path_length = path:len() }
  )

  error_handler.assert(
    M.config.backup_ext ~= nil and type(M.config.backup_ext) == "string",
    "Backup extension must be a string",
    error_handler.CATEGORY.VALIDATION,
    { backup_ext_type = type(M.config.backup_ext) }
  )

  log_debug("Creating backup of file", {
    path = path,
    backup_ext = M.config.backup_ext,
  })

  -- Check if file exists before backing up
  local file_check_success, file_exists_result = error_handler.try(function()
    return fs.file_exists(path)
  end)

  if not file_check_success or not file_exists_result then
    local error_obj =
      error_handler.io_error("Source file does not exist or cannot be accessed", error_handler.SEVERITY.ERROR, {
        path = path,
        operation = "backup_file",
      })

    log_error("Failed to backup file", {
      path = path,
      reason = "source file does not exist or cannot be accessed",
      error = error_handler.format_error(error_obj),
    })

    return false, error_obj
  end

  -- Create backup with error handling
  local backup_path = path .. M.config.backup_ext

  local success, result, err = error_handler.safe_io_operation(function()
    return fs.copy_file(path, backup_path)
  end, path, { operation = "copy_file", backup_path = backup_path })

  if not success then
    local error_obj = error_handler.io_error("Failed to create backup file", error_handler.SEVERITY.ERROR, {
      path = path,
      backup_path = backup_path,
      operation = "backup_file",
      error = err,
    })

    log_error("Failed to create backup file", {
      path = path,
      backup_path = backup_path,
      error = error_handler.format_error(error_obj),
    })

    return false, error_obj
  end

  log_debug("Backup file created successfully", {
    path = backup_path,
  })

  return true
end

-- Check if a command is available with error handling
local function command_exists(cmd)
  -- Validate required parameters
  error_handler.assert(
    cmd ~= nil and type(cmd) == "string",
    "Command must be a string",
    error_handler.CATEGORY.VALIDATION,
    { cmd_type = type(cmd) }
  )

  error_handler.assert(
    cmd:len() > 0,
    "Command cannot be empty",
    error_handler.CATEGORY.VALIDATION,
    { cmd_length = cmd:len() }
  )

  local command_check_success, os_name_or_err = error_handler.try(function()
    return get_os()
  end)

  if not command_check_success then
    log_warning("Failed to get OS type for command check", {
      error = error_handler.format_error(os_name_or_err),
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

-- Find a configuration file by searching up the directory tree with error handling
local function find_config_file(filename, start_dir)
  -- Validate required parameters
  error_handler.assert(
    filename ~= nil and type(filename) == "string",
    "Filename must be a string",
    error_handler.CATEGORY.VALIDATION,
    { filename_type = type(filename) }
  )

  error_handler.assert(
    filename:len() > 0,
    "Filename cannot be empty",
    error_handler.CATEGORY.VALIDATION,
    { filename_length = filename:len() }
  )

  -- Process optional parameters with defaults
  start_dir = start_dir or "."

  error_handler.assert(
    type(start_dir) == "string",
    "Start directory must be a string",
    error_handler.CATEGORY.VALIDATION,
    { start_dir_type = type(start_dir) }
  )

  log_debug("Searching for config file", {
    filename = filename,
    start_dir = start_dir,
  })

  -- Use try/catch pattern for the entire search process
  local search_success, search_result = error_handler.try(function()
    local current_dir = start_dir

    -- Get absolute path with error handling
    local abs_success, abs_path = error_handler.try(function()
      return fs.get_absolute_path(current_dir)
    end)

    if abs_success and abs_path then
      current_dir = abs_path
    else
      -- Fallback for absolute path using shell command if filesystem module fails
      log_warning("Failed to get absolute path with filesystem module", {
        dir = current_dir,
        error = error_handler.format_error(abs_path),
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
      local join_success, joined_path = error_handler.try(function()
        return fs.join_paths(current_dir, filename)
      end)

      if join_success and joined_path then
        config_path = joined_path
      else
        -- Fallback for path joining if filesystem module fails
        log_warning("Failed to join paths with filesystem module", {
          dir = current_dir,
          filename = filename,
          error = error_handler.format_error(joined_path),
          fallback = "using string concatenation",
        })

        config_path = current_dir .. "/" .. filename
      end

      -- Check if file exists with error handling
      local exists_success, file_exists_result = error_handler.try(function()
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
      local parent_success, parent_dir = error_handler.try(function()
        return fs.get_directory_name(current_dir)
      end)

      if not parent_success or not parent_dir then
        -- Fallback for get_directory_name if filesystem module fails
        log_warning("Failed to get parent directory with filesystem module", {
          dir = current_dir,
          error = error_handler.format_error(parent_dir),
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
      error = error_handler.format_error(search_result),
    })
    return nil
  end

  return search_result
end

-- Find files matching patterns with error handling
local function find_files(include_patterns, exclude_patterns, start_dir)
  -- Validate and process parameters
  error_handler.assert(
    include_patterns ~= nil,
    "Include patterns parameter is required",
    error_handler.CATEGORY.VALIDATION,
    { include_patterns_type = type(include_patterns) }
  )

  if type(include_patterns) == "string" then
    include_patterns = { include_patterns }
  end

  error_handler.assert(
    type(include_patterns) == "table",
    "Include patterns must be a table or string",
    error_handler.CATEGORY.VALIDATION,
    { include_patterns_type = type(include_patterns) }
  )

  if exclude_patterns ~= nil then
    if type(exclude_patterns) == "string" then
      exclude_patterns = { exclude_patterns }
    end

    error_handler.assert(
      type(exclude_patterns) == "table",
      "Exclude patterns must be a table or string",
      error_handler.CATEGORY.VALIDATION,
      { exclude_patterns_type = type(exclude_patterns) }
    )
  else
    exclude_patterns = {}
  end

  start_dir = start_dir or "."

  error_handler.assert(
    type(start_dir) == "string",
    "Start directory must be a string",
    error_handler.CATEGORY.VALIDATION,
    { start_dir_type = type(start_dir) }
  )

  log_debug("Using filesystem module to find files", {
    directory = start_dir,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns,
  })

  -- Use try/catch pattern for the entire file finding process
  local find_success, result = error_handler.try(function()
    -- Normalize path with error handling
    local norm_success, normalized_dir = error_handler.try(function()
      return fs.normalize_path(start_dir)
    end)

    if not norm_success or not normalized_dir then
      log_warning("Failed to normalize directory path", {
        directory = start_dir,
        error = error_handler.format_error(normalized_dir),
        fallback = "using original path",
      })
      normalized_dir = start_dir
    end

    -- Get absolute path with error handling
    local abs_success, absolute_dir = error_handler.try(function()
      return fs.get_absolute_path(normalized_dir)
    end)

    if not abs_success or not absolute_dir then
      log_warning("Failed to get absolute directory path", {
        directory = normalized_dir,
        error = error_handler.format_error(absolute_dir),
        fallback = "using normalized path",
      })
      absolute_dir = normalized_dir
    end

    log_debug("Finding files in normalized directory", {
      normalized_dir = normalized_dir,
      absolute_dir = absolute_dir,
    })

    -- Use filesystem discover_files function with error handling
    local discover_success, files = error_handler.try(function()
      return fs.discover_files({ absolute_dir }, include_patterns, exclude_patterns)
    end)

    if not discover_success or not files then
      local error_obj = error_handler.create(
        "Failed to discover files using filesystem module",
        error_handler.CATEGORY.IO,
        error_handler.SEVERITY.ERROR,
        {
          directory = absolute_dir,
          error = error_handler.format_error(files),
        }
      )

      log_error("Failed to discover files", {
        directory = absolute_dir,
        error = error_handler.format_error(error_obj),
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
      error = error_handler.format_error(result),
      fallback = "returning empty file list",
    })
    return {}
  end

  return result
end

-- Implementation of Lua-based file finding using filesystem module with error handling
local function find_files_lua(include_patterns, exclude_patterns, dir)
  -- Validate and process parameters
  error_handler.assert(
    include_patterns ~= nil,
    "Include patterns parameter is required",
    error_handler.CATEGORY.VALIDATION,
    { include_patterns_type = type(include_patterns) }
  )

  if type(include_patterns) == "string" then
    include_patterns = { include_patterns }
  end

  error_handler.assert(
    type(include_patterns) == "table",
    "Include patterns must be a table or string",
    error_handler.CATEGORY.VALIDATION,
    { include_patterns_type = type(include_patterns) }
  )

  if exclude_patterns ~= nil then
    if type(exclude_patterns) == "string" then
      exclude_patterns = { exclude_patterns }
    end

    error_handler.assert(
      type(exclude_patterns) == "table",
      "Exclude patterns must be a table or string",
      error_handler.CATEGORY.VALIDATION,
      { exclude_patterns_type = type(exclude_patterns) }
    )
  else
    exclude_patterns = {}
  end

  error_handler.assert(
    dir ~= nil and type(dir) == "string",
    "Directory must be a string",
    error_handler.CATEGORY.VALIDATION,
    { dir_type = type(dir) }
  )

  log_debug("Using filesystem module for Lua-based file discovery", {
    directory = dir,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns,
  })

  -- Use try/catch pattern for the file finding process
  local find_success, result = error_handler.try(function()
    -- Normalize directory path with error handling
    local norm_success, normalized_dir = error_handler.try(function()
      return fs.normalize_path(dir)
    end)

    if not norm_success or not normalized_dir then
      log_warning("Failed to normalize directory path", {
        directory = dir,
        error = error_handler.format_error(normalized_dir),
        fallback = "using original path",
      })
      normalized_dir = dir
    end

    -- Use scan_directory to get all files recursively with error handling
    local scan_success, all_files = error_handler.try(function()
      return fs.scan_directory(normalized_dir, true)
    end)

    if not scan_success or not all_files then
      local error_obj = error_handler.io_error("Failed to scan directory", error_handler.SEVERITY.ERROR, {
        directory = normalized_dir,
        error = error_handler.format_error(all_files),
      })

      log_error("Failed to scan directory for files", {
        directory = normalized_dir,
        error = error_handler.format_error(error_obj),
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
      local include_success, include_result = error_handler.try(function()
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
            error = error_handler.format_error(include_result),
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
        local exclude_success, exclude_result = error_handler.try(function()
          for _, pattern in ipairs(exclude_patterns) do
            -- Get relative path with error handling
            local rel_path
            local rel_success, rel_path_result = error_handler.try(function()
              return fs.get_relative_path(file_path, normalized_dir)
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
              error = error_handler.format_error(exclude_result),
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
      error = error_handler.format_error(result),
      fallback = "returning empty file list",
    })
    return {}
  end

  return result
end

--- Initialize module with configuration
---@param options? table Custom configuration options to override defaults
---@return codefix_module The module instance for method chaining
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

--- Check if StyLua is available in the system
---@return boolean available Whether StyLua is available
function M.check_stylua()
  if not command_exists(M.config.stylua_path) then
    log_warning("StyLua not found at: " .. M.config.stylua_path)
    return false
  end

  log_debug("StyLua found at: " .. M.config.stylua_path)
  return true
end

--- Find StyLua configuration file in the given directory or its ancestors
---@param dir? string Directory to start searching from (default: current directory)
---@return string|nil config_path Path to the found configuration file, or nil if not found
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
---@param config_file? string Path to StyLua configuration file (optional)
---@return boolean success Whether the formatting succeeded
---@return string? error_message Error message if formatting failed
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

--- Check if Luacheck is available in the system
---@return boolean available Whether Luacheck is available
function M.check_luacheck()
  if not command_exists(M.config.luacheck_path) then
    log_warning("Luacheck not found at: " .. M.config.luacheck_path)
    return false
  end

  log_debug("Luacheck found at: " .. M.config.luacheck_path)
  return true
end

--- Find Luacheck configuration file in the given directory or its ancestors
---@param dir? string Directory to start searching from (default: current directory)
---@return string|nil config_path Path to the found configuration file, or nil if not found
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
---@param output string The raw output from Luacheck command
---@return table issues Array of parsed issues with file, line, col, code, and message fields
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
---@param config_file? string Path to Luacheck configuration file (optional)
---@return boolean success Whether the check succeeded (may have warnings but no errors)
---@return table issues Array of issues found by Luacheck
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

--- Fix trailing whitespace in multiline strings
---@param content string The source code content to fix
---@return string fixed_content The fixed content with trailing whitespace removed
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

--- Fix unused variables by prefixing them with underscore
---@param file_path string Path to the file to fix
---@param issues? table Array of issues from Luacheck
---@return boolean modified Whether any changes were made
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

--- Fix string concatenation by optimizing .. operator usage
---@param content string The source code content to fix
---@return string fixed_content The fixed content with optimized string concatenations
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

--- Add type annotations in function documentation comments
---@param content string The source code content to fix
---@return string fixed_content The fixed content with added type annotations
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

--- Fix code for Lua version compatibility issues
---@param content string The source code content to fix
---@param target_version? string Target Lua version to make code compatible with (default: "5.1")
---@return string fixed_content The fixed content with compatibility adjustments
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

--- Run all custom fixers on a file
---@param file_path string Path to the file to fix
---@param issues? table Array of issues from Luacheck
---@return boolean modified Whether any changes were made
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

--- Main function to fix a file by running all available fixers
---@param file_path string Path to the file to fix
---@return boolean success Whether the file was successfully fixed
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

--- Fix multiple files by running all available fixers on each
---@param file_paths string[] Array of file paths to fix
---@return boolean success Whether all files were successfully fixed
---@return table results Results for each file, with success status and error message if any
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

--- Find and fix Lua files in a directory matching specified patterns
---@param directory? string Directory to search for Lua files (default: current directory)
---@param options? table Options for filtering and fixing files { include?: string[], exclude?: string[], limit?: number, sort_by_mtime?: boolean, generate_report?: boolean, report_file?: string }
---@return boolean success Whether all files were successfully fixed
---@return table results Results for each file, with success status and error message if any
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

    logger.debug("Generating report file", {
      report_file = report_file,
      report_size = #json_content,
      successful_files = report.successful,
      failed_files = report.failed,
    })

    local success, err = fs.write_file(report_file, json_content)
    if success then
      log_info("Wrote detailed report to " .. report_file)
    else
      log_error("Failed to write report to " .. report_file .. ": " .. (err or "unknown error"))
    end
  end

  return success, results
end

-- Command line interface
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
        logger.debug("Found matching file", { path = file })
        io.write(file .. "\n")
      end
    end

    return true
  elseif command == "help" then
    logger.debug("Displaying codefix help text")

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

-- Module interface with firmo
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

      logger.debug("Codefix reporter initialized", {
        test_count = #results.tests,
        options = options,
      })

      -- Find all source files in the test files
      local test_files = {}
      for _, test in ipairs(results.tests) do
        if test.source_file and not test_files[test.source_file] then
          test_files[test.source_file] = true
          logger.debug("Found source file in test results", {
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

        logger.info("Running codefix on test source files", {
          file_count = #files_to_fix,
          verbose = M.config.verbose,
        })

        local success, fix_results = M.fix_files(files_to_fix)

        if success then
          logger.info("All files fixed successfully", {
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

          logger.warn("Some files could not be fixed", {
            total_files = #files_to_fix,
            successful_files = successful,
            failed_files = failed,
          })
          io.write("⚠️ Some files could not be fixed\n")
        end
      end
    end)
  end

  -- Register a custom fixer with codefix
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

  -- Try to load and register the markdown module
  local ok, markdown = pcall(require, "lib.tools.markdown")
  if ok and markdown then
    markdown.register_with_codefix(M)
    if M.config.verbose then
      logger.info("Registered markdown fixing capabilities")
    end
  end

  return M
end

-- Return the module
return M
