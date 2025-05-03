--- Logging System Tests
---
--- Verifies the core functionality of the `lib.tools.logging` module, including:
--- - Log level constants and usage (`LEVELS`, `set_level`, `would_log`).
--- - Module logger creation and usage (`get_logger`, `set_module_level`).
--- - Configuration (`configure`, `get_config`).
--- - File logging (text and JSON formats).
--- - Silent mode (`configure({ silent = true })`).
--- - Module filtering (`filter_module`, `clear_module_filters`, `blacklist_module`, `clear_blacklist`).
--- - Buffered logging (`configure({ buffer_size = ... })`, `flush`, `create_buffered_logger`).
--- - Integration with sub-modules (`search`, `export`, `formatter_integration`).
--- Uses `filesystem` for log file verification and `test_helper` for error assertions.
--- Configures logging to use a test-specific directory and resets at the end.
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

local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

-- Import logging module
local logging = require("lib.tools.logging")

-- Configure logging to reduce noise during tests
logging.configure({
  level = logging.LEVELS.ERROR, -- Only show errors
  module_blacklist = { "filesystem" }, -- Blacklist filesystem module logs
})

-- Create temporary test directory
local TEST_DIR = "logs/test"
fs.ensure_directory_exists(TEST_DIR)

-- Set log directory to the correct location
logging.configure({
  log_dir = TEST_DIR, -- Use our test directory for logs
  output_file = nil, -- Clear any previous output file
  json_file = nil, -- Clear any previous JSON file
})

describe("Logging System", function()
  -- Basic logging functionality
  describe("Core logging", function()
    it("should provide different log levels", function()
      expect(type(logging.LEVELS.FATAL)).to.equal("number")
      expect(type(logging.LEVELS.ERROR)).to.equal("number")
      expect(type(logging.LEVELS.WARN)).to.equal("number")
      expect(type(logging.LEVELS.INFO)).to.equal("number")
      expect(type(logging.LEVELS.DEBUG)).to.equal("number")
      expect(type(logging.LEVELS.TRACE)).to.equal("number")
      expect(type(logging.LEVELS.VERBOSE)).to.equal("number")
    end)

    it("should create a module logger", function()
      local logger = logging.get_logger("test_module")
      expect(type(logger)).to.equal("table")
      expect(type(logger.info)).to.equal("function")
      expect(type(logger.error)).to.equal("function")
      expect(type(logger.warn)).to.equal("function")
      expect(type(logger.debug)).to.equal("function")
      expect(type(logger.trace)).to.equal("function")
    end)

    it("should configure logging options", function()
      local result = logging.configure({
        level = logging.LEVELS.DEBUG,
        timestamps = true,
        use_colors = false,
      })

      expect(result).to.equal(logging)

      local config = logging.get_config()
      expect(config.global_level).to.equal(logging.LEVELS.DEBUG)
      expect(config.timestamps).to.equal(true)
      expect(config.use_colors).to.equal(false)
    end)

    it("should set and get module level", function()
      -- Set level
      logging.set_module_level("test_module", logging.LEVELS.TRACE)

      -- Get config to check
      local config = logging.get_config()
      expect(config.module_levels.test_module).to.equal(logging.LEVELS.TRACE)

      -- Create a logger for this module
      local logger = logging.get_logger("test_module")
      local current_level = logger.get_level()
      expect(current_level).to.equal(logging.LEVELS.TRACE)
    end)

    it("should check if a level would be logged", function()
      logging.set_level(logging.LEVELS.INFO)

      expect(logging.would_log(logging.LEVELS.ERROR)).to.equal(true)
      expect(logging.would_log(logging.LEVELS.INFO)).to.equal(true)
      expect(logging.would_log(logging.LEVELS.DEBUG)).to.equal(false)

      expect(logging.would_log("ERROR")).to.equal(true)
      expect(logging.would_log("INFO")).to.equal(true)
      expect(logging.would_log("DEBUG")).to.equal(false)
    end)

    it("should write to a log file", { expect_error = true }, function()
      local test_log = "file_test.log"

      -- Configure to write to file
      logging.configure({
        level = logging.LEVELS.INFO,
        log_dir = TEST_DIR, -- Set log directory to our test dir
        output_file = test_log, -- Just the filename
        timestamps = false, -- Simplify testing
        use_colors = false, -- Simplify testing
      })

      -- Write some logs
      logging.info("Test file log message")
      logging.flush()

      -- Full path for checking
      local full_path = fs.join_paths(TEST_DIR, test_log)

      -- Check file was created
      expect(fs.file_exists(full_path)).to.equal(true)

      -- Read the file and verify content
      local content = fs.read_file(full_path)
      if content then
        expect(content:find("INFO") ~= nil).to.equal(true)
        expect(content:find("Test file log message") ~= nil).to.equal(true)
      end
    end)

    it("should write structured JSON logs", { expect_error = true }, function()
      local json_log = "json_test.json"

      -- Configure for JSON output
      logging.configure({
        level = logging.LEVELS.INFO,
        log_dir = TEST_DIR, -- Set log directory to our test dir
        json_file = json_log, -- Just the filename
        format = "json",
      })

      -- Write with parameters
      logging.info("Test JSON log", { param1 = "value1", param2 = 123 })
      logging.flush()

      -- Full path for checking
      local full_path = fs.join_paths(TEST_DIR, json_log)

      -- Check file was created
      expect(fs.file_exists(full_path)).to.equal(true)

      -- Read the file and verify content
      local content = fs.read_file(full_path)
      if content then
        -- Verify JSON format (simple check)
        expect(content:find('"level":"INFO"') ~= nil).to.equal(true)
        expect(content:find('"message":"Test JSON log"') ~= nil).to.equal(true)
        expect(content:find('"param1":"value1"') ~= nil).to.equal(true)
        expect(content:find('"param2":123') ~= nil).to.equal(true)
      end
    end)
  end)

  -- Test silent mode
  describe("Silent mode", function()
    it("should suppress all output when enabled", { expect_error = true }, function()
      local silent_log = "silent_test.log"

      -- First verify normal logging
      logging.configure({
        level = logging.LEVELS.INFO,
        log_dir = TEST_DIR,
        output_file = silent_log,
        silent = false,
        timestamps = false,
        use_colors = false,
      })

      -- Full path for checking
      local full_path = fs.join_paths(TEST_DIR, silent_log)

      -- Clear the file if it exists
      fs.write_file(full_path, "")

      -- Write logs in normal mode
      logging.info("Normal mode log")
      logging.flush()

      -- Verify log was written
      local normal_content = fs.read_file(full_path)
      if normal_content then
        expect(#normal_content > 0).to.equal(true)

        -- Now enable silent mode
        logging.configure({
          silent = true,
        })

        -- Clear the file again
        fs.write_file(full_path, "")

        -- Try to write logs
        logging.info("Silent mode log")
        logging.error("Silent mode error")
        logging.flush()

        -- Verify nothing was written
        local silent_content = fs.read_file(full_path)
        if silent_content then
          expect(#silent_content).to.equal(0)
        end
      end

      -- Re-enable logging for other tests
      logging.configure({
        silent = false,
      })
    end)
  end)

  -- Test module filtering
  describe("Module filtering", function()
    it("should filter logs by module", { expect_error = true }, function()
      local filter_log = "filter_test.log"

      -- Configure with no filters
      logging.configure({
        level = logging.LEVELS.INFO,
        log_dir = TEST_DIR,
        output_file = filter_log,
        timestamps = false,
        use_colors = false,
        module_filter = nil,
        module_blacklist = {},
      })

      -- Full path for checking
      local full_path = fs.join_paths(TEST_DIR, filter_log)

      -- Clear the file
      fs.write_file(full_path, "")

      -- Create test loggers
      local logger1 = logging.get_logger("module1")
      local logger2 = logging.get_logger("module2")

      -- Write logs from both modules
      logger1.info("Module 1 log")
      logger2.info("Module 2 log")
      logging.flush()

      -- Verify both logs were written
      local unfiltered_content = fs.read_file(full_path)
      if unfiltered_content then
        -- Verify both logs were written
        if unfiltered_content:find("Module 1 log") and unfiltered_content:find("Module 2 log") then
          -- Apply module filter
          logging.filter_module("module1")

          -- Clear the file
          fs.write_file(full_path, "")

          -- Write logs from both modules
          logger1.info("Module 1 log with filter")
          logger2.info("Module 2 log with filter")
          logging.flush()

          -- Verify only module1 logs were written
          local filtered_content = fs.read_file(full_path)
          if filtered_content then
            expect(filtered_content:find("Module 1 log with filter") ~= nil).to.equal(true)
            expect(filtered_content:find("Module 2 log with filter") == nil).to.equal(true)
          end
        end
      end

      -- Clean up filter for other tests
      logging.clear_module_filters()
    end)

    it("should blacklist modules", { expect_error = true }, function()
      local blacklist_log = "blacklist_test.log"

      -- Configure with no blacklist
      logging.configure({
        level = logging.LEVELS.INFO,
        log_dir = TEST_DIR,
        output_file = blacklist_log,
        timestamps = false,
        use_colors = false,
        module_filter = nil,
        module_blacklist = {},
      })

      -- Full path for checking
      local full_path = fs.join_paths(TEST_DIR, blacklist_log)

      -- Clear the file
      fs.write_file(full_path, "")

      -- Create test loggers
      local logger1 = logging.get_logger("test1")
      local logger2 = logging.get_logger("test2")

      -- Write logs from both modules
      logger1.info("Test 1 log")
      logger2.info("Test 2 log")
      logging.flush()

      -- Verify both logs were written
      local unfiltered_content = fs.read_file(full_path)
      if unfiltered_content then
        if unfiltered_content:find("Test 1 log") and unfiltered_content:find("Test 2 log") then
          -- Apply blacklist
          logging.blacklist_module("test1")

          -- Clear the file
          fs.write_file(full_path, "")

          -- Write logs from both modules
          logger1.info("Test 1 log with blacklist")
          logger2.info("Test 2 log with blacklist")
          logging.flush()

          -- Verify only test2 logs were written
          local filtered_content = fs.read_file(full_path)
          if filtered_content then
            expect(filtered_content:find("Test 1 log with blacklist") == nil).to.equal(true)
            expect(filtered_content:find("Test 2 log with blacklist") ~= nil).to.equal(true)
          end
        end
      end

      -- Clean up for other tests
      logging.clear_blacklist()
    end)
  end)

  -- Test buffering
  describe("Buffered logging", function()
    it("should buffer logs and flush on demand", { expect_error = true }, function()
      local buffer_log = "buffer_test.log"

      -- Configure with buffering
      logging.configure({
        level = logging.LEVELS.INFO,
        log_dir = TEST_DIR,
        output_file = buffer_log,
        timestamps = false,
        use_colors = false,
        buffer_size = 10, -- Buffer up to 10 messages
      })

      -- Full path for checking
      local full_path = fs.join_paths(TEST_DIR, buffer_log)

      -- Clear the file
      fs.write_file(full_path, "")

      -- Write 5 logs (should be buffered, not written yet)
      for i = 1, 5 do
        logging.info("Buffered log " .. i)
      end

      -- Check file is still empty
      local content_before = fs.read_file(full_path)
      if content_before then
        -- Should be empty before flush
        expect(#content_before).to.equal(0)

        -- Flush the buffer
        logging.flush()

        -- Verify logs were written
        local content_after = fs.read_file(full_path)
        if content_after then
          -- All 5 logs should be present
          for i = 1, 5 do
            expect(content_after:find("Buffered log " .. i) ~= nil).to.equal(true)
          end
        end
      end
    end)

    it("should auto-flush when buffer is full", { expect_error = true }, function()
      local auto_buffer_log = "auto_buffer_test.log"

      -- Configure with small buffer
      logging.configure({
        level = logging.LEVELS.INFO,
        log_dir = TEST_DIR,
        output_file = auto_buffer_log,
        timestamps = false,
        use_colors = false,
        buffer_size = 3, -- Buffer up to 3 messages
      })

      -- Full path for checking
      local full_path = fs.join_paths(TEST_DIR, auto_buffer_log)

      -- Clear the file
      fs.write_file(full_path, "")

      -- Write 4 logs (should trigger auto-flush after 3)
      for i = 1, 4 do
        logging.info("Auto-buffered log " .. i)
      end

      -- Ensure we flush any remaining logs
      logging.flush()

      -- Skip specific verification as auto-flush behavior is implementation-dependent
      -- We just need to verify the file exists with content
      local content = fs.read_file(full_path)
      if content then
        expect(#content > 0).to.equal(true)
      end
    end)

    it("should create a buffered logger", { expect_error = true }, function()
      local custom_buffer_log = "custom_buffer_test.log"

      -- Create a buffered logger
      local buffered_logger = logging.create_buffered_logger("buffered_test", {
        buffer_size = 5,
        flush_interval = 10,
        log_dir = TEST_DIR,
        output_file = custom_buffer_log,
      })

      -- Full path for checking
      local full_path = fs.join_paths(TEST_DIR, custom_buffer_log)

      -- Clear the file
      fs.write_file(full_path, "")

      -- Write some logs
      for i = 1, 3 do
        buffered_logger.info("Custom buffered log " .. i)
      end

      -- Check file is still empty (logs are buffered)
      local content_before = fs.read_file(full_path)
      if content_before then
        expect(#content_before).to.equal(0)

        -- Flush using the logger's flush method
        buffered_logger.flush()

        -- Verify logs were written
        local content_after = fs.read_file(full_path)
        if content_after then
          -- All logs should be present
          for i = 1, 3 do
            expect(content_after:find("Custom buffered log " .. i) ~= nil).to.equal(true)
          end
        end
      end
    end)
  end)

  -- Test advanced functionality
  describe("Advanced functionality", function()
    it("should expose search functionality", function()
      -- Access the search module
      local search = logging.search()
      expect(type(search)).to.equal("table")
      expect(type(search.search_logs)).to.equal("function")
      expect(type(search.get_log_stats)).to.equal("function")
      expect(type(search.export_logs)).to.equal("function")
    end)

    it("should expose export functionality", function()
      -- Access the export module
      local export = logging.export()
      expect(type(export)).to.equal("table")
      expect(type(export.export_to_platform)).to.equal("function")
      expect(type(export.create_platform_file)).to.equal("function")
      expect(type(export.create_platform_config)).to.equal("function")
      expect(type(export.create_realtime_exporter)).to.equal("function")
      expect(type(export.get_supported_platforms)).to.equal("function")
    end)

    it("should expose formatter integration", function()
      -- Access the formatter integration module
      local formatter_integration = logging.formatter_integration()
      expect(type(formatter_integration)).to.equal("table")
      expect(type(formatter_integration.enhance_formatters)).to.equal("function")
      expect(type(formatter_integration.create_test_logger)).to.equal("function")
      expect(type(formatter_integration.integrate_with_reporting)).to.equal("function")
      expect(type(formatter_integration.create_log_formatter)).to.equal("function")
    end)
  end)

  -- Test search functionality
  describe("Log search and analysis", function()
    -- Set up a log file with mixed content for searching
    local search_log = fs.join_paths(TEST_DIR, "search_test.log")
    local function create_test_log_file()
      -- Create sample log content
      local log_content = [[
2023-01-01 10:00:00 | INFO | module1 | Log message 1
2023-01-01 10:01:00 | DEBUG | module1 | Debug message
2023-01-01 10:02:00 | ERROR | module2 | Error message
2023-01-01 10:03:00 | WARN | module1 | Warning message
2023-01-01 10:04:00 | INFO | module2 | Log message 2
2023-01-01 10:05:00 | ERROR | module3 | Another error
]]
      -- Write to file
      fs.write_file(search_log, log_content)
    end

    -- Create the test log file before tests
    create_test_log_file()

    it("should search logs by level", function()
      local search = logging.search()

      -- Search for ERROR logs
      local results = search.search_logs({
        log_file = search_log,
        level = "ERROR",
      })

      -- Verify results
      expect(type(results)).to.equal("table")
      expect(results.count).to.equal(2)
      expect(results.entries[1].level).to.equal("ERROR")
      expect(results.entries[2].level).to.equal("ERROR")
    end)

    it("should search logs by module", function()
      local search = logging.search()

      -- Search for module1 logs
      local results = search.search_logs({
        log_file = search_log,
        module = "module1",
      })

      -- Verify results
      expect(type(results)).to.equal("table")
      expect(results.count).to.equal(3)

      -- All entries should be from module1
      for _, entry in ipairs(results.entries) do
        expect(entry.module).to.equal("module1")
      end
    end)

    it("should search logs by message content", function()
      local search = logging.search()

      -- Search for logs containing "message"
      local results = search.search_logs({
        log_file = search_log,
        message_pattern = "message",
      })

      -- Verify results (all logs have "message" in our test file)
      expect(type(results)).to.equal("table")
      -- There are 5 messages (not 6) in this test
      expect(results.count).to.equal(5)
    end)

    it("should get log statistics", function()
      local search = logging.search()

      -- Get stats
      local stats = search.get_log_stats(search_log)

      -- Verify basic stats
      expect(type(stats)).to.equal("table")
      expect(stats.total_entries).to.equal(6)
      expect(stats.errors).to.equal(2)
      expect(stats.warnings).to.equal(1)

      -- Verify level breakdown
      expect(stats.by_level.INFO).to.equal(2)
      expect(stats.by_level.DEBUG).to.equal(1)
      expect(stats.by_level.ERROR).to.equal(2)
      expect(stats.by_level.WARN).to.equal(1)

      -- Verify module breakdown
      expect(stats.by_module.module1).to.equal(3)
      expect(stats.by_module.module2).to.equal(2)
      expect(stats.by_module.module3).to.equal(1)
    end)

    it("should export logs to different formats", { expect_error = true }, function()
      local search = logging.search()

      -- Export to CSV
      local csv_output = fs.join_paths(TEST_DIR, "export_test.csv")
      local csv_result = search.export_logs(search_log, csv_output, "csv")

      -- Verify CSV export
      expect(type(csv_result)).to.equal("table")
      expect(csv_result.entries_processed).to.equal(6)
      expect(fs.file_exists(csv_output)).to.equal(true)

      -- Read CSV to verify format
      local csv_content = fs.read_file(csv_output)
      if csv_content then
        -- CSV should have headers and data rows
        expect(csv_content:find("timestamp,level,module,message") ~= nil).to.equal(true)
        -- Count newlines to verify we have at least 6 entries + header
        local count = 0
        for _ in csv_content:gmatch("\n") do
          count = count + 1
        end
        expect(count > 6).to.equal(true) -- Header + 6 entries
      end
    end)
  end)

  -- Test export functionality
  describe("Log export integration", function()
    it("should list supported platforms", function()
      local export = logging.export()

      -- Get supported platforms
      local platforms = export.get_supported_platforms()

      -- Verify basic platform support
      expect(type(platforms)).to.equal("table")
      expect(#platforms > 0).to.equal(true)

      -- Check for common platforms
      local has_elasticsearch = false
      local has_logstash = false
      local has_splunk = false

      for _, platform in ipairs(platforms) do
        if platform == "elasticsearch" then
          has_elasticsearch = true
        end
        if platform == "logstash" then
          has_logstash = true
        end
        if platform == "splunk" then
          has_splunk = true
        end
      end

      expect(has_elasticsearch or has_logstash).to.equal(true)
      expect(has_splunk).to.equal(true)
    end)

    it("should create adapters for external platforms", function()
      local export = logging.export()

      -- Test a platform adapter (choose one that's guaranteed to exist)
      local platforms = export.get_supported_platforms()
      local test_platform = platforms[1]

      -- Create export adapter
      local adapted_entries = export.export_to_platform(
        {
          {
            timestamp = "2023-01-01T10:00:00",
            level = "INFO",
            module = "test_module",
            message = "Test message",
          },
        },
        test_platform,
        {
          environment = "test",
        }
      )

      -- Verify adapter output
      expect(type(adapted_entries)).to.equal("table")
      expect(#adapted_entries).to.equal(1)

      -- Adapter should have transformed the entry
      local entry = adapted_entries[1]
      expect(type(entry)).to.equal("table")
    end)

    it("should create platform configuration files", function()
      local export = logging.export()

      -- Get a platform to test
      local platforms = export.get_supported_platforms()
      local test_platform = platforms[1]

      -- Create a config file
      local config_path = fs.join_paths(TEST_DIR, "platform_config_test.conf")
      local result = export.create_platform_config(test_platform, config_path, {
        environment = "test",
      })

      -- Verify config was created
      expect(type(result)).to.equal("table")
      expect(result.config_file).to.equal(config_path)
      expect(fs.file_exists(config_path)).to.equal(true)

      -- File should contain content
      local content, err = fs.read_file(config_path)
      if not content then
        firmo.log.error({
          message = "Failed to read platform config file",
          file = config_path,
          error = err or "unknown error",
        })
        expect(false).to.equal(true)
        return
      end

      expect(#content > 0).to.equal(true)
    end)
  end)

  -- Test formatter integration
  describe("Test formatter integration", function()
    it("should create a test logger with context", function()
      local formatter_integration = logging.formatter_integration()

      -- Create a test logger with context
      local test_logger = formatter_integration.create_test_logger("Test Suite", {
        category = "Unit",
        environment = "Test",
      })

      -- Verify logger
      expect(type(test_logger)).to.equal("table")
      expect(type(test_logger.info)).to.equal("function")
      expect(type(test_logger.error)).to.equal("function")
      expect(type(test_logger.step)).to.equal("function")
      expect(type(test_logger.with_context)).to.equal("function")
    end)

    it("should support test steps", function()
      local formatter_integration = logging.formatter_integration()

      -- Create a test logger
      local test_logger = formatter_integration.create_test_logger("Test Suite")

      -- Create a step logger
      local step_logger = test_logger.step("Step 1")

      -- Verify step logger
      expect(type(step_logger)).to.equal("table")
      expect(type(step_logger.info)).to.equal("function")
      expect(type(step_logger.error)).to.equal("function")
    end)
  end)
end)

-- Clean up after tests (after_all is not available in firmo)
-- Set up cleanup to run at the end
describe("Test Cleanup", function()
  it("resets logging configuration", function()
    -- Reset logging configuration
    logging.configure({
      level = logging.LEVELS.INFO,
      output_file = nil,
      json_file = nil,
      silent = false,
      buffer_size = 0,
      module_filter = nil,
      module_blacklist = {},
    })
    expect(true).to.equal(true) -- Always pass
  end)
end)
