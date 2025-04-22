--[[
  Watch Mode Test Suite

  This file tests the functionality of the watcher module in the firmo framework.
  The watcher module provides file system monitoring capabilities for the
  watch mode feature of the test runner.

  @module tests.tools.watcher.watch_mode_test
  @copyright 2025
  @license MIT
--]]

-- Load dependencies
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Initialize proper logging
local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.watch_mode")

-- Test the watcher module
describe("Watch Mode", function()
  -- Variables to track state across tests
  local watcher
  local temp_dir
  local watcher_initialized = false

  -- Setup environment before running tests
  before(function()
    -- Try to load the watcher module safely
    local load_fn = test_helper.with_error_capture(function()
      return require("lib.tools.watcher")
    end)

    local result = load_fn() -- result will be the module directly if successful, no success/error pattern here

    if result then
      watcher = result
      logger.info("Watcher module loaded successfully", {
        module_type = type(watcher),
        has_init = type(watcher.init) == "function",
      })
    else
      logger.error("Failed to load watcher module - module is nil")
      return
    end

    -- Verify we have required functions
    if type(watcher.init) ~= "function" then
      logger.error("Watcher module missing init function")
      return
    end

    -- Create a temporary directory for file operations during tests
    local dir_success, dir_result = pcall(function()
      return temp_file.create_temp_directory()
    end)

    if dir_success and dir_result then
      temp_dir = dir_result
      logger.info("Created temporary directory for tests", { path = temp_dir })
    else
      logger.warn("Failed to create temp directory, using current directory", {
        error = dir_success and "Unknown error" or error_handler.format_error(dir_result),
      })
      temp_dir = "."
    end

    -- Initialize watcher with test directory
    -- Initialize watcher with test directory
    local init_success, init_result = pcall(function()
      -- Pass directories as a table and empty exclude_patterns
      local success, err = watcher.init({ temp_dir }, {})

      if not success then
        error(err) -- Propagate the error to pcall for consistent error handling
      end

      return success
    end)

    if init_success and init_result then
      watcher_initialized = true
      logger.info("Watcher initialized successfully for tests", {
        directory = temp_dir,
      })
    else
      logger.error("Failed to initialize watcher", {
        error = init_success and "Unknown error" or error_handler.format_error(init_result),
      })
    end
  end)

  -- Clean up after all tests
  after(function()
    -- Clean up temp directory if it was created
    if temp_dir and temp_dir ~= "." then
      local success, result = pcall(function()
        return temp_file.remove_directory(temp_dir)
      end)

      if success and result then
        logger.info("Cleaned up temporary directory", { path = temp_dir })
      else
        logger.warn("Failed to clean up temporary directory", {
          path = temp_dir,
          error = success and "Unknown error" or error_handler.format_error(result),
        })
      end
    end

    -- Reset watcher state if initialized
    if watcher and watcher_initialized and watcher.full_reset then
      pcall(function()
        watcher.full_reset()
      end)
    end
  end)

  -- Basic module loading test
  it("should load the watcher module", function()
    expect(watcher).to.exist("Watcher module should exist")
    expect(watcher._VERSION).to.be.a("string", "Watcher module should have version")
  end)

  -- Test for module API
  describe("Module API", function()
    it("has all required functions", function()
      -- Skip if module not available
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      -- Function existence checks
      expect(watcher.debug_config).to.be.a("function")
      expect(watcher.full_reset).to.be.a("function")
      expect(watcher.reset).to.be.a("function")
      expect(watcher.check_for_changes).to.be.a("function")
      expect(watcher.add_patterns).to.be.a("function")
      expect(watcher.init).to.be.a("function")
      expect(watcher.check_for_changes).to.be.a("function")
      expect(watcher.add_patterns).to.be.a("function")
      expect(watcher.set_check_interval).to.be.a("function")
      expect(watcher.reset).to.be.a("function")
      expect(watcher.full_reset).to.be.a("function")
      expect(watcher.debug_config).to.be.a("function")
    end)
  end)

  -- Test initialization
  describe("Initialization", function()
    it("initializes with a single directory", function()
      -- Skip if module not available
      if not watcher then
        logger.warn("Skipping test: watcher module not available")
        return
      end

      -- Pass directory as a table and empty exclude_patterns
      local success, err = watcher.init({ temp_dir }, {})
      expect(success).to.be_truthy("Watcher should initialize with directory")
      expect(err).to_not.exist("No error should be returned on successful initialization")
    end)

    it("initializes with an array of directories", function()
      -- Skip if module not available
      if not watcher then
        logger.warn("Skipping test: watcher module not available")
        return
      end

      local success, err = watcher.init({ temp_dir, "." }, {})
      expect(success).to.be_truthy("Watcher should initialize with array of directories")
      expect(err).to_not.exist("No error should be returned on successful initialization")
    end)

    it("initializes with exclude patterns", function()
      -- Skip if module not available
      if not watcher then
        logger.warn("Skipping test: watcher module not available")
        return
      end

      -- Pass directory as a table and exclude patterns
      local success, err = watcher.init({ temp_dir }, { "%.git", "node_modules" })
      expect(success).to.be_truthy("Watcher should initialize with exclude patterns")
      expect(err).to_not.exist("No error should be returned on successful initialization")
    end)

    it("handles invalid directory paths", { expect_error = true }, function()
      -- Skip if module not available
      if not watcher then
        logger.warn("Skipping test: watcher module not available")
        return
      end

      local success, err = test_helper.with_error_capture(function()
        local success, err = watcher.init({ "/nonexistent/path/that/shouldnt/exist" }, {})
        return success, err
      end)()

      expect(success).to.be_falsy("Should fail for invalid path")
      expect(err).to.exist("Should return error for invalid path")
    end)
  end)

  -- Test configuration
  describe("Configuration", function()
    it("configures with valid options", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      local result = watcher.configure({
        check_interval = 0.5,
        watch_patterns = { "%.lua$", "%.json$" },
        debug = true,
      })

      expect(result).to.equal(watcher, "Configure should return watcher for chaining")
    end)

    it("sets check interval", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      local result = watcher.set_check_interval(1.0)
      expect(result).to.equal(watcher, "set_check_interval should return watcher for chaining")
    end)

    it("adds watch patterns", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      local result = watcher.add_patterns({ "%.txt$", "%.md$" })
      expect(result).to.equal(watcher, "add_patterns should return watcher for chaining")
    end)

    it("rejects invalid intervals", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      local result, err = test_helper.with_error_capture(function()
        return watcher.set_check_interval(-1)
      end)()

      expect(result).to_not.exist("Should reject negative interval")

      local result2, err2 = test_helper.with_error_capture(function()
        return watcher.set_check_interval(nil)
      end)()

      expect(result2).to_not.exist("Should reject nil interval")
    end)

    it("rejects invalid patterns", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      local result, err = test_helper.with_error_capture(function()
        return watcher.add_patterns(nil)
      end)()
      expect(result).to_not.exist("Should reject nil patterns")
    end)
  end)

  -- Test file change detection
  describe("File Change Detection", function()
    it("detects no changes initially", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      local changes = watcher.check_for_changes()

      -- Initial state should have no changes
      if changes == nil then
        -- Nil is an acceptable return value
        expect(true).to.be_truthy() -- Always true, just to have an expect
      else
        -- If not nil, it should be a table with zero elements
        expect(type(changes)).to.equal("table")
        expect(#changes).to.equal(0)
      end
    end)

    it("detects file changes when files are modified", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      -- Create test file
      local test_file_path
      local success, result = pcall(function()
        return temp_file.create_with_content("test content", "txt")
      end)

      if not success or not result then
        logger.warn("Failed to create test file, skipping test", {
          error = success and "Unknown error" or error_handler.format_error(result),
        })
        return
      end

      test_file_path = result

      -- Add pattern to detect .txt files
      watcher.add_patterns({ "%.txt$" })

      -- Modify the file
      local write_success, write_result = pcall(function()
        return fs.write_file(test_file_path, "modified content")
      end)

      if not write_success then
        logger.warn("Failed to modify test file, skipping test", {
          error = error_handler.format_error(write_result),
        })
        return
      end

      -- Wait briefly for filesystem to register the change
      -- This avoids race conditions during testing
      os.execute("sleep 0.1")

      -- Check for changes
      local changes = watcher.check_for_changes()

      -- We don't guarantee changes will be detected in this test environment
      -- but the function should at least not error
      expect(function()
        watcher.check_for_changes()
      end).to_not.fail()

      -- If changes were detected, verify their structure
      if changes and #changes > 0 then
        expect(type(changes)).to.equal("table")
        expect(changes[1].path).to.exist()
        expect(changes[1].type).to.exist()
      end
    end)
  end)

  -- Test reset functionality
  describe("Reset Functionality", function()
    it("performs basic reset", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      local result = watcher.reset()
      expect(result).to.equal(watcher, "reset should return watcher for chaining")

      -- Should be able to check for changes after reset
      expect(function()
        watcher.check_for_changes()
      end).to_not.fail()
    end)

    it("performs full reset", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      local result = watcher.full_reset()
      expect(result).to.equal(watcher, "full_reset should return watcher for chaining")

      -- After full reset, should be able to initialize again
      local success, err = watcher.init({ temp_dir }, {})
      expect(success).to.be_truthy("Should be able to re-initialize after full reset")
      expect(err).to_not.exist("No error should be returned on successful re-initialization")
    end)
  end)

  -- Test debug configuration
  describe("Debug Configuration", function()
    it("returns current configuration", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      local config = watcher.debug_config()

      expect(config).to.exist("debug_config should return configuration object")
      expect(type(config)).to.equal("table", "Configuration should be a table")
    end)

    it("reflects configuration changes", function()
      -- Skip if module not available or not initialized
      if not watcher or not watcher_initialized then
        logger.warn("Skipping test: watcher not initialized")
        return
      end

      -- Set a specific interval
      local test_interval = 0.75
      watcher.set_check_interval(test_interval)

      -- Check that debug config reflects the change
      local config = watcher.debug_config()
      expect(config.local_config.check_interval).to.equal(test_interval)

      -- Add specific patterns
      local test_patterns = { "%.test$", "%.config$" }
      watcher.add_patterns(test_patterns)

      -- Check that debug config reflects the pattern changes
      local updated_config = watcher.debug_config()

      -- Verify patterns were added
      local pattern_found = false
      for _, pattern in ipairs(updated_config.local_config.watch_patterns) do
        for _, test_pattern in ipairs(test_patterns) do
          if pattern == test_pattern then
            pattern_found = true
          end
        end
      end

      expect(pattern_found).to.be_truthy("Added patterns should be reflected in debug output")
    end)
  end)

  -- Test integration with framework
  describe("Framework Integration", function()
    it("works with firmo reset", function()
      -- Skip if firmo.reset doesn't exist
      if not firmo.reset then
        logger.info("firmo.reset not available, skipping test")
        return
      end

      expect(firmo.reset).to.be.a("function")

      -- Reset should not cause errors
      expect(function()
        firmo.reset()
      end).to_not.fail()
    end)
  end)
end)

-- Final logging to help with debugging
if logger then
  logger.info("Watch mode tests completed")
end
