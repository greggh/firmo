# Filesystem Module API Reference

The filesystem module provides a comprehensive, platform-independent interface for file and directory operations in Lua. It is designed to work consistently across all operating systems while providing robust error handling, path manipulation, file discovery, and temporary file management capabilities.

## Importing the Module

```lua
local fs = require("lib.tools.filesystem")
```

## Core File Operations

### Reading Files

```lua
local content, err = fs.read_file(path)
```

Reads the entire contents of a file.

**Parameters:**
- `path` (string): Path to the file to read

**Returns:**
- `content` (string|nil): File contents or nil if the file cannot be read
- `err` (string|nil): Error message if the operation failed

### Writing Files

```lua
local success, err = fs.write_file(path, content)
```

Writes content to a file, creating the file and any necessary parent directories.

**Parameters:**
- `path` (string): Path to the file to write
- `content` (string): Content to write to the file

**Returns:**
- `success` (boolean|nil): True on success or nil on failure
- `err` (string|nil): Error message if the operation failed

### Appending to Files

```lua
local success, err = fs.append_file(path, content)
```

Appends content to an existing file, creating the file if it doesn't exist.

**Parameters:**
- `path` (string): Path to the file to append to
- `content` (string): Content to append to the file

**Returns:**
- `success` (boolean|nil): True on success or nil on failure
- `err` (string|nil): Error message if the operation failed

### Copying Files

```lua
local success, err = fs.copy_file(source, destination)
```

Copies a file from `source` to `destination`, creating any necessary parent directories.

**Parameters:**
- `source` (string): Path to the source file
- `destination` (string): Path to the destination file

**Returns:**
- `success` (boolean|nil): True on success or nil on failure
- `err` (string|nil): Error message if the operation failed

### Moving Files

```lua
local success, err = fs.move_file(source, destination)
```

Moves a file from `source` to `destination`, creating any necessary parent directories.

**Parameters:**
- `source` (string): Path to the source file
- `destination` (string): Path to the destination file

**Returns:**
- `success` (boolean|nil): True on success or nil on failure
- `err` (string|nil): Error message if the operation failed

### Deleting Files

```lua
local success, err = fs.delete_file(path)
```

Deletes a file.

**Parameters:**
- `path` (string): Path to the file to delete

**Returns:**
- `success` (boolean|nil): True on success or nil on failure
- `err` (string|nil): Error message if the operation failed

### Renaming Files or Directories

```lua
local success, err = fs.rename(old_path, new_path)
```

Renames a file or directory.

**Parameters:**
- `old_path` (string): Path to the file or directory to rename
- `new_path` (string): New path for the file or directory

**Returns:**
- `success` (boolean|nil): True on success or nil on failure
- `err` (string|nil): Error message if the operation failed

## Directory Operations

### Creating Directories

```lua
local success, err = fs.create_directory(path)
```

Creates a directory and any necessary parent directories.

**Parameters:**
- `path` (string): Path to the directory to create

**Returns:**
- `success` (boolean|nil): True on success or nil on failure
- `err` (string|nil): Error message if the operation failed

### Ensuring Directories Exist

```lua
local success, err = fs.ensure_directory_exists(path)
```

Creates a directory only if it doesn't already exist.

**Parameters:**
- `path` (string): Path to ensure exists

**Returns:**
- `success` (boolean|nil): True if the directory exists or was created successfully, or nil on failure
- `err` (string|nil): Error message if the operation failed

### Getting Directory Contents

```lua
local contents, err = fs.get_directory_contents(path)
```

Lists the contents of a directory.

**Parameters:**
- `path` (string): Path to the directory to list

**Returns:**
- `contents` (table|nil): Table of file and directory names or nil on failure
- `err` (string|nil): Error message if the operation failed

### Getting Directory Items

```lua
local items, err = fs.get_directory_items(path, include_hidden)
```

Gets all items (files and directories) in a directory.

**Parameters:**
- `path` (string): Path to the directory to list
- `include_hidden` (boolean, optional): Whether to include hidden files (default: false)

**Returns:**
- `items` (table|nil): Table of file and directory names or nil on failure
- `err` (string|nil): Error message if the operation failed

### Listing Files

```lua
local files, err = fs.list_files(path, include_hidden)
```

Lists only files (not directories) in a directory.

**Parameters:**
- `path` (string): Path to the directory to list
- `include_hidden` (boolean, optional): Whether to include hidden files (default: false)

**Returns:**
- `files` (table|nil): Table of file names or nil on failure
- `err` (string|nil): Error message if the operation failed

### Listing Files Recursively

```lua
local files, err = fs.list_files_recursive(path, include_hidden)
```

Lists all files in a directory and its subdirectories.

**Parameters:**
- `path` (string): Path to the directory to list
- `include_hidden` (boolean, optional): Whether to include hidden files (default: false)

**Returns:**
- `files` (table|nil): Table of file paths or nil on failure
- `err` (string|nil): Error message if the operation failed

### Listing Directories

```lua
local dirs, err = fs.list_directories(path, include_hidden)
```

Lists only directories (not files) in a directory.

**Parameters:**
- `path` (string): Path to the directory to list
- `include_hidden` (boolean, optional): Whether to include hidden directories (default: false)

**Returns:**
- `dirs` (table|nil): Table of directory names or nil on failure
- `err` (string|nil): Error message if the operation failed

### Deleting Directories

```lua
local success, err = fs.delete_directory(path, recursive)
```

Deletes a directory.

**Parameters:**
- `path` (string): Path to the directory to delete
- `recursive` (boolean, optional): If true, deletes all contents recursively (default: false)

**Returns:**
- `success` (boolean|nil): True on success or nil on failure
- `err` (string|nil): Error message if the operation failed

## Path Manipulation

### Normalizing Paths

```lua
local normalized = fs.normalize_path(path)
```

Standardizes path separators and removes redundant elements. Always uses forward slashes (`/`) as the path separator, regardless of platform.

**Parameters:**
- `path` (string): Path to normalize

**Returns:**
- `normalized` (string|nil): Normalized path or nil if path is nil

### Joining Paths

```lua
local joined = fs.join_paths(path1, path2, ...)
```

Combines multiple path segments into a single path, handling separators appropriately.

**Parameters:**
- `path1, path2, ...` (string): Path segments to join

**Returns:**
- `joined` (string|nil): Joined path or nil on error
- `err` (string|nil): Error message if the operation failed

### Getting Directory Name

```lua
local dir = fs.get_directory_name(path)
```

Extracts the directory component from a path.

**Parameters:**
- `path` (string): Path to process

**Returns:**
- `dir` (string|nil): Directory component of path or nil if path is nil

### Getting File Name

```lua
local name = fs.get_file_name(path)
```

Extracts the file name component from a path.

**Parameters:**
- `path` (string): Path to process

**Returns:**
- `name` (string|nil): File name component of path or nil on error
- `err` (string|nil): Error message if the operation failed

### Getting File Extension

```lua
local ext = fs.get_extension(path)
```

Extracts the file extension from a path (without the dot).

**Parameters:**
- `path` (string): Path to process

**Returns:**
- `ext` (string|nil): File extension (without the dot) or empty string if no extension, nil on error
- `err` (string|nil): Error message if the operation failed

### Changing File Extension

```lua
local new_path = fs.change_extension(path, new_ext)
```

Changes the extension of a file path.

**Parameters:**
- `path` (string): Path to process
- `new_ext` (string): New extension (without the dot)

**Returns:**
- `new_path` (string): Path with the new extension

### Getting Absolute Path

```lua
local abs_path = fs.get_absolute_path(path)
```

Converts a relative path to an absolute path.

**Parameters:**
- `path` (string): Path to convert

**Returns:**
- `abs_path` (string|nil): Absolute path or nil on error
- `err` (string|nil): Error message if the operation failed

### Getting Relative Path

```lua
local rel_path = fs.get_relative_path(path, base)
```

Computes the relative path from `base` to `path`.

**Parameters:**
- `path` (string): Path to convert
- `base` (string): Base path to make relative to

**Returns:**
- `rel_path` (string|nil): Path relative to base or nil if path or base is nil

### Checking if Path is Absolute

```lua
local is_absolute = fs.is_absolute_path(path)
```

Checks if a path is absolute.

**Parameters:**
- `path` (string): Path to check

**Returns:**
- `is_absolute` (boolean): True if the path is absolute, false otherwise

### Getting Current Directory

```lua
local current_dir, err = fs.get_current_directory()
```

Gets the current working directory.

**Parameters:** None

**Returns:**
- `current_dir` (string|nil): Current working directory or nil on error
- `err` (string|nil): Error message if the operation failed

### Setting Current Directory

```lua
local success, err = fs.set_current_directory(dir_path)
```

Sets the current working directory.

**Parameters:**
- `dir_path` (string): Directory to set as current

**Returns:**
- `success` (boolean|nil): True on success or nil on failure
- `err` (string|nil): Error message if the operation failed

## File Discovery

### Converting Glob to Pattern

```lua
local pattern = fs.glob_to_pattern(glob)
```

Converts a glob pattern (like `*.lua`) to a Lua pattern string.

**Parameters:**
- `glob` (string): Glob pattern to convert

**Returns:**
- `pattern` (string|nil): Lua pattern equivalent or nil if glob is nil

### Matching Patterns

```lua
local matches = fs.matches_pattern(path, pattern)
```

Tests if a path matches a glob pattern.

**Parameters:**
- `path` (string): Path to test
- `pattern` (string): Glob pattern to match against

**Returns:**
- `matches` (boolean|nil): True if path matches pattern, nil on error
- `err` (string|nil): Error message if the operation failed

### Glob Pattern Matching

```lua
local files, err = fs.glob(pattern, base_dir)
```

Finds files matching a glob pattern.

**Parameters:**
- `pattern` (string): Glob pattern to match
- `base_dir` (string, optional): Base directory to search in (default: current directory)

**Returns:**
- `files` (table|nil): List of matching file paths or nil on error
- `err` (string|nil): Error message if the operation failed

### Discovering Files

```lua
local files, err = fs.discover_files(directories, patterns, exclude_patterns)
```

Finds all files in the specified directories that match any pattern in `patterns` and don't match any pattern in `exclude_patterns`.

**Parameters:**
- `directories` (table): List of root directories to search in
- `patterns` (table, optional): List of glob patterns to include (default: `{"*"}`)
- `exclude_patterns` (table, optional): List of glob patterns to exclude

**Returns:**
- `files` (table|nil): List of matching file paths or nil on error
- `err` (string|nil): Error message if the operation failed

### Scanning Directories

```lua
local files = fs.scan_directory(path, recursive)
```

Lists all files in a directory.

**Parameters:**
- `path` (string): Directory path to scan
- `recursive` (boolean): Whether to include files in subdirectories

**Returns:**
- `files` (table): List of absolute file paths found in the directory

### Finding Matches

```lua
local matches = fs.find_matches(files, pattern)
```

Filters a list of files to those matching a glob pattern.

**Parameters:**
- `files` (table): List of file paths to filter
- `pattern` (string): Glob pattern to match against

**Returns:**
- `matches` (table): List of matching file paths

### Finding Files

```lua
local files, err = fs.find_files(dir_path, pattern, recursive)
```

Finds files in a directory that match a pattern.

**Parameters:**
- `dir_path` (string): Directory to search in
- `pattern` (string): Lua pattern to match against file names
- `recursive` (boolean, optional): Whether to search in subdirectories (default: false)

**Returns:**
- `files` (table|nil): List of matching file paths or nil on error
- `err` (string|nil): Error message if the operation failed

### Finding Directories

```lua
local dirs, err = fs.find_directories(dir_path, pattern, recursive)
```

Finds directories in a directory that match a pattern.

**Parameters:**
- `dir_path` (string): Directory to search in
- `pattern` (string): Lua pattern to match against directory names
- `recursive` (boolean, optional): Whether to search in subdirectories (default: false)

**Returns:**
- `dirs` (table|nil): List of matching directory paths or nil on error
- `err` (string|nil): Error message if the operation failed

### Detecting Project Root

```lua
local root_dir, err = fs.detect_project_root(start_dir, markers)
```

Attempts to find the root directory of a project by looking for common project marker files.

**Parameters:**
- `start_dir` (string, optional): Directory to start searching from (default: current directory)
- `markers` (table, optional): List of marker files/directories to look for

**Returns:**
- `root_dir` (string|nil): Project root directory or nil if not found
- `err` (string|nil): Error message if an error occurred

## Information Functions

### Checking if File Exists

```lua
local exists = fs.file_exists(path)
```

Tests if a file exists and is readable.

**Parameters:**
- `path` (string): Path to the file to check

**Returns:**
- `exists` (boolean): True if the file exists and is readable

### Checking if Directory Exists

```lua
local exists = fs.directory_exists(path)
```

Tests if a directory exists and is accessible.

**Parameters:**
- `path` (string): Path to the directory to check

**Returns:**
- `exists` (boolean): True if the directory exists and is accessible

### Getting File Information

```lua
local info, err = fs.get_file_info(file_path)
```

Gets detailed information about a file.

**Parameters:**
- `file_path` (string): Path to the file

**Returns:**
- `info` (table|nil): Table containing file information or nil on error:
  - `size` (number): Size in bytes
  - `modified` (number): Last modified timestamp
  - `type` (string): File type
  - `is_directory` (boolean): Whether it's a directory
  - `is_file` (boolean): Whether it's a regular file
  - `is_link` (boolean): Whether it's a symbolic link
  - `permissions` (string): File permissions
- `err` (string|nil): Error message if the operation failed

### Getting File Size

```lua
local size, err = fs.get_file_size(path)
```

Gets the size of a file in bytes.

**Parameters:**
- `path` (string): Path to the file to check

**Returns:**
- `size` (number|nil): File size in bytes or nil on error
- `err` (string|nil): Error message if the operation failed

### Getting Modified Time

```lua
local time, err = fs.get_modified_time(path)
```

Gets the modification timestamp of a file or directory.

**Parameters:**
- `path` (string): Path to the file or directory

**Returns:**
- `time` (number|nil): Modification time as Unix timestamp or nil on error
- `err` (string|nil): Error message if the operation failed

### Getting File Modified Time

```lua
local time, err = fs.get_file_modified_time(path)
```

Gets the modification timestamp of a file.

**Parameters:**
- `path` (string): Path to the file

**Returns:**
- `time` (number|nil): Modification time as Unix timestamp or nil on error
- `err` (string|nil): Error message if the operation failed

### Getting Creation Time

```lua
local time, err = fs.get_creation_time(path)
```

Gets the creation timestamp of a file or directory.

**Parameters:**
- `path` (string): Path to the file or directory

**Returns:**
- `time` (number|nil): Creation time as Unix timestamp or nil on error
- `err` (string|nil): Error message if the operation failed

### Testing if Path is a File

```lua
local is_file = fs.is_file(path)
```

Tests if a path points to a file.

**Parameters:**
- `path` (string): Path to check

**Returns:**
- `is_file` (boolean): True if the path exists and is a file

### Testing if Path is a Directory

```lua
local is_dir = fs.is_directory(path)
```

Tests if a path points to a directory.

**Parameters:**
- `path` (string): Path to check

**Returns:**
- `is_dir` (boolean): True if the path exists and is a directory

## Temporary File Operations

The filesystem module is complemented by the `temp_file` module for temporary file management during tests:

```lua
local temp_file = require("lib.tools.temp_file")
```

### Creating Temporary Files

```lua
local temp_path, err = temp_file.create_with_content(content, extension)
```

Creates a temporary file with specified content.

**Parameters:**
- `content` (string): Content to write to the file
- `extension` (string, optional): File extension without the dot (default: "tmp")

**Returns:**
- `temp_path` (string|nil): Path to the created file or nil on error
- `err` (table|nil): Error object if file creation failed

### Creating Temporary Directories

```lua
local dir_path, err = temp_file.create_temp_directory()
```

Creates a temporary directory.

**Parameters:** None

**Returns:**
- `dir_path` (string|nil): Path to the created directory or nil on error
- `err` (table|nil): Error object if directory creation failed

### Registering Files for Cleanup

```lua
local registered = temp_file.register_file(file_path)
```

Registers an existing file for automatic cleanup when tests complete.

**Parameters:**
- `file_path` (string): Path to the file to register

**Returns:**
- `registered` (string): The file path that was registered

### Using Temporary Files with Callbacks

```lua
local result, err = temp_file.with_temp_file(content, callback, extension)
```

Creates a temporary file, uses it with a callback, and cleans it up.

**Parameters:**
- `content` (string): Content to write to the file
- `callback` (function): Function to call with the temporary file path
- `extension` (string, optional): File extension (default: "tmp")

**Returns:**
- `result` (any|nil): Result from the callback or nil on error
- `err` (table|nil): Error object if operation failed

### Using Temporary Directories with Callbacks

```lua
local result, err = temp_file.with_temp_directory(callback)
```

Creates a temporary directory, uses it with a callback, and cleans it up.

**Parameters:**
- `callback` (function): Function to call with the temporary directory path

**Returns:**
- `result` (any|nil): Result from the callback or nil on error
- `err` (table|nil): Error object if operation failed

### Cleaning Up Temporary Files

```lua
local success, errors = temp_file.cleanup_test_context()
```

Cleans up all temporary files and directories registered for the current test context.

**Parameters:** None

**Returns:**
- `success` (boolean): Whether all files were cleaned up successfully
- `errors` (table): Array of resources that could not be cleaned up

## Error Handling

All functions that can fail return two values:
1. The result value (or `nil` if an error occurred)
2. An error message (only present if an error occurred)

This allows for robust error handling:

```lua
local content, err = fs.read_file("/path/to/file.txt")
if not content then
    print("Error reading file: " .. (err or "unknown error"))
    return
end
```

## Platform Compatibility

The filesystem module works consistently across all platforms, including:
- Linux
- macOS
- Windows

It handles platform-specific differences internally, providing a consistent API regardless of the underlying operating system.

## Performance Considerations

- The module includes internal caching to avoid redundant operations
- Path normalization is optimized for frequent use
- Operations are designed to minimize system calls where possible
- For high-volume operations, consider batching changes to minimize I/O overhead