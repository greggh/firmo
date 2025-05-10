--- Centralized Logging System for the Firmo Framework
---
--- This module provides a comprehensive, structured logging system with support
--- for multiple output formats, log levels, and context-enriched messages. It
--- integrates with the central configuration system and supports both global
--- and per-module logging configuration.
---
--- Features:
--- - Named logger instances (`get_logger`) with independent configuration.
--- - Hierarchical log levels (`DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`, `TRACE`).
--- - Structured logging with context tables (`params`).
--- - Configurable output formats (`text`, `json`) and destinations (console, file).
--- - Color-coded console output.
--- - File logging with size-based rotation.
--- - Module filtering (whitelist/blacklist).
--- - Log buffering for performance.
--- - Integration with other tools (search, export, formatter_integration).
--- - Test-aware log suppression.
---
--- @module lib.tools.logging
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class logger_instance Represents a logger instance bound to a specific module name.
--- Provides methods for logging at different levels and checking if levels are enabled.
---@field fatal fun(message: string, params?: table): boolean Logs a message at FATAL level.
---@field error fun(message: string, params?: table): boolean Logs a message at ERROR level.
---@field warn fun(message: string, params?: table): boolean Logs a message at WARN level.
---@field info fun(message: string, params?: table): boolean Logs a message at INFO level.
---@field debug fun(message: string, params?: table): boolean Logs a message at DEBUG level.
---@field trace fun(message: string, params?: table): boolean Logs a message at TRACE level.
---@field verbose fun(message: string, params?: table): boolean Logs a message at TRACE level (alias for trace).
---@field log fun(level: number, message: string, params?: table): boolean Logs a message at a specific numeric level.
---@field would_log fun(level: string|number): boolean Checks if a log at a level would be output for this logger.
---@field is_fatal_enabled fun(): boolean Checks if FATAL level is enabled.
---@field is_error_enabled fun(): boolean Checks if ERROR level is enabled.
---@field is_warn_enabled fun(): boolean Checks if WARN level is enabled.
---@field is_info_enabled fun(): boolean Checks if INFO level is enabled.
---@field is_debug_enabled fun(): boolean Checks if DEBUG level is enabled.
---@field is_trace_enabled fun(): boolean Checks if TRACE level is enabled.
---@field is_verbose_enabled fun(): boolean Checks if TRACE level is enabled (alias).
---@field get_level fun(): number Gets the effective numeric log level for this logger instance.
---@field get_name fun(): string Gets the name of this logger instance.
---@field set_level fun(level: number|string): logger_instance Sets the log level specifically for this logger instance. @throws error If level is invalid.
---@field with_context fun(context: table): logger_instance Creates a new logger instance that includes the provided context in all its log entries.

---@class logging The public API of the logging module.
---@field _VERSION string Module version.
---@field LEVELS table<string, number> Log level constants: FATAL=0, ERROR=1, WARN=2, INFO=3, DEBUG=4, TRACE=5, VERBOSE=5.
---@field FATAL number Fatal log level constant (0).
---@field ERROR number Error log level constant (1).
---@field WARN number Warning log level constant (2).
---@field INFO number Info log level constant (3).
---@field DEBUG number Debug log level constant (4).
---@field TRACE number Trace log level constant (5).
---@field VERBOSE number Verbose log level constant (5, alias for TRACE).
---@field get_logger fun(module_name: string): logger_instance Creates or retrieves a logger instance for a specific module name with optional error handler configuration.
---@field get_configured_logger fun(module_name: string): logger_instance Alias for `get_logger` (configuration is now applied automatically).
---@field configure fun(options?: {level?: number|string, module_levels?: table<string, number|string>, timestamps?: boolean, use_colors?: boolean, output_file?: string|nil, log_dir?: string, silent?: boolean, max_file_size?: number, max_log_files?: number, date_pattern?: string, format?: "text"|"json", json_file?: string|nil, module_filter?: string|string[]|nil, module_blacklist?: string[], buffer_size?: numblocal M = {}

local M = {}

--- Module version
M._VERSION = "1.0.0"

-- Local helper for safe requires without dependency on error_handler
--- @private
--- @return table|nil a module
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

-- Load optional components (lazy loading to avoid circular dependencies)
local error_handler_module, fs_module, search_module, export_module, formatter_integration_module

--- gets the error handler for the filesystem module
local function get_error_handler()
  if not error_handler_module then
    error_handler_module = try_require("lib.tools.error_handler")
  end
  return error_handler_module
end

--- Get the filesystem module using lazy loading
--- This helper function implements lazy loading for the filesystem module,
--- which is needed for all file operations like writing logs, creating
--- directories, and rotating log files. Lazy loading helps avoid circular
--- dependencies and improves module initialization time.
---
--- @private
--- @return table|nil The filesystem module
local function get_fs()
  if not fs_module then
    fs_module = try_require("lib.tools.filesystem")
  end
  return fs_module
end

--- Get the search module for log searching functionality using lazy loading
--- This helper function lazily loads the log search module, which provides
--- functionality for searching through log files based on patterns, levels,
--- and time ranges. It's loaded on-demand to avoid circular dependencies.
---
--- @private
--- @return table|nil The search module or nil if not available
local function get_search()
  if not search_module then
    local search_module = try_require("lib.tools.logging.search")
  end
  return search_module
end

--- Get the export module for log exporting functionality using lazy loading
--- This helper function lazily loads the log export module, which provides
--- functionality for exporting logs to different formats (CSV, JSON, etc.)
--- for integration with external systems. It's loaded on-demand to avoid
--- circular dependencies.
---
--- @private
--- @return table|nil The export module or nil if not available
local function get_export()
  if not export_module then
    local export_module = try_require("lib.tools.logging.export")
  end
  return export_module
end

--- Get the formatter integration module for custom log formatting using lazy loading
--- This helper function lazily loads the formatter integration module, which
--- provides functionality for registering and using custom log formatters.
--- It's loaded on-demand to avoid circular dependencies during module initialization.
---
--- @private
--- @return table|nil The formatter integration module or nil if not available
local function get_formatter_integration()
  if not formatter_integration_module then
    local formatter_integration_module = try_require("lib.tools.logging.formatter_integration")
  end
  return formatter_integration_module
end

--- Convert a log level from string or number to its numeric value
---@param level string|number The log level to normalize (e.g., "INFO", M.LEVELS.INFO).
---@return number|nil The numeric log level value, or `nil` if invalid.
---@private
local function normalize_log_level(level)
  if type(level) == "number" then
    -- Verify it's a valid level number
    for _, num_level in pairs(M.LEVELS) do
      if level == num_level then
        return level
      end
    end
    return nil
  elseif type(level) == "string" then
    -- Convert string level (e.g. "INFO") to number
    local upper_level = level:upper()
    return M.LEVELS[upper_level]
  end
  return nil
end

-- Log levels
M.LEVELS = {
  FATAL = 0,
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
  TRACE = 5,
  VERBOSE = 5, -- for backward compatibility
}

-- Default configuration
local config = {
  global_level = M.LEVELS.INFO, -- Default global level
  module_levels = {}, -- Per-module log levels
  timestamps = true, -- Enable/disable timestamps
  use_colors = true, -- Enable/disable colors
  output_file = nil, -- Log to file (nil = console only)
  log_dir = "logs", -- Directory to store log files
  silent = false, -- Suppress all output when true
  max_file_size = 50 * 1024, -- 50KB default size limit per log file (small for testing)
  max_log_files = 5, -- Number of rotated log files to keep
  date_pattern = "%Y-%m-%d", -- Date pattern for log filenames
  format = "text", -- Default log format: "text" or "json"
  json_file = nil, -- Separate JSON structured log file
  module_filter = nil, -- Filter logs to specific modules (nil = all)
  module_blacklist = {}, -- List of modules to exclude from logging
  buffer_size = 0, -- Buffer size (0 = no buffering)
  buffer_flush_interval = 5, -- Seconds between auto-flush (if buffering)
  standard_metadata = {}, -- Standard metadata fields to include in all logs
  _configured = false, -- Track if module is configured to avoid circular deps
}

-- ANSI color codes
local COLORS = {
  RESET = "\27[0m",
  RED = "\27[31m",
  BRIGHT_RED = "\27[91m",
  GREEN = "\27[32m",
  YELLOW = "\27[33m",
  BLUE = "\27[34m",
  MAGENTA = "\27[35m",
  CYAN = "\27[36m",
  WHITE = "\27[37m",
}

-- Color mapping for log levels
local LEVEL_COLORS = {
  [M.LEVELS.FATAL] = COLORS.BRIGHT_RED,
  [M.LEVELS.ERROR] = COLORS.RED,
  [M.LEVELS.WARN] = COLORS.YELLOW,
  [M.LEVELS.INFO] = COLORS.BLUE,
  [M.LEVELS.DEBUG] = COLORS.CYAN,
  [M.LEVELS.TRACE] = COLORS.MAGENTA,
  [M.LEVELS.VERBOSE] = COLORS.MAGENTA, -- For backward compatibility
}

-- Level names for display
local LEVEL_NAMES = {
  [M.LEVELS.FATAL] = "FATAL",
  [M.LEVELS.ERROR] = "ERROR",
  [M.LEVELS.WARN] = "WARN",
  [M.LEVELS.INFO] = "INFO",
  [M.LEVELS.DEBUG] = "DEBUG",
  [M.LEVELS.TRACE] = "TRACE",
  [M.LEVELS.VERBOSE] = "VERBOSE", -- For backward compatibility
}

-- Message buffer
local buffer = {
  entries = {},
  count = 0,
  last_flush_time = os.time(),
}

--- Gets the current timestamp formatted as "YYYY-MM-DD HH:MM:SS".
---@return string The formatted timestamp string.
---@private
local function get_timestamp()
  return os.date("%Y-%m-%d %H:%M:%S")
end

--- Ensures the logging module is configured
--- This helper function contains the configuration logic that was previously
--- in get_logger(), moved here to break the circular dependency.
---@private
local function _ensure_configured()
  if not config._configured then
    -- Check if central_config is available and initialized
    local ok, central_config_mod = pcall(require, "lib.core.central_config")
    if ok and central_config_mod and central_config_mod._initialized then
      M.configure_from_config("central_config")
    else
      -- Fall back to defaults if central_config isn't available
      M.configure({ level = M.LEVELS.INFO })
    end
    config._configured = true
  end
end

--- Check if logging is enabled for a specific level and module
---@param level number The numeric log level to check.
---@param module_name? string The optional module name to check against specific levels/filters.
---@return boolean `true` if logging is enabled for this level and module context, `false` otherwise.
---@private
local function is_enabled(level, module_name)
  if config.silent then
    return false -- Silent mode overrides all logging
  end

  -- Ensure level is a number
  if type(level) ~= "number" then
    return false
  end

  -- Check module filter/blacklist
  if module_name then
    -- Skip if module is blacklisted
    for _, blacklisted in ipairs(config.module_blacklist) do
      if module_name == blacklisted then
        return false
      end

      -- Support wildcard patterns at the end
      if type(blacklisted) == "string" and blacklisted:match("%*$") then
        local prefix = blacklisted:gsub("%*$", "")
        if module_name:sub(1, #prefix) == prefix then
          return false
        end
      end
    end

    -- If a module filter is specified, only allow matching modules
    if config.module_filter then
      local match = false

      -- Handle array of filters
      if type(config.module_filter) == "table" then
        for _, filter in ipairs(config.module_filter) do
          -- Support exact matches
          if module_name == filter then
            match = true
            break
          end

          -- Support wildcard patterns at the end
          if type(filter) == "string" and filter:match("%*$") then
            local prefix = filter:gsub("%*$", "")
            if module_name:sub(1, #prefix) == prefix then
              match = true
              break
            end
          end
        end
      -- Handle string filter (single module or pattern)
      elseif type(config.module_filter) == "string" then
        -- Support exact match
        if module_name == config.module_filter then
          match = true
        end

        -- Support wildcard pattern at the end
        if config.module_filter:match("%*$") then
          local prefix = config.module_filter:gsub("%*$", "")
          if module_name:sub(1, #prefix) == prefix then
            match = true
          end
        end
      end

      if not match then
        return false
      end
    end
  end

  -- Check module-specific level first, if module is specified
  if module_name then
    local module_level = config.module_levels[module_name]
    if module_level then
      -- Normalize string levels like "INFO" to numbers
      local numeric_level = normalize_log_level(module_level)
      if numeric_level then
        return level <= numeric_level
      end
    end
  end

  -- Fall back to global level if no module level found
  local global_level = config.global_level
  if type(global_level) ~= "number" then
    -- Handle case where global level is a string
    global_level = normalize_log_level(global_level) or M.LEVELS.INFO
  end

  return level <= global_level
end

--- Includes timestamp, level (colorized if enabled), module name, message, and parameters.
---@param level number The numeric log level.
---@param module_name? string The optional module name.
---@param message string The log message.
---@param params? table Additional context parameters.
---@return string The formatted log message string.
---@private
local function format_log(level, module_name, message, params)
  local parts = {}

  -- Add timestamp if enabled
  if config.timestamps then
    table.insert(parts, get_timestamp())
  end

  -- Add level with color if enabled
  local level_str = LEVEL_NAMES[level] or "UNKNOWN"
  if config.use_colors then
    level_str = (LEVEL_COLORS[level] or "") .. level_str .. COLORS.RESET
  end
  table.insert(parts, level_str)

  -- Add module name if provided
  if module_name then
    if config.use_colors then
      table.insert(parts, COLORS.GREEN .. module_name .. COLORS.RESET)
    else
      table.insert(parts, module_name)
    end
  end

  -- Add the message
  table.insert(parts, tostring(message or ""))

  -- Add parameters as a formatted string if provided
  if params and type(params) == "table" and next(params) ~= nil then
    local param_parts = {}
    for k, v in pairs(params) do
      local val_str
      if type(v) == "table" then
        val_str = "{...}" -- Simplify table display in text format
      else
        val_str = tostring(v)
      end
      table.insert(param_parts, k .. "=" .. val_str)
    end

    local param_str = table.concat(param_parts, ", ")
    if config.use_colors then
      param_str = COLORS.CYAN .. param_str .. COLORS.RESET
    end
    table.insert(parts, "(" .. param_str .. ")")
  end

  -- Join all parts with separators
  return table.concat(parts, " | ")
end

--- Ensures the configured log directory exists, creating it if necessary.
---@return boolean `true` if the directory exists or was successfully created, `false` otherwise (logs warning).
---@private
local function ensure_log_dir()
  if config.log_dir then
    local success, err
    local fs = get_fs()
    if fs and get_error_handler() then -- Ensure error_handler is also available for safe_io_operation
      success, err = get_error_handler().safe_io_operation(function()
        return fs.ensure_directory_exists(config.log_dir)
      end, config.log_dir, { operation = "ensure_log_dir" })
    elseif fs then -- Fallback if error_handler is not available
      success, err = pcall(fs.ensure_directory_exists, config.log_dir)
      if not success then
        err = tostring(err)
      end
    end

    if not success then
      print("Warning: Failed to create log directory: " .. (err or "unknown error"))
      return false
    end
    return true
  end
  return true -- No directory configured means no need to create
end

--- Gets the fully resolved path to the main text log file based on configuration.
---@return string|nil The absolute or relative path string, or `nil` if `config.output_file` is not set.
---@private
local function get_log_file_path()
  if not config.output_file then
    return nil
  end

  -- If output_file is an absolute path, use it directly
  if config.output_file:sub(1, 1) == "/" or config.output_file:match("^[A-Za-z]:\\") then -- Basic check for Windows absolute path
    return config.output_file
  end

  -- Otherwise, construct path within log directory
  return (config.log_dir or ".") .. "/" .. config.output_file
end

--- Rotate log files when they exceed the configured maximum size
--- This helper function implements log rotation, which prevents log files from
--- growing too large. When a log file exceeds the configured maximum size,
--- this function:
--- 1. Renames existing rotated logs to make room for the new rotation
--- 2. Moves the current log file to the first rotation position
--- 3. Creates a new empty log file for future logging
---
--- The rotation pattern is:
--- - Current log: logfile.log
--- - Previous logs: logfile.log.1, logfile.log.2, etc.
--- - Oldest logs are deleted when rotation count exceeds max_log_files
---@return boolean `true` if rotation was performed successfully, `false` if rotation was not needed or failed.
---@private
local function rotate_log_files()
  local log_path = get_log_file_path()
  if not log_path then
    return false
  end

  local fs = get_fs()
  if not fs or not fs.file_exists or not fs.get_file_size or not fs.move_file then
    print("Warning: Filesystem module or required functions missing for log rotation.")
    return false
  end

  if not fs.file_exists(log_path) then
    return false
  end

  local size = fs.get_file_size(log_path)
  if not size or size < config.max_file_size then
    return false
  end

  -- Rotate files (move existing rotated logs)
  for i = config.max_log_files - 1, 1, -1 do
    local old_file = log_path .. "." .. i
    local new_file = log_path .. "." .. (i + 1)
    if fs.file_exists(old_file) then
      fs.move_file(old_file, new_file) -- Ignoring errors for simplicity here, could add logging
    end
  end

  -- Move current log to .1
  return fs.move_file(log_path, log_path .. ".1") -- Ignoring errors for simplicity
end

--- Encodes a Lua value to its JSON string representation. Handles basic types and tables.
--- Limits table depth/items for performance.
---@param val any The Lua value to encode.
---@return string The JSON string representation. Returns string representation of type for unsupported types.
---@private
local function json_encode_value(val)
  local json_type = type(val)
  if json_type == "nil" then
    return "null"
  elseif json_type == "string" then
    return '"'
      .. val
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
        :gsub("\b", "\\b")
        :gsub("\f", "\\f")
      .. '"'
  elseif json_type == "number" then
    if val ~= val then
      return '"NaN"'
    elseif val == 1 / 0 then
      return '"Infinity"'
    elseif val == -1 / 0 then
      return '"-Infinity"'
    else
      return tostring(val)
    end
  elseif json_type == "boolean" then
    return tostring(val)
  elseif json_type == "table" then
    local is_array = true
    local n = 0
    for k, _ in pairs(val) do
      n = n + 1
      if type(k) ~= "number" or k ~= n then
        is_array = false
        break
      end
    end
    local result = is_array and "[" or "{"
    local first = true
    local count = 0
    local max_items = 100
    if is_array then
      for _, v in ipairs(val) do
        count = count + 1
        if count > max_items then
          result = result .. (first and "" or ",") .. '"..."'
          break
        end
        if not first then
          result = result .. ","
        end
        result = result .. json_encode_value(v)
        first = false
      end
      result = result .. "]"
    else
      for k, v in pairs(val) do
        count = count + 1
        if count > max_items then
          result = result .. (first and "" or ",") .. '"..." : "..."'
          break
        end
        if not first then
          result = result .. ","
        end
        result = result .. '"' .. tostring(k):gsub('"', '\\"') .. '":' .. json_encode_value(v)
        first = false
      end
      result = result .. "}"
    end
    return result
  else
    return '"' .. tostring(val):gsub('"', '\\"') .. '"'
  end
end

--- Formats a log entry into a JSON string.
--- Includes standard fields (timestamp, level, module, message) and merges standard metadata and call parameters.
---@param level number The numeric log level.
---@param module_name? string The optional module name.
---@param message string The log message.
---@param params? table Additional context parameters.
---@return string The JSON string representation of the log entry.
---@private
local function format_json(level, module_name, message, params)
  local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ") -- UTC ISO 8601
  local level_name = LEVEL_NAMES[level] or "UNKNOWN"
  local json_parts = {
    '"timestamp":"' .. timestamp .. '"',
    '"level":"' .. level_name .. '"',
    '"module":"' .. (module_name or ""):gsub('"', '\\"') .. '"',
    '"message":"' .. (message or ""):gsub('"', '\\"') .. '"',
  }
  for key, value in pairs(config.standard_metadata) do
    table.insert(json_parts, '"' .. key .. '":' .. json_encode_value(value))
  end
  if params and type(params) == "table" then
    for key, value in pairs(params) do
      if key ~= "timestamp" and key ~= "level" and key ~= "module" and key ~= "message" then
        table.insert(json_parts, '"' .. key .. '":' .. json_encode_value(value))
      end
    end
  end
  return "{" .. table.concat(json_parts, ",") .. "}"
end

--- Gets the fully resolved path to the JSON log file based on configuration.
---@return string|nil The absolute or relative path string, or `nil` if `config.json_file` is not set.
---@private
local function get_json_log_file_path()
  if not config.json_file then
    return nil
  end
  if config.json_file:sub(1, 1) == "/" or config.json_file:match("^[A-Za-z]:\\") then
    return config.json_file
  end
  return (config.log_dir or ".") .. "/" .. config.json_file
end

--- Rotate JSON log files when they exceed the configured maximum size
---@return boolean `true` if rotation was performed successfully, `false` if rotation was not needed or failed.
---@private
local function rotate_json_log_files()
  local log_path = get_json_log_file_path()
  if not log_path then
    return false
  end
  local fs = get_fs()
  if not fs or not fs.file_exists or not fs.get_file_size or not fs.move_file then
    print("Warning: FS module missing for JSON log rotation.")
    return false
  end
  if not fs.file_exists(log_path) then
    return false
  end
  local size = fs.get_file_size(log_path)
  if not size or size < config.max_file_size then
    return false
  end
  for i = config.max_log_files - 1, 1, -1 do
    local of = log_path .. "." .. i
    local nf = log_path .. "." .. (i + 1)
    if fs.file_exists(of) then
      fs.move_file(of, nf)
    end
  end
  return fs.move_file(log_path, log_path .. ".1")
end

--- Writes all buffered log entries to configured output files (text and/or JSON).
---@return boolean `true` if flush was successful (or nothing to flush), `false` if any write operation failed.
---@private
local function flush_buffer()
  if buffer.count == 0 then
    return true
  end
  local success = true
  local fs = get_fs()
  if config.output_file then
    local log_path = get_log_file_path()
    local content = ""
    for _, e in ipairs(buffer.entries) do
      content = content .. e.text .. "\n"
    end
    local file_ok, err
    if fs and get_error_handler() then
      file_ok, err = get_error_handler().safe_io_operation(function()
        return fs.append_file(log_path, content)
      end, log_path, { op = "append_text_log_buffer" })
    elseif fs then
      file_ok, err = pcall(fs.append_file, log_path, content)
      if not file_ok then
        err = tostring(err)
      end
    end
    if not file_ok then
      print("Warning: Failed to write buffer to log file: " .. (err or "?"))
      success = false
    end
  end
  if config.json_file then
    local json_log_path = get_json_log_file_path()
    local json_content = ""
    for _, e in ipairs(buffer.entries) do
      json_content = json_content .. e.json .. "\n"
    end
    local json_ok, err
    if fs and get_error_handler() then
      json_ok, err = get_error_handler().safe_io_operation(function()
        return fs.append_file(json_log_path, json_content)
      end, json_log_path, { op = "append_json_log_buffer" })
    elseif fs then
      json_ok, err = pcall(fs.append_file, json_log_path, json_content)
      if not json_ok then
        err = tostring(err)
      end
    end
    if not json_ok then
      print("Warning: Failed to write buffer to JSON log file: " .. (err or "?"))
      success = false
    end
  end
  buffer.entries = {}
  buffer.count = 0
  buffer.last_flush_time = os.time()
  return success
end

---@return boolean `true` if the current test expects errors, `false` otherwise.
---@private
local function current_test_expects_errors()
  local eh = get_error_handler()
  if eh and eh.current_test_expects_errors then
    return eh.current_test_expects_errors()
  end
  return false
end

if not _G._firmo_debug_mode then
  _G._firmo_debug_mode = false
  if _G.arg then
    for _, v in ipairs(_G.arg) do
      if v == "--debug" then
        _G._firmo_debug_mode = true
        break
      end
    end
  end
end

--- Core logging function that handles all log operations
---@param level number The numeric log level for this message.
---@param module_name? string The module name (source) of the log message.
---@param message string The log message text.
---@param params? table Additional context parameters to include with the log.
---@return boolean `true` if the log message was processed, `false` if filtered out.
---@private
local function log(level, module_name, message, params)
  if level <= M.LEVELS.WARN and current_test_expects_errors() then
    if _G._firmo_debug_mode then
      params = params or {}
      params._expected_debug_override = true
    else
      level = M.LEVELS.DEBUG
    end
  end
  local has_override = params and type(params) == "table" and params._expected_debug_override
  if not has_override and not is_enabled(level, module_name) then
    return false
  end
  if params and type(params) == "table" and params._expected_debug_override then
    params._expected_debug_override = nil
  end
  if config.silent then
    return false
  end
  local formatted_text = format_log(level, module_name, message, params)
  local formatted_json = format_json(level, module_name, message, params)
  print(formatted_text) -- Always print to console if not silent and not filtered
  if config.buffer_size > 0 then
    if os.time() - buffer.last_flush_time >= config.buffer_flush_interval then
      flush_buffer()
    end
    table.insert(buffer.entries, {
      text = formatted_text,
      json = formatted_json,
      level = level,
      module = module_name,
      message = message,
      params = params,
    })
    buffer.count = buffer.count + 1
    if buffer.count >= config.buffer_size then
      flush_buffer()
    end
    return true
  end
  local fs = get_fs()
  if config.output_file and fs then
    local log_path = get_log_file_path()
    ensure_log_dir()
    if config.max_file_size and config.max_file_size > 0 then
      local sz = fs.file_exists(log_path) and fs.get_file_size(log_path) or 0
      if sz >= config.max_file_size then
        rotate_log_files()
      end
    end
    local s, e
    if get_error_handler() then
      s, e = get_error_handler().safe_io_operation(function()
        return fs.append_file(log_path, formatted_text .. "\n")
      end, log_path, { op = "append_text_log_direct" })
    else
      s, e = pcall(fs.append_file, log_path, formatted_text .. "\n")
      if not s then
        e = tostring(e)
      end
    end
    if not s then
      print("Warning: Failed to write to log file: " .. (e or "?"))
    end
  end
  if config.json_file and fs then
    local json_log_path = get_json_log_file_path()
    ensure_log_dir()
    if config.max_file_size and config.max_file_size > 0 then
      local sz = fs.file_exists(json_log_path) and fs.get_file_size(json_log_path) or 0
      if sz >= config.max_file_size then
        rotate_json_log_files()
      end
    end
    local s, e
    if get_error_handler() then
      s, e = get_error_handler().safe_io_operation(function()
        return fs.append_file(json_log_path, formatted_json .. "\n")
      end, json_log_path, { op = "append_json_log_direct" })
    else
      s, e = pcall(fs.append_file, json_log_path, formatted_json .. "\n")
      if not s then
        e = tostring(e)
      end
    end
    if not s then
      print("Warning: Failed to write to JSON log file: " .. (e or "?"))
    end
  end
  return true
end

function M.configure(options)
  options = options or {}
  if options.level ~= nil then
    config.global_level = normalize_log_level(options.level) or config.global_level
  end
  if options.module_levels then
    for m, l in pairs(options.module_levels) do
      config.module_levels[m] = normalize_log_level(l) or config.module_levels[m]
    end
  end
  if options.timestamps ~= nil then
    config.timestamps = options.timestamps
  end
  if options.use_colors ~= nil then
    config.use_colors = options.use_colors
  end
  if options.output_file ~= nil then
    config.output_file = options.output_file
  end
  if options.log_dir ~= nil then
    config.log_dir = options.log_dir
  end
  if options.silent ~= nil then
    config.silent = options.silent
  end
  if options.max_file_size ~= nil then
    config.max_file_size = options.max_file_size
  end
  if options.max_log_files ~= nil then
    config.max_log_files = options.max_log_files
  end
  if options.date_pattern ~= nil then
    config.date_pattern = options.date_pattern
  end
  if options.format ~= nil then
    config.format = options.format
  end
  if options.json_file ~= nil then
    config.json_file = options.json_file
  end
  if options.module_filter ~= nil then
    config.module_filter = options.module_filter
  end
  if options.module_blacklist ~= nil then
    config.module_blacklist = options.module_blacklist
  end
  if options.buffer_size ~= nil then
    config.buffer_size = options.buffer_size
    buffer.entries = {}
    buffer.count = 0
    buffer.last_flush_time = os.time()
  end
  if options.buffer_flush_interval ~= nil then
    config.buffer_flush_interval = options.buffer_flush_interval
  end
  if options.standard_metadata ~= nil then
    config.standard_metadata = options.standard_metadata
  end
  if config.output_file or config.json_file then
    ensure_log_dir()
  end
  return M
end

local logger_mt = {
  __index = function(tbl, key)
    local level_const = M.LEVELS[key:upper()]
    if level_const then
      return function(message, params)
        _ensure_configured()
        return log(level_const, rawget(tbl, "_module_name"), message, params)
      end
    end
    if key == "is_level_enabled" or key == "would_log" then
      return function(level)
        return is_enabled(normalize_log_level(level) or -1, rawget(tbl, "_module_name"))
      end
    end
    for level_name_iter, level_val_iter in pairs(M.LEVELS) do
      if key == "is_" .. level_name_iter:lower() .. "_enabled" then
        return function()
          return is_enabled(level_val_iter, rawget(tbl, "_module_name"))
        end
      end
    end
    if key == "get_level" then
      return function()
        local ml = config.module_levels[rawget(tbl, "_module_name")]
        return normalize_log_level(ml) or normalize_log_level(config.global_level) or M.LEVELS.INFO
      end
    end
    if key == "get_name" then
      return function()
        return rawget(tbl, "_module_name")
      end
    end
    if key == "set_level" then
      return function(level_val)
        M.set_module_level(rawget(tbl, "_module_name"), level_val)
        return tbl
      end
    end
    return nil
  end,
}

function M.get_logger(module_name)
  _ensure_configured() -- Ensure config is loaded before creating a logger
  local logger_instance = { _module_name = module_name or "default" }
  return setmetatable(logger_instance, logger_mt)
end

M.get_configured_logger = M.get_logger -- Alias

function M.fatal(message, params)
  log(M.LEVELS.FATAL, nil, message, params)
end
function M.error(message, params)
  log(M.LEVELS.ERROR, nil, message, params)
end
function M.warn(message, params)
  log(M.LEVELS.WARN, nil, message, params)
end
function M.info(message, params)
  log(M.LEVELS.INFO, nil, message, params)
end
function M.debug(message, params)
  log(M.LEVELS.DEBUG, nil, message, params)
end
function M.trace(message, params)
  log(M.LEVELS.TRACE, nil, message, params)
end
M.verbose = M.trace -- Alias

function M.flush()
  flush_buffer()
  return M
end
function M.would_log(level, module_name)
  local nl = normalize_log_level(level)
  return nl and is_enabled(nl, module_name) or false
end
function M.with_level(module_name, level, func)
  local ol = config.module_levels[module_name]
  local nl = normalize_log_level(level)
  if nl then
    M.set_module_level(module_name, nl)
  end
  local s, r = pcall(func)
  if ol then
    M.set_module_level(module_name, ol)
  else
    config.module_levels[module_name] = nil
  end
  if not s then
    error(r)
  end
  return r
end
function M.set_module_level(module_name, level)
  local nl = normalize_log_level(level)
  if nl then
    config.module_levels[module_name] = nl
  end
  return M
end
function M.set_level(level)
  local nl = normalize_log_level(level)
  if nl then
    config.global_level = nl
  end
  return M
end

function M.configure_from_config(context_name) -- Typically "central_config" or "cli_options"
  local ccfg_mod = try_require("lib.core.central_config")
  if not ccfg_mod then
    return config.global_level
  end
  local log_cfg = ccfg_mod.get("logging")
  if log_cfg then
    M.configure({ -- Pass the whole logging sub-table
      level = log_cfg.level,
      module_levels = log_cfg.modules,
      timestamps = log_cfg.timestamps,
      use_colors = log_cfg.use_colors,
      output_file = log_cfg.output_file,
      log_dir = log_cfg.log_dir,
      silent = log_cfg.silent,
      max_file_size = log_cfg.max_file_size,
      max_log_files = log_cfg.max_log_files,
      date_pattern = log_cfg.date_pattern,
      format = log_cfg.format,
      json_file = log_cfg.json_file,
      module_filter = log_cfg.module_filter,
      module_blacklist = log_cfg.module_blacklist,
      buffer_size = log_cfg.buffer_size,
      buffer_flush_interval = log_cfg.buffer_flush_interval,
      standard_metadata = log_cfg.standard_metadata,
    })
    -- Determine the effective global level after applying config
    return normalize_log_level(config.global_level) or M.LEVELS.INFO
  end
  return config.global_level -- Return current if no specific "logging" table found
end

function M.configure_from_options(module_name, options)
  if not module_name or not options then
    return M.LEVELS.INFO
  end
  local log_level = normalize_log_level(config.global_level) or M.LEVELS.INFO -- Start with current global
  if options.level then
    local nl = normalize_log_level(options.level)
    if nl then
      log_level = nl
    end
  elseif options.debug then
    log_level = M.LEVELS.DEBUG
  elseif options.verbose then
    log_level = M.LEVELS.TRACE -- Changed from VERBOSE to TRACE to match LEVELS
  end
  M.set_module_level(module_name, log_level)
  return log_level
end

function M.filter_module(module_pattern)
  if not config.module_filter then
    config.module_filter = {}
  end
  if type(config.module_filter) == "string" then
    config.module_filter = { config.module_filter }
  end
  for _, p in ipairs(config.module_filter) do
    if p == module_pattern then
      return M
    end
  end
  table.insert(config.module_filter, module_pattern)
  return M
end
function M.clear_module_filters()
  config.module_filter = nil
  return M
end
function M.blacklist_module(module_pattern)
  if not config.module_blacklist then
    config.module_blacklist = {}
  end
  for _, p in ipairs(config.module_blacklist) do
    if p == module_pattern then
      return M
    end
  end
  table.insert(config.module_blacklist, module_pattern)
  return M
end
function M.remove_from_blacklist(module_pattern)
  if config.module_blacklist then
    for i, p in ipairs(config.module_blacklist) do
      if p == module_pattern then
        table.remove(config.module_blacklist, i)
        return M
      end
    end
  end
  return M
end
function M.clear_blacklist()
  config.module_blacklist = {}
  return M
end
function M.get_config()
  local c = {}
  for k, v in pairs(config) do
    c[k] = v
  end
  return c
end

M.log_debug = function(msg, mod)
  log(M.LEVELS.DEBUG, mod, msg)
end
M.log_verbose = function(msg, mod)
  log(M.LEVELS.TRACE, mod, msg)
end -- Changed from VERBOSE to TRACE

function M.search()
  return get_search()
end
function M.export()
  return get_export()
end
function M.formatter_integration()
  return get_formatter_integration()
end
function M.create_buffered_logger(module_name, options)
  options = options or {}
  local bs = options.buffer_size or 100
  local fi = options.flush_interval or 5
  local bc = { buffer_size = bs, buffer_flush_interval = fi }
  if options.output_file then
    bc.output_file = options.output_file
  end
  M.configure(bc)
  local li = M.get_logger(module_name)
  li.flush = function()
    M.flush()
    return li
  end
  local mt = getmetatable(li) or {}
  mt.__gc = function()
    li.flush()
  end
  setmetatable(li, mt)
  return li
end

return M
