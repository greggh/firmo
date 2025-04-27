# Test Filtering API


This document describes the test filtering and tagging capabilities provided by Firmo.

## Overview


Firmo provides a powerful system for filtering tests based on tags and name patterns. This allows you to run specific subsets of tests, which is particularly useful for:


- Running only unit tests or only integration tests
- Running tests for a specific feature
- Running only tests that match a particular pattern
- Excluding tests that might be slow or dependent on external resources


## Tagging Functions


### firmo.tags(...)


Adds tags to a test or describe block. Tags are inherited by nested tests.
**Parameters:**


- `...` (strings): One or more tags to apply

**Returns:**


- The firmo object (for chaining)

**Example:**


```lua
describe("Database operations", function()
  firmo.tags("db", "integration")
  it("connects to the database", function()
    -- This test has the "db" and "integration" tags
  end)
  describe("Queries", function()
    it("executes a SELECT query", function()
      -- This test also has the "db" and "integration" tags
    end)
    firmo.tags("slow")
    it("performs a complex join", function()
      -- This test has "db", "integration", and "slow" tags
    end)
  end)
end)
```



### firmo.only_tags(...)


Filters tests to only run those matching at least one of the specified tags (OR logic).
**Parameters:**


- `...` (strings): One or more tags to filter by

**Returns:**


- The firmo object (for chaining)

**Example:**


```lua
-- Only run tests tagged with "unit"
firmo.only_tags("unit")
-- Only run tests tagged with both "fast" and "critical"
firmo.only_tags("fast", "critical")
```



### firmo.filter_pattern(pattern)

Filters tests to only run those with names matching the specified Lua pattern.
**Parameters:**

- `pattern` (string): A Lua pattern to match against test names

**Returns:**

- The firmo object (for chaining)

**Example:**

```lua
-- Only run tests with "validation" in their name
firmo.filter_pattern("validation")
-- Only run tests that match a specific pattern
firmo.filter_pattern("^user%s+%w+$")
```


### firmo.reset()

Resets the internal state of the test system, clearing all test definitions, hooks, results, filters, focus mode, and counters. This is typically called between test suite runs or file executions to ensure a clean state.
**Returns:**

- `nil`

**Example:**

```lua
-- Apply a filter
firmo.only_tags("unit")
-- Run some tests...
-- Clear all filters, hooks, results, etc.
firmo.reset()
```


## Focusing and Skipping Tests

Firmo allows you to focus on specific tests or suites, or temporarily skip them, using prefixed versions of `describe` and `it`.

### Focus Mode

When any test or suite is marked as "focused" (using `fit` or `fdescribe`), Firmo enters "Focus Mode". In this mode, only focused tests and tests within focused suites will run. All other tests will be skipped. This is useful for isolating specific tests during development or debugging.

**Example:**

```lua
describe("Regular Suite", function()
  it("This test will be skipped", function() end)
end)

fdescribe("Focused Suite", function()
  it("This test WILL run", function() end)

  fit("This focused test WILL run", function() end)
end)

describe("Another Regular Suite", function()
  fit("This focused test WILL run", function() end)

  it("This test will be skipped", function() end)
end)
```

### fdescribe(name, fn)

Defines a focused test group. Equivalent to `describe(name, fn, {focused = true})`. All tests within this block will run when focus mode is active, and this block itself activates focus mode.

### fit(name, options_or_fn, fn?)

Defines a focused test case. Equivalent to `it(name, options_or_fn, fn)` but implicitly adds `{focused = true}` to the options if `options_or_fn` is a table. This test will run when focus mode is active, and it activates focus mode.

**Parameters:**

- `name` (string): Name/description of the test case.
- `options_or_fn` (table|function): Either the test function itself, or an options table `{focused?: boolean, excluded?: boolean, expect_error?: boolean, tags?: string[], timeout?: number}`. The `focused = true` flag will be automatically added if an options table is provided.
- `fn?` (function): The test function, if `options_or_fn` was an options table.

### xdescribe(name, fn)

Defines a skipped test group. Equivalent to `describe(name, fn, {excluded = true})`. All tests within this block will be skipped.

### xit(name, options_or_fn, fn?)

Defines a skipped test case. Equivalent to `it(name, options_or_fn, fn)` but implicitly adds `{excluded = true}` to the options if `options_or_fn` is a table. This test will be skipped.

**Parameters:**

- `name` (string): Name/description of the test case.
- `options_or_fn` (table|function): Either the test function itself, or an options table `{focused?: boolean, excluded?: boolean, expect_error?: boolean, tags?: string[], timeout?: number}`. The `excluded = true` flag will be automatically added if an options table is provided.
- `fn?` (function): The test function, if `options_or_fn` was an options table.

**Example Usage:**

```lua
-- Temporarily skip this whole block
xdescribe("Work in Progress", function()
  it("Feature A", function() end)
end)

describe("Stable Features", function()
  it("Works fine", function() end)

  -- Skip just this test
  xit("Temporarily broken test", function() end)
end)
```

```

### Best Practices

1. **Use focus temporarily**: `fdescribe` and `fit` should be used as temporary development tools, not committed to your codebase permanently.
2. **Clean up before committing**: Remove or convert focused tests back to regular tests before committing code.
3. **Document excluded tests**: When using `xdescribe` or `xit` in committed code, add a comment explaining why the test is excluded and when it might be re-enabled.
4. **Avoid excluding in production**: Like focused tests, excluded tests should generally be temporary. Fix failing tests rather than permanently excluding them.
5. **Combine with tags**: For more permanent test organization, use tags instead of focus/exclude.
6. **CI protection**: Configure your CI pipeline to fail if focused tests are detected in committed code to prevent accidentally skipping tests in production.
7. **Use for debugging**: Focus is particularly useful during debugging to quickly iterate on a problematic test without running the entire suite.

### Implementation Details

When any test is marked as focused, the `firmo.focus_mode` flag is set to `true`. This causes all non-focused tests to be skipped during execution. When tests are excluded, they are effectively replaced with empty functions that never run.
The focus system is implemented to be explicit and deterministic, ensuring that:

1. Focus takes precedence over normal execution
2. Exclusion takes precedence over focus
3. The order of execution remains consistent

This makes the behavior predictable and reliable for development and debugging workflows.

## Filtering from the Command Line
Firmo supports filtering tests from the command line when running tests directly.

### --tags Option


The `--tags` option allows you to specify tags to filter by, separated by commas. This uses OR logic: tests matching *any* of the specified tags will be included.
**Example:**


```bash

# Run only tests tagged with "unit"


lua test.lua --tags unit

# Run tests tagged with either "fast" or "critical"


lua test.lua --tags fast,critical
```



### --filter Option


The `--filter` option allows you to specify a pattern to match against test names.
**Example:**


```bash

# Run only tests with "validation" in their name


lua test.lua --filter validation
```



### Combining Filters


You can combine tag and pattern filters to further narrow the tests that run.
**Example:**


```bash

# Run only "unit" tests with "validation" in their name


lua test.lua --tags unit --filter validation
```



## Examples


### Basic Tag Filtering



```lua
-- Define tests with tags
describe("User module", function()
  firmo.tags("unit")
  it("validates username", function()
    -- Test code here
  end)
  it("validates email", function()
    -- Test code here
  end)
  firmo.tags("integration", "slow")
  it("stores user in database", function()
    -- Test code here
  end)
end)
-- Run only unit tests
firmo.only_tags("unit")
firmo.run_discovered("./tests")
```



### Pattern Filtering



```lua
describe("String utilities", function()
  it("trims whitespace", function()
    -- Test code here
  end)
  it("formats currency", function()
    -- Test code here
  end)
end)
-- Run only tests related to formatting
firmo.filter_pattern("format")
firmo.run_discovered("./tests")
```



### Programmatic Control



```lua
-- Test suite setup
local function run_tests(options)
  -- Reset any previous filters, hooks, state, etc.
  firmo.reset()
  -- Apply tags filter if specified
  if options.tags then
    local unpack_table = table.unpack or unpack -- Lua 5.1 compatibility
    firmo.only_tags(unpack_table(options.tags))
  end
  -- Apply name filter if specified
  if options.pattern then
    firmo.filter_pattern(options.pattern)
  end
  -- Run the tests
  return firmo.run_discovered("./tests")
end
-- Examples of usage
run_tests({}) -- Run all tests
run_tests({tags = {"unit"}}) -- Run only unit tests
run_tests({pattern = "validation"}) -- Run only validation tests
run_tests({tags = {"unit"}, pattern = "validation"}) -- Run only unit validation tests
```



### Using with CI Systems



```lua
-- ci_tests.lua
local firmo = require("firmo")
-- Based on environment variable, run different test subsets
local test_type = os.getenv("TEST_TYPE") or "all"
if test_type == "unit" then
  firmo.only_tags("unit")
elseif test_type == "integration" then
  firmo.only_tags("integration")
elseif test_type == "performance" then
  firmo.only_tags("performance")
end
-- Run the filtered tests
local success = firmo.run_discovered("./tests")
os.exit(success and 0 or 1)
```



### Organizing Tests with Tags



```lua
-- user_test.lua
local firmo = require("firmo")
local describe, it = firmo.describe, firmo.it
describe("User module", function()
  -- Authentication tests
  describe("Authentication", function()
    firmo.tags("auth", "unit")
    it("validates credentials", function()
      -- Test code
    end)
    it("hashes passwords", function()
      -- Test code
    end)
  end)
  -- Profile tests
  describe("Profile", function()
    firmo.tags("profile", "unit")
    it("updates user info", function()
      -- Test code
    end)
    firmo.tags("profile", "integration")
    it("saves profile to database", function()
      -- Test code
    end)
  end)
end)
```



## Best Practices



1. **Use consistent tag naming**: Establish a convention for tag names (e.g., "unit", "integration", "slow") and use them consistently.
2. **Tag at the right level**: Apply tags to describe blocks when all contained tests share the same tags, and to individual tests for specific cases.
3. **Keep tags focused**: Use tags that have clear meaning and purpose, rather than overly specific or redundant tags.
4. **Document your tags**: Maintain a list of standard tags and their meanings for your project.
5. **Consider CI integration**: Set up your CI system to run different subsets of tests based on tags for faster feedback.
6. **Use pattern filtering sparingly**: Pattern filtering is powerful but can be less explicit than tag-based filtering.
