---@diagnostic disable: missing-parameter, param-type-mismatch
--- Test-Level Error Handling (`expect_error` Flag) Tests
---
--- Verifies the functionality of the `expect_error = true` option for `it` blocks.
--- Ensures that:
--- - Tests marked with `expect_error = true` do not fail when an error is thrown or returned.
--- - Standard errors and structured errors are handled correctly in this mode.
--- - The error handler's test metadata (`current_test_metadata`, `current_test_expects_errors`) reflects the `expect_error` flag.
--- Uses `test_helper.with_error_capture` for testing error capture within `expect_error` tests.
---
--- @author Firmo Team
--- @test
local error_handler = require("lib.tools.error_handler")
local firmo = require("firmo")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local test_helper = require("lib.tools.test_helper")

describe("Test Error Handling", function()
  --- Creates a function that throws a simple string error.
  ---@param message? string The error message to throw (default: "This is an expected error").
  ---@return function A function that throws the error when called.
  ---@private
  local function throw_error(message)
    return function()
      error(message or "This is an expected error")
    end
  end

  --- Creates a function that returns a validation error object from the error handler.
  ---@param message? string Message parameter (unused in current implementation).
  ---@return function A function that returns the error object when called.
  ---@private
  local function throw_validation_error(message)
    return function()
      return error_handler.validation_error("Expected validation error", {
        operation = "test_validation_error",
        test = "test_error_handling_test.lua",
      })
    end
  end

  --- Creates a function that returns a test-expected error object from the error handler.
  ---@param message? string Message parameter (unused in current implementation).
  ---@return function A function that returns the error object when called.
  ---@private
  local function throw_test_expected_error(message)
    return function()
      return error_handler.test_expected_error("Expected test error", {
        operation = "test_expected_error",
        test = "test_error_handling_test.lua",
      })
    end
  end

  describe("Standard errors (no expect_error flag)", function()
    it("should fail with a validation error", function()
      -- This test will fail, but that's intentional
      local result, err = throw_validation_error("This is a validation error without expect_error flag")()
      expect(result).to.exist() -- This will fail since result is nil
    end)

    it("should fail with a test-expected error", function()
      -- This test will fail, but that's intentional
      local result, err = throw_test_expected_error("This is a test-expected error without expect_error flag")()
      expect(result).to.exist() -- This will fail since result is nil
    end)
  end)

  describe("Errors with expect_error flag", function()
    it("should handle raw errors gracefully", { expect_error = true }, function()
      -- Use our helper for safe error testing
      local result, err = test_helper.with_error_capture(function()
        throw_error("Test error - should be captured")()
      end)()

      -- Should have captured an error
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.TEST_EXPECTED)
    end)

    it("should handle validation errors gracefully", { expect_error = true }, function()
      -- Force test mode explicitly
      error_handler.set_current_test_metadata({
        expect_error = true,
        name = "should handle validation errors gracefully",
      })

      -- This should not cause the test to fail
      local result, err = throw_validation_error("This is a validation error with expect_error flag")()

      -- We can still make assertions about the error
      expect(err).to.exist()
      expect(err.message).to.equal("Expected validation error") -- Changed to exact match
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    end)

    it("should handle test-expected errors gracefully", { expect_error = true }, function()
      -- Force test mode explicitly
      error_handler.set_current_test_metadata({
        expect_error = true,
        name = "should handle test-expected errors gracefully",
      })

      -- This should not cause the test to fail
      local result, err = throw_test_expected_error("This is a test-expected error with expect_error flag")()

      -- We can still make assertions about the error
      expect(err).to.exist()
      expect(err.message).to.equal("Expected test error") -- Changed to exact match
      expect(err.category).to.equal(error_handler.CATEGORY.TEST_EXPECTED)
    end)
  end)

  describe("Error metadata handling", function()
    -- In these tests, we verify that test metadata is properly set and cleared

    it("should set current_test_metadata.expect_error to true when flag is present", { expect_error = true }, function()
      local current_metadata = error_handler.get_current_test_metadata()
      expect(current_metadata).to.exist()
      expect(current_metadata.expect_error).to.equal(true)
      expect(current_metadata.name).to.match("should set current_test_metadata.expect_error to true")
    end)

    it("should set current_test_metadata.expect_error to false by default", function()
      local current_metadata = error_handler.get_current_test_metadata()
      expect(current_metadata).to.exist()
      expect(current_metadata.expect_error).to.equal(false)
      expect(current_metadata.name).to.match("should set current_test_metadata.expect_error to false by default")
    end)

    -- Test that current_test_expects_errors helper works
    it("should detect expect_error with helper function", { expect_error = true }, function()
      expect(error_handler.current_test_expects_errors()).to.equal(true)
    end)

    it("should not detect expect_error with helper function by default", function()
      expect(error_handler.current_test_expects_errors()).to.equal(false)
    end)
  end)

  describe("Lifecycle hooks with expect_error", function()
    local hook_error_thrown = false

    before(function()
      hook_error_thrown = false
    end)

    it("should handle errors that occur within expect_error tests", { expect_error = true }, function()
      -- Use our helper for safe error testing
      local result, err = test_helper.with_error_capture(function()
        -- Manually throw an error
        error("Intentional test error that should be captured")
      end)()

      -- Should have captured the error
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Intentional test error that should be captured")
    end)

    after(function()
      hook_error_thrown = true
    end)

    it("should handle errors returned by functions", { expect_error = true }, function()
      -- Force test mode explicitly
      error_handler.set_current_test_metadata({
        expect_error = true,
        name = "should handle errors returned by functions",
      })

      -- Call a function that returns an error
      local result, err = throw_validation_error()()

      -- This test passes because we can check properties of the error
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    end)
  end)
end)
