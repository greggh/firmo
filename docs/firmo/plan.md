# V3 Coverage System Implementation Plan

## Overview

The v3 coverage system is a complete rewrite that replaces the debug hook approach with source code instrumentation. This provides more accurate coverage tracking and better performance.

## Important: No Debug Hooks

The v3 system MUST NOT use any debug hooks (debug.sethook, etc). Debug hooks are unreliable and cannot properly distinguish between executed and covered code. All coverage tracking MUST be done through source code instrumentation.

## Implementation Steps

1. 🔄 Rework Core Components for Temp Files

   - ✅ Create directory structure in lib/coverage/v3
   - ✅ Create test directory structure in tests/coverage/v3
   - ✅ Implement parser using existing LPegLabel parser
   - 🔄 Update transformer to work with temp files
   - 🔄 Rework sourcemap for temp file mapping
   - 🔄 Add path mapping system

2. 🔄 Rework Module Loading

   - 🔄 Create loader hook using test_helper temp files
   - 🔄 Update instrumentation to work in temp directory
   - 🔄 Rework caching system for temp files
   - 🔄 Add temp file configuration options
   - 🔄 Handle circular dependencies with temp files

3. 🔄 Rework Runtime Tracking

   - 🔄 Update execution tracker for temp files
   - 🔄 Update data store for path mapping
   - 🔄 Implement three-state tracking (covered, executed, not covered)
   - 🔄 Add persistence with temp file support

4. 🔄 Implement Safe Instrumentation with Temp Files

   - Modify loader/hook.lua to:
     - Use test_helper.create_temp_test_directory() for instrumented files
     - Instrument copies in temp directory
     - Load from temp directory instead of originals
     - Use temp_file registration for automatic cleanup
   - Update runtime/tracker.lua to:
     - Map temp file paths back to original paths
     - No need for manual cleanup - temp_file handles it
   - Update sourcemap.lua to:
     - Account for temp file locations
     - Map error locations back to original files

5. 🔄 Implement Path Mapping System

   - Create mapping between original and temp file paths
   - Update sourcemap to handle temp file locations
   - Map error locations back to original files
   - Ensure proper error reporting with correct file paths

6. Implement Assertion Integration

   - Create assertion analyzer
   - Track which lines are verified by assertions
   - Map assertions to covered code

7. Implement Reporting

   - Create HTML reporter with three-state visualization
   - Add JSON reporter for machine consumption
   - Add source code viewer
   - Add coverage statistics

8. Testing and Validation

   - Create comprehensive test suite
   - Add performance benchmarks
   - Test edge cases
   - Validate coverage accuracy

9. Documentation

   - Update API documentation
   - Add migration guide
   - Document configuration options
   - Add examples

## Architecture

The v3 system uses source code instrumentation with temporary files:

1. When a module is loaded:

   - Create temporary copy of source file
   - Parse the source code into an AST
   - Transform the AST to add coverage tracking
   - Generate instrumented code in temp file
   - Create source map
   - Cache the instrumented module

2. During execution:

   - Load instrumented code from temp files
   - Track which lines are executed
   - Track which lines are covered by assertions
   - Store data efficiently
   - Map temp paths back to original paths

3. After test run:

   - Process coverage data
   - Generate reports
   - Show three-state coverage
   - Temp files cleaned automatically by temp_file module

## Current State Assessment

### Working Components
1. **Parser (parser.lua)**:
   - Properly handles Lua source code parsing
   - Includes comment extraction
   - Adds line numbers to AST nodes
   - No temp file dependencies - can keep as is

2. **Data Store (data_store.lua)**:
   - Implements three-state tracking (covered, executed, not covered)
   - Clean data structure design
   - No temp file dependencies - can keep core functionality

### Broken/Incomplete Components
1. **Init Module (init.lua)**:
   - Has syntax errors (unmatched braces in stop() and reset())
   - Missing path mapping implementation
   - Temp directory handling is incomplete

2. **Instrumentation (instrumentation/init.lua)**:
   - Not using temp files for instrumented code
   - Incorrect source map handling
   - Generates wrong instrumented code (just concatenates functions)

3. **Transformer (transformer.lua)**:
   - Code generation returns dummy string
   - Source map creation is incomplete
   - No temp file path handling

4. **Source Map (sourcemap.lua)**:
   - Only implements 1:1 mapping
   - Missing temp file path mapping
   - Missing validation implementation

5. **Loader Hook (loader/hook.lua)**:
   - Not using temp files for instrumented modules
   - Direct file I/O instead of test_helper
   - Missing proper cleanup registration

6. **Cache (cache.lua)**:
   - Not temp file aware
   - Uses direct file I/O for mtime
   - Missing proper path mapping

7. **Runtime Tracker (tracker.lua)**:
   - Uses debug.getinfo instead of proper path mapping
   - No temp file path translation
   - Missing proper error handling

### Missing Tests
1. **No Test Files Found**:
   - instrumentation_test.lua
   - loader_test.lua
   - tracker_test.lua
   - data_store_test.lua

### Critical Issues to Fix
1. **Syntax Errors**:
   - Fix unmatched braces in init.lua
   - Fix any other syntax errors found during testing

2. **Missing Path Mapping**:
   - Implement consistent path mapping system
   - Update all components to use it
   - Handle temp file to original file translation

3. **Temp File Integration**:
   - Replace all direct file I/O with test_helper
   - Implement proper temp file registration
   - Ensure automatic cleanup

4. **Test Coverage**:
   - Create missing test files
   - Test temp file functionality
   - Test path mapping
   - Test error cases

### Implementation Order
1. Fix syntax errors in init.lua
2. Create test files first (TDD approach)
3. Implement path mapping system
4. Update components in this order:
   - sourcemap.lua (foundation for path mapping)
   - transformer.lua (code generation)
   - instrumentation/init.lua (temp file usage)
   - loader/hook.lua (temp file loading)
   - cache.lua (temp file awareness)
   - tracker.lua (path translation)

## Migration

1. Remove all debug hook code
2. Replace with instrumentation
3. Update tests to use new system
4. Update documentation

## Success Criteria

The implementation is only complete when:

- No debug hooks are used anywhere
- All coverage tracking is done through instrumentation
- Three states are properly distinguished
- Performance is better than v2
- All tests pass
- Edge cases are handled
- No modification of original source files
- Proper cleanup of temporary files

## Test Development Guidelines

### TDD Approach
- ALWAYS write tests first
- Run tests frequently during development
- Keep test cases focused and minimal
- Add edge cases as separate test cases

### Critical: Test Error Handling
1. ALWAYS read the full test output when tests fail
2. Look for the actual ERROR lines in test output
3. Track down the exact error location and message
4. Fix the specific error reported, not assumed issues
5. Re-run tests to verify the exact error is fixed
6. Only then move on to the next error

### Test Debugging Process
1. Run the failing test in isolation
2. Capture the complete error output
3. Locate the exact error line and message
4. Check the test file at the error location
5. Verify assumptions about what's failing
6. Make minimal changes to fix the specific error
7. Re-run test to confirm error is resolved
8. Move to next error only after current one is fixed

## Critical Implementation Notes

### Coverage Module Functionality
- Must maintain full lifecycle management (start, stop, reset)
- Must handle three-state coverage tracking properly
- Must process and normalize data before reporting
- Must preserve all existing functionality while adding temp file support

### Proper Temp File Usage
1. Use test_helper.create_temp_test_directory() for instrumented files
2. Leverage automatic cleanup through test contexts
3. Use proper path mapping between original and temp files
4. Never modify original source files
5. Register all temp files with temp_file system

### Core Module Usage and Enhancement
1. **First Approach**:
   - Use existing functionality in core modules
   - Combine existing functions to meet needs
   - Follow established patterns

2. **When to Add New Core Functionality**:
   - When need is project-wide, not coverage-specific
   - When functionality would benefit multiple modules
   - When existing functions don't quite meet common needs
   - Example: Adding recursive file listing because many modules need it

3. **Requirements for Core Module Additions**:
   - Must be generally useful
   - Must be well-tested
   - Must be properly documented
   - Must match module's design patterns
   - Must not modify existing behavior

4. **When Not to Modify Core Modules**:
   - No special-case functionality
   - No coverage-specific features
   - No duplication of existing functionality
   - No changes to existing behavior

### Available Infrastructure
1. test_helper module provides:
   - Temporary directory creation
   - File creation in temp directories
   - Automatic cleanup through test contexts
   - Safe error handling

2. temp_file module provides:
   - File registration for cleanup
   - Directory registration
   - Automatic cleanup
   - Test context management

3. filesystem module provides:
   - Safe file operations
   - Directory creation
   - Path manipulation
   - Error handling

## Test Review and Rewrite

1. **Current Test Issues**:
   - Tests assume direct file manipulation instead of temp files
   - Missing tests for path mapping between temp and original files
   - Tests don't verify proper cleanup
   - Tests don't check for file isolation

2. **Test Files to Replace**:
   - instrumentation_test.lua:
     - Add temp file creation tests
     - Test path mapping in instrumented code
     - Verify no original file modification
     - Test cleanup after instrumentation

   - loader_test.lua:
     - Test temp directory usage
     - Test proper file registration
     - Test path mapping during loading
     - Test cleanup after module loads

   - tracker_test.lua:
     - Remove direct file path tests
     - Add temp to original path mapping tests
     - Test path translation accuracy
     - Test cleanup of tracking data

   - data_store_test.lua:
     - Update for temp file path storage
     - Test path mapping in data storage
     - Test data aggregation across temp files
     - Test cleanup of stored data

3. **New Tests Needed**:
   - sourcemap_test.lua:
     - Test temp to original path mapping
     - Test line number mapping
     - Test error location mapping
     - Test sourcemap persistence

   - path_mapping_test.lua:
     - Test path translation utilities
     - Test edge cases (symlinks, etc.)
     - Test error handling
     - Test cleanup

4. **Test Implementation Order**:
   1. Create path_mapping_test.lua first (foundation)
   2. Create sourcemap_test.lua (depends on path mapping)
   3. Replace instrumentation_test.lua
   4. Replace loader_test.lua
   5. Replace tracker_test.lua
   6. Replace data_store_test.lua

5. **Test Guidelines**:
   - Every test must verify temp file usage
   - Every test must verify cleanup
   - Every test must check path mapping
   - No direct file manipulation in tests

## Implementation Requirements

### CRITICAL: Code Reuse Requirements
1. **Before ANY New Code**:
   - Search core modules exhaustively
   - Document all existing functionality found
   - Map existing functions to requirements
   - Only write new code as last resort

2. **Required Module Review**:
   - filesystem (fs): ALL path/file operations
   - test_helper: ALL test file management
   - error_handler: ALL error handling
   - logging: ALL debug/error logging
   - central_config: ALL configuration

3. **Specific Requirements**:
   - Path operations: MUST use fs.normalize_path, fs.join_paths
   - File I/O: MUST use fs.read_file, fs.write_file
   - Temp files: MUST use test_helper.create_temp_test_directory
   - Error handling: MUST use error_handler patterns

4. **Implementation Process**:
   - Document existing functionality first
   - Map requirements to existing functions
   - Get approval for any new code
   - Write tests using existing helpers
   - Implement using existing functions
