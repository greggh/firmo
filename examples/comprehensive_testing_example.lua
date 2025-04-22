-- comprehensive_testing_example.lua
-- A comprehensive example demonstrating best practices for testing with Firmo
-- Including temp file management, error handling, assertions, and test organization

-- Import the Firmo framework
local firmo = require("firmo")

-- Extract test functions (recommended approach)
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import supporting modules
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local temp_file = require("lib.tools.filesystem.temp_file")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Configure logger for this example
local logger = logging.get_logger("comprehensive_example")

-- ===================================================================
-- Example Module to Test - A simple file processor
-- ===================================================================
local FileProcessor = {}

-- Create a new file processor instance
function FileProcessor.new()
  return {
    -- Internal state
    _files = {},
    _config = {
      max_file_size = 1024 * 1024, -- 1MB default
      allowed_extensions = { lua = true, txt = true, json = true },
    },
    
    -- Configure the processor
    configure = function(self, options)
      if not options or type(options) ~= "table" then
        return nil, error_handler.validation_error(
          "Options must be a table",
          { parameter = "options", provided_type = type(options) }
        )
      end
      
      if options.max_file_size then
        if type(options.max_file_size) ~= "number" or options.max_file_size <= 0 then
          return nil, error_handler.validation_error(
            "max_file_size must be a positive number",
            { parameter = "max_file_size", provided_value = options.max_file_size }
          )
        end
        self._config.max_file_size = options.max_file_size
      end
      
      if options.allowed_extensions then
        if type(options.allowed_extensions) ~= "table" then
          return nil, error_handler.validation_error(
            "allowed_extensions must be a table",
            { parameter = "allowed_extensions", provided_type = type(options.allowed_extensions) }
          )
        end
        
        self._config.allowed_extensions = {}
        for _, ext in ipairs(options.allowed_extensions) do
          self._config.allowed_extensions[ext] = true
        end
      end
      
      return true
    end,
    
    -- Add a file to process
    add_file = function(self, file_path)
      -- Validate parameters
      if not file_path or type(file_path) ~= "string" then
        return nil, error_handler.validation_error(
          "File path must be a string",
          { parameter = "file_path", provided_type = type(file_path) }
        )
      end
      
      -- Check if file exists
      local exists, file_exists_err = error_handler.safe_io_operation(
        function() return fs.file_exists(file_path) end,
        file_path,
        { operation = "check_file_exists" }
      )
      
      if not exists then
        return nil, file_exists_err
      end
      
      if not exists then
        return nil, error_handler.io_error(
          "File does not exist",
          { file_path = file_path }
        )
      end
      
      -- Check file extension
      local extension = file_path:match("%.([^%.]+)$")
      if not extension or not self._config.allowed_extensions[extension] then
        return nil, error_handler.validation_error(
          "File has invalid extension",
          { file_path = file_path, extension = extension or "none", 
            allowed = table.concat(self:get_allowed_extensions(), ", ") }
        )
      end
      
      -- Check file size
      local size, size_err = error_handler.safe_io_operation(
        function() return fs.get_file_size(file_path) end,
        file_path,
        { operation = "get_file_size" }
      )
      
      if not size then
        return nil, size_err
      end
      
      if size > self._config.max_file_size then
        return nil, error_handler.validation_error(
          "File is too large",
          { file_path = file_path, size = size, max_size = self._config.max_file_size }
        )
      end
      
      -- Add file to internal tracking
      table.insert(self._files, {
        path = file_path,
        size = size,
        added_at = os.time()
      })
      
      return true
    end,
    
    -- Process all added files
    process = function(self)
      if #self._files == 0 then
        return nil, error_handler.validation_error(
          "No files have been added for processing",
          { files_count = 0 }
        )
      end
      
      local results = {
        processed = 0,
        failed = 0,
        files = {}
      }
      
      for _, file_info in ipairs(self._files) do
        local content, read_err = error_handler.safe_io_operation(
          function() return fs.read_file(file_info.path) end,
          file_info.path,
          { operation = "read_file" }
        )
        
        if not content then
          results.failed = results.failed + 1
          table.insert(results.files, {
            path = file_info.path,
            success = false,
            error = read_err
          })
        else
          -- Process content (for this example, just count lines and characters)
          local line_count = 0
          for _ in content:gmatch("[^\r\n]+") do
            line_count = line_count + 1
          end
          
          results.processed = results.processed + 1
          table.insert(results.files, {
            path = file_info.path,
            success = true,
            stats = {
              size = file_info.size,
              lines = line_count,
              chars = #content
            }
          })
        end
      end
      
      -- Clear file list after processing
      self._files = {}
      
      return results
    end,
    
    -- Get allowed file extensions
    get_allowed_extensions = function(self)
      local extensions = {}
      for ext, _ in pairs(self._config.allowed_extensions) do
        table.insert(extensions, ext)
      end
      return extensions
    end,
    
    -- Reset processor state
    reset = function(self)
      self._files = {}
      -- Config is preserved
      return true
    end
  }
end

-- ===================================================================
-- Tests - Using Firmo's BDD-style nested blocks
-- ===================================================================
describe("FileProcessor", function()
  -- Setup variables for test suite
  local processor
  local test_dir
  local test_files = {}
  
  -- Setup that runs before each test
  before(function()
    -- Create a fresh instance for each test
    processor = FileProcessor.new()
    
    -- Create a temporary test directory with automatically tracked cleanup
    test_dir = test_helper.create_temp_test_directory()
    
    logger.debug("Test setup complete", {
      directory = test_dir.path,
      extensions = table.concat(processor:get_allowed_extensions(), ", ")
    })
  end)
  
  -- Cleanup after each test
  after(function()
    -- Clean up resources (test_dir is auto-cleaned by create_temp_test_directory)
    processor:reset()
    logger.debug("Test cleanup complete")
  end)
  
  -- Test basic initialization
  describe("Initialization", function()
    it("should initialize with default configuration", function()
      expect(processor).to.exist()
      expect(processor._config).to.exist()
      expect(processor._config.max_file_size).to.equal(1024 * 1024)
      expect(processor._config.allowed_extensions).to.exist()
      expect(processor._config.allowed_extensions.lua).to.be_truthy()
    end)
    
    it("can be configured with custom settings", function()
      local success, err = processor:configure({
        max_file_size = 2048,
        allowed_extensions = {"csv", "xml"}
      })
      
      expect(err).to_not.exist()
      expect(success).to.be_truthy()
      expect(processor._config.max_file_size).to.equal(2048)
      expect(processor._config.allowed_extensions.csv).to.be_truthy()
      expect(processor._config.allowed_extensions.lua).to_not.exist()
    end)
    
    -- Example of error testing with expect_error flag
    it("rejects invalid configuration", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return processor:configure("not a table")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("must be a table")
    end)
  end)
  
  -- Test file validation
  describe("File Validation", function()
    -- Using the test directory helper to create test files
    before(function()
      -- Create test files with content
      test_dir.create_file("valid.lua", "-- A valid Lua file\nreturn {success = true}")
      test_dir.create_file("valid.txt", "This is a text file")
      test_dir.create_file("invalid.bin", "Binary content")
      
      -- Create a large file that exceeds the limit
      local large_content = string.rep("x", processor._config.max_file_size + 100)
      test_dir.create_file("large.txt", large_content)
    end)
    
    it("accepts valid files with allowed extensions", function()
      local file_path = test_dir.path .. "/valid.lua"
      local success, err = processor:add_file(file_path)
      
      expect(err).to_not.exist()
      expect(success).to.be_truthy()
      
      -- Check that file was added to internal tracking
      expect(#processor._files).to.equal(1)
      expect(processor._files[1].path).to.equal(file_path)
    end)
    
    it("rejects files with invalid extensions", { expect_error = true }, function()
      local file_path = test_dir.path .. "/invalid.bin"
      local result, err = test_helper.with_error_capture(function()
        return processor:add_file(file_path)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("invalid extension")
      expect(err.context.extension).to.equal("bin")
    end)
    
    it("rejects files that exceed size limit", { expect_error = true }, function()
      local file_path = test_dir.path .. "/large.txt"
      local result, err = test_helper.with_error_capture(function()
        return processor:add_file(file_path)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("too large")
    end)
    
    it("rejects non-existent files", { expect_error = true }, function()
      local file_path = test_dir.path .. "/nonexistent.lua"
      local result, err = test_helper.with_error_capture(function()
        return processor:add_file(file_path)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.IO)
    end)
  end)
  
  -- Test processing functionality
  describe("File Processing", function()
    before(function()
      -- Create test files with different content
      test_dir.create_file("file1.lua", "-- First file\nlocal x = 10\nreturn x")
      test_dir.create_file("file2.txt", "Line 1\nLine 2\nLine 3\nLine 4")
      
      -- Add files to processor
      processor:add_file(test_dir.path .. "/file1.lua")
      processor:add_file(test_dir.path .. "/file2.txt")
    end)
    
    it("should process all added files", function()
      local results, err = processor:process()
      
      expect(err).to_not.exist()
      expect(results).to.exist()
      expect(results.processed).to.equal(2)
      expect(results.failed).to.equal(0)
      expect(#results.files).to.equal(2)
      
      -- Check stats for first file
      expect(results.files[1].success).to.be_truthy()
      expect(results.files[1].stats.lines).to.equal(3)
      
      -- Check stats for second file
      expect(results.files[2].success).to.be_truthy()
      expect(results.files[2].stats.lines).to.equal(4)
    end)
    
    it("should clear file list after processing", function()
      processor:process()
      
      -- Check that internal file list is cleared
      expect(#processor._files).to.equal(0)
      
      -- Trying to process again should fail
      local results, err = test_helper.with_error_capture(function()
        return processor:process()
      end)()
      
      expect(results).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("No files")
    end)
  end)
  
  -- Test reset functionality
  describe("Reset Functionality", function()
    before(function()
      -- Add a file to processor
      test_dir.create_file("reset_test.lua", "-- Test file for reset")
      processor:add_file(test_dir.path .. "/reset_test.lua")
    end)
    
    it("should clear file list on reset", function()
      -- Verify file is added
      expect(#processor._files).to.equal(1)
      
      -- Reset the processor
      local success = processor:reset()
      expect(success).to.be_truthy()
      
      -- Check that internal file list is cleared
      expect(#processor._files).to.equal(0)
    end)
    
    it("should preserve configuration after reset", function()
      -- Set custom configuration
      processor:configure({
        max_file_size = 5000,
        allowed_extensions = {"xml"}
      })
      
      -- Reset the processor
      processor:reset()
      
      -- Check that configuration is preserved
      expect(processor._config.max_file_size).to.equal(5000)
      expect(processor._config.allowed_extensions.xml).to.be_truthy()
    end)
  end)
end)

-- NOTE: Run this example using the standard test runner:
-- lua test.lua examples/comprehensive_testing_example.lua