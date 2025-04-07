# Asynchronous Testing

This directory contains tests for the firmo asynchronous testing functionality. The async module enables testing of asynchronous operations with proper timeout handling and sequential execution guarantees.

## Directory Contents

- **async_test.lua** - Tests for the core async module functionality
- **async_timeout_test.lua** - Tests for async timeout behavior and error handling

## Asynchronous Testing Features

The firmo framework provides specialized support for asynchronous testing:

- Support for async test blocks with `it.async`
- Proper handling of timeout configurations
- Sequential execution of async operations
- Callback integration with test framework
- Promise-like API for easier async test writing

## Writing Async Tests

Use the `it.async` function to create asynchronous test blocks:

```lua
it.async("should complete an asynchronous operation", function(done)
  -- Async operation here
  -- Call done() when complete
  done()
end)
```

## Common Patterns

- Always call the `done()` callback when an async test completes
- Set appropriate timeouts for async operations
- Handle both success and error cases in async tests
- Use the async module for nested async operations

## Running Tests

To run all async tests:
```
lua test.lua tests/async/
```

To run a specific async test:
```
lua test.lua tests/async/async_test.lua
```

See the [Async API Documentation](/docs/api/async.md) for more information.