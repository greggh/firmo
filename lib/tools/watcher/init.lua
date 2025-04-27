--- File Watcher Module for Firmo
---
--- Monitors filesystem for changes based on patterns and provides change
--- notifications. Integrates with central configuration.
---
--- @module lib.tools.watcher
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class watcher_module The public API for the file watcher module.
---@field _VERSION string Module version.
---@field configure fun(options?: { check_interval?: number, watch_patterns?: string[], default_directory?: string, debug?: boolean, verbose?: boolean }): watcher_module Configures the watcher. Returns self.
---@field init fun(directories?: string|string[], exclude_patterns?: string[]): boolean|nil, table? Initializes the watcher by scanning files. Returns `success, error?`. @throws table If validation fails.
---@field check_for_changes fun(): string[]|nil, table? Checks for modified/new/deleted files. Returns list of changed files or `nil, error?`. @throws table If validation fails or critical error occurs.
---@field add_patterns fun(patterns: string[]): watcher_module|nil, table? Adds patterns to the `watch_patterns` list. Returns self or `nil, error?`. @throws table If validation fails.
---@field set_check_interval fun(interval: number): watcher_module|nil, table? Sets the file check interval. Returns self or `nil, error?`. @throws table If validation fails.
---@field reset fun(): watcher_module|nil, table? Resets local configuration to defaults. Returns self or `nil, error?`. @throws table If runtime error occurs.
---@field full_reset fun(): watcher_module|nil, table? Resets local and central configuration. Returns self or `nil, error?`. @throws table If runtime error occurs.
---@field debug_config fun(): table Returns a table with current configuration and state for debugging.
---@field on_change fun(...) [Not Implemented] Register a callback for when files change.
---@field watch fun(...) [Not Implemented] Start watching for changes with continuous polling.
---@field stop fun(...) [Not Implemented] Stop watching for changes.
---@field get_watched_files fun(...) [Not Implemented] Get currently watched files with metadata.
---@field add_directory fun(...) [Not Implemented] Add a directory to watch.
---@field add_file fun(...) [Not Implemented] Add a specific file to watch.
---@field is_watching fun(...) [Not Implemented] Check if the watcher is currently active.

local watcher = {}
watcher._VERSION = "1.0.0"

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
    return logging.get_logger("watcher")
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

-- Default configuration
local DEFAULT_CONFIG = {
  check_interval = 1.0, -- seconds
  watch_patterns = {
    "%.lua$", -- Lua source files
    "%.txt$", -- Text files
    "%.json$", -- JSON files
  },
  default_directory = ".",
  debug = false,
  verbose = false,
}

-- Current configuration
local config = {
  check_interval = DEFAULT_CONFIG.check_interval,
  watch_patterns = {},
  default_directory = DEFAULT_CONFIG.default_directory,
  debug = DEFAULT_CONFIG.debug,
  verbose = DEFAULT_CONFIG.verbose,
}

-- Copy default watch patterns
for _, pattern in ipairs(DEFAULT_CONFIG.watch_patterns) do
  table.insert(config.watch_patterns, pattern)
end

-- Variables to track file state
local file_timestamps = {}
local last_check_time = 0

local central_config = try_require("lib.core.central_config")

-- Register this module with central_config
central_config.register_module("watcher", {
  -- Schema
  field_types = {
    check_interval = "number",
    watch_patterns = "table",
    default_directory = "string",
    debug = "boolean",
    verbose = "boolean",
  },
  field_ranges = {
    check_interval = { min = 0.1, max = 60 },
  },
}, DEFAULT_CONFIG)

--- Registers a listener with central_config to update local config cache when watcher settings change.
---@return boolean success `true` if the listener was registered, `false` otherwise.
---@private
local function register_change_listener()
  -- Register change listener for watcher configuration
  central_config.on_change("watcher", function(path, old_value, new_value)
    get_logger().debug("Configuration change detected", {
      path = path,
      changed_by = "central_config",
    })

    -- Update local configuration from central_config
    local watcher_config = central_config.get("watcher")
    if watcher_config then
      -- Update check_interval
      if watcher_config.check_interval ~= nil and watcher_config.check_interval ~= config.check_interval then
        config.check_interval = watcher_config.check_interval
        get_logger().debug("Updated check_interval from central_config", {
          check_interval = config.check_interval,
        })
      end

      -- Update watch_patterns
      if watcher_config.watch_patterns ~= nil then
        -- Clear existing patterns and copy new ones
        config.watch_patterns = {}
        for _, pattern in ipairs(watcher_config.watch_patterns) do
          table.insert(config.watch_patterns, pattern)
        end
        get_logger().debug("Updated watch_patterns from central_config", {
          pattern_count = #config.watch_patterns,
        })
      end

      -- Update default_directory
      if watcher_config.default_directory ~= nil and watcher_config.default_directory ~= config.default_directory then
        config.default_directory = watcher_config.default_directory
        get_logger().debug("Updated default_directory from central_config", {
          default_directory = config.default_directory,
        })
      end

      -- Update debug setting
      if watcher_config.debug ~= nil and watcher_config.debug ~= config.debug then
        config.debug = watcher_config.debug
        get_logger().debug("Updated debug setting from central_config", {
          debug = config.debug,
        })
      end

      -- Update verbose setting
      if watcher_config.verbose ~= nil and watcher_config.verbose ~= config.verbose then
        config.verbose = watcher_config.verbose
        get_logger().debug("Updated verbose setting from central_config", {
          verbose = config.verbose,
        })
      end

      -- Update logging configuration
      -- Update logging configuration
      local log_level = config.debug and get_logging().LEVELS.DEBUG
        or (config.verbose and get_logging().LEVELS.VERBOSE or get_logging().LEVELS.INFO)
      get_logging().set_module_level("watcher", log_level)
      get_logger().debug("Applied configuration changes from central_config")
    end
  end)

  get_logger().debug("Registered change listener for central configuration")
  return true
end

--- Configures the watcher module settings.
--- Merges provided `options` with defaults, potentially loading from or saving to central config.
---@param options? { check_interval?: number, default_directory?: string, debug?: boolean, verbose?: boolean, watch_patterns?: string[] } Configuration options table.
---@return watcher_module self The module instance (`watcher`) for chaining.
function watcher.configure(options)
  options = options or {}

  get_logger().debug("Configuring watcher module", {
    options = options,
  })

  -- Get existing central config values
  local watcher_config = central_config.get("watcher")

  -- Apply central configuration (with defaults as fallback)
  if watcher_config then
    get_logger().debug("Using central_config values for initialization", {
      check_interval = watcher_config.check_interval,
      has_watch_patterns = watcher_config.watch_patterns ~= nil,
    })

    -- Apply check_interval
    config.check_interval = watcher_config.check_interval ~= nil and watcher_config.check_interval
      or DEFAULT_CONFIG.check_interval

    -- Apply default_directory
    config.default_directory = watcher_config.default_directory ~= nil and watcher_config.default_directory
      or DEFAULT_CONFIG.default_directory

    -- Apply debug and verbose settings
    config.debug = watcher_config.debug ~= nil and watcher_config.debug or DEFAULT_CONFIG.debug

    config.verbose = watcher_config.verbose ~= nil and watcher_config.verbose or DEFAULT_CONFIG.verbose

    -- Apply watch_patterns if available
    if watcher_config.watch_patterns then
      config.watch_patterns = {}
      for _, pattern in ipairs(watcher_config.watch_patterns) do
        table.insert(config.watch_patterns, pattern)
      end
    else
      -- Reset to defaults
      config.watch_patterns = {}
      for _, pattern in ipairs(DEFAULT_CONFIG.watch_patterns) do
        table.insert(config.watch_patterns, pattern)
      end
    end
  else
    get_logger().debug("No central_config values found, using defaults")
    -- Reset to defaults
    config.check_interval = DEFAULT_CONFIG.check_interval
    config.default_directory = DEFAULT_CONFIG.default_directory
    config.debug = DEFAULT_CONFIG.debug
    config.verbose = DEFAULT_CONFIG.verbose

    config.watch_patterns = {}
    for _, pattern in ipairs(DEFAULT_CONFIG.watch_patterns) do
      table.insert(config.watch_patterns, pattern)
    end
  end

  -- Register change listener if not already done
  register_change_listener()

  -- Apply user options (highest priority) and update central config
  if options.check_interval ~= nil then
    config.check_interval = options.check_interval

    -- Update central_config if available
    central_config.set("watcher.check_interval", options.check_interval)
  end

  if options.default_directory ~= nil then
    config.default_directory = options.default_directory

    -- Update central_config if available
    central_config.set("watcher.default_directory", options.default_directory)
  end

  if options.debug ~= nil then
    config.debug = options.debug

    -- Update central_config if available
    central_config.set("watcher.debug", options.debug)
  end

  if options.verbose ~= nil then
    config.verbose = options.verbose

    -- Update central_config if available
    central_config.set("watcher.verbose", options.verbose)
  end

  if options.watch_patterns ~= nil then
    -- Replace watch patterns
    config.watch_patterns = {}
    for _, pattern in ipairs(options.watch_patterns) do
      table.insert(config.watch_patterns, pattern)
    end

    -- Update central_config if available
    central_config.set("watcher.watch_patterns", options.watch_patterns)
  end

  -- Configure logging based on debug/verbose settings
  local log_level = config.debug and "DEBUG" or (config.verbose and "VERBOSE" or "INFO")
  get_logging().set_module_level("watcher", log_level)

  get_logger().debug("Watcher module configuration complete", {
    check_interval = config.check_interval,
    watch_patterns_count = #config.watch_patterns,
    default_directory = config.default_directory,
    debug = config.debug,
    verbose = config.verbose,
    using_central_config = central_config ~= nil,
  })

  return watcher
end

-- Initialize the module
watcher.configure()

--- Checks if a filename matches any of the configured `watch_patterns`.
---@param filename string The filename to check.
---@return boolean should_watch `true` if the filename matches any pattern, `false` otherwise.
---@throws table If validation fails (e.g., filename is nil) via `error_handler`.
---@private
local function should_watch_file(filename)
  -- Validate input
  if not filename then
    local err = get_error_handler().validation_error("Missing required filename parameter", {
      operation = "should_watch_file",
      module = "watcher",
    })
    get_logger().warn("Invalid parameter", {
      operation = "should_watch_file",
      error = get_error_handler().format_error(err),
    })
    return false
  end

  -- Ensure filename is a string
  if type(filename) ~= "string" then
    local err = get_error_handler().validation_error("Filename must be a string", {
      operation = "should_watch_file",
      provided_type = type(filename),
      module = "watcher",
    })
    get_logger().warn("Invalid parameter type", {
      operation = "should_watch_file",
      error = get_error_handler().format_error(err),
    })
    return false
  end

  -- Check if patterns is valid
  if not config.watch_patterns or type(config.watch_patterns) ~= "table" then
    local err = get_error_handler().runtime_error("Invalid watch patterns configuration", {
      operation = "should_watch_file",
      module = "watcher",
    })
    get_logger().warn("Invalid configuration", {
      operation = "should_watch_file",
      error = get_error_handler().format_error(err),
    })
    return false
  end

  -- Try to match each pattern
  local success, result, err = get_error_handler().try(function()
    for _, pattern in ipairs(config.watch_patterns) do
      if type(pattern) == "string" and filename:match(pattern) then
        get_logger().debug("File matches watch pattern", {
          filename = filename,
          pattern = pattern,
        })
        return true
      end
    end
    get_logger().debug("File does not match watch patterns", { filename = filename })
    return false
  end)

  if not success then
    get_logger().warn("Pattern matching failed", {
      filename = filename,
      error = get_error_handler().format_error(result),
    })
    return false
  end

  return result
end

--- Gets the last modification time of a file using `get_fs().get_modified_time`.
--- Handles errors gracefully.
---@param path string The file path to check.
---@return number|nil mtime Modification time as a Unix timestamp, or `nil` on error.
---@throws table If `path` validation fails (e.g., nil) via `error_handler`.
---@private
local function get_file_mtime(path)
  -- Validate input
  if not path then
    local err = get_error_handler().validation_error("Missing required path parameter", {
      operation = "get_file_mtime",
      module = "watcher",
    })
    get_logger().warn("Invalid parameter", {
      operation = "get_file_mtime",
      error = get_error_handler().format_error(err),
    })
    return nil
  end

  -- Ensure path is a string
  if type(path) ~= "string" then
    local err = get_error_handler().validation_error("Path must be a string", {
      operation = "get_file_mtime",
      provided_type = type(path),
      module = "watcher",
    })
    get_logger().warn("Invalid parameter type", {
      operation = "get_file_mtime",
      error = get_error_handler().format_error(err),
    })
    return nil
  end

  -- Get modification time with error handling
  local mtime, err = get_error_handler().safe_io_operation(
    function()
      return get_fs().get_modified_time(path)
    end,
    path,
    {
      operation = "get_file_mtime",
      module = "watcher",
    }
  )

  if not mtime then
    get_logger().warn("Failed to get modification time", {
      path = path,
      error = err and get_error_handler().format_error(err),
    })
    return nil
  end

  get_logger().debug("File modification time", { path = path, mtime = mtime })
  return mtime
end

--- Initialize the watcher by scanning all files in the given directories
---@param directories? string|string[] Directory path string or array of directory paths to scan initially. Defaults to `config.default_directory`.
---@param exclude_patterns? string[] Array of Lua patterns to exclude files/directories during the initial scan.
---@return boolean|nil success `true` if initialization succeeded (files scanned), `nil` if a critical error occurred (e.g., all directories failed).
---@return table? error Error object from `error_handler` if operation failed critically.
---@throws table If parameter validation fails via `error_handler`.
function watcher.init(directories, exclude_patterns)
  get_logger().info("Initializing file watcher", {
    directories = directories,
    exclude_pattern_count = exclude_patterns and #exclude_patterns or 0,
  })

  -- Validate directories parameter
  if directories ~= nil and type(directories) ~= "table" and type(directories) ~= "string" then
    local err = get_error_handler().validation_error("Directories must be a string, table, or nil", {
      operation = "watcher.init",
      provided_type = type(directories),
      module = "watcher",
    })
    get_logger().error("Invalid parameter type", {
      operation = "watcher.init",
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  -- Validate exclude_patterns parameter
  if exclude_patterns ~= nil and type(exclude_patterns) ~= "table" then
    local err = get_error_handler().validation_error("Exclude patterns must be a table or nil", {
      operation = "watcher.init",
      provided_type = type(exclude_patterns),
      module = "watcher",
    })
    get_logger().error("Invalid parameter type", {
      operation = "watcher.init",
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  -- Parse and normalize the inputs with proper validation
  local dirs_to_watch
  if type(directories) == "table" then
    dirs_to_watch = directories
  else
    dirs_to_watch = { directories or "." }
  end

  -- Ensure all directory entries are strings
  for i, dir in ipairs(dirs_to_watch) do
    if type(dir) ~= "string" then
      local err = get_error_handler().validation_error("Directory entry must be a string", {
        operation = "watcher.init",
        index = i,
        provided_type = type(dir),
        module = "watcher",
      })
      get_logger().error("Invalid directory entry", {
        operation = "watcher.init",
        error = get_error_handler().format_error(err),
      })
      return nil, err
    end
  end

  -- Use provided exclude patterns or initialize an empty table
  local excl_patterns = exclude_patterns or {}

  -- Reset state
  file_timestamps = {}

  -- Record the initialization time using protected call
  local success, current_time = get_error_handler().try(function()
    return os.time()
  end)

  if not success then
    get_logger().warn("Failed to get system time, using 0 as fallback", {
      error = get_error_handler().format_error(current_time),
    })
    last_check_time = 0
  else
    last_check_time = current_time
  end

  -- Create list of exclusion patterns as functions
  local excludes = {}
  local exclude_success, exclude_result = get_error_handler().try(function()
    for i, pattern in ipairs(excl_patterns) do
      if type(pattern) ~= "string" then
        get_logger().warn("Skipping non-string exclusion pattern", {
          index = i,
          provided_type = type(pattern),
        })
      else
        get_logger().info("Adding exclusion pattern", { pattern = pattern })
        table.insert(excludes, function(path)
          return path:match(pattern)
        end)
      end
    end
    return true
  end)

  if not exclude_success then
    get_logger().warn("Failed to process exclusion patterns", {
      error = get_error_handler().format_error(exclude_result),
    })
    -- Continue with empty excludes as a fallback
    excludes = {}
  end

  -- Track total files for summary statistics
  local total_found = 0
  local total_excluded = 0
  local total_watched = 0
  local dir_error_count = 0

  -- Scan all files in directories
  for _, dir in ipairs(dirs_to_watch) do
    get_logger().info("Watching directory", { directory = dir })

    -- Verify the directory exists before scanning
    local dir_exists, dir_err = get_error_handler().safe_io_operation(
      function()
        return get_fs().directory_exists(dir)
      end,
      dir,
      {
        operation = "watcher.init.directory_check",
        module = "watcher",
      }
    )

    if not dir_exists then
      get_logger().error("Directory does not exist", {
        directory = dir,
        error = dir_err and get_error_handler().format_error(dir_err),
      })
      dir_error_count = dir_error_count + 1
      -- Continue with other directories instead of failing completely
      goto continue
    end

    -- Use filesystem module to scan directory recursively with error handling
    get_logger().debug("Scanning directory recursively", { directory = dir })
    local files, scan_err = get_error_handler().safe_io_operation(
      function()
        return get_fs().scan_directory(dir, true)
      end,
      dir,
      {
        operation = "watcher.init.scan_directory",
        recursive = true,
        module = "watcher",
      }
    )

    if not files then
      get_logger().error("Failed to scan directory", {
        directory = dir,
        error = scan_err and get_error_handler().format_error(scan_err),
      })
      dir_error_count = dir_error_count + 1
      goto continue
    end

    if type(files) ~= "table" then
      get_logger().error("Invalid scan results, expected table", {
        directory = dir,
        result_type = type(files),
      })
      dir_error_count = dir_error_count + 1
      goto continue
    end

    -- Process found files with error boundaries
    local success, result = get_error_handler().try(function()
      local file_count = #files
      local exclude_count = 0
      local watch_count = 0

      for _, path in ipairs(files) do
        -- Skip invalid paths
        if type(path) ~= "string" then
          get_logger().warn("Skipping invalid path", { path_type = type(path) })
          goto next_file
        end

        -- Apply exclusion patterns with protection
        local exclude = false
        local exclude_success, exclude_result = get_error_handler().try(function()
          for _, exclude_func in ipairs(excludes) do
            if exclude_func(path) then
              exclude = true
              exclude_count = exclude_count + 1
              get_logger().debug("Excluding file", { path = path })
              break
            end
          end
          return exclude
        end)

        if not exclude_success then
          get_logger().warn("Error applying exclusion patterns", {
            path = path,
            error = get_error_handler().format_error(exclude_result),
          })
          -- Default to not excluding on error
          exclude = false
        else
          exclude = exclude_result -- Use the result from the try block
        end

        -- If not excluded and matches patterns to watch, add to timestamp list
        if not exclude then
          local should_watch = should_watch_file(path)
          if should_watch then
            local mtime = get_file_mtime(path)
            if mtime then
              file_timestamps[path] = mtime
              watch_count = watch_count + 1
            end
          end
        end

        ::next_file::
      end

      get_logger().info("Directory scan results", {
        directory = dir,
        files_found = file_count,
        files_excluded = exclude_count,
        files_watched = watch_count,
      })

      -- Update global counters
      total_found = total_found + file_count
      total_excluded = total_excluded + exclude_count
      total_watched = total_watched + watch_count

      return true
    end)

    if not success then
      get_logger().error("Failed to process files in directory", {
        directory = dir,
        error = get_error_handler().format_error(result),
      })
      dir_error_count = dir_error_count + 1
    end

    ::continue::
  end

  -- Count total watched files with error handling
  local file_count = 0
  local count_success, count_result = get_error_handler().try(function()
    for _ in pairs(file_timestamps) do
      file_count = file_count + 1
    end
    return file_count
  end)

  if not count_success then
    get_logger().warn("Failed to count monitored files", {
      error = get_error_handler().format_error(count_result),
    })
    file_count = total_watched -- Use the accumulated count as fallback
  else
    file_count = count_result
  end

  get_logger().info("Watch initialization complete", {
    monitored_files = file_count,
    total_found = total_found,
    total_excluded = total_excluded,
    directories_with_errors = dir_error_count,
    total_directories = #dirs_to_watch,
  })

  if dir_error_count == #dirs_to_watch and #dirs_to_watch > 0 then
    local err = get_error_handler().io_error("Failed to initialize watcher - all directories failed", {
      operation = "watcher.init",
      module = "watcher",
      directories = dirs_to_watch,
      error_count = dir_error_count,
    })
    return nil, err
  end

  return true
end

--- Checks all watched files for changes since the last call to this function or `init`.
--- Detects modified, added, and removed files based on timestamps and presence.
--- Updates internal state (`file_timestamps`, `last_check_time`).
---@return string[]|nil changed_files An array of file paths that have changed (modified, added, or removed), or `nil` if no changes were detected or if a critical error occurred.
---@return table? error Error object from `error_handler` if a critical error occurred during checks.
---@throws table If configuration validation fails or critical errors occur during file checks via `error_handler`.
function watcher.check_for_changes()
  -- Validate configuration before proceeding
  if not config then
    local err = get_error_handler().runtime_error("Configuration not initialized", {
      operation = "watcher.check_for_changes",
      module = "watcher",
    })
    get_logger().error("Invalid configuration state", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  if not config.check_interval or type(config.check_interval) ~= "number" then
    local err = get_error_handler().validation_error("Invalid check_interval in configuration", {
      operation = "watcher.check_for_changes",
      provided_type = type(config.check_interval),
      module = "watcher",
    })
    get_logger().error("Invalid configuration value", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  -- Get current time with error handling
  local time_success, current_time = get_error_handler().try(function()
    return os.time()
  end)

  if not time_success then
    local err = get_error_handler().runtime_error(
      "Failed to get system time",
      {
        operation = "watcher.check_for_changes",
        module = "watcher",
      },
      current_time -- cause
    )
    get_logger().error("Time function failed", {
      error = get_error_handler().format_error(err),
    })
    -- Use a reasonable fallback to not disrupt operation
    current_time = (last_check_time or 0) + config.check_interval + 1
  end

  -- Check if it's time for a new check
  if current_time - last_check_time < config.check_interval then
    get_logger().verbose("Skipping file check", {
      elapsed = current_time - last_check_time,
      required_interval = config.check_interval,
    })
    return nil
  end

  -- Get formatted timestamp with error protection
  local timestamp
  local timestamp_success, timestamp_result = get_error_handler().try(function()
    return os.date("%Y-%m-%d %H:%M:%S")
  end)

  if not timestamp_success then
    get_logger().warn("Failed to format timestamp", {
      error = get_error_handler().format_error(timestamp_result),
    })
    timestamp = tostring(current_time) -- Fallback to raw timestamp
  else
    timestamp = timestamp_result
  end

  get_logger().debug("Checking for file changes", { timestamp = timestamp })
  last_check_time = current_time
  local changed_files = {}

  -- Verify file_timestamps is valid
  if type(file_timestamps) ~= "table" then
    local err = get_error_handler().runtime_error("Invalid file_timestamps table", {
      operation = "watcher.check_for_changes",
      module = "watcher",
    })
    get_logger().error("Invalid state", {
      error = get_error_handler().format_error(err),
    })
    -- Initialize a new empty table as fallback
    file_timestamps = {}
    return nil, err
  end

  -- Track statistics for reporting
  local checked_files = 0
  local changed_count = 0
  local removed_count = 0
  local errors_count = 0

  -- Check each watched file for changes with error boundaries per file
  local success, result = get_error_handler().try(function()
    for path, old_mtime in pairs(file_timestamps) do
      checked_files = checked_files + 1

      -- Skip invalid paths and mtimes
      if type(path) ~= "string" or type(old_mtime) ~= "number" then
        get_logger().warn("Skipping invalid entry", {
          path_type = type(path),
          mtime_type = type(old_mtime),
        })
        errors_count = errors_count + 1
        goto continue_file_check
      end

      -- Get file modification time with error handling
      local new_mtime = get_file_mtime(path)

      -- If file exists and has changed
      if new_mtime and new_mtime > old_mtime then
        get_logger().info("File changed", {
          path = path,
          old_mtime = old_mtime,
          new_mtime = new_mtime,
        })
        -- Protected insert operation
        local insert_success, _ = get_error_handler().try(function()
          table.insert(changed_files, path)
          return true
        end)

        if not insert_success then
          get_logger().warn("Failed to add path to changed files list", { path = path })
          errors_count = errors_count + 1
        else
          changed_count = changed_count + 1
        end

        file_timestamps[path] = new_mtime
      -- If file no longer exists
      elseif not new_mtime then
        get_logger().info("File removed", { path = path })
        -- Protected insert operation
        local insert_success, _ = get_error_handler().try(function()
          table.insert(changed_files, path)
          return true
        end)

        if not insert_success then
          get_logger().warn("Failed to add removed path to changed files list", { path = path })
          errors_count = errors_count + 1
        else
          removed_count = removed_count + 1
        end

        file_timestamps[path] = nil
      end

      ::continue_file_check::
    end

    return true
  end)

  if not success then
    get_logger().error("Failed to check existing files", {
      error = get_error_handler().format_error(result),
    })
    -- Don't return immediately - try to check for new files too
  end

  -- Check for new files with comprehensive error handling
  local new_files_count = 0
  local scan_errors_count = 0

  -- Validate directory configuration
  if not config.default_directory or type(config.default_directory) ~= "string" then
    get_logger().warn("Invalid default_directory configuration, using current directory", {
      provided_value = config.default_directory,
    })
    config.default_directory = "."
  end

  -- Create the directories list safely
  local dirs = { config.default_directory }

  -- Process each directory for new files
  for _, dir in ipairs(dirs) do
    -- Check if directory exists before scanning
    local dir_exists, dir_err = get_error_handler().safe_io_operation(
      function()
        return get_fs().directory_exists(dir)
      end,
      dir,
      {
        operation = "watcher.check_for_changes.directory_check",
        module = "watcher",
      }
    )

    if not dir_exists then
      get_logger().warn("Directory does not exist", {
        directory = dir,
        error = dir_err and get_error_handler().format_error(dir_err),
      })
      scan_errors_count = scan_errors_count + 1
      goto continue_dir
    end

    get_logger().debug("Checking for new files", { directory = dir })
    local files, scan_err = get_error_handler().safe_io_operation(
      function()
        return get_fs().scan_directory(dir, true)
      end,
      dir,
      {
        operation = "watcher.check_for_changes.scan_directory",
        recursive = true,
        module = "watcher",
      }
    )

    if not files then
      get_logger().warn("Failed to scan directory for new files", {
        directory = dir,
        error = scan_err and get_error_handler().format_error(scan_err),
      })
      scan_errors_count = scan_errors_count + 1
      goto continue_dir
    end

    -- Validate scan results
    if type(files) ~= "table" then
      get_logger().warn("Invalid scan result type", {
        directory = dir,
        result_type = type(files),
      })
      scan_errors_count = scan_errors_count + 1
      goto continue_dir
    end

    -- Process new files with per-file error boundaries
    local files_success, _ = get_error_handler().try(function()
      for _, path in ipairs(files) do
        -- Skip invalid paths
        if type(path) ~= "string" then
          get_logger().warn("Skipping invalid path", { path_type = type(path) })
          goto continue_new_file
        end

        -- Skip files we're already tracking
        if file_timestamps[path] ~= nil then
          goto continue_new_file
        end

        -- Check if this file matches our patterns
        local should_watch = should_watch_file(path)
        if should_watch then
          local mtime = get_file_mtime(path)
          if mtime then
            get_logger().info("New file detected", { path = path })

            -- Protected insert operation
            local insert_success, _ = get_error_handler().try(function()
              table.insert(changed_files, path)
              return true
            end)

            if not insert_success then
              get_logger().warn("Failed to add new path to changed files list", { path = path })
              errors_count = errors_count + 1
            else
              new_files_count = new_files_count + 1
            end

            file_timestamps[path] = mtime
          end
        end

        ::continue_new_file::
      end
      return true
    end)

    if not files_success then
      get_logger().warn("Error processing new files", {
        directory = dir,
        error = get_error_handler().format_error(files_success), -- Error is in first return value in this case
      })
      scan_errors_count = scan_errors_count + 1
    end

    ::continue_dir::
  end

  -- Get file count safely
  local file_count = 0
  local count_success, count_result = get_error_handler().try(function()
    return #changed_files
  end)

  if not count_success then
    get_logger().warn("Failed to count changed files", {
      error = get_error_handler().format_error(count_result),
    })
    file_count = changed_count + removed_count + new_files_count -- Fallback to tracked counts
  else
    file_count = count_result
  end

  get_logger().info("File check completed", {
    files_checked = checked_files,
    files_changed = changed_count,
    files_removed = removed_count,
    new_files_found = new_files_count,
    total_changes = file_count,
    errors = errors_count,
    scan_errors = scan_errors_count,
  })

  if file_count > 0 then
    get_logger().info("Detected changed files", { count = file_count })
    return changed_files
  else
    get_logger().debug("No file changes detected", {
      elapsed = os.time() - last_check_time,
    })
    return nil
  end
end

--- Add patterns to watch
---@param patterns string[] Array of Lua patterns to add to the `config.watch_patterns` list.
---@return watcher_module|nil self The module instance (`watcher`) for chaining, or `nil` on validation failure.
---@return table? error Error object from `error_handler` if validation failed.
---@throws table If parameter validation fails critically via `error_handler`.
function watcher.add_patterns(patterns)
  -- Validate patterns parameter
  if not patterns then
    local err = get_error_handler().validation_error("Missing required patterns parameter", {
      operation = "watcher.add_patterns",
      module = "watcher",
    })
    get_logger().error("Invalid parameter", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  if type(patterns) ~= "table" then
    local err = get_error_handler().validation_error("Patterns must be a table", {
      operation = "watcher.add_patterns",
      provided_type = type(patterns),
      module = "watcher",
    })
    get_logger().error("Invalid parameter type", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  -- Validate config state
  if not config or type(config) ~= "table" then
    local err = get_error_handler().runtime_error("Configuration not initialized", {
      operation = "watcher.add_patterns",
      module = "watcher",
    })
    get_logger().error("Invalid state", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  if not config.watch_patterns or type(config.watch_patterns) ~= "table" then
    get_logger().warn("Invalid watch_patterns configuration, initializing new table")
    config.watch_patterns = {}
  end

  -- Track successful additions
  local added_count = 0
  local error_count = 0

  -- Process each pattern with error boundaries around each pattern
  for i, pattern in ipairs(patterns) do
    local success, result = get_error_handler().try(function()
      -- Validate pattern
      if type(pattern) ~= "string" then
        get_logger().warn("Skipping non-string pattern", {
          index = i,
          provided_type = type(pattern),
        })
        return false
      end

      -- Check if pattern is valid (catch malformed patterns)
      local _, pattern_err = pcall(function()
        return string.match("test", pattern)
      end)
      if pattern_err then
        get_logger().warn("Skipping invalid pattern", {
          pattern = pattern,
          error = pattern_err,
        })
        return false
      end

      get_logger().info("Adding watch pattern", { pattern = pattern })
      table.insert(config.watch_patterns, pattern)

      -- Get current patterns with error handling
      local get_success, current_patterns = get_error_handler().try(function()
        return central_config.get("watcher.watch_patterns") or {}
      end)

      if not get_success then
        get_logger().warn("Failed to get current patterns from central_config", {
          error = get_error_handler().format_error(current_patterns),
        })
        -- Continue without updating central_config
        return true
      end

      -- Add new pattern with error handling
      local set_success, set_result = get_error_handler().try(function()
        -- Add new pattern
        table.insert(current_patterns, pattern)
        -- Update central config
        central_config.set("watcher.watch_patterns", current_patterns)
        return true
      end)

      if not set_success then
        get_logger().warn("Failed to update patterns in central_config", {
          error = get_error_handler().format_error(set_result),
        })
        -- Pattern was still added to local config, so still return success
      else
        get_logger().debug("Updated watch_patterns in central_config", {
          pattern_count = #current_patterns,
        })
      end

      return true
    end)

    if success and result then
      added_count = added_count + 1
    else
      error_count = error_count + 1
    end
  end

  get_logger().info("Pattern addition complete", {
    patterns_added = added_count,
    errors = error_count,
  })

  return watcher
end

--- Set check interval for file change detection
---@param interval number Time in seconds between file checks (must be > 0).
---@return watcher_module|nil self The module instance (`watcher`) for chaining, or `nil` on validation failure.
---@return table? error Error object from `error_handler` if validation failed.
---@throws table If parameter validation fails critically via `error_handler`.
function watcher.set_check_interval(interval)
  -- Validate interval parameter
  if not interval then
    local err = get_error_handler().validation_error("Missing required interval parameter", {
      operation = "watcher.set_check_interval",
      module = "watcher",
    })
    get_logger().error("Invalid parameter", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  if type(interval) ~= "number" then
    local err = get_error_handler().validation_error("Interval must be a number", {
      operation = "watcher.set_check_interval",
      provided_type = type(interval),
      module = "watcher",
    })
    get_logger().error("Invalid parameter type", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  if interval <= 0 then
    local err = get_error_handler().validation_error("Interval must be greater than zero", {
      operation = "watcher.set_check_interval",
      provided_value = interval,
      module = "watcher",
    })
    get_logger().error("Invalid parameter value", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  -- Validate config state
  if not config or type(config) ~= "table" then
    local err = get_error_handler().runtime_error("Configuration not initialized", {
      operation = "watcher.set_check_interval",
      module = "watcher",
    })
    get_logger().error("Invalid state", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  get_logger().info("Setting check interval", { seconds = interval })
  config.check_interval = interval

  local success, result = get_error_handler().try(function()
    central_config.set("watcher.check_interval", interval)
    return true
  end)

  if not success then
    get_logger().warn("Failed to update check_interval in central_config", {
      error = get_error_handler().format_error(result),
    })
    -- Value was still updated locally, so don't return error
  else
    get_logger().debug("Updated check_interval in central_config", {
      check_interval = interval,
    })
  end

  return watcher
end

--- Resets the watcher module's local configuration to its defaults (`DEFAULT_CONFIG`).
--- Does not reset file timestamps or central configuration.
---@return watcher_module|nil self The module instance (`watcher`) for chaining, or `nil` on failure.
---@return table? error Error object from `error_handler` if reset failed critically.
---@throws table If a runtime error occurs during reset (via `get_error_handler().try`).
function watcher.reset()
  get_logger().debug("Resetting watcher module configuration to defaults")

  -- Validate DEFAULT_CONFIG availability
  if not DEFAULT_CONFIG then
    local err = get_error_handler().runtime_error("Default configuration not available", {
      operation = "watcher.reset",
      module = "watcher",
    })
    get_logger().error("Missing default configuration", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  -- Validate config state
  if not config then
    local err = get_error_handler().runtime_error("Configuration table not initialized", {
      operation = "watcher.reset",
      module = "watcher",
    })
    get_logger().error("Invalid state", {
      error = get_error_handler().format_error(err),
    })

    -- Initialize config as fallback
    config = {}
  end

  -- Reset configuration with error boundaries
  local success, result = get_error_handler().try(function()
    -- Reset check_interval and default_directory with proper defaults
    config.check_interval = DEFAULT_CONFIG.check_interval
    config.default_directory = DEFAULT_CONFIG.default_directory
    config.debug = DEFAULT_CONFIG.debug
    config.verbose = DEFAULT_CONFIG.verbose

    -- Reset watch_patterns with fallback for pattern errors
    config.watch_patterns = {}
    for _, pattern in ipairs(DEFAULT_CONFIG.watch_patterns or {}) do
      if type(pattern) == "string" then
        -- Check if pattern is valid
        local is_valid = true
        local _, pattern_err = pcall(function()
          return string.match("test", pattern)
        end)
        if pattern_err then
          get_logger().warn("Skipping invalid default pattern", {
            pattern = pattern,
            error = pattern_err,
          })
          is_valid = false
        end

        if is_valid then
          table.insert(config.watch_patterns, pattern)
        end
      else
        get_logger().warn("Skipping non-string default pattern", {
          pattern_type = type(pattern),
        })
      end
    end

    return true
  end)

  if not success then
    get_logger().error("Failed to reset configuration", {
      error = get_error_handler().format_error(result),
    })
    return nil, result
  end

  -- Update logging configuration
  local log_level = config.debug and get_logging().LEVELS.DEBUG
    or (config.verbose and get_logging().LEVELS.VERBOSE or get_logging().LEVELS.INFO)
  get_logging().set_level(log_level)

  get_logger().info("Reset complete", {
    check_interval = config.check_interval,
    patterns_count = #config.watch_patterns,
  })

  return watcher
end

--- Performs a full reset: resets local configuration (`watcher.reset()`) and attempts to reset
--- the "watcher" section in the central configuration system. Also clears file timestamps.
---@return watcher_module|nil self The module instance (`watcher`) for chaining, or `nil` on failure.
---@return table? error Error object from `error_handler` if reset failed critically.
---@throws table If a runtime error occurs during reset (via `get_error_handler().try`).
function watcher.full_reset()
  get_logger().info("Performing full reset of watcher module")

  -- Reset local configuration first
  local success, err = watcher.reset()
  if not success then
    get_logger().error("Failed to reset local configuration during full reset", {
      error = get_error_handler().format_error(err),
    })
    -- Continue with central config reset despite local reset failure
  end

  local success, result = get_error_handler().try(function()
    central_config.reset("watcher")
    return true
  end)

  if not success then
    get_logger().warn("Failed to reset central configuration", {
      error = get_error_handler().format_error(result),
    })
    return nil, result
  else
    get_logger().debug("Reset central configuration for watcher module")
  end

  -- Clear the file timestamps to force re-initialization
  file_timestamps = {}
  last_check_time = 0

  get_logger().info("Full reset complete")
  return watcher
end

--- Returns a table containing the current watcher configuration and state for debugging purposes.
--- Includes local config, central config (if available), file counts, and timestamps.
---@return table debug_info Detailed information about configuration and state.
function watcher.debug_config()
  get_logger().debug("Generating configuration debug information")

  -- Initialize with safe defaults
  local debug_info = {
    local_config = {},
    using_central_config = false,
    central_config = nil,
    file_count = 0,
    last_check_time = 0,
    status = "unknown",
  }

  -- Get local config with error handling
  local config_success, _ = get_error_handler().try(function()
    if config then
      debug_info.local_config = {
        check_interval = config.check_interval,
        default_directory = config.default_directory,
        debug = config.debug,
        verbose = config.verbose,
        watch_patterns = config.watch_patterns,
      }

      -- Determine watcher status
      debug_info.status = "initialized"
      debug_info.last_check_time = last_check_time
    else
      debug_info.status = "uninitialized"
    end
    return true
  end)

  if not config_success then
    debug_info.status = "error"
    debug_info.local_config = {
      error = "Failed to access configuration",
    }
  end

  -- Count monitored files with error handling
  local count_success, _ = get_error_handler().try(function()
    local file_count = 0
    if type(file_timestamps) == "table" then
      for _ in pairs(file_timestamps) do
        file_count = file_count + 1
      end
    end
    debug_info.file_count = file_count
    return true
  end)

  if not count_success then
    debug_info.file_count = -1 -- Error indicator
  end

  -- Check for central_config with error handling
  local central_success, _ = get_error_handler().try(function()
    debug_info.using_central_config = true
    local watcher_config = central_config.get("watcher")
    debug_info.central_config = watcher_config or { status = "empty" }
    return true
  end)

  if not central_success then
    debug_info.using_central_config = false
    debug_info.central_config = { status = "error" }
  end

  -- Display configuration
  get_logger().info("Watcher module configuration", debug_info)

  return debug_info
end

return watcher
