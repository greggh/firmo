# tests/tools Knowledge

## Purpose

The `tests/tools/` directory is dedicated to housing the automated tests for the various utility modules found within the `lib/tools/` directory of the Firmo framework. These tests are essential for verifying the correctness, robustness, error handling, and platform compatibility of tools responsible for fundamental operations like filesystem access, logging, data handling (JSON, hashing), code parsing, command-line interaction, file watching, and more.

## Key Concepts

- **Component-Based Testing:** Tests within this directory are generally organized according to the specific tool module they target. For tools with extensive tests, a dedicated subdirectory is used (e.g., `tests/tools/filesystem/`). For simpler tools, a single standalone test file might exist directly within `tests/tools/` (e.g., `tests/tools/hash_test.lua`).
- **Scope:** The goal of these tests is to ensure that each utility module in `lib/tools/` functions correctly according to its documented API, handles expected inputs and edge cases properly, and integrates seamlessly with other core Firmo components like `error_handler` and `filesystem`.

## Usage Examples / Patterns (General Test Structure)

Tests for tool modules typically follow Firmo's standard BDD structure, often utilizing `test_helper` for setup and `error_handler` wrappers for safe execution.

```lua
-- General structure for testing a function in a tool module
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
-- Replace 'tool_name' with the actual tool module name
local tool_module = require("lib.tools.tool_name")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper") -- Often used for setup

describe("Tool Module: tool_name", function()

  it("should perform its function correctly under normal conditions", function()
    -- 1. Setup (e.g., define input data, use test_helper to create temp files)
    local input_data = "valid input"
    local expected_output = "processed output"

    -- 2. Execute the function being tested, using appropriate error handling
    local success, result = error_handler.try(tool_module.some_function, input_data)
    -- OR for filesystem I/O:
    -- local result, err = error_handler.safe_io_operation(tool_module.some_io_function, ...)

    -- 3. Assertions
    expect(success).to.be_truthy() -- Check no error occurred if using try
    -- expect(err).to_not.exist() -- Check no error occurred if using safe_io_operation
    expect(result).to.equal(expected_output) -- Check the result
    -- Add more specific assertions as needed...

    -- 4. Cleanup (if necessary, and not handled by test_helper or after_each)
  end)

  it("should handle specific error conditions gracefully", function()
    -- 1. Setup for an error condition
    local invalid_input = nil

    -- 2. Execute using error testing helpers (or check error return)
    local err = test_helper.expect_error(function()
      -- Call function expected to throw, OR call function that returns nil, error
      local success_flag, result_or_err = error_handler.try(tool_module.some_function, invalid_input)
      if not success_flag then error(result_or_err) end -- Make try() failure visible to expect_error
    end, "Expected error message pattern") -- Optional message pattern

    -- 3. Assertions about the error
    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION) -- Verify correct error type
  end)

end)
```

## Related Components / Modules (Directory Index)

This directory contains tests for the following tool modules (either in subdirectories or as standalone files):

- **`tests/tools/filesystem/knowledge.md`**: Contains tests for `lib/tools/filesystem` (core file/dir operations and temporary file management).
- **`tests/tools/logging/knowledge.md`**: Contains tests for the `lib/tools/logging` system (levels, outputs, context, formatters, rotation).
- **`tests/tools/vendor/knowledge.md`**: Contains tests (or overview) related to third-party libraries vendored in `lib/tools/vendor`.
- **`tests/tools/watcher/knowledge.md`**: Contains tests for the polling-based file watcher `lib/tools/watcher`.
- **`hash_test.lua`**: Contains tests for the FNV-1a hashing functions in `lib/tools/hash`.
- **`interactive_mode_test.lua`**: Contains tests for the interactive REPL provided by `lib/tools/interactive`.
- **`json_test.lua`**: Contains tests for the JSON encoder/decoder in `lib/tools/json`.
- **`parser_test.lua`**: Contains tests for the Lua code parser (`lib/tools/parser`) based on LPegLabel.

*(Note: Tests for other modules under `lib/tools/` such as `benchmark`, `cli`, `codefix`, `date`, `discover`, `markdown`, `parallel`, `test_helper` might reside here under different filenames, be located in other top-level `tests/` subdirectories, or may currently be missing).*

- **Parent Test Directory:** `tests/knowledge.md`
- **Library Directory:** `lib/tools/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Use `test_helper` for Setup:** Utilize `test_helper` functions like `with_temp_test_directory` to create isolated and controlled environments, especially crucial for testing filesystem-related tools.
- **Mandatory Error Handling Tests:** Explicitly test how utility functions handle invalid inputs, missing dependencies, or runtime failures. Verify that they return appropriate, standardized errors (using `error_handler` objects) or fail predictably. Use `error_handler.safe_io_operation` correctly in tests involving filesystem calls.
- **Platform Considerations:** For tools interacting heavily with the operating system (filesystem, process execution), consider potential cross-platform differences and include tests for various scenarios if possible.
- **Mock Dependencies:** When testing a tool that depends on other complex Firmo modules or external services, consider using mocks (`lib/mocking`) to isolate the test to the tool's specific logic.

## Troubleshooting / Common Pitfalls (Optional)

- **Dependency Errors (`require` fails):** Tests might fail if the tool being tested cannot load its own dependencies (like `error_handler`, `filesystem`, or vendored libs). Ensure tests are run from the project root so `package.path` is set correctly. Check for typos in `require` statements.
- **Incorrect Test Setup:** Failures are often caused by incorrect test preconditions (e.g., temporary files not having the expected content, mock data being wrong). Use logging or intermediate assertions within the test's setup phase to verify preconditions.
- **Filesystem/Permission Issues:** Tests for filesystem tools (`filesystem`, `watcher`, `temp_file`) are particularly sensitive to permissions in the test environment. Ensure the process has rights to read/write/delete in temporary locations.
- **Platform-Specific Failures:** A test might pass on Linux but fail on Windows (or vice-versa) if the tool or the test itself relies on platform-specific commands, path formats, or behaviors not fully abstracted by `lib/tools/filesystem`.
- **Incorrect Error Handling in Tests:** Ensure tests correctly check for errors using the `success, result_or_err` pattern from `error_handler.try` or the `result, err` pattern from `safe_io_operation`, and make assertions on the `err` object when failure is expected.
