# LCOV Formatter API Reference

The LCOV formatter generates coverage reports in the industry-standard LCOV format for integration with external analysis tools, CI/CD pipelines, and coverage visualization utilities.

## Overview

The LCOV formatter produces standard-compliant LCOV files with these key features:

- Full compliance with the LCOV format specification
- Seamless integration with LCOV tools like `genhtml` and `geninfo`
- Support for line, function, and branch coverage data
- Path normalization for cross-platform compatibility
- Configurable source file handling
- Specialized handling for Lua's non-traditional branch structure

## Class Reference

### Inheritance

```text
Formatter (Base)
  └── LCOVFormatter
```

### Class Definition

```lua
---@class LCOVFormatter : Formatter
---@field _VERSION string Version information
local LCOVFormatter = Formatter.extend("lcov", "lcov")
```

## LCOV Format Specification

LCOV is a line-oriented, plain-text format with this structure:

```text
TN:<test name>
SF:<source file>
FN:<line number>,<function name>
FNDA:<execution count>,<function name>
FNF:<number of functions>
FNH:<number of functions hit>
DA:<line number>,<execution count>
LF:<number of instrumented lines>
LH:<number of lines with non-zero execution count>
end_of_record
```

Where:

- `TN` = Test Name (optional)
- `SF` = Source File path
- `FN` = Function definition line and name
- `FNDA` = Function execution data
- `FNF` = Functions Found (total)
- `FNH` = Functions Hit (executed)
- `DA` = Line execution data
- `LF` = Lines Found (instrumented)
- `LH` = Lines Hit (executed)

## Core Methods

### format(data, options)

Formats coverage data into LCOV format.

```lua
---@param data table Normalized coverage data
---@param options table|nil Formatting options
---@return string lcov LCOV-formatted coverage report
---@return table|nil error Error object if formatting failed
function LCOVFormatter:format(data, options)
```

### generate(data, output_path, options)

Generate and save a complete LCOV report.

```lua
---@param data table Coverage data
---@param output_path string Path to save the report
---@param options table|nil Formatting options
---@return boolean success Whether the operation succeeded
---@return string|table result Path to saved file or error object
function LCOVFormatter:generate(data, output_path, options)
```

## Configuration Options

The LCOV formatter supports these configuration options:

| Option | Type | Default | Description |

|--------|------|---------|-------------|

| `test_name` | string | `"firmo"` | Test name to include in TN records |

| `include_functions` | boolean | `true` | Include function coverage data |

| `include_branches` | boolean | `false` | Include branch coverage data (experimental) |

| `normalize_paths` | boolean | `true` | Normalize file paths for cross-platform compatibility |

| `base_directory` | string | `"."` | Base directory for relative paths |

| `path_prefix` | string | `""` | Prefix to add to all file paths |

| `source_encoding` | string | `"utf8"` | Source file encoding |

| `include_zero_exec` | boolean | `true` | Include lines with zero executions |

| `empty_entries` | boolean | `true` | Include "empty" entries (0 execution count) |

| `end_marker` | string | `"end_of_record"` | End of record marker |

| `path_separator` | string | `"/"` | Path separator character to use |

### Configuration Example

```lua
local reporting = require("lib.reporting")
reporting.configure_formatter("lcov", {
  test_name = "MyProject",                 -- Custom test name
  include_functions = true,                -- Include function data
  normalize_paths = true,                  -- Standardize paths
  base_directory = "./src",                -- Set base directory
  path_prefix = "MyProject/src/"           -- Add path prefix for tools
})
```

## Integration with LCOV Tools

### Using with genhtml

The LCOV formatter integrates seamlessly with the standard `genhtml` tool:

```bash

# Generate LCOV report

lua firmo.lua --coverage --format=lcov tests/

# Generate HTML from LCOV data using genhtml

genhtml -o coverage-html coverage-reports/coverage-report.lcov
```

### Using with lcov-summary

```bash

# Generate a summary from LCOV data

lcov-summary coverage-reports/coverage-report.lcov
```

### Using with other LCOV tools

The formatter's output is compatible with all standard LCOV tools:

- `lcov` - For combining LCOV trace files
- `geninfo` - For generating LCOV data files
- `lcov-result-merger` - For merging multiple LCOV files
- `lcov-parse` - For parsing LCOV data programmatically

## File Structure and Line Mapping

### Path Normalization

The LCOV formatter normalizes file paths to ensure compatibility across operating systems:

1. Converts backslash to forward slash on Windows
2. Optionally adds base directory prefix
3. Optionally adds custom path prefix
4. Resolves relative path segments (../, ./)

### Line Mapping

Line numbers in LCOV format are mapped directly from the coverage data:

```lua
-- DA records in LCOV (line execution data)
DA:10,5   -- Line 10 was executed 5 times
DA:11,0   -- Line 11 was not executed (optional, depends on include_zero_exec)
```

Function mapping:

```lua
-- FN records in LCOV (function definition)
FN:15,calculate    -- Function 'calculate' starts on line 15
-- FNDA records in LCOV (function execution data)
FNDA:10,calculate  -- Function 'calculate' was called 10 times
```

## Usage Example

```lua
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")
-- Configure the LCOV formatter
reporting.configure_formatter("lcov", {
  test_name = "MyProject",
  normalize_paths = true,
  base_directory = "./src"
})
-- Run tests with coverage
coverage.start()
-- Run tests here...
coverage.stop()
-- Generate LCOV report
local data = coverage.get_data()
local lcov_content = reporting.format_coverage(data, "lcov")
-- Save the report
reporting.write_file("coverage-report.lcov", lcov_content)
-- Or in one step:
reporting.save_coverage_report("coverage-report.lcov", data, "lcov")
```

## CI/CD Integration

### GitHub Actions

Use LCOV reports for GitHub Actions with Coveralls:

```yaml

# .github/workflows/coverage.yml

jobs:
  test:
    runs-on: ubuntu-latest
    steps:

      - uses: actions/checkout@v2

      - name: Setup Lua

        uses: leafo/gh-actions-lua@v8

      - name: Run tests with coverage

        run: lua firmo.lua --coverage --format=lcov tests/

      - name: Coveralls

        uses: coverallsapp/github-action@master
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          path-to-lcov: ./coverage-reports/coverage-report.lcov
```

### GitLab CI

```yaml

# .gitlab-ci.yml

test:
  script:

    - lua firmo.lua --coverage --format=lcov tests/

  artifacts:
    paths:

      - coverage-reports/coverage-report.lcov

    reports:
      coverage_report:
        coverage_format: lcov
        path: coverage-reports/coverage-report.lcov
```

### Jenkins

Use the Jenkins LCOV plugin:

```groovy
pipeline {
  agent any
  stages {
    stage('Test') {
      steps {
        sh 'lua firmo.lua --coverage --format=lcov tests/'
      }
    }
  }
  post {
    always {
      // Use the LCOV Plugin to visualize coverage
      lcov(
        pattern: 'coverage-reports/coverage-report.lcov',
        skip: false
      )
    }
  }
}
```

## Error Handling

The LCOV formatter handles these common issues:

1. **Invalid Data Structure**: Validates input and reports structured errors
2. **File Access Problems**: Handles file system errors when saving reports
3. **Path Normalization Issues**: Reports problems with path normalization
4. **Data Conversion Errors**: Provides detailed context for data conversion failures

### Error Response Example

```lua
local success, result_or_error = reporting.format_coverage(invalid_data, "lcov")
if not success then
  print("Error: " .. result_or_error.message)
  print("Category: " .. result_or_error.category)
  if result_or_error.context and result_or_error.context.file then
    print("Problem with file: " .. result_or_error.context.file)
  end
end
```

## Data Structure Requirements

To generate valid LCOV reports, the coverage data must include:

1. **Files Table**: Mapping of file paths to file data
2. **Line Data**: Information about line execution counts
3. **Summary Information**: Overall coverage statistics

At minimum, each file record must include:

- `path`: The file path
- `lines`: Table of line entries
- `summary`: Summary statistics

Each line entry must include:

- `line_number`: The line number
- `executed`: Whether the line was executed
- `execution_count`: How many times the line was executed

Function data should include:

- `name`: Function name
- `start_line`: Starting line number
- `executed`: Whether the function was executed
- `execution_count`: Function call count

## Performance Considerations

### File Size

LCOV reports are generally compact compared to other formats:

- No source code inclusion
- Line-based plain text format
- Minimal overhead beyond raw data

For large projects:

- Expect approximately 30-60 bytes per covered line
- Scales linearly with codebase size

### Processing Speed

The LCOV formatter is efficient in terms of:

- Memory usage: Low overhead, minimal temporary objects
- CPU usage: Simple string concatenation operations
- I/O operations: Single-pass file writing

For performance optimization:

- Set `include_functions = false` if function data isn't needed
- Disable `normalize_paths` if path normalization is unnecessary

## See Also

- [LCOV Project Documentation](http://ltp.sourceforge.net/coverage/lcov.php)
- [genhtml Documentation](http://ltp.sourceforge.net/coverage/lcov/genhtml.1.php)
- [Reporting API](../reporting.md)
- [Coverage API](../coverage.md)
- [Cobertura Formatter](./cobertura_formatter.md) - Alternative XML format
