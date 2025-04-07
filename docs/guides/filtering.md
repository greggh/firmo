# Test Filtering Guide

This guide explains how to use Firmo's powerful test filtering and tagging system to run specific subsets of your test suite.

## Introduction

As your test suite grows, running all tests for every change becomes inefficient. Firmo's filtering capabilities let you:

- Run only unit tests during rapid development
- Run integration tests before commits
- Target specific components or features
- Skip slow tests during local development
- Create custom test subsets for different purposes

## Understanding Test Filtering

Firmo provides two primary filtering mechanisms:

1. **Tag-based filtering**: Select tests based on labels you assign
2. **Pattern-based filtering**: Select tests based on their name

Both approaches can be used programmatically or via command-line options.

## Using Tags

Tags are labels you attach to test groups or individual tests. They're the most flexible way to organize your tests.

### Adding Tags to Tests

You can add tags at different levels in your test hierarchy:

```lua
local firmo = require("firmo")

-- 1. Tag an entire test file
firmo.tags("unit", "auth")

describe("Authentication Module", function()
  -- Tests inherit the "unit" and "auth" tags
  
  it("validates user credentials", function()
    -- This test has "unit" and "auth" tags
  end)
  
  -- 2. Tag a nested describe block
  describe("Password Reset", function()
    firmo.tags("email")
    
    it("sends reset email", function()
      -- This test has "unit", "auth", and "email" tags
    end)
  end)
  
  -- 3. Tag an individual test
  it("handles invalid login", function()
    firmo.tags("security")
    -- This test has "unit", "auth", and "security" tags
  end)
end)
```

### Running Tests by Tag

#### Command Line

The most common way to filter by tags is using the `--tags` option:

```bash
# Run only tests tagged with "unit"
lua test.lua --tags unit tests/

# Run tests with both "auth" and "security" tags
lua test.lua --tags auth,security tests/
```

#### Programmatically

You can also filter programmatically:

```lua
-- In a custom test runner
local firmo = require("firmo")

-- Filter to only unit tests
firmo.only_tags("unit")

-- Run the tests
require("tests/auth_tests")
require("tests/user_tests")
```

## Tag Combinations

The `--tags` option supports complex filtering:

```bash
# Tests tagged with both "unit" AND "auth"
lua test.lua --tags unit,auth tests/

# Tests tagged with EITHER "unit" OR "integration"
lua test.lua --tags unit+integration tests/

# Tests tagged with "auth" but NOT "slow"
lua test.lua --tags auth,-slow tests/
```

## Name Pattern Filtering

You can also filter tests based on their names using Lua patterns.

### Using Pattern Filters

Pattern filters match against the full test path (all describe blocks plus the test name):

```bash
# Run tests containing "password" in their name
lua test.lua --filter password tests/

# Run tests starting with "validates"
lua test.lua --filter "^validates" tests/
```

### Programmatic Pattern Filtering

```lua
-- Filter to tests related to passwords
firmo.filter("password")

-- Run the tests
require("tests/auth_tests")
```

## Combining Filters

You can combine tag and pattern filters for precise test selection:

```bash
# Run "unit" tests that have "validation" in their name
lua test.lua --tags unit --filter validation tests/
```

## Common Tagging Strategies

### Test Type Tags

One of the most useful tag categories separates tests by type:

```lua
-- Fast tests that don't need external resources
firmo.tags("unit")

-- Tests that interact with databases, APIs, etc.
firmo.tags("integration") 

-- Tests that exercise many components together
firmo.tags("system")

-- Tests that verify performance requirements
firmo.tags("performance")
```

### Feature Area Tags

Tag tests by the feature they're testing:

```lua
firmo.tags("auth")
firmo.tags("user")
firmo.tags("billing")
firmo.tags("api")
```

### Characteristic Tags

Tag tests by their characteristics:

```lua
firmo.tags("slow")    -- Tests that take significant time
firmo.tags("flaky")   -- Tests that might be unreliable
firmo.tags("network") -- Tests requiring network access
firmo.tags("db")      -- Tests requiring database access
```

### Status Tags

Sometimes it's useful to tag tests by status:

```lua
firmo.tags("wip")     -- Work in progress
firmo.tags("broken")  -- Known broken, need fixing
```

## Using Tags and Focus Together

Firmo's focus mode (using `fdescribe`/`fit`) works alongside tag filters:

```lua
describe("User module", {tags = {"unit"}}, function()
  it("validates usernames", function()
    -- Test code
  end)
  
  fit("validates passwords", function()
    -- Only this test will run, if it matches active tag filters
  end)
end)
```

When running with `--tags unit`, only the focused password test will run. Without the tag filter, the same focused test would run regardless of its tags.

## Organizing Test Suites

As your project grows, consider organizing tests with consistent tag structures:

### File Organization

```
tests/
  unit/            -- All files use firmo.tags("unit")
    auth_test.lua  -- Also has firmo.tags("auth")
    user_test.lua  -- Also has firmo.tags("user")
  integration/     -- All files use firmo.tags("integration") 
    api_test.lua   -- Also has firmo.tags("api")
```

### Standard CI Pipeline

```
# .github/workflows/test.yml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - run: lua test.lua --tags unit tests/
  
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - run: lua test.lua --tags integration tests/
```

## Best Practices

### Tag Naming Conventions

1. **Use lowercase**: `unit` not `Unit`
2. **Use hyphens for multi-word tags**: `slow-network` not `slow_network`
3. **Be consistent**: Document standard tags for your project

### Tag Application Strategy

1. **Tag at the right level**: Apply to the highest level that makes sense
2. **Don't over-tag**: Too many tags become hard to maintain
3. **Tag during authoring**: Add tags as you write tests, not later

### Common Tag Combinations

- `unit,fast`: Rapid development feedback
- `unit,integration,-slow`: Pre-commit verification
- `feature-name`: Working on a specific feature
- `-flaky,-slow`: Reliable, quick feedback

## Advanced Filtering Techniques

### Using Environment Variables

```lua
-- Filter based on environment
local test_type = os.getenv("TEST_TYPE") or "all"
if test_type == "unit" then
  firmo.only_tags("unit")
elseif test_type == "integration" then
  firmo.only_tags("integration")
end
```

### Custom Tag Logic

```lua
-- Custom tag-based runner
local function run_suite(options)
  firmo.reset_filters()
  
  if options.exclude_slow then
    -- Filter out slow tests
    firmo.exclude_tags("slow")
  end
  
  if options.components then
    -- Build a tag list from components
    local tags = {}
    for _, component in ipairs(options.components) do
      table.insert(tags, component)
    end
    firmo.only_tags(unpack(tags))
  end
  
  if options.pattern then
    firmo.filter(options.pattern)
  end
  
  -- Run the selected tests
  require("tests/run_all")
end

-- Example usage
run_suite({
  exclude_slow = true,
  components = {"auth", "user"},
  pattern = "validation"
})
```

## Troubleshooting

### No Tests Running

If no tests are running with your filters:

1. **Check tag spelling**: Tags are case-sensitive
2. **Look for tag hierarchy issues**: Make sure tags are applied at correct levels
3. **Check for tag conflicts**: You might have excluded the tests with another tag

### Too Many Tests Running

If filters aren't narrowing the selection enough:

1. **Add more specific tags**: Break down generic tags like "unit" into more specific ones
2. **Combine with pattern filters**: Use `--filter` alongside `--tags`
3. **Use focus mode**: Temporarily use `fit` or `fdescribe` 

## Conclusion

Effective test filtering makes your testing workflow more efficient and targeted. By intelligently tagging your tests and using pattern filters, you can run exactly the tests you need at any point in your development cycle.

For practical examples, see the [filtering examples](/examples/filtering_examples.md) file.