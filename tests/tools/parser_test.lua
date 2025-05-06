--- Lua Parser Module Tests
---
--- This test suite verifies the functionality of the Lua parser module (`lib.tools.parser`),
--- which provides:
--- - AST (Abstract Syntax Tree) generation from Lua source code (`parse`).
--- - Code structure analysis for coverage and static analysis (`get_executable_lines`, `get_functions`).
--- - Syntax validation and error detection (`parse` error return).
--- - Support for function and block boundary detection.
--- - AST pretty-printing (`to_string`, previously `pretty_print`).
--- - Code map generation (`create_code_map`).
--- The tests cover basic parsing, pretty-printing, executable line detection,
--- function detection, code map creation, and syntax error handling.
---
--- @author Firmo Team
--- @test

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

local parser = require("lib.tools.parser")
local test_helper = require("lib.tools.test_helper")

describe("Parser Module", function()
  describe("Basic Parsing", function()
    local code = [[
local function test(a, b, ...)
  local sum = a + b
  print("The sum is:", sum)

  if sum > 10 then
    return true
  else
    return false
  end
end

-- Call the function
test(5, 10)
]]

    it("should parse Lua code successfully", function()
      local ast = parser.parse(code, "test_code")
      expect(ast).to.exist()
    end)

    it("should pretty print the AST", { expect_error = true }, function()
      -- Test valid case first
      local ast = parser.parse(code, "test_code")
      local pp_output = parser.to_string(ast) -- Use the renamed function
      expect(pp_output).to.be.a("string")
      expect(pp_output).to_not.be.empty()

      -- Test invalid AST (nil)
      local err = test_helper.expect_error(function()
        return parser.to_string(nil) -- Use the renamed function
      end)
      expect(err).to.exist()
      expect(err.message).to.match("invalid AST")

      -- Test malformed AST (wrong structure)
      local malformed_ast = { type = "invalid_type" }
      local err2 = test_helper.expect_error(function()
        return parser.to_string(malformed_ast) -- Use the renamed function
      end)
      expect(err2).to.exist()
      expect(err2.message).to.match("malformed AST")
    end)
    
    --- Tests AST validation with both success and error cases
    --- Verifies that the parser's validate function correctly validates ASTs
    --- and properly handles the errorinfo parameter
    it("should validate AST structure", { expect_error = true }, function()
      -- Get a valid AST
      local source_code = "local x = 1"
      local ast = parser.parse(source_code, "test_validation")
      expect(ast).to.exist()
      
      -- Create proper errorinfo with required fields
      local errorinfo = {
        subject = source_code,
        filename = "test_validation"
      }
      
      -- Test successful validation
      local validator = require("lib.tools.parser.validator")
      local is_valid, err_msg = validator.validate(ast, errorinfo)
      expect(is_valid).to.exist()
      expect(err_msg).to.be(nil)
      
      -- Test with missing errorinfo
      local err = test_helper.with_error_capture(function()
        return validator.validate(ast, nil)
      end)
      expect(err).to.exist()
      expect(err.message).to.match("validator requires errorinfo table")
      
      -- Test with incomplete errorinfo
      local incomplete_info = { subject = source_code }
      local err2 = test_helper.with_error_capture(function()
        return validator.validate(ast, incomplete_info)
      end)
      expect(err2).to.exist()
      expect(err2.message).to.match("errorinfo.filename must be a string")
      
      -- Test with invalid AST
      local invalid_ast = { tag = "Chunk" } -- Missing position information
      local err3 = test_helper.with_error_capture(function()
        return validator.validate(invalid_ast, errorinfo)
      end)
      expect(err3).to.exist()
      expect(err3.message).to.match("has invalid pos field")
    end)

    it("should detect executable lines", { expect_error = true }, function()
      -- Test valid case first
      local ast = parser.parse(code, "test_code")
      local executable_lines = parser.get_executable_lines(ast, code)

      expect(executable_lines).to.be.a("table")

      -- Count executable lines
      local count = 0
      for _ in pairs(executable_lines) do
        count = count + 1
      end

      -- We should have several executable lines in our sample
      expect(count).to.be_greater_than(3)

      -- Test with invalid AST
      local err = test_helper.expect_error(function()
        return parser.get_executable_lines(nil, code)
      end)
      expect(err).to.exist()
      expect(err.message).to.match("invalid AST")

      -- Test with invalid code
      local err2 = test_helper.expect_error(function()
        return parser.get_executable_lines(ast, nil)
      end)
      expect(err2).to.exist()
      expect(err2.message).to.match("invalid code")

      -- Test with malformed AST
      local malformed_ast = { type = "invalid_type" }
      local err3 = test_helper.expect_error(function()
        return parser.get_executable_lines(malformed_ast, code)
      end)
      expect(err3).to.exist()
      expect(err3.message).to.match("malformed AST")
    end)

    it("should detect functions", function()
      local ast = parser.parse(code, "test_code")
      local functions = parser.get_functions(ast, code)

      expect(functions).to.be.a("table")
      expect(#functions).to.equal(1) -- Our sample has one function

      local func = functions[1]
      expect(func.name).to.equal("test")
      expect(func.params).to.be.a("table")
      expect(#func.params).to.equal(2) -- a, b parameters
      expect(func.is_vararg).to.be_truthy() -- Has vararg ...
    end)

    it("should create code map", function()
      local code_map = parser.create_code_map(code, "test_code")

      expect(code_map).to.be.a("table")
      expect(code_map.valid).to.be_truthy()
      expect(code_map.source_lines).to.be_greater_than(0)
    end)
  end)

  describe("Error Handling", function()
    it("should handle syntax errors gracefully", { expect_error = true }, function()
      local invalid_code = [[
function broken(
  -- Missing closing parenthesis
  return 5
end
]]

      local err = test_helper.expect_error(function()
        return parser.parse(invalid_code, "invalid_code")
      end)

      expect(err).to.exist()
      expect(err.message).to.match("syntax") -- Should mention syntax error
      expect(err.source).to.equal("invalid_code") -- Should include source name
    end)
  end)
end)
