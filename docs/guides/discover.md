# Test Discovery Guide

This guide covers how to use the Test Discovery module in Firmo for finding and working with test files programmatically. While the test runner uses this module internally, you may want to leverage it for custom test tooling, reporting, or automation.

## Introduction

The Test Discovery module (`lib.tools.discover`) helps locate test files in your project structure based on configurable patterns, extensions, and filtering rules. It's particularly useful when you need to:

- Create custom test runners or watchers
- Generate test reports or statistics
- Implement test file management tools
- Build test organization and validation tools

## Basic Usage

### Finding Test Files

The simplest way to use the discovery module is to find all test files in a directory:

```lua
local discover = require("lib.tools.discover")

-- Find all test files in the default "tests" directory
local result, err = discover.discover()

if result then
  for _, file_path in ipairs(result.files) do
    print("Test file: " .. file_path)
  end
  print(string.format("Found %d test files", result.matched))
else
  print("Error discovering tests: " .. err.message)
end
```

### Specifying a Different Directory

You can specify a different directory to search for tests:

```lua
local result, err = discover.discover("src/tests")
```

### Filtering by Pattern

To find test files that match a specific pattern:

```lua
-- Find all test files containing "user" in their path
local result, err = discover.discover("tests", "user")
```

## Configuring Discovery

### Complete Configuration

For more control, you can configure all discovery options at once:

```lua
discover.configure({
  -- Directories to ignore during discovery
  ignore = {"node_modules", ".git", "vendor", "build"},
  
  -- Patterns to include as test files
  include = {"*_test.lua", "test_*.lua", "*_spec.lua", "unit_*.lua"},
  
  -- Patterns to exclude from test files
  exclude = {"*_fixture.lua", "*_helper.lua", "*_disabled.lua"},
  
  -- Whether to search subdirectories recursively
  recursive = true,
  
  -- Valid file extensions for test files
  extensions = {".lua"}
})
```

### Method Chaining

The configuration functions support method chaining for a more fluent interface:

```lua
discover.configure({recursive = false})
        .add_include_pattern("integration_*.lua")
        .add_exclude_pattern("*_wip.lua")
```

### Adding Individual Patterns

You can add individual include or exclude patterns:

```lua
-- Add a new pattern for integration tests
discover.add_include_pattern("integration_*.lua")

-- Exclude work-in-progress tests
discover.add_exclude_pattern("*_wip.lua")
```

## Advanced Usage

### Custom Test File Detection

Sometimes you may want to check if individual files are test files according to your configuration:

```lua
local discover = require("lib.tools.discover")

local files = {
  "src/utils.lua",
  "tests/user_test.lua",
  "tests/helpers/test_helper.lua"
}

for _, file in ipairs(files) do
  if discover.is_test_file(file) then
    print(file .. " is a test file")
  else
    print(file .. " is NOT a test file")
  end
end
```

### Building a Custom Test Runner

You can use the discovery module to build a simple custom test runner:

```lua
local discover = require("lib.tools.discover")
local firmo = require("firmo")

local function run_tests(directory, pattern)
  -- Discover test files
  local result, err = discover.discover(directory, pattern)
  if not result then
    print("Error discovering tests: " .. err.message)
    return false
  end
  
  -- No tests found
  if #result.files == 0 then
    print("No matching test files found")
    return true
  end
  
  print(string.format("Running %d test files...", #result.files))
  
  -- Run each test file
  local failures = 0
  for _, file in ipairs(result.files) do
    print("\nRunning " .. file)
    local success = pcall(function()
      dofile(file)
    end)
    
    if not success then
      failures = failures + 1
    end
  end
  
  print(string.format("\nCompleted %d tests with %d failures", 
    #result.files, failures))
  
  return failures == 0
end

-- Usage:
run_tests("tests/unit", "user")
```

## Working with the Test Discovery Results

The discovery results provide information you can use for reporting or further processing:

```lua
local discover = require("lib.tools.discover")
local result = discover.discover("tests")

if result then
  -- Get all discovered test files
  local test_files = result.files
  
  -- Number of files matching the pattern
  local matched_count = result.matched
  
  -- Total number of test files found (before pattern filtering)
  local total_count = result.total
  
  -- Calculate percentages
  local match_percentage = (matched_count / total_count) * 100
  
  print(string.format("Found %d/%d test files (%.1f%%)", 
    matched_count, total_count, match_percentage))
end
```

## Integration with File Watchers

The discover module works well with file watchers for implementing test-on-change functionality:

```lua
local discover = require("lib.tools.discover")
local watcher = require("lib.tools.watcher")

-- First, discover all test files
local result = discover.discover("tests")
local test_files = result and result.files or {}

-- Map source files to their test files (simplified example)
local file_to_tests = {}
for _, test_file in ipairs(test_files) do
  -- Simple mapping assumption: test has same name as source file but with _test suffix
  local source_name = test_file:gsub("_test%.lua$", ".lua")
  source_name = source_name:gsub("^tests/", "src/")
  
  if not file_to_tests[source_name] then
    file_to_tests[source_name] = {}
  end
  table.insert(file_to_tests[source_name], test_file)
end

-- Watch for changes
watcher.create()
       :add_pattern("src/**.lua")
       :on_change(function(file)
         local tests = file_to_tests[file]
         if tests then
           for _, test in ipairs(tests) do
             print("Running test for changed file: " .. test)
             -- Run the test...
           end
         end
       end)
       :start()
```

## Best Practices

1. **Use specific include/exclude patterns**: Narrower patterns improve performance in large codebases.

2. **Consider recursion settings**: For very large projects, you might want to set `recursive = false` and manually specify subdirectories.

3. **Balance pattern specificity**: Too generic patterns might match unwanted files, too specific patterns might miss valid test files.

4. **Check error returns**: Always check for errors when calling `discover()`.

5. **Cache discovery results**: If you're using discovery in a long-running process, consider caching the results and refreshing only when files change.

## Troubleshooting

### Tests Not Being Found

If your tests aren't being found:

1. **Check your include patterns**: Make sure they match your file naming convention.
   ```lua
   discover.configure({include = {"your_pattern_*.lua"}})
   ```

2. **Verify exclude patterns**: Ensure you're not accidentally excluding your test files.
   ```lua
   discover.configure({exclude = {}}) -- Clear all exclude patterns
   ```

3. **Check ignored directories**: Make sure your tests aren't in ignored directories.
   ```lua
   discover.configure({ignore = {}}) -- Clear all ignore patterns
   ```

4. **Enable logging**: The discovery module logs detailed information about the discovery process.
   ```lua
   local logging = require("lib.tools.logging")
   logging.configure({level = "debug"})
   ```

### Performance Issues

If discovery is slow:

1. **Limit recursion**: If you have a deep directory structure but tests are only in specific locations, set `recursive = false` and specify the exact test directories.

2. **Add specific ignore patterns**: Exclude large directories that don't contain tests.

3. **Use more specific include patterns**: This helps filter files earlier in the process.

## Conclusion

The Test Discovery module provides a flexible system for finding test files in your project structure. By customizing its configuration, you can adapt it to any project organization or test file naming convention. Whether used directly or as part of a larger system, it simplifies the task of programmatically working with your test suite.