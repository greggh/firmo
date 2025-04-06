-- tests/all_tests.lua
local firmo = require("firmo")
local fs = require("lib.tools.filesystem")
local describe = firmo.describe

-- Core tests
describe("Core functionality tests", function()
    -- Core assertions moved to assertions directory
    if fs.file_exists("tests/assertions/assertions_test.lua") then
        require("tests.assertions.assertions_test")
    else
        require("tests.assertions_test")
    end
    
    if fs.file_exists("tests/assertions/expect_assertions_test.lua") then
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
