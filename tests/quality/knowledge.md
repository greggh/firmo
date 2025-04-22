# Quality Knowledge


## Purpose


Test quality validation system and enforce test standards.

## Quality Validation



```lua
-- Enable quality validation
firmo.quality_options.enabled = true
firmo.quality_options.level = 3
-- Run tests with quality checks
firmo.run_discovered("tests/", "*_test.lua", {
  quality = {
    enabled = true,
    level = 3,
    threshold = 80,
    report = "quality-report.html"
  }
})
-- Configure quality rules
quality.configure({
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



## Quality Metrics



```lua
-- Test coverage metrics
local metrics = quality.get_metrics()
expect(metrics.coverage.statements).to.be_greater_than(90)
expect(metrics.coverage.branches).to.be_greater_than(85)
expect(metrics.coverage.functions).to.equal(100)
-- Assertion metrics
expect(metrics.assertions.count).to.be_greater_than(0)
expect(metrics.assertions.per_test).to.be_greater_than(1)
-- Documentation metrics
expect(metrics.documentation.coverage).to.be_greater_than(80)
```



## Critical Rules



- Set appropriate quality level
- Fix quality issues promptly
- Document requirements
- Use quality in CI
- Monitor trends


## Best Practices



- Test all quality levels
- Check metrics regularly
- Verify scoring
- Document standards
- Handle edge cases
- Update documentation
- Monitor trends
- Fix issues early


## Performance Tips



- Cache quality results
- Run in CI pipeline
- Monitor trends
- Fix issues early
- Document exceptions
