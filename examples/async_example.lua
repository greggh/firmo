--- async_example.lua
--
-- This example demonstrates Firmo's asynchronous testing capabilities, including:
-- - Defining async tests using `it_async()` and `async()`.
-- - Waiting for delays or operations using `await()`.
-- - Waiting for conditions using `wait_until()`.
-- - Testing functions that return promises.
-- - Handling timeouts in async tests.
--

---@diagnostic disable: undefined-global
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect -- Ensure this is present
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local async_utils = require("lib.async") -- Use correct import path
-- Setup logger
local logger = logging.get_logger("AsyncExample")
local it_async = firmo.it_async
-- local async = firmo.async -- Remove this, potential conflict
local await = firmo.await
local wait_until = firmo.wait_until
--- Simulate an asynchronous API using promises.
local AsyncAPI = {}
--- Simulate a delayed API response using a promise.
-- Resolves with mock data after the specified delay.
-- @param delay number|nil The delay in milliseconds (default: 100ms).
-- @return table A promise that resolves with the mock data.
function AsyncAPI.fetch_data(delay)
  delay = delay or 100
  return async_utils.create_promise(function(resolve)
    async_utils.set_timeout(function()
      resolve({ status = "success", data = { value = 42 } })
    end, delay)
  end)
end
--- Main test suite demonstrating Firmo's async testing features.
describe("Async Testing Demo", function()
  --- Tests for basic await() and wait_until() functionality.
  describe("Basic async/await", function()
    it_async("waits for a specified time using await(ms)", function()
      local start_time = os.clock()

      -- Wait for 100ms
      await(100)

      local elapsed = (os.clock() - start_time) * 1000
      expect(elapsed).to.exist()
      expect(elapsed).to.be_greater_than(90) -- Allow for timing variations
    end)

    it_async("can perform assertions after waiting", function()
      local value = 0

      -- Simulate an async operation that changes a value after 50ms
      await(50)
      value = 42

      -- Now we can make assertions on the updated value
      expect(value).to.equal(42)
    end)

    it_async("waits until a condition is met using wait_until", function()
      local flag = false
      local flag = false
      -- Simulate setting the flag after a delay
      async_utils.set_timeout(function()
        flag = true
      end, 75)
      -- Wait until the flag becomes true (up to 200ms timeout)
      local condition_met = wait_until(function()
        return flag
      end, 200)
      expect(condition_met).to.be_truthy() -- wait_until returns true if condition met
      expect(flag).to.equal(true)
    end)
  end)

  --- Tests simulating interaction with an asynchronous API using promises.
  describe("Simulated API testing with Promises", function()
    it_async("can await a promise from simulated API", function()
      -- Start the async operation (returns a promise)
      local data_promise = AsyncAPI.fetch_data(100)

      -- Await the promise
      local result = await(data_promise)

      -- Now we can make assertions on the resolved value
      expect(result).to.exist()
      expect(result.status).to.equal("success")
      expect(result.data).to.exist()
      expect(result.data.value).to.equal(42)
    end)

    it_async(
      "demonstrates timeout behavior with test options",
      { timeout = 50, expect_error = true }, -- Set test-specific timeout shorter than API delay
      function()
        -- Start an async operation that will take too long (100ms)
        local data_promise = AsyncAPI.fetch_data(100)

        -- Await the promise. This should fail because the test timeout (50ms)
        -- is shorter than the API delay (100ms).
        local success, err = pcall(function()
          await(data_promise)
        end)

        expect(success).to.be_falsy()
        expect(err).to.exist()
        expect(err).to.match("timeout") -- Verify the error is a timeout error
      end
    )
  end)

  --- Tests demonstrating the explicit use of `async()` wrapper for tests.
  describe("Using async() wrapper directly", function()
    it(
      "runs an async test with custom timeout",
      firmo.async(function() -- Use firmo.async explicitly if local 'async' was removed
        local start_time = os.clock()
        await(100)
        local elapsed = (os.clock() - start_time) * 1000
        expect(elapsed).to.be_greater_than(90)
      end, 1000) -- 1 second timeout for the async function itself
    )

    -- Nested async calls
    it(
      "supports nested async operations",
      firmo.async(function() -- Use firmo.async explicitly if local 'async' was removed
        local value = 0
        -- First async operation
        await(50)
        value = value + 1

        -- Second async operation
        await(50)
        value = value + 1

        -- Final assertion
        expect(value).to.equal(2)
      end)
    )
  end)
end)
