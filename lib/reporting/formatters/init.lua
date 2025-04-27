--- Formatter Registry Initialization
---
--- This module loads and registers all built-in reporting formatters (coverage,
--- quality, results) into a central registry provided by the main reporting module.
--- It handles different formatter module structures (registration function, register method,
--- direct formatting functions) and provides error handling during loading.
---
--- @module lib.reporting.formatters
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class ReportingFormatters The public API for the formatter registry initializer.
---@field _VERSION string Module version.
---@field built_in table A table listing the names of built-in formatters by category (`coverage`, `quality`, `results`).
---@field register_all fun(formatters: table): table|nil, table? Loads and registers all built-in formatters into the provided registry table. Returns the updated formatters table on success, or nil and an error table on failure.

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging, _fs

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the filesystem module with lazy loading to avoid circular dependencies
---@return table|nil The filesystem module or nil if not available
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
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
    return logging.get_logger("formatters")
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

local M = {
  --- Lists the names of built-in formatters categorized by type.
  built_in = {
    coverage = { "summary", "json", "html", "lcov", "cobertura" },
    quality = { "summary", "json", "html" },
    results = { "junit", "tap", "csv" },
  },
}

--- Module version
M._VERSION = "1.0.0"

--- Loads and registers all built-in formatter modules into the provided registry.
--- Attempts to load formatters like "summary", "json", "html", "lcov", etc., from the current directory.
--- Handles different module structures (registration function, register method, direct format functions).
---@param formatters table The main formatters registry object, expected to have `coverage`, `quality`, and `results` sub-tables. This table is modified in place.
---@return table|nil formatters The updated `formatters` table if at least one formatter registered successfully, `nil` otherwise.
---@return table? error An error object containing details if some or all formatters failed to load/register.
function M.register_all(formatters)
  -- Validate formatters parameter
  if not formatters then
    local err = get_error_handler().validation_error("Missing required formatters parameter", {
      operation = "register_all",
      module = "formatters",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Verify formatters has the expected structure
  if not formatters.coverage or not formatters.quality or not formatters.results then
    local err = get_error_handler().validation_error("Formatters parameter missing required registries", {
      operation = "register_all",
      module = "formatters",
      has_coverage = formatters.coverage ~= nil,
      has_quality = formatters.quality ~= nil,
      has_results = formatters.results ~= nil,
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Load all the built-in formatters
  local formatter_modules = {
    "summary",
    "json",
    "html",
    "lcov",
    "tap",
    "csv",
    "junit",
    "cobertura",
  }

  get_logger().debug("Registering reporting formatters", {
    modules = formatter_modules,
  })

  -- Track loaded formatters and any errors
  local loaded_formatters = {}
  local formatter_errors = {}

  for _, module_name in ipairs(formatter_modules) do
    -- Get the current module path with error handling
    local get_path_success, current_module_dir = get_error_handler().try(function()
      local source = debug.getinfo(1).source
      local dir = source:match("@(.+)/[^/]+$") or ""
      return get_fs().normalize_path(dir)
    end)

    if not get_path_success then
      get_logger().warn("Failed to get module directory", {
        module = module_name,
        error = get_error_handler().format_error(current_module_dir), -- current_module_dir contains the error
      })
      -- Use empty string as fallback
      current_module_dir = ""
    end

    -- Try multiple possible paths to load the formatter
    local formatter_paths = {}

    -- Add standard paths
    table.insert(formatter_paths, "lib.reporting.formatters." .. module_name)
    table.insert(formatter_paths, "../lib/reporting/formatters/" .. module_name)
    table.insert(formatter_paths, "./lib/reporting/formatters/" .. module_name)

    -- Add path with directory base - wrap in try/catch to handle potential errors
    local join_success, joined_path = get_error_handler().try(function()
      return get_fs().join_paths(current_module_dir, module_name)
    end)

    if join_success then
      table.insert(formatter_paths, joined_path)
    else
      get_logger().warn("Failed to join paths for formatter", {
        module = module_name,
        base_dir = current_module_dir,
        error = get_error_handler().format_error(joined_path), -- joined_path contains the error
      })
    end

    get_logger().trace("Attempting to load formatter", {
      module = module_name,
      paths = formatter_paths,
      base_dir = current_module_dir,
    })

    local loaded = false
    local last_error = nil

    for _, path in ipairs(formatter_paths) do
      -- Use error_handler.try for better error handling
      local require_success, formatter_module_or_error = get_error_handler().try(function()
        return require(path)
      end)

      if require_success then
        -- Handle different module formats:
        if type(formatter_module_or_error) == "function" then
          -- 1. Function that registers formatters - use try/catch
          get_logger().trace("Attempting to register formatter as function", {
            module = module_name,
            path = path,
          })

          local register_success, register_result = get_error_handler().try(function()
            formatter_module_or_error(formatters)
            return true
          end)

          if register_success then
            get_logger().trace("Loaded formatter as registration function", {
              module = module_name,
              path = path,
            })
            loaded = true
            table.insert(loaded_formatters, {
              name = module_name,
              path = path,
              type = "registration_function",
            })
            break
          else
            -- Register failed but require succeeded - record the error and continue
            last_error = error_handler.runtime_error(
              "Registration function failed",
              {
                module = module_name,
                path = path,
                operation = "register_all",
                formatter_type = "function",
              },
              register_result -- register_result contains the error
            )
            get_logger().warn(last_error.message, last_error.context)
          end
        elseif
          type(formatter_module_or_error) == "table" and type(formatter_module_or_error.register) == "function"
        then
          -- 2. Table with register function - use try/catch
          get_logger().trace("Attempting to register formatter with register() method", {
            module = module_name,
            path = path,
          })

          local register_success, register_result = get_error_handler().try(function()
            formatter_module_or_error.register(formatters)
            return true
          end)

          if register_success then
            get_logger().trace("Loaded formatter with register() method", {
              module = module_name,
              path = path,
            })
            loaded = true
            table.insert(loaded_formatters, {
              name = module_name,
              path = path,
              type = "register_method",
            })
            break
          else
            -- Register method failed - record the error and continue
            last_error = error_handler.runtime_error(
              "Register method failed",
              {
                module = module_name,
                path = path,
                operation = "register_all",
                formatter_type = "register_method",
              },
              register_result -- register_result contains the error
            )
            get_logger().warn(last_error.message, last_error.context)
          end
        elseif type(formatter_module_or_error) == "table" then
          -- 3. Table with format_coverage/format_quality functions
          local functions_found = {}

          -- Register each function with error handling
          if type(formatter_module_or_error.format_coverage) == "function" then
            local register_success, _ = get_error_handler().try(function()
              formatters.coverage[module_name] = formatter_module_or_error.format_coverage
              return true
            end)

            if register_success then
              table.insert(functions_found, "format_coverage")
            else
              get_logger().warn("Failed to register format_coverage function", {
                module = module_name,
                path = path,
              })
            end
          end

          if type(formatter_module_or_error.format_quality) == "function" then
            local register_success, _ = get_error_handler().try(function()
              formatters.quality[module_name] = formatter_module_or_error.format_quality
              return true
            end)

            if register_success then
              table.insert(functions_found, "format_quality")
            else
              get_logger().warn("Failed to register format_quality function", {
                module = module_name,
                path = path,
              })
            end
          end

          if type(formatter_module_or_error.format_results) == "function" then
            local register_success, _ = get_error_handler().try(function()
              formatters.results[module_name] = formatter_module_or_error.format_results
              return true
            end)

            if register_success then
              table.insert(functions_found, "format_results")
            else
              get_logger().warn("Failed to register format_results function", {
                module = module_name,
                path = path,
              })
            end
          end

          if #functions_found > 0 then
            get_logger().trace("Loaded formatter with formatting functions", {
              module = module_name,
              path = path,
              functions = functions_found,
            })
            loaded = true
            table.insert(loaded_formatters, {
              name = module_name,
              path = path,
              type = "formatting_functions",
              functions = functions_found,
            })
            break
          else
            -- No valid formatting functions found
            last_error = get_error_handler().validation_error("No formatting functions found in module", {
              module = module_name,
              path = path,
              operation = "register_all",
            })
            get_logger().warn(last_error.message, last_error.context)
          end
        else
          -- Module is not in a recognized format
          last_error = get_error_handler().validation_error("Formatter module is not in a recognized format", {
            module = module_name,
            path = path,
            module_type = type(formatter_module_or_error),
            operation = "register_all",
          })
          get_logger().warn(last_error.message, last_error.context)
        end
      else
        -- Require failed - record error but continue trying other paths
        last_error = get_error_handler().runtime_error(
          "Failed to require formatter module",
          {
            module = module_name,
            path = path,
            operation = "register_all",
          },
          formatter_module_or_error -- formatter_module_or_error contains the error
        )

        -- Only log at trace level since we try multiple paths and expect some to fail
        get_logger().trace("Failed to require formatter", {
          module = module_name,
          path = path,
          error = get_error_handler().format_error(formatter_module_or_error),
        })
      end
    end

    if loaded then
      get_logger().debug("Successfully registered formatter", { module = module_name })
    else
      -- Record the error if all load attempts failed
      if last_error then
        table.insert(formatter_errors, {
          module = module_name,
          error = last_error,
        })
      end

      get_logger().warn("Failed to load formatter module", {
        module = module_name,
        error = last_error and get_error_handler().format_error(last_error) or "Unknown error",
      })
    end
  end

  -- If we have errors but loaded some formatters, continue with warning
  if #formatter_errors > 0 then
    get_logger().warn("Some formatters failed to load", {
      total_modules = #formatter_modules,
      loaded = #loaded_formatters,
      failed = #formatter_errors,
    })
  end

  get_logger().debug("Formatter registration complete", {
    loaded_formatters = #loaded_formatters,
    error_count = #formatter_errors,
    coverage_formatters = table.concat(M.built_in.coverage, ", "),
    quality_formatters = table.concat(M.built_in.quality, ", "),
    results_formatters = table.concat(M.built_in.results, ", "),
  })

  -- If all formatters failed to load, return an error
  if #loaded_formatters == 0 and #formatter_errors > 0 then
    local err = get_error_handler().runtime_error("All formatters failed to load", {
      operation = "register_all",
      module = "formatters",
      modules_attempted = #formatter_modules,
      error_count = #formatter_errors,
      first_error = formatter_errors[1] and formatter_errors[1].error.message or "Unknown error",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Even with some errors, return the formatters if at least one loaded
  return formatters
end

return M
