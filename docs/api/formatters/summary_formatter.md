# Summary Formatter API Reference

The Summary formatter generates text-based coverage reports that provide a concise overview of coverage statistics, suitable for display in terminals, logs, and continuous integration output.

## Overview

The Summary formatter produces text reports with these key features:

- Compact, readable overview of coverage statistics
- Terminal-friendly output with ANSI color support
- Multiple output styles (compact, detailed, hierarchical)
- Customizable formatting and display options
- File filtering and sorting capabilities
- Progress indicators for coverage levels
- Threshold-based highlighting
- Direct terminal integration

## Class Reference

### Inheritance

```
Formatter (Base)
  └── SummaryFormatter
```

### Class Definition

```lua
---@class SummaryFormatter : Formatter
---@field _VERSION string Version information
local SummaryFormatter = Formatter.extend("summary", "txt")
```

## Text-Based Summary Format

The Summary formatter provides several output formats tailored for different use cases:

### Compact Format (Default)

```
Coverage Summary:
Total Files:      25
Total Lines:      2547
Covered Lines:    1876
Coverage:         73.7%
Execution:        82.5%

Files below threshold (<75%):
  lib/module.lua              64.3%  ████████████▒▒▒▒▒▒
  lib/other.lua               58.9%  ███████████▒▒▒▒▒▒▒
```

### Detailed Format

```
Coverage Summary (2025-04-12 21:45:14)

Overall Statistics:
  Files:               25
  Total Lines:         2547
  Covered Lines:       1876 (73.7%)
  Executed Lines:      2101 (82.5%)
  Uncovered Lines:     671 (26.3%)
  Function Coverage:   85.2%

Files by Coverage:
  ✓ lib/core/utils.lua              95.2%  ███████████████████▒
  ✓ lib/reporting/format.lua        92.1%  ██████████████████▒▒
  ✓ lib/coverage/init.lua           88.4%  █████████████████▒▒▒
  ⚠ lib/module.lua                  64.3%  ████████████▒▒▒▒▒▒
  ✗ lib/other.lua                   58.9%  ███████████▒▒▒▒▒▒▒

Performance:
  Execution Time: 1.23s
  Processed 2547 lines at 2070 lines/s
```

### Hierarchical Format

```
Coverage Summary:

lib/ (75.2%)
  ├── core/ (89.4%)
  │   ├── utils.lua               95.2%  ███████████████████▒
  │   └── config.lua              83.7%  ████████████████▒▒▒
  ├── reporting/ (82.1%)
  │   ├── format.lua              92.1%  ██████████████████▒▒
  │   └── schema.lua              72.1%  ██████████████▒▒▒▒▒
  └── coverage/ (88.4%)
      ├── init.lua                88.4%  █████████████████▒▒▒
      └── format.lua              86.7%  █████████████████▒▒▒
```

## Core Methods

### format(data, options)

Formats coverage data into text summary.

```lua
---@param data table Normalized coverage data
---@param options table|nil Formatting options
---@return string text Text-formatted coverage summary
---@return table|nil error Error object if formatting failed
function SummaryFormatter:format(data, options)
```

### generate(data, output_path, options)

Generate and save a complete text summary report.

```lua
---@param data table Coverage data
---@param output_path string Path to save the report
---@param options table|nil Formatting options
---@return boolean success Whether the operation succeeded
---@return string|table result Path to saved file or error object
function SummaryFormatter:generate(data, output_path, options)
```

## Configuration Options

The Summary formatter supports these configuration options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `style` | string | `"compact"` | Output style ("compact", "detailed", "hierarchical") |
| `include_timestamp` | boolean | `true` | Include timestamp in the report |
| `color` | boolean | `true` | Use ANSI color escape sequences |
| `progress_bars` | boolean | `true` | Show visual progress bars for coverage |
| `progress_char` | string | `"█"` | Character for progress bar filled sections |
| `progress_empty` | string | `"▒"` | Character for progress bar empty sections |
| `progress_width` | number | `20` | Width of progress bars in characters |
| `sort_by` | string | `"coverage"` | Sort files by ("coverage", "path", "name") |
| `sort_direction` | string | `"desc"` | Sort direction ("asc", "desc") |
| `thresholds` | table | `{good=80, warn=70}` | Coverage thresholds for status indicators |
| `show_uncovered_files` | boolean | `true` | Include files with 0% coverage |
| `show_files` | boolean | `true` | Show individual file information |
| `max_files` | number | `10` | Maximum number of files to show (0 = all) |
| `max_filename_length` | number | `30` | Truncate filenames to this length |
| `show_execution_count` | boolean | `false` | Show execution counts for lines |
| `min_coverage` | number | `0` | Minimum coverage to show a file |
| `max_coverage` | number | `100` | Maximum coverage to show a file |
| `filter_pattern` | string | `nil` | Pattern to filter files (Lua pattern) |
| `exclude_pattern` | string | `nil` | Pattern to exclude files (Lua pattern) |
| `directory_depth` | number | `0` | Max directory depth for hierarchical view (0 = all) |
| `show_statistics` | boolean | `true` | Show overall statistics section |
| `show_performance` | boolean | `false` | Show performance information |
| `precision` | number | `1` | Decimal precision for percentages |
| `status_indicator` | boolean | `true` | Show status indicators (✓, ⚠, ✗) |
| `status_chars` | table | `{good="✓",warn="⚠",bad="✗"}` | Characters for status indicators |

### Configuration Example

```lua
local reporting = require("lib.reporting")
reporting.configure_formatter("summary", {
  style = "detailed",
  color = true,
  progress_bars = true,
  progress_width = 25,
  sort_by = "coverage",
  sort_direction = "desc",
  thresholds = {
    good = 85,  -- Green above 85%
    warn = 70   -- Yellow between 70-85%, Red below 70%
  },
  max_files = 20,
  show_statistics = true,
  show_performance = true,
  precision = 1
})
```

## Color and Formatting Support

The Summary formatter supports ANSI color codes for terminal output:

```lua
-- Configure with custom colors
reporting.configure_formatter("summary", {
  color = true,
  colors = {
    header = "\27[1;36m",      -- Bright cyan for headers
    good = "\27[1;32m",        -- Bright green for good coverage
    warn = "\27[1;33m",        -- Bright yellow for warning coverage
    bad = "\27[1;31m",         -- Bright red for poor coverage
    default = "\27[0m",        -- Default terminal color
    bold = "\27[1m",           -- Bold text
    dim = "\27[2m",            -- Dim text
    reset = "\27[0m"           -- Reset all formatting
  }
})
```

### Disabling Colors

For environments that don't support ANSI codes:

```lua
-- CI/CD environment with no color support
reporting.configure_formatter("summary", {
  color = false,
  progress_bars = true,        -- Still show progress bars using ASCII
  progress_char = "#",         -- Use simple ASCII character for progress
  progress_empty = ".",        -- Use simple ASCII character for empty
  status_chars = {
    good = "+",                -- Use ASCII instead of Unicode
    warn = "!",
    bad = "X"
  }
})
```

## Output Customization

### Custom Progress Bars

```lua
-- Custom progress bar appearance
reporting.configure_formatter("summary", {
  progress_bars = true,
  progress_width = 10,        -- Shorter bars
  progress_char = "=",        -- ASCII bar filling
  progress_empty = " ",       -- Empty space for unfilled bar
  progress_prefix = "[",      -- Add brackets around progress bar
  progress_suffix = "]"
})
```

Produces bars like: `[======    ]` instead of the default `██████▒▒▒▒`.

### Custom Thresholds

```lua
-- Custom thresholds for coverage quality
reporting.configure_formatter("summary", {
  thresholds = {
    good = 90,                -- Higher standard for good coverage
    warn = 75                 -- Higher threshold for warnings
  },
  status_indicator = true,
  status_chars = {
    good = "PASS",            -- Text instead of symbols
    warn = "WARN",
    bad = "FAIL"
  }
})
```

### Custom File Selection

```lua
-- Show only specific files
reporting.configure_formatter("summary", {
  filter_pattern = "^lib/core/",  -- Only files in lib/core/
  exclude_pattern = "_test%.lua$", -- Exclude test files
  min_coverage = 50,           -- Only files with at least 50% coverage
  max_coverage = 95            -- Only files with at most 95% coverage
})
```

## Terminal Integration

The Summary formatter is designed for direct terminal output:

```lua
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")

-- Run tests with coverage
coverage.start()
-- Run tests here...
coverage.stop()

-- Generate summary for terminal output
local data = coverage.get_data()
local summary = reporting.format_coverage(data, "summary")

-- Print directly to terminal
print(summary)

-- For CI environments, save to file as well
reporting.write_file("coverage-summary.txt", summary)
```

### Integration with Test Runner

```lua
-- In runner.lua
local function run_tests_with_coverage(args)
  -- Start coverage
  coverage.start()
  
  -- Run tests
  local success = true
  for _, test_file in ipairs(args.files) do
    success = success and run_test_file(test_file)
  end
  
  -- Stop coverage
  coverage.stop()
  
  -- Print summary to terminal
  local summary_config = {
    color = args.color ~= false,
    style = args.verbose and "detailed" or "compact",
    max_files = args.verbose and 0 or 10
  }
  
  local summary = reporting.format_coverage(
    coverage.get_data(), 
    "summary",
    summary_config
  )
  
  print("\nCoverage Summary:")
  print(summary)
  
  -- Save detailed reports if requested
  if args.save_reports then
    reporting.save_coverage_report("coverage-report.html", coverage.get_data(), "html")
  end
  
  return success
end
```

## Statistics Calculation

The Summary formatter calculates these statistics:

| Statistic | Description | Calculation |
|-----------|-------------|-------------|
| Total Files | Number of files in coverage data | `#data.files` |
| Total Lines | Total lines analyzed | Sum of `file.summary.total_lines` |
| Covered Lines | Lines covered by tests | Sum of `file.summary.covered_lines` |
| Executed Lines | Lines that executed | Sum of `file.summary.executed_lines` |
| Coverage % | Percentage of covered lines | `(covered_lines / total_lines) * 100` |
| Execution % | Percentage of executed lines | `(executed_lines / total_lines) * 100` |
| Function Coverage % | Percentage of covered functions | `(covered_functions / total_functions) * 100` |

### Custom Statistics

Add custom statistics to the summary:

```lua
-- Add custom metrics
reporting.configure_formatter("summary", {
  style = "detailed",
  custom_statistics = {
    {
      name = "Branch Coverage",
      value = function(data)
        -- Calculate custom metric from data
        local branches_total = 0
        local branches_covered = 0
        for _, file in pairs(data.files) do
          if file.branches then
            for _, branch in pairs(file.branches) do
              branches_total = branches_total + 1
              if branch.covered then
                branches_covered = branches_covered + 1
              end
            end
          end
        end
        return {
          value = branches_covered / (branches_total > 0 and branches_total or 1) * 100,
          format = "%.1f%%",
          description = string.format("%d/%d branches", branches_covered, branches_total)
        }
      end
    }
  }
})
```

## File Filtering

The Summary formatter supports robust file filtering:

### Pattern-Based Filtering

```lua
-- Include only specific files
reporting.configure_formatter("summary", {
  filter_pattern = "^lib/.*%.lua$",  -- Only Lua files in lib/
  exclude_pattern = "test"           -- Exclude any path containing "test"
})
```

### Coverage-Based Filtering

```lua
-- Show files needing attention
reporting.configure_formatter("summary", {
  min_coverage = 0,          -- Minimum coverage
  max_coverage = 75,         -- Maximum coverage
  sort_by = "coverage",      -- Sort by coverage percentage
  sort_direction = "asc"     -- Ascending (worst first)
})
```

### Combined Filtering

```lua
-- Focused view of core modules needing work
reporting.configure_formatter("summary", {
  filter_pattern = "^lib/core/",     -- Only core modules
  exclude_pattern = "_internal%.lua$", -- Exclude internal modules
  max_coverage = 90,                 -- Only modules below 90%
  sort_by = "coverage",              -- Sort by coverage
  sort_direction = "asc",            -- Worst first
  max_files = 5                      -- Only show 5 worst files
})
```

## Output Styles

### Compact Style

The compact style focuses on a brief summary with minimal file details:

```lua
reporting.configure_formatter("summary", {
  style = "compact",
  max_files = 5,              -- Only show 5 files needing attention
  show_statistics = true,
  progress_bars = true,
  progress_width = 15
})
```

Output example:

```
Coverage Summary:
Files: 25 | Lines: 2547 | Covered: 73.7% | Executed: 82.5%

Files below threshold (<75%):
  lib/module.lua              64.3%  █████████▒▒▒▒▒
  lib/other.lua               58.9%  ████████▒▒▒▒▒▒
```

### Detailed Style

The detailed style provides comprehensive information:

```lua
reporting.configure_formatter("summary", {
  style = "detailed",
  show_statistics = true,
  show_performance = true,
  show_execution_count = true,
  progress_bars = true
})
```

Output example:

