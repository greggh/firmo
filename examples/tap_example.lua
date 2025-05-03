--[[
  tap_example.lua

  Example demonstrating Test Anything Protocol (TAP) format generation with firmo.

  This example shows how to:
  - Generate TAP v13 test result reports
  - Configure TAP-specific options for diagnostics and YAML blocks
  - Save TAP reports to disk using the filesystem module
  - Integrate TAP output with testing frameworks and CI systems
]]

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

-- Create mock test results data (focusing on test results, not coverage)
local mock_test_results = {
  name = "TAP Example Test Suite",
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

-- Create tests to demonstrate the TAP formatter
describe("TAP Formatter Example", function()
  -- Ensure the reports directory exists
  local reports_dir = "test-reports"
  fs.ensure_directory_exists(reports_dir)

  it("generates basic TAP test results", function()
    -- Generate TAP report
    print("Generating basic TAP test results report...")
    local tap_report = reporting.format_results(mock_test_results, "tap")

    -- Validate the report
    expect(tap_report).to.exist()
    expect(tap_report).to.be.a("string")
    expect(tap_report).to.match("TAP version 13")
    expect(tap_report).to.match("1%.%.%d+") -- Test count (1..n)
    expect(tap_report).to.match("ok %d+") -- Passed test
    expect(tap_report).to.match("not ok %d+") -- Failed test

    -- Save to file
    local file_path = fs.join_paths(reports_dir, "test-results.tap")
    local success, err = fs.write_file(file_path, tap_report)

    -- Check if write was successful
    expect(success).to.be_truthy()

    print("Basic TAP report saved to:", file_path)
    print("Report size:", #tap_report, "bytes")

    -- Preview the TAP output
    print("\nTAP Preview:")
    print(tap_report:sub(1, 500) .. "...\n")
  end)

  it("demonstrates TAP formatter configuration options", function()
    -- Configure TAP formatter options via central_config
    central_config.set("reporting.formatters.tap", {
      include_yaml = true, -- Include YAML blocks with additional info
      include_diagnostics = true, -- Include diagnostic messages for failed tests
      include_timestamps = true, -- Include timestamps in output
      bail_on_fail = false, -- Don't stop on first failure (no Bail out! directive)
      include_test_duration = true, -- Include test duration in output
      compact_output = false, -- Use verbose output format
    })

    -- Generate the report with configuration
    print("Generating configured TAP test results report...")
    local tap_report = reporting.format_results(mock_test_results, "tap")

    -- Validate the report
    expect(tap_report).to.exist()
    expect(tap_report).to.match("---") -- YAML block start
    expect(tap_report).to.match("duration:") -- Test duration in YAML

    -- Save to file
    local file_path = fs.join_paths(reports_dir, "test-results-configured.tap")
    local success, err = fs.write_file(file_path, tap_report)

    -- Check if write was successful
    expect(success).to.be_truthy()

    print("Configured TAP report saved to:", file_path)

    -- Preview the TAP output with YAML blocks
    print("\nConfigured TAP Preview with YAML blocks:")
    print(tap_report:sub(1, 700) .. "...\n")
  end)

  it("demonstrates integrating TAP output with test harnesses", function()
    -- Generate TAP report
    local tap_report = reporting.format_results(mock_test_results, "tap")

    -- Save to common file location for test harnesses
    local file_path = fs.join_paths(reports_dir, "tap-output.tap")
    local success, err = fs.write_file(file_path, tap_report)
    expect(success).to.be_truthy()

    print("TAP report for test harnesses saved to:", file_path)

    -- Example of tap consumers and commands to run them
    print("\nCommon TAP consumers and how to use them:")
    print("1. prove (Perl's TAP harness):")
    print("   $ prove --exec 'lua' examples/tap_example.lua")

    print("\n2. tape (JavaScript TAP harness):")
    print("   $ lua examples/tap_example.lua | npx tape-run")

    print("\n3. tap-spec (TAP formatter):")
    print("   $ lua examples/tap_example.lua | npx tap-spec")

    print("\n4. Jenkins with TAP Plugin:")
    print("   Configure to read " .. file_path)

    print("\n5. GitHub Actions with TAP reporting:")
    print("   $ lua test.lua --format=tap tests/ > test-output.tap")

    -- Simple TAP parser example
    print("\nSimple TAP parser example:")
    local lines = {}
    for line in tap_report:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end

    local passed, failed, skipped = 0, 0, 0
    for _, line in ipairs(lines) do
      if line:match("^ok %d+") and not line:match("# SKIP") then
        passed = passed + 1
      elseif line:match("^not ok %d+") then
        failed = failed + 1
      elseif line:match("# SKIP") then
        skipped = skipped + 1
      end
    end

    print(string.format("Parsed results: %d passed, %d failed, %d skipped", passed, failed, skipped))
  end)
end)

print("\n=== TAP Formatter Example ===")
print("This example demonstrates how to generate test results in TAP format.")
print("TAP (Test Anything Protocol) is a standard format for test output supported by many test frameworks.")

print("\nTo run this example directly:")
print("  lua examples/tap_example.lua")

print("\nOr run it with firmo's test runner:")
print("  lua test.lua examples/tap_example.lua")

print("\nTAP Format Overview:")
print("- 'TAP version 13' - Protocol version declaration")
print("- '1..n' - Plan line with number of tests")
print("- 'ok 1 - test name' - Passing test")
print("- 'not ok 2 - test name' - Failing test")
print("- '# Diagnostic message' - Comments and diagnostics")
print("- 'ok 3 # SKIP skipped test' - Skipped test")
print("- 'Bail out! [reason]' - Abort testing (optional)")
print("- YAML blocks for additional test information (indented with spaces):")
print("  ---")
print("  message: Additional test information")
print("  severity: comment")
print("  ...")

print("\nCommon uses for TAP format:")
print("1. Integration with CI/CD systems")
print("2. Test reporting with standardized harnesses")
print("3. Cross-language test aggregation")
print("4. Historical test result tracking")

print("\nExample complete!")
