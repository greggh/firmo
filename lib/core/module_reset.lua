--[[
Module Reset Functionality for Firmo

Provides enhanced test isolation by managing Lua's module cache (package.loaded).
This allows cleaning up module state between test runs for better isolation,
preventing test pollution, and identifying memory usage patterns.

Core functionality includes:
- Module state tracking and restoration
- Selective module reset by name or pattern
- Protection of critical modules from reset
- Memory usage analysis per module
- Integration with firmo's test lifecycle
]]

---@type ErrorHandler
local error_handler = require("lib.tools.error_handler")

---@class module_reset
---@field _VERSION string Version number following semantic versioning
---@field initial_state table<string, boolean>|nil Original snapshot of package.loaded on initialization
---@field protected_modules table<string, boolean> Registry of modules that should never be reset
---@field firmo table|nil Reference to the firmo instance for integration
---@field protect fun(modules: string|string[]): module_reset Add modules to the protected list to prevent resettingmodule
This sub-plan is documented in the docs/firmo/claude_document_update_plan.md
---@field count_protected_modules fun(): number Count the number of protected modules in the registry
---@field snapshot fun(): table<string, boolean>, number Take a snapshot of the current module state and return count
---@field init fun(): module_reset Initialize the module tracking system and capture initial state
---@field reset_all fun(options?: {verbose?: boolean, force?: boolean}): number Reset all non-protected modules to initial state
---@field reset_pattern fun(pattern: string, options?: {verbose?: boolean}): number Reset modules matching a Lua pattern string
---@field get_loaded_modules fun(): string[] Get list of currently loaded, non-protected modules
---@field get_memory_usage fun(): {current: number, count: number} Get current memory usage in kilobytes
---@field analyze_memory_usage fun(options?: {track_level?: string}): {name: string, memory: number}[] Calculate approximate memory usage per module
---@field is_protected fun(module_name: string): boolean Check if a specific module is protected from reset
---@field add_protected_module fun(module_name: string): boolean Add a single module to the protected list
---@field register_with_firmo fun(firmo: table): table Register this module with firmo and enhance firmo.reset()
---@field configure fun(options: {reset_modules?: boolean, verbose?: boolean, track_memory?: boolean}): table Configure isolation options for test runs

local module_reset = {}
module_reset._VERSION = "1.2.0"

-- Enhanced validation functions using error_handler
---@private
---@param value any Value to check for nil
---@param name string Name of the parameter for error message
---@return boolean true If value is not nil (throws error otherwise)
local function validate_not_nil(value, name)
  if value == nil then
    error_handler.throw(
      name .. " must not be nil",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      { parameter_name = name }
    )
  end
  return true
end

---@private
---@param value any Value to check type of
---@param expected_type string Expected type name
---@param name string Name of the parameter for error message
---@return boolean true If value is of expected type (throws error otherwise)
local function validate_type(value, expected_type, name)
  if type(value) ~= expected_type then
    error_handler.throw(
      name .. " must be of type '" .. expected_type .. "', got '" .. type(value) .. "'",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      {
        parameter_name = name,
        expected_type = expected_type,
        actual_type = type(value),
      }
    )
  end
  return true
end

---@private
---@param value any Value to check type of
---@param expected_type string Expected type name
---@param name string Name of the parameter for error message
---@return boolean true If value is nil or of expected type (throws error otherwise)
local function validate_type_or_nil(value, expected_type, name)
  if value ~= nil and type(value) ~= expected_type then
    error_handler.throw(
      name .. " must be of type '" .. expected_type .. "' or nil, got '" .. type(value) .. "'",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      {
        parameter_name = name,
        expected_type = expected_type,
        actual_type = type(value),
      }
    )
  end
  return true
end

-- Import logging directly
local logging = require("lib.tools.logging")
local logger = logging.get_logger("core.module_reset")

-- Initialize logger with configuration
local function init_logger()
  -- Configure the logger
  local config_success, config_err = error_handler.try(function()
    logging.configure_from_config("core.module_reset")
    return true
  end)

  if not config_success then
    -- Log error but continue
    print("[WARNING] Failed to configure module_reset logger: "
      .. error_handler.format_error(config_err))
  end

  logger.debug("Module reset system initialized", {
    version = module_reset._VERSION,
  })
end

-- Initialize logger immediately
init_logger()

-- Store original package.loaded state
module_reset.initial_state = nil

-- Store modules that should never be reset
module_reset.protected_modules = {
  -- Core Lua modules that should never be reset
  ["_G"] = true,
  ["package"] = true,
  ["coroutine"] = true,
  ["table"] = true,
  ["io"] = true,
  ["os"] = true,
  ["string"] = true,
  ["math"] = true,
  ["debug"] = true,
  ["bit32"] = true,
  ["utf8"] = true,

  -- Essential testing modules
  ["firmo"] = true,
}

---@param modules string|string[] Module name or array of module names to protect
-- Configure additional modules that should be protected
function module_reset.protect(modules)

  if type(modules) == "string" then
    logger.debug("Protecting single module", {
      module = modules,
    })
    module_reset.protected_modules[modules] = true
  elseif type(modules) == "table" then
    logger.debug("Protecting multiple modules", {
      count = #modules,
    })
    for _, module_name in ipairs(modules) do
      module_reset.protected_modules[module_name] = true
      logger.debug("Added module to protected list", {
        module = module_name,
      })
    end
  end

  logger.info("Module protection updated", {
    protected_count = module_reset.count_protected_modules(),
  })
end

---@return number count Number of protected modules
-- Helper function to count protected modules
function module_reset.count_protected_modules()
  local count = 0
  for _ in pairs(module_reset.protected_modules) do
    count = count + 1
  end
  return count
end

---@return table snapshot Table mapping module names to boolean (true)
-- Take a snapshot of the current module state
function module_reset.snapshot()
  local success, result = error_handler.try(function()
    local snapshot = {}
    local count = 0

    for module_name, _ in pairs(package.loaded) do
      snapshot[module_name] = true
      count = count + 1
    end

    logger.debug("Created module state snapshot", {
      module_count = count,
    })

    return snapshot, count
  end)

  if not success then
    local loaded_modules_count = 0
    if package and package.loaded and type(package.loaded) == "table" then
      for _ in pairs(package.loaded) do
        loaded_modules_count = loaded_modules_count + 1
      end
    end

    logger.error("Failed to create module state snapshot", {
      error = error_handler.format_error(result),
      loaded_modules_count = loaded_modules_count,
      protected_modules_count = module_reset.count_protected_modules(),
    })

    error_handler.rethrow(result, {
      operation = "module_reset.snapshot",
      module_version = module_reset._VERSION,
    })
  end

  return result
end

---@return module_reset The module instance for chaining
-- Initialize the module system (capture initial state)
function module_reset.init()
  local success, err = error_handler.try(function()
    logger.debug("Initializing module reset system")

    module_reset.initial_state = module_reset.snapshot()
    local initial_count = 0

    -- Also protect all modules already loaded at init time
    ---@diagnostic disable-next-line: param-type-mismatch
    for module_name, _ in pairs(module_reset.initial_state) do
      module_reset.protected_modules[module_name] = true
      initial_count = initial_count + 1
    end

    logger.info("Module reset system initialized", {
      initial_modules = initial_count,
      protected_modules = module_reset.count_protected_modules(),
    })
  end)

  if not success then
    logger.error("Failed to initialize module reset system", {
      error = error_handler.format_error(err),
      protected_modules_count = module_reset.count_protected_modules(),
      state = module_reset.initial_state ~= nil and "created" or "missing",
    })

    error_handler.rethrow(err, {
      operation = "module_reset.init",
      module_version = module_reset._VERSION,
    })
  end

  return module_reset
end

---@param options? table Options: { verbose?: boolean }
---@return number count Number of modules reset
-- Reset modules to initial state, excluding protected modules
function module_reset.reset_all(options)
  -- Validate options
  options = options or {}
  validate_type_or_nil(options, "table", "options")

  local verbose = options.verbose

  logger.debug("Resetting all modules", {
    verbose = verbose and true or false,
  })

  ---@diagnostic disable-next-line: unused-local
  local success, result, err = error_handler.try(function()
    -- If we haven't initialized, do so now
    if not module_reset.initial_state then
      logger.debug("Module reset system not initialized, initializing now")
      module_reset.init()
      return 0
    end

    local reset_count = 0
    local modules_to_reset = {}
    local total_modules = 0
    local protected_count = 0

    -- Collect modules that need to be reset
    for module_name, _ in pairs(package.loaded) do
      total_modules = total_modules + 1
      if not module_reset.protected_modules[module_name] then
        modules_to_reset[#modules_to_reset + 1] = module_name
      else
        protected_count = protected_count + 1
      end
    end

    if log then
      log.debug("Collected modules for reset", {
        total_loaded = total_modules,
        to_reset = #modules_to_reset,
        protected = protected_count,
      })
    end

    -- Actually reset the modules
    for _, module_name in ipairs(modules_to_reset) do
      package.loaded[module_name] = nil
      reset_count = reset_count + 1

      if verbose then
        if log then
          log.info("Reset module", {
            module = module_name,
          })
        else
          -- Safe printing with try/catch
          local print_success, _ = error_handler.try(function()
            print("Reset module: " .. module_name)
            return true
          end)

          ---@diagnostic disable-next-line: empty-block
          if not print_success then
            -- Cannot log if log is nil here, just silently fail
          end
        end
      end
    end

    -- Force garbage collection after resetting modules
    local before_gc = collectgarbage("count")
    collectgarbage("collect")
    local after_gc = collectgarbage("count")
    local memory_freed = before_gc - after_gc

    logger.info("Module reset completed", {
      reset_count = reset_count,
      memory_freed_kb = memory_freed > 0 and memory_freed or 0,
    })

    return reset_count
  end)

  if not success then
    local loaded_modules_count = 0
    if package and package.loaded and type(package.loaded) == "table" then
      for _ in pairs(package.loaded) do
        loaded_modules_count = loaded_modules_count + 1
      end
    end

    logger.error("Failed to reset modules", {
      error = error_handler.format_error(result),
      loaded_modules_count = loaded_modules_count,
      protected_modules_count = module_reset.count_protected_modules(),
      options = options ~= nil and type(options) == "table" and "provided" or "default",
    })

    ---@diagnostic disable-next-line: redundant-parameter
    error_handler.rethrow(result, {
      operation = "module_reset.reset_all",
      options = options or "default",
    })
  end

  return result
end

---@param pattern string Lua pattern to match module names against
---@param options? table Options: { verbose?: boolean }
---@return number count Number of modules reset
-- Reset specific modules by pattern
function module_reset.reset_pattern(pattern, options)
  -- Validate parameters
  validate_not_nil(pattern, "pattern")
  validate_type(pattern, "string", "pattern")

  options = options or {}
  validate_type_or_nil(options, "table", "options")

  local verbose = options.verbose

  logger.debug("Resetting modules by pattern", {
    pattern = pattern,
    verbose = verbose and true or false,
  })

  local success, result = error_handler.try(function()
    local reset_count = 0
    local modules_to_reset = {}
    local total_checked = 0
    local match_count = 0

    -- Collect matching modules
    for module_name, _ in pairs(package.loaded) do
      total_checked = total_checked + 1

      -- Safely check for pattern match
      local match_success, matches = error_handler.try(function()
        return module_name:match(pattern) ~= nil
      end)

      if not match_success then
        error_handler.throw(
          "Invalid pattern for module matching",
          error_handler.CATEGORY.VALIDATION,
          error_handler.SEVERITY.ERROR,
          { pattern = pattern, module = module_name }
        )
      end

      if matches then
        match_count = match_count + 1
        if not module_reset.protected_modules[module_name] then
          modules_to_reset[#modules_to_reset + 1] = module_name
        else
          logger.debug("Skipping protected module", {
            module = module_name,
            pattern = pattern,
          })
        end
      end
    end

    logger.debug("Collected modules for pattern reset", {
      pattern = pattern,
      total_checked = total_checked,
      matches = match_count,
      to_reset = #modules_to_reset,
    })

    -- Actually reset the modules
    for _, module_name in ipairs(modules_to_reset) do
      package.loaded[module_name] = nil
      reset_count = reset_count + 1

      if verbose then
        if log then
          log.info("Reset module", {
            module = module_name,
            pattern = pattern,
          })
        else
          -- Safe printing with try/catch
          local print_success, _ = error_handler.try(function()
            print("Reset module: " .. module_name)
            return true
          end)

          ---@diagnostic disable-next-line: empty-block
          if not print_success then
            -- Cannot log if log is nil here, just silently fail
          end
        end
      end
    end

    -- Conditional garbage collection
    if reset_count > 0 then
      local before_gc = collectgarbage("count")
      collectgarbage("collect")
      local after_gc = collectgarbage("count")
      local memory_freed = before_gc - after_gc

      if log then
        log.info("Pattern reset completed", {
          pattern = pattern,
          reset_count = reset_count,
          memory_freed_kb = memory_freed > 0 and memory_freed or 0,
        })
      end
    else
      if log then
        log.debug("No modules reset for pattern", {
          pattern = pattern,
        })
      end
    end

    return reset_count
  end)

  if not success then
    if log then
      local loaded_modules_count = 0
      if package and package.loaded and type(package.loaded) == "table" then
        for _ in pairs(package.loaded) do
          loaded_modules_count = loaded_modules_count + 1
        end
      end

      log.error("Failed to reset modules by pattern", {
        pattern = pattern,
        error = error_handler.format_error(result),
        loaded_modules_count = loaded_modules_count,
        protected_modules_count = module_reset.count_protected_modules(),
        options = options ~= nil and type(options) == "table" and "provided" or "default",
      })
    end

    error_handler.rethrow(result, {
      operation = "module_reset.reset_pattern",
      pattern = pattern,
      options = options or "default",
    })
  end

  return result
end

---@return string[] module_names List of loaded, non-protected module names
-- Get list of currently loaded modules
function module_reset.get_loaded_modules()

  local success, result = error_handler.try(function()
    local modules = {}
    local total_loaded = 0
    local non_protected = 0

    for module_name, _ in pairs(package.loaded) do
      total_loaded = total_loaded + 1
      if not module_reset.protected_modules[module_name] then
        table.insert(modules, module_name)
        non_protected = non_protected + 1
      end
    end

    table.sort(modules)

    if log then
      log.debug("Retrieved loaded modules list", {
        total_loaded = total_loaded,
        non_protected = non_protected,
      })
    end

    return modules
  end)

  if not success then
    if log then
      log.error("Failed to retrieve loaded modules list", {
        error = error_handler.format_error(result),
        protected_modules_count = module_reset.count_protected_modules(),
      })
    end

    error_handler.rethrow(result, {
      operation = "module_reset.get_loaded_modules",
      module_version = module_reset._VERSION,
    })
  end

  return result
end

---@return table info Memory usage information { current: number, count: number }
-- Get memory usage information
function module_reset.get_memory_usage()

  local success, result = error_handler.try(function()
    local current_mem = collectgarbage("count")

    logger.debug("Retrieved memory usage", {
      current_kb = current_mem,
    })

    return {
      current = current_mem, -- Current memory in KB
      count = 0, -- Will be calculated below
    }
  end)

  if not success then
    if log then
      log.error("Failed to retrieve memory usage", {
        error = error_handler.format_error(result),
        operation = "get_memory_usage",
      })
    end

    ---@diagnostic disable-next-line: redundant-parameter
    error_handler.rethrow(result, {
      operation = "module_reset.get_memory_usage",
      module_version = module_reset._VERSION,
    })
  end

  return result
end

---@param options? table Options: { track_level?: string }
---@return table[] results Array of { name: string, memory: number } sorted by memory usage
-- Calculate memory usage per module (approximately)
function module_reset.analyze_memory_usage(options)

  -- Validate options
  options = options or {}
  validate_type_or_nil(options, "table", "options")

  if log then
    log.debug("Starting memory usage analysis", {
      track_level = options.track_level or "basic",
    })
  end

  local success, result = error_handler.try(function()
    local baseline = collectgarbage("count")
    local results = {}

    -- Get the starting memory usage
    collectgarbage("collect")
    local start_mem = collectgarbage("count")

    if log then
      log.debug("Memory baseline established", {
        before_gc = baseline,
        after_gc = start_mem,
        freed_kb = baseline - start_mem,
      })
    end

    -- Check memory usage of each module by removing and re-requiring
    local modules = module_reset.get_loaded_modules()
    local analyzed_count = 0
    local total_memory = 0

    if log then
      log.debug("Analyzing modules", {
        module_count = #modules,
      })
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    for _, module_name in ipairs(modules) do
      -- Skip protected modules
      if not module_reset.protected_modules[module_name] then
        -- Safely measure memory difference
        local module_success, module_memory = error_handler.try(function()
          -- Save the loaded module
          local loaded_module = package.loaded[module_name]

          -- Unload it
          package.loaded[module_name] = nil
          collectgarbage("collect")
          local after_unload = collectgarbage("count")

          -- Measure memory difference
          local memory_used = start_mem - after_unload

          -- Re-load the module to preserve state
          package.loaded[module_name] = loaded_module

          return memory_used
        end)

        if not module_success then
          if log then
            log.warn("Failed to analyze memory for module", {
              module = module_name,
              error = error_handler.format_error(module_memory),
            })
          end
          -- Continue with the next module
        else
          local memory_used = module_memory

          if memory_used > 0 then
            results[module_name] = memory_used
            total_memory = total_memory + memory_used
            analyzed_count = analyzed_count + 1

            if log and log.is_debug_enabled() then
              log.debug("Module memory usage measured", {
                module = module_name,
                memory_kb = memory_used,
              })
            end
          end
        end
      end
    end

    -- Sort modules by memory usage
    local sorted_results = {}
    for module_name, mem in pairs(results) do
      table.insert(sorted_results, {
        name = module_name,
        memory = mem,
      })
    end

    table.sort(sorted_results, function(a, b)
      return a.memory > b.memory
    end)

    if log then
      log.info("Memory usage analysis completed", {
        total_modules = #modules,
        analyzed_modules = analyzed_count,
        total_memory_kb = total_memory,
        top_module = sorted_results[1] and sorted_results[1].name or "none",
        top_module_memory = sorted_results[1] and sorted_results[1].memory or 0,
      })
    end

    return sorted_results
  end)

  if not success then
    if log then
      log.error("Failed to analyze memory usage", {
        error = error_handler.format_error(result),
        track_level = options and options.track_level or "basic",
        modules_count = module_reset.get_loaded_modules() and #module_reset.get_loaded_modules() or 0,
        protected_modules_count = module_reset.count_protected_modules(),
      })
    end

    ---@diagnostic disable-next-line: redundant-parameter
    error_handler.rethrow(result, {
      operation = "module_reset.analyze_memory_usage",
      module_version = module_reset._VERSION,
      options = options or "default",
    })
  end

  return result
end

---@param module_name string Name of the module to check
---@return boolean is_protected Whether the module is protected
-- Check if a module is protected
function module_reset.is_protected(module_name)
  validate_not_nil(module_name, "module_name")
  validate_type(module_name, "string", "module_name")

  return module_reset.protected_modules[module_name] or false
end

---@param module_name string Name of the module to protect
---@return boolean added Whether the module was newly added (false if already protected)
-- Add a module to the protected list
function module_reset.add_protected_module(module_name)

  -- Validate input
  validate_not_nil(module_name, "module_name")
  validate_type(module_name, "string", "module_name")

  local success, result = error_handler.try(function()
    if not module_reset.protected_modules[module_name] then
      module_reset.protected_modules[module_name] = true

      if log then
        log.debug("Added module to protected list", {
          module = module_name,
          protected_count = module_reset.count_protected_modules(),
        })
      end

      return true
    end

    return false
  end)

  if not success then
    if log then
      log.error("Failed to add module to protected list", {
        module = module_name,
        error = error_handler.format_error(result),
        protected_modules_count = module_reset.count_protected_modules(),
        is_already_protected = module_reset.protected_modules[module_name] and true or false,
      })
    end

    error_handler.rethrow(result, {
      operation = "module_reset.add_protected_module",
      module_name = module_name,
      module_version = module_reset._VERSION,
    })
  end

  return result
end

---@param firmo table The firmo instance to register with
---@return table firmo The firmo instance with module_reset registered
-- Register the module with firmo
function module_reset.register_with_firmo(firmo)
  -- Validate input
  validate_not_nil(firmo, "firmo")
  validate_type(firmo, "table", "firmo")

  local success, err = error_handler.try(function()
    logger.debug("Registering module reset with firmo")

    -- Store reference to firmo
    module_reset.firmo = firmo

    -- Add module reset capabilities to firmo
    firmo.module_reset = module_reset

    -- Verify that firmo.reset exists and is a function
    if type(firmo.reset) ~= "function" then
      error_handler.throw(
        "Expected firmo.reset to be a function, but it was " .. (firmo.reset == nil and "nil" or type(firmo.reset)),
        error_handler.CATEGORY.VALIDATION,
        error_handler.SEVERITY.ERROR,
        {
          required_function = "firmo.reset",
          actual_type = firmo.reset == nil and "nil" or type(firmo.reset),
          operation = "register_with_firmo",
        }
      )
    end

    -- Enhance the reset function
    local original_reset = firmo.reset

    firmo.reset = function()
      local reset_success, reset_result = error_handler.try(function()
        logger.debug("Enhanced reset function called")

        -- First call the original reset function
        original_reset()

        -- Then reset modules as needed
        if firmo.isolation_options and firmo.isolation_options.reset_modules then
          logger.debug("Automatic module reset triggered", {
            verbose = firmo.isolation_options.verbose and true or false,
          })

          module_reset.reset_all({
            verbose = firmo.isolation_options.verbose,
          })
        end

        -- Return firmo to allow chaining
        return firmo
      end)

      if not reset_success then
        if log then
          log.error("Enhanced reset function failed", {
            error = error_handler.format_error(reset_result),
          })
        end
        error_handler.rethrow(reset_result)
      end

      return reset_result
    end

    -- Initialize module tracking
    module_reset.init()

    logger.info("Module reset system registered with firmo", {
      protected_modules = module_reset.count_protected_modules(),
      initial_modules = module_reset.initial_state
          and (type(module_reset.initial_state) == "table" and #module_reset.initial_state or 0)
        or 0,
    })
  end)

  if not success then
    logger.error("Failed to register module reset with firmo", {
      error = error_handler.format_error(err),
      protected_modules_count = module_reset.count_protected_modules(),
      initial_state = module_reset.initial_state ~= nil and "created" or "missing",
    })

    error_handler.rethrow(err, {
      operation = "module_reset.register_with_firmo",
      module_version = module_reset._VERSION,
    })
  end

  return firmo
end

---@param options table Options: { reset_modules?: boolean, verbose?: boolean, track_memory?: boolean }
---@return table firmo The configured firmo instance
-- Configure isolation options for firmo
function module_reset.configure(options)

  -- Validate options
  options = options or {}
  validate_type_or_nil(options, "table", "options")

  local success, result = error_handler.try(function()
    local firmo = module_reset.firmo

    if not firmo then
      error_handler.throw(
        "Module reset not registered with firmo",
        error_handler.CATEGORY.CONFIGURATION,
        error_handler.SEVERITY.ERROR
      )
    end

    logger.debug("Configuring isolation options", {
      reset_modules = options.reset_modules and true or false,
      verbose = options.verbose and true or false,
      track_memory = options.track_memory and true or false,
    })

    firmo.isolation_options = options

    logger.info("Isolation options configured", {
      reset_enabled = options.reset_modules and true or false,
    })

    return firmo
  end)

  if not success then
    logger.error("Failed to configure isolation options", {
      error = error_handler.format_error(result),
      options_type = type(options),
      has_firmo = module_reset.firmo ~= nil,
      reset_modules = options and options.reset_modules,
      verbose = options and options.verbose,
      track_memory = options and options.track_memory,
    })

    error_handler.rethrow(result, {
      operation = "module_reset.configure",
      module_version = module_reset._VERSION,
      options = options or "default",
    })
  end

  return result
end

return module_reset
