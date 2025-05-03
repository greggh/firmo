# Firmo Examples Knowledge Snippets

## Purpose

This document serves as a quick reference or cheat sheet, providing concise code snippets demonstrating common patterns found in the Firmo example files located in the `examples/` directory.

## Key Concepts (Example Areas)

The `examples/` directory contains practical demonstrations of various Firmo features:

1.  **Basic Tests:** `basic_example.lua` - Shows fundamental `describe`, `it`, `expect`.
2.  **Assertions:** `assertions_example.lua` - Demonstrates various assertion types.
3.  **Async Tests:** `async_example.lua` - Shows testing of asynchronous code.
4.  **Mocking:** `mocking_example.lua` - Illustrates spies, stubs, and mocks.
5.  **Coverage:** `coverage_example.lua` - Example of running tests with coverage.
6.  **Error Handling:** `error_handling_example.lua` - Shows patterns for testing errors.
7.  **Performance:** `performance_example.lua` - Demonstrates benchmarking (if applicable).
8.  **Integration:** `integration_example.lua` - Example of integrating multiple components.

## Usage Examples / Patterns

_(Note: These snippets assume necessary modules like `firmo`, `test_helper`, `mocking` are required and functions like `expect`, `describe`, `it`, `before`, `after`, `it_async` are available in the scope, typically via `local firmo = require("firmo")` etc.)_

### Basic Test Example

```lua
--[[
  Basic test structure with setup, teardown, and assertions.
  See: examples/basic_example.lua
]]
-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after
local test_helper = require("lib.tools.test_helper") -- For error capture

describe('Calculator', function()
  local calculator

  before(function()
    calculator = {
      add = function(a, b) return a + b end,
      subtract = function(a, b) return a - b end,
      divide = function(a, b)
        if b == 0 then
          error("Cannot divide by zero")
        end
        return a / b
      end
    }
  end)

  it('adds numbers correctly', function()
    expect(calculator.add(2, 2)).to.equal(4)
  end)

  it('handles errors properly', { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return calculator.divide(1, 0)
    end)()
    expect(err).to.exist()
    expect(err.message).to.match("divide by zero")
  end)
end)
```

### Assertion Examples

```lua
--[[
  Demonstrates various assertion types.
  See: examples/assertions_example.lua
]]
-- Basic assertions
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
-- Extended assertions
expect("hello").to.have_length(5)
expect({1, 2, 3}).to.have_length(3)
expect({}).to.be.empty()
-- Numeric assertions
expect(5).to.be.positive()
expect(-5).to.be.negative()
expect(10).to.be.integer()
-- String assertions
expect("HELLO").to.be.uppercase()
expect("hello").to.be.lowercase()
expect("hello world").to.match("^hello")
-- Table assertions
expect({name = "John"}).to.have_property("name")
expect({1, 2, 3}).to.contain(2)
```

### Async Testing

```lua
--[[
  Shows basic async testing with it_async and wait_until.
  See: examples/async_example.lua
]]
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local start_async_operation -- Placeholder

describe("Async Examples", function()
  -- Basic async test using done callback
  it_async("completes async operation", function(done)
    start_async_operation(function(result)
      expect(result).to.exist()
      done()
    end)
  end)

  -- Using wait_until
  it_async("waits for condition", function()
    local value = false
    firmo.await(50) -- Simulate async delay
    value = true

    firmo.wait_until(function()
      return value
    end, 200) -- Wait up to 200ms

    expect(value).to.be_truthy()
  end)
end)
```

### Mocking Examples

```lua
--[[
  Demonstrates spies, stubs, and mocks.
  See: examples/mocking_example.lua
]]
local mocking = require("lib.mocking")
local firmo = require("firmo") -- For expect
local expect = firmo.expect
local table = {} -- Define table for stub example

-- Function spy
local spy = mocking.spy(function(x) return x * 2 end)
spy(5)
expect(spy).to.be.called()
expect(spy.calls[1].args[1]).to.equal(5) -- Access args correctly

-- Method stub
local stub = mocking.stub.on(table, "method")
stub:returns("stubbed value") -- Chain returns correctly
expect(table.method()).to.equal("stubbed value")
stub:restore() -- Remember to restore

-- Full mock
local mock = mocking.mock({}) -- Create mock from empty table
mock:stub("method"):returns("mocked") -- Use :stub():returns()
expect(mock.method()).to.equal("mocked")
mock:verify() -- Verify calls if needed
```

### Error Handling

```lua
--[[
  Shows patterns for testing code that should produce errors.
  See: examples/error_handling_example.lua
]]
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.core.error_handler")

-- Basic error testing using expect_error flag
it("handles errors", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return function_that_throws() -- Placeholder
  end)()
  expect(err).to.exist()
  expect(err.message).to.match("pattern")
end)

-- Complex error scenario using try/catch from error_handler
describe("Error handling", function()
  it("handles nested errors", function()
    local function deep_error()
      local success, result = error_handler.try(function()
        error("inner error")
      end)
      if not success then error(result) end -- Re-throw if needed
    end

    local _, err = test_helper.with_error_capture(deep_error) -- Call wrapped function

    expect(err).to.exist()
    -- expect(err.stack).to.exist() -- Stack might not be standard field
  end)
end)
```

## Running Examples

You can run the example files directly using the Firmo test runner:

```bash
# Run single example
lua test.lua examples/basic_example.lua

# Run with coverage
lua test.lua --coverage examples/coverage_example.lua

# Run all examples in the directory
lua test.lua examples/
```

## Related Components / Modules

- **Examples Directory:** [`examples/`](./) - Contains the full source code for these patterns.
- **Getting Started Guide:** [`docs/guides/getting-started.md`](../guides/getting-started.md) - Introduces basic Firmo usage.
- **API Reference & Guides:** Refer to the specific API/Guide documents for detailed information on functions used in the examples (e.g., Assertions, Mocking, Async). See [`docs/firmo/knowledge.md`](../firmo/knowledge.md) for an index.
