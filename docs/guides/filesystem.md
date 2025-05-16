# Filesystem Usage Guide

## Introduction

The filesystem module provides a robust, cross-platform interface for file and directory operations in Lua. This guide explains how to use the module effectively, covering common use cases, best practices, and migration strategies from standard Lua I/O functions.

## Getting Started

### Importing the Module

```lua
local fs = require("lib.tools.filesystem")
```

### Basic Usage

```lua
-- Create a directory
fs.create_directory("/path/to/directory")
-- Write a file
fs.write_file("/path/to/file.txt", "Hello, world!")
-- Read a file
local content = fs.read_file("/path/to/file.txt")
print(content)  -- "Hello, world!"
```

## File Operations

### Reading Files

```lua
-- Read an entire file
local content, err = fs.read_file("/path/to/file.txt")
if not content then
    print("Error reading file: " .. (err or "unknown error"))
    return
end
-- Process the content
print("File contains " .. #content .. " characters")
-- Read a file line by line
local lines = {}
for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
end
```

### Writing Files

```lua
-- Write a new file (creates parent directories if needed)
local success, err = fs.write_file("/path/to/new/file.txt", "File content")
if not success then
    print("Error writing file: " .. (err or "unknown error"))
    return
end
-- Overwrite an existing file
fs.write_file("/path/to/existing.txt", "New content")
```

### Appending to Files

```lua
-- Append to a file (creates file if it doesn't exist)
local success, err = fs.append_file("/path/to/log.txt", "New log entry\n")
if not success then
    print("Error appending to file: " .. (err or "unknown error"))
    return
end
```

### Working with Binary Files

The filesystem module handles binary files correctly without any special configuration:

```lua
-- Read binary file
local binary_data, err = fs.read_file("/path/to/image.jpg")
if not binary_data then
    print("Error reading binary file: " .. (err or "unknown error"))
    return
end
-- Write binary file
local success, err = fs.write_file("/path/to/copy.jpg", binary_data)
if not success then
    print("Error writing binary file: " .. (err or "unknown error"))
    return
end
```

### Copying Files

```lua
-- Copy a file to a new location
local success, err = fs.copy_file("/path/to/source.txt", "/path/to/destination.txt")
if not success then
    print("Error copying file: " .. (err or "unknown error"))
    return
end
```

### Moving Files

```lua
-- Move a file to a new location
local success, err = fs.move_file("/path/to/source.txt", "/path/to/destination.txt")
if not success then
    print("Error moving file: " .. (err or "unknown error"))
    return
end
```

### Deleting Files

```lua
-- Delete a file
local success, err = fs.delete_file("/path/to/file.txt")
if not success then
    print("Error deleting file: " .. (err or "unknown error"))
    return
end
```

## Directory Operations

### Creating Directories

```lua
-- Create a directory (including parent directories)
local success, err = fs.create_directory("/path/to/nested/directory")
if not success then
    print("Error creating directory: " .. (err or "unknown error"))
    return
end
```

### Ensuring Directories Exist

```lua
-- Create a directory only if it doesn't already exist
local success, err = fs.ensure_directory_exists("/path/to/directory")
if not success then
    print("Error ensuring directory exists: " .. (err or "unknown error"))
    return
end
```

### Listing Directory Contents

```lua
-- Get all files and directories in a directory
local contents, err = fs.get_directory_contents("/path/to/directory")
if not contents then
    print("Error listing directory: " .. (err or "unknown error"))
    return
end
for i, item in ipairs(contents) do
    local item_path = fs.join_paths("/path/to/directory", item)
    if fs.is_file(item_path) then
        print("File: " .. item)
    else
        print("Directory: " .. item)
    end
end
```

### Listing Files Only

```lua
-- Get only files in a directory (not subdirectories)
local files, err = fs.list_files("/path/to/directory")
if not files then
    print("Error listing files: " .. (err or "unknown error"))
    return
end
for _, file in ipairs(files) do
    print("File: " .. file)
end
```

### Recursive Directory Listing

```lua
-- Get all files in a directory and its subdirectories
local files, err = fs.list_files_recursive("/path/to/directory")
if not files then
    print("Error listing files recursively: " .. (err or "unknown error"))
    return
end
for _, file in ipairs(files) do
    print("File: " .. file)
end
```

### Finding Files by Pattern

```lua
-- Find files matching a pattern in a directory
local lua_files, err = fs.find_files("/path/to/directory", "%.lua$", false)
if not lua_files then
    print("Error finding files: " .. (err or "unknown error"))
    return
end
for _, file in ipairs(lua_files) do
    print("Lua file: " .. file)
end
```

### Deleting Directories

```lua
-- Delete an empty directory
local success, err = fs.delete_directory("/path/to/directory", false)
if not success then
    print("Error deleting directory: " .. (err or "unknown error"))
    return
end
-- Delete a directory and all its contents
local success, err = fs.delete_directory("/path/to/directory", true)
if not success then
    print("Error deleting directory recursively: " .. (err or "unknown error"))
    return
end
```

## Path Manipulation

### Joining Paths

```lua
-- Join path components
local path = fs.join_paths("/base", "subdirectory", "file.txt")
print(path)  -- "/base/subdirectory/file.txt"
-- Join paths with different separator styles
local path = fs.join_paths("/base/", "/subdirectory/", "file.txt")
print(path)  -- "/base/subdirectory/file.txt"
```

### Normalizing Paths

```lua
-- Normalize path with redundant components
local normalized = fs.normalize_path("/path//to/./unnecessary/../file.txt")
print(normalized)  -- "/path/to/file.txt"
-- Normalize Windows paths
local normalized = fs.normalize_path("C:\\Windows\\System32\\..\\Drivers")
print(normalized)  -- "C:/Windows/Drivers"
```

### Extracting Path Components

```lua
-- Get directory part of a path
local dir = fs.get_directory_name("/path/to/file.txt")
print(dir)  -- "/path/to"
-- Get file name from a path
local name = fs.get_file_name("/path/to/file.txt")
print(name)  -- "file.txt"
-- Get file extension
local ext = fs.get_extension("/path/to/file.txt")
print(ext)  -- "txt"
```

### Absolute and Relative Paths

```lua
-- Convert a relative path to absolute
local abs_path = fs.get_absolute_path("../file.txt")
print(abs_path)  -- "/absolute/path/file.txt"
-- Convert an absolute path to relative from a base
local rel_path = fs.get_relative_path("/home/user/project/src/file.lua", "/home/user/project")
print(rel_path)  -- "src/file.lua"
```

## File Discovery

### Matching Files with Glob Patterns

```lua
-- Find all Lua files in a directory
local lua_files = fs.discover_files({"/path/to/project"}, {"*.lua"})
for _, file in ipairs(lua_files) do
    print("Found Lua file: " .. file)
end
-- Find specific files excluding patterns
local config_files = fs.discover_files(
    {"/path/to/project"},  -- Directories to search
    {"*.json", "*.yml"},   -- Include patterns
    {"*test*", "*backup*"} -- Exclude patterns
)
```

### Testing File Patterns

```lua
-- Check if a file matches a pattern
if fs.matches_pattern("script.lua", "*.lua") then
    print("File is a Lua script")
end
-- More complex pattern matching
local is_jsx = fs.matches_pattern("/path/to/Component.jsx", "**/*.jsx")
```

### Scanning Directories

```lua
-- Scan a directory non-recursively
local files = fs.scan_directory("/path/to/directory", false)
for _, file in ipairs(files) do
    print("File: " .. file)
end
-- Scan a directory recursively
local all_files = fs.scan_directory("/path/to/directory", true)
for _, file in ipairs(all_files) do
    print("File: " .. file)
end
```

### Filtering Files

```lua
-- Get all files in a directory
local all_files = fs.scan_directory("/path/to/directory", true)
-- Filter to only Lua files
local lua_files = fs.find_matches(all_files, "*.lua")
for _, file in ipairs(lua_files) do
    print("Lua file: " .. file)
end
```

## File Information

### Checking Existence

```lua
-- Check if a file exists
if fs.file_exists("/path/to/file.txt") then
    print("File exists")
end
-- Check if a directory exists
if fs.directory_exists("/path/to/directory") then
    print("Directory exists")
end
```

### Checking File Type

```lua
-- Check if a path is a file
if fs.is_file("/path/to/something") then
    print("It's a file")
end
-- Check if a path is a directory
if fs.is_directory("/path/to/something") then
    print("It's a directory")
end
```

### Getting File Information

```lua
-- Get file size
local size, err = fs.get_file_size("/path/to/file.txt")
if size then
    print("File size: " .. size .. " bytes")
end
-- Get file modification time
local mod_time, err = fs.get_modified_time("/path/to/file.txt")
if mod_time then
    print("Last modified: " .. os.date("%Y-%m-%d %H:%M:%S", mod_time))
end
-- Get file creation time (when available)
local create_time, err = fs.get_creation_time("/path/to/file.txt")
if create_time then
    print("Created: " .. os.date("%Y-%m-%d %H:%M:%S", create_time))
end
```

## Temporary Files

For temporary file management, firmo provides a dedicated `temp_file` module that integrates with the filesystem module.

### Importing the Module

```lua
local temp_file = require("lib.tools.filesystem.temp_file")
```

### Creating Temporary Files

```lua
-- Create a temporary file with content
local file_path, err = temp_file.create_with_content("File content", "txt")
if not file_path then
    print("Error creating temporary file: " .. (err or "unknown error"))
    return
end
-- The file is automatically registered for cleanup when tests complete
```

### Creating Temporary Directories

```lua
-- Create a temporary directory
local dir_path, err = temp_file.create_temp_directory()
if not dir_path then
    print("Error creating temporary directory: " .. (err or "unknown error"))
    return
end
-- The directory is automatically registered for cleanup when tests complete
```

### Using Temporary Files with Callbacks

```lua
-- Create a temporary file, use it, and clean it up when done
local result, err = temp_file.with_temp_file("File content", function(path)
    -- Use the temporary file here
    local content = fs.read_file(path)
    return content -- This will be returned as 'result'
end, "txt")
-- Create a temporary directory, use it, and clean it up when done
local result, err = temp_file.with_temp_directory(function(path)
    -- Use the temporary directory here
    fs.write_file(fs.join_paths(path, "file.txt"), "Content")
    return true -- This will be returned as 'result'
end)
```

### Registering Existing Files for Cleanup

```lua
-- If you create files through other means, register them for cleanup
temp_file.register_file("/path/to/file.txt")
temp_file.register_directory("/path/to/directory")
```

### Creating Test Directory Structures

For more complex test scenarios, you can use the `test_helper` module to create directory structures:

```lua
local test_helper = require("lib.tools.test_helper")
-- Create a test directory
local test_dir = test_helper.create_temp_test_directory()
-- Create files in the directory
test_dir:create_file("config.json", '{"setting": "value"}')
test_dir:create_file("nested/file.txt", "Nested file content")
-- Use the directory in tests
local config_path = fs.join_paths(test_dir:path(), "config.json")
local content = fs.read_file(config_path)
```

### Creating Predefined Directory Structures

```lua
-- Create a directory with a predefined structure
test_helper.with_temp_test_directory({
    ["config.json"] = '{"setting": "value"}',
    ["data.txt"] = "Test data",
    ["nested/file.lua"] = "return {}"
}, function(dir_path, files, dir_obj)
    -- Test code here
    assert(fs.file_exists(fs.join_paths(dir_path, "config.json")))
end)
```

## Error Handling

All filesystem functions follow a consistent error handling pattern:

1. On success, they return the result
2. On failure, they return `nil` and an error message

```lua
local result, err = fs.some_function(args)
if not result then
    print("Error: " .. (err or "unknown error"))
    return
end
```

### Integration with Error Handler

The filesystem module integrates with firmo's error handler for structured error objects:

```lua
local error_handler = require("lib.tools.error_handler")
-- Use error_handler with filesystem operations
local success, result, err = error_handler.try(function()
    return fs.read_file("/path/to/file.txt")
end)
if not success then
    -- result contains the error object in this case
    print("Error category: " .. result.category)
    print("Error message: " .. result.message)
    return nil, result
end
-- result contains the file content in this case
return result
```

## Migration from Lua I/O Functions

### Reading Files

**Before:**

```lua
local file, err = io.open("data.txt", "r")
if not file then
    print("Error opening file: " .. (err or ""))
    return
end
local content = file:read("*a")
file:close()
return content
```

**After:**

```lua
local fs = require("lib.tools.filesystem")
local content, err = fs.read_file("data.txt")
if not content then
    print("Error reading file: " .. (err or ""))
    return
end
return content
```

### Writing Files

**Before:**

```lua
local file, err = io.open("output.txt", "w")
if not file then
    print("Error opening file: " .. (err or ""))
    return false
end
file:write("Hello, world!")
file:close()
return true
```

**After:**

```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.write_file("output.txt", "Hello, world!")
if not success then
    print("Error writing file: " .. (err or ""))
    return false
end
return true
```

### Appending to Files

**Before:**

```lua
local file, err = io.open("log.txt", "a")
if not file then
    print("Error opening file: " .. (err or ""))
    return false
end
file:write("New log entry\n")
file:close()
return true
```

**After:**

```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.append_file("log.txt", "New log entry\n")
if not success then
    print("Error appending to file: " .. (err or ""))
    return false
end
return true
```

### Checking if a File Exists

**Before:**

```lua
local file = io.open("data.txt", "r")
if file then
    file:close()
    return true
end
return false
```

**After:**

```lua
local fs = require("lib.tools.filesystem")
return fs.file_exists("data.txt")
```

### Creating a Directory

**Before:**

```lua
local success = os.execute('mkdir "new_dir"')
if not success then
    print("Failed to create directory")
    return false
end
return true
```

**After:**

```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.create_directory("new_dir")
if not success then
    print("Failed to create directory: " .. (err or ""))
    return false
end
return true
```

### Creating Nested Directories

**Before:**

```lua
local function create_recursive(path)
    local sep = package.config:sub(1,1)
    local current = ""
    for dir in path:gmatch("[^" .. sep .. "]+") do
        current = current .. dir .. sep
        os.execute('mkdir "' .. current .. '" 2>/dev/null')
    end
end
```

**After:**

```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.create_directory("path/to/nested/directory")
```

### Listing Directory Contents

**Before:**

```lua
local function list_directory(path)
    local handle
    if package.config:sub(1,1) == '\\' then
        -- Windows
        handle = io.popen('dir /b "' .. path .. '"')
    else
        -- Unix
        handle = io.popen('ls -1 "' .. path .. '"')
    end
    if not handle then
        return {}
    end
    local result = {}
    for file in handle:lines() do
        table.insert(result, file)
    end
    handle:close()
    return result
end
```

**After:**

```lua
local fs = require("lib.tools.filesystem")
local contents, err = fs.get_directory_contents(path)
if not contents then
    return {}
end
return contents
```

### Copying a File

**Before:**

```lua
local function copy_file(source, destination)
    local input = io.open(source, "rb")
    if not input then return false end

    local output = io.open(destination, "wb")
    if not output then
        input:close()
        return false
    end

    local content = input:read("*a")
    output:write(content)

    input:close()
    output:close()
    return true
end
```

**After:**

```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.copy_file(source, destination)
```

### Moving/Renaming a File

**Before:**

```lua
local success = os.rename(source, destination)
if not success then
    print("Failed to move file")
    return false
end
return true
```

**After:**

```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.move_file(source, destination)
if not success then
    print("Failed to move file: " .. (err or ""))
    return false
end
return true
```

## Best Practices

### File Path Handling

1. **Use join_paths for path construction**:

   ```lua
   local path = fs.join_paths(base_dir, "subdirectory", "file.txt")
   ```

2. **Always normalize user-provided paths**:

   ```lua
   local normalized = fs.normalize_path(user_path)
   ```

3. **Use absolute paths for clarity**:

   ```lua
   local abs_path = fs.get_absolute_path(relative_path)
   ```

4. **Check file existence before reading/writing**:

   ```lua
   if fs.file_exists(path) then
       -- Safe to read
   end
   ```

### Error Handling

1. **Always check return values**:

   ```lua
   local content, err = fs.read_file(path)
   if not content then
       -- Handle error
   end
   ```

2. **Provide detailed error messages**:

   ```lua
   if not content then
       print("Failed to read configuration from " .. path .. ": " .. (err or "unknown error"))
   end
   ```

3. **Use with error_handler for structured errors**:

   ```lua
   local success, result, err = error_handler.try(function()
       return fs.read_file(path)
   end)
   ```

### Performance Optimization

1. **Cache frequently accessed file content**:

   ```lua
   local config_cache = {}

   local function get_config(path)
       if not config_cache[path] then
           local content, err = fs.read_file(path)
           if not content then
               return nil, err
           end
           config_cache[path] = content
       end
       return config_cache[path]
   end
   ```

2. **Minimize directory scanning in tight loops**:

   ```lua
   -- Do this once
   local files = fs.list_files(directory)

   -- Then process the results
   for _, file in ipairs(files) do
       process_file(file)
   end
   ```

3. **Use filters to reduce the number of files processed**:

   ```lua
   local lua_files = fs.discover_files({project_dir}, {"*.lua"}, {"test/*"})
   ```

### Temporary File Management

1. **Always use temp_file module instead of os.tmpname()**:

   ```lua
   -- Bad:
   local temp_name = os.tmpname()

   -- Good:
   local temp_name, err = temp_file.create_with_content("", "tmp")
   ```

2. **Let the temp_file system handle cleanup**:

   ```lua
   -- Bad:
   local temp_path = temp_file.create_with_content(content)
   -- ... use temp_path ...
   temp_file.remove(temp_path)

   -- Good:
   local temp_path = temp_file.create_with_content(content)
   -- ... use temp_path ...
   -- No manual cleanup needed
   ```

3. **Use with_temp_file for controlled scope**:

   ```lua
   temp_file.with_temp_file(content, function(path)
       -- Use path within this function
       -- Automatically cleaned up when function ends
   end)
   ```

## Advanced Usage

### Working with Binary Data

```lua
-- Reading binary file content
local binary_data, err = fs.read_file("image.jpg")
-- Create a hex dump of binary content
local function hex_dump(data, bytes_per_line)
    bytes_per_line = bytes_per_line or 16
    local result = {}
    for i = 1, #data, bytes_per_line do
        local line = {}
        for j = i, math.min(i + bytes_per_line - 1, #data) do
            table.insert(line, string.format("%02X", data:byte(j)))
        end
        table.insert(result, table.concat(line, " "))
    end
    return table.concat(result, "\n")
end
-- Process binary data
print(hex_dump(binary_data:sub(1, 128)))
```

### File Watching and Monitoring

You can implement a simple file watching mechanism:

```lua
local function watch_file(path, callback, interval)
    interval = interval or 1  -- Default to 1 second

    local last_modified = fs.get_modified_time(path)
    if not last_modified then
        return nil, "File not found: " .. path
    end

    -- Start the watch loop
    local running = true

    -- Return a controller to stop watching
    local controller = {
        stop = function() running = false end
    }

    -- Run in a separate coroutine
    local co = coroutine.create(function()
        while running do
            local current_modified = fs.get_modified_time(path)
            if current_modified and current_modified > last_modified then
                last_modified = current_modified
                callback(path)
            end

            -- Wait for the next check
            os.execute("sleep " .. tostring(interval))
        end
    end)

    -- Start the coroutine
    coroutine.resume(co)

    return controller
end
-- Usage:
local controller = watch_file("config.json", function(path)
    print("File changed: " .. path)
    local content = fs.read_file(path)
    -- Process updated content
end, 2)  -- Check every 2 seconds
-- Later, to stop watching:
controller.stop()
```

### Recursive Directory Operations

```lua
-- Recursively process all files in a directory
local function process_directory(dir, callback)
    local files = fs.list_files_recursive(dir)
    for _, file in ipairs(files) do
        callback(file)
    end
end
-- Usage:
process_directory("/path/to/project", function(file)
    local ext = fs.get_extension(file)
    if ext == "lua" then
        -- Process Lua file
        local content = fs.read_file(file)
        -- Do something with content
    end
end)
```

### File-Based Configuration

```lua
local function load_config(config_path)
    if not fs.file_exists(config_path) then
        return nil, "Configuration file not found: " .. config_path
    end

    local content, err = fs.read_file(config_path)
    if not content then
        return nil, "Failed to read configuration: " .. (err or "unknown error")
    end

    -- Parse the configuration (example for Lua config)
    local config = {}
    local fn, load_err = load("return " .. content, "config", "t", config)
    if not fn then
        return nil, "Invalid configuration format: " .. load_err
    end

    local ok, result = pcall(fn)
    if not ok then
        return nil, "Error executing configuration: " .. result
    end

    return result
end
-- Usage:
local config, err = load_config("/path/to/config.lua")
if not config then
    print("Error loading configuration: " .. err)
    return
end
-- Use configuration
print("Setting: " .. (config.setting or "not found"))
```

## Integration with Logging

The filesystem module integrates with firmo's logging system for detailed diagnostics:

```lua
-- Configure verbose logging for filesystem operations
local logging = require("lib.tools.logging")
logging.configure({
    modules = {
        filesystem = {
            level = logging.LEVELS.DEBUG
        }
    }
})
-- Filesystem operations will now produce detailed logs
local fs = require("lib.tools.filesystem")
fs.read_file("config.json")  -- Will log detailed information about the operation
```

## Troubleshooting

### Common Issues and Solutions

1. **Permission Denied Errors**

   ```lua
   local content, err = fs.read_file("/root/private.txt")
   if not content and err and err:match("Permission denied") then
       print("You don't have permission to read this file. Try running with elevated privileges.")
   end
   ```

2. **File Not Found Errors**

   ```lua
   local content, err = fs.read_file(path)
   if not content and err and err:match("No such file") then
       print("File not found. Check that the path is correct.")
       print("Absolute path: " .. fs.get_absolute_path(path))
   end
   ```

3. **Cross-Platform Path Issues**

   ```lua
   -- Always use forward slashes and normalize paths
   local platform_path = "/path/on/unix"
   if package.config:sub(1,1) == '\\' then
       -- We're on Windows, so adjust the path
       platform_path = "C:\\path\\on\\windows"
   end

   -- Normalize to work on any platform
   local normalized = fs.normalize_path(platform_path)
   ```

4. **Temporary File Cleanup Issues**

   If temporary files are not being cleaned up, check that:

   - You're using `temp_file.create_with_content()` and not `os.tmpname()`
   - You're letting the test framework handle cleanup automatically
   - You register any manually created files with `temp_file.register_file()`

   You can manually clean up orphaned temporary files:

   ```lua
   temp_file.cleanup_all()
   ```

## Conclusion

The filesystem module provides a robust, cross-platform interface for file and directory operations in Lua. By following the patterns and best practices in this guide, you can create reliable code that works consistently across different operating systems and handles errors gracefully.
For a complete reference of all available functions, see the [Filesystem API Reference](../api/filesystem.md).
For practical examples, see the [Filesystem Examples](../../examples/filesystem_examples.md).
