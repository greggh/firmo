# Output Formatting Guide


This guide explains how to customize the output and formatting of test results in Firmo.

## Introduction


When running tests, clear and readable output is essential for quickly understanding results. Firmo provides several ways to customize how test results are displayed, including:


- Changing output styles (detailed, compact, dot mode)
- Controlling color usage
- Customizing indentation
- Configuring error reporting
- Using specialized formatters for reports

This guide covers both command-line options and programmatic configuration of test output.

## Basic Output Formatting


### Command Line Formatting


The easiest way to change output is through command-line options:


```bash

# Run tests with dot output format (dots for each test)


lua test.lua --format dot tests/

# Run tests with compact output


lua test.lua --format compact tests/

# Run tests with detailed output


lua test.lua --format detailed tests/

# Run tests with summary only


lua test.lua --format summary tests/

# Run tests with plain text (no colors)


lua test.lua --format plain tests/
```



### Programmatic Formatting


You can also configure output programmatically:


```lua
local firmo = require("firmo")
-- Configure output style
firmo.format({
  use_color = true,      -- Use colored output
  indent_char = '  ',    -- Use spaces for indentation
  indent_size = 2,       -- Two spaces per level
  show_trace = true,     -- Show stack traces for errors
  compact = false        -- Use verbose output
})
```



## Output Format Options


Firmo provides several output formats designed for different use cases:

### Detailed Format (Default)


Shows comprehensive information about each test:


```text
Calculator
  ✓ adds two numbers
  ✓ subtracts two numbers
  ✗ divides by zero - Error: Cannot divide by zero
    at calculator.lua:42
Running 3 tests complete
✓ 2 passed, 1 failed
```



### Compact Format


More concise output, using dots to indicate passing tests:


```text
Calculator
  ..✗
Running 3 tests complete
✓ 2 passed, 1 failed
```



### Dot Format


Shows only a dot for each passing test, helpful for large test suites:


```text
...✗...
Running 7 tests complete
✓ 6 passed, 1 failed
```



### Summary Format


Shows only the final test summary:


```text
Running 7 tests complete
✓ 6 passed, 1 failed
```



## Customizing Output Appearance


### Color Configuration


Colors help highlight important information:


```lua
-- Enable colors (default)
firmo.format({ use_color = true })
-- Disable colors (for terminals without ANSI support)
firmo.format({ use_color = false })
-- Shorthand to disable colors
firmo.nocolor()
```



### Indentation Settings


Control how nested tests are indented:


```lua
-- Use two spaces per level
firmo.format({
  indent_char = ' ',
  indent_size = 2
})
-- Use tabs (default)
firmo.format({
  indent_char = '\t',
  indent_size = 1
})
```



### Error Reporting


Configure how much detail is shown for errors:


```lua
-- Show stack traces for errors
firmo.format({ show_trace = true })
-- Hide stack traces for concise output
firmo.format({ show_trace = false })
```



### Success Details


Control whether passing tests show details:


```lua
-- Show details for passing tests (default)
firmo.format({ show_success_detail = true })
-- Hide details for passing tests
firmo.format({ show_success_detail = false })
```



## Advanced Output Options


### Environment-based Configuration


Adapt output based on the execution environment:


```lua
-- Configure output based on environment
if os.getenv("CI") then
  -- CI environment - use plain output for logs
  firmo.format({
    use_color = false,
    summary_only = true
  })
elseif os.getenv("DEBUG") then
  -- Debug mode - show all details
  firmo.format({
    use_color = true,
    show_trace = true,
    show_success_detail = true
  })
else
  -- Normal development - balanced output
  firmo.format({
    use_color = true,
    compact = false,
    show_trace = false
  })
end
```



### Custom Formatters


For specialized output needs, consider using report formatters:


```lua
-- Configure HTML formatter using central_config
local central_config = require("lib.core.central_config")
local reporting = require("lib.reporting")
-- Configure HTML formatter
reporting.configure_formatter("html", {
  theme = "dark",               -- Use dark theme
  show_line_numbers = true,     -- Show line numbers
  collapsible_sections = true,  -- Allow collapsing sections
  highlight_syntax = true       -- Enable syntax highlighting
})
-- Run tests with HTML output
-- lua test.lua --format html tests/
```



### Report Generation


Generate structured reports from test results:


```lua
-- Generate HTML report
lua test.lua --format html --output-file report.html tests/
-- Generate JSON report
lua test.lua --format json --output-file report.json tests/
-- Generate XML report (JUnit format)
lua test.lua --format junit --output-file junit-report.xml tests/
```



## Common Use Cases


### Large Test Suites


For large test suites, consider using dot or compact mode:


```bash

# Run large test suite with dot output


lua test.lua --format dot tests/

# Run large test suite with compact output


lua test.lua --format compact tests/
```



### Continuous Integration


For CI systems, use plain text and summary formats:


```bash

# Run tests with CI-friendly output


lua test.lua --format plain --summary tests/
```



### Debugging Tests


When debugging, use detailed output with stack traces:


```lua
-- Configure for debugging
firmo.format({
  use_color = true,
  show_trace = true,
  show_success_detail = true,
  compact = false
})
```



### Terminal Output vs. HTML Reports


Different formats serve different purposes:


```bash

# Quick feedback in terminal


lua test.lua --format compact tests/

# Generate comprehensive HTML report


lua test.lua --format html --output-file coverage-report.html tests/
```



## Best Practices



1. **Match Output to Context**: Use detailed output for development and troubleshooting, compact formats for quick feedback, and specialized formats for reports.
2. **Consider Terminal Capabilities**: Not all terminals support colors or Unicode characters. Use plain format when needed.
3. **Balance Verbosity**: Too much output can hide important information; too little can make debugging difficult.
4. **Default to Clear Formatting**: Set project defaults that prioritize clarity for your team's workflow.
5. **Use HTML Reports for Sharing**: Generate HTML reports for sharing with team members or storing test results.
6. **Configure CI Output Properly**: Ensure CI systems use appropriate formatting for log storage and viewing.


## Troubleshooting Output Issues


### Colors Not Displaying


If colors aren't showing:


1. Check terminal support for ANSI colors
2. Try manually enabling colors:

   ```lua
   firmo.format({ use_color = true })
   ```


3. If colors can't be supported, explicitly disable them:

   ```lua
   firmo.format({ use_color = false })
   ```

### Too Much or Too Little Information


If output is hard to read:


1. For too much output, try compact mode:

   ```bash
   lua test.lua --format compact tests/
   ```


2. For too little detail, use the detailed format:

   ```bash
   lua test.lua --format detailed tests/
   ```


3. For debugging errors, enable stack traces:

   ```lua
   firmo.format({ show_trace = true })
   ```

## Conclusion


Effective output formatting helps you quickly understand test results and focus on what matters. Firmo's flexible output options let you customize how test results appear based on your specific needs, whether you're running tests during active development, in CI environments, or generating reports for broader consumption.
For practical examples, see the [output examples](/examples/output_examples.md) file.
