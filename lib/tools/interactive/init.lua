--- Firmo Interactive CLI Module
---
--- Provides an interactive command-line interface (REPL) for running tests,
--- managing test settings, and interacting with other Firmo tools like codefix.
--- Features command history, watch mode toggle, filtering, and more.
---
--- @module lib.tools.interactive
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.3.0

---@class interactive_module The public API for the interactive CLI module.
---@field _VERSION string Module version.
---@field start fun(firmo: table, options?: {test_dir?: string, pattern?: string, watch_mode?: boolean}): boolean Starts the interactive CLI session. Requires the main `firmo` instance.
---@field configure fun(options?: {test_dir?: string, test_pattern?: string, watch_mode?: boolean, watch_dirs?: string[], watch_interval?: number, exclude_patterns?: string[], max_history?: number, colorized_output?: boolean, prompt_symbol?: string, debug?: boolean, verbose?: boolean}): interactive_module Configures the interactive module settings, interacting with central config if available.
---@field reset fun(): interactive_module Resets local configuration and runtime state (history, filters, etc.) to defaults.
---@field full_reset fun(): interactive_module Resets local config, state, and attempts to reset central config for this module.
---@field debug_config fun(): table Returns a table containing the current configuration and runtime state for debugging.

local interactive = {}
local interactive = {}

--- Module version
interactive._VERSION = "1.3.0"

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
    return logging.get_logger("interactive")
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

local runner = try_require("lib.core.runner")

local DEFAULT_CONFIG = {
  test_dir = "./tests", -- Default directory containing test files.
  test_pattern = "*_test.lua", -- Default Lua pattern for matching test files.
  watch_mode = false, -- Start in watch mode (true/false).
  watch_dirs = { "." }, -- Directories to monitor in watch mode.
  watch_interval = 1.0, -- Interval (seconds) for checking file changes in watch mode.
  exclude_patterns = { "node_modules", "%.git" },
  max_history = 100, -- Maximum number of commands to keep in history.
  colorized_output = true, -- Use ANSI colors in output.
  prompt_symbol = ">", -- Character(s) to display for the input prompt.
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

--- Internal state table for the interactive module.
local state = {
  firmo = nil, -- Reference to the main firmo instance.
  test_dir = DEFAULT_CONFIG.test_dir, -- Current directory for test discovery.
  test_pattern = DEFAULT_CONFIG.test_pattern,
  current_files = {}, -- List of discovered test files based on current dir/pattern.
  focus_filter = nil, -- Current focus pattern string applied to tests.
  tag_filter = nil, -- Current tag filter string applied to tests.
  watch_mode = DEFAULT_CONFIG.watch_mode,
  watch_dirs = {}, -- Current list of directories being watched.
  watch_interval = DEFAULT_CONFIG.watch_interval, -- Current watch interval.
  exclude_patterns = {}, -- Current list of exclude patterns for watch mode.
  last_command = nil, -- The previously executed command string.
  history = {}, -- Array storing command history strings.
  history_pos = 1, -- Current position in the history (for up/down navigation - partially implemented).
  codefix_enabled = false, -- Flag indicating if the codefix module has been initialized.
  running = true, -- Flag to control the main interactive loop.
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
local central_config

local central_config = try_require("lib.core.central_config")

-- Register this module with central_config
central_config.register_module("interactive", {
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

--- Registers a listener with central_config to update local config cache when interactive settings change.
---@return boolean success `true` if the listener was registered, `false` otherwise.
---@private
local function register_change_listener()
  -- Register change listener for interactive configuration
  central_config.on_change("interactive", function(path, old_value, new_value)
    get_logger().debug("Configuration change detected", {
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
            get_logger().debug("Updated setting from central_config", {
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
        get_logger().debug("Updated watch_dirs from central_config", {
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
        get_logger().debug("Updated exclude_patterns from central_config", {
          pattern_count = #state.exclude_patterns,
        })
      end

      -- Update logging configuration
      logging.configure_from_options("interactive", {
        debug = interactive_config.debug,
        verbose = interactive_config.verbose,
      })

      get_logger().debug("Applied configuration changes from central_config")
    end
  end)

  get_logger().debug("Registered change listener for central configuration")
  return true
end

--- Configures the interactive module settings.
--- Merges provided `options` with defaults, potentially loading from or saving to central config.
---@param options? {test_dir?: string, test_pattern?: string, watch_mode?: boolean, watch_dirs?: string[], watch_interval?: number, exclude_patterns?: string[], max_history?: number, colorized_output?: boolean, prompt_symbol?: string, debug?: boolean, verbose?: boolean} Configuration options table.
---@return interactive_module self The module instance (`interactive`) for method chaining.
function interactive.configure(options)
  options = options or {}

  get_logger().debug("Configuring interactive module", {
    options = options,
  })

  -- Get existing central config values
  local interactive_config = central_config.get("interactive")

  -- Apply central configuration (with defaults as fallback)
  if interactive_config then
    get_logger().debug("Using central_config values for initialization", {
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
    get_logger().debug("No central_config values found, using defaults")
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
        central_config.set("interactive.watch_dirs", value)
      end
    elseif key == "exclude_patterns" then
      if type(value) == "table" then
        -- Replace exclude_patterns
        state.exclude_patterns = {}
        for _, pattern in ipairs(value) do
          table.insert(state.exclude_patterns, pattern)
        end

        central_config.set("interactive.exclude_patterns", value)
      end
    else
      -- Apply basic setting
      if state[key] ~= nil then
        state[key] = value

        central_config.set("interactive." .. key, value)
      end
    end
  end

  -- Configure logging
  get_logging().configure_from_options("interactive", {
    debug = state.debug,
    verbose = state.verbose,
  })

  get_logger().debug("Interactive module configuration complete", {
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
get_logger().debug("Interactive CLI module initialized", {
  version = interactive._VERSION,
})

-- Load internal modules (should exist)
local watcher = try_require("lib.tools.watcher")
local codefix = try_require("lib.tools.codefix")
local discover = try_require("lib.tools.discover")

--- Clears the screen (if possible) and prints the standard interactive CLI header.
--- Handles potential errors during screen clear or printing.
---@private
local function print_header()
  -- Safe screen clearing with error handling
  local success, result = get_error_handler().try(function()
    io.write("\027[2J\027[H") -- Clear screen
    return true
  end)

  if not success then
    get_logger().warn("Failed to clear screen", {
      component = "CLI",
      error = get_error_handler().format_error(result),
    })
    -- Continue without clearing screen
  end

  -- Safe output with error handling
  success, result = get_error_handler().try(function()
    print(colors.bold .. colors.cyan .. "Firmo Interactive CLI" .. colors.normal)
    print(colors.green .. "Type 'help' for available commands" .. colors.normal)
    print(string.rep("-", 60))
    return true
  end)

  if not success then
    get_logger().error("Failed to display header", {
      component = "CLI",
      error = get_error_handler().format_error(result),
    })
    -- Try a simple fallback for header display
    get_error_handler().try(function()
      print("Firmo Interactive CLI")
      print("Type 'help' for available commands")
      print("---------------------------------------------------------")
      return true
    end)
  end

  -- Safely get current time
  local time_str = "unknown"
  local time_success, time_result = get_error_handler().try(function()
    return os.date("%H:%M:%S")
  end)

  if time_success then
    time_str = time_result
  end

  get_logger().info("Interactive CLI header displayed", {
    component = "CLI",
    time = time_str,
  })

  -- Safely check state properties with error handling
  local debug_info = {}
  success, result = get_error_handler().try(function()
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
    get_logger().debug("Display settings initialized", debug_info)
  else
    get_logger().warn("Failed to get display settings", {
      component = "CLI",
      error = get_error_handler().format_error(result),
    })
  end
end

--- Prints the available commands and keyboard shortcuts to the console.
---@private
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

  get_logger().debug("Help information displayed", {
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

--- Prints the current configuration settings (test dir, pattern, filters, watch mode, etc.) to the console.
---@private
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

  get_logger().debug("Status information displayed", {
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

--- Lists the currently discovered test files (from `state.current_files`) to the console.
--- Shows a warning if no files have been discovered.
---@return nil
---@private
local function list_test_files()
  if #state.current_files == 0 then
    print(colors.yellow .. "No test files found in " .. state.test_dir .. colors.normal)
    get_logger().warn("No test files found", {
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

  get_logger().debug("Test files listed", {
    component = "CLI",
    file_count = #state.current_files,
    directory = state.test_dir,
    pattern = state.test_pattern,
    success = #state.current_files > 0,
  })
end

--- Discovers test files based on current settings (`state.test_dir`, `state.test_pattern`).
--- Uses the `discover` module (if available) and updates `state.current_files`.
--- Handles errors during validation and discovery.
---@return boolean found `true` if files were found (or discovery skipped), `false` otherwise.
---@private
local function discover_test_files()
  -- Validate necessary state for test discovery
  if not state then
    local err = get_error_handler().runtime_error("State not initialized for test discovery", {
      operation = "discover_test_files",
      module = "interactive",
    })
    get_logger().error("Test discovery failed due to missing state", {
      component = "TestDiscovery",
      error = get_error_handler().format_error(err),
    })

    -- Safe error display with fallback
    get_error_handler().try(function()
      print(colors.red .. "Error: Internal state not initialized" .. colors.normal)
      return true
    end)

    return false
  end

  -- Validate test directory and pattern
  if not state.test_dir or type(state.test_dir) ~= "string" then
    local err = get_error_handler().validation_error("Invalid test directory", {
      operation = "discover_test_files",
      test_dir = state.test_dir,
      test_dir_type = type(state.test_dir),
      module = "interactive",
    })
    get_logger().error("Test discovery failed due to invalid directory", {
      component = "TestDiscovery",
      error = get_error_handler().format_error(err),
    })

    -- Safe error display with fallback
    get_error_handler().try(function()
      print(colors.red .. "Error: Invalid test directory" .. colors.normal)
      return true
    end)

    return false
  end

  if not state.test_pattern or type(state.test_pattern) ~= "string" then
    local err = get_error_handler().validation_error("Invalid test pattern", {
      operation = "discover_test_files",
      test_pattern = state.test_pattern,
      test_pattern_type = type(state.test_pattern),
      module = "interactive",
    })
    get_logger().error("Test discovery failed due to invalid pattern", {
      component = "TestDiscovery",
      error = get_error_handler().format_error(err),
    })

    -- Safe error display with fallback
    get_error_handler().try(function()
      print(colors.red .. "Error: Invalid test pattern" .. colors.normal)
      return true
    end)

    return false
  end

  -- Initialize current_files if not present
  if not state.current_files then
    state.current_files = {}
  end

  -- Log discovery start
  get_logger().debug("Discovering test files", {
    component = "TestDiscovery",
    directory = state.test_dir,
    pattern = state.test_pattern,
    existing_files = #state.current_files,
  })

  -- Attempt to discover test files with error handling
  local success, result = get_error_handler().try(function()
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
    local err = get_error_handler().runtime_error(
      "Test discovery operation failed",
      {
        operation = "discover_test_files",
        module = "interactive",
        test_dir = state.test_dir,
        test_pattern = state.test_pattern,
      },
      result -- Original error as cause
    )
    get_logger().error("Test discovery failed with exception", {
      component = "TestDiscovery",
      error = get_error_handler().format_error(err),
      directory = state.test_dir,
      pattern = state.test_pattern,
      attempted_recovery = false,
    })

    -- Safe error display with fallback
    get_error_handler().try(function()
      print(colors.red .. "Error: Test discovery failed: " .. get_error_handler().format_error(result) .. colors.normal)
      return true
    end)

    return false
  end

  -- Process successful discovery results
  if not result.files or type(result.files) ~= "table" then
    local err = get_error_handler().runtime_error("Discovery returned invalid result", {
      operation = "discover_test_files",
      module = "interactive",
      result_type = type(result.files),
    })
    get_logger().error("Test discovery failed with invalid result", {
      component = "TestDiscovery",
      error = get_error_handler().format_error(err),
      directory = state.test_dir,
      pattern = state.test_pattern,
      attempted_recovery = false,
    })

    -- Safe error display with fallback
    get_error_handler().try(function()
      print(colors.red .. "Error: Test discovery returned invalid result" .. colors.normal)
      return true
    end)

    return false
  end

  -- Update state with discovered files
  state.current_files = result.files

  -- Get timestamp for logging
  local timestamp = "unknown"
  local time_success, time_result = get_error_handler().try(function()
    return os.date("%H:%M:%S")
  end)

  if time_success then
    timestamp = time_result
  end

  -- Log discovery completion
  get_logger().debug("Test files discovery completed", {
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

--- Runs tests either for a single specified file or for all currently discovered files (`state.current_files`).
--- Uses the `runner` module (if available) and the `firmo` instance.
--- Resets `firmo` state before running. Handles errors during validation and execution.
---@param file_path? string Path to a single test file. If `nil`, runs all files in `state.current_files`.
---@return boolean success `true` if the test run(s) succeeded without errors, `false` otherwise.
---@private
local function run_tests(file_path)
  -- Validate state and dependencies
  if not state then
    local err = get_error_handler().runtime_error("State not initialized for test execution", {
      operation = "run_tests",
      module = "interactive",
    })
    get_logger().error("Test execution failed due to missing state", {
      component = "TestRunner",
      error = get_error_handler().format_error(err),
    })

    -- Safe error display with fallback
    get_error_handler().try(function()
      print(colors.red .. "Error: Internal state not initialized" .. colors.normal)
      return true
    end)

    return false
  end

  -- Verify firmo test framework is available
  if not state.firmo then
    local err = get_error_handler().runtime_error("Test framework not initialized", {
      operation = "run_tests",
      module = "interactive",
      file_path = file_path or "all tests",
    })

    get_logger().error("Test execution failed", {
      component = "TestRunner",
      error = get_error_handler().format_error(err),
      error_type = "FrameworkNotInitialized",
      file = file_path or "all tests",
      attempted_recovery = false,
    })

    -- Safe error display with fallback
    get_error_handler().try(function()
      print(colors.red .. "Error: Test framework not initialized" .. colors.normal)
      return true
    end)

    return false
  end

  -- Reset firmo state with error handling
  local reset_success, reset_result = get_error_handler().try(function()
    state.firmo.reset()
    return true
  end)

  if not reset_success then
    local err = get_error_handler().runtime_error(
      "Failed to reset test environment",
      {
        operation = "run_tests",
        module = "interactive",
        file_path = file_path or "all tests",
      },
      reset_result -- Original error as cause
    )

    get_logger().error("Test environment reset failed", {
      component = "TestRunner",
      error = get_error_handler().format_error(err),
      file = file_path or "all tests",
      attempted_recovery = true,
    })

    -- Try to continue despite reset failure
  else
    -- Get timestamp for logging
    local timestamp = "unknown"
    local time_success, time_result = get_error_handler().try(function()
      return os.date("%H:%M:%S")
    end)

    if time_success then
      timestamp = time_result
    end

    get_logger().debug("Test environment reset before execution", {
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
      local err = get_error_handler().validation_error("Invalid file path for test execution", {
        operation = "run_tests",
        module = "interactive",
        file_path = file_path,
        file_path_type = type(file_path),
      })

      get_logger().error("Test execution failed", {
        component = "TestRunner",
        error = get_error_handler().format_error(err),
        file = tostring(file_path),
      })

      -- Safe error display with fallback
      get_error_handler().try(function()
        print(colors.red .. "Error: Invalid file path for test execution" .. colors.normal)
        return true
      end)

      return false
    end

    -- Verify file exists with safe I/O
    local file_exists, file_err = get_error_handler().safe_io_operation(
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
      local err = get_error_handler().io_error(
        "Test file not found",
        {
          operation = "run_tests",
          module = "interactive",
          file_path = file_path,
        },
        file_err -- Include underlying error as cause
      )

      get_logger().error("Test execution failed", {
        component = "TestRunner",
        error = get_error_handler().format_error(err),
        file = file_path,
      })

      -- Safe error display with fallback
      get_error_handler().try(function()
        print(colors.red .. "Error: Test file not found: " .. file_path .. colors.normal)
        return true
      end)

      return false
    end

    -- Display running message with error handling
    get_error_handler().try(function()
      print(colors.cyan .. "Running file: " .. file_path .. colors.normal)
      return true
    end)

    get_logger().info("Running single test file", {
      file = file_path,
      focus_filter = state.focus_filter or "none",
      tag_filter = state.tag_filter or "none",
    })

    -- Run the single test file with error handling
    local run_success, results = get_error_handler().try(function()
      return runner.run_file(file_path, state.firmo)
    end)

    if not run_success then
      local err = get_error_handler().runtime_error(
        "Test file execution failed with exception",
        {
          operation = "run_tests",
          module = "interactive",
          file_path = file_path,
        },
        results -- Original error as cause
      )

      get_logger().error("Test file execution failed", {
        component = "TestRunner",
        error = get_error_handler().format_error(err),
        file = file_path,
      })

      -- Safe error display with fallback
      get_error_handler().try(function()
        print(colors.red .. "Error executing test file: " .. get_error_handler().format_error(results) .. colors.normal)
        return true
      end)

      return false
    end

    -- Validate results
    if type(results) ~= "table" then
      local err = get_error_handler().runtime_error("Test runner returned invalid result", {
        operation = "run_tests",
        module = "interactive",
        file_path = file_path,
        result_type = type(results),
      })

      get_logger().error("Test file execution completed with invalid result", {
        component = "TestRunner",
        error = get_error_handler().format_error(err),
        file = file_path,
      })

      -- Safe error display with fallback
      get_error_handler().try(function()
        print(colors.red .. "Error: Test runner returned invalid result" .. colors.normal)
        return true
      end)

      return false
    end

    -- Extract success state
    success = results.success and results.errors == 0

    get_logger().info("Test run completed", {
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
      get_logger().debug("No test files in state, attempting discovery", {
        component = "TestRunner",
        test_dir = state.test_dir,
        test_pattern = state.test_pattern,
      })

      if not discover_test_files() then
        -- Error messages already handled by discover_test_files

        -- Safe error display with fallback
        get_error_handler().try(function()
          print(colors.yellow .. "No test files found. Check test directory and pattern." .. colors.normal)
          return true
        end)

        get_logger().warn("No test files found to run", {
          directory = state.test_dir,
          pattern = state.test_pattern,
        })

        return false
      end
    end

    -- Get file count safely
    local file_count = 0
    get_error_handler().try(function()
      file_count = #state.current_files
      return true
    end)

    -- Display running message with error handling
    get_error_handler().try(function()
      print(colors.cyan .. "Running " .. file_count .. " test files..." .. colors.normal)
      return true
    end)

    get_logger().info("Running multiple test files", {
      file_count = file_count,
      focus_filter = state.focus_filter or "none",
      tag_filter = state.tag_filter or "none",
    })

    -- Run all test files with error handling
    local run_success, run_result = get_error_handler().try(function()
      return runner.run_all(state.current_files, state.firmo)
    end)

    if not run_success then
      local err = get_error_handler().runtime_error(
        "Multiple test file execution failed with exception",
        {
          operation = "run_tests",
          module = "interactive",
          file_count = file_count,
        },
        run_result -- Original error as cause
      )

      get_logger().error("Multiple test file execution failed", {
        component = "TestRunner",
        error = get_error_handler().format_error(err),
        file_count = file_count,
      })

      -- Safe error display with fallback
      get_error_handler().try(function()
        print(
          colors.red .. "Error executing test files: " .. get_error_handler().format_error(run_result) .. colors.normal
        )
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

    get_logger().info("Multiple file test run completed", {
      success = success,
      file_count = file_count,
    })
  end

  return success
end

--- Starts the file watcher loop.
--- Initializes the `watcher` module, performs an initial test run, and then enters a loop
--- checking for file changes and user input (Enter key to exit). Re-runs tests on change.
--- Requires `watcher` and `runner` modules.
---@return boolean success `true` if watch mode started and exited normally (user input), `false` if required modules are missing.
---@private
local function start_watch_mode()
  print(colors.cyan .. "Starting watch mode..." .. colors.normal)
  print("Watching directories: " .. table.concat(state.watch_dirs, ", "))
  print("Press Enter to return to interactive mode")

  get_logger().info("Watch mode starting", {
    directories = state.watch_dirs,
    exclude_patterns = state.exclude_patterns,
    check_interval = state.watch_interval,
    component = "WatchMode",
  })

  watcher.set_check_interval(state.watch_interval)
  watcher.init(state.watch_dirs, state.exclude_patterns)

  -- Initial test run
  if #state.current_files == 0 then
    get_logger().debug("No test files found, discovering tests before watch", {
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

  --- Performs a non-blocking check for keyboard input (specifically Enter key).
  --- Sets `watch_running` to false if input is detected.
  --- **Note:** `io.read(0)` behavior might be platform-dependent or require specific terminal settings.
  ---@return boolean input_detected `true` if input was detected, `false` otherwise.
  ---@private
  local function check_input()
    local input_available = io.read(0) ~= nil
    if input_available then
      -- Consume the input
      ---@diagnostic disable-next-line: discard-returns
      io.read("*l")
      watch_running = false
      get_logger().debug("User input detected, exiting watch mode", {
        component = "WatchMode",
      })
    end
    return input_available
  end

  -- Clear terminal
  io.write("\027[2J\027[H")

  -- Initial test run
  get_logger().debug("Running initial tests in watch mode", {
    component = "WatchMode",
    file_count = #state.current_files,
  })

  state.firmo.reset()
  runner.run_all(state.current_files, state.firmo)

  print(colors.cyan .. "\n--- WATCHING FOR CHANGES (Press Enter to return to interactive mode) ---" .. colors.normal)

  get_logger().info("Watch mode active", {
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

      get_logger().info("File changes detected in watch mode", {
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

      get_logger().info("Running tests after file changes", {
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

      get_logger().info("Watch mode resumed", {
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

  get_logger().info("Watch mode exited", {
    component = "WatchMode",
  })

  return true
end

--- Executes a codefix command ("check" or "fix") on a target directory.
--- Initializes the `codefix` module if needed and calls its `run_cli`.
--- Requires `codefix` module. Prints status messages to console.
---@param command "check"|"fix" The codefix operation to perform.
---@param target string The directory path to target.
---@return boolean success `true` if the codefix command succeeded, `false` otherwise (e.g., module unavailable, invalid command/target, codefix failure).
---@private
local function run_codefix(command, target)
  if not command or not target then
    print(colors.yellow .. "Usage: codefix <check|fix> <directory>" .. colors.normal)
    get_logger().warn("Invalid codefix command", {
      component = "CodeFix",
      command = command or "nil",
      target = target or "nil",
      reason = "Missing required parameters",
    })
    return false
  end

  -- Initialize codefix if needed
  if not state.codefix_enabled then
    get_logger().debug("Initializing codefix module", {
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

  get_logger().info("Running codefix operation", {
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
    get_logger().info("Codefix operation completed", {
      component = "CodeFix",
      status = "success",
      command = command,
      target = target,
    })
  else
    print(colors.red .. "Codefix failed" .. colors.normal)
    get_logger().warn("Codefix operation failed", {
      component = "CodeFix",
      status = "failed",
      command = command,
      target = target,
    })
  end

  return success
end

--- Adds a command string to the internal history buffer (`state.history`).
--- Avoids adding empty strings or consecutive duplicates. Limits history size.
---@param command string The command string to add.
---@return nil
---@private
local function add_to_history(command)
  -- Don't add empty commands or duplicates of the last command
  if command == "" or (state.history[#state.history] == command) then
    if get_logger().is_debug_enabled() then
      get_logger().debug("Skipping history addition", {
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
    get_logger().debug("Trimming command history", {
      component = "CLI",
      history_size = #state.history,
      removed_command = state.history[1],
    })
    table.remove(state.history, 1)
  end

  get_logger().debug("Command added to history", {
    component = "CLI",
    command = command,
    history_size = #state.history,
    history_position = state.history_pos,
  })
end

--- Parses user input, updates history, and executes the corresponding command handler
--- (e.g., `run`, `list`, `help`, `watch`, `exit`, etc.).
---@param input string The raw command line input from the user.
---@return boolean success `true` if the command was processed successfully (or was `exit`), `false` if command unknown or failed.
---@private
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

  get_logger().debug("Command parsed", {
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

    central_config.set("interactive.test_dir", args)
    get_logger().debug("Updated test_dir in central_config", { test_dir = args })

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

    central_config.set("interactive.test_pattern", args)
    get_logger().debug("Updated test_pattern in central_config", { test_pattern = args })

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

      central_config.set("interactive.watch_mode", true)
      get_logger().debug("Updated watch_mode in central_config", { watch_mode = true })

      print(colors.green .. "Watch mode enabled" .. colors.normal)
      return start_watch_mode()
    elseif args == "off" or args == "false" or args == "0" then
      state.watch_mode = false

      central_config.set("interactive.watch_mode", false)
      get_logger().debug("Updated watch_mode in central_config", { watch_mode = false })

      print(colors.green .. "Watch mode disabled" .. colors.normal)
      return true
    else
      -- Toggle watch mode
      state.watch_mode = not state.watch_mode

      central_config.set("interactive.watch_mode", state.watch_mode)
      get_logger().debug("Updated watch_mode in central_config", { watch_mode = state.watch_mode })

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

    central_config.set("interactive.watch_dirs", state.watch_dirs)
    get_logger().debug("Updated watch_dirs in central_config", { watch_dirs = state.watch_dirs })

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

    central_config.set("interactive.exclude_patterns", state.exclude_patterns)
    get_logger().debug("Updated exclude_patterns in central_config", { exclude_patterns = state.exclude_patterns })

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

--- Reads a line of input from the console.
--- **Placeholder:** Currently uses basic `io.read`. Full implementation would handle
--- history navigation (Up/Down arrows), editing, and potentially tab completion.
---@return string|nil input The line read from input, or `nil` on EOF (e.g., Ctrl+D).
---@private
local function read_line_with_history()
  local line = io.read("*l")
  return line
end

--- Starts the main interactive command-line loop.
--- Initializes state, discovers tests, prints header/status, handles watch mode,
--- and enters the read-process loop until the user exits.
---@param firmo table The main `firmo` framework instance.
---@param options? {test_dir?: string, pattern?: string, watch_mode?: boolean} Optional initial configuration overrides.
---@return boolean success Always returns `true` when the loop terminates normally (via 'exit' command).
function interactive.start(firmo, options)
  options = options or {}

  -- Record session start time
  state.session_start_time = os.time()

  get_logger().info("Starting interactive CLI", {
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

    central_config.set("interactive.test_dir", options.test_dir)
  end

  if options.pattern then
    state.test_pattern = options.pattern

    central_config.set("interactive.test_pattern", options.pattern)
  end

  if options.watch_mode ~= nil then
    state.watch_mode = options.watch_mode

    central_config.set("interactive.watch_mode", options.watch_mode)
  end

  get_logger().debug("Interactive CLI configuration", {
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
  get_logger().debug("Starting interactive CLI main loop", {
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
      get_logger().debug("Processing command", {
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

  get_logger().info("Interactive CLI session ended", {
    component = "CLI",
    commands_executed = #state.history,
    session_duration = os.difftime(os.time(), state.session_start_time or os.time()),
    last_command = state.last_command,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    files_executed = #state.current_files,
  })

  return true
end

--- Resets the interactive module's local configuration and runtime state to defaults.
--- Clears history, filters, etc., and re-applies `DEFAULT_CONFIG`.
---@return interactive_module self The module instance (`interactive`) for chaining.
function interactive.reset()
  get_logger().debug("Resetting interactive module configuration to defaults")

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

  get_logger().debug("Interactive module reset to defaults")

  return interactive
end

--- Resets local configuration and state (`interactive.reset()`) and also attempts
--- to reset the "interactive" section in the central configuration system.
---@return interactive_module self The module instance (`interactive`) for chaining.
function interactive.full_reset()
  -- Reset local configuration
  interactive.reset()

  central_config.reset("interactive")
  get_logger().debug("Reset central configuration for interactive module")

  return interactive
end

--- Returns a table containing a snapshot of the current configuration and runtime state for debugging.
--- Includes local config, central config (if available), and runtime variables like filters and file counts.
---@return table debug_info Detailed information about the current configuration and state.
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

  debug_info.using_central_config = true
  debug_info.central_config = central_config.get("interactive")

  -- Display configuration
  get_logger().info("Interactive module configuration", debug_info)

  return debug_info
end

return interactive
