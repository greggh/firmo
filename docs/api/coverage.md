# Coverage Module

The Coverage module provides comprehensive code coverage tracking and reporting for Lua code. It uses an instrumentation-based approach to track which lines of code are executed and which lines are verified by assertions during test execution.

## Overview

The v3 coverage system is a complete overhaul of the previous debug hook-based system. It uses source code instrumentation to provide more accurate and detailed coverage information, including the critical distinction between code that is merely executed versus code that is actually verified by assertions.

### Three-State Coverage Model

The coverage system tracks three distinct states for each line of code:

1. **Covered** (Green): Lines that are both executed AND verified by assertions
2. **Executed** (Orange): Lines that are executed during tests but NOT verified by assertions
3. **Not Covered** (Red): Lines that are not executed at all

This distinction helps identify code that is running but not actually being tested properly.

## Architecture

The v3 coverage system is composed of several components:

1. **Instrumentation Engine**:
   - **Parser**: Parses Lua source code into an Abstract Syntax Tree (AST)
   - **Transformer**: Inserts tracking calls into the source code
   - **Sourcemap**: Maps instrumented line numbers to original source lines

2. **Module Loading Integration**:
   - **Loader Hook**: Intercepts module loading to instrument code on-the-fly
   - **Cache**: Caches instrumented modules for performance

3. **Runtime Tracking**:
   - **Tracker**: Records execution of code during tests
   - **Data Store**: Stores and manages coverage information

4. **Assertion Integration**:
   - **Assertion Hook**: Hooks into the assertion system
   - **Stack Analyzer**: Associates assertions with the code they verify

5. **Reporting System**:
   - **HTML Reporter**: Generates visual HTML reports with three-state visualization
   - **JSON Reporter**: Outputs machine-readable coverage data

## API Reference

### Coverage Module

```lua
local coverage = require("lib.coverage")
```

#### Public Functions

- `coverage.start()`: Starts coverage tracking
- `coverage.stop()`: Stops coverage tracking and collects data
- `coverage.reset()`: Resets coverage data
- `coverage.is_active()`: Checks if coverage is active
- `coverage.get_data()`: Gets the current coverage data
- `coverage.generate_report(format, output_path)`: Generates a coverage report

### Configuration

Coverage settings are controlled via the central configuration system:

```lua
-- .firmo-config.lua
return {
  coverage = {
    enabled = true,                     -- Enable coverage tracking
    version = 3,                       -- Use v3 coverage system
    
    -- Include/exclude functions
    include = function(path)
      return path:match("%.lua$") ~= nil
    end,
    
    exclude = function(path)
      return path:match("/tests/") ~= nil or path:match("test%.lua$") ~= nil
    end,
    
    -- Cache settings
    cache = {
      enabled = true,                  -- Enable caching for performance
      dir = "./.firmo-cache"           -- Cache directory
    },
    
    -- Instrumentation options
    instrumentation = {
      preserve_comments = true,        -- Keep comments in instrumented code
      preserve_whitespace = true,      -- Preserve whitespace
      track_branches = true,           -- Track branches for detailed coverage
      track_functions = true           -- Track function coverage
    },
    
    -- Report settings
    report = {
      format = "html",                 -- Default report format
      dir = "./coverage-reports",      -- Report output directory
      title = "Coverage Report",       -- Report title
      colors = {
        covered = "#00FF00",           -- Green for covered lines
        executed = "#FFA500",          -- Orange for executed lines
        not_covered = "#FF0000"        -- Red for not covered lines
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

-- Generate HTML report
coverage.generate_report("html", "./coverage-reports")
```

### Integration with Test Runner

```lua
-- In runner.lua
local coverage = require("lib.coverage")

local function run_tests_with_coverage(test_path)
  -- Start coverage
  coverage.start()
  
  -- Run tests
  local success = run_tests(test_path)
  
  -- Stop coverage
  coverage.stop()
  
  -- Generate report
  coverage.generate_report("html", "./coverage-reports")
  
  return success
end
```

## Report Formats

The coverage system supports multiple report formats:

### HTML Report

The HTML report provides a visual representation of coverage with syntax highlighting and three-state visualization:

- Green lines: Covered (executed and verified by assertions)
- Orange lines: Executed but not verified
- Red lines: Not executed

Features:
- File navigation panel
- Coverage summary statistics
- Line-by-line coverage information
- Syntax highlighting

### JSON Report

The JSON report provides machine-readable coverage data for integration with other tools:

```json
{
  "summary": {
    "total_files": 10,
    "total_lines": 1500,
    "covered_lines": 850,
    "executed_lines": 300,
    "not_covered_lines": 350,
    "coverage_percent": 56.67,
    "execution_percent": 76.67
  },
  "files": {
    "lib/module.lua": {
      "summary": {
        "total_lines": 150,
        "covered_lines": 85,
        "executed_lines": 30,
        "not_covered_lines": 35,
        "coverage_percent": 56.67,
        "execution_percent": 76.67
      },
      "lines": {
        "1": {"line_number": 1, "executed": true, "covered": true, "execution_count": 10},
        "2": {"line_number": 2, "executed": true, "covered": false, "execution_count": 5},
        "3": {"line_number": 3, "executed": false, "covered": false, "execution_count": 0}
      }
    }
  }
}
```