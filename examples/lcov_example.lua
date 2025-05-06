--- lcov_example.lua
--
-- This example demonstrates generating LCOV format coverage reports using
-- Firmo's reporting module. LCOV is a common format used by many CI/CD
-- platforms and code coverage services (like Codecov, Coveralls, SonarQube).
--
-- It shows how to:
-- - Generate LCOV reports using `reporting.format_coverage`.
-- - Configure LCOV-specific options (functions, test name, paths) via `central_config`.
-- - Save reports to a temporary directory managed by `test_helper`.
-- - Provides examples for integrating with common CI platforms.
--
-- @module examples.lcov_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see lib.reporting.formatters.lcov
-- @see lib.core.central_config
-- @see lib.tools.test_helper
-- @usage
-- Run embedded tests: lua test.lua examples/lcov_example.lua
--

-- Import required modules
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after
local logging = require("lib.tools.logging")
local test_helper = require("lib.tools.test_helper")
local temp_file = require("lib.tools.filesystem.temp_file") -- For cleanup

-- Setup logger
local logger = logging.get_logger("LCOVExample")

-- Create mock coverage data (consistent with other examples, using execution_count)
--- @type MockCoverageData (See csv_example.lua for full definition)
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = { executable = true, execution_count = 1 },
        [2] = { executable = true, execution_count = 1 },
        [3] = { executable = true, execution_count = 1 },
        [5] = { executable = true, execution_count = 0 },
        [6] = { executable = true, execution_count = 1 },
        [8] = { executable = true, execution_count = 0 },
        [9] = { executable = true, execution_count = 0 },
      },
      functions = {
        ["add"] = { name = "add", execution_count = 1 },
        ["subtract"] = { name = "subtract", execution_count = 1 },
        ["multiply"] = { name = "multiply", execution_count = 0 },
        ["divide"] = { name = "divide", execution_count = 0 },
      },
      total_lines = 10,
      executable_lines = 7,
      covered_lines = 4,
      total_functions = 4,
      covered_functions = 2,
      line_coverage_percent = (4 / 7) * 100,
      function_coverage_percent = (2 / 4) * 100,
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = { executable = true, execution_count = 1 },
        [2] = { executable = true, execution_count = 1 },
        [4] = { executable = true, execution_count = 1 },
        [5] = { executable = true, execution_count = 1 },
        [7] = { executable = true, execution_count = 0 },
      },
      functions = {
        ["validate"] = { name = "validate", execution_count = 1 },
        ["format"] = { name = "format", execution_count = 0 },
      },
      total_lines = 8,
      executable_lines = 5,
      covered_lines = 4,
      total_functions = 2,
      covered_functions = 1,
      line_coverage_percent = (4 / 5) * 100,
      function_coverage_percent = (1 / 2) * 100,
    },
  },
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 18,
    executable_lines = 12,
    covered_lines = 8,
    total_functions = 6,
    covered_functions = 3,
    line_coverage_percent = (8 / 12) * 100, -- ~66.7%
    function_coverage_percent = (3 / 6) * 100, -- 50.0%
    overall_percent = (8 / 12) * 100,
  },
}

-- Create tests to demonstrate the LCOV formatter
-- Create tests to demonstrate the LCOV formatter
--- Test suite demonstrating LCOV report generation and configuration.
--- @within examples.lcov_example
describe("LCOV Formatter Example", function()
  local temp_dir -- Stores the temporary directory helper object

  --- Setup hook: Create a temporary directory for reports.
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  --- Teardown hook: Release reference. Directory cleaned automatically.
  after(function()
    temp_dir = nil
  end)

  --- Tests generating a basic LCOV coverage report with default settings.
  it("generates basic LCOV coverage report with defaults", function()
    -- Reset config
    central_config.reset("reporting.formatters.lcov")

    -- Generate LCOV report
    logger.info("Generating basic LCOV coverage report...")
    local lcov_report, format_err = reporting.format_coverage(mock_coverage_data, "lcov")

    -- Validate the report
    expect(format_err).to_not.exist("Formatting should succeed")
    expect(lcov_report).to.exist()
    expect(lcov_report).to.be.a("string")
    expect(lcov_report).to.match("TN:") -- Test Name line
    expect(lcov_report).to.match("SF:") -- Source File line
    expect(lcov_report).to.match("DA:") -- Data line
    expect(lcov_report).to.match("LF:") -- Lines Found
    expect(lcov_report).to.match("LH:") -- Lines Hit
    expect(lcov_report).to.match("end_of_record")

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-report.lcov")
    local success, err_str = fs.write_file(file_path, lcov_report)

    -- Check if write was successful
    expect(err_str).to_not.exist("Writing LCOV report should succeed")
    expect(success).to.be_truthy()

    logger.info("Basic LCOV report saved to: " .. file_path)
    logger.info("Report size: " .. #lcov_report .. " bytes")

    -- Preview a sample of the LCOV output
    logger.info("\nLCOV Preview (first 300 characters):")
    print(lcov_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Tests configuring LCOV formatter options (functions, test name, paths).
  it("demonstrates LCOV formatter configuration options", function()
    -- Configure LCOV formatter options via central_config
    central_config.set("reporting.formatters.lcov", {
      include_functions = true, -- Include function coverage (FN, FNDA lines)
      test_name = "FirmoTests", -- Set custom test name
      source_prefix = "", -- Strip source prefix from file paths
      exclude_patterns = { "test/" }, -- Exclude files matching these patterns
    })

    -- Generate the report with configuration
    logger.info("Generating configured LCOV coverage report...")
    local lcov_report, format_err = reporting.format_coverage(mock_coverage_data, "lcov")

    -- Validate the report
    expect(format_err).to_not.exist("Formatting should succeed")
    expect(lcov_report).to.exist()
    expect(lcov_report).to.match("TN:") -- Custom test name

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-report-configured.lcov")
    local success, err_str = fs.write_file(file_path, lcov_report)

    -- Check if write was successful
    expect(err_str).to_not.exist("Writing configured LCOV report should succeed")
    expect(success).to.be_truthy()

    logger.info("Configured LCOV report saved to: " .. file_path)
    logger.info("Report size: " .. #lcov_report .. " bytes")

    -- Preview a sample of the LCOV output
    logger.info("\nConfigured LCOV Preview (first 300 characters):")
    print(lcov_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Informational test providing example CI/CD configurations for using LCOV reports.
  it("discusses CI integration with LCOV reports", function()
    -- Generate LCOV report
    local lcov_report, format_err = reporting.format_coverage(mock_coverage_data, "lcov")

    -- Validate formatting worked
    expect(format_err).to_not.exist("Formatting should succeed")
    expect(lcov_report).to.exist("Report string should exist")
    local file_path = fs.join_paths(temp_dir.path, "lcov.info")
    local success, err_str = fs.write_file(file_path, lcov_report)
    expect(err_str).to_not.exist("Writing CI/CD LCOV report should succeed")
    expect(success).to.be_truthy()

    logger.info("CI-ready LCOV report saved to: " .. file_path)

    -- Example CI configuration for using LCOV reports
    local example_configs = {
      github_actions = [[
name: Coverage

on: [push, pull_request]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Lua
        uses: leafo/gh-actions-lua@v8
      - name: Run Tests with Coverage
        run: lua test.lua --coverage tests/
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v2
        with:
          files: ./coverage-reports/lcov.info
          fail_ci_if_error: true
]],

      gitlab_ci = [[
test_with_coverage:
  stage: test
  script:
    - lua test.lua --coverage tests/
  artifacts:
    paths:
      - coverage-reports/lcov.info
    expire_in: 1 week
  coverage: '/Overall coverage: \d+\.\d+%/'
]],

      jenkins = [[
// Jenkinsfile
pipeline {
  agent any
  stages {
    stage('Test') {
      steps {
        sh 'lua test.lua --coverage tests/'
      }
    }
  }
  post {
    always {
      publishCoverage adapters: [lcov('coverage-reports/lcov.info')]
    }
  }
}
]],
    }

    -- Print example CI configurations
    logger.info("\nExample CI configurations for LCOV integration:")
    logger.info("\n=== GitHub Actions ===")
    print(example_configs.github_actions)

    logger.info("\n=== GitLab CI ===")
    print(example_configs.gitlab_ci)

    logger.info("\n=== Jenkins ===")
    print(example_configs.jenkins)
  end)
end)

logger.info("\n=== LCOV Formatter Example ===")
logger.info("This example demonstrates how to generate coverage reports in LCOV format.")
logger.info("LCOV is a standard format supported by many CI/CD tools and coverage services.")

logger.info("\nTo run this example directly:")
logger.info("  lua examples/lcov_example.lua")

logger.info("\nOr run it with firmo's test runner:")
logger.info("  lua test.lua examples/lcov_example.lua")

logger.info("\nCommon CI/CD services that support LCOV:")
logger.info("- Codecov (codecov.io)")
logger.info("- Coveralls (coveralls.io)")
logger.info("- SonarQube/SonarCloud")
logger.info("- Jenkins with the Coverage Plugin")
logger.info("- GitHub Actions with codecov action")

logger.info("\nLCOV Format Specification:")
logger.info("- TN: Test Name")
logger.info("- SF: Source File")
logger.info("- FN: Function Name and Line")
logger.info("- FNDA: Function Data (call count)")
logger.info("- FNF: Functions Found")
logger.info("- FNH: Functions Hit")
logger.info("- DA: Line Data (line number, execution count)")
logger.info("- LF: Lines Found")
logger.info("- LH: Lines Hit")
logger.info("- end_of_record: Separator between files")

logger.info("\nExample complete!")

-- Cleanup is handled automatically by test_helper registration
