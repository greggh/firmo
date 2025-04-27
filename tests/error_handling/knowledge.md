# tests/error_handling Knowledge

## Purpose

The `tests/error_handling/` directory contains a suite of tests designed to validate Firmo's centralized error handling system, implemented in `lib/tools/error_handler`. These tests are crucial for ensuring the robustness and predictability of how errors are created, captured, propagated, logged, and suppressed throughout the framework, particularly within the context of test execution.

## Key Concepts

The tests in this directory cover various facets of the error handling module:

- **Core Functionality (`error_handler_test.lua`):** Focuses on the fundamental operations:
    - Creating errors using the base `create` function and specific constructors like `validation_error`, `io_error`, `runtime_error`, etc. Verifies the correct `category`, `severity`, `message`, and `context` are set.
    - The primary `try` wrapper: Testing its ability to correctly capture return values on success (`true, result...`) and return a standardized error object on failure (`false, error_object`).
    - The `safe_io_operation` wrapper: Testing its specific handling of I/O functions, including automatic context addition (like `file_path`) and IO category assignment.
    - Utility functions like `is_error` (identifying error objects) and `format_error` (generating detailed string representations).

- **Rethrow Logic (`error_handler_rethrow_test.lua`):** Dedicated to testing the `rethrow` function. Verifies that it correctly preserves the original error (`cause`), merges additional context provided during the rethrow, and properly propagates the error up the call stack.

- **Logging Integration (`error_logging_test.lua`, `error_logging_debug_test.lua`):** Examines how the error handler interacts with `lib/tools/logging`.
    - Verifies that errors handled by `try`, `throw`, etc., trigger log messages.
    - Checks that the correct log severity level (e.g., `ERROR`, `WARN`) is used based on the error's severity.
    - Tests how logging behavior changes when the logger's `debug` or `verbose` configuration flags are enabled. These tests might involve mocking the logger to intercept calls.

- **Test Context Suppression (`expected_error_test.lua`, `test_error_handling_test.lua`):** Critically important tests that validate how error logging behaves differently when running inside a test managed by the Firmo runner.
    - Verifying the effect of `error_handler.set_test_mode(true)`.
    - Verifying that setting test metadata via `error_handler.set_current_test_metadata({ expect_error = true })` causes ERROR/WARN level logs for expected errors to be downgraded (usually to DEBUG), thus reducing noise in test output.
    - Testing the internal mechanisms for capturing and retrieving errors that occurred when suppression was active (`get/clear_expected_test_errors`).

- **Core Internals (`core/` subdirectory):** Contains tests likely targeting lower-level helper functions or specific internal mechanisms within the error handler implementation.

## Usage Examples / Patterns (Illustrative Test Snippets)

### Testing `try` Wrapper

```lua
--[[
  Example test verifying the behavior of error_handler.try
]]
local error_handler = require("lib.tools.error_handler")
local expect = require("lib.assertion.expect").expect

it("try should return success and result on success", function()
  local function succeeds() return "OK" end
  local success, result = error_handler.try(succeeds)
  expect(success).to.be_truthy()
  expect(result).to.equal("OK")
end)

it("try should return false and error object on failure", function()
  local function fails() error("Something bad", 0) end -- Level 0 for cleaner trace
  local success, err = error_handler.try(fails)
  expect(success).to_not.be_truthy()
  expect(error_handler.is_error(err)).to.be_truthy()
  expect(err.message).to.equal("Something bad")
  expect(err.category).to.equal(error_handler.CATEGORY.RUNTIME) -- Default category
end)
```

### Testing Error Object Properties

```lua
--[[
  Example test verifying the properties of a created error object.
]]
local error_handler = require("lib.tools.error_handler")
local expect = require("lib.assertion.expect").expect

it("io_error should create error with correct properties", function()
  local original_cause = "Permission denied"
  local context = { filename = "secret.txt" }
  local err = error_handler.io_error("Failed to read", context, original_cause)

  expect(error_handler.is_error(err)).to.be_truthy()
  expect(err.category).to.equal(error_handler.CATEGORY.IO)
  expect(err.severity).to.equal(error_handler.SEVERITY.ERROR)
  expect(err.message).to.equal("Failed to read")
  expect(err.context.filename).to.equal("secret.txt")
  expect(err.cause).to.equal(original_cause)
end)
```

### Testing Logging Suppression (Conceptual)

```lua
--[[
  Conceptual structure of a test verifying log suppression for expected errors.
  Requires mocking the logger.
]]
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging") -- For mocking
local expect = require("lib.assertion.expect").expect
local stub = require("lib.mocking.stub") -- Assuming stubbing mechanism

it("should downgrade error log level if expect_error is true", function()
  local logger_stubs = {}
  logger_stubs.error = stub.spy(logging.get_logger("ErrorHandler")) -- Spy on error method
  logger_stubs.debug = stub.spy(logging.get_logger("ErrorHandler")) -- Spy on debug method

  -- Simulate test context where an error is expected
  error_handler.set_test_mode(true)
  error_handler.set_current_test_metadata({ expect_error = true })

  -- Trigger an error via 'try' which logs internally
  local success, err = error_handler.try(function() error("Expected failure") end)

  -- Assertions
  expect(success).to_not.be_truthy()
  expect(err).to.exist()
  -- Verify logging: debug should have been called, error should NOT
  expect(logger_stubs.debug.calls).to.have_length(1)
  expect(logger_stubs.error.calls).to.be.empty()

  -- Cleanup
  error_handler.set_current_test_metadata(nil)
  error_handler.set_test_mode(false)
  stub.restore_all(logger_stubs)
end)
```

### Testing `rethrow`

```lua
--[[
  Example test verifying error_handler.rethrow preserves cause and merges context.
]]
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local expect = require("lib.assertion.expect").expect

it("rethrow should preserve cause and merge context", function()
  local original_err = error_handler.validation_error("Initial issue", { detail = "abc" })
  local new_context = { stage = "processing" }

  -- Use expect_error to catch the error thrown by rethrow
  local captured_err = test_helper.expect_error(function()
    error_handler.rethrow(original_err, new_context)
  end)

  expect(captured_err).to.exist()
  expect(captured_err.category).to.equal(error_handler.CATEGORY.TEST_EXPECTED) -- Normalization by expect_error
  -- Check the *cause* for the original details
  expect(captured_err.cause).to.equal(original_err)
  -- Check that context was merged (specific context field depends on rethrow implementation)
  expect(captured_err.context).to.have_property("stage", "processing")
  expect(captured_err.context.original_context).to.have_property("detail", "abc")
end)
```

## Related Components / Modules

- **Module Under Test:** `lib/tools/error_handler/knowledge.md` (and `lib/tools/error_handler/init.lua`)
- **Test Files:**
    - `tests/error_handling/error_handler_test.lua`
    - `tests/error_handling/error_handler_rethrow_test.lua`
    - `tests/error_handling/error_logging_test.lua`
    - `tests/error_handling/error_logging_debug_test.lua`
    - `tests/error_handling/expected_error_test.lua`
    - `tests/error_handling/test_error_handling_test.lua`
    - Files in `tests/error_handling/core/`
- **Dependencies & Interactions:**
    - **`lib/tools/logging/knowledge.md`**: The logging module is tightly coupled and its interaction is a key focus of these tests.
    - **`lib/tools/test_helper/knowledge.md`**: Provides `expect_error` and `with_error_capture`, essential tools for testing error conditions.
    - **`scripts/runner.lua` Knowledge**: The test runner is responsible for setting the test mode (`set_test_mode`) and metadata (`set_current_test_metadata`) that control the error handler's behavior during tests; this interaction is implicitly or explicitly tested here.
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Cover All Error Types:** Ensure tests exist for each specific error constructor (validation, IO, runtime, etc.) to verify correct category and severity assignment.
- **Test Context Propagation:** Verify that context provided during error creation, or added via `safe_io_operation` or `rethrow`, is correctly stored and accessible in the final error object.
- **Focus on Test Context Logic:** Pay special attention to tests verifying the log suppression mechanisms (`expect_error` flag, `in_test_run` flag). This logic is complex and crucial for usable test output. Use logger mocking if necessary for precise verification.
- **Verify `safe_io_operation`:** Ensure tests confirm that `safe_io_operation` correctly wraps filesystem calls, adds `file_path` context, and returns the appropriate `IO` category error.

## Troubleshooting / Common Pitfalls (Optional)

- **Incorrect Error Properties (Category, Severity, Context):** Failures in tests checking these properties usually point directly to bugs in the specific error constructor function or in the context merging logic (`rethrow`, `safe_io_operation`).
- **Logging Behavior Mismatches:** If tests checking log levels or suppression fail:
    - Double-check that the test correctly sets the necessary preconditions (e.g., calling `set_test_mode(true)` and `set_current_test_metadata({expect_error = true})`).
    - Verify the `severity` and `category` of the error being triggered.
    - Examine the conditional logic within `error_handler.log_error` to ensure it matches the expected behavior for the given context and error type.
    - Ensure the global logging configuration (e.g., `log_all_errors` flag) isn't interfering unexpectedly.
- **`try`/`rethrow`/`safe_io_operation` Issues:** Failures might indicate problems with the underlying `pcall` usage, how different types of thrown values (strings vs. tables vs. error objects) are captured and normalized, or how context tables are merged. Debugging often involves inspecting the exact value caught by `pcall` within the wrapper function.
