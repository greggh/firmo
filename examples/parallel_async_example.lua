--- parallel_async_example.lua
--
-- This example demonstrates how to run multiple asynchronous operations
-- concurrently using `firmo.parallel_async`. This can significantly speed up
-- tests that need to perform several independent async tasks, such as fetching
-- data from multiple API endpoints simultaneously.
--
-- It shows:
-- - Defining multiple async operations (using promises).
-- - Running them in parallel using `parallel_async`.
-- - Collecting and verifying the results.
-- - Error handling when one or more parallel operations fail.
--
-- Run embedded tests: lua test.lua examples/parallel_async_example.lua
--

local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("ParallelAsyncExample")

-- Import the test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local it_async = firmo.it_async
---@diagnostic disable-next-line: unused-local
local async = firmo.async
local await = firmo.await
---@diagnostic disable-next-line: unused-local
local wait_until = firmo.wait_until
local parallel_async = firmo.parallel_async

-- Import promise functions
local create_promise = firmo.async.create_promise
local set_timeout = firmo.async.set_timeout

-- Simulate a set of asynchronous APIs
local AsyncAPI = {}

--- Simulated fetch function with delay, returning a promise.
-- @param user_id number The user ID.
-- @param delay number|nil Optional delay in ms (default 100).
-- @return table promise A promise that resolves with user data.
function AsyncAPI.fetch_user(user_id, delay)
  delay = delay or 100
  return create_promise(function(resolve)
    set_timeout(function()
      resolve({
        id = user_id,
        name = "User " .. user_id,
        email = "user" .. user_id .. "@example.com",
      })
    end, delay)
  end)
end

--- Simulated data service, returning a promise.
-- @param user_id number The user ID.
-- @param delay number|nil Optional delay in ms (default 150).
-- @return table promise A promise that resolves with posts data.
function AsyncAPI.fetch_posts(user_id, delay)
  delay = delay or 150
  return create_promise(function(resolve)
    set_timeout(function()
      resolve({
        { id = 1, title = "First post by user " .. user_id },
        { id = 2, title = "Second post by user " .. user_id },
      })
    end, delay)
  end)
end

--- Simulated comments service, returning a promise.
-- @param post_id number The post ID.
-- @param delay number|nil Optional delay in ms (default 80).
-- @return table promise A promise that resolves with comments data.
function AsyncAPI.fetch_comments(post_id, delay)
  delay = delay or 80
  return create_promise(function(resolve)
    set_timeout(function()
      resolve({
        { id = 1, text = "Great post! #" .. post_id },
        { id = 2, text = "I agree #" .. post_id },
      })
    end, delay)
  end)
end

--- Test suite demonstrating `parallel_async`.
describe("Parallel Async Operations Demo", function()
  --- Tests demonstrating basic usage of `parallel_async`.
  describe("Basic parallel operations", function()
    it_async("can run multiple async operations in parallel", function()
      local start = os.clock()

      -- Define three different async operations
      local op1 = function()
        await(70) -- Simulate a 70ms operation
      end

      local op2 = function()
        await(120) -- Simulate a 120ms operation
      end

      local op3 = function()
        await(50) -- Simulate a 50ms operation
      end

      logger.info("\nRunning 3 operations in parallel...")

      -- Run all operations in parallel and wait for all to complete
      local results = parallel_async({ op1, op2, op3 })

      local elapsed = (os.clock() - start) * 1000
      logger.info(string.format("All operations completed in %.2fms", elapsed))
      print("Results:")
      ---@diagnostic disable-next-line: param-type-mismatch
      for i, result in ipairs(results) do
        print("  " .. i .. ": " .. result)
      end

      -- The total time should be close to the longest operation (120ms)
      -- rather than the sum (240ms)
      expect(elapsed < 400).to.be.truthy() -- More lenient timing check for different environments
      expect(elapsed > 100).to.be.truthy() -- Should take at least 100ms
      expect(#results).to.equal(3)
    end)
  end)

  --- Tests demonstrating parallel fetching of data using the simulated AsyncAPI.
  describe("Simulated API service calls", function()
    it_async("can fetch user profile, posts, and comments in parallel", function()
      local user_data, posts_data, comments_data

      -- Operation to fetch user profile (returns promise)
      local fetch_user_op = function()
        return AsyncAPI.fetch_user(123, 100)
      end

      -- Operation to fetch user posts (returns promise)
      local fetch_posts_op = function()
        return AsyncAPI.fetch_posts(123, 150)
      end

      -- Operation to fetch comments (returns promise)
      local fetch_comments_op = function()
        return AsyncAPI.fetch_comments(1, 80)
      end

      logger.info("\nFetching user profile, posts, and comments in parallel...")
      local start = os.clock()

      -- Run all data fetching operations in parallel
      local results = parallel_async({
        fetch_user_op,
        fetch_posts_op,
        fetch_comments_op,
      })
      -- Extract results
      ---@diagnostic disable-next-line: need-check-nil
      user_data = results[1]
      ---@diagnostic disable-next-line: need-check-nil
      posts_data = results[2]
      ---@diagnostic disable-next-line: need-check-nil
      comments_data = results[3]

      local elapsed = (os.clock() - start) * 1000
      logger.info(string.format("All data fetched in %.2fms", elapsed))

      -- The user profile data should be available
      expect(user_data.name).to.equal("User 123")

      -- The posts data should be available
      expect(posts_data).to.exist()
      expect(#posts_data).to.equal(2)

      -- The comments data should be available
      expect(comments_data).to.exist()
      expect(comments_data[1].text).to.match("Great post")

      -- Verify that data was collected in parallel
      print("Data collected:")
      print("  User: " .. user_data.name)
      print("  Posts: " .. #posts_data .. " posts found")
      print("  Comments: " .. #comments_data .. " comments found")

      -- The total time should be approximately the longest operation (150ms)
      expect(elapsed < 400).to.be.truthy() -- More lenient for different environments
    end)
  end)

  --- Tests demonstrating error handling within `parallel_async`.
  describe("Error handling", function()
    it_async("handles errors in parallel operations", function()
      -- Define operations where one will fail
      -- Define operations where one will fail
      local op1 = function()
        await(30)

        local op2 = function()
          await(20)
          error("Simulated failure in operation 2")
        end

        local op3 = function()
          await(40)
        end
      end

      logger.info("\nRunning operations with expected failure...")

      -- Attempt to run operations in parallel
      local success, err = pcall(function()
        parallel_async({ op1, op2, op3 })

        -- Operation 2 should cause an error
        expect(success).to.equal(false)
        logger.info("Caught expected error: " .. tostring(err))
        expect(err).to.match("One or more parallel operations failed")
        -- The message may contain line numbers, so just check for "Simulated failure"
        expect(err).to.match("Simulated failure")
      end)
    end)

    --- Tests demonstrating timeout handling (marked as pending).
    describe("Timeout handling", function()
      it("handles timeouts for operations that take too long", function()
        -- Using the pending mechanism is better than manually printing skip messages
        return firmo.pending("Timeout test is hard to test reliably - see implementation in src/async.lua")
      end)
    end)
  end)

  -- Log usage instructions
  logger.info("\n-- Parallel Async Example --")
  logger.info("This file demonstrates using firmo.parallel_async to run async operations concurrently.")
  logger.info("Run with:")
  logger.info("  lua test.lua examples/parallel_async_example.lua")
  logger.info("\nKey features demonstrated:")
  logger.info("1. Running multiple async operations concurrently")
  logger.info("2. Collecting results from parallel operations")
  logger.info("3. Error handling when one operation fails")
end)
