# Module Reset API Reference


This document provides a comprehensive reference for firmo's module reset functionality, which helps maintain clean state between tests.

## Overview


Firmo provides utilities for managing Lua's module cache (`package.loaded`) to ensure test isolation. The module reset functionality is available in two forms:


1. **Basic Module Reset Functions**: Simple functions for resetting individual modules
2. **Enhanced Module Reset System**: Comprehensive system for advanced module management

Both approaches help prevent test cross-contamination by ensuring each test has a fresh module state.

## Basic Module Reset Functions


### firmo.reset_module(module_name)


Resets and reloads a specific module.
**Parameters:**


- `module_name` (string): The name of the module to reset (as it would be used in `require()`)

**Returns:**


- (table): The freshly loaded module instance

**Description:**
This function removes the specified module from Lua's `package.loaded` table and then requires it again, returning a fresh instance. This ensures the module starts with its initial state.
**Example:**


```lua
describe("Counter tests", function()
  local counter

  before_each(function()
    -- Reset the counter module before each test
    counter = firmo.reset_module("app.counter")
    expect(counter.value).to.equal(0)
  end)

  it("increments the counter", function()
    counter.increment()
    expect(counter.value).to.equal(1)
  end)

  it("also starts from zero", function()
    -- Thanks to reset_module, we have a fresh counter instance
    expect(counter.value).to.equal(0)
  end)
end)
```



### firmo.with_fresh_module(module_name, callback)


Temporarily uses a fresh module instance within a callback function.
**Parameters:**


- `module_name` (string): The name of the module to reset and reload
- `callback` (function): Function to run with the fresh module (receives module as argument)

**Returns:**


- (any): The result of the callback function

**Description:**
This function provides a fresh module instance to the callback function while preserving the original module for code outside the callback. It's useful for isolated tests that need a clean slate but don't want to affect other tests.
**Example:**


```lua
it("handles configuration changes in isolation", function()
  -- Get a reference to the normal config module
  local config = require("app.config")
  local original_debug = config.debug

  -- Work with a fresh module that won't affect the original
  firmo.with_fresh_module("app.config", function(fresh_config)
    expect(fresh_config.debug).to.equal(false) -- Default value
    fresh_config.debug = true
    expect(fresh_config.debug).to.equal(true)
  end)

  -- Original module is unchanged
  expect(config.debug).to.equal(original_debug)
end)
```



## Enhanced Module Reset System


The enhanced module reset system is available through the `lib.core.module_reset` module and provides comprehensive module management capabilities.

### module_reset.init()


Initializes the module reset system and takes a snapshot of the current module state.
**Returns:**


- (module_reset): The module_reset instance for chaining

**Description:**
This function initializes the module reset system by taking a snapshot of the currently loaded modules. It also protects these initial modules from being reset. You should call this once at the start of your test suite.
**Example:**


```lua
local module_reset = require("lib.core.module_reset")
module_reset.init()
```



### module_reset.register_with_firmo(firmo)


Registers the module reset system with firmo and enhances firmo's reset functionality.
**Parameters:**


- `firmo` (table): The firmo instance to register with

**Returns:**


- (table): The enhanced firmo instance

**Description:**
This function integrates the module reset system with firmo by enhancing firmo's `reset()` function to include module reset capabilities. After registration, firmo can automatically reset modules between tests.
**Example:**


```lua
local firmo = require("firmo")
local module_reset = require("lib.core.module_reset")
-- Register with firmo
module_reset.register_with_firmo(firmo)
```



### module_reset.configure(options)


Configures the isolation options for the module reset system.
**Parameters:**


- `options` (table): Configuration options
  - `reset_modules` (boolean, optional): Whether to automatically reset modules (default: false)
  - `verbose` (boolean, optional): Whether to show detailed output about reset operations (default: false)
  - `track_memory` (boolean, optional): Whether to track memory usage (default: false)

**Returns:**


- (table): The firmo instance with updated configuration

**Description:**
This function configures how the module reset system behaves during test runs. The most important setting is `reset_modules`, which enables automatic module reset between test files.
**Example:**


```lua
module_reset.configure({
  reset_modules = true,  -- Enable automatic module reset
  verbose = false,       -- Don't show detailed output
  track_memory = true    -- Track memory usage for analysis
})
```



### module_reset.reset_all(options)


Resets all non-protected modules.
**Parameters:**


- `options` (table, optional): Options for reset operation
  - `verbose` (boolean, optional): Whether to show detailed output (default: false)
  - `force` (boolean, optional): Whether to force reset of all modules, including protected (default: false)

**Returns:**


- (number): Number of modules that were reset

**Description:**
This function resets all non-protected modules by removing them from `package.loaded`. When modules are required again, they'll be loaded fresh with their initial state.
**Example:**


```lua
-- Reset all modules and report how many were reset
local count = module_reset.reset_all()
print("Reset " .. count .. " modules")
-- Reset with verbose output
module_reset.reset_all({ verbose = true })
```



### module_reset.reset_pattern(pattern, options)


Resets modules whose names match the given Lua pattern.
**Parameters:**


- `pattern` (string): Lua pattern to match against module names
- `options` (table, optional): Options for reset operation
  - `verbose` (boolean, optional): Whether to show detailed output (default: false)

**Returns:**


- (number): Number of modules that were reset

**Description:**
This function selectively resets modules whose names match the given Lua pattern. This is useful for resetting modules in a specific namespace while leaving others untouched.
**Example:**


```lua
-- Reset all modules in the "app.services" namespace
local count = module_reset.reset_pattern("app%.services%.")
print("Reset " .. count .. " service modules")
-- Reset all modules with "model" in their name, with verbose output
module_reset.reset_pattern("model", { verbose = true })
```



### module_reset.protect(modules)


Protects specified modules from being reset.
**Parameters:**


- `modules` (string|table): Module name or array of module names to protect

**Returns:**


- (module_reset): The module_reset instance

**Description:**
This function adds modules to the protected list, preventing them from being reset by `reset_all()` or `reset_pattern()`. This is useful for modules that should maintain their state across tests, such as configuration or logging modules.
**Example:**


```lua
-- Protect a single module
module_reset.protect("app.config")
-- Protect multiple modules
module_reset.protect({
  "app.logger",
  "app.constants",
  "app.database_connection"
})
```



### module_reset.is_protected(module_name)


Checks if a module is protected from reset.
**Parameters:**


- `module_name` (string): Name of the module to check

**Returns:**


- (boolean): Whether the module is protected

**Description:**
This function checks if a module is in the protected list and thus safe from being reset.
**Example:**


```lua
if module_reset.is_protected("app.config") then
  print("Config module is protected")
else
  print("Config module is not protected")
end
```



### module_reset.add_protected_module(module_name)


Adds a single module to the protected list.
**Parameters:**


- `module_name` (string): Name of the module to protect

**Returns:**


- (boolean): Whether the module was newly added (false if already protected)

**Description:**
This function adds a single module to the protected list. It differs from `protect()` in that it only accepts a single module name and returns whether the module was newly added.
**Example:**


```lua
local was_added = module_reset.add_protected_module("app.critical_module")
if was_added then
  print("Module was newly protected")
else
  print("Module was already protected")
end
```



### module_reset.count_protected_modules()


Counts the number of protected modules.
**Returns:**


- (number): Number of protected modules

**Description:**
This function returns the total count of modules that are protected from reset.
**Example:**


```lua
local count = module_reset.count_protected_modules()
print("There are " .. count .. " protected modules")
```



### module_reset.snapshot()


Takes a snapshot of the current module state.
**Returns:**


- (table): Table mapping module names to boolean (true)
- (number): Count of modules in the snapshot

**Description:**
This function takes a snapshot of the currently loaded modules. This is mainly used internally but can be useful for tracking module loading during tests.
**Example:**


```lua
local snapshot, count = module_reset.snapshot()
print("There are " .. count .. " modules loaded")
```



### module_reset.get_loaded_modules()


Gets a list of currently loaded, non-protected modules.
**Returns:**


- (table): Array of module names

**Description:**
This function returns a sorted list of all currently loaded modules that are not protected from reset.
**Example:**


```lua
local modules = module_reset.get_loaded_modules()
print("Loaded modules:")
for _, name in ipairs(modules) do
  print("  " .. name)
end
```



### module_reset.get_memory_usage()


Gets current memory usage information.
**Returns:**


- (table): Memory usage information
  - `current` (number): Current memory usage in kilobytes
  - `count` (number): Count information (if available)

**Description:**
This function returns information about the current memory usage of the Lua state, useful for tracking memory during tests.
**Example:**


```lua
local memory = module_reset.get_memory_usage()
print("Current memory usage: " .. memory.current .. " KB")
```



### module_reset.analyze_memory_usage(options)


Analyzes memory usage by module.
**Parameters:**


- `options` (table, optional): Options for analysis
  - `track_level` (string, optional): Level of detail for tracking

**Returns:**


- (table): Array of tables with module memory information
  - Each entry has `name` (string) and `memory` (number) fields
  - Sorted by memory usage (highest first)

**Description:**
This function analyzes the memory usage of loaded modules by measuring the memory difference when each module is temporarily unloaded. This helps identify which modules are using the most memory.
**Example:**


```lua
local module_memory = module_reset.analyze_memory_usage()
print("Top 5 memory-using modules:")
for i, entry in ipairs(module_memory) do
  if i <= 5 then
    print(entry.name .. ": " .. entry.memory .. " KB")
  end
end
```



## Integration with firmo Test Framework


After registering with firmo, the module reset system enhances firmo's reset functionality to automatically reset modules between tests.

### firmo.reset()


The enhanced reset function provided by module_reset integration.
**Description:**
This function is enhanced by the module_reset system to reset modules automatically based on the configured options. It's called automatically by the test runner between test files.
**Example:**


```lua
-- This will reset all modules if reset_modules is enabled
firmo.reset()
```



### firmo.isolation_options


The isolation options configured through module_reset.
**Type:**


- (table): The configuration options for isolation
  - `reset_modules` (boolean): Whether to automatically reset modules
  - `verbose` (boolean): Whether to show detailed output
  - `track_memory` (boolean): Whether to track memory usage

**Description:**
This property holds the isolation options configured through `module_reset.configure()`. It's used by the enhanced `reset()` function to determine whether to reset modules.
**Example:**


```lua
if firmo.isolation_options and firmo.isolation_options.reset_modules then
  print("Automatic module reset is enabled")
else
  print("Automatic module reset is disabled")
end
```



## How Module Reset Works


Understanding how module reset works internally can help you use it effectively:


1. **In Lua, modules are singletons**: When you call `require("module_name")`, Lua:
   - Checks if the module is already in `package.loaded[module_name]`
   - If not, it loads the module and stores it in `package.loaded[module_name]`
   - If yes, it returns the cached module instance
2. **Basic module reset** works by:
   - Setting `package.loaded[module_name] = nil` to remove the module from cache
   - Calling `require(module_name)` again to get a fresh instance
3. **Enhanced module reset** adds features like:
   - Tracking which modules are loaded
   - Protecting essential modules from reset
   - Providing selective reset by pattern
   - Tracking memory usage
4. **Protected modules** include:
   - Core Lua modules (`_G`, `package`, `table`, etc.)
   - The firmo module itself
   - Any modules that were loaded when `module_reset.init()` was called
   - Any modules explicitly added through `module_reset.protect()`


## Error Handling


The module reset system includes comprehensive error handling using firmo's error_handler system:


1. **Validation errors** for invalid parameters:
   - Invalid module names
   - Invalid patterns
   - Missing required parameters
2. **Runtime errors** for issues during module operations:
   - Problems during snapshot creation
   - Issues during module reset
   - Memory analysis errors
3. **Recovery mechanisms** to ensure tests can continue:
   - Graceful failure when modules can't be reset
   - Protection of critical modules

All errors include detailed context information to help diagnose issues.

## See Also



- [Module Reset Guide](../guides/module_reset.md): Practical guide to using module reset
- [Module Reset Examples](../../examples/module_reset_examples.md): Real-world usage examples
