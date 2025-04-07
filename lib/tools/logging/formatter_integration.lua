---@class LogFormatterIntegration
---@field _VERSION string Module version
---@field enhance_formatters fun(): boolean Enable logging integration for all formatters
---@field create_test_logger fun(test_name: string, test_context: table): table Create a logger with test context
---@field integrate_with_reporting fun(options?: table): table Integrate logging with the reporting system
---@field create_log_formatter fun(): table Create a specialized formatter for log output

-- Integration between logging system and test output formatters
-- This module enhances test output with structured logging information

local M = {}
M._VERSION = "1.0.0"

-- Try to load modules
local function try_require(module_name)
  local success, module = pcall(require, module_name)
  if success then
    return module
  end
  return nil
end

-- Load required modules
---@type Logging|nil
local logging = try_require("lib.tools.logging")
---@type Formatters|nil
local formatters = try_require("lib.reporting.formatters")
---@type Filesystem
local fs = require("lib.tools.filesystem")

-- Get a formatter-specific logger
local function get_formatter_logger(formatter_name)
  if not logging then
    return nil, "Logging module not available"
  end

  return logging.get_logger("formatter." .. formatter_name)
end

-- Enhance formatters with logging capabilities
function M.enhance_formatters()
  if not formatters then
    return nil, "Formatters module not available"
  end

  -- Save original formatter initialization
  local original_init = formatters.init

  -- Override formatter initialization to add logging
  formatters.init = function(...)
    -- Call the original initialization
    local result = original_init(...)

    -- Enhance each formatter with a logger
    for name, formatter in pairs(formatters.available_formatters) do
      -- Create a formatter-specific logger
      local logger = get_formatter_logger(name)

      if logger then
        -- Attach logger to formatter
        formatter._logger = logger

        -- Add logging helper methods
        formatter.log_debug = function(self, message, params)
          if self._logger then
            self._logger.debug(message, params)
          end
        end

        formatter.log_info = function(self, message, params)
          if self._logger then
            self._logger.info(message, params)
          end
        end

        formatter.log_error = function(self, message, params)
          if self._logger then
            self._logger.error(message, params)
          end
        end

        -- Log formatter initialization
        logger.info("Formatter initialized", {
          name = name,
          type = formatter.type or "unknown",
        })
      end
    end

    return result
  end

  return formatters
end

-- Create a logger that adds test context to log messages
function M.create_test_logger(test_name, test_context)
  if not logging then
    return nil, "Logging module not available"
  end

  -- Clean test name for use as module name
  local module_name = "test." .. (test_name:gsub("%s+", "_"):gsub("[^%w_]", ""))

  -- Get a logger for this test
  local logger = logging.get_logger(module_name)

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

-- Integrate with the test reporting system
function M.integrate_with_reporting(options)
  options = options or {}

  if not logging then
    return nil, "Logging module not available"
  end

  -- Load reporting module
  local reporting = try_require("lib.reporting")
  if not reporting then
    return nil, "Reporting module not available"
  end

  -- Create a logger for the reporting module
  local report_logger = logging.get_logger("reporting")

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

-- Create a specialized formatter for log-friendly output
function M.create_log_formatter()
  if not formatters then
    return nil, "Formatters module not available"
  end

  -- Define the formatter
  local log_formatter = {
    name = "log",
    description = "Log-optimized formatter that outputs structured data for logs",

    -- Initialize formatter
    init = function(self, options)
      options = options or {}
      self.options = options
      self.logger = get_formatter_logger("log")

      if self.logger then
        self.logger.info("Log formatter initialized", {
          output_file = options.output_file,
          format = options.format or "json",
        })
      end

      return self
    end,

    -- Format test results
    format = function(self, results)
      -- Log the formatting operation
      if self.logger then
        self.logger.debug("Formatting test results", {
          test_count = results.tests and #results.tests or 0,
          success_rate = results.success_percent,
        })
      end

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
      local dir = fs.get_directory_name(output_file)
      if dir and dir ~= "" then
        local success, err = fs.ensure_directory_exists(dir)
        if not success then
          if self.logger then
            self.logger.error("Failed to create parent directory", {
              directory = dir,
              error = err,
            })
          end
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
      local success, err = fs.write_file(output_file, content)
      if not success then
        if self.logger then
          self.logger.error("Failed to write output file", {
            output_file = output_file,
            error = err,
          })
        end
        return nil, "Failed to write output file: " .. (err or "unknown error")
      end

      -- Log completion
      if self.logger then
        self.logger.info("JSON log output complete", {
          output_file = output_file,
          test_count = #results.tests,
        })
      end

      return { output_file = output_file }
    end,

    -- Generate text output
    format_text = function(self, results)
      -- Prepare output file path
      local output_file = self.options.output_file or "test-results.log.txt"

      -- Ensure parent directory exists
      local dir = fs.get_directory_name(output_file)
      if dir and dir ~= "" then
        local success, err = fs.ensure_directory_exists(dir)
        if not success then
          if self.logger then
            self.logger.error("Failed to create parent directory", {
              directory = dir,
              error = err,
            })
          end
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
      local success, err = fs.write_file(output_file, content)
      if not success then
        if self.logger then
          self.logger.error("Failed to write output file", {
            output_file = output_file,
            error = err,
          })
        end
        return nil, "Failed to write output file: " .. (err or "unknown error")
      end

      -- Log completion
      if self.logger then
        self.logger.info("Text log output complete", {
          output_file = output_file,
          test_count = #results.tests,
        })
      end

      return { output_file = output_file }
    end,
  }

  -- Register the formatter
  formatters.register_formatter("log", log_formatter)

  return log_formatter
end

return M
