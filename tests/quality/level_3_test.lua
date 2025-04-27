---@diagnostic disable: missing-parameter, param-type-mismatch
--- Quality Level 3 Test Example
---
--- This file represents a test that meets the requirements for Quality Level 3
--- (Managed). It builds upon Level 2 by including setup and teardown logic
--- using `before` and `after` hooks.
---
--- @author Firmo Team
--- @test
local firmo = require("firmo")
---@type fun(description: string, callback: function):nil describe Test suite container function
---@type fun(description: string, options: table|function, fn?: function):nil it Test case function with optional parameters
---@type fun(value: any):any expect Assertion generator function
---@type fun(callback: function):nil before Setup function that runs before each test
---@type fun(callback: function):nil after Teardown function that runs after each test
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

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

  local setup_value = nil
  before(function()
    setup_value = "initialized"
  end)

  after(function()
    setup_value = nil
  end)

  it("should use setup and teardown", function()
    expect(setup_value).to.equal("initialized")
    -- We verify that setup ran properly and after will run to clean up
  end)
end)

return true
