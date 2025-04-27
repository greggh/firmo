--- TAP Formatter for Coverage Reports
---
--- Generates coverage reports in the Test Anything Protocol (TAP) version 13 format.
--- Treats overall coverage and each file's coverage against configured thresholds
--- as individual test points, suitable for consumption by TAP parsers.
---
--- @module lib.reporting.formatters.tap
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

--- @class CoverageReportFileStats Simplified structure expected by this formatter.
--- @field path string File path.
--- @field summary table { coverage_percent: number, total_lines: number, covered_lines: number, executed_lines?: number, not_covered_lines?: number }
--- @field lines? table<number, { covered?: boolean, executed?: boolean, execution_count?: number }> Line data (used for uncovered lines).
--- @field functions? table<string, { executed?: boolean, execution_count?: number, start_line?: number, name?: string }> Function data (used for function coverage).

--- @class CoverageReportSummary Simplified structure expected by this formatter.
--- @field coverage_percent number Overall coverage percentage.
--- @field total_files number Total number of files.
--- @field total_lines number Total lines across all files.
--- @field covered_lines number Total covered lines across all files.
--- @field executed_lines? number Total executed lines across all files.
--- @field not_covered_lines? number Total lines not covered.

--- @class CoverageReportData Expected structure for coverage data input.
--- @field summary CoverageReportSummary Overall summary statistics.
--- @field files table<string, CoverageReportFileStats> Map of file paths to file data.

---@class TAPFormatter : Formatter TAP Formatter for coverage reports.
--- Generates coverage reports in the Test Anything Protocol (TAP) version 13 format.
--- Treats overall coverage and each file's coverage as separate test points.
---@field _VERSION string Module version.
---@field validate fun(self: TAPFormatter, coverage_data: CoverageReportData): boolean, string? Validates coverage data, ensuring the 'files' section exists. Returns `true` or `false, error_message`.
---@field format fun(self: TAPFormatter, coverage_data: CoverageReportData, options?: { threshold?: number, file_threshold?: number, detailed?: boolean, list_uncovered?: boolean, list_uncovered_lines?: boolean }): string|nil, table? Formats coverage data as a TAP string. Returns `tap_string, nil` or `nil, error`. @throws table If validation fails.
---@field build_tap fun(self: TAPFormatter, data: CoverageReportData, options: table): string Builds the TAP content string. Returns TAP string. @private
---@field write fun(self: TAPFormatter, tap_content: string, output_path: string, options?: table): boolean, table? Writes the TAP content to a file. Returns `true, nil` or `false, error`. @throws table If writing fails critically.
---@field register fun(formatters: table): boolean, table? Registers the TAP formatter with the main registry. Returns `true, nil` or `false, error`. @throws table If validation fails.

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler

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

local Formatter = try_require("lib.reporting.formatters.base")

-- Create TAP formatter class
local TAPFormatter = Formatter.extend("tap", "tap")

--- TAP Formatter version
TAPFormatter._VERSION = "1.0.0"

--- Validates the coverage data structure for TAP format.
--- Ensures the base validation passes and the `files` section exists.
---@param self TAPFormatter The formatter instance.
---@param coverage_data CoverageReportData The coverage data to validate.
---@return boolean success `true` if validation passes.
---@return string? error_message Error message string if validation failed.
function TAPFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end

  -- Additional TAP-specific validation if needed

  return true
end

--- Formats coverage data into a TAP version 13 string.
---@param self TAPFormatter The formatter instance.
---@param coverage_data CoverageReportData The coverage data structure.
---@param options? { threshold?: number, file_threshold?: number, detailed?: boolean, list_uncovered?: boolean, list_uncovered_lines?: boolean } Formatting options:
---  - `threshold` (number, default 80): Overall coverage threshold for the main test point.
---  - `file_threshold` (number, default `threshold`): Coverage threshold for individual file test points.
---  - `detailed` (boolean, default true): Include YAML diagnostic blocks with details.
---  - `list_uncovered` (boolean, default false): Include list of uncovered functions in YAML diagnostics.
---  - `list_uncovered_lines` (boolean, default false): Include list/ranges of uncovered lines in YAML diagnostics.
---@return string|nil tap_content The generated TAP content as a single string, or `nil` on validation error.
---@return table? error Error object if validation failed.
---@throws table If `normalize_coverage_data` or `build_tap` fails critically.
function TAPFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, get_error_handler().validation_error("Coverage data is required", { formatter = self.name })
  end

  -- Apply options with defaults
  options = options or {}
  options.threshold = options.threshold or 80
  options.file_threshold = options.file_threshold or options.threshold
  options.detailed = options.detailed ~= false -- Default to true

  -- Normalize the coverage data
  local normalized_data = self:normalize_coverage_data(coverage_data)

  -- Begin building TAP content
  local tap_content = self:build_tap(normalized_data, options)

  return tap_content
end

--- Builds the TAP format content string.
---@param self TAPFormatter The formatter instance.
---@param data CoverageReportData The normalized coverage data.
---@param options table The formatting options.
---@return string tap_content The generated TAP string.
---@private
function TAPFormatter:build_tap(data, options)
  local lines = {}

  -- Add TAP header
  table.insert(lines, "TAP version 13")

  -- Calculate how many tests we'll run
  local test_count = 1 -- Start with the overall coverage test

  -- Add file tests if we have files
  if data.files then
    test_count = test_count + #self:get_table_keys(data.files)
  end

  -- Add TAP plan line
  table.insert(lines, "1.." .. test_count)

  -- Check overall coverage first
  local overall_threshold = options.threshold or 80
  local overall_coverage = data.summary.coverage_percent or 0
  local overall_test_passed = overall_coverage >= overall_threshold

  -- Add overall coverage test
  if overall_test_passed then
    table.insert(lines, "ok 1 - Overall coverage meets threshold")
  else
    table.insert(lines, "not ok 1 - Overall coverage below threshold")
  end

  -- Add overall coverage details as YAML diagnostic
  if options.detailed then
    table.insert(lines, "  ---")
    table.insert(lines, "  threshold: " .. overall_threshold .. "%")
    table.insert(lines, "  coverage: " .. string.format("%.2f", overall_coverage) .. "%")
    table.insert(lines, "  total_files: " .. data.summary.total_files)
    table.insert(lines, "  total_lines: " .. data.summary.total_lines)
    table.insert(lines, "  covered_lines: " .. data.summary.covered_lines)
    table.insert(lines, "  executed_lines: " .. data.summary.executed_lines)
    table.insert(lines, "  not_covered_lines: " .. data.summary.not_covered_lines)
    table.insert(lines, "  ...")
  end

  -- Process each file
  local sorted_files = {}
  for path, file_data in pairs(data.files or {}) do
    table.insert(sorted_files, { path = path, data = file_data })
  end

  table.sort(sorted_files, function(a, b)
    return a.path < b.path
  end)

  -- Add each file's coverage as a test
  for i, file in ipairs(sorted_files) do
    local test_number = i + 1 -- Start from 2 since overall is test 1
    local path = file.path
    local file_data = file.data
    local file_threshold = options.file_threshold or 80
    local file_coverage = file_data.summary.coverage_percent or 0
    local file_test_passed = file_coverage >= file_threshold

    -- Add file coverage test
    if file_test_passed then
      table.insert(lines, "ok " .. test_number .. " - " .. path)
    else
      table.insert(lines, "not ok " .. test_number .. " - " .. path)
    end

    -- Add file coverage details as YAML diagnostic
    if options.detailed then
      table.insert(lines, "  ---")
      table.insert(lines, "  threshold: " .. file_threshold .. "%")
      table.insert(lines, "  coverage: " .. string.format("%.2f", file_coverage) .. "%")
      table.insert(lines, "  total_lines: " .. file_data.summary.total_lines)
      table.insert(lines, "  covered_lines: " .. file_data.summary.covered_lines)
      table.insert(lines, "  executed_lines: " .. file_data.summary.executed_lines)
      table.insert(lines, "  not_covered_lines: " .. file_data.summary.not_covered_lines)

      -- Add function coverage if available
      if file_data.functions and next(file_data.functions) then
        table.insert(lines, "  functions:")

        -- Count covered and uncovered functions
        local covered_functions = 0
        local total_functions = 0

        for name, func_data in pairs(file_data.functions) do
          total_functions = total_functions + 1
          if func_data.executed or (func_data.execution_count and func_data.execution_count > 0) then
            covered_functions = covered_functions + 1
          end
        end

        table.insert(lines, "    total: " .. total_functions)
        table.insert(lines, "    covered: " .. covered_functions)

        -- List uncovered functions if any and if we should be detailed
        if options.list_uncovered and covered_functions < total_functions then
          table.insert(lines, "    uncovered:")

          -- Sort function names for consistency
          local func_names = {}
          for name, func_data in pairs(file_data.functions) do
            if not (func_data.executed or (func_data.execution_count and func_data.execution_count > 0)) then
              table.insert(func_names, {
                name = name,
                line = func_data.start_line or 0,
              })
            end
          end

          table.sort(func_names, function(a, b)
            return a.line < b.line
          end)

          for _, func in ipairs(func_names) do
            table.insert(lines, "      - name: " .. func.name)
            table.insert(lines, "        line: " .. func.line)
          end
        end
      end

      -- Add uncovered lines if configured
      if options.list_uncovered_lines and file_data.lines then
        local uncovered_lines = {}

        for line_num, line_data in pairs(file_data.lines) do
          if
            not (
              line_data.covered
              or line_data.executed
              or (line_data.execution_count and line_data.execution_count > 0)
            )
          then
            table.insert(uncovered_lines, tonumber(line_num))
          end
        end

        if #uncovered_lines > 0 then
          table.sort(uncovered_lines)

          table.insert(lines, "  uncovered_lines:")

          -- Group consecutive lines for readability
          local ranges = {}
          local current_range = { start = uncovered_lines[1], end_ = uncovered_lines[1] }

          for i = 2, #uncovered_lines do
            if uncovered_lines[i] == current_range.end_ + 1 then
              -- Continue the current range
              current_range.end_ = uncovered_lines[i]
            else
              -- End the current range and start a new one
              table.insert(ranges, current_range)
              current_range = { start = uncovered_lines[i], end_ = uncovered_lines[i] }
            end
          end

          -- Add the last range
          table.insert(ranges, current_range)

          -- Output ranges
          for _, range in ipairs(ranges) do
            if range.start == range.end_ then
              table.insert(lines, "    - " .. range.start)
            else
              table.insert(lines, "    - " .. range.start .. "-" .. range.end_)
            end
          end
        end
      end

      table.insert(lines, "  ...")
    end
  end

  -- Add TAP summary
  local pass_count = 0
  local fail_count = 0

  if overall_test_passed then
    pass_count = pass_count + 1
  else
    fail_count = fail_count + 1
  end

  for _, file in ipairs(sorted_files) do
    local file_threshold = options.file_threshold or 80
    local file_coverage = file.data.summary.coverage_percent or 0

    if file_coverage >= file_threshold then
      pass_count = pass_count + 1
    else
      fail_count = fail_count + 1
    end
  end

  -- Add TAP summary as a comment
  table.insert(lines, "# Tests " .. test_count)
  table.insert(lines, "# Pass " .. pass_count)
  table.insert(lines, "# Fail " .. fail_count)

  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

--- Writes the generated TAP content to a file.
--- Inherits the write logic (including directory creation) from the base `Formatter`.
---@param self TAPFormatter The formatter instance.
---@param tap_content string The TAP content string to write.
---@param output_path string The path to the output file.
---@param options? table Optional options passed to the base `write` method (currently unused by base).
---@return boolean success `true` if writing succeeded.
---@return table? error Error object if writing failed.
---@throws table If writing fails critically.
function TAPFormatter:write(tap_content, output_path, options)
  return Formatter.write(self, tap_content, output_path, options)
end

--- Register the TAP formatter with the formatters registry
---@param formatters table The main formatters registry object (must contain `coverage` table).
---@return boolean success `true` if registration succeeded.
---@return table? error Error object if validation failed.
---@throws table If validation fails critically.
function TAPFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    local err = get_error_handler().validation_error("Invalid formatters registry", {
      operation = "register",
      formatter = "tap",
      provided_type = type(formatters),
    })
    return false, err
  end

  -- Create a new instance of the formatter
  local formatter = TAPFormatter.new()

  -- Register format_coverage function
  formatters.coverage.tap = function(coverage_data, options)
    return formatter:format(coverage_data, options)
  end

  return true
end

return TAPFormatter
