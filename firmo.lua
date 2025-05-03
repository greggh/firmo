--- Firmo Test Framework Main Module
---
--- This is the main entry point for the Firmo testing framework. It provides a comprehensive
--- set of functions for defining, running, and reporting on tests in Lua projects.
--- Firmo supports BDD-style nested test blocks, a fluent assertion API, setup/teardown
--- hooks, mocking, asynchronous testing, code coverage, and more.
---
--- @module firmo
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.7.5

---@class firmo
---@field version string Version string from `lib.core.version` (read-only).
---@field level number Current nesting level of `describe` blocks. Internal state.
---@field passes number Count of passing tests in the current run. Internal state.
---@field errors number Count of failing tests in the current run. Internal state.
---@field skipped number Count of skipped tests in the current run. Internal state.
---@field befores table Table storing `before` hooks per nesting level. Internal state.
---@field afters table Table storing `after` hooks per nesting level. Internal state.
---@field active_tags table Table storing tags currently being filtered for. Internal state.
---@field current_tags table Table storing tags applied to the current `describe` block. Internal state.
---@field filter_pattern string|nil Lua pattern used to filter tests by name. Internal state.
---@field focus_mode boolean Flag indicating if any focused tests/suites (`fit`/`fdescribe`) exist. Internal state.
---@field async_options table Configuration options for the async module (e.g., `{timeout = 5000}`).
---@field config table|nil Reference to the `lib.core.central_config` module instance, if loaded.
---@field _current_test_context table|nil Internal context for the currently running test or file (used by temp file integration).
---@field test_results table|nil Structured results gathered during the test run. Internal state, accessed via `get_structured_results`.
---@field describe fun(name: string, fn: function, options?: {focused?: boolean, excluded?: boolean, _parent_focused?: boolean, tags?: string[]}): nil Defines a test group (suite) that can contain tests (`it`) and nested groups.
---@field fdescribe fun(name: string, fn: function): nil Defines a focused test group. If any focused groups/tests exist, only they will be run.
---@field xdescribe fun(name: string, fn: function): nil Defines a skipped test group. All tests and hooks within this group will be skipped.
---@field it fun(name: string, options_or_fn: table|function, fn?: function): nil Defines an individual test case. Can accept options like `{focus=true, tags={...}}` or just the test function.
---@field fit fun(name: string, options_or_fn: table|function, fn?: function): nil Defines a focused test case. If any focused groups/tests exist, only they will be run.
---@field xit fun(name: string, options_or_fn: table|function, fn?: function): nil Defines a skipped test case. It will not be run but will be reported as skipped.
---@field before fun(fn: function): nil Registers a setup function to run before each test within the current `describe` block and any nested blocks.
---@field after fun(fn: function): nil Registers a teardown function to run after each test within the current `describe` block and any nested blocks.
---@field pending fun(message?: string): string Marks a test case (`it`) as pending (not yet implemented or temporarily disabled). Throws a specific error to signal this state.
---@field expect fun(value: any): ExpectChain Starts an assertion chain for the given value. See `lib.assertion` for available matchers.
---@field assert table Deprecated. Provides a basic `assert.equals` function for limited backward compatibility. Use `expect()` instead.
---@field tags fun(...: string): firmo Applies one or more string tags to the current `describe` block. Used for filtering tests via `only_tags`.
---@field nocolor fun(): nil Disables ANSI color codes in the runner's output. Useful for CI logs.
---@field only_tags fun(...: string): firmo Sets tags for filtering. Only tests belonging to `describe` blocks matching *all* of these tags will run.
---@field set_filter fun(pattern: string): firmo Deprecated. Sets a Lua pattern to filter tests by name. Use `cli_run` with `--pattern` argument instead.
---@field discover fun(dir?: string, pattern?: string): table, table|nil Discovers test files matching a pattern within a directory (uses `lib.tools.discover`).
---@field run_file fun(file: string): table, table|nil Runs tests defined in a single file (uses `lib.core.runner`).
---@field run_discovered fun(dir?: string, pattern?: string): boolean, table|nil Discovers and runs all test files matching a pattern (uses `lib.core.runner`).
---@field cli_run fun(args?: table): boolean Parses command-line arguments and runs tests accordingly (uses `lib.tools.cli`). Main entry point for `test.lua`.
---@field report fun(name?: string, options?: table): table Generates test reports in various formats (depends on `lib.reporting` module).
---@field reset fun(): nil Resets the internal state of the test framework (`passes`, `errors`, `hooks`, etc.) (uses `lib.core.test_definition`).
---@field get_current_test_context fun(): table|nil Gets the context object for the currently running test (used by `lib.tools.filesystem.temp_file_integration`).
---@field get_structured_results fun(): table Gets the raw, structured test results collected during the run (used by `lib.reporting`).
---@field get_coverage fun(): table|nil Gets code coverage data collected during the run (depends on `lib.coverage` module).
---@field get_quality fun(): table|nil Gets test quality metrics calculated during the run (depends on `lib.quality` module).
---@field watch fun(dir: string, pattern?: string): nil Starts file watching mode to automatically re-run tests on changes (depends on `lib.tools.watcher` module).
---@field mock fun(target: table, method_or_options?: string|table, impl_or_value?: any): table|nil, table|nil Creates a mock object or replaces methods with mocks (depends on `lib.mocking` module).
---@field spy fun(target: table|function, method?: string): table|nil, table|nil Creates a spy on a function or object method to track calls (depends on `lib.mocking` module).
---@field stub fun(value_or_fn?: any): table|nil, table|nil Creates a stub function that returns a value or executes a given function (depends on `lib.mocking` module).
---@field with_mocks fun(fn: function): any Executes a function and automatically cleans up any mocks created within it (depends on `lib.mocking` module).
---@field async fun(fn: function): function Wraps a function to run in a managed coroutine, enabling `await` and `wait_until` (depends on `lib.async` module).
---@field it_async fun(fn: function): function Wraps a function to run in a managed coroutine, enabling `await` and `wait_until` (depends on `lib.async` module).
---@field await fun(ms: number): nil Pauses execution within an `async` function for a specified duration (uses `lib.async`).
---@field wait_until fun(condition: function, timeout?: number, check_interval?: number): boolean Pauses execution within an `async` function until a condition returns true or a timeout occurs (uses `lib.async`).
---@field parallel_async fun(operations: table, timeout?: number): table Runs multiple async operations concurrently within an `async` function (uses `lib.async`).
---@field fit_async fun(description: string, options_or_fn: table|function, fn?: function, timeout_ms?: number): nil Defines a focused asynchronous test case using `firmo.fit`. Only focused tests run if any exist.
---@field xit_async fun(description: string, options_or_fn: table|function, fn?: function, timeout_ms?: number): nil Defines a skipped asynchronous test case using `firmo.xit`. It will not be run.
---@field describe_async fun(name: string, fn: function, options?: {focused?: boolean, excluded?: boolean}): nil Defines an asynchronous test group (suite) using `firmo.describe`. Tests inside can use async features.
---@field fdescribe_async fun(name: string, fn: function): nil Defines a focused asynchronous test group using `firmo.fdescribe`. Only focused suites/tests run if any exist.
---@field xdescribe_async fun(name: string, fn: function): nil Defines a skipped asynchronous test group using `firmo.xdescribe`. All tests inside will be skipped.
---@field configure_async fun(options: {timeout?: number, interval?: number}): firmo Configures global options for the async module (e.g., default timeout).

-- firmo v0.7.5 - Enhanced Lua test framework
-- https://github.com/greggh/firmo
-- MIT LICENSE
-- Based on lust by Bjorn Swenson (https://github.com/bjornbytes/lust)
--
-- Features:
-- * BDD-style nested test blocks (describe/it)
-- * Assertions with detailed error messages
-- * Setup and teardown with before/after hooks
-- * Advanced mocking and spying system
-- * Tag-based filtering for selective test execution
-- * Focus mode for running only specific tests (fdescribe/fit)
-- * Skip mode for excluding tests (xdescribe/xit)
-- * Asynchronous testing support
-- * Code coverage analysis and reporting
-- * Watch mode for continuous testing

-- Load required modules directly (without try/catch - these are required)
local error_handler
local assertion = require("lib.assertion") -- Assertion is critical, load directly

--- gets the error handler for the filesystem module
local function get_error_handler()
  if not error_handler then
    error_handler = require("lib.tools.error_handler")
  end
  return error_handler
end

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

-- Define essential modules required for Firmo core functionality
local essential_modules = {
  "lib.tools.filesystem",
  "lib.tools.logging",
  "lib.core.version",
  "lib.core.test_definition",
  "lib.tools.cli",
  "lib.tools.discover",
  "lib.core.runner",
  "lib.coverage",
  "lib.quality",
  "lib.tools.codefix",
  "lib.tools.parser",
  "lib.tools.json",
  "lib.tools.watcher",
  "lib.core.type_checking", -- Corrected path
  "lib.async",
  "lib.reporting",
  "lib.tools.interactive",
  "lib.tools.parallel",
  "lib.mocking",
  "lib.core.central_config",
  "lib.core.module_reset",
  "lib.tools.filesystem.temp_file_integration",
}

-- Local variables for loaded modules
local fs, logging, version, test_definition, cli_module, discover_module, runner_module
local coverage, quality, codefix, parser, json, watcher, type_checking, async_module, temp_file_integration
local reporting, interactive, parallel_module, mocking_module, central_config, module_reset_module

-- Load essential modules using the safe utility
local loaded_modules_status = {} -- Store status for logging
for _, module_name in ipairs(essential_modules) do
  local mod = try_require(module_name)

  -- Assign to specific local variables based on module name
  if module_name == "lib.tools.filesystem" then
    fs = mod
  elseif module_name == "lib.tools.logging" then
    logging = mod
  elseif module_name == "lib.core.version" then
    version = mod
  -- assertion is loaded directly above
  elseif module_name == "lib.core.test_definition" then
    test_definition = mod
  elseif module_name == "lib.tools.cli" then
    cli_module = mod
  elseif module_name == "lib.tools.discover" then
    discover_module = mod
  elseif module_name == "lib.core.runner" then
    runner_module = mod
  elseif module_name == "lib.coverage" then
    coverage = mod
  elseif module_name == "lib.quality" then
    quality = mod
  elseif module_name == "lib.tools.codefix" then
    codefix = mod
  elseif module_name == "lib.tools.parser" then
    parser = mod
  elseif module_name == "lib.tools.json" then
    json = mod
  elseif module_name == "lib.tools.watcher" then
    watcher = mod
  elseif module_name == "lib.core.type_checking" then
    type_checking = mod -- Corrected path
  elseif module_name == "lib.async" then
    async_module = mod
  elseif module_name == "lib.reporting" then
    reporting = mod
  elseif module_name == "lib.tools.interactive" then
    interactive = mod
  elseif module_name == "lib.tools.parallel" then
    parallel_module = mod
  elseif module_name == "lib.mocking" then
    mocking_module = mod
  elseif module_name == "lib.core.central_config" then
    central_config = mod
  elseif module_name == "lib.core.module_reset" then
    module_reset_module = mod
  elseif module_name == "lib.tools.filesystem.temp_file_integration" then
    temp_file_integration = mod
  end
  loaded_modules_status[module_name] = true -- Mark as loaded successfully
end

-- Configure logging (MUST happen after logging module is loaded)
---@diagnostic disable-next-line: need-check-nil
local logger = logging.get_logger("firmo-core")

-- Log initial status and loaded modules
logger.debug("Firmo core initialization complete", {
  module = "firmo-core",
  firmo_version = version and version.string or "unknown",
  modules_loaded = loaded_modules_status, -- Use the status table from the loop
})

-- Initialize the firmo table
local firmo = {}
---@diagnostic disable-next-line: need-check-nil
firmo.version = version.string

-- Set up core state
firmo.level = 0
firmo.passes = 0
firmo.errors = 0
firmo.skipped = 0
firmo.befores = {}
firmo.afters = {}
firmo.active_tags = {}
firmo.current_tags = {}
firmo.filter_pattern = nil
firmo.focus_mode = false
firmo._current_test_context = nil

-- Default configuration for modules
firmo.async_options = {
  timeout = 5000, -- Default timeout in ms
}

-- Store reference to configuration in firmo if available
if central_config then
  firmo.config = central_config

  -- Try to load default configuration if it exists
  central_config.load_from_file()

  -- Register firmo core with central_config
  central_config.register_module("firmo", {
    field_types = {
      version = "string",
    },
  }, {
    version = firmo.version,
  })
end

-- Forward test definition functions if available
if test_definition then
  -- Test definition functions
  firmo.describe = test_definition.describe
  firmo.fdescribe = test_definition.fdescribe
  firmo.xdescribe = test_definition.xdescribe
  firmo.it = test_definition.it
  firmo.fit = test_definition.fit
  firmo.xit = test_definition.xit

  -- Test lifecycle hooks
  firmo.before = test_definition.before
  firmo.after = test_definition.after
  firmo.pending = test_definition.pending

  -- Test organization
  firmo.tags = test_definition.tags
  firmo.only_tags = test_definition.only_tags
  firmo.filter_pattern = test_definition.filter_pattern

  -- Test state management
  firmo.reset = test_definition.reset

  -- Sync the state fields
  --- Synchronizes internal state fields (counters, flags) from the `test_definition` module
  --- to the main `firmo` table for exposure via the API.
  --- Called internally after test definition functions update the state.
  ---@return nil
  ---@private
  local function sync_state()
    local state = test_definition.get_state()
    firmo.level = state.level
    firmo.passes = state.passes
    firmo.errors = state.errors
    firmo.skipped = state.skipped
    firmo.focus_mode = state.focus_mode
  end

  -- Call sync_state periodically or when needed
  sync_state()
else
  logger.error("Test definition module not available", {
    message = "Basic test functionality will not work",
    module = "firmo",
  })
end

-- Forward assertion functions
firmo.expect = assertion.expect

-- Forward test execution functions if available
if runner_module then
  -- Test execution
  firmo.run_file = runner_module.run_file
  firmo.run_discovered = runner_module.run_discovered
  firmo.nocolor = runner_module.nocolor
  firmo.format = runner_module.format
end

-- Forward test discovery functions if available
if discover_module then
  firmo.discover = discover_module.discover
end

-- Forward CLI functions if available
if cli_module then
  firmo.parse_args = cli_module.parse_args
  firmo.show_help = cli_module.show_help
  firmo.cli_run = cli_module.run
end

-- Export async functions if the module is available
if async_module then
  -- Import core async functions with type annotations
  firmo.async = async_module.async
  firmo.it_async = async_module.it_async
  firmo.await = async_module.await
  firmo.wait_until = async_module.wait_until
  firmo.parallel_async = async_module.parallel_async
  firmo.fit_async = async_module.fit_async
  firmo.xit_async = async_module.xit_async
  firmo.describe_async = async_module.describe_async
  firmo.fdescribe_async = async_module.fdescribe_async
  firmo.xdescribe_async = async_module.xdescribe_async
  firmo.configure_async = async_module.configure -- Expose configure

  -- Configure the async module with our options
  if firmo.async_options and firmo.async_options.timeout then
    async_module.set_timeout(firmo.async_options.timeout)
  end
else
  -- Define stub functions for when the module isn't available
  --- Placeholder function that throws an error when an async feature is used but the `lib.async` module is not available.
  ---@return nil This function never returns normally.
  ---@throws string Always throws an error indicating the async module is missing.
  ---@private
  local function async_error()
    error("Async module not available. Make sure lib/async.lua exists.", 2)
  end

  firmo.async = async_error
  firmo.it_async = async_error
  firmo.await = async_error
  firmo.wait_until = async_error
  firmo.parallel_async = async_error
end

-- Register codefix module if available
if codefix then
  codefix.register_with_firmo(firmo)
end

-- Register parallel execution module if available
if parallel_module then
  parallel_module.register_with_firmo(firmo)
end

-- Register mocking functionality if available
if mocking_module then
  logger.info("Integrating mocking module with firmo", {
    module = "firmo-core",
    mocking_version = mocking_module._VERSION,
  })

  -- Export mocking functions
  firmo.spy = mocking_module.spy
  firmo.stub = mocking_module.stub
  firmo.mock = mocking_module.mock
  firmo.with_mocks = mocking_module.with_mocks

  -- Add required assertion functions (be_truthy, be_falsy)
  local success, err = mocking_module.ensure_assertions(firmo)
  if not success then
    logger.warn("Failed to register mocking assertions", {
      error = get_error_handler().format_error(err),
      module = "firmo-core",
    })
  end
end

--- Create a module that can be required
---@type firmo
local module = setmetatable({
  ---@type firmo
  firmo = firmo,
  version = firmo.version,

  -- Export the main functions directly
  describe = firmo.describe,
  fdescribe = firmo.fdescribe,
  xdescribe = firmo.xdescribe,
  it = firmo.it,
  fit = firmo.fit,
  xit = firmo.xit,
  before = firmo.before,
  after = firmo.after,
  pending = firmo.pending,
  expect = firmo.expect,
  tags = firmo.tags,
  only_tags = firmo.only_tags,
  reset = firmo.reset,

  -- Export CLI functions
  parse_args = firmo.parse_args,
  show_help = firmo.show_help,

  -- Export mocking functions if available
  spy = firmo.spy,
  stub = firmo.stub,
  mock = firmo.mock,

  -- Export async functions
  async = firmo.async,
  it_async = firmo.it_async,
  await = firmo.await,
  wait_until = firmo.wait_until,
  parallel_async = firmo.parallel_async,
  fit_async = firmo.fit_async,
  xit_async = firmo.xit_async,
  describe_async = firmo.describe_async,
  fdescribe_async = firmo.fdescribe_async,
  xdescribe_async = firmo.xdescribe_async,
  configure_async = firmo.configure_async,

  -- Export interactive mode
  interactive = interactive,

  --- Global exposure utility for easier test writing
  --- Exports core Firmo functions (describe, it, expect, etc.) to the global namespace (`_G`).
  --- Makes test writing more concise by avoiding the need for `firmo.` prefixes.
  --- Use with caution as it pollutes the global namespace.
  ---@return firmo The `firmo` module instance (for potential chaining, though unlikely here).
  expose_globals = function()
    -- Test building blocks
    _G.describe = firmo.describe
    _G.fdescribe = firmo.fdescribe
    _G.xdescribe = firmo.xdescribe
    _G.it = firmo.it
    _G.fit = firmo.fit
    _G.xit = firmo.xit
    _G.before = firmo.before
    _G.after = firmo.after

    -- Assertions
    _G.expect = firmo.expect
    _G.pending = firmo.pending

    -- Expose firmo.assert namespace and global assert for convenience
    _G.firmo = { assert = firmo.assert }
    _G.assert = firmo.assert

    -- Mocking utilities
    if firmo.spy then
      _G.spy = firmo.spy
      _G.stub = firmo.stub
      _G.mock = firmo.mock
    end

    -- Async testing utilities
    if async_module then
      _G.async = firmo.async
      _G.it_async = firmo.it_async
      _G.await = firmo.await
      _G.wait_until = firmo.wait_until
    end

    _G.version = firmo.version

    return firmo
  end,

  -- Main entry point when called
  ---@diagnostic disable-next-line: unused-vararg
  --- Metamethod allowing the module table to be called like a function.
  --- Determines if Firmo is being run directly from the command line (e.g., `lua firmo.lua ...`)
  --- or being required (`require("firmo")`).
  --- If run directly, it invokes the CLI handler. If required, it returns the `firmo` API table.
  ---@param _ table The module table itself (conventionally ignored).
  ---@param ... any Command-line arguments if run directly via `lua firmo.lua ...`.
  ---@return firmo The `firmo` API table if required as a module. This function calls `os.exit` if run directly.
  ---@private Used internally to control module execution behavior.
  __call = function(_, ...)
    -- Check if we are running tests directly or just being required
    local info = debug.getinfo(2, "S")
    local is_main_module = info and (info.source == "=(command line)" or info.source:match("firmo%.lua$"))

    if is_main_module and arg then
      -- Simply forward to CLI module if available
      if cli_module then
        local success = cli_module.run(arg)
        os.exit(success and 0 or 1)
      else
        logger.error("CLI module not available", {
          message = "Cannot run tests from command line",
          module = "firmo",
        })
        print("Error: CLI module not available. Make sure lib/tools/cli.lua exists.")
        os.exit(1)
      end
    end

    -- When required as module, just return the module
    return firmo
  end,
}, {
  __index = firmo,
})

-- Register module reset functionality if available
-- This must be done after all methods (including reset) are defined
if module_reset_module then
  module_reset_module.register_with_firmo(firmo)
end

-- Initialize the temp file integration system
logger.info("Initializing temp file integration system")

-- Initialize integration with explicit firmo instance
temp_file_integration.initialize(firmo)

-- Add getter/setter for current test context
--- Gets the context object for the currently running test or file.
--- Used by the temp file integration (`lib.tools.filesystem.temp_file_integration`)
--- to associate temporary files with specific tests for automatic cleanup.
--- The context is typically set by the test runner.
---@return table|nil context The context object (e.g., `{type="test", name="...", file="..."}` or `{type="file", file="..."}`), or `nil` if no context is set.
firmo.get_current_test_context = function()
  return firmo._current_test_context
end

--- Sets the context object for the currently running test or file.
--- Called internally by the test runner or other framework components.
---@param context table|nil The context object to set, or `nil` to clear the context.
---@return nil
---@private Should only be called by internal Firmo modules like the runner or temp file integration.
firmo.set_current_test_context = function(context)
  firmo._current_test_context = context
end

return module
