-- tests/core/version_integration_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Version Integration", function()
  it("should have version from version.lua", function()
    expect(firmo.version).to.match("^%d+%.%d+%.%d+$")
  end)

  it("should load version module successfully", function()
    local v = require("lib.core.version")
    expect(v.string).to.equal(firmo.version)
  end)
end)
