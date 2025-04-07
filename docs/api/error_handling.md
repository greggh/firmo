# Error Handling API Reference

## Overview

The error handling system in firmo provides a structured, consistent approach to handling errors throughout the framework. It creates standardized error objects, manages error propagation, integrates with logging, and provides specialized support for testing error conditions.

## Core Error Handler Module

The `error_handler` module is the foundation of firmo's error handling system.

### Importing the Module

```lua
local error_handler = require("lib.tools.error_handler")
```

### Error Categories

The error handler defines standard categories for different types of errors:

```lua
-- Access error categories
local CATEGORY = error_handler.CATEGORY

-- Categories available:
-- CATEGORY.VALIDATION - Input validation errors
-- CATEGORY.IO - File I/O errors
-- CATEGORY.PARSE - Parsing errors
-- CATEGORY.RUNTIME - Runtime errors
-- CATEGORY.TIMEOUT - Timeout errors
-- CATEGORY.MEMORY - Memory-related errors
-- CATEGORY.CONFIGURATION - Configuration errors
-- CATEGORY.UNKNOWN - Unknown errors
-- CATEGORY.TEST_EXPECTED - Errors expected during tests
```

### Error Severity Levels

The error handler provides different severity levels:

```lua
-- Access severity levels
local SEVERITY = error_handler.SEVERITY

-- Severity levels available:
-- SEVERITY.FATAL - Unrecoverable errors that require termination
-- SEVERITY.ERROR - Serious errors but process can continue
-- SEVERITY.WARNING - Warnings that need attention
-- SEVERITY.INFO - Informational messages about error conditions
```

## Creating Error Objects

### Generic Error Creation

```lua
-- Create a generic error object
local error_obj = error_handler.create(
  "Error message",              -- Error message (required)
  error_handler.CATEGORY.IO,    -- Error category (optional)
  error_handler.SEVERITY.ERROR, -- Error severity (optional)
  {                             -- Context table (optional)
    file_path = "/path/to/file",
    operation = "read_file"
  },
  original_error                -- Original error that caused this one (optional)
)
```

### Specialized Error Creators

The module provides convenience functions for common error types:

```lua
-- Validation error (for parameter validation)
local validation_err = error_handler.validation_error(
  "Invalid parameter: value must be a number",
  {parameter = "value", provided_type = "string"}
)

-- I/O error (for file operations)
local io_err = error_handler.io_error(
  "Failed to read file",
  {file_path = "/path/to/file"}
)

-- Runtime error (for errors during execution)
local runtime_err = error_handler.runtime_error(
  "Operation failed",
  {operation = "process_data"},
  original_error  -- Original error that caused this one
)

-- Parse error (for parsing failures)
local parse_err = error_handler.parse_error(
  "Invalid syntax in file",
  {line = 42, file_path = "/path/to/file.lua"}
)

-- Configuration error (for config issues)
local config_err = error_handler.config_error(
  "Missing required configuration",
  {missing_key = "api_key"}
)

-- Timeout error (for operations that time out)
local timeout_err = error_handler.timeout_error(
  "Operation timed out",
  {timeout_ms = 5000, operation = "network_request"}
)

-- Fatal error (for unrecoverable errors)
local fatal_err = error_handler.fatal_error(
  "Critical system failure",
  error_handler.CATEGORY.MEMORY,
  {memory_usage = "100%"}
)

-- Test expected error (for use in tests)
local test_err = error_handler.test_expected_error(
  "Expected test failure",
  {test_case = "should_fail_on_invalid_input"}
)
```

## Error Handling Patterns

### The Try-Catch Pattern

```lua
-- Execute a function and catch any errors
local success, result, err = error_handler.try(function()
  -- Function that might throw an error
  return some_risky_function(arg1, arg2)
end)

if not success then
  -- Handle error (result contains the error object)
  print("Error:", result.message)
  return nil, result
else
  -- Use the result
  return result
end

-- With arguments
local success, result = error_handler.try(function(a, b)
  return a + b
end, 5, 10)
-- result will be 15 if successful
```

### Safe I/O Operations

```lua
-- Execute a file operation safely
local content, err = error_handler.safe_io_operation(
  function() return fs.read_file(file_path) end,
  file_path,
  {operation = "read_config_file"}
)

if not content then
  -- Handle error
  logger.error("Failed to read config", {
    file_path = file_path,
    error = error_handler.format_error(err)
  })
  return nil, err
end

-- With result transformation
local data, err = error_handler.safe_io_operation(
  function() return fs.read_file(config_path) end,
  config_path,
  {operation = "parse_config"},
  function(content) 
    -- Transform successful result
    return json.decode(content) 
  end
)
```

### Asserting Conditions

```lua
-- Assert that a condition is true, or throw an error
error_handler.assert(
  type(value) == "string",
  "Value must be a string",
  error_handler.CATEGORY.VALIDATION,
  {parameter = "value", provided_type = type(value)}
)

-- Assertions can be used as expressions
local name = error_handler.assert(
  config.name,
  "Name is required",
  error_handler.CATEGORY.VALIDATION
)
```

### Throwing Errors

```lua
-- Throw an error with proper logging
error_handler.throw(
  "Operation failed",
  error_handler.CATEGORY.RUNTIME,
  error_handler.SEVERITY.ERROR,
  {operation = "process_data"}
)

-- Rethrow an existing error with additional context
error_handler.rethrow(
  original_error,
  {additional_context = "value"}
)
```

## Testing-Specific Functions

### Test Mode Functions

```lua
-- Set error handler to test mode
error_handler.set_test_mode(true)

-- Check if in test mode
local in_test_mode = error_handler.is_test_mode()

-- Check if test logs are being suppressed
local logs_suppressed = error_handler.is_suppressing_test_logs()
```

### Test Metadata Management

```lua
-- Set metadata for the current test
error_handler.set_current_test_metadata({
  name = "test_function_name",
  expect_error = true  -- Flag that this test expects errors
})

-- Get current test metadata
local metadata = error_handler.get_current_test_metadata()

-- Check if current test expects errors
local expects_errors = error_handler.current_test_expects_errors()
```

### Expected Error Management

```lua
-- Check if an error is an expected test error
local is_expected = error_handler.is_expected_test_error(err)

-- Get all expected errors captured during tests
local expected_errors = error_handler.get_expected_test_errors()

-- Clear the collection of expected errors
error_handler.clear_expected_test_errors()
```

## Error Object Structure

Error objects created by the error handler have a standardized structure:

```lua
local error_obj = {
  -- Core error information
  message = "Error message",                -- Human-readable error message
  category = error_handler.CATEGORY.IO,     -- Error category
  severity = error_handler.SEVERITY.ERROR,  -- Error severity
  
  -- Context and tracking
  timestamp = 1680000000,                   -- When the error occurred (os.time())
  context = {                               -- Optional error context
    file_path = "/path/to/file",
    operation = "read_file" 
  },
  
  -- Source location
  source_file = "module.lua",               -- File where error occurred
  source_line = 42,                         -- Line number where error occurred
  
  -- Debug information
  traceback = "stack trace...",             -- Stack trace (if enabled)
  cause = original_error                    -- Original error that caused this one
}
```

## Error Formatting Functions

```lua
-- Format an error object as a string (basic)
local error_str = error_handler.format_error(error_obj)

-- Format with traceback
local detailed_error = error_handler.format_error(error_obj, true)
```

## Configuration Functions

```lua
-- Configure the error handler module
error_handler.configure({
  use_assertions = true,         -- Use Lua assertions for validation errors
  verbose = false,               -- Verbose error messages
  trace_errors = true,           -- Include traceback information
  log_all_errors = true,         -- Log all errors through the logging system
  exit_on_fatal = false,         -- Exit the process on fatal errors
  capture_backtraces = true,     -- Capture stack traces for errors
  in_test_run = false,           -- Are we currently running tests
  suppress_test_assertions = true -- Suppress validation errors in tests
})

-- Configure from central_config
error_handler.configure_from_config()
```

## Utility Functions

```lua
-- Check if a value is an error object
local is_error = error_handler.is_error(value)

-- Log an error using the logging system
error_handler.log_error(error_obj)
```

## Integration with Testing Framework

The error handler integrates with firmo's testing system through:

1. **Test Mode Detection**: Tests can be marked to expect errors using `{ expect_error = true }`
2. **Error Suppression**: Expected errors are properly suppressed in test output
3. **Error Verification**: Tests can verify error properties through standard assertions

For detailed test integration, see the Error Handling Guide and Error Testing Best Practices documentation.

## Error Handler Behavior by Default

The default error handler configuration:

- Creates structured error objects with category, context, and severity
- Captures file and line information for errors
- Captures stack traces for detailed debugging
- Integrates with the logging system
- Suppresses expected errors during tests
- Detects the test environment automatically
- Works with central configuration system

## Error Handling Best Practices

1. Always use structured error objects with proper categorization
2. Add detailed context to error objects for better diagnostics
3. Validate input parameters at the beginning of functions
4. Use try/catch for risky operations (especially external calls)
5. Propagate errors with additional context rather than absorbing them
6. Handle all error cases explicitly rather than assuming success
7. Use the appropriate specialized error creator for each error type
8. Log errors with appropriate severity levels

For more detailed guidance on error handling patterns, see the Error Handling Guide.