# Example Files Update Plan

## Phase 1: Inventory and Assessment

1. Create inventory of all 43 example files with metadata:
   - File path
   - Last modified date
   - Covered functionality
   - Deprecation status

## Phase 2: Deprecation Review

1. Identify examples using deprecated features using rules:
   - Remove examples using deprecated functions like `table.getn`
   - Flag examples using non-standard configurations
   - Check for direct coverage module usage
2. Document deprecation decisions in changelog

## Phase 3: Example Updates

1. Align all examples with current functionality:
   - Update to use `#` operator for table length
   - Standardize on `table.unpack` compatibility function
   - Update to use central_config system
   - Update to use proper error_handler system
   - If needed, update test examples to use expect_errors
   - If needed, update test examples to use test_helper
2. Add JSDoc documentation per project standards
3. Normalize data structures at boundaries

## Phase 4: Feature Coverage

1. Identify gaps in example coverage from architecture docs
2. Create new examples for uncovered features following:
   - Single responsibility principle
   - Proper polymorphism patterns
   - No special case code

## Phase 5: Standardization

1. Apply consistent formatting across examples
2. Standardize documentation headers
3. Ensure all examples follow test command patterns

## Phase 6: Validation

1. Verify all examples execute successfully
2. Confirm no disabled diagnostic comments are removed

## Phase 7: Documentation

1. Update example index documentation
2. Add example cross-references to feature docs
3. Document all changes in CHANGELOG.md
4. Mark example file as completed in the list below.

## List of example files

- [x] examples/assertions_example.lua -- executes successfully
- [x] examples/async_example.lua -- executes successfully
- [x] examples/async_watch_example.lua -- executes successfully
- [x] examples/basic_example.lua -- executes successfully
- [x] examples/benchmark_example.lua
- [x] examples/central_config_example.lua -- executes successfully
- [x] examples/cobertura_example.lua -- executes successfully
- [x] examples/cobertura_jenkins_example.lua -- executes successfully (with known report generation errors due to non-standard coverage setup)
- [x] examples/codefix_example.lua -- executes successfully (with 'no matching files' warnings)
- [x] examples/comprehensive_testing_example.lua -- executes successfully
- [x] examples/coverage_example.lua
- [x] examples/csv_example.lua
- [x] examples/custom_formatters_example.lua
- [x] examples/error_handling_example.lua
- [x] examples/extended_assertions_example.lua
- [x] examples/filesystem_example.lua
- [x] examples/focused_tests_example.lua
- [x] examples/formatter_config_example.lua
- [x] examples/hash_example.lua
- [x] examples/html_coverage_example.lua
- [x] examples/html_formatter_example.lua
- [x] examples/html_report_example.lua
- [x] examples/interactive_mode_example.lua
- [x] examples/json_example.lua
- [x] examples/json_output_example.lua
- [x] examples/junit_example.lua
- [x] examples/lcov_example.lua
- [x] examples/logging_examples.md
- [x] examples/mock_sequence_example.lua
- [x] examples/mocking_example.lua
- [x] examples/module_reset_example.lua
- [x] examples/parallel_async_example.lua
- [x] examples/parallel_execution_example.lua
- [x] examples/parallel_json_example.lua
- [x] examples/quality_example.lua
- [x] examples/report_example.lua
- [x] examples/reporting_filesystem_integration.lua
- [x] examples/specialized_assertions_example.lua
- [x] examples/summary_example.lua
- [x] examples/tagging_example.lua
- [x] examples/tap_example.lua
- [x] examples/temp_file_management_example.lua
- [x] examples/watch_mode_example.lua

--- gets the error handler for the filesystem module
local function get_error_handler()
if not error_handler then
error_handler = require("lib.tools.error_handler")
end
return error_handler
end

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
local success, result = pcall(require, module_name)
if not success then
print("Warning: Failed to load module:", module_name, "Error:", result)
return nil
end
return result
end
