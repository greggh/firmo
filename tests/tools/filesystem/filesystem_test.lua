local firmo = require("firmo")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Filesystem Module", function()
  local test_dir = "/tmp/firmo-fs-test"
  local test_file = "/tmp/firmo-fs-test/test.txt"
  local test_content = "Hello, world!"

  -- Helper function to clean up test directory
  local function cleanup()
    fs.delete_directory(test_dir, true)
  end

  -- Run cleanup before tests
  cleanup()

  -- We don't have after_all, so we'll clean up in the last test
  -- The last test in the file is in the "Information Functions" describe block

  describe("Core File Operations", function()
    it("should create directories", function()
      local success = fs.create_directory(test_dir)
      expect(success).to.be_truthy()
      expect(fs.directory_exists(test_dir)).to.be_truthy()
    end)

    it("should write and read files", function()
      local write_success = fs.write_file(test_file, test_content)
      expect(write_success).to.be_truthy()
      expect(fs.file_exists(test_file)).to.be_truthy()

      local content = fs.read_file(test_file)
      expect(content).to.equal(test_content)
    end)

    it("should append to files", function()
      local append_content = "\nAppended content"
      local append_success = fs.append_file(test_file, append_content)
      expect(append_success).to.be_truthy()

      local content = fs.read_file(test_file)
      expect(content).to.equal(test_content .. append_content)
    end)

    it("should copy files", function()
      local copy_file = "/tmp/firmo-fs-test/test-copy.txt"
      local success = fs.copy_file(test_file, copy_file)
      expect(success).to.be_truthy()
      expect(fs.file_exists(copy_file)).to.be_truthy()

      local content = fs.read_file(copy_file)
      expect(content).to.equal(test_content .. "\nAppended content")
    end)

    it("should move files", function()
      local moved_file = "/tmp/firmo-fs-test/test-moved.txt"
      local copy_file = "/tmp/firmo-fs-test/test-copy.txt"

      local success = fs.move_file(copy_file, moved_file)
      expect(success).to.be_truthy()
      expect(fs.file_exists(moved_file)).to.be_truthy()
      expect(fs.file_exists(copy_file)).to_not.be_truthy()
    end)

    it("should delete files", function()
      local moved_file = "/tmp/firmo-fs-test/test-moved.txt"
      local success = fs.delete_file(moved_file)
      expect(success).to.be_truthy()
      expect(fs.file_exists(moved_file)).to_not.be_truthy()
    end)
  end)

  describe("Directory Operations", function()
    it("should ensure directory exists", function()
      local nested_dir = "/tmp/firmo-fs-test/nested/path"
      local success = fs.ensure_directory_exists(nested_dir)
      expect(success).to.be_truthy()
      expect(fs.directory_exists(nested_dir)).to.be_truthy()
    end)

    it("should get directory contents", function()
      -- Create a few test files
      fs.write_file("/tmp/firmo-fs-test/file1.txt", "File 1")
      fs.write_file("/tmp/firmo-fs-test/file2.txt", "File 2")

      local contents = fs.get_directory_contents(test_dir)
      expect(#contents).to.be.at_least(3) -- file1.txt, file2.txt, nested/ directory

      -- Check if files exist in the listing
      local has_file1 = false
      local has_file2 = false
      local has_nested = false

      for _, item in ipairs(contents) do
        if item == "file1.txt" then
          has_file1 = true
        end
        if item == "file2.txt" then
          has_file2 = true
        end
        if item == "nested" then
          has_nested = true
        end
      end

      expect(has_file1).to.be_truthy()
      expect(has_file2).to.be_truthy()
      expect(has_nested).to.be_truthy()
    end)

    it("should handle non-empty directory deletion gracefully", { expect_error = true }, function()
      local nested_dir = "/tmp/firmo-fs-test/nested"

      -- Try non-recursive delete on non-empty directory (should fail)
      local success, err = fs.delete_directory(nested_dir, false)

      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err).to.match("Directory not empty")
      expect(fs.directory_exists(nested_dir)).to.be_truthy()

      -- Try recursive delete (should succeed)
      success = fs.delete_directory(nested_dir, true)
      expect(success).to.be_truthy()
      expect(fs.directory_exists(nested_dir)).to_not.be_truthy()
    end)
  end)

  describe("Path Manipulation", function()
    it("should normalize paths", function()
      expect(fs.normalize_path("/path/to//file")).to.equal("/path/to/file")
      expect(fs.normalize_path("/path/to/file/")).to.equal("/path/to/file")
      expect(fs.normalize_path("path\\to\\file")).to.equal("path/to/file")
    end)

    it("should join paths", function()
      expect(fs.join_paths("/path", "to", "file")).to.equal("/path/to/file")
      expect(fs.join_paths("/path/", "/to/", "/file")).to.equal("/path/to/file")
      expect(fs.join_paths("path", "./to", "../path/file")).to.equal("path/./to/../path/file")
    end)

    it("should get directory name", function()
      local dir1 = fs.get_directory_name("/path/to/file")
      expect(dir1).to.equal("/path/to")

      local dir2 = fs.get_directory_name("file.txt")
      expect(dir2).to.equal(".")

      local dir3 = fs.get_directory_name("/path/")
      expect(dir3).to.equal("/path")
    end)

    it("should get file name", function()
      -- Get file name from path with directories
      local name1 = fs.get_file_name("/path/to/file.txt")
      expect(name1).to.equal("file.txt")

      -- Directory path should return empty string
      local name2 = fs.get_file_name("/path/to/")
      expect(name2).to.equal("")

      -- Just a filename should return itself
      local name3 = fs.get_file_name("file.txt")
      expect(name3).to.equal("file.txt")
    end)

    it("should get file extension", function()
      expect(fs.get_extension("/path/to/file.txt")).to.equal("txt")
      expect(fs.get_extension("file.tar.gz")).to.equal("gz")
      expect(fs.get_extension("file")).to.equal("")
    end)

    it("should convert to absolute path", function()
      -- This is a bit tricky to test since it depends on current directory
      local abs_path = fs.get_absolute_path("relative/path")
      expect(abs_path:sub(1, 1)).to.equal("/") -- Should start with /
    end)

    it("should convert to relative path", function()
      expect(fs.get_relative_path("/a/b/c/d", "/a/b")).to.equal("c/d")
      expect(fs.get_relative_path("/a/b/c", "/a/b/c/d")).to.equal("..")
      expect(fs.get_relative_path("/a/b/c", "/a/b/c")).to.equal(".")
      expect(fs.get_relative_path("/a/b/c", "/x/y/z")).to.equal("../../../a/b/c")
    end)
  end)

  describe("File Discovery", function()
    it("should convert glob to pattern", function()
      local pattern = fs.glob_to_pattern("*.lua")
      expect(pattern ~= nil).to.be_truthy()
      expect(("test.lua"):match(pattern) ~= nil).to.be_truthy()
      expect(("test.txt"):match(pattern) == nil).to.be_truthy()
    end)

    it("should test if path matches pattern", function()
      expect(fs.matches_pattern("test.lua", "*.lua")).to.be_truthy()
      expect(fs.matches_pattern("test.txt", "*.lua")).to_not.be_truthy()
      expect(fs.matches_pattern("test/file.lua", "test/*.lua")).to.be_truthy()
      expect(fs.matches_pattern("test/file.lua", "test/*.txt")).to_not.be_truthy()
    end)

    it("should discover files", { expect_error = true }, function()
      -- Create test directory structure
      local result = test_helper.with_error_capture(function()
        return fs.ensure_directory_exists("/tmp/firmo-fs-test/discover/a")
      end)()
      expect(result).to.be_truthy()

      result = test_helper.with_error_capture(function()
        return fs.ensure_directory_exists("/tmp/firmo-fs-test/discover/b")
      end)()
      expect(result).to.be_truthy()

      result = test_helper.with_error_capture(function()
        return fs.write_file("/tmp/firmo-fs-test/discover/file1.lua", "test")
      end)()
      expect(result).to.be_truthy()

      result = test_helper.with_error_capture(function()
        return fs.write_file("/tmp/firmo-fs-test/discover/file2.txt", "test")
      end)()
      expect(result).to.be_truthy()

      result = test_helper.with_error_capture(function()
        return fs.write_file("/tmp/firmo-fs-test/discover/a/file3.lua", "test")
      end)()
      expect(result).to.be_truthy()

      result = test_helper.with_error_capture(function()
        return fs.write_file("/tmp/firmo-fs-test/discover/b/file4.lua", "test")
      end)()
      expect(result).to.be_truthy()

      -- Discover files with error handling
      local files, err = test_helper.with_error_capture(function()
        return fs.discover_files({ "/tmp/firmo-fs-test/discover" }, { "*.lua" })
      end)()

      -- If there was an error, handle it
      expect(err).to_not.exist()
      expect(files).to.exist()

      -- No longer using firmo.log, which doesn't exist
      -- Use a logger we know exists
      local logger = require("lib.tools.logging").get_logger("test.filesystem")
      logger.debug("discover_files result", { count = #files })
      for _, file in ipairs(files) do
        logger.trace("discovered file", { path = file })
      end

      expect(#files).to.equal(3) -- Should find all 3 .lua files

      -- Test with exclude patterns
      local filtered_files, filter_err = test_helper.with_error_capture(function()
        return fs.discover_files({ "/tmp/firmo-fs-test/discover" }, { "*.lua" }, { "a/*" })
      end)()

      -- If there was an error, handle it
      expect(filter_err).to_not.exist()
      expect(filtered_files).to.exist()

      expect(#filtered_files).to.equal(2) -- Should exclude file3.lua in directory a
    end)

    it("should scan directory", { expect_error = true }, function()
      local files, err = test_helper.with_error_capture(function()
        return fs.scan_directory("/tmp/firmo-fs-test/discover", false)
      end)()

      expect(err).to_not.exist()
      expect(files).to.exist()
      expect(#files).to.equal(2) -- Should only get files in the root, not subdirectories

      local all_files, all_err = test_helper.with_error_capture(function()
        return fs.scan_directory("/tmp/firmo-fs-test/discover", true)
      end)()

      expect(all_err).to_not.exist()
      expect(all_files).to.exist()
      expect(#all_files).to.equal(4) -- Should get all files recursively
    end)

    it("should find matches", { expect_error = true }, function()
      local all_files, scan_err = test_helper.with_error_capture(function()
        return fs.scan_directory("/tmp/firmo-fs-test/discover", true)
      end)()

      expect(scan_err).to_not.exist()
      expect(all_files).to.exist()

      -- No longer using firmo.log, which doesn't exist
      -- Use a logger we know exists
      local logger = require("lib.tools.logging").get_logger("test.filesystem")
      logger.debug("scan_directory result", { count = #all_files })
      for _, file in ipairs(all_files) do
        logger.trace("scanned file", { path = file })
      end

      local lua_files, match_err = test_helper.with_error_capture(function()
        return fs.find_matches(all_files, "*.lua")
      end)()

      expect(match_err).to_not.exist()
      expect(lua_files).to.exist()

      -- Log lua matches
      logger.debug("find_matches result", { count = #lua_files, pattern = "*.lua" })
      for _, file in ipairs(lua_files) do
        logger.trace("matched file", { path = file })
      end

      expect(#lua_files).to.equal(3) -- Should find all 3 .lua files
    end)
  end)

  describe("Information Functions", function()
    it("should check if file exists", function()
      expect(fs.file_exists(test_file)).to.be_truthy()
      expect(fs.file_exists("/tmp/non-existent-file.txt")).to_not.be_truthy()
    end)

    it("should check if directory exists", function()
      expect(fs.directory_exists(test_dir)).to.be_truthy()
      expect(fs.directory_exists("/tmp/non-existent-directory")).to_not.be_truthy()
    end)

    it("should get file size", function()
      local size = fs.get_file_size(test_file)
      expect(size).to.equal(#(test_content .. "\nAppended content"))
    end)

    it("should check if path is file or directory", function()
      -- Test for file
      expect(fs.is_file(test_file)).to.be_truthy()
      expect(fs.is_directory(test_file)).to_not.be_truthy()

      -- Test for directory
      local is_file = fs.is_file(test_dir)
      expect(is_file).to_not.be_truthy()

      local is_dir = fs.is_directory(test_dir)
      expect(is_dir).to.be_truthy()
    end)

    it("should get modification time", function()
      local time = fs.get_modified_time(test_file)
      expect(time ~= nil).to.be_truthy()
      expect(type(time)).to.equal("number")
    end)

    -- Final cleanup after all tests have run
    it("should clean up test directory", { expect_error = true }, function()
      local success, err = test_helper.with_error_capture(function()
        return fs.delete_directory(test_dir, true)
      end)()

      expect(err).to_not.exist()
      expect(success).to.be_truthy()

      local exists = test_helper.with_error_capture(function()
        return fs.directory_exists(test_dir)
      end)()

      expect(exists).to_not.be_truthy()
    end)
  end)
end)
