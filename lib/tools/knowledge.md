# Tools Knowledge

## Purpose
Core utility modules supporting the framework functionality.

## Module Usage
```lua
-- Filesystem operations
local fs = require("lib.tools.filesystem")
local content, err = fs.read_file("config.json")
if not content then
  logger.error("Failed to read config", {
    error = err,
    category = err.category
  })
  return nil, err
end

-- Error handling
local error_handler = require("lib.tools.error_handler")
local success, result, err = error_handler.try(function()
  return risky_operation()
end)

if not success then
  logger.error("Operation failed", {
    error = err,
    category = err.category
  })
  return nil, err
end

-- Structured logging
local logger = require("lib.tools.logging").get_logger("module_name")
logger.info("Operation completed", {
  duration = time_taken,
  items = count
})

-- Parser usage
local parser = require("lib.tools.parser")
local ast, err = parser.parse([[
  local function test()
    return true
  end
]])

-- File watching
local watcher = require("lib.tools.watcher")
watcher.watch("src/", {
  patterns = { "*.lua" },
  on_change = function(event)
    if event.type == "modified" then
      run_tests(event.path)
    end
  end
})
```

## Error Handling
```lua
-- Standard error handling pattern
local function safe_operation()
  local success, result, err = error_handler.try(function()
    return risky_operation()
  end)
  
  if not success then
    logger.error("Operation failed", {
      error = err,
      category = err.category
    })
    return nil, err
  end
  
  return result
end

-- File operation error handling
local function safe_file_operation(path)
  if not fs.file_exists(path) then
    return nil, error_handler.io_error(
      "File not found",
      { path = path }
    )
  end
  
  local content, err = fs.read_file(path)
  if not content then
    return nil, err
  end
  
  return content
end

-- Resource cleanup
local function with_temp_file(callback)
  local path = fs.temp_file()
  local result, err = error_handler.try(function()
    return callback(path)
  end)
  
  fs.delete_file(path)
  
  if not result then
    return nil, err
  end
  return result
end
```

## Critical Rules
- Use error_handler for all errors
- Validate all input parameters
- Clean up resources properly
- Log operations appropriately
- Use filesystem module for files
- Never use io.* directly
- Always handle cleanup
- Document public APIs
- Test thoroughly
- Monitor performance

## Best Practices
- Use structured logging
- Handle all error cases
- Clean up resources
- Monitor performance
- Document patterns
- Test edge cases
- Use helper functions
- Keep focused
- Follow patterns
- Handle timeouts

## Performance Tips
- Check log levels
- Use buffering
- Clean up promptly
- Monitor resources
- Handle timeouts
- Batch operations
- Cache results
- Stream large files