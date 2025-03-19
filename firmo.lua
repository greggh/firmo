-- firmo v0.7.5 - Enhanced Lua test framework
-- https://github.com/greggh/firmo
-- MIT LICENSE
-- Based on lust by Bjorn Swenson (https://github.com/bjornbytes/lust)
--
-- Features:
-- * BDD-style nested test blocks (describe/it)
-- * Assertions with detailed error messages
-- * Setup and teardown with before/after hooks
-- * Advanced mocking and spying system
-- * Tag-based filtering for selective test execution
-- * Focus mode for running only specific tests (fdescribe/fit)
-- * Skip mode for excluding tests (xdescribe/xit)
-- * Asynchronous testing support
-- * Code coverage analysis and reporting
-- * Watch mode for continuous testing

-- Load required modules directly (without try/catch - these are required)
local error_handler = require("lib.tools.error_handler")
local assertion = require("lib.assertion")

-- Try to require optional modules
local function try_require(name)
  ---@diagnostic disable-next-line: unused-local
  local success, mod, err = error_handler.try(function()
    return require(name)
  end)

  if success then
    return mod
  else
    -- Only log errors for modules that should exist but failed to load
    -- (Don't log errors for optional modules that might not exist)
    if name:match("^lib%.") then
      -- This is an internal module that should exist
      local logger = error_handler.get_logger and error_handler.get_logger() or nil
      -- We can't use the centralized logger here because this function runs before
      -- we load the logger module. This would create a circular dependency, so we
      -- need to keep the conditional check in this specific place.
      if logger then
        logger.warn("Failed to load module", {
          module = name,
          error = error_handler.format_error(mod),
        })
      end
    end
    return nil
  end
end

-- Load filesystem module (required for basic operations)
local fs = try_require("lib.tools.filesystem")
if not fs then
  error_handler.throw(
    "Required module 'lib.tools.filesystem' could not be loaded",
    error_handler.CATEGORY.CONFIGURATION,
    error_handler.SEVERITY.FATAL,
    { module = "firmo" }
  )
end

-- Load logging module (required for proper error reporting)
local logging = try_require("lib.tools.logging")
if not logging then
  error_handler.throw(
    "Required module 'lib.tools.logging' could not be loaded",
    error_handler.CATEGORY.CONFIGURATION,
    error_handler.SEVERITY.FATAL,
    { module = "firmo" }
  )
end
---@diagnostic disable-next-line: need-check-nil
local logger = logging.get_logger("firmo-core")

-- Optional modules for advanced features
local coverage = try_require("lib.coverage")
local quality = try_require("lib.quality")
local codefix = try_require("lib.tools.codefix")
local reporting = try_require("lib.reporting")
local watcher = try_require("lib.tools.watcher")
---@diagnostic disable-next-line: unused-local
local json = try_require("lib.reporting.json")
local type_checking = try_require("lib.core.type_checking")
local async_module = try_require("lib.async")
local interactive = try_require("lib.tools.interactive")
local discover_module = try_require("scripts.discover")
local parallel_module = try_require("lib.tools.parallel")
-- Use central_config for configuration
local central_config = try_require("lib.core.central_config")
local module_reset_module = try_require("lib.core.module_reset")

-- Configure logging (now a required component)
local success, err = error_handler.try(function()
  ---@diagnostic disable-next-line: need-check-nil
  logging.configure_from_config("firmo-core")
end)

if not success then
  local context = {
    module = "firmo-core",
    operation = "configure_logging",
  }

  -- Log warning but continue - configuration might fail but logging still works
  logger.warn("Failed to configure logging", {
    error = error_handler.format_error(err),
    context = context,
  })
end

logger.debug("Logging system initialized", {
  module = "firmo-core",
  modules_loaded = {
    error_handler = true, -- Always true as this is now required
    filesystem = fs ~= nil, -- Always true as this is now required
    logging = true, -- Always true as this is now required
    assertion = true, -- Always true as this is now required
    coverage = coverage ~= nil,
    quality = quality ~= nil,
    codefix = codefix ~= nil,
    reporting = reporting ~= nil,
    watcher = watcher ~= nil,
    async = async_module ~= nil,
    interactive = interactive ~= nil,
    discover = discover_module ~= nil,
    parallel = parallel_module ~= nil,
    central_config = central_config ~= nil,
    module_reset = module_reset_module ~= nil,
  },
})

local firmo = {}
firmo.level = 0
firmo.passes = 0
firmo.errors = 0
firmo.befores = {}
firmo.afters = {}
firmo.version = "0.7.5"
firmo.active_tags = {}
firmo.current_tags = {}
firmo.filter_pattern = nil
-- Default configuration for modules
firmo.async_options = {
  timeout = 5000, -- Default timeout in ms
}
firmo.focus_mode = false -- Tracks if any focused tests are present
firmo.skipped = 0 -- Track skipped tests

-- Export async functions if the module is available
if async_module then
  -- Import core async functions
  firmo.async = async_module.async
  firmo.await = async_module.await
  firmo.wait_until = async_module.wait_until
  firmo.parallel_async = async_module.parallel_async

  -- Configure the async module with our options
  if firmo.async_options and firmo.async_options.timeout then
    async_module.set_timeout(firmo.async_options.timeout)
  end
else
  -- Define stub functions for when the module isn't available
  local function async_error()
    error("Async module not available. Make sure src/async.lua exists.", 2)
  end

  firmo.async = async_error
  firmo.await = async_error
  firmo.wait_until = async_error
  firmo.parallel_async = async_error
end

-- Register codefix module if available
if codefix then
  codefix.register_with_firmo(firmo)
end

-- Register parallel execution module if available
if parallel_module then
  parallel_module.register_with_firmo(firmo)
end

-- Register configuration
if central_config then
  -- Register firmo core with central_config
  central_config.register_module("firmo", {
    field_types = {
      version = "string",
    },
  }, {
    version = firmo.version,
  })

  -- Register additional core modules
  central_config.register_module("test_discovery", {
    field_types = {
      dir = "string",
      pattern = "string",
    },
  }, {
    dir = "./tests",
    pattern = "*_test.lua",
  })

  central_config.register_module("format", {
    field_types = {
      default_format = "string",
      use_color = "boolean",
      show_success_detail = "boolean",
      show_trace = "boolean",
      dot_mode = "boolean",
      compact = "boolean",
      summary_only = "boolean",
    },
  }, {
    use_color = true,
    show_success_detail = false,
    show_trace = false,
  })

  -- Store reference to configuration in firmo
  firmo.config = central_config

  -- Try to load default configuration if it exists
  central_config.load_from_file()
end

-- Add test discovery functionality
if discover_module then
  -- Test file discovery function with improved error handling
  function firmo.discover(dir, pattern)
    -- Parameter validation
    if dir ~= nil and type(dir) ~= "string" then
      local err = error_handler.validation_error("Directory must be a string", {
        parameter = "dir",
        provided_type = type(dir),
        function_name = "discover",
      })

      logger.error("Parameter validation failed", {
        error = error_handler.format_error(err),
        operation = "discover",
      })
      return {}, err
    end

    if pattern ~= nil and type(pattern) ~= "string" then
      local err = error_handler.validation_error("Pattern must be a string", {
        parameter = "pattern",
        provided_type = type(pattern),
        function_name = "discover",
      })

      logger.error("Parameter validation failed", {
        error = error_handler.format_error(err),
        operation = "discover",
      })
      return {}, err
    end

    dir = dir or "./tests"
    pattern = pattern or "*_test.lua"

    logger.debug("Discovering test files", {
      directory = dir,
      pattern = pattern,
    })

    -- Use discover_files from filesystem module if available
    if fs and fs.discover_files then
      local files, err = fs.discover_files(dir, pattern)

      if not files then
        logger.error("Failed to discover test files", {
          directory = dir,
          pattern = pattern,
          error = error_handler.format_error(err),
        })
        return {}, err
      end

      logger.debug("Test files discovered", {
        directory = dir,
        pattern = pattern,
        count = #files,
      })

      return files
    else
      -- Fallback method - this is deprecated and should be removed in future
      logger.warn("Using deprecated test discovery method", {
        reason = "fs.discover_files not available",
      })

      -- Platform-specific command to find test files
      local command
      if package.config:sub(1, 1) == "\\" then
        -- Windows
        command = 'dir /s /b "' .. dir .. "\\" .. pattern .. '" > firmo_temp_files.txt'
      else
        -- Unix
        command = 'find "' .. dir .. '" -name "' .. pattern .. '" -type f > firmo_temp_files.txt'
      end

      -- Execute the command with error handling
      local success, exec_err = error_handler.try(function()
        return os.execute(command)
      end)

      if not success or exec_err == 0 then
        local err = error_handler.io_error("Failed to execute command for file discovery", {
          command = command,
          directory = dir,
          pattern = pattern,
        }, exec_err)

        logger.error("Failed to execute command for file discovery", {
          error = error_handler.format_error(err),
          command = command,
        })

        return {}, err
      end

      -- Read the results from the temporary file
      local files = {}

      local content, read_err = error_handler.safe_io_operation(function()
        ---@diagnostic disable-next-line: need-check-nil
        return fs.read_file("firmo_temp_files.txt")
      end, "firmo_temp_files.txt", { operation = "read_temp_file", context = "discover" })

      if content then
        for line in content:gmatch("[^\r\n]+") do
          if line:match(pattern:gsub("*", ".*"):gsub("?", ".")) then
            table.insert(files, line)
          end
        end

        -- Clean up temporary file
        local remove_success = error_handler.try(function()
          os.remove("firmo_temp_files.txt")
          return true
        end)

        if not remove_success then
          logger.warn("Failed to remove temporary file", {
            file = "firmo_temp_files.txt",
          })
        end
      else
        logger.error("Failed to read temporary file list", {
          file = "firmo_temp_files.txt",
          error = error_handler.format_error(read_err),
        })
        return {}, read_err
      end

      logger.debug("Test files discovered (fallback method)", {
        directory = dir,
        pattern = pattern,
        count = #files,
      })

      return files
    end
  end

  -- Run a single test file with improved error handling
  function firmo.run_file(file)
    -- Parameter validation
    if not file then
      local err = error_handler.validation_error("File path cannot be nil", {
        parameter = "file",
        function_name = "run_file",
      })

      logger.error("Parameter validation failed", {
        error = error_handler.format_error(err),
        operation = "run_file",
      })
      return { success = false, errors = 1 }, err
    end

    if type(file) ~= "string" then
      local err = error_handler.validation_error("File path must be a string", {
        parameter = "file",
        provided_type = type(file),
        function_name = "run_file",
      })

      logger.error("Parameter validation failed", {
        error = error_handler.format_error(err),
        operation = "run_file",
      })
      return { success = false, errors = 1 }, err
    end

    -- Reset test state
    firmo.reset()

    logger.debug("Running test file", {
      file = file,
    })

    -- Load the test file using error_handler.try
    ---@diagnostic disable-next-line: unused-local
    local success, result, load_err = error_handler.try(function()
      -- First check if the file exists
      ---@diagnostic disable-next-line: need-check-nil
      local exists, exists_err = fs.file_exists(file)
      if not exists then
        return nil, error_handler.io_error("Test file does not exist", {
          file = file,
        }, exists_err)
      end

      -- Attempt to load the file
      local chunk, err = loadfile(file)
      if not chunk then
        return nil,
          error_handler.parse_error("Failed to load test file", {
            file = file,
            parse_error = err,
          })
      end

      -- Execute the test file in a protected call
      local ok, result = pcall(chunk)
      if not ok then
        return nil, error_handler.runtime_error("Error executing test file", {
          file = file,
        }, result)
      end

      return true
    end)

    if not success or not result then
      local err = result -- In case of failure, result contains the error

      logger.error("Failed to run test file", {
        file = file,
        error = error_handler.format_error(err),
      })

      return {
        success = false,
        errors = 1,
        file = file,
      }, err
    end

    -- Determine if tests passed based on error count
    local test_results = {
      success = firmo.errors == 0,
      passes = firmo.passes,
      errors = firmo.errors,
      skipped = firmo.skipped,
      file = file,
    }

    if test_results.success then
      logger.debug("Test file completed successfully", {
        file = file,
        passes = test_results.passes,
        skipped = test_results.skipped,
      })
    else
      logger.warn("Test file completed with errors", {
        file = file,
        errors = test_results.errors,
        passes = test_results.passes,
        skipped = test_results.skipped,
      })
    end

    return test_results
  end

  -- Run all discovered test files with improved error handling
  function firmo.run_discovered(dir, pattern)
    local files, err = firmo.discover(dir, pattern)

    -- Handle discovery errors
    if err then
      logger.error("Failed to discover test files", {
        directory = dir or "./tests",
        pattern = pattern,
        error = error_handler.format_error(err),
      })
      return false, err
    end

    -- Handle empty result
    if #files == 0 then
      local warning_context = {
        directory = dir or "./tests",
        pattern = pattern or "*_test.lua",
      }

      logger.warn("No test files found", warning_context)

      return false,
        error_handler.create(
          "No test files found",
          error_handler.CATEGORY.CONFIGURATION,
          error_handler.SEVERITY.WARNING,
          warning_context
        )
    end

    logger.debug("Running discovered test files", {
      count = #files,
      directory = dir or "./tests",
      pattern = pattern or "*_test.lua",
    })

    local success = true
    local error_files = {}

    for _, file in ipairs(files) do
      local file_results, file_err = firmo.run_file(file)

      if file_err then
        logger.error("Failed to run test file", {
          file = file,
          error = error_handler.format_error(file_err),
        })
        table.insert(error_files, { file = file, error = file_err })
        success = false
      elseif not file_results.success or file_results.errors > 0 then
        success = false
      end
    end

    if #error_files > 0 then
      logger.error("Some test files could not be executed", {
        error_count = #error_files,
        total_files = #files,
      })
    end

    return success,
      (#error_files > 0) and error_handler.create(
        string.format("%d of %d test files failed to execute", #error_files, #files),
        error_handler.CATEGORY.RUNTIME,
        error_handler.SEVERITY.ERROR,
        { error_files = error_files }
      ) or nil
  end

  -- CLI runner function for command-line usage
  function firmo.cli_run(args)
    args = args or {}
    local options = {
      dir = "./tests",
      pattern = "*_test.lua",
      files = {},
      tags = {},
      watch = false,
      interactive = false,
      coverage = false,
      quality = false,
      quality_level = 1,
      format = "summary",

      -- Report configuration options
      report_dir = "./coverage-reports",
      report_suffix = nil,
      coverage_path_template = nil,
      quality_path_template = nil,
      results_path_template = nil,
      timestamp_format = "%Y-%m-%d",
      verbose = false,

      -- Custom formatter options
      coverage_format = nil, -- Custom format for coverage reports
      quality_format = nil, -- Custom format for quality reports
      results_format = nil, -- Custom format for test results
      formatter_module = nil, -- Custom formatter module to load
    }

    -- Parse command line arguments
    local i = 1
    while i <= #args do
      local arg = args[i]
      if arg == "--watch" or arg == "-w" then
        options.watch = true
        i = i + 1
      elseif arg == "--interactive" or arg == "-i" then
        options.interactive = true
        i = i + 1
      elseif arg == "--coverage" or arg == "-c" then
        options.coverage = true
        i = i + 1
      elseif arg == "--quality" or arg == "-q" then
        options.quality = true
        i = i + 1
      elseif arg == "--quality-level" or arg == "-ql" then
        if args[i + 1] and tonumber(args[i + 1]) then
          options.quality_level = tonumber(args[i + 1])
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--format" or arg == "-f" then
        if args[i + 1] then
          options.format = args[i + 1]
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--dir" or arg == "-d" then
        if args[i + 1] then
          options.dir = args[i + 1]
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--pattern" or arg == "-p" then
        if args[i + 1] then
          options.pattern = args[i + 1]
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--tag" or arg == "-t" then
        if args[i + 1] then
          table.insert(options.tags, args[i + 1])
          i = i + 2
        else
          i = i + 1
        end
      -- Report configuration options
      elseif arg == "--output-dir" and args[i + 1] then
        options.report_dir = args[i + 1]
        i = i + 2
      elseif arg == "--report-suffix" and args[i + 1] then
        options.report_suffix = args[i + 1]
        i = i + 2
      elseif arg == "--coverage-path" and args[i + 1] then
        options.coverage_path_template = args[i + 1]
        i = i + 2
      elseif arg == "--quality-path" and args[i + 1] then
        options.quality_path_template = args[i + 1]
        i = i + 2
      elseif arg == "--results-path" and args[i + 1] then
        options.results_path_template = args[i + 1]
        i = i + 2
      elseif arg == "--timestamp-format" and args[i + 1] then
        options.timestamp_format = args[i + 1]
        i = i + 2
      elseif arg == "--verbose-reports" then
        options.verbose = true
        i = i + 1
      -- Custom formatter options
      elseif arg == "--coverage-format" and args[i + 1] then
        options.coverage_format = args[i + 1]
        i = i + 2
      elseif arg == "--quality-format" and args[i + 1] then
        options.quality_format = args[i + 1]
        i = i + 2
      elseif arg == "--results-format" and args[i + 1] then
        options.results_format = args[i + 1]
        i = i + 2
      elseif arg == "--formatter-module" and args[i + 1] then
        options.formatter_module = args[i + 1]
        i = i + 2
      elseif arg == "--help" or arg == "-h" then
        firmo.show_help()
        return true
      elseif not arg:match("^%-") then
        -- Not a flag, assume it's a file
        table.insert(options.files, arg)
        i = i + 1
      else
        -- Skip unknown options
        i = i + 1
      end
    end

    -- Set tags if specified
    if #options.tags > 0 then
      firmo.active_tags = options.tags
    end

    -- Load custom formatter module if specified
    if options.formatter_module and reporting then
      local ok, custom_formatters = pcall(require, options.formatter_module)
      if ok and custom_formatters then
        logger.info("Loading custom formatters", {
          module = options.formatter_module,
        })

        local count = reporting.load_formatters(custom_formatters)

        logger.info("Registered custom formatters", {
          count = count,
        })

        -- Get list of available formatters for display
        local formatters = reporting.get_available_formatters()
        logger.info("Available formatters", {
          coverage = table.concat(formatters.coverage, ", "),
          quality = table.concat(formatters.quality, ", "),
          results = table.concat(formatters.results, ", "),
        })
      else
        logger.error("Failed to load custom formatter module", {
          module = options.formatter_module,
          error = custom_formatters,
        })
      end
    end

    -- Set coverage format from CLI if specified
    if options.coverage_format then
      options.format = options.coverage_format
    end

    -- Configure report options
    local report_config = {
      report_dir = options.report_dir,
      report_suffix = options.report_suffix,
      coverage_path_template = options.coverage_path_template,
      quality_path_template = options.quality_path_template,
      results_path_template = options.results_path_template,
      timestamp_format = options.timestamp_format,
      verbose = options.verbose,
    }

    -- Set quality options
    if options.quality and quality then
      quality.init(firmo, {
        enabled = true,
        level = options.quality_level,
        format = options.quality_format or options.format,
        report_config = report_config,
      })
    end

    -- Set coverage options
    if options.coverage and coverage then
      coverage.init(firmo, {
        enabled = true,
        format = options.format,
        report_config = report_config,
      })
    end

    -- Store report config for other modules to use
    firmo.report_config = report_config

    -- Store custom format settings
    if options.results_format then
      firmo.results_format = options.results_format
    end

    -- If interactive mode is enabled and the module is available
    if options.interactive and interactive then
      interactive.run(firmo, options)
      return true
    end

    -- If watch mode is enabled and the module is available
    if options.watch and watcher then
      watcher.init({ "." }, { "node_modules", "%.git" })

      -- Run tests
      local run_tests = function()
        firmo.reset()
        if #options.files > 0 then
          -- Run specific files
          for _, file in ipairs(options.files) do
            firmo.run_file(file)
          end
        else
          -- Run all discovered tests
          firmo.run_discovered(options.dir)
        end
      end

      -- Initial test run
      run_tests()

      -- Watch loop
      logger.info("Watching for changes", {
        message = "Press Ctrl+C to exit",
      })

      while true do
        local changes = watcher.check_for_changes()
        if changes then
          logger.info("File changes detected", {
            action = "re-running tests",
          })
          run_tests()
        end
        os.execute("sleep 0.5")
      end

      return true
    end

    -- Run tests normally (no watch mode or interactive mode)
    if #options.files > 0 then
      -- Run specific files
      local success = true
      for _, file in ipairs(options.files) do
        local file_results = firmo.run_file(file)
        if not file_results.success or file_results.errors > 0 then
          success = false
        end
      end

      -- Exit with appropriate code
      return success
    else
      -- Run all discovered tests
      local success = firmo.run_discovered(options.dir, options.pattern)
      return success
    end
  end
else
  -- Stub functions when the discovery module isn't available
  function firmo.discover()
    return {}
  end

  function firmo.run_discovered()
    return false
  end

  function firmo.cli_run()
    logger.error("Test discovery not available", {
      reason = "Required module not found",
      component = "discover",
    })
    return false
  end
end

-- Reset function to clear state between test runs
function firmo.reset()
  -- Reset test state variables
  firmo.level = 0
  firmo.passes = 0
  firmo.errors = 0
  firmo.befores = {}
  firmo.afters = {}
  firmo.active_tags = {}
  firmo.current_tags = {}
  firmo.focus_mode = false
  firmo.skipped = 0

  -- Reset assertion count if tracking is enabled
  firmo.assertion_count = 0

  -- Reset the async module if available
  if async_module and async_module.reset then
    async_module.reset()
  end

  -- Preserve the paths table because it's essential for expect assertions
  -- DO NOT reset or clear the paths table

  -- Free memory
  collectgarbage()

  -- Return firmo to allow for chaining
  return firmo
end

-- Coverage options
firmo.coverage_options = {
  enabled = false, -- Whether coverage is enabled
  include = { ".*%.lua$" }, -- Files to include in coverage
  exclude = { "test_", "_spec%.lua$", "_test%.lua$" }, -- Files to exclude
  threshold = 80, -- Coverage threshold percentage
  format = "summary", -- Report format (summary, json, html, lcov)
  output = nil, -- Custom output file path (if nil, html/lcov auto-saved to ./coverage-reports/)
}

-- Code quality options
firmo.codefix_options = {
  enabled = false, -- Enable code fixing functionality
  verbose = false, -- Enable verbose output
  debug = false, -- Enable debug output

  -- StyLua options
  use_stylua = true, -- Use StyLua for formatting
  stylua_path = "stylua", -- Path to StyLua executable

  -- Luacheck options
  use_luacheck = true, -- Use Luacheck for linting
  luacheck_path = "luacheck", -- Path to Luacheck executable

  -- Custom fixers
  custom_fixers = {
    trailing_whitespace = true, -- Fix trailing whitespace in strings
    unused_variables = true, -- Fix unused variables by prefixing with underscore
    string_concat = true, -- Optimize string concatenation
    type_annotations = false, -- Add type annotations (disabled by default)
    lua_version_compat = false, -- Fix Lua version compatibility issues (disabled by default)
  },
}

-- Quality options
firmo.quality_options = {
  enabled = false, -- Whether test quality validation is enabled
  level = 1, -- Quality level to enforce (1-5)
  strict = false, -- Whether to fail on first quality issue
  format = "summary", -- Report format (summary, json, html)
  output = nil, -- Output file path (nil for console)
}

-- Output formatting options
firmo.format_options = {
  use_color = true, -- Whether to use color codes in output
  indent_char = "\t", -- Character to use for indentation (tab or spaces)
  indent_size = 1, -- How many indent_chars to use per level
  show_trace = false, -- Show stack traces for errors
  show_success_detail = true, -- Show details for successful tests
  compact = false, -- Use compact output format (less verbose)
  dot_mode = false, -- Use dot mode (. for pass, F for fail)
  summary_only = false, -- Show only summary, not individual tests
}

-- Set up colors based on format options
local red = string.char(27) .. "[31m"
local green = string.char(27) .. "[32m"
local yellow = string.char(27) .. "[33m"
---@diagnostic disable-next-line: unused-local
local blue = string.char(27) .. "[34m"
---@diagnostic disable-next-line: unused-local
local magenta = string.char(27) .. "[35m"
local cyan = string.char(27) .. "[36m"
local normal = string.char(27) .. "[0m"

-- Helper function for indentation with configurable char and size
local function indent(level)
  level = level or firmo.level
  local indent_char = firmo.format_options.indent_char
  local indent_size = firmo.format_options.indent_size
  return string.rep(indent_char, level * indent_size)
end

-- Disable colors (for non-terminal output or color-blind users)
function firmo.nocolor()
  -- No need for parameter validation as this function takes no parameters

  logger.debug("Disabling colors in output", {
    function_name = "nocolor",
  })

  -- Apply change with error handling in case of any terminal-related issues
  local success, err = error_handler.try(function()
    firmo.format_options.use_color = false
    ---@diagnostic disable-next-line: unused-local
    red, green, yellow, blue, magenta, cyan, normal = "", "", "", "", "", "", ""
    return true
  end)

  if not success then
    logger.error("Failed to disable colors", {
      error = error_handler.format_error(err),
      function_name = "nocolor",
    })
    error_handler.throw(
      "Failed to disable colors: " .. error_handler.format_error(err),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "nocolor" }
    )
  end

  return firmo
end

-- Configure output formatting options
function firmo.format(options)
  -- Parameter validation
  if options == nil then
    local err = error_handler.validation_error("Options cannot be nil", {
      parameter = "options",
      function_name = "format",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "format",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if type(options) ~= "table" then
    local err = error_handler.validation_error("Options must be a table", {
      parameter = "options",
      provided_type = type(options),
      function_name = "format",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "format",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  logger.debug("Configuring format options", {
    function_name = "format",
    option_count = (options and type(options) == "table") and #options or 0,
  })

  -- Apply format options with error handling
  local unknown_options = {}
  local success, apply_err = error_handler.try(function()
    for k, v in pairs(options) do
      if firmo.format_options[k] ~= nil then
        firmo.format_options[k] = v
      else
        table.insert(unknown_options, k)
      end
    end
    return true
  end)

  -- Handle unknown options
  if #unknown_options > 0 then
    local err = error_handler.validation_error("Unknown format option(s): " .. table.concat(unknown_options, ", "), {
      function_name = "format",
      unknown_options = unknown_options,
      valid_options = (function()
        local opts = {}
        for k, _ in pairs(firmo.format_options) do
          table.insert(opts, k)
        end
        return table.concat(opts, ", ")
      end)(),
    })

    logger.error("Unknown format options provided", {
      error = error_handler.format_error(err),
      operation = "format",
      unknown_options = unknown_options,
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  -- Handle general application errors
  if not success then
    logger.error("Failed to apply format options", {
      error = error_handler.format_error(apply_err),
      operation = "format",
    })

    error_handler.throw(
      "Failed to apply format options: " .. error_handler.format_error(apply_err),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "format" }
    )
  end

  -- Update colors if needed
  local color_success, color_err = error_handler.try(function()
    if not firmo.format_options.use_color then
      -- Call nocolor but catch errors explicitly here
      firmo.format_options.use_color = false
      ---@diagnostic disable-next-line: unused-local
      red, green, yellow, blue, magenta, cyan, normal = "", "", "", "", "", "", ""
    else
      red = string.char(27) .. "[31m"
      green = string.char(27) .. "[32m"
      yellow = string.char(27) .. "[33m"
      ---@diagnostic disable-next-line: unused-local
      blue = string.char(27) .. "[34m"
      ---@diagnostic disable-next-line: unused-local
      magenta = string.char(27) .. "[35m"
      cyan = string.char(27) .. "[36m"
      normal = string.char(27) .. "[0m"
    end
    return true
  end)

  if not color_success then
    logger.error("Failed to update color settings", {
      error = error_handler.format_error(color_err),
      operation = "format",
      use_color = firmo.format_options.use_color,
    })

    error_handler.throw(
      "Failed to update color settings: " .. error_handler.format_error(color_err),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "format", use_color = firmo.format_options.use_color }
    )
  end

  logger.debug("Format options configured successfully", {
    function_name = "format",
    use_color = firmo.format_options.use_color,
    show_trace = firmo.format_options.show_trace,
    indent_char = firmo.format_options.indent_char == "\t" and "tab" or "space",
  })

  return firmo
end

-- The main describe function with support for focus and exclusion
function firmo.describe(name, fn, options)
  -- Parameter validation
  if name == nil then
    local err = error_handler.validation_error("Describe name cannot be nil", {
      parameter = "name",
      function_name = "describe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "describe",
    })

    firmo.errors = firmo.errors + 1
    print(indent() .. red .. "ERROR" .. normal .. " Invalid describe block (missing name)")
    return
  end

  if type(name) ~= "string" then
    local err = error_handler.validation_error("Describe name must be a string", {
      parameter = "name",
      provided_type = type(name),
      function_name = "describe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "describe",
    })

    firmo.errors = firmo.errors + 1
    print(indent() .. red .. "ERROR" .. normal .. " Invalid describe name (must be string)")
    return
  end

  if fn == nil then
    local err = error_handler.validation_error("Describe function cannot be nil", {
      parameter = "fn",
      describe_name = name,
      function_name = "describe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "describe",
      describe_name = name,
    })

    firmo.errors = firmo.errors + 1
    print(indent() .. red .. "ERROR" .. normal .. " Invalid describe block '" .. name .. "' (missing function)")
    return
  end

  if type(fn) ~= "function" then
    local err = error_handler.validation_error("Describe requires a function", {
      parameter = "fn",
      provided_type = type(fn),
      describe_name = name,
      function_name = "describe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "describe",
      describe_name = name,
    })

    firmo.errors = firmo.errors + 1
    print(indent() .. red .. "ERROR" .. normal .. " Invalid describe block '" .. name .. "' (fn must be function)")
    return
  end

  if type(options) == "function" then
    -- Handle case where options is actually a function (support for tags("tag")(fn) syntax)
    fn = options
    options = {}
  end

  options = options or {}
  local focused = options.focused or false
  local excluded = options.excluded or false

  -- If this is a focused describe block, mark that we're in focus mode
  if focused then
    firmo.focus_mode = true
  end

  -- Only print in non-summary mode and non-dot mode
  if not firmo.format_options.summary_only and not firmo.format_options.dot_mode then
    -- Print description with appropriate formatting
    if excluded then
      print(indent() .. yellow .. "SKIP" .. normal .. " " .. name)
    else
      local prefix = focused and cyan .. "FOCUS " .. normal or ""
      print(indent() .. prefix .. name)
    end
  end

  -- If excluded, don't execute the function
  if excluded then
    return
  end

  logger.trace("Entering describe block", {
    name = name,
    level = firmo.level + 1,
    focused = focused,
    tags = #firmo.current_tags > 0 and table.concat(firmo.current_tags, ", ") or nil,
  })

  firmo.level = firmo.level + 1

  -- Save current tags and focus state to restore them after the describe block
  local prev_tags = {}
  for i, tag in ipairs(firmo.current_tags) do
    prev_tags[i] = tag
  end

  -- Store the current focus state at this level
  ---@diagnostic disable-next-line: unused-local
  local prev_focused = options._parent_focused or focused

  -- Run the function with improved error handling
  local success, err = error_handler.try(function()
    fn()
    return true
  end)

  -- Reset current tags to what they were before the describe block
  firmo.current_tags = prev_tags

  firmo.befores[firmo.level] = {}
  firmo.afters[firmo.level] = {}
  firmo.level = firmo.level - 1

  logger.trace("Exiting describe block", {
    name = name,
    level = firmo.level,
    success = success,
  })

  -- If there was an error in the describe block, report it
  if not success then
    firmo.errors = firmo.errors + 1

    -- Convert error to structured error if it's not already
    if not error_handler.is_error(err) then
      err = error_handler.runtime_error(tostring(err), {
        describe = name,
        level = firmo.level,
      })
    end

    logger.error("Error in describe block", {
      describe = name,
      error = error_handler.format_error(err),
      level = firmo.level,
    })

    -- Display error according to format options
    if not firmo.format_options.summary_only then
      print(indent() .. red .. "ERROR" .. normal .. " in describe '" .. name .. "'")

      if firmo.format_options.show_trace then
        -- Show the full stack trace
        print(indent(firmo.level + 1) .. red .. (err.traceback or debug.traceback(tostring(err), 2)) .. normal)
      else
        -- Show just the error message
        print(indent(firmo.level + 1) .. red .. error_handler.format_error(err) .. normal)
      end
    elseif firmo.format_options.dot_mode then
      -- In dot mode, print an 'E' for error
      io.write(red .. "E" .. normal)
    end
  end
end -- End of describe function

-- Focused version of describe
function firmo.fdescribe(name, fn)
  -- Parameter validation
  if name == nil then
    local err = error_handler.validation_error("Name cannot be nil", {
      parameter = "name",
      function_name = "fdescribe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "fdescribe",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if type(name) ~= "string" then
    local err = error_handler.validation_error("Name must be a string", {
      parameter = "name",
      provided_type = type(name),
      function_name = "fdescribe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "fdescribe",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if fn == nil then
    local err = error_handler.validation_error("Function cannot be nil", {
      parameter = "fn",
      function_name = "fdescribe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "fdescribe",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if type(fn) ~= "function" then
    local err = error_handler.validation_error("Second parameter must be a function", {
      parameter = "fn",
      provided_type = type(fn),
      function_name = "fdescribe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "fdescribe",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  logger.debug("Creating focused describe block", {
    function_name = "fdescribe",
    name = name,
  })

  ---@diagnostic disable-next-line: unused-local
  local success, result, err = error_handler.try(function()
    return firmo.describe(name, fn, { focused = true })
  end)

  if not success then
    logger.error("Failed to create focused describe block", {
      error = error_handler.format_error(result),
      function_name = "fdescribe",
      name = name,
    })

    error_handler.throw(
      "Failed to create focused describe block: " .. error_handler.format_error(result),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "fdescribe", name = name }
    )
  end

  return result
end

-- Excluded version of describe
function firmo.xdescribe(name, fn)
  -- Parameter validation
  if name == nil then
    local err = error_handler.validation_error("Name cannot be nil", {
      parameter = "name",
      function_name = "xdescribe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "xdescribe",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if type(name) ~= "string" then
    local err = error_handler.validation_error("Name must be a string", {
      parameter = "name",
      provided_type = type(name),
      function_name = "xdescribe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "xdescribe",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  -- fn can be nil for xdescribe since we're skipping it anyway
  if fn ~= nil and type(fn) ~= "function" then
    local err = error_handler.validation_error("Second parameter must be a function if provided", {
      parameter = "fn",
      provided_type = type(fn),
      function_name = "xdescribe",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "xdescribe",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  logger.debug("Creating excluded describe block", {
    function_name = "xdescribe",
    name = name,
  })

  ---@diagnostic disable-next-line: unused-local
  local success, result, err = error_handler.try(function()
    -- Use an empty function to ensure none of the tests within it ever run
    -- This is more robust than just marking it excluded
    return firmo.describe(name, function() end, { excluded = true })
  end)

  if not success then
    logger.error("Failed to create excluded describe block", {
      error = error_handler.format_error(result),
      function_name = "xdescribe",
      name = name,
    })

    error_handler.throw(
      "Failed to create excluded describe block: " .. error_handler.format_error(result),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "xdescribe", name = name }
    )
  end

  return result
end

-- Set tags for the current describe block or test
function firmo.tags(...)
  local tags_list = { ... }

  logger.debug("Setting tags", {
    function_name = "tags",
    tag_count = #tags_list,
    tags = #tags_list > 0 and table.concat(tags_list, ", ") or "none",
  })

  -- Validate the tags
  local success, err = error_handler.try(function()
    -- Validate each tag is a string
    for i, tag in ipairs(tags_list) do
      if type(tag) ~= "string" then
        error_handler.throw("Tag must be a string", error_handler.CATEGORY.VALIDATION, error_handler.SEVERITY.ERROR, {
          tag_index = i,
          provided_type = type(tag),
          function_name = "tags",
        })
      end
    end

    -- Allow both tags("one", "two") and tags("one")("two") syntax
    if #tags_list == 1 and type(tags_list[1]) == "string" then
      -- Handle tags("tag1", "tag2", ...) syntax
      firmo.current_tags = tags_list

      -- Return a function that can be called again to allow tags("tag1")("tag2")(fn) syntax
      return function(fn_or_tag)
        if type(fn_or_tag) == "function" then
          -- If it's a function, it's the test/describe function
          return fn_or_tag
        else
          -- Validate the tag
          if type(fn_or_tag) ~= "string" then
            error_handler.throw(
              "Tag must be a string",
              error_handler.CATEGORY.VALIDATION,
              error_handler.SEVERITY.ERROR,
              {
                provided_type = type(fn_or_tag),
                function_name = "tags(chain)",
              }
            )
          end

          -- If it's another tag, add it
          table.insert(firmo.current_tags, fn_or_tag)
          -- Return itself again to allow chaining
          return firmo.tags()
        end
      end
    else
      -- Store the tags
      firmo.current_tags = tags_list
      return firmo
    end
  end)

  -- Handle errors
  if not success then
    logger.error("Failed to set tags", {
      error = error_handler.format_error(err),
      function_name = "tags",
    })

    error_handler.throw(
      "Failed to set tags: " .. error_handler.format_error(err),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "tags" }
    )
  end

  return firmo
end

-- Filter tests to only run those matching specific tags
function firmo.only_tags(...)
  local tags = { ... }

  logger.debug("Filtering by tags", {
    function_name = "only_tags",
    tag_count = #tags,
    tags = #tags > 0 and table.concat(tags, ", ") or "none",
  })

  -- Validate the tags
  local success, err = error_handler.try(function()
    -- Validate each tag is a string
    for i, tag in ipairs(tags) do
      if type(tag) ~= "string" then
        error_handler.throw("Tag must be a string", error_handler.CATEGORY.VALIDATION, error_handler.SEVERITY.ERROR, {
          tag_index = i,
          provided_type = type(tag),
          function_name = "only_tags",
        })
      end
    end

    -- Set the active tags
    firmo.active_tags = tags
    return true
  end)

  -- Handle errors
  if not success then
    logger.error("Failed to set tag filter", {
      error = error_handler.format_error(err),
      function_name = "only_tags",
    })

    error_handler.throw(
      "Failed to set tag filter: " .. error_handler.format_error(err),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "only_tags" }
    )
  end

  return firmo
end

-- Filter tests by name pattern
function firmo.filter(pattern)
  -- Parameter validation
  if pattern == nil then
    local err = error_handler.validation_error("Pattern cannot be nil", {
      parameter = "pattern",
      function_name = "filter",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "filter",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if type(pattern) ~= "string" then
    local err = error_handler.validation_error("Pattern must be a string", {
      parameter = "pattern",
      provided_type = type(pattern),
      function_name = "filter",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "filter",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  logger.debug("Setting test filter pattern", {
    function_name = "filter",
    pattern = pattern,
  })

  -- Apply the filter with error handling
  local success, err = error_handler.try(function()
    -- Verify the pattern is a valid Lua pattern
    -- This may raise an error if the pattern is invalid
    ---@diagnostic disable-next-line: discard-returns
    string.match("test", pattern)

    firmo.filter_pattern = pattern
    return true
  end)

  -- Handle errors
  if not success then
    local validation_err =
      error_handler.validation_error("Invalid filter pattern: " .. error_handler.format_error(err), {
        pattern = pattern,
        function_name = "filter",
        error = error_handler.format_error(err),
      })

    logger.error("Invalid filter pattern", {
      error = error_handler.format_error(validation_err),
      pattern = pattern,
      function_name = "filter",
    })

    error_handler.throw(
      validation_err.message,
      validation_err.category,
      validation_err.severity,
      validation_err.context
    )
  end

  return firmo
end

-- Reset all filters
function firmo.reset_filters()
  logger.debug("Resetting all filters", {
    function_name = "reset_filters",
    had_tags = #firmo.active_tags > 0,
    had_pattern = firmo.filter_pattern ~= nil,
  })

  -- Apply reset with error handling
  local success, err = error_handler.try(function()
    firmo.active_tags = {}
    firmo.filter_pattern = nil
    return true
  end)

  -- Handle errors
  if not success then
    logger.error("Failed to reset filters", {
      error = error_handler.format_error(err),
      function_name = "reset_filters",
    })

    error_handler.throw(
      "Failed to reset filters: " .. error_handler.format_error(err),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "reset_filters" }
    )
  end

  return firmo
end

-- Check if a test should run based on tags and pattern filtering
local function should_run_test(name, tags)
  -- Parameter validation
  if name == nil then
    logger.error("Test name cannot be nil", {
      function_name = "should_run_test",
    })
    error_handler.throw(
      "Test name cannot be nil",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      { function_name = "should_run_test" }
    )
  end

  if type(name) ~= "string" then
    logger.error("Test name must be a string", {
      function_name = "should_run_test",
      provided_type = type(name),
    })
    error_handler.throw(
      "Test name must be a string",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      { function_name = "should_run_test", provided_type = type(name) }
    )
  end

  if tags == nil then
    logger.error("Tags cannot be nil", {
      function_name = "should_run_test",
    })
    error_handler.throw(
      "Tags cannot be nil",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      { function_name = "should_run_test" }
    )
  end

  if type(tags) ~= "table" then
    logger.error("Tags must be a table", {
      function_name = "should_run_test",
      provided_type = type(tags),
    })
    error_handler.throw(
      "Tags must be a table",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      { function_name = "should_run_test", provided_type = type(tags) }
    )
  end

  -- Use error_handler.try for the implementation
  ---@diagnostic disable-next-line: unused-local
  local success, result, err = error_handler.try(function()
    -- If no filters are set, run everything
    if #firmo.active_tags == 0 and not firmo.filter_pattern then
      return true
    end

    -- Check pattern filter
    if firmo.filter_pattern then
      local pattern_match_success, pattern_match_result = pcall(function()
        return name:match(firmo.filter_pattern)
      end)

      if not pattern_match_success then
        error_handler.throw(
          "Error matching pattern: " .. tostring(pattern_match_result),
          error_handler.CATEGORY.RUNTIME,
          error_handler.SEVERITY.ERROR,
          {
            function_name = "should_run_test",
            pattern = firmo.filter_pattern,
            name = name,
          }
        )
      end

      if not pattern_match_result then
        return false
      end
    end

    -- If we have tags filter but no tags on this test, skip it
    if #firmo.active_tags > 0 and #tags == 0 then
      return false
    end

    -- Check tag filters
    if #firmo.active_tags > 0 then
      for _, activeTag in ipairs(firmo.active_tags) do
        for _, testTag in ipairs(tags) do
          if activeTag == testTag then
            return true
          end
        end
      end
      return false
    end

    return true
  end)

  -- Handle errors
  if not success then
    logger.error("Failed to check if test should run", {
      error = error_handler.format_error(result),
      function_name = "should_run_test",
      name = name,
      tag_count = #tags,
    })

    error_handler.throw(
      "Failed to check if test should run: " .. error_handler.format_error(result),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      {
        function_name = "should_run_test",
        name = name,
        tag_count = #tags,
      }
    )
  end

  return result
end

function firmo.it(name, fn, options)
  -- Parameter validation
  if name == nil then
    local err = error_handler.validation_error("Test name cannot be nil", {
      parameter = "name",
      function_name = "it",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "it",
    })

    firmo.errors = firmo.errors + 1
    print(indent() .. red .. "ERROR" .. normal .. " Invalid test (missing name)")
    return
  end

  if type(name) ~= "string" then
    local err = error_handler.validation_error("Test name must be a string", {
      parameter = "name",
      provided_type = type(name),
      function_name = "it",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "it",
    })

    firmo.errors = firmo.errors + 1
    print(indent() .. red .. "ERROR" .. normal .. " Invalid test name (must be string)")
    return
  end

  if fn == nil then
    local err = error_handler.validation_error("Test function cannot be nil", {
      parameter = "fn",
      test_name = name,
      function_name = "it",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "it",
      test_name = name,
    })

    firmo.errors = firmo.errors + 1
    print(indent() .. red .. "ERROR" .. normal .. " Missing function for test '" .. name .. "'")
    return
  end

  if type(fn) ~= "function" and type(fn) ~= "table" then
    -- We allow tables because async tests may return a table with promises
    local err = error_handler.validation_error("Test requires a function or async result", {
      parameter = "fn",
      provided_type = type(fn),
      test_name = name,
      function_name = "it",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "it",
      test_name = name,
    })

    firmo.errors = firmo.errors + 1
    print(indent() .. red .. "ERROR" .. normal .. " Invalid function for test '" .. name .. "'")
    return
  end

  options = options or {}
  
  local focused = options.focused or false
  local excluded = options.excluded or false
  local expect_error = options.expect_error or false

  -- If this is a focused test, mark that we're in focus mode
  if focused then
    firmo.focus_mode = true
  end
  
  -- Create test metadata
  local test_metadata = {
    name = name,
    expect_error = expect_error,
    focused = focused,
    excluded = excluded,
  }

  -- Save current tags for this test
  local test_tags = {}
  for _, tag in ipairs(firmo.current_tags) do
    table.insert(test_tags, tag)
  end

  -- Determine if this test should be run
  -- Skip if:
  -- 1. It's explicitly excluded, or
  -- 2. Focus mode is active but this test is not focused, or
  -- 3. It doesn't match the filter pattern or tags
  local should_skip = excluded or (firmo.focus_mode and not focused) or (not should_run_test(name, test_tags))

  if should_skip then
    -- Skip test but still print it as skipped
    firmo.skipped = firmo.skipped + 1

    local skip_reason = ""
    if excluded then
      skip_reason = " (excluded)"
    elseif firmo.focus_mode and not focused then
      skip_reason = " (not focused)"
    end

    logger.debug("Skipping test", {
      test = name,
      reason = skip_reason:gsub("^%s+", ""),
      level = firmo.level,
    })

    if not firmo.format_options.summary_only and not firmo.format_options.dot_mode then
      print(indent() .. yellow .. "SKIP" .. normal .. " " .. name .. skip_reason)
    elseif firmo.format_options.dot_mode then
      -- In dot mode, print an 'S' for skipped
      io.write(yellow .. "S" .. normal)
    end
    return
  end

  logger.trace("Running test", {
    test = name,
    level = firmo.level,
    focused = focused,
    tags = #test_tags > 0 and table.concat(test_tags, ", ") or nil,
  })

  -- Run before hooks with error handling
  local before_errors = {}
  for level = 1, firmo.level do
    if firmo.befores[level] then
      for i = 1, #firmo.befores[level] do
        local before_fn = firmo.befores[level][i]

        -- Skip invalid before hooks
        if type(before_fn) ~= "function" then
          table.insert(
            before_errors,
            error_handler.validation_error("Invalid before hook (not a function)", {
              level = level,
              index = i,
              provided_type = type(before_fn),
            })
          )
          goto continue_befores
        end

        -- Run before hook with error handling
        local before_success, before_err = error_handler.try(function()
          -- Set test metadata before executing the before hook
          local error_handler = require("lib.tools.error_handler")
          error_handler.set_current_test_metadata(test_metadata)
          
          -- Execute the before hook
          before_fn(name)
          
          -- Clear test metadata after execution
          error_handler.set_current_test_metadata(nil)
          
          return true
        end)

        if not before_success then
          -- Create structured error
          if not error_handler.is_error(before_err) then
            before_err = error_handler.runtime_error("Error in before hook: " .. tostring(before_err), {
              test = name,
              level = level,
              hook_index = i,
            })
          end

          table.insert(before_errors, before_err)

          logger.error("Error in before hook", {
            test = name,
            level = level,
            hook_index = i,
            error = error_handler.format_error(before_err),
          })
        end

        ::continue_befores::
      end
    end
  end

  -- Check if we had any errors in before hooks
  local had_before_errors = #before_errors > 0

  -- Handle both regular and async tests
  local success, err

  if not had_before_errors then
    -- Only run the test if before hooks succeeded
    if type(fn) == "function" then
      -- Run test with proper error handling
      success, err = error_handler.try(function()
        -- Set test metadata before executing the test
        local error_handler = require("lib.tools.error_handler")
        error_handler.set_current_test_metadata(test_metadata)
        
        -- Execute the test
        fn()
        
        -- Clear test metadata after execution
        error_handler.set_current_test_metadata(nil)
        
        return true
      end)
    else
      -- If it's not a function, it might be the result of an async test that already completed
      success, err = true, fn
    end
  else
    -- Before hooks failed, but if the test expects errors, we'll still consider it a success
    if expect_error then
      -- This test expects errors, so treat it as a success even with before hook errors
      success = true
      err = nil
      logger.debug("Ignoring before hook errors for test with expect_error flag", {
        test = name,
        error_count = #before_errors,
      })
    else
      -- Not expecting errors, so the test fails due to before hook errors
      success = false
      err = error_handler.runtime_error(
        "Test not run due to errors in before hooks",
        {
          test = name,
          error_count = #before_errors,
        },
        before_errors[1] -- Chain to the first error
      )
    end
  end

  -- Convert error to structured error if needed
  if not success and not error_handler.is_error(err) then
    err = error_handler.runtime_error(tostring(err), {
      test = name,
      level = firmo.level,
    })
  end

  -- Update test counters
  if success then
    firmo.passes = firmo.passes + 1

    logger.debug("Test passed", {
      test = name,
      level = firmo.level,
    })
  else
    firmo.errors = firmo.errors + 1

    logger.error("Test failed", {
      test = name,
      error = error_handler.format_error(err),
      level = firmo.level,
    })
  end

  -- Output based on format options
  if firmo.format_options.dot_mode then
    -- In dot mode, just print a dot for pass, F for fail
    if success then
      io.write(green .. "." .. normal)
    else
      io.write(red .. "F" .. normal)
    end
  elseif not firmo.format_options.summary_only then
    -- Full output mode
    local color = success and green or red
    local label = success and "PASS" or "FAIL"
    local prefix = focused and cyan .. "FOCUS " .. normal or ""

    -- Only show successful tests details if configured to do so
    if success and not firmo.format_options.show_success_detail then
      if not firmo.format_options.compact then
        print(indent() .. color .. "." .. normal)
      end
    else
      print(indent() .. color .. label .. normal .. " " .. prefix .. name)
    end

    -- Show error details
    if err and not success then
      if firmo.format_options.show_trace then
        -- Show the full stack trace with proper formatting
        local traceback = err.traceback or debug.traceback(tostring(err), 2)
        print(indent(firmo.level + 1) .. red .. traceback .. normal)
      else
        -- Show just the error message with proper formatting
        print(indent(firmo.level + 1) .. red .. error_handler.format_error(err, false) .. normal)
      end

      -- Show any before hook errors if they exist and aren't already displayed
      if had_before_errors and not err.message:match("errors in before hooks") then
        print(indent(firmo.level + 1) .. red .. "Before hook errors:" .. normal)
        for i, hook_err in ipairs(before_errors) do
          print(indent(firmo.level + 2) .. red .. i .. ": " .. error_handler.format_error(hook_err, false) .. normal)
        end
      end
    end
  end

  -- Run after hooks with error handling
  local after_errors = {}
  for level = 1, firmo.level do
    if firmo.afters[level] then
      for i = 1, #firmo.afters[level] do
        local after_fn = firmo.afters[level][i]

        -- Skip invalid after hooks
        if type(after_fn) ~= "function" then
          logger.warn("Invalid after hook (not a function)", {
            level = level,
            index = i,
            provided_type = type(after_fn),
          })
          goto continue_afters
        end

        -- Run after hook with error handling
        local after_success, after_err = error_handler.try(function()
          -- Set test metadata before executing the after hook
          local error_handler = require("lib.tools.error_handler")
          error_handler.set_current_test_metadata(test_metadata)
          
          -- Execute the after hook
          after_fn(name)
          
          -- Clear test metadata after execution
          error_handler.set_current_test_metadata(nil)
          
          return true
        end)

        if not after_success then
          -- Create structured error
          if not error_handler.is_error(after_err) then
            after_err = error_handler.runtime_error("Error in after hook: " .. tostring(after_err), {
              test = name,
              level = level,
              hook_index = i,
            })
          end

          table.insert(after_errors, after_err)

          logger.error("Error in after hook", {
            test = name,
            level = level,
            hook_index = i,
            error = error_handler.format_error(after_err),
          })
        end

        ::continue_afters::
      end
    end
  end

  -- If we had after hook errors, display them unless the test expects errors
  if #after_errors > 0 then
    if expect_error then
      -- This test expects errors, so just log them at debug level
      logger.debug("Ignoring after hook errors for test with expect_error flag", {
        test = name,
        error_count = #after_errors,
      })
    elseif not firmo.format_options.summary_only then
      -- Display after hook errors for non-expect_error tests
      logger.error("Errors in after hooks", {
        test = name,
        error_count = #after_errors,
        first_error = error_handler.format_error(after_errors[1], false)
      })
      
      -- Still need to display visually in the test output
      for i, after_err in ipairs(after_errors) do
        if i == 1 then
          logger.error("ERRORS IN AFTER HOOKS:")
        end
        logger.error(i .. ": " .. error_handler.format_error(after_err, false))
      end
    end
  end

  -- Clear current tags after test
  firmo.current_tags = {}
end

-- Focused version of it
function firmo.fit(name, fn)
  -- Parameter validation
  if name == nil then
    local err = error_handler.validation_error("Name cannot be nil", {
      parameter = "name",
      function_name = "fit",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "fit",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if type(name) ~= "string" then
    local err = error_handler.validation_error("Name must be a string", {
      parameter = "name",
      provided_type = type(name),
      function_name = "fit",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "fit",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if fn == nil then
    local err = error_handler.validation_error("Function cannot be nil", {
      parameter = "fn",
      function_name = "fit",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "fit",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if type(fn) ~= "function" then
    local err = error_handler.validation_error("Second parameter must be a function", {
      parameter = "fn",
      provided_type = type(fn),
      function_name = "fit",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "fit",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  logger.debug("Creating focused test", {
    function_name = "fit",
    name = name,
  })

  ---@diagnostic disable-next-line: unused-local
  local success, result, err = error_handler.try(function()
    return firmo.it(name, fn, { focused = true })
  end)

  if not success then
    logger.error("Failed to create focused test", {
      error = error_handler.format_error(result),
      function_name = "fit",
      name = name,
    })

    error_handler.throw(
      "Failed to create focused test: " .. error_handler.format_error(result),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "fit", name = name }
    )
  end

  return result
end

-- Excluded version of it
function firmo.xit(name, fn)
  -- Parameter validation
  if name == nil then
    local err = error_handler.validation_error("Name cannot be nil", {
      parameter = "name",
      function_name = "xit",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "xit",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  if type(name) ~= "string" then
    local err = error_handler.validation_error("Name must be a string", {
      parameter = "name",
      provided_type = type(name),
      function_name = "xit",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "xit",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  -- fn can be nil for xit since we're skipping it anyway
  if fn ~= nil and type(fn) ~= "function" then
    local err = error_handler.validation_error("Second parameter must be a function if provided", {
      parameter = "fn",
      provided_type = type(fn),
      function_name = "xit",
    })

    logger.error("Parameter validation failed", {
      error = error_handler.format_error(err),
      operation = "xit",
    })

    error_handler.throw(err.message, err.category, err.severity, err.context)
  end

  logger.debug("Creating excluded test", {
    function_name = "xit",
    name = name,
  })

  ---@diagnostic disable-next-line: unused-local
  local success, result, err = error_handler.try(function()
    -- Important: Replace the function with a dummy that never runs
    -- This ensures the test is completely skipped, not just filtered
    return firmo.it(name, function() end, { excluded = true })
  end)

  if not success then
    logger.error("Failed to create excluded test", {
      error = error_handler.format_error(result),
      function_name = "xit",
      name = name,
    })

    error_handler.throw(
      "Failed to create excluded test: " .. error_handler.format_error(result),
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { function_name = "xit", name = name }
    )
  end

  return result
end

-- Asynchronous version of it
---@diagnostic disable-next-line: unused-local
function firmo.it_async(name, fn, timeout)
  if not async_module then
    error("it_async requires the async module to be available", 2)
  end

  -- Delegate to the async module for the implementation
  ---@diagnostic disable-next-line: redundant-parameter
  local async_fn = firmo.async(fn)
  return firmo.it(name, function()
    ---@diagnostic disable-next-line: need-check-nil
    return async_fn()()
  end)
end

-- Pending test helper
function firmo.pending(message)
  message = message or "Test not yet implemented"
  if not firmo.format_options.summary_only and not firmo.format_options.dot_mode then
    print(indent() .. yellow .. "PENDING: " .. normal .. message)
  elseif firmo.format_options.dot_mode then
    io.write(yellow .. "P" .. normal)
  end
  return message -- Return the message to allow it to be used as a return value
end

function firmo.before(fn)
  firmo.befores[firmo.level] = firmo.befores[firmo.level] or {}
  table.insert(firmo.befores[firmo.level], fn)
end

function firmo.after(fn)
  firmo.afters[firmo.level] = firmo.afters[firmo.level] or {}
  table.insert(firmo.afters[firmo.level], fn)
end

-- Assertions now provided by the standalone assertion module

-- Using assertion module's paths table
-- Export assertion paths for plugins and extensions
---@diagnostic disable-next-line: unused-local
local paths = assertion.paths

function firmo.expect(v)
  -- Count assertion
  firmo.assertion_count = (firmo.assertion_count or 0) + 1

  -- Track assertion in quality module if enabled
  if firmo.quality_options.enabled and quality then
    quality.track_assertion("expect", debug.getinfo(2, "n").name)
  end

  -- Use the standalone assertion module
  return assertion.expect(v)
end

-- Export assertion paths for plugins and extensions
local paths = assertion.paths

-- Load the mocking system directly from lib/mocking
package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path
local mocking_ok, mocking = pcall(require, "lib.mocking")

-- If the mocking module is available, use it
if mocking_ok and mocking then
  -- Export the mocking functionality to firmo
  firmo.spy = mocking.spy
  firmo.stub = mocking.stub
  firmo.mock = mocking.mock
  firmo.with_mocks = mocking.with_mocks
  firmo.arg_matcher = mocking.arg_matcher or {}

  -- Override the test runner to use our mocking system
  local original_it = firmo.it
  firmo.it = function(name, fn, options)
    -- Check if the parameter order needs to be swapped (options passed as second parameter)
    if type(fn) == "table" and type(options) == "function" then
      local temp = fn
      fn = options
      options = temp
    end
    
    -- Ensure options is a table
    options = type(options) == "table" and options or {}
    
    local wrapped_fn
    
    -- Also pass through expect_error flag
    local expect_error = options.expect_error or false

    if options.focused or options.excluded or expect_error then
      -- If this is a focused, excluded, or expect_error test, don't wrap it with mocking
      -- This prevents mocking from interfering with expected errors
      wrapped_fn = fn
    else
      -- Otherwise, wrap the function with mocking context
      wrapped_fn = function()
        return mocking.with_mocks(function()
          return fn()
        end)
      end
    end

    -- Make sure the expect_error flag is properly transferred
    local opt_copy = {}
    for k, v in pairs(options) do
      opt_copy[k] = v
    end
    
    -- Explicitly set the expect_error flag
    opt_copy.expect_error = expect_error
    
    return original_it(name, wrapped_fn, opt_copy)
  end
end

-- CLI Helper functions
function firmo.parse_args(args)
  local options = {
    dir = "./tests",
    format = "default",
    tags = {},
    filter = nil,
    files = {},
    interactive = false, -- Interactive CLI mode option
    watch = false, -- Watch mode option

    -- Report configuration options
    report_dir = "./coverage-reports",
    report_suffix = nil,
    coverage_path_template = nil,
    quality_path_template = nil,
    results_path_template = nil,
    timestamp_format = "%Y-%m-%d",
    verbose = false,

    -- Custom formatter options
    coverage_format = nil, -- Custom format for coverage reports
    quality_format = nil, -- Custom format for quality reports
    results_format = nil, -- Custom format for test results
    formatter_module = nil, -- Custom formatter module to load
  }

  local i = 1
  while i <= #args do
    if args[i] == "--dir" and args[i + 1] then
      options.dir = args[i + 1]
      i = i + 2
    elseif args[i] == "--format" and args[i + 1] then
      options.format = args[i + 1]
      i = i + 2
    elseif args[i] == "--tags" and args[i + 1] then
      for tag in args[i + 1]:gmatch("[^,]+") do
        table.insert(options.tags, tag:match("^%s*(.-)%s*$")) -- Trim whitespace
      end
      i = i + 2
    elseif args[i] == "--filter" and args[i + 1] then
      options.filter = args[i + 1]
      i = i + 2
    elseif args[i] == "--config" and args[i + 1] then
      -- Load configuration from file
      if central_config then
        local config_path = args[i + 1]
        local user_config, err = central_config.load_from_file(config_path)
        if not user_config and logger then
          logger.warn("Failed to load config file", {
            path = config_path,
            error = err and err.message or "unknown error",
          })
        end
      end
      i = i + 2
    elseif args[i] == "--create-config" then
      -- Create default configuration file
      if central_config then
        central_config.save_to_file()
      end
      i = i + 1
    elseif args[i] == "--help" or args[i] == "-h" then
      firmo.show_help()
      os.exit(0)
    elseif args[i] == "--file" and args[i + 1] then
      table.insert(options.files, args[i + 1])
      i = i + 2
    elseif args[i] == "--watch" or args[i] == "-w" then
      options.watch = true
      i = i + 1
    elseif args[i] == "--interactive" or args[i] == "-i" then
      options.interactive = true
      i = i + 1
    -- Report configuration options
    elseif args[i] == "--output-dir" and args[i + 1] then
      options.report_dir = args[i + 1]
      i = i + 2
    elseif args[i] == "--report-suffix" and args[i + 1] then
      options.report_suffix = args[i + 1]
      i = i + 2
    elseif args[i] == "--coverage-path" and args[i + 1] then
      options.coverage_path_template = args[i + 1]
      i = i + 2
    elseif args[i] == "--quality-path" and args[i + 1] then
      options.quality_path_template = args[i + 1]
      i = i + 2
    elseif args[i] == "--results-path" and args[i + 1] then
      options.results_path_template = args[i + 1]
      i = i + 2
    elseif args[i] == "--timestamp-format" and args[i + 1] then
      options.timestamp_format = args[i + 1]
      i = i + 2
    elseif args[i] == "--verbose-reports" then
      options.verbose = true
      i = i + 1
    -- Custom formatter options
    elseif args[i] == "--coverage-format" and args[i + 1] then
      options.coverage_format = args[i + 1]
      i = i + 2
    elseif args[i] == "--quality-format" and args[i + 1] then
      options.quality_format = args[i + 1]
      i = i + 2
    elseif args[i] == "--results-format" and args[i + 1] then
      options.results_format = args[i + 1]
      i = i + 2
    elseif args[i] == "--formatter-module" and args[i + 1] then
      options.formatter_module = args[i + 1]
      i = i + 2
    elseif args[i]:match("%.lua$") then
      table.insert(options.files, args[i])
      i = i + 1
    else
      i = i + 1
    end
  end

  return options
end

function firmo.show_help()
  print("firmo test runner v" .. firmo.version)
  print("Usage:")
  print("  lua firmo.lua [options] [file.lua]")

  print("\nTest Selection Options:")
  print("  --dir DIR        Directory to search for tests (default: ./tests)")
  print("  --file FILE      Run a specific test file")
  print("  --tags TAG1,TAG2 Only run tests with matching tags")
  print("  --filter PATTERN Only run tests with names matching pattern")

  print("\nOutput Format Options:")
  print("  --format FORMAT  Output format (dot, compact, summary, detailed, plain)")

  print("\nRuntime Mode Options:")
  print("  --interactive, -i Start interactive CLI mode")
  print("  --watch, -w      Watch for file changes and automatically re-run tests")

  print("\nConfiguration Options:")
  print("  --config FILE    Load configuration from specified file")
  print("  --create-config  Create default configuration file (.firmo-config.lua)")

  print("\nReport Configuration Options:")
  print("  --output-dir DIR       Base directory for all reports (default: ./coverage-reports)")
  print('  --report-suffix STR    Add a suffix to all report filenames (e.g., "-v1.0")')
  print("  --coverage-path PATH   Path template for coverage reports")
  print("  --quality-path PATH    Path template for quality reports")
  print("  --results-path PATH    Path template for test results reports")
  print('  --timestamp-format FMT Format string for timestamps (default: "%Y-%m-%d")')
  print("  --verbose-reports      Enable verbose output during report generation")
  print("\n  Path templates support the following placeholders:")
  print("    {format}    - Output format (html, json, etc.)")
  print("    {type}      - Report type (coverage, quality, etc.)")
  print("    {date}      - Current date using timestamp format")
  print("    {datetime}  - Current date and time (%Y-%m-%d_%H-%M-%S)")
  print("    {suffix}    - The report suffix if specified")

  print("\nCustom Formatter Options:")
  print("  --coverage-format FMT  Set format for coverage reports (html, json, lcov, or custom)")
  print("  --quality-format FMT   Set format for quality reports (html, json, summary, or custom)")
  print("  --results-format FMT   Set format for test results (junit, tap, csv, or custom)")
  print("  --formatter-module MOD Load custom formatter module (Lua module path)")

  print("\nExamples:")
  print("  lua firmo.lua --dir tests --format dot")
  print("  lua firmo.lua --tags unit,api --format compact")
  print("  lua firmo.lua tests/specific_test.lua")
  print("  lua firmo.lua --interactive")
  print("  lua firmo.lua --watch tests/specific_test.lua")
  print('  lua firmo.lua --coverage --output-dir ./reports --report-suffix "-$(date +%Y%m%d)"')
  print('  lua firmo.lua --coverage-path "coverage-{date}.{format}"')
  print('  lua firmo.lua --formatter-module "my_formatters" --results-format "markdown"')
end

-- Create a module that can be required
local module = setmetatable({
  firmo = firmo,

  -- Export paths to allow extensions to register assertions
  paths = paths,

  -- Export the main functions directly
  describe = firmo.describe,
  fdescribe = firmo.fdescribe,
  xdescribe = firmo.xdescribe,
  it = firmo.it,
  fit = firmo.fit,
  xit = firmo.xit,
  it_async = firmo.it_async,
  before = firmo.before,
  after = firmo.after,
  pending = firmo.pending,
  expect = firmo.expect,
  tags = firmo.tags,
  only_tags = firmo.only_tags,
  filter = firmo.filter,
  reset = firmo.reset,
  reset_filters = firmo.reset_filters,

  -- Export CLI functions
  parse_args = firmo.parse_args,
  show_help = firmo.show_help,

  -- Export mocking functions if available
  spy = firmo.spy,
  stub = firmo.stub,
  mock = firmo.mock,
  with_mocks = firmo.with_mocks,
  arg_matcher = firmo.arg_matcher,

  -- Export async functions
  async = firmo.async,
  await = firmo.await,
  wait_until = firmo.wait_until,

  -- Export interactive mode
  interactive = interactive,

  -- Global exposure utility for easier test writing
  expose_globals = function()
    -- Test building blocks
    _G.describe = firmo.describe
    _G.fdescribe = firmo.fdescribe
    _G.xdescribe = firmo.xdescribe
    _G.it = firmo.it
    _G.fit = firmo.fit
    _G.xit = firmo.xit
    _G.before = firmo.before
    _G.before_each = firmo.before -- Alias for compatibility
    _G.after = firmo.after
    _G.after_each = firmo.after -- Alias for compatibility

    -- Assertions
    _G.expect = firmo.expect
    _G.pending = firmo.pending

    -- Add firmo.assert namespace for direct assertions
    if not firmo.assert then
      firmo.assert = {}

      -- Define basic assertions
      firmo.assert.equal = function(actual, expected, message)
        if actual ~= expected then
          error(message or ("Expected " .. tostring(actual) .. " to equal " .. tostring(expected)), 2)
        end
        return true
      end

      firmo.assert.not_equal = function(actual, expected, message)
        if actual == expected then
          error(message or ("Expected " .. tostring(actual) .. " to not equal " .. tostring(expected)), 2)
        end
        return true
      end

      firmo.assert.is_true = function(value, message)
        if value ~= true then
          error(message or ("Expected value to be true, got " .. tostring(value)), 2)
        end
        return true
      end

      firmo.assert.is_false = function(value, message)
        if value ~= false then
          error(message or ("Expected value to be false, got " .. tostring(value)), 2)
        end
        return true
      end

      firmo.assert.is_nil = function(value, message)
        if value ~= nil then
          error(message or ("Expected value to be nil, got " .. tostring(value)), 2)
        end
        return true
      end

      firmo.assert.is_not_nil = function(value, message)
        if value == nil then
          error(message or "Expected value to not be nil", 2)
        end
        return true
      end

      firmo.assert.is_truthy = function(value, message)
        if not value then
          error(message or ("Expected value to be truthy, got " .. tostring(value)), 2)
        end
        return true
      end

      firmo.assert.is_falsey = function(value, message)
        if value then
          error(message or ("Expected value to be falsey, got " .. tostring(value)), 2)
        end
        return true
      end

      -- Additional assertion methods for enhanced reporting tests
      firmo.assert.not_nil = firmo.assert.is_not_nil

      firmo.assert.contains = function(container, item, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.contains(container, item, message)
        else
          -- Simple fallback implementation
          if type(container) == "string" then
            -- Handle string containment
            local item_str = tostring(item)
            if not string.find(container, item_str, 1, true) then
              error(message or ("Expected string to contain '" .. item_str .. "'"), 2)
            end
            return true
          elseif type(container) == "table" then
            -- Handle table containment
            for _, value in pairs(container) do
              if value == item then
                return true
              end
            end
            error(message or ("Expected table to contain " .. tostring(item)), 2)
          else
            -- Error for unsupported types
            error("Cannot check containment in a " .. type(container), 2)
          end
        end
      end

      -- Add enhanced type checking assertions (delegate to type_checking module)
      firmo.assert.is_exact_type = function(value, expected_type, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.is_exact_type(value, expected_type, message)
        else
          -- Minimal fallback
          if type(value) ~= expected_type then
            error(
              message or ("Expected value to be exactly of type '" .. expected_type .. "', got '" .. type(value) .. "'"),
              2
            )
          end
          return true
        end
      end

      firmo.assert.is_instance_of = function(object, class, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.is_instance_of(object, class, message)
        else
          -- Basic fallback
          if type(object) ~= "table" or type(class) ~= "table" then
            error(message or "Expected an object and a class (both tables)", 2)
          end

          local mt = getmetatable(object)
          if not mt or mt ~= class then
            error(message or "Object is not an instance of the specified class", 2)
          end

          return true
        end
      end

      firmo.assert.implements = function(object, interface, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.implements(object, interface, message)
        else
          -- Simple fallback
          if type(object) ~= "table" or type(interface) ~= "table" then
            error(message or "Expected an object and an interface (both tables)", 2)
          end

          -- Check all interface keys
          ---@diagnostic disable-next-line: unused-local
          for key, expected in pairs(interface) do
            if object[key] == nil then
              error(message or ("Object missing required property: " .. key), 2)
            end
          end

          return true
        end
      end

      firmo.assert.has_error = function(fn, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.has_error(fn, message)
        else
          -- Simple fallback
          if type(fn) ~= "function" then
            error("Expected a function to test for errors", 2)
          end

          local ok, err = pcall(fn)
          if ok then
            error(message or "Expected function to throw an error, but it did not", 2)
          end

          return err
        end
      end

      -- Add satisfies assertion for predicate testing
      firmo.assert.satisfies = function(value, predicate, message)
        if type(predicate) ~= "function" then
          error("Expected second argument to be a predicate function", 2)
        end

        local success, result = pcall(predicate, value)
        if not success then
          error("Predicate function failed: " .. result, 2)
        end

        if not result then
          error(message or "Expected value to satisfy the predicate function", 2)
        end

        return true
      end

      firmo.assert.type_of = function(value, expected_type, message)
        if type(value) ~= expected_type then
          error(message or ("Expected value to be of type '" .. expected_type .. "', got '" .. type(value) .. "'"), 2)
        end
        return true
      end

      -- Add type_or_nil assertion
      firmo.assert.is_type_or_nil = function(value, expected_type, message)
        if value ~= nil and type(value) ~= expected_type then
          error(
            message or ("Expected value to be of type '" .. expected_type .. "' or nil, got '" .. type(value) .. "'"),
            2
          )
        end
        return true
      end
    end

    -- Expose firmo.assert namespace and global assert for convenience
    _G.firmo = { assert = firmo.assert }
    _G.assert = firmo.assert

    -- Mocking utilities
    if firmo.spy then
      _G.spy = firmo.spy
      _G.stub = firmo.stub
      _G.mock = firmo.mock
      _G.with_mocks = firmo.with_mocks
    end

    -- Async testing utilities
    if async_module then
      _G.async = firmo.async
      _G.await = firmo.await
      _G.wait_until = firmo.wait_until
      _G.it_async = firmo.it_async
    end

    return firmo
  end,

  -- Main entry point when called
  ---@diagnostic disable-next-line: unused-vararg
  __call = function(_, ...)
    -- Check if we are running tests directly or just being required
    local info = debug.getinfo(2, "S")
    local is_main_module = info and (info.source == "=(command line)" or info.source:match("firmo%.lua$"))

    if is_main_module and arg then
      -- Parse command line arguments
      local options = firmo.parse_args(arg)

      -- Start interactive mode if requested
      if options.interactive then
        if interactive then
          logger.info("Starting interactive mode", {
            options = {
              test_dir = options.dir,
              pattern = options.files[1] or "*_test.lua",
              watch_mode = options.watch,
            },
          })
          interactive.start(firmo, {
            test_dir = options.dir,
            pattern = options.files[1] or "*_test.lua",
            watch_mode = options.watch,
          })
          return firmo
        else
          logger.error("Interactive mode not available", {
            reason = "Required module not found",
            component = "interactive",
            action = "exiting with error",
          })
          print("Error: Interactive mode not available. Make sure src/interactive.lua exists.")
          os.exit(1)
        end
      end

      -- Apply format options
      if options.format == "dot" then
        firmo.format({ dot_mode = true })
      elseif options.format == "compact" then
        firmo.format({ compact = true, show_success_detail = false })
      elseif options.format == "summary" then
        firmo.format({ summary_only = true })
      elseif options.format == "detailed" then
        firmo.format({ show_success_detail = true, show_trace = true })
      elseif options.format == "plain" then
        firmo.format({ use_color = false })
      end

      -- Apply tag filtering
      if #options.tags > 0 then
        firmo.only_tags(table.unpack(options.tags))
      end

      -- Apply pattern filtering
      if options.filter then
        firmo.filter(options.filter)
      end

      -- Handle watch mode
      if options.watch then
        if watcher then
          logger.info("Starting watch mode", {
            interval = 2,
            paths = { "." },
            excludes = { "node_modules", "%.git" },
          })

          -- Set up watcher
          watcher.set_check_interval(2) -- 2 seconds
          watcher.init({ "." }, { "node_modules", "%.git" })

          -- Run tests
          local run_tests = function()
            firmo.reset()
            if #options.files > 0 then
              -- Run specific files
              logger.debug("Running specific test files", {
                count = #options.files,
                files = options.files,
              })
              for _, file in ipairs(options.files) do
                firmo.run_file(file)
              end
            else
              -- Run all discovered tests
              logger.debug("Running all discovered tests", {
                directory = options.dir,
              })
              firmo.run_discovered(options.dir)
            end
          end

          -- Initial test run
          run_tests()

          -- Watch loop
          logger.info("Watching for changes", {
            message = "Press Ctrl+C to exit",
          })

          while true do
            local changes = watcher.check_for_changes()
            if changes then
              logger.info("File changes detected", {
                action = "re-running tests",
                changed_files = changes,
              })
              run_tests()
            end
            os.execute("sleep 0.5")
          end

          return firmo
        else
          logger.error("Watch mode not available", {
            reason = "Required module not found",
            component = "watcher",
            action = "exiting with error",
          })
          print("Error: Watch mode not available. Make sure src/watcher.lua exists.")
          os.exit(1)
        end
      end

      -- Run tests normally (no watch mode or interactive mode)
      if #options.files > 0 then
        -- Run specific files
        local success = true
        for _, file in ipairs(options.files) do
          local file_results = firmo.run_file(file)
          if not file_results.success or file_results.errors > 0 then
            success = false
          end
        end

        -- Exit with appropriate code
        os.exit(success and 0 or 1)
      else
        -- Run all discovered tests
        local success = firmo.run_discovered(options.dir)
        os.exit(success and 0 or 1)
      end
    end

    -- When required as module, just return the module
    return firmo
  end,
}, {
  __index = firmo,
})

-- Register module reset functionality if available
-- This must be done after all methods (including reset) are defined
if module_reset_module then
  module_reset_module.register_with_firmo(firmo)
end

return module
