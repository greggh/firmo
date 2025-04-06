--- CSV Formatter for Coverage Reports
-- Generates CSV format coverage reports with configurable columns
-- @module coverage.report.csv
-- @author Firmo Team

local Formatter = require("lib.coverage.report.formatter")
local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")

-- Create CSV formatter class
local CSVFormatter = Formatter.extend("csv", "csv")

--- CSV Formatter version
CSVFormatter._VERSION = "1.0.0"

-- Default column configurations
CSVFormatter.DEFAULT_FILE_COLUMNS = {
  { name = "File", field = "path" },
  { name = "Lines", field = "summary.total_lines" },
  { name = "Covered Lines", field = "summary.covered_lines" },
  { name = "Executed Lines", field = "summary.executed_lines" },
  { name = "Not Covered Lines", field = "summary.not_covered_lines" },
  { name = "Coverage %", field = "summary.coverage_percent", format = "%.2f" },
  { name = "Execution %", field = "summary.execution_percent", format = "%.2f" }
}

CSVFormatter.DEFAULT_LINE_COLUMNS = {
  { name = "File", field = "file" },
  { name = "Line", field = "line" },
  { name = "Executed", field = "executed" },
  { name = "Covered", field = "covered" },
  { name = "Execution Count", field = "execution_count" },
  { name = "Content", field = "content" }
}

-- Validate coverage data structure for CSV formatter
function CSVFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end
  
  -- Additional CSV-specific validation if needed
  
  return true
end

-- Format coverage data as CSV
function CSVFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, error_handler.validation_error("Coverage data is required", {formatter = self.name})
  end
  
  -- Apply options with defaults
  options = options or {}
  options.include_header = options.include_header ~= false  -- Default to true
  options.separator = options.separator or ","
  options.level = options.level or "file"  -- "file" or "line"
  options.columns = options.columns or (options.level == "line" and 
    self.DEFAULT_LINE_COLUMNS or self.DEFAULT_FILE_COLUMNS)
  
  -- Normalize the coverage data
  local normalized_data = self:normalize_coverage_data(coverage_data)
  
  -- Begin building CSV content
  local csv_content
  
  if options.level == "line" then
    csv_content = self:build_line_level_csv(normalized_data, options)
  else
    csv_content = self:build_file_level_csv(normalized_data, options)
  end
  
  return csv_content
end

-- Build file-level CSV content
function CSVFormatter:build_file_level_csv(data, options)
  local lines = {}
  local separator = options.separator or ","
  local columns = options.columns or self.DEFAULT_FILE_COLUMNS
  
  -- Add header if configured
  if options.include_header then
    local header_cells = {}
    for _, column in ipairs(columns) do
      table.insert(header_cells, self:escape_csv_field(column.name or ""))
    end
    table.insert(lines, table.concat(header_cells, separator))
  end
  
  -- Process each file
  local sorted_files = {}
  for path, file_data in pairs(data.files or {}) do
    -- Add path to the data for simpler lookup
    file_data.path = path
    table.insert(sorted_files, file_data)
  end
  
  -- Sort files by path for consistent output
  table.sort(sorted_files, function(a, b) return a.path < b.path end)
  
  -- Add each file as a row
  for _, file_data in ipairs(sorted_files) do
    local row_cells = {}
    
    -- Add each column's data
    for _, column in ipairs(columns) do
      local value = self:get_nested_field(file_data, column.field)
      
      -- Apply formatting if specified
      if column.format and type(value) == "number" then
        value = string.format(column.format, value)
      end
      
      -- Convert to string and escape
      value = self:escape_csv_field(tostring(value or ""))
      
      table.insert(row_cells, value)
    end
    
    table.insert(lines, table.concat(row_cells, separator))
  end
  
  -- Add summary row if configured
  if options.include_summary and data.summary then
    local summary_cells = {}
    
    -- First cell is "SUMMARY"
    summary_cells[1] = self:escape_csv_field("SUMMARY")
    
    -- Skip first column (file path) and add summary data for other columns
    for i = 2, #columns do
      local column = columns[i]
      local value = self:get_nested_field(data.summary, column.field:gsub("^summary%.", ""))
      
      -- Apply formatting if specified
      if column.format and type(value) == "number" then
        value = string.format(column.format, value)
      end
      
      -- Convert to string and escape
      value = self:escape_csv_field(tostring(value or ""))
      
      summary_cells[i] = value
    end
    
    table.insert(lines, table.concat(summary_cells, separator))
  end
  
  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

-- Build line-level CSV content
function CSVFormatter:build_line_level_csv(data, options)
  local lines = {}
  local separator = options.separator or ","
  local columns = options.columns or self.DEFAULT_LINE_COLUMNS
  
  -- Add header if configured
  if options.include_header then
    local header_cells = {}
    for _, column in ipairs(columns) do
      table.insert(header_cells, self:escape_csv_field(column.name or ""))
    end
    table.insert(lines, table.concat(header_cells, separator))
  end
  
  -- Process each file
  local sorted_files = {}
  for path, file_data in pairs(data.files or {}) do
    table.insert(sorted_files, { path = path, data = file_data })
  end
  
  -- Sort files by path for consistent output
  table.sort(sorted_files, function(a, b) return a.path < b.path end)
  
  -- Process each file's lines
  for _, file in ipairs(sorted_files) do
    local path = file.path
    local file_data = file.data
    
    -- Skip if no line data
    if not file_data.lines or not next(file_data.lines) then
      goto continue
    end
    
    -- Get source content if available
    local source_content = {}
    if file_data.source then
      for line in file_data.source:gmatch("([^\n]*)\n?") do
        table.insert(source_content, line)
      end
    end
    
    -- Sort line numbers for consistent output
    local line_numbers = {}
    for line_num, _ in pairs(file_data.lines) do
      table.insert(line_numbers, tonumber(line_num))
    end
    
    table.sort(line_numbers)
    
    -- Add each line as a row
    for _, line_num in ipairs(line_numbers) do
      local line_data = file_data.lines[tostring(line_num)]
      local row_cells = {}
      
      -- Create line record with file path for column lookup
      local line_record = {
        file = path,
        line = line_num,
        executed = line_data.executed or false,
        covered = line_data.covered or false,
        execution_count = line_data.execution_count or 0,
        content = (source_content[line_num] or "")
      }
      
      -- Add each column's data
      for _, column in ipairs(columns) do
        local value = self:get_nested_field(line_record, column.field)
        
        -- Apply formatting if specified
        if column.format and type(value) == "number" then
          value = string.format(column.format, value)
        elseif type(value) == "boolean" then
          value = value and "true" or "false"
        end
        
        -- Convert to string and escape
        value = self:escape_csv_field(tostring(value or ""))
        
        table.insert(row_cells, value)
      end
      
      table.insert(lines, table.concat(row_cells, separator))
    end
    
    ::continue::
  end
  
  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

-- Escape a value for CSV output
function CSVFormatter:escape_csv_field(value)
  if value == nil then
    return ""
  end
  
  -- Convert to string if it's not already
  if type(value) ~= "string" then
    value = tostring(value)
  end
  
  -- Check if the value needs escaping
  local needs_escaping = value:match('[",%s\n\r]')
  
  if needs_escaping then
    -- Escape double quotes by doubling them
    value = value:gsub('"', '""')
    -- Wrap in quotes
    return '"' .. value .. '"'
  else
    return value
  end
end

-- Get a field value from a nested table structure
function CSVFormatter:get_nested_field(data, field_path)
  if not data or not field_path then
    return nil
  end
  
  -- Split the field path by dots
  local parts = {}
  for part in field_path:gmatch("[^%.]+") do
    table.insert(parts, part)
  end
  
  -- Navigate through the data structure
  local current = data
  for _, part in ipairs(parts) do
    if type(current) ~= "table" then
      return nil
    end
    current = current[part]
    if current == nil then
      return nil
    end
  end
  
  return current
end

-- Write the report to the filesystem
function CSVFormatter:write(csv_content, output_path, options)
  return Formatter.write(self, csv_content, output_path, options)
end

return CSVFormatter

