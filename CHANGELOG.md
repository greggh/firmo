# Changelog


All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


### Added



- Comprehensive test coverage for all formatters:
  - Test suites for HTML, JSON, LCOV, TAP, CSV, and JUnit XML formatters
  - Standardized error handling patterns across all formatters
  - Performance testing with large datasets
  - Configuration validation for all formatter options
  - Data structure normalization testing
  - Edge case handling for all formatters
  - Special character handling in CSV and XML outputs
  - Custom separators and column configuration
  - File operation error testing
  - Empty and malformed data handling
- Advanced mock sequences:
  - Sequential returns with returns_in_sequence() for stubbed functions
  - Multiple return behaviors for sequence exhaustion:
    - Return nil (default)
    - Return custom fallback value
    - Fall back to original implementation
    - Cycling behavior for repeating values
  - Sequence reset functionality
  - Comprehensive documentation and examples
  - Auto-restoration when tests complete
- Enhanced reporting system:
  - Standardized data structures for all report types
  - JUnit XML output format for CI/CD integration
  - Improved HTML coverage reports with syntax highlighting
  - Source code highlighting in HTML reports
  - Test statistics including passes, failures, and pending counts
  - Robust error handling and cross-platform support
  - Auto-save functionality for multiple report formats at once
  - Comprehensive diagnostics for report generation
- Interactive CLI mode for running tests:
  - Full-featured interactive command-line interface
  - Live configuration of test options (tags, filters, focus)
  - Command history and navigation
  - Dynamic test discovery and execution
  - Status display showing current configuration
  - Toggle watch mode from within the interface
  - Integration with codefix module for code quality checks
  - Comprehensive help system with command reference
  - Clear, colorized output for better readability
  - Example script demonstrating interactive mode usage
- Watch mode for continuous testing:
  - Automatic file change detection
  - Continuous test execution
  - Configurable directories to watch
  - Exclusion patterns for ignoring files
  - Debounce mechanism to prevent multiple runs on rapid changes
  - Clear terminal interface with status indicators
  - Support for Ctrl+C to exit watch mode
  - Integration with interactive CLI mode
- Complete documentation overhaul:
  - Standardized three-part structure for all modules (API reference, guide, examples)
  - Added missing guides for all core modules (focus, filtering, output, CLI, core, coverage)
  - Comprehensive examples for all modules showing practical use cases
  - Updated all command references to use current test.lua execution pattern
  - Enhanced README with module relationship explanations
  - Consistent terminology and approach throughout documentation
  - Expanded architectural principles documentation
  - Updated CI integration examples with modern practices


### Fixed



- Expect assertion system now works consistently:
  - Fixed issues with chained assertions (to.be.truthy(), to_not.be.falsey(), etc.)
  - Added proper test coverage for expect assertions
  - Corrected path definitions for all assertion methods
  - Ensured reset() function preserves assertion paths
  - Added comprehensive documentation and examples
  - Command-line options for configuration
  - Example script demonstrating watch mode usage
- Enhanced modular reporting architecture:
  - Centralized reporting module for all output formats
  - Standardized data interfaces between modules
  - Support for multiple report formats (HTML, JSON, LCOV, Summary)
  - Comprehensive error handling and diagnostics
  - Robust fallback mechanisms for reliable report generation
  - Enhanced HTML reports with syntax highlighting and interactive features


### Fixed



- Coverage data flow issues between modules
- File operations with enhanced directory handling
- Module loading with better search paths and fallbacks
- Report generation with better error detection and recovery
- Cross-platform compatibility issues in file paths
- Reset function for proper state management between test runs


### Improved



- TAP formatter enhancements:
  - TAP v13 compliance verification
  - YAML diagnostics integration
  - Proper line range grouping
  - Customizable indentation
  - Configurable thresholds
  - Function coverage reporting
- CSV formatter enhancements:
  - Custom column definitions
  - Configurable separators
  - Special character escaping
  - Line-level and file-level output modes
  - Summary row support
  - Optional headers
  - Nested field handling
- Version bumped to 0.7.5
- Coverage tracking with better source file detection
- Input validation throughout the reporting process
- Directory creation with multiple fallback methods
- Error reporting with detailed diagnostic output
- File path normalization for better pattern matching
- Command-line interface with more options and better help documentation
- Updated `CLAUDE.md` internal documentation:
  - Revised assertion documentation to match current `expect`-style implementation, including many newly documented assertions (numeric, string, table, error, date, async, etc.).
  - Corrected "Test Directory Structure" to reflect the actual layout.
  - Updated "Project Structure" with a detailed overview.
  - Rewrote "Coverage Module Architecture" to describe the current debug hook system, replacing the outdated instrumentation description.
- Completed comprehensive review and update of all example files (`examples/*.lua`) based on `docs/firmo/examples_cleanup_plan.md`. Ensured consistency with current standards for JSDoc, central configuration, error handling, temporary file usage, assertions, and test execution. Removed deprecated patterns. Created a new `docs/guides/examples.md` index file listing all examples with brief descriptions.
- Initiated a comprehensive refactoring of all example files (`examples/*.lua`, `examples/*.md`) based on the inventory in `docs/firmo/examples_inventory.md` to align with current project standards. Key updates include:
  - Adding missing JSDoc comments.
  - Standardizing configuration via `lib.core.central_config`.
  - Replacing manual temporary file/directory management with `lib.tools.filesystem.temp_file` or `lib.tools.test_helper`.
  - Removing direct modifications of `package.path`.
  - Removing direct usage of `lib.coverage`, deferring to the test runner.
  - Ensuring consistent use of `expect`-style assertions.
  - Updating module usage (e.g., `fs`, `error_handler`) per current APIs.
  - Updating CLI examples to use the standard `lua test.lua ...` pattern.
## [0.7.4] - 2025-03-18


### Added



- Module management utilities:
  - `reset_module(module_name)` to reload modules and ensure a clean state
  - `with_fresh_module(module_name, test_fn)` to run tests with freshly loaded modules
  - Global `reset_module` and `with_fresh_module` functions when using `expose_globals()`
- Enhanced async testing capabilities:
  - `parallel_async()` for running multiple async operations in parallel
  - Return value from `wait_until()` for consistent API design
  - Better error handling in timeout scenarios


### Fixed



- `wait_until()` error handling to properly throw errors on timeout
- Reduced boilerplate in tests with proper module reset utilities
- Improved async testing ergonomics with parallel execution support


## [0.7.0] - 2025-03-05


### Added



- Enhanced mocking system with advanced verification options:
  - Argument matchers for flexible verification:
    - Type-based matchers (`string()`, `number()`, `table()`, etc.)
    - Content-based matchers (`table_containing()` for partial table matching)
    - Custom matchers for domain-specific validation
    - `any()` matcher for ignoring specific arguments
  - Call sequence verification:
    - `verify_sequence()` to check exact order of method calls
    - `called_before()` and `called_after()` for relative ordering
    - Argument matching within sequence verification
    - Detailed error messages for sequence failures
  - Expectation API for clearer test setup:
    - `expect(method).to.be.called.times(n)` for count expectations
    - `expect(method).to.be.called.with(args)` for argument expectations
    - `expect(method).to.be.called.after(other)` for ordering
    - `expect(method).to.not_be.called()` for negative expectations
    - Chainable fluent interface for readable tests
  - Enhanced error reporting for verification failures
  - New example file demonstrating all new mocking features


### Changed



- Replaced timestamp-based call ordering with sequence-based tracking:
  - More deterministic verification of call order
  - No longer dependent on system clock precision
  - Consistent behavior across different systems and speeds
  - Backward compatible with existing tests


### Fixed



- Improved argument comparison for table values in mocking system
- Better error messages for expectation failures with detailed diffs
- Enhanced mock cleanup to prevent test cross-contamination


## [0.6.1] - 2025-03-05


### Fixed



- Bug in excluded tests where test functions in `xit` were still being executed
- Proper state reset between test files in CLI runner
- Focus mode state management for consistent behavior when running multiple files
- Excluded test handling for both direct execution and CLI runner
- More robust implementation for `xdescribe` to ensure excluded tests never run


## [0.6.0] - 2025-03-05


### Added



- Focused and excluded test support:
  - `fdescribe` and `fit` for focused test blocks and tests
  - `xdescribe` and `xit` for excluded test blocks and tests
  - Focus mode automatically activates when focused tests are present
  - Skip tracking for excluded tests with reasons
- Enhanced error messages:
  - Detailed diffs for table comparisons showing missing/extra keys
  - Better formatting for error messages across all assertion types
  - Improved string representation for complex data structures
  - Context-aware error messages with more details
- Improved output formatting options:
  - Configurable output styles with `firmo.format()`
  - Multiple output formats: normal, dot, compact, summary, detailed
  - Customizable indentation (tabs or spaces)
  - Colorized output with intelligent context
  - New dot mode for compact test progress display
  - Stack trace option for detailed error information
  - Summary-only mode for CI environments
- Enhanced CLI options:
  - Format selection with `--format` argument
  - Indentation control with `--indent` argument
  - Color control with `--no-color` flag
  - Improved help documentation and examples
  - Better visual separation for test runs


### Fixed



- Improved error handling in describe blocks
- Enhanced context display in test summaries
- Better skipped test reporting with reasons


### Added



- Fork from bjornbytes/firmo to enhance functionality
- GitHub Actions CI workflow for testing on multiple Lua versions
- GitHub structure with templates and community health files
- Documentation improvements with modern markdown format
- Test directory with initial test suite
- Examples directory with sample usage
- Enhanced README with new feature descriptions
- Automatic test discovery for finding and running test files
- Test filtering and tagging system:
  - Tag tests with `firmo.tags()` function
  - Filter by tag with `firmo.only_tags()`
  - Filter by name pattern with `firmo.filter()`
  - Command-line filtering with `--tags` and `--filter` flags
  - Skip tracking for filtered tests
- Enhanced reporting with clearer test summaries
- Improved CLI with more flexible options
- Async testing support:
  - `firmo.async()` for wrapping async test functions
  - `firmo.await()` for waiting in tests
  - `firmo.wait_until()` for condition-based waiting
  - `firmo.it_async()` for simplified async test declaration
  - Configurable timeouts and error handling
  - Comprehensive examples in examples/async_example.lua
- Comprehensive mocking system:
  - Enhanced spy functionality with call tracking
  - Stub system for replacing functions
  - Mock objects for complete dependency isolation
  - Automatic cleanup through `with_mocks` context
  - Verification of mock expectations
  - Advanced call tracking with argument matching
  - Detailed examples in examples/mocking_example.lua
- Enhanced assertions:
  - Table assertions:
    - Key and value containment checking
    - Subset validation
    - Exact key checking
  - String assertions:
    - Prefix and suffix validation
  - Type assertions:
    - Callable, comparable, and iterable checking
  - Numeric assertions:
    - Greater/less than comparisons
    - Range checking with `be_between`
    - Approximate equality for floating point
  - Error assertions:
    - Enhanced error pattern matching
    - Error type verification
  - Complete validation examples for complex data structures
- Comprehensive documentation:
  - Detailed API reference for all features
  - Getting started guide
  - Structured documentation organization
  - Command-line interface documentation
  - Usage examples for all major features
  - Code examples for common use cases


## [0.2.0] - Original firmo


This is where the fork begins. Original [lust project](https://github.com/bjornbytes/lust) features:

### Features



- Nested describe/it blocks
- Before/after handlers
- Expect-style assertions
- Function spies
- Support for console and non-console environments

  [Unreleased]: https://github.com/greggh/firmo/compare/v0.2.0...HEAD
  [0.2.0]: https://github.com/bjornbytes/lust/tree/master
