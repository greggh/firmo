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

#### Programmatically (`firmo.only_tags`)

You can filter programmatically within your test setup or a custom runner script:

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

## Name Pattern Filtering

You can also filter tests based on their names using Lua patterns.

### Using Pattern Filters

Pattern filters match against the full test path (all describe blocks plus the test name):

```bash

# Run tests containing "password" in their name

lua firmo.lua --filter password tests/

# Run tests starting with "validates"

lua firmo.lua --filter "^validates" tests/
```

### Programmatic Pattern Filtering

```lua
-- Filter to tests related to passwords
firmo.filter_pattern("password")
-- Run the tests
require("tests/auth_tests")
```

## Combining Filters (Programmatically)

You can combine programmatic tag and pattern filtering:

```lua
-- Run "unit" tests that have "validation" in their name
firmo.only_tags("unit")
firmo.filter_pattern("validation")
-- Run tests
```

From the command line, you can only use `--filter` for name pattern filtering.

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

When running tests *after* programmatically setting `firmo.only_tags("unit")`, only the focused password test will run (as it matches the "unit" tag inherited from the describe block). If `only_tags` was not called (or reset), the focused test would run regardless of its tags. Focus mode applies *after* the initial set of tests to run has been determined by tag/pattern filters.
## Organizing Test Suites

As your project grows, consider organizing tests with consistent tag structures:

### File Organization

```text
tests/
  unit/            -- All files use firmo.tags("unit")
    auth_test.lua  -- Also has firmo.tags("auth")
    user_test.lua  -- Also has firmo.tags("user")
  integration/     -- All files use firmo.tags("integration") 
    api_test.lua   -- Also has firmo.tags("api")
```

### Standard CI Pipeline

```text

# .github/workflows/test.yml

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      # Use --filter to select tests by name pattern
      - run: lua firmo.lua tests/ --filter unit

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      # ... setup ...
      - run: lua firmo.lua tests/ --filter integration
```
Alternatively, configure each job to use a different entry script or configuration file that applies programmatic tag filtering (`firmo.only_tags(...)`) before running `lua firmo.lua tests/`.

## Best Practices

### Tag Naming Conventions

1. **Use lowercase**: `unit` not `Unit`
2. **Use hyphens for multi-word tags**: `slow-network` not `slow_network`
3. **Be consistent**: Document standard tags for your project

### Tag Application Strategy

1. **Tag at the right level**: Apply to the highest level that makes sense
2. **Don't over-tag**: Too many tags become hard to maintain. Focus on categories useful for filtering.
3. **Tag during authoring**: Add tags as you write tests, not later.
4. **CLI Filtering**: Use `--filter` for quick name-based filtering during development. For tag-based filtering in CI, prefer programmatic setup.

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
```lua
-- Custom runner applying filters
local function run_suite(options)
  firmo.reset() -- Reset filters, state, etc.

  -- Note: firmo.exclude_tags is not implemented.
  -- Implementing exclusion requires filtering the test list manually
  -- or modifying the runner logic.

  if options.components then
    -- Build a tag list from components
    local tags = {}
    for _, component in ipairs(options.components) do
      table.insert(tags, component)
    end
    -- Use compatibility unpack
    local unpack_table = table.unpack or unpack
    firmo.only_tags(unpack_table(tags))
  end

  if options.pattern then
    firmo.filter_pattern(options.pattern)
  end

  -- Run the selected tests
  require("tests/run_all") -- Assumes this loads/runs tests
end
-- Example usage
run_suite({
  -- exclude_slow = true, -- Cannot directly exclude tags
  components = {"auth", "user"},
  pattern = "validation"
})

## Troubleshooting

### No Tests Running

If no tests are running with your filters:

1. **Check tag spelling**: Tags are case-sensitive
2. **Look for tag hierarchy issues**: Make sure tags are applied at correct describe levels if using `firmo.tags()`.
3. **Check Filter Pattern**: Ensure your `--filter` pattern is correct Lua syntax and matches the intended test names.

### Too Many Tests Running

If filters aren't narrowing the selection enough:

1. **Add more specific tags**: Break down generic tags like "unit" into more specific ones if using programmatic `only_tags`.
2. **Refine `--filter` Pattern**: Make your `--filter` pattern more specific.
3. **Use focus mode**: Temporarily use `fit` or `fdescribe`.

## Conclusion

Effective test filtering makes your testing workflow more efficient and targeted. By intelligently tagging your tests and using pattern filters, you can run exactly the tests you need at any point in your development cycle.
For practical examples, see the [filtering examples](/examples/filtering_examples.md) file.
