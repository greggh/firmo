# lib/tools/test_helper Knowledge

## Purpose

The `lib/tools/test_helper` module provides a collection of utility functions specifically crafted to simplify common patterns and tasks when writing tests using the Firmo framework. These helpers are particularly useful for tests that need to verify error handling behavior or require temporary files and directories that should be automatically cleaned up after the test runs.

## Key Concepts

- **Error Handling Helpers:** These functions integrate with `lib.tools.error_handler` to manage test contexts and expectations around errors.
    - **`with_error_capture(fn)`:** This function takes another function `fn` as input and returns a *new wrapper function*. When this wrapper function is called:
        1.  It signals to the `error_handler` that an error is expected within this context (setting `expect_error=true` in test metadata).
        2.  It executes the original function `fn` safely using `pcall`.
        3.  It cleans up the error handler context.
        4.  If `fn` completed successfully, it returns the results (`result, nil`).
        5.  If `fn` threw an error, `with_error_capture` catches it, performs complex internal normalization to ensure the error is a standard `error_handler` object with the category `TEST_EXPECTED` (preserving the original error as a cause or in context), and returns `nil, normalized_error_object`.
        This is useful when you need to inspect the properties of an expected error object.
    - **`expect_error(fn, message_pattern?)`:** This function serves as an *assertion*. It verifies that the provided function `fn` *must* throw an error.
        1.  It sets the `error_handler` context to expect an error.
        2.  It executes `fn` safely using `pcall`.
        3.  It cleans up the error handler context.
        4.  If `fn` *succeeds* (does not throw), `expect_error` itself throws a standard Firmo assertion error (failing the test).
        5.  If `fn` *throws* an error, it normalizes the captured error (similar to `with_error_capture`).
        6.  If `message_pattern` (a Lua string pattern) was provided, it checks if the normalized error's message matches the pattern. If it doesn't match, `expect_error` throws a Firmo assertion error.
        7.  If all conditions are met (error thrown, pattern matches if provided), it returns the normalized `TEST_EXPECTED` error object.

- **Temporary Directory Helpers:** These leverage `lib.tools.filesystem.temp_file` for cleanup.
    - **`create_temp_test_directory()`:** Creates a unique temporary directory via `temp_file.create_temp_directory` (which registers it for cleanup) and returns a `TestDirectory` helper object. This object provides convenient methods for working within that specific temporary directory:
        - `path`: The absolute path to the created directory.
        - `create_file(name, content)`: Creates a file inside the directory (and subdirs if needed), registers it for cleanup, returns full path.
        - `read_file(name)`: Reads a file from the directory.
        - `create_subdirectory(name)`: Creates a subdirectory, registers it for cleanup, returns full path.
        - `file_exists(name)`: Checks if a relative path exists within the directory.
        - `unique_filename(prefix?, ext?)`: Generates a unique filename string (not path).
        - `create_numbered_files(basename, content_pattern, count)`: Creates multiple files (e.g., `base_001.txt`), registers them, returns paths.
        - `write_file(name, content)`: Writes a file, registers it, returns `success, err`.
    - **`with_temp_test_directory(files_map, callback)`:** A higher-level convenience function. It performs the following sequence:
        1.  Calls `create_temp_test_directory()` to get a managed temporary directory.
        2.  Iterates through `files_map` (a table where keys are relative paths and values are content strings) and uses `test_dir.create_file` to create the specified file structure.
        3.  Executes the provided `callback` function, passing it the absolute directory path, a list of created file paths, and the `TestDirectory` helper object.
        4.  Automatic cleanup of the directory and all registered contents occurs after the callback finishes (via the `temp_file` integration).
        5.  Returns any values returned by the `callback` function. If the callback errors, the error is re-thrown after cleanup. This is often the preferred way to set up temporary test fixtures.

- **Manual Cleanup Registration:**
    - **`register_temp_file(path)` / `register_temp_directory(path)`:** These directly call the corresponding functions in `lib.tools.filesystem.temp_file`, allowing manual registration of existing files or directories within a test context for automatic cleanup. Useful if resources are created by external processes or means other than the helper functions.

- **Code Execution:**
    - **`execute_string(code)`:** A simple utility using Lua's built-in `load()` function to compile and execute a string containing Lua code. It returns the results of the executed code or `nil, error_message` if compilation or execution fails.

- **Integration:** These helpers are tightly integrated with:
    - `lib/tools/error_handler`: For managing the `expect_error` context in test metadata and for normalizing captured errors.
    - `lib/tools/filesystem` (specifically `temp_file.lua` and `temp_file_integration.lua`): For creating temporary resources and ensuring they are automatically cleaned up by the test runner.

## Usage Examples / Patterns

### Pattern 1: Using `with_error_capture`

```lua
--[[
  Test that a function fails and inspect the error object.
]]
local test_helper = require("lib.tools.test_helper")
local expect = require("lib.assertion.expect").expect -- Assuming expect is available

local function might_fail(value)
  if type(value) ~= "number" then
    error(error_handler.validation_error("Input must be a number", { input_type = type(value) }))
  end
  return value * 2
end

it("should capture and return a validation error", function()
  local wrapped_func = test_helper.with_error_capture(function()
    might_fail("not a number")
  end)

  local result, err = wrapped_func()

  expect(result).to.be_nil()
  expect(err).to.exist()
  expect(err.category).to.equal(error_handler.CATEGORY.TEST_EXPECTED)
  expect(err.message).to.match("Input must be a number")
  -- Inspect original error via cause or context added during normalization
  if err.cause then
    expect(err.cause.category).to.equal(error_handler.CATEGORY.VALIDATION)
    expect(err.cause.context.input_type).to.equal("string")
  end
end)
```

### Pattern 2: Using `expect_error`

```lua
--[[
  Assert that a function throws an error, optionally matching the message.
]]
local test_helper = require("lib.tools.test_helper")
local expect = require("lib.assertion.expect").expect -- Assuming expect is available

local function always_throws()
  error("Something went wrong!")
end

local function throws_specific()
    error("Error code: 123 - Specific message.")
end

it("should assert that a function throws any error", function()
  local captured_err = test_helper.expect_error(always_throws)
  -- Test passes if always_throws() errors. We can optionally inspect captured_err.
  expect(captured_err).to.exist()
  expect(captured_err.category).to.equal(error_handler.CATEGORY.TEST_EXPECTED)
end)

it("should assert that a function throws an error matching a pattern", function()
  local captured_err = test_helper.expect_error(throws_specific, "Error code: %d+")
  -- Test passes if throws_specific() errors AND message matches pattern.
  expect(captured_err).to.exist()
  expect(captured_err.message).to.match("Error code: 123")
end)

-- This test would FAIL because the function succeeds:
-- it("should fail if the function does not throw", function()
--   test_helper.expect_error(function() return true end)
-- end)

-- This test would FAIL because the message doesn't match:
-- it("should fail if the message pattern doesn't match", function()
--   test_helper.expect_error(always_throws, "Non-matching pattern")
-- end)

```

### Pattern 3: Using `create_temp_test_directory`

```lua
--[[
  Create a temporary directory and files dynamically within a test.
]]
local test_helper = require("lib.tools.test_helper")
local expect = require("lib.assertion.expect").expect

it("should allow creating files in a temp directory", function()
  local test_dir = test_helper.create_temp_test_directory()
  expect(test_dir).to.exist()
  expect(test_dir.path).to.be.a("string")

  local file1_path = test_dir.create_file("file1.txt", "Content 1")
  expect(test_dir:file_exists("file1.txt")).to.be_truthy()

  local subdir_path = test_dir.create_subdirectory("data")
  local file2_path = test_dir.create_file("data/file2.log", "Log entry")
  expect(test_dir:file_exists("data/file2.log")).to.be_truthy()

  -- Read back content (using the helper method)
  local content1, read_err1 = test_dir:read_file("file1.txt")
  expect(read_err1).to_not.exist()
  expect(content1).to.equal("Content 1")

  -- Directory and files are cleaned up automatically after the test
end)
```

### Pattern 4: Using `with_temp_test_directory`

```lua
--[[
  Execute code within a temporary directory pre-populated with files.
]]
local test_helper = require("lib.tools.test_helper")
local expect = require("lib.assertion.expect").expect
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

it("should execute callback within a populated temp directory", function()
  local files_to_create = {
    ["config.lua"] = "return { setting = true }",
    ["data/input.txt"] = "Data to process",
  }

  local result, cb_err = test_helper.with_temp_test_directory(files_to_create,
    function(dir_path, created_files, test_dir_obj)
      -- Assert files were created
      expect(#created_files).to.equal(2)
      expect(test_dir_obj:file_exists("config.lua")).to.be_truthy()
      expect(test_dir_obj:file_exists("data/input.txt")).to.be_truthy()

      -- Example: load the config file
      local config_path = fs.join_paths(dir_path, "config.lua")
      local func, load_err = loadfile(config_path)
      expect(load_err).to_be_nil()
      local config_data = func()
      expect(config_data.setting).to.be_truthy()

      return "Callback Done" -- Pass result back
    end
  )

  -- Check callback results and potential errors
  expect(cb_err).to_not.exist()
  expect(result).to.equal("Callback Done")
  -- Temp directory is automatically cleaned up
end)
```

### Pattern 5: Using `execute_string`

```lua
--[[
  Dynamically execute a string of Lua code.
]]
local test_helper = require("lib.tools.test_helper")
local expect = require("lib.assertion.expect").expect

it("should execute a lua string", function()
  local code = "local a=5; local b=3; return a+b"
  local result, err = test_helper.execute_string(code)

  expect(err).to_be_nil()
  expect(result).to.equal(8)
end)

it("should return error for invalid code string", function()
  local invalid_code = "local a = 1 +"
  local result, err = test_helper.execute_string(invalid_code)

  expect(result).to_be_nil()
  expect(err).to.be.a("string")
  expect(err).to.match("unexpected symbol") -- Error from load()
end)

```

## Related Components / Modules

- **`lib/tools/test_helper/init.lua`**: The source code implementation of this module.
- **`lib/tools/error_handler/knowledge.md`**: **Crucial dependency.** The error helpers (`with_error_capture`, `expect_error`) rely heavily on the error handler's context management (`set_current_test_metadata`) and error object structure. Understanding the error handler is key to using these helpers effectively.
- **`lib/tools/filesystem/knowledge.md` (specifically `temp_file.lua` section)**: **Crucial dependency.** The temporary directory helpers (`create_temp_test_directory`, `with_temp_test_directory`, `register_*`) are built upon the `temp_file` module and rely on its automatic cleanup integration with the test runner.
- **`lib/assertion/expect.lua` Knowledge**: The `expect()` function (or other assertion functions) is commonly used within tests alongside these helpers to make assertions about captured errors (`with_error_capture`) or results obtained using temporary files.

## Best Practices / Critical Rules (Optional)

- **Choose the Right Error Helper:**
    - Use `expect_error` when your primary goal is simply to verify that a function throws *any* error, or an error with a specific message pattern.
    - Use `with_error_capture` when you need to catch the error object itself to perform more detailed assertions on its properties (e.g., `category`, `severity`, specific `context` fields, `cause`).
- **Prefer `with_temp_test_directory`:** For tests requiring a known set of temporary files as input, `with_temp_test_directory` is generally cleaner and safer than manually using `create_temp_test_directory` because it encapsulates setup, execution, and cleanup. Use `create_temp_test_directory` when the test logic needs to dynamically create files/directories during execution.
- **Run within Firmo Runner:** These helpers, especially those interacting with `error_handler` context and `temp_file` cleanup, assume they are being run within the context of the Firmo test runner (`scripts/runner.lua`), which performs necessary setup and teardown (like calling `temp_file_integration.initialize()` and managing test metadata). Running tests containing these helpers outside the standard runner might lead to unexpected behavior or resource leaks.

## Troubleshooting / Common Pitfalls (Optional)

- **`expect_error` Fails: "Function did not throw an error..."**: The code inside the function passed to `expect_error` completed successfully without calling `error()`. Review the logic of the function being tested to ensure it actually fails under the test conditions.
- **`expect_error` Fails: "Error message does not match..."**: The function *did* throw an error, but the error message (after normalization) did not match the Lua pattern provided as the second argument to `expect_error`. Check the actual error message produced (e.g., by temporarily using `with_error_capture` and printing `err.message`) and ensure your pattern correctly matches it. Remember Lua pattern syntax differs from regex.
- **Errors from `with_error_capture` Have Unexpected Structure:** The normalization logic inside `with_error_capture` tries to create a consistent `TEST_EXPECTED` error, often preserving the original error in the `cause` field or context. If inspecting the error, look at `err.cause` or `err.context.original_context` for details about the initially thrown error. The complexity arises from handling errors thrown as strings vs. structured error objects vs. other types.
- **Temporary Files/Directories Not Cleaned Up:** This usually indicates a problem with the underlying `temp_file` system or its integration. Refer to the Troubleshooting section in `lib/tools/filesystem/knowledge.md`. Ensure tests are run via the Firmo runner which should initialize the cleanup hooks. If a test crashes fatally, cleanup might be skipped.
