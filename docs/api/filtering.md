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


Filters tests to only run those with the specified tags.
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



### firmo.filter(pattern)


Filters tests to only run those with names matching the specified pattern.
**Parameters:**


- `pattern` (string): A Lua pattern to match against test names

**Returns:**


- The firmo object (for chaining)

**Example:**


```lua
-- Only run tests with "validation" in their name
firmo.filter("validation")
-- Only run tests that match a specific pattern
firmo.filter("^user%s+%w+$")
```



### firmo.reset_filters()


Clears all active filters.
**Returns:**


- The firmo object (for chaining)

**Example:**


```lua
-- Apply a filter
firmo.only_tags("unit")
-- Run some tests...
-- Clear the filter
firmo.reset_filters()
```



## Filtering from the Command Line


Firmo supports filtering tests from the command line when running tests directly.

### --tags Option


The `--tags` option allows you to specify tags to filter by, separated by commas.
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
firmo.filter("format")
firmo.run_discovered("./tests")
```



### Programmatic Control



```lua
-- Test suite setup
local function run_tests(options)
  -- Reset any previous filters
  firmo.reset_filters()
  -- Apply tags filter if specified
  if options.tags then
    firmo.only_tags(unpack(options.tags))
  end
  -- Apply name filter if specified
  if options.pattern then
    firmo.filter(options.pattern)
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
