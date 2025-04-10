# Test Helper API Reference

The Test Helper module provides utilities to make it easier to test error conditions and work with temporary files in tests. It's an essential tool for writing robust, reliable tests in the Firmo framework.

## Table of Contents

- [Module Overview](#module-overview)
- [Error Testing Functions](#error-testing-functions)
- [Temporary File Management](#temporary-file-management)
- [Test Directory Utilities](#test-directory-utilities)
- [Utility Functions](#utility-functions)

## Module Overview

The Test Helper module provides several key capabilities:

1. **Error Testing**: Functions to safely capture and test error conditions
2. **Temporary File Management**: Functions to create and manage temporary files during tests
3. **Test Directory Utilities**: Functions to work with temporary directories containing test files
4. **Test Utilities**: Helper functions for common testing operations

This module is designed to make writing tests easier, more reliable, and less error-prone, particularly when dealing with error conditions and file operations.

## Error Testing Functions

### with_error_capture

Wraps a function to safely capture errors.

```lua
function test_helper.with_error_capture(func)
```

**Parameters:**
- `func` (function): The function to wrap

**Returns:**
- (function): A wrapped function that returns `nil, error_object` when an error occurs

**Example:**
```lua
local result, err = test_helper.with_error_capture(function()
  return some_function_that_might_throw()
end)()

if not result then
  -- Error was captured
  expect(err.message).to.match("expected error pattern")
else
  -- Function succeeded
  expect(result).to.equal(expected_value)
end
```

### expect_error

Throws an assertion error if the function doesn't raise an error matching the expected message.

```lua
function test_helper.expect_error(func, expected_message)
```

**Parameters:**
- `func` (function): The function expected to throw an error
- `expected_message` (string, optional): Pattern to match against the error message

**Returns:**
- (table): The error object if the function throws an error

**Example:**
```lua
local err = test_helper.expect_error(function()
  validate_input(invalid_value)
end, "Invalid input")

-- Additional assertions on the error object
expect(err.category).to.equal("VALIDATION")
```

### with_suppressed_output

Executes a function with stdout and stderr temporarily suppressed.

```lua
function test_helper.with_suppressed_output(func)
```

**Parameters:**
- `func` (function): The function to execute with suppressed output

**Returns:**
- (any): The return value from the function
- (string): Captured stdout output
- (string): Captured stderr output

**Example:**
```lua
local result, stdout, stderr = test_helper.with_suppressed_output(function()
  print("This won't be displayed")
  io.stderr:write("This error won't be displayed")
  return "result"
end)

expect(result).to.equal("result")
expect(stdout).to.match("This won't be displayed")
expect(stderr).to.match("This error won't be displayed")
```

### mock_io

Temporarily mocks io.open and related functions for testing I/O operations.

```lua
function test_helper.mock_io(mocks)
```

**Parameters:**
- `mocks` (table): Table of file path patterns and mock behaviors

**Returns:**
- (function): Function to restore original I/O functions

**Example:**
```lua
local restore = test_helper.mock_io({
  ["config%.json"] = {
    read = '{"setting": "value"}',
    error = nil
  },
  ["nonexistent%.txt"] = {
    read = nil,
    error = "No such file or directory"
  }
})

-- Test code that uses io.open
local f = io.open("config.json", "r")
local content = f:read("*a")
f:close()
expect(content).to.equal('{"setting": "value"}')

-- Restore original I/O functions
restore()
```

## Temporary File Management

The test_helper module integrates with the temp_file module to provide easy-to-use functions for managing temporary files and directories in tests. The following functions handle test-specific file operations with automatic tracking and cleanup.

### register_temp_file

Register a file for cleanup after tests.

```lua
function test_helper.register_temp_file(file_path)
```

**Parameters:**
- `file_path` (string): Path to the file to register for cleanup

**Returns:**
- (boolean): Whether the file was successfully registered

**Example:**
```lua
-- For files created outside the test_helper system
local file_path = os.tmpname()
local f = io.open(file_path, "w")
f:write("content")
f:close()

-- Register for automatic cleanup
test_helper.register_temp_file(file_path)
```

### register_temp_directory

Register a directory for cleanup after tests.

```lua
function test_helper.register_temp_directory(dir_path)
```

**Parameters:**
- `dir_path` (string): Path to the directory to register for cleanup

**Returns:**
- (boolean): Whether the directory was successfully registered

**Example:**
```lua
-- For directories created outside the test_helper system
local dir_path = os.tmpname()
os.remove(dir_path) -- Remove the file created by tmpname
fs.create_directory(dir_path)

-- Register for automatic cleanup
test_helper.register_temp_directory(dir_path)
```

### create_temp_directory

Creates a temporary directory.

```lua
function test_helper.create_temp_directory(name_prefix)
```

**Parameters:**
- `name_prefix` (string, optional): Prefix for the directory name

**Returns:**
- (string|nil): Path to the created temporary directory, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local temp_dir, err = test_helper.create_temp_directory("test_")
expect(err).to_not.exist()

-- Use the directory in tests
fs.write_file(temp_dir .. "/config.json", '{"setting": "value"}')

-- Directory is automatically cleaned up after test completes
```

## Test Directory Utilities

### create_temp_test_directory

Creates a temporary test directory with utility functions for managing test files.

```lua
---@return TestDirectory test_directory Directory object with helper methods
function test_helper.create_temp_test_directory()
```

**Returns:**
- (TestDirectory): A test directory object with utility methods

**Example:**
```lua
local test_dir = test_helper.create_temp_test_directory()

-- Create files in the directory
test_dir.create_file("config.json", '{"setting": "value"}')
test_dir.create_file("src/main.lua", "print('Hello')")

-- Use the directory in tests
local config_path = test_dir.path .. "/config.json"
expect(fs.file_exists(config_path)).to.be_truthy()

-- Directory is automatically cleaned up after test completes
```

The `TestDirectory` object has the following methods and properties:

- `path` (string): The absolute path to the test directory
- `create_file(file_name, content)` (function): Creates a file within the directory, automatically creating parent directories as needed
- `create_subdirectory(subdir_name)` (function): Creates a subdirectory
- `file_exists(file_name)` (function): Checks if a file exists in the test directory
- `read_file(file_name)` (function): Reads a file within the directory
- `unique_filename(prefix, extension)` (function): Generates a unique filename in the directory
- `create_numbered_files(basename, content_pattern, count)` (function): Creates multiple numbered files
- `write_file(filename, content)` (function): Writes a file and registers it for cleanup

### with_temp_test_directory

Creates a temporary directory with specified files and executes a callback function with that directory.

```lua
---@param files_map table<string, string> Map of file paths to their content
---@param callback fun(dir_path: string, files: string[], test_dir: TestDirectory): any Function to call with created directory
---@return any Results from the callback function
function test_helper.with_temp_test_directory(files_map, callback)
```

**Parameters:**
- `files_map` (table): A table mapping file paths to their content
- `callback` (function): Function to call with the created directory

**Returns:**
- (any): The return values from the callback function

**Example:**
```lua
test_helper.with_temp_test_directory({
  ["config.json"] = '{"setting": "value"}',
  ["src/main.lua"] = "print('Hello')",
  ["README.md"] = "# Test Project"
}, function(dir_path, files, test_dir)
  -- dir_path is the absolute path to the test directory
  -- files is an array of created file paths
  -- test_dir is the TestDirectory object with helper methods
  
  -- Verify files were created correctly
  expect(fs.file_exists(dir_path .. "/config.json")).to.be_truthy()
  expect(#files).to.equal(3)
  
  -- Test code using these files
  local config = load_config(dir_path .. "/config.json")
  expect(config.setting).to.equal("value")
  
  -- Add more files if needed during the test
  test_dir.create_file("data.txt", "Some test data")
  
  -- All files are automatically cleaned up after the callback returns
end)
```

## Utility Functions

### with_environment

Temporarily modifies environment variables for a test.

```lua
function test_helper.with_environment(env_vars, func)
```

**Parameters:**
- `env_vars` (table): A table of environment variables to set
- `func` (function): Function to execute with the modified environment

**Returns:**
- (any): The return value from the function

**Example:**
```lua
local result = test_helper.with_environment({
  DEBUG = "1",
  LOG_LEVEL = "trace"
}, function()
  -- Code that uses environment variables
  return check_debug_setting()
end)

expect(result).to.be_truthy()
```

### with_working_directory

Temporarily changes the working directory for a test.

```lua
function test_helper.with_working_directory(dir_path, func)
```

**Parameters:**
- `dir_path` (string): The directory to change to
- `func` (function): Function to execute in the directory

**Returns:**
- (any): The return value from the function

**Example:**
```lua
local result = test_helper.with_working_directory("tests/fixtures", function()
  -- Code that relies on current working directory
  return load_relative_file("data.json")
end)

expect(result).to_not.equal(nil)
```

### with_path_separator

Temporarily changes the path separator for cross-platform testing.

```lua
function test_helper.with_path_separator(separator, func)
```

**Parameters:**
- `separator` (string): The path separator to use ("/" or "\\")
- `func` (function): Function to execute with the modified separator

**Returns:**
- (any): The return value from the function

**Example:**
```lua
-- Test Windows path handling
local result = test_helper.with_path_separator("\\", function()
  return fs.normalize_path("dir\\subdir\\file.txt")
end)

expect(result).to.equal("dir\\subdir\\file.txt")
```

### mock_time

Mocks os.time and os.date for time-dependent tests.

```lua
function test_helper.mock_time(time_value)
```

**Parameters:**
- `time_value` (number|string): Unix timestamp or date string

**Returns:**
- (function): Function to restore original time functions

**Example:**
```lua
-- Mock time to a specific date
local restore = test_helper.mock_time("2025-01-15 12:00:00")

-- Test code that depends on time
local timestamp = os.time()
local formatted = os.date("%Y-%m-%d", timestamp)
expect(formatted).to.equal("2025-01-15")

-- Restore original time functions
restore()
```

### create_spy

Creates a spy function for tracing calls.

```lua
function test_helper.create_spy(func)
```

**Parameters:**
- `func` (function, optional): Original function to wrap

**Returns:**
- (table): Spy object with call history and the spy function

**Example:**
```lua
local spy = test_helper.create_spy(math.max)

-- Call the spy function
local result = spy.func(5, 10)

-- Verify calls
expect(result).to.equal(10)
expect(spy.called).to.equal(true)
expect(spy.call_count).to.equal(1)
expect(spy.calls[1].args[1]).to.equal(5)
expect(spy.calls[1].args[2]).to.equal(10)
expect(spy.calls[1].result).to.equal(10)
```