---@class CoverageLcovFormatter
---@field generate fun(coverage_data: table, output_path: string): boolean, string|nil Generates an LCOV coverage report
---@field _VERSION string Version of this module
---@field format_coverage fun(coverage_data: table): string Formats coverage data as LCOV
---@field write_coverage_report fun(coverage_data: table, file_path: string): boolean, string|nil Writes coverage data to a file
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
-- Version
M._VERSION = "0.2.0"

--- Generates an LCOV coverage report
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
    output_path = output_path .. "coverage-report-v2.lcov"
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
  
  -- Build LCOV content
  local lcov_content = ""
  
  -- Sort files for consistent output
  local files = {}
  for path, file_data in pairs(coverage_data.files) do
    table.insert(files, { path = path, data = file_data })
  end
  
  table.sort(files, function(a, b) return a.path < b.path end)
  
  -- Generate LCOV records for each file
  for _, file in ipairs(files) do
    local file_data = file.data
    local path = file.path
    
    -- Start file section
    lcov_content = lcov_content .. "TN:" .. path .. "\n"
    lcov_content = lcov_content .. "SF:" .. path .. "\n"
    
    -- Add function records
    for func_id, func_data in pairs(file_data.functions) do
      -- Function name
      local func_name = func_data.name
      
      -- Function type annotation
      if func_data.type then
        func_name = func_name .. " [" .. func_data.type .. "]"
      end
      
      -- Function record
      lcov_content = lcov_content .. "FN:" .. func_data.start_line .. "," .. func_name .. "\n"
    end
    
    -- Add function hits
    for func_id, func_data in pairs(file_data.functions) do
      -- Function name
      local func_name = func_data.name
      
      -- Function type annotation
      if func_data.type then
        func_name = func_name .. " [" .. func_data.type .. "]"
      end
      
      -- Function execution count
      local count = 0
      if func_data.executed then
        count = func_data.execution_count > 0 and func_data.execution_count or 1
      end
      
      lcov_content = lcov_content .. "FNDA:" .. count .. "," .. func_name .. "\n"
    end
    
    -- Add total function information
    lcov_content = lcov_content .. "FNF:" .. file_data.total_functions .. "\n"
    lcov_content = lcov_content .. "FNH:" .. file_data.executed_functions .. "\n"
    
    -- Add line coverage information
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
    
    -- Line records
    for _, line_info in ipairs(sorted_lines) do
      local line_num = line_info.line_num
      local line_data = line_info.data
      
      -- Line record
      lcov_content = lcov_content .. "DA:" .. line_num .. "," .. line_data.execution_count .. "\n"
    end
    
    -- Add line summary
    lcov_content = lcov_content .. "LF:" .. file_data.executable_lines .. "\n"
    lcov_content = lcov_content .. "LH:" .. file_data.executed_lines .. "\n"
    
    -- End file section
    lcov_content = lcov_content .. "end_of_record\n"
  end
  
  -- Write the report to the output file
  local success, err = error_handler.safe_io_operation(
    function() 
      return fs.write_file(output_path, lcov_content)
    end,
    output_path,
    {operation = "write_lcov_report"}
  )
  
  if not success then
    return false, "Failed to write LCOV report: " .. error_handler.format_error(err)
  end
  
  logger.info("Generated LCOV coverage report", {
    output_path = output_path,
    total_files = coverage_data.summary.total_files,
    line_coverage = coverage_data.summary.line_coverage_percent .. "%",
    function_coverage = coverage_data.summary.function_coverage_percent .. "%"
  })
  
  return true
end

--- Formats coverage data as LCOV
---@param coverage_data table The coverage data
---@return string lcov_content LCOV content
function M.format_coverage(coverage_data)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  
  -- Check if summary is available
  if not coverage_data.summary then
    logger.warn("Coverage data does not contain summary data, returning empty LCOV content")
    return ""
  end
  
  -- Build LCOV content
  local lcov_content = ""
  
  -- Sort files for consistent output
  local files = {}
  for path, file_data in pairs(coverage_data.files) do
    table.insert(files, { path = path, data = file_data })
  end
  
  table.sort(files, function(a, b) return a.path < b.path end)
  
  -- Generate LCOV records for each file
  for _, file in ipairs(files) do
    local file_data = file.data
    local path = file.path
    
    -- Start file section
    lcov_content = lcov_content .. "TN:" .. path .. "\n"
    lcov_content = lcov_content .. "SF:" .. path .. "\n"
    
    -- Add function records
    for func_id, func_data in pairs(file_data.functions) do
      -- Function name
      local func_name = func_data.name
      
      -- Function type annotation
      if func_data.type then
        func_name = func_name .. " [" .. func_data.type .. "]"
      end
      
      -- Function record
      lcov_content = lcov_content .. "FN:" .. func_data.start_line .. "," .. func_name .. "\n"
    end
    
    -- Add function hits
    for func_id, func_data in pairs(file_data.functions) do
      -- Function name
      local func_name = func_data.name
      
      -- Function type annotation
      if func_data.type then
        func_name = func_name .. " [" .. func_data.type .. "]"
      end
      
      -- Function execution count
      local count = 0
      if func_data.executed then
        count = func_data.execution_count > 0 and func_data.execution_count or 1
      end
      
      -- Function execution record
      lcov_content = lcov_content .. "FNDA:" .. count .. "," .. func_name .. "\n"
    end
    
    -- Add function summary
    lcov_content = lcov_content .. "FNF:" .. file_data.total_functions .. "\n"
    lcov_content = lcov_content .. "FNH:" .. file_data.executed_functions .. "\n"
    
    -- Add line records
    for line_num, line_data in pairs(file_data.lines) do
      -- Only include executable lines
      if line_data.executable then
        -- Line execution count
        local count = 0
        if line_data.executed then
          count = line_data.execution_count > 0 and line_data.execution_count or 1
        end
        
        -- Line execution record
        lcov_content = lcov_content .. "DA:" .. line_num .. "," .. count .. "\n"
      end
    end
    
    -- Add line summary
    lcov_content = lcov_content .. "LF:" .. file_data.executable_lines .. "\n"
    lcov_content = lcov_content .. "LH:" .. file_data.executed_lines .. "\n"
    
    -- End file section
    lcov_content = lcov_content .. "end_of_record\n"
  end
  
  return lcov_content
end

--- Writes coverage data to a file in LCOV format
---@param coverage_data table The coverage data
---@param file_path string The path to write the file to
---@return boolean success Whether the write was successful
---@return string|nil error_message Error message if write failed
function M.write_coverage_report(coverage_data, file_path)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Format the data
  local lcov = M.format_coverage(coverage_data)
  
  -- Write to file
  local success, err = error_handler.safe_io_operation(
    function() 
      return fs.write_file(file_path, lcov)
    end,
    file_path,
    {operation = "write_lcov_report"}
  )
  
  if not success then
    return false, "Failed to write LCOV report: " .. error_handler.format_error(err)
  end
  
  logger.info("Wrote LCOV coverage report", {
    file_path = file_path,
    size = #lcov,
    total_files = coverage_data.summary.total_files,
    line_coverage = coverage_data.summary.line_coverage_percent .. "%"
  })
  
  return true
end

return M