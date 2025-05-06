# Assertion Module API Reference

---@diagnostic disable: unused-local

The assertion module provides a comprehensive, standalone implementation of expect-style assertions for the Firmo testing framework. It includes a rich set of chainable assertions, deep equality comparisons, type checking (`isa`), structured error reporting, and integration with the coverage system.

## Core Functions


### assertion.expect(value)


The primary function to start an assertion chain. Takes any value and returns an assertion object with chainable methods.
**Parameters:**


- `value` (any): The value to create assertions for

**Returns:**


- An assertion object with chainable assertion methods (ExpectChain)

**Example:**


```lua
local assertion = require("lib.assertion")
assertion.expect(42).to.equal(42)
assertion.expect("hello").to.be.a("string")
```



### assertion.eq(v1, v2, [epsilon], [visited])


Deep equality comparison function with cycle detection and epsilon comparison for numbers.
**Parameters:**


- `v1` (any): First value to compare
- `v2` (any): Second value to compare
- `epsilon` (number, optional): Epsilon value for floating point comparisons (default: 0)
- `visited` (table, optional): Table for tracking visited objects (for internal use)

**Returns:**


- `boolean`: True if values are considered equal

**Example:**


```lua
local assertion = require("lib.assertion")
local result = assertion.eq({a = 1, b = {c = 2}}, {a = 1, b = {c = 2}})
-- result is true
```



### assertion.isa(value, expected_type)


Type checking function that works with both basic types and metatables.
**Parameters:**


- `value` (any): The value to check
- `expected_type` (string|table): Type string or metatable to check against

**Returns:**


- `boolean`: True if value is of the expected type
- `string`: Success message (for internal use)
- `string`: Failure message (for internal use)

**Throws:** An error if `expected_type` is not a string or table.

**Example:**


```lua
local assertion = require("lib.assertion")
local result = assertion.isa(42, "number")
-- result is true
```



## ExpectChain Methods


The `expect()` function returns an ExpectChain object with the following chainable methods:

### .to / .to_not


Properties to indicate positive or negative assertion chains.
**Example:**


```lua
expect(42).to.equal(42)
expect(42).to_not.equal(43)
```



### .exist()


Asserts that a value is not nil.
**Example:**


```lua
expect(42).to.exist()
expect(nil).to_not.exist()
```



### .equal(expected, [epsilon])


Performs a deep comparison between the actual and expected values.
**Parameters:**


- `expected` (any): The expected value
- `epsilon` (number, optional): For floating point comparisons, maximum allowable difference

**Example:**


```lua
expect(42).to.equal(42)
expect({a = 1, b = 2}).to.equal({a = 1, b = 2})
expect(0.1 + 0.2).to.equal(0.3, 0.0001) -- With epsilon for floating point
```



### .be(expected)


Checks equality using the `==` operator.
**Parameters:**


- `expected` (any): The expected value

**Example:**


```lua
expect(5).to.be(5) -- Same as 5 == 5
```



### .be.a(type) / .be.an(type)


Asserts that a value is of the specified type.
**Parameters:**


- `type` (string|table): Type name as string or metatable for inheritance checks

**Example:**


```lua
expect(42).to.be.a("number")
expect("hello").to.be.a("string")
expect({}).to.be.a("table")
expect(function() end).to.be.a("function")
expect(MyClass:new()).to.be.a(MyClass) -- Checks against metatable
```



### .be_truthy()


Asserts that a value is truthy (not nil and not false).
**Example:**


```lua
expect(true).to.be_truthy()
expect(42).to.be_truthy()
expect(false).to_not.be_truthy()
expect(nil).to_not.be_truthy()
```



### .be_falsy() / .be_falsey()


Asserts that a value is falsy (nil or false).
**Example:**


```lua
expect(false).to.be_falsy()
expect(nil).to.be_falsy()
expect(true).to_not.be_falsy()
expect(42).to_not.be_falsy()
```


### .be_nil()

Asserts that a value is exactly `nil`.
**Example:**

```lua
expect(nil).to.be_nil()
expect(false).to_not.be_nil()
```

### .match(pattern)


Asserts that a string matches the given Lua pattern.
**Parameters:**


- `pattern` (string): Lua pattern to match against the string

**Example:**


```lua
expect("hello world").to.match("hello")
expect("test123").to.match("%a+%d+")
```



### .match_regex(pattern, [options])


Asserts that a string matches the given regular expression pattern with optional configuration.
**Parameters:**


- `pattern` (string): Regex pattern to match
- `options` (table, optional): Configuration options
  - `case_insensitive` (boolean): If true, performs case-insensitive matching
  - `multiline` (boolean): If true, allows ^ and $ to match start/end of lines

**Example:**


```lua
expect("hello world").to.match_regex("hello")
expect("HELLO").to.match_regex("hello", { case_insensitive = true })
```


### .match_with_options(pattern, options)

Asserts that a string matches the given Lua pattern with custom matching options.
**Parameters:**

- `pattern` (string): Lua pattern to match against the string
- `options` (table): Configuration options
  - `case_insensitive` (boolean): If true, performs case-insensitive matching
  - `full` (boolean): If true, matches the entire string (anchors pattern with ^ and $)
  - `multi_line` (boolean): If true, allows ^ and $ to match start/end of lines

**Example:**

```lua
expect("Hello World").to.match_with_options("hello", { case_insensitive = true })
expect("TESTING").to.match_with_options("test", { case_insensitive = true })
expect("abc123def").to.match_with_options("abc%d+", { full = false }) // partial match
```


### .match.fully(pattern)

Asserts that a string fully matches the given Lua pattern (entire string must match, not just a substring).
**Parameters:**

- `pattern` (string): Lua pattern to match against the string

**Example:**

```lua
expect("abc123").to.match.fully("%a+%d+") // matches
expect("abc123def").to_not.match.fully("%a+%d+") // doesn't match entire string
```


### .match.any_of(patterns)

Asserts that a string matches at least one of the provided Lua patterns.
**Parameters:**

- `patterns` (table): Array of Lua patterns to match against the string

**Example:**

```lua
expect("abc").to.match.any_of({ "%a+", "%d+", "%p+" })
expect("123").to.match.any_of({ "%a+", "%d+", "%p+" })
expect("!!!").to.match.any_of({ "%a+", "%d+", "%p+" })
```


### .match.all_of(patterns)

Asserts that a string matches all of the provided Lua patterns.
**Parameters:**

- `patterns` (table): Array of Lua patterns to match against the string

**Example:**

```lua
expect("abc123").to.match.all_of({ "%a", "%d" })
expect("Password123!").to.match.all_of({ "%a", "%d", "%p" })
expect("abc").to_not.match.all_of({ "%a", "%d" })
```


### .contain(value)


Asserts that a string or table contains the specified value.
**Parameters:**


- `value` (any): The value to look for

**Example:**


```lua
expect("hello world").to.contain("world") -- String containment
expect({1, 2, 3}).to.contain(2) -- Table containment
```



### .key(key)

Asserts that a table contains the specified key.
**Parameters:**

- `key` (any): The key to check for

**Example:**

```lua
expect({name = "test", id = 1}).to.have.key("name")
```


### .keys(keys)

Asserts that a table contains all the specified keys.
**Parameters:**

- `keys` (table): An array of keys to check for

**Example:**

```lua
expect({a = 1, b = 2, c = 3}).to.have.keys({"a", "b"})
```



### .fail()


Asserts that a function throws an error when called.
**Example:**


```lua
expect(function() error("Something went wrong") end).to.fail()
```



### .fail.with(pattern)


Asserts that a function throws an error matching the given pattern.
**Parameters:**


- `pattern` (string): Lua pattern to match against the error message

**Example:**


```lua
expect(function() error("Invalid input") end).to.fail.with("Invalid")
```



### .have_length(length) / .have_size(size)


Asserts that a string or table has a specific length.
**Parameters:**


- `length` (number): The expected length

**Example:**


```lua
expect("hello").to.have_length(5) -- String length
expect({1, 2, 3}).to.have_length(3) -- Array length
```



### .be.empty()


Asserts that a string or table is empty.
**Example:**


```lua
expect("").to.be.empty() -- Empty string
expect({}).to.be.empty() -- Empty table
```



### .have_property(property_name, [expected_value])


Asserts that an object has a specific property, optionally with a specific value.
**Parameters:**


- `property_name` (string): The name of the property to check for
- `expected_value` (any, optional): The expected value of the property

**Example:**


```lua
local obj = {name = "John", age = 30}
expect(obj).to.have_property("name") -- Just check property exists
expect(obj).to.have_property("age", 30) -- Check property has specific value
```



### .match_schema(schema)


Asserts that an object matches a specified schema of property types or values.
**Parameters:**


- `schema` (table): A table specifying property types or exact values

**Example:**


```lua
expect({name = "John", age = 30}).to.match_schema({
  name = "string", -- Type check
  age = "number"   -- Type check
})
```



### .be_greater_than(value)


Asserts that a number is greater than the specified value.
**Parameters:**


- `value` (number): The value to compare against

**Example:**


```lua
expect(5).to.be_greater_than(3)
```



### .be_less_than(value)


Asserts that a number is less than the specified value.
**Parameters:**


- `value` (number): The value to compare against

**Example:**


```lua
expect(3).to.be_less_than(5)
```


### .be_between(min, max)

Asserts that a number is between the specified minimum and maximum values (inclusive).
**Parameters:**

- `min` (number): The minimum value (inclusive)
- `max` (number): The maximum value (inclusive)

**Example:**

```lua
expect(5).to.be_between(1, 10)
expect(1).to.be_between(1, 10)
expect(10).to.be_between(1, 10)
expect(11).to_not.be_between(1, 10)
```


### .be_near(expected, [tolerance]) / .be_approximately(expected, [tolerance])

Asserts that a number is close to the expected value within a given tolerance.
**Parameters:**

- `expected` (number): The target value to compare against.
- `tolerance` (number, optional): The maximum allowed difference (default: 0.0001).

**Example:**

```lua
expect(0.1 + 0.2).to.be_near(0.3) -- Uses default tolerance
expect(3.14159).to.be_near(3.14, 0.01)
expect(10.5).to.be_approximately(10, 1) -- Alias works the same
```


### .be_between(min, max)


Asserts that a number is between the specified minimum and maximum values (inclusive).
**Parameters:**


- `min` (number): The minimum value (inclusive)
- `max` (number): The maximum value (inclusive)

**Example:**


```lua
expect(5).to.be_between(1, 10)
```



### .be_approximately(target, delta)


Asserts that a number is approximately equal to the target value within the specified delta.
**Parameters:**


- `target` (number): The target value to compare against
- `delta` (number): The maximum allowed difference (default: 0.0001)

**Example:**


```lua
expect(0.1 + 0.2).to.be_approximately(0.3, 0.0001)
```


### .be_approximately(target, delta)

Asserts that a number is approximately equal to the target value within the specified delta.
**Parameters:**

- `target` (number): The target value to compare against
- `delta` (number): The maximum allowed difference (default: 0.0001)

**Example:**

```lua
expect(0.1 + 0.2).to.be_approximately(0.3) -- Uses default tolerance
expect(3.14159).to.be_approximately(3.14, 0.01)
```


### .be.positive()


Asserts that a number is greater than zero.
**Example:**


```lua
expect(5).to.be.positive()
```



### .be.negative()


Asserts that a number is less than zero.
**Example:**


```lua
expect(-5).to.be.negative()
```



### .be.integer()


Asserts that a number is an integer (whole number with no decimal part).
**Example:**


```lua
expect(5).to.be.integer()
expect(5.5).to_not.be.integer()
```



### .be.uppercase()


Asserts that a string contains only uppercase characters.
**Example:**


```lua
expect("HELLO").to.be.uppercase()
expect("Hello").to_not.be.uppercase()
```



### .be.lowercase()


Asserts that a string contains only lowercase characters.
**Example:**


```lua
expect("hello").to.be.lowercase()
expect("Hello").to_not.be.lowercase()
```


### .start_with(prefix)

Asserts that a string starts with the specified prefix.
**Parameters:**

- `prefix` (string): The expected starting substring

**Example:**

```lua
expect("hello world").to.start_with("hello")
expect("test").to_not.start_with("best")
```


### .end_with(suffix)

Asserts that a string ends with the specified suffix.
**Parameters:**

- `suffix` (string): The expected ending substring

**Example:**

```lua
expect("hello world").to.end_with("world")
expect("testing").to_not.end_with("fest")
```


### .have.deep_key(key_path)

Asserts that a table contains a deeply nested key specified by a path.
**Parameters:**

- `key_path` (string|table): The path to the key, either as a dot-separated string (e.g., "a.b.c") or a table of keys (e.g., `{"a", "b", "c"}`).

**Example:**

```lua
local data = { user = { profile = { name = "Alice" } } }
expect(data).to.have.deep_key("user.profile.name")
expect(data).to.have.deep_key({"user", "profile", "name"})
expect(data).to_not.have.deep_key("user.profile.email")
```


### .have.exact_keys(keys_table)

Asserts that a table contains *exactly* the keys specified in the array and no others.
**Parameters:**

- `keys_table` (table): An array-like table containing the exact set of keys expected.

**Example:**

```lua
expect({ a = 1, b = 2 }).to.have.exact_keys({ "a", "b" })
expect({ b = 2, a = 1 }).to.have.exact_keys({ "a", "b" }) -- Order doesn't matter
expect({ a = 1, b = 2, c = 3 }).to_not.have.exact_keys({ "a", "b" }) -- Fails due to extra key 'c'
expect({ a = 1 }).to_not.have.exact_keys({ "a", "b" }) -- Fails due to missing key 'b'
```


### .change(value_fn, [change_fn])


Asserts that executing a function changes the value returned by the value function.
**Parameters:**


- `value_fn` (function): A function that returns the value to check
- `change_fn` (function, optional): A function to validate the nature of the change

**Example:**


```lua
local obj = {count = 0}
expect(function() obj.count = obj.count + 1 end).to.change(function() return obj.count end)
```


### .satisfy(predicate)

Asserts that a value satisfies a custom predicate function.
**Parameters:**

- `predicate` (function): A function that takes the value and returns `true` if satisfied, `false` otherwise.

**Example:**

```lua
local function is_positive_number(v)
  return type(v) == "number" and v > 0
end
expect(10).to.satisfy(is_positive_number)
expect(-5).to_not.satisfy(is_positive_number)
expect("hello").to_not.satisfy(is_positive_number)
```

### .increase(value_fn)


Asserts that executing a function increases the numeric value returned by the value function.
**Parameters:**


- `value_fn` (function): A function that returns the numeric value to check

**Example:**


```lua
local counter = {value = 10}
expect(function() counter.value = counter.value + 1 end).to.increase(function() return counter.value end)
```



### .decrease(value_fn)


Asserts that executing a function decreases the numeric value returned by the value function.
**Parameters:**


- `value_fn` (function): A function that returns the numeric value to check

**Example:**


```lua
local counter = {value = 10}
expect(function() counter.value = counter.value - 1 end).to.decrease(function() return counter.value end)
```



### .deep_equal(expected)


Alias for equal that explicitly indicates deep equality comparison.
**Parameters:**


- `expected` (any): The expected value to compare against

**Example:**


```lua
expect({a = 1, b = {c = 2}}).to.deep_equal({a = 1, b = {c = 2}})
```



### .be_date()


Asserts that a string is a valid date in any of the supported formats (ISO, MM/DD/YYYY, DD/MM/YYYY).
**Example:**


```lua
expect("2023-10-15").to.be_date() -- ISO format
expect("10/15/2023").to.be_date() -- MM/DD/YYYY format
expect("15/10/2023").to.be_date() -- DD/MM/YYYY format
```



### .be_iso_date()


Asserts that a string is a valid date in ISO 8601 format.
**Example:**


```lua
expect("2023-10-15").to.be_iso_date()
expect("2023-10-15T14:30:15Z").to.be_iso_date()
```



### .be_before(other_date)


Asserts that a date string represents a date that is chronologically before another date.
**Parameters:**


- `other_date` (string): The date to compare against

**Example:**


```lua
expect("2022-01-01").to.be_before("2023-01-01")
```



### .be_after(other_date)


Asserts that a date string represents a date that is chronologically after another date.
**Parameters:**


- `other_date` (string): The date to compare against

**Example:**


```lua
expect("2023-01-01").to.be_after("2022-01-01")
```



### .be_same_day_as(other_date)


Asserts that a date string represents the same calendar day as another date.
**Parameters:**


- `other_date` (string): The date to compare against

**Example:**


```lua
expect("2022-01-01T10:30:00Z").to.be_same_day_as("2022-01-01T15:45:00Z")
```


### .be_same_day_as(other_date)

Asserts that a date string represents the same calendar day as another date.
**Parameters:**

- `other_date` (string): The date to compare against

**Example:**

```lua
expect("2022-01-01T10:30:00Z").to.be_same_day_as("2022-01-01T15:45:00Z")
expect("May 1, 2023").to.be_same_day_as("2023-05-01")
```


### .be_between_dates(start_date, end_date, inclusive)

Asserts that a date string represents a date that falls between two other dates.
**Parameters:**

- `start_date` (string): The start date of the range
- `end_date` (string): The end date of the range
- `inclusive` (boolean, optional): Whether the range includes the start and end dates (default: true)

**Example:**

```lua
expect("2023-05-15").to.be_between_dates("2023-05-01", "2023-05-31")
expect("2023-05-01").to.be_between_dates("2023-05-01", "2023-05-31") // inclusive by default
expect("2023-06-01").to_not.be_between_dates("2023-05-01", "2023-05-31")
expect("2023-05-01").to_not.be_between_dates("2023-05-01", "2023-05-31", false) // exclusive
```


## Async Assertions


These assertions require an async test context created with `async.test()`.

### .complete()


Asserts that an async function completes successfully.
**Example:**


```lua
async.test(function()
  expect(function(cb) async.set_timeout(function() cb("done") end, 10) end).to.complete()
end)
```



### .complete_within(timeout)


Asserts that an async function completes successfully within a time limit.
**Parameters:**


- `timeout` (number): Maximum time in milliseconds to wait for completion

**Example:**


```lua
async.test(function()
  expect(function(cb) async.set_timeout(function() cb("done") end, 10) end).to.complete_within(50)
end)
```



### .resolve_with(expected_value)


Asserts that an async function resolves with a specific value.
**Parameters:**


- `expected_value` (any): The expected resolution value

**Example:**


```lua
async.test(function()
  expect(function(cb) async.set_timeout(function() cb("expected") end, 10) end).to.resolve_with("expected")
end)
```



### .reject([error_pattern])


Asserts that an async function rejects with an error.
**Parameters:**


- `error_pattern` (string, optional): Pattern to match against the rejection error

**Example:**


```lua
async.test(function()
  expect(function(_, reject) async.set_timeout(function() reject("error") end, 10) end).to.reject()
end)
```



## Error Assertions (`.throw`)

These assertions check if a function throws an error.

### .throw()

Asserts that a function throws any error when called. Also aliased as `.throw.error()`.

**Example:**

```lua
expect(function() error("Error") end).to.throw()
expect(function() return 1 end).to_not.throw()
```


### .throw.error_matching(pattern)

Asserts that a function throws an error whose message matches the given Lua pattern.

**Parameters:**

- `pattern` (string): Lua pattern to match against the error message.

**Example:**

```lua
expect(function() error("Invalid input") end).to.throw.error_matching("Invalid")
expect(function() error("Other error") end).to_not.throw.error_matching("Invalid")
```


### .throw.error_type(type)

Asserts that a function throws an error of the specified type.

**Parameters:**

- `type` (string): The expected error type ("string", "table", etc.). Checks `type()` of the error value.

**Example:**

```lua
expect(function() error("Error message") end).to.throw.error_type("string")
expect(function() error({}) end).to.throw.error_type("table")
expect(function() return 1 end).to_not.throw.error_type("string")
```



## Extension Points


### assertion.paths


A table containing the assertion paths and test functions used to implement the expectation chain. Used for extending the system with custom assertions.
**Example:**


```lua
local assertion = require("lib.assertion")
-- Add a custom assertion
assertion.paths.to.is_even = {
  test = function(v)
    return v % 2 == 0,
      "expected " .. tostring(v) .. " to be even",
      "expected " .. tostring(v) .. " to not be even"
  end
}
-- Now you can use the custom assertion
assertion.expect(4).to.is_even()
assertion.expect(5).to_not.is_even()
```



## Error Handling


When an assertion fails, it throws an error with a descriptive message. If the `error_handler` module is available, it creates structured error objects with the following fields:


```lua
{
  message = "Assertion failed message",
  category = "VALIDATION",
  severity = "ERROR",
  context = {
    expected = expected_value,
    actual = actual_value,
    action = "equal",
    negate = false
  }
}
```


These structured errors can be caught and analyzed in tests with the `expect_error` flag.
