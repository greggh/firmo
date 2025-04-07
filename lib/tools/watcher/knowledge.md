# Watcher Knowledge

## Purpose
File system watching for continuous test execution.

## Watcher Usage
```lua
-- Basic file watching
local watcher = require("lib.tools.watcher")

-- Watch directory with options
watcher.watch("src/", {
  patterns = { "*.lua" },
  exclude = { "node_modules" },
  recursive = true,
  debounce = 100,
  on_change = function(event)
    if event.type == "modified" then
      run_tests(event.path)
    end
  end
})

-- Watch multiple paths
watcher.watch_paths({
  "src/",
  "tests/"
}, {
  patterns = { "*.lua", "*.test.lua" }
})

-- Complex watching scenario
local function setup_test_watcher()
  -- Configure watcher
  local config = {
    paths = {
      { path = "src/", patterns = { "*.lua" } },
      { path = "tests/", patterns = { "*_test.lua" } }
    },
    exclude = {
      "node_modules",
      "vendor",
      "%.git"
    },
    options = {
      recursive = true,
      follow_symlinks = false,
      debounce = 100
    }
  }
  
  -- Create watcher
  local watcher = require("lib.tools.watcher").new(config)
  
  -- Add event handlers
  watcher.on("change", function(event)
    if event.type == "modified" then
      run_tests(event.path)
    end
  end)
  
  watcher.on("error", function(err)
    logger.error("Watch error", {
      error = err,
      category = err.category
    })
  end)
  
  return watcher
end
```

## Error Handling
```lua
-- Error handling pattern
local success, err = watcher.start({
  error_handler = function(err)
    logger.error("Watch error", {
      error = err,
      category = err.category
    })
  end,
  recovery = function()
    -- Attempt recovery
    return watcher.restart()
  end
})

-- Resource cleanup
local function with_watcher(config, callback)
  local watcher = require("lib.tools.watcher").new(config)
  local result, err = error_handler.try(function()
    return callback(watcher)
  end)
  
  watcher:stop()
  
  if not result then
    return nil, err
  end
  return result
end

-- Handle watch errors
watcher.on("error", function(err)
  if err.code == "ENOSPC" then
    -- No space left for inotify watches
    logger.error("Watch limit reached", {
      error = err,
      category = err.category
    })
    -- Attempt to recover by reducing watch paths
    watcher.reduce_watches()
  end
end)
```

## Critical Rules
- Handle rapid changes
- Clean up watchers
- Limit watch paths
- Handle permissions
- Monitor resources
- Set debounce time
- Handle interrupts
- Clean up properly

## Best Practices
- Set debounce time
- Filter file types
- Handle recursion
- Clean up properly
- Log watch events
- Monitor resources
- Handle interrupts
- Validate patterns
- Check permissions
- Use efficient patterns

## Performance Tips
- Optimize patterns
- Limit watch depth
- Handle large dirs
- Clean up promptly
- Monitor memory
- Use event batching
- Cache results
- Handle timeouts