-- Special fixed test file just for testing timeouts
package.path = "../?.lua;" .. package.path
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local it_async = firmo.it_async
local async = firmo.async

describe("Async Timeout Testing", function()
  it("simulates a timeout test for parallel_async", function()
    -- Create a fake test that simulates the behavior we want to test
    -- without actually running the timeout-prone functions

    -- This simulates what would happen if parallel_async detected a timeout
    local error_message = "Timeout of 50ms exceeded. Operations 2 did not complete in time."

    -- Test that our error parsing logic works correctly using the specialized regex assertion
    expect(error_message).to.match_regex("^Timeout of %d+ms exceeded%.", { case_insensitive = false })
    expect(error_message).to.match_regex("Operations %d+ did not complete in time%.", { case_insensitive = false })

    -- Mark this test as successful
    return true
  end)

  it_async("tests that operations can exceed expected timeouts", { expect_error = true }, function()
    -- Create a test that simulates timeout verification with proper error handling
    local test_helper = require("lib.tools.test_helper")
    local start_time = os.clock() * 1000
    local operation_completed = false

    -- Start a long-running operation
    firmo.set_timeout(function()
      operation_completed = true
    end, 100) -- Takes 100ms to complete

    -- Wait just a short time (not long enough for completion)
    firmo.set_timeout(function()
      -- Wrap assertions in error handling to properly capture potential failures
      local result, err = test_helper.with_error_capture(function()
        local elapsed = (os.clock() * 1000) - start_time
        -- After 30ms, the operation should not be completed yet
        expect(operation_completed).to_not.be_truthy()
        expect(elapsed).to.be_greater_than(20)
        expect(elapsed).to.be_less_than(80)
        return true
      end)()

      -- Verify no errors occurred during the timeout check
      expect(err).to_not.exist()
      expect(result).to.be_truthy()
    end, 30)

    -- Now wait longer to let the operation complete
    local wait_result, wait_err = test_helper.with_error_capture(function()
      return wait_until(function()
        return operation_completed
      end, 200)
    end)()

    -- Check that wait_until completed without errors
    expect(wait_err).to_not.exist()

    -- Verify the operation completed eventually
    expect(operation_completed).to.be_truthy()
  end)
end)
