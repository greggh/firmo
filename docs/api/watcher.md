# Watcher Module API Reference


The watcher module provides functionality for monitoring filesystem changes to enable continuous test execution and automatic reloading capabilities.

## Overview


The watcher module allows you to monitor files and directories for changes, enabling use cases such as:


- Continuous test execution when source files change
- Automatic reloading of configuration
- Real-time documentation generation
- Live development workflows

The module tracks file modification timestamps and provides notifications when changes are detected.

## Module Interface



```lua
local watcher = require("lib.tools.watcher")
```



## Configuration Functions


### `watcher.configure(options)`


Configure the watcher module settings. Merges provided options with defaults and central configuration.


```lua
watcher.configure({
  check_interval = 1.0,     -- Check every 1 second
  watch_patterns = {
    "%.lua$",               -- Watch Lua files
    "%.json$"               -- Watch JSON files
  },
  default_directory = "./src",
  debug = false,
  verbose = false
})
```


**Parameters:**


- `options` (table, optional): Configuration options
- `options` (table, optional): Configuration options:
  - `check_interval` (number, optional): Time in seconds between file checks (e.g., `1.0`).
  - `watch_patterns` (string[], optional): Array of Lua patterns to match files to watch (replaces existing patterns).
  - `default_directory` (string, optional): Default directory to watch if none specified during `init`.
  - `debug` (boolean, optional): Enable debug logging for the watcher module.
  - `verbose` (boolean, optional): Enable verbose logging for the watcher module.
**Returns:**


- The watcher module instance for method chaining


### `watcher.set_check_interval(interval)`


Set the time interval between file change checks.


```lua
watcher.set_check_interval(0.5) -- Check every 0.5 seconds
```


**Parameters:**


- `interval` (number): Interval in seconds (must be greater than 0)

**Returns:**


- The watcher module instance for method chaining, or nil and error on failure


### `watcher.add_patterns(patterns)`


Add patterns for files to watch.


```lua
watcher.add_patterns({"%.css$", "%.html$"})
```


**Parameters:**


- `patterns` (string[]): Array of Lua patterns to add to watch list

**Returns:**


- The watcher module instance for method chaining, or nil and error on failure


### `watcher.reset()`


Reset the module configuration to defaults.


```lua
watcher.reset()
```


**Returns:**


- The watcher module instance for method chaining, or nil and error on failure


### `watcher.full_reset()`


Fully reset both local and central configuration.


```lua
watcher.full_reset()
```


**Returns:**


- The watcher module instance for method chaining, or nil and error on failure


### `watcher.debug_config()`


Get detailed information about the current configuration.


```lua
local config_info = watcher.debug_config()
```


**Returns:**


- `config_info` (table): Detailed information about the configuration
  - `local_config` (table): Local configuration values
  - `using_central_config` (boolean): Whether central configuration is in use
  - `central_config` (table): Central configuration values (if available)
  - `file_count` (number): Number of files being watched
  - `last_check_time` (number): Timestamp of last file check
  - `status` (string): Status of the watcher ("initialized", "uninitialized", or "error")
  - `status` (string): Status of the watcher ("initialized", "uninitialized", or "error")


## Watcher Operation Functions


### `watcher.init(directories, exclude_patterns)`


Initialize the watcher by scanning all files in the given directories.


```lua
local success, err = watcher.init("./src", {"node_modules", "%.git"})
```


**Parameters:**


- `directories` (string|string[], optional): Directory or array of directories to scan (default: current directory)
- `exclude_patterns` (string[], optional): Array of patterns to exclude from watching

**Returns:**


- `success` (boolean|nil): True if initialization succeeded, nil on failure
- `error` (table|nil): Error object if operation failed


### `watcher.check_for_changes()`


Check for file changes since the last check.


```lua
local changed_files = watcher.check_for_changes()
if changed_files then
  -- Handle changed files
  for _, file in ipairs(changed_files) do
    print("Changed file: " .. file)
  end
end
```


**Returns:**


- `changed_files` (string[]|nil): Array of changed file paths, or nil if no changes detected
- `error` (table|nil): Error object if operation failed
## Example Usage


### Basic Usage



```lua
local watcher = require("lib.tools.watcher")
-- Configure the watcher
watcher.configure({
  check_interval = 0.5,
  watch_patterns = {"%.lua$", "%.json$"}
})
-- Initialize with directories to watch
local success, err = watcher.init({"./src", "./tests"}, {"node_modules"})
if not success then
  print("Failed to initialize watcher: " .. tostring(err))
  return
end
-- Continuously check for changes
while true do
  local changed_files = watcher.check_for_changes()
  if changed_files then
    for _, file in ipairs(changed_files) do
      print("Changed: " .. file)
      -- You could run tests, reload configuration, etc.
    end
  end

  -- Sleep to avoid busy-waiting
  os.execute("sleep 0.1")
end
```



### Integration with Central Configuration



```lua
local watcher = require("lib.tools.watcher")
local central_config = require("lib.core.central_config")
-- Set configuration in central_config
central_config.set("watcher", {
  check_interval = 1.0,
  watch_patterns = {"%.lua$", "%.json$"},
  default_directory = "./src"
})
-- Configure watcher (will use central_config values)
watcher.configure()
-- Initialize the watcher
watcher.init()
-- Check for changes
local changed_files = watcher.check_for_changes()
-- Process changed files...
```



### Handling Errors



```lua
local watcher = require("lib.tools.watcher")
local error_handler = require("lib.tools.error_handler")
-- Initialize watcher with error handling
local success, err = watcher.init("./src")
if not success then
  print("Failed to initialize watcher: " .. error_handler.format_error(err))
  return
end
-- Check for changes with error handling
local success, result, err = error_handler.try(function()
  return watcher.check_for_changes()
end)
if not success then
  print("Error checking for changes: " .. error_handler.format_error(result))
else
  -- Process changed files
  if result then
    for _, file in ipairs(result) do
      print("Changed: " .. file)
    end
  end
end
```



## Advanced Configuration


The watcher module integrates with Firmo's central configuration system. You can set watcher configuration through the central configuration:


```lua
local central_config = require("lib.core.central_config")
central_config.set("watcher", {
  check_interval = 1.0,          -- Time between checks in seconds
  watch_patterns = {
    "%.lua$",                    -- Lua source files
    "%.json$",                   -- JSON files
    "%.txt$"                     -- Text files
  },
  default_directory = "./src",   -- Default directory to watch
  debug = false,                 -- Enable debug logging
  verbose = false                -- Enable verbose logging
})
```


Once set in central configuration, all components using the watcher will use these settings.
