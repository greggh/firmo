--- Command Line Interface (CLI) Module for Firmo
--- @module lib.tools.cli
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.2

local colors_enabled = true
local SGR_CODES =
  { reset = 0, bold = 1, red = 31, green = 32, yellow = 33, blue = 34, magenta = 35, cyan = 36, white = 37 }
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
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
end
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end
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
        if options[k] ~= nil then
          options[k] = v
        end
      end
    end
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
  options.specific_paths_to_run = {}
  options.report_file_formats = {}
  options.extra_config_settings = {}
  options.parse_errors = {}
  local i = 1
  while i <= #args do
    local arg_val = args[i]
    local consumed_next = false
    local key, value
    if arg_val:match("^%-%-.+=.") then
      key, value = arg_val:match("^%-%-([^=]+)=(.+)")
    elseif args[i + 1] and not args[i + 1]:match("^%-") then
      if arg_val:match("^%-%-.") or arg_val:match("^%-%a$") then
        key = arg_val:match("^%-%-(.+)") or arg_val:match("^%-(.+)")
        value = args[i + 1]
        consumed_next = true
      end
    elseif arg_val:match("^%-%-.") then
      key = arg_val:match("^%-%-(.+)")
      value = true
    elseif arg_val:match("^%-%a+$") then
      local fs = arg_val:sub(2)
      if #fs == 1 then
        key = fs
        value = true
      else
        for kx = 1, #fs do
          local fc = fs:sub(kx, kx)
          if fc == "h" then
            options.show_help = true
          elseif fc == "V" then
            options.show_version = true
          elseif fc == "v" then
            options.verbose = true
          elseif fc == "c" then
            options.coverage_enabled = true
          elseif fc == "q" then
            options.quality_enabled = true
          elseif fc == "w" then
            options.watch_mode = true
          elseif fc == "i" then
            options.interactive_mode = true
          elseif fc == "p" then
            options.parallel_execution = true
          elseif fc == "r" then
            options.generate_reports = true
          else
            table.insert(options.parse_errors, "Unknown short flag: -" .. fc)
          end
        end
        key = nil
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
        options.coverage_debug = true
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
      elseif key == "json" then
        options.console_json_dump = true
        options.console_format = "json_dump_internal"
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
        if value == "json_dump_internal" or value == "json" then
          options.console_json_dump = true
        end
      elseif key == "output-json-file" then
        options.output_json_filepath = value -- ADDED: Parse new argument
      elseif key == "report-formats" then
        options.report_file_formats = {}
        for fn in value:gmatch("([^,]+)") do
          table.insert(options.report_file_formats, fn:match("^%s*(.-)%s*$"))
        end
      elseif key == "report-dir" then
        options.report_output_dir = value
      elseif key == "config" then
        options.config_file_path = value
        if central_config and get_fs() and get_fs().file_exists(options.config_file_path) then
          local lok, ler = central_config.load_from_file(options.config_file_path)
          if not lok then
            table.insert(options.parse_errors, "Failed to load " .. options.config_file_path .. ": " .. tostring(ler))
          else
            local to = {}
            for kd, vd in pairs(default_options) do
              to[kd] = vd
            end
            local cv = central_config.get_all()
            if cv.cli_options then
              for kc, vc in pairs(cv.cli_options) do
                if to[kc] ~= nil then
                  to[kc] = vc
                end
              end
            end
            if cv.quality then
              to.quality_level = cv.quality.level or to.quality_level
            end
            if cv.coverage then
              to.coverage_threshold = cv.coverage.threshold or to.coverage_threshold
            end
            to.report_output_dir = cv.reporting and cv.reporting.report_dir or to.report_output_dir
            local psh = options.show_help
            local psv = options.show_version
            options = to
            options.show_help = psh or options.show_help
            options.show_version = psv or options.show_version
            options.specific_paths_to_run = {}
            options.report_file_formats = {}
            options.extra_config_settings = {}
            options.parse_errors = {}
          end
        elseif not central_config then
          table.insert(options.parse_errors, "Central_config not available for --config")
        elseif not (get_fs() and get_fs().file_exists(options.config_file_path)) then
          table.insert(options.parse_errors, "Config file not found: " .. options.config_file_path)
        end
      elseif type(value) == "boolean" and options[key] ~= nil and type(options[key]) == "boolean" then
        options[key] = value
      elseif arg_val:match("^%-%-") then
        options.extra_config_settings[key] = value
      else
        if arg_val:match("^%-") then
          table.insert(options.parse_errors, "Unknown option: " .. arg_val)
        else
          table.insert(options.specific_paths_to_run, arg_val)
        end
      end
    else
      table.insert(options.specific_paths_to_run, arg_val)
    end
    i = i + (consumed_next and 2 or 1)
  end
  local proc_paths = {}
  local dir_set = false
  if #options.specific_paths_to_run > 0 then
    for _, pa in ipairs(options.specific_paths_to_run) do
      if not dir_set and get_fs() then
        local isd_ok, isd = pcall(get_fs().is_directory, pa)
        if isd_ok and isd then
          options.base_test_dir = pa
          dir_set = true
        else
          table.insert(proc_paths, pa)
        end
      else
        table.insert(proc_paths, pa)
      end
    end
    options.specific_paths_to_run = proc_paths
  end
  if #options.specific_paths_to_run == 0 and not dir_set then
    options.base_test_dir = options.base_test_dir or default_options.base_test_dir
  end
  return options
end

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
    logger.info(string.format("Time: %.4f seconds", elapsed_time)) -- Using .4f
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
    logger.info("  Passes:           " .. pcg .. t_passes .. pcn)
    logger.info("  Failures:         " .. (t_errors > 0 and pcr or pcn) .. t_errors .. pcn)
    logger.info("  Skipped:          " .. pcy .. t_skipped .. pcn)
    logger.info("  Total Tests Run:  " .. t_total)
    logger.info(string.format("  Total Time:       %.4f seconds", elapsed_time)) -- Using .4f
    logger.info(string.rep("-", 40))
    if overall_success then
      logger.info(pcg .. pbold .. "All tests passed successfully!" .. pcn)
    else
      logger.info(pcr .. pbold .. "Some tests failed or errors occurred." .. pcn)
    end
  end
end

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
  print("[CLI_RUN_DIAG] Check before setting log level: options.verbose = " .. tostring(options.verbose))
  local temp_log_mod_check = get_logging()
  print(
    "[CLI_RUN_DIAG] Check before setting log level: get_logging() is nil? = " .. tostring(temp_log_mod_check == nil)
  )
  if temp_log_mod_check then
    print(
      "[CLI_RUN_DIAG] Check before setting log level: type of get_logging().set_level = "
        .. tostring(type(temp_log_mod_check.set_level))
    )
  end

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
          get_logger().error("auto_save_reports failed", { error = rer })
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
    ignore = { "node_modules", ".git" },
    debounce = 500,
    clear_console = true,
  })
  runner_module.configure({
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
  return true
end

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
  return true
end

return M
