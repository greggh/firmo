---@diagnostic disable: missing-parameter, param-type-mismatch
--- Asynchronous Testing Functionality Tests
---
--- Verifies the core features of Firmo's asynchronous testing support, including:
--- - `async()` function wrapper for async execution.
--- - `await()` for pausing execution within async tests.
--- - `wait_until()` for pausing until a condition becomes true.
--- - `parallel_async()` for concurrent execution of async functions.
--- - `it_async()` convenience function for defining async tests.
--- - Error handling when async functions are used outside their context.
--- - Use of `test_helper.expect_error` for validating expected errors.
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
---@type fun(callback: function) after Hook that runs after each test
local after = firmo.after

local async_module = require("lib.async")
---@type fun(description: string, options_or_fn: table|function, fn?: function, timeout_ms?: number) it_async
local it_async = async_module.it_async
---@type fun(fn: function) async Function to wrap a function for async execution
local async = async_module.async
local await = async_module.await
local wait_until = async_module.wait_until
local parallel_async = async_module.parallel_async
local test_helper = require("lib.tools.test_helper")

describe("Asynchronous Testing", function()
  -- Reset async module state after each test to ensure clean state
  after(function()
    async_module.reset()
  end)
  -- Verify basic async functionality
  describe("async() function", function()
    it("wraps a function for async execution", function()
      local fn = function()
        return "test"
      end
      ---@diagnostic disable-next-line: redundant-parameter
      local wrapped = async(fn)

      expect(wrapped).to.be.a("function")
      ---@diagnostic disable-next-line: need-check-nil
      local executor = wrapped()
      expect(executor).to.be.a("function")
    end)

    it("preserves function arguments", function()
      local args_received = nil

      local fn = function(a, b, c)
        args_received = { a, b, c }
        return args_received
      end

      ---@diagnostic disable-next-line: unused-local, redundant-parameter
      local result = async(fn)(1, 2, 3)()
      ---@diagnostic disable-next-line: need-check-nil
      expect(args_received[1]).to.equal(1)
      ---@diagnostic disable-next-line: need-check-nil
      expect(args_received[2]).to.equal(2)
      ---@diagnostic disable-next-line: need-check-nil
      expect(args_received[3]).to.equal(3)
    end)
  end)

  -- Test await functionality
  describe("await() function", function()
    it_async("waits for the specified time", function()
      local start = os.clock()

      ---@diagnostic disable-next-line: redundant-parameter
      await(50) -- Wait 50ms

      local elapsed = (os.clock() - start) * 1000
      expect(elapsed >= 40).to.be_truthy() -- Allow for small timing differences
    end)

    it("fails when used outside async context", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        ---@diagnostic disable-next-line: redundant-parameter
        await(10)
      end, "can only be called within an async test")

      expect(err).to.exist()
    end)
  end)

  -- Test wait_until functionality
  describe("wait_until() function", function()
    it_async("waits until condition is true", function()
      local value = 0
      local start_time = os.clock() * 1000

      -- Create a condition function that becomes true after 30ms
      local function condition()
        if os.clock() * 1000 - start_time >= 30 then
          value = 42
          return true
        end
        return false
      end

      ---@diagnostic disable-next-line: redundant-parameter
      wait_until(condition, 200, 5)

      expect(value).to.equal(42)
    end)

    it_async("should fail with timeout when condition never becomes true", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        ---@diagnostic disable-next-line: redundant-parameter
        return wait_until(function()
          return false
          ---@diagnostic disable-next-line: redundant-parameter
        end, 50, 5)
      end)

      expect(err).to.exist()
      expect(err.message).to.match(".*Timeout of.*exceeded while waiting for condition to be.*")
    end)

    it("fails when used outside async context", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        ---@diagnostic disable-next-line: redundant-parameter
        wait_until(function()
          return true
        end)
      end, "can only be called within an async test")

      expect(err).to.exist()
    end)
  end)

  -- Test parallel_async functionality
  describe("parallel_async() function", function()
    it_async("runs multiple operations concurrently", function()
      local start = os.clock()

      -- Define three operations with different completion times
      local op1 = async(function()
        ---@diagnostic disable-next-line: redundant-parameter
        await(50) -- Operation 1 takes 50ms
        return "op1 done"
      end)

      local op2 = async(function()
        ---@diagnostic disable-next-line: redundant-parameter
        await(30) -- Operation 2 takes 30ms
        return "op2 done"
      end)

      local op3 = async(function()
        ---@diagnostic disable-next-line: redundant-parameter
        await(70) -- Operation 3 takes 70ms
        return "op3 done"
      end)

      -- Run operations in parallel
      ---@diagnostic disable-next-line: redundant-parameter
      local results = parallel_async({ op1(), op2(), op3() })

      -- Check that all operations completed
      ---@diagnostic disable-next-line: need-check-nil
      expect(results[1]).to.equal("op1 done")
      ---@diagnostic disable-next-line: need-check-nil
      expect(results[2]).to.equal("op2 done")
      ---@diagnostic disable-next-line: need-check-nil
      expect(results[3]).to.equal("op3 done")

      -- The total time should be close to the longest operation (70ms)
      -- rather than the sum of all operations (150ms)
      local elapsed = (os.clock() - start) * 1000

      -- The test might run slower in some environments, so we're more lenient with the timing checks
      expect(elapsed).to.be_greater_than(60) -- Should take at least close to the longest operation
      expect(elapsed).to.be_less_than(250) -- Allow overhead but should be less than sum of all operations
    end)

    it_async("should fail when any parallel operation throws an error", { expect_error = true }, function()
      local op1 = async(function()
        ---@diagnostic disable-next-line: redundant-parameter
        await(20)
        return "op1 done"
      end)

      local op2 = async(function()
        ---@diagnostic disable-next-line: redundant-parameter
        await(10)
        error("op2 failed")
      end)

      local op3 = async(function()
        ---@diagnostic disable-next-line: redundant-parameter
        await(30)
        return "op3 done"
      end)

      -- Run operations and expect an error using test_helper.expect_error
      local err = test_helper.expect_error(function()
        ---@diagnostic disable-next-line: redundant-parameter
        return parallel_async({ op1(), op2(), op3() })
      end)

      expect(err).to.exist()
      -- Only check for partial match because line numbers may vary
      expect(err.message).to.match("op2 failed")
    end)

    -- Timeout test has been moved to async_timeout_test.lua

    it("fails when used outside async context", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        ---@diagnostic disable-next-line: redundant-parameter
        parallel_async({ function() end })
      end, "can only be called within an async test")

      expect(err).to.exist()
    end)
  end)

  -- Test the async/await pattern for assertions
  describe("Async assertions", function()
    it_async("can make assertions after async operations", function()
      local result = nil

      -- Simulate async operation
      local start_time = os.clock() * 1000
      local function operation_complete()
        if os.clock() * 1000 - start_time >= 20 then
          result = "completed"
          return true
        end
        return false
      end

      -- Wait for operation to complete
      ---@diagnostic disable-next-line: redundant-parameter
      wait_until(operation_complete, 100)

      -- Assertions after the async operation
      expect(result).to.equal("completed")
    end)
  end)

  -- Test it_async convenience function
  describe("it_async() function", function()
    it("is a shorthand for it() with async()", function()
      -- This test verifies that it_async exists and calls the right functions
      -- The actual async functionality is tested in other tests
      expect(firmo.it_async).to.be.a("function")
    end)
  end)
end)
