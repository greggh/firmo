--- Reporting Data Schema Validation
---
--- Defines schemas for core data structures (coverage, test results, quality) and
--- various output formats (HTML, JSON, LCOV, etc.). Provides functions to
--- validate data against these schemas.
---
--- @module lib.reporting.schema
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.1.0

---@class ReportingSchema The public API of the schema validation module.
---@field _VERSION string Module version.
---@field COVERAGE_SCHEMA table Schema definition for internal coverage data structure (`CoverageReportData`).
---@field TEST_RESULTS_SCHEMA table Schema definition for test results data structure (e.g., for JUnit/TAP).
---@field QUALITY_SCHEMA table Schema definition for quality validation data structure (`QualityData`).
---@field HTML_COVERAGE_SCHEMA table Schema definition for basic HTML coverage format validation.
---@field JSON_COVERAGE_SCHEMA table Schema definition for JSON coverage format (currently same as internal `COVERAGE_SCHEMA`).
---@field LCOV_COVERAGE_SCHEMA table Schema definition for LCOV coverage format string validation.
---@field COBERTURA_COVERAGE_SCHEMA table Schema definition for Cobertura XML coverage format string validation.
---@field TAP_RESULTS_SCHEMA table Schema definition for TAP test results format string validation.
---@field JUNIT_RESULTS_SCHEMA table Schema definition for JUnit XML test results format string validation.
---@field CSV_RESULTS_SCHEMA table Schema definition for CSV test results format string validation.
---@field validate fun(data: any, schema_name: string): boolean, string? Validates data against a named schema defined in this module. Returns `success, error_message?`.
---@field detect_schema fun(data: any): string? Attempts to automatically detect which schema (`COVERAGE_SCHEMA`, `TEST_RESULTS_SCHEMA`, etc.) matches the given data. Returns schema name string or `nil`.
---@field validate_format fun(data: any, format: string): boolean, string? Validates data against the schema associated with a specific output `format` name (e.g., "html", "json", "lcov"). Returns `success, error_message?`.

local M = {}

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
    return logging.get_logger("Reporting:Schema")
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

--- Module version
M._VERSION = "0.1.0"

--- Schema definition for internal coverage data structure (`CoverageReportData`).
M.COVERAGE_SCHEMA = {
  type = "table",
  required = { "files", "summary" },
  properties = {
    files = {
      type = "table",
      description = "Table mapping normalized file paths to file statistics",
      dynamic_properties = {
        -- Schema for each file entry within the 'files' table
        type = "table",
        required = { "total_lines", "covered_lines", "line_coverage_percent" },
        properties = {
          total_lines = { type = "number", minimum = 0 },
          covered_lines = { type = "number", minimum = 0 },
          executable_lines = { type = "number", minimum = 0, optional = true },
          line_coverage_percent = { type = "number", minimum = 0, maximum = 100 },
          total_functions = { type = "number", minimum = 0, optional = true },
          covered_functions = { type = "number", minimum = 0, optional = true },
          function_coverage_percent = { type = "number", minimum = 0, maximum = 100, optional = true },
          total_blocks = { type = "number", minimum = 0, optional = true },
          covered_blocks = { type = "number", minimum = 0, optional = true },
          block_coverage_percent = { type = "number", minimum = 0, maximum = 100, optional = true },
        },
      },
    },
    summary = {
      type = "table",
      required = { "total_files", "total_lines", "covered_lines", "line_coverage_percent" },
      properties = {
        total_files = { type = "number", minimum = 0, description = "Total number of files analyzed" },
        covered_files = { type = "number", minimum = 0, optional = true },
        total_lines = { type = "number", minimum = 0 },
        covered_lines = { type = "number", minimum = 0, description = "Total lines covered across all files" },
        executable_lines = {
          type = "number",
          minimum = 0,
          optional = true,
          description = "Total executable lines across all files",
        },
        line_coverage_percent = {
          type = "number",
          minimum = 0,
          maximum = 100,
          description = "Overall line coverage percentage",
        },
        total_functions = {
          type = "number",
          minimum = 0,
          optional = true,
          description = "Total functions across all files",
        },
        covered_functions = { type = "number", minimum = 0, optional = true },
        function_coverage_percent = { type = "number", minimum = 0, maximum = 100, optional = true },
        total_blocks = { type = "number", minimum = 0, optional = true },
        covered_blocks = { type = "number", minimum = 0, optional = true },
        block_coverage_percent = { type = "number", minimum = 0, maximum = 100, optional = true },
        overall_percent = { type = "number", minimum = 0, maximum = 100, optional = true },
      },
    },
    original_files = {
      type = "table",
      optional = true,
      description = "Optional: Original source file contents used for coverage analysis (potentially large)",
      dynamic_properties = {
        -- Schema for each file entry within the 'original_files' table
        type = "table",
        properties = {
          source = { type = "any" }, -- Can be string or table of lines
          executable_lines = { type = "table", optional = true },
          functions = { type = "table", optional = true },
          lines = { type = "table", optional = true },
        },
      },
    },
    timestamp = { type = "string", optional = true },
    version = { type = "string", optional = true },
  },
}

--- Schema definition for test results data structure (e.g., for JUnit/TAP).
M.TEST_RESULTS_SCHEMA = {
  type = "table",
  required = { "name", "tests" },
  properties = {
    name = { type = "string" },
    timestamp = { type = "string", optional = true },
    tests = { type = "number", minimum = 0 },
    failures = { type = "number", minimum = 0, optional = true },
    errors = { type = "number", minimum = 0, optional = true },
    skipped = { type = "number", minimum = 0, optional = true },
    time = { type = "number", minimum = 0, optional = true },
    test_cases = {
      type = "table",
      optional = true,
      array_of = {
        type = "table",
        required = { "name" },
        properties = {
          name = { type = "string" },
          classname = { type = "string", optional = true },
          time = { type = "number", minimum = 0, optional = true },
          status = {
            type = "string",
            enum = { "pass", "fail", "error", "skipped", "pending" },
            optional = true,
          },
          failure = {
            type = "table",
            optional = true,
            properties = {
              message = { type = "string", optional = true },
              type = { type = "string", optional = true },
              details = { type = "string", optional = true },
            },
          },
          error = {
            type = "table",
            optional = true,
            properties = {
              message = { type = "string", optional = true },
              type = { type = "string", optional = true },
              details = { type = "string", optional = true },
            },
          },
        },
      },
    },
  },
}

--- Schema definition for quality validation data structure (`QualityData`).
M.QUALITY_SCHEMA = {
  type = "table",
  required = { "level", "summary" },
  properties = {
    level = { type = "number", minimum = 0, maximum = 5 },
    level_name = { type = "string", optional = true },
    tests = {
      type = "table",
      optional = true,
      dynamic_properties = {
        type = "table",
        properties = {
          assertions = { type = "number", minimum = 0, optional = true },
          quality_score = { type = "number", minimum = 0, maximum = 100, optional = true },
          patterns = { type = "table", optional = true },
          issues = { type = "table", optional = true },
        },
      },
    },
    summary = {
      type = "table",
      required = { "tests_analyzed", "quality_percent" },
      properties = {
        tests_analyzed = { type = "number", minimum = 0 },
        tests_passing_quality = { type = "number", minimum = 0 },
        quality_percent = { type = "number", minimum = 0, maximum = 100 },
        assertions_total = { type = "number", minimum = 0, optional = true },
        assertions_per_test_avg = { type = "number", minimum = 0, optional = true },
        issues = { type = "table", optional = true },
      },
    },
  },
}

--- Schema definition for basic HTML coverage format validation (checks start tag).
M.HTML_COVERAGE_SCHEMA = {
  type = "string",
  pattern = "^<!DOCTYPE html>", -- Check if it starts like an HTML file
}

--- Schema definition for JSON coverage format (currently same as internal `COVERAGE_SCHEMA`).
M.JSON_COVERAGE_SCHEMA = {
  type = "table",
  required = { "files", "summary" },
  -- Note: Ideally, this would reference M.COVERAGE_SCHEMA or copy its properties
  -- For simplicity now, we assume structure is identical
}

--- Schema definition for LCOV coverage format string validation (checks start).
M.LCOV_COVERAGE_SCHEMA = {
  type = "string",
  pattern = "^TN:", -- Check if it starts with Test Name marker
}

--- Schema definition for Cobertura XML coverage format string validation (checks start).
M.COBERTURA_COVERAGE_SCHEMA = {
  type = "string",
  pattern = "^<%?xml", -- Check if it starts like an XML file
}

--- Schema definition for TAP test results format string validation (checks start).
M.TAP_RESULTS_SCHEMA = {
  type = "string",
  pattern = "^TAP version ", -- Check for TAP version header
}

--- Schema definition for JUnit XML test results format string validation (checks start).
M.JUNIT_RESULTS_SCHEMA = {
  type = "string",
  pattern = "^<%?xml", -- Check if it starts like an XML file
}

--- Schema definition for CSV test results format string validation (checks expected header start).
M.CSV_RESULTS_SCHEMA = {
  type = "string",
  pattern = "^[\"']?test[\"']?,", -- Check if it likely starts with a header like "test",...
}

--- Validates a single value against type and constraints defined in a schema property.
--- Checks type, optionality, string patterns, enums, and number ranges.
---@param value any The value to validate.
---@param schema {type: string, optional?: boolean, pattern?: string, enum?: string[], minimum?: number, maximum?: number} The schema definition for this specific value/property.
---@return boolean success `true` if the value matches the schema requirements.
---@return string? error_message An error message string if validation failed, `nil` otherwise.
---@private
local function validate_type(value, schema)
  -- Check for nil values
  if value == nil then
    if schema.optional then
      return true
    else
      return false, "Value is nil but required"
    end
  end

  -- Check type
  if schema.type == "any" then
    return true
  elseif schema.type == "string" and type(value) == "string" then
    -- Check string pattern if specified
    if schema.pattern and not value:match(schema.pattern) then
      return false, "String does not match required pattern: " .. schema.pattern
    end

    -- Check enum if specified
    if schema.enum then
      local found = false
      for _, allowed in ipairs(schema.enum) do
        if value == allowed then
          found = true
          break
        end
      end
      if not found then
        return false, "String is not one of the allowed values: " .. table.concat(schema.enum, ", ")
      end
    end

    return true
  elseif schema.type == "number" and type(value) == "number" then
    -- Check number constraints
    if schema.minimum ~= nil and value < schema.minimum then
      return false, "Number is less than minimum: " .. schema.minimum
    end
    if schema.maximum ~= nil and value > schema.maximum then
      return false, "Number is greater than maximum: " .. schema.maximum
    end
    return true
  elseif schema.type == "boolean" and type(value) == "boolean" then
    return true
  elseif schema.type == "table" and type(value) == "table" then
    return true
  elseif schema.type == "function" and type(value) == "function" then
    return true
  else
    return false, "Expected type " .. schema.type .. ", got " .. type(value)
  end
end

--- Recursively validates a value (especially tables) against a schema definition.
--- Checks required properties, property types/schemas, array item schemas, and dynamic properties.
--- Uses `validate_type` for individual property type checks.
---@param value any The value to validate.
---@param schema {type: string, optional?: boolean, required?: string[], properties?: table<string, table>, array_of?: table, dynamic_properties?: table} The schema definition.
---@param path? string The current dot-separated path within the data structure (used for error reporting). Defaults to "".
---@return boolean success `true` if the value conforms to the schema.
---@return string? error_message An error message describing the first validation failure found, including the path, or `nil` if validation succeeded.
---@private
local function validate_schema(value, schema, path)
  path = path or ""

  -- Type validation is the first step
  local valid, err = validate_type(value, schema)
  if not valid then
    return false, path .. ": " .. err
  end

  -- If it's optional and nil, no further validation needed
  if value == nil and schema.optional then
    return true
  end

  -- For tables, validate properties
  if schema.type == "table" and type(value) == "table" then
    -- Check required properties
    if schema.required then
      for _, req_prop in ipairs(schema.required) do
        if value[req_prop] == nil then
          return false, path .. ": Missing required property: " .. req_prop
        end
      end
    end

    -- Check properties
    if schema.properties then
      for prop_name, prop_schema in pairs(schema.properties) do
        if value[prop_name] ~= nil or not prop_schema.optional then
          local prop_path = path .. (path ~= "" and "." or "") .. prop_name
          local prop_valid, prop_err = validate_schema(value[prop_name], prop_schema, prop_path)
          if not prop_valid then
            return false, prop_err
          end
        end
      end
    end

    -- Check array items
    if schema.array_of and #value > 0 then
      for i, item in ipairs(value) do
        local item_path = path .. "[" .. i .. "]"
        local item_valid, item_err = validate_schema(item, schema.array_of, item_path)
        if not item_valid then
          return false, item_err
        end
      end
    end

    -- Handle dynamic properties (like files table where keys are file paths)
    if schema.dynamic_properties then
      for key, val in pairs(value) do
        if type(val) == "table" then
          local dyn_path = path .. "." .. key
          local dyn_valid, dyn_err = validate_schema(val, schema.dynamic_properties, dyn_path)
          if not dyn_valid then
            return false, dyn_err
          end
        end
      end
    end
  end

  return true
end

---@param data any The data to validate
---@param schema_name string The name of the schema to validate against
---@return boolean success Whether the data is valid
---@return string? error_message An error message string if validation failed, `nil` otherwise.
function M.validate(data, schema_name)
  get_logger().debug("Validating data against schema", { schema = schema_name })

  local schema = M[schema_name]
  if not schema then
    get_logger().error("Schema not found", { schema_name = schema_name })
    return false, "Schema not found: " .. schema_name
  end

  -- For string validation that needs to test file contents
  if schema.type == "string" and type(data) == "string" then
    if schema.pattern and not data:sub(1, 50):match(schema.pattern) then
      get_logger().warn("String validation failed", {
        schema = schema_name,
        pattern = schema.pattern,
        data_sample = data:sub(1, 50) .. "...",
      })
      return false, "String content does not match required pattern"
    end
    return true
  end

  -- For regular schema validation
  local is_valid, err = validate_schema(data, schema)

  if not is_valid then
    get_logger().warn("Schema validation failed", {
      schema = schema_name,
      error = err,
    })
    return false, err
  end

  get_logger().debug("Schema validation successful", { schema = schema_name })
  return true
end

---@param data any The data to detect schema for
---@return string? schema_name The name of the detected schema (e.g., "COVERAGE_SCHEMA", "HTML_COVERAGE_SCHEMA") or `nil` if no specific schema could be confidently identified based on data type and content signatures.
function M.detect_schema(data)
  get_logger().debug("Detecting schema for data")

  if type(data) == "table" then
    -- Check for coverage data
    if data.files and data.summary then
      get_logger().debug("Detected coverage data")
      return "COVERAGE_SCHEMA"
    end

    -- Check for test results data
    if data.name and data.tests then
      get_logger().debug("Detected test results data")
      return "TEST_RESULTS_SCHEMA"
    end

    -- Check for quality data
    if data.level and data.summary and data.summary.quality_percent then
      get_logger().debug("Detected quality data")
      return "QUALITY_SCHEMA"
    end
  elseif type(data) == "string" then
    -- Check string formats
    local first_line = data:match("^([^\n]+)")

    if first_line:match("^<!DOCTYPE html") then
      get_logger().debug("Detected HTML format")
      return "HTML_COVERAGE_SCHEMA"
    elseif first_line:match("^<%?xml") then
      -- Need to check if it's JUnit or Cobertura
      if data:match("testsuites") or data:match("testsuite") then
        get_logger().debug("Detected JUnit XML format")
        return "JUNIT_RESULTS_SCHEMA"
      else
        get_logger().debug("Detected Cobertura XML format")
        return "COBERTURA_COVERAGE_SCHEMA"
      end
    elseif first_line:match("^TN:") then
      get_logger().debug("Detected LCOV format")
      return "LCOV_COVERAGE_SCHEMA"
    elseif first_line:match("^TAP version") then
      get_logger().debug("Detected TAP format")
      return "TAP_RESULTS_SCHEMA"
    elseif first_line:match("^[\"']?test[\"']?,") then
      get_logger().debug("Detected CSV format")
      return "CSV_RESULTS_SCHEMA"
    end
  end

  get_logger().warn("Unable to detect schema for data")
  return nil
end

---@param data any The data to validate
---@param format string The format name to validate against
---@return boolean success `true` if the data is valid for the specified format's schema.
---@return string? error_message An error message string if validation failed, `nil` otherwise.
function M.validate_format(data, format)
  get_logger().debug("Validating format", { format = format })

  -- Map format names to schemas
  local format_schema_map = {
    html = "HTML_COVERAGE_SCHEMA",
    json = "JSON_COVERAGE_SCHEMA",
    lcov = "LCOV_COVERAGE_SCHEMA",
    cobertura = "COBERTURA_COVERAGE_SCHEMA",
    tap = "TAP_RESULTS_SCHEMA",
    junit = "JUNIT_RESULTS_SCHEMA",
    csv = "CSV_RESULTS_SCHEMA",
  }

  local schema_name = format_schema_map[format]
  if not schema_name then
    -- Try to detect schema based on data
    schema_name = M.detect_schema(data)

    if not schema_name then
      get_logger().warn("Unknown format", { format = format })
      return false, "Unknown format: " .. format
    end
  end

  return M.validate(data, schema_name)
end

-- Return the module
return M
