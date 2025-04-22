# Core Testing Knowledge


## Purpose


Test fundamental framework functionality.

## Components



- Configuration management
- Module reset system
- Test lifecycle
- Type validation
- Tagging system


## Configuration Testing



```lua
describe("Configuration", function()
  -- Test loading from file
  it("loads from .firmo-config.lua", function()
    local config = require("lib.core.central_config")
    local success = config.load_from_file(".firmo-config.lua")
    expect(success).to.be_truthy()
    expect(config.get_config()).to.exist()
  end)
  -- Test overriding values
  it("overrides with CLI options", function()
    local config = require("lib.core.central_config")
    config.override({ debug = true })
    expect(config.get_config().debug).to.be_truthy()
  end)
  -- Test validation
  it("validates config values", function()
    local config = require("lib.core.central_config")
    local success, err = config.set("coverage.threshold", "invalid")
    expect(success).to_not.exist()
    expect(err.category).to.equal("VALIDATION")
  end)
end)
```



## Module Reset Pattern



```lua
describe("Module Reset", function()
  local fresh_module

  -- Reset before each test
  before_each(function()
    fresh_module = firmo.reset_module("path.to.module")
  end)
  -- Test clean state
  it("provides clean module state", function()
    expect(fresh_module._state).to.be.empty()
  end)
  -- Test circular dependencies
  it("handles circular dependencies", function()
    local modules = {
      "module_a",
      "module_b",
      "module_c"
    }

    local success = firmo.reset_modules(modules, {
      order = {"c", "b", "a"}
    })
    expect(success).to.be_truthy()
  end)
end)
```



## Type Validation



```lua
-- Basic type checks
expect(value).to.be.a("string")
expect(value).to.be.a("number")
expect(value).to.be.a("table")
expect(value).to.be.a("function")
-- Complex type validation
expect(fn).to.be_type("callable")  -- Function or callable table
expect(num).to.be_type("comparable")  -- Can use < operator
expect(table).to.be_type("iterable")  -- Can iterate with pairs()
-- Custom type validation
type_checker.register_type("positive_number", function(value)
  return type(value) == "number" and value > 0
end)
```



## Error Handling



```lua
-- Test error handling
it("handles configuration errors", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return config.load_from_file("nonexistent.lua")
  end)()

  expect(err).to.exist()
  expect(err.category).to.equal("IO")
  expect(err.message).to.match("not found")
end)
-- Test validation errors
it("validates input", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return config.set("invalid.path", "value")
  end)()

  expect(err).to.exist()
  expect(err.category).to.equal("VALIDATION")
end)
```



## Critical Rules



- ALWAYS use central_config
- NEVER bypass type checks
- ALWAYS handle module reset
- NEVER modify core modules
- ALWAYS validate input


## Best Practices



- Test configuration thoroughly
- Verify type validation
- Check error handling
- Document test cases
- Clean up state
- Handle edge cases
- Test all paths
- Verify resets


## Common Pitfalls



```lua
-- WRONG:
-- Direct module modification
module._state = {}  -- Don't modify internal state
-- CORRECT:
-- Use proper reset
module = firmo.reset_module("module")
```
