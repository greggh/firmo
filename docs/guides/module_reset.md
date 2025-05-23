# Module Reset Guide

This guide explains how to use firmo's module reset functionality to improve test isolation and prevent test state from leaking between test cases.

## Why Module Reset Matters

In Lua, modules are typically singletons - a module is loaded once and cached in `package.loaded`. This is normally efficient, but can cause problems in testing:

1.  **State Leakage**: If one test modifies a module's state, subsequent tests might see those modifications
2.  **Initialization Side Effects**: Modules with initialization side effects (database connections, file handles) may persist between tests
3.  **Memory Growth**: Long-running test suites can accumulate memory if modules hold references to large data structures

The module reset system solves these problems by providing ways to reload modules with fresh state.
## Module Reset System (`lib.core.module_reset`)

For comprehensive control, firmo includes the `module_reset` system which manages all modules and provides features like:

- Automatic module reset between test files
- Selective module reset by pattern
- Protection of core modules from reset
- Memory usage tracking

### Basic Setup

To use the enhanced system, first require and register it with firmo:

```lua
local firmo = require("firmo")
local module_reset = require("lib.core.module_reset")
-- Register with firmo
module_reset.register_with_firmo(firmo)
-- Configure isolation options
module_reset.configure({
  reset_modules = true,  -- Enable module reset between test files
  verbose = false        -- Show detailed output about reset operations
})
```

### Protecting Essential Modules

Some modules should never be reset. The system automatically protects core Lua modules and firmo itself, but you can add your own:

```lua
-- Protect a single module
module_reset.protect("app.essential_service")
-- Protect multiple modules
module_reset.protect({
  "app.config", 
  "app.logger", 
  "app.constants"
})
```

### Resetting Modules Selectively

Reset all non-protected modules:

```lua
-- Reset all modules and return count of modules reset
local reset_count = module_reset.reset_all()
print("Reset " .. reset_count .. " modules")
```

Reset modules matching a pattern:

```lua
-- Reset all modules in the "app.services" namespace
local count = module_reset.reset_pattern("app%.services%.")
print("Reset " .. count .. " service modules")
```

### Analyzing Memory Usage

Track memory usage of your modules:

```lua
-- Get overall memory usage
local memory = module_reset.get_memory_usage()
print("Current memory usage: " .. memory.current .. " KB")
-- Analyze memory usage by module
local module_memory = module_reset.analyze_memory_usage()
for i, entry in ipairs(module_memory) do
  if i <= 5 then -- Show top 5 memory users
    print(entry.name .. ": " .. entry.memory .. " KB")
  end
end
```

## Common Patterns and Best Practices

### Database Test Pattern

When testing database operations, reset the database module before each test:

```lua
describe("User database", function()
  local db

  before(function()
    -- Get a fresh database module (Assuming db module exists)
    -- NOTE: firmo.reset_module does not exist; this demonstrates the *concept*.
    -- In practice, you'd use the enhanced module_reset system or other isolation techniques.
    local db_module = require("app.database") -- Placeholder

    -- Connect to test database
    db = db_module.connect({
    -- Connect to test database
    db.connect({
      driver = "sqlite",
      in_memory = true  -- Use in-memory database for tests
    })

    -- Create test tables
    db.execute("CREATE TABLE users (id INTEGER, name TEXT)")
  end)

  after(function()
    -- Clean up
    if db then db:disconnect() end
  end)

  it("creates a user", function()
    local result = db.execute("INSERT INTO users VALUES (1, 'Test User')")
    expect(result.rows_affected).to.equal(1)

    local user = db.query_one("SELECT * FROM users WHERE id = 1")
    expect(user).to.exist()
    expect(user.name).to.equal("Test User")
  end)

  it("updates a user", function()
    -- No state leakage from previous test - fresh database each time
    db.execute("INSERT INTO users VALUES (1, 'Original Name')")
    db.execute("UPDATE users SET name = 'Updated Name' WHERE id = 1")

    local user = db.query_one("SELECT * FROM users WHERE id = 1")
    expect(user.name).to.equal("Updated Name")
  end)
end)
```

### Configuration Test Pattern

When testing with different configurations:

```lua
describe("Application with different configs", function()
  local config
  local app

  before(function()
    -- Reset both the config and app modules (Conceptual example)
    -- NOTE: firmo.reset_module does not exist. Use enhanced system or other techniques.
    local config_module = require("app.config") -- Placeholder
    local app_module = require("app.core") -- Placeholder
    config = config_module -- Use fresh instance
    app = app_module -- Use fresh instance
  end)

  it("works in development mode", function()
    config.set_environment("development")
    app.initialize()

    expect(app.debug_mode).to.be_truthy()
    expect(app.logger.level).to.equal("debug")
  end)

  it("works in production mode", function()
    config.set_environment("production")
    app.initialize()

    expect(app.debug_mode).to_not.be_truthy()
    expect(app.logger.level).to.equal("warning")
  end)
end)
```

### Module Dependencies Pattern

When a module has dependencies, reset the highest-level module to ensure all dependencies get re-required correctly:

```lua
describe("Authentication service", function()
  local auth

  before(function()
    -- This will cause all dependencies to be re-required (Conceptual example)
    -- NOTE: firmo.reset_module does not exist. Use enhanced system.
    local auth_module = require("app.services.auth") -- Placeholder
    auth = auth_module -- Use fresh instance
  end)

  it("authenticates valid users", function()
    expect(auth.authenticate("user", "password")).to.be_truthy()
  end)

  it("rejects invalid credentials", function()
    expect(auth.authenticate("user", "wrong")).to_not.be_truthy()
  end)
end)
```

### Memory Leak Detection Pattern

Use memory tracking to find potential memory leaks in your modules:

```lua
describe("Memory usage tests", function()
  it("should not grow memory when used repeatedly", function()
    local module = require("app.heavy_module")

    -- Get initial memory usage
    local before = module_reset.get_memory_usage().current

    -- Use the module repeatedly
    for i = 1, 100 do
      module.process_data("test")
    end

    -- Force garbage collection
    collectgarbage("collect")

    -- Check memory usage
    local after = module_reset.get_memory_usage().current

    -- Allow some small variation
    expect(after).to.be_less_than(before * 1.1) 
  end)
end)
```

## Troubleshooting

### Module State Not Resetting

If module state seems to persist despite resetting:

1. Check if the module is protected: `module_reset.is_protected("module_name")`
2. Verify module caching: some modules might cache data in global variables
3. Use verbose mode to see what's being reset: `module_reset.reset_all({verbose = true})`

### Performance Issues

If tests are slow due to frequent module resets:

1. Be more selective with resets, using `reset_pattern` instead of `reset_all`
2. Only reset modules in `before_each` when truly needed
3. Use `with_fresh_module` for isolated cases

### Identifying Memory-Intensive Modules

If your tests use excessive memory:

```lua
-- Run at the end of your test suite
local memory_hogs = module_reset.analyze_memory_usage()
print("Top memory users:")
for i, entry in ipairs(memory_hogs) do
  if i <= 10 then
    print(entry.name .. ": " .. entry.memory .. " KB")
  end
end
```

## Advanced Usage

### Integration with Test Runner

For automatic module reset between test files, configure your test runner:

```lua
-- In your test runner
local firmo = require("firmo")
local module_reset = require("lib.core.module_reset")
module_reset.register_with_firmo(firmo)
module_reset.configure({
  reset_modules = true,
  verbose = os.getenv("VERBOSE") == "1"
})
-- This will now automatically reset modules between test files
firmo.run_tests(test_files)
```

### Customizing Module Reset Behavior

You can customize which modules get reset by combining protection and pattern reset:

```lua
-- Protect critical modules
module_reset.protect({
  "app.config", 
  "app.logger", 
  "app.database_connection"
})
-- Only reset modules in specific namespaces
module_reset.reset_pattern("app%.services%.")
module_reset.reset_pattern("app%.controllers%.")
```

## Summary

The `module_reset` system (`lib/core/module_reset.lua`) provides powerful tools for managing module state and test isolation, including automatic reset between files, selective reset, and memory tracking. By integrating it into your test runner setup, you can significantly improve the reliability and independence of your tests.
