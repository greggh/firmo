# Firmo Knowledge


## CRITICAL: Project Organization Rules



1. **Directory Structure**:
   - ALL implementation code goes in /lib
   - ALL tests go in /tests root directory
   - NEVER create test files in implementation directories
   - Follow architecture.md structure exactly
2. **Before Writing Code**:
   - Study architecture.md thoroughly
   - Review ALL existing code in target area
   - Check lib/tools/vendor for dependencies
   - Search for similar implementations
3. **Version 3 Coverage System**:
   - ALL v3 work MUST be in lib/coverage/v3/
   - Keep completely separate from existing system
   - Follow v3 structure in architecture.md
   - No v3 code in base coverage directory
   - NEVER modify original source files
   - ALWAYS use temp files for instrumentation
   - Use test_helper and temp_file modules for file management


### Implementation Boundaries



1. **Coverage v3 Directory (lib/coverage/v3/)**:
   - Complete rewrite/replacement allowed
   - No need to preserve existing v3 code
   - Implement new temp file-based approach here
   - Can restructure files as needed
2. **Core Utility Modules (lib/tools/)**:
   - Use existing functionality first
   - OK to add new generic functionality when needed
   - Example: Adding recursive file listing to filesystem module
   - Any additions must be:
     - Generally useful (not specific to one use case)
     - Well-tested
     - Properly documented
     - Consistent with module's design
3. **When to Modify Core Modules**:
   - When new functionality would be useful project-wide
   - When the addition is generic and reusable
   - When existing functions don't quite meet a common need
   - Example: Adding recursive file listing because many parts of the project need it
4. **When NOT to Modify Core Modules**:
   - Don't add special-case functionality
   - Don't modify existing behavior
   - Don't duplicate existing functionality
   - Don't add coverage-specific features to generic modules


### Implementation Strategy



- Build new functionality in v3 directory
- Use core modules for infrastructure
- Keep v3 changes isolated from rest of codebase
- Don't touch anything outside v3 directory
1. **Code Quality Requirements**:
   - NEVER simplify code just to make tests pass
   - NEVER implement workarounds or hacks
   - If tests fail, fix the underlying code properly
   - Tests verify code works correctly, not the other way around
   - Implementation must be robust and complete
   - No shortcuts or temporary solutions


## Available Tools and Modules


### Temporary File Management



- Use test_helper.create_temp_test_directory() for test files
- temp_file module handles automatic cleanup
- Files registered with temp_file are cleaned up after tests
- Use temp_file.register_file() for manual registration
- NEVER call cleanup functions directly in tests
- The test runner uses temp_file_integration.lua to track test contexts and clean up temp files automatically after each test completes


### Filesystem Operations



- fs module provides safe file operations
- Use fs.copy_file() for safe file copying
- Use fs.create_directory() for nested directories
- Use fs.write_file() for safe file writing
- Handle all fs operations with proper error checking


### Configuration System



- Use central_config for all settings
- NEVER create custom configuration systems
- NEVER hardcode paths or patterns
- NEVER remove existing config integration
- Use .firmo-config.lua for project-wide settings


## Error Handling in Tests


CRITICAL: When writing tests that expect errors:


1. ALWAYS use `{ expect_error = true }` flag in test definition:

   ```lua
   it("should fail gracefully", { expect_error = true }, function()
     -- Test code here
   end)
   ```


2. ALWAYS use `test_helper.with_error_capture()` to capture expected errors:

   ```lua
   local result, err = test_helper.with_error_capture(function()
     return function_that_should_fail()
   end)()
   expect(result).to_not.exist()
   expect(err).to.exist()
   expect(err.message).to.match("expected error message")
   ```


3. NEVER create workarounds to handle expected errors. The framework provides proper error handling mechanisms.
4. ALWAYS read error handling documentation and test files before implementing error handling.
5. Look for similar error handling patterns in existing tests.


## Project Overview



- Enhanced Lua testing framework with BDD-style nested test blocks
- Provides comprehensive testing capabilities including assertions, mocking, coverage analysis, quality analysis, benchmarking, code fixing, and documentation fixing (markdown).
- Currently in alpha state - not for production use unless helping with development


## Minimal Test Example



```lua
local firmo = require('firmo')
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
describe('Calculator', function()
  before(function()
    -- Setup runs before each test
  end)
  it('adds numbers correctly', function()
    expect(2 + 2).to.equal(4)
  end)
  it('handles errors properly', { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return divide(1, 0)
    end)()
    expect(err).to.exist()
    expect(err.message).to.match("divide by zero")
  end)
end)
```



## Critical Rules


### Configuration System



- ALWAYS use central_config module for settings
- NEVER create custom configuration systems
- NEVER hardcode paths or patterns
- NEVER remove existing config integration
- Use .firmo-config.lua for project-wide settings


### Special Case Code Policy



- NEVER add special case code for specific files/situations
- NO file-specific logic or hardcoded paths
- NO workarounds - fix root causes
- NO specialized handling for specific cases
- Solutions must be general purpose and work for all files


### Coverage Module Rules



- NEVER import coverage module in test files
- NEVER manually set coverage status
- NEVER create test-specific workarounds
- NEVER manipulate coverage data directly
- ALWAYS run tests properly via test.lua


## Essential Commands



- Run all tests: `lua test.lua tests/`
- Run specific test: `lua test.lua tests/reporting_test.lua`
- Run with pattern: `lua test.lua --pattern=coverage tests/`
- Run with coverage: `lua test.lua --coverage --format=html tests/`
- Run with coverage (JSON): `lua test.lua --coverage --format=json tests/`
- Run with coverage (LCOV): `lua test.lua --coverage --format=lcov tests/`
- Run with watch mode: `lua test.lua --watch tests/`


## JSDoc-Style Type Annotations


CRITICAL: Any code changes MUST include updates to affected JSDoc annotations.
Example:


```lua
---@class ModuleName
---@field function_name fun(param: type): return_type Description 
---@field another_function fun(param1: type, param2?: type): return_type|nil, error? Description
local M = {}
--- Description of what the function does
---@param name type Description of the parameter
---@param optional_param? type Description of the optional parameter
---@return type Description of what the function returns
function M.function_name(name, optional_param)
  -- Implementation
end
```



## Error Handling Diagnostic Patterns



```lua
-- pcall Pattern
---@diagnostic disable-next-line: unused-local
local ok, err = pcall(function()
  return some_operation()
end)
-- error_handler.try Pattern
---@diagnostic disable-next-line: unused-local
local success, result, err = error_handler.try(function()
  return some_operation()
end)
-- Table Access Without nil Check
---@diagnostic disable-next-line: need-check-nil
local value = table[key]
```



## Lua Compatibility



- ALWAYS use table unpacking compatibility:

  ```lua
  local unpack_table = table.unpack or unpack
  ```


- Use # operator for table length:

  ```lua
  local length = #my_table  -- Correct
  local length = table.getn(my_table)  -- Incorrect, deprecated
  ```

## Assertion Style Guide



```lua
-- CORRECT: firmo expect-style assertions
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
expect(value).to.be_truthy()
expect(value).to.match("pattern")
expect(fn).to.fail()
-- INCORRECT: busted-style assert assertions
assert.is_not_nil(value)         -- wrong
assert.equals(expected, actual)  -- wrong
```



## Extended Assertions



```lua
-- Collection assertions
expect("hello").to.have_length(5)
expect({1, 2, 3}).to.have_length(3)
expect({}).to.be.empty()
-- Numeric assertions
expect(5).to.be.positive()
expect(-5).to.be.negative()
expect(10).to.be.integer()
-- String assertions
expect("HELLO").to.be.uppercase()
expect("hello").to.be.lowercase()
-- Object assertions
expect({name = "John"}).to.have_property("name")
expect({name = "John"}).to.have_property("name", "John")
```



## Error Testing Best Practices



1. ALWAYS use expect_error flag when the test expects and error and that error is a passing test:

   ```lua
   it("test description", { expect_error = true }, function()
   local result, err = test_helper.with_error_capture(function()
    return function_that_throws()
   end)()
   expect(err).to.exist()
   expect(err.message).to.match("pattern")
   end)
   ```


2. ALWAYS use test_helper.with_error_capture() when the test expects and error and that error is a passing test.
3. Be flexible with error categories
4. Use pattern matching for messages
5. Test for existence first
6. Handle both error patterns (nil,error and false)
7. Clean up resources properly
8. Document expected error behavior


## Documentation Links



- Tasks: `/home/gregg/Projects/lua-library/firmo/docs/firmo/plan.md`
- Architecture: `/home/gregg/Projects/lua-library/firmo/docs/firmo/architecture.md`


## Test Development and Debugging


### Test-Driven Development (TDD)



- Write tests before implementation
- Run tests frequently
- Keep test cases focused
- Add edge cases separately


### CRITICAL: Error Resolution Process



1. ALWAYS read complete test output
2. Find exact ERROR line and message
3. Track error to specific location
4. Fix reported error, not assumed issues
5. Verify error is fixed before moving on
6. Never assume error cause without evidence


### Common Error Resolution Mistakes



- Assuming error cause without reading message
- Fixing assumed issues instead of actual error
- Moving on before verifying error is fixed
- Making multiple changes before re-running tests
- Ignoring exact error location and line numbers


### Test Debugging Best Practices



1. Run failing test in isolation:

   ```lua
   lua test.lua tests/specific_test.lua
   ```


2. Enable debug logging if needed:

   ```lua
   local logger = logging.get_logger("test")
   logger.set_level(logging.LEVELS.DEBUG)
   ```


3. Add debug assertions:

   ```lua
   it("should handle error case", function()
     expect(actual_value).to.exist() -- Value should exist here
     expect(actual_value).to.equal(expected) -- Values should match
   end)
   ```


4. Check error location:

   ```lua
   -- In test file
   local result, err = test_helper.with_error_capture(function()
     return problematic_function()
   end)()

   -- Error will show exact line number and message
   expect(err).to.exist()
   expect(err.message).to.match("expected error")
   ```

## Coverage Module Requirements


### Core Functionality (Debug Hook Based)

-   ALWAYS ensure proper debug hook lifecycle management (`init`, `shutdown`, `pause`, `resume`).
-   The system tracks execution counts (`lib/coverage`). Assertions mark lines as 'covered' (`lib/assertion`). Ensure reporting reflects this distinction if relevant.
-   Data processing/normalization for reporting should be maintained.
-   Maintain backward compatibility where feasible.
-   ALWAYS preserve existing error handling integration (`error_handler`).

### Considerations for Debug Hook Coverage

1.  **Hook Management:** Ensure `debug.sethook` is correctly installed and removed by `coverage.init()` and `coverage.shutdown()`.
2.  **File Access:** The hook needs to access original source files to map execution lines. Ensure correct paths and permissions.
3.  **Coroutine Handling:** The LuaCov integration handles standard coroutines, but be mindful of complex async patterns.
4.  **Performance:** Debug hooks add overhead. Use `coverage.pause()`/`resume()` for non-relevant sections if performance is critical. Configure `savestepsize` appropriately.
5.  **Configuration:** Use `central_config` (`coverage.include`, `coverage.exclude`, etc.) to control which files are tracked.

### Available Tools



1. test_helper provides:
   - create_temp_test_directory()
   - register_temp_file()
   - register_temp_directory()
   - Automatic cleanup
2. temp_file provides:
   - File registration
   - Directory registration
   - Test context management
   - Automatic cleanup
3. filesystem provides:
   - Safe file operations
   - Directory management
   - Path manipulation


## Code Assessment and Recovery


### Component Assessment Process



1. **Read All Related Files**:
   - Read implementation files
   - Read test files
   - Read interface files (init.lua)
   - Check for missing files
2. **Identify Working Components**:
   - Look for complete implementations
   - Check for proper error handling
   - Verify test coverage
   - Note dependencies on other modules
3. **Identify Broken Components**:
   - Check for syntax errors
   - Look for incomplete implementations
   - Find missing functionality
   - Note incorrect usage of dependencies
4. **Document Current State**:
   - List working components
   - List broken/incomplete components
   - Note missing tests
   - Identify critical issues


### Recovery Strategy



1. **Fix Critical Issues First**:
   - Fix syntax errors immediately
   - Fix broken imports/requires
   - Fix incorrect API usage
   - Fix type errors
2. **Test-First Recovery**:
   - Create missing test files first
   - Write tests for broken functionality
   - Use tests to verify fixes
   - Add edge case tests
3. **Dependency Order**:
   - Fix foundation modules first (e.g., sourcemap)
   - Then fix dependent modules
   - Then fix integration points
   - Then fix high-level modules
4. **Preserve Working Code**:
   - Don't modify working components
   - Keep existing tests that pass
   - Keep correct error handling
   - Keep proper module structure


### Common Recovery Mistakes



1. **Rushing to Fix**:
   - Fixing without full assessment
   - Fixing symptoms not causes
   - Breaking working components
   - Missing critical issues
2. **Poor Planning**:
   - Wrong fix order
   - Missing dependencies
   - Incomplete testing
   - Inconsistent fixes
3. **Incomplete Assessment**:
   - Missing broken components
   - Missing dependencies
   - Missing test gaps
   - Missing critical issues


### Recovery Best Practices



1. **Document Everything**:
   - List all issues found
   - Track fix progress
   - Note test status
   - Record dependencies
2. **Test Everything**:
   - Write tests first
   - Test each fix
   - Test integration
   - Test edge cases
3. **Review Everything**:
   - Check all related files
   - Verify all fixes
   - Validate all tests
   - Confirm all functionality


## CRITICAL: Code Reuse and Existing Modules


### Before Writing ANY Code



1. **ALWAYS Check Existing Modules First**:
   - Search ALL core modules for needed functionality
   - Read module documentation thoroughly
   - Look for similar implementations
   - NEVER write new code for functionality that exists
2. **Core Module Examples**:
   - Path operations: Use `fs.normalize_path`, `fs.join_paths`
   - File operations: Use `fs.read_file`, `fs.write_file`
   - Error handling: Use `error_handler` patterns
   - Logging: Use `logging` module
   - Testing: Use `test_helper` functions
3. **Common Mistakes to Avoid**:
   - Writing your own path normalization (use fs.normalize_path)
   - Writing your own file I/O (use fs module)
   - Creating new error patterns (use error_handler)
   - Writing your own test helpers (use test_helper)
4. **When You Find Existing Functionality**:
   - Study how it's used in other parts of codebase
   - Copy existing usage patterns exactly
   - Keep consistent with existing code
   - Document which module/function you're using
5. **If No Existing Functionality**:
   - Document your search for existing code
   - Explain why new code is needed
   - Consider adding to core modules instead
   - Get approval before writing new implementation
