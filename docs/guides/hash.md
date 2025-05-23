# Hash Module Guide

The hash module provides utilities for generating hashes of strings and files, primarily used for caching and change detection in the framework.

## Overview

The hash module implements a simple but fast FNV-1a hashing algorithm. This algorithm is:

- Fast to compute
- Has good distribution
- Suitable for caching and change detection
- Not cryptographically secure (do not use for security purposes)

## Basic Usage

### Hashing Strings

```lua
local hash = require("lib.tools.hash")
-- Hash a simple string
local str_hash = hash.hash_string("Hello, world!")
print(str_hash)  -- e.g., "a5f3c678"
-- Hash some data
local data = {
  name = "test",
  value = 42
}
local data_str = require("lib.tools.json").encode(data)
local data_hash = hash.hash_string(data_str)
```

### Hashing Files

```lua
local hash = require("lib.tools.hash")
-- Hash a file
local file_hash, err = hash.hash_file("path/to/file.lua")
if not file_hash then
  print("Failed to hash file:", err.message)
else
  print("File hash:", file_hash)
end
```

## Common Use Cases

### Caching

```lua
local hash = require("lib.tools.hash")
local cache = {}
local function get_cached_result(input)
  local input_hash = hash.hash_string(input)
  return cache[input_hash]
end
local function cache_result(input, result)
  local input_hash = hash.hash_string(input)
  cache[input_hash] = result
end
```

### Change Detection

```lua
local hash = require("lib.tools.hash")
local file_hashes = {}
local function has_file_changed(path)
  local current_hash = hash.hash_file(path)
  if not current_hash then
    return true  -- Assume changed if can't read file
  end

  local previous_hash = file_hashes[path]
  if not previous_hash then
    file_hashes[path] = current_hash
    return true
  end

  if current_hash ~= previous_hash then
    file_hashes[path] = current_hash
    return true
  end

  return false
end
```

## Best Practices

1. **Error Handling**: Always check for errors when hashing files
2. **Performance**: Cache hash results when appropriate
3. **Security**: Do not use for security purposes (not cryptographic)
4. **Validation**: Validate input types before hashing

## Common Pitfalls

1. **File Access**: Remember that file hashing can fail if:
   - File doesn't exist
   - No read permissions
   - File is locked

2. **Memory Usage**: For very large files:
   - File is read entirely into memory
   - Consider chunked reading for huge files

3. **String Length**: Very long strings may impact performance

## Integration with Other Modules

The hash module is commonly used with:

- **Cache Module**: For caching computed results
- **Filesystem Module**: For file operations
- **JSON Module**: For hashing structured data
- **Coverage Module**: For tracking file changes

## Example: Complete Caching System

```lua
local hash = require("lib.tools.hash")
local fs = require("lib.tools.filesystem")
local json = require("lib.tools.json")
-- Simple caching system
local Cache = {}
function Cache.new(cache_dir)
  local self = {
    dir = cache_dir,
    memory = {}
  }

  -- Ensure cache directory exists
  fs.create_directory(cache_dir)

  -- Get cached value
  function self:get(key, validator)
    -- Generate hash for key
    local key_hash = hash.hash_string(
      type(key) == "string" and key or json.encode(key)
    )

    -- Check memory cache
    local cached = self.memory[key_hash]
    if cached then
      return cached
    end

    -- Check file cache
    local cache_file = self.dir .. "/" .. key_hash
    if fs.file_exists(cache_file) then
      local content = fs.read_file(cache_file)
      if content then
        local value = json.decode(content)
        if not validator or validator(value) then
          self.memory[key_hash] = value
          return value
        end
      end
    end

    return nil
  end

  -- Set cached value
  function self:set(key, value)
    -- Generate hash for key
    local key_hash = hash.hash_string(
      type(key) == "string" and key or json.encode(key)
    )

    -- Update memory cache
    self.memory[key_hash] = value

    -- Update file cache
    local cache_file = self.dir .. "/" .. key_hash
    fs.write_file(cache_file, json.encode(value))
  end

  return self
end
-- Usage example
local cache = Cache.new("./.cache")
-- Cache some data
cache:set("example", {
  data = "test",
  timestamp = os.time()
})
-- Get cached data
local data = cache:get("example")
if data then
  print("Found cached data from:", os.date("%c", data.timestamp))
end
```

## Next Steps

After mastering the hash module, explore:

1. [Cache Module](./cache.md)
2. [Filesystem Module](./filesystem.md)
3. [JSON Module](./json.md)
4. [Coverage Module](./coverage.md)
