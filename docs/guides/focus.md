# Focus Mode Guide


This guide explains how to use Firmo's focus and exclude features to run specific tests during development and debugging.

## Introduction


When working with a large test suite, you often need to run only a subset of tests:


- During development, you may want to focus on tests related to the feature you're building
- When debugging, you may want to isolate and repeatedly run failing tests
- Sometimes you need to temporarily skip problematic tests

Firmo provides a powerful focus system to address these needs with minimal changes to your test code.

## Understanding Focus Mode


### How Focus Mode Works


When you mark any test as "focused" using `fdescribe` or `fit`, Firmo enters focus mode:


1. Only focused tests and tests within focused groups will run
2. All other tests are skipped (marked as "SKIP (not focused)")
3. The test runner reports the number of skipped tests

Focus mode is automatically enabled when any focused test is detected in your test suite.

## Focusing Tests


### Using `fdescribe` - Focus a Test Group


To focus an entire group of tests:


```lua
local describe, fdescribe = firmo.describe, firmo.fdescribe
-- This group will be skipped in focus mode
describe("User Profile", function()
  it("loads user data", function()
    -- This test won't run in focus mode
  end)
end)
-- This group and all its tests will run
fdescribe("User Authentication", function()
  it("validates credentials", function()
    -- This test will run because it's in a focused group
  end)

  it("handles invalid passwords", function()
    -- This test will also run
  end)
end)
```



### Using `fit` - Focus a Single Test


To focus on a single test:


```lua
local it, fit = firmo.it, firmo.fit
describe("Data Validation", function()
  it("validates string inputs", function()
    -- This test will be skipped
  end)

  fit("validates numeric inputs", function()
    -- Only this test will run
  end)

  it("validates boolean inputs", function()
    -- This test will be skipped
  end)
end)
```



### Focus Hierarchy


Focus respects the test hierarchy:


```lua
fdescribe("User Management", function()
  describe("Profile", function()
    it("updates profile", function()
      -- Runs because ancestor is focused
    end)
  end)

  it("creates user", function()
    -- Runs because parent is focused
  end)
end)
describe("Other Feature", function()
  fit("specific test", function()
    -- Runs because it's directly focused
  end)

  it("regular test", function()
    -- Skipped in focus mode
  end)
end)
```



## Excluding Tests


### Using `xdescribe` - Exclude a Test Group


To temporarily skip a group of tests:


```lua
local describe, xdescribe = firmo.describe, firmo.xdescribe
describe("Working Features", function()
  it("runs normally", function()
    -- This test runs 
  end)
end)
xdescribe("Problematic Tests", function()
  it("flaky test", function() 
    -- This won't run
  end)

  it("unfinished feature", function()
    -- This won't run
  end)
end)
```



### Using `xit` - Exclude a Single Test


To skip a single test:


```lua
local it, xit = firmo.it, firmo.xit
describe("API Tests", function()
  it("gets user data", function()
    -- This runs normally
  end)

  xit("fails with bad network", function()
    -- This is skipped
  end)
end)
```



### Exclude Priority


Exclusion always takes precedence over focus:


```lua
fdescribe("Focused Group", function()
  it("normal test", function()
    -- Runs because parent is focused
  end)

  xit("excluded test", function()
    -- Skipped despite focused parent
  end)
})
```



## Practical Workflows


### Development Workflow


When building a new feature:


1. Use `fdescribe` to focus on the relevant test group:

   ```lua
   fdescribe("New Feature: Shopping Cart", function()
     -- Tests for the feature you're actively working on
   end)
   ```


2. As you complete parts of the feature, use `fit` for specific tests:

   ```lua
   fdescribe("New Feature: Shopping Cart", function()
     it("adds items", function()
       -- Already implemented
     end)

     fit("applies discount codes", function()
       -- Currently implementing this
     end)

     it("calculates total", function()
       -- Not implemented yet
     end)
   end)
   ```


3. Before committing, remove all focus markers:

   ```lua
   describe("New Feature: Shopping Cart", function()
     it("adds items", function()
       -- Fully implemented
     end)

     it("applies discount codes", function()
       -- Fully implemented
     end)

     it("calculates total", function()
       -- Fully implemented
     end)
   end)
   ```

### Debugging Workflow


When fixing a failing test:


1. Focus on the failing test:

   ```lua
   describe("Data Processing", function()
     fit("handles special characters", function()
       -- The failing test you're debugging
     end)
   end)
   ```


2. Make small changes and run repeatedly
3. Once fixed, remove the focus:

   ```lua
   describe("Data Processing", function()
     it("handles special characters", function()
       -- Fixed test
     end)
   end)
   ```

### Test Creation Workflow


When adding new tests:


1. Start with a focused test group:

   ```lua
   fdescribe("New Feature Tests", function()
     -- New tests here
   end)
   ```


2. Add and test one case at a time:

   ```lua
   fdescribe("New Feature Tests", function()
     it("handles basic case", function()
       -- First test
     end)

     fit("handles edge case", function()
       -- Currently writing this test
     end)
   end)
   ```


3. Remove focus when all tests pass


## Running Tests with Focus Mode


### Command Line Execution


Focus mode works with the standard test runner:


```bash

# Run all tests, respecting focus settings


lua firmo.lua tests/

# Run with specific pattern, still respecting focus 


lua firmo.lua --pattern=user tests/
```



### Combining with Tags and Patterns


Focus mode works alongside other filtering mechanisms:


```lua
-- Tag your tests
describe("User System", {tags = {"unit"}}, function()
  fit("focused unit test", function() 
    -- This runs
  end)
end)
describe("API", {tags = {"integration"}}, function()
  fit("focused integration test", function()
    -- Also runs if no tag filter is applied
  end)
end)
```

This runs tests, first filtering by name pattern (`--filter unit`), then applying focus mode to that subset. Only focused tests whose name/path contains 'unit' will run.

```bash
# Only runs focused tests whose name/path contains "unit"
lua firmo.lua --filter unit tests/
```


## Best Practices


### Temporary Use Only


Focus and exclude features are meant for development, not for committed code:


1. **Never commit focused tests**
   - Before committing, remove all instances of `fdescribe` and `fit`
   - Configure CI to fail if focused tests are detected
2. **Document exclusions**
   - If committing excluded tests, add a comment explaining why:

     ```lua
     xit("uploads large files", function()
       -- TODO: Fix this test, it's flaky on CI
       -- Issue #123
     end)
     ```


3. **Track excluded tests**
   - Maintain a list of excluded tests in a project tracking system
   - Set deadlines for re-enabling excluded tests


### Focus System vs. Tags


Focus mode is for temporary selection, while tags are for permanent categorization:
| When to use Focus/Exclude | When to use Tags |
|---------------------------|------------------|
| During active development | For test categories (unit, integration) |
| When debugging failing tests | For feature areas (auth, profile) |
| For temporary skipping | For test characteristics (slow, network) |

### Common Mistakes to Avoid



1. **Committing focused tests**
   - This can accidentally skip important tests in CI
2. **Using exclusion instead of fixing**
   - Excluded tests should be temporary, not permanent
3. **Too many focus levels**
   - Focus on the minimum needed tests to keep runs fast
   - Don't mix multiple levels of focus unnecessarily
4. **Confusing focus test results**
   - Remember that focus mode is active when analyzing results
   - A "100% passing" report might be excluding most tests


## Troubleshooting


### All Tests Running Despite Focus


If all tests are running despite using `fdescribe` or `fit`:


1. Ensure you're using the correct functions

   ```lua
   local fdescribe, fit = firmo.fdescribe, firmo.fit  -- Correct
   ```


2. Check for typos in function names

   ```lua
   describe("Group", function() -- Not focused
     f_it("test", function() -- Not a real focus function
   ```

### No Tests Running


If no tests are running:


1. Check if your focus tests are excluded by filters

   ```bash
   # Your focused test might not have this tag
   lua firmo.lua --tags=unit tests/
   ```


2. Verify you haven't excluded the focused tests

   ```lua
   xdescribe("Group", function() 
     fit("test", function() -- Won't run because parent is excluded
   ```

## Conclusion


Firmo's focus system gives you powerful tools for controlling test execution during development. Use it to streamline your workflow, but remember it's designed for temporary use during development. When used properly, it can dramatically improve your testing efficiency while maintaining the integrity of your test suite.
For more examples, see the [focus examples](/examples/focus_examples.md) file.
