--- Aggregated Test Runner Script
---
--- This script requires and runs all major test suites within the Firmo project.
--- It groups tests by functionality using `describe` blocks.
--- It is primarily used for running the complete test suite in CI or development.
---
--- Usage: Pass this file path to the Firmo test runner.
--- Example: lua firmo.lua scripts/utilities/all_tests.lua
---
--- @author Firmo Team
--- @version 1.0.0
--- @script
local firmo = require("firmo")
local describe = firmo.describe

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _fs

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

-- Core tests
describe("Core functionality tests", function()
  -- Core assertions moved to assertions directory
  if get_fs().file_exists("tests/assertions/assertions_test.lua") then
    require("tests.assertions.assertions_test")
  else
    require("tests.assertions_test")
  end

  if get_fs().file_exists("tests/assertions/expect_assertions_test.lua") then
    require("tests.assertions.expect_assertions_test")
  else
    require("tests.expect_assertions_test")
  end

  -- Core framework files
  require("tests.core.config_test")
  require("tests.core.module_reset_test")
  require("tests.core.type_checking_test")
  require("tests.core.firmo_test")
  require("tests.core.tagging_test")
end)

-- Coverage tests
describe("Coverage tests", function()
  require("tests.coverage.coverage_module_test")
  require("tests.coverage.coverage_test_minimal")
  require("tests.coverage.coverage_test_simple")
  require("tests.coverage.coverage_error_handling_test")
  require("tests.coverage.large_file_coverage_test")
  require("tests.coverage.fallback_heuristic_analysis_test")
end)

-- Quality tests
describe("Quality tests", function()
  require("tests.quality.quality_test")
end)

-- Reporting tests
describe("Reporting tests", function()
  require("tests.reporting.reporting_test")
  require("tests.reporting.enhanced_reporting_test")
  require("tests.reporting.reporting_filesystem_test")
  require("tests.reporting.report_validation_test")

  -- Formatter tests
  require("tests.reporting.formatters.tap_csv_format_test")
  require("tests.reporting.formatters.html_formatter_test")
end)

-- Tools tests
describe("Tools tests", function()
  -- Filesystem tools
  require("tests.tools.filesystem.filesystem_test")

  -- Other tools
  require("tests.tools.codefix_test")
  require("tests.tools.fix_markdown_script_test")
  require("tests.tools.interactive_mode_test")
  require("tests.tools.markdown_test")

  -- Logging
  require("tests.tools.logging.logging_test")

  -- Watcher
  require("tests.tools.watcher.watch_mode_test")
end)

-- Mocking tests
describe("Mocking tests", function()
  require("tests.mocking.mocking_test")
end)

-- Async tests
describe("Async tests", function()
  require("tests.async.async_test")
  require("tests.async.async_timeout_test")
end)

-- Performance tests
describe("Performance tests", function()
  require("tests.performance.performance_test")
  require("tests.performance.large_file_test")
end)

-- Parallel tests
describe("Parallel tests", function()
  require("tests.parallel.parallel_test")
end)

-- Discovery tests
describe("Discovery tests", function()
  require("tests.discovery.discovery_test")
end)

-- Assertions tests
describe("Assertions tests", function()
  require("tests.assertions.truthy_falsey_test")
end)

-- Simple test
describe("Simple tests", function()
  require("tests.simple_test")
end)
