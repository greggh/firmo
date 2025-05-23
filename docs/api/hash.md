# Hash Module API Reference

The `hash` module provides utilities for generating hashes of strings and files. It uses a simple but fast FNV-1a hashing algorithm suitable for caching and change detection.

## Importing the Module

```lua
local hash = require("lib.tools.hash")
```

## Core Functions

### Hashing Strings

```lua
local hash_str = hash.hash_string(str)
```

Generate a hash for a string. Throws a validation error (via `error_handler`) if the input is not a string.
**Parameters:**

- `str` (string): The string to hash

**Returns:**

- `hash_str` (string): The 32-bit FNV-1a hash as an 8-character hexadecimal string.

**Example:**

```lua
local str_hash = hash.hash_string("Hello, world!")
print(str_hash)  -- e.g., "a5f3c678"
```

### Hashing Files

```lua
local hash_str, err = hash.hash_file(path)
```

Generate a hash for a file's contents.
**Parameters:**

- `path` (string): Path to the file to hash

**Returns:**

- `hash_str` (string|nil): The 32-bit FNV-1a hash as an 8-character hexadecimal string, or `nil` if the file couldn't be read or the path was invalid.
- `error` (table|nil): An error handler object (`operation_error` or `validation_error`) if reading or input validation failed.

**Example:**

```lua
local file_hash = hash.hash_file("path/to/file.lua")
if file_hash then
  print(file_hash)  -- e.g., "b7d2f901"
end
```

## Error Handling

The module uses the standard `error_handler` system. `hash_string` throws an error for invalid input (typically caught using `pcall`), while `hash_file` returns `nil, error_object` for file read issues or invalid input path:

```lua
-- String hashing errors
local ok, err = pcall(function()
  hash.hash_string(123)  -- Wrong type
end)
-- err will contain validation error
-- File hashing errors
local hash_str, err = hash.hash_file("nonexistent.lua")
if not hash_str then
  print("Failed to hash file:", err.message)
end
```

## Module Version

```lua
hash._VERSION  -- e.g., "1.0.0"
```

The version of the hash module.
