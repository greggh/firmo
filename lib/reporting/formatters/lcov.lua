--- LCOV Formatter for Coverage Reports
-- Generates LCOV format coverage reports for code coverage tools
-- @module reporting.formatters.lcov
-- @author Firmo Team

local Formatter = require("lib.reporting.formatters.base")
local error_handler = require("lib.tools.error_handler")
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

  -- LCOV-specific validation
  if not coverage_data.files then
    return false, "Coverage data missing files section"
  end

  return true
end

-- Format coverage data as LCOV
function LCOVFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, error_handler.validation_error("Coverage data is required", { formatter = self.name })
  end

  -- Apply options with defaults
  options = options or {}
  options.include_functions = options.include_functions ~= false -- Default to true

  -- Initialize output lines
  local lines = {}

  -- Sort files for consistent output
  local files = {}
  for filename in pairs(coverage_data.files) do
    table.insert(files, filename)
  end
  table.sort(files)

  -- Process each file
  for _, filename in ipairs(files) do
    local file_data = coverage_data.files[filename]

    -- Add file record
    table.insert(lines, "TN:") -- Test name (optional)
    table.insert(lines, "SF:" .. filename)

    -- Add function coverage if available and enabled
    if options.include_functions and file_data.functions then
      local functions = {}
      -- Collect functions and sort by start line for consistent output
      for func_id, func in pairs(file_data.functions) do
        if type(func) == "table" then
          table.insert(functions, func)
        end
      end

      table.sort(functions, function(a, b)
        return (a.start_line or 0) < (b.start_line or 0)
      end)

      -- Function declarations
      for _, func in ipairs(functions) do
        if func.name and func.start_line then
          table.insert(lines, string.format("FN:%d,%s", func.start_line, func.name))
        end
      end

      -- Function execution counts
      for _, func in ipairs(functions) do
        if func.name and func.execution_count then
          table.insert(lines, string.format("FNDA:%d,%s", func.execution_count, func.name))
        end
      end

      -- Function summary
      table.insert(lines, string.format("FNF:%d", file_data.total_functions or 0))
      table.insert(lines, string.format("FNH:%d", file_data.covered_functions or 0))
    end

    -- Add line coverage data
    local line_list = {}

    -- Collect line numbers and sort them for consistent output
    for line_num, line_data in pairs(file_data.lines) do
      if type(line_num) == "number" then
        local execution_count = 0
        if type(line_data) == "table" then
          execution_count = line_data.execution_count or 0
        elseif type(line_data) == "number" then
          execution_count = line_data
        end

        if line_data.executable or execution_count > 0 then
          table.insert(line_list, {
            line = line_num,
            count = execution_count,
          })
        end
      end
    end

    table.sort(line_list, function(a, b)
      return a.line < b.line
    end)

    -- Add line records
    for _, line_info in ipairs(line_list) do
      table.insert(lines, string.format("DA:%d,%d", line_info.line, line_info.count))
    end

    -- Line coverage summary
    table.insert(lines, string.format("LF:%d", file_data.executable_lines or 0))
    table.insert(lines, string.format("LH:%d", file_data.covered_lines or 0))

    -- End of record
    table.insert(lines, "end_of_record")
  end

  return table.concat(lines, "\n") .. "\n"
end

-- Write LCOV output to file
function LCOVFormatter:write(lcov_content, output_path, options)
  return Formatter.write(self, lcov_content, output_path, options)
end

--- Register the LCOV formatter with the formatters registry
-- @param formatters table The formatters registry
-- @return boolean success Whether registration was successful
function LCOVFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    local err = error_handler.validation_error("Invalid formatters registry", {
      operation = "register",
      formatter = "lcov",
      provided_type = type(formatters),
    })
    return false, err
  end

  -- Create a new instance of the formatter
  local formatter = LCOVFormatter.new()

  -- Register format_coverage function
  formatters.coverage.lcov = function(coverage_data, options)
    return formatter:format(coverage_data, options)
  end

  return true
end

return LCOVFormatter
