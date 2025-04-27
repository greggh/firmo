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
local error_handler = require("lib.tools.error_handler")
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local firmo = require("firmo") -- Needed for describe/it/expect
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local logging = require("lib.tools.logging")
local test_helper = require("lib.tools.test_helper")

-- Setup logger
local logger = logging.get_logger("JSONExample")

-- Create mock coverage data (similar to the cobertura example)
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = true, -- This line was covered
        [2] = true, -- This line was covered
        [3] = true, -- This line was covered
        [5] = false, -- This line was not covered
        [6] = true, -- This line was covered
        [8] = false, -- This line was not covered
        [9] = false, -- This line was not covered
      },
      functions = {
        ["add"] = true, -- This function was covered
        ["subtract"] = true, -- This function was covered
        ["multiply"] = false, -- This function was not covered
        ["divide"] = false, -- This function was not covered
      },
      total_lines = 10,
      covered_lines = 4,
      total_functions = 4,
      covered_functions = 2,
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = true, -- This line was covered
        [2] = true, -- This line was covered
        [4] = true, -- This line was covered
        [5] = true, -- This line was covered
        [7] = false, -- This line was not covered
      },
      functions = {
        ["validate"] = true, -- This function was covered
        ["format"] = false, -- This function was not covered
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

-- ============================================================
-- PART 1: JSON Coverage Formatter Example (using Firmo tests)
-- ============================================================

--- Test suite demonstrating the JSON coverage report formatter.
describe("JSON Formatter Example", function()
  local temp_dir

  -- Setup: Create a temporary directory for reports before tests run
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)

  -- Teardown: Release reference (directory cleaned up by test_helper)
  after(function()
    temp_dir = nil
  end)

  --- Test case for generating a basic JSON coverage report.
  it("generates basic JSON coverage report", function()
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
    expect(success).to.be_truthy()

    logger.info("Basic JSON report saved to: " .. file_path)
    logger.info("Report size: " .. #json_report .. " bytes")

    -- Preview a sample of the JSON output
    logger.info("\nJSON Preview (first 300 characters):")
    print(json_report:sub(1, 300) .. "...\n")
  end)

  --- Test case for configuring the JSON formatter (pretty print, indent, etc.).
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
    expect(success).to.be_truthy()

    logger.info("Pretty-printed JSON report saved to: " .. file_path)
    logger.info("Report size: " .. #json_report .. " bytes")

    -- Preview a sample of the pretty-printed JSON output
    logger.info("\nPretty JSON Preview (first 300 characters):")
    print(json_report:sub(1, 300) .. "...\n")
  end)

  --- Test case discussing potential use cases for the generated JSON data.
  it("demonstrates parsing and using the JSON data", function()
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

--- Demonstrates basic encoding of a Lua table to a JSON string
-- using `json.encode` and decoding it back using `json.decode`.
logger.info("\nExample 1: Basic Encoding/Decoding")
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

--- Demonstrates encoding a Lua table to JSON, writing it to a file,
-- reading the file back, and decoding the JSON string.
logger.info("\nExample 2: Working with Files")
logger.info("--------------------------")

-- Create a test directory
local test_dir = test_helper.create_temp_test_directory()

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
logger.info("Saving configuration to file...")
test_dir.create_file("config.json", json.encode(config))

-- Read from file
logger.info("Reading configuration from file...")
local content = test_dir.read_file("config.json")
local loaded_config = json.decode(content)

print("Loaded config:", logging.format_value(loaded_config))

--- Demonstrates error handling for invalid encoding (e.g., functions)
-- and invalid decoding (malformed JSON string).
logger.info("\nExample 3: Error Handling")
logger.info("----------------------")

-- Try to encode an invalid value
local result, err = json.encode(function() end)
logger.info("Trying to encode a function:")
print("Result:", result)
print("Error:", err and err.message or "no error")

-- Try to decode invalid JSON
result, err = json.decode("invalid json")
logger.info("\nTrying to decode invalid JSON:")
print("Result:", result)
print("Error:", err and err.message or "no error")

--- Demonstrates how the JSON module handles special Lua values like
-- NaN, Infinity, escaped string characters, arrays vs objects.
logger.info("\nExample 4: Special Cases")
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

--- Demonstrates a simple example of validating the structure of decoded
-- JSON data (although this is typically done outside the JSON module itself).
logger.info("\nExample 5: Schema Validation")
logger.info("-------------------------")

-- Define a schema validator
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
