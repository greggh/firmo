# Test Helper Usage Guide


The Test Helper module provides essential utilities for writing robust tests, handling errors gracefully, and managing temporary files and directories. This guide explains how to use the module's features effectively in your tests.

## Table of Contents



- [Introduction](#introduction)
- [Testing Error Conditions](#testing-error-conditions)
- [Working with Temporary Files](#working-with-temporary-files)
- [Creating Test Directories](#creating-test-directories)
- [Utility Functions](#utility-functions)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)


## Introduction


### Getting Started


To use the Test Helper module, first require it in your test file:


```lua
local test_helper = require("lib.tools.test_helper")
```


The module works seamlessly with the Firmo testing framework and provides several categories of utilities:


1. **Error testing**: Safely capture and verify errors (`with_error_capture`, `expect_error`).
2. **Temporary file management**: Register external temporary files/directories for automatic cleanup (`register_temp_file`, `register_temp_directory`). Note: File creation is handled by the `temp_file` module.
3. **Test directory utilities**: Create temporary directories with helper methods for file manipulation (`create_temp_test_directory`, `with_temp_test_directory`).
4. **Utility Functions**: Execute Lua code strings (`execute_string`).


## Testing Error Conditions


### Capturing Errors Safely

- (function): A new function that wraps the original `func`. When this new function is called, it executes `func` safely. The wrapped function returns `result, nil` on success, or `nil, error_object` if `func` throws an error.


```lua
-- Traditional pcall approach
local success, result = pcall(function()
  return potentially_failing_function(arg1, arg2)
end)
if not success then
  -- Handle error in result
  print("Error:", result)
else
  -- Use successful result
  print("Result:", result)
end
-- With test_helper.with_error_capture
local result, err = test_helper.with_error_capture(function()
  return potentially_failing_function(arg1, arg2)
end)()
if err then
  -- Handle error in err (structured error object)
  print("Error:", err.message)
  print("Category:", err.category)
else
  -- Use successful result
  print("Result:", result)
end
```


The benefit of `with_error_capture` is that errors are returned as structured objects with categories, messages, and context, rather than just strings.

### Expecting Errors


When testing functions that should fail under certain conditions, use `expect_error`:


```lua
it("should throw error for invalid input", function()
  local err = test_helper.expect_error(function()
    validate_email("not-an-email")
  end, "Invalid email format")

  -- You can make additional assertions about the error
  expect(err.category).to.equal("VALIDATION")
  expect(err.context.input).to.equal("not-an-email")
end)
```


`expect_error` automatically fails the test if:


1. The function doesn't throw an error
2. The error message doesn't match the expected pattern (if provided)


### Testing with Error Flags


For tests focused on error conditions, use the `expect_error` flag:


```lua
it("should handle file not found gracefully", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return fs.read_file("nonexistent-file.txt")
  end)()

  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("file not found")
  expect(err.category).to.equal("IO")
end)
```


The `expect_error` flag indicates to the test framework that this test intentionally tests error conditions, which helps with reporting and test quality validation.
## Working with Temporary Files


### Creating Temporary Files


Register externally created temporary files that should be automatically cleaned up after tests:

> Note: For creating temporary files and directories with automatic registration, use the dedicated `temp_file` module (`require("lib.tools.filesystem.temp_file")`). The `test_helper` module primarily provides functions to *register* files/directories created by other means.
### Registering External Files


For files created outside the test helper system:


```lua
it("should handle files created by the system", function()
  -- File created by some external means
  local temp_path = os.tmpname()
  local f = io.open(temp_path, "w")
  f:write("test content")
  f:close()

  -- Register it for cleanup
  test_helper.register_temp_file(temp_path)

  -- Test with the file
  local content = read_file(temp_path)
  expect(content).to.equal("test content")

  -- No need to manually delete - happens automatically
end)
```


This ensures all files and directories are cleaned up, even those created outside the `temp_file` module's creation functions.

### Registering Temporary Directories

Similar to files, register directories created externally:

```lua
it("should handle directories created externally", function()
  -- Directory created by some external means
  local dir_path = create_directory_structure() -- Your function

  -- Register it for automatic cleanup
  test_helper.register_temp_directory(dir_path)

  -- Test with the directory
  local files = fs.list_files(dir_path)
  expect(#files).to.be_greater_than(0)

  -- No need to manually delete - happens automatically
end)
```



## Creating Test Directories

### `create_temp_test_directory()`

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
it("should process project structure correctly", function()
  local test_dir = test_helper.create_temp_test_directory()
  expect(test_dir).to.exist()
  expect(test_dir.path).to.be.a("string")

  -- Create project structure using helper methods
  test_dir:create_file("src/main.lua", "print('Hello')")
  test_dir:create_file("src/utils.lua", "return {trim = function(s) return s:match('^%s*(.-)%s*$') end}")
  test_dir:create_subdirectory("tests")
  test_dir:create_file("tests/main_test.lua", "-- Test file")
  test_dir:create_file(".firmo-config.lua", "return {watch_mode = true}")

  -- Test project operations
  local files = find_project_files(test_dir.path) -- Assuming this function exists
  expect(#files).to.equal(4)

  local config = load_project_config(test_dir.path) -- Assuming this function exists
  expect(config.watch_mode).to.equal(true)

  -- Directory and all created files/subdirs are automatically cleaned up
end)
```


### Using with_temp_test_directory


For tests that need a complete directory structure created at once:


```lua
it("should build project correctly", function()
  test_helper.with_temp_test_directory({
    ["src/main.lua"] = "print('Hello')",
    ["src/utils.lua"] = "return {trim = function(s) return s:match('^%s*(.-)%s*$') end}",
    ["tests/main_test.lua"] = "-- Test file",
    [".firmo-config.lua"] = "return {watch_mode = true}"
  }, function(dir_path, files, test_dir)
    -- dir_path is the directory path
    -- files is a table of created file paths
    -- test_dir is the test directory object

    -- Test build process
    local success = build_project(dir_path)
    expect(success).to.equal(true)

    -- Check build results
    expect(fs.file_exists(dir_path .. "/build/main.lua")).to.equal(true)

    -- Directory is cleaned up automatically when function returns
  end)
end)
```


This approach is more concise and doesn't require creating files individually.

## Utility Functions

### `execute_string(code)`

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
it("should execute lua code string", function()
  local result, err = test_helper.execute_string("return 1 + 2")
  expect(err).to_not.exist()
  expect(result).to.equal(3)

  local _, err = test_helper.execute_string("invalid lua code")
  expect(err).to.be.a("string")
end)
```
## Best Practices


### Structuring Error Tests


Follow these best practices for testing error conditions:


1. **Use the `expect_error` flag** for tests focused on error conditions:


```lua
it("should handle invalid input gracefully", { expect_error = true }, function()
  -- Test code
end)
```



1. **Prefer `with_error_capture` over raw `pcall`** for better error objects:


```lua
-- Better approach
local result, err = test_helper.with_error_capture(function()
  return risky_function()
end)()
-- Instead of
local success, result = pcall(function() return risky_function() end)
```



1. **Check error categories** rather than exact error messages when appropriate:


```lua
-- More resilient to message changes
expect(err.category).to.equal("VALIDATION")
-- Instead of
expect(err.message).to.equal("Invalid email: missing @ symbol")
```



1. **Test both happy path and error cases** for thorough coverage:


```lua
it("should parse valid JSON", function()
  local result = parse_json('{"key": "value"}')
  expect(result.key).to.equal("value")
end)
it("should handle invalid JSON", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return parse_json('{not valid json}')
  end)()

  expect(result).to_not.exist()
  expect(err.category).to.equal("PARSE")
### Managing Temporary Resources

Follow these best practices for temporary file and directory management:

1.  **Prefer `temp_file` module for creation:** Use `require("lib.tools.filesystem.temp_file")` functions (`create_with_content`, `create_temp_directory`) for creating simple temporary resources, as they handle registration automatically.
2.  **Use `test_helper` for registration:** If you must create files/directories externally (e.g., complex setup, external tools), use `test_helper.register_temp_file` and `test_helper.register_temp_directory` to ensure they are tracked for cleanup.
3.  **Use `TestDirectory` object for structures:** When tests need a controlled directory structure with multiple files/subdirectories, `test_helper.create_temp_test_directory()` provides a convenient API:
    ```lua
    local test_dir = test_helper.create_temp_test_directory()
    test_dir:create_file("config/settings.json", '{"debug": true}')
    test_dir:create_subdirectory("src")
    test_dir:create_file("src/main.lua", "print('Hello')")
    ```
4.  **Use `with_temp_test_directory` for declarative structures:** For simple, predefined structures, this function is concise:
    ```lua
    test_helper.with_temp_test_directory({
      ["config.json"] = '{"debug": true}',
      ["main.lua"] = "print('Hello')"
    }, function(dir_path, files, test_dir)
      -- Test code using the created files/directory
    end)
    ```
-- Instead of deeply nested directories
test_dir.create_file("system/subsystem/module/component/config.json", "{}")
```



### Clean Test Structure


Structure your tests for clarity and maintainability:


1. **Group related test utilities**:


```lua
-- Setup common test environment
local function setup_test_environment()
  local test_dir = test_helper.create_temp_test_directory()
  test_dir.create_file("config.json", '{"test": true}')

  -- Initialize system with test directory
  local system = init_system(test_dir.path)

  return {
    dir = test_dir,
    system = system
  }
end
it("should load configuration", function()
  local env = setup_test_environment()
  expect(env.system.config.test).to.equal(true)
end)
```



1. **Use `before` and `after` hooks for common setup**:


```lua
describe("Configuration system", function()
  local test_dir
  local system

  before(function()
    test_dir = test_helper.create_temp_test_directory()
    test_dir.create_file("config.json", '{"test": true}')
    system = init_system(test_dir.path)
  end)

  -- Tests can use test_dir and system
  it("should load configuration", function()
    expect(system.config.test).to.equal(true)
  end)

  it("should detect configuration changes", function()
    test_dir.create_file("config.json", '{"test": false}')
    system.reload()
    expect(system.config.test).to.equal(false)
  end)

  -- Cleanup happens automatically
end)
```



## Troubleshooting


### Common Issues and Solutions


#### Files Not Being Cleaned Up

If temporary files aren't being cleaned up properly:

1.  **Check registration**: Ensure files/directories are created with `temp_file` module functions, the `TestDirectory` object's methods, or manually registered using `test_helper.register_temp_file`/`test_helper.register_temp_directory`.
2.  **Verify test context**: Ensure `temp_file_integration.initialize(firmo)` is called (usually by the runner) so resources are tracked per test.
3.  **Manual cleanup**: Try calling `require("lib.tools.filesystem.temp_file").cleanup_all()` explicitly at the end of your test suite run to diagnose issues.

#### Error Tests Failing Unexpectedly


If error tests are failing:


```lua
-- Make sure you're using the expect_error flag
it("should handle errors", { expect_error = true }, function()
  -- Test code
end)
-- Use with_error_capture correctly (note the double parentheses)
local result, err = test_helper.with_error_capture(function()
  return risky_function()
end)() -- <-- Don't forget to call the returned function
```




### Getting Help


For more details on test helper functions:


1. See the [Test Helper API Reference](../api/test_helper.md)
2. Look at examples in [Test Helper Examples](../../examples/test_helper_examples.md)
3. Check existing tests in the codebase for practical usage patterns

If you encounter persistent issues:


1. Enable debug logging to see more details:

   ```lua
   local logging = require("lib.tools.logging")
   logging.configure_from_options("test_helper", {
     debug = true,
     verbose = true
   })
   ```


2. Use structured error handling to get more context:

   ```lua
   local error_handler = require("lib.tools.error_handler")
   local success, result, err = error_handler.try(function()
     -- Problematic code here
   end)

   if not success then
     print("Error:", error_handler.format_error(result))
   end
   ```
## Conclusion

The Test Helper module provides essential utilities for robust testing in Firmo, particularly for handling error conditions (`with_error_capture`, `expect_error`) and managing temporary test directory structures (`create_temp_test_directory`, `with_temp_test_directory`). It also allows registration of externally created temporary files/directories for cleanup and provides a simple way to execute Lua code strings. By incorporating these helpers, you can write cleaner, more reliable tests focused on validating your code's behavior.
