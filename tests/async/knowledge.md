# tests/async Knowledge

## Purpose

The `tests/async/` directory contains tests dedicated to validating Firmo's asynchronous testing utilities, primarily those provided by the `lib/async` module. These tests ensure the correct behavior of defining and running asynchronous test cases (`async.it_async`), simulating delays (`async.await`), polling for conditions (`async.wait_until`), handling simulated concurrency (`async.parallel_async`), and managing timeouts within this simulated asynchronous environment.

## Key Concepts

- **Test Scope:** The tests cover the core implemented features of `lib/async`:
    - `async_test.lua`: Focuses on the main functionalities like defining async tests via `async.it_async`, using `async.await` for delays, checking conditions with `async.wait_until`, running simulated parallel operations with `async.parallel_async`, and handling expected errors within async tests.
    - `async_timeout_test.lua`: Specifically targets the timeout mechanisms, ensuring that `async.it_async`, `async.wait_until`, and `async.parallel_async` correctly respect and report timeout conditions.

- **Core Concepts Tested:**
    - **Async Context:** Tests verify that `async.it_async` establishes the necessary context allowing functions like `async.await` and `async.wait_until` to be called correctly.
    - **Simulated Delay (`async.await`):** The underlying busy-wait `sleep` function used to simulate time delays is tested for approximate accuracy.
    - **Condition Polling (`async.wait_until`):** The polling loop, condition checking frequency (`check_interval`), and timeout behavior are validated.
    - **Simulated Concurrency (`async.parallel_async`):** Tests check if multiple async operations run in the expected interleaved (round-robin) manner and if results are aggregated correctly. Error handling and timeouts within parallel operations are also tested.
    - **Timeout Enforcement:** Tests ensure that exceeding the configured default or per-test timeout correctly results in a test failure with an appropriate timeout message.

## Usage Examples / Patterns

These examples illustrate how the `lib/async` features are typically used within Firmo tests, reflecting the patterns validated by the tests in this directory.

### Pattern 1: Basic Async Test with `await`

```lua
--[[
  Define an async test using it_async and simulate a delay.
]]
local async = require("lib.async")
local expect = require("lib.assertion.expect").expect

async.it_async("should complete after a delay", function()
  local start_time = os.clock()
  async.await(50) -- Simulate a 50ms operation
  local end_time = os.clock()
  expect(end_time - start_time).to.be.near(0.05, 0.02) -- Check delay +/- tolerance
  expect(true).to.be_truthy() -- Final assertion
end)

-- Note: async.await() and async.wait_until() use a busy-wait sleep, consuming CPU.
```

### Pattern 2: Using `wait_until`

```lua
--[[
  Use wait_until to poll for a condition within an async test.
]]
local async = require("lib.async")
local expect = require("lib.assertion.expect").expect

async.it_async("should wait until a condition is met", function()
  local value = false
  -- Simulate setting the value after a delay
  local setter = async.async(function()
    async.await(30)
    value = true
  end)
  setter()() -- Start the simulated async setter

  -- Wait for 'value' to become true, with a 100ms timeout
  local success = async.wait_until(function() return value == true end, 100)

  expect(success).to.be_truthy() -- wait_until returns true if condition met
  expect(value).to.be_truthy()
end)
```

### Pattern 3: Testing Expected Errors in Async Code

```lua
--[[
  Use the options table { expect_error = true } to test async code that should fail.
]]
local async = require("lib.async")
local expect = require("lib.assertion.expect").expect

async.it_async("should handle expected errors", { expect_error = true }, function()
  local failing_op = async.async(function()
    async.await(10)
    error("Something failed inside async!")
  end)

  -- Directly execute the operation; it_async expects it to throw.
  failing_op()()

  -- If needed, use test_helper.expect_error to wrap the async call
  -- and inspect the error object, though it might be less direct.
end)
```

### Pattern 4: Custom Timeout for `it_async`

```lua
--[[
  Provide a specific timeout for an async test case.
]]
local async = require("lib.async")
local expect = require("lib.assertion.expect").expect

-- This test will run with a 200ms timeout instead of the default
async.it_async("should respect custom timeout", function()
  async.await(100) -- Simulate work less than timeout
  expect(true).to.be_truthy()
end, 200) -- Timeout in milliseconds as the last argument
```

### Pattern 5: Using `parallel_async`

```lua
--[[
  Run multiple simulated async operations concurrently.
]]
local async = require("lib.async")
local expect = require("lib.assertion.expect").expect

async.it_async("should run operations in parallel (simulated)", function()
  local op1 = async.async(function() async.await(40); return "Result 1" end)
  local op2 = async.async(function() async.await(20); return "Result 2" end)

  -- Pass the *executor* functions (result of the first call) to parallel_async
  local results = async.parallel_async({ op1(), op2() }, 100) -- 100ms overall timeout

  -- Results array preserves the original order
  expect(results).to.deep_equal({ "Result 1", "Result 2" })
end)
```

## Related Components / Modules

- **Module Under Test:** `lib/async/knowledge.md` (specifically `lib/async/init.lua`)
- **Test Files:**
    - `tests/async/async_test.lua`
    - `tests/async/async_timeout_test.lua`
- **Helper Modules:** `lib/tools/test_helper/knowledge.md` (May be used for `expect_error` if needed, though `it_async` handles expected errors directly via options).
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Use `async.it_async`:** Any test case that utilizes `async.await`, `async.wait_until`, or `async.parallel_async` **must** be defined using `async.it_async` (or potentially a function wrapped with `async.async` called within a standard `it`) to establish the correct execution context.
- **Set Realistic Timeouts:** Provide appropriate timeouts for `it_async` and `wait_until` based on the expected duration of the simulated asynchronous operations. Timeouts that are too short will cause false failures; timeouts that are too long can slow down the test suite unnecessarily.
- **Simulated Concurrency (`parallel_async`):** Remember that `parallel_async` uses a round-robin approach on a single thread. It does **not** provide true OS-level parallelism. Avoid writing tests that rely on genuine concurrent execution or that might have race conditions related to shared Lua state (which wouldn't occur in truly parallel processes).
- **Test Expected Errors:** Use the `{ expect_error = true }` option when defining an `async.it_async` test case where the asynchronous function is expected to throw an error.

## Troubleshooting / Common Pitfalls (Optional)

- **Tests Timing Out:**
    - Check the default async timeout (`config.default_timeout`) and any per-test timeouts passed to `async.it_async`.
    - Ensure the total duration of `async.await` calls and `async.wait_until` polling within a test does not exceed the timeout.
    - The busy-wait nature of `await`/`wait_until` means system load can slightly affect actual elapsed time; allow some margin in timeouts.
- **`await`/`wait_until` Error: "...can only be called within an async test"**: This error occurs if `async.await` or `async.wait_until` is called outside the special context set up by `async.it_async` or a function wrapped by `async.async`. Ensure these functions are used only inside appropriately defined async tests or functions.
- **`parallel_async` Issues:**
    - Errors thrown by one of the functions passed to `parallel_async` will cause `parallel_async` itself to error.
    - Unexpected results might occur if the functions passed share mutable Lua state (upvalues, global variables) due to the interleaved execution.
- **Unimplemented Promise/Scheduler Functions:** Do not attempt to use functions like `defer`, `poll`, `all`, `race`, `catch`, `finally`, `scheduler`, `cancel`, `timeout` (the function, not the option) mentioned as placeholders in `lib/async/init.lua`. They lack functional implementation.
