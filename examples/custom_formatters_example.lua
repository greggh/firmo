--- Example demonstrating custom report formatter creation and registration in Firmo.
---
--- This example shows how to define custom functions to format both test results
--- and code coverage data into a non-standard format (in this case, Markdown).
---
--- It covers:
--- - Defining formatter functions that accept standardized data structures (`coverage_data`, `results_data`).
--- - Implementing the logic to transform these data structures into a custom string output (Markdown).
--- - Registering the custom formatters with Firmo's reporting system using `reporting.register_coverage_formatter()` and `reporting.register_results_formatter()`.
--- - Verifying the registration using `reporting.get_available_formatters()`.
--- - Generating a report using the newly registered custom formatter (`reporting.format_results()`).
--- - Saving the custom report to a file managed by the `temp_file` module.
--- - Discussing how custom formatters might be loaded dynamically using `--load-formatters`.
---
--- @module examples.custom_formatters_example
--- @see lib.reporting
--- @see lib.tools.filesystem.temp_file
--- @usage
--- Run this example directly to see the custom formatter registration and output:
--- ```bash
--- lua examples/custom_formatters_example.lua
--- ```
--- The generated Markdown report will be saved to a temporary file (path logged to console).

-- Load firmo and required modules
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("CustomFormatterExample")

--- Example module structure containing custom formatter functions.
-- In a real project, this could be a separate Lua file loaded via `--load-formatters`.
--- @class CustomFormattersModule
--- @field coverage table Table containing custom coverage formatters.
--- @field quality table Table containing custom quality formatters.
--- @field results table Table containing custom test results formatters.
--- @within examples.custom_formatters_example
local custom_formatters = {}

--- Table containing custom coverage formatters.
custom_formatters.coverage = {}
--- Table containing custom quality formatters (not implemented in this example).
custom_formatters.quality = {}
--- Table containing custom test result formatters.
custom_formatters.results = {}

--- Custom coverage formatter function that generates a Markdown report.
--- Assumes `coverage_data` follows the structure defined in `MockCoverageData` (see `csv_example.lua` for JSDoc).
--- @param coverage_data table The standardized coverage data structure.
--- @return string markdown The formatted Markdown report string.
custom_formatters.coverage.markdown = function(coverage_data)
  local markdown = "# Coverage Report (Custom Markdown)\n\n"
  markdown = markdown .. "## Summary\n\n"

  -- Get data from the coverage report
  local summary = coverage_data.summary
    or {
      total_files = 0,
      covered_files = 0,
      total_lines = 0,
      covered_lines = 0,
      total_functions = 0,
      covered_functions = 0,
      line_coverage_percent = 0,
      function_coverage_percent = 0,
      overall_percent = 0,
    }

  -- Add summary data
  markdown = markdown .. "- **Overall Coverage**: " .. string.format("%.2f%%", summary.overall_percent) .. "\n"
  markdown = markdown
    .. "- **Line Coverage**: "
    .. summary.covered_lines
    .. "/"
    .. summary.total_lines
    .. " ("
    .. string.format("%.2f%%", summary.line_coverage_percent)
    .. ")\n"
  markdown = markdown
    .. "- **Function Coverage**: "
    .. summary.covered_functions
    .. "/"
    .. summary.total_functions
    .. " ("
    .. string.format("%.2f%%", summary.function_coverage_percent)
    .. ")\n"
  markdown = markdown .. "- **Files**: " .. summary.covered_files .. "/" .. summary.total_files .. "\n\n"

  -- Add file table
  markdown = markdown .. "## Files\n\n"
  markdown = markdown .. "| File | Line Coverage | Function Coverage |\n"
  markdown = markdown .. "|------|--------------|-------------------|\n"

  -- Add each file
  for file, stats in pairs(coverage_data.files or {}) do
    -- Calculate percentages
    local line_pct = stats.total_lines > 0 and ((stats.covered_lines or 0) / stats.total_lines * 100) or 0
    local func_pct = stats.total_functions > 0 and ((stats.covered_functions or 0) / stats.total_functions * 100) or 0

    -- Add to table
    markdown = markdown
      .. "| `"
      .. file
      .. "` | "
      .. stats.covered_lines
      .. "/"
      .. stats.total_lines
      .. " ("
      .. string.format("%.2f%%", line_pct)
      .. ") | "
      .. stats.covered_functions
      .. "/"
      .. stats.total_functions
      .. " ("
      .. string.format("%.2f%%", func_pct)
      .. ") |\n"
  end
  -- Removed misplaced 'end' here

  -- Add timestamp
  markdown = markdown .. "\n\n*Report generated on 2025-01-01T00:00:00Z*" -- Static timestamp

  return markdown
end -- Correctly close the function body here

--- Custom test results formatter function that generates a Markdown report.
--- Assumes `results_data` follows the structure defined in `MockTestResults` (see `csv_example.lua` for JSDoc).
--- @param results_data table The standardized test results data structure.
--- @return string markdown The formatted Markdown report string.
custom_formatters.results.markdown = function(results_data)
  -- Create timestamp and summary info
  local timestamp = results_data.timestamp or os.date("!%Y-%m-%dT%H:%M:%S")
  local tests = results_data.tests or 0
  local failures = results_data.failures or 0
  local errors = results_data.errors or 0
  local skipped = results_data.skipped or 0
  local success_rate = tests > 0 and ((tests - failures - errors) / tests * 100) or 0
  local markdown = "# Test Results Report (Custom Markdown)\n\n"

  -- Add summary data
  markdown = markdown .. "## Summary\n\n"
  markdown = markdown .. "- **Test Suite**: " .. (results_data.name or "Unnamed Test Suite") .. "\n"
  markdown = markdown .. "- **Timestamp**: " .. timestamp .. "\n"
  markdown = markdown .. "- **Total Tests**: " .. tests .. "\n"
  markdown = markdown .. "- **Passed**: " .. (tests - failures - errors - skipped) .. "\n"
  markdown = markdown .. "- **Failed**: " .. failures .. "\n"
  markdown = markdown .. "- **Errors**: " .. errors .. "\n"
  markdown = markdown .. "- **Skipped**: " .. skipped .. "\n"
  markdown = markdown .. "- **Success Rate**: " .. string.format("%.2f%%", success_rate) .. "\n\n"

  -- Add test results table
  markdown = markdown .. "## Test Results\n\n"
  markdown = markdown .. "| Test | Status | Duration | Message |\n"
  markdown = markdown .. "|------|--------|----------|--------|\n"

  -- Add each test case
  for _, test_case in ipairs(results_data.test_cases or {}) do
    local name = test_case.name or "Unnamed Test"
    local status = test_case.status or "unknown"
    local duration = string.format("%.3fs", test_case.time or 0)
    local message = ""

    -- Format status with emojis
    local status_emoji
    if status == "pass" then
      status_emoji = "✅ Pass"
    elseif status == "fail" then
      status_emoji = "❌ Fail"
      message = test_case.failure and test_case.failure.message or ""
    elseif status == "error" then
      status_emoji = "⚠️ Error"
      message = test_case.error and test_case.error.message or ""
    elseif status == "skipped" or status == "pending" then
      status_emoji = "⏭️ Skip"
      message = test_case.skip_message or ""
    else
      status_emoji = "❓ " .. status
    end

    -- Sanitize message for markdown table
    message = message:gsub("|", "\\|"):gsub("\n", " ")

    -- Add to table
    markdown = markdown .. "| " .. name .. " | " .. status_emoji .. " | " .. duration .. " | " .. message .. " |\n"
  end

  -- Removed misplaced 'end' here

  -- Add timestamp
  markdown = markdown .. "\n\n*Report generated on 2025-01-01T00:00:00Z*" -- Static timestamp

  return markdown
end

-- Register our custom formatters using the reporting module API
logger.info("Registering custom 'markdown' formatters...")
local cov_success = reporting.register_coverage_formatter("markdown", custom_formatters.coverage.markdown)
local res_success = reporting.register_results_formatter("markdown", custom_formatters.results.markdown)

if not cov_success or not res_success then
  logger.error("Failed to register one or both custom formatters.")
  return -- Exit if registration fails
end

-- Verify registration by getting available formatters
local available = reporting.get_available_formatters()
logger.info("\nAvailable formatters after registration:")
-- Helper to safely concatenate formatter lists
local function format_list(list)
  return list and #list > 0 and table.concat(list, ", ") or "None"
end
logger.info("  Coverage: " .. format_list(available.coverage))
logger.info("  Quality: " .. format_list(available.quality))
logger.info("  Results: " .. format_list(available.results))

-- Create some mock test data to format
--- @type MockTestResults (See csv_example.lua for definition)
local results_data = {
  name = "Custom Formatter Example",
  timestamp = "2025-01-01T00:00:00Z", -- Static timestamp
  tests = 2,
  failures = 1,
  time = 0.002,
  test_cases = {
    {
      name = "demonstrates successful tests",
      classname = "Custom Formatter Example",
      time = 0.001,
      status = "pass",
    },
    {
      name = "demonstrates a failing test",
      classname = "Custom Formatter Example",
      time = 0.001,
      status = "fail",
      failure = {
        message = "Expected 4 to equal 5",
        type = "Assertion",
        details = "Expected 4 to equal 5",
      },
    },
  },
}

-- Create a temporary directory using the helper for automatic cleanup
local temp_dir, err = temp_file.create_temp_directory("custom_formatter_")
if not temp_dir then
  logger.error("Failed to create temp directory: " .. tostring(err))
  return -- Exit if temp dir fails
end

-- Generate a report using the custom "markdown" formatter for test results
local markdown_report, format_err = reporting.format_results(results_data, "markdown")

if not markdown_report then
  logger.error("Failed to format results using custom markdown formatter", { error = format_err })
else
  -- Save the generated report to a file in the temporary directory
  local report_path = fs.join_paths(temp_dir, "custom-test-report.md") -- Use temp_dir directly
  local success, write_err = fs.write_file(report_path, markdown_report)
  if not success then
    logger.error("Failed to write custom markdown report", { error = write_err })
  end
  -- Show output path
  if success then
    logger.info("\nGenerated custom markdown report: " .. report_path)
  end
end

logger.info("\nUsage with command line (hypothetical):")
logger.info("lua test.lua --load-formatters examples/custom_formatters_example.lua --format=markdown")

-- Clean up temporary files
temp_file.cleanup_all()

-- Return the module so we can be loaded as a formatter module (if needed)
return custom_formatters
