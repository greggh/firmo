# tests/tools/logging Knowledge

## Purpose

The `tests/tools/logging/` directory contains the automated tests for Firmo's comprehensive logging system, implemented in `lib/tools/logging` and its associated sub-modules (`export`, `search`, `formatter_integration`). These tests verify the correct operation of all logging features, including obtaining logger instances, handling different log levels, filtering messages, formatting output (text, JSON, colors), writing to console and files, performing log rotation, buffering, interacting with the error handler for test context suppression, exporting logs to various formats, searching log files, and integrating logging with report formatters.

## Key Concepts

The tests in this directory cover the various components of the logging system:

- **Core Logging (`logging_test.lua`):** Focuses on the main functionalities provided by `lib/tools/logging/init.lua`:
    - `logging.get_logger()`: Creating named logger instances.
    - Logging Methods (`debug`, `info`, `warn`, `error`, `fatal`): Verifying messages are logged correctly.
    - Level Filtering: Testing that global (`level`) and per-module (`module_levels`) configuration correctly filters messages.
    - Structured Data (`params`): Ensuring the key-value data passed as the second argument is correctly processed and included in output (especially JSON).
    - Output Formatting: Testing text vs. JSON formats, timestamp inclusion, and console colorization based on configuration.
    - File Output & Rotation: Verifying logs are written to configured files (`output_file`, `json_file`), that directories are created (`log_dir`), and that size-based rotation (`max_file_size`, `max_log_files`) functions correctly.
    - Buffering: Testing that buffering (`buffer_size`, `buffer_flush_interval`) works as expected.
    - Filtering: Testing `module_filter` and `module_blacklist` configurations.
    - Test Context Suppression: Verifying interaction with `error_handler` to downgrade log levels for expected errors during tests.

- **Log Export (`export_test.lua`):** Tests the functionality of `lib/tools/logging/export.lua`. It verifies that `export.create_platform_file` can correctly read sample log data and transform it into the specific JSON formats required by external systems like Logstash, Elasticsearch (ECS), Splunk (HEC), Datadog, and Loki. Tests likely assert the structure and key fields of the generated output for each supported platform adapter.

- **Log Search (`search_test.lua`):** Validates `lib/tools/logging/search.lua`. Tests check if `search.search_logs` correctly finds and filters log entries within temporary log files (both text and JSON formats) based on criteria like time range, log level, module name pattern, and message content pattern. It also likely tests `search.get_log_stats`.

- **Formatter Integration (`formatter_integration_test.lua`):** Tests `lib/tools/logging/formatter_integration.lua`. It verifies that `enhance_formatters` successfully adds logging methods (like `log_info`) to mock formatter objects and that `create_test_logger` generates a logger instance which automatically includes test context information (test name, etc.) in its structured log parameters.

## Usage Examples / Patterns (Illustrative Test Snippets)

### Testing Basic Logging and Filtering

```lua
--[[
  Conceptual test verifying level filtering. Requires mocking output.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local logging = require("lib.tools.logging")
local mock_io = { write = function() end } -- Simple mock
local write_spy = firmo.spy.spy_on(mock_io, "write")

describe("Logging Filtering", function()
  before_each(function()
    -- Configure to use mocked output and reset state
    logging.full_reset()
    logging.configure({ level = "INFO", _output_stream = mock_io }) -- Set global level to INFO
    write_spy:reset()
  end)
  after_each(function()
    write_spy:restore()
    logging.configure({ _output_stream = nil }) -- Restore default output
  end)

  it("should log INFO level messages", function()
    local logger = logging.get_logger("Test")
    logger.info("Info message")
    expect(write_spy).to.be.called_once()
    expect(write_spy.calls[1].args[1]).to.match("INFO%s+Test:%s+Info message")
  end)

  it("should NOT log DEBUG level messages when level is INFO", function()
    local logger = logging.get_logger("Test")
    logger.debug("Debug message")
    expect(write_spy.called).to.be_falsey()
  end)

  it("should log DEBUG for a specific module if configured", function()
    logging.configure({ module_levels = { TestDebug = "DEBUG" } })
    local logger = logging.get_logger("TestDebug")
    logger.debug("Module-specific debug message")
    expect(write_spy).to.be.called_once()
    expect(write_spy.calls[1].args[1]).to.match("DEBUG%s+TestDebug:%s+Module%-specific debug message")
  end)
end)

```

### Testing File Rotation

```lua
--[[
  Conceptual test verifying log file rotation. Requires test_helper and filesystem.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local logging = require("lib.tools.logging")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

it("should rotate log files when size limit is exceeded", function()
  test_helper.with_temp_test_directory({}, function(dir_path)
    local log_file_path = fs.join_paths(dir_path, "rotate.log")

    logging.full_reset()
    logging.configure({
      level = "DEBUG",
      output_file = log_file_path, -- Use temp path
      log_dir = "", -- Path is absolute
      max_file_size = 100, -- Very small size limit (100 bytes)
      max_log_files = 2, -- Keep log, log.1, log.2
    })

    local logger = logging.get_logger("RotationTest")
    local long_message = string.rep("X", 60)

    -- Log messages to trigger rotation multiple times
    for i = 1, 10 do
      logger.info(long_message, { index = i })
    end

    -- Wait briefly for potential async flush (if buffer > 0) and check files
    -- socket.sleep(0.1) -- Add if buffering is enabled

    local files, err = error_handler.safe_io_operation(fs.list_files, dir_path)
    expect(err).to_not.exist()

    -- Expect rotate.log, rotate.log.1, rotate.log.2 (check names precisely)
    local file_names = {}
    for _, fpath in ipairs(files) do file_names[fs.get_file_name(fpath)] = true end

    expect(file_names["rotate.log"]).to.be_truthy()
    expect(file_names["rotate.log.1"]).to.be_truthy()
    expect(file_names["rotate.log.2"]).to.be_truthy()
    expect(file_names["rotate.log.3"]).to_not.exist() -- Should have been deleted
  end)
end)
```

### Testing Export Format (Conceptual)

```lua
--[[ Conceptual test for Logstash export format. ]]
it("should format log entries correctly for Logstash", function()
  local export_module = require("lib.tools.logging.export")
  local mock_log_entry = {
    timestamp = 1678886400, -- Example timestamp
    level = logging.LEVELS.WARN,
    levelName = "WARN",
    module = "MyModule",
    message = "Operation timed out",
    params = { duration = 5.1, retry = false },
  }
  local logstash_output, err = export_module.format_for_platform("logstash", { mock_log_entry })

  expect(err).to_not.exist()
  expect(logstash_output).to.be.a("string")

  -- Basic check for JSON structure and key fields
  expect(logstash_output).to.match('^%{') -- Starts with {
  expect(logstash_output).to.match('%}$') -- Ends with }
  expect(logstash_output).to.match('"@timestamp":')
  expect(logstash_output).to.match('"message":"Operation timed out"')
  expect(logstash_output).to.match('"level":"WARN"')
  expect(logstash_output).to.match('"logger_name":"MyModule"')
  expect(logstash_output).to.match('"duration":5.1') -- Check param
end)
```

### Testing Search (Conceptual)

```lua
--[[ Conceptual test for log searching. ]]
it("should find log entries by level", function()
  local search_module = require("lib.tools.logging.search")
  local test_helper = require("lib.tools.test_helper")

  local log_content = "INFO Core: App started\nWARN Network: Timeout\nINFO Core: Shutting down"
  test_helper.with_temp_test_directory({ ["app.log"] = log_content }, function(dir_path)
    local log_path = fs.join_paths(dir_path, "app.log")
    local results, err = search_module.search_logs({ log_file = log_path, level = "WARN" })

    expect(err).to_not.exist()
    expect(results).to.exist()
    expect(results.matched).to.equal(1)
    expect(results.entries[1].levelName).to.equal("WARN")
    expect(results.entries[1].message).to.equal("Timeout")
    expect(results.entries[1].module).to.equal("Network")
  end)
end)
```

## Related Components / Modules

- **Module Under Test:** `lib/tools/logging/knowledge.md` (and `init.lua`, `export.lua`, `search.lua`, `formatter_integration.lua`).
- **Test Files:** `logging_test.lua`, `export_test.lua`, `search_test.lua`, `formatter_integration_test.lua`.
- **Dependencies:**
    - `lib/tools/error_handler/knowledge.md`: Errors generated by `error_handler` are often logged by default. Logging also uses `error_handler.try` internally. Test context suppression relies on `error_handler`.
    - `lib/tools/filesystem/knowledge.md`: Used for file output, directory creation, and log rotation logic. Tests rely on it for setup/verification.
    - `lib/core/central_config/knowledge.md`: The primary mechanism for configuring logging levels, outputs, and other options.
- **Integration Target:** `lib/reporting/formatters/knowledge.md` (Formatters are enhanced by `formatter_integration.lua`).
- **Parent Overview:** `tests/tools/knowledge.md`.

## Best Practices / Critical Rules (Optional)

- **Mock Output/Filesystem:** For tests verifying formatting, filtering, or basic API calls, prefer mocking `io.write` or using in-memory buffers over checking actual console output. For testing file writing or rotation, use `test_helper` to create temporary directories and mock `os.time` if precise control over rotation timing is needed.
- **Test Configurations Thoroughly:** Explicitly test the effects of various configuration settings passed via `logging.configure` or simulated `central_config` values (e.g., different `level`s, `module_levels`, `format` types, `output_file` vs. `nil`, rotation settings, `module_filter`/`blacklist`). Use `logging.reset()` or `full_reset()` in `after_each` to isolate tests.
- **Verify Structured Data (`params`):** Ensure tests confirm that structured data passed in the `params` table is correctly included and formatted in the log output, especially for JSON format and export formatters.
- **Test Test-Context Suppression:** Include specific tests (like those in `expected_error_test.lua`) that verify the log level downgrading logic when `error_handler` indicates an error is expected within a test.

## Troubleshooting / Common Pitfalls (Optional)

- **Log Filtering Not Working:**
    - **Cause:** Incorrect level string/number, incorrect module name used in `get_logger` vs. `module_levels` config, `module_filter`/`blacklist` pattern issue, `silent` flag accidentally enabled, test context suppression active unexpectedly.
    - **Debugging:** Use `logging.debug_config()` (if available) or log the effective configuration within the test. Verify the exact module name passed to `get_logger`. Double-check Lua patterns in filters. Check `error_handler` state (`in_test_run`, `expect_error`).
- **File Rotation Issues:**
    - **Cause:** Incorrect `max_file_size` or `max_log_files` settings. Filesystem permission errors preventing writing, renaming (`.log` to `.log.1`), or deleting old rotated files. Issues within `lib/tools/filesystem`'s rename/delete logic.
    - **Debugging:** Use very small `max_file_size` in tests. Add logging within the rotation logic (`_rotate_log_file` in `init.lua`). Use `test_helper` for temp directories to rule out simple permission issues. Check for errors returned by `filesystem` calls wrapped in `safe_io_operation`.
- **Search/Export Failures:**
    - **Cause:** Input log file doesn't exist or is unreadable. Input log format (text/JSON) doesn't match what the search/export function expects. Search query parameters are incorrect. Export platform name is wrong. Output format/schema is incorrect.
    - **Debugging:** Verify input file path and format. Simplify search queries. Check the output string structure against the expected schema for the target export platform. Add logging to the search/export functions.
- **Mocking Complexity:** Mocking `io.write`, `os.time`, or filesystem functions can introduce its own complexities. Ensure mocks accurately simulate the needed behavior (e.g., return values, side effects) and are properly restored using `stub.restore_all()`.
