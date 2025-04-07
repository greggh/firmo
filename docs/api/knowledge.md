# API Knowledge

## Purpose
Detailed technical documentation of modules, functions, and patterns.

## Core Functions
```lua
-- Test Structure
describe("Group", function()
  before(function()
    -- Setup
  end)
  
  it("test case", function()
    expect(value).to.exist()
  end)
  
  after(function()
    -- Cleanup
  end)
end)

-- Assertions
expect(value).to.exist()
expect(value).to.equal(expected)
expect(value).to.be.truthy()
expect(table).to.contain.key("id")
expect(str).to.start_with("prefix")

-- Async Testing
it.async("async test", function(done)
  async_operation(function(result)
    expect(result).to.exist()
    done()
  end)
end)

-- Parallel Operations
local results = parallel_async({
  function() await(100); return "first" end,
  function() await(200); return "second" end
})

-- Module Reset
local fresh_module = reset_module("app.module")
with_fresh_module("app.module", function(mod)
  -- Test with fresh module
end)

-- Mocking
local mock = firmo.mock.new()
mock.method.returns("mocked")
expect(mock.method()).to.equal("mocked")

-- Coverage & Quality
firmo.coverage_options.enabled = true
firmo.coverage_options.include = {"src/*.lua"}
firmo.quality_options.level = 3

-- Reporting
local reporting = require("lib.reporting")
reporting.generate({
  format = "html",
  output = "coverage.html"
})
```

## Error Handling
```lua
-- Standard error pattern
local success, result, err = error_handler.try(function()
  return risky_operation()
end)

if not success then
  logger.error("Operation failed", {
    error = err,
    category = err.category
  })
  return nil, err
end

-- Test error handling
it("handles errors", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return function_that_throws()
  end)()
  expect(err).to.exist()
  expect(err.category).to.equal("VALIDATION")
end)
```

## Critical Rules
- Use expect-style assertions
- Always handle errors
- Clean up resources
- Document APIs
- Test thoroughly
- Follow patterns
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

## Module Organization
- Core: Test structure
- Assertions: Verification
- Async: Time operations
- Coverage: Code tracking
- Quality: Test validation
- Reporting: Output formats
- Tools: Utilities