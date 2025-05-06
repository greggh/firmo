# pcall/xpcall Migration Plan Initial Review

**IMPORTANT**
**This plan does not edit code. Do not modify lua files or markdown documents.**
**IMPORTANT**
**ONLY EDIT THIS PLAN FILE TO DOCUMENT THE CHANGES NEEDED**

## Current State Analysis

1. Audit all existing `pcall`/`xpcall` usage across codebase, specifically the files listed below.
2. Document current error handling patterns
3. Identify cases where errors are logged/suppressed

## Migration Benefits

- Structured error objects for better debugging
- Standardized error categories/severity levels
- Consistent logging format
- Better error context propagation

## Migration Review

1. Document all needed changes or the fact that no changes are needed, under every file listed below
   as a bulletted list.

## File-by-File Analysis

Each file will be evaluated on:

- Need for structured errors
- Error logging requirements
- Test environment needs
- Interface boundaries

## File list

- [x] firmo.lua
- [x] test.lua
- [x] lib/assertion/init.lua
- [x] lib/async/init.lua
- [x] lib/core/central_config.lua
- [x] lib/core/fix_expect.lua
- [x] lib/core/init.lua
- [x] lib/core/module_reset.lua
- [x] lib/core/runner.lua
- [x] lib/core/test_definition.lua
- [x] lib/core/type_checking.lua
- [x] lib/core/version.lua
- [x] lib/coverage/init.lua
- [x] lib/mocking/init.lua
- [x] lib/mocking/mock.lua
- [x] lib/mocking/spy.lua
- [x] lib/mocking/stub.lua
- [x] lib/quality/init.lua
- [x] lib/quality/level_checkers.lua
- [x] lib/reporting/format.lua
- [x] lib/reporting/init.lua
- [x] lib/reporting/schema.lua
- [x] lib/reporting/validation.lua
- [x] lib/reporting/formatters/base.lua
- [x] lib/reporting/formatters/cobertura.lua
- [x] lib/reporting/formatters/coverage_formatters.lua
- [x] lib/reporting/formatters/csv.lua
- [x] lib/reporting/formatters/html.lua
- [x] lib/reporting/formatters/init.lua
- [x] lib/reporting/formatters/json.lua
- [x] lib/reporting/formatters/junit.lua
- [x] lib/reporting/formatters/lcov.lua
- [x] lib/reporting/formatters/summary.lua
- [x] lib/reporting/formatters/tap.lua
- [x] lib/reporting/formatters/tap_results.lua
- [x] lib/samples/calculator.lua
- [x] lib/tools/benchmark/init.lua
- [x] lib/tools/cli/init.lua
- [x] lib/tools/codefix/init.lua
- [x] lib/tools/date/init.lua
- [x] lib/tools/discover/init.lua
- [x] lib/tools/error_handler/init.lua
- [x] lib/tools/filesystem/init.lua
- [x] lib/tools/filesystem/temp_file.lua
- [x] lib/tools/filesystem/temp_file_integration.lua
- [x] lib/tools/hash/init.lua
- [x] lib/tools/interactive/init.lua
- [x] lib/tools/json/init.lua
- [x] lib/tools/logging/export.lua
- [x] lib/tools/logging/formatter_integration.lua
- [x] lib/tools/logging/init.lua
- [x] lib/tools/logging/search.lua
- [x] lib/tools/markdown/init.lua
- [x] lib/tools/parallel/init.lua
- [x] lib/tools/parser/grammar.lua
- [x] lib/tools/parser/init.lua
- [x] lib/tools/parser/pp.lua
- [x] lib/tools/parser/validator.lua
- [x] lib/tools/test_helper/init.lua
- [x] lib/tools/vendor/lpeglabel/init.lua
- [x] lib/tools/watcher/init.lua
- [x] scripts/check_assertion_patterns.lua
- [x] scripts/check_syntax.lua
- [x] scripts/cleanup_temp_files.lua
- [x] scripts/find_print_statements.lua
- [x] scripts/fix_markdown.lua
- [x] scripts/monitor_temp_files.lua
- [x] scripts/runner.lua
- [x] scripts/version_bump.lua
- [x] scripts/version_check.lua
- [x] scripts/utilities/all_tests.lua
- [x] tests/debug_structured_results.lua
- [x] tests/simple_test.lua
- [x] tests/assertions/assertion_module_integration_test.lua
- [x] tests/assertions/assertion_module_test.lua
- [x] tests/assertions/assertions_test.lua
- [x] tests/assertions/expect_assertions_test.lua
- [x] tests/assertions/extended_assertions_test.lua
- [x] tests/assertions/specialized_assertions_test.lua
- [x] tests/assertions/truthy_falsey_test.lua
- [x] tests/async/async_test.lua
- [x] tests/async/async_timeout_test.lua
- [x] tests/core/config_test.lua
- [x] tests/core/firmo_test.lua
- [x] tests/core/module_reset_test.lua
- [x] tests/core/tagging_test.lua
- [x] tests/core/type_checking_test.lua
- [x] tests/coverage/coverage_test.lua
- [x] tests/coverage/hook_test.lua
- [x] tests/discovery/discovery_test.lua
- [x] tests/error_handling/error_handler_rethrow_test.lua
- [x] tests/error_handling/error_handler_test.lua
- [x] tests/error_handling/error_logging_debug_test.lua
- [x] tests/error_handling/error_logging_test.lua
- [x] tests/error_handling/helper.lua
- [x] tests/error_handling/test_error_handling_test.lua
- [x] tests/error_handling/core/expected_error_test.lua
- [x] tests/fixtures/common_errors.lua
- [x] tests/fixtures/modules/test_math.lua
- [x] tests/mocking/mock_test.lua
- [x] tests/mocking/spy_test.lua
- [x] tests/mocking/stub_test.lua
- [x] tests/parallel/parallel_test.lua
- [x] tests/performance/large_file_test.lua
- [x] tests/performance/performance_test.lua
- [x] tests/quality/level_1_test.lua
- [x] tests/quality/level_2_test.lua
- [x] tests/quality/level_3_test.lua
- [x] tests/quality/level_4_test.lua
- [x] tests/quality/level_5_test.lua
- [x] tests/quality/quality_test.lua
- [x] tests/reporting/core_test.lua
- [x] tests/reporting/formatter_test.lua
- [x] tests/tools/hash_test.lua
- [x] tests/tools/interactive_mode_test.lua
- [x] tests/tools/json_test.lua
- [x] tests/tools/parser_test.lua
- [x] tests/tools/filesystem/filesystem_test.lua
- [x] tests/tools/filesystem/temp_file_integration_test.lua
- [x] tests/tools/filesystem/temp_file_performance_test.lua
- [x] tests/tools/filesystem/temp_file_stress_test.lua
- [x] tests/tools/filesystem/temp_file_test.lua
- [x] tests/tools/filesystem/temp_file_timeout_test.lua
- [x] tests/tools/logging/export_test.lua
- [x] tests/tools/logging/formatter_integration_test.lua
- [x] tests/tools/logging/logging_test.lua
- [x] tests/tools/logging/search_test.lua
- [x] tests/tools/vendor/lpeglabel_test.lua
- [x] tests/tools/watcher/watch_mode_test.lua
