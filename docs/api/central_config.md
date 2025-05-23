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

- `value` (any): A **deep copy** of the configuration value found at `path`, or the `default` value if not found. Returns `nil` if not found and no default is provided (error will also be returned).
- `error` (table|nil): An error object (conforming to `error_handler` structure with `message` and `context`) if the path is invalid or not found (and no default was provided), otherwise `nil`.

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

Sets a configuration value at the specified path. Note: If `value` is a table, a deep copy is made before storing to prevent modifications by reference. If `path` is nil or empty, the entire configuration is replaced (value must be a table).
**Parameters:**

- `path` (string|nil): The dot-separated path to set the value at. If nil or empty, sets the entire configuration.
- `value` (any): The value to set at the specified path.

**Returns:**

- `central_config`: The module instance for method chaining.
**Note:** Logs a warning internally if the path is invalid or setting fails, but does not throw an error.

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
**Note:** Logs a warning internally if arguments are invalid.

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

**Returns:** `nil`
**Note:** Listener callbacks are executed safely using `error_handler.try`; errors within callbacks are logged but do not stop other listeners or the configuration system. Logs a warning internally if arguments are invalid.

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
**Note:** The provided `schema` and `defaults` tables are deeply copied (`serialize`) internally before being stored. Logs an error or warning internally if arguments are invalid.

**Examples:**

```lua
-- Register coverage module with schema and defaults
central_config.register_module("coverage", {
  -- Schema definition for coverage
  field_types = {
    enabled = "boolean",
    include_patterns = "table",
    exclude_patterns = "table",
    statsfile = "string",
    thresholds = "table"
  },
  field_types_nested = {
    ["thresholds.line"] = "number",
    ["thresholds.function"] = "number",
    ["thresholds.fail_on_threshold"] = "boolean"
  },
  validators = {
    include_patterns = function(value)
      if type(value) ~= "table" then return false, "Must be a table of patterns" end
      for i, pattern in ipairs(value) do
        if type(pattern) ~= "string" then
          return false, "Pattern at index " .. i .. " must be a string"
        end
      end
      return true
    end,
    thresholds = function(value)
      if type(value) ~= "table" then return true end -- Optional field
      if type(value.line) ~= "nil" and (value.line < 0 or value.line > 100) then
        return false, "Line threshold must be between 0 and 100"
      end
      if type(value.function) ~= "nil" and (value.function < 0 or value.function > 100) then
        return false, "Function threshold must be between 0 and 100"
      end
      return true
    end
  }
}, {
  -- Default values for coverage
  enabled = true,
  include_patterns = {".*%.lua$"},
  exclude_patterns = {"tests/.*", "lib/vendor/.*"},
  statsfile = "./.coverage-stats",
  thresholds = {
    line = 75,
    function = 80,
    fail_on_threshold = false
  }
})
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
- `field_types_nested` (table): Mapping of nested field paths to expected types.
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

### Coverage Configuration Schema Example

The coverage module uses a comprehensive schema for validation:

```lua
{
  field_types = {
    enabled = "boolean",
    include_patterns = "table",  -- Array of Lua patterns to include
    exclude_patterns = "table",  -- Array of Lua patterns to exclude
    statsfile = "string",        -- Path to save coverage statistics
    thresholds = "table"         -- Coverage thresholds configuration
  },
  field_types_nested = {
    ["thresholds.line"] = "number",           -- Line coverage threshold (0-100)
    ["thresholds.function"] = "number",       -- Function coverage threshold (0-100)
    ["thresholds.fail_on_threshold"] = "boolean" -- Whether to fail tests when thresholds aren't met
  },
  validators = {
    -- Custom validators for complex validation logic
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
- `error` (table|nil): An error object if validation failed, otherwise `nil`. The `error.context` field contains detailed failure information, typically under `context.errors` (for single module) or `context.modules` (for all modules).
**Note:** Logs a warning internally if `module_name` argument is invalid.

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

Loads configuration from a file and merges it with the existing configuration. If the file is not found, it logs an informational message and returns `nil, error`. Changes resulting from merging the loaded file will trigger registered `on_change` listeners.
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

Saves the current configuration to a file. The configuration is serialized internally using `central_config.serialize` and written safely using `error_handler.safe_io_operation`.
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

Resets configuration values to their defaults. The system includes recursive reset protection to prevent infinite loops when configurations reference each other. If defaults were registered for the module, the configuration is reset to those defaults; otherwise, the module's configuration section is cleared. Changes trigger `on_change` listeners.
**Parameters:**

- `module_name` (string|nil, optional): The name of the module to reset. If nil, resets all configuration.

**Returns:**

- `central_config`: The module instance for method chaining.
**Note:** Logs a warning internally if `module_name` is provided but invalid.

**Examples:**

```lua
-- Reset a specific module
central_config.reset("coverage")
-- Reset all configuration
central_config.reset()
-- Reset protection example: prevent infinite reset loops
-- This is handled automatically by the system
central_config.on_change("module_a", function(path, old_value, new_value)
  -- Without reset protection, this would cause an infinite loop
  -- since resetting module_b would trigger the module_b listener,
  -- which would reset module_a again, and so on.
  central_config.reset("module_b")
end)
central_config.on_change("module_b", function(path, old_value, new_value)
  central_config.reset("module_a")
end)
-- Safe to call, won't cause infinite recursion:
central_config.reset("module_a")
```

```text

## Integration Functions

### Configuring from Options

```lua

central_config.configure_from_options(options)

```text
Configures the system from a table of options, typically from command-line arguments. It only processes options where the key follows the `\"module.setting\"` dot notation format, ignoring other entries. Setting attempts are performed safely; errors are logged as warnings.
**Parameters:**

- `options` (table): Table of options from CLI or other source.

**Returns:**

- `central_config`: The module instance for method chaining.

**Examples:**
```lua

-- Configure from command-line options
local options = {
  ["coverage.thresholds.line"] = 95,
  ["coverage.thresholds.function"] = 90,
  ["coverage.include_patterns[1]"] = "lib/.*%.lua$",
  ["coverage.exclude_patterns[1]"] = "tests/.*",
  ["coverage.statsfile"] = "./.coverage-stats",
  ["reporting.format"] = "html",
  debug = true
}
central_config.configure_from_options(options)

```text

### Configuring from Config

```lua

central_config.configure_from_config(global_config)

```text
Configures the system from a complete configuration object. Uses `central_config.merge` internally. Errors during merging are logged.
**Parameters:**

- `global_config` (table): Global configuration table to apply.

**Returns:**

- `central_config`: The module instance for method chaining.

**Examples:**
```lua

```lua
-- Configure from a complete configuration object
local config = {
  debug = true,
  coverage = {
    enabled = true,
    -- Pattern-based include/exclude using Lua patterns
    include_patterns = {
      "lib/.*%.lua$",      -- All Lua files in lib directory
      "src/.*%.lua$"       -- All Lua files in src directory
    },
    exclude_patterns = {
      "tests/.*",          -- Exclude test files
      "lib/vendor/.*",     -- Exclude vendor files
      ".*_test%.lua$"      -- Exclude files ending with _test.lua
    },
    -- Debug hook system configuration
    savestepsize = 100,    -- Save stats every 100 lines
    tick = false,          -- Don't use tick-based saving
    codefromstrings = false, -- Don't track code loaded from strings
    -- Stats file configuration
    statsfile = "./.coverage-stats",
    -- Threshold configuration
    thresholds = {
      line = 85,             -- Minimum line coverage percentage
      function = 90,         -- Minimum function coverage percentage
      fail_on_threshold = true -- Fail tests if thresholds not met
    }
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

Creates a deep copy of an object, safely handling cycles.
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
**Note:** Errors during the merge process are logged internally, and the original `target` table is returned in case of failure.

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
