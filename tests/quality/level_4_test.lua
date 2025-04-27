--- Quality Level 4 Test Example
---
--- This file represents a test that meets the requirements for Quality Level 4
--- (Robust). It builds upon Level 3 by including tests specifically
--- designed to cover edge cases (nil values, empty strings, large numbers, etc.).
---
--- @author Firmo Team
--- @test
local firmo = require("firmo")
---@type fun(description: string, callback: function):nil describe Test suite container function
---@type fun(description: string, options: table|function, fn?: function):nil it Test case function with optional parameters
---@type fun(value: any):any expect Assertion generator function
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
---@type fun(callback: function):nil before Setup function that runs before each test
---@type fun(callback: function):nil after Teardown function that runs after each test
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
  describe("Edge Cases", function()
    it("should handle nil values", function()
      expect(nil).to.be.falsy()
      -- Test a function returning nil
      local fn = function()
        return nil
      end
      expect(fn()).to.equal(nil)
    end)
    it("should handle empty strings", function()
      expect("").to.be.a("string")
      expect(#"").to.equal(0)
    end)
    it("should handle large numbers", function()
      expect(1e10).to.be.a("number")
      expect(1e10 > 1e9).to.be.truthy()
    end)
  end)
end)

return true
