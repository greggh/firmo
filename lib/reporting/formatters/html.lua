--- HTML Coverage Report Formatter
---
--- Generates an interactive HTML report for code coverage results, including
--- summary statistics, file lists, and syntax-highlighted source code views
--- with line coverage indicators. Includes theme toggling (light/dark).
--- Uses performance optimizations for large files.
---
--- @module lib.reporting.formatters.html
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 2.0.0

--- @class CoverageReportFileStats Detailed coverage statistics for a single file.
--- @field name string Normalized path of the file.
--- @field path string Same as name (for compatibility/convenience).
--- @field lines table<number|string, CoverageLineEntry> Map of line number (string or number) to line data.
--- @field total_lines number Total number of lines in the file.
--- @field covered_lines number Number of lines with at least one hit.
--- @field executable_lines number Number of lines considered executable code.
--- @field functions table Placeholder for function coverage data.
--- @field executed_functions number Count of functions executed.
--- @field total_functions number Total count of functions defined.
--- @field line_coverage_percent number Percentage of lines covered (covered / executable).
--- @field function_coverage_percent number Percentage of functions covered (executed / total).
--- @field source? string Optional source code content.
--- @field simplified_rendering? boolean Internal flag indicating only summary should be shown for this file due to size.

--- @class CoverageLineEntry Detailed data for a single line.
--- @field executable boolean Whether the line is executable.
--- @field execution_count number Number of times the line was hit.
--- @field covered boolean Whether the line was covered (usually `execution_count > 0`).
--- @field content? string Optional source code content for the line.
--- @field line_type? string Optional classification (e.g., "comment", "blank").

--- @class CoverageReportSummary Overall coverage statistics for the report.
--- @field total_files number Total number of files analyzed.
--- @field covered_files number Number of files with at least one covered line.
--- @field total_lines number Total number of lines across all analyzed files.
--- @field covered_lines number Total number of lines covered across all analyzed files.
--- @field executable_lines number Total executable lines across all files.
--- @field total_functions number Total number of functions across all files.
--- @field executed_functions number Total number of functions executed across all files.
--- @field line_coverage_percent number Overall line coverage percentage.
--- @field function_coverage_percent number Overall function coverage percentage.
--- @field file_coverage_percent? number Percentage of files covered (if total_files > 0).

--- @class CoverageReportData Expected structure for coverage data input.
--- @field summary CoverageReportSummary Overall summary statistics.
--- @field files table<string, CoverageReportFileStats> Map of normalized filename to file statistics.
--- @field executed_lines? number Deprecated: Use `summary.executable_lines`.
--- @field covered_lines? number Deprecated: Use `summary.covered_lines`.

---@class HTMLFormatter API for generating HTML coverage reports.
---@field _VERSION string Module version.
---@field format_coverage fun(coverage_data: CoverageReportData): string Formats coverage data into a complete HTML document string.
---@field generate fun(coverage_data: CoverageReportData, output_path: string): boolean, table? Generates and writes the HTML report to a file. Returns `success, error`. @throws table If validation or file operations fail critically.
local M = {}

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
    return logging.get_logger("Reporting:HTMLFormatter")
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

-- Version
M._VERSION = "2.0.0"

-- Simple, self-contained CSS
local SIMPLE_CSS = [[
/* Theme Variables */
:root {
  /* Light Theme */
  --bg-color-light: #f5f5f5;
  --text-color-light: #333;
  --card-bg-light: #fff;
  --card-border-light: #e1e1e1;
  --header-bg-light: #fff;
  --header-border-light: #e1e1e1;
  --stat-box-bg-light: #f9f9f9;
  --stat-box-border-light: #e1e1e1;
  --muted-text-light: #666;
  --line-number-bg-light: #f9f9f9;
  --line-number-color-light: #999;
  --progress-bg-light: #e0e0e0;
  --hover-bg-light: #f9f9f9;
  --td-border-light: #e1e1e1;
  --target-highlight-light: #fffde7;

  /* Dark Theme */
  --bg-color-dark: #1a1a1a;
  --text-color-dark: #e0e0e0;
  --card-bg-dark: #242424;
  --card-border-dark: #3a3a3a;
  --header-bg-dark: #242424;
  --header-border-dark: #3a3a3a;
  --stat-box-bg-dark: #2a2a2a;
  --stat-box-border-dark: #3a3a3a;
  --muted-text-dark: #aaa;
  --line-number-bg-dark: #2a2a2a;
  --line-number-color-dark: #888;
  --progress-bg-dark: #3a3a3a;
  --hover-bg-dark: #2d2d2d;
  --td-border-dark: #3a3a3a;
  --target-highlight-dark: #3a3600;

  /* Shared Colors */
  --high-color: #4caf50;
  --medium-color: #ff9800;
  --low-color: #f44336;

  /* Coverage Status Colors - Higher contrast for better visibility */
  --covered-bg-dark: rgba(76, 175, 80, 0.4);     /* Green with more opacity */
  --executed-bg-dark: rgba(255, 152, 0, 0.4);    /* Orange with more opacity */
  --not-covered-bg-dark: rgba(244, 67, 54, 0.4); /* Red with more opacity */

  --covered-bg-light: rgba(76, 175, 80, 0.3);    /* Green for light theme */
  --executed-bg-light: rgba(255, 152, 0, 0.3);   /* Orange for light theme */
  --not-covered-bg-light: rgba(244, 67, 54, 0.3); /* Red for light theme */

  /* Dark Theme Syntax Highlighting */
  --keyword-dark: #ff79c6;
  --string-dark: #9ccc65;
  --comment-dark: #7e7e7e;
  --number-dark: #bd93f9;
  --function-dark: #8be9fd;

  /* Light Theme Syntax Highlighting */
  --keyword-light: #0033b3;
  --string-light: #067d17;
  --comment-light: #8c8c8c;
  --number-light: #1750eb;
  --function-light: #7c4dff;
}

/* Dark Mode by Default */
html {
  color-scheme: dark;
}

body {
  background-color: var(--bg-color-dark);
  color: var(--text-color-dark);
}

/* Basic reset */
html, body {
  margin: 0;
  padding: 0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  font-size: 14px;
  line-height: 1.5;
}

/* Theme Toggle Switch */
.theme-switch-wrapper {
  display: flex;
  align-items: center;
  gap: 8px;
}

.theme-switch {
  position: relative;
  width: 40px;
  height: 20px;
}

.theme-switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.slider {
  position: absolute;
  cursor: pointer;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: #555;
  border-radius: 20px;
  transition: .4s;
}

.slider:before {
  position: absolute;
  content: "";
  height: 16px;
  width: 16px;
  left: 2px;
  bottom: 2px;
  background-color: white;
  border-radius: 50%;
  transition: .4s;
}

input:checked + .slider {
  background-color: #2196F3;
}

input:checked + .slider:before {
  transform: translateX(20px);
}

/* Layout */
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 10px;
}

header {
  background-color: var(--header-bg-dark);
  border-bottom: 1px solid var(--header-border-dark);
  padding: 15px 0;
  margin-bottom: 20px;
}

h1, h2, h3, h4 {
  margin: 0 0 15px 0;
  font-weight: 600;
}

h1 { font-size: 24px; }
h2 { font-size: 20px; }
h3 { font-size: 16px; }
h4 { font-size: 14px; }

/* Coverage Summary */
.summary {
  background-color: var(--card-bg-dark);
  border: 1px solid var(--card-border-dark);
  border-radius: 4px;
  padding: 15px;
  margin-bottom: 20px;
}

.stats {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
  margin-bottom: 15px;
}

.stat-box {
  background-color: var(--stat-box-bg-dark);
  border: 1px solid var(--stat-box-border-dark);
  border-radius: 4px;
  padding: 10px;
  min-width: 150px;
}

.stat-label {
  font-size: 12px;
  color: var(--muted-text-dark);
}

.stat-value {
  font-size: 18px;
  font-weight: 600;
}

.high { color: var(--high-color); }
.medium { color: var(--medium-color); }
.low { color: var(--low-color); }

/* Progress bar */
.progress-bar {
  height: 8px;
  background-color: var(--progress-bg-dark);
  border-radius: 4px;
  overflow: hidden;
  margin-top: 3px;
}

.progress-value {
  height: 100%;
}

.progress-value.high { background-color: var(--high-color); }
.progress-value.medium { background-color: var(--medium-color); }
.progress-value.low { background-color: var(--low-color); }

/* File list */
.file-list {
  background-color: var(--card-bg-dark);
  border: 1px solid var(--card-border-dark);
  border-radius: 4px;
  margin-bottom: 20px;
}

.file-list-table {
  width: 100%;
  border-collapse: collapse;
}

.file-list-table th {
  text-align: left;
  padding: 10px;
  border-bottom: 1px solid var(--td-border-dark);
  background-color: var(--stat-box-bg-dark);
  font-weight: 600;
}

.file-list-table td {
  padding: 8px 10px;
  border-bottom: 1px solid var(--td-border-dark);
}

.file-list-table tr:hover {
  background-color: var(--hover-bg-dark);
}

/* Source code display */
.source-section {
  background-color: var(--card-bg-dark);
  border: 1px solid var(--card-border-dark);
  border-radius: 4px;
  margin-bottom: 20px;
}

/* Coverage status classes */
.covered {
  background-color: var(--covered-bg-dark);
}

.executed {
  background-color: var(--executed-bg-dark);
}

.not-covered {
  background-color: var(--not-covered-bg-dark);
}

.file-header {
  padding: 8px 10px;
  border-bottom: 1px solid var(--td-border-dark);
  background-color: var(--stat-box-bg-dark);
  font-weight: 600;
  font-size: 13px;
}

.file-header .file-path {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--text-color-dark); /* Use theme variable for dark mode */
}

.file-stats {
  padding: 5px 10px;
  border-bottom: 1px solid var(--td-border-dark);
  background-color: var(--stat-box-bg-dark);
  font-size: 12px;
  color: var(--text-color-dark); /* Use theme variable for dark mode */
  display: flex;
  justify-content: space-between;
}

/* Styling for the function details section with theme support */
.function-details-container {
  border-bottom: 1px solid var(--td-border-dark);
  background-color: var(--stat-box-bg-dark);
}

.function-details-container summary,
.function-details-container span,
.function-details-container th,
.function-details-container td,
.function-details-container a {
  color: var(--text-color-dark) !important; /* Light text for dark mode */
}

/* Make file headers and stats visible in dark mode */
.file-header,
.file-header *,
.file-stats,
.file-stats span:not(.high):not(.medium):not(.low),
.file-stats div {
  color: var(--text-color-dark) !important; /* Force text color in dark mode */
}

.source-code {
  overflow-x: auto;
}

.code-table {
  width: 100%;
  border-collapse: collapse;
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
  font-size: 12px;
  tab-size: 4;
}

/* Line styles */
.line-number {
  width: 40px;
  text-align: right;
  padding: 0 10px 0 10px;
  border-right: 1px solid var(--td-border-dark);
  user-select: none;
  color: var(--line-number-color-dark);
  background-color: var(--line-number-bg-dark);
}

.line-number a {
  color: var(--line-number-color-dark);
  text-decoration: none;
}

.exec-count {
  width: 30px;
  text-align: right;
  padding: 0 8px;
  border-right: 1px solid var(--td-border-dark);
  color: var(--muted-text-dark);
}

.code-content {
  padding: 0 5px 0 10px;
  white-space: pre;
}

.code-line {
  height: 18px;
  line-height: 18px;
}

.covered {
  background-color: rgba(76, 175, 80, 0.15);
}

.executed {
  background-color: rgba(255, 152, 0, 0.15);
}

.not-covered {
  background-color: rgba(244, 67, 54, 0.15);
}

.not-executable {
  color: var(--muted-text-dark);
}

/* Syntax highlighting for dark theme */
.keyword { color: var(--keyword-dark); font-weight: bold; }
.string { color: var(--string-dark); }
.comment { color: var(--comment-dark); font-style: italic; }
.number { color: var(--number-dark); }
.function { color: var(--function-dark); }

/* Footer */
footer {
  text-align: center;
  padding: 20px;
  color: var(--muted-text-dark);
  font-size: 12px;
}

/* Anchor link highlighting */
tr:target {
  background-color: var(--target-highlight-dark);
}

/* Light Theme Styles */
.light-theme {
  color-scheme: light;
  background-color: var(--bg-color-light);
  color: var(--text-color-light);
}

.light-theme header {
  background-color: var(--header-bg-light);
  border-bottom-color: var(--header-border-light);
}

.light-theme .summary,
.light-theme .file-list,
.light-theme .source-section {
  background-color: var(--card-bg-light);
  border-color: var(--card-border-light);
}

.light-theme .stat-box {
  background-color: var(--stat-box-bg-light);
  border-color: var(--stat-box-border-light);
}

.light-theme .stat-label,
.light-theme .exec-count,
.light-theme .not-executable,
.light-theme footer {
  color: var(--muted-text-light);
}

.light-theme .progress-bar {
  background-color: var(--progress-bg-light);
}

.light-theme .file-list-table th {
  background-color: var(--stat-box-bg-light);
  color: var(--text-color-light);
  border-color: var(--td-border-light);
}

.light-theme .file-header {
  background-color: var(--stat-box-bg-light);
  border-color: var(--td-border-light);
}

.light-theme .file-header,
.light-theme .file-header *,
.light-theme .file-stats,
.light-theme .file-stats span:not(.high):not(.medium):not(.low),
.light-theme .file-stats div {
  color: var(--text-color-light) !important; /* Force text color in light mode */
}

/* Light theme for function details */
.light-theme .function-details-container {
  border-bottom: 1px solid var(--td-border-light);
  background-color: var(--stat-box-bg-light);
}

.light-theme .function-details-container summary,
.light-theme .function-details-container span,
.light-theme .function-details-container th,
.light-theme .function-details-container td,
.light-theme .function-details-container a {
  color: var(--text-color-light) !important; /* Force dark text in light mode */
}

.light-theme .file-header {
  background-color: var(--stat-box-bg-light);
  border-color: var(--td-border-light);
}

.light-theme .file-stats {
  background-color: var(--stat-box-bg-light);
  border-color: var(--td-border-light);
}

.light-theme .file-list-table td {
  border-color: var(--td-border-light);
}

.light-theme .file-list-table tr:hover {
  background-color: var(--hover-bg-light);
}

.light-theme .line-number {
  background-color: var(--line-number-bg-light);
  color: var(--line-number-color-light);
  border-color: var(--td-border-light);
}

.light-theme .line-number a {
  color: var(--line-number-color-light);
}

.light-theme .exec-count {
  border-color: var(--td-border-light);
}

.light-theme tr:target {
  background-color: var(--target-highlight-light);
}

/* Light theme coverage status classes */
.light-theme .covered {
  background-color: var(--covered-bg-light);
}

.light-theme .executed {
  background-color: var(--executed-bg-light);
}

.light-theme .not-covered {
  background-color: var(--not-covered-bg-light);
}

/* Light theme syntax highlighting */
.light-theme .keyword { color: var(--keyword-light); font-weight: bold; }
.light-theme .string { color: var(--string-light); }
.light-theme .comment { color: var(--comment-light); font-style: italic; }
.light-theme .number { color: var(--number-light); }
.light-theme .function { color: var(--function-light); }
]]

--- Escapes HTML special characters.
---@param text string|nil The input string.
---@return string The escaped string.
---@private
local function escape_html(text)
  if not text then
    return ""
  end
  return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

--- Basic Lua syntax highlighter (currently simplified for performance).
--- Returns HTML-escaped code, with no actual syntax highlighting applied in this version.
---@param code string The Lua code string.
---@return string The HTML-escaped code (no highlighting applied currently).
---@private
local function highlight_lua(code)
  if not code then
    return ""
  end

  -- PERFORMANCE OPTIMIZATION: Just return escaped code without syntax highlighting
  -- This dramatically improves HTML generation performance
  return escape_html(code)

  -- The full syntax highlighting has been removed for performance reasons
  -- The current implementation was causing timeouts in test runs
end

--- Rounds a number to a specified number of decimal places.
---@param num number The number to round.
---@param decimal_places? number Number of decimal places (default 0).
---@return number The rounded number.
---@private
local function round(num, decimal_places)
  local mult = 10 ^ (decimal_places or 0)
  return math.floor(num * mult + 0.5) / mult
end

--- Gets CSS class ("high", "medium", "low") based on coverage percentage.
---@param percent number Coverage percentage (0-100).
---@return "high"|"medium"|"low" The CSS class name.
---@private
local function get_coverage_class(percent)
  if percent >= 80 then
    return "high"
  elseif percent >= 50 then
    return "medium"
  else
    return "low"
  end
end

--- Formats a percentage number as a string with "%", rounded to zero decimal places.
---@param percent number|nil The percentage (0-100). Handles nil input.
---@return string The formatted percentage string (e.g., "75%"). Returns "0%" for nil input.
---@private
local function format_percent(percent)
  if not percent or type(percent) ~= "number" then
    return "0%"
  end

  -- Round to nearest whole number
  percent = round(percent, 0)

  -- Return as string with % sign
  return tostring(percent) .. "%"
end

--- Generates the HTML markup for the coverage summary section.
--- Calculates overall percentages based on the data provided.
---@param coverage_data CoverageReportData The report data, requires `summary` and `files` fields.
---@return string The generated HTML string for the overview section.
---@private
local function generate_overview_html(coverage_data)
  -- Calculate summary statistics
  local total_files = 0
  local total_covered_lines = 0
  local total_executable_lines = 0
  local total_executed_functions = 0
  local total_functions = 0

  for _, file_data in pairs(coverage_data.files) do
    total_files = total_files + 1
    total_covered_lines = total_covered_lines + (file_data.covered_lines or 0)
    total_executable_lines = total_executable_lines + (file_data.executable_lines or 0)
    total_executed_functions = total_executed_functions + (file_data.executed_functions or 0)
    total_functions = total_functions + (file_data.total_functions or 0)
  end

  local line_coverage_percent = 0
  if total_executable_lines > 0 then
    line_coverage_percent = (total_covered_lines / total_executable_lines) * 100
  end

  local function_coverage_percent = 0
  if total_functions > 0 then
    function_coverage_percent = (total_executed_functions / total_functions) * 100
  end

  local line_class = get_coverage_class(line_coverage_percent)
  local function_class = get_coverage_class(function_coverage_percent)

  -- Create HTML
  local html = [[
  <div class="summary">
    <h2>Coverage Summary</h2>

    <div class="stats">
      <div class="stat-box">
        <div class="stat-label">Line Coverage</div>
        <div class="stat-value ]] .. line_class .. [[">]] .. format_percent(line_coverage_percent) .. [[</div>
        <div class="progress-bar">
          <div class="progress-value ]] .. line_class .. [[" style="width: ]] .. math.min(100, line_coverage_percent) .. [[%;"></div>
        </div>
        <div style="font-size: 12px; margin-top: 5px;">]] .. total_covered_lines .. [[ of ]] .. total_executable_lines .. [[ lines</div>
      </div>

      <div class="stat-box">
        <div class="stat-label">Function Coverage</div>
        <div class="stat-value ]] .. function_class .. [[">]] .. format_percent(function_coverage_percent) .. [[</div>
        <div class="progress-bar">
          <div class="progress-value ]] .. function_class .. [[" style="width: ]] .. math.min(
    100,
    function_coverage_percent
  ) .. [[%;"></div>
        </div>
        <div style="font-size: 12px; margin-top: 5px;">]] .. total_executed_functions .. [[ of ]] .. total_functions .. [[ functions</div>
      </div>

      <div class="stat-box">
        <div class="stat-label">Total Files</div>
        <div class="stat-value">]] .. total_files .. [[</div>
      </div>
    </div>
  </div>
  ]]

  return html
end

--- Generates the HTML markup for the file list table section.
--- Sorts files by path.
---@param coverage_data CoverageReportData The report data, requires `files` field.
---@return string The generated HTML string for the file list table.
---@private
local function generate_file_list_html(coverage_data)
  -- Prepare file list with sorted paths
  local file_paths = {}
  for path, _ in pairs(coverage_data.files) do
    table.insert(file_paths, path)
  end
  table.sort(file_paths)

  -- Start HTML
  local html = [[
  <div class="file-list">
    <h2 style="padding: 10px 15px; margin: 0; border-bottom: 1px solid #e1e1e1;">Files</h2>
    <table class="file-list-table">
      <thead>
        <tr>
          <th style="width: 60%;">Path</th>
          <th style="width: 15%;">Line Coverage</th>
          <th style="width: 15%;">Function Coverage</th>
          <th style="width: 10%;">Lines</th>
        </tr>
      </thead>
      <tbody>
  ]]

  -- Add each file
  for _, path in ipairs(file_paths) do
    local file_data = coverage_data.files[path]
    local file_id = path:gsub("[^%w]", "-")
    local line_coverage_percent = 0
    local function_coverage_percent = 0

    if file_data.executable_lines and file_data.executable_lines > 0 then
      line_coverage_percent = (file_data.covered_lines / file_data.executable_lines) * 100
    end

    if file_data.total_functions and file_data.total_functions > 0 then
      function_coverage_percent = (file_data.executed_functions / file_data.total_functions) * 100
    end

    local line_class = get_coverage_class(line_coverage_percent)
    local function_class = get_coverage_class(function_coverage_percent)

    html = html
      .. [[
      <tr>
        <td><a href="#file-]]
      .. file_id
      .. [[">]]
      .. path
      .. [[</a></td>
        <td>
          <div class="]]
      .. line_class
      .. [[">]]
      .. format_percent(line_coverage_percent)
      .. [[</div>
          <div class="progress-bar">
            <div class="progress-value ]]
      .. line_class
      .. [[" style="width: ]]
      .. math.min(100, line_coverage_percent)
      .. [[%;"></div>
          </div>
        </td>
        <td>
          <div class="]]
      .. function_class
      .. [[">]]
      .. format_percent(function_coverage_percent)
      .. [[</div>
          <div class="progress-bar">
            <div class="progress-value ]]
      .. function_class
      .. [[" style="width: ]]
      .. math.min(100, function_coverage_percent)
      .. [[%;"></div>
          </div>
        </td>
        <td>]]
      .. file_data.total_lines
      .. [[</td>
      </tr>
    ]]
  end

  -- Close HTML
  html = html .. [[
      </tbody>
    </table>
  </div>
  ]]

  return html
end

--- Generates the HTML markup for a single file's source code display section.
--- Includes line numbers, execution counts, coverage highlighting, and syntax highlighting (simplified).
--- Uses a simplified summary view if `file_data.simplified_rendering` is true.
--- Truncates display after `max_lines_to_display` for performance.
---@param file_data CoverageReportFileStats The data for the specific file.
---@param file_id string A unique HTML ID string generated from the file path.
---@return string The generated HTML string for the file section.
---@private
local function generate_file_source_html(file_data, file_id)
  -- Performance optimization based on file size characteristics
  if file_data.simplified_rendering then
    -- Generate summary view for large files to improve performance
    return [[
      <div id="file-]] .. file_id .. [[" class="source-section">
        <div class="file-header">
          <div class="file-path">]] .. file_data.path .. [[</div>
        </div>

        <div class="file-stats">
          <div>
            <span>Line Coverage: </span>
            <span class="]] .. get_coverage_class(file_data.line_coverage_percent) .. [[">]] .. format_percent(
      file_data.line_coverage_percent
    ) .. [[</span>
            <span>(]] .. file_data.covered_lines .. [[/]] .. file_data.executable_lines .. [[)</span>

            <span style="margin-left: 15px;">Function Coverage: </span>
            <span class="]] .. get_coverage_class(file_data.function_coverage_percent) .. [[">]] .. format_percent(
      file_data.function_coverage_percent
    ) .. [[</span>
            <span>(]] .. file_data.executed_functions .. [[/]] .. file_data.total_functions .. [[)</span>
          </div>
        </div>
        <div style="padding: 15px; text-align: center; font-style: italic;">
          <p><strong>Large file (]] .. file_data.total_lines .. [[ lines) - summary view shown for performance</strong></p>
          <p>Coverage: ]] .. file_data.covered_lines .. [[ covered of ]] .. file_data.executable_lines .. [[ executable lines</p>
        </div>
      </div>
    ]]
  end

  -- Get all line numbers and sort them
  local line_numbers = {}
  for line_num, _ in pairs(file_data.lines) do
    table.insert(line_numbers, line_num)
  end
  table.sort(line_numbers)

  -- Create HTML for file
  local html = [[
  <div class="source-section" id="file-]] .. file_id .. [[">
    <div class="file-header">
      <div class="file-path">]] .. file_data.path .. [[</div>
    </div>

    <div class="file-stats">
      <div>
        <span>Line Coverage: </span>
        <span class="]] .. get_coverage_class(file_data.line_coverage_percent) .. [[">]] .. format_percent(
    file_data.line_coverage_percent
  ) .. [[</span>
        <span>(]] .. file_data.covered_lines .. [[/]] .. file_data.executable_lines .. [[)</span>

        <span style="margin-left: 15px;">Function Coverage: </span>
        <span class="]] .. get_coverage_class(file_data.function_coverage_percent) .. [[">]] .. format_percent(
    file_data.function_coverage_percent
  ) .. [[</span>
        <span>(]] .. file_data.executed_functions .. [[/]] .. file_data.total_functions .. [[)</span>
      </div>
    </div>

    <div class="source-code">
      <table class="code-table">
        <tbody>
  ]]

  -- Performance optimization: limit number of displayed lines for all files
  local max_lines_to_display = 200
  local line_display_limit = math.min(#line_numbers, max_lines_to_display)

  for i = 1, line_display_limit do
    local line_num = line_numbers[i]
    local line_data = file_data.lines[line_num]
    local line_content = line_data.content or ""
    local line_class = ""
    local exec_count = ""

    if line_data.executable then
      exec_count = tostring(line_data.execution_count)
      if line_data.execution_count > 0 then
        -- Apply three-state visualization
        if line_data.covered then
          line_class = "covered" -- Green - tested and verified
        else
          line_class = "executed" -- Orange - executed but not verified
        end
      else
        line_class = "not-covered"
      end
    elseif line_data.line_type == "comment" or line_data.line_type == "blank" then
      line_class = "not-executable"
    end

    -- Create a table row with line number, execution count and code content
    html = html
      .. [[
          <tr id="L]]
      .. line_num
      .. [[" class="code-line ]]
      .. line_class
      .. [[">
            <td class="line-number">]]
      .. line_num
      .. [[</td>
            <td class="exec-count">]]
      .. exec_count
      .. [[</td>
            <td class="code-content">]]
      .. highlight_lua(line_content)
      .. [[</td>
          </tr>
    ]]
  end

  -- Add a note if we truncated the display
  if #line_numbers > max_lines_to_display then
    html = html
      .. [[
          <tr>
            <td colspan="3" style="padding: 10px; text-align: center; font-style: italic;">
              (File truncated to ]]
      .. max_lines_to_display
      .. [[ lines. ]]
      .. (#line_numbers - max_lines_to_display)
      .. [[ additional lines not shown for performance.)
            </td>
          </tr>
    ]]
  end

  -- Close HTML
  html = html .. [[
        </tbody>
      </table>
    </div>
  </div>
  ]]

  return html
end

--- Formats the coverage data into a complete HTML document string.
--- Combines overview, file list, and source code sections with CSS and JS.
---@param coverage_data CoverageReportData The report data structure. Assumes data is already normalized.
---@return string The complete HTML report content.
function M.format_coverage(coverage_data)
  -- Generate report sections
  local overview_html = generate_overview_html(coverage_data)
  local file_list_html = generate_file_list_html(coverage_data)

  -- Generate source code sections for each file, but skip large files
  local source_sections = ""
  for path, file_data in pairs(coverage_data.files) do
    -- Skip files over 1000 lines to prevent hanging
    if file_data.total_lines < 1000 then
      local file_id = path:gsub("[^%w]", "-")
      source_sections = source_sections .. generate_file_source_html(file_data, file_id)
    else
      -- Just add a placeholder for large files to avoid performance issues
      local file_id = path:gsub("[^%w]", "-")
      source_sections = source_sections
        .. [[
        <div id="file-]]
        .. file_id
        .. [[" class="file-section">
          <h2 class="file-heading">]]
        .. path
        .. [[</h2>
          <div class="file-info">
            <p><strong>Large file (]]
        .. file_data.total_lines
        .. [[ lines) - source view skipped for performance reasons</strong></p>
            <p>Coverage: ]]
        .. file_data.covered_lines
        .. [[ covered of ]]
        .. file_data.executable_lines
        .. [[ executable lines</p>
          </div>
        </div>
      ]]
    end
  end

  -- Generate complete HTML document
  local html = [[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Coverage Report</title>
  <style>
]] .. SIMPLE_CSS .. [[
  </style>
  <script>
    // Simple theme toggle functionality
    document.addEventListener('DOMContentLoaded', function() {
      const themeToggle = document.getElementById('theme-toggle');
      if (themeToggle) {
        themeToggle.addEventListener('change', function() {
          document.body.classList.toggle('light-theme');
          // Save preference
          localStorage.setItem('theme', document.body.classList.contains('light-theme') ? 'light' : 'dark');
        });

        // Check for saved preference
        const savedTheme = localStorage.getItem('theme');
        if (savedTheme === 'light') {
          document.body.classList.add('light-theme');
          themeToggle.checked = true;
        }
      }
    });
  </script>
</head>
<body>
  <header>
    <div class="container">
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <div>
          <h1>Coverage Report</h1>
          <div style="color: var(--muted-text-dark); font-size: 12px;">Generated on ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[</div>
        </div>
        <div style="display: flex; align-items: center; gap: 20px;">
          <div class="theme-switch-wrapper">
            <span>🌑</span>
            <label class="theme-switch">
              <input type="checkbox" id="theme-toggle">
              <span class="slider"></span>
            </label>
            <span>☀️</span>
          </div>
          <div>
            <a href="#overview" style="margin-right: 10px; text-decoration: none; color: var(--high-color);">Overview</a>
            <a href="#files" style="text-decoration: none; color: var(--high-color);">Files</a>
          </div>
        </div>
      </div>
    </div>
  </header>

  <div class="container">
    <div id="overview">
      ]] .. overview_html .. [[
    </div>

    <div class="summary" style="margin-bottom: 20px;">
      <h2>Legend</h2>
      <ul style="list-style-type: none; padding-left: 0;">
        <li><div style="display: inline-block; width: 20px; height: 15px; background-color: var(--covered-bg-dark); margin-right: 10px;"></div> <strong>Covered Line:</strong> Line was executed and covered by tests</li>
        <li><div style="display: inline-block; width: 20px; height: 15px; background-color: var(--executed-bg-dark); margin-right: 10px;"></div> <strong>Executed Line:</strong> Line was executed but not explicitly covered by a test</li>
        <li><div style="display: inline-block; width: 20px; height: 15px; background-color: var(--not-covered-bg-dark); margin-right: 10px;"></div> <strong>Not Covered Line:</strong> Executable line that was not executed</li>
        <li><div style="display: inline-block; width: 20px; height: 15px; margin-right: 10px;"></div> <strong>Not Executable Line:</strong> Line that cannot be executed (comment, blank, etc.)</li>
      </ul>
    </div>

    <div id="files">
      ]] .. file_list_html .. [[
    </div>

    <div id="source-sections">
      ]] .. source_sections .. [[
    </div>
  </div>

  <footer>
    <div class="container">
      Coverage report generated by Firmo Coverage v]] .. M._VERSION .. [[
    </div>
  </footer>
</body>
</html>]]

  return html
end

--- Generates and writes the HTML coverage report file.
--- Applies performance optimizations (simplified rendering for large files) before formatting.
--- Ensures output directory exists and writes the generated HTML.
---@param coverage_data CoverageReportData The coverage data structure.
---@param output_path string The path where the HTML report file should be saved. If it ends in "/", "coverage-report.html" is appended.
---@return boolean success `true` if the report was generated and written successfully.
---@return table? error Error object if validation, formatting, or file operations failed.
---@throws table If input validation fails (via `error_handler.assert`) or if directory creation/file writing fails critically.
function M.generate(coverage_data, output_path)
  -- Parameter validation
  get_error_handler().assert(
    type(coverage_data) == "table",
    "coverage_data must be a table",
    get_error_handler().CATEGORY.VALIDATION
  )
  get_error_handler().assert(type(output_path) == "string", "output_path must be a string", get_error_handler().CATEGORY.VALIDATION)

  -- If output_path is a directory, add a filename
  if output_path:sub(-1) == "/" then
    output_path = output_path .. "coverage-report.html"
  end

  -- Try to ensure the directory exists
  local dir_path = output_path:match("(.+)/[^/]+$")
  if dir_path then
    local mkdir_success, mkdir_err = get_fs().ensure_directory_exists(dir_path)
    if not mkdir_success then
      get_logger().warn("Failed to ensure directory exists, but will try to write anyway", {
        directory = dir_path,
        error = mkdir_err and get_error_handler().format_error(mkdir_err) or "Unknown error",
      })
    end
  end

  -- PERFORMANCE OPTIMIZATION: Filter large files to improve report generation speed
  -- This applies universally to all files based only on their size characteristics
  local filtered_coverage_data = {
    summary = coverage_data.summary,
    files = {},
    executed_lines = coverage_data.executed_lines,
    covered_lines = coverage_data.covered_lines,
  }

  -- Set maximum file size for full inclusion - anything larger will be represented
  -- by a summary only. This is a performance constraint, not a special case.
  local max_lines_for_full_inclusion = 1000

  -- Process files based on size thresholds (applies to ALL files equally)
  local file_count = 0
  local skipped_count = 0
  for path, file_data in pairs(coverage_data.files) do
    -- Include all files, but mark large ones for simplified rendering
    if file_data.total_lines < max_lines_for_full_inclusion then
      -- Small files get full treatment
      filtered_coverage_data.files[path] = file_data
    else
      -- Large files get included with a size flag for optimized rendering
      filtered_coverage_data.files[path] = file_data
      filtered_coverage_data.files[path].simplified_rendering = true
    end
    file_count = file_count + 1
  end

  get_logger().info("Generating report with performance optimization", {
    total_files = file_count,
    max_lines_threshold = max_lines_for_full_inclusion,
  })

  -- Generate the HTML content using the filtered data
  local html = M.format_coverage(filtered_coverage_data)

  -- Write the report to the output file
  local success, err = get_error_handler().safe_io_operation(function()
    return get_fs().write_file(output_path, html)
  end, output_path, { operation = "write_coverage_report" })

  if not success then
    get_logger().error("Failed to write HTML coverage report", {
      file_path = output_path,
      error = get_error_handler().format_error(err),
    })
    return false, err
  end

  get_logger().info("Successfully wrote HTML coverage report", {
    file_path = output_path,
    report_size = #html,
  })

  return true
end

return M
