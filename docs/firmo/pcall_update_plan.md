# pcall/xpcall Migration Plan

## Current State Analysis

1. Audit all existing `pcall`/`xpcall` usage across codebase, specifically the files listed below.
2. Document current error handling patterns
3. Identify cases where errors are logged/suppressed

## Migration Benefits

- Structured error objects for better debugging
- Standardized error categories/severity levels
- Consistent logging format
- Better error context propagation

## Migration Approach

1. Phase 1: Replace simple `pcall` cases
2. Phase 2: Handle complex `xpcall` cases
3. Phase 3: Update tests and documentation
4. Phase 4: Mark files as complete below as you complete them.

## File-by-File Analysis

Each file will be evaluated on:

- Need for structured errors
- Error logging requirements
- Test environment needs
- Interface boundaries

## Testing Strategy

1. Unit tests for error handler integration
2. Verify structured error propagation
3. Update test assertions to use `expect(fn).to.fail()`
4. Add negative test cases

## Documentation Updates

1. `docs/api/error_handler.md`:
   - New usage patterns
   - Migration examples
2. `docs/guide/error_handler.md`:
   - Best practices
   - Common patterns
   - Debugging tips

## File list

- [ ] firmo.lua
- [ ] test.lua
- [ ] lib/assertion/init.lua
- [ ] lib/async/init.lua
- [ ] lib/core/central_config.lua
- [ ] lib/core/fix_expect.lua
- [ ] lib/core/init.lua
- [ ] lib/core/module_reset.lua
- [ ] lib/core/runner.lua
- [ ] lib/core/test_definition.lua
- [ ] lib/core/type_checking.lua
- [ ] lib/core/version.lua
- [ ] lib/coverage/init.lua
- [ ] lib/mocking/init.lua
- [ ] lib/mocking/mock.lua
- [ ] lib/mocking/spy.lua
- [ ] lib/mocking/stub.lua
- [ ] lib/quality/init.lua
- [ ] lib/quality/level_checkers.lua
- [ ] lib/reporting/format.lua
- [ ] lib/reporting/init.lua
- [ ] lib/reporting/schema.lua
- [ ] lib/reporting/validation.lua
- [ ] lib/reporting/formatters/base.lua
- [ ] lib/reporting/formatters/cobertura.lua
- [ ] lib/reporting/formatters/coverage_formatters.lua
- [ ] lib/reporting/formatters/csv.lua
- [ ] lib/reporting/formatters/html.lua
- [ ] lib/reporting/formatters/init.lua
- [ ] lib/reporting/formatters/json.lua
- [ ] lib/reporting/formatters/junit.lua
- [ ] lib/reporting/formatters/lcov.lua
- [ ] lib/reporting/formatters/summary.lua
- [ ] lib/reporting/formatters/tap.lua
- [ ] lib/reporting/formatters/tap_results.lua
- [ ] lib/samples/calculator.lua
- [ ] lib/tools/benchmark/init.lua
- [ ] lib/tools/cli/init.lua
- [ ] lib/tools/codefix/init.lua
- [ ] lib/tools/date/init.lua
- [ ] lib/tools/discover/init.lua
- [ ] lib/tools/error_handler/init.lua
- [ ] lib/tools/filesystem/init.lua
- [ ] lib/tools/filesystem/temp_file.lua
- [ ] lib/tools/filesystem/temp_file_integration.lua
- [ ] lib/tools/hash/init.lua
- [ ] lib/tools/interactive/init.lua
- [ ] lib/tools/json/init.lua
- [ ] lib/tools/logging/export.lua
- [ ] lib/tools/logging/formatter_integration.lua
- [ ] lib/tools/logging/init.lua
- [ ] lib/tools/logging/search.lua
- [ ] lib/tools/markdown/init.lua
- [ ] lib/tools/parallel/init.lua
- [ ] lib/tools/parser/grammar.lua
- [ ] lib/tools/parser/init.lua
- [ ] lib/tools/parser/pp.lua
- [ ] lib/tools/parser/validator.lua
- [ ] lib/tools/test_helper/init.lua
- [ ] lib/tools/vendor/lpeglabel/init.lua
- [ ] lib/tools/watcher/init.lua
- [ ] scripts/check_assertion_patterns.lua
- [ ] scripts/check_syntax.lua
- [ ] scripts/cleanup_temp_files.lua
- [ ] scripts/find_print_statements.lua
- [ ] scripts/fix_markdown.lua
- [ ] scripts/monitor_temp_files.lua
- [ ] scripts/runner.lua
- [ ] scripts/version_bump.lua
- [ ] scripts/version_check.lua
- [ ] scripts/utilities/all_tests.lua
- [ ] tests/debug_structured_results.lua
- [ ] tests/simple_test.lua
- [ ] tests/assertions/assertion_module_integration_test.lua
- [ ] tests/assertions/assertion_module_test.lua
- [ ] tests/assertions/assertions_test.lua
- [ ] tests/assertions/expect_assertions_test.lua
- [ ] tests/assertions/extended_assertions_test.lua
- [ ] tests/assertions/specialized_assertions_test.lua
- [ ] tests/assertions/truthy_falsey_test.lua
- [ ] tests/async/async_test.lua
- [ ] tests/async/async_timeout_test.lua
- [ ] tests/core/config_test.lua
- [ ] tests/core/firmo_test.lua
- [ ] tests/core/module_reset_test.lua
- [ ] tests/core/tagging_test.lua
- [ ] tests/core/type_checking_test.lua
- [ ] tests/coverage/coverage_test.lua
- [ ] tests/coverage/hook_test.lua
- [ ] tests/discovery/discovery_test.lua
- [ ] tests/error_handling/error_handler_rethrow_test.lua
- [ ] tests/error_handling/error_handler_test.lua
- [ ] tests/error_handling/error_logging_debug_test.lua
- [ ] tests/error_handling/error_logging_test.lua
- [ ] tests/error_handling/helper.lua
- [ ] tests/error_handling/test_error_handling_test.lua
- [ ] tests/error_handling/core/expected_error_test.lua
- [ ] tests/fixtures/common_errors.lua
- [ ] tests/fixtures/modules/test_math.lua
- [ ] tests/mocking/mock_test.lua
- [ ] tests/mocking/spy_test.lua
- [ ] tests/mocking/stub_test.lua
- [ ] tests/parallel/parallel_test.lua
- [ ] tests/performance/large_file_test.lua
- [ ] tests/performance/performance_test.lua
- [ ] tests/quality/level_1_test.lua
- [ ] tests/quality/level_2_test.lua
- [ ] tests/quality/level_3_test.lua
- [ ] tests/quality/level_4_test.lua
- [ ] tests/quality/level_5_test.lua
- [ ] tests/quality/quality_test.lua
- [ ] tests/reporting/core_test.lua
- [ ] tests/reporting/formatter_test.lua
- [ ] tests/tools/hash_test.lua
- [ ] tests/tools/interactive_mode_test.lua
- [ ] tests/tools/json_test.lua
- [ ] tests/tools/parser_test.lua
- [ ] tests/tools/filesystem/filesystem_test.lua
- [ ] tests/tools/filesystem/temp_file_integration_test.lua
- [ ] tests/tools/filesystem/temp_file_performance_test.lua
- [ ] tests/tools/filesystem/temp_file_stress_test.lua
- [ ] tests/tools/filesystem/temp_file_test.lua
- [ ] tests/tools/filesystem/temp_file_timeout_test.lua
- [ ] tests/tools/logging/export_test.lua
- [ ] tests/tools/logging/formatter_integration_test.lua
- [ ] tests/tools/logging/logging_test.lua
- [ ] tests/tools/logging/search_test.lua
- [ ] tests/tools/vendor/lpeglabel_test.lua
- [ ] tests/tools/watcher/watch_mode_test.lua
