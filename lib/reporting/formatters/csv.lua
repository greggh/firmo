--- CSV Formatter for Coverage Reports
---
--- Generates CSV format coverage reports with configurable columns, supporting
--- both file-level summaries and detailed line-level output. Inherits from the base Formatter.
---
--- @module lib.reporting.formatters.csv
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

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

---@class CSVFormatter : Formatter CSV Formatter for coverage reports.
--- Generates CSV reports at either file or line level, with configurable columns.
---@field _VERSION string Module version.
---@field DEFAULT_FILE_COLUMNS table Default column configuration for file-level reports. Structure: `{ {name = string, field = string, format? = string}, ... }`.
---@field DEFAULT_LINE_COLUMNS table Default column configuration for line-level reports. Structure: `{ {name = string, field = string, format? = string}, ... }`.
---@field validate fun(self: CSVFormatter, coverage_data: table): boolean, table? Validates coverage data. Returns `true` or `false, error`.
---@field format fun(self: CSVFormatter, coverage_data: table, options?: { include_header?: boolean, separator?: string, level?: "file"|"line", columns?: table[], include_summary?: boolean }): string|nil, table? Formats coverage data as a CSV string. Returns `csv_string, nil` or `nil, error`. @throws table If validation fails.
---@field build_file_level_csv fun(self: CSVFormatter, data: table, options: table): string Builds the CSV content for file-level report. Returns CSV string.
---@field build_line_level_csv fun(self: CSVFormatter, data: table, options: table): string Builds the CSV content for line-level report. Returns CSV string.
---@field escape_csv_field fun(self: CSVFormatter, value: any): string Escapes a value for safe inclusion in a CSV field. Returns escaped string.
---@field get_nested_field fun(self: CSVFormatter, data: table, field_path: string): any Retrieves a value from a nested table using a dot-separated path. Returns value or nil.
---@field write fun(self: CSVFormatter, csv_content: string, output_path: string, options?: table): boolean, table? Writes the CSV content to a file. Returns `true, nil` or `false, error`. @throws table If writing fails critically.
---@field register fun(formatters: table): boolean, table? Registers the CSV formatter with the main registry. Returns `true, nil` or `false, error`. @throws table If validation fails.

-- Create CSV formatter class
local CSVFormatter = Formatter.extend("csv", "csv")

--- CSV Formatter version
CSVFormatter._VERSION = "1.0.0"

--- Default column configuration for file-level reports.
--- `name` is the header, `field` is the dot-path to the value in the file data, `format` is an optional sprintf pattern.
CSVFormatter.DEFAULT_FILE_COLUMNS = {
  { name = "File", field = "path" },
  { name = "Lines", field = "summary.total_lines" },
  { name = "Covered Lines", field = "summary.covered_lines" },
  { name = "Executed Lines", field = "summary.executed_lines" },
  { name = "Not Covered Lines", field = "summary.not_covered_lines" },
  { name = "Coverage %", field = "summary.coverage_percent", format = "%.2f" },
  { name = "Execution %", field = "summary.execution_percent", format = "%.2f" },
}

--- Default column configuration for line-level reports.
--- `name` is the header, `field` is the key in the line record, `format` is optional sprintf pattern.
CSVFormatter.DEFAULT_LINE_COLUMNS = {
  { name = "File", field = "file" },
  { name = "Line", field = "line" },
  { name = "Executed", field = "executed" },
  { name = "Covered", field = "covered" },
  { name = "Execution Count", field = "execution_count" },
  { name = "Content", field = "content" },
}

--- Validates the coverage data structure. Inherits base validation.
---@param self CSVFormatter The formatter instance.
---@param coverage_data table The coverage data to validate.
---@return boolean success `true` if validation passes.
---@return table? error Error object if validation fails.
function CSVFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end

  -- Additional CSV-specific validation if needed

  return true
end

--- Formats coverage data into a CSV string based on the specified options.
--- Can generate file-level or line-level reports.
---@param self CSVFormatter The formatter instance.
---@param coverage_data table The coverage data (expected structure depends on level, uses normalized data).
---@param options? { include_header?: boolean, separator?: string, level?: "file"|"line", columns?: table[], include_summary?: boolean } Formatting options:
---  - `include_header` (boolean, default true): Include header row.
---  - `separator` (string, default ","): Field separator.
---  - `level` ("file"|"line", default "file"): Level of detail.
---  - `columns` (table[]): Array of column definitions (see `DEFAULT_*_COLUMNS`). Defaults based on `level`.
---  - `include_summary` (boolean, file level only): Add a summary row at the end.
---@return string|nil csv_content The generated CSV content as a single string, or `nil` on validation error.
---@return table? error Error object if validation failed.
---@throws table If `coverage_data` validation fails critically.
function CSVFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, get_error_handler().validation_error("Coverage data is required", { formatter = self.name })
  end

  -- Apply options with defaults
  options = options or {}
  options.include_header = options.include_header ~= false -- Default to true
  options.separator = options.separator or ","
  options.level = options.level or "file" -- "file" or "line"
  options.columns = options.columns
    or (options.level == "line" and self.DEFAULT_LINE_COLUMNS or self.DEFAULT_FILE_COLUMNS)

  -- Normalize the coverage data
  local normalized_data = self:normalize_coverage_data(coverage_data)

  -- Begin building CSV content
  local csv_content

  if options.level == "line" then
    csv_content = self:build_line_level_csv(normalized_data, options)
  else
    csv_content = self:build_file_level_csv(normalized_data, options)
  end

  return csv_content
end

--- Builds the CSV content string for a file-level report.
---@param self CSVFormatter The formatter instance.
---@param data table The normalized coverage data (requires `files` table, optionally `summary`).
---@param options table Formatting options including `include_header`, `separator`, `columns`, `include_summary`.
---@return string csv_content The generated CSV content.
function CSVFormatter:build_file_level_csv(data, options)
  local lines = {}
  local separator = options.separator or ","
  local columns = options.columns or self.DEFAULT_FILE_COLUMNS

  -- Add header if configured
  if options.include_header then
    local header_cells = {}
    for _, column in ipairs(columns) do
      table.insert(header_cells, self:escape_csv_field(column.name or ""))
    end
    table.insert(lines, table.concat(header_cells, separator))
  end

  -- Process each file
  local sorted_files = {}
  for path, file_data in pairs(data.files or {}) do
    -- Add path to the data for simpler lookup
    file_data.path = path
    table.insert(sorted_files, file_data)
  end

  -- Sort files by path for consistent output
  table.sort(sorted_files, function(a, b)
    return a.path < b.path
  end)

  -- Add each file as a row
  for _, file_data in ipairs(sorted_files) do
    local row_cells = {}

    -- Add each column's data
    for _, column in ipairs(columns) do
      local value = self:get_nested_field(file_data, column.field)

      -- Apply formatting if specified
      if column.format and type(value) == "number" then
        value = string.format(column.format, value)
      end

      -- Convert to string and escape
      value = self:escape_csv_field(tostring(value or ""))

      table.insert(row_cells, value)
    end

    table.insert(lines, table.concat(row_cells, separator))
  end

  -- Add summary row if configured
  if options.include_summary and data.summary then
    local summary_cells = {}

    -- First cell is "SUMMARY"
    summary_cells[1] = self:escape_csv_field("SUMMARY")

    -- Skip first column (file path) and add summary data for other columns
    for i = 2, #columns do
      local column = columns[i]
      local value = self:get_nested_field(data.summary, column.field:gsub("^summary%.", ""))

      -- Apply formatting if specified
      if column.format and type(value) == "number" then
        value = string.format(column.format, value)
      end

      -- Convert to string and escape
      value = self:escape_csv_field(tostring(value or ""))

      summary_cells[i] = value
    end

    table.insert(lines, table.concat(summary_cells, separator))
  end

  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

--- Builds the CSV content string for a line-level report.
---@param self CSVFormatter The formatter instance.
---@param data table The normalized coverage data (requires `files` table with `lines` and optionally `source`).
---@param options table Formatting options including `include_header`, `separator`, `columns`.
---@return string csv_content The generated CSV content.
function CSVFormatter:build_line_level_csv(data, options)
  local lines = {}
  local separator = options.separator or ","
  local columns = options.columns or self.DEFAULT_LINE_COLUMNS

  -- Add header if configured
  if options.include_header then
    local header_cells = {}
    for _, column in ipairs(columns) do
      table.insert(header_cells, self:escape_csv_field(column.name or ""))
    end
    table.insert(lines, table.concat(header_cells, separator))
  end

  -- Process each file
  local sorted_files = {}
  for path, file_data in pairs(data.files or {}) do
    table.insert(sorted_files, { path = path, data = file_data })
  end

  -- Sort files by path for consistent output
  table.sort(sorted_files, function(a, b)
    return a.path < b.path
  end)

  -- Process each file's lines
  for _, file in ipairs(sorted_files) do
    local path = file.path
    local file_data = file.data

    -- Skip if no line data
    if not file_data.lines or not next(file_data.lines) then
      goto continue
    end

    -- Get source content if available
    local source_content = {}
    if file_data.source then
      for line in file_data.source:gmatch("([^\n]*)\n?") do
        table.insert(source_content, line)
      end
    end

    -- Sort line numbers for consistent output
    local line_numbers = {}
    for line_num, _ in pairs(file_data.lines) do
      table.insert(line_numbers, tonumber(line_num))
    end

    table.sort(line_numbers)

    -- Add each line as a row
    for _, line_num in ipairs(line_numbers) do
      local line_data = file_data.lines[tostring(line_num)]
      local row_cells = {}

      -- Create line record with file path for column lookup
      local line_record = {
        file = path,
        line = line_num,
        executed = line_data.executed or false,
        covered = line_data.covered or false,
        execution_count = line_data.execution_count or 0,
        content = (source_content[line_num] or ""),
      }

      -- Add each column's data
      for _, column in ipairs(columns) do
        local value = self:get_nested_field(line_record, column.field)

        -- Apply formatting if specified
        if column.format and type(value) == "number" then
          value = string.format(column.format, value)
        elseif type(value) == "boolean" then
          value = value and "true" or "false"
        end

        -- Convert to string and escape
        value = self:escape_csv_field(tostring(value or ""))

        table.insert(row_cells, value)
      end

      table.insert(lines, table.concat(row_cells, separator))
    end

    ::continue::
  end

  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

--- Escapes a value to be safely included as a field in a CSV row.
--- Converts non-strings to strings. Wraps fields containing commas, quotes, or newlines in double quotes, and doubles any internal double quotes.
---@param self CSVFormatter The formatter instance.
---@param value any The value to escape.
---@return string escaped_value The escaped CSV field string.
function CSVFormatter:escape_csv_field(value)
  if value == nil then
    return ""
  end

  -- Convert to string if it's not already
  if type(value) ~= "string" then
    value = tostring(value)
  end

  -- Check if the value needs escaping
  local needs_escaping = value:match('[",%s\n\r]')

  if needs_escaping then
    -- Escape double quotes by doubling them
    value = value:gsub('"', '""')
    -- Wrap in quotes
    return '"' .. value .. '"'
  else
    return value
  end
end

--- Safely retrieves a potentially nested value from a table using a dot-separated path string.
---@param self CSVFormatter The formatter instance.
---@param data table The table to retrieve the value from.
---@param field_path string The dot-separated path (e.g., "summary.total_lines").
---@return any value The value found at the path, or `nil` if the path is invalid or the value doesn't exist.
function CSVFormatter:get_nested_field(data, field_path)
  if not data or not field_path then
    return nil
  end

  -- Split the field path by dots
  local parts = {}
  for part in field_path:gmatch("[^%.]+") do
    table.insert(parts, part)
  end

  -- Navigate through the data structure
  local current = data
  for _, part in ipairs(parts) do
    if type(current) ~= "table" then
      return nil
    end
    current = current[part]
    if current == nil then
      return nil
    end
  end

  return current
end

--- Writes the generated CSV content to a file.
--- Inherits the write logic (including directory creation) from the base `Formatter`.
---@param self CSVFormatter The formatter instance.
---@param csv_content string The CSV content to write.
---@param output_path string The path to the output file.
---@param options? table Optional options passed to the base `write` method (currently unused by base).
---@return boolean success `true` if writing succeeded.
---@return table? error Error object if writing failed.
---@throws table If writing fails critically.
function CSVFormatter:write(csv_content, output_path, options)
  return Formatter.write(self, csv_content, output_path, options)
end

--- Register the CSV formatter with the formatters registry
---@param formatters table The main formatters registry table (typically from `lib.reporting.formatters.init`).
---@return boolean success `true` if registration succeeded.
---@return table? error Error object if validation failed.
---@throws table If validation fails critically.
function CSVFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    local err = get_error_handler().validation_error("Invalid formatters registry", {
      operation = "register",
      formatter = "csv",
      provided_type = type(formatters),
    })
    return false, err
  end

  -- Create a new instance of the formatter
  local formatter = CSVFormatter.new()

  -- Register format_results function
  formatters.results.csv = function(results_data, options)
    return formatter:format(results_data, options)
  end

  return true
end

return CSVFormatter
