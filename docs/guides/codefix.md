# Codefix Usage Guide

The Firmo codefix module provides tools for automating code quality improvements in Lua projects. This guide explains how to use the module effectively, covering common scenarios and best practices.

## Table of Contents

- [Introduction](#introduction)
- [Getting Started](#getting-started)
- [Configuration Options](#configuration-options)
- [Common Usage Patterns](#common-usage-patterns)
- [StyLua Integration](#stylua-integration)
- [Luacheck Integration](#luacheck-integration)
- [Custom Fixers](#custom-fixers)
- [Command Line Interface](#command-line-interface)
- [Integrating with CI/CD](#integrating-with-cicd)
- [Troubleshooting](#troubleshooting)

## Introduction

The codefix module offers a unified approach to code quality by combining:

1. **Formatting** using StyLua
2. **Linting** using Luacheck
3. **Custom fixers** for common issues
4. **Backup capabilities** to ensure safety
5. **Command line interface** for easy integration

These tools work together to automate code quality improvements while maintaining safety through proper error handling and backups.

## Getting Started

### Basic Setup

1. Ensure you have the Firmo framework properly installed
2. Make sure StyLua and/or Luacheck are installed if you plan to use them
3. Import the module in your script:

```lua
local firmo = require("firmo")
-- The codefix module is available through firmo
```

### Simple Usage

Fix a single file:

```lua
-- Enable codefix
firmo.codefix_options.enabled = true

-- Fix a file
local success = firmo.fix_file("path/to/file.lua")
if success then
  print("File fixed successfully")
else
  print("Failed to fix file")
end
```

Fix multiple files:

```lua
local files = {
  "src/module1.lua",
  "src/module2.lua",
  "src/utils.lua"
}

local success, results = firmo.fix_files(files)
if success then
  print("All files fixed successfully")
else
  -- Check which files failed
  for _, result in ipairs(results) do
    if not result.success then
      print("Failed to fix: " .. result.file)
    end
  end
end
```

Find and fix all Lua files in a directory:

```lua
local success, results = firmo.fix_lua_files("src")
print("Fixed " .. #results .. " files")
```

## Configuration Options

The codefix module is highly configurable. You can set options through the `firmo.codefix_options` table:

```lua
firmo.codefix_options = {
  -- General options
  enabled = true,            -- Enable code fixing functionality
  verbose = true,            -- Enable verbose output
  debug = false,             -- Enable debug output

  -- StyLua options
  use_stylua = true,         -- Use StyLua for formatting
  stylua_path = "stylua",    -- Path to StyLua executable
  stylua_config = nil,       -- Path to StyLua config file

  -- Luacheck options
  use_luacheck = true,       -- Use Luacheck for linting
  luacheck_path = "luacheck", -- Path to Luacheck executable
  luacheck_config = nil,      -- Path to Luacheck config file

  -- Custom fixers
  custom_fixers = {
    trailing_whitespace = true,    -- Fix trailing whitespace in strings
    unused_variables = true,       -- Fix unused variables by prefixing with underscore
    string_concat = true,          -- Optimize string concatenation
    type_annotations = false,      -- Add type annotations (disabled by default)
    lua_version_compat = false,    -- Fix Lua version compatibility issues (disabled by default)
  },

  -- Input/output
  include = { "%.lua$" },          -- File patterns to include
  exclude = {                      -- File patterns to exclude
    "_test%.lua$", 
    "_spec%.lua$", 
    "test/", 
    "tests/", 
    "spec/"
  },
  backup = true,                   -- Create backup files when fixing
  backup_ext = ".bak",             -- Extension for backup files
}
```

## Common Usage Patterns

### Quick Pre-Commit Check and Fix

Before committing code, you can run a quick check and fix:

```lua
-- Check and fix modified files only
local files = get_modified_files() -- Your function to get modified files
local success = firmo.fix_files(files)
if not success then
  print("Some files could not be fixed automatically")
  return false
end
return true
```

### Selective Fixing

Only run specific fixers on selective files:

```lua
-- Only run StyLua, not Luacheck or custom fixers
firmo.codefix_options.use_luacheck = false
firmo.codefix_options.custom_fixers.trailing_whitespace = false
firmo.codefix_options.custom_fixers.unused_variables = false

-- Only format files
local success = firmo.fix_lua_files("src")
```

### Diagnostic Mode

Run in diagnostic mode to see issues without fixing them:

```lua
-- Check files without modifying them
firmo.codefix_options.use_stylua = false
local codefix = require("lib.tools.codefix")
codefix.run_cli({"check", "src"})
```

### Batch Processing with Options

Process files in batches with custom options:

```lua
local options = {
  sort_by_mtime = true,         -- Fix newest files first
  limit = 10,                   -- Only process 10 files
  generate_report = true,       -- Generate a JSON report
  report_file = "report.json"   -- Custom report file name
}

firmo.fix_lua_files("src", options)
```

## StyLua Integration

[StyLua](https://github.com/JohnnyMorganz/StyLua) is a powerful Lua formatter. The codefix module can detect and use StyLua if it's installed.

### Setting Up StyLua

1. Install StyLua following the instructions from its repository
2. (Optional) Create a StyLua configuration file (`.stylua.toml` or `stylua.toml`)
3. Configure codefix to use StyLua:

```lua
firmo.codefix_options.use_stylua = true
firmo.codefix_options.stylua_path = "stylua" -- Or specific path
```

### Customizing StyLua Integration

You can specify a custom StyLua configuration file:

```lua
firmo.codefix_options.stylua_config = "path/to/stylua.toml"
```

Or let codefix find the configuration automatically:

```lua
local codefix = require("lib.tools.codefix")
local config_file = codefix.find_stylua_config("src")
if config_file then
  print("Using StyLua config: " .. config_file)
end
```

### Running StyLua Directly

You can also run StyLua on a specific file:

```lua
local codefix = require("lib.tools.codefix")
local success, err = codefix.run_stylua("path/to/file.lua")
if not success then
  print("StyLua error: " .. (err or ""))
end
```

## Luacheck Integration

[Luacheck](https://github.com/mpeterv/luacheck) is a static analyzer and linter for Lua. The codefix module can integrate with it to identify and fix issues.

### Setting Up Luacheck

1. Install Luacheck (`luarocks install luacheck` or follow the repository instructions)
2. (Optional) Create a Luacheck configuration file (`.luacheckrc`)
3. Configure codefix to use Luacheck:

```lua
firmo.codefix_options.use_luacheck = true
firmo.codefix_options.luacheck_path = "luacheck" -- Or specific path
```

### Customizing Luacheck Integration

You can specify a custom Luacheck configuration file:

```lua
firmo.codefix_options.luacheck_config = "path/to/.luacheckrc"
```

Or let codefix find the configuration automatically:

```lua
local codefix = require("lib.tools.codefix")
local config_file = codefix.find_luacheck_config("src")
if config_file then
  print("Using Luacheck config: " .. config_file)
end
```

### Retrieving and Processing Luacheck Issues

Get issues from Luacheck without fixing:

```lua
local codefix = require("lib.tools.codefix")
local success, issues = codefix.run_luacheck("path/to/file.lua")

-- Process issues
for _, issue in ipairs(issues) do
  print(string.format("%s:%d:%d: (%s) %s",
    issue.file, issue.line, issue.col, issue.code, issue.message))
end
```

### Fixing Luacheck Issues

Fix specific Luacheck issues like unused variables:

```lua
local codefix = require("lib.tools.codefix")
local _, issues = codefix.run_luacheck("path/to/file.lua")
local modified = codefix.fix_unused_variables("path/to/file.lua", issues)
```

## Custom Fixers

Custom fixers address common issues that aren't handled by StyLua or Luacheck.

### Available Custom Fixers

1. **Trailing Whitespace** (`trailing_whitespace`): Removes trailing whitespace in multiline strings
2. **Unused Variables** (`unused_variables`): Prefixes unused variables with underscore
3. **String Concatenation** (`string_concat`): Optimizes string concatenation patterns
4. **Type Annotations** (`type_annotations`): Adds type annotations to function documentation
5. **Lua Version Compatibility** (`lua_version_compat`): Fixes Lua version compatibility issues

### Enabling/Disabling Specific Fixers

```lua
-- Enable only specific fixers
firmo.codefix_options.custom_fixers = {
  trailing_whitespace = true,
  unused_variables = true,
  string_concat = false,
  type_annotations = false,
  lua_version_compat = false
}

-- Or modify individual fixers
firmo.codefix_options.custom_fixers.trailing_whitespace = true
firmo.codefix_options.custom_fixers.unused_variables = false
```

### Running Specific Fixers

```lua
local codefix = require("lib.tools.codefix")
local content = read_file("path/to/file.lua")

-- Apply specific fixer only
local fixed_content = codefix.fix_trailing_whitespace(content)
write_file("path/to/file.lua", fixed_content)
```

### Creating Custom Fixers

You can register your own custom fixers:

```lua
codefix.register_custom_fixer("remove_print", {
  name = "Remove print statements",
  fix = function(content)
    return content:gsub("print%b()", "-- print removed")
  end
})
```

## Command Line Interface

The codefix module provides a command-line interface for easy integration with scripts and build tools.

### Basic CLI Commands

```lua
local codefix = require("lib.tools.codefix")

-- Fix files in a directory
codefix.run_cli({"fix", "src"})

-- Check files without fixing
codefix.run_cli({"check", "src"})

-- Find Lua files matching a pattern
codefix.run_cli({"find", "src", "--include", "%.lua$", "--exclude", "_test%.lua$"})

-- Display help information
codefix.run_cli({"help"})
```

### CLI Options

The CLI supports various options:

```
Options:
  --verbose, -v       - Enable verbose output
  --debug, -d         - Enable debug output
  --no-backup, -nb    - Disable backup files
  --no-stylua, -ns    - Disable StyLua formatting
  --no-luacheck, -nl  - Disable Luacheck verification
  --sort-by-mtime, -s - Sort files by modification time (newest first)
  --generate-report, -r - Generate a JSON report file
  --report-file FILE  - Specify report file name
  --limit N, -l N     - Limit processing to N files
  --include PATTERN, -i PATTERN - Add file pattern to include
  --exclude PATTERN, -e PATTERN - Add file pattern to exclude
```

### Usage Examples

```lua
-- Fix 10 most recently modified files
codefix.run_cli({"fix", "src", "--sort-by-mtime", "--limit", "10"})

-- Check specific file types
codefix.run_cli({"check", "src", "--include", "model_.+%.lua$"})

-- Generate a report of fixes
codefix.run_cli({"fix", "src", "--generate-report", "--report-file", "fixes.json"})
```

## Integrating with CI/CD

The codefix module can be integrated into continuous integration pipelines to ensure code quality.

### GitHub Actions Example

```yaml
name: Lua Code Quality

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install Lua and dependencies
        run: |
          sudo apt-get install lua5.3 luarocks
          sudo luarocks install luacheck
          
      - name: Install StyLua
        run: |
          curl -L https://github.com/JohnnyMorganz/StyLua/releases/download/v0.14.2/stylua-linux.zip -o stylua.zip
          unzip stylua.zip
          chmod +x stylua
          sudo mv stylua /usr/local/bin/
          
      - name: Run Code Checks
        run: |
          lua -e 'require("firmo").codefix.run_cli({"check", "src"})'
```

### Pre-commit Hook Example

Create a pre-commit hook script:

```bash
#!/bin/sh
# .git/hooks/pre-commit

lua -e '
local firmo = require("firmo")
firmo.codefix_options.enabled = true
firmo.codefix_options.verbose = true

-- Get modified Lua files
local result, files = firmo.codefix.run_cli({"find", ".", "--include", "%.lua$"})
local modified_files = {}

for _, file in ipairs(files or {}) do
  local is_modified = os.execute("git diff --cached --name-only | grep -q " .. file)
  if is_modified then
    table.insert(modified_files, file)
  end
end

if #modified_files > 0 then
  print("Fixing " .. #modified_files .. " modified Lua files...")
  local success = firmo.fix_files(modified_files)
  if not success then
    print("Failed to fix some files. Please check the output above.")
    os.exit(1)
  end
  
  -- Add fixed files back to staging
  for _, file in ipairs(modified_files) do
    os.execute("git add " .. file)
  end
end
'
```

## Troubleshooting

### Common Issues and Solutions

1. **StyLua not found**

   ```
   StyLua not found at: stylua
   ```

   **Solution**: Install StyLua or specify the correct path:
   
   ```lua
   firmo.codefix_options.stylua_path = "/path/to/stylua"
   ```

2. **Luacheck not found**

   ```
   Luacheck not found at: luacheck
   ```

   **Solution**: Install Luacheck or specify the correct path:
   
   ```lua
   firmo.codefix_options.luacheck_path = "/path/to/luacheck"
   ```

3. **File not found**

   ```
   Failed to read file: No such file or directory
   ```

   **Solution**: Verify the file paths are correct and accessible:
   
   ```lua
   -- Use absolute paths if necessary
   local success = firmo.fix_file("/absolute/path/to/file.lua")
   ```

4. **Permission issues**

   ```
   Failed to write file: Permission denied
   ```

   **Solution**: Ensure the process has write permissions to the files and directories.

5. **Backup failures**

   ```
   Failed to create backup for file
   ```

   **Solution**: If backup creation fails, you can disable backups:
   
   ```lua
   firmo.codefix_options.backup = false
   ```

### Debugging

Enable debug mode for more detailed logs:

```lua
firmo.codefix_options.debug = true
firmo.codefix_options.verbose = true
```

Or use the CLI debug flag:

```lua
codefix.run_cli({"fix", "src", "--debug"})
```

### Reporting Issues

If you encounter persistent issues:

1. Enable debug mode to capture detailed logs
2. Verify StyLua and Luacheck are working properly standalone
3. Check for any custom fixers that might be causing issues
4. Try limiting the scope to fewer files or specific fixers
5. Report the issue with full logs and reproduction steps

---

For more examples, see the [codefix_example.lua](../../examples/codefix_example.lua) file in the examples directory. This demonstrates common usage patterns and how to integrate the codefix module into your workflow.