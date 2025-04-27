# lib/tools/json Knowledge

## Purpose

The `lib/tools/json` module provides fundamental functions for working with JSON (JavaScript Object Notation) data within the Firmo framework. It offers a pure Lua implementation for encoding Lua data structures into JSON formatted strings (`M.encode`) and for decoding JSON strings back into Lua data structures (`M.decode`). It is suitable for simple, internal JSON serialization and deserialization tasks where external dependencies or full specification compliance (like Unicode escape handling) are not primary requirements.

## Key Concepts

- **`M.encode(value)` Function:**
    - **Purpose:** Serializes a given Lua value into a JSON string representation.
    - **Supported Lua Types:**
        - `nil`: Encodes to the JSON literal `null`.
        - `boolean`: Encodes to `true` or `false`.
        - `number`: Encodes to a JSON number string. Uses `string.format("%.14g", val)` for precision. Special numbers `NaN`, `+Infinity`, and `-Infinity` are encoded as `null`.
        - `string`: Encodes to a JSON string literal, enclosed in double quotes (`"`). Standard control characters (`\b`, `\f`, `\n`, `\r`, `\t`), double quotes (`"`), and backslashes (`\`) are escaped (e.g., `\n`, `\"`, `\\`). Other control characters (ASCII 0-31) are escaped using `\uXXXX` notation.
        - `table`: Handled recursively. The function attempts to detect if the table should be represented as a JSON array or object:
            - **Array:** If all keys are positive integers from 1 up to a maximum index `n`, it's encoded as `[...]`, containing the encoded values from `val[1]` to `val[n]`.
            - **Object:** Otherwise, it's encoded as `{...}`. Only key-value pairs where the key is a `string` are included. Keys are encoded as JSON strings, and values are recursively encoded.
    - **Unsupported Lua Types:** Passing functions, userdata, or threads to `M.encode` will result in an error.
    - **Error Handling:** The encoding process is wrapped in `error_handler.try`. If an error occurs (e.g., attempting to encode an unsupported type), the error is logged using `lib.tools.logging`, and the function returns `nil, error_object`.

- **`M.decode(json_string)` Function:**
    - **Purpose:** Deserializes a JSON formatted string into a corresponding Lua value.
    - **Supported JSON Types:**
        - `null`: Decodes to Lua `nil`.
        - `true`, `false`: Decodes to Lua `boolean`.
        - Numbers (integer, float, scientific notation): Decodes to Lua `number`.
        - Strings (`"..."`): Decodes to Lua `string`. Handles standard JSON escapes: `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`.
        - Arrays (`[...]`): Decodes to a Lua sequence table (integer keys 1, 2, 3...).
        - Objects (`{...}`): Decodes to a Lua table where keys are the JSON string keys.
    - **Parser Implementation:** Uses a basic recursive descent parser. It correctly handles nested structures and skips insignificant whitespace between JSON tokens.
    - **CRITICAL LIMITATION - Unicode Escapes:** The current decoder implementation **does not support** Unicode escape sequences (`\uXXXX`). If the input JSON string contains such sequences within its strings, `M.decode` will fail and return an error.
    - **Error Handling:** First validates that the input `json_string` is actually a string. The parsing process is wrapped in `error_handler.try`. If a syntax error is found in the JSON string, or if an unsupported feature like a `\uXXXX` escape is encountered, the error is logged via `lib.tools.logging`, and the function returns `nil, error_object`.

## Usage Examples / Patterns

### Pattern 1: Encoding a Lua Table

```lua
--[[
  Demonstrates encoding a mixed Lua table to JSON.
]]
local json = require("lib.tools.json")

local lua_data = {
  name = "Firmo JSON Example",
  version = 1.0,
  enabled = true,
  keywords = { "lua", "json", "encode" }, -- Array part
  config = { timeout = 5000, retry = false }, -- Object part
  description = "A string with\nnewline and \"quotes\"."
}

local json_string, err = json.encode(lua_data)

if json_string then
  print("Encoded JSON:\n" .. json_string)
  -- Expected output might look like:
  -- {"name":"Firmo JSON Example","config":{"timeout":5000,"retry":false},"enabled":true,"description":"A string with\\nnewline and \\\"quotes\\\".","keywords":["lua","json","encode"],"version":1}
else
  print("Error encoding JSON: " .. err.message)
end

-- Encoding a simple array
local json_array_str = json.encode({10, 20, "thirty", nil})
print("Encoded Array: " .. json_array_str) -- Expected: [10,20,"thirty",null]

-- Encoding unsupported type (will cause error)
local err_func_str, err_func = json.encode({ func = function() end })
if not err_func_str then
    print("Encoding function failed as expected: " .. err_func.message)
end
```

### Pattern 2: Decoding a JSON String

```lua
--[[
  Demonstrates decoding a JSON string to a Lua table.
]]
local json = require("lib.tools.json")

local json_string = '{"id": 123, "name": "Example", "tags": ["test", "simple"], "active": true, "score": 99.5, "extra": null}'

local lua_value, err = json.decode(json_string)

if lua_value then
  print("Decoded Lua Value:")
  -- Example access:
  print("ID:", lua_value.id) -- Output: ID: 123
  print("Second Tag:", lua_value.tags[2]) -- Output: Second Tag: simple
  print("Active:", lua_value.active) -- Output: Active: true
else
  print("Error decoding JSON: " .. err.message)
end
```

### Pattern 3: Handling Decoding Errors

```lua
--[[
  Shows how to handle potential errors during decoding.
]]
local json = require("lib.tools.json")

-- Example with invalid syntax (missing closing brace)
local invalid_json = '{"key": "value"'
local value_invalid, err_invalid = json.decode(invalid_json)

if not value_invalid then
  print("Decoding invalid JSON failed as expected: " .. err_invalid.message)
end

-- Example with unsupported Unicode escape
local unicode_json = '{"char": "\\u26A0"}' -- Warning sign unicode
local value_unicode, err_unicode = json.decode(unicode_json)

if not value_unicode then
  print("Decoding JSON with Unicode escape failed as expected: " .. err_unicode.message)
end
```

## Related Components / Modules

- **`lib/tools/json/init.lua`**: The source code implementation of this module.
- **`lib/tools/error_handler/knowledge.md`**: This JSON module uses the error handler to create standardized error objects for encoding/decoding failures and wraps operations in `try`.
- **`lib/tools/logging/knowledge.md`**: Used internally to log errors that occur during encoding or decoding.
- **`lib/reporting/formatters/json.lua`**: The JSON reporter likely uses this module (or potentially another JSON library) to generate its output.
- Configuration Loading/Saving: Could potentially be used if Firmo implements configuration saving or loading from JSON files (though Lua tables are more common via `central_config`).

## Best Practices / Critical Rules (Optional)

- **Use for Simple Needs:** This module is well-suited for basic, internal serialization/deserialization tasks within Firmo where performance is not the absolute top priority and full JSON specification compliance (especially `\uXXXX` support) is not strictly required.
- **Be Aware of Limitations:** The lack of support for decoding `\uXXXX` Unicode escape sequences is the most significant limitation. If interacting with external systems that produce JSON with these escapes, this module will fail.
- **Check Return Values:** Always check the second return value (`err`) from `M.encode` and `M.decode` to handle potential errors gracefully.

## Troubleshooting / Common Pitfalls (Optional)

- **`M.decode` returns `nil, err`:**
    - **Invalid Syntax:** The most common cause. Double-check the JSON string for errors like missing commas, mismatched brackets/braces, incorrect quoting, etc. Using an online JSON validator can help identify syntax issues.
    - **Unsupported Unicode Escapes (`\uXXXX`): CRITICAL:** If the JSON string contains `\uXXXX` sequences, this decoder **will fail**. The error message might be "Unicode escape sequences not supported" or similar. **Workaround:** If possible, pre-process the JSON string to remove or replace these sequences before decoding. Alternatively, use a more robust external JSON library (like `dkjson` or `lua-cjson` if C bindings are acceptable) if full Unicode support is necessary.
- **`M.encode` returns `nil, err`:**
    - **Unsupported Lua Type:** The Lua data structure being encoded likely contains a value of a type that cannot be serialized to JSON (e.g., a function, userdata, or thread). **Solution:** Traverse the Lua structure before encoding and remove or replace unsupported types with suitable representations (e.g., replace functions with `nil` or a placeholder string).
    - **Circular References:** While not explicitly handled or detected, deeply nested tables with circular references could potentially cause a stack overflow during recursive encoding. This is less likely with typical data structures but possible. **Solution:** Avoid circular references in data intended for JSON serialization.
    - **Number Precision/Representation:** While encoding uses `%.14g`, be aware of potential floating-point precision limitations when decoding and re-encoding numbers. `NaN`/`Infinity` are intentionally converted to `null`.
