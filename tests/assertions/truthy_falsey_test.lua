---@diagnostic disable: missing-parameter, param-type-mismatch
--- Truthy/Falsy Assertion Tests
---
--- This file tests the `expect(...).to.be_truthy()` assertion and its
--- negation `expect(...).to_not.be_truthy()` against various Lua values,
--- including `true`, `false`, `nil`, numbers (0 and non-zero), strings
--- (empty and non-empty), and tables.
--- It uses `test_helper.expect_error` to verify failure messages.
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

local test_helper = require("lib.tools.test_helper")
local inspect = require("inspect")

describe("Truthy and Falsey Assertions", function()
  describe("expect(value).to.be_truthy()", function()
    it("correctly identifies truthy values", function()
      expect(true).to.be_truthy()
      expect(1).to.be_truthy()
      expect("hello").to.be_truthy()
      expect({}).to.be_truthy()
      expect(0).to.be_truthy()
      expect("").to.be_truthy()
    end)

    it("correctly identifies non-truthy values", { expect_error = true }, function()
      -- Using expect_error for more concise error testing
      local err = test_helper.expect_error(function()
        expect(false).to.be_truthy()
      end, "expected.*to be truthy")

      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("expected.*to be truthy", "Error message should include the actual value")

      -- Test the nil case
      err = test_helper.expect_error(function()
        expect(nil).to.be_truthy()
      end, "expected.*to be truthy")

      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("expected.*to be truthy", "Error message should include the actual value")
    end)
  end)

  describe("expect(value).to_not.be_truthy()", function()
    it("correctly identifies falsey values", function()
      expect(false).to_not.be_truthy()
      expect(nil).to_not.be_truthy()
    end)

    it("correctly identifies non-falsey values", { expect_error = true }, function()
      -- Using expect_error for more concise error testing
      local err = test_helper.expect_error(function()
        expect(true).to_not.be_truthy()
      end, "expected.*to not be truthy")

      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("expected.*true.*to not be truthy", "Error message should include the actual value")

      -- Test the string case
      err = test_helper.expect_error(function()
        expect("hello").to_not.be_truthy()
      end, "expected.*to not be truthy")

      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("expected.*to not be truthy", "Error message should include the actual value")
    end)
  end)
end)
