--- Centralized configuration module for firmo
--- Provides a global configuration store with standardized access patterns
---
--- Features:
--- - Hierarchical configuration with dot-notation paths (module.setting.subsetting)
--- - Schema validation for type safety and consistency
--- - Change listeners with hierarchical notification
--- - Default values with automatic application
--- - File-based persistence with load/save capabilities
--- - Clean serialization of Lua tables for readable config files
--- - Comprehensive error handling with detailed context
--- - Lazy loading of dependencies to avoid circular references
---
--- @version 0.3.0
--- @author Firmo Team

-- Directly require error_handler to ensure it's always available
local error_handler = require("lib.tools.error_handler")

---@class central_config
---@field get fun(path?: string, default?: any): any, table|nil Returns the value at the specified path or the default if not found
---@field set fun(path: string, value: any): central_config Sets a value at the specified path
---@field delete fun(path: string): boolean, table|nil Deletes a value at the specified path
---@field on_change fun(path: string, callback: fun(path: string, old_value: any, new_value: any)): central_config Registers a callback for when a value changes
---@field notify_change fun(path: string, old_value: any, new_value: any) Notifies listeners of a value change
---@field register_module fun(module_name: string, schema?: table, defaults?: table): central_config Registers a module's schema and defaults
---@field validate fun(module_name?: string): boolean, table|nil Validates configuration against registered schemas
---@field load_from_file fun(path?: string): table|nil, table|nil Loads configuration from a file
---@field save_to_file fun(path?: string): boolean, table|nil Saves configuration to a file
---@field reset fun(module_name?: string): central_config Resets configuration to defaults
---@field configure_from_options fun(options: table): central_config Configures from options table (typically from CLI)
---@field configure_from_config fun(global_config: table): central_config Configures from global config
---@field serialize fun(obj: any): any Serializes an object for storage
---@field merge fun(target: table, source: table): table Merges two tables
---@field DEFAULT_CONFIG_PATH string The default configuration file path
---@field ERROR_TYPES table Error type constants mapping to error_handler categories
---@field _VERSION string Module version identifier
-- Module table
local M = {}

-- Module version
M._VERSION = "0.3.0"

-- Configuration storage
local config = {
  values = {}, -- Main configuration values
  schemas = {}, -- Registered schemas by module
  listeners = {}, -- Change listeners by path
  defaults = {}, -- Default values by module
  resetting = false, -- Flag to prevent recursive resets
}

---@private
-- Initialize empty config storage
local function init_config()
  config.values = {}
  config.schemas = {}
  config.listeners = {}
  config.defaults = {}
end

-- Constants
M.DEFAULT_CONFIG_PATH = ".firmo-config.lua"

-- Error categories mapping to error_handler categories
M.ERROR_TYPES = {
  VALIDATION = error_handler.CATEGORY.VALIDATION, -- Schema validation errors
  ACCESS = error_handler.CATEGORY.VALIDATION, -- Path access errors
  IO = error_handler.CATEGORY.IO, -- File I/O errors
  PARSE = error_handler.CATEGORY.PARSE, -- Config file parsing errors
}

---@private
---@param path string|nil The dot-separated path to convert to parts
---@return string[] Array of path segments
-- Helper for generating pathed keys (a.b.c -> ["a"]["b"]["c"])
local function path_to_parts(path)
  if not path or path == "" then
    return {}
  end

  local parts = {}
  for part in string.gmatch(path, "[^.]+") do
    table.insert(parts, part)
  end

  return parts
end

---@private
---@param t table The table to ensure path in
---@param parts string[] The path parts to ensure exist
---@return table|nil parent The parent table where the last part would be set
---@return table|nil error The error if any occurred
-- Create value at path
---@diagnostic disable-next-line: unused-local
local function ensure_path(t, parts)
  if not t or type(t) ~= "table" then
    return nil,
      error_handler.validation_error("Target must be a table for ensure_path", {
        target_type = type(t),
        parts = parts,
      })
  end

  local current = t
  for i, part in ipairs(parts) do
    if i < #parts then
      current[part] = current[part] or {}
      if type(current[part]) ~= "table" then
        current[part] = {} -- Convert to table if it's not
      end
      current = current[part]
    end
  end
  return current
end

-- Lazy loading of dependencies to avoid circular references
local _logging, _fs

---@private
---@return table|nil The logging module if available, nil otherwise
-- Get the logging module, loading it if necessary
local function get_logging()
  if not _logging then
    local success, logging = pcall(require, "lib.tools.logging")
    _logging = success and logging or nil
  end
  return _logging
end

---@private
---@return table|nil The filesystem module if available, nil otherwise
-- Get the filesystem module, loading it if necessary
local function get_fs()
  if not _fs then
    local success, fs = pcall(require, "lib.tools.filesystem")
    _fs = success and fs or nil
  end
  return _fs
end

---@private
---@param level string The log level ('debug', 'info', 'warn', 'error')
---@param message string The log message
---@param params? table Additional parameters for structured logging
-- Log helper with structured logging
local function log(level, message, params)
  local logging = get_logging()
  if logging then
    local logger = logging.get_logger("central_config")
    logger[level](message, params or {})
  end
end

---@private
---@param target table|nil The target table to merge into
---@param source table|nil The source table to merge from
---@return table|nil merged The merged table
---@return table|nil error Any error that occurred during merging
-- Deep merge helper (for merging configs)
local function deep_merge(target, source)
  -- Input validation
  if source ~= nil and type(source) ~= "table" then
    return nil,
      error_handler.validation_error("Source must be a table or nil for deep_merge", {
        source_type = type(source),
        operation = "deep_merge",
      })
  end

  if source == nil then
    return target
  end

  if target ~= nil and type(target) ~= "table" then
    return nil,
      error_handler.validation_error("Target must be a table or nil for deep_merge", {
        target_type = type(target),
        operation = "deep_merge",
      })
  end

  if target == nil then
    target = {}
  end

  for k, v in pairs(source) do
    if type(v) == "table" and type(target[k]) == "table" then
      local merged_value, err = deep_merge(target[k], v)
      if err then
        return nil,
          error_handler.validation_error("Failed to merge nested table", {
            key = k,
            operation = "deep_merge",
            error = err.message,
          })
      end
      target[k] = merged_value
    else
      target[k] = v
    end
  end

  return target
end

---@private
---@param obj any The object to copy
---@param cache table Cache table for cycle detection
---@return any A deep copy of the input object
-- Deep copy helper with cycle detection to prevent infinite recursion
local function deep_copy(obj, cache)
  -- Input validation
  if obj == nil then
    return nil
  end
  
  if type(obj) ~= "table" then
    -- For non-tables, just return the value
    return obj
  end
  
  -- Check if we've already copied this table (cycle detection)
  if cache[obj] then
    return cache[obj]
  end
  
  -- Create new table and register it in cache immediately to handle cycles
  local result = {}
  cache[obj] = result
  
  -- Copy all key/value pairs
  for k, v in pairs(obj) do
    -- Handle table keys - check cache first to prevent recursion
    local key_copy
    if type(k) == "table" then
      -- Check if key is already in cache before recursive copy
      if cache[k] then
        key_copy = cache[k]
      else
        key_copy = deep_copy(k, cache)
      end
    else
      key_copy = k
    end
    
    -- Handle values (already checks cache in deep_copy)
    result[key_copy] = deep_copy(v, cache)
  end
  
  -- Copy metatable if exists
  local mt = getmetatable(obj)
  if mt then
    setmetatable(result, deep_copy(mt, cache))
  end
  
  return result
end

---@private
---@param a any First value to compare
---@param b any Second value to compare
---@return boolean Whether the values are deeply equal
-- Deep compare helper
local function deep_equals(a, b)
  -- Direct comparison for identical references or non-table values
  if a == b then
    return true
  end

  -- Type checking
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end

  -- Check all keys in a exist in b with equal values
  for k, v in pairs(a) do
    if not deep_equals(v, b[k]) then
      return false
    end
  end

  -- Check for extra keys in b that don't exist in a
  for k in pairs(b) do
    if a[k] == nil then
      return false
    end
  end

  return true
end

--- Gets a configuration value from the specified path
--- This function retrieves a value from the central configuration store using a
--- dot-separated path notation. It returns a copy of the value to prevent direct
--- modification of configuration data. If the path doesn't exist, it returns either
--- the provided default value or an error object.
---
--- @param path? string The path to get the value at (dot-separated, e.g. 'module.setting')
--- @param default? any Value to return if path doesn't exist
--- @return any value The value at the path or the default
--- @return table|nil error Error if any occurred
---
--- @usage
--- -- Get a simple setting with default value
--- local logging_level = central_config.get("logging.level", "info")
---
--- -- Get a complex configuration object
--- local database_config = central_config.get("database")
--- if database_config then
---   db.connect(database_config.host, database_config.port)
--- end
---
--- -- Get full configuration
--- local full_config = central_config.get()
---
--- -- With error handling
--- local cache_settings, err = central_config.get("cache.settings")
--- if err then
---   print("Error getting cache settings: " .. err.message)
---   -- Use defaults
---   cache_settings = { ttl = 3600, max_size = 1000 }
--- end
function M.get(path, default)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error("Path must be a string or nil", {
      parameter_name = "path",
      provided_type = type(path),
      operation = "get",
    })
    log("warn", err.message, err.context)
    return nil, err
  end

  -- Return all config if no path specified
  if not path or path == "" then
    return M.serialize(config.values)
  end

  local parts = path_to_parts(path)
  if #parts == 0 then
    return M.serialize(config.values)
  end

  -- Navigate to value
  local current = config.values
  for i, part in ipairs(parts) do
    if type(current) ~= "table" then
      local context = {
        path = path,
        failed_at = table.concat(parts, ".", 1, i - 1),
        expected = "table",
        got = type(current),
      }

      log("debug", "Path traversal failed at part", context)

      if default ~= nil then
        return default
      else
        local err =
          error_handler.validation_error("Path traversal failed: expected table but got " .. type(current), context)
        return nil, err
      end
    end

    current = current[part]
    if current == nil then
      local context = {
        path = path,
        failed_at = table.concat(parts, ".", 1, i),
      }

      log("debug", "Path not found", context)

      if default ~= nil then
        return default
      else
        local err = error_handler.validation_error("Path not found: " .. path, context)
        return nil, err
      end
    end
  end

  -- Return copy to prevent direct modification
  if type(current) == "table" then
    return M.serialize(current)
  end

  return current
end

--- Sets a configuration value at the specified path
--- This function stores a value in the configuration system at the specified path,
--- automatically creating any required parent tables. When setting table values,
--- it makes a deep copy to prevent unintended modification by reference. The function
--- also notifies any change listeners if the value changes. The function supports
--- method chaining by returning the module instance.
---
--- @param path? string The path to set the value at (dot-separated, e.g. 'module.setting')
--- @param value any The value to store at the specified path
--- @return central_config The module instance for chaining
---
--- @usage
--- -- Set a simple value
--- central_config.set("logging.level", "debug")
---
--- -- Set a nested value
--- central_config.set("database.connection", {
---   host = "localhost",
---   port = 5432,
---   username = "app_user",
---   password = "secret"
--- })
---
--- -- Set the entire configuration at once
--- central_config.set({
---   logging = { level = "info", format = "json" },
---   app = { name = "MyApp", version = "1.0.0" },
---   paths = { data = "/var/data", temp = "/tmp/myapp" }
--- })
---
--- -- Method chaining
--- central_config
---   .set("cache.ttl", 3600)
---   .set("cache.max_size", 1024)
---   .set("cache.storage", "memory")
function M.set(path, value)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error("Path must be a string or nil", {
      parameter_name = "path",
      provided_type = type(path),
      operation = "set",
    })
    log("warn", err.message, err.context)
    return M
  end

  -- Handle root config
  if not path or path == "" then
    -- Root config must be a table
    if type(value) ~= "table" then
      local err = error_handler.validation_error("Cannot set root config to non-table value", {
        type = type(value),
        operation = "set",
      })
      log("warn", err.message, err.context)
      return M
    end

    -- Set the root config (with deep copy)
    config.values = M.serialize(value)
    log("debug", "Set complete configuration", { keys = table.concat({}, ",") })
    return M
  end

  local parts = path_to_parts(path)
  if #parts == 0 then
    -- Empty path parts (shouldn't normally happen with non-empty path)
    if type(value) == "table" then
      config.values = M.serialize(value)
      log("debug", "Set complete configuration (empty parts)", { path = path })
    else
      local err = error_handler.validation_error("Cannot set root config to non-table value", {
        type = type(value),
        operation = "set",
      })
      log("warn", err.message, err.context)
    end
    return M
  end

  -- Get the last part (key to set)
  local last_key = parts[#parts]
  table.remove(parts, #parts)

  -- Ensure path exists by creating parent tables as needed
  local parent
  if #parts == 0 then
    -- If no parent path (direct child of root), use root config
    parent = config.values
  else
    -- Create the parent path structure if needed
    parent = config.values
    ---@diagnostic disable-next-line: unused-local
    for i, part in ipairs(parts) do
      ---@diagnostic disable-next-line: need-check-nil
      if type(parent[part]) ~= "table" then
        parent[part] = {}
      end
      ---@diagnostic disable-next-line: need-check-nil
      parent = parent[part]
    end
  end

  -- Store old value for change detection
  ---@diagnostic disable-next-line: need-check-nil
  local old_value = parent[last_key]

  -- Set the value (deep copy if it's a table)
  if type(value) == "table" then
    parent[last_key] = M.serialize(value)
  else
    parent[last_key] = value
  end

  -- Log the operation with detailed information for debugging
  log("debug", "Set configuration value", {
    path = path,
    old_value_type = type(old_value),
    new_value_type = type(value),
    complete_path = path,
  })

  -- Notify listeners if value changed
  if not deep_equals(old_value, value) then
    M.notify_change(path, old_value, value)
  end

  return M
end

--- Deletes a configuration value at the specified path
--- This function removes a value from the configuration system at the specified path.
--- It performs path validation and traversal to find the target value, verifies its
--- existence, and properly notifies listeners of the change. The function returns
--- a boolean indicating success or failure and an optional error object with details.
---
--- @param path string The path to delete the value at (dot-separated, e.g. 'module.setting')
--- @return boolean success Whether the delete was successful
--- @return table|nil error Error if any occurred
---
--- @usage
--- -- Delete a configuration value
--- local success, err = central_config.delete("logging.debug_mode")
--- if not success then
---   print("Failed to delete config: " .. (err and err.message or "unknown error"))
--- end
---
--- -- Safely delete nested configuration
--- if central_config.get("database.replica") then
---   central_config.delete("database.replica.host")
---   central_config.delete("database.replica.port")
--- end
---
--- -- Delete with error handling
--- local function safe_delete(path)
---   local success, err = central_config.delete(path)
---   if not success then
---     if err and err.message:match("path not found") then
---       -- Silently ignore if path doesn't exist
---       return true
---     end
---     return false, err
---   end
---   return true
--- end
function M.delete(path)
  -- Parameter validation
  if path == nil or type(path) ~= "string" then
    local err = error_handler.validation_error("Path must be a non-empty string", {
      parameter_name = "path",
      provided_type = type(path),
      operation = "delete",
    })
    log("warn", err.message, err.context)
    return false, err
  end

  if path == "" then
    local err = error_handler.validation_error("Cannot delete root configuration", {
      operation = "delete",
    })
    log("warn", err.message, err.context)
    return false, err
  end

  local parts = path_to_parts(path)
  if #parts == 0 then
    local err = error_handler.validation_error("Cannot delete root configuration", {
      operation = "delete",
      path = path,
    })
    log("warn", err.message, err.context)
    return false, err
  end

  -- Get the last part (key to delete)
  local last_key = parts[#parts]
  table.remove(parts, #parts)

  -- Navigate to parent
  local current = config.values
  for i, part in ipairs(parts) do
    if type(current) ~= "table" then
      local context = {
        path = path,
        failed_at = table.concat(parts, ".", 1, i),
        operation = "delete",
      }

      local err = error_handler.validation_error("Delete failed: path not found", context)
      log("debug", err.message, context)
      return false, err
    end

    current = current[part]
    if current == nil then
      local context = {
        path = path,
        failed_at = table.concat(parts, ".", 1, i),
        operation = "delete",
      }

      local err = error_handler.validation_error("Delete failed: path not found", context)
      log("debug", err.message, context)
      return false, err
    end
  end

  -- Delete the key if parent exists
  if type(current) == "table" then
    -- Store old value for change detection
    local old_value = current[last_key]

    -- Check if the key exists
    if old_value == nil then
      local context = {
        path = path,
        key = last_key,
        operation = "delete",
      }

      local err = error_handler.validation_error("Delete failed: key does not exist", context)
      log("debug", err.message, context)
      return false, err
    end

    -- Remove the key
    current[last_key] = nil

    -- Notify listeners
    M.notify_change(path, old_value, nil)

    log("debug", "Deleted configuration value", { path = path })
    return true
  end

  -- Parent isn't a table
  local context = {
    path = path,
    parent_type = type(current),
    operation = "delete",
  }

  local err = error_handler.validation_error("Delete failed: parent is not a table", context)
  log("debug", err.message, context)
  return false, err
end

--- Registers a callback to be notified when configuration values change
--- This function adds a listener that will be called whenever a specific configuration
--- path or any of its children changes. You can register listeners for specific paths
--- or for the entire configuration tree (by using nil or "" as the path). Callbacks
--- receive the changed path, the old value, and the new value as parameters.
---
--- @param path? string The path to listen for changes on (nil for all changes)
--- @param callback fun(path: string, old_value: any, new_value: any) Function to call when value changes
--- @return central_config The module instance for chaining
---
--- @usage
--- -- Listen for changes to a specific setting
--- central_config.on_change("logging.level", function(path, old_value, new_value)
---   print("Logging level changed from " .. old_value .. " to " .. new_value)
---   log_system.set_level(new_value)
--- end)
---
--- -- Listen for changes to an entire module's configuration
--- central_config.on_change("database", function(path, old_value, new_value)
---   -- Reconnect to database if configuration changes
---   if path:match("database.connection") then
---     db.reconnect(central_config.get("database.connection"))
---   end
--- end)
---
--- -- Listen for all configuration changes
--- central_config.on_change(nil, function(path, old_value, new_value)
---   print("Config changed: " .. path)
---
---   -- Trigger cache invalidation on core settings changes
---   if path:match("^cache%.") then
---     cache_system.invalidate(path)
---   end
--- end)
function M.on_change(path, callback)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error("Path must be a string or nil", {
      parameter_name = "path",
      provided_type = type(path),
      operation = "on_change",
    })
    log("warn", err.message, err.context)
    return M
  end

  if type(callback) ~= "function" then
    local err = error_handler.validation_error("Callback must be a function", {
      parameter_name = "callback",
      provided_type = type(callback),
      operation = "on_change",
    })
    log("warn", err.message, err.context)
    return M
  end

  -- Initialize the listener array if needed
  path = path or "" -- Convert nil to empty string for root listeners
  config.listeners[path] = config.listeners[path] or {}

  -- Register the listener
  table.insert(config.listeners[path], callback)
  log("debug", "Registered change listener", { path = path })

  return M
end

--- Notifies change listeners about a configuration change
--- This internal function is called whenever a configuration value changes. It notifies
--- all applicable listeners, including those registered for the exact path, parent paths,
--- and root path. The function handles errors in listeners safely, ensuring configuration
--- system stability even if callbacks throw errors.
---
--- @param path string The path that changed
--- @param old_value any The previous value
--- @param new_value any The new value
---
--- @usage
--- -- Typically called internally by set() and delete()
--- -- Example of manual notification:
--- local old_value = central_config.get("app.version")
--- -- External process changed version file
--- local new_version = read_version_from_file()
--- central_config.set("app.version", new_version)
---
--- -- In rare cases, manually notify if bypass setter:
--- -- central_config.notify_change("app.version", old_value, new_version)
function M.notify_change(path, old_value, new_value)
  -- Parameter validation
  if path == nil or type(path) ~= "string" then
    local err = error_handler.validation_error("Path must be a string", {
      parameter_name = "path",
      provided_type = type(path),
      operation = "notify_change",
    })
    log("warn", err.message, err.context)
    return
  end

  -- Log the notification for debugging
  log("debug", "Notifying change listeners", {
    path = path,
    old_value_type = type(old_value),
    new_value_type = type(new_value),
    has_exact_listeners = config.listeners[path] ~= nil and #(config.listeners[path] or {}) > 0,
  })

  -- Notify exact path listeners using error_handler.try for safety
  if config.listeners[path] and #config.listeners[path] > 0 then
    for i, callback in ipairs(config.listeners[path]) do
      if type(callback) == "function" then
        local success, err = error_handler.try(function()
          return callback(path, old_value, new_value)
        end)

        if not success then
          log("error", "Error in change listener callback", {
            path = path,
            error = err.message,
            traceback = err.traceback,
            listener_index = i,
          })
        else
          log("debug", "Successfully called exact path listener", {
            path = path,
            listener_index = i,
          })
        end
      else
        log("warn", "Non-function callback found in listeners", {
          path = path,
          callback_type = type(callback),
          listener_index = i,
        })
      end
    end
  end

  -- Notify parent path listeners
  local parts = path_to_parts(path)
  while #parts > 0 do
    table.remove(parts, #parts)
    local parent_path = table.concat(parts, ".")

    if config.listeners[parent_path] and #config.listeners[parent_path] > 0 then
      for i, callback in ipairs(config.listeners[parent_path]) do
        if type(callback) == "function" then
          local success, err = error_handler.try(function()
            return callback(path, old_value, new_value)
          end)

          if not success then
            log("error", "Error in parent change listener callback", {
              parent_path = parent_path,
              changed_path = path,
              error = err.message,
              traceback = err.traceback,
              listener_index = i,
            })
          else
            log("debug", "Successfully called parent path listener", {
              parent_path = parent_path,
              changed_path = path,
              listener_index = i,
            })
          end
        else
          log("warn", "Non-function callback found in parent listeners", {
            parent_path = parent_path,
            callback_type = type(callback),
            listener_index = i,
          })
        end
      end
    end
  end

  -- Notify root listeners (empty path)
  if config.listeners[""] and #config.listeners[""] > 0 then
    for i, callback in ipairs(config.listeners[""]) do
      if type(callback) == "function" then
        local success, err = error_handler.try(function()
          return callback(path, old_value, new_value)
        end)

        if not success then
          log("error", "Error in root change listener callback", {
            changed_path = path,
            error = err.message,
            traceback = err.traceback,
            listener_index = i,
          })
        else
          log("debug", "Successfully called root listener", {
            changed_path = path,
            listener_index = i,
          })
        end
      else
        log("warn", "Non-function callback found in root listeners", {
          callback_type = type(callback),
          listener_index = i,
        })
      end
    end
  end
end

--- Registers a module with the configuration system
--- This function registers a module's configuration schema and default values with
--- the central configuration system. The schema is used for validation, and defaults
--- are applied if corresponding values don't already exist. This function enables
--- modules to define their configuration requirements in a structured way.
---
--- @param module_name string The name of the module to register
--- @param schema? table Schema definition for validation
--- @param defaults? table Default values for the module
--- @return central_config The module instance for chaining
---
--- @usage
--- -- Register a module with schema and defaults
--- central_config.register_module("logging", {
---   -- Schema definition
---   required_fields = {"level", "format"},
---   field_types = {
---     level = "string",
---     format = "string",
---     file = "string",
---     rotate = "boolean",
---     max_size = "number"
---   },
---   field_values = {
---     level = {"debug", "info", "warn", "error"},
---     format = {"text", "json", "pretty"}
---   }
--- }, {
---   -- Default values
---   level = "info",
---   format = "text",
---   rotate = false,
---   max_size = 10485760 -- 10MB
--- })
---
--- -- Register just defaults (no schema validation)
--- central_config.register_module("http_client", nil, {
---   timeout = 30,
---   max_retries = 3,
---   retry_delay = 1000
--- })
---
--- -- Register schema without defaults
--- central_config.register_module("database", {
---   required_fields = {"host", "port", "username", "password"},
---   field_types = {
---     host = "string",
---     port = "number",
---     username = "string",
---     password = "string",
---     pool_size = "number"
---   }
--- })
function M.register_module(module_name, schema, defaults)
  -- Parameter validation
  if type(module_name) ~= "string" then
    local err = error_handler.validation_error("Module name must be a string", {
      parameter_name = "module_name",
      provided_type = type(module_name),
      operation = "register_module",
    })
    log("error", err.message, err.context)
    return M
  end

  if module_name == "" then
    local err = error_handler.validation_error("Module name cannot be empty", {
      parameter_name = "module_name",
      operation = "register_module",
    })
    log("error", err.message, err.context)
    return M
  end

  -- Log the registration operation
  log("debug", "Registering module configuration", {
    module = module_name,
    has_schema = schema ~= nil,
    has_defaults = defaults ~= nil,
  })

  -- Store schema if provided
  if schema ~= nil then
    if type(schema) ~= "table" then
      local err = error_handler.validation_error("Schema must be a table or nil", {
        parameter_name = "schema",
        provided_type = type(schema),
        module = module_name,
        operation = "register_module",
      })
      log("warn", err.message, err.context)
    else
      config.schemas[module_name] = M.serialize(schema) -- Use serialize to prevent modification
      log("debug", "Registered schema for module", {
        module = module_name,
        schema_keys = table.concat(
          (function()
            local keys = {}
            for k, _ in pairs(schema) do
              table.insert(keys, k)
            end
            return keys
          end)(),
          ", "
        ),
      })
    end
  end

  -- Apply defaults if provided
  if defaults ~= nil then
    if type(defaults) ~= "table" then
      local err = error_handler.validation_error("Defaults must be a table or nil", {
        parameter_name = "defaults",
        provided_type = type(defaults),
        module = module_name,
        operation = "register_module",
      })
      log("warn", err.message, err.context)
    else
      -- Store defaults (with deep copy to prevent modification)
      config.defaults[module_name] = M.serialize(defaults)

      -- Make sure the module's config section exists
      config.values[module_name] = config.values[module_name] or {}

      -- Simplified and more robust default application function with recursion protection
      -- Simplified and more robust default application function
      local function apply_defaults(target, source, seen)
        -- Initialize tracking table on first call
        seen = seen or {}
        
        -- Validate input types
        if type(target) ~= "table" or type(source) ~= "table" then
          log("warn", "Invalid types in apply_defaults", {
            module = module_name,
            target_type = type(target),
            source_type = type(source)
          })
          return
        end
        
        -- Direct table reference check for cycle detection
        if seen[source] then
          log("warn", "Circular reference detected in apply_defaults", {
            module = module_name
          })
          return
        end
        
        -- Mark this source table as seen using direct reference
        seen[source] = true
        
        for k, v in pairs(source) do
          -- Check if key exists in target
          if target[k] == nil then
            -- No value exists, so copy from defaults
            if type(v) == "table" then
              target[k] = M.serialize(v) -- Use serialize for tables
            else
              target[k] = v -- Direct assignment for simple values
            end
            
            log("debug", "Applied default value for key", {
              module = module_name,
              key = k,
              value_type = type(v),
            })
          elseif type(target[k]) == "table" and type(v) == "table" then
            -- Both are tables, so merge recursively - pass the same seen table
            apply_defaults(target[k], v, seen)
          end
          -- If value exists and is not a table, keep the existing value
        end
      end
      apply_defaults(config.values[module_name], defaults)

      log("debug", "Applied defaults for module", {
        module = module_name,
        default_keys = table.concat(
          (function()
            local keys = {}
            for k, _ in pairs(defaults) do
              table.insert(keys, k)
            end
            return keys
          end)(),
          ", "
        ),
      })
    end
  end

  return M
end

--- Validates configuration against registered schemas
--- This function performs comprehensive validation of configuration values against
--- their registered schemas. It can validate a specific module or all modules with
--- registered schemas. The validation includes type checking, required fields verification,
--- range validation, pattern matching, enum value validation, and custom validator functions.
---
--- @param module_name? string The name of the module to validate (nil for all)
--- @return boolean valid Whether the configuration is valid
--- @return table|nil error Error if validation failed, with details on validation errors
---
--- @usage
--- -- Validate a specific module's configuration
--- local valid, err = central_config.validate("database")
--- if not valid then
---   print("Database configuration is invalid:")
---   for _, field_err in ipairs(err.context.errors) do
---     print("  - " .. field_err.field .. ": " .. field_err.message)
---   end
---   -- Use defaults or prompt for configuration
--- end
---
--- -- Validate all registered modules
--- local valid, err = central_config.validate()
--- if not valid then
---   print("Configuration validation failed:")
---   for module_name, module_errors in pairs(err.context.modules) do
---     print("Module: " .. module_name)
---     for _, field_err in ipairs(module_errors) do
---       print("  - " .. field_err.field .. ": " .. field_err.message)
---     end
---   end
--- end
---
--- -- Validate before saving configuration
--- local function save_if_valid(path)
---   if central_config.validate() then
---     return central_config.save_to_file(path)
---   else
---     return false, "Configuration validation failed"
---   end
--- end
function M.validate(module_name)
  -- Parameter validation
  if module_name ~= nil and type(module_name) ~= "string" then
    local err = error_handler.validation_error("Module name must be a string or nil", {
      parameter_name = "module_name",
      provided_type = type(module_name),
      operation = "validate",
    })
    log("warn", err.message, err.context)
    return false, err
  end

  local errors = {}

  local function validate_module(name)
    -- Verify the module exists in the schema registry
    local schema = config.schemas[name]
    if not schema then
      log("debug", "No schema registered for module", { module = name })
      return true
    end

    -- Get the current configuration for this module
    local module_config = M.get(name)
    if not module_config then
      -- No configuration for this module, which is valid
      return true
    end

    local module_errors = {}

    -- Basic structural validation (check required fields)
    if schema.required_fields then
      if type(schema.required_fields) ~= "table" then
        log("warn", "Invalid schema.required_fields format", {
          module = name,
          type = type(schema.required_fields),
        })
      else
        for _, field in ipairs(schema.required_fields) do
          if module_config[field] == nil then
            table.insert(module_errors, {
              field = field,
              message = "Required field missing",
            })
          end
        end
      end
    end

    -- Type validation
    if schema.field_types then
      if type(schema.field_types) ~= "table" then
        log("warn", "Invalid schema.field_types format", {
          module = name,
          type = type(schema.field_types),
        })
      else
        for field, expected_type in pairs(schema.field_types) do
          if module_config[field] ~= nil and type(module_config[field]) ~= expected_type then
            table.insert(module_errors, {
              field = field,
              message = "Field has wrong type",
              expected = expected_type,
              got = type(module_config[field]),
            })
          end
        end
      end
    end

    -- Range validation
    if schema.field_ranges then
      if type(schema.field_ranges) ~= "table" then
        log("warn", "Invalid schema.field_ranges format", {
          module = name,
          type = type(schema.field_ranges),
        })
      else
        for field, range in pairs(schema.field_ranges) do
          if type(range) ~= "table" then
            log("warn", "Invalid range specification", {
              module = name,
              field = field,
              range_type = type(range),
            })
          else
            local value = module_config[field]
            if value ~= nil and type(value) == "number" then
              if (range.min and value < range.min) or (range.max and value > range.max) then
                table.insert(module_errors, {
                  field = field,
                  message = "Field value out of range",
                  min = range.min,
                  max = range.max,
                  value = value,
                })
              end
            end
          end
        end
      end
    end

    -- Pattern validation
    if schema.field_patterns then
      if type(schema.field_patterns) ~= "table" then
        log("warn", "Invalid schema.field_patterns format", {
          module = name,
          type = type(schema.field_patterns),
        })
      else
        for field, pattern in pairs(schema.field_patterns) do
          if type(pattern) ~= "string" then
            log("warn", "Invalid pattern specification", {
              module = name,
              field = field,
              pattern_type = type(pattern),
            })
          else
            local value = module_config[field]
            if value ~= nil and type(value) == "string" then
              local success, result = error_handler.try(function()
                return string.match(value, pattern) ~= nil
              end)

              if not success then
                table.insert(module_errors, {
                  field = field,
                  message = "Invalid pattern: " .. result.message,
                  pattern = pattern,
                })
              elseif not result then
                table.insert(module_errors, {
                  field = field,
                  message = "Field value does not match pattern",
                  pattern = pattern,
                  value = value,
                })
              end
            end
          end
        end
      end
    end

    -- Value validation (enum-like)
    if schema.field_values then
      if type(schema.field_values) ~= "table" then
        log("warn", "Invalid schema.field_values format", {
          module = name,
          type = type(schema.field_values),
        })
      else
        for field, valid_values in pairs(schema.field_values) do
          if type(valid_values) ~= "table" then
            log("warn", "Invalid valid_values specification", {
              module = name,
              field = field,
              values_type = type(valid_values),
            })
          else
            local value = module_config[field]
            if value ~= nil then
              local valid = false
              for _, valid_value in ipairs(valid_values) do
                if value == valid_value then
                  valid = true
                  break
                end
              end

              if not valid then
                table.insert(module_errors, {
                  field = field,
                  message = "Field has invalid value",
                  valid_values = valid_values,
                  value = value,
                })
              end
            end
          end
        end
      end
    end

    -- Custom validators
    if schema.validators then
      if type(schema.validators) ~= "table" then
        log("warn", "Invalid schema.validators format", {
          module = name,
          type = type(schema.validators),
        })
      else
        for field, validator in pairs(schema.validators) do
          if type(validator) ~= "function" then
            log("warn", "Invalid validator specification", {
              module = name,
              field = field,
              validator_type = type(validator),
            })
          else
            local value = module_config[field]
            if value ~= nil then
              local success, result, message = error_handler.try(function()
                return validator(value, module_config)
              end)

              if not success then
                table.insert(module_errors, {
                  field = field,
                  message = "Validator error: " .. result.message,
                  value = value,
                })
              elseif not result then
                table.insert(module_errors, {
                  field = field,
                  message = message or "Failed custom validation",
                  value = value,
                })
              end
            end
          end
        end
      end
    end

    -- Store errors if any
    if #module_errors > 0 then
      errors[name] = module_errors
      return false
    end

    return true
  end

  -- Validate specific module if provided
  if module_name then
    local result = validate_module(module_name)
    if result then
      return true
    else
      local validation_error =
        error_handler.validation_error("Configuration validation failed for module: " .. module_name, {
          module = module_name,
          errors = errors[module_name],
        })
      return false, validation_error
    end
  end

  -- Validate all registered modules
  local all_valid = true
  for name in pairs(config.schemas) do
    if not validate_module(name) then
      all_valid = false
    end
  end

  -- Return validation result
  if all_valid then
    return true
  else
    -- Create error object
    local validation_error = error_handler.validation_error("Configuration validation failed for multiple modules", {
      modules = errors,
    })
    return false, validation_error
  end
end

--- Loads configuration from a file and merges it with existing configuration
--- This function loads configuration data from a Lua file and merges it with the
--- current configuration. The file is expected to return a table containing
--- configuration data. If the file doesn't exist, it's not considered an error
--- (the function simply logs the case and continues with existing configuration).
---
--- @param path? string The path to the configuration file (defaults to DEFAULT_CONFIG_PATH)
--- @return table|nil config The loaded configuration or nil if failed
--- @return table|nil error Error if any occurred
---
--- @usage
--- -- Load from default configuration path
--- local config, err = central_config.load_from_file()
--- if not config then
---   if err.message:match("not found") then
---     print("No configuration file found, using defaults")
---   else
---     print("Error loading configuration: " .. err.message)
---   end
--- end
---
--- -- Load from custom path
--- local config, err = central_config.load_from_file("/etc/myapp/config.lua")
--- if config then
---   print("Configuration loaded successfully")
--- end
---
--- -- Load with validation
--- local config, err = central_config.load_from_file()
--- if config then
---   local valid, validate_err = central_config.validate()
---   if not valid then
---     print("Loaded config is invalid: " .. validate_err.message)
---   end
--- end
function M.load_from_file(path)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error("Path must be a string or nil", {
      parameter_name = "path",
      provided_type = type(path),
      operation = "load_from_file",
    })
    log("warn", err.message, err.context)
    return nil, err
  end

  path = path or M.DEFAULT_CONFIG_PATH
  local fs = get_fs()

  -- Check if filesystem module is available
  if not fs then
    local err = error_handler.io_error("Filesystem module not available for loading config", {
      path = path,
      operation = "load_from_file",
    })
    log("error", err.message, err.context)
    return nil, err
  end

  -- Use safe_io_operation for checking if file exists
  local exists, err = error_handler.safe_io_operation(function()
    return fs.file_exists(path)
  end, path, { operation = "check_file_exists" })

  if err then
    log("error", "Error checking if config file exists", {
      path = path,
      error = err.message,
    })
    return nil, err
  end

  if not exists then
    -- This is a normal case - config file is optional
    log("info", "Config file not found, using defaults", {
      path = path,
      operation = "load_from_file",
    })
    -- Create a proper error object for tests
    local err = error_handler.io_error("Config file not found", {
      path = path,
      operation = "load_from_file",
    })
    return nil, err -- Return nil, err to indicate file not found
  end

  -- Try to load the configuration file
  local success, user_config, err = error_handler.try(function()
    return dofile(path)
  end)

  if not success then
    -- Handle the case where err might not be a structured error
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    local error_message = error_handler.is_error(err) and err.message or tostring(err)
    local parse_err = error_handler.parse_error("Error loading config file: " .. error_message, {
      path = path,
      operation = "load_from_file",
    }, error_handler.is_error(err) and err or nil)
    log("warn", parse_err.message, parse_err.context)
    return nil, parse_err
  end

  if type(user_config) ~= "table" then
    local format_err =
      error_handler.validation_error("Invalid config format: expected a table, got " .. type(user_config), {
        path = path,
        expected = "table",
        got = type(user_config),
        operation = "load_from_file",
      })
    log("error", format_err.message, format_err.context)
    return nil, format_err
  end

  -- Apply loaded configuration
  local old_config = M.serialize(config.values)
  -- Store and apply the loaded configuration
  local merged_config, err = deep_merge(config.values, user_config)
  if err then
    log("error", "Failed to merge configuration", {
      path = path,
      error = err.message,
    })
    return nil, err
  end

  config.values = merged_config
  log("debug", "Config file loaded successfully", { path = path })

  -- Notify listeners of all changed paths
  local function notify_changes(prefix, old, new)
    if type(old) ~= "table" or type(new) ~= "table" then
      if not deep_equals(old, new) then
        M.notify_change(prefix, old, new)
      end
      return
    end

    -- Notify about changed or added keys
    for k, v in pairs(new) do
      local new_prefix = prefix == "" and k or (prefix .. "." .. k)
      notify_changes(new_prefix, old[k], v)
    end

    -- Notify about removed keys
    for k, v in pairs(old) do
      if new[k] == nil then
        local new_prefix = prefix == "" and k or (prefix .. "." .. k)
        M.notify_change(new_prefix, v, nil)
      end
    end
  end

  notify_changes("", old_config, config.values)

  return user_config
end

--- Saves the current configuration to a file
--- This function serializes the current configuration state to a Lua file that can
--- later be loaded with load_from_file(). The configuration is saved as a Lua table
--- with sorted keys for readability and consistency. The function creates any parent
--- directories needed and handles filesystem errors properly.
---
--- @param path? string The path to save the configuration to (defaults to DEFAULT_CONFIG_PATH)
--- @return boolean success Whether the save was successful
--- @return table|nil error Error if any occurred
---
--- @usage
--- -- Save to default configuration file
--- local success, err = central_config.save_to_file()
--- if not success then
---   print("Failed to save configuration: " .. err.message)
--- end
---
--- -- Save to a specific path
--- local success, err = central_config.save_to_file("/etc/myapp/config.lua")
--- if success then
---   print("Configuration saved to " .. path)
--- end
---
--- -- Save with validation check
--- if central_config.validate() then
---   central_config.save_to_file()
--- else
---   print("Cannot save: configuration is invalid")
--- end
---
--- -- Save after making changes
--- central_config.set("logging.level", "debug")
---   .set("app.name", "MyApp")
---   .set("app.version", "1.0.0")
---   .save_to_file()
function M.save_to_file(path)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error("Path must be a string or nil", {
      parameter_name = "path",
      provided_type = type(path),
      operation = "save_to_file",
    })
    log("warn", err.message, err.context)
    return false, err
  end

  path = path or M.DEFAULT_CONFIG_PATH
  local fs = get_fs()

  -- Check if filesystem module is available
  if not fs then
    local err = error_handler.io_error("Filesystem module not available for saving config", {
      path = path,
      operation = "save_to_file",
    })
    log("error", err.message, err.context)
    return false, err
  end

  -- Generate Lua code for the configuration
  local function serialize(tbl, indent)
    -- Validate input
    if type(tbl) ~= "table" then
      return nil,
        error_handler.validation_error("Cannot serialize non-table value", {
          provided_type = type(tbl),
          operation = "serialize",
        })
    end

    indent = indent or ""
    local result = "{\n"

    -- Sort keys for deterministic output
    local keys = {}
    for k in pairs(tbl) do
      table.insert(keys, k)
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
      local v = tbl[k]
      local key_str

      -- Format key based on type
      if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
        key_str = k
      elseif type(k) == "string" then
        key_str = string.format("[%q]", k)
      elseif type(k) == "number" then
        key_str = string.format("[%d]", k)
      else
        -- Skip non-string/non-number keys
        log("warn", "Skipping unsupported key type in serialization", {
          key_type = type(k),
          operation = "serialize",
        })
        goto continue
      end

      -- Format value based on type
      if type(v) == "table" then
        local serialized_value, err = serialize(v, indent .. "  ")
        if err then
          return nil, err
        end
        result = result .. indent .. "  " .. key_str .. " = " .. serialized_value .. ",\n"
      elseif type(v) == "string" then
        result = result .. indent .. "  " .. key_str .. " = " .. string.format("%q", v) .. ",\n"
      elseif type(v) == "number" or type(v) == "boolean" then
        result = result .. indent .. "  " .. key_str .. " = " .. tostring(v) .. ",\n"
      elseif type(v) == "nil" then
        result = result .. indent .. "  " .. key_str .. " = nil,\n"
      else
        -- Skip unsupported types (function, userdata, thread)
        log("warn", "Skipping unsupported value type in serialization", {
          key = tostring(k),
          value_type = type(v),
          operation = "serialize",
        })
      end

      ::continue::
    end

    result = result .. indent .. "}"
    return result
  end

  -- Create a copy of the config to serialize
  local config_to_save = M.serialize(config.values)

  -- Generate Lua code
  local serialized_config, err = serialize(config_to_save)
  if not serialized_config then
    log("error", "Failed to serialize configuration", {
      path = path,
      ---@diagnostic disable-next-line: need-check-nil
      error = err.message,
    })
    return false, err
  end

  local content = "-- firmo configuration file\n"
  content = content .. "-- This file was automatically generated\n\n"
  content = content .. "return " .. serialized_config .. "\n"

  -- Write to file using safe_io_operation
  local success, err = error_handler.safe_io_operation(function()
    return fs.write_file(path, content)
  end, path, { operation = "write_config_file" })

  if not success then
    log("error", "Failed to save config file", {
      path = path,
      error = err.message,
    })
    return false, err
  end

  log("info", "Configuration saved to file", { path = path })
  return true
end

--- Resets configuration values to their defaults
--- This function resets configuration values to their default values as registered
--- with register_module(). It can reset a specific module's configuration or the
--- entire configuration system. If no defaults are available for a module, its
--- configuration will be cleared. The function notifies any listeners of the changes.
---
--- @param module_name? string The name of the module to reset (nil for all)
--- @return central_config The module instance for chaining
---
--- @usage
--- -- Reset a specific module's configuration
--- central_config.reset("logging")
---
--- -- Reset after changing settings temporarily
--- local original_level = central_config.get("logging.level")
--- central_config.set("logging.level", "debug")
--- -- Do some debug operations...
--- central_config.reset("logging") -- Restore defaults including original level
---
--- -- Reset the entire configuration system
--- central_config.reset()
---
--- -- Reset as part of a chain of operations
--- central_config.reset("database")
---   .set("database.timeout", 60)
---   .set("database.retries", 3)
function M.reset(module_name)
  -- Prevent recursive resets
  if config.resetting then
    return M
  end
  
  -- Set resetting flag
  config.resetting = true

  -- Parameter validation
  if module_name ~= nil and type(module_name) ~= "string" then
    local err = error_handler.validation_error("Module name must be a string or nil", {
      parameter_name = "module_name",
      provided_type = type(module_name),
      operation = "reset",
    })
    log("warn", err.message, err.context)
    config.resetting = false -- Clear flag before returning
    return M
  end

  -- If module_name is nil, completely reset everything
  if module_name == nil then
    -- Reset everything for testing
    local old_values = M.serialize(config.values)
    -- Clear all configuration data structures with a single operation
    config.values = {}
    config.schemas = {}
    config.listeners = {}
    config.defaults = {}

    log("info", "Reset entire configuration system for testing")

    -- No listeners to notify after full reset since they were cleared too
    config.resetting = false -- Clear flag before returning
    return M
  end

  -- Reset specific module
  if not config.defaults[module_name] then
    -- If there are no defaults, just clear the module's configuration
    if config.values[module_name] then
      -- Store old config for change notifications
      local old_config = M.serialize(config.values[module_name])
      -- Clear the module's config
      config.values[module_name] = {}

      log("info", "Cleared configuration for module (no defaults)", { module = module_name })

      -- Notify listeners
      M.notify_change(module_name, old_config, config.values[module_name])
    else
      log("debug", "No configuration or defaults to reset for module", { module = module_name })
    end

    config.resetting = false -- Clear flag before returning
    return M
  end

  -- Copy the old configuration for change detection
  local old_config = M.serialize(config.values[module_name])

  -- Reset to defaults (with deep copy to prevent modification of defaults)
  config.values[module_name] = M.serialize(config.defaults[module_name])
  log("info", "Reset configuration for module to defaults", {
    module = module_name,
    default_count = (function()
      local count = 0
      for _, _ in pairs(config.defaults[module_name]) do
        count = count + 1
      end
      return count
    end)(),
  })

  -- Notify listeners of change
  M.notify_change(module_name, old_config, config.values[module_name])

  -- Clear resetting flag before returning
  config.resetting = false
  return M
end

--- Configures the system from command-line or program options
--- This function applies configuration values from a table of options, typically coming from
--- command-line arguments or program initialization parameters. It only processes options
--- that follow the "module.setting" dot notation format, ignoring other entries. The function
--- safely applies each valid option, logging warnings for any options that fail to apply.
---
--- @param options table Table of options from CLI or other source
--- @return central_config The module instance for chaining
---
--- @usage
--- -- Configure from command-line arguments
--- local opts = {
---   ["logging.level"] = "debug",
---   ["coverage.enabled"] = true,
---   ["reporting.format"] = "junit",
---   non_config_option = "value" -- This will be ignored (no dot)
--- }
--- central_config.configure_from_options(opts)
---
--- -- Configure from parsed CLI options
--- local function parse_cli()
---   local options = {}
---   for i = 1, #arg do
---     local key, value = arg[i]:match("^%-%-([%w%.]+)=(.+)$")
---     if key and key:find("%.") then
---       -- Convert value types
---       if value == "true" then value = true
---       elseif value == "false" then value = false
---       elseif tonumber(value) then value = tonumber(value)
---       end
---       options[key] = value
---     end
---   end
---   return options
--- end
---
--- central_config.configure_from_options(parse_cli())
function M.configure_from_options(options)
  -- Parameter validation
  if options == nil then
    log("debug", "No options provided to configure_from_options")
    return M
  end

  if type(options) ~= "table" then
    local err = error_handler.validation_error("Options must be a table", {
      parameter_name = "options",
      provided_type = type(options),
      operation = "configure_from_options",
    })
    log("warn", err.message, err.context)
    return M
  end

  -- Process options using error_handler.try to catch any errors
  for k, v in pairs(options) do
    -- Only handle options with module.option format
    if type(k) == "string" and string.find(k, "%.") then
      local success, err = error_handler.try(function()
        M.set(k, v)
      end)

      if not success then
        log("warn", "Failed to set option", {
          key = k,
          value_type = type(v),
          error = err.message,
        })
      end
    end
  end

  log("debug", "Applied configuration from options")
  return M
end

--- Configures the system from a global configuration object
--- This function merges a complete configuration object into the current configuration.
--- Unlike configure_from_options() which handles individual key-value pairs, this function
--- takes a complete, potentially nested configuration structure and merges it with the
--- existing configuration. This is useful for initializing configuration from a predefined
--- state or applying configuration presets.
---
--- @param global_config table Global configuration table to apply
--- @return central_config The module instance for chaining
---
--- @usage
--- -- Configure from a predefined configuration structure
--- local default_config = {
---   logging = {
---     level = "info",
---     format = "text",
---     file = nil
---   },
---   coverage = {
---     enabled = true,
---     include = {"src/**/*.lua"},
---     exclude = {"test/**/*.lua"}
---   },
---   testing = {
---     timeout = 5000,
---     parallel = false
---   }
--- }
--- central_config.configure_from_config(default_config)
---
--- -- Load a configuration preset and apply it
--- local function load_preset(preset_name)
---   local presets = {
---     development = { logging = { level = "debug" }, coverage = { enabled = true } },
---     production = { logging = { level = "error" }, coverage = { enabled = false } },
---     testing = { logging = { level = "info" }, coverage = { enabled = true } }
---   }
---   return presets[preset_name] or {}
--- end
---
--- central_config.configure_from_config(load_preset("development"))
function M.configure_from_config(global_config)
  -- Parameter validation
  if global_config == nil then
    log("debug", "No global config provided to configure_from_config")
    return M
  end

  if type(global_config) ~= "table" then
    local err = error_handler.validation_error("Global config must be a table", {
      parameter_name = "global_config",
      provided_type = type(global_config),
      operation = "configure_from_config",
    })
    log("warn", err.message, err.context)
    return M
  end

  -- Merge global config into our config with error handling
  local merged_config, err = deep_merge(config.values, global_config)
  if err then
    log("error", "Failed to merge global configuration", {
      error = err.message,
    })
    return M
  end

  config.values = merged_config
  log("debug", "Applied configuration from global config")

  return M
end

-- Export public interface with error handling wrappers

--- Creates a deep copy of an object
--- This function creates a complete deep copy of the provided object, ensuring that
--- modifications to the returned object don't affect the original. It's particularly
--- useful for tables, where it recursively copies all nested tables. For non-table
--- values, it simply returns the value itself. This function is safe to use with any
--- value type and handles nil values appropriately.
---
--- @param obj any Object to serialize (deep copy)
--- @return any Serialized (deep-copied) object
---
--- @usage
--- -- Deep copy a configuration table
--- local original_config = {
---   logging = { level = "info", format = "json" },
---   cache = { enabled = true, ttl = 3600 }
--- }
--- local config_copy = central_config.serialize(original_config)
---
--- -- Modify the copy without affecting the original
--- config_copy.logging.level = "debug"
--- print(original_config.logging.level) -- Still "info"
---
--- -- Safe to use with any value type
--- local str_copy = central_config.serialize("hello") -- Returns "hello"
--- local num_copy = central_config.serialize(42) -- Returns 42
--- local nil_copy = central_config.serialize(nil) -- Returns nil
--- Creates a deep copy of an object with cycle detection
--- This function creates a complete deep copy of the provided object, ensuring that
--- modifications to the returned object don't affect the original. It's particularly
--- useful for tables, where it recursively copies all nested tables. For non-table
--- values, it simply returns the value itself.
---
--- The function creates a fresh cycle detection cache for each call, which allows
--- it to safely handle circular references in tables and prevents infinite recursion,
--- while avoiding memory leaks between operations.
---
--- @param obj any Object to serialize (deep copy)
--- @return any Serialized (deep-copied) object
M.serialize = function(obj)
  -- Handle non-tables directly for better performance
  if type(obj) ~= "table" then
    return obj
  end
  
  -- Create a new cache for this copy operation to prevent memory leaks
  local cache = {}
  
  local result = deep_copy(obj, cache)
  if type(result) ~= "table" and obj ~= nil then
    log("warn", "serialize was called on a non-table value", {
      value_type = type(obj),
    })
  end
  return result
end

--- Deeply merges two tables together
--- This function recursively merges the source table into the target table. For overlapping
--- keys that contain tables in both source and target, it performs a deep merge. For other
--- value types or when a key exists only in one table, the source value takes precedence.
--- If an error occurs during merging, the function logs the error and returns the original
--- target table unmodified.
---
--- @param target table Target table to merge into
--- @param source table Source table to merge from
--- @return table Merged result
---
--- @usage
--- -- Merge configuration tables
--- local base_config = {
---   logging = { level = "info", format = "text" },
---   timeouts = { connection = 30, request = 10 }
--- }
---
--- local overrides = {
---   logging = { level = "debug" }, -- Only override the level
---   database = { host = "localhost", port = 5432 } -- Add new section
--- }
---
--- local merged = central_config.merge(base_config, overrides)
--- -- Result:
--- -- {
--- --   logging = { level = "debug", format = "text" },
--- --   timeouts = { connection = 30, request = 10 },
--- --   database = { host = "localhost", port = 5432 }
--- -- }
---
--- -- Merge with error handling
--- local function safe_merge(target, source)
---   if type(target) ~= "table" or type(source) ~= "table" then
---     return central_config.serialize(source or target)
---   end
---   return central_config.merge(target, source)
--- end
M.merge = function(target, source)
  local result, err = deep_merge(target, source)
  if err then
    log("error", "Error in merge operation", {
      error = err.message,
      target_type = type(target),
      source_type = type(source),
    })
    return target
  end
  return result
end

--- Module initialization function
--- This private function initializes the central configuration module, setting up
--- its default configuration and registering it with itself. It uses error handling
--- to ensure the module is always returned, even if initialization fails, preventing
--- application crashes. This function is called automatically when the module is required.
---
--- @private
--- @return central_config Initialized module
local function init()
  -- Initialize with proper error handling
  local success, err = error_handler.try(function()
    -- Register this module's defaults
    M.register_module("central_config", {
      -- Schema
      required_fields = {},
      field_types = {
        auto_save = "boolean",
        config_path = "string",
      },
    }, {
      -- Defaults
      auto_save = false,
      config_path = M.DEFAULT_CONFIG_PATH,
    })

    log("debug", "Centralized configuration module initialized")

    return M
  end)

  if not success then
    log("error", "Failed to initialize central_config module", {
      error = err.message,
      traceback = err.traceback,
    })
    -- Return module anyway to prevent crashes
  end

  return M
end

return init()
