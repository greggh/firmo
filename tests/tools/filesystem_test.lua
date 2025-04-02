-- Tests for the filesystem module
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

describe("Filesystem", function()
  -- Test get_directory_contents with hidden files
  describe("get_directory_contents", function()
    local test_dir

    before(function()
      test_dir = test_helper.create_temp_test_directory()
      -- Create regular files
      test_dir.create_file("visible1.txt", "visible file 1")
      test_dir.create_file("visible2.txt", "visible file 2")
      -- Create hidden files
      test_dir.create_file(".hidden1", "hidden file 1")
      test_dir.create_file(".hidden2", "hidden file 2")
    end)

    it("should list only visible files by default", function()
      local contents, err = fs.get_directory_contents(test_dir.path)
      expect(err).to_not.exist()
      expect(contents).to.exist()
      expect(#contents).to.equal(2)
      
      -- Check that we only see the visible files
      local has_visible1 = false
      local has_visible2 = false
      local has_hidden = false
      
      for _, file in ipairs(contents) do
        if file == "visible1.txt" then has_visible1 = true end
        if file == "visible2.txt" then has_visible2 = true end
        if file:match("^%.") then has_hidden = true end
      end
      
      expect(has_visible1).to.be_truthy()
      expect(has_visible2).to.be_truthy()
      expect(has_hidden).to.be_falsy()
    end)

    it("should include hidden files when include_hidden is true", function()
      local contents, err = fs.get_directory_contents(test_dir.path, true)
      expect(err).to_not.exist()
      expect(contents).to.exist()
      expect(#contents).to.equal(4)
      
      -- Check that we see all files including hidden ones
      local visible_count = 0
      local hidden_count = 0
      
      for _, file in ipairs(contents) do
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

  -- Test list_directory using get_directory_contents
  describe("list_directory", function()
    local test_dir

    before(function()
      test_dir = test_helper.create_temp_test_directory()
      -- Create regular files
      test_dir.create_file("file1.txt", "file 1")
      test_dir.create_file("file2.txt", "file 2")
      -- Create hidden file
      test_dir.create_file(".hidden", "hidden file")
    end)

    it("should use get_directory_contents for implementation", function()
      local contents1, err1 = fs.list_directory(test_dir.path)
      local contents2, err2 = fs.get_directory_contents(test_dir.path)
      
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
    end)

    it("should handle hidden files parameter correctly", function()
      local with_hidden, err1 = fs.list_directory(test_dir.path, true)
      local without_hidden, err2 = fs.list_directory(test_dir.path, false)
      
      expect(err1).to_not.exist()
      expect(err2).to_not.exist()
      expect(with_hidden).to.exist()
      expect(without_hidden).to.exist()
      
      -- With hidden should have more files
      expect(#with_hidden).to.equal(3)
      expect(#without_hidden).to.equal(2)
      
      -- Check that hidden files are included when requested
      local has_hidden = false
      for _, file in ipairs(with_hidden) do
        if file:match("^%.") then has_hidden = true; break end
      end
      expect(has_hidden).to.be_truthy()
      
      -- Check that hidden files are excluded when not requested
      has_hidden = false
      for _, file in ipairs(without_hidden) do
        if file:match("^%.") then has_hidden = true; break end
      end
      expect(has_hidden).to.be_falsy()
    end)
  end)

  -- Test alias functions
  describe("alias functions", function()
    local test_dir
    local test_file_path
    local test_subdir_path

    before(function()
      test_dir = test_helper.create_temp_test_directory()
      test_file_path = test_dir.create_file("test_file.txt", "test content")
      test_subdir_path = test_dir.create_subdirectory("test_subdir")
    end)

    it("should have remove_directory as alias for delete_directory", function()
      -- Create a directory to delete
      local dir_to_delete = test_dir.create_subdirectory("dir_to_delete")
      
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
      local file_to_delete = test_dir.create_file("file_to_delete.txt", "delete me")
      
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
      expect(dir1).to.equal(test_dir.path)
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
      -- Both should return the same result
      expect(time1).to.equal(time2)
      expect(type(time1) == "number").to.be_truthy()
    end)

    it("should have get_directory_items as alias for get_directory_contents", function()
      -- Create test files in the subdirectory
      test_dir.create_file("test_subdir/file1.txt", "content 1")
      test_dir.create_file("test_subdir/file2.txt", "content 2")
      test_dir.create_file("test_subdir/.hidden", "hidden content")
      
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
  end)
end)
