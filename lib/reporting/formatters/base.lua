--- Firmo Base Report Formatter Class
---
--- Provides common functionality and defines the interface for specific report formatters
--- (e.g., HTML, JSON, LCOV). Subclasses should inherit from this base class using `Formatter.extend()`.
---
--- @module lib.reporting.formatters.base
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _fs

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the filesystem module with lazy loading to avoid circular dependencies
---@return table|nil The filesystem module or nil if not available
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
end

--- Get the success handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

--- Formatter Class
---@class Formatter Base class for report formatters.
--- Provides common functionality and defines the interface for specific formatters.
--- Should not be instantiated directly; use `Formatter.extend()`.
---@field _VERSION string Module version.
---@field name string The name of the formatter (e.g., "json", "html"). Set by `new()`.
---@field extension string The default file extension for the report (e.g., ".json", ".html"). Set by `new()`.
---@field options table Configuration options for the formatter instance. Set by `new()`.
---@field new fun(name: string, extension: string): Formatter Creates a new Formatter instance (internal constructor). @private
---@field extend fun(name: string, extension: string): Formatter Creates a new formatter class extending this base class.
---@field validate fun(self: Formatter, coverage_data: table): boolean, table? Base validation method. Checks data structure. Returns `true` or `false, error`.
---@field format fun(self: Formatter, coverage_data: table, options?: table): string|table|nil, table? Abstract format method. Must be implemented by subclasses. Returns formatted data or `nil, error`.
---@field write fun(self: Formatter, formatted_data: string|table, output_path: string, options?: table): boolean, table? Writes formatted data to a file. Handles directory creation. Returns `true` or `false, error`. @throws table If IO operations fail critically.
---@field generate fun(self: Formatter, coverage_data: table, output_path: string, options?: table): boolean, string|table? Generates and writes the report. Returns `true, output_path` or `false, error`. @throws table If validation, formatting, or writing fails critically.
---@field normalize_coverage_data fun(self: Formatter, coverage_data: table): table Normalizes raw coverage data to a standard structure with calculated percentages.
---@field deep_copy fun(self: Formatter, value: any): any Creates a deep copy of a Lua value. @protected
---@field get_table_keys fun(self: Formatter, tbl: table): table Returns a sorted array of keys from a table. @protected
local Formatter = {}
-- Module version
Formatter._VERSION = "1.0.0"

---@param name string The name of the formatter (used for identification).
---@param extension string The default file extension (e.g., ".html").
---@return Formatter instance The newly created formatter instance.
---@private Use `Formatter.extend()` to create new formatters.
function Formatter.new(name, extension)
  local formatter = {
    name = name,
    extension = extension,
    options = {},
  }

  -- Set default meta-methods
  setmetatable(formatter, {
    __index = Formatter,
    __tostring = function(self)
      return string.format("Formatter(%s)", self.name)
    end,
  })

  return formatter
end

---@param self Formatter The formatter instance.
---@param coverage_data table The coverage data to validate (structure depends on the report type).
---@return boolean valid `true` if basic structure is valid.
---@return table? error Error object if validation failed.
function Formatter:validate(coverage_data)
  if type(coverage_data) ~= "table" then
    return false,
      get_error_handler().validation_error(
        "Coverage data must be a table",
        { formatter = self.name, provided_type = type(coverage_data) }
      )
  end

  -- Check for required top-level fields
  if not coverage_data.data then
    return false,
      get_error_handler().validation_error(
        "Coverage data must contain 'data' field",
        { formatter = self.name, fields = table.concat(self:get_table_keys(coverage_data), ", ") }
      )
  end

  -- Additional validation can be added by derived formatters

  return true
end

---@param self Formatter The formatter instance.
---@param coverage_data table The coverage data to format (structure depends on report type).
---@param options? table Optional configuration specific to the formatter.
---@return string|table|nil formatted The formatted report content (string or table), or `nil` on error.
---@return table? error Error object if formatting failed.
function Formatter:format(coverage_data, options)
  return nil,
    get_error_handler().validation_error(
      "format() method must be implemented by formatter: " .. self.name,
      { formatter = self.name }
    )
end

---@param self Formatter The formatter instance.
---@param formatted_data string|table The formatted report content (string or table - tables might be encoded, e.g., JSON).
---@param output_path string The path to write the report file to.
---@param options? table Optional configuration for the write operation (currently unused).
---@return boolean success `true` if the file was written successfully.
---@return table? error Error object if validation or writing failed.
---@throws table If directory creation or file writing fails critically.
function Formatter:write(formatted_data, output_path, options)
  -- Parameter validation
  if not formatted_data then
    return false, get_error_handler().validation_error("Formatted data is required", { formatter = self.name })
  end

  if not output_path then
    return false, get_error_handler().validation_error("Output path is required", { formatter = self.name })
  end

  -- Ensure directory exists
  local dir_path = filesystem.get_directory_name(output_path)
  if dir_path and dir_path ~= "" then
    local success, err = filesystem.ensure_directory_exists(dir_path)
    if not success then
      return false,
        get_error_handler().io_error(
          "Failed to create directory for report",
          { formatter = self.name, directory = dir_path, error = err }
        )
    end
  end

  -- Write the file using a safe operation
  local success, err = error_handler.safe_io_operation(function()
    return get_fs().write_file(output_path, formatted_data)
  end, output_path, { operation = "write_" .. self.name .. "_report" })

  if not success then
    return false,
      get_error_handler().io_error(
        "Failed to write " .. self.name .. " report",
        { formatter = self.name, path = output_path, error = err and err.message or err }
      )
  end

  return true
end

---@param self Formatter The formatter instance.
---@param coverage_data table The coverage data to format.
---@param output_path string The path to write the final report file to.
---@param options? table Additional options passed to the `format` and `write` methods.
---@return boolean success `true` if the report was generated and written successfully.
---@return string|table? path_or_error The `output_path` string on success, or an error object on failure.
---@throws table If validation, formatting, or writing fails critically.
function Formatter:generate(coverage_data, output_path, options)
  -- Validate coverage data
  local is_valid, validation_error = self:validate(coverage_data)
  if not is_valid then
    return false, validation_error
  end

  -- Format the coverage data
  local formatted_data, format_error = self:format(coverage_data, options)
  if not formatted_data then
    return false, format_error
  end

  -- Write the report
  local write_success, write_error = self:write(formatted_data, output_path, options)
  if not write_success then
    return false, write_error
  end

  return true, output_path
end

--- Normalizes raw coverage data into a standard structure.
--- Ensures required fields exist, calculates percentages if missing.
--- Creates a deep copy of the input data.
---@param self Formatter The formatter instance.
---@param coverage_data table The raw coverage data (expected structure includes `summary` and `files`).
---@return table normalized_data A new table containing the normalized coverage data (conforming roughly to `CoverageReportData` structure).
function Formatter:normalize_coverage_data(coverage_data)
  if not coverage_data then
    return {}
  end

  -- Create a deep copy to avoid modifying the original
  local normalized = self:deep_copy(coverage_data)

  -- Ensure summary exists
  normalized.summary = normalized.summary or {}

  -- Set defaults for required summary fields if missing
  normalized.summary.total_files = normalized.summary.total_files or 0
  normalized.summary.total_lines = normalized.summary.total_lines or 0
  normalized.summary.covered_lines = normalized.summary.covered_lines or 0
  normalized.summary.executed_lines = normalized.summary.executed_lines or 0
  normalized.summary.not_covered_lines = normalized.summary.not_covered_lines or 0

  -- Calculate coverage percentage if missing
  if not normalized.summary.coverage_percent then
    normalized.summary.coverage_percent = 0
    if normalized.summary.total_lines > 0 then
      normalized.summary.coverage_percent = (normalized.summary.covered_lines / normalized.summary.total_lines) * 100
    end
  end

  -- Calculate execution percentage if missing
  if not normalized.summary.execution_percent then
    normalized.summary.execution_percent = 0
    if normalized.summary.total_lines > 0 then
      normalized.summary.execution_percent = (
        (normalized.summary.covered_lines + normalized.summary.executed_lines) / normalized.summary.total_lines
      ) * 100
    end
  end

  -- Ensure files structure exists
  normalized.files = normalized.files or {}

  -- Normalize each file
  for file_path, file_data in pairs(normalized.files) do
    -- Ensure file summary exists
    file_data.summary = file_data.summary or {}

    -- Set defaults for required file summary fields if missing
    file_data.summary.total_lines = file_data.summary.total_lines or 0
    file_data.summary.covered_lines = file_data.summary.covered_lines or 0
    file_data.summary.executed_lines = file_data.summary.executed_lines or 0
    file_data.summary.not_covered_lines = file_data.summary.not_covered_lines or 0

    -- Calculate file coverage percentage if missing
    if not file_data.summary.coverage_percent then
      file_data.summary.coverage_percent = 0
      if file_data.summary.total_lines > 0 then
        file_data.summary.coverage_percent = (file_data.summary.covered_lines / file_data.summary.total_lines) * 100
      end
    end

    -- Calculate file execution percentage if missing
    if not file_data.summary.execution_percent then
      file_data.summary.execution_percent = 0
      if file_data.summary.total_lines > 0 then
        file_data.summary.execution_percent = (
          (file_data.summary.covered_lines + file_data.summary.executed_lines) / file_data.summary.total_lines
        ) * 100
      end
    end

    -- Ensure lines structure exists
    file_data.lines = file_data.lines or {}

    -- Normalize each line
    for line_number, line_data in pairs(file_data.lines) do
      -- Ensure required line fields
      line_data.line_number = line_data.line_number or tonumber(line_number)
      line_data.executed = line_data.executed or false
      line_data.covered = line_data.covered or false
      line_data.execution_count = line_data.execution_count or 0

      -- Ensure assertions array exists
      line_data.assertions = line_data.assertions or {}
    end

    -- Ensure functions structure exists
    file_data.functions = file_data.functions or {}

    -- Normalize each function
    for func_id, func_data in pairs(file_data.functions) do
      -- Ensure required function fields
      func_data.name = func_data.name or func_id
      func_data.start_line = func_data.start_line or 0
      func_data.end_line = func_data.end_line or 0
      func_data.executed = func_data.executed or false
      func_data.covered = func_data.covered or false
      func_data.execution_count = func_data.execution_count or 0
    end
  end

  return normalized
end

--- Creates a deep copy of a table or value
---@param self Formatter The formatter instance.
---@param value any The Lua value to deep copy.
---@return any copy The deep copy.
---@protected May be useful for subclasses, but not part of the core public API.
function Formatter:deep_copy(value)
  if type(value) ~= "table" then
    return value
  end

  local copy = {}
  for k, v in pairs(value) do
    if type(v) == "table" then
      copy[k] = self:deep_copy(v)
    else
      copy[k] = v
    end
  end

  return copy
end

--- Gets all keys from a table as an array
---@param self Formatter The formatter instance.
---@param tbl table The table to extract keys from.
---@return table keys A new table containing the sorted keys of the input table.
---@protected May be useful for subclasses, but not part of the core public API.
function Formatter:get_table_keys(tbl)
  local keys = {}
  if type(tbl) == "table" then
    for k, _ in pairs(tbl) do
      table.insert(keys, k)
    end
    table.sort(keys)
  end
  return keys
end

--- Creates a new formatter class that extends the base formatter
---@param name string The name for the new formatter class (e.g., "HtmlFormatter").
---@param extension string The default file extension for reports produced by this class (e.g., ".html").
---@return Formatter The new formatter class table, inheriting from `Formatter`, ready for instantiation or further extension.
function Formatter.extend(name, extension)
  local formatter_class = {
    name = name,
    extension = extension,
  }

  -- Set up inheritance
  setmetatable(formatter_class, {
    __index = Formatter,
    __call = function(cls, ...)
      return cls.new(...)
    end,
  })

  -- Set up .new method for the class
  formatter_class.new = function(options)
    local instance = {
      options = options or {},
    }

    setmetatable(instance, {
      __index = formatter_class,
      __tostring = function(self)
        return string.format("Formatter(%s)", name)
      end,
    })

    return instance
  end

  return formatter_class
end

return Formatter
