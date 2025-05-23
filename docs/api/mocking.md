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

- `lib/mocking/init.lua`: The main integration module, exports `spy`, `stub`, `mock`, and helper functions.
- `lib/mocking/spy.lua`: Implementation for creating spies to track calls.
- `lib/mocking/stub.lua`: Implementation for replacing function behavior.
- `lib/mocking/mock.lua`: Implementation for creating complete mock objects and the `mocking.with_mocks` context manager.

> 📌 **Note:** These modules integrate closely, with `mock.lua` and `stub.lua` utilizing `spy.lua` for call tracking. The system also uses `lib/tools/logging.lua` and `lib/tools/error_handler.lua` internally.

## Integration Architecture

The mocking system uses a layered architecture with strong integration: `init.lua` provides the public API, wrapping functionality from `mock.lua`, `stub.lua`, and `spy.lua`. Internal tools like `error_handler` and `logging` support these modules.

```text
┌───────────────────┐
│ lib/mocking/init.lua │  <-- Public API (`require("lib.mocking")`)
└─────────┬─────────┘
          │ Wraps & Integrates
          ▼
┌───────────────────┬───────────────────┬───────────────────┐
│ lib/mocking/mock.lua│ lib/mocking/stub.lua│ lib/mocking/spy.lua │
└─────────┬─────────┴─────────┬─────────┴─────────┬─────────┘
          │ Uses                │ Uses                │ (Base Tracking)
          ▼                     ▼                     │
┌───────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────┐
│ lib/tools/error_handler.lua     │
│ lib/tools/logging.lua           │
└─────────────────────────────────┘
```

This integration provides several benefits:

- **Consistent Error Handling**: All components use the same error management
- **Detailed Logging**: Comprehensive logging through the logging system
- **Type Checking**: Consistent argument validation across components
- **Shared Utilities**: Common functionality is shared between modules

## Spy Functions

### mocking.spy(target, [method_name])

Creates a spy function or spies on an object method.
**Parameters**:

- `target` (function|table): Function to spy on or table containing method to spy on
- `method_name` (string, optional): If target is a table, the name of the method to spy on

**Returns**:

- A spy object that tracks calls to the function

**Example**:

````lua
-- Spy on a function
local fn = function(a, b) return a + b end
local mocking = require("lib.mocking")
local fn = function(a, b) return a + b end
local spy_fn = mocking.spy(fn)
spy_fn(1, 2) -- Calls original function, but tracks the call
-- Spy on an object method
local obj = { method = function(self, arg) return arg end }
local spy_method = mocking.spy(obj, "method")
obj:method("test") -- Calls original method, but tracks the call

### mocking.spy.new(fn)

Creates a standalone spy function that wraps the provided function.
**Parameters**:

- `fn` (function, optional): The function to spy on (defaults to an empty function)

**Returns**:

- A spy object that records calls

**Example**:

```lua
-- Create a spy on a function
local mocking = require("lib.mocking")
local fn = function(x) return x * 2 end
local spy = mocking.spy.new(fn)
local result = spy(5) -- Returns 10, but tracking is enabled
expect(result).to.equal(10)
expect(spy.calls[1][1]).to.equal(5)
````

### mocking.spy.on(obj, method_name)

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
local mocking = require("lib.mocking")
local add_spy = mocking.spy.on(calculator, "add")
local result = calculator.add(3, 4) -- Returns 7, but call is tracked
expect(result).to.equal(7)
expect(add_spy.called).to.be_truthy()
```

### spy.called

A boolean value indicating whether the spy has been called at least once.
**Example**:

```lua
local fn = function() end
local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
expect(spy_fn.called).to.equal(false)
spy_fn()
```

### spy.call_count

The number of times the spy has been called.
**Example**:

```lua
local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
spy_fn()
spy_fn()
expect(spy_fn.call_count).to.equal(2)
```

### spy.calls

A table containing call record objects for each call. Each record contains:

- `args` (table): Array-like table of arguments passed.
- `timestamp` (number): Time of the call (`os.time()`).
- `result` (any, optional): The value returned by the spied function.
- `error` (any, optional): The error thrown by the spied function.
  **Example**:

````lua
local fn = function() end
local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
spy_fn(1, 2)
spy_fn("a", "b")
expect(spy_fn.calls[1].args[1]).to.equal(1) -- First call, first argument
expect(spy_fn.calls[2].args[2]).to.equal("b") -- Second call, second argument

### spy:called_with(...)

Checks whether the spy was called with the specified arguments.
**Parameters**:

- `...`: The arguments to check for

**Returns**:

- `true` if the spy was called with the specified arguments, `false` otherwise

**Example**:

```lua
local fn = function() end
local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
spy_fn("test", 123)
expect(spy_fn:called_with("test")).to.be_truthy() -- Checks just the first arg
expect(spy_fn:called_with("test", 123)).to.be_truthy() -- Checks both args
````

### spy:called_times(n)

Checks whether the spy was called exactly n times.
**Parameters**:

- `n` (number): The expected number of calls

**Returns**:

- `true` if the spy was called exactly n times, `false` otherwise

**Example**:

```lua
local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
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
local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
expect(spy_fn:not_called()).to.be_truthy()
spy_fn()
expect(spy_fn:not_called()).to.equal(false)
```

### spy:called_once()

Checks whether the spy was called exactly once.
**Returns**:

- `true` if the spy was called exactly once, `false` otherwise

**Example**:

local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
spy_fn()
expect(spy_fn:called_once()).to.be_truthy()
spy_fn()
spy_fn()
expect(spy_fn:called_once()).to.equal(false)

````

### spy:last_call()

Gets the call record object for the most recent call to the spy.
**Returns**:

- A table containing the call record (`{args, timestamp, result?, error?}`) for the most recent call, or nil if the spy was never called.

**Example**:

```lua
local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
spy_fn("first")
spy_fn("second", "arg")
local last_call_record = spy_fn:last_call()
expect(last_call_record.args[1]).to.equal("second")
expect(last_call_record.args[2]).to.equal("arg")
````

### spy:called_before(other_spy, [call_index])

Checks whether this spy was called before another spy.
**Parameters**:

- `other_spy` (spy): Another spy to compare with
- `call_index` (number, optional): The index of the call to check on the other spy (default: 1)

**Returns**:

- `true` if this spy was called before the other spy, `false` otherwise

**Example**:

local mocking = require("lib.mocking")
local fn1 = function() end
local fn2 = function() end
local spy1 = mocking.spy(fn1)
local spy2 = mocking.spy(fn2)
spy1() -- Called first
spy2() -- Called second
expect(spy1:called_before(spy2)).to.be_truthy()
expect(spy2:called_before(spy1)).to.equal(false)
expect(spy1:called_after(spy2)).to.equal(false)

````

### spy:called_after(other_spy, [call_index])

Checks whether the last call to this spy occurred after another spy's Nth call.
**Parameters**:

- `other_spy` (spy_object): Another spy to compare with
- `call_index` (number, optional): The index of the call to check on the other spy (default: 1)

**Returns**:

- `true` if this spy's last call was after the other spy's specified call, `false` otherwise

**Example**:

```lua
local mocking = require("lib.mocking")
local fn1 = function() end
local fn2 = function() end
local spy1 = mocking.spy(fn1)
local spy2 = mocking.spy(fn2)
spy1() -- Called first
spy2() -- Called second
expect(spy2:called_after(spy1)).to.be_truthy()
expect(spy1:called_after(spy2)).to.equal(false)
````

### spy:reset()

Resets the call history of the spy (`calls`, `call_count`, `called`, `call_sequence`). Does not restore original functions or change stub behavior.
**Returns**:

- The spy object (`self`) for chaining.

**Example**:

```lua
local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
spy_fn()
expect(spy_fn.call_count).to.equal(1)
spy_fn:reset()
expect(spy_fn.call_count).to.equal(0)
expect(spy_fn.called).to.equal(false)
```

### spy:restore()

Restores the original function/method if the spy was created for an object method.
**Example**:

````lua
local obj = { method = function() return "original" end }
local mocking = require("lib.mocking")
local obj = { method = function() return "original" end }
local spy_method = mocking.spy.on(obj, "method")
expect(obj.method()).to.equal("original") -- Calls through to original
spy_method:restore()
expect(obj.method == original_method).to.be_truthy() -- Original function is restored

### spy:and_call_through()

Configures the spy to call the original function (if one was provided or spied upon). This is the default behavior.
**Returns**: The spy object (`self`) for chaining.

### spy:and_call_fake(fn)

Configures the spy to call the provided fake function instead of the original one.
**Parameters**:
- `fn` (function): The fake implementation function.
**Returns**: The spy object (`self`) for chaining.

### spy:and_return(value)

Configures the spy to return a fixed value instead of calling any function.
**Parameters**:
- `value` (any): The value to return.
**Returns**: The spy object (`self`) for chaining.

### spy:and_throw(error_value)

Configures the spy to throw an error when called.
**Parameters**:
- `error_value` (any): The error to throw.
**Returns**: The spy object (`self`) for chaining.

### mocking.spy.assert(spy_obj)

Creates an assertion helper object for the given spy, allowing chainable assertions like `expect(spy.assert(my_spy).was_called_with("arg"))`. (Note: This is less commonly used than the direct `expect(spy).to.be.called...` style).
**Parameters**:
- `spy_obj` (spy_object): The spy object to create assertions for.
**Returns**: An assertion helper object (`spy_assert`) or `nil`, `error`.

### mocking.spy.get_all_spies()

Returns a list of all spy objects created by the module.
**Returns**: `table<number, spy_object>`

### mocking.spy.reset_all()

Resets the call history for all spies created by the module.
**Returns**: `boolean, table?` (success, error)

### mocking.spy.wrap(fn, options?)

Creates a spy wrapping `fn` with optional behavior modifiers. Similar to `new` but allows configuring `and_*` behavior upfront.
**Parameters**:
- `fn` (function): The function to wrap.
- `options` (table, optional): Options like `{ callThrough?, callFake?, returnValue?, throwError? }`.
**Returns**: `spy_object|nil, table?` (spy, error)
## Stub Functions

### mocking.stub(return_value_or_implementation)

Creates a standalone stub function that returns a specific value or uses a custom implementation. The stub system integrates with the logging system for detailed diagnostics and error handling.
**Parameters**:
```lua

---@param return_value_or_implementation any|function Value to return when stub is called, or function to use as implementation
---@return Stub The created stub object

```text
**Returns**:

- A stub function that returns the specified value or executes the specified function

**Example**:
```lua

local mocking = require("lib.mocking")
-- Stub with a return value
local get_config = mocking.stub({debug = true, timeout = 1000})
local config = get_config() -- Returns {debug = true, timeout = 1000}
-- Stub with a function implementation
local calculate = mocking.stub(function(a, b) return a * b end)
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

```text
### mocking.stub.new(return_value_or_implementation)

Creates a new standalone stub function that returns a specified value or uses custom implementation.
**Parameters**:

- `return_value_or_implementation` (any|function, optional): Value to return when stub is called, or function to use as implementation

**Returns**:

- A stub object

**Example**:
```lua

local mocking = require("lib.mocking")
-- Create a stub with a fixed return value
local stub = mocking.stub.new("fixed value")
expect(stub()).to.equal("fixed value")
-- Create a stub with custom implementation
local custom_stub = mocking.stub.new(function(arg1, arg2)
  return arg1 * arg2
end)
expect(custom_stub(3, 4)).to.equal(12)

```text

### mocking.stub.on(obj, method_name, value_or_impl)

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
local mocking = require("lib.mocking")
local stub = mocking.stub.on(obj, "method", "stubbed")
expect(obj.method()).to.equal("stubbed")
-- Restore the original method
stub:restore()
expect(obj.method()).to.equal("original")

```text

### stub:returns(value)

Configure stub to return a specific value.
**Parameters**:

- `value` (any): The value to return when the stub is called

**Returns**:

- A new stub configured to return the specified value

**Example**:
```lua

local mocking = require("lib.mocking")
local stub = mocking.stub(nil)
stub:returns("new value") -- Modifies stub in-place
expect(stub()).to.equal("new value")

```text

### stub:returns_in_sequence(values)

Configure stub to return values from a sequence in order.
**Parameters**:

- `values` (table): An array of values to return in sequence

**Returns**:

- A new stub configured with sequence behavior

**Example**:
```lua

local mocking = require("lib.mocking")
local stub = mocking.stub():returns_in_sequence({"first", "second", "third"})
expect(stub()).to.equal("first")
expect(stub()).to.equal("second")
expect(stub()).to.equal("third")
expect(stub()).to.equal(nil) -- Sequence exhausted

```text

### stub:matches(matcher_fn)

Configure a stub to respond differently based on argument matching.
**Parameters**:
```lua

---@param matcher_fn function Function that takes arguments and returns boolean
---@return Stub The stub object for method chaining

```text
**Returns**:

- The stub object for method chaining

**Example**:
```lua

local mocking = require("lib.mocking")
local api_stub = mocking.stub()
  :matches(function(id)
    return type(id) == "number" and id > 0
  end)
  :returns({ status = "success", data = "valid id" })
  :otherwise()
  :returns({ status = "error", message = "invalid id" })
expect(api_stub(123)).to.deep_equal({ status = "success", data = "valid id" })
expect(api_stub("abc")).to.deep_equal({ status = "error", message = "invalid id" })

```text

### stub:cycle_sequence(enable)

Configure whether the sequence of return values should cycle.
**Parameters**:

- `enable` (boolean, optional): Whether to enable cycling (defaults to true)

**Returns**:

- The stub object for method chaining

**Example**:
```lua

local mocking = require("lib.mocking")
local stub = mocking.stub()
  :returns_in_sequence({"red", "yellow", "green"})
  :cycle_sequence()
expect(stub()).to.equal("red")
expect(stub()).to.equal("yellow")
expect(stub()).to.equal("green")
expect(stub()).to.equal("red") -- Cycles back to beginning

```text

### stub:when_exhausted(behavior, [custom_value])

Configure what happens when a sequence is exhausted.
**Parameters**:

- `behavior` (string): One of:
- `"nil"`: Return nil (default behavior)
- `"error"`: Throw an error.
- `"fallback"`: Fall back to the original implementation (if available).
- `"custom"`: Return a custom value (`custom_value` must be provided).
- `custom_value` (any, optional): Value to return when behavior is "custom"

**Returns**:

- The stub object for method chaining

**Example**:
```lua

local mocking = require("lib.mocking")
-- Return a custom error object when exhausted
local stub = mocking.stub()
  :returns_in_sequence({"first", "second"})
  :when_exhausted("custom", "sequence ended")
expect(stub()).to.equal("first")
expect(stub()).to.equal("second")
expect(stub()).to.equal("sequence ended")

```text

### stub:reset_sequence()

Reset sequence to the beginning.
**Returns**:

- The stub object for method chaining

**Example**:
```lua

local mocking = require("lib.mocking")
local stub = mocking.stub():returns_in_sequence({1, 2, 3})
expect(stub()).to.equal(1)
expect(stub()).to.equal(2)
expect(stub()).to.equal(3)
expect(stub()).to.equal(nil) -- Exhausted
stub:reset_sequence() -- Reset to start
expect(stub()).to.equal(1) -- Starts over

```text

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

```text
**Example**:
```lua

local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
-- Create a stub with enhanced error handling (Note: with_error_handling is not yet implemented)
-- local database_stub = mocking.stub()
--  :with_error_handling({
--    capture_stack = true,
--    capture_args = true,
    log_errors = true
  })
  :throws(error_handler.runtime_error("Database connection failed", {
    operation = "connect",
    category = error_handler.CATEGORY.EXTERNAL_SERVICE
  }))
-- When the stub is called, it would (if implemented) throw a detailed error
-- with stack info, arguments, and automatically log to the logging system

```text

### stub:with_error_handling(options)

Configure stub with enhanced error handling options. **(Not Currently Implemented in stub.lua)**
**Parameters**:
```lua

---@param options table
---@field capture_stack boolean Whether to capture stack information
---@field capture_args boolean Whether to capture arguments in errors
---@field log_errors boolean Whether to log errors to the logging system
---@field debug_mode boolean Whether to enable detailed debug information
---@return Stub The stub object for method chaining

```text

### stub:throws(error_message)

Configure stub to throw an error when called.
**Parameters**:

- `error_message` (string|table): The error message or error object to throw

**Returns**:

- A new stub configured to throw the specified error

**Example**:
```lua

local mocking = require("lib.mocking")
local stub = mocking.stub():throws("test error")
-- Using expect to verify the error
expect(function()
  stub()
end).to.throw("test error")

```text

### stub:restore()

Restore the original method (for stubs created with stub.on).
**Example**:
```lua

local obj = {
  method = function() return "original" end
}
local mocking = require("lib.mocking")
local stub = mocking.stub.on(obj, "method", "stubbed")
expect(obj.method()).to.equal("stubbed")
stub:restore() -- Restore the original method
expect(obj.method()).to.equal("original")

```text
### mocking.stub.from_spy(spy_obj)

Creates a stub from an existing spy object, inheriting its call history and allowing stub configuration (`returns`, `throws`, etc.).
**Parameters**:
- `spy_obj` (spy_object): The spy object to convert.
**Returns**: `stub_object|nil, table?` (stub, error)

### mocking.stub.reset_all()

Resets the call history for all stubs created by the module.
**Returns**: `boolean, table?` (success, error)

### mocking.stub.sequence(values)

Creates a stub that returns values from a table in sequence. **(Currently Unimplemented)**
**Parameters**:
- `values` (table): An array of values to return.
**Returns**: `stub_object|nil, table?` (stub, error)

## Mock Objects

### mocking.mock(target, [method_or_options], [impl_or_value])

Create a mock object with controlled behavior.
**Parameters**:

- `target` (table): The object to create a mock of
- `method_or_options` (string|table, optional): Either a method name to stub or options table
- `impl_or_value` (any, optional): The implementation or return value for the stub (when method specified)

**Returns**:

- A mock object

**Example**:
```lua

local mocking = require("lib.mocking")
-- Create a mock object and stub a method in one call
local database = { query = function() end }
local mock_db = mocking.mock(database, "query", { rows = 10 })
expect(database.query()).to.deep_equal({ rows = 10 })
-- Create a mock with options
local obj = { method = function() end }
local mock_obj = mocking.mock(obj, { verify_all_expectations_called = true })

```text

### mocking.mock.create(target, [options])

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
local mocking = require("lib.mocking")
local mock_fs = mocking.mock.create(file_system)

```text

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
local mocking = require("lib.mocking")
local database = { query = function() end }
local db_mock = mocking.mock(database)
db_mock:stub("query", function(query_string)
  return {rows = {{id = 1, name = "test"}}}
end)

```text

### mock:stub_in_sequence(name, sequence_values)

Stub a method on the mock object to return different values on successive calls.
**Parameters**:

- `name` (string): Name of the method to stub
- `sequence_values` (table): Array of values to return in sequence on successive calls

**Returns**:

- The stub object for method chaining

**Example**:
```lua

local mocking = require("lib.mocking")
local api = { get_status = function() return "online" end }
local mock_api = mocking.mock(api)
mock_api:stub_in_sequence("get_status", {
  "starting",
  "connecting",
  "online",
  "disconnecting"
})

```text

### mock:restore_stub(name)

Restore the original implementation of a specific stubbed method.
**Parameters**:

- `name` (string): Name of the method to restore

**Returns**:

- The mock object for method chaining

**Example**:
```lua

local mocking = require("lib.mocking")
local obj = { method = function() return "original" end }
local mock_obj = mocking.mock(obj)
mock_obj:stub("method", function() return "stubbed" end)
expect(obj.method()).to.equal("stubbed")
mock_obj:restore_stub("method")
expect(obj.method()).to.equal("original")

```text

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
local mocking = require("lib.mocking")
local obj = {
  method1 = function() return "original1" end,
  method2 = function() return "original2" end
}
local mock_obj = mocking.mock(obj)
mock_obj:stub("method1", function() return "stubbed1" end)
mock_obj:stub("method2", function() return "stubbed2" end)
mock_obj:restore()
```text

### mock:verify()

Verify that all expected method calls were made. Checks stubs marked with `verify_all_expectations_called` (default true) and any specific expectations set with `mock:expect()`.
**Returns**:
- `success` (boolean|nil): `true` if verification passes, `false` if expectations unmet, `nil` on critical error.
- `error` (table|nil): Error object containing failure details (`error.context.failures`) if verification fails or a critical error occurred.

**Example**:
```lua

local mocking = require("lib.mocking")
local obj = { method = function() end }
local mock_obj = mocking.mock(obj)
mock_obj:stub("method", function() return "stubbed" end)
obj.method() -- Call the stubbed method
local success, err = mock_obj:verify() -- Passes because method was called
expect(success).to.be_truthy()

```text

### mock:spy(name)

Creates a spy on a method of the target object, tracking calls without changing behavior.
**Parameters**:
- `name` (string): The method name to spy on.
**Returns**: `mockable_object|nil, table?` (self, error)

### mock:expect(name)

Sets up an expectation for a method call, allowing verification of calls with specific arguments or counts.
**Parameters**:
- `name` (string): The method name to expect.
**Returns**: `expectation|nil, table?` (expectation object, error)

### mock:stub_property(name, value)

Replaces a property on the target object with a fixed value.
**Parameters**:
- `name` (string): The property name.
- `value` (any): The value to set.
**Returns**: `mockable_object|nil, table?` (self, error)

### mock:reset()

Resets the mock by restoring all stubbed methods/properties. Alias for `restore()`.
**Returns**: `mockable_object|nil, table?` (self, error)

### mocking.mock.restore_all()

Restores all mocks created by the module globally.
**Returns**: `boolean, table?` (success, error)

### mocking.mock.reset_all()

Resets all mocks created by the module globally. Alias for `restore_all()`.
**Returns**: `boolean, table?` (success, error)

## Context Manager

### mocking.with_mocks(fn)

Execute a function with automatic mock cleanup, even if an error occurs.
Executes a function within a managed context that guarantees automatic restoration of all mocks created inside it, even if errors occur.
**Parameters**:

- `fn` (function): Function to execute. It receives context-aware creators: `mock_fn(target, method?, impl?)`, `spy(target?, name?)`, and `stub(impl?)`.

**Example**:
```lua

local mocking = require("lib.mocking")
local obj = { method = function() return "original" end }
mocking.with_mocks(function(mock_fn, spy, stub) -- Pass creators to fn
  -- Create mocks inside the context using provided functions
  local mock_obj = mock_fn(obj) -- Uses context-aware mock creator
  mock_obj:stub("method", function() return "stubbed" end)

  -- Use the mock
  expect(obj.method()).to.equal("stubbed")

  -- No need to restore, happens automatically on exit
end)
-- Outside the context, original method is restored
expect(obj.method()).to.equal("original")

```text

## Integration with Expect

The mocking system integrates with Firmo's expectation system for fluent verification of mock behaviors:
```lua

-- Using the expect API with mocks and spies
local mocking = require("lib.mocking")
local fn = function() end
local spy_fn = mocking.spy(fn)
spy_fn("test")
-- All of these assertions work with spies
expect(spy_fn).to.be.called()
expect(spy_fn).to.be.called.once()
expect(spy_fn).to.be.called.times(1)
expect(spy_fn).to.be.called.with("test")
expect(spy_fn).to.have.been.called.before(other_spy)

```text

## Type Annotations

The mocking system includes comprehensive type annotations for IDE support (Luau).

## Mocking Module API

The main `mocking` module (`require("lib.mocking")`) provides several top-level helper functions:

### mocking.create_spy(fn?)

Creates a standalone spy function via `spy.new`.
**Parameters**: `fn` (function, optional)
**Returns**: `spy_object|nil, table?` (spy, error)

### mocking.create_stub(return_value?)

Creates a standalone stub function via `stub.new`.
**Parameters**: `return_value` (any, optional)
**Returns**: `stub_object|nil, table?` (stub, error)

### mocking.create_mock(methods?)

Creates a mock object from scratch (no target object) via `mock.create({})`.
**Parameters**: `methods` (table, optional): Table defining methods `{ name = impl_or_value, ... }`.
**Returns**: `mockable_object|nil, table?` (mock, error)

### mocking.is_spy(obj)

Checks if an object is a spy created by this system.
**Parameters**: `obj` (any)
**Returns**: `boolean`

### mocking.is_stub(obj)

Checks if an object is a stub created by this system.
**Parameters**: `obj` (any)
**Returns**: `boolean`

### mocking.is_mock(obj)

Checks if an object is a mock created by this system.
**Parameters**: `obj` (any)
**Returns**: `boolean`

### mocking.get_all_mocks()

Gets a list of all active mocks tracked globally.
**Returns**: `table<number, mockable_object>`

### mocking.verify(mock_obj)

Verifies expectations for a specific mock object via `mock.verify`.
**Parameters**: `mock_obj` (mockable_object)
**Returns**: `boolean|nil, table?` (success, error)

### mocking.reset_all()

Resets all spies, stubs, and mocks globally by calling `mock.restore_all()`.
**Returns**: `boolean, table?` (success, error)

### mocking.register_cleanup_hook(after_test_fn?)

Registers a composite cleanup hook (suitable for `firmo.after`) that runs the optional `after_test_fn` then `mock.restore_all()`.
**Parameters**: `after_test_fn` (function, optional)
**Returns**: `function` (the composite hook function)

### mocking.configure(options)

Configures the mocking system (placeholder, currently no options).
**Parameters**: `options` (table)
**Returns**: `mocking` module table

## Version Information

### mocking.mock._VERSION

String identifier for the mock module version.
**Example**:
```lua

local mocking = require("lib.mocking")
print(mocking.mock._VERSION) -- e.g., "1.0.0"

```text

### mocking.spy._VERSION

String identifier for the spy module version.
**Example**:
```lua

local mocking = require("lib.mocking")
print(mocking.spy._VERSION) -- e.g., "1.0.0"

```text

### mocking.stub._VERSION

String identifier for the stub module version.
**Example**:
```lua

local mocking = require("lib.mocking")
print(mocking.stub._VERSION) -- e.g., "1.0.0"
````
