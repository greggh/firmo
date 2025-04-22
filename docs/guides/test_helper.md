# Test Helper Usage Guide


The Test Helper module provides essential utilities for writing robust tests, handling errors gracefully, and managing temporary files and directories. This guide explains how to use the module's features effectively in your tests.

## Table of Contents



- [Introduction](#introduction)
- [Testing Error Conditions](#testing-error-conditions)
- [Working with Temporary Files](#working-with-temporary-files)
- [Creating Test Directories](#creating-test-directories)
- [Test Environment Utilities](#test-environment-utilities)
- [Mocking and Spying](#mocking-and-spying)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)


## Introduction


### Getting Started


To use the Test Helper module, first require it in your test file:


```lua
local test_helper = require("lib.tools.test_helper")
```


The module works seamlessly with the Firmo testing framework and provides several categories of utilities:


1. **Error testing**: Safely capture and verify errors
2. **Temporary file management**: Create and cleanup test files automatically
3. **Test directory utilities**: Work with directories containing multiple test files
4. **Environment utilities**: Modify environment variables, working directory, etc.
5. **Mocking and spying**: Mock I/O operations and create spy functions


## Testing Error Conditions


### Capturing Errors Safely


Traditional Lua error handling with `pcall` can be verbose. The Test Helper provides a cleaner approach:


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

### Suppressing Output


To test functions that produce output without cluttering test results:


```lua
it("should print error message", function()
  local result, stdout, stderr = test_helper.with_suppressed_output(function()
    return print_error_and_return("Something went wrong", 1)
  end)

  expect(result).to.equal(1)
  expect(stdout).to.match("Something went wrong")
  expect(stderr).to.equal("")
end)
```


The function captures both stdout and stderr while executing the provided function, allowing you to test the output without it appearing in test results.

## Working with Temporary Files


### Creating Temporary Files


Create temporary files that are automatically cleaned up after tests:


```lua
it("should read JSON file correctly", function()
  local content = [[
    {
      "name": "test",
      "value": 42
    }
  ]]

  local temp_file, err = test_helper.create_temp_file_with_content(content, "json")
  expect(err).to_not.exist("Failed to create temp file")

  -- Test file operations
  local data = load_json_file(temp_file)
  expect(data.name).to.equal("test")
  expect(data.value).to.equal(42)

  -- No need to clean up - happens automatically
end)
```


Benefits of using `test_helper` for temporary files:


1. Files are automatically cleaned up after tests
2. File paths are tracked to ensure nothing is left behind
3. Error handling is built in


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


This ensures all files are cleaned up, even those created outside the test helper system.

### Creating Temporary Directories


For tests that need directory operations:


```lua
it("should scan directory for configuration files", function()
  local temp_dir, err = test_helper.create_temp_directory("config_test_")
  expect(err).to_not.exist("Failed to create temp directory")

  -- Create files in the directory
  local fs = require("lib.tools.filesystem")
  fs.write_file(temp_dir .. "/config.json", '{"enabled": true}')
  fs.write_file(temp_dir .. "/settings.ini", "[Settings]\nenabled=true")

  -- Register files for cleanup
  test_helper.register_temp_file(temp_dir .. "/config.json")
  test_helper.register_temp_file(temp_dir .. "/settings.ini")

  -- Test directory operations
  local configs = find_config_files(temp_dir)
  expect(#configs).to.equal(2)

  -- Directory is cleaned up automatically
end)
```



## Creating Test Directories


### Using Test Directory Objects


For more complex tests involving multiple files in a directory structure:


```lua
it("should process project structure correctly", function()
  local test_dir = test_helper.create_temp_test_directory()

  -- Create project structure
  test_dir.create_file("src/main.lua", "print('Hello')")
  test_dir.create_file("src/utils.lua", "return {trim = function(s) return s:match('^%s*(.-)%s*$') end}")
  test_dir.create_file("tests/main_test.lua", "-- Test file")
  test_dir.create_file(".firmo-config.lua", "return {watch_mode = true}")

  -- Test project operations
  local files = find_project_files(test_dir.path)
  expect(#files).to.equal(4)

  local config = load_project_config(test_dir.path)
  expect(config.watch_mode).to.equal(true)

  -- Directory is cleaned up automatically
end)
```


The test directory object provides:


1. A property `path` with the directory path
2. A method `create_file` to create files with content
3. A method `create_directory` to create subdirectories
4. A method `file_path` to get absolute file paths
5. A method `read_file` to read file contents
6. A method `cleanup` to manually clean up (rarely needed)


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

## Test Environment Utilities


### Modifying Environment Variables


For tests that depend on environment variables:


```lua
it("should use DEBUG level from environment", function()
  test_helper.with_environment({
    DEBUG = "trace",
    APP_ENV = "test"
  }, function()
    -- Initialize system that reads from environment
    local logger = init_logger()

    -- Test with modified environment
    expect(logger.level).to.equal("trace")
    expect(logger.app_env).to.equal("test")
  end)

  -- Environment is restored after function returns
end)
```



### Changing Working Directory


For tests that depend on the current working directory:


```lua
it("should load config from current directory", function()
  test_helper.with_temp_test_directory({
    [".config"] = "test_value=42"
  }, function(dir_path)
    -- Run test with modified working directory
    test_helper.with_working_directory(dir_path, function()
      local config = load_local_config()
      expect(config.test_value).to.equal(42)
    end)
  end)
end)
```



### Path Separator Testing


For testing cross-platform path handling:


```lua
it("should normalize paths correctly on Windows", function()
  test_helper.with_path_separator("\\", function()
    local result = normalize_path("dir\\subdir\\file.txt")
    expect(result).to.equal("dir\\subdir\\file.txt")

    result = normalize_path("dir/subdir/file.txt")
    expect(result).to.equal("dir\\subdir\\file.txt")
  end)
end)
it("should normalize paths correctly on Unix", function()
  test_helper.with_path_separator("/", function()
    local result = normalize_path("dir/subdir/file.txt")
    expect(result).to.equal("dir/subdir/file.txt")

    result = normalize_path("dir\\subdir\\file.txt")
    expect(result).to.equal("dir/subdir/file.txt")
  end)
end)
```



## Mocking and Spying


### Mocking I/O Operations


For tests that depend on file I/O without actual files:


```lua
it("should handle different file scenarios", function()
  local restore = test_helper.mock_io({
    -- Successful read
    ["config%.json"] = {
      read = '{"setting": "value"}',
      error = nil
    },
    -- File not found
    ["nonexistent%.txt"] = {
      read = nil,
      error = "No such file or directory"
    },
    -- Permission denied
    ["protected%.log"] = {
      read = nil,
      error = "Permission denied"
    }
  })

  -- Test successful case
  local config = load_config("config.json")
  expect(config.setting).to.equal("value")

  -- Test error handling for missing file
  local success, err = pcall(function() load_config("nonexistent.txt") end)
  expect(success).to.equal(false)
  expect(err).to.match("No such file or directory")

  -- Test error handling for protected file
  success, err = pcall(function() load_config("protected.log") end)
  expect(success).to.equal(false)
  expect(err).to.match("Permission denied")

  -- Restore original I/O functions
  restore()
end)
```



### Creating Spy Functions


For tracking function calls without changing behavior:


```lua
it("should call correct functions with proper arguments", function()
  -- Create a spy for math.max
  local spy = test_helper.create_spy(math.max)

  -- Replace the original function (in a module or global)
  local original_max = math.max
  math.max = spy.func

  -- Call code that uses math.max
  local result = find_largest_value({5, 10, 3, 8})

  -- Verify the result
  expect(result).to.equal(10)

  -- Verify function was called correctly
  expect(spy.called).to.equal(true)
  expect(spy.call_count).to.equal(3) -- Called for each comparison

  -- Check specific calls
  expect(spy.calls[1].args[1]).to.equal(5)
  expect(spy.calls[1].args[2]).to.equal(10)
  expect(spy.calls[1].result).to.equal(10)

  -- Restore original function
  math.max = original_max
end)
```



### Mocking Time Functions


For tests that depend on time:


```lua
it("should format timestamps correctly", function()
  -- Mock time to a specific date
  local restore = test_helper.mock_time("2025-03-15 14:30:00")

  -- Test function that uses os.time() and os.date()
  local formatted = format_timestamp()
  expect(formatted).to.equal("2025-03-15 14:30:00")

  -- Test time difference calculations
  local difference = calculate_time_difference("2025-03-15 13:30:00")
  expect(difference).to.equal(3600) -- 1 hour in seconds

  -- Restore original time functions
  restore()
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
end)
```



### Managing Temporary Files


Follow these best practices for temporary file management:


1. **Use `create_temp_test_directory` for complex file structures**:


```lua
local test_dir = test_helper.create_temp_test_directory()
test_dir.create_file("config/settings.json", '{"debug": true}')
test_dir.create_file("src/main.lua", "print('Hello')")
```



1. **Use `with_temp_test_directory` for declarative file structures**:


```lua
test_helper.with_temp_test_directory({
  ["config/settings.json"] = '{"debug": true}',
  ["src/main.lua"] = "print('Hello')"
}, function(dir_path, files, test_dir)
  -- Test code
end)
```



1. **Always register external temporary files**:


```lua
local file_path = create_file_using_external_library()
test_helper.register_temp_file(file_path)
```



1. **Group related files in subdirectories**:


```lua
local test_dir = test_helper.create_temp_test_directory()
-- Group by module
test_dir.create_file("logger/config.json", '{"level": "debug"}')
test_dir.create_file("logger/output.log", "")
-- Group by feature
test_dir.create_file("authentication/users.json", '[{"username": "test"}]')
test_dir.create_file("authentication/roles.json", '[{"role": "admin"}]')
```



1. **Avoid deep directory nesting**:


```lua
-- Better: flat structure with prefixes
test_dir.create_file("logger_config.json", '{"level": "debug"}')
test_dir.create_file("auth_users.json", '[{"username": "test"}]')
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


If temporary files aren't being cleaned up:


```lua
-- Check that you're using test_helper functions
local temp_file = test_helper.create_temp_file_with_content("test", "txt")
-- Or register external files
local external_file = os.tmpname()
test_helper.register_temp_file(external_file)
-- Avoid creating unregistered files
-- BAD: This file won't be cleaned up automatically
local f = io.open("untracked_temp.txt", "w")
f:write("This file may be left behind")
f:close()
```



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



#### Mock I/O Not Working


If mock I/O isn't working as expected:


```lua
-- Make sure pattern matching is correct (use % to escape special characters)
local restore = test_helper.mock_io({
  ["config%.json"] = { -- Note the % to escape the .
    read = '{"setting": "value"}'
  }
})
-- Ensure you restore after tests
local function test_with_mocks()
  local restore = test_helper.mock_io({...})

  -- Test code

  -- Don't forget to restore
  restore()
end
```



#### Spy Functions Not Capturing Calls


If spy functions aren't capturing calls:


```lua
-- Make sure you're using the .func property
local spy = test_helper.create_spy(original_function)
-- CORRECT: Use the .func property
module.function_name = spy.func
-- INCORRECT: This doesn't work
module.function_name = spy
-- Remember to check .calls[index] for specific calls
expect(spy.calls[1].args[1]).to.equal(expected_value)
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
