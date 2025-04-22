# Interactive Mode Configuration


This document describes the comprehensive configuration options for the firmo interactive testing mode, which provides a command-line interface for running tests, filtering, and debugging interactively.

## Overview


The interactive module provides a powerful TUI (Text-based User Interface) for test execution with support for:


- Command history with persistence
- Tab completion for commands and filenames
- Integrated watch mode for file monitoring
- Color-coded output
- Custom command registration
- Configurable prompt and appearance
- Integration with the central configuration system


## Configuration Options


### Core Options


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `test_dir` | string | `"./tests"` | Directory to search for tests. |
| `test_pattern` | string | `"*_test.lua"` | Pattern to match test files. |
| `watch_mode` | boolean | `false` | Whether to enable watch mode by default. |
| `watch_dirs` | string[] | `["."]` | Directories to watch for changes. |
| `watch_interval` | number | `1.0` | Interval between file change checks (in seconds). |
| `exclude_patterns` | string[] | `["node_modules", ".git"]` | Patterns to exclude from watching. |
| `max_history` | number | `100` | Maximum number of commands to keep in history. |
| `colorized_output` | boolean | `true` | Whether to enable colorized output. |
| `prompt_symbol` | string | `">"` | Symbol to use for the command prompt. |
| `debug` | boolean | `false` | Enable debug mode with additional logging. |
| `verbose` | boolean | `false` | Enable verbose output. |

## Configuration in .firmo-config.lua


You can configure the interactive mode in your `.firmo-config.lua` file:


```lua
return {
  -- Interactive mode configuration
  interactive = {
    -- Test discovery
    test_dir = "./tests",                   -- Directory to search for tests
    test_pattern = "*_test.lua",            -- Pattern to match test files

    -- Watch mode
    watch_mode = true,                      -- Enable watch mode by default
    watch_dirs = {"./src", "./tests"},      -- Directories to watch
    watch_interval = 0.5,                   -- Check every 0.5 seconds
    exclude_patterns = {
      "node_modules",                       -- Skip node_modules
      "%.git",                              -- Skip git directory
      "%.vscode",                           -- Skip vscode directory
      "coverage%-reports"                   -- Skip coverage reports
    },

    -- UI options
    max_history = 100,                      -- Remember 100 commands
    colorized_output = true,                -- Use colorized output
    prompt_symbol = "→",                    -- Custom prompt symbol

    -- Debugging
    debug = false,                          -- No debug mode by default
    verbose = false                         -- No verbose output by default
  }
}
```



## Programmatic Configuration


You can also configure the interactive mode programmatically:


```lua
local interactive = require("lib.tools.interactive")
-- Basic configuration
interactive.configure({
  test_dir = "./tests",
  test_pattern = "*_test.lua",
  watch_mode = true,
  colorized_output = true
})
-- Set custom prompt
interactive.set_prompt("firmo> ")
-- Set specific options
interactive.configure({
  watch_dirs = {"./src", "./tests"},
  watch_interval = 0.5,
  exclude_patterns = {"node_modules", ".git"}
})
```



## Command History Configuration


Control how command history is managed:


```lua
-- Configure history
interactive.configure({
  max_history = 200,                -- Store up to 200 commands
  history_file = ".firmo_history"   -- Custom history file
})
-- Load history from a file
interactive.load_history(".custom_history")
-- Save history to a file
interactive.save_history(".saved_history")
```



## Watch Mode Configuration


Configure the integrated file watcher:


```lua
-- Configure watch mode
interactive.configure({
  watch_mode = true,                -- Enable watch mode
  watch_dirs = {                    -- Directories to watch
    "./src",                        -- Source files
    "./tests",                      -- Test files
    "./config"                      -- Configuration files
  },
  watch_interval = 0.5,             -- Check every 0.5 seconds
  exclude_patterns = {              -- Patterns to exclude
    "node_modules",
    "%.git",
    "%.swp$",                       -- Vim swap files
    "~$"                            -- Backup files
  }
})
```



## Custom Commands


Register custom commands for the interactive mode:


```lua
-- Register a custom command
interactive.register_command("lint", function(args)
  -- Run linting on source code
  print("Running linter...")
  os.execute("luacheck " .. (args[1] or "src"))
  return true
end, "Run the linter on source code")
-- Register a command with subcommands
interactive.register_command("db", function(args)
  local subcommand = args[1] or "help"

  if subcommand == "migrate" then
    print("Running database migrations...")
    return run_migrations()
  elseif subcommand == "reset" then
    print("Resetting database...")
    return reset_database()
  else
    print("Available db commands: migrate, reset")
    return true
  end
end, "Database management commands")
```



## Output Customization


Configure output appearance:


```lua
-- Configure output
interactive.configure({
  colorized_output = true           -- Enable colors
})
-- Print colorized text
interactive.print("Test passed!", "green")
interactive.print("Test failed!", "red")
interactive.print("Skipped test", "yellow")
-- Clear the screen
interactive.clear()
```



## Integration with Test Runner


The interactive mode integrates with Firmo's test runner:


```lua
-- In test runner initialization
local interactive = require("lib.tools.interactive")
local runner = require("lib.core.runner")
-- Initialize interactive mode with runner
interactive.init({
  -- Pass reference to runner
  runner = runner,

  -- Configuration options
  test_dir = "./tests",
  test_pattern = "*_test.lua",
  colorized_output = true
})
-- Start interactive mode
interactive.start()
```



## Command Line Integration


Launch interactive mode from the command line:


```bash

# Start interactive mode


lua test.lua --interactive

# Start with custom test directory


lua test.lua --interactive --dir=custom/tests

# Start with watch mode enabled


lua test.lua --interactive --watch

# Start with specific watch directories


lua test.lua --interactive --watch --watch-dirs=src,tests
```



## Built-in Commands


The interactive mode includes several built-in commands:
| Command | Description |
|---------|-------------|
| `help` | Show available commands and help text |
| `run` | Run tests (all or filtered) |
| `filter` | Set pattern filter for tests |
| `watch` | Toggle watch mode |
| `focus` | Focus on specific test file or pattern |
| `tag` | Filter tests by tag |
| `coverage` | Toggle coverage reporting |
| `config` | Show or set configuration |
| `clear` | Clear the screen |
| `quit` | Exit interactive mode |
| `history` | Show command history |

## Command Completion


Configure command completion behavior:


```lua
-- Set custom completion handler
interactive.set_completion_handler(function(input)
  -- Return possible completions for input
  if input:match("^run%s+") then
    -- Complete test file names
    local partial = input:match("^run%s+(.*)$") or ""
    return find_matching_test_files(partial)
  end

  -- Return default completions for other commands
  return default_completions(input)
end)
```



## Best Practices


### Setting Up Developer Environment



```lua
-- In .firmo-config.lua
return {
  interactive = {
    -- Developer-friendly settings
    test_dir = "./tests",
    watch_mode = true,
    watch_dirs = {"./src", "./tests"},
    watch_interval = 0.5,
    colorized_output = true,

    -- Commands to show prominently in help
    prominent_commands = {
      "run", "filter", "focus", "watch", "coverage"
    }
  }
}
```



### Custom Commands for Project Workflow



```lua
-- Register workflow-specific commands
interactive.register_command("build", function(args)
  print("Building project...")
  local success = os.execute("luarocks make")
  return success == 0
end, "Build the project")
interactive.register_command("docs", function(args)
  print("Generating documentation...")
  local success = os.execute("ldoc .")
  return success == 0
end, "Generate documentation")
interactive.register_command("publish", function(args)
  local version = args[1]
  if not version then
    print("Usage: publish <version>")
    return false
  end

  print("Publishing version " .. version)
  local success = os.execute("luarocks upload my_project-" .. version .. ".rockspec")
  return success == 0
end, "Publish to LuaRocks")
```



### Watch Mode with Filters



```lua
-- Set up watching with filters
interactive.configure({
  watch_mode = true,
  watch_dirs = {"./src", "./tests"},

  -- When a file changes, only run related tests
  watch_filters = {
    ["src/(.*)%.lua"] = function(match)
      -- Run the corresponding test file
      return "tests/" .. match .. "_test.lua"
    end
  }
})
```



## Troubleshooting


### Common Issues



1. **Colors not displaying**:
   - Some terminals don't support ANSI colors
   - Set `colorized_output = false` for these environments
   - Use the `colors off` command in interactive mode
2. **Watch mode not detecting changes**:
   - Verify the `watch_dirs` include the directories where changes occur
   - Check if `exclude_patterns` are accidentally excluding your files
   - Try decreasing the `watch_interval` for more frequent checks
3. **Command history not persisting**:
   - Verify the history file is writable
   - Ensure `max_history` is set to an appropriate value
   - Check if the history file path is correct
4. **Commands not working**:
   - Use `help <command>` to check command usage
   - Verify that custom commands are registered correctly
   - Check if required dependencies for commands are available


## Example Configuration Files


### Basic Configuration



```lua
-- .firmo-config.lua
return {
  interactive = {
    test_dir = "./tests",
    test_pattern = "*_test.lua",
    watch_mode = false,
    watch_dirs = {"."},
    watch_interval = 1.0,
    exclude_patterns = {"node_modules", ".git"},
    max_history = 100,
    colorized_output = true,
    prompt_symbol = ">"
  }
}
```



### Developer-Friendly Configuration



```lua
-- .firmo-config.developer.lua
return {
  interactive = {
    test_dir = "./tests",
    test_pattern = "*_test.lua",
    watch_mode = true,             -- Enable watch mode by default
    watch_dirs = {"./src", "./tests"}, -- Watch both source and tests
    watch_interval = 0.3,          -- Quick updates
    exclude_patterns = {
      "node_modules", ".git", "%.swp$", "~$", "coverage%-reports"
    },
    max_history = 200,             -- Larger history
    colorized_output = true,
    prompt_symbol = "➜",          -- Custom prompt
    debug = true,                  -- More debugging info
    verbose = true                 -- Verbose output
  }
}
```



### CI Configuration



```lua
-- .firmo-config.ci.lua
return {
  interactive = {
    -- Interactive mode is rarely used in CI, but these settings
    -- are still useful for scripts that might use the module
    test_dir = "./tests",
    test_pattern = "*_test.lua",
    watch_mode = false,            -- No watch mode in CI
    colorized_output = false,      -- No colors in CI logs
    prompt_symbol = ">",
    debug = false,
    verbose = true                 -- Verbose for CI logs
  }
}
```


These configuration options give you complete control over the interactive testing mode, allowing you to create a productive and convenient environment for test-driven development.
