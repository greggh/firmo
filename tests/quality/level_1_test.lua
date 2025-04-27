---@diagnostic disable: missing-parameter, param-type-mismatch
--- Quality Level 1 Test Example
---
--- This file represents a basic test that meets the minimum requirements for
--- Quality Level 1 (Basic). It includes simple assertions within a basic
--- test structure (`describe` and `it`).
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
end)

return true
