--- LCOV Formatter for Coverage Reports
-- Generates LCOV format coverage reports
-- @module coverage.report.lcov
-- @author Firmo Team

local Formatter = require("lib.coverage.report.formatter")
local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")

-- Create LCOV formatter class
local LCOVFormatter = Formatter.extend("lcov", "lcov")

--- LCOV Formatter version
LCOVFormatter._VERSION = "1.0.0"

-- Validate coverage data structure for LCOV formatter
function LCOVFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end
  
  -- Additional LCOV-specific validation
  -- LCOV requires files with line and function data
  if not coverage_data.files or not next(coverage_data.files) then
    return false, error_handler.validation_error(
      "Coverage data must contain file information for LCOV format",
      { formatter = self.name }
    )
  end
  
  return true
end

-- Format coverage data as LCOV
function LCOVFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, error_handler.validation_error("Coverage data is required", {formatter = self.name})
  end
  
  -- Apply options with defaults
  options = options or {}
  options.base_dir = options.base_dir or ""
  options.relative_paths = options.relative_paths ~= false  -- Default to true
  
  -- Normalize the coverage data
  local normalized_data = self:normalize_coverage_data(coverage_data)
  
  -- Begin building LCOV content
  local lcov_content = self:build_lcov(normalized_data, options)
  
  return lcov_content
end

-- Build LCOV format content
function LCOVFormatter:build_lcov(data, options)
  local lines = {}
  
  -- Add LCOV header
  table.insert(lines, "TN:Firmo Coverage Report")
  
  -- Process each file
  local sorted_files = {}
  for path, file_data in pairs(data.files) do
    table.insert(sorted_files, { path = path, data = file_data })
  end
  
  table.sort(sorted_files, function(a, b) return a.path < b.path end)
  
  for _, file in ipairs(sorted_files) do
    local path = file.path
    local file_data = file.data
    
    -- Format path based on options
    local formatted_path = self:format_path(path, options)
    
    -- Start file section
    table.insert(lines, "SF:" .. formatted_path)
    
    -- Process functions
    local function_list = {}
    local functions_found = 0
    local functions_hit = 0
    
    if file_data.functions then
      -- Sort functions by line number for consistent output
      local sorted_functions = {}
      for name, func_data in pairs(file_data.functions) do
        table.insert(sorted_functions, {
          name = name,
          start_line = func_data.start_line or 0,
          executed = func_data.executed or false,
          hit = func_data.execution_count or 0
        })
        
        functions_found = functions_found + 1
        if func_data.executed or (func_data.execution_count and func_data.execution_count > 0) then
          functions_hit = functions_hit + 1
        end
      end
      
      table.sort(sorted_functions, function(a, b) return a.start_line < b.start_line end)
      
      -- Add function information
      for _, func in ipairs(sorted_functions) do
        -- FN:<line number>,<function name>
        table.insert(lines, "FN:" .. func.start_line .. "," .. func.name)
        
        -- FNDA:<execution count>,<function name>
        table.insert(lines, "FNDA:" .. func.hit .. "," .. func.name)
      end
    end
    
    -- Add function summary
    table.insert(lines, "FNF:" .. functions_found)  -- Functions found
    table.insert(lines, "FNH:" .. functions_hit)    -- Functions hit
    
    -- Process lines
    local lines_found = 0
    local lines_hit = 0
    
    if file_data.lines then
      -- Sort line numbers for consistent output
      local line_numbers = {}
      for line_num, _ in pairs(file_data.lines) do
        table.insert(line_numbers, tonumber(line_num))
      end
      
      table.sort(line_numbers)
      
      -- Add line information
      for _, line_num in ipairs(line_numbers) do
        local line_data = file_data.lines[tostring(line_num)]
        local execution_count = line_data.execution_count or 0
        
        -- DA:<line number>,<execution count>[,<checksum>]
        table.insert(lines, "DA:" .. line_num .. "," .. execution_count)
        
        lines_found = lines_found + 1
        if line_data.covered or line_data.executed or execution_count > 0 then
          lines_hit = lines_hit + 1
        end
      end
    end
    
    -- Add line summary
    table.insert(lines, "LF:" .. lines_found)  -- Lines found
    table.insert(lines, "LH:" .. lines_hit)    -- Lines hit
    
    -- End file section
    table.insert(lines, "end_of_record")
  end
  
  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

-- Format file path according to LCOV requirements
function LCOVFormatter:format_path(path, options)
  if not path then
    return "unknown"
  end
  
  -- Convert backslashes to forward slashes for consistency
  path = path:gsub("\\", "/")
  
  -- Handle relative paths if configured
  if options.relative_paths and options.base_dir and options.base_dir ~= "" then
    local base_dir = options.base_dir:gsub("\\", "/")
    
    -- Ensure base_dir ends with a slash
    if not base_dir:match("/$") then
      base_dir = base_dir .. "/"
    end
    
    -- If path starts with base_dir, remove it
    if path:sub(1, #base_dir) == base_dir then
      path = path:sub(#base_dir + 1)
    end
  end
  
  return path
end

-- Write the report to the filesystem
function LCOVFormatter:write(lcov_content, output_path, options)
  return Formatter.write(self, lcov_content, output_path, options)
end

return LCOVFormatter

