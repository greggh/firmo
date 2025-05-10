--- JUnit Coverage Formatter Example
---
--- This example demonstrates how to use the JUnit coverage formatter to generate
--- XML coverage reports compatible with CI systems. It shows how to:
---   1. Load and use the JUnit formatter via the coverage_formatters module
---   2. Prepare sample coverage data matching the expected input structure
---   3. Format the data with various formatter options
---   4. Write the output to a file
---   5. Parse and validate the generated XML
---
--- The example includes both passing and failing coverage cases to show how
--- JUnit test cases are generated for coverage metrics.
---
--- @module examples.junit_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.reporting.formatters.junit
--- @usage
--- Run this example: lua firmo.lua examples/junit_example.lua

-- Extract required testing functions
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import necessary modules
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")
local coverage_formatters = require("lib.reporting.formatters.coverage_formatters")
local temp_file = require("lib.tools.filesystem.temp_file")

-- Set up logger
local logger = logging.get_logger("JUnitExample")

-- Simple Calculator module to use for coverage example
local Calculator = {}

-- This function will have "good" coverage
function Calculator.add(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a + b
end

-- This function will have "poor" coverage
function Calculator.subtract(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a - b
end

describe("JUnit Coverage Formatter Example", function()
  it("demonstrates how to use the JUnit coverage formatter", function()
    -- Get the JUnit formatter from the coverage_formatters registry
    local junit_formatter = coverage_formatters.get_formatter("junit")
    expect(junit_formatter).to.exist()
    logger.info("Successfully loaded JUnit formatter")

    -- Create sample coverage data that matches the expected structure
    -- This mimics what the coverage module would produce
    local sample_coverage_data = {
      summary = {
        coverage_percent = 75.5,  -- Overall coverage percentage
        total_files = 2,          -- Total number of files
        total_lines = 100,        -- Total lines across all files
        covered_lines = 75,       -- Total covered lines across all files
        executed_lines = 80       -- Total executed lines across all files
      },
      files = {
        ["calculator.lua"] = {
          name = "calculator.lua",
          path = "calculator.lua",
          summary = {
            coverage_percent = 90.0,      -- This file has good coverage
            total_lines = 50,
            covered_lines = 45,
            executed_lines = 48,
            not_covered_lines = 5
          },
          -- Example line details
          lines = {
            [1] = { covered = true, executed = true, execution_count = 10 },
            [2] = { covered = true, executed = true, execution_count = 10 },
            [45] = { covered = false, executed = false, execution_count = 0 },
            [46] = { covered = false, executed = false, execution_count = 0 }
          }
        },
        ["utilities.lua"] = {
          name = "utilities.lua",
          path = "utilities.lua",
          summary = {
            coverage_percent = 60.0,      -- This file has poor coverage
            total_lines = 50,
            covered_lines = 30,
            executed_lines = 32,
            not_covered_lines = 20
          },
          -- Example line details
          lines = {
            [10] = { covered = false, executed = false, execution_count = 0 },
            [11] = { covered = false, executed = false, execution_count = 0 },
            [12] = { covered = false, executed = false, execution_count = 0 },
            [20] = { covered = true, executed = true, execution_count = 5 }
          }
        }
      }
    }

    -- Example 1: Basic JUnit coverage report
    logger.info("Example 1: Basic JUnit coverage report")
    local basic_options = {
      threshold = 70,              -- Overall coverage threshold
      file_threshold = 80,         -- Per-file coverage threshold
      suite_name = "Coverage Demo" -- Name for the testsuite
    }
    
    local xml_content = junit_formatter:format(sample_coverage_data, basic_options)
    expect(xml_content).to.exist()
    
    -- Write the XML to a file
    local temp_path = temp_file.create_with_content(xml_content, "xml")
    logger.info("Wrote basic JUnit coverage report to: " .. temp_path)
    
    -- Basic validation of the XML content
    expect(xml_content).to.match("<?xml version")
    expect(xml_content).to.match("<testsuites>")
    expect(xml_content).to.match("</testsuites>")
    expect(xml_content).to.match("Coverage Demo")  -- Our suite name
    expect(xml_content).to.match("75.50")          -- Overall coverage
    expect(xml_content).to.match("90.00")          -- calculator.lua coverage
    expect(xml_content).to.match("60.00")          -- utilities.lua coverage
    
    -- Check that we have a passing and failing test case
    expect(xml_content).to.match("calculator.lua")
    expect(xml_content).to.match("utilities.lua")
    
    -- Example 2: Report with failing threshold
    logger.info("Example 2: JUnit report with failing threshold")
    local strict_options = {
      threshold = 80,              -- Set threshold higher than our 75.5% overall
      file_threshold = 70,         -- Per-file threshold
      suite_name = "Strict Coverage",
      include_uncovered_lines = true  -- Include details of uncovered lines
    }
    
    local strict_xml = junit_formatter:format(sample_coverage_data, strict_options)
    expect(strict_xml).to.exist()
    
    -- Write to a temp file
    local strict_path = temp_file.create_with_content(strict_xml, "xml")
    logger.info("Wrote strict JUnit coverage report to: " .. strict_path)
    
    -- Validate that we have failure elements
    expect(strict_xml).to.match("<failure message=")
    expect(strict_xml).to.match("Overall coverage below threshold")
    expect(strict_xml).to.match("Coverage: 75.50%% %(threshold: 80%%%)") -- Note escaped % signs
    
    -- The utilities.lua file should also fail its threshold
    expect(strict_xml).to.match("utilities.lua.*Coverage below threshold")
    
    -- Should include uncovered lines details
    expect(strict_xml).to.match("Uncovered lines:")
    
    -- Example 3: Show how to get all available coverage formatters
    logger.info("Example 3: List all available coverage formatters")
    local available_formats = coverage_formatters.get_available_formats()
    expect(available_formats).to.be.a("table")
    expect(#available_formats).to.be.greater_than(0)
    
    logger.info("Available coverage formatters:")
    for _, format in ipairs(available_formats) do
      logger.info("  - " .. format)
    end
    
    -- Example 4: Demonstrate custom properties
    logger.info("Example 4: JUnit report with custom properties")
    local custom_options = {
      threshold = 75,
      suite_name = "Custom Properties Demo",
      properties = {
        environment = "test",
        git_commit = "abcdef123456",
        build_id = "12345"
      }
    }
    
    local custom_xml = junit_formatter:format(sample_coverage_data, custom_options)
    expect(custom_xml).to.exist()
    
    -- Check that the custom properties were included
    expect(custom_xml).to.match('property name="environment" value="test"')
    expect(custom_xml).to.match('property name="git_commit" value="abcdef123456"')
    expect(custom_xml).to.match('property name="build_id" value="12345"')
    
    -- Write to a file
    local custom_path = temp_file.create_with_content(custom_xml, "xml")
    logger.info("Wrote custom JUnit coverage report to: " .. custom_path)
    
    -- CI integration examples
    logger.info("\nCI/CD Integration Examples:")
    logger.info("GitHub Actions:\n```yaml")
    logger.info("- name: Run Tests with Coverage")
    logger.info("  run: lua firmo.lua --coverage --format=junit tests/")
    logger.info("- name: Publish Coverage Report")
    logger.info("  uses: mikepenz/action-junit-report@v3")
    logger.info("  if: always() # Always run")
    logger.info("  with:")
    logger.info("    report_paths: junit-coverage-results.xml")
    logger.info("```\n")
    
    logger.info("GitLab CI:\n```yaml")
    logger.info("coverage:")
    logger.info("  stage: test")
    logger.info("  script:")
    logger.info("    - lua firmo.lua --coverage --format=junit tests/")
    logger.info("  artifacts:")
    logger.info("    reports:")
    logger.info("      junit: junit-coverage-results.xml")
    logger.info("```\n")
    
    logger.info("Jenkins:\n```groovy")
    logger.info("pipeline {")
    logger.info("  agent any")
    logger.info("  stages {")
    logger.info("    stage('Test with Coverage') {")
    logger.info("      steps {")
    logger.info("        sh 'lua firmo.lua --coverage --format=junit tests/'")
    logger.info("      }")
    logger.info("      post {")
    logger.info("        always {")
    logger.info("          junit 'junit-coverage-results.xml'")
    logger.info("        }")
    logger.info("      }")
    logger.info("    }")
    logger.info("  }")
    logger.info("}")
    logger.info("```")
  end)
end)

-- Run this example using:
-- lua firmo.lua examples/junit_example.lua

-- Example complete! To learn more about JUnit coverage reports, see: lib/reporting/formatters/junit.lua

-- Cleanup is handled automatically by test_helper registration
