# Configuration Details Knowledge

## Purpose
Provide detailed configuration documentation for all Firmo modules and features.

## Configuration System
```lua
-- Load configuration
local config = require("lib.core.central_config")
config.load_from_file(".firmo-config.lua")

-- Module-specific configuration
config.configure_module("module_name", {
  option1 = value1,
  option2 = value2
})

-- Complex configuration example
local function setup_module_config()
  -- Define schema
  local schema = {
    field_types = {
      formatters = {
        html = {
          theme = "string",
          show_line_numbers = "boolean",
          syntax_highlighting = "boolean"
        },
        json = {
          pretty = "boolean",
          truncate_content = "boolean"
        }
      },
      discovery = {
        patterns = "table",
        exclude = "table",
        recursive = "boolean"
      }
    }
  }
  
  -- Register with validation
  config.register_module("my_module", schema, defaults)
end
```

## Documentation Structure
```lua
-- Standard documentation format
local doc = {
  title = "Module Configuration",
  description = [[
    Detailed description of the module's configuration options
    and how they affect behavior.
  ]],
  options = {
    {
      name = "option_name",
      type = "string",
      default = "default_value",
      description = "What this option does"
    }
  },
  examples = {
    basic = [[
      return {
        module = {
          option = value
        }
      }
    ]],
    advanced = [[
      -- Advanced configuration
      return {
        module = {
          complex = {
            nested = value
          }
        }
      }
    ]]
  }
}
```

## Error Handling
```lua
-- Configuration validation
local function validate_config(config)
  local validator = require("lib.reporting.validation")
  local valid, errors = validator.validate(config)
  
  if not valid then
    for _, err in ipairs(errors) do
      logger.error("Config validation error", {
        field = err.field,
        message = err.message
      })
    end
    return false
  end
  
  return true
end

-- Safe configuration loading
local function safe_load_config(path)
  local success, config = error_handler.try(function()
    return config.load_from_file(path)
  end)
  
  if not success then
    logger.error("Failed to load config", {
      error = config,
      path = path
    })
    return nil, config
  end
  
  return config
end
```

## Critical Rules
- ALWAYS use central_config
- NEVER hardcode configuration
- ALWAYS validate config values
- NEVER bypass validation
- ALWAYS document options
- NEVER use magic values
- ALWAYS provide defaults
- DOCUMENT all options

## Best Practices
- Use clear option names
- Document all options
- Provide examples
- Include defaults
- Validate input
- Handle errors
- Keep organized
- Update docs
- Test thoroughly
- Monitor usage

## Documentation Tips
- Be concise
- Use examples
- Show defaults
- Explain impacts
- Group related
- Link references
- Update regularly
- Test examples
- Include errors
- Show patterns

## Performance Tips
- Cache config values
- Validate efficiently
- Handle large files
- Clean up resources
- Monitor memory
- Batch operations
- Use defaults
- Handle timeouts