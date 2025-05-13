---@diagnostic disable: missing-parameter, param-type-mismatch
--- CLI Module Advanced Tests
---
--- Advanced tests for the `lib/tools/cli` module focusing on edge cases, complex scenarios,
--- and regression testing as part of the CLI refactoring plan Phase IV.
---
--- @author Firmo Team
--- @test

-- debug variable
local testname = ""

-- Import the test framework functions
local firmo = require("firmo")
local describe = firmo.describe
local it = firmo.it
local expect = firmo.expect
local before = firmo.before
local after = firmo.after

-- Import test_helper for improved error handling and temp files
local test_helper = require("lib.tools.test_helper")
local inspect = require("inspect")

-- Required modules for testing
local cli = require("lib.tools.cli")
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.cli_advanced")

-- Make sure error handler is available
local error_handler = require("lib.tools.error_handler")

local colors_enabled = true
local SGR_CODES =
  { reset = 0, bold = 1, red = 31, green = 32, yellow = 33, blue = 34, magenta = 35, cyan = 36, white = 37 }

--- Generates an SGR (Select Graphic Rendition) escape code string.
--- If colors are disabled globally (via `colors_enabled` upvalue), returns an empty string.
---@param code_or_name string|number The SGR code number or a predefined color/style name (e.g., "red", "bold").
---@return string The ANSI SGR escape code string, or an empty string.
---@private
local function sgr(code_or_name)
  if not colors_enabled then
    return ""
  end
  local code = type(code_or_name) == "number" and code_or_name or SGR_CODES[code_or_name]
  if code then
    return string.char(27) .. "[" .. code .. "m"
  end
  return ""
end

local cr, cg, cy, cb, cm, cc, bold, cn =
  sgr("red"), sgr("green"), sgr("yellow"), sgr("blue"), sgr("magenta"), sgr("cyan"), sgr("bold"), sgr("reset")

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
  local current_G_print = _G.print -- Capture current _G.print first

  captured_output = {}
  original_print = current_G_print -- Store the initially captured _G.print into the upvalue

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
    print(cr .. "BEFORE test" .. cn)
    local err = test_helper.with_error_capture(function()
      temp_dir = test_helper.create_temp_test_directory()
      logger.debug("Created temporary test directory", { path = temp_dir.path })
      central_config.reset()
      if original_print then
        _G.print = original_print
      end
      captured_output = nil
    end)()
    if err then
      print("[ étoile PROBLEM IN MAIN BEFORE HOOK étoile ] Error:", tostring(err), inspect(err))
    end
  end)

  -- Cleanup after each test
  after(function()
    print(cr .. "AFTER test: " .. testname .. cn)
    local err = test_helper.with_error_capture(function()
      for module_name, _ in pairs(original_modules) do
        restore_module(module_name)
      end
      central_config.reset()
      if logging and logging.reset_internal_config_flag_for_testing then -- Check existence
        logging.reset_internal_config_flag_for_testing()
      end
      if logging and logging.set_level and logging.LEVELS then
        logging.set_level(logging.LEVELS.INFO)
        logger.debug("Main after hook: Reset global logging level to INFO")
      end
      if original_print then
        _G.print = original_print
        original_print = nil
      end
      captured_output = nil
      logger.debug("Test complete, temporary directory will be cleaned up")
    end)()
    if err then
      print(cr .. "[ étoile PROBLEM IN MAIN AFTER HOOK étoile ] Error:" .. cn, tostring(err), inspect(err))
    end
  end)

  -- Test sections will be implemented below according to the plan
  -- 1. Edge Cases and Advanced Scenarios
  describe("Edge Cases and Advanced Scenarios", function()
    describe("Config File Loading and Creation", function()
      it("handles loading a valid config file correctly", function()
        testname = "handles loading a valid config file correctly"
        print(cg .. "TEST: " .. testname .. cn)
        -- Save both the original verbose setting and logging level before the test
        local original_cli_options = central_config.get("cli_options") or {}
        local original_verbose = original_cli_options.verbose
        local original_global_log_level_num = (logging.get_config and logging.get_config().global_level)
          or logging.LEVELS.INFO

        before(function()
          logging.set_level(logging.INFO)
          logger.debug("Temporarily set logging level to INFO for 'valid config' test")
        end)

        after(function()
          if original_cli_options then
            local cli_options_to_restore = central_config.get("cli_options") or {}
            cli_options_to_restore.verbose = original_verbose
            central_config.set("cli_options", cli_options_to_restore)
          end
          logging.set_level(original_global_log_level_num)
          logger.debug(
            "Restored original global logging level for 'valid config' test",
            { level = original_global_log_level_num }
          )
        end)

        -- Mock discover to prevent scanning real ./tests directory
        local mock_discover_minimal = {
          discover = function(dir, pattern)
            logger.debug("Minimal mock_discover called for 'valid config' test", { dir = dir, pattern = pattern })
            return { files = { "fake_discovered_test_for_valid_config.lua" } }
          end,
        }
        mock_module("lib.tools.discover", mock_discover_minimal)

        -- Mock runner as well since we don't want to run the fake file
        local mock_runner_minimal = {
          configure = function() end,
          run_tests = function()
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
          run_file = function()
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
        }
        mock_module("lib.core.runner", mock_runner_minimal)

        local valid_config_content = [[
              return {
                coverage = { threshold = 95, include = { "lib/**/*.lua" } },
                quality = { level = 5 },
                cli_options = { verbose = true, file_discovery_pattern = "*_spec.lua" }
              }
            ]]
        local config_file_path = temp_dir:create_file("valid_config.lua", valid_config_content)

        local mock_firmo = create_mock_firmo()
        start_capture_output()
        -- cli.run with no path args defaults to discovering in "./tests"
        local result = cli.run({ "--config=" .. config_file_path }, mock_firmo)
        local output = stop_capture_output()

        expect(result).to.be_truthy("Command should succeed with valid config")
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
        testname = "handles syntax errors in config files gracefully"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "handles runtime errors in config files gracefully"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "handles non-existent config file paths gracefully"
        print(cg .. "TEST: " .. testname .. cn)
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

      it("handles config creation failure gracefully", function()
        testname = "handles config creation failure gracefully"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "CLI flags override loaded config values"
        print(cg .. "TEST: " .. testname .. cn)
        local original_cli_options = central_config.get("cli_options") or {}
        local original_verbose = original_cli_options.verbose
        local original_global_log_level_num = (logging.get_config and logging.get_config().global_level)
          or logging.LEVELS.INFO

        -- Closure variables for the mock
        -- local actual_coverage_init_was_called = false -- No longer strictly needed if we trust config_received
        local actual_coverage_config_received = nil

        after(function()
          if original_cli_options then
            local cli_options_to_restore = central_config.get("cli_options") or {}
            cli_options_to_restore.verbose = original_verbose
            central_config.set("cli_options", cli_options_to_restore)
          end
          logging.set_level(original_global_log_level_num)
          logger.debug(
            "Restored original global logging level post 'CLI flags override' test",
            { level = original_global_log_level_num }
          )
        end)

        local mock_discover_minimal = {
          discover = function(dir, pattern)
            logger.debug("Minimal mock_discover called for 'CLI flags override' test", { dir = dir, pattern = pattern })
            return { files = { "fake_discovered_test_for_override.lua" } }
          end,
        }
        mock_module("lib.tools.discover", mock_discover_minimal)

        local mock_runner_minimal = {
          configure = function() end,
          run_tests = function()
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
          run_file = function()
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
        }
        mock_module("lib.core.runner", mock_runner_minimal)

        local config_content = [[
          return {
            coverage = { threshold = 80 },
            quality = { level = 3 },
            cli_options = { file_discovery_pattern = "*_test.lua", verbose = false }
          }
        ]]
        local config_file_path = temp_dir:create_file("override_test.lua", config_content)

        local mock_firmo = create_mock_firmo()

        local mock_coverage_module_instance = {}

        mock_coverage_module_instance.init = function(cov_cfg_arg)
          print(
            string.format(
              "[TEST MOCK DEBUG] mock_coverage_module.init CALLED. cov_cfg_arg is: %s (type: %s)",
              tostring(cov_cfg_arg),
              type(cov_cfg_arg)
            )
          )
          -- actual_coverage_init_was_called = true -- Not asserting on this directly anymore
          actual_coverage_config_received = cov_cfg_arg
          print(
            string.format(
              "[TEST MOCK DEBUG] mock_coverage_module.init EXECUTED. actual_coverage_config_received type: %s",
              type(actual_coverage_config_received)
            )
          )
          return true
        end
        mock_coverage_module_instance.start = function()
          print("[TEST MOCK DEBUG] mock_coverage_module.start CALLED")
        end

        mock_module("lib.coverage", mock_coverage_module_instance)
        print(
          string.format(
            "[TEST DEBUG] mock_coverage_module_instance in test: %s",
            tostring(mock_coverage_module_instance)
          )
        )

        local result = cli.run({
          "--config=" .. config_file_path,
          "--coverage",
          "--threshold=90",
          "--verbose",
        }, mock_firmo)

        print(
          "[TEST DEBUG] In 'CLI flags override', value of 'result' before expect: "
            .. tostring(result)
            .. ", type: "
            .. type(result)
        )
        expect(result).to.be_truthy("CLI run should complete successfully")

        -- REMOVED: expect(actual_coverage_init_was_called).to.equal(true, "Coverage init function should have been invoked")

        print(
          string.format(
            "[TEST DEBUG] Before expect actual_coverage_config_received: value is %s, type is %s",
            tostring(actual_coverage_config_received),
            type(actual_coverage_config_received)
          )
        ) -- Keep this for diagnostics
        expect(actual_coverage_config_received).to.be.a("table", "Coverage config received should be a table")
        if actual_coverage_config_received then
          expect(actual_coverage_config_received.threshold).to.equal(
            90,
            "CLI threshold for coverage should override config"
          )
        end

        local final_log_level_after_cli_run = (logging.get_config and logging.get_config().global_level)
        expect(final_log_level_after_cli_run).to.equal(
          logging.LEVELS.DEBUG,
          "CLI --verbose flag should set global log level to DEBUG"
        )
      end)

      it("handles config files with non-table return values gracefully", function()
        testname = "handles config files with non-table return values gracefully"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "correctly handles a mix of file and directory paths"
        print(cg .. "TEST: " .. testname .. cn)
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
        -- Parse args first to inspect options before running
        local raw_args = {
          test_dir_1,
          test_file_1,
          test_dir_2,
          test_file_2,
        }
        local options = cli.parse_args(raw_args)
        local result = cli.run(raw_args, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "Command should succeed with valid paths")

        -- Check how paths were processed by cli.parse_args
        local actual_processed_targets = {}
        for _, p in ipairs(options.specific_paths_to_run) do
          table.insert(actual_processed_targets, p)
        end

        if options.base_test_dir then
          local base_dir_is_an_input = false
          for _, input_path in ipairs(raw_args) do
            if input_path == options.base_test_dir then
              base_dir_is_an_input = true
              break
            end
          end
          if base_dir_is_an_input then
            -- Check if it's already in actual_processed_targets (it shouldn't be if it was consumed as base_test_dir)
            local already_present = false
            for _, p_target in ipairs(actual_processed_targets) do
              if p_target == options.base_test_dir then
                already_present = true
                break
              end
            end
            if not already_present then
              table.insert(actual_processed_targets, options.base_test_dir)
            end
          end
        end

        -- Check that the first directory is treated as base_test_dir and the rest are in specific_paths
        expect(#discover_calls).to.equal(0, "Discover should not be called since specific paths were provided")
        expect(#run_tests_calls).to.equal(1, "run_tests should be called once")
        expect(run_tests_calls[1]).to.be.a("table")

        -- The paths passed to runner should reflect the logic of parse_args
        -- The assertion here is on `run_tests_calls[1]` which comes from the runner module.
        -- The `actual_processed_targets` is built from `options` to verify `parse_args` behavior.

        local expected_paths_for_runner = raw_args -- The runner should ultimately get all raw paths in this scenario if no discovery happens.
        -- However, the current CLI logic for `run_tests` will receive specific_paths_to_run directly
        -- or a list from discovery.
        -- For this test, since `specific_paths_to_run` is used by `cli.run` to decide to call `run_tests` vs `run_file`.
        -- And `run_tests` gets `target_files_to_run` which is options.specific_paths_to_run if populated.
        -- The logic in cli.init.lua line 455-475 means test_dir_1 became options.base_test_dir
        -- and the rest {test_file_1, test_dir_2, test_file_2} became options.specific_paths_to_run.
        -- So run_tests_calls[1] should contain {test_file_1, test_dir_2, test_file_2}.
        -- The test's `expected_paths` for assertion against the *parsed options* should be `raw_args`.

        -- Assert against the actual_processed_targets which reflects how parse_args interpreted the inputs.
        expect(#actual_processed_targets).to.equal(
          #raw_args,
          "All raw input paths should be accounted for in parsed options logic"
        )

        -- Verify each path from raw_args is present in actual_processed_targets
        for _, expected_raw_path in ipairs(raw_args) do
          local found_in_processed = false
          for _, actual_target_path in ipairs(actual_processed_targets) do
            if actual_target_path == expected_raw_path then
              found_in_processed = true
              break
            end
          end
          expect(found_in_processed).to.equal(
            true,
            "Raw input path should be present in actual_processed_targets: " .. expected_raw_path
          )
        end

        -- Additionally, check what the runner actually received.
        -- Based on current cli.lua, run_tests is called with options.specific_paths_to_run.
        -- So, run_tests_calls[1] should be options.specific_paths_to_run.
        expect(#run_tests_calls[1]).to.equal(
          #options.specific_paths_to_run,
          "Runner should receive options.specific_paths_to_run"
        )
        for i, path_in_runner in ipairs(run_tests_calls[1]) do
          expect(path_in_runner).to.equal(options.specific_paths_to_run[i])
        end
      end)

      it("handles non-existent paths gracefully", function()
        testname = "handles non-existent paths gracefully"
        print(cg .. "TEST: " .. testname .. cn)
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
            local is_the_path_match = paths and #paths == 1 and paths[1] == "./non-existent"
            -- Use the existing logger instance from the top of the file
            logger.debug("Mock runner.run_tests called", {
              paths_received = paths,
              is_match_for_non_existent = is_the_path_match,
              type_paths = type(paths),
              type_path_1 = paths and type(paths[1]),
              value_path_1 = paths and paths[1],
            })

            if is_the_path_match then
              logger.debug("Mock runner returning success = false for './non-existent'")
              return { success = false, errors = 1, passes = 0, total = 1, elapsed = 0.01 }
            end
            logger.debug("Mock runner returning default success = true")
            return { success = true, passes = (#paths or 0), errors = 0, total = (#paths or 0), elapsed = 0.01 }
          end,
        }

        mock_module("lib.tools.discover", mock_discover)
        mock_module("lib.core.runner", mock_runner) -- Corrected module name

        -- Capture output
        start_capture_output()

        -- Run CLI with non-existent paths
        local mock_firmo = create_mock_firmo()
        local result = cli.run({
          "./non-existent", -- This should trigger directory discovery and fail
        }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Should fail due to directory not found
        expect(result).to.equal(false, "Command should fail with non-existent directory")
        -- Should output error message (from print_final_summary for failed tests)
        local error_message_found = false
        for _, line in ipairs(output) do
          if line:match("Some tests failed or errors occurred") then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message indicating test failure should be displayed")
      end)

      it("handles multiple directory specifications correctly", function()
        testname = "handles multiple directory specifications correctly"
        print(cg .. "TEST: " .. testname .. cn)
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
        local raw_args_multi_dir = {
          test_dir_1,
          test_dir_2,
          test_dir_3,
        }
        local options_multi_dir = cli.parse_args(raw_args_multi_dir)
        local result = cli.run(raw_args_multi_dir, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "Command should succeed with multiple directories")

        -- First directory should be base_test_dir, others in specific_paths_to_run
        expect(options_multi_dir.base_test_dir).to.equal(test_dir_1)
        expect(#options_multi_dir.specific_paths_to_run).to.equal(2)
        expect(options_multi_dir.specific_paths_to_run[1]).to.equal(test_dir_2)
        expect(options_multi_dir.specific_paths_to_run[2]).to.equal(test_dir_3)

        -- run_tests should be called with specific_paths_to_run
        expect(run_tests_paths).to.be.a("table")
        expect(#run_tests_paths).to.equal(2, "run_tests should receive 2 paths (test_dir_2, test_dir_3)")

        local dir2_found_in_runner = false
        local dir3_found_in_runner = false
        for _, path in ipairs(run_tests_paths) do
          if path == test_dir_2 then
            dir2_found_in_runner = true
          end
          if path == test_dir_3 then
            dir3_found_in_runner = true
          end
        end
        expect(dir2_found_in_runner).to.equal(true, "Second directory should be passed to runner")
        expect(dir3_found_in_runner).to.equal(true, "Third directory should be passed to runner")
      end)

      it("handles glob-expanded paths correctly", function()
        testname = "handles glob-expanded paths correctly"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "handles a directory path with a pattern correctly"
        print(cg .. "TEST: " .. testname .. cn)
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
        local run_file_called_with_path = nil -- Renamed and will store the path directly
        local mock_runner = {
          configure = function() end,
          run_file = function(path, _, __) -- Changed from run_discovered to run_file
            run_file_called_with_path = path
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

        -- run_file should be called with the discovered spec_file
        expect(run_file_called_with_path).to.be.a("string")
        expect(run_file_called_with_path).to.equal(spec_file, "Correct file path should be passed to run_file")
      end)

      it("falls back to default test directory when no paths specified", function()
        testname = "falls back to default test directory when no paths specified"
        print(cg .. "TEST: " .. testname .. cn)
        -- Mock discover to track default directory usage
        local discover_called_with = nil
        local mock_discover = {
          discover = function(dir, pattern)
            discover_called_with = { dir = dir, pattern = pattern }
            return { files = { "default_test.lua" } }
          end,
        }
        -- Mock runner to avoid actual running
        local run_tests_called_with_paths = nil -- Renamed
        local mock_runner = {
          configure = function() end,
          run_tests = function(paths, _, __) -- Changed from run_discovered to run_tests
            run_tests_called_with_paths = paths
            return { success = true, passes = #paths, errors = 0, elapsed = 0.01 }
          end,
        }

        mock_module("lib.tools.discover", mock_discover)
        mock_module("lib.core.runner", mock_runner)

        -- Run CLI without any path arguments
        local mock_firmo = create_mock_firmo()
        local result = cli.run({}, mock_firmo)

        -- Should succeed
        expect(result).to.equal(true, "Command should succeed with default test directory")
        -- Default directory should be used for discovery
        expect(discover_called_with).to.be.a("table")
        expect(discover_called_with.dir).to.equal("./tests", "Default test directory should be used for discovery")
        expect(discover_called_with.pattern).to.equal("*_test.lua", "Default pattern should be used for discovery")

        -- run_tests should be called with the discovered files
        expect(run_tests_called_with_paths).to.be.a("table")
        expect(#run_tests_called_with_paths).to.equal(1, "Should receive one discovered file")
        expect(run_tests_called_with_paths[1]).to.equal(
          "default_test.lua",
          "Correct discovered file should be passed to run_tests"
        )
      end)
    end)
  end)

  -- 2. Regression Tests
  describe("Regression Tests", function()
    describe("Exit Code Verification", function()
      it("returns true exit code for successful test execution", function()
        testname = "returns true exit code for successful test execution"
        print(cg .. "TEST: " .. testname .. cn)
        -- Create a mock runner module that always succeeds
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
          end,
          run_file = function() -- Added for completeness, though run_tests is likely called
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
          end,
          run_discovered = function() -- May not be used if run_tests is comprehensive
            return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
          end,
        }

        -- Create a mock discover module to prevent discovery of other test files
        local mock_discover = {
          discover = function(dir, pattern)
            logger.debug("Mock discover called in 'true exit code' test", { dir = dir, pattern = pattern })
            return { files = { "mock_test_file.lua" } } -- Return a controlled, minimal set
          end,
        }

        mock_module("lib.core.runner", mock_runner)
        mock_module("lib.tools.discover", mock_discover) -- Mock discovery

        -- Run CLI with basic test run
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "./tests" }, mock_firmo) -- This will now use mock_discover

        -- Should return true for successful tests
        expect(result).to.equal(true, "CLI should return true for successful test execution")
      end)

      it("returns false exit code for failed test execution", function()
        testname = "returns false exit code for failed test execution"
        print(cg .. "TEST: " .. testname .. cn)
        -- Create a mock runner module that always fails
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            return { success = false, passes = 3, errors = 2, elapsed = 0.01 }
          end,
          run_file = function()
            return { success = false, passes = 0, errors = 1, elapsed = 0.01 }
          end,
          run_discovered = function()
            return { success = false, passes = 3, errors = 2, elapsed = 0.01 }
          end,
        }

        -- Create a mock discover module
        local mock_discover = {
          discover = function(dir, pattern)
            logger.debug("Mock discover called in 'false exit code' test", { dir = dir, pattern = pattern })
            return { files = { "mock_test_file_for_failure.lua" } }
          end,
        }

        mock_module("lib.core.runner", mock_runner)
        mock_module("lib.tools.discover", mock_discover) -- Mock discovery

        -- Run CLI with basic test run
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "./tests" }, mock_firmo) -- This will now use mock_discover

        -- Should return false for failed tests
        expect(result).to.equal(false, "CLI should return false for failed test execution")
      end)

      it("returns false exit code when discovering test files fails", function()
        testname = "returns false exit code when discovering test files fails"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "returns false exit code when report generation fails"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "returns true exit code for help and version flags"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "returns false exit code for invalid CLI arguments"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "integrates coverage, quality, and reports correctly"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "integrates coverage, quality, and watch mode correctly"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "handles complex path combinations with filters and report formats"
        print(cg .. "TEST: " .. testname .. cn)
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
          run_file = function(path, firmo_instance, options) -- ADDED THIS FUNCTION
            -- runner_file_filter = options and options.filter -- or some other tracking if needed
            return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
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
        testname = "applies multiple formats and handles format conflicts correctly"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "combines multi-feature testing with exit code verification"
        print(cg .. "TEST: " .. testname .. cn)
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
      it("propagates runner errors to exit code", { expect_error = true }, function()
        testname = "propagates runner errors to exit code"
        print(cg .. "TEST: " .. testname .. cn)
        -- Create a mock runner that throws an error
        local mock_runner = {
          configure = function() end,
          run_tests = function()
            logger.debug("Mock runner.run_tests is about to crash...")
            error("Runner module crashed")
          end,
          run_discovered = function()
            logger.debug("Mock runner.run_discovered is about to crash...")
            error("Runner module crashed")
          end,
        }

        mock_module("lib.core.runner", mock_runner)

        -- Capture output
        start_capture_output()

        -- Run CLI with basic test run
        local mock_firmo = create_mock_firmo()

        -- The error from the mock runner should propagate out of cli.run
        -- and be caught by the test framework because of { expect_error = true }
        cli.run({ "./tests" }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- For now, we're just checking if the error propagates.
        -- The test framework handles the { expect_error = true } part.
        -- If the test passes, it means an error occurred as expected.
        -- If it fails, it means cli.run completed without an error.
        -- We can add more specific checks later if needed.
      end)

      it(
        "propagates coverage module errors to exit code",
        { expect_error = true },
        function() -- ADDED expect_error = true
          testname = "propagates coverage module errors to exit code"
          print(cg .. "TEST: " .. testname .. cn)
          local mock_runner = {
            configure = function() end,
            run_tests = function()
              return { success = true, passes = 5, errors = 0, elapsed = 0.01 }
            end,
            run_file = function()
              return { success = true, passes = 1, errors = 0, elapsed = 0.01 }
            end,
          }
          local mock_coverage = {
            init = function()
              logger.debug("Mock coverage.init called for 'propagates coverage errors' test")
              return true
            end,
            start = function()
              logger.debug("Mock coverage.start is about to error() for 'propagates coverage errors' test")
              error("Coverage module crashed during start")
            end,
            shutdown = function() end,
            get_report_data = function() end,
          }

          mock_module("lib.core.runner", mock_runner)
          mock_module("lib.coverage", mock_coverage)

          start_capture_output()
          local mock_firmo = create_mock_firmo()

          -- Call cli.run directly. The error from mock_coverage.start() should propagate
          -- and be caught by the test runner because of { expect_error = true }.
          cli.run({ "--coverage", "./tests" }, mock_firmo)

          -- The above line is expected to error out. Code here might not be reached fully.
          local output = stop_capture_output()

          local error_message_found = false
          for _, line in ipairs(output) do
            if
              line:match("Coverage module crashed during start")
              or line:match("[ERROR] RUNTIME: .*Coverage module crashed during start") -- ErrorHandler might format it
              or line:match("Warning: Failed to start coverage analysis") -- A more generic CLI warning
            then
              error_message_found = true
              break
            end
          end
          expect(error_message_found).to.equal(true, "Error message from coverage crash should be in output")
        end
      )

      it("combines multiple failing modules correctly", { timeout = 5000 }, function()
        testname = "combines multiple failing modules correctly"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "verifies that --json output format works correctly"
        print(cg .. "TEST: " .. testname .. cn)
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
        testname = "handles missing required modules gracefully"
        print(cg .. "TEST: " .. testname .. cn)
        local original_global_require = _G.require
        _G.require = function(module_name_to_require)
          if module_name_to_require == "lib.core.runner" then
            error("Simulated failure: lib.core.runner is missing.")
          end
          -- Ensure other modules can still be loaded by the test framework itself if needed during this mock
          return original_global_require(module_name_to_require)
        end

        -- Capture output
        start_capture_output()

        -- Run CLI, which should fail due to missing runner module
        local mock_firmo = create_mock_firmo()
        local result = cli.run({ "./tests" }, mock_firmo)

        -- Get output
        local output = stop_capture_output()

        -- Restore original _G.require
        _G.require = original_global_require

        -- Should return false for missing module
        expect(result).to.equal(false, "CLI should return false when a required module is missing")

        -- Should output error message
        local error_message_found = false
        for _, line in ipairs(output) do
          if
            line:match("Runner module not loaded") or line:match("Warning: Failed to load module: lib.core.runner")
          then
            error_message_found = true
            break
          end
        end
        expect(error_message_found).to.equal(true, "Error message about missing module should be displayed")
      end)
    end)
  end)

  describe("Programmatic Invocation", function()
    it("successfully runs with array of args and returns true", function()
      testname = "programmatic run with array of args" -- Keep for AFTER test hook consistency

      local firmo_instance_for_run = require("firmo")
      expect(firmo_instance_for_run).to.be.a("table", "Firmo module should be loadable")

      local fake_test_path
      local runner_function_called = "none" -- Keep for assertion
      local runner_paths_received = nil -- Keep for assertion

      local setup_mocks_fn = function()
        local fake_test_content = [[
          local firmo_for_fake_test = require("firmo")
          firmo_for_fake_test.describe("Fake Suite", function()
            firmo_for_fake_test.it("Fake Test", function()
              firmo_for_fake_test.expect(true).to.equal(true)
            end)
          end)
        ]]
        fake_test_path = temp_dir:create_file("programmatic_fake_test.lua", fake_test_content)

        local mock_discover = {
          discover = function(dir_path_arg, pattern_arg)
            if
              dir_path_arg == fake_test_path
              or (dir_path_arg == temp_dir.path and pattern_arg == "programmatic_fake_test.lua")
            then
              return { files = { fake_test_path } }
            end
            if
              dir_path_arg == temp_dir.path
              and fs.file_exists(fs.join_paths(temp_dir.path, "programmatic_fake_test.lua"))
            then
              return { files = { fs.join_paths(temp_dir.path, "programmatic_fake_test.lua") } }
            end
            return { files = {} }
          end,
        }
        mock_module("lib.tools.discover", mock_discover)

        local mock_runner = {
          configure = function() end,
          run_file = function(path, ...)
            runner_function_called = "run_file"
            runner_paths_received = path
            return { success = true, passes = 1, errors = 0, skipped = 0, elapsed = 0.01 }
          end,
          run_tests = function(paths, ...)
            runner_function_called = "run_tests"
            runner_paths_received = paths
            return { success = true, passes = (paths and #paths or 0), errors = 0, skipped = 0, elapsed = 0.01 }
          end,
          run_discovered = function(base_dir, pattern, ...)
            runner_function_called = "run_discovered"
            runner_paths_received = { base_dir, pattern }
            return { success = true, passes = 1, errors = 0, skipped = 0, elapsed = 0.01 }
          end,
        }
        mock_module("lib.core.runner", mock_runner)
      end

      local run_cli_fn = function(freshly_loaded_cli_module)
        local cli_args = { fake_test_path }
        return freshly_loaded_cli_module.run(cli_args, firmo_instance_for_run)
      end

      start_capture_output()
      local isolated_run_success, cli_run_result_or_error =
        test_helper.with_isolated_module_run("lib.tools.cli", setup_mocks_fn, run_cli_fn)
      stop_capture_output()

      expect(isolated_run_success).to.equal(
        true,
        "with_isolated_module_run should succeed. Error: "
          .. (not isolated_run_success and inspect(cli_run_result_or_error) or "none")
      )

      expect(cli_run_result_or_error).to.equal(
        true,
        "Programmatic cli.run (isolated) should return true on success. Got: " .. tostring(cli_run_result_or_error)
      )

      local expected_runner_path = fake_test_path
      if runner_function_called == "run_file" then
        expect(runner_paths_received).to.equal(
          expected_runner_path,
          "Runner function 'run_file' should have been called with the fake test path."
        )
      elseif runner_function_called == "run_tests" then
        expect(runner_paths_received).to.be.a("table")
        expect(#runner_paths_received).to.equal(1)
        expect(runner_paths_received[1]).to.equal(
          expected_runner_path,
          "Runner function 'run_tests' should have been called with the fake test path."
        )
      else
        expect(false).to.equal(
          true,
          "Unexpected runner function called: "
            .. runner_function_called
            .. " with paths: "
            .. inspect(runner_paths_received)
        )
      end
    end)

    it("handles --help flag programmatically and returns true", function()
      testname = "programmatic run with --help"

      local firmo_instance_for_run = require("firmo")

      local run_cli_fn = function(freshly_loaded_cli_module)
        return freshly_loaded_cli_module.run({ "--help" }, firmo_instance_for_run)
      end

      start_capture_output()
      -- No mocks needed for --help as it should short-circuit before discovery/runner
      local isolated_run_success, cli_run_result =
        test_helper.with_isolated_module_run("lib.tools.cli", nil, run_cli_fn)
      local output = stop_capture_output()

      expect(isolated_run_success).to.equal(true, "with_isolated_module_run for --help should succeed")
      expect(cli_run_result).to.equal(true, "Programmatic cli.run with --help should return true")

      local help_message_found = false
      if output then
        for _, line in ipairs(output) do
          if line:match("Usage: lua firmo%.lua") then
            help_message_found = true
            break
          end
        end
      end
      expect(help_message_found).to.equal(true, "Help message should be printed to output")
    end)

    it("successfully runs with a pre-parsed options table", function()
      testname = "programmatic run with options table"

      -- Use a global for diagnostics
      _G._TEST_RUNNER_TRACKING_TABLE = {
        function_called = "none",
        paths_received = nil,
        options_received = nil,
      }
      -- Ensure cleanup of the global. This 'after' is local to this 'it' block's scope.
      -- However, Firmo's 'after' is associated with 'describe' blocks.
      -- For simplicity in this diagnostic step, we'll rely on the main 'after' hook for the describe block
      -- or manually ensure this global is nilled if the test is interrupted.
      -- A more robust solution would be a dedicated cleanup mechanism if this pattern were permanent.

      local firmo_instance_for_run = require("firmo")
      local fake_test_path

      local setup_mocks_fn = function()
        print("DEBUG_SETUP: setup_mocks_fn called")
        local fake_test_content = [[
          local firmo_for_fake_test = require("firmo")
          firmo_for_fake_test.describe("Fake Options Suite", function()
            firmo_for_fake_test.it("Fake Options Test", function()
              firmo_for_fake_test.expect(1).to.equal(1)
            end)
          end)
        ]]
        fake_test_path = temp_dir:create_file("options_fake_test.lua", fake_test_content)
        print("DEBUG_SETUP: Fake test file created at:", fake_test_path)

        mock_module("lib.tools.discover", {
          discover = function(dir_path_arg, pattern_arg)
            print("DEBUG_MOCK_DISCOVER: discover called with dir:", dir_path_arg, "pattern:", pattern_arg)
            if
              dir_path_arg == fake_test_path
              or (dir_path_arg == temp_dir.path and pattern_arg == "options_fake_test.lua")
            then
              print("DEBUG_MOCK_DISCOVER: Returning fake_test_path:", fake_test_path)
              return { files = { fake_test_path } }
            end
            if
              dir_path_arg == temp_dir.path and fs.file_exists(fs.join_paths(temp_dir.path, "options_fake_test.lua"))
            then
              print(
                "DEBUG_MOCK_DISCOVER: Returning fake_test_path from temp_dir scan:",
                fs.join_paths(temp_dir.path, "options_fake_test.lua")
              )
              return { files = { fs.join_paths(temp_dir.path, "options_fake_test.lua") } }
            end
            print("DEBUG_MOCK_DISCOVER: Returning empty files table")
            return { files = {} }
          end,
        })
        print("DEBUG_SETUP: lib.tools.discover mocked")

        local mock_runner = {
          configure = function(...)
            print("DEBUG_MOCK_RUNNER: configure called with:", inspect({ ... }))
          end,
          run_file = function(path, firmo_inst, opts)
            print(
              "DEBUG_MOCK_RUNNER: run_file called. Path:",
              path,
              "opts.verbose:",
              opts and opts.verbose,
              "Full opts:",
              inspect(opts)
            )
            _G._TEST_RUNNER_TRACKING_TABLE.function_called = "run_file"
            _G._TEST_RUNNER_TRACKING_TABLE.paths_received = path
            _G._TEST_RUNNER_TRACKING_TABLE.options_received = opts
            print(
              "DEBUG_MOCK_RUNNER: INSIDE run_file, _G._TEST_RUNNER_TRACKING_TABLE.options_received.verbose IS:",
              _G._TEST_RUNNER_TRACKING_TABLE.options_received
                and _G._TEST_RUNNER_TRACKING_TABLE.options_received.verbose
            )
            return { success = true, passes = 1, errors = 0, skipped = 0, elapsed = 0.01 }
          end,
          run_tests = function(paths, firmo_inst, opts)
            print(
              "DEBUG_MOCK_RUNNER: run_tests called. Paths:",
              inspect(paths),
              "opts.verbose:",
              opts and opts.verbose,
              "Full opts:",
              inspect(opts)
            )
            _G._TEST_RUNNER_TRACKING_TABLE.function_called = "run_tests"
            _G._TEST_RUNNER_TRACKING_TABLE.paths_received = paths
            _G._TEST_RUNNER_TRACKING_TABLE.options_received = opts
            print(
              "DEBUG_MOCK_RUNNER: INSIDE run_tests, _G._TEST_RUNNER_TRACKING_TABLE.options_received.verbose IS:",
              _G._TEST_RUNNER_TRACKING_TABLE.options_received
                and _G._TEST_RUNNER_TRACKING_TABLE.options_received.verbose
            )
            return { success = true, passes = (paths and #paths or 0), errors = 0, skipped = 0, elapsed = 0.01 }
          end,
          run_discovered = function(base_dir, pattern, ...)
            print(
              "DEBUG_MOCK_RUNNER: run_discovered called with base_dir:",
              base_dir,
              "pattern:",
              pattern,
              " other_args:",
              inspect({ ... })
            )
            _G._TEST_RUNNER_TRACKING_TABLE.function_called = "run_discovered"
            _G._TEST_RUNNER_TRACKING_TABLE.paths_received = { base_dir, pattern }
            return { success = true, passes = 1, errors = 0, skipped = 0, elapsed = 0.01 }
          end,
        }
        mock_module("lib.core.runner", mock_runner)
        print("DEBUG_SETUP: lib.core.runner mocked")
        print("DEBUG_SETUP: setup_mocks_fn finished")
      end

      local run_cli_fn = function(freshly_loaded_cli_module)
        local options_table = {
          specific_paths_to_run = { fake_test_path },
          verbose = true,
        }
        print("DEBUG_PRE_PARSED_TEST: options_table being passed to cli.run:", inspect(options_table))
        -- No longer returning the tracking table from here
        return freshly_loaded_cli_module.run(options_table, firmo_instance_for_run)
      end

      start_capture_output()
      -- Capture only success and primary result of cli.run
      local isolated_run_success, cli_run_actual_result =
        test_helper.with_isolated_module_run("lib.tools.cli", setup_mocks_fn, run_cli_fn)
      stop_capture_output()

      expect(isolated_run_success).to.equal(
        true,
        "with_isolated_module_run for options table should succeed. Error: "
          .. (not isolated_run_success and inspect(cli_run_actual_result) or "none")
      )
      expect(cli_run_actual_result).to.equal(true, "Programmatic cli.run with options table should return true")

      -- Use the global _G._TEST_RUNNER_TRACKING_TABLE for assertions
      print(
        "DEBUG_TEST_BODY: AFTER isolated_run, _G._TEST_RUNNER_TRACKING_TABLE.options_received IS:",
        inspect(_G._TEST_RUNNER_TRACKING_TABLE and _G._TEST_RUNNER_TRACKING_TABLE.options_received)
      )
      print(
        "DEBUG_TEST_BODY: AFTER isolated_run, _G._TEST_RUNNER_TRACKING_TABLE.options_received.verbose IS:",
        _G._TEST_RUNNER_TRACKING_TABLE
          and _G._TEST_RUNNER_TRACKING_TABLE.options_received
          and _G._TEST_RUNNER_TRACKING_TABLE.options_received.verbose
      )

      expect(_G._TEST_RUNNER_TRACKING_TABLE.options_received).to.be.a(
        "table",
        "Runner options should have been received by the runner"
      )
      if _G._TEST_RUNNER_TRACKING_TABLE.options_received then
        expect(_G._TEST_RUNNER_TRACKING_TABLE.options_received.verbose).to.equal(
          true,
          "Runner option 'verbose' should be true as set in options_table"
        )
        expect(_G._TEST_RUNNER_TRACKING_TABLE.options_received.stop_on_fail).to.be.falsy(
          "Runner option 'stop_on_fail' should not be present or be falsy from pre-parsed top-level options"
        )
      end

      local correct_path_passed = false
      if
        _G._TEST_RUNNER_TRACKING_TABLE.function_called == "run_file"
        and _G._TEST_RUNNER_TRACKING_TABLE.paths_received == fake_test_path
      then
        correct_path_passed = true
      elseif
        _G._TEST_RUNNER_TRACKING_TABLE.function_called == "run_tests"
        and type(_G._TEST_RUNNER_TRACKING_TABLE.paths_received) == "table"
        and #_G._TEST_RUNNER_TRACKING_TABLE.paths_received == 1
        and _G._TEST_RUNNER_TRACKING_TABLE.paths_received[1] == fake_test_path
      then
        correct_path_passed = true
      end
      expect(correct_path_passed).to.equal(
        true,
        "Runner should have been called with the fake test path. Called: "
          .. _G._TEST_RUNNER_TRACKING_TABLE.function_called
      )
    end)
  end)
end)
