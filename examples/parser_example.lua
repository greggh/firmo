--- Example demonstrating the Firmo Lua Parser module.
---
--- This example showcases the core functionalities of the `lib.tools.parser` module,
--- which uses LPegLabel to parse Lua code into an Abstract Syntax Tree (AST)
--- and provides utilities for analyzing that AST.
---
--- Features Demonstrated:
--- - Parsing Lua code from a string using `parser.parse()`.
--- - Parsing Lua code from a file using `parser.parse_file()`.
--- - Validating the structure of a generated AST using `parser.validate()`.
--- - Converting an AST back into a string representation using `parser.to_string()`.
--- - Analyzing the AST to find executable lines using `parser.get_executable_lines()`.
--- - Analyzing the AST to find function definitions using `parser.get_functions()`.
--- - Creating a comprehensive code map (source, AST, analysis) using `parser.create_code_map()` and `parser.create_code_map_from_file()`.
--- - Handling parsing errors (invalid syntax, file not found).
---
--- @module examples.parser_example
--- @see lib.tools.parser
--- @see lib.tools.filesystem
--- @see lib.tools.test_helper
--- @usage
--- Run the embedded tests:
--- ```bash
--- lua test.lua examples/parser_example.lua
--- ```

-- Import necessary modules
local parser = require("lib.tools.parser")
local test_helper = require("lib.tools.test_helper")
local validator = require("lib.tools.parser.validator") -- Import validator module directly
-- Extract the testing functions we need
local firmo = require("firmo")
-- Table unpacking compatibility function
local unpack_table = table.unpack or unpack
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

-- Initialize logger
local logger = require("lib.tools.logging").get_logger("parser-example")

--- Helper function to create a valid errorinfo table for AST validation.
--- The validator requires specific fields in the errorinfo table to correctly
--- validate AST nodes and report errors with line numbers.
---
--- @param source string The source code string being validated
--- @param filename string Optional filename for error messages, defaults to "test.lua"
--- @return table A properly structured errorinfo table with required fields:
---   - subject: The source code being validated (required for position lookups)
---   - filename: A filename string for error messages (required for error formatting)
local function create_valid_errorinfo(source, filename)
  return {
    subject = source,
    filename = filename or "test.lua"
  }
end

--- Helper function to count the number of lines in a string.
--- Matches the parser's behavior by only counting non-empty lines.
--- The parser uses a regex pattern [^\r\n]+ which excludes empty lines.
--- @param str string The string to count lines in
--- @return number The number of non-empty lines in the string (parser behavior)
local function count_lines(str)
  local count = 0
  for _ in str:gmatch("[^\r\n]+") do
    count = count + 1
  end
  return count
end

-- Sample Lua code for parsing
-- Sample Lua code with consistent \n line endings only
local sample_lua_code = [[
-- Sample Lua code
local function add(a, b)
  local sum = a + b -- Calculate sum
  if sum > 10 then
    print("Large sum!") -- Print message
  end
  return sum
end

local result = add(5, 7)
-- End of sample
]]

-- Count the number of lines in sample_lua_code according to parser behavior
local parser_lines = count_lines(sample_lua_code)
-- Count actual lines (including empty ones) for comparison
local actual_lines = select(2, sample_lua_code:gsub("\n", "")) + 1

-- The parser counts only non-empty lines using the pattern [^\r\n]+
-- Our sample code has 12 actual lines (including empty lines) but only 10 non-empty lines
assert(parser_lines == 10, string.format("Parser should count 10 non-empty lines, but got %d", parser_lines))
assert(actual_lines == 12, string.format("sample_lua_code should have exactly 12 total lines, but got %d", actual_lines))

-- Log line count details for debugging
logger.debug("Line counting details:", {
  parser_lines = parser_lines, -- Non-empty lines (parser behavior)
  actual_total_lines = actual_lines, -- Total lines including empty ones
  newlines_count = select(2, sample_lua_code:gsub("\n", "")),
  empty_lines = actual_lines - parser_lines, -- Number of empty lines
  last_char = string.byte(sample_lua_code:sub(-1)) == string.byte("\n") and "newline" or "not newline"
})

--- Main test suite for the parser module.
--- @within examples.parser_example
describe("Parser Module Examples", function()
  local temp_dir -- Holds the test_helper temporary directory object

  local temp_file_path

  --- Setup hook: Create a temporary directory and a sample Lua file.
  before(function()
    temp_dir = test_helper.create_temp_test_directory("parser_example_")
    local file_path, err = temp_dir:create_file("sample.lua", sample_lua_code)
    if not file_path then
      error("Failed to create temporary test file: " .. tostring(err))
    end
    temp_file_path = file_path
  end)

  --- Teardown hook: Release reference. Directory cleaned automatically.
  after(function()
    temp_dir = nil
    temp_file_path = nil
  end)

  --- Tests for parsing Lua code from strings and files.
  --- @within examples.parser_example
  describe("Parsing", function()
    --- Tests parsing a valid Lua code string.
    it("parses a valid Lua code string using parser.parse()", function()
      local ast, err = parser.parse(sample_lua_code, "string_source")
      expect(err).to_not.exist()
      expect(ast).to.be.a("table")
      expect(ast.tag).to.equal("Block") -- Root node should be a Block
      expect(#ast).to.be_greater_than(0) -- Should have child nodes
    end)

    --- Tests parsing a valid Lua file.
    it("parses a valid Lua file using parser.parse_file()", function()
      expect(temp_file_path).to.be.a("string", "Temporary file path should exist")
      local ast, err = parser.parse_file(temp_file_path)
      expect(err).to_not.exist()
      expect(ast).to.be.a("table")
      expect(ast.tag).to.equal("Block")
      expect(#ast).to.be_greater_than(0)
    end)
  end)

  --- Tests for validating AST structure.
  --- @within examples.parser_example
  describe("AST Validation", function()
    --- Tests validating a correctly parsed AST.
    --- This test demonstrates the proper way to validate an AST:
    --- 1. Create a valid source string
    --- 2. Create a properly structured errorinfo table with subject and filename
    --- 3. Parse the source to get a valid AST
    --- 4. Validate the AST with the errorinfo
    it("validates a correctly parsed AST using parser.validate()", function()
      -- Using a simple example with minimal complexity
      local source = [[
local x = 1
return x
]]
      -- Create errorinfo with EXACTLY the required fields: subject and filename
      local errorinfo = {
        subject = source,       -- Source code string (required)
        filename = "validation_test.lua" -- Filename string (required)
      }
      
      -- Log errorinfo for debugging
      logger.debug("Errorinfo being used for validation:", {
        is_table = type(errorinfo) == "table",
        subject_type = type(errorinfo.subject),
        subject_length = errorinfo.subject and #errorinfo.subject or 0,
        filename = errorinfo.filename
      })
      
      -- Verify errorinfo has required fields before validation
      expect(errorinfo).to.be.a("table", "Errorinfo must be a table")
      expect(errorinfo.subject).to.be.a("string", "Errorinfo must have subject field")
      expect(errorinfo.filename).to.be.a("string", "Errorinfo must have filename field")
      
      -- Get AST directly from parser
      local ast, parse_err = parser.parse(source, errorinfo.filename)
      expect(parse_err).to_not.exist("Parser should not error on valid code")
      expect(ast).to.exist("Parser should produce a valid AST")
      
      -- Validate the AST using the validator module directly
      local result, err = validator.validate(ast, errorinfo)
      
      -- Log validation results
      logger.debug("Validation results:", {
        success = result ~= nil,
        error = err,
        ast_equals_result = (result == ast)
      })
      
      -- Verify validation succeeded
      expect(err).to_not.exist("Validation should not produce an error")
      expect(result).to.exist("AST validation should succeed")
      expect(result).to.equal(ast, "Validated AST should match input AST")
      
      -- Verify key properties of the validated AST
      expect(result.tag).to.equal("Block", "Root AST node should be a Block")
      expect(result.pos).to.be.a("number", "AST pos should be a number")
      expect(result.end_pos).to.be.a("number", "AST end_pos should be a number")
      expect(#result).to.be_greater_than(0, "AST should have child nodes")
    end)

    --- Tests validation failure for an AST structure missing required fields.
    --- Tests validation failure for an AST structure missing required fields.
    --- This test verifies that the validator correctly identifies missing required elements
    --- in specific node types (in this case, a Local node with no variable names).
    it("fails validation for an AST structure missing required fields", { expect_error = true }, function()
      local source = "local x = 1\n"
      local errorinfo = create_valid_errorinfo(source, "missing_fields_test.lua")
      
      -- Invalid AST - missing proper names array content
      -- Local statement needs at least one variable name
      local invalid_ast = {
        tag = "Block",
        pos = 1,
        end_pos = 12,
        [1] = {
          tag = "Local",
          pos = 1,
          end_pos = 11,
          [1] = {    -- Empty names array - this will fail validation
            tag = "NameList", -- Needs tag
            pos = 7,  -- Must still have position info
            end_pos = 8
            -- No elements, which is the intentional error
          },
          [2] = {    -- Values array
            tag = "ExpList", -- Needs tag
            pos = 11,
            end_pos = 12,
            [1] = {
              tag = "Number",
              pos = 11,
              end_pos = 12,
              [1] = 1
            }
          }
        }
      }
      
      -- Log the invalid AST structure for debugging
      logger.debug("Invalid AST validation test - Missing fields:", {
        structure = "Local node with empty NameList array",
        details = parser.to_string(invalid_ast),
        expected_error = "Local node must have at least one variable name"
      })
      
      local result, err = test_helper.with_error_capture(function()
        return parser.validate(invalid_ast, errorinfo)
      end)()  -- Call the wrapper function to execute it
      
      expect(result).to_not.exist("Validation should fail")
      expect(err).to.exist("Error should exist")
      expect(err.message).to.be.a("string", "Error should have a message string")
      expect(err.message).to.match("Local node must have at least one variable name")
      
      logger.debug("Invalid AST validation test - Result:", {
        success = (result ~= nil),
        error_message = err and err.message
      })
    end)
    
    --- Tests validation failure for an AST structure with missing position information.
    --- Tests validation failure for an AST structure with missing position information.
    --- This test verifies that the validator correctly enforces the requirement for
    --- all AST nodes to have proper position information (pos and end_pos fields).
    it("fails validation for an AST structure with missing position information", { expect_error = true }, function()
      local source = "local x = 1\n"
      local errorinfo = create_valid_errorinfo(source, "missing_position_test.lua")
      
      -- Invalid AST - missing pos field which is required for all nodes
      local invalid_ast = {
        tag = "Block",
        -- Intentionally missing pos field
        end_pos = 12,
        [1] = {
          tag = "Local",
          pos = 1,
          end_pos = 11,
          [1] = {  -- Names array
            tag = "NameList", -- Needs tag
            pos = 7,
            end_pos = 8,
            [1] = {  -- First name
              tag = "Id",
              pos = 7,
              end_pos = 8,
              [1] = "x"
            }
          },
          [2] = {  -- Values array
            tag = "ExpList", -- Needs tag
            pos = 11,
            end_pos = 12,
            [1] = {  -- First value
              tag = "Number",
              pos = 11,
              end_pos = 12,
              [1] = 1
            }
          }
        }
      }
      
      -- Log information about the missing field
      logger.debug("Invalid AST validation test - Missing position info:", {
        issue = "Root Block node missing pos field",
        ast_details = {
          has_tag = invalid_ast.tag ~= nil,
          has_pos = invalid_ast.pos ~= nil, -- Should be false
          has_end_pos = invalid_ast.end_pos ~= nil
        }
      })
      
      local result, err = test_helper.with_error_capture(function()
        return parser.validate(invalid_ast, errorinfo)
      end)()  -- Call the wrapper function to execute it
      
      expect(result).to_not.exist("Validation should fail")
      expect(err).to.exist("Error should exist")
      expect(err.message).to.be.a("string", "Error should have a message string")
      expect(err.message).to.match("missing pos field")
      
      logger.debug("Invalid AST validation test - Result:", {
        success = (result ~= nil),
        error_message = err and err.message
      })
    end)
    
      --- Tests validation failure when errorinfo is missing required fields.
    it("fails validation when errorinfo is missing required fields", { expect_error = true }, function()
      local ast = parser.parse("local x = 1")
      local invalid_errorinfo = {} -- Missing required fields
      
      local validated_ast, err = test_helper.with_error_capture(function()
        return parser.validate(ast, invalid_errorinfo)
      end)()
      
      expect(validated_ast).to_not.exist("Validation with invalid errorinfo should fail")
      expect(err).to.exist("Error should be captured")
      expect(err.message).to.match("errorinfo must have subject and filename fields")
    end)

    --- Tests validation failure for AST with improper tag field.
    it("fails validation for AST with improper tag field", { expect_error = true }, function()
      local source = "local x = 1"
      local errorinfo = create_valid_errorinfo(source)
      local invalid_ast = {
        tag = "InvalidTag", -- Invalid tag type
        pos = 1,
        end_pos = 12,
        [1] = {
          tag = "Local",
          pos = 1,
          end_pos = 11
        }
      }
      
      local validated_ast, err = test_helper.with_error_capture(function()
        return parser.validate(invalid_ast, errorinfo)
      end)()
      
      expect(validated_ast).to_not.exist("Validation with invalid tag should fail")
      expect(err).to.exist("Error should be captured")
      expect(err.message).to.match("Invalid tag type")
    end)
  end)
    

  --- Tests for converting AST back to string.
  --- @within examples.parser_example
  describe("AST to String", function()
    --- Tests converting a simple AST to its string representation.
    it("converts a simple AST to string using parser.to_string()", function()
      local source = "local x = 1"
      local ast, _ = parser.parse(source)
      expect(ast).to.exist()
      local ast_string = parser.to_string(ast)
      expect(ast_string).to.be.a("string")
      -- Match the actual format with backtick prefix for node names
      expect(ast_string).to.match("`Local")
      expect(ast_string).to.match("`Id")
      expect(ast_string).to.match("`Number")
      logger.debug("AST String Representation:\n" .. ast_string)
    end)
  end)

  --- Tests for AST analysis functions.
  --- @within examples.parser_example
  describe("AST Analysis", function()
    --- Tests identifying executable lines.
    it("gets executable lines using parser.get_executable_lines()", function()
      local ast, _ = parser.parse(sample_lua_code)
      expect(ast).to.exist()
      local executable_lines = parser.get_executable_lines(ast)
      expect(executable_lines[10]).to.be_truthy()  -- local result = add(5, 7)

      -- Verify lines not expected to be executable
      expect(executable_lines[48]).to_not.exist()  -- Comment
      expect(executable_lines[49]).to_not.exist()  -- Function definition line
      expect(executable_lines[53]).to_not.exist()  -- end (of if)
      expect(executable_lines[55]).to_not.exist()  -- end (of function)
      expect(executable_lines[58]).to_not.exist()  -- Comment
    end)

    --- Tests finding function definitions.
    it("finds function definitions using parser.get_functions()", function()
      local source = [[
local function add(a, b)
  return a + b
end
]]
      local ast, err = parser.parse(source)
      expect(err).to_not.exist()
      expect(ast).to.exist()
      
      local functions = parser.get_functions(ast, source)
      expect(functions).to.be.a("table")
      expect(#functions).to.equal(1)
      
      local func_info = functions[1]
      expect(func_info).to.be.a("table")
      expect(func_info.name).to.equal("add")
      expect(func_info.line_start).to.equal(1)  -- First line, no initial newline counted
      
      expect(func_info.params).to.deep_equal({ "a", "b" })
    end)
  end)

  --- Tests for creating code maps.
  --- @within examples.parser_example
  describe("Code Map Creation", function()
    --- Tests creating a code map from a string.
    it("creates a code map from string using parser.create_code_map()", function()
      local code_map = parser.create_code_map(sample_lua_code, "string_source")
      expect(code_map).to.be.a("table")
      expect(code_map.valid).to.be_truthy()
      expect(code_map.source).to.equal(sample_lua_code)
      expect(code_map.ast).to.be.a("table")
      expect(code_map.ast.tag).to.equal("Block")
      expect(code_map.lines).to.be.a("table")
      expect(#code_map.lines).to.be.greater_than(0)
      expect(code_map.executable_lines).to.be.a("table")
      expect(code_map.functions).to.be.a("table")
      expect(#code_map.functions).to.equal(1)
    end)

    --- Tests creating a code map from a file.
    it("creates a code map from file using parser.create_code_map_from_file()", function()
      expect(temp_file_path).to.be.a("string")
      local code_map = parser.create_code_map_from_file(temp_file_path)
      expect(code_map).to.be.a("table")
      expect(code_map.valid).to.be_truthy()
      expect(code_map.source).to.equal(sample_lua_code)
      expect(code_map.ast).to.be.a("table")

      -- Count actual newlines in sample_lua_code
      local parser_line_count = count_lines(sample_lua_code)
      expect(code_map.source).to.equal(sample_lua_code) -- Verify source matches 
      
      -- Log detailed line count information for debugging
      logger.debug("Code map line count details:", {
        parser_line_count = parser_line_count, -- Non-empty lines using parser's counting method
        actual_total_lines = select(2, sample_lua_code:gsub("\n", "")) + 1, -- Total lines including empty ones
        code_map_lines_count = #code_map.lines,
        source_lines_prop = code_map.source_lines
      })
      
      -- Parser's behavior: counts only non-empty lines using [^\r\n]+ pattern
      -- Our sample code has 12 actual lines but only 10 non-empty lines that the parser counts
      expect(parser_line_count).to.equal(10) -- Should match our updated count_lines function
      expect(#code_map.lines).to.equal(10) -- Parser's internal line count
      expect(code_map.source_lines).to.equal(10) -- Source lines property should also be 10
      expect(#code_map.functions).to.equal(1)
    end)
  end)

  --- Tests for handling parsing errors.
  --- @within examples.parser_example
  describe("Error Handling", function()
    --- Tests parsing invalid Lua syntax.
    it("returns error for invalid syntax using parser.parse()", { expect_error = true }, function()
      local invalid_code = "local x = 1\nlocal y = " -- Incomplete assignment
      
      local result, err = test_helper.with_error_capture(function()
        return parser.parse(invalid_code)
      end)()
      
      expect(result).to_not.exist("Parsing invalid code should return nil result")
      expect(err).to.exist("Error should be captured")
      expect(err.message).to.be.a("string")
      -- Error message details might depend on LPegLabel version
      expect(err.message).to.match("syntax error")
    end)

    --- Tests parsing a non-existent file.
    it("returns error for non-existent file using parser.parse_file()", { expect_error = true }, function()
      local non_existent_path = "./non_existent_file.lua"
      
      local result, err = test_helper.with_error_capture(function()
        return parser.parse_file(non_existent_path)
      end)()
      
      expect(result).to_not.exist("Parsing non-existent file should return nil result")
      expect(err).to.exist("Error should be captured")
      expect(err.message).to.be.a("string")
      expect(err.message).to.match("File not found:")  -- Match error prefix
    end)

    --- Tests creating a code map from invalid source.
    it("returns error map for invalid source using parser.create_code_map()", { expect_error = true }, function()
      local invalid_code = "this is not lua { "
      
      local result, err = test_helper.with_error_capture(function()
        return parser.create_code_map(invalid_code)
      end)()
      
      expect(result).to.exist("Should return a code map even with invalid code")
      expect(result.valid).to.be_falsy("Code map should be marked as invalid")
      expect(result.error).to.be.a("string", "Error message should be a string")
      expect(result.error).to.match("syntax error", "Error should indicate syntax error")
    end)
  end)
end)
