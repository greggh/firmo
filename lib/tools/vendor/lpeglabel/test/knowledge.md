# lib/tools/vendor/lpeglabel/test Knowledge

## Purpose

This document outlines the testing approach for the vendored LPegLabel library, located at `lib/tools/vendor/lpeglabel`, within the context of the Firmo project.

## Key Concepts

- **No Dedicated Firmo Tests:** This specific directory (`lib/tools/vendor/lpeglabel/test`) **does not currently contain any dedicated test files** that are executed as part of Firmo's own test suite. The original `lpeglabel` library might have its own tests within its source distribution, but these are not actively run by Firmo's testing process.

- **Reliance on Upstream Testing:** The core correctness and functionality of the `lpeglabel` library itself are primarily assumed based on the testing performed by the original library authors in the upstream project (Sérgio Medeiros, Roberto Ierusalimschy).

- **Implicit Testing via Parser Module:** The most significant testing of `lpeglabel` within the Firmo project occurs *indirectly*. The `lib/tools/parser` module relies heavily on `lpeglabel` to define and execute its Lua grammar. Therefore, the unit and integration tests written for the `lib/tools/parser` module (located in `tests/tools/parser/`) serve as functional tests for the `lpeglabel` features actually utilized by Firmo. If `lpeglabel` (especially the C module) fails to load or behaves incorrectly, the parser tests are expected to fail.

## Usage Examples / Patterns

Not Applicable. There are no specific test scripts in this directory to run via Firmo's test runner.

## Related Components / Modules

- **`lib/tools/vendor/lpeglabel/knowledge.md`**: Documentation for the main vendored LPegLabel library, explaining its purpose and loading mechanism.
- **`lib/tools/parser/knowledge.md`**: Documentation for the Firmo Lua parser, which is the primary consumer of the LPegLabel library.
- **`tests/tools/parser/`** (Directory): Contains the tests for the parser module, which implicitly test the usage of LPegLabel within Firmo.

## Best Practices / Critical Rules (Optional)

Not Applicable for this directory.

## Troubleshooting / Common Pitfalls (Optional)

Not Applicable for this directory. Any issues related to `lpeglabel` functionality within Firmo would typically be discovered and debugged through failures in the `lib/tools/parser` module or its tests. Refer to the troubleshooting sections in `lib/tools/vendor/lpeglabel/knowledge.md` (for loading/building issues) and `lib/tools/parser/knowledge.md` (for parsing issues).
