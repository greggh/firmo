# File Watcher Configuration

This document describes the comprehensive configuration options for the firmo file watcher system, which provides automated file monitoring and change detection for continuous testing and other tasks.

## Overview

The file watcher module provides a robust system for monitoring file changes with support for:

- Monitoring specific files or directories
- Pattern-based file filtering
- Configurable check intervals
- Exclusion patterns
- Integration with the test runner for continuous testing
- Custom change handlers

## Configuration Options

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `check_interval` | number | `1.0` | Time in seconds between file change checks. Must be between 0.1 and 60. |
| `watch_patterns` | string[] | `["%.lua$", "%.txt$", "%.json$"]` | Array of Lua patterns that determine which files to watch. |
| `default_directory` | string | `.` | Default directory to scan if no specific directories are provided. |
| `debug` | boolean | `false` | Enables debug logging for the watcher module. |
| `verbose` | boolean | `false` | Enables verbose logging for the watcher module. |

### Watch Mode Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `interval` | number | `1.0` | Time in seconds between checking for changes (maps to `check_interval`). |
| `exclude_patterns` | string[] | `["node_modules", "%.git"]` | Patterns to exclude from watching. |
| `debounce_time` | number | `0.5` | Seconds to wait after changes are detected before running tests. |

## Configuration in .firmo-config.lua

You can configure the watcher system in your `.firmo-config.lua` file:

```lua
return {
  -- File watcher configuration
  watcher = {
    -- Basic configuration
    check_interval = 0.5,  -- Check every half second
    watch_patterns = {
      "%.lua$",            -- Watch Lua files
      "%.md$",             -- Watch Markdown files
      "%.json$",           -- Watch JSON files
      "%.xml$"             -- Watch XML files
    },

    -- Debugging options
    debug = false,
    verbose = false,

    -- Default directory
    default_directory = "src"
  },

  -- Test runner watch mode configuration
  runner = {
    watch = {
      interval = 0.5,
      exclude_patterns = {
        "node_modules",
        "%.git",
        "%.vscode",
        "coverage%-reports",
        "%.DS_Store"
      },
      debounce_time = 0.3
    }
  }
}
```

## Programmatic Configuration

You can also configure the watcher system programmatically:

```lua
local watcher = require("lib.tools.watcher")
-- Basic configuration
watcher.configure({
  check_interval = 0.5,
  watch_patterns = {"%.lua$", "%.md$", "%.json$"},
  debug = true
})
-- Initialize with specific directories
watcher.init({"src", "tests"}, {"%.git", "node_modules"})
-- Individual option configuration (fluent interface)
watcher.set_check_interval(0.5)
      .add_patterns({"%.md$", "%.json$"})
      .set_debug(true)
```

## Watch Patterns

Watch patterns determine which files the watcher will monitor for changes:

```lua
-- Configure watch patterns
watcher.configure({
  watch_patterns = {
    "%.lua$",     -- Lua source files
    "%.json$",    -- JSON data files
    "%.md$",      -- Markdown documentation
    "%.html$",    -- HTML files
    "%.css$",     -- CSS files
    "%.js$"       -- JavaScript files
  }
})
-- Add additional patterns
watcher.add_patterns({"%.xml$", "%.yaml$"})
```

Patterns use Lua's pattern matching syntax, which is similar to but not identical to regular expressions:

- `%.` matches a literal dot (in Lua patterns, `.` means "any character")
- `$` matches the end of the string
- So `%.lua$` matches any string ending with ".lua"

## Excluding Files and Directories

You can exclude specific files or directories from being watched:

```lua
-- Initialize with exclusions
watcher.init(".", {
  "%.git",        -- Exclude .git directory 
  "node_modules", -- Exclude node_modules
  "%.DS_Store",   -- Exclude macOS metadata files
  "%.bak$",       -- Exclude backup files
  "temp"          -- Exclude temp directory
})
-- Through central configuration
watcher = {
  exclude_patterns = {
    "%.git",
    "node_modules",
    "coverage%-reports"
  }
}
```

## Change Detection

The watcher detects three types of changes:

1. **Modified files**: Files with a newer modification time
2. **New files**: Files that match watch patterns but weren't previously tracked
3. **Removed files**: Files that were previously tracked but no longer exist

```lua
-- Check for changes
local changed_files = watcher.check_for_changes()
-- Handle changed files
if changed_files and #changed_files > 0 then
  print("Files changed:")
  for _, file in ipairs(changed_files) do
    print("  - " .. file)
  end

  -- Take action based on changes
  run_tests()
end
```

## Integration with Test Runner

The watcher integrates directly with the test runner to implement continuous testing:

```bash

# Run tests in watch mode

lua firmo.lua --watch tests/

# Set custom watch interval

lua firmo.lua --watch --watch-interval=0.5 tests/

# Exclude specific patterns

lua firmo.lua --watch --exclude="node_modules,%.git" tests/

# Set debounce time

lua firmo.lua --watch --debounce=1.0 tests/
```

When the test runner is in watch mode:

1. It initializes the watcher with the specified test directory
2. It continuously monitors for changes to test or source files
3. When changes are detected, it waits for the debounce period
4. It clears the terminal and re-runs the specified tests
5. It returns to watching for changes

## Advanced Usage

### Manual File and Directory Management

You can manually add specific files or directories to watch:

```lua
-- Add a specific directory
watcher.add_directory("src/core", true)  -- true = recursive
-- Add a specific file
watcher.add_file("config.json")
-- Check if the watcher is active
if watcher.is_watching() then
  print("Watcher is active")
end
-- Get the list of watched files
local files = watcher.get_watched_files()
for file_path, file_info in pairs(files) do
  print(file_path, file_info.last_modified)
end
```

### Custom Watch Loop

You can implement your own watch loop for custom behavior:

```lua
local watcher = require("lib.tools.watcher")
-- Configure the watcher
watcher.configure({
  check_interval = 0.5,
  watch_patterns = {"%.lua$", "%.json$"}
})
-- Initialize with specific directories
watcher.init({"src", "config"})
-- Custom watch loop
local function watch_loop()
  while true do
    local changed_files = watcher.check_for_changes()

    if changed_files and #changed_files > 0 then
      print("\nFiles changed:")
      for _, file in ipairs(changed_files) do
        print("  - " .. file)
      end

      -- Custom actions for different file types
      for _, file in ipairs(changed_files) do
        if file:match("%.lua$") then
          print("Running lint on " .. file)
          os.execute("luacheck " .. file)
        elseif file:match("%.json$") then
          print("Validating JSON in " .. file)
          validate_json(file)
        end
      end
    end

    -- Sleep to prevent CPU hogging
    os.execute("sleep 0.1")
  end
end
-- Start watching
watch_loop()
```

### Debugging the Watcher

The watcher includes debugging tools to help troubleshoot issues:

```lua
-- Enable debug mode
watcher.configure({debug = true})
-- Get the current configuration
local config = watcher.debug_config()
print("Current interval:", config.check_interval)
print("Watch patterns:", table.concat(config.watch_patterns, ", "))
-- Reset the watcher to defaults
watcher.reset()
-- Full reset (including central config)
watcher.full_reset()
```

## Error Handling

The watcher implements comprehensive error handling:

```lua
-- Initialize with error checking
local success, err = pcall(function()
  watcher.init("nonexistent_directory")
end)
if not success then
  print("Error initializing watcher:", err)
end
-- Check for changes with error handling
local changed_files, err = watcher.check_for_changes()
if not changed_files then
  print("Error checking for changes:", err)
end
```

All watcher functions:

- Validate inputs and return `nil, error_object` for failures
- Use the `error_handler` module for standardized error creation
- Include appropriate context in error objects

## Integration Example

```lua
local watcher = require("lib.tools.watcher")
local central_config = require("lib.core.central_config")
-- Configure through central config
central_config.set("watcher.check_interval", 0.5)
central_config.set("watcher.watch_patterns", {"%.lua$", "%.md$"})
-- Apply configuration from central config
watcher.configure_from_config()
-- Initialize with specific directories
watcher.init({"src", "docs"}, {"%.git", "node_modules"})
-- Create a simple watch loop
local function watch_files()
  while true do
    local changed_files = watcher.check_for_changes()

    if changed_files and #changed_files > 0 then
      print("\nFiles changed:", os.date())
      for _, file in ipairs(changed_files) do
        print("  - " .. file)
      end

      -- Run tests
      os.execute("lua firmo.lua")
    end

    -- Sleep for a bit to prevent CPU hogging
    os.execute("sleep 0.1")
  end
end
-- Start watching
watch_files()
```

## Command Line Options

When using the test runner's watch mode, you can configure the watcher through command line options:

```bash

# Basic watch mode

lua firmo.lua --watch tests/

# Set custom check interval (0.5 seconds)

lua firmo.lua --watch --watch-interval=0.5 tests/

# Set custom debounce time

lua firmo.lua --watch --debounce=1.0 tests/

# Set custom exclude patterns

lua firmo.lua --watch --exclude="node_modules,%.git,%.vscode" tests/

# Verbose output (show more details about file changes)

lua firmo.lua --watch --verbose tests/

# Focus on specific test patterns in watch mode

lua firmo.lua --watch --pattern="database" tests/
```

These command line options override any settings from the configuration file for that specific run.
