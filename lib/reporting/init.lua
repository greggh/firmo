--- Reporting module for firmo test framework
--- Centralized module for all report generation and file output
---
--- Features:
--- - Unified interface for generating coverage, quality, and test results reports
--- - Support for multiple output formats (HTML, JSON, XML, CSV, TAP, etc.)
--- - Pluggable formatter system with customizable themes and options
--- - File saving with appropriate error handling and validation
--- - Integration with central configuration system
--- - Automatic directory creation and path management
--- - Validation of report data and formatted output
---
--- This module handles the entire reporting pipeline from raw data to formatted output files,
--- including validation, formatting, and file I/O operations.
---
--- @version 0.4.0
--- @author Firmo Team

---@class reporting
---@field configure fun(options?: table): reporting Configure the reporting module with custom options
---@field get_config fun(): table Get the current configuration
---@field register_formatter fun(format: string, formatter: table): reporting Register a custom formatter
---@field register_coverage_formatter fun(name: string, formatter_fn: function): boolean|nil, table? Register a custom coverage report formatter
---@field register_quality_formatter fun(name: string, formatter_fn: function): boolean|nil, table? Register a custom quality report formatter
---@field register_results_formatter fun(name: string, formatter_fn: function): boolean|nil, table? Register a custom test results formatter
---@field get_formatter fun(format: string, type: string): table|nil Get a formatter by name and type
---@field get_formatter_config fun(formatter_name: string): table|nil Get configuration for a specific formatter
---@field configure_formatter fun(formatter_name: string, formatter_config: table): reporting Configure a specific formatter
---@field configure_formatters fun(formatters_config: table): reporting Configure multiple formatters at once
---@field load_formatters fun(formatter_module: table): number|nil, table? Load formatters from a module
---@field get_available_formatters fun(): table Get list of available formatters for each type
---@field generate_report fun(data: table, options?: table): boolean|nil, string? Generate a report
---@field get_report_path fun(type: string, format: string, options?: table): string Get the path for a report file
---@field load_formatter fun(format: string, type: string): table|nil Load a formatter module with lazy loading
---@field run_formatter fun(formatter: table, data: table, options?: table): string|nil Generate report output with a formatter
---@field format_coverage fun(coverage_data: table, format?: string, options?: table): string|table Format coverage data into the specified format
---@field format_quality fun(quality_data: table, format?: string, options?: table): string|table Format quality data into the specified format
---@field format_results fun(results_data: table, format?: string, options?: table): string|table Format test results data into the specified format
---@field save_coverage_report fun(file_path: string, coverage_data: table, format: string, options?: table): boolean|nil, table? Save a coverage report to a file
---@field save_quality_report fun(file_path: string, quality_data: table, format: string, options?: table): boolean|nil, table? Save a quality report to a file
---@field save_results_report fun(file_path: string, results_data: table, format: string, options?: table): boolean|nil, table? Save a test results report to a file
---@field auto_save_reports fun(coverage_data: table, quality_data: table, results_data: table, options?: table|string): table Generate and save all reports to default locations
---@field validate_coverage_data fun(coverage_data: table): boolean, table? Validate coverage data structure
---@field validate_report_format fun(formatted_data: string|table, format: string): boolean, string? Validate formatted report
---@field validate_report fun(coverage_data: table, formatted_output?: string|table, format?: string): table Run comprehensive validation of report
---@field validate_formatter_config fun(formatter_name: string, config: table): boolean, table? Validate formatter configuration
---@field write_file fun(file_path: string, content: string|table): boolean|nil, table? Write content to a file
---@field reset fun(): reporting Reset the module to default configuration
---@field full_reset fun(): reporting Reset both local and central configuration
---@field debug_config fun(): table Show current configuration for debugging
---@field _VERSION string Module version identifier

local M = {}

-- Module version
M._VERSION = "0.5.0"

-- Import modules
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Default configuration
local DEFAULT_CONFIG = {
  debug = false,
  verbose = false,
  report_dir = "./coverage-reports",
  report_suffix = "",
  timestamp_format = "%Y-%m-%d",
  formats = {
    coverage = {
      default = "html",
      path_template = nil,
    },
    quality = {
      default = "html",
      path_template = nil,
    },
    results = {
      default = "junit",
      path_template = nil,
    },
  },
  formatters = {
    html = {
      theme = "dark",
      show_line_numbers = true,
      collapsible_sections = true,
      highlight_syntax = true,
      asset_base_path = nil,
      include_legend = true,
      max_file_size = 10 * 1024 * 1024, -- 10MB max file size for HTML report
      template_path = nil,               -- Custom template path
      stylesheet_path = nil,             -- Custom stylesheet path
      enable_dark_mode = true,           -- Support dark mode toggle
      inline_source = true,              -- Include source code inline
      line_number_anchors = true,        -- Enable line number anchors
    },
    summary = {
      detailed = false,
      show_files = true,
      colorize = true,
      show_function_coverage = true,     -- Show function coverage
      sort_by = "coverage",              -- Sort by coverage percentage
      max_files = 100,                   -- Maximum files to show in summary
    },
    json = {
      pretty = false,
      schema_version = "1.0",
      indentation = 2,                   -- Indentation level when pretty-printing
      enable_streaming = true,           -- Enable streaming for large files
      chunk_size = 1024 * 1024,          -- 1MB chunks for streaming
      omit_source_code = false,          -- Whether to include source code
    },
    lcov = {
      absolute_paths = false,
      include_function_coverage = true,  -- Include function coverage data
      include_branch_coverage = false,   -- Include branch coverage data
      normalize_paths = true,            -- Normalize paths for cross-platform compatibility
    },
    cobertura = {
      schema_version = "4.0",
      include_packages = true,
      include_source = true,             -- Include source in report
      include_methods = true,            -- Include methods in report
      include_conditions = false,        -- Include conditions in report
    },
    junit = {
      schema_version = "2.0",
      include_timestamps = true,
      include_hostname = true,
      include_properties = true,         -- Include properties in report
      format_stack_traces = true,        -- Format stack traces for readability
      use_cdata = true,                  -- Use CDATA sections for message content
    },
    tap = {
      version = 13,
      verbose = true,
      include_yaml_diagnostics = true,   -- Include YAML diagnostics
      include_summary = true,            -- Include summary comments
      include_stack_traces = true,       -- Include stack traces in diagnostics
      include_uncovered_list = false,    -- List uncovered items
    },
    csv = {
      delimiter = ",",
      quote = '"',
      include_header = true,
      columns = nil,                     -- Custom columns specification
      escape_special_chars = true,       -- Properly escape special characters
      include_line_data = false,         -- Include per-line data
    },
  },
  lazy_loading = {
    enabled = true,                      -- Enable lazy loading of formatters
    formatters_path = "lib.reporting.formatters",  -- Base path for formatters
    load_on_demand = true,               -- Load formatters only when needed
  },
  validation = {
    validate_config = true,              -- Validate formatter configurations
    validate_data = true,                -- Validate data before formatting
    validate_output = true,              -- Validate output after formatting
    strict = false,                      -- Whether to fail on validation errors
  }
}

-- Current configuration (will be synchronized with central config)
local config = {
  debug = DEFAULT_CONFIG.debug,
  verbose = DEFAULT_CONFIG.verbose,
}

-- Create a logger for this module
local logger = logging.get_logger("Reporting")

-- Lazy loading of central_config to avoid circular dependencies
local _central_config

---@return table|nil central_config The central config module if loaded
---@private
local function get_central_config()
  if not _central_config then
    -- Use pcall to safely attempt loading central_config
    local success, central_config = pcall(require, "lib.core.central_config")
    if success then
      _central_config = central_config

      -- Register this module with central_config
      _central_config.register_module("reporting", {
        -- Schema
        field_types = {
          debug = "boolean",
          verbose = "boolean",
          report_dir = "string",
          report_suffix = "string",
          timestamp_format = "string",
          formats = "table",
          formatters = "table",
        },
      }, DEFAULT_CONFIG)

      -- Register formatter-specific schema
      _central_config.register_module("reporting.formatters", {
        field_types = {
          html = "table",
          summary = "table",
          json = "table",
          lcov = "table",
          cobertura = "table",
          junit = "table",
          tap = "table",
          csv = "table",
        },
      }, DEFAULT_CONFIG.formatters)

      logger.debug("Successfully loaded central_config", {
        module = "reporting",
      })
    else
      logger.debug("Failed to load central_config", {
        error = tostring(central_config),
      })
    end
  end

  return _central_config
end

-- Load the JSON module if available
local json_module
local ok, mod = pcall(require, "lib.reporting.json")
if ok then
  json_module = mod
else
  -- Simple fallback JSON encoder if module isn't available
  json_module = {
    encode = function(t)
      if type(t) ~= "table" then
        return tostring(t)
      end
      local s = "{"
      local first = true
      for k, v in pairs(t) do
        if not first then
          s = s .. ","
        else
          first = false
        end
        if type(k) == "string" then
          s = s .. '"' .. k .. '":'
        else
          s = s .. "[" .. tostring(k) .. "]:"
        end
        if type(v) == "table" then
          s = s .. json_module.encode(v)
        elseif type(v) == "string" then
          s = s .. '"' .. v .. '"'
        elseif type(v) == "number" or type(v) == "boolean" then
          s = s .. tostring(v)
        else
          s = s .. '"' .. tostring(v) .. '"'
        end
      end
      return s .. "}"
    end,
  }
end

--- Helper function to escape XML special characters for use in XML output formats
---@private
---@param str string|any String to escape or any value to convert to string and escape
---@return string escaped_string String with XML special characters escaped (&, <, >, ", ')
---@diagnostic disable-next-line: unused-local, unused-function
local function escape_xml(str)
  if type(str) ~= "string" then
    return tostring(str or "")
  end

  return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
end

---@return boolean success Whether the listener was registered
---@private
-- Set up change listener for central configuration
local function register_change_listener()
  local central_config = get_central_config()
  if not central_config then
    logger.debug("Cannot register change listener - central_config not available")
    return false
  end

  -- Register change listener for reporting configuration
  ---@diagnostic disable-next-line: unused-local
  central_config.on_change("reporting", function(path, old_value, new_value)
    logger.debug("Configuration change detected", {
      path = path,
      changed_by = "central_config",
    })

    -- Update local configuration from central_config
    local reporting_config = central_config.get("reporting")
    if reporting_config then
      -- Update debug and verbose settings directly
      if reporting_config.debug ~= nil and reporting_config.debug ~= config.debug then
        config.debug = reporting_config.debug
        logger.debug("Updated debug setting from central_config", {
          debug = config.debug,
        })
      end

      if reporting_config.verbose ~= nil and reporting_config.verbose ~= config.verbose then
        config.verbose = reporting_config.verbose
        logger.debug("Updated verbose setting from central_config", {
          verbose = config.verbose,
        })
      end

      -- Update logging configuration
      logging.configure_from_options("Reporting", {
        debug = config.debug,
        verbose = config.verbose,
      })

      logger.debug("Applied configuration changes from central_config")
    end
  end)

  logger.debug("Registered change listener for central configuration")
  return true
end

---@param options? table Configuration options for the reporting module
---@return reporting The reporting module for method chaining
-- Configure the module
function M.configure(options)
  options = options or {}

  logger.debug("Configuring reporting module", {
    debug = options.debug,
    verbose = options.verbose,
    has_options = options ~= nil,
  })

  -- Check for central configuration first
  local central_config = get_central_config()
  if central_config then
    -- Get existing central config values
    local reporting_config = central_config.get("reporting")

    -- Apply central configuration (with defaults as fallback)
    if reporting_config then
      logger.debug("Using central_config values for initialization", {
        debug = reporting_config.debug,
        verbose = reporting_config.verbose,
      })

      if reporting_config.debug ~= nil then
        config.debug = reporting_config.debug
      else
        config.debug = DEFAULT_CONFIG.debug
      end

      if reporting_config.verbose ~= nil then
        config.verbose = reporting_config.verbose
      else
        config.verbose = DEFAULT_CONFIG.verbose
      end
    else
      logger.debug("No central_config values found, using defaults")
      config.debug = DEFAULT_CONFIG.debug
      config.verbose = DEFAULT_CONFIG.verbose
    end

    -- Register change listener if not already done
    register_change_listener()
  else
    logger.debug("central_config not available, using defaults")
    -- Apply defaults
    config.debug = DEFAULT_CONFIG.debug
    config.verbose = DEFAULT_CONFIG.verbose
  end

  -- Apply user options (highest priority) and update central config
  if options.debug ~= nil then
    config.debug = options.debug

    -- Update central_config if available
    if central_config then
      central_config.set("reporting.debug", options.debug)
    end
  end

  if options.verbose ~= nil then
    config.verbose = options.verbose

    -- Update central_config if available
    if central_config then
      central_config.set("reporting.verbose", options.verbose)
    end
  end

  -- Configure reporting directory and other settings if provided
  if options.report_dir then
    -- Update central_config if available
    if central_config then
      central_config.set("reporting.report_dir", options.report_dir)
    end
  end

  -- Configure formatter options if provided
  if options.formats then
    -- Update central_config if available
    if central_config then
      central_config.set("reporting.formats", options.formats)
    end
  end

  -- We can use options directly for logging configuration if provided
  if options.debug ~= nil or options.verbose ~= nil then
    logger.debug("Using provided options for logging configuration")
    logging.configure_from_options("Reporting", options)
  else
    -- Otherwise use global config
    logger.debug("Using global config for logging configuration")
    logging.configure_from_config("Reporting")
  end

  logger.debug("Reporting module configuration complete", {
    debug = config.debug,
    verbose = config.verbose,
    using_central_config = central_config ~= nil,
  })

  -- Return the module for chaining
  return M
end

---@param formatter_name string Name of the formatter to get configuration for
---@return table|nil formatter_config Configuration for the formatter or nil if not found
-- Get configuration for a specific formatter
function M.get_formatter_config(formatter_name)
  if not formatter_name then
    logger.warn("Formatter name required for get_formatter_config")
    return nil
  end

  -- Try to get from central_config
  local central_config = get_central_config()
  if central_config then
    local formatter_config = central_config.get("reporting.formatters." .. formatter_name)
    if formatter_config then
      logger.debug("Retrieved formatter config from central_config", {
        formatter = formatter_name,
      })
      return formatter_config
    end
  end

  -- Fall back to local config
  if config.formatters and config.formatters[formatter_name] then
    logger.debug("Retrieved formatter config from local config", {
      formatter = formatter_name,
    })
    return config.formatters[formatter_name]
  end

  -- Return default config if available
  if DEFAULT_CONFIG.formatters and DEFAULT_CONFIG.formatters[formatter_name] then
    logger.debug("Using default formatter config", {
      formatter = formatter_name,
    })
    return DEFAULT_CONFIG.formatters[formatter_name]
  end

  logger.warn("No configuration found for formatter", {
    formatter = formatter_name,
  })
  return {}
end

---@param formatter_name string Name of the formatter to configure
---@param formatter_config table Configuration options for the formatter
---@return reporting The reporting module for method chaining
-- Configure a specific formatter
function M.configure_formatter(formatter_name, formatter_config)
  if not formatter_name then
    logger.error("Formatter name required for configure_formatter")
    return M
  end

  if type(formatter_config) ~= "table" then
    logger.error("Invalid formatter configuration", {
      formatter = formatter_name,
      config_type = type(formatter_config),
    })
    return M
  end

  -- Update central_config if available
  local central_config = get_central_config()
  if central_config then
    central_config.set("reporting.formatters." .. formatter_name, formatter_config)
  end

  -- Update local config
  config.formatters = config.formatters or {}
  config.formatters[formatter_name] = config.formatters[formatter_name] or {}

  for k, v in pairs(formatter_config) do
    config.formatters[formatter_name][k] = v
  end

  logger.debug("Updated configuration for formatter", {
    formatter = formatter_name,
    config_count = #formatter_config,
  })

  return M
end

---@param formatters_config table Table of formatter configurations {formatter_name = config, ...}
---@return reporting The reporting module for method chaining
-- Configure multiple formatters at once
function M.configure_formatters(formatters_config)
  if type(formatters_config) ~= "table" then
    logger.error("Invalid formatters configuration", {
      config_type = type(formatters_config),
    })
    return M
  end

  for formatter_name, formatter_config in pairs(formatters_config) do
    M.configure_formatter(formatter_name, formatter_config)
  end

  return M
end

---------------------------
-- REPORT DATA STRUCTURES
---------------------------

-- Standard data structures that modules should return

-- Coverage report data structure
-- Modules should return this structure instead of directly generating reports
M.CoverageData = {
  -- Example structure that modules should follow:
  -- files = {}, -- Data per file (line execution, function calls)
  -- summary = {  -- Overall statistics
  --   total_files = 0,
  --   covered_files = 0,
  --   total_lines = 0,
  --   covered_lines = 0,
  --   total_functions = 0,
  --   covered_functions = 0,
  --   line_coverage_percent = 0,
  --   function_coverage_percent = 0,
  --   overall_percent = 0
  -- }
}

-- Quality report data structure
-- Modules should return this structure instead of directly generating reports
M.QualityData = {
  -- Example structure that modules should follow:
  -- level = 0, -- Achieved quality level (0-5)
  -- level_name = "", -- Level name (e.g., "basic", "standard", etc.)
  -- tests = {}, -- Test data with assertions, patterns, etc.
  -- summary = {
  --   tests_analyzed = 0,
  --   tests_passing_quality = 0,
  --   quality_percent = 0,
  --   assertions_total = 0,
  --   assertions_per_test_avg = 0,
  --   issues = {}
  -- }
}

-- Test results data structure for JUnit XML and other test reporters
M.TestResultsData = {
  -- Example structure that modules should follow:
  -- name = "TestSuite", -- Name of the test suite
  -- timestamp = "2023-01-01T00:00:00", -- ISO 8601 timestamp
  -- tests = 0, -- Total number of tests
  -- failures = 0, -- Number of failed tests
  -- errors = 0, -- Number of tests with errors
  -- skipped = 0, -- Number of skipped tests
  -- time = 0, -- Total execution time in seconds
  -- test_cases = { -- Array of test case results
  --   {
  --     name = "test_name",
  --     classname = "test_class", -- Usually module/file name
  --     time = 0, -- Execution time in seconds
  --     status = "pass", -- One of: pass, fail, error, skipped, pending
  --     failure = { -- Only present if status is fail
  --       message = "Failure message",
  --       type = "Assertion",
  --       details = "Detailed failure information"
  --     },
  --     error = { -- Only present if status is error
  --       message = "Error message",
  --       type = "RuntimeError",
  --       details = "Stack trace or error details"
  --     }
  --   }
  -- }
}

---------------------------
-- REPORT FORMATTERS
---------------------------

-- Formatter registries for built-in and custom formatters
local formatters = {
  coverage = {}, -- Coverage report formatters
  quality = {}, -- Quality report formatters
  results = {}, -- Test results formatters
}

-- Load and register all formatter modules with improved error handling
local function load_formatter_registry()
  logger.debug("Loading formatter registry")
  
  -- Use error_handler.try for better error handling
  local success, result, err = error_handler.try(function()
    return require("lib.reporting.formatters.init")
  end)
  
  if success and result then
    logger.debug("Successfully loaded formatter registry")
    
    -- Register formatters with error handling
    local register_success, register_result, register_err = error_handler.try(function()
      return result.register_all(formatters)
    end)
    
    if register_success then
      logger.debug("Successfully registered all formatters", {
        coverage_count = formatters.coverage and #formatters.coverage or 0,
        quality_count = formatters.quality and #formatters.quality or 0,
        results_count = formatters.results and #formatters.results or 0
      })
      return true
    else
      logger.warn("Failed to register formatters", {
        error = error_handler.format_error(register_result),
        module = "reporting"
      })
      return false
    end
  else
    logger.warn("Failed to load formatter registry", {
      error = error_handler.format_error(result),
      module = "reporting"
    })
    return false
  end
end

-- Attempt to load formatter registry
if not load_formatter_registry() then
  logger.warn("Using fallback formatters due to registry loading failure")
  
  -- Fallback formatters with proper error handling
  -- Summary formatter
  if not formatters.coverage.summary then
    formatters.coverage.summary = function(coverage_data, options)
      options = options or {}
      
      -- Use error handler to safely process data
      local success, result, err = error_handler.try(function()
        return {
          files = coverage_data and coverage_data.files or {},
          total_files = coverage_data and coverage_data.summary and coverage_data.summary.total_files or 0,
          covered_files = coverage_data and coverage_data.summary and coverage_data.summary.covered_files or 0,
          files_pct = coverage_data and coverage_data.summary and coverage_data.summary.files_percent or 0,
          total_lines = coverage_data and coverage_data.summary and coverage_data.summary.total_lines or 0,
          covered_lines = coverage_data and coverage_data.summary and coverage_data.summary.covered_lines or 0,
          lines_pct = coverage_data and coverage_data.summary and coverage_data.summary.coverage_percent or 0,
          overall_pct = coverage_data and coverage_data.summary and coverage_data.summary.coverage_percent or 0
        }
      end)
      
      if success then
        return result
      else
        logger.error("Summary formatter processing error", {
          error = error_handler.format_error(result),
          module = "reporting.summary"
        })
        return {
          files = {},
          total_files = 0,
          covered_files = 0,
          files_pct = 0,
          total_lines = 0,
          covered_lines = 0,
          lines_pct = 0,
          overall_pct = 0
        }
      end
    end
  end
end

-- Local references to formatter registries
---@diagnostic disable-next-line: unused-local
local coverage_formatters = formatters.coverage
---@diagnostic disable-next-line: unused-local
local quality_formatters = formatters.quality
---@diagnostic disable-next-line: unused-local
local results_formatters = formatters.results

---------------------------
-- CUSTOM FORMATTER REGISTRATION
---------------------------

---@param name string Name of the formatter to register
---@param formatter_fn function Function to format coverage reports
---@return boolean|nil success True if formatter was registered successfully, nil if failed
---@return table|nil error Error object if registration failed
-- Register a custom coverage report formatter
function M.register_coverage_formatter(name, formatter_fn)
  -- Validate name parameter
  if type(name) ~= "string" then
    local err = error_handler.validation_error("Failed to register coverage formatter: name must be a string", {
      name_type = type(name),
      operation = "register_coverage_formatter",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Validate formatter_fn parameter
  if type(formatter_fn) ~= "function" then
    local err = error_handler.validation_error("Failed to register coverage formatter: formatter must be a function", {
      formatter_name = name,
      formatter_type = type(formatter_fn),
      operation = "register_coverage_formatter",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Register the formatter using error_handler.try
  local success, result = error_handler.try(function()
    formatters.coverage[name] = formatter_fn
    return true
  end)

  if not success then
    local err = error_handler.runtime_error(
      "Failed to register coverage formatter: registration error",
      {
        formatter_name = name,
        operation = "register_coverage_formatter",
        module = "reporting",
      },
      result -- result contains the error when success is false
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Registered custom coverage formatter", {
    formatter_name = name,
  })

  return true
end

---@param name string Name of the formatter to register
---@param formatter_fn function Function to format quality reports
---@return boolean|nil success True if formatter was registered successfully, nil if failed
---@return table|nil error Error object if registration failed
-- Register a custom quality report formatter
function M.register_quality_formatter(name, formatter_fn)
  -- Validate name parameter
  if type(name) ~= "string" then
    local err = error_handler.validation_error("Failed to register quality formatter: name must be a string", {
      name_type = type(name),
      operation = "register_quality_formatter",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Validate formatter_fn parameter
  if type(formatter_fn) ~= "function" then
    local err = error_handler.validation_error("Failed to register quality formatter: formatter must be a function", {
      formatter_name = name,
      formatter_type = type(formatter_fn),
      operation = "register_quality_formatter",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Register the formatter using error_handler.try
  local success, result = error_handler.try(function()
    formatters.quality[name] = formatter_fn
    return true
  end)

  if not success then
    local err = error_handler.runtime_error(
      "Failed to register quality formatter: registration error",
      {
        formatter_name = name,
        operation = "register_quality_formatter",
        module = "reporting",
      },
      result -- result contains the error when success is false
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Registered custom quality formatter", {
    formatter_name = name,
  })

  return true
end

---@param name string Name of the formatter to register
---@param formatter_fn function Function to format test results
---@return boolean|nil success True if formatter was registered successfully, nil if failed
---@return table|nil error Error object if registration failed
-- Register a custom test results formatter
function M.register_results_formatter(name, formatter_fn)
  -- Validate name parameter
  if type(name) ~= "string" then
    local err = error_handler.validation_error("Failed to register results formatter: name must be a string", {
      name_type = type(name),
      operation = "register_results_formatter",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Validate formatter_fn parameter
  if type(formatter_fn) ~= "function" then
    local err = error_handler.validation_error("Failed to register results formatter: formatter must be a function", {
      formatter_name = name,
      formatter_type = type(formatter_fn),
      operation = "register_results_formatter",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Register the formatter using error_handler.try
  local success, result = error_handler.try(function()
    formatters.results[name] = formatter_fn
    return true
  end)

  if not success then
    local err = error_handler.runtime_error(
      "Failed to register results formatter: registration error",
      {
        formatter_name = name,
        operation = "register_results_formatter",
        module = "reporting",
      },
      result -- result contains the error when success is false
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Registered custom results formatter", {
    formatter_name = name,
  })

  return true
end

---@param formatter_module table Module containing formatters {coverage={}, quality={}, results={}}
---@return number|nil registered Number of formatters registered or nil if failed
---@return table|nil error Error object if some formatters failed to register
-- Load formatters from a module (table with format functions)
function M.load_formatters(formatter_module)
  -- Validate formatter_module parameter
  if type(formatter_module) ~= "table" then
    local err = error_handler.validation_error("Failed to load formatters: module must be a table", {
      module_type = type(formatter_module),
      operation = "load_formatters",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Loading formatters from module", {
    has_coverage = type(formatter_module.coverage) == "table",
    has_quality = type(formatter_module.quality) == "table",
    has_results = type(formatter_module.results) == "table",
  })

  local registered = 0
  local registration_errors = {}

  -- Register coverage formatters with error handling
  if type(formatter_module.coverage) == "table" then
    local coverage_formatters = {}
    for name, fn in pairs(formatter_module.coverage) do
      if type(fn) == "function" then
        local success, err = error_handler.try(function()
          return M.register_coverage_formatter(name, fn)
        end)

        if success then
          registered = registered + 1
          table.insert(coverage_formatters, name)
        else
          -- Add to errors list but continue with other formatters
          table.insert(registration_errors, {
            formatter_type = "coverage",
            name = name,
            error = err,
          })
          logger.warn("Failed to register coverage formatter", {
            formatter_name = name,
            error = error_handler.format_error(err),
          })
        end
      end
    end

    if #coverage_formatters > 0 then
      logger.debug("Registered coverage formatters", {
        count = #coverage_formatters,
        formatters = coverage_formatters,
      })
    end
  end

  -- Register quality formatters with error handling
  if type(formatter_module.quality) == "table" then
    local quality_formatters = {}
    for name, fn in pairs(formatter_module.quality) do
      if type(fn) == "function" then
        local success, err = error_handler.try(function()
          return M.register_quality_formatter(name, fn)
        end)

        if success then
          registered = registered + 1
          table.insert(quality_formatters, name)
        else
          -- Add to errors list but continue with other formatters
          table.insert(registration_errors, {
            formatter_type = "quality",
            name = name,
            error = err,
          })
          logger.warn("Failed to register quality formatter", {
            formatter_name = name,
            error = error_handler.format_error(err),
          })
        end
      end
    end

    if #quality_formatters > 0 then
      logger.debug("Registered quality formatters", {
        count = #quality_formatters,
        formatters = quality_formatters,
      })
    end
  end

  -- Register test results formatters with error handling
  if type(formatter_module.results) == "table" then
    local results_formatters = {}
    for name, fn in pairs(formatter_module.results) do
      if type(fn) == "function" then
        local success, err = error_handler.try(function()
          return M.register_results_formatter(name, fn)
        end)

        if success then
          registered = registered + 1
          table.insert(results_formatters, name)
        else
          -- Add to errors list but continue with other formatters
          table.insert(registration_errors, {
            formatter_type = "results",
            name = name,
            error = err,
          })
          logger.warn("Failed to register results formatter", {
            formatter_name = name,
            error = error_handler.format_error(err),
          })
        end
      end
    end

    if #results_formatters > 0 then
      logger.debug("Registered results formatters", {
        count = #results_formatters,
        formatters = results_formatters,
      })
    end
  end

  logger.debug("Completed formatter registration", {
    total_registered = registered,
    error_count = #registration_errors,
  })

  -- If we have errors but still registered some formatters, return partial success
  if #registration_errors > 0 then
    local err = error_handler.runtime_error("Some formatters failed to register", {
      total_attempted = registered + #registration_errors,
      successful = registered,
      failed = #registration_errors,
      operation = "load_formatters",
      module = "reporting",
    })

    -- Return the number registered and the error object
    return registered, err
  end

  return registered
end

---@return table available_formatters Table with lists of formatters by type {coverage={}, quality={}, results={}}
-- Get list of available formatters for each type
function M.get_available_formatters()
  logger.debug("Getting available formatters")

  local available = {
    coverage = {},
    quality = {},
    results = {},
  }

  -- Collect formatter names
  for name, _ in pairs(formatters.coverage) do
    table.insert(available.coverage, name)
  end

  for name, _ in pairs(formatters.quality) do
    table.insert(available.quality, name)
  end

  for name, _ in pairs(formatters.results) do
    table.insert(available.results, name)
  end

  -- Sort for consistent results
  table.sort(available.coverage)
  table.sort(available.quality)
  table.sort(available.results)

  logger.debug("Available formatters", {
    coverage_count = #available.coverage,
    coverage = table.concat(available.coverage, ", "),
    quality_count = #available.quality,
    quality = table.concat(available.quality, ", "),
    results_count = #available.results,
    results = table.concat(available.results, ", "),
  })

  return available
end

---------------------------
-- FORMAT OUTPUT FUNCTIONS
---------------------------

---@param type string Type of report ("coverage", "quality", or "results")
---@return string format Default format name for the specified report type
---@private
-- Get default format from configuration
local function get_default_format(type)
  -- Check central_config first
  local central_config = get_central_config()
  if central_config then
    local format_config = central_config.get("reporting.formats." .. type .. ".default")
    if format_config then
      return format_config
    end
  end

  -- Fall back to local defaults
  if DEFAULT_CONFIG.formats and DEFAULT_CONFIG.formats[type] then
    return DEFAULT_CONFIG.formats[type].default
  end

  -- Final fallbacks based on type
  if type == "coverage" then
    return "summary"
  elseif type == "quality" then
    return "summary"
  elseif type == "results" then
    return "junit"
  else
    return "summary"
  end
end

-- Format coverage data
function M.format_coverage(coverage_data, format)
  -- If no format specified, use default from config
  format = format or get_default_format("coverage")

  logger.debug("Formatting coverage data", {
    format = format,
    has_data = coverage_data ~= nil,
    formatter_available = formatters.coverage[format] ~= nil,
    from_config = format == get_default_format("coverage"),
  })

  -- Use the appropriate formatter
  if formatters.coverage[format] then
    logger.trace("Using requested formatter", { format = format })
    local result = formatters.coverage[format](coverage_data)

    -- Handle both old-style string returns and new-style structured returns
    if type(result) == "table" and result.output then
      -- For formatters that return a table with both display output and structured data
      return result
    else
      -- For backward compatibility with formatters that return strings directly
      return result
    end
  else
    local default_format = get_default_format("coverage")
    logger.warn("Requested formatter not available, falling back to default", {
      requested_format = format,
      default_format = default_format,
    })
    -- Default to summary formatter explicitly
    logger.debug("Using summary formatter as fallback for invalid format")
    local result = formatters.coverage.summary(coverage_data)

    -- Handle both old-style string returns and new-style structured returns
    if type(result) == "table" and result.output then
      return result
    else
      return result
    end
  end
end

-- Format quality data
function M.format_quality(quality_data, format)
  -- If no format specified, use default from config
  format = format or get_default_format("quality")

  logger.debug("Formatting quality data", {
    format = format,
    has_data = quality_data ~= nil,
    formatter_available = formatters.quality[format] ~= nil,
    from_config = format == get_default_format("quality"),
  })

  -- Use the appropriate formatter
  if formatters.quality[format] then
    logger.trace("Using requested formatter", { format = format })
    local result = formatters.quality[format](quality_data)

    -- Handle both old-style string returns and new-style structured returns
    if type(result) == "table" and result.output then
      -- For formatters that return a table with both display output and structured data
      return result
    else
      -- For backward compatibility with formatters that return strings directly
      return result
    end
  else
    local default_format = get_default_format("quality")
    logger.warn("Requested formatter not available, falling back to default", {
      requested_format = format,
      default_format = default_format,
    })
    -- Default to summary formatter explicitly
    logger.debug("Using summary formatter as fallback for invalid format")
    local result = formatters.quality.summary(quality_data)

    -- Handle both old-style string returns and new-style structured returns
    if type(result) == "table" and result.output then
      return result
    else
      return result
    end
  end
end

-- Format test results data
function M.format_results(results_data, format)
  -- If no format specified, use default from config
  format = format or get_default_format("results")

  logger.debug("Formatting test results data", {
    format = format,
    has_data = results_data ~= nil,
    formatter_available = formatters.results[format] ~= nil,
    from_config = format == get_default_format("results"),
  })

  -- Use the appropriate formatter
  if formatters.results[format] then
    logger.trace("Using requested formatter", { format = format })
    local result = formatters.results[format](results_data)

    -- Handle both old-style string returns and new-style structured returns
    if type(result) == "table" and result.output then
      -- For formatters that return a table with both display output and structured data
      return result
    else
      -- For backward compatibility with formatters that return strings directly
      return result
    end
  else
    local default_format = get_default_format("results")
    logger.warn("Requested formatter not available, falling back to default", {
      requested_format = format,
      default_format = default_format,
    })
    -- Default to junit formatter explicitly
    logger.debug("Using junit formatter as fallback for invalid format")
    local result = formatters.results.junit(results_data)

    -- Handle both old-style string returns and new-style structured returns
    if type(result) == "table" and result.output then
      return result
    else
      return result
    end
  end
end

---------------------------
-- FILE I/O FUNCTIONS
---------------------------

-- Write content to a file using the filesystem module
function M.write_file(file_path, content)
  -- Input validation using error_handler
  if not file_path then
    local err = error_handler.validation_error("Missing required file_path parameter", {
      operation = "write_file",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if not content then
    local err = error_handler.validation_error("Missing required content parameter", {
      operation = "write_file",
      file_path = file_path,
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Writing file", {
    file_path = file_path,
    content_length = content and #content or 0,
  })

  -- Make sure content is a string, with error handling
  local content_str
  ---@diagnostic disable-next-line: unused-local
  local success, result, err

  if type(content) == "table" then
    ---@diagnostic disable-next-line: unused-local
    success, result, err = error_handler.try(function()
      return json_module.encode(content)
    end)

    if not success then
      local error_obj = error_handler.io_error(
        "Failed to encode table as JSON",
        {
          file_path = file_path,
          module = "reporting",
          table_size = #content,
        },
        result -- The error object is in result when success is false
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    content_str = result
    logger.trace("Converted table to JSON string", {
      file_path = file_path,
      content_length = content_str and #content_str or 0,
    })
  else
    -- If not a table, convert to string directly
    ---@diagnostic disable-next-line: unused-local
    success, result, err = error_handler.try(function()
      return tostring(content)
    end)

    if not success then
      local error_obj = error_handler.io_error(
        "Failed to convert content to string",
        {
          file_path = file_path,
          module = "reporting",
          content_type = type(content),
        },
        result -- The error object is in result when success is false
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    content_str = result
    logger.trace("Converted content to string", {
      file_path = file_path,
      content_type = type(content),
      content_length = content_str and #content_str or 0,
    })
  end

  -- Use the filesystem module to write the file with proper error handling
  local write_success, write_err = error_handler.safe_io_operation(
    function()
      return fs.write_file(file_path, content_str)
    end,
    file_path,
    {
      operation = "write_file",
      module = "reporting",
      content_length = content_str and #content_str or 0,
    }
  )

  if not write_success then
    logger.error("Error writing to file", {
      file_path = file_path,
      error = error_handler.format_error(write_err),
    })
    return nil, write_err
  end

  logger.debug("Successfully wrote file", {
    file_path = file_path,
    content_length = content_str and #content_str or 0,
  })
  return true
end

-- Load validation module (lazy loading with fallback)
local _validation_module
local function get_validation_module()
  if not _validation_module then
    -- Use error_handler.try for better error handling and context
    local success, validation = error_handler.try(function()
      return require("lib.reporting.validation")
    end)

    if success then
      _validation_module = validation
      logger.debug("Successfully loaded validation module")
    else
      logger.debug("Failed to load validation module", {
        error = error_handler.format_error(validation),
        operation = "get_validation_module",
        module = "reporting",
      })

      -- Create dummy validation module with structured error handling
      _validation_module = {
        validate_coverage_data = function()
          -- Return dummy validation result (valid with no issues)
          logger.warn("Using dummy validation module", {
            operation = "validate_coverage_data",
            module = "reporting",
          })
          return true, {}
        end,

        validate_report = function()
          -- Return dummy report validation (valid with no issues)
          logger.warn("Using dummy validation module", {
            operation = "validate_report",
            module = "reporting",
          })
          return {
            validation = {
              is_valid = true,
              issues = {},
            },
            statistics = {
              outliers = {},
              anomalies = {},
            },
            cross_check = {
              files_checked = 0,
            },
          }
        end,
      }
    end
  end
  return _validation_module
end

-- Validate coverage data before saving (can be called directly)
function M.validate_coverage_data(coverage_data)
  local validation = get_validation_module()

  logger.debug("Validating coverage data", {
    has_data = coverage_data ~= nil,
    has_summary = coverage_data and coverage_data.summary ~= nil,
    has_files = coverage_data and coverage_data.files ~= nil,
  })

  -- Run validation
  ---@diagnostic disable-next-line: redundant-parameter
  local is_valid, issues = validation.validate_coverage_data(coverage_data)

  logger.info("Coverage data validation results", {
    is_valid = is_valid,
    issue_count = issues and #issues or 0,
  })

  return is_valid, issues
end

-- Validate report format (can be called directly)
function M.validate_report_format(formatted_data, format)
  local validation = get_validation_module()

  logger.debug("Validating report format", {
    format = format,
    has_data = formatted_data ~= nil,
    data_type = type(formatted_data),
  })

  -- Run validation
  local is_valid, error_message = validation.validate_report_format(formatted_data, format)

  logger.info("Format validation results", {
    is_valid = is_valid,
    format = format,
    error = error_message or "none",
  })

  return is_valid, error_message
end

-- Perform comprehensive validation of coverage report
function M.validate_report(coverage_data, formatted_output, format)
  local validation = get_validation_module()

  logger.debug("Running comprehensive report validation", {
    has_data = coverage_data ~= nil,
    has_formatted_output = formatted_output ~= nil,
    format = format,
  })

  -- Setup options for validation
  local options = {}
  if formatted_output and format then
    options.formatted_output = formatted_output
    options.format = format
  end

  -- Run full validation
  ---@diagnostic disable-next-line: redundant-parameter
  local result = validation.validate_report(coverage_data, options)

  logger.info("Comprehensive validation results", {
    is_valid = result.validation.is_valid,
    issues = result.validation.issues and #result.validation.issues or 0,
    format_valid = result.format_validation and result.format_validation.is_valid,
    outliers = result.statistics and result.statistics.outliers and #result.statistics.outliers or 0,
    anomalies = result.statistics and result.statistics.anomalies and #result.statistics.anomalies or 0,
    cross_check_files = result.cross_check and result.cross_check.files_checked or 0,
  })

  return result
end

-- Save a coverage report to file
function M.save_coverage_report(file_path, coverage_data, format, options)
  -- Validate required parameters
  if not file_path then
    local err = error_handler.validation_error("Missing required file_path parameter", {
      operation = "save_coverage_report",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if not coverage_data then
    local err = error_handler.validation_error("Missing required coverage_data parameter", {
      operation = "save_coverage_report",
      file_path = file_path,
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Set defaults
  format = format or "html"
  options = options or {}

  logger.debug("Saving coverage report to file", {
    file_path = file_path,
    format = format,
    has_data = true,
    validate = options.validate ~= false, -- Default to validate=true
  })

  -- CRITICAL FIX: Check for minimal valid data structure before proceeding
  if not coverage_data.files or not coverage_data.summary then
    local err = error_handler.validation_error(
      "Invalid coverage data structure: missing required fields",
      {
        file_path = file_path,
        format = format,
        operation = "save_coverage_report",
        module = "reporting",
        missing_files = coverage_data.files == nil,
        missing_summary = coverage_data.summary == nil
      }
    )
    logger.error(err.message, err.context)
    return nil, err
  end
  
  -- Count files in the coverage data - an empty report is invalid
  local file_count = 0
  if coverage_data.files then
    for _ in pairs(coverage_data.files) do
      file_count = file_count + 1
    end
  end
  
  -- CRITICAL FIX: Fail if there are no files in the coverage data
  if file_count == 0 then
    local err = error_handler.validation_error(
      "Invalid coverage data: no files found in coverage data",
      {
        file_path = file_path,
        format = format,
        operation = "save_coverage_report",
        module = "reporting",
        file_count = file_count
      }
    )
    logger.error(err.message, err.context)
    return nil, err
  end
  
  -- Log file count for debugging
  logger.debug("Coverage file count validation", {
    file_count = file_count,
    files_valid = file_count > 0
  })

  -- Validate coverage data before saving if not disabled
  if options.validate ~= false then
    -- Safely get the validation module using error_handler.try
    local success, validation_module = error_handler.try(function()
      return get_validation_module()
    end)

    if success and validation_module and validation_module.validate_coverage_data then
      -- Validate the coverage data with error handling
      local validation_success, is_valid, issues = error_handler.try(function()
        return validation_module.validate_coverage_data(coverage_data)
      end)

      if validation_success then
        if issues and #issues > 0 and not is_valid then
          logger.warn("Validation issues detected in coverage data", {
            issue_count = #issues,
            first_issue = issues[1] and issues[1].message or "Unknown issue",
          })

          -- If validation is strict, don't save invalid data
          if options.strict_validation then
            local validation_err =
              error_handler.validation_error("Not saving report due to validation failures (strict mode)", {
                file_path = file_path,
                format = format,
                operation = "save_coverage_report",
                module = "reporting",
                issue_count = #issues,
                first_issue = issues[1] and issues[1].message or "Unknown issue",
              })
            logger.error(validation_err.message, validation_err.context)
            return nil, validation_err
          end

          -- Otherwise just warn but continue
          logger.warn("Saving report despite validation issues (non-strict mode)")
        end
      else
        -- Validation failed with an error
        local validation_err = error_handler.runtime_error(
          "Error during coverage data validation",
          {
            file_path = file_path,
            format = format,
            operation = "save_coverage_report",
            module = "reporting",
          },
          is_valid -- is_valid contains the error when validation_success is false
        )
        logger.warn(validation_err.message, validation_err.context)

        -- If validation is strict, don't save on validation error
        if options.strict_validation then
          return nil, validation_err
        end

        -- Otherwise, continue despite validation error
        logger.warn("Continuing with report generation despite validation error (non-strict mode)")
      end
    else
      logger.warn("Validation module not fully available, skipping validation", {
        file_path = file_path,
        format = format,
      })
    end
  end

  -- Format the coverage data with error handling
  ---@diagnostic disable-next-line: unused-local
  local format_success, formatted, format_err = error_handler.try(function()
    return M.format_coverage(coverage_data, format)
  end)

  if not format_success then
    local err = error_handler.runtime_error(
      "Failed to format coverage data",
      {
        file_path = file_path,
        format = format,
        operation = "save_coverage_report",
        module = "reporting",
      },
      formatted -- formatted contains the error when format_success is false
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Handle both old-style string returns and new-style structured returns
  local content
  if type(formatted) == "table" and formatted.output then
    -- For formatters that return a table with both display output and structured data
    content = formatted.output
  else
    -- For backward compatibility with formatters that return strings directly
    content = formatted
  end

  -- Validate the formatted output if requested
  if options.validate_format ~= false then
    logger.debug("Validating formatted output", {
      format = format,
      content_sample = type(content) == "string" and content:sub(1, 50) .. "..." or "non-string content",
    })

    -- Only attempt format validation for certain types
    if (format == "json" and type(content) == "table") or type(content) == "string" then
      local validation_success, format_valid, format_err = error_handler.try(function()
        return M.validate_report_format(content, format)
      end)

      if validation_success and not format_valid then
        logger.warn("Format validation failed", {
          format = format,
          error = format_err,
        })

        -- If strict validation enabled, don't save the file
        if options.strict_validation then
          local validation_err =
            error_handler.validation_error("Not saving report due to format validation failure (strict mode)", {
              file_path = file_path,
              format = format,
              operation = "save_coverage_report",
              module = "reporting",
              error = format_err,
            })
          logger.error(validation_err.message, validation_err.context)
          return nil, validation_err
        end

        -- Otherwise just warn but continue
        logger.warn("Saving report despite format validation issues (non-strict mode)")
      end
    end
  end

  -- Write all formats (including HTML) directly to file
  -- Write to file with error handling
  logger.debug("Writing coverage report file", {
    file_path = file_path,
    format = format,
    content_length = #content
  })
  
  ---@diagnostic disable-next-line: unused-local
  local write_success, write_err = error_handler.try(function()
    return M.write_file(file_path, content)
  end)
  
  if not write_success then
    local err = error_handler.io_error(
      "Failed to write coverage report to file",
      {
        file_path = file_path,
        format = format,
        operation = "save_coverage_report",
        module = "reporting",
      },
      write_err
    )
    logger.error(err.message, err.context)
    return nil, err
  end
  
  logger.debug("Successfully saved coverage report", {
    file_path = file_path,
    format = format,
  })
  
  return true
end

-- Save a quality report to file
function M.save_quality_report(file_path, quality_data, format)
  -- Validate required parameters
  if not file_path then
    local err = error_handler.validation_error("Missing required file_path parameter", {
      operation = "save_quality_report",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if not quality_data then
    local err = error_handler.validation_error("Missing required quality_data parameter", {
      operation = "save_quality_report",
      file_path = file_path,
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Set defaults
  format = format or "html"

  logger.debug("Saving quality report to file", {
    file_path = file_path,
    format = format,
    has_data = true,
  })

  -- Format the quality data with error handling
  ---@diagnostic disable-next-line: unused-local
  local format_success, formatted, format_err = error_handler.try(function()
    return M.format_quality(quality_data, format)
  end)

  if not format_success then
    local err = error_handler.runtime_error(
      "Failed to format quality data",
      {
        file_path = file_path,
        format = format,
        operation = "save_quality_report",
        module = "reporting",
      },
      formatted -- formatted contains the error when format_success is false
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Handle both old-style string returns and new-style structured returns
  local content
  if type(formatted) == "table" and formatted.output then
    -- For formatters that return a table with both display output and structured data
    content = formatted.output
  else
    -- For backward compatibility with formatters that return strings directly
    content = formatted
  end

  -- Write to file with error handling
  ---@diagnostic disable-next-line: unused-local
  local write_success, write_err = error_handler.try(function()
    return M.write_file(file_path, content)
  end)

  if not write_success then
    local err = error_handler.io_error(
      "Failed to write quality report to file",
      {
        file_path = file_path,
        format = format,
        operation = "save_quality_report",
        module = "reporting",
      },
      write_success -- write_success contains the error when success is false
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Successfully saved quality report", {
    file_path = file_path,
    format = format,
  })

  return true
end

-- Save a test results report to file
function M.save_results_report(file_path, results_data, format)
  -- Validate required parameters
  if not file_path then
    local err = error_handler.validation_error("Missing required file_path parameter", {
      operation = "save_results_report",
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if not results_data then
    local err = error_handler.validation_error("Missing required results_data parameter", {
      operation = "save_results_report",
      file_path = file_path,
      module = "reporting",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Set defaults
  format = format or "junit"

  logger.debug("Saving test results report to file", {
    file_path = file_path,
    format = format,
    has_data = true,
  })

  -- Format the results data with error handling
  ---@diagnostic disable-next-line: unused-local
  local format_success, formatted, format_err = error_handler.try(function()
    return M.format_results(results_data, format)
  end)

  if not format_success then
    local err = error_handler.runtime_error(
      "Failed to format test results data",
      {
        file_path = file_path,
        format = format,
        operation = "save_results_report",
        module = "reporting",
      },
      formatted -- formatted contains the error when format_success is false
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Handle both old-style string returns and new-style structured returns
  local content
  if type(formatted) == "table" and formatted.output then
    -- For formatters that return a table with both display output and structured data
    content = formatted.output
  else
    -- For backward compatibility with formatters that return strings directly
    content = formatted
  end

  -- Write to file with error handling
  ---@diagnostic disable-next-line: unused-local
  local write_success, write_err = error_handler.try(function()
    return M.write_file(file_path, content)
  end)

  if not write_success then
    local err = error_handler.io_error(
      "Failed to write test results report to file",
      {
        file_path = file_path,
        format = format,
        operation = "save_results_report",
        module = "reporting",
      },
      write_success -- write_success contains the error when success is false
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Successfully saved test results report", {
    file_path = file_path,
    format = format,
  })

  return true
end

-- Auto-save reports to configured locations
-- Options can be:
-- - string: base directory (backward compatibility)
-- - table: configuration with properties:
--   * report_dir: base directory for reports (default: "./coverage-reports")
--   * report_suffix: suffix to add to all report filenames (optional)
--   * coverage_path_template: path template for coverage reports (optional)
--   * quality_path_template: path template for quality reports (optional)
--   * results_path_template: path template for test results reports (optional)
--   * timestamp_format: format string for timestamps in templates (default: "%Y-%m-%d")
--   * verbose: enable verbose logging (default: false)
--   * validate: whether to validate reports before saving (default: true)
--   * strict_validation: if true, don't save invalid reports (default: false)
--   * validation_report: if true, generate validation report (default: false)
--   * validation_report_path: path for validation report (optional)
function M.auto_save_reports(coverage_data, quality_data, results_data, options)
  -- Handle both string (backward compatibility) and table options
  local config = {}

  if type(options) == "string" then
    config.report_dir = options
  elseif type(options) == "table" then
    config = options
  end

  -- Check central_config for defaults
  local central_config = get_central_config()
  if central_config then
    local reporting_config = central_config.get("reporting")

    if reporting_config then
      -- Use central config as base if available, but allow options to override
      if not config.report_dir and reporting_config.report_dir then
        config.report_dir = reporting_config.report_dir
      end

      if not config.report_suffix and reporting_config.report_suffix then
        config.report_suffix = reporting_config.report_suffix
      end

      if not config.timestamp_format and reporting_config.timestamp_format then
        config.timestamp_format = reporting_config.timestamp_format
      end

      -- Check for path templates in the formats section
      if reporting_config.formats then
        if
          not config.coverage_path_template
          and reporting_config.formats.coverage
          and reporting_config.formats.coverage.path_template
        then
          config.coverage_path_template = reporting_config.formats.coverage.path_template
        end

        if
          not config.quality_path_template
          and reporting_config.formats.quality
          and reporting_config.formats.quality.path_template
        then
          config.quality_path_template = reporting_config.formats.quality.path_template
        end

        if
          not config.results_path_template
          and reporting_config.formats.results
          and reporting_config.formats.results.path_template
        then
          config.results_path_template = reporting_config.formats.results.path_template
        end
      end

      logger.debug("Using centralized configuration for reports", {
        using_central_report_dir = config.report_dir == reporting_config.report_dir,
        using_central_suffix = config.report_suffix == reporting_config.report_suffix,
        using_central_timestamp = config.timestamp_format == reporting_config.timestamp_format,
        using_coverage_template = config.coverage_path_template ~= nil,
        using_quality_template = config.quality_path_template ~= nil,
        using_results_template = config.results_path_template ~= nil,
      })
    end
  end

  -- Set defaults for missing values (after checking central_config)
  config.report_dir = config.report_dir or DEFAULT_CONFIG.report_dir
  config.report_suffix = config.report_suffix or DEFAULT_CONFIG.report_suffix
  config.timestamp_format = config.timestamp_format or DEFAULT_CONFIG.timestamp_format
  config.verbose = config.verbose or false

  local base_dir = config.report_dir
  local results = {}

  -- Helper function for path templates
  local function process_template(template, format, type)
    -- If no template provided, use default filename pattern
    if not template then
      return base_dir .. "/" .. type .. "-report" .. config.report_suffix .. "." .. format
    end

    -- Get current timestamp
    local timestamp = os.date(config.timestamp_format)
    local datetime = os.date("%Y-%m-%d_%H-%M-%S")

    -- Replace placeholders in template
    local path = template
      :gsub("{format}", format)
      :gsub("{type}", type)
      :gsub("{date}", timestamp)
      :gsub("{datetime}", datetime)
      :gsub("{suffix}", config.report_suffix)

    -- If path doesn't start with / or X:\ (absolute), prepend base_dir
    if not path:match("^[/\\]") and not path:match("^%a:[/\\]") then
      path = base_dir .. "/" .. path
    end

    -- If path doesn't have an extension and format is provided, add extension
    if format and not path:match("%.%w+$") then
      path = path .. "." .. format
    end

    return path
  end

  -- Debug output for troubleshooting
  if config.verbose then
    -- Prepare debug data for coverage information
    local coverage_debug = {
      present = coverage_data ~= nil,
    }

    if coverage_data then
      coverage_debug.total_files = coverage_data.summary and coverage_data.summary.total_files or "unknown"
      coverage_debug.total_lines = coverage_data.summary and coverage_data.summary.total_lines or "unknown"

      -- Gather file info for diagnostics
      local tracked_files = {}
      local file_count = 0

      if coverage_data.files then
        for file, _ in pairs(coverage_data.files) do
          file_count = file_count + 1
          if file_count <= 5 then -- Just include first 5 files for brevity
            table.insert(tracked_files, file)
          end
        end
        coverage_debug.file_count = file_count
        coverage_debug.sample_files = tracked_files
      else
        coverage_debug.file_count = 0
        coverage_debug.has_files_table = false
      end
    end

    -- Prepare debug data for quality information
    local quality_debug = {
      present = quality_data ~= nil,
    }

    if quality_data then
      quality_debug.tests_analyzed = quality_data.summary and quality_data.summary.tests_analyzed or "unknown"
      quality_debug.quality_level = quality_data.level or "unknown"
    end

    -- Prepare debug data for test results
    local results_debug = {
      present = results_data ~= nil,
    }

    if results_data then
      results_debug.tests = results_data.tests or "unknown"
      results_debug.failures = results_data.failures or "unknown"
      results_debug.skipped = results_data.skipped or "unknown"
    end

    -- Log the combined debug data
    logger.debug("Auto-saving reports", {
      base_dir = base_dir,
      timestamp_format = config.timestamp_format,
      coverage = coverage_debug,
      quality = quality_debug,
      results = results_debug,
    })
  end

  -- Use filesystem module to ensure directory exists
  logger.debug("Ensuring report directory exists", {
    directory = base_dir,
  })

  -- Validate directory path
  if not base_dir or base_dir == "" then
    logger.error("Failed to create report directory", {
      directory = base_dir,
      error = "Invalid directory path: path cannot be empty",
    })
    
    -- Return empty results but don't fail
    return {}
  end
  
  -- Check for invalid characters in directory path
  if base_dir:match("[*?<>|]") then
    logger.error("Failed to create report directory", {
      directory = base_dir,
      error = "Invalid directory path: contains invalid characters",
    })
    
    -- Return empty results but don't fail
    return {}
  end
  
  -- Create the directory if it doesn't exist
  local dir_ok, dir_err = fs.ensure_directory_exists(base_dir)

  if not dir_ok then
    logger.error("Failed to create report directory", {
      directory = base_dir,
      error = tostring(dir_err),
    })
    
    -- Return empty results table
    return {}
  else
    logger.debug("Report directory ready", {
      directory = base_dir,
      created = not fs.directory_exists(base_dir),
    })
  end

  -- Always save coverage reports in multiple formats if coverage data is provided
  if coverage_data then
    -- Prepare validation options
    local validation_options = {
      validate = config.validate ~= false, -- Default to true
      strict_validation = config.strict_validation or false,
    }

    -- Generate validation report if requested
    if config.validation_report then
      local validation = get_validation_module()
      ---@diagnostic disable-next-line: redundant-parameter
      local validation_result = validation.validate_report(coverage_data)

      -- Save validation report
      if validation_result then
        local validation_path = config.validation_report_path
          or process_template(config.coverage_path_template, "json", "validation")

        -- Convert validation result to JSON
        local validation_json
        if json_module and json_module.encode then
          validation_json = json_module.encode(validation_result)
        else
          validation_json = tostring(validation_result)
        end

        -- Save validation report
        local ok, err = M.write_file(validation_path, validation_json)
        if ok then
          logger.info("Saved validation report", {
            path = validation_path,
            is_valid = validation_result.validation and validation_result.validation.is_valid,
          })

          results["validation"] = {
            success = true,
            path = validation_path,
            is_valid = validation_result.validation and validation_result.validation.is_valid,
          }
        else
          logger.error("Failed to save validation report", {
            path = validation_path,
            error = tostring(err),
          })

          results["validation"] = {
            success = false,
            error = err,
            path = validation_path,
          }
        end
      end
    end

    -- Save reports in multiple formats
    local formats = { "html", "json", "lcov", "cobertura" }

    logger.debug("Saving coverage reports", {
      formats = formats,
      has_template = config.coverage_path_template ~= nil,
      validate = validation_options.validate,
      strict = validation_options.strict_validation,
    })

    for _, format in ipairs(formats) do
      local path = process_template(config.coverage_path_template, format, "coverage")

      logger.debug("Saving coverage report", {
        format = format,
        path = path,
      })

      local ok, err = M.save_coverage_report(path, coverage_data, format, validation_options)
      results[format] = {
        success = ok,
        error = err,
        path = path,
      }

      if ok then
        logger.debug("Successfully saved coverage report", {
          format = format,
          path = path,
        })
      else
        logger.error("Failed to save coverage report", {
          format = format,
          path = path,
          error = tostring(err),
        })
      end
    end
  end

  -- Save quality reports if quality data is provided
  if quality_data then
    -- Save reports in multiple formats
    local formats = { "html", "json" }

    logger.debug("Saving quality reports", {
      formats = formats,
      has_template = config.quality_path_template ~= nil,
    })

    for _, format in ipairs(formats) do
      local path = process_template(config.quality_path_template, format, "quality")

      logger.debug("Saving quality report", {
        format = format,
        path = path,
      })

      local ok, err = M.save_quality_report(path, quality_data, format)
      results["quality_" .. format] = {
        success = ok,
        error = err,
        path = path,
      }

      if ok then
        logger.debug("Successfully saved quality report", {
          format = format,
          path = path,
        })
      else
        logger.error("Failed to save quality report", {
          format = format,
          path = path,
          error = tostring(err),
        })
      end
    end
  end

  -- Save test results in multiple formats if results data is provided
  if results_data then
    -- Test results formats
    local formats = {
      junit = { ext = "xml", name = "JUnit XML" },
      tap = { ext = "tap", name = "TAP" },
      csv = { ext = "csv", name = "CSV" },
    }

    logger.debug("Saving test results reports", {
      formats = { "junit", "tap", "csv" },
      has_template = config.results_path_template ~= nil,
    })

    for format, info in pairs(formats) do
      local path = process_template(config.results_path_template, info.ext, "test-results")

      logger.debug("Saving test results report", {
        format = format,
        name = info.name,
        extension = info.ext,
        path = path,
      })

      local ok, err = M.save_results_report(path, results_data, format)
      results[format] = {
        success = ok,
        error = err,
        path = path,
      }

      if ok then
        logger.debug("Successfully saved test results report", {
          format = format,
          name = info.name,
          path = path,
        })
      else
        logger.error("Failed to save test results report", {
          format = format,
          name = info.name,
          path = path,
          error = tostring(err),
        })
      end
    end
  end

  return results
end

-- Reset the module to default configuration
function M.reset()
  -- Reset local configuration to defaults
  config = {
    debug = DEFAULT_CONFIG.debug,
    verbose = DEFAULT_CONFIG.verbose,
  }

  logger.debug("Reset local configuration to defaults")

  -- Return the module for chaining
  return M
end

-- Fully reset both local and central configuration
function M.full_reset()
  -- Reset local configuration
  M.reset()

  -- Reset central configuration if available
  local central_config = get_central_config()
  if central_config then
    central_config.reset("reporting")
    logger.debug("Reset central configuration for reporting module")
  end

  return M
end

-- Debug helper to show current configuration
function M.debug_config()
  local debug_info = {
    local_config = {
      debug = config.debug,
      verbose = config.verbose,
    },
    using_central_config = false,
    central_config = nil,
  }

  -- Check for central_config
  local central_config = get_central_config()
  if central_config then
    debug_info.using_central_config = true
    debug_info.central_config = central_config.get("reporting")
  end

  -- Display configuration
  logger.info("Reporting module configuration", debug_info)

  return debug_info
end

-- Return the module
return M
