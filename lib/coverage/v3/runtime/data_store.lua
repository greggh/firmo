-- Coverage data storage for v3 coverage system
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local path_mapping = require("lib.coverage.v3.path_mapping")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.runtime.data_store")

---@class coverage_v3_runtime_data_store
---@field record_execution fun(file_path: string, line: number): boolean Record line execution
---@field record_coverage fun(file_path: string, line: number): boolean Record line coverage
---@field get_data fun(): table Get current coverage data
---@field reset fun(): boolean Reset coverage data
---@field serialize fun(): string Serialize coverage data
---@field deserialize fun(serialized: string): boolean Deserialize coverage data
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0",
}

-- Coverage data structure
-- file_path -> { line_number -> { count = number, state = string } }
local coverage_data = {}

-- Constants
local MAX_LINE_NUMBER = 1000000 -- Arbitrary large number to prevent unreasonable line numbers

-- Validate line number
---@param line number Line number to validate
---@return boolean is_valid Whether the line number is valid
---@return string? error Error message if validation failed
local function validate_line_number(line)
  if not line then
    return false, "Line number is required"
  end
  
  if type(line) ~= "number" then
    return false, "Line number must be a number"
  end
  
  if math.floor(line) ~= line then
    return false, "Line number must be an integer"
  end
  
  if line <= 0 then
    return false, "Line number must be positive"
  end
  
  if line > MAX_LINE_NUMBER then
    return false, "Line number is too large"
  end
  
  return true
end

-- Initialize file data structure
---@param path string Path to file
---@return table file_data The initialized file data
local function initialize_file_data(path)
  if not coverage_data[path] then
    coverage_data[path] = {}
    logger.debug("Initialized data for file", { path = path })
  end
  return coverage_data[path]
end

-- Initialize line data structure
---@param file_data table File data table
---@param line number Line number
---@return table line_data The initialized line data
local function initialize_line_data(file_data, line)
  if not file_data[line] then
    file_data[line] = {
      count = 0,
      state = "executed"
    }
    logger.debug("Initialized data for line", { line = line })
  end
  return file_data[line]
end

-- Record line execution
---@param file_path string Path to instrumented file
---@param line number Line number in instrumented file
---@return boolean success Whether execution was recorded
---@return string? error Error message if recording failed
function M.record_execution(file_path, line)
  -- Validate inputs
  if not file_path or type(file_path) ~= "string" then
    return false, error_handler.validation_error("Invalid file path", { path = file_path })
  end
  
  local is_valid, err_msg = validate_line_number(line)
  if not is_valid then
    return false, error_handler.validation_error("Invalid line number: " .. err_msg, { line = line })
  end

  -- Map temp path to original path
  local original_path, err = path_mapping.get_original_path(file_path)
  if not original_path then
    return false, err
  end

  -- Initialize data structures if needed
  local file_data = initialize_file_data(original_path)
  local line_data = initialize_line_data(file_data, line)

  -- Update execution count with integer index
  line_data.count = line_data.count + 1

  logger.debug("Recorded line execution", {
    file = original_path,
    line = line,
    count = coverage_data[original_path][line].count,
  })

  return true
end

-- Record line coverage
---@param file_path string Path to instrumented file
---@param line number Line number in instrumented file
---@return boolean success Whether coverage was recorded
---@return string? error Error message if recording failed
function M.record_coverage(file_path, line)
  -- Validate inputs
  if not file_path or type(file_path) ~= "string" then
    return false, error_handler.validation_error("Invalid file path", { path = file_path })
  end
  
  local is_valid, err_msg = validate_line_number(line)
  if not is_valid then
    return false, error_handler.validation_error("Invalid line number: " .. err_msg, { line = line })
  end

  -- Map temp path to original path
  local original_path, err = path_mapping.get_original_path(file_path)
  if not original_path then
    return false, err
  end

  -- Initialize data structures if needed
  local file_data = initialize_file_data(original_path)
  local line_data = initialize_line_data(file_data, line)

  -- Update coverage state
  line_data.state = "covered"

  logger.debug("Recorded line coverage", {
    file = original_path,
    line = line,
  })

  return true
end

-- Get current coverage data
---@return table data The current coverage data
function M.get_data()
  return coverage_data
end

-- Reset coverage data
---@return boolean success Whether data was reset successfully
function M.reset()
  coverage_data = {}
  logger.debug("Reset coverage data")
  return true
end

-- Serialize coverage data
---@return string|nil serialized The serialized coverage data
---@return string? error Error message if serialization failed
function M.serialize()
  local json = require("lib.tools.json")
  local success, result = pcall(json.encode, coverage_data)
  if not success then
    logger.error("Failed to serialize coverage data", { error = result })
    return nil, "Failed to serialize coverage data: " .. tostring(result)
  end
  return result
end

-- Validate coverage data structure 
---@param data table The data to validate
---@return boolean is_valid Whether the data is valid
---@return string? error Error message if validation failed
local function validate_coverage_data(data)
  if type(data) ~= "table" then
    return false, "Coverage data must be a table"
  end

  for file_path, file_data in pairs(data) do
    if type(file_path) ~= "string" then
      return false, "File path must be a string"
    end
    
    if type(file_data) ~= "table" then
      return false, "File data must be a table"
    end
    
    for line_number, line_data in pairs(file_data) do
      -- Validate line number
      if type(line_number) ~= "number" then
        return false, "Line number must be a number"
      end
      
      if math.floor(line_number) ~= line_number then
        return false, "Line number must be an integer"
      end
      
      if line_number <= 0 then
        return false, "Line number must be positive"
      end
      
      -- Validate line data
      if type(line_data) ~= "table" then
        return false, "Line data must be a table"
      end
      
      if type(line_data.count) ~= "number" then
        return false, "Line count must be a number"
      end
      
      if type(line_data.state) ~= "string" then
        return false, "Line state must be a string"
      end
    end
  end
  
  return true
end

-- Deserialize coverage data
---@param serialized string The serialized coverage data
---@return boolean success Whether data was deserialized successfully
---@return string? error Error message if deserialization failed
function M.deserialize(serialized)
  if type(serialized) ~= "string" then
    return false, error_handler.validation_error("Serialized data must be a string", { type = type(serialized) })
  end

  local json = require("lib.tools.json")
  local data, err = json.decode(serialized)
  if not data then
    return false, error_handler.validation_error("Failed to decode JSON", { error = err })
  end

  -- Validate the structure of the deserialized data
  local is_valid, validation_error = validate_coverage_data(data)
  if not is_valid then
    return false, error_handler.validation_error("Invalid coverage data structure: " .. validation_error, {})
  end

  -- If everything is valid, update the coverage data
  coverage_data = data
  logger.debug("Successfully deserialized coverage data")
  return true
end

return M
