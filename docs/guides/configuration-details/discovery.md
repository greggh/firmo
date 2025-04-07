# Test Discovery Configuration

This document describes the comprehensive configuration options for the firmo test discovery system, which locates test files in your project based on naming patterns and directory structure.

## Overview

The test discovery module provides a flexible system for finding test files with support for:

- Customizable test file patterns (e.g., `*_test.lua`, `test_*.lua`)
- Directory exclusion patterns for skipping irrelevant folders
- Recursive directory traversal with configurable depth
- File extension filtering
- Integration with the central configuration system

## Configuration Options

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ignore` | string[] | `["node_modules", ".git", "vendor"]` | Directories to skip during discovery. |
| `include` | string[] | `["*_test.lua", "*_spec.lua", "test_*.lua", "spec_*.lua"]` | Patterns to identify test files. |
| `exclude` | string[] | `[]` | Patterns to exclude from test files. |
| `recursive` | boolean | `true` | Whether to search subdirectories recursively. |
| `extensions` | string[] | `[".lua"]` | Valid file extensions for test files. |

## Configuration in .firmo-config.lua

You can configure the test discovery system in your `.firmo-config.lua` file:

```lua
return {
  -- Test discovery configuration
  discovery = {
    -- Directories to ignore
    ignore = {
      "node_modules",        -- Skip node_modules directory
      ".git",                -- Skip git directory
      "vendor",              -- Skip vendor directory
      "build",               -- Skip build directory
      "coverage-reports"     -- Skip coverage reports
    },
    
    -- Test file patterns
    include = {
      "*_test.lua",          -- Files ending with _test.lua
      "test_*.lua",          -- Files starting with test_
      "*_spec.lua",          -- Files ending with _spec.lua
      "tests/*.lua"          -- All Lua files in tests directory
    },
    
    -- Files to exclude
    exclude = {
      "*_fixture.lua",       -- Exclude fixture files
      "*_helper.lua",        -- Exclude helper files
      "temp_*"               -- Exclude temporary files
    },
    
    -- Directory traversal
    recursive = true,        -- Search subdirectories
    
    -- File types
    extensions = {".lua"}    -- Only Lua files
  }
}
```

## Programmatic Configuration

You can also configure the test discovery system programmatically:

```lua
local discover = require("lib.tools.discover")

-- Basic configuration
discover.configure({
  ignore = {"node_modules", ".git", "vendor", "build"},
  include = {"*_test.lua", "test_*.lua"},
  exclude = {"*_fixture.lua"},
  recursive = true,
  extensions = {".lua"}
})

-- Add individual patterns
discover.add_include_pattern("*_spec.lua")
discover.add_exclude_pattern("temp_*")
```

## Test File Patterns

Test file patterns determine which files are identified as tests:

```lua
-- Common test file naming patterns
local test_patterns = {
  "*_test.lua",     -- Files ending with _test.lua
  "test_*.lua",     -- Files starting with test_
  "*_spec.lua",     -- Files ending with _spec.lua
  "*Test.lua",      -- Files ending with Test.lua
  "Test*.lua"       -- Files starting with Test
}

-- Configure with these patterns
discover.configure({
  include = test_patterns
})
```

## Directory Exclusion

Exclude directories you don't want to scan for tests:

```lua
-- Common directories to exclude
local excluded_dirs = {
  "node_modules",   -- Node.js dependencies
  ".git",           -- Git repository metadata
  "vendor",         -- Third-party code
  "build",          -- Build artifacts
  "dist",           -- Distribution files
  "coverage-reports", -- Test coverage reports
  "tmp"             -- Temporary files
}

-- Configure to exclude these directories
discover.configure({
  ignore = excluded_dirs
})
```

## Integration with Test Runner

The discovery module integrates with Firmo's test runner:

```lua
-- In test runner
local discover = require("lib.tools.discover")

-- Configure discovery
discover.configure({
  ignore = {"node_modules", ".git"},
  include = {"*_test.lua", "test_*.lua"}
})

-- Discover test files
local result, err = discover.discover("./tests")
if not result then
  print("Discovery failed:", err.message)
  return
end

-- Use discovered files
for _, file in ipairs(result.files) do
  print("Running test file:", file)
  run_test_file(file)
end
```

## Best Practices

### Targeted Test Discovery

Define patterns that match your project's test naming convention:

```lua
-- For a project that uses test_*.lua convention
discover.configure({
  include = {"test_*.lua"},
  exclude = {"test_helper.lua", "test_fixture.lua"}
})

-- For a project that uses *_test.lua convention
discover.configure({
  include = {"*_test.lua"},
  exclude = {"helper_test.lua", "fixture_test.lua"}
})
```

### Performance Optimization

Optimize test discovery for large codebases:

```lua
-- For large codebases with many dependencies
discover.configure({
  ignore = {
    "node_modules",
    ".git",
    "vendor",
    "build",
    "dist",
    "coverage-reports",
    "assets",
    "docs"
  },
  recursive = true  -- Still search subdirectories
})

-- For very large projects where test files are in specific directories
discover.configure({
  recursive = false,  -- Don't search subdirectories
  include = {
    "tests/*.lua",    -- Only look in the tests directory
    "specs/*.lua"     -- And the specs directory
  }
})
```

### Nested Test Directory Structure

For projects with nested test directory structures:

```lua
-- For a project with feature-based test organization
-- src/
--   feature1/
--     feature1.lua
--     feature1_test.lua
--   feature2/
--     feature2.lua
--     feature2_test.lua

discover.configure({
  recursive = true,
  include = {"*_test.lua"}
})
```

## Troubleshooting

### Common Issues

1. **Tests not being discovered**:
   - Check if test files match your include patterns
   - Ensure test files have the expected file extension
   - Verify that test directories aren't accidentally excluded

2. **Too many files being discovered**:
   - Add more specific include patterns
   - Add exclude patterns for files that shouldn't be considered tests
   - Add directories to the ignore list

3. **Discovery is too slow**:
   - Limit recursive scanning with `recursive = false`
   - Exclude large directories that don't contain tests
   - Use more specific include patterns to reduce the number of files examined

## Integration with CI/CD Systems

For continuous integration environments:

```lua
-- In .firmo-config.ci.lua
return {
  discovery = {
    -- Be explicit about where tests are located in CI
    include = {
      "tests/**/*_test.lua",  -- All test files in tests directory and subdirectories
      "specs/**/*_spec.lua"   -- All spec files in specs directory and subdirectories
    },
    -- Exclude CI-specific directories
    ignore = {
      "node_modules", ".git", "vendor", "build", "dist",
      "coverage-reports", "ci-artifacts"
    }
  }
}
```

## Example Configuration Files

### Basic Configuration

```lua
-- .firmo-config.lua
return {
  discovery = {
    ignore = {"node_modules", ".git", "vendor"},
    include = {"*_test.lua", "test_*.lua"},
    exclude = {},
    recursive = true,
    extensions = {".lua"}
  }
}
```

### Feature-Based Test Structure

```lua
-- .firmo-config.feature.lua
return {
  discovery = {
    ignore = {"node_modules", ".git", "vendor"},
    include = {
      "src/**/*_test.lua",     -- Tests alongside source code
      "tests/features/**/*.lua" -- Feature tests in dedicated directory
    },
    exclude = {"*_helper.lua"},
    recursive = true,
    extensions = {".lua"}
  }
}
```

### Integration Test Configuration

```lua
-- .firmo-config.integration.lua
return {
  discovery = {
    ignore = {"node_modules", ".git", "vendor"},
    include = {
      "tests/integration/**/*.lua", -- Only integration tests
    },
    exclude = {},
    recursive = true,
    extensions = {".lua"}
  }
}
```

These configuration options give you complete control over test file discovery, allowing you to tailor the process to your project's specific structure and naming conventions.