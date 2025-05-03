--- json_example.lua
--
-- This file demonstrates two primary aspects related to JSON in Firmo:
--
-- 1.  **JSON Coverage Report Formatter:** It shows how to generate JSON format
--     coverage reports using `reporting.format_coverage`, configure options like
--     pretty printing via `central_config`, and save the output using `test_helper`
--     for temporary files.
-- 2.  **Core JSON Module:** It demonstrates the direct usage of the `lib.tools.json`
--     module for encoding Lua tables to JSON strings (`json.encode`) and decoding
--     JSON strings back into Lua tables (`json.decode`), including file I/O and
--     error handling.
--
-- Run embedded tests (Part 1): lua test.lua examples/json_example.lua
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
--- @type MockCoverageData (See csv_example.lua for full definition)
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

-- ============================================================
-- PART 1: JSON Coverage Formatter Example (using Firmo tests)
-- ============================================================

--- Test suite demonstrating the JSON coverage report formatter.
--- @within examples.json_example
describe("JSON Coverage Formatter Example", function()
  local temp_dir -- Stores the temporary directory helper object

  --- Setup hook: Create a temporary directory for reports.
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  --- Teardown hook: Release reference. Directory cleaned automatically.
  after(function()
    temp_dir = nil
  end)

  --- Tests generating a basic JSON coverage report with default settings.
  it("generates basic JSON coverage report with defaults", function()
    -- Generate JSON report
    logger.info("Generating basic JSON coverage report...")
    local json_report = reporting.format_coverage(mock_coverage_data, "json")

    -- Validate the report
    expect(json_report).to.exist()
    expect(json_report).to.be.a("string")
    expect(json_report).to.match('"overall_percent":')

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-report.json")
    local success, err = fs.write_file(file_path, json_report)

    -- Check if write was successful
    expect(err).to.be_nil() -- Check for nil error string
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
    local json_report = reporting.format_coverage(mock_coverage_data, "json")

    -- Validate the report
    expect(json_report).to.exist()
    expect(json_report).to.match("\n  ") -- Should have indentation due to pretty=true

    -- Save to file
    local file_path = fs.join_paths(temp_dir.path, "coverage-report-pretty.json")
    local success, err = fs.write_file(file_path, json_report)

    -- Check if write was successful
    expect(err).to.be_nil() -- Check for nil error string
    expect(success).to.be_truthy()

    logger.info("Pretty-printed JSON report saved to: " .. file_path)
    logger.info("Report size: " .. #json_report .. " bytes")

    -- Preview a sample of the pretty-printed JSON output
    logger.info("\nPretty JSON Preview (first 300 characters):")
    print(json_report:sub(1, 300) .. "...\n")
  end)

  --- Informational test discussing potential use cases for the generated JSON data.
  it("discusses parsing and using the JSON data", function()
    -- Generate JSON report
    local json_report = reporting.format_coverage(mock_coverage_data, "json")

    -- Parse the JSON back to a Lua table (simulated)
    -- In a real application, you would use a JSON parser like dkjson or lunajson
    -- In a real application, you would use a JSON parser like dkjson or lunajson
    logger.info("In a real application, you could parse the JSON back to a Lua table")
    logger.info("and perform further analysis or display it in a custom UI.")

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
logger.info("----------------------------------")

local data = {
  name = "test",
  values = { 1, 2, 3 },
  enabled = true,
}

local json_str = json.encode(data)
print("Original data:", logging.format_value(data))
print("JSON string:", json_str)

local decoded = json.decode(json_str)
print("Decoded data:", logging.format_value(decoded))

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
local write_ok, write_err = fs.write_file(json_file_path, json.encode(config))
if not write_ok then
  error("Failed to write JSON file: " .. write_err)
end

-- Read from file using fs.read_file
print("Reading configuration from file...")
local content, read_err = fs.read_file(json_file_path)
if not content then
  error("Failed to read JSON file: " .. read_err)
end
local loaded_config = json.decode(content)

print("Loaded config:", logging.format_value(loaded_config))
print("Loaded config:", logging.format_value(loaded_config))

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
local decode_ok, decode_err_or_result = pcall(json.decode, "{ invalid json ' ")
print("\nTrying to decode invalid JSON:")
print("Success:", tostring(decode_ok))
print("Error:", decode_err_or_result) -- pcall returns the error message directly

--- Demonstrates how the JSON module handles special Lua values like `NaN`, `Infinity`,
-- escaped string characters, and differentiates between arrays and objects.
--- @within examples.json_example
print("\nExample 4: Special Cases")
logger.info("---------------------")

-- Special numbers
logger.info("Encoding special numbers:")
print("NaN:", json.encode(0 / 0))
print("Infinity:", json.encode(math.huge))
print("-Infinity:", json.encode(-math.huge))

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

local decoded_user = json.decode(json_user)
print("Valid?", validate_user(decoded_user))

-- Invalid user
local invalid_user = {
  name = 123, -- Wrong type
  age = "30", -- Wrong type
}

logger.info("\nInvalid user:")
json_user = json.encode(invalid_user)
print("JSON:", json_user)

decoded_user = json.decode(json_user)
print("Valid?", validate_user(decoded_user))

logger.info("\nJSON module example completed successfully.")

-- Add cleanup for temp_file module at the end
local temp_file = require("lib.tools.filesystem.temp_file")
temp_file.cleanup_all()
