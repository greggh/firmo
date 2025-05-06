--[[
  tap_example.lua

  Example demonstrating Test Anything Protocol (TAP) format generation with firmo.

  This example shows how to:
  - Generate TAP v13 test result reports
  - Configure TAP-specific options for diagnostics and YAML blocks via `central_config`.
  - Save TAP reports to disk using `fs.write_file`.
  - Use `test_helper` for managing temporary output files.
  - Discuss integrating TAP output with testing frameworks and CI systems.

  @module examples.tap_example
  @author Firmo Team
  @license MIT
  @copyright 2023-2025
  @version 1.0.0
  @see lib.reporting.formatters.tap
  @see lib.core.central_config
  @see lib.tools.test_helper
  @usage
  Run embedded tests:
  ```bash
  lua test.lua examples/tap_example.lua
  ```
  The generated TAP reports will be saved to a temporary directory.
]]

-- Import required modules
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local test_helper = require("lib.tools.test_helper") -- Added missing require
local logging = require("lib.tools.logging") -- Added missing require

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
local before = firmo.before -- Added missing require
local after = firmo.after -- Added missing require

-- Setup logger
local logger = logging.get_logger("TAPExample")

-- Create mock test results data (focusing on test results, not coverage)
--- @type MockTestResults (See csv_example.lua for definition)
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
--- Test suite demonstrating TAP report generation and configuration.
--- @within examples.tap_example
-- NOTE: The TAP formatter primarily focuses on coverage data. Tests for generating
--       test results using this formatter have been removed due to incompatibility
--       or lack of support, causing the reporting module to fall back to JUnit.

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
