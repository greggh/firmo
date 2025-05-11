---@diagnostic disable: missing-parameter, param-type-mismatch
--- CLI Module Tests
---
--- Tests for the `lib/tools/cli` module's argument parsing and other functionalities.
---
--- @author Firmo Team
--- @test

-- Import the test framework functions
local firmo = require("firmo")
local describe = firmo.describe
local it = firmo.it
local expect = firmo.expect
local before = firmo.before
local after = firmo.after

-- Import test_helper for improved error handling and temp files
local test_helper = require("lib.tools.test_helper")

-- Required modules for testing
local cli = require("lib.tools.cli")
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.cli")

-- Utility functions for mocking and testing

-- Store original modules for restoration
local original_modules = {}

-- Mock a module by replacing it in package.loaded
local function mock_module(module_name, mock_impl)
  if not package.loaded[module_name] then
    return false, "Module " .. module_name .. " not loaded yet"
  end

  original_modules[module_name] = package.loaded[module_name]
  package.loaded[module_name] = mock_impl
  return true
end

-- Restore a previously mocked module
local function restore_module(module_name)
  if original_modules[module_name] then
    package.loaded[module_name] = original_modules[module_name]
    original_modules[module_name] = nil
    return true
  end
  return false, "No original module found for " .. module_name
end

-- Create a mocked firmo instance for testing
local function create_mock_firmo()
  return {
    -- Mock functions
    reset = function() end,
    set_filter = function() end,
    describe = function() end,
    it = function() end,
    expect = function() end,
    -- Tracking for assertions
    reset_called = false,
    filter_set = false,
    filter_pattern = nil,
  }
end

-- Utility to capture print output
local original_print
local captured_output

local function start_capture_output()
  captured_output = {}
  original_print = _G.print
  _G.print = function(...)
    local args = { ... }
    local line = ""
    for i, v in ipairs(args) do
      line = line .. tostring(v)
      if i < #args then
        line = line .. "\t"
      end
    end
    table.insert(captured_output, line)
  end
end

local function stop_capture_output()
  _G.print = original_print
  return captured_output
end

-- Create test results for output format tests
local function create_test_results(success)
  return {
    success = success or true,
    passes = 10,
    errors = success and 0 or 2,
    skipped = 1,
    total = 11, -- passes + errors
    elapsed = 0.123,
    file = "test_file.lua",
  }
end

-- Create a mock runner for tests
local function create_mock_runner(results)
  return {
    configure = function() end,
    run_tests = function()
      return results
    end,
    run_file = function()
      return results
    end,
  }
end

-- Main test suite
describe("CLI Module", function()
  local temp_dir

  -- Setup before each test
  before(function()
    -- Create a temporary directory for test files if needed
    temp_dir = test_helper.create_temp_test_directory()
    logger.debug("Created temporary test directory", { path = temp_dir.path })

    -- Reset central_config to ensure clean state
    central_config.reset()

    -- Ensure any captured output is cleaned up
    if original_print then
      _G.print = original_print
    end
    captured_output = nil
  end)

  -- Cleanup after each test
  after(function()
    -- Restore any mocked modules
    for module_name, _ in pairs(original_modules) do
      restore_module(module_name)
    end

    -- Reset central_config to clean state
    central_config.reset()

    -- Restore print function if we were capturing output
    if original_print then
      _G.print = original_print
    end

    -- temp_dir is automatically cleaned up by test_helper
    logger.debug("Test complete, temporary directory will be cleaned up")
  end)

  -- 1. ARGUMENT PARSING TESTS
  describe("Argument Parsing", function()
    it("parses long-form flags correctly", function()
      -- Test various long-form flags
      local args = { "--coverage", "--verbose", "--quality", "--watch", "--parallel", "--report" }
      local options = cli.parse_args(args)

      expect(options.coverage_enabled).to.equal(true)
      expect(options.verbose).to.equal(true)
      expect(options.quality_enabled).to.equal(true)
      expect(options.watch_mode).to.equal(true)
      expect(options.parallel_execution).to.equal(true)
      expect(options.generate_reports).to.equal(true)
    end)

    it("parses short-form flags correctly", function()
      -- Test various short-form flags
      local args = { "-c", "-v", "-q", "-w", "-p", "-r" }
      local options = cli.parse_args(args)

      expect(options.coverage_enabled).to.equal(true)
      expect(options.verbose).to.equal(true)
      expect(options.quality_enabled).to.equal(true)
      expect(options.watch_mode).to.equal(true)
      expect(options.parallel_execution).to.equal(true)
      expect(options.generate_reports).to.equal(true)
    end)

    it("parses combined short-form flags correctly", function()
      -- Test combined flags like -vcq
      local args = { "-vcqwpr" }
      local options = cli.parse_args(args)

      expect(options.verbose).to.equal(true)
      expect(options.coverage_enabled).to.equal(true)
      expect(options.quality_enabled).to.equal(true)
      expect(options.watch_mode).to.equal(true)
      expect(options.parallel_execution).to.equal(true)
      expect(options.generate_reports).to.equal(true)
    end)

    it("parses options with values using space separator", function()
      -- Test options with values using space separator
      local args =
        { "--pattern", "*_test.lua", "--quality-level", "3", "--threshold", "80", "--report-dir", "./reports" }
      local options = cli.parse_args(args)

      expect(options.file_discovery_pattern).to.equal("*_test.lua")
      expect(options.quality_level).to.equal(3)
      expect(options.coverage_threshold).to.equal(80)
      expect(options.report_output_dir).to.equal("./reports")
    end)

    it("parses options with values using equals separator", function()
      -- Test options with values using equals separator
      local args = { "--pattern=*_spec.lua", "--quality-level=4", "--threshold=85", "--report-dir=./custom-reports" }
      local options = cli.parse_args(args)

      expect(options.file_discovery_pattern).to.equal("*_spec.lua")
      expect(options.quality_level).to.equal(4)
      expect(options.coverage_threshold).to.equal(85)
      expect(options.report_output_dir).to.equal("./custom-reports")
    end)

    it("handles special cases like --help, --version correctly", function()
      -- Test help flag
      local help_args = { "--help" }
      local help_options = cli.parse_args(help_args)
      expect(help_options.show_help).to.equal(true)

      -- Test version flag
      local version_args = { "--version" }
      local version_options = cli.parse_args(version_args)
      expect(version_options.show_version).to.equal(true)
    end)

    it("parses report formats correctly", function()
      -- Test parsing of report formats
      local args = { "--report-formats=html,json,lcov" }
      local options = cli.parse_args(args)

      expect(options.report_file_formats).to.be.a("table")
      expect(#options.report_file_formats).to.equal(3)
      expect(options.report_file_formats[1]).to.equal("html")
      expect(options.report_file_formats[2]).to.equal("json")
      expect(options.report_file_formats[3]).to.equal("lcov")

      -- Test with space separator
      local space_args = { "--report-formats", "html,md" }
      local space_options = cli.parse_args(space_args)

      expect(space_options.report_file_formats).to.be.a("table")
      expect(#space_options.report_file_formats).to.equal(2)
      expect(space_options.report_file_formats[1]).to.equal("html")
      expect(space_options.report_file_formats[2]).to.equal("md")
    end)

    it("parses path arguments correctly", function()
      -- Test positional path arguments
      local test_args = { "--verbose", "tests/", "tests/specific_test.lua" }
      local options = cli.parse_args(test_args)

      -- For basic tests, we can just check that the paths were recorded
      expect(options.verbose).to.equal(true)
      expect(#options.specific_paths_to_run).to.be.greater_than(0)

      -- Test with directory handling mock
      local original_is_directory = fs.is_directory
      fs.is_directory = function(path)
        return path:match("/$") ~= nil -- Simple mock: if path ends with /, it's a directory
      end

      local path_args = { "tests/", "tests/another/", "tests/specific_test.lua" }
      local path_options = cli.parse_args(path_args)

      expect(path_options.base_test_dir).to.equal("tests/")
      expect(#path_options.specific_paths_to_run).to.equal(2)
      expect(path_options.specific_paths_to_run[1]).to.equal("tests/another/")
      expect(path_options.specific_paths_to_run[2]).to.equal("tests/specific_test.lua")

      -- Restore original function
      fs.is_directory = original_is_directory
    end)
  end)

  -- 2. HELP DISPLAY TESTS
  describe("Help Display", function()
    it("can display help information", function()
      -- Capture output
      start_capture_output()

      -- Call show_help
      cli.show_help()

      -- Get captured output
      local output = stop_capture_output()

      -- Check if help was displayed
      expect(#output).to.be.greater_than(0, "Help output should have multiple lines")

      -- Verify some basic content
      local has_usage = false
      local has_options = false

      for _, line in ipairs(output) do
        if line:match("Usage:") then
          has_usage = true
        end
        if line:match("Options:") then
          has_options = true
        end
      end

      expect(has_usage).to.equal(true, "Help should contain usage information")
      expect(has_options).to.equal(true, "Help should contain options section")
    end)

    it("handles the run method with --help flag", function()
      -- Capture output
      start_capture_output()

      -- Create mocks
      local mock_firmo = create_mock_firmo()

      -- Call with --help
      local result = cli.run({ "--help" }, mock_firmo)
      local output = stop_capture_output()

      -- Check that help was displayed and it returned success
      expect(result).to.equal(true)
      expect(#output).to.be.greater_than(5) -- Help should be multi-line

      -- Verify some expected content in the help output
      local has_usage = false
      local has_options = false
      for _, line in ipairs(output) do
        if line:match("Usage: lua firmo.lua") then
          has_usage = true
        end
        if line:match("Options:") then
          has_options = true
        end
      end

      expect(has_usage).to.equal(true, "Help output should contain usage information")
      expect(has_options).to.equal(true, "Help output should contain options section")
    end)
  end)

  -- 3. BASIC INTEGRATION TESTS
  describe("Integration Tests", function()
    -- Integration tests for coverage
    it("initializes coverage with --coverage flag", function()
      -- Mock coverage module
      local coverage_init_called = false
      local coverage_start_called = false
      local coverage_config

      local mock_coverage = {
        init = function(config)
          coverage_init_called = true
          coverage_config = config
          return true
        end,
        start = function()
          coverage_start_called = true
        end,
      }

      -- Replace coverage module temporarily
      mock_module("lib.coverage", mock_coverage)

      -- Create a simple mock runner
      local mock_runner = {
        configure = function() end,
        run_tests = function()
          return { success = true, passes = 2, errors = 0, elapsed = 0.01 }
        end,
      }
      mock_module("lib.core.runner", mock_runner)

      -- Run with coverage flag
      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "--coverage", "--threshold=85" }, mock_firmo)

      -- Verify coverage was initialized and started with correct config
      expect(coverage_init_called).to.equal(true, "Coverage init should be called")
      expect(coverage_start_called).to.equal(true, "Coverage start should be called")
      expect(coverage_config).to.be.a("table")
      expect(coverage_config.enabled).to.equal(true)
      expect(coverage_config.threshold).to.equal(85)
    end)

    -- Integration tests for quality
    it("initializes quality module with --quality flag", function()
      -- Mock quality module
      local quality_init_called = false
      local quality_register_called = false
      local quality_config

      local mock_quality = {
        init = function(config)
          quality_init_called = true
          quality_config = config
          return true
        end,
        register_with_firmo = function(firmo)
          quality_register_called = true
        end,
      }

      -- Create a simple mock runner
      local mock_runner = {
        configure = function() end,
        run_tests = function()
          return { success = true, passes = 2, errors = 0, elapsed = 0.01 }
        end,
      }

      -- Replace modules temporarily
      mock_module("lib.quality", mock_quality)
      mock_module("lib.core.runner", mock_runner)

      -- Run with quality flag
      local mock_firmo = create_mock_firmo()
      mock_firmo.reset = function()
        mock_firmo.reset_called = true
      end

      local result = cli.run({ "--quality", "--quality-level=4" }, mock_firmo)

      -- Verify quality was initialized with correct config
      expect(quality_init_called).to.equal(true, "Quality init should be called")
      expect(quality_register_called).to.equal(true, "Quality register_with_firmo should be called")
      expect(quality_config).to.be.a("table")
      expect(quality_config.enabled).to.equal(true)
      expect(quality_config.level).to.equal(4)
    end)

    it("configures file discovery with --pattern flag", function()
      -- Mock discover module
      local discover_called = false
      local discover_dir
      local discover_pattern

      local mock_discover = {
        discover = function(dir, pattern)
          discover_called = true
          discover_dir = dir
          discover_pattern = pattern
          return { files = { "test1.lua", "test2.lua" } }
        end,
      }

      -- Mock runner module
      local runner_called = false
      local runner_files
      local mock_runner = {
        configure = function() end,
        run_tests = function(files)
          runner_called = true
          runner_files = files
          return { success = true, passes = 2, errors = 0, elapsed = 0.01 }
        end,
      }

      -- Replace modules temporarily
      mock_module("lib.tools.discover", mock_discover)
      mock_module("lib.core.runner", mock_runner)

      -- Run with pattern flag
      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "--pattern=*_spec.lua", "tests/" }, mock_firmo)

      -- Verify correct path and pattern were used
      expect(discover_called).to.equal(true, "Discover should be called")
      expect(discover_dir).to.equal("tests/")
      expect(discover_pattern).to.equal("*_spec.lua")

      -- Verify runner was called with discovered files
      expect(runner_called).to.equal(true, "Runner should be called")
      expect(runner_files).to.be.a("table")
    end)

    it("generates reports with --report flag", function()
      -- Create mock coverage and reporting modules
      local coverage_get_data_called = false
      local coverage_data = { some = "coverage_data" }

      local mock_coverage = {
        init = function()
          return true
        end,
        start = function() end,
        shutdown = function() end,
        get_report_data = function()
          coverage_get_data_called = true
          return coverage_data
        end,
      }

      local reporting_save_called = false
      local reporting_formats
      local reporting_dir
      local mock_reporting = {
        auto_save_reports = function(cov_data, qual_data, _, options)
          reporting_save_called = true
          reporting_formats = options and options.coverage_formats
          reporting_dir = options and options.report_dir
          return true
        end,
      }

      -- Replace modules temporarily
      mock_module("lib.coverage", mock_coverage)
      mock_module("lib.reporting", mock_reporting)

      -- Create a mock runner that returns success
      local mock_runner = {
        configure = function() end,
        run_tests = function()
          return { success = true, passes = 2, errors = 0, elapsed = 0.01 }
        end,
      }
      mock_module("lib.core.runner", mock_runner)

      -- Run with report flag
      local mock_firmo = create_mock_firmo()
      local result = cli.run({
        "--coverage",
        "--report",
        "--report-formats=html,json",
        "--report-dir=./test-reports",
      }, mock_firmo)

      -- Verify reports were generated with correct options
      expect(coverage_get_data_called).to.equal(true, "Coverage get_report_data should be called")
      expect(reporting_save_called).to.equal(true, "Reporting auto_save_reports should be called")
      expect(reporting_formats).to.be.a("table")
      expect(#reporting_formats).to.equal(2)
      expect(reporting_formats[1]).to.equal("html")
      expect(reporting_formats[2]).to.equal("json")
      expect(reporting_dir).to.equal("./test-reports")
    end)

    it("sets up parallel execution with --parallel flag", function()
      -- Mock runner module to check if parallel was enabled
      local runner_configure_called = false
      local runner_config

      local mock_runner = {
        configure = function(config)
          runner_configure_called = true
          runner_config = config
          return true
        end,
        run_tests = function()
          return { success = true, passes = 2, errors = 0, elapsed = 0.01 }
        end,
      }

      -- Replace runner module temporarily
      mock_module("lib.core.runner", mock_runner)

      -- Run with parallel flag
      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "--parallel", "tests/" }, mock_firmo)

      -- Verify runner was configured with parallel flag
      expect(runner_configure_called).to.equal(true, "Runner configure should be called")
      expect(runner_config).to.be.a("table")
      expect(runner_config.parallel).to.equal(true, "Parallel execution should be enabled in runner config")
    end)

    it("sets up watch mode with --watch flag", function()
      -- Ensure we're working with a fresh environment
      for module_name, _ in pairs(original_modules) do
        restore_module(module_name)
      end

      -- Define tracking variables in the proper scope
      local watcher_configure_called = false
      local watcher_watch_called = false
      local watcher_dirs = nil
      local watch_callback = nil
      local runner_discovered_called = false
      local runner_file_called = false

      -- IMPORTANT: Create and setup mock modules FIRST
      -- First declare an empty table
      local mock_runner = {}

      -- Add state fields
      mock_runner.last_config = nil
      mock_runner.last_dir = nil
      mock_runner.last_pattern = nil
      mock_runner.last_file = nil
      mock_runner.last_options = nil
      mock_runner.last_firmo_instance = nil

      -- Add methods after table is created
      mock_runner.configure = function(config)
        mock_runner.last_config = config
        return true
      end

      mock_runner.run_tests = function(files, firmo_instance, options)
        mock_runner.last_files = files
        mock_runner.last_options = options
        mock_runner.last_firmo_instance = firmo_instance
        
        -- Call run_file for each file in the list to match CLI's behavior in watch mode
        if files and #files > 0 then
          for _, file in ipairs(files) do
            mock_runner.run_file(file, firmo_instance, options)
          end
        end
        
        return { success = true, passes = 2, errors = 0, elapsed = 0.01 }
      end

      mock_runner.run_discovered = function(dir, pattern, firmo_instance, options)
        runner_discovered_called = true
        mock_runner.last_dir = dir
        mock_runner.last_pattern = pattern
        mock_runner.last_firmo_instance = firmo_instance
        
        -- Simulate discovering and running a test file from the directory
        -- This matches CLI's behavior by calling run_file for discovered files
        if dir then
          -- Use "test_file.lua" directly instead of constructing path with directory
          mock_runner.run_file("test_file.lua", firmo_instance, options)
        end
        
        return { success = true, passes = 2, errors = 0, elapsed = 0.01 }
      end

      mock_runner.run_file = function(path, firmo_instance, options)
        runner_file_called = true
        mock_runner.last_file = path
        mock_runner.last_options = options
        mock_runner.last_firmo_instance = firmo_instance
        return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
      end

      local mock_watcher = {
        configure = function(config)
          watcher_configure_called = true
          watcher_dirs = config and config.dirs
          return true
        end,

        watch = function(callback)
          watcher_watch_called = true
          watch_callback = callback
          return true
        end,
      }

      -- Mock the modules BEFORE any other operations
      local runner_mock_success = mock_module("lib.core.runner", mock_runner)
      expect(runner_mock_success).to.equal(true, "Failed to mock runner module")

      local watcher_mock_success = mock_module("lib.tools.watcher", mock_watcher)
      expect(watcher_mock_success).to.equal(true, "Failed to mock watcher module")

      -- Get the private load_modules function
      local load_modules_found = false
      local i = 1
      while true do
        local name, val = debug.getupvalue(cli.run, i)
        if not name then
          break
        end
        if name == "load_modules" and type(val) == "function" then
          cli.load_modules = val
          load_modules_found = true
          break
        end
        i = i + 1
      end
      expect(load_modules_found).to.equal(true, "Could not find load_modules in CLI module upvalues")

      -- Reload modules to ensure CLI module uses our mocks
      cli.load_modules()

      -- Create our mock firmo instance
      local mock_firmo = create_mock_firmo()

      -- Run with watch flag
      local status, err = pcall(function()
        return cli.run({ "--watch", "tests/" }, mock_firmo)
      end)

      if not status then
        print("Error during cli.run:", err) -- Add debug output
      end

      expect(status).to.equal(true, "cli.run with watch flag should not throw an error")
      expect(watcher_configure_called).to.equal(true, "Watcher configure should be called")
      expect(watcher_watch_called).to.equal(true, "Watcher watch should be called")
      expect(watcher_dirs).to.be.a("table", "Watcher dirs should be configured")
      expect(watcher_dirs[1]).to.equal("./tests", "Watcher should monitor the tests directory")

      -- Verify watcher was configured and started
      expect(watcher_configure_called).to.equal(true, "Watcher configure should be called")
      expect(watcher_watch_called).to.equal(true, "Watcher watch should be called")
      expect(watcher_dirs).to.be.a("table", "Watcher dirs should be configured")
      expect(watcher_dirs[1]).to.equal("./tests", "Watcher should monitor the tests directory")
      expect(watch_callback).to.be.a("function", "Watch callback should be registered")

      -- Now manually call the watcher callback to simulate file changes
      expect(watch_callback).to.exist("Watch callback should exist")

      -- Simulate a single file change
      local file_callback_status, file_callback_error = pcall(function()
        watch_callback({ "test_file.lua" })
      end)
      expect(file_callback_status).to.equal(
        true,
        "File change callback should not throw errors: " .. tostring(file_callback_error or "")
      )

      -- Verify that the runner function was called by watcher callback
      expect(runner_file_called).to.equal(true, "run_file should be called when a specific file changes")
      expect(mock_runner.last_file).to.equal("test_file.lua", "run_file should be called with the changed file")

      -- Simulate directory change
      local dir_callback_status, dir_callback_error = pcall(function()
        watch_callback({ "tests/" })
      end)
      expect(dir_callback_status).to.equal(
        true,
        "Directory change callback should not throw errors: " .. tostring(dir_callback_error or "")
      )

      -- Verify directory change handling
      expect(runner_discovered_called).to.equal(true, "run_discovered should be called when a directory changes")
      expect(mock_runner.last_dir).to.equal("./tests", "run_discovered should be called with the right directory")
      expect(mock_runner.last_pattern).to.equal("*_test.lua", "run_discovered should use the default test pattern")

      -- Clean up
      restore_module("lib.core.runner")
      restore_module("lib.tools.watcher")
    end)

    it("outputs JSON with --json flag", function()
      -- Mock relevant modules
      local mock_runner = {
        configure = function() end,
        run_tests = function()
          return {
            success = true,
            passes = 2,
            errors = 0,
            elapsed = 0.01,
            files = { "test1.lua", "test2.lua" },
          }
        end,
      }

      local json_encode_called = false
      local json_input
      local mock_json = {
        encode = function(data)
          json_encode_called = true
          json_input = data
          return '{"success":true,"passes":2,"errors":0}'
        end,
      }

      -- Replace modules temporarily
      mock_module("lib.core.runner", mock_runner)
      mock_module("lib.tools.json", mock_json)

      -- Capture output
      start_capture_output()

      -- Run with json flag
      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "--json", "tests/" }, mock_firmo)

      -- Check output
      local output = stop_capture_output()

      -- Verify JSON was generated
      expect(json_encode_called).to.equal(true, "JSON encode should be called")
      expect(json_input).to.be.a("table")
      expect(json_input.success).to.equal(true)

      -- Verify JSON delimiter markers were printed
      local begin_marker_found = false
      local json_output_found = false
      local end_marker_found = false

      for _, line in ipairs(output) do
        if line == "RESULTS_JSON_BEGIN" then
          begin_marker_found = true
        elseif line:match('{"success":true') then
          json_output_found = true
        elseif line == "RESULTS_JSON_END" then
          end_marker_found = true
        end
      end

      expect(begin_marker_found).to.equal(true, "JSON begin marker should be printed")
      expect(json_output_found).to.equal(true, "JSON data should be printed")
      expect(end_marker_found).to.equal(true, "JSON end marker should be printed")
    end)

    it("loads configuration from --config file", function()
      -- Create a temporary config file
      local config_content = [[
      return {
        coverage = {
          threshold = 92,
          include = { "lib/**/*.lua" }
        },
        quality = {
          level = 4
        },
        reporting = {
          report_dir = "./custom-reports"
        }
      }
      ]]

      local config_file_path = temp_dir:create_file("test_config.lua", config_content)

      -- Capture central_config.set calls
      local central_config_load_called = false
      local original_load_from_file = central_config.load_from_file
      central_config.load_from_file = function(path)
        central_config_load_called = true
        return original_load_from_file(path)
      end

      -- Mock necessary modules for execution
      local mock_runner = {
        configure = function() end,
        run_tests = function()
          return { success = true, passes = 2, errors = 0, elapsed = 0.01 }
        end,
      }
      mock_module("lib.core.runner", mock_runner)

      -- Run with config flag
      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "--config=" .. config_file_path }, mock_firmo)

      -- Verify config was loaded
      expect(central_config_load_called).to.equal(true, "central_config.load_from_file should be called")

      -- Verify values from config file were applied
      local coverage_config = central_config.get("coverage")
      expect(coverage_config).to.be.a("table")
      expect(coverage_config.threshold).to.equal(92)

      local quality_config = central_config.get("quality")
      expect(quality_config).to.be.a("table")
      expect(quality_config.level).to.equal(4)

      local reporting_config = central_config.get("reporting")
      expect(reporting_config).to.be.a("table")
      expect(reporting_config.report_dir).to.equal("./custom-reports")

      -- Restore original function
      central_config.load_from_file = original_load_from_file
    end)

    it("creates default config with --create-config flag", function()
      -- Mock central_config.create_default_config_file
      local create_config_called = false
      local create_config_path

      local original_create_default_config = central_config.create_default_config_file
      central_config.create_default_config_file = function(path)
        create_config_called = true
        create_config_path = path
        return true
      end

      -- Capture output
      start_capture_output()

      -- Run with create-config flag
      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "--create-config" }, mock_firmo)

      -- Check output
      local output = stop_capture_output()

      -- Verify config creation was triggered
      expect(create_config_called).to.equal(true, "create_default_config_file should be called")
      expect(create_config_path).to.equal(".firmo-config.lua")
      expect(result).to.equal(true, "Command should succeed")

      -- Verify success message was printed
      local success_message_found = false
      for _, line in ipairs(output) do
        if line:match("Created .firmo%-config%.lua") then
          success_message_found = true
          break
        end
      end
      expect(success_message_found).to.equal(true, "Success message should be printed")

      -- Restore original function
      central_config.create_default_config_file = original_create_default_config
    end)
  end)

  -- 4. Error Handling Tests
  describe("Error Handling", function()
    it("reports parsing errors for invalid arguments", function()
      -- Create arguments with invalid flag
      local args = { "--invalid-flag", "--another-bad-one=value" }
      local options = cli.parse_args(args)

      -- Check for parsing errors
      expect(options.parse_errors).to.be.a("table")
      expect(#options.parse_errors).to.be.greater_than(0)

      -- Verify the run function handles parsing errors
      start_capture_output()

      local mock_firmo = create_mock_firmo()
      local result = cli.run(args, mock_firmo)

      local output = stop_capture_output()

      -- Should return false to indicate error
      expect(result).to.equal(false)

      -- Should output error message
      local error_message_found = false
      for _, line in ipairs(output) do
        if line:match("CLI Argument Parsing Error") or line:match("Unknown option") then
          error_message_found = true
          break
        end
      end
      expect(error_message_found).to.equal(true, "Error message should be displayed")
    end)

    it("handles missing required modules gracefully", { expect_error = true }, function()
      -- Store original try_require
      local original_try_require = cli.try_require

      -- Create a mock function that fails for the runner module
      local function mock_try_require(module_name)
        if module_name == "lib.core.runner" then
          return nil, "Mock module load failure"
        end
        return original_try_require(module_name)
      end

      -- Wrap the entire test in a pcall to ensure cleanup
      return test_helper.with_error_capture(function()
        -- Set up capture
        start_capture_output()

        -- Replace try_require with mock
        cli.try_require = mock_try_require

        -- Run test
        local result = cli.run({ "tests/" }, create_mock_firmo())

        -- Get output
        local output = stop_capture_output()

        -- Verify results
        expect(result).to.equal(false, "Command should fail")

        -- Check error message
        local error_found = false
        for _, line in ipairs(output) do
          if line:match("Runner module not loaded") then
            error_found = true
            break
          end
        end
        expect(error_found).to.equal(true, "Error message about missing module should be displayed")

        -- Restore original function
        cli.try_require = original_try_require
      end)
    end)

    it("handles config file errors gracefully", function()
      -- Create an invalid config file
      local invalid_config_content = [[
      return {
        -- Invalid Lua syntax - missing closing brace
        coverage = {
          threshold = 90,
      ]]

      local invalid_config_path = temp_dir:create_file("invalid_config.lua", invalid_config_content)

      -- Run with invalid config file
      start_capture_output()

      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "--config=" .. invalid_config_path }, mock_firmo)

      local output = stop_capture_output()

      -- Should continue execution but report error
      expect(result).to.be_falsy("Command should fail with invalid config")

      -- Should output error message
      local error_message_found = false
      for _, line in ipairs(output) do
        if line:match("Failed to load config file") or line:match("Error loading config") then
          error_message_found = true
          break
        end
      end
      expect(error_message_found).to.equal(true, "Error message about invalid config should be displayed")
    end)

    it("handles non-existent config file gracefully", function()
      -- Run with non-existent config file
      start_capture_output()

      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "--config=./nonexistent_config.lua" }, mock_firmo)

      local output = stop_capture_output()

      -- Should continue execution but report error
      expect(result).to.be_falsy("Command should fail with non-existent config")

      -- Should output error message
      local error_message_found = false
      for _, line in ipairs(output) do
        if line:match("Specified config file not found") or line:match("Config file not found") then
          error_message_found = true
          break
        end
      end
      expect(error_message_found).to.equal(true, "Error message about missing config file should be displayed")
    end)

    it("handles file path validation errors", function()
      -- Mock filesystem to simulate directory access problems
      local original_is_directory = fs.is_directory
      fs.is_directory = function(path)
        -- Simulate failure for a specific path
        if path == "inaccessible/" then
          error("Permission denied")
        end
        -- Fallback to simple check for paths ending with /
        return path:match("/$") ~= nil
      end

      -- Mock discover module to throw error for invalid directory
      local mock_discover = {
        discover = function(dir, pattern)
          if dir == "nonexistent/" then
            return nil, "Directory not found"
          end
          return { files = { "test1.lua" } }
        end,
      }
      mock_module("lib.tools.discover", mock_discover)

      -- Run with non-existent directory
      start_capture_output()

      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "nonexistent/" }, mock_firmo)

      local output = stop_capture_output()

      -- Should return false to indicate failure
      expect(result).to.equal(false, "Command should fail with invalid directory")

      -- Should output error message
      local error_message_found = false
      for _, line in ipairs(output) do
        if line:match("Discovery failed") or line:match("Directory not found") then
          error_message_found = true
          break
        end
      end
      expect(error_message_found).to.equal(true, "Error message about invalid directory should be displayed")

      -- Restore original function
      fs.is_directory = original_is_directory
    end)

    it("handles report generation errors", function()
      -- Create a mock coverage and reporting modules
      local mock_coverage = {
        init = function()
          return true
        end,
        start = function() end,
        shutdown = function() end,
        get_report_data = function()
          return { some = "coverage_data" }
        end,
      }

      -- Reporting module that throws error
      local mock_reporting = {
        auto_save_reports = function()
          -- Only throw the error - return is unreachable and Permission denied is the key phrase for test to find
          error("Permission denied while writing to report directory")
        end,
      }

      -- Basic runner mock
      local mock_runner = {
        configure = function() end,
        run_tests = function()
          return { success = true, passes = 2, errors = 0, elapsed = 0.01 }
        end,
      }

      -- Replace modules
      mock_module("lib.coverage", mock_coverage)
      mock_module("lib.reporting", mock_reporting)
      mock_module("lib.core.runner", mock_runner)

      -- Run with report and capture output
      start_capture_output()

      local mock_firmo = create_mock_firmo()
      local result

      -- Use error_capture since we expect an error
      result, _ = test_helper.with_error_capture(function()
        return cli.run({ "--coverage", "--report", "--report-formats=html" }, mock_firmo)
      end)()

      local output = stop_capture_output()

      -- Command should succeed (tests ran) but report should fail
      expect(result).to.be_falsy("Overall command should fail if reporting fails")

      -- Check for error message about reporting
      local error_message_found = false
      for _, line in ipairs(output) do
        if line:match("auto_save_reports failed") or line:match("Permission denied") then
          error_message_found = true
          break
        end
      end

      expect(error_message_found).to.equal(true, "Error message about reporting failure should be displayed")
    end)
  end)

  -- 5. CLI Output Format Tests
  describe("Output Formats", function()
    -- Create a standard test result for all format tests
    local function create_test_results(success)
      return {
        success = success or true,
        passes = 10,
        errors = success and 0 or 2,
        skipped = 1,
        total = 11, -- passes + errors
        elapsed = 0.123,
        file = "test_file.lua",
      }
    end

    -- Utility to create a mock runner
    local function create_mock_runner(results)
      return {
        configure = function() end,
        run_tests = function()
          return results
        end,
        run_file = function()
          return results
        end,
      }
    end

    it("formats output correctly with default format", function()
      -- Create mock test results with specific values
      local test_results = create_test_results(true) -- Creates results with 10 passes and 0.123 elapsed time
      logger.debug("Created mock test results", {
        passes = test_results.passes,
        elapsed = test_results.elapsed,
        success = test_results.success,
      })

      local mock_runner = create_mock_runner(test_results)
      -- Wrap run_tests to add logging
      local original_run_tests = mock_runner.run_tests
      mock_runner.run_tests = function(...)
        logger.debug("Mock runner.run_tests called")
        local results = original_run_tests(...)
        logger.debug("Mock runner returned results", {
          passes = results.passes,
          elapsed = results.elapsed,
        })
        return results
      end

      -- Install the mock runner to be used by CLI
      mock_module("lib.core.runner", mock_runner)
      logger.debug("Installed mock runner")

      start_capture_output()

      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "tests/" }, mock_firmo)

      local output = stop_capture_output()

      -- Debug: Print all output lines for diagnosis
      logger.debug("Captured output lines count: " .. #output)
      for i, line in ipairs(output) do
        logger.debug(string.format("Line %d: %q", i, line))
      end

      -- Default format should be detailed with clear sections
      expect(result).to.equal(true)

      -- Check for expected elements in default output
      local found_summary = false
      local found_passes = false
      local found_time = false

      for _, line in ipairs(output) do
        -- Handle ANSI color codes and timestamps in the output
        -- Look for key elements regardless of formatting
        if line:match("Test Execution Summary") then
          found_summary = true
          logger.debug("Found summary line: " .. line)
        end
        -- Simplified pattern to find "Passes: 10" within formatted output
        if line:match("Passes:") and line:match("10") then
          found_passes = true
          logger.debug("Found passes line: " .. line)
        end
        -- Simplified pattern to find "Total Time: 0.123" within formatted output
        if line:match("Total Time:") and line:match("0%.123") then
          found_time = true
          logger.debug("Found time line: " .. line)
        end
      end

      expect(found_summary).to.equal(true, "Output should contain 'Test Execution Summary'")
      expect(found_passes).to.equal(true, "Output should list passes count")
      expect(found_time).to.equal(true, "Output should show elapsed time")
    end)

    it("formats output correctly with dot format", function()
      local test_results = create_test_results(true)
      local mock_runner = create_mock_runner(test_results)
      mock_module("lib.core.runner", mock_runner)

      start_capture_output()

      local mock_firmo = create_mock_firmo()
      local result = cli.run({ "--console-format=dot", "tests/" }, mock_firmo)

      local output = stop_capture_output()

      -- Dot format should be more compact
      expect(result).to.equal(true)

      -- Check for expected elements in dot output
      local found_all_passed = false
      local found_compact_summary = false

      for _, line in ipairs(output) do
        if line:match("All tests passed!") then
          found_all_passed = true
        end
        if line:match("Passes: 10, Failures: 0, Skipped: 1") then
          found_compact_summary = true
        end
      end

      expect(found_all_passed).to.equal(true, "Dot output should contain 'All tests passed!'")
      expect(found_compact_summary).to.equal(true, "Dot output should contain compact summary line")
    end)
  end)
end)
