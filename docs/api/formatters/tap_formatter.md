# TAP Formatter API Reference

The TAP formatter produces coverage and test results in the Test Anything Protocol (TAP) format, compatible with TAP consumers, harnesses, and CI/CD systems that support TAP output.

## Overview

The TAP formatter generates TAP v13 compliant output with these key features:

- Full TAP v13 specification compliance
- Rich YAML diagnostics for test and coverage details
- Support for Skip and TODO test states
- BailOut handling for fatal errors
- Coverage data integrated into test results
- Configurable output formatting
- Hierarchical test organization support
- Embedded source snippets (optional)

## Class Reference

### Inheritance

```text
Formatter (Base)
  └── TAPFormatter
```

### Class Definition

```lua
---@class TAPFormatter : Formatter
---@field _VERSION string Version information
local TAPFormatter = Formatter.extend("tap", "tap")
```

## TAP v13 Specification

The TAP formatter implements TAP Version 13, which enhances the original TAP format with:

- YAML diagnostics blocks
- Explicit version declaration
- Improved directive handling
- Structured diagnostics

Basic TAP format structure:

```text
TAP version 13
1..n
ok 1 - Test description
not ok 2 - Failed test
ok 3 - # SKIP Skipped test
ok 4 # TODO Not implemented yet
Bail out! Fatal error occurred
```

### YAML Diagnostics

YAML diagnostics blocks provide detailed information:

```text
not ok 1 - Test failed
  ---
  message: Expected return value to equal 42, got 41
  severity: fail
  file: /path/to/test.lua
  line: 123
  source: |
    function test_return_value()
      return calculate() -- Should return 42
    end
  captured_output: |
    Error: calculation failed
    Stack trace...
  ...
```

## Core Methods

### format(data, options)

Formats coverage or test results data into TAP format.

```lua
---@param data table Normalized coverage or test results data
---@param options table|nil Formatting options
---@return string tap TAP-formatted report
---@return table|nil error Error object if formatting failed
function TAPFormatter:format(data, options)
```

### format_coverage(data, options)

Specialized method for formatting coverage data into TAP.

```lua
---@param data table Normalized coverage data
---@param options table|nil Formatting options
---@return string tap TAP-formatted coverage report
---@return table|nil error Error object if formatting failed
function TAPFormatter:format_coverage(data, options)
```

### format_results(data, options)

Specialized method for formatting test results into TAP.

```lua
---@param data table Test results data
---@param options table|nil Formatting options
---@return string tap TAP-formatted test results
---@return table|nil error Error object if formatting failed
function TAPFormatter:format_results(data, options)
```

### generate(data, output_path, options)

Generate and save a complete TAP report.

```lua
---@param data table Coverage or test results data
---@param output_path string Path to save the report
---@param options table|nil Formatting options
---@return boolean success Whether the operation succeeded
---@return string|table result Path to saved file or error object
function TAPFormatter:generate(data, output_path, options)
```

## Configuration Options

The TAP formatter supports these configuration options:

| Option | Type | Default | Description |

|--------|------|---------|-------------|

| `tap_version` | string | `"13"` | TAP version to declare |

| `include_yaml` | boolean | `true` | Include YAML diagnostics blocks |

| `yaml_indent` | string | `"  "` | Indentation for YAML blocks |

| `include_source` | boolean | `false` | Include source code in YAML diagnostics |

| `source_context` | number | `3` | Lines of context around source errors |

| `include_coverage` | boolean | `true` | Include coverage data in diagnostics |

| `include_summary` | boolean | | Include summary information |

| `strict_mode` | boolean | `false` | Strict TAP compliance mode |

| `handle_bailout` | boolean | `true` | Process BailOut directives |

| `directive_style` | string | `"#"` | Directive indicator style (`#` or `-`) |

| `max_line_length` | number | `0` | Max line length (0 = unlimited) |

| `wrap_long_lines` | boolean | `false` | Wrap lines exceeding max_line_length |

| `show_execution_count` | boolean | `true` | Show execution counts in output |

| `escape_non_ascii` | boolean | `true` | Escape non-ASCII characters |

| `file_as_tests` | boolean | `false` | Treat each file as a separate test |

### Configuration Example

```lua
local reporting = require("lib.reporting")
reporting.configure_formatter("tap", {
  tap_version = "13",
  include_yaml = true,
  yaml_indent = "  ",
  include_source = true,
  source_context = 5,
  include_coverage = true,
  strict_mode = false,
  directive_style = "#"
})
```

## Test Result Formatting

### Basic Test Structure

```text
TAP version 13
1..3
ok 1 - User authentication works correctly
not ok 2 - Database connection fails on invalid credentials
  ---
  message: Expected connection to fail but it succeeded
  file: tests/db_test.lua
  line: 42
  ...
ok 3 - Configuration loads from default path # SKIP Not implemented
```

### Subtests Support

The TAP formatter supports nested tests with proper indentation:

```text
TAP version 13
1..2

# Database tests

ok 1 - Database connection
    1..3
    ok 1 - Connects with valid credentials
    not ok 2 - Fails with invalid credentials
    ok 3 - Reconnects after timeout
ok 2 - User operations
    1..2
    ok 1 - Creates new user
    ok 2 - Updates user profile
```

### Skip and TODO Support

The TAP formatter properly handles Skip and TODO directives:

```text
ok 1 - Has proper permissions # SKIP Not relevant on this platform
ok 2 - Implements advanced search # TODO Planned for next release
```

### BailOut Handling

When fatal errors occur, the formatter can generate BailOut directives:

```text
1..5
ok 1 - Test one
ok 2 - Test two
Bail out! Fatal error: Database connection lost
```

## Coverage Information in TAP Format

Coverage data is represented in TAP format as a series of tests, with one test per file:

```text
TAP version 13
1..2

# Coverage for lib/module.lua (75.0%)

ok 1 - lib/module.lua
  ---
  coverage:
    total_lines: 100
    covered_lines: 75
    executed_lines: 25
    coverage_percent: 75.0
    execution_percent: 90.0
  lines:

    - line: 10

      executed: true
      covered: true
      execution_count: 5

    - line: 11

      executed: true
      covered: false
      execution_count: 3
    # ...more lines...
  ...

# Coverage for lib/other.lua (50.0%)

not ok 2 - lib/other.lua
  ---
  coverage:
    total_lines: 80
    covered_lines: 40
    executed_lines: 20
    coverage_percent: 50.0
    execution_percent: 60.0
  # ...more details...
  ...
```

## YAML Diagnostics Support

YAML blocks in TAP v13 provide structured diagnostic information:

### Error Details

```text
not ok 1 - Test failed
  ---
  message: Expected values to be equal
  severity: fail
  file: tests/example_test.lua
  line: 23
  expected: 42
  actual: 41
  trace: |
    tests/example_test.lua:23: in function test_calculation
    tests/runner.lua:156: in function run_test
  ...
```

### Coverage Details

```text
ok 1 - Module has sufficient coverage
  ---
  coverage_summary:
    files: 10
    lines: 500
    covered_lines: 350
    coverage_percent: 70.0
  uncovered_files:

    - path: lib/rarely_used.lua

      coverage: 20.0%

    - path: lib/utility.lua

      coverage: 45.0%
  ...
```

## Producer/Consumer Integration

### Integration with Prove

The TAP formatter integrates seamlessly with the Perl `prove` tool:

```bash

# Generate TAP report

lua firmo.lua --coverage --format=tap tests/ > results.tap

# Process with prove

prove --tap results.tap
```

### Integration with TAP Harness

```bash

# Run with TAP::Harness

tap-harness results.tap
```

### Integration with Jenkins TAP Plugin

Configure Jenkins to collect and display TAP reports:

1. Install the TAP Plugin in Jenkins
2. Add a "Publish TAP Results" post-build action
3. Configure the TAP file pattern (e.g., `coverage-reports/*.tap`)

```groovy
// Jenkinsfile example
pipeline {
  agent any
  stages {
    stage('Test') {
      steps {
        sh 'lua firmo.lua --coverage --format=tap tests/ > coverage-reports/results.tap'
      }
    }
  }
  post {
    always {
      step([$class: 'TapPublisher', 
            testResults: 'coverage-reports/*.tap',
            verbose: true,
            failIfNoResults: true,
            failedTestsMarkBuildAsFailure: true])
    }
  }
}
```

### Integration with GitLab CI

```yaml

# .gitlab-ci.yml

test:
  script:

    - lua firmo.lua --coverage --format=tap tests/ > coverage-reports/results.tap

  artifacts:
    paths:

      - coverage-reports/results.tap

    reports:
      junit: coverage-reports/results.tap
```

## Usage Example

```lua
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")
-- Configure the TAP formatter
reporting.configure_formatter("tap", {
  include_yaml = true,
  include_source = true,
  source_context = 3
})
-- Run tests with coverage
coverage.start()
-- Run tests here...
coverage.stop()
-- Generate TAP report from coverage data
local data = coverage.get_data()
local tap_content = reporting.format_coverage(data, "tap")
-- Save the report
reporting.write_file("coverage-report.tap", tap_content)
-- Or in one step:
reporting.save_coverage_report("coverage-report.tap", data, "tap")
```

## Combining Test Results and Coverage

To generate a comprehensive TAP report with both test results and coverage:

```lua
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")
local test_results = require("lib.core.test_results")
-- Run tests with coverage
coverage.start()
local results = run_tests()
coverage.stop()
-- Get coverage data
local coverage_data = coverage.get_data()
-- Create combined TAP report
local tap = reporting.format_coverage(coverage_data, "tap")
local test_tap = reporting.format_results(results, "tap")
-- Combine reports (preserving TAP structure)
local combined = combine_tap_reports(tap, test_tap)
-- Save combined report
reporting.write_file("combined-report.tap", combined)
-- Function to combine TAP reports
function combine_tap_reports(coverage_tap, test_tap)
  -- Extract headers and plan lines
  local coverage_header = coverage_tap:match("TAP version %d+\n")
  local coverage_plan = coverage_tap:match("1..%d+\n")
  local test_plan = test_tap:match("1..%d+\n")

  -- Extract test lines
  local coverage_tests = coverage_tap:gsub("TAP version %d+\n", ""):gsub("1..%d+\n", "")
  local test_tests = test_tap:gsub("TAP version %d+\n", ""):gsub("1..%d+\n", "")

  -- Count total tests
  local coverage_count = tonumber(coverage_plan:match("1..(%d+)"))
  local test_count = tonumber(test_plan:match("1..(%d+)"))
  local total_count = coverage_count + test_count

  -- Build combined report
  return coverage_header .. "1.." .. total_count .. "\n" .. 
         "# Coverage Tests\n" .. coverage_tests .. 
         "# Unit Tests\n" .. test_tests
end
```

## See Also

- [TAP Specification](https://testanything.org/tap-version-13-specification.html)
- [Reporting API](../reporting.md)
- [Coverage API](../coverage.md)
- [JUnit Formatter](./junit_formatter.md) - Alternative XML format for CI/CD
