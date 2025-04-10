# Logging Guide

This guide explains how to use the firmo logging system effectively in your projects, including best practices and advanced features.

## Overview

The firmo testing framework includes a comprehensive centralized logging system that provides:

- Multiple log levels (FATAL, ERROR, WARN, INFO, DEBUG, TRACE)
- Module-specific log configuration
- Structured logging with contextual parameters
- Console output with timestamps and colors
- File output with automatic log rotation
- JSON structured logging for machine analysis
- Error handling integration with test error suppression
- Performance optimization features
- Integration with the central configuration system

## Getting Started

### Basic Usage

To use the logging system in your module:

```lua
-- Import the logging module
local logging = require("lib.tools.logging")

-- Create a logger for your module
local logger = logging.get_logger("my_module")

-- Configure logging from global config (recommended)
logging.configure_from_config("my_module")

-- Use the logger at different levels
logger.info("Initializing my_module...")
logger.debug("Configuration loaded with 5 options")
logger.error("Failed to load file: my_file.lua")
```

### Log Levels

The logging system supports six log levels, ordered by priority:

| Level | Value | Description | Usage |
|-------|-------|-------------|-------|
| FATAL | 0 | Severe errors | Application cannot continue, immediate attention required |
| ERROR | 1 | Critical errors | Operation prevented from completing successfully |
| WARN | 2 | Warnings | Concerning but non-critical issues |
| INFO | 3 | Information | Important state changes, normal operations |
| DEBUG | 4 | Debug information | Detailed information for troubleshooting |
| TRACE | 5 | Trace | Extremely detailed execution information |

Messages are only displayed if their level is less than or equal to the configured level. For example, if the log level is set to INFO (3), then FATAL, ERROR, WARN, and INFO messages will be displayed, but DEBUG and TRACE messages will be hidden.

## Configuration Methods

### 1. Using Central Configuration (Recommended)

The recommended approach is to use the central configuration system through the `.firmo-config.lua` file:

```lua
-- In .firmo-config.lua
return {
  -- Other configuration...
  
  logging = {
    level = 3,  -- Global log level (INFO)
    timestamps = true,
    use_colors = true,
    output_file = "my_project.log",
    log_dir = "logs",
    max_file_size = 10 * 1024 * 1024,  -- 10MB
    max_log_files = 5,
    
    -- Module-specific log levels
    module_levels = {
      coverage = 4,   -- DEBUG level for coverage module
      parser = 2,     -- WARN level for parser
      my_module = 3   -- INFO level for my_module
    }
  }
}
```

Then in your module:

```lua
local logging = require("lib.tools.logging")
local logger = logging.get_logger("my_module")
logging.configure_from_config("my_module")
```

### 2. Command-Line Options

You can configure log levels based on command-line options:

```lua
local logging = require("lib.tools.logging")
local logger = logging.get_logger("my_module")

-- Parse command-line options
local options = parse_args(arg)

-- Configure logging based on options
logging.configure_from_options("my_module", options)
```

This is useful for temporary debugging:

```bash
lua my_script.lua --debug    # Sets DEBUG level
lua my_script.lua --verbose  # Sets TRACE level
```

### 3. Direct Configuration

You can also configure the logging system directly:

```lua
local logging = require("lib.tools.logging")

-- Global configuration
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "my_log.log",
  log_dir = "logs"
})

-- Module-specific configuration
logging.set_module_level("my_module", logging.LEVELS.TRACE)
```

## Structured Logging

### Parameter-Based Logging

Always separate messages from contextual data using the parameters table:

```lua
-- Bad: Variable data embedded in message
logger.info("Processed file " .. filename .. " with " .. count .. " lines")

-- Good: Variable data as separate parameters
logger.info("Processed file", {filename = filename, line_count = count})
```

The parameters will appear in:
- Text logs as key-value pairs in parentheses
- JSON logs as a nested object structure

### Parameter Naming Conventions

- Use snake_case for parameter names
- Be specific (use `operation_duration_ms` not just `time`)
- Include units in names when applicable (`size_bytes`, `duration_ms`)
- Use consistent names for the same data across different messages
- Follow these common naming patterns:
  - IDs: `user_id`, `file_id`, `transaction_id`
  - Names: `filename`, `function_name`, `module_name`
  - Counts: `line_count`, `error_count`, `total_files`
  - Metrics: `duration_ms`, `size_bytes`, `memory_usage_mb`
  - Errors: `error`, `error_message`, `error_code`

### JSON Structured Logging

For machine processing, the logging system can write logs in JSON format while keeping console output human-readable:

```lua
logging.configure({
  format = "text",              -- Console format
  json_file = "app.json",       -- Separate JSON log
  output_file = "app.log"       -- Text log
})
```

The JSON log file format is one JSON object per line (newline-delimited JSON):

```
{"timestamp":"2025-03-26T14:32:45","level":"INFO","module":"app","message":"Application started"}
{"timestamp":"2025-03-26T14:32:46","level":"ERROR","module":"database","message":"Connection failed","params":{"host":"db.example.com","retries":3}}
```

## Log File Management

### Log Directory

By default, log files are stored in the `logs` directory. This directory is automatically created if it doesn't exist.

### Log Rotation

The logging system automatically rotates log files when they reach a specified size:

1. When `my_log.log` reaches `max_file_size`, it's renamed to `my_log.log.1`
2. If `my_log.log.1` already exists, it's renamed to `my_log.log.2`, and so on
3. The system keeps up to `max_log_files` rotated logs

This prevents log files from growing too large while preserving history.

Configuration options:

```lua
logging.configure({
  output_file = "my_log.log",
  log_dir = "logs",
  max_file_size = 10 * 1024 * 1024,  -- 10MB
  max_log_files = 5                  -- Keep 5 rotated files
})
```

## Error Handling Integration

### Expected Error Suppression

In tests that use the `{ expect_error = true }` flag, expected errors are automatically handled specially:

1. ERROR and WARN level messages are downgraded to DEBUG level
2. Messages are prefixed with [EXPECTED] to clearly mark them
3. If DEBUG logging is disabled, these messages won't appear at all

This provides a cleaner test output while still making the information available when needed.

```lua
it("should handle division by zero", { expect_error = true }, function()
  -- This error will be downgraded to DEBUG level with [EXPECTED] prefix
  local result, err = calculator.divide(10, 0)
  
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("Division by zero")
})
```

### Error History Access

All expected errors can be accessed programmatically:

```lua
-- After running tests with expected errors
local error_handler = require("lib.tools.error_handler")
local expected_errors = error_handler.get_expected_test_errors()

-- Process the errors for diagnostics
for i, err in ipairs(expected_errors) do
  print(string.format("[%s] From module %s: %s", 
    os.date("%H:%M:%S", err.timestamp),
    err.module or "unknown", 
    err.message))
end

-- Clear expected errors when done
error_handler.clear_expected_test_errors()
```

## Performance Optimization

### Check Level Before Expensive Operations

To avoid performance overhead when generating complex debug messages:

```lua
if logger.is_debug_enabled() then
  -- Only perform expensive operations if debug logging is enabled
  local details = gather_expensive_debug_details()
  logger.debug("Debug details", details)
end
```

### Practical Example

```lua
function process_file(file_path)
  logger.info("Processing file", {path = file_path})
  
  -- Only gather detailed stats if debug logging is enabled
  if logger.is_debug_enabled() then
    local stats = fs.get_file_stats(file_path)
    logger.debug("File stats", {
      size_bytes = stats.size,
      modified = stats.mtime,
      permissions = stats.mode
    })
  end
  
  -- Do processing...
  
  logger.info("Finished processing file", {path = file_path})
end
```

### Using Buffering for High-Volume Logging

For scenarios with many log events in a short time, enable buffering:

```lua
logging.configure({
  buffering = true,             -- Enable buffering
  buffer_size = 100,            -- Buffer up to 100 messages
  buffer_flush_interval = 5000, -- Auto-flush every 5 seconds
  buffer_flush_on_exit = true   -- Ensure logs are written at exit
})
```

With buffering enabled, messages aren't written immediately but are held in memory until:
- The buffer reaches `buffer_size` entries
- The `buffer_flush_interval` time elapses
- `logging.flush()` is called manually
- The application exits (if `buffer_flush_on_exit` is true)

## Integration with Test System

### Test-Specific Loggers

Create context-aware loggers for tests:

```lua
local formatter_integration = require("lib.tools.logging.formatter_integration")

-- Create a test-specific logger with context
local test_logger = formatter_integration.create_test_logger(
  "Calculator Test",
  { component = "math", type = "unit" }
)

-- Use in test
describe("Calculator", function()
  -- Log test initialization
  test_logger.info("Initializing calculator test")
  
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
end)
end)
```

This creates logs with rich context:
- `[INFO] [test.Calculator_Test] Initializing calculator test (component=math, type=unit)`
- `[DEBUG] [test.Calculator_Test] Testing addition (component=math, type=unit, step=Addition Test, a=2, b=3, expected=5)`

### Test Error Visibility

When writing tests that expect errors, the logging system has special behavior to help with debugging:

1. **Debug override for expected errors**: When a test uses the `{ expect_error = true }` flag, DEBUG level messages are shown for that test even if the module's configured log level is higher (e.g., WARN).

```lua
-- This test will show DEBUG messages even if the module is configured at WARN level
it("handles file operation errors", { expect_error = true }, function()
  -- Test code that expects errors
  -- DEBUG messages will be visible during this test
end)
```

2. **Selective use of expect_error**: Only use `expect_error = true` when you need visibility into debug messages during error conditions:

```lua
-- Good: Use expect_error when you need DEBUG visibility into error handling
it("recovers from database corruption", { expect_error = true }, function()
  -- Complex error recovery that needs DEBUG message visibility
end)

-- Better: For simple error expectations, use expect_error() helper instead
it("validates input parameters", function()
  local err = test_helper.expect_error(function()
    process_input(nil)  -- Should throw error
  end)
  expect(err).to.exist()
  -- No DEBUG message flooding here
end)
```

3. **Log level precedence**: The precedence for determining the effective log level is:
   - Debug mode flag (`--debug` command line option)
   - Test expect_error flag (temporarily lowers threshold for specific tests)
   - Module-specific configured level
   - Global default log level

4. **Real-world examples from the coverage module**:

```lua
-- Coverage initialization errors need detailed DEBUG output
-- The expect_error flag temporarily enables DEBUG messages
it("handles initialization errors gracefully", { expect_error = true }, function()
  -- Mock debug.sethook to generate an error
  local original_sethook = debug.sethook
  debug.sethook = function()
    error("Simulated sethook error")
  end
  
  -- This will fail, but all DEBUG messages will be visible
  local err = test_helper.expect_error(function()
    coverage.init()
  end)
  
  expect(err).to.exist("Should get initialization error")
  
  -- Restore original function
  debug.sethook = original_sethook
end)

-- Pattern compilation doesn't need DEBUG visibility
-- Use regular expect_error() without the flag
it("handles invalid include patterns", function()
  local err = test_helper.expect_error(function()
    central_config.set("coverage", {
      include = {"[invalid regexp"}
    })
    coverage.init()
  end)
  
  if err then
    expect(err.message).to.match("pattern")
  end
end)
```

This behavior ensures that when testing error conditions, you have appropriate visibility into the system's internal state without modifying the code or changing configuration.

## Troubleshooting Logging Issues

### Common Problems and Solutions

1. **Too many DEBUG messages in test output**

   *Problem*: Tests using `{ expect_error = true }` show excessive DEBUG messages.
   
   *Solution*: Only use `expect_error = true` for tests that need detailed error diagnostics. For simple error checks, use the helper instead:
   
   ```lua
   -- BEFORE: Shows all DEBUG messages
   it("validates input", { expect_error = true }, function()
     local result = validate(bad_input)
   end)
   
   -- AFTER: Only shows proper log levels
   it("validates input", function()
     local err = test_helper.expect_error(function()
       validate(bad_input)
     end)
     expect(err).to.exist()
   end)
   ```

2. **Coverage module generating unexpected debug output**

   *Problem*: Even with `coverage = 2` in config, some tests still show DEBUG (level 4) messages.
   
   *Solution*: Check for `expect_error = true` in test definitions:
   
   ```lua
   -- In .firmo-config.lua
   logging = {
     level = 3, -- INFO level globally
     modules = {
       coverage = 2, -- WARN level for coverage
     }
   }
   
   -- In tests/coverage/coverage_test.lua
   -- This test will still show DEBUG messages despite config
   it("handles file errors", { expect_error = true }, function()
     -- Test code...
   end)
   ```

3. **Inconsistent log levels across environments**

   *Problem*: Log levels change when running in different environments.
   
   *Solution*: Explicitly configure logging at the start of execution:
   
   ```lua
   local central_config = require("lib.core.central_config")
   local logging = require("lib.tools.logging")
   
   -- Set explicit configuration
   central_config.set("logging.modules.coverage", 2) -- WARN
   logging.configure_from_config()
   ```

4. **Log messages missing during error conditions**

   *Problem*: Important diagnostic messages aren't visible during failures.
   
   *Solution*: Use the `debug_temporary` helper for specific code sections:
   
   ```lua
   local logging = require("lib.tools.logging")
   
   -- Temporarily enable debug logs for a specific section
   logging.debug_temporary("coverage", function()
     -- Code that needs diagnostic visibility
     complex_operation()
   end)
   ```

### Debug Mode Override

The `--debug` command-line flag will force all logs to be visible, regardless of configuration:

```bash
lua test.lua --debug tests/coverage/
```

This is useful for troubleshooting but can generate a large volume of output.

## Best Practices
1. **Use module-specific loggers**: Create a separate logger for each module
   ```lua
   local logger = logging.get_logger("module_name")
   ```

2. **Use configure_from_config**: Let global config control log levels
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

6. **Choose appropriate log levels**:
   - FATAL: System cannot continue, requires immediate action
   - ERROR: Operation failed completely 
   - WARN: Concerning situation, but operation continued
   - INFO: Normal operational events users should know about
   - DEBUG: Information useful to developers during debugging
   - TRACE: Very detailed internal state information

7. **Use clear, action-oriented messages**:
   ```lua
   -- Good message verbs
   logger.info("Starting data import")
   logger.info("Completed data import")
   logger.error("Failed to connect to database") 
   logger.warn("Retrying failed operation")
   ```

8. **Include operation names and IDs for correlation**:
   ```lua
   logger.info("Processing user request", {
     request_id = "req-12345",
     operation = "user_registration",
     user_id = user.id
   })
   ```

9. **Log state transitions**:
   ```lua
   logger.info("Changed processing state", {
     previous_state = "validating",
     new_state = "processing",
     item_id = item.id
   })
   ```

10. **Use consistent parameter naming across modules**:
    ```lua
    -- All modules use the same parameter names for similar concepts
    logger.info("Database query completed", {duration_ms = time_taken})
    logger.info("API request completed", {duration_ms = time_taken})
    ```

## See Also

- [Coverage System Guide](./coverage.md) - Explains how coverage interacts with logging
- [Central Configuration](./central_config.md) - Configuration system used for logging
- [Error Handling](./error_handling.md) - Error integration with logging system
- [Test Helper](./test_helper.md) - Utilities for test error handling

## Message Style Guide

### Do

- Write concise, clear messages explaining what happened
- Use active voice: "Found 5 files" (not "5 files were found")
- Use consistent terminology across the codebase
- Write full sentences with proper capitalization
- Include the operation being performed

### Don't

- Include formatting characters (dashes, indentation, asterisks)
- Include variable data in the message text
- Use abbreviations unless well-established
- Include timestamps or module names (the logger adds these)
- Include line breaks or multi-line messages

### Common Message Templates

#### Operations

- Starting: "Starting [operation]"
- Completion: "Completed [operation]"
- Failure: "Failed to [operation]"

#### Resources

- Creation: "Created [resource]"
- Update: "Updated [resource]"
- Deletion: "Deleted [resource]"
- Not Found: "Could not find [resource]"

### Examples

```lua
-- Operation start/end
logger.info("Starting test execution", {test_count = 42, tag = "integration"})
logger.info("Completed test execution", {passed = 40, failed = 2, duration_ms = 1500})

-- Resource operations
logger.debug("Created temporary file", {filename = "/tmp/test123.lua"})
logger.debug("Deleted temporary file", {filename = "/tmp/test123.lua"})

-- Warnings
logger.warn("Missing configuration value", {key = "timeout", using_default = true})
logger.warn("Retrying failed operation", {attempt = 3, max_attempts = 5})

-- Errors
logger.error("Failed to open file", {filename = "/missing/file.lua", error = err_msg})
logger.error("Database query failed", {query_id = "user_lookup", error_code = 1045})

-- Metrics
logger.info("Performance metrics", {
  operation = "parse_file",
  filename = "large_file.lua",
  duration_ms = 234,
  memory_used_kb = 1500
})
```