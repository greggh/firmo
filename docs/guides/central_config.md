# Central Configuration Guide


The central configuration system in Firmo provides a unified approach to managing configuration across all framework components. This guide explains how to use the system effectively in your projects.

## Introduction


Firmo's centralized configuration system replaces the legacy module-specific configuration approach, offering significant advantages:


- **Hierarchical Configuration**: Access configuration using intuitive dot notation
- **Schema Validation**: Verify configuration values against defined schemas
- **Change Notifications**: React to configuration changes in real-time
- **File-Based Persistence**: Load and save configuration from/to files
- **Consistent API**: All framework components use the same configuration interface


## Basic Usage


### Importing the Module



```lua
local central_config = require("lib.core.central_config")
```



### Getting Configuration Values


Access configuration values using the `get()` function with dot notation paths:


```lua
-- Get with default values (recommended)
local debug_mode = central_config.get("debug", false)
local timeout = central_config.get("http.timeout", 30)
-- Get nested configurations
local coverage_config = central_config.get("coverage")
local include_patterns = central_config.get("coverage.include", {})
-- Get the entire configuration
local full_config = central_config.get()
```


Always provide a default value as the second parameter to handle cases where the configuration value doesn't exist.

### Setting Configuration Values


Set configuration values using the `set()` function:


```lua
-- Set simple values
central_config.set("debug", true)
central_config.set("http.timeout", 60)
-- Set nested values
central_config.set("coverage.threshold", 95)
-- Set an entire section
central_config.set("database", {
  host = "localhost",
  port = 5432,
  username = "app_user",
  password = "secret"
})
-- Method chaining
central_config
  .set("debug", true)
  .set("coverage.threshold", 95)
```



### Deleting Configuration Values


Remove configuration values using the `delete()` function:


```lua
-- Delete a configuration value
local success, err = central_config.delete("temporary.setting")
if not success then
  print("Failed to delete: " .. err.message)
end
```



## Configuration Files


### Creating a Configuration File


Create a `.firmo-config.lua` file in your project root:


```lua
-- .firmo-config.lua
return {
  -- Core options
  debug = false,
  verbose = true,

  -- Coverage options
  coverage = {
    enabled = true,
    threshold = 90,
    include = { "lib/**/*.lua", "src/**/*.lua" },
    exclude = { "tests/**/*.lua", "examples/**/*.lua" }
  },

  -- Reporting options
  reporting = {
    format = "html",
    output_dir = "./coverage-reports",
    formatters = {
      html = {
        theme = "dark",
        title = "Coverage Report"
      }
    }
  }
}
```



### Loading Configuration from a File


Load configuration from a file using the `load_from_file()` function:


```lua
-- Load from default config file (.firmo-config.lua)
local config, err = central_config.load_from_file()
if not config then
  if err.message:match("not found") then
    print("No config file found, using defaults")
  else
    print("Error loading config: " .. err.message)
  end
end
-- Load from a specific file
local config, err = central_config.load_from_file("/path/to/custom-config.lua")
```



### Saving Configuration to a File


Save your current configuration to a file using the `save_to_file()` function:


```lua
-- Save to default config file
local success, err = central_config.save_to_file()
if not success then
  print("Failed to save config: " .. err.message)
end
-- Save to a specific file
local success, err = central_config.save_to_file("/path/to/saved-config.lua")
```



## Module Registration


Modules should register their configuration schema and defaults with the central configuration system.

### Registering a Module



```lua
central_config.register_module("my_module", {
  -- Schema definition
  required_fields = {"api_key"},
  field_types = {
    api_key = "string",
    timeout = "number",
    debug = "boolean"
  },
  field_ranges = {
    timeout = {min = 1000, max = 30000}
  }
}, {
  -- Default values
  timeout = 5000,
  debug = false
})
```



### Schema Definition


The schema table supports these validation options:


- `required_fields`: Array of field names that must be present
- `field_types`: Mapping of field names to expected types
- `field_ranges`: Numeric ranges for fields (min/max)
- `field_patterns`: String pattern validation for fields
- `field_values`: Allowed values for fields (enum-like)
- `validators`: Custom validator functions for complex validation

Example of a detailed schema:


```lua
{
  required_fields = {"api_key"},

  field_types = {
    api_key = "string",
    timeout = "number",
    debug = "boolean",
    log_level = "string"
  },

  field_ranges = {
    timeout = {min = 1000, max = 30000}
  },

  field_patterns = {
    api_key = "^[A-Za-z0-9]+$"  -- Only alphanumeric chars
  },

  field_values = {
    log_level = {"debug", "info", "warn", "error"}
  },

  validators = {
    custom_field = function(value, full_config)
      -- Custom validation logic
      if value >= full_config.some_threshold then
        return true
      else
        return false, "Value must be >= some_threshold"
      end
    end
  }
}
```



### Default Values


Provide reasonable defaults for your module:


```lua
{
  timeout = 5000,
  retry_count = 3,
  log_level = "info",
  cache_enabled = true,
  cache_ttl = 3600
}
```


Defaults will be applied when:


1. A user doesn't specify a value
2. The configuration is reset


## Change Notifications


The central configuration system can notify your code when configuration values change.

### Registering for Change Notifications



```lua
-- Listen for changes to a specific setting
central_config.on_change("coverage.threshold", function(path, old_value, new_value)
  print("Coverage threshold changed from " .. tostring(old_value) .. 
        " to " .. tostring(new_value))

  -- Update your module's behavior based on the new value
  update_coverage_requirement(new_value)
end)
-- Listen for changes to an entire section
central_config.on_change("database", function(path, old_value, new_value)
  -- The path parameter tells you exactly what changed
  if path == "database.host" or path == "database.port" then
    -- Reconnect to the database
    reconnect_to_database()
  end
end)
-- Listen for all configuration changes
central_config.on_change("", function(path, old_value, new_value)
  log_configuration_change(path, old_value, new_value)
end)
```



## Configuration Validation


Validate configuration values against registered schemas:


```lua
-- Validate a specific module's configuration
local valid, err = central_config.validate("database")
if not valid then
  print("Invalid database configuration:")
  for _, field_err in ipairs(err.context.errors) do
    print("  - " .. field_err.field .. ": " .. field_err.message)
  end
end
-- Validate all configuration
local valid, err = central_config.validate()
if not valid then
  print("Configuration validation failed:")
  for module_name, module_errors in pairs(err.context.modules) do
    print("Module: " .. module_name)
    for _, field_err in ipairs(module_errors) do
      print("  - " .. field_err.field .. ": " .. field_err.message)
    end
  end
end
```



## Configuration Reset


Reset configuration to defaults:


```lua
-- Reset a specific module
central_config.reset("logging")
-- Reset all configuration
central_config.reset()
```



## Advanced Usage


### Command Line Integration


Integrate configuration with command-line arguments:


```lua
local function parse_cli_args()
  local options = {}
  for i = 1, #arg do
    local key, value = arg[i]:match("^%-%-([%w%.]+)=(.+)$")
    if key and value then
      -- Convert value types
      if value == "true" then value = true
      elseif value == "false" then value = false
      elseif tonumber(value) then value = tonumber(value)
      end
      options[key] = value
    end
  end
  return options
end
-- Apply command-line options to configuration
central_config.configure_from_options(parse_cli_args())
```



### Environment-Specific Configuration


Load different configuration files based on the environment:


```lua
-- Determine the environment
local env = os.getenv("ENV") or "development"
-- Load environment-specific config
local config_file = ".firmo-config." .. env .. ".lua"
if fs.file_exists(config_file) then
  central_config.load_from_file(config_file)
else
  -- Fall back to default config
  central_config.load_from_file()
end
```



### Configuration Layers


Implement configuration layers with priority:


```lua
-- 1. Start with defaults from module registration
-- (happens automatically when modules are loaded)
-- 2. Load base configuration
central_config.load_from_file(".firmo-config.lua")
-- 3. Load environment-specific overrides
local env = os.getenv("ENV") or "development"
local env_config = ".firmo-config." .. env .. ".lua"
if fs.file_exists(env_config) then
  central_config.load_from_file(env_config)
end
-- 4. Load local developer overrides (not in version control)
if fs.file_exists(".firmo-config.local.lua") then
  central_config.load_from_file(".firmo-config.local.lua")
end
-- 5. Apply command-line options (highest priority)
central_config.configure_from_options(parse_cli_args())
```



## Integration with Modules


### Accessing Configuration in Modules


Modules should access configuration using the central configuration system:


```lua
local function initialize_module(options)
  -- Try to load central_config (with pcall for safety)
  local has_central_config, central_config = pcall(require, "lib.core.central_config")

  -- Default configuration
  local config = {
    enabled = true,
    timeout = 30
  }

  -- If central_config is available, use it
  if has_central_config then
    -- Register the module schema and defaults
    central_config.register_module("my_module", {
      field_types = {
        enabled = "boolean",
        timeout = "number"
      }
    }, {
      enabled = true,
      timeout = 30
    })

    -- Get module configuration
    local module_config = central_config.get("my_module")
    if module_config then
      -- Update local config with central config
      for k, v in pairs(module_config) do
        config[k] = v
      end
    end

    -- Register for changes
    central_config.on_change("my_module", function(path, old_value, new_value)
      -- Update local config when central config changes
      config = central_config.get("my_module") or config
    end)
  end

  -- Options override everything
  if options then
    for k, v in pairs(options) do
      config[k] = v
    end
  end

  return config
end
```



### Error Handling


Handle configuration errors gracefully:


```lua
local success, user_config = pcall(function()
  return central_config.load_from_file()
end)
if not success then
  -- Handle error gracefully
  print("Failed to load configuration: " .. tostring(user_config))
  -- Continue with defaults
end
-- Alternatively, use with error_handler
local error_handler = require("lib.tools.error_handler")
local success, result, err = error_handler.try(function()
  return central_config.load_from_file()
end)
if not success then
  -- Handle error with structured error information
  print("Error category: " .. result.category)
  print("Error message: " .. result.message)
  -- Continue with defaults
end
```



## Best Practices



1. **Register Module Schemas**: All modules should register their schema with default values.
2. **Use Dot Notation**: Access configuration using dot notation for consistency.
3. **Provide Fallbacks**: Always provide fallback values when getting configuration.
4. **Use Change Listeners**: Register for changes to react to configuration updates.
5. **Validate Input**: Use schema validation to ensure valid configuration.
6. **Document Configuration**: Document all configuration options with examples.
7. **Use Central Configuration**: Avoid module-specific configuration systems.
8. **Environment-Specific Configuration**: Use environment-specific configuration files.
9. **Local Overrides**: Support local developer overrides not checked into version control.
10. **Command-Line Options**: Allow command-line options to override file-based configuration.


## Common Use Cases


### Testing Configuration


Set up test-specific configuration:


```lua
-- Before tests
local original_config = central_config.get()
-- Set test configuration
central_config.set({
  debug = true,
  coverage = {
    enabled = true,
    threshold = 90
  }
})
-- Run tests...
-- After tests
central_config.reset() -- Reset to defaults
```



### CI/CD Configuration


Create CI/CD-specific configuration:


```lua
-- .firmo-ci-config.lua
return {
  debug = false,
  verbose = true,
  coverage = {
    enabled = true,
    threshold = 95, -- Stricter threshold for CI
    fail_on_threshold = true
  },
  reporting = {
    report_dir = "./ci-reports"
  }
}
```



### Configuration Migration


Transitioning from a legacy configuration system:


```lua
-- Old approach
local my_module = {}
my_module.options = {
  timeout = 30,
  max_retries = 3
}
my_module.configure = function(opts)
  for k, v in pairs(opts or {}) do
    my_module.options[k] = v
  end
end
-- New approach
local central_config = require("lib.core.central_config")
local my_module = {}
central_config.register_module("my_module", {
  field_types = {
    timeout = "number",
    max_retries = "number"
  }
}, {
  timeout = 30,
  max_retries = 3
})
-- Access configuration
local function get_options()
  return central_config.get("my_module")
end
-- Compatibility layer
my_module.configure = function(opts)
  for k, v in pairs(opts or {}) do
    central_config.set("my_module." .. k, v)
  end
end
```



## Troubleshooting


### Configuration Not Applying


If configuration changes aren't being applied:


1. Verify the config file path is correct
2. Check if there are any syntax errors in the config file
3. Make sure you're using the correct path when getting values
4. Check if the module has registered with the central configuration system


### Schema Validation Errors


If you encounter validation errors:


1. Double-check the types of your configuration values
2. Ensure required fields are present
3. Verify values are within the specified ranges
4. Check custom validator functions for errors


### Configuration File Not Found


If the configuration file can't be found:


1. Verify the file exists at the expected path
2. Check if the file has the correct permissions
3. Try using an absolute path instead of a relative path
4. Verify the file extension is `.lua`


## Next Steps


After mastering the central configuration system, explore these related topics:


- [Coverage Configuration](./coverage_configuration.md)
- [Reporting Configuration](./reporting_configuration.md)
- [Watcher Configuration](./configuration-details/watcher.md)
- [Parallel Execution Configuration](./configuration-details/parallel.md)
- [Async Testing Configuration](./configuration-details/async.md)
- [Error Handler Configuration](./configuration-details/error_handler.md)
- [Quality Validation Configuration](./configuration-details/quality.md)
- [Test Discovery Configuration](./configuration-details/discovery.md)
- [Command Line Interface Configuration](./configuration-details/cli.md)
- [Interactive Mode Configuration](./configuration-details/interactive.md)
- [Benchmark Configuration](./configuration-details/benchmark.md)
- [Temporary File Configuration](./configuration-details/temp_file.md)
- [CLI Integration](./cli_integration.md)
- [Testing Configuration](./testing_configuration.md)
