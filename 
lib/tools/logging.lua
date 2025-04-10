end

--- Configure module log level based on debug/verbose settings from an options object
--- This function provides a convenient way to configure a module's log level
--- based on standard debug/verbose flags commonly used in command-line options
--- or configuration objects.
---
--- @param module_name string The module name to configure
--- @param options table The options object with debug/verbose flags
--- @return number The configured log level
---
--- @usage
--- -- Configure log level from command-line args
--- local args = {debug = true, verbose = false}
--- logging.configure_from_options("MyModule", args)
---
--- -- Configure based on options object
--- local options = {debug = false, verbose = true, other_option = "value"}
--- local level = logging.configure_from_options("DataProcessor", options)
--- print("Configured log level: " .. level)  -- Will be VERBOSE level
function M.configure_from_options(module_name, options)
  if not module_name or not options then
    return M.LEVELS.INFO -- default if missing arguments
  end

  local log_level = M.LEVELS.INFO -- default level

  -- Check explicit level setting first
  if options.level then
    local numeric_level = normalize_log_level(options.level)
    if numeric_level then
      log_level = numeric_level
    end
  -- Otherwise check debug/verbose flags
  else
    if options.debug then
      log_level = M.LEVELS.DEBUG
    elseif options.verbose then
      log_level = M.LEVELS.VERBOSE
    end
  end

  -- Set the module's log level
  M.set_module_level(module_name, log_level)

  return log_level
end

--- Add a module pattern to the module filter whitelist
