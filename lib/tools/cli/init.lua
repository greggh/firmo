--- Command Line Interface (CLI) Module for Firmo
---
--- Provides a comprehensive command line interface for the Firmo testing framework,
--- handling argument parsing, command execution, and user interaction. The module
--- supports various testing modes (normal, watch, interactive) and integrates with
--- other framework components.
---
--- Features:
--- - Command argument parsing (`parse_args`).
--- - Help display (`show_help`).
--- - Core test execution (`run`).
--- - Watch mode (`watch`).
--- - Interactive mode (`interactive`).
--- - Report generation trigger (`report`).
--- - Integration with core modules (config, runner, coverage, etc.).
---
--- @module lib.tools.cli
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

---@class CLI The public API of the CLI module.
---@field _VERSION string Version of the CLI module.
---@field version string Version string from `lib.core.version` (read-only).
---@field parse_args fun(args?: table): CommandLineOptions Parses command line arguments into a structured options table.
---@field show_help fun(): nil Displays help information to the console. (Note: Implemented but not exported on `M`).
---@field run fun(args?: table): boolean Executes tests based on parsed command line arguments. Main entry point. Returns overall success.
---@field watch fun(options: CommandLineOptions): boolean Runs tests in watch mode. Returns success (usually doesn't return if successful).
---@field interactive fun(options: CommandLineOptions): boolean Runs tests in interactive mode. Returns success (usually doesn't return if successful).
---@field report fun(options: CommandLineOptions): boolean Generates reports based on options. Returns success.

local M = {}

--- Module version
M._VERSION = "1.0.0"

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
    return logging.get_logger("CLI")
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

-- Load required modules
local central_config, coverage_module, quality_module, watcher_module, interactive_module, parallel_module, runner_module, discover_module, version_module

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
  ---@diagnostic disable-next-line: need-check-nil
  M.version = version_module.string
end

--- Command line options for test execution
---@class CommandLineOptions
---@field pattern string|nil Lua pattern to filter tests/files by name (e.g., "core").
---@field dir string Directory to search for tests (default "tests").
---@field files string[] List of specific test files/directories provided on command line.
---@field coverage boolean Enable code coverage tracking (`--coverage` or `-c`).
---@field report boolean Generate reports after test run (`--report` or `-r`).
---@field watch boolean Enable watch mode (`--watch` or `-w`).
---@field interactive boolean Enable interactive mode (`--interactive` or `-i`).
---@field verbose boolean Enable verbose output (`--verbose` or `-v`).
---@field quality boolean Enable quality validation (`--quality` or `-q`).
---@field parallel boolean Enable parallel test execution (`--parallel` or `-p`).
---@field help boolean Show help message (`--help` or `-h`).
---@field version boolean Show version information (`--version` or `-V`).
---@field format string Console output format ("default", "dot", "summary", etc.).
---@field report_format string|nil Format for generated reports (e.g., "html", "junit").
---@field quality_level number Quality validation level (1-5, default 1).

-- Default options
local default_options = {
  pattern = nil,
  dir = "tests",
  files = {},
  coverage = false,
  report = false,
  watch = false,
  interactive = false,
  version = false,
  verbose = false,
  quality = false,
  parallel = false,
  help = false,
  format = "default",
  report_format = nil,
  quality_level = 1,
}

--- Parse command line arguments
--- Parses command line arguments into a structured options table.
--- Handles flags (e.g., `--coverage`), options with values (e.g., `--pattern=foo`),
--- key-value pairs (`--key=value`), and positional file/directory arguments.
---@param args? table Optional array of argument strings (defaults to Lua's global `arg` table).
---@return CommandLineOptions options A table containing parsed options, merged with defaults.
function M.parse_args(args)
  args = args or arg or {}

  -- Clone default options
  local options = {}
  for k, v in pairs(default_options) do
    options[k] = v
  end

  local i = 1
  local files = {}

  while i <= #args do
    local arg = args[i]

    -- Handle flags and options
    if arg:match("^%-") then
      -- Convert flags to option keys
      local key = arg:match("^%-%-(.+)") or arg:match("^%-(.+)")

      -- Handle special cases
      if key == "pattern" and args[i + 1] then
        options.pattern = args[i + 1]
        i = i + 2
      elseif key == "h" or key == "help" then
        options.help = true
        i = i + 1
      elseif key == "p" or key == "parallel" then
        options.parallel = true
        i = i + 1
      elseif key == "w" or key == "watch" then
        options.watch = true
        i = i + 1
      elseif key == "i" or key == "interactive" then
        options.interactive = true
        i = i + 1
      elseif key == "c" or key == "coverage" then
        options.coverage = true
        i = i + 1
      elseif key == "q" or key == "quality" then
        options.quality = true
        i = i + 1
      elseif key == "quality-level" and args[i + 1] then
        options.quality_level = tonumber(args[i + 1]) or 1
        i = i + 2
      elseif key == "V" or key == "version" then
        options.version = true
        i = i + 1
      elseif key == "v" or key == "verbose" then
        options.verbose = true
        i = i + 1
      elseif key == "r" or key == "report" then
        options.report = true
        i = i + 1
      elseif key == "format" and args[i + 1] then
        options.format = args[i + 1]
        i = i + 2
      elseif key == "report-format" and args[i + 1] then
        options.report_format = args[i + 1]
        i = i + 2
      elseif key == "config" and args[i + 1] then
        -- Load the specified config file if central_config is available
        if central_config then
          local config_path = args[i + 1]
          local success, err = central_config.load_from_file(config_path)

          if not success then
            get_logger().warn("Failed to load config file", {
              path = config_path,
              error = err and get_error_handler().format_error(err) or "unknown error",
            })
          else
            get_logger().info("Loaded configuration from " .. config_path)
          end
        end

        i = i + 2
      elseif key == "create-config" then
        -- Create a default config file
        if central_config and central_config.save_to_file then
          central_config.save_to_file()
          os.exit(0)
        else
          get_logger().error("Cannot create config file - central_config module not available")
          os.exit(1)
        end

        i = i + 1
      else
        -- Handle key=value pattern
        local k, v = arg:match("^%-%-(.+)=(.+)")

        if k and v then
          -- Set option with value
          if k == "pattern" then
            options.pattern = v
          elseif k == "format" then
            options.format = v
          elseif k == "report-format" then
            options.report_format = v
          elseif k == "quality-level" then
            options.quality_level = tonumber(v) or 1
          elseif central_config then
            -- Send unknown options to central_config if available
            central_config.set(k, v)
          end
        else
          -- Boolean flag
          options[key] = true
        end

        i = i + 1
      end
    else
      -- Add file or directory to list
      table.insert(files, arg)
      i = i + 1
    end
  end

  -- If files were specified, use them instead of default directory
  if #files > 0 then
    -- Check if any of the files are directories
    local dirs = {}
    local file_list = {}

    for _, file in ipairs(files) do
      -- Try to detect if it's a directory
      local success, is_dir = pcall(function()
        return get_fs().is_directory(file)
      end)

      if success and is_dir then
        table.insert(dirs, file)
      else
        table.insert(file_list, file)
      end
    end

    -- Use the first directory as the test directory
    if #dirs > 0 then
      options.dir = dirs[1]
    end

    -- Use the file list
    options.files = file_list
  end

  return options
end

--- Displays help information for the command line interface to the console.
---@return nil
function M.show_help()
  print("firmo test runner - Enhanced Lua test framework")
  print("")
  print("Usage: lua test.lua [options] [files/directories]")
  print("")
  print("Options:")
  print("  -h, --help                  Show this help message")
  print("  -V, --version               Show version")
  print("  -c, --coverage              Enable code coverage tracking")
  print("  -w, --watch                 Watch files for changes and rerun tests")
  print("  -i, --interactive           Run tests in interactive mode")
  print("  -p, --parallel              Run tests in parallel")
  print("  -q, --quality               Enable quality validation")
  print("  --quality-level=LEVEL       Set quality validation level (1-3)")
  print("  -v, --verbose               Show verbose output")
  print("  -r, --report                Generate test and coverage reports")
  print("  --pattern=PATTERN           Only run tests matching the pattern")
  print("  --format=FORMAT             Set output format (dot, summary, detailed)")
  print("  --report-format=FORMAT      Set report format (html, junit, cobertura)")
  print("")
  print("Examples:")
  print("  lua test.lua tests/                     Run all tests in the tests directory")
  print("  lua test.lua --coverage tests/          Run tests with coverage tracking")
  print("  lua test.lua --pattern=\"core\" tests/    Run tests with names matching 'core'")
  print("  lua test.lua --watch tests/             Run tests and watch for changes")
  print("  lua test.lua tests/unit/ tests/file.lua Run specified tests")
end

--- Main entry point for running tests via the CLI.
--- Parses arguments, shows help/version if requested, configures modules,
--- and delegates execution to the appropriate mode (run, watch, interactive).
---@param args? table Optional array of command line argument strings (defaults to global `arg`).
---@return boolean success Overall success status of the test run (`true` if all tests passed, `false` otherwise or if execution failed).
function M.run(args)
  -- Load required modules
  load_modules()

  -- Parse arguments
  local options = M.parse_args(args)

  -- Show help if requested
  if options.help then
    M.show_help()
    return true
  end

  -- Show version if requested
  if options.version then
    print("firmo - Version " .. M.version)
    return true
  end

  -- Apply configuration from central_config
  if central_config then
    -- Apply config to modules
    if coverage_module and options.coverage then
      coverage_module.init({
        enabled = true,
        report_format = options.report_format or central_config.get("coverage.report_format") or "html",
      })
    end

    if quality_module and options.quality then
      quality_module.init({
        level = options.quality_level or central_config.get("quality.level") or 1,
      })
    end
  end

  -- Handle watch mode
  if options.watch then
    return M.watch(options)
  end

  -- Handle interactive mode
  if options.interactive then
    return M.interactive(options)
  end

  -- Configure test runner if available
  if runner_module then
    -- Configure runner based on CLI options
    runner_module.configure({
      format = {
        dot_mode = options.format == "dot",
        summary_only = options.format == "summary",
        compact = options.format == "compact",
        show_trace = options.format == "detailed",
        use_color = options.format ~= "plain",
      },
      parallel = options.parallel,
      coverage = options.coverage,
      verbose = options.verbose,
      timeout = 30000, -- Default timeout
    })
  else
    get_logger().warn("Runner module not available", {
      message = "Using fallback runner - not all features may be available",
      action = "continuing with limited functionality",
    })
  end

  -- Run test files
  local success = true

  if #options.files > 0 then
    -- Run specific files using the runner module if available
    if runner_module then
      success = runner_module.run_tests(options.files, {
        parallel = options.parallel,
        coverage = options.coverage,
      })
    else
      -- Fallback without runner module - limited functionality
      get_logger().warn("Running tests without runner module", {
        file_count = #options.files,
        message = "Limited functionality available",
      })

      for _, file in ipairs(options.files) do
        get_logger().info("Running test file: " .. file)
        success = false -- Without the runner, we can't know if tests passed
      end
    end
  else
    -- Run all discovered tests
    if discover_module and runner_module then
      success = runner_module.run_discovered(options.dir, options.pattern)
    else
      get_logger().error("Cannot run discovered tests", {
        reason = "Required modules not available",
        runner_available = runner_module ~= nil,
        discover_available = discover_module ~= nil,
      })
      success = false
    end
  end

  -- Generate reports if requested
  if options.report then
    M.report(options)
  end

  return success
end

--- Runs tests in watch mode using the `lib.tools.watcher` module.
--- Monitors specified directories/files and re-runs tests on changes.
--- Requires `watcher` and `runner` modules to be available.
---@param options CommandLineOptions Parsed command line options.
---@return boolean success `false` if required modules are missing, otherwise this function typically doesn't return as the watcher takes over.
function M.watch(options)
  -- Check if watcher module is available
  if not watcher_module then
    get_logger().error("Watch mode not available", {
      reason = "Required module not found",
      component = "watcher",
      action = "exiting with error",
    })
    print("Error: Watch mode not available. Make sure lib/tools/watcher.lua exists.")
    return false
  end

  -- Check if runner module is available
  if not runner_module then
    get_logger().error("Watch mode requires runner module", {
      reason = "Required module not found",
      component = "runner",
      action = "exiting with error",
    })
    print("Error: Watch mode requires runner module. Make sure lib/core/runner.lua exists.")
    return false
  end

  -- Configure watcher
  watcher_module.configure({
    dirs = { options.dir },
    ignore = { "node_modules", ".git", "coverage-reports" },
    debounce = 500,
    clear_console = true,
  })

  -- Configure runner
  runner_module.configure({
    format = {
      dot_mode = options.format == "dot",
      summary_only = options.format == "summary",
      compact = options.format == "compact",
      show_trace = options.format == "detailed",
      use_color = options.format ~= "plain",
    },
    parallel = options.parallel,
    coverage = options.coverage,
    verbose = options.verbose,
  })

  -- Watch for changes
  watcher_module.watch(function(changed_files)
    get_logger().info("Files changed, rerunning tests", {
      files = changed_files,
    })

    -- Run relevant tests
    if #options.files > 0 then
      -- Run specific files
      return runner_module.run_tests(options.files, {
        parallel = options.parallel,
        coverage = options.coverage,
      })
    else
      -- Run all discovered tests
      return runner_module.run_discovered(options.dir, options.pattern)
    end

    return true
  end)

  -- This should not return as watcher will keep running
  return true
end

--- Runs tests in interactive mode using the `lib.tools.interactive` module.
--- Provides a TUI for selecting and running tests.
--- Requires `interactive` module to be available.
---@param options CommandLineOptions Parsed command line options.
---@return boolean success `false` if the interactive module is missing, otherwise this function typically doesn't return as the interactive mode takes over.
function M.interactive(options)
  -- Check if interactive module is available
  if not interactive_module then
    get_logger().error("Interactive mode not available", {
      reason = "Required module not found",
      component = "interactive",
      action = "exiting with error",
    })
    print("Error: Interactive mode not available. Make sure lib/tools/interactive.lua exists.")
    return false
  end

  -- Configure interactive mode
  interactive_module.configure({
    test_dir = options.dir,
    coverage = options.coverage,
    quality = options.quality,
  })

  -- Start interactive mode
  interactive_module.start()

  -- This should not return as interactive mode will keep running
  return true
end

--- Triggers the generation of reports based on CLI options.
--- Calls `report()` methods on `coverage` and `quality` modules if available and enabled.
---@param options CommandLineOptions Parsed command line options (uses `coverage`, `quality`, `report_format`).
---@return boolean success `true` if all requested reports were generated successfully (or if no reports were requested), `false` otherwise.
---@throws table If coverage/quality module interaction fails critically (though handled by `error_handler.try`).
function M.report(options)
  get_logger().info("Generating reports", {
    coverage = options.coverage,
    format = options.report_format or "html",
  })

  -- Generate coverage report if enabled
  if options.coverage and coverage_module then
    local format = options.report_format or "html"

    local success, err = get_error_handler().try(function()
      return coverage_module.report(format)
    end)

    if not success then
      get_logger().error("Failed to generate coverage report: " .. get_error_handler().format_error(err))
      return false
    end
  end

  -- Generate quality report if enabled
  if options.quality and quality_module then
    local success, err = get_error_handler().try(function()
      return quality_module.report()
    end)

    if not success then
      get_logger().error("Failed to generate quality report: " .. get_error_handler().format_error(err))
      return false
    end
  end

  return true
end

-- Return the module
return M
