# Tests Knowledge


## Directory Structure



- assertions/: Assertion system tests
- async/: Async testing functionality
- core/: Core framework components
- coverage/: Code coverage tracking
- discovery/: Test file discovery
- fixtures/: Common test fixtures
- integration/: Cross-component tests
- mocking/: Mocking system
- parallel/: Parallel execution
- quality/: Test quality validation
- reporting/: Result and coverage reporting
- tools/: Utility modules


## Test Guidelines



- Focus each test on single behavior
- Isolate tests from each other
- Use firmo-style assertions
- Clean up test resources
- Add comments for complex logic
- Use mocks/stubs for isolation


## Running Tests



- All tests: `lua test.lua tests/`
- Specific component: `lua test.lua tests/core/`
- Single file: `lua test.lua tests/core/config_test.lua`
- With options: `lua test.lua --coverage --verbose tests/`


## Test File Organization



1. Module imports
2. Local test utilities
3. Describe blocks for logical grouping
4. Individual test cases
5. Cleanup code


## Error Testing



- Use expect_error flag for error tests
- Use test_helper.with_error_capture()
- Check error existence before assertions
- Use pattern matching for messages
- Clean up resources properly
