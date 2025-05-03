-- Comprehensive Temporary File Management Example
--
-- This example demonstrates the complete functionality of the temp_file module
-- including automatic tracking and cleanup of temporary files and directories.

-- Load firmo
package.path = "../?.lua;../lib/?.lua;" .. package.path
--- Comprehensive example demonstrating the Firmo temporary file management module.
---
--- This example showcases the features of `lib.tools.filesystem.temp_file`:
--- - Creating temporary files with initial content using `create_with_content()`.
--- - Creating temporary directories using `create_temp_directory()`.
--- - Using the `with_temp_file` and `with_temp_directory` patterns for automatic cleanup within a scope.
--- - Manually creating and registering files/directories for later cleanup.
--- - Retrieving statistics about tracked temporary resources using `get_stats()`.
--- - Explicitly cleaning up all tracked resources using `cleanup_all()`.
---
--- @module examples.temp_file_management_example
--- @see lib.tools.filesystem.temp_file
--- @see lib.tools.filesystem
--- @usage
--- Run this example directly to see temporary resources created and cleaned up:
--- ```bash
--- lua examples/temp_file_management_example.lua
--- ```

-- Import necessary modules
local temp_file = require("lib.tools.filesystem.temp_file")
local fs = require("lib.tools.filesystem")

-- Setup logger (optional, using print for direct execution clarity)
-- local logging = require("lib.tools.logging")
-- local logger = logging.get_logger("TempFileExample")

print("=== TEMPORARY FILE MANAGEMENT EXAMPLE ===\n")

print("1. Basic Temporary File Creation (create_with_content)")
print("-------------------------------------------------------")
print("Creating a temporary file with initial content...")
-- `create_with_content` automatically registers the file for cleanup.
local file_path, err = temp_file.create_with_content("This is test content", "txt")
if err then
  print("ERROR creating file: " .. tostring(err))
  os.exit(1)
end

print("File created: " .. file_path)

-- Verify file exists
if fs.file_exists(file_path) then
  print("File exists on disk ✓")
else
  print("ERROR: File does not exist")
  os.exit(1)
end

-- Read the content to verify
local content, read_err = fs.read_file(file_path)
if content then
  print('File content verified: "' .. content .. '" ✓')
else
  print("ERROR: Could not read file: " .. tostring(read_err))
end

print("\n2. Temporary Directory Creation (create_temp_directory)")
print("----------------------------------------------------------")
print("Creating a temporary directory...")
-- `create_temp_directory` automatically registers the directory for cleanup.
local dir_path, dir_err = temp_file.create_temp_directory()
if dir_err then
  print("ERROR creating directory: " .. tostring(dir_err))
  os.exit(1)
end

print("Directory created: " .. dir_path)

-- Create a file in the directory
local nested_file = dir_path .. "/nested.txt"
local write_success, write_err = fs.write_file(nested_file, "Nested file content")
if write_success then
  print("Created nested file in temp directory ✓")
else
  print("ERROR: Could not create nested file: " .. tostring(write_err))
end

print("\n3. Scoped Cleanup using 'with' Patterns")
print("-------------------------------------------")
print("Using with_temp_file for automatic cleanup...")

-- The file created by with_temp_file exists only within the callback function's scope.
local scoped_file_path -- To verify cleanup later
local result, with_err = temp_file.with_temp_file("Temporary content for callback", function(tmp_path)
  print("Inside callback with temporary file: " .. tmp_path)
  scoped_file_path = tmp_path -- Store path to check later
  local file_content, read_err_str = fs.read_file(tmp_path)
  if file_content then
    print('Successfully read content: "' .. file_content .. '" ✓')
    -- Simulate work...
    return "Callback result: OK" -- Return value from callback
  else
    -- Return nil, error to indicate failure within the callback
    return nil, "Failed to read file: " .. tostring(read_err_str)
  end
end, "lua") -- Optional extension 'lua'

if result then
  print("with_temp_file callback returned: " .. result .. " ✓")
  -- Verify the file was automatically cleaned up *after* the callback finished
  if not fs.file_exists(scoped_file_path) then
    print("Temporary file was automatically cleaned up ✓")
  else
    print("ERROR: Temporary file from with_temp_file still exists!")
  end
else
  print("ERROR during with_temp_file callback: " .. tostring(with_err))
end

print("\nUsing with_temp_directory for automatic cleanup...")
local scoped_dir_path -- To verify cleanup later
local dir_result, dir_with_err = temp_file.with_temp_directory(function(tmp_dir_path)
  print("Inside callback with temporary directory: " .. tmp_dir_path)
  scoped_dir_path = tmp_dir_path

  -- Create a file inside this temp directory
  local success, err = fs.write_file(fs.join_paths(tmp_dir_path, "file_in_dir.txt"), "Content")
  if not success then
    return nil, "Failed to write file in temp dir: " .. tostring(err)
  end
  print("Created file inside with_temp_directory ✓")
  return "Directory callback OK"
end)

if dir_result then
  print("with_temp_directory callback returned: " .. dir_result .. " ✓")
  -- Verify the directory was automatically cleaned up
  if not fs.directory_exists(scoped_dir_path) then
    print("Directory was automatically cleaned up ✓")
  else
    print("ERROR: Temporary directory from with_temp_directory still exists!")
  end
else
  print("ERROR during with_temp_directory callback: " .. tostring(dir_with_err))
end

print("\n4. Manual Registration and Cleanup")
print("--------------------------------------")
print("Creating resources without automatic cleanup (will use cleanup_all later)...")

-- Create a directory but don't use the 'with' pattern
-- Note: create_temp_directory *still registers* it for cleanup_all by default
local manual_dir, manual_dir_err = temp_file.create_temp_directory("manual_")
if not manual_dir then
  error("Failed to create manual dir: " .. manual_dir_err)
end
print("Manually managed directory created at: " .. manual_dir)

-- Create files within this directory
local manual_file1 = fs.join_paths(manual_dir, "file1.data")
local manual_file2 = fs.join_paths(manual_dir, "file2.log")
local ok1, err1 = fs.write_file(manual_file1, "Data 1")
local ok2, err2 = fs.write_file(manual_file2, "Log entry")

if not ok1 then
  print("ERROR writing manual_file1: " .. err1)
end
if not ok2 then
  print("ERROR writing manual_file2: " .. err2)
end

-- Normally, create_temp_directory registers the directory.
-- If we created files *outside* the temp system, we could register them:
-- local external_file = "./external_temp.tmp"
-- fs.write_file(external_file, "External")
-- temp_file.register_file(external_file) -- Now it will be cleaned up by cleanup_all

print("Directory and its contents were automatically registered by create_temp_directory.")

print("\n5. Resource Statistics and Explicit Cleanup")
print("--------------------------------")
local stats = temp_file.get_stats()
print("Current temporary resources:")
print("  - Total contexts: " .. stats.contexts)
print("  - Total resources: " .. stats.total_resources)
print("  - Files: " .. stats.files)
print("  - Directories: " .. stats.directories)

print("\nCleaning up all tracked temporary resources via cleanup_all()...")
local success, errors = temp_file.cleanup_all()

if success then
  print("cleanup_all() successful ✓")
else
  print("cleanup_all() encountered errors:")
  for i, err_info in ipairs(errors or {}) do
    print(string.format("  - Error cleaning %s '%s': %s", err_info.type, err_info.path, tostring(err_info.error)))
  end
end

-- Verify resources created initially were cleaned up
print("\nVerifying cleanup:")
print("  Original temp file exists?", tostring(fs.file_exists(file_path)))
print("  Original temp directory exists?", tostring(fs.directory_exists(dir_path)))
print("  Manually managed directory exists?", tostring(fs.directory_exists(manual_dir)))

-- Final check of stats (should be zero)
local final_stats = temp_file.get_stats()
print("\nFinal resource count after cleanup_all(): " .. final_stats.total_resources)

print("\n=== EXAMPLE COMPLETED SUCCESSFULLY ===")
