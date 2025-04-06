---@class HTMLSimpleFormatter
---@field generate fun(coverage_data: table, output_path: string): boolean, string|nil
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

-- Version
M._VERSION = "1.0.0"

-- HTML escaping
local function escape_html(text)
  if not text then return "" end
  return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

-- Get a color class based on coverage percentage
local function get_coverage_class(percent)
  if percent >= 80 then
    return "high"
  elseif percent >= 50 then
    return "medium"
  else
    return "low"
  end
end

-- Format a percentage for display
local function format_percent(percent)
  if not percent or type(percent) ~= "number" then
    return "0%"
  end
  
  -- Round to nearest whole number
  percent = math.floor(percent + 0.5)
  
  -- Return as string with % sign
  return tostring(percent) .. "%"
end

-- Simple CSS styling for the report
local SIMPLE_CSS = [[
body { 
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.6;
  color: #333;
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
  background-color: #f5f5f5;
}

h1, h2, h3 { margin-top: 0; }

.card {
  background: white;
  border-radius: 4px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.1);
  padding: 20px;
  margin-bottom: 20px;
}

.summary-stats {
  display: flex;
  flex-wrap: wrap;
  gap: 15px;
  margin-bottom: 20px;
}

.stat-box {
  background-color: #f9f9f9;
  border: 1px solid #e1e1e1;
  border-radius: 4px;
  padding: 15px;
  flex: 1;
  min-width: 200px;
}

.stat-label {
  font-size: 14px;
  color: #666;
  margin-bottom: 5px;
}

.stat-value {
  font-size: 24px;
  font-weight: bold;
}

.high { color: #4caf50; }
.medium { color: #ff9800; }
.low { color: #f44336; }

.progress-bar {
  height: 10px;
  background-color: #e0e0e0;
  border-radius: 5px;
  overflow: hidden;
  margin-top: 10px;
}

.progress-value {
  height: 100%;
}

.progress-value.high { background-color: #4caf50; }
.progress-value.medium { background-color: #ff9800; }
.progress-value.low { background-color: #f44336; }

table {
  border-collapse: collapse;
  width: 100%;
  margin: 20px 0;
}

th, td {
  text-align: left;
  padding: 10px;
  border-bottom: 1px solid #ddd;
}

th {
  background-color: #f2f2f2;
  font-weight: 600;
}

tr:hover {
  background-color: #f9f9f9;
}

/* Coverage status classes */
.covered { background-color: #a5d6a7; }     /* Green - much more visible */
.executed { background-color: #ffcc80; }     /* Orange - much more visible */
.not-covered { background-color: #ef9a9a; }  /* Red - much more visible */
.not-executable { color: #777; }

.code-table {
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
  font-size: 13px;
  margin: 0;
  width: 100%;
}

.line-number {
  width: 40px;
  text-align: right;
  padding: 0 10px;
  user-select: none;
  color: #999;
  background-color: #f9f9f9;
  border-right: 1px solid #e1e1e1;
}

.exec-count {
  width: 30px;
  text-align: right;
  padding: 0 8px;
  color: #666;
  border-right: 1px solid #e1e1e1;
}

.code-content {
  padding: 0 5px 0 10px;
  white-space: pre;
}

footer {
  text-align: center;
  padding: 20px;
  color: #666;
  font-size: 12px;
}
]]

-- Generate file list for the report
local function generate_file_list_html(coverage_data)
  local html = "<table>"
  html = html .. "<tr><th>File Path</th><th>Line Coverage</th><th>Function Coverage</th><th>Lines</th></tr>"
  
  -- Get all file paths and sort them
  local file_paths = {}
  for path, _ in pairs(coverage_data.files) do
    table.insert(file_paths, path)
  end
  table.sort(file_paths)
  
  -- Add each file to the table
  for _, path in ipairs(file_paths) do
    local file_data = coverage_data.files[path]
    
    local line_coverage_percent = 0
    if file_data.executable_lines > 0 then
      line_coverage_percent = (file_data.covered_lines / file_data.executable_lines) * 100
    end
    
    local function_coverage_percent = 0
    if file_data.total_functions > 0 then
      function_coverage_percent = (file_data.executed_functions / file_data.total_functions) * 100
    end
    
    local line_class = get_coverage_class(line_coverage_percent)
    local function_class = get_coverage_class(function_coverage_percent)
    
    html = html .. "<tr>"
    html = html .. "<td>" .. escape_html(path) .. "</td>"
    html = html .. "<td class='" .. line_class .. "'>" 
      .. format_percent(line_coverage_percent) 
      .. " (" .. file_data.covered_lines .. "/" .. file_data.executable_lines .. ")</td>"
    html = html .. "<td class='" .. function_class .. "'>" 
      .. format_percent(function_coverage_percent) 
      .. " (" .. file_data.executed_functions .. "/" .. file_data.total_functions .. ")</td>"
    html = html .. "<td>" .. file_data.total_lines .. "</td>"
    html = html .. "</tr>"
  end
  
  html = html .. "</table>"
  return html
end

-- Generate source view for a file - limited to one key file
local function generate_source_view(file_data, file_path)
  if not file_data then return "" end
  
  local html = "<div class='card'>"
  html = html .. "<h3>File: " .. escape_html(file_path) .. "</h3>"
  
  -- File stats
  html = html .. "<div>"
  html = html .. "<strong>Line Coverage: </strong>"
  html = html .. "<span class='" .. get_coverage_class(file_data.line_coverage_percent) .. "'>"
  html = html .. format_percent(file_data.line_coverage_percent) 
  html = html .. " (" .. file_data.covered_lines .. "/" .. file_data.executable_lines .. ")</span>"
  html = html .. "</div>"
  
  -- Source code
  html = html .. "<div style='overflow-x: auto;'>"
  html = html .. "<table class='code-table'>"
  
  -- Get all line numbers and sort them
  local line_numbers = {}
  for line_num, _ in pairs(file_data.lines) do
    table.insert(line_numbers, line_num)
  end
  table.sort(line_numbers)
  
  -- Add each line
  for _, line_num in ipairs(line_numbers) do
    local line_data = file_data.lines[line_num]
    local line_content = line_data.content or ""
    local line_class = ""
    local exec_count = ""
    
    if line_data.executable then
      exec_count = tostring(line_data.execution_count)
      if line_data.execution_count > 0 then
        -- Apply three-state visualization
        if line_data.covered then
          line_class = "covered"  -- Green - tested and verified
        else
          line_class = "executed" -- Orange - executed but not verified
        end
      else
        line_class = "not-covered"
      end
    elseif line_data.line_type == "comment" or line_data.line_type == "blank" then
      line_class = "not-executable"
    end
    
    html = html .. "<tr class='" .. line_class .. "'>"
    html = html .. "<td class='line-number'>" .. line_num .. "</td>"
    html = html .. "<td class='exec-count'>" .. exec_count .. "</td>"
    html = html .. "<td class='code-content'>" .. escape_html(line_content) .. "</td>"
    html = html .. "</tr>"
  end
  
  html = html .. "</table>"
  html = html .. "</div>"
  html = html .. "</div>"
  
  return html
end

-- Generate statistics section with coverage metrics
local function generate_statistics_section(coverage_data)
  local summary = coverage_data.summary
  
  local html = "<div class='summary-stats'>"
  
  -- Line Coverage Stat
  html = html .. "<div class='stat-box'>"
  html = html .. "<div class='stat-label'>Line Coverage</div>"
  html = html .. "<div class='stat-value " .. get_coverage_class(summary.line_coverage_percent) .. "'>"
  html = html .. format_percent(summary.line_coverage_percent) .. "</div>"
  html = html .. "<div class='progress-bar'>"
  html = html .. "<div class='progress-value " .. get_coverage_class(summary.line_coverage_percent) .. "' "
  html = html .. "style='width: " .. math.min(100, summary.line_coverage_percent) .. "%;'></div>"
  html = html .. "</div>"
  html = html .. "<div style='font-size: 12px; margin-top: 5px;'>"
  html = html .. summary.covered_lines .. " of " .. summary.executable_lines .. " lines"
  html = html .. "</div>"
  html = html .. "</div>"
  
  -- Function Coverage Stat
  html = html .. "<div class='stat-box'>"
  html = html .. "<div class='stat-label'>Function Coverage</div>"
  html = html .. "<div class='stat-value " .. get_coverage_class(summary.function_coverage_percent) .. "'>"
  html = html .. format_percent(summary.function_coverage_percent) .. "</div>"
  html = html .. "<div class='progress-bar'>"
  html = html .. "<div class='progress-value " .. get_coverage_class(summary.function_coverage_percent) .. "' "
  html = html .. "style='width: " .. math.min(100, summary.function_coverage_percent) .. "%;'></div>"
  html = html .. "</div>"
  html = html .. "<div style='font-size: 12px; margin-top: 5px;'>"
  html = html .. summary.covered_functions .. " of " .. summary.total_functions .. " functions"
  html = html .. "</div>"
  html = html .. "</div>"
  
  -- File Coverage Stat
  html = html .. "<div class='stat-box'>"
  html = html .. "<div class='stat-label'>File Coverage</div>"
  html = html .. "<div class='stat-value " .. get_coverage_class(summary.file_coverage_percent) .. "'>"
  html = html .. format_percent(summary.file_coverage_percent) .. "</div>"
  html = html .. "<div class='progress-bar'>"
  html = html .. "<div class='progress-value " .. get_coverage_class(summary.file_coverage_percent) .. "' "
  html = html .. "style='width: " .. math.min(100, summary.file_coverage_percent) .. "%;'></div>"
  html = html .. "</div>"
  html = html .. "<div style='font-size: 12px; margin-top: 5px;'>"
  html = html .. summary.covered_files .. " of " .. summary.total_files .. " files"
  html = html .. "</div>"
  html = html .. "</div>"
  
  html = html .. "</div>"
  return html
end

-- Generate the complete HTML report
local function format_coverage_simple(coverage_data)
  -- Find a file to display in detail
  local display_file_data = nil
  local display_file_path = nil
  
  -- Simple file selection - take the first one that's calculator.lua
  for path, file_data in pairs(coverage_data.files) do
    if path:match("calculator%.lua$") then
      display_file_data = file_data
      display_file_path = path
      break
    end
  end
  
  -- If no calculator file found, just use the first file
  if not display_file_data then
    for path, file_data in pairs(coverage_data.files) do
      display_file_data = file_data
      display_file_path = path
      break
    end
  end
  
  local html = [[<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Coverage Report</title>
  <style>
]] .. SIMPLE_CSS .. [[
  </style>
</head>
<body>
  <div class="card">
    <h1>Coverage Report</h1>
    <p>Generated on ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[</p>
    
    ]] .. generate_statistics_section(coverage_data) .. [[
  </div>
  
  <div class="card">
    <h2>Legend</h2>
    <ul>
      <li><span style="display:inline-block; background-color:rgba(76,175,80,0.15); width:20px; height:12px;"></span> <strong>Covered Line:</strong> Line was executed and verified by test assertions</li>
      <li><span style="display:inline-block; background-color:rgba(255,152,0,0.15); width:20px; height:12px;"></span> <strong>Executed Line:</strong> Line was executed but not explicitly verified</li>
      <li><span style="display:inline-block; background-color:rgba(244,67,54,0.15); width:20px; height:12px;"></span> <strong>Not Covered Line:</strong> Line was not executed</li>
    </ul>
  </div>
  
  <div class="card">
    <h2>Files</h2>
    ]] .. generate_file_list_html(coverage_data) .. [[
  </div>
  
  ]] .. (display_file_data and generate_source_view(display_file_data, display_file_path) or "") .. [[
  
  <footer>
    Generated by Firmo Coverage Simple v]] .. M._VERSION .. [[
  </footer>
</body>
</html>]]

  return html
end

-- Generate HTML report with simplified approach
function M.generate(coverage_data, output_path)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(output_path) == "string", "output_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- If output_path is a directory, add a filename
  if output_path:sub(-1) == "/" then
    output_path = output_path .. "coverage-report-simple.html"
  end
  
  -- Try to ensure the directory exists
  local dir_path = output_path:match("(.+)/[^/]+$")
  if dir_path then
    local mkdir_success, mkdir_err = fs.ensure_directory_exists(dir_path)
    if not mkdir_success then
      logger.warn("Failed to ensure directory exists, but will try to write anyway", {
        directory = dir_path,
        error = mkdir_err and error_handler.format_error(mkdir_err) or "Unknown error"
      })
    end
  end
  
  logger.info("Generating simplified HTML report")
  
  -- Generate HTML content
  local html = format_coverage_simple(coverage_data)
  
  -- Write the report to the output file
  local success, err = error_handler.safe_io_operation(
    function() 
      return fs.write_file(output_path, html)
    end,
    output_path,
    {operation = "write_coverage_report_simple"}
  )
  
  if not success then
    logger.error("Failed to write simplified HTML coverage report", {
      file_path = output_path,
      error = error_handler.format_error(err)
    })
    return false, err
  end
  
  logger.info("Successfully wrote simplified HTML coverage report", {
    file_path = output_path,
    report_size = #html
  })
  
  return true
end

-- Public format_coverage function used by the formatter registry
function M.format_coverage(coverage_data, output_path)
  -- If output_path is not a file path, assign a default
  if not output_path or output_path == "" or output_path:sub(-1) == "/" then
    output_path = (output_path or "./") .. "coverage-report-simple.html"
  end
  
  -- Generate the report
  local success, err = M.generate(coverage_data, output_path)
  if not success then
    return false, err
  end
  
  -- Return success
  return true
end

return M