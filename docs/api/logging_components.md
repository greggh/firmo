# Logging Module Components


The firmo logging system consists of several integrated components that together provide a comprehensive, flexible, and performance-optimized logging solution. This document details the individual components and their APIs.

## Table of Contents



1. [Core Logging Module](#core-logging-module)
2. [Export Module](#export-module)
3. [Search Module](#search-module)
4. [Formatter Integration Module](#formatter-integration-module)
   - [Log Capture](#log-capture)
5. [Component Interactions](#component-interactions)
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
-- Results contain (LogSearchResults):
-- {
--   entries = { ... },  -- Array of matching log entries
--   total = 1500,       -- Total number of entries processed
--   matched = 42,       -- Number of entries that matched filters
--   count = 42,         -- Alias for matched
--   truncated = false   -- True if the search hit the result limit
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
  "logstash",               -- Adapter type: "logstash", "elasticsearch", "splunk", "datadog", "loki"
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

```


#### Log Capture

##### `formatter_integration.capture_start(test_name, test_id)`

Starts capturing logs associated with a specific test run.

```lua
---@param test_name string Name of the test being run.
---@param test_id string Unique ID for this specific test run instance.
```
**Parameters:**
- `test_name` (string): Name of the test.
- `test_id` (string): Unique ID for the test run.
**Returns:** `nil`
**Example:**
```lua
formatter_integration.capture_start("My Test Case", "run-123")
-- Logs generated after this point will be captured under "run-123"
```


##### `formatter_integration.capture_end(test_id)`

Stops capturing logs for a specific test run and returns the collected logs.

```lua
---@param test_id string The unique ID used in `capture_start`.
---@return table[] captured_logs An array of captured log entry tables.
```
**Parameters:**
- `test_id` (string): Unique ID for the test run.
**Returns:**
- `captured_logs` (table[]): Array of log entry tables captured for this test ID.
**Example:**
```lua
local captured_logs = formatter_integration.capture_end("run-123")
print("Captured " .. #captured_logs .. " log entries.")
```


##### `formatter_integration.attach_logs_to_results(test_results, captured_logs)`

Attaches captured logs to a test results object.

```lua
---@param test_results table The results object for a single test.
---@param captured_logs table[] Array of log entries captured for this test.
---@return table test_results The modified `test_results` table with a `logs` field added.
```
**Parameters:**
- `test_results` (table): The test result object.
- `captured_logs` (table[]): The array of logs returned by `capture_end`.
**Returns:**
- `test_results` (table): The input `test_results` table, now including a `logs` field containing `captured_logs`.
**Example:**
```lua
local results = { name = "My Test", status = "pass" }
local logs = formatter_integration.capture_end("run-123")
local results_with_logs = formatter_integration.attach_logs_to_results(results, logs)
-- results_with_logs now has a .logs field
```
```


#### Log Capture

##### `formatter_integration.capture_start(test_name, test_id)`

Starts capturing logs associated with a specific test run.

```lua
---@param test_name string Name of the test being run.
---@param test_id string Unique ID for this specific test run instance.
```
**Parameters:**
- `test_name` (string): Name of the test.
- `test_id` (string): Unique ID for the test run.
**Returns:** `nil`
**Example:**
```lua
formatter_integration.capture_start("My Test Case", "run-123")
-- Logs generated after this point will be captured under "run-123"
```


##### `formatter_integration.capture_end(test_id)`

Stops capturing logs for a specific test run and returns the collected logs.

```lua
---@param test_id string The unique ID used in `capture_start`.
---@return table[] captured_logs An array of captured log entry tables.
```
**Parameters:**
- `test_id` (string): Unique ID for the test run.
**Returns:**
- `captured_logs` (table[]): Array of log entry tables captured for this test ID.
**Example:**
```lua
local captured_logs = formatter_integration.capture_end("run-123")
print("Captured " .. #captured_logs .. " log entries.")
```


##### `formatter_integration.attach_logs_to_results(test_results, captured_logs)`

Attaches captured logs to a test results object.

```lua
---@param test_results table The results object for a single test.
---@param captured_logs table[] Array of log entries captured for this test.
---@return table test_results The modified `test_results` table with a `logs` field added.
```
**Parameters:**
- `test_results` (table): The test result object.
- `captured_logs` (table[]): The array of logs returned by `capture_end`.
**Returns:**
- `test_results` (table): The input `test_results` table, now including a `logs` field containing `captured_logs`.
**Example:**
```lua
local results = { name = "My Test", status = "pass" }
local logs = formatter_integration.capture_end("run-123")
local results_with_logs = formatter_integration.attach_logs_to_results(results, logs)
-- results_with_logs now has a .logs field
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
