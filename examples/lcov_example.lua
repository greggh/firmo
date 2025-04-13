--[[
  lcov_example.lua
  
  Example demonstrating LCOV coverage report generation with firmo.
  
  This example shows how to:
  - Generate LCOV coverage reports from coverage data
  - Configure LCOV-specific options
  - Save reports to disk using the filesystem module
  - Integrate LCOV reports with CI/CD tools like Codecov, Coveralls, and SonarQube
]]

-- Import firmo (no direct coverage module usage per project rules)
---@diagnostic disable-next-line: unused-local
local firmo = require("firmo")

-- Import required modules
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Create mock coverage data (consistent with other examples)
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = true,  -- This line was covered
        [2] = true,  -- This line was covered 
        [3] = true,  -- This line was covered
        [5] = false, -- This line was not covered
        [6] = true,  -- This line was covered
        [8] = false, -- This line was not covered
        [9] = false, -- This line was not covered
      },
      functions = {
        ["add"] = true,      -- This function was covered
        ["subtract"] = true, -- This function was covered
        ["multiply"] = false, -- This function was not covered
        ["divide"] = false,  -- This function was not covered
      },
      total_lines = 10,
      covered_lines = 4,
      total_functions = 4,
      covered_functions = 2,
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = true,  -- This line was covered
        [2] = true,  -- This line was covered
        [4] = true,  -- This line was covered
        [5] = true,  -- This line was covered
        [7] = false, -- This line was not covered
      },
      functions = {
        ["validate"] = true, -- This function was covered
        ["format"] = false,  -- This function was not covered
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
describe("LCOV Formatter Example", function()
  -- Ensure the reports directory exists
  local reports_dir = "coverage-reports"
  fs.ensure_directory_exists(reports_dir)
  
  it("generates basic LCOV coverage report", function()
    -- Generate LCOV report
    print("Generating basic LCOV coverage report...")
    local lcov_report = reporting.format_coverage(mock_coverage_data, "lcov")
    
    -- Validate the report
    expect(lcov_report).to.exist()
    expect(lcov_report).to.be.a("string")
    expect(lcov_report).to.match("TN:")  -- Test Name line
    expect(lcov_report).to.match("SF:")  -- Source File line
    expect(lcov_report).to.match("DA:")  -- Data line
    expect(lcov_report).to.match("LF:")  -- Lines Found
    expect(lcov_report).to.match("LH:")  -- Lines Hit
    expect(lcov_report).to.match("end_of_record")
    
    -- Save to file
    local file_path = fs.join_paths(reports_dir, "coverage-report.lcov")
    local success, err = fs.write_file(file_path, lcov_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Basic LCOV report saved to:", file_path)
    print("Report size:", #lcov_report, "bytes")
    
    -- Preview a sample of the LCOV output
    print("\nLCOV Preview (first 300 characters):")
    print(lcov_report:sub(1, 300) .. "...\n")
  end)
  
  it("demonstrates LCOV formatter configuration options", function()
    -- Configure LCOV formatter options via central_config
    central_config.set("reporting.formatters.lcov", {
      include_functions = true,   -- Include function coverage (FN, FNDA lines)
      test_name = "FirmoTests",   -- Set custom test name 
      source_prefix = "",         -- Strip source prefix from file paths
      exclude_patterns = {"test/"} -- Exclude files matching these patterns
    })
    
    -- Generate the report with configuration
    print("Generating configured LCOV coverage report...")
    local lcov_report = reporting.format_coverage(mock_coverage_data, "lcov")
    
    -- Validate the report
    expect(lcov_report).to.exist()
    expect(lcov_report).to.match("TN:FirmoTests")  -- Custom test name
    
    -- Save to file
    local file_path = fs.join_paths(reports_dir, "coverage-report-configured.lcov")
    local success, err = fs.write_file(file_path, lcov_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Configured LCOV report saved to:", file_path)
    print("Report size:", #lcov_report, "bytes")
    
    -- Preview a sample of the LCOV output
    print("\nConfigured LCOV Preview (first 300 characters):")
    print(lcov_report:sub(1, 300) .. "...\n")
  end)
  
  it("demonstrates CI integration with LCOV reports", function()
    -- Generate LCOV report
    local lcov_report = reporting.format_coverage(mock_coverage_data, "lcov")
    
    -- Save to the standard location that most CI tools expect
    local file_path = fs.join_paths(reports_dir, "lcov.info")
    local success, err = fs.write_file(file_path, lcov_report)
    expect(success).to.be_truthy()
    
    print("CI-ready LCOV report saved to:", file_path)
    
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
]]
    }
    
    -- Print example CI configurations
    print("\nExample CI configurations for LCOV integration:")
    print("\n=== GitHub Actions ===")
    print(example_configs.github_actions)
    
    print("\n=== GitLab CI ===")
    print(example_configs.gitlab_ci)
    
    print("\n=== Jenkins ===")
    print(example_configs.jenkins)
  end)
end)

print("\n=== LCOV Formatter Example ===")
print("This example demonstrates how to generate coverage reports in LCOV format.")
print("LCOV is a standard format supported by many CI/CD tools and coverage services.")

print("\nTo run this example directly:")
print("  lua examples/lcov_example.lua")

print("\nOr run it with firmo's test runner:")
print("  lua test.lua examples/lcov_example.lua")

print("\nCommon CI/CD services that support LCOV:")
print("- Codecov (codecov.io)")
print("- Coveralls (coveralls.io)")
print("- SonarQube/SonarCloud")
print("- Jenkins with the Coverage Plugin")
print("- GitHub Actions with codecov action")

print("\nLCOV Format Specification:")
print("- TN: Test Name")
print("- SF: Source File")
print("- FN: Function Name and Line")
print("- FNDA: Function Data (call count)")
print("- FNF: Functions Found")
print("- FNH: Functions Hit")
print("- DA: Line Data (line number, execution count)")
print("- LF: Lines Found")
print("- LH: Lines Hit")
print("- end_of_record: Separator between files")

print("\nExample complete!")

