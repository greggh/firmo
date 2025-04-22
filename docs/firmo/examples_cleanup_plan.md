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

- [ ] examples/assertions_example.lua
- [ ] examples/async_example.lua
- [ ] examples/async_watch_example.lua
- [ ] examples/basic_example.lua
- [ ] examples/benchmark_example.lua
- [ ] examples/central_config_example.lua
- [ ] examples/cli_tool_example.lua
- [ ] examples/cobertura_example.lua
- [ ] examples/cobertura_jenkins_example.lua
- [ ] examples/codefix_example.lua
- [ ] examples/comprehensive_testing_example.lua
- [ ] examples/coverage_example.lua
- [ ] examples/csv_example.lua
- [ ] examples/custom_formatters_example.lua
- [ ] examples/error_handling_example.lua
- [ ] examples/extended_assertions_example.lua
- [ ] examples/filesystem_example.lua
- [ ] examples/focused_tests_example.lua
- [ ] examples/formatter_config_example.lua
- [ ] examples/hash_example.lua
- [ ] examples/html_coverage_example.lua
- [ ] examples/html_formatter_example.lua
- [ ] examples/html_report_example.lua
- [ ] examples/interactive_mode_example.lua
- [ ] examples/json_example.lua
- [ ] examples/json_output_example.lua
- [ ] examples/junit_example.lua
- [ ] examples/lcov_example.lua
- [ ] examples/logging_examples.md
- [ ] examples/mock_sequence_example.lua
- [ ] examples/mocking_example.lua
- [ ] examples/module_reset_example.lua
- [ ] examples/parallel_async_example.lua
- [ ] examples/parallel_execution_example.lua
- [ ] examples/parallel_json_example.lua
- [ ] examples/quality_example.lua
- [ ] examples/report_example.lua
- [ ] examples/reporting_filesystem_integration.lua
- [ ] examples/specialized_assertions_example.lua
- [ ] examples/summary_example.lua
- [ ] examples/tagging_example.lua
- [ ] examples/tap_example.lua
- [ ] examples/temp_file_management_example.lua
- [ ] examples/watch_mode_example.lua
