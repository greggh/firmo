---@class LogSearchModule
---@field _VERSION string Module version
---@field search_logs fun(log_file: string, query: table): {entries: table[], total: number, matched: number}|nil, table? Search log files with filters
---@field filter_entries fun(entries: table[], filters: table): table[] Filter log entries by criteria
---@field parse_log_file fun(log_file: string, format?: string): table[]|nil, table? Parse a log file into entries
---@field query fun(logs: table[], options: {level?: string|string[], module?: string|string[], message?: string, from?: string, to?: string, limit?: number}): table[] Query logs with various criteria
---@field get_logs_for_date fun(date: string, log_dir?: string): table[]|nil, table? Get logs for a specific date
---@field extract_log_stats fun(log_entries: table[]): {by_level: table<string, number>, by_module: table<string, number>, errors_by_module: table<string, number>, time_distribution: table<number, number>} Extract statistics from log entries
---@field get_recent_errors fun(count?: number, log_dir?: string): table[]|nil, table? Get recent error logs

-- Log search and query module for firmo
-- This module provides search and filtering capabilities for log files

local M = {}
M._VERSION = "1.0.0"

-- Require filesystem module - fail if not available
local fs = require("lib.tools.filesystem")

-- Parse a log line (text format)
local function parse_text_log_line(line)
  if not line then
    return nil
  end

  -- Basic text log format parser
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
  local params_str = message and message:match("%([^)]+%)$")
  local clean_message = message and message:gsub("%([^)]+%)$", ""):gsub("%s+$", "")

  return {
    timestamp = timestamp,
    level = level,
    module = module and module:gsub("%s+$", ""),
    message = clean_message,
    params = params_str,
    raw = line,
  }
end

-- Parse a log line (JSON format)
local function parse_json_log_line(line)
  if not line or line:sub(1, 1) ~= "{" then
    return nil
  end

  -- Implement a very simple JSON parser for log entries
  local function extract_string_value(input, key)
    local pattern = '"' .. key .. '"%s*:%s*"([^"]*)"'
    return input:match(pattern)
  end

  ---@diagnostic disable-next-line: unused-local, unused-function
  local function extract_numeric_value(input, key)
    local pattern = '"' .. key .. '"%s*:%s*([0-9%.]+)'
    local value = input:match(pattern)
    return value and tonumber(value)
  end

  return {
    timestamp = extract_string_value(line, "timestamp"),
    level = extract_string_value(line, "level"),
    module = extract_string_value(line, "module"),
    message = extract_string_value(line, "message"),
    raw = line,
    -- Note: other fields will be parsed on demand as needed
  }
end

-- Basic log search function
function M.search_logs(options)
  options = options or {}

  if not fs then
    return nil, "Filesystem module not available"
  end

  -- Validate options
  local log_file = options.log_file
  if not log_file then
    return nil, "Log file path is required"
  end

  -- Check if file exists
  if not fs.file_exists(log_file) then
    return nil, "Log file does not exist: " .. log_file
  end

  -- Determine log format (text or JSON)
  local is_json = log_file:match("%.json$") or options.format == "json"

  -- Read log file
  local content, err = fs.read_file(log_file)
  if not content then
    return nil, "Failed to read log file: " .. (err or "unknown error")
  end

  -- Set up filtering criteria
  local from_date = options.from_date
  local to_date = options.to_date
  local level = options.level and options.level:upper()
  local module = options.module
  local message_pattern = options.message_pattern
  local limit = options.limit or 1000 -- Default limit to prevent memory issues

  -- Initialize results
  local results = {}
  local count = 0
  local total = 0

  -- Process log file line by line (split content into lines)
  for line in content:gmatch("([^\r\n]+)[\r\n]*") do
    local log_entry

    -- Parse based on format
    if is_json then
      log_entry = parse_json_log_line(line)
    else
      log_entry = parse_text_log_line(line)
    end

    -- Apply filters to parsed entry
    if log_entry then
      total = total + 1
      local include = true

      -- Filter by timestamp/date if specified
      if include and from_date and log_entry.timestamp then
        include = log_entry.timestamp >= from_date
      end

      if include and to_date and log_entry.timestamp then
        include = log_entry.timestamp <= to_date
      end

      -- Filter by log level
      if include and level and log_entry.level then
        include = log_entry.level == level
      end

      -- Filter by module
      if include and module and log_entry.module then
        -- Support exact match or wildcard at end
        if module:match("%*$") then
          local prefix = module:gsub("%*$", "")
          include = log_entry.module:sub(1, #prefix) == prefix
        else
          include = log_entry.module == module
        end
      end

      -- Filter by message content - make it case-insensitive
      if include and message_pattern and log_entry.message then
        include = log_entry.message:lower():find(message_pattern:lower()) ~= nil
      end

      -- Add to results if passes all filters
      if include then
        count = count + 1
        results[count] = log_entry

        -- Check limit
        if count >= limit then
          break
        end
      end
    end
  end

  -- Return results
  return {
    entries = results,
    total = total,       -- Total entries processed
    matched = count,     -- Number of entries that matched filters
    count = count,       -- For backward compatibility
    truncated = count >= limit,
  }
end

-- Get log statistics
function M.get_log_stats(log_file, options)
  options = options or {}

  -- Check if file exists
  if not fs.file_exists(log_file) then
    return nil, "Log file does not exist: " .. log_file
  end

  -- Determine log format (text or JSON)
  local is_json = log_file:match("%.json$") or options.format == "json"

  -- Read log file
  local content, err = fs.read_file(log_file)
  if not content then
    return nil, "Failed to read log file: " .. (err or "unknown error")
  end

  -- Initialize statistics
  local stats = {
    total_entries = 0,
    by_level = {},
    by_module = {},
    errors = 0,
    warnings = 0,
    first_timestamp = nil,
    last_timestamp = nil,
  }

  -- Process log file line by line
  for line in content:gmatch("([^\r\n]+)[\r\n]*") do
    local log_entry

    -- Parse based on format
    if is_json then
      log_entry = parse_json_log_line(line)
    else
      log_entry = parse_text_log_line(line)
    end

    -- Update statistics
    if log_entry then
      stats.total_entries = stats.total_entries + 1

      -- Track by level
      if log_entry.level then
        stats.by_level[log_entry.level] = (stats.by_level[log_entry.level] or 0) + 1

        -- Count errors and warnings
        if log_entry.level == "ERROR" or log_entry.level == "FATAL" then
          stats.errors = stats.errors + 1
        elseif log_entry.level == "WARN" then
          stats.warnings = stats.warnings + 1
        end
      end

      -- Track by module
      if log_entry.module then
        stats.by_module[log_entry.module] = (stats.by_module[log_entry.module] or 0) + 1
      end

      -- Track timestamp range
      if log_entry.timestamp then
        if not stats.first_timestamp or log_entry.timestamp < stats.first_timestamp then
          stats.first_timestamp = log_entry.timestamp
        end

        if not stats.last_timestamp or log_entry.timestamp > stats.last_timestamp then
          stats.last_timestamp = log_entry.timestamp
        end
      end
    end
  end

  -- Add file size information
  stats.file_size = fs.get_file_size(log_file)

  -- Always return a valid stats object even if there are no entries
  return stats
end

-- Export logs to a different format
function M.export_logs(log_file, output_file, format, options)
  options = options or {}

  -- Check if source file exists
  if not fs.file_exists(log_file) then
    return nil, "Log file does not exist: " .. log_file
  end

  -- Determine source log format (text or JSON)
  local is_json_source = log_file:match("%.json$") or options.source_format == "json"

  -- Read source log file
  local source_content, err = fs.read_file(log_file)
  if not source_content then
    return nil, "Failed to read source log file: " .. (err or "unknown error")
  end

  -- Ensure output directory exists
  local output_dir = fs.get_directory_name(output_file)
  if output_dir and output_dir ~= "" then
    local success, err = fs.ensure_directory_exists(output_dir)
    if not success then
      return nil, "Failed to create output directory: " .. (err or "unknown error")
    end
  end

  -- Prepare output content
  local output_content = ""

  -- Add format-specific header
  if format == "csv" then
    output_content = output_content .. "timestamp,level,module,message\n"
  elseif format == "html" then
    -- Add HTML header
    output_content = output_content
      .. [[
<!DOCTYPE html>
<html>
<head>
  <title>Log Export</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 20px; }
    table { width: 100%; border-collapse: collapse; }
    th { background: #f1f1f1; border-bottom: 2px solid #ddd; text-align: left; padding: 8px; }
    td { border-bottom: 1px solid #ddd; padding: 8px; vertical-align: top; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    .fatal { background-color: #ffdddd; }
    .error { color: #d00; }
    .warn { color: #e90; }
    .info { color: #07f; }
    .debug { color: #090; }
    .trace { color: #777; }
  </style>
</head>
<body>
  <h1>Log Export</h1>
  <p>Source: ]]
      .. log_file
      .. [[</p>
  <table>
    <tr>
      <th>Timestamp</th>
      <th>Level</th>
      <th>Module</th>
      <th>Message</th>
    </tr>
]]
  end

  -- Process each line
  local count = 0
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

      -- Add entry in the output format
      if format == "json" and not is_json_source then
        -- Convert text log to JSON format
        output_content = output_content
          .. string.format(
            '{"timestamp":"%s","level":"%s","module":"%s","message":"%s"}',
            log_entry.timestamp or "",
            log_entry.level or "",
            log_entry.module or "",
            (log_entry.message or ""):gsub('"', '\\"')
          )
          .. "\n"
      elseif format == "csv" then
        -- Add as CSV
        output_content = output_content
          .. string.format(
            '"%s","%s","%s","%s"\n',
            log_entry.timestamp or "",
            log_entry.level or "",
            log_entry.module or "",
            (log_entry.message or ""):gsub('"', '""') -- Escape quotes in CSV
          )
      elseif format == "html" then
        -- Add as HTML table row
        local level_class = log_entry.level and log_entry.level:lower() or ""
        output_content = output_content
          .. string.format(
            '    <tr class="%s">\n      <td>%s</td>\n      <td class="%s">%s</td>\n      <td>%s</td>\n      <td>%s</td>\n    </tr>\n',
            log_entry.level and log_entry.level:lower() == "fatal" and "fatal" or "",
            log_entry.timestamp or "",
            level_class,
            log_entry.level or "",
            log_entry.module or "",
            (log_entry.message or ""):gsub("<", "&lt;"):gsub(">", "&gt;") -- Escape HTML
          )
      elseif format == "text" and is_json_source then
        -- Convert JSON log to text format
        local text = string.format(
          "%s | %s | %s | %s",
          log_entry.timestamp or "",
          log_entry.level or "",
          log_entry.module or "",
          log_entry.message or ""
        )
        output_content = output_content .. text .. "\n"
      else
        -- Copy as-is
        output_content = output_content .. log_entry.raw .. "\n"
      end
    end
  end

  -- Add format-specific footer
  if format == "html" then
    output_content = output_content .. [[
  </table>
  <p>Total entries: ]] .. count .. [[</p>
</body>
</html>
]]
  end

  -- Write the complete output content to file
  local success, write_err = fs.write_file(output_file, output_content)
  if not success then
    return nil, "Failed to write output file: " .. (write_err or "unknown error")
  end

  return {
    entries_processed = count,
    output_file = output_file,
  }
end

-- Add adapter for popular log analysis tools
function M.create_export_adapter(adapter_type, options)
  options = options or {}

  -- Validate adapter type
  if not adapter_type then
    return nil, "Adapter type is required"
  end

  local adapters = {
    -- Logstash adapter
    logstash = function(log_entry)
      return {
        ["@timestamp"] = log_entry.timestamp,
        ["@metadata"] = {
          type = "firmo_log",
        },
        level = log_entry.level,
        module = log_entry.module,
        message = log_entry.message,
        application = options.application_name or "firmo",
        environment = options.environment or "development",
        host = options.host or os.getenv("HOSTNAME") or "unknown",
      }
    end,

    -- ELK adapter
    elk = function(log_entry)
      return {
        ["@timestamp"] = log_entry.timestamp,
        log = {
          level = log_entry.level,
          logger = log_entry.module,
        },
        message = log_entry.message,
        service = {
          name = options.service_name or "firmo",
          environment = options.environment or "development",
        },
        host = {
          name = options.host or os.getenv("HOSTNAME") or "unknown",
        },
      }
    end,

    -- Splunk adapter
    splunk = function(log_entry)
      return {
        time = log_entry.timestamp,
        host = options.host or os.getenv("HOSTNAME") or "unknown",
        source = options.source or "firmo",
        sourcetype = options.sourcetype or "firmo:log",
        index = options.index or "main",
        event = {
          level = log_entry.level,
          module = log_entry.module,
          message = log_entry.message,
          environment = options.environment or "development",
        },
      }
    end,

    -- Datadog adapter
    datadog = function(log_entry)
      return {
        timestamp = log_entry.timestamp,
        message = log_entry.message,
        level = log_entry.level and log_entry.level:lower() or "info",
        service = options.service or "firmo",
        ddsource = "firmo",
        ddtags = "env:" .. (options.environment or "development") .. ",module:" .. (log_entry.module or "unknown"),
        hostname = options.hostname or os.getenv("HOSTNAME") or "unknown",
      }
    end,
  }

  -- Return the selected adapter
  if adapters[adapter_type] then
    return adapters[adapter_type]
  else
    return nil, "Unknown adapter type: " .. adapter_type
  end
end

-- Get a function to process log entries in real-time
function M.get_log_processor(options)
  options = options or {}

  -- Supported outputs
  local outputs = {}

  -- Add file output if configured
  if options.output_file then
    -- Ensure output directory exists
    local dir = fs.get_directory_name(options.output_file)
    if dir and dir ~= "" then
      fs.ensure_directory_exists(dir)
    end

    -- Create an output handler
    table.insert(outputs, {
      type = "file",
      format = options.format or "text",
      path = options.output_file,
      buffer = "",
      flush_interval = options.flush_interval or 10, -- Seconds
      last_flush = os.time(),
      flush = function(self)
        if self.buffer and self.buffer ~= "" then
          fs.append_file(self.path, self.buffer)
          self.buffer = ""
          self.last_flush = os.time()
        end
      end,
      close = function(self)
        self:flush()
      end,
    })
  end

  -- Add adapter output if configured
  if options.adapter and options.adapter_type then
    table.insert(outputs, {
      type = "adapter",
      adapter = options.adapter,
      adapter_type = options.adapter_type,
    })
  end

  -- Add callback output if provided
  if options.callback and type(options.callback) == "function" then
    table.insert(outputs, {
      type = "callback",
      callback = options.callback,
    })
  end

  -- Set up filtering
  local filter = {
    level = options.level,
    module = options.module,
    message_pattern = options.message_pattern,
  }

  -- Return processor function
  return {
    -- Process a log entry
    process = function(log_entry)
      -- Apply filters
      local include = true

      -- Filter by log level
      if include and filter.level and log_entry.level then
        include = log_entry.level == filter.level
      end

      -- Filter by module
      if include and filter.module and log_entry.module then
        -- Support exact match or wildcard at end
        if filter.module:match("%*$") then
          local prefix = filter.module:gsub("%*$", "")
          include = log_entry.module:sub(1, #prefix) == prefix
        else
          include = log_entry.module == filter.module
        end
      end

      -- Filter by message content
      if include and filter.message_pattern and log_entry.message then
        include = log_entry.message:match(filter.message_pattern) ~= nil
      end

      -- Process if passes filters
      if include then
        for _, output in ipairs(outputs) do
          if output.type == "file" then
            local line
            if output.format == "json" then
              -- Format as JSON
              line = string.format(
                '{"timestamp":"%s","level":"%s","module":"%s","message":"%s"}',
                log_entry.timestamp or "",
                log_entry.level or "",
                log_entry.module or "",
                (log_entry.message or ""):gsub('"', '\\"')
              ) .. "\n"
            elseif output.format == "csv" then
              -- Format as CSV
              line = string.format(
                '"%s","%s","%s","%s"\n',
                log_entry.timestamp or "",
                log_entry.level or "",
                log_entry.module or "",
                (log_entry.message or ""):gsub('"', '""') -- Escape quotes in CSV
              )
            else
              -- Format as text
              line = string.format(
                "%s | %s | %s | %s",
                log_entry.timestamp or "",
                log_entry.level or "",
                log_entry.module or "",
                log_entry.message or ""
              ) .. "\n"
            end

            -- Add to buffer
            output.buffer = output.buffer .. line

            -- Check if it's time to flush
            if os.time() - output.last_flush >= output.flush_interval then
              output:flush()
            end
          elseif output.type == "adapter" then
            -- Process through adapter
            if output.adapter then
              ---@diagnostic disable-next-line: unused-local
              local adapted = output.adapter(log_entry)
              -- The adapted result can be processed further or sent to external systems
            end
          elseif output.type == "callback" then
            -- Call the callback function
            output.callback(log_entry)
          end
        end

        return true
      end

      return false
    end,

    -- Close all outputs
    close = function()
      for _, output in ipairs(outputs) do
        if output.type == "file" and output.close then
          output:close()
        end
      end
    end,
  }
end

return M
