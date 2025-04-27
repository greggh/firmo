# tests/mocking Knowledge

## Purpose

The `tests/mocking/` directory contains tests that validate the functionality of Firmo's test double system, which is provided by the `lib/mocking` module. This includes tests for spies (`firmo.spy`), stubs (`firmo.stub`), and mocks (`firmo.mock`). The goal of these tests is to ensure that spies accurately record function calls, stubs correctly replace behavior, mocks properly handle expectations and verification, and all related features (like sequences and error raising) work as intended.

## Key Concepts

The tests are organized by the type of test double being validated:

- **Spies (`spy_test.lua`):** These tests verify the core functionality of spies created with `firmo.spy()`. They check if calls are correctly recorded in the `spy.calls` table, if properties like `spy.called` and `spy.call_count` are updated accurately, and if arguments passed to the spy and values returned by the original function (if wrapped) are accessible for inspection.

- **Stubs (`stub_test.lua`):** These tests focus on `firmo.stub.on(object, method)`. They ensure that stubs can successfully replace the behavior of existing functions or table methods. Tests cover various stubbing strategies:
    - `.returns(value)`: Verifying the stub consistently returns a predefined value.
    - `.raises(error_message)`: Verifying the stub throws the specified error when called.
    - `.calls_fake(implementation)`: Verifying the stub executes the provided fake function.
    - **Restoration:** Critically, these tests verify that `stub:restore()` (or `stub.restore_all()`) correctly reverts the stubbed function/method back to its original implementation, which is essential for test isolation.

- **Mocks (`mock_test.lua`):** These tests cover the more complex mock objects created via `firmo.mock.new()`. Key areas tested include:
    - Defining basic behavior using `.returns()` or `.raises()` on mock methods (e.g., `mock.method.returns(...)`).
    - Setting up specific expectations using `mock.expect("method_name")`, chaining conditions like `.with(arg1, arg2)`, `.returns(value)`, and `.times(n)`.
    - Using sequences via `firmo.mock.sequence()` to define a series of return values or errors for consecutive calls.
    - **Verification:** Ensuring that `mock:verify()` correctly checks if all defined expectations were met during the test and throws an appropriate error if any expectation failed (e.g., wrong arguments, incorrect call count).

## Usage Examples / Patterns (Illustrative Test Snippets)

### Testing a Spy

```lua
--[[
  Example test verifying spy functionality.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local spy = require("lib.mocking.spy") -- Assuming spy alias

it("should track calls made to a spy", function()
  local my_func = function(a, b) return a + b end
  local spied_func = spy.spy_on(my_func)

  expect(spied_func.called).to.be_falsey()
  expect(spied_func.call_count).to.equal(0)

  local result = spied_func(3, 4)

  expect(result).to.equal(7) -- Original function should still execute
  expect(spied_func.called).to.be_truthy()
  expect(spied_func.call_count).to.equal(1)
  expect(spied_func.calls).to.have_length(1)
  expect(spied_func.calls[1].args).to.deep_equal({3, 4})
  expect(spied_func.calls[1].returned).to.equal(7)
end)
```

### Testing a Stub

```lua
--[[
  Example test verifying stub functionality and restoration.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local stub = require("lib.mocking.stub")

local original_value = _G.my_global_func -- Store original if global
_G.my_global_func = function() return "original" end

describe("Stubbing", function()
  after_each(function()
    -- CRITICAL: Restore stubs after each test
    stub.restore_all()
    _G.my_global_func = original_value -- Restore global manually if needed
  end)

  it("should replace function behavior with .returns()", function()
    local my_stub = stub.on(_G, "my_global_func").returns("stubbed value")
    expect(_G.my_global_func()).to.equal("stubbed value")
    -- my_stub:restore() -- Alternatively, restore individually
  end)

  it("original function should be restored after test", function()
     -- Stub was restored by after_each
    expect(_G.my_global_func()).to.equal("original")
  end)
end)
```

### Testing a Mock's Behavior

```lua
--[[
  Example test verifying simple mock behavior.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock = require("lib.mocking.mock")

it("should return configured value from mock method", function()
  local my_mock = mock.new()
  my_mock.get_data.returns({ id = 1, value = "test" })

  local result = my_mock.get_data("query")

  expect(result.id).to.equal(1)
  expect(result.value).to.equal("test")
  -- Note: Without expectations, verify() doesn't do much here
end)
```

### Testing Mock Expectations and Verification

```lua
--[[
  Example test defining and verifying mock expectations.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock = require("lib.mocking.mock")
local test_helper = require("lib.tools.test_helper")

describe("Mock Verification", function()
  local my_mock

  before_each(function()
    my_mock = mock.new()
  end)

  it("should pass verification if expectation is met", function()
    my_mock.expect("process").with("data", 123).returns(true)

    local result = my_mock.process("data", 123)

    expect(result).to.be_truthy()
    my_mock:verify() -- Should pass silently
  end)

  it("should fail verification if expectation is not met", function()
    my_mock.expect("process").with("expected_data").times(1)

    -- We never call my_mock.process("expected_data")

    -- Assert that verify() throws an error
    test_helper.expect_error(function()
      my_mock:verify()
    end, "expected process.*to be called") -- Match error message
  end)
end)
```

### Testing Error Raising with Stubs/Mocks

```lua
--[[
  Example test verifying .raises() functionality.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock = require("lib.mocking.mock")
local test_helper = require("lib.tools.test_helper")

it("should raise configured error when method is called", function()
  local my_mock = mock.new()
  my_mock.connect.raises("Connection timed out")

  -- Assert that calling connect() throws the expected error
  test_helper.expect_error(function()
    my_mock.connect("db_host")
  end, "Connection timed out")
end)
```

## Related Components / Modules

- **Module Under Test:**
    - `lib/mocking/knowledge.md` (Overview)
    - `lib/mocking/stub.lua`
    - `lib/mocking/mock.lua`
    - (`lib/mocking/spy.lua` - Although integrated, source might be separate)
- **Test Files:**
    - `tests/mocking/mock_test.lua`
    - `tests/mocking/spy_test.lua`
    - `tests/mocking/stub_test.lua`
- **Helper Modules:**
    - `lib/tools/test_helper/knowledge.md`: Used via `expect_error` to verify expected failures (e.g., from `mock:verify()` or `.raises()`).
- **Assertions:**
    - `lib/assertion/knowledge.md`: `expect()` is used extensively to assert spy call counts, arguments, return values from stubs/mocks.
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Choose Appropriate Test Double:** Use `spy` for observing calls without changing behavior, `stub` for simple behavior replacement (returning values, raising errors), and `mock` when you need to verify specific interactions (method called with specific arguments, specific number of times).
- **Keep Test Doubles Simple:** Configure only the minimal behavior required for the test case. Avoid overly complex setups in stubs or mocks.
- **CRITICAL: Restore Stubs:** Always restore functions or methods modified by `firmo.stub.on()` using `stub:restore()` or `stub.restore_all()` after each test, typically in an `after_each` block. Failure to do so will cause state leakage and interfere with subsequent tests.
- **Verify Mock Expectations:** When using `mock.expect()`, always call `mock:verify()` at the end of the `it` block to ensure the defined interactions actually occurred.
- **Isolate Tests:** Ensure tests using mocks/stubs do not interfere with each other, primarily through proper restoration.

## Troubleshooting / Common Pitfalls (Optional)

- **Verification Failures (`mock:verify()` error):**
    - **Cause:** An expectation defined with `mock.expect()` was not met (e.g., method called with wrong arguments, called an incorrect number of times, or not called at all).
    - **Debugging:** Carefully examine the error message from `verify()`, which usually details the expected vs. actual interaction. Review the test code that interacts with the mock and compare it against the expectation setup.
- **Incorrect Stub/Mock Behavior:**
    - **Cause:** The `.returns()`, `.raises()`, or `.calls_fake()` configuration might be incorrect, or multiple stubs might be conflicting.
    - **Debugging:** Double-check the setup chain for the stub/mock method. Add logging before calling the mocked method to confirm its state. Ensure no previous, unrestored stub is interfering.
- **State Leakage / Test Interference:**
    - **Symptom:** Tests pass individually but fail when run together; test failures seem random or dependent on order.
    - **Cause:** Almost always due to forgetting to call `stub.restore()` or `stub.restore_all()` in an `after_each` block, leaving a function/method globally replaced.
    - **Solution:** Ensure all tests that use `firmo.stub.on()` have a corresponding `after_each(stub.restore_all)` (or individual `stub:restore()`).
- **Confusion Between Spy/Stub/Mock:** Using the wrong type of test double can make tests harder to write or understand. If just checking if a function was called, use a spy. If replacing behavior without checking calls, use a stub. If verifying specific interactions occurred, use a mock with expectations.
