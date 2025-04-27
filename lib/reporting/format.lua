--- Firmo Coverage Data Formatting Module
---
--- This module converts raw coverage data (typically from `lib.coverage`) into a
--- standardized intermediate format (`CoverageReportData`) suitable for various
--- reporting formatters. It also provides a convenience function to directly format
--- coverage data using the main reporting module.
---
--- @module lib.reporting.format
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class report_format Provides functions for formatting coverage data.
---@field to_report_data fun(coverage_data: table): CoverageReportData|nil, table? Converts raw coverage data to firmo's reporting format. Returns `formatted_data, nil` or `nil, error`. Throws validation errors.
---@field coverage_report fun(coverage_data: table, format: string): string|table|nil, table? Formats coverage data using the main reporting module. Returns `formatted_output, nil` or `nil, error`. Throws runtime errors if reporting module fails.

---@class CoverageReportFileStats Detailed coverage statistics for a single file.
---@field name string Normalized path of the file.
---@field lines table<number, number> Map of line number to hit count.
---@field total_lines number Total number of lines in the file.
---@field covered_lines number Number of lines with at least one hit.
---@field functions table Placeholder for function coverage (future implementation).
---@field covered_functions number Number of functions covered (future implementation).
---@field line_coverage_percent number Percentage of lines covered.
---@field function_coverage_percent number Percentage of functions covered (future implementation).
---@field overall_percent number Overall coverage percentage for the file (currently same as line coverage).

---@class CoverageReportSummary Overall coverage statistics for the report.
---@field total_files number Total number of files analyzed.
---@field covered_files number Number of files with at least one covered line.
---@field total_lines number Total number of lines across all analyzed files.
---@field covered_lines number Total number of lines covered across all analyzed files.
---@field total_functions number Total number of functions (future implementation).
---@field covered_functions number Total number of functions covered (future implementation).
---@field line_coverage_percent number Overall line coverage percentage.
---@field function_coverage_percent number Overall function coverage percentage (future implementation).
---@field overall_percent number Overall coverage percentage (currently same as line coverage).
---@field file_coverage_percent? number Percentage of files covered (if total_files > 0).

---@class CoverageReportData Standardized coverage report structure.
---@field files table<string, CoverageReportFileStats> Map of normalized filename to file statistics.
---@field summary CoverageReportSummary Overall summary statistics.

local format = {}

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _fs

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

--- Converts raw coverage data (typically from `lib.coverage` or LuaCov format)
--- into the standardized `CoverageReportData` structure used by Firmo reporters.
--- Calculates summary statistics based on per-file data.
---@param coverage_data table Raw coverage data. Expected format: `{ [filename]= { [line_nr]=hit_count, max=number }, ... }`.
---@return CoverageReportData|nil formatted_data The formatted `CoverageReportData` object, or `nil` if input validation fails.
---@return table|nil error Error object if formatting failed (e.g., input validation).
---@throws table If input validation (`coverage_data` is nil) fails critically.
function format.to_report_data(coverage_data)
  -- Validate input
  if not coverage_data then
    return nil, error_handler.validation_error(
      "Missing coverage data",
      {operation = "to_report_data"}
    )
  end

  -- Initialize report structure
  local report = {
    files = {},
    summary = {
      total_files = 0,
      covered_files = 0,
      total_lines = 0,
      covered_lines = 0,
      total_functions = 0,
      covered_functions = 0,
      line_coverage_percent = 0,
      function_coverage_percent = 0,
      overall_percent = 0
    }
  }

  -- Process each file's coverage data
  for filename, file_data in pairs(coverage_data) do
    -- Skip non-table entries
    if type(file_data) ~= "table" then goto continue end

    -- Initialize file stats
    local file_stats = {
      name = get_fs().normalize_path(filename),
      lines = {},
      total_lines = file_data.max or 0,
      covered_lines = 0,
      functions = {}, -- Will be populated when function tracking is added
      covered_functions = 0,
      line_coverage_percent = 0,
      function_coverage_percent = 0,
      overall_percent = 0
    }

    -- Process line hits
    for line_nr = 1, file_data.max do
      local hits = file_data[line_nr] or 0
      if hits > 0 then
        file_stats.covered_lines = file_stats.covered_lines + 1
      end
      file_stats.lines[line_nr] = hits
    end

    -- Calculate file percentages
    if file_stats.total_lines > 0 then
      file_stats.line_coverage_percent = (file_stats.covered_lines / file_stats.total_lines) * 100
      file_stats.overall_percent = file_stats.line_coverage_percent -- For now, same as line coverage
    end

    -- Update report summary
    report.summary.total_files = report.summary.total_files + 1
    if file_stats.covered_lines > 0 then
      report.summary.covered_files = report.summary.covered_files + 1
    end
    report.summary.total_lines = report.summary.total_lines + file_stats.total_lines
    report.summary.covered_lines = report.summary.covered_lines + file_stats.covered_lines

    -- Add file stats to report
    report.files[file_stats.name] = file_stats

    ::continue::
  end

  -- Calculate overall percentages
  if report.summary.total_lines > 0 then
    report.summary.line_coverage_percent = (report.summary.covered_lines / report.summary.total_lines) * 100
    report.summary.overall_percent = report.summary.line_coverage_percent -- For now, same as line coverage
  end

  if report.summary.total_files > 0 then
    report.summary.file_coverage_percent = (report.summary.covered_files / report.summary.total_files) * 100
  end

  return report
end

--- Format coverage report for output
---@param coverage_data table Raw coverage data (same format as expected by `to_report_data`).
---@param format string The desired output format string (e.g., "html", "json", "lcov", "summary"). This is passed to the main reporting module.
---@return string|table|nil formatted_output The formatted report (string or table depending on the formatter), or `nil` if formatting fails.
---@return table|nil error Error object if formatting failed (e.g., input validation, reporting module load error, formatter error).
---@throws table If `to_report_data` fails validation critically, or if the reporting module cannot be loaded or fails critically during formatting.
function format.coverage_report(coverage_data, format)
  -- Convert to report data format first
  local report_data, err = format.to_report_data(coverage_data)
  if not report_data then
    return nil, err
  end

-- Get the reporting module
  local reporting = try_require("lib.reporting")

  -- Format using reporting module
  local formatted = reporting.format_coverage(report_data, format)
  if not formatted then
    return nil, get_error_handler().runtime_error(
      "Failed to format coverage report",
      {operation = "coverage_report", format = format}
    )
  end

  return formatted
end

return format

