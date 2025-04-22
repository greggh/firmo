# Logging Module Configuration


This document describes the comprehensive configuration options for the firmo logging system, which provides structured, leveled logging with multiple output formats and destinations.

## Overview


The logging module provides a powerful logging system with support for:


- Multiple named loggers with independent configuration
- Hierarchical log levels (FATAL, ERROR, WARN, INFO, DEBUG, TRACE/VERBOSE)
- Structured logging with context objects
- Multiple output formats (text, JSON)
- Output to console, files, or both
- Log rotation and file management
- Module-specific log levels and filtering
- Buffered logging for high-performance scenarios


## Configuration Options


### Basic Options


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `level` | string or number | `"INFO"` | Global log level threshold |
| `timestamps` | boolean | `true` | Include timestamps in log entries |
| `use_colors` | boolean | `true` | Use ANSI colors in console output |
| `output_file` | string | `nil` | Path to log file (nil = console only) |
| `log_dir` | string | `"logs"` | Directory for log files |
| `silent` | boolean | `false` | Suppress all logging output |
| `format` | string | `"text"` | Log format: "text" or "json" |

### Module-Specific Options


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `module_levels` | table | `{}` | Log levels by module name |
| `module_filter` | string/table | `nil` | Only log from specified modules |
| `module_blacklist` | table | `{}` | Never log from specified modules |

### File and Rotation Options


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max_file_size` | number | `50 * 1024` | Maximum log file size in bytes (50KB) |
| `max_log_files` | number | `5` | Number of rotated log files to keep |
| `date_pattern` | string | `"%Y-%m-%d"` | Date pattern for log file names |
| `json_file` | string | `nil` | Path for JSON structured logs |

### Performance Options


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `buffer_size` | number | `0` | Buffer size (0 = no buffering) |
| `buffer_flush_interval` | number | `5` | Seconds between auto-flush if buffering |
| `standard_metadata` | table | `{}` | Fields to include in all log entries |

## Configuration in .firmo-config.lua


You can configure the logging system in your `.firmo-config.lua` file:


```lua
return {
  -- Global logging configuration
  logging = {
    -- Basic configuration
    level = "DEBUG",
    timestamps = true, 
    use_colors = true,

    -- Output destinations
    output_file = "app.log",
    log_dir = "logs",
    format = "text",
    json_file = "logs/structured.json",

    -- File management
    max_file_size = 1024 * 1024,  -- 1MB
    max_log_files = 10,
    date_pattern = "%Y-%m-%d",

    -- Module-specific configuration
    modules = {
      Database = "INFO",     -- Database module at INFO level
      Network = "DEBUG",     -- Network module at DEBUG level
      UI = "WARN"            -- UI module at WARN level
    },

    -- Filtering
    module_filter = {"Database", "Auth*"}, -- Only log from Database and Auth* modules
    module_blacklist = {"Stats"},          -- Never log from Stats module

    -- Performance options
    buffer_size = 100,                     -- Buffer up to 100 messages
    buffer_flush_interval = 10,            -- Flush every 10 seconds

    -- Standard metadata included in all logs
    standard_metadata = {
      app_name = "MyApp",
      version = "1.0.0",
      environment = "production"
    }
  }
}
```



## Programmatic Configuration


You can also configure the logging system programmatically:


```lua
local logging = require("lib.tools.logging")
-- Global configuration
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "app.log",
  log_dir = "logs",
  format = "json",
  max_file_size = 1024 * 1024  -- 1MB
})
-- Module-specific configuration
logging.set_module_level("Database", logging.LEVELS.INFO)
  .set_module_level("Network", logging.LEVELS.DEBUG)
  .set_module_level("UI", logging.LEVELS.WARN)
-- Configure from central config
logging.configure_from_config("MyModule")
```



## Log Levels


The logging system supports the following log levels, in order of decreasing severity:
| Level | Numeric Value | Description |
|-------|---------------|-------------|
| `FATAL` | 0 | Critical errors that prevent application from continuing |
| `ERROR` | 1 | Error conditions that affect operation of component/subsystem |
| `WARN` | 2 | Warning conditions, potential issues, unexpected states |
| `INFO` | 3 | Informational messages, normal operation status |
| `DEBUG` | 4 | Detailed information for debugging and development |
| `TRACE`/`VERBOSE` | 5 | Very detailed trace information for fine-grained debugging |

## Module Filtering


The logging system provides powerful filtering capabilities to control which modules' logs are displayed:

### Whitelist Filtering


The `module_filter` option allows you to specify which modules should have their logs displayed:


```lua
-- Through central configuration
logging = {
  module_filter = {"Database", "Auth*"}  -- Only log from Database and Auth* modules
}
-- Programmatically
logging.filter_module("Database")
  .filter_module("Auth*")
```



### Blacklist Filtering


The `module_blacklist` option allows you to specify modules that should never log:


```lua
-- Through central configuration
logging = {
  module_blacklist = {"Stats", "Metrics*"}  -- Never log from Stats or Metrics* modules
}
-- Programmatically
logging.blacklist_module("Stats")
  .blacklist_module("Metrics*")
```



## File Output and Rotation


The logging system supports writing logs to files with automatic rotation:


```lua
-- Configure file output
logging.configure({
  output_file = "app.log",       -- Log file name
  log_dir = "logs",              -- Directory for log files
  max_file_size = 1024 * 1024,   -- 1MB maximum file size
  max_log_files = 10             -- Keep 10 rotated files
})
```


When a log file reaches the maximum size:


1. The current file (app.log) is renamed to app.log.1
2. Existing rotated files move up one position (app.log.1 → app.log.2, etc.)
3. The oldest file is deleted if the number of files exceeds max_log_files
4. A new empty log file is created


## JSON Structured Logging


The logging system can generate structured JSON logs alongside or instead of text logs:


```lua
-- Configure JSON logging
logging.configure({
  format = "json",            -- Use JSON format for console
  json_file = "app.json.log"  -- Also write structured logs to file
})
```


JSON logs include standard fields and all context parameters:


```json
{
  "timestamp": "2025-03-27T14:35:22",
  "level": "INFO",
  "module": "Database",
  "message": "Query executed successfully",
  "query_id": "SELECT001",
  "duration_ms": 42,
  "rows_affected": 10
}
```



## Buffered Logging


For high-performance scenarios, the logging system supports buffered logging:


```lua
-- Configure buffered logging
logging.configure({
  buffer_size = 1000,            -- Buffer up to 1000 messages
  buffer_flush_interval = 10,    -- Flush every 10 seconds
  output_file = "high_volume.log"
})
-- Or create a dedicated buffered logger
local metrics_logger = logging.create_buffered_logger("Metrics", {
  buffer_size = 1000,
  flush_interval = 10,
  output_file = "metrics.log"
})
```


Buffered logging reduces I/O operations by:


1. Collecting multiple log messages in memory
2. Writing them to disk in batches when:
   - The buffer fills up (hits buffer_size)
   - The flush interval elapses (buffer_flush_interval seconds)
   - The flush() method is called manually


## Advanced Usage


### Getting or Creating Loggers



```lua
-- Get a logger for a specific module
local logger = logging.get_logger("Database")
-- Use the logger
logger.info("Connection established", {host = "localhost", port = 5432})
logger.warn("Slow query detected", {query_id = "SELECT001", execution_time = 1.5})
logger.error("Connection failed", {error_code = "ACCESS_DENIED"})
```



### Checking Log Levels



```lua
-- Check if a level is enabled before performing expensive operations
if logger.is_debug_enabled() then
  -- Only execute expensive debug code if debug logging is enabled
  local stats = generate_detailed_statistics()
  logger.debug("Performance statistics", stats)
end
```



### Temporarily Changing Log Levels



```lua
-- Temporarily increase log level for a specific operation
logging.with_level("Database", "DEBUG", function()
  -- This code block will have Database logging at DEBUG level
  db.execute_query("SELECT * FROM users")
end)
-- The original log level is automatically restored after function completes
```



## Example Logger Usage



```lua
-- Get a logger
local logger = logging.get_logger("MyModule")
-- Basic logging with context
logger.info("Application started", {version = "1.0.0"})
-- Different log levels
logger.debug("Processing request", {user_id = 12345, request = "/api/data"})
logger.info("User authenticated", {user_id = 12345})
logger.warn("Rate limit approaching", {user_id = 12345, current = 80, limit = 100})
logger.error("Database query failed", {error = "Connection timeout"})
-- Check log level before expensive operations
if logger.is_debug_enabled() then
  local details = calculate_detailed_metrics()
  logger.debug("Request metrics", details)
end
-- Log with context
logger.info("Processing completed", {
  duration_ms = 42,
  success = true,
  items_processed = 10
})
```



## Integration with Error Handler


The logging system integrates with the error handler module to handle expected errors in tests:


```lua
-- If this error occurs in a test marked with {expect_error = true},
-- It will be logged as DEBUG level with [EXPECTED] prefix
logger.error("Operation failed", {error = "Connection refused"})
```


In tests marked with `{expect_error = true}`, errors will be:


1. Prefixed with `[EXPECTED]` to indicate they're part of the test
2. Downgraded to DEBUG level (unless --debug flag is present)
3. Collected for potential debugging and analysis
