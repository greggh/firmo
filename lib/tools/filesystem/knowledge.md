# lib/tools/filesystem Knowledge

## Purpose

The `lib/tools/filesystem` module provides Firmo's primary interface for interacting with the file system. It offers a robust, cross-platform API for common file and directory operations, aiming for consistency across Windows, Linux, and macOS. Additionally, it includes a specialized sub-system (`temp_file.lua`) designed for creating and managing temporary files and directories, particularly within automated tests. This temporary file system features automatic cleanup capabilities, integrated with the Firmo test runner via `temp_file_integration.lua` to ensure resources are released after test execution.

## Key Concepts (Core Filesystem - `init.lua`)

- **Cross-Platform Abstraction:** A primary goal is to abstract away platform differences. The module internally handles variations in path separators (`/` vs `\`), external commands (`mkdir`, `rmdir`, `ls`, `dir`, `stat`), and error reporting to provide a unified Lua API.
- **Core Operations:** Offers a wide range of functions:
    - File I/O: `read_file`, `write_file`, `append_file`.
    - File Manipulation: `copy_file`, `move_file` (uses `os.rename` with copy+delete fallback), `delete_file` (aliased as `remove_file`).
    - Directory Management: `create_directory` (recursive), `ensure_directory_exists`, `delete_directory` (aliased as `remove_directory`, supports recursive).
    - Listing: `get_directory_contents` (files & dirs, aliased as `get_directory_items`, `list_directory`), `list_files` (non-recursive), `list_files_recursive`, `list_directories`.
- **Path Handling:** Provides essential utilities:
    - Normalization: `normalize_path` (converts separators, resolves `.`/`..`).
    - Joining: `join_paths(...)` (combines segments intelligently).
    - Extraction: `get_directory_name` (aliased as `dirname`, `get_directory`), `get_file_name` (aliased as `get_filename`), `basename`, `get_extension`.
    - Resolution: `get_absolute_path`, `get_relative_path`.
- **Discovery & Matching:** Facilitates finding specific files:
    - `find_files`: Searches based on Lua patterns.
    - `glob`: Uses shell-like glob patterns (limited `*`, `?`, `**` support).
    - `discover_files`: Advanced discovery across directories with include/exclude patterns.
    - `scan_directory`: Simple recursive/non-recursive file listing.
    - `matches_pattern`: Checks if a path matches a glob pattern.
    - `glob_to_pattern`: Converts glob to Lua pattern.
- **Metadata & Type Checking:** Allows inspecting files/directories:
    - Existence: `file_exists`, `directory_exists`.
    - Type: `is_file`, `is_directory`, `is_symlink`.
    - Metadata: `get_file_size`, `get_modified_time` (aliased as `get_file_modified_time`), `get_creation_time`.
- **Error Handling (CRITICAL):** All potentially failing I/O operations provided by this module (like `read_file`, `write_file`, `create_directory`, `list_files`, etc.) **MUST** be invoked using the wrapper `error_handler.safe_io_operation`. This ensures consistent error handling, adds relevant context (like the file path) automatically, and returns errors as standardized `error_handler` objects (`nil, error_object`). Non-I/O functions that might still fail logically (like `join_paths`) should be wrapped in `error_handler.try`. The module uses an internal `safe_io_action` wrapper which notably suppresses common "Permission denied" errors from flooding logs by default, returning `nil, nil` in those specific cases; `safe_io_operation` ensures these still produce a proper error object for the caller.

## Key Concepts (Temporary Files - `temp_file.lua` & `temp_file_integration.lua`)

- **Purpose:** To simplify the creation and guarantee the cleanup of temporary files and directories needed during the execution of automated tests. This prevents test runs from leaving leftover artifacts on the filesystem.
- **Automatic Cleanup:** Temporary resources created via `temp_file.lua` functions (like `create_with_content`, `create_temp_directory`) are automatically *registered*. The `temp_file_integration.lua` module patches the Firmo test runner (`lib.core.runner`) and the global `firmo` object. These patches ensure that after each test (`it` block) finishes, `temp_file.cleanup_test_context` is called to remove resources registered during that test. A final, more robust cleanup (`temp_file.cleanup_all` via `temp_file_integration.cleanup_all`) runs after the entire test suite completes to catch any remaining resources.
- **Context Management:** The integration works by wrapping `runner.execute_test`, `firmo.it`, and `firmo.describe`. These wrappers call `temp_file.set_current_test_context` before executing the test/suite function and `temp_file.clear_current_test_context` afterwards. This allows `temp_file.lua` to associate registered resources with the currently running test.
    *Note: While the integration sets a detailed test context (table with name, type, etc.), the current implementation of `temp_file.register_file` and `temp_file.register_directory` simplifies this internally and uses a single, hardcoded string context (`"_SIMPLE_STRING_CONTEXT_"`) for all registrations.*
- **Key Functions (`temp_file.lua`):**
    - `create_with_content(content, ext?)`: Creates a temp file, writes content, registers it, returns path.
    - `create_temp_directory()`: Creates a temp dir, registers it, returns path.
    - `register_file(path)` / `register_directory(path)`: Manually register existing items for cleanup.
    - `with_temp_file(content, callback, ext?)`: Creates file, calls `callback(path)`, cleans up. Returns callback result. **Preferred usage pattern.**
    - `with_temp_directory(callback)`: Creates dir, calls `callback(path)`, cleans up. Returns callback result. **Preferred usage pattern.**
    - `cleanup_test_context()` / `cleanup_all()`: Trigger cleanup manually (usually handled by integration).
    - `generate_temp_path(ext?)`: Creates a unique temporary path string (used internally).
- **Limitations:** Several functions documented in `temp_file.lua`'s header comments (e.g., `configure`, `set_temp_dir`, `get_registered_files`, `is_registered`) are currently **not implemented**.

## Usage Examples / Patterns

### Pattern 1: Reading a File (Mandatory Pattern)

```lua
--[[
  Safely read file content using safe_io_operation.
]]
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

local file_path = "config.json"
local content, err = error_handler.safe_io_operation(
  function() return fs.read_file(file_path) end,
  file_path,
  { context = "reading main config" } -- Optional context
)

if not content then
  print("Error reading file: " .. err.message)
  -- Handle error (err is an error_handler object)
else
  print("File content: " .. content)
  -- Process content
end
```

### Pattern 2: Writing a File (Mandatory Pattern)

```lua
--[[
  Safely write content to a file using safe_io_operation.
]]
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

local file_path = "output/result.txt"
local content_to_write = "Process completed."
local success, err = error_handler.safe_io_operation(
  function() return fs.write_file(file_path, content_to_write) end,
  file_path
)

if not success then
  print("Error writing file: " .. err.message)
  -- Handle error
else
  print("Successfully wrote to " .. file_path)
end
```

### Pattern 3: Ensuring Directory Exists (Mandatory Pattern)

```lua
--[[
  Safely ensure a directory exists using safe_io_operation.
]]
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

local dir_path = "logs/today"
local success, err = error_handler.safe_io_operation(
  function() return fs.ensure_directory_exists(dir_path) end,
  dir_path
)

if not success then
  print("Error creating/ensuring directory: " .. err.message)
  -- Handle error
else
  print("Directory exists or was created: " .. dir_path)
end
```

### Pattern 4: Listing Files Recursively (Mandatory Pattern)

```lua
--[[
  Safely list all files recursively using safe_io_operation.
]]
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

local dir_path = "src"
local file_list, err = error_handler.safe_io_operation(
  function() return fs.list_files_recursive(dir_path, true) end, -- Include hidden
  dir_path
)

if not file_list then
  print("Error listing files: " .. err.message)
  -- Handle error
else
  print("Found " .. #file_list .. " files in " .. dir_path)
  -- Process file_list
end
```

### Pattern 5: Joining Paths (Using `try`)

```lua
--[[
  Join path components safely using error_handler.try.
]]
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

local base = "/home/user"
local sub = "data"
local file = "file.txt"

local success, joined_path_or_err = error_handler.try(fs.join_paths, base, sub, file)

if not success then
  print("Error joining paths: " .. joined_path_or_err.message)
  -- Handle error (joined_path_or_err is the error object)
else
  print("Joined path: " .. joined_path_or_err)
end
```

### Pattern 6: Creating a Temporary File in a Test

```lua
--[[
  Example within a Firmo test using temp_file.
  Assumes temp_file_integration has patched the environment.
]]
local temp_file = require("lib.tools.filesystem.temp_file")
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

it("should process data from a temporary file", function()
  local content = "Data line 1\nData line 2"
  local temp_path, err = temp_file.create_with_content(content, "txt")
  expect(err).to_not.exist()
  expect(temp_path).to.be.a("string")

  -- Use the temp file
  local read_content, read_err = error_handler.safe_io_operation(fs.read_file, temp_path)
  expect(read_err).to_not.exist()
  expect(read_content).to.equal(content)

  -- No need to manually delete, cleanup happens automatically after the 'it' block
end)
```

### Pattern 7: Using `with_temp_directory` in a Test

```lua
--[[
  Example within a Firmo test using with_temp_directory.
]]
local temp_file = require("lib.tools.filesystem.temp_file")
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

it("should create files within a temporary directory", function()
  local result, err = temp_file.with_temp_directory(function(dir_path)
    expect(dir_path).to.be.a("string")
    local file1_path = fs.join_paths(dir_path, "file1.txt")
    local file2_path = fs.join_paths(dir_path, "subdir", "file2.log") -- Will create subdir

    local ok1, write_err1 = error_handler.safe_io_operation(fs.write_file, file1_path, "content1")
    expect(write_err1).to_not.exist()
    expect(ok1).to.be_truthy()

    local ok2, write_err2 = error_handler.safe_io_operation(fs.write_file, file2_path, "content2")
    expect(write_err2).to_not.exist()
    expect(ok2).to.be_truthy()

    return "Callback Success" -- Return value from callback
  end)

  expect(err).to_not.exist()
  expect(result).to.equal("Callback Success")
  -- Directory and its contents are automatically cleaned up after the callback
end)
```

## Related Components / Modules

- **`lib/tools/filesystem/init.lua`**: Source for core filesystem functions.
- **`lib/tools/filesystem/temp_file.lua`**: Source for temporary file management.
- **`lib/tools/filesystem/temp_file_integration.lua`**: Source for integration with test runner/framework.
- **`lib/tools/error_handler/knowledge.md`**: **Crucial dependency.** Explains the mandatory `safe_io_operation` wrapper and standardized error objects.
- **`lib/tools/discover/knowledge.md`**: Uses filesystem listing functions (`list_files`, etc.) to find test files.
- **`lib/tools/logging/knowledge.md`**: Used by `temp_file.lua` for logging temporary file operations and cleanup status.
- **`lib/core/runner/knowledge.md`**: The test runner, which is patched by `temp_file_integration.lua` to manage cleanup contexts.
- **`firmo.lua` Knowledge/API**: The main framework object, also patched by `temp_file_integration.lua` for context management in `it`/`describe`.

## Best Practices / Critical Rules (Optional)

- **MANDATORY: Use `error_handler.safe_io_operation`:** All calls to filesystem functions from `init.lua` (read, write, list, create, delete, etc.) **MUST** be wrapped in `error_handler.safe_io_operation`. This ensures consistent error handling, automatic context addition, and proper error object propagation. For non-I/O path functions like `join_paths` that can still fail, use `error_handler.try`.
- **Use `fs.join_paths`:** Always use `fs.join_paths(...)` to construct file paths from segments to ensure cross-platform compatibility and correct separator handling.
- **Use `temp_file.lua` for Tests:** Any temporary files or directories needed during test execution should be created using functions from `lib/tools/filesystem/temp_file.lua` (e.g., `create_with_content`, `create_temp_directory`, or preferably the `with_temp_file`/`with_temp_directory` wrappers) to guarantee automatic cleanup via the integration layer.
- **Check Return Values:** Always check the return values of filesystem operations (especially the `err` object when using `safe_io_operation` or `try`) to handle potential failures gracefully.

## Troubleshooting / Common Pitfalls (Optional)

- **Forgetting `safe_io_operation` / `try`:** This is the most common mistake. It can lead to uncaught Lua errors (e.g., `attempt to index a nil value` if an operation failed silently) or inconsistent error handling compared to the rest of the framework. **Symptom:** Raw Lua errors instead of structured error objects. **Solution:** Wrap the filesystem call correctly.
- **Permission Errors:** Filesystem operations often fail due to insufficient permissions for the user/process running Firmo. **Symptom:** `safe_io_operation` returns an error object with category `IO` and a message mentioning permissions. **Solution:** Check and adjust file/directory permissions on the system. Note the internal `safe_io_action` might sometimes suppress these unless `safe_io_operation` is used.
- **Path Issues:** Incorrect path separators, confusion between relative and absolute paths, or typos in paths. **Symptom:** "File not found", "Directory does not exist" errors. **Solution:** Use `fs.join_paths`, `fs.normalize_path`, `fs.get_absolute_path` to construct and verify paths. Use logging to print the exact paths being used.
- **Temporary Files Not Cleaned Up:**
    - **Symptom:** Temporary files/directories remain after test runs.
    - **Cause 1:** Files were created using raw `io.open` or core `fs` functions directly within a test, instead of using `lib/tools/filesystem/temp_file.lua`. **Solution:** Refactor test to use `temp_file` functions.
    - **Cause 2:** `temp_file_integration.initialize()` was not called early enough, or patching of the runner/firmo failed. **Solution:** Ensure initialization happens correctly. Check logs for patching errors.
    - **Cause 3:** A test suite experienced a fatal, unrecoverable error that prevented the final cleanup hooks from running. **Solution:** Address the fatal error. Manually clean up if necessary.
    - **Cause 4:** Resource locking (file still open or in use by another process) prevented deletion during cleanup attempts. **Solution:** Ensure resources are closed properly in tests. Check `temp_file_integration` logs for cleanup errors (might indicate which files failed).
