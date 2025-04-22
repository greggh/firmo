# Examples Knowledge


## Purpose


Demonstrate Firmo testing framework usage and best practices through practical examples.

## Basic Test Example



```lua
-- Basic test structure
local firmo = require('firmo')
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
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



## Assertion Examples



```lua
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



## Async Testing



```lua
-- Basic async test
it.async("completes async operation", function(done)
  start_async_operation(function(result)
    expect(result).to.exist()
    done()
  end)
end)
-- Using wait_until
it.async("waits for condition", function()
  local value = false
  setTimeout(function() value = true end, 50)

  firmo.wait_until(function() 
    return value 
  end, 200)

  expect(value).to.be_truthy()
end)
```



## Mocking Examples



```lua
-- Function spy
local spy = firmo.spy(function(x) return x * 2 end)
spy(5)
expect(spy).to.be.called()
expect(spy[1][1]).to.equal(5)
-- Method stub
local stub = firmo.stub.on(table, "method")
  .returns("stubbed value")
expect(table.method()).to.equal("stubbed value")
-- Full mock
local mock = firmo.mock.new()
mock.method.returns("mocked")
expect(mock.method()).to.equal("mocked")
```



## Error Handling



```lua
-- Basic error testing
it("handles errors", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return function_that_throws()
  end)()
  expect(err).to.exist()
  expect(err.message).to.match("pattern")
end)
-- Complex error scenario
describe("Error handling", function()
  it("handles nested errors", function()
    local function deep_error()
      error_handler.try(function()
        error("inner error")
      end)
    end

    local _, err = test_helper.with_error_capture(function()
      return deep_error()
    end)()

    expect(err).to.exist()
    expect(err.stack).to.exist()
  end)
end)
```



## Critical Rules



- Use expect-style assertions
- Always test error cases
- Clean up resources
- Document examples
- Keep focused
- Handle errors properly


## Best Practices



- Start with basic examples
- Use assertions correctly
- Handle errors properly
- Clean up resources
- Document behavior
- Test edge cases
- Keep focused
- Follow patterns
- Use helpers
- Monitor performance


## Example Categories



1. Basic Tests: basic_example.lua
2. Assertions: assertions_example.lua
3. Async Tests: async_example.lua
4. Mocking: mocking_example.lua
5. Coverage: coverage_example.lua
6. Error Handling: error_handling_example.lua
7. Performance: performance_example.lua
8. Integration: integration_example.lua


## Running Examples



```bash

# Run single example


lua test.lua examples/basic_example.lua

# Run with coverage


lua test.lua --coverage examples/coverage_example.lua

# Run all examples


lua test.lua examples/
```
