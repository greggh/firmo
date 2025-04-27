--- LCOV Formatter for Coverage Reports
---
--- Generates coverage reports in the LCOV tracefile format, commonly used by
--- tools like GenHTML. Inherits from the base Formatter.
---
--- @module lib.reporting.formatters.lcov
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

--- @class CoverageReportFileStats Simplified structure expected by this formatter.
--- @field lines table<number|string, CoverageLineEntry> Map of line number to line data.
--- @field functions? table<string, CoverageFunctionEntry> Optional map of function IDs to function data.
--- @field executable_lines? number Total executable lines in the file.
--- @field covered_lines? number Total covered lines in the file.
--- @field total_functions? number Total functions in the file.
--- @field covered_functions? number Total covered functions in the file.

--- @class CoverageLineEntry Simplified structure expected by this formatter.
--- @field execution_count? number Number of times the line was hit.
--- @field executable? boolean Whether the line is executable.

--- @class CoverageFunctionEntry Simplified structure expected by this formatter.
--- @field name string Function name.
--- @field start_line number Start line of the function.
--- @field execution_count? number Number of times the function was called.

--- @class CoverageReportData Expected structure for coverage data input (simplified).
--- @field files table<string, CoverageReportFileStats> Map of file paths to file statistics.

---@class LCOVFormatter : Formatter LCOV Formatter for coverage reports.
--- Generates coverage reports in the LCOV tracefile format, commonly used by
--- tools like GenHTML.
---@field _VERSION string Module version.
---@field validate fun(self: LCOVFormatter, coverage_data: CoverageReportData): boolean, string? Validates coverage data, ensuring the 'files' section exists. Returns `true` or `false, error_message`.
---@field format fun(self: LCOVFormatter, coverage_data: CoverageReportData, options?: { include_functions?: boolean }): string|nil, table? Formats coverage data as an LCOV string. Returns `lcov_string, nil` or `nil, error`.
---@field write fun(self: LCOVFormatter, lcov_content: string, output_path: string, options?: table): boolean, table? Writes the LCOV content to a file. Returns `true, nil` or `false, error`. @throws table If writing fails critically.
---@field register fun(formatters: table): boolean, table? Registers the LCOV formatter with the main registry. Returns `true, nil` or `false, error`. @throws table If validation fails.

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the success handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

local Formatter = try_require("lib.reporting.formatters.base")

-- Create LCOV formatter class
local LCOVFormatter = Formatter.extend("lcov", "lcov")

--- LCOV Formatter version
LCOVFormatter._VERSION = "1.0.0"

--- Validates the coverage data structure for LCOV format.
--- Ensures the base validation passes and the `files` section exists.
---@param self LCOVFormatter The formatter instance.
---@param coverage_data CoverageReportData The coverage data to validate.
---@return boolean success `true` if validation passes.
---@return string? error_message Error message string if validation failed.
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

--- Formats coverage data into an LCOV tracefile string.
---@param self LCOVFormatter The formatter instance.
---@param coverage_data CoverageReportData The coverage data structure (expects `files`, `files[].functions`, `files[].lines`, etc.).
---@param options? { include_functions?: boolean } Formatting options:
---  - `include_functions` (boolean, default true): Include function coverage sections (FN, FNDA, FNF, FNH).
---@return string|nil lcov_content The generated LCOV content as a single string, or `nil` on validation error.
---@return table? error Error object if validation failed.
function LCOVFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, get_error_handler().validation_error("Coverage data is required", { formatter = self.name })
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

--- Writes the generated LCOV content to a file.
--- Inherits the write logic (including directory creation) from the base `Formatter`.
---@param self LCOVFormatter The formatter instance.
---@param lcov_content string The LCOV content string to write.
---@param output_path string The path to the output file.
---@param options? table Optional options passed to the base `write` method (currently unused by base).
---@return boolean success `true` if writing succeeded.
---@return table? error Error object if writing failed.
---@throws table If writing fails critically.
function LCOVFormatter:write(lcov_content, output_path, options)
  return Formatter.write(self, lcov_content, output_path, options)
end

--- Registers the LCOV formatter with the main formatters registry.
---@param formatters table The main formatters registry object (must contain `coverage` table).
---@return boolean success `true` if registration succeeded.
---@return table? error Error object if validation failed.
---@throws table If validation fails critically.
function LCOVFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    local err = get_error_handler().validation_error("Invalid formatters registry", {
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
