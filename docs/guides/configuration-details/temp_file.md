# Temporary File Management Configuration

This document describes the comprehensive configuration options for the firmo temporary file management system, which creates, tracks, and cleans up temporary files and directories during test execution.

## Overview

The temporary file module provides a robust system for managing temporary files with support for:

- Automatic tracking and cleanup of temporary files
- Test context-aware file management
- Secure file and directory creation
- Detailed file tracking and statistics
- Configurable cleanup policies
- Integration with the central configuration system

## Configuration Options

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `temp_dir` | string | System temp | Base directory for temporary files. |
| `force_cleanup` | boolean | `true` | Force removal of files even if errors occur. |
| `file_prefix` | string | `"firmo-"` | Prefix for all generated temporary files. |
| `auto_register` | boolean | `true` | Automatically register files with the current test context. |
| `cleanup_on_exit` | boolean | `true` | Clean up all registered files when the process exits. |
| `track_orphans` | boolean | `true` | Track and report orphaned temporary files. |
| `cleanup_delay` | number | `0` | Delay in seconds before removing files (0 = immediate). |

## Configuration in .firmo-config.lua

You can configure the temporary file management system in your `.firmo-config.lua` file:

```lua
return {
  -- Temporary file management configuration
  temp_file = {
    -- File storage
    temp_dir = "/tmp/firmo-tests",  -- Custom temporary directory
    file_prefix = "firmo-test-",    -- Custom file prefix
    
    -- Cleanup behavior
    force_cleanup = true,           -- Force cleanup even if errors occur
    auto_register = true,           -- Automatically register files with test context
    cleanup_on_exit = true,         -- Clean up on process exit
    track_orphans = true,           -- Track orphaned files
    cleanup_delay = 0,              -- No delay before cleanup
    
    -- Advanced options
    max_temp_files = 1000,          -- Maximum number of temp files (prevent runaway creation)
    orphan_age_threshold = 86400,   -- Consider files older than 24 hours as orphans
    secure_mode = true              -- Use secure file creation techniques
  }
}
```

## Programmatic Configuration

You can also configure the temporary file system programmatically:

```lua
local temp_file = require("lib.tools.temp_file")

-- Basic configuration
temp_file.configure({
  temp_dir = "./test-tmp",
  force_cleanup = true,
  file_prefix = "test-",
  auto_register = true
})

-- Set a specific temporary directory
temp_file.set_temp_dir("./my-test-temp")
```

## Creating Temporary Files

Create temporary files with automatic tracking:

```lua
-- Create an empty temporary file
local file_path, err = temp_file.create_temp_file("txt")
if not file_path then
  print("Error creating file:", err.message)
  return
end

-- Create a temporary file with content
local file_with_content, err = temp_file.create_with_content(
  "This is test content",
  "lua"  -- File extension
)

-- Create a temporary directory
local dir_path, err = temp_file.create_temp_directory()
```

## Test Context Integration

Manage files within test context for automatic cleanup:

```lua
-- Set the current test context
temp_file.set_current_test_context({
  name = "database_test",
  file = "tests/database_test.lua"
})

-- Create files associated with this context
local file1 = temp_file.create_with_content("data", "json")
local file2 = temp_file.create_with_content("logs", "txt")

-- Files will be automatically cleaned up when the test completes
-- ...

-- Clear the context when test is done
temp_file.clear_current_test_context()
```

## Using Temporary Files Safely

```lua
-- Use a temporary file with automatic cleanup
temp_file.with_temp_file("test content", function(file_path)
  -- Use the file
  local content = fs.read_file(file_path)
  process_data(content)
  
  -- File is automatically removed after function returns
end, "json")

-- Use a temporary directory with automatic cleanup
temp_file.with_temp_directory(function(dir_path)
  -- Use the directory
  fs.write_file(dir_path .. "/config.json", "{}")
  fs.write_file(dir_path .. "/data.txt", "test data")
  
  run_tests_with_config(dir_path .. "/config.json")
  
  -- Directory and all its contents are removed after function returns
end)
```

## Managing Existing Files

Register existing files for cleanup:

```lua
-- Register an existing file for cleanup
local file_path = "/path/to/existing/file.txt"
temp_file.register_file(file_path)

-- Register an existing directory for cleanup
local dir_path = "/path/to/existing/directory"
temp_file.register_directory(dir_path)

-- Check if a file is registered
if temp_file.is_registered(file_path) then
  print("File is registered for cleanup")
end
```

## Cleanup Management

Control the cleanup process:

```lua
-- Clean up files for a specific test context
temp_file.cleanup_test_context("my_test_context")

-- Clean up all registered files
local success, removed_files, errors = temp_file.cleanup_all()
print("Removed " .. #removed_files .. " files")
if #errors > 0 then
  print("Encountered " .. #errors .. " errors during cleanup")
end

-- Get statistics about temp file usage
local stats = temp_file.get_stats()
print("Registered files: " .. stats.registered_files)
print("Registered directories: " .. stats.registered_directories)
print("Total size: " .. stats.total_size .. " bytes")
print("Orphaned files: " .. stats.orphaned_files)
```

## Integration with Test Runner

The temporary file module integrates with Firmo's test runner:

```lua
-- In test runner (before tests)
local temp_file = require("lib.tools.temp_file")

-- Configure temp file management
temp_file.configure({
  temp_dir = "./test-tmp",
  cleanup_on_exit = true,
  track_orphans = true
})

-- Before each test
before_each(function()
  -- Set context for the current test
  temp_file.set_current_test_context(test_info)
end)

-- After each test
after_each(function()
  -- Clean up files for the test
  temp_file.cleanup_test_context()
  -- Clear the context
  temp_file.clear_current_test_context()
end)

-- After all tests
after_all(function()
  -- Clean up any remaining files
  temp_file.cleanup_all()
  
  -- Check for orphaned files
  local orphans = temp_file.find_orphans()
  if #orphans > 0 then
    print("Warning: Found " .. #orphans .. " orphaned temporary files")
  end
end)
```

## Best Practices

### Secure File Management

```lua
-- Configure for secure file management
temp_file.configure({
  secure_mode = true,         -- Use secure file creation techniques
  temp_dir = "/tmp/firmo-isolated",  -- Use isolated directory
  file_prefix = "secure-",    -- Distinct prefix for tracking
  force_cleanup = true        -- Always clean up files
})

-- Create files with unpredictable names
local file_path = temp_file.create_with_content(
  sensitive_data,
  "dat"
)

-- Always handle cleanup errors
local success, removed, errors = temp_file.cleanup_test_context()
if not success then
  logger.error("Failed to clean up temporary files", {
    context = temp_file.get_current_test_context(),
    removed_count = #removed,
    error_count = #errors
  })
end
```

### Efficient Test Setup with Temporary Files

```lua
-- Create a test directory structure efficiently
temp_file.with_temp_directory(function(base_dir)
  -- Create subdirectories
  fs.create_directory(base_dir .. "/config")
  fs.create_directory(base_dir .. "/data")
  fs.create_directory(base_dir .. "/logs")
  
  -- Create configuration files
  temp_file.create_with_content('{"test": true}', base_dir .. "/config/settings.json")
  temp_file.create_with_content('DATABASE=sqlite\nPATH=./data', base_dir .. "/config/env")
  
  -- Run tests with this directory structure
  run_application_tests(base_dir)
  
  -- All files and directories cleaned up automatically
end)
```

### CI/CD Environment Setup

For continuous integration environments:

```lua
-- In .firmo-config.ci.lua
return {
  temp_file = {
    temp_dir = "./ci-temp",   -- Use local directory in CI
    cleanup_on_exit = true,   -- Always clean up in CI
    force_cleanup = true,     -- Force cleanup even if errors occur
    track_orphans = true,     -- Track orphaned files
    max_temp_files = 5000,    -- Higher limit for CI test suites
    debug_mode = true         -- Enable detailed logging for CI
  }
}
```

## Troubleshooting

### Common Issues

1. **Files not being cleaned up**:
   - Verify the test context is being properly set with `set_current_test_context()`
   - Check if files are registered correctly with `is_registered(path)`
   - Ensure `cleanup_on_exit` is enabled
   - Look for errors during cleanup with detailed logging

2. **Permission errors**:
   - Check if the `temp_dir` has correct permissions
   - Verify the process has write permissions to the temporary directory
   - On some systems, use a user-specific directory instead of system temp

3. **Too many open files**:
   - Use `with_temp_file()` to ensure proper file closing
   - Limit concurrent file creation in parallel tests
   - Configure `max_temp_files` to prevent runaway file creation

4. **Orphaned files**:
   - Run `find_orphans()` to identify orphaned files
   - Check if proper test contexts are being used
   - Ensure `cleanup_test_context()` is called after tests

## Example Configuration Files

### Development Configuration

```lua
-- .firmo-config.development.lua
return {
  temp_file = {
    temp_dir = "./dev-temp",      -- Local temp directory
    file_prefix = "dev-test-",    -- Recognize dev files
    cleanup_on_exit = true,       -- Clean up on exit
    track_orphans = true,         -- Track orphans
    debug_mode = true             -- Detailed logging for development
  }
}
```

### CI Configuration

```lua
-- .firmo-config.ci.lua
return {
  temp_file = {
    temp_dir = "./ci-temp",       -- CI-specific directory
    file_prefix = "ci-test-",     -- CI-specific prefix
    cleanup_on_exit = true,       -- Always clean up in CI
    force_cleanup = true,         -- Force cleanup in CI
    track_orphans = true,         -- Report orphans in CI
    max_temp_files = 10000,       -- Higher limit for CI test suite
    orphan_report_file = "temp-file-report.txt" -- Save orphan report
  }
}
```

### Production Test Configuration

```lua
-- .firmo-config.production.lua
return {
  temp_file = {
    temp_dir = "/tmp/firmo-prod-tests", -- System temp with specific subdir
    file_prefix = "prod-test-",         -- Production test prefix
    cleanup_on_exit = true,             -- Always clean up
    force_cleanup = true,               -- Force cleanup
    secure_mode = true,                 -- Use secure mode for production tests
    track_orphans = false,              -- No orphan tracking needed
    cleanup_delay = 0                   -- Immediate cleanup
  }
}
```

These configuration options give you complete control over temporary file management, ensuring clean test environments and preventing file leaks in your test suite.