---@diagnostic disable: missing-parameter, param-type-mismatch
--- Simple Test Case
---
--- This file contains a very basic test case to verify the core test runner
--- functionality (describe, it, expect).
---
--- @author Firmo Team
--- @test

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
describe("Test", function()
  it("works", function()
    expect(true).to.equal(true)
  end)
end)
