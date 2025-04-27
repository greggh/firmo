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
-- Run embedded tests: lua test.lua examples/lcov_example.lua
--

-- Import required modules
local error_handler = require("lib.tools.error_handler")
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local firmo = require("firmo") -- Needed for describe/it/expect
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local logging = require("lib.tools.logging")
local test_helper = require("lib.tools.test_helper")
local temp_file = require("lib.tools.filesystem.temp_file") -- For cleanup

-- Setup logger
local logger = logging.get_logger("LCOVExample")

-- Create mock coverage data (consistent with other examples)
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = true, -- This line was covered
        [2] = true, -- This line was covered
        [3] = true, -- This line was covered
        [5] = false, -- This line was not covered
        [6] = true, -- This line was covered
        [8] = false, -- This line was not covered
        [9] = false, -- This line was not covered
      },
      functions = {
        ["add"] = true, -- This function was covered
        ["subtract"] = true, -- This function was covered
        ["multiply"] = false, -- This function was not covered
        ["divide"] = false, -- This function was not covered
      },
      total_lines = 10,
      covered_lines = 4,
      total_functions = 4,
      covered_functions = 2,
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = true, -- This line was covered
        [2] = true, -- This line was covered
        [4] = true, -- This line was covered
        [5] = true, -- This line was covered
        [7] = false, -- This line was not covered
      },
      functions = {
        ["validate"] = true, -- This function was covered
        ["format"] = false, -- This function was not covered
      },
      total_lines = 8,
      covered_lines = 4,
      total_functions = 2,
      covered_functions = 1,
    },
  },
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 18,
    covered_lines = 8,
    total_functions = 6,
    covered_functions = 3,
    line_coverage_percent = 44.4, -- 8/18
    function_coverage_percent = 50.0, -- 3/6
    overall_percent = 47.2, -- (44.4 + 50.0) / 2
  },
}

-- Create tests to demonstrate the LCOV formatter
--- Test suite demonstrating LCOV report generation and configuration.
describe("LCOV Formatter Example", function()
  local temp_dir

  -- Setup: Create a temporary directory for reports before tests run
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  -- Teardown: Release reference (directory cleaned up by test_helper)
  after(function()
    temp_dir = nil
  end)

  --- Test case for generating a basic LCOV coverage report.
  it("generates basic LCOV coverage report", function()
    -- Generate LCOV report
    logger.info("Generating basic LCOV coverage report...")
    local lcov_report = reporting.format_coverage(mock_coverage_data, "lcov")

    -- Validate the report
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
    local success, err = fs.write_file(file_path, lcov_report)

    -- Check if write was successful
    expect(success).to.be_truthy()

    logger.info("Basic LCOV report saved to: " .. file_path)
    logger.info("Report size: " .. #lcov_report .. " bytes")

    -- Preview a sample of the LCOV output
    logger.info("\nLCOV Preview (first 300 characters):")
    print(lcov_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Test case demonstrating LCOV formatter configuration options
  -- (including function data, test name, path prefix).
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
    local lcov_report = reporting.format_coverage(mock_coverage_data, "lcov")

    -- Validate the report
    expect(lcov_report).to.exist()
    expect(lcov_report).to.match("TN:FirmoTests") -- Custom test name

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-report-configured.lcov")
    local success, err = fs.write_file(file_path, lcov_report)

    -- Check if write was successful
    expect(success).to.be_truthy()

    logger.info("Configured LCOV report saved to: " .. file_path)
    logger.info("Report size: " .. #lcov_report .. " bytes")

    -- Preview a sample of the LCOV output
    logger.info("\nConfigured LCOV Preview (first 300 characters):")
    print(lcov_report:sub(1, 300) .. "...\n") -- Print preview
  end)

  --- Test case providing example configurations for integrating LCOV reports
  -- with common CI/CD platforms (GitHub Actions, GitLab CI, Jenkins).
  it("demonstrates CI integration with LCOV reports", function()
    -- Generate LCOV report
    local lcov_report = reporting.format_coverage(mock_coverage_data, "lcov")

    -- Save to the standard location that most CI tools expect
    local file_path = fs.join_paths(temp_dir.path, "lcov.info")
    local success, err = fs.write_file(file_path, lcov_report)
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

-- Add cleanup for temp_file module at the end
temp_file.cleanup_all()
