---@class CLI
---@field _VERSION string Version of the CLI module
---@field parse_args fun(args?: table): table Parse command line arguments into structured options
---@field show_help fun(): nil Display help information about available commands and options
---@field run fun(args?: table): boolean Run tests from command line with specified options
---@field watch fun(options: table): boolean Run tests in watch mode for continuous testing
---@field interactive fun(options: table): boolean Run tests in interactive mode with TUI interface
---@field report fun(options: table): boolean Generate reports in various formats
---@field configure fun(options: table): CLI Configure CLI behavior and defaults
---@field register_command fun(name: string, handler: function, help: string): boolean Register a custom command
---@field process_command fun(command: string, args: table): boolean Process a specific command
---@field get_supported_options fun(): table Get list of all supported command line options
---@field colorize fun(text: string, color: string): string Apply ANSI color codes to text
---@field format_error fun(err: table|string): string Format error messages for display
---@field get_version fun(): string Get CLI version information
---@field validate_args fun(args: table, schema: table): boolean, string? Validate arguments against schema

--[[
Command Line Interface (CLI) Module for Firmo

Provides a comprehensive command line interface for the Firmo testing framework,
handling argument parsing, command execution, and user interaction. The module
supports various testing modes (normal, watch, interactive) and integrates with
all framework components through a unified interface.

Features:
- Command argument parsing with validation
- Help and documentation display
- Watch mode for continuous testing
- Interactive TUI for guided test execution
- Report generation in multiple formats
- Color terminal output with fallback
- Extensible command registration
]]

local M = {}

-- Load required modules
---@type ErrorHandler
local error_handler = require("lib.tools.error_handler")
---@type Logging
local logging = require("lib.tools.logging")
---@type Logger
local logger = logging.get_logger("CLI")

--- Safely require a module without raising an error if it doesn't exist
---@param name string The name of the module to require
---@return table|nil The loaded module or nil if it couldn't be loaded
local function try_require(name)
  local success, mod = pcall(require, name)
  if success then return mod end
  return nil
end

-- Optional modules
local central_config = try_require("lib.core.central_config")
local coverage_module = try_require("lib.coverage")
local quality_module = try_require("lib.quality")
local watcher_module = try_require("lib.tools.watcher")
local interactive_module = try_require("lib.tools.interactive")
local parallel_module = try_require("lib.tools.parallel")
local runner_module = try_require("lib.core.runner")
local discover_module = try_require("lib.tools.discover")

--- Command line options for test execution
---@class CommandLineOptions
---@field pattern string|nil Pattern to filter test files
---@field dir string Directory to search for test files
---@field files table[] List of specific test files to run
---@field coverage boolean Whether to track code coverage
---@field report boolean Whether to generate reports
---@field watch boolean Whether to run in watch mode
---@field interactive boolean Whether to run in interactive mode
---@field verbose boolean Whether to show verbose output
---@field quality boolean Whether to run quality validation
---@field parallel boolean Whether to run tests in parallel
---@field help boolean Whether to show help information
---@field format string Output format (default, dot, summary, etc)
---@field report_format string|nil Format for coverage report
---@field quality_level number Quality validation level (1-3)

-- Default options
local default_options = {
  pattern = nil,
  dir = "tests",
  files = {},
  coverage = false,
  report = false,
  watch = false,
  interactive = false,
  verbose = false,
  quality = false,
  parallel = false,
  help = false,
  format = "default",
  report_format = nil,
  quality_level = 1,
}

--- Parse command line arguments
---@param args? table Command line arguments (defaults to arg global)
---@return table Parsed options
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
      if key == "pattern" and args[i+1] then
        options.pattern = args[i+1]
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
      elseif key == "quality-level" and args[i+1] then
        options.quality_level = tonumber(args[i+1]) or 1
        i = i + 2
      elseif key == "v" or key == "verbose" then
        options.verbose = true
        i = i + 1
      elseif key == "r" or key == "report" then
        options.report = true
        i = i + 1
      elseif key == "format" and args[i+1] then
        options.format = args[i+1]
        i = i + 2
      elseif key == "report-format" and args[i+1] then
        options.report_format = args[i+1]
        i = i + 2
      elseif key == "config" and args[i+1] then
        -- Load the specified config file if central_config is available
        if central_config then
          local config_path = args[i+1]
          local success, err = central_config.load_from_file(config_path)
          
          if not success then
            logger.warn("Failed to load config file", {
              path = config_path,
              error = err and error_handler.format_error(err) or "unknown error"
            })
          else
            logger.info("Loaded configuration from " .. config_path)
          end
        end
        
        i = i + 2
      elseif key == "create-config" then
        -- Create a default config file
        if central_config and central_config.save_to_file then
          central_config.save_to_file()
          os.exit(0)
        else
          logger.error("Cannot create config file - central_config module not available")
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
        local fs = require("lib.tools.filesystem")
        return fs.is_directory(file)
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

--- Display help information for command line usage
---@return nil
function M.show_help()
  print("firmo test runner - Enhanced Lua test framework")
  print("")
  print("Usage: lua test.lua [options] [files/directories]")
  print("")
  print("Options:")
  print("  -h, --help                  Show this help message")
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

--- Run tests from command line with provided arguments
---@param args? table[] Command line arguments (defaults to the global 'arg' variable)
---@return boolean success Whether all tests passed successfully
function M.run(args)
  -- Parse arguments
  local options = M.parse_args(args)
  
  -- Show help if requested
  if options.help then
    M.show_help()
    return true
  end
  
  -- Apply configuration from central_config
  if central_config then
    -- Apply config to modules
    if coverage_module and options.coverage then
      coverage_module.init({
        enabled = true,
        report_format = options.report_format or central_config.get("coverage.report_format") or "html"
      })
    end
    
    if quality_module and options.quality then
      quality_module.init({
        level = options.quality_level or central_config.get("quality.level") or 1
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
        use_color = options.format ~= "plain"
      },
      parallel = options.parallel,
      coverage = options.coverage,
      verbose = options.verbose,
      timeout = 30000 -- Default timeout
    })
  else
    logger.warn("Runner module not available", {
      message = "Using fallback runner - not all features may be available",
      action = "continuing with limited functionality"
    })
  end
  
  -- Run test files
  local success = true
  
  if #options.files > 0 then
    -- Run specific files using the runner module if available
    if runner_module then
      success = runner_module.run_tests(options.files, {
        parallel = options.parallel,
        coverage = options.coverage
      })
    else
      -- Fallback without runner module - limited functionality
      logger.warn("Running tests without runner module", {
        file_count = #options.files,
        message = "Limited functionality available"
      })
      
      for _, file in ipairs(options.files) do
        logger.info("Running test file: " .. file)
        success = false -- Without the runner, we can't know if tests passed
      end
    end
  else
    -- Run all discovered tests
    if discover_module and runner_module then
      success = runner_module.run_discovered(options.dir, options.pattern)
    else
      logger.error("Cannot run discovered tests", {
        reason = "Required modules not available",
        runner_available = runner_module ~= nil,
        discover_available = discover_module ~= nil
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

--- Run tests in watch mode, automatically re-running when files change
---@param options table Configuration options for watch mode including directories to watch
---@return boolean success Whether watch mode was successfully started
function M.watch(options)
  -- Check if watcher module is available
  if not watcher_module then
    logger.error("Watch mode not available", {
      reason = "Required module not found",
      component = "watcher",
      action = "exiting with error",
    })
    print("Error: Watch mode not available. Make sure lib/tools/watcher.lua exists.")
    return false
  end
  
  -- Check if runner module is available
  if not runner_module then
    logger.error("Watch mode requires runner module", {
      reason = "Required module not found",
      component = "runner",
      action = "exiting with error",
    })
    print("Error: Watch mode requires runner module. Make sure lib/core/runner.lua exists.")
    return false
  end
  
  -- Configure watcher
  watcher_module.configure({
    dirs = {options.dir},
    ignore = {"node_modules", ".git", "coverage-reports"},
    debounce = 500,
    clear_console = true
  })
  
  -- Configure runner
  runner_module.configure({
    format = {
      dot_mode = options.format == "dot",
      summary_only = options.format == "summary",
      compact = options.format == "compact",
      show_trace = options.format == "detailed",
      use_color = options.format ~= "plain"
    },
    parallel = options.parallel,
    coverage = options.coverage,
    verbose = options.verbose
  })
  
  -- Watch for changes
  watcher_module.watch(function(changed_files)
    logger.info("Files changed, rerunning tests", {
      files = changed_files
    })
    
    -- Run relevant tests
    if #options.files > 0 then
      -- Run specific files
      return runner_module.run_tests(options.files, {
        parallel = options.parallel,
        coverage = options.coverage
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

--- Run tests in interactive mode with a command prompt interface
---@param options table Configuration options for interactive mode
---@return boolean success Whether interactive mode was successfully started
function M.interactive(options)
  -- Check if interactive module is available
  if not interactive_module then
    logger.error("Interactive mode not available", {
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
    quality = options.quality
  })
  
  -- Start interactive mode
  interactive_module.start()
  
  -- This should not return as interactive mode will keep running
  return true
end

--- Generate test reports (coverage, quality) based on configuration options
---@param options table Options for report generation including format
---@field options.coverage boolean Whether to generate coverage reports
---@field options.quality boolean Whether to generate quality reports
---@field options.report_format string|nil Format for coverage report output
---@return boolean success Whether reports were successfully generated
function M.report(options)
  logger.info("Generating reports", {
    coverage = options.coverage,
    format = options.report_format or "html"
  })
  
  -- Generate coverage report if enabled
  if options.coverage and coverage_module then
    local format = options.report_format or "html"
    
    local success, err = error_handler.try(function()
      return coverage_module.report(format)
    end)
    
    if not success then
      logger.error("Failed to generate coverage report: " .. error_handler.format_error(err))
      return false
    end
  end
  
  -- Generate quality report if enabled
  if options.quality and quality_module then
    local success, err = error_handler.try(function()
      return quality_module.report()
    end)
    
    if not success then
      logger.error("Failed to generate quality report: " .. error_handler.format_error(err))
      return false
    end
  end
  
  return true
end

-- Return the module
return M