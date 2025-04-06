--- Coverage Report module for firmo
-- Generates coverage reports in various formats
-- @module coverage.report
-- @author Firmo Team

local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")

-- Initialize with config registration
central_config.register_module("coverage.report", {
  -- Schema definition
  field_types = {
    output_dir = "string",
    formats = "table",
    include_source = "boolean",
    pretty_print = "boolean",
    theme = "string",
    threshold = "number",
    open_report = "boolean"
  },
  -- Field value constraints
  field_values = {
    theme = {"light", "dark"}
  }
}, {
  -- Default values
  output_dir = "coverage-reports",
  formats = {"html", "json"},
  include_source = true,
  pretty_print = true,
  theme = "light",
  threshold = 80,
  open_report = false
})

-- The report module table
local report = {}

-- Version
report._VERSION = "1.0.0"

-- Available formatters (lazy-loaded)
local formatters = {
  html = nil,
  json = nil,
  lcov = nil,
  cobertura = nil,
  junit = nil,
  tap = nil,
  csv = nil
}

-- Formatter file paths
local formatter_paths = {
  html = "lib.coverage.report.html",
  json = "lib.coverage.report.json",
  lcov = "lib.coverage.report.lcov",
  cobertura = "lib.coverage.report.cobertura",
  junit = "lib.coverage.report.junit",
  tap = "lib.coverage.report.tap",
  csv = "lib.coverage.report.csv"
}

--- Load a formatter by name
-- @param format string The formatter name
-- @return table formatter The formatter module or nil if not found
-- @return table|nil error Error if loading failed
local function load_formatter(format)
  if not formatters[format] then
    if not formatter_paths[format] then
      return nil, error_handler.validation_error(
        "Unsupported formatter: " .. format,
        { available_formatters = table.concat(report.get_available_formats(), ", ") }
      )
    end
    
    local success, result = error_handler.try(function()
      return require(formatter_paths[format])
    end)
    
    if not success then
      return nil, error_handler.runtime_error(
        "Failed to load formatter: " .. format, 
        { error = result.message, formatter = format }
      )
    end
    
    formatters[format] = result
  end
  
  return formatters[format]
end

--- Get a list of available formatter names
-- @return table formats List of available formatter names
function report.get_available_formats()
  local available = {}
  for format, _ in pairs(formatter_paths) do
    table.insert(available, format)
  end
  table.sort(available)
  return available
end

--- Validates coverage data to ensure it has the expected structure
-- @param coverage_data table The coverage data to validate
-- @return boolean valid Whether the data is valid
-- @return table|nil error Error if validation failed
function report.validate_coverage_data(coverage_data)
  if type(coverage_data) ~= "table" then
    return false, error_handler.validation_error(
      "Coverage data must be a table", 
      { provided_type = type(coverage_data) }
    )
  end
  
  -- Check for required top-level fields
  if not coverage_data.data then
    return false, error_handler.validation_error(
      "Coverage data must contain 'data' field",
      { fields = table.concat(get_table_keys(coverage_data), ", ") }
    )
  end
  
  -- Successful validation
  return true
end

--- Formats coverage data to specified format
-- @param coverage_data table The coverage data
-- @param format string The format to convert to
-- @param options table|nil Optional configuration for the formatter
-- @return string|nil formatted The formatted data or nil on error
-- @return table|nil error Error if formatting failed
function report.format(coverage_data, format, options)
  -- Parameter validation
  if not coverage_data then
    return nil, error_handler.validation_error("Coverage data is required")
  end
  
  if not format then
    return nil, error_handler.validation_error("Format is required")
  end
  
  -- Validate coverage data
  local is_valid, validation_error = report.validate_coverage_data(coverage_data)
  if not is_valid then
    return nil, validation_error
  end
  
  -- Load the formatter
  local formatter, load_error = load_formatter(format)
  if not formatter then
    return nil, load_error
  end
  
  -- Format the data
  local success, result, err = error_handler.try(function()
    -- Merge options with config defaults
    local config = central_config.get("coverage.report")
    local merged_options = {}
    
    -- Start with config defaults
    for k, v in pairs(config) do
      merged_options[k] = v
    end
    
    -- Override with provided options
    if options then
      for k, v in pairs(options) do
        merged_options[k] = v
      end
    end
    
    return formatter.format(coverage_data, merged_options)
  end)
  
  if not success then
    return nil, error_handler.runtime_error(
      "Failed to format coverage data", 
      { format = format, error = result.message }
    )
  end
  
  return result
end

--- Writes formatted coverage data to a file
-- @param formatted_data string The formatted coverage data
-- @param output_path string The path to write to
-- @param options table|nil Optional configuration for the write operation
-- @return boolean success Whether the write was successful
-- @return table|nil error Error if write failed
function report.write(formatted_data, output_path, options)
  -- Parameter validation
  if not formatted_data then
    return false, error_handler.validation_error("Formatted data is required")
  end
  
  if not output_path then
    return false, error_handler.validation_error("Output path is required")
  end
  
  -- Ensure directory exists
  local dir_path = filesystem.get_directory_name(output_path)
  if dir_path and dir_path ~= "" then
    local success, err = filesystem.ensure_directory_exists(dir_path)
    if not success then
      return false, error_handler.io_error(
        "Failed to create directory for report", 
        { directory = dir_path, error = err }
      )
    end
  end
  
  -- Write the file
  local success, err = error_handler.safe_io_operation(
    function() 
      return filesystem.write_file(output_path, formatted_data)
    end,
    output_path,
    {operation = "write_coverage_report"}
  )
  
  if not success then
    return false, error_handler.io_error(
      "Failed to write coverage report", 
      { path = output_path, error = err and err.message or err }
    )
  end
  
  return true
end

--- Generates a coverage report in the specified format
-- @param coverage_data table The coverage data
-- @param format string The report format
-- @param output_path string|nil The path to write the report to (defaults to auto-generated path)
-- @param options table|nil Additional options for the formatter
-- @return boolean success Whether report generation succeeded
-- @return string|table path_or_error The report path if successful, or error if failed
function report.generate(coverage_data, format, output_path, options)
  -- Parameter validation
  if not coverage_data then
    return false, error_handler.validation_error("Coverage data is required")
  end
  
  if not format then
    return false, error_handler.validation_error("Format is required")
  end
  
  -- Get configuration
  local config = central_config.get("coverage.report")
  
  -- Generate output path if not provided
  if not output_path then
    local output_dir = (options and options.output_dir) or config.output_dir
    filesystem.ensure_directory_exists(output_dir)
    
    -- Determine filename based on format
    local extension = format
    if format == "html" then
      extension = "html"
    elseif format == "json" then
      extension = "json"
    elseif format == "lcov" then
      extension = "lcov"
    elseif format == "cobertura" then
      extension = "xml"
    elseif format == "junit" then
      extension = "xml"
    elseif format == "tap" then
      extension = "tap"
    elseif format == "csv" then
      extension = "csv"
    end
    
    output_path = filesystem.join_paths(output_dir, "coverage-report." .. extension)
  end
  
  -- Format the coverage data
  local formatted_data, format_error = report.format(coverage_data, format, options)
  if not formatted_data then
    return false, format_error
  end
  
  -- Write the report
  local write_success, write_error = report.write(formatted_data, output_path, options)
  if not write_success then
    return false, write_error
  end
  
  return true, output_path
end

--- Generates reports in multiple formats
-- @param coverage_data table The coverage data
-- @param formats table|nil The formats to generate (defaults to configured formats)
-- @param output_dir string|nil The directory to write reports to (defaults to configured dir)
-- @param options table|nil Additional options for the formatters
-- @return boolean success Whether all reports were generated successfully
-- @return table results Table of results with format as key and success/error as value
function report.generate_reports(coverage_data, formats, output_dir, options)
  -- Parameter validation
  if not coverage_data then
    return false, error_handler.validation_error("Coverage data is required")
  end
  
  -- Get configuration
  local config = central_config.get("coverage.report")
  
  -- Determine formats to generate
  formats = formats or config.formats
  if type(formats) == "string" then
    formats = {formats}
  end
  
  -- Ensure output directory exists
  output_dir = output_dir or config.output_dir
  local dir_success, dir_error = filesystem.ensure_directory_exists(output_dir)
  if not dir_success then
    return false, error_handler.io_error(
      "Failed to create directory for reports",
      { directory = output_dir, error = dir_error }
    )
  end
  
  -- Generate each report
  local overall_success = true
  local results = {}
  
  for _, format in ipairs(formats) do
    local output_path = filesystem.join_paths(output_dir, "coverage-report." .. format)
    local success, result = report.generate(coverage_data, format, output_path, options)
    
    results[format] = {
      success = success,
      result = success and result or nil,
      error = not success and result or nil
    }
    
    overall_success = overall_success and success
  end
  
  return overall_success, results
end

-- Helper function to get table keys
function get_table_keys(tbl)
  local keys = {}
  for k, _ in pairs(tbl) do
    table.insert(keys, k)
  end
  return keys
end

return report

