# Guides Knowledge


## Purpose


Practical how-to guides and best practices for using Firmo.

## Getting Started



```lua
-- Basic test structure
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
describe("Calculator", function()
  local calculator

  before(function()
    calculator = {
      add = function(a, b) return a + b end,
      subtract = function(a, b) return a - b end
    }
  end)
  it("adds numbers", function()
    expect(calculator.add(2, 2)).to.equal(4)
  end)

  it("handles errors", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return calculator.divide(1, 0)
    end)()
    expect(err).to.exist()
  end)
end)
```



## Testing Patterns



```lua
-- Resource cleanup pattern
describe("Database tests", function()
  local db

  before(function()
    db = require("database")
    db.connect()
  end)

  after(function()
    db.disconnect()
  end)

  it("saves data", function()
    local id = db.insert({ data = "test" })
    local result = db.find(id)
    expect(result.data).to.equal("test")
  end)
end)
-- Async pattern
it.async("handles async operations", function(done)
  start_async_operation(function(result)
    expect(result).to.exist()
    done()
  end)
end)
-- Mocking pattern
describe("Service tests", function()
  local service, mock_db

  before(function()
    mock_db = firmo.mock.new()
    service = create_service(mock_db)
  end)

  it("processes data", function()
    mock_db.query.returns({ rows = 5 })
    local result = service.process()
    expect(result.count).to.equal(5)
  end)
end)
```



## CI Integration



```bash

# Run tests in CI


lua test.lua --coverage tests/

# Generate reports


lua test.lua --coverage --format html,json tests/

# Run with quality checks


lua test.lua --quality --quality-level=3 tests/

# Run specific test suites


lua test.lua --tags unit,integration tests/
```



## Critical Rules



- Follow test patterns
- Clean up resources
- Handle errors
- Document behavior
- Use helpers
- Test thoroughly
- Monitor performance


## Best Practices



- Write clear tests
- Handle edge cases
- Clean up resources
- Document behavior
- Use helpers
- Follow patterns
- Test thoroughly
- Monitor performance


## Common Patterns



- Resource cleanup
- Error handling
- Async operations
- Mocking services
- Data setup
- State reset
- Report generation
- Quality validation
