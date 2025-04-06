---@class CoverageCobertura
---@field generate fun(coverage_data: table, output_path: string): boolean, string|nil Generates a Cobertura coverage report
---@field format_coverage fun(coverage_data: table): string Formats coverage data as Cobertura XML
---@field write_coverage_report fun(coverage_data: table, file_path: string): boolean, string|nil Writes coverage data to a file
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
-- Version
M._VERSION = "0.2.0"

--- XML escape function
---@param s string String to escape
---@return string escaped_string
local function xml_escape(s)
  if type(s) ~= "string" then
    s = tostring(s)
  end
  return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;")
end

--- Generates a Cobertura coverage report
---@param coverage_data table The coverage data
---@param output_path string The path where the report should be saved
---@return boolean success Whether report generation succeeded
---@return string|nil error_message Error message if generation failed
function M.generate(coverage_data, output_path)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(output_path) == "string", "output_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- If output_path is a directory, add a filename
  if output_path:sub(-1) == "/" then
    output_path = output_path .. "coverage-report-v2.cobertura"
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
  
  -- Check for basic coverage data structure
  if not coverage_data.execution_data or not coverage_data.coverage_data then
    logger.warn("Coverage data structure doesn't match expected format, but will attempt to generate report anyway")
  end
  
  -- Generate timestamp
  local timestamp = os.date("%Y-%m-%dT%H:%M:%S")
  
  -- Start building XML content
  local xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
  xml = xml .. '<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">\n'
  xml = xml .. '<coverage line-rate="' .. (coverage_data.summary.line_coverage_percent / 100) .. '" '
  xml = xml .. 'branch-rate="0" '
  xml = xml .. 'lines-covered="' .. coverage_data.summary.covered_lines .. '" '
  xml = xml .. 'lines-valid="' .. coverage_data.summary.executable_lines .. '" '
  xml = xml .. 'branches-covered="0" '
  xml = xml .. 'branches-valid="0" '
  xml = xml .. 'complexity="0" '
  xml = xml .. 'version="0.1" '
  xml = xml .. 'timestamp="' .. timestamp .. '">\n'
  
  -- Add sources
  xml = xml .. '  <sources>\n'
  xml = xml .. '    <source>.</source>\n'
  xml = xml .. '  </sources>\n'
  
  -- Add packages (we use files as packages in this simple implementation)
  xml = xml .. '  <packages>\n'
  
  -- Sort files for consistent output
  local files = {}
  for path, file_data in pairs(coverage_data.files) do
    table.insert(files, { path = path, data = file_data })
  end
  
  table.sort(files, function(a, b) return a.path < b.path end)
  
  -- Process each file
  for _, file in ipairs(files) do
    local file_data = file.data
    local path = file.path
    
    -- Generate a package name from the path (e.g. "lib.coverage")
    local package_name = path:gsub("/", "."):gsub("%.lua$", "")
    
    -- Add package
    xml = xml .. '    <package name="' .. xml_escape(package_name) .. '" '
    xml = xml .. 'line-rate="' .. (file_data.line_coverage_percent / 100) .. '" '
    xml = xml .. 'branch-rate="0" '
    xml = xml .. 'complexity="0">\n'
    
    -- Add classes (we use one class per file in this simple implementation)
    xml = xml .. '      <classes>\n'
    
    -- Add class
    local class_name = file_data.name:gsub("%.lua$", "")
    xml = xml .. '        <class name="' .. xml_escape(class_name) .. '" '
    xml = xml .. 'filename="' .. xml_escape(path) .. '" '
    xml = xml .. 'line-rate="' .. (file_data.line_coverage_percent / 100) .. '" '
    xml = xml .. 'branch-rate="0" '
    xml = xml .. 'complexity="0">\n'
    
    -- Add methods
    xml = xml .. '          <methods>\n'
    
    -- Sort functions by start line
    local functions = {}
    for func_id, func_data in pairs(file_data.functions) do
      table.insert(functions, {id = func_id, data = func_data})
    end
    
    table.sort(functions, function(a, b) return a.data.start_line < b.data.start_line end)
    
    -- Process each function
    for _, func in ipairs(functions) do
      local func_data = func.data
      local func_name = func_data.name
      
      -- Calculate line rate for this function
      local func_line_count = func_data.end_line - func_data.start_line + 1
      local func_line_rate = 0
      if func_data.executed then
        func_line_rate = 1
      end
      
      -- Add method
      xml = xml .. '            <method name="' .. xml_escape(func_name) .. '" '
      xml = xml .. 'signature="()V" ' -- Simplified method signature
      xml = xml .. 'line-rate="' .. func_line_rate .. '" '
      xml = xml .. 'branch-rate="0">\n'
      
      -- Add method lines
      xml = xml .. '              <lines>\n'
      
      -- Add function start line
      xml = xml .. '                <line number="' .. func_data.start_line .. '" '
      xml = xml .. 'hits="' .. (func_data.executed and func_data.execution_count > 0 and func_data.execution_count or 0) .. '" '
      xml = xml .. 'branch="false"/>\n'
      
      -- Add method end
      xml = xml .. '              </lines>\n'
      xml = xml .. '            </method>\n'
    end
    
    -- Close methods
    xml = xml .. '          </methods>\n'
    
    -- Add lines
    xml = xml .. '          <lines>\n'
    
    -- Get all executable lines
    local sorted_lines = {}
    for line_num, line_data in pairs(file_data.lines) do
      if line_data.executable then
        table.insert(sorted_lines, {
          line_num = line_num,
          data = line_data
        })
      end
    end
    
    table.sort(sorted_lines, function(a, b) return a.line_num < b.line_num end)
    
    -- Process each line
    for _, line_info in ipairs(sorted_lines) do
      local line_num = line_info.line_num
      local line_data = line_info.data
      
      -- Add line
      xml = xml .. '            <line number="' .. line_num .. '" '
      xml = xml .. 'hits="' .. line_data.execution_count .. '" '
      xml = xml .. 'branch="false"/>\n'
    end
    
    -- Close lines, class, classes, package
    xml = xml .. '          </lines>\n'
    xml = xml .. '        </class>\n'
    xml = xml .. '      </classes>\n'
    xml = xml .. '    </package>\n'
  end
  
  -- Close packages and coverage tags
  xml = xml .. '  </packages>\n'
  xml = xml .. '</coverage>\n'
  
  -- Write the report to the output file
  local success, err = error_handler.safe_io_operation(
    function() 
      return fs.write_file(output_path, xml)
    end,
    output_path,
    {operation = "write_cobertura_report"}
  )
  
  if not success then
    return false, "Failed to write Cobertura report: " .. error_handler.format_error(err)
  end
  
  logger.info("Generated Cobertura coverage report", {
    output_path = output_path,
    total_files = coverage_data.summary.total_files,
    line_coverage = coverage_data.summary.line_coverage_percent .. "%",
    function_coverage = coverage_data.summary.function_coverage_percent .. "%"
  })
  
  return true
end

--- Formats coverage data as Cobertura XML
---@param coverage_data table The coverage data
---@return string xml_content Cobertura XML content
function M.format_coverage(coverage_data)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  
  -- Check if summary is available
  if not coverage_data.summary then
    logger.warn("Coverage data does not contain summary data, returning empty Cobertura content")
    return '<?xml version="1.0" encoding="UTF-8"?>\n<coverage></coverage>'
  end
  
  -- Generate timestamp
  local timestamp = os.date("%Y-%m-%dT%H:%M:%S")
  
  -- Start building XML content
  local xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
  xml = xml .. '<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">\n'
  xml = xml .. '<coverage line-rate="' .. (coverage_data.summary.line_coverage_percent / 100) .. '" '
  xml = xml .. 'branch-rate="0" '
  xml = xml .. 'lines-covered="' .. coverage_data.summary.covered_lines .. '" '
  xml = xml .. 'lines-valid="' .. coverage_data.summary.executable_lines .. '" '
  xml = xml .. 'branches-covered="0" '
  xml = xml .. 'branches-valid="0" '
  xml = xml .. 'complexity="0" '
  xml = xml .. 'version="0.1" '
  xml = xml .. 'timestamp="' .. timestamp .. '">\n'
  
  -- Add sources
  xml = xml .. '  <sources>\n'
  xml = xml .. '    <source>.</source>\n'
  xml = xml .. '  </sources>\n'
  
  -- Add packages (we use files as packages in this simple implementation)
  xml = xml .. '  <packages>\n'
  
  -- Sort files for consistent output
  local files = {}
  for path, file_data in pairs(coverage_data.files) do
    table.insert(files, { path = path, data = file_data })
  end
  
  table.sort(files, function(a, b) return a.path < b.path end)
  
  -- Process each file
  for _, file in ipairs(files) do
    local file_data = file.data
    local path = file.path
    
    -- Generate a package name from the path (e.g. "lib.coverage")
    local package_name = path:gsub("/", "."):gsub("%.lua$", "")
    
    -- Add package
    xml = xml .. '    <package name="' .. xml_escape(package_name) .. '" '
    xml = xml .. 'line-rate="' .. (file_data.line_coverage_percent / 100) .. '" '
    xml = xml .. 'branch-rate="0" '
    xml = xml .. 'complexity="0">\n'
    
    -- Add classes (we use one class per file in this simple implementation)
    xml = xml .. '      <classes>\n'
    
    -- Add class
    local class_name = file_data.name:gsub("%.lua$", "")
    xml = xml .. '        <class name="' .. xml_escape(class_name) .. '" '
    xml = xml .. 'filename="' .. xml_escape(path) .. '" '
    xml = xml .. 'line-rate="' .. (file_data.line_coverage_percent / 100) .. '" '
    xml = xml .. 'branch-rate="0" '
    xml = xml .. 'complexity="0">\n'
    
    -- Add methods
    xml = xml .. '          <methods>\n'
    
    -- Sort functions by start line
    local functions = {}
    for func_id, func_data in pairs(file_data.functions) do
      table.insert(functions, {id = func_id, data = func_data})
    end
    
    table.sort(functions, function(a, b) return a.data.start_line < b.data.start_line end)
    
    -- Process each function
    for _, func in ipairs(functions) do
      local func_data = func.data
      local func_name = func_data.name
      
      -- Calculate line rate for this function
      local func_line_count = func_data.end_line - func_data.start_line + 1
      local func_line_rate = 0
      if func_data.executed then
        func_line_rate = 1
      end
      
      -- Add method
      xml = xml .. '            <method name="' .. xml_escape(func_name) .. '" '
      xml = xml .. 'signature="()V" ' -- Simplified method signature
      xml = xml .. 'line-rate="' .. func_line_rate .. '" '
      xml = xml .. 'branch-rate="0">\n'
      
      -- Add method lines
      xml = xml .. '              <lines>\n'
      
      -- Add function start line
      xml = xml .. '                <line number="' .. func_data.start_line .. '" '
      xml = xml .. 'hits="' .. (func_data.executed and func_data.execution_count > 0 and func_data.execution_count or 0) .. '" '
      xml = xml .. 'branch="false"/>\n'
      
      -- Add method end
      xml = xml .. '              </lines>\n'
      xml = xml .. '            </method>\n'
    end
    
    -- Close methods
    xml = xml .. '          </methods>\n'
    
    -- Add lines
    xml = xml .. '          <lines>\n'
    
    -- Get all executable lines
    local sorted_lines = {}
    for line_num, line_data in pairs(file_data.lines) do
      if line_data.executable then
        table.insert(sorted_lines, {
          line_num = line_num,
          data = line_data
        })
      end
    end
    
    table.sort(sorted_lines, function(a, b) return a.line_num < b.line_num end)
    
    -- Process each line
    for _, line_info in ipairs(sorted_lines) do
      local line_num = line_info.line_num
      local line_data = line_info.data
      
      -- Add line
      xml = xml .. '            <line number="' .. line_num .. '" '
      xml = xml .. 'hits="' .. line_data.execution_count .. '" '
      xml = xml .. 'branch="false"/>\n'
    end
    
    -- Close lines, class, classes, package
    xml = xml .. '          </lines>\n'
    xml = xml .. '        </class>\n'
    xml = xml .. '      </classes>\n'
    xml = xml .. '    </package>\n'
  end
  
  -- Close packages and coverage tags
  xml = xml .. '  </packages>\n'
  xml = xml .. '</coverage>\n'
  
  return xml
end

--- Writes coverage data to a file in Cobertura format
---@param coverage_data table The coverage data
---@param file_path string The path to write the file to
---@return boolean success Whether the write was successful
---@return string|nil error_message Error message if write failed
function M.write_coverage_report(coverage_data, file_path)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Format the data
  local xml = M.format_coverage(coverage_data)
  
  -- Write to file
  local success, err = error_handler.safe_io_operation(
    function() 
      return fs.write_file(file_path, xml)
    end,
    file_path,
    {operation = "write_cobertura_report"}
  )
  
  if not success then
    return false, "Failed to write Cobertura report: " .. error_handler.format_error(err)
  end
  
  logger.info("Wrote Cobertura coverage report", {
    file_path = file_path,
    size = #xml,
    total_files = coverage_data.summary.total_files,
    line_coverage = coverage_data.summary.line_coverage_percent .. "%"
  })
  
  return true
end

return M