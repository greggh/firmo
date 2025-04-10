--[[
  filesystem_example.lua

  Comprehensive example of the filesystem module in Firmo.
  This example demonstrates file operations with proper error
  handling and best practices for file system interactions.
]]

-- Import required modules
local firmo = require("firmo")
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local temp_file = require("lib.tools.temp_file")
local central_config = require("lib.core.central_config")

-- Test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Create a logger
local logging = require("lib.tools.logging")
local logger = logging.get_logger("FSExample")

print("\n== FILESYSTEM MODULE EXAMPLE ==\n")
print("PART 1: Basic File Operations\n")

-- Create a temporary directory for our examples
local temp_dir = test_helper.create_temp_test_directory()
print("Created temporary directory:", temp_dir.path)

-- Example 1: Writing Files
print("\nExample 1: Writing Files")

-- Simple file writing
local write_result, write_err = fs.write_file(temp_dir.path .. "/simple.txt", "Hello, world!")
if write_result then
  print("Successfully wrote to simple.txt")
else
  print("Error writing file:", write_err.message)
end

-- Writing with options
local options_result, options_err =
  fs.write_file(temp_dir.path .. "/options.txt", "File with options", { append = false, create_dirs = true })
if options_result then
  print("Successfully wrote to options.txt")
else
  print("Error writing file:", options_err.message)
end

-- Example 2: Reading Files
print("\nExample 2: Reading Files")

-- Read an existing file
local content, read_err = fs.read_file(temp_dir.path .. "/simple.txt")
if content then
  print("Read from simple.txt:", content)
else
  print("Error reading file:", read_err.message)
end

-- Try to read a non-existent file
local missing_content, missing_err = fs.read_file(temp_dir.path .. "/missing.txt")
if missing_content then
  print("Read from missing.txt (unexpected):", missing_content)
else
  print("Error reading missing file:", missing_err.message)
end

-- Example 3: Checking File Existence
print("\nExample 3: Checking File Existence")

-- Check if a file exists
local file_exists = fs.file_exists(temp_dir.path .. "/simple.txt")
print("simple.txt exists:", file_exists)

-- Check if a file doesn't exist
local missing_exists = fs.file_exists(temp_dir.path .. "/missing.txt")
print("missing.txt exists:", missing_exists)

-- Check if a directory exists
local dir_exists = fs.directory_exists(temp_dir.path)
print("Temp directory exists:", dir_exists)

-- PART 2: Directory Operations
print("\nPART 2: Directory Operations\n")

-- Example 4: Creating Directories
print("Example 4: Creating Directories")

-- Create a new directory
local nested_dir = temp_dir.path .. "/nested/structure"
local mkdir_result, mkdir_err = fs.create_directory(nested_dir)
if mkdir_result then
  print("Successfully created directory:", nested_dir)
else
  print("Error creating directory:", mkdir_err.message)
end

-- Create a file in the nested directory
local nested_file = nested_dir .. "/nested.txt"
local nested_result, nested_err = fs.write_file(nested_file, "Nested file content")
if nested_result then
  print("Successfully wrote to nested file:", nested_file)
else
  print("Error writing nested file:", nested_err.message)
end

-- Example 5: Listing Directory Contents
print("\nExample 5: Listing Directory Contents")

-- Create additional files for listing
local files_to_create = {
  "/file1.txt",
  "/file2.lua",
  "/file3.json",
  "/subdir/file4.txt",
  "/subdir/file5.lua",
}

for _, file_path in ipairs(files_to_create) do
  local full_path = temp_dir.path .. file_path
  -- Ensure parent directory exists
  local dir_path = full_path:match("(.+)/[^/]+$")
  if dir_path then
    fs.create_directory(dir_path)
  end
  fs.write_file(full_path, "Content for " .. file_path)
end

-- List all files in the root temporary directory
local root_files, root_err = fs.list_directory(temp_dir.path)
if root_files then
  print("Files in root directory:")
  for _, file in ipairs(root_files) do
    local full_path = temp_dir.path .. "/" .. file
    local file_type = fs.file_exists(full_path) and "File" or "Directory"
    print("  " .. file_type .. ": " .. file)
  end
else
  print("Error listing directory:", root_err.message)
end

-- List files recursively
local all_files, all_err = fs.list_directory_recursive(temp_dir.path)
if all_files then
  print("\nAll files (recursive):")
  for _, file in ipairs(all_files) do
    print("  " .. file)
  end
else
  print("Error listing recursively:", all_err.message)
end

-- Example 6: Filtering Files
print("\nExample 6: Filtering Files")

-- Filter files by pattern
local lua_files, lua_err = fs.find_files(temp_dir.path, "%.lua$")
if lua_files then
  print("Lua files:")
  for _, file in ipairs(lua_files) do
    print("  " .. file)
  end
else
  print("Error finding Lua files:", lua_err.message)
end

-- Filter with multiple patterns
local patterns = { "%.txt$", "%.json$" }
local text_files, text_err = fs.find_files_matching(temp_dir.path, patterns)
if text_files then
  print("\nText and JSON files:")
  for _, file in ipairs(text_files) do
    print("  " .. file)
  end
else
  print("Error finding text files:", text_err.message)
end

-- PART 3: Path Manipulation
print("\nPART 3: Path Manipulation\n")

-- Example 7: Path Functions
print("Example 7: Path Functions")

-- Get base directory and filename
local test_path = "/path/to/some/file.txt"
local base_dir = fs.get_directory(test_path)
local filename = fs.get_filename(test_path)
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
local messy_path = "/path/with/../and/./strange/../segments"
local normalized_path = fs.normalize_path(messy_path)
print("Original path:", messy_path)
print("Normalized path:", normalized_path)

-- Make path absolute
local rel_path = "relative/path/file.txt"
local abs_path = fs.make_absolute_path(rel_path)
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
    print("Error reading initial content:", read_err.message)
    return false, read_err
  end

  -- Modify the temporary file
  local write_result, write_err = fs.write_file(file_path, "Updated content")
  if write_result then
    print("Updated temporary file content")
  else
    print("Error updating temporary file:", write_err.message)
    return false, write_err
  end

  -- Read the updated content
  content, read_err = fs.read_file(file_path)
  if content then
    print("Read updated content:", content)
  else
    print("Error reading updated content:", read_err.message)
    return false, read_err
  end

  print("Temporary file will be automatically cleaned up after this function")
  return true, "Operation completed successfully"
end)

if result then
  print("Temporary file operation succeeded")
else
  print("Temporary file operation failed:", err and err.message or "Unknown error")
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
    print("Error reading Lua file:", read_err.message)
  end

  return true
end, "lua")

if lua_result then
  print("Lua temporary file operation succeeded")
else
  print("Lua temporary file operation failed:", lua_err and lua_err.message or "Unknown error")
end

-- Example 9: Using Temporary Directories with Automatic Cleanup
print("\nExample 9: Using Temporary Directories with Automatic Cleanup")

-- Use with_temp_directory for automatic cleanup
local dir_result, dir_err = temp_file.with_temp_directory(function(dir_path)
  print("Created temporary directory:", dir_path)

  -- Create files in the temporary directory
  local file1 = dir_path .. "/file1.txt"
  local file2 = dir_path .. "/file2.txt"
  local subdir = dir_path .. "/subdir"

  -- Create a file in the temp directory
  local write_result, write_err = fs.write_file(file1, "Content for file 1")
  if write_result then
    print("Created file in temporary directory:", file1)
  else
    print("Error creating file in temporary directory:", write_err.message)
    return false, write_err
  end

  -- Create a subdirectory
  local mkdir_result, mkdir_err = fs.create_directory(subdir)
  if mkdir_result then
    print("Created subdirectory in temporary directory:", subdir)
  else
    print("Error creating subdirectory:", mkdir_err.message)
    return false, mkdir_err
  end

  -- Create a file in the subdirectory
  local sub_write_result, sub_write_err = fs.write_file(subdir .. "/nested.txt", "Nested file content")
  if sub_write_result then
    print("Created file in subdirectory:", subdir .. "/nested.txt")
  else
    print("Error creating file in subdirectory:", sub_write_err.message)
    return false, sub_write_err
  end

  -- List files in the temporary directory
  local files, list_err = fs.list_directory_recursive(dir_path)
  if files then
    print("\nFiles in temporary directory structure:")
    for _, file in ipairs(files) do
      print("  " .. file)
    end
  else
    print("Error listing directory:", list_err.message)
  end

  print("Temporary directory will be automatically cleaned up after this function")
  return true, "Directory operations completed successfully"
end)

if dir_result then
  print("Temporary directory operation succeeded")
else
  print("Temporary directory operation failed:", dir_err and dir_err.message or "Unknown error")
end

-- PART 5: Advanced Operations
print("\nPART 5: Advanced Operations\n")

-- Example 10: Copying and Moving Files
print("Example 10: Copying and Moving Files")

-- Create a file to copy
local source_file = temp_dir.path .. "/source.txt"
fs.write_file(source_file, "Content to copy and move")

-- Copy the file
local copy_dest = temp_dir.path .. "/copy.txt"
local copy_result, copy_err = fs.copy_file(source_file, copy_dest)
if copy_result then
  print("Successfully copied file to:", copy_dest)

  -- Verify the copy
  local copy_content = fs.read_file(copy_dest)
  print("Copy content:", copy_content)
else
  print("Error copying file:", copy_err.message)
end

-- Move the file
local move_dest = temp_dir.path .. "/moved.txt"
local move_result, move_err = fs.move_file(copy_dest, move_dest)
if move_result then
  print("Successfully moved file to:", move_dest)

  -- Verify the source no longer exists
  print("Source still exists:", fs.file_exists(copy_dest))

  -- Verify the destination
  local move_content = fs.read_file(move_dest)
  print("Moved content:", move_content)
else
  print("Error moving file:", move_err.message)
end

-- Example 11: File and Directory Removal
print("\nExample 11: File and Directory Removal")

-- Create a nested directory structure to remove
local remove_dir = temp_dir.path .. "/to_remove"
fs.create_directory(remove_dir)
fs.write_file(remove_dir .. "/file1.txt", "Content 1")
fs.write_file(remove_dir .. "/file2.txt", "Content 2")
fs.create_directory(remove_dir .. "/subdir")
fs.write_file(remove_dir .. "/subdir/file3.txt", "Content 3")

-- Remove a single file
local file_remove_result, file_remove_err = fs.remove_file(remove_dir .. "/file1.txt")
if file_remove_result then
  print("Removed single file")
  print("File still exists:", fs.file_exists(remove_dir .. "/file1.txt"))
else
  print("Error removing file:", file_remove_err.message)
end

-- Remove directory and contents recursively
local dir_remove_result, dir_remove_err = fs.remove_directory_recursive(remove_dir)
if dir_remove_result then
  print("Removed directory recursively")
  print("Directory still exists:", fs.directory_exists(remove_dir))
else
  print("Error removing directory:", dir_remove_err.message)
end

-- PART 6: Error Handling
print("\nPART 6: Error Handling in Filesystem Operations\n")

-- Example 12: Proper Error Handling with Filesystem Operations
print("Example 12: Proper Error Handling")

---@param file_path any The path to the configuration file
---@return table|nil config The parsed configuration if successful, nil otherwise
---@return table|nil error An error object if the operation failed
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

  -- Read the file with error handling
  local content, read_err = fs.read_file(file_path)
  if not content then
    -- Propagate error with additional context
    read_err.context.operation = "process_config_file"
    return nil, read_err
  end

  -- Process the content (simplified for example)
  local config = {}
  for line in content:gmatch("[^\r\n]+") do
    local key, value = line:match("^([%w_]+)%s*=%s*(.+)$")
    if key and value then
      config[key] = value
    end
  end

  -- Check if we found any config entries
  if next(config) == nil then
    return nil, error_handler.format_error("Invalid config file format", { file_path = file_path, content = content })
  end

  return config
end

-- Test files for our function
local valid_config = temp_dir.path .. "/valid.conf"
fs.write_file(valid_config, "name = Test\nvalue = 42\nenabled = true")

local empty_config = temp_dir.path .. "/empty.conf"
fs.write_file(empty_config, "")

local invalid_path = temp_dir.path .. "/missing.conf"

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
      string.format("SUCCESS: '%s' -> Processed %d config entries", tostring(path), next(result) and #next(result) or 0)
    )

    -- Display config entries
    for k, v in pairs(result) do
      print(string.format("  %s = %s", k, v))
    end
  else
    print(string.format("ERROR: '%s' -> %s: %s", tostring(path), err.category, err.message))
  end
end

-- PART 7: Unit Testing Filesystem Code
print("\nPART 7: Unit Testing Filesystem Code\n")

-- Example 13: Testing File Operations
print("Example 13: Testing File Operations")

-- Create a test directory for our tests
local test_dir = test_helper.create_temp_test_directory()

-- Unit tests for file operations
describe("File Operations", function()
  local test_file

  -- Set up before each test
  before(function()
    test_file = test_dir.path .. "/test_file.txt"
  end)

  -- Clean up after each test
  after(function()
    if fs.file_exists(test_file) then
      fs.remove_file(test_file)
    end
  end)

  it("can write and read a file", function()
    local content = "Test content " .. os.time()

    -- Write to the file
    local write_result, write_err = fs.write_file(test_file, content)
    expect(write_err).to_not.exist("Write error: " .. tostring(write_err))
    expect(write_result).to.be_truthy()

    -- Check file exists
    expect(fs.file_exists(test_file)).to.be_truthy()

    -- Read the file
    local read_content, read_err = fs.read_file(test_file)
    expect(read_err).to_not.exist("Read error: " .. tostring(read_err))
    expect(read_content).to.equal(content)
  end)

  it("handles missing files correctly", { expect_error = true }, function()
    local missing_file = test_dir.path .. "/does_not_exist.txt"

    -- Ensure file doesn't exist
    if fs.file_exists(missing_file) then
      fs.remove_file(missing_file)
    end

    -- Verify file doesn't exist
    expect(fs.file_exists(missing_file)).to.equal(false)

    -- Try to read missing file
    local content, err = test_helper.with_error_capture(function()
      return fs.read_file(missing_file)
    end)()

    -- Verify error
    expect(content).to.equal(nil)
    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.IO)
    expect(err.message).to.match("file")
  end)

  it("can append to files", function()
    -- Initial content
    local initial = "Initial content\n"
    local write_result, _ = fs.write_file(test_file, initial)
    expect(write_result).to.be_truthy()

    -- Append content
    local append = "Appended content"
    local append_result, append_err = fs.write_file(test_file, append, { append = true })
    expect(append_err).to_not.exist("Append error: " .. tostring(append_err))
    expect(append_result).to.be_truthy()

    -- Read combined content
    local read_content, _ = fs.read_file(test_file)
    expect(read_content).to.equal(initial .. append)
  end)
end)

-- Example 14: Testing Directory Operations
print("\nExample 14: Testing Directory Operations")

describe("Directory Operations", function()
  local base_dir

  -- Create a unique directory for each test
  before(function()
    base_dir = test_dir.path .. "/dir_tests_" .. os.time()
    fs.create_directory(base_dir)
  end)

  -- Clean up after tests
  after(function()
    if fs.directory_exists(base_dir) then
      fs.remove_directory_recursive(base_dir)
    end
  end)

  it("can create nested directories", function()
    local nested_dir = base_dir .. "/level1/level2/level3"

    -- Create the nested directories
    local result, err = fs.create_directory(nested_dir)
    expect(err).to_not.exist("Directory creation error: " .. tostring(err))
    expect(result).to.be_truthy()

    -- Verify directories exist
    expect(fs.directory_exists(nested_dir)).to.be_truthy()
    expect(fs.directory_exists(base_dir .. "/level1/level2")).to.be_truthy()
    expect(fs.directory_exists(base_dir .. "/level1")).to.be_truthy()
  end)

  it("can list directory contents", function()
    -- Create test files
    fs.write_file(base_dir .. "/file1.txt", "Content 1")
    fs.write_file(base_dir .. "/file2.txt", "Content 2")
    fs.create_directory(base_dir .. "/subdir")

    -- List directory
    local entries, err = fs.list_directory(base_dir)
    expect(err).to_not.exist("Listing error: " .. tostring(err))
    expect(entries).to.exist()

    -- Should have 3 entries
    expect(#entries).to.equal(3)

    -- Should contain our files and directory
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

  it("can remove directories recursively", function()
    -- Create a structure to remove
    local remove_path = base_dir .. "/to_remove"
    fs.create_directory(remove_path)
    fs.write_file(remove_path .. "/file.txt", "Content")
    fs.create_directory(remove_path .. "/subdir")
    fs.write_file(remove_path .. "/subdir/nested.txt", "Nested content")

    -- Verify structure was created
    expect(fs.directory_exists(remove_path)).to.be_truthy()
    expect(fs.file_exists(remove_path .. "/file.txt")).to.be_truthy()
    expect(fs.directory_exists(remove_path .. "/subdir")).to.be_truthy()
    expect(fs.file_exists(remove_path .. "/subdir/nested.txt")).to.be_truthy()

    -- Remove recursively
    local result, err = fs.remove_directory_recursive(remove_path)
    expect(err).to_not.exist("Removal error: " .. tostring(err))
    expect(result).to.be_truthy()

    -- Verify removal
    expect(fs.directory_exists(remove_path)).to.equal(false)
  end)
end)

print("Run the tests with: lua test.lua examples/filesystem_example.lua\n")

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
