--- junit_example.lua
--
-- This example demonstrates generating JUnit XML format test result reports
-- using Firmo's reporting module. JUnit is a widely supported format for
-- integrating test results into CI/CD systems.
--
-- It shows how to:
-- - Generate JUnit XML reports using `reporting.format_results`.
-- - Configure JUnit-specific options (timestamps, hostname, properties, etc.)
--   via `central_config`.
-- - Generate multi-suite reports using the `group_by_classname` option.
-- - Save reports to a temporary directory managed by `test_helper`.
-- - Provides examples for integrating with Jenkins, GitHub Actions, and GitLab CI.
--
-- Run embedded tests: lua test.lua examples/junit_example.lua
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
local logger = logging.get_logger("JUnitExample")

-- Mock test results data structure for demonstration.
--- @type MockTestResults (See csv_example.lua for definition)
local mock_test_results = {
  name = "JUnit Example Test Suite",
  timestamp = "2025-01-01T00:00:00Z", -- Static timestamp
  tests = 8,
  failures = 1,
  errors = 1,
  skipped = 1,
  time = 0.35, -- Execution time in seconds
  test_cases = {
    {
      name = "validates positive numbers correctly",
      classname = "NumberValidator",
      time = 0.001,
      status = "pass",
    },
    {
      name = "validates negative numbers correctly",
      classname = "NumberValidator",
      time = 0.003,
      status = "pass",
    },
    {
      name = "validates zero correctly",
      classname = "NumberValidator",
      time = 0.001,
      status = "pass",
    },
    {
      name = "rejects non-numeric inputs",
      classname = "NumberValidator",
      time = 0.002,
      status = "pass",
    },
    {
      name = "handles boundary values correctly",
      classname = "NumberValidator",
      time = 0.015,
      status = "fail",
      failure = {
        message = "Expected validation to pass for MAX_INT but it failed",
        type = "AssertionError",
        details = "test/number_validator_test.lua:42: Expected isValid(9223372036854775807) to be true, got false",
      },
    },
    {
      name = "throws appropriate error for invalid format",
      classname = "NumberValidator",
      time = 0.005,
      status = "error",
      error = {
        message = "Runtime error in test",
        type = "Error",
        details = "test/number_validator_test.lua:53: attempt to call nil value (method 'formatError')",
      },
    },
    {
      name = "validates scientific notation",
      classname = "NumberValidator",
      time = 0.000,
      status = "skipped",
      skip_message = "Scientific notation validation not implemented yet",
    },
    {
      name = "validates decimal precision correctly",
      classname = "NumberValidator",
      time = 0.002,
      status = "pass",
    },
  },
}

-- Create multiple test suites to demonstrate grouping
local multi_suite_test_results = {
  name = "Multi-Suite Example",
  timestamp = "2025-01-01T00:00:00Z", -- Static timestamp
  tests = 6,
  failures = 1,
  errors = 0,
  skipped = 0,
  time = 0.25,
  test_cases = {
    {
      name = "can create new user accounts",
      classname = "UserService",
      time = 0.042,
      status = "pass",
    },
    {
      name = "can authenticate users with valid credentials",
      classname = "UserService",
      time = 0.038,
      status = "pass",
    },
    {
      name = "rejects invalid login attempts",
      classname = "UserService",
      time = 0.015,
      status = "pass",
    },
    {
      name = "creates new orders correctly",
      classname = "OrderService",
      time = 0.055,
      status = "pass",
    },
    {
      name = "calculates order totals correctly",
      classname = "OrderService",
      time = 0.022,
      status = "fail",
      failure = {
        message = "Order total calculation failed for multi-currency orders",
        type = "AssertionError",
        details = "test/order_service_test.lua:128: Expected 125.50, got 120.75",
      },
    },
    {
      name = "processes refunds correctly",
      classname = "OrderService",
      time = 0.078,
      status = "pass",
    },
  },
}

-- Create tests to demonstrate the JUnit formatter
--- Test suite demonstrating JUnit XML report generation and configuration.
--- @within examples.junit_example
describe("JUnit Formatter Example", function()
  local temp_dir -- Stores the temporary directory helper object

  --- Setup hook: Create a temporary directory for reports.
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  --- Teardown hook: Release reference. Directory cleaned automatically.
  after(function()
    temp_dir = nil
  end)

  --- Tests generating a basic JUnit XML report with default settings.
  it("generates basic JUnit XML test results with defaults", function()
    -- Generate JUnit XML report
    logger.info("Generating basic JUnit XML test results report...")
    local junit_xml = reporting.format_results(mock_test_results, "junit")

    -- Validate the report
    expect(junit_xml).to.exist()
    expect(junit_xml).to.be.a("string")
    expect(junit_xml).to.match("<testsuite") -- Should have testsuite element
    expect(junit_xml).to.match("<testcase") -- Should have testcase elements
    expect(junit_xml).to.match("failures=") -- Should have failure count
    expect(junit_xml).to.match("errors=") -- Should have error count
    expect(junit_xml).to.match("skipped=") -- Should have skipped count
    expect(junit_xml).to.match("<failure") -- Should have failure element
    expect(junit_xml).to.match("<error") -- Should have error element
    expect(junit_xml).to.match("<skipped") -- Should have skipped element

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "test-results.xml")
    local success, err = fs.write_file(file_path, junit_xml)

    -- Check if write was successful
    expect(err).to.be_nil() -- Check for nil error string
    expect(success).to.be_truthy()

    logger.info("Basic JUnit XML report saved to: " .. file_path)
    logger.info("Report size: " .. #junit_xml .. " bytes")

    -- Preview the JUnit XML output
    logger.info("\nJUnit XML Preview:")
    print(junit_xml:sub(1, 500) .. "...\n") -- Print preview
  end)

  --- Tests configuring JUnit formatter options (timestamps, hostname, properties, etc.).
  it("demonstrates JUnit formatter configuration options", function()
    -- Configure JUnit formatter options via central_config
    central_config.set("reporting.formatters.junit", {
      include_timestamp = true, -- Include timestamp attribute
      include_hostname = true, -- Include hostname attribute
      include_properties = true, -- Include properties element
      include_system_out = true, -- Include system-out element
      include_system_err = true, -- Include system-err element
      normalize_classnames = true, -- Normalize class names to standard format
      pretty_print = true, -- Format XML with indentation for readability
    })

    -- Temporarily add properties for this test case
    mock_test_results.properties = {
      { "name", "value" },
      { "lua_version", _VERSION },
      { "os", package.config:sub(1, 1) == "/" and "unix" or "windows" },
      { "test_mode", "example" },
      { "timestamp", "2025-01-01T00:00:00Z" }, -- Static timestamp
    }

    -- Generate the report with configuration
    logger.info("Generating configured JUnit XML test results report...")
    local junit_xml = reporting.format_results(mock_test_results, "junit")
    -- Remove temporary properties
    mock_test_results.properties = nil

    -- Validate the report
    expect(junit_xml).to.exist()
    expect(junit_xml).to.match("<properties>") -- Should have properties element
    expect(junit_xml).to.match("<property name=") -- Should have property elements
    expect(junit_xml).to.match("hostname=") -- Should have hostname attribute
    expect(junit_xml).to.match("<system%-out>") -- Should have system-out element

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "test-results-configured.xml")
    local success, err = fs.write_file(file_path, junit_xml)

    -- Check if write was successful
    expect(err).to.be_nil() -- Check for nil error string
    expect(success).to.be_truthy()

    logger.info("Configured JUnit XML report saved to: " .. file_path)

    -- Preview the JUnit XML output with configuration
    logger.info("\nConfigured JUnit XML Preview:")
    print(junit_xml:sub(1, 700) .. "...\n")
  end)

  --- Tests generating a multi-suite JUnit report using `group_by_classname`.
  it("demonstrates multi-suite JUnit XML reports", function()
    -- Configure JUnit formatter for multiple test suites
    central_config.set("reporting.formatters.junit", {
      group_by_classname = true, -- Group tests by classname into separate suites
      include_timestamp = true, -- Include timestamp attribute
      pretty_print = true, -- Format XML with indentation for readability
    })

    -- Generate multi-suite JUnit XML report
    logger.info("Generating multi-suite JUnit XML report...")
    local junit_xml = reporting.format_results(multi_suite_test_results, "junit")

    -- Validate the report has multiple test suites
    expect(junit_xml).to.exist()
    expect(junit_xml).to.match("<testsuites>") -- Should have testsuites root element
    expect(junit_xml).to.match('name="UserService"') -- Should have UserService suite
    expect(junit_xml).to.match('name="OrderService"') -- Should have OrderService suite

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "multi-suite-results.xml")
    local success, err = fs.write_file(file_path, junit_xml)

    -- Check if write was successful
    expect(err).to.be_nil() -- Check for nil error string
    expect(success).to.be_truthy()

    logger.info("Multi-suite JUnit XML report saved to: " .. file_path)

    -- Preview the multi-suite XML output
    logger.info("\nMulti-suite JUnit XML Preview:")
    print(junit_xml:sub(1, 700) .. "...\n")
  end)

  --- Informational test providing example CI/CD configurations for using JUnit reports.
  it("discusses CI/CD integration with JUnit XML reports", function()
    -- Generate JUnit XML report for CI/CD examples
    local junit_xml = reporting.format_results(mock_test_results, "junit")

    -- Save to common CI/CD file location
    local file_path = fs.join_paths(temp_dir.path, "junit-results.xml")
    local success, err = fs.write_file(file_path, junit_xml)
    expect(err).to.be_nil()
    expect(success).to.be_truthy()

    logger.info("CI/CD-ready JUnit XML report saved to: " .. file_path)

    -- Example CI/CD configurations for using JUnit XML reports
    local ci_examples = {
      github_actions = [[
# GitHub Actions workflow example for JUnit reports
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Lua
        uses: leafo/gh-actions-lua@v9
      - name: Run Tests
        run: lua test.lua --format=junit tests/
      - name: Publish Test Report
        uses: mikepenz/action-junit-report@v3
        if: always() # Always run even if tests fail
        with:
          report_paths: 'test-reports/junit/*.xml'
          fail_on_failure: true
]],

      jenkins = [[
// Jenkinsfile example for JUnit reports
pipeline {
  agent any
  stages {
    stage('Test') {
      steps {
        sh 'lua test.lua --format=junit tests/'
      }
      post {
        always {
          junit 'test-reports/junit/*.xml'
        }
      }
    }
  }
}
]],

      gitlab_ci = [[
# GitLab CI configuration example for JUnit reports
test:
  stage: test
  script:
    - lua test.lua --format=junit tests/
  artifacts:
    reports:
      junit: test-reports/junit/*.xml
]],
    }

    -- Print example CI/CD configurations
    logger.info("\nExample CI/CD configurations for JUnit XML integration:")

    logger.info("\n=== GitHub Actions ===")
    print(ci_examples.github_actions)

    logger.info("\n=== Jenkins ===")
    print(ci_examples.jenkins)

    logger.info("\n=== GitLab CI ===")
    print(ci_examples.gitlab_ci)
  end)

  -- Removed XML validation test case
end)

-- Add cleanup for temp_file module at the end
temp_file.cleanup_all()
