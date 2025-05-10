# Command Line Interface Configuration


This document describes the comprehensive configuration options for the firmo command line interface (CLI), which provides a unified interface for running tests, generating reports, and managing the testing environment.

## Overview


The CLI module provides a powerful interface for command-line interaction with support for:


- Comprehensive command-line argument parsing
- Multiple test execution modes (standard, watch, interactive)
- Test filtering and discovery
- Report generation in various formats
- Colorized terminal output
- Custom command registration
- Configuration persistence through the central configuration system


## Configuration Options


### Core Options


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `format` | string | `"default"` | Output format for test results (default, dot, summary, etc.) |
| `pattern` | string | `nil` | Pattern to filter test files |
| `dir` | string | `"tests"` | Directory to search for test files |
| `verbose` | boolean | `false` | Whether to show verbose output |
| `colorized` | boolean | `true` | Whether to use ANSI colors in terminal output |
| `help_headers` | table | `{}` | Custom headers for help sections |
| `default_commands` | table | `{}` | Default commands to show in help |
| `custom_commands` | table | `{}` | Custom registered commands |

### Output Format Options


| Format | Description |
|--------|-------------|
| `"default"` | Standard output with test name and status |
| `"dot"` | Minimal output with dots for each test |
| `"summary"` | Condensed summary with counts only |
| `"detailed"` | Verbose output with timing information |
| `"json"` | Machine-readable JSON output |
| `"tap"` | Test Anything Protocol format |

## Configuration in .firmo-config.lua


You can configure the CLI system in your `.firmo-config.lua` file:


```lua
return {
  -- CLI configuration
  cli = {
    -- Output format
    format = "detailed",          -- Use detailed output format

    -- Discovery settings
    dir = "tests",                -- Look for tests in this directory
    pattern = "*_test.lua",       -- Test file pattern

    -- Output settings
    colorized = true,             -- Use colorized output
    verbose = false,              -- Don't use verbose output by default

    -- Command configuration
    help_headers = {
      main = "Firmo Test Framework CLI",
      commands = "Available Commands:",
      options = "General Options:"
    },

    -- Default options for commands
    default_options = {
      test = {
        parallel = false,         -- Don't run tests in parallel by default
        coverage = true           -- Enable coverage by default
      },
      report = {
        format = "html",          -- Default report format
        output_dir = "reports"    -- Default report output directory
      }
    }
  }
}
```



## Programmatic Configuration


You can also configure the CLI system programmatically:


```lua
local cli = require("lib.tools.cli")
-- Configure CLI behavior
cli.configure({
  format = "detailed",         -- Detailed output format
  colorized = true,            -- Use ANSI colors
  verbose = false,             -- No verbose output
  pattern = "*_test.lua"       -- Test file pattern
})
-- Register a custom command
cli.register_command("lint", function(args)
  -- Run linting logic here
  return true -- Return success status
end, "Run linting on source files")
```



## Command Line Arguments


The CLI processes various command line arguments:


```bash

# Basic test run


lua firmo.lua tests/

# Run with pattern filter


lua firmo.lua --pattern="database" tests/

# Run with coverage


lua firmo.lua --coverage tests/

# Run in watch mode


lua firmo.lua --watch tests/

# Run in interactive mode


lua firmo.lua --interactive tests/

# Run in parallel


lua firmo.lua --parallel tests/

# Generate report


lua firmo.lua --coverage --format=html tests/

# Run quality validation


lua firmo.lua --quality --quality-level=3 tests/

# Show help


lua firmo.lua --help
```



## Test Execution Modes


The CLI supports various test execution modes:

### Standard Mode



```lua
-- Configure standard test execution
cli.configure({
  format = "default",
  verbose = false,
  colorized = true
})
-- Run tests in standard mode
cli.run({
  dir = "tests",
  pattern = "*_test.lua"
})
```



### Watch Mode



```lua
-- Configure watch mode
cli.configure({
  watch_interval = 1.0,           -- Check for changes every second
  watch_patterns = {"*.lua"},     -- Watch Lua files
  watch_exclude = {"node_modules"}  -- Exclude node_modules
})
-- Run tests in watch mode
cli.watch({
  dir = "tests",
  pattern = "*_test.lua"
})
```



### Interactive Mode



```lua
-- Configure interactive mode
cli.configure({
  prompt_symbol = ">",            -- Custom prompt symbol
  max_history = 100,              -- Command history size
  colorized_output = true         -- Use colors in output
})
-- Run tests in interactive mode
cli.interactive({
  dir = "tests"
})
```



## Custom Commands


You can register custom commands for the CLI:


```lua
-- Register a custom command
cli.register_command("lint", function(args)
  -- Run linting on source code
  local success = run_linter(args.dir or "src")
  return success
end, "Run linting on source files")
-- Register a command with detailed help
cli.register_command("benchmark", function(args)
  -- Run benchmarks
  return run_benchmarks(args.file, args.iterations)
end, {
  summary = "Run benchmarks",
  description = "Run performance benchmarks on specified files or functions",
  usage = "benchmark [file] [--iterations=N]",
  options = {
    file = "The file or function to benchmark",
    iterations = "Number of iterations to run (default: 1000)"
  }
})
```



## Report Generation


Configure report generation through the CLI:


```lua
-- Configure report generation
cli.configure({
  report = {
    format = "html",              -- Default format
    output_dir = "reports",       -- Output directory
    timestamp = true,             -- Add timestamp to filenames
    open_after = true             -- Open report after generation
  }
})
-- Generate reports
cli.report({
  format = "html,json",           -- Generate multiple formats
  output_dir = "custom-reports"   -- Custom output directory
})
```



## Output Formatting


Customize the output format for test results:


```lua
-- Configure output format
cli.configure({
  format = "detailed",            -- Detailed output
  colorized = true,               -- Use colors
  symbols = {
    pass = "✓",                   -- Custom pass symbol
    fail = "✗",                   -- Custom fail symbol
    skip = "-",                   -- Custom skip symbol
    pending = "?"                 -- Custom pending symbol
  }
})
```



## Integration with Test Runner


The CLI integrates with Firmo's test runner:


```lua
-- In test runner initialization
local cli = require("lib.tools.cli")
local runner = require("lib.core.runner")
-- Connect CLI to runner
runner.register_cli(cli)
-- Process command line arguments
local options = cli.parse_args()
-- Run tests based on options
if options.watch then
  cli.watch(options)
elseif options.interactive then
  cli.interactive(options)
else
  cli.run(options)
end
```



## Best Practices


### Setting Default Options



```lua
-- Set sensible defaults for your project
cli.configure({
  -- For standard development workflow
  format = "default",                -- Standard output
  colorized = true,                  -- Use colors

  -- Default directories
  dir = "tests",                     -- Test directory

  -- Commonly used options
  default_options = {
    test = {
      coverage = true,               -- Enable coverage by default
      parallel = true                -- Run tests in parallel by default
    },
    report = {
      format = "html",               -- Default to HTML reports
      output_dir = "reports"         -- Standard reports directory
    }
  }
})
```



### CI/CD Configuration


For continuous integration environments:


```lua
-- In .firmo-config.ci.lua
return {
  cli = {
    format = "detailed",             -- Detailed output for CI logs
    colorized = false,               -- No colors for CI logs
    verbose = true,                  -- Verbose output for debugging
    default_options = {
      test = {
        coverage = true,             -- Always enable coverage
        parallel = true,             -- Use parallel execution for speed
        quality = true,              -- Enable quality validation
        quality_level = 3            -- Use comprehensive quality level
      },
      report = {
        format = "lcov,cobertura",   -- Formats for CI integration
        output_dir = "ci-reports"    -- CI-specific directory
      }
    }
  }
}
```



### Custom Command Registration


For extending CLI functionality:


```lua
-- Register helpful development commands
cli.register_command("lint", function(args)
  return run_linter(args.dir or "src")
end, "Run linting on source files")
cli.register_command("docs", function(args)
  return generate_docs(args.output or "docs")
end, "Generate documentation")
cli.register_command("release", function(args)
  return create_release(args.version)
end, "Create a new release")
```



## Troubleshooting


### Common Issues



1. **Colors not displaying**:
   - Some terminals don't support ANSI colors
   - Set `colorized = false` for these environments
   - Use the `--no-color` command line flag
2. **Command not recognized**:
   - Ensure custom commands are registered before parsing arguments
   - Check command name casing (commands are case-sensitive)
   - Verify the command is registered in the correct CLI instance
3. **Incorrect output format**:
   - Verify the format name is supported
   - Make sure the format is properly specified (check spelling)
   - Try using the full format name instead of abbreviated version


## Example Configuration Files


### Development Configuration



```lua
-- .firmo-config.development.lua
return {
  cli = {
    format = "default",
    colorized = true,
    verbose = false,
    default_options = {
      test = {
        coverage = true,
        parallel = true,
        watch = false
      }
    }
  }
}
```



### CI Configuration



```lua
-- .firmo-config.ci.lua
return {
  cli = {
    format = "detailed",
    colorized = false,
    verbose = true,
    default_options = {
      test = {
        coverage = true,
        parallel = true,
        quality = true
      },
      report = {
        format = "lcov,cobertura",
        output_dir = "ci-reports"
      }
    }
  }
}
```



### Local Development Configuration



```lua
-- .firmo-config.local.lua (not checked into version control)
return {
  cli = {
    format = "default",
    colorized = true,
    verbose = true,  -- More verbose for local debugging
    default_options = {
      test = {
        coverage = true,
        parallel = false,  -- Disable parallel for easier debugging
        watch = true       -- Enable watch mode by default for development
      }
    }
  }
}
```


These configuration options give you complete control over the command line interface, allowing you to customize the testing experience for different environments and workflows.
