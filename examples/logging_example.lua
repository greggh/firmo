--- Demonstrates the basic usage of the Firmo logging system.
---
--- Shows how to:
--- - Get a named logger instance.
--- - Log messages at different severity levels (INFO, WARN, ERROR, DEBUG, TRACE).
--- - Include structured context parameters with log messages.
--- - Conditionally log based on the enabled level.
--- - Enable DEBUG logs with command-line flags.
---
--- Note: Detailed configuration (log levels, file output, formatting, etc.)
--- is typically managed via the central configuration system (`.firmo-config.lua`)
--- rather than directly in code. See `docs/guides/logging.md` and
--- `docs/guides/central_config.md` for more details.
---
--- @module examples.logging_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config")

-- Detect debug/verbose flags from command line
local debug_flag = false
local verbose_flag = false

if arg then
  for _, v in ipairs(arg) do
    if v == "--debug" then
      debug_flag = true
    elseif v == "--verbose" then
      verbose_flag = true
    end
  end
end

-- No need to call central_config.init() - it's automatically initialized when required

-- Configure logging based on the command-line flags
local options = {
  debug = debug_flag,
  verbose = verbose_flag
}

-- Use central_config's built-in support for command-line flags
central_config.configure_from_options(options)

-- Print the selected log level for demonstration
if verbose_flag then
  print("Setting log level to TRACE (most verbose)")
elseif debug_flag then
  print("Setting log level to DEBUG")
end

-- Get a logger instance specific to this example/module
local logger = logging.get_logger("LoggingExample")

--- Runs the logging demonstrations.
local function run_example()
  print("\n--- Running Logging Example ---")
  print("Current log level: " .. (central_config.get("logging.level") or "INFO (default)"))
  print("Debug enabled: " .. tostring(logger.is_debug_enabled()))
  print("Trace enabled: " .. tostring(logger.is_trace_enabled()))
  print("----------------------------\n")

  -- Log informational messages
  logger.info("Application started", { version = "1.0.0", pid = os.time() }) -- Example with params

  -- Log warnings for potential issues
  logger.warn("Configuration value not found, using default", { config_key = "timeout_ms" })

  -- Log errors for problems that occurred
  local error_details = { code = 12, message = "Network connection failed" }
  logger.error("Failed to connect to service", { service = "AuthService", error = error_details }) -- Example with params

  -- Log debug messages (typically only shown when debug level is enabled)
  -- Use is_debug_enabled() to avoid preparing expensive data if not needed
  if logger.is_debug_enabled() then
    local complex_data = { user_id = 42, data = { a = 1, b = 2, c = 3 } }
    logger.debug("Processing detailed user data", { user_data = complex_data })
  end
  
  -- This debug message will be shown only when debug is enabled
  logger.debug("Debug message with simple context", { enabled_by = debug_flag and "--debug flag" or "config" })

  -- These trace messages will be shown only when trace/verbose level is enabled
  logger.trace("Entering function: process_request")
  logger.trace("Low-level execution details", { thread_id = 1, stack_depth = 5 })

  print("\n--- Logging Example Finished ---")
  print("Log levels shown:")
  print("  ERROR - Always shown")
  print("  WARN  - Always shown") 
  print("  INFO  - Always shown")
  print("  DEBUG - Only shown with '--debug' flag or DEBUG level in config")
  print("  TRACE - Only shown with '--verbose' flag or TRACE level in config")
  print("\nCommand line options:")
  print("  Run with '--debug' to see DEBUG level logs:")
  print("    lua examples/logging_example.lua --debug")
  print("  Run with '--verbose' to see all logs including TRACE:")
  print("    lua examples/logging_example.lua --verbose")
end

run_example()
