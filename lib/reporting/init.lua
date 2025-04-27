--- Firmo Reporting Module
---
--- Centralized module for generating and saving reports (coverage, quality, test results)
--- in various formats (HTML, JSON, LCOV, Cobertura, JUnit, TAP, CSV, etc.).
---
--- Features:
--- - Unified interface for formatting different data types (`format_coverage`, `format_quality`, `format_results`).
--- - Pluggable formatter system via `lib.reporting.formatters`.
--- - Integration with central configuration for settings (`report_dir`, formatter options).
--- - File saving with error handling (`save_*_report`, `auto_save_reports`).
--- - Data validation hooks via `lib.reporting.validation` and `lib.reporting.schema`.
---
--- @module lib.reporting
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.5.0

---@class reporting The public API of the reporting module.
---@field _VERSION string Module version identifier.
---@field configure fun(options?: {debug?: boolean, verbose?: boolean, report_dir?: string, report_suffix?: string, timestamp_format?: string, formats?: table, formatters?: table}): reporting Configures the reporting module. Returns self.
---@field get_config fun(): table<string, any> Gets the current merged configuration (defaults + central config).
---@field register_formatter fun(format: string, formatter: table): reporting [Deprecated] Use specific registration functions.
---@field register_coverage_formatter fun(name: string, formatter_fn: function): boolean|nil, table? Registers a custom formatter for coverage reports. Returns `success, error?`.
---@field register_quality_formatter fun(name: string, formatter_fn: function): boolean|nil, table? Registers a custom formatter for quality reports. Returns `success, error?`.
---@field register_results_formatter fun(name: string, formatter_fn: function): boolean|nil, table? Registers a custom formatter for test results. Returns `success, error?`.
---@field get_formatter fun(format: string, type: string): table|nil Gets a registered formatter function. Type is "coverage", "quality", or "results".
---@field get_formatter_config fun(formatter_name: string): table|nil Gets configuration for a specific formatter.
---@field configure_formatter fun(formatter_name: string, formatter_config: table): reporting Configures a specific formatter. Returns self.
---@field configure_formatters fun(formatters_config: table): reporting Configures multiple formatters. Returns self.
---@field load_formatters fun(formatter_module: table): number|nil, table? Loads and registers formatters from a module table. Returns `count, error?`.
---@field get_available_formatters fun(): {coverage: string[], quality: string[], results: string[]} Gets lists of available registered formatter names.
---@field generate_report fun(...) [Not Implemented] Generate a report.
---@field get_report_path fun(...) [Not Implemented] Get the path for a report file.
---@field load_formatter fun(...) [Not Implemented] Load a formatter module with lazy loading.
---@field run_formatter fun(...) [Not Implemented] Generate report output with a formatter.
---@field format_coverage fun(coverage_data: table, format?: string, options?: table): string|table|nil Formats coverage data. Returns formatted output or nil. @throws table If formatter fails critically.
---@field format_quality fun(quality_data: table, format?: string, options?: table): string|table|nil Formats quality data. Returns formatted output or nil. @throws table If formatter fails critically.
---@field format_results fun(results_data: table, format?: string, options?: table): string|table|nil Formats test results data. Returns formatted output or nil. @throws table If formatter fails critically.
---@field save_coverage_report fun(file_path: string, coverage_data: table, format: string, options?: table): boolean|nil, table? Saves a coverage report. Returns `success, error?`. @throws table If formatting or writing fails critically.
---@field save_quality_report fun(file_path: string, quality_data: table, format: string, options?: table): boolean|nil, table? Saves a quality report. Returns `success, error?`. @throws table If formatting or writing fails critically.
---@field save_results_report fun(file_path: string, results_data: table, format: string, options?: table): boolean|nil, table? Saves a test results report. Returns `success, error?`. @throws table If formatting or writing fails critically.
---@field auto_save_reports fun(coverage_data: table|nil, quality_data: table|nil, results_data: table|nil, options?: table|string): table<string, {success: boolean, error?: table, path: string}> Generates and saves multiple reports based on configuration. Returns a table summarizing results. @throws table If directory creation fails critically.
---@field validate_coverage_data fun(coverage_data: table): boolean, table? Validates coverage data structure via `lib.reporting.validation`. Returns `valid, issues?`. @throws table If validation module fails critically.
---@field validate_report_format fun(formatted_data: string|table, format: string): boolean, string? Validates formatted report string/table via `lib.reporting.schema`. Returns `valid, error_message?`. @throws table If schema module fails critically.
---@field validate_report fun(coverage_data: table, formatted_output?: string|table, format?: string): table Runs comprehensive validation via `lib.reporting.validation`. Returns validation result table. @throws table If validation module fails critically.
---@field validate_formatter_config fun(...) [Not Implemented] Validate formatter configuration.
---@field write_file fun(file_path: string, content: string|table): boolean|nil, table? Writes content to a file (handles JSON encoding for tables). Returns `success, error?`. @throws table If encoding or writing fails critically.
---@field reset fun(): reporting Resets local configuration to defaults. Returns self.
---@field full_reset fun(): reporting Resets local and central configuration. Returns self.
---@field debug_config fun(): table Gets current configuration snapshot for debugging.

local M = {}

-- Module version
M._VERSION = "0.5.0"

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
    return logging.get_logger("Reporting")
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

-- Load mandatory dependencies using standard pattern
local central_config = try_require("lib.core.central_config")
local json_module = try_require("lib.tools.json")
local formatter_registry = try_require("lib.reporting.formatters.init")
local validation_module = try_require("lib.reporting.validation")

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
      template_path = nil, -- Custom template path
      stylesheet_path = nil, -- Custom stylesheet path
      enable_dark_mode = true, -- Support dark mode toggle
      inline_source = true, -- Include source code inline
      line_number_anchors = true, -- Enable line number anchors
    },
    summary = {
      detailed = false,
      show_files = true,
      colorize = true,
      show_function_coverage = true, -- Show function coverage
      sort_by = "coverage", -- Sort by coverage percentage
      max_files = 100, -- Maximum files to show in summary
    },
    json = {
      pretty = false,
      schema_version = "1.0",
      indentation = 2, -- Indentation level when pretty-printing
      enable_streaming = true, -- Enable streaming for large files
      chunk_size = 1024 * 1024, -- 1MB chunks for streaming
      omit_source_code = false, -- Whether to include source code
    },
    lcov = {
      absolute_paths = false,
      include_function_coverage = true, -- Include function coverage data
      include_branch_coverage = false, -- Include branch coverage data
      normalize_paths = true, -- Normalize paths for cross-platform compatibility
    },
    cobertura = {
      schema_version = "4.0",
      include_packages = true,
      include_source = true, -- Include source in report
      include_methods = true, -- Include methods in report
      include_conditions = false, -- Include conditions in report
    },
    junit = {
      schema_version = "2.0",
      include_timestamps = true,
      include_hostname = true,
      include_properties = true, -- Include properties in report
      format_stack_traces = true, -- Format stack traces for readability
      use_cdata = true, -- Use CDATA sections for message content
    },
    tap = {
      version = 13,
      verbose = true,
      include_yaml_diagnostics = true, -- Include YAML diagnostics
      include_summary = true, -- Include summary comments
      include_stack_traces = true, -- Include stack traces in diagnostics
      include_uncovered_list = false, -- List uncovered items
    },
    csv = {
      delimiter = ",",
      quote = '"',
      include_header = true,
      columns = nil, -- Custom columns specification
      escape_special_chars = true, -- Properly escape special characters
      include_line_data = false, -- Include per-line data
    },
  },
  lazy_loading = {
    enabled = true, -- Enable lazy loading of formatters
    formatters_path = "lib.reporting.formatters", -- Base path for formatters
    load_on_demand = true, -- Load formatters only when needed
  },
  validation = {
    validate_config = true, -- Validate formatter configurations
    validate_data = true, -- Validate data before formatting
    validate_output = true, -- Validate output after formatting
    strict = false, -- Whether to fail on validation errors
  },
}

-- Current configuration (will be synchronized with central config)
local config = {
  debug = DEFAULT_CONFIG.debug,
  verbose = DEFAULT_CONFIG.verbose,
}

-- Register central_config immediately after loading it (now done at top level)
central_config.register_module("reporting", {
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
central_config.register_module("reporting.formatters", {
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
get_logger().debug("Successfully loaded and registered with central_config", { module = "reporting" })

--- Helper function to escape XML special characters for use in XML output formats
---@param str string|any String to escape, or any value to convert to string and then escape.
---@return string escaped_string String with XML special characters (`&`, `<`, `>`, `"`, `'`) escaped.
---@private
local function escape_xml(str)
  if type(str) ~= "string" then
    return tostring(str or "")
  end

  return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
end

--- Registers a listener with central_config to update local config cache when reporting settings change.
---@return boolean success `true` if the listener was registered, `false` otherwise.
---@private
local function register_change_listener()
  -- central_config is loaded at top level and guaranteed to exist
  if not central_config then
    -- This block should ideally not be reached if loading is enforced
    get_logger().error("Cannot register change listener - central_config unexpectedly nil")
    return false
  end

  -- Register change listener for reporting configuration
  ---@diagnostic disable-next-line: unused-local
  central_config.on_change("reporting", function(path, old_value, new_value)
    get_logger().debug("Configuration change detected", {
      path = path,
      changed_by = "central_config",
    })

    -- Update local configuration from central_config
    local reporting_config = central_config.get("reporting")
    if reporting_config then
      -- Update debug and verbose settings directly
      if reporting_config.debug ~= nil and reporting_config.debug ~= config.debug then
        config.debug = reporting_config.debug
        get_logger().debug("Updated debug setting from central_config", {
          debug = config.debug,
        })
      end

      if reporting_config.verbose ~= nil and reporting_config.verbose ~= config.verbose then
        config.verbose = reporting_config.verbose
        get_logger().debug("Updated verbose setting from central_config", {
          verbose = config.verbose,
        })
      end

      -- Update logging configuration
      logging.configure_from_options("Reporting", {
        debug = config.debug,
        verbose = config.verbose,
      })

      get_logger().debug("Applied configuration changes from central_config")
    end
  end)

  get_logger().debug("Registered change listener for central configuration")
  return true
end

--- Configures the reporting module.
--- Merges provided `options` with defaults and central configuration.
--- Updates local config cache and potentially updates central config if options are provided.
--- Configures the logger based on the final debug/verbose settings.
---@param options? {debug?: boolean, verbose?: boolean, report_dir?: string, report_suffix?: string, timestamp_format?: string, formats?: table, formatters?: table} Configuration options table.
---@return reporting The reporting module instance (`M`) for method chaining.
---@throws table If central config interaction fails critically during loading or setting values.
function M.configure(options)
  options = options or {}

  get_logger().debug("Configuring reporting module", {
    debug = options.debug,
    verbose = options.verbose,
    has_options = options ~= nil,
  })

  -- Check for central configuration first
  -- central_config is loaded at top level and guaranteed to exist
  if central_config then
    -- Get existing central config values
    local reporting_config = central_config.get("reporting")

    -- Apply central configuration (with defaults as fallback)
    if reporting_config then
      get_logger().debug("Using central_config values for initialization", {
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
      get_logger().debug("No central_config values found, using defaults")
      config.debug = DEFAULT_CONFIG.debug
      config.verbose = DEFAULT_CONFIG.verbose
    end

    -- Register change listener if not already done
    register_change_listener()
  else
    get_logger().debug("central_config not available, using defaults")
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
    get_logger().debug("Using provided options for logging configuration")
    get_logging().configure_from_options("Reporting", options)
  else
    -- Otherwise use global config
    get_logger().debug("Using global config for logging configuration")
  end

  get_logger().debug("Reporting module configuration complete", {
    debug = config.debug,
    verbose = config.verbose,
    using_central_config = central_config ~= nil,
  })

  -- Return the module for chaining
  return M
end

--- Gets the configuration for a specific formatter by name.
--- Looks in central configuration first, then local configuration, then defaults.
---@param formatter_name string The name of the formatter (e.g., "html", "json").
---@return table formatter_config A table containing the formatter's configuration options. Returns an empty table if no specific config is found.
---@throws table If central config interaction fails critically.
function M.get_formatter_config(formatter_name)
  if not formatter_name then
    get_logger().warn("Formatter name required for get_formatter_config")
    return nil
  end

  -- Try to get from central_config
  -- central_config is loaded at top level and guaranteed to exist
  if central_config then
    local formatter_config = central_config.get("reporting.formatters." .. formatter_name)
    if formatter_config then
      get_logger().debug("Retrieved formatter config from central_config", {
        formatter = formatter_name,
      })
      return formatter_config
    end
  end

  -- Fall back to local config
  if config.formatters and config.formatters[formatter_name] then
    get_logger().debug("Retrieved formatter config from local config", {
      formatter = formatter_name,
    })
    return config.formatters[formatter_name]
  end

  -- Return default config if available
  if DEFAULT_CONFIG.formatters and DEFAULT_CONFIG.formatters[formatter_name] then
    get_logger().debug("Using default formatter config", {
      formatter = formatter_name,
    })
    return DEFAULT_CONFIG.formatters[formatter_name]
  end

  get_logger().warn("No configuration found for formatter", {
    formatter = formatter_name,
  })
  return {}
end

--- Configures options for a specific formatter by name.
--- Updates both the local config cache and the central configuration (if available).
---@param formatter_name string Name of the formatter to configure (e.g., "html").
---@param formatter_config table Table of configuration options for the formatter.
---@return reporting The reporting module instance (`M`) for method chaining.
---@throws table If central config interaction fails critically during setting values.
function M.configure_formatter(formatter_name, formatter_config)
  if not formatter_name then
    get_logger().error("Formatter name required for configure_formatter")
    return M
  end

  if type(formatter_config) ~= "table" then
    get_logger().error("Invalid formatter configuration", {
      formatter = formatter_name,
      config_type = type(formatter_config),
    })
    return M
  end

  -- Update central_config if available
  -- central_config is loaded at top level and guaranteed to exist
  if central_config then
    central_config.set("reporting.formatters." .. formatter_name, formatter_config)
  end

  -- Update local config
  config.formatters = config.formatters or {}
  config.formatters[formatter_name] = config.formatters[formatter_name] or {}

  for k, v in pairs(formatter_config) do
    config.formatters[formatter_name][k] = v
  end

  get_logger().debug("Updated configuration for formatter", {
    formatter = formatter_name,
    config_count = #formatter_config,
  })

  return M
end

--- Configures multiple formatters at once by iterating through a table.
--- Calls `M.configure_formatter` for each entry.
---@param formatters_config table A table where keys are formatter names and values are their configuration tables. Example: `{ html = { theme = "light" }, json = { pretty = true } }`.
---@return reporting The reporting module instance (`M`) for method chaining.
---@throws table If `formatters_config` is not a table, or if central config interaction fails critically during `configure_formatter`.
function M.configure_formatters(formatters_config)
  if type(formatters_config) ~= "table" then
    get_logger().error("Invalid formatters configuration", {
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

--- Schema definition (interface) for Coverage Report Data.
--- Modules providing coverage data (like `lib.coverage`) should return data conforming to this structure.
--- Actual schema validation might occur in `lib.reporting.validation` or `lib.reporting.schema`.
-- M.CoverageData = {
-- Example structure:
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
-- }

--- Schema definition (interface) for Quality Report Data.
--- Modules providing quality data (like `lib.quality`) should return data conforming to this structure.
--- Actual schema validation might occur elsewhere.
-- M.QualityData = {
-- Example structure:
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
-- }

--- Schema definition (interface) for Test Results Data (often used for JUnit/TAP).
--- Modules providing test results (like `lib.core.test_definition`) should structure their results like this.
--- Actual schema validation might occur elsewhere.
-- M.TestResultsData = {
-- Example structure:
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
-- }

---------------------------
-- REPORT FORMATTERS
---------------------------

-- Formatter registries for built-in and custom formatters
local formatters = {
  coverage = {}, -- Coverage report formatters
  quality = {}, -- Quality report formatters
  results = {}, -- Test results formatters
}

--- Loads the formatter registry (`lib.reporting.formatters.init`) and calls its `register_all`
--- function to populate the internal `formatters` table. Handles errors during loading or registration.
---@return boolean `true` if registry loaded and at least some formatters registered, `false` otherwise.
---@private
local function load_formatter_registry()
  get_logger().debug("Loading formatter registry")
  -- formatter_registry is loaded at top level and guaranteed to exist

  if formatter_registry then
    get_logger().debug("Using loaded formatter registry")

    -- Register formatters with error handling
    local register_success, register_result, register_err = get_error_handler().try(function()
      return formatter_registry.register_all(formatters) -- Use loaded module
    end)

    if register_success then
      get_logger().debug("Successfully registered all formatters", {
        coverage_count = formatters.coverage and #formatters.coverage or 0,
        quality_count = formatters.quality and #formatters.quality or 0,
        results_count = formatters.results and #formatters.results or 0,
      })
      return true
    else
      get_logger().warn("Failed to register formatters", {
        error = get_error_handler().format_error(register_result),
        module = "reporting",
      })
      return false -- Registration failed
    end

    -- This case should not be reachable due to fatal error on load failure
    get_logger().error("Formatter registry module was unexpectedly nil")
    return false
  end
  get_logger().warn("Failed to load formatter registry", {
    error = get_error_handler().format_error(result),
    module = "reporting",
  })
end -- <<<< This is the end of load_formatter_registry

-- Attempt to load formatter registry
load_formatter_registry() -- Call directly; fatal errors handled during require at top

-- Local references to formatter registries
---@diagnostic disable-next-line: unused-local
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

---@param name string Name of the formatter to register (e.g., "my_coverage_format").
---@param formatter_fn function The formatter function `(coverage_data, options) -> string|table`.
---@return boolean|nil success `true` if registered successfully, `nil` if validation or registration failed.
---@return table|nil error Error object if registration failed.
---@throws table If registration fails critically within `error_handler.try`.
function M.register_coverage_formatter(name, formatter_fn)
  -- Validate name parameter
  if type(name) ~= "string" then
    local err = get_error_handler().validation_error("Failed to register coverage formatter: name must be a string", {
      name_type = type(name),
      operation = "register_coverage_formatter",
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Validate formatter_fn parameter
  if type(formatter_fn) ~= "function" then
    local err =
      get_error_handler().validation_error("Failed to register coverage formatter: formatter must be a function", {
        formatter_name = name,
        formatter_type = type(formatter_fn),
        operation = "register_coverage_formatter",
        module = "reporting",
      })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Register the formatter using get_error_handler()try
  local success, result = get_error_handler().try(function()
    formatters.coverage[name] = formatter_fn
    return true
  end)

  if not success then
    local err = get_error_handler().runtime_error(
      "Failed to register coverage formatter: registration error",
      {
        formatter_name = name,
        operation = "register_coverage_formatter",
        module = "reporting",
      },
      result -- result contains the error when success is false
    )
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Registered custom coverage formatter", {
    formatter_name = name,
  })

  return true
end

---@param name string Name of the formatter to register (e.g., "my_quality_format").
---@param formatter_fn function The formatter function `(quality_data, options) -> string|table`.
---@return boolean|nil success `true` if registered successfully, `nil` if validation or registration failed.
---@return table|nil error Error object if registration failed.
---@throws table If registration fails critically within `error_handler.try`.
function M.register_quality_formatter(name, formatter_fn)
  -- Validate name parameter
  if type(name) ~= "string" then
    local err = get_error_handler().validation_error("Failed to register quality formatter: name must be a string", {
      name_type = type(name),
      operation = "register_quality_formatter",
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Validate formatter_fn parameter
  if type(formatter_fn) ~= "function" then
    local err =
      get_error_handler().validation_error("Failed to register quality formatter: formatter must be a function", {
        formatter_name = name,
        formatter_type = type(formatter_fn),
        operation = "register_quality_formatter",
        module = "reporting",
      })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Register the formatter using get_error_handler().try
  local success, result = get_error_handler().try(function()
    formatters.quality[name] = formatter_fn
    return true
  end)

  if not success then
    local err = get_error_handler().runtime_error(
      "Failed to register quality formatter: registration error",
      {
        formatter_name = name,
        operation = "register_quality_formatter",
        module = "reporting",
      },
      result -- result contains the error when success is false
    )
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Registered custom quality formatter", {
    formatter_name = name,
  })

  return true
end

---@param name string Name of the formatter to register (e.g., "my_results_format").
---@param formatter_fn function The formatter function `(results_data, options) -> string|table`.
---@return boolean|nil success `true` if registered successfully, `nil` if validation or registration failed.
---@return table|nil error Error object if registration failed.
---@throws table If registration fails critically within `error_handler.try`.
function M.register_results_formatter(name, formatter_fn)
  -- Validate name parameter
  if type(name) ~= "string" then
    local err = get_error_handler().validation_error("Failed to register results formatter: name must be a string", {
      name_type = type(name),
      operation = "register_results_formatter",
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Validate formatter_fn parameter
  if type(formatter_fn) ~= "function" then
    local err =
      get_error_handler().validation_error("Failed to register results formatter: formatter must be a function", {
        formatter_name = name,
        formatter_type = type(formatter_fn),
        operation = "register_results_formatter",
        module = "reporting",
      })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Register the formatter using get_error_handler()try
  local success, result = get_error_handler().try(function()
    formatters.results[name] = formatter_fn
    return true
  end)

  if not success then
    local err = get_error_handler().runtime_error(
      "Failed to register results formatter: registration error",
      {
        formatter_name = name,
        operation = "register_results_formatter",
        module = "reporting",
      },
      result -- result contains the error when success is false
    )
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Registered custom results formatter", {
    formatter_name = name,
  })

  return true
end

---@param formatter_module table A module-like table containing formatter functions keyed by type (e.g., `{ coverage = { my_format = fn }, quality = { ... } }`) or a `.register(formatters)` method.
---@return number|nil registered The number of formatters successfully registered, or `nil` if `formatter_module` validation failed.
---@return table|nil error An error object if some formatters failed to register. Contains details in `error.context.failed_formatters`.
---@throws table If validation or registration fails critically.
function M.load_formatters(formatter_module)
  -- Validate formatter_module parameter
  if type(formatter_module) ~= "table" then
    local err = get_error_handler().validation_error("Failed to load formatters: module must be a table", {
      module_type = type(formatter_module),
      operation = "load_formatters",
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Loading formatters from module", {
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
        local success, err = get_error_handler().try(function()
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
          get_logger().warn("Failed to register coverage formatter", {
            formatter_name = name,
            error = get_error_handler().format_error(err),
          })
        end
      end
    end

    if #coverage_formatters > 0 then
      get_logger().debug("Registered coverage formatters", {
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
        local success, err = get_error_handler().try(function()
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
          get_logger().warn("Failed to register quality formatter", {
            formatter_name = name,
            error = get_error_handler().format_error(err),
          })
        end
      end
    end

    if #quality_formatters > 0 then
      get_logger().debug("Registered quality formatters", {
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
        local success, err = get_error_handler().try(function()
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
          get_logger().warn("Failed to register results formatter", {
            formatter_name = name,
            error = get_error_handler().format_error(err),
          })
        end
      end
    end

    if #results_formatters > 0 then
      get_logger().debug("Registered results formatters", {
        count = #results_formatters,
        formatters = results_formatters,
      })
    end
  end

  get_logger().debug("Completed formatter registration", {
    total_registered = registered,
    error_count = #registration_errors,
  })

  -- If we have errors but still registered some formatters, return partial success
  if #registration_errors > 0 then
    local err = get_error_handler().runtime_error("Some formatters failed to register", {
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

--- Gets a table containing lists of names for all currently registered formatters, categorized by type.
---@return {coverage: string[], quality: string[], results: string[]} available_formatters A table where keys are report types ("coverage", "quality", "results") and values are sorted arrays of registered formatter names for that type.
function M.get_available_formatters()
  get_logger().debug("Getting available formatters")

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

  get_logger().debug("Available formatters", {
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

--- Gets the default format string for a given report type ("coverage", "quality", "results") from configuration.
---@param type string The report type.
---@return string format The default format name (e.g., "html", "junit"). Falls back to hardcoded defaults if not configured.
---@private
local function get_default_format(type)
  -- Check central_config first
  -- central_config is loaded at top level and guaranteed to exist
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

--- Formats coverage data using the specified formatter.
---@param coverage_data table The coverage data (conforming to `M.CoverageData` structure).
---@param format? string The name of the formatter to use (e.g., "html", "lcov"). Defaults to the configured default for "coverage".
---@return string|table|nil formatted_output The formatted report (string or table), or `nil` if the formatter is not found or fails.
---@throws table If the specified formatter fails critically during execution (errors wrapped by `pcall` are handled gracefully).
function M.format_coverage(coverage_data, format)
  -- If no format specified, use default from config
  format = format or get_default_format("coverage")

  get_logger().debug("Formatting coverage data", {
    format = format,
    has_data = coverage_data ~= nil,
    formatter_available = formatters.coverage[format] ~= nil,
    from_config = format == get_default_format("coverage"),
  })

  -- Use the appropriate formatter
  if formatters.coverage[format] then
    get_logger().trace("Using requested formatter", { format = format })
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
    get_logger().warn("Requested formatter not available, falling back to default", {
      requested_format = format,
      default_format = default_format,
    })
    -- Default to summary formatter explicitly
    get_logger().debug("Using summary formatter as fallback for invalid format")
    local result = formatters.coverage.summary(coverage_data)

    -- Handle both old-style string returns and new-style structured returns
    if type(result) == "table" and result.output then
      return result
    else
      return result
    end
  end
end

--- Formats quality data using the specified formatter.
---@param quality_data table The quality data (conforming to `M.QualityData` structure).
---@param format? string The name of the formatter to use (e.g., "summary", "json"). Defaults to the configured default for "quality".
---@return string|table|nil formatted_output The formatted report (string or table), or `nil` if the formatter is not found or fails.
---@throws table If the specified formatter fails critically during execution (errors wrapped by `pcall` are handled gracefully).
function M.format_quality(quality_data, format)
  -- If no format specified, use default from config
  format = format or get_default_format("quality")

  get_logger().debug("Formatting quality data", {
    format = format,
    has_data = quality_data ~= nil,
    formatter_available = formatters.quality[format] ~= nil,
    from_config = format == get_default_format("quality"),
  })

  -- Use the appropriate formatter
  if formatters.quality[format] then
    get_logger().trace("Using requested formatter", { format = format })
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
    get_logger().warn("Requested formatter not available, falling back to default", {
      requested_format = format,
      default_format = default_format,
    })
    -- Default to summary formatter explicitly
    get_logger().debug("Using summary formatter as fallback for invalid format")
    local result = formatters.quality.summary(quality_data)

    -- Handle both old-style string returns and new-style structured returns
    if type(result) == "table" and result.output then
      return result
    else
      return result
    end
  end
end

--- Formats test results data using the specified formatter.
---@param results_data table The test results data (conforming to `M.TestResultsData` structure).
---@param format? string The name of the formatter to use (e.g., "junit", "tap"). Defaults to the configured default for "results".
---@return string|table|nil formatted_output The formatted report (string or table), or `nil` if the formatter is not found or fails.
---@throws table If the specified formatter fails critically during execution (errors wrapped by `pcall` are handled gracefully).
function M.format_results(results_data, format)
  -- If no format specified, use default from config
  format = format or get_default_format("results")

  get_logger().debug("Formatting test results data", {
    format = format,
    has_data = results_data ~= nil,
    formatter_available = formatters.results[format] ~= nil,
    from_config = format == get_default_format("results"),
  })

  -- Use the appropriate formatter
  if formatters.results[format] then
    get_logger().trace("Using requested formatter", { format = format })
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
    get_logger().warn("Requested formatter not available, falling back to default", {
      requested_format = format,
      default_format = default_format,
    })
    -- Default to junit formatter explicitly
    get_logger().debug("Using junit formatter as fallback for invalid format")
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

--- Writes content (string or table automatically JSON encoded) to a specified file path.
--- Ensures parent directories exist. Uses `filesystem.write_file`.
---@param file_path string The absolute or relative path to the output file.
---@param content string|table The content to write. If a table, it's encoded as JSON.
---@return boolean|nil success `true` if writing succeeded, `nil` otherwise.
---@return table|nil error Error object if validation, encoding, or writing failed.
---@throws table If encoding or writing fails critically within `error_handler.try` or `safe_io_operation`.
function M.write_file(file_path, content)
  -- Input validation using error_handler
  if not file_path then
    local err = get_error_handler().validation_error("Missing required file_path parameter", {
      operation = "write_file",
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if not content then
    local err = get_error_handler().validation_error("Missing required content parameter", {
      operation = "write_file",
      file_path = file_path,
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Writing file", {
    file_path = file_path,
    content_length = content and #content or 0,
  })

  -- Make sure content is a string, with error handling
  local content_str
  ---@diagnostic disable-next-line: unused-local
  local success, result, err

  if type(content) == "table" then
    ---@diagnostic disable-next-line: unused-local
    success, result, err = get_error_handler().try(function()
      return json_module.encode(content)
    end)

    if not success then
      local error_obj = get_error_handler().io_error(
        "Failed to encode table as JSON",
        {
          file_path = file_path,
          module = "reporting",
          table_size = #content,
        },
        result -- The error object is in result when success is false
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    content_str = result
    get_logger().trace("Converted table to JSON string", {
      file_path = file_path,
      content_length = content_str and #content_str or 0,
    })
  else
    -- If not a table, convert to string directly
    ---@diagnostic disable-next-line: unused-local
    success, result, err = get_error_handler().try(function()
      return tostring(content)
    end)

    if not success then
      local error_obj = get_error_handler().io_error(
        "Failed to convert content to string",
        {
          file_path = file_path,
          module = "reporting",
          content_type = type(content),
        },
        result -- The error object is in result when success is false
      )
      get_logger().error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    content_str = result
    get_logger().trace("Converted content to string", {
      file_path = file_path,
      content_type = type(content),
      content_length = content_str and #content_str or 0,
    })
  end

  -- Use the filesystem module to write the file with proper error handling
  local write_success, write_err = get_error_handler().safe_io_operation(
    function()
      return get_fs().write_file(file_path, content_str)
    end,
    file_path,
    {
      operation = "write_file",
      module = "reporting",
      content_length = content_str and #content_str or 0,
    }
  )

  if not write_success then
    get_logger().error("Error writing to file", {
      file_path = file_path,
      error = get_error_handler().format_error(write_err),
    })
    return nil, write_err
  end

  get_logger().debug("Successfully wrote file", {
    file_path = file_path,
    content_length = content_str and #content_str or 0,
  })
  return true
end

-- Load validation module (lazy loading with fallback)
local _validation_module
local function get_validation_module()
  if not _validation_module then
    -- Use get_error_handler()try for better error handling and context
    local success, validation = get_error_handler().try(function()
      return require("lib.reporting.validation")
    end)

    if success then
      _validation_module = validation
      get_logger().debug("Successfully loaded validation module")
    else
      get_logger().debug("Failed to load validation module", {
        error = get_error_handler().format_error(validation),
        operation = "get_validation_module",
        module = "reporting",
      })

      -- Create dummy validation module with structured error handling
      _validation_module = {
        validate_coverage_data = function()
          -- Return dummy validation result (valid with no issues)
          get_logger().warn("Using dummy validation module", {
            operation = "validate_coverage_data",
            module = "reporting",
          })
          return true, {}
        end,

        validate_report = function()
          -- Return dummy report validation (valid with no issues)
          get_logger().warn("Using dummy validation module", {
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

--- Validates the structure and consistency of coverage data using `lib.reporting.validation`.
---@param coverage_data table The coverage data (conforming to `M.CoverageData`).
---@return boolean is_valid `true` if the data is valid according to the validation module.
---@return table? issues A list of validation issue tables if `is_valid` is false.
---@throws table If validation fails critically.
function M.validate_coverage_data(coverage_data)
  -- validation_module is loaded at top level and guaranteed to exist
  get_logger().debug("Validating coverage data", {
    has_data = coverage_data ~= nil,
    has_summary = coverage_data and coverage_data.summary ~= nil,
    has_files = coverage_data and coverage_data.files ~= nil,
  })

  -- Run validation
  ---@diagnostic disable-next-line: redundant-parameter
  local is_valid, issues = validation_module.validate_coverage_data(coverage_data)

  get_logger().info("Coverage data validation results", {
    issue_count = issues and #issues or 0,
  })

  return is_valid, issues
end

--- Validates if the formatted report data (string or table) conforms to the expected schema/structure for the given format name.
--- Uses `lib.reporting.schema` (or a fallback if unavailable).
---@param formatted_data string|table The formatted report content.
---@param format string The name of the format (e.g., "json", "lcov").
---@return boolean success `true` if the format is valid or validation is skipped.
---@return string? error_message An error message if validation failed.
---@throws table If validation fails critically.
function M.validate_report_format(formatted_data, format)
  -- validation_module is loaded at top level and guaranteed to exist
  get_logger().debug("Validating report format", {
    format = format,
    has_data = formatted_data ~= nil,
    data_type = type(formatted_data),
  })

  -- Run validation
  local is_valid, error_message = validation_module.validate_report_format(formatted_data, format)

  get_logger().info("Format validation results", {
    is_valid = is_valid,
    format = format,
    error = error_message or "none",
  })

  return is_valid, error_message
end

--- Performs comprehensive validation on coverage data and optionally the formatted output.
--- Includes schema checks, statistical analysis, and cross-checking via `lib.reporting.validation`.
---@param coverage_data table The coverage data (conforming to `M.CoverageData`).
---@param formatted_output? string|table Optional formatted report content to validate.
---@param format? string Optional format name corresponding to `formatted_output`.
---@return table validation_result A table containing detailed validation results (structure defined by `lib.reporting.validation.validate_report`).
---@throws table If validation fails critically.
function M.validate_report(coverage_data, formatted_output, format)
  -- validation_module is loaded at top level and guaranteed to exist
  get_logger().debug("Running comprehensive report validation", {
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
  local result = validation_module.validate_report(coverage_data, options)

  get_logger().info("Comprehensive validation results", {
    is_valid = result.validation.is_valid,
    issues = result.validation.issues and #result.validation.issues or 0,
    format_valid = result.format_validation and result.format_validation.is_valid,
    outliers = result.statistics and result.statistics.outliers and #result.statistics.outliers or 0,
    anomalies = result.statistics and result.statistics.anomalies and #result.statistics.anomalies or 0,
    cross_check_files = result.cross_check and result.cross_check.files_checked or 0,
  })

  return result
end

--- Formats and saves a coverage report to a file.
--- Optionally validates data and format before saving based on `options`.
---@param file_path string Path to save the report file.
---@param coverage_data table Raw coverage data.
---@param format string The desired output format (e.g., "html", "lcov").
---@param options? {validate?: boolean, strict_validation?: boolean, validate_format?: boolean} Optional saving/validation flags.
---@return boolean|nil success `true` if formatting and saving succeeded, `nil` otherwise.
---@return table|nil error Error object if formatting, validation, or saving failed.
---@throws table If formatting or writing fails critically.
function M.save_coverage_report(file_path, coverage_data, format, options)
  -- Validate required parameters
  if not file_path then
    local err = get_error_handler().validation_error("Missing required file_path parameter", {
      operation = "save_coverage_report",
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if not coverage_data then
    local err = get_error_handler().validation_error("Missing required coverage_data parameter", {
      operation = "save_coverage_report",
      file_path = file_path,
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Set defaults
  format = format or "html"
  options = options or {}

  get_logger().debug("Saving coverage report to file", {
    file_path = file_path,
    format = format,
    has_data = true,
    validate = options.validate ~= false, -- Default to validate=true
  })

  -- CRITICAL FIX: Check for minimal valid data structure before proceeding
  if not coverage_data.files or not coverage_data.summary then
    local err = get_error_handler().validation_error("Invalid coverage data structure: missing required fields", {
      file_path = file_path,
      format = format,
      operation = "save_coverage_report",
      module = "reporting",
      missing_files = coverage_data.files == nil,
      missing_summary = coverage_data.summary == nil,
    })
    get_logger().error(err.message, err.context)
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
    local err = get_error_handler().validation_error("Invalid coverage data: no files found in coverage data", {
      file_path = file_path,
      format = format,
      operation = "save_coverage_report",
      module = "reporting",
      file_count = file_count,
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Log file count for debugging
  get_logger().debug("Coverage file count validation", {
    file_count = file_count,
    files_valid = file_count > 0,
  })

  -- Validate coverage data before saving if not disabled
  if options.validate ~= false then
    -- Safely get the validation module using get_error_handler()try
    local success, validation_module = get_error_handler().try(function()
      return get_validation_module()
    end)

    if success and validation_module and validation_module.validate_coverage_data then
      -- Validate the coverage data with error handling
      local validation_success, is_valid, issues = get_error_handler().try(function()
        return validation_module.validate_coverage_data(coverage_data)
      end)

      if validation_success then
        if issues and #issues > 0 and not is_valid then
          get_logger().warn("Validation issues detected in coverage data", {
            issue_count = #issues,
            first_issue = issues[1] and issues[1].message or "Unknown issue",
          })

          -- If validation is strict, don't save invalid data
          if options.strict_validation then
            local validation_err =
              get_error_handler().validation_error("Not saving report due to validation failures (strict mode)", {
                file_path = file_path,
                format = format,
                operation = "save_coverage_report",
                module = "reporting",
                issue_count = #issues,
                first_issue = issues[1] and issues[1].message or "Unknown issue",
              })
            get_logger().error(validation_err.message, validation_err.context)
            return nil, validation_err
          end

          -- Otherwise just warn but continue
          get_logger().warn("Saving report despite validation issues (non-strict mode)")
        end
      else
        -- Validation failed with an error
        local validation_err = get_error_handler().runtime_error(
          "Error during coverage data validation",
          {
            file_path = file_path,
            format = format,
            operation = "save_coverage_report",
            module = "reporting",
          },
          is_valid -- is_valid contains the error when validation_success is false
        )
        get_logger().warn(validation_err.message, validation_err.context)

        -- If validation is strict, don't save on validation error
        if options.strict_validation then
          return nil, validation_err
        end

        -- Otherwise, continue despite validation error
        get_logger().warn("Continuing with report generation despite validation error (non-strict mode)")
      end
    else
      get_logger().warn("Validation module not fully available, skipping validation", {
        file_path = file_path,
        format = format,
      })
    end
  end

  -- Format the coverage data with error handling
  ---@diagnostic disable-next-line: unused-local
  local format_success, formatted, format_err = get_error_handler().try(function()
    return M.format_coverage(coverage_data, format)
  end)

  if not format_success then
    local err = get_error_handler().runtime_error(
      "Failed to format coverage data",
      {
        file_path = file_path,
        format = format,
        operation = "save_coverage_report",
        module = "reporting",
      },
      formatted -- formatted contains the error when format_success is false
    )
    get_logger().error(err.message, err.context)
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
    get_logger().debug("Validating formatted output", {
      format = format,
      content_sample = type(content) == "string" and content:sub(1, 50) .. "..." or "non-string content",
    })

    -- Only attempt format validation for certain types
    if (format == "json" and type(content) == "table") or type(content) == "string" then
      local validation_success, format_valid, format_err = get_error_handler().try(function()
        return M.validate_report_format(content, format)
      end)

      if validation_success and not format_valid then
        get_logger().warn("Format validation failed", {
          format = format,
          error = format_err,
        })

        -- If strict validation enabled, don't save the file
        if options.strict_validation then
          local validation_err =
            get_error_handler().validation_error("Not saving report due to format validation failure (strict mode)", {
              file_path = file_path,
              format = format,
              operation = "save_coverage_report",
              module = "reporting",
              error = format_err,
            })
          get_logger().error(validation_err.message, validation_err.context)
          return nil, validation_err
        end

        -- Otherwise just warn but continue
        get_logger().warn("Saving report despite format validation issues (non-strict mode)")
      end
    end
  end

  -- Write all formats (including HTML) directly to file
  -- Write to file with error handling
  get_logger().debug("Writing coverage report file", {
    file_path = file_path,
    format = format,
    content_length = #content,
  })

  ---@diagnostic disable-next-line: unused-local
  local write_success, write_err = get_error_handler().try(function()
    return M.write_file(file_path, content)
  end)

  if not write_success then
    local err = get_error_handler().io_error("Failed to write coverage report to file", {
      file_path = file_path,
      format = format,
      operation = "save_coverage_report",
      module = "reporting",
    }, write_err)
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Successfully saved coverage report", {
    file_path = file_path,
    format = format,
  })

  return true
end

--- Formats and saves a quality report to a file.
---@param file_path string Path to save the report file.
---@param quality_data table Raw quality data.
---@param format string The desired output format (e.g., "summary", "json").
---@return boolean|nil success `true` if formatting and saving succeeded, `nil` otherwise.
---@return table|nil error Error object if formatting or saving failed.
---@throws table If formatting or writing fails critically.
function M.save_quality_report(file_path, quality_data, format)
  -- Validate required parameters
  if not file_path then
    local err = get_error_handler().validation_error("Missing required file_path parameter", {
      operation = "save_quality_report",
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if not quality_data then
    local err = get_error_handler().validation_error("Missing required quality_data parameter", {
      operation = "save_quality_report",
      file_path = file_path,
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Set defaults
  format = format or "html"

  get_logger().debug("Saving quality report to file", {
    file_path = file_path,
    format = format,
    has_data = true,
  })

  -- Format the quality data with error handling
  ---@diagnostic disable-next-line: unused-local
  local format_success, formatted, format_err = get_error_handler().try(function()
    return M.format_quality(quality_data, format)
  end)

  if not format_success then
    local err = get_error_handler().runtime_error(
      "Failed to format quality data",
      {
        file_path = file_path,
        format = format,
        operation = "save_quality_report",
        module = "reporting",
      },
      formatted -- formatted contains the error when format_success is false
    )
    get_logger().error(err.message, err.context)
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
  local write_success, write_err = get_error_handler().try(function()
    return M.write_file(file_path, content)
  end)

  if not write_success then
    local err = get_error_handler().io_error(
      "Failed to write quality report to file",
      {
        file_path = file_path,
        format = format,
        operation = "save_quality_report",
        module = "reporting",
      },
      write_success -- write_success contains the error when success is false
    )
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Successfully saved quality report", {
    file_path = file_path,
    format = format,
  })

  return true
end

--- Formats and saves a test results report to a file.
---@param file_path string Path to save the report file.
---@param results_data table Raw test results data.
---@param format string The desired output format (e.g., "junit", "tap").
---@return boolean|nil success `true` if formatting and saving succeeded, `nil` otherwise.
---@return table|nil error Error object if formatting or saving failed.
---@throws table If formatting or writing fails critically.
function M.save_results_report(file_path, results_data, format)
  -- Validate required parameters
  if not file_path then
    local err = get_error_handler().validation_error("Missing required file_path parameter", {
      operation = "save_results_report",
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  if not results_data then
    local err = get_error_handler().validation_error("Missing required results_data parameter", {
      operation = "save_results_report",
      file_path = file_path,
      module = "reporting",
    })
    get_logger().error(err.message, err.context)
    return nil, err
  end

  -- Set defaults
  format = format or "junit"

  get_logger().debug("Saving test results report to file", {
    file_path = file_path,
    format = format,
    has_data = true,
  })

  -- Format the results data with error handling
  ---@diagnostic disable-next-line: unused-local
  local format_success, formatted, format_err = get_error_handler().try(function()
    return M.format_results(results_data, format)
  end)

  if not format_success then
    local err = get_error_handler().runtime_error(
      "Failed to format test results data",
      {
        file_path = file_path,
        format = format,
        operation = "save_results_report",
        module = "reporting",
      },
      formatted -- formatted contains the error when format_success is false
    )
    get_logger().error(err.message, err.context)
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
  local write_success, write_err = get_error_handler().try(function()
    return M.write_file(file_path, content)
  end)

  if not write_success then
    local err = get_error_handler().io_error(
      "Failed to write test results report to file",
      {
        file_path = file_path,
        format = format,
        operation = "save_results_report",
        module = "reporting",
      },
      write_success -- write_success contains the error when success is false
    )
    get_logger().error(err.message, err.context)
    return nil, err
  end

  get_logger().debug("Successfully saved test results report", {
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
--- Automatically generates and saves multiple report types (coverage, quality, results)
--- based on available data and configuration (defaults, central config, and `options`).
--- Determines output paths using templates or defaults.
---@param coverage_data table|nil Optional coverage data to report.
---@param quality_data table|nil Optional quality data to report.
---@param results_data table|nil Optional test results data to report.
---@param options? table|string Optional configuration overrides. Can be a directory path (string) or a table: `{report_dir?: string, report_suffix?: string, timestamp_format?: string, coverage_path_template?: string, quality_path_template?: string, results_path_template?: string, verbose?: boolean, validate?: boolean, strict_validation?: boolean, validation_report?: boolean, validation_report_path?: string}`.
---@return table<string, {success: boolean, error?: table, path: string}> results A summary table mapping report format/type (e.g., "html", "lcov", "quality_json") to its save result (`{success, error?, path}`).
---@throws table If ensuring the base report directory exists fails critically.
function M.auto_save_reports(coverage_data, quality_data, results_data, options)
  -- Handle both string (backward compatibility) and table options
  local config = {}

  if type(options) == "string" then
    config.report_dir = options
  elseif type(options) == "table" then
    config = options
  end

  -- Check central_config for defaults
  -- central_config is loaded at top level and guaranteed to exist
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

      get_logger().debug("Using centralized configuration for reports", {
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
    get_logger().debug("Auto-saving reports", {
      base_dir = base_dir,
      timestamp_format = config.timestamp_format,
      coverage = coverage_debug,
      quality = quality_debug,
      results = results_debug,
    })
  end

  -- Use filesystem module to ensure directory exists
  get_logger().debug("Ensuring report directory exists", {
    directory = base_dir,
  })

  -- Validate directory path
  if not base_dir or base_dir == "" then
    get_logger().error("Failed to create report directory", {
      directory = base_dir,
      error = "Invalid directory path: path cannot be empty",
    })

    -- Return empty results but don't fail
    return {}
  end

  -- Check for invalid characters in directory path
  if base_dir:match("[*?<>|]") then
    get_logger().error("Failed to create report directory", {
      directory = base_dir,
      error = "Invalid directory path: contains invalid characters",
    })

    -- Return empty results but don't fail
    return {}
  end

  -- Create the directory if it doesn't exist
  local dir_ok, dir_err = get_fs().ensure_directory_exists(base_dir)

  if not dir_ok then
    get_logger().error("Failed to create report directory", {
      directory = base_dir,
      error = tostring(dir_err),
    })

    -- Return empty results table
    return {}
  else
    get_logger().debug("Report directory ready", {
      directory = base_dir,
      created = not get_fs().directory_exists(base_dir),
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
          get_logger().info("Saved validation report", {
            path = validation_path,
            is_valid = validation_result.validation and validation_result.validation.is_valid,
          })

          results["validation"] = {
            success = true,
            path = validation_path,
            is_valid = validation_result.validation and validation_result.validation.is_valid,
          }
        else
          get_logger().error("Failed to save validation report", {
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

    get_logger().debug("Saving coverage reports", {
      formats = formats,
      has_template = config.coverage_path_template ~= nil,
      validate = validation_options.validate,
      strict = validation_options.strict_validation,
    })

    for _, format in ipairs(formats) do
      local path = process_template(config.coverage_path_template, format, "coverage")

      get_logger().debug("Saving coverage report", {
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
        get_logger().debug("Successfully saved coverage report", {
          format = format,
          path = path,
        })
      else
        get_logger().error("Failed to save coverage report", {
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

    get_logger().debug("Saving quality reports", {
      formats = formats,
      has_template = config.quality_path_template ~= nil,
    })

    for _, format in ipairs(formats) do
      local path = process_template(config.quality_path_template, format, "quality")

      get_logger().debug("Saving quality report", {
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
        get_logger().debug("Successfully saved quality report", {
          format = format,
          path = path,
        })
      else
        get_logger().error("Failed to save quality report", {
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

    get_logger().debug("Saving test results reports", {
      formats = { "junit", "tap", "csv" },
      has_template = config.results_path_template ~= nil,
    })

    for format, info in pairs(formats) do
      local path = process_template(config.results_path_template, info.ext, "test-results")

      get_logger().debug("Saving test results report", {
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
        get_logger().debug("Successfully saved test results report", {
          format = format,
          name = info.name,
          path = path,
        })
      else
        get_logger().error("Failed to save test results report", {
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

--- Resets the module's local configuration cache to defaults defined in `DEFAULT_CONFIG`.
--- Does **not** reset central configuration or loaded formatters.
---@return reporting The reporting module instance (`M`) for method chaining.
function M.reset()
  -- Reset local configuration to defaults
  config = {
    debug = DEFAULT_CONFIG.debug,
    verbose = DEFAULT_CONFIG.verbose,
  }

  get_logger().debug("Reset local configuration to defaults")

  -- Return the module for chaining
  return M
end

--- Performs a full reset: resets local configuration (`M.reset()`) and attempts to reset
--- the "reporting" section in the central configuration system (if available).
---@return reporting The reporting module instance (`M`) for method chaining.
---@throws table If central config interaction fails critically during reset.
function M.full_reset()
  -- Reset local configuration
  M.reset()

  -- Reset central configuration if available
  -- central_config is loaded at top level and guaranteed to exist
  if central_config then
    central_config.reset("reporting")
    get_logger().debug("Reset central configuration for reporting module")
  end

  return M
end

--- Gets a snapshot of the current configuration (local cache and central config) for debugging.
---@return table debug_info A table containing `{ local_config, using_central_config, central_config }`.
---@throws table If central config interaction fails critically during retrieval.
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
  -- central_config is loaded at top level and guaranteed to exist
  if central_config then
    debug_info.using_central_config = true
    debug_info.central_config = central_config.get("reporting")
  end

  -- Display configuration
  get_logger().info("Reporting module configuration", debug_info)

  return debug_info
end

-- Return the module
return M
