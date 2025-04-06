--- JUnit XML Formatter for Coverage Reports
-- Generates JUnit XML format coverage reports
-- @module coverage.report.junit
-- @author Firmo Team

local Formatter = require("lib.coverage.report.formatter")
local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")

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
  ["'"] = "&apos;"
}

-- Escape a string for XML output
local function xml_escape(s)
  if type(s) ~= "string" then
    s = tostring(s)
  end
  
  return s:gsub("[&<>'\"]", xml_escape_chars)
end

-- Validate coverage data structure for JUnit formatter
function JUnitFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end
  
  -- Additional JUnit-specific validation if needed
  
  return true
end

-- Format coverage data as JUnit XML
function JUnitFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, error_handler.validation_error("Coverage data is required", {formatter = self.name})
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

-- Build JUnit XML format content
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
  table.sort(sorted_files, function(a, b) return a.path < b.path end)
  
  -- Build test cases for each file
  for _, file in ipairs(sorted_files) do
    local path = file.path
    local file_data = file.data
    local file_threshold = options.file_threshold or 80
    local file_coverage = file_data.summary.coverage_percent or 0
    local file_test_passed = file_coverage >= file_threshold
    
    -- Mock test time (could be proportional to file size or configurable)
    local test_time = 0.01  -- Default small duration
    total_time = total_time + test_time
    
    -- Create test case XML
    local test_case = {}
    table.insert(test_case, '    <testcase classname="' .. xml_escape(path:gsub("/", ".")) .. 
                             '" name="Coverage" time="' .. test_time .. '">')
    
    -- Add properties
    table.insert(test_case, '      <properties>')
    table.insert(test_case, '        <property name="coverage_percent" value="' .. 
                             string.format("%.2f", file_coverage) .. '" />')
    table.insert(test_case, '        <property name="threshold" value="' .. file_threshold .. '" />')
    table.insert(test_case, '        <property name="total_lines" value="' .. 
                             file_data.summary.total_lines .. '" />')
    table.insert(test_case, '        <property name="covered_lines" value="' .. 
                             file_data.summary.covered_lines .. '" />')
    table.insert(test_case, '        <property name="executed_lines" value="' .. 
                             file_data.summary.executed_lines .. '" />')
    table.insert(test_case, '        <property name="not_covered_lines" value="' .. 
                             file_data.summary.not_covered_lines .. '" />')
    table.insert(test_case, '      </properties>')
    
    -- Add failure if coverage is below threshold
    if not file_test_passed then
      failure_count = failure_count + 1
      table.insert(test_case, '      <failure message="Coverage below threshold" type="CoverageFailure">')
      table.insert(test_case, '        Coverage: ' .. string.format("%.2f", file_coverage) .. 
                               '% (threshold: ' .. file_threshold .. '%)')
      
      -- Optional: Add uncovered line details
      if options.include_uncovered_lines and file_data.lines then
        local uncovered_lines = {}
        for line_num, line_data in pairs(file_data.lines) do
          if not (line_data.covered or line_data.executed or 
                 (line_data.execution_count and line_data.execution_count > 0)) then
            table.insert(uncovered_lines, tonumber(line_num))
          end
        end
        
        if #uncovered_lines > 0 then
          table.sort(uncovered_lines)
          table.insert(test_case, '')
          table.insert(test_case, '        Uncovered lines:')
          
          -- Group consecutive lines for readability
          local ranges = self:group_consecutive_lines(uncovered_lines)
          
          for _, range in ipairs(ranges) do
            if range.start == range.end_ then
              table.insert(test_case, '          - Line ' .. range.start)
            else
              table.insert(test_case, '          - Lines ' .. range.start .. '-' .. range.end_)
            end
          end
        end
      end
      
      table.insert(test_case, '      </failure>')
    end
    
    table.insert(test_case, '    </testcase>')
    
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
  table.insert(overall_test, '    <testcase classname="' .. xml_escape(options.suite_name) .. 
                             '" name="OverallCoverage" time="' .. overall_test_time .. '">')
  
  -- Add properties
  table.insert(overall_test, '      <properties>')
  table.insert(overall_test, '        <property name="coverage_percent" value="' .. 
                             string.format("%.2f", overall_coverage) .. '" />')
  table.insert(overall_test, '        <property name="threshold" value="' .. overall_threshold .. '" />')
  table.insert(overall_test, '        <property name="total_files" value="' .. 
                             data.summary.total_files .. '" />')
  table.insert(overall_test, '        <property name="total_lines" value="' .. 
                             data.summary.total_lines .. '" />')
  table.insert(overall_test, '        <property name="covered_lines" value="' .. 
                             data.summary.covered_lines .. '" />')
  table.insert(overall_test, '        <property name="executed_lines" value="' .. 
                             data.summary.executed_lines .. '" />')
  table.insert(overall_test, '      </properties>')
  
  -- Add failure if overall coverage is below threshold
  if not overall_test_passed then
    failure_count = failure_count + 1
    table.insert(overall_test, '      <failure message="Overall coverage below threshold" type="CoverageFailure">')
    table.insert(overall_test, '        Coverage: ' .. string.format("%.2f", overall_coverage) .. 
                               '% (threshold: ' .. overall_threshold .. '%)')
    table.insert(overall_test, '      </failure>')
  end
  
  table.insert(overall_test, '    </testcase>')
  
  -- Add overall test case to the beginning
  table.insert(test_cases, 1, table.concat(overall_test, "\n"))
  
  -- Build the full testsuite XML
  local test_count = #sorted_files + 1  -- Files + overall
  
  -- Add testsuite start tag with attributes
  table.insert(lines, '<testsuites>')
  table.insert(lines, '  <testsuite name="' .. xml_escape(options.suite_name) .. '"')
  table.insert(lines, '             tests="' .. test_count .. '"')
  table.insert(lines, '             errors="' .. error_count .. '"')
  table.insert(lines, '             failures="' .. failure_count .. '"')
  table.insert(lines, '             skipped="' .. skipped_count .. '"')
  table.insert(lines, '             time="' .. total_time .. '"')
  table.insert(lines, '             timestamp="' .. options.timestamp .. '"')
  table.insert(lines, '             hostname="' .. (options.hostname or xml_escape(io.popen('hostname'):read('*a'):gsub('\n', ''))) .. '">')
  
  -- Add any system properties
  table.insert(lines, '    <properties>')
  table.insert(lines, '      <property name="coverage_tool" value="Firmo Coverage" />')
  table.insert(lines, '      <property name="formatter_version" value="' .. self._VERSION .. '" />')
  
  -- Add any custom properties if provided
  if options.properties then
    for name, value in pairs(options.properties) do
      table.insert(lines, '      <property name="' .. xml_escape(name) .. 
                         '" value="' .. xml_escape(value) .. '" />')
    end
  end
  
  table.insert(lines, '    </properties>')
  
  -- Add test cases
  for _, test_case in ipairs(test_cases) do
    table.insert(lines, test_case)
  end
  
  -- Add testsuite and testsuites end tags
  table.insert(lines, '  </testsuite>')
  table.insert(lines, '</testsuites>')
  
  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

-- Group consecutive line numbers into ranges
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

-- Write the report to the filesystem
function JUnitFormatter:write(xml_content, output_path, options)
  return Formatter.write(self, xml_content, output_path, options)
end

return JUnitFormatter

