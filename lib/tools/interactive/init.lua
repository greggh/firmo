-- Interactive CLI module for firmo
-- Provides an interactive command-line interface for the test framework

---@class interactive_module
---@field _VERSION string Module version
---@field init fun(options?: {history_file?: string, prompt?: string, max_history?: number, colors?: boolean, auto_complete?: boolean, enable_debugging?: boolean, silent?: boolean}): interactive_module Initialize the interactive CLI with configuration options
---@field start fun(): boolean Start the interactive CLI session
---@field stop fun(): boolean Stop the interactive CLI session
---@field run_command fun(command: string): boolean|nil, string? Run a CLI command
---@field parse_command fun(input: string): {command: string, args: string[]} Parse a command string into command and arguments
---@field configure fun(options?: table): interactive_module Configure the interactive CLI
---@field load_history fun(file_path?: string): boolean|nil, string? Load command history from a file
---@field save_history fun(file_path?: string): boolean|nil, string? Save command history to a file
---@field add_to_history fun(command: string): boolean Add a command to the history
---@field get_history fun(): string[] Get the command history
---@field register_command fun(name: string, handler: fun(args: string[]): boolean|string, help_text: string): boolean Register a custom command
---@field unregister_command fun(name: string): boolean Remove a registered command
---@field set_prompt fun(prompt: string): interactive_module Set the command prompt
---@field colorize fun(text: string, color: string): string Apply ANSI color to text
---@field get_registered_commands fun(): table<string, {handler: function, help: string}> Get all registered commands
---@field print fun(text: string, color?: string): nil Print text to the interactive console
---@field clear fun(): nil Clear the console screen
---@field set_completion_handler fun(handler: fun(input: string): string[]): interactive_module Set custom auto-completion handler
---@field handle_tab_completion fun(input: string): string[] Handle tab completion for commands
---@field get_command_help fun(command?: string): string Get help text for commands
---@field process_input fun(input: string): boolean Process user input

local interactive = {}
interactive._VERSION = "1.3.0"

local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

-- Initialize module logger
local logger = logging.get_logger("interactive")

-- Default configuration
local DEFAULT_CONFIG = {
  test_dir = "./tests",
  test_pattern = "*_test.lua",
  watch_mode = false,
  watch_dirs = { "." },
  watch_interval = 1.0,
  exclude_patterns = { "node_modules", "%.git" },
  max_history = 100,
  colorized_output = true,
  prompt_symbol = ">",
  debug = false,
  verbose = false,
}

-- ANSI color codes
local colors = {
  red = string.char(27) .. "[31m",
  green = string.char(27) .. "[32m",
  yellow = string.char(27) .. "[33m",
  blue = string.char(27) .. "[34m",
  magenta = string.char(27) .. "[35m",
  cyan = string.char(27) .. "[36m",
  white = string.char(27) .. "[37m",
  bold = string.char(27) .. "[1m",
  normal = string.char(27) .. "[0m",
}

-- Current state of the interactive CLI
local state = {
  firmo = nil,
  test_dir = DEFAULT_CONFIG.test_dir,
  test_pattern = DEFAULT_CONFIG.test_pattern,
  current_files = {},
  focus_filter = nil,
  tag_filter = nil,
  watch_mode = DEFAULT_CONFIG.watch_mode,
  watch_dirs = {},
  watch_interval = DEFAULT_CONFIG.watch_interval,
  exclude_patterns = {},
  last_command = nil,
  history = {},
  history_pos = 1,
  codefix_enabled = false,
  running = true,
  colorized_output = DEFAULT_CONFIG.colorized_output,
  prompt_symbol = DEFAULT_CONFIG.prompt_symbol,
}

-- Copy default watch dirs and exclude patterns
for _, dir in ipairs(DEFAULT_CONFIG.watch_dirs) do
  table.insert(state.watch_dirs, dir)
end

for _, pattern in ipairs(DEFAULT_CONFIG.exclude_patterns) do
  table.insert(state.exclude_patterns, pattern)
end

-- Lazy loading of central_config to avoid circular dependencies
local _central_config

local function get_central_config()
  if not _central_config then
    -- Use pcall to safely attempt loading central_config
    local success, central_config = pcall(require, "lib.core.central_config")
    if success then
      _central_config = central_config

      -- Register this module with central_config
      _central_config.register_module("interactive", {
        -- Schema
        field_types = {
          test_dir = "string",
          test_pattern = "string",
          watch_mode = "boolean",
          watch_dirs = "table",
          watch_interval = "number",
          exclude_patterns = "table",
          max_history = "number",
          colorized_output = "boolean",
          prompt_symbol = "string",
          debug = "boolean",
          verbose = "boolean",
        },
        field_ranges = {
          watch_interval = { min = 0.1, max = 10 },
          max_history = { min = 10, max = 1000 },
        },
      }, DEFAULT_CONFIG)

      logger.debug("Successfully loaded central_config", {
        module = "interactive",
      })
    else
      logger.debug("Failed to load central_config", {
        error = tostring(central_config),
      })
    end
  end

  return _central_config
end

-- Set up change listener for central configuration
local function register_change_listener()
  local central_config = get_central_config()
  if not central_config then
    logger.debug("Cannot register change listener - central_config not available")
    return false
  end

  -- Register change listener for interactive configuration
  central_config.on_change("interactive", function(path, old_value, new_value)
    logger.debug("Configuration change detected", {
      path = path,
      changed_by = "central_config",
    })

    -- Update local configuration from central_config
    local interactive_config = central_config.get("interactive")
    if interactive_config then
      -- Update basic settings
      for key, value in pairs(interactive_config) do
        -- Special handling for array values
        if key == "watch_dirs" or key == "exclude_patterns" then
          -- Skip arrays, they will be handled separately
        else
          if state[key] ~= nil and state[key] ~= value then
            state[key] = value
            logger.debug("Updated setting from central_config", {
              key = key,
              value = value,
            })
          end
        end
      end

      -- Handle watch_dirs array
      if interactive_config.watch_dirs then
        -- Clear existing watch dirs and copy new ones
        state.watch_dirs = {}
        for _, dir in ipairs(interactive_config.watch_dirs) do
          table.insert(state.watch_dirs, dir)
        end
        logger.debug("Updated watch_dirs from central_config", {
          dir_count = #state.watch_dirs,
        })
      end

      -- Handle exclude_patterns array
      if interactive_config.exclude_patterns then
        -- Clear existing patterns and copy new ones
        state.exclude_patterns = {}
        for _, pattern in ipairs(interactive_config.exclude_patterns) do
          table.insert(state.exclude_patterns, pattern)
        end
        logger.debug("Updated exclude_patterns from central_config", {
          pattern_count = #state.exclude_patterns,
        })
      end

      -- Update logging configuration
      logging.configure_from_options("interactive", {
        debug = interactive_config.debug,
        verbose = interactive_config.verbose,
      })

      logger.debug("Applied configuration changes from central_config")
    end
  end)

  logger.debug("Registered change listener for central configuration")
  return true
end

-- Configure the module
--- Configure the interactive CLI with custom options
---@param options? table Configuration options to override defaults
---@return interactive_module The module instance for method chaining
function interactive.configure(options)
  options = options or {}

  logger.debug("Configuring interactive module", {
    options = options,
  })

  -- Check for central configuration first
  local central_config = get_central_config()
  if central_config then
    -- Get existing central config values
    local interactive_config = central_config.get("interactive")

    -- Apply central configuration (with defaults as fallback)
    if interactive_config then
      logger.debug("Using central_config values for initialization", {
        test_dir = interactive_config.test_dir,
        test_pattern = interactive_config.test_pattern,
        watch_mode = interactive_config.watch_mode,
      })

      -- Apply basic settings
      for key, default_value in pairs(DEFAULT_CONFIG) do
        -- Skip arrays, they will be handled separately
        if key ~= "watch_dirs" and key ~= "exclude_patterns" then
          state[key] = interactive_config[key] ~= nil and interactive_config[key] or default_value
        end
      end

      -- Apply watch_dirs if available
      if interactive_config.watch_dirs then
        state.watch_dirs = {}
        for _, dir in ipairs(interactive_config.watch_dirs) do
          table.insert(state.watch_dirs, dir)
        end
      else
        -- Reset to defaults
        state.watch_dirs = {}
        for _, dir in ipairs(DEFAULT_CONFIG.watch_dirs) do
          table.insert(state.watch_dirs, dir)
        end
      end

      -- Apply exclude_patterns if available
      if interactive_config.exclude_patterns then
        state.exclude_patterns = {}
        for _, pattern in ipairs(interactive_config.exclude_patterns) do
          table.insert(state.exclude_patterns, pattern)
        end
      else
        -- Reset to defaults
        state.exclude_patterns = {}
        for _, pattern in ipairs(DEFAULT_CONFIG.exclude_patterns) do
          table.insert(state.exclude_patterns, pattern)
        end
      end
    else
      logger.debug("No central_config values found, using defaults")
      -- Reset to defaults
      for key, value in pairs(DEFAULT_CONFIG) do
        -- Skip arrays, they will be handled separately
        if key ~= "watch_dirs" and key ~= "exclude_patterns" then
          state[key] = value
        end
      end

      -- Reset watch_dirs to defaults
      state.watch_dirs = {}
      for _, dir in ipairs(DEFAULT_CONFIG.watch_dirs) do
        table.insert(state.watch_dirs, dir)
      end

      -- Reset exclude_patterns to defaults
      state.exclude_patterns = {}
      for _, pattern in ipairs(DEFAULT_CONFIG.exclude_patterns) do
        table.insert(state.exclude_patterns, pattern)
      end
    end

    -- Register change listener if not already done
    register_change_listener()
  else
    logger.debug("central_config not available, using defaults")
    -- Apply defaults for basic settings
    for key, value in pairs(DEFAULT_CONFIG) do
      -- Skip arrays, they will be handled separately
      if key ~= "watch_dirs" and key ~= "exclude_patterns" then
        state[key] = value
      end
    end

    -- Reset watch_dirs to defaults
    state.watch_dirs = {}
    for _, dir in ipairs(DEFAULT_CONFIG.watch_dirs) do
      table.insert(state.watch_dirs, dir)
    end

    -- Reset exclude_patterns to defaults
    state.exclude_patterns = {}
    for _, pattern in ipairs(DEFAULT_CONFIG.exclude_patterns) do
      table.insert(state.exclude_patterns, pattern)
    end
  end

  -- Apply user options (highest priority) and update central config
  for key, value in pairs(options) do
    -- Special handling for watch_dirs and exclude_patterns
    if key == "watch_dirs" then
      if type(value) == "table" then
        -- Replace watch_dirs
        state.watch_dirs = {}
        for _, dir in ipairs(value) do
          table.insert(state.watch_dirs, dir)
        end

        -- Update central_config if available
        if central_config then
          central_config.set("interactive.watch_dirs", value)
        end
      end
    elseif key == "exclude_patterns" then
      if type(value) == "table" then
        -- Replace exclude_patterns
        state.exclude_patterns = {}
        for _, pattern in ipairs(value) do
          table.insert(state.exclude_patterns, pattern)
        end

        -- Update central_config if available
        if central_config then
          central_config.set("interactive.exclude_patterns", value)
        end
      end
    else
      -- Apply basic setting
      if state[key] ~= nil then
        state[key] = value

        -- Update central_config if available
        if central_config then
          central_config.set("interactive." .. key, value)
        end
      end
    end
  end

  -- Configure logging
  logging.configure_from_options("interactive", {
    debug = state.debug,
    verbose = state.verbose,
  })

  logger.debug("Interactive module configuration complete", {
    test_dir = state.test_dir,
    test_pattern = state.test_pattern,
    watch_mode = state.watch_mode,
    watch_dirs_count = #state.watch_dirs,
    exclude_patterns_count = #state.exclude_patterns,
    colorized_output = state.colorized_output,
    using_central_config = central_config ~= nil,
  })

  return interactive
end

-- Initialize the module
interactive.configure()

-- Log module initialization
logger.debug("Interactive CLI module initialized", {
  version = interactive._VERSION,
})

-- Try to load modules with enhanced error handling
local function load_module(name, module_path)
  logger.debug("Attempting to load module", {
    module = name,
    path = module_path,
  })

  -- Try to load the module
  local success, result = error_handler.try(function()
    return require(module_path)
  end)

  if not success then
    -- Don't show errors for these specific modules, which are used differently in the CLI version
    if name == "discover" or name == "runner" then
      logger.debug("Module not available in this context", {
        module = name,
        path = module_path,
      })
    else
      logger.warn("Failed to load module", {
        module = name,
        path = module_path,
        error = error_handler.format_error(result),
      })
    end
  else
    logger.debug("Successfully loaded module", {
      module = name,
      path = module_path,
    })
  end

  return success, result
end

-- These modules are loaded directly in the CLI version but not needed in the library context
local has_discovery, discover = false, nil
local has_runner, runner = false, nil

-- Load internal modules (should exist)
local has_watcher, watcher = load_module("watcher", "lib.tools.watcher")
local has_codefix, codefix = load_module("codefix", "lib.tools.codefix")

-- Print the interactive CLI header with error handling
local function print_header()
  -- Safe screen clearing with error handling
  local success, result = error_handler.try(function()
    io.write("\027[2J\027[H") -- Clear screen
    return true
  end)

  if not success then
    logger.warn("Failed to clear screen", {
      component = "CLI",
      error = error_handler.format_error(result),
    })
    -- Continue without clearing screen
  end

  -- Safe output with error handling
  success, result = error_handler.try(function()
    print(colors.bold .. colors.cyan .. "Firmo Interactive CLI" .. colors.normal)
    print(colors.green .. "Type 'help' for available commands" .. colors.normal)
    print(string.rep("-", 60))
    return true
  end)

  if not success then
    logger.error("Failed to display header", {
      component = "CLI",
      error = error_handler.format_error(result),
    })
    -- Try a simple fallback for header display
    error_handler.try(function()
      print("Firmo Interactive CLI")
      print("Type 'help' for available commands")
      print("---------------------------------------------------------")
      return true
    end)
  end

  -- Safely get current time
  local time_str = "unknown"
  local time_success, time_result = error_handler.try(function()
    return os.date("%H:%M:%S")
  end)

  if time_success then
    time_str = time_result
  end

  logger.info("Interactive CLI header displayed", {
    component = "CLI",
    time = time_str,
  })

  -- Safely check state properties with error handling
  local debug_info = {}
  success, result = error_handler.try(function()
    debug_info = {
      component = "CLI",
      test_dir = state and state.test_dir or "unknown",
      pattern = state and state.test_pattern or "unknown",
      watch_mode = state and (state.watch_mode and "on" or "off") or "unknown",
      focus_filter = state and (state.focus_filter or "none") or "unknown",
      tag_filter = state and (state.tag_filter or "none") or "unknown",
      codefix_enabled = state and (state.codefix_enabled and true or false) or "unknown",
      watch_directories = state and state.watch_dirs and #state.watch_dirs or 0,
      exclude_patterns = state and state.exclude_patterns and #state.exclude_patterns or 0,
      available_tests = state and state.current_files and #state.current_files or 0,
    }
    return debug_info
  end)

  if success then
    logger.debug("Display settings initialized", debug_info)
  else
    logger.warn("Failed to get display settings", {
      component = "CLI",
      error = error_handler.format_error(result),
    })
  end
end

-- Print help information
local function print_help()
  print(colors.bold .. "Available commands:" .. colors.normal)
  print("  help                Show this help message")
  print("  run [file]          Run all tests or a specific test file")
  print("  list                List available test files")
  print("  filter <pattern>    Filter tests by name pattern")
  print("  focus <name>        Focus on specific test (partial name match)")
  print("  tags <tag1,tag2>    Run tests with specific tags")
  print("  watch <on|off>      Toggle watch mode")
  print("  watch-dir <path>    Add directory to watch")
  print("  watch-exclude <pat> Add exclusion pattern for watch")
  print("  codefix <cmd> <dir> Run codefix (check|fix) on directory")
  print("  dir <path>          Set test directory")
  print("  pattern <pat>       Set test file pattern")
  print("  clear               Clear the screen")
  print("  status              Show current settings")
  print("  history             Show command history")
  print("  exit                Exit the interactive CLI")
  print("\n" .. colors.bold .. "Keyboard shortcuts:" .. colors.normal)
  print("  Up/Down             Navigate command history")
  print("  Ctrl+C              Exit interactive mode")
  print(string.rep("-", 60))

  logger.debug("Help information displayed", {
    component = "CLI",
    command_count = 16, -- Count of available commands
    has_keyboard_shortcuts = true,
    available_commands = {
      "help",
      "run",
      "list",
      "filter",
      "focus",
      "tags",
      "watch",
      "watch-dir",
      "watch-exclude",
      "codefix",
      "dir",
      "pattern",
      "clear",
      "status",
      "history",
      "exit",
    },
  })
end

-- Show current state/settings
local function print_status()
  print(colors.bold .. "Current settings:" .. colors.normal)
  print("  Test directory:     " .. state.test_dir)
  print("  Test pattern:       " .. state.test_pattern)
  print("  Focus filter:       " .. (state.focus_filter or "none"))
  print("  Tag filter:         " .. (state.tag_filter or "none"))
  print("  Watch mode:         " .. (state.watch_mode and "enabled" or "disabled"))

  if state.watch_mode then
    print("  Watch directories:  " .. table.concat(state.watch_dirs, ", "))
    print("  Watch interval:     " .. state.watch_interval .. "s")
    print("  Exclude patterns:   " .. table.concat(state.exclude_patterns, ", "))
  end

  print("  Codefix:            " .. (state.codefix_enabled and "enabled" or "disabled"))
  print("  Available tests:    " .. #state.current_files)
  print(string.rep("-", 60))

  logger.debug("Status information displayed", {
    component = "UI",
    test_count = #state.current_files,
    watch_mode = state.watch_mode and "on" or "off",
    focus_filter = state.focus_filter or "none",
    tag_filter = state.tag_filter or "none",
    test_directory = state.test_dir,
    test_pattern = state.test_pattern,
    codefix_enabled = state.codefix_enabled and true or false,
    watch_directories = state.watch_mode and #state.watch_dirs or 0,
    exclude_patterns = state.watch_mode and #state.exclude_patterns or 0,
  })
end

-- List available test files
local function list_test_files()
  if #state.current_files == 0 then
    print(colors.yellow .. "No test files found in " .. state.test_dir .. colors.normal)
    logger.warn("No test files found", {
      directory = state.test_dir,
      pattern = state.test_pattern,
    })
    return
  end

  print(colors.bold .. "Available test files:" .. colors.normal)
  for i, file in ipairs(state.current_files) do
    print("  " .. i .. ". " .. file)
  end
  print(string.rep("-", 60))

  logger.debug("Test files listed", {
    component = "CLI",
    file_count = #state.current_files,
    directory = state.test_dir,
    pattern = state.test_pattern,
    success = #state.current_files > 0,
  })
end

-- Discover test files with comprehensive error handling
local function discover_test_files()
  -- Validate necessary state for test discovery
  if not state then
    local err = error_handler.runtime_error("State not initialized for test discovery", {
      operation = "discover_test_files",
      module = "interactive",
    })
    logger.error("Test discovery failed due to missing state", {
      component = "TestDiscovery",
      error = error_handler.format_error(err),
    })

    -- Safe error display with fallback
    error_handler.try(function()
      print(colors.red .. "Error: Internal state not initialized" .. colors.normal)
      return true
    end)

    return false
  end

  -- Validate test directory and pattern
  if not state.test_dir or type(state.test_dir) ~= "string" then
    local err = error_handler.validation_error("Invalid test directory", {
      operation = "discover_test_files",
      test_dir = state.test_dir,
      test_dir_type = type(state.test_dir),
      module = "interactive",
    })
    logger.error("Test discovery failed due to invalid directory", {
      component = "TestDiscovery",
      error = error_handler.format_error(err),
    })

    -- Safe error display with fallback
    error_handler.try(function()
      print(colors.red .. "Error: Invalid test directory" .. colors.normal)
      return true
    end)

    return false
  end

  if not state.test_pattern or type(state.test_pattern) ~= "string" then
    local err = error_handler.validation_error("Invalid test pattern", {
      operation = "discover_test_files",
      test_pattern = state.test_pattern,
      test_pattern_type = type(state.test_pattern),
      module = "interactive",
    })
    logger.error("Test discovery failed due to invalid pattern", {
      component = "TestDiscovery",
      error = error_handler.format_error(err),
    })

    -- Safe error display with fallback
    error_handler.try(function()
      print(colors.red .. "Error: Invalid test pattern" .. colors.normal)
      return true
    end)

    return false
  end

  -- Verify discovery module is available
  if not has_discovery then
    local err = error_handler.runtime_error("Discovery module not available", {
      operation = "discover_test_files",
      module = "interactive",
      test_dir = state.test_dir,
      test_pattern = state.test_pattern,
    })
    logger.error("Test discovery failed", {
      component = "TestDiscovery",
      error = error_handler.format_error(err),
      error_type = "ModuleNotFound",
      directory = state.test_dir,
      pattern = state.test_pattern,
      attempted_recovery = false,
    })

    -- Safe error display with fallback
    error_handler.try(function()
      print(colors.red .. "Error: Discovery module not available" .. colors.normal)
      return true
    end)

    return false
  end

  -- Initialize current_files if not present
  if not state.current_files then
    state.current_files = {}
  end

  -- Log discovery start
  logger.debug("Discovering test files", {
    component = "TestDiscovery",
    directory = state.test_dir,
    pattern = state.test_pattern,
    existing_files = #state.current_files,
  })

  -- Attempt to discover test files with error handling
  local success, result = error_handler.try(function()
    -- Get timestamp for performance tracking
    local start_time = os.time()

    -- Perform the actual discovery
    local files = discover.find_tests(state.test_dir, state.test_pattern)

    -- Calculate discovery time
    local end_time = os.time()
    local duration = end_time - start_time

    return {
      files = files,
      duration = duration,
    }
  end)

  -- Handle discovery results
  if not success then
    local err = error_handler.runtime_error(
      "Test discovery operation failed",
      {
        operation = "discover_test_files",
        module = "interactive",
        test_dir = state.test_dir,
        test_pattern = state.test_pattern,
      },
      result -- Original error as cause
    )
    logger.error("Test discovery failed with exception", {
      component = "TestDiscovery",
      error = error_handler.format_error(err),
      directory = state.test_dir,
      pattern = state.test_pattern,
      attempted_recovery = false,
    })

    -- Safe error display with fallback
    error_handler.try(function()
      print(colors.red .. "Error: Test discovery failed: " .. error_handler.format_error(result) .. colors.normal)
      return true
    end)

    return false
  end

  -- Process successful discovery results
  if not result.files or type(result.files) ~= "table" then
    local err = error_handler.runtime_error("Discovery returned invalid result", {
      operation = "discover_test_files",
      module = "interactive",
      result_type = type(result.files),
    })
    logger.error("Test discovery failed with invalid result", {
      component = "TestDiscovery",
      error = error_handler.format_error(err),
      directory = state.test_dir,
      pattern = state.test_pattern,
      attempted_recovery = false,
    })

    -- Safe error display with fallback
    error_handler.try(function()
      print(colors.red .. "Error: Test discovery returned invalid result" .. colors.normal)
      return true
    end)

    return false
  end

  -- Update state with discovered files
  state.current_files = result.files

  -- Get timestamp for logging
  local timestamp = "unknown"
  local time_success, time_result = error_handler.try(function()
    return os.date("%H:%M:%S")
  end)

  if time_success then
    timestamp = time_result
  end

  -- Log discovery completion
  logger.debug("Test files discovery completed", {
    component = "TestDiscovery",
    file_count = #state.current_files,
    success = #state.current_files > 0,
    directory = state.test_dir,
    pattern = state.test_pattern,
    timestamp = timestamp,
    duration_seconds = result.duration or 0,
  })

  return #state.current_files > 0
end

-- Run tests with comprehensive error handling
local function run_tests(file_path)
  -- Validate state and dependencies
  if not state then
    local err = error_handler.runtime_error("State not initialized for test execution", {
      operation = "run_tests",
      module = "interactive",
    })
    logger.error("Test execution failed due to missing state", {
      component = "TestRunner",
      error = error_handler.format_error(err),
    })

    -- Safe error display with fallback
    error_handler.try(function()
      print(colors.red .. "Error: Internal state not initialized" .. colors.normal)
      return true
    end)

    return false
  end

  -- Verify runner module is available
  if not has_runner then
    local err = error_handler.runtime_error("Runner module not available", {
      operation = "run_tests",
      module = "interactive",
      file_path = file_path or "all tests",
    })

    logger.error("Test execution failed", {
      component = "TestRunner",
      error = error_handler.format_error(err),
      error_type = "ModuleNotFound",
      file = file_path or "all tests",
      attempted_recovery = false,
    })

    -- Safe error display with fallback
    error_handler.try(function()
      print(colors.red .. "Error: Runner module not available" .. colors.normal)
      return true
    end)

    return false
  end

  -- Verify firmo test framework is available
  if not state.firmo then
    local err = error_handler.runtime_error("Test framework not initialized", {
      operation = "run_tests",
      module = "interactive",
      file_path = file_path or "all tests",
    })

    logger.error("Test execution failed", {
      component = "TestRunner",
      error = error_handler.format_error(err),
      error_type = "FrameworkNotInitialized",
      file = file_path or "all tests",
      attempted_recovery = false,
    })

    -- Safe error display with fallback
    error_handler.try(function()
      print(colors.red .. "Error: Test framework not initialized" .. colors.normal)
      return true
    end)

    return false
  end

  -- Reset firmo state with error handling
  local reset_success, reset_result = error_handler.try(function()
    state.firmo.reset()
    return true
  end)

  if not reset_success then
    local err = error_handler.runtime_error(
      "Failed to reset test environment",
      {
        operation = "run_tests",
        module = "interactive",
        file_path = file_path or "all tests",
      },
      reset_result -- Original error as cause
    )

    logger.error("Test environment reset failed", {
      component = "TestRunner",
      error = error_handler.format_error(err),
      file = file_path or "all tests",
      attempted_recovery = true,
    })

    -- Try to continue despite reset failure
  else
    -- Get timestamp for logging
    local timestamp = "unknown"
    local time_success, time_result = error_handler.try(function()
      return os.date("%H:%M:%S")
    end)

    if time_success then
      timestamp = time_result
    end

    logger.debug("Test environment reset before execution", {
      component = "TestRunner",
      file_path = file_path or "all files",
      focus_filter = state.focus_filter or "none",
      tag_filter = state.tag_filter or "none",
      watch_mode = state.watch_mode and true or false,
      timestamp = timestamp,
    })
  end

  local success = false

  if file_path then
    -- Run single file with error handling

    -- Validate file path
    if type(file_path) ~= "string" or file_path == "" then
      local err = error_handler.validation_error("Invalid file path for test execution", {
        operation = "run_tests",
        module = "interactive",
        file_path = file_path,
        file_path_type = type(file_path),
      })

      logger.error("Test execution failed", {
        component = "TestRunner",
        error = error_handler.format_error(err),
        file = tostring(file_path),
      })

      -- Safe error display with fallback
      error_handler.try(function()
        print(colors.red .. "Error: Invalid file path for test execution" .. colors.normal)
        return true
      end)

      return false
    end

    -- Verify file exists with safe I/O
    local file_exists, file_err = error_handler.safe_io_operation(
      function()
        return fs.file_exists(file_path)
      end,
      file_path,
      {
        operation = "run_tests.check_file",
        module = "interactive",
      }
    )

    if not file_exists then
      local err = error_handler.io_error(
        "Test file not found",
        {
          operation = "run_tests",
          module = "interactive",
          file_path = file_path,
        },
        file_err -- Include underlying error as cause
      )

      logger.error("Test execution failed", {
        component = "TestRunner",
        error = error_handler.format_error(err),
        file = file_path,
      })

      -- Safe error display with fallback
      error_handler.try(function()
        print(colors.red .. "Error: Test file not found: " .. file_path .. colors.normal)
        return true
      end)

      return false
    end

    -- Display running message with error handling
    error_handler.try(function()
      print(colors.cyan .. "Running file: " .. file_path .. colors.normal)
      return true
    end)

    logger.info("Running single test file", {
      file = file_path,
      focus_filter = state.focus_filter or "none",
      tag_filter = state.tag_filter or "none",
    })

    -- Run the single test file with error handling
    local run_success, results = error_handler.try(function()
      return runner.run_file(file_path, state.firmo)
    end)

    if not run_success then
      local err = error_handler.runtime_error(
        "Test file execution failed with exception",
        {
          operation = "run_tests",
          module = "interactive",
          file_path = file_path,
        },
        results -- Original error as cause
      )

      logger.error("Test file execution failed", {
        component = "TestRunner",
        error = error_handler.format_error(err),
        file = file_path,
      })

      -- Safe error display with fallback
      error_handler.try(function()
        print(colors.red .. "Error executing test file: " .. error_handler.format_error(results) .. colors.normal)
        return true
      end)

      return false
    end

    -- Validate results
    if type(results) ~= "table" then
      local err = error_handler.runtime_error("Test runner returned invalid result", {
        operation = "run_tests",
        module = "interactive",
        file_path = file_path,
        result_type = type(results),
      })

      logger.error("Test file execution completed with invalid result", {
        component = "TestRunner",
        error = error_handler.format_error(err),
        file = file_path,
      })

      -- Safe error display with fallback
      error_handler.try(function()
        print(colors.red .. "Error: Test runner returned invalid result" .. colors.normal)
        return true
      end)

      return false
    end

    -- Extract success state
    success = results.success and results.errors == 0

    logger.info("Test run completed", {
      file = file_path,
      success = success,
      errors = results.errors or 0,
      tests = results.total or 0,
      passes = results.passes or 0,
      pending = results.pending or 0,
    })
  else
    -- Run all discovered files with error handling

    -- Check if we need to discover files first
    if not state.current_files or #state.current_files == 0 then
      logger.debug("No test files in state, attempting discovery", {
        component = "TestRunner",
        test_dir = state.test_dir,
        test_pattern = state.test_pattern,
      })

      if not discover_test_files() then
        -- Error messages already handled by discover_test_files

        -- Safe error display with fallback
        error_handler.try(function()
          print(colors.yellow .. "No test files found. Check test directory and pattern." .. colors.normal)
          return true
        end)

        logger.warn("No test files found to run", {
          directory = state.test_dir,
          pattern = state.test_pattern,
        })

        return false
      end
    end

    -- Get file count safely
    local file_count = 0
    error_handler.try(function()
      file_count = #state.current_files
      return true
    end)

    -- Display running message with error handling
    error_handler.try(function()
      print(colors.cyan .. "Running " .. file_count .. " test files..." .. colors.normal)
      return true
    end)

    logger.info("Running multiple test files", {
      file_count = file_count,
      focus_filter = state.focus_filter or "none",
      tag_filter = state.tag_filter or "none",
    })

    -- Run all test files with error handling
    local run_success, run_result = error_handler.try(function()
      return runner.run_all(state.current_files, state.firmo)
    end)

    if not run_success then
      local err = error_handler.runtime_error(
        "Multiple test file execution failed with exception",
        {
          operation = "run_tests",
          module = "interactive",
          file_count = file_count,
        },
        run_result -- Original error as cause
      )

      logger.error("Multiple test file execution failed", {
        component = "TestRunner",
        error = error_handler.format_error(err),
        file_count = file_count,
      })

      -- Safe error display with fallback
      error_handler.try(function()
        print(colors.red .. "Error executing test files: " .. error_handler.format_error(run_result) .. colors.normal)
        return true
      end)

      return false
    end

    -- Process run result
    if type(run_result) == "boolean" then
      success = run_result
    else
      -- If we get a table of results, process it like the single file case
      if type(run_result) == "table" and run_result.success ~= nil then
        success = run_result.success and (run_result.errors or 0) == 0
      else
        success = false
      end
    end

    logger.info("Multiple file test run completed", {
      success = success,
      file_count = file_count,
    })
  end

  return success
end

-- Start watch mode
local function start_watch_mode()
  if not has_watcher then
    print(colors.red .. "Error: Watch module not available" .. colors.normal)
    logger.error("Watch mode initialization failed", {
      error = "Watch module not available",
      component = "WatchMode",
    })
    return false
  end

  if not has_runner then
    print(colors.red .. "Error: Runner module not available" .. colors.normal)
    logger.error("Watch mode initialization failed", {
      error = "Runner module not available",
      component = "WatchMode",
    })
    return false
  end

  print(colors.cyan .. "Starting watch mode..." .. colors.normal)
  print("Watching directories: " .. table.concat(state.watch_dirs, ", "))
  print("Press Enter to return to interactive mode")

  logger.info("Watch mode starting", {
    directories = state.watch_dirs,
    exclude_patterns = state.exclude_patterns,
    check_interval = state.watch_interval,
    component = "WatchMode",
  })

  watcher.set_check_interval(state.watch_interval)
  watcher.init(state.watch_dirs, state.exclude_patterns)

  -- Initial test run
  if #state.current_files == 0 then
    logger.debug("No test files found, discovering tests before watch", {
      component = "WatchMode",
    })
    discover_test_files()
  end

  local last_run_time = os.time()
  local debounce_time = 0.5 -- seconds to wait after changes before running tests
  local last_change_time = 0
  local need_to_run = true

  -- Watch loop
  local watch_running = true

  -- Create a non-blocking input check
  local function check_input()
    local input_available = io.read(0) ~= nil
    if input_available then
      -- Consume the input
      ---@diagnostic disable-next-line: discard-returns
      io.read("*l")
      watch_running = false
      logger.debug("User input detected, exiting watch mode", {
        component = "WatchMode",
      })
    end
    return input_available
  end

  -- Clear terminal
  io.write("\027[2J\027[H")

  -- Initial test run
  logger.debug("Running initial tests in watch mode", {
    component = "WatchMode",
    file_count = #state.current_files,
  })

  state.firmo.reset()
  runner.run_all(state.current_files, state.firmo)

  print(colors.cyan .. "\n--- WATCHING FOR CHANGES (Press Enter to return to interactive mode) ---" .. colors.normal)

  logger.info("Watch mode active", {
    component = "WatchMode",
    status = "waiting for changes",
    directories = state.watch_dirs,
    test_files = #state.current_files,
  })

  while watch_running do
    local current_time = os.time()

    -- Check for file changes
    local changed_files = watcher.check_for_changes()
    if changed_files then
      last_change_time = current_time
      need_to_run = true

      print(colors.yellow .. "\nFile changes detected:" .. colors.normal)
      for _, file in ipairs(changed_files) do
        print("  - " .. file)
      end

      logger.info("File changes detected in watch mode", {
        component = "WatchMode",
        changed_file_count = #changed_files,
        changed_files = changed_files,
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        time_since_last_change = current_time - last_change_time,
        debounce_active = current_time - last_change_time < debounce_time,
        need_to_run = need_to_run,
      })
    end

    -- Run tests if needed and after debounce period
    if need_to_run and current_time - last_change_time >= debounce_time then
      print(colors.cyan .. "\n--- RUNNING TESTS ---" .. colors.normal)
      print(os.date("%Y-%m-%d %H:%M:%S"))

      -- Clear terminal
      io.write("\027[2J\027[H")

      logger.info("Running tests after file changes", {
        component = "WatchMode",
        debounce_time = debounce_time,
        time_since_last_run = current_time - last_run_time,
        file_count = #state.current_files,
        filter_active = state.focus_filter ~= nil or state.tag_filter ~= nil,
        focus_filter = state.focus_filter or "none",
        tag_filter = state.tag_filter or "none",
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        execution_id = os.time(), -- Add a unique identifier for tracing test runs
        batch = os.time() - state.session_start_time, -- How many batches into the session
      })

      state.firmo.reset()
      runner.run_all(state.current_files, state.firmo)
      last_run_time = current_time
      need_to_run = false

      print(
        colors.cyan .. "\n--- WATCHING FOR CHANGES (Press Enter to return to interactive mode) ---" .. colors.normal
      )

      logger.info("Watch mode resumed", {
        component = "WatchMode",
        status = "waiting for changes",
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
      })
    end

    -- Check for input to exit watch mode
    if check_input() then
      break
    end

    -- Small sleep to prevent CPU hogging
    os.execute("sleep 0.1")
  end

  logger.info("Watch mode exited", {
    component = "WatchMode",
  })

  return true
end

-- Run codefix operations
local function run_codefix(command, target)
  if not has_codefix then
    print(colors.red .. "Error: Codefix module not available" .. colors.normal)
    logger.error("Codefix operation failed", {
      error = "Codefix module not available",
      component = "CodeFix",
    })
    return false
  end

  if not command or not target then
    print(colors.yellow .. "Usage: codefix <check|fix> <directory>" .. colors.normal)
    logger.warn("Invalid codefix command", {
      component = "CodeFix",
      command = command or "nil",
      target = target or "nil",
      reason = "Missing required parameters",
    })
    return false
  end

  -- Initialize codefix if needed
  if not state.codefix_enabled then
    logger.debug("Initializing codefix module", {
      component = "CodeFix",
      options = {
        enabled = true,
        verbose = true,
      },
    })

    codefix.init({
      enabled = true,
      verbose = true,
    })
    state.codefix_enabled = true
  end

  print(colors.cyan .. "Running codefix: " .. command .. " " .. target .. colors.normal)

  logger.info("Running codefix operation", {
    component = "CodeFix",
    command = command,
    target = target,
    options = {
      enabled = true,
      verbose = true,
    },
  })

  local codefix_args = { command, target }
  local success = codefix.run_cli(codefix_args)

  if success then
    print(colors.green .. "Codefix completed successfully" .. colors.normal)
    logger.info("Codefix operation completed", {
      component = "CodeFix",
      status = "success",
      command = command,
      target = target,
    })
  else
    print(colors.red .. "Codefix failed" .. colors.normal)
    logger.warn("Codefix operation failed", {
      component = "CodeFix",
      status = "failed",
      command = command,
      target = target,
    })
  end

  return success
end

-- Add command to history
local function add_to_history(command)
  -- Don't add empty commands or duplicates of the last command
  if command == "" or (state.history[#state.history] == command) then
    if logger.is_debug_enabled() then
      logger.debug("Skipping history addition", {
        component = "CLI",
        reason = command == "" and "empty command" or "duplicate command",
        command = command,
      })
    end
    return
  end

  table.insert(state.history, command)
  state.history_pos = #state.history + 1

  -- Limit history size
  if #state.history > 100 then
    logger.debug("Trimming command history", {
      component = "CLI",
      history_size = #state.history,
      removed_command = state.history[1],
    })
    table.remove(state.history, 1)
  end

  logger.debug("Command added to history", {
    component = "CLI",
    command = command,
    history_size = #state.history,
    history_position = state.history_pos,
  })
end

-- Process a command
local function process_command(input)
  -- Add to history
  add_to_history(input)

  -- Split into command and arguments
  local command, args = input:match("^(%S+)%s*(.*)$")
  if not command then
    return false
  end

  command = command:lower()
  state.last_command = command

  logger.debug("Command parsed", {
    component = "CLI",
    command = command,
    args = args or "",
    history_position = state.history_pos,
    related_to_previous = command == state.last_command,
    timestamp = os.date("%H:%M:%S"),
  })

  if command == "help" or command == "h" then
    print_help()
    return true
  elseif command == "exit" or command == "quit" or command == "q" then
    state.running = false
    return true
  elseif command == "clear" or command == "cls" then
    print_header()
    return true
  elseif command == "status" then
    print_status()
    return true
  elseif command == "list" or command == "ls" then
    list_test_files()
    return true
  elseif command == "run" or command == "r" then
    if args and args ~= "" then
      return run_tests(args)
    else
      return run_tests()
    end
  elseif command == "dir" or command == "directory" then
    if not args or args == "" then
      print(colors.yellow .. "Current test directory: " .. state.test_dir .. colors.normal)
      return true
    end

    state.test_dir = args
    print(colors.green .. "Test directory set to: " .. state.test_dir .. colors.normal)

    -- Update central_config if available
    local central_config = get_central_config()
    if central_config then
      central_config.set("interactive.test_dir", args)
      logger.debug("Updated test_dir in central_config", { test_dir = args })
    end

    -- Rediscover tests with new directory
    discover_test_files()
    return true
  elseif command == "pattern" or command == "pat" then
    if not args or args == "" then
      print(colors.yellow .. "Current test pattern: " .. state.test_pattern .. colors.normal)
      return true
    end

    state.test_pattern = args
    print(colors.green .. "Test pattern set to: " .. state.test_pattern .. colors.normal)

    -- Update central_config if available
    local central_config = get_central_config()
    if central_config then
      central_config.set("interactive.test_pattern", args)
      logger.debug("Updated test_pattern in central_config", { test_pattern = args })
    end

    -- Rediscover tests with new pattern
    discover_test_files()
    return true
  elseif command == "filter" then
    if not args or args == "" then
      state.focus_filter = nil
      print(colors.green .. "Test filter cleared" .. colors.normal)
      return true
    end

    state.focus_filter = args
    print(colors.green .. "Test filter set to: " .. state.focus_filter .. colors.normal)

    -- Apply filter to firmo
    if state.firmo and state.firmo.set_filter then
      state.firmo.set_filter(state.focus_filter)
    end

    return true
  elseif command == "focus" then
    if not args or args == "" then
      state.focus_filter = nil
      print(colors.green .. "Test focus cleared" .. colors.normal)
      return true
    end

    state.focus_filter = args
    print(colors.green .. "Test focus set to: " .. state.focus_filter .. colors.normal)

    -- Apply focus to firmo
    if state.firmo and state.firmo.focus then
      state.firmo.focus(state.focus_filter)
    end

    return true
  elseif command == "tags" then
    if not args or args == "" then
      state.tag_filter = nil
      print(colors.green .. "Tag filter cleared" .. colors.normal)
      return true
    end

    state.tag_filter = args
    print(colors.green .. "Tag filter set to: " .. state.tag_filter .. colors.normal)

    -- Apply tags to firmo
    if state.firmo and state.firmo.filter_tags then
      local tags = {}
      for tag in state.tag_filter:gmatch("([^,]+)") do
        table.insert(tags, tag:match("^%s*(.-)%s*$")) -- Trim spaces
      end
      state.firmo.filter_tags(tags)
    end

    return true
  elseif command == "watch" then
    if args == "on" or args == "true" or args == "1" then
      state.watch_mode = true

      -- Update central_config if available
      local central_config = get_central_config()
      if central_config then
        central_config.set("interactive.watch_mode", true)
        logger.debug("Updated watch_mode in central_config", { watch_mode = true })
      end

      print(colors.green .. "Watch mode enabled" .. colors.normal)
      return start_watch_mode()
    elseif args == "off" or args == "false" or args == "0" then
      state.watch_mode = false

      -- Update central_config if available
      local central_config = get_central_config()
      if central_config then
        central_config.set("interactive.watch_mode", false)
        logger.debug("Updated watch_mode in central_config", { watch_mode = false })
      end

      print(colors.green .. "Watch mode disabled" .. colors.normal)
      return true
    else
      -- Toggle watch mode
      state.watch_mode = not state.watch_mode

      -- Update central_config if available
      local central_config = get_central_config()
      if central_config then
        central_config.set("interactive.watch_mode", state.watch_mode)
        logger.debug("Updated watch_mode in central_config", { watch_mode = state.watch_mode })
      end

      print(colors.green .. "Watch mode " .. (state.watch_mode and "enabled" or "disabled") .. colors.normal)

      if state.watch_mode then
        return start_watch_mode()
      end

      return true
    end
  elseif command == "watch-dir" or command == "watchdir" then
    if not args or args == "" then
      print(colors.yellow .. "Current watch directories: " .. table.concat(state.watch_dirs, ", ") .. colors.normal)
      return true
    end

    -- Reset the default directory if this is the first watch dir
    if #state.watch_dirs == 1 and state.watch_dirs[1] == "." then
      state.watch_dirs = {}
    end

    table.insert(state.watch_dirs, args)
    print(colors.green .. "Added watch directory: " .. args .. colors.normal)

    -- Update central_config if available
    local central_config = get_central_config()
    if central_config then
      central_config.set("interactive.watch_dirs", state.watch_dirs)
      logger.debug("Updated watch_dirs in central_config", { watch_dirs = state.watch_dirs })
    end

    return true
  elseif command == "watch-exclude" or command == "exclude" then
    if not args or args == "" then
      print(
        colors.yellow .. "Current exclusion patterns: " .. table.concat(state.exclude_patterns, ", ") .. colors.normal
      )
      return true
    end

    table.insert(state.exclude_patterns, args)
    print(colors.green .. "Added exclusion pattern: " .. args .. colors.normal)

    -- Update central_config if available
    local central_config = get_central_config()
    if central_config then
      central_config.set("interactive.exclude_patterns", state.exclude_patterns)
      logger.debug("Updated exclude_patterns in central_config", { exclude_patterns = state.exclude_patterns })
    end

    return true
  elseif command == "codefix" then
    -- Split args into command and target
    local codefix_cmd, target = args:match("^(%S+)%s*(.*)$")
    if not codefix_cmd or not target or target == "" then
      print(colors.yellow .. "Usage: codefix <check|fix> <directory>" .. colors.normal)
      return false
    end

    return run_codefix(codefix_cmd, target)
  elseif command == "history" or command == "hist" then
    print(colors.bold .. "Command History:" .. colors.normal)
    for i, cmd in ipairs(state.history) do
      print("  " .. i .. ". " .. cmd)
    end
    return true
  else
    print(colors.red .. "Unknown command: " .. command .. colors.normal)
    print("Type 'help' for available commands")
    return false
  end
end

-- Read a line with history navigation
local function read_line_with_history()
  local line = io.read("*l")
  return line
end

-- Main entry point for the interactive CLI
--- Start the interactive CLI session
---@param firmo table The firmo framework instance
---@param options? table Additional options for the CLI session
---@return boolean success Whether the session was started successfully
function interactive.start(firmo, options)
  options = options or {}

  -- Record session start time
  state.session_start_time = os.time()

  logger.info("Starting interactive CLI", {
    version = interactive._VERSION,
    component = "CLI",
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    options = {
      test_dir = options.test_dir or state.test_dir,
      pattern = options.pattern or state.test_pattern,
      watch_mode = options.watch_mode ~= nil and options.watch_mode or state.watch_mode,
    },
  })

  -- Set initial state
  state.firmo = firmo

  if options.test_dir then
    state.test_dir = options.test_dir

    -- Update central_config if available
    local central_config = get_central_config()
    if central_config then
      central_config.set("interactive.test_dir", options.test_dir)
    end
  end

  if options.pattern then
    state.test_pattern = options.pattern

    -- Update central_config if available
    local central_config = get_central_config()
    if central_config then
      central_config.set("interactive.test_pattern", options.pattern)
    end
  end

  if options.watch_mode ~= nil then
    state.watch_mode = options.watch_mode

    -- Update central_config if available
    local central_config = get_central_config()
    if central_config then
      central_config.set("interactive.watch_mode", options.watch_mode)
    end
  end

  logger.debug("Interactive CLI configuration", {
    test_dir = state.test_dir,
    pattern = state.test_pattern,
    watch_mode = state.watch_mode and "on" or "off",
    component = "CLI",
  })

  -- Discover test files
  discover_test_files()

  -- Print header
  print_header()

  -- Print initial status
  print_status()

  -- Start watch mode if enabled
  if state.watch_mode then
    start_watch_mode()
  end

  -- Main loop
  logger.debug("Starting interactive CLI main loop", {
    component = "CLI",
  })

  while state.running do
    local prompt = state.prompt_symbol
    if state.colorized_output then
      io.write(colors.green .. prompt .. " " .. colors.normal)
    else
      io.write(prompt .. " ")
    end

    local input = read_line_with_history()

    if input then
      logger.debug("Processing command", {
        input = input,
        component = "CLI",
      })
      process_command(input)
    end
  end

  if state.colorized_output then
    print(colors.cyan .. "Exiting interactive mode" .. colors.normal)
  else
    print("Exiting interactive mode")
  end

  logger.info("Interactive CLI session ended", {
    component = "CLI",
    commands_executed = #state.history,
    session_duration = os.difftime(os.time(), state.session_start_time or os.time()),
    last_command = state.last_command,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    files_executed = #state.current_files,
  })

  return true
end

-- Reset the module configuration to defaults
--- Reset the interactive CLI to default configuration
---@return interactive_module The module instance for method chaining
function interactive.reset()
  logger.debug("Resetting interactive module configuration to defaults")

  -- Reset basic settings to defaults
  for key, value in pairs(DEFAULT_CONFIG) do
    -- Skip arrays, they will be handled separately
    if key ~= "watch_dirs" and key ~= "exclude_patterns" then
      state[key] = value
    end
  end

  -- Reset watch_dirs to defaults
  state.watch_dirs = {}
  for _, dir in ipairs(DEFAULT_CONFIG.watch_dirs) do
    table.insert(state.watch_dirs, dir)
  end

  -- Reset exclude_patterns to defaults
  state.exclude_patterns = {}
  for _, pattern in ipairs(DEFAULT_CONFIG.exclude_patterns) do
    table.insert(state.exclude_patterns, pattern)
  end

  -- Reset runtime state
  state.focus_filter = nil
  state.tag_filter = nil
  state.last_command = nil
  state.history = {}
  state.history_pos = 1
  state.codefix_enabled = false

  logger.debug("Interactive module reset to defaults")

  return interactive
end

-- Fully reset both local and central configuration
--- Fully reset both configuration and state
---@return interactive_module The module instance for method chaining
function interactive.full_reset()
  -- Reset local configuration
  interactive.reset()

  -- Reset central configuration if available
  local central_config = get_central_config()
  if central_config then
    central_config.reset("interactive")
    logger.debug("Reset central configuration for interactive module")
  end

  return interactive
end

-- Debug helper to show current configuration
--- Get debug information about the current configuration
---@return table debug_info Detailed information about the current configuration and state
function interactive.debug_config()
  local debug_info = {
    version = interactive._VERSION,
    local_config = {
      test_dir = state.test_dir,
      test_pattern = state.test_pattern,
      watch_mode = state.watch_mode,
      watch_dirs = state.watch_dirs,
      watch_interval = state.watch_interval,
      exclude_patterns = state.exclude_patterns,
      colorized_output = state.colorized_output,
      prompt_symbol = state.prompt_symbol,
      debug = state.debug,
      verbose = state.verbose,
    },
    runtime_state = {
      focus_filter = state.focus_filter,
      tag_filter = state.tag_filter,
      file_count = #state.current_files,
      history_count = #state.history,
      codefix_enabled = state.codefix_enabled,
    },
    using_central_config = false,
    central_config = nil,
  }

  -- Check for central_config
  local central_config = get_central_config()
  if central_config then
    debug_info.using_central_config = true
    debug_info.central_config = central_config.get("interactive")
  end

  -- Display configuration
  logger.info("Interactive module configuration", debug_info)

  return debug_info
end

return interactive
