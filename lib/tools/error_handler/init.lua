--- Structured Error Handling Module for the Firmo Framework
---
--- Provides a comprehensive error handling system with standardized error objects,
--- contextual information, integrated logging, and test-aware behavior.
---
--- Features:
--- - Standardized error objects (`{ message, category, severity, timestamp, traceback?, context?, cause? }`).
--- - Error categories (`M.CATEGORY`) and severities (`M.SEVERITY`).
--- - Specialized error constructors (`validation_error`, `io_error`, etc.).
--- - Protected function execution (`M.try`).
--- - Safe I/O operation wrapper (`M.safe_io_operation`).
--- - Integrated logging (`M.log_error`) with configurable suppression in test environments.
--- - Stack trace capture and formatting (`M.format_error`).
--- - Assertion helper (`M.assert`).
--- - Error rethrowing (`M.rethrow`).
--- - Test context integration (`set/get_current_test_metadata`, `is_expected_test_error`, etc.).
---
--- @module lib.tools.error_handler
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class ErrorHandler The public API of the error handler module.
---@field CATEGORY table<string, string> Enum of error category constants (e.g., `VALIDATION`, `IO`).
---@field SEVERITY table<string, string> Enum of error severity constants (e.g., `FATAL`, `ERROR`, `WARNING`).
---@field _VERSION string Module version string.
---@field try_require fun(module_name: string): table Safely requires a Lua module.
---@field configure fun(options?: table): ErrorHandler Configures the error handler.
---@field configure_from_config fun(): ErrorHandler Configures from central config.
---@field create fun(message: string, category?: string, severity?: string, context?: table, cause?: any): table Creates a standardized error object.
---@field throw fun(message: string, category?: string, severity?: string, context?: table, cause?: any): nil Creates, logs, and throws an error. @throws table Always throws an error.
---@field validation_error fun(message: string, context?: table): table Creates a validation error object.
---@field io_error fun(message: string, context?: table, cause?: any): table Creates an I/O error object.
---@field runtime_error fun(message: string, context?: table, cause?: any): table Creates a runtime error object.
---@field parser_error fun(message: string, context?: table, cause?: any): table Creates a parser error object.
---@field test_expected_error fun(message: string, context?: table, cause?: any): table Creates an error object specifically for expected test failures.
---@field not_found_error fun(message: string, context?: table, cause?: any): table Creates a validation/not found error object.
---@field timeout_error fun(message: string, context?: table): table Creates a timeout error object.
---@field config_error fun(message: string, context?: table): table local M = {}

local M = {}

--- Module version
M._VERSION = "1.0.0"

-- Simple forward declarations for functions used before they're defined
local create_error -- Forward declaration for create_error function

-- Define internal modules to exclude when tracking error sources
local INTERNAL_MODULES = {
  ["lib/tools/error_handler"] = true,
  ["lib/assertion/init"] = true,
  ["lib/tools/test_helper"] = true,
  ["lib/core/test_definition"] = true,
}

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack_table = table.unpack or unpack

-- Lazy-load dependencies to avoid circular dependencies
local _logging, fs, logger
local function get_logging()
  if not _logging then
    _logging = M.try_require("lib.tools.logging")
  end
  return _logging
end

--- Get the filesystem module lazily to avoid circular dependencies
---@return table|nil The filesystem module if available
local function get_fs()
  if not fs then
    fs = M.try_require("lib.tools.filesystem")
  end
  return fs
end

-- Get a logger instance for this module
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("ErrorHandler")
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

-- Module configuration
local config = {
  use_assertions = true, -- Use Lua assertions for validation errors
  verbose = false, -- Verbose error messages
  trace_errors = true, -- Include traceback information
  log_all_errors = true, -- Log all errors through the logging system
  exit_on_fatal = false, -- Exit the process on fatal errors
  capture_backtraces = true, -- Capture stack traces for errors
  in_test_run = false, -- Are we currently running tests? (Set by test runner)
  suppress_test_assertions = true, -- Whether to suppress expected validation errors in tests
  suppress_all_logging_in_tests = true, -- Whether to suppress ALL console output during tests
  current_test_metadata = nil, -- Metadata for the currently running test (if any)
}

-- IMPORTANT: We DO NOT detect test mode automatically by pattern matching filenames.
-- Instead, the test runner explicitly sets test mode via M.set_test_mode()
-- This ensures reliability across different environments and file structures.
-- See scripts/runner.lua for the proper implementation.

-- Do NOT set test run mode here - it will be set explicitly by the test runner

-- Error severity levels
M.SEVERITY = {
  FATAL = "FATAL", -- Unrecoverable errors that require process termination
  ERROR = "ERROR", -- Serious errors that might allow the process to continue
  WARNING = "WARNING", -- Warnings that need attention but don't stop execution
  INFO = "INFO", -- Informational messages about error conditions
}

-- Error categories
M.CATEGORY = {
  VALIDATION = "VALIDATION", -- Input validation errors
  IO = "IO", -- File I/O errors
  PARSE = "PARSE", -- Parsing errors
  RUNTIME = "RUNTIME", -- Runtime errors
  TIMEOUT = "TIMEOUT", -- Timeout errors
  MEMORY = "MEMORY", -- Memory-related errors
  CONFIGURATION = "CONFIG", -- Configuration errors
  UNKNOWN = "UNKNOWN", -- Unknown errors
  TEST_EXPECTED = "TEST_EXPECTED", -- Errors that are expected during tests
}

--- Internal helper to get a traceback string.
---@param level? number Stack level offset (default 3).
---@return string|nil Traceback string or nil if disabled.
---@private
local function get_traceback(level)
  if not config.capture_backtraces then
    return nil
  end
  level = level or 3 -- Skip this function and the caller
  return debug.traceback("", level)
end

--- Find the most relevant error source by traversing the stack.
--- Skips internal framework modules to find the original source of errors.
--- @return table|nil The debug info for the most relevant source location
--- @private
local function find_error_source()
  local stack_level = 3 -- Start above our immediate caller
  local most_relevant = nil
  local internal_source = nil

  while true do
    local info = debug.getinfo(stack_level, "Sl")
    if not info then
      break
    end

    -- Always capture first internal source as fallback
    if not internal_source and info.short_src then
      local is_internal = false
      for pattern in pairs(INTERNAL_MODULES) do
        if info.short_src:match(pattern) then
          is_internal = true
          break
        end
      end

      if is_internal then
        internal_source = info
      end
    end

    -- If we find a non-internal source, that's our most relevant
    if info.short_src then
      local is_internal = false
      for pattern in pairs(INTERNAL_MODULES) do
        if info.short_src:match(pattern) then
          is_internal = true
          break
        end
      end

      if not is_internal then
        most_relevant = info
        break
      end
    end

    stack_level = stack_level + 1
  end

  -- If we found a most relevant source, store the internal source as additional context
  if most_relevant and internal_source then
    most_relevant.source_internal = internal_source
  end

  return most_relevant or internal_source
end

-- Internal helper to create an error object
create_error = function(message, category, severity, context, cause)
  local err = {
    message = message or "Unknown error",
    category = category or M.CATEGORY.UNKNOWN,
    severity = severity or M.SEVERITY.ERROR,
    timestamp = os.time(),
    traceback = get_traceback(),
    context = context or {},
    cause = cause, -- Original error that caused this one
  }

  -- Find the most relevant source location
  local source = find_error_source()
  if source then
    err.source_file = source.short_src
    err.source_line = source.currentline

    -- Store internal location in debug context if different
    if source.source_internal then
      if not err.context.internal_source then
        err.context.internal_source = {}
      end
      err.context.internal_source.file = source.source_internal.short_src
      err.context.internal_source.line = source.source_internal.currentline
    end
  end

  return err
end

--- Internal helper to format error object for logging/display (before export).
---@param err any Error object or value.
---@return string Formatted string.
---@private
local function format_error(err)
  if type(err) == "string" then
    return err
  end

  if type(err) ~= "table" then
    return tostring(err)
  end

  if not err.category and not err.message then
    return tostring(err)
  end

  local parts = {}
  table.insert(parts, "[" .. (err.severity or "ERROR") .. "]")

  if err.category then
    table.insert(parts, err.category .. ":")
  end

  table.insert(parts, err.message or "Unknown error")

  if err.source_file and err.source_line then
    -- Don't show internal source locations in normal messages
    local is_internal_source = false
    for pattern in pairs(INTERNAL_MODULES) do
      if err.source_file:match(pattern) then
        is_internal_source = true
        break
      end
    end

    if not is_internal_source then
      table.insert(parts, "(at " .. err.source_file .. ":" .. err.source_line .. ")")
    end
  end

  local verbose = config.verbose -- Use configuration to determine verbosity
  if verbose and err.context and next(err.context) then
    table.insert(parts, "\nContext: ")
    for k, v in pairs(err.context) do
      if k ~= "internal_source" then -- Skip internal_source in regular context output
        table.insert(parts, string.format("\n  %s: %s", k, tostring(v)))
      end
    end
  end

  return table.concat(parts, " ")
end

-- Add function to module
M.format_error = format_error

--- Rethrow an error with proper error level
---@param err table|string The error object or string to rethrow.
---@param context? table Additional context to merge into the error object.
---@return nil Never returns.
---@throws table Always throws an error based on `err`, potentially adding context and logging it.
function M.rethrow(err, context)
  -- Create a copy of the error to avoid modifying the original
  local error_to_throw

  if type(err) == "table" and err.message then
    -- Make a shallow copy of the original error keeping all fields
    error_to_throw = {}
    for k, v in pairs(err) do
      error_to_throw[k] = v
    end

    -- If there's context in the original error and it's a table, make a copy of that too
    if type(err.context) == "table" then
      error_to_throw.context = {}
      for k, v in pairs(err.context) do
        error_to_throw.context[k] = v
      end
    end

    -- If additional context was provided, merge it
    if context and type(context) == "table" then
      -- Initialize context table if needed
      error_to_throw.context = error_to_throw.context or {}
      -- Merge the additional context
      for k, v in pairs(context) do
        error_to_throw.context[k] = v
      end
    end

    -- Log the enhanced error
    M.log_error(error_to_throw)

    -- Then throw it
    error(error_to_throw.message, 2)
  elseif type(err) == "string" then
    -- For string errors, create a new error object with the message and context
    error_to_throw = create_error(err, M.CATEGORY.RUNTIME, M.SEVERITY.ERROR, context)

    -- Log the error
    M.log_error(error_to_throw)

    -- Throw the error
    error(err, 2)
  else
    -- Fallback for other types
    local err_str = tostring(err)
    error_to_throw = create_error(err_str, M.CATEGORY.UNKNOWN, M.SEVERITY.ERROR, context)

    -- Log the error
    M.log_error(error_to_throw)

    -- Throw it
    error(err_str, 2)
  end
end

-- REMOVED: Assert functions were moved to firmo.assert

--- Internal helper to log an error
---@param err table Error object to log
---@return nil
---@private
local function log_error(err)
  -- Lazy initialize logger if needed
  if not logger and config.log_all_errors ~= false then
    logger = get_logger()
  end

  -- Skip all error logging if config says not to log errors
  if not config.log_all_errors then
    return
  end

  -- IMMEDIATELY RETURN if we're in test mode and suppressing all logging
  if config.in_test_run and config.suppress_all_logging_in_tests then
    -- Store the error in a global table for potential debugging if needed
    _G._firmo_test_errors = _G._firmo_test_errors or {}
    table.insert(_G._firmo_test_errors, err)
    return
  end

  -- Convert to structured log
  local log_params = {
    category = err.category,
    context = err.context,
    source_file = err.source_file,
    source_line = err.source_line,
  }

  -- Add traceback in verbose mode
  if config.verbose and err.traceback then
    log_params.traceback = err.traceback
  end

  -- Add cause if available
  if err.cause then
    if type(err.cause) == "table" and err.cause.message then
      log_params.cause = err.cause.message
    else
      log_params.cause = tostring(err.cause)
    end
  end

  -- Check if we should suppress logging in test environment
  local log_level = "error"
  local suppress_logging = false
  local completely_skip_logging = false

  -- In test mode, we may suppress certain categories of errors
  -- This is the proper approach instead of unreliable pattern matching
  if config.in_test_run then
    -- Check if this is a test that expects errors
    if config.current_test_metadata and config.current_test_metadata.expect_error then
      -- If the current test explicitly expects errors, completely skip logging
      completely_skip_logging = true
    elseif config.suppress_test_assertions then
      -- Otherwise, only suppress logging for validation and test_expected errors
      if err.category == M.CATEGORY.VALIDATION or err.category == M.CATEGORY.TEST_EXPECTED then
        suppress_logging = true
      end
    end
  end

  if err.category == M.CATEGORY.TEST_EXPECTED then
    log_level = "debug"
  end

  -- When in a test with expect_error flag, handle errors specially
  if completely_skip_logging then
    -- Store the error in a global table for potential debugging if needed
    _G._firmo_test_errors = _G._firmo_test_errors or {}
    table.insert(_G._firmo_test_errors, err)

    -- Don't skip all logging - only downgrade ERROR and WARNING logs to DEBUG
    -- This allows explicit debug logging to still work
    if err.severity == M.SEVERITY.ERROR or err.severity == M.SEVERITY.WARNING then
      log_level = "debug"
    end

    -- Additionally check if debug logs are explicitly enabled
    local debug_enabled = logger.is_debug_enabled and logger.is_debug_enabled()
    if not debug_enabled then
      -- If debug logs aren't enabled, skip logging entirely
      return
    end
    -- Otherwise, continue with debug-level logging
  end

  -- Choose appropriate log level
  if err.severity == M.SEVERITY.FATAL then
    log_level = "error" -- Fatal errors are always logged at error level
  elseif err.severity == M.SEVERITY.ERROR then
    log_level = suppress_logging and "debug" or "error"
  elseif err.severity == M.SEVERITY.WARNING then
    log_level = suppress_logging and "debug" or "warn"
  else
    log_level = suppress_logging and "debug" or "info"
  end

  -- Log at the appropriate level
  if err.severity == M.SEVERITY.FATAL then
    logger.error("FATAL: " .. err.message, log_params)
  elseif log_level == "error" then
    logger.error(err.message, log_params)
  elseif log_level == "warn" then
    logger.warn(err.message, log_params)
  elseif log_level == "info" then
    logger.info(err.message, log_params)
  else -- debug
    logger.debug(err.message, log_params)
  end

  -- Handle fatal errors
  if err.severity == M.SEVERITY.FATAL and config.exit_on_fatal then
    os.exit(1)
  end
end

--- Internal helper to handle an error
---@param err table Error object.
---@return nil
---@return table err The error object passed in.
---@private
local function handle_error(err)
  -- Log the error
  log_error(err)

  -- Return the error as an object
  return nil, err
end

--- Configures the error handler settings.
---@param options? table Options table matching the structure of the internal `config` table.
---@return ErrorHandler self The module instance (`M`) for chaining.
function M.configure(options)
  if options then
    for k, v in pairs(options) do
      config[k] = v
    end
  end

  -- Configure from central_config if available
  local ok, central_config = pcall(require, "lib.core.central_config")
  if ok and central_config then
    -- Register our module with default configuration
    central_config.register_module("error_handler", {
      -- Schema definition
      field_types = {
        use_assertions = "boolean",
        verbose = "boolean",
        trace_errors = "boolean",
        log_all_errors = "boolean",
        exit_on_fatal = "boolean",
        capture_backtraces = "boolean",
        in_test_run = "boolean",
        suppress_test_assertions = "boolean",
      },
    }, {
      -- Default values (matching our local config)
      use_assertions = config.use_assertions,
      verbose = config.verbose,
      trace_errors = config.trace_errors,
      log_all_errors = config.log_all_errors,
      exit_on_fatal = config.exit_on_fatal,
      capture_backtraces = config.capture_backtraces,
      in_test_run = config.in_test_run,
      suppress_test_assertions = config.suppress_test_assertions,
    })

    -- Now get configuration (will include our defaults if not yet set)
    local error_handler_config = central_config.get("error_handler")
    if error_handler_config then
      for k, v in pairs(error_handler_config) do
        config[k] = v
      end
    end
  end

  --- Create a not found error object
  ---@param message string The error message
  ---@param context? table Additional context for the error
  ---@param cause? table|string The cause of the error
  ---@return table The not found error object
  function M.not_found_error(message, context, cause)
    return create_error(message, M.CATEGORY.VALIDATION, M.SEVERITY.ERROR, context, cause)
  end

  return M
end

--- Creates a standardized error object.
---@param message string The error message.
---@param category? string The error category (defaults to `M.CATEGORY.UNKNOWN`).
---@param severity? string The error severity (defaults to `M.SEVERITY.ERROR`).
---@param context? table Additional context for the error.
---@param cause? any The original cause of the error (another error object or value).
---@return table The structured error object.
function M.create(message, category, severity, context, cause)
  return create_error(message, category, severity, context, cause)
end

--- Creates, logs, and then throws a standardized error.
--- Adjusts category/severity based on context (e.g., `TEST_EXPECTED` in relevant test modes).
---@param message string The error message.
---@param category? string The error category (defaults to `M.CATEGORY.UNKNOWN`).
---@param severity? string The error severity (defaults to `M.SEVERITY.ERROR`).
---@param context? table Additional context for the error.
---@param cause? any The original cause of the error.
---@return nil Never returns.
---@throws table Always throws the created error object (or its message).
function M.throw(message, category, severity, context, cause)
  -- Determine the appropriate error category based on context
  local error_category = category
  local error_severity = severity

  -- 1. Check if the cause is a TEST_EXPECTED error, and if so, preserve that category
  if type(cause) == "table" and cause.category == M.CATEGORY.TEST_EXPECTED then
    error_category = M.CATEGORY.TEST_EXPECTED
  end

  -- 2. Check if the cause is in the context table
  if
    type(context) == "table"
    and type(context.error) == "table"
    and context.error.category == M.CATEGORY.TEST_EXPECTED
  then
    error_category = M.CATEGORY.TEST_EXPECTED
  end

  -- 3. Check if we're in a test context that expects errors
  local test_metadata = config.current_test_metadata
  if test_metadata and test_metadata.expect_error then
    -- Add test context information to the error context if not already present
    context = context or {}
    context.in_test_context = true
    context.test_name = test_metadata.name
    if test_metadata.caller_info then
      context.test_source_file = test_metadata.caller_info.source
      context.test_source_line = test_metadata.caller_info.currentline
    end
    
    -- For validation errors in tests with expect_error, preserve the category
    if category == M.CATEGORY.VALIDATION then
      -- Keep original category for explicit validation testing
      error_category = M.CATEGORY.VALIDATION
    else
      -- Use TEST_EXPECTED for other errors in test context
      error_category = M.CATEGORY.TEST_EXPECTED
    end
  elseif category == M.CATEGORY.VALIDATION and M.is_test_mode() then
    -- 4. If the error is for validation and we're in test context (without expect_error)
    -- Tests with validation errors should generally use TEST_EXPECTED
    error_category = M.CATEGORY.TEST_EXPECTED
  end

  -- Create the error with the determined category
  local err = create_error(message, error_category, error_severity, context, cause)

  -- Log the error - The logger will handle severity appropriately based on category
  -- In log_error(), TEST_EXPECTED errors are typically logged at debug level
  -- to avoid polluting test output with expected errors
  log_error(err)

  error(err.message, 2) -- Level 2 to point to the caller
end

--- Checks a condition and throws a standardized error if the condition is falsey.
---@param condition any The condition to check.
---@param message string The error message if the condition fails.
---@param category? string The error category (defaults to `M.CATEGORY.VALIDATION`).
---@param context? table Additional context for the error.
---@param cause? any The cause of the error.
---@return boolean `true` if the condition is truthy (the function does not throw).
---@throws table Throws a standardized error if the condition is falsey.
function M.assert(condition, message, category, context, cause)
  if not condition then
    local severity = M.SEVERITY.ERROR
    local err = create_error(message, category, severity, context, cause)
    log_error(err)

    if config.use_assertions then
      assert(false, err.message)
    else
      error(err.message, 2) -- Level 2 to point to the caller
    end
  end
  return condition -- Will only return true if no error was thrown
end

--- Safely call a function and catch any errors (try/catch pattern)
--- Executes a function in protected mode with proper error handling. This is the
--- primary error handling pattern throughout the Firmo framework, providing a
--- clean try/catch pattern with standardized error objects.
---
--- @param func function The function to execute safely
--- @param ... any Arguments to pass to the function
--- @return boolean success Whether the function execution succeeded
--- @return any result The function's first return value if successful, or the error object if failed.
--- @return ... any? Additional return values from the function if successful.
---
--- @usage
--- -- Basic usage:
--- local success, result, err = error_handler.try(function()
---   return potentially_failing_function()
--- end)
---
--- if not success then
---   -- Handle error (result contains the error object)
---   print("Error:", result.message)
---   return nil, result
--- else
---   -- Use the result
---   return result
--- end
---
--- -- With arguments:
--- local success, result = error_handler.try(function(a, b)
---   return a + b
--- end, 5, 10)
--- -- result will be 15 if successful
function M.try(func, ...)
  local result = { pcall(func, ...) }
  local success = table.remove(result, 1)

  if success then
    return true, unpack_table(result)
  else
    local err_message = result[1]

    -- Check if the error is already one of our error objects
    if type(err_message) == "table" and err_message.category then
      -- If this is already an error object, just log it and return it
      log_error(err_message)
      return false, err_message
    end

    -- Determine error category based on the error message or object
    local error_category = M.CATEGORY.RUNTIME
    local error_obj = nil

    -- Comprehensive TEST_EXPECTED detection

    -- Case 1: String errors with TEST_EXPECTED in the message
    if type(err_message) == "string" and string.match(err_message, "TEST_EXPECTED") then
      error_category = M.CATEGORY.TEST_EXPECTED
    end

    -- Case 2: Error is a table that might contain a cause with TEST_EXPECTED
    if type(err_message) == "table" then
      -- Check if it has a cause property with a category
      if type(err_message.cause) == "table" and err_message.cause.category == M.CATEGORY.TEST_EXPECTED then
        error_category = M.CATEGORY.TEST_EXPECTED
      end

      -- Check if any nested context contains TEST_EXPECTED errors
      if
        type(err_message.context) == "table"
        and type(err_message.context.error) == "table"
        and err_message.context.error.category == M.CATEGORY.TEST_EXPECTED
      then
        error_category = M.CATEGORY.TEST_EXPECTED
      end
    end

    -- Case 3: If the current test is marked with expect_error, categorize as TEST_EXPECTED
    if config.current_test_metadata and config.current_test_metadata.expect_error then
      error_category = M.CATEGORY.TEST_EXPECTED
    end

    -- Create an error object, preserving any potential nested error
    local err = create_error(
      tostring(err_message),
      error_category,
      M.SEVERITY.ERROR,
      { args = { ... } },
      type(err_message) == "table" and err_message or nil -- Preserve original error as cause if it's a table
    )

    log_error(err)
    return false, err
  end
end

--- Create a validation error object
--- Creates a standardized error object for validation failures, such as
--- invalid parameters, missing required values, or type mismatches.
--- Validation errors are automatically recognized by the test system and
--- can be suppressed in test environments that expect them.
---
--- @param message string The human-readable error message
--- @param context? table Additional context information (key-value pairs).
--- @return table The structured validation error object.
---
--- @usage
--- -- Basic validation error
--- if type(filename) ~= "string" then
---   return nil, error_handler.validation_error(
---     "Filename must be a string",
---     {parameter_name = "filename", provided_type = type(filename)}
---   )
--- end
function M.validation_error(message, context)
  return create_error(message, M.CATEGORY.VALIDATION, M.SEVERITY.ERROR, context)
end

--- Create an I/O error object
---@param message string The error message
---@param context? table Additional context for the error
---@param cause? any The underlying error (e.g., from `io.open`).
---@return table The I/O error object.
function M.io_error(message, context, cause)
  return create_error(message, M.CATEGORY.IO, M.SEVERITY.ERROR, context, cause)
end

--- Create a parse error object
---@param message string The error message
---@param context? table Additional context for the error
---@param cause? any The underlying error (e.g., from a parser).
---@return table The parse error object.
function M.parse_error(message, context, cause)
  return create_error(message, M.CATEGORY.PARSE, M.SEVERITY.ERROR, context, cause)
end

--- Create a timeout error object
---@param message string The error message
---@param context? table Additional context for the error
---@return table The timeout error object
function M.timeout_error(message, context)
  return create_error(message, M.CATEGORY.TIMEOUT, M.SEVERITY.ERROR, context)
end

--- Create a configuration error object
---@param message string The error message
---@param context? table Additional context for the error
---@return table The configuration error object
function M.config_error(message, context)
  return create_error(message, M.CATEGORY.CONFIGURATION, M.SEVERITY.ERROR, context)
end

--- Create a runtime error object
---@param message string The error message
---@param context? table Additional context for the error
---@param cause? any The underlying error.
---@return table The runtime error object.
function M.runtime_error(message, context, cause)
  return create_error(message, M.CATEGORY.RUNTIME, M.SEVERITY.ERROR, context, cause)
end

--- Create a fatal error object
---@param message string The error message
---@param category? string The error category (defaults to UNKNOWN)
---@param context? table Additional context for the error
---@param cause? any The underlying error.
---@return table The fatal error object.
function M.fatal_error(message, category, context, cause)
  return create_error(message, category or M.CATEGORY.UNKNOWN, M.SEVERITY.FATAL, context, cause)
end

--- Create a test expected error object (for use in test stubs, mocks, etc.)
---@param message string The error message
---@param context? table Additional context for the error
---@param cause? any The underlying expected error.
---@return table The test expected error object.
function M.test_expected_error(message, context, cause)
  return create_error(message, M.CATEGORY.TEST_EXPECTED, M.SEVERITY.ERROR, context, cause)
end

--- Safely attempts to require a Lua module using `try`.
--- This function wraps the standard `require` function in a protected call,
--- capturing any errors that occur during module loading.
---
--- @param module_name string The name of the module to require (e.g., "lib.tools.filesystem").
--- @return table module The loaded module table if successful.
function M.try_require(module_name)
  local success, result = M.try(require, module_name)

  if success then
    -- Return module on success
    return result
  else
    M.throw(
      "Failed to load essential dependency: " .. module_name,
      M.CATEGORY.RUNTIME,
      M.SEVERITY.FATAL,
      { module_name = module_name },
      result
    )
    print("FATAL: Exiting due to essential dependency load failure: " .. module_name)
    os.exit(1)
  end
end

--- Safely execute an I/O operation with proper error handling
--- Wraps file system operations with standardized error handling, automatically
--- adding the file path to error context and creating detailed I/O error objects.
--- This is the preferred way to perform any file operations throughout the framework.
---
--- @param operation function The I/O operation function to execute (must return result, err pattern)
--- @param file_path string The file path being operated on
--- @param context? table Additional context information for error reporting
--- @param transform_result? fun(result:any):any Optional function to transform the success result
--- @return any|nil result The result of the operation or nil on error
--- @return any|nil result The result of the operation (potentially transformed), or `nil` on error.
--- @return table|nil error_obj The structured error object on failure, `nil` on success.
---
--- @usage
--- -- Read a file safely
--- local content, err = error_handler.safe_io_operation(
---   function() return get_fs().read_file("config.json") end,
---   "config.json",
---   {operation = "read_config"}
--- )
---
--- if not content then
---   -- Handle error
---   print("Failed to read config: " .. err.message)
---   return nil, err
--- end
---
--- -- With result transformation
--- local data, err = error_handler.safe_io_operation(
---   function() return get_fs().read_file("config.json") end,
---   "config.json",
---   {operation = "parse_config"},
---   function(content) return json.decode(content) end
--- )
function M.safe_io_operation(operation, file_path, context, transform_result)
  transform_result = transform_result or function(result)
    return result
  end

  local result, err = operation()

  if result ~= nil or err == nil then
    -- Either operation succeeded (result is not nil) or
    -- operation returned nil, nil (no error, just negative result, e.g., file doesn't exist)
    return transform_result(result)
  end

  -- Add file path to context
  context = context or {}
  context.file_path = file_path

  -- Create an I/O error
  local error_obj = M.io_error((err or "I/O operation failed: ") .. tostring(file_path), context, err)

  -- Log and return
  log_error(error_obj)
  return nil, error_obj
end

--- Checks if a value appears to be a structured error object created by this module
--- by checking for the presence of key fields (`message`, `category`, `severity`).
---@param value any The value to check.
---@return boolean `true` if the value looks like a structured error object, `false` otherwise.
function M.is_error(value)
  return type(value) == "table" and value.message ~= nil and value.category ~= nil and value.severity ~= nil
end

-- Add a metatable to error objects for better string conversion
local mt = {
  __tostring = function(err)
    if type(err) == "table" and err.message then
      return err.message
    else
      return tostring(err)
    end
  end,
}

local original_create_error = create_error
--- Internal helper to create a standardized error object with metatable.
---@param message string Error message.
---@param category? string Error category.
---@param severity? string Error severity.
---@param context? table Error context.
---@param cause? any Original cause.
---@return table The error object.
---@private
create_error = function(message, category, severity, context, cause)
  local err = original_create_error(message, category, severity, context, cause)
  return setmetatable(err, mt)
end

--- Formats an error object or any value into a human-readable string.
--- Includes severity, category, message, source location, context, cause, and optional traceback.
---@param err any The error object or value to format.
---@param include_traceback? boolean If `true`, include the stack traceback in the output (if available).
---@return string The formatted error string.
function M.format_error(err, include_traceback)
  if not M.is_error(err) then
    if type(err) == "string" then
      return err
    else
      return tostring(err)
    end
  end

  local parts = {
    string.format("[%s] %s: %s", err.severity, err.category, err.message),
  }

  -- Add source location if available
  if err.source_file and err.source_line then
    table.insert(parts, string.format(" (at %s:%d)", err.source_file, err.source_line))
  end

  -- Add context if available and not empty
  if err.context and next(err.context) then
    table.insert(parts, "\nContext:")
    for k, v in pairs(err.context) do
      table.insert(parts, string.format("  %s: %s", k, tostring(v)))
    end
  end

  -- Add cause if available
  if err.cause then
    if type(err.cause) == "table" and err.cause.message then
      table.insert(parts, "\nCaused by: " .. err.cause.message)
    else
      table.insert(parts, "\nCaused by: " .. tostring(err.cause))
    end
  end

  -- Add traceback if requested and available
  if include_traceback and err.traceback then
    table.insert(parts, "\nTraceback:" .. err.traceback)
  end

  return table.concat(parts, "")
end

-- Export log_error function for internal use by other module functions
M.log_error = log_error

--- Configures the error handler using settings from the central configuration system.
--- Loads central config, registers schema/defaults if needed, and applies the configuration.
---@return ErrorHandler self The module instance (`M`) for chaining.
function M.configure_from_config()
  -- Try to load central_config directly
  local ok, central_config = pcall(require, "lib.core.central_config")
  if ok and central_config then
    -- Register our module with central_config if not already done
    central_config.register_module("error_handler", {
      -- Schema definition
      field_types = {
        use_assertions = "boolean",
        verbose = "boolean",
        trace_errors = "boolean",
        log_all_errors = "boolean",
        exit_on_fatal = "boolean",
        capture_backtraces = "boolean",
        in_test_run = "boolean",
        suppress_test_assertions = "boolean",
      },
    }, {
      -- Default values (matching our local config)
      use_assertions = config.use_assertions,
      verbose = config.verbose,
      trace_errors = config.trace_errors,
      log_all_errors = config.log_all_errors,
      exit_on_fatal = config.exit_on_fatal,
      capture_backtraces = config.capture_backtraces,
      in_test_run = config.in_test_run,
      suppress_test_assertions = config.suppress_test_assertions,
    })

    -- Get the centralized configuration
    local error_handler_config = central_config.get("error_handler")
    if error_handler_config then
      M.configure(error_handler_config)
    end
  end
  --- Create a not found error object
  ---@param message string The error message
  ---@param context? table Additional context for the error
  ---@param cause? table|string The cause of the error
  ---@return table The not found error object
  function M.not_found_error(message, context, cause)
    return create_error(message, M.CATEGORY.VALIDATION, M.SEVERITY.ERROR, context, cause)
  end

  return M
end

--- Sets the internal flag indicating whether Firmo is running in a test environment.
--- This affects error logging and potentially assertion behavior.
--- Should be called by the test runner.
---@param enabled boolean `true` to enable test mode, `false` to disable.
---@return boolean enabled The new state of the test mode flag.
function M.set_test_mode(enabled)
  config.in_test_run = enabled and true or false

  -- Update central_config if available
  local ok, central_config = pcall(require, "lib.core.central_config")
  if ok and central_config then
    central_config.set("error_handler.in_test_run", config.in_test_run)

    -- We'll handle logging suppression locally through our module
  end

  -- Don't try to configure logging directly - use its own methods
  -- This can cause circular dependencies and type issues

  return config.in_test_run
end

--- Checks if the internal test mode flag is currently enabled.
---@return boolean is_test_mode `true` if test mode is active, `false` otherwise.
function M.is_test_mode()
  return config.in_test_run
end

--- Checks if logging is currently being suppressed due to test mode configuration
--- (`config.in_test_run` and `config.suppress_all_logging_in_tests` are both true).
---@return boolean is_suppressed `true` if logging is suppressed, `false` otherwise.
function M.is_suppressing_test_logs()
  return config.in_test_run and config.suppress_all_logging_in_tests
end

--- Determines if a given error object should be considered an "expected" error within the current test context.
--- Checks the error's category (`VALIDATION` or `TEST_EXPECTED`) and if the current test metadata includes `expect_error = true`.
---@param err table The structured error object to check.
---@return boolean is_expected `true` if the error is considered expected, `false` otherwise.
function M.is_expected_test_error(err)
  if not M.is_error(err) then
    return false
  end

  -- Expected test errors are VALIDATION errors or explicitly marked TEST_EXPECTED errors
  local is_expected_category = err.category == M.CATEGORY.VALIDATION or err.category == M.CATEGORY.TEST_EXPECTED

  -- Check for test metadata with expect_error flag
  -- Tests with { expect_error = true } flag have ALL error logging completely suppressed
  -- This is different from tests that lack the flag, where only validation/test_expected errors are suppressed
  if config.current_test_metadata and config.current_test_metadata.expect_error then
    get_logger().debug("Expected test error detected via test metadata", {
      error_category = err.category,
      metadata_name = config.current_test_metadata.name,
      expect_error = true,
    })
    return true
  end

  return is_expected_category
end

--- Sets metadata associated with the currently executing test.
--- Used by `log_error` and `is_expected_test_error` to adjust behavior based on test context (e.g., `expect_error` flag).
--- Should be called by the test runner before and after each test execution.
---@param metadata table|nil The test metadata table (e.g., `{ name = "...", expect_error = true, preserve_category = true, expected_category = "VALIDATION" }`) or `nil` to clear.
---@return table|nil metadata The metadata that was just set, or `nil` if cleared.
function M.set_current_test_metadata(metadata)
  -- Log the metadata change
  if metadata then
    get_logger().debug("Setting test metadata", {
      metadata_name = metadata.name,
      expect_error = metadata.expect_error or false,
      preserve_category = metadata.preserve_category or false,
      expected_category = metadata.expected_category,
    })
  else
    get_logger().debug("Clearing test metadata")
  end

  config.current_test_metadata = metadata

  -- Update central_config if available
  local ok, central_config = pcall(require, "lib.core.central_config")
  if ok and central_config then
    central_config.set("error_handler.current_test_metadata", config.current_test_metadata)
  end

  return config.current_test_metadata
end

--- Gets the metadata associated with the currently executing test.
--- Returns a default table `{ expect_error = false, name = "(no active test)" }` if no metadata is currently set.
---@return table metadata The current test metadata table.
function M.get_current_test_metadata()
  -- Return the current metadata or default with expect_error=false
  return config.current_test_metadata or {
    expect_error = false,
    name = "(no active test)",
  }
end

--- Checks if the currently set test metadata indicates that the test expects an error (`expect_error == true`).
---@return boolean expects_errors `true` if the current test expects an error, `false` otherwise.
function M.current_test_expects_errors()
  return config.current_test_metadata ~= nil and config.current_test_metadata.expect_error == true or false
end

--- Retrieves the list of errors that were logged while `expect_error` was active for the current test context.
--- These are errors logged via `log_error` but potentially suppressed from console output.
---@return table[] errors An array containing the captured error objects. Returns empty table if none captured.
function M.get_expected_test_errors()
  return _G._firmo_test_expected_errors or {}
end

--- Clears the internal list of captured expected errors (`_G._firmo_test_expected_errors`).
--- Should be called by the test runner, typically after a test finishes.
---@return boolean success Always returns `true`.
function M.clear_expected_test_errors()
  _G._firmo_test_expected_errors = {}
  return true
end

-- Automatically configure from global config if available
M.configure_from_config()

--- Creates a validation error object, often used specifically for "not found" scenarios.
---@param message string The error message (e.g., "File not found").
---@param context? table Additional context (e.g., `{ path = "..." }`).
---@param cause? any Optional underlying cause.
---@return table The validation error object.
function M.not_found_error(message, context, cause)
  return create_error(message, M.CATEGORY.VALIDATION, M.SEVERITY.ERROR, context, cause)
end

return M
