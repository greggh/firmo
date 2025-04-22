# Parser Knowledge


## Purpose


Parse and analyze Lua source code for coverage and quality modules.

## Parser Usage



```lua
-- Basic parsing
local parser = require("lib.tools.parser")
local ast, err = parser.parse([[
  local function test()
    return true
  end
]])
-- Parse from file
local ast, err = parser.parse_file("module.lua")
-- Get executable lines
local lines = parser.get_executable_lines(ast)
-- Create detailed code map
local code_map = parser.create_code_map(source, "module.lua")
-- Complex parsing example
local code_map = parser.create_code_map([[
  local function complex()
    local t = {
      [function() return "key" end] = "value",
      method = function(self) end
    }
    return t
  end
]], "complex.lua")
if code_map.valid then
  for line, executable in pairs(code_map.executable_lines) do
    print(string.format("Line %d: %s", line, 
      executable and "executable" or "not executable"))
  end

  for _, func in ipairs(code_map.functions) do
    print(string.format("Function %s: lines %d-%d", 
      func.name, func.line_start, func.line_end))
  end
end
```



## Error Handling



```lua
-- Safe parsing
local function safe_parse(source)
  local ast, err = parser.parse(source)
  if not ast then
    logger.error("Parse failed", {
      error = err,
      source_length = #source
    })
    return nil, err
  end

  -- Validate AST
  local valid, validate_err = parser.validate(ast)
  if not valid then
    logger.error("AST validation failed", {
      error = validate_err
    })
    return nil, validate_err
  end

  return ast
end
-- Handle large files
local function parse_large_file(path)
  local source, err = fs.read_file(path)
  if not source then
    return nil, err
  end

  -- Check file size
  if #source > 1024000 then -- 1MB
    return nil, error_handler.validation_error(
      "File too large",
      { size = #source }
    )
  end

  return parser.parse(source, path)
end
```



## Critical Rules



- Always check error returns
- Validate ASTs after parsing
- Handle large files carefully
- Clean up resources
- Document patterns
- Test thoroughly
- Monitor performance


## Best Practices



- Use code_map for analysis
- Include filenames in errors
- Handle timeouts
- Clean up resources
- Document patterns
- Test edge cases
- Monitor memory
- Handle errors
- Cache results


## Performance Tips



- Parse in chunks
- Handle timeouts
- Monitor memory
- Clean up promptly
- Cache results
- Stream large files
