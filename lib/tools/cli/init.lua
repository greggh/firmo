--- Command Line Interface (CLI) Module for Firmo
--- @module lib.tools.cli
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.2

---@class CLI The public API of the CLI module.
--- Handles argument parsing, command execution, and different operational modes.
---@field _VERSION string Version of the CLI module itself.
---@field version string Overall Firmo version string (typically from `lib.core.version`).
---@field parse_args fun(args?: table): table Parses command line arguments into a structured options table. See `default_options` in the source and `knowledge.md` for typical option fields.
---@field show_help fun():nil Displays help information to the console.
---@field run fun(args?: table, firmo_instance_passed_in: table):boolean Main entry point. Parses args, configures, and executes tests or other CLI actions. Returns overall success.
---@field watch fun(firmo_instance: table, options: table):boolean Runs tests in watch mode. Requires `lib.tools.watcher`.
---@field interactive fun(firmo_instance: table, options: table):boolean Runs tests in interactive mode. Requires `lib.tools.interactive`.

local colors_enabled = true
local SGR_CODES =
  { reset = 0, bold = 1, red = 31, green = 32, yellow = 33, blue = 34, magenta = 35, cyan = 36, white = 37 }

--- Generates an SGR (Select Graphic Rendition) escape code string.
--- If colors are disabled globally (via `colors_enabled` upvalue), returns an empty string.
---@param code_or_name string|number The SGR code number or a predefined color/style name (e.g., "red", "bold").
---@return string The ANSI SGR escape code string, or an empty string.
---@private
local function sgr(code_or_name)
  if not colors_enabled then
    return ""
  end
  local code = type(code_or_name) == "number" and code_or_name or SGR_CODES[code_or_name]
  if code then
    return string.char(27) .. "[" .. code .. "m"
  end
  return ""
end

local cr, cg, cy, cb, cm, cc, bold, cn =
  sgr("red"), sgr("green"), sgr("yellow"), sgr("blue"), sgr("magenta"), sgr("cyan"), sgr("bold"), sgr("reset")

local M = {}
M._VERSION = "1.0.2" -- Version increment

local _error_handler, _logging, _fs

--- Safely attempts to require a Lua module.
--- Prints a warning to the console if the module fails to load.
---@param module_name string The name of the module to require.
---@return table|nil The loaded module, or `nil` if loading failed.
---@private
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Lazily loads and returns the filesystem module (`lib.tools.filesystem`).
---@return table|nil The filesystem module, or `nil` if unavailable.
---@private
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
end

--- Lazily loads and returns the error handler module (`lib.tools.error_handler`).
---@return table|nil The error handler module, or `nil` if unavailable.
---@private
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

--- Lazily loads and returns the logging module (`lib.tools.logging`).
---@return table|nil The logging module, or `nil` if unavailable.
---@private
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end

--- Gets a logger instance specifically for the CLI module.
--- If the main logging module is unavailable, it returns a basic stub logger
--- that prints to the console with a "[LEVEL] CLI:" prefix.
---@return table A logger instance (either from `lib.tools.logging` or a stub).
---@private
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("CLI")
  end
  return {
    error = function(...)
      print("[ERROR] CLI:", ...)
    end,
    warn = function(...)
      print("[WARN] CLI:", ...)
    end,
    info = function(...)
      print("[INFO] CLI:", ...)
    end,
    debug = function(...)
      print("[DEBUG] CLI:", ...)
    end,
    trace = function(...)
      print("[TRACE] CLI:", ...)
    end,
  }
end

local central_config, coverage_module, quality_module, watcher_module, interactive_module, parallel_module, runner_module, discover_module, version_module, json_module

--- Loads essential and optional modules required by the CLI.
--- Assigns loaded modules to upvalues (e.g., `central_config`, `runner_module`).
--- Sets `M.version` using `lib.core.version`.
---@private
local function load_modules()
  central_config = try_require("lib.core.central_config")
  coverage_module = try_require("lib.coverage")
  quality_module = try_require("lib.quality")
  watcher_module = try_require("lib.tools.watcher")
  interactive_module = try_require("lib.tools.interactive")
  parallel_module = try_require("lib.tools.parallel")
  runner_module = try_require("lib.core.runner")
  discover_module = try_require("lib.tools.discover")
  version_module = try_require("lib.core.version")
  json_module = try_require("lib.tools.json")
  if version_module and version_module.string then
    M.version = version_module.string
  else
    M.version = "unknown"
    get_logger().warn("Failed to load version string from version_module.")
  end
end

local default_options = {
  show_help = false,
  show_version = false,
  verbose = false,
  coverage_enabled = false,
  coverage_debug = false,
  coverage_threshold = 70,
  quality_enabled = false,
  quality_level = 3,
  watch_mode = false,
  interactive_mode = false,
  parallel_execution = false,
  file_discovery_pattern = "*_test.lua",
  test_name_filter = nil,
  config_file_path = nil,
  perform_create_config = false,
  console_format = "default",
  report_file_formats = {},
  report_output_dir = "./firmo-reports",
  generate_reports = false,
  console_json_dump = false,
  output_json_filepath = nil, -- ADDED: For dedicated JSON output file
  extra_config_settings = {},
  base_test_dir = "./tests",
  specific_paths_to_run = {},
  parse_errors = {},
}

-- Table of recognized CLI flags and their expected value type
-- true = flag requires a value, false = boolean flag (no value)
local valid_cli_flags = {
  -- Boolean flags
  help = false,
  h = false,
  version = false,
  V = false,
  verbose = false,
  v = false,
  coverage = false,
  c = false,
  ["coverage-debug"] = false,
  quality = false,
  q = false,
  watch = false,
  w = false,
  interactive = false,
  i = false,
  parallel = false,
  p = false,
  ["create-config"] = false,
  report = false,
  r = false,
  json = false,
  -- Value flags
  pattern = true,
  filter = true,
  ["quality-level"] = true,
  threshold = true,
  ["console-format"] = true,
  ["results-format"] = true,
  ["output-json-file"] = true,
  ["report-formats"] = true,
  ["report-dir"] = true,
  config = true,
}

--- Parses command line arguments into a structured options table.
--- It handles various flag formats (short, long, with values, combined short flags),
--- positional arguments (interpreted as test paths), and integrates with
--- `central_config` to load defaults and apply CLI overrides.
--- Errors encountered during parsing are collected in `options.parse_errors`.
---
--- The parser validates all long-form options (--flag) against a list of known flags
--- and only allows unknown options in the form of --key=value for config settings.
--- Any unrecognized flags or malformed arguments are recorded as errors.
---@param args? table Optional array of argument strings (defaults to Lua's global `_G.arg`).
---@return table options A table containing parsed options, merged with defaults from `default_options` and potentially `central_config`. Refer to `default_options` in the source and `lib/tools/cli/knowledge.md` for a detailed description of the fields in the returned options table.
function M.parse_args(args)
  args = args or _G.arg or {}
  local options = {}
  for k, v in pairs(default_options) do
    options[k] = v
  end
  if central_config then
    local cli_defaults_cen = central_config.get("cli_options")
    if cli_defaults_cen then
      for k, v in pairs(cli_defaults_cen) do
        if options[k] ~= nil then -- Only override if the key exists in our defaults
          options[k] = v
        end
      end
    end
    -- Override specific options from other central_config sections
    local q_cfg = central_config.get("quality")
    if q_cfg then
      options.quality_level = q_cfg.level or options.quality_level
    end
    local c_cfg = central_config.get("coverage")
    if c_cfg then
      options.coverage_threshold = c_cfg.threshold or options.coverage_threshold
    end
    options.report_output_dir = central_config.get("reporting.report_dir") or options.report_output_dir
    options.file_discovery_pattern = central_config.get("runner.default_pattern") or options.file_discovery_pattern
    options.base_test_dir = central_config.get("runner.default_test_dir") or options.base_test_dir
  end

  -- Initialize potentially dynamic fields
  options.specific_paths_to_run = {}
  options.report_file_formats = {} -- Ensure this is always a table
  options.extra_config_settings = {}
  options.parse_errors = {}

  local i = 1
  while i <= #args do
    local arg_val = args[i]
    local consumed_next = false
    local key, value

    -- Try to parse '--key=value'
    if arg_val:match("^%-%-.+=.") then
      key, value = arg_val:match("^%-%-([^=]+)=(.+)")
    -- Try to parse '--key value' or '-k value'
    elseif args[i + 1] and not args[i + 1]:match("^%-") then -- Next arg exists and is not an option itself
      if arg_val:match("^%-%-.") or arg_val:match("^%-%a$") then -- Long option or single char short option
        key = arg_val:match("^%-%-(.+)") or arg_val:match("^%-(.+)")
        value = args[i + 1]
        consumed_next = true
      end
    -- Try to parse '--key' (boolean long option)
    elseif arg_val:match("^%-%-.") then
      key = arg_val:match("^%-%-(.+)")
      value = true -- Assume boolean flag if no value part
    -- Try to parse '-abc' (combined short boolean options) or '-k' (single short boolean option)
    elseif arg_val:match("^%-%a+$") then
      local short_flags = arg_val:sub(2)
      if #short_flags == 1 then -- Single short flag like '-v'
        key = short_flags
        value = true
      else -- Combined short flags like '-vcq'
        for k_idx = 1, #short_flags do
          local flag_char = short_flags:sub(k_idx, k_idx)
          if flag_char == "h" then
            options.show_help = true
          elseif flag_char == "V" then
            options.show_version = true
          elseif flag_char == "v" then
            options.verbose = true
          elseif flag_char == "c" then
            options.coverage_enabled = true
          elseif flag_char == "q" then
            options.quality_enabled = true
          elseif flag_char == "w" then
            options.watch_mode = true
          elseif flag_char == "i" then
            options.interactive_mode = true
          elseif flag_char == "p" then
            options.parallel_execution = true
          elseif flag_char == "r" then
            options.generate_reports = true
          else
            table.insert(options.parse_errors, "Unknown short flag in combined group: -" .. flag_char)
          end
        end
        key = nil -- Processed combined flags, skip main key processing
      end
    end

    if key then
      if key == "help" or key == "h" then
        options.show_help = true
      elseif key == "version" or key == "V" then
        options.show_version = true
      elseif key == "verbose" or key == "v" then
        options.verbose = true
      elseif key == "coverage" or key == "c" then
        options.coverage_enabled = true
      elseif key == "coverage-debug" then
        options.coverage_debug = true -- Assuming boolean
      elseif key == "quality" or key == "q" then
        options.quality_enabled = true
      elseif key == "watch" or key == "w" then
        options.watch_mode = true
      elseif key == "interactive" or key == "i" then
        options.interactive_mode = true
      elseif key == "parallel" or key == "p" then
        options.parallel_execution = true
      elseif key == "create-config" then
        options.perform_create_config = true
      elseif key == "report" or key == "r" then
        options.generate_reports = true
      elseif key == "json" then -- New shorthand for console JSON dump
        options.console_json_dump = true
        options.console_format = "json_dump_internal" -- Internal format key for this
      elseif key == "pattern" then
        options.file_discovery_pattern = value
      elseif key == "filter" then
        options.test_name_filter = value
      elseif key == "quality-level" then
        options.quality_level = tonumber(value) or options.quality_level
      elseif key == "threshold" then
        options.coverage_threshold = tonumber(value) or options.coverage_threshold
      elseif key == "console-format" or key == "results-format" then
        options.console_format = value
        if value == "json_dump_internal" or value == "json" then -- Ensure json flag is also set
          options.console_json_dump = true
        end
      elseif key == "output-json-file" then
        options.output_json_filepath = value -- ADDED
      elseif key == "report-formats" then
        options.report_file_formats = {} -- Reset if specified multiple times
        for fmt_name in value:gmatch("([^,]+)") do
          table.insert(options.report_file_formats, fmt_name:match("^%s*(.-)%s*$")) -- Trim whitespace
        end
      elseif key == "report-dir" then
        options.report_output_dir = value
      elseif key == "config" then
        options.config_file_path = value
        if central_config and get_fs() and get_fs().file_exists(options.config_file_path) then
          local loaded_ok, load_err = central_config.load_from_file(options.config_file_path)
          if not loaded_ok then
            table.insert(
              options.parse_errors,
              "Failed to load config file '" .. options.config_file_path .. "': " .. tostring(load_err)
            )
          else
            -- Config loaded, re-apply defaults and central config to effectively refresh options
            -- Store critical flags like help/version before refresh
            local prev_help = options.show_help
            local prev_version = options.show_version

            local temp_opts = {} -- Start from scratch
            for kd, vd in pairs(default_options) do
              temp_opts[kd] = vd
            end
            local cc_all = central_config.get()
            if cc_all.cli_options then
              for kc, vc in pairs(cc_all.cli_options) do
                if temp_opts[kc] ~= nil then
                  temp_opts[kc] = vc
                end
              end
            end
            if cc_all.quality then
              temp_opts.quality_level = cc_all.quality.level or temp_opts.quality_level
            end
            if cc_all.coverage then
              temp_opts.coverage_threshold = cc_all.coverage.threshold or temp_opts.coverage_threshold
            end
            temp_opts.report_output_dir = cc_all.reporting and cc_all.reporting.report_dir
              or temp_opts.report_output_dir
            -- temp_opts.file_discovery_pattern = cc_all.runner and cc_all.runner.default_pattern or temp_opts.file_discovery_pattern -- Already handled by initial load

            options = temp_opts -- Replace options with refreshed ones
            options.show_help = prev_help or options.show_help -- Restore critical flags
            options.show_version = prev_version or options.show_version
            -- Re-initialize dynamic fields
            options.specific_paths_to_run = {}
            options.report_file_formats = {}
            options.extra_config_settings = {}
            options.parse_errors = {} -- Clear parse errors as config file is now the source of truth
          end
        elseif not central_config then
          table.insert(options.parse_errors, "central_config module not available to load --config file.")
        elseif not (get_fs() and get_fs().file_exists(options.config_file_path)) then
          table.insert(options.parse_errors, "Specified config file not found: " .. options.config_file_path)
        end
      -- Handle boolean flags that might already exist in options
      elseif type(value) == "boolean" and options[key] ~= nil and type(options[key]) == "boolean" then
        options[key] = value
      -- Validate long options against known flags
      elseif arg_val:match("^%-%-") then
        if valid_cli_flags[key] ~= nil then
          -- Known flag, check if value matches expected type
          if valid_cli_flags[key] == true and value == true then
            -- Flag expects a value but none provided
            table.insert(options.parse_errors, "Option --" .. key .. " requires a value")
          elseif valid_cli_flags[key] == false and value ~= true then
            -- Flag doesn't expect a value but one was provided
            table.insert(options.parse_errors, "Option --" .. key .. " doesn't accept a value")
          end
          -- Valid flag is handled by the specific option cases above, no need to do anything else here
        else
          -- Not a recognized CLI flag, check if it's a valid config setting (must have equals sign)
          if arg_val:match("=") then
            -- Looks like a config setting (--key=value format)
            if key:match("^[%w_][%w_.]*$") then -- Basic validation of config key format
              options.extra_config_settings[key] = value
            else
              table.insert(options.parse_errors, "Invalid config setting format: " .. arg_val)
            end
          else
            table.insert(options.parse_errors, "Unknown option: " .. arg_val)
          end
        end
      else -- Unrecognized option or positional argument
        if arg_val:match("^%-") then -- It's an option we don't know
          table.insert(options.parse_errors, "Unknown option: " .. arg_val)
        else -- It's a positional argument (path)
          table.insert(options.specific_paths_to_run, arg_val)
        end
      end
    else -- Not a recognized key format, assume positional path
      if not arg_val:match("^%-") then -- Ensure it's not an option we missed
        table.insert(options.specific_paths_to_run, arg_val)
      elseif not key and not arg_val:match("^%-%a%a+$") then -- Avoid erroring on already processed combined short flags
        table.insert(options.parse_errors, "Malformed or unknown option: " .. arg_val)
      end
    end
    i = i + (consumed_next and 2 or 1)
  end

  -- Post-process paths: if a directory is first among specific_paths_to_run,
  -- it becomes base_test_dir, and other paths are relative or absolute files/dirs.
  local processed_paths = {}
  local base_dir_set_from_paths = false
  if #options.specific_paths_to_run > 0 then
    for _, path_arg in ipairs(options.specific_paths_to_run) do
      if not base_dir_set_from_paths and get_fs() then
        local is_dir_ok, is_dir_val = pcall(get_fs().is_directory, path_arg)
        if is_dir_ok and is_dir_val then
          options.base_test_dir = path_arg
          base_dir_set_from_paths = true
          -- This directory itself isn't added to processed_paths, it sets the context
        else
          table.insert(processed_paths, path_arg) -- It's a file or non-existent, treat as specific target
        end
      else
        table.insert(processed_paths, path_arg) -- Subsequent paths are specific targets
      end
    end
    options.specific_paths_to_run = processed_paths
  end

  -- If no specific paths led to setting base_test_dir, and no specific files are listed,
  -- ensure base_test_dir has its default.
  if #options.specific_paths_to_run == 0 and not base_dir_set_from_paths then
    options.base_test_dir = options.base_test_dir or default_options.base_test_dir
  end

  return options
end

--- Displays detailed help information for the Firmo CLI to the console.
--- Lists available options, their descriptions, and usage examples.
---@return nil
function M.show_help()
  print("Firmo Test Framework - Unified CLI")
  print("Usage: lua firmo.lua [options] [paths...]")
  print("")
  print("Options:")
  print("  Paths                       One or more file or directory paths to test.")
  print("                              If a directory is first, it's the base for discovery.")
  print("")
  print("  General:")
  print("    -h, --help                Show this help message and exit.")
  print("    -V, --version             Show Firmo version and exit.")
  print("    -v, --verbose             Enable verbose logging output.")
  print("    --config=<path>           Load a specific Firmo configuration file.")
  print("    --create-config           Create a default '.firmo-config.lua' file and exit.")
  print("    --<key>=<value>           Set a 'central_config' value (e.g., --logging.level=DEBUG).")
  print("")
  print("  Test Execution & Filtering:")
  print("    --pattern=<glob>          Glob pattern for test file discovery (e.g., '*_spec.lua').")
  print("                              Default: " .. (default_options.file_discovery_pattern or "*_test.lua"))
  print("    --filter=<lua_pattern>    Lua pattern to filter tests by their names/descriptions.")
  print("    -p, --parallel            Enable parallel test execution (if supported).")
  print("    --output-json-file=<path> For internal use by parallel runner: worker writes JSON results to this file.")
  print("")
  print("  Modes:")
  print("    -w, --watch               Enable watch mode to re-run tests on file changes.")
  print("    -i, --interactive         Enable interactive REPL mode.")
  print("")
  print("  Features:")
  print("    -c, --coverage            Enable code coverage analysis.")
  print("    --coverage-debug          Enable debug logging for the coverage module.")
  print("    --threshold=<0-100>       Set coverage threshold percentage (used by coverage).")
  print("    -q, --quality             Enable test quality validation.")
  print("    --quality-level=<1-5>     Set target quality level.")
  print("")
  print("  Reporting:")
  print("    -r, --report              Generate configured file reports after tests run.")
  print("    --console-format=<type>   Set console output style during test run.")
  print("                              Types: default, dot, summary, json_dump_internal (for --json).")
  print("    --report-formats=<list>   Comma-separated list of report file formats (e.g., 'html,json,md').")
  print("    --report-dir=<path>       Output directory for all generated report files.")
  print("                              Default: " .. (default_options.report_output_dir or "./firmo-reports"))
  print(
    "    --json                    Shorthand for '--console-format=json_dump_internal'. Outputs JSON test results to console."
  )
  print("")
  print("Examples:")
  print("  lua firmo.lua tests/")
  print("  lua firmo.lua --coverage --report-formats=html,lcov")
  print("  lua firmo.lua --quality --quality-level=4 tests/specific_test.lua")
  print('  lua firmo.lua --filter="User Login" --verbose')
  print("  lua firmo.lua -w -p")
  print("  lua firmo.lua --interactive")
  get_logger().info("Help displayed to user.")
end

--- Prints a formatted summary of test results to the console.
--- Adapts output based on the `options.console_format` (e.g., "dot" or "default").
--- Uses colors if enabled via the global `colors_enabled` and not plain format.
---@param results table A results table, typically from `runner_module.run_tests` or `runner_module.run_file`. Expected fields include `passes`, `errors`, `skipped`, `total`, `elapsed`, `success`, and optionally `file` or `files_tested`, `files_passed`, `files_failed`.
---@param options? table The CLI options table, used to determine `console_format` and color usage.
---@private
local function print_final_summary(results, options)
  local logger = get_logger()
  if not results then
    logger.warn("print_final_summary called with nil results.")
    return
  end
  options = options or {}
  local use_colors = colors_enabled and (options.console_format ~= "plain")
  local pcr, pcg, pcy, pcn, pbold =
    (use_colors and cr or ""),
    (use_colors and cg or ""),
    (use_colors and cy or ""),
    (use_colors and cn or ""),
    (use_colors and bold or "")
  local t_passes, t_errors, t_skipped = results.passes or 0, results.errors or 0, results.skipped or 0
  local t_total = results.total or (t_passes + t_errors + t_skipped)
  local elapsed_time = results.elapsed or 0
  local overall_success = results.success
  if options.console_format == "dot" then
    logger.info(overall_success and (pcg .. "All tests passed!" .. pcn) or (pcr .. "There were test failures!" .. pcn))
    logger.info(
      "Passes: " .. t_passes .. ", Failures: " .. t_errors .. ", Skipped: " .. t_skipped .. " | Total: " .. t_total
    )
    if results.files_tested then
      logger.info(
        "Files: "
          .. results.files_tested
          .. " tested, "
          .. (results.files_passed or 0)
          .. " passed, "
          .. (results.files_failed or 0)
          .. " failed."
      )
    end
    logger.info(string.format("Time: %.3f seconds", elapsed_time)) -- Using .3f for exact test match
  else
    logger.info(pbold .. "Test Execution Summary:" .. pcn)
    if results.file then
      logger.info("File: " .. results.file)
    elseif results.files_tested then
      logger.info(
        "Files Tested: "
          .. results.files_tested
          .. " (Passed: "
          .. pcg
          .. (results.files_passed or 0)
          .. pcn
          .. ", Failed: "
          .. pcr
          .. (results.files_failed or 0)
          .. pcn
          .. ")"
      )
    end
    logger.info(string.rep("-", 40))
    logger.info("  Passes: " .. pcg .. t_passes .. pcn)
    logger.info("  Failures: " .. (t_errors > 0 and pcr or pcn) .. t_errors .. pcn)
    logger.info("  Skipped: " .. pcy .. t_skipped .. pcn)
    logger.info("  Total Tests Run: " .. t_total)
    logger.info(string.format("  Total Time: %.3f seconds", elapsed_time)) -- Using .3f for exact test match
    logger.info(string.rep("-", 40))
    if overall_success then
      logger.info(pcg .. pbold .. "All tests passed successfully!" .. pcn)
    else
      logger.info(pcr .. pbold .. "Some tests failed or errors occurred." .. pcn)
    end
  end
end

--- Main entry point for the Firmo CLI.
--- This function orchestrates the entire CLI process:
--- 1. Loads necessary modules.
--- 2. Parses command-line arguments using `M.parse_args`.
--- 3. Handles informational flags like `--help` and `--version`.
--- 4. Handles `--create-config` to generate a default configuration file.
--- 5. Applies CLI options to configure logging, coverage, quality, and the test runner.
--- 6. Determines the execution mode (standard run, watch, interactive).
--- 7. For standard runs:
---    a. Discovers test files or uses specified paths.
---    b. Applies test name filters.
---    c. Invokes `runner_module.run_file` or `runner_module.run_tests`.
---    d. Handles JSON output for results if requested (for single file/worker or multi-file).
---    e. Prints a final summary using `print_final_summary`.
--- 8. For watch or interactive modes, delegates to `M.watch` or `M.interactive`.
--- 9. Triggers report generation via `lib.reporting.auto_save_reports` if `--report` is specified.
---
---@param args? table Optional array of command-line argument strings (defaults to `_G.arg`).
---@param firmo_instance_passed_in table The main Firmo instance, which provides core functionalities and interfaces like `set_filter`, `reset`, etc. This instance is passed through to other modules like the runner.
---@return boolean success Overall success status of the CLI operation. `true` if all tests passed and reports generated successfully (if requested), `false` otherwise or if critical errors occurred.
function M.run(args, firmo_instance_passed_in)
  load_modules()
  local options = M.parse_args(args)
  if options.show_help then
    M.show_help()
    return true
  end
  if options.show_version then
    if version_module and version_module.string then
      print("Firmo version " .. version_module.string)
    else
      print("Firmo version unknown")
    end
    return true
  end
  if options.perform_create_config then
    if central_config and central_config.create_default_config_file then
      local crtd, emsg = central_config.create_default_config_file(".firmo-config.lua")
      if crtd then
        print("Created .firmo-config.lua")
        return true
      else
        print("Error: " .. tostring(emsg))
        return false
      end
    else
      print("Error: Central_config missing for create-config")
      return false
    end
  end
  if options.parse_errors and #options.parse_errors > 0 then
    get_logger().error("CLI Argument Parsing Errors:")
    for _, e in ipairs(options.parse_errors) do
      get_logger().error("- " .. e)
    end
    M.show_help()
    return false
  end
  if central_config and options.extra_config_settings then
    for k, v in pairs(options.extra_config_settings) do
      central_config.set(k, v)
      get_logger().debug("Set CLI config override", { key = k, value = v })
    end
  end
  local firmo_instance = firmo_instance_passed_in
  if not firmo_instance then
    get_logger().error("CRITICAL: firmo_instance not passed to cli.run()")
    return false
  end
  -- Diagnostic print BEFORE the verbose check
  local temp_log_mod_check = get_logging()

  if options.verbose then
    local log_mod = get_logging() -- Get fresh instance for set_level
    if log_mod and log_mod.set_level then
      log_mod.set_level("DEBUG") -- This call should trigger diagnostic prints from logging.set_level itself
      get_logger().info("Verbose logging enabled.") -- This uses the CLI's named logger instance
    else
      get_logger().error("Could not set global logging level to DEBUG for verbose mode.")
    end
  end
  if options.coverage_enabled then
    if coverage_module and coverage_module.init and coverage_module.start then
      local co = { enabled = true }
      if options.coverage_debug then
        co.debug_mode = true
      end
      if options.coverage_threshold then
        co.threshold = options.coverage_threshold
      end
      coverage_module.init(co)
      coverage_module.start()
      options.coverage_instance = coverage_module
    else
      get_logger().warn("Coverage module not available.")
    end
  end
  if options.quality_enabled then
    if quality_module and quality_module.init and quality_module.register_with_firmo then
      local qo = { enabled = true }
      if options.quality_level then
        qo.level = options.quality_level
      end
      if options.coverage_instance then
        qo.coverage_data = options.coverage_instance
      end
      quality_module.init(qo)
      if firmo_instance.reset then
        quality_module.register_with_firmo(firmo_instance)
      end
      options.quality_instance = quality_module
    else
      get_logger().warn("Quality module not available.")
    end
  end
  if runner_module and runner_module.configure then
    runner_module.configure({
      format = {
        dot_mode = options.console_format == "dot",
        summary_only = options.console_format == "summary",
        compact = options.console_format == "compact",
      },
      parallel = options.parallel_execution,
      coverage_instance = options.coverage_instance,
      quality_instance = options.quality_instance,
      verbose = options.verbose,
    })
  end
  local overall_success = true
  if options.watch_mode then
    if watcher_module and M.watch then
      overall_success = M.watch(firmo_instance, options)
    else
      get_logger().error("Watcher module not available.")
      overall_success = false
    end
  elseif options.interactive_mode then
    if interactive_module and M.interactive then
      overall_success = M.interactive(firmo_instance, options)
    else
      get_logger().error("Interactive module not available.")
      overall_success = false
    end
  else
    if not runner_module then
      get_logger().error("Runner module not loaded.")
      return false
    end
    local target_files_to_run
    if options.specific_paths_to_run and #options.specific_paths_to_run > 0 then
      target_files_to_run = options.specific_paths_to_run
      get_logger().info("Running specific paths", { paths = target_files_to_run })
    else
      if discover_module and type(discover_module.discover) == "function" then
        get_logger().info(
          "Discovering tests",
          { dir = options.base_test_dir, pattern = options.file_discovery_pattern }
        )
        local dr, de = discover_module.discover(options.base_test_dir, options.file_discovery_pattern)
        if not dr then
          get_logger().error("Discovery failed", {
            dir = options.base_test_dir,
            pattern = options.file_discovery_pattern,
            error = de and get_error_handler().format_error(de) or "?",
          })
          return false
        end
        target_files_to_run = dr.files
        if #target_files_to_run == 0 then
          get_logger().warn(
            "No test files found.",
            { dir = options.base_test_dir, pattern = options.file_discovery_pattern }
          )
        end
      else
        get_logger().error("Discover module/function not available.")
        return false
      end
    end
    if firmo_instance.set_filter and options.test_name_filter then
      firmo_instance.set_filter(options.test_name_filter)
    end
    if #target_files_to_run > 0 then
      local runner_opts_for_run = {
        verbose = options.verbose,
        console_format = options.console_format,
        coverage_instance = options.coverage_instance,
        quality_instance = options.quality_instance,
        parallel = options.parallel_execution,
      }
      if #target_files_to_run == 1 and get_fs() and get_fs().file_exists(target_files_to_run[1]) then
        -- This is the path taken by WORKER processes invoked by the parallel runner
        local result_table_single_file =
          runner_module.run_file(target_files_to_run[1], firmo_instance, runner_opts_for_run)
        if result_table_single_file then
          overall_success = result_table_single_file.success and (result_table_single_file.errors or 0) == 0
          if options.output_json_filepath and json_module and get_fs() then -- Check for dedicated JSON output file path
            get_logger().debug("Worker: Attempting to write JSON to dedicated file: " .. options.output_json_filepath)
            local json_str, json_err = json_module.encode(result_table_single_file)
            if json_str then
              local write_ok, write_err = get_fs().write_file(options.output_json_filepath, json_str)
              if write_ok then
                get_logger().debug("Worker: Successfully wrote JSON to: " .. options.output_json_filepath)
              else
                get_logger().error(
                  "Worker: Failed to write JSON to dedicated file.",
                  { path = options.output_json_filepath, error = write_err }
                )
              end
            else
              get_logger().error(
                "Worker: json_module.encode failed for dedicated file output.",
                { error = json_err and (json_err.message or tostring(json_err)) }
              )
            end
            -- When outputting to a dedicated file, worker should not produce other console output like summary or delimited JSON.
          elseif options.console_json_dump and json_module then -- Fallback to stdout JSON dump (e.g. if user runs single file with --json)
            get_logger().debug("Worker/SingleRun: Attempting console JSON dump.")
            local json_str, json_err = json_module.encode(result_table_single_file)
            if json_str then
              print("RESULTS_JSON_BEGIN")
              print(json_str)
              print("RESULTS_JSON_END")
            else
              get_logger().error("Worker/SingleRun: json_module.encode failed.", { error = json_err })
              print_final_summary(result_table_single_file, options)
            end
          else -- Fallback to standard console summary for single run
            get_logger().debug("Worker/SingleRun: Calling print_final_summary.")
            print_final_summary(result_table_single_file, options)
          end
        else
          overall_success = false
          get_logger().error("Worker: runner_module.run_file returned nil for: " .. target_files_to_run[1])
          if options.output_json_filepath and json_module and get_fs() then -- Try to write minimal error to dedicated file
            local err_json_str = json_module.encode({
              error = "runner_module.run_file_returned_nil",
              file = target_files_to_run[1] or "unknown",
            })
            if err_json_str then
              get_fs().write_file(options.output_json_filepath, err_json_str)
            end
          elseif options.console_json_dump then -- Fallback to stdout error JSON if dedicated file not specified but console dump requested
            print("RESULTS_JSON_BEGIN")
            print(
              '{"error":"runner_module.run_file_returned_nil","file":"' .. (target_files_to_run[1] or "unknown") .. '"}'
            )
            print("RESULTS_JSON_END")
          end
        end
      else -- Multi-file execution path (main process when running multiple files)
        local results_table_multi_file =
          runner_module.run_tests(target_files_to_run, firmo_instance, runner_opts_for_run)
        if results_table_multi_file then
          overall_success = results_table_multi_file.success
          if options.console_json_dump and json_module then
            local js, je = json_module.encode(results_table_multi_file)
            if js then
              print("RESULTS_JSON_BEGIN")
              print(js)
              print("RESULTS_JSON_END")
            else
              get_logger().error("Failed to encode multi-file results", { error = je and (je.message or tostring(je)) })
              print_final_summary(results_table_multi_file, options)
            end
          else
            print_final_summary(results_table_multi_file, options)
          end
        else
          overall_success = false
          get_logger().error("runner_module.run_tests returned nil")
        end
      end
    else
      get_logger().info("No test files to run.")
    end
  end
  local reporting_mod = try_require("lib.reporting")
  local reporting_ok = true
  if options.generate_reports and options.report_file_formats and #options.report_file_formats > 0 then
    if reporting_mod then
      local cov_data, qual_data
      if
        options.coverage_instance
        and options.coverage_instance.shutdown
        and options.coverage_instance.get_report_data
      then
        options.coverage_instance.shutdown()
        cov_data = options.coverage_instance.get_report_data()
      end
      if options.quality_instance and options.quality_instance.get_report_data then
        qual_data = options.quality_instance.get_report_data()
      end
      if cov_data or qual_data then
        local p_path = nil
        if options.specific_paths_to_run and #options.specific_paths_to_run == 1 then
          p_path = options.specific_paths_to_run[1]
        elseif
          not (options.specific_paths_to_run and #options.specific_paths_to_run > 0)
          and options.base_test_dir
          and get_fs()
          and get_fs().is_directory(options.base_test_dir)
        then
          p_path = options.base_test_dir
        end
        local aso = {
          report_dir = options.report_output_dir,
          current_test_file_path = p_path,
          coverage_formats = options.coverage_enabled and options.report_file_formats or nil,
          quality_formats = options.quality_enabled and options.report_file_formats or nil,
        }
        local rok, rer = pcall(reporting_mod.auto_save_reports, cov_data, qual_data, nil, aso)
        if not rok then
          -- Log with both logger (for structured logs) and print (for console/test capture)
          local err_msg = "auto_save_reports failed: " .. tostring(rer)
          get_logger().error(err_msg, {
            error = tostring(rer),
            report_dir = options.report_output_dir,
            formats = table.concat(options.report_file_formats, ","),
          })
          print("Error: " .. err_msg) -- Ensure it appears in captured output

          -- Add more detailed error information for specific error types
          if type(rer) == "string" then
            if rer:match("Permission denied") then
              local perm_msg = "Permission denied while writing to report directory: " .. options.report_output_dir
              get_logger().error(perm_msg, { dir = options.report_output_dir })
              print("Error: " .. perm_msg) -- Console output for test capture
            elseif rer:match("No such file or directory") then
              local dir_msg = "Report directory does not exist: " .. options.report_output_dir
              get_logger().error(dir_msg, { dir = options.report_output_dir })
              print("Error: " .. dir_msg) -- Console output for test capture
            end
          elseif type(rer) == "table" and rer.message then
            local detail_msg = "Report generation error details: " .. rer.message
            get_logger().error(detail_msg, {
              message = rer.message,
              code = rer.code,
              type = rer.type,
            })
            print("Error: " .. detail_msg) -- Console output for test capture
          end

          reporting_ok = false
          -- Ensure reporting failure is reflected in return value
          reporting_ok = false
        end
      else
        get_logger().info("No coverage/quality data for reports.")
      end
    else
      get_logger().warn("Reporting module not loaded.")
      reporting_ok = false
    end
  end
  return overall_success and reporting_ok
end

--- Runs tests in watch mode using the `lib.tools.watcher` module.
--- Monitors specified directories/files and re-runs tests on changes.
--- Requires `watcher_module` and `runner_module` to be available.
---@param firmo_instance table The main Firmo instance.
---@param options table Parsed command line options (expects fields like `base_test_dir`, `specific_paths_to_run`, `file_discovery_pattern`, `console_format`, `parallel_execution`, `coverage_instance`, `verbose`).
---@return boolean success `false` if required modules are missing, otherwise this function typically doesn't return as the watcher takes over.
function M.watch(firmo_instance, options)
  if not watcher_module then
    get_logger().error("Watcher module not available.")
    print("Error: Watch mode unavailable.")
    return false
  end
  if not runner_module then
    get_logger().error("Runner module required by watch mode.")
    print("Error: Runner module unavailable.")
    return false
  end
  watcher_module.configure({
    dirs = { options.base_test_dir },
    ignore = { "node_modules", ".git" }, -- Consider making this configurable
    debounce = 500, -- Consider making this configurable
    clear_console = true, -- Consider making this configurable
  })
  runner_module.configure({ -- Ensure runner is configured for watch loop
    format = { dot_mode = options.console_format == "dot", summary_only = options.console_format == "summary" },
    parallel = options.parallel_execution,
    coverage_instance = options.coverage_instance,
    verbose = options.verbose,
  })
  watcher_module.watch(function(changed_files)
    get_logger().info("Files changed, rerunning", { files = changed_files })
    if #options.specific_paths_to_run > 0 then
      return runner_module.run_tests(
        options.specific_paths_to_run,
        firmo_instance,
        { parallel = options.parallel_execution, coverage_instance = options.coverage_instance }
      )
    else
      return runner_module.run_discovered(options.base_test_dir, options.file_discovery_pattern, firmo_instance)
    end
  end)
  return true -- Typically not reached as watcher.watch() blocks
end

--- Runs tests in interactive mode using the `lib.tools.interactive` module.
--- Provides a TUI for selecting and running tests.
--- Requires `interactive_module` to be available.
---@param firmo_instance table The main Firmo instance.
---@param options table Parsed command line options (expects fields like `base_test_dir`, `coverage_instance`, `quality_instance`).
---@return boolean success `false` if the interactive module is missing, otherwise this function typically doesn't return as the interactive mode takes over.
function M.interactive(firmo_instance, options)
  if not interactive_module then
    get_logger().error("Interactive module not available.")
    print("Error: Interactive mode unavailable.")
    return false
  end
  interactive_module.configure({
    test_dir = options.base_test_dir,
    coverage_instance = options.coverage_instance,
    quality_instance = options.quality_instance,
  })
  interactive_module.start(firmo_instance)
  return true -- Typically not reached as interactive.start() blocks
end

return M
