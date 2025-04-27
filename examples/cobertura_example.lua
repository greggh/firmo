--- cobertura_example.lua
--
-- This example demonstrates generating Cobertura XML format coverage reports
-- using Firmo's reporting module. It shows how to:
-- - Use `reporting.auto_save_reports` to generate multiple formats including Cobertura.
-- - Configure the output directory using `central_config` principles (via `auto_save_reports`).
-- - Use `temp_file` module to manage temporary output directories.
-- - Highlights compatibility with common CI/CD tools that consume Cobertura reports.
--
-- Run this example directly: lua examples/cobertura_example.lua
--

-- Import necessary modules
local error_handler = require("lib.tools.error_handler")
local reporting = require("lib.reporting")
local central_config = require("lib.core.central_config") -- Although not explicitly used, implicitly used by auto_save
local temp_file = require("lib.tools.filesystem.temp_file")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem") -- Added missing import

-- Setup logger
local logger = logging.get_logger("CoberturaExample")

-- Mock coverage data for the example
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = { executable = true, execution_count = 1 },
        [2] = { executable = true, execution_count = 1 },
        [3] = { executable = true, execution_count = 1 },
        [5] = { executable = true, execution_count = 0 }, -- false becomes count 0
        [6] = { executable = true, execution_count = 1 },
        [8] = { executable = true, execution_count = 0 }, -- false becomes count 0
        [9] = { executable = true, execution_count = 0 }, -- false becomes count 0
      },
      functions = {
        ["add"] = { name = "add", start_line = 5, end_line = 10, executed = true, execution_count = 1 },
        ["subtract"] = { name = "subtract", start_line = 11, end_line = 15, executed = true, execution_count = 1 },
        ["multiply"] = { name = "multiply", start_line = 16, end_line = 20, executed = false, execution_count = 0 },
        ["divide"] = { name = "divide", start_line = 21, end_line = 25, executed = false, execution_count = 0 },
      },
      total_lines = 10,
      covered_lines = 4,
      executable_lines = 8, -- Added estimated field
      total_functions = 4,
      covered_functions = 2,
      line_coverage_percent = 40.0, -- Added field
      function_coverage_percent = 50.0, -- Added field
      branch_coverage_percent = 100.0, -- Added field
    }, -- <<< Comma
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
      total_lines = 8,
      covered_lines = 4,
      executable_lines = 6, -- Added estimated field
      total_functions = 2,
      covered_functions = 1,
      line_coverage_percent = 50.0, -- Added field
      function_coverage_percent = 50.0, -- Added field
      branch_coverage_percent = 100.0, -- Added field
    }, -- <<< Comma
  }, -- <<< Comma
  summary = {
    total_files = 2, -- Added missing field
    covered_files = 2,
    total_lines = 18,
    executable_lines = 14, -- Added missing field (sum of per-file executable lines)
    covered_lines = 8, -- Corrected based on file data
    total_functions = 6,
    covered_functions = 3, -- Corrected based on file data
    line_coverage_percent = 44.4, -- 8/18
    function_coverage_percent = 50.0, -- 3/6
    overall_percent = 47.2, -- (44.4 + 50.0) / 2
  },
}

-- Create a temporary directory for the reports
local temp_dir, err = temp_file.create_temp_directory()
if not temp_dir then
  logger.error("Failed to create temporary directory: " .. tostring(err))
  -- In a real script, you might os.exit(1) here
  return
end
logger.info("Created temporary directory for reports: " .. temp_dir) -- temp_dir is the path string
-- Demonstrating Cobertura report generation
logger.info("\nGenerating and saving Cobertura report...")

-- Manually format and save only the Cobertura report
logger.info("Generating Cobertura report...")
local cobertura_xml, format_err = reporting.format_coverage(mock_coverage_data, "cobertura")

if not cobertura_xml then
  logger.error(
    "Failed to format Cobertura report",
    { error = format_err and format_err.message or "Unknown formatting error" }
  )
else
  local file_path = fs.join_paths(temp_dir, "coverage-report.cobertura")
  logger.info("Saving Cobertura report to: " .. file_path)
  local success, write_err = fs.write_file(file_path, cobertura_xml)

  if success then
    logger.info("Cobertura report saved successfully.", { path = file_path, size = #cobertura_xml })
  else
    logger.error(
      "Failed to save Cobertura report",
      { path = file_path, error = write_err and write_err.message or "Unknown write error" }
    )
  end
end

logger.info("\nReports saved in: " .. temp_dir) -- temp_dir is the path string
print("\nCobertura XML report is now saved and can be used with CI/CD systems that support this format.")
print("Common systems that use Cobertura XML include:")
print("- Jenkins with the Cobertura Plugin")
print("- GitHub Actions with the codecov action")
print("- GitLab CI with the coverage functionality")
print("- Azure DevOps with the Publish Code Coverage task")

logger.info("\nExample complete!")

-- Cleanup temporary directory
temp_file.cleanup_all()
