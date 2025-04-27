--- Logging and Formatter Integration
---
--- Integrates the Firmo logging system with test output formatters, allowing
--- formatters to log messages. Also provides a factory for creating loggers
--- with attached test context.
---
--- @module lib.tools.logging.formatter_integration
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class LogFormatterIntegration The public API for the logging/formatter integration module.
---@field _VERSION string Module version.
---@field enhance_formatters fun(): table|nil, string? Enhances all registered formatters in `lib.reporting.formatters` with logging methods. Returns the formatters table or `nil, error_message`. @throws error If logger cannot be created.
---@field create_test_logger fun(test_name: string, test_context: table): table Creates a logger instance wrapped to automatically include test context in log entries.
---@field integrate_with_reporting fun(options?: table): table|nil, string? Patches the `lib.reporting` module to add logging around key reporting actions. Returns the patched reporting module or `nil, error_message`. @throws error If logger cannot be created or original function calls fail.
---@field create_log_formatter fun(): table|nil, string? Creates a specialized formatter instance designed for writing structured logs (JSON or text) to a file. Returns the formatter object or `nil, error_message`. @throws table If formatter module not available, directory creation fails, or file writing fails critically.
local M = {}
M._VERSION = "1.0.0"

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
    return logging.get_logger("assertion")
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

--- Gets a logger instance specifically named for a formatter.
---@param formatter_name string The name of the formatter (e.g., "html", "json").
---@return table logger A logger instance (from `lib.tools.logging`).
---@private
local function get_formatter_logger(formatter_name)
  return get_logger("formatter." .. formatter_name)
end

--- Helper function to get sorted keys from a table.
---@param tbl table Input table.
---@return string[] Sorted keys array.
---@private
local function get_table_keys(tbl)
  local keys = {}
  if type(tbl) == "table" then
    for k, _ in pairs(tbl) do
      table.insert(keys, tostring(k))
    end
    table.sort(keys)
  end
  return keys
end

-- Note: We removed deep_copy function as it's not needed
--- Adds logging methods (log_info, log_debug, etc.) directly to a formatter object.
---@param formatter table The formatter object/table to enhance.
---@param name string The name of the formatter (for logging context).
---@param registry_type string The type of registry it belongs to ("coverage", "quality", "results").
---@return table formatter The enhanced formatter object. Returns original object if input not a table.
---@private
local function enhance_formatter(formatter, name, registry_type)

  -- Only enhance if it's actually a table
  if type(formatter) ~= "table" then
    get_formatter_logger().warn("Cannot enhance non-table formatter", {
      name = name,
      type = type(formatter),
    })
    return formatter
  end

  -- Log what we're enhancing
  get_formatter_logger().debug("Enhancing formatter", {
    name = name,
    registry = registry_type,
    formatter_type = formatter.type,
    formatter_name = formatter.name,
  })

  -- Add logging capabilities directly to the formatter
  formatter._logger = get_formatter_logger()

  formatter.log_debug = function(self, message, params)
    self._logger.debug(message, params)
  end

  formatter.log_info = function(self, message, params)
    self._logger.info(message, params)
  end

  formatter.log_error = function(self, message, params)
    self._logger.error(message, params)
  end

  formatter.log_warn = function(self, message, params)
    self._logger.warn(message, params)
  end

  -- Log successful enhancement
  get_formatter_logger().debug("Formatter enhancement complete", {
    name = name,
    registry = registry_type,
    type = formatter.type,
    has_logger = formatter._logger ~= nil,
  })

  return formatter
end

--- Enhances all registered formatters in the main `lib.reporting.formatters` registry
--- by adding logging methods (`log_info`, `log_debug`, etc.) to each formatter object.
--- Patches the formatter registry's `init` function to ensure future formatters are also enhanced.
---@return table|nil formatters The enhanced formatters registry table, or `nil` if the registry module is unavailable.
---@return string? error_message Error message if the formatters module could not be loaded.
---@throws error If `get_formatter_logger` fails.
function M.enhance_formatters()
  -- Get formatters module inside the function to honor any mocking
  local formatters = try_require("lib.reporting.formatters")

  -- Return error if formatters module is not available
  if not formatters then
    return nil, "Formatters module not available"
  end

  -- Save original init function
  local original_init = formatters.init

  -- Log initial state
  get_formatter_logger().debug("Starting formatter enhancement", {
    has_coverage = formatters.coverage ~= nil,
    coverage_test = formatters.coverage and formatters.coverage.test ~= nil,
    test_type = formatters.coverage and formatters.coverage.test and formatters.coverage.test.type,
    test_name = formatters.coverage and formatters.coverage.test and formatters.coverage.test.name,
  })

  -- Work directly with formatters table, no need for local references
  -- Enhance formatters in coverage registry if it exists
  if formatters.coverage then
    for name, formatter in pairs(formatters.coverage) do
      get_formatter_logger().debug("Enhancing coverage formatter", {
        name = name,
        type = formatter.type,
        has_logger = formatter._logger ~= nil,
      })
      -- Enhance in place without reassignment
      enhance_formatter(formatter, name, "coverage")
      get_formatter_logger().debug("Enhanced coverage formatter", {
        name = name,
        type = formatter.type,
        has_logger = formatter._logger ~= nil,
      })
    end
  end

  -- Enhance formatters in quality registry if it exists
  if formatters.quality then
    for name, formatter in pairs(formatters.quality) do
      enhance_formatter(formatter, name, "quality")
    end
  end

  -- Enhance formatters in results registry if it exists
  if formatters.results then
    for name, formatter in pairs(formatters.results) do
      enhance_formatter(formatter, name, "results")
    end
  end

  -- Override formatter initialization to handle runtime additions
  formatters.init = function(...)
    get_formatter_logger().debug("Formatter initialization triggered")

    -- Call original init if it exists
    if type(original_init) == "function" then
      local success, result = pcall(original_init, ...)
      if not success then
        logger.error("Original init failed", { error = result })
        return false
      end
      if not result then
        return false
      end
    end

    return true
  end

  -- Final verification
  get_formatter_logger().debug("Enhancement complete", {
    has_coverage = formatters.coverage ~= nil,
    coverage_test = formatters.coverage and formatters.coverage.test ~= nil,
    test_type = formatters.coverage and formatters.coverage.test and formatters.coverage.test.type,
    test_name = formatters.coverage and formatters.coverage.test and formatters.coverage.test.name,
  })

  return formatters
end

--- Creates a logger instance that automatically includes test context (`test_name` and fields from `test_context`)
--- in the `params` table of every log entry. Also provides `.step()` and `.with_context()` methods.
---@param test_name string The name of the test.
---@param test_context table A table containing additional context (e.g., `{ file = "path", tags = {} }`).
---@return table test_logger A logger instance with context-aware methods (debug, info, warn, error, fatal, trace, step, with_context).
function M.create_test_logger(test_name, test_context)
  -- Clean test name for use as module name
  local module_name = "test." .. (test_name:gsub("%s+", "_"):gsub("[^%w_]", ""))

  -- Get a logger for this test
  local logger = get_logging().get_logger(module_name)

  -- Create wrapper that adds test context
  local test_logger = {}

  -- Define logging methods with test context
  for _, level in ipairs({ "fatal", "error", "warn", "info", "debug", "trace" }) do
    test_logger[level] = function(message, params)
      params = params or {}

      -- Add test context to params
      params.test_name = test_name

      -- Add test context elements
      if test_context then
        for k, v in pairs(test_context) do
          -- Avoid overwriting explicit parameters
          if params[k] == nil then
            params[k] = v
          end
        end
      end

      -- Log with enhanced context
      logger[level](message, params)
    end
  end

  -- Add context management
  test_logger.with_context = function(additional_context)
    -- Merge contexts
    local new_context = {}
    if test_context then
      for k, v in pairs(test_context) do
        new_context[k] = v
      end
    end

    if additional_context then
      for k, v in pairs(additional_context) do
        new_context[k] = v
      end
    end

    -- Create new logger with merged context
    return M.create_test_logger(test_name, new_context)
  end

  -- Add step method for test steps
  test_logger.step = function(step_name)
    -- Log the step
    logger.info("Starting test step", {
      step = step_name,
    })

    -- Return a step-specific logger
    return test_logger.with_context({
      step = step_name,
    })
  end

  return test_logger
end

--- Integrates logging with the reporting module by patching key reporting functions
--- (`test_start`, `test_end`, `generate`) to log information before and after execution.
---@param options? table Optional configuration (currently unused).
---@return table|nil reporting_module The patched `lib.reporting` module instance, or `nil` if the reporting module is unavailable.
---@return string? error_message Error message if the reporting module could not be loaded.
---@throws error If `get_formatter_logger` fails or if the original reporting function calls fail within the wrapper.
function M.integrate_with_reporting(options)
  options = options or {}

  -- Load reporting module
  local reporting = get_error_handler().try_require("lib.reporting")

  -- Create a logger for the reporting module
  local report_logger = get_logging().get_logger("reporting")

  -- Log options for the integration
  report_logger.debug("Integrating logging with reporting", options)

  -- Enhanced test start
  local original_test_start = reporting.test_start
  reporting.test_start = function(test_data)
    -- Call original function
    local result = original_test_start(test_data)

    -- Log test start
    report_logger.info("Test started", {
      test_name = test_data.name,
      test_file = test_data.file,
      tags = test_data.tags,
    })

    return result
  end

  -- Enhanced test end
  local original_test_end = reporting.test_end
  reporting.test_end = function(test_data)
    -- Call original function
    local result = original_test_end(test_data)

    -- Log test end
    report_logger.info("Test complete", {
      test_name = test_data.name,
      status = test_data.status,
      duration_ms = test_data.duration,
      assertions = test_data.assertions_count,
      error = test_data.error,
    })

    return result
  end

  -- Enhanced report generation
  local original_generate = reporting.generate
  reporting.generate = function(report_data, formats)
    -- Log report generation
    report_logger.info("Generating reports", {
      test_count = report_data.tests and #report_data.tests or 0,
      formats = formats,
      success_rate = report_data.success_percent,
    })

    -- Call original function
    local result = original_generate(report_data, formats)

    -- Log completion
    report_logger.info("Reports generated", {
      formats = formats,
      output_files = result.output_files,
    })

    return result
  end

  return reporting
end

--- Creates a specialized formatter instance specifically designed for writing structured logs to a file.
--- Can output in JSON or a simple text format.
---@return table|nil log_formatter A formatter object with `init`, `format`, `format_json`, `format_text`, `format_coverage`, `format_quality`, `format_results` methods, or `nil` if the base formatter module is unavailable.
---@return string? error_message Error message if the base formatter module could not be loaded.
---@throws table If required modules (`filesystem`, `logging`) are unavailable, or if file operations fail critically during formatting/writing.
function M.create_log_formatter()
  -- Get formatters module inside the function to honor any mocking
  local formatters = get_error_handler().try_require("lib.reporting.formatters")

  -- Define the formatter
  local log_formatter = {
    name = "log",
    description = "Log-optimized formatter that outputs structured data for logs",

    -- Initialize formatter
    init = function(self, options)
      options = options or {}
      self.options = options
      self.logger = get_formatter_logger("log")

      self.logger.info("Log formatter initialized", {
        output_file = options.output_file,
        format = options.format or "json",
      })

      return self
    end,

    format = function(self, results)
      -- Log the formatting operation
      self.logger.debug("Formatting test results", {
        test_count = results.tests and #results.tests or 0,
        success_rate = results.success_percent,
      })

      -- Format as JSON or text based on options
      if self.options.format == "json" then
        return self:format_json(results)
      else
        return self:format_text(results)
      end
    end,

    -- Generate JSON output
    format_json = function(self, results)
      -- Prepare output file path
      local output_file = self.options.output_file or "test-results.log.json"

      -- Ensure parent directory exists
      local dir = get_fs().get_directory_name(output_file)
      if dir and dir ~= "" then
        local success, err = get_fs().ensure_directory_exists(dir)
        if not success then
          self.logger.error("Failed to create parent directory", {
            directory = dir,
            error = err,
          })
          return nil, "Failed to create parent directory: " .. (err or "unknown error")
        end
      end

      -- Build output content
      local content = '{"test_results":[' .. "\n"

      -- Add each test result
      for i, test in ipairs(results.tests or {}) do
        -- Convert test to JSON
        local json = '{"name":"' .. (test.name or ""):gsub('"', '\\"') .. '"'
        json = json .. ',"status":"' .. (test.status or "unknown") .. '"'
        json = json .. ',"duration":' .. (test.duration or 0)
        json = json .. ',"file":"' .. (test.file or ""):gsub('"', '\\"') .. '"'

        -- Add error if present
        if test.error then
          json = json .. ',"error":"' .. tostring(test.error):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
        end

        -- Add tags if present
        if test.tags and #test.tags > 0 then
          json = json .. ',"tags":["' .. table.concat(test.tags, '","') .. '"]'
        end

        -- Close the test entry
        json = json .. "}"

        -- Add comma between entries
        if i < #results.tests then
          json = json .. ","
        end

        content = content .. json .. "\n"
      end

      -- Add summary
      content = content
        .. '],"summary":{"total":'
        .. results.total
        .. ',"passed":'
        .. results.passed
        .. ',"failed":'
        .. results.failed
        .. ',"pending":'
        .. results.pending
        .. ',"success_percent":'
        .. results.success_percent
        .. ',"duration":'
        .. results.duration
        .. "}}"

      -- Write content to file
      local success, err = get_fs().write_file(output_file, content)
      if not success then
        self.logger.error("Failed to write output file", {
          output_file = output_file,
          error = err,
        })
        return nil, "Failed to write output file: " .. (err or "unknown error")
      end

      -- Log completion
      self.logger.info("JSON log output complete", {
        output_file = output_file,
        test_count = #results.tests,
      })

      return { output_file = output_file }
    end,

    -- Generate text output
    format_text = function(self, results)
      -- Prepare output file path
      local output_file = self.options.output_file or "test-results.log.txt"

      -- Ensure parent directory exists
      local dir = get_fs().get_directory_name(output_file)
      if dir and dir ~= "" then
        local success, err = get_fs().ensure_directory_exists(dir)
        if not success then
          self.logger.error("Failed to create parent directory", {
            directory = dir,
            error = err,
          })
          return nil, "Failed to create parent directory: " .. (err or "unknown error")
        end
      end

      -- Build output content
      local content = "TEST RESULTS\n" .. string.rep("-", 80) .. "\n\n"

      -- Add each test result
      for _, test in ipairs(results.tests or {}) do
        content = content .. string.format("Test: %s\n", test.name or "")
        content = content .. string.format("Status: %s\n", test.status or "unknown")
        content = content .. string.format("Duration: %.3fms\n", test.duration or 0)
        content = content .. string.format("File: %s\n", test.file or "")

        -- Add tags if present
        if test.tags and #test.tags > 0 then
          content = content .. string.format("Tags: %s\n", table.concat(test.tags, ", "))
        end

        -- Add error if present
        if test.error then
          content = content .. "Error: " .. tostring(test.error) .. "\n"
        end

        content = content .. "\n"
      end

      -- Add summary
      content = content .. "SUMMARY\n" .. string.rep("-", 80) .. "\n"
      content = content .. string.format("Total: %d tests\n", results.total)
      content = content .. string.format("Passed: %d tests\n", results.passed)
      content = content .. string.format("Failed: %d tests\n", results.failed)
      content = content .. string.format("Pending: %d tests\n", results.pending)
      content = content .. string.format("Success Rate: %.1f%%\n", results.success_percent)
      content = content .. string.format("Total Duration: %.3fms\n", results.duration)

      -- Write content to file
      local success, err = get_fs().write_file(output_file, content)
      if not success then
        self.logger.error("Failed to write output file", {
          output_file = output_file,
          error = err,
        })
        return nil, "Failed to write output file: " .. (err or "unknown error")
      end

      -- Log completion
      self.logger.info("Text log output complete", {
        output_file = output_file,
        test_count = #results.tests,
      })

      return { output_file = output_file }
    end,

    -- Specific formatter for coverage reports
    format_coverage = function(self, coverage_data)
      self.logger.debug("Formatting coverage results", {
        file_count = coverage_data.files and #coverage_data.files or 0,
        total_coverage = coverage_data.total_coverage,
      })
      return self:format(coverage_data)
    end,

    -- Specific formatter for quality reports
    format_quality = function(self, quality_data)
      self.logger.debug("Formatting quality results", {
        rule_count = quality_data.rules and #quality_data.rules or 0,
        quality_score = quality_data.quality_score,
      })
      return self:format(quality_data)
    end,

    -- Specific formatter for test results
    format_results = function(self, results_data)
      self.logger.debug("Formatting test results", {
        test_count = results_data.tests and #results_data.tests or 0,
        success_rate = results_data.success_percent,
      })
      return self:format(results_data)
    end,
  }

  -- Register the formatter for each report type directly in the appropriate registry
  if formatters then
    -- Add formatters to the appropriate registries as properly structured objects
    if formatters.coverage then
      formatters.coverage["log"] = {
        type = "coverage",
        name = "log",
        format = log_formatter.format_coverage,
        description = "Log-optimized coverage formatter",
      }
    end

    if formatters.quality then
      formatters.quality["log"] = {
        type = "quality",
        name = "log",
        format = log_formatter.format_quality,
        description = "Log-optimized quality formatter",
      }
    end

    if formatters.results then
      formatters.results["log"] = {
        type = "results",
        name = "log",
        format = log_formatter.format_results,
        description = "Log-optimized results formatter",
      }
    end
  end

  return log_formatter
end

return M
