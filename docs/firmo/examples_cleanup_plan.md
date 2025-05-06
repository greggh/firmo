# Example Files Update Plan

## Phase 1: Deprecation Review

1. Mark all files in the "List of example files" below as not completed.
2. Remove the additonal data marking each file as executed successfully if any file
   in the list has that marking.
3. Ensure every file listed in "List of example files" actually exist in the examples
   directory, if any files are in this list but don't exist on the filesystem, then remove that file from the list.
4. Ensure the list in "List of example files" is complete, it should contain every lua file in the examples direcotry.
   List every .lua file in the examples directory and add any missing ones to the "List of example files".
5. Identify examples using deprecated features using rules:
   - Remove examples using deprecated functions like `table.getn`
   - Flag examples using non-standard configurations
   - Check for direct coverage module usage
6. Document deprecation decisions in changelog
   Note: The following files were identified as using `require("lib.coverage")` and will be updated in Phase 2:

- `examples/cobertura_jenkins_example.lua`
- `examples/html_formatter_example.lua`
- `examples/report_example.lua`

## Phase 2: Example Updates

1. Align all examples with current functionality:
   - Update to use `#` operator for table length
   - Standardize on `table.unpack` compatibility function, only if needed.
   - Update to use central_config system
   - Update to use proper error_handler system
   - If needed, update test examples to use expect_errors
   - If needed, update test examples to use test_helper
   - Remove unused require statements.
2. Add JSDoc documentation per project standards, docs/firmo/jsdoc_standards.md
3. Normalize data structures at boundaries

## Phase 3: Feature Coverage

1. Identify gaps in example coverage from architecture docs
2. Create new examples for uncovered features following:
   - Single responsibility principle
   - Proper polymorphism patterns
   - No special case code

## Phase 4: Standardization

1. Apply consistent formatting across examples
2. Standardize documentation headers
3. Ensure all examples follow test command patterns

## Phase 5: Validation (Completed)

1. Verify all examples execute successfully

## Phase 6: Documentation (Completed)

1. Update example index documentation (`docs/guides/examples.md`)
2. Add example cross-references to feature docs (`docs/guides/getting-started.md` updated)
3. Document all changes in CHANGELOG.md
4. Mark example file as completed in the list below.

## List of example files

- [x] examples/advanced_async.lua
- [x] examples/assertions_example.lua
- [x] examples/async_example.lua
- [x] examples/async_focus_skip.lua
- [x] examples/async_watch_example.lua
- [x] examples/basic_async.lua
- [x] examples/basic_example.lua
- [x] examples/benchmark_example.lua
- [x] examples/central_config_example.lua
- [x] examples/cobertura_example.lua
- [x] examples/cobertura_jenkins_example.lua
- [x] examples/codefix_example.lua
- [x] examples/comprehensive_testing_example.lua
- [x] examples/coverage_example.lua
- [x] examples/csv_example.lua
- [x] examples/custom_formatters_example.lua
- [x] examples/date_example.lua
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
- [x] examples/logging_example.lua
- [x] examples/markdown_fixer_example.lua
- [x] examples/mock_sequence_example.lua
- [x] examples/mocking_example.lua
- [x] examples/module_reset_example.lua
- [x] examples/nested_async.lua
- [x] examples/parallel_async_example.lua
- [x] examples/parallel_execution_example.lua
- [x] examples/parallel_json_example.lua
- [x] examples/parser_example.lua
- [x] examples/quality_example.lua
- [x] examples/report_example.lua
- [x] examples/reporting_filesystem_integration.lua
- [x] examples/specialized_assertions_example.lua
- [x] examples/summary_example.lua
- [x] examples/tagging_example.lua
- [x] examples/tap_example.lua
- [x] examples/temp_file_management_example.lua
- [x] examples/test_helper_example.lua
- [x] examples/type_checking_example.lua
- [x] examples/watch_mode_example.lua
