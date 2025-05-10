--- Comprehensive example demonstrating the Firmo central configuration system.
---
--- This example showcases various features of the `lib.core.central_config` module:
--- - Retrieving the current configuration using `central_config.get()`.
--- - Understanding the default configuration structure.
--- - Loading configuration from a specified file path using `central_config.load_from_file()`.
--- - Creating and loading environment-specific configuration files (e.g., `.firmo-config.dev.lua`).
--- - Applying configuration settings programmatically using `central_config.set()` (implicitly via `load_from_file` or direct calls if needed).
--- - Accessing configuration values correctly within other modules by calling `central_config.get()` where needed.
--- - Illustrating best practices and common anti-patterns for configuration usage.
--- - Demonstrating how to test configuration settings within Firmo tests.
---
--- @module examples.central_config_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.core.central_config
--- @see docs/guides/central_config.md
--- @usage
--- Run this example directly to see configuration loading and usage demonstrated in the console:
--- ```bash
--- lua examples/central_config_example.lua
--- ```
--- Run the embedded tests to verify configuration loading and access:
--- ```bash
--- lua firmo.lua examples/central_config_example.lua
--- ```

-- Import the required modules
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")
-- local temp_file = require("lib.tools.filesystem.temp_file") -- Moved lower

-- Setup logger for this example
local logger = logging.get_logger("CentralConfigExample")

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

-- Create a temporary directory for the example files using test_helper
-- This ensures the directory and its contents are automatically cleaned up.
local temp_dir = test_helper.create_temp_test_directory()
logger.info("Created temporary directory for config examples: " .. temp_dir.path)

-- PART 1: Core Configuration Concepts
logger.info("\n== CENTRAL CONFIGURATION SYSTEM EXAMPLE ==\n")
logger.info("PART 1: Core Configuration Concepts\n")

-- Access the current configuration
local config = central_config.get() -- Use get() instead of get_config()
print("Initial configuration source:", config.__source or "defaults")

-- Example: Accessing a default configuration value
print("Default reporting format:", config.reporting and config.reporting.format or "nil") -- Should be 'summary' or similar default

-- Define sample configuration content (can be written to a file)
local config_file_content = [[
-- Sample .firmo-config.lua file
-- This file defines custom settings for the Firmo framework.

local config = {
  -- Coverage configuration
  coverage = {
    -- Include pattern (function that returns true if file should be included)
    include = function(file_path)
      -- Include all Lua files in src/ and lib/
      return file_path:match("%.lua$") and (
        file_path:match("^src/") or
        file_path:match("^lib/")
      )
    end,

    -- Exclude pattern (function that returns true if file should be excluded)
    exclude = function(file_path)
      -- Exclude test files and vendored code
      return file_path:match("test") or
             file_path:match("vendor") or
             file_path:match("%.test%.lua$")
    end,

    -- Track all executed lines (not just covered ones)
    track_all_executed = true,

    -- Report uncovered branches
    track_branches = true
  },

  -- Reporting configuration
  reporting = {
    -- Default report format
    format = "html",

    -- Output directory for reports
    output_dir = "reports",

    -- Report file name template
    file_template = "coverage-report-${timestamp}",

    -- Show coverage statistics in console output
    show_stats = true
  },

  -- Logging configuration
  logging = {
    -- Global log level (error, warn, info, debug, trace)
    level = "info",

    -- Enable output coloring
    colors = true,

    -- Module-specific log levels
    modules = {
      ["coverage"] = "warn",
      ["runner"] = "info"
    }
  },

  -- Test discovery configuration
  discovery = {
    -- Patterns to include in test discovery
    patterns = {"test_", "_test.lua$", "_spec.lua$"},

    -- Directories to search for tests
    directories = {"tests/"},

    -- Maximum recursion depth for directory traversal
    max_depth = 10
  },

  -- Async testing configuration
  async = {
    -- Default timeout for async tests (in milliseconds)
    default_timeout = 2000,

    -- Poll interval for async tests (in milliseconds)
    poll_interval = 10
  }
}

-- Return the configuration
return config
]]

-- Display structure of a sample config (illustrative)
logger.info("\nIllustrative Structure of a .firmo-config.lua:")
print("- Contains sections like 'coverage', 'reporting', 'logging', 'discovery', 'async'.")
print("- Uses Lua functions for complex patterns (e.g., coverage.include).")
print("- Overrides default framework settings.")

-- PART 2: Loading Custom Configuration from Files
logger.info("\nPART 2: Loading Custom Configuration from Files\n")

-- Write the sample config content to a temporary file
local config_path = fs.join_paths(temp_dir.path, ".firmo-config-sample.lua") -- Use a distinct name
local write_ok, write_err = fs.write_file(config_path, config_file_content)
if not write_ok then
  logger.error("Failed to write sample config file: " .. tostring(write_err))
  return -- Stop example if file can't be written
end

-- Display the configuration file
logger.info("Sample .firmo-config.lua file created at: " .. config_path)
-- print(config_file_content:sub(1, 500) .. "...\n") -- Avoid excessive printing

-- Attempt to load the configuration from the created file
logger.info("Loading custom configuration from: " .. config_path)
-- Note: load_from_file applies the loaded config internally if successful.
-- It returns the loaded config table, but this returned value doesn't need to be stored
-- as the configuration has already been applied internally.
local loaded_config_success, loaded_config_data_or_err = central_config.load_from_file(config_path)

if not loaded_config_success then
  logger.error("Error loading custom configuration: " .. tostring(loaded_config_data_or_err or "Unknown error"))
else
  logger.info("Custom configuration loaded and applied successfully!")

  -- Get the *current* config after loading to see the merged result
  local current_config = central_config.get()

  -- Display some loaded configuration values
  logger.info("\nValues after loading custom config:")
  print("- Reporting format:", current_config.reporting and current_config.reporting.format or "nil") -- Should be 'html' from the file
  print("- Default async timeout:", current_config.async and current_config.async.default_timeout or "nil", "ms") -- Should be 2000

  -- Test the loaded coverage patterns
  local test_paths_patterns = {
    "src/calculator.lua",
    "lib/utils/string.lua",
    "tests/calculator_test.lua",
    "lib/vendor/json.lua",
  }
  logger.info("\nTesting include/exclude patterns from loaded config:")
  for _, path in ipairs(test_paths_patterns) do
    -- Access patterns from the current config state
    local include_fn = current_config.coverage and current_config.coverage.include
    local exclude_fn = current_config.coverage and current_config.coverage.exclude
    local included = include_fn and include_fn(path) or false
    local excluded = exclude_fn and exclude_fn(path) or false
    local status = included and not excluded and "INCLUDED" or "EXCLUDED"
    print(string.format("- %-25s: %s", path, status))
  end
end

-- Reset config to defaults for next section
central_config.reset()
logger.info("\nConfiguration reset to defaults.")

-- PART 3: Programmatic Configuration (Using central_config.set)
logger.info("\nPART 3: Programmatic Configuration\n")

-- Set specific configuration values programmatically
logger.info("Applying specific settings programmatically using central_config.set()...")
central_config.set("reporting.format", "json")
central_config.set("logging.level", "debug")
central_config.set("coverage.track_branches", false)
-- Example setting a nested value
central_config.set("reporting.formatters.json", { pretty = true, indent = 2 })

-- Get the configuration again to verify changes
local prog_config = central_config.get()
logger.info("Configuration updated programmatically:")
print("- Reporting format:", prog_config.reporting.format) -- Should be 'json'
print("- Logging level:", prog_config.logging.level) -- Should be 'debug'
print("- Track branches:", tostring(prog_config.coverage.track_branches)) -- Should be false
print("- JSON pretty print:", tostring(prog_config.reporting.formatters.json.pretty)) -- Should be true

-- Reset config again
central_config.reset()
logger.info("\nConfiguration reset to defaults.")

-- PART 4: Environment-Specific Configuration
logger.info("\nPART 4: Environment-Specific Configuration\n")

-- Define environment-specific configurations content
-- Development environment configuration
local dev_config_content = [[
-- .firmo-config.dev.lua
local config = {
  logging = {
    level = "debug",
    colors = true
  },
  reporting = {
    format = "html",
    show_stats = true
  },
  discovery = {
    directories = {"tests/"}
  }
}
return config
]]

-- CI environment configuration
local ci_config_content = [[
-- .firmo-config.ci.lua
local config = {
  logging = {
    level = "info",
    colors = false,
    file = "firmo-ci.log"
  },
  reporting = {
    format = "cobertura",
    output_dir = "coverage-reports"
  },
  discovery = {
    directories = {"tests/", "integration-tests/"},
    patterns = {"test_", "_test.lua$"}
  }
}
return config
]]

-- Write the environment-specific configs to the temp directory
local base_config_path = fs.join_paths(temp_dir.path, ".firmo-config.lua") -- Base config
local dev_config_path = fs.join_paths(temp_dir.path, ".firmo-config.dev.lua")
local ci_config_path = fs.join_paths(temp_dir.path, ".firmo-config.ci.lua")

-- Write a simple base config first
fs.write_file(base_config_path, [[ return { reporting = { format = "summary" } } ]])
fs.write_file(dev_config_path, dev_config_content)
fs.write_file(ci_config_path, ci_config_content)

logger.info("Environment-specific configuration files created in: " .. temp_dir.path)

-- Simulate loading with different environments
-- central_config automatically detects .firmo-config.<env>.lua if FIRMO_ENV is set,
-- or loads .firmo-config.lua by default. We simulate by calling load explicitly.

logger.info("\nLoading configuration for 'dev' environment (simulated):")
-- In a real scenario, setting FIRMO_ENV=dev and calling central_config.get() 
-- would handle this automatically. Here we load the configs manually:
central_config.reset() -- Start fresh
local base_loaded, _ = central_config.load_from_file(base_config_path)
local dev_loaded, _ = central_config.load_from_file(dev_config_path)
if base_loaded and dev_loaded then
  -- central_config.load_from_file ALREADY applies the config internally, so get() reflects the latest loaded values.
  local final_dev_config = central_config.get()
  print("- Loaded reporting format (expect 'html'):", final_dev_config.reporting and final_dev_config.reporting.format or "nil")
  print("- Loaded logging level (expect 'debug'):", final_dev_config.logging and final_dev_config.logging.level or "nil")
else
  logger.warn("Failed to load base or dev config for simulation.")
end

logger.info("\nLoading configuration for 'ci' environment (simulated):")
central_config.reset() -- Start fresh
local base_loaded_ci, _ = central_config.load_from_file(base_config_path)
local ci_loaded, _ = central_config.load_from_file(ci_config_path)
if base_loaded_ci and ci_loaded then
  local final_ci_config = central_config.get()
  print("- Loaded reporting format (expect 'cobertura'):", final_ci_config.reporting and final_ci_config.reporting.format or "nil")
  print("- Loaded logging level (expect 'info'):", final_ci_config.logging and final_ci_config.logging.level or "nil")
  print("- Loaded logging file (expect 'firmo-ci.log'):", final_ci_config.logging and final_ci_config.logging.file or "nil")
else
  logger.warn("Failed to load base or ci config for simulation.")
end

-- Reset config again
central_config.reset()
logger.info("\nConfiguration reset to defaults.")

-- PART 5: Using Configuration in Modules
logger.info("\nPART 5: Using Configuration in Modules\n")

-- Example of a module that properly uses central_config
--- @class ExampleModule
--- @field init fun():boolean Initializes the module using current config.
--- @field should_process_file fun(file_path: string):boolean Checks if a file should be processed based on current config.
--- @within examples.central_config_example
local ExampleModule = {}

--- Initializes the ExampleModule, demonstrating how to use `central_config.get()`
-- during module setup to read current settings.
-- @return boolean success Always returns true in this example.
function ExampleModule.init()
  -- **BEST PRACTICE**: Get fresh configuration *inside* the function where it's needed.
  -- Avoid storing the config table in the module itself if settings might change.
  local config = central_config.get()

  -- Use configuration values immediately
  local log_level = config.logging and config.logging.level or "info" -- Use default if missing
  local report_format = config.reporting and config.reporting.format or "summary" -- Use default

  logger.info("ExampleModule initialized with:")
  print("- Log level:", log_level)
  print("- Report format:", report_format)
  return true
end

--- Checks if a file should be processed based on the current coverage include/exclude patterns
-- retrieved fresh from `central_config.get()`.
-- @param file_path string Path to the file to check.
-- @return boolean should_process Whether the file should be processed based on current configuration.
function ExampleModule.should_process_file(file_path)
  -- **BEST PRACTICE**: Get fresh configuration inside the function.
  local config = central_config.get()

  -- Safely access potentially nested configuration values
  local include_fn = config.coverage and config.coverage.include
  local exclude_fn = config.coverage and config.coverage.exclude

  -- Ensure functions exist and are callable before using them
  local should_include = type(include_fn) == "function" and include_fn(file_path) or false
  local should_exclude = type(exclude_fn) == "function" and exclude_fn(file_path) or false

  return should_include and not should_exclude
end

-- Demonstrate proper configuration usage within the module
logger.info("Initializing example module (uses central_config.get())...")
ExampleModule.init()

-- Load the sample config again to test filtering
central_config.load_from_file(config_path)
logger.info("\nLoaded sample config again for filtering test.")

local test_paths_for_filtering = {
  "src/core/util.lua",
  "tests/unit/main_test.lua",
  "lib/vendor/third_party.lua",
  "lib/reporting/html.lua",
}

logger.info("\nFile filtering results (using ExampleModule.should_process_file):")
for _, file in ipairs(test_paths_for_filtering) do
  local should_process = ExampleModule.should_process_file(file)
  print(string.format("- %-30s: %s", file, should_process and "Process (Included)" or "Skip (Excluded)"))
end

-- Part 6: Best Practices and Anti-patterns
logger.info("\nPART 6: Best Practices and Anti-patterns\n")

logger.info("BEST PRACTICES:")
print("✓ Always use `central_config.get()` inside functions where config is needed.")
print("✓ Avoid caching the config table in module-level variables.")
print("✓ Provide sensible defaults when accessing potentially missing config values.")
print("✓ Use environment variables (e.g., FIRMO_ENV) or specific load calls for context.")
print("✓ Define configuration schema/expectations clearly (e.g., in documentation).")

logger.info("\nANTI-PATTERNS (AVOID):")
print("✗ Caching config: `local my_module_config = central_config.get()` at module level.")
print("  Problem: Doesn't reflect later changes to the central config.")
print("✗ Hardcoding defaults: `local level = my_options.level or 'info'` without checking central config first.")
print("  Problem: Ignores globally configured defaults.")
print("✗ Direct file loading: `dofile('.firmo-config.lua')` inside a module.")
print("  Problem: Bypasses merging, environment handling, and validation.")

-- PART 7: Testing with Firmo
logger.info("\nPART 7: Testing Configuration with Firmo\n")

--- Test suite for verifying aspects of the central configuration system itself.
--- @within examples.central_config_example
describe("Central Config System Tests", function()
  --- Tests that the configuration can be retrieved and has expected top-level keys.
  it("loads default configuration successfully", function()
    central_config.reset() -- Ensure defaults
    local config = central_config.get()
    expect(config).to.exist()
    
    -- The default configuration may have empty/nil sections
    -- We only check that the config object itself exists and has the expected structure
    -- without assuming specific keys are present
    
    -- Check if coverage exists or is nil by default
    expect(config.coverage).to.satisfy(function(val)
      return type(val) == "table" or val == nil
    end, "Coverage should be a table or nil")
    
    -- Check if logging exists or is nil by default
    expect(config.logging).to.satisfy(function(val)
      return type(val) == "table" or val == nil
    end, "Logging should be a table or nil")
    
    -- Note: We don't check for config.reporting since it's not guaranteed 
    -- to exist in the default configuration
  end)

  --- Tests loading a specific configuration file and verifying its content.
  it("loads configuration from a specified file", function()
    -- Use the sample config file created earlier
    local loaded, cfg_or_err = central_config.load_from_file(config_path)
    expect(loaded).to.be_truthy("Loading should return true on success")
    -- load_from_file returns success status and error message on failure, not the config object
    expect(type(cfg_or_err)).to_not.equal("string", "Should not be an error string if load succeeded")
    -- No need for the 'if loaded then' check as the previous assertions cover it.

    -- Get the current config state after loading
    local current_config = central_config.get()
    expect(current_config.reporting.format).to.equal("html") -- From the sample file
    expect(type(current_config.coverage.include)).to.equal("function")
  end)

  --- Tests the behavior of the include/exclude pattern functions after loading a config.
  it("applies include/exclude patterns correctly after loading", function()
    -- Ensure sample config is loaded
    central_config.load_from_file(config_path)
    local config = central_config.get()

    -- Test includes (based on sample config)
    expect(config.coverage.include("src/file.lua")).to.be_truthy()
    expect(config.coverage.include("lib/file.lua")).to.be_truthy()
    expect(config.coverage.include("tests/file.lua")).to_not.be_truthy() -- Excluded by include pattern

    -- Test excludes (based on sample config)
    expect(config.coverage.exclude("tests/some_test.lua")).to.be_truthy()
    expect(config.coverage.exclude("lib/vendor/lib.lua")).to.be_truthy()
    expect(config.coverage.exclude("src/main.lua")).to_not.be_truthy()

    -- Test combined effect
    expect(ExampleModule.should_process_file("src/core.lua")).to.be_truthy()
    expect(ExampleModule.should_process_file("tests/core_test.lua")).to_not.be_truthy()
  end)

  --- Tests setting and getting configuration values programmatically.
  it("allows setting configuration programmatically", function()
    central_config.reset() -- Start fresh
    central_config.set("new_feature.enabled", true)
    central_config.set("logging.level", "trace")

    local config = central_config.get()
    expect(config.new_feature.enabled).to.be_truthy()
    expect(config.logging.level).to.equal("trace")
  end)
end)

logger.info("Run the tests with: lua firmo.lua examples/central_config_example.lua\n")

-- Cleanup is handled automatically by the test runner via temp_file integration when run with `lua firmo.lua ...`
-- If run directly (`lua examples/...`), manual cleanup might be needed if errors occur before registration.
logger.info("Temporary files/directories created in " .. temp_dir.path .. " will be cleaned up.")

logger.info("Central configuration example completed successfully.")
