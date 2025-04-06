--- HTML Formatter for Coverage Reports
-- Generates HTML coverage reports with syntax highlighting and interactive features
-- @module coverage.report.html
-- @author Firmo Team

local Formatter = require("lib.coverage.report.formatter")
local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")

-- Create HTML formatter class
local HTMLFormatter = Formatter.extend("html", "html")

--- HTML Formatter version
HTMLFormatter._VERSION = "1.0.0"

-- HTML escaping function
local function html_escape(s)
  if type(s) ~= "string" then
    s = tostring(s)
  end
  return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;")
end

-- Validate coverage data structure for HTML formatter
function HTMLFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end
  
  -- Additional HTML-specific validation if needed
  
  return true
end

-- Format coverage data as HTML
function HTMLFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, error_handler.validation_error("Coverage data is required", {formatter = self.name})
  end
  
  -- Apply options with defaults
  options = options or {}
  options.title = options.title or "Coverage Report"
  options.theme = options.theme or "light"
  options.include_source = options.include_source ~= false  -- Default to true
  options.threshold = options.threshold or 80
  
  -- Normalize the coverage data
  local normalized_data = self:normalize_coverage_data(coverage_data)
  
  -- Begin building HTML content
  local html = self:generate_html_header(options.title, options.theme)
  html = html .. self:generate_html_summary(normalized_data.summary, options)
  html = html .. self:generate_html_file_list(normalized_data.files, options)
  html = html .. self:generate_html_file_details(normalized_data.files, options)
  html = html .. self:generate_html_footer()
  
  return html
end

-- Generate HTML header with CSS and JavaScript
function HTMLFormatter:generate_html_header(title, theme)
  local html = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>]] .. html_escape(title) .. [[</title>
  <style>
    /* Base styles */
    :root {
      --bg-color: #ffffff;
      --text-color: #333333;
      --link-color: #0066cc;
      --header-bg: #f0f0f0;
      --covered-bg: #ccffcc;
      --executed-bg: #ffdd99;
      --not-covered-bg: #ffcccc;
      --border-color: #dddddd;
      --hover-color: #f5f5f5;
      --code-bg: #f8f8f8;
      --summary-bg: #eef9ff;
    }
    
    .dark-theme {
      --bg-color: #222222;
      --text-color: #e0e0e0;
      --link-color: #7db9f4;
      --header-bg: #333333;
      --covered-bg: #105510;
      --executed-bg: #775500;
      --not-covered-bg: #772222;
      --border-color: #444444;
      --hover-color: #333333;
      --code-bg: #2d2d2d;
      --summary-bg: #1d3443;
    }
    
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      margin: 0;
      padding: 0;
      background-color: var(--bg-color);
      color: var(--text-color);
    }
    
    a {
      color: var(--link-color);
      text-decoration: none;
    }
    
    a:hover {
      text-decoration: underline;
    }
    
    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 20px;
    }
    
    header {
      background-color: var(--header-bg);
      padding: 15px 20px;
      margin-bottom: 20px;
    }
    
    h1, h2, h3 {
      margin-top: 0;
    }
    
    /* Summary styles */
    .summary {
      background-color: var(--summary-bg);
      border-radius: 4px;
      padding: 15px;
      margin-bottom: 20px;
    }
    
    .summary-title {
      font-weight: bold;
      margin-bottom: 10px;
    }
    
    .summary-metrics {
      display: flex;
      flex-wrap: wrap;
      gap: 20px;
    }
    
    .metric {
      flex: 1;
      min-width: 200px;
    }
    
    .metric-value {
      font-size: 24px;
      font-weight: bold;
    }
    
    .metric-label {
      font-size: 14px;
      color: var(--text-color);
      opacity: 0.8;
    }
    
    /* File list styles */
    .file-list {
      margin-bottom: 30px;
      border: 1px solid var(--border-color);
      border-radius: 4px;
    }
    
    .file-list-header {
      background-color: var(--header-bg);
      padding: 10px 15px;
      font-weight: bold;
      display: flex;
    }
    
    .file-list-row {
      padding: 8px 15px;
      display: flex;
      border-top: 1px solid var(--border-color);
    }
    
    .file-list-row:hover {
      background-color: var(--hover-color);
    }
    
    .file-name {
      flex: 3;
    }
    
    .file-coverage {
      flex: 1;
      text-align: right;
    }
    
    /* File detail styles */
    .file-detail {
      margin-bottom: 30px;
      border: 1px solid var(--border-color);
      border-radius: 4px;
      overflow: hidden;
    }
    
    .file-detail-header {
      background-color: var(--header-bg);
      padding: 10px 15px;
      font-weight: bold;
      cursor: pointer;
      display: flex;
      justify-content: space-between;
    }
    
    .file-detail-content {
      display: none;
    }
    
    .file-detail.expanded .file-detail-content {
      display: block;
    }
    
    .file-source {
      font-family: monospace;
      white-space: pre;
      tab-size: 4;
      border-collapse: collapse;
      width: 100%;
    }
    
    .line-number {
      user-select: none;
      text-align: right;
      padding: 0 8px;
      min-width: 50px;
      color: #888;
      border-right: 1px solid var(--border-color);
    }
    
    .line-covered {
      background-color: var(--covered-bg);
    }
    
    .line-executed {
      background-color: var(--executed-bg);
    }
    
    .line-not-covered {
      background-color: var(--not-covered-bg);
    }
    
    .line-content {
      padding: 0 8px;
    }
    
    /* Controls */
    .controls {
      margin-bottom: 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    
    .theme-toggle {
      cursor: pointer;
      padding: 8px 12px;
      background-color: var(--header-bg);
      border: none;
      border-radius: 4px;
      color: var(--text-color);
    }
    
    .expand-all {
      cursor: pointer;
      padding: 8px 12px;
      background-color: var(--header-bg);
      border: none;
      border-radius: 4px;
      color: var(--text-color);
    }
    
    /* Progress bar */
    .progress-bar {
      height: 8px;
      background-color: var(--not-covered-bg);
      border-radius: 4px;
      overflow: hidden;
      margin-top: 5px;
    }
    
    .progress-value {
      height: 100%;
      background-color: var(--covered-bg);
    }
    
    /* Syntax highlighting */
    .keyword { color: #7373dd; }
    .string { color: #1fa858; }
    .comment { color: #777777; font-style: italic; }
    .number { color: #ff8000; }
    .operator { color: #999999; }
    .identifier { color: #0077aa; }
    
    .dark-theme .keyword { color: #8d8df2; }
    .dark-theme .string { color: #5cd68a; }
    .dark-theme .comment { color: #aaaaaa; }
    .dark-theme .number { color: #ffaa33; }
    .dark-theme .operator { color: #cccccc; }
    .dark-theme .identifier { color: #5cb1f2; }
  </style>
</head>
<body class="]] .. (theme == "dark" and "dark-theme" or "") .. [[">
  <div class="container">
    <header>
      <h1>]] .. html_escape(title) .. [[</h1>
      <div>Generated on ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[</div>
    </header>
    
    <div class="controls">
      <button class="theme-toggle" onclick="toggleTheme()">Toggle Theme</button>
      <button class="expand-all" onclick="toggleAllFiles()">Expand All Files</button>
    </div>
]]
  return html
end

-- Generate HTML summary section
function HTMLFormatter:generate_html_summary(summary, options)
  local threshold = options.threshold or 80
  local html = [[
    <div class="summary">
      <div class="summary-title">Coverage Summary</div>
      <div class="summary-metrics">
        <div class="metric">
          <div class="metric-value">]] .. summary.total_files .. [[</div>
          <div class="metric-label">Files</div>
        </div>
        <div class="metric">
          <div class="metric-value">]] .. string.format("%.1f", summary.coverage_percent) .. [[%</div>
          <div class="metric-label">Coverage</div>
          <div class="progress-bar">
            <div class="progress-value" style="width: ]] .. summary.coverage_percent .. [[%;"></div>
          </div>
        </div>
        <div class="metric">
          <div class="metric-value">]] .. summary.covered_lines .. [[/]] .. summary.total_lines .. [[</div>
          <div class="metric-label">Lines Covered</div>
        </div>
        <div class="metric">
          <div class="metric-value">]] .. summary.executed_lines .. [[</div>
          <div class="metric-label">Executed but Not Verified</div>
        </div>
      </div>
      
      <div class="threshold-info" style="margin-top: 15px;">
        <div>Coverage threshold: ]] .. threshold .. [[%</div>
        <div>Status: ]] .. (summary.coverage_percent >= threshold and 
              "<span style='color:#009900'>PASS</span>" or 
              "<span style='color:#cc0000'>FAIL</span>") .. [[</div>
      </div>
    </div>
]]
  return html
end

-- Generate HTML file list section
function HTMLFormatter:generate_html_file_list(files, options)
  local html = [[
    <h2>Files</h2>
    <div class="file-list">
      <div class="file-list-header">
        <div class="file-name">File</div>
        <div class="file-coverage">Coverage</div>
      </div>
]]

  -- Sort files by path for consistent ordering
  local sorted_files = {}
  for path, file_data in pairs(files) do
    table.insert(sorted_files, { path = path, data = file_data })
  end
  
  table.sort(sorted_files, function(a, b) return a.path < b.path end)
  
  -- Add each file's details
  for _, file in ipairs(sorted_files) do
    local path = file.path
    local data = file.data
    local file_id = self:create_file_id(path)
    local coverage_percent = data.summary.coverage_percent or 0
    
    -- Determine coverage color class based on threshold
    local threshold = options.threshold or 80
    local color_class = ""
    if coverage_percent >= threshold then
      color_class = "line-covered"
    elseif coverage_percent >= threshold / 2 then
      color_class = "line-executed"
    else
      color_class = "line-not-covered"
    end
    
    html = html .. [[
    <div id="file-]] .. file_id .. [[" class="file-detail">
      <div class="file-detail-header" onclick="toggleFile(']] .. file_id .. [[')">
        <div>]] .. html_escape(path) .. [[</div>
        <div class="]] .. color_class .. [[">]] .. string.format("%.1f", coverage_percent) .. [[%</div>
      </div>
      <div class="file-detail-content">
        <div class="file-summary">
          <div class="metric">
            <div class="metric-value">]] .. data.summary.total_lines .. [[</div>
            <div class="metric-label">Total Lines</div>
          </div>
          <div class="metric">
            <div class="metric-value">]] .. data.summary.covered_lines .. [[</div>
            <div class="metric-label">Covered Lines</div>
          </div>
          <div class="metric">
            <div class="metric-value">]] .. data.summary.executed_lines .. [[</div>
            <div class="metric-label">Executed Lines</div>
          </div>
          <div class="metric">
            <div class="metric-value">]] .. data.summary.not_covered_lines .. [[</div>
            <div class="metric-label">Not Covered Lines</div>
          </div>
        </div>
]]

    -- Only include source if configured to do so
    if options.include_source then
      -- Get source content
      local source_content = ""
      if data.source and data.source ~= "" then
        source_content = data.source
      else
        -- Try to read source file if available
        local success, content = error_handler.safe_io_operation(
          function() 
            if filesystem.file_exists(path) then
              return filesystem.read_file(path)
            end
            return nil
          end,
          path,
          {operation = "read_source_file"}
        )
        
        if success and content then
          source_content = content
        end
      end
      
      -- Only display source if we have it
      if source_content and source_content ~= "" then
        html = html .. [[
        <table class="file-source">
          <tbody>
]]
        -- Get the lines of source code
        local source_lines = {}
        for line in source_content:gmatch("([^\n]*)\n?") do
          table.insert(source_lines, line)
        end
        
        -- Add each line with coverage info
        for line_num, line_content in ipairs(source_lines) do
          -- Get coverage status for this line
          local line_status = "line-uncovered"
          local line_data = data.lines[tostring(line_num)]
          
          if line_data then
            if line_data.covered then
              line_status = "line-covered"
            elseif line_data.executed then
              line_status = "line-executed"
            elseif line_data.execution_count and line_data.execution_count > 0 then
              line_status = "line-executed"
            else
              line_status = "line-not-covered"
            end
          end
          
          -- Apply syntax highlighting to the content
          local highlighted_content = self:apply_syntax_highlighting(line_content)
          
          html = html .. [[
            <tr class="]] .. line_status .. [[">
              <td class="line-number">]] .. line_num .. [[</td>
              <td class="line-content">]] .. highlighted_content .. [[</td>
            </tr>
]]
        end
        
        html = html .. [[
          </tbody>
        </table>
]]
      else
        html = html .. [[
        <div class="source-not-available">Source code not available</div>
]]
      end
    end
    
    html = html .. [[
      </div>
    </div>
]]
  end

  return html
end

-- Generate the HTML footer with JavaScript
function HTMLFormatter:generate_html_footer()
  local html = [[
    <div class="footer">
      <p>Generated by Firmo Coverage Reporter ]] .. self._VERSION .. [[</p>
    </div>
    
    <script>
      // Theme toggling
      function toggleTheme() {
        document.body.classList.toggle('dark-theme');
        
        // Store theme preference
        const isDarkTheme = document.body.classList.contains('dark-theme');
        localStorage.setItem('firmo-coverage-theme', isDarkTheme ? 'dark' : 'light');
      }
      
      // Initialize theme from stored preference
      document.addEventListener('DOMContentLoaded', function() {
        const storedTheme = localStorage.getItem('firmo-coverage-theme');
        if (storedTheme === 'dark') {
          document.body.classList.add('dark-theme');
        }
      });
      
      // File detail toggling
      function toggleFile(fileId) {
        const fileElement = document.getElementById('file-' + fileId);
        if (fileElement) {
          fileElement.classList.toggle('expanded');
        }
      }
      
      // Show a specific file and scroll to it
      function showFile(fileId) {
        const fileElement = document.getElementById('file-' + fileId);
        if (fileElement) {
          // Expand the file
          fileElement.classList.add('expanded');
          
          // Scroll to it
          setTimeout(function() {
            fileElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }, 100);
        }
      }
      
      // Toggle all files
      function toggleAllFiles() {
        const expandAllButton = document.querySelector('.expand-all');
        const fileDetails = document.querySelectorAll('.file-detail');
        
        // Determine if we're expanding or collapsing
        const shouldExpand = !allFilesExpanded();
        
        // Update button text
        expandAllButton.textContent = shouldExpand ? 'Collapse All Files' : 'Expand All Files';
        
        // Toggle each file
        fileDetails.forEach(function(fileDetail) {
          if (shouldExpand) {
            fileDetail.classList.add('expanded');
          } else {
            fileDetail.classList.remove('expanded');
          }
        });
      }
      
      // Check if all files are expanded
      function allFilesExpanded() {
        const fileDetails = document.querySelectorAll('.file-detail');
        for (let i = 0; i < fileDetails.length; i++) {
          if (!fileDetails[i].classList.contains('expanded')) {
            return false;
          }
        }
        return fileDetails.length > 0;
      }
    </script>
  </div>
</body>
</html>
]]
  return html
end

-- Create a valid ID from a file path
function HTMLFormatter:create_file_id(path)
  -- Replace non-alphanumeric characters with hyphens
  local id = path:gsub("[^%w]", "-")
  -- Ensure it starts with a letter (for HTML ID validity)
  if id:match("^[^%a]") then
    id = "f-" .. id
  end
  return id
end

-- Apply basic syntax highlighting to Lua code
function HTMLFormatter:apply_syntax_highlighting(code)
  if not code or code == "" then
    return ""
  end
  
  -- Pre-process line for HTML safety
  local escaped_code = html_escape(code)
  
  -- Lua keywords to highlight
  local keywords = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
    ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
    ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true
  }
  
  -- Simple pattern-based highlighting (not perfect but good enough)
  
  -- Highlight comments
  escaped_code = escaped_code:gsub("(%-%-[^\n]*)", "<span class='comment'>%1</span>")
  
  -- Highlight strings (simple form)
  escaped_code = escaped_code:gsub("([\"'])(.-)%1", function(quote, content)
    return "<span class='string'>" .. quote .. content .. quote .. "</span>"
  end)
  
  -- Highlight numbers
  escaped_code = escaped_code:gsub("(%s+)(%d+%.?%d*)", "%1<span class='number'>%2</span>")
  escaped_code = escaped_code:gsub("^(%d+%.?%d*)", "<span class='number'>%1</span>")
  
  -- Highlight keywords
  escaped_code = escaped_code:gsub("([%s%p])([%w_]+)([%s%p])", function(pre, word, post)
    if keywords[word] then
      return pre .. "<span class='keyword'>" .. word .. "</span>" .. post
    end
    return pre .. word .. post
  end)
  
  return escaped_code
end

-- Write the report to the filesystem
function HTMLFormatter:write(html_content, output_path, options)
  return Formatter.write(self, html_content, output_path, options)
end

return HTMLFormatter

