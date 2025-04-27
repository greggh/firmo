# lib/tools/logging Knowledge

## Purpose

The `lib/tools/logging` module provides Firmo's centralized system for recording events, diagnostic information, errors, and other runtime messages. It offers a flexible and feature-rich approach, supporting structured logging with key-value context, multiple hierarchical log levels, configurable output destinations (console and file), different formatting options (text with colors, JSON), module-based filtering, automatic file rotation, log buffering, test-aware log suppression, and integrations for searching and exporting log data.

## Key Concepts

- **Logger Instances (`get_logger`):** The primary way to interact with the logging system is by obtaining a named logger instance using `logging.get_logger("MyModuleName")`. This associates log messages with their source module, allowing for fine-grained configuration (e.g., setting different log levels for different modules) and easier filtering during analysis.

- **Log Levels (`LEVELS`):** The system uses hierarchical log levels to control verbosity. The standard levels are:
    - `FATAL` (0): Unrecoverable errors causing application termination.
    - `ERROR` (1): Serious errors preventing normal operation of a component.
    - `WARN` (2): Potential issues or unexpected situations.
    - `INFO` (3): Normal operational messages, significant events.
    - `DEBUG` (4): Detailed information for troubleshooting and development.
    - `TRACE`/`VERBOSE` (5): Highly detailed step-by-step execution information.
    Setting a log level (e.g., `INFO`) enables logging for that level and all levels above it (`INFO`, `WARN`, `ERROR`, `FATAL`).

- **Structured Logging (`params`):** Instead of embedding variable data directly into log messages (which makes parsing harder), the logging methods accept an optional second argument: a Lua table (`params`). This table should contain key-value pairs representing contextual information relevant to the log event (e.g., `{ user_id = 123, file = "data.txt" }`). This structured data is preserved, especially in JSON output, facilitating easier filtering, searching, and analysis later.

- **Configuration (`configure`, `configure_from_config`):** The logging system's behavior is highly configurable, primarily through the `lib.core.central_config` system (usually via `.firmo-config.lua`). Key options include:
    - `level` (string|number): The default global log level threshold.
    - `module_levels` (table): A table mapping module names (strings) to specific log levels (e.g., `{ Database = "INFO", Network = "DEBUG" }`). Module levels override the global level.
    - `timestamps` (boolean): Whether to include timestamps in log output.
    - `use_colors` (boolean): Whether to use ANSI color codes for levels in console output.
    - `output_file` (string|nil): Path (relative to `log_dir`) for the primary text/console-formatted log file. If `nil`, file logging is disabled.
    - `log_dir` (string): The base directory where log files are stored (default: `"logs"`).
    - `max_file_size` (number): Maximum size in bytes before a log file is rotated (default: 50KB).
    - `max_log_files` (number): Number of rotated log files to keep (e.g., `5` keeps `file.log`, `file.log.1`, ..., `file.log.5`).
    - `format` (string): Format for console and `output_file` (`"text"` or `"json"`).
    - `json_file` (string|nil): Path (relative to `log_dir`) for a separate file containing logs strictly in JSON format.
    - `module_filter` (string|string[]|nil): A whitelist of module name patterns (e.g., `"UI*"` or `{"Network", "Database"}`) to include. Only logs from matching modules are processed if set.
    - `module_blacklist` (string[]): A list of module name patterns to always exclude, taking precedence over `module_filter`.
    - `silent` (boolean): If `true`, suppresses *all* logging output.
    - `buffer_size` (number): Number of log entries to buffer in memory before flushing to file (0 disables buffering).
    - `buffer_flush_interval` (number): Maximum time in seconds before automatically flushing the buffer, even if not full.
    `M.configure(options)` applies settings directly, while `M.configure_from_config(module_name)` loads settings from `central_config` and determines the effective level for a given module. `get_logger` automatically calls `configure_from_config`.

- **Output & Formatting:** Logs can be sent to the console (stdout) and/or one or two files (`output_file` for text/JSON, `json_file` strictly for JSON). Console output can optionally use ANSI colors for levels. File output supports automatic rotation based on `max_file_size`, keeping `max_log_files` backups.

- **Test Integration (`current_test_expects_errors`):** The logging system is aware of the test execution context via integration with `lib/tools/error_handler`. If the error handler indicates the currently running test *expects* an error (via metadata set by the runner), log messages with `ERROR` or `WARN` severity are automatically downgraded to `DEBUG` level before filtering. This significantly reduces noise in test output when failures are anticipated and intentionally handled. The global flag `_G._firmo_debug_mode` (set via `--debug` CLI flag) can override this suppression for debugging expected errors.

- **Log Export (`export.lua` - via `M.export()`):** This sub-module provides tools to format log entries into structures suitable for various external log analysis platforms (Logstash, Elasticsearch ECS, Splunk HEC, Datadog, Loki). `M.export().create_platform_file(...)` can read a Firmo log file and convert it into a format ready for ingestion. `M.export().get_supported_platforms()` lists available adapters.

- **Log Search (`search.lua` - via `M.search()`):** This sub-module allows searching through existing Firmo log files (text or JSON). `M.search().search_logs(...)` filters entries based on criteria like time range, level, module name, and message content patterns. `M.search().get_log_stats(...)` provides summary statistics about a log file.

- **Formatter Integration (`formatter_integration.lua` - via `M.formatter_integration()`):** This sub-module bridges logging and reporting. `M.formatter_integration().enhance_formatters()` adds logging methods (`log_info`, etc.) to reporting formatters. `M.formatter_integration().create_test_logger(...)` creates logger instances that automatically include test name and context in log parameters.

## Usage Examples / Patterns

### Pattern 1: Getting and Using a Module Logger

```lua
--[[
  Standard way to get and use a logger within a module.
]]
local logging = require("lib.tools.logging")
local logger = logging.get_logger("MyModule") -- Use specific module name

local item_id = 123
local data = { value = 42, status = "processed" }

-- Log informational message with structured context
logger.info("Processing item completed", {
  item_id = item_id,
  processed_data = data,
  duration_ms = 55,
})

-- Log a warning
logger.warn("Configuration value missing, using default", {
  key = "retry_count",
  default = 3,
})

-- Log an error (perhaps retrieved from error_handler)
local err = { message = "Connection refused", category = "IO", context = { host = "db.server" } }
logger.error("Database connection failed", { error_details = err })
```

### Pattern 2: Checking Log Level Before Expensive Operations

```lua
--[[
  Avoid computing expensive debug data if DEBUG level is not enabled for this logger.
]]
local logging = require("lib.tools.logging")
local logger = logging.get_logger("DataAnalysis")

if logger.is_debug_enabled() then
  -- This function might take time or allocate memory
  local detailed_stats = calculate_complex_statistics()

  logger.debug("Detailed analysis statistics", {
    stats = detailed_stats,
    threshold = 0.95,
  })
end
```

### Pattern 3: Basic Configuration (Example)

```lua
--[[
  Example of directly configuring logging (usually done via central_config).
]]
local logging = require("lib.tools.logging")

logging.configure({
  level = "INFO", -- Global level is INFO
  module_levels = {
    ["Network.HTTP"] = "DEBUG", -- Specific module at DEBUG
    ["Database"] = "WARN",      -- Another module at WARN
  },
  output_file = "app.log",    -- Log to logs/app.log
  log_dir = "logs",
  use_colors = true,          -- Use colors on console
  timestamps = true,
  max_file_size = 10 * 1024 * 1024, -- 10 MB rotation size
  max_log_files = 3,             -- Keep 3 rotated files
  -- json_file = "app_structured.log", -- Optionally log JSON to separate file
  -- module_filter = {"Core*", "UI"},   -- Optionally only show logs from Core* and UI
  -- module_blacklist = {"ThirdPartyLib"}, -- Optionally always hide ThirdPartyLib logs
})
```

### Pattern 4: Basic Log Search Example

```lua
--[[
  Search for ERROR level messages in a log file.
]]
local logging = require("lib.tools.logging")

local search_module = logging.search() -- Get the search sub-module

local results, err = search_module.search_logs({
  log_file = "logs/app.log",
  level = "ERROR",
  limit = 50, -- Find up to 50 errors
})

if results then
  print("Found " .. results.matched .. " error(s):")
  for _, entry in ipairs(results.entries) do
    print(string.format("  [%s] %s: %s", entry.timestamp, entry.module or "-", entry.message or ""))
  end
else
  print("Error searching logs: " .. err)
end
```

### Pattern 5: Basic Log Export Example

```lua
--[[
  Export logs to Logstash JSON format.
]]
local logging = require("lib.tools.logging")

local export_module = logging.export() -- Get the export sub-module

local result, err = export_module.create_platform_file(
  "logs/app.log",      -- Source log file
  "logstash",          -- Target platform
  "export/logstash.json", -- Output file
  {                      -- Platform-specific options
    application_name = "MyFirmoApp",
    environment = "production"
  }
)

if result then
  print("Exported " .. result.entries_processed .. " entries to " .. result.output_file)
else
  print("Error exporting logs: " .. err)
end
```

## Related Components / Modules

- **`lib/tools/logging/init.lua`**: Source for core logging logic, configuration, logger instances.
- **`lib/tools/logging/export.lua`**: Source for log exporting adapters and functions.
- **`lib/tools/logging/search.lua`**: Source for log searching and statistics functions.
- **`lib/tools/logging/formatter_integration.lua`**: Source for integration with reporting formatters and test context.
- **`lib/tools/error_handler/knowledge.md`**: Interacts closely for logging errors and determining test context (e.g., `expect_error` flag for suppression). Error objects are often passed in `params`.
- **`lib/core/central_config/knowledge.md`**: The primary source for logging configuration (`level`, `output_file`, `module_levels`, etc.).
- **`lib/tools/filesystem/knowledge.md`**: Used internally for writing log files, ensuring directories exist, and handling file rotation.
- **`lib/reporting/formatters/knowledge.md`**: Reporting formatters can be enhanced with logging capabilities via `formatter_integration`.

## Best Practices / Critical Rules (Optional)

- **Use Module Loggers:** Always use `logging.get_logger("ModuleName")` instead of global logging functions (`logging.info`, etc.) to provide context and allow per-module configuration.
- **Use Structured Context (`params`):** Pass contextual data as a table in the second argument (`params`) rather than formatting it into the message string. This makes logs searchable and parsable.
- **Check Levels for Expensive Ops:** Use `logger.is_debug_enabled()` or `logger.is_trace_enabled()` before performing computationally expensive operations solely for generating log data.
- **Configure via Central Config:** Manage logging settings primarily through the `.firmo-config.lua` file for consistency and environment-specific overrides.
- **Configure Rotation:** For applications or long test suites that generate significant logs, configure `max_file_size` and `max_log_files` appropriately to prevent disk space issues.

## Troubleshooting / Common Pitfalls (Optional)

- **Logs Not Appearing:**
    - Check the configured log level (global `level` and specific `module_levels` in config) versus the level being logged.
    - Check if `module_filter` is set and excludes the module logging.
    - Check if `module_blacklist` excludes the module logging.
    - Check if the `silent` flag is set to `true`.
    - Ensure the correct logger instance (obtained via `get_logger`) is being used.
- **File Logging Issues:**
    - Verify `output_file` and/or `json_file` are set in the configuration.
    - Check the `log_dir` path; ensure it exists and the process has write permissions. Check logs for "Failed to create log directory" or "Failed to write to log file" warnings.
    - If rotation seems broken, check `max_file_size` (ensure it's > 0) and `max_log_files`. Verify filesystem permissions allow renaming/deleting files in `log_dir`. Ensure `lib/tools/filesystem` is available and working.
- **Test Logs Appearing / Suppressed Unexpectedly:**
    - This logic depends entirely on `lib/tools/error_handler`. Verify that the test runner (`scripts/runner.lua`) is correctly calling `error_handler.set_test_mode(true)` before tests and `error_handler.set_current_test_metadata({...})` before *each* test (with `expect_error = true` if applicable), and clearing them afterwards.
    - Use the `--debug` CLI flag (`_G._firmo_debug_mode`) to force display of expected errors if needed for debugging the suppression itself.
- **Search/Export Errors:**
    - Ensure the source log file (`log_file` argument) exists and is readable.
    - Verify the specified format (`text` or `json`) matches the actual content of the log file.
    - For export, ensure the target platform name (e.g., `logstash`) is correct (`M.export().get_supported_platforms()`).
    - Check write permissions for the output file/directory.
