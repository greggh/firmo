# firmo Parser Module

This module provides a Lua parser that can analyze Lua 5.3/5.4 source code and generate detailed information about the code structure. It is primarily designed to support the coverage and quality modules in firmo.

## Features

- Parse Lua 5.3/5.4 source code into an Abstract Syntax Tree (AST)
- Pretty print AST for debugging and inspection
- Identify executable lines in source code
- Detect function definitions and their parameters
- Create comprehensive code maps for detailed analysis
- Support for error detection and reporting

## Usage

```lua
local parser = require("lib.tools.parser")

-- Parse a Lua source string
local source = [[
local function add(a, b)
  return a + b
end

print(add(2, 3))
]]

-- Parse the source into an AST
local ast, err = parser.parse(source, "example.lua")
if not ast then
  print("Error parsing source:", err)
  return
end

-- Pretty print the AST
print(parser.pretty_print(ast))

-- Get executable lines
local executable_lines = parser.get_executable_lines(ast, source)
for line, _ in pairs(executable_lines) do
  print("Executable line:", line)
end

-- Get function definitions
local functions = parser.get_functions(ast, source)
for _, func in ipairs(functions) do
  print(string.format("Function: %s (lines %d-%d)",
    func.name, func.line_start, func.line_end))
end

-- Create a code map
local code_map = parser.create_code_map(source, "example.lua")
if code_map.valid then
  print("Source lines:", code_map.source_lines)
  print("Functions count:", #code_map.functions)
end
```

## API Reference

### parser.parse(source, filename)

Parses a Lua source string into an AST.

- `source`: The Lua source code as a string
- `filename`: (optional) Name to use in error messages
- Returns: The AST or `nil, error_message` on error

### parser.parse_file(filepath)

Parses a Lua file into an AST.

- `filepath`: Path to the Lua file
- Returns: The AST or `nil, error_message` on error

### parser.pretty_print(ast)

Returns a string representation of the AST for debugging.

- `ast`: The AST to print
- Returns: String representation of the AST

### parser.get_executable_lines(ast, source)

Analyzes an AST to identify executable lines.

- `ast`: The AST to analyze
- `source`: (optional) Source code for better line mapping
- Returns: Table mapping line numbers to executable status (true if executable)

### parser.get_functions(ast, source)

Extracts function definitions from an AST.

- `ast`: The AST to analyze
- `source`: (optional) Source code for better line mapping
- Returns: Array of function information tables

### parser.create_code_map(source, name)

Creates a comprehensive code map with detailed information.

- `source`: The Lua source code
- `name`: (optional) Name to use in error messages
- Returns: Code map object

### parser.create_code_map_from_file(filepath)

Creates a code map from a Lua file.

- `filepath`: Path to the Lua file
- Returns: Code map object

## Credits

This module is based on the lua-parser project by Andre Murbach Maidl:
- https://github.com/andremm/lua-parser

The implementation uses LPegLabel for parsing, a modified version of LPeg:
- https://github.com/sqmedeiros/lpeglabel