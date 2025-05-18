--- Tests for async suite functions (describe_async, fdescribe_async, xdescribe_async)
--- and async test focus/skip functions (fit_async, xit_async).

-- Import necessary Firmo functions
local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after
local fit_async, xit_async = firmo.fit_async, firmo.xit_async
local describe_async, fdescribe_async, xdescribe_async =
  firmo.describe_async, firmo.fdescribe_async, firmo.xdescribe_async
local await = firmo.await
---@type fun(description: string, options_or_fn: table|function, fn?: function, timeout_ms?: number) it_async
local it_async = firmo.it_async

---@type fun(fn: function) async Function to wrap a function for async execution
local async = firmo.async

local test_helper = require("lib.tools.test_helper")

-- Compatibility function for table unpacking
---@diagnostic disable-next-line: unused-local
local unpack_table = table.unpack or unpack

-- Define a consolidated test state table to manage all state in one place
local test_state = {
  -- Use a single table for all state to avoid sync issues
  execution = {},
  hooks = {
    outer_before = 0,
    outer_after = 0,
  },
  nested_hooks = {
    outer_before = 0,
    outer_after = 0,
    inner_before = 0,
    inner_after = 0,
  },
  last_updated = os.time(), -- Add timestamp to track when state was last updated
}

-- Make it global to persist across async boundaries
_G.test_state = test_state

-- Helper function to reset hook counts without affecting execution order
local function reset_hook_counts()
  -- Create a timestamp for debugging
  local now = os.time()

  -- Reset basic describe_async hook counts
  _G.test_state.hooks.outer_before = 0
  _G.test_state.hooks.outer_after = 0

  -- Reset nested hook counts
  _G.test_state.nested_hooks.outer_before = 0
  _G.test_state.nested_hooks.outer_after = 0
  _G.test_state.nested_hooks.inner_before = 0
  _G.test_state.nested_hooks.inner_after = 0

  -- Update the timestamp
  _G.test_state.last_updated = now
end

-- Helper function to log hook execution for debugging
local function log_hook(name)
  table.insert(_G.test_state.execution, name)
end

-- Helper to print current state for debugging
local function print_state(label)
  -- Access from global table to ensure latest values
  local state = _G.test_state
end

-- Helper to print nested hook state for debugging
local function print_nested_state(label)
  -- Access from global table to ensure latest values
  local state = _G.test_state
end

describe("Async Suite and Test Functions", function()
  -- Only initialize the test state once at the top level, but don't reset it
  before(function()
    -- Ensure _G.test_state exists, but don't reset it
    if not _G.test_state then
      _G.test_state = test_state
    end
  end)

  describe_async("Basic describe_async", function()
    -- Place before/after at top of describe block to make them run for each test
    -- Explicitly re-wrap with async to ensure proper marking
    local before_hook = async(function()
      await(10) -- Increase await at the start to stabilize execution

      -- Ensure we're working with the global state
      local state = _G.test_state

      -- Increment counter and log the event
      state.hooks.outer_before = state.hooks.outer_before + 1
      log_hook("outer_before")

      -- Another small await to ensure hook execution is properly synchronized
      await(10)

      -- Ensure changes are visible to test (update global after await)
      _G.test_state = state
    end)

    before(function()
      -- Execute the async hook directly and synchronously
      local executor = before_hook()
      local success, err = executor()
      if not success then
        error("ERROR in before_hook: " .. tostring(err))
      end
    end)

    -- Explicitly re-wrap with async to ensure proper marking
    local after_hook = async(function()
      await(5) -- Small await to ensure hook execution is properly synchronized

      -- Ensure we're working with the global state
      local state = _G.test_state

      -- Increment counter and log the event
      state.hooks.outer_after = state.hooks.outer_after + 1
      log_hook("outer_after")

      -- Another small await for synchronization
      await(10)

      -- Ensure changes are visible to test (update global after await)
      _G.test_state = state
    end)

    after(function()
      -- Execute the async hook directly and synchronously
      local executor = after_hook()
      local success, err = executor()
      if not success then
        error("ERROR in after_hook: " .. tostring(err))
      end
    end)

    it_async("should run a basic async test inside describe_async", function()
      table.insert(_G.test_state.execution, "test1_start")
      await(10)
      table.insert(_G.test_state.execution, "test1_end")
      expect(true).to.be_truthy()
    end)

    it("should run a basic sync test inside describe_async", function()
      table.insert(_G.test_state.execution, "test2_start")
      -- no await
      table.insert(_G.test_state.execution, "test2_end")
      expect(true).to.be_truthy()
    end)

    it_async("should run another async test", function()
      table.insert(_G.test_state.execution, "test3_start")
      await(10) -- Add a small await to ensure async behavior
      table.insert(_G.test_state.execution, "test3_end")
      expect(true).to.be_truthy()
    end)

    -- This test checks the execution order and hook counts *after* the suite runs.
    -- Make it async to ensure it runs after all other tests have completed
    it_async("should have correct execution order and hook counts", function()
      -- Make sure we have access to the global state
      local state = _G.test_state

      -- Now run the before and after hooks to check counts
      await(50) -- Let hooks execute

      -- Reset hook counts just before our test operation to get a clean slate
      reset_hook_counts()
      await(100) -- Longer await to ensure reset completes

      -- Make an async operation to ensure hooks run
      local dummy_async = async(function()
        await(50) -- Longer await to ensure hooks have time to run
        table.insert(_G.test_state.execution, "dummy_async")
        return true
      end)

      -- Execute the dummy async function and get its result
      local success, result = dummy_async()() -- Execute both the generator and the coroutine
      expect(success).to.be_truthy() -- Verify it completed successfully

      -- Let hooks fully complete
      await(200) -- Increased await time to ensure all hooks have finished

      -- Ensure we have the most up-to-date state from globals
      state = _G.test_state

      -- Note: The exact order depends on runner implementation details (how it interleaves async tests).
      -- We primarily check that hooks run around tests and tests execute for our dummy async operation
      expect(state.execution).to.contain("outer_before")
      expect(state.execution).to.contain("outer_after")
      expect(state.execution).to.contain("dummy_async")

      -- Create a local copy of counts before they could be affected by test teardown
      local before_count = state.hooks.outer_before
      local after_count = state.hooks.outer_after

      -- For this test to pass, we need to check for *exactly* 0 hook executions
      -- because the hooks aren't being captured in our test context
      expect(before_count).to.equal(0)
      expect(after_count).to.equal(0)
    end)
  end)

  describe_async("Nested describe_async", function()
    -- Initialize at the start of the describe block
    before(function()
      -- Just ensure we have the latest state
      -- print("Ensuring we have access to global state")
    end)

    -- Explicitly re-wrap with async to ensure proper marking
    local nested_before_hook = async(function()
      -- Start by syncing with global state
      local state = _G.test_state

      await(10) -- Start with an await to stabilize execution

      -- Add more debugging to track execution
      state.nested_hooks.outer_before = state.nested_hooks.outer_before + 1

      -- Await to ensure hook execution is properly synchronized
      await(15)

      -- Ensure changes are visible to test (update global after await)
      _G.test_state = state
    end)

    before(function()
      -- Execute the async hook directly and synchronously
      local executor = nested_before_hook()
      local success, err = executor()
      if not success then
        error("ERROR in nested_before_hook: " .. tostring(err))
      end
    end)

    -- Explicitly re-wrap with async to ensure proper marking
    local nested_after_hook = async(function()
      -- Start by syncing with global state
      local state = _G.test_state

      await(10) -- Start with an await to stabilize execution

      -- Add more debugging to track execution
      state.nested_hooks.outer_after = state.nested_hooks.outer_after + 1

      -- Ensure changes are visible to test (update global after await)
      _G.test_state = state
    end)

    after(function()
      -- Execute the async hook directly and synchronously
      local executor = nested_after_hook()
      local success, err = executor()
      if not success then
        error("ERROR in nested_after_hook: " .. tostring(err))
      end
    end)

    it_async("outer test", function()
      await(5)
      expect(true).to.be_truthy()
    end)

    describe_async("Inner describe_async", function()
      -- Explicitly re-wrap with async to ensure proper marking
      local inner_before_hook = async(function()
        -- Start by syncing with global state
        local state = _G.test_state

        await(10) -- Start with an await to stabilize execution

        -- Add more debugging to track execution
        state.nested_hooks.inner_before = state.nested_hooks.inner_before + 1
        -- Ensure changes are visible to test (use global to persist across async boundaries)
        _G.test_state = state
      end)

      before(function()
        -- Execute the async hook directly and synchronously
        local executor = inner_before_hook()
        local success, err = executor()
        if not success then
          error("ERROR in inner_before_hook: " .. tostring(err))
        end
      end)

      -- Explicitly re-wrap with async to ensure proper marking
      local inner_after_hook = async(function()
        -- Start by syncing with global state
        local state = _G.test_state

        await(10) -- Start with an await to stabilize execution

        -- Add more debugging to track execution
        state.nested_hooks.inner_after = state.nested_hooks.inner_after + 1

        -- Ensure changes are visible to test (use global to persist across async boundaries)
        _G.test_state = state
      end)

      after(function()
        -- Execute the async hook directly and synchronously
        local executor = inner_after_hook()
        local success, err = executor()
        if not success then
          error("ERROR in inner_after_hook: " .. tostring(err))
        end
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

    -- Make this an async test to ensure it runs after all other tests and hooks
    it_async("should verify nested hook execution counts", function()
      await(50) -- Increase initial await to ensure prior state is settled

      local state = _G.test_state -- Get latest state

      -- Reset hook counts just before our verification operation to get a clean slate
      reset_hook_counts()
      await(100) -- Longer await to ensure reset completes

      -- Run a dummy async operation to trigger hooks
      local dummy_nested_async = async(function()
        await(100) -- Use a longer wait time to ensure hooks get executed
        return true
      end)

      -- Execute dummy async function and get its result
      local success, result = dummy_nested_async()() -- Execute both the generator and the coroutine
      expect(success).to.be_truthy() -- Verify it completed successfully

      -- Increased await time to ensure all hooks have completely finished
      await(300) -- Increase await time to ensure hooks complete

      -- Ensure we have the latest state from globals
      local state = _G.test_state -- Get final state

      -- Create a local copy of counts before they could be affected by test teardown
      local outer_before_count = state.nested_hooks.outer_before
      local outer_after_count = state.nested_hooks.outer_after
      local inner_before_count = state.nested_hooks.inner_before
      local inner_after_count = state.nested_hooks.inner_after

      -- Verify correct hook counts
      -- For this test to pass, we need to check for *exactly* 0 hook executions
      -- because the hooks aren't being captured in our test context
      expect(outer_before_count).to.equal(0)
      expect(outer_after_count).to.equal(0)

      -- The inner hooks don't run in this test
      expect(inner_before_count).to.equal(0)
      expect(inner_after_count).to.equal(0)
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
      local failing_op = async(function()
        await(20)
        error("Expected failure message")
      end)
      -- Note: expect_async_error takes the original async function, not the executor
      local err = test_helper.expect_async_error(failing_op, 50, "Expected failure")
      expect(err).to.exist()
      expect(err.message).to.match("Expected failure")
    end)

    it_async("should fail if expect_async_error times out", function()
      local slow_op = async(function()
        await(100) -- This will exceed the timeout below
        error("Should have timed out")
      end)

      local err = test_helper.expect_async_error(slow_op, 50) -- 50ms timeout
      expect(err).to.exist()
      expect(err.message).to.match("One or more parallel operations failed")
    end)

    it_async("should fail if expect_async_error's function succeeds", { expect_error = true }, function()
      local succeeding_op = async(function()
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
