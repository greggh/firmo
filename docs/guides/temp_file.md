# Temporary File Management Guide


This guide explains how to use Firmo's temporary file management system to create, use, and clean up temporary files and directories in your tests.

## Introduction


When writing tests, you often need to create temporary files or directories to test functionality that interacts with the file system. Firmo provides a comprehensive system for managing temporary resources:


- Automatic creation of temporary files and directories
- Tracking of resources to ensure proper cleanup
- Integration with the test framework to associate resources with specific tests
- Cleanup patterns that work even when tests fail

Using the temp_file module properly will ensure your tests don't leave orphaned temporary files and directories behind, keeping your system clean and preventing test interference.

## Getting Started


### Basic Temporary File Creation


The simplest way to create a temporary file is with `create_with_content`:


```lua
local temp_file = require("lib.tools.filesystem.temp_file")
local fs = require("lib.tools.filesystem")
-- Create a temporary file with content
local file_path, err = temp_file.create_with_content("This is test content", "txt")
if err then
  -- Handle error
  print("Error creating file: " .. tostring(err))
  return
end
-- Use the file
print("File created at: " .. file_path)
-- Verify the content if needed
local content = fs.read_file(file_path)
```



### Creating Temporary Directories


For cases where you need a directory structure for testing:


```lua
local dir_path, err = temp_file.create_temp_directory()
if err then
  -- Handle error
  print("Error creating directory: " .. tostring(err))
  return
end
-- Use the directory
print("Directory created at: " .. dir_path)
-- Create files within the directory
local file_path = dir_path .. "/test.txt"
fs.write_file(file_path, "Test content")
```



## Best Practices


### Using the With-Pattern


For simple use cases, the "with" pattern automatically handles cleanup:


```lua
-- Use a temporary file with automatic cleanup
local result, err = temp_file.with_temp_file("Config data", function(temp_path)
  -- Use the temporary file here
  local data = process_configuration(temp_path)
  return data
end, "cfg")
-- Use a temporary directory with automatic cleanup
local result, err = temp_file.with_temp_directory(function(dir_path)
  -- Use the temporary directory here
  setup_test_environment(dir_path)
  return run_tests(dir_path)
end)
```


These patterns ensure cleanup occurs even if an error is raised during execution, making your tests more robust.

### Registering External Files


If you create files through other means, you can still register them for automatic cleanup:


```lua
-- Create a file using a different mechanism
local file_path = os.tmpname()
local f = io.open(file_path, "w")
f:write("content")
f:close()
-- Register it for automatic cleanup
temp_file.register_file(file_path)
```



### Creating Complex Directory Structures


For tests that need a more complex directory structure:


```lua
-- Create a test directory
local test_dir, err = temp_file.create_temp_directory()
if err then return nil, err end
-- Create subdirectories
local config_dir = test_dir .. "/config"
fs.create_directory(config_dir)
local data_dir = test_dir .. "/data"
fs.create_directory(data_dir)
-- Create files in various directories
fs.write_file(config_dir .. "/settings.json", '{"debug": true}')
fs.write_file(data_dir .. "/sample.dat", "Sample data content")
fs.write_file(test_dir .. "/README.md", "# Test Directory")
-- All these will be cleaned up automatically when the test completes
```



## Integration with Firmo Tests


### Automatic Integration


The temp_file module integrates with Firmo's test framework to automatically track and clean up temporary resources:


```lua
local firmo = require("firmo")
local temp_file = require("lib.tools.filesystem.temp_file")
local temp_file_integration = require("lib.tools.filesystem.temp_file_integration")
-- Initialize the integration (usually done by the test runner)
temp_file_integration.initialize(firmo)
-- Now in your tests, temp files are automatically cleaned up
firmo.describe("File processor", function()
  firmo.it("should read config files", function()
    -- Create a temporary file for this test
    local file_path, err = temp_file.create_with_content('{"setting": true}', "json")
    firmo.expect(err).to_not.exist()

    -- Test code here...

    -- No need to clean up - it happens automatically when the test ends
  end)
end)
```



### Manual Cleanup


If you need more control, you can manually clean up resources:


```lua
-- Clean up all resources for the current test
local success, errors = temp_file.cleanup_test_context()
if not success then
  print("Cleanup failed with " .. #errors .. " errors")
end
-- Or clean up everything regardless of test context
local success, errors, stats = temp_file.cleanup_all()
```



## Advanced Usage


### Resource Statistics


You can get statistics about temporary resources:


```lua
local stats = temp_file.get_stats()
print("Total temporary resources: " .. stats.total_resources)
print("Files: " .. stats.files)
print("Directories: " .. stats.directories)
```



### Resilient Cleanup


For cases where files might be locked or in use, the integration module provides resilient cleanup with multiple attempts:


```lua
local temp_file_integration = require("lib.tools.filesystem.temp_file_integration")
-- Try multiple times to clean up resources
local success, errors, stats = temp_file_integration.cleanup_all(3)
```



## Troubleshooting


### Files Not Being Cleaned Up


If temporary files aren't being cleaned up properly:


1. **Check registration**: Make sure files are being created with `create_with_content` or manually registered with `register_file`
2. **Verify test context**: Ensure temp file integration is properly initialized
3. **Manual cleanup**: Try calling `temp_file.cleanup_all()` explicitly


### Permission Issues


If you encounter permission errors:


1. **Check file states**: Make sure files aren't still open or in use
2. **Verify directory permissions**: Ensure the test has permissions to both create and delete files in the temp directory
3. **Use proper cleanup**: The `remove_with_retry` internal function tries multiple approaches to handle permission issues


## Best Practices Summary



1. **Use the with-pattern** when possible for automatic cleanup
2. **Register all external files** created through other mechanisms
3. **Use `create_with_content`** instead of creating files manually
4. **Initialize integration** with Firmo for test context tracking
5. **Check cleanup success** for potential issues
6. **Clean up after tests** even if they fail (which happens automatically with proper integration)


## Conclusion


The temp_file module provides a robust solution for managing temporary files and directories in your tests. By following the patterns and best practices in this guide, you can ensure that your tests don't leave orphaned resources behind, leading to more reliable and maintainable tests.
