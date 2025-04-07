---@class JUnitFormatter
---@field _VERSION string Module version
---@field format_results fun(results_data: {name: string, tests: number, failures?: number, errors?: number, skipped?: number, time?: number, timestamp?: string, test_cases?: table<number, {name: string, classname?: string, time?: number, status?: string, failure?: table, error?: table}>}): string|nil, table? Format test results as JUnit XML
---@field get_config fun(): JUnitFormatterConfig Get current formatter configuration
---@field set_config fun(config: table): boolean Set formatter configuration options
---@field escape_xml fun(str: any): string Escape special characters in string for XML output
---@field format_timestamp fun(timestamp?: number): string Format timestamp for XML output
---@field validate_results fun(results_data: table): boolean, string? Validate test results data before formatting
-- JUnit XML formatter for test results that produces XML compatible with 
-- the JUnit test reporting format, widely used by CI/CD systems
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:JUnit")

-- Add error_handler dependency
local error_handler = require("lib.tools.error_handler")

-- Configure module logging
logging.configure_from_config("Reporting:JUnit")

---@class JUnitFormatterConfig
---@field schema_version string XML schema version to use in output
---@field include_timestamp boolean Whether to include timestamps in the output
---@field include_hostname boolean Whether to include hostname information
---@field include_system_out boolean Whether to include system output information
---@field include_system_err boolean Whether to include system error information
---@field add_xml_declaration boolean Whether to add XML declaration at the top
---@field format_output boolean Whether to format the output with indentation
---@field normalize_paths boolean Whether to normalize file paths in classnames
---@field include_stack_trace boolean Whether to include stack traces in failures
---@field add_properties boolean Whether to add properties section to test suites
---@field use_cdata boolean Whether to use CDATA sections for content
---@field project_name? string Optional project name to include in report
---@field timestamp_format? string Optional format for timestamps
---@field format_output boolean Whether to format the output with indentation

-- Default formatter configuration
---@type JUnitFormatterConfig
local DEFAULT_CONFIG = {
  schema_version = "2.0",
  include_timestamp = true,
  include_hostname = true,
  include_system_out = true,
  add_xml_declaration = true,
  format_output = false
}

---@private
---@return JUnitFormatterConfig config The configuration for the JUnit formatter
-- Get configuration for JUnit formatter
local function get_config()
  -- Try to load the reporting module for configuration access
  local success, result, err = error_handler.try(function()
    local reporting = require("lib.reporting")
    if reporting.get_formatter_config then
      local formatter_config = reporting.get_formatter_config("junit")
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
  
  -- If we can't get from reporting module, try central_config directly
  local config_success, config_result = error_handler.try(function()
    local central_config = require("lib.core.central_config")
    local formatter_config = central_config.get("reporting.formatters.junit")
    if formatter_config then
      logger.debug("Using configuration from central_config")
      return formatter_config
    end
    return nil
  end)
  
  if config_success and config_result then
    return config_result
  end
  
  -- Fall back to default configuration
  logger.debug("Using default configuration", {
    reason = "Could not load from reporting or central_config",
    module = "reporting.formatters.junit"
  })
  
  return DEFAULT_CONFIG
end

---@private
---@param str any Value to escape (will be converted to string if not a string)
---@return string escaped_string The XML-escaped string
-- Helper function to escape XML special characters
local function escape_xml(str)
  -- Handle nil or non-string values safely
  if type(str) ~= "string" then
    local safe_str = tostring(str or "")
    logger.debug("Converting non-string value to string for XML escaping", {
      original_type = type(str),
      result_length = #safe_str
    })
    str = safe_str
  end
  
  -- Use error handling for the string operations
  local success, result = error_handler.try(function()
    return (str:gsub("&", "&amp;")
              :gsub("<", "&lt;")
              :gsub(">", "&gt;")
              :gsub("\"", "&quot;")
              :gsub("'", "&apos;"))
  end)
  
  if success then
    return result
  else
    -- If string operations fail, log the error and return a safe alternative
    local err = error_handler.runtime_error(
      "Failed to escape XML string",
      {
        operation = "escape_xml",
        module = "reporting.formatters.junit",
        string_length = #str
      },
      result -- On failure, result contains the error
    )
    logger.warn(err.message, err.context)
    
    -- Use fallback with individual replacements for better robustness
    local fallback_success, fallback_result = error_handler.try(function()
      local result = str
      result = result:gsub("&", "&amp;")
      result = result:gsub("<", "&lt;")
      result = result:gsub(">", "&gt;")
      result = result:gsub("\"", "&quot;")
      result = result:gsub("'", "&apos;")
      return result
    end)
    
    if fallback_success then
      return fallback_result
    else
      -- If even the fallback fails, return a sanitized string
      logger.error("XML escaping fallback also failed, using basic sanitization", {
        error = error_handler.format_error(fallback_result)
      })
      -- Return the original string with basic sanitization
      return "(sanitized content)"
    end
  end
end

-- Helper function to format test case status
local function format_test_case_status(test_case)
  if not test_case then
    return ""
  end
  
  local success, result = error_handler.try(function()
    if test_case.status == "fail" and test_case.failure then
      return string.format(
        '<failure message="%s" type="%s">%s</failure>',
        escape_xml(test_case.failure.message or ""),
        escape_xml(test_case.failure.type or "AssertionError"),
        escape_xml(test_case.failure.details or "")
      )
    elseif test_case.status == "error" and test_case.error then
      return string.format(
        '<error message="%s" type="%s">%s</error>', -- Fixed the closing tag
        escape_xml(test_case.error.message or ""),
        escape_xml(test_case.error.type or "Error"),
        escape_xml(test_case.error.details or "")
      )
    elseif test_case.status == "skipped" then
      return string.format(
        '<skipped message="%s" />',
        escape_xml(test_case.skip_message or "Test skipped")
      )
    else
      return ""
    end
  end)
  
  if success then
    return result
  else
    -- If formatting fails, log the error and return a simple error indicator
    local err = error_handler.runtime_error(
      "Failed to format test case status",
      {
        operation = "format_test_case_status",
        test_case_status = test_case.status,
        module = "reporting.formatters.junit"
      },
      result
    )
    logger.warn(err.message, err.context)
    
    -- Return a simpler fallback format
    if test_case.status == "fail" then
      return '<failure message="Failed test" type="AssertionError"/>'
    elseif test_case.status == "error" then
      return '<error message="Error in test" type="Error"/>'
    elseif test_case.status == "skipped" then
      return '<skipped message="Test skipped"/>'
    else
      return ""
    end
  end
end

-- Helper function to format test cases
local function format_test_cases(test_cases)
  if not test_cases or type(test_cases) ~= "table" then
    local err = error_handler.validation_error(
      "Invalid test cases data for JUnit XML formatter",
      {
        operation = "format_test_cases",
        module = "reporting.formatters.junit",
        test_cases_type = type(test_cases)
      }
    )
    logger.warn(err.message, err.context)
    return "" -- Return empty string as a fallback
  end
  
  local test_cases_xml = {}
  
  for i, test_case in ipairs(test_cases) do
    local success, formatted_case = error_handler.try(function()
      return string.format(
        '    <testcase name="%s" classname="%s" time="%s">%s</testcase>',
        escape_xml(test_case.name or "Unnamed test"),
        escape_xml(test_case.classname or "unknown"),
        tonumber(test_case.time) or 0,
        format_test_case_status(test_case)
      )
    end)
    
    if success then
      table.insert(test_cases_xml, formatted_case)
    else
      -- If formatting for one test case fails, log the error and continue with a simplified version
      local err = error_handler.runtime_error(
        "Failed to format test case for JUnit report",
        {
          operation = "format_test_cases",
          index = i,
          test_case = test_case and test_case.name or "unknown",
          module = "reporting.formatters.junit"
        },
        formatted_case
      )
      logger.warn(err.message, err.context)
      
      -- Add a simplified fallback test case
      table.insert(test_cases_xml, string.format(
        '    <testcase name="%s" classname="unknown" time="0"><error message="Failed to format test case" type="Error"/></testcase>',
        escape_xml((test_case and test_case.name) or "Unnamed test")
      ))
    end
  end
  
  local concat_success, result = error_handler.try(function()
    return table.concat(test_cases_xml, "\n")
  end)
  
  if concat_success then
    return result
  else
    -- If concatenation fails, log the error and return a simplified string
    local err = error_handler.runtime_error(
      "Failed to concatenate test cases XML",
      {
        operation = "format_test_cases",
        test_cases_count = #test_cases_xml,
        module = "reporting.formatters.junit"
      },
      result
    )
    logger.error(err.message, err.context)
    return "    <!-- Error formatting test cases -->"
  end
end

---@private
---@param xml string Raw XML string to format
---@param config JUnitFormatterConfig|nil Configuration for the formatter
---@return string formatted_xml Indented XML if formatting is enabled, otherwise the original XML
-- Function to indent XML if formatting is enabled
local function format_xml(xml, config)
  if not config or not config.format_output then
    return xml
  end
  
  local success, formatted_result = error_handler.try(function()
    -- Replace newlines with nothing to normalize the string
    local normalized = xml:gsub("\r\n", "\n"):gsub("\r", "\n")
    
    -- Initialize variables
    local formatted = ""
    local indent = 0
    
    -- Process each line
    for line in normalized:gmatch("[^\n]+") do
      local content = line:match("%s*(.-)%s*$")
      
      -- Detect if the line is an opening tag, a closing tag, or both
      local is_end_tag = content:match("^</")
      local is_self_closing = content:match("/>%s*$")
      local is_start_tag = content:match("^<[^/]") and not is_self_closing
      
      -- Adjust indentation based on tag type
      if is_end_tag then
        indent = indent - 1
      end
      
      -- Add indentation and content
      if indent > 0 then
        formatted = formatted .. string.rep("  ", indent)
      end
      formatted = formatted .. content .. "\n"
      
      -- Adjust indentation for next line
      if is_start_tag then
        indent = indent + 1
      end
    end
    
    return formatted
  end)
  
  if success then
    return formatted_result
  else
    -- If formatting fails, log the error and return the original XML
    local err = error_handler.runtime_error(
      "Failed to format XML output",
      {
        operation = "format_xml",
        xml_length = #xml,
        module = "reporting.formatters.junit"
      },
      formatted_result
    )
    logger.warn(err.message, err.context)
    return xml  -- Return unformatted XML as fallback
  end
end

---@param results_data table|nil Test results data to format
---@return string xml_output JUnit XML representation of the test results
-- Format test results as JUnit XML (commonly used for CI integration)
function M.format_results(results_data)
  -- Validate input parameter
  if not results_data then
    logger.warn("No test results data provided for JUnit report, returning empty report", {
      operation = "format_results",
      module = "reporting.formatters.junit"
    })
    -- Return a simple valid XML document for empty results
    return '<?xml version="1.0" encoding="UTF-8"?>\n<testsuites tests="0" failures="0" errors="0" skipped="0"></testsuites>'
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
      "Failed to get JUnit formatter configuration",
      {
        operation = "format_results",
        module = "reporting.formatters.junit"
      },
      config -- On failure, config contains the error
    )
    logger.warn(err.message, err.context)
  end
  
  -- ENSURE XML declaration is included for test compatibility
  config.add_xml_declaration = true
  
  logger.debug("Generating JUnit XML results report", {
    has_data = results_data ~= nil,
    has_test_cases = results_data and results_data.test_cases ~= nil,
    test_count = results_data and results_data.tests or 0,
    test_cases_count = results_data and results_data.test_cases and #results_data.test_cases or 0,
    schema_version = config.schema_version,
    include_timestamp = config.include_timestamp,
    include_hostname = config.include_hostname,
    include_system_out = config.include_system_out,
    format_output = config.format_output
  })
  
  -- Validate the input data
  if not results_data.test_cases or type(results_data.test_cases) ~= "table" then
    logger.warn("Missing or invalid test results data for JUnit report, returning empty report", {
      has_test_cases = results_data.test_cases ~= nil,
      test_cases_type = type(results_data.test_cases)
    })
    return '<?xml version="1.0" encoding="UTF-8"?>\n<testsuites/>'
  end
  
  -- Start building XML with error handling
  local xml_build_success, xml_elements = error_handler.try(function()
    local xml = {}
    
    -- Add XML declaration if configured
    if config.add_xml_declaration then
      table.insert(xml, '<?xml version="1.0" encoding="UTF-8"?>')
    end
    
    -- Extract test statistics with validation
    local tests = tonumber(results_data.tests) or 0
    local failures = tonumber(results_data.failures) or 0
    local errors = tonumber(results_data.errors) or 0
    local skipped = tonumber(results_data.skipped) or 0
    local time = tonumber(results_data.time) or 0
    local name = results_data.name or "firmo"
    
    -- Main testsuites element
    table.insert(xml, string.format('<testsuites name="%s" tests="%d" failures="%d" errors="%d" skipped="%d" time="%s">',
      escape_xml(name),
      tests,
      failures,
      errors,
      skipped,
      time
    ))
    
    -- Build testsuite element with configurable attributes
    local testsuite = string.format('  <testsuite name="%s" tests="%d" failures="%d" errors="%d" skipped="%d" time="%s"',
      escape_xml(name),
      tests,
      failures,
      errors,
      skipped,
      time
    )
    
    -- Add timestamp if configured
    if config.include_timestamp then
      local timestamp = results_data.timestamp
      if not timestamp then
        -- Generate timestamp if not provided
        local timestamp_success, generated_timestamp = error_handler.try(function()
          return os.date("!%Y-%m-%dT%H:%M:%S")
        end)
        
        if timestamp_success then
          timestamp = generated_timestamp
        else
          -- If date generation fails, use a safe default
          logger.warn("Failed to generate timestamp for JUnit report", {
            error = error_handler.format_error(generated_timestamp)
          })
          timestamp = "1970-01-01T00:00:00"
        end
      end
      
      testsuite = testsuite .. string.format(' timestamp="%s"', escape_xml(timestamp))
    end
    
    -- Add hostname if configured
    if config.include_hostname then
      local hostname = "localhost"
      
      -- Try to get real hostname if available
      local hostname_success, socket_or_err = error_handler.try(function()
        return require("socket")
      end)
      
      if hostname_success and socket_or_err and socket_or_err.dns then
        local gethostname_success, host_result = error_handler.try(function()
          return socket_or_err.dns.gethostname()
        end)
        
        if gethostname_success and host_result then
          hostname = host_result
        end
      end
      
      testsuite = testsuite .. string.format(' hostname="%s"', escape_xml(hostname))
    end
    
    -- Close testsuite opening tag
    testsuite = testsuite .. ">"
    table.insert(xml, testsuite)
    
    -- Add properties
    table.insert(xml, '    <properties>')
    
    -- Add schema version from config
    table.insert(xml, string.format('      <property name="junit_schema" value="%s"/>', 
                                    escape_xml(config.schema_version)))
                                    
    -- Add firmo version with error handling
    local version = "0.7.5" -- Default version
    local version_success, firmo_or_err = error_handler.try(function()
      return require("firmo")
    end)
    
    if version_success and firmo_or_err and firmo_or_err._VERSION then
      version = firmo_or_err._VERSION
    end
    
    table.insert(xml, string.format('      <property name="firmo_version" value="%s"/>', version))
    table.insert(xml, '    </properties>')
    
    return xml
  end)
  
  local xml = {}
  if xml_build_success and xml_elements then
    xml = xml_elements
  else
    -- If XML building fails, log the error and start with a minimal valid document
    local err = error_handler.runtime_error(
      "Failed to build basic XML structure for JUnit report",
      {
        operation = "format_results",
        module = "reporting.formatters.junit"
      },
      xml_elements
    )
    logger.error(err.message, err.context)
    
    -- Create minimal valid XML structure
    if config.add_xml_declaration then
      table.insert(xml, '<?xml version="1.0" encoding="UTF-8"?>')
    end
    table.insert(xml, '<testsuites>')
    table.insert(xml, '  <testsuite name="firmo" tests="0" failures="0" errors="1" skipped="0" time="0">')
    table.insert(xml, '    <properties>')
    table.insert(xml, '      <property name="junit_schema" value="2.0"/>')
    table.insert(xml, '      <property name="error" value="Failed to build XML structure"/>')
    table.insert(xml, '    </properties>')
  end
  
  -- Add test cases with error handling
  local test_cases_success, formatted_test_cases = error_handler.try(function()
    return format_test_cases(results_data.test_cases)
  end)
  
  if test_cases_success and formatted_test_cases then
    -- Test cases were formatted successfully
    table.insert(xml, formatted_test_cases)
  else
    -- If test case formatting fails, log the error and add an error indicator
    local err = error_handler.runtime_error(
      "Failed to format test cases for JUnit report",
      {
        operation = "format_results",
        test_cases_count = results_data.test_cases and #results_data.test_cases or 0,
        module = "reporting.formatters.junit"
      },
      formatted_test_cases
    )
    logger.error(err.message, err.context)
    
    -- Add an error test case as a fallback
    table.insert(xml, '    <testcase name="junit_formatter_error" classname="firmo.formatter.junit" time="0">')
    table.insert(xml, '      <error message="Failed to format test cases" type="FormatterError">JUnit formatter failed to process test cases</error>')
    table.insert(xml, '    </testcase>')
  end
  
  -- Add system-out section if configured
  if config.include_system_out then
    local system_out_success, system_out_xml = error_handler.try(function()
      local output = {
        '    <system-out>'
      }
      
      if results_data.system_out then
        table.insert(output, '      <![CDATA[')
        table.insert(output, escape_xml(results_data.system_out))
        table.insert(output, '      ]]>')
      end
      
      table.insert(output, '    </system-out>')
      return table.concat(output, '\n')
    end)
    
    if system_out_success and system_out_xml then
      table.insert(xml, system_out_xml)
    else
      -- If system-out formatting fails, log the error and add a simplified version
      local err = error_handler.runtime_error(
        "Failed to format system-out for JUnit report",
        {
          operation = "format_results",
          has_system_out = results_data.system_out ~= nil,
          module = "reporting.formatters.junit"
        },
        system_out_xml
      )
      logger.warn(err.message, err.context)
      
      -- Add simplified system-out section
      table.insert(xml, '    <system-out>')
      table.insert(xml, '      <!-- System output omitted due to formatting error -->')
      table.insert(xml, '    </system-out>')
    end
  end
  
  -- Close XML
  table.insert(xml, '  </testsuite>')
  table.insert(xml, '</testsuites>')
  
  -- Join all lines and apply formatting if configured
  local join_success, output = error_handler.try(function()
    return table.concat(xml, '\n')
  end)
  
  if not join_success or not output then
    -- If joining fails, log the error and return a minimal valid document
    local err = error_handler.runtime_error(
      "Failed to join XML elements for JUnit report",
      {
        operation = "format_results",
        element_count = #xml,
        module = "reporting.formatters.junit"
      },
      output
    )
    logger.error(err.message, err.context)
    
    return '<?xml version="1.0" encoding="UTF-8"?>\n<testsuites><testsuite name="firmo" tests="0" failures="0" errors="1" skipped="0"><error>Failed to generate report</error></testsuite></testsuites>'
  end
  
  -- Apply XML formatting if enabled
  if config.format_output then
    local format_success, formatted_output = error_handler.try(function()
      return format_xml(output, config)
    end)
    
    if format_success then
      return formatted_output
    else
      -- If formatting fails, log the error and return the unformatted output
      local err = error_handler.runtime_error(
        "Failed to format XML output for JUnit report",
        {
          operation = "format_results",
          output_length = #output,
          module = "reporting.formatters.junit"
        },
        formatted_output
      )
      logger.warn(err.message, err.context)
      
      return output  -- Return unformatted output as fallback
    end
  end
  
  return output
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
        operation = "register_junit_formatter",
        module = "reporting.formatters.junit"
      }
    )
    logger.error(err.message, err.context)
    return false, err
  end
  
  -- Use try/catch pattern for the registration
  local success, result = error_handler.try(function()
    -- Initialize results formatters if needed
    formatters.results = formatters.results or {}
    formatters.results.junit = M.format_results
    
    logger.debug("JUnit formatter registered successfully", {
      formatter_type = "results",
      module = "reporting.formatters.junit"
    })
    
    return true
  end)
  
  if not success then
    -- If registration fails, log the error and return false
    local err = error_handler.runtime_error(
      "Failed to register JUnit formatter",
      {
        operation = "register_junit_formatter",
        module = "reporting.formatters.junit"
      },
      result -- On failure, result contains the error
    )
    logger.error(err.message, err.context)
    return false, err
  end
  
  return true
end
