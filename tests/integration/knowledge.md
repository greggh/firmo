# tests/integration Knowledge

## Purpose

The `tests/integration/` directory is designated within the Firmo project structure to hold **integration tests**. Integration tests differ from unit tests in that they verify the interaction and data flow between multiple distinct modules or components of the framework, ensuring these parts work together correctly as a cohesive system.

Examples of interactions suitable for integration tests include:
- The full workflow from command-line interface (`lib/tools/cli`) parsing, through test discovery (`lib/tools/discover`), execution by the runner (`lib/core/runner`), and final reporting (`lib/reporting`).
- The interaction between the test runner, the coverage module (`lib/coverage`) enabling hooks and collecting data, and the reporting module generating a coverage report.
- The interplay between configuration loading (`lib/core/central_config`) and multiple modules that consume that configuration.

## Key Concepts

- **Scope:** Integration tests focus on the interfaces, contracts, and communication paths between different modules. They aim to catch issues that might arise from incorrect assumptions about how modules interact, data format mismatches, or unexpected side effects when components are used together. This contrasts with unit tests (found in other `tests/*` subdirectories), which typically test a single module in isolation, often using mocks or stubs for dependencies.
- **Current Status:** This directory **currently contains no implemented integration test files**. It serves as a designated placeholder for such tests as they are developed for the Firmo framework.
- **Future Use:** When added, tests in this directory will validate key end-to-end workflows and complex interactions between multiple Firmo subsystems, providing a higher level of confidence in the framework's overall stability.

## Usage Examples / Patterns

**Not Applicable.**

There are currently no integration test scripts within this directory to run or demonstrate. Hypothetical examples showing cross-component testing (like CLI -> Runner -> Reporter) would belong here once implemented.

## Related Components / Modules

Integration tests placed here would typically involve interactions between several key Firmo modules, including but not limited to:

- `lib/core/runner/knowledge.md`: The test execution engine.
- `lib/coverage/knowledge.md`: The code coverage system.
- `lib/reporting/knowledge.md`: The report generation system.
- `lib/tools/cli/knowledge.md`: The command-line interface handler.
- `lib/tools/discover/knowledge.md`: The test file discovery mechanism.
- `lib/assertion/knowledge.md`: Used for making assertions within the tests.
- `lib/core/central_config/knowledge.md`: Configuration management.
- `lib/tools/test_helper/knowledge.md`: Would likely be used for test setup, assertions, and managing temporary resources needed for integration scenarios.
- `tests/knowledge.md`: Overview of the parent test directory.

## Best Practices / Critical Rules (Optional)

*(These apply if/when integration tests are added)*
- **Focus on Interactions:** Design tests to specifically target the communication points and data handoffs between modules.
- **Minimize Mocking:** While some mocking might be unavoidable (e.g., for truly external services), integration tests provide the most value when they use the *real* implementations of the interacting Firmo modules.
- **Robust Setup/Teardown:** Integration tests often require more complex setup (e.g., creating configuration files, setting up directory structures) and careful teardown (e.g., cleaning up temporary files) to ensure isolation. Use `lib/tools/test_helper` extensively.
- **Keep Focused:** Integration tests can become slow and complex. Focus on testing the most critical cross-component workflows rather than trying to achieve exhaustive coverage of all possible interactions.

## Troubleshooting / Common Pitfalls (Optional)

**Not Applicable** due to the current lack of tests in this directory.

*(If/when integration tests are added)*
- Debugging failures would typically involve tracing the execution flow and data transformations across the boundaries of the interacting modules to identify where the communication breaks down or produces incorrect results. This might require more extensive logging or step-through debugging compared to unit tests.
