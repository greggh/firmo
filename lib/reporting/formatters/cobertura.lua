--- Cobertura Coverage Report Formatter
---
--- Generates code coverage reports in the Cobertura XML format, commonly used
--- by CI/CD systems and code quality tools.
---
--- @module lib.reporting.formatters.cobertura
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.2.0

--- @class CoverageReportData Expected structure for coverage data input (simplified).
--- @field summary table { line_coverage_percent: number, covered_lines: number, executable_lines: number }
--- @field files table<string, CoverageFileEntry> Map of file paths to file data.

--- @class CoverageFileEntry
--- @field name string File name.
--- @field line_coverage_percent number Line coverage percentage for the file.
--- @field lines table<number, CoverageLineEntry> Map of line numbers to line data.
--- @field functions table<string, CoverageFunctionEntry> Map of function IDs to function data.

--- @class CoverageLineEntry
--- @field executable boolean Whether the line is executable code.
--- @field execution_count number Number of times the line was hit.

--- @class CoverageFunctionEntry
--- @field name string Function name.
--- @field start_line number Start line of the function.
--- @field end_line number End line of the function.
--- @field executed boolean Whether the function was executed.
--- @field execution_count number Number of times the function was called.

---@class CoverageCobertura The public API for the Cobertura formatter.
---@field _VERSION string Version of this module.
---@field generate fun(coverage_data: CoverageReportData, output_path: string): boolean, string|nil Generates and writes a Cobertura coverage report file. Returns `success, error_message?`. @throws table If validation or IO fails critically.
---@field format_coverage fun(coverage_data: CoverageReportData): string Formats coverage data as a Cobertura XML string. @throws table If validation fails.
---@field write_coverage_report fun(coverage_data: CoverageReportData, file_path: string): boolean, string|nil Formats and writes coverage data to a file. Alias for `generate`. Returns `success, error_message?`. @throws table If validation or IO fails critically.
local M = {}

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging, _fs

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

--- Get the logging module with lazy loading to avoid circular dependencies
---@return table|nil The logging module or nil if not available
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end

--- Get a logger instance for this module
---@return table A logger instance (either real or stub)
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("Reporting:CoberturaFormatter")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

-- Version
M._VERSION = "0.2.0"

--- Escapes special XML characters in a string.
---@param s string String to escape.
---@return string escaped_string The string with `&`, `<`, `>`, `"`, `'` replaced by XML entities.
---@private
local function xml_escape(s)
  if type(s) ~= "string" then
    s = tostring(s)
  end
  return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
end

--- Generates a Cobertura coverage report XML file.
--- Formats the data using `M.format_coverage` and writes it to `output_path`.
--- Ensures the output directory exists.
---@param coverage_data CoverageReportData The coverage data (must contain `summary` and `files`).
---@param output_path string The path where the report should be saved. If it ends in "/", "coverage-report-v2.cobertura" is appended.
---@return boolean success `true` if the report was generated and written successfully.
---@return string|nil error_message An error message string if generation or writing failed.
---@throws table If validation fails (via `error_handler.assert`) or if critical directory creation/file writing errors occur.
function M.generate(coverage_data, output_path)
  -- Parameter validation
  get_error_handler().assert(
    type(coverage_data) == "table",
    "coverage_data must be a table",
    get_error_handler().CATEGORY.VALIDATION
  )
  get_error_handler().assert(type(output_path) == "string", "output_path must be a string", get_error_handler().CATEGORY.VALIDATION)

  -- If output_path is a directory, add a filename
  if output_path:sub(-1) == "/" then
    output_path = output_path .. "coverage-report-v2.cobertura"
  end

  -- Try to ensure the directory exists
  local dir_path = output_path:match("(.+)/[^/]+$")
  if dir_path then
    local mkdir_success, mkdir_err = fs.ensure_directory_exists(dir_path)
    if not mkdir_success then
      get_logger().warn("Failed to ensure directory exists, but will try to write anyway", {
        directory = dir_path,
        error = mkdir_err and get_error_handler().format_error(mkdir_err) or "Unknown error",
      })
    end
  end

  -- Check for basic coverage data structure
  if not coverage_data.execution_data or not coverage_data.coverage_data then
    get_logger().warn("Coverage data structure doesn't match expected format, but will attempt to generate report anyway")
  end

  -- Generate timestamp
  local timestamp = os.date("%Y-%m-%dT%H:%M:%S")

  -- Start building XML content
  local xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
  xml = xml .. '<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">\n'
  xml = xml .. '<coverage line-rate="' .. (coverage_data.summary.line_coverage_percent / 100) .. '" '
  xml = xml .. 'branch-rate="0" '
  xml = xml .. 'lines-covered="' .. coverage_data.summary.covered_lines .. '" '
  xml = xml .. 'lines-valid="' .. coverage_data.summary.executable_lines .. '" '
  xml = xml .. 'branches-covered="0" '
  xml = xml .. 'branches-valid="0" '
  xml = xml .. 'complexity="0" '
  xml = xml .. 'version="0.1" '
  xml = xml .. 'timestamp="' .. timestamp .. '">\n'

  -- Add sources
  xml = xml .. "  <sources>\n"
  xml = xml .. "    <source>.</source>\n"
  xml = xml .. "  </sources>\n"

  -- Add packages (we use files as packages in this simple implementation)
  xml = xml .. "  <packages>\n"

  -- Sort files for consistent output
  local files = {}
  for path, file_data in pairs(coverage_data.files) do
    table.insert(files, { path = path, data = file_data })
  end

  table.sort(files, function(a, b)
    return a.path < b.path
  end)

  -- Process each file
  for _, file in ipairs(files) do
    local file_data = file.data
    local path = file.path

    -- Generate a package name from the path (e.g. "lib.coverage")
    local package_name = path:gsub("/", "."):gsub("%.lua$", "")

    -- Add package
    xml = xml .. '    <package name="' .. xml_escape(package_name) .. '" '
    xml = xml .. 'line-rate="' .. (file_data.line_coverage_percent / 100) .. '" '
    xml = xml .. 'branch-rate="0" '
    xml = xml .. 'complexity="0">\n'

    -- Add classes (we use one class per file in this simple implementation)
    xml = xml .. "      <classes>\n"

    -- Add class
    local class_name = file_data.name:gsub("%.lua$", "")
    xml = xml .. '        <class name="' .. xml_escape(class_name) .. '" '
    xml = xml .. 'filename="' .. xml_escape(path) .. '" '
    xml = xml .. 'line-rate="' .. (file_data.line_coverage_percent / 100) .. '" '
    xml = xml .. 'branch-rate="0" '
    xml = xml .. 'complexity="0">\n'

    -- Add methods
    xml = xml .. "          <methods>\n"

    -- Sort functions by start line
    local functions = {}
    for func_id, func_data in pairs(file_data.functions) do
      table.insert(functions, { id = func_id, data = func_data })
    end

    table.sort(functions, function(a, b)
      return a.data.start_line < b.data.start_line
    end)

    -- Process each function
    for _, func in ipairs(functions) do
      local func_data = func.data
      local func_name = func_data.name

      -- Calculate line rate for this function
      local func_line_count = func_data.end_line - func_data.start_line + 1
      local func_line_rate = 0
      if func_data.executed then
        func_line_rate = 1
      end

      -- Add method
      xml = xml .. '            <method name="' .. xml_escape(func_name) .. '" '
      xml = xml .. 'signature="()V" ' -- Simplified method signature
      xml = xml .. 'line-rate="' .. func_line_rate .. '" '
      xml = xml .. 'branch-rate="0">\n'

      -- Add method lines
      xml = xml .. "              <lines>\n"

      -- Add function start line
      xml = xml .. '                <line number="' .. func_data.start_line .. '" '
      xml = xml
        .. 'hits="'
        .. (func_data.executed and func_data.execution_count > 0 and func_data.execution_count or 0)
        .. '" '
      xml = xml .. 'branch="false"/>\n'

      -- Add method end
      xml = xml .. "              </lines>\n"
      xml = xml .. "            </method>\n"
    end

    -- Close methods
    xml = xml .. "          </methods>\n"

    -- Add lines
    xml = xml .. "          <lines>\n"

    -- Get all executable lines
    local sorted_lines = {}
    for line_num, line_data in pairs(file_data.lines) do
      if line_data.executable then
        table.insert(sorted_lines, {
          line_num = line_num,
          data = line_data,
        })
      end
    end

    table.sort(sorted_lines, function(a, b)
      return a.line_num < b.line_num
    end)

    -- Process each line
    for _, line_info in ipairs(sorted_lines) do
      local line_num = line_info.line_num
      local line_data = line_info.data

      -- Add line
      xml = xml .. '            <line number="' .. line_num .. '" '
      xml = xml .. 'hits="' .. line_data.execution_count .. '" '
      xml = xml .. 'branch="false"/>\n'
    end

    -- Close lines, class, classes, package
    xml = xml .. "          </lines>\n"
    xml = xml .. "        </class>\n"
    xml = xml .. "      </classes>\n"
    xml = xml .. "    </package>\n"
  end

  -- Close packages and coverage tags
  xml = xml .. "  </packages>\n"
  xml = xml .. "</coverage>\n"

  -- Write the report to the output file
  local success, err = get_error_handler().safe_io_operation(function()
    return get_fs().write_file(output_path, xml)
  end, output_path, { operation = "write_cobertura_report" })

  if not success then
    return false, "Failed to write Cobertura report: " .. get_error_handler().format_error(err)
  end

  logger.info("Generated Cobertura coverage report", {
    output_path = output_path,
    total_files = coverage_data.summary.total_files,
    line_coverage = coverage_data.summary.line_coverage_percent .. "%",
    function_coverage = coverage_data.summary.function_coverage_percent .. "%",
  })

  return true
end

--- Formats coverage data into a Cobertura XML string.
---@param coverage_data CoverageReportData The coverage data (must contain `summary` and `files`).
---@return string xml_content The generated Cobertura XML content as a string. Returns a minimal empty XML if input data is invalid.
---@throws table If validation fails (via `error_handler.assert`).
function M.format_coverage(coverage_data)
  get_logger().trace("Starting format_coverage")
  -- Parameter validation
  get_error_handler().assert(
    type(coverage_data) == "table",
    "coverage_data must be a table",
    get_error_handler().CATEGORY.VALIDATION
  )

  -- Check if summary is available
  if not coverage_data.summary then
    logger.warn("Coverage data does not contain summary data, returning empty Cobertura content")
    return '<?xml version="1.0" encoding="UTF-8"?>\n<coverage></coverage>'
  end
  get_logger().trace("Checked summary data")

  -- Generate timestamp
  local timestamp = os.date("%Y-%m-%dT%H:%M:%S")

  -- Start building XML content
  local xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
  xml = xml .. '<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">\n'
  xml = xml .. '<coverage line-rate="' .. (coverage_data.summary.line_coverage_percent / 100) .. '" '
  xml = xml .. 'branch-rate="0" '
  xml = xml .. 'lines-covered="' .. coverage_data.summary.covered_lines .. '" '
  xml = xml .. 'lines-valid="' .. coverage_data.summary.executable_lines .. '" '
  xml = xml .. 'branches-covered="0" '
  xml = xml .. 'branches-valid="0" '
  xml = xml .. 'complexity="0" '
  xml = xml .. 'version="0.1" '
  xml = xml .. 'timestamp="' .. timestamp .. '">\n'

  -- Add sources
  xml = xml .. "  <sources>\n"
  xml = xml .. "    <source>.</source>\n"
  xml = xml .. "  </sources>\n"

  -- Add packages (we use files as packages in this simple implementation)
  xml = xml .. "  <packages>\n"

  -- Sort files for consistent output
  local files = {}
  for path, file_data in pairs(coverage_data.files) do
    table.insert(files, { path = path, data = file_data })
  end

  table.sort(files, function(a, b)
    return a.path < b.path
  end)

  get_logger().trace("Starting file loop")
  -- Process each file
  for _, file in ipairs(files) do
    get_logger().trace("Processing file", { path = file.path })
    local file_data = file.data
    local path = file.path

    -- Generate a package name from the path (e.g. "lib.coverage")
    local package_name = path:gsub("/", "."):gsub("%.lua$", "")

    -- Add package
    xml = xml .. '    <package name="' .. xml_escape(package_name) .. '" '
    xml = xml .. 'line-rate="' .. (file_data.line_coverage_percent / 100) .. '" '
    xml = xml .. 'branch-rate="0" '
    xml = xml .. 'complexity="0">\n'

    -- Add classes (we use one class per file in this simple implementation)
    xml = xml .. "      <classes>\n"

    -- Add class
    local class_name = path:gsub("%.lua$", "") -- Use path, not file_data.name
    xml = xml .. '        <class name="' .. xml_escape(class_name) .. '" '
    xml = xml .. 'filename="' .. xml_escape(path) .. '" '
    xml = xml .. 'line-rate="' .. (file_data.line_coverage_percent / 100) .. '" '
    xml = xml .. 'branch-rate="0" '
    xml = xml .. 'complexity="0">\n'

    -- Add methods
    xml = xml .. "          <methods>\n"

    -- Sort functions by start line
    local functions = {}
    for func_id, func_data in pairs(file_data.functions) do
      table.insert(functions, { id = func_id, data = func_data })
    end

    table.sort(functions, function(a, b)
      return a.data.start_line < b.data.start_line
    end)

    get_logger().trace("Starting function loop for file", { path = path })
    -- Process each function
    for _, func in ipairs(functions) do
      local func_data = func.data
      local func_name = func_data.name

      -- Calculate line rate for this function
      local func_line_count = func_data.end_line - func_data.start_line + 1
      local func_line_rate = 0
      if func_data.executed then
        func_line_rate = 1
      end

      -- Add method
      xml = xml .. '            <method name="' .. xml_escape(func_name) .. '" '
      xml = xml .. 'signature="()V" ' -- Simplified method signature
      xml = xml .. 'line-rate="' .. func_line_rate .. '" '
      xml = xml .. 'branch-rate="0">\n'

      -- Add method lines
      xml = xml .. "              <lines>\n"

      -- Add function start line
      xml = xml .. '                <line number="' .. func_data.start_line .. '" '
      xml = xml
        .. 'hits="'
        .. (func_data.executed and func_data.execution_count > 0 and func_data.execution_count or 0)
        .. '" '
      xml = xml .. 'branch="false"/>\n'

      -- Add method end
      xml = xml .. "              </lines>\n"
      xml = xml .. "            </method>\n"
    end

    -- Close methods
    xml = xml .. "          </methods>\n"

    -- Add lines
    xml = xml .. "          <lines>\n"

    -- Get all executable lines
    local sorted_lines = {}
    for line_num, line_data in pairs(file_data.lines) do
      if line_data.executable then
        table.insert(sorted_lines, {
          line_num = line_num,
          data = line_data,
        })
      end
    end

    table.sort(sorted_lines, function(a, b)
      return a.line_num < b.line_num
    end)

    get_logger().trace("Starting line loop for file", { path = path })
    -- Process each line
    for _, line_info in ipairs(sorted_lines) do
      local line_num = line_info.line_num
      local line_data = line_info.data

      -- Add line
      xml = xml .. '            <line number="' .. line_num .. '" '
      xml = xml .. 'hits="' .. line_data.execution_count .. '" '
      xml = xml .. 'branch="false"/>\n'
    end

    -- Close lines, class, classes, package
    xml = xml .. "          </lines>\n"
    xml = xml .. "        </class>\n"
    xml = xml .. "      </classes>\n"
    xml = xml .. "    </package>\n"
  end

  -- Close packages and coverage tags
  xml = xml .. "  </packages>\n"
  xml = xml .. "</coverage>\n"

  get_logger().trace("Finished format_coverage successfully")
  return xml
end

--- Formats and writes coverage data to a file in Cobertura XML format.
--- This is essentially an alias for `M.generate`.
---@param coverage_data CoverageReportData The coverage data.
---@param file_path string The path to write the file to.
---@return boolean success `true` if formatting and writing were successful.
---@return string|nil error_message An error message string if formatting or writing failed.
---@throws table If validation fails (via `error_handler.assert`) or if critical file writing errors occur.
function M.write_coverage_report(coverage_data, file_path)
  -- Parameter validation
  get_error_handler().assert(
    type(coverage_data) == "table",
    "coverage_data must be a table",
    get_error_handler().CATEGORY.VALIDATION
  )
  get_error_handler().assert(type(file_path) == "string", "file_path must be a string", get_error_handler().CATEGORY.VALIDATION)

  -- Format the data
  local xml = M.format_coverage(coverage_data)

  -- Write to file
  local success, err = get_error_handler().safe_io_operation(function()
    return get_fs().write_file(file_path, xml)
  end, file_path, { operation = "write_cobertura_report" })

  if not success then
    return false, "Failed to write Cobertura report: " .. get_error_handler().format_error(err)
  end

  logger.info("Wrote Cobertura coverage report", {
    file_path = file_path,
    size = #xml,
    total_files = coverage_data.summary.total_files,
    line_coverage = coverage_data.summary.line_coverage_percent .. "%",
  })

  return true
end

return M
