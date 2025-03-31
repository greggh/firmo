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
  if not line or type(line) ~= "number" then
    return false, error_handler.validation_error(
      "Invalid line number",
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

  -- Record execution in data store
  if state == "executed" then
    data_store.record_execution(file_path, line)
  else
    data_store.record_coverage(file_path, line)
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
  return true
end

-- Get current tracking data
---@return table data The current tracking data
function M.get_data()
  return data_store.get_data()
end

return M