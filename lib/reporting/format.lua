--- Format coverage data for reporting
-- @module reporting.format

local format = {}

-- Import modules
local error_handler = require("lib.tools.error_handler")
local filesystem = require("lib.tools.filesystem")

--- Convert raw coverage data to firmo's reporting format
---@param coverage_data table Raw coverage data from LuaCov
---@return table|nil formatted_data Formatted coverage data or nil on error
---@return table|nil error Error object if formatting failed
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
      name = filesystem.normalize_path(filename),
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
---@param coverage_data table Coverage data to format
---@param format string Output format (html, json, etc.)
---@return string|table|nil formatted_output Formatted output or nil on error
---@return table|nil error Error object if formatting failed
function format.coverage_report(coverage_data, format)
  -- Convert to report data format first
  local report_data, err = format.to_report_data(coverage_data)
  if not report_data then
    return nil, err
  end

  -- Get the reporting module
  local success, reporting = pcall(require, "lib.reporting")
  if not success then
    return nil, error_handler.runtime_error(
      "Failed to load reporting module",
      {operation = "coverage_report", format = format},
      reporting -- Error is in the reporting variable
    )
  end

  -- Format using reporting module
  local formatted = reporting.format_coverage(report_data, format)
  if not formatted then
    return nil, error_handler.runtime_error(
      "Failed to format coverage report",
      {operation = "coverage_report", format = format}
    )
  end

  return formatted
end

return format

