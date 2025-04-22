# Filesystem Module Tests


This directory contains tests for the firmo filesystem module. The filesystem module provides cross-platform file operations for test runners and reporting.

## Directory Contents



- **filesystem_test.lua** - Tests for filesystem operations


## Filesystem Features


The firmo filesystem module provides:


- **Platform independence** - Works consistently across operating systems
- **Error handling** - Robust error handling with detailed messages
- **Path normalization** - Handles path differences between platforms
- **Directory operations** - Create, remove, and scan directories
- **File operations** - Read, write, copy, and delete files
- **Temporary files** - Create and manage temporary files and directories
- **Path manipulation** - Join, split, and normalize paths
- **Permission handling** - Set and check file permissions
- **File metadata** - Get file size, modification time, and type


## Common Usage Patterns



```lua
local fs = require "lib.tools.filesystem"
-- Reading a file
local content, err = fs.read_file("path/to/file.txt")
-- Writing a file
local success, err = fs.write_file("path/to/output.txt", content)
-- Creating a directory
local success, err = fs.mkdir("path/to/directory")
-- Checking if a file exists
local exists = fs.file_exists("path/to/file.txt")
-- Getting all files in a directory
local files = fs.get_files("path/to/directory", "*.lua")
```



## Platform Differences


The filesystem module automatically handles differences between:


- Windows (backslashes, drive letters)
- Unix/Linux (forward slashes, case sensitivity)
- macOS (resource forks, case insensitivity)


## Running Tests


To run all filesystem tests:


```text
lua test.lua tests/tools/filesystem/
```


To run a specific filesystem test:


```text
lua test.lua tests/tools/filesystem/filesystem_test.lua
```


See the [Filesystem API Documentation](/docs/api/filesystem.md) for more information.
