---@diagnostic disable: missing-parameter, param-type-mismatch
-- tests/core/version_integration_test.lua

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

describe("Version Integration", function()
  it("should have version from version.lua", function()
    expect(firmo.version).to.match("^%d+%.%d+%.%d+$")
  end)

  it("should load version module successfully", function()
    local v = require("lib.core.version")
    expect(v.string).to.equal(firmo.version)
  end)
end)
