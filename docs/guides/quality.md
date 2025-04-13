# Quality Validation Guide

This guide explains how to use Firmo's quality validation system to ensure your tests meet specific quality standards beyond simple code coverage.

## Introduction

Code coverage alone isn't enough to guarantee effective tests. Firmo's quality module helps ensure your tests are comprehensive, well-structured, and properly validate your code. The quality system evaluates tests across multiple dimensions:

- **Assertion coverage**: Are you testing the right things with appropriate assertions?
- **Test organization**: Are tests structured properly with describe/it blocks and proper naming?
- **Edge case testing**: Do tests verify boundary conditions and special cases?
- **Error handling**: Are error paths and validation properly tested?
- **Mock verification**: Are mocks and stubs properly verified?

The quality module grades tests on a 1-5 scale, allowing you to set minimum quality requirements for your project.

## Basic Usage

### Enabling Quality Validation

To enable quality validation for your tests:

```lua
-- In your test file or setup module
local quality = require("lib.quality")
quality.init({
  enabled = true,
  level = 3 -- Comprehensive level
})
```

Using the central configuration system:

```lua
-- In your .firmo-config.lua file
return {
  quality = {
    enabled = true,
    level = 3
  }
}
```

From the command line:

```bash
# Run tests with quality validation at level 3
lua test.lua --quality --quality-level=3 tests/
```

### Understanding Quality Levels

Firmo's quality validation provides five progressive quality levels:

1. **Basic (Level 1)**
   - At least one assertion per test
   - Proper test and describe block structure
   - Basic test naming

2. **Standard (Level 2)**
   - Multiple assertions per test (at least 2)
   - Testing equality, truth value, and type checking 
   - Clear test organization and naming

3. **Comprehensive (Level 3)**
   - Multiple assertion types (at least 3 different types)
   - Edge case testing
   - Setup/teardown with before/after hooks
   - Context nesting for organized tests

4. **Advanced (Level 4)**
   - Boundary condition testing
   - Mock verification
   - Integration and unit test separation
   - Performance validation where applicable

5. **Complete (Level 5)**
   - High branch coverage (90% threshold)
   - Security validation
   - Comprehensive API contract testing
   - Multiple assertion types (at least 5 different types)
   - Performance testing requirements

### Configuring Quality Options

You can configure quality validation through the central configuration system:

```lua
-- In .firmo-config.lua
return {
  quality = {
    enabled = true,                -- Enable quality validation
    level = 3,                     -- Quality level to enforce (1-5)
    strict = false,                -- Fail on first issue
    custom_rules = {               -- Custom quality rules
      require_describe_block = true,
      min_assertions_per_test = 3
    }
  },
  reporting = {
    formats = {
      quality = {
        default = "html"           -- Default format for quality reports
      }
    },
    templates = {
      quality = "./reports/quality-{timestamp}.{format}"  -- Report path template
    }
  }
}
```

Or directly in your code:

```lua
local quality = require("lib.quality")
local central_config = require("lib.core.central_config")

-- Update config settings
central_config.set("quality.enabled", true)
central_config.set("quality.level", 3)

-- Or initialize directly
quality.init({
  enabled = true,
  level = 3,
  strict = false
})
```


-- Generate a JSON report
firmo.generate_quality_report("json", "./quality-report.json")

-- Generate a summary report (returns text, doesn't write to file)
local summary = firmo.generate_quality_report("summary")
```

From the command line:

```bash
# Generate HTML quality report
lua test.lua --quality --quality-format=html --quality-output=./reports/quality.html tests/

# Generate JSON quality report 
lua test.lua --quality --quality-format=json --quality-output=./reports/quality.json tests/
```

### Interpreting Quality Reports

Quality reports provide information about:

- Overall quality level achieved
- Test count and assertion statistics
- Which quality standards were met or missed
- Specific recommendations for improvement
- Assertion type distribution
- Quality scores by test file or module

## Advanced Quality Configuration

### Custom Rules

You can define custom quality rules for specific project needs:

```lua
firmo.quality_options.custom_rules = {
  require_describe_block = true,       -- Tests must be in describe blocks
  min_assertions_per_test = 2,         -- Minimum number of assertions per test
  require_error_assertions = true,     -- Tests must include error assertions
  require_mock_verification = true,    -- Mocks must be verified
  max_test_name_length = 60,           -- Maximum test name length
  require_setup_teardown = true,       -- Tests must use setup/teardown
  naming_pattern = "^should_.*$",      -- Test name pattern requirement
  max_nesting_level = 3                -- Maximum nesting level for describes
}
```

### Integration with CI/CD

Quality validation can be integrated into CI/CD pipelines to enforce quality standards:

```bash
# In CI script
lua test.lua --quality --quality-level=3 --quality-format=json --quality-output=./quality-report.json tests/

# Optional: Fail the build if quality level isn't met
if ! lua scripts/check_quality_level.lua ./quality-report.json 3; then
  echo "Quality validation failed!"
  exit 1
fi
```

### Programmatic Quality Checking

You can check quality programmatically:

```lua
local firmo = require("firmo")

-- Run tests with quality validation enabled
firmo.start_quality({
  level = 3,
  strict = true
})

firmo.run_discovered("./tests")

-- Check if quality meets specified level
if firmo.quality_meets_level(3) then
  print("Quality meets level 3 standards!")
else
  print("Quality does not meet level 3 standards")
  
  -- Get quality data for analysis
  local quality_data = firmo.get_quality_data()
  
  -- Output specific issues
  for _, issue in ipairs(quality_data.issues) do
    print("Issue in test: " .. issue.test)
    print("  " .. issue.message)
  end
end
```

## Error Handling

The Quality module provides comprehensive error handling patterns that you should follow in your tests to ensure robustness.

### Standardized Error Handling Patterns

#### 1. Use test_helper.with_error_capture() for Function Calls

```lua
local quality, load_error = test_helper.with_error_capture(function()
  return require("lib.quality")
end)()

expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
expect(quality).to.exist()
```

#### 2. Proper Resource Creation and Cleanup

```lua
-- Track created test files
local test_files = {}

-- Create test files with error handling
local file_path, create_err = temp_file.create_with_content(content, "lua")
expect(create_err).to_not.exist("Failed to create test file: " .. tostring(create_err))
table.insert(test_files, file_path)

-- Clean up in after() hook
after(function()
  for _, filename in ipairs(test_files) do
    -- Remove file with error handling
    local success, err = pcall(function()
      temp_file.remove(filename)
    end)
    
    if not success and logger then
      logger.warn("Failed to remove test file: " .. tostring(err))
    end
  end
  test_files = {}
end)
```

#### 3. Testing Error Conditions

```lua
it("should handle missing files gracefully", { expect_error = true }, function()
  -- Try to check a non-existent file
  local result, err = test_helper.with_error_capture(function()
    return quality.check_file("non_existent_file.lua", 1)
  end)()
  
  -- The check should either return false or an error
  if result ~= nil then
    expect(result).to.equal(false, "check_file should return false for non-existent files")
  else
    expect(err).to.exist("check_file should error for non-existent files")
  end
end)
```

#### 4. Graceful Logger Initialization

```lua
local logger
local logger_init_success, result = pcall(function()
  local logging = require("lib.tools.logging")
  logger = logging.get_logger("test.quality")
  return true
end)

if not logger_init_success then
  print("Warning: Failed to initialize logger: " .. tostring(result))
  -- Create a minimal logger as fallback
  logger = {
    debug = function() end,
    info = function() end,
    warn = function(msg) print("WARN: " .. msg) end,
    error = function(msg) print("ERROR: " .. msg) end
  }
end
```

### Parameter Validation

Always validate input parameters in functions that work with the quality module:

```lua
local function check_test_quality(file_path, quality_level)
  -- Validate parameters
  if not file_path or file_path == "" then
    return false, "Invalid file path"
  end
  
  if not quality_level or type(quality_level) ~= "number" or 
     quality_level < 1 or quality_level > 5 then
    return false, "Invalid quality level: must be between 1 and 5"
  end
  
  -- Continue with implementation...
}
```

## Troubleshooting

### Common Quality Issues

If your tests don't meet quality standards, look for:

1. **Too few assertions**: Add more comprehensive assertions covering different aspects
2. **Missing assertion types**: Ensure you use different assertion types (equality, type, existence, etc.)
3. **No error testing**: Add tests for error conditions and edge cases
4. **Missing before/after hooks**: Add proper setup and teardown
5. **No nested contexts**: Use nested describe blocks to organize tests
6. **Insufficient mock verification**: Verify mock calls are made correctly

### Progressive Implementation

If you're adding quality validation to an existing project:

1. Start with Level 1 and gradually increase the required level
2. Focus on improving one test suite at a time
3. Set up CI pipeline to warn (not fail) until ready for enforcement
4. Create template tests that meet quality standards

## Best Practices

1. **Use descriptive test names**: Tests should clearly describe what they're verifying
2. **Structure tests logically**: Use nested describe blocks to organize tests by feature
3. **Test both happy and error paths**: Always test both successful and error scenarios
4. **Verify edge cases**: Test boundary conditions and special cases
5. **Use setup/teardown properly**: Initialize and clean up test state in before/after hooks
6. **Keep tests independent**: Tests should not depend on other tests' state
7. **Verify mock interactions**: Always verify that mocks are called correctly
8. **Test security implications**: Include security testing for sensitive components

## Conclusion

Quality validation helps ensure your tests are comprehensive, well-structured, and effective. By following the patterns and practices in this guide, you can write tests that meet high quality standards and provide better verification of your code's behavior.