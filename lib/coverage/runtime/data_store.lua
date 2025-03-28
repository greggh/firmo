---@class CoverageDataStore
---@field create fun(): table Create a new coverage data store
---@field add_execution fun(data: table, file_id: string, line_number: number) Add an execution record
---@field add_coverage fun(data: table, file_id: string, line_number: number) Add a coverage record
---@field get_execution_count fun(data: table, file_id: string, line_number: number): number Get the execution count for a line
---@field is_covered fun(data: table, file_id: string, line_number: number): boolean Check if a line is covered
---@field get_file_data fun(data: table, file_id: string): table Get data for a specific file
---@field register_file fun(data: table, file_id: string, file_path: string) Register a file in the data store
---@field calculate_summary fun(data: table): table Calculate summary statistics
---@field merge fun(data1: table, data2: table): table Merge two data stores
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

-- Version
M._VERSION = "0.1.0"

-- Coverage status constants
M.STATUS = {
  NOT_COVERED = "not_covered",
  EXECUTED = "executed",
  COVERED = "covered"
}

-- Create a new coverage data store
---@return table data The new coverage data store
function M.create()
  return {
    -- Execution data indexed by file_id and line number
    execution_data = {},
    
    -- Coverage data indexed by file_id and line number
    coverage_data = {},
    
    -- File map that associates file_id with file_path
    file_map = {},
    
    -- Source maps
    sourcemaps = {},
    
    -- Summary statistics
    summary = {
      total_files = 0,
      covered_files = 0,
      executed_files = 0,
      file_coverage_percent = 0,
      
      total_lines = 0,
      executable_lines = 0,
      executed_lines = 0,
      covered_lines = 0,
      line_coverage_percent = 0,
      execution_coverage_percent = 0
    }
  }
end

-- Register a file in the data store
---@param data table The coverage data store
---@param file_id string The unique identifier for the file
---@param file_path string The path to the file
function M.register_file(data, file_id, file_path)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Create the file map if it doesn't exist
  if not data.file_map then
    data.file_map = {}
  end
  
  -- Register mappings in both directions
  data.file_map[file_id] = file_path
  data.file_map[file_path] = file_id
  
  -- Initialize data structures for this file
  if not data.execution_data[file_id] then
    data.execution_data[file_id] = {}
  end
  
  if not data.coverage_data[file_id] then
    data.coverage_data[file_id] = {}
  end
  
  -- Update file count
  data.summary.total_files = data.summary.total_files + 1
end

-- Add an execution record
---@param data table The coverage data store
---@param file_id string The unique identifier for the file
---@param line_number number The line number that was executed
function M.add_execution(data, file_id, line_number)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(line_number) == "number", "line_number must be a number", error_handler.CATEGORY.VALIDATION)
  
  -- Initialize data structures if needed
  if not data.execution_data[file_id] then
    data.execution_data[file_id] = {}
  end
  
  -- Increment execution count
  data.execution_data[file_id][line_number] = (data.execution_data[file_id][line_number] or 0) + 1
end

-- Add a coverage record
---@param data table The coverage data store
---@param file_id string The unique identifier for the file
---@param line_number number The line number that was covered
function M.add_coverage(data, file_id, line_number)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(line_number) == "number", "line_number must be a number", error_handler.CATEGORY.VALIDATION)
  
  -- Initialize data structures if needed
  if not data.execution_data[file_id] then
    data.execution_data[file_id] = {}
  end
  
  if not data.coverage_data[file_id] then
    data.coverage_data[file_id] = {}
  end
  
  -- Increment execution count
  data.execution_data[file_id][line_number] = (data.execution_data[file_id][line_number] or 0) + 1
  
  -- Mark as covered
  data.coverage_data[file_id][line_number] = true
end

-- Get the execution count for a line
---@param data table The coverage data store
---@param file_id string The unique identifier for the file
---@param line_number number The line number to check
---@return number count The execution count (0 if not executed)
function M.get_execution_count(data, file_id, line_number)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(line_number) == "number", "line_number must be a number", error_handler.CATEGORY.VALIDATION)
  
  -- Check if the file exists in the data store
  if not data.execution_data[file_id] then
    return 0
  end
  
  -- Return execution count (0 if not executed)
  return data.execution_data[file_id][line_number] or 0
end

-- Check if a line is covered
---@param data table The coverage data store
---@param file_id string The unique identifier for the file
---@param line_number number The line number to check
---@return boolean is_covered Whether the line is covered
function M.is_covered(data, file_id, line_number)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(line_number) == "number", "line_number must be a number", error_handler.CATEGORY.VALIDATION)
  
  -- Check if the file exists in the data store
  if not data.coverage_data[file_id] then
    return false
  end
  
  -- Return coverage status
  return data.coverage_data[file_id][line_number] or false
end

-- Get coverage status for a line
---@param data table The coverage data store
---@param file_id string The unique identifier for the file
---@param line_number number The line number to check
---@return string status The coverage status (not_covered, executed, covered)
function M.get_line_status(data, file_id, line_number)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(line_number) == "number", "line_number must be a number", error_handler.CATEGORY.VALIDATION)
  
  local execution_count = M.get_execution_count(data, file_id, line_number)
  local is_covered = M.is_covered(data, file_id, line_number)
  
  if is_covered then
    return M.STATUS.COVERED
  elseif execution_count > 0 then
    return M.STATUS.EXECUTED
  else
    return M.STATUS.NOT_COVERED
  end
end

-- Get a file path from a file ID
---@param data table The coverage data store
---@param file_id string The unique identifier for the file
---@return string|nil file_path The file path or nil if not found
function M.get_file_path(data, file_id)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Check if file map exists
  if not data.file_map then
    return nil
  end
  
  -- Direct lookup
  local file_path = data.file_map[file_id]
  if file_path and type(file_path) == "string" and not file_path:match("^file_") then
    return file_path
  end
  
  -- Reverse lookup
  for path, id in pairs(data.file_map) do
    if type(path) == "string" and not path:match("^file_") and id == file_id then
      return path
    end
  end
  
  return nil
end

-- Get data for a specific file
---@param data table The coverage data store
---@param file_id string The unique identifier for the file
---@return table|nil file_data The file data or nil if not found
function M.get_file_data(data, file_id)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Check if the file exists in the data store
  if not data.execution_data[file_id] and not data.coverage_data[file_id] then
    return nil
  end
  
  -- Get file path from file map
  ---@diagnostic disable-next-line: redundant-parameter
  local file_path = M.get_file_path(data, file_id) or file_id
  
  -- Get file content if available
  local content = nil
  if file_path and fs.file_exists(file_path) then
    local read_success, read_content, err = pcall(function() 
      return fs.read_file(file_path)
    end)
    
    if read_success and read_content then
      content = read_content
      logger.debug("Successfully read source file content", {
        file_path = file_path,
        content_length = #content
      })
    else
      logger.warn("Failed to read source file", {
        file_path = file_path,
        error = err and tostring(err) or "Unknown error"
      })
    end
  end
  
  -- Analyze the file data
  local file_data = {
    file_id = file_id, -- Store the file ID for reference
    file_path = file_path or file_id, -- Use ID as fallback if path not available
    content = content,
    lines = {},
    summary = {
      total_lines = 0,
      executable_lines = 0,
      executed_lines = 0,
      covered_lines = 0,
      execution_coverage_percent = 0,
      line_coverage_percent = 0
    }
  }
  
  -- Determine the total number of lines
  local total_lines = 0
  if content then
    for _ in content:gmatch("\n") do
      total_lines = total_lines + 1
    end
    total_lines = total_lines + 1  -- Add one for the last line
  else
    -- If content is not available, determine from execution data
    for line_number, _ in pairs(data.execution_data[file_id] or {}) do
      total_lines = math.max(total_lines, line_number)
    end
  end
  
  file_data.summary.total_lines = total_lines
  
  -- Determine which lines are executable, executed, and covered
  local executable_lines = 0
  local executed_lines = 0
  local covered_lines = 0
  
  -- Get sourcemap if available
  local sourcemap = data.sourcemaps and data.sourcemaps[file_id]
  
  -- Process each line
  for line_number = 1, total_lines do
    local execution_count = M.get_execution_count(data, file_id, line_number)
    local is_covered = M.is_covered(data, file_id, line_number)
    
    -- Determine if the line is executable
    -- In instrumentation mode, we count a line as executable if:
    -- 1. It was executed at least once, OR
    -- 2. It contains actual code (not comments or empty lines)
    local is_executable = execution_count > 0
    
    -- For lines that weren't executed, check if they look like code
    if not is_executable and content then
      local line_content = ""
      local line_count = 0
      for l in content:gmatch("[^\r\n]+") do
        line_count = line_count + 1
        if line_count == line_number then
          line_content = l
          break
        end
      end
      
      -- Skip comments and empty lines
      local trimmed = line_content:gsub("^%s+", ""):gsub("%s+$", "")
      if trimmed ~= "" and not trimmed:match("^%-%-") then
        -- Check if it has Lua code patterns (e.g., keywords, function calls, etc.)
        if trimmed:match("function") or 
           trimmed:match("if%s+") or
           trimmed:match("for%s+") or
           trimmed:match("while%s+") or
           trimmed:match("return") or
           trimmed:match("local%s+") or
           trimmed:match("end") or
           trimmed:match("=") then
          is_executable = true
        end
      end
    end
    
    if is_executable then
      executable_lines = executable_lines + 1
    end
    
    if execution_count > 0 then
      executed_lines = executed_lines + 1
    end
    
    if is_covered then
      covered_lines = covered_lines + 1
    end
    
    -- Extract line content from source if available
    local line_content = ""
    if content then
      -- More robust line extraction using gmatch
      local lines = {}
      local line_count = 0
      
      -- Split content into lines and store in array
      for line in content:gmatch("([^\r\n]*)[\r\n]?") do
        line_count = line_count + 1
        lines[line_count] = line
        
        -- Stop if we've reached our target line (optimization for large files)
        if line_count >= line_number then
          break
        end
      end
      
      -- Get the content for our target line
      if line_number <= line_count then
        line_content = lines[line_number] or ""
      end
      
      -- If we still don't have content, try the previous approach as a fallback
      if line_content == "" and line_number <= line_count then
        -- Fallback approach
        local start_pos = 1
        local current_line = 1
        
        -- Find the starting position of the target line
        while current_line < line_number and start_pos <= #content do
          local next_newline = content:find("[\r\n]", start_pos) or #content + 1
          start_pos = (content:sub(next_newline, next_newline + 1) == "\r\n") 
                      and (next_newline + 2) or (next_newline + 1)
          current_line = current_line + 1
        end
        
        -- Extract the line content
        if current_line == line_number and start_pos <= #content then
          local end_pos = content:find("[\r\n]", start_pos) or #content + 1
          line_content = content:sub(start_pos, end_pos - 1)
        end
      end
      
      logger.debug("Extracted line content", {
        file_id = file_id,
        line_number = line_number,
        content_length = #line_content
      })
    end
    
    -- Store line data
    file_data.lines[line_number] = {
      number = line_number,
      content = line_content,
      execution_count = execution_count,
      is_executable = is_executable,
      is_executed = execution_count > 0,
      is_covered = is_covered,
      status = M.get_line_status(data, file_id, line_number)
    }
  end
  
  -- Update summary
  file_data.summary.executable_lines = executable_lines
  file_data.summary.executed_lines = executed_lines
  file_data.summary.covered_lines = covered_lines
  
  -- Calculate percentages
  if executable_lines > 0 then
    file_data.summary.execution_coverage_percent = math.floor((executed_lines / executable_lines) * 100)
    file_data.summary.line_coverage_percent = math.floor((covered_lines / executable_lines) * 100)
  else
    file_data.summary.execution_coverage_percent = 0
    file_data.summary.line_coverage_percent = 0
  end
  
  return file_data
end

-- Calculate summary statistics
---@param data table The coverage data store
---@return table summary The updated summary statistics
function M.calculate_summary(data)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  
  -- Initialize summary
  local summary = {
    total_files = 0,
    covered_files = 0,
    executed_files = 0,
    file_coverage_percent = 0,
    
    total_lines = 0,
    executable_lines = 0,
    executed_lines = 0,
    covered_lines = 0,
    line_coverage_percent = 0,
    execution_coverage_percent = 0
  }
  
  -- Get all file IDs
  local file_ids = {}
  for file_id, _ in pairs(data.execution_data or {}) do
    file_ids[file_id] = true
  end
  for file_id, _ in pairs(data.coverage_data or {}) do
    file_ids[file_id] = true
  end
  
  -- Process each file
  for file_id, _ in pairs(file_ids) do
    -- Get file data
    local file_data = M.get_file_data(data, file_id)
    
    if file_data then
      -- Update file counts
      summary.total_files = summary.total_files + 1
      
      -- Update line counts
      summary.total_lines = summary.total_lines + file_data.summary.total_lines
      summary.executable_lines = summary.executable_lines + file_data.summary.executable_lines
      summary.executed_lines = summary.executed_lines + file_data.summary.executed_lines
      summary.covered_lines = summary.covered_lines + file_data.summary.covered_lines
      
      -- Log file data for diagnostics
      logger.info("Including file in coverage summary", {
        file_id = file_id,
        file_path = file_data.file_path,
        total_lines = file_data.summary.total_lines,
        executable_lines = file_data.summary.executable_lines,
        executed_lines = file_data.summary.executed_lines,
        covered_lines = file_data.summary.covered_lines
      })
      
      -- Update file execution and coverage counts
      if file_data.summary.executed_lines > 0 then
        summary.executed_files = summary.executed_files + 1
      end
      
      if file_data.summary.covered_lines > 0 then
        summary.covered_files = summary.covered_files + 1
      end
    end
  end
  
  -- Calculate percentages
  if summary.executable_lines > 0 then
    summary.execution_coverage_percent = math.floor((summary.executed_lines / summary.executable_lines) * 100)
    summary.line_coverage_percent = math.floor((summary.covered_lines / summary.executable_lines) * 100)
  else
    summary.execution_coverage_percent = 0
    summary.line_coverage_percent = 0
  end
  
  if summary.total_files > 0 then
    summary.file_coverage_percent = math.floor((summary.covered_files / summary.total_files) * 100)
  else
    summary.file_coverage_percent = 0
  end
  
  -- Update data store summary
  data.summary = summary
  
  return summary
end

-- Merge two data stores
---@param data1 table The first coverage data store
---@param data2 table The second coverage data store
---@return table merged_data The merged coverage data store
function M.merge(data1, data2)
  -- Parameter validation
  error_handler.assert(type(data1) == "table", "data1 must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(data2) == "table", "data2 must be a table", error_handler.CATEGORY.VALIDATION)
  
  -- Create a new data store
  local merged_data = M.create()
  
  -- Merge file maps
  for k, v in pairs(data1.file_map or {}) do
    merged_data.file_map[k] = v
  end
  for k, v in pairs(data2.file_map or {}) do
    merged_data.file_map[k] = v
  end
  
  -- Merge execution data
  for file_id, lines in pairs(data1.execution_data or {}) do
    merged_data.execution_data[file_id] = merged_data.execution_data[file_id] or {}
    for line_number, count in pairs(lines) do
      merged_data.execution_data[file_id][line_number] = (merged_data.execution_data[file_id][line_number] or 0) + count
    end
  end
  for file_id, lines in pairs(data2.execution_data or {}) do
    merged_data.execution_data[file_id] = merged_data.execution_data[file_id] or {}
    for line_number, count in pairs(lines) do
      merged_data.execution_data[file_id][line_number] = (merged_data.execution_data[file_id][line_number] or 0) + count
    end
  end
  
  -- Merge coverage data
  for file_id, lines in pairs(data1.coverage_data or {}) do
    merged_data.coverage_data[file_id] = merged_data.coverage_data[file_id] or {}
    for line_number, covered in pairs(lines) do
      merged_data.coverage_data[file_id][line_number] = merged_data.coverage_data[file_id][line_number] or covered
    end
  end
  for file_id, lines in pairs(data2.coverage_data or {}) do
    merged_data.coverage_data[file_id] = merged_data.coverage_data[file_id] or {}
    for line_number, covered in pairs(lines) do
      merged_data.coverage_data[file_id][line_number] = merged_data.coverage_data[file_id][line_number] or covered
    end
  end
  
  -- Merge sourcemaps
  for file_id, sourcemap in pairs(data1.sourcemaps or {}) do
    merged_data.sourcemaps[file_id] = sourcemap
  end
  for file_id, sourcemap in pairs(data2.sourcemaps or {}) do
    merged_data.sourcemaps[file_id] = sourcemap
  end
  
  -- Recalculate summary
  M.calculate_summary(merged_data)
  
  return merged_data
end

return M