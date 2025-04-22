-- Comprehensive Temporary File Management Example
--
-- This example demonstrates the complete functionality of the temp_file module
-- including automatic tracking and cleanup of temporary files and directories.

-- Load firmo
package.path = "../?.lua;../lib/?.lua;" .. package.path
local firmo = require("firmo")

-- Import necessary modules
local temp_file = require("lib.tools.filesystem.temp_file")
local fs = require("lib.tools.filesystem")

print("=== TEMPORARY FILE MANAGEMENT EXAMPLE ===\n")

print("1. Basic Temporary File Creation")
print("---------------------------------")
print("Creating a temporary file with content...")
local file_path, err = temp_file.create_with_content("This is test content", "txt")
if err then
  print("Error creating file: " .. tostring(err))
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
  print("File content verified: \"" .. content .. "\" ✓")
else
  print("ERROR: Could not read file: " .. tostring(read_err))
end

print("\n2. Temporary Directory Creation")
print("------------------------------")
print("Creating a temporary directory...")
local dir_path, dir_err = temp_file.create_temp_directory()
if dir_err then
  print("Error creating directory: " .. tostring(dir_err))
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

print("\n3. With-Pattern for Temporary Resources")
print("-------------------------------------")
print("Using with_temp_file pattern...")

-- This pattern automatically cleans up the file after use
local result, with_err = temp_file.with_temp_file("Temporary content for callback", function(tmp_path)
  print("Inside callback with temporary file: " .. tmp_path)
  local file_content, err = fs.read_file(tmp_path)
  if file_content then
    print("Successfully read content: \"" .. file_content .. "\" ✓")
    return "Operation completed successfully"
  else
    return nil, "Failed to read file: " .. tostring(err)
  end
end, "lua")

if result then
  print("with_temp_file result: " .. result .. " ✓")
  -- Verify file was automatically cleaned up
  if not fs.file_exists(result) then
    print("File was automatically cleaned up ✓")
  end
else
  print("ERROR in with_temp_file: " .. tostring(with_err))
end

print("\n4. Manual Directory Structure Creation")
print("------------------------------------")
print("Creating a test directory with custom structure...")

-- Create a test directory manually
local test_dir = temp_file.create_temp_directory()
print("Test directory created at: " .. test_dir)

-- Create files in the directory
local config_file = test_dir .. "/config.json"
local success, err = fs.write_file(config_file, '{"setting": "value"}')
if success then
  print("Created config.json ✓")
else
  print("ERROR: Failed to create config.json: " .. tostring(err))
end

-- Create subdirectory
local scripts_dir = test_dir .. "/scripts"
success, err = fs.create_directory(scripts_dir)
if success then
  print("Created scripts subdirectory ✓")
else
  print("ERROR: Failed to create scripts directory: " .. tostring(err))
end

-- Create file in subdirectory
local helper_file = scripts_dir .. "/helper.lua"
success, err = fs.write_file(helper_file, "return function() return true end")
if success then
  print("Created helper.lua in subdirectory ✓")
else
  print("ERROR: Failed to create helper.lua: " .. tostring(err))
end

-- Verify files exist
if fs.file_exists(config_file) then
  print("config.json exists ✓")
end

if fs.file_exists(helper_file) then
  print("helper.lua exists in subdirectory ✓")
end

print("All files registered for automatic cleanup")

print("\n5. Resource Statistics and Cleanup")
print("--------------------------------")
local stats = temp_file.get_stats()
print("Current temporary resources:")
print("  - Total contexts: " .. stats.contexts)
print("  - Total resources: " .. stats.total_resources)
print("  - Files: " .. stats.files)
print("  - Directories: " .. stats.directories)

print("\nCleaning up all temporary resources...")
local success, errors = temp_file.cleanup_all()
if success then
  print("Cleanup successful ✓")
else
  print("Cleanup had errors: " .. tostring(#errors) .. " errors")
  for i, err in ipairs(errors) do
    print("  Error " .. i .. ": Failed to clean up " .. err.type .. " at " .. err.path)
  end
end

-- Verify resources were cleaned up
if not fs.file_exists(file_path) then
  print("Original temp file was removed ✓")
else
  print("ERROR: Original temp file still exists")
end

if not fs.directory_exists(dir_path) then
  print("Temp directory was removed ✓")
else
  print("ERROR: Temp directory still exists")
end

-- Get final stats
local final_stats = temp_file.get_stats()
print("\nFinal resource count: " .. final_stats.total_resources)

print("\n=== EXAMPLE COMPLETED SUCCESSFULLY ===")