# Fixtures Knowledge

## Purpose
Provide common test data and utilities.

## Fixture Examples
```lua
-- Common error fixtures
local common_errors = {
  divide_by_zero = function()
    return 1/0
  end,
  
  invalid_input = function()
    return nil, error_handler.validation_error(
      "Invalid input",
      {parameter = "input", provided = nil}
    )
  end,
  
  type_error = function()
    local num = 42
    return num:upper() -- Attempting to call method on number
  end,
  
  out_of_memory = function(limit)
    limit = limit or 1000000
    local t = {}
    for i = 1, limit do
      table.insert(t, string.rep("x", 100))
    end
    return t
  end
}

-- Test module fixture
local test_math = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b)
    if b == 0 then
      error("Division by zero")
    end
    return a / b
  end
}

-- Data fixtures
local sample_data = {
  users = {
    {id = 1, name = "Test User"},
    {id = 2, name = "Another User"}
  },
  products = {
    {id = 1, name = "Product 1", price = 10.99},
    {id = 2, name = "Product 2", price = 20.99}
  }
}
```

## Directory Structure
```
fixtures/
├── common_errors.lua    # Common error scenarios
├── modules/            # Test modules
│   └── test_math.lua  # Math operations
└── data/              # Test data
    └── users.json     # Sample data
```

## Using Fixtures
```lua
-- Import fixtures
local common_errors = require("tests.fixtures.common_errors")
local test_math = require("tests.fixtures.modules.test_math")

describe("Error handling", function()
  it("handles division by zero", function()
    expect(common_errors.divide_by_zero).to.fail()
  end)
end)

describe("Math operations", function()
  it("adds numbers", function()
    expect(test_math.add(2, 3)).to.equal(5)
  end)
end)
```

## Temporary Files
```lua
-- Create test directory
local test_dir = test_helper.create_temp_test_directory()

-- Create test files
test_dir.create_file("config.json", '{"setting": "value"}')
test_dir.create_file("data.txt", "test content")

-- Create multiple files
test_dir.create_numbered_files("test", "content %d", 10)

-- Clean up happens automatically
```

## Critical Rules
- Keep fixtures simple
- Document purpose
- Make reusable
- Clean up resources
- Version control

## Best Practices
- Keep focused
- Document usage
- Make independent
- Handle cleanup
- Test fixtures
- Keep minimal
- Update regularly
- Version control
- Document changes
- Handle errors

## Performance Tips
- Cache fixtures
- Clean up promptly
- Monitor resources
- Handle large data
- Use streaming
- Batch operations