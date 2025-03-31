-- firmo v3 coverage module
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local instrumentation = require("lib.coverage.v3.instrumentation")
local test_helper = require("lib.tools.test_helper")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3")

---@class coverage_v3
---@field _VERSION string Module version
---@field start fun(): boolean, table? Start coverage tracking
---@field stop fun(): boolean, table? Stop coverage tracking and collect data
---@field reset fun(): boolean, table? Reset coverage data
---@field is_active fun(): boolean Check if coverage is active
---@field get_data fun(): table|nil, table? Get current coverage data
local M = {
  _VERSION = "3.0.0"
}

-- Track module state
local active = false
local data = nil
local temp_dir = nil

-- Start coverage tracking
---@return boolean success Whether tracking was started successfully
---@return table? error Error information if start failed
function M.start()
  if active then
    return true
  end

  logger.debug("Starting v3 coverage tracking")
  
  -- Create temp directory for instrumented files
  local dir, err = test_helper.create_temp_test_directory()
  if not dir then
    return false, error_handler.io_error(
      "Failed to create temp directory for coverage",
      {error = err}
    )
  end
  temp_dir = dir
  
  -- Initialize tracking components
  local tracker = require("lib.coverage.v3.runtime.tracker")
  local success, init_err = tracker.start()
  if not success then
    return false, init_err
  end
  
  active = true
  data = {}
  
  return true
end

-- Stop coverage tracking and collect data
---@return boolean success Whether tracking was stopped successfully
---@return table? error Error information if stop failed
function M.stop()
  if not active then
    return true
  end

  logger.debug("Stopping v3 coverage tracking")
  
  -- Stop tracking components
  local tracker = require("lib.coverage.v3.runtime.tracker")
  local success, stop_err = tracker.stop()
  if not success then
    return false, stop_err
  end
  
  -- Temp files will be cleaned up automatically by test_helper
  temp_dir = nil
  active = false
  
  return true
end

-- Reset coverage data
---@return boolean success Whether data was reset successfully
---@return table? error Error information if reset failed
function M.reset()
  logger.debug("Resetting v3 coverage data")
  
  -- Reset tracking components
  local tracker = require("lib.coverage.v3.runtime.tracker")
  local success, reset_err = tracker.reset()
  if not success then
    return false, reset_err
  end
  
  data = nil
  return true
end

-- Check if coverage is active
---@return boolean is_active Whether coverage tracking is active
function M.is_active()
  return active
end

-- Get current coverage data
---@return table|nil data The current coverage data, or nil if not available
---@return table? error Error information if data retrieval failed
function M.get_data()
  if not data then
    return nil, error_handler.validation_error(
      "No coverage data available",
      {reason = "Coverage tracking not started or no data collected"}
    )
  end
  
  -- Get data from runtime tracker
  local tracker = require("lib.coverage.v3.runtime.tracker")
  local tracker_data = tracker.get_data()
  
  -- Map temp file paths back to original paths
  for file_path, file_data in pairs(tracker_data) do
    -- TODO: Implement path mapping from temp files back to originals
    data[file_path] = file_data
  end
  
  return data
end

return M