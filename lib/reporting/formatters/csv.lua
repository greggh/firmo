--- CSV Formatter for Coverage Reports and Test Results
---
--- Generates CSV format reports with configurable columns, supporting
--- coverage reports (file-level or line-level) and test results. Inherits from the base Formatter.
---
--- @module lib.reporting.formatters.csv
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler
local central_config = try_require("lib.core.central_config")

--- Get the success handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

local Formatter = try_require("lib.reporting.formatters.base")

---@class CSVFormatter : Formatter CSV Formatter for coverage reports and test results.
--- Generates CSV reports for coverage data (file-level or line-level) and test results, with configurable columns.
---@field _VERSION string Module version.
---@field DEFAULT_FILE_COLUMNS table Default column configuration for file-level coverage reports. Structure: `{ {name = string, field = string, format? = string}, ... }`.
---@field DEFAULT_LINE_COLUMNS table Default column configuration for line-level coverage reports. Structure: `{ {name = string, field = string, format? = string}, ... }`.
---@field DEFAULT_TEST_COLUMNS table Default column configuration for test results reports. Structure: `{ {name = string, field = string, format? = string}, ... }`.
---@field validate fun(self: CSVFormatter, data: table): boolean, table? Validates input data. Returns `true` or `false, error`.
---@field format fun(self: CSVFormatter, data: table, options?: { include_header?: boolean, separator?: string, level?: "file"|"line", columns?: table[], include_summary?: boolean }): string|nil, table? Formats data as a CSV string. Returns `csv_string, nil` or `nil, error`. @throws table If validation fails.
---@field build_file_level_csv fun(self: CSVFormatter, data: table, options: table): string Builds the CSV content for file-level coverage report. Returns CSV string.
---@field build_line_level_csv fun(self: CSVFormatter, data: table, options: table): string Builds the CSV content for line-level coverage report. Returns CSV string.
---@field build_test_results_csv fun(self: CSVFormatter, data: table, options: table): string Builds the CSV content for test results report. Returns CSV string.
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
}

--- Default column configuration for line-level reports.
--- `name` is the header, `field` is the key in the line record, `format` is optional sprintf pattern.
CSVFormatter.DEFAULT_LINE_COLUMNS = {
  { name = "File", field = "file" },
  { name = "Line Number", field = "line" },
  { name = "Status", field = "status" },
}

--- Default column configuration for test results reports.
--- `name` is the header, `field` is the key or path in the test case record.
CSVFormatter.DEFAULT_TEST_COLUMNS = {
  { name = "test_id", field = "id" },
  { name = "test_suite", field = "classname" },
  { name = "test_name", field = "name" },
  { name = "status", field = "status" },
  { name = "duration", field = "time" },
  { name = "error_message", field = "error_message" }
}

--- Convert test data to standard status string
---@param test table The test case data
---@return string status The standardized status string
function CSVFormatter:get_test_status(test)
  if test.status then
    return test.status
  elseif test.failed then
    return "failed"
  elseif test.skipped then
    return "skipped"
  elseif test.pending then
    return "pending"
  else
    return "passed"
  end
end

--- Validates the input data structure. Inherits base validation.
---@param self CSVFormatter The formatter instance.
---@param data table The data to validate (either coverage data or test results).
---@return boolean success `true` if validation passes.
---@return table? error Error object if validation fails.
function CSVFormatter:validate(data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, data)
  if not valid then
    return false, err
  end

  -- Additional CSV-specific validation if needed

  return true
end

--- Formats data (coverage or test results) into a CSV string based on the specified options.
--- Can generate file-level coverage reports, line-level coverage reports, or test results reports.
---@param self CSVFormatter The formatter instance.
---@param data table The data to format (either coverage data or test results).
---@param options? { include_header?: boolean, separator?: string, delimiter?: string, level?: "file"|"line", columns?: table[], include_summary?: boolean } Formatting options:
---  - `include_header` (boolean, default true): Include header row.
---  - `separator` (string, default ","): Field separator.
---  - `delimiter` (string): Alias for separator (delimiter takes precedence if both are provided).
---  - `level` ("file"|"line", default "file"): Level of detail (for coverage data only).
---  - `columns` (table[]): Array of column definitions (see `DEFAULT_*_COLUMNS`). Defaults based on `level` or data type.
---  - `include_summary` (boolean, file level only): Add a summary row at the end.
---@return string|nil csv_content The generated CSV content as a single string, or `nil` on validation error.
---@return table? error Error object if validation failed.
---@throws table If data validation fails critically.
function CSVFormatter:format(data, options)
  -- Parameter validation
  if not data then
    return nil, get_error_handler().validation_error("Data is required", { formatter = self.name })
  end

  -- Get config first
  -- Get config first
  local config = central_config and central_config.get() or {}
  local csv_config = config.reporting and config.reporting.formatters and config.reporting.formatters.csv or {}

  -- Apply options with defaults, prioritizing passed options over config
  options = options or {}
  options.include_header = options.include_header ~= false -- Default to true
  
  -- Use delimiter from: 1) options.delimiter, 2) options.separator, 3) config.delimiter, 4) default ","
  local delimiter = options.delimiter or options.separator or csv_config.delimiter or ","
  -- Normalize delimiter to ensure it's always a string
  if type(delimiter) == "table" then
    delimiter = ","
    print("Warning: Delimiter provided as table, defaulting to comma")
  elseif type(delimiter) ~= "string" then
    delimiter = tostring(delimiter)
  end
  options.separator = delimiter

  -- Detect data type (test results vs coverage data)
  local is_test_results = data.test_cases ~= nil
  
  -- Set level for coverage data
  if not is_test_results then
    options.level = options.level or "file" -- "file" or "line"
  end
  
  -- Set appropriate columns based on data type and level
  options.columns = options.columns or (
    is_test_results 
    and self.DEFAULT_TEST_COLUMNS 
    or (options.level == "line" and self.DEFAULT_LINE_COLUMNS or self.DEFAULT_FILE_COLUMNS)
  )
  
  -- Begin building CSV content
  local csv_content
  
  if is_test_results then
    -- Handle test results data
    
    -- Normalize the test results data
    local normalized_data = self:normalize_test_results(data)
    
    csv_content = self:build_test_results_csv(normalized_data, options)
  else
    -- Handle coverage data
    
    -- Normalize the coverage data
    local normalized_data = self:normalize_coverage_data(data)
    
    if options.level == "line" then
      csv_content = self:build_line_level_csv(normalized_data, options)
    else
      csv_content = self:build_file_level_csv(normalized_data, options)
    end
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
  local separator = options.separator
  local columns = options.columns or self.DEFAULT_FILE_COLUMNS

  -- Add header if configured
  if options.include_header then
    local header_cells = {}
    for _, column in ipairs(columns) do
      table.insert(header_cells, self:escape_csv_field(column.name or "", true))
    end
    local header_line = table.concat(header_cells, separator)
    table.insert(lines, header_line)
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

--- Normalizes test results data into a standard structure.
--- Ensures all required fields exist and converts different test result formats to a consistent structure.
--- Creates a deep copy of the input data.
---@param self CSVFormatter The formatter instance.
---@param test_results table The raw test results data (expected to contain `test_cases`).
---@return table normalized_data A new table containing the normalized test results data.
function CSVFormatter:normalize_test_results(test_results)
  if not test_results then
    return { test_cases = {} }
  end

  -- Create a deep copy to avoid modifying the original
  local normalized = self:deep_copy(test_results)
  
  -- Ensure test_cases exists
  normalized.test_cases = normalized.test_cases or {}
  
  -- Normalize each test case
  for i, test_case in ipairs(normalized.test_cases) do
    -- Ensure required fields exist
    test_case.classname = test_case.classname or test_case.suite_name or ""
    test_case.name = test_case.name or ""
    -- Generate test_id from classname only (not classname.name)
    test_case.id = test_case.id or test_case.classname or tostring(i)
    test_case.status = self:get_test_status(test_case)
    test_case.time = test_case.time or test_case.duration or 0
    
    -- Normalize error data
    if test_case.error and type(test_case.error) == "table" and test_case.error.message then
      test_case.error_message = test_case.error.message
    elseif test_case.error and type(test_case.error) == "string" then
      test_case.error_message = test_case.error
    end
    test_case.error_message = test_case.error_message or ""
    
    -- Normalize nested tests if they exist
    if test_case.tests and #test_case.tests > 0 then
      for j, nested_test in ipairs(test_case.tests) do
        -- Ensure required fields exist for nested test
        nested_test.id = nested_test.id or test_case.classname or tostring(j)
        nested_test.classname = test_case.classname or ""
        nested_test.name = nested_test.name or ""
        nested_test.status = self:get_test_status(nested_test)
        nested_test.time = nested_test.time or nested_test.duration or 0
        
        -- Normalize error data for nested test
        if nested_test.error and type(nested_test.error) == "table" and nested_test.error.message then
          nested_test.error_message = nested_test.error.message
        elseif nested_test.error and type(nested_test.error) == "string" then
          nested_test.error_message = nested_test.error
        end
        nested_test.error_message = nested_test.error_message or ""
      end
    end
  end
  
  return normalized
end

--- Builds the CSV content string for a line-level report.
---@param self CSVFormatter The formatter instance.
---@param data table The normalized coverage data (requires `files` table with `lines` and optionally `source`).
---@param options table Formatting options including `include_header`, `separator`, `columns`.
---@return string csv_content The generated CSV content.
function CSVFormatter:build_line_level_csv(data, options)
  local lines = {}
  local separator = options.separator
  local columns = options.columns or self.DEFAULT_LINE_COLUMNS

  -- Add header if configured
  if options.include_header then
    local header_cells = {}
    for _, column in ipairs(columns) do
      table.insert(header_cells, self:escape_csv_field(column.name or "", true))
    end
    local header_line = table.concat(header_cells, separator)
    table.insert(lines, header_line)
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
      for line in (file_data.source .. "\n"):gmatch("([^\n]*)\n") do
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

      -- Add status translation for line data
      local status
      if line_data.covered then
        status = "Covered"
      else
        status = "Not Covered"
      end
      line_record.status = status

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

--- Builds the CSV content string for test results.
---@param self CSVFormatter The formatter instance.
---@param data table The test results data (requires `test_cases` table).
---@param options table Formatting options including `include_header`, `separator`, `columns`.
---@return string csv_content The generated CSV content.
function CSVFormatter:build_test_results_csv(data, options)
  local lines = {}
  local separator = options.separator
  local columns = options.columns or self.DEFAULT_TEST_COLUMNS

  -- Add header if configured
  if options.include_header ~= false then
    local header_cells = {}
    for _, column in ipairs(columns) do
      table.insert(header_cells, self:escape_csv_field(column.name or "", true))
    end
    local header_line = table.concat(header_cells, separator)
    table.insert(lines, header_line)
  end

  -- Process each test case
  for _, test_case in ipairs(data.test_cases or {}) do
    local row_cells = {}
    
    -- Add each column's data
    for _, column in ipairs(columns) do
      local value = self:get_nested_field(test_case, column.field)
      
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
    
    -- Process nested tests if they exist
    if test_case.tests and #test_case.tests > 0 then
      for _, nested_test in ipairs(test_case.tests) do
        local nested_row_cells = {}
        
        -- Add each column's data for the nested test
        for _, column in ipairs(columns) do
          local value = self:get_nested_field(nested_test, column.field)
          
          -- Apply formatting if specified
          if column.format and type(value) == "number" then
            value = string.format(column.format, value)
          elseif type(value) == "boolean" then
            value = value and "true" or "false"
          end
          
          -- Convert to string and escape
          value = self:escape_csv_field(tostring(value or ""))
          
          table.insert(nested_row_cells, value)
        end
        
        -- Ensure separator is a string before passing to table.concat
        table.insert(lines, table.concat(nested_row_cells, separator))
      end
    end
  end
  
  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

--- Converts non-strings to strings. Wraps fields containing commas, quotes, or newlines in double quotes, and doubles any internal double quotes.
---@param self CSVFormatter The formatter instance.
---@param value any The value to escape.
---@param is_header boolean Whether this is a header field, which should always be quoted.
---@return string escaped_value The escaped CSV field string.
function CSVFormatter:escape_csv_field(value, is_header)
  if value == nil then
    return ""
  end

  -- Convert to string if it's not already
  if type(value) ~= "string" then
    value = tostring(value)
  end

  -- Always quote header fields
  if is_header then
    -- Escape double quotes by doubling them
    value = value:gsub('"', '""')
    -- Always wrap headers in quotes
    return '"' .. value .. '"'
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

  -- Register format_results function for test results
  formatters.results.csv = function(results_data, options)
    return formatter:format(results_data, options)
  end

  -- Register format_coverage function for coverage data
  formatters.coverage.csv = function(coverage_data, options)
    return formatter:format(coverage_data, options)
  end

  return true
end

-- Helper for backward compatibility
function CSVFormatter.format_test_results_csv(results, columns, separator, include_header)
  local formatter = CSVFormatter.new()
  
  -- Get config for defaults
  -- Get config first with error handling
  local config = central_config and central_config.get() or {}
  local csv_config = config.reporting and config.reporting.formatters and config.reporting.formatters.csv or {}
  
  -- Ensure separator is a string, using config as fallback
  local separator_value = separator or csv_config.delimiter or ","
  if type(separator_value) == "table" then
    -- Handle case where separator might be a table (error case)
    separator_value = ","
    print("Warning: Separator provided as table in format_test_results_csv, defaulting to comma")
  elseif type(separator_value) ~= "string" then
    -- Convert non-string values to strings
    separator_value = tostring(separator_value)
  end
  
  return formatter:format(results, {
    columns = columns, -- Use provided columns, not default ones
    separator = separator_value,
    include_header = include_header
  })
end

return CSVFormatter
