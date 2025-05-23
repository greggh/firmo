# Codefix API

The codefix module in firmo provides comprehensive code quality checking and fixing capabilities. It integrates with external tools like StyLua and Luacheck while also providing custom fixers for issues that neither tool handles well.

## Overview

The codefix module can:

1. Format Lua code using StyLua
2. Lint Lua code using Luacheck
3. Apply custom fixes for common issues
4. Provide a unified API for all code quality operations
5. Be used through a simple CLI interface

## Configuration Options

The codefix module can be configured via the `central_config` system under the `codefix` key, or by calling `codefix.init(options)`. The available options (shown below with defaults) can also be accessed via `codefix.config` after initialization:

```lua
local codefix = require("lib.tools.codefix")
codefix.init({ -- Example overrides
  use_stylua = false,
  custom_fixers = {
    unused_variables = false
  }
})
local current_config = codefix.config
-- current_config now reflects:
-- {
--   enabled = true,            -- Enable code fixing functionality (set internally by init/CLI)
--   verbose = true,            -- Enable verbose output (set internally by init/CLI)
--   debug = false,             -- Enable debug output (more detailed logs)
--   -- StyLua options
--   use_stylua = false,        -- Use StyLua for formatting (overridden)
--   stylua_path = "stylua",    -- Path to StyLua executable
--   stylua_config = nil,       -- Path to StyLua config file (optional)
--   -- Luacheck options
--   use_luacheck = true,       -- Use Luacheck for linting
--   luacheck_path = "luacheck",-- Path to Luacheck executable
--   luacheck_config = nil,     -- Path to Luacheck config file (optional)
--   -- Custom fixers
--   custom_fixers = {
--     trailing_whitespace = true, -- Fix trailing whitespace in multiline strings
--     unused_variables = false,   -- Fix unused variables by prefixing with underscore (overridden)
--     string_concat = true,       -- Optimize string concatenation
--     type_annotations = false,   -- Add type annotations (disabled by default)
--     lua_version_compat = false, -- Fix Lua version compatibility issues (disabled by default)
--   },
--   -- Input/output
--   include = {"%.lua$"},            -- File patterns to include
--   exclude = {"_test%.lua$", "_spec%.lua$", "test/", "tests/", "spec/"}, -- File patterns to exclude
--   backup = true,                   -- Create backup files when fixing
--   backup_ext = ".bak",             -- Extension for backup files
-- }
```
  enabled = true,            -- Enable code fixing functionality
  verbose = true,            -- Enable verbose output
  debug = false,             -- Enable debug output (more detailed logs)
  -- StyLua options
  use_stylua = true,         -- Use StyLua for formatting
  stylua_path = "stylua",    -- Path to StyLua executable
  stylua_config = nil,       -- Path to StyLua config file (optional)
  -- Luacheck options
  use_luacheck = true,       -- Use Luacheck for linting
  luacheck_path = "luacheck", -- Path to Luacheck executable
  luacheck_config = nil,     -- Path to Luacheck config file (optional)
  -- Custom fixers
  custom_fixers = {
    trailing_whitespace = true,    -- Fix trailing whitespace in multiline strings
    unused_variables = true,       -- Fix unused variables by prefixing with underscore
    string_concat = true,          -- Optimize string concatenation
    type_annotations = false,      -- Add type annotations (disabled by default)
    lua_version_compat = false,    -- Fix Lua version compatibility issues (disabled by default)
  },
  -- Input/output
  include = {"%.lua$"},            -- File patterns to include
  exclude = {"_test%.lua$", "_spec%.lua$", "test/", "tests/", "spec/"}, -- File patterns to exclude
  backup = true,                   -- Create backup files when fixing
  backup_ext = ".bak",             -- Extension for backup files
}
```

## Basic Usage

### In Lua Scripts

```lua
local codefix = require("lib.tools.codefix")
local firmo -- Assume firmo instance exists if needed for CLI registration

-- Configure (optional, often done via central_config)
codefix.init({
  enabled = true,
  verbose = true
})

-- Register with firmo (optional, enables firmo.fix_file, CLI commands)
-- codefix.register_with_firmo(firmo)

-- Fix a specific file
local success_file = codefix.fix_file("path/to/file.lua")

-- Fix multiple files
local success_files, results_table = codefix.fix_files({
  "path/to/file1.lua",
  "path/to/file2.lua"
})

-- Find and fix Lua files in a directory
local success_dir, results_table = codefix.fix_lua_files("path/to/directory")
```

*Note: Calling `codefix.register_with_firmo(firmo)` makes these functions available directly on the `firmo` object (e.g., `firmo.fix_file(...)`).*

### From Command Line

```bash

# Fix a specific file

lua firmo.lua --fix path/to/file.lua

# Fix all Lua files in a directory

lua firmo.lua --fix path/to/directory

# Check a file without fixing

lua firmo.lua --check path/to/file.lua
```

*Note: The `--fix` and `--check` commands are registered with the main test runner (usually `test.lua`) via `codefix.register_with_firmo(firmo)`.*

## API Reference

### `codefix.init(options?)`

Initializes the codefix module, merging provided options with defaults and central configuration.
**Parameters:**

- `options` (table, optional): Configuration options table (see Configuration Options section).

**Returns:**

- `codefix_module`: The module instance (`M`) for method chaining.

### `codefix.fix_file(file_path)`

Applies the full code fixing process to a single file: Luacheck (optional) -> Custom Fixers -> StyLua (optional) -> Luacheck verification (optional).
**Parameters:**

- `file_path` (string): Path to the Lua file to fix

**Returns:**

- `success` (boolean): `true` if all enabled steps completed successfully (Luacheck may have warnings), `false` otherwise.

**Throws:**
- `table`: Can throw errors if validation, file I/O, or external tool execution fails critically.

**Example:**

```lua
local success = firmo.fix_file("src/module.lua")
if success then
  print("File fixed successfully")
else
  print("Failed to fix file")
end
```

### `codefix.fix_files(file_paths)`

Fixes multiple files by calling `codefix.fix_file` for each path in the input array. Logs overall progress and summary statistics.
**Parameters:**

- `file_paths` (table): Array of file paths to fix

**Returns:**

- `success` (boolean): `true` if *all* files were fixed successfully, `false` otherwise.
- `results` (table): An array of result tables, one for each file: `{ file: string, success: boolean, error?: string }`.

**Throws:**
- `table`: Can throw errors if `file_paths` validation fails.

**Example:**

```lua
local files = {
  "src/module1.lua",
  "src/module2.lua",
  "src/module3.lua"
}
local success = firmo.fix_files(files)
```

### `codefix.fix_lua_files(directory, options?)`

Finds Lua files in a directory (using include/exclude patterns) and fixes them using `codefix.fix_files`. Optionally generates a JSON report of the results.
**Parameters:**

- `directory` (string, optional): Directory to search (default: ".").
- `options` (table, optional): Options for filtering and fixing:
  - `include` (string[]): Array of include patterns (defaults to `codefix.config.include`).
  - `exclude` (string[]): Array of exclude patterns (defaults to `codefix.config.exclude`).
  - `limit` (number): Maximum number of files to process.
  - `sort_by_mtime` (boolean): Sort files by modification time (newest first) before processing.
  - `generate_report` (boolean): Generate a JSON report file.
  - `report_file` (string): Path for the JSON report file (default "codefix_report.json").

**Returns:**

- `success` (boolean): `true` if file discovery and fixing of all found files succeeded, `false` otherwise.
- `results` (table): The results table returned by `codefix.fix_files`.

**Throws:**
- `table`: Can throw errors if validation or file discovery/fixing fails critically.

**Example:**

```lua
local success = firmo.fix_lua_files("src")
```

### `codefix.init(options?)`

Initializes the codefix module, merging provided options with defaults.
**Parameters:**
- `options` (table, optional): Configuration options (see Configuration Options section).
**Returns:**
- `codefix_module`: The module instance (`M`) for method chaining.

### `codefix.check_stylua()`

Checks if the StyLua executable is available.
**Returns:**
- `boolean`: `true` if available, `false` otherwise.

### `codefix.find_stylua_config(dir?)`

Finds a StyLua configuration file (`stylua.toml` or `.stylua.toml`) by searching upwards.
**Parameters:**
- `dir` (string, optional): Directory to start searching from (default: ".").
**Returns:**
- `string|nil`: Absolute path to the config file, or `nil`.

### `codefix.run_stylua(file_path, config_file?)`

Runs StyLua on a file.
**Parameters:**
- `file_path` (string): Path to the file to format.
- `config_file` (string, optional): Path to a specific StyLua config file.
**Returns:**
- `boolean`: `true` if StyLua ran successfully (exit code 0).
- `string?`: Raw output from StyLua if it failed.
**Throws:**
- `table`: If `file_path` validation fails.

### `codefix.check_luacheck()`

Checks if the Luacheck executable is available.
**Returns:**
- `boolean`: `true` if available, `false` otherwise.

### `codefix.find_luacheck_config(dir?)`

Finds a Luacheck configuration file (`.luacheckrc` or `luacheck.rc`) by searching upwards.
**Parameters:**
- `dir` (string, optional): Directory to start searching from (default: ".").
**Returns:**
- `string|nil`: Absolute path to the config file, or `nil`.

### `codefix.parse_luacheck_output(output)`

Parses raw Luacheck output (from `--codes` format) into an array of issue tables.
**Parameters:**
- `output` (string): Raw Luacheck output.
**Returns:**
- `table[]`: Array of issue tables: `{ file, line, col, code, message }`.

### `codefix.run_luacheck(file_path, config_file?)`

Runs Luacheck on a file.
**Parameters:**
- `file_path` (string): Path to the file to check.
- `config_file` (string, optional): Path to a specific Luacheck config file.
**Returns:**
- `boolean`: `true` if Luacheck ran without errors (exit code 0 or 1).
- `table[]`: Array of issue tables parsed from output.
**Throws:**
- `table`: If `file_path` validation fails.

### `codefix.fix_trailing_whitespace(content)`

Removes trailing whitespace from multiline string literals.
**Parameters:**
- `content` (string): Source code content.
**Returns:**
- `string`: Content with fixes applied.

### `codefix.fix_unused_variables(file_path, issues?)`

Fixes unused variables by prefixing with `_`. Requires Luacheck issues.
**Parameters:**
- `file_path` (string): Path to the file to fix.
- `issues` (table[], optional): Issues array from `run_luacheck`.
**Returns:**
- `boolean`: `true` if the file was modified and saved.
**Throws:**
- `table`: If validation or file I/O fails critically.

### `codefix.fix_string_concat(content)`

Optimizes string concatenation operations.
**Parameters:**
- `content` (string): Source code content.
**Returns:**
- `string`: Content with fixes applied.

### `codefix.fix_type_annotations(content)`

Adds basic JSDoc type annotations (experimental, disabled by default).
**Parameters:**
- `content` (string): Source code content.
**Returns:**
- `string`: Content with potential annotations added.

### `codefix.fix_lua_version_compat(content, target_version?)`

Applies basic fixes for Lua 5.1 compatibility (disabled by default).
**Parameters:**
- `content` (string): Source code content.
- `target_version` (string, optional): Target version (default "5.1").
**Returns:**
- `string`: Content with potential compatibility fixes.

### `codefix.run_custom_fixers(file_path, issues?)`

Runs all enabled custom fixers on a file.
**Parameters:**
- `file_path` (string): Path to the file to fix.
- `issues` (table[], optional): Issues array from `run_luacheck`.
**Returns:**
- `boolean`: `true` if any fixer modified the content and saved the file.
**Throws:**
- `table`: If validation or file I/O fails critically.

### `codefix.register_custom_fixer(name, options)`

Registers a custom fixer function.
**Parameters:**
- `name` (string): A unique name for the fixer.
- `options` (table): Table containing `{name: string, fix: function, description?: string}`. The `fix` function takes `(content, file_path, issues?)` and returns modified content.
**Returns:**
- `boolean`: `true` if registration was successful.
**Throws:**
- `table`: If validation fails.

### `codefix.run_cli(args?)`

Command line interface entry point.
**Parameters:**
- `args` (table, optional): Array of arguments (defaults to global `arg`).
**Returns:**
- `boolean`: `true` if the CLI command succeeded.

### `codefix.register_with_firmo(firmo)`

Registers the codefix module and commands with a Firmo instance.
**Parameters:**
- `firmo` (table): The Firmo instance.
**Returns:**
- `codefix_module`: The codefix module instance (`M`).
**Throws:**
- `table`: If `firmo` validation fails critically.

## Custom Fixers

The codefix module includes several custom fixers for issues that StyLua and Luacheck don't handle well:

### 1. Trailing Whitespace in Multiline Strings

Fixes trailing whitespace in multiline strings, which StyLua doesn't modify.
**Before:**

```lua
local str = [[
  This string has trailing whitespace   
  on multiple lines   
]]
```

**After:**

```lua
local str = [[
  This string has trailing whitespace
  on multiple lines
]]
```

### 2. Unused Variables

Prefixes unused variables with underscore to indicate they're intentionally unused.
**Before:**

```lua
local function process(data, options, callback)
  -- Only uses data
  return data.value
end
```

**After:**

```lua
local function process(data, _options, _callback)
  -- Only uses data
  return data.value
end
```

### 3. String Concatenation

Optimizes string concatenation patterns by merging adjacent string literals.
**Before:**

```lua
local greeting = "Hello " .. "there " .. name .. "!"
```

**After:**

```lua
local greeting = "Hello there " .. name .. "!"
```

### 4. Type Annotations (Optional)

Adds basic JSDoc type annotations to function documentation (experimental, disabled by default). May produce incorrect annotations.
**Before:**
**Before:**

```lua
function calculate(x, y)
  return x * y
end
```

**After:**

```lua
--- Function documentation
---@param x any
---@param y any
---@return any
function calculate(x, y)
  return x * y
end
```

### 5. Lua Version Compatibility (Optional)

Fixes Lua version compatibility issues (targets Lua 5.1, disabled by default). Comments out `goto` and labels, replaces `table.pack` and `bit32.*` calls.
**Before:**
**Before:**

```lua
local packed = table.pack(...)  -- Lua 5.2+ feature
```

**After:**

```lua
local packed = {...}  -- table.pack replaced for Lua 5.1 compatibility
```

## Integration with hooks-util

The codefix module is designed to integrate seamlessly with the hooks-util framework:

1. It can be used in pre-commit hooks to ensure code quality
2. It shares configuration with hooks-util's existing StyLua and Luacheck integration
3. It provides additional fixing capabilities beyond what hooks-util currently offers

## Examples

See the [codefix_example.lua](../../examples/codefix_example.lua) file for a complete example of using the codefix module.

## Unimplemented Functions

The following functions are listed in the module's JSDoc class definition but are **not currently implemented** and should not be used:

- `fix_directory`
- `unregister_custom_fixer`
- `restore_backup`
- `get_custom_fixers`
- `validate_lua_syntax`
- `format_issues`
