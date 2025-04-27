--- Summary Formatter for Coverage and Quality Reports
---
--- Provides human-readable text summaries with optional color-coded outputs.
--- Can format both coverage and quality report data. Inherits from base Formatter.
---
--- @module lib.reporting.formatters.summary
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

--- @class CoverageReportFileStats Simplified structure expected for coverage input.
--- @field path string File path.
--- @field line_coverage_percent number Coverage percentage for the file.

--- @class CoverageReportSummary Simplified structure expected for coverage input.
--- @field total_files number Total number of files.
--- @field covered_files number Number of covered files.
--- @field total_lines number Total lines across all files.
--- @field covered_lines number Total covered lines across all files.
--- @field total_functions number Total functions across all files.
--- @field covered_functions number Total covered functions across all files.
--- @field overall_percent number Overall coverage percentage.

--- @class CoverageReportData Expected structure for coverage data input (simplified).
--- @field summary CoverageReportSummary Overall summary statistics.
--- @field files table<string, CoverageReportFileStats> Map of file paths to file statistics.

--- @class QualityReportSummary Simplified structure expected for quality input.
--- @field tests_analyzed number Total number of tests analyzed.
--- @field tests_passing_quality number Number of tests passing validation.
--- @field quality_percent number Overall quality percentage score.
--- @field issues string[] List of quality issue description strings.

--- @class QualityReportData Expected structure for quality data input (simplified).
--- @field level number The quality level configured/achieved.
--- @field level_name string The name of the quality level.
--- @field summary QualityReportSummary Summary statistics.

---@class SummaryFormatter : Formatter Generates human-readable text summaries.
--- Capable of formatting both coverage and quality reports with optional colorization.
---@field _VERSION string Module version.
---@field get_config fun(self: SummaryFormatter): table Retrieves the formatter's configuration.
---@field colorize fun(self: SummaryFormatter, text: string, color_code: string, config: table): string Colorizes text based on config. Returns original text if color disabled or error occurs.
---@field validate fun(self: SummaryFormatter, data: table): boolean, table? Validates report data (currently always returns true). Returns `true` or `false, error`.
---@field format fun(self: SummaryFormatter, data: table, options?: table): table|nil, table? Formats coverage or quality data. Returns a table containing the formatted `output` string and key metrics, or `nil, error`.
---@field format_coverage fun(self: SummaryFormatter, coverage_data: CoverageReportData, config: table, options?: table): table Returns a table with formatted `output` string and coverage metrics.
---@field format_quality fun(self: SummaryFormatter, quality_data: QualityReportData, config: table, options?: table): table Returns a table with formatted `output` string and quality metrics.
---@field write fun(self: SummaryFormatter, formatted_data: {output: string}, output_path: string, options?: table): boolean, table? Writes the `output` string from the formatted data table to a file. Returns `true, nil` or `false, error`. @throws table If writing fails critically.
---@field generate fun(self: SummaryFormatter, data: table, output_path: string, options?: table): boolean, string|table? Generates and writes the summary report file. Returns `true, output_path` or `false, error`. @throws table If validation, formatting, or writing fails critically.
---@field register fun(formatters: table): boolean, table? Registers the Summary formatter with the main registry. Returns `true, nil` or `false, error`. @throws table If validation fails.

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging

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
    return logging.get_logger("Reporting:Summary")
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

local central_config = try_require("lib.core.central_config")
local Formatter = try_require("lib.reporting.formatters.base")

-- Create Summary formatter class
local SummaryFormatter = Formatter.extend("summary", "txt")

--- Summary Formatter version
SummaryFormatter._VERSION = "1.0.0"

-- Default formatter configuration
local DEFAULT_CONFIG = {
  detailed = false,
  show_files = true,
  colorize = true,
  min_coverage_warn = 70,
  min_coverage_ok = 80,
}

--- Retrieves the configuration for the summary formatter.
--- Fetches from `central_config` ("reporting.formatters.summary") or uses `DEFAULT_CONFIG`.
---@param self SummaryFormatter The formatter instance.
---@return table config The merged configuration table for the formatter.
function SummaryFormatter:get_config()
  -- Use central_config to get formatter configuration
  local config_success, config_result = get_error_handler().try(function()
    return central_config.get("reporting.formatters.summary")
  end)

  if config_success and config_result then
    get_logger().debug("Using configuration from central_config")
    return config_result
  else
    -- Log warning but continue with fallback
    if not config_success then
      get_logger().warn("Failed to get formatter config from central_config", {
        formatter = self.name,
        error = get_error_handler().format_error(config_result),
      })
    else
      get_logger().debug("No configuration found in central_config, using defaults")
    end
  end

  -- Fall back to default configuration
  get_logger().debug("Using default configuration for summary formatter")
  return DEFAULT_CONFIG
end

--- Colorizes text based on configuration
-- @param self SummaryFormatter The formatter instance
---@param config table The formatter configuration (must contain `colorize` boolean field).
---@return string colorized_text The colorized text string, or the original `text` if colorization is disabled or `color_code` is invalid.
function SummaryFormatter:colorize(text, color_code, config)
  -- Validate input parameters
  if not text then
    get_logger().warn("Missing text parameter in colorize", {
      formatter = self.name,
      color_code = color_code,
    })
    return ""
  end

  if not color_code then
    get_logger().warn("Missing color_code parameter in colorize", {
      formatter = self.name,
      text = type(text) == "string" and text:sub(1, 20) .. (text:len() > 20 and "..." or "") or tostring(text),
    })
    return text
  end

  -- Check if colorization is disabled in config
  if not config or config.colorize == false then
    return text
  end

  -- Define available colors with error handling
  local colors = {
    reset = "\27[0m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m",
    bold = "\27[1m",
  }

  -- Handle invalid color codes gracefully
  if not colors[color_code] then
    get_logger().warn("Invalid color code in colorize", {
      formatter = self.name,
      color_code = color_code,
      available_colors = "reset, red, green, yellow, blue, magenta, cyan, white, bold",
    })
    return text
  end

  -- Use get_error_handler().try for string concatenation (rare but possible errors)
  local success, result = get_error_handler().try(function()
    return colors[color_code] .. tostring(text) .. colors.reset
  end)

  if not success then
    get_logger().warn("Failed to colorize text", {
      formatter = self.name,
      color_code = color_code,
      error = get_error_handler().format_error(result),
    })
    return tostring(text)
  end

  return result
end

--- Validate report data structure
-- @param self SummaryFormatter The formatter instance
--- Validates the report data. Currently performs only base validation.
---@param self SummaryFormatter The formatter instance.
---@param data table The report data to validate (coverage or quality).
---@return boolean valid `true` if validation passes (currently always true if base passes).
---@return table? error Error object if base validation failed.
function SummaryFormatter:validate(data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, data)
  if not valid then
    return false, err
  end

  -- Summary formatter specific validation - less strict since it shows summaries
  -- We'll accept most data structures and handle gracefully in the format methods

  return true
end

--- Format coverage or quality data based on report type
-- @param self SummaryFormatter The formatter instance
---@param data table The coverage data (`CoverageReportData`) or quality data (`QualityReportData`) to format.
---@param options? table Optional formatting options (passed to specific formatters).
---@return table|nil report A table containing the formatted `output` string and key metrics, or `nil` on error.
---@return table? error Error object if formatting failed (e.g., data validation).
function SummaryFormatter:format(data, options)
  -- Parameter validation
  if not data then
    return nil, get_error_handler().validation_error("Data is required", { formatter = self.name })
  end

  -- Apply options with defaults
  options = options or {}

  -- Get configuration
  local config = self:get_config()

  -- Detect report type and format accordingly
  if data.type == "quality" or data.quality_level or data.level_name then
    -- This appears to be quality data
    return self:format_quality(data, config, options)
  else
    -- Default to coverage report
    return self:format_coverage(data, config, options)
  end
end

--- Format coverage data as a text summary
---@param self SummaryFormatter The formatter instance.
---@param coverage_data CoverageReportData The coverage data to format (expects `summary`, `files`).
---@param config table Configuration for the formatter.
---@param options? table Optional additional formatting options (currently unused).
---@return table report A table containing the formatted `output` string and key coverage metrics (overall_pct, files_pct, lines_pct, functions_pct, etc.). Returns a default structure with zeros if input is invalid.
function SummaryFormatter:format_coverage(coverage_data, config, options)
  get_logger().debug("Formatting coverage summary", {
    has_files = coverage_data and coverage_data.files ~= nil,
    detailed = config.detailed,
    show_files = config.show_files,
    colorize = config.colorize,
  })

  -- Validate the input data to prevent runtime errors
  if not coverage_data then
    local err = get_error_handler().validation_error("Missing coverage data", {
      formatter = self.name,
      data_type = type(coverage_data),
      operation = "format_coverage",
    })
    get_logger().error(err.message, err.context)

    -- Return an empty report structure with zeros
    return {
      output = "No coverage data available",
      files = {},
      total_files = 0,
      covered_files = 0,
      files_pct = 0,
      total_lines = 0,
      covered_lines = 0,
      lines_pct = 0,
      total_functions = 0,
      covered_functions = 0,
      functions_pct = 0,
      overall_pct = 0,
    }
  end

  -- Count files in a safer way with error handling
  local file_count = 0
  if coverage_data.files then
    local count_success, count_result = get_error_handler().try(function()
      local count = 0
      for _ in pairs(coverage_data.files) do
        count = count + 1
      end
      return count
    end)

    if count_success then
      file_count = count_result
    else
      get_logger().warn("Failed to count files in coverage data", {
        formatter = self.name,
        error = get_error_handler().format_error(count_result),
      })
      -- Continue with file_count = 0
    end
  end

  get_logger().debug("Formatting coverage summary", {
    has_files = coverage_data.files ~= nil,
    has_summary = coverage_data.summary ~= nil,
    file_count = file_count,
  })

  -- Make sure we have summary data
  local summary = coverage_data.summary
    or {
      total_files = 0,
      covered_files = 0,
      total_lines = 0,
      covered_lines = 0,
      total_functions = 0,
      covered_functions = 0,
      line_coverage_percent = 0,
      function_coverage_percent = 0,
      overall_percent = 0,
    }

  -- Prepare the summary data with error handling for division operations
  local report = {
    files = coverage_data.files or {},
    total_files = summary.total_files or 0,
    covered_files = summary.covered_files or 0,
    files_pct = 0, -- Default value, calculated below with error handling

    total_lines = summary.total_lines or 0,
    covered_lines = summary.covered_lines or 0,
    lines_pct = 0, -- Default value, calculated below with error handling

    total_functions = summary.total_functions or 0,
    covered_functions = summary.covered_functions or 0,
    functions_pct = 0, -- Default value, calculated below with error handling

    overall_pct = summary.overall_percent or 0,
  }

  -- Calculate percentages with error handling
  if summary.total_files and summary.total_files > 0 and summary.covered_files then
    local calc_success, files_pct = get_error_handler().try(function()
      return (summary.covered_files / summary.total_files) * 100
    end)

    if calc_success then
      report.files_pct = files_pct
    else
      get_logger().warn("Failed to calculate files coverage percentage", {
        formatter = self.name,
        covered = summary.covered_files,
        total = summary.total_files,
        error = get_error_handler().format_error(files_pct),
      })
    end
  end

  if summary.total_lines and summary.total_lines > 0 and summary.covered_lines then
    local calc_success, lines_pct = get_error_handler().try(function()
      return (summary.covered_lines / summary.total_lines) * 100
    end)

    if calc_success then
      report.lines_pct = lines_pct
    else
      get_logger().warn("Failed to calculate lines coverage percentage", {
        formatter = self.name,
        covered = summary.covered_lines,
        total = summary.total_lines,
        error = get_error_handler().format_error(lines_pct),
      })
    end
  end

  if summary.total_functions and summary.total_functions > 0 and summary.covered_functions then
    local calc_success, functions_pct = get_error_handler().try(function()
      return (summary.covered_functions / summary.total_functions) * 100
    end)

    if calc_success then
      report.functions_pct = functions_pct
    else
      get_logger().warn("Failed to calculate functions coverage percentage", {
        formatter = self.name,
        covered = summary.covered_functions,
        total = summary.total_functions,
        error = get_error_handler().format_error(functions_pct),
      })
    end
  end

  -- Format summary as a string based on configuration
  local output = {}

  -- Add header with error handling
  local add_header_success, _ = get_error_handler().try(function()
    table.insert(output, self:colorize("Coverage Summary", "bold", config))
    table.insert(output, self:colorize("----------------", "bold", config))
    return true
  end)

  if not add_header_success then
    get_logger().warn("Failed to add header to coverage summary", {
      formatter = self.name,
    })
    -- Continue with empty output array
    output = {}
  end

  -- Make sure config has valid thresholds
  local min_coverage_ok = config.min_coverage_ok or DEFAULT_CONFIG.min_coverage_ok
  local min_coverage_warn = config.min_coverage_warn or DEFAULT_CONFIG.min_coverage_warn

  -- Color the overall percentage based on coverage level
  local overall_color = "red"
  if report.overall_pct >= min_coverage_ok then
    overall_color = "green"
  elseif report.overall_pct >= min_coverage_warn then
    overall_color = "yellow"
  end

  -- Add overall percentage with error handling
  local add_overall_success, _ = get_error_handler().try(function()
    table.insert(
      output,
      string.format(
        "Overall Coverage: %s",
        self:colorize(string.format("%.1f%%", report.overall_pct), overall_color, config)
      )
    )
    return true
  end)

  if not add_overall_success then
    get_logger().warn("Failed to add overall coverage to summary", {
      formatter = self.name,
    })
    -- Add simpler version as fallback
    table.insert(output, "Overall Coverage: " .. tostring(report.overall_pct) .. "%")
  end

  -- Add detailed stats with error handling
  local add_stats_success, _ = get_error_handler().try(function()
    table.insert(
      output,
      string.format("Files: %s/%s (%.1f%%)", report.covered_files, report.total_files, report.files_pct)
    )
    table.insert(
      output,
      string.format("Lines: %s/%s (%.1f%%)", report.covered_lines, report.total_lines, report.lines_pct)
    )
    table.insert(
      output,
      string.format("Functions: %s/%s (%.1f%%)", report.covered_functions, report.total_functions, report.functions_pct)
    )
    return true
  end)

  if not add_stats_success then
    get_logger().warn("Failed to add detailed stats to coverage summary", {
      formatter = self.name,
    })
    -- Add simpler versions as fallback
    table.insert(output, "Files: " .. tostring(report.covered_files) .. "/" .. tostring(report.total_files))
    table.insert(output, "Lines: " .. tostring(report.covered_lines) .. "/" .. tostring(report.total_lines))
    table.insert(output, "Functions: " .. tostring(report.covered_functions) .. "/" .. tostring(report.total_functions))
  end

  -- Add detailed file information if configured with error handling
  if config.show_files and config.detailed and report.files then
    local add_detail_header_success, _ = get_error_handler().try(function()
      table.insert(output, "")
      table.insert(output, self:colorize("File Details", "bold", config))
      table.insert(output, self:colorize("------------", "bold", config))
      return true
    end)

    if not add_detail_header_success then
      get_logger().warn("Failed to add detail header to coverage summary", {
        formatter = self.name,
      })
      -- Skip file details section
    else
      -- Continue with file details
      local files_list = {}

      -- Build file list with error handling
      local build_list_success, _ = get_error_handler().try(function()
        for file_path, file_data in pairs(report.files) do
          table.insert(files_list, {
            path = file_path,
            pct = file_data.line_coverage_percent or 0,
          })
        end
        return true
      end)

      if not build_list_success then
        get_logger().warn("Failed to build file list for coverage summary", {
          formatter = self.name,
        })
        -- Continue with empty files_list
      end

      -- Sort files by coverage percentage with error handling
      local sort_success, _ = get_error_handler().try(function()
        table.sort(files_list, function(a, b)
          return a.pct < b.pct
        end)
        return true
      end)

      if not sort_success then
        get_logger().warn("Failed to sort file list for coverage summary", {
          formatter = self.name,
          files_count = #files_list,
        })
        -- Continue with unsorted files_list
      end

      -- Add each file with error handling
      for _, file in ipairs(files_list) do
        local add_file_success, _ = get_error_handler().try(function()
          local file_color = "red"
          if file.pct >= config.min_coverage_ok then
            file_color = "green"
          elseif file.pct >= config.min_coverage_warn then
            file_color = "yellow"
          end

          table.insert(
            output,
            string.format("%s: %s", file.path, self:colorize(string.format("%.1f%%", file.pct), file_color, config))
          )
          return true
        end)

        if not add_file_success then
          get_logger().warn("Failed to add file to coverage summary", {
            formatter = self.name,
            file_path = tostring(file.path),
          })
          -- Continue with next file
        end
      end
    end
  end

  -- Prepare the formatted output string with error handling
  local formatted_output
  local format_success, concat_result = get_error_handler().try(function()
    return table.concat(output, "\n")
  end)

  if format_success then
    formatted_output = concat_result
  else
    get_logger().error("Failed to format coverage summary output", {
      formatter = self.name,
      output_length = #output,
      error = get_error_handler().format_error(concat_result),
    })
    formatted_output = "Error formatting coverage summary"
  end

  -- Return both the formatted string and structured data for programmatic use
  return {
    output = formatted_output, -- String representation for display
    overall_pct = report.overall_pct,
    total_files = report.total_files,
    covered_files = report.covered_files,
    files_pct = report.files_pct,
    total_lines = report.total_lines,
    covered_lines = report.covered_lines,
    lines_pct = report.lines_pct,
    total_functions = report.total_functions,
    covered_functions = report.covered_functions,
    functions_pct = report.functions_pct,
  }
end

--- Format quality data as a text summary
---@param self SummaryFormatter The formatter instance.
---@param quality_data QualityReportData The quality data to format (expects `level`, `level_name`, `summary`).
---@param config table Configuration for the formatter.
---@param options? table Optional additional formatting options (currently unused).
---@return table report A table containing the formatted `output` string and key quality metrics (level, level_name, tests_analyzed, tests_passing, quality_pct, issues). Returns a default structure with zeros/unknown if input is invalid.
function SummaryFormatter:format_quality(quality_data, config, options)
  get_logger().debug("Formatting quality summary", {
    level = quality_data and quality_data.level or 0,
    level_name = quality_data and quality_data.level_name or "unknown",
    has_summary = quality_data and quality_data.summary ~= nil,
    detailed = config.detailed,
    colorize = config.colorize,
  })

  -- Validate input
  if not quality_data then
    get_logger().error("Missing quality data", {
      formatter = self.name,
      data_type = type(quality_data),
    })

    local output = {}
    table.insert(output, self:colorize("Quality Summary", "bold", config))
    table.insert(output, self:colorize("--------------", "bold", config))
    table.insert(output, "No quality data available")

    return {
      output = table.concat(output, "\n"),
      level = 0,
      level_name = "unknown",
      tests_analyzed = 0,
      tests_passing = 0,
      quality_pct = 0,
      issues = {},
    }
  end

  -- Extract useful data for report
  local report = {
    level = quality_data.level or 0,
    level_name = quality_data.level_name or "unknown",
    tests_analyzed = quality_data.summary and quality_data.summary.tests_analyzed or 0,
    tests_passing = quality_data.summary and quality_data.summary.tests_passing_quality or 0,
    quality_pct = quality_data.summary and quality_data.summary.quality_percent or 0,
    issues = quality_data.summary and quality_data.summary.issues or {},
  }

  -- Format quality as a string based on configuration
  local output = {}

  -- Add header
  table.insert(output, self:colorize("Quality Summary", "bold", config))
  table.insert(output, self:colorize("--------------", "bold", config))

  -- Make sure config has valid thresholds
  local min_coverage_ok = config.min_coverage_ok or DEFAULT_CONFIG.min_coverage_ok
  local min_coverage_warn = config.min_coverage_warn or DEFAULT_CONFIG.min_coverage_warn

  -- Color the quality percentage based on level
  local quality_color = "red"
  if report.quality_pct >= min_coverage_ok then
    quality_color = "green"
  elseif report.quality_pct >= min_coverage_warn then
    quality_color = "yellow"
  end

  -- Add quality level and percentage
  table.insert(
    output,
    string.format(
      "Quality Level: %s (%s)",
      report.level_name,
      self:colorize(string.format("Level %d", report.level), "cyan", config)
    )
  )
  table.insert(
    output,
    string.format(
      "Quality Rating: %s",
      self:colorize(string.format("%.1f%%", report.quality_pct), quality_color, config)
    )
  )

  -- Add test stats
  table.insert(output, string.format("Tests Analyzed: %d", report.tests_analyzed))
  table.insert(
    output,
    string.format(
      "Tests Passing Quality Validation: %d/%d (%.1f%%)",
      report.tests_passing,
      report.tests_analyzed,
      report.tests_analyzed > 0 and (report.tests_passing / report.tests_analyzed * 100) or 0
    )
  )

  -- Add issues if detailed mode is enabled with error handling
  if config.detailed and report.issues and #report.issues > 0 then
    local add_issues_success, _ = get_error_handler().try(function()
      table.insert(output, "")
      table.insert(output, self:colorize("Quality Issues", "bold", config))
      table.insert(output, self:colorize("-------------", "bold", config))

      for _, issue in ipairs(report.issues) do
        local issue_text = string.format(
          "%s: %s",
          self:colorize(issue.test or "Unknown", "bold", config),
          issue.issue or "Unknown issue"
        )

        table.insert(output, issue_text)
      end

      return true
    end)

    if not add_issues_success then
      get_logger().warn("Failed to add issues to quality summary", {
        formatter = self.name,
        issues_count = #report.issues,
      })
      -- Skip issues section on error
    end
  end

  -- Prepare the formatted output string with error handling
  local formatted_output
  local format_success, concat_result = get_error_handler().try(function()
    return table.concat(output, "\n")
  end)

  if format_success then
    formatted_output = concat_result
  else
    get_logger().error("Failed to format quality summary output", {
      formatter = self.name,
      output_length = #output,
      error = get_error_handler().format_error(concat_result),
    })
    formatted_output = "Error formatting quality summary"
  end

  -- Return both the formatted string and structured data for programmatic use
  return {
    output = formatted_output, -- String representation for display
    level = report.level,
    level_name = report.level_name,
    tests_analyzed = report.tests_analyzed,
    tests_passing = report.tests_passing,
    quality_pct = report.quality_pct,
    issues = report.issues,
  }
end

--- Write formatted data to a file
-- @param self SummaryFormatter The formatter instance
---@param formatted_data table The table returned by the `format` method (must contain an `output` string field).
---@param output_path string The path to write the file to.
---@param options? table Optional configuration passed to the base `write` method.
---@return boolean success Whether the write operation succeeded.
---@return table? error Error object if write failed.
---@throws table If writing fails critically.
function SummaryFormatter:write(formatted_data, output_path, options)
  -- Leverage the base class write implementation
  return Formatter.write(self, formatted_data, output_path, options)
end

--- Generate a complete summary report
-- @param self SummaryFormatter The formatter instance
---@param data table The data to format (coverage or quality).
---@param output_path string The path to write the report to.
---@param options? table Optional configuration passed to `format` and `write`.
---@return boolean success Whether report generation succeeded.
---@return string|table? path_or_error The report `output_path` string if successful, or error object if failed.
---@throws table If validation, formatting, or writing fails critically.
function SummaryFormatter:generate(data, output_path, options)
  -- Leverage the base class generate implementation
  return Formatter.generate(self, data, output_path, options)
end

--- Register the Summary formatter with the formatters registry
---@param formatters table The main formatters registry object (must contain `coverage` and `quality` tables).
---@return boolean success `true` if registration succeeded.
---@return table? error Error object if validation failed.
---@throws table If validation fails critically.
function SummaryFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    local err = get_error_handler().validation_error("Invalid formatters registry", {
      operation = "register",
      formatter = "summary",
      provided_type = type(formatters),
    })
    return false, err
  end

  -- Create a new instance of the formatter
  local formatter = SummaryFormatter.new()

  -- Ensure coverage and quality tables exist
  formatters.coverage = formatters.coverage or {}
  formatters.quality = formatters.quality or {}

  -- Register format functions
  formatters.coverage.summary = function(coverage_data, options)
    return formatter:format(coverage_data, options)
  end

  formatters.quality.summary = function(quality_data, options)
    return formatter:format(quality_data, options)
  end

  return true
end

return SummaryFormatter
