# Error Handling Guide


## Introduction


Effective error handling is essential for creating robust, maintainable code. This guide provides a comprehensive overview of firmo's error handling system, explaining key concepts, patterns, and best practices to use throughout your codebase.

## Key Concepts


### Structured Error Objects


The foundation of firmo's error handling is the structured error object. Unlike simple string errors, structured error objects contain rich information:


- A human-readable error message
- A categorical classification of the error
- Severity level
- Contextual data specific to the error
- Source file and line information
- Stack trace (when enabled)
- Original causing error (for chained errors)

This structure makes errors more informative, easier to debug, and enables programmatic handling of specific error types.

### Standard Error Return Pattern


Firmo uses the Lua convention of returning `nil` plus an error object for functions that fail:


```lua
-- Function that might fail
function read_config(file_path)
  if not file_path then
    return nil, error_handler.validation_error(
      "File path is required",
      {parameter = "file_path"}
    )
  end

  -- Attempt to read file
  local content, err = error_handler.safe_io_operation(
    function() return fs.read_file(file_path) end,
    file_path,
    {operation = "read_config"}
  )

  if not content then
    return nil, err
  end

  -- Continue processing...
  return parsed_content
end
-- Calling code checks for errors
local config, err = read_config("/path/to/config.lua")
if not config then
  -- Handle error
  logger.error("Failed to load configuration", {
    error = err.message,
    category = err.category
  })
  return nil, err
end
```


This pattern provides consistent error handling throughout your codebase.

### Error Handling Integration


The error handling system integrates with:


1. **Logging System**: Automatically logs errors with appropriate severity
2. **Test Framework**: Suppresses expected errors during tests
3. **Central Configuration**: Configurable through the central config system


## Common Error Handling Patterns


### 1. Input Validation


Start functions with input validation to catch issues early:


```lua
function process_user_data(user)
  -- Validate required parameters
  if not user then
    return nil, error_handler.validation_error(
      "User object is required",
      {parameter = "user", operation = "process_user_data"}
    )
  end

  -- Validate parameter types
  if not user.name or type(user.name) ~= "string" then
    return nil, error_handler.validation_error(
      "User name must be a string",
      {parameter = "user.name", operation = "process_user_data"}
    )
  end

  -- Continue with function implementation...
end
```



### 2. Try-Catch Pattern


Use the try-catch pattern for operations that might throw errors:


```lua
-- Execute potentially risky code
local success, result, err = error_handler.try(function()
  return json.decode(content)
end)
if not success then
  -- Handle error (result contains the error object)
  logger.error("Failed to parse JSON", {
    error = error_handler.format_error(result)
  })
  return nil, result
end
-- Use the result
return process_data(result)
```



### 3. Safe I/O Operations


For file operations, use the specialized I/O error handling:


```lua
-- Read a file safely
local content, err = error_handler.safe_io_operation(
  function() return fs.read_file(file_path) end,
  file_path,
  {operation = "read_config"}
)
if not content then
  logger.error("Failed to read file", {
    file_path = file_path,
    error = err.message
  })
  return nil, err
end
```



### 4. Error Propagation


When calling other functions that might fail, propagate errors with additional context:


```lua
function process_directory(dir_path)
  -- Call another function that might fail
  local files, err = list_files(dir_path)
  if not files then
    -- Add context and propagate
    logger.error("Failed to process directory", {
      directory = dir_path,
      error = err.message
    })
    return nil, err
  end

  -- Process files...
  return processed_files
end
```



### 5. Resource Management with Error Handling


When working with resources that need cleanup, use this pattern:


```lua
function process_file_safely(file_path)
  -- Resource tracking
  local resources = {}

  -- Create temporary file with error handling
  local temp_path, temp_err = error_handler.try(function()
    local path = create_temp_file()
    table.insert(resources, path) -- Track for cleanup
    return path
  end)

  if not temp_path then
    -- No cleanup needed yet
    return nil, temp_err
  end

  -- Try operations that might fail
  local success, result, err = error_handler.try(function()
    -- Perform operations...
    return process_result
  end)

  -- Always clean up resources
  local cleanup_failed = false
  for _, resource in ipairs(resources) do
    local cleanup_success = error_handler.try(function()
      cleanup_resource(resource)
    end)

    if not cleanup_success then
      cleanup_failed = true
    end
  end

  -- Log cleanup issues but prioritize original error
  if cleanup_failed and logger then
    logger.warn("Resource cleanup failed")
  end

  -- Return the original result/error
  if not success then
    return nil, err
  end

  return result
end
```



## Testing Error Conditions


A critical part of error handling is verifying that errors work correctly. Firmo provides specialized patterns for testing error conditions.

### 1. Using the expect_error Flag


When a test specifically validates error behavior, add the `expect_error` flag:


```lua
it("should reject invalid input", { expect_error = true }, function()
  -- This error won't cause the test to fail
  local result, err = function_that_returns_error()

  -- Make assertions about the error
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
  expect(err.message).to.match("invalid input")
end)
```


The `expect_error` flag tells the test runner:


- Don't mark the test as failed if errors occur
- Suppress error messages in normal output
- Allow assertions about the errors


### 2. Testing Functions that Throw Errors


For functions that throw errors directly (not returning nil, error):


```lua
it("should throw on invalid config", { expect_error = true }, function()
  -- Using test_helper.expect_error to verify the error message
  local err = test_helper.expect_error(function()
    parse_config(nil)
  end, "Config must be a string")

  expect(err).to.exist()
  expect(err.message).to.match("Config must be a string")
end)
```



### 3. Testing Functions with Complex Error Paths


For more detailed error testing:


```lua
it("should handle complex error conditions", { expect_error = true }, function()
  -- Using test_helper.with_error_capture for detailed inspection
  local result, err = test_helper.with_error_capture(function()
    return process_complicated_operation()
  end)()

  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
  expect(err.context.operation).to.equal("process_complicated_operation")
})
```



### 4. Testing Different Error Return Patterns


Some functions return `nil, error` while others return `false`:


```lua
it("handles both error patterns", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return function_that_might_return_false_or_nil_error()
  end)()

  if result == nil then
    -- nil, error pattern
    expect(err).to.exist()
    expect(err.message).to.match("expected pattern")
  else
    -- false pattern (no error object)
    expect(result).to.equal(false)
  end
end)
```



## Error Suppression in Tests


The firmo error handling system intelligently suppresses expected errors during tests:


1. **Automatic Downgrading**: ERROR/WARNING logs are downgraded to DEBUG level in tests with `expect_error = true`
2. **Error Marking**: Adds `[EXPECTED]` prefix to suppressed errors in debug mode
3. **Error History**: Maintains a global registry of expected errors for programmatic access


### Viewing Suppressed Errors


To see suppressed errors during debugging:


```bash

# Run tests with debug flag


lua test.lua --debug tests/my_module_test.lua
```



### Accessing Error History


For advanced use cases, access expected errors programmatically:


```lua
local function count_expected_errors()
  local errors = error_handler.get_expected_errors()
  return #errors
end
it("should record multiple errors", { expect_error = true }, function()
  local start_count = count_expected_errors()

  -- Generate multiple errors
  test_helper.with_error_capture(function() error("Error 1") end)()
  test_helper.with_error_capture(function() error("Error 2") end)()

  -- Verify errors were recorded
  local end_count = count_expected_errors()
  expect(end_count - start_count).to.equal(2)
end)
```



## Error Testing Best Practices



1. **Always Use expect_error Flag**: Mark tests that expect errors with `{ expect_error = true }`
2. **Be Flexible with Error Checking**: Use `match()` instead of `equal()` for error messages
3. **Test All Error Cases**: Don't just test the happy path
4. **Use the Right Tool for the Job**:
   - `test_helper.expect_error()` for functions that throw errors
   - `test_helper.with_error_capture()` for complex error paths
   - Direct testing for functions that return nil + error
5. **Test Error Propagation**: Verify errors propagate correctly through function calls


## Module-Specific Error Handling


### Coverage Module


When implementing error handling in coverage components:


1. **File paths**: Always normalize and validate file paths
2. **Source code analysis**: Use try/catch for parser operations
3. **Data flow**: Validate data structures before processing
4. **Report generation**: Implement fallbacks for invalid data


### Assertions


For assertion-related error handling:


1. **Clear error messages**: Include expected and actual values
2. **Source location**: Include file and line information when available
3. **Failure isolation**: Prevent assertion failures from affecting other tests
4. **Custom formatting**: Use formatted messages for complex values


## Common Error Handling Mistakes


### 1. Swallowing Errors



```lua
-- BAD: Error is lost
function process_data(data)
  local result, err = validate(data)
  if not result then
    -- Error is swallowed, caller has no idea what went wrong
    return false
  end
  return process_result(result)
end
-- GOOD: Error is propagated
function process_data(data)
  local result, err = validate(data)
  if not result then
    -- Propagate error with additional context
    return nil, err
  end
  return process_result(result)
end
```



### 2. Insufficient Context



```lua
-- BAD: Generic error with no context
if not file_exists(path) then
  return nil, error_handler.io_error("File not found")
end
-- GOOD: Detailed error with context
if not file_exists(path) then
  return nil, error_handler.io_error(
    "File not found: " .. path,
    {file_path = path, operation = "read_config"}
  )
end
```



### 3. Inconsistent Error Handling



```lua
-- BAD: Inconsistent error handling
function operation_a()
  if error_condition then
    error("Operation failed")  -- Throws error
  end
  return result
end
function operation_b()
  if error_condition then
    return nil, "Operation failed"  -- Returns nil, error
  end
  return result
end
-- GOOD: Consistent error handling
function operation_a()
  if error_condition then
    return nil, error_handler.runtime_error(
      "Operation failed",
      {operation = "operation_a"}
    )
  end
  return result
end
function operation_b()
  if error_condition then
    return nil, error_handler.runtime_error(
      "Operation failed",
      {operation = "operation_b"}
    )
  end
  return result
end
```



### 4. Not Handling All Error Cases



```lua
-- BAD: Missing error handling
local result = json.decode(data)  -- Might throw an error
process_result(result)
-- GOOD: Comprehensive error handling
local success, result, err = error_handler.try(function()
  return json.decode(data)
end)
if not success then
  return nil, err
end
process_result(result)
```



## Error Handling Implementation Checklist


When implementing error handling in a module, ensure you cover these aspects:


1. **Input Validation**
   - [x] Add parameter validation at the start of functions
   - [x] Use appropriate error categories
   - [x] Include detailed error messages and context
2. **Error Propagation**
   - [x] Consistently use nil, error pattern
   - [x] Propagate errors from called functions
   - [x] Add context information to propagated errors
3. **Resource Management**
   - [x] Track resources for cleanup
   - [x] Use try/finally patterns for cleanup
   - [x] Handle cleanup errors properly
4. **I/O Operations**
   - [x] Use safe_io_operation for file access
   - [x] Include file paths in error context
   - [x] Handle filesystem errors properly
5. **External Integration**
   - [x] Use try/catch for external calls
   - [x] Convert third-party errors to standard format
   - [x] Provide fallbacks for external failures
6. **Logging**
   - [x] Log errors with appropriate severity
   - [x] Include relevant context in error logs
   - [x] Handle logger initialization failures
7. **Testing**
   - [x] Add error-specific tests
   - [x] Use expect_error flag for error tests
   - [x] Test all error paths and conditions


## Conclusion


Effective error handling is essential for creating reliable, maintainable code. By following the patterns and best practices in this guide, you can create a consistent approach to error handling that improves code quality, simplifies debugging, and enhances the overall robustness of your application.
For detailed API reference of the error handling system, see the [Error Handling API Reference](../api/error_handling.md).
For practical examples of the error handling patterns in action, see the [Error Handling Examples](../../examples/error_handling_examples.md).
