--- JUnit XML Formatter for Coverage Reports
---
--- Generates coverage reports in JUnit XML format, treating each file's coverage
--- and the overall coverage against configured thresholds as individual "test cases".
--- This allows CI systems to track coverage metrics alongside test results.
---
--- @module lib.reporting.formatters.junit
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

--- @class CoverageReportFileStats Simplified structure expected by this formatter.
--- @field name string File path.
--- @field path string Same as name.
--- @field summary { coverage_percent: number, total_lines: number, covered_lines: number, executed_lines: number, not_covered_lines: number } File summary stats.
--- @field lines? table<number, { covered?: boolean, executed?: boolean, execution_count?: number }> Optional line details for failure messages.

--- @class CoverageReportSummary Simplified structure expected by this formatter.
--- @field coverage_percent number Overall coverage percentage.
--- @field total_files number Total number of files.
--- @field total_lines number Total lines across all files.
--- @field covered_lines number Total covered lines across all files.
--- @field executed_lines number Total executed lines across all files.

--- @class CoverageReportData Expected structure for coverage data input (simplified).
--- @field summary CoverageReportSummary Overall summary statistics.
--- @field files table<string, CoverageReportFileStats> Map of file paths to file statistics.

---@class JUnitFormatter : Formatter JUnit XML Formatter for coverage reports.
--- Treats each file's coverage and overall coverage as a test case, generating
--- a JUnit XML report suitable for CI systems.
---@field _VERSION string Module version.
---@field validate fun(self: JUnitFormatter, coverage_data: CoverageReportData): boolean, table? Validates coverage data. Returns `true` or `false, error`.
---@field format fun(self: JUnitFormatter, coverage_data: CoverageReportData, options?: { threshold?: number, file_threshold?: number, suite_name?: string, timestamp?: string, hostname?: string, include_uncovered_lines?: boolean, properties?: table<string, string> }): string|nil, table? Formats coverage data as a JUnit XML string. Returns `xml_string, nil` or `nil, error`.
---@field build_junit_xml fun(self: JUnitFormatter, data: CoverageReportData, options: table): string Builds the JUnit XML content. Returns XML string.
---@field group_consecutive_lines fun(self: JUnitFormatter, line_numbers: number[]): {start: number, end_: number}[] Groups consecutive line numbers into ranges. Returns array of range tables.
---@field write fun(self: JUnitFormatter, xml_content: string, output_path: string, options?: table): boolean, table? Writes the XML content to a file. Returns `true, nil` or `false, error`. @throws table If writing fails critically.
---@field register fun(formatters: table): boolean, table? Registers the JUnit formatter with the main registry. Returns `true, nil` or `false, error`. @throws table If validation fails.

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

-- Create JUnit formatter class
local JUnitFormatter = Formatter.extend("junit", "xml")

--- JUnit Formatter version
JUnitFormatter._VERSION = "1.0.0"

-- XML escape sequences
local xml_escape_chars = {
  ["&"] = "&amp;",
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ['"'] = "&quot;",
  ["'"] = "&apos;",
}

--- Escapes special XML characters in a string.
---@param s string|any The input string (or value convertible to string).
---@return string The escaped string.
---@private
local function xml_escape(s)
  if type(s) ~= "string" then
    s = tostring(s)
  end

  return s:gsub("[&<>'\"]", xml_escape_chars)
end

--- Validates the coverage data structure. Inherits base validation.
---@param self JUnitFormatter The formatter instance.
---@param coverage_data CoverageReportData The coverage data to validate.
---@return boolean success `true` if validation passes.
---@return table? error Error object if validation failed.
function JUnitFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end

  -- Additional JUnit-specific validation if needed

  return true
end

--- Formats coverage data into a JUnit XML string.
--- Treats overall coverage and each file's coverage as separate test cases.
---@param self JUnitFormatter The formatter instance.
---@param coverage_data CoverageReportData The coverage data structure.
---@param options? { threshold?: number, file_threshold?: number, suite_name?: string, timestamp?: string, hostname?: string, include_uncovered_lines?: boolean, properties?: table<string, string> } Formatting options:
---  - `threshold` (number, default 80): Overall coverage percentage required to pass.
---  - `file_threshold` (number, default: same as `threshold`): Per-file coverage percentage required.
---  - `suite_name` (string, default "CoverageTests"): Name for the `<testsuite>`.
---  - `timestamp` (string): ISO 8601 timestamp for the report. Defaults to current time.
---  - `hostname` (string): Hostname for the report. Defaults to system hostname.
---  - `include_uncovered_lines` (boolean, default false): Include lists of uncovered lines in failure messages.
---  - `properties` (table): Additional `<property>` tags to include in the report.
---@return string|nil xml_content The generated JUnit XML content as a single string, or `nil` on validation error.
---@return table? error Error object if validation failed.
function JUnitFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, get_error_handler().validation_error("Coverage data is required", { formatter = self.name })
  end

  -- Apply options with defaults
  options = options or {}
  options.threshold = options.threshold or 80
  options.file_threshold = options.file_threshold or options.threshold
  options.suite_name = options.suite_name or "CoverageTests"
  options.timestamp = options.timestamp or os.date("%Y-%m-%dT%H:%M:%S")

  -- Normalize the coverage data
  local normalized_data = self:normalize_coverage_data(coverage_data)

  -- Begin building JUnit XML content
  local xml_content = self:build_junit_xml(normalized_data, options)

  return xml_content
end

--- Builds the main JUnit XML structure based on formatted coverage data.
---@param self JUnitFormatter The formatter instance.
---@param data CoverageReportData The normalized coverage data (requires `summary`, `files`).
---@param options table Formatting options (passed from `format` method).
---@return string xml_content The generated JUnit XML string.
function JUnitFormatter:build_junit_xml(data, options)
  local lines = {}
  -- Add XML header
  table.insert(lines, '<?xml version="1.0" encoding="UTF-8" ?>')

  -- Process files for test cases
  local test_cases = {}
  local error_count = 0
  local failure_count = 0
  local skipped_count = 0
  local total_time = 0

  -- Process each file
  local sorted_files = {}
  for path, file_data in pairs(data.files or {}) do
    table.insert(sorted_files, { path = path, data = file_data })
  end

  -- Sort files by path for consistent output
  table.sort(sorted_files, function(a, b)
    return a.path < b.path
  end)

  -- Build test cases for each file
  for _, file in ipairs(sorted_files) do
    local path = file.path
    local file_data = file.data
    local file_threshold = options.file_threshold or 80
    local file_coverage = file_data.summary.coverage_percent or 0
    local file_test_passed = file_coverage >= file_threshold

    -- Mock test time (could be proportional to file size or configurable)
    local test_time = 0.01 -- Default small duration
    total_time = total_time + test_time

    -- Create test case XML
    local test_case = {}
    table.insert(
      test_case,
      '    <testcase classname="' .. xml_escape(path:gsub("/", ".")) .. '" name="Coverage" time="' .. test_time .. '">'
    )

    -- Add properties
    table.insert(test_case, "      <properties>")
    table.insert(
      test_case,
      '        <property name="coverage_percent" value="' .. string.format("%.2f", file_coverage) .. '" />'
    )
    table.insert(test_case, '        <property name="threshold" value="' .. file_threshold .. '" />')
    table.insert(test_case, '        <property name="total_lines" value="' .. file_data.summary.total_lines .. '" />')
    table.insert(
      test_case,
      '        <property name="covered_lines" value="' .. file_data.summary.covered_lines .. '" />'
    )
    table.insert(
      test_case,
      '        <property name="executed_lines" value="' .. file_data.summary.executed_lines .. '" />'
    )
    table.insert(
      test_case,
      '        <property name="not_covered_lines" value="' .. file_data.summary.not_covered_lines .. '" />'
    )
    table.insert(test_case, "      </properties>")

    -- Add failure if coverage is below threshold
    if not file_test_passed then
      failure_count = failure_count + 1
      table.insert(test_case, '      <failure message="Coverage below threshold" type="CoverageFailure">')
      table.insert(
        test_case,
        "        Coverage: " .. string.format("%.2f", file_coverage) .. "% (threshold: " .. file_threshold .. "%)"
      )

      -- Optional: Add uncovered line details
      if options.include_uncovered_lines and file_data.lines then
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
          table.insert(test_case, "")
          table.insert(test_case, "        Uncovered lines:")

          -- Group consecutive lines for readability
          local ranges = self:group_consecutive_lines(uncovered_lines)

          for _, range in ipairs(ranges) do
            if range.start == range.end_ then
              table.insert(test_case, "          - Line " .. range.start)
            else
              table.insert(test_case, "          - Lines " .. range.start .. "-" .. range.end_)
            end
          end
        end
      end

      table.insert(test_case, "      </failure>")
    end

    table.insert(test_case, "    </testcase>")

    -- Add this test case
    table.insert(test_cases, table.concat(test_case, "\n"))
  end

  -- Add overall coverage test
  local overall_threshold = options.threshold or 80
  local overall_coverage = data.summary.coverage_percent or 0
  local overall_test_passed = overall_coverage >= overall_threshold

  -- Mock test time for overall coverage
  local overall_test_time = 0.01
  total_time = total_time + overall_test_time

  -- Create overall test case XML
  local overall_test = {}
  table.insert(
    overall_test,
    '    <testcase classname="'
      .. xml_escape(options.suite_name)
      .. '" name="OverallCoverage" time="'
      .. overall_test_time
      .. '">'
  )

  -- Add properties
  table.insert(overall_test, "      <properties>")
  table.insert(
    overall_test,
    '        <property name="coverage_percent" value="' .. string.format("%.2f", overall_coverage) .. '" />'
  )
  table.insert(overall_test, '        <property name="threshold" value="' .. overall_threshold .. '" />')
  table.insert(overall_test, '        <property name="total_files" value="' .. data.summary.total_files .. '" />')
  table.insert(overall_test, '        <property name="total_lines" value="' .. data.summary.total_lines .. '" />')
  table.insert(overall_test, '        <property name="covered_lines" value="' .. data.summary.covered_lines .. '" />')
  table.insert(overall_test, '        <property name="executed_lines" value="' .. data.summary.executed_lines .. '" />')
  table.insert(overall_test, "      </properties>")

  -- Add failure if overall coverage is below threshold
  if not overall_test_passed then
    failure_count = failure_count + 1
    table.insert(overall_test, '      <failure message="Overall coverage below threshold" type="CoverageFailure">')
    table.insert(
      overall_test,
      "        Coverage: " .. string.format("%.2f", overall_coverage) .. "% (threshold: " .. overall_threshold .. "%)"
    )
    table.insert(overall_test, "      </failure>")
  end

  table.insert(overall_test, "    </testcase>")

  -- Add overall test case to the beginning
  table.insert(test_cases, 1, table.concat(overall_test, "\n"))

  -- Build the full testsuite XML
  local test_count = #sorted_files + 1 -- Files + overall

  -- Add testsuite start tag with attributes
  table.insert(lines, "<testsuites>")
  table.insert(lines, '  <testsuite name="' .. xml_escape(options.suite_name) .. '"')
  table.insert(lines, '             tests="' .. test_count .. '"')
  table.insert(lines, '             errors="' .. error_count .. '"')
  table.insert(lines, '             failures="' .. failure_count .. '"')
  table.insert(lines, '             skipped="' .. skipped_count .. '"')
  table.insert(lines, '             time="' .. total_time .. '"')
  table.insert(lines, '             timestamp="' .. options.timestamp .. '"')
  table.insert(lines, '             hostname="' .. (options.hostname or os.getenv("HOSTNAME") or "unknown") .. '">')

  -- Add any system properties
  table.insert(lines, "    <properties>")
  table.insert(lines, '      <property name="coverage_tool" value="Firmo Coverage" />')
  table.insert(lines, '      <property name="formatter_version" value="' .. self._VERSION .. '" />')

  -- Add any custom properties if provided
  if options.properties then
    for name, value in pairs(options.properties) do
      table.insert(lines, '      <property name="' .. xml_escape(name) .. '" value="' .. xml_escape(value) .. '" />')
    end
  end

  table.insert(lines, "    </properties>")

  -- Add test cases
  for _, test_case in ipairs(test_cases) do
    table.insert(lines, test_case)
  end

  -- Add testsuite and testsuites end tags
  table.insert(lines, "  </testsuite>")
  table.insert(lines, "</testsuites>")

  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

--- Helper function to group sorted consecutive line numbers into ranges for more readable output.
--- E.g., {1, 2, 3, 5, 6, 8} becomes `{{start=1, end_=3}, {start=5, end_=6}, {start=8, end_=8}}`.
---@param self JUnitFormatter The formatter instance.
---@param line_numbers number[] A sorted array of line numbers.
---@return {start: number, end_: number}[] ranges An array of range tables.
function JUnitFormatter:group_consecutive_lines(line_numbers)
  if not line_numbers or #line_numbers == 0 then
    return {}
  end

  local ranges = {}
  local current_range = { start = line_numbers[1], end_ = line_numbers[1] }

  for i = 2, #line_numbers do
    if line_numbers[i] == current_range.end_ + 1 then
      -- Continue the current range
      current_range.end_ = line_numbers[i]
    else
      -- End the current range and start a new one
      table.insert(ranges, current_range)
      current_range = { start = line_numbers[i], end_ = line_numbers[i] }
    end
  end

  -- Add the last range
  table.insert(ranges, current_range)

  return ranges
end

--- Writes the generated JUnit XML content to a file.
--- Inherits the write logic (including directory creation) from the base `Formatter`.
---@param self JUnitFormatter The formatter instance.
---@param xml_content string The XML content string to write.
---@param output_path string The path to the output file.
---@param options? table Optional options passed to the base `write` method (currently unused by base).
---@return boolean success `true` if writing succeeded.
---@return table? error Error object if writing failed.
---@throws table If writing fails critically.
function JUnitFormatter:write(xml_content, output_path, options)
  return Formatter.write(self, xml_content, output_path, options)
end

--- Registers the JUnit formatter with the main formatters registry.
---@param formatters table The main formatters registry object (must contain `results` table).
---@return boolean success `true` if registration succeeded.
---@return table? error Error object if validation failed.
---@throws table If validation fails critically.
function JUnitFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    local err = get_error_handler().validation_error("Invalid formatters registry", {
      operation = "register",
      formatter = "junit",
      provided_type = type(formatters),
    })
    return false, err
  end

  -- Create a new instance of the formatter
  local formatter = JUnitFormatter.new()

  -- Register format_results function
  formatters.results.junit = function(results_data, options)
    return formatter:format(results_data, options)
  end

  return true
end

return JUnitFormatter
