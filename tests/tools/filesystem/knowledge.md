# tests/tools/filesystem Knowledge

## Purpose

The `tests/tools/filesystem/` directory contains tests validating Firmo's filesystem utilities. This includes verifying the core cross-platform operations provided by `lib/tools/filesystem/init.lua` (like file reading/writing, directory manipulation, path handling) and the specialized system for managing temporary files and directories during test runs, implemented in `lib/tools/filesystem/temp_file.lua` and integrated via `lib/tools/filesystem/temp_file_integration.lua`.

## Key Concepts

The tests in this directory cover two main areas:

- **Core Filesystem Operations (`filesystem_test.lua`):**
    - Tests basic file I/O (`read_file`, `write_file`, `append_file`).
    - Tests file manipulation (`copy_file`, `move_file`, `delete_file`).
    - Tests directory operations (`create_directory`, `ensure_directory_exists`, `delete_directory`, `list_files`, `list_files_recursive`, `scan_directory`).
    - Tests path handling utilities (`join_paths`, `normalize_path`, `get_absolute_path`, `get_directory_name`, `get_file_name`, `get_extension`).
    - Tests metadata functions (`file_exists`, `directory_exists`, `is_file`, `is_directory`, `get_file_size`, `get_modified_time`).
    - **Crucially**, these tests verify that operations behave correctly *when wrapped with `error_handler.safe_io_operation`* and that appropriate errors are returned for failure conditions (e.g., file not found, permission errors). Test setup likely uses `test_helper` extensively.

- **Temporary File System (`temp_file_*.lua`):**
    - `temp_file_test.lua`: Tests the core functions of `lib/tools/filesystem/temp_file.lua`, such as `create_with_content`, `create_temp_directory`, the scoped wrappers `with_temp_file` and `with_temp_directory`, manual registration (`register_file`, `register_directory`), and potentially manual cleanup functions. Verifies that these functions create resources and register them correctly.
    - `temp_file_integration_test.lua`: Focuses on the automatic cleanup mechanism provided by `temp_file_integration.lua`. Tests likely involve running simple `it` blocks that create temporary resources via `temp_file.lua`, and then using `after_each` hooks to assert that those resources have been automatically deleted by the integrated cleanup process.
    - `temp_file_stress_test.lua`, `temp_file_performance_test.lua`, `temp_file_timeout_test.lua`: These likely test the temporary file system's robustness and behavior under more demanding conditions, such as creating/deleting many files, measuring the time required for these operations, or testing cleanup behavior when dealing with potentially slow operations.

- **Test Environment:** Tests rely heavily on `lib/tools/test_helper` (especially `with_temp_test_directory`) to create controlled, temporary filesystem structures. Tests involving the automatic cleanup feature of `temp_file.lua` must run within the Firmo test runner environment where `temp_file_integration` has patched the necessary hooks.

## Usage Examples / Patterns (Illustrative Test Snippets)

### Testing Core FS Read (Correctly Wrapped)

```lua
--[[
  Example test verifying fs.read_file using the mandatory safe wrapper.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")

it("should read file content using safe_io_operation", function()
  -- Use test_helper to create a controlled temp environment
  test_helper.with_temp_test_directory({ ["data.txt"] = "test content" }, function(dir_path)
    local file_path = fs.join_paths(dir_path, "data.txt")

    -- MUST wrap filesystem call in safe_io_operation
    local content, err = error_handler.safe_io_operation(fs.read_file, file_path)

    -- Assertions
    expect(err).to_not.exist()
    expect(content).to.equal("test content")
  end)
end)
```

### Testing `temp_file.with_temp_file` (Scoped Helper)

```lua
--[[
  Example test verifying the scoped temp file helper.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")
local error_handler = require("lib.tools.error_handler")

it("with_temp_file creates, uses, and cleans up file", function()
  local file_path_in_callback -- Variable to store the path for later check
  local callback_result

  local success, err = error_handler.try(function()
    callback_result = temp_file.with_temp_file("temporary data", function(path)
      file_path_in_callback = path
      -- File should exist during callback
      expect(fs.file_exists(path)).to.be_truthy()
      local content = fs.read_file(path) -- Using fs directly here is okay if failure is handled
      expect(content).to.equal("temporary data")
      return "Callback Ran"
    end)
  end)

  -- Check callback result and ensure no errors
  expect(err).to_not.exist()
  expect(success).to.be_truthy()
  expect(callback_result).to.equal("Callback Ran")

  -- Critical check: Verify the file was automatically cleaned up afterwards
  expect(fs.file_exists(file_path_in_callback)).to.be_falsey("Temp file should be cleaned up")
end)
```

### Testing Temp File Integration (Conceptual)

```lua
--[[
  Conceptual test for verifying automatic cleanup via runner integration.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")

describe("Temporary File Integration", function()
  local path_to_check

  before_each(function()
    path_to_check = nil -- Reset path before each test
  end)

  after_each(function()
    -- Check if the file created in the 'it' block was deleted
    if path_to_check then
      expect(fs.file_exists(path_to_check)).to.be_falsey("File should be cleaned up by runner hook")
    end
  end)

  it("should clean up file created within test", function()
    -- Create a temp file; its path will be checked in after_each
    local path = temp_file.create_with_content("cleanup test", "txt")
    expect(fs.file_exists(path)).to.be_truthy("File should exist initially")
    path_to_check = path -- Store path for after_each check
  end)
end)
```

**Note:** The examples in the previous version of this file incorrectly omitted the mandatory `error_handler.safe_io_operation` wrapper for core filesystem calls.

## Related Components / Modules

- **Module Under Test:** `lib/tools/filesystem/knowledge.md` (covers `init.lua`, `temp_file.lua`, `temp_file_integration.lua`).
- **Test Files:**
    - `tests/tools/filesystem/filesystem_test.lua`
    - `tests/tools/filesystem/temp_file_test.lua`
    - `tests/tools/filesystem/temp_file_integration_test.lua`
    - `tests/tools/filesystem/temp_file_stress_test.lua`
    - `tests/tools/filesystem/temp_file_performance_test.lua`
    - `tests/tools/filesystem/temp_file_timeout_test.lua`
- **Crucial Dependencies:**
    - **`lib/tools/error_handler/knowledge.md`**: Essential for correctly wrapping I/O operations with `safe_io_operation`.
    - **`lib/tools/test_helper/knowledge.md`**: Provides `with_temp_test_directory` for setting up controlled test environments.
- **Parent Overview:** `tests/tools/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **MANDATORY: Test with `safe_io_operation`:** Tests for `lib/tools/filesystem/init.lua` functions **must** demonstrate usage via `error_handler.safe_io_operation` and include assertions for both successful results and expected error objects (`err`).
- **Use `test_helper` for Controlled Environments:** Leverage `with_temp_test_directory` to create isolated and predictable filesystem states for testing core operations. Avoid tests that rely on the state of the actual project filesystem.
- **Explicitly Verify Cleanup:** When testing `temp_file.lua` or `temp_file_integration.lua`, include explicit `expect(fs.file_exists(...)).to.be_falsey()` assertions (often in `after_each`) to confirm that temporary resources were actually deleted.
- **Consider Platform Differences:** While the `filesystem` module aims to abstract platform differences, tests might still need to consider edge cases related to path formats, permissions, or available commands if testing low-level interactions or error conditions.

## Troubleshooting / Common Pitfalls (Optional)

- **Permission Errors:** Filesystem tests frequently fail due to insufficient permissions in the execution environment (e.g., CI server cannot write to `/tmp`, user lacks rights for a specific test directory). Ensure the process running tests has necessary read/write/delete permissions for temporary locations.
- **Incorrect Paths in Tests:** Using hardcoded paths, incorrect relative paths, or improperly joined paths can lead to "File not found" errors. Use `fs.join_paths` and consider using absolute paths derived from `test_helper` temporary directories. Log the paths being used for debugging.
- **Missing `safe_io_operation` Wrapper:** Tests might incorrectly pass if they call core filesystem functions directly and don't check the error return value, masking bugs in the library. Ensure the wrapper is used.
- **Temporary File Cleanup Failures:** If `after_each` checks show temp files persisting:
    - Check for errors during the test execution that might have prevented cleanup hooks from running.
    - Ensure the test runner environment correctly initialized the `temp_file_integration`.
    - Look for file locking issues (e.g., a file handle wasn't closed within the test or callback).
    - Check logs from `temp_file` or `temp_file_integration` for specific cleanup errors.
