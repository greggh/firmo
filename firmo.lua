--- Firmo Test Framework Main Module
--- @module firmo
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.7.6

local _FIRMO_HAS_BEEN_RUN_AS_MAIN = _FIRMO_HAS_BEEN_RUN_AS_MAIN

local error_handler
local function get_error_handler()
  if not error_handler then
    error_handler = require("lib.tools.error_handler")
  end
  return error_handler
end
local function try_require(module_name)
  local s, r = pcall(require, module_name)
  if not s then
    print("Warning: Failed to load module:", module_name, "Error:", r)
    return nil
  end
  return r
end

local assertion = require("lib.assertion")

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
  "lib.core.type_checking",
  "lib.async",
  "lib.reporting",
  "lib.tools.interactive",
  "lib.tools.parallel",
  "lib.mocking",
  "lib.core.central_config",
  "lib.core.module_reset",
  "lib.tools.filesystem.temp_file_integration",
}
local fs, logging, version, test_definition, cli_module, discover_module, runner_module, coverage, quality, codefix, parser, json, watcher, type_checking, async_module, temp_file_integration, reporting, interactive, parallel_module, mocking_module, central_config, module_reset_module
local loaded_modules_status = {}
for _, mn in ipairs(essential_modules) do
  local mod = try_require(mn)
  if mn == "lib.tools.filesystem" then
    fs = mod
  elseif mn == "lib.tools.logging" then
    logging = mod
  elseif mn == "lib.core.version" then
    version = mod
  elseif mn == "lib.core.test_definition" then
    test_definition = mod
  elseif mn == "lib.tools.cli" then
    cli_module = mod
  elseif mn == "lib.tools.discover" then
    discover_module = mod
  elseif mn == "lib.core.runner" then
    runner_module = mod
  elseif mn == "lib.coverage" then
    coverage = mod
  elseif mn == "lib.quality" then
    quality = mod
  elseif mn == "lib.tools.codefix" then
    codefix = mod
  elseif mn == "lib.tools.parser" then
    parser = mod
  elseif mn == "lib.tools.json" then
    json = mod
  elseif mn == "lib.tools.watcher" then
    watcher = mod
  elseif mn == "lib.core.type_checking" then
    type_checking = mod
  elseif mn == "lib.async" then
    async_module = mod
  elseif mn == "lib.reporting" then
    reporting = mod
  elseif mn == "lib.tools.interactive" then
    interactive = mod
  elseif mn == "lib.tools.parallel" then
    parallel_module = mod
  elseif mn == "lib.mocking" then
    mocking_module = mod
  elseif mn == "lib.core.central_config" then
    central_config = mod
  elseif mn == "lib.core.module_reset" then
    module_reset_module = mod
  elseif mn == "lib.tools.filesystem.temp_file_integration" then
    temp_file_integration = mod
  end
  loaded_modules_status[mn] = mod ~= nil
end

local logger = logging and logging.get_logger("firmo-core")
  or {
    debug = function() end,
    info = function(...)
      print("[INFO] firmo-core:", ...)
    end,
    error = function(...)
      print("[ERROR] firmo-core:", ...)
    end,
  }
logger.debug(
  "Firmo core init done",
  { version = version and version.string or "?", modules_count = #essential_modules }
)

local firmo = { version = version and version.string or "unknown" }
firmo.level, firmo.passes, firmo.errors, firmo.skipped = 0, 0, 0, 0
firmo.befores, firmo.afters = {}, {}
firmo.active_tags, firmo.current_tags = {}, {}
firmo.filter_pattern, firmo.focus_mode = nil, false
firmo._current_test_context = nil
firmo.async_options = { timeout = 5000 }
if central_config then
  firmo.config = central_config
  central_config.load_from_file()
  central_config.register_module("firmo", { field_types = { version = "string" } }, { version = firmo.version })
end

if test_definition then
  firmo.describe, firmo.fdescribe, firmo.xdescribe =
    test_definition.describe, test_definition.fdescribe, test_definition.xdescribe
  firmo.it, firmo.fit, firmo.xit = test_definition.it, test_definition.fit, test_definition.xit
  firmo.before, firmo.after, firmo.pending = test_definition.before, test_definition.after, test_definition.pending
  firmo.tags, firmo.only_tags, firmo.filter_pattern, firmo.reset =
    test_definition.tags, test_definition.only_tags, test_definition.filter_pattern, test_definition.reset
  local function sync_state()
    local s = test_definition.get_state()
    firmo.level, firmo.passes, firmo.errors, firmo.skipped, firmo.focus_mode =
      s.level, s.passes, s.errors, s.skipped, s.focus_mode
  end
  sync_state()
else
  logger.error("Test definition module not available.")
end

firmo.expect = assertion.expect
if runner_module then
  firmo.run_file, firmo.run_discovered, firmo.nocolor, firmo.format =
    runner_module.run_file, runner_module.run_discovered, runner_module.nocolor, runner_module.format
end
if discover_module then
  firmo.discover = discover_module.discover
end
if cli_module then
  firmo.parse_args, firmo.show_help, firmo.cli_run = cli_module.parse_args, cli_module.show_help, cli_module.run
end

if async_module then
  firmo.async, firmo.it_async, firmo.await, firmo.wait_until, firmo.parallel_async, firmo.fit_async, firmo.xit_async, firmo.describe_async, firmo.fdescribe_async, firmo.xdescribe_async, firmo.configure_async =
    async_module.async,
    async_module.it_async,
    async_module.await,
    async_module.wait_until,
    async_module.parallel_async,
    async_module.fit_async,
    async_module.xit_async,
    async_module.describe_async,
    async_module.fdescribe_async,
    async_module.xdescribe_async,
    async_module.configure
  if firmo.async_options and firmo.async_options.timeout then
    async_module.set_timeout(firmo.async_options.timeout)
  end
else
  local function async_err()
    error("Async module not available.", 2)
  end
  firmo.async, firmo.it_async, firmo.await, firmo.wait_until, firmo.parallel_async =
    async_err, async_err, async_err, async_err, async_err
end

if codefix then
  codefix.register_with_firmo(firmo)
end
if parallel_module then
  parallel_module.register_with_firmo(firmo)
end
if mocking_module then
  logger.info("Integrating mocking module with firmo", { mocking_version = mocking_module._VERSION })
  firmo.spy, firmo.stub, firmo.mock, firmo.with_mocks =
    mocking_module.spy, mocking_module.stub, mocking_module.mock, mocking_module.with_mocks
end

local module = setmetatable({
  firmo = firmo,
  version = firmo.version,
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
  parse_args = firmo.parse_args,
  show_help = firmo.show_help,
  spy = firmo.spy,
  stub = firmo.stub,
  mock = firmo.mock,
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
  interactive = interactive,
  expose_globals = function()
    _G.describe, _G.fdescribe, _G.xdescribe, _G.it, _G.fit, _G.xit, _G.before, _G.after =
      firmo.describe, firmo.fdescribe, firmo.xdescribe, firmo.it, firmo.fit, firmo.xit, firmo.before, firmo.after
    _G.expect, _G.pending = firmo.expect, firmo.pending
    _G.firmo = { assert = firmo.assert }
    _G.assert = firmo.assert
    if firmo.spy then
      _G.spy, _G.stub, _G.mock = firmo.spy, firmo.stub, firmo.mock
    end
    if async_module then
      _G.async, _G.it_async, _G.await, _G.wait_until = firmo.async, firmo.it_async, firmo.await, firmo.wait_until
    end
    _G.version = firmo.version
    return firmo
  end,
}, { __index = firmo })

if module_reset_module then
  module_reset_module.register_with_firmo(firmo)
end
if temp_file_integration and temp_file_integration.initialize then
  logger.info("Initializing temp file integration system")
  temp_file_integration.initialize(firmo)
end
firmo.get_current_test_context = function()
  return firmo._current_test_context
end
firmo.set_current_test_context = function(ctx)
  firmo._current_test_context = ctx
end

if not _G._FIRMO_MAIN_EXECUTED_FLAG then
  _G._FIRMO_MAIN_EXECUTED_FLAG = true
  local si = debug.getinfo(1, "S")
  local main_exec = (
    si
    and (
      si.source == "=(command line)"
      or (_G.arg and _G.arg[0] and _G.arg[0]:match("firmo%.lua$") and si.source:match("firmo%.lua$"))
    )
  )
  if main_exec and _G.arg then
    if cli_module and cli_module.run then
      if logging and logging.get_logger then
        logging.get_logger("firmo.lua"):debug("[FIRMO_LUA] Calling cli_module.run", { args_count = #(_G.arg or {}) })
      end
      local suc = cli_module.run(_G.arg, module)
      os.exit(suc and 0 or 1)
    elseif not cli_module then
      print("[FIRMO_LUA_ERROR] CRITICAL: cli_module is NIL.")
      if _G.arg then
        for k, v in pairs(_G.arg) do
          print("  ARG[" .. tostring(k) .. "]=" .. tostring(v))
        end
      end
      os.exit(1)
    else
      print("[FIRMO_LUA_ERROR] CRITICAL: cli_module.run is NIL.")
      if _G.arg then
        for k, v in pairs(_G.arg) do
          print("  ARG[" .. tostring(k) .. "]=" .. tostring(v))
        end
      end
      os.exit(1)
    end
  end
end
return module
