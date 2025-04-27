# Firmo Developer Knowledge Base

## Purpose

This document outlines key architectural principles, implementation guidelines, and important considerations for developers contributing to the Firmo framework. It serves as a high-level guide complementing the detailed architecture and module documentation.

## Key Concepts (Architectural Principles)

-   **Coverage System (Debug Hooks):** The *current* code coverage system integrates LuaCov, which relies on Lua's `debug.sethook`. While instrumentation was previously considered, the current implementation uses debug hooks.
-   **Three-State Coverage (Execution vs. Assertion):** The system aims to distinguish between lines that were merely executed and lines specifically covered by assertions. The `lib/coverage` module tracks execution counts, and the `lib/assertion` module calls `coverage.mark_line_covered` to mark lines associated with passing assertions.
-   **No Special Cases:** Solutions should be general-purpose without special handling for specific files or situations. Core logic should handle all inputs consistently.
-   **Clean Abstractions:** Components must interact through well-defined interfaces. Avoid direct access to internal implementation details of other modules.
-   **Central Configuration:** All modules **must** retrieve configuration settings via the `lib/core/central_config` module. Avoid module-specific config tables or hardcoded values.
-   **Consistent Error Handling:** All modules **must** use the `lib/core/error_handler` system for creating and propagating structured errors, typically using the `nil, error_object` return pattern for functions that can fail.

## Usage Examples / Patterns (Implementation Guidelines)

-   **Parser:** Use the parser (`lib/tools/parser`) for analyzing Lua source code when necessary (e.g., for static analysis in quality checks or potential future instrumentation).
-   **Central Config:** Always use `require("lib.core.central_config").get(...)` to retrieve configuration values, providing sensible defaults. Register module schemas and defaults using `register_module`.
-   **Error Handler:** Use `error_handler.create`, `validation_error`, `io_error`, etc., to generate structured errors. Use `error_handler.try` or `error_handler.safe_io_operation` to wrap potentially failing operations.
-   **Logging:** Use the structured logging system (`lib/tools/logging`). Get a module-specific logger (`logging.get_logger("my_module")`) and log messages with separate context tables (`logger.info("Message", { key = value })`).
-   **Filesystem:** Use the `lib/tools/filesystem` module for all file and directory operations to ensure cross-platform compatibility and integration with error handling/logging.

## Testing Requirements

After making significant changes, developers should typically run:

1.  **All Tests:** `lua test.lua tests/`
2.  **Coverage Check:** `lua test.lua --coverage tests/` (Ensure changes don't negatively impact coverage significantly).
3.  **(Optional) Quality Check:** `lua test.lua --quality tests/` (If quality checks are configured).

## Troubleshooting / Common Pitfalls

-   **Debug Hook Limitations:** Be aware that debug hooks can have performance overhead, especially with complex code or extensive coroutine usage. `lib/coverage` aims to mitigate this, but complex scenarios might require investigation.
-   **Parser Stack Size:** The LPegLabel parser used by `lib/tools/parser` may require an increased stack size (`lpeg.setmaxstack(...)`) for very complex or deeply nested Lua code.
-   **Configuration Caching:** Modules should ideally react to configuration changes via `central_config.on_change` rather than caching configuration values indefinitely at startup.

## Related Components / Modules

-   **Architecture Overview:** [`docs/firmo/architecture.md`](architecture.md)
-   **Project Plan:** [`docs/firmo/plan.md`](plan.md)
-   **Contributing Guide:** [`CONTRIBUTING.md`](../../CONTRIBUTING.md)
-   **API Reference:** [`docs/api/README.md`](../api/README.md)
-   **Usage Guides:** [`docs/guides/README.md`](../guides/README.md)
