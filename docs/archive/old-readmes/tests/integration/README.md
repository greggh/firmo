# Integration Tests

This directory contains cross-component integration tests for the firmo framework. These tests verify that different modules work together correctly.

## Purpose

Integration tests ensure that:

- Components interact correctly with each other
- Data flows properly between modules
- System behavior matches expectations when components are combined
- Edge cases are handled correctly at component boundaries
- Configurations affect all relevant components appropriately

## Integration Test Focus Areas

- **Coverage and Reporting** - Verify that coverage data is correctly processed by formatters
- **Async and Parallel** - Ensure async testing works with parallel execution
- **Logging and Reporting** - Validate integration between logging and test reporting
- **Config and Components** - Test configuration propagation to all components
- **Filesystem and Reporting** - Test report generation with filesystem operations
- **Quality and Coverage** - Verify quality metrics with coverage data
- **Discovery and Execution** - Test file discovery with test execution

## Integration Test Patterns

Integration tests typically:

1. Set up multiple components
2. Establish their connections
3. Execute operations that cross component boundaries
4. Verify the end-to-end behavior
5. Clean up resources

## Writing Integration Tests

When writing integration tests:

- Focus on component interactions, not individual component behavior
- Test realistic usage scenarios
- Verify data consistency across component boundaries
- Check error propagation between components
- Test configuration effects across multiple components

## Running Tests

To run all integration tests:
```
lua test.lua tests/integration/
```

To run a specific integration test:
```
lua test.lua tests/integration/coverage_reporting_test.lua
```

See the [Testing Guide](/docs/coverage_repair/testing_guide.md) for more information on integration testing.