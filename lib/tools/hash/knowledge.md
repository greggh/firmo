# lib/tools/hash Knowledge

## Purpose

The `lib/tools/hash` module provides simple and fast utility functions for generating hash values from strings and file contents. Its primary aim is to offer a quick way to create identifiers or detect changes, prioritizing speed over cryptographic strength. It utilizes the FNV-1a algorithm for this purpose.

## Key Concepts

- **FNV-1a Algorithm:** The module implements the 32-bit variant of the Fowler–Noll–Vo hash function (FNV-1a). This algorithm is known for its simplicity, speed, and reasonably good distribution characteristics, making it suitable for non-cryptographic applications like keys in hash tables, quick identity checks, or basic change detection where resistance to deliberate collisions is not a requirement. **It is explicitly NOT designed for security purposes.**

- **`hash_string(str)` Function:**
    - **Input:** Takes a single argument, `str`, which must be a Lua string.
    - **Output:** Returns an 8-character lowercase hexadecimal string representing the calculated 32-bit FNV-1a hash of the input string.
    - **Error Handling:** If the input `str` is not of type `string`, this function throws a standard error object created via `error_handler.validation_error`. This error must be caught using `error_handler.try` or similar if the input type is uncertain.

- **`hash_file(path)` Function:**
    - **Input:** Takes a single argument, `path`, which must be a string representing the path to a file.
    - **Process:**
        1.  Validates that the `path` argument is a string. If not, it returns `nil` and a `validation_error` object.
        2.  Attempts to read the entire content of the file specified by `path` using `lib.tools.filesystem.read_file`. **Note:** This operation itself should ideally be wrapped in `error_handler.safe_io_operation` by the caller, although the `hash_file` function internally handles the specific error from `read_file`.
        3.  If `fs.read_file` fails (returns `nil, err`), `hash_file` creates a standard `error_handler.operation_error` object, adding context like the file path and the original error. It logs this error using `lib/tools/logging` (at ERROR level) and then returns `nil, error_object`.
        4.  If the file content is read successfully, it calls `hash_string` with the content.
        5.  Returns the hexadecimal hash string produced by `hash_string`, along with `nil` for the error (`hash_string, nil`).
    - **Error Handling Summary:** Returns `nil, error_object` for invalid path input or file read errors. Can potentially throw an error from the internal `hash_string` call if file content read somehow isn't a string (highly unlikely).

## Usage Examples / Patterns

### Pattern 1: Hashing a String

```lua
--[[
  Generate a hash for a simple string.
]]
local hash_util = require("lib.tools.hash")
local error_handler = require("lib.tools.error_handler") -- For catching potential errors

local my_string = "Hello, Firmo!"
local success, hash_or_err = error_handler.try(hash_util.hash_string, my_string)

if success then
  print("String: '" .. my_string .. "'")
  print("Hash: " .. hash_or_err) -- e.g., Hash: 09e9a1bb
else
  -- This would only happen if my_string wasn't a string
  print("Error hashing string: " .. hash_or_err.message)
end

-- Example hashing an empty string
local success_empty, hash_empty = error_handler.try(hash_util.hash_string, "")
if success_empty then
  print("Empty string hash: " .. hash_empty) -- e.g., Empty string hash: 811c9dc5
end
```

### Pattern 2: Hashing a File's Content

```lua
--[[
  Generate a hash for the content of a file, handling potential errors.
]]
local hash_util = require("lib.tools.hash")
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

local file_path = "path/to/your/file.txt"

-- Ensure file exists and has content for a meaningful example
local setup_ok, setup_err = error_handler.safe_io_operation(fs.write_file, file_path, "File content for hashing.")
if not setup_ok then
  print("Setup failed: Could not write test file: " .. setup_err.message)
  return
end

-- Attempt to hash the file
local file_hash, err = hash_util.hash_file(file_path)

if file_hash then
  print("Hash for file '" .. file_path .. "': " .. file_hash)
else
  -- err contains the standardized error object
  print("Error hashing file '" .. file_path .. "': " .. err.message)
  if err.context then
    -- Inspect context for details like original_error or path
    print("  Context: path=" .. tostring(err.context.path))
  end
end

-- Cleanup the example file
error_handler.safe_io_operation(fs.delete_file, file_path)

-- Example of a non-existent file
local non_existent_path = "path/does/not/exist.txt"
local hash_ne, err_ne = hash_util.hash_file(non_existent_path)
if not hash_ne then
  print("Hashing non-existent file failed as expected: " .. err_ne.message)
end
```

## Related Components / Modules

- **`lib/tools/hash/init.lua`**: The source code implementation of this module.
- **`lib/tools/filesystem/knowledge.md`**: The `hash_file` function depends on `lib.tools.filesystem.read_file` to access file contents. Callers should use `safe_io_operation` for filesystem calls.
- **`lib/tools/error_handler/knowledge.md`**: Used by `hash_file` to create and return standardized error objects for file read failures or invalid path inputs. `hash_string` throws errors created by this module. `error_handler.try` should be used to catch errors from `hash_string`.
- **`lib/tools/logging/knowledge.md`**: Used internally by `hash_file` to log errors encountered during file reading.

## Best Practices / Critical Rules (Optional)

- **NOT FOR SECURITY:** **CRITICAL:** The FNV-1a algorithm used here is **not cryptographically secure**. Do **NOT** use these hash functions for password storage, secure data integrity checks (where malicious modification is a concern), digital signatures, or any other security-sensitive application. Use dedicated cryptographic libraries (like LuaSec with OpenSSL bindings, or external tools) for such purposes.
- **Suitable Use Cases:** This module is appropriate for:
    - Generating keys for hash tables or caches.
    - Quick checks for potential changes in configuration files or data blobs (where collision probability is acceptable).
    - Creating simple, non-secure identifiers based on content.

## Troubleshooting / Common Pitfalls (Optional)

- **`hash_file` returns `nil, err`:**
    - **Cause:** The most common reason is that the file specified by `path` does not exist or the process lacks the necessary read permissions.
    - **Debugging:** Inspect the returned `err` object. The `err.message` will indicate failure to read. Check `err.context.path` to verify the path being accessed. Check `err.cause` (if present) for the underlying error from the filesystem module. Verify file existence and permissions manually.
    - **Cause 2:** The `path` argument provided was not a string. Check `err.category` (should be `VALIDATION`) and `err.context.provided_type`.
- **`hash_string` throws an error:**
    - **Cause:** The argument passed to `hash_string` was not a Lua `string` type.
    - **Debugging:** Ensure the value being passed is definitely a string. Use `type()` to check before calling if unsure. Wrap the call in `error_handler.try` to catch the thrown error gracefully.
