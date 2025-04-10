---@class ReportingValidation
---@field _VERSION string Module version
---@field validate_coverage_data fun(coverage_data: table): boolean, table Validates coverage data structure against schema
---@field analyze_coverage_statistics fun(coverage_data: table): table Performs statistical analysis of coverage data
---@field cross_check_with_static_analysis fun(coverage_data: table): table Cross-checks coverage data with static analysis
---@field get_validation_issues fun(): table<number, {severity: string, message: string, context: table, file?: string, line?: number}> Returns all validation issues found
---@field reset_validation_issues fun() Resets the validation issues list
---@field validate_report_format fun(data: any, format: string): boolean, string? Validates report format against schema
---@field validate_report fun(coverage_data: table, options?: {validate_schema?: boolean, analyze_statistics?: boolean, cross_check?: boolean, validate_files?: boolean}): table Performs comprehensive report validation
---@field validate_file_paths fun(coverage_data: table): boolean, table Validates that file paths exist and are readable
---@field validate_test_results fun(results_data: table): boolean, table Validates test results data structure
---@field configure fun(options: table): boolean Configure validation options
---@field is_coverage_threshold_met fun(coverage_data: table, threshold: number): boolean, table Check if coverage meets threshold
---@field get_error_summary fun(): string Get a human-readable summary of validation errors
-- Validation module for coverage reports and test results
-- Ensures data conforms to expected schemas and performs sanity checks
local M = {}

local logging = require("lib.tools.logging")

-- Create a logger for this module
local logger = logging.get_logger("Reporting:Validation")

-- Configure module logging
logging.configure_from_config("Reporting:Validation")

-- Default validation configuration
local DEFAULT_CONFIG = {
  validate_reports = true,
  validate_line_counts = true,
  validate_percentages = true,
  validate_file_paths = true,
  validate_function_counts = true,
  validate_block_counts = true,
  validate_cross_module = true,
  validation_threshold = 0.5, -- 0.5% tolerance for percentage mismatches
  warn_on_validation_failure = true,
}

--- Get the validation configuration from central_config or fall back to defaults
---@private
---@return table config The validation configuration with all necessary fields
local function get_config()
  -- Try to load central_config module
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    local validation_config = central_config.get("reporting.validation")
    if validation_config then
      return validation_config
    end
  end

  -- Fall back to default configuration
  return DEFAULT_CONFIG
end

--- Register the validation configuration schema with central_config
---@private
---@return boolean success Whether the schema was successfully registered
local function register_config_schema()
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    local register_success = central_config.register_module("reporting.validation", {
      validate_reports = { type = "boolean", default = true },
      validate_line_counts = { type = "boolean", default = true },
      validate_percentages = { type = "boolean", default = true },
      validate_file_paths = { type = "boolean", default = true },
      validate_function_counts = { type = "boolean", default = true },
      validate_block_counts = { type = "boolean", default = true },
      validate_cross_module = { type = "boolean", default = true },
      validation_threshold = { type = "number", default = 0.5 },
      warn_on_validation_failure = { type = "boolean", default = true },
    })
    return register_success == true
  end

  return false
end

-- Try to register with central_config
register_config_schema()

-- List of validation issues
local validation_issues = {}

--- Add a validation issue to the issues list and log it appropriately
---@private
---@param category string The issue category (e.g., "schema_validation", "line_count")
---@param message string The human-readable issue message
---@param severity? string The issue severity ("error" or "warning", defaults to "warning")
---@param details? table<string, any> Additional contextual details about the issue
local function add_issue(category, message, severity, details)
  table.insert(validation_issues, {
    category = category,
    message = message,
    severity = severity or "warning",
    details = details or {},
  })

  -- Log the issue
  if severity == "error" then
    logger.error(message, details or {})
  else
    logger.warn(message, details or {})
  end
end

--- Validate that line counts in the summary match the sum of file line counts
---@private
---@param coverage_data {summary: table, files: table<string, table>} The coverage data to validate
---@return boolean valid Whether the line counts are valid and consistent
local function validate_line_counts(coverage_data)
  local config = get_config()
  if not config.validate_line_counts then
    return true
  end

  local valid = true

  -- Validate summary line counts
  if coverage_data and coverage_data.summary then
    local summary = coverage_data.summary

    -- Count files and lines directly to validate the summary
    local total_files = 0
    local total_lines = 0
    local executable_lines = 0
    local executed_lines = 0
    local covered_lines = 0
    local total_functions = 0
    local executed_functions = 0
    local covered_functions = 0
    local total_blocks = 0
    local covered_blocks = 0

    -- Validate files data
    if coverage_data.files then
      for filename, file_data in pairs(coverage_data.files) do
        total_files = total_files + 1

        -- Validate line counts
        if file_data.total_lines then
          total_lines = total_lines + file_data.total_lines
        end

        if file_data.executable_lines then
          executable_lines = executable_lines + file_data.executable_lines
        end

        if file_data.executed_lines then
          executed_lines = executed_lines + file_data.executed_lines
        end

        if file_data.covered_lines then
          covered_lines = covered_lines + file_data.covered_lines
        end

        -- Validate function counts
        if file_data.total_functions then
          total_functions = total_functions + file_data.total_functions
        end

        if file_data.executed_functions then
          executed_functions = executed_functions + file_data.executed_functions
        end

        if file_data.covered_functions then
          covered_functions = covered_functions + file_data.covered_functions
        end

        -- Validate block counts
        if file_data.total_blocks then
          total_blocks = total_blocks + file_data.total_blocks
        end

        if file_data.covered_blocks then
          covered_blocks = covered_blocks + file_data.covered_blocks
        end

        -- Validate per-file percentages
        if file_data.line_coverage_percent and file_data.executable_lines > 0 then
          local calculated_pct = (file_data.covered_lines / file_data.executable_lines) * 100
          local diff = math.abs(calculated_pct - file_data.line_coverage_percent)

          if diff > config.validation_threshold then
            add_issue("line_percentage", "Line coverage percentage doesn't match calculation", "warning", {
              file = filename,
              reported = file_data.line_coverage_percent,
              calculated = calculated_pct,
              difference = diff,
              covered_lines = file_data.covered_lines,
              executable_lines = file_data.executable_lines,
            })
            valid = false
          end
        end
      end

      -- Validate summary against calculated totals
      if math.abs(total_files - (summary.total_files or 0)) > 0 then
        add_issue("file_count", "Total file count doesn't match actual file count", "warning", {
          reported = summary.total_files,
          calculated = total_files,
        })
        valid = false
      end

      if math.abs(total_lines - (summary.total_lines or 0)) > 0 then
        add_issue("line_count", "Total line count doesn't match sum of file line counts", "warning", {
          reported = summary.total_lines,
          calculated = total_lines,
        })
        valid = false
      end

      if math.abs(executable_lines - (summary.executable_lines or 0)) > 0 then
        add_issue("executable_lines", "Executable line count doesn't match sum of file executable lines", "warning", {
          reported = summary.executable_lines,
          calculated = executable_lines,
        })
        valid = false
      end

      if math.abs(executed_lines - (summary.executed_lines or 0)) > 0 then
        add_issue("executed_lines", "Executed line count doesn't match sum of file executed lines", "warning", {
          reported = summary.executed_lines,
          calculated = executed_lines,
          difference = math.abs(executed_lines - (summary.executed_lines or 0)),
        })
        valid = false
      end

      if math.abs(covered_lines - (summary.covered_lines or 0)) > 0 then
        add_issue("covered_lines", "Covered line count doesn't match sum of file covered lines", "warning", {
          reported = summary.covered_lines,
          calculated = covered_lines,
          difference = math.abs(covered_lines - (summary.covered_lines or 0)),
        })
        valid = false
      end

      -- Validate function counts
      if summary.total_functions and math.abs(total_functions - summary.total_functions) > 0 then
        add_issue("function_count", "Total function count doesn't match sum of file function counts", "warning", {
          reported = summary.total_functions,
          calculated = total_functions,
          difference = math.abs(total_functions - summary.total_functions),
        })
        valid = false
      end

      if summary.executed_functions and math.abs(executed_functions - summary.executed_functions) > 0 then
        add_issue(
          "executed_functions",
          "Executed function count doesn't match sum of file executed functions",
          "warning",
          {
            reported = summary.executed_functions,
            calculated = executed_functions,
            difference = math.abs(executed_functions - summary.executed_functions),
          }
        )
        valid = false
      end

      if summary.covered_functions and math.abs(covered_functions - summary.covered_functions) > 0 then
        add_issue(
          "covered_functions",
          "Covered function count doesn't match sum of file covered functions",
          "warning",
          {
            reported = summary.covered_functions,
            calculated = covered_functions,
            difference = math.abs(covered_functions - summary.covered_functions),
          }
        )
        valid = false
      end

      -- Validate block counts if present
      if summary.total_blocks and math.abs(total_blocks - summary.total_blocks) > 0 then
        add_issue("block_count", "Total block count doesn't match sum of file block counts", "warning", {
          reported = summary.total_blocks,
          calculated = total_blocks,
        })
        valid = false
      end

      if summary.covered_blocks and math.abs(covered_blocks - summary.covered_blocks) > 0 then
        add_issue("covered_blocks", "Covered block count doesn't match sum of file covered blocks", "warning", {
          reported = summary.covered_blocks,
          calculated = covered_blocks,
        })
        valid = false
      end
    end
  else
    add_issue("missing_summary", "Coverage report is missing summary data", "error")
    valid = false
  end

  return valid
end

---@private
---@param coverage_data table The coverage data to validate percentages for
---@return boolean valid Whether the percentages are valid
local function validate_percentages(coverage_data)
  local config = get_config()
  if not config.validate_percentages then
    return true
  end

  local valid = true

  -- Validate summary percentages
  if coverage_data and coverage_data.summary then
    local summary = coverage_data.summary

    -- Validate line coverage percentage
    if summary.executable_lines and summary.executable_lines > 0 and summary.covered_lines then
      local calculated_pct = (summary.covered_lines / summary.executable_lines) * 100

      if
        summary.line_coverage_percent ~= nil
        and math.abs(calculated_pct - summary.line_coverage_percent) > config.validation_threshold
      then
        add_issue("line_percentage", "Line coverage percentage doesn't match calculation", "warning", {
          reported = summary.line_coverage_percent,
          calculated = calculated_pct,
          covered_lines = summary.covered_lines,
          executable_lines = summary.executable_lines,
        })
        valid = false
      end
    end

    -- Validate function coverage percentage
    if summary.total_functions and summary.total_functions > 0 and summary.covered_functions then
      local calculated_pct = (summary.covered_functions / summary.total_functions) * 100

      if
        summary.function_coverage_percent ~= nil
        and math.abs(calculated_pct - summary.function_coverage_percent) > config.validation_threshold
      then
        add_issue("function_percentage", "Function coverage percentage doesn't match calculation", "warning", {
          reported = summary.function_coverage_percent,
          calculated = calculated_pct,
          covered_functions = summary.covered_functions,
          total_functions = summary.total_functions,
        })
        valid = false
      end
    end

    -- Validate block coverage percentage
    if summary.total_blocks and summary.total_blocks > 0 and summary.covered_blocks then
      local calculated_pct = (summary.covered_blocks / summary.total_blocks) * 100

      if
        summary.block_coverage_percent ~= nil
        and math.abs(calculated_pct - summary.block_coverage_percent) > config.validation_threshold
      then
        add_issue("block_percentage", "Block coverage percentage doesn't match calculation", "warning", {
          reported = summary.block_coverage_percent,
          calculated = calculated_pct,
        })
        valid = false
      end
    end

    -- Validate overall percentage (weighted average)
    if summary.overall_percent then
      -- Calculate weighted average based on available metrics
      local has_blocks = summary.total_blocks and summary.total_blocks > 0
      local line_weight = has_blocks and 0.4 or 0.8
      local function_weight = has_blocks and 0.2 or 0.2
      local block_weight = has_blocks and 0.4 or 0

      local line_pct = summary.line_coverage_percent
        or (
          summary.executable_lines
            and summary.executable_lines > 0
            and summary.covered_lines
            and (summary.covered_lines / summary.executable_lines * 100)
          or 0
        )

      local function_pct = summary.function_coverage_percent
        or (
          summary.total_functions
            and summary.total_functions > 0
            and summary.covered_functions
            and (summary.covered_functions / summary.total_functions * 100)
          or 0
        )

      local block_pct = summary.block_coverage_percent
        or (
          summary.total_blocks
            and summary.total_blocks > 0
            and summary.covered_blocks
            and (summary.covered_blocks / summary.total_blocks * 100)
          or 0
        )

      local calculated_overall = (line_pct * line_weight)
        + (function_pct * function_weight)
        + (block_pct * block_weight)

      local validation_threshold = config.validation_threshold or DEFAULT_CONFIG.validation_threshold

      -- Check if summary.overall_percent is nil before comparison
      if
        summary.overall_percent ~= nil
        and math.abs(calculated_overall - summary.overall_percent) > validation_threshold
      then
        add_issue("overall_percentage", "Overall coverage percentage doesn't match weighted calculation", "warning", {
          reported = summary.overall_percent,
          calculated = calculated_overall,
          line_pct = line_pct,
          function_pct = function_pct,
          block_pct = block_pct,
          weights = {
            line = line_weight,
            func = function_weight,
            block = block_weight,
          },
        })
        valid = false
      end
    end
  else
    -- This issue would already be reported by validate_line_counts
    valid = false
  end

  return valid
end

---@private
---@param coverage_data table The coverage data to validate file paths for
---@return boolean valid Whether the file paths are valid
local function validate_file_paths(coverage_data)
  local config = get_config()
  if not config.validate_file_paths then
    return true
  end

  local valid = true

  -- Check if we have fs module available
  local fs_available, fs = pcall(require, "lib.tools.filesystem")
  if not fs_available then
    logger.warn("Filesystem module not available, skipping file path validation")
    return true
  end

  -- Check that files exist
  if coverage_data and coverage_data.files then
    for filename, _ in pairs(coverage_data.files) do
      -- Only validate absolute paths
      if filename:match("^/") then
        if not fs.file_exists(filename) then
          add_issue("file_path", "Coverage report references file that doesn't exist", "warning", {
            file = filename,
          })
          valid = false
        end
      end
    end
  end

  return valid
end

---@private
---@param coverage_data table The coverage data to validate cross-module references for
---@return boolean valid Whether the cross-module references are valid
local function validate_cross_module(coverage_data)
  local config = get_config()
  if not config.validate_cross_module then
    return true
  end

  local valid = true

  -- Check if original_files data matches files data
  if coverage_data and coverage_data.files and coverage_data.original_files then
    local files_count = 0
    local orig_files_count = 0

    -- Count files
    for _ in pairs(coverage_data.files) do
      files_count = files_count + 1
    end

    for _ in pairs(coverage_data.original_files) do
      orig_files_count = orig_files_count + 1
    end

    if files_count ~= orig_files_count then
      add_issue("cross_module", "File count mismatch between files and original_files", "warning", {
        files_count = files_count,
        original_files_count = orig_files_count,
      })
      valid = false
    end

    -- Check for files that don't have matching original_files data
    for filename, _ in pairs(coverage_data.files) do
      if not coverage_data.original_files[filename] then
        add_issue("cross_module", "Coverage file missing from original_files data", "warning", {
          file = filename,
        })
        valid = false
      end
    end
  end

  return valid
end

---@param coverage_data table The coverage data to validate
---@return boolean is_valid Whether the coverage data is valid
---@return table validation_issues List of validation issues
function M.validate_coverage_data(coverage_data)
  -- Reset issues list
  validation_issues = {}

  -- Count files in a safer way than using deprecated table.getn
  local file_count = 0
  if coverage_data and coverage_data.files then
    for _ in pairs(coverage_data.files) do
      file_count = file_count + 1
    end
  end

  logger.debug("Starting coverage report validation", {
    has_data = coverage_data ~= nil,
    has_summary = coverage_data and coverage_data.summary ~= nil,
    has_files = coverage_data and coverage_data.files ~= nil,
    file_count = file_count,
  })

  local config = get_config() or DEFAULT_CONFIG

  -- Ensure we have valid config values
  local validate_reports = config.validate_reports
  if validate_reports == nil then
    validate_reports = DEFAULT_CONFIG.validate_reports
  end

  -- Skip validation if disabled
  if not validate_reports then
    logger.info("Coverage report validation is disabled in configuration")
    return true, {}
  end

  -- Basic data structure validation
  if not coverage_data then
    add_issue("data_structure", "Coverage data is nil", "error")
    return false, validation_issues
  end

  if not coverage_data.summary then
    add_issue("data_structure", "Coverage data is missing summary section", "error")
    return false, validation_issues
  end

  if not coverage_data.files then
    add_issue("data_structure", "Coverage data is missing files section", "error")
    return false, validation_issues
  end

  -- Schema validation
  local schema_validation_ok = true
  local schema_error
  local schema_module

  -- Try to load schema module
  local schema_load_success, module = pcall(require, "lib.reporting.schema")
  if schema_load_success then
    schema_module = module

    -- Perform schema validation
    schema_validation_ok, schema_error = schema_module.validate(coverage_data, "COVERAGE_SCHEMA")
    if not schema_validation_ok then
      add_issue("schema_validation", "Coverage data failed schema validation: " .. tostring(schema_error), "error", {
        error = schema_error,
      })
    else
      logger.debug("Schema validation passed")
    end
  else
    -- Schema module not available
    logger.debug("Schema module not available, skipping schema validation", {
      error = tostring(module),
    })
  end

  -- Run specific validation checks
  local line_counts_valid = validate_line_counts(coverage_data)
  local percentages_valid = validate_percentages(coverage_data)
  local file_paths_valid = validate_file_paths(coverage_data)
  local cross_module_valid = validate_cross_module(coverage_data)

  -- All validations must pass for the data to be considered valid
  local is_valid = schema_validation_ok
    and line_counts_valid
    and percentages_valid
    and file_paths_valid
    and cross_module_valid

  logger.info("Coverage report validation complete", {
    valid = is_valid,
    issues_found = #validation_issues,
    schema_validation_ok = schema_validation_ok,
    line_counts_valid = line_counts_valid,
    percentages_valid = percentages_valid,
    file_paths_valid = file_paths_valid,
    cross_module_valid = cross_module_valid,
  })

  -- Return validation result and issues
  return is_valid, validation_issues
end

---@param coverage_data table The coverage data to analyze
---@return table stats Statistical analysis results
function M.analyze_coverage_statistics(coverage_data)
  local stats = {
    median_line_coverage = 0,
    mean_line_coverage = 0,
    std_dev_line_coverage = 0,
    outliers = {},
    anomalies = {},
  }

  if not coverage_data or not coverage_data.files then
    return stats
  end

  -- Collect line coverage percentages for all files
  local percentages = {}
  local sum = 0

  for filename, file_data in pairs(coverage_data.files) do
    if file_data.line_coverage_percent then
      table.insert(percentages, {
        file = filename,
        pct = file_data.line_coverage_percent,
      })
      sum = sum + file_data.line_coverage_percent
    end
  end

  -- Calculate mean
  if #percentages > 0 then
    stats.mean_line_coverage = sum / #percentages

    -- Sort percentages for median calculation
    table.sort(percentages, function(a, b)
      return a.pct < b.pct
    end)

    -- Calculate median
    if #percentages % 2 == 0 then
      local mid = #percentages / 2
      stats.median_line_coverage = (percentages[mid].pct + percentages[mid + 1].pct) / 2
    else
      stats.median_line_coverage = percentages[math.ceil(#percentages / 2)].pct
    end

    -- Calculate standard deviation
    local variance_sum = 0
    for _, entry in ipairs(percentages) do
      variance_sum = variance_sum + (entry.pct - stats.mean_line_coverage) ^ 2
    end

    stats.std_dev_line_coverage = math.sqrt(variance_sum / #percentages)

    -- Identify outliers (more than 2 standard deviations from mean)
    for _, entry in ipairs(percentages) do
      local z_score = math.abs(entry.pct - stats.mean_line_coverage) / stats.std_dev_line_coverage
      if z_score > 2 then
        table.insert(stats.outliers, {
          file = entry.file,
          coverage = entry.pct,
          z_score = z_score,
        })
      end
    end

    -- Identify potential anomalies based on heuristics
    for filename, file_data in pairs(coverage_data.files) do
      -- Files with high line count but low coverage might need attention
      if
        file_data.total_lines
        and file_data.total_lines > 100
        and file_data.line_coverage_percent
        and file_data.line_coverage_percent < 20
      then
        table.insert(stats.anomalies, {
          file = filename,
          reason = "Large file with low coverage",
          details = {
            lines = file_data.total_lines,
            coverage = file_data.line_coverage_percent,
          },
        })
      end

      -- Check for odd ratios between line and function coverage
      if
        file_data.line_coverage_percent
        and file_data.function_coverage_percent
        and math.abs(file_data.line_coverage_percent - file_data.function_coverage_percent) > 50
      then
        table.insert(stats.anomalies, {
          file = filename,
          reason = "Large discrepancy between line and function coverage",
          details = {
            line_coverage = file_data.line_coverage_percent,
            function_coverage = file_data.function_coverage_percent,
            difference = math.abs(file_data.line_coverage_percent - file_data.function_coverage_percent),
          },
        })
      end
    end
  end

  logger.info("Statistical analysis complete", {
    files_analyzed = #percentages,
    mean = stats.mean_line_coverage,
    median = stats.median_line_coverage,
    std_dev = stats.std_dev_line_coverage,
    outliers = #stats.outliers,
    anomalies = #stats.anomalies,
  })

  return stats
end

---@param coverage_data table The coverage data to cross-check with static analysis
---@return table results The cross-check results
function M.cross_check_with_static_analysis(coverage_data)
  local results = {
    files_checked = 0,
    discrepancies = {},
    unanalyzed_files = {},
    analysis_success = false,
  }

  -- Get static analyzer if available
  local analyzer_available, static_analyzer = pcall(require, "lib.coverage.static_analyzer")
  if not analyzer_available then
    logger.warn("Static analyzer not available, skipping cross-check")
    return results
  end

  logger.info("Starting cross-check with static analysis")

  results.analysis_success = true

  if not coverage_data or not coverage_data.files then
    logger.warn("No coverage data available for cross-check")
    return results
  end

  -- Check each file against static analysis
  for filename, file_data in pairs(coverage_data.files) do
    -- Skip files with no source code
    if not coverage_data.original_files or not coverage_data.original_files[filename] then
      table.insert(results.unanalyzed_files, filename)
      goto continue
    end

    local original_file = coverage_data.original_files[filename]
    if not original_file.source then
      table.insert(results.unanalyzed_files, filename)
      goto continue
    end

    -- Run static analysis on the file
    local source = original_file.source
    if type(source) == "table" then
      source = table.concat(source, "\n")
    end

    local analysis_result, err = static_analyzer.analyze_source(source, filename)
    if not analysis_result then
      logger.warn("Static analysis failed for file", {
        file = filename,
        error = err,
      })
      results.analysis_success = false
      goto continue
    end

    results.files_checked = results.files_checked + 1

    -- Compare static analysis with coverage data
    local discrepancies = {}

    -- Check executable lines
    for line_num, is_executable in pairs(analysis_result.executable_lines or {}) do
      local coverage_executable = original_file.executable_lines and original_file.executable_lines[line_num]

      if is_executable ~= coverage_executable then
        table.insert(discrepancies, {
          line = line_num,
          type = "executable_line",
          static_analysis = is_executable,
          coverage_data = coverage_executable,
        })
      end
    end

    -- Check function positions
    for _, func in ipairs(analysis_result.functions or {}) do
      local found = false
      for _, coverage_func in ipairs(original_file.functions or {}) do
        if func.start_line == coverage_func.start_line and func.name == coverage_func.name then
          found = true
          break
        end
      end

      if not found then
        table.insert(discrepancies, {
          type = "function",
          name = func.name,
          start_line = func.start_line,
          end_line = func.end_line,
          issue = "Function found by static analysis but not in coverage data",
        })
      end
    end

    -- Add discrepancies to results if any were found
    if #discrepancies > 0 then
      results.discrepancies[filename] = discrepancies
    end

    ::continue::
  end

  -- Count discrepancies
  local discrepancy_count = 0
  if results.discrepancies then
    for _ in pairs(results.discrepancies) do
      discrepancy_count = discrepancy_count + 1
    end
  end

  logger.info("Static analysis cross-check complete", {
    files_checked = results.files_checked,
    files_with_discrepancies = discrepancy_count,
    unanalyzed_files = #results.unanalyzed_files,
  })

  return results
end

---@return table validation_issues List of validation issues found
function M.get_validation_issues()
  return validation_issues
end

---@return nil
function M.reset_validation_issues()
  validation_issues = {}
end

---@param data any The data to validate
---@param format string The format name to validate against
---@return boolean success Whether the format is valid
---@return string? error_message Error message if validation failed
function M.validate_report_format(data, format)
  logger.debug("Validating report format", { format = format })

  -- Try to load schema module
  local schema_module
  local ok, module = pcall(require, "lib.reporting.schema")
  if ok then
    schema_module = module

    -- Use schema module to validate format
    local is_valid, err = schema_module.validate_format(data, format)

    if not is_valid then
      add_issue("format_validation", "Report format validation failed: " .. tostring(err), "error", {
        format = format,
        error = err,
      })
      return false, "Format validation failed: " .. tostring(err)
    end

    logger.debug("Format validation successful", { format = format })
    return true
  else
    logger.debug("Schema module not available, skipping format validation", {
      error = tostring(module),
    })
    -- Skip validation if schema module is not available
    return true
  end
end

---@param coverage_data table The coverage data to validate
---@param options? table Options for validation
---@return table validation_result The comprehensive validation results
function M.validate_report(coverage_data, options)
  options = options or {}

  logger.debug("Running comprehensive report validation", {
    has_data = coverage_data ~= nil,
    has_options = options ~= nil,
    format = options.format,
  })

  -- Start with basic validation
  local is_valid, issues = M.validate_coverage_data(coverage_data)

  -- Run statistical analysis
  local stats = M.analyze_coverage_statistics(coverage_data)

  -- Cross-check with static analysis
  local cross_check = M.cross_check_with_static_analysis(coverage_data)

  -- Formatted output validation
  local format_validation = {
    is_valid = true,
    issues = {},
  }

  -- If format is provided, validate the formatted output
  if options.format and options.formatted_output then
    local format_valid, format_error = M.validate_report_format(options.formatted_output, options.format)

    format_validation.is_valid = format_valid
    if not format_valid then
      format_validation.issues = {
        {
          category = "format_validation",
          message = "Format validation failed for " .. options.format,
          details = {
            format = options.format,
            error = format_error,
          },
        },
      }
    end
  end

  -- Combine all results
  local result = {
    validation = {
      is_valid = is_valid,
      issues = issues,
    },
    statistics = stats,
    cross_check = cross_check,
    format_validation = format_validation,
  }

  logger.info("Comprehensive validation complete", {
    data_valid = is_valid,
    format_valid = format_validation.is_valid,
    issues = #issues,
    format_issues = #format_validation.issues,
    statistics = {
      outliers = #stats.outliers,
      anomalies = #stats.anomalies,
    },
  })

  return result
end

-- Return the module
return M

