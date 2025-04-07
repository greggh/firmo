# Firmo Documentation

[![Version](https://img.shields.io/badge/Version-0.7.4-blue?style=flat-square)](https://github.com/greggh/firmo/releases/tag/v0.7.4)
Welcome to the Firmo documentation. Firmo is a lightweight, powerful testing library for Lua projects, offering a rich set of features while maintaining simplicity and ease of use.

## Documentation Structure

The documentation is organized into three main sections:

1. **API References** - Detailed technical documentation of modules, functions, parameters, and return values
2. **Guides** - Practical how-to guides with explanations and best practices
3. **Examples** - Real-world code examples showing each module in action

## Core Modules

### Test Structure and Organization

- [Core](api/core.md) - Essential test functions (`describe`, `it`, etc.)
- [Focus](api/focus.md) - Focused and excluded tests (`fdescribe`, `fit`, `xdescribe`, `xit`)
- [Filtering](api/filtering.md) - Test filtering and tagging
- [Discovery](api/discovery.md) - Automatic test file discovery

### Assertions and Verification

- [Assertion](api/assertion.md) - Comprehensive assertion capabilities
- [Mocking](api/mocking.md) - Mocking, spying, and stubbing
- [Module Reset](api/module_reset.md) - Module management for clean test state

### Advanced Testing Features

- [Async](api/async.md) - Asynchronous testing support
- [Coverage](api/coverage.md) - Code coverage tracking and reporting
- [Quality](api/quality.md) - Test quality validation
- [Parallel](api/parallel.md) - Parallel test execution

### Output and Reporting

- [Output](api/output.md) - Output formatting options
- [Reporting](api/reporting.md) - Report generation (HTML, JSON, etc.)
- [CLI](api/cli.md) - Command-line interface

### Utilities

- [Filesystem](api/filesystem.md) - File system operations
- [Logging](api/logging.md) - Structured logging
- [Error Handling](api/error_handling.md) - Standardized error handling
- [Central Config](api/central_config.md) - Centralized configuration
- [Temp File](api/temp_file.md) - Temporary file management
- [Watcher](api/watcher.md) - File watching for continuous testing

## Getting Started

New to Firmo? Start with these resources:

1. [Getting Started Guide](guides/getting-started.md) - Learn the basics of Firmo
2. [Core Guide](guides/core.md) - Understanding test structure and organization
3. [Assertion Guide](guides/assertion.md) - How to write effective assertions
4. [Core Examples](examples/core_examples.md) - Basic usage examples

## Running Tests

The standard way to run tests with Firmo is through the central test runner:

```bash
# Run all tests in the tests directory
lua test.lua tests/

# Run tests with coverage
lua test.lua --coverage tests/

# Run tests with specific tags
lua test.lua --tags unit,fast tests/

# Run tests matching a pattern
lua test.lua --filter validation tests/

# Run tests with continuous watching
lua test.lua --watch tests/
```

## Module Relationships

Firmo's architecture consists of several interconnected modules:

- **Core Test Framework** - The foundation that provides test organization and execution
- **Assertion System** - Connects to the core to provide verification capabilities
- **Coverage Module** - Integrates with test execution to track code coverage
- **Reporting System** - Consumes data from tests and coverage to generate reports
- **Utilities** - Support modules that provide functionality to other components

## Architectural Principles

Firmo follows these key principles:

1. **Centralized Configuration** - All settings managed through the central_config system
2. **No Special Case Code** - All solutions are general purpose, avoiding file-specific handling
3. **Clear Error Handling** - Structured error objects with consistent patterns
4. **Modularity** - Well-defined module boundaries with clear responsibilities
5. **Comprehensive Documentation** - Every module has API references, guides, and examples

## Additional Resources

- [CI Integration](guides/ci_integration.md) - Integrating with continuous integration systems
- [Error Handling Guide](guides/error_handling.md) - Understanding error handling patterns
- [Central Config Guide](guides/central_config.md) - Managing framework configuration

## Latest Updates

### Unreleased

- **Enhanced Modular Reporting Architecture**:
  - Centralized reporting module for all output formats
  - Support for multiple report formats (HTML, JSON, LCOV, Summary)
  - Robust fallback mechanisms for reliable report generation
  - Comprehensive error handling and diagnostics
  - Improved file operations and module loading
- **Complete Documentation Overhaul**:
  - Standardized structure for all modules
  - Added guides for all major components
  - Comprehensive examples for all features
  - Updated all references to use current practices
  - Unified terminology and approach throughout

### v0.7.4

- **Module Reset Utilities**: New functions for ensuring clean test state:
  - `reset_module()`: Reset and reload modules between tests
  - `with_fresh_module()`: Run tests with a freshly loaded module instance
- **Enhanced Async Testing**:
  - New `parallel_async()` function for running multiple operations concurrently
  - Improved error handling in `wait_until()` for timeout scenarios
  - Better performance when running multiple async tests

## Quick Links

- [GitHub Repository](https://github.com/greggh/firmo)
- [Issue Tracker](https://github.com/greggh/firmo/issues)
- [Changelog](https://github.com/greggh/firmo/blob/main/CHANGELOG.md)

## Contributing

Contributions are welcome! See the [Contributing Guide](https://github.com/greggh/firmo/blob/main/CONTRIBUTING.md) for details on how to get involved.