# Quality Knowledge


## Purpose


Validates and enforces test quality standards.

## Quality Validation



```lua
-- Enable quality validation
local quality = require("lib.quality")
quality.configure({
  enabled = true,
  level = 3,
  threshold = 80
})
-- Configure quality rules
quality.set_rules({
  assertion_count: {
    min: 1,
    max: 5
  },
  coverage: {
    statements: 90,
    branches: 85,
    functions: 100
  },
  complexity: {
    max: 10
  }
})
-- Complex quality validation
describe("Quality validation", function()
  before_each(function()
    quality.reset()
    quality.start({
      level = 4,
      rules = {
        assertions = { min = 2 },
        coverage = { min = 90 },
        complexity = { max = 8 }
      }
    })
  end)

  it("validates test quality", function()
    local result = quality.validate_test({
      assertions = 3,
      coverage = 95,
      complexity = 5
    })

    expect(result.passed).to.be_truthy()
    expect(result.score).to.be_greater_than(90)
  end)

  after_each(function()
    quality.stop()
  end)
end)
```



## Quality Levels



```lua
-- Level 1: Basic Syntax
describe("Basic Quality", function()
  it("has assertions", function()
    expect(true).to.be_truthy()
  end)
end)
-- Level 2: Coverage
describe("Coverage Quality", function()
  it("tests edge cases", function()
    expect(process_number(-1)).to.equal(0)
    expect(process_number(0)).to.equal(0)
    expect(process_number(1)).to.equal(1)
  end)
end)
-- Level 3: Assertions
describe("Assertion Quality", function()
  it("uses specific assertions", function()
    local result = complex_operation()
    expect(result.status).to.equal("success")
    expect(result.data).to.be.a("table")
    expect(result.data.id).to.be_greater_than(0)
  end)
end)
-- Level 4: Error Handling
describe("Error Quality", function()
  it("verifies error conditions", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return risky_operation()
    end)()
    expect(err).to.exist()
    expect(err.category).to.equal("VALIDATION")
  end)
end)
-- Level 5: Documentation
describe("Documentation Quality", function()
  -- @test Verifies user authentication process
  -- @covers auth.login
  -- @covers auth.validate
  it("authenticates users", function()
    -- Test implementation
  end)
end)
```



## Error Handling



```lua
-- Quality validation errors
local function validate_with_errors(test)
  local result, err = quality.validate_test(test)
  if not result then
    logger.error("Quality validation failed", {
      error = err,
      test = test.name
    })
    return nil, err
  end
  return result
end
-- Handle validation failures
local function handle_quality_failure(result)
  if result.score < quality.get_threshold() then
    logger.warn("Test quality below threshold", {
      score = result.score,
      threshold = quality.get_threshold(),
      failures = result.failures
    })

    -- Generate improvement suggestions
    local suggestions = quality.get_suggestions(result)
    for _, suggestion in ipairs(suggestions) do
      logger.info("Quality improvement suggestion", {
        type = suggestion.type,
        message = suggestion.message
      })
    end
  end
end
```



## Critical Rules



- Set appropriate quality level
- Fix quality issues promptly
- Document requirements
- Use quality in CI
- Monitor trends
- Follow standards
- Handle errors
- Clean up state


## Best Practices



- Test all quality levels
- Check metrics regularly
- Verify scoring
- Document standards
- Handle edge cases
- Update documentation
- Monitor trends
- Fix issues early
- Follow patterns
- Use helpers


## Performance Tips



- Cache quality results
- Run in CI pipeline
- Monitor trends
- Fix issues early
- Document exceptions
- Batch operations
- Handle timeouts
