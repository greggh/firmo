# JSON Module API Reference


The `json` module provides functions for encoding Lua values to JSON strings and decoding JSON strings back to Lua values.

## Importing the Module



```lua
local json = require("lib.tools.json")
```



## Core Functions


### Encoding



```lua
local json_str, err = json.encode(value)
```


Encode a Lua value to a JSON string.
**Parameters:**


- `value` (any): The Lua value to encode

**Returns:**


- `json_str` (string|nil): The JSON string, or nil if encoding failed
- `error` (table|nil): Error information if encoding failed

**Example:**


```lua
local data = {
  name = "test",
  values = {1, 2, 3},
  enabled = true
}
local json_str = json.encode(data)
print(json_str)  -- {"name":"test","values":[1,2,3],"enabled":true}
```



### Decoding



```lua
local value, err = json.decode(json_str)
```


Decode a JSON string to a Lua value.
**Parameters:**


- `json_str` (string): The JSON string to decode

**Returns:**


- `value` (any|nil): The decoded Lua value, or nil if decoding failed
- `error` (table|nil): Error information if decoding failed

**Example:**


```lua
local json_str = '{"name":"test","values":[1,2,3],"enabled":true}'
local data = json.decode(json_str)
print(data.name)  -- "test"
print(data.values[1])  -- 1
print(data.enabled)  -- true
```



## Error Handling


The module uses the standard error_handler system:


```lua
-- Encoding errors
local json_str, err = json.encode({[{}] = true})  -- Invalid key type
if not json_str then
  print("Failed to encode:", err.message)
end
-- Decoding errors
local value, err = json.decode("invalid json")
if not value then
  print("Failed to decode:", err.message)
end
```



## Module Version



```lua
json._VERSION  -- e.g., "1.0.0"
```


The version of the JSON module.

## Type Support


### Encoding


| Lua Type | JSON Representation |
|----------|-------------------|
| nil | null |
| boolean | true/false |
| number | number |
| string | string |
| table (array) | array |
| table (object) | object |

### Decoding


| JSON Type | Lua Representation |
|-----------|-------------------|
| null | nil |
| boolean | boolean |
| number | number |
| string | string |
| array | table with numeric keys |
| object | table with string keys |

## Limitations



1. **Table Keys**: Only string keys are supported for objects
2. **Special Numbers**: NaN and Infinity are encoded as null
3. **Unicode**: Unicode escape sequences in strings are not supported
4. **Circular References**: Not supported in tables
