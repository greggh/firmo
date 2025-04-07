# Mocking System Tests

This directory contains tests for the firmo mocking system. The mocking module provides facilities for creating test doubles (spies, stubs, and mocks) to isolate code during testing.

## Directory Contents

- **mocking_test.lua** - Tests for mocking, stubbing, and spying functionality

## Mocking System Features

The firmo mocking system provides:

- **Spies** - Track function calls without changing behavior
- **Stubs** - Replace function behavior with custom implementation
- **Mocks** - Combine spying and stubbing with expectations
- **Sequences** - Define ordered return values or behaviors
- **Table mocking** - Mock methods on tables
- **Return value control** - Specify what mocked functions return
- **Error simulation** - Make mocked functions throw errors

## Mocking Patterns

```lua
-- Creating a spy
local spy = firmo.spy.on(table, "method")
expect(spy).to.be.called()

-- Creating a stub
local stub = firmo.stub.on(table, "method").returns(value)
expect(stub).to.be.called_with(arg1, arg2)

-- Creating a mock
local mock = firmo.mock.new()
mock.method.returns(value)
expect(mock.method).to.be.called()

-- Creating a sequence
local sequence = firmo.mock.sequence()
  .returns(1)
  .returns(2)
  .raises("error")
```

## Running Tests

To run all mocking tests:
```
lua test.lua tests/mocking/
```

To run a specific mocking test:
```
lua test.lua tests/mocking/mocking_test.lua
```

See the [Mocking API Documentation](/docs/api/mocking.md) for more information.