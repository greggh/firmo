-- Runtime tracking for instrumented code
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local path_mapping = require("lib.coverage.v3.path_mapping")
local data_store = require("lib.coverage.v3.runtime.data_store")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.runtime.tracker")

---@class coverage_v3_runtime_tracker
---@field track fun(line: number, state: string, file_path: string): boolean Track code execution
---@field start fun(): boolean Start tracking
---@field stop fun(): boolean Stop tracking
---@field reset fun(): boolean Reset tracking data
---@field get_data fun(): table Get current tracking data
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Track whether tracking is active
local is_active = false

-- Track persistent state
local tracking_state = {
  processed_lines = {},
  assertion_coverage = {}
}

-- Constants
local MAX_LINE_NUMBER = 1000000 -- Consistent with data_store limit
-- Validate line number for tracking
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

-- Initialize tracking for a file if needed
---@param file_path string Path to the file
local function initialize_file_tracking(file_path)
  if not tracking_state.processed_lines[file_path] then
    tracking_state.processed_lines[file_path] = {}
  end
  
  if not tracking_state.assertion_coverage[file_path] then
    tracking_state.assertion_coverage[file_path] = {}
  end
end
-- Track code execution
---@param line number Line number in instrumented file
---@param state string Coverage state ("executed" or "covered")
---@param file_path string Path to instrumented file
---@return boolean success Whether tracking was successful
---@return string? error Error message if tracking failed
function M.track(line, state, file_path)
  -- Skip if not active
  if not is_active then
    return true
  end

  -- Validate inputs
  local is_valid, err_msg = validate_line_number(line)
  if not is_valid then
    return false, error_handler.validation_error(
      "Invalid line number: " .. err_msg,
      { line = line }
    )
  end
  
  if not state or (state ~= "executed" and state ~= "covered") then
    return false, error_handler.validation_error(
      "Invalid coverage state",
      { state = state }
    )
  end
  
  if not file_path or type(file_path) ~= "string" then
    return false, error_handler.validation_error(
      "Invalid file path",
      { path = file_path }
    )
  end

  -- Map temp path to original path
  local original_path, err = path_mapping.get_original_path(file_path)
  if not original_path then
    return false, err
  end

  -- Initialize tracking for this file
  initialize_file_tracking(original_path)

  -- Keep track of processed lines for state persistence
  if not tracking_state.processed_lines[original_path][line] then
    tracking_state.processed_lines[original_path][line] = true
  end

  -- Record execution in data store
  if state == "executed" then
    data_store.record_execution(file_path, line)
  else
    -- For "covered" state (assertions), track separately
    data_store.record_coverage(file_path, line)
    tracking_state.assertion_coverage[original_path][line] = true
  end

  logger.debug("Tracked line execution", {
    file = original_path,
    line = line,
    state = state
  })

  return true
end
-- Start tracking
---@return boolean success Whether tracking was started successfully
---@return string? error Error message if start failed
function M.start()
  if is_active then
    return true
  end

  logger.debug("Starting coverage tracking")
  is_active = true
  return true
end

-- Stop tracking
---@return boolean success Whether tracking was stopped successfully
---@return string? error Error message if stop failed
function M.stop()
  if not is_active then
    return true
  end

  logger.debug("Stopping coverage tracking")
  is_active = false
  return true
end
-- Reset tracking data
---@return boolean success Whether data was reset successfully
---@return string? error Error message if reset failed
function M.reset()
  logger.debug("Resetting coverage tracking data")
  data_store.reset()
  
  -- Reset local tracking state too
  tracking_state = {
    processed_lines = {},
    assertion_coverage = {}
  }
  
  return true
end

-- Get current tracking data
---@return table data The current tracking data with enhanced stats
function M.get_data()
  local coverage_data = data_store.get_data()
  
  -- Enhance the data with additional tracking information
  local result = {
    coverage = coverage_data,
    meta = {
      processed_lines_count = 0,
      assertion_coverage_count = 0,
      files_count = 0
    }
  }
  
  -- Calculate metadata
  for file_path, lines in pairs(tracking_state.processed_lines) do
    result.meta.files_count = result.meta.files_count + 1
    
    for line, _ in pairs(lines) do
      result.meta.processed_lines_count = result.meta.processed_lines_count + 1
    end
  end
  
  -- Count assertion coverage
  for file_path, lines in pairs(tracking_state.assertion_coverage) do
    for line, _ in pairs(lines) do
      result.meta.assertion_coverage_count = result.meta.assertion_coverage_count + 1
    end
  end
  
  return result
end

-- Validate the current tracking state
---@return boolean is_valid Whether the tracking state is valid
---@return string? error Error message if validation failed
function M.validate_state()
  local issues = {}
  
  -- Validate processed lines match data store
  local coverage_data = data_store.get_data()
  
  for file_path, lines in pairs(tracking_state.processed_lines) do
    if not coverage_data[file_path] then
      table.insert(issues, "File in tracking state not found in data store: " .. file_path)
    else
      for line_num, _ in pairs(lines) do
        if not coverage_data[file_path][line_num] then
          table.insert(issues, string.format("Line %d in file %s tracked but not in data store", line_num, file_path))
        end
      end
    end
  end
  
  -- Validate assertion coverage is consistent
  for file_path, lines in pairs(tracking_state.assertion_coverage) do
    if not coverage_data[file_path] then
      table.insert(issues, "File in assertion tracking not found in data store: " .. file_path)
    else
      for line_num, _ in pairs(lines) do
        if not coverage_data[file_path][line_num] then
          table.insert(issues, string.format("Assertion line %d in file %s tracked but not in data store", line_num, file_path))
        elseif coverage_data[file_path][line_num].state ~= "covered" then
          table.insert(issues, string.format("Line %d in file %s marked as assertion but state is not 'covered'", line_num, file_path))
        end
      end
    end
  end
  
  if #issues > 0 then
    return false, "Tracking state validation failed: " .. table.concat(issues, "; ")
  end
  
  return true
}

return M
