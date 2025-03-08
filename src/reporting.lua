-- lust-next reporting module
-- Centralized module for all report generation and file output

local M = {}

-- Load the JSON module if available
local json_module
local ok, mod = pcall(require, "src.json")
if ok then
  json_module = mod
else
  -- Simple fallback JSON encoder if module isn't available
  json_module = {
    encode = function(t)
      if type(t) ~= "table" then return tostring(t) end
      local s = "{"
      local first = true
      for k, v in pairs(t) do
        if not first then s = s .. "," else first = false end
        if type(k) == "string" then
          s = s .. '"' .. k .. '":'
        else
          s = s .. "[" .. tostring(k) .. "]:"
        end
        if type(v) == "table" then
          s = s .. json_module.encode(v)
        elseif type(v) == "string" then
          s = s .. '"' .. v .. '"'
        elseif type(v) == "number" or type(v) == "boolean" then
          s = s .. tostring(v)
        else
          s = s .. '"' .. tostring(v) .. '"'
        end
      end
      return s .. "}"
    end
  }
end

-- Helper function to escape XML special characters
local function escape_xml(str)
  if type(str) ~= "string" then
    return tostring(str or "")
  end
  
  return str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub("\"", "&quot;")
            :gsub("'", "&apos;")
end

---------------------------
-- REPORT DATA STRUCTURES
---------------------------

-- Standard data structures that modules should return

-- Coverage report data structure
-- Modules should return this structure instead of directly generating reports
M.CoverageData = {
  -- Example structure that modules should follow:
  -- files = {}, -- Data per file (line execution, function calls)
  -- summary = {  -- Overall statistics
  --   total_files = 0,
  --   covered_files = 0,
  --   total_lines = 0,
  --   covered_lines = 0,
  --   total_functions = 0,
  --   covered_functions = 0,
  --   line_coverage_percent = 0,
  --   function_coverage_percent = 0, 
  --   overall_percent = 0
  -- }
}

-- Quality report data structure
-- Modules should return this structure instead of directly generating reports
M.QualityData = {
  -- Example structure that modules should follow:
  -- level = 0, -- Achieved quality level (0-5)
  -- level_name = "", -- Level name (e.g., "basic", "standard", etc.)
  -- tests = {}, -- Test data with assertions, patterns, etc.
  -- summary = {
  --   tests_analyzed = 0,
  --   tests_passing_quality = 0,
  --   quality_percent = 0,
  --   assertions_total = 0,
  --   assertions_per_test_avg = 0,
  --   issues = {}
  -- }
}

-- Test results data structure for JUnit XML and other test reporters
M.TestResultsData = {
  -- Example structure that modules should follow:
  -- name = "TestSuite", -- Name of the test suite
  -- timestamp = "2023-01-01T00:00:00", -- ISO 8601 timestamp
  -- tests = 0, -- Total number of tests
  -- failures = 0, -- Number of failed tests
  -- errors = 0, -- Number of tests with errors
  -- skipped = 0, -- Number of skipped tests
  -- time = 0, -- Total execution time in seconds
  -- test_cases = { -- Array of test case results
  --   {
  --     name = "test_name",
  --     classname = "test_class", -- Usually module/file name
  --     time = 0, -- Execution time in seconds
  --     status = "pass", -- One of: pass, fail, error, skipped, pending
  --     failure = { -- Only present if status is fail
  --       message = "Failure message",
  --       type = "Assertion",
  --       details = "Detailed failure information"
  --     },
  --     error = { -- Only present if status is error
  --       message = "Error message",
  --       type = "RuntimeError", 
  --       details = "Stack trace or error details"
  --     }
  --   }
  -- }
}

---------------------------
-- REPORT FORMATTERS
---------------------------

-- Formatter registries for built-in and custom formatters
local formatters = {
  coverage = {},     -- Coverage report formatters
  quality = {},      -- Quality report formatters
  results = {}       -- Test results formatters
}

-- Coverage report formatters
local coverage_formatters = formatters.coverage

-- Generate a summary coverage report from coverage data
coverage_formatters.summary = function(coverage_data)
  -- Validate the input data to prevent runtime errors
  if not coverage_data then
    print("ERROR [Reporting] Missing coverage data")
    return {
      files = {},
      total_files = 0,
      covered_files = 0,
      files_pct = 0,
      total_lines = 0,
      covered_lines = 0,
      lines_pct = 0,
      total_functions = 0,
      covered_functions = 0,
      functions_pct = 0,
      overall_pct = 0
    }
  end
  
  -- Make sure we have summary data
  local summary = coverage_data.summary or {
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
  
  -- Debug output for troubleshooting
  print("DEBUG [Reporting] Formatting coverage data with:")
  print("  Total files: " .. (summary.total_files or 0))
  print("  Covered files: " .. (summary.covered_files or 0))
  print("  Total lines: " .. (summary.total_lines or 0))
  print("  Covered lines: " .. (summary.covered_lines or 0))
  
  local report = {
    files = coverage_data.files or {},
    total_files = summary.total_files or 0,
    covered_files = summary.covered_files or 0,
    files_pct = summary.total_files > 0 and 
                ((summary.covered_files or 0) / summary.total_files * 100) or 0,
    
    total_lines = summary.total_lines or 0,
    covered_lines = summary.covered_lines or 0,
    lines_pct = summary.total_lines > 0 and 
               ((summary.covered_lines or 0) / summary.total_lines * 100) or 0,
    
    total_functions = summary.total_functions or 0,
    covered_functions = summary.covered_functions or 0,
    functions_pct = summary.total_functions > 0 and 
                   ((summary.covered_functions or 0) / summary.total_functions * 100) or 0,
    
    overall_pct = summary.overall_percent or 0,
  }
  
  return report
end

-- Generate a JSON coverage report
coverage_formatters.json = function(coverage_data)
  local report = coverage_formatters.summary(coverage_data)
  return json_module.encode(report)
end

-- Generate an HTML coverage report with syntax highlighting
coverage_formatters.html = function(coverage_data)
  local report = coverage_formatters.summary(coverage_data)
  
  -- Generate HTML header with enhanced styling for syntax highlighting
  local html = [[
<\!DOCTYPE html>
<html>
<head>
  <title>Lust-Next Coverage Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    .summary { margin: 20px 0; background: #f5f5f5; padding: 10px; border-radius: 5px; }
    .progress { background-color: #e0e0e0; border-radius: 5px; height: 20px; }
    .progress-bar { height: 20px; border-radius: 5px; background-color: #4CAF50; }
    .low { background-color: #f44336; }
    .medium { background-color: #ff9800; }
    .high { background-color: #4CAF50; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    .file-link { color: #0366d6; text-decoration: none; cursor: pointer; }
    .file-link:hover { text-decoration: underline; }
    
    /* Source code viewer */
    .source-container { display: none; margin: 20px 0; background: #f8f8f8; border: 1px solid #ddd; border-radius: 5px; }
    .source-header { padding: 10px; background: #eaeaea; border-bottom: 1px solid #ddd; font-weight: bold; }
    .source-code { font-family: 'Courier New', monospace; padding: 0; margin: 0; }
    .source-line { padding: 2px 8px; display: flex; }
    .source-line:hover { background-color: #f0f0f0; }
    .source-line-number { color: #999; text-align: right; padding-right: 10px; border-right: 1px solid #ddd; min-width: 40px; user-select: none; }
    .source-line-content { padding-left: 10px; white-space: pre; }
    .source-line.covered { background-color: rgba(77, 175, 80, 0.1); }
    .source-line.not-covered { background-color: rgba(244, 67, 54, 0.1); }
    
    /* Syntax highlighting */
    .keyword { color: #0000ff; font-weight: bold; }
    .string { color: #a31515; }
    .comment { color: #008000; font-style: italic; }
    .number { color: #098658; }
    .operator { color: #666666; }
    .function-name { color: #795e26; }
    .table-key { color: #267f99; }
  </style>
  <script>
    function toggleSource(fileId) {
      const container = document.getElementById('source-' + fileId);
      if (container.style.display === 'none' || container.style.display === '') {
        container.style.display = 'block';
      } else {
        container.style.display = 'none';
      }
    }
  </script>
</head>
<body>
  <h1>Lust-Next Coverage Report</h1>
  <div class="summary">
    <h2>Summary</h2>
    <p>Overall Coverage: ]].. string.format("%.2f%%", report.overall_pct) ..[[</p>
    <div class="progress">
      <div class="progress-bar ]].. (report.overall_pct < 50 and "low" or (report.overall_pct < 80 and "medium" or "high")) ..[[" style="width: ]].. math.min(100, report.overall_pct) ..[[%;"></div>
    </div>
    <p>Lines: ]].. report.covered_lines ..[[ / ]].. report.total_lines ..[[ (]].. string.format("%.2f%%", report.lines_pct) ..[[)</p>
    <p>Functions: ]].. report.covered_functions ..[[ / ]].. report.total_functions ..[[ (]].. string.format("%.2f%%", report.functions_pct) ..[[)</p>
    <p>Files: ]].. report.covered_files ..[[ / ]].. report.total_files ..[[ (]].. string.format("%.2f%%", report.files_pct) ..[[)</p>
  </div>
  <table>
    <tr>
      <th>File</th>
      <th>Lines</th>
      <th>Line Coverage</th>
      <th>Functions</th>
      <th>Function Coverage</th>
    </tr>
  ]]
  
  -- Add file rows
  local fileId = 0
  for file, stats in pairs(report.files or {}) do
    fileId = fileId + 1
    local line_pct = (stats.total_lines or 0) > 0 and 
                    ((stats.covered_lines or 0) / stats.total_lines * 100) or 0
    local func_pct = (stats.total_functions or 0) > 0 and 
                    ((stats.covered_functions or 0) / stats.total_functions * 100) or 0
    
    -- Extract filename for display
    local filename = file:match("([^/\\]+)$") or file
    
    html = html .. [[
    <tr>
      <td><span class="file-link" onclick="toggleSource(']] .. fileId .. [[')" title="Click to view source">]].. filename ..[[</span> <small>]].. file ..[[</small></td>
      <td>]].. stats.covered_lines ..[[ / ]].. stats.total_lines ..[[</td>
      <td>
        <div class="progress">
          <div class="progress-bar ]].. (line_pct < 50 and "low" or (line_pct < 80 and "medium" or "high")) ..[[" style="width: ]].. math.min(100, line_pct) ..[[%;"></div>
        </div>
        ]].. string.format("%.2f%%", line_pct) ..[[
      </td>
      <td>]].. stats.covered_functions ..[[ / ]].. stats.total_functions ..[[</td>
      <td>
        <div class="progress">
          <div class="progress-bar ]].. (func_pct < 50 and "low" or (func_pct < 80 and "medium" or "high")) ..[[" style="width: ]].. math.min(100, func_pct) ..[[%;"></div>
        </div>
        ]].. string.format("%.2f%%", func_pct) ..[[
      </td>
    </tr>
    ]]
    
    -- Add the source code section for this file
    local source_content = ""
    
    -- Try to read the file content
    local file_path = file
    local file_content = {}
    local source_file = io.open(file_path, "r")
    if source_file then
      for line in source_file:lines() do
        table.insert(file_content, line)
      end
      source_file:close()
    end
    
    -- Get the lines that are covered (from original coverage data)
    local covered_lines = {}
    if coverage_data.files and coverage_data.files[file] and coverage_data.files[file].lines then
      covered_lines = coverage_data.files[file].lines
    end
    
    -- Simple Lua syntax highlighting function
    local function highlight_lua(line)
      -- Replace HTML special chars first
      line = line:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
      
      -- Keywords
      local keywords = {
        "and", "break", "do", "else", "elseif", "end", "false", "for", 
        "function", "if", "in", "local", "nil", "not", "or", "repeat", 
        "return", "then", "true", "until", "while"
      }
      
      for _, keyword in ipairs(keywords) do
        line = line:gsub("([^%w_])" .. keyword .. "([^%w_])", "%1<span class=\"keyword\">" .. keyword .. "</span>%2")
      end
      
      -- String literals
      line = line:gsub("(\".-[^\\]\")", "<span class=\"string\">%1</span>")
      line = line:gsub("('.-[^\\]')", "<span class=\"string\">%1</span>")
      
      -- Multi-line strings aren't properly handled in this simple highlighter
      
      -- Comments (only handles single-line comments)
      line = line:gsub("(%-%-.-$)", "<span class=\"comment\">%1</span>")
      
      -- Numbers
      line = line:gsub("([^%w_])(%d+%.?%d*)", "%1<span class=\"number\">%2</span>")
      
      -- Function calls
      line = line:gsub("([%w_]+)(%s*%b())", "<span class=\"function-name\">%1</span>%2")
      
      -- Table keys
      line = line:gsub("([%w_]+)(%s*=)", "<span class=\"table-key\">%1</span>%2")
      
      return line
    end
    
    -- Add the source container
    source_content = source_content .. [[
    <div id="source-]] .. fileId .. [[" class="source-container">
      <div class="source-header">Source: ]] .. file .. [[</div>
      <div class="source-code">
    ]]
    
    -- Add each line of code with highlighting
    for i, line in ipairs(file_content) do
      local is_covered = covered_lines[i] ~= nil
      local line_class = is_covered and "covered" or "not-covered"
      
      source_content = source_content .. [[
        <div class="source-line ]] .. line_class .. [[">
          <div class="source-line-number">]] .. i .. [[</div>
          <div class="source-line-content">]] .. highlight_lua(line) .. [[</div>
        </div>
      ]]
    end
    
    source_content = source_content .. [[
      </div>
    </div>
    ]]
    
    html = html .. source_content
  end
  
  -- Close HTML
  html = html .. [[
  </table>
</body>
</html>
  ]]
  
  return html
end

-- Generate an LCOV coverage report
coverage_formatters.lcov = function(coverage_data)
  local lcov = ""
  
  for file, data in pairs(coverage_data.files) do
    lcov = lcov .. "SF:" .. file .. "\n"
    
    -- Add function coverage
    local func_count = 0
    for func_name, covered in pairs(data.functions or {}) do
      func_count = func_count + 1
      -- If function name is a line number, use that
      if func_name:match("^line_(%d+)$") then
        local line = func_name:match("^line_(%d+)$")
        lcov = lcov .. "FN:" .. line .. "," .. func_name .. "\n"
      else
        -- We don't have line information for named functions in this simple implementation
        lcov = lcov .. "FN:1," .. func_name .. "\n"
      end
      lcov = lcov .. "FNDA:1," .. func_name .. "\n"
    end
    
    lcov = lcov .. "FNF:" .. func_count .. "\n"
    lcov = lcov .. "FNH:" .. func_count .. "\n"
    
    -- Add line coverage
    local lines_data = {}
    for line, covered in pairs(data.lines or {}) do
      if type(line) == "number" then
        table.insert(lines_data, line)
      end
    end
    table.sort(lines_data)
    
    for _, line in ipairs(lines_data) do
      lcov = lcov .. "DA:" .. line .. ",1\n"
    end
    
    -- Get line count, safely handling different data structures
    local line_count = data.line_count or data.total_lines or #lines_data or 0
    lcov = lcov .. "LF:" .. line_count .. "\n"
    lcov = lcov .. "LH:" .. #lines_data .. "\n"
    lcov = lcov .. "end_of_record\n"
  end
  
  return lcov
end

-- Test results formatters
local results_formatters = formatters.results

-- TAP (Test Anything Protocol) formatter
results_formatters.tap = function(results_data)
  -- Validate input
  if not results_data then
    print("ERROR [Reporting] Missing test results data")
    return "TAP version 13\n1..0\n# No test results provided"
  end

  local lines = {}
  
  -- Add TAP version header
  table.insert(lines, "TAP version 13")
  
  -- Handle multiple test suites if present
  local test_cases = {}
  if results_data.suites then
    -- Flatten multiple test suites into a single list for TAP output
    for _, suite in ipairs(results_data.suites) do
      for _, test_case in ipairs(suite.test_cases or {}) do
        -- Add suite information to the test case
        test_case.suite_name = suite.name
        table.insert(test_cases, test_case)
      end
    end
  else
    -- Single test suite format
    test_cases = results_data.test_cases or {}
  end
  
  -- Add TAP plan based on test count
  local total_tests = #test_cases
  table.insert(lines, "1.." .. total_tests)
  
  -- Process each test case
  for i, test_case in ipairs(test_cases) do
    local test_num = i
    local test_name = test_case.name or ""
    if test_case.suite_name then
      test_name = test_case.suite_name .. " - " .. test_name
    end
    local status = test_case.status or "unknown"
    
    -- Convert classname path to something more readable if provided
    if test_case.classname and test_case.classname ~= "Unknown" then
      test_name = test_case.classname .. ": " .. test_name
    end
    
    -- Determine TAP status line
    local status_line = ""
    if status == "pass" then
      status_line = "ok " .. test_num .. " - " .. test_name
    elseif status == "pending" or status == "skipped" then
      -- For skipped/pending tests, use SKIP directive
      local skip_message = test_case.skip_message or "Test not implemented"
      status_line = "ok " .. test_num .. " - " .. test_name .. " # SKIP " .. skip_message
    else
      -- For failed or error tests
      status_line = "not ok " .. test_num .. " - " .. test_name
    end
    
    table.insert(lines, status_line)
    
    -- Add YAML block with details for failed or error tests
    if status == "fail" or status == "error" then
      table.insert(lines, "  ---")
      
      if status == "fail" and test_case.failure then
        table.insert(lines, "  message: " .. (test_case.failure.message or "Test failed"))
        if test_case.failure.type then
          table.insert(lines, "  type: " .. test_case.failure.type)
        end
        if test_case.failure.details then
          local details = test_case.failure.details:gsub("\n", "\n  ")
          table.insert(lines, "  details: |\n    " .. details)
        end
      elseif status == "error" and test_case.error then
        table.insert(lines, "  message: " .. (test_case.error.message or "Test error"))
        if test_case.error.type then
          table.insert(lines, "  type: " .. test_case.error.type)
        end
        if test_case.error.details then
          local details = test_case.error.details:gsub("\n", "\n  ")
          table.insert(lines, "  details: |\n    " .. details)
        end
      end
      
      if test_case.time then
        table.insert(lines, "  duration: " .. test_case.time .. "s")
      end
      
      table.insert(lines, "  ...")
    end
  end
  
  return table.concat(lines, "\n")
end

-- CSV formatter
results_formatters.csv = function(results_data)
  -- Validate input
  if not results_data then
    print("ERROR [Reporting] Missing test results data")
    return "test_id,test_suite,test_name,status,duration,message,error_type,details,timestamp\n# No test results provided"
  end
  
  -- Helper function to escape and quote CSV values
  local function csv_escape(str)
    if str == nil then return '""' end
    -- Convert to string if not already
    str = tostring(str)
    -- Escape quotes by doubling them
    str = string.gsub(str, '"', '""')
    -- Remove newlines to maintain CSV integrity
    str = string.gsub(str, "[\r\n]+", " ")
    -- Return the quoted string
    return '"' .. str .. '"'
  end
  
  local lines = {}
  
  -- Add CSV header
  table.insert(lines, "test_id,test_suite,test_name,status,duration,message,error_type,details,timestamp")
  
  -- Create timestamp if not provided
  local timestamp = results_data.timestamp or os.date("!%Y-%m-%dT%H:%M:%S")
  
  -- Handle multiple test suites if present
  local test_cases = {}
  if results_data.suites then
    -- Process multiple test suites
    for _, suite in ipairs(results_data.suites) do
      for _, test_case in ipairs(suite.test_cases or {}) do
        -- Add suite information to the test case
        test_case.suite_name = suite.name
        test_case.suite_timestamp = suite.timestamp or timestamp
        table.insert(test_cases, test_case)
      end
    end
  else
    -- Single test suite format
    test_cases = results_data.test_cases or {}
    for _, test_case in ipairs(test_cases) do
      test_case.suite_name = results_data.name or "Test Suite"
      test_case.suite_timestamp = timestamp
    end
  end
  
  -- Process each test case
  for i, test_case in ipairs(test_cases) do
    local test_id = i
    local test_suite = csv_escape(test_case.suite_name)
    local test_name = csv_escape(test_case.name or "")
    local class_name = test_case.classname and csv_escape(test_case.classname) or '""'
    local status = csv_escape(test_case.status or "unknown")
    local duration = string.format("%.6f", test_case.time or 0)
    local message = '""'
    local error_type = '""'
    local details = '""'
    local case_timestamp = csv_escape(test_case.suite_timestamp)
    
    -- Get appropriate message, error type, and details based on test status
    if test_case.status == "fail" and test_case.failure then
      message = csv_escape(test_case.failure.message or "")
      error_type = csv_escape(test_case.failure.type or "")
      details = csv_escape(test_case.failure.details or "")
    elseif test_case.status == "error" and test_case.error then
      message = csv_escape(test_case.error.message or "")
      error_type = csv_escape(test_case.error.type or "")
      details = csv_escape(test_case.error.details or "")
    elseif (test_case.status == "skipped" or test_case.status == "pending") and test_case.skip_message then
      message = csv_escape(test_case.skip_message)
    end
    
    -- Construct the CSV row
    local row = {
      test_id,
      test_suite,
      test_name,
      status,
      duration,
      message,
      error_type,
      details,
      case_timestamp
    }
    
    -- Join and add the row
    table.insert(lines, table.concat(row, ","))
  end
  
  return table.concat(lines, "\n")
end

-- Generate JUnit XML for test results
results_formatters.junit = function(results_data)
  -- Validate input
  if not results_data then
    print("ERROR [Reporting] Missing test results data")
    return '<?xml version="1.0" encoding="UTF-8"?>\n<testsuites/>'
  end

  -- Create default timestamp if not provided
  local timestamp = results_data.timestamp or os.date("!%Y-%m-%dT%H:%M:%S")
  
  -- Create XML
  local xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
  
  -- Add single testsuite if suite is flat, or multiple testsuites if nested
  if results_data.suites then
    -- Multiple test suites format
    xml = xml .. '<testsuites>\n'
    
    for _, suite in ipairs(results_data.suites) do
      xml = xml .. '  <testsuite'
      xml = xml .. ' name="' .. escape_xml(suite.name or "Unknown") .. '"'
      xml = xml .. ' tests="' .. (suite.tests or 0) .. '"'
      xml = xml .. ' failures="' .. (suite.failures or 0) .. '"'
      xml = xml .. ' errors="' .. (suite.errors or 0) .. '"'
      xml = xml .. ' skipped="' .. (suite.skipped or 0) .. '"'
      xml = xml .. ' time="' .. string.format("%.3f", suite.time or 0) .. '"'
      xml = xml .. ' timestamp="' .. escape_xml(suite.timestamp or timestamp) .. '"'
      xml = xml .. '>\n'
      
      -- Add test cases
      for _, test_case in ipairs(suite.test_cases or {}) do
        xml = xml .. '    <testcase'
        xml = xml .. ' name="' .. escape_xml(test_case.name or "Unknown") .. '"'
        xml = xml .. ' classname="' .. escape_xml(test_case.classname or "Unknown") .. '"'
        xml = xml .. ' time="' .. string.format("%.3f", test_case.time or 0) .. '"'
        xml = xml .. '>\n'
        
        -- Add failure info if present
        if test_case.status == "fail" and test_case.failure then
          xml = xml .. '      <failure'
          if test_case.failure.message then
            xml = xml .. ' message="' .. escape_xml(test_case.failure.message) .. '"'
          end
          if test_case.failure.type then
            xml = xml .. ' type="' .. escape_xml(test_case.failure.type) .. '"'
          end
          xml = xml .. '>'
          if test_case.failure.details then
            xml = xml .. escape_xml(test_case.failure.details)
          end
          xml = xml .. '</failure>\n'
        end
        
        -- Add error info if present
        if test_case.status == "error" and test_case.error then
          xml = xml .. '      <error'
          if test_case.error.message then
            xml = xml .. ' message="' .. escape_xml(test_case.error.message) .. '"'
          end
          if test_case.error.type then
            xml = xml .. ' type="' .. escape_xml(test_case.error.type) .. '"'
          end
          xml = xml .. '>'
          if test_case.error.details then
            xml = xml .. escape_xml(test_case.error.details)
          end
          xml = xml .. '</error>\n'
        end
        
        -- Add skipped info if present
        if test_case.status == "skipped" or test_case.status == "pending" then
          xml = xml .. '      <skipped'
          if test_case.skip_message then
            xml = xml .. ' message="' .. escape_xml(test_case.skip_message) .. '"'
          end
          xml = xml .. '/>\n'
        end
        
        xml = xml .. '    </testcase>\n'
      end
      
      xml = xml .. '  </testsuite>\n'
    end
    
    xml = xml .. '</testsuites>'
  else
    -- Single test suite format
    xml = xml .. '<testsuite'
    xml = xml .. ' name="' .. escape_xml(results_data.name or "TestSuite") .. '"'
    xml = xml .. ' tests="' .. (results_data.tests or 0) .. '"'
    xml = xml .. ' failures="' .. (results_data.failures or 0) .. '"'
    xml = xml .. ' errors="' .. (results_data.errors or 0) .. '"'
    xml = xml .. ' skipped="' .. (results_data.skipped or 0) .. '"'
    xml = xml .. ' time="' .. string.format("%.3f", results_data.time or 0) .. '"'
    xml = xml .. ' timestamp="' .. escape_xml(timestamp) .. '"'
    xml = xml .. '>\n'
    
    -- Add properties if present
    if results_data.properties and next(results_data.properties) then
      xml = xml .. '  <properties>\n'
      for name, value in pairs(results_data.properties) do
        xml = xml .. '    <property name="' .. escape_xml(name) .. '" value="' .. escape_xml(value) .. '"/>\n'
      end
      xml = xml .. '  </properties>\n'
    end
    
    -- Add test cases
    for _, test_case in ipairs(results_data.test_cases or {}) do
      xml = xml .. '  <testcase'
      xml = xml .. ' name="' .. escape_xml(test_case.name or "Unknown") .. '"'
      xml = xml .. ' classname="' .. escape_xml(test_case.classname or "Unknown") .. '"'
      xml = xml .. ' time="' .. string.format("%.3f", test_case.time or 0) .. '"'
      xml = xml .. '>\n'
      
      -- Add failure info if present
      if test_case.status == "fail" and test_case.failure then
        xml = xml .. '    <failure'
        if test_case.failure.message then
          xml = xml .. ' message="' .. escape_xml(test_case.failure.message) .. '"'
        end
        if test_case.failure.type then
          xml = xml .. ' type="' .. escape_xml(test_case.failure.type) .. '"'
        end
        xml = xml .. '>'
        if test_case.failure.details then
          xml = xml .. escape_xml(test_case.failure.details)
        end
        xml = xml .. '</failure>\n'
      end
      
      -- Add error info if present
      if test_case.status == "error" and test_case.error then
        xml = xml .. '    <error'
        if test_case.error.message then
          xml = xml .. ' message="' .. escape_xml(test_case.error.message) .. '"'
        end
        if test_case.error.type then
          xml = xml .. ' type="' .. escape_xml(test_case.error.type) .. '"'
        end
        xml = xml .. '>'
        if test_case.error.details then
          xml = xml .. escape_xml(test_case.error.details)
        end
        xml = xml .. '</error>\n'
      end
      
      -- Add skipped info if present
      if test_case.status == "skipped" or test_case.status == "pending" then
        xml = xml .. '    <skipped'
        if test_case.skip_message then
          xml = xml .. ' message="' .. escape_xml(test_case.skip_message) .. '"'
        end
        xml = xml .. '/>\n'
      end
      
      -- Add system output if present (stdout/stderr)
      if test_case.stdout and #test_case.stdout > 0 then
        xml = xml .. '    <system-out>' .. escape_xml(test_case.stdout) .. '</system-out>\n'
      end
      
      if test_case.stderr and #test_case.stderr > 0 then
        xml = xml .. '    <system-err>' .. escape_xml(test_case.stderr) .. '</system-err>\n'
      end
      
      xml = xml .. '  </testcase>\n'
    end
    
    xml = xml .. '</testsuite>'
  end
  
  return xml
end

-- Quality report formatters
local quality_formatters = formatters.quality

-- Generate a summary quality report
quality_formatters.summary = function(quality_data)
  -- Simply return the structured data for summary reports
  return {
    level = quality_data.level,
    level_name = quality_data.level_name,
    tests_analyzed = quality_data.summary.tests_analyzed,
    tests_passing_quality = quality_data.summary.tests_passing_quality,
    quality_pct = quality_data.summary.quality_percent,
    assertions_total = quality_data.summary.assertions_total,
    assertions_per_test_avg = quality_data.summary.assertions_per_test_avg,
    assertion_types_found = quality_data.summary.assertion_types_found or {},
    issues = quality_data.summary.issues or {},
    tests = quality_data.tests or {}
  }
end

-- Generate a JSON quality report
quality_formatters.json = function(quality_data)
  local report = quality_formatters.summary(quality_data)
  return json_module.encode(report)
end

-- Generate an HTML quality report
quality_formatters.html = function(quality_data)
  local report = quality_formatters.summary(quality_data)
  
  -- Generate HTML header
  local html = [[
<\!DOCTYPE html>
<html>
<head>
  <title>Lust-Next Test Quality Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    .summary { margin: 20px 0; background: #f5f5f5; padding: 10px; border-radius: 5px; }
    .progress { background-color: #e0e0e0; border-radius: 5px; height: 20px; }
    .progress-bar { height: 20px; border-radius: 5px; background-color: #4CAF50; }
    .low { background-color: #f44336; }
    .medium { background-color: #ff9800; }
    .high { background-color: #4CAF50; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    .issue { color: #f44336; }
  </style>
</head>
<body>
  <h1>Lust-Next Test Quality Report</h1>
  <div class="summary">
    <h2>Quality Summary</h2>
    <p>Quality Level: ]].. report.level_name .. " (Level " .. report.level .. [[ of 5)</p>
    <div class="progress">
      <div class="progress-bar ]].. (report.quality_pct < 50 and "low" or (report.quality_pct < 80 and "medium" or "high")) ..[[" style="width: ]].. math.min(100, report.quality_pct) ..[[%;"></div>
    </div>
    <p>Tests Passing Quality: ]].. report.tests_passing_quality ..[[ / ]].. report.tests_analyzed ..[[ (]].. string.format("%.2f%%", report.quality_pct) ..[[)</p>
    <p>Average Assertions per Test: ]].. string.format("%.2f", report.assertions_per_test_avg) ..[[</p>
  </div>
  ]]
  
  -- Add issues if any
  if #report.issues > 0 then
    html = html .. [[
  <h2>Quality Issues</h2>
  <table>
    <tr>
      <th>Test</th>
      <th>Issue</th>
    </tr>
  ]]
    
    for _, issue in ipairs(report.issues) do
      html = html .. [[
    <tr>
      <td>]].. issue.test ..[[</td>
      <td class="issue">]].. issue.issue ..[[</td>
    </tr>
  ]]
    end
    
    html = html .. [[
  </table>
  ]]
  end
  
  -- Add test details
  html = html .. [[
  <h2>Test Details</h2>
  <table>
    <tr>
      <th>Test</th>
      <th>Quality Level</th>
      <th>Assertions</th>
      <th>Assertion Types</th>
    </tr>
  ]]
  
  for test_name, test_info in pairs(report.tests) do
    -- Convert assertion types to a string
    local assertion_types = {}
    for atype, count in pairs(test_info.assertion_types or {}) do
      table.insert(assertion_types, atype .. " (" .. count .. ")")
    end
    local assertion_types_str = table.concat(assertion_types, ", ")
    
    html = html .. [[
    <tr>
      <td>]].. test_name ..[[</td>
      <td>]].. (test_info.quality_level_name or "") .. " (Level " .. (test_info.quality_level or 0) .. [[)</td>
      <td>]].. (test_info.assertion_count or 0) ..[[</td>
      <td>]].. assertion_types_str ..[[</td>
    </tr>
    ]]
  end
  
  html = html .. [[
  </table>
</body>
</html>
  ]]
  
  return html
end

---------------------------
-- CUSTOM FORMATTER REGISTRATION
---------------------------

-- Register a custom coverage report formatter
function M.register_coverage_formatter(name, formatter_fn)
  if type(name) ~= "string" then
    error("Formatter name must be a string")
  end
  
  if type(formatter_fn) ~= "function" then
    error("Formatter must be a function")
  end
  
  -- Register the formatter
  formatters.coverage[name] = formatter_fn
  
  return true
end

-- Register a custom quality report formatter
function M.register_quality_formatter(name, formatter_fn)
  if type(name) ~= "string" then
    error("Formatter name must be a string")
  end
  
  if type(formatter_fn) ~= "function" then
    error("Formatter must be a function")
  end
  
  -- Register the formatter
  formatters.quality[name] = formatter_fn
  
  return true
end

-- Register a custom test results formatter
function M.register_results_formatter(name, formatter_fn)
  if type(name) ~= "string" then
    error("Formatter name must be a string")
  end
  
  if type(formatter_fn) ~= "function" then
    error("Formatter must be a function")
  end
  
  -- Register the formatter
  formatters.results[name] = formatter_fn
  
  return true
end

-- Load formatters from a module (table with format functions)
function M.load_formatters(formatter_module)
  if type(formatter_module) ~= "table" then
    error("Formatter module must be a table")
  end
  
  local registered = 0
  
  -- Register coverage formatters
  if type(formatter_module.coverage) == "table" then
    for name, fn in pairs(formatter_module.coverage) do
      if type(fn) == "function" then
        M.register_coverage_formatter(name, fn)
        registered = registered + 1
      end
    end
  end
  
  -- Register quality formatters
  if type(formatter_module.quality) == "table" then
    for name, fn in pairs(formatter_module.quality) do
      if type(fn) == "function" then
        M.register_quality_formatter(name, fn)
        registered = registered + 1
      end
    end
  end
  
  -- Register test results formatters
  if type(formatter_module.results) == "table" then
    for name, fn in pairs(formatter_module.results) do
      if type(fn) == "function" then
        M.register_results_formatter(name, fn)
        registered = registered + 1
      end
    end
  end
  
  return registered
end

-- Get list of available formatters for each type
function M.get_available_formatters()
  local available = {
    coverage = {},
    quality = {},
    results = {}
  }
  
  -- Collect formatter names
  for name, _ in pairs(formatters.coverage) do
    table.insert(available.coverage, name)
  end
  
  for name, _ in pairs(formatters.quality) do
    table.insert(available.quality, name)
  end
  
  for name, _ in pairs(formatters.results) do
    table.insert(available.results, name)
  end
  
  -- Sort for consistent results
  table.sort(available.coverage)
  table.sort(available.quality)
  table.sort(available.results)
  
  return available
end

---------------------------
-- FORMAT OUTPUT FUNCTIONS
---------------------------

-- Format coverage data
function M.format_coverage(coverage_data, format)
  format = format or "summary"
  
  -- Use the appropriate formatter
  if formatters.coverage[format] then
    return formatters.coverage[format](coverage_data)
  else
    -- Default to summary if format not supported
    return formatters.coverage.summary(coverage_data)
  end
end

-- Format quality data
function M.format_quality(quality_data, format)
  format = format or "summary"
  
  -- Use the appropriate formatter
  if formatters.quality[format] then
    return formatters.quality[format](quality_data)
  else
    -- Default to summary if format not supported
    return formatters.quality.summary(quality_data)
  end
end

-- Format test results data
function M.format_results(results_data, format)
  format = format or "junit"
  
  -- Use the appropriate formatter
  if formatters.results[format] then
    return formatters.results[format](results_data)
  else
    -- Default to JUnit if format not supported
    return formatters.results.junit(results_data)
  end
end

---------------------------
-- FILE I/O FUNCTIONS
---------------------------

-- Utility function to create directory if it doesn't exist
local function ensure_directory(dir_path)
  -- Extract directory part (trying different approaches for reliability)
  if type(dir_path) ~= "string" then 
    print("ERROR [Reporting] Invalid directory path: " .. tostring(dir_path))
    return false, "Invalid directory path" 
  end
  
  -- Skip if it's just a filename with no directory component
  if not dir_path:match("[/\\]") then 
    print("DEBUG [Reporting] No directory component in path: " .. dir_path)
    return true 
  end
  
  local last_separator = dir_path:match("^(.*)[\\/][^\\/]*$")
  if not last_separator then 
    print("DEBUG [Reporting] No directory part found in: " .. dir_path)
    return true 
  end
  
  print("DEBUG [Reporting] Extracted directory part: " .. last_separator)
  
  -- Check if directory already exists
  local test_cmd = package.config:sub(1,1) == "\\" and
    "if exist \"" .. last_separator .. "\\*\" (exit 0) else (exit 1)" or
    "test -d \"" .. last_separator .. "\""
  
  local dir_exists = os.execute(test_cmd)
  if dir_exists == true or dir_exists == 0 then
    print("DEBUG [Reporting] Directory already exists: " .. last_separator)
    return true
  end
  
  -- Create the directory
  print("DEBUG [Reporting] Creating directory: " .. last_separator)
  
  -- Use platform appropriate command
  local command = package.config:sub(1,1) == "\\" and
    "mkdir \"" .. last_separator .. "\"" or
    "mkdir -p \"" .. last_separator .. "\""
  
  print("DEBUG [Reporting] Running mkdir command: " .. command)
  local result = os.execute(command)
  
  -- Check result
  local success = (result == true or result == 0 or result == 1)
  if success then
    print("DEBUG [Reporting] Successfully created directory: " .. last_separator)
  else
    print("ERROR [Reporting] Failed to create directory: " .. last_separator .. " (result: " .. tostring(result) .. ")")
  end
  
  return success, success and nil or "Failed to create directory: " .. last_separator
end

-- Write content to a file
function M.write_file(file_path, content)
  print("DEBUG [Reporting] Writing file: " .. file_path)
  print("DEBUG [Reporting] Content length: " .. (content and #content or 0) .. " bytes")
  
  -- Create directory if needed
  print("DEBUG [Reporting] Ensuring directory exists...")
  local dir_ok, dir_err = ensure_directory(file_path)
  if not dir_ok then
    print("ERROR [Reporting] Failed to create directory: " .. tostring(dir_err))
    -- Try direct mkdir as fallback
    local dir_path = file_path:match("^(.*)[\\/][^\\/]*$")
    if dir_path then
      print("DEBUG [Reporting] Attempting direct mkdir -p: " .. dir_path)
      os.execute("mkdir -p \"" .. dir_path .. "\"")
    end
  end
  
  -- Open the file for writing
  print("DEBUG [Reporting] Opening file for writing...")
  local file, err = io.open(file_path, "w")
  if not file then
    print("ERROR [Reporting] Could not open file for writing: " .. tostring(err))
    return false, "Could not open file for writing: " .. tostring(err)
  end
  
  -- Write content and close
  print("DEBUG [Reporting] Writing content...")
  local write_ok, write_err = pcall(function()
    file:write(content)
    file:close()
  end)
  
  if not write_ok then
    print("ERROR [Reporting] Error writing to file: " .. tostring(write_err))
    return false, "Error writing to file: " .. tostring(write_err)
  end
  
  print("DEBUG [Reporting] Successfully wrote file: " .. file_path)
  return true
end

-- Save a coverage report to file
function M.save_coverage_report(file_path, coverage_data, format)
  format = format or "html"
  
  -- Format the coverage data
  local content = M.format_coverage(coverage_data, format)
  
  -- Write to file
  return M.write_file(file_path, content)
end

-- Save a quality report to file
function M.save_quality_report(file_path, quality_data, format)
  format = format or "html"
  
  -- Format the quality data
  local content = M.format_quality(quality_data, format)
  
  -- Write to file
  return M.write_file(file_path, content)
end

-- Save a test results report to file
function M.save_results_report(file_path, results_data, format)
  format = format or "junit"
  
  -- Format the test results data
  local content = M.format_results(results_data, format)
  
  -- Write to file
  return M.write_file(file_path, content)
end

-- Auto-save reports to configured locations
-- Options can be:
-- - string: base directory (backward compatibility)
-- - table: configuration with properties:
--   * report_dir: base directory for reports (default: "./coverage-reports")
--   * report_suffix: suffix to add to all report filenames (optional)
--   * coverage_path_template: path template for coverage reports (optional)
--   * quality_path_template: path template for quality reports (optional)
--   * results_path_template: path template for test results reports (optional)
--   * timestamp_format: format string for timestamps in templates (default: "%Y-%m-%d")
--   * verbose: enable verbose logging (default: false)
function M.auto_save_reports(coverage_data, quality_data, results_data, options)
  -- Handle both string (backward compatibility) and table options
  local config = {}
  
  if type(options) == "string" then
    config.report_dir = options
  elseif type(options) == "table" then
    config = options
  end
  
  -- Set defaults for missing values
  config.report_dir = config.report_dir or "./coverage-reports"
  config.report_suffix = config.report_suffix or ""
  config.timestamp_format = config.timestamp_format or "%Y-%m-%d"
  config.verbose = config.verbose or false
  
  local base_dir = config.report_dir
  local results = {}
  
  -- Helper function for path templates
  local function process_template(template, format, type)
    -- If no template provided, use default filename pattern
    if not template then
      return base_dir .. "/" .. type .. "-report" .. config.report_suffix .. "." .. format
    end
    
    -- Get current timestamp
    local timestamp = os.date(config.timestamp_format)
    local datetime = os.date("%Y-%m-%d_%H-%M-%S")
    
    -- Replace placeholders in template
    local path = template:gsub("{format}", format)
                          :gsub("{type}", type)
                          :gsub("{date}", timestamp)
                          :gsub("{datetime}", datetime)
                          :gsub("{suffix}", config.report_suffix)
    
    -- If path doesn't start with / or X:\ (absolute), prepend base_dir
    if not path:match("^[/\\]") and not path:match("^%a:[/\\]") then
      path = base_dir .. "/" .. path
    end
    
    -- If path doesn't have an extension and format is provided, add extension
    if format and not path:match("%.%w+$") then
      path = path .. "." .. format
    end
    
    return path
  end
  
  -- Debug output for troubleshooting
  if config.verbose then
    print("DEBUG [Reporting] auto_save_reports called with:")
    print("  base_dir: " .. base_dir)
    print("  coverage_data: " .. (coverage_data and "present" or "nil"))
    if coverage_data then
      print("    total_files: " .. (coverage_data.summary and coverage_data.summary.total_files or "unknown"))
      print("    total_lines: " .. (coverage_data.summary and coverage_data.summary.total_lines or "unknown"))
      
      -- Print file count to help diagnose data flow issues
      local file_count = 0
      if coverage_data.files then
        for file, _ in pairs(coverage_data.files) do
          file_count = file_count + 1
          if file_count <= 5 then -- Just print first 5 files for brevity
            print("    - File: " .. file)
          end
        end
        print("    Total files tracked: " .. file_count)
      else
        print("    No files tracked in coverage data")
      end
    end
    print("  quality_data: " .. (quality_data and "present" or "nil"))
    if quality_data then
      print("    tests_analyzed: " .. (quality_data.summary and quality_data.summary.tests_analyzed or "unknown"))
    end
    print("  results_data: " .. (results_data and "present" or "nil"))
    if results_data then
      print("    tests: " .. (results_data.tests or "unknown"))
      print("    failures: " .. (results_data.failures or "unknown"))
    end
  end
  
  -- Try different directory creation methods to ensure success
  if config.verbose then
    print("DEBUG [Reporting] Ensuring directory exists using multiple methods...")
  end
  
  -- First, try the standard ensure_directory function
  local dir_ok, dir_err = ensure_directory(base_dir)
  if not dir_ok then
    if config.verbose then
      print("WARNING [Reporting] Standard directory creation failed: " .. tostring(dir_err))
      print("DEBUG [Reporting] Trying direct mkdir -p command...")
    end
    
    -- Try direct mkdir command as fallback
    os.execute('mkdir -p "' .. base_dir .. '"')
    
    -- Verify directory exists after fallback
    local test_cmd = package.config:sub(1,1) == "\\" and
      'if exist "' .. base_dir .. '\\*" (exit 0) else (exit 1)' or
      'test -d "' .. base_dir .. '"'
    
    local exists = os.execute(test_cmd)
    if exists == true or exists == 0 then
      if config.verbose then
        print("DEBUG [Reporting] Directory created successfully with fallback method")
      end
      dir_ok = true
    else
      if config.verbose then
        print("ERROR [Reporting] Failed to create directory with all methods")
      end
      dir_ok = false
    end
  elseif config.verbose then
    print("DEBUG [Reporting] Directory exists or was created: " .. base_dir)
  end
  
  -- Always save both HTML and LCOV reports if coverage data is provided
  if coverage_data then
    -- Save reports in multiple formats
    local formats = {"html", "json", "lcov"}
    
    for _, format in ipairs(formats) do
      local path = process_template(config.coverage_path_template, format, "coverage")
      
      if config.verbose then
        print("DEBUG [Reporting] Saving " .. format .. " report to: " .. path)
      end
      
      local ok, err = M.save_coverage_report(path, coverage_data, format)
      results[format] = {
        success = ok,
        error = err,
        path = path
      }
      
      if config.verbose then
        print("DEBUG [Reporting] " .. format .. " save result: " .. (ok and "success" or "failed: " .. tostring(err)))
      end
    end
  end
  
  -- Save quality reports if quality data is provided
  if quality_data then
    -- Save reports in multiple formats
    local formats = {"html", "json"}
    
    for _, format in ipairs(formats) do
      local path = process_template(config.quality_path_template, format, "quality")
      
      if config.verbose then
        print("DEBUG [Reporting] Saving quality " .. format .. " report to: " .. path)
      end
      
      local ok, err = M.save_quality_report(path, quality_data, format)
      results["quality_" .. format] = {
        success = ok,
        error = err,
        path = path
      }
      
      if config.verbose then
        print("DEBUG [Reporting] Quality " .. format .. " save result: " .. (ok and "success" or "failed: " .. tostring(err)))
      end
    end
  end
  
  -- Save test results in multiple formats if results data is provided
  if results_data then
    -- Test results formats
    local formats = {
      junit = { ext = "xml", name = "JUnit XML" },
      tap = { ext = "tap", name = "TAP" },
      csv = { ext = "csv", name = "CSV" }
    }
    
    for format, info in pairs(formats) do
      local path = process_template(config.results_path_template, info.ext, "test-results")
      
      if config.verbose then
        print("DEBUG [Reporting] Saving " .. info.name .. " report to: " .. path)
      end
      
      local ok, err = M.save_results_report(path, results_data, format)
      results[format] = {
        success = ok,
        error = err,
        path = path
      }
      
      if config.verbose then
        print("DEBUG [Reporting] " .. info.name .. " save result: " .. (ok and "success" or "failed: " .. tostring(err)))
      end
    end
  end
  
  return results
end

-- Return the module
return M
