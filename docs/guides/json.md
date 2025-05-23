# JSON Module Guide

The JSON module provides functions for working with JSON data in Lua. It supports encoding Lua values to JSON strings and decoding JSON strings back to Lua values.

## Overview

The JSON module implements a fast and standards-compliant JSON encoder/decoder that:

- Handles all standard JSON data types
- Provides detailed error messages
- Integrates with firmo's error handling system
- Optimizes for common use cases

## Basic Usage

### Encoding Lua Values to JSON

```lua
local json = require("lib.tools.json")
-- Encode simple values
local str1 = json.encode("hello")  -- "hello"
local str2 = json.encode(42)       -- 42
local str3 = json.encode(true)     -- true
local str4 = json.encode(nil)      -- null
-- Encode arrays
local arr = json.encode({1, 2, 3})  -- [1,2,3]
-- Encode objects
local obj = json.encode({
  name = "test",
  value = 42
})  -- {"name":"test","value":42}
-- Encode nested structures
local nested = json.encode({
  items = {
    { id = 1, name = "first" },
    { id = 2, name = "second" }
  },
  count = 2
})
```

### Decoding JSON to Lua Values

```lua
local json = require("lib.tools.json")
-- Decode simple values
local val1 = json.decode('"hello"')  -- "hello"
local val2 = json.decode('42')       -- 42
local val3 = json.decode('true')     -- true
local val4 = json.decode('null')     -- nil
-- Decode arrays
local arr = json.decode('[1,2,3]')  -- {1, 2, 3}
-- Decode objects
local obj = json.decode([[
{
  "name": "test",
  "value": 42
}
]])  -- {name = "test", value = 42}
-- Decode nested structures
local nested = json.decode([[
{
  "items": [
    {"id": 1, "name": "first"},
    {"id": 2, "name": "second"}
  ],
  "count": 2
}
]])
```

## Common Use Cases

### Configuration Files

```lua
local json = require("lib.tools.json")
local fs = require("lib.tools.filesystem")
-- Load configuration
local function load_config(path)
  local content = fs.read_file(path)
  if not content then
    return nil, "Failed to read config file"
  end

  return json.decode(content)
end
-- Save configuration
local function save_config(path, config)
  local json_str = json.encode(config)
  if not json_str then
    return nil, "Failed to encode config"
  end

  return fs.write_file(path, json_str)
end
-- Usage
local config = load_config("config.json")
config.debug = true
save_config("config.json", config)
```

### API Responses

```lua
local json = require("lib.tools.json")
-- Parse API response
local function parse_response(response_body)
  local data = json.decode(response_body)
  if not data then
    return nil, "Invalid JSON response"
  end

  -- Process data
  return {
    id = data.id,
    name = data.name,
    timestamp = data.created_at
  }
end
-- Create API request body
local function create_request(params)
  return json.encode({
    method = "update",
    params = params,
    id = generate_id()
  })
end
```

### Data Storage

```lua
local json = require("lib.tools.json")
-- Simple key-value store
local Store = {}
function Store.new()
  return setmetatable({
    data = {}
  }, {__index = Store})
end
function Store:serialize()
  return json.encode(self.data)
end
function Store:deserialize(str)
  local data = json.decode(str)
  if data then
    self.data = data
  end
end
function Store:set(key, value)
  self.data[key] = value
end
function Store:get(key)
  return self.data[key]
end
-- Usage
local store = Store.new()
store:set("user", {
  name = "John",
  age = 30
})
local serialized = store:serialize()
-- Save to file or send over network
local new_store = Store.new()
new_store:deserialize(serialized)
print(new_store:get("user").name)  -- "John"
```

## Best Practices

1. **Error Handling**: Always check for errors when encoding/decoding:

   ```lua
   local json_str, err = json.encode(data)
   if not json_str then
     -- Handle error
     print("Failed to encode:", err.message)
     return
   end
   ```

2. **Type Validation**: Validate data types before encoding:

   ```lua
   local function is_valid_user(user)
     return type(user) == "table"
       and type(user.name) == "string"
       and type(user.age) == "number"
   end

   local function encode_user(user)
     if not is_valid_user(user) then
       return nil, "Invalid user data"
     end
     return json.encode(user)
   end
   ```

3. **Memory Efficiency**: For large data structures, process incrementally:

   ```lua
   local function process_large_array(arr)
     local chunks = {}
     local chunk_size = 1000

     for i = 1, #arr, chunk_size do
       local chunk = {}
       for j = i, math.min(i + chunk_size - 1, #arr) do
         table.insert(chunk, arr[j])
       end
       local json_chunk = json.encode(chunk)
       -- Process chunk...
     end
   end
   ```

4. **Schema Validation**: Validate decoded data against expected schema:

   ```lua
   local function validate_config(config)
     if type(config) ~= "table" then return false end
     if type(config.host) ~= "string" then return false end
     if type(config.port) ~= "number" then return false end
     return true
   end

   local function load_config(path)
     local content = fs.read_file(path)
     if not content then return nil, "Failed to read file" end

     local config = json.decode(content)
     if not config then return nil, "Invalid JSON" end

     if not validate_config(config) then
       return nil, "Invalid config format"
     end

     return config
   end
   ```

## Common Pitfalls

1. **Circular References**: Tables with circular references cannot be encoded:

   ```lua
   local t = {}
   t.self = t  -- Circular reference
   local json_str = json.encode(t)  -- Will fail
   ```

2. **Invalid Keys**: Only string keys are supported for objects:

   ```lua
   -- This will work:
   json.encode({["1"] = "value"})

   -- These will fail:
   json.encode({[{}] = "value"})
   json.encode({[1.5] = "value"})
   ```

3. **Special Numbers**: NaN and Infinity are encoded as null:

   ```lua
   json.encode(0/0)      -- "null" (NaN)
   json.encode(math.huge) -- "null" (Infinity)
   ```

4. **Unicode**: Unicode escape sequences are not supported:

   ```lua
   local str = json.decode('"\\u0041"')  -- Will fail
   ```

## Integration with Other Modules

The JSON module is commonly used with:

1. **Filesystem Module**: For reading/writing JSON files
2. **Error Handler**: For consistent error handling
3. **Logging**: For debugging JSON operations
4. **Coverage Module**: For storing coverage data
5. **Test Helper**: For creating test fixtures

## Next Steps

After mastering the JSON module, explore:

1. [Filesystem Module](./filesystem.md)
2. [Error Handler](./error_handler.md)
3. [Logging](./logging.md)
4. [Coverage Module](./coverage.md)
