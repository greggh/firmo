# Coverage Module

The Coverage module provides comprehensive code coverage tracking and reporting for Lua code. It uses a debug hook-based approach to efficiently track which lines of code are executed during test execution.

## Overview

The coverage system leverages Lua's debug hook mechanism to provide reliable and efficient code coverage tracking. By using debug hooks instead of source code instrumentation, the system offers better performance, improved reliability with coroutines, and seamless integration with firmo's reporting capabilities.

### Three-State Coverage Model

The coverage system tracks three distinct states for each line of code:

1. **Covered** (Green): Lines that are both executed AND verified by assertions
2. **Executed** (Orange): Lines that are executed during tests but NOT verified by assertions
3. **Not Covered** (Red): Lines that are not executed at all

This distinction helps identify code that is running but not actually being tested properly.

## Architecture

The coverage system consists of several integrated components:

1. **Debug Hook System**:
   - **Line Hook**: Tracks which lines of code are executed via debug.sethook
   - **Coroutine Support**: Properly tracks coverage across coroutines
   - **Thread Safety**: Ensures reliable operation in multi-threaded environments

2. **File Operations**:
   - **Filesystem Module**: All file access through firmo's filesystem module
   - **Stats Management**: Saves and loads coverage statistics between runs
   - **Temporary File Handling**: Uses temp_file module for reliable operations

3. **Configuration Management**:
   - **Central Config**: Settings managed by central_config system
   - **Pattern Matching**: Flexible file include/exclude with pattern matching
   - **Threshold Configuration**: Configurable coverage thresholds

4. **Reporting System**:
   - **Multiple Formatters**: Support for HTML, JSON, LCOV, TAP, CSV, JUnit, Cobertura, and Summary formats
   - **Data Normalization**: Coverage data normalized for consistent reporting
   - **Integration**: Seamless integration with firmo's reporting system

## API Reference

### Coverage Module

```lua
local coverage = require("lib.coverage")
```

#### Public Functions

- `coverage.start()`: Starts coverage tracking using debug hooks
- `coverage.stop()`: Stops coverage tracking, unregisters hooks, and collects data
- `coverage.reset()`: Resets coverage data
- `coverage.is_active()`: Checks if coverage is active
- `coverage.get_data()`: Gets the current coverage data
- `coverage.save_stats(filename)`: Saves coverage statistics to a file
- `coverage.load_stats(filename)`: Loads coverage statistics from a file
- `coverage.generate_report(options)`: Generates coverage reports in specified formats
- `coverage.validate_thresholds(data)`: Validates coverage against configured thresholds

### Configuration

Coverage settings are controlled via the central configuration system:

```lua
-- .firmo-config.lua
return {
  coverage = {
    enabled = true,                -- Enable coverage tracking
    
    -- Include/exclude patterns
    include_patterns = {
      ".*%.lua$",                  -- Include all .lua files
      "lib/.*"                     -- Include all files in lib directory
    },
    
    exclude_patterns = {
      "tests/.*",                  -- Exclude test files
      ".*_test%.lua$",             -- Exclude files ending with _test.lua
      "vendor/.*"                  -- Exclude vendor files
    },
    
    -- Stats file settings
    statsfile = "./.coverage-stats", -- Path to save coverage statistics
    
    -- Threshold settings
    thresholds = {
      line = 75,                    -- Minimum line coverage percentage
      function = 80,                -- Minimum function coverage percentage
      fail_on_threshold = true      -- Fail tests if thresholds not met
    },
    
    -- Report settings
    report = {
      formats = {"html", "json"},    -- Report formats to generate
      dir = "./coverage-reports",    -- Report output directory
      title = "Coverage Report",     -- Report title
      colors = {
        covered = "#00FF00",         -- Green for covered lines
        executed = "#FFA500",        -- Orange for executed lines
        not_covered = "#FF0000"      -- Red for not covered lines
      }
    }
  }
}
```

## Usage Examples

### Basic Usage

```lua
-- Start coverage tracking
coverage.start()

-- Run tests
-- ...

-- Stop coverage tracking
coverage.stop()

-- Generate reports in multiple formats
coverage.generate_report({
  formats = {"html", "json"},
  dir = "./coverage-reports"
})

-- Validate coverage against thresholds
local passed = coverage.validate_thresholds()
if not passed then
  print("Coverage thresholds not met")
end

-- Save stats for future runs
coverage.save_stats("./.coverage-stats")
```

### Integration with Test Runner

```lua
-- In runner.lua
local coverage = require("lib.coverage")
local config = require("lib.core.central_config")

local function run_tests_with_coverage(test_path)
  -- Load previous stats if available
  local statsfile = config.get("coverage.statsfile", "./.coverage-stats")
  if filesystem.exists(statsfile) then
    coverage.load_stats(statsfile)
  end
  
  -- Start coverage
  coverage.start()
  
  -- Run tests
  local success = run_tests(test_path)
  
  -- Stop coverage
  coverage.stop()
  
  -- Generate reports
  local report_config = config.get("coverage.report", {})
  coverage.generate_report({
    formats = report_config.formats or {"html"},
    dir = report_config.dir or "./coverage-reports",
    title = report_config.title or "Coverage Report"
  })
  
  -- Save stats for future runs
  coverage.save_stats(statsfile)
  
  -- Check thresholds if configured
  local thresholds = config.get("coverage.thresholds", {})
  if
