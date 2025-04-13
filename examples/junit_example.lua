--[[
  junit_example.lua
  
  Example demonstrating JUnit XML test report generation with firmo.
  
  This example shows how to:
  - Generate JUnit XML test result reports
  - Configure JUnit-specific options for test suites and cases
  - Save JUnit XML reports to disk using the filesystem module
  - Integrate JUnit reports with CI/CD systems
  - Validate JUnit XML output against schema requirements
]]

-- Import firmo (no direct coverage module usage per project rules)
local firmo = require("firmo")

-- Import required modules
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Create mock test results data (consistent with other examples)
local mock_test_results = {
  name = "JUnit Example Test Suite",
  timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
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
      status = "pass"
    },
    {
      name = "validates negative numbers correctly",
      classname = "NumberValidator",
      time = 0.003,
      status = "pass"
    },
    {
      name = "validates zero correctly",
      classname = "NumberValidator",
      time = 0.001,
      status = "pass"
    },
    {
      name = "rejects non-numeric inputs",
      classname = "NumberValidator",
      time = 0.002,
      status = "pass"
    },
    {
      name = "handles boundary values correctly",
      classname = "NumberValidator",
      time = 0.015,
      status = "fail",
      failure = {
        message = "Expected validation to pass for MAX_INT but it failed",
        type = "AssertionError",
        details = "test/number_validator_test.lua:42: Expected isValid(9223372036854775807) to be true, got false"
      }
    },
    {
      name = "throws appropriate error for invalid format",
      classname = "NumberValidator",
      time = 0.005,
      status = "error",
      error = {
        message = "Runtime error in test",
        type = "Error",
        details = "test/number_validator_test.lua:53: attempt to call nil value (method 'formatError')"
      }
    },
    {
      name = "validates scientific notation",
      classname = "NumberValidator",
      time = 0.000,
      status = "skipped",
      skip_message = "Scientific notation validation not implemented yet"
    },
    {
      name = "validates decimal precision correctly",
      classname = "NumberValidator",
      time = 0.002,
      status = "pass"
    }
  }
}

-- Create multiple test suites to demonstrate grouping
local multi_suite_test_results = {
  name = "Multi-Suite Example",
  timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
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
      status = "pass"
    },
    {
      name = "can authenticate users with valid credentials",
      classname = "UserService",
      time = 0.038,
      status = "pass"
    },
    {
      name = "rejects invalid login attempts",
      classname = "UserService",
      time = 0.015,
      status = "pass"
    },
    {
      name = "creates new orders correctly",
      classname = "OrderService",
      time = 0.055,
      status = "pass"
    },
    {
      name = "calculates order totals correctly",
      classname = "OrderService",
      time = 0.022,
      status = "fail",
      failure = {
        message = "Order total calculation failed for multi-currency orders",
        type = "AssertionError",
        details = "test/order_service_test.lua:128: Expected 125.50, got 120.75"
      }
    },
    {
      name = "processes refunds correctly",
      classname = "OrderService",
      time = 0.078,
      status = "pass"
    }
  }
}

-- Create tests to demonstrate the JUnit formatter
describe("JUnit Formatter Example", function()
  -- Ensure the reports directory exists
  local reports_dir = "test-reports/junit"
  fs.ensure_directory_exists(reports_dir)
  
  it("generates basic JUnit XML test results", function()
    -- Generate JUnit XML report
    print("Generating basic JUnit XML test results report...")
    local junit_xml = reporting.format_results(mock_test_results, "junit")
    
    -- Validate the report
    expect(junit_xml).to.exist()
    expect(junit_xml).to.be.a("string")
    expect(junit_xml).to.match("<testsuite")  -- Should have testsuite element
    expect(junit_xml).to.match("<testcase")   -- Should have testcase elements
    expect(junit_xml).to.match("failures=")   -- Should have failure count
    expect(junit_xml).to.match("errors=")     -- Should have error count
    expect(junit_xml).to.match("skipped=")    -- Should have skipped count
    expect(junit_xml).to.match("<failure")    -- Should have failure element
    expect(junit_xml).to.match("<error")      -- Should have error element
    expect(junit_xml).to.match("<skipped")    -- Should have skipped element
    
    -- Save to file
    local file_path = fs.join_paths(reports_dir, "test-results.xml")
    local success, err = fs.write_file(file_path, junit_xml)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Basic JUnit XML report saved to:", file_path)
    print("Report size:", #junit_xml, "bytes")
    
    -- Preview the JUnit XML output
    print("\nJUnit XML Preview:")
    print(junit_xml:sub(1, 500) .. "...\n")
  end)
  
  it("demonstrates JUnit formatter configuration options", function()
    -- Configure JUnit formatter options via central_config
    central_config.set("reporting.formatters.junit", {
      include_timestamp = true,        -- Include timestamp attribute
      include_hostname = true,         -- Include hostname attribute
      include_properties = true,       -- Include properties element
      include_system_out = true,       -- Include system-out element
      include_system_err = true,       -- Include system-err element
      normalize_classnames = true,     -- Normalize class names to standard format
      pretty_print = true              -- Format XML with indentation for readability
    })
    
    -- Add custom properties to test results
    local test_results_with_props = table.deepcopy(mock_test_results)
    test_results_with_props.properties = {
      {"name", "value"},
      {"lua_version", _VERSION},
      {"os", package.config:sub(1,1) == "/" and "unix" or "windows"},
      {"test_mode", "example"},
      {"timestamp", os.date("!%Y-%m-%dT%H:%M:%S")}
    }
    
    -- Generate the report with configuration
    print("Generating configured JUnit XML test results report...")
    local junit_xml = reporting.format_results(test_results_with_props, "junit")
    
    -- Validate the report
    expect(junit_xml).to.exist()
    expect(junit_xml).to.match("<properties>")       -- Should have properties element
    expect(junit_xml).to.match("<property name=")    -- Should have property elements
    expect(junit_xml).to.match("hostname=")          -- Should have hostname attribute
    expect(junit_xml).to.match("<system%-out>")      -- Should have system-out element
    
    -- Save to file
    local file_path = fs.join_paths(reports_dir, "test-results-configured.xml")
    local success, err = fs.write_file(file_path, junit_xml)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Configured JUnit XML report saved to:", file_path)
    
    -- Preview the JUnit XML output with configuration
    print("\nConfigured JUnit XML Preview:")
    print(junit_xml:sub(1, 700) .. "...\n")
  end)
  
  it("demonstrates multi-suite JUnit XML reports", function()
    -- Configure JUnit formatter for multiple test suites
    central_config.set("reporting.formatters.junit", {
      group_by_classname = true,       -- Group tests by classname into separate suites
      include_timestamp = true,        -- Include timestamp attribute
      pretty_print = true              -- Format XML with indentation for readability
    })
    
    -- Generate multi-suite JUnit XML report
    print("Generating multi-suite JUnit XML report...")
    local junit_xml = reporting.format_results(multi_suite_test_results, "junit")
    
    -- Validate the report has multiple test suites
    expect(junit_xml).to.exist()
    expect(junit_xml).to.match("<testsuites>")     -- Should have testsuites root element
    expect(junit_xml).to.match("name=\"UserService\"")  -- Should have UserService suite
    expect(junit_xml).to.match("name=\"OrderService\"") -- Should have OrderService suite
    
    -- Save to file
    local file_path = fs.join_paths(reports_dir, "multi-suite-results.xml")
    local success, err = fs.write_file(file_path, junit_xml)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Multi-suite JUnit XML report saved to:", file_path)
    
    -- Preview the multi-suite XML output
    print("\nMulti-suite JUnit XML Preview:")
    print(junit_xml:sub(1, 700) .. "...\n")
  end)
  
  it("demonstrates CI/CD integration with JUnit XML reports", function()
    -- Generate JUnit XML report for CI/CD examples
    local junit_xml = reporting.format_results(mock_test_results, "junit")
    
    -- Save to common CI/CD file location
    local file_path = fs.join_paths(reports_dir, "junit-results.xml")
    local success, err = fs.write_file(file_path, junit_xml)
    expect(success).to.be_truthy()
    
    print("CI/CD-ready JUnit XML report saved to:", file_path)
    
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
]]
    }
    
    -- Print example CI/CD configurations
    print("\nExample CI/CD configurations for JUnit XML integration:")
    
    print("\n=== GitHub Actions ===")
    print(ci_examples.github_actions)
    
    print("\n=== Jenkins ===")
    print(ci_examples.jenkins)
    
    print("\n=== GitLab CI ===")
    print(ci_examples.gitlab_ci)
  end)
  
  it("demonstrates JUnit XML validation and schema compliance", function()
    -- Generate JUnit XML report
    local junit_xml = reporting.format_results(mock_test_results, "junit")
    
    -- Perform basic validation checks (matching opening/closing tags)
    local function count_xml_tag(xml, tag)
      local open_tag = "<%s" -- Pattern for opening tag with attributes
      local close_tag = "</%s>" -- Pattern for closing tag
      
      local open_count = 0
      for _ in string.gmatch(xml, string.format(open_tag, tag)) do
        open_count = open_count + 1
      end
      
      local close_count = 0
      for _ in string.gmatch(xml, string.format(close_tag, tag)) do
        close_count = close_count + 1
      end
      
      return open_count, close_count
    end
    
    -- Validate testsuite tags
    local open_testsuite, close_testsuite = count_xml_tag(junit_xml, "testsuite")
    print(string.format("Validating XML: testsuite tags (%d open, %d close)", 
                        open_testsuite, close_testsuite))
    expect(open_testsuite).to.equal(close_testsuite)
    
    -- Validate testcase tags
    local open_testcase, close_testcase = count_xml_tag(junit_xml, "testcase")
    print(string.format("Validating XML: testcase tags (%d open, %d close)", 
                        open_testcase, close_testcase))
    expect(open_testcase).to.equal(close_testcase)
    
    -- JUnit XML schema key requirements
    print("\nKey JUnit XML Schema Requirements:")
    print("1. Every <testsuite> must have attributes: name, tests, failures, errors, skipped, time")
    print("2. Every <testcase> must have attributes: name, classname, time")
    print("3. Failure elements must have type and message attributes")
    print("4. Error elements must have type and message attributes")
    print("5. XML must be well-formed (matching tags, proper nesting)")
    
    -- Check for minimal required attributes

