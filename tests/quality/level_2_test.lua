---@diagnostic disable: missing-parameter, param-type-mismatch
--- Quality Level 2 Test Example
---
--- This file represents a basic test that meets the requirements for
--- Quality Level 2 (Developed). It includes nested `describe` blocks and
--- multiple assertions within `it` blocks.
---
--- @author Firmo Team
--- @test
---@type Firmo
local firmo = require("firmo")
---@type fun(description: string, callback: function):nil describe Test suite container function
---@type fun(description: string, options: table|function, fn?: function):nil it Test case function with optional parameters
---@type fun(value: any):any expect Assertion generator function
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Sample Test Suite", function()
  it("should perform basic assertion", function()
    expect(true).to.be.truthy()
    expect(1 + 1).to.equal(2)
  end)
  describe("Nested Group", function()
    it("should have multiple assertions", function()
      local value = "test"
      expect(value).to.be.a("string")
      expect(#value).to.equal(4)
      expect(value:sub(1, 1)).to.equal("t")
    end)
  end)
end)

return true
