# Temp File Module API Reference

The temp_file module provides comprehensive functionality for creating and managing temporary files and directories during tests, with automatic tracking, registration, and cleanup.

## Overview

The temp_file module makes it easy to create and clean up temporary files and directories, ensuring that tests don't leave orphaned resources behind. The module integrates with the Firmo test framework to automatically track which files belong to which tests and clean them up accordingly.

## Module Interface

```lua
local temp_file = require("lib.tools.temp_file")
```

## Core Functions

### File Creation and Management

#### `temp_file.create_with_content(content, extension)`

Creates a temporary file with the specified content and automatically registers it for cleanup.

```lua
local file_path, err = temp_file.create_with_content("Test content", "txt")
if not err then
  -- Use file_path
end
```

**Parameters:**
- `content` (string): Content to write to the file
- `extension` (string, optional): File extension without the dot (default: "tmp")

**Returns:**
- `file_path` (string|nil): Path to the created temporary file, or nil on error
- `error` (table|nil): Error object if file creation failed

#### `temp_file.create_temp_directory()`

Creates a temporary directory and registers it for automatic cleanup.

```lua
local dir_path, err = temp_file.create_temp_directory()
if not err then
  -- Use dir_path
end
```

**Returns:**
- `dir_path` (string|nil): Path to the created temporary directory, or nil on error
- `error` (table|nil): Error object if directory creation failed

#### `temp_file.generate_temp_path(extension)`

Generates a temporary file path without creating the file.

```lua
local temp_path = temp_file.generate_temp_path("log")
```

**Parameters:**
- `extension` (string, optional): File extension without the dot (default: "tmp")

**Returns:**
- `temp_path` (string): Path for a temporary file

### Resource Registration

#### `temp_file.register_file(file_path)`

Registers an existing file for automatic cleanup.

```lua
local registered = temp_file.register_file("/path/to/file.txt")
```

**Parameters:**
- `file_path` (string): Path to the file to register for cleanup

**Returns:**
- `file_path` (string): Path to the registered file (for method chaining)

#### `temp_file.register_directory(dir_path)`

Registers an existing directory for automatic cleanup.

```lua
local registered = temp_file.register_directory("/path/to/directory")
```

**Parameters:**
- `dir_path` (string): Path to the directory to register for cleanup

**Returns:**
- `dir_path` (string): Path to the registered directory (for method chaining)

### Resource Cleanup

#### `temp_file.remove(file_path)`

Safely removes a temporary file with proper error handling.

```lua
local success, err = temp_file.remove("/path/to/file.txt")
```

**Parameters:**
- `file_path` (string): Path to the temporary file to remove

**Returns:**
- `success` (boolean): Whether the file was successfully removed
- `error` (string|nil): Error message if removal failed

#### `temp_file.remove_directory(dir_path)`

Safely removes a temporary directory with proper error handling.

```lua
local success, err = temp_file.remove_directory("/path/to/directory")
```

**Parameters:**
- `dir_path` (string): Path to the temporary directory to remove

**Returns:**
- `success` (boolean): Whether the directory was successfully removed
- `error` (string|nil): Error message if removal failed

#### `temp_file.cleanup_test_context()`

Cleans up all temporary files and directories for the current test context.

```lua
local success, errors = temp_file.cleanup_test_context()
```

**Returns:**
- `success` (boolean): Whether all files were cleaned up successfully
- `errors` (table[]): Array of resources that could not be cleaned up

#### `temp_file.cleanup_all()`

Cleans up all registered temporary files and directories across all test contexts.

```lua
local success, errors, stats = temp_file.cleanup_all()
```

**Returns:**
- `success` (boolean): Whether all files were cleaned up successfully
- `errors` (table[]): Array of resources that could not be cleaned up
- `stats` (table): Statistics about the cleanup operation

### Convenience Patterns

#### `temp_file.with_temp_file(content, callback, extension)`

Creates a temporary file, passes it to a callback, and then removes it when the callback completes, regardless of success or failure.

```lua
local result, err = temp_file.with_temp_file("file content", function(temp_path)
  -- Use temp_path here
  return "Operation result"
end, "txt")
```

**Parameters:**
- `content` (string): Content to write to the file
- `callback` (function): Function to call with the temporary file path
- `extension` (string, optional): File extension without the dot (default: "tmp")

**Returns:**
- `result` (any|nil): Result from the callback function, or nil on error
- `error` (table|nil): Error object if operation failed

#### `temp_file.with_temp_directory(callback)`

Creates a temporary directory, passes it to a callback, and then removes it when the callback completes.

```lua
local result, err = temp_file.with_temp_directory(function(dir_path)
  -- Use dir_path here
  return "Operation result"
end)
```

**Parameters:**
- `callback` (function): Function to call with the temporary directory path

**Returns:**
- `result` (any|nil): Result from the callback function, or nil on error
- `error` (table|nil): Error object if operation failed

### Statistics and Information

#### `temp_file.get_stats()`

Gets statistics about temporary files and their contexts.

```lua
local stats = temp_file.get_stats()
```

**Returns:**
- `stats` (table): Statistics about temporary files with the following fields:
  - `contexts` (number): Number of test contexts with registered resources
  - `total_resources` (number): Total number of registered resources
  - `files` (number): Number of registered files
  - `directories` (number): Number of registered directories
  - `resources_by_context` (table): Resources grouped by test context

## Integration with Test Framework

The temp_file module is designed to integrate with the Firmo test framework to automatically track and clean up temporary resources.

### `temp_file.set_current_test_context(context)`

Sets the current test context for automatic registration. This is typically called by the test runner.

```lua
temp_file.set_current_test_context(test_object)
```

**Parameters:**
- `context` (table|string): The test context to set

### `temp_file.clear_current_test_context()`

Clears the current test context after tests complete. This is typically called by the test runner.

```lua
temp_file.clear_current_test_context()
```

## Temp File Integration Module

The temp_file_integration module provides additional functionality to integrate the temp_file module with the Firmo test framework.

```lua
local temp_file_integration = require("lib.tools.temp_file_integration")
```

### Key Functions

#### `temp_file_integration.initialize(firmo_instance)`

Initializes the temp file integration with the Firmo test framework.

```lua
temp_file_integration.initialize(firmo)
```

**Parameters:**
- `firmo_instance` (table, optional): Firmo instance to integrate with. If not provided, will use global Firmo instance.

**Returns:**
- `success` (boolean): Whether the initialization was successful

#### `temp_file_integration.patch_runner(runner)`

Patches a test runner to handle temp file tracking and cleanup automatically.

```lua
temp_file_integration.patch_runner(runner)
```

**Parameters:**
- `runner` (table): The test runner instance to patch

**Returns:**
- `success` (boolean): Whether the patching was successful
- `error` (string|nil): Error message if patching failed

#### `temp_file_integration.cleanup_all(max_attempts)`

Cleans up all managed temporary files with multiple attempts for resilience.

```lua
local success, errors, stats = temp_file_integration.cleanup_all(3)
```

**Parameters:**
- `max_attempts` (number, optional): Number of cleanup attempts to make (default: 2)

**Returns:**
- `success` (boolean): Whether the cleanup was completely successful
- `errors` (table|nil): List of resources that could not be cleaned up
- `stats` (table|nil): Statistics about the cleanup operation

## Example Usage

### Basic Usage

```lua
local temp_file = require("lib.tools.temp_file")

-- Create a temporary file with content
local file_path, err = temp_file.create_with_content("File content", "txt")
if err then
  print("Error: " .. tostring(err))
  return
end

-- Use the file...

-- Clean up when done
temp_file.remove(file_path)
```

### Automatic Cleanup with Test Integration

```lua
local firmo = require("firmo")
local temp_file = require("lib.tools.temp_file")
local temp_file_integration = require("lib.tools.temp_file_integration")

-- Initialize temp file integration with Firmo
temp_file_integration.initialize(firmo)

-- In tests, create temporary files that will be automatically cleaned up
firmo.describe("File operations", function()
  firmo.it("should process files correctly", function()
    local file_path, err = temp_file.create_with_content("Test data", "dat")
    firmo.expect(err).to_not.exist()
    
    -- Test code that uses the file
    -- No need to clean up - it will be handled automatically
  end)
end)
```

### Using the With-Pattern

```lua
local temp_file = require("lib.tools.temp_file")

-- Create a temporary file, use it, and clean it up automatically
local result, err = temp_file.with_temp_file("Config data", function(temp_path)
  -- Use the temporary file
  -- ...
  return "Operation completed"
end, "cfg")

if err then
  print("Error: " .. tostring(err))
else
  print("Result: " .. result)
end
```