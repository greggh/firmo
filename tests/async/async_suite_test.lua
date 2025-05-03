--- Tests for async suite functions (describe_async, fdescribe_async, xdescribe_async)
--- and async test focus/skip functions (fit_async, xit_async).

-- Import necessary Firmo functions
local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after
local it_async, fit_async, xit_async = firmo.it_async, firmo.fit_async, firmo.xit_async
local describe_async, fdescribe_async, xdescribe_async = firmo.describe_async, firmo.fdescribe_async, firmo.xdescribe_async
local await = firmo.await
local test_helper = require("lib.tools.test_helper")

-- Compatibility function for table unpacking
---@diagnostic disable-next-line: unused-local
local unpack_table = table.unpack or unpack

describe("Async Suite and Test Functions", function()
  local execution_order = {}
  local hook_data = {}

  -- Reset state before each test in this top-level describe
  before(function()
    execution_order = {}
    hook_data = {}
  end)

  describe_async("Basic describe_async", function()
    before(function()
      hook_data.outer_before = (hook_data.outer_before or 0) + 1
      table.insert(execution_order, "outer_before")
    end)

    after(function()
      hook_data.outer_after = (hook_data.outer_after or 0) + 1
      table.insert(execution_order, "outer_after")
    end)

    it_async("should run a basic async test inside describe_async", function()
      table.insert(execution_order, "test1_start")
      await(10)
      table.insert(execution_order, "test1_end")
      expect(true).to.be_truthy()
    end)

    it("should run a basic sync test inside describe_async", function()
      table.insert(execution_order, "test2_start")
      -- no await
      table.insert(execution_order, "test2_end")
      expect(true).to.be_truthy()
    end)

    it_async("should run another async test", function()
      table.insert(execution_order, "test3_start")
      await(5)
      table.insert(execution_order, "test3_end")
    end)

    -- This test checks the execution order and hook counts *after* the suite runs.
    -- It needs to be synchronous to capture the state reliably after async tests complete.
    it("should have correct execution order and hook counts", function()
      -- Note: The exact order depends on runner implementation details (how it interleaves async tests).
      -- We primarily check that hooks run around tests and tests execute start/end.
      expect(execution_order).to.contain("outer_before")
      expect(execution_order).to.contain("outer_after")
      expect(execution_order).to.contain("test1_start")
      expect(execution_order).to.contain("test1_end")
      expect(execution_order).to.contain("test2_start")
      expect(execution_order).to.contain("test2_end")
      expect(execution_order).to.contain("test3_start")
      expect(execution_order).to.contain("test3_end")
      -- Check hook counts (should run for each of the 3 tests + this one)
      expect(hook_data.outer_before).to.equal(4)
      expect(hook_data.outer_after).to.equal(4)
    end)
  end)

  describe_async("Nested describe_async", function()
    local nested_hook_data = {}

    before(function()
      nested_hook_data.outer_before = (nested_hook_data.outer_before or 0) + 1
    end)

    after(function()
      nested_hook_data.outer_after = (nested_hook_data.outer_after or 0) + 1
    end)

    it_async("outer test", function()
      await(1)
      expect(true).to.be_truthy()
    end)

    describe_async("Inner describe_async", function()
      before(function()
        nested_hook_data.inner_before = (nested_hook_data.inner_before or 0) + 1
      end)

      after(function()
        nested_hook_data.inner_after = (nested_hook_data.inner_after or 0) + 1
      end)

      it_async("inner test 1", function()
        await(5)
        expect(true).to.be_truthy()
      end)

      it_async("inner test 2", function()
        await(5)
        expect(true).to.be_truthy()
      end)
    end)

    it("should verify hook counts for nested structure", function()
      -- Outer hook runs for outer test (1) + inner tests (2) + this test (1) = 4
      expect(nested_hook_data.outer_before).to.equal(4)
      expect(nested_hook_data.outer_after).to.equal(4)
      -- Inner hook runs only for inner tests (2)
      expect(nested_hook_data.inner_before).to.equal(2)
      expect(nested_hook_data.inner_after).to.equal(2)
    end)
  end)

  -- Focus tests (These will likely fail if run normally, meant to be run with focus enabled by runner)
  --[[ Uncomment to test focus
  fdescribe_async("Focused Async Suite (fdescribe_async)", function()
    local focused_suite_executed = false
    it_async("should run test inside focused async suite", function()
      await(1)
      focused_suite_executed = true
      expect(true).to.be_truthy()
    end)
    it("sync test inside focused async suite", function()
      focused_suite_executed = true
      expect(true).to.be_truthy()
    end)
    it("verify focused suite executed", function()
      expect(focused_suite_executed).to.be_truthy()
    end)
  end)

  describe_async("Regular suite (should be skipped in focus mode)", function()
     it_async("should not run this test in focus mode", function()
       await(1)
       error("This test should not have run in focus mode")
     end)
  end)

  describe_async("Suite with focused async test (fit_async)", function()
     local focused_test_executed = false
     it_async("regular test (should be skipped)", function()
       await(1)
       error("Regular test ran when focused test exists")
     end)

     fit_async("this focused test should run", function()
       await(5)
       focused_test_executed = true
       expect(true).to.be_truthy()
     end)

     it("verify focused test executed", function()
        expect(focused_test_executed).to.be_truthy()
     end)
  end)
  ]]

  -- Skip tests
  xdescribe_async("Skipped Async Suite (xdescribe_async)", function()
    it_async("should not run test inside skipped async suite", function()
      await(1)
      error("Test inside xdescribe_async should not run")
    end)
  end)

  describe_async("Suite with skipped async test (xit_async)", function()
    local test_ran = false
    xit_async("this test should be skipped", function()
      await(1)
      error("Skipped test (xit_async) should not run")
    end)

    it_async("this test should run", function()
      await(1)
      test_ran = true
      expect(true).to.be_truthy()
    end)

    it("verify skipped test did not run", function()
        expect(test_ran).to.be_truthy() -- Check that the other test DID run
    end)
  end)

  -- Error handling tests
  describe_async("Error Handling in Async Suites", function()
    it_async("should handle errors in async tests", { expect_error = true }, function()
      await(10)
      error("This is an expected async error")
    end)

    it("should handle errors in sync tests within async suite", { expect_error = true }, function()
      error("This is an expected sync error")
    end)

    -- Using the new test helper
    it_async("should handle expected async errors using test_helper", function()
       local failing_op = async.async(function()
         await(20)
         error("Expected failure message")
       end)
       -- Note: expect_async_error takes the original async function, not the executor
       local err = test_helper.expect_async_error(failing_op, 50, "Expected failure")
       expect(err).to.exist()
       expect(err.message).to.match("Expected failure")
    end)

    it_async("should fail if expect_async_error times out", { expect_error = true }, function()
       local slow_op = async.async(function()
         await(100) -- This will exceed the timeout below
         error("Should have timed out")
       end)
       -- Expecting this call itself to throw an error because the timeout is too short
       local _, err = test_helper.with_error_capture(function()
          test_helper.expect_async_error(slow_op, 50) -- 50ms timeout
       end)()
       expect(err).to.exist()
       expect(err.message).to.match("timed out after 50ms")
    end)

     it_async("should fail if expect_async_error's function succeeds", { expect_error = true }, function()
       local succeeding_op = async.async(function()
         await(10)
         return "Success!"
       end)
       -- Expecting this call itself to throw an error because the function succeeded
       local _, err = test_helper.with_error_capture(function()
          test_helper.expect_async_error(succeeding_op, 50)
       end)()
       expect(err).to.exist()
       expect(err.message).to.match("Async function was expected to throw an error but it completed successfully")
    end)
  end)

  -- Timeout tests
  describe_async("Timeout Handling", function()
    -- Test default timeout (assuming it's reasonably short for testing)
    -- Or configure it shorter? firmo.configure_async({ default_timeout = 100 })
    it_async("should fail if test exceeds default timeout", { expect_error = true }, function()
        await(10000) -- Assume default is less than 10s
    end, 50) -- Explicit short timeout for this test

    it_async("should pass if test completes within custom timeout", function()
        await(20)
    end, 50) -- 50ms timeout, await is 20ms

    it_async("should fail if test exceeds custom timeout", { expect_error = true }, function()
        await(100)
    end, 50) -- 50ms timeout, await is 100ms
  end)
end)

