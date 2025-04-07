# Logging Module Components

The firmo logging system consists of several integrated components that together provide a comprehensive, flexible, and performance-optimized logging solution. This document details the individual components and their APIs.

## Table of Contents

1. [Core Logging Module](#core-logging-module)
2. [Export Module](#export-module)
3. [Search Module](#search-module)
4. [Formatter Integration Module](#formatter-integration-module)
5. [Component Interactions](#component-interactions)

## Core Logging Module

**File:** `lib/tools/logging.lua`

The core logging module provides the central logging functionality, including logger creation, configuration, and basic log output.

### Key Features

- Named logger instances with independent configuration
- Hierarchical log levels (FATAL, ERROR, WARN, INFO, DEBUG, TRACE)
- Structured logging with context objects
- Configurable output formats and destinations
- Color-coded console output
- File logging with rotation
- Module-specific log level configuration
- Performance-optimized logging with buffer support
- Integration with the central configuration system

### API Reference

#### Logger Creation

```lua
-- Import the logging module
local logging = require("lib.tools.logging")

-- Create a logger for your module
local logger = logging.get_logger("my_module")
```

#### Log Methods

Each logger provides these methods:

```lua
-- Log levels from highest to lowest priority
logger.fatal("Critical error: system cannot continue", {error = err})
logger.error("Operation failed", {operation = "save_file", error = err})
logger.warn("Configuration value missing, using default", {key = "timeout"})
logger.info("Process completed successfully", {items = 42})
logger.debug("Function called with parameters", {param1 = "value", param2 = 123})
logger.trace("Detailed execution information", {state = {...}})
```

#### Configuration

```lua
-- Global configuration
logging.configure({
  level = logging.LEVELS.INFO,      -- Global default level
  timestamps = true,                -- Include timestamps in logs
  use_colors = true,                -- Use ANSI colors for console output
  output_file = "application.log",  -- Log to file (nil = console only)
  log_dir = "logs",                 -- Directory for log files
  max_file_size = 1024 * 1024,      -- 1MB max file size before rotation
  max_log_files = 5,                -- Keep 5 rotated log files
  format = "text",                  -- Log format: "text" or "json"
  json_file = "application.json",   -- Separate JSON structured log file
  buffer_size = 100,                -- Buffer size (0 = no buffering)
  buffer_flush_interval = 5,        -- Seconds between auto-flush (if buffering)
  module_filter = {"ui", "network"},-- Only show logs from these modules
  module_blacklist = {"metrics"},   -- Hide logs from these modules
  standard_metadata = {             -- Added to all logs
    version = "1.0.0",
    environment = "production"
  }
})

-- Module-specific configuration
logging.set_module_level("database", logging.LEVELS.DEBUG)
logging.filter_module("ui*")  -- Wildcard pattern for module filtering
logging.blacklist_module("metrics")  -- Hide logs from this module
```

#### Performance Optimization

```lua
-- Check if level is enabled before expensive operations
if logger.is_debug_enabled() then
  -- Only do this expensive operation if debug logging is enabled
  local stats = gather_detailed_statistics()
  logger.debug("Performance statistics", stats)
end

-- Use buffered logging for high-volume scenarios
local buffered_logger = logging.create_buffered_logger("metrics", {
  buffer_size = 1000,        -- Buffer up to 1000 messages
  flush_interval = 10,       -- Flush every 10 seconds
  output_file = "metrics.log" -- Write to specific file
})

-- Flush buffers manually when needed
logging.flush()
```

#### Central Configuration Integration

```lua
-- Configure logging based on central config
logging.configure_from_config("my_module")

-- Configure based on command-line options
logging.configure_from_options("my_module", {
  debug = true,     -- Sets DEBUG level if true
  verbose = false   -- Sets TRACE level if true (only if debug is false)
})
```

## Export Module

**File:** `lib/tools/logging/export.lua`

The export module provides functionality for exporting logs to various external logging platforms and formats.

### Key Features

- Export logs to popular logging platforms (Elasticsearch, Logstash, Splunk, Datadog, Loki)
- Convert between log formats (text, JSON, platform-specific)
- Generate configuration files for logging platforms
- Create real-time log exporters for streaming logs to external systems

### Supported Platforms

- **Elasticsearch**: JSON-based search and analytics engine
- **Logstash**: Log collection, parsing, and forwarding
- **Splunk**: Enterprise log monitoring and analysis
- **Datadog**: Cloud monitoring and analytics
- **Loki**: Grafana's log aggregation system

### API Reference

#### Platform-Specific Export

```lua
-- Import the export module
local log_export = require("lib.tools.logging.export")

-- Get list of supported platforms
local platforms = log_export.get_supported_platforms()
-- Returns: {"logstash", "elasticsearch", "splunk", "datadog", "loki"}

-- Export logs to a platform-specific format
local entries, err = log_export.export_to_platform(
  log_entries,           -- Array of log entries
  "elasticsearch",       -- Target platform
  {                      -- Platform-specific options
    service_name = "my_app",
    environment = "production"
  }
)
```

#### Configuration File Generation

```lua
-- Create a configuration file for a specific platform
local result, err = log_export.create_platform_config(
  "elasticsearch",             -- Platform name
  "config/elasticsearch.json", -- Output file path
  {                            -- Platform-specific options
    es_host = "logs.example.com:9200",
    index = "my-app-logs"
  }
)
```

#### Log File Conversion

```lua
-- Convert a log file to a platform-specific format
local result, err = log_export.create_platform_file(
  "logs/application.log",     -- Source log file
  "splunk",                   -- Target platform
  "logs/splunk_format.json",  -- Output file path
  {                           -- Options
    source_format = "text",   -- Source format: "text" or "json"
    source = "my-application",
    sourcetype = "app:logs"
  }
)

-- Result contains:
-- {
--   entries_processed = 157,  -- Number of entries processed
--   output_file = "logs/splunk_format.json",
--   entries = { ... }         -- Array of formatted entries
-- }
```

#### Real-Time Exporters

```lua
-- Create a real-time log exporter
local exporter, err = log_export.create_realtime_exporter(
  "datadog",                  -- Platform name
  {                           -- Platform-specific options
    api_key = "YOUR_API_KEY",
    service = "my-service",
    environment = "production"
  }
)

-- Use the exporter
local formatted_entry = exporter.export({
  timestamp = "2025-03-26T14:32:45",
  level = "ERROR",
  module = "database",
  message = "Connection failed",
  params = {
    host = "db.example.com",
    error = "Connection refused"
  }
})

-- Exporter contains HTTP endpoint information if needed
local endpoint = exporter.http_endpoint
-- { method = "POST", url = "https://http-intake.logs.datadoghq.com/v1/input", ... }
```

## Search Module

**File:** `lib/tools/logging/search.lua`

The search module provides functionality for searching and analyzing log files.

### Key Features

- Search log files with flexible filtering criteria
- Parse log files in various formats (text, JSON)
- Filter log entries by level, module, timestamp, and message content
- Extract statistics and metrics from log files
- Export log data to different formats (CSV, JSON, HTML)
- Create real-time log processors for continuous log analysis

### API Reference

#### Basic Log Search

```lua
-- Import the search module
local log_search = require("lib.tools.logging.search")

-- Search logs with various criteria
local results = log_search.search_logs({
  log_file = "logs/application.log", -- Log file to search
  level = "ERROR",                   -- Filter by log level
  module = "database",               -- Filter by module name
  from_date = "2025-03-20 00:00:00", -- Filter by start date/time
  to_date = "2025-03-26 23:59:59",   -- Filter by end date/time
  message_pattern = "connection",    -- Pattern to search for in messages
  limit = 100                        -- Maximum results to return
})

-- Results contain:
-- {
--   entries = { ... },  -- Array of matching log entries
--   count = 42,         -- Number of matches
--   truncated = false   -- Whether results were limited
-- }
```

#### Log Statistics

```lua
-- Get statistics about a log file
local stats = log_search.get_log_stats(
  "logs/application.log",
  { format = "json" }  -- Optional format (defaults to autodetect)
)

-- Stats contain:
-- {
--   total_entries = 1542,   -- Total number of log entries
--   by_level = {            -- Count by log level
--     ERROR = 12,
--     WARN = 45,
--     INFO = 978,
--     DEBUG = 507
--   },
--   by_module = {           -- Count by module
--     database = 256,
--     ui = 145,
--     network = 412,
--     ...
--   },
--   errors = 12,            -- Total error count
--   warnings = 45,          -- Total warning count
--   first_timestamp = "2025-03-20 08:15:42",  -- First log entry time
--   last_timestamp = "2025-03-26 17:30:12",   -- Last log entry time
--   file_size = 256000      -- Log file size in bytes
-- }
```

#### Log Export

```lua
-- Export logs to a different format
local result = log_search.export_logs(
  "logs/application.log",      -- Source log file
  "reports/logs_export.html",  -- Output file path
  "html",                      -- Format: "csv", "json", "html", or "text"
  {                            -- Options
    source_format = "json"     -- Source format (default: autodetect)
  }
)

-- Result contains:
-- {
--   entries_processed = 1542,  -- Number of entries processed
--   output_file = "reports/logs_export.html"
-- }
```

#### Real-Time Log Processing

```lua
-- Create a log processor for real-time analysis
local processor = log_search.get_log_processor({
  output_file = "filtered_logs.json", -- Output file (optional)
  format = "json",                    -- Output format
  level = "ERROR",                    -- Only process errors
  module = "database*",               -- Only process database modules
  
  -- Custom callback for each log entry
  callback = function(log_entry)
    -- Do custom processing here
    print("Processing error: " .. log_entry.message)
    return true -- Return false to stop processing
  end
})

-- Process a log entry
processor.process({
  timestamp = "2025-03-26 14:35:22",
  level = "ERROR",
  module = "database",
  message = "Connection failed",
  params = { host = "db.example.com" }
})

-- Close the processor when done
processor.close()
```

#### Log Export Adapters

```lua
-- Create an adapter for a specific platform
local adapter = log_search.create_export_adapter(
  "logstash",               -- Adapter type: "logstash", "elk", "splunk", "datadog"
  {                         -- Platform-specific options
    application_name = "my_app",
    environment = "production"
  }
)

-- Use the adapter to format a log entry
local formatted = adapter({
  timestamp = "2025-03-26 14:35:22",
  level = "ERROR",
  module = "database",
  message = "Connection failed",
  params = { host = "db.example.com" }
})
```

## Formatter Integration Module

**File:** `lib/tools/logging/formatter_integration.lua`

The formatter integration module provides integration between the logging system and test output formatters.

### Key Features

- Enhance test formatters with logging capabilities
- Create test-specific loggers with context
- Collect and attach logs to test results
- Create specialized formatters for log-friendly output
- Step-based logging for test execution phases

### API Reference

#### Formatter Enhancement

```lua
-- Import the formatter integration module
local formatter_integration = require("lib.tools.logging.formatter_integration")

-- Enhance all registered formatters with logging capabilities
local formatters = formatter_integration.enhance_formatters()

-- Enable logging for a specific formatter
formatter_integration.enable_formatter_logging(
  "html",                   -- Formatter name
  html_formatter           -- Formatter object
)
```

#### Test-Specific Logging

```lua
-- Create a test-specific logger with context
local test_logger = formatter_integration.create_test_logger(
  "Database Connection Test",    -- Test name
  {                              -- Test context
    component = "database",
    test_type = "integration"
  }
)

-- Log with test context automatically included
test_logger.info("Starting database connection test")
-- Result: "[INFO] [test.Database_Connection_Test] Starting database connection test 
--          (test_name=Database Connection Test, component=database, test_type=integration)"

-- Create a step-specific logger
local step_logger = test_logger.step("Connection establishment")
step_logger.info("Connecting to database")
-- Result includes step name in the context
```

#### Log Collection for Tests

```lua
-- Start capturing logs for a specific test
formatter_integration.capture_start(
  "Database Connection Test",   -- Test name
  "test_123"                    -- Unique test ID
)

-- Run the test (logs are captured)
test_function()

-- End capture and get collected logs
local logs = formatter_integration.capture_end("test_123")

-- Attach logs to test results
local enhanced_results = formatter_integration.attach_logs_to_results(
  test_results,  -- Original test results
  logs           -- Captured logs
)
```

#### Custom Log Formatter

```lua
-- Create a specialized formatter for log output
local log_formatter = formatter_integration.create_log_formatter()

-- Initialize with options
log_formatter:init({
  output_file = "test-results.log.json",
  format = "json"
})

-- Format test results with enhanced logging
local result = log_formatter:format(test_results)
```

#### Integration with Reporting System

```lua
-- Integrate logging with the test reporting system
local reporting = formatter_integration.integrate_with_reporting({
  include_logs = true,            -- Include logs in reports
  include_debug = false,          -- Exclude DEBUG level logs
  max_logs_per_test = 50,         -- Limit logs per test
  attach_to_results = true        -- Automatically attach logs to results
})
```

## Component Interactions

The logging system components work together in the following ways:

1. **Core Logging Module**
   - Provides the main API that users interact with directly
   - Manages configuration, levels, and module filtering
   - Handles writing logs to console and files
   - Lazy-loads other components when needed

2. **Export Module**
   - Used by core module when exporting logs to external platforms
   - Provides adapters for different log analysis systems
   - Handles format conversion for external consumption

3. **Search Module**
   - Separate utility for analyzing existing log files
   - Can be used independently for log analysis tasks
   - Provides export functionality for log reports

4. **Formatter Integration Module**
   - Bridges logging and test reporting systems
   - Enhances test formatters with logging capabilities
   - Provides context-aware logging during test execution

### Usage Flow

1. **Application Initialization**
   - Import core logging module
   - Configure global settings
   - Create module-specific loggers

2. **Runtime Logging**
   - Applications use module-specific loggers
   - Logs are output to console and/or files
   - Buffer management and rotation happen automatically

3. **Test Integration**
   - Formatter integration enhances test output
   - Test-specific loggers provide context
   - Test logs are collected and attached to results

4. **Log Analysis**
   - Search module analyzes existing log files
   - Export module converts to external formats
   - Log data is presented in reports or dashboards

### Configuration Flow

The logging system follows this configuration priority:

1. Direct configuration (`logging.configure()`)
2. Central configuration system (`.firmo-config.lua`)
3. Command-line options (`--debug`, `--verbose`)
4. Default configuration values

Module-specific settings override global settings.