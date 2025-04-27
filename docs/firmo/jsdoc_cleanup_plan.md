# JSDoc Cleanup and Standardization Plan

## Phase 1: Preparation

1. Review project architecture docs (docs/firmo/architecture.md) to understand module relationships
2. Establish standard JSDoc style guide based on:
   - Existing well-documented files as examples
   - Project memory rules regarding documentation
3. Write this style guide to the file docs/firmo/jsdoc_standards.md
   a. Include:

   - JSDoc tags to use
   - Formatting rules (spacing, alignment)
   - Examples of good documentation
   - Rules for polymorphism documentation

   b. Ensure it is comprehensive but concise

   c. Relevant Context From Files

   - Example file patterns (firmo.lua, lib/core/init.lua, lib/assertion/init.lua) show:
   - Luau-style type annotations (---@type, ---@class)
   - Detailed function documentation blocks
   - Header documentation listing all class fields
   - Consistent use of --- prefix for all documentation lines

## Phase 2: File Processing

4. Create processing pipeline for the 130 files:
   a. Categorize files by module/functionality area
   b. Do not assign priority to any files.
   c. Process in batches of 10 files

## Phase 3: Documentation Updates

**CRITICAL RULE: ONLY modify or add lines starting with `---`. DO NOT change any other Lua code logic, structure, or syntax. The goal is solely to update documentation comments.**

5. For each file:
   a. Verify current functionality matches header documentation

   - Review top-of-file class/field documentation (---@class, ---@field)
   - Update header comments to match current behavior
   - Remove any obsolete or incorrect documentation

   b. Add/update JSDoc for all functions following standards:

   - Proper @params with types
   - @returns documentation
   - @throws where applicable
   - @description for complex functions

   c. Remove obsolete documentation
   d. Ensure consistent formatting (spacing, alignment)
   e. Preserve diagnostic disable comments (per rule)
   f. Document any polymorphism patterns found

6. VERY IMPORTANT: After each file is updated, mark that file as completed in the list below.

## Phase 4: Quality Assurance

6. Create validation checks:
   a. Automated scanning for JSDoc coverage
   b. Spot-check random files in each module
   c. Verify no special cases were introduced (per rule)
   d. Confirm centralized configuration is properly documented

## Phase 5: Finalization

7. Update project documentation:
   a. Refresh architecture.md if API changes were found
   b. Update any documentation references to files that were modified in docs/api and docs/guides

## List of files to review for updates

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
- [x] lib/tools/vendor/lpeglabel/init.lua
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

## Phase 6: Documentation File Review

**CRITICAL RULE: ONLY modify the documentation (`.md`) files in `docs/api` and `docs/guides`. DO NOT edit any Lua code (`.lua` files) to match the documentation. The Lua code and its JSDoc are the source of truth.**

This phase involves reviewing the API and Guide documentation files to ensure they accurately reflect the code state after the JSDoc updates.

- [x] docs/api/assertion.md
- [x] docs/api/async.md
- [x] docs/api/benchmark.md
- [x] docs/api/central_config.md
- [x] docs/api/cli.md
- [x] docs/api/codefix.md
- [x] docs/api/core.md
- [x] docs/api/coverage.md
- [x] docs/api/discover.md
- [x] docs/api/error_handling.md
- [x] docs/api/filesystem.md
- [x] docs/api/filtering.md
- [x] docs/api/focus.md
- [x] docs/api/hash.md
- [x] docs/api/interactive.md
- [x] docs/api/json.md
- [x] docs/api/knowledge.md <!-- NOTE: Source file lib/tools/knowledge/init.lua is empty; MD summarizes other modules. -->
- [x] docs/api/logging.md
- [x] docs/api/logging_components.md
- [x] docs/api/markdown.md
- [x] docs/api/mocking.md
- [x] docs/api/module_reset.md
- [x] docs/api/output.md
- [x] docs/api/parallel.md
- [x] docs/api/parser.md
- [x] docs/api/quality.md
- [x] docs/api/reporting.md
- [x] docs/api/temp_file.md
- [x] docs/api/test_helper.md
- [x] docs/api/test_runner.md
- [x] docs/api/watcher.md
- [x] docs/guides/assertion.md
- [x] docs/guides/async.md
- [x] docs/guides/benchmark.md
- [x] docs/guides/central_config.md
- [x] docs/guides/ci_integration.md
- [x] docs/guides/cli.md
- [x] docs/guides/codefix.md
- [x] docs/guides/core.md
- [x] docs/guides/coverage.md
- [x] docs/guides/discover.md
- [x] docs/guides/error_handling.md
- [x] docs/guides/filesystem.md
- [x] docs/guides/filtering.md
- [x] docs/guides/focus.md
- [x] docs/guides/getting-started.md
- [x] docs/guides/hash.md
- [x] docs/guides/interactive.md
- [x] docs/guides/json.md
- [x] docs/guides/knowledge.md <!-- NOTE: Summary document, snippets reviewed/corrected. -->
- [x] docs/guides/logging.md
- [x] docs/guides/logging_components.md
- [x] docs/guides/markdown.md
- [x] docs/guides/mocking.md
- [x] docs/guides/module_reset.md
- [x] docs/guides/output.md
- [x] docs/guides/parallel.md
- [x] docs/guides/parser.md
- [x] docs/guides/quality.md
- [x] docs/guides/reporting.md
- [x] docs/guides/temp_file.md
- [x] docs/guides/test_helper.md
- [x] docs/guides/test_runner.md
- [x] docs/guides/watcher.md
