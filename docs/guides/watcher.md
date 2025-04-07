# Watcher Module Guide

This guide explains how to use Firmo's watcher module to monitor filesystem changes and implement continuous testing and reloading capabilities.

## Introduction

The watcher module helps you monitor files and directories for changes, allowing you to trigger actions like running tests when code is modified. This is particularly useful for development workflows where you want immediate feedback as you make changes.

For detailed configuration options, see [File Watcher Configuration](./configuration-details/watcher.md).

Key capabilities of the watcher module include:

- Monitoring multiple directories for changes
- Filtering which files to watch using pattern matching
- Customizable check intervals
- Integration with Firmo's central configuration system
- Comprehensive error handling

## Getting Started

### Basic File Watching

To get started with the watcher module, you need to initialize it with directories to watch and then periodically check for changes:

```lua
local watcher = require("lib.tools.watcher")

-- Configure which file types to watch
watcher.configure({
  watch_patterns = {"%.lua$", "%.json$"}
})

-- Initialize the watcher with directories to scan
local success, err = watcher.init("./src")
if not success then
  print("Failed to initialize watcher: " .. tostring(err))
  return
end

-- Check for changes
local changed_files = watcher.check_for_changes()
if changed_files then
  print("Files changed:")
  for _, file in ipairs(changed_files) do
    print("  - " .. file)
  end
end
```

### Continuous Watching Loop

For continuous watching, you'll typically use a loop that periodically checks for changes:

```lua
local watcher = require("lib.tools.watcher")

-- Initialize the watcher
watcher.configure({
  check_interval = 0.5  -- Check every 0.5 seconds
})
watcher.init({"./src", "./tests"})

print("Watching for changes (press Ctrl+C to stop)...")

-- Watch loop
while true do
  local changed_files = watcher.check_for_changes()
  
  if changed_files then
    print("\nDetected changes:")
    for _, file in ipairs(changed_files) do
      print("  - " .. file)
      
      -- Run tests related to the changed file
      if file:match("%.lua$") then
        local test_file = file:gsub("^src/", "tests/"):gsub("%.lua$", "_test.lua")
        if fs.file_exists(test_file) then
          print("Running test: " .. test_file)
          -- Run your test command here
          os.execute("lua " .. test_file)
        end
      end
    end
  end
  
  -- Sleep to avoid busy waiting
  os.execute("sleep 0.1")
end
```

## Configuration Options

### File Patterns

The watcher module uses Lua patterns to determine which files to watch. You can configure these patterns when setting up the watcher:

```lua
watcher.configure({
  watch_patterns = {
    "%.lua$",       -- Lua source files
    "%.json$",      -- JSON configuration files
    "%.md$",        -- Markdown documentation
    "%.css$",       -- CSS style files
    "%.html$",      -- HTML template files
  }
})
```

You can also add patterns later:

```lua
watcher.add_patterns({"%.js$", "%.ts$"})
```

### Check Interval

The check interval determines how frequently the watcher checks for file changes:

```lua
-- Check every 0.5 seconds
watcher.set_check_interval(0.5)

-- Slower checks (every 2 seconds)
watcher.set_check_interval(2.0)
```

A smaller interval provides quicker feedback but uses more CPU. A larger interval uses less CPU but has delayed notifications.

### Excluding Files and Directories

When initializing the watcher, you can specify patterns for files and directories to exclude:

```lua
-- Exclude patterns
local exclude_patterns = {
  "node_modules",  -- Exclude node_modules directory
  "%.git",         -- Exclude .git directory
  "%.bak$",        -- Exclude backup files
  "~$",            -- Exclude temporary files
}

watcher.init("./src", exclude_patterns)
```

## Advanced Usage

### Integration with Central Configuration

The watcher module integrates with Firmo's central configuration system:

```lua
local central_config = require("lib.core.central_config")

-- Set watcher configuration in central_config
central_config.set("watcher", {
  check_interval = 1.0,
  watch_patterns = {"%.lua$", "%.json$"},
  default_directory = "./src",
  debug = true,
  verbose = false
})

-- The watcher will use these settings automatically
local watcher = require("lib.tools.watcher")
watcher.init()
```

### Error Handling

The watcher module includes comprehensive error handling. All functions return error information when operations fail:

```lua
local watcher = require("lib.tools.watcher")
local error_handler = require("lib.tools.error_handler")

-- Initialize with error handling
local success, err = watcher.init("./nonexistent_directory")
if not success then
  print("Initialization failed: " .. error_handler.format_error(err))
  -- You could use a fallback directory
  success, err = watcher.init(".")
  if not success then
    print("Fallback initialization failed: " .. error_handler.format_error(err))
    return
  end
end

-- Check for changes with error handling
local success, result, err = error_handler.try(function()
  return watcher.check_for_changes()
end)

if not success then
  print("Error checking for changes: " .. error_handler.format_error(result))
end
```

### Resetting the Watcher

If you need to reset the watcher's configuration:

```lua
-- Reset to default configuration
watcher.reset()

-- Full reset of both local and central configuration
watcher.full_reset()
```

### Debugging

For debugging watcher configuration and state:

```lua
-- Get detailed configuration information
local config_info = watcher.debug_config()

print("Watcher Configuration:")
print("  Using central config: " .. tostring(config_info.using_central_config))
print("  Check interval: " .. config_info.local_config.check_interval .. " seconds")
print("  Watching " .. config_info.file_count .. " files")
print("  Status: " .. config_info.status)
```

## Implementation Patterns

### Test Runner with File Watching

Here's a pattern for implementing a test runner with file watching:

```lua
local watcher = require("lib.tools.watcher")
local fs = require("lib.tools.filesystem")

local function run_test(test_file)
  print("Running test: " .. test_file)
  local success = os.execute("lua " .. test_file)
  return success
end

local function find_related_test(source_file)
  -- Convert source file path to test file path
  local test_file = source_file:gsub("^src/", "tests/"):gsub("%.lua$", "_test.lua")
  if fs.file_exists(test_file) then
    return test_file
  end
  return nil
end

local function watch_and_test()
  -- Initialize watcher
  watcher.configure({
    check_interval = 0.5,
    watch_patterns = {"%.lua$"}
  })
  
  watcher.init({"./src", "./tests"}, {"%.git"})
  
  print("Watching for changes (press Ctrl+C to stop)...")
  
  while true do
    local changed_files = watcher.check_for_changes()
    
    if changed_files then
      local tests_to_run = {}
      
      -- Find tests related to changed files
      for _, file in ipairs(changed_files) do
        print("Changed: " .. file)
        
        -- If a test file changed, run it directly
        if file:match("^tests/.*_test%.lua$") then
          table.insert(tests_to_run, file)
        
        -- If a source file changed, find and run related tests
        elseif file:match("^src/.*%.lua$") then
          local test_file = find_related_test(file)
          if test_file then
            table.insert(tests_to_run, test_file)
          end
        end
      end
      
      -- Run all identified tests
      print("\nRunning " .. #tests_to_run .. " tests...")
      for _, test_file in ipairs(tests_to_run) do
        run_test(test_file)
      end
    end
    
    -- Sleep to avoid busy waiting
    os.execute("sleep 0.1")
  end
end

-- Start watching and testing
watch_and_test()
```

### Auto-Reloading Configuration

Here's a pattern for auto-reloading configuration:

```lua
local watcher = require("lib.tools.watcher")
local fs = require("lib.tools.filesystem")
local config_file = "./config.json"

local function load_config()
  local content, err = fs.read_file(config_file)
  if not content then
    print("Failed to read config: " .. tostring(err))
    return nil
  end
  
  -- Parse JSON (assuming a JSON parser is available)
  local success, config = pcall(function()
    return JSON.parse(content)
  end)
  
  if not success then
    print("Failed to parse config: " .. tostring(config))
    return nil
  end
  
  return config
end

local function apply_config(config)
  if not config then return end
  
  print("Applying configuration:")
  print("  Log level: " .. (config.log_level or "info"))
  print("  Port: " .. (config.port or 8080))
  
  -- Apply configuration to your application
  -- app.set_log_level(config.log_level)
  -- app.set_port(config.port)
end

local function watch_config()
  -- Initialize watcher
  watcher.configure({
    check_interval = 1.0,
    watch_patterns = {"%.json$"}
  })
  
  watcher.init(".", {"%.git"})
  
  -- Load initial configuration
  local config = load_config()
  apply_config(config)
  
  print("Watching for configuration changes...")
  
  while true do
    local changed_files = watcher.check_for_changes()
    
    if changed_files then
      for _, file in ipairs(changed_files) do
        if file == config_file then
          print("\nConfiguration file changed. Reloading...")
          local new_config = load_config()
          apply_config(new_config)
        end
      end
    end
    
    -- Sleep to avoid busy waiting
    os.execute("sleep 0.1")
  end
end

-- Start watching configuration
watch_config()
```

## Best Practices

### Setting Appropriate Check Intervals

Choose an appropriate check interval based on your use case:

- **Development feedback**: 0.2-0.5 seconds for quick feedback during development
- **Documentation generation**: 1-2 seconds for less frequent tasks
- **Production monitoring**: 5+ seconds for low-impact monitoring

### Limiting Watched Directories

For better performance:

- Only watch relevant directories
- Use exclude patterns for large directories you don't need to monitor
- Be specific with file patterns to reduce the number of files tracked

```lua
-- Good practice - specific directories and exclusions
watcher.init(
  {"./src", "./tests", "./config"},
  {"node_modules", "%.git", "%.DS_Store", "build"}
)

-- Avoid - watching too much
watcher.init(".")
```

### Handling Rapid Changes

When files change rapidly (e.g., during a large copy or build operation), implement debouncing:

```lua
local last_action_time = 0
local debounce_interval = 1.0 -- seconds

-- In your watch loop
local changed_files = watcher.check_for_changes()
if changed_files then
  local current_time = os.time()
  
  -- Only process if enough time has passed since last action
  if current_time - last_action_time >= debounce_interval then
    -- Process changes
    process_changes(changed_files)
    last_action_time = current_time
  else
    print("Debouncing rapid changes...")
  end
end
```

### Resource Management

Always clean up watcher resources when they're no longer needed:

```lua
-- Good practice - reset when done
local function run_watched_tests()
  watcher.init("./src")
  
  -- Run tests when files change
  -- ...
  
  -- Clean up when done
  watcher.full_reset()
end
```

## Troubleshooting

### Common Issues

1. **No changes detected**: Ensure your file patterns match the files you expect. Check if `watcher.debug_config()` shows files being watched.

2. **High CPU usage**: Your check interval might be too small. Increase it using `watcher.set_check_interval()`.

3. **Missing file notifications**: Some editors write temporary files first and then rename them. This can sometimes confuse timestamp-based watchers. Consider using direct file access APIs if available.

4. **Initialization failures**: Check directory permissions and ensure the directory exists before calling `watcher.init()`.

## Conclusion

The watcher module provides a powerful tool for monitoring filesystem changes and implementing continuous test execution and auto-reloading functionality. By following the patterns and best practices in this guide, you can create efficient and responsive development workflows.