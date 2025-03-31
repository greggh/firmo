-- firmo v3 coverage parser tests
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local parser = require("lib.coverage.v3.instrumentation.parser")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Coverage v3 Parser", function()
  it("should parse simple variable declarations", function()
    local source = [[
      local x = 1
      local y = 2
    ]]
    
    local ast = parser.parse(source)
    expect(ast).to.exist()
    expect(ast.tag).to.equal("Chunk")
    expect(#ast).to.equal(2) -- Two statements
    
    -- First statement
    expect(ast[1].tag).to.equal("Local")
    expect(ast[1].pos).to.exist()
    expect(ast[1].line).to.equal(1)
    expect(ast[1][1][1]).to.equal("x")
    expect(ast[1][2][1].tag).to.equal("Number")
    expect(ast[1][2][1][1]).to.equal(1)
    
    -- Second statement
    expect(ast[2].tag).to.equal("Local")
    expect(ast[2].pos).to.exist()
    expect(ast[2].line).to.equal(2)
    expect(ast[2][1][1]).to.equal("y")
    expect(ast[2][2][1].tag).to.equal("Number")
    expect(ast[2][2][1][1]).to.equal(2)
  end)

  it("should parse function declarations", function()
    local source = [[
      local function add(a, b)
        return a + b
      end
    ]]
    
    local ast = parser.parse(source)
    expect(ast).to.exist()
    expect(ast.tag).to.equal("Chunk")
    expect(#ast).to.equal(1)
    
    local func = ast[1]
    expect(func.tag).to.equal("Localrec")
    expect(func.pos).to.exist()
    expect(func.line).to.equal(1)
    expect(func[1][1][1]).to.equal("add") -- Function name
    
    -- Function parameters
    local params = func[2][1][1]
    expect(#params).to.equal(2)
    expect(params[1][1]).to.equal("a")
    expect(params[2][1]).to.equal("b")
  end)

  it("should preserve comments", function()
    local source = [[
      -- Header comment
      local x = 1 -- Line comment
      -- Another line comment
      local y = 2
    ]]
    
    local ast = parser.parse(source)
    expect(ast).to.exist()
    expect(ast.comments).to.exist()
    expect(#ast.comments).to.equal(3)
    
    -- Header comment
    expect(ast.comments[1].text).to.match("^%-%- Header comment")
    expect(ast.comments[1].line).to.equal(1)
    
    -- Line comment
    expect(ast.comments[2].text).to.match("^%-%- Line comment")
    expect(ast.comments[2].line).to.equal(2)
    
    -- Another line comment
    expect(ast.comments[3].text).to.match("^%-%- Another line comment")
    expect(ast.comments[3].line).to.equal(3)
  end)

  it("should handle syntax errors gracefully", { expect_error = true }, function()
    local source = [[
      local x = -- incomplete statement
      return x
    ]]
    
    local result, err = test_helper.with_error_capture(function()
      return parser.parse(source)
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("syntax error")
  end)

  it("should track line numbers correctly", function()
    local source = [[

      local x = 1

      local y = 2

      local z = 3
    ]]
    
    local ast = parser.parse(source)
    expect(ast).to.exist()
    expect(#ast).to.equal(3)
    
    expect(ast[1].line).to.equal(2)
    expect(ast[2].line).to.equal(4)
    expect(ast[3].line).to.equal(6)
  end)

  it("should parse complex expressions", function()
    local source = [[
      local x = 1 + 2 * 3
      local y = x * (4 + 5)
    ]]
    
    local ast = parser.parse(source)
    expect(ast).to.exist()
    expect(#ast).to.equal(2)
    
    -- First expression: 1 + 2 * 3
    local expr1 = ast[1][2][1]
    expect(expr1.tag).to.equal("Op")
    expect(expr1[1]).to.equal("+")
    
    -- Second expression: x * (4 + 5)
    local expr2 = ast[2][2][1]
    expect(expr2.tag).to.equal("Op")
    expect(expr2[1]).to.equal("*")
  end)
end)