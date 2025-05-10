# Focused and Excluded Tests


This document describes how to use focused and excluded tests in Firmo, allowing you to run specific tests or skip certain tests temporarily.

## Overview


Firmo provides a powerful system for selectively running or skipping tests:


- **Focused Tests**: Run only tests marked as "focused" (using `fdescribe` or `fit`)
- **Excluded Tests**: Skip specific tests (using `xdescribe` or `xit`)

This is particularly useful during development when:


- You're working on a specific feature and only want to run relevant tests
- You need to disable problematic tests temporarily
- You want to focus on debugging a specific failing test


## Focused Tests


### fdescribe(name, fn)


Creates a focused test group. When focus mode is active, only focused test groups and their children will run.
**Parameters:**


- `name` (string): The name of the test group
- `fn` (function): The function containing the tests and nested groups

**Example:**


```lua
fdescribe("User Authentication", function()
  it("validates credentials", function()
    -- This test will run even in focus mode
  end)
  it("handles invalid passwords", function()
    -- This test will also run because it's in a focused group
  end)
end)
describe("User Profile", function()
  it("loads user data", function()
    -- This test will NOT run in focus mode because it's not focused
  end)
end)
```



### fit(name, fn)


Creates a focused test. When focus mode is active, only focused tests will run.
**Parameters:**


- `name` (string): The name of the test
- `fn` (function): The test function

**Example:**


```lua
describe("Data Validation", function()
  it("validates string inputs", function()
    -- This test will NOT run in focus mode
  end)
  fit("validates numeric inputs", function()
    -- This test WILL run in focus mode
  end)
  it("validates boolean inputs", function()
    -- This test will NOT run in focus mode
  end)
end)
```



## Excluded Tests


### xdescribe(name, fn)


Creates an excluded test group. Tests within this group will be skipped.
**Parameters:**


- `name` (string): The name of the test group
- `fn` (function): The function containing the tests and nested groups (these won't be executed)

**Example:**


```lua
describe("User Authentication", function()
  it("validates credentials", function()
    -- This test will run
  end)
end)
xdescribe("Database Operations", function()
  it("connects to database", function()
    -- This test will be skipped
  end)
  it("executes queries", function()
    -- This test will also be skipped
  end)
end)
```



### xit(name, fn)


Creates an excluded test. This test will be skipped.
**Parameters:**


- `name` (string): The name of the test
- `fn` (function): The test function (which won't be executed)

**Example:**


```lua
describe("Data Validation", function()
  it("validates string inputs", function()
    -- This test will run
  end)
  xit("validates numeric inputs", function()
    -- This test will be skipped
  end)
  it("validates boolean inputs", function()
    -- This test will run
  end)
end)
```



## Focus Mode Behavior


When any test is marked as focused (using `fdescribe` or `fit`), Firmo enters "focus mode." In focus mode:


1. Only focused tests or tests in focused groups will run
2. All other tests will be skipped (shown as "SKIP (not focused)" in the output)
3. Excluded tests (`xdescribe`, `xit`) are always skipped, even in focused groups


## Command Line Interaction


When running tests via the command line, focus mode works alongside tag and filter options:


```bash

# Run tests with focus mode respecting focused tests


lua firmo.lua tests/

# Focus mode can be combined with other filters


lua firmo.lua tests/ --tags unit
```


If filters are active (via tags or pattern) but no focused tests match the filters, no tests will run.

## Examples


### Basic Focus and Exclude Example



```lua
local firmo = require("firmo")
local describe, it, fit, xit = firmo.describe, firmo.it, firmo.fit, firmo.xit
describe("Calculator", function()
  it("adds numbers", function()
    -- Regular test, will be skipped if focus mode is active
  end)
  fit("subtracts numbers", function()
    -- Focused test, will ALWAYS run
  end)
  xit("divides numbers", function()
    -- Excluded test, will NEVER run
  end)
  it("multiplies numbers", function()
    -- Regular test, will be skipped if focus mode is active
  end)
end)
```



### Nested Focus Example



```lua
describe("User System", function()
  describe("Authentication", function()
    it("logs in users", function()
      -- Skipped in focus mode
    end)
    fit("validates passwords", function()
      -- Focused test, will run
    end)
  end)
  fdescribe("Authorization", function()
    it("checks permissions", function()
      -- Will run because parent is focused
    end)
    it("grants roles", function()
      -- Will run because parent is focused
    end)
    xit("revokes access", function()
      -- Excluded, won't run despite focused parent
    end)
  end)
end)
```



### Temporary Debugging Example



```lua
describe("Complex Algorithm", function()
  -- When debugging, focus the problematic test
  fit("handles edge case", function()
    local result = complex_algorithm({edge = true})
    expect(result).to.equal(expected_value)
  end)
  -- Other tests are skipped during focused debugging
  it("processes normal input", function()
    -- Skipped while focused test above exists
  end)
  it("handles empty input", function()
    -- Skipped while focused test above exists
  end)
end)
```



## Best Practices



1. **Use focus temporarily**: `fdescribe` and `fit` should be used as temporary development tools, not committed to your codebase permanently.
2. **Clean up before committing**: Remove or convert focused tests back to regular tests before committing code.
3. **Document excluded tests**: When using `xdescribe` or `xit` in committed code, add a comment explaining why the test is excluded and when it might be re-enabled.
4. **Avoid excluding in production**: Like focused tests, excluded tests should generally be temporary. Fix failing tests rather than permanently excluding them.
5. **Combine with tags**: For more permanent test organization, use tags instead of focus/exclude.
6. **CI protection**: Configure your CI pipeline to fail if focused tests are detected in committed code to prevent accidentally skipping tests in production.
7. **Use for debugging**: Focus is particularly useful during debugging to quickly iterate on a problematic test without running the entire suite.


## Implementation Details


When any test is marked as focused, the `firmo.focus_mode` flag is set to `true`. This causes all non-focused tests to be skipped during execution. When tests are excluded, they are effectively replaced with empty functions that never run.
The focus system is implemented to be explicit and deterministic, ensuring that:


1. Focus takes precedence over normal execution
2. Exclusion takes precedence over focus
3. The order of execution remains consistent

This makes the behavior predictable and reliable for development and debugging workflows.
