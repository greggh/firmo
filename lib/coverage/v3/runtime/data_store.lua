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
  _VERSION = "3.0.0"
}

-- Coverage data structure
-- file_path -> { line_number -> { count = number, state = string } }
local coverage_data = {}

-- Record line execution
---@param file_path string Path to instrumented file
---@param line number Line number in instrumented file
---@return boolean success Whether execution was recorded
---@return string? error Error message if recording failed
function M.record_execution(file_path, line)
  -- Validate inputs
  if not file_path or type(file_path) ~= "string" then
    return false, error_handler.validation_error(
      "Invalid file path",
      { path = file_path }
    )
  end
  if not line or type(line) ~= "number" then
    return false, error_handler.validation_error(
      "Invalid line number",
      { line = line }
    )
  end

  -- Map temp path to original path
  local original_path, err = path_mapping.get_original_path(file_path)
  if not original_path then
    return false, err
  end

  -- Initialize data structures if needed
  coverage_data[original_path] = coverage_data[original_path] or {}
  coverage_data[original_path][line] = coverage_data[original_path][line] or {
    count = 0,
    state = "executed"
  }

  -- Update execution count
  coverage_data[original_path][line].count = coverage_data[original_path][line].count + 1

  logger.debug("Recorded line execution", {
    file = original_path,
    line = line,
    count = coverage_data[original_path][line].count
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
    return false, error_handler.validation_error(
      "Invalid file path",
      { path = file_path }
    )
  end
  if not line or type(line) ~= "number" then
    return false, error_handler.validation_error(
      "Invalid line number",
      { line = line }
    )
  end

  -- Map temp path to original path
  local original_path, err = path_mapping.get_original_path(file_path)
  if not original_path then
    return false, err
  end

  -- Initialize data structures if needed
  coverage_data[original_path] = coverage_data[original_path] or {}
  coverage_data[original_path][line] = coverage_data[original_path][line] or {
    count = 0,
    state = "executed"
  }

  -- Update coverage state
  coverage_data[original_path][line].state = "covered"

  logger.debug("Recorded line coverage", {
    file = original_path,
    line = line
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
---@return string serialized The serialized coverage data
function M.serialize()
  return error_handler.serialize(coverage_data)
end

-- Deserialize coverage data
---@param serialized string The serialized coverage data
---@return boolean success Whether data was deserialized successfully
---@return string? error Error message if deserialization failed
function M.deserialize(serialized)
  local data, err = error_handler.deserialize(serialized)
  if not data then
    return false, err
  end

  coverage_data = data
  return true
end

return M