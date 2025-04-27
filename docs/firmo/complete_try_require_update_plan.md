# Plan: Consolidate `try_require` Usage

## Goal

Replace all local implementations of `try_require` functions throughout the codebase with the standardized `require("lib.tools.error_handler").try_require` function. This ensures consistent error handling and module loading behavior across the Firmo framework.

## Steps

1.  **Review Each File:** Iterate through the list of files provided below.
2.  **Identify Incorrect Loading:** For each file, search for:
    a) Local function definitions matching `local function try_require(...)`.
    b) Calls to `pcall(require, module_name)` used for loading _mandatory_ dependencies (which should fail fatally if loading fails).
3.  **Refactor if Found:**
    - If an incorrect loading pattern (local `try_require` or `pcall` for mandatory dependency) is found:
      - Add `local error_handler = require("lib.tools.error_handler")` near the top of the file with other requires, if not already present. Ensure `local error_handler = require("lib.tools.error_handler")` and `local logging = require("lib.tools.logging")` are also present and required _directly_. These two (`error_handler`, `logging`) are the _only_ mandatory dependencies loaded with direct `require`.
      - Replace all call sites of the local `try_require(module_name)` _or_ the incorrect `pcall(require, module_name)` _or_ incorrect direct `require(mandatory_module)` (for anything other than `error_handler`, `logging`) with the standard pattern:
      ```lua
      -- Standard pattern for all mandatory requires except error_handler, logging
      local module = error_handler.try_require(module_name)
      ```
      - **Crucially, verify the expected return values.** The standard `error_handler.try_require` returns `(module, nil)` on success and `(nil, error_object)` on failure. Ensure the calling code correctly handles this pattern (e.g., `local mod = error_handler.try_require(...)`). Adjust the calling code if its expectations were different based on the old local implementation (e.g., if it only expected `mod` or `nil`).
      - Remove the original local `try_require` function definition _or_ the incorrect `pcall(require, ...)` call.
    - If no incorrect loading pattern is found, no changes are needed for this specific task in that file.
4.  **Basic Validation:** After modifying a file, perform a basic Lua syntax check: `luac -p <file_path>`. If specific tests exist for the modified file's functionality, consider running those individual tests.
5.  **Mark Completion:** After reviewing and potentially refactoring each file, mark it as complete by changing `[ ]` to `[x]` in the list below.

## Files to Review

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
