--[[
  json_example.lua
  
  Example demonstrating JSON coverage report generation with firmo.
  
  This example shows how to:
  - Generate JSON coverage reports from coverage data
  - Configure JSON-specific options like pretty printing
  - Save reports to disk using the filesystem module
  - Parse and work with the generated JSON data
]]

-- Import firmo (no direct coverage module usage per project rules)
---@diagnostic disable-next-line: unused-local
local firmo = require("firmo")

-- Import required modules
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

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

-- Create tests to demonstrate the JSON formatter
describe("JSON Formatter Example", function()
  -- Ensure the reports directory exists
  local reports_dir = "coverage-reports"
  fs.ensure_directory_exists(reports_dir)
  
  it("generates basic JSON coverage report", function()
    -- Generate JSON report
    print("Generating basic JSON coverage report...")
    local json_report = reporting.format_coverage(mock_coverage_data, "json")
    
    -- Validate the report
    expect(json_report).to.exist()
    expect(json_report).to.be.a("string")
    expect(json_report).to.match('"overall_percent":')
    
    -- Save to file
    local file_path = fs.join_paths(reports_dir, "coverage-report.json")
    local success, err = fs.write_file(file_path, json_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Basic JSON report saved to:", file_path)
    print("Report size:", #json_report, "bytes")
    
    -- Preview a sample of the JSON output
    print("\nJSON Preview (first 300 characters):")
    print(json_report:sub(1, 300) .. "...\n")
  end)
  
  it("demonstrates JSON formatter configuration options", function()
    -- Configure JSON formatter options via central_config
    central_config.set("reporting.formatters.json", {
      pretty = true,           -- Enable pretty printing (formatted JSON)
      indent = 2,              -- Number of spaces for indentation
      include_source = false,  -- Don't include source code in the report
      include_functions = true -- Include function coverage details
    })
    
    -- Generate the report with configuration
    print("Generating configured JSON coverage report...")
    local json_report = reporting.format_coverage(mock_coverage_data, "json")
    
    -- Validate the report
    expect(json_report).to.exist()
    expect(json_report).to.match("\n  ")  -- Should have indentation due to pretty=true
    
    -- Save to file
    local file_path = fs.join_paths(reports_dir, "coverage-report-pretty.json")
    local success, err = fs.write_file(file_path, json_report)
    
    -- Check if write was successful
    expect(success).to.be_truthy()
    
    print("Pretty-printed JSON report saved to:", file_path)
    print("Report size:", #json_report, "bytes")
    
    -- Preview a sample of the pretty-printed JSON output
    print("\nPretty JSON Preview (first 300 characters):")
    print(json_report:sub(1, 300) .. "...\n")
  end)
  
  it("demonstrates parsing and using the JSON data", function()
    -- Generate JSON report
    local json_report = reporting.format_coverage(mock_coverage_data, "json")
    
    -- Parse the JSON back to a Lua table (simulated)
    -- In a real application, you would use a JSON parser like dkjson or lunajson
    print("In a real application, you could parse the JSON back to a Lua table")
    print("and perform further analysis or display it in a custom UI.")
    
    -- Example of how you might use the JSON data
    print("\nExample use cases for JSON coverage data:")
    print("1. Store in a database for historical tracking")
    print("2. Create custom visualizations or dashboards")
    print("3. Integration with third-party tools via API")
    print("4. Generate delta reports to track coverage improvements")
  end)
end)

print("\n=== JSON Formatter Example ===")
print("This example demonstrates how to generate coverage reports in JSON format.")
print("JSON is ideal for machine-readable output, API integrations, and custom tooling.")

print("\nTo run this example directly:")
print("  lua examples/json_example.lua")

print("\nOr run it with firmo's test runner:")
print("  lua test.lua examples/json_example.lua")

print("\nCommon configurations for JSON reports:")
print("- pretty: true|false - Enable/disable pretty printing")
print("- indent: number - Spaces for indentation (default: 2)")
print("- include_source: true|false - Include source code in output")
print("- include_functions: true|false - Include function coverage details")

print("\nExample complete!")

-- JSON module example
local json = require("lib.tools.json")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Example 1: Basic encoding and decoding
print("\nExample 1: Basic Encoding/Decoding")
print("----------------------------------")

local data = {
  name = "test",
  values = {1, 2, 3},
  enabled = true
}

local json_str = json.encode(data)
print("Original data:", logging.format_value(data))
print("JSON string:", json_str)

local decoded = json.decode(json_str)
print("Decoded data:", logging.format_value(decoded))

-- Example 2: Working with files
print("\nExample 2: Working with Files")
print("--------------------------")

-- Create a test directory
local test_dir = test_helper.create_temp_test_directory()

-- Create a configuration object
local config = {
  server = {
    host = "localhost",
    port = 8080
  },
  database = {
    url = "postgres://localhost/test",
    pool = {
      min = 1,
      max = 10
    }
  },
  features = {
    logging = true,
    metrics = false
  }
}

-- Save to file
print("Saving configuration to file...")
test_dir.create_file("config.json", json.encode(config))

-- Read from file
print("Reading configuration from file...")
local content = test_dir.read_file("config.json")
local loaded_config = json.decode(content)

print("Loaded config:", logging.format_value(loaded_config))

-- Example 3: Error Handling
print("\nExample 3: Error Handling")
print("----------------------")

-- Try to encode an invalid value
local result, err = json.encode(function() end)
print("Trying to encode a function:")
print("Result:", result)
print("Error:", err and err.message or "no error")

-- Try to decode invalid JSON
result, err = json.decode("invalid json")
print("\nTrying to decode invalid JSON:")
print("Result:", result)
print("Error:", err and err.message or "no error")

-- Example 4: Special Cases
print("\nExample 4: Special Cases")
print("---------------------")

-- Special numbers
print("Encoding special numbers:")
print("NaN:", json.encode(0/0))
print("Infinity:", json.encode(math.huge))
print("-Infinity:", json.encode(-math.huge))

-- Escaped strings
print("\nEncoding escaped strings:")
print("Newline:", json.encode("hello\nworld"))
print("Quote:", json.encode("quote\"here"))
print("Tab:", json.encode("tab\there"))

-- Arrays vs Objects
print("\nArrays vs Objects:")
print("Array:", json.encode({1, 2, 3}))
print("Object:", json.encode({x = 1, y = 2}))
print("Mixed:", json.encode({1, 2, x = 3}))

-- Example 5: Schema Validation
print("\nExample 5: Schema Validation")
print("-------------------------")

-- Define a schema validator
local function validate_user(user)
  if type(user) ~= "table" then return false end
  if type(user.name) ~= "string" then return false end
  if type(user.age) ~= "number" then return false end
  return true
end

-- Valid user
local valid_user = {
  name = "John",
  age = 30
}

print("Valid user:")
local json_user = json.encode(valid_user)
print("JSON:", json_user)

local decoded_user = json.decode(json_user)
print("Valid?", validate_user(decoded_user))

-- Invalid user
local invalid_user = {
  name = 123,  -- Wrong type
  age = "30"   -- Wrong type
}

print("\nInvalid user:")
json_user = json.encode(invalid_user)
print("JSON:", json_user)

decoded_user = json.decode(json_user)
print("Valid?", validate_user(decoded_user))

print("\nJSON module example completed successfully.")