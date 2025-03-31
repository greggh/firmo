-- Module loader hook for v3 coverage system
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local instrumentation = require("lib.coverage.v3.instrumentation")
local path_mapping = require("lib.coverage.v3.path_mapping")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.loader.hook")

---@class coverage_v3_loader_hook
---@field install fun(): boolean Install module loader hook
---@field uninstall fun(): boolean Uninstall module loader hook
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Original loader functions
local original_loaders = {}

-- Track loading modules to handle circular dependencies
local loading_modules = {}

-- Temp directory for instrumented files
local temp_dir

-- Helper to ensure temp directory exists
local function ensure_temp_dir()
  if not temp_dir then
    temp_dir = test_helper.create_temp_test_directory()
    -- Create instrumented subdirectory
    fs.create_directory(fs.join_paths(temp_dir.path, "instrumented"))
  end
  return temp_dir
end

-- Helper to get module path from name
local function get_module_path(name)
  -- Convert module name to path
  local path = name:gsub("%.", "/")
  
  -- Try standard Lua paths
  local paths = {
    "./" .. path .. ".lua",
    path .. ".lua",
    path .. "/init.lua"
  }
  
  -- Try each path
  for _, p in ipairs(paths) do
    if fs.file_exists(p) then
      return fs.normalize_path(p)
    end
  end
  
  return nil
end

-- Module loader function
local function coverage_loader(name)
  -- Check if module is already being loaded (circular dependency)
  if loading_modules[name] then
    return nil, string.format("Circular dependency detected: %s", name)
  end
  
  -- Get module path
  local path = get_module_path(name)
  if not path then
    return nil
  end
  
  -- Mark module as being loaded
  loading_modules[name] = true
  
  -- Instrument the file
  local result, err = instrumentation.instrument_file(path)
  if not result then
    loading_modules[name] = nil
    return nil, err
  end
  
  -- Create loader function
  local loader, load_err = loadfile(result.instrumented_path)
  if not loader then
    loading_modules[name] = nil
    return nil, load_err
  end
  
  -- Module loaded successfully
  loading_modules[name] = nil
  
  logger.debug("Loaded and instrumented module", {
    name = name,
    path = path,
    instrumented_path = result.instrumented_path
  })
  
  return loader
end

-- Install module loader hook
function M.install()
  -- Create temp directory
  ensure_temp_dir()
  
  -- Save original loaders
  for i, loader in ipairs(package.loaders) do
    original_loaders[i] = loader
  end
  
  -- Insert our loader after the preload loader
  table.insert(package.loaders, 2, coverage_loader)
  
  logger.debug("Installed module loader hook")
  
  return true
end

-- Uninstall module loader hook
function M.uninstall()
  -- Restore original loaders
  for i, loader in ipairs(original_loaders) do
    package.loaders[i] = loader
  end
  
  -- Clear loading state
  loading_modules = {}
  
  -- Clear temp directory reference (cleanup handled by test_helper)
  temp_dir = nil
  
  logger.debug("Uninstalled module loader hook")
  
  return true
end

return M