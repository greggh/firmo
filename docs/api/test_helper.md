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

- (function): A new function that wraps the original `func`. When this new function is called, it executes `func` safely. It returns `result, nil` on success, or `nil, error_object` if `func` throws an error.

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

### create_temp_test_directory

Creates a temporary test directory with helper methods for managing files within it. The directory itself is automatically registered for cleanup.

```lua
function test_helper.create_temp_test_directory()
```

**Returns:**

- `test_directory` (TestDirectory): An object representing the temporary directory with the following properties and methods:
  - `path` (string): The absolute path to the created temporary directory.
  - `create_file(file_path, content)`: Creates a file within the test directory (relative `file_path`). Handles subdirectories. Returns the full path. Registers the file for cleanup.
  - `read_file(file_path)`: Reads a file within the test directory (relative `file_path`). Returns `content|nil, error?`.
  - `create_subdirectory(subdir_path)`: Creates a subdirectory within the test directory (relative `subdir_path`). Returns the full path. Registers the subdirectory for cleanup.
  - `file_exists(file_name)`: Checks if a file exists within the test directory (relative `file_name`).
  - `unique_filename(prefix?, extension?)`: Generates a unique filename (not path) suitable for use within this directory.
  - `create_numbered_files(basename, content_pattern, count)`: Creates multiple numbered files (e.g., `base_001.txt`). Returns an array of full paths. Registers files for cleanup.
  - `write_file(filename, content)`: Writes content to a file (relative `filename`) and registers it for cleanup. Returns `success?, error?`.

**Example:**

```lua
local test_dir = test_helper.create_temp_test_directory()
expect(test_dir).to.exist()
expect(test_dir:path()).to.be.a("string")

-- Create a file
local file_path = test_dir:create_file("my_config.txt", "data=123")
expect(test_dir:file_exists("my_config.txt")).to.be_truthy()

-- Create a file in a subdirectory
local nested_path = test_dir:create_file("subdir/nested.log", "Log entry")
expect(test_dir:file_exists("subdir/nested.log")).to.be_truthy()

-- Read content
local content = test_dir:read_file("my_config.txt")
expect(content).to.equal("data=123")

-- Directory and all created files are automatically cleaned up
```

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
  test_dir:create_file("data.txt", "Some test data")

  -- All files are automatically cleaned up after the callback returns
end)
```

### execute_string

Executes a string of Lua code using `load()`.

```lua
function test_helper.execute_string(code)
```

**Parameters:**

- `code` (string): The Lua code string to execute.

**Returns:**

- `result` (any|nil): The result(s) returned by the executed code, or `nil` on error.
- `error_message` (string?): Error message if loading or executing the code failed.

**Example:**

```lua
local result, err = test_helper.execute_string("return 1 + 2")
expect(err).to_not.exist()
expect(result).to.equal(3)

local _, err = test_helper.execute_string("invalid lua code")
expect(err).to.be.a("string")
```
