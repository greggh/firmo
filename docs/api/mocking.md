# Mocking API Reference

This document provides comprehensive reference information about the mocking, spying, and stubbing facilities in Firmo.

## Overview

The Firmo mocking system offers comprehensive facilities for creating test doubles that help isolate components during testing:

- **Spies**: Track function calls without changing behavior
- **Stubs**: Replace functions with custom implementations
- **Mocks**: Complete mock objects with verification capabilities
- **Sequential Values**: Configure functions to return different values on successive calls
- **Context Management**: Automatically restore mocks after use
- **Deep Integration**: Work seamlessly with the rest of the Firmo testing framework
- **Enhanced Error Handling**: Robust error handling with detailed diagnostics
- **Advanced Matchers**: Flexible argument matching for verifying calls

## Module Structure

The mocking system consists of these active, core components that work together:

- `firmo.spy`: Functions for creating spies to track calls (`lib/mocking/spy.lua`)
- `firmo.stub`: Functions for replacing implementations (`lib/mocking/stub.lua`)
- `firmo.mock`: Functions for creating complete mock objects (`lib/mocking/mock.lua`)
- `firmo.with_mocks`: Context manager for automatic cleanup
- `lib/tools/logging.lua`: Provides integrated logging support for mocking operations

> 📌 **Note:** Both `mock.lua` and `logging.lua` are actively maintained, core modules that integrate closely with the stub system for comprehensive mocking capabilities.

## Integration Architecture

The mocking system uses a layered architecture with strong integration between components:

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│ Mock Module   │────▶│ Stub System   │────▶│ Spy System    │
│ (mock.lua)    │     │ (stub.lua)    │     │ (spy.lua)     │
└───────┬───────┘     └───────┬───────┘     └───────────────┘
        │                     │                     ▲
        │                     │                     │
        │                     │                     │
        ▼                     ▼                     │
┌───────────────┐     ┌───────────────┐             │
│ Error Handler │◀────│ Logging       │─────────────┘
│               │     │ (logging.lua) │
└───────────────┘     └───────────────┘
```

This integration provides several benefits:

- **Consistent Error Handling**: All components use the same error management
- **Detailed Logging**: Comprehensive logging through the logging system
- **Type Checking**: Consistent argument validation across components
- **Shared Utilities**: Common functionality is shared between modules

## Spy Functions

### firmo.spy(target, [method_name])

Creates a spy function or spies on an object method.

**Parameters**:
- `target` (function|table): Function to spy on or table containing method to spy on
- `method_name` (string, optional): If target is a table, the name of the method to spy on

**Returns**:
- A spy object that tracks calls to the function

**Example**:
```lua
-- Spy on a function
local fn = function(a, b) return a + b end
local spy_fn = firmo.spy(fn)
spy_fn(1, 2) -- Calls original function, but tracks the call

-- Spy on an object method
local obj = { method = function(self, arg) return arg end }
local spy_method = firmo.spy(obj, "method")
obj:method("test") -- Calls original method, but tracks the call
```

### firmo.spy.new(fn)

Creates a standalone spy function that wraps the provided function.

**Parameters**:
- `fn` (function, optional): The function to spy on (defaults to an empty function)

**Returns**:
- A spy object that records calls

**Example**:
```lua
-- Create a spy on a function
local fn = function(x) return x * 2 end
local spy = firmo.spy.new(fn)
local result = spy(5) -- Returns 10, but tracking is enabled
expect(result).to.equal(10)
expect(spy.calls[1][1]).to.equal(5)
```

### firmo.spy.on(obj, method_name)

Creates a spy on an object method, replacing it with the spy while preserving behavior.

**Parameters**:
- `obj` (table): The object containing the method to spy on
- `method_name` (string): The name of the method to spy on

**Returns**:
- A spy for the object method

**Example**:
```lua
local calculator = {
  add = function(a, b) return a + b end
}
local add_spy = firmo.spy.on(calculator, "add")
local result = calculator.add(3, 4) -- Returns 7, but call is tracked
expect(result).to.equal(7)
expect(add_spy.called).to.be_truthy()
```

### spy.called

A boolean value indicating whether the spy has been called at least once.

**Example**:
```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
expect(spy_fn.called).to.equal(false)
spy_fn()
expect(spy_fn.called).to.be_truthy()
```

### spy.call_count

The number of times the spy has been called.

**Example**:
```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn()
spy_fn()
expect(spy_fn.call_count).to.equal(2)
```

### spy.calls

A table containing the arguments passed to each call of the spy.

**Example**:
```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn(1, 2)
spy_fn("a", "b")
expect(spy_fn.calls[1][1]).to.equal(1) -- First call, first argument
expect(spy_fn.calls[2][2]).to.equal("b") -- Second call, second argument
```

### spy:called_with(...)

Checks whether the spy was called with the specified arguments.

**Parameters**:
- `...`: The arguments to check for

**Returns**:
- `true` if the spy was called with the specified arguments, `false` otherwise

**Example**:
```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn("test", 123)
expect(spy_fn:called_with("test")).to.be_truthy() -- Checks just the first arg
expect(spy_fn:called_with("test", 123)).to.be_truthy() -- Checks both args
expect(spy_fn:called_with("wrong")).to.equal(false)
```

### spy:called_times(n)

Checks whether the spy was called exactly n times.

**Parameters**:
- `n` (number): The expected number of calls

**Returns**:
- `true` if the spy was called exactly n times, `false` otherwise

**Example**:
```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn()
spy_fn()
expect(spy_fn:called_times(2)).to.be_truthy()
expect(spy_fn:called_times(3)).to.equal(false)
```

### spy:not_called()

Checks whether the spy was never called.

**Returns**:
- `true` if the spy was never called, `false` otherwise

**Example**:
```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
expect(spy_fn:not_called()).to.be_truthy()
spy_fn()
expect(spy_fn:not_called()).to.equal(false)
```

### spy:called_once()

Checks whether the spy was called exactly once.

**Returns**:
- `true` if the spy was called exactly once, `false` otherwise

**Example**:
```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn()
expect(spy_fn:called_once()).to.be_truthy()
spy_fn()
expect(spy_fn:called_once()).to.equal(false)
```

### spy:last_call()

Gets the arguments from the most recent call to the spy.

**Returns**:
- A table containing the arguments passed to the most recent call, or nil if the spy was never called

**Example**:
```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn("first")
spy_fn("second", "arg")
local last_args = spy_fn:last_call()
expect(last_args[1]).to.equal("second")
expect(last_args[2]).to.equal("arg")
```

### spy:called_before(other_spy, [call_index])

Checks whether this spy was called before another spy.

**Parameters**:
- `other_spy` (spy): Another spy to compare with
- `call_index` (number, optional): The index of the call to check on the other spy (default: 1)

**Returns**:
- `true` if this spy was called before the other spy, `false` otherwise

**Example**:
```lua
local fn1 = function() end
local fn2 = function() end
local spy1 = firmo.spy(fn1)
local spy2 = firmo.spy(fn2)
spy1() -- Called first
spy2() -- Called second
expect(spy2:called_after(spy1)).to.be_truthy()
expect(spy1:called_after(spy2)).to.equal(false)
```

### spy:restore()

Restores the original function/method if the spy was created for an object method.

**Example**:
```lua
local obj = { method = function() return "original" end }
local spy_method = firmo.spy(obj, "method")
expect(obj.method()).to.equal("original") -- Calls through to original
spy_method:restore()
expect(obj.method()).to.equal(obj.method) -- Original function is restored
```

### spy:args_match(call_index, match_pattern)

Checks if the arguments of a specific call match a pattern.

**Parameters**:
- `call_index` (number): The index of the call to check
- `match_pattern` (table): Pattern to match, using special matchers or direct values

**Returns**:
- `boolean`: Whether the arguments match the pattern

**Example**:
```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn("test", 123, {key = "value"})

-- Direct value matching
expect(spy_fn:args_match(1, {"test", 123})).to.be_truthy()

-- Using matchers
expect(spy_fn:args_match(1, {firmo.spy.matchers.any_string, firmo.spy.matchers.any_number})).to.be_truthy()
expect(spy_fn:args_match(1, {firmo.spy.matchers.matches("^t"), 123})).to.be_truthy()
```

### Argument Matchers

The spy system includes advanced matchers for flexible argument verification:

```lua
-- Available matchers
local matchers = firmo.spy.matchers

matchers.any               -- Matches any value
matchers.any_string        -- Matches any string
matchers.any_number        -- Matches any number
matchers.any_boolean       -- Matches any boolean
matchers.any_table         -- Matches any table
matchers.any_function      -- Matches any function
matchers.matches(pattern)  -- Matches string against pattern
matchers.greater_than(n)   -- Matches number > n
matchers.less_than(n)      -- Matches number < n
matchers.in_range(min, max) -- Matches number in range
matchers.contains(key)     -- Matches table containing key
matchers.contains_value(v) -- Matches table containing value
matchers.has_keys(keys)    -- Matches table with all specified keys
matchers.same_structure(t) -- Matches table with same structure
```

## Stub Functions
local fn2 = function() end
local spy1 = firmo.spy(fn1)
local spy2 = firmo.spy(fn2)
spy1() -- Called first
spy2() -- Called second
expect(spy2:called_after(spy1)).to.be_truthy()
expect(spy1:called_after(spy2)).to.equal(false)
```

### spy:restore()

Restores the original function/method if the spy was created for an object method.

**Example**:
```lua
local obj = { method = function() return "original" end }
local spy_method = firmo.spy(obj, "method")
expect(obj.method()).to.equal("original") -- Calls through to original
spy_method:restore()
expect(obj.method).to.equal(obj.method) -- Original function is restored
```

## Stub Functions

### firmo.stub(return_value_or_implementation)

Creates a standalone stub function that returns a specific value or uses a custom implementation. The stub system integrates with the logging system for detailed diagnostics and error handling.

**Parameters**:
```lua
---@param return_value_or_implementation any|function Value to return when stub is called, or function to use as implementation
---@return Stub The created stub object
```

**Returns**:
- A stub function that returns the specified value or executes the specified function

**Example**:
```lua
-- Stub with a return value
local get_config = firmo.stub({debug = true, timeout = 1000})
local config = get_config() -- Returns {debug = true, timeout = 1000}

-- Stub with a function implementation
local calculate = firmo.stub(function(a, b) return a * b end)
local result = calculate(2, 3) -- Returns 6

-- With logging integration for debugging
local logger = require("lib.tools.logging").get_logger("mocking")
local validate_user = firmo.stub(function(user_data)
  logger.debug("Stub called with user data", {
    user_id = user_data.id,
    operation = "validate_user"
  })
  return true
end)
```

### firmo.stub.new(return_value_or_implementation)

Creates a new standalone stub function that returns a specified value or uses custom implementation.

**Parameters**:
- `return_value_or_implementation` (any|function, optional): Value to return when stub is called, or function to use as implementation

**Returns**:
- A stub object

**Example**:
```lua
-- Create a stub with a fixed return value
local stub = firmo.stub.new("fixed value")
expect(stub()).to.equal("fixed value")

-- Create a stub with custom implementation
local custom_stub = firmo.stub.new(function(arg1, arg2)
  return arg1 * arg2
end)
expect(custom_stub(3, 4)).to.equal(12)
```

### firmo.stub.on(obj, method_name, value_or_impl)

Replace an object's method with a stub.

**Parameters**:
- `obj` (table): The object containing the method to stub
- `method_name` (string): The name of the method to stub
- `value_or_impl` (any|function): Value to return when stub is called, or function to use as implementation

**Returns**:
- A stub object for the method

**Example**:
```lua
local obj = { 
  method = function() return "original" end 
}

-- Replace with a value
local stub = firmo.stub.on(obj, "method", "stubbed")
expect(obj.method()).to.equal("stubbed")

-- Restore the original method
stub:restore()
expect(obj.method()).to.equal("original")
```

### stub:returns(value)

Configure stub to return a specific value.

**Parameters**:
- `value` (any): The value to return when the stub is called

**Returns**:
- A new stub configured to return the specified value

**Example**:
```lua
local stub = firmo.stub(nil)
local new_stub = stub:returns("new value")
expect(new_stub()).to.equal("new value")
```

### stub:returns_in_sequence(values)

Configure stub to return values from a sequence in order.

**Parameters**:
- `values` (table): An array of values to return in sequence

**Returns**:
- A new stub configured with sequence behavior

**Example**:
```lua
local stub = firmo.stub():returns_in_sequence({"first", "second", "third"})
expect(stub()).to.equal("first")
expect(stub()).to.equal("second")
expect(stub()).to.equal("third")
expect(stub()).to.equal(nil) -- Sequence exhausted
```

### stub:matches(matcher_fn)

Configure a stub to respond differently based on argument matching.

**Parameters**:
```lua
---@param matcher_fn function Function that takes arguments and returns boolean
---@return Stub The stub object for method chaining
```

**Returns**:
- The stub object for method chaining

**Example**:
```lua
local api_stub = firmo.stub()
  :matches(function(id) 
    return type(id) == "number" and id > 0 
  end)
  :returns({ status = "success", data = "valid id" })
  :otherwise()
  :returns({ status = "error", message = "invalid id" })

expect(api_stub(123)).to.deep_equal({ status = "success", data = "valid id" })
expect(api_stub("abc")).to.deep_equal({ status = "error", message = "invalid id" })
```

### stub:cycle_sequence(enable)

Configure whether the sequence of return values should cycle.

**Parameters**:
- `enable` (boolean, optional): Whether to enable cycling (defaults to true)

**Returns**:
- The stub object for method chaining

**Example**:
```lua
local stub = firmo.stub()
  :returns_in_sequence({"red", "yellow", "green"})
  :cycle_sequence()

expect(stub()).to.equal("red")
expect(stub()).to.equal("yellow")
expect(stub()).to.equal("green")
expect(stub()).to.equal("red") -- Cycles back to beginning
```

### stub:when_exhausted(behavior, [custom_value])

Configure what happens when a sequence is exhausted.

**Parameters**:
- `behavior` (string): One of:
  - `"nil"`: Return nil (default behavior)
  - `"fallback"`: Fall back to the original implementation
  - `"custom"`: Return a custom value
- `custom_value` (any, optional): Value to return when behavior is "custom"

**Returns**:
- The stub object for method chaining

**Example**:
```lua
-- Return a custom error object when exhausted
local stub = firmo.stub()
  :returns_in_sequence({"first", "second"})
  :when_exhausted("custom", "sequence ended")

expect(stub()).to.equal("first")
expect(stub()).to.equal("second")
expect(stub()).to.equal("sequence ended")
```

### stub:reset_sequence()

Reset sequence to the beginning.

**Returns**:
- The stub object for method chaining

**Example**:
```lua
local stub = firmo.stub():returns_in_sequence({1, 2, 3})
expect(stub()).to.equal(1)
expect(stub()).to.equal(2)
expect(stub()).to.equal(3)
expect(stub()).to.equal(nil) -- Exhausted

stub:reset_sequence() -- Reset to start
expect(stub()).to.equal(1) -- Starts over
```

### stub:with_error_handling(options)

Configure stub with enhanced error handling options.

**Parameters**:
```lua
---@param options table
---@field capture_stack boolean Whether to capture stack information
---@field capture_args boolean Whether to capture arguments in errors
---@field log_errors boolean Whether to log errors to the logging system
---@field debug_mode boolean Whether to enable detailed debug information
---@return Stub The stub object for method chaining
```

**Example**:
```lua
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Create a stub with enhanced error handling
local database_stub = firmo.stub()
  :with_error_handling({
    capture_stack = true,
    capture_args = true,
    log_errors = true
  })
  :throws(error_handler.runtime_error("Database connection failed", {
    operation = "connect",
    category = error_handler.CATEGORY.EXTERNAL_SERVICE
  }))

-- When the stub is called, it will throw a detailed error
-- with stack info, arguments, and automatically log to the logging system
```

### stub:throws(error_message)

Configure stub to throw an error when called.

**Parameters**:
- `error_message` (string|table): The error message or error object to throw

**Returns**:
- A new stub configured to throw the specified error

**Example**:
```lua
local stub = firmo.stub():throws("test error")

-- Using expect to verify the error
expect(function()
  stub()
end).to.throw("test error")
```

### stub:restore()

Restore the original method (for stubs created with stub.on).

**Example**:
```lua
local obj = { 
  method = function() return "original" end 
}

local stub = firmo.stub.on(obj, "method", "stubbed")
expect(obj.method()).to.equal("stubbed")

stub:restore() -- Restore the original method
expect(obj.method()).to.equal("original")
```

## Mock Objects

### firmo.mock(target, [method_or_options], [impl_or_value])

Create a mock object with controlled behavior.

**Parameters**:
- `target` (table): The object to create a mock of
- `method_or_options` (string|table, optional): Either a method name to stub or options table
- `impl_or_value` (any, optional): The implementation or return value for the stub (when method specified)

**Returns**:
- A mock object

**Example**:
```lua
-- Create a mock object and stub a method in one call
local database = { query = function() end }
local mock_db = firmo.mock(database, "query", { rows = 10 })
expect(database.query()).to.deep_equal({ rows = 10 })

-- Create a mock with options
local obj = { method = function() end }
local mock_obj = firmo.mock(obj, { verify_all_expectations_called = true })
```

### firmo.mock.create(target, [options])

Create a mock object with verifiable behavior.

**Parameters**:
- `target` (table): The object to create a mock of
- `options` (table, optional): Optional configuration:
  - `verify_all_expectations_called` (boolean): If true, verify() will fail if any stubbed methods were not called (default: true)

**Returns**:
- A mockable object

**Example**:
```lua
local file_system = {
  read_file = function(path) return io.open(path, "r"):read("*a") end,
  write_file = function(path, content) local f = io.open(path, "w"); f:write(content); f:close() end
}
local mock_fs = firmo.mock.create(file_system)
```

### mock:stub(name, implementation_or_value)

Stub a method on the mock object with a specific implementation or return value.

**Parameters**:
- `name` (string): Name of the method to stub
- `implementation_or_value` (any|function): Function to run when the method is called, or value to return

**Returns**:
- The mock object for method chaining

**Example**:
```lua
local database = { query = function() end }
local db_mock = firmo.mock(database)
db_mock:stub("query", function(query_string)
  return {rows = {{id = 1, name = "test"}}}
end)
```

### mock:stub_in_sequence(name, sequence_values)

Stub a method on the mock object to return different values on successive calls.

**Parameters**:
- `name` (string): Name of the method to stub
- `sequence_values` (table): Array of values to return in sequence on successive calls

**Returns**:
- The stub object for method chaining

**Example**:
```lua
local api = { get_status = function() return "online" end }
local mock_api = firmo.mock(api)
mock_api:stub_in_sequence("get_status", {
  "starting",
  "connecting",
  "online",
  "disconnecting"
})
```

### mock:restore_stub(name)

Restore the original implementation of a specific stubbed method.

**Parameters**:
- `name` (string): Name of the method to restore

**Returns**:
- The mock object for method chaining

**Example**:
```lua
local obj = { method = function() return "original" end }
local mock_obj = firmo.mock(obj)
mock_obj:stub("method", function() return "stubbed" end)
expect(obj.method()).to.equal("stubbed")
mock_obj:restore_stub("method")
expect(obj.method()).to.equal("original")
```

### mock:restore()

Restore all stubbed methods to their original implementations.

**Returns**:
- The mock object for method chaining

**Example**:
```lua
local obj = {
  method1 = function() return "original1" end,
  method2 = function() return "original2" end
}
local mock_obj = firmo.mock(obj)
mock_obj:stub("method1", function() return "stubbed1" end)
mock_obj:stub("method2", function() return "stubbed2" end)
mock_obj:restore()
expect(obj.method1()).to.equal("original1")
expect(obj.method2()).to.equal("original2")
```

### mock:verify()

Verify that all expected method calls were made.

**Returns**:
- `true` if all expectations were met
- Throws an error if verification fails

**Example**:
```lua
local obj = { method = function() end }
local mock_obj = firmo.mock(obj)
mock_obj:stub("method", function() return "stubbed" end)
obj.method() -- Call the stubbed method
mock_obj:verify() -- Passes because method was called
```

## Context Manager

### firmo.with_mocks(fn)

Execute a function with automatic mock cleanup, even if an error occurs.

**Parameters**:
- `fn` (function): Function to execute with mock context, receives `mock_fn`, `spy`, and `stub` as arguments

**Example**:
```lua
local obj = { method = function() return "original" end }

firmo.with_mocks(function(mock_fn)
  -- Create mocks inside the context
  local mock_obj = mock_fn(obj)
  mock_obj:stub("method", function() return "stubbed" end)
  
  -- Use the mock
  expect(obj.method()).to.equal("stubbed")
  
  -- No need to restore, happens automatically
end)

-- Outside the context, original method is restored
expect(obj.method()).to.equal("original")
```

## Integration with Expect

The mocking system integrates with Firmo's expectation system for fluent verification of mock behaviors:

```lua
-- Using the expect API with mocks and spies
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn("test")

-- All of these assertions work with spies
expect(spy_fn).to.be.called()
expect(spy_fn).to.be.called.once()
expect(spy_fn).to.be.called.times(1)
expect(spy_fn).to.be.called.with("test")
expect(spy_fn).to.have.been.called.before(other_spy)
```

## Type Annotations

The mocking system includes comprehensive type annotations for IDE support (Lu

### firmo.mock._VERSION

String identifier for the mock module version.

**Example**:
```lua
print(firmo.mock._VERSION) -- e.g., "1.0.0"
```

### firmo.spy._VERSION

String identifier for the spy module version.

**Example**:
```lua
print(firmo.spy._VERSION) -- e.g., "1.0.0"
```

### firmo.stub._VERSION

String identifier for the stub module version.

**Example**:
```lua
print(firmo.stub._VERSION) -- e.g., "1.0.0"
```