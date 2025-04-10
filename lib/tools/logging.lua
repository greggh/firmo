--[[
    Centralized Logging System for the Firmo Framework

    This module provides a comprehensive, structured logging system with support
    for multiple output formats, log levels, and context-enriched messages. It
    integrates with the central configuration system and supports both global
    and per-module logging configuration.

    Features:
    - Named logger instances with independent configuration
    - Hierarchical log levels (DEBUG, INFO, WARN, ERROR, FATAL)
    - Structured logging with context objects
    - Configurable output formats and destinations
    - Color-coded console output
    - File logging with rotation
    - Log search and filtering capabilities
    - Integration with external logging systems
    - Context inheritance and enrichment
    - Source location tracking
    - Performance-optimized logging
    - Test-aware log suppression

    The logging system serves as a foundation for debugging, monitoring, and
    diagnostics throughout the framework, providing consistent log formatting
    and centralized control over verbosity.

    @module logging
    @author Firmo Team
    @license MIT
    @copyright 2023-2025
    @version 1.0.0
]]

---@class logging
---@field _VERSION string Module version
---@field DEBUG number Debug log level (most verbose)
---@field INFO number Info log level
---@field WARN number Warning log level
---@field ERROR number Error log level (least verbose)
---@field get_logger fun(name: string): logger_instance Create a named logger instance
---@field get_logger fun(name: string): logger_instance Create a named logger instance
---@field get_configured_logger fun(name: string): logger_instance Create and configure a named logger instance
---@field configure fun(options: {level?: number|string, file?: string, format?: string, console?: boolean, max_file_size?: number, include_source?: boolean, include_timestamp?: boolean, include_level?: boolean, include_colors?: boolean, colors?: table<string, string>}): logging Configure the logging system
---@field configure_from_config fun(config_key: string): logging Configure logging from central config
---@field reset fun(): logging Reset logging to defaults
---@field disable fun(): logging Disable all logging
---@field enable fun(): logging Re-enable logging
---@field is_enabled fun(): boolean Check if logging is enabled
---@field get_level fun(): number Get current log level
---@field get_current_config fun(): table Get current logging configuration
---@field formats table<string, string> Built-in formatting patterns
---@field register_formatter fun(name: string, formatter: fun(log_entry: table): string): boolean Register a custom formatter
---@field log fun(level: number, message: string, context?: table, source?: string): boolean Log a message with level
---@field debug fun(message: string, context?: table, source?: string): boolean Log a debug message
---@field info fun(message: string, context?: table, source?: string): boolean Log an info message
---@field warn fun(message: string, context?: table, source?: string): boolean Log a warning message
---@field error fun(message: string, context?: table, source?: string): boolean Log an error message
---@field search_logs fun(pattern: string, options?: table): table Search logs for a pattern
---@field flush fun(): boolean Flush pending log messages

---@class logger_instance
---@field debug fun(message: string, context?: table): boolean Log a debug message
---@field info fun(message: string, context?: table): boolean Log an info message
---@field warn fun(message: string, context?: table): boolean Log a warning message
---@field error fun(message: string, context?: table): boolean Log an error message
---@field is_debug_enabled fun(): boolean Check if debug logging is enabled
---@field is_info_enabled fun(): boolean Check if info logging is enabled
---@field is_warn_enabled fun(): boolean Check if warning logging is enabled
---@field is_error_enabled fun(): boolean Check if error logging is enabled
---@field set_level fun(level: number|string): logger_instance Set log level for this logger instance
---@field get_level fun(): number Get log level for this logger instance
---@field get_name fun(): string Get logger name
---@field configure fun(options: table): logger_instance Configure this logger instance
---@field log fun(level: number, message: string, context?: table): boolean Log a message with level
---@field with_context fun(context: table): logger_instance Create a logger with predefined context

local M = {}

-- Try to import filesystem module (might not be available during first load)
local fs
--- Get the filesystem module using lazy loading
--- This helper function implements lazy loading for the filesystem module,
--- which is needed for all file operations like writing logs, creating
--- directories, and rotating log files. Lazy loading helps avoid circular
--- dependencies and improves module initialization time.
---
--- @private
--- @return table The filesystem module
local function get_fs()
  if not fs then
    fs = require("lib.tools.filesystem")
  end
  return fs
end

-- Load optional components (lazy loading to avoid circular dependencies)
local search_module, export_module, formatter_integration_module

--- Get the search module for log searching functionality using lazy loading
--- This helper function lazily loads the log search module, which provides
--- functionality for searching through log files based on patterns, levels,
--- and time ranges. It's loaded on-demand to avoid circular dependencies.
---
--- @private
--- @return table|nil The search module or nil if not available
local function get_search()
  if not search_module then
    local success, module = pcall(require, "lib.tools.logging.search")
    if success then
      search_module = module
    end
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
    local success, module = pcall(require, "lib.tools.logging.export")
    if success then
      export_module = module
    end
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
    local success, module = pcall(require, "lib.tools.logging.formatter_integration")
    if success then
      formatter_integration_module = module
    end
  end
  return formatter_integration_module
end

--- Convert a log level from string or number to its numeric value
--- @param level string|number The log level to normalize
--- @return number|nil The numeric log level value, or nil if invalid
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

--- Get current timestamp formatted for logs
---@return string The formatted timestamp
local function get_timestamp()
  return os.date("%Y-%m-%d %H:%M:%S")
end

--- Check if logging is enabled for a specific level and module
---@param level number The log level to check
---@param module_name? string The module name to check
---@return boolean Whether logging is enabled for this level and module
local function is_enabled(level, module_name)
  if config.silent then
    return false
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

--- Format a log message for text output
---@param level number The log level
---@param module_name? string The module name
---@param message string The log message
---@param params? table Additional parameters to include in the log
---@return string The formatted log message
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
  table.insert(parts, message or "")

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

--- Ensure the log directory exists before writing log files
--- This helper function checks if the configured log directory exists
--- and creates it if necessary. It handles any errors that might occur
--- during directory creation by printing a warning to the console.
---
--- @private
--- @return boolean Whether the directory exists or was successfully created
local function ensure_log_dir()
  local fs = get_fs()
  if config.log_dir then
    local success, err = fs.ensure_directory_exists(config.log_dir)
    if not success then
      print("Warning: Failed to create log directory: " .. (err or "unknown error"))
      return false
    end
    return true
  end
  return true -- No directory configured means no need to create
end

--- Get the full path to the log file, considering absolute and relative paths
--- This helper function resolves the configured log file path, handling both
--- absolute paths and paths relative to the log directory. It ensures consistent
--- path handling throughout the logging system.
---
--- @private
--- @return string|nil The full path to the log file or nil if not configured
local function get_log_file_path()
  if not config.output_file then
    return nil
  end

  -- If output_file is an absolute path, use it directly
  if config.output_file:sub(1, 1) == "/" then
    return config.output_file
  end

  -- Otherwise, construct path within log directory
  return config.log_dir .. "/" .. config.output_file
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
---
--- @private
--- @return boolean Whether rotation was successful
local function rotate_log_files()
  local fs = get_fs()
  local log_path = get_log_file_path()
  if not log_path then
    return false
  end

  -- Check if we need to rotate
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
      fs.move_file(old_file, new_file)
    end
  end

  -- Move current log to .1
  return fs.move_file(log_path, log_path .. ".1")
end

--- Encode a Lua value as a JSON string
--- This helper function implements a lightweight JSON encoder that converts
--- Lua values (strings, numbers, booleans, tables) to their JSON representation.
--- It handles special cases like NaN and Infinity, and truncates large tables
--- to prevent excessive output. This function is used for structured logging
--- to generate JSON-formatted log entries.
---
--- @private
--- @param val any The Lua value to encode as JSON
--- @return string The JSON string representation of the value
local function json_encode_value(val)
  local json_type = type(val)
  if json_type == "string" then
    -- Escape special characters in strings
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
    -- Handle NaN and infinity which have no direct JSON representation
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
    -- Determine if table is an array or object
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

    -- Avoid processing tables that are too large
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
          result = result .. (first and "" or ",") .. '"...":"..."'
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
  elseif json_type == "nil" then
    return "null"
  else
    -- Function, userdata, thread, etc. can't be directly represented in JSON
    return '"' .. tostring(val):gsub('"', '\\"') .. '"'
  end
end

--- Format a log entry as a JSON string for structured logging
--- This helper function creates a JSON representation of a log entry, including
--- standard fields (timestamp, level, module, message) and any additional
--- context parameters. The resulting JSON string can be written to log files
--- or sent to external logging systems that consume structured logs.
---
--- @private
--- @param level number The numeric log level
--- @param module_name? string The module name that generated the log
--- @param message string The log message text
--- @param params? table Additional context parameters to include
--- @return string The JSON string representation of the log entry
local function format_json(level, module_name, message, params)
  -- Use ISO8601-like timestamp format for JSON logs
  local timestamp = os.date("%Y-%m-%dT%H:%M:%S")
  local level_name = LEVEL_NAMES[level] or "UNKNOWN"

  -- Start with standard fields
  local json_parts = {
    '"timestamp":"' .. timestamp .. '"',
    '"level":"' .. level_name .. '"',
    '"module":"' .. (module_name or ""):gsub('"', '\\"') .. '"',
    '"message":"' .. (message or ""):gsub('"', '\\"') .. '"',
  }

  -- Add standard metadata fields from configuration
  for key, value in pairs(config.standard_metadata) do
    table.insert(json_parts, '"' .. key .. '":' .. json_encode_value(value))
  end

  -- Add parameters if provided
  if params and type(params) == "table" then
    for key, value in pairs(params) do
      -- Skip reserved keys to prevent overwriting standard fields
      if key ~= "timestamp" and key ~= "level" and key ~= "module" and key ~= "message" then
        table.insert(json_parts, '"' .. key .. '":' .. json_encode_value(value))
      end
    end
  end

  return "{" .. table.concat(json_parts, ",") .. "}"
end

--- Get the full path to the JSON log file
--- This helper function resolves the configured JSON log file path, handling
--- both absolute paths and paths relative to the log directory. It works
--- similarly to get_log_file_path() but for the structured JSON logs.
---
--- @private
--- @return string|nil The full path to the JSON log file or nil if not configured
local function get_json_log_file_path()
  if not config.json_file then
    return nil
  end

  -- If json_file is an absolute path, use it directly
  if config.json_file:sub(1, 1) == "/" then
    return config.json_file
  end

  -- Otherwise, construct path within log directory
  return config.log_dir .. "/" .. config.json_file
end

--- Rotate JSON log files when they exceed the configured maximum size
--- This helper function implements log rotation for JSON-formatted log files,
--- which prevents them from growing too large. It works similarly to
--- rotate_log_files() but specifically for structured JSON logs.
---
--- @private
--- @return boolean Whether rotation was successful
local function rotate_json_log_files()
  local fs = get_fs()
  local log_path = get_json_log_file_path()
  if not log_path then
    return false
  end

  -- Check if we need to rotate
  if not fs.file_exists(log_path) then
    return false
  end

  local size = fs.get_file_size(log_path)
  if not size or size < config.max_file_size then
    return false
  end

  -- Rotate files
  for i = config.max_log_files - 1, 1, -1 do
    local old_file = log_path .. "." .. i
    local new_file = log_path .. "." .. (i + 1)
    if fs.file_exists(old_file) then
      fs.move_file(old_file, new_file)
    end
  end

  -- Move current log to .1
  return fs.move_file(log_path, log_path .. ".1")
end

--- Flush buffered log messages to disk
--- This helper function writes all buffered log messages to the configured
--- output files. It's called automatically when the buffer fills up or after
--- the flush interval elapses, and can also be called manually via the flush()
--- public method. Buffering improves performance by reducing I/O operations.
---
--- @private
--- @return boolean Whether the flush operation was successful
local function flush_buffer()
  if buffer.count == 0 then
    return true -- Nothing to flush is considered successful
  end

  local fs = get_fs()
  local success = true

  -- Regular log file
  if config.output_file then
    local log_path = get_log_file_path()

    -- Build content string
    local content = ""
    for _, entry in ipairs(buffer.entries) do
      content = content .. entry.text .. "\n"
    end

    -- Append to log file
    local file_success, err = fs.append_file(log_path, content)
    if not file_success then
      print("Warning: Failed to write to log file: " .. (err or "unknown error"))
      success = false
    end
  end

  -- JSON log file
  if config.json_file then
    local json_log_path = get_json_log_file_path()

    -- Build JSON content string
    local json_content = ""
    for _, entry in ipairs(buffer.entries) do
      json_content = json_content .. entry.json .. "\n"
    end

    -- Append to JSON log file
    local json_success, err = fs.append_file(json_log_path, json_content)
    if not json_success then
      print("Warning: Failed to write to JSON log file: " .. (err or "unknown error"))
      success = false
    end
  end

  -- Reset buffer
  buffer.entries = {}
  buffer.count = 0
  buffer.last_flush_time = os.time()

  return success
end

--- Lazy-load the error_handler module to avoid circular dependencies
--- This helper function implements lazy loading for the error_handler module,
--- which helps prevent circular dependencies that can occur during module
--- initialization. It attempts to load the module only when needed and
--- caches the result to avoid repeated require attempts.
---
--- @private
--- @return table|nil The error_handler module or nil if it couldn't be loaded
local _error_handler
local function get_error_handler()
  if not _error_handler then
    local success, module = pcall(require, "lib.tools.error_handler")
    if success then
      _error_handler = module
    end
  end
  return _error_handler
end

--- Check if the current test is designed to expect errors
--- This helper function integrates with the error_handler module to determine
--- if the current running test is marked as expecting errors. This allows the
--- logging system to handle error logs differently during tests that are
--- deliberately testing error conditions.
---
--- @private
--- @return boolean Whether the current test expects errors
local function current_test_expects_errors()
  local error_handler = get_error_handler()

  -- If error_handler is loaded and has the function, call it
  if error_handler and error_handler.current_test_expects_errors then
    return error_handler.current_test_expects_errors()
  end

  -- Default to false if we couldn't determine
  return false
end

-- Set a global debug flag if the --debug argument is present
-- This is only done once when the module loads
if not _G._firmo_debug_mode then
  _G._firmo_debug_mode = false

  -- Detect debug mode from command line arguments
  if arg then
    for _, v in ipairs(arg) do
      if v == "--debug" then
        _G._firmo_debug_mode = true
        break
      end
    end
  end
end

--- Core logging function that handles all log operations
--- This internal function implements the actual logging logic, including
--- level filtering, formatting, test error handling, output to console and files,
--- buffering, and rotation. All public logging methods ultimately call this
--- function to perform the actual logging operation.
---
--- @private
--- @param level number The numeric log level for this message
--- @param module_name? string The module name (source) of the log message
--- @param message string The log message text
--- @param params? table Additional context parameters to include with the log
--- @return boolean Whether the log message was output
local function log(level, module_name, message, params)
  -- For expected errors in tests, either filter or log expected errors
  if level <= M.LEVELS.WARN then
    if current_test_expects_errors() then
      -- Prefix message to indicate this is an expected error
      message = "[EXPECTED] " .. message

      -- Store the error in the global error repository for potential debugging
      local error_handler = get_error_handler()
      if error_handler then
        _G._firmo_test_expected_errors = _G._firmo_test_expected_errors or {}
        table.insert(_G._firmo_test_expected_errors, {
          level = level,
          module = module_name,
          message = message,
          params = params,
          timestamp = os.time(),
        })
      end

      -- In debug mode (--debug flag), make all expected errors visible regardless of module
      if _G._firmo_debug_mode then
        -- Override the level check below for expected errors
        -- Force immediate logging - we do this by keeping the original level (ERROR or WARN)
        -- but setting a special flag that skips the is_enabled() check
        params = params or {}
        params._expected_debug_override = true
      else
        -- Downgrade to DEBUG level - which may or may not be visible depending on module config
        level = M.LEVELS.DEBUG
      end
    end
  end

  -- Check if this log should be shown (unless it's an expected error with debug override)
  local has_debug_override = params and params._expected_debug_override
  if not has_debug_override and not is_enabled(level, module_name) then
    return false
  end

  -- Remove internal flag from params if it exists
  if params and params._expected_debug_override then
    params._expected_debug_override = nil
  end

  -- In silent mode, don't output anything
  if config.silent then
    return false
  end

  -- Format as text for console and regular log file
  local formatted_text = format_log(level, module_name, message, params)

  -- Format as JSON for structured logging
  local formatted_json = format_json(level, module_name, message, params)

  -- Output to console
  print(formatted_text)

  -- If we're buffering, add to buffer
  if config.buffer_size > 0 then
    -- Check if we need to auto-flush due to time
    if os.time() - buffer.last_flush_time >= config.buffer_flush_interval then
      flush_buffer()
    end

    -- Add to buffer
    table.insert(buffer.entries, {
      text = formatted_text,
      json = formatted_json,
      level = level,
      module = module_name,
      message = message,
      params = params,
    })
    buffer.count = buffer.count + 1

    -- Flush if buffer is full
    if buffer.count >= config.buffer_size then
      flush_buffer()
    end

    return true
  end

  -- Direct file output (no buffering)
  local fs = get_fs()

  -- Output to regular text log file if configured
  if config.output_file then
    local log_path = get_log_file_path()

    -- Ensure log directory exists
    ensure_log_dir()

    -- Check if we need to rotate the log file
    if config.max_file_size and config.max_file_size > 0 then
      local size = fs.file_exists(log_path) and fs.get_file_size(log_path) or 0
      if size >= config.max_file_size then
        rotate_log_files()
      end
    end

    -- Append to the log file
    local success, err = fs.append_file(log_path, formatted_text .. "\n")
    if not success then
      print("Warning: Failed to write to log file: " .. (err or "unknown error"))
    end
  end

  -- Output to JSON log file if configured
  if config.json_file then
    local json_log_path = get_json_log_file_path()

    -- Ensure log directory exists
    ensure_log_dir()

    -- Check if we need to rotate the JSON log file
    if config.max_file_size and config.max_file_size > 0 then
      local size = fs.file_exists(json_log_path) and fs.get_file_size(json_log_path) or 0
      if size >= config.max_file_size then
        rotate_json_log_files()
      end
    end

    -- Append to the JSON log file
    local success, err = fs.append_file(json_log_path, formatted_json .. "\n")
    if not success then
      print("Warning: Failed to write to JSON log file: " .. (err or "unknown error"))
    end
  end

  return true
end

--- Configure the logging module with comprehensive options
--- Sets up the global logging configuration including output destinations,
--- formatting options, log levels, and filtering. This is typically called
--- once at application startup to establish logging behavior.
---
--- @param options? {level?: number|string, file?: string, format?: string, console?: boolean,
---                  max_file_size?: number, include_source?: boolean, include_timestamp?: boolean,
---                  include_level?: boolean, include_colors?: boolean, colors?: table<string, string>,
---                  module_levels?: table<string, number>, module_filter?: string|string[],
---                  silent?: boolean, buffer_size?: number, json_logs?: boolean} Configuration options
--- @return logging The logging module for method chaining
---
--- @usage
--- -- Configure basic logging
--- logging.configure({
---   level = logging.DEBUG,        -- Set global log level
---   console = true,               -- Enable console output
---   file = "logs/application.log" -- Also log to file
--- })
---
--- -- Advanced configuration
--- logging.configure({
---   level = "DEBUG",              -- Level as string
---   include_colors = true,        -- Enable colored output
---   include_source = true,        -- Include source file and line
---   module_levels = {             -- Module-specific levels
---     Database = logging.INFO,
---     Network = logging.DEBUG
---   },
---   module_filter = {"UI*", "Network"}, -- Only log from these modules
---   json_logs = true              -- Also output structured JSON logs
--- })
function M.configure(options)
  options = options or {}

  -- Apply configuration options
  if options.level ~= nil then
    config.global_level = options.level
  end

  if options.module_levels then
    for module, level in pairs(options.module_levels) do
      config.module_levels[module] = level
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

  -- JSON format options
  if options.format ~= nil then
    config.format = options.format
  end

  if options.json_file ~= nil then
    config.json_file = options.json_file
  end

  -- Module filtering options
  if options.module_filter ~= nil then
    config.module_filter = options.module_filter
  end

  if options.module_blacklist ~= nil then
    config.module_blacklist = options.module_blacklist
  end

  -- Buffering options
  if options.buffer_size ~= nil then
    config.buffer_size = options.buffer_size
    -- Reset buffer when size changes
    buffer.entries = {}
    buffer.count = 0
    buffer.last_flush_time = os.time()
  end

  if options.buffer_flush_interval ~= nil then
    config.buffer_flush_interval = options.buffer_flush_interval
  end

  -- Standard metadata
  if options.standard_metadata ~= nil then
    config.standard_metadata = options.standard_metadata
  end

  -- If log file is configured, ensure the directory exists
  if config.output_file or config.json_file then
    ensure_log_dir()
  end

  return M
end

--- Creates a new logger instance for a specific module
--- This is the primary method for obtaining a logger that is bound to a specific module.
--- Each logger instance encapsulates the module name and provides level-specific logging
--- methods as well as utility methods for checking log levels and configuration.
---
--- @param module_name string The name of the module this logger is for
--- @return logger_instance A logger instance bound to the specified module
---
--- @usage
--- -- Create a logger for a specific module
--- local logger = logging.get_logger("Database")
---
--- -- Use the logger with different log levels
--- logger.debug("Connection established", {host = "localhost", port = 5432})
--- logger.info("Query executed successfully")
--- logger.warn("Slow query detected", {execution_time = 1.5, query_id = "SELECT001"})
--- logger.error("Database connection failed", {error_code = 1045})
---
--- -- Check if certain log levels are enabled before expensive operations
--- if logger.is_debug_enabled() then
---   -- Only execute this expensive debug code if debug logging is enabled
---   local stats = generate_detailed_statistics()
---   logger.debug("Performance statistics", stats)
--- end
function M.get_logger(module_name)
  -- First configure the logger from central config
  M.configure_from_config(module_name)

  local logger = {}

  --- Log a fatal level message through this logger
  --- @param message string The message to log
  --- @param params? table Additional context parameters to include
  --- @return boolean Whether the message was logged
  logger.fatal = function(message, params)
    log(M.LEVELS.FATAL, module_name, message, params)
  end

  --- Log an error level message through this logger
  --- @param message string The message to log
  --- @param params? table Additional context parameters to include
  --- @return boolean Whether the message was logged
  logger.error = function(message, params)
    log(M.LEVELS.ERROR, module_name, message, params)
  end

  --- Log a warning level message through this logger
  --- @param message string The message to log
  --- @param params? table Additional context parameters to include
  --- @return boolean Whether the message was logged
  logger.warn = function(message, params)
    log(M.LEVELS.WARN, module_name, message, params)
  end

  --- Log an info level message through this logger
  --- @param message string The message to log
  --- @param params? table Additional context parameters to include
  --- @return boolean Whether the message was logged
  logger.info = function(message, params)
    log(M.LEVELS.INFO, module_name, message, params)
  end

  --- Log a debug level message through this logger
  --- @param message string The message to log
  --- @param params? table Additional context parameters to include
  --- @return boolean Whether the message was logged
  logger.debug = function(message, params)
    log(M.LEVELS.DEBUG, module_name, message, params)
  end

  --- Log a trace level message through this logger
  --- @param message string The message to log
  --- @param params? table Additional context parameters to include
  --- @return boolean Whether the message was logged
  logger.trace = function(message, params)
    log(M.LEVELS.TRACE, module_name, message, params)
  end

  --- Log a verbose level message through this logger (for backward compatibility)
  --- @param message string The message to log
  --- @param params? table Additional context parameters to include
  --- @return boolean Whether the message was logged
  logger.verbose = function(message, params)
    log(M.LEVELS.VERBOSE, module_name, message, params)
  end

  --- Log a message with a specific level through this logger
  --- @param level number The log level to use
  --- @param message string The message to log
  --- @param params? table Additional context parameters to include
  --- @return boolean Whether the message was logged
  logger.log = function(level, message, params)
    log(level, module_name, message, params)
  end

  --- Check if a message at the specified level would be logged
  --- @param level string|number The log level to check (can be name or number)
  --- @return boolean Whether logging is enabled for this level and module
  logger.would_log = function(level)
    if type(level) == "string" then
      local level_name = level:upper()
      for k, v in pairs(M.LEVELS) do
        if k == level_name then
          return is_enabled(v, module_name)
        end
      end
      return false
    elseif type(level) == "number" then
      return is_enabled(level, module_name)
    else
      return false
    end
  end

  --- Check if debug level logging is enabled for this module
  --- @return boolean Whether debug logging is enabled
  logger.is_debug_enabled = function()
    return is_enabled(M.LEVELS.DEBUG, module_name)
  end

  --- Check if trace level logging is enabled for this module
  --- @return boolean Whether trace logging is enabled
  logger.is_trace_enabled = function()
    return is_enabled(M.LEVELS.TRACE, module_name)
  end

  --- Check if verbose level logging is enabled for this module (for backward compatibility)
  --- @return boolean Whether verbose logging is enabled
  logger.is_verbose_enabled = function()
    return is_enabled(M.LEVELS.VERBOSE, module_name)
  end

  --- Get the current log level for this module
  --- @return number The current log level
  logger.get_level = function()
    if config.module_levels[module_name] then
      return config.module_levels[module_name]
    end
    return config.global_level
  end

  return logger
end

--- Get a configured logger instance for a module, automatically applying configuration
--- This helper function creates a logger for the specified module and automatically
--- applies any relevant configuration from .firmo-config.lua. This ensures consistent
--- logging behavior across all modules.
---
--- @param module_name string The name of the module this logger is for
--- @return logger_instance A configured logger instance bound to the specified module
---
--- @usage
--- -- Get a configured logger for a module
--- local logger = logging.get_configured_logger("Database")
---
--- -- Logger is already configured with correct level and settings
--- logger.info("Connection established")
--- logger.debug("Query details") -- Will respect configured level
function M.get_configured_logger(module_name)
  -- Simple alias to get_logger which now does configuration automatically
  return M.get_logger(module_name)
end

--- Direct module-level logging functions
--- These functions provide a convenient way to log messages without
--- needing to create a logger instance first. They're useful for global
--- logging or for quick/temporary logs.
--- Log a fatal level message globally without module association
--- Fatal messages indicate a critical error that prevents the application
--- from continuing operation. Fatal logs are always recorded regardless of
--- log level settings.
---
--- @param message string The message to log
--- @param params? table Additional context parameters to include
--- @return boolean Whether the message was logged
---
--- @usage
--- logging.fatal("Application initialization failed", {error_code = 500})
function M.fatal(message, params)
  log(M.LEVELS.FATAL, nil, message, params)
end

--- Log an error level message globally without module association
--- Error messages indicate a serious problem that prevents normal operation
--- of a component or subsystem, but may not crash the entire application.
---
--- @param message string The message to log
--- @param params? table Additional context parameters to include
--- @return boolean Whether the message was logged
---
--- @usage
--- logging.error("Failed to open configuration file", {
---   file_path = "/etc/app/config.json",
---   error = "Permission denied"
--- })
function M.error(message, params)
  log(M.LEVELS.ERROR, nil, message, params)
end

--- Log a warning level message globally without module association
--- Warning messages indicate potential issues or unexpected states that
--- don't prevent normal operation but may lead to problems in the future.
---
--- @param message string The message to log
--- @param params? table Additional context parameters to include
--- @return boolean Whether the message was logged
---
--- @usage
--- logging.warn("Configuration using default values", {
---   reason = "Config file not found",
---   config_path = "/etc/app/config.json"
--- })
function M.warn(message, params)
  log(M.LEVELS.WARN, nil, message, params)
end

--- Log an info level message globally without module association
--- Info messages provide normal operational information about the application's
--- state and significant events during normal execution.
---
--- @param message string The message to log
--- @param params? table Additional context parameters to include
--- @return boolean Whether the message was logged
---
--- @usage
--- logging.info("Application started successfully", {
---   version = "1.2.3",
---   environment = "production"
--- })
function M.info(message, params)
  log(M.LEVELS.INFO, nil, message, params)
end

--- Log a debug level message globally without module association
--- Debug messages provide detailed information useful during development
--- and troubleshooting, but typically too verbose for production use.
---
--- @param message string The message to log
--- @param params? table Additional context parameters to include
--- @return boolean Whether the message was logged
---
--- @usage
--- logging.debug("Processing user request", {
---   user_id = 12345,
---   request_path = "/api/data",
---   request_method = "GET"
--- })
function M.debug(message, params)
  log(M.LEVELS.DEBUG, nil, message, params)
end

--- Log a trace level message globally without module association
--- Trace messages provide highly detailed diagnostic information, typically
--- used for step-by-step tracing of program execution or algorithm internals.
---
--- @param message string The message to log
--- @param params? table Additional context parameters to include
--- @return boolean Whether the message was logged
---
--- @usage
--- logging.trace("Function enter", {
---   function_name = "process_data",
---   arguments = {id = 123, options = {validate = true}}
--- })
function M.trace(message, params)
  log(M.LEVELS.TRACE, nil, message, params)
end

--- Log a verbose level message globally without module association (for backward compatibility)
--- The verbose level is an alias for TRACE level in this implementation,
--- maintained for backward compatibility with older code.
---
--- @param message string The message to log
--- @param params? table Additional context parameters to include
--- @return boolean Whether the message was logged
---
--- @usage
--- logging.verbose("Detailed execution information", {
---   context = "initialization",
---   modules_loaded = {"core", "ui", "network"}
--- })
function M.verbose(message, params)
  log(M.LEVELS.VERBOSE, nil, message, params)
end

--- Flush buffered logs to output
---@return table The logging module for chaining
function M.flush()
  flush_buffer()
  return M
end

--- Check if a log at the specified level would be output for a given module
--- This function checks if a log with the specified level for the given module
--- would actually be output based on current level settings, module filters,
--- and blacklist. It's useful for avoiding expensive log preparation when
--- the message would be filtered out anyway.
---
--- @param level string|number The log level to check (can be level name or number)
--- @param module_name? string The module name to check (optional)
--- @return boolean Whether logging is enabled for this level and module
---
--- @usage
--- -- Check before executing expensive log preparation
--- if logging.would_log("DEBUG", "Database") then
---   -- Only compute expensive diagnostic info if it will actually be logged
---   local stats = calculate_detailed_database_statistics()
---   logging.debug("Database statistics", stats)
--- end
---
--- -- Check using numeric level
--- if logging.would_log(logging.LEVELS.TRACE, "Network") then
---   logging.trace("Network packet details", capture_packet_details())
--- end
function M.would_log(level, module_name)
  if type(level) == "string" then
    local level_name = level:upper()
    for k, v in pairs(M.LEVELS) do
      if k == level_name then
        return is_enabled(v, module_name)
      end
    end
    return false
  elseif type(level) == "number" then
    return is_enabled(level, module_name)
  else
    return false
  end
end

--- Temporarily change log level for a module while executing a function
--- This function allows you to temporarily override a module's log level
--- while executing a function, then automatically restore the original
--- level afterward. This is useful for diagnostics or for operations
--- that need more detailed logging temporarily.
---
--- @param module_name string The module name to change the level for
--- @param level string|number The log level to use temporarily
--- @param func function The function to execute with the temporary log level
--- @return any The result from the executed function
--- @error Any error raised by the executed function
---
--- @usage
--- -- Temporarily increase log level for a section of code
--- local result = logging.with_level("Database", "DEBUG", function()
---   -- This code block will have Database logging at DEBUG level
---   db.execute_query("SELECT * FROM users")
---   return "query completed"
--- end)
---
--- -- The module's original log level is automatically restored after
--- -- the function completes, even if the function raises an error
---
--- -- Can also use with numeric levels
--- logging.with_level("Network", logging.LEVELS.TRACE, function()
---   network.send_request("https://api.example.com/data")
--- end)
function M.with_level(module_name, level, func)
  local original_level = config.module_levels[module_name]

  -- Set temporary level
  if type(level) == "string" then
    local level_name = level:upper()
    for k, v in pairs(M.LEVELS) do
      if k == level_name then
        M.set_module_level(module_name, v)
        break
      end
    end
  else
    M.set_module_level(module_name, level)
  end

  -- Run the function
  local success, result = pcall(func)

  -- Restore original level
  if original_level then
    M.set_module_level(module_name, original_level)
  else
    config.module_levels[module_name] = nil
  end

  -- Handle errors
  if not success then
    error(result)
  end

  return result
end

--- Set the log level for a specific module
--- This function configures the log level for a specific module, allowing
--- different modules to have different verbosity levels. Module-specific
--- levels override the global log level.
---
--- @param module_name string The name of the module to configure
--- @param level number The log level to set for the module
--- @return table The logging module for chaining
---
--- @usage
--- -- Set the Database module to show only ERROR and above
--- logging.set_module_level("Database", logging.LEVELS.ERROR)
---
--- -- Set the AuthService to show detailed DEBUG logs
--- logging.set_module_level("AuthService", logging.LEVELS.DEBUG)
---
--- -- Use method chaining to configure multiple modules
--- logging.set_module_level("API", logging.LEVELS.WARN)
---   .set_module_level("UI", logging.LEVELS.INFO)
---   .set_module_level("Storage", logging.LEVELS.ERROR)
function M.set_module_level(module_name, level)
  local numeric_level = normalize_log_level(level)
  if numeric_level then
    config.module_levels[module_name] = numeric_level
  end
  return M
end

--- Set the global log level for all modules
--- This function sets the default log level that applies to all modules
--- that don't have a specific level set via set_module_level(). This
--- provides a simple way to control overall logging verbosity.
---
--- @param level number The log level to set globally
--- @return table The logging module for chaining
---
--- @usage
--- -- Reduce global verbosity to just warnings and errors
--- logging.set_level(logging.LEVELS.WARN)
---
--- -- Show all logs including debug
--- logging.set_level(logging.LEVELS.DEBUG)
---
--- -- In production, show only errors
--- if env == "production" then
---   logging.set_level(logging.LEVELS.ERROR)
--- else
---   logging.set_level(logging.LEVELS.INFO)
--- end
function M.set_level(level)
  config.global_level = level
  return M
end

--- Configure logging from central configuration
--- This function loads logging configuration from the central configuration system,
--- applying global and module-specific settings. It automatically retrieves the
--- appropriate configuration based on the module name provided.
---
--- @param module_name string The module name to configure logging for
--- @return number The configured log level
---
--- @usage
--- -- Configure logging from central config
--- local level = logging.configure_from_config("Database")
--- print("Configured log level from central config: " .. level)
---
--- -- Use with get_logger
--- local logger = logging.get_logger("API")
--- -- logger is already configured from central_config
function M.configure_from_config(module_name)
  -- First try to load the global config
  local log_level = M.LEVELS.INFO -- default level
  local config_obj

  -- Try to load central_config module and get config
  local success, central_config = pcall(require, "lib.core.central_config")
  if success and central_config then
    config_obj = central_config.get()

    -- Check for logging configuration
    if config_obj and config_obj.logging then
      -- Global logging configuration - must be set first
      if config_obj.logging.level then
        local numeric_level = normalize_log_level(config_obj.logging.level)
        if numeric_level then
          config.global_level = numeric_level
          log_level = numeric_level
        end
      -- If no explicit level, check debug/verbose flags
      else
        if config_obj.debug then
          log_level = M.LEVELS.DEBUG
          config.global_level = M.LEVELS.DEBUG
        elseif config_obj.verbose then
          log_level = M.LEVELS.VERBOSE
          config.global_level = M.LEVELS.VERBOSE
        end
      end

      -- Module-specific log levels
      if config_obj.logging.modules then
        -- Process all module levels to ensure they're normalized
        for mod, level in pairs(config_obj.logging.modules) do
          local numeric_level = normalize_log_level(level)
          if numeric_level then
            config.module_levels[mod] = numeric_level
            -- If this is our module, set its level
            if mod == module_name then
              log_level = numeric_level
            end
          end
        end
      end

      -- Configure logging output options
      if config_obj.logging.output_file then
        config.output_file = config_obj.logging.output_file
      end

      if config_obj.logging.log_dir then
        config.log_dir = config_obj.logging.log_dir
      end

      if config_obj.logging.timestamps ~= nil then
        config.timestamps = config_obj.logging.timestamps
      end

      if config_obj.logging.use_colors ~= nil then
        config.use_colors = config_obj.logging.use_colors
      end

      -- Configure log rotation options
      if config_obj.logging.max_file_size then
        config.max_file_size = config_obj.logging.max_file_size
      end

      if config_obj.logging.max_log_files then
        config.max_log_files = config_obj.logging.max_log_files
      end

      if config_obj.logging.date_pattern then
        config.date_pattern = config_obj.logging.date_pattern
      end

      -- JSON format options
      if config_obj.logging.format then
        config.format = config_obj.logging.format
      end

      if config_obj.logging.json_file then
        config.json_file = config_obj.logging.json_file
      end

      -- Module filtering options
      if config_obj.logging.module_filter then
        config.module_filter = config_obj.logging.module_filter
      end

      if config_obj.logging.module_blacklist then
        config.module_blacklist = config_obj.logging.module_blacklist
      end

      -- Ensure log directory exists if output file is configured
      if config.output_file or config.json_file then
        ensure_log_dir()
      end
    end
  end

  -- Apply the log level if a module name was provided
  if module_name then
    M.set_module_level(module_name, log_level)
  end
  return log_level
end

--- Configure module log level based on debug/verbose settings from an options object
--- This function provides a convenient way to configure a module's log level
--- based on standard debug/verbose flags commonly used in command-line options
--- or configuration objects.
---
--- @param module_name string The module name to configure
--- @param options table The options object with debug/verbose flags
--- @return number The configured log level
---
--- @usage
--- -- Configure log level from command-line args
--- local args = {debug = true, verbose = false}
--- logging.configure_from_options("MyModule", args)
---
--- -- Configure based on options object
--- local options = {debug = false, verbose = true, other_option = "value"}
--- local level = logging.configure_from_options("DataProcessor", options)
--- print("Configured log level: " .. level)  -- Will be VERBOSE level
function M.configure_from_options(module_name, options)
  if not module_name or not options then
    return M.LEVELS.INFO -- default if missing arguments
  end

  local log_level = M.LEVELS.INFO -- default level

  -- Check explicit level setting first
  if options.level then
    local numeric_level = normalize_log_level(options.level)
    if numeric_level then
      log_level = numeric_level
    end
  -- Otherwise check debug/verbose flags
  else
    if options.debug then
      log_level = M.LEVELS.DEBUG
    elseif options.verbose then
      log_level = M.LEVELS.VERBOSE
    end
  end

  -- Set the module's log level
  M.set_module_level(module_name, log_level)

  return log_level
end

--- Add a module pattern to the module filter whitelist
--- This function adds a module name pattern to the filter, which controls
--- which modules' logs will be shown. When a filter is active, only logs
--- from modules matching the filter will be displayed. This is useful for
--- focusing on specific components during debugging.
---
--- @param module_pattern string The module pattern to add to the filter (supports "*" wildcard suffix)
--- @return table The logging module for chaining
---
--- @usage
--- -- Show logs only from the Database module
--- logging.filter_module("Database")
---
--- -- Show logs from all UI-related modules
--- logging.filter_module("UI*")
---
--- -- Add multiple filters
--- logging.filter_module("Network")
---   .filter_module("Security*")
function M.filter_module(module_pattern)
  if not config.module_filter then
    config.module_filter = {}
  end

  if type(config.module_filter) == "string" then
    -- Convert to table if currently a string
    config.module_filter = { config.module_filter }
  end

  -- Add to filter if not already present
  for _, pattern in ipairs(config.module_filter) do
    if pattern == module_pattern then
      return M -- Already filtered
    end
  end

  table.insert(config.module_filter, module_pattern)
  return M
end

--- Clear all module filters, allowing logs from all modules to be shown
--- This function removes any previously set module filters, effectively
--- enabling logs from all modules (subject to log level and blacklist settings).
---
--- @return table The logging module for chaining
---
--- @usage
--- -- First filter to specific modules
--- logging.filter_module("Database").filter_module("Auth")
---
--- -- Later, remove all filters to see all modules again
--- logging.clear_module_filters()
function M.clear_module_filters()
  config.module_filter = nil
  return M
end

--- Add a module pattern to the blacklist to prevent its logs from being shown
--- The blacklist takes precedence over the whitelist filter. Modules matching
--- any pattern in the blacklist will never log, regardless of log level or
--- filter settings. This is useful for suppressing noisy modules.
---
--- @param module_pattern string The module pattern to blacklist (supports "*" wildcard suffix)
--- @return table The logging module for chaining
---
--- @usage
--- -- Prevent logs from a noisy HTTP client module
--- logging.blacklist_module("HTTPClient")
---
--- -- Silence all analytics-related modules
--- logging.blacklist_module("Analytics*")
function M.blacklist_module(module_pattern)
  -- Make sure module_blacklist is initialized
  if not config.module_blacklist then
    config.module_blacklist = {}
  end

  -- Add to blacklist if not already present
  for _, pattern in ipairs(config.module_blacklist) do
    if pattern == module_pattern then
      return M -- Already blacklisted
    end
  end

  table.insert(config.module_blacklist, module_pattern)
  return M
end

--- Remove a module pattern from the blacklist, allowing its logs to be shown again
--- This function removes a specific pattern from the blacklist. If the pattern
--- was previously added with blacklist_module(), it will be removed and logs
--- from matching modules will be shown again (subject to normal filtering rules).
---
--- @param module_pattern string The module pattern to remove from the blacklist
--- @return table The logging module for chaining
---
--- @usage
--- -- First blacklist a module
--- logging.blacklist_module("Metrics")
---
--- -- Later, remove it from the blacklist when you need to see its logs
--- logging.remove_from_blacklist("Metrics")
function M.remove_from_blacklist(module_pattern)
  if config.module_blacklist then
    for i, pattern in ipairs(config.module_blacklist) do
      if pattern == module_pattern then
        table.remove(config.module_blacklist, i)
        return M
      end
    end
  end
  return M
end

--- Clear all module blacklist entries, allowing all modules to log again
--- This function removes all patterns from the blacklist, effectively enabling
--- logs from all previously blacklisted modules (subject to normal filter and
--- log level settings).
---
--- @return table The logging module for chaining
---
--- @usage
--- -- Set up multiple blacklist entries
--- logging.blacklist_module("Metrics")
---   .blacklist_module("Statistics*")
---   .blacklist_module("Analytics")
---
--- -- Later, clear the entire blacklist when you need to see everything
--- logging.clear_blacklist()
function M.clear_blacklist()
  config.module_blacklist = {}
  return M
end

--- Get the current logging configuration for debugging or diagnostics
--- This function returns a copy of the current logging configuration,
--- allowing inspection of all settings in effect. This is useful for
--- diagnosing logging behavior or understanding the current system state.
---
--- @return table A copy of the current configuration settings
---
--- @usage
--- -- Check current logging configuration
--- local config = logging.get_config()
--- print("Current log level: " .. config.global_level)
--- print("Log to file: " .. (config.output_file or "disabled"))
---
--- -- Check module-specific settings
--- for module, level in pairs(config.module_levels) do
---   print("Module " .. module .. " level: " .. level)
--- end
function M.get_config()
  -- Return a copy to prevent modification
  local copy = {}
  for k, v in pairs(config) do
    copy[k] = v
  end
  return copy
end

--- Log a debug message (compatibility with existing code)
--- This is a legacy compatibility function for code that uses the older
--- log_debug() pattern instead of the current debug() pattern.
---
--- @param message string The message to log
--- @param module_name? string The optional module name
--- @return boolean Whether the message was logged
---
--- @usage
--- -- Old style logging with module name
--- logging.log_debug("Initializing component", "Startup")
function M.log_debug(message, module_name)
  log(M.LEVELS.DEBUG, module_name, message)
end

--- Log a verbose message (compatibility with existing code)
--- This is a legacy compatibility function for code that uses the older
--- log_verbose() pattern instead of the current verbose() pattern.
---
--- @param message string The message to log
--- @param module_name? string The optional module name
--- @return boolean Whether the message was logged
---
--- @usage
--- -- Old style verbose logging
--- logging.log_verbose("Processing item 42", "DataProcessor")
function M.log_verbose(message, module_name)
  log(M.LEVELS.VERBOSE, module_name, message)
end

--- Get the log search module for searching logs
--- This function provides access to the log search functionality, allowing
--- historical logs to be searched and analyzed. The search module provides
--- pattern-based, level-based, and time-based search capabilities.
---
--- @return table The log search module interface
--- @error If the search module couldn't be loaded
---
--- @usage
--- -- Search for all error logs containing "database"
--- local search = logging.search()
--- local results = search.find("database", {
---   level = logging.ERROR,
---   case_sensitive = false,
---   max_results = 100
--- })
---
--- -- Process search results
--- for _, entry in ipairs(results) do
---   print(entry.timestamp, entry.module, entry.message)
--- end
function M.search()
  local search = get_search()
  if not search then
    error("Log search module not available")
  end
  return search
end

--- Get the log export module for exporting logs to different formats
--- This function provides access to the log export functionality, which can
--- convert logs to various formats like CSV, JSON, or custom formats for
--- integration with external systems.
---
--- @return table The log export module interface
--- @error If the export module couldn't be loaded
---
--- @usage
--- -- Export today's logs to CSV
--- local export = logging.export()
--- local csv_content = export.to_csv({
---   start_time = os.time() - 86400,  -- Last 24 hours
---   end_time = os.time(),
---   fields = {"timestamp", "level", "module", "message"}
--- })
---
--- -- Save to file
--- local file = io.open("logs_export.csv", "w")
--- file:write(csv_content)
--- file:close()
function M.export()
  local export = get_export()
  if not export then
    error("Log export module not available")
  end
  return export
end

--- Get the formatter integration module for custom log formatting
--- This function provides access to the formatter integration functionality,
--- which allows custom log formatting patterns and output styles to be defined
--- and used with the logging system.
---
--- @return table The formatter integration module interface
--- @error If the formatter integration module couldn't be loaded
---
--- @usage
--- -- Register a custom formatter
--- local fi = logging.formatter_integration()
--- fi.register("compact", function(entry)
---   return string.format(
---     "%s|%s|%s|%s",
---     entry.timestamp:sub(12),  -- Just the time part
---     entry.level:sub(1,1),     -- First letter of level (E, W, I, D)
---     entry.module or "-",
---     entry.message
---   )
--- end)
---
--- -- Configure logging to use the custom formatter
--- logging.configure({
---   format = "compact"
--- })
function M.formatter_integration()
  local formatter_integration = get_formatter_integration()
  if not formatter_integration then
    error("Formatter integration module not available")
  end
  return formatter_integration
end

--- Create a buffered logger for high-volume logging scenarios
--- This function creates a specialized logger instance that buffers log messages
--- in memory and flushes them to disk periodically or when the buffer fills up.
--- This is useful for high-throughput logging scenarios where individual disk I/O
--- operations for each log message would be too expensive.
---
--- @param module_name string The module name for the logger
--- @param options? {buffer_size?: number, flush_interval?: number, output_file?: string} Options for the buffered logger
--- @return logger_instance The buffered logger instance with flush capability
---
--- @usage
--- -- Create a buffered logger for high-volume metrics
--- local metrics_logger = logging.create_buffered_logger("Metrics", {
---   buffer_size = 1000,       -- Buffer up to 1000 messages
---   flush_interval = 10,      -- Flush every 10 seconds
---   output_file = "metrics.log"  -- Write to specific file
--- })
---
--- -- Use like a normal logger
--- metrics_logger.info("Request processed", {
---   duration_ms = 42,
---   endpoint = "/api/data",
---   status = 200
--- })
---
--- -- Force an immediate flush when needed
--- metrics_logger.flush()
function M.create_buffered_logger(module_name, options)
  options = options or {}

  -- Apply buffering configuration
  local buffer_size = options.buffer_size or 100
  local flush_interval = options.flush_interval or 5 -- seconds

  -- Configure a buffered logger
  local buffered_config = {
    buffer_size = buffer_size,
    buffer_flush_interval = flush_interval,
  }

  -- If output_file specified, use it
  if options.output_file then
    buffered_config.output_file = options.output_file
  end

  -- Apply the configuration
  M.configure(buffered_config)

  -- Create a logger with the specified module name
  local logger = M.get_logger(module_name)

  -- Add flush method to this logger instance
  logger.flush = function()
    M.flush()
    return logger
  end

  -- Add auto-flush on shutdown
  local mt = getmetatable(logger) or {}
  mt.__gc = function()
    logger.flush()
  end
  setmetatable(logger, mt)

  return logger
end

return M
