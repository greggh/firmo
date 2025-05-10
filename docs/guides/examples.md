# Firmo Examples Index

This document provides an index and brief description of the example files available in the `examples/` directory. These examples showcase various features and usage patterns of the Firmo testing framework.

To run most examples (those containing tests), use the Firmo test runner:
```bash
lua firmo.lua examples/<example_file_name>.lua
```
Some examples are procedural scripts demonstrating specific features and should be run directly:
```bash
lua examples/<example_file_name>.lua
```
Refer to the `@usage` section within each example file for specific instructions.

## Core Testing Features

- **examples/basic_example.lua**: Demonstrates the fundamental structure of a test file using `describe`, `it`, and `expect` for a simple calculator module.
- **examples/comprehensive_testing_example.lua**: Shows a more complex test suite structure with nested `describe` blocks, `before`/`after` hooks, and various assertion types for a simulated `FileProcessor` class.
- **examples/tagging_example.lua**: Illustrates how to apply tags to tests and suites using `firmo.tags()` and how to filter tests based on tags using runner flags (`--tags`, `--exclude-tags`).
- **examples/focused_tests_example.lua**: Demonstrates using `fit` and `fdescribe` to focus execution on specific tests/suites, and `xit`/`xdescribe` to skip tests/suites. Includes an intentionally failing test to showcase table diff output.
- **examples/module_reset_example.lua**: Explains the concept of test isolation and demonstrates how Firmo's module reset system prevents state leakage between tests (using a simulated manual reset for contrast).
- **examples/test_helper_example.lua**: Showcases utilities from `lib.tools.test_helper` for testing error conditions (`expect_error`, `with_error_capture`), managing temporary test directories (`with_temp_test_directory`), and testing async errors (`expect_async_error`).
- **examples/temp_file_management_example.lua**: Provides a detailed look at `lib.tools.filesystem.temp_file` for creating temporary files/directories with automatic cleanup (`create_with_content`, `create_temp_directory`, `with_temp_file`, `with_temp_directory`) and manual management (`register_*`, `cleanup_all`).

## Assertions

- **examples/assertions_example.lua**: Provides a comprehensive overview of Firmo's built-in `expect()` assertions, covering existence, type, equality, truthiness, strings, numbers, tables, and basic error checks.
- **examples/extended_assertions_example.lua**: Demonstrates additional assertions for collections (length, empty), numeric properties (positive, negative, integer), string casing, object structure (properties, schema), function behavior (change, increase, decrease), and deep equality.
- **examples/specialized_assertions_example.lua**: Showcases assertions for specific data types or scenarios, including date validation/comparison (`.be_date`, `.be_iso_date`, `.be_before`, etc.), advanced regex matching (`.match_regex`), and asynchronous operations (`.complete`, `.resolve_with`, `.reject`).

## Asynchronous Testing

- **examples/basic_async.lua**: Introduces asynchronous testing with `describe_async`, `it_async`, and `await`. Shows synchronous tests and hooks within an async suite.
- **examples/advanced_async.lua**: Covers more complex async scenarios including nested `describe_async`, focus/skip (`fit_async`, `fdescribe_async`, `xit_async`, `xdescribe_async`), `wait_until`, and testing expected async errors.
- **examples/nested_async.lua**: Focuses specifically on the execution order of `before`/`after` hooks within nested `describe_async` blocks.
- **examples/parallel_async_example.lua**: Demonstrates running multiple independent asynchronous operations concurrently using `parallel_async` and collecting their results.

## Mocking

- **examples/mocking_example.lua**: Provides a comprehensive guide to Firmo's mocking system, including spies (`spy`), mocks (`mock`), stubs (`stub`), verifying calls, testing error conditions, and using the `with_mocks` context manager.
- **examples/mock_sequence_example.lua**: Focuses on verifying the *order* of mock calls, explaining the benefits over timestamp-based tracking and demonstrating manual sequence verification using the mock's `.calls` array.

## Reporting

- **examples/report_example.lua**: Demonstrates generating various report formats (HTML, JSON, LCOV, TAP, CSV, JUnit, Cobertura, Summary) using mock data passed to `reporting.format_coverage`. **Note:** Uses mock data, does not perform live coverage.
- **examples/auto_save_reports_example.lua**: Shows how to use `reporting.auto_save_reports` to automatically generate and save multiple report types based on configuration, including path templates.
- **examples/formatter_config_example.lua**: Illustrates how to configure options for specific formatters (e.g., HTML theme, JSON pretty print) using the `central_config` system.
- **examples/custom_formatters_example.lua**: Guides users on creating, registering, and using custom report formatters by extending the base `Formatter` class.
- **examples/reporting_filesystem_integration.lua**: Highlights the interaction between the reporting module and the filesystem module for saving reports and ensuring directories exist.
- **examples/html_report_example.lua**: Focuses specifically on generating HTML test result reports (using mock results data).
- **examples/html_coverage_example.lua**: Focuses on generating HTML *coverage* reports and explains how different code states (covered, executed-not-covered, uncovered) are visualized.
- **examples/json_output_example.lua**: Contains tests with various outcomes (pass, fail, skip) intended to showcase the structure of the JSON test results format, often used for inter-process communication.
- **examples/json_example.lua**: Demonstrates both the JSON coverage report formatter and the direct use of the `lib.tools.json` module for encoding/decoding Lua tables and interacting with JSON files.
- **examples/junit_example.lua**: Shows how to generate JUnit XML test result reports, configure options, and provides CI integration examples (Jenkins, GitHub Actions, GitLab CI).
- **examples/cobertura_example.lua**: Demonstrates generating Cobertura XML *coverage* reports using mock data.
- **examples/cobertura_jenkins_example.lua**: Focuses on generating Cobertura XML coverage reports suitable for Jenkins, including path mapping options, and provides CI integration examples (Jenkins, SonarQube, GitHub Actions).
- **examples/lcov_example.lua**: Shows how to generate LCOV format coverage reports, configure options, and provides CI integration examples (Codecov, Coveralls, SonarQube, Jenkins, GitLab CI).
- **examples/tap_example.lua**: Explains the Test Anything Protocol (TAP) format and demonstrates generating TAP *test results*.
- **examples/csv_example.lua**: Demonstrates generating CSV format *test results* reports and configuring options like delimiters and columns.
- **examples/summary_example.lua**: Focuses on generating text-based summary *coverage* reports suitable for terminal output and configuring verbosity/color options.

## Tools & Utilities

- **examples/central_config_example.lua**: Provides a detailed guide to using the central configuration system (`lib.core.central_config`), including loading files, programmatic setting, environment handling, and best practices.
- **examples/filesystem_example.lua**: Demonstrates various functions of the `lib.tools.filesystem` module, such as reading/writing files, checking existence, creating directories, listing contents, filtering, and path manipulation.
- **examples/hash_example.lua**: Shows how to use `lib.tools.hash` to generate hash digests for strings and files, useful for change detection or caching keys.
- **examples/logging_example.lua**: Introduces the basic usage of the `lib.tools.logging` system, including getting loggers, logging at different levels, and adding structured context.
- **examples/type_checking_example.lua**: Demonstrates advanced type validation functions from `lib.core.type_checking`, like `is_exact_type`, `is_instance_of`, `implements`, `contains`, and `has_error`.
- **examples/parser_example.lua**: Showcases the `lib.tools.parser` module for parsing Lua code into an AST, validating the AST, converting it back to string, and performing basic analysis (finding executable lines, functions).
- **examples/benchmark_example.lua**: Demonstrates using the `lib.tools.benchmark` module for measuring function performance, comparing implementations, tracking memory usage, and performing basic statistical analysis.
- **examples/error_handling_example.lua**: Provides a comprehensive overview of Firmo's standardized error handling system (`lib.tools.error_handler`), covering error creation, propagation, `try`/`catch` patterns, safe I/O, and testing error conditions.

## Runner Features

- **examples/watch_mode_example.lua**: Contains a simple test suite intended to be run with the `--watch` flag to demonstrate automatic test re-runs on file changes.
- **examples/interactive_mode_example.lua**: Includes placeholder tests and usage instructions related to the conceptual interactive mode (`--interactive` flag). *(Note: Interactive mode is not fully implemented)*.
- **examples/parallel_execution_example.lua**: Demonstrates running multiple test *files* in parallel using `firmo.parallel.run_tests` (procedural example comparing timings).
- **examples/parallel_json_example.lua**: Shows parallel test file execution specifically configured to use the JSON results format for inter-process communication and result aggregation.
- **examples/quality_example.lua**: Illustrates the *concept* of different test quality levels and how a runner *could* filter based on them (using `describe` names as conceptual markers). *(Note: Quality filtering is partially implemented)*.
- **examples/codefix_example.lua**: Demonstrates the conceptual `codefix` tool for checking/fixing Lua code quality issues (uses external tools like StyLua/Luacheck implicitly). *(Note: Codefix module is partially implemented)*.
- **examples/markdown_fixer_example.lua**: Placeholder example related to the Markdown fixing script/tool. *(Note: Markdown fixer is partially implemented)*.

