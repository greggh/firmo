# Error Handler Configuration

This document describes the comprehensive configuration options for the firmo error handling system, which standardizes error creation, reporting, and handling across the framework.

## Overview

The error handler module provides a robust system for structured error handling with support for:

- Standardized error objects with categories and severity levels
- Contextual error information with detailed metadata
- Error suppression for test environments
- Integrated logging with configurable verbosity
- Stack trace capture and formatting
- Safe operation wrappers for error-prone code
- Integration with the central configuration system

## Configuration Options

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `use_assertions` | boolean | `true` | Use Lua assertions for validation errors. |
| `verbose` | boolean | `false` | Enable verbose error messages with additional context. |
| `trace_errors` | boolean | `true` | Include traceback information in error objects. |
| `log_all_errors` | boolean | `true` | Log all errors through the logging system. |
| `exit_on_fatal` | boolean | `false` | Exit the process when fatal errors occur. |
| `capture_backtraces` | boolean | `true` | Capture stack traces for errors. |

### Test-Related Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `in_test_run` | boolean | `false` | Indicates if code is running in a test environment. |
| `suppress_test_assertions` | boolean | `true` | Suppress expected validation errors in tests. |
| `suppress_all_logging_in_tests` | boolean | `true` | Suppress all console output during tests. |

## Configuration in .firmo-config.lua

You can configure the error handler in your `.firmo-config.lua` file:

```lua
return {
  -- Error handler configuration
  error_handler = {
    -- Core behavior
    use_assertions = true,
    verbose = true,                    -- Show verbose error messages
    trace_errors = true,               -- Include stack traces
    log_all_errors = true,             -- Log all errors

    -- Error handling severity
    exit_on_fatal = false,             -- Don't exit on fatal errors
    capture_backtraces = true,         -- Capture stack traces

    -- Test behavior
    suppress_test_assertions = true,   -- Suppress expected errors in tests
    suppress_all_logging_in_tests = false  -- Show error logs in tests
  }
}
```

## Programmatic Configuration

You can also configure the error handler programmatically:

```lua
local error_handler = require("lib.tools.error_handler")
-- Core configuration
error_handler.configure({
  verbose = true,
  trace_errors = true,
  log_all_errors = true
})
-- Test mode configuration
error_handler.set_test_mode(true)
-- With specific test metadata
error_handler.set_current_test_metadata({
  name = "test_example",
  expect_error = true,
  file = "test_file.lua"
})
```

## Error Categories and Severity

The error handler uses standardized categories and severity levels:

### Error Categories

```lua
-- Main error categories
local CATEGORY = error_handler.CATEGORY
-- Available categories
CATEGORY.VALIDATION  -- Input validation errors
CATEGORY.IO          -- File I/O errors
CATEGORY.PARSE       -- Parsing errors
CATEGORY.RUNTIME     -- Runtime errors
CATEGORY.TIMEOUT     -- Timeout errors
CATEGORY.MEMORY      -- Memory-related errors
CATEGORY.CONFIG      -- Configuration errors
CATEGORY.UNKNOWN     -- Unknown errors
CATEGORY.TEST_EXPECTED -- Errors expected during tests
```

### Error Severity Levels

```lua
-- Severity levels
local SEVERITY = error_handler.SEVERITY
-- Available severity levels
SEVERITY.FATAL    -- Unrecoverable errors requiring process termination
SEVERITY.ERROR    -- Serious errors that might allow the process to continue
SEVERITY.WARNING  -- Warnings that need attention but don't stop execution
SEVERITY.INFO     -- Informational messages about error conditions
```

## Test Mode Configuration

Test mode changes error handling behavior to support testing error conditions:

```lua
-- Enable test mode
error_handler.set_test_mode(true)
-- Configure test-specific behavior
error_handler.configure({
  -- Suppress expected validation errors in tests
  suppress_test_assertions = true,

  -- Suppress all console output in tests
  suppress_all_logging_in_tests = true
})
-- Set metadata for the current test
error_handler.set_current_test_metadata({
  name = "test_validation_errors",
  expect_error = true,  -- This test expects errors to occur
  category = error_handler.CATEGORY.VALIDATION  -- Specific error category expected
})
```

## Error Logging Configuration

Control how errors are logged:

```lua
-- Enable verbose logging
error_handler.configure({
  verbose = true,
  log_all_errors = true
})
-- Disable verbose logging
error_handler.configure({
  verbose = false
})
-- Disable error logging completely (only for special cases)
error_handler.configure({
  log_all_errors = false
})
```

## Stack Trace Configuration

Control stack trace capture and display:

```lua
-- Enable stack trace capture and display
error_handler.configure({
  trace_errors = true,
  capture_backtraces = true
})
-- Disable stack traces for performance (rarely needed)
error_handler.configure({
  trace_errors = false,
  capture_backtraces = false
})
```

## Integration with Test Runner

The error handler integrates with Firmo's test runner:

```lua
-- In test runner
local error_handler = require("lib.tools.error_handler")
-- Before running tests
error_handler.set_test_mode(true)
-- For each test
error_handler.set_current_test_metadata({
  name = test.name,
  expect_error = test.expect_error,
  category = test.expected_category
})
-- After running tests
error_handler.set_test_mode(false)
error_handler.set_current_test_metadata(nil)
```

## Advanced Usage

### Custom Error Categories

Add your own error categories for specific domains:

```lua
-- Add custom error categories
error_handler.CATEGORY.DATABASE = "DATABASE"
error_handler.CATEGORY.NETWORK = "NETWORK"
error_handler.CATEGORY.AUTHENTICATION = "AUTHENTICATION"
-- Create domain-specific errors
local function database_error(message, context)
  return error_handler.create(
    message,
    error_handler.CATEGORY.DATABASE,
    error_handler.SEVERITY.ERROR,
    context
  )
end
```

### Error Suppression Patterns

Configure error suppression for specific test scenarios:

```lua
-- Configure test-specific error handling
error_handler.set_current_test_metadata({
  name = "test_timeout_handling",
  expect_error = true,
  category = error_handler.CATEGORY.TIMEOUT,
  suppress_pattern = "Connection timeout",
  suppress_categories = {
    error_handler.CATEGORY.TIMEOUT,
    error_handler.CATEGORY.NETWORK
  }
})
```

### Fatal Error Handling

Configure how fatal errors are handled:

```lua
-- Configure fatal error handling
error_handler.configure({
  exit_on_fatal = true  -- Process will exit on fatal errors
})
-- Create a fatal error
local err = error_handler.create(
  "Unrecoverable database corruption",
  error_handler.CATEGORY.DATABASE,
  error_handler.SEVERITY.FATAL,
  { database = "users.db" }
)
-- Will exit the process if exit_on_fatal is true
error_handler.handle_error(err)
```

## Best Practices

### Standardized Error Objects

Create standardized error objects with proper context:

```lua
-- Create a validation error
local err = error_handler.validation_error(
  "Invalid email format",
  {
    value = user_input,
    field = "email",
    pattern = email_pattern
  }
)
-- Create an I/O error
local err = error_handler.io_error(
  "Failed to write to log file",
  {
    file = log_file_path,
    operation = "write",
    mode = "append"
  }
)
```

### Try/Catch Pattern

Use the try/catch pattern for operations that might fail:

```lua
local success, result, err = error_handler.try(function()
  return process_data(input)
end)
if not success then
  -- Handle the error
  logger.error("Failed to process data", {
    error = error_handler.format_error(result)
  })
  -- Take recovery action
  return fallback_value
end
-- Use the result
return result
```

### Safe I/O Operations

Use safe I/O operations with consistent error handling:

```lua
local content, err = error_handler.safe_io_operation(
  function() 
    return fs.read_file(file_path)
  end,
  file_path,
  { operation = "read_config_file" }
)
if not content then
  logger.error("Failed to read configuration", {
    error = error_handler.format_error(err)
  })
  return nil, err
end
```

### Assertion Pattern

Use the assertion pattern for precondition checking:

```lua
-- Validate input parameters
error_handler.assert(type(value) == "string", 
  "Value must be a string",
  error_handler.CATEGORY.VALIDATION,
  { provided_type = type(value) }
)
-- Check required fields
error_handler.assert(config.api_key, 
  "API key is required",
  error_handler.CATEGORY.CONFIG,
  { config_file = config_file_path }
)
```

## Troubleshooting

### Common Issues

1. **Too many error logs**:
   - Set `verbose = false` to reduce log verbosity
   - Enable `suppress_test_assertions` for test environments
   - Use `error_handler.set_test_mode(true)` in test runners
2. **Missing stack traces**:
   - Ensure `trace_errors = true` and `capture_backtraces = true`
   - Check that the error is being created through the error handler
   - Make sure errors aren't being lost in transit between functions
3. **Unexpected assertions in tests**:
   - Set `expect_error = true` in test metadata
   - Ensure test metadata is set before the test runs
   - Use the try/catch pattern for operations expected to fail
4. **Inconsistent error handling**:
   - Standardize on error_handler.create() for all errors
   - Use specialized creators like validation_error() and io_error()
   - Return nil, error instead of throwing errors directly

## Example Configuration Files

### Development Configuration

```lua
-- .firmo-config.development.lua
return {
  error_handler = {
    use_assertions = true,
    verbose = true,                 -- Verbose for debugging
    trace_errors = true,
    log_all_errors = true,
    exit_on_fatal = false,          -- Don't exit for development
    capture_backtraces = true,
    suppress_test_assertions = true,
    suppress_all_logging_in_tests = false  -- Show logs during tests
  }
}
```

### Production Test Configuration

```lua
-- .firmo-config.production.lua
return {
  error_handler = {
    use_assertions = true,
    verbose = false,                -- Less verbose for production
    trace_errors = true,
    log_all_errors = true,
    exit_on_fatal = true,           -- Exit on fatal errors in production
    capture_backtraces = true,
    suppress_test_assertions = true,
    suppress_all_logging_in_tests = true  -- Suppress logs in automated tests
  }
}
```

### CI Configuration

```lua
-- .firmo-config.ci.lua
return {
  error_handler = {
    use_assertions = true,
    verbose = true,                 -- Verbose for CI debugging
    trace_errors = true,
    log_all_errors = true,
    exit_on_fatal = false,
    capture_backtraces = true,
    suppress_test_assertions = true,
    suppress_all_logging_in_tests = false  -- Show logs for CI debugging
  }
}
```

These configuration options give you complete control over error handling behavior, allowing you to balance detailed error information with performance considerations across different environments.
