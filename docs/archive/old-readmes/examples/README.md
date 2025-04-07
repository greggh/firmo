# Firmo Examples

This directory contains examples demonstrating how to use the Firmo testing framework. Below is a guide to help you find the right examples for your needs.

## Core Examples

These examples demonstrate the fundamental capabilities of Firmo:

- [Basic Example](basic_example.lua): Simple introduction to Firmo's testing functionality
- [Comprehensive Testing Example](comprehensive_testing_example.lua): Complete example showing best practices for testing a module
- [Assertions Example](assertions_example.lua): Guide to all assertion functions available in Firmo

## Testing Features

- [Mocking Example](mocking_example.lua): Demonstrates how to mock objects and functions
- [Mock Sequence Example](mock_sequence_example.lua): Shows sequence-based tracking for mocks
- [Async Example](async_example.lua): Shows how to test asynchronous code
- [Parallel Async Example](parallel_async_example.lua): Demonstrates parallel test execution
- [Tagging Example](tagging_example.lua): Illustrates how to use tags to organize and filter tests
- [Focused Tests Example](focused_tests_example.lua): Shows how to run specific test subsets
- [Extended Assertions Example](extended_assertions_example.lua): Shows specialized assertion types
- [Specialized Assertions Example](specialized_assertions_example.lua): Domain-specific assertions

## Reporting and Output

- [Report Example](report_example.lua): Demonstrates the different report formats available
- [HTML Report Example](html_report_example.lua): Shows how to generate HTML test reports
- [Custom Formatters Example](custom_formatters_example.lua): Illustrates creating custom report formats
- [Formatter Config Example](formatter_config_example.lua): Shows how to configure formatters

## Code Coverage

- [Coverage Example](coverage_example.lua): Introduction to code coverage tracking
- [HTML Coverage Example](html_coverage_example.lua): Shows how to generate HTML coverage reports
- [Instrumentation Example](instrumentation_example.lua): Demonstrates the instrumentation-based coverage system

## Configuration and Infrastructure

- [Central Config Example](central_config_example.lua): Shows how to use the centralized configuration system
- [Error Handling Example](error_handling_example.lua): Demonstrates standardized error handling patterns
- [Filesystem Example](filesystem_example.lua): Shows file operations with proper error handling
- [CLI Tool Example](cli_tool_example.lua): Demonstrates building command-line interface tools
- [Benchmark Example](benchmark_example.lua): Shows performance testing and analysis

## Tools and Utilities

- [Module Reset Example](module_reset_example.lua): Shows how to reset module state between tests
- [Temp File Management Example](temp_file_management_example.lua): Shows how to manage temporary test files
- [Watch Mode Example](watch_mode_example.lua): Demonstrates continuous testing
- [Codefix Example](codefix_example.lua): Shows automatic code correction utilities
- [Interactive Mode Example](interactive_mode_example.lua): Demonstrates the interactive testing mode

## Running Examples

All examples can be run with the standard test command:

```
lua test.lua examples/example_name.lua
```

For example, to run the basic example:

```
lua test.lua examples/basic_example.lua
```

## Recommended Starting Order

If you're new to Firmo, we recommend exploring the examples in the following order:

1. [Basic Example](basic_example.lua)
2. [Assertions Example](assertions_example.lua)
3. [Central Config Example](central_config_example.lua)
4. [Error Handling Example](error_handling_example.lua)
5. [Coverage Example](coverage_example.lua)
6. [Report Example](report_example.lua)
7. [Mocking Example](mocking_example.lua)
8. [Comprehensive Testing Example](comprehensive_testing_example.lua)

## Organization

The examples directory has been consolidated to provide clear, non-redundant demonstrations of Firmo's capabilities. Each example focuses on a specific aspect of the framework, and comprehensive examples combine multiple features.

For detailed report examples, check the [reports](reports) directory which contains sample outputs in various formats.