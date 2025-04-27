# Mocking System Knowledge

## Purpose

This document outlines key internal concepts, implementation patterns, and design considerations for the `lib/mocking` modules (spy, stub, mock), intended for developers working on or extending Firmo's mocking system.

## Key Concepts

-   **Spy (`lib/mocking/spy.lua`):** Wraps a function (or replaces an object method) to record calls (`spy.calls`, `spy.call_count`, etc.) while optionally still calling the original function (`and_call_through`). Can be configured to return values (`and_return`), call fakes (`and_call_fake`), or throw errors (`and_throw`). Forms the basis for Stubs and Mocks. Call history is stored in `spy.calls` as an array of tables: `{ args = {}, timestamp = num, result = val?, error = err? }`.
-   **Stub (`lib/mocking/stub.lua`):** Replaces a function's implementation entirely. Inherits from Spy for call tracking. Provides methods to define return values (`returns`), sequences (`returns_in_sequence`), error throwing (`throws`), and behavior when sequences are exhausted (`when_exhausted`). Can be created standalone (`stub.new`) or replace an object method (`stub.on`).
-   **Mock (`lib/mocking/mock.lua`):** Wraps a target table (or creates a mock from scratch). Uses Stubs internally to replace methods/properties (`mock:stub`, `mock:stub_property`). Provides an `expect` method for setting up detailed call expectations (less commonly used) and a `verify` method to check if stubbed methods were called as expected (checks `call_count > 0` by default, or specific expectations set via `expect`). Also provides `restore` and integrates with the `with_mocks` context manager.
-   **Verification (`mock:verify()`):** Checks if methods stubbed on the mock object were called. By default (`verify_all_expectations_called = true`), it checks if `call_count > 0` for all stubbed methods. If specific expectations were set using `mock:expect(...)`, it verifies those instead. Returns `success, error_object`.
-   **Sequence Handling:** Stubs manage sequences using internal counters and configuration (`_sequence_values`, `_sequence_index`, `_cycle_sequence`, `_exhausted_behavior`).
-   **Context Manager (`mocking.with_mocks`):** Provided by `lib/mocking/mock.lua` (exported via `init.lua`). Executes a function, passing context-aware creators (`mock_creator`, `spy_creator`, `stub_creator`). Automatically calls `mock.restore_all()` after the function executes (even on error) to clean up mocks created *within* the context.
-   **Cleanup (`restore`, `restore_all`, `reset_all`):** Individual spies/stubs/mocks have `restore()` methods. `mock.restore_all()` (aliased as `reset_all`) restores *all* mocks globally. `spy.reset_all()` and `stub.reset_all()` reset call history for all spies/stubs. `mocking.reset_all()` calls `mock.restore_all()`. Cleanup is crucial to prevent test interference.

## Usage Examples / Patterns

*(Note: Examples assume necessary modules like `firmo`, `mocking`, `test_helper`, `error_handler` are required and functions like `expect`, `describe`, `it`, `before`, `after` are available.)*

### Spy, Stub, Mock Examples

```lua
local mocking = require("lib.mocking")
local expect = require("firmo").expect -- Assuming expect

-- Spy Example
local spy = mocking.spy(function(x) return x*2 end)
spy(5)
expect(spy).to.be.called()
expect(spy.calls[1].args[1]).to.equal(5) -- Access args correctly

-- Stub Example (Method Stub)
local my_table = {}
local original_method = my_table.method -- Store original if needed
local stub = mocking.stub.on(my_table, "method")
stub:returns("stubbed value") -- Chain returns correctly
expect(my_table.method()).to.equal("stubbed value")
stub:restore() -- Remember to restore
expect(my_table.method == original_method).to.be_truthy()

-- Stub Example (Sequence)
local seq_stub = mocking.stub():returns_in_sequence({1, 2}):throws("error"):when_exhausted("custom", nil)
expect(seq_stub()).to.equal(1)
expect(seq_stub()).to.equal(2)
expect(function() seq_stub() end).to.throw("error") -- Throws before custom value due to order
-- expect(seq_stub()).to.equal(nil) -- Example for custom nil value

-- Mock Example
local mock = mocking.mock({}) -- Mock an empty table
mock:stub("method"):returns("mocked") -- Use :stub():returns()
expect(mock.method()).to.equal("mocked")
local success, err = mock:verify()
expect(success).to.be_truthy(err and err.message or "Verification failed")
```

### Complex Mocking Scenario

```lua
--[[
  Demonstrates mocking multiple dependencies for a service test.
]]
local mocking = require("lib.mocking")
local firmo = require("firmo")
local describe, it, expect, before = firmo.describe, firmo.it, firmo.expect, firmo.before
local create_service -- Placeholder for service constructor

describe("Database operations", function()
  local mock_db, mock_api, service

  before(function()
    -- Create mocks for dependencies
    mock_db = mocking.mock({ connect = function() end, query = function() end }) -- Mock with method names
    mock_api = mocking.mock({ fetch = function() end })

    -- Configure mock behavior using stub
    mock_db:stub("connect"):returns({ connected = true })
    mock_db:stub("query"):returns({ rows = 5 })
    mock_api:stub("fetch"):returns({ data = "test" })

    -- Create service with mocks
    service = create_service(mock_db, mock_api)
  end)

  it("processes data correctly", function()
    local result = service.process_data() -- Assuming this calls db.connect, db.query, api.fetch

    -- Verify interactions using mock:verify()
    local db_ok, db_err = mock_db:verify()
    expect(db_ok).to.be_truthy(db_err and db_err.message or "DB verify failed")

    local api_ok, api_err = mock_api:verify()
    expect(api_ok).to.be_truthy(api_err and api_err.message or "API verify failed")

    -- Verify service result
    expect(result.success).to.be_truthy()
  end)
end)
```

### Mock Verification

```lua
--[[
  Demonstrates verifying mock/spy calls.
]]
local mocking = require("lib.mocking")
local expect = require("firmo").expect
local spy = mocking.spy(function() end)
local mock = mocking.mock({ method1 = function() end, method2 = function() end })

spy(5, "arg")
mock.method1(1, 2)

-- Call count verification (Spy)
expect(spy.call_count).to.equal(1)

-- Arguments verification (Spy)
expect(spy).to.be.called_with(5, "arg")

-- Mock verification (checks if stubbed methods were called)
mock:stub("method1"):returns(true) -- Stubbing implicitly sets expectation
mock.method1(1, 2) -- Call the stubbed method
local success, err = mock:verify()
expect(success).to.be_truthy(err and err.message or "Verify failed")

-- Mock verification failure example
mock:stub("method2"):returns(true) -- Expect method2 to be called
-- But method2 is never called...
local success_fail, err_fail = mock:verify()
expect(success_fail).to.be_falsy()
expect(err_fail.message).to.match("Expected stub 'method2' to have been called")

```

### Error Handling with Mocks

```lua
--[[
  Shows how to test code that handles errors from mocked dependencies.
]]
local mocking = require("lib.mocking")
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")

describe("Mock Error Handling", function()
  it("handles errors thrown by stubs", { expect_error = true }, function()
    local mock = mocking.mock({})
    -- Configure stub to throw an error
    mock:stub("method"):throws("test error")

    -- Call the method and capture the error
    local result, err = test_helper.with_error_capture(function()
      return mock.method()
    end)()

    expect(err).to.exist()
    -- Note: The error caught might be the raw "test error" string or a wrapped error object
    expect(tostring(err)).to.match("test error")
  end)

  it("verifies expectations correctly on failure", function()
    local mock = mocking.mock({ method = function() end })
    -- Stub implies expectation that method should be called
    mock:stub("method")
    -- But we don't call mock.method()...

    -- verify() should return false and an error object
    local success, err = mock:verify()

    expect(success).to.be_falsy()
    expect(err).to.exist()
    expect(err.message).to.match("Expected stub 'method' to have been called")
  end)
end)

-- Refer readers to mocking.with_mocks for automatic resource cleanup
-- print("See `mocking.with_mocks` for automatic mock cleanup patterns.")

```

## Related Components / Modules

-   **Source:** [`lib/mocking/init.lua`](init.lua), [`lib/mocking/mock.lua`](mock.lua), [`lib/mocking/spy.lua`](spy.lua), [`lib/mocking/stub.lua`](stub.lua)
-   **Usage Guide:** [`docs/guides/mocking.md`](../../docs/guides/mocking.md)
-   **API Reference:** [`docs/api/mocking.md`](../../docs/api/mocking.md)
-   **Assertions:** [`lib/assertion/init.lua`](../assertion/init.lua) - Used via `expect` to verify mock behavior.
-   **Error Handling:** [`lib/core/error_handler/init.lua`](../core/error_handler/init.lua) - Used internally.
