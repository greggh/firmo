#!/usr/bin/env lua
--[[
reporting_filesystem_integration.lua - Demo of the reporting module with filesystem integration

This example demonstrates how the reporting module uses the filesystem module for
file operations, showing both modules working together to generate test reports.
]]

-- Add the project directory to the module path
package.path = package.path .. ";./?.lua;./?/init.lua"

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

-- Load the modules directly for demonstration
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

-- Create a temporary directory for reports
local report_dir = "./temp-reports-demo"
fs.ensure_directory_exists(report_dir)

print("==== Demonstrating Reporting + Filesystem Integration ====\n")

-- Run a simple test suite to generate reports
describe("Filesystem-based Reporting Demo", function()
  it("generates reports in multiple formats", function()
    -- Create mock test results data
    local test_results = {
      name = "DemoTestSuite",
      timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
      tests = 5,
      failures = 1,
      errors = 0,
      skipped = 0,
      time = 0.42,
      test_cases = {
        {
          name = "test_passing",
          classname = "DemoTests",
          time = 0.1,
          status = "pass",
        },
        {
          name = "test_failing",
          classname = "DemoTests",
          time = 0.3,
          status = "fail",
          failure = {
            message = "Expected 5 to be 6",
            type = "Assertion",
            details = "test.lua:42: Expected 5 to be 6",
          },
        },
        {
          name = "test_another_passing",
          classname = "DemoTests",
          time = 0.02,
          status = "pass",
        },
      },
    }

    -- Mock coverage data
    local coverage_data = {
      files = {
        ["lib/core/init.lua"] = {
          executed_lines = { 1, 2, 3, 5, 7, 8, 10, 12 },
          line_count = 10,
          functions = {
            ["init"] = { calls = 1, line = 1 },
            ["setup"] = { calls = 1, line = 5 },
          },
        },
      },
      summary = {
        total_files = 1,
        covered_files = 1,
        total_lines = 10,
        covered_lines = 8,
        total_functions = 2,
        covered_functions = 2,
        line_coverage_percent = 80,
        function_coverage_percent = 100,
        overall_percent = 90,
      },
    }

    -- Save reports using the integrated modules
    print("Saving reports to: " .. report_dir)

    -- Show that filesystem module is being used by the reporting module
    print("\nUsing filesystem module functions:")
    print("  - fs.write_file() - Used by reporting.write_file()")
    print("  - fs.ensure_directory_exists() - Used for directory creation")
    print("  - fs.normalize_path() - Used for path handling")

    -- Configure report options with path templates
    local report_options = {
      report_dir = report_dir,
      report_suffix = "-demo",
      timestamp_format = "%Y-%m-%d",
      verbose = true,
      coverage_path_template = "coverage-{format}{suffix}",
      results_path_template = "results-{format}{suffix}",
    }

    -- Save all reports
    local results = reporting.auto_save_reports(
      coverage_data,
      nil, -- No quality data for this demo
      test_results,
      report_options
    )

    -- Verify reports were created
    print("\nGenerated reports:")
    for format, result in pairs(results) do
      local status = result.success and "SUCCESS" or "FAILED"
      print(string.format("  - %s: %s (%s)", format, fs.get_file_name(result.path), status))

      -- Verify file exists using filesystem module
      local exists = fs.file_exists(result.path)
      expect(exists).to.equal(true)
    end

    -- Show some file stats using filesystem module
    print("\nReport file information:")
    local files = fs.discover_files({ report_dir }, { "*" }, {})
    for _, file_path in ipairs(files) do
      local size = fs.get_file_size(file_path)
      local modified = fs.get_modified_time(file_path)
      local rel_path = fs.get_relative_path(file_path, ".")
      print(
        string.format("  - %s: %d bytes, modified at %s", rel_path, size or 0, os.date("%Y-%m-%d %H:%M:%S", modified))
      )
    end
  end)
end)

-- All tests are discovered and run automatically

print("\n==== Example Complete ====")
print("Generated reports are in: " .. report_dir)
print("You can remove this directory with: rm -rf " .. report_dir)
