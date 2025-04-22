# Logging Knowledge


## Purpose


Centralized logging system with structured output and configuration.

## Logging Usage



```lua
-- Get module logger
local logger = logging.get_logger("module_name")
-- Basic logging with context
logger.info("Operation completed", {
  duration = time_taken,
  items = count,
  status = "success"
})
-- Error logging with structured data
logger.error("Operation failed", {
  error = err,
  category = err.category,
  context = operation_context,
  stack = debug.traceback()
})
-- Complex logging scenario
local function setup_module_logging()
  -- Configure logger
  local logger = logging.get_logger("my_module")
  logger.configure({
    level = "DEBUG",
    file = "logs/my_module.log",
    format = "json",
    rotation = {
      size = "10M",
      keep = 5
    }
  })

  -- Performance-aware logging
  if logger.would_log("debug") then
    -- Only compute expensive debug info if needed
    logger.debug("Detailed state", {
      state = compute_expensive_state()
    })
  end

  -- Batch logging for performance
  logger.batch_start()
  for i = 1, 1000 do
    logger.debug("Processing item", { index = i })
  end
  logger.batch_flush()

  -- Error context
  local function with_error_context(context, callback)
    logger.push_context(context)

    local result, err = error_handler.try(callback)

    logger.pop_context()

    if not result then
      logger.error("Operation failed", {
        error = err,
        context = context
      })
      return nil, err
    end

    return result
  end
end
```



## Log Levels



```lua
-- Available levels
local levels = {
  ERROR = 1,   -- Critical errors preventing operation
  WARN = 2,    -- Concerning but non-critical issues
  INFO = 3,    -- Important state changes
  DEBUG = 4,   -- Developer troubleshooting info
  VERBOSE = 5  -- Detailed execution info
}
-- Configure levels per module
logging.configure({
  ["module_name"] = {
    level = "DEBUG",
    file = "logs/module.log",
    format = "json",
    buffer_size = 1024,
    flush_interval = 1000
  }
})
-- Level-specific logging
logger.error("Critical error", { error = err })
logger.warn("Concerning issue", { issue = details })
logger.info("State change", { old = old_state, new = new_state })
logger.debug("Debug info", { details = debug_data })
logger.verbose("Execution details", { trace = execution_trace })
```



## Error Handling



```lua
-- Safe logging pattern
local function safe_log(level, message, context)
  local success, err = error_handler.try(function()
    logger[level](message, context)
  end)

  if not success then
    -- Fallback to console
    io.stderr:write(string.format(
      "[%s] %s: %s\n",
      level,
      message,
      err.message
    ))
  end
end
-- Handle logging errors
local function with_log_error_handling(callback)
  local success, err = error_handler.try(callback)

  if not success then
    logger.error("Logging error", {
      error = err,
      category = err.category
    })
    return nil, err
  end

  return success
end
```



## Critical Rules



- Use structured logging
- Configure from central_config
- Clean up log files
- Handle rotation
- Check log levels
- Document patterns
- Test thoroughly
- Monitor performance


## Best Practices



- Use module loggers
- Include context
- Check levels
- Clean up logs
- Handle rotation
- Monitor size
- Use batching
- Structure data
- Handle errors
- Document patterns


## Performance Tips



- Check would_log
- Use buffering
- Keep context small
- Avoid concatenation
- Use structured data
- Batch operations
- Monitor file size
- Handle rotation
- Clean up old logs
