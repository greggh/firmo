-- truthy_falsey_test.lua

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")

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
      end, "Expected value to be truthy")

      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Expected.*false.*to be truthy", "Error message should include the actual value")

      -- Test the nil case
      err = test_helper.expect_error(function()
        expect(nil).to.be_truthy()
      end, "Expected value to be truthy")

      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Expected.*nil.*to be truthy", "Error message should include the actual value")
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
      end, "Expected value to not be truthy")

      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Expected.*true.*to not be truthy", "Error message should include the actual value")

      -- Test the string case
      err = test_helper.expect_error(function()
        expect("hello").to_not.be_truthy()
      end, "Expected value to not be truthy")

      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Expected.*hello.*to not be truthy", "Error message should include the actual value")
    end)
  end)
end)
