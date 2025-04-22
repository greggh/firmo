# Parser API Reference


## Overview


The Parser module provides a powerful Lua source code parser for analyzing and manipulating Lua 5.3/5.4 code. It generates an Abstract Syntax Tree (AST) representation of the code and provides utilities for static analysis, code structure identification, and coverage information extraction. The module is primarily designed to support the coverage and quality features of the Firmo framework.

## Module: `lib.tools.parser`



```lua
local parser = require("lib.tools.parser")
```



## Core Functions


### `parser.parse(source, name)`


Parses Lua source code into an Abstract Syntax Tree (AST).
**Parameters:**


- `source` (string): The Lua source code to parse
- `name` (string, optional): Name to use in error messages (defaults to "input")

**Returns:**


- `ast` (table|nil): The AST representing the Lua code, or nil if there was an error
- `error_info` (table|nil): Error information if parsing failed

**Example:**


```lua
local source = [[
local function add(a, b)
  return a + b
end
]]
local ast, err = parser.parse(source, "math.lua")
if not ast then
  print("Parse error:", err)
else
  -- AST successfully created
end
```



### `parser.parse_file(file_path)`


Parses a Lua file into an Abstract Syntax Tree (AST).
**Parameters:**


- `file_path` (string): Path to the Lua file to parse

**Returns:**


- `ast` (table|nil): The AST representing the Lua code, or nil if there was an error
- `error_info` (table|nil): Error information if parsing failed

**Example:**


```lua
local ast, err = parser.parse_file("/path/to/module.lua")
if not ast then
  print("Parse error:", err)
end
```



### `parser.pretty_print(ast)`


Converts an AST to a human-readable string representation for debugging.
**Parameters:**


- `ast` (table): The AST to print

**Returns:**


- `representation` (string): String representation of the AST

**Example:**


```lua
local ast = parser.parse(source)
print(parser.pretty_print(ast))
```



### `parser.validate(ast)`


Validates that an AST is properly structured.
**Parameters:**


- `ast` (table): The abstract syntax tree to validate

**Returns:**


- `is_valid` (boolean): Whether the AST is valid
- `error_info` (table|nil): Error information if validation failed

**Example:**


```lua
local is_valid, err = parser.validate(ast)
if not is_valid then
  print("AST validation failed:", err)
end
```



### `parser.get_executable_lines(ast, source)`


Extracts a list of executable lines from a Lua AST.
**Parameters:**


- `ast` (table): The abstract syntax tree
- `source` (string): The original source code

**Returns:**


- `executable_lines` (table): Table mapping line numbers to executability status

**Example:**


```lua
local executable_lines = parser.get_executable_lines(ast, source)
for line_number, _ in pairs(executable_lines) do
  print("Line " .. line_number .. " is executable")
end
```



### `parser.get_functions(ast, source)`


Extracts a list of functions and their positions from a Lua AST.
**Parameters:**


- `ast` (table): The abstract syntax tree
- `source` (string): The original source code

**Returns:**


- `functions` (table): List of functions with their line numbers, names, and parameters

**Example:**


```lua
local functions = parser.get_functions(ast, source)
for _, func in ipairs(functions) do
  print(string.format("Function %s (lines %d-%d)", 
    func.name, func.line_start, func.line_end))

  print("Parameters: " .. table.concat(func.params, ", "))
  if func.is_vararg then
    print("Has varargs (...)")
  end
end
```



### `parser.create_code_map(source, name)`


Creates a detailed map of a Lua source code file including AST, executable lines, and functions.
**Parameters:**


- `source` (string): The Lua source code
- `name` (string, optional): Name for the source (for error messages)

**Returns:**


- `code_map` (table|nil): The code map containing AST and analysis, or nil on error
  - `source` (string): Original source code
  - `ast` (table): Parsed abstract syntax tree
  - `lines` (table): Source code split into lines
  - `source_lines` (number): Number of lines in the source
  - `executable_lines` (table): Map of executable line numbers
  - `functions` (table): Array of function information tables
  - `valid` (boolean): Whether the code map is valid
- `error_info` (table|nil): Error information if mapping failed

**Example:**


```lua
local code_map = parser.create_code_map(source, "module.lua")
if code_map.valid then
  print("Source has " .. code_map.source_lines .. " lines")
  print("Found " .. #code_map.functions .. " functions")

  local executable_count = 0
  for _ in pairs(code_map.executable_lines) do
    executable_count = executable_count + 1
  end
  print("Found " .. executable_count .. " executable lines")
end
```



### `parser.create_code_map_from_file(file_path)`


Creates a detailed map of a Lua file including AST, executable lines, and functions.
**Parameters:**


- `file_path` (string): Path to the Lua file

**Returns:**


- `code_map` (table|nil): The code map containing AST and analysis, or nil on error
- `error_info` (table|nil): Error information if mapping failed

**Example:**


```lua
local code_map = parser.create_code_map_from_file("/path/to/module.lua")
if code_map.valid then
  -- Process code map
end
```



## AST Structure


The AST generated by the parser follows a structured format with node types that represent different Lua syntax elements:

### Common Node Structure


Each node in the AST has at least:


- `tag` (string): The type of the node (e.g., "Block", "If", "Function", etc.)
- `pos` (number): The position of the node in the source code
- `end_pos` (number): The end position of the node in the source code


### Main Node Types



- **Block**: A sequence of statements

  ```lua
  { tag = "Block", pos = 1, end_pos = 42, ... }
  ```


- **Function**: A function definition

  ```lua
  { tag = "Function", pos = 1, end_pos = 42, 
    [1] = { ... }, -- parameters
    [2] = { ... }  -- function body (Block)
  }
  ```


- **Id**: An identifier (variable name)

  ```lua
  { tag = "Id", pos = 10, end_pos = 15, [1] = "name" }
  ```


- **If**: An if statement with conditions and bodies

  ```lua
  { tag = "If", pos = 1, end_pos = 42,
    [1] = { ... }, -- condition expression
    [2] = { ... }, -- then block
    [3] = { ... }, -- condition for elseif (if present)
    [4] = { ... }  -- block for elseif (if present)
    -- Additional conditions and blocks for more elseifs
    -- Last element may be the else block
  }
  ```


- **Op**: An operation (arithmetic, logical, etc.)

  ```lua
  { tag = "Op", pos = 10, end_pos = 15, 
    [1] = "add", -- operation type
    [2] = { ... }, -- left operand
    [3] = { ... }  -- right operand (if binary)
  }
  ```

### Example AST


For the Lua code:


```lua
local function add(a, b)
  return a + b
end
```


The AST structure would be similar to:


```lua
{
  tag = "Block",
  pos = 1,
  end_pos = 33,
  {
    tag = "Localrec",
    pos = 1,
    end_pos = 33,
    {
      {
        tag = "Id",
        pos = 14,
        end_pos = 17,
        [1] = "add"
      }
    },
    {
      {
        tag = "Function",
        pos = 14,
        end_pos = 33,
        {
          {
            tag = "Id",
            pos = 18,
            end_pos = 19,
            [1] = "a"
          },
          {
            tag = "Id",
            pos = 21,
            end_pos = 22,
            [1] = "b"
          }
        },
        {
          tag = "Block",
          pos = 24,
          end_pos = 33,
          {
            tag = "Return",
            pos = 26,
            end_pos = 37,
            {
              tag = "Op",
              pos = 33,
              end_pos = 37,
              [1] = "add",
              [2] = {
                tag = "Id",
                pos = 33,
                end_pos = 34,
                [1] = "a"
              },
              [3] = {
                tag = "Id",
                pos = 37,
                end_pos = 38,
                [1] = "b"
              }
            }
          }
        }
      }
    }
  }
}
```



## Implementation Details


### Parsing Process


The parser module uses LPegLabel (an extension of LPeg) to implement a grammar-based parser for Lua. The parsing process involves:


1. Converting the Lua source code into a stream of tokens
2. Applying grammar rules to build an AST
3. Validating the AST structure
4. Adding additional metadata such as positions


### Error Handling


The parser provides detailed error messages with line and column information. Most functions return nil and an error message when they encounter problems such as:


- Syntax errors in the source code
- Invalid AST structures
- Missing files when parsing from file
- Timeouts for very large or complex files


### Performance Considerations


For large files, the parser implements several safeguards:


- A 1MB file size limit to prevent memory issues
- A 10-second timeout for parsing operations
- Coroutine-based execution to allow cancellation of long-running parses


## Version Information


The parser module follows semantic versioning and includes a `_VERSION` field with the current version.

## Credits


The parser module is based on the lua-parser project by Andre Murbach Maidl:


- https://github.com/andremm/lua-parser

The implementation uses LPegLabel for parsing, a modified version of LPeg:


- https://github.com/sqmedeiros/lpeglabel
