# Quality Tests

This directory contains tests for the firmo quality validation system. The quality module evaluates test comprehensiveness beyond simple code coverage.

## Directory Contents

- **quality_test.lua** - Tests for the quality validation module

## Quality Validation Features

The firmo quality module provides:

- Test comprehensiveness scoring
- Assertion density analysis
- Edge case coverage assessment
- Assertion quality evaluation
- Test-to-code mapping
- Mocking usage analysis
- Test isolation evaluation
- Quality reporting in various formats

## Quality Metrics

The quality system evaluates tests across multiple dimensions:

- **Assertion coverage** - How well assertions cover code paths
- **Branch coverage** - Coverage of conditional branches
- **Edge case testing** - Coverage of boundary conditions
- **Mocking appropriateness** - Proper use of test doubles
- **Test isolation** - Independence between tests
- **Assertion specificity** - How precise assertions are

## Quality Levels

Quality validation supports different levels of strictness:

- Level 1 - Basic quality checks
- Level 2 - Standard quality requirements
- Level 3 - Advanced quality metrics
- Level 4 - Comprehensive quality validation
- Level 5 - Rigorous quality standards

## Running Tests

To run all quality tests:
```
lua test.lua tests/quality/
```

To run a specific quality test:
```
lua test.lua tests/quality/quality_test.lua
```

To run tests with quality validation:
```
lua test.lua --quality --quality-level=3 tests/
```

See the [Quality API Documentation](/docs/api/quality.md) for more information.