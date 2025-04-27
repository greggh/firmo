--- Common Lua Error Fixtures
---
--- This module provides a collection of functions designed to intentionally
--- produce common Lua runtime errors. These are used in tests to verify
--- error handling, stack trace generation, and debugging features.
---
--- @module tests.fixtures.common_errors
--- @author Firmo Team
--- @fixture

---@class CommonErrorFixtures Functions designed to trigger specific Lua errors.
---@field nil_access fun(): any Throws error by accessing a field on a nil value. @throws error
---@field type_error fun(): any Throws error by attempting to call a string method on a number. @throws error
---@field arithmetic_error fun(): any Throws error by dividing by zero. @throws error
---@field out_of_memory fun(limit?: number): table, string? Attempts to consume memory up to a limit. May return table and "Memory limit approached" string, or potentially trigger an actual OOM error depending on system/limit. @throws error
---@field stack_overflow fun(depth?: number): number Attempts to cause stack overflow via deep recursion. @throws error
---@field assertion_error fun(): any Throws an assertion failure via `assert(false)`. @throws error
---@field custom_error fun(message?: string): any Throws a custom error message via `error()`. @throws error
---@field runtime_error fun(): any Triggers a runtime error by loading and executing code with a type mismatch. @throws error
---@field slow_function fun(seconds?: number): string Executes a busy-wait loop for a specified duration.
---@field memory_leak fun(iterations?: number): number Intentionally leaks memory into a global table for testing leak detection. Returns size of leak table.
---@field clear_leak_data fun(): nil Clears the global table used by `memory_leak` and runs garbage collection.
---@field upvalue_capture_error fun(): any Throws error by accessing a missing field through an upvalue closure. @throws error
---@field circular_reference fun(): table Creates and returns a table with a circular reference (`t.self = t`).
---@field pcall_error fun(): any Returns the error message captured by `pcall` from an internal `error()` call.
local fixtures = {}

--- Attempts to access a property on a nil value, causing an error.
---@throws error "attempt to index a nil value"
function fixtures.nil_access()
  local t = nil
  return t.property -- Accessing property of nil value
end

--- Attempts to call a string method on a number, causing a type error.
---@throws error "attempt to call a number value"
function fixtures.type_error()
  local num = 42
  return num:upper() -- Attempting to call method on number
end

--- Attempts to divide by zero, causing an arithmetic error.
---@throws error "attempt to divide by zero"
function fixtures.arithmetic_error()
  return 1 / 0 -- Division by zero
end

--- Attempts to allocate large amounts of memory to simulate an out-of-memory condition.
--- May return early if limit approached based on `collectgarbage("count")`.
---@param limit? number Iteration limit (default 1,000,000). Controls memory allocation attempts.
---@return table, string? Returns the large table created and potentially a warning string "Memory limit approached", or triggers OOM.
---@throws error May trigger an out-of-memory error depending on system resources and `limit`.
function fixtures.out_of_memory(limit)
  limit = limit or 1000000 -- Default to reasonable limit to avoid actual OOM
  local t = {}
  for i = 1, limit do
    table.insert(t, string.rep("x", 100))
    if i % 10000 == 0 then
      collectgarbage("collect")
      -- Check if we're getting close to memory limits
      -- and abort early if needed
      if collectgarbage("count") > 1000000 then
        return t, "Memory limit approached"
      end
    end
  end
  return t
end

--- Attempts to cause a stack overflow through deep recursion.
---@param depth? number Recursion depth limit (default 5000).
---@return number The result of the recursion (usually 0 if it completes without error).
---@throws error "stack overflow" If the recursion depth exceeds the system limit.
function fixtures.stack_overflow(depth)
  depth = depth or 5000 -- Default to reasonable depth to avoid actual crash

  local function recurse(n)
    if n <= 0 then return 0 end
    return 1 + recurse(n - 1)
  end

  return recurse(depth)
end

--- Triggers an assertion failure using `assert(false)`.
---@throws error "assertion failed!" or the custom message provided to assert.
function fixtures.assertion_error()
  assert(false, "This is an assertion error")
end

--- Throws an error using `error()` with a customizable message.
---@param message? string Custom error message (default: "This is a custom error").
---@throws error The provided or default error message.
function fixtures.custom_error(message)
  error(message or "This is a custom error", 2)
end

--- Dynamically loads and executes code containing a runtime error (type mismatch).
---@return any Result of the loaded code (never reached).
---@throws error "attempt to perform arithmetic on a string value" (or similar).
function fixtures.runtime_error()
  local code = "function x() local y = 1 + 'string' end; x()"
  return load(code)()
end

--- Simulates a slow operation using a busy-wait loop.
---@param seconds? number Duration in seconds (default 1).
---@return string Completion message indicating the duration.
function fixtures.slow_function(seconds)
  seconds = seconds or 1
  local start = os.time()
  while os.time() - start < seconds do
    -- Busy wait
  end
  return "Completed after " .. seconds .. " seconds"
end

--- Intentionally leaks memory by storing large strings in a global table `_G._test_leak_storage`.
--- FOR TESTING MEMORY LEAK DETECTION ONLY. Use `clear_leak_data` afterwards.
---@param iterations? number Number of strings to add (default 10).
---@return number The total number of items currently in the leak storage table.
function fixtures.memory_leak(iterations)
  iterations = iterations or 10

  -- This is a controlled leak for testing leak detection
  _G._test_leak_storage = _G._test_leak_storage or {}

  for i = 1, iterations do
    table.insert(_G._test_leak_storage, string.rep("leak test data", 1000))
  end

  return #_G._test_leak_storage
end

--- Clears the global data used by `memory_leak` (`_G._test_leak_storage`) and triggers garbage collection.
---@return nil
function fixtures.clear_leak_data()
  _G._test_leak_storage = nil
  collectgarbage("collect")
end

--- Creates a closure that captures an upvalue (table `t`), then attempts to access a non-existent field through it.
---@return any Result of the closure call (never reached).
---@throws error "attempt to index a nil value" (on `missing_field`).
function fixtures.upvalue_capture_error()
  local t = {value = 10}
  local function outer()
    return function()
      return t.missing_field.something
    end
  end

  return outer()()
end

--- Creates and returns a simple table containing a circular reference (`t.self = t`).
---@return table The table with the circular reference.
function fixtures.circular_reference()
  local t = {}
  t.self = t
  return t
end

--- Uses `pcall` to capture an error thrown internally by `error()` and returns the error message/value.
---@return any The captured error message/value ("Error inside pcall").
function fixtures.pcall_error()
  return select(2, pcall(function() error("Error inside pcall") end))
end

return fixtures
