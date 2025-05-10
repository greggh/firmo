# scripts/utilities Knowledge

## Purpose

The `scripts/utilities/` directory serves as a location for auxiliary or more specialized standalone Lua scripts that support the development and maintenance of the Firmo framework. These scripts might be less frequently used or more specific in function compared to those found in the parent `scripts/` directory. Currently, the primary script residing here is `all_tests.lua`.

## Key Concepts (`all_tests.lua`)

- **Test Suite Manifest (`all_tests.lua`):** This script functions as a "manifest" file. Its sole purpose is to explicitly `require` a large collection of individual test files from the `tests/` directory, effectively defining a comprehensive test suite for the Firmo project.
- **Structure (`all_tests.lua`):** It uses Firmo's `describe()` function to logically group the required test files by the area of functionality they cover (e.g., "Core", "Coverage", "Tools", "Reporting"). Within each `describe` block, it uses standard Lua `require("path.to.test_file")` statements to load and execute the tests defined in those files.
- **Execution Method (`all_tests.lua`):** **Crucially**, this script is **not** intended to be run directly via `lua scripts/utilities/all_tests.lua`. Instead, it is designed to be **passed as an argument** to the main Firmo test runner entry point (`test.lua` or `scripts/runner.lua`). For example: `lua firmo.lua scripts/utilities/all_tests.lua`. The test runner executes this script within its environment, causing all the required test files to be loaded and run under Firmo's control.
- **Path Handling & Maintenance (`all_tests.lua`):** The script includes comments and some conditional `require` paths (using `fs.file_exists`) suggesting that the locations of test files might change over time. This highlights that `all_tests.lua` requires manual maintenance to keep its `require` paths accurate as the `tests/` directory structure evolves.

## Usage Examples / Patterns

### Running the Comprehensive Test Suite (`all_tests.lua`)

```bash
# Run the full suite of tests defined in all_tests.lua
lua firmo.lua scripts/utilities/all_tests.lua

# Run the full suite with specific Firmo options (e.g., coverage)
lua firmo.lua --coverage scripts/utilities/all_tests.lua

# Run the full suite with a pattern filter (applied by the runner)
lua firmo.lua --pattern "filesystem" scripts/utilities/all_tests.lua
```

## Related Components / Modules

- **Source File:** `scripts/utilities/all_tests.lua`
- **Parent Directory Overview:** `scripts/knowledge.md`
- **Firmo Test Runner Entry Point:** `test.lua` (typically calls `scripts/runner.lua`)
- **Firmo Test Runner Logic:** `scripts/runner.lua` (and `lib/core/runner.lua`)
- **Main Tests Directory:** `tests/` (contains the files required by `all_tests.lua`)

## Best Practices / Critical Rules (Optional)

- **Keep `all_tests.lua` Updated:** When test files are added, removed, renamed, or moved within the `tests/` directory structure, the corresponding `require()` statements in `scripts/utilities/all_tests.lua` **must be updated manually** to ensure the comprehensive suite remains accurate and functional.
- **Use Case for `all_tests.lua`:** This script is most useful for ensuring complete test coverage runs, typically in Continuous Integration (CI) environments or for periodic full regression checks during development. For day-to-day development and faster feedback, running specific test files or subdirectories directly (e.g., `lua firmo.lua tests/core/`) is often more efficient.

## Troubleshooting / Common Pitfalls (Optional)

- **`require` Errors when running `all_tests.lua`:**
    - **Symptom:** The test run fails immediately with an error like `module 'tests/some/path/some_test' not found`.
    - **Cause:** `scripts/utilities/all_tests.lua` contains a `require()` statement pointing to a test file that has been moved, renamed, or deleted.
    - **Solution:** Edit `scripts/utilities/all_tests.lua`, find the incorrect `require()` statement, and update the path to match the test file's current location or remove the line if the test file was intentionally deleted.
- **Test Failures when running `all_tests.lua`:**
    - **Symptom:** The test runner executes `all_tests.lua` but reports failures within specific tests.
    - **Cause:** The failure lies within the logic of the individual test file(s) being required by `all_tests.lua`, not typically within `all_tests.lua` itself (unless it's a `require` error as above).
    - **Solution:** Examine the Firmo test runner's output to identify which specific test file and test case (`it` block) failed. Debug the failing test file directly.
