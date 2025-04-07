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
local firmo = require("firmo")
firmo.quality_options.enabled = true
firmo.quality_options.level = 3 -- Comprehensive level
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
   - High branch coverage
   - Security validation
   - Comprehensive API contract testing
   - Multiple assertion types (at least 5 different types)

### Configuring Quality Options

You can configure quality validation through the `firmo.quality_options` table:

```lua
firmo.quality_options = {
  enabled = true,                -- Enable quality validation
  level = 3,                     -- Quality level to enforce (1-5)
  format = "html",               -- Default format for reports
  output = "./quality-reports",  -- Default output location for reports
  strict = false,                -- Fail on first issue
  custom_rules = {               -- Custom quality rules
    require_describe_block = true,
    min_assertions_per_test = 3
  }
}
```

## Writing Tests that Meet Quality Standards

### Level 1: Basic Quality

At this level, ensure each test has at least one assertion:

```lua
describe("Calculator", function()
  it("should add two numbers", function()
    expect(add(2, 3)).to.equal(5)
  end)
  
  it("should subtract numbers", function()
    expect(subtract(5, 3)).to.equal(2)
  end)
end)
```

### Level 2: Standard Quality

At this level, use multiple assertion types and better test organization:

```lua
describe("Calculator", function()
  it("should add two positive numbers correctly", function()
    -- Multiple assertions of different types
    expect(add(2, 3)).to.equal(5)       -- Equality assertion
    expect(add(2, 3)).to.be.a("number") -- Type checking
    expect(add(0, 0)).to.equal(0)       -- Edge case
  end)
  
  it("should handle subtraction properly", function()
    expect(subtract(5, 3)).to.equal(2)
    expect(subtract(3, 5)).to.equal(-2)  -- Testing negative result
  end)
end)
```

### Level 3: Comprehensive Quality

At this level, add setup/teardown, edge cases, and context nesting:

```lua
describe("Calculator", function()
  local calculator = nil
  
  -- Setup and teardown
  before(function()
    calculator = Calculator.new()
  end)
  
  after(function()
    calculator = nil
  end)
  
  -- Context nesting
  describe("when performing addition", function()
    it("should add two numbers correctly", function()
      expect(calculator.add(2, 3)).to.equal(5)
      expect(calculator.add(0, 5)).to.equal(5)
      expect(calculator.add(-2, 2)).to.equal(0)  -- Edge case
    end)
  end)
  
  describe("when performing division", function()
    it("should divide numbers correctly", function()
      expect(calculator.divide(6, 2)).to.equal(3)
      expect(calculator.divide(5, 2)).to.equal(2.5)
    end)
    
    it("should handle division by zero", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return calculator.divide(5, 0)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("division by zero")
    end)
  end)
end)
```

### Level 4: Advanced Quality

At this level, include boundary testing, extensive mocking, and performance checks:

```lua
describe("UserService", function()
  local user_service, db_mock
  
  before(function()
    -- Create a mock database
    db_mock = firmo.mock("DatabaseClient")
    
    -- Configure the mock
    db_mock:when("get_user", "123").returns({ id = "123", name = "Test User" })
    db_mock:when("get_user", "999").returns(nil)
    
    -- Initialize service with mock
    user_service = UserService.new(db_mock)
  end)
  
  describe("when fetching users", function()
    it("should return user data for valid id", function()
      local user = user_service.get_user("123")
      
      expect(user).to.exist()
      expect(user.id).to.equal("123")
      expect(user.name).to.equal("Test User")
      
      -- Verify mock was called correctly
      expect(db_mock:called_with("get_user", "123")).to.be_truthy()
    end)
    
    it("should handle non-existent users", function()
      local user = user_service.get_user("999")
      
      expect(user).to_not.exist()
      expect(db_mock:called_with("get_user", "999")).to.be_truthy()
    end)
    
    -- Boundary testing
    it("should validate user id format", function()
      -- Test minimum length
      expect(user_service.is_valid_id("1")).to.equal(false)
      
      -- Test boundary case
      expect(user_service.is_valid_id("12")).to.equal(false)
      expect(user_service.is_valid_id("123")).to.equal(true)
      
      -- Test maximum length
      expect(user_service.is_valid_id("12345678901234567890")).to.equal(true)
      expect(user_service.is_valid_id("123456789012345678901")).to.equal(false)
    end)
    
    -- Performance testing
    it("should fetch users efficiently", function()
      local start_time = os.clock()
      user_service.get_user("123")
      local end_time = os.clock()
      
      expect(end_time - start_time).to.be_less_than(0.01)
    end)
  end)
end)
```

### Level 5: Complete Quality

At this level, add security testing, complete API contract testing, and comprehensive edge cases:

```lua
describe("AuthenticationService", function()
  local auth_service, user_db, logger_mock
  
  before(function()
    -- Set up mocks
    user_db = firmo.mock("UserDatabase")
    logger_mock = firmo.mock("Logger") 
    
    -- Configure mock behavior
    user_db:when("find_by_username", "test_user").returns({
      id = "123",
      username = "test_user",
      password_hash = "$2a$10$...", -- Bcrypt hash for "password123"
      roles = {"user"}
    })
    
    -- Initialize service with mocks
    auth_service = AuthenticationService.new(user_db, logger_mock)
  end)
  
  describe("when authenticating users", function()
    it("should authenticate valid credentials", function()
      local result = auth_service.authenticate("test_user", "password123")
      
      expect(result.success).to.be_truthy()
      expect(result.user.id).to.equal("123")
      expect(result.user.roles).to.include("user")
      expect(result.token).to.be.a("string")
      expect(#result.token).to.be_greater_than(20)
    end)
    
    it("should reject invalid credentials", function()
      local result = auth_service.authenticate("test_user", "wrong_password")
      
      expect(result.success).to.equal(false)
      expect(result.user).to_not.exist()
      expect(result.token).to_not.exist()
      expect(result.error).to.match("Invalid credentials")
      
      -- Verify proper logging of security events
      expect(logger_mock:called_with("warn", "Failed login attempt")).to.be_truthy()
    end)
    
    -- Security testing
    describe("security requirements", function()
      it("should prevent timing attacks", function()
        -- Measure timing for both valid and invalid username
        local start1 = os.clock()
        auth_service.authenticate("test_user", "wrong_password")
        local time1 = os.clock() - start1
        
        local start2 = os.clock()
        auth_service.authenticate("invalid_user", "wrong_password")
        local time2 = os.clock() - start2
        
        -- Timing should be similar regardless of whether user exists
        expect(math.abs(time1 - time2)).to.be_less_than(0.01)
      end)
      
      it("should rate limit authentication attempts", function()
        -- Try multiple failed logins
        for i = 1, 10 do
          auth_service.authenticate("test_user", "wrong_password" .. i)
        end
        
        -- Next attempt should be rate limited
        local result = auth_service.authenticate("test_user", "wrong_password")
        
        expect(result.success).to.equal(false)
        expect(result.error).to.match("rate limited")
        expect(logger_mock:called_with("warn", "Rate limit applied")).to.be_truthy()
      end)
      
      it("should sanitize inputs for SQL injection", function()
        -- Attempt SQL injection in username
        local result = auth_service.authenticate("admin' --", "anything")
        
        expect(result.success).to.equal(false)
        expect(result.error).to.match("Invalid input")
        expect(logger_mock:called_with("warn", "Potential SQL injection")).to.be_truthy()
      end)
    end)
  end)
end)
```

## Generating Quality Reports

### Basic Report Generation

To generate a quality report:

```lua
-- Generate an HTML report
firmo.generate_quality_report("html", "./quality-report.html")

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