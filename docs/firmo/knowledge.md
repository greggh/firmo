# Firmo Project Knowledge Index

## Purpose

This document provides a high-level overview and entry point to the various documentation sections within the Firmo project, including API references, usage guides, and internal planning documents. Use this as a starting point to navigate the framework's documentation.

## Key Concepts (Main Documentation Areas)

Firmo's documentation is structured into several key areas:

-   **API Reference (`docs/api/`):** Contains detailed technical documentation for each module's public functions, classes, and configuration options, often generated or verified against source code JSDoc comments. Start here for specific function signatures and parameters. See [`docs/api/README.md`](../api/README.md).

-   **Usage Guides (`docs/guides/`):** Provides practical "how-to" information, best practices, common patterns, and troubleshooting advice for using specific Firmo features or modules. Start here for learning how to use a feature effectively. See [`docs/guides/README.md`](../guides/README.md).

-   **Core Testing:** Fundamental test structure (`describe`, `it`), setup/teardown (`before`, `after`), and test definition options.
    -   Guide: [`docs/guides/core.md`](../guides/core.md)
    -   API: [`docs/api/core.md`](../api/core.md) (Note: Core API is often exposed via `firmo.lua`, see also `docs/api/test_definition.md`)

-   **Assertions:** Verifying test expectations using the `expect()` API.
    -   Guide: [`docs/guides/assertion.md`](../guides/assertion.md)
    -   API: [`docs/api/assertion.md`](../api/assertion.md)

-   **Mocking:** Creating test doubles (spies, stubs, mocks) for isolated testing.
    -   Guide: [`docs/guides/mocking.md`](../guides/mocking.md)
    -   API: [`docs/api/mocking.md`](../api/mocking.md)

-   **Coverage:** Tracking code execution during tests.
    -   Guide: [`docs/guides/coverage.md`](../guides/coverage.md)
    -   API: [`docs/api/coverage.md`](../api/coverage.md)

-   **Quality:** Validating test quality against defined standards.
    -   Guide: [`docs/guides/quality.md`](../guides/quality.md)
    -   API: [`docs/api/quality.md`](../api/quality.md)

-   **Reporting:** Generating reports (HTML, JSON, JUnit, LCOV, etc.) from test, coverage, or quality data.
    -   Guide: [`docs/guides/reporting.md`](../guides/reporting.md)
    -   API: [`docs/api/reporting.md`](../api/reporting.md), [`docs/api/logging_components.md`](../api/logging_components.md) (for formatters)

-   **Async Testing:** Writing tests for asynchronous code.
    -   Guide: [`docs/guides/async.md`](../guides/async.md)
    -   API: [`docs/api/async.md`](../api/async.md)

-   **CLI:** Using the command-line interface (`lua test.lua ...`).
    -   Guide: [`docs/guides/cli.md`](../guides/cli.md)
    -   API: [`docs/api/cli.md`](../api/cli.md), [`docs/api/test_runner.md`](../api/test_runner.md)

-   **Configuration:** Using the central configuration system.
    -   Guide: [`docs/guides/central_config.md`](../guides/central_config.md)
    -   API: [`docs/api/central_config.md`](../api/central_config.md)

-   **Utilities:** Various helper modules.
    -   Filesystem: [`docs/guides/filesystem.md`](../guides/filesystem.md), [`docs/api/filesystem.md`](../api/filesystem.md)
    -   Logging: [`docs/guides/logging.md`](../guides/logging.md), [`docs/api/logging.md`](../api/logging.md), [`docs/api/logging_components.md`](../api/logging_components.md)
    -   Error Handling: [`docs/guides/error_handling.md`](../guides/error_handling.md), [`docs/api/error_handling.md`](../api/error_handling.md)
    -   Module Reset: [`docs/guides/module_reset.md`](../guides/module_reset.md), [`docs/api/module_reset.md`](../api/module_reset.md)
    -   *Other Tools:* Parser, Benchmark, Watcher, Codefix, Discover, JSON, Date, Hash, Markdown, Parallel, Test Helper (See respective `docs/api/` files).

-   **Internal Documentation (`docs/firmo/`):** Contains project planning, architecture decisions, and contribution guidelines specific to the Firmo framework development itself. Key documents include:
    -   [`docs/firmo/plan.md`](plan.md)
    -   [`docs/firmo/architecture.md`](architecture.md)
    -   [`docs/firmo/jsdoc_cleanup_plan.md`](jsdoc_cleanup_plan.md)
    -   [`docs/firmo/knowledge_documentation_standardization_plan.md`](knowledge_documentation_standardization_plan.md)

## Usage Examples / Patterns

Specific usage examples and common patterns are provided within the individual **Usage Guides** and **API Reference** documents linked above. This document serves as an index to find the relevant guide or API doc for the feature you are interested in.

## Related Components / Modules

-   **Project README:** [`README.md`](../../README.md) - Overall project introduction and setup.
-   **Contributing Guide:** [`CONTRIBUTING.md`](../../CONTRIBUTING.md) - Guidelines for contributing to the Firmo project.

