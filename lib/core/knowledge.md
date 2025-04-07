# Core Knowledge

## Purpose
Core utilities and foundational functionality for the framework.

## Configuration System
```lua
-- Load config from file
local config = require("lib.core.central_config")
config.load_from_file(".firmo-config.lua")

-- Get and set values
local value = config.get("coverage.threshold")
config.set("coverage.threshold", 90)

-- Register module config
config.register_module("my_module", {
  field_types = {
    timeout = "number",
    debug = "boolean"
  }
}, {
  timeout = 5000,
  debug = false
})

-- Complex configuration example
local function setup_module_config()
  -- Define schema
  local schema = {
    field_types = {
      database = {
        host = "string",
        port = "number",
        timeout = "number",
        max_connections = "number"
      },
      logging = {
        level = "string",
        file = "string",
        format = "string"
      }
    }
  }
  
  -- Define defaults
  local defaults = {
    database = {
      host = "localhost",
      port = 5432,
      timeout = 5000,
      max_connections = 10
    },
    logging = {
      level = "INFO",
      file = "app.log",
      format = "json"
    }
  }
  
  -- Register with validation
  config.register_module("my_module", schema, defaults)
  
  -- Watch for changes
  config.on_change("my_module.database.timeout", function(path, old, new)
    logger.info("Timeout changed", {
      old = old,
      new = new
    })
  end)
end
```

## Module Reset System
```lua
-- Reset single module
local fresh_module = firmo.reset_module("path.to.module")

-- Reset with dependencies
firmo.reset_module("my_module", {
  recursive = true,
  clear_cache = true
})

-- Complex module reset
local function reset_module_group()
  -- Define module dependencies
  local modules = {
    "module_a",
    "module_b",
    "module_c"
  }
  
  -- Define reset order
  local order = {
    "c", -- Must be reset first
    "b",
    "a"  -- Must be reset last
  }
  
  -- Reset modules in order
  for _, name in ipairs(order) do
    local success, err = error_handler.try(function()
      return firmo.reset_module(name, {
        recursive = false,  -- Already handling order
        clear_cache = true
      })
    end)
    
    if not success then
      logger.error("Module reset failed", {
        module = name,
        error = err
      })
      return nil, err
    end
  end
  
  return true
end
```

## Type Validation
```lua
-- Basic type checks
expect(value).to.be.a("string")
expect(value).to.be.a("number")
expect(value).to.be.a("table")
expect(value).to.be.a("function")

-- Complex type validation
expect(fn).to.be_type("callable")  -- Function or callable table
expect(num).to.be_type("comparable")  -- Can use < operator
expect(table).to.be_type("iterable")  -- Can iterate with pairs()

-- Custom type validation
type_checker.register_type("positive_number", function(value)
  return type(value) == "number" and value > 0
end)

-- Type validation with schema
local schema = {
  name = "string",
  age = "number",
  email = "string?",  -- Optional
  settings = {
    theme = "string",
    notifications = "boolean"
  }
}

local function validate_user(user)
  local valid, errors = type_checker.validate(user, schema)
  if not valid then
    return nil, error_handler.validation_error(
      "Invalid user data",
      { errors = errors }
    )
  end
  return true
end
```

## Critical Rules
- ALWAYS use central_config
- NEVER bypass type checks
- ALWAYS handle module reset
- NEVER modify core modules
- ALWAYS validate input
- NEVER add special cases
- ALWAYS clean up state
- DOCUMENT public APIs

## Best Practices
- Use type annotations
- Document public APIs
- Handle edge cases
- Clean up resources
- Log state changes
- Monitor performance
- Test thoroughly
- Handle errors
- Follow patterns
- Keep focused

## Performance Tips
- Cache config values
- Minimize resets
- Clean up promptly
- Monitor memory
- Handle timeouts
- Batch operations
- Use efficient checks
- Profile regularly