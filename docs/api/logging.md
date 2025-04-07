# Logging API

The firmo logging system provides a comprehensive structured logging framework with support for multiple severity levels, module-specific configuration, various output formats, search capabilities, external tool integration, and test reporting integration.

## Basic Usage

```lua
-- Import the logging module
local logging = require("lib.tools.logging")

-- Create a logger for your module
local logger = logging.get_logger("my_module")

-- Use various logging levels
logger.fatal("Severe error requiring immediate attention")
logger.error("Critical error: database connection failed")
logger.warn("Warning: configuration file missing, using defaults")
logger.info("Server started on port 8080")
logger.debug("Request parameters", {user_id = 123, query = "search term"})
logger.trace("Function called with arguments", {args = {1, 2, 3}})

-- Structured logging with parameters
logger.info("User logged in", {
  user_id = 123,
  ip_address = "192.168.1.1",
  login_time = os.time()
})
```

## Log Levels

The logging system supports 6 severity levels:

| Level   | Constant              | Description                                       |
|---------|------------------------|--------------------------------------------------|
| FATAL   | logging.LEVELS.FATAL   | Severe errors that prevent application operation  |
| ERROR   | logging.LEVELS.ERROR   | Critical errors that prevent normal operation     |
| WARN    | logging.LEVELS.WARN    | Unexpected conditions that don't stop execution   |
| INFO    | logging.LEVELS.INFO    | Normal operational messages                       |
| DEBUG   | logging.LEVELS.DEBUG   | Detailed information useful for debugging         |
| TRACE   | logging.LEVELS.TRACE   | Extremely detailed diagnostic information         |

## Logging Module API

### Core Functions

- **get_logger(module_name)**: Creates/retrieves a logger for the specified module
- **configure(options)**: Sets up global logging configuration
- **configure_from_config(module_name)**: Configures logging based on global configuration
- **configure_from_options(module_name, options)**: Configures logging from command-line options
- **set_module_level(module_name, level)**: Sets the log level for a specific module
- **flush()**: Flushes any buffered log messages
- **silent_mode(enabled)**: Enables/disables silent mode for testing

### Logger Objects

Each logger created with `get_logger()` provides these methods:

- **fatal(message, params)**: Logs a fatal error message
- **error(message, params)**: Logs an error message
- **warn(message, params)**: Logs a warning message
- **info(message, params)**: Logs an information message
- **debug(message, params)**: Logs a debug message
- **trace(message, params)**: Logs a trace message
- **would_log(level)**: Checks if a message at the specified level would be logged
- **is_fatal_enabled()**: Checks if FATAL level is enabled
- **is_error_enabled()**: Checks if ERROR level is enabled
- **is_warn_enabled()**: Checks if WARN level is enabled
- **is_info_enabled()**: Checks if INFO level is enabled
- **is_debug_enabled()**: Checks if DEBUG level is enabled
- **is_trace_enabled()**: Checks if TRACE level is enabled

## Configuration Options

### Basic Configuration

```lua
logging.configure({
  level = logging.LEVELS.INFO,     -- Global default level
  timestamps = true,               -- Include timestamps in log messages
  use_colors = true,               -- Use ANSI colors in console output
  output_file = "firmo.log",       -- Log to file (nil = console only)
  log_dir = "logs",                -- Directory for log files
  max_file_size = 1024 * 1024,     -- 1MB max file size before rotation
  max_log_files = 5,               -- Keep 5 rotated log files
  format = "text",                 -- Log format: "text" or "json"
  json_file = "firmo.json",        -- Separate JSON structured log file
  buffering = false,               -- Buffer logs for higher performance
  buffer_size = 100,               -- Buffer size when buffering is enabled
  buffer_flush_interval = 5000,    -- Auto-flush buffer every 5 seconds
  silent_mode = false,             -- Disable all output (for testing)
  standard_metadata = {            -- Metadata added to all logs
    version = "1.0.0",
    environment = "production"
  }
})
```

### Module-Specific Levels

```lua
-- Set levels for specific modules
logging.set_module_level("ui", logging.LEVELS.ERROR)
logging.set_module_level("network", logging.LEVELS.DEBUG)

-- Or configure multiple modules at once
logging.configure({
  module_levels = {
    ui = logging.LEVELS.ERROR,
    network = logging.LEVELS.DEBUG,
    database = logging.LEVELS.WARN
  }
})
```

### Module Filtering

```lua
-- Only show logs from specific modules
logging.filter_module("ui")
logging.filter_module("api")

-- Use wildcards to match multiple modules
logging.filter_module("test*")  -- Any module starting with "test"

-- Clear filters to show all modules again
logging.clear_module_filters()
```

### Module Blacklisting

```lua
-- Hide logs from specific modules
logging.blacklist_module("database")

-- Use wildcards to hide multiple modules
logging.blacklist_module("debug*")  -- Hide any module starting with "debug"

-- Clear the blacklist
logging.clear_blacklist()
```

## Structured Logging

For machine processing and log analysis tools, the logging system supports JSON structured output:

```lua
logging.configure({
  format = "text",              -- Console format remains human-readable
  json_file = "app.json",       -- Separate machine-readable JSON log
  output_file = "app.log"       -- Regular text log still available
})
```

### Parameter Logging

You can attach structured parameters to any log message:

```lua
logger.info("Processing completed", {
  items_processed = 157,
  duration_ms = 432,
  success_rate = 0.98,
  source = "monthly_report"
})
```

## Log Rotation

The logging system automatically rotates log files when they reach the configured size:

```lua
logging.configure({
  output_file = "app.log",       -- Log file name
  log_dir = "logs",              -- Log directory
  max_file_size = 10 * 1024,     -- 10KB max file size
  max_log_files = 3              -- Keep 3 rotated log files
})
```

When rotation occurs:
- The current log file (app.log) is moved to app.log.1
- Previous rotated files move up: app.log.1 → app.log.2, etc.
- The oldest rotated file is deleted if max_log_files is exceeded

## Integration with Central Configuration

The logging system integrates with firmo's central configuration system:

```lua
-- In your .firmo-config.lua file:
return {
  -- Test configuration
  filter = ".*test",
  verbose = true,
  
  -- Logging configuration
  logging = {
    level = 3,  -- INFO level
    timestamps = true,
    output_file = "firmo.log",
    log_dir = "logs",
    module_levels = {
      coverage = 4,  -- DEBUG level for coverage module
      reporting = 2  -- WARN level for reporting module
    },
    format = "text",
    json_file = "firmo.json"
  }
}
```

To configure a module using the central config:

```lua
local logging = require("lib.tools.logging")
local logger = logging.get_logger("my_module")
logging.configure_from_config("my_module")
```

## Error Handling Integration

### Expected Error Suppression

In tests that use the `{ expect_error = true }` flag, expected errors are automatically downgraded to DEBUG level with an [EXPECTED] prefix:

```lua
it("should throw an error for invalid input", { expect_error = true }, function()
  -- This error will be downgraded to DEBUG level in logs
  local result, err = function_that_should_error()
  
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("Invalid input")
})
```

### Error History Access

All expected errors can be accessed programmatically:

```lua
-- After running tests with expected errors
local error_handler = require("lib.tools.error_handler")
local expected_errors = error_handler.get_expected_test_errors()

-- Print all expected errors
for i, err in ipairs(expected_errors) do
  print(string.format("[%s] From module %s: %s", 
    os.date("%H:%M:%S", err.timestamp),
    err.module or "unknown", 
    err.message))
end

-- Clear expected errors when done
error_handler.clear_expected_test_errors()
```

## Performance Considerations

### Check Level Before Expensive Operations

```lua
local logger = logging.get_logger("database")

if logger.is_debug_enabled() then
  -- Only do this expensive operation if debug logging is enabled
  local stats = calculate_detailed_stats()
  logger.debug("Database stats", stats)
end
```

### Using Buffering for High-Volume Logging

```lua
-- Enable buffering globally
logging.configure({
  buffering = true,
  buffer_size = 100,            -- Buffer size (entries)
  buffer_flush_interval = 5000, -- Auto-flush interval (ms)
  buffer_flush_on_exit = true   -- Flush buffer on program exit
})

-- Use buffered logging
local logger = logging.get_logger("high_volume")

for i = 1, 1000 do
  logger.debug("Processing item " .. i)  -- Not written immediately
end

-- Manually flush all buffers
logging.flush_buffers()
```

## Silent Mode for Testing

```lua
-- Enable silent mode (no output)
logging.configure({ silent_mode = true })

-- No output will be produced
local logger = logging.get_logger("test")
logger.info("This won't be output anywhere")

-- Re-enable output
logging.configure({ silent_mode = false })
```

## Test Formatter Integration

The logging system integrates with the test reporting system:

```lua
local formatter_integration = require("lib.tools.logging.formatter_integration")

-- Enhance all test formatters with logging capabilities
formatter_integration.enhance_formatters()

-- Create a test-specific logger with context
local test_logger = formatter_integration.create_test_logger(
  "Database Connection Test",      -- Test name
  { component = "database" }       -- Test context
)

-- Log with test context
test_logger.info("Starting database connection test")
-- Result: "[INFO] [test.Database_Connection_Test] Starting database connection test (test_name=Database Connection Test, component=database)"

-- Create a step-specific logger
local step_logger = test_logger.step("Connection establishment")
step_logger.info("Connecting to database")
-- Result: "[INFO] [test.Database_Connection_Test] Connecting to database (test_name=Database Connection Test, component=database, step=Connection establishment)"
```

## External Tool Integration

The logging system can export logs to popular log analysis platforms:

```lua
local log_export = require("lib.tools.logging.export")

-- Get supported platforms
local platforms = log_export.get_supported_platforms()
-- Returns: {"elasticsearch", "logstash", "splunk", "datadog", "loki"}

-- Create configuration file for a platform
log_export.create_platform_config(
  "elasticsearch",                  -- Platform name
  "config/elasticsearch.json",      -- Output configuration file
  { es_host = "logs.example.com" }  -- Platform-specific options
)

-- Export logs in platform-specific format
log_export.create_platform_file(
  "logs/application.log",          -- Source log file
  "splunk",                        -- Target platform
  "logs/splunk_format.json",       -- Output file
  {                                -- Platform-specific options
    source = "my-application",
    sourcetype = "firmo:application",
    environment = "production"
  }
)
```