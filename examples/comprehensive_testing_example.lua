--- Comprehensive example demonstrating Firmo testing best practices.
---
--- This example showcases a well-structured test suite for a sample `FileProcessor` module,
--- illustrating key Firmo features and recommended patterns:
--- - BDD-style test structure (`describe`, `it`).
--- - Setup and teardown hooks (`before`, `after`) for managing test context.
--- - Various assertion types using `expect`.
--- - Correct error handling testing using `error_handler`, `test_helper.with_error_capture`, and the `expect_error` option.
--- - Managing temporary files and directories safely using `test_helper.create_temp_test_directory`.
--- - Designing a module (`FileProcessor`) that integrates with `central_config`.
--- - Using `logging` effectively within tests and the module under test.
--- - Applying JSDoc for documentation.
---
--- @module examples.comprehensive_testing_example
--- @see firmo
--- @see lib.tools.test_helper
--- @see lib.tools.error_handler
--- @see lib.tools.filesystem
--- @see lib.tools.logging
--- @see lib.core.central_config
--- @usage
--- Run the embedded tests:
--- ```bash
--- lua test.lua examples/comprehensive_testing_example.lua
--- ```

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

-- Import supporting modules
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config")

-- Configure logger for this example
local logger = logging.get_logger("comprehensive_example")

-- ===================================================================
-- Example Module to Test: FileProcessor
-- ===================================================================
--- A simple module designed to process files based on configuration.
-- Demonstrates integration with `central_config` and `error_handler`.
--- @class FileProcessor
--- @field _files table Internal list of files added for processing.
--- @field _config table Internal configuration settings.
--- @field configure fun(self: FileProcessor, options: table): boolean|nil, table|nil Configures the processor instance.
--- @field add_file fun(self: FileProcessor, file_path: string): boolean|nil, table|nil Adds a file to the processing queue after validation.
--- @field process fun(self: FileProcessor): table|nil, table|nil Processes all files in the queue.
--- @field get_allowed_extensions fun(self: FileProcessor): string[] Returns the list of allowed extensions.
--- @field reset fun(self: FileProcessor): boolean Resets the file queue.
--- @within examples.comprehensive_testing_example
local FileProcessor = {}
FileProcessor.__index = FileProcessor -- Allow method calls using ':'

--- Creates a new FileProcessor instance.
--- Initializes configuration from `central_config` (if `file_processor` key exists) or uses defaults.
--- @return FileProcessor processor The new FileProcessor instance.
function FileProcessor:new()
  local cfg = central_config.get() -- Corrected function call
  local default_exts = cfg.file_processor and cfg.file_processor.allowed_extensions or { "lua", "txt", "json" }

  local self = setmetatable({}, FileProcessor) -- Set metatable for ':' syntax

  -- Internal state
  self._files = {}
  local _config = {
    max_file_size = cfg.file_processor and cfg.file_processor.max_file_size or 1024 * 1024, -- 1MB default
    allowed_extensions = {}, -- Initialize empty, populate below
  }

  -- Populate initial allowed extensions from defaults
  for _, ext in ipairs(default_exts) do
    self._config.allowed_extensions[ext:lower()] = true -- Store lowercase
  end

  return self
end

--- Configures the FileProcessor instance with new options, validating inputs.
--- Overrides defaults set during initialization or previous calls.
--- @param self FileProcessor The FileProcessor instance.
--- @param options table A table containing configuration options: `max_file_size` (number), `allowed_extensions` (string[]).
--- @return boolean|nil success `true` on successful configuration, `nil` on validation error.
--- @return table|nil err A validation error object if input options are invalid.
function FileProcessor:configure(options)
  if not options or type(options) ~= "table" then
    return nil,
      error_handler.validation_error(
        "Options must be a table",
        { parameter = "options", provided_type = type(options) }
      )
  end

  if options.max_file_size then
    if type(options.max_file_size) ~= "number" or options.max_file_size <= 0 then
      return nil,
        error_handler.validation_error(
          "max_file_size must be a positive number",
          { parameter = "max_file_size", provided_value = options.max_file_size }
        )
    end
    self._config.max_file_size = options.max_file_size
  end

  if options.allowed_extensions then
    if type(options.allowed_extensions) ~= "table" then
      return nil,
        error_handler.validation_error(
          "allowed_extensions must be a table",
          { parameter = "allowed_extensions", provided_type = type(options.allowed_extensions) }
        )
    end

    self._config.allowed_extensions = {} -- Reset before applying new ones
    for _, ext in ipairs(options.allowed_extensions) do
      if type(ext) == "string" then
        self._config.allowed_extensions[ext:lower()] = true -- Store lowercase
      end
    end
  end
  return true
end

--- Adds a file to the processor's queue after validating its existence,
--- extension, and size against the current configuration.
--- @param self FileProcessor The FileProcessor instance.
--- @param file_path string The absolute path to the file to add.
--- @return boolean|nil success `true` if the file was added successfully, `nil` on error.
--- @return table|nil err A validation or IO error object if the file cannot be added.
function FileProcessor:add_file(file_path)
  -- Validate parameters
  if not file_path or type(file_path) ~= "string" then
    return nil,
      error_handler.validation_error(
        "File path must be a string",
        { parameter = "file_path", provided_type = type(file_path) }
      )
  end

  -- Check if file exists
  local exists, file_exists_err = error_handler.safe_io_operation(function()
    return fs.file_exists(file_path)
  end, file_path, { operation = "check_file_exists" })

  if not exists then
    return nil, file_exists_err
  end

  if not exists then
    return nil, error_handler.io_error("File does not exist", { file_path = file_path })
  end

  -- Check file extension
  local extension = file_path:match("%.([^%.]+)$")
  if not extension or not self._config.allowed_extensions[extension:lower()] then
    return nil,
      error_handler.validation_error(
        "File has invalid extension",
        { file_path = file_path, extension = extension or "none" } -- Removed 'allowed' field
      )
  end

  -- Check file size
  local size, size_err = error_handler.safe_io_operation(function()
    return fs.get_file_size(file_path)
  end, file_path, { operation = "get_file_size" })

  if not size then
    return nil, size_err
  end

  if size > self._config.max_file_size then
    return nil,
      error_handler.validation_error(
        "File is too large",
        { file_path = file_path, size = size, max_size = self._config.max_file_size }
      )
  end

  -- Add file to internal tracking
  table.insert(self._files, {
    path = file_path,
    path = file_path,
    size = size,
    added_at = 0, -- Placeholder timestamp -- Added missing comma
  }) -- Closing parenthesis for table.insert

  return true
end

--- Processes all files currently in the queue.
--- Reads each file, gathers basic stats (lines, chars), and returns a summary.
--- Clears the file queue after processing.
--- @param self FileProcessor The FileProcessor instance.
--- @return table|nil results A table summarizing the processing results (`{ processed: number, failed: number, files: table[] }`), or `nil` on error.
--- @return table|nil err A validation error object if no files were in the queue.
function FileProcessor:process()
  if #self._files == 0 then
    return nil, error_handler.validation_error("No files have been added for processing", { files_count = 0 })
  end

  local results = {
    processed = 0,
    failed = 0,
    files = {},
  }

  for _, file_info in ipairs(self._files) do
    local content, read_err = error_handler.safe_io_operation(function()
      return fs.read_file(file_info.path)
    end, file_info.path, { operation = "read_file" })

    if not content then
      results.failed = results.failed + 1
      table.insert(results.files, {
        path = file_info.path,
        success = false,
        error = read_err,
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
          chars = #content,
        },
      })
    end
  end

  -- Clear file list after processing
  self._files = {}

  return results
end

--- Returns a list of currently allowed file extensions based on the configuration.
--- @param self FileProcessor The FileProcessor instance.
--- @return string[] extensions An array of allowed extensions (e.g., `{"lua", "txt"}`).
function FileProcessor:get_allowed_extensions()
  local extensions = {}
  for ext, _ in pairs(self._config.allowed_extensions) do
    table.insert(extensions, ext)
  end
  return extensions
end

--- Resets the internal state of the processor (clears the file queue)
--- but preserves the current configuration.
--- @param self FileProcessor The FileProcessor instance.
--- @return boolean success Always returns `true`.
function FileProcessor:reset()
  self._files = {}
  -- Config is preserved
  return true
end

-- ===================================================================
-- Tests - Using Firmo's BDD-style nested blocks
-- ===================================================================
--- Main test suite for the FileProcessor module.
--- @within examples.comprehensive_testing_example
describe("FileProcessor", function()
  -- Setup variables accessible within the test suite
  local processor -- The instance of FileProcessor being tested
  local test_dir
  local test_files = {}

  local test_files = {} -- Keep track of manually created files if needed (test_dir helper often sufficient)

  --- Setup function executed before each `it` block in this suite.
  -- Creates a fresh FileProcessor instance and a temporary test directory.
  before(function()
    -- Create a fresh processor instance for isolation between tests
    processor = FileProcessor:new() -- Use ':' for consistency

    -- Create a temporary test directory; automatically registered for cleanup
    test_dir = test_helper.create_temp_test_directory("fileproc_test_")

    logger.debug("Test setup complete", {
      directory = test_dir.path,
      extensions = table.concat(processor:get_allowed_extensions(), ", "),
    })
  end)

  --- Teardown function executed after each `it` block in this suite.
  -- Resets the processor state. Temporary directory is cleaned automatically.
  after(function()
    -- Reset processor state, but directory cleanup is handled by test_helper
    processor:reset()
    logger.debug("Test cleanup complete")
  end)

  --- Tests related to the initialization (`:new()`) and configuration (`:configure()`) of the FileProcessor.
  --- @within examples.comprehensive_testing_example
  describe("Initialization and Configuration", function()
    --- Tests that a new instance has the expected default configuration values.
    it("should initialize with default configuration", function()
      expect(processor).to.exist()
      expect(processor._config).to.exist()
      expect(processor._config.max_file_size).to.equal(1024 * 1024) -- Default 1MB
      expect(processor._config.allowed_extensions).to.exist()
      expect(processor._config.allowed_extensions.lua).to.be_truthy() -- Default includes lua
    end)

    --- Tests that the `:configure()` method correctly updates the processor's internal settings.
    it("can be configured with custom settings using :configure()", function()
      local success, err = processor:configure({
        max_file_size = 2048,
        allowed_extensions = { "csv", "xml" },
      })

      expect(err).to_not.exist()
      expect(success).to.be_truthy()
      expect(processor._config.max_file_size).to.equal(2048)
      expect(processor._config.allowed_extensions.csv).to.be_truthy()
      expect(processor._config.allowed_extensions.lua).to_not.exist()
    end)

    --- Tests that `:configure()` returns an error when provided with invalid options.
    it("rejects invalid configuration options", { expect_error = true }, function()
      -- Test with non-table input
      local result1, err1 = test_helper.with_error_capture(function()
        return processor:configure("not a table")
      end)()

      expect(result1).to_not.exist()
      expect(err1).to.exist()
      expect(err1.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err1.message).to.match("Options must be a table")

      -- Test with invalid max_file_size
      local result2, err2 = test_helper.with_error_capture(function()
        return processor:configure({ max_file_size = -100 })
      end)()

      expect(result2).to_not.exist()
      expect(err2).to.exist()
      expect(err2.message).to.match("must be a positive number")

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("must be a table")
    end)
  end)

  --- Tests focused on the file validation logic within the `:add_file()` method.
  --- @within examples.comprehensive_testing_example
  describe("File Validation (:add_file)", function()
    --- Setup hook to create various test files in the temporary directory before validation tests run.
    before(function()
      -- Create test files with content using the test_dir helper provided by create_temp_test_directory
      test_dir:create_file("valid.lua", "-- A valid Lua file\nreturn {success = true}")
      test_dir:create_file("valid.txt", "This is a text file")
      test_dir:create_file("invalid.bin", "Binary content") -- Invalid extension by default

      -- Create a large file that exceeds the limit
      local large_content = string.rep("x", processor._config.max_file_size + 100)
      test_dir.create_file("large.txt", large_content)
    end)

    --- Tests that a file with an allowed extension and valid size is added successfully.
    it("accepts valid files with allowed extensions and size", function()
      local file_path = test_dir:path_for("valid.lua") -- Use helper for path
      local success, err = processor:add_file(file_path)

      expect(err).to_not.exist("Adding a valid file should not produce an error")
      expect(success).to.be_truthy("Adding a valid file should return true")

      -- Check that file was added to internal tracking
      expect(#processor._files).to.equal(1)
      expect(processor._files[1].path).to.equal(file_path)
    end)

    --- Tests that `:add_file` returns a validation error for disallowed file extensions.
    it("rejects files with invalid extensions", { expect_error = true }, function()
      local file_path = test_dir:path_for("invalid.bin")
      local result, err = test_helper.with_error_capture(function()
        return processor:add_file(file_path)
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("invalid extension")
      expect(err.context.extension).to.equal("bin")
    end)

    --- Tests that `:add_file` returns a validation error for files exceeding the configured size limit.
    it("rejects files that exceed size limit", { expect_error = true }, function()
      local file_path = test_dir:path_for("large.txt")
      local result, err = test_helper.with_error_capture(function()
        return processor:add_file(file_path)
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("too large")
    end)

    --- Tests that `:add_file` returns an IO error if the specified file does not exist.
    it("rejects non-existent files", { expect_error = true }, function()
      local file_path = test_dir:path_for("nonexistent.lua")
      local result, err = test_helper.with_error_capture(function()
        return processor:add_file(file_path)
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.IO)
    end)
  end)

  --- Tests focused on the `:process()` method and its outcomes.
  --- @within examples.comprehensive_testing_example
  describe("File Processing (:process)", function()
    --- Setup hook to create files and add them to the processor before processing tests run.
    before(function()
      -- Create test files
      test_dir:create_file("file1.lua", "-- First file\nlocal x = 10\nreturn x")
      test_dir:create_file("file2.txt", "Line 1\nLine 2\nLine 3\nLine 4")

      -- Add files to processor queue
      processor:add_file(test_dir:path_for("file1.lua"))
      processor:add_file(test_dir:path_for("file2.txt"))
    end)

    --- Tests that `:process()` successfully processes all queued files and returns correct stats.
    it("should process all added files and return stats", function()
      local results, err = processor:process()

      expect(err).to_not.exist("Processing should succeed when files are valid")
      expect(results).to.exist("Processing results should be returned")
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

    --- Tests that the internal file queue is cleared after `:process()` is called.
    it("should clear the file list after processing", function()
      processor:process() -- Run processing first

      -- Check that internal file list is now empty
      expect(#processor._files).to.equal(0)
      -- Trying to process again when the queue is empty should return an error
      local results, err = test_helper.with_error_capture(function()
        return processor:process()
      end)()

      expect(results).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("No files have been added")
    end)
  end)

  --- Tests focused on the `:reset()` method and its effect on state and configuration.
  --- @within examples.comprehensive_testing_example
  describe("Reset Functionality (:reset)", function()
    --- Setup hook to add a file before reset tests run.
    before(function()
      -- Add a file to the processor queue
      test_dir:create_file("reset_test.lua", "-- Test file for reset")
      processor:add_file(test_dir:path_for("reset_test.lua"))
    end)

    --- Tests that `:reset()` clears the internal file queue.
    it("should clear the file list on reset", function()
      -- Verify file was initially added
      expect(#processor._files).to.equal(1)

      -- Reset the processor
      local success = processor:reset()
      expect(success).to.be_truthy()

      -- Check that the internal file list is now empty
      expect(#processor._files).to.equal(0)
    end)

    --- Tests that `:reset()` preserves the existing configuration.
    it("should preserve configuration after reset", function()
      -- Set some custom configuration
      processor:configure({
        max_file_size = 5000,
        allowed_extensions = { "xml" },
      })

      -- Reset the processor
      processor:reset()

      -- Check that the custom configuration is still applied
      expect(processor._config.max_file_size).to.equal(5000)
      expect(processor:get_allowed_extensions()).to.deep_equal({ "xml" })
    end)
  end)
end)

-- NOTE: Run this example using the standard test runner:
-- lua test.lua examples/comprehensive_testing_example.lua
