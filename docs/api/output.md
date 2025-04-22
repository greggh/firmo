# Output Formatting API


This document describes the output formatting capabilities provided by Firmo, allowing you to customize how test results are displayed.

## Overview


Firmo provides a flexible output formatting system that allows you to customize how test results are presented. This includes options for colors, indentation, verbosity levels, and specialized output formats.
The output formatting options can dramatically improve the readability of your test output, especially when running large test suites.

## Formatting Functions


### firmo.format(options)


Configures the output formatting options.
**Parameters:**


- `options` (table): A table of formatting options (see formatting options table below)

  **Returns:**


- The firmo object (for chaining)

  **Example:**


```lua
-- Configure output formatting
firmo.format({
  use_color = true,
  indent_char = '  ',
  indent_size = 2,
  compact = true
})
```



### firmo.nocolor()


Disables colored output. This is a shorthand for `firmo.format({ use_color = false })`.
**Returns:**


- The firmo object (for chaining)

  **Example:**


```lua
-- Disable colored output
firmo.nocolor()
```



## Formatting Options


| Option                | Type    | Default | Description                                      |
| --------------------- | ------- | ------- | ------------------------------------------------ |
| `use_color`           | boolean | `true`  | Whether to use ANSI color codes in output        |
| `indent_char`         | string  | `'\t'`  | Character to use for indentation (tab or spaces) |
| `indent_size`         | number  | `1`     | How many indent_chars to use per level           |
| `show_trace`          | boolean | `false` | Whether to show stack traces for errors          |
| `show_success_detail` | boolean | `true`  | Whether to show details for successful tests     |
| `compact`             | boolean | `false` | Use compact output format (less verbose)         |
| `dot_mode`            | boolean | `false` | Use dot mode (. for pass, F for fail)            |
| `summary_only`        | boolean | `false` | Show only summary, not individual tests          |

## Examples


### Basic Configuration



```lua
local firmo = require('firmo')
-- Set up formatting before running tests
firmo.format({
  use_color = true,
  indent_char = '  ',
  indent_size = 2,
  show_trace = true
})
-- Your tests here
describe("My feature", function()
  it("works correctly", function()
    expect(1 + 1).to.equal(2)
  end)
end)
```



### Different Output Styles


#### Standard Output (Default)



```lua
firmo.format({
  use_color = true,
  show_success_detail = true,
  compact = false
})
```


This produces verbose output with colors:


```text
My feature
  PASS Test works correctly
```



#### Compact Output



```lua
firmo.format({
  compact = true,
  show_success_detail = false
})
```


This produces less verbose output:


```text
My feature
  .
```



#### Dot Mode



```lua
firmo.format({
  dot_mode = true
})
```


This produces minimal output with dots for passing tests and 'F' for failing tests:


```text
...F..
```



#### Summary Only



```lua
firmo.format({
  summary_only = true
})
```


This only shows the final summary:


```text
5 passes, 1 failure
```



#### Plain Text (No Colors)



```lua
firmo.format({
  use_color = false
})
```


or simply:


```lua
firmo.nocolor()
```


This disables ANSI color codes, useful for environments that don't support them.

### Custom Indentation



```lua
-- Using spaces for indentation
firmo.format({
  indent_char = ' ',
  indent_size = 2
})
-- Using tabs for indentation
firmo.format({
  indent_char = '\t',
  indent_size = 1
})
```



### Showing Stack Traces



```lua
firmo.format({
  show_trace = true
})
```


This shows full stack traces for errors:


```text
FAIL Test that will fail
  stack traceback:
    test.lua:10: in function 'fn'
    firmo.lua:283: in upvalue 'subject'
    firmo.lua:289: in function <firmo.lua:278>
```



## Command Line Integration


When running tests via the command line, you can use the `--format` option to specify a predefined format.


```bash

# Run tests with dot mode


lua test.lua --format dot

# Run tests with compact mode


lua test.lua --format compact

# Run tests with summary only


lua test.lua --format summary

# Run tests with detailed output


lua test.lua --format detailed

# Run tests with plain text (no colors)


lua test.lua --format plain
```


You can also customize indentation from the command line:


```bash

# Use spaces for indentation


lua test.lua --indent spaces

# Use 4 spaces for indentation


lua test.lua --indent 4

# Use tabs for indentation


lua test.lua --indent tabs
```



## Best Practices



1. **Choose the right format for the context**:
   - Use detailed output during development for clarity
   - Use dot mode or compact mode for large test suites
   - Use summary only for CI systems
2. **Consider the environment**:
   - Disable colors for environments that don't support ANSI color codes
   - Use plain text output for logs that will be stored
3. **Adjust verbosity for test size**:
   - For large test suites, use compact or dot mode
   - For focused testing, use detailed output with stack traces
4. **Consistent configuration**:
   - Set up standard formatting in project init files
   - Document formatting conventions for your team
5. **Configure for maximum readability**:
   - Use indentation that matches your code style
   - Use colors when supported to highlight important information


## Examples in Context


### Error Handling


With detailed error output:


```lua
-- Enable detailed error output
firmo.format({
  show_trace = true,
  show_success_detail = true
})
describe("Error handling", function()
  it("provides helpful error messages", function()
    local function will_error()
      error("Something went wrong")
    end
    -- This will fail and show detailed error information
    will_error()
  end)
end)
```



### CI Integration


For CI environments, you might want summary-only output for logs:


```lua
-- Check if we're running in a CI environment
local in_ci = os.getenv("CI") == "true"
if in_ci then
  -- Use summary only mode for CI
  firmo.format({
    summary_only = true,
    use_color = false  -- Many CI log systems don't support color
  })
else
  -- Use detailed mode for local development
  firmo.format({
    show_trace = true,
    compact = false
  })
end
```



### Large Test Suites


For large test suites, dot mode can provide a compact overview:


```lua
firmo.format({
  dot_mode = true
})
-- When many tests run, you'll see something like:
-- .........................F...........
--
-- Followed by details on the single failure
```
