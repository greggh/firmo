---@class ReportingSchema
---@field _VERSION string Module version
---@field COVERAGE_SCHEMA table Schema definition for internal coverage data structure
---@field TEST_RESULTS_SCHEMA table Schema definition for test results data structure
---@field QUALITY_SCHEMA table Schema definition for quality validation data structure
---@field HTML_COVERAGE_SCHEMA table Schema definition for HTML coverage format
---@field JSON_COVERAGE_SCHEMA table Schema definition for JSON coverage format
---@field LCOV_COVERAGE_SCHEMA table Schema definition for LCOV coverage format
---@field COBERTURA_COVERAGE_SCHEMA table Schema definition for Cobertura XML coverage format
---@field TAP_RESULTS_SCHEMA table Schema definition for TAP test results format
---@field JUNIT_RESULTS_SCHEMA table Schema definition for JUnit XML test results format
---@field CSV_RESULTS_SCHEMA table Schema definition for CSV test results format
---@field validate fun(data: any, schema_name: string): boolean, string? Validate data against a named schema
---@field get_schema fun(schema_name: string): table|nil, string? Get a schema definition by name
---@field detect_schema fun(data: any): string? Automatically detect which schema matches the data
---@field validate_format fun(data: any, format: string): boolean, string? Validate data against a specific output format
---@field format_validation_error fun(err: string): string Format a validation error message for better readability
---@field create_schema fun(schema_def: table): table Create a new validation schema with proper metatable
-- Schema module for validating coverage reports and test results against defined schemas
-- Used to ensure data structures are properly formatted before processing or outputting
local M = {}

-- Import logging module
local logging = require("lib.tools.logging")

-- Create logger for this module
local logger = logging.get_logger("Reporting:Schema")

-- Configure module logging
logging.configure_from_config("Reporting:Schema")

-- Schema for coverage data structure
M.COVERAGE_SCHEMA = {
  type = "table",
  required = { "files", "summary" },
  properties = {
    files = {
      type = "table",
      description = "Table containing coverage data for each file",
      dynamic_properties = {
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
        total_files = { type = "number", minimum = 0 },
        covered_files = { type = "number", minimum = 0, optional = true },
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
        overall_percent = { type = "number", minimum = 0, maximum = 100, optional = true },
      },
    },
    original_files = {
      type = "table",
      optional = true,
      description = "Original source files used for coverage analysis",
      dynamic_properties = {
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

-- Schema for test results data structure
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

-- Schema for quality data structure
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

-- Schema for HTML coverage format
M.HTML_COVERAGE_SCHEMA = {
  type = "string",
  pattern = "^<!DOCTYPE html>",
}

-- Schema for JSON coverage format
M.JSON_COVERAGE_SCHEMA = {
  type = "table",
  required = { "files", "summary" },
  -- Same structure as COVERAGE_SCHEMA
}

-- Schema for LCOV coverage format
M.LCOV_COVERAGE_SCHEMA = {
  type = "string",
  pattern = "^TN:",
}

-- Schema for Cobertura XML coverage format
M.COBERTURA_COVERAGE_SCHEMA = {
  type = "string",
  pattern = "^<%?xml",
}

-- Schema for TAP test results format
M.TAP_RESULTS_SCHEMA = {
  type = "string",
  pattern = "^TAP version ",
}

-- Schema for JUnit XML test results format
M.JUNIT_RESULTS_SCHEMA = {
  type = "string",
  pattern = "^<%?xml",
}

-- Schema for CSV test results format
M.CSV_RESULTS_SCHEMA = {
  type = "string",
  pattern = "^[\"']?test[\"']?,",
}

-- Utility functions for schema validation
--- Validate that a value matches the required type and constraints in a schema
---@private
---@param value any The value to validate against the schema
---@param schema {type: string, optional?: boolean, pattern?: string, enum?: string[], minimum?: number, maximum?: number} The schema definition with type and constraints
---@return boolean success Whether the value matches the schema type and constraints
---@return string? error_message Error message if validation failed, nil otherwise
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

--- Recursively validate a value against a schema, including nested properties
---@private
---@param value any The value to validate against the schema
---@param schema {type: string, optional?: boolean, required?: string[], properties?: table<string, table>, array_of?: table, dynamic_properties?: table} The schema definition with type and structure requirements
---@param path? string The current path in the validation tree (for error messages)
---@return boolean success Whether the value conforms to the schema structure
---@return string? error_message Error message if validation failed, including the path to the failure point
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
---@return string? error_message Error message if validation failed
function M.validate(data, schema_name)
  logger.debug("Validating data against schema", { schema = schema_name })

  local schema = M[schema_name]
  if not schema then
    logger.error("Schema not found", { schema_name = schema_name })
    return false, "Schema not found: " .. schema_name
  end

  -- For string validation that needs to test file contents
  if schema.type == "string" and type(data) == "string" then
    if schema.pattern and not data:sub(1, 50):match(schema.pattern) then
      logger.warn("String validation failed", {
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
    logger.warn("Schema validation failed", {
      schema = schema_name,
      error = err,
    })
    return false, err
  end

  logger.debug("Schema validation successful", { schema = schema_name })
  return true
end

---@param data any The data to detect schema for
---@return string? schema_name The detected schema name or nil if no match
function M.detect_schema(data)
  logger.debug("Detecting schema for data")

  if type(data) == "table" then
    -- Check for coverage data
    if data.files and data.summary then
      logger.debug("Detected coverage data")
      return "COVERAGE_SCHEMA"
    end

    -- Check for test results data
    if data.name and data.tests then
      logger.debug("Detected test results data")
      return "TEST_RESULTS_SCHEMA"
    end

    -- Check for quality data
    if data.level and data.summary and data.summary.quality_percent then
      logger.debug("Detected quality data")
      return "QUALITY_SCHEMA"
    end
  elseif type(data) == "string" then
    -- Check string formats
    local first_line = data:match("^([^\n]+)")

    if first_line:match("^<!DOCTYPE html") then
      logger.debug("Detected HTML format")
      return "HTML_COVERAGE_SCHEMA"
    elseif first_line:match("^<%?xml") then
      -- Need to check if it's JUnit or Cobertura
      if data:match("testsuites") or data:match("testsuite") then
        logger.debug("Detected JUnit XML format")
        return "JUNIT_RESULTS_SCHEMA"
      else
        logger.debug("Detected Cobertura XML format")
        return "COBERTURA_COVERAGE_SCHEMA"
      end
    elseif first_line:match("^TN:") then
      logger.debug("Detected LCOV format")
      return "LCOV_COVERAGE_SCHEMA"
    elseif first_line:match("^TAP version") then
      logger.debug("Detected TAP format")
      return "TAP_RESULTS_SCHEMA"
    elseif first_line:match("^[\"']?test[\"']?,") then
      logger.debug("Detected CSV format")
      return "CSV_RESULTS_SCHEMA"
    end
  end

  logger.warn("Unable to detect schema for data")
  return nil
end

---@param data any The data to validate
---@param format string The format name to validate against
---@return boolean success Whether the data is valid for the given format
---@return string? error_message Error message if validation failed
function M.validate_format(data, format)
  logger.debug("Validating format", { format = format })

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
      logger.warn("Unknown format", { format = format })
      return false, "Unknown format: " .. format
    end
  end

  return M.validate(data, schema_name)
end

-- Return the module
return M
