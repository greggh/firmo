---@class CoverageJsonFormatter
---@field generate fun(coverage_data: table, output_path: string): boolean, string|nil Generates a JSON coverage report
---@field format_coverage fun(coverage_data: table): string Formats coverage data as JSON
---@field write_coverage_report fun(coverage_data: table, file_path: string): boolean, string|nil Writes coverage data to a file
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
-- Version
M._VERSION = "0.2.0"

-- Simple JSON encoding
local function encode_json(value, pretty)
  local json_string = ""
  local indent = pretty and 2 or 0
  local current_indent = 0
  
  local function get_indent(level)
    if not pretty then return "" end
    return string.rep(" ", level)
  end
  
  local function encode(val, level)
    level = level or 0
    local indent_str = get_indent(level)
    
    if type(val) == "table" then
      -- Check if array-like
      local is_array = true
      local max_index = 0
      
      for k, _ in pairs(val) do
        if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
          is_array = false
          break
        end
        max_index = math.max(max_index, k)
      end
      
      is_array = is_array and max_index == #val
      
      if is_array then
        -- Array encoding
        if #val == 0 then
          return "[]"
        end
        
        local items = {}
        for i, v in ipairs(val) do
          if pretty then
            items[i] = get_indent(level + indent) .. encode(v, level + indent)
          else
            items[i] = encode(v, level + indent)
          end
        end
        
        if pretty then
          return "[\n" .. table.concat(items, ",\n") .. "\n" .. indent_str .. "]"
        else
          return "[" .. table.concat(items, ",") .. "]"
        end
      else
        -- Object encoding
        local count = 0
        for _, _ in pairs(val) do
          count = count + 1
        end
        
        if count == 0 then
          return "{}"
        end
        
        local items = {}
        local i = 1
        
        for k, v in pairs(val) do
          local key = type(k) == "string" and '"' .. k:gsub('"', '\\"') .. '"' or "[" .. tostring(k) .. "]"
          
          if pretty then
            items[i] = get_indent(level + indent) .. key .. ": " .. encode(v, level + indent)
          else
            items[i] = key .. ":" .. encode(v, level + indent)
          end
          
          i = i + 1
        end
        
        if pretty then
          return "{\n" .. table.concat(items, ",\n") .. "\n" .. indent_str .. "}"
        else
          return "{" .. table.concat(items, ",") .. "}"
        end
      end
      
    elseif type(val) == "string" then
      -- Escape special characters
      local escaped = val:gsub('\\', '\\\\')
                         :gsub('"', '\\"')
                         :gsub('\n', '\\n')
                         :gsub('\r', '\\r')
                         :gsub('\t', '\\t')
                         :gsub('\b', '\\b')
                         :gsub('\f', '\\f')
      
      return '"' .. escaped .. '"'
      
    elseif type(val) == "number" then
      -- Handle NaN and infinity
      if val ~= val then  -- NaN
        return '"NaN"'
      elseif val == math.huge then
        return '"Infinity"'
      elseif val == -math.huge then
        return '"-Infinity"'
      else
        return tostring(val)
      end
      
    elseif type(val) == "boolean" then
      return tostring(val)
      
    elseif val == nil then
      return "null"
      
    else
      -- Unsupported type, convert to string
      return '"' .. tostring(val) .. '"'
    end
  end
  
  json_string = encode(value, current_indent)
  return json_string
end

--- Prepares coverage data for JSON serialization to avoid large string contents
---@param coverage_data table The coverage data
---@return table serializable_data A version of the data suitable for JSON serialization
local function prepare_json_data(coverage_data)
  -- Create a clean copy without file source contents
  local json_data = {
    summary = {}, -- Will copy all summary fields
    files = {}    -- Will copy files with modifications
  }
  
  -- Copy summary
  for k, v in pairs(coverage_data.summary) do
    json_data.summary[k] = v
  end
  
  -- Process files
  for path, file_data in pairs(coverage_data.files) do
    json_data.files[path] = {
      path = file_data.path,
      name = file_data.name,
      total_lines = file_data.total_lines,
      executable_lines = file_data.executable_lines,
      executed_lines = file_data.executed_lines,
      covered_lines = file_data.covered_lines,
      line_coverage_percent = file_data.line_coverage_percent,
      execution_coverage_percent = file_data.execution_coverage_percent,
      total_functions = file_data.total_functions,
      executed_functions = file_data.executed_functions,
      covered_functions = file_data.covered_functions,
      function_coverage_percent = file_data.function_coverage_percent,
      lines = {},
      functions = {}
    }
    
    -- Add line data (but with truncated content for readability)
    for line_num, line_data in pairs(file_data.lines) do
      -- Only include minimal necessary line data to keep the JSON size manageable
      json_data.files[path].lines[tostring(line_num)] = {
        executable = line_data.executable,
        executed = line_data.executed,
        covered = line_data.covered,
        execution_count = line_data.execution_count,
        line_type = line_data.line_type,
        -- Truncate content to first 50 chars to save space
        content = line_data.content:sub(1, 50) .. (line_data.content:len() > 50 and "..." or "")
      }
    end
    
    -- Add function data
    for func_id, func_data in pairs(file_data.functions) do
      json_data.files[path].functions[func_id] = {
        name = func_data.name,
        start_line = func_data.start_line,
        end_line = func_data.end_line,
        type = func_data.type,
        executed = func_data.executed,
        covered = func_data.covered,
        execution_count = func_data.execution_count
      }
    end
  end
  
  return json_data
end

--- Generates a JSON coverage report
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
    output_path = output_path .. "coverage-report-v2.json"
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
  
  -- Prepare data for JSON serialization (removing large strings)
  local json_data = prepare_json_data(coverage_data)
  
  -- Format the data as JSON
  local json_content = encode_json(json_data, true)
  
  -- Write the report to the output file
  local success, err = error_handler.safe_io_operation(
    function() 
      return fs.write_file(output_path, json_content)
    end,
    output_path,
    {operation = "write_json_report"}
  )
  
  if not success then
    return false, "Failed to write JSON report: " .. error_handler.format_error(err)
  end
  
  logger.info("Generated JSON coverage report", {
    output_path = output_path,
    total_files = coverage_data.summary.total_files,
    line_coverage = coverage_data.summary.line_coverage_percent .. "%",
    function_coverage = coverage_data.summary.function_coverage_percent .. "%"
  })
  
  return true
end

--- Formats coverage data as JSON
---@param coverage_data table The coverage data
---@return string json_content JSON content
function M.format_coverage(coverage_data)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  
  -- Check if summary is available
  if not coverage_data.summary then
    logger.warn("Coverage data does not contain summary data, returning empty JSON content")
    return "{}"
  end
  
  -- Prepare data for JSON serialization (removing large strings)
  local json_data = prepare_json_data(coverage_data)
  
  -- Format the data as JSON
  local json_content = encode_json(json_data, true)
  
  return json_content
end

--- Writes coverage data to a file in JSON format
---@param coverage_data table The coverage data
---@param file_path string The path to write the file to
---@return boolean success Whether the write was successful
---@return string|nil error_message Error message if write failed
function M.write_coverage_report(coverage_data, file_path)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Format the data
  local json = M.format_coverage(coverage_data)
  
  -- Write to file
  local success, err = error_handler.safe_io_operation(
    function() 
      return fs.write_file(file_path, json)
    end,
    file_path,
    {operation = "write_json_report"}
  )
  
  if not success then
    return false, "Failed to write JSON report: " .. error_handler.format_error(err)
  end
  
  logger.info("Wrote JSON coverage report", {
    file_path = file_path,
    size = #json,
    total_files = coverage_data.summary.total_files,
    line_coverage = coverage_data.summary.line_coverage_percent .. "%"
  })
  
  return true
end

return M