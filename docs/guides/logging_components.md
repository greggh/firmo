# Logging Components Guide

This guide provides detailed information on using the various components of firmo's logging system, including the core logging module, export functionality, search capabilities, and formatter integration.

## Table of Contents

1. [Introduction](#introduction)
2. [Core Logging Module](#core-logging-module)
3. [Export Module for External Platforms](#export-module-for-external-platforms)
4. [Search Module for Log Analysis](#search-module-for-log-analysis)
5. [Formatter Integration for Tests](#formatter-integration-for-tests)
6. [Component Interaction Examples](#component-interaction-examples)
7. [Best Practices](#best-practices)

## Introduction

The firmo logging system is modular and consists of several integrated components:

1. **Core Logging Module** (`lib/tools/logging.lua`): The main interface for logging, providing logger creation, configuration, and log output.
2. **Export Module** (`lib/tools/logging/export.lua`): Handles exporting logs to external platforms like Elasticsearch, Logstash, Splunk, Datadog, and Loki.
3. **Search Module** (`lib/tools/logging/search.lua`): Provides functionality for searching, analyzing, and exporting log data.
4. **Formatter Integration Module** (`lib/tools/logging/formatter_integration.lua`): Integrates logging with test reporting and provides test-specific logging capabilities.

These components can be used independently or together, depending on your needs.

## Core Logging Module

The core logging module is the primary interface that most users will interact with. It provides logger creation, configuration, and basic logging functionality.

### Setting Up a Logger

```lua
-- Import the logging module
local logging = require("lib.tools.logging")
-- Create a logger for your module
local logger = logging.get_logger("my_module")
-- Or configure directly
logging.set_module_level("my_module", logging.LEVELS.DEBUG)
```

### Logging at Different Levels

```lua
-- General information
logger.info("Application started", {version = "1.2.3"})
-- Debug information for troubleshooting
logger.debug("Processing request", {request_id = "req123", params = {...}})
-- Warning about potential issues
logger.warn("Retrying operation", {attempt = 3, max_attempts = 5})
-- Errors that prevent normal operation
logger.error("Database connection failed", {host = "db.example.com", error = err})
-- Fatal errors that require immediate attention
logger.fatal("System cannot continue", {reason = "Out of disk space"})
-- Extremely detailed tracing information
logger.trace("Function entered", {function = "process_data", args = {...}})
```

### Log Buffers for Performance

When dealing with high-volume logging, use the buffer capabilities to improve performance:

```lua
-- Configure buffering globally
logging.configure({
  buffer_size = 100,            -- Buffer up to 100 messages
  buffer_flush_interval = 5     -- Auto-flush every 5 seconds
})
-- Or create a dedicated buffered logger
local metrics_logger = logging.create_buffered_logger("metrics", {
  buffer_size = 1000,           -- Buffer up to 1000 messages
  flush_interval = 10,          -- Flush every 10 seconds
  output_file = "metrics.log"   -- Dedicated log file
})
-- Use the buffered logger
for i = 1, 10000 do
  metrics_logger.debug("Processing item", {item_id = i})
end
-- Flush manually when done
metrics_logger.flush()
```

### Structured Logging with Parameters

Always use structured logging with separate parameters for variable data:

```lua
-- BAD: Embedding variable data in messages
logger.info("User john@example.com logged in from 192.168.1.1 at 2025-03-26 14:32:45")
-- GOOD: Separating message from structured data
logger.info("User logged in", {
  email = "john@example.com",
  ip_address = "192.168.1.1",
  timestamp = "2025-03-26 14:32:45"
})
```

The structured parameters are:

- Available for filtering and searching
- Properly formatted in JSON logs
- Displayed in a consistent format in text logs
- Machine-readable for log analysis tools

### Performance Optimization

To avoid expensive operations when logging is disabled:

```lua
if logger.is_debug_enabled() then
  -- Only execute this code if debug logging is enabled
  local detailed_stats = gather_detailed_statistics()
  logger.debug("Performance statistics", detailed_stats)
end
```

This is especially important when:

- Generating debug information is computationally expensive
- The debug information involves formatting large data structures
- You're in a tight loop or performance-critical section

## Export Module for External Platforms

The export module allows you to integrate your logs with external logging platforms and analysis tools.

### Supported Platforms

The export module supports these popular logging platforms:

1. **Elasticsearch**: JSON-based search and analytics engine
2. **Logstash**: Log collection, parsing, and forwarding
3. **Splunk**: Enterprise log monitoring and analysis
4. **Datadog**: Cloud monitoring and analytics
5. **Loki**: Grafana's log aggregation system

### Exporting Logs to External Platforms

```lua
-- Import the export module
local log_export = require("lib.tools.logging.export")
-- Get the list of supported platforms
local platforms = log_export.get_supported_platforms()
-- Returns: {"logstash", "elasticsearch", "splunk", "datadog", "loki"}
-- Format logs for a specific platform
local log_entries = {
  {
    timestamp = "2025-03-26T14:32:45",
    level = "ERROR",
    module = "database",
    message = "Connection failed",
    params = {
      host = "db.example.com",
      port = 5432,
      error = "Connection refused"
    }
  },
  -- More log entries...
}
-- Format for Elasticsearch
local formatted_entries, err = log_export.export_to_platform(
  log_entries,
  "elasticsearch",
  {
    service_name = "my_app",
    environment = "production"
  }
)
-- Now you can send these formatted entries to Elasticsearch
-- (Use an HTTP client or other mechanism to send the data)
```

### Creating Platform Configuration Files

```lua
-- Create a configuration file for Elasticsearch
local result, err = log_export.create_platform_config(
  "elasticsearch",                  -- Platform name
  "config/elasticsearch.json",      -- Output file path
  {                                 -- Platform-specific options
    es_host = "logs.example.com:9200",
    service = "my_service"
  }
)
-- Create a Splunk configuration
local result, err = log_export.create_platform_config(
  "splunk",
  "config/splunk.conf",
  {
    token = "YOUR_SPLUNK_TOKEN",
    index = "my_app_logs"
  }
)
```

### Converting Log Files to Platform Formats

```lua
-- Convert an existing log file to Logstash format
local result, err = log_export.create_platform_file(
  "logs/application.log",      -- Source log file
  "logstash",                  -- Target platform
  "logs/logstash_format.json", -- Output file
  {                            -- Options
    source_format = "text",    -- Source format: "text" or "json"
    application_name = "my_app",
    environment = "production",
    tags = {"web", "backend"}
  }
)
-- Result contains information about the conversion:
-- {
--   entries_processed = 1542,  -- Number of entries processed
--   output_file = "logs/logstash_format.json",
--   entries = {...}            -- Sample of the formatted entries
-- }
```

### Creating Real-Time Exporters

For real-time export of log data to external platforms:

```lua
-- Create a real-time exporter for Datadog
local exporter, err = log_export.create_realtime_exporter(
  "datadog",
  {
    api_key = "YOUR_DATADOG_API_KEY",
    service = "my_service",
    environment = "production",
    tags = {"web", "api"}
  }
)
-- Use the exporter with a log entry
local log_entry = {
  timestamp = "2025-03-26T14:32:45",
  level = "ERROR",
  module = "database",
  message = "Connection failed",
  params = {
    host = "db.example.com",
    error = "Connection refused"
  }
}
-- Format the entry for Datadog
local formatted = exporter.export(log_entry)
-- The exporter also provides HTTP endpoint details
local endpoint = exporter.http_endpoint
-- {
--   method = "POST",
--   url = "https://http-intake.logs.datadoghq.com/v1/input",
--   headers = {
--     ["Content-Type"] = "application/json",
--     ["DD-API-KEY"] = "YOUR_DATADOG_API_KEY"
--   }
-- }
-- You can use these details with an HTTP client to send the data
-- local http = require("some_http_client")
-- http.request(endpoint.method, endpoint.url, endpoint.headers, formatted)
```

## Search Module for Log Analysis

The search module provides tools for searching, analyzing, and exporting log files.

### Searching Log Files

```lua
-- Import the search module
local log_search = require("lib.tools.logging.search")
-- Search for specific logs
local results = log_search.search_logs({
  log_file = "logs/application.log",    -- Log file to search
  level = "ERROR",                      -- Only show errors
  module = "database",                  -- Only show database logs
  from_date = "2025-03-20 00:00:00",    -- Start date/time
  to_date = "2025-03-26 23:59:59",      -- End date/time
  message_pattern = "connection",       -- Message must contain this text
  limit = 100                           -- Maximum results
})
-- Process the results
print("Found " .. results.count .. " matching log entries")
for i, entry in ipairs(results.entries) do
  print(string.format("[%s] %s: %s",
    entry.timestamp,
    entry.level,
    entry.message))
end
-- Check if results were truncated
if results.truncated then
  print("Results were truncated. Increase limit to see more.")
end
```

### Analyzing Log Statistics

```lua
-- Get statistics about a log file
local stats = log_search.get_log_stats(
  "logs/application.log",
  { format = "json" }  -- Optional format (defaults to autodetect)
)
-- Display log statistics
print("Total log entries: " .. stats.total_entries)
print("Date range: " .. stats.first_timestamp .. " to " .. stats.last_timestamp)
print("File size: " .. (stats.file_size / 1024) .. " KB")
-- Show distribution by log level
print("\nDistribution by level:")
for level, count in pairs(stats.by_level) do
  local percentage = (count / stats.total_entries) * 100
  print(string.format("  %s: %d entries (%.1f%%)", level, count, percentage))
end
-- Show top modules by error count
print("\nTop modules by error count:")
local modules_by_errors = {}
for module, count in pairs(stats.by_module) do
  table.insert(modules_by_errors, {name = module, count = count})
end
table.sort(modules_by_errors, function(a, b) return a.count > b.count end)
for i, module in ipairs(modules_by_errors) do
  if i <= 5 then
    print(string.format("  %s: %d entries", module.name, module.count))
  end
end
```

### Exporting Logs to Different Formats

```lua
-- Export logs to CSV format
local result = log_search.export_logs(
  "logs/application.log",     -- Source log file
  "reports/logs.csv",         -- Output file
  "csv",                      -- Format: csv, json, html, text
  { source_format = "text" }  -- Options
)
-- Export logs to HTML for viewing in a browser
local result = log_search.export_logs(
  "logs/application.log",
  "reports/logs.html",
  "html",
  { source_format = "text" }
)
-- Export logs to JSON for further processing
local result = log_search.export_logs(
  "logs/application.log",
  "reports/logs.json",
  "json",
  { source_format = "text" }
)
```

### Real-Time Log Processing

```lua
-- Create a processor for real-time log filtering
local processor = log_search.get_log_processor({
  -- Output configuration
  output_file = "filtered_logs.json", -- Where to write filtered logs
  format = "json",                    -- Output format

  -- Filtering criteria
  level = "ERROR",                    -- Only process errors
  module = "database*",               -- Only process database modules
  message_pattern = "connection",     -- Only messages with "connection"

  -- Custom processing
  callback = function(log_entry)
    -- Do custom processing with each entry
    if log_entry.params and log_entry.params.host then
      -- Alert on specific hosts
      if log_entry.params.host == "production-db" then
        send_alert("Production database error", log_entry)
      end
    end
    return true -- Continue processing
  end
})
-- Process log entries as they come in
processor.process({
  timestamp = "2025-03-26 14:35:22",
  level = "ERROR",
  module = "database",
  message = "Connection failed",
  params = { host = "production-db" }
})
-- Close the processor when done
processor.close()
```

## Formatter Integration for Tests

The formatter integration module connects the logging system with firmo's test reporting system, providing test-aware logging capabilities.

### Enhancing Test Formatters

```lua
-- Import the formatter integration module
local formatter_integration = require("lib.tools.logging.formatter_integration")
-- Enhance all test formatters with logging capabilities
formatter_integration.enhance_formatters()
```

### Creating Test-Specific Loggers

```lua
-- Create a test-specific logger with context
local test_logger = formatter_integration.create_test_logger(
  "Calculator Test Suite",     -- Test name
  {                            -- Test context
    component = "calculator",
    test_type = "unit"
  }
)
-- Use the logger in your tests
describe("Calculator", function()
  -- Log test initialization with context
  test_logger.info("Initializing calculator test suite")

  it("should add two numbers correctly", function()
    -- Create a step-specific logger
    local step_logger = test_logger.step("Addition Test")

    -- Log test details
    step_logger.debug("Testing addition", {a = 2, b = 3, expected = 5})

    -- Run the test
    local result = calculator.add(2, 3)
    expect(result).to.equal(5)

    -- Log success
    step_logger.info("Addition test passed")
  end)

  it("should handle division by zero", { expect_error = true }, function()
    -- Create another step logger
    local step_logger = test_logger.step("Division By Zero")

    -- Log test details
    step_logger.debug("Testing division by zero", {a = 10, b = 0})

    -- Run the test (this will log an expected error)
    local result, err = calculator.divide(10, 0)

    -- Test assertions
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("division by zero")

    -- Log success
    step_logger.info("Division by zero test passed")
  end)
end)
```

The resulting logs include rich context information:

- `[INFO] [test.Calculator_Test_Suite] Initializing calculator test suite (component=calculator, test_type=unit)`
- `[DEBUG] [test.Calculator_Test_Suite] Testing addition (component=calculator, test_type=unit, step=Addition Test, a=2, b=3, expected=5)`
- `[INFO] [test.Calculator_Test_Suite] Addition test passed (component=calculator, test_type=unit, step=Addition Test)`

### Capturing and Attaching Logs to Test Results

```lua
-- Capture logs for a specific test
formatter_integration.capture_start(
  "Database Connection Test",   -- Test name
  "test_db_123"                 -- Unique test ID
)
-- Run your test (logs are captured)
local function run_database_test()
  local logger = logging.get_logger("database")
  logger.info("Connecting to database")

  -- Some test code...

  logger.error("Connection failed", {
    host = "test-db",
    error = "Connection refused"
  })
end
run_database_test()
-- End capture and get collected logs
local logs = formatter_integration.capture_end("test_db_123")
-- Display the captured logs
print("Captured " .. #logs .. " log entries:")
for _, log in ipairs(logs) do
  print(string.format("[%s] %s: %s",
    log.timestamp or "",
    log.level or "",
    log.message or ""))
end
-- Attach logs to test results
local test_results = {
  name = "Database Connection Test",
  status = "failed",
  error = "Connection to database failed"
}
local enhanced_results = formatter_integration.attach_logs_to_results(
  test_results,
  logs
)
-- Enhanced results now contain the logs:
-- {
--   name = "Database Connection Test",
--   status = "failed",
--   error = "Connection to database failed",
--   logs = { ... }  -- The captured logs
-- }
```

### Creating a Log-Friendly Formatter

```lua
-- Create a specialized formatter for log output
local log_formatter = formatter_integration.create_log_formatter()
-- Initialize with options
log_formatter:init({
  output_file = "test-logs.json",  -- Output file path
  format = "json"                  -- Output format (json or text)
})
-- Format test results with log information
local result = log_formatter:format(test_results)
```

### Integrating with the Reporting System

```lua
-- Integrate logging with the test reporting system
local reporting = formatter_integration.integrate_with_reporting({
  include_logs = true,            -- Include logs in reports
  include_debug = false,          -- Exclude DEBUG level logs
  max_logs_per_test = 50,         -- Limit logs per test
  attach_to_results = true        -- Automatically attach logs to results
})
```

## Component Interaction Examples

The following examples show how the different logging components can work together.

### Example 1: Comprehensive Test Logging and Export

```lua
-- Set up the components
local logging = require("lib.tools.logging")
local formatter_integration = require("lib.tools.logging.formatter_integration")
local log_export = require("lib.tools.logging.export")

-- Enhance test formatters
formatter_integration.enhance_formatters()
-- Create a test-specific logger
local test_logger = formatter_integration.create_test_logger(
  "API Integration Test",
  { component = "api", environment = "test" }
)
-- Run the test with structured logging
describe("API", function()
  local logs = {}

  before(function()
    -- Start log capture
    formatter_integration.capture_start("API Integration Test", "api_test_123")
    test_logger.info("Starting API integration test")
  end)

  it("should process requests correctly", function()
    local step_logger = test_logger.step("Request Processing")
    step_logger.info("Sending test request")

    -- Test code goes here...

    step_logger.info("Request processed successfully")
  end)

  after(function()
    test_logger.info("Completed API integration test")

    -- End capture and get the logs
    logs = formatter_integration.capture_end("api_test_123")

    -- Export the logs to Elasticsearch format
    local formatted_logs, err = log_export.export_to_platform(
      logs,
      "elasticsearch",
      {
        service_name = "api_tests",
        environment = "test"
      }
    )

    -- Save the formatted logs to a file
    local fs = require("lib.tools.filesystem")
    fs.write_file(
      "reports/api_test_logs.json",
      table.concat(formatted_logs, "\n")
    )
  end)
end)
```

### Example 2: Log Analysis Workflow

```lua
-- Set up the components
local log_search = require("lib.tools.logging.search")
local log_export = require("lib.tools.logging.export")
-- Load and analyze log data
local results = log_search.search_logs({
  log_file = "logs/application.log",
  level = "ERROR",
  from_date = os.date("%Y-%m-%d", os.time() - 86400), -- Last 24 hours
  to_date = os.date("%Y-%m-%d %H:%M:%S"),
  limit = 1000
})
-- Get statistics about error distribution
local stats = log_search.get_log_stats("logs/application.log")
-- Create an error report
local error_report = {
  timestamp = os.date(),
  total_errors = #results.entries,
  error_rate = (#results.entries / stats.total_entries) * 100,
  top_modules = {},
  entries = results.entries
}
-- Find top modules by error count
local module_counts = {}
for _, entry in ipairs(results.entries) do
  if entry.module then
    module_counts[entry.module] = (module_counts[entry.module] or 0) + 1
  end
end
local sorted_modules = {}
for module, count in pairs(module_counts) do
  table.insert(sorted_modules, {name = module, count = count})
end
table.sort(sorted_modules, function(a, b) return a.count > b.count end)
-- Add top 5 modules to the report
for i = 1, math.min(5, #sorted_modules) do
  table.insert(error_report.top_modules, sorted_modules[i])
end
-- Export the errors to HTML for human review
log_search.export_logs(
  "logs/application.log",
  "reports/errors.html",
  "html",
  {
    level = "ERROR",
    from_date = os.date("%Y-%m-%d", os.time() - 86400),
    to_date = os.date("%Y-%m-%d %H:%M:%S")
  }
)
-- Export to Splunk format for integration with monitoring system
log_export.create_platform_file(
  "logs/application.log",
  "splunk",
  "reports/splunk_errors.json",
  {
    source = "application",
    sourcetype = "app:error",
    environment = "production"
  }
)
```

## Best Practices

### General Logging Practices

1. **Use module-specific loggers**: Create a separate logger for each module

   ```lua
   local logger = logging.get_logger("module_name")
   ```

2. **Configure from central config**: Use the central configuration system

   ```lua
   logging.configure_from_config("module_name")
   ```

3. **Separate message from parameters**: Keep messages simple and put variable data in parameters

   ```lua
   -- Bad: Embedded data
   logger.info("Found " .. count .. " items in " .. category)

   -- Good: Separated data
   logger.info("Found items", {count = count, category = category})
   ```

4. **Include context in parameters**: Provide enough information for troubleshooting

   ```lua
   logger.error("Database connection failed", {
     host = db_host,
     port = db_port,
     retry_count = retries,
     error_code = err.code
   })
   ```

5. **Check level before expensive operations**:

   ```lua
   if logger.is_debug_enabled() then
     -- Expensive operations here
   end
   ```

### Using the Export Module

1. **Be consistent with platform options**: Use the same option names and values for all exports to ensure consistency
2. **Check for errors**: Always check for errors when using export functions

   ```lua
   local result, err = log_export.create_platform_file(...)
   if err then
     print("Export failed: " .. err)
   end
   ```

3. **Use platform-specific formats wisely**: Each platform has different field requirements - use the appropriate adapter
4. **For high-volume exports**, use buffering or paging to avoid memory issues

### Using the Search Module

1. **Use specific search criteria**: Narrower searches are more efficient

   ```lua
   -- More efficient:
   local results = log_search.search_logs({
     log_file = "logs/application.log",
     level = "ERROR",
     module = "database"
   })

   -- Less efficient:
   local results = log_search.search_logs({
     log_file = "logs/application.log"
   })
   ```

2. **Set reasonable limits**: Use the `limit` parameter to prevent loading too many entries into memory
3. **For large log files**, use the `format` option to specify the format explicitly rather than autodetect
4. **Export to HTML** for human review, **JSON** for machine processing, and **CSV** for spreadsheet analysis

### Using the Formatter Integration Module

1. **Create step-specific loggers** to provide better context in test logs
2. **Attach logs to results** to keep logs with their relevant test results
3. **Use context parameters consistently** across all tests
4. **For long-running tests**, periodically flush log buffers to ensure logs are not lost if the test crashes
5. **Create custom formatters** for specific reporting needs
