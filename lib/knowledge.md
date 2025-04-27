# Firmo Library (`lib/`) Knowledge

## Purpose

This document provides a high-level overview of the `lib/` directory structure, which contains all core framework modules and tools for Firmo. It also outlines key principles for developers working within this directory.

## Key Components (Subdirectories)

The `lib/` directory is organized into several key areas:

-   **`core/`:** Fundamental framework components including the central configuration (`central_config`), error handling (`error_handler`), test definition (`test_definition`), core runner logic (`runner`), module reset (`module_reset`), type checking (`type_checking`), and versioning (`version`).
-   **`assertion/`:** The standalone expect-style assertion system (`expect`).
-   **`async/`:** Asynchronous testing utilities (`it_async`, `await`, `wait_until`, `parallel_async`).
-   **`coverage/`:** Code coverage tracking system (based on LuaCov debug hooks).
-   **`mocking/`:** Mocking system providing spies, stubs, and mocks.
-   **`quality/`:** Test quality validation framework (partially implemented).
-   **`reporting/`:** Report generation system with various formatters (HTML, JSON, JUnit, LCOV, etc.).
-   **`tools/`:** General-purpose utility modules including `benchmark`, `cli`, `codefix`, `date`, `discover`, `filesystem` (with `temp_file`), `hash`, `interactive`, `json`, `logging` (with `export`, `search`, `formatter_integration`), `markdown`, `parallel`, `parser`, `test_helper`, and `watcher`. Also contains `vendor/` for third-party libraries.

## Core Principles / Guidelines

When developing modules within the `lib/` directory, adhere to the following:

-   **Central Configuration:** ALWAYS use `lib/core/central_config` for all configuration settings. Provide defaults and register module schemas. NEVER use module-specific config tables or hardcoded values.
-   **Error Handling:** ALWAYS use the `lib/core/error_handler` system. Return `nil, error_object` for failures. Use `error_handler.try` or `safe_io_operation` for risky calls. Validate inputs.
-   **No Special Cases:** Ensure solutions are general-purpose and handle all inputs consistently. AVOID code specific to certain files or scenarios. Fix root causes, don't add workarounds.
-   **Focused Modules:** Keep modules focused on a single responsibility. Use clean abstractions and well-defined interfaces between modules.
-   **Documentation:** Document all public APIs using JSDoc/Luau-style annotations (`---@class`, `---@field`, `---@param`, `---@return`, etc.). Update documentation when changing code.
-   **Testing:** Add comprehensive tests for all public functionality, including edge cases and error conditions. Ensure tests are independent.
-   **Dependencies:** Minimize external dependencies. Place any required third-party code in `lib/tools/vendor/` and document its source and license.
-   **Logging:** Use the `lib/tools/logging` module for structured logging, especially for debug information.
-   **Filesystem:** Use the `lib/tools/filesystem` module for all file I/O to ensure cross-platform compatibility and proper error handling.

## Related Components / Modules

-   **Architecture Overview:** [`docs/firmo/architecture.md`](../docs/firmo/architecture.md)
-   **Developer Knowledge Base:** [`docs/knowledge.md`](../docs/knowledge.md)
-   **Contributing Guide:** [`CONTRIBUTING.md`](../CONTRIBUTING.md)
