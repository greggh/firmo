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

-- Sample Lua code for parsing
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
      expect(err).to.be_nil()
      expect(ast).to.be.a("table")
      expect(ast.tag).to.equal("Block") -- Root node should be a Block
      expect(#ast).to.be_greater_than(0) -- Should have child nodes
    end)

    --- Tests parsing a valid Lua file.
    it("parses a valid Lua file using parser.parse_file()", function()
      expect(temp_file_path).to.be.a("string", "Temporary file path should exist")
      local ast, err = parser.parse_file(temp_file_path)
      expect(err).to.be_nil()
      expect(ast).to.be.a("table")
      expect(ast.tag).to.equal("Block")
      expect(#ast).to.be_greater_than(0)
    end)
  end)

  --- Tests for validating AST structure.
  --- @within examples.parser_example
  describe("AST Validation", function()
    --- Tests validating a correctly parsed AST.
    it("validates a correctly parsed AST using parser.validate()", function()
      local ast, parse_err = parser.parse(sample_lua_code)
      expect(parse_err).to.be_nil()
      expect(ast).to.exist()

      local is_valid, validate_err = parser.validate(ast)
      expect(validate_err).to.be_nil()
      expect(is_valid).to.be_truthy()
    end)

    --- Tests validation failure for an invalid AST structure.
    it("fails validation for an invalid AST structure", function()
      -- Create an intentionally invalid AST (e.g., missing tag)
      local invalid_ast = { { tag = "Id", "a" }, { tag = "Number", 1 } } -- Missing outer Block tag
      local is_valid, validate_err = parser.validate(invalid_ast)
      expect(is_valid).to.be_falsy()
      expect(validate_err).to.be.a("string")
      expect(validate_err).to.match("invalid AST structure") -- Check for expected error type
    end)
  end)

  --- Tests for converting AST back to string.
  --- @within examples.parser_example
  describe("AST to String", function()
    --- Tests converting a simple AST to its string representation.
    it("converts a simple AST to string using parser.to_string()", function()
      local ast, _ = parser.parse("local x = 1")
      expect(ast).to.exist()
      local ast_string = parser.to_string(ast)
      expect(ast_string).to.be.a("string")
      -- Check for key elements, exact format might vary slightly
      expect(ast_string).to.match("Block")
      expect(ast_string).to.match("Local")
      expect(ast_string).to.match("Id.*'x'")
      expect(ast_string).to.match("Number.*1")
      firmo.log.debug("AST String Representation:\n" .. ast_string)
    end)
  end)

  --- Tests for AST analysis functions.
  --- @within examples.parser_example
  describe("AST Analysis", function()
    --- Tests identifying executable lines.
    it("gets executable lines using parser.get_executable_lines()", function()
      local ast, _ = parser.parse(sample_lua_code)
      expect(ast).to.exist()
      local executable_lines = parser.get_executable_lines(ast, sample_lua_code)

      expect(executable_lines).to.be.a("table")
      -- Verify specific lines expected to be executable
      expect(executable_lines[4]).to.be_truthy() -- local sum = a + b
      expect(executable_lines[5]).to.be_truthy() -- if sum > 10 then
      expect(executable_lines[6]).to.be_truthy() -- print("Large sum!")
      expect(executable_lines[8]).to.be_truthy() -- return sum
      expect(executable_lines[11]).to.be_truthy() -- local result = add(5, 7)

      -- Verify lines not expected to be executable
      expect(executable_lines[1]).to_not.exist() -- Comment
      expect(executable_lines[3]).to_not.exist() -- Function definition line
      expect(executable_lines[7]).to_not.exist() -- end (of if)
      expect(executable_lines[9]).to_not.exist() -- end (of function)
      expect(executable_lines[12]).to_not.exist() -- Comment
    end)

    --- Tests finding function definitions.
    it("gets function definitions using parser.get_functions()", function()
      local ast, _ = parser.parse(sample_lua_code)
      expect(ast).to.exist()
      local functions = parser.get_functions(ast, sample_lua_code)

      expect(functions).to.be.a("table")
      expect(#functions).to.equal(1) -- Should find the 'add' function

      local func_info = functions[1]
      expect(func_info).to.be.a("table")
      expect(func_info.name).to.equal("add")
      expect(func_info.line_start).to.equal(3)
      expect(func_info.line_end).to.equal(9)
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
      expect(#code_map.lines).to.equal(#code_map.source:split("\n"))
      expect(#code_map.functions).to.equal(1)
    end)
  end)

  --- Tests for handling parsing errors.
  --- @within examples.parser_example
  describe("Error Handling", function()
    --- Tests parsing invalid Lua syntax.
    it("returns error for invalid syntax using parser.parse()", function()
      local invalid_code = "local x = 1\nlocal y = " -- Incomplete assignment
      local ast, err = parser.parse(invalid_code)
      expect(ast).to.be_nil()
      expect(err).to.be.a("string")
      -- Error message details might depend on LPegLabel version
      expect(err).to.match("Parse error")
    end)

    --- Tests parsing a non-existent file.
    it("returns error for non-existent file using parser.parse_file()", function()
      local non_existent_path = temp_dir:path_for("non_existent_file.lua")
      local ast, err = parser.parse_file(non_existent_path)
      expect(ast).to.be_nil()
      expect(err).to.be.a("string")
      expect(err).to.match("File not found")
    end)

    --- Tests creating a code map from invalid source.
    it("returns error map for invalid source using parser.create_code_map()", function()
      local invalid_code = "this is not lua { "
      local code_map = parser.create_code_map(invalid_code)
      expect(code_map.valid).to.be_falsy()
      expect(code_map.error).to.be.a("string")
      expect(code_map.error).to.match("Parse error")
    end)
  end)
end)
