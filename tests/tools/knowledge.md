# Tools Testing Knowledge

## Purpose
Test utility modules functionality and helper tools.

## File Operations
```lua
-- Safe file operations
local content, err = fs.read_file("test.txt")
if not content then
  expect(err.category).to.equal("IO")
end

-- Directory operations
local success, err = fs.create_directory("test_dir")
expect(success).to.be_truthy()

-- Path normalization
local path = fs.normalize_path("dir/../file.txt")
expect(path).to.equal("file.txt")

-- Complex file operations
describe("File System Operations", function()
  local test_dir
  
  before_each(function()
    test_dir = test_helper.create_temp_test_directory()
  end)
  
  it("handles large files", function()
    -- Create large test file
    local content = string.rep("x", 1024 * 1024) -- 1MB
    local path = test_dir.path .. "/large.txt"
    
    -- Write in chunks
    local success = fs.write_file(path, content, {
      chunk_size = 1024,
      mode = "644"
    })
    expect(success).to.be_truthy()
    
    -- Read in chunks
    local result = fs.read_file(path, {
      chunk_size = 1024
    })
    expect(#result).to.equal(#content)
  end)
end)
```

## Parser Testing
```lua
-- Parse Lua code
local ast, err = parser.parse([[
  local function test()
    return true
  end
]])
expect(err).to_not.exist()

-- Get executable lines
local lines = parser.get_executable_lines(ast)
expect(lines[2]).to.be_truthy() -- return line

-- Complex parsing
describe("Parser functionality", function()
  it("handles complex syntax", function()
    local code = [[
      local function complex()
        local t = {
          [function() return "key" end] = "value",
          method = function(self) end
        }
        return t
      end
    ]]
    
    local ast = parser.parse(code)
    expect(ast).to.exist()
    
    local info = parser.analyze(ast)
    expect(info.functions).to.have_length(3) -- main + 2 inner
  end)
end)
```

## Error Handling
```lua
-- Test error handler
local success, result, err = error_handler.try(function()
  return risky_operation()
end)

if not success then
  expect(err.category).to.exist()
  expect(err.message).to.match("pattern")
end

-- Complex error scenarios
describe("Error handling", function()
  it("handles nested errors", function()
    local function deep_error()
      error_handler.try(function()
        error("inner error")
      end)
    end
    
    local _, err = test_helper.with_error_capture(function()
      return deep_error()
    end)()
    
    expect(err).to.exist()
    expect(err.stack).to.exist()
  end)
end)
```

## Critical Rules
- Test cross-platform
- Verify error handling
- Check edge cases
- Document test cases
- Clean up resources

## Best Practices
- Test all platforms
- Handle errors
- Check boundaries
- Document setup
- Clean up properly
- Test thoroughly
- Handle timeouts
- Monitor resources
- Validate input
- Clean up state

## Performance Tips
- Use appropriate chunks
- Clean up resources
- Handle timeouts
- Monitor memory
- Batch operations
- Cache results