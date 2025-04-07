# Migrating to Coverage v3

This guide explains how to migrate from the v2 debug hook-based coverage system to the v3 instrumentation-based coverage system.

## Overview of Changes

The v3 coverage system introduces several fundamental changes:

1. **Instrumentation-Based Approach**: Instead of using debug hooks, v3 instruments source code by inserting tracking calls.
2. **Three-State Coverage Model**: v3 distinguishes between covered lines (verified by assertions), executed lines, and not covered lines.
3. **Automatic Module Loading Integration**: v3 automatically instruments modules when they are loaded, eliminating the need for manual tracking.
4. **Assertion Integration**: v3 automatically detects which lines are verified by assertions, eliminating the need for manual marking.

## API Changes

### Functions Removed in v3

The following functions from v2 are no longer available in v3:

```lua
-- Removed in v3 (no longer needed)
coverage.track_file(file_path)
coverage.process_module_structure(file_path)
coverage.mark_line_covered(file_path, line_number)
coverage.mark_line_executed(file_path, line_number)
```

### Compatible API Functions

These functions maintain the same signature but may have enhanced functionality:

```lua
-- Initialize coverage
coverage.init(options)

-- Start tracking
coverage.start()

-- Stop tracking and get data
local data = coverage.stop()

-- Reset coverage state
coverage.reset()
```

### Enhanced Functions

These functions have enhanced capabilities in v3:

```lua
-- Generate a report with more options
coverage.report(format, options)
```

## Configuration Changes

The configuration options have changed to support the new architecture:

### v2 Configuration

```lua
coverage.init({
  enabled = true,
  use_static_analysis = true,
  discover_uncovered = false,
  include_patterns = {"%.lua$"},
  exclude_patterns = {"test%.lua$"}
})
```

### v3 Configuration

```lua
coverage.init({
  enabled = true,
  
  -- Inclusion/exclusion with function patterns
  include = function(path) return path:match("%.lua$") end,
  exclude = function(path) return path:match("test%.lua$") end,
  
  -- Instrumentation options
  cache_instrumented = true,
  preserve_comments = true,
  
  -- Reporting options
  report_format = "html",
  output_dir = "./coverage-reports"
})
```

## Migrating Test Code

### Before (v2)

```lua
-- Manual tracking required in v2
local coverage = require("lib.coverage")
coverage.init({enabled = true})
coverage.start()

-- Manual file tracking
coverage.track_file("path/to/module.lua")

-- Run test
local module = require("path/to/module")
local result = module.function(1, 2)

-- Manual coverage marking
coverage.mark_line_covered("path/to/module.lua", 10)

-- Stop and report
coverage.stop()
coverage.report("html")
```

### After (v3)

```lua
-- Automatic tracking in v3
local coverage = require("lib.coverage")
coverage.init({enabled = true})
coverage.start()

-- No manual tracking needed
local module = require("path/to/module")

-- Run test with assertion
local result = module.function(1, 2)
expect(result).to.equal(3)  -- This automatically marks the function as covered

-- Stop and report
local data = coverage.stop()
coverage.report("html", {
  output_dir = "./coverage-reports",
  title = "My Coverage Report"
})
```

## HTML Report Changes

The HTML report in v3 uses a new three-color scheme:

- **Green**: Lines that are both executed and covered by assertions
- **Orange**: Lines that are executed but not covered by assertions
- **Red**: Lines that are not executed at all

The report also includes enhanced navigation, filtering options, and more detailed coverage statistics.

## Common Migration Issues

### 1. Manual Tracking Calls

**Problem**: Code uses `coverage.track_file()` or `coverage.mark_line_covered()`

**Solution**: Remove these calls. v3 automatically tracks files when they are loaded and marks lines as covered when they are verified by assertions.

### 2. Custom Report Formatters

**Problem**: Custom report formatters designed for v2 data format

**Solution**: Update formatters to handle the new three-state data model. v3 coverage data includes `executed` and `covered` boolean flags for each line.

### 3. Testing Framework Integration

**Problem**: Custom testing framework integration with manual coverage tracking

**Solution**: Update to use the automatic tracking. Ensure that assertions are properly integrated to track covered lines.

## Advanced Features in v3

The v3 system includes several advanced features:

1. **Module Caching**: Instrumented modules are cached for better performance
2. **Source Mapping**: Accurate line number mapping for error reporting
3. **Execution Count**: Track how many times each line is executed
4. **Conditional Coverage**: Better tracking of conditional branches
5. **HTML Report Enhancements**: Three-color visualization, filtering, and navigation

## Need Help?

If you encounter issues while migrating to v3:

1. Check the v3 implementation plan: `docs/coverage-v3-plan.md`
2. Review the API documentation: `docs/api/coverage.md`
3. Look at the example tests: `tests/coverage/minimal_coverage_test.lua`