--- Example demonstrating Cobertura XML coverage report generation.
---
--- This example showcases how to generate Cobertura XML coverage reports using
--- Firmo's reporting module. It covers:
--- - Creating mock coverage data for demonstration.
--- - Manually formatting the mock data into Cobertura XML using `reporting.format_coverage()`.
--- - Saving the generated XML report to a file using `fs.write_file()`.
--- - Using the `temp_file` module to manage the output directory for cleanup.
--- - Discusses the compatibility of Cobertura reports with CI/CD systems.
---
--- Note: This example uses *mock* coverage data and manually calls the formatter.
--- In a real scenario, you would run tests with `--coverage --format=cobertura`
--- and Firmo would handle data collection and formatting automatically based on config.
---
--- @module examples.cobertura_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.reporting
--- @see lib.reporting.formatters.cobertura
--- @see lib.tools.filesystem.temp_file
--- @usage
--- Run this example directly to generate a mock Cobertura report in a temporary directory:
--- ```bash
--- lua examples/cobertura_example.lua
--- ```

-- Import necessary modules
local reporting = require("lib.reporting")
local temp_file = require("lib.tools.filesystem.temp_file")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem") -- Added missing import

-- Setup logger
local logger = logging.get_logger("CoberturaExample")

-- Mock coverage data structure for demonstration purposes.
-- This simulates the data structure the reporting module expects.
--- @class MockCoverageData
--- @field files table<string, FileCoverageData> Coverage data per file.
--- @field summary CoverageSummaryData Overall summary statistics.
--- @field lines table<number, { executable: boolean, execution_count: number }> Line coverage data.
--- @field functions table<string, FunctionCoverageData> Function coverage data.
--- @field total_lines number Total lines in the file.
--- @field executable_lines number Total executable lines in the file.
--- @field covered_lines number Number of executable lines covered (execution_count > 0).
--- @field total_functions number Total functions defined in the file.
--- @field covered_functions number Number of functions covered (execution_count > 0).
--- @field line_coverage_percent number Percentage of executable lines covered.
--- @field function_coverage_percent number Percentage of functions covered.
--- @field branch_coverage_percent number Percentage of branches covered (optional).
--- @within examples.cobertura_example
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = { executable = true, execution_count = 1 },
        [2] = { executable = true, execution_count = 1 },
        [3] = { executable = true, execution_count = 1 },
        [5] = { executable = true, execution_count = 0 }, -- false becomes count 0
        [6] = { executable = true, execution_count = 1 },
        [8] = { executable = true, execution_count = 0 },
        [9] = { executable = true, execution_count = 0 },
      },
      --- @class FunctionCoverageData
      --- @field name string Function name.
      --- @field start_line number Starting line number.
      --- @field end_line number Ending line number.
      --- @field execution_count number How many times the function was entered.
      functions = {
        ["add"] = { name = "add", start_line = 5, end_line = 10, execution_count = 1 },
        ["subtract"] = { name = "subtract", start_line = 11, end_line = 15, execution_count = 1 },
        ["multiply"] = { name = "multiply", start_line = 16, end_line = 20, execution_count = 0 },
        ["divide"] = { name = "divide", start_line = 21, end_line = 25, execution_count = 0 },
      },
      total_lines = 25, -- Estimated based on function end lines
      executable_lines = 7, -- Number of entries in lines table
      covered_lines = 4, -- Number with execution_count > 0
      total_functions = 4,
      covered_functions = 2, -- Number with execution_count > 0
      line_coverage_percent = (4 / 7) * 100, -- Recalculated
      function_coverage_percent = (2 / 4) * 100, -- Recalculated
      branch_coverage_percent = 100.0, -- Placeholder
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = { executable = true, execution_count = 1 },
        [2] = { executable = true, execution_count = 1 },
        [4] = { executable = true, execution_count = 1 },
        [5] = { executable = true, execution_count = 1 },
        [7] = { executable = true, execution_count = 0 }, -- false becomes count 0
      },
      functions = {
        ["validate"] = { name = "validate", start_line = 3, end_line = 8, executed = true, execution_count = 1 },
        ["format"] = { name = "format", start_line = 9, end_line = 12, executed = false, execution_count = 0 },
      },
      total_lines = 12, -- Estimated based on function end lines
      executable_lines = 5, -- Number of entries in lines table
      covered_lines = 4, -- Number with execution_count > 0
      total_functions = 2,
      covered_functions = 1, -- Number with execution_count > 0
      line_coverage_percent = (4 / 5) * 100, -- Recalculated
      function_coverage_percent = (1 / 2) * 100, -- Recalculated
      branch_coverage_percent = 100.0, -- Placeholder
    },
  },
  --- @class CoverageSummaryData
  --- @field total_files number Total number of files processed.
  --- @field covered_files number Number of files with > 0% coverage.
  --- @field total_lines number Total lines across all files.
  --- @field executable_lines number Total executable lines across all files.
  --- @field covered_lines number Total covered executable lines.
  --- @field total_functions number Total functions across all files.
  --- @field covered_functions number Total covered functions.
  --- @field line_coverage_percent number Overall line coverage percentage.
  --- @field function_coverage_percent number Overall function coverage percentage.
  --- @field overall_percent number Overall coverage percentage (often based on lines).
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 37, -- 25 + 12
    executable_lines = 12, -- 7 + 5
    covered_lines = 8, -- 4 + 4
    total_functions = 6, -- 4 + 2
    covered_functions = 3, -- 2 + 1
    line_coverage_percent = (8 / 12) * 100, -- Recalculated: ~66.7%
    function_coverage_percent = (3 / 6) * 100, -- Recalculated: 50.0%
    overall_percent = (8 / 12) * 100, -- Typically based on lines
  },
}

-- Create a temporary directory for the report using the temp_file helper.
-- This ensures the directory is automatically cleaned up later.
local temp_dir_path, err = temp_file.create_temp_directory("cobertura_example_")

if not temp_dir_path then
  logger.error("Failed to create temporary directory: " .. tostring(err))
  -- In a real script, you might os.exit(1) here
  return -- Exit script if temp directory fails
end

logger.info("Created temporary directory for reports: " .. temp_dir_path)

-- Demonstrating Cobertura report generation using the mock data
logger.info("\nGenerating Cobertura report from mock data...")

-- Manually format the mock data into Cobertura XML
local cobertura_xml, format_err = reporting.format_coverage(mock_coverage_data, "cobertura")

if not cobertura_xml then
  logger.error(
    "Failed to format Cobertura report",
    { error = format_err and format_err.message or "Unknown formatting error" }
  )
else
  -- Save the generated XML to a file within the temporary directory
  local file_path = fs.join_paths(temp_dir_path, "coverage-report.cobertura")
  logger.info("Saving Cobertura report to: " .. file_path)
  local success, write_err = fs.write_file(file_path, cobertura_xml)

  if success then
    logger.info("Mock Cobertura report saved successfully.", { path = file_path, size = #cobertura_xml })
  else
    logger.error(
      "Failed to save Cobertura report",
      { path = file_path, error = write_err and write_err.message or "Unknown write error" }
    )
  end
end

logger.info("\nMock report saved in temporary directory: " .. temp_dir_path)
print("\nCobertura XML report format is compatible with many CI/CD tools, including:")
print("- Jenkins (Cobertura Plugin)")
print("- GitHub Actions (e.g., codecov/codecov-action)")
print("- GitHub Actions with the codecov action")
print("- GitLab CI with the coverage functionality")
print("- Azure DevOps with the Publish Code Coverage task")

logger.info("\nExample complete!")

-- Cleanup temporary directory (handled by temp_file registration or test runner)
