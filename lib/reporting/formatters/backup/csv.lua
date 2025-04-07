---@class CSVFormatter
---@field _VERSION string Module version
---@field format_results fun(results_data: {name: string, tests: number, failures?: number, errors?: number, skipped?: number, time?: number, timestamp?: string, test_cases?: table<number, {name: string, classname?: string, time?: number, status?: string, failure?: table, error?: table}>}): string|nil, table? Format test results as CSV
---@field format_coverage fun(coverage_data: {files: table<string, table>, summary: table}): string|nil, table? Format coverage data as CSV
---@field get_config fun(): CSVFormatterConfig Get current formatter configuration
---@field set_config fun(config: table): boolean Set formatter configuration options
---@field escape_field fun(field: any): string Escape a field value according to CSV rules
---@field validate_results fun(results_data: table): boolean, string? Validate test results data before formatting
-- CSV formatter for test results and coverage data
-- Creates CSV-formatted output suitable for spreadsheet programs or data analysis
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:CSV")

-- Add error_handler dependency
local error_handler = require("lib.tools.error_handler")

-- Configure module logging
logging.configure_from_config("Reporting:CSV")

---@class CSVFormatterConfig
---@field delimiter string Field delimiter character (e.g., comma, tab, semicolon)
---@field quote string Quote character for fields containing special characters
---@field double_quote boolean Whether to double quotes for escaping
---@field include_header boolean Whether to include header row with column names
---@field include_summary boolean Whether to include summary row at end
---@field newline string Line ending character(s) (CR, LF, or CRLF)
---@field columns? string[] Optional array of columns to include (and their order)
---@field escape_special_chars boolean Whether to escape special characters
---@field null_value string String to use for nil values
---@field true_value string String to use for true values
---@field false_value string String to use for false values
---@field precision? number Optional decimal precision for numbers
---@field null_placeholder string Value to use when a field is missing
---@field dateformat? string Optional date format string for timestamp fields
---@field date_format string Date format for timestamps
---@field fields string[] Fields to include in output (in order)

-- Define default configuration
---@type CSVFormatterConfig
local DEFAULT_CONFIG = {
  delimiter = ",",               -- Field delimiter character
  quote = "\"",                  -- Quote character for fields
  double_quote = true,           -- Double quotes for escaping
  include_header = true,         -- Include header row
  include_summary = false,       -- Include summary row at end
  date_format = "%Y-%m-%dT%H:%M:%S", -- Date format for timestamps
  fields = {                     -- Fields to include in output (in order)
    "test_id", 
    "test_suite", 
    "test_name", 
    "status", 
    "duration", 
    "message", 
    "error_type", 
    "details", 
    "timestamp"
  }
}

---@private
---@return CSVFormatterConfig config The configuration for the CSV formatter
-- Get configuration for this formatter
local function get_config()
  -- Try reporting module first with error handling
  local success, result, err = error_handler.try(function()
    local reporting = require("lib.reporting")
    if reporting.get_formatter_config then
      local formatter_config = reporting.get_formatter_config("csv")
      if formatter_config then 
        logger.debug("Using configuration from reporting module")
        return formatter_config 
      end
    end
    return nil
  end)
  
  if success and result then
    return result
  end
  
  -- Try central_config directly with error handling
  local config_success, config_result = error_handler.try(function()
    local central_config = require("lib.core.central_config")
    local formatter_config = central_config.get("reporting.formatters.csv")
    if formatter_config then 
      logger.debug("Using configuration from central_config")
      return formatter_config 
    end
    return nil
  end)
  
  if config_success and config_result then
    return config_result
  end
  
  -- Fall back to defaults
  logger.debug("Using default configuration", {
    reason = "Could not load from reporting or central_config",
    module = "reporting.formatters.csv"
  })
  
  return DEFAULT_CONFIG
end

---@private
---@param s any Value to escape (will be converted to string if not a string)
---@param config CSVFormatterConfig|nil Formatter configuration
---@return string escaped_value The CSV-escaped string
-- Helper to escape CSV field values based on configuration
local function escape_csv(s, config)
  -- Handle nil or non-string values safely
  if type(s) ~= "string" then
    local safe_str = tostring(s or "")
    logger.debug("Converting non-string value to string for CSV escaping", {
      original_type = type(s),
      result_length = #safe_str
    })
    s = safe_str
  end
  
  -- Validate config with safe fallbacks
  local safe_config = config or {}
  local delimiter = safe_config.delimiter or ","
  local quote = safe_config.quote or "\""
  
  -- Use error handling for string operations
  local success, result = error_handler.try(function()
    local needs_quotes = false
    
    -- Check if the string contains characters requiring quotes
    if s:find('[' .. delimiter .. quote .. '\r\n]') then
      needs_quotes = true
    end
    
    if needs_quotes then
      if safe_config.double_quote then
        -- Double the quote characters for escaping
        local escaped = s:gsub(quote, quote .. quote)
        return quote .. escaped .. quote
      else
        -- Simple quoting without doubling
        return quote .. s .. quote
      end
    else
      return s
    end
  end)
  
  if success then
    return result
  else
    -- If string operations fail, log the error and return a safe alternative
    local err = error_handler.runtime_error(
      "Failed to escape CSV string",
      {
        operation = "escape_csv",
        module = "reporting.formatters.csv",
        string_length = #s
      },
      result -- On failure, result contains the error
    )
    logger.warn(err.message, err.context)
    
    -- Use a simpler fallback that should be more robust
    local fallback_success, fallback_result = error_handler.try(function()
      -- Always quote the string as a safe fallback
      if safe_config.double_quote then
        local safe_str = s:gsub(quote, quote .. quote)
        return quote .. safe_str .. quote
      else
        -- Use simple quoting for the fallback
        return quote .. s .. quote
      end
    end)
    
    if fallback_success then
      return fallback_result
    else
      -- If even the fallback fails, return a sanitized string
      logger.error("CSV escaping fallback also failed, using basic sanitization", {
        error = error_handler.format_error(fallback_result)
      })
      -- Return a sanitized string in quotes
      return quote .. "SANITIZED" .. quote
    end
  end
end

---@private
---@param config CSVFormatterConfig Formatter configuration
---@param ... any Field values to format as a CSV line
---@return string csv_line A single line of CSV-formatted data
-- Helper to create a CSV line from field values
local function csv_line(config, ...)
  -- Validate parameters
  if not config then
    local err = error_handler.validation_error(
      "Missing config parameter in csv_line",
      {
        operation = "csv_line",
        module = "reporting.formatters.csv"
      }
    )
    logger.warn(err.message, err.context)
    config = DEFAULT_CONFIG -- Use default config as fallback
  end
  
  -- Get the varargs before passing to error_handler.try
  local varargs = {...}
  
  local fields_success, fields_result = error_handler.try(function()
    local fields = {}
    for i, field in ipairs(varargs) do
      -- Escape each field safely
      fields[i] = escape_csv(field, config)
    end
    return fields
  end)
  
  if not fields_success then
    -- If field processing fails, log the error and create a minimal valid fields array
    local err = error_handler.runtime_error(
      "Failed to process fields for CSV line",
      {
        operation = "csv_line",
        module = "reporting.formatters.csv"
      },
      fields_result
    )
    logger.warn(err.message, err.context)
    
    -- Return an empty string as fallback
    return ""
  end
  
  -- Join fields with delimiter
  local join_success, result = error_handler.try(function()
    return table.concat(fields_result, config.delimiter or ",")
  end)
  
  if join_success then
    return result
  else
    -- If joining fails, log the error and return a safe empty string
    local err = error_handler.runtime_error(
      "Failed to join CSV fields",
      {
        operation = "csv_line",
        module = "reporting.formatters.csv",
        fields_count = #fields_result
      },
      result
    )
    logger.error(err.message, err.context)
    
    -- Return an empty string as fallback
    return ""
  end
end

---@param results_data table|nil Test results data to format
---@return string csv_output CSV representation of the test results
-- Format test results as CSV (comma-separated values)
function M.format_results(results_data)
  -- Validate input parameter
  if not results_data then
    local err = error_handler.validation_error(
      "Missing results_data parameter",
      {
        operation = "format_results",
        module = "reporting.formatters.csv"
      }
    )
    logger.warn(err.message, err.context)
    -- Continue with empty results generation
  end
  
  -- Get formatter configuration with error handling
  local config_success, config, config_err = error_handler.try(function()
    return get_config()
  end)
  
  local config = DEFAULT_CONFIG
  if config_success and config then
    -- Use the successfully retrieved config
  else
    -- Log error and use default config
    local err = error_handler.runtime_error(
      "Failed to get CSV formatter configuration",
      {
        operation = "format_results",
        module = "reporting.formatters.csv"
      },
      config -- On failure, config contains the error
    )
    logger.warn(err.message, err.context)
  end
  
  -- Ensure config.fields exists
  if not config.fields then
    config.fields = DEFAULT_CONFIG.fields
    logger.warn("Missing fields in CSV formatter config, using defaults", {
      config_source = config ~= DEFAULT_CONFIG and "custom" or "default"
    })
  end
  
  logger.debug("Generating CSV format test results", {
    has_data = results_data ~= nil,
    has_test_cases = results_data and results_data.test_cases ~= nil,
    test_count = results_data and results_data.test_cases and #results_data.test_cases or 0,
    failures = results_data and results_data.failures or 0,
    errors = results_data and results_data.errors or 0,
    config_fields_count = config.fields and #config.fields or 0
  })
  
  -- Validate the input data
  if not results_data or not results_data.test_cases then
    logger.warn("Missing or invalid test results data for CSV report, returning header only", {
      has_data = results_data ~= nil,
      has_test_cases = results_data and results_data.test_cases ~= nil
    })
    
    -- Return just the header or empty string
    if config.include_header and config.fields then
      local header_success, header = error_handler.try(function()
        return table.concat(config.fields, config.delimiter)
      end)
      
      if header_success then
        return header
      else
        -- If header creation fails, log the error and return an empty string
        local err = error_handler.runtime_error(
          "Failed to create CSV header",
          {
            operation = "format_results",
            module = "reporting.formatters.csv"
          },
          header
        )
        logger.error(err.message, err.context)
        return ""
      end
    else
      return ""
    end
  end
  
  -- Initialize lines array safely
  local lines = {}
  
  -- CSV header with error handling
  if config.include_header and config.fields then
    local header_success, header = error_handler.try(function()
      return table.concat(config.fields, config.delimiter)
    end)
    
    if header_success then
      table.insert(lines, header)
    else
      -- If header creation fails, log the error and use a fallback
      local err = error_handler.runtime_error(
        "Failed to create CSV header",
        {
          operation = "format_results",
          module = "reporting.formatters.csv"
        },
        header
      )
      logger.warn(err.message, err.context)
      
      -- Create a simpler fallback header
      table.insert(lines, "test_id,test_suite,test_name,status")
    end
  end
  
  -- Add test case results with error handling for each test case
  for i, test_case in ipairs(results_data.test_cases or {}) do
    local test_success, test_row = error_handler.try(function()
      -- Skip if test_case is nil or not a table
      if not test_case or type(test_case) ~= "table" then
        logger.warn("Invalid test case data", {
          index = i,
          test_case_type = type(test_case)
        })
        return nil -- Skip this test case
      end
      
      -- Prepare test data with safe defaults
      local status = test_case.status or "unknown"
      local message = ""
      local error_type = ""
      local details = ""
      
      -- Extract failure/error information with error handling
      local extract_info_success, _ = error_handler.try(function()
        if status == "fail" and test_case.failure then
          message = test_case.failure.message or ""
          error_type = test_case.failure.type or ""
          details = test_case.failure.details or ""
        elseif status == "error" and test_case.error then
          message = test_case.error.message or ""
          error_type = test_case.error.type or ""
          details = test_case.error.details or ""
        end
        return true
      end)
      
      if not extract_info_success then
        -- If extraction fails, use safe defaults
        message = "Error extracting test information"
        error_type = "FormatterError"
        details = ""
      end
      
      -- Create a data table that will be used to generate the row
      local data = {
        test_id = i,
        test_suite = test_case.classname or "Test Suite",
        test_name = test_case.name or "Unnamed Test",
        status = status,
        duration = test_case.time or 0,
        message = message,
        error_type = error_type,
        details = details,
        timestamp = results_data.timestamp or ""
      }
      
      -- Generate timestamp with error handling if needed
      if not data.timestamp or data.timestamp == "" then
        local timestamp_success, timestamp = error_handler.try(function()
          return os.date(config.date_format)
        end)
        
        if timestamp_success then
          data.timestamp = timestamp
        else
          data.timestamp = "1970-01-01T00:00:00" -- Safe fallback
        end
      end
      
      -- Format and add the row based on configured fields
      local row = {}
      if config.fields and #config.fields > 0 then
        for _, field in ipairs(config.fields) do
          table.insert(row, escape_csv(data[field], config))
        end
      else
        -- Fallback if fields are missing
        for _, field in ipairs(DEFAULT_CONFIG.fields) do
          table.insert(row, escape_csv(data[field], config))
        end
      end
      
      -- Join row fields with delimiter
      return table.concat(row, config.delimiter)
    end)
    
    if test_success and test_row then
      table.insert(lines, test_row)
    else
      -- If test case processing fails, log the error and add a minimal valid row
      local err = error_handler.runtime_error(
        "Failed to process test case for CSV report",
        {
          operation = "format_results",
          index = i,
          test_case = test_case and test_case.name or "unknown",
          module = "reporting.formatters.csv"
        },
        test_row
      )
      logger.warn(err.message, err.context)
      
      -- Add a minimal valid row as a fallback
      local fallback_row = error_handler.try(function()
        local safety_row = {
          tostring(i),
          escape_csv("Error", config),
          escape_csv("Failed to process test case", config),
          escape_csv("error", config)
        }
        return table.concat(safety_row, config.delimiter)
      end)
      
      if fallback_row then
        table.insert(lines, fallback_row)
      end
    end
  end
  
  -- Add summary line if configured
  if config.include_summary and results_data.test_cases and #results_data.test_cases > 0 then
    local summary_success, summary_row = error_handler.try(function()
      -- Calculate summary statistics safely
      local total = #results_data.test_cases
      local failures = tonumber(results_data.failures) or 0
      local errors = tonumber(results_data.errors) or 0
      local skipped = tonumber(results_data.skipped) or 0
      local passed = total - failures - errors - skipped
      
      if passed < 0 then passed = 0 end  -- Sanity check
      
      -- Format summary message safely
      local summary_msg = error_handler.try(function()
        return string.format("Total: %d, Pass: %d, Fail: %d, Error: %d, Skip: %d", 
          total, passed, failures, errors, skipped)
      end)
      
      if not summary_msg then
        summary_msg = "Summary information unavailable"
      end
      
      -- Create summary data
      local summary_data = {
        test_id = "summary",
        test_suite = "TestSuite",
        test_name = "Summary",
        status = "info", 
        duration = tonumber(results_data.time) or 0,
        message = summary_msg,
        error_type = "",
        details = "",
        timestamp = results_data.timestamp or ""
      }
      
      -- Generate timestamp if needed
      if not summary_data.timestamp or summary_data.timestamp == "" then
        local timestamp_success, timestamp = error_handler.try(function()
          return os.date(config.date_format)
        end)
        
        if timestamp_success then
          summary_data.timestamp = timestamp
        else
          summary_data.timestamp = "1970-01-01T00:00:00" -- Safe fallback
        end
      end
      
      -- Format and add the summary row based on configured fields
      local row = {}
      if config.fields and #config.fields > 0 then
        for _, field in ipairs(config.fields) do
          table.insert(row, escape_csv(summary_data[field], config))
        end
      else
        -- Fallback if fields are missing
        for _, field in ipairs(DEFAULT_CONFIG.fields) do
          table.insert(row, escape_csv(summary_data[field], config))
        end
      end
      
      -- Join row fields with delimiter
      return table.concat(row, config.delimiter)
    end)
    
    if summary_success and summary_row then
      table.insert(lines, summary_row)
    else
      -- If summary processing fails, log the error
      local err = error_handler.runtime_error(
        "Failed to generate summary row for CSV report",
        {
          operation = "format_results",
          module = "reporting.formatters.csv"
        },
        summary_row
      )
      logger.warn(err.message, err.context)
      
      -- Fallback summary row
      local simple_summary = error_handler.try(function()
        return "summary,TestSuite,Summary,info,0,Summary information unavailable,,,0"
      end)
      
      if simple_summary then
        table.insert(lines, simple_summary)
      end
    end
  end
  
  -- Join all lines with newlines with error handling
  local join_success, result = error_handler.try(function()
    return table.concat(lines, "\n")
  end)
  
  if join_success then
    return result
  else
    -- If joining fails, log the error and return a minimal valid CSV
    local err = error_handler.runtime_error(
      "Failed to join CSV lines",
      {
        operation = "format_results",
        lines_count = #lines,
        module = "reporting.formatters.csv"
      },
      result
    )
    logger.error(err.message, err.context)
    
    -- If header exists, return it as a fallback
    if config.include_header and config.fields then
      local header_fallback = error_handler.try(function()
        return table.concat(config.fields, config.delimiter)
      end)
      
      if header_fallback then
        return header_fallback
      end
    end
    
    -- Last resort fallback - most minimal valid CSV
    return "test_id,test_name,status"
  end
end

---@param formatters table Table of formatter registries
---@return boolean success True if registration was successful
---@return table|nil error Error object if registration failed
-- Register formatter
return function(formatters)
  -- Validate parameters
  if not formatters then
    local err = error_handler.validation_error(
      "Missing required formatters parameter",
      {
        operation = "register_csv_formatter",
        module = "reporting.formatters.csv"
      }
    )
    logger.error(err.message, err.context)
    return false, err
  end
  
  -- Use try/catch pattern for the registration
  local success, result = error_handler.try(function()
    -- Initialize results formatters if needed
    formatters.results = formatters.results or {}
    formatters.results.csv = M.format_results
    
    logger.debug("CSV formatter registered successfully", {
      formatter_type = "results",
      module = "reporting.formatters.csv"
    })
    
    return true
  end)
  
  if not success then
    -- If registration fails, log the error and return false
    local err = error_handler.runtime_error(
      "Failed to register CSV formatter",
      {
        operation = "register_csv_formatter",
        module = "reporting.formatters.csv"
      },
      result -- On failure, result contains the error
    )
    logger.error(err.message, err.context)
    return false, err
  end
  
  return true
end