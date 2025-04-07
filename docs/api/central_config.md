# Central Configuration API Reference

The `central_config` module provides a comprehensive, hierarchical configuration system for the firmo framework. It serves as a centralized store for all configuration settings, with support for schema validation, change notifications, and persistent storage.

## Importing the Module

```lua
local central_config = require("lib.core.central_config")
```

## Core Functions

### Getting Configuration Values

```lua
local value = central_config.get(path, default)
```

Gets a configuration value from the specified path.

**Parameters:**
- `path` (string|nil): The dot-separated path to the configuration value (e.g., "coverage.threshold"). If nil or empty, returns the entire configuration.
- `default` (any, optional): The default value to return if the path doesn't exist.

**Returns:**
- `value` (any): The configuration value at the specified path, or the default value if not found.
- `error` (table|nil): An error object if an error occurred.

**Examples:**
```lua
-- Get a simple value with default
local debug_mode = central_config.get("debug", false)

-- Get a nested value
local threshold = central_config.get("coverage.threshold", 90)

-- Get an entire section
local coverage_config = central_config.get("coverage")

-- Get the entire configuration
local full_config = central_config.get()
```

### Setting Configuration Values

```lua
central_config.set(path, value)
```

Sets a configuration value at the specified path.

**Parameters:**
- `path` (string|nil): The dot-separated path to set the value at. If nil or empty, sets the entire configuration.
- `value` (any): The value to set at the specified path.

**Returns:**
- `central_config`: The module instance for method chaining.

**Examples:**
```lua
-- Set a simple value
central_config.set("debug", true)

-- Set a nested value
central_config.set("coverage.threshold", 95)

-- Set an entire section
central_config.set("coverage", {
  threshold = 95,
  include = {"lib/**/*.lua"},
  exclude = {"tests/**/*.lua"}
})

-- Set the entire configuration
central_config.set({
  debug = true,
  coverage = {
    threshold = 95
  }
})

-- Method chaining
central_config
  .set("coverage.threshold", 95)
  .set("reporting.format", "html")
```

### Deleting Configuration Values

```lua
local success, err = central_config.delete(path)
```

Deletes a configuration value at the specified path.

**Parameters:**
- `path` (string): The dot-separated path to delete the value at.

**Returns:**
- `success` (boolean): Whether the deletion was successful.
- `error` (table|nil): An error object if an error occurred.

**Examples:**
```lua
-- Delete a configuration value
local success, err = central_config.delete("temporary.setting")
if not success then
  print("Error deleting value: " .. err.message)
end
```

### Registering for Change Notifications

```lua
central_config.on_change(path, callback)
```

Registers a callback to be notified when a configuration value changes.

**Parameters:**
- `path` (string|nil): The dot-separated path to listen for changes on. If nil or empty, listens for all changes.
- `callback` (function): Function to call when a value changes, with signature `function(path, old_value, new_value)`.

**Returns:**
- `central_config`: The module instance for method chaining.

**Examples:**
```lua
-- Listen for changes to a specific value
central_config.on_change("coverage.threshold", function(path, old_value, new_value)
  print("Coverage threshold changed from " .. old_value .. " to " .. new_value)
end)

-- Listen for changes to an entire section
central_config.on_change("coverage", function(path, old_value, new_value)
  print("Coverage configuration changed at " .. path)
end)

-- Listen for all changes
central_config.on_change("", function(path, old_value, new_value)
  print("Configuration changed at " .. path)
end)
```

### Notifying of Changes

```lua
central_config.notify_change(path, old_value, new_value)
```

Notifies listeners about a configuration change.

**Parameters:**
- `path` (string): The dot-separated path that changed.
- `old_value` (any): The previous value.
- `new_value` (any): The new value.

**Returns:** None

**Examples:**
```lua
-- Manually notify about a change (rarely needed)
central_config.notify_change("coverage.threshold", 90, 95)
```

## Module Registration

### Registering a Module

```lua
central_config.register_module(module_name, schema, defaults)
```

Registers a module with the configuration system, providing its schema and default values.

**Parameters:**
- `module_name` (string): The name of the module to register.
- `schema` (table|nil, optional): Schema definition for validation.
- `defaults` (table|nil, optional): Default values for the module.

**Returns:**
- `central_config`: The module instance for method chaining.

**Examples:**
```lua
-- Register a module with schema and defaults
central_config.register_module("logging", {
  -- Schema definition
  required_fields = {"level"},
  field_types = {
    level = "string",
    file = "string",
    format = "string"
  },
  field_values = {
    level = {"debug", "info", "warn", "error"},
    format = {"text", "json"}
  }
}, {
  -- Default values
  level = "info",
  format = "text"
})

-- Register just defaults (no schema validation)
central_config.register_module("cache", nil, {
  ttl = 3600,
  max_size = 1024
})
```

### Schema Definition

A schema is a table with the following fields:

- `required_fields` (table): Array of field names that must be present.
- `field_types` (table): Mapping of field names to expected types.
- `field_ranges` (table): Mapping of numeric fields to their valid ranges.
- `field_patterns` (table): Mapping of string fields to pattern validation.
- `field_values` (table): Mapping of fields to their allowed values (enum-like).
- `validators` (table): Mapping of fields to custom validator functions.

**Example Schema:**
```lua
{
  required_fields = {"api_key", "username"},
  
  field_types = {
    api_key = "string",
    username = "string",
    timeout = "number",
    debug = "boolean"
  },
  
  field_ranges = {
    timeout = {min = 1000, max = 30000}
  },
  
  field_patterns = {
    api_key = "^[A-Za-z0-9]+$"
  },
  
  field_values = {
    log_level = {"debug", "info", "warn", "error"}
  },
  
  validators = {
    custom_field = function(value, all_config) 
      if value >= all_config.some_threshold then
        return true
      else
        return false, "Value must be >= some_threshold"
      end
    end
  }
}
```

## Validation

### Validating Configuration

```lua
local valid, err = central_config.validate(module_name)
```

Validates configuration against registered schemas.

**Parameters:**
- `module_name` (string|nil, optional): The name of the module to validate. If nil, validates all modules.

**Returns:**
- `valid` (boolean): Whether the configuration is valid.
- `error` (table|nil): An error object if validation failed.

**Examples:**
```lua
-- Validate a specific module
local valid, err = central_config.validate("database")
if not valid then
  print("Invalid database configuration: " .. err.message)
end

-- Validate all configuration
local valid, err = central_config.validate()
if not valid then
  print("Invalid configuration: " .. err.message)
  for module_name, module_errors in pairs(err.context.modules) do
    print("Module: " .. module_name)
    for _, field_error in ipairs(module_errors) do
      print("  - " .. field_error.field .. ": " .. field_error.message)
    end
  end
end
```

## File Operations

### Loading from a File

```lua
local config, err = central_config.load_from_file(path)
```

Loads configuration from a file and merges it with the existing configuration.

**Parameters:**
- `path` (string|nil, optional): Path to the configuration file. Defaults to `DEFAULT_CONFIG_PATH`.

**Returns:**
- `config` (table|nil): The loaded configuration or nil if failed.
- `error` (table|nil): An error object if an error occurred.

**Examples:**
```lua
-- Load from default path (.firmo-config.lua)
local config, err = central_config.load_from_file()
if not config then
  print("Failed to load config: " .. err.message)
end

-- Load from custom path
local config, err = central_config.load_from_file("/path/to/config.lua")
if not config then
  print("Failed to load config from custom path: " .. err.message)
end
```

### Saving to a File

```lua
local success, err = central_config.save_to_file(path)
```

Saves the current configuration to a file.

**Parameters:**
- `path` (string|nil, optional): Path to save the configuration to. Defaults to `DEFAULT_CONFIG_PATH`.

**Returns:**
- `success` (boolean): Whether the save was successful.
- `error` (table|nil): An error object if an error occurred.

**Examples:**
```lua
-- Save to default path
local success, err = central_config.save_to_file()
if not success then
  print("Failed to save config: " .. err.message)
end

-- Save to custom path
local success, err = central_config.save_to_file("/path/to/config.lua")
if not success then
  print("Failed to save config to custom path: " .. err.message)
end
```

## Reset Functions

### Resetting Configuration

```lua
central_config.reset(module_name)
```

Resets configuration values to their defaults.

**Parameters:**
- `module_name` (string|nil, optional): The name of the module to reset. If nil, resets all configuration.

**Returns:**
- `central_config`: The module instance for method chaining.

**Examples:**
```lua
-- Reset a specific module
central_config.reset("coverage")

-- Reset all configuration
central_config.reset()
```

## Integration Functions

### Configuring from Options

```lua
central_config.configure_from_options(options)
```

Configures the system from a table of options, typically from command-line arguments.

**Parameters:**
- `options` (table): Table of options from CLI or other source.

**Returns:**
- `central_config`: The module instance for method chaining.

**Examples:**
```lua
-- Configure from command-line options
local options = {
  ["coverage.threshold"] = 95,
  ["reporting.format"] = "html",
  debug = true
}
central_config.configure_from_options(options)
```

### Configuring from Config

```lua
central_config.configure_from_config(global_config)
```

Configures the system from a complete configuration object.

**Parameters:**
- `global_config` (table): Global configuration table to apply.

**Returns:**
- `central_config`: The module instance for method chaining.

**Examples:**
```lua
-- Configure from a complete configuration object
local config = {
  debug = true,
  coverage = {
    threshold = 95,
    include = {"lib/**/*.lua"}
  },
  reporting = {
    format = "html"
  }
}
central_config.configure_from_config(config)
```

## Utility Functions

### Serializing Objects

```lua
local copy = central_config.serialize(obj)
```

Creates a deep copy of an object.

**Parameters:**
- `obj` (any): Object to serialize (deep copy).

**Returns:**
- `copy` (any): The serialized (deep-copied) object.

**Examples:**
```lua
-- Deep copy a configuration table
local config_copy = central_config.serialize(central_config.get("coverage"))
config_copy.threshold = 95  -- Modify the copy without affecting the original
```

### Merging Tables

```lua
local merged = central_config.merge(target, source)
```

Deeply merges two tables together.

**Parameters:**
- `target` (table): Target table to merge into.
- `source` (table): Source table to merge from.

**Returns:**
- `merged` (table): The merged result.

**Examples:**
```lua
-- Merge configuration tables
local base_config = {
  logging = { level = "info" }
}
local override = {
  logging = { format = "json" }
}
local merged = central_config.merge(base_config, override)
-- Result: { logging = { level = "info", format = "json" } }
```

## Constants

### Default Configuration Path

```lua
central_config.DEFAULT_CONFIG_PATH  -- ".firmo-config.lua"
```

The default path for configuration files.

### Error Types

```lua
central_config.ERROR_TYPES.VALIDATION  -- Maps to error_handler.CATEGORY.VALIDATION
central_config.ERROR_TYPES.ACCESS      -- Maps to error_handler.CATEGORY.VALIDATION
central_config.ERROR_TYPES.IO          -- Maps to error_handler.CATEGORY.IO
central_config.ERROR_TYPES.PARSE       -- Maps to error_handler.CATEGORY.PARSE
```

Error categories for different error types, mapping to error_handler categories.

## Module Version

```lua
central_config._VERSION  -- e.g., "0.3.0"
```

The version of the central_config module.