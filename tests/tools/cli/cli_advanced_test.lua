---@diagnostic disable: missing-parameter, param-type-mismatch
--- CLI Module Advanced Tests
---
--- Advanced tests for the `lib/tools/cli` module focusing on edge cases, complex scenarios,
--- and regression testing as part of the CLI refactoring plan Phase IV.
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
local logger = logging.get_logger("test.cli_advanced")

-- Make sure error handler is available
local error_handler = require("lib.tools.error_handler")

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

-- Create a mock interactive module
local function create_mock_interactive()
  return {
    configure_called = false,
    start_called = false,
    config_options = nil,
    firmo_instance = nil,

    configure = function(self, options)
      self.configure_called = true
      self.config_options = options
      return true
    end,

    start = function(self, firmo_instance)
      self.start_called = true
      self.firmo_instance = firmo_instance
      return true
    end,
  }
end

-- Main test suite
describe("CLI Advanced Tests", function()
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

  -- Test sections will be implemented below according to the plan
  -- 1. Edge Cases and Advanced Scenarios
  describe("Edge Cases and Advanced Scenarios", function()
    describe("Config File Loading and Creation", function()
      it("handles loading a valid config file correctly", function()
        -- Save both the original verbose setting and logging level before the test
        local original_cli_options = central_config.get("cli_options") or {}
        local original_verbose = original_cli_options.verbose
        local original_log_level = logging.get_level()

        -- Setup before block to set logging level before test runs
        before(function()
          -- Temporarily set logging level to INFO to prevent excessive debug output
          logging.set_level(logging.INFO)
          logger.debug("Temporarily set logging level to INFO for test")
        end)

        -- Setup cleanup in after block to ensure state is restored even if test fails
        after(function()
          -- Restore the original verbose setting
          if original_cli_options then
            local cli_options_to_restore = central_config.get("cli_options") or {}
            cli_options_to_restore.verbose = original_verbose
            central_config.set("cli_options", cli_options_to_restore)
          end

          -- Restore the original logging level
          logging.set_level(original_log_level)
          logger.debug("Restored original logging level", { level = original_log_level })
        end)

        -- Create a valid config file
        local valid_config_content = [[
          return {
            coverage = {
              threshold = 95,
              include = { "lib/**/*.lua" }
            },
            quality = {
              level = 5
            },
            cli_options = {
              verbose = true,
              file_discovery_pattern = "*_spec.lua"
            }
          }
        ]]

        local config_file_path = temp_dir:create_file("valid_config.lua", valid_config_content)

        -- Run CLI with config option
        local mock_firmo = create_mock_firmo()
        start_capture_output()
        local result = cli.run({ "--config=" .. config_file_path }, mock_firmo)
        local output = stop_capture_output()

        -- Should succeed
        expect(result).to.be_truthy("Command should succeed with valid config")

        -- Check if config values were loaded correctly
        local coverage_config = central_config.get("coverage")
        expect(coverage_config).to.be.a("table")
        expect(coverage_config.threshold).to.equal(95)

        local quality_config = central_config.get("quality")
        expect(quality_config).to.be.a("table")
        expect(quality_config.level).to.equal(5)

        local cli_options = central_config.get("cli_options")
        expect(cli_options).to.be.a("table")
        expect(cli_options.verbose).to.equal(true)
        expect(cli_options.file_discovery_pattern).to.equal("*_spec.lua")
      end)

      it("handles syntax errors in config files gracefully", function()
        -- Create a config file with Lua syntax error
        local syntax_error_config = [[
          return {
            coverage = {
              threshold = 90,
              include = { "lib/**/*.lua"  -- Missing closing brace
            },
            quality = {
              level = 4
            }
          }
        ]]

        local config_file_path = temp_dir:create_file("syntax_error_config.lua", syntax_error_config)

        -- Capture output
        start_capture_output()

        -- Run CLI with broken config
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "--config=" .. config_file_path }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Should return false to indicate error
        expect(result).to.be_falsey("Command should fail with invalid config")

        -- Should output error message about syntax
        local error_message_found = false
        for _, line in ipairs(output) do
          if line:match("Failed to load config file") or line:match("syntax error") then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message about syntax error should be displayed")
      end)

      it("handles runtime errors in config files gracefully", function()
        -- Create a config file with runtime error (not syntax error)
        local runtime_error_config = [[
          local x = non_existent_function() -- This will cause a runtime error
          return {
            coverage = {
              threshold = 85
            }
          }
        ]]

        local config_file_path = temp_dir:create_file("runtime_error_config.lua", runtime_error_config)

        -- Capture output
        start_capture_output()

        -- Run CLI with config that has runtime error
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "--config=" .. config_file_path }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Should return false to indicate error
        expect(result).to.be_falsey("Command should fail with runtime error in config")

        -- Should output error message about runtime error
        local error_message_found = false
        for _, line in ipairs(output) do
          if line:match("Error loading config") or line:match("attempt to call") then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message about runtime error should be displayed")
      end)

      it("handles non-existent config file paths gracefully", function()
        -- Use a path that doesn't exist
        local non_existent_path = temp_dir.path .. "/does_not_exist.lua"

        -- Ensure file doesn't actually exist
        if fs.file_exists(non_existent_path) then
          fs.remove_file(non_existent_path)
        end

        -- Capture output
        start_capture_output()

        -- Run CLI with non-existent config
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "--config=" .. non_existent_path }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Should return false to indicate error
        expect(result).to.be_falsey("Command should fail with non-existent config")

        -- Should output error message about file not found
        local error_message_found = false
        for _, line in ipairs(output) do
          if line:match("Config file not found") or line:match("Specified config file not found") then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message about missing config file should be displayed")
      end)

      it("creates a default config file with --create-config flag", function()
        -- Get the path where the config file will be created
        local config_path = ".firmo-config.lua"

        -- Patch central_config.create_default_config_file to use our temp directory
        local original_create_fn = central_config.create_default_config_file
        central_config.create_default_config_file = function(path)
          return original_create_fn(temp_dir.path .. "/" .. path)
        end

        -- Capture output
        start_capture_output()

        -- Run CLI with create-config flag
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "--create-config" }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Restore original function
        central_config.create_default_config_file = original_create_fn

        -- Should succeed
        expect(result).to.equal(true, "Create config command should succeed")

        -- Should output success message
        local success_message_found = false
        for _, line in ipairs(output) do
          if line:match("Created .firmo%-config%.lua") then
            success_message_found = true
            break
          end
        end
        expect(success_message_found).to.equal(true, "Success message should be displayed")

        -- File should exist in the temp directory
        expect(fs.file_exists(temp_dir.path .. "/" .. config_path)).to.equal(true, "Config file should be created")
      end)

      it("handles config creation failure gracefully", function()
        -- Mock central_config.create_default_config_file to simulate failure
        local original_create_fn = central_config.create_default_config_file
        central_config.create_default_config_file = function(path)
          return nil, "Permission denied"
        end

        -- Capture output
        start_capture_output()

        -- Run CLI with create-config flag
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "--create-config" }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Restore original function
        central_config.create_default_config_file = original_create_fn

        -- Should fail
        expect(result).to.equal(false, "Command should fail when config creation fails")

        -- Should output error message
        local error_message_found = false
        for _, line in ipairs(output) do
          if line:match("Error:") and line:match("Permission denied") then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message about creation failure should be displayed")
      end)

      it("CLI flags override loaded config values", function()
        -- Save the original verbose setting and logging level
        local original_cli_options = central_config.get("cli_options") or {}
        local original_verbose = original_cli_options.verbose
        local original_log_level = logging.get_level()

        -- Setup before block to set logging level before test runs
        before(function()
          -- Temporarily set logging level to INFO to prevent excessive debug output
          logging.set_level(logging.INFO)
          logger.debug("Temporarily set logging level to INFO for test")
        end)

        -- Setup cleanup in after block to ensure state is restored even if test fails
        after(function()
          -- Restore the original verbose setting
          if original_cli_options then
            local cli_options_to_restore = central_config.get("cli_options") or {}
            cli_options_to_restore.verbose = original_verbose
            central_config.set("cli_options", cli_options_to_restore)
          end

          -- Restore the original logging level
          logging.set_level(original_log_level)
          logger.debug("Restored original logging level", { level = original_log_level })
        end)

        -- Create a config with specific values
        local config_content = [[
          return {
            coverage = {
              threshold = 80
            },
            quality = {
              level = 3
            },
            cli_options = {
              file_discovery_pattern = "*_test.lua",
              verbose = false
            }
          }
        ]]

        local config_file_path = temp_dir:create_file("override_test.lua", config_content)

        -- Run CLI with config but also override with flags
        local mock_firmo = create_mock_firmo()

        -- Need to mock coverage and quality modules
        local mock_coverage = {
          init_called = false,
          config = nil,

          init = function(self, config)
            self.init_called = true
            self.config = config
            return true
          end,

          start = function() end,
        }

        -- Capture output to check for verbose messages
        start_capture_output()

        mock_module("lib.coverage", mock_coverage)

        -- Run with both config and CLI flags
        local result = cli.run({
          "--config=" .. config_file_path,
          "--coverage",
          "--threshold=90",
          "--verbose",
        }, mock_firmo)

        local output = stop_capture_output()

        -- CLI flags should override config values
        expect(mock_coverage.init_called).to.equal(true, "Coverage should be initialized")
        expect(mock_coverage.config).to.be.a("table")
        expect(mock_coverage.config.threshold).to.equal(90, "CLI threshold should override config")

        -- Check if verbose flag was set despite config having it as false
        local verbose_enabled = false
        for _, line in ipairs(output) do
          if line:match("Debug mode enabled") or line:match("verbose.*true") then
            verbose_enabled = true
            break
          end
        end
        expect(verbose_enabled).to.equal(true, "Verbose output should be enabled by CLI flag")
      end)

      it("handles config files with non-table return values gracefully", function()
        -- Create a config that returns a non-table value
        local invalid_return_config = [[
          return "This is not a table"
        ]]

        local config_file_path = temp_dir:create_file("invalid_return.lua", invalid_return_config)

        -- Capture output
        start_capture_output()

        -- Run CLI with invalid config
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "--config=" .. config_file_path }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Should ideally fail with a meaningful error
        expect(result).to.be_falsey("Command should fail with invalid config return type")

        -- Look for an error message
        local error_message_found = false
        for _, line in ipairs(output) do
          if line:match("Invalid config") or line:match("Expected table") or line:match("Error loading config") then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message about invalid config structure should be displayed")
      end)
    end)

    -- describe("Interactive Mode", function()
    --   it("initializes interactive mode with --interactive flag", function()
    --     -- Create mock interactive module
    --     local mock_interactive_module = create_mock_interactive()
    --     mock_module("lib.tools.interactive", mock_interactive_module)
    --
    --     -- Run CLI with interactive flag
    --     local mock_firmo = create_mock_firmo()
    --     local result = cli.run({ "--interactive" }, mock_firmo)
    --
    --     -- Check interactive module was properly initialized
    --     expect(mock_interactive_module.configure_called).to.equal(true, "Interactive module configure should be called")
    --     expect(mock_interactive_module.start_called).to.equal(true, "Interactive module start should be called")
    --     expect(mock_interactive_module.firmo_instance).to.equal(
    --       mock_firmo,
    --       "Firmo instance should be passed to interactive module"
    --     )
    --
    --     -- Default values should be set in config options
    --     expect(mock_interactive_module.config_options).to.be.a("table")
    --     expect(mock_interactive_module.config_options.test_dir).to.equal(
    --       "./tests",
    --       "Default test directory should be set"
    --     )
    --   end)
    --
    --   it("passes CLI options to interactive mode configuration", function()
    --     -- Create mock interactive module
    --     local mock_interactive_module = create_mock_interactive()
    --     mock_module("lib.tools.interactive", mock_interactive_module)
    --
    --     -- Run CLI with interactive flag and additional options
    --     local mock_firmo = create_mock_firmo()
    --     local result = cli.run({
    --       "--interactive",
    --       "--quality",
    --       "--coverage",
    --       "./custom/tests/",
    --     }, mock_firmo)
    --
    --     -- Check interactive module was properly initialized
    --     expect(mock_interactive_module.configure_called).to.equal(true, "Interactive module configure should be called")
    --     expect(mock_interactive_module.start_called).to.equal(true, "Interactive module start should be called")
    --
    --     -- Check config options
    --     expect(mock_interactive_module.config_options).to.be.a("table")
    --     expect(mock_interactive_module.config_options.test_dir).to.equal(
    --       "./custom/tests/",
    --       "Custom test directory should be set"
    --     )
    --     expect(mock_interactive_module.config_options.coverage_instance).to.exist("Coverage instance should be passed")
    --     expect(mock_interactive_module.config_options.quality_instance).to.exist("Quality instance should be passed")
    --   end)
    --
    --   it("handles missing interactive module gracefully", function()
    --     -- Ensure interactive module is null
    --     mock_module("lib.tools.interactive", nil)
    --
    --     -- Capture output
    --     start_capture_output()
    --
    --     -- Run CLI with interactive flag
    --     local mock_firmo = create_mock_firmo()
    --     local result = cli.run({ "--interactive" }, mock_firmo)
    --
    --     -- Check output
    --     local output = stop_capture_output()
    --
    --     -- Should return false to indicate error
    --     expect(result).to.equal(false, "Command should fail when interactive module is not available")
    --
    --     -- Should output error message
    --     local error_message_found = false
    --     for _, line in ipairs(output) do
    --       if line:match("Interactive module not available") then
    --         error_message_found = true
    --         break
    --       end
    --     end
    --     expect(error_message_found).to.equal(true, "Error message about missing interactive module should be displayed")
    --   end)
    --
    --   it("handles combined interactive and watch modes correctly", { expect_error = true }, function()
    --     -- Create mock modules
    --     local mock_interactive_module = create_mock_interactive()
    --     local mock_watcher_module = {
    --       configure_called = false,
    --       watch_called = false,
    --       config = nil,
    --
    --       configure = function(self, config)
    --         self.configure_called = true
    --         self.config = config
    --         return true
    --       end,
    --
    --       watch = function(self, callback)
    --         self.watch_called = true
    --         return true
    --       end,
    --     }
    --
    --     mock_module("lib.tools.interactive", mock_interactive_module)
    --     mock_module("lib.tools.watcher", mock_watcher_module)
    --
    --     -- Wrap the test in error capture
    --     return test_helper.with_error_capture(function()
    --       -- Run CLI with both interactive and watch flags
    --       local mock_firmo = create_mock_firmo()
    --       local result = cli.run({ "--interactive", "--watch" }, mock_firmo)
    --
    --       -- Interactive should take precedence over watch
    --       expect(mock_interactive_module.start_called).to.equal(true, "Interactive mode should be started")
    --       expect(mock_watcher_module.watch_called).to.equal(false, "Watch mode should not be started")
    --     end)
    --   end)
    --
    --   it("honors central_config settings for interactive mode", function()
    --     -- Create mock interactive module
    --     local mock_interactive_module = create_mock_interactive()
    --     mock_module("lib.tools.interactive", mock_interactive_module)
    --
    --     -- Set central_config values
    --     local custom_test_dir = "./custom_interactive_tests"
    --     central_config.set("interactive.test_dir", custom_test_dir)
    --
    --     -- Run CLI with interactive flag
    --     local mock_firmo = create_mock_firmo()
    --     local result = cli.run({ "--interactive" }, mock_firmo)
    --
    --     -- Check interactive module was properly initialized
    --     expect(mock_interactive_module.configure_called).to.equal(true, "Interactive module configure should be called")
    --
    --     -- Check that central_config values are passed
    --     expect(mock_interactive_module.config_options).to.be.a("table")
    --     expect(mock_interactive_module.config_options.test_dir).to.equal(
    --       "./tests",
    --       "Default test directory should still be used because CLI options take precedence"
    --     )
    --
    --     -- Now try with a different approach where we directly get the config
    --     mock_interactive_module = create_mock_interactive()
    --     mock_module("lib.tools.interactive", mock_interactive_module)
    --
    --     -- Mock central_config.get to return our custom values
    --     local original_get = central_config.get
    --     central_config.get = function(key)
    --       if key == "interactive" then
    --         return { test_dir = custom_test_dir }
    --       end
    --       return original_get(key)
    --     end
    --
    --     local result = cli.run({ "--interactive" }, mock_firmo)
    --
    --     -- Restore original central_config.get
    --     central_config.get = original_get
    --
    --     -- Central config values should be used if available
    --     expect(mock_interactive_module.config_options).to.be.a("table")
    --     -- This part depends on actual CLI implementation - would need to check if CLI
    --     -- module actually reads interactive.test_dir from central_config
    --   end)
    -- end)

    describe("Complex Path Combinations", function()
      it("correctly handles a mix of file and directory paths", function()
        -- Create a test directory structure
        local test_dir_1 = temp_dir:create_subdirectory("test_dir_1")
        local test_dir_2 = temp_dir:create_subdirectory("test_dir_2")
        local test_file_1 = temp_dir:create_file("test_file_1.lua", "-- Test file 1")
        local test_file_2 = temp_dir:create_file("test_file_2.lua", "-- Test file 2")
        local nested_file = temp_dir:create_file("test_dir_1/nested_test.lua", "-- Nested test file")

        -- Mock the discover module
        local discover_calls = {}
        local discover_dirs = {}
        local mock_discover = {
          discover = function(dir, pattern)
            table.insert(discover_calls, { dir = dir, pattern = pattern })
            table.insert(discover_dirs, dir)
            return { files = { "fake_discovered_file.lua" } }
          end,
        }

        -- Mock the runner module
        local run_file_calls = {}
        local run_tests_calls = {}
        local mock_runner = {
          configure = function() end,
          run_file = function(path, _, __)
            table.insert(run_file_calls, path)
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
          run_tests = function(paths, _, __)
            table.insert(run_tests_calls, paths)
            return { success = true, passes = #paths, errors = 0, elapsed = 0.01 }
          end,
        }

        mock_module("lib.tools.discover", mock_discover)
        mock_module("lib.core.runner", mock_runner)

        -- Run CLI with a mix of file and directory paths
        local mock_firmo = create_mock_firmo()
        local result = cli.run({
          test_dir_1,
          test_file_1,
          test_dir_2,
          test_file_2,
        }, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "Command should succeed with valid paths")

        -- Check that the first directory is treated as base_test_dir and the rest are in specific_paths
        expect(#discover_calls).to.equal(0, "Discover should not be called since specific paths were provided")
        expect(#run_tests_calls).to.equal(1, "run_tests should be called once")
        expect(run_tests_calls[1]).to.be.a("table")

        -- Order of paths should be preserved in the execution
        local expected_paths = {
          test_dir_1, -- First dir should still be included
          test_file_1,
          test_dir_2,
          test_file_2,
        }

        local inspect = require("inspect")
        logger.debug("Expected paths:" .. inspect(expected_paths))
        logger.debug("Actual paths:" .. inspect(run_tests_calls[1]))

        -- Check that all paths are included
        expect(#run_tests_calls[1]).to.equal(#expected_paths, "All paths should be included")

        -- Verify each path is included
        for _, expected_path in ipairs(expected_paths) do
          local found = false
          for _, actual_path in ipairs(run_tests_calls[1]) do
            if actual_path == expected_path then
              found = true
              break
            end
          end
          expect(found).to.equal(true, "Path should be included: " .. expected_path)
        end
      end)

      it("handles non-existent paths gracefully", function()
        -- Create the mock discover and runner modules
        local mock_discover = {
          discover = function(dir, pattern)
            -- Return empty file list for any unknown directory
            if dir == "./non-existent" or dir == "./not-real" then
              return nil, "Directory not found: " .. dir
            end
            return { files = { "fake_discovered_file.lua" } }
          end,
        }

        local mock_runner = {
          configure = function() end,
          run_tests = function(paths, _, __)
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
        }

        mock_module("lib.tools.discover", mock_discover)
        mock_module("lib.core.runner", mock_runner)

        -- Capture output
        start_capture_output()

        -- Run CLI with non-existent paths
        local mock_firmo = create_mock_firmo()
        local result = cli.run({
          "./non-existent", -- This would trigger directory discovery
          "./not-real/test.lua", -- This would be treated as a specific file
        }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Should fail due to directory not found
        expect(result).to.equal(false, "Command should fail with non-existent directory")

        -- Should output error message
        local error_message_found = false
        for _, line in ipairs(output) do
          if line:match("Discovery failed") or line:match("Directory not found") then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message about non-existent directory should be displayed")
      end)

      it("handles multiple directory specifications correctly", function()
        -- Create test directories and files
        local test_dir_1 = temp_dir:create_subdirectory("test_dir_1")
        local test_dir_2 = temp_dir:create_subdirectory("test_dir_2")
        local test_dir_3 = temp_dir:create_subdirectory("test_dir_3")

        -- Create mock discover module
        local last_discover_dir = nil
        local mock_discover = {
          discover = function(dir, pattern)
            last_discover_dir = dir
            return { files = { "fake_discovered_file.lua" } }
          end,
        }

        -- Create mock runner module
        local run_tests_paths = nil
        local mock_runner = {
          configure = function() end,
          run_tests = function(paths, _, __)
            run_tests_paths = paths
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
          run_discovered = function(dir, pattern, _, __)
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
        }

        mock_module("lib.tools.discover", mock_discover)
        mock_module("lib.core.runner", mock_runner)

        -- Run with multiple directory paths
        local mock_firmo = create_mock_firmo()
        local result = cli.run({
          test_dir_1,
          test_dir_2,
          test_dir_3,
        }, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "Command should succeed with multiple directories")

        -- First directory should be base_test_dir (not directly evident in test)
        expect(run_tests_paths).to.be.a("table")
        expect(#run_tests_paths).to.equal(3, "All three directories should be included")

        -- All three directories should be in the paths
        local dir1_found = false
        local dir2_found = false
        local dir3_found = false

        for _, path in ipairs(run_tests_paths) do
          if path == test_dir_1 then
            dir1_found = true
          end
          if path == test_dir_2 then
            dir2_found = true
          end
          if path == test_dir_3 then
            dir3_found = true
          end
        end

        expect(dir1_found).to.equal(true, "First directory should be included")
        expect(dir2_found).to.equal(true, "Second directory should be included")
        expect(dir3_found).to.equal(true, "Third directory should be included")
      end)

      it("handles glob-expanded paths correctly", function()
        -- Create a test directory with multiple test files
        local test_dir = temp_dir:create_subdirectory("glob_test")
        local test_file_1 = temp_dir:create_file("glob_test/test1.lua", "-- Test file 1")
        local test_file_2 = temp_dir:create_file("glob_test/test2.lua", "-- Test file 2")
        local test_file_3 = temp_dir:create_file("glob_test/test3.lua", "-- Test file 3")

        -- Create mock runner module
        local run_tests_paths = nil
        local mock_runner = {
          configure = function() end,
          run_tests = function(paths, _, __)
            run_tests_paths = paths
            return { success = true, passes = #paths, errors = 0, elapsed = 0.01 }
          end,
        }

        mock_module("lib.core.runner", mock_runner)

        -- Run CLI with glob expanded paths (simulate what shell would do)
        local mock_firmo = create_mock_firmo()
        local result = cli.run({
          test_file_1,
          test_file_2,
          test_file_3,
        }, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "Command should succeed with glob expanded paths")

        -- All files should be in the run_tests_paths
        expect(run_tests_paths).to.be.a("table")
        expect(#run_tests_paths).to.equal(3, "All three files should be included")

        -- Verify each file is included
        local file1_found = false
        local file2_found = false
        local file3_found = false

        for _, path in ipairs(run_tests_paths) do
          if path == test_file_1 then
            file1_found = true
          end
          if path == test_file_2 then
            file2_found = true
          end
          if path == test_file_3 then
            file3_found = true
          end
        end

        expect(file1_found).to.equal(true, "First file should be included")
        expect(file2_found).to.equal(true, "Second file should be included")
        expect(file3_found).to.equal(true, "Third file should be included")
      end)

      it("handles a directory path with a pattern correctly", function()
        -- Create test directory with files
        local test_dir = temp_dir:create_subdirectory("pattern_test")
        local test_file = temp_dir:create_file("pattern_test/unit_test.lua", "-- Unit test file")
        local spec_file = temp_dir:create_file("pattern_test/feature_spec.lua", "-- Spec test file")

        -- Mock discover module to verify pattern is passed
        local last_discover_call = nil
        local mock_discover = {
          discover = function(dir, pattern)
            last_discover_call = { dir = dir, pattern = pattern }
            return { files = { spec_file } }
          end,
        }

        -- Mock runner module
        local run_discovered_call = nil
        local mock_runner = {
          configure = function() end,
          run_discovered = function(dir, pattern, _, __)
            run_discovered_call = { dir = dir, pattern = pattern }
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
        }

        mock_module("lib.tools.discover", mock_discover)
        mock_module("lib.core.runner", mock_runner)

        -- Run CLI with directory path and pattern
        local custom_pattern = "*_spec.lua"
        local mock_firmo = create_mock_firmo()
        local result = cli.run({
          "--pattern=" .. custom_pattern,
          test_dir,
        }, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "Command should succeed with directory and pattern")

        -- Pattern should be passed to discover
        expect(last_discover_call).to.be.a("table")
        expect(last_discover_call.dir).to.equal(test_dir, "Correct directory should be passed to discover")
        expect(last_discover_call.pattern).to.equal(custom_pattern, "Custom pattern should be passed to discover")

        -- Pattern should be passed to run_discovered
        expect(run_discovered_call).to.be.a("table")
        expect(run_discovered_call.dir).to.equal(test_dir, "Correct directory should be passed to run_discovered")
        expect(run_discovered_call.pattern).to.equal(
          custom_pattern,
          "Custom pattern should be passed to run_discovered"
        )
      end)

      it("falls back to default test directory when no paths specified", function()
        -- Mock discover to track default directory usage
        local discover_called_with = nil
        local mock_discover = {
          discover = function(dir, pattern)
            discover_called_with = { dir = dir, pattern = pattern }
            return { files = { "default_test.lua" } }
          end,
        }

        -- Mock runner to avoid actual running
        local run_discovered_args = nil
        local mock_runner = {
          configure = function() end,
          run_discovered = function(dir, pattern, _, __)
            run_discovered_args = { dir = dir, pattern = pattern }
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
        }

        mock_module("lib.tools.discover", mock_discover)
        mock_module("lib.core.runner", mock_runner)

        -- Run CLI without any path arguments
        local mock_firmo = create_mock_firmo()
        local result = cli.run({}, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "Command should succeed with default test directory")

        -- Default directory should be used
        expect(discover_called_with).to.be.a("table")
        expect(discover_called_with.dir).to.equal("./tests", "Default test directory should be used")
        expect(discover_called_with.pattern).to.equal("*_test.lua", "Default pattern should be used")

        -- Run_discovered should be called with same values
        expect(run_discovered_args).to.be.a("table")
        expect(run_discovered_args.dir).to.equal("./tests", "Default test directory should be used for running")
        expect(run_discovered_args.pattern).to.equal("*_test.lua", "Default pattern should be used for running")
      end)
    end)
  end)

  -- 2. Regression Tests
  describe("Regression Tests", function()
    describe("Exit Code Verification", function()
      it("returns true exit code for successful test execution", function()
        -- Create a mock runner module that always succeeds
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
          end,
          run_discovered = function()
            return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
          end,
        }

        mock_module("lib.core.runner", mock_runner)

        -- Run CLI with basic test run
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "./tests" }, mock_firmo)

        -- Should return true for successful tests
        expect(result).to.equal(true, "CLI should return true for successful test execution")
      end)

      it("returns false exit code for failed test execution", function()
        -- Create a mock runner module that always fails
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            return { success = false, passes = 3, errors = 2, elapsed = 0.01 }
          end,
          run_discovered = function()
            return { success = false, passes = 3, errors = 2, elapsed = 0.01 }
          end,
        }

        mock_module("lib.core.runner", mock_runner)

        -- Run CLI with basic test run
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "./tests" }, mock_firmo)

        -- Should return false for failed tests
        expect(result).to.equal(false, "CLI should return false for failed test execution")
      end)

      it("returns false exit code when discovering test files fails", function()
        -- Create a mock discover module that fails
        local mock_discover = {
          discover = function()
            return nil, "Failed to discover tests: Permission denied"
          end,
        }

        mock_module("lib.tools.discover", mock_discover)

        -- Capture output
        start_capture_output()

        -- Run CLI with a directory path
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "./tests" }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Should return false for discovery failure
        expect(result).to.equal(false, "CLI should return false when discovery fails")

        -- Should output error message
        local error_message_found = false
        for _, line in ipairs(output) do
          if line:match("Discovery failed") then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message about discovery failure should be displayed")
      end)

      it("returns false exit code when report generation fails", function()
        -- Create a mock runner that succeeds
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
          end,
        }

        -- Create a mock coverage module
        local mock_coverage = {
          init = function()
            return true
          end,
          start = function() end,
          shutdown = function() end,
          get_report_data = function()
            return { coverage_data = "mock data" }
          end,
        }

        -- Create a mock reporting module that fails
        local mock_reporting = {
          auto_save_reports = function()
            error("Failed to write report: Permission denied")
          end,
        }

        mock_module("lib.core.runner", mock_runner)
        mock_module("lib.coverage", mock_coverage)
        mock_module("lib.reporting", mock_reporting)

        -- Run CLI with coverage and report flags
        local mock_firmo = create_mock_firmo()

        -- Capture output to hide expected error messages
        start_capture_output()

        local result = cli.run({
          "--coverage",
          "--report",
          "--report-formats=html",
          "./tests",
        }, mock_firmo)

        stop_capture_output()

        -- Should return false when report generation fails, despite tests passing
        expect(result).to.equal(false, "CLI should return false when report generation fails")
      end)

      it("returns true exit code for help and version flags", function()
        -- Mock version module
        local mock_version = {
          string = "1.2.3",
        }

        mock_module("lib.core.version", mock_version)

        -- Run CLI with help flag
        start_capture_output()
        local mock_firmo = create_mock_firmo()
        local help_result = cli.run({ "--help" }, mock_firmo)
        stop_capture_output()

        -- Run CLI with version flag
        start_capture_output()
        local version_result = cli.run({ "--version" }, mock_firmo)
        stop_capture_output()

        -- Both should return true
        expect(help_result).to.equal(true, "CLI should return true for --help flag")
        expect(version_result).to.equal(true, "CLI should return true for --version flag")
      end)

      it("returns false exit code for invalid CLI arguments", function()
        -- Run CLI with invalid arguments
        start_capture_output()
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "--invalid-flag", "--another-bad-option" }, mock_firmo)
        stop_capture_output()

        -- Should return false for invalid arguments
        expect(result).to.equal(false, "CLI should return false for invalid arguments")
      end)
    end)

    describe("Full System Integration", function()
      it("integrates coverage, quality, and reports correctly", function()
        -- Create mocks for all required modules
        local coverage_init_called = false
        local coverage_start_called = false
        local coverage_shutdown_called = false
        local coverage_get_data_called = false

        local mock_coverage = {
          init = function()
            coverage_init_called = true
            return true
          end,
          start = function()
            coverage_start_called = true
          end,
          shutdown = function()
            coverage_shutdown_called = true
          end,
          get_report_data = function()
            coverage_get_data_called = true
            return { lines = 100, covered = 80, coverage = 80 }
          end,
        }

        local quality_init_called = false
        local quality_register_called = false
        local quality_get_data_called = false

        local mock_quality = {
          init = function()
            quality_init_called = true
            return true
          end,
          register_with_firmo = function()
            quality_register_called = true
          end,
          get_report_data = function()
            quality_get_data_called = true
            return { level = 3, score = 85 }
          end,
        }

        local runner_configure_called = false

        local mock_runner = {
          configure = function(config)
            runner_configure_called = true
            return true
          end,
          run_tests = function()
            return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
          end,
        }

        local reporting_save_called = false
        local reporting_save_args = nil

        local mock_reporting = {
          auto_save_reports = function(cov_data, qual_data, _, options)
            reporting_save_called = true
            reporting_save_args = {
              cov_data = cov_data,
              qual_data = qual_data,
              options = options,
            }
            return true
          end,
        }

        -- Replace all modules
        mock_module("lib.coverage", mock_coverage)
        mock_module("lib.quality", mock_quality)
        mock_module("lib.core.runner", mock_runner)
        mock_module("lib.reporting", mock_reporting)

        -- Create a mock discover module as well
        local mock_discover = {
          discover = function()
            return { files = { "test1.lua", "test2.lua" } }
          end,
        }

        mock_module("lib.tools.discover", mock_discover)

        -- Run CLI with coverage, quality, and report flags
        local mock_firmo = create_mock_firmo()

        local result = cli.run({
          "--coverage",
          "--quality",
          "--report",
          "--report-formats=html,json",
          "--report-dir=./custom-reports",
          "--threshold=75",
          "--quality-level=4",
          "./tests",
        }, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "CLI should succeed with integrated coverage, quality, and reports")

        -- All modules should be initialized and used correctly
        expect(coverage_init_called).to.equal(true, "Coverage module should be initialized")
        expect(coverage_start_called).to.equal(true, "Coverage should be started")
        expect(quality_init_called).to.equal(true, "Quality module should be initialized")
        expect(quality_register_called).to.equal(true, "Quality should be registered with firmo")
        expect(runner_configure_called).to.equal(true, "Runner should be configured")

        -- Report generation should be triggered
        expect(coverage_shutdown_called).to.equal(true, "Coverage should be shutdown after tests")
        expect(coverage_get_data_called).to.equal(true, "Coverage data should be retrieved")
        expect(quality_get_data_called).to.equal(true, "Quality data should be retrieved")
        expect(reporting_save_called).to.equal(true, "Reports should be generated")

        -- Reporting args should be correct
        expect(reporting_save_args).to.be.a("table")
        expect(reporting_save_args.cov_data).to.be.a("table")
        expect(reporting_save_args.qual_data).to.be.a("table")
        expect(reporting_save_args.options).to.be.a("table")
        expect(reporting_save_args.options.report_dir).to.equal("./custom-reports")

        -- Coverage formats should be passed correctly
        expect(reporting_save_args.options.coverage_formats).to.be.a("table")
        expect(#reporting_save_args.options.coverage_formats).to.equal(2)
        expect(reporting_save_args.options.coverage_formats[1]).to.equal("html")
        expect(reporting_save_args.options.coverage_formats[2]).to.equal("json")

        -- Quality formats should be passed correctly
        expect(reporting_save_args.options.quality_formats).to.be.a("table")
        expect(#reporting_save_args.options.quality_formats).to.equal(2)
        expect(reporting_save_args.options.quality_formats[1]).to.equal("html")
        expect(reporting_save_args.options.quality_formats[2]).to.equal("json")
      end)

      it("integrates coverage, quality, and watch mode correctly", function()
        -- Create mock modules
        local coverage_init_called = false
        local quality_init_called = false
        local watcher_configure_called = false
        local watcher_watch_called = false
        local watcher_callback = nil

        local mock_coverage = {
          init = function()
            coverage_init_called = true
            return true
          end,
          start = function() end,
        }

        local mock_quality = {
          init = function()
            quality_init_called = true
            return true
          end,
          register_with_firmo = function() end,
        }

        local mock_watcher = {
          configure = function(config)
            watcher_configure_called = true
            return true
          end,
          watch = function(callback)
            watcher_watch_called = true
            watcher_callback = callback
            return true
          end,
        }

        local runner_calls = {}
        local mock_runner = {
          configure = function() end,
          run_discovered = function(dir, pattern, firmo_instance)
            table.insert(runner_calls, { dir = dir, pattern = pattern })
            return { success = true, passes = 3, errors = 0, elapsed = 0.01 }
          end,
        }

        -- Replace all modules
        mock_module("lib.coverage", mock_coverage)
        mock_module("lib.quality", mock_quality)
        mock_module("lib.tools.watcher", mock_watcher)
        mock_module("lib.core.runner", mock_runner)

        -- Run CLI with coverage, quality, and watch mode
        local mock_firmo = create_mock_firmo()

        -- The watch mode will take over and not return, so we need to mock that behavior
        -- We'll have the watcher call the callback once and then return true
        local original_watch = mock_watcher.watch
        mock_watcher.watch = function(callback)
          watcher_watch_called = true
          watcher_callback = callback
          -- Call the callback with simulated changed files
          callback({ "test1.lua", "test2.lua" })
          -- Now just return true instead of blocking
          return true
        end

        local result = cli.run({
          "--coverage",
          "--quality",
          "--watch",
          "./tests",
        }, mock_firmo)

        -- Restore original watch function
        mock_watcher.watch = original_watch

        -- Should succeed
        expect(result).to.equal(true, "CLI should succeed with watch mode")

        -- Modules should be initialized
        expect(coverage_init_called).to.equal(true, "Coverage module should be initialized")
        expect(quality_init_called).to.equal(true, "Quality module should be initialized")
        expect(watcher_configure_called).to.equal(true, "Watcher should be configured")
        expect(watcher_watch_called).to.equal(true, "Watch mode should be started")

        -- Runner should be called in response to changed files
        expect(#runner_calls).to.be.greater_than(0, "Runner should be called by watcher callback")
      end)

      it("handles complex path combinations with filters and report formats", function()
        -- Create mock modules
        local discover_called = false
        local mock_discover = {
          discover = function(dir, pattern)
            discover_called = true
            return { files = { "test1.lua", "test2.lua" } }
          end,
        }

        local runner_file_filter = nil
        local mock_runner = {
          configure = function() end,
          run_tests = function(paths, firmo_instance, options)
            runner_file_filter = options and options.filter
            return { success = true, passes = 3, errors = 0, elapsed = 0.01 }
          end,
        }

        local mock_coverage = {
          init = function()
            return true
          end,
          start = function() end,
          shutdown = function() end,
          get_report_data = function()
            return { coverage_data = "mock coverage data" }
          end,
        }

        local mock_reporting = {
          auto_save_reports = function(cov_data, qual_data, _, options)
            return true
          end,
        }

        mock_module("lib.tools.discover", mock_discover)
        mock_module("lib.core.runner", mock_runner)
        mock_module("lib.coverage", mock_coverage)
        mock_module("lib.reporting", mock_reporting)

        -- Create test directories and files
        local test_dir = temp_dir:create_subdirectory("complex_test")
        local test_file_1 = temp_dir:create_file("complex_test/api_test.lua", "-- API Test file")
        local test_file_2 = temp_dir:create_file("complex_test/core_test.lua", "-- Core Test file")

        -- Create mock firmo that tracks filter
        local mock_firmo = create_mock_firmo()
        local filter_pattern = nil
        mock_firmo.set_filter = function(pattern)
          filter_pattern = pattern
          mock_firmo.filter_set = true
          mock_firmo.filter_pattern = pattern
        end

        -- Run CLI with complex combination of paths, filters, coverage, and report flags
        local result = cli.run({
          "--coverage",
          "--filter=api", -- Only run tests with "api" in their name/description
          "--report",
          "--report-formats=html,json",
          test_dir,
          test_file_1,
        }, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "CLI should succeed with complex path and filter combination")

        -- Filter should be set on firmo instance
        expect(mock_firmo.filter_set).to.equal(true, "Test name filter should be set")
        expect(mock_firmo.filter_pattern).to.equal("api", "Filter pattern should be set correctly")
      end)

      it("applies multiple formats and handles format conflicts correctly", function()
        -- Create mock modules
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
          end,
        }

        local mock_coverage = {
          init = function()
            return true
          end,
          start = function() end,
          shutdown = function() end,
          get_report_data = function()
            return { coverage = 80, lines = 100, covered = 80 }
          end,
        }

        local reporting_formats = nil
        local mock_reporting = {
          auto_save_reports = function(cov_data, qual_data, _, options)
            reporting_formats = options and options.coverage_formats
            return true
          end,
        }

        mock_module("lib.core.runner", mock_runner)
        mock_module("lib.coverage", mock_coverage)
        mock_module("lib.reporting", mock_reporting)

        -- Run CLI with multiple report formats specifications
        local mock_firmo = create_mock_firmo()

        -- Using both --report-formats and the older conflicting format if it exists
        local result = cli.run({
          "--coverage",
          "--report",
          "--report-formats=html,json",
          "--console-format=dot", -- This should affect console output, not file formats
          "./tests",
        }, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "CLI should succeed with multiple format specifications")

        -- Report formats should be correctly parsed and applied
        expect(reporting_formats).to.be.a("table")
        expect(#reporting_formats).to.equal(2, "Should have two report formats")
        expect(reporting_formats[1]).to.equal("html", "HTML format should be first")
        expect(reporting_formats[2]).to.equal("json", "JSON format should be second")
      end)

      it("combines multi-feature testing with exit code verification", function()
        -- Create mock modules that will trigger different exit codes
        local mock_discover = {
          discover = function(dir, pattern)
            return { files = { "test1.lua", "test2.lua" } }
          end,
        }

        -- Create a suite of exit code tests
        local test_cases = {
          {
            name = "Success case",
            runner = {
              configure = function() end,
              run_tests = function()
                return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
              end,
            },
            reporting = {
              auto_save_reports = function()
                return true
              end,
            },
            args = { "--coverage", "--report", "--report-formats=html", "./tests" },
            expected_result = true,
          },
          {
            name = "Test failure case",
            runner = {
              configure = function() end,
              run_tests = function()
                return { success = false, passes = 3, errors = 2, elapsed = 0.01 }
              end,
            },
            reporting = {
              auto_save_reports = function()
                return true
              end,
            },
            args = { "--coverage", "--report", "--report-formats=html", "./tests" },
            expected_result = false,
          },
          {
            name = "Reporting failure case",
            runner = {
              configure = function() end,
              run_tests = function()
                return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
              end,
            },
            reporting = {
              auto_save_reports = function()
                error("Report generation failed")
              end,
            },
            args = { "--coverage", "--report", "--report-formats=html", "./tests" },
            expected_result = false,
          },
        }

        -- Run each test case
        for _, test_case in ipairs(test_cases) do
          -- Install mocks
          mock_module("lib.tools.discover", mock_discover)
          mock_module("lib.core.runner", test_case.runner)

          -- Coverage module mock
          local mock_coverage = {
            init = function()
              return true
            end,
            start = function() end,
            shutdown = function() end,
            get_report_data = function()
              return { coverage = 80 }
            end,
          }
          mock_module("lib.coverage", mock_coverage)

          -- Reporting module mock
          mock_module("lib.reporting", test_case.reporting)

          -- Capture output to avoid spamming the test results
          start_capture_output()

          -- Run CLI with the test case arguments
          local mock_firmo = create_mock_firmo()
          local result = cli.run(test_case.args, mock_firmo)

          -- Stop capturing output
          stop_capture_output()

          -- Verify the exit code
          expect(result).to.equal(
            test_case.expected_result,
            "CLI should return " .. tostring(test_case.expected_result) .. " for " .. test_case.name
          )
        end
      end)
    end)

    describe("Error Propagation", function()
      it("propagates runner errors to exit code", function()
        -- Create a mock runner that throws an error
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            error("Runner module crashed")
          end,
          run_discovered = function()
            error("Runner module crashed")
          end,
        }

        mock_module("lib.core.runner", mock_runner)

        -- Capture output
        start_capture_output()

        -- Run CLI with basic test run
        local mock_firmo = create_mock_firmo()

        -- The error will be caught within CLI module, but should result in a false return value
        local result = test_helper.with_error_capture(function()
          return cli.run({ "./tests" }, mock_firmo)
        end)()

        -- Get output
        local output = stop_capture_output()

        -- Should return false for runner error
        expect(result).to.equal(false, "CLI should return false when runner throws an error")
      end)

      it("propagates coverage module errors to exit code", function()
        -- Create a mock runner that succeeds
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
          end,
        }

        -- Create a mock coverage module that throws an error
        local mock_coverage = {
          init = function()
            return true
          end,
          start = function()
            error("Coverage module crashed during start")
          end,
          shutdown = function()
            -- This won't be called if start crashed
          end,
          get_report_data = function()
            -- This won't be called if start crashed
          end,
        }

        mock_module("lib.core.runner", mock_runner)
        mock_module("lib.coverage", mock_coverage)

        -- Capture output
        start_capture_output()

        -- Run CLI with coverage flag
        local mock_firmo = create_mock_firmo()

        -- The error will be caught within CLI module, but should result in a false return value
        local result = test_helper.with_error_capture(function()
          return cli.run({ "--coverage", "./tests" }, mock_firmo)
        end)()

        -- Get output
        local output = stop_capture_output()

        -- Should propagate error by returning false
        expect(result).to.equal(false, "CLI should return false when coverage module throws an error")
      end)

      it("combines multiple failing modules correctly", { timeout = 5000 }, function()
        -- Test scenario with multiple modules that could fail
        -- First create all the necessary mocks

        -- Mock coverage module that fails
        local mock_coverage = {
          init = function()
            return nil, "Failed to initialize coverage: Invalid config"
          end,
          start = function() end,
        }

        -- Mock quality module that actually succeeds
        local mock_quality = {
          init = function()
            return true
          end,
          register_with_firmo = function() end,
        }

        -- Mock runner that succeeds
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
          end,
        }

        -- Install mocks
        mock_module("lib.coverage", mock_coverage)
        mock_module("lib.quality", mock_quality)
        mock_module("lib.core.runner", mock_runner)

        -- Capture output
        start_capture_output()

        -- Run CLI with coverage and quality flags
        local mock_firmo = create_mock_firmo()
        local result = cli.run({
          "--coverage",
          "--quality",
          "./tests",
        }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Coverage failure is not fatal, so the CLI should still run quality and tests
        expect(result).to.equal(true, "CLI should continue even if coverage fails to initialize")

        -- Now test with multiple failing modules

        -- Mock discover module that fails
        local mock_discover = {
          discover = function()
            return nil, "Failed to discover tests: IO error"
          end,
        }

        -- Install new mock
        mock_module("lib.tools.discover", mock_discover)

        -- Capture output
        start_capture_output()

        -- Run CLI again
        result = cli.run({
          "--coverage",
          "--quality",
          "./tests",
        }, mock_firmo)

        -- Get output
        output = stop_capture_output()

        -- This time it should fail because discover is critical
        expect(result).to.equal(false, "CLI should fail when discover module fails")
      end)

      it("verifies that --json output format works correctly", function()
        -- Create mock modules
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            return {
              success = true,
              passes = 5,
              errors = 0,
              skipped = 1,
              elapsed = 0.123,
              files = { "test1.lua", "test2.lua" },
              files_tested = 2,
              files_passed = 2,
              files_failed = 0,
            }
          end,
        }

        local json_encoded = nil
        local mock_json = {
          encode = function(data)
            json_encoded = data
            return '{"success":true,"passes":5,"errors":0}'
          end,
        }

        mock_module("lib.core.runner", mock_runner)
        mock_module("lib.tools.json", mock_json)

        -- Capture output
        start_capture_output()

        -- Run CLI with json flag
        local mock_firmo = create_mock_firmo()
        local result = cli.run({
          "--json",
          "./tests",
        }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Should succeed
        expect(result).to.equal(true, "CLI should succeed with --json flag")

        -- Check JSON encoding
        expect(json_encoded).to.be.a("table", "CLI should pass test results to JSON encoder")
        expect(json_encoded.success).to.equal(true, "JSON should include success status")
        expect(json_encoded.passes).to.equal(5, "JSON should include passes count")

        -- Check output format
        local json_markers_found = 0
        for _, line in ipairs(output) do
          if line == "RESULTS_JSON_BEGIN" or line == "RESULTS_JSON_END" then
            json_markers_found = json_markers_found + 1
          end
        end
        expect(json_markers_found).to.equal(2, "Output should include JSON markers")
      end)

      it("handles missing required modules gracefully", function()
        -- Mock try_require to simulate missing core module
        local original_try_require = cli.try_require

        -- Get access to the internal try_require function
        local try_require_found = false
        local i = 1
        while true do
          local name, val = debug.getupvalue(cli.run, i)
          if not name then
            break
          end
          if name == "try_require" and type(val) == "function" then
            cli.try_require = val
            try_require_found = true
            break
          end
          i = i + 1
        end

        -- If we couldn't get the function, create a mock that simulates a missing module
        if not try_require_found then
          cli.try_require = function(module_name)
            if module_name == "lib.core.runner" then
              return nil
            end
            return original_try_require and original_try_require(module_name) or require(module_name)
          end
        end

        -- Capture output
        start_capture_output()

        -- Run CLI, which should fail due to missing runner module
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "./tests" }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Restore original function if we saved it
        if original_try_require then
          cli.try_require = original_try_require
        end

        -- Should return false for missing module
        expect(result).to.equal(false, "CLI should return false when a required module is missing")

        -- Should output error message
        local error_message_found = false
        for _, line in ipairs(output) do
          if line:match("Runner module not loaded") then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message about missing module should be displayed")
      end)
    end)
  end)
end)
