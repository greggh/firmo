--- Filesystem Module Tests (Comprehensive)
---
--- Provides extensive tests for the `lib.tools.filesystem` module, covering:
--- - Core File Operations: Write, read, append, delete, copy, move.
--- - Directory Operations: Create, delete, recursive delete, copy, listing (with/without hidden).
--- - Path Operations: Join, normalize, extract directory/file/base names, extension, absolute path check.
--- - Alias Functions: Verifying aliases like `remove_directory`, `remove_file`, `get_filename`, etc.
--- - Information Functions: Existence checks, size, modification time, symlink handling.
--- - Error Handling: Verifying behavior with invalid paths, types, and non-existent files/directories.
--- Uses `before`/`after` hooks for setting up and tearing down temporary test directories
--- and `test_helper` for error verification.
---
--- @author Firmo Team
--- @test

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

local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")

-- Initialize logging
local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.filesystem")

describe("Filesystem Module", function()
  -- Set up a consistent testing environment
  local temp_test_dir
  local test_files = {}

  before(function()
    -- Create a fresh test directory for each test suite
    temp_test_dir = test_helper.create_temp_test_directory()
    logger.debug("Created test directory", { path = temp_test_dir:path() })
  end)

  after(function()
    -- Logging for test directory cleanup
    -- Note: Actual cleanup is handled automatically by the test runner via temp_file.cleanup_test_context
    if temp_test_dir then
      logger.debug("Test directory will be automatically cleaned up by test runner")
    end
  end)

  describe("Core File Operations", function()
    local test_file_path
    local test_content = "Hello, world!"

    before(function()
      test_file_path = temp_test_dir:path() .. "/test.txt"
    end)

    it("should create directories", function()
      local dir_path = temp_test_dir:path() .. "/nested/dir"
      local success, err = fs.create_directory(dir_path)

      expect(err).to_not.exist()
      expect(success).to.be_truthy()
      expect(fs.directory_exists(dir_path)).to.be_truthy()
    end)

    it("should write and read files", function()
      local write_success, write_err = fs.write_file(test_file_path, test_content)

      expect(write_err).to_not.exist()
      expect(write_success).to.be_truthy()
      expect(fs.file_exists(test_file_path)).to.be_truthy()

      local read_content, read_err = fs.read_file(test_file_path)

      expect(read_err).to_not.exist()
      expect(read_content).to.equal(test_content)
    end)

    it("should append to files", function()
      local file_path = temp_test_dir:path() .. "/append.txt"
      local initial_content = "Initial content"
      local append_content = "\nAppended content"

      -- Write initial content
      local write_success, write_err = fs.write_file(file_path, initial_content)
      expect(write_err).to_not.exist()
      expect(write_success).to.be_truthy()

      -- Append content
      local append_success, append_err = fs.append_file(file_path, append_content)
      expect(append_err).to_not.exist()
      expect(append_success).to.be_truthy()

      -- Read and verify
      local read_content, read_err = fs.read_file(file_path)
      expect(read_err).to_not.exist()
      expect(read_content).to.equal(initial_content .. append_content)
    end)

    it("should delete files", function()
      local file_path = temp_test_dir:path() .. "/to_delete.txt"

      -- Create a file
      local write_success = fs.write_file(file_path, "Delete me")
      expect(write_success).to.be_truthy()
      expect(fs.file_exists(file_path)).to.be_truthy()

      -- Delete the file
      local delete_success, delete_err = fs.delete_file(file_path)
      expect(delete_err).to_not.exist()
      expect(delete_success).to.be_truthy()
      expect(fs.file_exists(file_path)).to.be_falsy()
    end)

    it("should copy files", function()
      local source_path = temp_test_dir:path() .. "/source.txt"
      local target_path = temp_test_dir:path() .. "/target.txt"
      local content = "Test content for copying"

      -- Create source file
      local write_success = fs.write_file(source_path, content)
      expect(write_success).to.be_truthy()

      -- Copy file
      local copy_success, copy_err = fs.copy_file(source_path, target_path)
      expect(copy_err).to_not.exist()
      expect(copy_success).to.be_truthy()

      -- Verify target file exists and has same content
      expect(fs.file_exists(target_path)).to.be_truthy()
      local target_content = fs.read_file(target_path)
      expect(target_content).to.equal(content)
    end)

    it("should move files", function()
      local source_path = temp_test_dir:path() .. "/move_source.txt"
      local target_path = temp_test_dir:path() .. "/move_target.txt"
      local content = "Test content for moving"

      -- Create source file
      local write_success = fs.write_file(source_path, content)
      expect(write_success).to.be_truthy()

      -- Move file
      local move_success, move_err = fs.move_file(source_path, target_path)
      expect(move_err).to_not.exist()
      expect(move_success).to.be_truthy()

      -- Verify source is gone and target has the content
      expect(fs.file_exists(source_path)).to.be_falsy()
      expect(fs.file_exists(target_path)).to.be_truthy()
      local target_content = fs.read_file(target_path)
      expect(target_content).to.equal(content)
    end)

    it("should handle errors correctly", { expect_error = true }, function()
      -- Invalid file path
      local result, err = fs.read_file("/nonexistent/path.txt")
      expect(result).to_not.exist()
      expect(err).to.exist()
    end)
  end)

  describe("Directory Operations", function()
    local test_dir

    before(function()
      test_dir = temp_test_dir:path() .. "/test_dir"
      fs.create_directory(test_dir)
    end)

    it("should create and delete directories", function()
      local new_dir = test_dir .. "/new_dir"

      -- Create directory
      local create_success, create_err = fs.create_directory(new_dir)
      expect(create_err).to_not.exist()
      expect(create_success).to.be_truthy()
      expect(fs.directory_exists(new_dir)).to.be_truthy()

      -- Delete directory
      local delete_success, delete_err = fs.delete_directory(new_dir)
      expect(delete_err).to_not.exist()
      expect(delete_success).to.be_truthy()
      expect(fs.directory_exists(new_dir)).to.be_falsy()
    end)

    it("should recursively delete directories", function()
      local parent_dir = test_dir .. "/parent"
      local child_dir = parent_dir .. "/child"
      local file_in_child = child_dir .. "/file.txt"

      -- Create nested structure
      fs.create_directory(parent_dir)
      fs.create_directory(child_dir)
      fs.write_file(file_in_child, "test content")

      -- Verify structure exists
      expect(fs.directory_exists(parent_dir)).to.be_truthy()
      expect(fs.directory_exists(child_dir)).to.be_truthy()
      expect(fs.file_exists(file_in_child)).to.be_truthy()

      -- Delete recursively
      local delete_success, delete_err = fs.delete_directory(parent_dir, true)
      expect(delete_err).to_not.exist()
      expect(delete_success).to.be_truthy()

      -- Verify all is gone
      expect(fs.directory_exists(parent_dir)).to.be_falsy()
    end)

    it("should copy directories", function()
      local source_dir = test_dir .. "/source_dir"
      local target_dir = test_dir .. "/target_dir"
      local file_in_source = source_dir .. "/file.txt"
      local content = "Test content for directory copying"

      -- Create source structure
      fs.create_directory(source_dir)
      fs.write_file(file_in_source, content)

      -- Copy directory
      local copy_success, copy_err = fs.copy_directory(source_dir, target_dir)
      expect(copy_err).to_not.exist()
      expect(copy_success).to.be_truthy()

      -- Verify target structure
      expect(fs.directory_exists(target_dir)).to.be_truthy()
      expect(fs.file_exists(target_dir .. "/file.txt")).to.be_truthy()
      local copied_content = fs.read_file(target_dir .. "/file.txt")
      expect(copied_content).to.equal(content)
    end)

    it("should get directory contents with and without hidden files", function()
      local content_dir = test_dir .. "/content_test"
      fs.create_directory(content_dir)

      -- Create regular files
      fs.write_file(content_dir .. "/visible1.txt", "visible file 1")
      fs.write_file(content_dir .. "/visible2.txt", "visible file 2")

      -- Create hidden files
      fs.write_file(content_dir .. "/.hidden1", "hidden file 1")
      fs.write_file(content_dir .. "/.hidden2", "hidden file 2")

      -- Test without hidden files (default)
      local contents1, err1 = fs.get_directory_contents(content_dir)
      expect(err1).to_not.exist()
      expect(contents1).to.exist()
      expect(#contents1).to.equal(2)

      -- Verify only visible files are included
      local visible_files = { "visible1.txt", "visible2.txt" }
      table.sort(contents1)
      for i, file in ipairs(visible_files) do
        expect(contents1[i]).to.equal(file)
      end

      -- Test with hidden files
      local contents2, err2 = fs.get_directory_contents(content_dir, true)
      expect(err2).to_not.exist()
      expect(contents2).to.exist()
      expect(#contents2).to.equal(4)

      -- Count visible and hidden files
      local visible_count = 0
      local hidden_count = 0
      for _, file in ipairs(contents2) do
        if file:match("^%.") then
          hidden_count = hidden_count + 1
        else
          visible_count = visible_count + 1
        end
      end

      expect(visible_count).to.equal(2)
      expect(hidden_count).to.equal(2)
    end)
  end)

  describe("Path Operations", function()
    it("should join paths correctly", function()
      local path1 = "/path/to"
      local path2 = "file.txt"

      local joined = fs.join_paths(path1, path2)
      expect(joined).to.equal("/path/to/file.txt")

      -- Test with trailing slash in first path
      local path_with_slash = "/path/to/"
      local joined2 = fs.join_paths(path_with_slash, path2)
      expect(joined2).to.equal("/path/to/file.txt")

      -- Test with multiple path components
      local multi_joined = fs.join_paths("/base", "subdir", "file.txt")
      expect(multi_joined).to.equal("/base/subdir/file.txt")
    end)

    it("should normalize paths", function()
      local abnormal_path = "/path/./to/../to/file.txt"
      local normal_path = fs.normalize_path(abnormal_path)
      expect(normal_path).to.equal("/path/to/file.txt")

      -- Test with double slashes
      local double_slash_path = "/path//to/file.txt"
      local normalized = fs.normalize_path(double_slash_path)
      expect(normalized).to.equal("/path/to/file.txt")
    end)

    it("should extract directory names correctly", function()
      local path = "/path/to/file.txt"
      local dir = fs.get_directory_name(path)
      expect(dir).to.equal("/path/to")

      -- Test with trailing slash
      local path_with_slash = "/path/to/dir/"
      local dir2 = fs.get_directory_name(path_with_slash)
      expect(dir2).to.equal("/path/to/dir")
    end)

    it("should extract file names correctly", function()
      local path = "/path/to/file.txt"
      local filename = fs.get_file_name(path)
      expect(filename).to.equal("file.txt")

      -- Test with no directory
      local simple_path = "file.txt"
      local simple_filename = fs.get_file_name(simple_path)
      expect(simple_filename).to.equal("file.txt")
    end)

    it("should extract file base names and extensions", function()
      local path = "/path/to/file.txt"
      local basename = fs.basename(path)
      local extension = fs.get_extension(path)

      expect(basename).to.equal("file.txt")
      expect(extension).to.equal("txt")

      -- Test file with no extension
      local no_ext_path = "/path/to/noextension"
      local no_ext_basename = fs.basename(no_ext_path)
      local no_ext_extension = fs.get_extension(no_ext_path)

      expect(no_ext_basename).to.equal("noextension")
      expect(no_ext_extension).to.equal("")

      -- Test file with multiple dots
      local multi_dot_path = "/path/to/archive.tar.gz"

      -- Test basename without suffix (should return the full filename)
      local multi_basename = fs.basename(multi_dot_path)
      expect(multi_basename).to.equal("archive.tar.gz")

      -- Test basename with suffix removal (Unix basename behavior)
      local multi_basename_no_ext = fs.basename(multi_dot_path, ".gz")
      expect(multi_basename_no_ext).to.equal("archive.tar")

      -- Test get_extension function
      local multi_extension = fs.get_extension(multi_dot_path)
      expect(multi_extension).to.equal("gz")
    end)

    it("should determine if paths are absolute", function()
      -- Unix absolute path
      local unix_abs = "/absolute/path"
      expect(fs.is_absolute_path(unix_abs)).to.be.truthy()

      -- Unix relative path
      local unix_rel = "relative/path"
      expect(fs.is_absolute_path(unix_rel)).to.be.falsy()

      -- Windows style absolute path (if supported)
      if fs.is_windows() then
        local win_abs = "C:\\Windows\\Path"
        expect(fs.is_absolute_path(win_abs)).to.be.truthy()
      end
    end)
  end)

  describe("Alias Functions", function()
    local test_dir
    local test_file_path
    local test_subdir_path

    before(function()
      test_dir = temp_test_dir:path() .. "/alias_test"
      fs.create_directory(test_dir)
      test_file_path = test_dir .. "/test_file.txt"
      fs.write_file(test_file_path, "test content")
      test_subdir_path = test_dir .. "/test_subdir"
      fs.create_directory(test_subdir_path)
    end)

    it("should have remove_directory as alias for delete_directory", function()
      -- Create a directory to delete
      local dir_to_delete = test_dir .. "/dir_to_delete"
      fs.create_directory(dir_to_delete)

      -- Verify both functions exist
      expect(fs.delete_directory).to.exist()
      expect(fs.remove_directory).to.exist()

      -- Test the alias function
      local success, err = fs.remove_directory(dir_to_delete, true)
      expect(err).to_not.exist()
      expect(success).to.be_truthy()

      -- Verify directory was deleted
      expect(fs.directory_exists(dir_to_delete)).to.be_falsy()
    end)

    it("should have remove_file as alias for delete_file", function()
      -- Create a file to delete
      local file_to_delete = test_dir .. "/file_to_delete.txt"
      fs.write_file(file_to_delete, "delete me")

      -- Verify both functions exist
      expect(fs.delete_file).to.exist()
      expect(fs.remove_file).to.exist()

      -- Test the alias function
      local success, err = fs.remove_file(file_to_delete)
      expect(err).to_not.exist()
      expect(success).to.be_truthy()

      -- Verify file was deleted
      expect(fs.file_exists(file_to_delete)).to.be_falsy()
    end)

    it("should have get_directory as alias for get_directory_name", function()
      -- Verify both functions exist
      expect(fs.get_directory_name).to.exist()
      expect(fs.get_directory).to.exist()

      -- Test both functions with the same input
      local dir1 = fs.get_directory_name(test_file_path)
      local dir2 = fs.get_directory(test_file_path)

      -- Both should return the same result
      expect(dir1).to.equal(dir2)
      expect(dir1).to.equal(test_dir)
    end)

    it("should have get_filename as alias for get_file_name", function()
      -- Verify both functions exist
      expect(fs.get_file_name).to.exist()
      expect(fs.get_filename).to.exist()

      -- Test both functions with the same input
      local name1 = fs.get_file_name(test_file_path)
      local name2 = fs.get_filename(test_file_path)

      -- Both should return the same result
      expect(name1).to.equal(name2)
      expect(name1).to.equal("test_file.txt")
    end)

    it("should have get_file_modified_time as alias for get_modified_time", function()
      -- Verify both functions exist
      expect(fs.get_modified_time).to.exist()
      expect(fs.get_file_modified_time).to.exist()

      -- Test both functions with the same input
      local time1 = fs.get_modified_time(test_file_path)
      local time2 = fs.get_file_modified_time(test_file_path)

      -- Both should return the same result
      expect(time1).to.equal(time2)
      expect(type(time1)).to.equal("number")
    end)

    it("should have get_directory_items as alias for get_directory_contents", function()
      -- Create test files in the subdirectory
      fs.write_file(test_subdir_path .. "/file1.txt", "content 1")
      fs.write_file(test_subdir_path .. "/file2.txt", "content 2")
      fs.write_file(test_subdir_path .. "/.hidden", "hidden content")

      -- Verify both functions exist
      expect(fs.get_directory_contents).to.exist()
      expect(fs.get_directory_items).to.exist()

      -- Test both functions with the same input (without hidden files)
      local items1, err1 = fs.get_directory_contents(test_subdir_path)
      local items2, err2 = fs.get_directory_items(test_subdir_path)

      expect(err1).to_not.exist()
      expect(err2).to_not.exist()
      expect(items1).to.exist()
      expect(items2).to.exist()

      -- Both should return the same result
      expect(#items1).to.equal(#items2)

      -- Sort both tables to ensure consistent comparison
      table.sort(items1)
      table.sort(items2)

      for i, item in ipairs(items1) do
        expect(item).to.equal(items2[i])
      end

      -- Test with hidden files
      local items3, err3 = fs.get_directory_contents(test_subdir_path, true)
      local items4, err4 = fs.get_directory_items(test_subdir_path, true)

      expect(err3).to_not.exist()
      expect(err4).to_not.exist()
      expect(items3).to.exist()
      expect(items4).to.exist()

      -- Both should return the same result
      expect(#items3).to.equal(#items4)
      expect(#items3).to.equal(3) -- 2 regular files + 1 hidden file

      -- Sort both tables to ensure consistent comparison
      table.sort(items3)
      table.sort(items4)

      for i, item in ipairs(items3) do
        expect(item).to.equal(items4[i])
      end
    end)

    it("should have list_directory using get_directory_contents", function()
      -- Create test directory with mixed files
      local list_dir = test_dir .. "/list_dir"
      fs.create_directory(list_dir)

      -- Create regular files
      fs.write_file(list_dir .. "/file1.txt", "file 1")
      fs.write_file(list_dir .. "/file2.txt", "file 2")
      -- Create hidden file
      fs.write_file(list_dir .. "/.hidden", "hidden file")

      -- Compare implementation results
      local contents1, err1 = fs.list_directory(list_dir)
      local contents2, err2 = fs.get_directory_contents(list_dir)

      expect(err1).to_not.exist()
      expect(err2).to_not.exist()
      expect(contents1).to.exist()
      expect(contents2).to.exist()

      -- Both functions should return the same result
      expect(#contents1).to.equal(#contents2)

      -- Sort both tables to ensure consistent comparison
      table.sort(contents1)
      table.sort(contents2)

      for i, item in ipairs(contents1) do
        expect(item).to.equal(contents2[i])
      end

      -- Test with hidden files parameter
      local with_hidden, err3 = fs.list_directory(list_dir, true)
      local without_hidden, err4 = fs.list_directory(list_dir, false)

      expect(err3).to_not.exist()
      expect(err4).to_not.exist()
      expect(with_hidden).to.exist()
      expect(without_hidden).to.exist()

      -- With hidden should have more files
      expect(#with_hidden).to.equal(3)
      expect(#without_hidden).to.equal(2)
    end)
  end)

  describe("Information Functions", function()
    local test_dir
    local test_file_path
    local test_content = "Test content for information functions"

    before(function()
      test_dir = temp_test_dir:path() .. "/info_test"
      fs.create_directory(test_dir)
      test_file_path = test_dir .. "/info_file.txt"
      fs.write_file(test_file_path, test_content)

      -- Create a subdirectory for testing directory functions
      local test_subdir = test_dir .. "/subdir"
      fs.create_directory(test_subdir)
    end)

    it("should check file existence correctly", function()
      -- Existing file
      expect(fs.file_exists(test_file_path)).to.be_truthy()

      -- Non-existent file
      expect(fs.file_exists(test_dir .. "/nonexistent.txt")).to.be_falsy()

      -- Directory (not a file)
      expect(fs.file_exists(test_dir)).to.be_falsy()
    end)

    it("should check directory existence correctly", function()
      -- Existing directory
      expect(fs.directory_exists(test_dir)).to.be_truthy()

      -- Non-existent directory
      expect(fs.directory_exists(test_dir .. "/nonexistent")).to.be_falsy()

      -- File (not a directory)
      expect(fs.directory_exists(test_file_path)).to.be_falsy()
    end)

    it("should retrieve file size correctly", function()
      local size, err = fs.get_file_size(test_file_path)

      expect(err).to_not.exist()
      expect(size).to.equal(#test_content)
    end)

    it("should handle non-existent files for size retrieval", function()
      -- Test with non-existent file using test_helper.expect_error
      local result = fs.get_file_size(test_dir .. "/nonexistent.txt")

      expect(result).to_not.exist()
    end)

    it("should retrieve file modification time", function()
      local mod_time, err = fs.get_modified_time(test_file_path)

      expect(err).to_not.exist()
      expect(mod_time).to.exist()
      expect(type(mod_time)).to.equal("number")

      -- The file was just created, so its modification time should be recent
      local current_time = os.time()
      local time_diff = current_time - mod_time

      -- Allow for a small time difference (< 60 seconds)
      expect(time_diff < 60).to.be_truthy()
    end)

    it("should handle non-existent files for modification time retrieval", function()
      -- Test with non-existent file using test_helper.expect_error
      local result = fs.get_modified_time(test_dir .. "/nonexistent.txt")

      expect(result).to_not.exist()
    end)

    it("should check if path is a file or directory", function()
      -- Check is_file
      expect(fs.is_file(test_file_path)).to.be_truthy()
      expect(fs.is_file(test_dir)).to.be_falsy()
      expect(fs.is_file(test_dir .. "/nonexistent.txt")).to.be_falsy()

      -- Check is_directory
      expect(fs.is_directory(test_dir)).to.be_truthy()
      expect(fs.is_directory(test_file_path)).to.be_falsy()
      expect(fs.is_directory(test_dir .. "/nonexistent")).to.be_falsy()
    end)

    it("should handle symlinks correctly", { skip = not fs.supports_symlinks }, function()
      local symlink_path = test_dir .. "/symlink.txt"

      -- Create a symlink if the platform supports it
      local symlink_success, symlink_err = fs.create_symlink(test_file_path, symlink_path)

      if symlink_success then
        expect(fs.is_symlink(symlink_path)).to.be_truthy()
        expect(fs.is_symlink(test_file_path)).to.be_falsy()

        -- Symlinks should also appear as files
        expect(fs.file_exists(symlink_path)).to.be_truthy()

        -- Get the target of the symlink
        local target, target_err = fs.get_symlink_target(symlink_path)
        expect(target_err).to_not.exist()
        expect(target).to.equal(test_file_path)
      else
        logger.info("Symlinks not supported on this platform, skipping test")
      end
    end)

    it("should handle nil inputs gracefully", function()
      -- Test with invalid inputs using test_helper.expect_error
      local result = fs.get_file_size(nil)

      expect(result).to_not.exist()
    end)

    it("should handle directory inputs for file operations", function()
      -- Test with directory instead of file using test_helper.expect_error
      local result = fs.get_file_size(test_dir)

      expect(result).to_not.exist()
    end)

    it("should handle non-existent files", function()
      -- Test file operations on non-existent file using test_helper.expect_error
      local result = fs.read_file(test_dir .. "/nonexistent.txt")

      expect(result).to_not.exist()
    end)
  end)
end)
