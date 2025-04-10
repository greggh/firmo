-- Tests for the temp_file module

-- Load dependencies first
local firmo_import = require("firmo") -- use a different name to avoid conflicts
local temp_file_import = require("lib.tools.temp_file")
local fs_import = require("lib.tools.filesystem")
local test_helper_import = require("lib.tools.test_helper")

-- Make local copies to avoid upvalue issues
local firmo = firmo_import
local temp_file = temp_file_import
local fs = fs_import
local test_helper = test_helper_import

-- Unpack test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("temp_file", function()
  -- No need to track files for manual cleanup - the temp_file system handles this automatically
  
  describe("basic functionality", function()
    it("should generate temporary file paths", function()
      local path = temp_file.generate_temp_path("lua")
      expect(path).to.be.a("string")
      expect(path).to.match("%.lua$")
    end)
    
    it("should create temporary files with content", function()
      local content = "test content"
      local file_path, err = temp_file.create_with_content(content, "txt")
      
      expect(err).to_not.exist()
      expect(file_path).to.be.a("string")
      expect(file_path).to.match("%.txt$")
      
      -- Verify file exists and has correct content
      expect(fs.file_exists(file_path)).to.be_truthy()
      local file_content = fs.read_file(file_path)
      expect(file_content).to.equal(content)
      
      -- No need to track for cleanup - the temp_file system handles this automatically
    end)
    
    it("should create temporary directories", function()
      local dir_path, err = temp_file.create_temp_directory()
      
      expect(err).to_not.exist()
      expect(dir_path).to.be.a("string")
      expect(fs.directory_exists(dir_path)).to.be_truthy()
      
      -- Add a file to verify directory works
      local test_file = dir_path .. "/test.txt"
      fs.write_file(test_file, "test")
      expect(fs.file_exists(test_file)).to.be_truthy()
      
      -- No need to track for cleanup - the temp_file system handles this automatically
    end)
  end)
  
  describe("resource tracking", function()
    it("should register and track files", function()
      -- Create a file manually
      local file_path = os.tmpname()
      local f = io.open(file_path, "w")
      f:write("test content")
      f:close()
      
      -- Register it with temp_file system
      temp_file.register_file(file_path)
      
      -- Get stats to verify tracking
      local stats = temp_file.get_stats()
      expect(stats.files).to.be_greater_than(0)
      
      -- No need to track for manual cleanup - the temp_file system handles this automatically
    end)
    
    it("should properly clean up tracked resources", function()
      -- Create multiple files
      local paths = {}
      for i = 1, 3 do
        local file_path, err = temp_file.create_with_content("content " .. i, "txt")
        expect(err).to_not.exist()
        table.insert(paths, file_path)
      end
      
      -- Verify all files exist
      for _, path in ipairs(paths) do
        expect(fs.file_exists(path)).to.be_truthy()
      end
      
      -- Clean up using temp_file system
      local success, errors = temp_file.cleanup_all()
      expect(success).to.be_truthy()
      
      -- Verify files are gone
      for _, path in ipairs(paths) do
        expect(fs.file_exists(path)).to.be_falsy()
      end
    end)
  end)
  
  describe("test_helper integration", function()
    it("should create temp test directories with helpers", function()
      local test_dir = test_helper.create_temp_test_directory()
      
      -- Create files using the helper
      local file1 = test_dir.create_file("test.txt", "test content")
      local file2 = test_dir.create_file("nested/file.lua", "return {}")
      
      -- Verify files exist
      expect(fs.file_exists(file1)).to.be_truthy()
      expect(fs.file_exists(file2)).to.be_truthy()
      
      -- Verify helper functions work
      expect(test_dir.file_exists("test.txt")).to.be_truthy()
      expect(test_dir.read_file("test.txt")).to.equal("test content")
      
      -- Cleanup happens automatically through the temp_file system
    end)
    
    it("should create directories with predefined content", function()
      test_helper.with_temp_test_directory({
        ["config.json"] = '{"setting":"value"}',
        ["data.txt"] = "test data",
        ["scripts/helper.lua"] = "return function() return true end"
      }, function(dir_path, files, test_dir)
        -- Verify files were created
        expect(fs.file_exists(dir_path .. "/config.json")).to.be_truthy()
        expect(fs.file_exists(dir_path .. "/data.txt")).to.be_truthy()
        expect(fs.file_exists(dir_path .. "/scripts/helper.lua")).to.be_truthy()
        
        -- Read and verify content
        expect(fs.read_file(dir_path .. "/config.json")).to.equal('{"setting":"value"}')
        
        -- Create additional file
        local new_file = test_dir.create_file("additional.txt", "more data")
        expect(fs.file_exists(new_file)).to.be_truthy()
        
        -- Cleanup happens automatically through the with_temp_test_directory function
      end)
    end)
  end)
  
  describe("error handling", function()
    it("should fail when removing nil file path", { expect_error = true }, function()
      -- Use test_helper.expect_error to properly capture and verify errors
      local err = test_helper.expect_error(function()
        return temp_file.remove(nil)
      end)
      
      expect(err).to.exist()
      expect(err).to.be.a("table")
      expect(err.category).to.exist()
      expect(err.message).to.match("Missing file path")
    end)
    
    it("should fail when removing nil directory path", { expect_error = true }, function()
      -- Use test_helper.expect_error to properly capture and verify errors
      local err = test_helper.expect_error(function()
        return temp_file.remove_directory(nil)
      end)
      
      expect(err).to.exist()
      expect(err).to.be.a("table")
      expect(err.category).to.exist()
      expect(err.message).to.match("Missing directory path")
    end)
  end)
end)