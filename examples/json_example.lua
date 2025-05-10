--- This file demonstrates two primary aspects related to JSON in Firmo:
---
-- 1.  **JSON Coverage Report Formatter:** It shows how to generate JSON format
--     coverage reports using `reporting.format_coverage`, configure options like
--     pretty printing via `central_config`, and save the output using `test_helper`
--     for temporary files.
-- 2.  **Core JSON Module:** It demonstrates the direct usage of the `lib.tools.json`
--     module for encoding Lua tables to JSON strings (`json.encode`) and decoding
--     JSON strings back into Lua tables (`json.decode`), including file I/O and
--     error handling.
--
-- @module examples.json_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see lib.reporting.formatters.json
-- @see lib.tools.json
-- @usage
-- Run embedded tests (Part 1): lua firmo.lua examples/json_example.lua
-- Run procedural example (Part 2): lua examples/json_example.lua
--

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
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after
local logging = require("lib.tools.logging")
local test_helper = require("lib.tools.test_helper")
local json = require("lib.tools.json") -- Added for Part 2

-- Setup logger
local logger = logging.get_logger("JSONExample")

-- Create mock coverage data (consistent with other examples, using execution_count)
--- Mock coverage data structure for demonstration.
--- @class MockCoverageData
--- @field files table<string, FileCoverageData> Coverage data per file.
--- @field summary CoverageSummaryData Overall summary statistics.
--- @within examples.json_example

--- @class FileCoverageData
--- @field lines table<number, { execution_count: number }> Line coverage data (keys are line numbers).
--- @field functions table<string, FunctionCoverageData> Function coverage data.
--- @field total_lines number Total lines in the file.
--- @field executable_lines number Total executable lines.
--- @field covered_lines number Total covered executable lines.
--- @field total_functions number Total functions defined.
--- @field covered_functions number Total covered functions.
--- @field line_coverage_percent number Percentage of lines covered.
--- @field function_coverage_percent number Percentage of functions covered.
--- @field line_rate number Line coverage rate (0.0 to 1.0).
--- @field filename string Path to the file.
--- @within examples.json_example

--- @class FunctionCoverageData
--- @field name string Function name.
--- @field execution_count number How many times the function was entered.
--- @within examples.json_example

--- @class CoverageSummaryData
--- @field total_files number Total files processed.
--- @field covered_files number Files with > 0% coverage.
--- @field total_lines number Total lines across all files.
--- @field executable_lines number Total executable lines.
--- @field covered_lines number Total covered executable lines.
--- @field total_functions number Total functions.
--- @field covered_functions number Total covered functions.
--- @field line_coverage_percent number Overall line coverage percentage.
--- @field function_coverage_percent number Overall function coverage percentage.
--- @field overall_percent number Overall coverage percentage.
--- @within examples.json_example

local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = { executable = true, execution_count = 1 },
        [2] = { executable = true, execution_count = 1 },
        [3] = { executable = true, execution_count = 1 },
        [5] = { executable = true, execution_count = 0 },
        [6] = { executable = true, execution_count = 1 },
        [8] = { executable = true, execution_count = 0 },
        [9] = { executable = true, execution_count = 0 },
      },
      functions = {
        ["add"] = { name = "add", execution_count = 1 },
        ["subtract"] = { name = "subtract", execution_count = 1 },
        ["multiply"] = { name = "multiply", execution_count = 0 },
        ["divide"] = { name = "divide", execution_count = 0 },
      },
      total_lines = 10,
      executable_lines = 7, -- Based on lines table
      covered_lines = 4, -- Based on execution_count > 0
      total_functions = 4,
      covered_functions = 2, -- Based on execution_count > 0
      line_coverage_percent = (4 / 7) * 100,
      function_coverage_percent = (2 / 4) * 100,
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = { executable = true, execution_count = 1 },
        [2] = { executable = true, execution_count = 1 },
        [4] = { executable = true, execution_count = 1 },
        [5] = { executable = true, execution_count = 1 },
        [7] = { executable = true, execution_count = 0 },
      },
      functions = {
        ["validate"] = { name = "validate", execution_count = 1 },
        ["format"] = { name = "format", execution_count = 0 },
      },
      total_lines = 8,
      executable_lines = 5, -- Based on lines table
      covered_lines = 4, -- Based on execution_count > 0
      total_functions = 2,
      covered_functions = 1, -- Based on execution_count > 0
      line_coverage_percent = (4 / 5) * 100,
      function_coverage_percent = (1 / 2) * 100,
    },
  },
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 18,
    executable_lines = 12, -- 7 + 5
    covered_lines = 8, -- 4 + 4
    total_functions = 6, -- 4 + 2
    covered_functions = 3, -- 2 + 1
    line_coverage_percent = (8 / 12) * 100, -- ~66.7%
    function_coverage_percent = (3 / 6) * 100, -- 50.0%
    overall_percent = (8 / 12) * 100, -- Based on lines
  },
}

-- ============================================================
-- PART 1: JSON Coverage Formatter Example (using Firmo tests)
-- ============================================================
local temp_dir = test_helper.create_temp_test_directory()

--- Test suite demonstrating the JSON coverage report formatter.
--- @within examples.json_example
describe("JSON Coverage Formatter Example", function()
  --- Tests generating a basic JSON coverage report with default settings.
  it("generates basic JSON coverage report with defaults", function()
    -- Reset config to ensure defaults
    central_config.reset("reporting.formatters.json")

    -- Generate JSON report
    logger.info("Generating basic JSON coverage report...")
    local json_report, format_err = reporting.format_coverage(mock_coverage_data, "json")

    -- Validate the report
    expect(format_err).to_not.exist("Formatting should succeed")
    expect(json_report).to.exist()
    expect(json_report).to.be.a("string")
    expect(json_report).to.match('"overall_percent":')

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-report.json")
    local success, err_str = fs.write_file(file_path, json_report)

    -- Check if write was successful
    expect(err_str).to_not.exist("Writing JSON report should succeed")
    expect(success).to.be_truthy()

    logger.info("Basic JSON report saved to: " .. file_path)
    logger.info("Report size: " .. #json_report .. " bytes")

    -- Preview a sample of the JSON output
    logger.info("\nJSON Preview (first 300 characters):")
    print(json_report:sub(1, 300) .. "...\n")
  end)

  --- Tests configuring the JSON formatter (pretty print, indent, source inclusion).
  it("demonstrates JSON formatter configuration options", function()
    -- Configure JSON formatter options via central_config
    central_config.set("reporting.formatters.json", {
      pretty = true, -- Enable pretty printing (formatted JSON)
      indent = 2, -- Number of spaces for indentation
      include_source = false, -- Don't include source code in the report
      include_functions = true, -- Include function coverage details
    })

    -- Generate the report with configuration
    logger.info("Generating configured JSON coverage report...")
    local json_report, format_err = reporting.format_coverage(mock_coverage_data, "json")

    -- Validate the report
    expect(format_err).to_not.exist("Formatting should succeed")
    expect(json_report).to.exist()
    expect(json_report).to.match("\n  ") -- Should have indentation due to pretty=true

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-report-pretty.json")
    local success, err_str = fs.write_file(file_path, json_report)

    -- Check if write was successful
    expect(err_str).to_not.exist("Writing pretty JSON report should succeed")
    expect(success).to.be_truthy()

    logger.info("Pretty-printed JSON report saved to: " .. file_path)
    logger.info("Report size: " .. #json_report .. " bytes")

    -- Preview a sample of the pretty-printed JSON output
    logger.info("\nPretty JSON Preview (first 300 characters):")
    print(json_report:sub(1, 300) .. "...\n")
  end)

  --- Informational test discussing potential use cases for the generated JSON data.
  it("discusses parsing and using the JSON data", { expect_error = true }, function()
    -- First verify our mock data structure
    expect(mock_coverage_data.files).to.exist("Mock data should have files")
    expect(mock_coverage_data.summary).to.exist("Mock data should have summary")
    
    -- Format the data with verbose output
    logger.info("Mock coverage data sample:", json.encode(mock_coverage_data, { pretty = true }))

    -- Generate JSON report with error handling
    local json_report = reporting.format_coverage(mock_coverage_data, "json")
    expect(json_report).to.exist()
    
    -- Capture and check that the decode succeeds
    local result, err = test_helper.with_error_capture(function()
      return json.decode(json_report)
    end)()

    -- Verify we got valid data back
    expect(err).to_not.exist("JSON decode should succeed")
    expect(result).to.be.a("table")
    expect(result.files).to.exist("Decoded data should have files")
    expect(result.summary).to.exist("Decoded data should have summary")
    
    -- If we got here, the test is passing - log some helpful info about the data
    logger.info("Successfully decoded JSON report")
    logger.info("Report contains data for " .. result.summary.total_files .. " files")
    logger.info("Overall coverage: " .. result.summary.line_coverage_percent .. "%")
    -- Show how to use the data in practical applications
    logger.info("\nExample uses of JSON coverage data:")
    logger.info("1. Generate custom reports or visualizations")
    logger.info("2. Integrate with CI/CD pipelines")
    logger.info("3. Store in databases for historical tracking")
    logger.info("4. Calculate delta coverage between runs")
    
    -- Verify specific values from the JSON structure
    expect(result.metadata.tool).to.equal("Firmo Coverage")
    expect(result.metadata.format).to.equal("json")
    
    -- List the files found in the report
    logger.info("\nFiles in coverage report:")
    for file_path, file_data in pairs(result.files) do
      logger.info("  - " .. file_path .. ": " .. file_data.line_coverage_percent .. "% covered")
    end

    logger.info("Successfully decoded the generated JSON report back into a Lua table.")

    -- Example of how you might use the JSON data
    logger.info("\nExample use cases for JSON coverage data:")
    logger.info("1. Store in a database for historical tracking")
    logger.info("2. Create custom visualizations or dashboards")
    logger.info("3. Integration with third-party tools via API")
    logger.info("4. Generate delta reports to track coverage improvements")
  end)
end)

-- ======================================================
-- PART 2: Direct JSON Module Usage (procedural example)
-- ======================================================

logger.info("\n=== JSON Module Example ===")
logger.info("This section demonstrates direct usage of the lib.tools.json module.")

-- JSON module example
-- Removed duplicate test_helper/logging imports

--- Demonstrates basic encoding of a Lua table to a JSON string using `json.encode()`
-- and decoding it back using `json.decode()`.
--- @within examples.json_example
print("\nExample 1: Basic Encoding/Decoding")

--- Demonstrates basic encoding of a Lua table to a JSON string using `json.encode()`
-- and decoding it back using `json.decode()`.
--- @within examples.json_example

local data = {
  name = "test",
  values = { 1, 2, 3 },
  enabled = true,
}

local json_str = json.encode(data)
print("Original data:", json.encode(data, { pretty = true })) -- Use JSON encode for better display
print("JSON string:", json_str)

local decoded_ok, decoded = pcall(json.decode, json_str)
print("Decoded data:", decoded_ok and json.encode(decoded, { pretty = true }) or "DECODE FAILED")

--- Demonstrates encoding a Lua table to JSON, writing it to a file using `fs.write_file`,
-- reading the file back using `fs.read_file`, and decoding the JSON string using `json.decode`.
--- @within examples.json_example
print("\nExample 2: Working with Files")
print("--------------------------")

-- Use the temp directory created by the test runner helper
local json_file_path = fs.join_paths(temp_dir.path, "config.json")

-- Create a configuration object
local config = {
  server = {
    host = "localhost",
    port = 8080,
  },
  database = {
    url = "postgres://localhost/test",
    pool = {
      min = 1,
      max = 10,
    },
  },
  features = {
    logging = true,
    metrics = false,
  },
}

-- Save to file
-- Save to file using fs.write_file
print("Saving configuration to file:", json_file_path)
-- Encode with pretty printing for readability in the file
local write_ok, write_err_str = fs.write_file(json_file_path, json.encode(config, { pretty = true }))
if not write_ok then
  error("Failed to write JSON file: " .. (write_err_str or "unknown error"))
end

-- Read from file using fs.read_file
print("Reading configuration from file...")
local content, read_err_str = fs.read_file(json_file_path)
if not content then
  error("Failed to read JSON file: " .. (read_err_str or "unknown error"))
end
local loaded_config, decode_err = json.decode(content)
if not loaded_config then
  error("Failed to decode JSON from file: " .. decode_err)
end

print("Loaded config:", json.encode(loaded_config, { pretty = true }))

--- Demonstrates error handling for invalid encoding (e.g., functions) using `pcall`
-- and invalid decoding (malformed JSON string) also using `pcall`.
--- @within examples.json_example
print("\nExample 3: Error Handling")
logger.info("----------------------")

-- Try to encode an invalid value
local encode_ok, encode_err = pcall(json.encode, function() end)
print("Trying to encode a function:")
print("Success:", tostring(encode_ok))
print("Error:", encode_err) -- pcall returns the error message directly

-- Try to decode invalid JSON
local decode_ok, decode_err = pcall(json.decode, "{ invalid json ' ")
print("\nTrying to decode invalid JSON:")
print("Success:", tostring(decode_ok))
print("Error:", decode_err) -- Check the returned error message/object

--- Demonstrates how the JSON module handles special Lua values like `NaN`, `Infinity`,
-- escaped string characters, and differentiates between arrays and objects.
--- @within examples.json_example
print("\nExample 4: Special Cases")
logger.info("---------------------")

-- Special numbers
logger.info("Encoding special numbers:")
-- JSON standard represents these as null
print("NaN:", json.encode(0 / 0)) -- Expected: null
print("Infinity:", json.encode(math.huge)) -- Expected: null
print("-Infinity:", json.encode(-math.huge)) -- Expected: null

-- Escaped strings
logger.info("\nEncoding escaped strings:")
print("Newline:", json.encode("hello\nworld"))
print("Quote:", json.encode('quote"here'))
print("Tab:", json.encode("tab\there"))

-- Arrays vs Objects
logger.info("\nArrays vs Objects:")
print("Array:", json.encode({ 1, 2, 3 }))
print("Object:", json.encode({ x = 1, y = 2 }))
print("Mixed:", json.encode({ 1, 2, x = 3 }))

--- Demonstrates a simple example of validating the structure of decoded JSON data.
--- Note: Schema validation is typically done *after* decoding, not by the JSON module itself.
--- @within examples.json_example
print("\nExample 5: Schema Validation (Conceptual)")
logger.info("-------------------------")

-- Define a schema validator
--- Basic validator function for a user object schema.
--- @param user table|any The decoded data to validate.
--- @return boolean isValid True if the data matches the expected schema, false otherwise.
--- @within examples.json_example
local function validate_user(user)
  if type(user) ~= "table" then
    return false
  end
  if type(user.name) ~= "string" then
    return false
  end
  if type(user.age) ~= "number" then
    return false
  end
  return true
end

-- Valid user
local valid_user = {
  name = "John",
  age = 30,
}

logger.info("Valid user:")
local json_user = json.encode(valid_user)
print("JSON:", json_user)

local decoded_user, decode_err_valid = json.decode(json_user)
print("Valid?", decode_err_valid == nil and validate_user(decoded_user))

-- Invalid user
local invalid_user = {
  name = 123, -- Wrong type
  age = "30", -- Wrong type
}

logger.info("\nInvalid user:")
json_user = json.encode(invalid_user)
print("JSON:", json_user)

local decoded_invalid_user, decode_err_invalid = json.decode(json_user)
print("Valid?", decode_err_invalid == nil and validate_user(decoded_invalid_user))

logger.info("\nJSON module example completed successfully.")
temp_dir = nil

-- Cleanup is handled automatically by temp_file registration
