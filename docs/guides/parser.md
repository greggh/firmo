# Parser Usage Guide

## Introduction

The parser module in Firmo provides tools for analyzing Lua source code, generating Abstract Syntax Trees (ASTs), and extracting information about code structure. It serves as the foundation for several key features in Firmo, including code coverage analysis, quality validation, and static analysis.
This guide will walk you through common use cases for the parser module and provide practical examples to help you understand how to effectively use it in your projects.

## Getting Started

### Basic Parsing

The most basic operation is parsing a Lua source string into an AST:

```lua
local parser = require("lib.tools.parser")
-- Parse a simple Lua code snippet
local source = [[
local function greet(name)
  print("Hello, " .. name)
  return true
end
greet("world")
]]
local ast, err = parser.parse(source, "greeting.lua")
if not ast then
  print("Parse error:", err)
  return
end
-- The AST is now available for analysis
print("Successfully parsed the code!")
```

### Parsing From Files

For Lua files on disk, you can use the `parse_file` function:

```lua
local ast, err = parser.parse_file("/path/to/module.lua")
if not ast then
  print("Failed to parse file:", err)
  return
end
```

### Inspecting the AST (`to_string`)

The AST can be difficult to understand in its raw form. Use `to_string` to get a readable representation (via the pretty-printer):

```lua
-- Print the AST in a human-readable format
local ast_string = parser.to_string(ast)
print(ast_string)
```

## Working with Code Analysis

### Finding Executable Lines

One common use case is identifying which lines of code are executable (as opposed to comments, blank lines, or syntax elements):

```lua
-- Get a map of executable lines
local executable_lines = parser.get_executable_lines(ast, source)
print("Executable lines:")
for line_number in pairs(executable_lines) do
  print("Line", line_number)
end
```

### Identifying Functions

To find function definitions in the code:

```lua
-- Get information about functions in the code
local functions = parser.get_functions(ast, source)
for _, func in ipairs(functions) do
  print(string.format("Function: %s (lines %d-%d)", 
    func.name or "anonymous", 
    func.line_start, 
    func.line_end))

  print("Parameters: " .. table.concat(func.params, ", "))

  if func.is_vararg then
    print("Function accepts variable arguments (...)")
  end

  if func.is_method then
    print("This is a method (uses : syntax)")
  end

  print("---")
end
```

### Creating a Code Map

For comprehensive code analysis, create a code map that contains all relevant information:

```lua
-- Create a complete code map
local code_map = parser.create_code_map(source, "module.lua")
-- Check if code_map creation was successful (it might be an error table)
if code_map and code_map.valid then
  print("Source analysis:")
  print("- Total lines:", code_map.source_lines)

  local executable_count = 0
  for _ in pairs(code_map.executable_lines) do
    executable_count = executable_count + 1
  end
  print("- Executable lines:", executable_count)

  print("- Function count:", #code_map.functions)

  -- You can now work with all aspects of the code
  -- code_map.ast - The full AST
  -- code_map.lines - Array of individual source lines
  -- code_map.executable_lines - Map of executable line numbers
  -- code_map.functions - Information about all functions
end
```

## Advanced Usage

### Validating AST Structure

If you're manipulating ASTs, you can validate their structure:

```lua
-- Check if an AST is valid
local is_valid, err = parser.validate(ast)
if not is_valid then
  print("Invalid AST:", err)
end
```

### Error Handling Patterns

When using the parser in larger applications, follow these error handling patterns:

```lua
-- Comprehensive error handling
local function parse_with_protection(source, filename)
  -- Check input
  if type(source) ~= "string" then
    return nil, "Source must be a string"
  end

  -- Check for empty source
  if #source == 0 then
    return nil, "Source is empty"
  end

  -- Use pcall for extra protection against crashes
  local success, result, error_info = pcall(function()
    return parser.parse(source, filename)
  end)

  if not success then
    return nil, "Parser crashed: " .. tostring(result)
  end

  if not result then
    return nil, "Parse error: " .. tostring(error_info)
  end

  return result
**Returns:**

- `code_map` (table|{error: string, valid: boolean}): The code map containing AST and analysis, or an error table `{error, valid=false}` if mapping failed. The code map includes:
  - `source` (string): Original source code.
  - `ast` (table): Parsed abstract syntax tree.
  - `lines` (string[]): Source code split into lines.
  - `source_lines` (number): Number of lines in the source.
  - `executable_lines` (table<number, boolean>): Map of executable line numbers to `true`.
  - `functions` (table[]): Array of function information tables.
  - `valid` (boolean): `true` if parsing and analysis were successful.
local code_map = parser.create_code_map_from_file("/path/to/module.lua")
if code_map and code_map.valid then
  -- Process code map
else
  print("Error creating code map:", code_map and code_map.error or "Unknown error")
end
  -- Create a code map with full information
  local code_map = parser.create_code_map_from_file(file_path)

  if not code_map or not code_map.valid then
    print("Could not analyze file for coverage:", file_path)
    return false
  end

  -- Register executable lines with coverage module
  for line_number in pairs(code_map.executable_lines) do
    coverage.register_line(file_path, line_number)
  end

  -- Register functions for more detailed reporting
  for _, func in ipairs(code_map.functions) do
    coverage.register_function(file_path, func.line_start, func.line_end, func.name)
  end

  return true
end
```

**Returns:**

- `code_map` (table|{error: string, valid: boolean}): The code map containing AST and analysis, or an error table `{error, valid=false}` if reading or mapping failed. See `create_code_map` for structure details.

```lua
-- Traverse all nodes in an AST
local function traverse_ast(node, callback)
  if type(node) ~= "table" then
    return
  end

  -- Call the callback with this node
  if node.tag then
    callback(node)
  end

  -- Recursively process all child nodes
  for i, child in ipairs(node) do
    if type(child) == "table" then
      traverse_ast(child, callback)
    end
  end
end
-- Example: Count node types in an AST
local function count_node_types(ast)
  local counts = {}

  traverse_ast(ast, function(node)
    counts[node.tag] = (counts[node.tag] or 0) + 1
  end)

  return counts
end
-- Usage:
local node_counts = count_node_types(ast)
for node_type, count in pairs(node_counts) do
  print(node_type .. ":", count)
end
```

## Best Practices

### Error Handling

Always check for errors when parsing:

```lua
local ast, err = parser.parse(source)
if not ast then
  -- Handle error appropriately
  logger.error("Parse error", { error = err })
  return nil, err
end
```

### Performance Considerations

For large files or when parsing frequently:

1. **Limit file size**: The parser has a built-in 1MB limit, but you might want to set a lower threshold for your application.
2. **Use timeouts**: The parser implements a 10-second timeout. For critical applications, you might want additional timeout handling.
3. **Cache results**: If you're parsing the same files repeatedly, consider caching the results:

```lua
local ast_cache = {}
local function get_ast(file_path)
  -- Check modification time
  local mod_time = fs.get_modification_time(file_path)

  if ast_cache[file_path] and ast_cache[file_path].mod_time == mod_time then
    return ast_cache[file_path].ast
  end

  -- Parse and cache
  local ast, err = parser.parse_file(file_path)
  if ast then
    ast_cache[file_path] = {
      ast = ast,
      mod_time = mod_time
    }
  end

  return ast, err
end
```

### Handling Syntax Errors

When working with user-provided code, be prepared to handle syntax errors gracefully:

```lua
-- Function to check if code has valid syntax
local function has_valid_syntax(code)
  local ast, err = parser.parse(code)
  if not ast then
    return false, err
  end
  return true
end
-- Example usage in an editor
local user_code = get_editor_content()
local is_valid, error_message = has_valid_syntax(user_code)
if not is_valid then
  -- Extract line and column from error message
  local line, col, message = error_message:match(".-:(%d+):(%d+): syntax error, (.+)")

  highlight_error_in_editor(tonumber(line), tonumber(col), message)
else
  clear_error_highlights()
end
```

## Common Pitfalls

### Using Too Much Memory

When parsing large files, be aware of memory usage:

```lua
-- Check file size before parsing
local function safe_parse_file(file_path, size_limit)
  size_limit = size_limit or 500000 -- 500KB default limit

  local file_size = fs.get_file_size(file_path)
  if file_size > size_limit then
    return nil, "File too large: " .. file_size .. " bytes (limit: " .. size_limit .. " bytes)"
  end

  return parser.parse_file(file_path)
end
```

### Not Checking Error Results

Always check if parsing succeeded:

```lua
-- BAD:
local ast = parser.parse(source)
process_ast(ast) -- Might crash if parsing failed
-- GOOD:
local ast, err = parser.parse(source)
if not ast then
  handle_error(err)
  return
end
process_ast(ast)
```

### Modifying AST Incorrectly

If you modify the AST, make sure to maintain its structure:

```lua
-- Function to safely modify an AST node
local function modify_node(node, modification_fn)
  if not node or type(node) ~= "table" or not node.tag then
    return false, "Not a valid AST node"
  end

  -- Make a copy of the node for safety
  local modified = table.copy(node)

  -- Apply modifications
  local success, err = pcall(modification_fn, modified)
  if not success then
    return false, "Modification error: " .. err
  end

  -- Validate the result
  local is_valid = parser.validate(modified)
  if not is_valid then
    return false, "Resulting AST is invalid"
  end

  -- Copy changes back to the original node
  for k, v in pairs(modified) do
    node[k] = v
  end

  return true
end
```

## Conclusion

The parser module is a powerful tool for analyzing Lua code and provides the foundation for many advanced features in Firmo. By understanding how to effectively use the parser, you can implement sophisticated code analysis, build code quality tools, and enhance your development workflow.
Remember to always handle errors appropriately and be mindful of performance when working with large codebases. The parser is designed to be robust and efficient, but proper error handling and caching strategies will ensure the best experience in your applications.
