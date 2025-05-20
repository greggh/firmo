--- Module Reset Functionality for Firmo
---
--- Provides enhanced test isolation by managing Lua's module cache (`package.loaded`).
--- Allows cleaning up module state between test runs for better isolation, preventing
--- test pollution, and optionally analyzing memory usage patterns.
---
--- Core functionality includes:
--- - Tracking initial module state (`package.loaded`) upon initialization.
--- - Resetting `package.loaded` by removing non-protected modules.
--- - Protecting critical Lua core modules and framework modules from being reset.
--- - Allowing custom protection rules (`protect`, `add_protected_module`).
--- - Optional verbose logging during reset operations.
--- - Optional memory usage analysis per module (experimental).
--- - Integration with the Firmo test runner lifecycle via `register_with_firmo`.
---
--- @module lib.core.module_reset
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025

---@class module_reset
---@field _VERSION string Version number following semantic versioning.
---@field initial_state table<string, boolean>|nil Snapshot of `package.loaded` keys taken during `init()`. Internal.
---@field protected_modules table<string, boolean> Registry mapping module names to `true` if they should be protected from reset. Internal.
---@field firmo table|nil Reference to the main `firmo` module instance, set via `register_with_firmo`. Internal.
---@field protect fun(self: module_reset, modules: string|string[]): module_reset Adds one or more module names to the protected list.
---@field count_protected_modules fun(self: module_reset): number Returns the count of currently protected modules.
---@field snapshot fun(self: module_reset): table<string, boolean>, number Takes a snapshot of the current `package.loaded` keys. Returns the snapshot table and the count. Throws error on failure.
---@field init fun(self: module_reset): module_reset Initializes the module by taking the initial snapshot and protecting initially loaded modules. Throws error on failure.
---@field reset_all fun(self: module_reset, options?: {verbose?: boolean}): number Resets `package.loaded` by removing all non-protected modules. Returns the number of modules reset. Throws error on failure. Note: `force` option is not implemented.
---@field reset_pattern fun(self: module_reset, pattern: string, options?: {verbose?: boolean}): number Resets modules in `package.loaded` whose names match the Lua `pattern`, excluding protected modules. Returns the number of modules reset. Throws error on failure or invalid pattern.
---@field get_loaded_modules fun(self: module_reset): string[] Returns a sorted list of currently loaded module names that are *not* protected. Throws error on failure.
---@field get_memory_usage fun(self: module_reset): {current: number, count: number} Returns the current memory usage reported by `collectgarbage("count")`. `count` field is deprecated/unused. Throws error on failure.
---@field analyze_memory_usage fun(self: module_reset, options?: {track_level?: string}): {name: string, memory: number}[] Experimental: Attempts to estimate memory usage per module by unloading/reloading. Returns an array of `{name=string, memory=number}` sorted by memory usage (KB). Throws error on failure. Note: `track_level` option is not implemented.
---@field is_protected fun(self: module_reset, module_name: string): boolean Checks if a specific module name is in the protected list. Throws error if `module_name` is nil or not a string.
---@field add_protected_module fun(self: module_reset, module_name: string): boolean Adds a single module name to the protected list. Returns `true` if added, `false` if already protected. Throws error if `module_name` is invalid or if internal error occurs.
---@field register_with_firmo fun(self: module_reset, firmo_instance: table): table Registers this module with the main `firmo` instance, stores a reference, assigns `firmo.module_reset = self`, enhances `firmo.reset`, and calls `self.init()`. Throws error on failure or if `firmo_instance.reset` is invalid.
---@field configure fun(self: module_reset, options: {reset_modules?: boolean, verbose?: boolean, track_memory?: boolean}): table Configures isolation options within the associated `firmo` instance (`firmo.isolation_options`). Returns the `firmo` instance. Throws error if not registered with firmo first or if `options` is invalid. Note: `track_memory` option is not currently used by the reset logic.

local module_reset = {}
module_reset._VERSION = "1.2.0"

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the success handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

--- Get the logging module with lazy loading to avoid circular dependencies
---@return table|nil The logging module or nil if not available
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end

--- Get a logger instance for this module
---@return table A logger instance (either real or stub)
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("module_reset")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

--- Validates that a value is not nil, throwing a standardized error if it is.
---@param value any The value to check.
---@param name string The name of the parameter being validated (for the error message).
---@return boolean `true` if the value is not nil.
---@throws table An error object from `error_handler.throw` if `value` is nil.
---@private
local function validate_not_nil(value, name)
  if value == nil then
    get_error_handler().throw(
      name .. " must not be nil",
      get_error_handler().CATEGORY.VALIDATION,
      get_error_handler().SEVERITY.ERROR,
      { parameter_name = name }
    )
  end
  return true
end

---@param value any Value to check type of
--- Validates that a value is of a specific Lua type, throwing a standardized error if not.
---@param value any The value to check.
---@param expected_type string The expected type name (e.g., "string", "table").
---@param name string The name of the parameter being validated (for the error message).
---@return boolean `true` if the value's type matches `expected_type`.
---@throws table An error object from `error_handler.throw` if the type does not match.
---@private
local function validate_type(value, expected_type, name)
  if type(value) ~= expected_type then
    get_error_handler().throw(
      name .. " must be of type '" .. expected_type .. "', got '" .. type(value) .. "'",
      get_error_handler().CATEGORY.VALIDATION,
      get_error_handler().SEVERITY.ERROR,
      {
        parameter_name = name,
        expected_type = expected_type,
        actual_type = type(value),
      }
    )
  end
  return true
end

--- Validates that a value is either nil or of a specific Lua type, throwing a standardized error otherwise.
---@param value any The value to check.
---@param expected_type string The expected type name (e.g., "string", "table").
---@param name string The name of the parameter being validated (for the error message).
---@return boolean `true` if the value is nil or its type matches `expected_type`.
---@throws table An error object from `error_handler.throw` if the value is not nil and the type does not match.
---@private
local function validate_type_or_nil(value, expected_type, name)
  if value ~= nil and type(value) ~= expected_type then
    get_error_handler().throw(
      name .. " must be of type '" .. expected_type .. "' or nil, got '" .. type(value) .. "'",
      get_error_handler().CATEGORY.VALIDATION,
      get_error_handler().SEVERITY.ERROR,
      {
        parameter_name = name,
        expected_type = expected_type,
        actual_type = type(value),
      }
    )
  end
  return true
end

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

--- Adds one or more module names to the list of modules protected from being reset.
---@param modules string|string[] A single module name (string) or an array of module names (table).
---@return module_reset The module instance (`module_reset`) for method chaining.
function module_reset.protect(modules)
  if type(modules) == "string" then
    get_logger().debug("Protecting single module", {
      module = modules,
    })
    module_reset.protected_modules[modules] = true
  elseif type(modules) == "table" then
    get_logger().debug("Protecting multiple modules", {
      count = #modules,
    })
    for _, module_name in ipairs(modules) do
      module_reset.protected_modules[module_name] = true
      get_logger().debug("Added module to protected list", {
        module = module_name,
      })
    end
  end

  get_logger().info("Module protection updated", {
    protected_count = module_reset.count_protected_modules(),
  })
end

--- Counts the number of modules currently in the protected list.
---@return number count The total number of protected modules.
function module_reset.count_protected_modules()
  local count = 0
  for _ in pairs(module_reset.protected_modules) do
    count = count + 1
  end
  return count
end

--- Takes a snapshot of the keys currently present in `package.loaded`.
---@return table<string, boolean> snapshot A table where keys are the names of loaded modules and values are `true`.
---@return number count The number of modules included in the snapshot.
---@throws table An error object from `error_handler.rethrow` if creating the snapshot fails.
function module_reset.snapshot()
  local success, result = get_error_handler().try(function()
    local snapshot = {}
    local count = 0

    for module_name, _ in pairs(package.loaded) do
      snapshot[module_name] = true
      count = count + 1
    end

    get_logger().debug("Created module state snapshot", {
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

    get_logger().error("Failed to create module state snapshot", {
      error = get_error_handler().format_error(result),
      loaded_modules_count = loaded_modules_count,
      protected_modules_count = module_reset.count_protected_modules(),
    })

    get_error_handler().rethrow(result, {
      operation = "module_reset.snapshot",
      module_version = module_reset._VERSION,
    })
  end

  return result
end

--- Initializes the module reset system.
--- Takes an initial snapshot of `package.loaded` and adds all initially loaded modules
--- to the protected list. This should typically be called once during framework setup,
--- often via `register_with_firmo`.
---@return module_reset The module instance (`module_reset`) for method chaining.
---@throws table An error object from `error_handler.rethrow` if initialization fails.
function module_reset.init()
  local success, err = get_error_handler().try(function()
    get_logger().debug("Initializing module reset system")

    module_reset.initial_state = module_reset.snapshot()
    local initial_count = 0

    -- Also protect all modules already loaded at init time
    ---@diagnostic disable-next-line: param-type-mismatch
    for module_name, _ in pairs(module_reset.initial_state) do
      module_reset.protected_modules[module_name] = true
      initial_count = initial_count + 1
    end

    get_logger().info("Module reset system initialized", {
      initial_modules = initial_count,
      protected_modules = module_reset.count_protected_modules(),
    })
  end)

  if not success then
    get_logger().error("Failed to initialize module reset system", {
      error = get_error_handler().format_error(err),
      protected_modules_count = module_reset.count_protected_modules(),
      state = module_reset.initial_state ~= nil and "created" or "missing",
    })

    get_error_handler().rethrow(err, {
      operation = "module_reset.init",
      module_version = module_reset._VERSION,
    })
  end

  return module_reset
end

--- Resets the Lua module cache (`package.loaded`) by removing all loaded modules
--- *except* those in the protected list. Also forces garbage collection afterwards.
--- If `init()` has not been called, it will be called implicitly first.
---@param options? {verbose?: boolean} Optional settings table.
---   - `verbose`: If `true`, logs each module being reset.
---@return number count The number of modules that were actually reset (removed from `package.loaded`).
---@throws table An error object from `error_handler.rethrow` if resetting fails.
function module_reset.reset_all(options)
  -- Validate options
  options = options or {}
  validate_type_or_nil(options, "table", "options")

  local verbose = options.verbose

  get_logger().debug("Resetting all modules", {
    verbose = verbose and true or false,
  })

  ---@diagnostic disable-next-line: unused-local
  local success, result, err = get_error_handler().try(function()
    -- If we haven't initialized, do so now
    if not module_reset.initial_state then
      get_logger().debug("Module reset system not initialized, initializing now")
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
          local print_success, _ = get_error_handler().try(function()
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

    get_logger().info("Module reset completed", {
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

    get_logger().error("Failed to reset modules", {
      error = get_error_handler().format_error(result),
      loaded_modules_count = loaded_modules_count,
      protected_modules_count = module_reset.count_protected_modules(),
      options = options ~= nil and type(options) == "table" and "provided" or "default",
    })

    ---@diagnostic disable-next-line: redundant-parameter
    get_error_handler().rethrow(result, {
      operation = "module_reset.reset_all",
      options = options or "default",
    })
  end

  return result
end

--- Resets modules in `package.loaded` whose names match a given Lua pattern string,
--- excluding any modules in the protected list. Forces garbage collection if any modules were reset.
---@param pattern string Lua pattern string to match against module names.
---@param options? {verbose?: boolean} Optional settings table.
---   - `verbose`: If `true`, logs each module being reset.
---@return number count The number of modules that matched the pattern and were reset.
---@throws table An error object from `error_handler.rethrow` if validation or resetting fails, or if the pattern is invalid.
function module_reset.reset_pattern(pattern, options)
  -- Validate parameters
  validate_not_nil(pattern, "pattern")
  validate_type(pattern, "string", "pattern")

  options = options or {}
  validate_type_or_nil(options, "table", "options")

  local verbose = options.verbose

  get_logger().debug("Resetting modules by pattern", {
    pattern = pattern,
    verbose = verbose and true or false,
  })

  local success, result = get_error_handler().try(function()
    local reset_count = 0
    local modules_to_reset = {}
    local total_checked = 0
    local match_count = 0

    -- Collect matching modules
    for module_name, _ in pairs(package.loaded) do
      total_checked = total_checked + 1

      -- Safely check for pattern match
      local match_success, matches = get_error_handler().try(function()
        return module_name:match(pattern) ~= nil
      end)

      if not match_success then
        get_error_handler().throw(
          "Invalid pattern for module matching",
          get_error_handler().CATEGORY.VALIDATION,
          get_error_handler().SEVERITY.ERROR,
          { pattern = pattern, module = module_name }
        )
      end

      if matches then
        match_count = match_count + 1
        if not module_reset.protected_modules[module_name] then
          modules_to_reset[#modules_to_reset + 1] = module_name
        else
          get_logger().debug("Skipping protected module", {
            module = module_name,
            pattern = pattern,
          })
        end
      end
    end

    get_logger().debug("Collected modules for pattern reset", {
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
          local print_success, _ = get_error_handler().try(function()
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
        error = get_error_handler().format_error(result),
        loaded_modules_count = loaded_modules_count,
        protected_modules_count = module_reset.count_protected_modules(),
        options = options ~= nil and type(options) == "table" and "provided" or "default",
      })
    end

    get_error_handler().rethrow(result, {
      operation = "module_reset.reset_pattern",
      pattern = pattern,
      options = options or "default",
    })
  end

  return result
end

--- Retrieves a sorted list of currently loaded module names from `package.loaded`,
--- excluding any modules present in the protected list.
---@return string[] module_names A sorted array of non-protected loaded module names.
---@throws table An error object from `error_handler.rethrow` if retrieving the list fails.
function module_reset.get_loaded_modules()
  local success, result = get_error_handler().try(function()
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
        error = get_error_handler().format_error(result),
        protected_modules_count = module_reset.count_protected_modules(),
      })
    end

    get_error_handler().rethrow(result, {
      operation = "module_reset.get_loaded_modules",
      module_version = module_reset._VERSION,
    })
  end

  return result
end

--- Gets the current Lua memory usage in kilobytes using `collectgarbage("count")`.
---@return table info A table `{ current = number, count = number }`, where `current` is memory in KB and `count` is currently unused (always 0).
---@throws table An error object from `error_handler.rethrow` if retrieving memory usage fails.
function module_reset.get_memory_usage()
  local success, result = get_error_handler().try(function()
    local current_mem = collectgarbage("count")

    get_logger().debug("Retrieved memory usage", {
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
        error = get_error_handler().format_error(result),
        operation = "get_memory_usage",
      })
    end

    ---@diagnostic disable-next-line: redundant-parameter
    get_error_handler().rethrow(result, {
      operation = "module_reset.get_memory_usage",
      module_version = module_reset._VERSION,
    })
  end

  return result
end

--- **Experimental:** Attempts to estimate the memory usage of each non-protected loaded module
--- by unloading it, running garbage collection, measuring the difference, and then reloading it.
--- The accuracy of this method is limited.
---@param options? {track_level?: string} Optional settings table. `track_level` is currently unused.
---@return {name: string, memory: number}[] results An array of tables, each containing `name` (module name) and `memory` (estimated usage in KB), sorted descending by memory usage. Only includes modules where estimated usage > 0.
---@throws table An error object from `error_handler.rethrow` if analysis fails.
function module_reset.analyze_memory_usage(options)
  -- Validate options
  options = options or {}
  validate_type_or_nil(options, "table", "options")

  if log then
    log.debug("Starting memory usage analysis", {
      track_level = options.track_level or "basic",
    })
  end

  local success, result = get_error_handler().try(function()
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
        local module_success, module_memory = get_error_handler().try(function()
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
              error = get_error_handler().format_error(module_memory),
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
        error = get_error_handler().format_error(result),
        track_level = options and options.track_level or "basic",
        modules_count = module_reset.get_loaded_modules() and #module_reset.get_loaded_modules() or 0,
        protected_modules_count = module_reset.count_protected_modules(),
      })
    end

    ---@diagnostic disable-next-line: redundant-parameter
    get_error_handler().rethrow(result, {
      operation = "module_reset.analyze_memory_usage",
      module_version = module_reset._VERSION,
      options = options or "default",
    })
  end

  return result
end

--- Checks if a given module name is present in the protected list.
---@param module_name string The name of the module to check.
---@return boolean is_protected `true` if the module name exists in the `protected_modules` table, `false` otherwise.
---@throws table An error object if `module_name` is nil or not a string.
function module_reset.is_protected(module_name)
  validate_not_nil(module_name, "module_name")
  validate_type(module_name, "string", "module_name")

  return module_reset.protected_modules[module_name] or false
end

--- Adds a single module name to the protected list, preventing it from being reset.
---@param module_name string The name of the module to protect.
---@return boolean added `true` if the module was newly added to the protected list, `false` if it was already protected.
---@throws table An error object from `error_handler.rethrow` if `module_name` is invalid or if an internal error occurs.
function module_reset.add_protected_module(module_name)
  -- Validate input
  validate_not_nil(module_name, "module_name")
  validate_type(module_name, "string", "module_name")

  local success, result = get_error_handler().try(function()
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
        error = get_error_handler().format_error(result),
        protected_modules_count = module_reset.count_protected_modules(),
        is_already_protected = module_reset.protected_modules[module_name] and true or false,
      })
    end

    get_error_handler().rethrow(result, {
      operation = "module_reset.add_protected_module",
      module_name = module_name,
      module_version = module_reset._VERSION,
    })
  end

  return result
end

--- Integrates the module reset system with the main Firmo instance.
--- - Stores a reference to the `firmo` instance.
--- - Assigns this module (`module_reset`) to `firmo.module_reset`.
--- - Wraps `firmo.reset` to potentially trigger `module_reset.reset_all` based on `firmo.isolation_options`.
--- - Calls `module_reset.init()` to take the initial snapshot.
---@param firmo table The main `firmo` module instance.
---@return table firmo The `firmo` instance passed in, potentially modified with the enhanced reset function.
---@throws table An error object from `error_handler.rethrow` if `firmo` is invalid, if `firmo.reset` is not a function, or if initialization fails.
function module_reset.register_with_firmo(firmo)
  -- Validate input
  validate_not_nil(firmo, "firmo")
  validate_type(firmo, "table", "firmo")

  local success, err = get_error_handler().try(function()
    get_logger().debug("Registering module reset with firmo")

    -- Store reference to firmo
    module_reset.firmo = firmo

    -- Add module reset capabilities to firmo
    firmo.module_reset = module_reset

    -- Verify that firmo.reset exists and is a function
    if type(firmo.reset) ~= "function" then
      get_error_handler().throw(
        "Expected firmo.reset to be a function, but it was " .. (firmo.reset == nil and "nil" or type(firmo.reset)),
        get_error_handler().CATEGORY.VALIDATION,
        get_error_handler().SEVERITY.ERROR,
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
      local reset_success, reset_result = get_error_handler().try(function()
        get_logger().debug("Enhanced reset function called")

        -- First call the original reset function
        original_reset()

        -- Then reset modules as needed
        if firmo.isolation_options and firmo.isolation_options.reset_modules then
          get_logger().debug("Automatic module reset triggered", {
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
            error = get_error_handler().format_error(reset_result),
          })
        end
        get_error_handler().rethrow(reset_result)
      end

      return reset_result
    end

    -- Initialize module tracking
    module_reset.init()

    get_logger().info("Module reset system registered with firmo", {
      protected_modules = module_reset.count_protected_modules(),
      initial_modules = module_reset.initial_state
          and (type(module_reset.initial_state) == "table" and #module_reset.initial_state or 0)
        or 0,
    })
  end)

  if not success then
    get_logger().error("Failed to register module reset with firmo", {
      error = get_error_handler().format_error(err),
      protected_modules_count = module_reset.count_protected_modules(),
      initial_state = module_reset.initial_state ~= nil and "created" or "missing",
    })

    get_error_handler().rethrow(err, {
      operation = "module_reset.register_with_firmo",
      module_version = module_reset._VERSION,
    })
  end

  return firmo
end

--- Configures module reset options within the associated `firmo` instance.
--- This function sets the `firmo.isolation_options` table, which controls whether
--- the enhanced `firmo.reset` function actually performs a module reset.
--- Requires `register_with_firmo` to have been called first.
---@param options {reset_modules?: boolean, verbose?: boolean, track_memory?: boolean} Table containing configuration flags:
---   - `reset_modules`: If `true`, `firmo.reset()` will call `module_reset.reset_all()`.
---   - `verbose`: If `true` and `reset_modules` is `true`, `reset_all` logs verbose output.
---   - `track_memory`: Currently unused.
---@return table firmo The associated `firmo` instance.
---@throws table An error object from `error_handler.rethrow` if not registered with `firmo` first, or if `options` is invalid.
function module_reset.configure(options)
  -- Validate options
  options = options or {}
  validate_type_or_nil(options, "table", "options")

  local success, result = get_error_handler().try(function()
    local firmo = module_reset.firmo

    if not firmo then
      get_error_handler().throw(
        "Module reset not registered with firmo",
        get_error_handler().CATEGORY.CONFIGURATION,
        get_error_handler().SEVERITY.ERROR
      )
    end

    get_logger().debug("Configuring isolation options", {
      reset_modules = options.reset_modules and true or false,
      verbose = options.verbose and true or false,
      track_memory = options.track_memory and true or false,
    })

    firmo.isolation_options = options

    get_logger().info("Isolation options configured", {
      reset_enabled = options.reset_modules and true or false,
    })

    return firmo
  end)

  if not success then
    get_logger().error("Failed to configure isolation options", {
      error = get_error_handler().format_error(result),
      options_type = type(options),
      has_firmo = module_reset.firmo ~= nil,
      reset_modules = options and options.reset_modules,
      verbose = options and options.verbose,
      track_memory = options and options.track_memory,
    })

    get_error_handler().rethrow(result, {
      operation = "module_reset.configure",
      module_version = module_reset._VERSION,
      options = options or "default",
    })
  end

  return result
end

return module_reset
