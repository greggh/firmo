--- TAP Formatter for Test Results
---
--- Generates test results reports in the Test Anything Protocol (TAP) version 13 format.
--- Outputs test points (ok/not ok) for each test case, optionally including YAML
--- diagnostic blocks for failures and errors.
---
--- @module lib.reporting.formatters.tap_results
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

--- @class TestResultCase Expected structure for individual test case data.
--- @field name string Test case name.
--- @field status "pass"|"fail"|"error"|"skipped"|"pending"|"unknown" Test status.
--- @field skip_message? string Reason for skipping (if status is 'skipped' or 'pending').
--- @field skip_reason? string Alternative field for skip reason.
--- @field failure? { message?: string, details?: string } Failure details (if status is 'fail').
--- @field error? { message?: string, details?: string } Error details (if status is 'error').

--- @class TestResultsData Expected structure for overall test results data.
--- @field test_cases? table<number, TestResultCase> Array of test case results.
--- @field tests? number Total number of tests planned (used in summary).
--- @field failures? number Total number of failed tests.
--- @field errors? number Total number of tests with errors.
--- @field skipped? number Total number of skipped/pending tests.

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
    return logging.get_logger("Reporting:TAP")
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

---@class TAPResultsFormatter The public API for the TAP test results formatter.
---@field _VERSION string Module version.
---@field format_results fun(results_data: TestResultsData): string Formats test results data into a TAP string. Returns a fallback string on error.
---@field register fun(formatters: table): boolean, table? Registers the formatter. Returns `true, nil` or `false, error`. @throws table If validation fails.
local M = {}

--- Module version
M._VERSION = "1.0.0"

---@class TAPFormatterConfig
---@field version number TAP version to declare (e.g., 13).
---@field include_yaml_diagnostics boolean Whether to include YAML diagnostic blocks (`--- ... ---`) for failures/errors.
---@field include_summary boolean Whether to include summary comments (`# tests ...`, `# pass ...`) at the end.
---@field include_stack_traces boolean Whether to include stack traces within YAML diagnostic blocks.
---@field default_skip_reason string Default message used for skipped/pending tests if no specific reason is provided.
---@field include_timestamps boolean Whether to include timestamps in diagnostics (Not currently implemented).
---@field include_durations boolean Whether to include durations in diagnostics (Not currently implemented).
---@field use_strict_formatting boolean Apply stricter formatting rules (Not currently implemented).
---@field bail_on_fail boolean Include `Bail out!` directive on first failure (Not currently implemented).
---@field normalize_test_names boolean Normalize test names (Not currently implemented).
---@field show_plan_at_end boolean Show the plan line (`1..N`) at the end instead of the beginning (Not currently implemented).
---@field diagnostic_format string Format for diagnostics ("yaml", "comment", "both") (Not currently implemented, defaults to yaml).
---@field subtest_level number Indentation level for subtests (Not currently implemented).
---@field indent_yaml number Number of spaces to indent YAML diagnostic blocks (default 2).

-- Define default configuration
---@type TAPFormatterConfig
local DEFAULT_CONFIG = {
  version = 13, -- TAP version (12 or 13)
  include_yaml_diagnostics = true, -- Include YAML diagnostics for failures
  include_summary = true, -- Include summary comments at the end
  include_stack_traces = true, -- Include stack traces in diagnostics
  default_skip_reason = "Not implemented yet", -- Default reason for skipped tests
  indent_yaml = 2, -- Number of spaces to indent YAML blocks
}

---@return TAPFormatterConfig config The merged configuration for the TAP formatter.
---@throws table If central_config or reporting module interactions fail critically (though handled by `error_handler.try`).
---@private
local function get_config()
  -- Try reporting module first with error handling
  local success, result, err = get_error_handler()try(function()
    local reporting = require("lib.reporting")
    if reporting.get_formatter_config then
      local formatter_config = reporting.get_formatter_config("tap")
      if formatter_config then
        get_logger().debug("Using configuration from reporting module")
        return formatter_config
      end
    end
    return nil
  end)

  if success and result then
    return result
  end

  -- Try central_config directly with error handling
  local config_success, config_result = get_error_handler()try(function()
    local central_config = require("lib.core.central_config")
    local formatter_config = central_config.get("reporting.formatters.tap")
    if formatter_config then
      get_logger().debug("Using configuration from central_config")
      return formatter_config
    end
    return nil
  end)

  if config_success and config_result then
    return config_result
  end

  -- Fall back to defaults
  get_logger().debug("Using default configuration", {
    reason = "Could not load from reporting or central_config",
    module = "reporting.formatters.tap_results",
  })

  return DEFAULT_CONFIG
end

---@param test_case TestResultCase Test case data.
---@param test_number number Test number in the sequence (1-based).
---@param config TAPFormatterConfig Formatter configuration.
---@return string tap_line TAP-formatted test result line(s), including potential YAML diagnostics. Returns a fallback "not ok" line on error.
---@throws table If input validation fails or critical formatting error occurs (though handled by `error_handler.try`).
---@private
local function format_test_case(test_case, test_number, config)
  -- Validate input parameters
  if not test_case then
    local err = get_error_handler()validation_error("Missing test_case parameter", {
      operation = "format_test_case",
      module = "reporting.formatters.tap_results",
    })
    get_logger().warn(err.message, err.context)
    -- Return a safe minimal line as fallback
    return string.format("not ok %d - Missing test case data # TODO", test_number or 0)
  end

  if not config then
    local err = get_error_handler()validation_error("Missing config parameter", {
      operation = "format_test_case",
      module = "reporting.formatters.tap_results",
    })
    get_logger().warn(err.message, err.context)
    config = DEFAULT_CONFIG -- Use default config as fallback
  end

  -- Protected test line generation
  local line_success, line = get_error_handler()try(function()
    -- Safe defaults for missing data
    local test_name = test_case.name or "Unnamed test"
    local status = test_case.status or "unknown"

    -- Generate basic TAP test line based on status
    if status == "pass" then
      return string.format("ok %d - %s", test_number, test_name)
    elseif status == "pending" or status == "skipped" then
      local skip_reason = test_case.skip_message
        or test_case.skip_reason
        or config.default_skip_reason
        or "Not implemented yet"
      return string.format("ok %d - %s # SKIP %s", test_number, test_name, skip_reason)
    else
      -- Failed or errored test
      return string.format("not ok %d - %s", test_number, test_name)
    end
  end)

  if not line_success or not line then
    local err = get_error_handler()runtime_error(
      "Failed to generate basic TAP line",
      {
        operation = "format_test_case",
        test_number = test_number,
        test_case_name = test_case.name,
        test_case_status = test_case.status,
        module = "reporting.formatters.tap_results",
      },
      line -- On failure, line contains the error
    )
    get_logger().warn(err.message, err.context)

    -- Return a safe minimal line as fallback
    return string.format("not ok %d - Error generating test result # TODO", test_number or 0)
  end

  -- For failed/errored tests, add diagnostic info if available and configured
  if
    (test_case.status == "fail" or test_case.status == "error")
    and config.include_yaml_diagnostics
    and (test_case.failure or test_case.error)
  then
    local yaml_success, yaml_block = get_error_handler()try(function()
      -- Extract diagnostic information safely
      local message = ""
      local details = ""

      if test_case.status == "fail" and test_case.failure then
        message = test_case.failure.message or "Test failed"
        details = test_case.failure.details or ""
      elseif test_case.status == "error" and test_case.error then
        message = test_case.error.message or "Error occurred"
        details = test_case.error.details or ""
      else
        message = "Test failed or errored"
      end

      -- Skip stack traces if configured
      if not config.include_stack_traces and details and details ~= "" then
        -- Safely process stack trace removal
        local trace_success, simplified_details = get_error_handler()try(function()
          local simplified = {}
          for detail_line in details:gmatch("([^\n]+)") do
            if not detail_line:match("stack traceback:") and not detail_line:match("%.lua:%d+:") then
              table.insert(simplified, detail_line)
            end
          end
          return table.concat(simplified, "\n")
        end)

        if trace_success then
          details = simplified_details
        else
          -- If trace removal fails, just use original (safer)
          get_logger().debug("Failed to remove stack traces from details, using original", {
            test_number = test_number,
            test_case_name = test_case.name,
          })
        end
      end

      -- Generate indent with error handling
      local indent = "  " -- Safe default
      local indent_success, indent_result = get_error_handler()try(function()
        local indent_count = tonumber(config.indent_yaml) or 2
        if indent_count < 0 then
          indent_count = 2
        end -- Sanity check
        if indent_count > 10 then
          indent_count = 10
        end -- Reasonable limit
        return string.rep(" ", indent_count)
      end)

      if indent_success then
        indent = indent_result
      end

      -- Create diagnostic block
      local diag = {
        "  ---",
        indent .. "message: " .. (message or ""),
        indent .. "severity: " .. (test_case.status == "error" and "error" or "fail"),
        "  ...",
      }

      -- Add details if available
      if details and details ~= "" then
        -- Process details with error handling
        local details_success, details_block = get_error_handler()try(function()
          diag[3] = indent .. "data: |"
          local detail_lines = {}
          for detail_line in details:gmatch("([^\n]+)") do
            table.insert(detail_lines, indent .. "  " .. detail_line)
          end
          return table.concat(detail_lines, "\n")
        end)

        if details_success then
          table.insert(diag, 3, details_block)
        else
          -- Fallback for details processing failure
          get_logger().warn("Failed to process test details for YAML block", {
            test_number = test_number,
            test_case_name = test_case.name,
            error = get_error_handler().format_error(details_block),
          })
          -- Add simplified details line
          table.insert(diag, 3, indent .. "data: Failed to process details")
        end
      end

      -- Join diagnostic lines with proper error handling
      local yaml_join_success, yaml_result = get_error_handler()try(function()
        return table.concat(diag, "\n")
      end)

      if yaml_join_success then
        return yaml_result
      else
        -- If join fails, return simplified diagnostic block
        get_logger().warn("Failed to join YAML diagnostic lines, using simplified block", {
          test_number = test_number,
          test_case_name = test_case.name,
          error = get_error_handler().format_error(yaml_result),
        })

        return "  ---\n  message: Error diagnostic\n  severity: unknown\n  ..."
      end
    end)

    if yaml_success and yaml_block then
      -- Append YAML block to test line with error handling
      local append_success, full_line = get_error_handler().try(function()
        return line .. "\n" .. yaml_block
      end)

      if append_success then
        return full_line
      else
        -- If append fails, log the error and return just the test line
        get_logger().warn("Failed to append YAML diagnostics to test line, returning basic line", {
          test_number = test_number,
          test_case_name = test_case.name,
          error = get_error_handler().format_error(full_line),
        })
        return line
      end
    else
      -- If YAML block generation fails, log the error and return just the test line
      local err = get_error_handler().runtime_error("Failed to generate YAML diagnostics for TAP report", {
        operation = "format_test_case",
        test_number = test_number,
        test_case_name = test_case.name,
        module = "reporting.formatters.tap_results",
      }, yaml_block)
      get_logger().warn(err.message, err.context)
      return line
    end
  end

  return line
end

--- Formats test results data into a TAP version 13 string.
--- Handles potential errors during configuration loading and formatting, returning a fallback string on error.
---@param results_data TestResultsData|nil Test results data to format. Handles `nil` input gracefully.
---@return string tap_output TAP-formatted test results string.
---@throws table If a critical error occurs during formatting or joining lines (though handled by `error_handler.try`).
function M.format_results(results_data)
  -- Validate input parameter
  if not results_data then
    local err = get_error_handler().validation_error("Missing results_data parameter", {
      operation = "format_results",
      module = "reporting.formatters.tap_results",
    })
    get_logger().warn(err.message, err.context)
    -- Return minimal TAP output for no tests
    return "TAP version 13\n1..0\n# No tests run"
  end

  -- Get formatter configuration with error handling
  local config_success, config = get_error_handler().try(function()
    return get_config()
  end)

  if not config_success or not config then
    -- Log error and use default config
    get_logger().warn("Failed to get TAP formatter configuration, using defaults", {
      error = get_error_handler().format_error(config),
    })
    config = DEFAULT_CONFIG
  end

  -- Initialize lines array safely
  local lines = {}

  -- TAP version header with error handling
  local version_success, version_line = get_error_handler().try(function()
    return "TAP version " .. (tonumber(config.version) or 13)
  end)

  if version_success then
    table.insert(lines, version_line)
  else
    -- If version line creation fails, use a safe default
    get_logger().warn("Failed to create TAP version line, using default version 13", {
      config_version = config.version,
      error = get_error_handler().format_error(version_line),
    })
    table.insert(lines, "TAP version 13")
  end

  -- Plan line with total number of tests
  local test_count_success, test_count = get_error_handler().try(function()
    return results_data.test_cases and #results_data.test_cases or 0
  end)

  if not test_count_success or not test_count then
    -- Log error and use zero as fallback
    get_logger().warn("Failed to calculate test count, using 0", {
      error = get_error_handler().format_error(test_count),
    })
    test_count = 0
  end

  local plan_success, plan_line = get_error_handler().try(function()
    return string.format("1..%d", test_count)
  end)

  if plan_success then
    table.insert(lines, plan_line)
  else
    -- If plan line creation fails, use a safe default
    get_logger().warn("Failed to create TAP plan line, using 1..0", {
      test_count = test_count,
      error = get_error_handler().format_error(plan_line),
    })
    table.insert(lines, "1..0")
    -- Since we're having trouble with the basic plan, set test_count to 0
    test_count = 0
  end

  -- Add test case results with error handling for each test case
  if test_count > 0 then
    for i, test_case in ipairs(results_data.test_cases) do
      local test_success, test_line = get_error_handler().try(function()
        return format_test_case(test_case, i, config)
      end)

      if test_success and test_line then
        table.insert(lines, test_line)
      else
        -- If test case formatting fails, log the error and add a minimal valid line
        local err = get_error_handler().runtime_error("Failed to format test case for TAP report", {
          operation = "format_results",
          index = i,
          test_case = test_case and test_case.name or "unknown",
          module = "reporting.formatters.tap_results",
        }, test_line)
        get_logger().warn(err.message, err.context)

        -- Add a minimal valid line as a fallback
        table.insert(lines, string.format("not ok %d - Failed to format test case # TODO", i))
      end
    end
  else
    -- No test cases to report
    get_logger().debug("No test cases to format")
    table.insert(lines, "# No test cases in results data")
  end

  -- Add summary line if configured
  if config.include_summary then
    local summary_success, summary_lines = get_error_handler().try(function()
      local sum_lines = {}

      -- Calculate statistics safely
      local total = test_count
      local failures = tonumber(results_data.failures) or 0
      local errors = tonumber(results_data.errors) or 0
      local skipped = tonumber(results_data.skipped) or 0
      local passed = total - failures - errors - skipped

      if passed < 0 then
        passed = 0
      end -- Sanity check

      -- Format summary lines
      table.insert(sum_lines, string.format("# tests %d", total))
      table.insert(sum_lines, string.format("# pass %d", passed))

      if failures > 0 then
        table.insert(sum_lines, string.format("# fail %d", failures))
      end

      if errors > 0 then
        table.insert(sum_lines, string.format("# error %d", errors))
      end

      if skipped > 0 then
        table.insert(sum_lines, string.format("# skip %d", skipped))
      end

      return sum_lines
    end)

    if summary_success and summary_lines then
      -- Add all summary lines
      for _, summary_line in ipairs(summary_lines) do
        table.insert(lines, summary_line)
      end
    else
      -- If summary generation fails, log the error and add a basic summary
      local err = get_error_handler().runtime_error("Failed to generate summary for TAP report", {
        operation = "format_results",
        module = "reporting.formatters.tap_results",
      }, summary_lines)
      get_logger().warn(err.message, err.context)

      -- Add minimal summary
      table.insert(lines, "# tests " .. test_count)
      table.insert(lines, "# Summary generation failed")
    end
  end

  -- Join all lines with newlines with error handling
  local join_success, result = get_error_handler().try(function()
    return table.concat(lines, "\n")
  end)

  if join_success then
    return result
  else
    -- If joining fails, log the error and return a minimal valid TAP report
    local err = get_error_handler().runtime_error(
      "Failed to join TAP lines",
      {
        operation = "format_results",
        lines_count = #lines,
        module = "reporting.formatters.tap_results",
      },
      result -- On failure, result contains the error
    )
    get_logger().error(err.message, err.context)

    -- Return minimal valid TAP output as fallback
    return "TAP version 13\n1..0\n# Error generating TAP report"
  end
end

--- Registers the TAP test results formatter with the main formatters registry.
---@param formatters table The main formatters registry object (must contain a `results` table).
---@return boolean success `true` if registration succeeded.
---@return table? error Error object if validation failed.
---@throws table If validation fails critically.
function M.register(formatters)
  -- Validate parameters
  if not formatters then
    local err = get_error_handler().validation_error("Missing required formatters parameter", {
      operation = "register",
      module = "reporting.formatters.tap_results",
    })
    get_logger().error(err.message, err.context)
    return false, err
  end

  -- Use try/catch pattern for the registration
  local success, result = get_error_handler().try(function()
    -- Initialize results formatters if needed
    formatters.results = formatters.results or {}
    formatters.results.tap = M.format_results

    get_logger().debug("TAP formatter registered successfully", {
      formatter_type = "results",
      module = "reporting.formatters.tap_results",
    })

    return true
  end)

  if not success then
    -- If registration fails, log the error and return false
    local err = get_error_handler().runtime_error(
      "Failed to register TAP formatter",
      {
        operation = "register",
        module = "reporting.formatters.tap_results",
      },
      result -- On failure, result contains the error
    )
    get_logger().error(err.message, err.context)
    return false, err
  end
  return true
end

return M
