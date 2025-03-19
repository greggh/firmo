-- Test file to verify error logging behavior with debug logs enabled
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Enable debug logs for the ErrorHandler module
logging.set_module_level("ErrorHandler", logging.LEVELS.DEBUG)

-- Helper function that throws an error
local function function_that_throws()
  error("This is a test error")
end

describe("Error Logging with Debug Enabled", function()
  
  it("should log errors at debug level for tests with expect_error flag", { expect_error = true }, function()
    -- In this test, we use the expect_error flag
    -- With debug logs enabled, we should see debug-level logs but not ERROR logs
    
    local result, err = test_helper.with_error_capture(function()
      -- This error should be logged at DEBUG level, not ERROR
      return error_handler.throw("This should appear as a DEBUG log", 
        error_handler.CATEGORY.RUNTIME, 
        error_handler.SEVERITY.ERROR)
    end)()
    
    -- We expect an error to be returned
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.exist()
  end)
  
  it("should properly handle debug info", { expect_error = true }, function()
    -- Add some debug info that should appear
    error_handler.set_current_test_metadata({
      name = "debug info test",
      expect_error = true
    })
    
    -- Log a debug message that should appear
    local logger = logging.get_logger("DebugTest")
    logger.debug("This DEBUG message should appear")
    
    -- Now generate an error that should be downgraded to debug
    local result, err = test_helper.with_error_capture(function_that_throws)()
    
    -- We expect an error to be returned and logged at debug level
    expect(result).to_not.exist()
    expect(err).to.exist()
  end)
  
end)

-- Reset logging level after tests
logging.set_module_level("ErrorHandler", logging.LEVELS.INFO)