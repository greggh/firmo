--- Base Formatter class for Coverage Reports
-- Provides common functionality for all coverage report formatters
-- @module coverage.report.formatter
-- @author Firmo Team

local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")

--- Formatter Class
-- @type Formatter
local Formatter = {}

-- Module version
Formatter._VERSION = "1.0.0"

--- Creates a new formatter instance
-- @param name string The name of the formatter
-- @param extension string The file extension for this formatter
-- @return table formatter The new formatter instance
function Formatter.new(name, extension)
  local formatter = {
    name = name,
    extension = extension,
    options = {}
  }
  
  -- Set default meta-methods
  setmetatable(formatter, {
    __index = Formatter,
    __tostring = function(self)
      return string.format("Formatter(%s)", self.name)
    end
  })
  
  return formatter
end

--- Base method to validate coverage data structure
-- This should be overridden by specific formatters if they need custom validation
-- @param coverage_data table The coverage data to validate
-- @return boolean valid Whether the data is valid
-- @return table|nil error Error if validation failed
function Formatter:validate(coverage_data)
  if type(coverage_data) ~= "table" then
    return false, error_handler.validation_error(
      "Coverage data must be a table", 
      { formatter = self.name, provided_type = type(coverage_data) }
    )
  end
  
  -- Check for required top-level fields
  if not coverage_data.data then
    return false, error_handler.validation_error(
      "Coverage data must contain 'data' field",
      { formatter = self.name, fields = table.concat(self:get_table_keys(coverage_data), ", ") }
    )
  end
  
  -- Additional validation can be added by derived formatters
  
  return true
end

--- Base method to format coverage data
-- This must be implemented by each specific formatter
-- @param coverage_data table The coverage data to format
-- @param options table|nil Optional configuration for the formatter
-- @return string|nil formatted The formatted data or nil on error
-- @return table|nil error Error if formatting failed
function Formatter:format(coverage_data, options)
  return nil, error_handler.validation_error(
    "format() method must be implemented by formatter: " .. self.name,
    { formatter = self.name }
  )
end

--- Base method to write formatted data to a file
-- @param formatted_data string The formatted coverage data
-- @param output_path string The path to write to
-- @param options table|nil Optional configuration for the write operation
-- @return boolean success Whether the write was successful
-- @return table|nil error Error if write failed
function Formatter:write(formatted_data, output_path, options)
  -- Parameter validation
  if not formatted_data then
    return false, error_handler.validation_error(
      "Formatted data is required", 
      { formatter = self.name }
    )
  end
  
  if not output_path then
    return false, error_handler.validation_error(
      "Output path is required", 
      { formatter = self.name }
    )
  end
  
  -- Ensure directory exists
  local dir_path = filesystem.get_directory_name(output_path)
  if dir_path and dir_path ~= "" then
    local success, err = filesystem.ensure_directory_exists(dir_path)
    if not success then
      return false, error_handler.io_error(
        "Failed to create directory for report", 
        { formatter = self.name, directory = dir_path, error = err }
      )
    end
  end
  
  -- Write the file using a safe operation
  local success, err = error_handler.safe_io_operation(
    function() 
      return filesystem.write_file(output_path, formatted_data)
    end,
    output_path,
    {operation = "write_" .. self.name .. "_report"}
  )
  
  if not success then
    return false, error_handler.io_error(
      "Failed to write " .. self.name .. " report", 
      { formatter = self.name, path = output_path, error = err and err.message or err }
    )
  end
  
  return true
end

--- Generate a complete report
-- @param coverage_data table The coverage data
-- @param output_path string The path to write the report to
-- @param options table|nil Additional options for the formatter
-- @return boolean success Whether report generation succeeded
-- @return string|table path_or_error The report path if successful, or error if failed
function Formatter:generate(coverage_data, output_path, options)
  -- Validate coverage data
  local is_valid, validation_error = self:validate(coverage_data)
  if not is_valid then
    return false, validation_error
  end
  
  -- Format the coverage data
  local formatted_data, format_error = self:format(coverage_data, options)
  if not formatted_data then
    return false, format_error
  end
  
  -- Write the report
  local write_success, write_error = self:write(formatted_data, output_path, options)
  if not write_success then
    return false, write_error
  end
  
  return true, output_path
end

--- Normalizes coverage data for consistent formatting
-- @param coverage_data table The raw coverage data
-- @return table normalized_data Normalized coverage data
function Formatter:normalize_coverage_data(coverage_data)
  if not coverage_data then
    return {}
  end
  
  -- Create a deep copy to avoid modifying the original
  local normalized = self:deep_copy(coverage_data)
  
  -- Ensure summary exists
  normalized.summary = normalized.summary or {}
  
  -- Set defaults for required summary fields if missing
  normalized.summary.total_files = normalized.summary.total_files or 0
  normalized.summary.total_lines = normalized.summary.total_lines or 0
  normalized.summary.covered_lines = normalized.summary.covered_lines or 0
  normalized.summary.executed_lines = normalized.summary.executed_lines or 0
  normalized.summary.not_covered_lines = normalized.summary.not_covered_lines or 0
  
  -- Calculate coverage percentage if missing
  if not normalized.summary.coverage_percent then
    normalized.summary.coverage_percent = 0
    if normalized.summary.total_lines > 0 then
      normalized.summary.coverage_percent = 
        (normalized.summary.covered_lines / normalized.summary.total_lines) * 100
    end
  end
  
  -- Calculate execution percentage if missing
  if not normalized.summary.execution_percent then
    normalized.summary.execution_percent = 0
    if normalized.summary.total_lines > 0 then
      normalized.summary.execution_percent = 
        ((normalized.summary.covered_lines + normalized.summary.executed_lines) / 
        normalized.summary.total_lines) * 100
    end
  end
  
  -- Ensure files structure exists
  normalized.files = normalized.files or {}
  
  -- Normalize each file
  for file_path, file_data in pairs(normalized.files) do
    -- Ensure file summary exists
    file_data.summary = file_data.summary or {}
    
    -- Set defaults for required file summary fields if missing
    file_data.summary.total_lines = file_data.summary.total_lines or 0
    file_data.summary.covered_lines = file_data.summary.covered_lines or 0
    file_data.summary.executed_lines = file_data.summary.executed_lines or 0
    file_data.summary.not_covered_lines = file_data.summary.not_covered_lines or 0
    
    -- Calculate file coverage percentage if missing
    if not file_data.summary.coverage_percent then
      file_data.summary.coverage_percent = 0
      if file_data.summary.total_lines > 0 then
        file_data.summary.coverage_percent = 
          (file_data.summary.covered_lines / file_data.summary.total_lines) * 100
      end
    end
    
    -- Calculate file execution percentage if missing
    if not file_data.summary.execution_percent then
      file_data.summary.execution_percent = 0
      if file_data.summary.total_lines > 0 then
        file_data.summary.execution_percent = 
          ((file_data.summary.covered_lines + file_data.summary.executed_lines) / 
          file_data.summary.total_lines) * 100
      end
    end
    
    -- Ensure lines structure exists
    file_data.lines = file_data.lines or {}
    
    -- Normalize each line
    for line_number, line_data in pairs(file_data.lines) do
      -- Ensure required line fields
      line_data.line_number = line_data.line_number or tonumber(line_number)
      line_data.executed = line_data.executed or false
      line_data.covered = line_data.covered or false
      line_data.execution_count = line_data.execution_count or 0
      
      -- Ensure assertions array exists
      line_data.assertions = line_data.assertions or {}
    end
    
    -- Ensure functions structure exists
    file_data.functions = file_data.functions or {}
    
    -- Normalize each function
    for func_id, func_data in pairs(file_data.functions) do
      -- Ensure required function fields
      func_data.name = func_data.name or func_id
      func_data.start_line = func_data.start_line or 0
      func_data.end_line = func_data.end_line or 0
      func_data.executed = func_data.executed or false
      func_data.covered = func_data.covered or false
      func_data.execution_count = func_data.execution_count or 0
    end
  end
  
  return normalized
end

--- Creates a deep copy of a table or value
-- @param value any The value to copy
-- @return any copy The deep copy
function Formatter:deep_copy(value)
  if type(value) ~= "table" then
    return value
  end
  
  local copy = {}
  for k, v in pairs(value) do
    if type(v) == "table" then
      copy[k] = self:deep_copy(v)
    else
      copy[k] = v
    end
  end
  
  return copy
end

--- Gets all keys from a table as an array
-- @param tbl table The table to get keys from
-- @return table keys Array of table keys
function Formatter:get_table_keys(tbl)
  local keys = {}
  if type(tbl) == "table" then
    for k, _ in pairs(tbl) do
      table.insert(keys, k)
    end
    table.sort(keys)
  end
  return keys
end

--- Creates a new formatter class that extends the base formatter
-- @param name string The name of the new formatter
-- @param extension string The file extension for this formatter
-- @return table formatter_class The new formatter class
function Formatter.extend(name, extension)
  local formatter_class = {
    name = name,
    extension = extension
  }
  
  -- Set up inheritance
  setmetatable(formatter_class, {
    __index = Formatter,
    __call = function(cls, ...)
      return cls.new(...)
    end
  })
  
  -- Set up .new method for the class
  formatter_class.new = function(options)
    local instance = {
      options = options or {}
    }
    
    setmetatable(instance, {
      __index = formatter_class,
      __tostring = function(self)
        return string.format("Formatter(%s)", name)
      end
    })
    
    return instance
  end
  
  return formatter_class
end

return Formatter

