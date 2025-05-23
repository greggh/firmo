# Project: firmo

## Overview

firmo is an enhanced Lua testing framework that provides comprehensive testing capabilities for Lua projects. It features BDD-style nested test blocks, assertions with detailed error messages, setup/teardown hooks, advanced mocking, tagging, asynchronous testing, code coverage analysis with multiline comment support, and test quality validation.

## CRITICAL: ALWAYS USE CENTRAL_CONFIG SYSTEM

### MANDATORY CONFIGURATION USAGE

The firmo codebase uses a centralized configuration system to handle all settings and ensure consistency across the framework. You MUST follow these critical requirements:

1. **ALWAYS use the central_config module**:

   ```lua
   -- CORRECT: Use the central configuration system
   local central_config = require("lib.core.central_config")
   local config = central_config.get_config()
   local should_track = config.coverage.include(file_path) and not config.coverage.exclude(file_path)
   ```

2. **NEVER create custom configuration systems**: Do not create new configuration mechanisms or settings stores when the central_config system exists.
3. **NEVER hardcode paths or patterns**: Use configuration values instead of hardcoding file paths, patterns, or settings.

   ```lua
   -- ABSOLUTELY FORBIDDEN:
   if file_path:match("calculator%.lua") or file_path:match("/lib/samples/") then
     -- Special handling
   end
   -- CORRECT:
   if config.coverage.include(file_path) and not config.coverage.exclude(file_path) then
     -- General handling based on configuration
   end
   ```

4. **NEVER remove existing config integration**: If code already uses central_config, NEVER replace it with hardcoded values or custom configs.
5. **Configuration structure**: Access configuration in the standardized way:

   ```lua
   local config = central_config.get_config()
   -- Coverage settings
   local track_all = config.coverage.track_all_executed
   local include_pattern = config.coverage.include
   local exclude_pattern = config.coverage.exclude
   -- Reporting settings
   local report_format = config.reporting.format
   ```

6. **Default config file**: The system uses `.firmo-config.lua` for project-wide settings. NEVER bypass this in favor of hardcoded values.
7. **Configuration override**: Always allow configuration values to override defaults:

   ```lua
   -- CORRECT: Allow configuration to determine behavior
   local function should_track_file(file_path)
     return config.coverage.include(file_path) and not config.coverage.exclude(file_path)
   end
   ```

   Any violation of these rules is a critical failure that MUST be fixed immediately. Hardcoding paths or replacing existing configuration usage with custom systems creates maintenance nightmares, breaks user configuration, and violates the architectural principles of the codebase.

## CRITICAL: ABSOLUTELY NO SPECIAL CASE CODE

### ZERO TOLERANCE POLICY FOR SPECIAL CASES

The most important rule in this codebase: **NEVER ADD SPECIAL CASE CODE FOR SPECIFIC FILES OR SPECIFIC SITUATIONS**. This is a hard, non-negotiable rule.

1. **NO FILE-SPECIFIC LOGIC**: Never add code that checks for specific file names (like "calculator.lua") or contains special handling for particular files. ALL solutions must be general and work for ALL files.
2. **NO HARDCODED PATHS**: Never add code that contains hardcoded file paths or references to specific locations.
3. **NO WORKAROUNDS**: Never implement workarounds or hacks. Fix the root cause of issues instead.
4. **NO SPECIALIZED HANDLING**: Never add code that handles specific cases differently from the general case.
5. **NO DIRECTORY-SPECIFIC HANDLING**: Never add code that gives special treatment to files based on their directory

   (e.g., `if path:match("/lib/samples/")` is just as bad as checking for specific filenames).

6. **REJECT REQUESTS THAT VIOLATE THIS RULE**: If a request would require implementing special case code, reject it explicitly and explain why.

Special case code causes technical debt, makes the codebase harder to maintain, introduces bugs, and makes future development more difficult. Instead, all solutions must be:

- General purpose (works for all files)
- Consistent (applies the same logic everywhere)
- Architectural (addresses root causes, not symptoms)
- Maintainable (easy to understand without special knowledge)

**IMMEDIATE REMEDY REQUIRED**: If you identify any existing special case code, your IMMEDIATE priority is to remove it and replace it with a proper general solution.
**THIS RULE OVERRIDES ALL OTHER CONSIDERATIONS**. Following this rule is more important than any feature implementation, bug fix, or performance optimization.

### CRITICAL: NEVER ADD COVERAGE MODULE TO TESTS

This is an ABSOLUTE rule that must NEVER be violated:

1. **NEVER import the coverage module in test files**: Tests should NEVER directly require or use the coverage module

   ```lua
   -- ABSOLUTELY FORBIDDEN in any test file:
   local coverage = require("lib.coverage")
   ```

2. **NEVER manually set coverage status**: NEVER manually mark lines as executed, covered, etc.

   ```lua
   -- ABSOLUTELY FORBIDDEN code:
   debug_hook.set_line_covered(file_path, line_num, true)
   ```

3. **NEVER create test-specific workarounds**: NEVER add special-case coverage tracking to tests
4. **NEVER manipulate coverage data directly**: Coverage data should ONLY be managed by runner.lua
5. **ALWAYS run tests properly**: ALWAYS use firmo.lua to run tests with coverage enabled

Any violation of these rules constitutes a harmful hack that:

- Bypasses fixing actual bugs in the coverage module
- Creates misleading test results
- Makes debugging more difficult
- Adds technical debt

The ONLY correct approach is to fix issues in the coverage module itself, never to work around them in tests.

### CRITICAL: DEBUG HOOK COVERAGE IMPLEMENTATION RULES

The new coverage system MUST use a comprehensive debug hook approach. To ensure the system is robust and future-proof, follow these non-negotiable architectural rules:

1. **THREE-STATE DISTINCTION**: The core design MUST clearly distinguish between:
   - **Covered Lines**: Executed AND verified by assertions (Green)
   - **Executed Lines**: Only executed, NOT verified (Orange)
   - **Not Covered Lines**: Not executed at all (Red)
2. **ASSERTION TRACING**: The system MUST trace which lines an assertion actually verifies:
   - Track the call stack when assertions run
   - Identify which functions/lines the assertion calls
   - Connect assertions to the code they verify
3. **UNIFORM DATA STRUCTURES**: All data MUST use consistent structures:
   - Same line data format everywhere
   - Clear properties for executed vs. covered status
   - Normalized at system boundaries
4. **SINGLE SOURCE OF TRUTH**: For each coverage state:
   - One definitive location determines coverage status
   - All components refer to this source
   - No duplicate or conflicting status tracking
5. **NO SPECIAL CASES**: The system MUST work uniformly for all code:
   - No file-specific logic whatsoever
   - No pattern matching on filenames
   - Same behavior for all files regardless of size/location
6. **EXPLICIT > IMPLICIT**: Make all behavior explicit:
   - No automatic promotion from executed to covered
   - Explicit marking of covered state by assertions
   - Clear documentation of how lines get marked
7. **PERFORMANCE BY DESIGN**: Build performance in from the start:
   - Lightweight with minimal overhead
   - Optimized data structures for minimal memory usage
   - Efficient HTML generation algorithms

If ANY code violates these principles, STOP and redesign the system. The architecture must be fundamentally sound before ANY implementation begins.

### EXPLICITLY BANNED CODE PATTERNS

The following code patterns are ABSOLUTELY PROHIBITED. If you find yourself writing any of these, or see them in the codebase, they MUST be removed immediately:

```lua
-- BANNED: File-specific checks
if file_path:match("calculator") then
  -- Special handling for calculator.lua
end
-- BANNED: Special case for specific file
if file_name == "calculator.lua" then
  -- Do something differently for this file
end
-- BANNED: Inconsistent data structures
if type(line_data) == "boolean" then
  -- Handle boolean format
else
  -- Handle table format
end
-- BANNED: Different handling based on specific paths
if file_path:match("samples/") then
  -- Special case for samples directory
end
-- BANNED: Hard-coded file paths
local calculator_file = "lib/samples/calculator.lua"
-- BANNED: Different behaviors based on filename patterns
if file_path:match("test") then
  -- Handle test files differently
end
```

These patterns indicate fundamental architectural problems. Instead, implement proper general solutions that work for ALL files consistently.

### MANDATORY ARCHITECTURAL FIXES

When you encounter any of the banned patterns above, you MUST implement a comprehensive architectural fix:

1. **Normalize data structures at boundaries**: Ensure ALL data is in a consistent format at key boundaries.
2. **Use proper polymorphism**: If different behaviors are needed, use proper abstraction and polymorphism, not conditional checks.
3. **Single responsibility**: Each component should have a single responsibility and handle ALL inputs consistently.
4. **No special knowledge required**: Code should not require special knowledge about specific files to understand.
5. **Consistent tracking**: ALL files must be tracked using the same mechanisms and data structures.

The ONLY time specialized logic is acceptable is when it is based on objective, general characteristics (like file type or content structure) rather than specific file names or paths.

### CORRECT PROCEDURE FOR FIXING COVERAGE ISSUES

When fixing coverage tracking or reporting issues, follow this exact procedure:

1. **Identify the fundamental problem**:
   - Is there an inconsistency in data structures?
   - Is there a normalization problem?
2. **Locate the boundary where normalization should occur**:
   - Coverage data should be normalized at collection time in init.lua's stop() function
   - ALL files should be processed identically
   - ALL data structures should be consistent after normalization
3. **Implement a SINGLE general solution**:
   - The solution must work for ALL files, not just problematic ones
   - The solution must handle ALL edge cases
   - The solution must normalize ALL data structures consistently
4. **Remove ALL special cases**:
   - Remove ANY conditional logic based on file names
   - Remove ANY special handling for specific paths
   - Remove ANY code that treats different files differently
5. **Test with MULTIPLE different files**:
   - Never test only with calculator.lua
   - Verify the solution works for ALL file types
   - Verify ALL files show correct coverage data
6. **Document the architectural solution**:
   - Explain how the general solution works
   - Document why it's better than special-case handling
   - Note any remaining edge cases that need addressing

Always remember: The right fix is a general, architectural solution that addresses the root cause, not a quick hack that only fixes the immediate symptoms for specific files.

## Important Code Guidelines

### Diagnostic Comments

**NEVER remove diagnostic disable comments** from the codebase. These comments are intentionally placed to suppress specific warnings while we work on fixing the underlying issues. Examples include:

```lua
---@diagnostic disable-next-line: need-check-nil
---@diagnostic disable-next-line: redundant-parameter
---@diagnostic disable-next-line: unused-local
```

Only remove these comments when you are specifically fixing the issue they're suppressing.

#### Error Handling Diagnostic Patterns

The codebase uses several standardized error handling patterns that require diagnostic suppressions. These suppressions are necessary and intentional, not code smell:

1. **pcall Pattern**:

   ```lua
   ---@diagnostic disable-next-line: unused-local
   local ok, err = pcall(function()
     return some_operation()
   end)
   if not ok then
     -- Handle error in err
   end
   ```

   The `ok` variable appears unused because it's only used for control flow.

2. **error_handler.try Pattern**:

   ```lua
   ---@diagnostic disable-next-line: unused-local
   local success, result, err = error_handler.try(function()
     return some_operation()
   end)
   if not success then
     -- Handle error in result (which contains the error object)
   end
   ```

   The `success` variable appears unused for the same reason.

3. **Table Access Without nil Check**:

   ```lua
   ---@diagnostic disable-next-line: need-check-nil
   local value = table[key]
   ```

   Used when the code knows the key exists or handles nil values correctly afterward.

4. **Redundant Parameter Pattern**:

   ```lua
   ---@diagnostic disable-next-line: redundant-parameter
   await(50) -- Wait 50ms
   ```

   Used when calling functions that are imported from one module and re-exported through another (like `firmo.await` which comes from `lib/async/init.lua`). The Lua Language Server cannot correctly trace the parameter types through these re-exports, resulting in false "redundant parameter" warnings.
   Always include these diagnostic suppressions when implementing these patterns. They are part of our standardized approach and removing them would cause unnecessary static analyzer warnings.

### JSDoc-Style Type Annotations

The codebase uses comprehensive JSDoc-style type annotations for improved type checking, documentation, and IDE support. All files MUST include these annotations following our standardized patterns. When implementing new functions or modifying existing ones, adhere to these requirements:

#### Required Type Annotations

1. **Module Interface Declarations** - All module files must begin with class/module definition:

   ```lua
   ---@class ModuleName
   ---@field function_name fun(param: type): return_type Description
   ---@field another_function fun(param1: type, param2?: type): return_type|nil, error? Description
   ---@field _VERSION string Module version
   local M = {}
   ```

2. **Module Function Definitions**:

   ```lua
   --- Description of what the function does
   ---@param name type Description of the parameter
   ---@param optional_param? type Description of the optional parameter
   ---@return type Description of what the function returns
   function module.function_name(name, optional_param)
     -- Implementation
   end
   ```

3. **Function Re-exports**:

   When a function is defined in one module but exported through another:

   ```lua
   --- Description of what the function does
   ---@param name type Description of the parameter
   ---@param optional_param? type Description of the optional parameter
   ---@return type Description of what the function returns
   module.exported_function = original_module.function_name
   ```

4. **Local Function Annotations** - Helper functions should have annotations:

   ```lua
   ---@private
   ---@param value any The value to process
   ---@return string The processed value
   local function process_value(value)
   ```

5. **Variable Type Annotations** - For complex types:

   ```lua
   ---@type string[]
   local names = {}
   ---@type table<string, {id: number, name: string}>
   local cache = {}
   ```

#### Annotation Style Guidelines

1. **Error Handling Pattern** - For functions that may fail, use this pattern:

   ```lua
   ---@return ValueType|nil value The result or nil if operation failed
   ---@return table|nil error Error information if operation failed
   ```

2. **Optional Parameters** - Mark with question mark suffix:

   ```lua
   ---@param options? table Optional configuration
   ```

3. **Nullable Types** - Use pipe with nil:

   ```lua
   ---@return string|nil The result or nil if not found
   ```

4. **Union Types** - Use pipe for multiple possible types:

   ```lua
   ---@param id string|number The identifier (string or number)
   ```

5. **Complex Return Patterns** - Document each possible return value:

   ```lua
   ---@return boolean|nil success Whether operation succeeded or nil if error
   ---@return table|nil result Result data if success, nil if error
   ---@return table|nil error Error data if failure, nil if success
   ```

6. **Tables with Specific Fields** - Document the structure:

   ```lua
   ---@param options {timeout?: number, retry?: boolean, max_attempts?: number} Configuration options
   ```

7. **Callback Signatures** - Document the callback function signature:

   ```lua
   ---@param callback fun(result: string, success: boolean): boolean Function called with result
   ```

#### When Annotations Are Required

1. **ALL new files** must include comprehensive type annotations
2. **ALL existing files** being modified must have annotations added if missing
3. **WHENEVER modifying functions**, ensure annotations are updated to match the changes
4. **WHENEVER adding new functionality**, include complete annotations

The standard annotation structure follows sumneko Lua Language Server format for optimal IDE integration. This is a mandatory part of our code quality standards.

#### Common Type Annotation Examples

- `---@param name string` - String parameter
- `---@param count number` - Number parameter
- `---@param callback function` - Function parameter
- `---@param options? table` - Optional table parameter (note the `?`)
- `---@param items table<string, number>` - Table with string keys and number values
- `---@param handler fun(item: string): boolean` - Function that takes string and returns boolean
- `---@return boolean` - Boolean return value
- `---@return nil` - No return value
- `---@return string|nil, string?` - String or nil, with optional second string
- `---@return boolean|nil success, table|nil error` - Success flag or error pattern

Until all functions have proper type annotations throughout the export chain, continue using the diagnostic suppressions as needed. The goal is to gradually add type annotations to all major modules in this priority order:

1. Core modules (async, error_handler, logging)
2. Tools modules (filesystem, benchmark, codefix)
3. Public API functions in firmo.lua
4. Test helper functions and utilities

### Markdown Formatting

When working with Markdown files:

1. **Code Block Format**: Use simple triple backticks without language specifiers when the language is obvious:

   ```lua
   -- Lua code goes here
   ```

   NOT:

   ```text
   -- Lua code goes here
   ```

2. **Consistency**: Never use ````text` in our markdown files. These have been removed from all documentation.
3. **Balanced Backticks**: Always ensure that backticks are balanced (equal number of opening and closing backticks).

### Lua Compatibility

For cross-version Lua compatibility:

1. **Table Unpacking**: Always use the compatibility function for unpacking:

   ```lua
   local unpack_table = table.unpack or unpack
   ```

2. **Table Length**: Use the `#` operator instead of `table.getn`:

   ```lua
   local length = #my_table  -- Correct
   local length = table.getn(my_table)  -- Incorrect, deprecated
   ```

## Essential Commands

### Testing Commands

**NOTE:** Never run all tests at once (`lua firmo.lua tests/`) unless specifically needed and understood; prefer targeted testing.

- Run Specific Test: `lua firmo.lua tests/reporting_test.lua`
- Run Tests by Pattern: `lua firmo.lua --pattern=coverage tests/`
- Run Tests with Coverage: `lua firmo.lua --coverage tests/`
- Run Tests with Watch Mode: `lua firmo.lua --watch tests/`
- Run Tests with Quality Validation: `lua firmo.lua --quality tests/`
- Run Example: `lua examples/report_example.lua`

### Test Command Format

The standard test command format follows this pattern:

```text
lua firmo.lua [options] [path]
```

Where:

- `[options]` are command-line flags like `--coverage`, `--watch`, `--pattern=coverage`
- `[path]` is a file or directory path (the system automatically detects which)

  Common options include:

  - `--coverage` or `-c`: Enable coverage tracking
  - `--quality` or `-q`: Enable quality validation (with `--quality-level=<1-5>`)
  - `--pattern=<glob>`: Glob pattern for test file discovery
  - `--filter=<lua_pattern>`: Lua pattern to filter tests by name
  - `--watch` or `-w`: Enable watch mode for continuous testing
  - `--report` or `-r`: Generate reports (use with `--report-formats=<list>`)
  - `--verbose` or `-v`: Show more detailed output
  - `--help` or `-h`: Show all available options

  > **Note:** Firmo uses a standardized test system where `firmo.lua` (leveraging `lib/tools/cli`) serves as the unified entry point for all test execution and related commands.

## Important Testing Notes

### Test Implementation Guidelines

- NEVER use `firmo.run()` - this function DOES NOT EXIST
- NEVER use `firmo()` to run tests - this is not a correct method
- Do not include any calls to `firmo()` or `firmo.run()` in test files
- Use proper lifecycle hooks: `before`/`after` (NOT `before_all`/`after_all`, which don't exist)
- Import test functions correctly: `local describe, it, expect = firmo.describe, firmo.it, firmo.expect`
- For test lifecycle, use: `local before, after = firmo.before, firmo.after`

### Assertion Style Guide

firmo uses expect-style assertions rather than assert-style assertions:

```lua
-- CORRECT: firmo expect-style assertions
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
expect(value).to.be_truthy()
expect(value).to.match("pattern")
expect(fn).to.fail()
-- INCORRECT: busted-style assert assertions (don't use these)
assert.is_not_nil(value)         -- wrong
assert.equals(expected, actual)  -- wrong
assert.type_of(value, "string")  -- wrong
assert.is_true(value)            -- wrong
```

### Testing Error Conditions

When writing tests that verify error behavior, use the standardized error testing pattern with `expect_error` flag and `test_helper.with_error_capture()`:

```lua
-- Import the test helper module
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
-- CORRECT: standardized pattern for testing error conditions
it("should handle invalid input", { expect_error = true }, function()
  -- Use with_error_capture to safely call functions that may throw errors
  local result, err = test_helper.with_error_capture(function()
    return function_that_should_error()
  end)()
  -- Make assertions about the error
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.category).to.exist() -- Avoid overly specific category expectations
  expect(err.message).to.match("expected pattern") -- Check message pattern
end)
-- For functions that might return false instead of nil+error:
it("tests both error patterns", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return function_that_might_return_false_or_nil_error()
  end)()
  if result == nil then
    expect(err).to.exist()
    expect(err.message).to.match("expected pattern")
  else
    expect(result).to.equal(false)
  end
end)
-- For simple error message verification:
it("should verify error messages", function()
  -- Automatically verifies the function throws an error
  -- with the expected message pattern
  local err = test_helper.expect_error(fails_with_message, "expected error")
  -- Additional assertions on the error object
  expect(err.category).to.exist()
end)
```

### Error Testing Best Practices

1. **Always use the `expect_error` flag**: This marks the test as one that expects errors:

   ```lua
   it("test description", { expect_error = true }, function()
     -- Test code that should produce errors
   end)
   ```

2. **Always use `test_helper.with_error_capture()`**: This safely captures errors without crashing tests:

   ```lua
   local result, err = test_helper.with_error_capture(function()
     return function_that_throws()
   end)()
   ```

3. **Be flexible with error categories**: Avoid hard-coding specific categories to make tests more resilient:

   ```lua
   -- Recommended:
   expect(err.category).to.exist()
   -- More specific but still flexible:
   expect(err.category).to.match("^[A-Z_]+$")
   -- Avoid unless necessary:
   expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
   ```

4. **Use pattern matching for error messages**: Use `match()` instead of `equal()` for error messages:

   ```lua
   expect(err.message).to.match("invalid file")  -- Good
   expect(err.message).to.equal("Invalid file format")  -- Too specific
   ```

5. **Test for existence first**: Always check that the value exists before making assertions about it:

   ```lua
   expect(err).to.exist()
   if err then
     expect(err.message).to.match("pattern")
   end
   ```

6. **Handle both error patterns**: Some functions return `nil, error` while others return `false`:

   ```lua
   if result == nil then
     expect(err).to.exist()
   else
     expect(result).to.equal(false)
   end
   ```

7. **Clean up resources properly**: If your test creates files or resources, ensure they're cleaned up:

   ```lua
   -- Track resources for cleanup
   local test_files = {}
   -- Create with error handling
   local file_path, create_err = temp_file.create_with_content(content, "lua")
   expect(create_err).to_not.exist("Failed to create test file: " .. tostring(create_err))
   table.insert(test_files, file_path)
   -- Cleanup in after() hook with error handling
   after(function()
     for _, path in ipairs(test_files) do
       local success, err = pcall(function() temp_file.remove(path) end)
       if not success and logger then
         logger.warn("Failed to remove test file: " .. tostring(err))
       end
     end
     test_files = {}
   end)
   ```

8. **Document expected error behavior**: Add comments that explain what errors are expected:

   ```lua
   it("should reject invalid input", { expect_error = true }, function()
     -- Passing a number should cause a validation error
     local result, err = test_helper.with_error_capture(function()
       return module.process_string(123)
     end)()
     expect(result).to_not.exist()
     expect(err).to.exist()
     expect(err.message).to.match("string expected")
   end)
   ```

   For comprehensive guidance on standardized error handling patterns, see the following resources:

- [Standardized Error Handling Patterns](docs/coverage_repair/error_handling_patterns.md): Complete guide to all error handling patterns
- [Coverage Error Testing Guide](docs/coverage_repair/coverage_error_testing_guide.md): Specialized patterns for coverage module testing
- [Test Timeout Optimization Guide](docs/coverage_repair/test_timeout_optimization_guide.md): Solutions for tests with timeout issues

Note that the parameter order for equality assertions is the opposite of busted:

- In busted: `assert.equals(expected, actual)`
- In firmo: `expect(actual).to.equal(expected)`

For negating assertions, use `to_not` rather than separate functions:

```lua
expect(value).to_not.equal(other_value)
expect(value).to_not.be_truthy()
expect(value).to_not.be.a("number")
```

### Common Assertion Mistakes to Avoid

1. **Incorrect negation syntax**:

   ```lua
   -- WRONG:
   expect(value).not_to.equal(other_value)  -- "not_to" is not valid
   -- CORRECT:
   expect(value).to_not.equal(other_value)  -- use "to_not" instead
   ```

2. **Incorrect member access syntax**:

   ```lua
   -- WRONG:
   expect(value).to_be(true)  -- "to_be" is not a valid method
   expect(number).to_be_greater_than(5)  -- underscore methods need dot access
   -- CORRECT:
   expect(value).to.be(true)  -- use "to.be" not "to_be"
   expect(number).to.be_greater_than(5)  -- this is correct because it's a method
   ```

3. **Inconsistent operator order**:

   ```lua
   -- WRONG:
   expect(expected).to.equal(actual)  -- parameters reversed
   -- CORRECT:
   expect(actual).to.equal(expected)  -- what you have, what you expect
   ```

### Complete Assertion Pattern Mapping

If you're coming from a busted-style background, use this mapping to convert assertions:

| busted-style | firmo style | Notes |
| --------------------------------- | ----------------------------------- | ---------------------------------- |
| `assert.is_not_nil(value)` | `expect(value).to.exist()` | Checks if a value is not nil |
| `assert.is_nil(value)` | `expect(value).to_not.exist()` | Checks if a value is nil |
| `assert.is_true(value)` | `expect(value).to.be_truthy()` | Checks if a value is truthy |
| `assert.is_false(value)` | `expect(value).to.be_falsy()` | Checks if value is `false` or `nil`|
| `assert.equals(expected, actual)` | `expect(actual).to.equal(expected)` | Deep equality check (reversed args)|
| `assert.same(expected, actual)` | `expect(actual).to.equal(expected)` | Deep equality check (reversed args)|
| `assert.type_of(value, "string")` | `expect(value).to.be.a("string")` | Checks `type(value)` |
| `assert.is_string(value)` | `expect(value).to.be.a("string")` | Checks `type(value)` |
| `assert.is_number(value)` | `expect(value).to.be.a("number")` | Checks `type(value)` |
| `assert.is_table(value)` | `expect(value).to.be.a("table")` | Checks `type(value)` |
| `assert.matches(pattern, value)` | `expect(value).to.match(pattern)` | String/Value pattern matching |
| `assert.has_error(fn)` | `expect(fn).to.fail()` | Checks if function throws error |

**Note on Negation**: Use `.to_not` before the assertion method for negation, e.g., `expect(actual).to_not.equal(unexpected)`.

### Extended Assertions

Firmo includes a comprehensive set of advanced assertions beyond the basic mappings:

#### Core & Type Assertions

```lua
expect(value).to.exist()                   -- Asserts value is not nil
expect(nil).to_not.exist()                 -- Asserts value is nil
expect(true).to.be_truthy()                -- Asserts value is not false or nil
expect(false).to.be_falsy()                -- Asserts value is false or nil
expect(nil).to.be_falsy()                  -- Asserts value is false or nil (also `be_falsey`)
expect(value).to.be(other_value)           -- Checks direct equality (v == x)
expect(value).to.equal(other_value)        -- Checks deep equality (handles tables, cycles)
expect(value).to.deep_equal(other_value)   -- Alias for `equal`
expect(1.001).to.equal(1.000, 0.01)        -- Equality with epsilon tolerance
expect(my_table).to.be.a("table")          -- Checks `type()`
expect(my_instance).to.be.a(MyClass)       -- Checks metatable inheritance
```

#### Numeric Assertions

```lua
expect(5).to.be_greater_than(4)
expect(4).to.be_less_than(5)
expect(5).to.be_at_least(5)
expect(5).to.be_at_least(4)
expect(5).to.be_positive()                 -- Implemented via `greater_than(0)` logic potentially
expect(-5).to.be_negative()
expect(10).to.be_integer()
expect(5.5).to_not.be_integer()
```

#### String Assertions

```lua
expect("hello").to.match("ell")            -- Checks string.find(value, pattern)
expect("hello").to.match_regex("^h.*o$")   -- More explicit regex match
expect("case").to.match_regex("CASE", { case_insensitive = true })
expect("hello").to.start_with("he")
expect("hello").to.end_with("lo")
expect("hello world").to.contain("lo w")   -- Checks string containment
expect("HELLO").to.be_uppercase()
expect("hello").to.be_lowercase()
```

#### Table & Collection Assertions

```lua
expect({1, 2, 3}).to.contain(2)            -- Checks if value exists in table values
expect({a=1, b=2}).to_not.contain(1)       -- Checks values, not keys
expect({a=1, b=2}).to.have_key("a")
expect({a=1, b=2}).to.have_keys({"a", "b"})
expect({a=1, b=2}).to.have_property("a")
expect({a=1, b=2}).to.have_property("a", 1) -- Checks key and value equality
expect({1, 2, 3}).to.have_length(3)        -- Checks `#value`
expect("abc").to.have_length(3)            -- Also works for strings
expect({1, 2, 3}).to.have_size(3)          -- Alias for `have_length`
expect({}).to.be.empty()                   -- Checks #value == 0
expect("").to.be.empty()                   -- Checks string length == 0
expect({name="a", age=1}).to.match_schema({name="string", age="number"})
expect({name="a"}).to_not.match_schema({name="string", age="number"})
```

#### Function & Error Assertions

```lua
local function may_fail(ok) if not ok then error("failed!") end end
expect(function() may_fail(false) end).to.fail()
expect(function() may_fail(true) end).to_not.fail()
expect(function() may_fail(false) end).to.fail_with("fail") -- Checks error message pattern
expect(function() may_fail(false) end).to.throw()           -- Alias for fail
expect(function() may_fail(false) end).to.throw_error_matching("fail") -- Alias for fail_with
-- expect(function() error({ code=1 }) end).to.throw_error_type("table") -- TODO: Verify implementation or remove if not supported.

local obj = { count = 0 }
local function get_count() return obj.count end
expect(function() obj.count = 1 end).to.change(get_count)
expect(function() obj.count = obj.count + 1 end).to.increase(get_count)
expect(function() obj.count = obj.count - 1 end).to.decrease(get_count)
```

#### Date Assertions (Requires `lib.tools.date`)

```lua
expect("2024-01-01").to.be_date()
expect("2024-01-01T10:00:00Z").to.be_iso_date()
expect("2024-01-01").to.be_before("2024-01-02")
expect("2024-01-02").to.be_after("2024-01-01")
expect("2024-01-01T10:00:00Z").to.be_same_day_as("2024-01-01T23:00:00+05:00")
```

#### Async Assertions (Requires `lib.async` and async context)

```lua
-- Assume async_fn accepts a `done` callback
it("tests async completion", { async = true }, function(done)
  expect(function(cb) async_module.sleep(10, cb) end).to.complete(50) -- Completes within 50ms
  expect(function(cb) async_module.sleep(10, cb) end).to.complete_within(50)
  expect(function(cb) async_module.sleep(10, function() cb(nil, "result") end) end)
    .to.resolve_with("result", 50)
  expect(function(cb) async_module.sleep(10, function() cb("error") end) end)
    .to.reject("error", 50) -- Checks error message pattern
  done()
end)
```

#### Other Assertions

```lua
expect(value).to.satisfy(function(v) return v > 10 end) -- Custom predicate
expect(my_obj).to.implement_interface({ method1 = "function", property = "string" })
-- expect(value).to.be_type("callable") -- NOTE: These 'be_type' assertions are conceptual/planned and may not be fully implemented. Checks if function or has __call metamethod
-- expect(value).to.be_type("comparable") -- NOTE: These 'be_type' assertions are conceptual/planned and may not be fully implemented. Checks if < operator works
-- expect(value).to.be_type("iterable") -- NOTE: These 'be_type' assertions are conceptual/planned and may not be fully implemented. Checks if pairs() works
```

For the most up-to-date details on parameters and behavior, refer to the JSDoc comments within `lib/assertion/init.lua`.

### Temporary File Management

Firmo tests should use the provided temporary file management system that automatically tracks and cleans up files. The system has been fully integrated into the test framework to ensure all temporary resources are properly cleaned up.

#### Creating Temporary Files

```lua
-- Create a temporary file
local file_path, err = temp_file.create_with_content("file content", "lua")
expect(err).to_not.exist("Failed to create temporary file")
-- Create a temporary directory
local dir_path, err = temp_file.create_temp_directory()
expect(err).to_not.exist("Failed to create temporary directory")
-- No manual cleanup needed - the system will automatically clean up
-- when the test completes
```

#### Working with Temporary Test Directories

For tests that need to work with multiple files, use the test directory helpers:

```lua
-- Create a test directory context
local test_dir = test_helper.create_temp_test_directory()
-- Create files in the directory
test_dir:create_file("config.json", '{"setting": "value"}')
test_dir:create_file("subdir/data.txt", "nested file content")
-- Use the directory in tests
local config_path = test_dir:path() .. "/config.json"
expect(fs.file_exists(config_path)).to.be_truthy()
```

#### Creating Test Directories with Predefined Content

For tests that need a directory with a predefined structure:

```lua
test_helper.with_temp_test_directory({
  ["config.json"] = '{"setting": "value"}',
  ["data.txt"] = "test data",
  ["scripts/helper.lua"] = "return function() return true end"
}, function(dir_path, files, test_dir)
  -- Test code here...
  expect(fs.file_exists(dir_path .. "/config.json")).to.be_truthy()
end)
```

#### Registering Existing Files

If you create files through other means, register them for cleanup:

```lua
-- For files created outside the temp_file system
local file_path = os.tmpname()
local f = io.open(file_path, "w")
f:write("content")
f:close()
-- Register for automatic cleanup
test_helper.register_temp_file(file_path)
```

#### Best Practices for Temporary Files

1. **ALWAYS** use `temp_file.create_with_content()` instead of `os.tmpname()`
2. **ALWAYS** check error returns with `expect(err).to_not.exist()`
3. **NEVER** manually remove temporary files (no need for `os.remove()` or `temp_file.remove()`)
4. **ALWAYS** use `test_helper.create_temp_test_directory()` for complex tests
5. For more advanced usage, see the full documentation in `docs/coverage_repair/temp_file_integration_summary.md`

#### Troubleshooting Orphaned Files

If temporary files are not being cleaned up:

```lua
-- Clean up orphaned temporary files (dry run mode)
lua scripts/cleanup_temp_files.lua --dry-run
-- Clean up orphaned temporary files (actual cleanup)
lua scripts/cleanup_temp_files.lua
```

### Test Directory Structure

Tests are organized in a logical directory structure by component:

```text
tests/
├── assertions/      # Assertion system tests
├── async/           # Asynchronous functionality tests
├── core/            # Core framework component tests (config, tagging, etc.)
├── coverage/        # Coverage module tests (debug hook system)
├── discovery/       # Test discovery mechanism tests
├── error_handling/  # Error handling tests
│   └── core/        # Core error handling mechanism tests
├── fixtures/        # Test fixtures and helper modules
│   └── modules/     # Example modules used in tests
├── integration/     # Integration tests involving multiple components
├── mocking/         # Mocking, stubbing, and spying tests
├── parallel/        # Parallel test execution tests
├── performance/     # Performance-related tests
├── quality/         # Code quality validation tests
├── reporting/       # Reporting system tests (formatters, core logic)
└── tools/           # Utility module tests
    ├── filesystem/  # Filesystem utilities (temp files) tests
    ├── logging/     # Logging system tests
    ├── vendor/      # Tests for vendored dependencies
    └── watcher/     # File watcher tests
```

### Test Execution

- Tests are run using the standardized command: `lua firmo.lua [path]`
- For a single test file: `lua firmo.lua tests/reporting_test.lua`
- For a directory of tests: `lua firmo.lua tests/coverage/`
- For all tests: `lua firmo.lua tests/`

### Other Useful Commands

- Fix Markdown Files: `lua scripts/fix_markdown.lua docs`
- Fix Specific Markdown Files: `lua scripts/fix_markdown.lua README.md CHANGELOG.md`
- Debug Report Generation: `lua firmo.lua --coverage --format=html tests/reporting_test.lua`
- Test Quality Validation: `lua firmo.lua --quality --quality-level=2 tests/quality_test.lua`
- Clean Orphaned Temp Files: `lua scripts/cleanup_temp_files.lua`
- Clean Orphaned Temp Files (Dry Run): `lua scripts/cleanup_temp_files.lua --dry-run`
- Check Lua Syntax: `lua scripts/check_syntax.lua <file_path>`
- Find Print Statements: `lua scripts/find_print_statements.lua lib/`

## Project Structure

The firmo project is organized as follows:

- `/lib`: Core library code, organized by functionality.
  - `/lib/assertion/`: Expect-style assertion implementation (`init.lua`).
  - `/lib/async/`: Asynchronous test support (`init.lua`, helpers).
  - `/lib/core/`: Fundamental framework components (`central_config.lua`, `firmo.lua`, `tagging.lua`, `type_checking.lua`, `version.lua`, `module_reset.lua`).
  - `/lib/coverage/`: Debug hook-based code coverage system (`init.lua`).
  - `/lib/discovery/`: Test file discovery logic (`init.lua`).
  - `/lib/error_handling/`: Standardized error handling system (`init.lua`, helpers).
  - `/lib/fixtures/`: Test fixture utilities (potentially).
  - `/lib/mocking/`: Mocking framework (`init.lua`, `mock.lua`, `spy.lua`, `stub.lua`).
  - `/lib/parallel/`: Parallel test execution support (`init.lua`).
  - `/lib/quality/`: Code quality validation rules and checks (`init.lua`, levels).
  - `/lib/reporting/`: Test result reporting system (`init.lua`, formatters).
    - `/lib/reporting/formatters/`: Specific report formatters (e.g., `console.lua`, `html.lua`, `json.lua`).
  - `/lib/tools/`: General utility modules.
    - `/lib/tools/filesystem/`: Filesystem operations, including temporary file management (`init.lua`, `temp_file.lua`).
    - `/lib/tools/logging/`: Structured logging (`init.lua`, formatters, search).
    - `/lib/tools/parser/`: Lua code parsing utilities (`init.lua`).
    - `/lib/tools/vendor/`: Third-party dependencies (e.g., `lpeglabel.lua`).
    - `/lib/tools/watcher/`: File system watcher for `--watch` mode (`init.lua`).
    - Other tools: `date.lua`, `hash/init.lua`, `interactive_mode.lua`, `json/init.lua`.
- `/tests`: Unit and integration tests for the framework, mirroring `lib` structure.
  - (See "Test Directory Structure" section above for detailed layout)
- `/examples`: Example Lua projects demonstrating firmo usage.
- `/scripts`: Helper scripts for development, maintenance, and CI tasks (e.g., `check_syntax.lua`, `cleanup_temp_files.lua`, `fix_markdown.lua`, `version_bump.lua`, `version_check.lua`).
- `/docs`: Project documentation.
  - `/docs/api/`: Generated API documentation.
  - `/docs/guides/`: Usage guides (e.g., `central_config.md`).
  - `/docs/firmo/`: Internal planning and architecture documents (e.g., `plan.md`, `architecture.md`, `claude_document_update_plan.md`).
- `firmo.lua`: Main entry point for using firmo as a library and for invoking the CLI (which handles test execution).
- `.firmo-config.lua`: Default configuration file for project-specific settings.
- `README.md`: Project overview and setup instructions.
- `CHANGELOG.md`: Record of changes.
- Other config/meta files: `.luacheckrc`, `.stylua.toml`, `LICENSE`, etc.

## Coverage Module Architecture

### Components (Debug Hook Architecture)

The coverage system leverages Lua's `debug.sethook` mechanism to track line execution without modifying the source code directly. This approach avoids the complexities of source code instrumentation and provides accurate coverage data based on runtime execution.

1. **Coverage Core (`lib/coverage/init.lua`)**:

    - **Public API**: Provides functions like `init`, `start`, `stop`, `pause`, `resume`, `save_stats`, `load_stats`.
    - **State Management**: Manages the coverage state (`initialized`, `paused`), coverage data (`state.data`), and configuration cache.
    - **Hook Management**: Sets the debug hook (`debug_hook`) on the main thread and patches `coroutine.create`/`wrap` to apply hooks to new coroutines. Ensures hooks are properly removed during `shutdown`.
    - **Configuration**: Integrates with `central_config` to get settings like `enabled`, `include`/`exclude` patterns, `statsfile`, `savestepsize`.
    - **Stats Handling**: Implements saving/loading coverage data to/from the configured stats file, using an atomic save process and handling potential errors. Merges loaded stats with existing data.
    - **Error Handling**: Uses `lib.tools.error_handler` and `lib.tools.filesystem` for robust operation and error reporting. Tracks write failures to prevent infinite loops if saving fails repeatedly.

2. **Debug Hook (`debug_hook` function inside `init.lua`)**:

    - **Execution Tracking**: Called by the Lua runtime for each executed line (`"l"` event).
    - **File Filtering**: Determines the source file, normalizes its path (`filesystem.normalize_path`), and checks if it should be tracked based on `include`/`exclude` patterns using `should_track_file`. Uses a cache (`ignored_files`) for efficiency.
    - **Data Recording**: If the file is tracked, increments the hit count for the specific line number in `state.data`. Initializes the file's entry if it's the first hit.
    - **Buffering & Saving**: Manages a buffer (`state.buffer`) and triggers `save_stats` periodically based on configuration (`savestepsize`, `tick`) or buffer limits (`MAX_BUFFER_SIZE`) to persist data.

3. **Configuration (`lib/core/central_config.lua`)**:

    - **Settings Source**: Provides all configuration for the coverage module (enabled status, include/exclude patterns, stats file path, save frequency).
    - **Defaults**: Defines default coverage settings.
    - **Project Overrides**: Reads project-specific settings from `.firmo-config.lua`.

4. **Filesystem (`lib/tools/filesystem/init.lua`)**:

    - **Path Normalization**: Provides `normalize_path` used extensively for consistent file tracking.
    - **File Operations**: Used by `save_stats` and `load_stats` for reading, writing, moving, and checking file existence.

5. **Error Handling (`lib.tools.error_handler.lua`)**:

    - **Error Reporting**: Used throughout the coverage module to create structured errors and handle exceptions gracefully (e.g., during file I/O).

6. **Assertion Integration for Three-State Coverage**:
    - The core coverage mechanism (`debug_hook`) tracks all executed lines, recording a hit count (> 0) for each line in the coverage data (`state.data`).
    - To differentiate verified code, the assertion module (`lib/assertion/init.lua`), upon successful execution of an assertion (`expect(...).to...`), explicitly calls `coverage.mark_line_covered(file_path, line_number)`. This function flags the specific line within the coverage data as having been covered by a passing assertion.
    - The reporting system uses both pieces of information:
      - **Covered (Green)**: Line has a hit count > 0 AND was explicitly marked by `coverage.mark_line_covered`.
      - **Executed (Orange)**: Line has a hit count > 0 BUT was NOT explicitly marked by an assertion.
      - **Not Covered (Red)**: Line has a hit count of 0 (or was never recorded).
    - This explicit marking by assertions is crucial for providing the distinction between merely executed code and code whose behavior was actively verified by a test.

This architecture differs significantly from instrumentation-based systems by relying on runtime hooks rather than code transformation.

### Error Handling Guidelines

When working with the coverage module and implementing error handling:

1. **Use Structured Error Objects**: Always use error_handler.create() or specialized functions

   ```lua
   local err = error_handler.validation_error(
     "Missing required parameter",
     {parameter_name = "file_path", operation = "track_file"}
   )
   ```

2. **Proper Error Propagation**: Return nil and error object

   ```lua
   if not file_content then
     return nil, error_handler.io_error(
       "Failed to read file",
       {file_path = file_path, operation = "track_file"}
     )
   end
   ```

3. **Try/Catch Pattern**: Use error_handler.try for operations that might throw errors

   ```lua
   local success, result, err = error_handler.try(function()
     return analyze_file(file_path)
   end)
   if not success then
     logger.error("Failed to analyze file", {
       file_path = file_path,
       error = error_handler.format_error(result)
     })
     return nil, result
   end
   ```

4. **Safe I/O Operations**: Use error_handler.safe_io_operation for file access

   ```lua
   local content, err = error_handler.safe_io_operation(
     function() return fs.read_file(file_path) end,
     file_path,
     {operation = "read_coverage_file"}
   )
   ```

5. **Validation Functions**: Always validate input parameters

   ```lua
   error_handler.assert(type(file_path) == "string",
     "file_path must be a string",
     error_handler.CATEGORY.VALIDATION,
     {provided_type = type(file_path)}
   )
   ```

## Error Handling Implementation Across Modules

All modules in firmo follow these consistent error handling patterns:

1. **Input Validation**: Validate all function parameters at the start
2. **Error Propagation**: Return nil/false and error objects for failures
3. **Error Types**: Use specialized error types (validation, io, runtime, etc.)
4. **Error Context**: Include detailed contextual information in error objects
5. **Try/Catch**: Wrap potentially risky operations in error_handler.try()
6. **Logging**: Log errors with appropriate severity levels and context
7. **Safe I/O**: Use safe I/O operations with proper error handling
8. **Recovery**: Implement recovery mechanisms and fallbacks where appropriate

Complete error handling has been implemented across:

- All formatters in the reporting system
- All tools modules (benchmark, codefix, interactive, markdown, watcher)
- Mocking system (init, spy, mock)
- Core framework modules (config, coverage components)
