# Test Discovery API Reference


The Test Discovery module provides functionality for finding test files in a project based on configurable patterns, extensions, and filtering rules. This module is used internally by the test runner but can also be used directly for custom test discovery scenarios.

## Module Overview



```lua
local discover = require("lib.tools.discover")
```


The discovery module offers a flexible configuration system with sensible defaults for test file discovery. It supports pattern-based inclusion and exclusion, directory recursion control, and extension filtering.

## Core Functions


### discover(dir, pattern)


Discovers test files in a directory based on configured patterns.
**Parameters:**


- `dir` (string, optional): Directory to search in (default: "tests")
- `pattern` (string, optional): Additional Lua pattern to further filter matched files by path.

**Returns:**


- `discovery_result` (table|nil): Discovery result table or `nil` on error. Structure:
  - `files` (string[]): Array of absolute file paths matching all criteria (include/exclude/extension/pattern).
  - `matched` (number): Number of files in the `files` array (matching all criteria).
  - `total` (number): Total number of files found matching *only* the configured include/exclude/extension rules (before the optional `pattern` argument was applied).
- `error` (table|nil): An error object (from `error_handler`) if directory validation or file listing failed, otherwise `nil`.

**Example:**


```lua
local discover = require("lib.tools.discover")
local result, err = discover.discover("tests/unit", "user_")
if result then
  for _, file in ipairs(result.files) do
    print("Found test file: " .. file)
  end
  print(string.format("Found %d matching test files (out of %d initially considered)", result.matched, result.total))
else
  -- Use error_handler formatting if available
  local error_handler = pcall(require, "lib.tools.error_handler") and require("lib.tools.error_handler")
  print("Error discovering tests: " .. (error_handler and error_handler.format_error(err) or tostring(err)))
end
```
**Throws:** Can throw errors if filesystem operations fail critically (though most are returned).


### is_test_file(path)


Checks if a file is a test file based on configured name patterns and extensions.
**Parameters:**


- `path` (string): File path to check against include/exclude patterns and extensions

**Returns:**


- `boolean`: Whether the file is considered a valid test file based on current configuration

**Example:**


```lua
local discover = require("lib.tools.discover")
local is_test = discover.is_test_file("tests/user_test.lua") -- true
local not_test = discover.is_test_file("src/utils.lua") -- false
```



## Configuration Functions


### configure(options)


Configures discovery options for customizing test file discovery.
**Parameters:**


- `options` (table): Configuration options
  - `ignore` (string[], optional): Directories to ignore during discovery
  - `include` (string[], optional): Patterns to include as test files
  - `exclude` (string[], optional): Patterns to exclude from test files
  - `recursive` (boolean, optional): Whether to search subdirectories recursively
  - `extensions` (string[], optional): Valid file extensions for test files

**Returns:**


- The `TestDiscovery` module instance for method chaining.

**Throws:** Can throw errors if options validation fails (currently minimal).

**Example:**


```lua
local discover = require("lib.tools.discover")
discover.configure({
  ignore = {"node_modules", ".git", "vendor", "third_party"},
  include = {"*_test.lua", "test_*.lua", "*_spec.lua"},
  exclude = {"*_fixture.lua", "*_helper.lua"},
  recursive = true,
  extensions = {".lua"}
})
```



### add_include_pattern(pattern)


Adds a pattern to include in test file discovery.
**Parameters:**


- `pattern` (string): Pattern to include (e.g. "*_test.lua", "test_*.lua")

**Returns:**


- The `TestDiscovery` module instance for method chaining.

**Example:**


```lua
local discover = require("lib.tools.discover")
discover.add_include_pattern("*_integration_test.lua")
       .add_include_pattern("integration_*.lua")
```



### add_exclude_pattern(pattern)


Adds a pattern to exclude from test file discovery.
**Parameters:**


- `pattern` (string): Pattern to exclude (e.g. "temp_*.lua", "*_fixture.lua")

**Returns:**


- The `TestDiscovery` module instance for method chaining.

**Example:**


```lua
local discover = require("lib.tools.discover")
discover.add_exclude_pattern("*_wip.lua")
       .add_exclude_pattern("*_ignore.lua")
```



## Default Configuration


The discovery module comes pre-configured with sensible defaults:


```lua
{
  ignore = {"node_modules", ".git", "vendor"},
  include = {"*_test.lua", "*_spec.lua", "test_*.lua", "spec_*.lua"},
  exclude = {},
  recursive = true,
  extensions = {".lua"}
}
```



## Module Properties


### _VERSION


Module version identifier.
**Type:** `string`
**Example:**


```lua
local discover = require("lib.tools.discover")
print("Test Discovery module version: " .. discover._VERSION)
```



## Error Handling


The discovery module uses structured error objects for error reporting. When operations fail, functions return `nil` and an error object with the following structure:


```lua
{
  message = "Error message",
  category = "IO_ERROR", -- Error category
  context = {
    directory = "tests",
    operation = "discover",
    -- Additional context information
  }
}
```


All errors are also logged through the logging system for diagnostic purposes.
