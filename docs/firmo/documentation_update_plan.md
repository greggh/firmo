# Documentation Update Implementation Plan

## Overview

This implementation plan outlines steps to systematically review and update documentation based on specific git commits from the past week. Each section corresponds to a major change set and details which documentation files need to be updated and how.

## 1. Coverage System Refactoring (April 12, 2025)

### From Commit 442c75a2 (Streamlined Coverage Configuration)

#### Files to Update:
- `docs/api/coverage.md`
- `docs/guides/coverage.md`
- `docs/api/central_config.md`
- `docs/guides/central_config.md`

#### Update Tasks:
1. Document pattern-based include/exclude configuration:
   - Add section on pattern syntax and matching rules
   - Include examples of common include/exclude patterns
   - Document default patterns

2. Document statsfile configuration:
   - Add parameters for statsfile location and format
   - Document automatic file management
   - Include examples of statsfile configuration options

3. Document threshold configurations:
   - Document line coverage thresholds
   - Document function coverage thresholds
   - Explain threshold enforcement options

4. Document recursive reset protection in central_config:
   - Explain protection mechanism
   - Document how to safely reset configuration
   - Include error handling examples for reset operations

5. Update coverage report generation documentation:
   - Document optimized report generation process
   - Update command-line options for report generation
   - Document integration with runner.lua

### From Commit f10b2350 (Debug Hook System Transition)

#### Files to Update:
- `docs/api/coverage.md`
- `docs/guides/coverage.md`
- `docs/guides/configuration-details/formatters.md`
- `lib/coverage/knowledge.md`

#### Update Tasks:
1. Document transition from instrumentation to debug hook system:
   - Add overview section explaining the major architectural change
   - Highlight benefits of debug hook approach
   - Document migration considerations for existing users

2. Update debug.sethook documentation:
   - Document line event handling
   - Explain how coroutines are tracked
   - Document hook installation and removal

3. Document large file performance considerations:
   - Add performance implications section
   - Include benchmark results
   - Document optimizations for large files

4. Update coverage implementation details:
   - Document internal hook functionality
   - Update coverage data structure documentation
   - Document thread-safety features
   - Update coverage lifecycle explanation

## 2. Stub and Logging Improvements (April 11, 2025)

### From Commit e60b9b03

#### Files to Update:
- `docs/api/mocking.md`
- `docs/guides/mocking.md`
- `docs/api/logging.md`
- `docs/guides/logging.md`
- `docs/api/logging_components.md`
- `docs/guides/logging_components.md`

#### Update Tasks:
1. Document enhanced stub error handling:
   - Update stub error handling documentation
   - Document new matcher support
   - Add examples of complex stub scenarios
   - Update API reference for stub functions

2. Update logging formatter integration documentation:
   - Document formatter registry system
   - Update formatter configuration options
   - Document formatter error handling

3. Document type annotations:
   - Add section on type annotations for stub and logging
   - Include LuaLS/Sumneko integration information
   - Document intellisense support

4. Update mock.lua and logging.lua documentation:
   - Emphasize active status of these modules
   - Document integration with stub module
   - Update API reference
   - Add cross-references between modules

## 3. Test Framework Updates (April 10, 2025)

### From Commit d74b41eb (Test Metadata)

#### Files to Update:
- `docs/api/test_helper.md`
- `docs/guides/test_helper.md`
- `docs/api/error_handling.md`
- `docs/guides/error_handling.md`

#### Update Tasks:
1. Document improved test metadata tracking:
   - Explain metadata synchronization between modules
   - Document metadata structure and properties
   - Include examples of accessing test metadata

2. Update error handler metadata documentation:
   - Document integration with test_definition
   - Explain error context propagation
   - Update error recovery documentation

3. Document test status reporting improvements:
   - Update status reporting options
   - Document error state management
   - Include examples of status reporting usage

### From Commit dda49eb2 (Async Timeout Patterns)

#### Files to Update:
- `docs/api/async.md`
- `docs/guides/async.md`
- `docs/guides/configuration-details/async.md`

#### Update Tasks:
1. Update async timeout test patterns documentation:
   - Document pattern matching improvements
   - Update timeout message format
   - Include examples of pattern matching for timeouts

### From Commit d6e86fa7 (it_async Function)

#### Files to Update:
- `docs/api/async.md`
- `docs/guides/async.md`
- `docs/guides/configuration-details/async.md`

#### Update Tasks:
1. Document new it_async function:
   - Add complete API reference
   - Document expect_error option support
   - Include code examples

2. Document async context management:
   - Explain context creation and cleanup
   - Document state management in async tests
   - Include best practices for async testing

3. Document timeout handling:
   - Update timeout configuration options
   - Document timeout error handling
   - Include examples of custom timeout handling

4. Update error propagation documentation:
   - Document error chain in async contexts
   - Explain error handling best practices
   - Include troubleshooting section

## 4. Integration Updates

### From Commit bb480dbb (Formatter Registry)

#### Files to Update:
- `docs/api/reporting.md`
- `docs/guides/reporting.md`
- `docs/guides/configuration-details/formatters.md`
- `docs/api/temp_file.md`
- `docs/guides/temp_file.md`

#### Update Tasks:
1. Document formatter registry methods:
   - Add CSV formatter registry documentation
   - Add JUnit formatter registry documentation
   - Document formatter registration patterns
   - Include examples of custom formatter registration

2. Update temp file performance documentation:
   - Document timeout optimizations
   - Update measure_time function documentation
   - Include performance benchmarks

### From Commit 5a5f13b6 (Spy Argument Handling)

#### Files to Update:
- `docs/api/mocking.md`
- `docs/guides/mocking.md`

#### Update Tasks:
1. Document spy.lua argument handling:
   - Explain both calling conventions (obj.method() and obj:method())
   - Document self parameter handling
   - Include examples of method spying
   - Update API reference for method_wrapper

## Implementation Guidelines

### For All Updates:
1. Reference the specific commit in documentation headers:
   ```lua
   -- Updated in commit 442c75a2 (April 12, 2025)
   -- See: https://github.com/your-org/firmo/commit/442c75a2
   ```

2. Update both API and guide documentation:
   - Maintain consistent information across API and guide docs
   - Update examples in both locations
   - Ensure cross-references are correct

3. Include practical examples:
   - Provide runnable code examples
   - Add common usage patterns
   - Include edge case handling

4. Maintain architectural principles:
   - Ensure documentation reflects proper abstraction
   - Document single responsibility adherence
   - Highlight normalized data structures at boundaries

5. Ensure consistent module treatment:
   - Update documentation in a consistent style
   - Use same structure for similar modules
   - Maintain consistent terminology

6. Document all formatters comprehensively:
   - Ensure all eight formatters are properly documented
   - Document formatter-specific options
   - Include examples for each formatter

7. Maintain accurate module status:
   - Correctly document mock.lua and logging.lua as active modules
   - Update integration documentation between modules
   - Remove any deprecated status references

## Validation Process

After updating each section of documentation:

1. Review changes for technical accuracy:
   - Verify function signatures match implementation
   - Test example code
   - Validate configuration options

2. Ensure consistency:
   - Check for consistent terminology
   - Verify cross-references
   - Ensure no deprecated functionality is recommended

3. Get feedback from implementers:
   - Have original commit authors review documentation
   - Address any inaccuracies
   - Incorporate additional insights

