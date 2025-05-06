--- @module examples.reporting_filesystem_integration
--- Demonstrates the integration between firmo's reporting module
--- and the filesystem for generating coverage reports in different formats.
---
--- This example shows how to:
--- - Create and manage temporary directories for reports
--- - Generate different report formats (HTML, JSON, LCOV, Cobertura)
--- - Handle errors properly when saving reports
--- - Use central_config for configuration
---
--- @usage
--- Run all the tests in this file:
--- ```
--- lua test.lua examples/reporting_filesystem_integration.lua
--- ```
--- Run as a standalone example:
--- ```
--- lua examples/reporting_filesystem_integration.lua
--- ```
---
--- @license MIT
--- @copyright Firmo Team 2023-2025
--- @version 1.0.0

-- Import required modules for both test suite and standalone example
local firmo = require("firmo")
local reporting = require("lib.reporting")
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Test suite imports
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Utility for logging, safe to use in both test and standalone contexts
local logger = {
  info = function(message, context)
    print(string.format("[INFO] %s%s", message, context and (": " .. require("lib.tools.json").encode(context)) or ""))
  end,
  debug = function(message, context)
    if os.getenv("FIRMO_DEBUG") then
      print(
        string.format("[DEBUG] %s%s", message, context and (": " .. require("lib.tools.json").encode(context)) or "")
      )
    end
  end,
  error = function(message, context)
    print(string.format("[ERROR] %s%s", message, context and (": " .. require("lib.tools.json").encode(context)) or ""))
  end,
}

-- Helper functions used by both the test suite and standalone example

--- Create sample files with Lua code to be used in coverage reports
-- @param temp_dir The temporary directory to create files in
-- @return Table with file paths or nil, error if file creation fails
local function create_sample_files(temp_dir)
  local example_files = {}

  -- Validate input directory
  -- Validate the directory is a valid string before attempting to check if it exists
  if not temp_dir or type(temp_dir) ~= "string" or temp_dir == "" then
    return nil, { message = "Invalid temporary directory: not a string or empty" }
  end

  -- Check for invalid characters that could cause issues with path operations
  if temp_dir:match("[*?<>|]") then
    return nil, { message = "Temporary directory contains invalid characters" }
  end

  -- Check directory existence
  local dir_exists = fs.directory_exists(temp_dir)

  if not dir_exists then
    return nil, { message = "Invalid or non-existent temporary directory: " .. "unknown error" }
  end

  -- Example file with basic math functions
  local example_file_content = [[
local function add(a, b)
  return a + b
end

local function subtract(a, b)
  return a - b
end

return {
  add = add,
  subtract = subtract
}]]

  -- Another sample file with a multiplication function
  local another_file_content = [[
local function multiply(a, b)
  return a * b
end

return {
  multiply = multiply
}]]

  -- Create the files in the temp directory
  -- Create the first file
  local file1 = temp_file.create_with_content(example_file_content)

  if not file1 then
    return nil, { message = "Failed to create example_file.lua" }
  end

  example_files.example_file = file1
  test_helper.register_temp_file(file1)

  -- Verify the file exists
  if not fs.file_exists(file1) then
    return nil, { message = "Failed to verify example_file.lua exists" }
  end

  -- Create the second file
  local file2 = temp_file.create_with_content(another_file_content)

  if not file2 then
    return nil, { message = "Failed to create another_file.lua" }
  end

  example_files.another_file = file2
  test_helper.register_temp_file(file2)

  -- Verify the file exists
  if not fs.file_exists(file2) then
    return nil, { message = "Failed to verify another_file.lua exists" }
  end

  -- Verify the example_files table has both required files
  if not example_files.example_file or not example_files.another_file then
    return nil, { message = "Incomplete example_files table after creation" }
  end

  return example_files
end

--- Create a valid coverage data structure suitable for all report formats
-- @param example_files Table of file paths to include in coverage data
-- @return Coverage data structure with all required fields or nil, error if validation fails
local function create_coverage_data(example_files)
  -- Validate input
  if not example_files then
    return nil, { message = "example_files table is required" }
  end

  -- Verify required files exist
  if not example_files.example_file or not fs.file_exists(example_files.example_file) then
    return nil, { message = "example_file is missing or doesn't exist" }
  end

  if not example_files.another_file or not fs.file_exists(example_files.another_file) then
    return nil, { message = "another_file is missing or doesn't exist" }
  end

  -- Common metadata fields
  local coverage_data = {
    version = "1.0",
    timestamp = os.date("%Y-%m-%dT%H:%M:%SZ"),
    generated_by = "reporting_filesystem_integration.lua",
    project_name = "firmo_example",
    branch = "main",

    -- Summary data
    summary = {
      total_files = 2,
      covered_files = 2,
      total_lines = 16,
      executable_lines = 16,
      covered_lines = 12,
      line_coverage_percent = 75.0, -- (12/16)*100
      function_coverage_percent = 75.0, -- (3/4)*100
      total_functions = 4,
      covered_functions = 3,
    },

    -- File data will be populated for each format
    files = {},
  }

  -- Add file data for the first example file with safe indexing
  if example_files.example_file then
    coverage_data.files[example_files.example_file] = {
      name = fs.get_file_name(example_files.example_file),
      path = example_files.example_file,
      total_lines = 10,
      executable_lines = 10,
      covered_lines = 6,
      line_coverage_percent = 60.0, -- (6/10)*100
      function_coverage_percent = 50.0, -- (1/2)*100
      total_functions = 2,
      covered_functions = 1,
      lines = {
        { number = 1, hits = 10, execution_count = 10, covered = true, line = "local function add(a, b)" },
        { number = 2, hits = 10, execution_count = 10, covered = true, line = "  return a + b" },
        { number = 3, hits = 10, execution_count = 10, covered = true, line = "end" },
        { number = 4, hits = 0, execution_count = 0, covered = false, line = "local function subtract(a, b)" },
        { number = 5, hits = 0, execution_count = 0, covered = false, line = "  return a - b" },
        { number = 6, hits = 0, execution_count = 0, covered = false, line = "end" },
        { number = 7, hits = 5, execution_count = 5, covered = true, line = "return {" },
        { number = 8, hits = 5, execution_count = 5, covered = true, line = "  add = add," },
        { number = 9, hits = 0, execution_count = 0, covered = false, line = "  subtract = subtract" },
        { number = 10, hits = 5, execution_count = 5, covered = true, line = "}" },
      },
      functions = {
        { name = "add", line = 1, hits = 10, execution_count = 10, covered = true },
        { name = "subtract", line = 4, hits = 0, execution_count = 0, covered = false },
      },
    }
  end

  -- Add file data for the second example file with safe indexing
  if example_files.another_file then
    coverage_data.files[example_files.another_file] = {
      name = fs.get_file_name(example_files.another_file),
      path = example_files.another_file,
      total_lines = 6,
      executable_lines = 6,
      covered_lines = 6,
      line_coverage_percent = 100.0, -- (6/6)*100
      function_coverage_percent = 100.0, -- (1/1)*100
      total_functions = 1,
      covered_functions = 1,
      lines = {
        { number = 1, hits = 8, execution_count = 8, covered = true, line = "local function multiply(a, b)" },
        { number = 2, hits = 8, execution_count = 8, covered = true, line = "  return a * b" },
        { number = 3, hits = 8, execution_count = 8, covered = true, line = "end" },
        { number = 4, hits = 8, execution_count = 8, covered = true, line = "return {" },
        { number = 5, hits = 8, execution_count = 8, covered = true, line = "  multiply = multiply" },
        { number = 6, hits = 8, execution_count = 8, covered = true, line = "}" },
      },
      functions = {
        { name = "multiply", line = 1, hits = 8, execution_count = 8, covered = true },
      },
    }
  end

  -- Validate that coverage data has required files
  if example_files.example_file and not coverage_data.files[example_files.example_file] then
    return nil, { message = "Failed to set up coverage data for example_file" }
  end

  if example_files.another_file and not coverage_data.files[example_files.another_file] then
    return nil, { message = "Failed to set up coverage data for another_file" }
  end

  -- Ensure files count matches actual file count
  local file_count = 0
  for _, _ in pairs(coverage_data.files) do
    file_count = file_count + 1
  end

  -- Update summary values if needed to match actual file count
  if file_count ~= coverage_data.summary.total_files then
    coverage_data.summary.total_files = file_count
    coverage_data.summary.covered_files = file_count -- Assume all files are covered
  end

  return coverage_data
end

----------------------------------------
-- PART 1: TEST SUITE
----------------------------------------

-- Main test suite for filesystem integration with reporting
describe("Reporting Filesystem Integration", function()
  -- Setup variables accessible within the test suite
  local temp_dir
  local example_files = {}
  local coverage_data

  -- Setup function to create temp directory and test files before tests
  before(function()
    -- First, create a temporary test directory for our files
    local dir_result = test_helper.create_temp_test_directory("reporting_test_")

    -- Validate the directory creation was successful
    expect(success).to.be_truthy("Directory creation should succeed")
    expect(dir_result).to.exist("Temporary directory object should be returned")
    expect(dir_result.path).to.exist("TestDirectory should have a path property")
    expect(dir_result.path).to.be.a("string", "Directory path should be a string")
    expect(dir_result.path).to_not.equal("", "Directory path cannot be empty")

    -- Store path in outer scope variable after validation
    temp_dir = dir_result.path

    -- Check for invalid characters in path before calling directory_exists
    expect(not temp_dir:match("[*?<>|]"), "Directory path should not contain invalid characters").to.be_truthy()

    -- Verify the directory exists on the filesystem
    local dir_exists, exists_err = test_helper.with_error_capture(function()
      return fs.directory_exists(temp_dir)
    end)

    expect(exists_err).to_not.exist("No errors should occur when checking if directory exists")
    expect(dir_exists).to.be_truthy("Temporary directory should exist on filesystem")

    -- Secondary verification that directory exists before proceeding
    expect(fs.directory_exists(temp_dir)).to.be_truthy("Temporary directory should exist on filesystem")

    -- Only proceed with file creation if temp directory exists
    if fs.directory_exists(temp_dir) then
      -- Create example files with content to use in coverage reports
      local files_result = create_sample_files(temp_dir)

      expect(files_result).to.be.a("table")
      example_files = files_result

      -- Verify files were created with specific error messages
      expect(example_files.example_file).to.exist("example_file path should exist in the example_files table")
      expect(example_files.another_file).to.exist("another_file path should exist in the example_files table")
      expect(fs.file_exists(example_files.example_file)).to.be_truthy("Example file should exist on filesystem")
      expect(fs.file_exists(example_files.another_file)).to.be_truthy("Another file should exist on filesystem")

      -- Only create coverage data if sample files exist
      if fs.file_exists(example_files.example_file) and fs.file_exists(example_files.another_file) then
        -- Create coverage data structure with explicit verification
        local coverage_result = create_coverage_data(example_files)

        expect(coverage_result).to.be.a("table")
        coverage_data = coverage_result

        -- Verify coverage data structure is properly formed
        expect(coverage_data.files).to.be.a("table")
        expect(coverage_data.files[example_files.example_file]).to.exist("Coverage data should include example_file")
        expect(coverage_data.files[example_files.another_file]).to.exist("Coverage data should include another_file")
      end
    end
  end)

  -- Teardown function - test_helper will clean up registered temp files
  after(function()
    -- Resources are automatically cleaned up
  end)

  -- Tests for generating coverage reports with filesystem integration
  describe("Coverage Report Generation", function()
    -- Test HTML report generation
    it("should generate an HTML coverage report", function()
      -- Populate the files data structure for HTML report format
      coverage_data.files = {
        [example_files.example_file] = {
          name = fs.get_file_name(example_files.example_file),
          path = example_files.example_file,
          line_coverage_percent = 83.3,
          function_coverage_percent = 100.0,
          total_lines = 9,
          covered_lines = 5,
          executable_lines = 6,
          total_functions = 2,
          executed_functions = 2,
          lines = {
            [1] = { executable = true, execution_count = 1, covered = true, content = "local function add(a, b)" },
            [2] = { executable = true, execution_count = 3, covered = true, content = "  return a + b" },
            [3] = { executable = true, execution_count = 1, covered = true, content = "end" },
            [4] = { executable = true, execution_count = 1, covered = true, content = "local function subtract(a, b)" },
            [5] = { executable = true, execution_count = 2, covered = true, content = "  return a - b" },
            [6] = { executable = true, execution_count = 1, covered = true, content = "end" },
            [7] = { executable = false, execution_count = 0, covered = false, content = "return {" },
            [8] = { executable = false, execution_count = 0, covered = false, content = "  add = add," },
            [9] = { executable = false, execution_count = 0, covered = false, content = "  subtract = subtract" },
          },
          functions = {
            { name = "add", start_line = 1, end_line = 3, executed = true, execution_count = 3 },
            { name = "subtract", start_line = 4, end_line = 6, executed = true, execution_count = 2 },
          },
        },
        [example_files.another_file] = {
          name = fs.get_file_name(example_files.another_file),
          path = example_files.another_file,
          line_coverage_percent = 66.7,
          function_coverage_percent = 50.0,
          total_lines = 7,
          covered_lines = 4,
          executable_lines = 6,
          total_functions = 2,
          executed_functions = 1,
          lines = {
            [1] = { executable = true, execution_count = 1, covered = true, content = "local function multiply(a, b)" },
            [2] = { executable = true, execution_count = 4, covered = true, content = "  return a * b" },
            [3] = { executable = true, execution_count = 1, covered = true, content = "end" },
            [4] = { executable = false, execution_count = 0, covered = false, content = "return {" },
            [5] = { executable = false, execution_count = 0, covered = false, content = "  multiply = multiply" },
            [6] = { executable = false, execution_count = 0, covered = false, content = "}" },
          },
          functions = {
            { name = "multiply", start_line = 1, end_line = 3, executed = true, execution_count = 4 },
          },
        },
      }

      -- Create a specific temp directory for HTML output with validation
      -- create_temp_test_directory returns a TestDirectory object with a .path property
      -- Create the directory with robust validation and error handling
      local html_dir_result = test_helper.create_temp_test_directory("html_report_")

      expect(html_dir_result).to.exist("Temporary directory object should be returned")
      expect(html_dir_result.path).to.exist("TestDirectory should have a path property")
      expect(html_dir_result.path).to.be.a("string", "Directory path should be a string")
      expect(html_dir_result.path).to_not.equal("", "Directory path cannot be empty")
      local html_dir = html_dir_result.path

      -- Ensure path is valid before checking if it exists
      expect(type(html_dir)).to.equal("string", "HTML directory path must be a string")
      expect(html_dir).to_not.equal("", "HTML directory path cannot be empty")

      -- Additional validation to ensure no invalid characters in path
      expect(not html_dir:match("[*?<>|]"), "Directory path should not contain invalid characters").to.be_truthy()
      logger.debug("Created HTML output directory", { path = html_dir })

      -- Verify directory exists before proceeding with safe error handling
      local dir_exists, dir_err = test_helper.with_error_capture(function()
        return fs.directory_exists(html_dir)
      end)

      expect(dir_err).to_not.exist("No errors should occur when checking if HTML directory exists")
      expect(dir_exists).to.be_truthy("HTML output directory should exist on filesystem")

      local output_path = fs.join_paths(html_dir, "coverage-report.html")
      test_helper.register_temp_file(output_path)

      -- Generate HTML report with proper error handling
      local success, err = error_handler.safe_io_operation(function()
        logger.debug("Formatting HTML coverage report")
        return reporting.format_coverage(coverage_data, "html")
      end)

      expect(err).to_not.exist("Formatting HTML coverage report should succeed")
      expect(success).to.be.a("string", "HTML formatter should return content as a string")

      -- Save the HTML report with path validation
      expect(output_path).to.be.a("string", "Output path should be a string")
      expect(output_path).to_not.match("[*?<>|]", "Output path should not contain invalid characters")

      local write_success, write_err = error_handler.safe_io_operation(function()
        logger.debug("Writing HTML report to file", { path = output_path })
        return fs.write_file(output_path, success)
      end)

      expect(write_err).to_not.exist("Writing HTML report should succeed")
      expect(write_success).to.be_truthy("HTML report should be written successfully")

      -- Verify the report exists
      expect(fs.file_exists(output_path)).to.be_truthy("HTML report file should exist")

      logger.info("HTML report saved successfully", { path = output_path })
    end)

    -- Test JSON report generation
    it("should generate a JSON coverage report", function()
      -- Populate the files data structure for JSON report format
      coverage_data.files = {
        [example_files.example_file] = {
          name = fs.get_file_name(example_files.example_file),
          path = example_files.example_file,
          line_coverage_percent = 83.3,
          function_coverage_percent = 100.0,
          total_lines = 9,
          covered_lines = 5,
          executable_lines = 6,
          total_functions = 2,
          executed_functions = 2,
          lines = {
            ["1"] = { executable = true, execution_count = 1, covered = true },
            ["2"] = { executable = true, execution_count = 3, covered = true },
            ["3"] = { executable = true, execution_count = 1, covered = true },
            ["4"] = { executable = true, execution_count = 1, covered = true },
            ["5"] = { executable = true, execution_count = 2, covered = true },
            ["6"] = { executable = true, execution_count = 1, covered = true },
            ["7"] = { executable = false, execution_count = 0, covered = false },
            ["8"] = { executable = false, execution_count = 0, covered = false },
            ["9"] = { executable = false, execution_count = 0, covered = false },
          },
          functions = {
            { name = "add", start_line = 1, end_line = 3, executed = true, execution_count = 3 },
            { name = "subtract", start_line = 4, end_line = 6, executed = true, execution_count = 2 },
          },
        },
        [example_files.another_file] = {
          name = fs.get_file_name(example_files.another_file),
          path = example_files.another_file,
          line_coverage_percent = 66.7,
          function_coverage_percent = 50.0,
          total_lines = 7,
          covered_lines = 4,
          executable_lines = 6,
          total_functions = 2,
          executed_functions = 1,
          lines = {
            ["1"] = { executable = true, execution_count = 1, covered = true },
            ["2"] = { executable = true, execution_count = 4, covered = true },
            ["3"] = { executable = true, execution_count = 1, covered = true },
            ["4"] = { executable = false, execution_count = 0, covered = false },
            ["5"] = { executable = false, execution_count = 0, covered = false },
            ["6"] = { executable = false, execution_count = 0, covered = false },
          },
          functions = {
            { name = "multiply", start_line = 1, end_line = 3, executed = true, execution_count = 4 },
          },
        },
      }

      -- Create a specific temp directory for JSON output with validation
      -- TestDirectory object has a .path property that should be accessed
      -- Create the directory with robust validation and error handling
      local json_dir_result = test_helper.create_temp_test_directory("json_report_")

      expect(json_dir_result).to.exist("Temporary directory object should be returned")
      expect(json_dir_result.path).to.exist("TestDirectory should have a path property")
      expect(json_dir_result.path).to.be.a("string", "Directory path should be a string")
      expect(json_dir_result.path).to_not.equal("", "Directory path cannot be empty")
      local json_dir = json_dir_result.path

      -- Ensure path is valid before checking if it exists
      expect(type(json_dir)).to.equal("string", "JSON directory path must be a string")
      expect(json_dir).to_not.equal("", "JSON directory path cannot be empty")

      -- Additional validation to ensure no invalid characters in path
      expect(not json_dir:match("[*?<>|]"), "Directory path should not contain invalid characters").to.be_truthy()
      logger.debug("Created JSON output directory", { path = json_dir })

      -- Verify directory exists before proceeding with safe error handling
      local dir_exists, dir_err = test_helper.with_error_capture(function()
        return fs.directory_exists(json_dir)
      end)

      expect(dir_err).to_not.exist("No errors should occur when checking if JSON directory exists")
      expect(dir_exists).to.be_truthy("JSON output directory should exist on filesystem")

      local output_path = fs.join_paths(json_dir, "coverage.json")
      test_helper.register_temp_file(output_path)

      -- Generate JSON report with proper error handling
      local success, err = error_handler.safe_io_operation(function()
        logger.debug("Formatting JSON coverage report")
        return reporting.format_coverage(coverage_data, "json")
      end)

      expect(err).to_not.exist("Formatting JSON coverage report should succeed")
      expect(success).to.be.a("string", "JSON formatter should return content as a string")

      -- Save the JSON report with path validation
      expect(output_path).to.be.a("string", "Output path should be a string")
      expect(output_path).to_not.match("[*?<>|]", "Output path should not contain invalid characters")

      local write_success, write_err = error_handler.safe_io_operation(function()
        logger.debug("Writing JSON report to file", { path = output_path })
        return fs.write_file(output_path, success)
      end)

      expect(write_err).to_not.exist("Writing JSON report should succeed")
      expect(write_success).to.be_truthy("JSON report should be written successfully")

      -- Verify the report exists
      expect(fs.file_exists(output_path)).to.be_truthy("JSON report file should exist")

      logger.info("JSON report saved successfully", { path = output_path })
    end)

    -- Test LCOV report generation
    it("should generate an LCOV coverage report", function()
      -- Populate the files data structure for LCOV report format
      coverage_data.files = {
        [example_files.example_file] = {
          name = fs.get_file_name(example_files.example_file),
          path = example_files.example_file,
          line_coverage_percent = 83.3,
          function_coverage_percent = 100.0,
          covered_lines = 5,
          executable_lines = 6,
          total_lines = 9,
          total_functions = 2,
          covered_functions = 2,
          lines = {
            ["1"] = { hits = 1, covered = true },
            ["2"] = { hits = 3, covered = true },
            ["3"] = { hits = 1, covered = true },
            ["4"] = { hits = 1, covered = true },
            ["5"] = { hits = 2, covered = true },
            ["6"] = { hits = 1, covered = true },
            ["7"] = { hits = 0, covered = false },
            ["8"] = { hits = 0, covered = false },
            ["9"] = { hits = 0, covered = false },
          },
          functions = {
            { name = "add", line = 1, hits = 3 },
            { name = "subtract", line = 4, hits = 2 },
          },
        },
        [example_files.another_file] = {
          name = fs.get_file_name(example_files.another_file),
          path = example_files.another_file,
          line_coverage_percent = 66.7,
          function_coverage_percent = 100.0,
          covered_lines = 3,
          executable_lines = 6,
          total_lines = 6,
          total_functions = 1,
          covered_functions = 1,
          lines = {
            ["1"] = { hits = 4, covered = true },
            ["2"] = { hits = 4, covered = true },
            ["3"] = { hits = 4, covered = true },
            ["4"] = { hits = 0, covered = false },
            ["5"] = { hits = 0, covered = false },
            ["6"] = { hits = 0, covered = false },
          },
          functions = {
            { name = "multiply", line = 1, hits = 4 },
          },
        },
      }

      -- Create a specific temp directory for LCOV output with validation
      -- TestDirectory object has a .path property that should be accessed
      -- Create the directory with robust validation and error handling
      local lcov_dir_result = test_helper.create_temp_test_directory("lcov_report_")

      expect(lcov_dir_result).to.exist("Temporary directory object should be returned")
      expect(lcov_dir_result.path).to.exist("TestDirectory should have a path property")
      expect(lcov_dir_result.path).to.be.a("string", "Directory path should be a string")
      expect(lcov_dir_result.path).to_not.equal("", "Directory path cannot be empty")
      local lcov_dir = lcov_dir_result.path

      -- Ensure path is valid before checking if it exists
      expect(type(lcov_dir)).to.equal("string", "LCOV directory path must be a string")
      expect(lcov_dir).to_not.equal("", "LCOV directory path cannot be empty")

      -- Additional validation to ensure no invalid characters in path
      expect(not lcov_dir:match("[*?<>|]"), "Directory path should not contain invalid characters").to.be_truthy()
      logger.debug("Created LCOV output directory", { path = lcov_dir })

      -- Verify directory exists before proceeding with safe error handling
      local dir_exists, dir_err = test_helper.with_error_capture(function()
        return fs.directory_exists(lcov_dir)
      end)

      expect(dir_err).to_not.exist("No errors should occur when checking if LCOV directory exists")
      expect(dir_exists).to.be_truthy("LCOV output directory should exist on filesystem")

      local output_path = fs.join_paths(lcov_dir, "lcov.info")
      test_helper.register_temp_file(output_path)

      -- Generate LCOV report with proper error handling
      local success, err = error_handler.safe_io_operation(function()
        logger.debug("Formatting LCOV coverage report")
        return reporting.format_coverage(coverage_data, "lcov")
      end)

      expect(err).to_not.exist("Formatting LCOV coverage report should succeed")
      expect(success).to.be.a("string", "LCOV formatter should return content as a string")

      -- Save the LCOV report with path validation
      expect(output_path).to.be.a("string", "Output path should be a string")
      expect(output_path).to_not.match("[*?<>|]", "Output path should not contain invalid characters")

      local write_success, write_err = error_handler.safe_io_operation(function()
        logger.debug("Writing LCOV report to file", { path = output_path })
        return fs.write_file(output_path, success)
      end)

      expect(write_err).to_not.exist("Writing LCOV report should succeed")
      expect(write_success).to.be_truthy("LCOV report should be written successfully")

      -- Verify the report exists
      expect(fs.file_exists(output_path)).to.be_truthy("LCOV report file should exist")

      logger.info("LCOV report saved successfully", { path = output_path })
    end)

    -- Test Cobertura report generation
    it("should generate a Cobertura coverage report", function()
      -- Populate the files data structure for Cobertura report format
      coverage_data.files = {
        [example_files.example_file] = {
          name = fs.get_file_name(example_files.example_file),
          path = example_files.example_file,
          line_coverage_percent = 83.3,
          function_coverage_percent = 100.0,
          covered_lines = 5,
          executable_lines = 6,
          total_lines = 9,
          total_functions = 2,
          covered_functions = 2,
          lines = {
            [1] = { number = 1, hits = 1, covered = true },
            [2] = { number = 2, hits = 3, covered = true },
            [3] = { number = 3, hits = 1, covered = true },
            [4] = { number = 4, hits = 1, covered = true },
            [5] = { number = 5, hits = 2, covered = true },
            [6] = { number = 6, hits = 1, covered = true },
            [7] = { number = 7, hits = 0, covered = false },
            [8] = { number = 8, hits = 0, covered = false },
            [9] = { number = 9, hits = 0, covered = false },
          },
          functions = {
            ["add"] = {
              name = "add",
              start_line = 1,
              end_line = 3,
              executed = true,
              execution_count = 3,
            },
            ["subtract"] = {
              name = "subtract",
              start_line = 4,
              end_line = 6,
              executed = true,
              execution_count = 2,
            },
          },
          -- Keep metadata about class for reference but it's not used by the formatter
          _class_info = {
            lines_valid = 9,
            lines_covered = 6,
            line_rate = 0.667,
          },
        },
        [example_files.another_file] = {
          name = fs.get_file_name(example_files.another_file),
          path = example_files.another_file,
          line_coverage_percent = 66.7,
          function_coverage_percent = 100.0,
          covered_lines = 3,
          executable_lines = 6,
          total_lines = 6,
          total_functions = 1,
          covered_functions = 1,
          lines = {
            [1] = { number = 1, hits = 4, covered = true },
            [2] = { number = 2, hits = 4, covered = true },
            [3] = { number = 3, hits = 4, covered = true },
            [4] = { number = 4, hits = 0, covered = false },
            [5] = { number = 5, hits = 0, covered = false },
            [6] = { number = 6, hits = 0, covered = false },
          },
          functions = {
            ["multiply"] = {
              name = "multiply",
              start_line = 1,
              end_line = 3,
              executed = true,
              execution_count = 4,
            },
          },
          -- Keep metadata about class for reference but it's not used by the formatter
          _class_info = {
            lines_valid = 6,
            lines_covered = 3,
            line_rate = 0.50,
          },
        },
      }

      -- Create a specific temp directory for Cobertura output with validation
      -- TestDirectory object has a .path property that should be accessed
      -- Create the directory with robust validation and error handling
      local cobertura_dir_result = test_helper.create_temp_test_directory("cobertura_report_")

      expect(cobertura_dir_result).to.exist("Temporary directory object should be returned")
      expect(cobertura_dir_result.path).to.exist("TestDirectory should have a path property")
      expect(cobertura_dir_result.path).to.be.a("string", "Directory path should be a string")
      expect(cobertura_dir_result.path).to_not.equal("", "Directory path cannot be empty")
      local cobertura_dir = cobertura_dir_result.path

      -- Ensure path is valid before checking if it exists
      expect(type(cobertura_dir)).to.equal("string", "Cobertura directory path must be a string")
      expect(cobertura_dir).to_not.equal("", "Cobertura directory path cannot be empty")

      -- Additional validation to ensure no invalid characters in path
      expect(not cobertura_dir:match("[*?<>|]"), "Directory path should not contain invalid characters").to.be_truthy()
      logger.debug("Created Cobertura output directory", { path = cobertura_dir })

      -- Verify directory exists before proceeding with safe error handling
      local dir_exists, dir_err = test_helper.with_error_capture(function()
        return fs.directory_exists(cobertura_dir)
      end)

      expect(dir_err).to_not.exist("No errors should occur when checking if Cobertura directory exists")
      expect(dir_exists).to.be_truthy("Cobertura output directory should exist on filesystem")

      local output_path = fs.join_paths(cobertura_dir, "cobertura.xml")
      test_helper.register_temp_file(output_path)

      -- Generate Cobertura report with proper error handling
      local success, err = error_handler.safe_io_operation(function()
        logger.debug("Formatting Cobertura coverage report")
        return reporting.format_coverage(coverage_data, "cobertura")
      end)

      expect(err).to_not.exist("Formatting Cobertura coverage report should succeed")
      expect(success).to.be.a("string", "Cobertura formatter should return content as a string")

      -- Save the Cobertura report with path validation
      expect(output_path).to.be.a("string", "Output path should be a string")
      expect(output_path).to_not.match("[*?<>|]", "Output path should not contain invalid characters")

      local write_success, write_err = error_handler.safe_io_operation(function()
        logger.debug("Writing Cobertura report to file", { path = output_path })
        return fs.write_file(output_path, success)
      end)

      expect(write_err).to_not.exist("Writing Cobertura report should succeed")
      expect(write_success).to.be_truthy("Cobertura report should be written successfully")

      -- Verify the report exists
      expect(fs.file_exists(output_path)).to.be_truthy("Cobertura report file should exist")

      logger.info("Cobertura report saved successfully", { path = output_path })
    end)
  end)
end)
