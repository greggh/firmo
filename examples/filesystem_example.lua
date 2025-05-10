--- Comprehensive example demonstrating the Firmo filesystem module.
---
--- This example showcases various features of the `lib.tools.filesystem` module,
--- including:
--- - Basic file operations: writing (`fs.write_file`), reading (`fs.read_file`), appending (`fs.append_file`).
--- - Existence checks: `fs.file_exists`, `fs.directory_exists`, `fs.is_file`.
--- - Directory operations: creating (`fs.create_directory`), listing (`fs.list_directory`, `fs.list_files_recursive`).
--- - File finding and filtering: `fs.find_files`.
--- - Path manipulation: `fs.join_paths`, `fs.get_directory_name`, `fs.get_file_name`, `fs.basename`, `fs.get_extension`, `fs.normalize_path`, `fs.get_absolute_path`.
--- - Temporary file and directory management using `temp_file` module helpers (`with_temp_file`, `with_temp_directory`).
--- - Advanced operations: copying (`fs.copy_file`), moving (`fs.move_file`), removing files/directories (`fs.remove_file`, `fs.remove_directory`).
--- - Demonstrates proper error handling patterns for filesystem operations using return values (`nil, error_string`).
--- - Integrates filesystem operations within Firmo tests (`describe`, `it`, `expect`).
--- - Highlights best practices for interacting with the filesystem.
---
--- @module examples.filesystem_example
--- @see lib.tools.filesystem
--- @see lib.tools.filesystem.temp_file
--- @see lib.tools.error_handler
--- @see lib.tools.test_helper
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @usage
--- Run this example directly to see file operations logged to the console:
--- ```bash
--- lua examples/filesystem_example.lua
--- ```
--- Run the embedded Firmo tests to verify filesystem functions:
--- ```bash
--- lua firmo.lua examples/filesystem_example.lua
--- ```

-- Import required modules
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")
local temp_file = require("lib.tools.filesystem.temp_file")
local test_helper = require("lib.tools.test_helper") -- Added test_helper import

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after

-- Create a logger
local logging = require("lib.tools.logging")
local logger = logging.get_logger("FSExample")

--- Helper function to count entries in a non-sequence table.
--- @param tbl table The table to count entries in
--- @return number The number of entries in the table
local function count_table_entries(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

print("\n== FILESYSTEM MODULE EXAMPLE ==\n")
print("PART 1: Basic File Operations\n")

-- Create a temporary directory managed by test_helper for automatic cleanup
local temp_dir = test_helper.create_temp_test_directory("filesystem_example_")
print("Created temporary directory:", temp_dir.path)

-- Example 1: Writing Files
print("\nExample 1: Writing Files")

-- Simple file writing

-- Simple file writing
local simple_file_path = fs.join_paths(temp_dir.path, "simple.txt")
local write_success, write_err = fs.write_file(simple_file_path, "Hello, world!")
if write_success then
  print("Successfully wrote to simple.txt")
else
  print("Error writing simple.txt:", write_err) -- Use direct error string
end

-- Writing another file
local options_file_path = fs.join_paths(temp_dir.path, "options.txt")
local options_result, options_err = fs.write_file(options_file_path, "File with options")
if options_result then
  print("Successfully wrote to options.txt")
else
  print("Error writing options.txt:", options_err) -- Use direct error string
end

-- Example 2: Reading Files
print("\nExample 2: Reading Files")

-- Read an existing file
local content, read_err = fs.read_file(simple_file_path)
if content then
  print("Read from simple.txt:", content)
else
  print("Error reading simple.txt:", read_err) -- Use direct error string
end

-- Try to read a non-existent file
local missing_file_path = fs.join_paths(temp_dir.path, "missing.txt")
local missing_content, missing_err = fs.read_file(missing_file_path)
if missing_content then
  print("Read from missing.txt (unexpected):", missing_content)
else
  print("Error reading missing file:", missing_err) -- Use direct error string
end

-- Example 3: Checking File Existence

print("\nExample 3: Checking File/Directory Existence")

-- Check if a file exists
local file_exists = fs.file_exists(simple_file_path)
print("simple.txt exists:", file_exists)

-- Check if a file doesn't exist
local missing_exists = fs.file_exists(missing_file_path)
print("missing.txt exists:", missing_exists)

-- Check if a directory exists
local dir_exists = fs.directory_exists(temp_dir.path)
print("Temp directory exists:", dir_exists)

-- PART 2: Directory Operations
print("\nPART 2: Directory Operations\n")

-- Example 4: Creating Directories
print("\nExample 4: Creating Directories")

-- Create a new nested directory structure
local nested_dir = fs.join_paths(temp_dir.path, "nested", "structure")
local mkdir_success, mkdir_err = fs.create_directory(nested_dir)
if mkdir_success then
  print("Successfully created directory:", nested_dir)
else
  print("Error creating nested directory:", mkdir_err) -- Use direct error string
end

-- Create a file within the nested directory
local nested_file = fs.join_paths(nested_dir, "nested.txt")
local nested_write_success, nested_err = fs.write_file(nested_file, "Nested file content")
if nested_write_success then
  print("Successfully wrote to nested file:", nested_file)
else
  print("Error writing nested file:", nested_err) -- Use direct error string
end

-- Example 5: Listing Directory Contents
print("\nExample 5: Listing Directory Contents")

-- Create additional files for listing
local files_to_create = {
  "file1.txt",
  "file2.lua",
  "file3.json",
  fs.join_paths("subdir", "file4.txt"),
  fs.join_paths("subdir", "file5.lua"),
}

for _, file_path in ipairs(files_to_create) do
  local full_path = fs.join_paths(temp_dir.path, file_path)
  -- Ensure parent directory exists (handled by fs.write_file implicitly)
  -- local dir_path = fs.get_directory_name(full_path)
  -- if dir_path then
  --   fs.create_directory(dir_path)
  -- end
  local write_ok, write_err = fs.write_file(full_path, "Content for " .. file_path)
  if not write_ok then
    print("Error creating example file:", write_err)
  end
end

-- List all items (files and directories) in the root temporary directory
local root_items, root_err = fs.list_directory(temp_dir.path)
if root_items then
  print("Items in root directory:")
  for _, item in ipairs(root_items) do
    local full_path = fs.join_paths(temp_dir.path, item)
    local item_type = fs.is_file(full_path) and "File" or "Directory"
    print("  " .. item_type .. ": " .. item)
  end
else
  print("Error listing root directory:", root_err) -- Use direct error string
end

-- List files recursively
local all_files, all_err = fs.list_files_recursive(temp_dir.path)
if all_files then
  print("\nAll files (recursive):")
  for _, file in ipairs(all_files) do
    print("  " .. file)
  end
else
  print("Error listing recursively:", all_err) -- Use direct error string
end

-- Example 6: Filtering Files
print("\nExample 6: Filtering Files")

-- Filter files by pattern (Lua pattern)
local lua_files, lua_err = fs.find_files(temp_dir.path, "%.lua$", true) -- Search recursively
if lua_files then
  print("Lua files (recursive):")
  for _, file in ipairs(lua_files) do
    print("  " .. file)
  end
else
  print("Error finding Lua files:", lua_err) -- Use direct error string
end

-- Filter with multiple patterns
local patterns = { "%.txt$", "%.json$" }
local text_files = {} -- Initialize result table
local text_err -- Variable to hold potential error
for _, pattern in ipairs(patterns) do
  local found_files, find_err = fs.find_files(temp_dir.path, pattern, true) -- Search recursively
  if found_files then
    for _, f in ipairs(found_files) do
      table.insert(text_files, f)
    end
  else
    text_err = find_err -- Store the first error encountered
    break -- Stop on first error
  end
end

if not text_err then
  print("\nText and JSON files (recursive):")
  for _, file in ipairs(text_files) do
    print("  " .. file)
  end
else
  print("Error finding text/JSON files:", text_err) -- Use direct error string
end

-- PART 3: Path Manipulation
print("\nPART 3: Path Manipulation\n")

-- Example 7: Path Functions
print("Example 7: Path Functions")

-- Get base directory and filename
local test_path = fs.join_paths("/path", "to", "some", "file.txt")
local base_dir = fs.get_directory_name(test_path)
local filename = fs.get_file_name(test_path)
local basename = fs.basename(test_path)
local extension = fs.get_extension(test_path)

print("Path:", test_path)
print("Base directory:", base_dir)
print("Filename:", filename)
print("Basename:", basename)
print("Extension:", extension)

-- Join paths
local joined_path = fs.join_paths("/base/dir", "subdir", "file.txt")
print("\nJoined path:", joined_path)

-- Normalize paths
local messy_path = fs.join_paths("/path", "with", "..", "and", ".", "strange", "..", "segments")
local normalized_path = fs.normalize_path(messy_path)
print("Original path:", messy_path)
print("Normalized path:", normalized_path)

-- Make path absolute
local rel_path = fs.join_paths("relative", "path", "file.txt")
local abs_path, abs_err = fs.get_absolute_path(rel_path)
expect(abs_err).to_not.exist("Getting absolute path should succeed") -- Check error
print("Relative path:", rel_path)
print("Absolute path:", abs_path)

-- PART 4: Temporary Files
print("\nPART 4: Temporary Files\n")

-- Example 8: Using Temporary Files with Automatic Cleanup
print("Example 8: Using Temporary Files with Automatic Cleanup")

-- Use with_temp_file for automatic cleanup
local result, err = temp_file.with_temp_file("Initial content", function(file_path)
  print("Created temporary file with content:", file_path)

  -- Read the initial content
  local content, read_err = fs.read_file(file_path)
  if content then
    print("Read initial content:", content)
  else
    print("Error reading initial content:", read_err) -- Use direct error string
    return false, read_err
  end

  -- Modify the temporary file
  local write_result, write_err = fs.write_file(file_path, "Updated content")
  if write_result then
    print("Updated temporary file content")
  else
    print("Error updating temporary file:", write_err) -- Use direct error string
    return false, write_err
  end

  -- Read the updated content
  content, read_err = fs.read_file(file_path)
  if content then
    print("Read updated content:", content)
  else
    print("Error reading updated content:", read_err) -- Use direct error string
    return false, read_err
  end

  print("Temporary file will be automatically cleaned up after this function")
  return true, "Operation completed successfully"
end)

if result then
  print("Temporary file operation succeeded")
else
  print("Temporary file operation failed:", err and tostring(err) or "Unknown error") -- Handle error object or string
end

-- Using with_temp_file with a Lua extension
local lua_result, lua_err = temp_file.with_temp_file("-- Lua comment\nreturn {success = true}", function(lua_file)
  print("\nCreated temporary Lua file:", lua_file)
  print("Has .lua extension:", lua_file:match("%.lua$") ~= nil)

  -- Read the Lua content
  local content, read_err = fs.read_file(lua_file)
  if content then
    print("Lua file content:", content)
  else
    print("Error reading Lua file:", read_err) -- Use direct error string
  end

  return true
end, "lua")

if lua_result then
  print("Lua temporary file operation succeeded")
else
  print("Lua temporary file operation failed:", lua_err and tostring(lua_err) or "Unknown error") -- Handle error object or string
end

-- Example 9: Using Temporary Directories with Automatic Cleanup
print("\nExample 9: Using Temporary Directories with Automatic Cleanup")

-- Use with_temp_directory for automatic cleanup
local dir_result, dir_err = temp_file.with_temp_directory(function(dir_path)
  print("Created temporary directory:", dir_path)

  -- Create files in the temporary directory
  local file1 = fs.join_paths(dir_path, "file1.txt")
  local file2 = fs.join_paths(dir_path, "file2.txt")
  local subdir = fs.join_paths(dir_path, "subdir")

  -- Create a file in the temp directory
  local write_result, write_err = fs.write_file(file1, "Content for file 1")
  if write_result then
    print("Created file in temporary directory:", file1)
  else
    print("Error creating file in temporary directory:", write_err) -- Use direct error string
    return false, write_err
  end

  -- Create a subdirectory
  local mkdir_result, mkdir_err = fs.create_directory(subdir)
  if mkdir_result then
    print("Created subdirectory in temporary directory:", subdir)
  else
    print("Error creating subdirectory:", mkdir_err) -- Use direct error string
    return false, mkdir_err
  end

  -- Create a file in the subdirectory
  local nested_sub_file = fs.join_paths(subdir, "nested.txt")
  local sub_write_result, sub_write_err = fs.write_file(nested_sub_file, "Nested file content")
  if sub_write_result then
    print("Created file in subdirectory:", nested_sub_file)
  else
    print("Error creating file in subdirectory:", sub_write_err) -- Use direct error string
    return false, sub_write_err
  end

  -- List files recursively in the temporary directory
  local files, list_err = fs.list_files_recursive(dir_path) -- Use correct function
  if files then
    print("\nFiles in temporary directory structure:")
    for _, file in ipairs(files) do
      print("  " .. file)
    end
  else
    print("Error listing files:", list_err) -- Use direct error string
  end

  print("Temporary directory will be automatically cleaned up after this function")
  return true, "Directory operations completed successfully"
end)

if dir_result then
  print("Temporary directory operation succeeded")
else
  print("Temporary directory operation failed:", dir_err and tostring(dir_err) or "Unknown error") -- Handle error object or string
end

-- PART 5: Advanced Operations
print("\nPART 5: Advanced Operations\n")

-- Example 10: Copying and Moving Files
print("Example 10: Copying and Moving Files")

-- Create a file to copy
local source_file = fs.join_paths(temp_dir.path, "source.txt")
fs.write_file(source_file, "Content to copy and move")

-- Copy the file
local copy_dest = fs.join_paths(temp_dir.path, "copy.txt")
local copy_success, copy_err = fs.copy_file(source_file, copy_dest)
if copy_success then
  print("Successfully copied file to:", copy_dest)

  -- Verify the copy
  local copy_content, copy_read_err = fs.read_file(copy_dest)
  expect(copy_read_err).to_not.exist("Reading copied file should succeed")
  print("Copy content:", copy_content)
else
  print("Error copying file:", copy_err)
end

-- Move the copied file
local move_dest = fs.join_paths(temp_dir.path, "moved.txt")
local move_success, move_err = fs.move_file(copy_dest, move_dest)
if move_success then
  print("Successfully moved file to:", move_dest)

  -- Verify the source no longer exists
  print("Source still exists:", fs.file_exists(copy_dest))

  -- Verify the destination
  local move_content, move_read_err = fs.read_file(move_dest)
  expect(move_read_err).to_not.exist("Reading moved file should succeed")
  print("Moved content:", move_content)
else
  print("Error moving file:", move_err)
end

-- Example 11: File and Directory Removal
print("\nExample 11: File and Directory Removal")

-- Create a nested directory structure to remove
local remove_dir = fs.join_paths(temp_dir.path, "to_remove")
fs.create_directory(remove_dir)
fs.write_file(fs.join_paths(remove_dir, "file1.txt"), "Content 1")
fs.write_file(fs.join_paths(remove_dir, "file2.txt"), "Content 2")
fs.create_directory(fs.join_paths(remove_dir, "subdir"))
fs.write_file(fs.join_paths(remove_dir, "subdir", "file3.txt"), "Content 3")

-- Remove a single file
local file1_path = fs.join_paths(remove_dir, "file1.txt")
local file_remove_success, file_remove_err = fs.remove_file(file1_path)
if file_remove_success then
  print("Removed single file:", file1_path)
  print("File still exists after removal:", fs.file_exists(file1_path))
else
  print("Error removing file:", file_remove_err) -- Use direct error string
end

-- Remove the entire directory and its remaining contents recursively
local dir_remove_success, dir_remove_err = fs.remove_directory(remove_dir, true) -- Set recursive = true
if dir_remove_success then
  print("Removed directory recursively:", remove_dir)
  print("Directory still exists after removal:", fs.directory_exists(remove_dir))
else
  print("Error removing directory recursively:", dir_remove_err) -- Use direct error string
end

-- PART 6: Error Handling
print("\nPART 6: Error Handling in Filesystem Operations\n")

-- Example 12: Proper Error Handling with Filesystem Operations
print("Example 12: Proper Error Handling")

--- Simulates processing a configuration file, demonstrating robust error handling
--- for file existence and reading using `error_handler` objects.
--- @param file_path any The path to the configuration file to process.
--- @return table|nil config The processed configuration table if successful, `nil` otherwise.
--- @return table|nil error An error object (from `error_handler`) if any operation failed.
--- @within examples.filesystem_example
function process_config_file(file_path)
  -- Validate input
  if type(file_path) ~= "string" then
    return nil,
      error_handler.validation_error(
        "File path must be a string",
        { parameter = "file_path", provided_type = type(file_path) }
      )
  end

  -- Check if file exists
  if not fs.file_exists(file_path) then
    return nil, error_handler.io_error("Config file does not exist", { file_path = file_path, operation = "read" })
  end

  local content, read_err_str = fs.read_file(file_path)
  if not content then
    -- Wrap the string error from fs.read_file into a proper error object
    local io_err =
      error_handler.io_error(read_err_str or "Unknown read error", { file_path = file_path, operation = "read" })
    -- Note: error_handler.wrap_error doesn't exist, just propagate the IO error
    -- or create a new runtime error with the IO error as the cause.
    -- Propagating directly is simpler here.
    return nil, io_err
  end

  -- Process the content (simplified example: assumes key=value pairs per line)
  local config = {}
  for line in content:gmatch("[^\r\n]+") do
    local key, value = line:match("^([%w_]+)%s*=%s*(.+)$")
    if key and value then
      config[key] = value
    end
  end

  -- Check if we found any config entries
  if next(config) == nil then
    return nil, error_handler.validation_error("Invalid config file format or empty file", { file_path = file_path })
  end

  return config
end

-- Test files for our function
local valid_config = fs.join_paths(temp_dir.path, "valid.conf")
fs.write_file(valid_config, "name = Test\nvalue = 42\nenabled = true")

local empty_config = fs.join_paths(temp_dir.path, "empty.conf")
fs.write_file(empty_config, "")

local invalid_path = fs.join_paths(temp_dir.path, "missing.conf")

-- Test the function with various inputs
local test_paths = {
  valid_config,
  empty_config,
  invalid_path,
  123, -- Invalid type
}

print("\nTesting process_config_file function:")
for _, path in ipairs(test_paths) do
  local result, err = process_config_file(path)

  if result then
    print(
      string.format(
        "SUCCESS: '%s' -> Processed %d config entries",
        tostring(path),
        next(result) and count_table_entries(result) or 0
      ) -- Count entries for non-sequence tables
    )

    -- Display config entries
    for k, v in pairs(result) do
      print(string.format("  %s = %s", k, v))
    end
  else
    -- Check if it's an error object or a simple string
    if type(err) == "table" and err.category then
      print(string.format("ERROR: '%s' -> %s: %s", tostring(path), err.category, err.message))
    else
      print(string.format("ERROR: '%s' -> %s", tostring(path), tostring(err))) -- Handle plain string error
    end
  end
end
-- PART 7: Unit Testing Filesystem Code
print("\nPART 7: Unit Testing Filesystem Code\n")

-- Example 13: Testing File Operations
print("\nExample 13: Testing Filesystem Operations with Firmo\n")

-- Unit tests for basic file operations using Firmo's testing framework
--- @within examples.filesystem_example
describe("File Operations Tests", function()
  local test_file

  local test_file
  local test_dir_helper -- Use the helper from test_helper

  --- Setup hook: Create a unique temp directory and define file path before each test.
  before(function()
    test_dir_helper = test_helper.create_temp_test_directory("file_ops_")
    test_file = fs.join_paths(test_dir_helper.path, "test_file.txt")
  end)

  --- Teardown hook: Release references. Directory is cleaned automatically.
  after(function()
    if fs.file_exists(test_file) then
      fs.remove_file(test_file)
    end
    test_file = nil
    test_dir_helper = nil -- Allow GC, directory cleanup handled by test_helper
  end)

  --- Tests basic file writing and reading using `fs.write_file` and `fs.read_file`.
  it("can write and read a file", function()
    local content = "Test content " .. os.time()

    -- Write to the file
    local write_success, write_err = fs.write_file(test_file, content)
    expect(write_err).to_not.exist("Writing file should succeed")
    expect(write_success).to.be_truthy()

    -- Check file exists
    expect(fs.file_exists(test_file)).to.be_truthy()

    -- Read the file
    local read_content, read_err = fs.read_file(test_file)
    expect(read_err).to_not.exist("Reading file should succeed")
    expect(read_content).to.equal(content)
  end)

  --- Tests how reading a non-existent file is handled by `fs.read_file` (returns `nil, error_string`).
  it("handles reading missing files correctly", function()
    local missing_file = fs.join_paths(test_dir_helper.path, "does_not_exist.txt")

    -- Ensure file doesn't exist
    if fs.file_exists(missing_file) then
      fs.remove_file(missing_file)
    end

    -- Verify file doesn't exist
    expect(fs.file_exists(missing_file)).to.equal(false)

    -- Try to read missing file
    local content, err_str = fs.read_file(missing_file)

    -- Verify result and error string
    expect(content).to_not.exist()
    expect(err_str).to.be.a("string")
    expect(err_str).to.match("No such file")  -- More flexible pattern that matches the actual error message
  end)

  --- Tests appending content to an existing file using `fs.append_file`.
  it("can append to files using append_file", function()
    -- Initial content
    local initial = "Initial content\n"
    local write_success, write_err = fs.write_file(test_file, initial)
    expect(write_err).to_not.exist("Initial write should succeed")
    expect(write_success).to.be_truthy()

    -- Append content
    local append = "Appended content"
    local append_success, append_err = fs.append_file(test_file, append)
    expect(append_err).to_not.exist("Appending should succeed")
    expect(append_success).to.be_truthy()

    -- Read combined content
    local read_content, read_err = fs.read_file(test_file)
    expect(read_err).to_not.exist("Reading after append should succeed")
    expect(read_content).to.equal(initial .. append)
  end)
end)

-- Unit tests for directory operations
--- @within examples.filesystem_example
describe("Directory Operations Tests", function()
  local test_dir_helper -- Stores the temp dir helper object

  --- Setup hook: Create a unique temp directory before each test.
  before(function()
    test_dir_helper = test_helper.create_temp_test_directory("dir_ops_")
  end)

  --- Tests creating nested directories using `fs.create_directory`.
  it("can create nested directories", function()
    local nested_dir = fs.join_paths(test_dir_helper.path, "level1", "level2", "level3")

    -- Create the nested directories
    local success, err = fs.create_directory(nested_dir)
    expect(err).to_not.exist("Creating nested directories should succeed")
    expect(success).to.be_truthy()

    -- Verify directories exist
    expect(fs.directory_exists(nested_dir)).to.be_truthy()
    expect(fs.directory_exists(fs.join_paths(test_dir_helper.path, "level1", "level2"))).to.be_truthy()
    expect(fs.directory_exists(fs.join_paths(test_dir_helper.path, "level1"))).to.be_truthy()
  end)

  --- Tests listing directory contents using `fs.list_directory`.
  it("can list directory contents", function()
    -- Create test files and a subdirectory
    test_dir_helper:create_file("file1.txt", "Content 1")
    test_dir_helper:create_file("file2.txt", "Content 2")
    fs.create_directory(fs.join_paths(test_dir_helper.path, "subdir")) -- Create dir directly

    -- List directory
    local entries, err = fs.list_directory(test_dir_helper.path)
    expect(err).to_not.exist("Listing directory should succeed")
    expect(entries).to.exist()

    -- Should have 3 entries
    expect(#entries).to.equal(3)

    -- Check if the expected entries are present (order might vary)
    local has_file1 = false
    local has_file2 = false
    local has_subdir = false

    for _, entry in ipairs(entries) do
      if entry == "file1.txt" then
        has_file1 = true
      end
      if entry == "file2.txt" then
        has_file2 = true
      end
      if entry == "subdir" then
        has_subdir = true
      end
    end

    expect(has_file1).to.be_truthy("Missing file1.txt")
    expect(has_file2).to.be_truthy("Missing file2.txt")
    expect(has_subdir).to.be_truthy("Missing subdir")
  end)

  --- Tests removing a directory and its contents recursively using `fs.remove_directory`.
  it("can remove directories recursively", function()
    -- Create a structure to remove
    local remove_path = fs.join_paths(test_dir_helper.path, "to_remove")
    fs.create_directory(remove_path)
    fs.write_file(fs.join_paths(remove_path, "file.txt"), "Content")
    fs.create_directory(fs.join_paths(remove_path, "subdir"))
    fs.write_file(fs.join_paths(remove_path, "subdir", "nested.txt"), "Nested content")

    -- Verify structure was created
    expect(fs.directory_exists(remove_path)).to.be_truthy()
    expect(fs.file_exists(fs.join_paths(remove_path, "file.txt"))).to.be_truthy()
    expect(fs.directory_exists(fs.join_paths(remove_path, "subdir"))).to.be_truthy()
    expect(fs.file_exists(fs.join_paths(remove_path, "subdir", "nested.txt"))).to.be_truthy()

    -- Remove recursively
    local success, err = fs.remove_directory(remove_path, true)
    expect(err).to_not.exist("Recursive remove should succeed")
    expect(success).to.be_truthy()

    -- Verify removal
    expect(fs.directory_exists(remove_path)).to.equal(false)
  end)
end)

print("Run the tests with: lua firmo.lua examples/filesystem_example.lua\n")

-- PART 8: Best Practices
print("\nPART 8: Filesystem Best Practices\n")

print("1. ALWAYS handle errors in filesystem operations")
print("   Bad: Not checking return values")
print("   Good: Checking both result and error return values")

print("\n2. ALWAYS use the filesystem module instead of io and os directly")
print("   Bad: Using io.open, os.remove directly")
print("   Good: Using fs.read_file, fs.remove_file")

print("\n3. ALWAYS use automatic cleanup for temporary files and directories")
print("   Bad: Manual creation and deletion (temp_file = create_temp_file(); fs.remove_file(temp_file))")
print("   Good: Using temp_file.with_temp_file() and temp_file.with_temp_directory() for automatic cleanup")

print("\n4. ALWAYS validate file paths and inputs")
print("   Bad: Assuming paths are valid")
print("   Good: Validating paths and checking existence before operations")

print("\n5. ALWAYS use path manipulation functions instead of string concatenation")
print("   Bad: path1 .. '/' .. path2")
print("   Good: fs.join_paths(path1, path2)")

print("\n6. ALWAYS normalize paths to prevent directory traversal")
print("   Bad: Using paths with '..' without normalization")
print("   Good: Using fs.normalize_path() for user-provided paths")

print("\n7. ALWAYS use proper permissions")
print("   Bad: Creating world-writable files")
print("   Good: Using appropriate permissions for security")

print("\n8. ALWAYS retry critical operations when appropriate")
print("   Bad: Giving up on first failure")
print("   Good: Implementing retry logic for intermittent issues")

print("\n9. ALWAYS log filesystem operations at the appropriate level")
print("   Bad: Not logging or over-logging")
print("   Good: Logging operations at debug level, errors at error level")

print("\n10. ALWAYS use absolute paths for clarity")
print("    Bad: Using relative paths that depend on current directory")
print("    Good: Using absolute paths or clearly documented relative paths")

-- Cleanup
print("\nFilesystem example completed successfully.")
