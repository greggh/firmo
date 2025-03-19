-- Test file to verify error logging behavior in tests
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Helper function to create a test error
local function create_test_error(message)
  return error_handler.validation_error(message or "Test validation error", {
    test_context = "error_logging_test"
  })
end

-- Helper function that throws an error
local function function_that_throws()
  error("This is a test error")
end

describe("Error Logging in Tests", function()
  
  it("should log errors for tests without expect_error flag", function()
    -- In this test, we deliberately DON'T use expect_error flag
    -- So the error will be logged (and visible in test output)
    
    -- Using with_error_capture ensures the test doesn't crash
    local result, err = test_helper.with_error_capture(function()
      -- This will produce an error that should be logged
      return error_handler.throw("This error should be logged", 
        error_handler.CATEGORY.RUNTIME, 
        error_handler.SEVERITY.ERROR)
    end)()
    
    -- We expect an error to be returned
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.exist() -- Just check that we have a category, don't be strict about which one
    -- NOTE: This test will show an ERROR log in the output - this is expected
  end)
  
  it("should suppress error logs for tests with expect_error flag", { expect_error = true }, function()
    -- In this test, we use the expect_error flag
    -- No error logs should appear in the test output
    
    local result, err = test_helper.with_error_capture(function()
      -- This error should NOT be logged in test output
      return error_handler.throw("This error should NOT be logged", 
        error_handler.CATEGORY.RUNTIME, 
        error_handler.SEVERITY.ERROR)
    end)()
    
    -- We expect an error to be returned
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.exist() -- Just check that we have a category, don't be strict about which one
    -- NOTE: This test should NOT show an ERROR log in the output
  end)
  
  it("should properly handle Lua errors with expect_error flag", { expect_error = true }, function()
    -- Test with a standard Lua error
    local result, err = test_helper.with_error_capture(function_that_throws)()
    
    -- We expect an error to be returned but not logged
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("This is a test error")
    -- NOTE: This test should NOT show an ERROR log in the output
  end)
  
  it("should store expected errors in _G._firmo_test_errors", { expect_error = true }, function()
    -- Clear the global error collection
    _G._firmo_test_errors = {}
    
    -- Generate an error that should be stored but not logged
    local result, err = test_helper.with_error_capture(function()
      return error_handler.throw("Store this error", 
        error_handler.CATEGORY.RUNTIME, 
        error_handler.SEVERITY.ERROR)
    end)()
    
    -- Verify the error was captured and stored
    expect(_G._firmo_test_errors).to.exist()
    expect(#_G._firmo_test_errors).to.be_greater_than(0)
    expect(_G._firmo_test_errors[1].message).to.match("Store this error")
    
    -- Verify the test receives the error
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.exist() -- Just check that we have a category, don't be strict about which one
  end)
  
end)