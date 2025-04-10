-- Test for expected errors

local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Expected Error Tests", function()
  describe("With expect_error flag", function()
    it("should handle expected errors correctly when error is thrown", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        error("This is an expected error")
      end)()
      
      expect(result).to_not.exist("Function should not return a value when error is thrown")
      expect(err).to.exist("Error object should be returned")
      expect(tostring(err)).to.match("This is an expected error", "Error message should match expected text")
    end)
    
    it("should detect actual error messages when error is thrown", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        error("Actual error message")
      end)()
      
      expect(result).to_not.exist("Function should not return a value when error is thrown")
      expect(err).to.exist("Error object should be returned")
      expect(tostring(err)).to.match("Actual error message", "Error message should match actual text")
      -- This would fail if uncommented:
      -- expect(tostring(err)).to.match("Wrong error message")
    end)
  end)
end)
