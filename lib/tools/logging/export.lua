--- Log Export Module for Firmo
---
--- This module provides adapters and functions to format and export log entries
--- to various external log analysis platforms like Logstash, Elasticsearch, Splunk, etc.
---
--- @module lib.tools.logging.export
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

--- @class LogEntry Expected structure for individual log entries.
--- @field timestamp string ISO 8601 timestamp.
--- @field level string Log level (e.g., "INFO", "ERROR").
--- @field module string Name of the originating module.
--- @field message string The log message.
--- @field params? table Optional table of additional parameters/context.
--- @field raw? string The original raw log line (optional).

---@class logging_export The public API for the logging export module.
---@field _VERSION string Module version.
---@field adapters table<string, {format: function, http_endpoint?: function}> Collection of adapter definitions for platforms like "logstash", "elasticsearch", etc. Each adapter has a `format` function and optional `http_endpoint` function.
---@field export_to_platform fun(entries: LogEntry[], platform: string, options?: table): table[]|nil, string? Formats log entries for a specified platform. Returns array of formatted entries or `nil, error_message`.
---@field create_platform_file fun(log_file: string, platform: string, output_file: string, options?: table): table|nil, string? Reads a log file, formats entries for a platform, and writes to an output file. Returns `{ entries_processed, output_file, entries }` or `nil, error_message`. @throws table If filesystem operations fail critically.
---@field create_platform_config fun(platform: string, output_file: string, options?: table): table|nil, string? Generates a basic configuration file template for a specified platform. Returns `{ config_file, platform }` or `nil, error_message`. @throws table If filesystem operations fail critically.
---@field create_realtime_exporter fun(platform: string, options?: table): table|nil, string? Creates an exporter object with an `export` function for real-time processing (NOTE: doesn't actually send data). Returns `{ export = function, platform = string, http_endpoint = table }` or `nil, error_message`.
---@field get_supported_platforms fun(): string[] Gets a list of supported platform names defined in `adapters`.

local M = {}

--- Module version
M._VERSION = "1.0.0"

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _fs

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the filesystem module with lazy loading to avoid circular dependencies
---@return table|nil The filesystem module or nil if not available
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
end

-- Try to import JSON module if available
local json = try_require("lib.tools.json")

-- Adapter collection for popular log analysis platforms
local adapters = {
  -- Common fields for all adapters
  common = {
    host = function()
      return os.getenv("HOSTNAME") or "unknown"
    end,
    timestamp = function()
      return os.date("%Y-%m-%dT%H:%M:%S")
    end,
  },

  -- Logstash adapter
  logstash = {
    --- Formats a log entry for Logstash (typically JSON format).
    ---@param entry LogEntry The log entry to format.
    ---@param options table Platform-specific options (e.g., `type`, `application_name`, `environment`, `tags`).
    ---@return table Formatted entry suitable for Logstash JSON input.
    format = function(entry, options)
      options = options or {}
      return {
        ["@timestamp"] = entry.timestamp or M.adapters.common.timestamp(),
        ["@metadata"] = {
          type = options.type or "firmo_log",
        },
        level = entry.level,
        module = entry.module,
        message = entry.message,
        params = entry.params,
        application = options.application_name or "firmo",
        environment = options.environment or "development",
        host = options.host or M.adapters.common.host(),
        tags = options.tags or {},
      }
    end,

    --- Defines HTTP endpoint details for Logstash bulk API (or Beats input).
    ---@param options table Platform-specific options (e.g., `url`).
    ---@return table {method: string, url: string, headers: table} HTTP request details.
    http_endpoint = function(options)
      return {
        method = "POST",
        url = options.url or "http://localhost:5044",
        headers = {
          ["Content-Type"] = "application/json",
        },
      }
    end,
  },

  -- Elasticsearch adapter
  elasticsearch = {
    --- Formats a log entry for Elasticsearch ECS (Elastic Common Schema).
    ---@param entry LogEntry The log entry to format.
    ---@param options table Platform-specific options (e.g., `service_name`, `environment`, `host`, `tags`).
    ---@return table Formatted entry conforming to basic ECS structure.
    format = function(entry, options)
      options = options or {}
      return {
        ["@timestamp"] = entry.timestamp or M.adapters.common.timestamp(),
        log = {
          level = entry.level,
          logger = entry.module,
        },
        message = entry.message,
        params = entry.params,
        service = {
          name = options.service_name or "firmo",
          environment = options.environment or "development",
        },
        host = {
          name = options.host or M.adapters.common.host(),
        },
        tags = options.tags or {},
      }
    end,

    --- Defines HTTP endpoint details for Elasticsearch Bulk API.
    ---@param options table Platform-specific options (e.g., `url`, `index`).
    ---@return table {method: string, url: string, headers: table} HTTP request details.
    http_endpoint = function(options)
      options = options or {}
      local index = options.index or "logs-firmo"
      return {
        method = "POST",
        url = (options.url or "http://localhost:9200") .. "/" .. index .. "/_doc",
        headers = {
          ["Content-Type"] = "application/json",
        },
      }
    end,
  },

  -- Splunk adapter
  splunk = {
    --- Formats a log entry for Splunk HEC (HTTP Event Collector) JSON format.
    ---@param entry LogEntry The log entry to format.
    ---@param options table Platform-specific options (e.g., `host`, `source`, `sourcetype`, `index`, `environment`).
    ---@return table Formatted entry suitable for Splunk HEC.
    format = function(entry, options)
      options = options or {}
      return {
        time = entry.timestamp or M.adapters.common.timestamp(),
        host = options.host or M.adapters.common.host(),
        source = options.source or "firmo",
        sourcetype = options.sourcetype or "firmo:log",
        index = options.index or "main",
        event = {
          level = entry.level,
          module = entry.module,
          message = entry.message,
          params = entry.params,
          environment = options.environment or "development",
        },
      }
    end,

    --- Defines HTTP endpoint details for Splunk HEC.
    ---@param options table Platform-specific options (e.g., `url`, `token`).
    ---@return table {method: string, url: string, headers: table} HTTP request details.
    http_endpoint = function(options)
      return {
        method = "POST",
        url = options.url or "http://localhost:8088/services/collector/event",
        headers = {
          ["Content-Type"] = "application/json",
          ["Authorization"] = options.token and ("Splunk " .. options.token) or nil,
        },
      }
    end,
  },

  -- Datadog adapter
  datadog = {
    --- Formats a log entry for Datadog Logs API.
    ---@param entry LogEntry The log entry to format.
    ---@param options table Platform-specific options (e.g., `environment`, `tags`, `service`, `hostname`).
    ---@return table Formatted entry suitable for Datadog Logs API.
    format = function(entry, options)
      options = options or {}
      -- Build tags string
      local tags = "env:" .. (options.environment or "development")
      if entry.module then
        tags = tags .. ",module:" .. entry.module
      end
      if options.tags then
        for k, v in pairs(options.tags) do
          if type(k) == "number" then
            tags = tags .. "," .. v
          else
            tags = tags .. "," .. k .. ":" .. v
          end
        end
      end

      return {
        timestamp = entry.timestamp or M.adapters.common.timestamp(),
        message = entry.message,
        level = entry.level and string.lower(entry.level) or "info",
        service = options.service or "firmo",
        ddsource = "firmo",
        ddtags = tags,
        hostname = options.hostname or M.adapters.common.host(),
        attributes = entry.params,
      }
    end,

    --- Defines HTTP endpoint details for Datadog Logs API.
    ---@param options table Platform-specific options (e.g., `url`, `api_key`).
    ---@return table {method: string, url: string, headers: table} HTTP request details.
    http_endpoint = function(options)
      return {
        method = "POST",
        url = options.url or "https://http-intake.logs.datadoghq.com/v1/input",
        headers = {
          ["Content-Type"] = "application/json",
          ["DD-API-KEY"] = options.api_key or "",
        },
      }
    end,
  },

  -- Grafana Loki adapter
  loki = {
    --- Formats a log entry for Grafana Loki push API.
    ---@param entry LogEntry The log entry to format.
    ---@param options table Platform-specific options (e.g., `environment`, `labels`).
    ---@return table Formatted entry suitable for Loki push API (structure with `streams`).
    format = function(entry, options)
      options = options or {}
      -- Prepare labels
      local labels = {
        level = entry.level and string.lower(entry.level) or "info",
        app = "firmo",
        env = options.environment or "development",
      }

      if entry.module then
        labels.module = entry.module
      end

      if options.labels then
        for k, v in pairs(options.labels) do
          labels[k] = v
        end
      end

      -- Format label string {key="value",key2="value2"}
      local label_str = "{"
      local first = true
      for k, v in pairs(labels) do
        if not first then
          label_str = label_str .. ","
        end
        label_str = label_str .. k .. '="' .. tostring(v):gsub('"', '\\"') .. '"'
        first = false
      end
      label_str = label_str .. "}"

      -- Format entry
      local timestamp_ns = os.time() * 1000000000 -- seconds to nanoseconds
      local formatted_entry = {
        streams = {
          {
            stream = labels,
            values = {
              {
                tostring(timestamp_ns),
                entry.message or "",
              },
            },
          },
        },
      }

      return formatted_entry
    end,

    --- Defines HTTP endpoint details for Grafana Loki push API.
    ---@param options table Platform-specific options (e.g., `url`).
    ---@return table {method: string, url: string, headers: table} HTTP request details.
    http_endpoint = function(options)
      return {
        method = "POST",
        url = (options.url or "http://localhost:3100") .. "/loki/api/v1/push",
        headers = {
          ["Content-Type"] = "application/json",
        },
      }
    end,
  },
}

-- Make adapters available externally
M.adapters = adapters

---@param entries LogEntry[] Array of log entries to export.
---@param platform string Name of the target platform (e.g., "logstash", "elasticsearch").
---@param options? table Platform-specific options passed to the adapter's `format` function.
---@return table[]|nil formatted_entries An array of formatted log entries suitable for the platform, or `nil` if the platform is unsupported.
---@return string? error Error message string if the platform is unsupported.
function M.export_to_platform(entries, platform, options)
  options = options or {}

  -- Get platform adapter
  local adapter = adapters[platform]
  if not adapter then
    return nil, "Unsupported platform: " .. platform
  end

  -- Format entries
  local formatted_entries = {}
  for i, entry in ipairs(entries) do
    formatted_entries[i] = adapter.format(entry, options)
  end

  -- Return formatted entries
  return formatted_entries
end

---@param log_file string Path to the source log file (can be JSON or text format).
---@param platform string Name of the target platform.
---@param output_file string Path to the output file to create.
---@param options? table Options: `{ source_format?: "json"|"text" }` and platform-specific options for formatting.
---@return table|nil result A table `{ entries_processed, output_file, entries }` on success, or `nil` on error.
---@return string? error Error message string if the operation failed (e.g., file not found, unsupported platform, write error).
---@throws table If filesystem operations (`ensure_directory_exists`, `write_file`) fail critically.
function M.create_platform_file(log_file, platform, output_file, options)
  options = options or {}

  -- Check if source file exists
  if not get_fs().file_exists(log_file) then
    return nil, "Log file does not exist: " .. log_file
  end

  -- Get platform adapter
  local adapter = adapters[platform]
  if not adapter then
    return nil, "Unsupported platform: " .. platform
  end

  -- Determine source log format (text or JSON)
  local is_json_source = log_file:match("%.json$") or options.source_format == "json"

  -- Read source log file
  local source_content, err = get_fs().read_file(log_file)
  if not source_content then
    return nil, "Failed to read source log file: " .. (err or "unknown error")
  end

  -- Prepare output content (will be written at the end)
  local output_content = ""

  -- Parse functions for different log formats
  local function parse_json_log_line(line)
    if not line or line:sub(1, 1) ~= "{" then
      return nil
    end

    -- Simple extraction of fields from JSON
    local timestamp = line:match('"timestamp":"([^"]*)"')
    local level = line:match('"level":"([^"]*)"')
    local module = line:match('"module":"([^"]*)"')
    local message = line:match('"message":"([^"]*)"')

    -- Try to parse additional parameters
    local params = {}
    for k, v in line:gmatch('"([^",:]*)":"([^"]*)"') do
      if k ~= "timestamp" and k ~= "level" and k ~= "module" and k ~= "message" then
        params[k] = v
      end
    end

    return {
      timestamp = timestamp,
      level = level,
      module = module,
      message = message,
      params = params,
      raw = line,
    }
  end

  local function parse_text_log_line(line)
    if not line then
      return nil
    end

    -- Parse timestamp
    local timestamp = line:match("^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)")

    -- Parse log level
    local level = line:match(" | ([A-Z]+) | ")

    -- Parse module name
    local module = line:match(" | [A-Z]+ | ([^|]+) | ")

    -- Parse message (everything after module)
    local message
    if module then
      message = line:match(" | [A-Z]+ | [^|]+ | (.+)")
    else
      message = line:match(" | [A-Z]+ | (.+)")
    end

    -- Parse parameters if present
    local params = {}
    local params_str = message and message:match("%([^)]+%)$")
    if params_str then
      -- Extract parameters from parentheses
      for k, v in params_str:gmatch("([%w_]+)=([^,)]+)") do
        params[k] = v
      end

      -- Clean up message
      message = message:gsub("%([^)]+%)$", ""):gsub("%s+$", "")
    end

    return {
      timestamp = timestamp,
      level = level,
      module = module and module:gsub("%s+$", ""),
      message = message,
      params = params,
      raw = line,
    }
  end

  -- Get JSON module
  local json = get_json()
  if not json then
    return nil, "JSON module not available and fallback failed"
  end

  -- Process each line
  local count = 0
  local entries = {}

  -- Split content into lines and process each one
  for line in source_content:gmatch("([^\r\n]+)[\r\n]*") do
    local log_entry

    -- Parse based on format
    if is_json_source then
      log_entry = parse_json_log_line(line)
    else
      log_entry = parse_text_log_line(line)
    end

    -- Process entries that were successfully parsed
    if log_entry then
      count = count + 1

      -- Format for the target platform
      local formatted = adapter.format(log_entry, options)
      table.insert(entries, formatted)

      -- Add to output content
      output_content = output_content .. json.encode(formatted) .. "\n"
    end
  end

  -- Ensure parent directory exists
  local parent_dir = get_fs().get_directory_name(output_file)
  if parent_dir and parent_dir ~= "" then
    local success, err = get_fs().ensure_directory_exists(parent_dir)
    if not success then
      return nil, "Failed to create parent directory: " .. (err or "unknown error")
    end
  end

  -- Write the complete output content to file
  local success, write_err = get_fs().write_file(output_file, output_content)
  if not success then
    return nil, "Failed to write output file: " .. (write_err or "unknown error")
  end

  return {
    entries_processed = count,
    output_file = output_file,
    entries = entries,
  }
end

---@param platform string Name of the target platform.
---@param output_file string Path to the output configuration file to create.
---@param options? table Platform-specific options used to customize the config template (e.g., `{ es_host?: string, service?: string }`).
---@return table|nil result A table `{ config_file, platform }` on success, or `nil` on error.
---@return string? error Error message string if the operation failed (e.g., unsupported platform, write error).
---@throws table If filesystem operations (`ensure_directory_exists`, `write_file`) fail critically.
function M.create_platform_config(platform, output_file, options)
  options = options or {}

  -- Get platform adapter
  local adapter = adapters[platform]
  if not adapter then
    return nil, "Unsupported platform: " .. platform
  end

  -- Ensure parent directory exists
  local parent_dir = get_fs().get_directory_name(output_file)
  if parent_dir and parent_dir ~= "" then
    local success, err = get_fs().ensure_directory_exists(parent_dir)
    if not success then
      return nil, "Failed to create parent directory: " .. (err or "unknown error")
    end
  end

  -- Prepare config content
  local config_content = ""

  -- Generate platform-specific configuration content
  if platform == "logstash" then
    config_content = [[
input {
  file {
    path => "logs/firmo.json"
    codec => "json"
    type => "firmo"
  }
}

filter {
  if [type] == "firmo" {
    date {
      match => [ "@timestamp", "ISO8601" ]
    }

    # Extract module for better filtering
    if [module] {
      mutate {
        add_field => { "[@metadata][module]" => "%{module}" }
      }
    }

    # Set log level as a tag for filtering
    if [level] {
      mutate {
        add_tag => [ "%{level}" ]
      }
    }
  }
}

output {
  if [type] == "firmo" {
    elasticsearch {
      hosts => ["]] .. (options.es_host or "localhost:9200") .. [["]
      index => "firmo-%{+YYYY.MM.dd}"
    }

    # Uncomment to enable stdout output for debugging
    # stdout { codec => rubydebug }
  }
}
]]
  elseif platform == "elasticsearch" then
    config_content = [[
{
  "index_patterns": ["firmo-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.refresh_interval": "5s"
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "log.level": { "type": "keyword" },
        "log.logger": { "type": "keyword" },
        "message": { "type": "text" },
        "service.name": { "type": "keyword" },
        "service.environment": { "type": "keyword" },
        "host.name": { "type": "keyword" },
        "tags": { "type": "keyword" }
      }
    }
  }
}
]]
  elseif platform == "splunk" then
    config_content = [[
[firmo_logs]
DATETIME_CONFIG =
INDEXED_EXTRACTIONS = json
KV_MODE = none
LINE_BREAKER = ([\r\n]+)
NO_BINARY_CHECK = true
category = Custom
disabled = false
pulldown_type = true
TIME_FORMAT = %Y-%m-%dT%H:%M:%S
TIME_PREFIX = "time":"
]]
  elseif platform == "datadog" then
    config_content = [[
# Datadog Agent configuration for firmo logs
logs:
  - type: file
    path: "logs/firmo.json"
    service: "]] .. (options.service or "firmo") .. [["
    source: "firmo"
    sourcecategory: "logging"
    log_processing_rules:
      - type: multi_line
        name: log_start_with_date
        pattern: \d{4}-\d{2}-\d{2}
    json:
      message: message
      service: service
      ddsource: ddsource
      ddtags: ddtags
      hostname: hostname
      level: level
]]
  elseif platform == "loki" then
    config_content = [[
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /tmp/loki/boltdb-shipper-active
    cache_location: /tmp/loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /tmp/loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
]]
  else
    return nil, "No configuration template available for platform: " .. platform
  end

  -- Write the configuration to file
  local success, err = get_fs().write_file(output_file, config_content)
  if not success then
    return nil, "Failed to write configuration file: " .. (err or "unknown error")
  end

  return {
    config_file = output_file,
    platform = platform,
  }
end

---@param platform string Name of the target platform.
---@param options? table Platform-specific options passed to the adapter's `format` and `http_endpoint` functions.
---@return table|nil exporter An exporter object `{ export = fun(entry: LogEntry), platform = string, http_endpoint = table }`, or `nil` if platform unsupported. The `export` function formats a single entry. `http_endpoint` provides details for sending data (actual sending is not implemented here).
---@return string? error Error message string if the platform is unsupported.
function M.create_realtime_exporter(platform, options)
  options = options or {}

  -- Get platform adapter
  local adapter = adapters[platform]
  if not adapter then
    return nil, "Unsupported platform: " .. platform
  end

  -- Define export function
  local function export_entry(entry)
    -- Format for the target platform
    local formatted = adapter.format(entry, options)

    -- In a real implementation, this would send to an external service
    -- For this example, we'll just return the formatted entry
    return formatted
  end

  -- Return the exporter
  return {
    export = export_entry,
    platform = platform,
    http_endpoint = adapter.http_endpoint and adapter.http_endpoint(options) or nil,
  }
end

--- Returns a list of supported platform names defined in the `adapters` table.
---@return string[] platforms An array of supported platform names (e.g., `"logstash"`, `"elasticsearch"`).
function M.get_supported_platforms()
  local platforms = {}
  for k, _ in pairs(adapters) do
    if k ~= "common" then
      table.insert(platforms, k)
    end
  end
  return platforms
end

return M
