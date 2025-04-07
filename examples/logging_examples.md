# Logging Module Examples

This document provides practical examples for using firmo's logging system components. These examples demonstrate real-world usage patterns and can be used as templates for your own implementations.

## Table of Contents

1. [Core Logging Examples](#core-logging-examples)
2. [Export Module Examples](#export-module-examples)
3. [Search Module Examples](#search-module-examples)
4. [Formatter Integration Examples](#formatter-integration-examples)
5. [Complete Application Examples](#complete-application-examples)

## Core Logging Examples

### Basic Logger Setup and Usage

```lua
-- example_basic_logging.lua
local logging = require("lib.tools.logging")

-- Create a logger for your module
local logger = logging.get_logger("my_module")

-- Configure from central config (recommended)
logging.configure_from_config("my_module")

-- Basic logging at different levels
logger.info("Application starting")
logger.debug("Configuration loaded", {config_file = "config.lua"})

-- Logging with structured parameters
logger.info("User authenticated", {
  user_id = 12345,
  username = "john_doe",
  auth_method = "password",
  session_id = "sess-abcdef123456"
})

-- Warning with context
logger.warn("Resource approaching limit", {
  resource = "memory",
  current_usage = "85%",
  threshold = "90%"
})

-- Error with detailed information
logger.error("Failed to connect to external API", {
  api = "payment_gateway",
  url = "https://api.example.com/v2/payments",
  status_code = 503,
  response = "Service Unavailable",
  retry_count = 3
})
```

### Conditional Logging and Performance Optimization

```lua
-- example_conditional_logging.lua
local logging = require("lib.tools.logging")
local logger = logging.get_logger("performance")

-- Basic conditional logging
function process_data(data_items)
  logger.info("Processing data items", {count = #data_items})
  
  for i, item in ipairs(data_items) do
    -- Only log every 100 items to reduce log volume
    if i % 100 == 0 then
      logger.debug("Processing progress", {
        current = i,
        total = #data_items,
        percent_complete = (i / #data_items) * 100
      })
    end
    
    -- Process the item...
  end
  
  logger.info("Data processing complete", {count = #data_items})
end

-- Avoid expensive operations when logging is disabled
function analyze_performance(data)
  if logger.is_debug_enabled() then
    -- This is a potentially expensive operation
    local detailed_metrics = calculate_detailed_metrics(data)
    logger.debug("Performance metrics", detailed_metrics)
  end
  
  -- Continue with normal processing...
end

-- Example of a buffered logger for high-volume metrics
local metrics_logger = logging.create_buffered_logger("metrics", {
  buffer_size = 500,        -- Buffer up to 500 messages
  flush_interval = 10,      -- Flush every 10 seconds
  output_file = "metrics.log"
})

-- Function that generates many log entries
function collect_metrics(duration_seconds)
  local start_time = os.time()
  local count = 0
  
  logger.info("Starting metrics collection", {
    duration_seconds = duration_seconds
  })
  
  while os.time() - start_time < duration_seconds do
    -- Generate a metric
    local metric = {
      timestamp = os.time(),
      cpu_usage = math.random(10, 90),
      memory_mb = math.random(100, 500),
      active_connections = math.random(1, 100)
    }
    
    -- Log using the buffered logger (won't write immediately)
    metrics_logger.debug("System metric", metric)
    
    count = count + 1
    -- Sleep briefly
    os.execute("sleep 0.01")
  end
  
  -- Flush remaining metrics when done
  metrics_logger.flush()
  
  logger.info("Metrics collection complete", {
    count = count,
    duration_seconds = os.time() - start_time
  })
end
```

### Custom Configuration Example

```lua
-- example_custom_logging_config.lua
local logging = require("lib.tools.logging")

-- Set up custom configuration
logging.configure({
  -- Global default log level
  level = logging.LEVELS.INFO,
  
  -- Module-specific levels
  module_levels = {
    database = logging.LEVELS.DEBUG,
    network = logging.LEVELS.WARN,
    ui = logging.LEVELS.ERROR
  },
  
  -- Output configuration
  timestamps = true,
  use_colors = true,
  output_file = "application.log",
  log_dir = "logs",
  max_file_size = 5 * 1024 * 1024,  -- 5MB
  max_log_files = 10,
  
  -- JSON structured logging
  format = "text",              -- Console format
  json_file = "application.json", -- Separate JSON file
  
  -- Filtering
  module_filter = {"database", "network"},  -- Only show these modules
  module_blacklist = {"metrics"},  -- Don't show these modules
  
  -- Standard metadata added to all logs
  standard_metadata = {
    application = "example_app",
    version = "1.0.0",
    environment = "development",
    host = os.getenv("HOSTNAME") or "unknown"
  }
})

-- Create loggers for different modules
local db_logger = logging.get_logger("database")
local net_logger = logging.get_logger("network")
local ui_logger = logging.get_logger("ui")
local metrics_logger = logging.get_logger("metrics")

-- Log at different levels to demonstrate filtering
db_logger.debug("Database connection established")  -- Will show (DEBUG level enabled for database)
net_logger.debug("Network packet received")         -- Won't show (WARN level for network)
ui_logger.info("UI component initialized")          -- Won't show (ERROR level for ui)
metrics_logger.error("Metrics collection failed")   -- Won't show (in module_blacklist)

-- Add module to filter
logging.filter_module("ui")  -- Now ui logs will show if they meet level requirements

-- Remove from blacklist
logging.remove_from_blacklist("metrics")  -- Now metrics logs will show

-- Log again
ui_logger.error("UI error occurred")           -- Will show (ERROR level and in filter)
metrics_logger.error("Metrics error occurred") -- Will show (no longer blacklisted)
```

## Export Module Examples

### Basic Log Export

```lua
-- example_basic_export.lua
local log_export = require("lib.tools.logging.export")
local fs = require("lib.tools.filesystem")

-- Get list of supported platforms
local platforms = log_export.get_supported_platforms()
print("Supported platforms: " .. table.concat(platforms, ", "))

-- Create sample log entries
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
  {
    timestamp = "2025-03-26T14:32:50",
    level = "WARN",
    module = "authentication",
    message = "Failed login attempt",
    params = {
      username = "user123",
      ip_address = "192.168.1.1",
      attempt = 3
    }
  },
  {
    timestamp = "2025-03-26T14:33:00",
    level = "INFO",
    module = "application",
    message = "Application started",
    params = {
      version = "1.0.0",
      environment = "production"
    }
  }
}

-- Format logs for different platforms
local formats = {}

for _, platform in ipairs(platforms) do
  local formatted, err = log_export.export_to_platform(
    log_entries,
    platform,
    {
      service_name = "example_app",
      environment = "production"
    }
  )
  
  if formatted then
    formats[platform] = formatted
    
    -- Save to file for inspection
    local output_file = "export_" .. platform .. ".json"
    local content = "[\n"
    for i, entry in ipairs(formatted) do
      -- Convert table to JSON
      local json_str = "  " 
      if type(entry) == "table" then
        -- Very simple table to JSON conversion
        json_str = json_str .. "{"
        local first = true
        for k, v in pairs(entry) do
          if not first then json_str = json_str .. ", " end
          json_str = json_str .. '"' .. k .. '": '
          if type(v) == "string" then
            json_str = json_str .. '"' .. v:gsub('"', '\\"') .. '"'
          elseif type(v) == "table" then
            json_str = json_str .. '"[table]"'
          else
            json_str = json_str .. tostring(v)
          end
          first = false
        end
        json_str = json_str .. "}"
      else
        json_str = json_str .. tostring(entry)
      end
      
      if i < #formatted then
        json_str = json_str .. ","
      end
      content = content .. json_str .. "\n"
    end
    content = content .. "]\n"
    
    fs.write_file(output_file, content)
    print("Exported " .. platform .. " format to " .. output_file)
  else
    print("Failed to format for " .. platform .. ": " .. tostring(err))
  end
end
```

### Converting Log Files for External Systems

```lua
-- example_log_file_conversion.lua
local log_export = require("lib.tools.logging.export")
local fs = require("lib.tools.filesystem")

-- Create a sample log file
local sample_log = [[
2025-03-26 14:32:45 | ERROR | database | Connection failed (host=db.example.com, port=5432, error=Connection refused)
2025-03-26 14:32:50 | WARN | authentication | Failed login attempt (username=user123, ip_address=192.168.1.1, attempt=3)
2025-03-26 14:33:00 | INFO | application | Application started (version=1.0.0, environment=production)
2025-03-26 14:33:15 | DEBUG | request | Processing request (request_id=req-12345, path=/api/users, method=GET)
2025-03-26 14:33:20 | ERROR | payment | Transaction failed (transaction_id=tx-67890, amount=99.99, currency=USD, reason=insufficient_funds)
]]

-- Write sample log to a file
fs.ensure_directory_exists("logs")
fs.write_file("logs/sample.log", sample_log)

-- Convert the log file to different platform formats

-- Elasticsearch format
local es_result, es_err = log_export.create_platform_file(
  "logs/sample.log",
  "elasticsearch",
  "logs/elasticsearch_format.json",
  {
    service_name = "example_app",
    environment = "production"
  }
)

if es_result then
  print("Converted to Elasticsearch format:")
  print("  - Processed " .. es_result.entries_processed .. " entries")
  print("  - Output file: " .. es_result.output_file)
else
  print("Elasticsearch conversion failed: " .. tostring(es_err))
end

-- Splunk format
local splunk_result, splunk_err = log_export.create_platform_file(
  "logs/sample.log",
  "splunk",
  "logs/splunk_format.json",
  {
    source = "example_app",
    sourcetype = "app:logs",
    index = "main"
  }
)

if splunk_result then
  print("Converted to Splunk format:")
  print("  - Processed " .. splunk_result.entries_processed .. " entries")
  print("  - Output file: " .. splunk_result.output_file)
else
  print("Splunk conversion failed: " .. tostring(splunk_err))
end

-- Datadog format
local datadog_result, datadog_err = log_export.create_platform_file(
  "logs/sample.log",
  "datadog",
  "logs/datadog_format.json",
  {
    service = "example_app",
    environment = "production",
    tags = {"app:example", "version:1.0.0"}
  }
)

if datadog_result then
  print("Converted to Datadog format:")
  print("  - Processed " .. datadog_result.entries_processed .. " entries")
  print("  - Output file: " .. datadog_result.output_file)
else
  print("Datadog conversion failed: " .. tostring(datadog_err))
end
```

### Creating Platform Configuration Files

```lua
-- example_platform_config.lua
local log_export = require("lib.tools.logging.export")
local fs = require("lib.tools.filesystem")

-- Ensure the config directory exists
fs.ensure_directory_exists("config")

-- Create configuration files for different platforms

-- Elasticsearch configuration
local es_result, es_err = log_export.create_platform_config(
  "elasticsearch",
  "config/elasticsearch.json",
  {
    es_host = "logs.example.com:9200"
  }
)

if es_result then
  print("Created Elasticsearch configuration at " .. es_result.config_file)
else
  print("Failed to create Elasticsearch config: " .. tostring(es_err))
end

-- Logstash configuration
local ls_result, ls_err = log_export.create_platform_config(
  "logstash",
  "config/logstash.conf",
  {
    es_host = "elasticsearch:9200"
  }
)

if ls_result then
  print("Created Logstash configuration at " .. ls_result.config_file)
else
  print("Failed to create Logstash config: " .. tostring(ls_err))
end

-- Splunk configuration
local splunk_result, splunk_err = log_export.create_platform_config(
  "splunk",
  "config/splunk.conf",
  {}
)

if splunk_result then
  print("Created Splunk configuration at " .. splunk_result.config_file)
else
  print("Failed to create Splunk config: " .. tostring(splunk_err))
end

-- Datadog configuration  
local dd_result, dd_err = log_export.create_platform_config(
  "datadog",
  "config/datadog.yaml",
  {
    service = "example_app"
  }
)

if dd_result then
  print("Created Datadog configuration at " .. dd_result.config_file)
else
  print("Failed to create Datadog config: " .. tostring(dd_err))
end

-- Loki configuration
local loki_result, loki_err = log_export.create_platform_config(
  "loki",
  "config/loki.yaml",
  {}
)

if loki_result then
  print("Created Loki configuration at " .. loki_result.config_file)
else
  print("Failed to create Loki config: " .. tostring(loki_err))
end
```

### Real-Time Log Exporter Example

```lua
-- example_realtime_exporter.lua
local log_export = require("lib.tools.logging.export")
local logging = require("lib.tools.logging")

-- Create a real-time exporter for Datadog
local exporter, err = log_export.create_realtime_exporter(
  "datadog",
  {
    service = "example_app",
    environment = "development",
    hostname = "dev-server-1",
    tags = {"app:example", "version:1.0.0"}
  }
)

if not exporter then
  print("Failed to create exporter: " .. tostring(err))
  os.exit(1)
end

-- Print the HTTP endpoint details
print("Exporter configured with endpoint:")
print("  - Method: " .. exporter.http_endpoint.method)
print("  - URL: " .. exporter.http_endpoint.url)
for k, v in pairs(exporter.http_endpoint.headers or {}) do
  print("  - Header: " .. k .. " = " .. tostring(v))
end

-- Create a logger that sends to Datadog
local logger = logging.get_logger("datadog_example")

-- Function to simulate HTTP requests
local function simulate_request(path, method, duration_ms, status_code)
  -- Log the event
  local log_entry = {
    timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
    level = (status_code >= 400) and "ERROR" or "INFO",
    module = "api",
    message = "API " .. method .. " request to " .. path,
    params = {
      path = path,
      method = method,
      duration_ms = duration_ms,
      status_code = status_code
    }
  }
  
  -- Regular logging
  if status_code >= 400 then
    logger.error(log_entry.message, log_entry.params)
  else
    logger.info(log_entry.message, log_entry.params)
  end
  
  -- Export to Datadog
  local formatted = exporter.export(log_entry)
  
  -- In a real application, you would send this to Datadog
  -- Here we'll just print it
  print("\nFormatted for Datadog:")
  for k, v in pairs(formatted) do
    if type(v) == "table" then
      print("  " .. k .. " = [table]")
    else
      print("  " .. k .. " = " .. tostring(v))
    end
  end
end

-- Simulate a few API requests
local paths = {"/api/users", "/api/products", "/api/orders", "/api/nonexistent"}
local methods = {"GET", "POST", "PUT", "DELETE"}

for i = 1, 5 do
  local path = paths[math.random(1, #paths)]
  local method = methods[math.random(1, #methods)]
  local duration = math.random(10, 500)
  local status = (math.random() > 0.8) and math.random(400, 503) or math.random(200, 299)
  
  simulate_request(path, method, duration, status)
  
  -- Sleep briefly between requests
  os.execute("sleep 0.5")
end
```

## Search Module Examples

### Basic Log Search and Analysis

```lua
-- example_log_search.lua
local log_search = require("lib.tools.logging.search")
local fs = require("lib.tools.filesystem")

-- Create a sample log file
local sample_log = [[
2025-03-26 14:32:45 | ERROR | database | Connection failed (host=db.example.com, port=5432, error=Connection refused)
2025-03-26 14:32:50 | WARN | authentication | Failed login attempt (username=user123, ip_address=192.168.1.1, attempt=3)
2025-03-26 14:33:00 | INFO | application | Application started (version=1.0.0, environment=production)
2025-03-26 14:33:15 | DEBUG | request | Processing request (request_id=req-12345, path=/api/users, method=GET)
2025-03-26 14:33:20 | ERROR | payment | Transaction failed (transaction_id=tx-67890, amount=99.99, currency=USD, reason=insufficient_funds)
2025-03-26 14:33:30 | INFO | database | Connected to database (host=db.example.com, port=5432, database=app_db)
2025-03-26 14:33:45 | DEBUG | request | Processing request (request_id=req-12346, path=/api/products, method=GET)
2025-03-26 14:34:00 | ERROR | storage | File not found (path=/data/uploads/image.jpg)
2025-03-26 14:34:15 | WARN | authentication | Password expiring soon (username=user123, days_remaining=5)
2025-03-26 14:34:30 | INFO | application | User logged out (username=user123, session_id=sess-abcdef)
]]

-- Write sample log to a file
fs.ensure_directory_exists("logs")
fs.write_file("logs/sample.log", sample_log)

-- Search the log file
print("Searching for ERROR logs...")
local errors = log_search.search_logs({
  log_file = "logs/sample.log",
  level = "ERROR"
})

print("Found " .. errors.count .. " ERROR logs:")
for i, entry in ipairs(errors.entries) do
  print(string.format("%d) [%s] %s: %s", 
    i,
    entry.timestamp or "",
    entry.module or "",
    entry.message or ""))
end

-- Search with module filter
print("\nSearching for database logs...")
local db_logs = log_search.search_logs({
  log_file = "logs/sample.log",
  module = "database"
})

print("Found " .. db_logs.count .. " database logs:")
for i, entry in ipairs(db_logs.entries) do
  print(string.format("%d) [%s] %s: %s", 
    i,
    entry.timestamp or "",
    entry.level or "",
    entry.message or ""))
end

-- Search with message pattern
print("\nSearching for logs containing 'failed'...")
local failed_logs = log_search.search_logs({
  log_file = "logs/sample.log",
  message_pattern = "failed"
})

print("Found " .. failed_logs.count .. " logs with 'failed':")
for i, entry in ipairs(failed_logs.entries) do
  print(string.format("%d) [%s] %s | %s: %s", 
    i,
    entry.timestamp or "",
    entry.level or "",
    entry.module or "",
    entry.message or ""))
end

-- Get statistics about the log file
print("\nLog file statistics:")
local stats = log_search.get_log_stats("logs/sample.log")

print("Total entries: " .. stats.total_entries)
print("First timestamp: " .. (stats.first_timestamp or "N/A"))
print("Last timestamp: " .. (stats.last_timestamp or "N/A"))

print("\nDistribution by level:")
for level, count in pairs(stats.by_level or {}) do
  local percentage = (count / stats.total_entries) * 100
  print(string.format("  %s: %d entries (%.1f%%)", level, count, percentage))
end

print("\nDistribution by module:")
for module, count in pairs(stats.by_module or {}) do
  local percentage = (count / stats.total_entries) * 100
  print(string.format("  %s: %d entries (%.1f%%)", module, count, percentage))
end
```

### Log Export to Different Formats

```lua
-- example_log_export_formats.lua
local log_search = require("lib.tools.logging.search")
local fs = require("lib.tools.filesystem")

-- Create a sample log file if it doesn't exist
if not fs.file_exists("logs/sample.log") then
  local sample_log = [[
2025-03-26 14:32:45 | ERROR | database | Connection failed (host=db.example.com, port=5432, error=Connection refused)
2025-03-26 14:32:50 | WARN | authentication | Failed login attempt (username=user123, ip_address=192.168.1.1, attempt=3)
2025-03-26 14:33:00 | INFO | application | Application started (version=1.0.0, environment=production)
2025-03-26 14:33:15 | DEBUG | request | Processing request (request_id=req-12345, path=/api/users, method=GET)
2025-03-26 14:33:20 | ERROR | payment | Transaction failed (transaction_id=tx-67890, amount=99.99, currency=USD, reason=insufficient_funds)
]]
  fs.ensure_directory_exists("logs")
  fs.write_file("logs/sample.log", sample_log)
end

-- Ensure reports directory exists
fs.ensure_directory_exists("reports")

-- Export to CSV format
local csv_result = log_search.export_logs(
  "logs/sample.log",
  "reports/logs.csv",
  "csv"
)

if csv_result then
  print("Exported to CSV format:")
  print("  - Processed " .. csv_result.entries_processed .. " entries")
  print("  - Output file: " .. csv_result.output_file)
else
  print("CSV export failed")
end

-- Export to JSON format
local json_result = log_search.export_logs(
  "logs/sample.log",
  "reports/logs.json",
  "json"
)

if json_result then
  print("Exported to JSON format:")
  print("  - Processed " .. json_result.entries_processed .. " entries")
  print("  - Output file: " .. json_result.output_file)
else
  print("JSON export failed")
end

-- Export to HTML format
local html_result = log_search.export_logs(
  "logs/sample.log",
  "reports/logs.html",
  "html"
)

if html_result then
  print("Exported to HTML format:")
  print("  - Processed " .. html_result.entries_processed .. " entries")
  print("  - Output file: " .. html_result.output_file)
else
  print("HTML export failed")
end

-- Export ERROR logs only to HTML
local error_html_result = log_search.export_logs(
  "logs/sample.log",
  "reports/error_logs.html",
  "html",
  {
    level = "ERROR"
  }
)

if error_html_result then
  print("Exported ERROR logs to HTML format:")
  print("  - Processed " .. error_html_result.entries_processed .. " entries")
  print("  - Output file: " .. error_html_result.output_file)
else
  print("ERROR HTML export failed")
end
```

### Real-Time Log Processor

```lua
-- example_realtime_log_processor.lua
local log_search = require("lib.tools.logging.search")
local fs = require("lib.tools.filesystem")

-- Ensure the output directory exists
fs.ensure_directory_exists("processed_logs")

-- Create a log processor for real-time filtering
local processor = log_search.get_log_processor({
  -- Output configuration
  output_file = "processed_logs/filtered.json",
  format = "json",
  
  -- Custom callback for each log entry
  callback = function(log_entry)
    -- Print each processed entry
    print(string.format("[%s] %s | %s: %s",
      log_entry.timestamp or "",
      log_entry.level or "",
      log_entry.module or "",
      log_entry.message or ""))
    
    -- Continue processing
    return true
  end
})

-- Sample log entries to process
local logs = {
  {
    timestamp = "2025-03-26 14:32:45",
    level = "ERROR",
    module = "database",
    message = "Connection failed",
    params = {
      host = "db.example.com",
      port = 5432,
      error = "Connection refused"
    }
  },
  {
    timestamp = "2025-03-26 14:32:50",
    level = "WARN",
    module = "authentication",
    message = "Failed login attempt",
    params = {
      username = "user123",
      ip_address = "192.168.1.1",
      attempt = 3
    }
  },
  {
    timestamp = "2025-03-26 14:33:00",
    level = "INFO",
    module = "application",
    message = "Application started",
    params = {
      version = "1.0.0",
      environment = "production"
    }
  }
}

-- Process each log entry
print("Processing log entries...")
for i, log_entry in ipairs(logs) do
  print("\nProcessing entry #" .. i)
  local processed = processor.process(log_entry)
  if processed then
    print("  ✓ Entry processed successfully")
  else
    print("  ✗ Entry did not meet filter criteria")
  end
end

-- Close the processor
processor.close()
print("\nProcessor closed. Output written to: processed_logs/filtered.json")
```

### Creating Export Adapters

```lua
-- example_export_adapters.lua
local log_search = require("lib.tools.logging.search")

-- Create an example log entry
local log_entry = {
  timestamp = "2025-03-26 14:32:45",
  level = "ERROR",
  module = "database",
  message = "Connection failed",
  params = {
    host = "db.example.com",
    port = 5432,
    error = "Connection refused"
  }
}

-- Create adapters for different platforms
local adapters = {}
local platforms = {"logstash", "elk", "splunk", "datadog"}

for _, platform in ipairs(platforms) do
  print("\nCreating adapter for " .. platform .. "...")
  
  local adapter, err = log_search.create_export_adapter(
    platform,
    {
      application_name = "example_app",
      service_name = "example_service",
      environment = "production",
      host = "example-host",
      tags = {"app:example", "env:prod"}
    }
  )
  
  if adapter then
    adapters[platform] = adapter
    print("Adapter created successfully")
  else
    print("Failed to create adapter: " .. tostring(err))
  end
end

-- Format the log entry using each adapter
for platform, adapter in pairs(adapters) do
  print("\nFormatting log entry for " .. platform .. ":")
  
  local formatted = adapter(log_entry)
  
  -- Print the formatted entry
  for k, v in pairs(formatted) do
    if type(v) == "table" then
      print("  " .. k .. " = [table]")
    else
      print("  " .. k .. " = " .. tostring(v))
    end
  end
end
```

## Formatter Integration Examples

### Test-Specific Logger Example

```lua
-- example_test_specific_logger.lua
local formatter_integration = require("lib.tools.logging.formatter_integration")
local logging = require("lib.tools.logging")

-- Configure logging
logging.configure({
  level = logging.LEVELS.DEBUG,
  use_colors = true,
  timestamps = true
})

-- Create a test-specific logger
local test_logger = formatter_integration.create_test_logger(
  "Calculator Test Suite",
  {
    component = "calculator",
    test_type = "unit"
  }
)

-- Simulate a test run
print("Running Calculator Test Suite...")

-- Log test initialization
test_logger.info("Initializing calculator test suite")

-- Test cases
local test_cases = {
  {
    name = "Addition Test",
    a = 2,
    b = 3,
    expected = 5,
    operation = "add"
  },
  {
    name = "Subtraction Test",
    a = 10,
    b = 4,
    expected = 6,
    operation = "subtract"
  },
  {
    name = "Multiplication Test",
    a = 5,
    b = 6,
    expected = 30,
    operation = "multiply"
  },
  {
    name = "Division Test",
    a = 20,
    b = 5,
    expected = 4,
    operation = "divide"
  },
  {
    name = "Division by Zero Test",
    a = 10,
    b = 0,
    expected_error = true,
    operation = "divide"
  }
}

-- Run each test case
for _, test_case in ipairs(test_cases) do
  -- Create a step-specific logger
  local step_logger = test_logger.step(test_case.name)
  
  -- Log test details
  step_logger.debug("Running test case", {
    a = test_case.a,
    b = test_case.b,
    expected = test_case.expected,
    operation = test_case.operation
  })
  
  -- Simulate test execution
  local result, err
  
  -- Simulate the calculator operation
  if test_case.operation == "add" then
    result = test_case.a + test_case.b
  elseif test_case.operation == "subtract" then
    result = test_case.a - test_case.b
  elseif test_case.operation == "multiply" then
    result = test_case.a * test_case.b
  elseif test_case.operation == "divide" then
    if test_case.b == 0 then
      err = "Division by zero"
    else
      result = test_case.a / test_case.b
    end
  end
  
  -- Check the result
  if test_case.expected_error then
    if err then
      step_logger.info("Test passed: expected error occurred", {
        error = err
      })
    else
      step_logger.error("Test failed: expected error but got result", {
        result = result
      })
    end
  else
    if err then
      step_logger.error("Test failed with error", {
        error = err
      })
    elseif result == test_case.expected then
      step_logger.info("Test passed", {
        actual = result,
        expected = test_case.expected
      })
    else
      step_logger.error("Test failed: incorrect result", {
        actual = result,
        expected = test_case.expected
      })
    end
  end
end

-- Log test completion
test_logger.info("Calculator test suite completed")
```

### Log Capture and Attachment Example

```lua
-- example_log_capture.lua
local formatter_integration = require("lib.tools.logging.formatter_integration")
local logging = require("lib.tools.logging")

-- Configure logging
logging.configure({
  level = logging.LEVELS.DEBUG,
  use_colors = true,
  timestamps = true
})

-- Create test logger
local logger = logging.get_logger("database_test")

-- Start capturing logs
print("Starting log capture...")
formatter_integration.capture_start(
  "Database Connection Test",
  "db_test_123"
)

-- Simulate a test that generates logs
print("Running database connection test...")

-- Log various messages during the test
logger.info("Initializing database connection test")
logger.debug("Connecting to database", {
  host = "test-db",
  port = 5432,
  database = "test_db",
  username = "test_user"
})

-- Simulate a failed connection
logger.error("Database connection failed", {
  host = "test-db",
  error = "Connection refused"
})

-- Simulate a retry
logger.warn("Retrying database connection", {
  attempt = 2,
  max_attempts = 3
})

-- Simulate success on second try
logger.debug("Connecting to database", {
  host = "test-db",
  port = 5432,
  database = "test_db",
  username = "test_user"
})

logger.info("Database connection established")

-- Simulate test actions
logger.debug("Running test queries")
logger.info("Test queries completed successfully")

-- Simulate test completion
logger.info("Database connection test completed")

-- End capture and get the logs
print("\nEnding log capture...")
local logs = formatter_integration.capture_end("db_test_123")

-- Create test results
local test_results = {
  name = "Database Connection Test",
  status = "passed",
  duration = 123,
  assertions = 5,
  file = "tests/database_test.lua"
}

-- Attach logs to test results
local enhanced_results = formatter_integration.attach_logs_to_results(
  test_results,
  logs
)

-- Display the captured logs
print("\nCaptured " .. #logs .. " log entries:")
for i, log in ipairs(logs) do
  print(string.format("%d) [%s] %s: %s", 
    i,
    log.timestamp or "",
    log.level or "",
    log.message or ""))
end

-- Display the enhanced test results
print("\nEnhanced test results with attached logs:")
print("  - Name: " .. enhanced_results.name)
print("  - Status: " .. enhanced_results.status)
print("  - Duration: " .. enhanced_results.duration .. "ms")
print("  - Assertions: " .. enhanced_results.assertions)
print("  - File: " .. enhanced_results.file)
print("  - Logs: " .. #enhanced_results.logs .. " entries")
```

### Test Formatter Integration Example

```lua
-- example_formatter_integration.lua
local formatter_integration = require("lib.tools.logging.formatter_integration")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

-- Initialize
logging.configure({
  level = logging.LEVELS.DEBUG,
  use_colors = true,
  timestamps = true
})

-- Enhance formatters with logging capabilities
formatter_integration.enhance_formatters()

-- Create a log-friendly formatter
local log_formatter = formatter_integration.create_log_formatter()

-- Initialize the formatter
log_formatter:init({
  output_file = "reports/test_logs.json",
  format = "json"
})

-- Simulate test results
local test_results = {
  name = "Calculator Test Suite",
  total = 5,
  passed = 4,
  failed = 1,
  pending = 0,
  success_percent = 80,
  duration = 123,
  tests = {
    {
      name = "Addition Test",
      status = "passed",
      duration = 15,
      file = "tests/calculator_test.lua",
      tags = {"unit", "math"}
    },
    {
      name = "Subtraction Test",
      status = "passed",
      duration = 12,
      file = "tests/calculator_test.lua",
      tags = {"unit", "math"}
    },
    {
      name = "Multiplication Test",
      status = "passed",
      duration = 11,
      file = "tests/calculator_test.lua",
      tags = {"unit", "math"}
    },
    {
      name = "Division Test",
      status = "passed",
      duration = 10,
      file = "tests/calculator_test.lua",
      tags = {"unit", "math"}
    },
    {
      name = "Division by Zero Test",
      status = "failed",
      duration = 75,
      file = "tests/calculator_test.lua",
      error = "Expected error but got result 5",
      tags = {"unit", "math", "error"}
    }
  }
}

-- Generate logs for each test
for _, test in ipairs(test_results.tests) do
  -- Start log capture
  formatter_integration.capture_start(
    test.name,
    "test_" .. test.name:gsub("%s+", "_")
  )
  
  -- Create a test logger
  local test_logger = formatter_integration.create_test_logger(
    test.name,
    {
      file = test.file,
      tags = table.concat(test.tags, ", ")
    }
  )
  
  -- Log test execution
  test_logger.info("Starting test " .. test.name)
  
  -- Add some sample logs
  if test.status == "passed" then
    test_logger.debug("Executing test case")
    test_logger.info("Test assertions passed")
    test_logger.info("Test completed successfully")
  else
    test_logger.debug("Executing test case")
    test_logger.warn("Test condition not met")
    test_logger.error("Test failed", {
      error = test.error
    })
  end
  
  -- End log capture
  local logs = formatter_integration.capture_end(
    "test_" .. test.name:gsub("%s+", "_")
  )
  
  -- Attach logs to the test results
  test.logs = logs
end

-- Format the test results with the log formatter
print("Formatting test results...")
fs.ensure_directory_exists("reports")
local result = log_formatter:format(test_results)

if result then
  print("Test results formatted successfully")
  print("Output file: " .. result.output_file)
else
  print("Failed to format test results")
end

-- Integrate with the reporting system
print("\nIntegrating with reporting system...")
local reporting = formatter_integration.integrate_with_reporting({
  include_logs = true,
  include_debug = false,
  max_logs_per_test = 10,
  attach_to_results = true
})

if reporting then
  print("Successfully integrated with reporting system")
else
  print("Failed to integrate with reporting system")
end
```

## Complete Application Examples

### Comprehensive Logging System Example

```lua
-- example_comprehensive_logging.lua

-- Load all the logging system components
local logging = require("lib.tools.logging")
local log_export = require("lib.tools.logging.export")
local log_search = require("lib.tools.logging.search")
local formatter_integration = require("lib.tools.logging.formatter_integration")
local fs = require("lib.tools.filesystem")

-- Ensure directories exist
fs.ensure_directory_exists("logs")
fs.ensure_directory_exists("reports")
fs.ensure_directory_exists("config")

-- Configure the logging system
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "logs/application.log",
  json_file = "logs/application.json",
  log_dir = "logs",
  max_file_size = 1024 * 1024,  -- 1MB
  max_log_files = 5,
  standard_metadata = {
    application = "example_app",
    version = "1.0.0",
    environment = "development"
  }
})

-- Create loggers for different modules
local app_logger = logging.get_logger("application")
local db_logger = logging.get_logger("database")
local auth_logger = logging.get_logger("authentication")
local api_logger = logging.get_logger("api")

-- Simulate application startup
app_logger.info("Application starting")

-- Simulate database connection
db_logger.debug("Connecting to database", {
  host = "localhost",
  port = 5432,
  database = "example_db"
})

-- Simulate a database error
db_logger.error("Database connection failed", {
  host = "localhost",
  error = "Connection refused"
})

-- Simulate retry
db_logger.warn("Retrying database connection", {
  attempt = 2,
  max_attempts = 3
})

-- Simulate successful connection
db_logger.info("Database connection established")

-- Simulate user authentication
auth_logger.debug("Authenticating user", {
  username = "john_doe",
  method = "password"
})

auth_logger.info("User authenticated successfully", {
  username = "john_doe",
  user_id = 12345
})

-- Simulate API requests
for i = 1, 5 do
  local request_id = "req-" .. i
  local paths = {"/api/users", "/api/products", "/api/orders"}
  local methods = {"GET", "POST", "PUT"}
  
  local path = paths[math.random(1, #paths)]
  local method = methods[math.random(1, #methods)]
  
  api_logger.info("Received API request", {
    request_id = request_id,
    path = path,
    method = method
  })
  
  api_logger.debug("Processing request", {
    request_id = request_id,
    parameters = {
      id = math.random(1, 1000),
      limit = math.random(10, 50)
    }
  })
  
  -- Randomly simulate errors
  if math.random() < 0.2 then
    api_logger.error("Request processing failed", {
      request_id = request_id,
      error = "Internal server error",
      code = 500
    })
  else
    api_logger.info("Request processed successfully", {
      request_id = request_id,
      response_time_ms = math.random(10, 500)
    })
  end
end

-- Simulate application shutdown
app_logger.info("Application shutting down")

-- Now demonstrate the various capabilities of the logging system

-- 1. Search the logs
print("\n=== Log Search ===")
local error_logs = log_search.search_logs({
  log_file = "logs/application.log",
  level = "ERROR"
})

print("Found " .. error_logs.count .. " ERROR logs")

-- 2. Get log statistics
print("\n=== Log Statistics ===")
local stats = log_search.get_log_stats("logs/application.log")

print("Log statistics:")
print("  - Total entries: " .. stats.total_entries)
print("  - Errors: " .. stats.errors)
print("  - Warnings: " .. stats.warnings)

-- 3. Export logs to different formats
print("\n=== Log Export ===")

-- Export to HTML
log_search.export_logs(
  "logs/application.log",
  "reports/logs.html",
  "html"
)

print("Exported logs to HTML: reports/logs.html")

-- Export to Elasticsearch format
local es_result = log_export.create_platform_file(
  "logs/application.log",
  "elasticsearch",
  "reports/elasticsearch_logs.json",
  {
    service_name = "example_app",
    environment = "development"
  }
)

print("Exported logs to Elasticsearch format: " .. es_result.output_file)

-- 4. Create platform configuration
print("\n=== Platform Configuration ===")
log_export.create_platform_config(
  "logstash",
  "config/logstash.conf",
  {
    es_host = "localhost:9200"
  }
)

print("Created Logstash configuration: config/logstash.conf")

-- 5. Test formatter integration
print("\n=== Test Formatter Integration ===")

-- Create a test-specific logger
local test_logger = formatter_integration.create_test_logger(
  "Integration Test",
  {
    component = "api",
    test_type = "integration"
  }
)

-- Start log capture
formatter_integration.capture_start(
  "Integration Test",
  "test_123"
)

-- Log test execution
test_logger.info("Starting integration test")
test_logger.debug("Testing API endpoints")
test_logger.info("Test completed successfully")

-- End capture
local logs = formatter_integration.capture_end("test_123")

print("Captured " .. #logs .. " log entries from the test")

-- Create a log formatter
local log_formatter = formatter_integration.create_log_formatter()
log_formatter:init({
  output_file = "reports/test_logs.json",
  format = "json"
})

-- Simulate test results
local test_results = {
  name = "API Integration Tests",
  total = 3,
  passed = 3,
  failed = 0,
  pending = 0,
  success_percent = 100,
  duration = 234,
  tests = {
    {
      name = "Integration Test",
      status = "passed",
      duration = 123,
      file = "tests/api_test.lua",
      logs = logs
    }
  }
}

-- Format test results
log_formatter:format(test_results)

print("Formatted test results with logs: reports/test_logs.json")

print("\n=== Comprehensive Logging Example Complete ===")
```

### Real-World API Service with Logging

```lua
-- example_api_service.lua

-- Load the logging components
local logging = require("lib.tools.logging")
local log_export = require("lib.tools.logging.export")
local fs = require("lib.tools.filesystem")

-- Ensure logs directory exists
fs.ensure_directory_exists("logs")

-- Configure logging
logging.configure({
  level = logging.LEVELS.INFO,
  timestamps = true,
  use_colors = true,
  output_file = "logs/api.log",
  json_file = "logs/api.json",
  log_dir = "logs",
  max_file_size = 5 * 1024 * 1024,  -- 5MB
  standard_metadata = {
    service = "api_service",
    version = "1.0.0",
    environment = "production"
  }
})

-- Create a datadog exporter for real-time monitoring
local exporter, exporter_err = log_export.create_realtime_exporter(
  "datadog",
  {
    service = "api_service",
    environment = "production",
    tags = {"service:api", "version:1.0.0"}
  }
)

if exporter_err then
  print("Warning: Failed to create monitoring exporter: " .. tostring(exporter_err))
end

-- Create module loggers
local app_logger = logging.get_logger("app")
local auth_logger = logging.get_logger("auth")
local db_logger = logging.get_logger("database")
local cache_logger = logging.get_logger("cache")
local api_logger = logging.get_logger("api")

-- Set debug level for database operations
logging.set_module_level("database", logging.LEVELS.DEBUG)

-- Simulate API server application

-- Database connection pool
local db_pool = {
  connections = {},
  max_connections = 10,
  active_connections = 0
}

-- Cache storage
local cache = {
  items = {},
  hits = 0,
  misses = 0
}

-- Authenticated users
local authenticated_users = {}

-- Function to simulate database connection
local function db_connect()
  db_logger.debug("Opening database connection")
  
  if db_pool.active_connections >= db_pool.max_connections then
    db_logger.warn("Connection pool limit reached", {
      active = db_pool.active_connections,
      max = db_pool.max_connections
    })
    return nil, "Connection pool limit reached"
  end
  
  -- Simulate occasional connection failure
  if math.random() < 0.1 then
    db_logger.error("Database connection failed", {
      host = "db.example.com",
      port = 5432,
      error = "Connection timed out"
    })
    return nil, "Connection timed out"
  end
  
  -- Create a new connection
  local conn_id = "conn-" .. math.random(1000, 9999)
  db_pool.connections[conn_id] = {
    id = conn_id,
    created_at = os.time()
  }
  db_pool.active_connections = db_pool.active_connections + 1
  
  db_logger.info("Database connection established", {
    connection_id = conn_id,
    pool_size = db_pool.active_connections
  })
  
  return conn_id
end

-- Function to simulate database query
local function db_query(conn_id, query, params)
  db_logger.debug("Executing database query", {
    connection_id = conn_id,
    query = query,
    params = params
  })
  
  if not db_pool.connections[conn_id] then
    db_logger.error("Invalid database connection", {
      connection_id = conn_id
    })
    return nil, "Invalid connection"
  end
  
  -- Simulate query execution time
  local execution_time = math.random(5, 100)
  
  -- Log slow queries
  if execution_time > 50 then
    db_logger.warn("Slow database query", {
      connection_id = conn_id,
      execution_time_ms = execution_time,
      query = query
    })
  end
  
  -- Simulate occasional query failure
  if math.random() < 0.05 then
    db_logger.error("Database query failed", {
      connection_id = conn_id,
      query = query,
      error = "Syntax error in SQL"
    })
    return nil, "Query failed: Syntax error in SQL"
  end
  
  -- Return simulated data
  return {
    rows = math.random(1, 100),
    execution_time_ms = execution_time
  }
end

-- Function to simulate cache operations
local function cache_get(key)
  cache_logger.debug("Cache lookup", {key = key})
  
  if cache.items[key] then
    if cache.items[key].expires_at < os.time() then
      -- Cache item expired
      cache_logger.debug("Cache item expired", {key = key})
      cache.items[key] = nil
      cache.misses = cache.misses + 1
      return nil
    end
    
    -- Cache hit
    cache.hits = cache.hits + 1
    cache_logger.debug("Cache hit", {
      key = key,
      hits = cache.hits,
      misses = cache.misses,
      hit_ratio = cache.hits / (cache.hits + cache.misses)
    })
    return cache.items[key].value
  end
  
  -- Cache miss
  cache.misses = cache.misses + 1
  cache_logger.debug("Cache miss", {
    key = key,
    hits = cache.hits,
    misses = cache.misses,
    hit_ratio = cache.hits / (cache.hits + cache.misses)
  })
  return nil
end

-- Function to set cache
local function cache_set(key, value, ttl)
  cache_logger.debug("Cache set", {
    key = key,
    ttl = ttl
  })
  
  cache.items[key] = {
    value = value,
    created_at = os.time(),
    expires_at = os.time() + (ttl or 300)
  }
  
  -- Log cache size periodically
  if math.random() < 0.1 then
    local cache_size = 0
    for _ in pairs(cache.items) do cache_size = cache_size + 1 end
    
    cache_logger.info("Cache status", {
      items = cache_size,
      hits = cache.hits,
      misses = cache.misses,
      hit_ratio = cache.hits / (cache.hits + cache.misses)
    })
  end
end

-- Function to authenticate a user
local function authenticate(username, password)
  auth_logger.info("Authentication attempt", {
    username = username,
    method = "password"
  })
  
  -- Simulate authentication process
  if username == "test" and password == "password" then
    local session_id = "sess-" .. math.random(1000, 9999)
    authenticated_users[session_id] = {
      username = username,
      authenticated_at = os.time(),
      expires_at = os.time() + 3600
    }
    
    auth_logger.info("Authentication successful", {
      username = username,
      session_id = session_id
    })
    
    return session_id
  end
  
  -- Authentication failed
  auth_logger.warn("Authentication failed", {
    username = username,
    reason = "Invalid credentials"
  })
  
  return nil, "Invalid credentials"
end

-- Function to verify a session
local function verify_session(session_id)
  auth_logger.debug("Verifying session", {
    session_id = session_id
  })
  
  if not authenticated_users[session_id] then
    auth_logger.warn("Invalid session", {
      session_id = session_id
    })
    return false
  end
  
  if authenticated_users[session_id].expires_at < os.time() then
    auth_logger.warn("Expired session", {
      session_id = session_id,
      username = authenticated_users[session_id].username
    })
    authenticated_users[session_id] = nil
    return false
  end
  
  return true
end

-- API request handler
local function handle_request(request)
  local request_id = "req-" .. math.random(1000, 9999)
  
  api_logger.info("Received API request", {
    request_id = request_id,
    path = request.path,
    method = request.method,
    client_ip = request.ip
  })
  
  -- Check if authentication is required
  if request.path ~= "/api/login" then
    if not request.session_id or not verify_session(request.session_id) then
      api_logger.warn("Unauthorized request", {
        request_id = request_id,
        path = request.path,
        method = request.method
      })
      
      return {
        status = 401,
        body = {
          error = "Unauthorized",
          message = "Please login first"
        }
      }
    end
  end
  
  -- Check if we have a cached response
  local cache_key = request.method .. ":" .. request.path
  local cached_response = cache_get(cache_key)
  
  if cached_response then
    api_logger.info("Serving cached response", {
      request_id = request_id,
      cache_key = cache_key
    })
    
    return cached_response
  }
  
  -- Handle different API endpoints
  if request.path == "/api/login" then
    -- Login endpoint
    if request.method ~= "POST" then
      api_logger.warn("Method not allowed", {
        request_id = request_id,
        path = request.path,
        method = request.method,
        allowed = "POST"
      })
      
      return {
        status = 405,
        body = {
          error = "Method not allowed",
          message = "This endpoint only supports POST"
        }
      }
    }
    
    -- Authenticate user
    local session_id, auth_error = authenticate(
      request.body.username,
      request.body.password
    )
    
    if auth_error then
      return {
        status = 401,
        body = {
          error = "Authentication failed",
          message = auth_error
        }
      }
    }
    
    return {
      status = 200,
      body = {
        session_id = session_id,
        message = "Login successful"
      }
    }
  elseif request.path == "/api/users" then
    -- Users endpoint
    
    -- Connect to database
    local conn_id, conn_error = db_connect()
    
    if conn_error then
      api_logger.error("Database connection failed for request", {
        request_id = request_id,
        error = conn_error
      })
      
      return {
        status = 500,
        body = {
          error = "Database error",
          message = "Could not connect to database"
        }
      }
    }
    
    -- Execute query
    local result, query_error = db_query(
      conn_id,
      "SELECT * FROM users LIMIT 10",
      {}
    )
    
    if query_error then
      api_logger.error("Database query failed for request", {
        request_id = request_id,
        error = query_error
      })
      
      return {
        status = 500,
        body = {
          error = "Database error",
          message = "Could not retrieve users"
        }
      }
    }
    
    -- Create response
    local response = {
      status = 200,
      body = {
        users = {
          {id = 1, username = "user1", email = "user1@example.com"},
          {id = 2, username = "user2", email = "user2@example.com"},
        },
        count = result.rows
      }
    }
    
    -- Cache the response
    cache_set(cache_key, response, 60)
    
    return response
  else
    -- Unknown endpoint
    api_logger.warn("Unknown API endpoint", {
      request_id = request_id,
      path = request.path
    })
    
    return {
      status = 404,
      body = {
        error = "Not found",
        message = "The requested endpoint does not exist"
      }
    }
  end
end

-- Simulate API traffic
app_logger.info("API service starting")

-- Handle some example requests
local requests = {
  {
    path = "/api/login",
    method = "POST",
    ip = "192.168.1.1",
    body = {
      username = "test",
      password = "password"
    }
  },
  {
    path = "/api/users",
    method = "GET",
    ip = "192.168.1.1",
    session_id = nil  -- Will be set after login
  },
  {
    path = "/api/unknown",
    method = "GET",
    ip = "192.168.1.2",
    session_id = "invalid-session"
  }
}

-- Handle the requests
for i, request in ipairs(requests) do
  local response = handle_request(request)
  
  api_logger.info("API response sent", {
    request_path = request.path,
    status = response.status
  })
  
  -- Set session ID for subsequent requests if this was a login
  if request.path == "/api/login" and response.status == 200 then
    requests[2].session_id = response.body.session_id
  end
  
  -- Export metrics to monitoring system if available
  if exporter then
    local log_entry = {
      timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
      level = response.status >= 400 and "ERROR" or "INFO",
      module = "api",
      message = "API Request",
      params = {
        path = request.path,
        method = request.method,
        status = response.status,
        response_time_ms = math.random(5, 100)
      }
    }
    
    exporter.export(log_entry)
  end
end

-- Simulate the same requests again to demonstrate caching
for _, request in ipairs(requests) do
  if request.path ~= "/api/login" then
    local response = handle_request(request)
    
    api_logger.info("API response sent", {
      request_path = request.path,
      status = response.status
    })
  end
end

app_logger.info("API service example completed")
```

These examples demonstrate how to use the various components of the firmo logging system in different scenarios, from basic logging to complex real-world applications.