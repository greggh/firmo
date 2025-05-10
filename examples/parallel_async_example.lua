--- This example demonstrates how to run multiple asynchronous operations
--- concurrently using `firmo.parallel_async`. This can significantly speed up
-- tests that need to perform several independent async tasks, such as fetching
-- data from multiple API endpoints simultaneously.
--
-- It shows:
-- - Defining multiple async operations (using promises).
-- - Running them in parallel using `parallel_async`.
-- - Collecting and verifying the results.
-- - Error handling when one or more parallel operations fail.
--
-- @module examples.parallel_async_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see firmo.parallel_async
-- @see firmo.async
-- @usage
-- Run embedded tests: lua firmo.lua examples/parallel_async_example.lua
--

local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("ParallelAsyncExample")

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
local it_async = firmo.it_async
local await = firmo.await
local wait_until = firmo.wait_until
local parallel_async = firmo.parallel_async -- Correct way to access parallel_async

-- Compatibility function for table unpacking
local unpack_table = table.unpack or unpack

--- Simulate a set of asynchronous APIs that return promises.
--- @class AsyncAPI
--- @field fetch_user fun(user_id: number, delay?: number): table Returns a promise resolving to user data.
--- @field fetch_posts fun(user_id: number, delay?: number): table Returns a promise resolving to posts data.
--- @field fetch_comments fun(post_id: number, delay?: number): table Returns a promise resolving to comments data.
--- @within examples.parallel_async_example
local AsyncAPI = {}

--- Simulated fetch function with delay, returning an async function.
--- @param user_id number The user ID.
--- @param delay? number Optional delay in ms (default 100).
--- @return function An async function that returns user data `{ id, name, email }`.
function AsyncAPI.fetch_user(user_id, delay)
  delay = delay or 100
  return firmo.async(function()
    await(delay)
    return {
      id = user_id,
      name = "User " .. user_id,
      email = "user" .. user_id .. "@example.com",
    }
  end)()
end

--- Simulated data service, returning an async function that resolves with user posts.
--- @param user_id number The user ID.
--- @param delay? number Optional delay in ms (default 150).
--- @return function An async function that returns an array of post tables `{ id, title }`.
function AsyncAPI.fetch_posts(user_id, delay)
  delay = delay or 150
  return firmo.async(function()
    await(delay)
    return {
      { id = 1, title = "First post by user " .. user_id },
      { id = 2, title = "Second post by user " .. user_id },
    }
  end)()
end

--- Simulated comments service, returning an async function that resolves with comments for a post.
--- @param post_id number The post ID.
--- @param delay? number Optional delay in ms (default 80).
--- @return function An async function that returns an array of comment tables `{ id, text }`.
function AsyncAPI.fetch_comments(post_id, delay)
  delay = delay or 80
  return firmo.async(function()
    await(delay)
    return {
      { id = 1, text = "Great post! #" .. post_id },
      { id = 2, text = "I agree #" .. post_id },
    }
  end)()
end

--- Test suite demonstrating `parallel_async`.
--- @within examples.parallel_async_example
describe("Parallel Async Operations Demo", function()
  --- Tests demonstrating basic usage of `parallel_async` with simple `await` calls.
  --- @within examples.parallel_async_example
  describe("Basic parallel operations", function()
    --- Tests running three simple `await` operations concurrently.
    it_async("can run multiple simple async operations in parallel", function()
      local start = os.clock()

      -- Define three different async operations, properly wrapped with firmo.async
      local op1 = firmo.async(function()
        await(70) -- Simulate a 70ms operation
        return "op1 complete"
      end)()

      local op2 = firmo.async(function()
        await(120) -- Simulate a 120ms operation
        return "op2 complete"
      end)()

      local op3 = firmo.async(function()
        await(50) -- Simulate a 50ms operation
        return "op3 complete"
      end)()

      logger.info("Running 3 operations in parallel...")

      -- Run all operations in parallel and wait for all to complete
      local results = parallel_async({ op1, op2, op3 })

      local elapsed = (os.clock() - start) * 1000
      logger.info(string.format("All operations completed in %.2fms", elapsed))
      print("Results:")
      ---@diagnostic disable-next-line: param-type-mismatch
      for i, result in ipairs(results) do
        -- Simple await calls return nil upon completion
        print(string.format("  Operation %d result: %s", i, tostring(result)))
      end

      -- The total time should be close to the longest operation (120ms)
      -- rather than the sum (70 + 120 + 50 = 240ms)
      expect(elapsed).to.be_less_than(200) -- Allow some overhead, should be around 120ms
      expect(elapsed).to.be.at_least(115) -- Should take at least the longest op time
      expect(#results).to.equal(3)
    end)
  end)

  --- Tests demonstrating parallel fetching of data using the simulated AsyncAPI.
  --- @within examples.parallel_async_example
  describe("Simulated API service calls", function()
    --- Tests fetching multiple pieces of related data concurrently.
    it_async("can fetch user profile, posts, and comments in parallel", function()
      local user_data, posts_data, comments_data

      -- Operation to fetch user profile (returns async function)
      local fetch_user_op = AsyncAPI.fetch_user(123, 100)

      -- Operation to fetch user posts (returns async function)
      local fetch_posts_op = AsyncAPI.fetch_posts(123, 150)

      -- Operation to fetch comments (returns async function)
      local fetch_comments_op = AsyncAPI.fetch_comments(1, 80)

      logger.info("Fetching user profile, posts, and comments in parallel...")
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
      expect(elapsed).to.be_less_than(250) -- Allow overhead, longest is 150ms
      expect(elapsed).to.be.at_least(145)
    end)
  end)

  --- Tests demonstrating error handling within `parallel_async`.
  --- @within examples.parallel_async_example
  describe("Error handling", function()
    --- Tests that `parallel_async` throws an error if any of the parallel operations fail.
    it_async("throws an error if any parallel operation fails", function()
      local op1 = firmo.async(function()
        await(30)
        return "Op1 Success"
      end)()

      local op2 = firmo.async(function()
        await(20)
        error("Simulated failure in operation 2") -- This operation will throw an error
      end)()

      local op3 = firmo.async(function()
        await(40)
        return "Op3 Success"
      end)()

      logger.info("Running operations with expected failure...")

      -- Attempt to run operations in parallel using pcall to catch the expected error
      local success, err = pcall(function()
        return parallel_async({ op1, op2, op3 })
      end)

      -- Verify that pcall caught an error
      expect(success).to.be_falsy("pcall should return false when an operation errors")
      expect(err).to.exist("An error message should be returned")
      expect(type(err)).to.equal("string") -- pcall returns error message as string

      -- Check the error message content
      -- Note: The exact error message might vary depending on the async implementation details.
      -- It should ideally indicate which operation failed and why.
      logger.info("Caught expected error from parallel_async: " .. err)
      expect(err).to.match("Simulated failure in operation 2") -- Specific error from op2
    end)
  end)

  --- Tests demonstrating timeout handling (marked as pending).
  describe("Timeout handling", function()
    it("handles timeouts for operations that take too long", function()
      -- Using the pending mechanism is better than manually printing skip messages
      return firmo.pending("Timeout test is hard to test reliably - see implementation in src/async.lua")
    end)
  end)

  -- Log usage instructions
  logger.info("-- Parallel Async Example --")
  logger.info("This file demonstrates using firmo.parallel_async to run async operations concurrently.")
  logger.info("Run with:")
  logger.info("  lua firmo.lua examples/parallel_async_example.lua")
  logger.info("Key features demonstrated:")
  logger.info("1. Running multiple async operations concurrently")
  logger.info("2. Collecting results from parallel operations")
  logger.info("3. Error handling when one operation fails")
end)
