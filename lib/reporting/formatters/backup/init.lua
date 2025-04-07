---@class ReportingFormatters
---@field built_in table Available built-in formatters
---@field register_all fun(formatters: table): table|nil, table? Load and register all formatters
-- Formatter registry initialization
-- Import required modules
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Initialize module logger
local logger = logging.get_logger("formatters")
logging.configure_from_config("formatters")

local M = {
  -- Export a list of built-in formatters for documentation
  built_in = {
    coverage = {"summary", "json", "html", "html_simple", "lcov", "cobertura"},
    quality = {"summary", "json", "html"},
    results = {"junit", "tap", "csv"}
  }
}

---@param formatters table The formatters registry object
---@return table|nil formatters The updated formatters registry or nil if registration failed
---@return table? error Error information if registration failed
function M.register_all(formatters)
  -- Validate formatters parameter
  if not formatters then
    local err = error_handler.validation_error(
      "Missing required formatters parameter",
      {
        operation = "register_all",
        module = "formatters"
      }
    )
    logger.error(err.message, err.context)
    return nil, err
  end
  
  -- Verify formatters has the expected structure
  if not formatters.coverage or not formatters.quality or not formatters.results then
    local err = error_handler.validation_error(
      "Formatters parameter missing required registries",
      {
        operation = "register_all",
        module = "formatters",
        has_coverage = formatters.coverage ~= nil,
        has_quality = formatters.quality ~= nil,
        has_results = formatters.results ~= nil
      }
    )
    logger.error(err.message, err.context)
    return nil, err
  end
  
  -- Load all the built-in formatters
  local formatter_modules = {
    "summary",
    "json",
    "html",
    "html_simple",
    "lcov",
    "tap",
    "csv",
    "junit",
    "cobertura"
  }
  
  logger.debug("Registering reporting formatters", {
    modules = formatter_modules
  })
  
  -- Track loaded formatters and any errors
  local loaded_formatters = {}
  local formatter_errors = {}
  
  for _, module_name in ipairs(formatter_modules) do
    -- Get the current module path with error handling
    local get_path_success, current_module_dir = error_handler.try(function()
      local source = debug.getinfo(1).source
      local dir = source:match("@(.+)/[^/]+$") or ""
      return fs.normalize_path(dir)
    end)
    
    if not get_path_success then
      logger.warn("Failed to get module directory", {
        module = module_name,
        error = error_handler.format_error(current_module_dir) -- current_module_dir contains the error
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
    local join_success, joined_path = error_handler.try(function()
      return fs.join_paths(current_module_dir, module_name)
    end)
    
    if join_success then
      table.insert(formatter_paths, joined_path)
    else
      logger.warn("Failed to join paths for formatter", {
        module = module_name,
        base_dir = current_module_dir,
        error = error_handler.format_error(joined_path) -- joined_path contains the error
      })
    end
    
    logger.trace("Attempting to load formatter", {
      module = module_name,
      paths = formatter_paths,
      base_dir = current_module_dir
    })
    
    local loaded = false
    local last_error = nil
    
    for _, path in ipairs(formatter_paths) do
      -- Use error_handler.try for better error handling
      local require_success, formatter_module_or_error = error_handler.try(function()
        return require(path)
      end)
      
      if require_success then
        -- Handle different module formats:
        if type(formatter_module_or_error) == "function" then
          -- 1. Function that registers formatters - use try/catch
          logger.trace("Attempting to register formatter as function", { 
            module = module_name,
            path = path
          })
          
          local register_success, register_result = error_handler.try(function()
            formatter_module_or_error(formatters)
            return true
          end)
          
          if register_success then
            logger.trace("Loaded formatter as registration function", { 
              module = module_name,
              path = path
            })
            loaded = true
            table.insert(loaded_formatters, {
              name = module_name,
              path = path,
              type = "registration_function"
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
                formatter_type = "function"
              },
              register_result -- register_result contains the error
            )
            logger.warn(last_error.message, last_error.context)
          end
        elseif type(formatter_module_or_error) == "table" and type(formatter_module_or_error.register) == "function" then
          -- 2. Table with register function - use try/catch
          logger.trace("Attempting to register formatter with register() method", { 
            module = module_name,
            path = path
          })
          
          local register_success, register_result = error_handler.try(function()
            formatter_module_or_error.register(formatters)
            return true
          end)
          
          if register_success then
            logger.trace("Loaded formatter with register() method", { 
              module = module_name,
              path = path
            })
            loaded = true
            table.insert(loaded_formatters, {
              name = module_name,
              path = path,
              type = "register_method"
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
                formatter_type = "register_method"
              },
              register_result -- register_result contains the error
            )
            logger.warn(last_error.message, last_error.context)
          end
        elseif type(formatter_module_or_error) == "table" then
          -- 3. Table with format_coverage/format_quality functions
          local functions_found = {}
          
          -- Register each function with error handling
          if type(formatter_module_or_error.format_coverage) == "function" then
            local register_success, _ = error_handler.try(function()
              formatters.coverage[module_name] = formatter_module_or_error.format_coverage
              return true
            end)
            
            if register_success then
              table.insert(functions_found, "format_coverage")
            else
              logger.warn("Failed to register format_coverage function", {
                module = module_name,
                path = path
              })
            end
          end
          
          if type(formatter_module_or_error.format_quality) == "function" then
            local register_success, _ = error_handler.try(function()
              formatters.quality[module_name] = formatter_module_or_error.format_quality
              return true
            end)
            
            if register_success then
              table.insert(functions_found, "format_quality")
            else
              logger.warn("Failed to register format_quality function", {
                module = module_name,
                path = path
              })
            end
          end
          
          if type(formatter_module_or_error.format_results) == "function" then
            local register_success, _ = error_handler.try(function()
              formatters.results[module_name] = formatter_module_or_error.format_results
              return true
            end)
            
            if register_success then
              table.insert(functions_found, "format_results")
            else
              logger.warn("Failed to register format_results function", {
                module = module_name,
                path = path
              })
            end
          end
          
          if #functions_found > 0 then
            logger.trace("Loaded formatter with formatting functions", {
              module = module_name,
              path = path,
              functions = functions_found
            })
            loaded = true
            table.insert(loaded_formatters, {
              name = module_name,
              path = path,
              type = "formatting_functions",
              functions = functions_found
            })
            break
          else
            -- No valid formatting functions found
            last_error = error_handler.validation_error(
              "No formatting functions found in module",
              {
                module = module_name,
                path = path,
                operation = "register_all"
              }
            )
            logger.warn(last_error.message, last_error.context)
          end
        else
          -- Module is not in a recognized format
          last_error = error_handler.validation_error(
            "Formatter module is not in a recognized format",
            {
              module = module_name,
              path = path,
              module_type = type(formatter_module_or_error),
              operation = "register_all"
            }
          )
          logger.warn(last_error.message, last_error.context)
        end
      else
        -- Require failed - record error but continue trying other paths
        last_error = error_handler.runtime_error(
          "Failed to require formatter module",
          {
            module = module_name,
            path = path,
            operation = "register_all"
          },
          formatter_module_or_error -- formatter_module_or_error contains the error
        )
        
        -- Only log at trace level since we try multiple paths and expect some to fail
        logger.trace("Failed to require formatter", {
          module = module_name,
          path = path,
          error = error_handler.format_error(formatter_module_or_error)
        })
      end
    end
    
    if loaded then
      logger.debug("Successfully registered formatter", { module = module_name })
    else
      -- Record the error if all load attempts failed
      if last_error then
        table.insert(formatter_errors, {
          module = module_name,
          error = last_error
        })
      end
      
      logger.warn("Failed to load formatter module", { 
        module = module_name,
        error = last_error and error_handler.format_error(last_error) or "Unknown error"
      })
    end
  end
  
  -- If we have errors but loaded some formatters, continue with warning
  if #formatter_errors > 0 then
    logger.warn("Some formatters failed to load", {
      total_modules = #formatter_modules,
      loaded = #loaded_formatters,
      failed = #formatter_errors
    })
  end
  
  logger.debug("Formatter registration complete", {
    loaded_formatters = #loaded_formatters,
    error_count = #formatter_errors,
    coverage_formatters = table.concat(M.built_in.coverage, ", "),
    quality_formatters = table.concat(M.built_in.quality, ", "),
    results_formatters = table.concat(M.built_in.results, ", ")
  })
  
  -- If all formatters failed to load, return an error
  if #loaded_formatters == 0 and #formatter_errors > 0 then
    local err = error_handler.runtime_error(
      "All formatters failed to load",
      {
        operation = "register_all",
        module = "formatters",
        modules_attempted = #formatter_modules,
        error_count = #formatter_errors,
        first_error = formatter_errors[1] and formatter_errors[1].error.message or "Unknown error"
      }
    )
    logger.error(err.message, err.context)
    return nil, err
  end
  
  -- Even with some errors, return the formatters if at least one loaded
  return formatters
end

return M