---@diagnostic disable: missing-parameter, param-type-mismatch
--- Simple Test Case
---
--- This file contains a very basic test case to verify the core test runner
--- functionality (describe, it, expect).
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

describe("Test", function()
  it("should work", function()
    expect(true).to.equal(true)
  end)
end)
