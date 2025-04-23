---@class firmo
---@field version string Version string from lib.core.version (read-only)
---@field level number Current depth level of test blocks for nested test structures
---@field passes number Number of passing tests in the current run
---@field errors number Number of failing tests in the current run
---@field skipped number Number of skipped tests in the current run
---@field befores table Setup hooks at each nesting level for test initialization
---@field afters table Teardown hooks at each nesting level for test cleanup
---@field active_tags table Tags being used for test filtering when using tag-based filtering
---@field current_tags table Tags for the current test block in the nesting hierarchy
---@field filter_pattern string|nil Pattern for filtering test names by regex pattern
---@field focus_mode boolean Whether any focused tests exist in the test suite
---@field async_options table Configuration options for async testing (timeout, interval, etc.)
---@field config table|nil Central configuration if available through central_config module
---@field _current_test_context table|nil Current test context for temp file tracking integration
---@field test_results table|nil Structured test results for reporting and analysis
---@field describe fun(name: string, fn: function, options?: {focused?: boolean, excluded?: boolean, _parent_focused?: boolean, tags?: string[]}): nil Create a test group that can contain nested tests and other groups
---@field fdescribe fun(name: string, fn: function): nil Create a focused test group (only focused tests will run)
---@field xdescribe fun(name: string, fn: function): nil Create a skipped test group (none of the contained tests will run)
---@field it fun(name: string, options_or_fn: table|function, fn?: function): nil Create a test case with optional configuration
---@field fit fun(name: string, options_or_fn: table|function, fn?: function): nil Create a focused test case (only focused tests will run)
---@field xit fun(name: string, options_or_fn: table|function, fn?: function): nil Create a skipped test case (will not run but reports as skipped)
---@field before fun(fn: function): nil Add a setup hook for the current test block that runs before each test
---@field after fun(fn: function): nil Add a teardown hook for the current test block that runs after each test
---@field pending fun(message?: string): string Mark a test as pending with an optional explanation message
---@field expect fun(value: any): ExpectChain Create an assertion chain that allows chaining various assertions
---@field assert table Backward compatibility assertion interface for older tests (deprecated)
---@field tags fun(...: string): firmo Set tags for the current describe block or test for filtering
---@field nocolor fun(): nil Disable colors in the output for CI environments or logs
---@field only_tags fun(...: string): firmo Filter tests to run only those with specified tags
---@field set_filter fun(pattern: string): firmo Set a pattern filter for test names
---@field discover fun(dir?: string, pattern?: string): table, table|nil Discover test files in a directory
---@field run_file fun(file: string): table, table|nil Run a single test file with full lifecycle management
---@field run_discovered fun(dir?: string, pattern?: string): boolean, table|nil Run all discovered test files
---@field cli_run fun(args?: table): boolean Run tests from command line arguments with options
---@field report fun(name?: string, options?: table): table Generate a test report in various formats
---@field reset fun(): nil Reset the test state completely for a fresh test run
---@field get_current_test_context fun(): table|nil Get the current test context for temp file tracking
---@field get_structured_results fun(): table Get structured test results for reporting
---@field get_coverage fun(): table|nil Get code coverage data for tests (when coverage module is loaded)
---@field get_quality fun(): table|nil Get quality metrics for tests (when quality module is loaded)
---@field watch fun(dir: string, pattern?: string): nil Watch for file changes and run tests automatically
---@field mock fun(target: table, method_or_options?: string|table, impl_or_value?: any): table|nil, table|nil Create a mock object or method
---@field spy fun(target: table|function, method?: string): table|nil, table|nil Create a spy on an object method or function
---@field stub fun(value_or_fn?: any): table|nil, table|nil Create a stub that returns a value or executes a function
---@field with_mocks fun(fn: function): any Execute a function with automatic mock cleanup
---@field async fun(fn: function): function Convert a function to one that can be executed asynchronously
---@field await fun(ms: number): nil Wait for a specified time in milliseconds
---@field wait_until fun(condition: function, timeout?: number, check_interval?: number): boolean Wait until a condition is true or timeout occurs
---@field parallel_async fun(operations: table, timeout?: number): table Run multiple async operations concurrently
---@field configure_async fun(options: {timeout?: number, interval?: number}): firmo Configure async testing options

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
local error_handler = require("lib.tools.error_handler")
local assertion = require("lib.assertion")

--- Safely require a module without raising an error if it doesn't exist
---@param name string The name of the module to require
---@return table|nil The loaded module or nil if it couldn't be loaded
local function try_require(name)
  ---@diagnostic disable-next-line: unused-local
  local success, mod, err = error_handler.try(function()
    return require(name)
  end)

  if success then
    return mod
  else
    -- Only log errors for modules that should exist but failed to load
    -- (Don't log errors for optional modules that might not exist)
    if name:match("^lib%.") then
      -- This is an internal module that should exist
      local logger = error_handler.get_logger and error_handler.get_logger() or nil
      -- We can't use the centralized logger here because this function runs before
      -- we load the logger module. This would create a circular dependency, so we
      -- need to keep the conditional check in this specific place.
      if logger then
        logger.warn("Failed to load module", {
          module = name,
          error = error_handler.format_error(mod),
        })
      end
    end
    return nil
  end
end

-- Load filesystem module (required for basic operations)
local fs = try_require("lib.tools.filesystem")
if not fs then
  error_handler.throw(
    "Required module 'lib.tools.filesystem' could not be loaded",
    error_handler.CATEGORY.CONFIGURATION,
    error_handler.SEVERITY.FATAL,
    { module = "firmo" }
  )
end

-- Load logging module (required for proper error reporting)
local logging = try_require("lib.tools.logging")
if not logging then
  error_handler.throw(
    "Required module 'lib.tools.logging' could not be loaded",
    error_handler.CATEGORY.CONFIGURATION,
    error_handler.SEVERITY.FATAL,
    { module = "firmo" }
  )
end

-- Load version module
local version = try_require("lib.core.version")
if not version then
  error_handler.throw(
    "Required module 'lib.core.version' could not be loaded",
    error_handler.CATEGORY.CONFIGURATION,
    error_handler.SEVERITY.FATAL,
    { module = "firmo" }
  )
end

---@diagnostic disable-next-line: need-check-nil
local logger = logging.get_logger("firmo-core")

-- Import required modules for modular architecture
local test_definition = try_require("lib.core.test_definition")
local cli_module = try_require("lib.tools.cli")
local discover_module = try_require("lib.tools.discover")
local runner_module = try_require("lib.core.runner")
local coverage = try_require("lib.coverage")
local quality = try_require("lib.quality")
local codefix = try_require("lib.tools.codefix")
local reporting = try_require("lib.reporting")
local watcher = try_require("lib.tools.watcher")
local json = try_require("lib.reporting.json")
local type_checking = try_require("lib.core.type_checking")
local async_module = try_require("lib.async")
local interactive = try_require("lib.tools.interactive")
local parallel_module = try_require("lib.tools.parallel")
-- Load mocking module for spy, stub and mock functionality
local mocking_module = try_require("lib.mocking")
-- Use central_config for configuration
local central_config = try_require("lib.core.central_config")
local module_reset_module = try_require("lib.core.module_reset")

-- Configure logging (now a required component)
local success, err = error_handler.try(function()
  ---@diagnostic disable-next-line: need-check-nil
  logging.configure_from_config("firmo-core")
end)

if not success then
  local context = {
    module = "firmo-core",
    operation = "configure_logging",
  }

  -- Log warning but continue - configuration might fail but logging still works
  logger.warn("Failed to configure logging", {
    error = error_handler.format_error(err),
    context = context,
  })
end

logger.debug("Logging system initialized", {
  module = "firmo-core",
  modules_loaded = {
    error_handler = error_handler ~= nil,
    filesystem = fs ~= nil,
    logging = logging ~= nil,
    version = version ~= nil,
    assertion = assertion ~= nil,
    test_definition = test_definition ~= nil,
    cli = cli_module ~= nil,
    discover = discover_module ~= nil,
    runner = runner_module ~= nil,
    coverage = coverage ~= nil,
    quality = quality ~= nil,
    codefix = codefix ~= nil,
    reporting = reporting ~= nil,
    watcher = watcher ~= nil,
    async = async_module ~= nil,
    interactive = interactive ~= nil,
    parallel = parallel_module ~= nil,
    mocking = mocking_module ~= nil,
    central_config = central_config ~= nil,
    module_reset = module_reset_module ~= nil,
    type_checking = type_checking ~= nil,
    json = json ~= nil,
  },
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
  --- Synchronize test state fields from test_definition module to firmo table
  ---@return nil
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

  -- Configure the async module with our options
  if firmo.async_options and firmo.async_options.timeout then
    async_module.set_timeout(firmo.async_options.timeout)
  end
else
  -- Define stub functions for when the module isn't available
  --- Error function that throws when async functions are called without the async module
  ---@return nil Never returns, always throws an error
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
      error = error_handler.format_error(err),
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

  -- Export interactive mode
  interactive = interactive,

  --- Global exposure utility for easier test writing
  ---@return firmo The firmo module
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
  ---@param _ table The module itself
  ---@param ... any Arguments passed to the module
  ---@return firmo The firmo module
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

-- Try to load temp_file_integration if available
local temp_file_integration_loaded, temp_file_integration = pcall(require, "lib.tools.filesystem.temp_file_integration")
if temp_file_integration_loaded and temp_file_integration then
  -- Initialize the temp file integration system
  logger.info("Initializing temp file integration system")

  -- Initialize integration with explicit firmo instance
  temp_file_integration.initialize(firmo)

  -- Add getter/setter for current test context
  --- Get the current test context for temp file tracking
  ---@return table|nil The current test context or nil if not set
  firmo.get_current_test_context = function()
    return firmo._current_test_context
  end

  --- Set the current test context for temp file tracking
  ---@param context table|nil The test context to set
  ---@return nil
  firmo.set_current_test_context = function(context)
    firmo._current_test_context = context
  end
else
  logger.debug("Temp file integration not available", {
    reason = "Module not loaded or not found",
    status = "using fallback cleanup",
  })
end

return module
