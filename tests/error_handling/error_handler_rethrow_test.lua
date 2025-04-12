-- Test for the error_handler.rethrow function
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")

describe("Error Handler Rethrow", function()
  describe("basic functionality", function()
    it("should rethrow a string error", { expect_error = true }, function()
      -- This test verifies that string errors are properly rethrown
      local result, err = test_helper.with_error_capture(function()
        error_handler.rethrow("Simple string error")
      end)()

      -- Make assertions
      expect(result).to_not.exist()
      expect(err.message).to.match("Simple string error")
    end)

    it("should preserve error message when rethrowing table errors", { expect_error = true }, function()
      -- Create an error object
      local error_obj = error_handler.validation_error("Missing parameter")

      -- Verify it's rethrown properly
      local result, err = test_helper.with_error_capture(function()
        error_handler.rethrow(error_obj)
      end)()

      expect(result).to_not.exist()
      expect(err.message).to.match("Missing parameter")
    end)
  end)

  -- Test that error handler properly preserves context information
  describe("enhanced error objects", function()
    it("preserves additional context metadata in logging", { expect_error = true }, function()
      -- Create a test error with context
      local error_obj = error_handler.validation_error("Test error with context", {
        operation = "test_operation",
        parameter = "test_param",
      })

      -- Create additional context
      local additional_context = {
        request_id = "12345",
        timestamp = os.time(),
      }

      -- We're not testing the thrown value (which is just a string),
      -- we're testing that the logged error object has the right context
      local logged_error = nil

      -- Replace log_error function temporarily to capture the error
      local original_log_error = error_handler.log_error
      error_handler.log_error = function(err)
        logged_error = err
      end

      -- Call rethrow (inside pcall to prevent test termination)
      pcall(function()
        error_handler.rethrow(error_obj, additional_context)
      end)

      -- Restore original logging function
      error_handler.log_error = original_log_error

      -- Now verify the logged error had the expected structure
      expect(logged_error).to.exist()
      expect(logged_error.message).to.match("Test error with context")
      expect(logged_error.category).to.equal("VALIDATION")

      -- Verify context was merged correctly
      expect(logged_error.context).to.exist()
      expect(logged_error.context.operation).to.equal("test_operation")
      expect(logged_error.context.parameter).to.equal("test_param")
      expect(logged_error.context.request_id).to.equal("12345")
      expect(logged_error.context.timestamp).to.exist()
    end)
  end)
end)

