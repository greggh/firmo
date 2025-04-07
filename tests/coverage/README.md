# Coverage Tests

This directory contains tests for the firmo coverage system v3. The v3 coverage system is a complete rewrite of the previous debug hook-based implementation, using source code instrumentation to provide more accurate and detailed coverage information.

## Testing Philosophy

The coverage system tests follow a component-based testing approach:

1. **Unit Tests**: Each component is tested in isolation
2. **Integration Tests**: Components are tested working together
3. **End-to-End Tests**: The entire system is tested as a whole

## Test Structure

The test directory structure mirrors the component structure of the coverage system:

```
tests/coverage/
├── assertion/               # Tests for assertion integration
│   └── hook_test.lua        # Tests for the assertion hook
├── runtime/                 # Tests for runtime tracking
│   ├── data_store_test.lua  # Tests for coverage data storage
│   └── tracker_test.lua     # Tests for runtime tracking
├── loader/                  # Tests for module loading integration
│   └── hook_test.lua        # Tests for the module loader hook
├── instrumentation/         # Tests for code instrumentation
│   ├── parser_test.lua      # Tests for Lua parser
│   ├── transformer_test.lua # Tests for AST transformation
│   └── sourcemap_test.lua   # Tests for source mapping
├── report/                  # Tests for reporting
│   ├── html_test.lua        # Tests for HTML report generation
│   └── json_test.lua        # Tests for JSON report generation
├── integration/             # Integration tests
│   └── coverage_integration_test.lua # End-to-end tests
└── fixtures/                # Test fixtures
    ├── simple_module.lua    # Simple module for testing
    └── complex_module.lua   # Complex module with edge cases
```

## Three-State Coverage Model

The v3 coverage system tracks three distinct states for each line of code:

1. **Covered** (Green): Lines that are both executed AND verified by assertions
2. **Executed** (Orange): Lines that are executed during tests but NOT verified by assertions
3. **Not Covered** (Red): Lines that are not executed at all

The tests verify that all three states are correctly tracked and reported.

## Test-Driven Development

The tests are written using a test-driven development approach:

1. Tests are written before the implementation
2. Each test verifies a specific component behavior
3. Tests guide the implementation of each component

## Running the Tests

To run all coverage tests:

```
lua test.lua tests/coverage/
```

To run a specific component test:

```
lua test.lua tests/coverage/runtime/tracker_test.lua
```

To run tests with coverage enabled (meta-coverage):

```
lua test.lua --coverage tests/coverage/
```

## Implementation Dependencies

When implementing the coverage system, components should be developed in this order:

1. **Data Model**: `data_store.lua` - Core data structures
2. **Runtime Tracking**: `tracker.lua` - Execution and coverage tracking
3. **Parser & Transformer**: Lua code parsing and instrumentation
4. **Module Loading**: Dynamic code instrumentation
5. **Assertion Integration**: Connecting assertions to code
6. **Reporting System**: Visualization and data export

This order matches the test dependency chain and ensures that each component has the necessary dependencies ready when it's implemented.