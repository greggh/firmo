# lib/tools/parser Knowledge

## Purpose

The `lib/tools/parser` module provides the capability to parse Lua 5.3/5.4 source code into an Abstract Syntax Tree (AST) within the Firmo framework. It leverages the LPegLabel parsing library (vendored) for its grammar definition (`grammar.lua`). Beyond basic parsing, the module offers semantic validation of the generated AST (`validator.lua`), utilities for analyzing the code structure (identifying executable lines, function definitions), and functions to represent the AST as a human-readable string (`pp.lua`) or dump its raw structure for debugging. This functionality is crucial for features like code coverage analysis and potentially for static analysis in quality checks or code fixing tools. This module is based on the `lua-parser` project by Andre Murbach Maidl.

## Key Concepts

- **LPegLabel Grammar (`grammar.lua`):** The core parsing engine is defined in `lib/tools/parser/grammar.lua`. This file uses LPegLabel, an extension of the LPeg library, to define a formal grammar that recognizes Lua 5.3/5.4 syntax. The grammar attempts to capture the structure of the code, including statements, expressions, operators, identifiers, literals, comments, etc.

- **AST Structure:** The parser generates an Abstract Syntax Tree, represented as nested Lua tables. Each node (table) in the tree typically contains:
    - `tag` (string): Identifies the type of the node (e.g., `"Block"`, `"Set"` for assignment, `"Function"`, `"Id"` for identifier, `"Op"` for operation, `"String"`, `"Number"`).
    - `pos` (number): The 1-based character index in the original source string where the node begins.
    - `end_pos` (number): The 1-based character index where the node ends.
    - Indexed children (e.g., `node[1]`, `node[2]`): These hold sub-nodes (other tables) or primitive values (like variable names, operator symbols, literal values) depending on the node's `tag`.

- **Parsing Functions (`init.lua` - `M.parse`, `M.parse_file`):**
    - `M.parse(source, name?)`: Takes a Lua source code string and an optional `name` (for error messages). It invokes the LPegLabel grammar (`grammar.parse`).
        - **Error Handling:** Returns `ast_table, nil` on success, or `nil, error_message` (string) if a syntax error is detected.
        - **Limits:** Includes input validation (source must be a string), a size limit (currently ~1MB), and a timeout mechanism (currently ~10 seconds) implemented using coroutines to prevent runaway parsing on complex or malicious input.
        - **Dependency:** Requires the LPegLabel library to be successfully loaded (`require("lib.tools.vendor.lpeglabel")`).
    - `M.parse_file(file_path)`: A convenience function that reads a file using `lib.tools.filesystem.read_file`, then calls `M.parse` with the content and filename. Returns `ast_table, nil` or `nil, error_message` (if file reading or parsing fails).

- **AST Validation (`validator.lua` - `M.validate`):**
    - **Purpose:** This function performs *semantic* validation on an already successfully parsed AST. It checks for errors that are syntactically valid but semantically incorrect according to Lua rules.
    - **Checks:** Verifies correct usage of `break` (must be inside a loop), `goto` (target label must be visible in scope), and varargs `...` (must be inside a function declared as vararg).
    - **Usage:** `M.validate(ast, errorinfo)` requires the AST table and an `errorinfo` table (`{subject = source_string, filename = name}`) for accurate error reporting (line/column).
    - **Returns:** `ast, nil` if validation passes, or `nil, error_message` (string) if a semantic error is found.

- **Pretty Printing & Dumping (`pp.lua` - `M.to_string`, `M.print`, `M.dump`, `M.log_dump`):**
    - `M.to_string(ast)`: Converts an AST into a compact, human-readable string representation. This string shows the AST structure using tags (e.g., `` `Block` ``) and nested braces (`{...}`), but it's **not** designed to reconstruct the original Lua code perfectly.
    - `M.print(ast)`: Prints the output of `M.to_string` either using the logging module (if available) or `io.write`.
    - `M.dump(ast, indent?, use_logger?)` / `M.log_dump(ast)`: These functions provide a detailed, recursive dump of the raw Lua table structure of the AST, including all tags, positions, and child nodes, with indentation. This is primarily useful for debugging the parser or analysis functions. `log_dump` specifically uses the logger.

- **Code Analysis (`init.lua` - `M.get_executable_lines`, `M.get_functions`):**
    - `M.get_executable_lines(ast, source)`: Traverses the AST to identify lines that contain potentially executable code. It excludes structural nodes (`Block`, `Function`), control flow (`If`, `While`, `For...`), and `Label`. Returns a map `{ [line_number] = true }`. Requires the original source string for accurate line number calculation from character positions (`pos`, `end_pos`).
    - `M.get_functions(ast, source)`: Traverses the AST to find all function definitions (including assignments like `foo = function()`, `local function foo()`, `t.foo = function()`, `function foo()` etc.). Returns an array of tables, each containing info about a function: `{ name, params, is_vararg, line_start, line_end, pos, end_pos }`. Also requires the original source string.

- **Code Map (`init.lua` - `M.create_code_map`, `M.create_code_map_from_file`):**
    - **Purpose:** These are high-level convenience functions that combine parsing and analysis into a single step.
    - **Input:** Source string or file path.
    - **Output:** Returns a `code_map` table containing:
        - `source`: The original source code.
        - `ast`: The parsed Abstract Syntax Tree.
        - `lines`: An array containing each line of the source code.
        - `source_lines`: The total number of lines.
        - `executable_lines`: The map of executable line numbers.
        - `functions`: The array of function information tables.
        - `valid` (boolean): `true` if parsing was successful, `false` otherwise.
        - `error` (string, optional): The error message if `valid` is `false`.
    - **Recommendation:** This is often the most useful entry point for consumers like the coverage module that need comprehensive code information.

- **Error Handling:** Functions like `parse`, `parse_file`, and `validate` return `nil, error_message` (string) on failure. The `create_code_map` functions indicate failure via the `valid` and `error` fields in the returned table. Internal errors and progress are logged using `lib/tools/logging`. Note that errors returned are simple strings, not the structured objects from `lib/tools/error_handler`.

## Usage Examples / Patterns

### Pattern 1: Parsing a String

```lua
--[[
  Parse a Lua code string into an AST.
]]
local parser = require("lib.tools.parser")

local source_code = [[
local x = 10
if x > 5 then
  print("Hello")
end
]]

local ast, parse_err = parser.parse(source_code, "example.lua")

if not ast then
  print("Parsing failed: " .. parse_err)
else
  print("Parsing successful!")
  -- 'ast' now holds the Abstract Syntax Tree table
end
```

### Pattern 2: Parsing a File

```lua
--[[
  Parse a Lua file into an AST.
]]
local parser = require("lib.tools.parser")
local error_handler = require("lib.tools.error_handler") -- To wrap the call
local fs = require("lib.tools.filesystem") -- Assume setup for test file

local file_path = "my_module.lua"
local setup_ok, _ = error_handler.safe_io_operation(fs.write_file, file_path, "local a = 1")
if not setup_ok then return end -- Ensure file exists

local ast, parse_err = parser.parse_file(file_path)

if not ast then
  print("Parsing file failed: " .. parse_err)
else
  print("Parsing file successful!")
  -- Process AST
end

error_handler.safe_io_operation(fs.delete_file, file_path) -- Cleanup
```

### Pattern 3: Validating an AST

```lua
--[[
  Parse and then validate the AST for semantic errors.
]]
local parser = require("lib.tools.parser")

local source_with_bad_break = [[
local x = 1
break -- Invalid: break outside loop
]]

local ast, parse_err = parser.parse(source_with_bad_break, "bad_break.lua")
if ast then
  local errorinfo = { subject = source_with_bad_break, filename = "bad_break.lua" }
  local validated_ast, validate_err = parser.validate(ast, errorinfo)

  if not validated_ast then
    print("AST Validation failed: " .. validate_err)
  else
    print("AST is valid (semantically).")
  end
else
  print("Parsing failed: " .. parse_err)
end
```

### Pattern 4: Getting Executable Lines and Functions

```lua
--[[
  Parse code and extract analysis information.
]]
local parser = require("lib.tools.parser")

local source = [[
local function add(a, b) -- Line 1
  local sum = a + b    -- Line 2 (executable)
  return sum           -- Line 3 (executable)
end                    -- Line 4

add(1, 2)              -- Line 6 (executable)
]]

local ast, parse_err = parser.parse(source, "analysis_example.lua")
if ast then
  local executable_lines = parser.get_executable_lines(ast, source)
  local functions_info = parser.get_functions(ast, source)

  print("Executable Lines:")
  for line_num, _ in pairs(executable_lines) do
    print("- Line " .. line_num) -- Expected: 2, 3, 6
  end

  print("\nFunctions Found:")
  for _, func in ipairs(functions_info) do
    print(string.format("- %s (%d-%d): Params(%s)",
      func.name, func.line_start, func.line_end, table.concat(func.params, ", ")))
      -- Expected: - add (1-4): Params(a, b)
  end
else
    print("Parsing failed: " .. parse_err)
end
```

### Pattern 5: Using the Code Map (Preferred for Analysis)

```lua
--[[
  Use create_code_map_from_file for combined parsing and analysis.
]]
local parser = require("lib.tools.parser")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")

local file_path = "my_module_for_map.lua"
local setup_ok, _ = error_handler.safe_io_operation(fs.write_file, file_path, "local x=1 print(x)")
if not setup_ok then return end -- Ensure file exists

local code_map = parser.create_code_map_from_file(file_path)

if not code_map.valid then
  print("Failed to create code map: " .. code_map.error)
else
  print("Code map created successfully for: " .. file_path)
  print("Total lines:", code_map.source_lines)
  print("AST Root Tag:", code_map.ast.tag) -- Should be "Block"
  -- Access executable lines: code_map.executable_lines
  -- Access function info: code_map.functions
end

error_handler.safe_io_operation(fs.delete_file, file_path) -- Cleanup
```

### Pattern 6: Viewing AST Structure

```lua
--[[
  Convert AST to string or dump its structure for debugging.
]]
local parser = require("lib.tools.parser")
local ast, _ = parser.parse("local a = 1 + 2")

if ast then
  -- Compact string representation
  local ast_string = parser.to_string(ast)
  print("AST String:\n" .. ast_string)

  -- Detailed structure dump (to console or logger)
  print("\nAST Dump:")
  parser.dump(ast)
  -- parser.log_dump(ast) -- Alternatively, log it
end
```

## Related Components / Modules

- **Sources:**
    - `lib/tools/parser/init.lua`: Main interface, analysis functions, code map creation.
    - `lib/tools/parser/grammar.lua`: LPegLabel grammar definition for Lua syntax.
    - `lib/tools/parser/pp.lua`: Pretty-printing and dumping functions (`to_string`, `dump`).
    - `lib/tools/parser/validator.lua`: Semantic validation logic (`validate`).
- **Dependencies:**
    - **`lib/tools/vendor/lpeglabel/knowledge.md`**: Provides the **required** LPegLabel parsing library. The parser will fail to load if this is missing.
    - `lib/tools/filesystem/knowledge.md`: Used by `parse_file` and `create_code_map_from_file` for reading file content.
    - `lib/tools/error_handler/knowledge.md`: Used indirectly via logging. Note that parser errors are returned as simple strings, not structured error objects.
    - `lib/tools/logging/knowledge.md`: Used heavily internally for debugging messages and reporting parsing/validation errors.
- **Consumers:**
    - `lib/coverage/knowledge.md`: Likely uses `create_code_map` to analyze source code for determining executable lines and tracking coverage.
    - `lib/quality/knowledge.md`: May use the parser for static analysis checks as part of quality validation rules.
    - `lib/tools/codefix/knowledge.md`: May potentially use the parser to understand code structure before applying automated fixes.

## Best Practices / Critical Rules (Optional)

- **Check Return Values:** Always check the second return value (`err`) from `parse()`, `parse_file()`, and `validate()` for potential errors. When using `create_code_map()` or `create_code_map_from_file()`, always check the `valid` boolean field in the returned table before accessing other fields like `ast`.
- **Use Code Map for Analysis:** For tasks requiring the AST plus line information or function definitions (like code coverage), the `create_code_map` functions are the most convenient and recommended entry point.
- **Validate After Parsing (Optional but Recommended):** If your application relies on the semantic correctness of the parsed code (e.g., ensuring `break` is valid), run `M.validate()` on the AST obtained from `M.parse()` before proceeding with further analysis or manipulation.
- **Handle Limits:** Be aware of the built-in source size (~1MB) and parse time (~10s) limits in `M.parse`. If dealing with exceptionally large Lua files, consider alternative parsing strategies or increasing these limits (though large files might indicate a need for refactoring).

## Troubleshooting / Common Pitfalls (Optional)

- **Parsing Fails (`parse`/`parse_file` returns `nil, error_message`):**
    - **Syntax Error:** The most likely cause is an error in the Lua source code itself. The returned `error_message` string usually contains the filename, line number, column number, and a description of the expected token, aiding in pinpointing the syntax issue.
    - **Size/Timeout Limit:** If parsing a very large file or extremely complex code, the internal size or timeout limits might be exceeded. Check the application logs for messages like "Source too large" or "Parse timeout exceeded".
    - **LPegLabel Missing:** If the core `lpeglabel` library failed to load, `require("lib.tools.parser")` itself might fail, or `M.parse` could error very early. Check logs for "Failed to load required dependency". Ensure `lib/tools/vendor/lpeglabel` is present and accessible.
- **Validation Fails (`validate` returns `nil, error_message`):**
    - **Semantic Error:** This indicates the Lua code, while syntactically correct, violates a semantic rule checked by the validator. The `error_message` will specify the issue (e.g., "`<break>` not inside a loop", "no visible label '...' for `<goto>`", "cannot use '...' outside a vararg function"). Check the reported line/column number.
- **Incorrect Analysis Results (`get_executable_lines`, `get_functions`):**
    - **Grammar/Logic Bugs:** The logic identifying executable lines or tracking function definitions (especially complex assignments or nested functions) might contain bugs or limitations for certain Lua code patterns.
    - **Debugging:** Use `M.dump(ast)` or `M.log_dump(ast)` to inspect the raw AST structure generated by `grammar.lua`. Compare the AST structure for the problematic code section against the logic in `get_executable_lines` or `get_functions` within `init.lua` to understand the discrepancy. Report potential bugs if the analysis seems incorrect based on the AST.
- **Performance:** Parsing very large files can be resource-intensive (CPU and memory). Use the `code_map` functions which include timeout protection. Consider if parsing is needed for the entire file or if targeted analysis is possible.
