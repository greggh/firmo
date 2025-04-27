# lib/tools/error_handler Knowledge

## Purpose

The `lib/tools/error_handler` module provides a centralized and standardized system for creating, handling, logging, and inspecting errors throughout the Firmo framework. It ensures that errors are reported consistently, includes contextual information to aid debugging, and intelligently manages error logging behavior, especially suppressing expected errors during test runs. Consistent use of this module is crucial for the stability and maintainability of the framework.

## Key Concepts

- **Standardized Error Object:** The core of the system is a structured error object, typically a Lua table with the following key fields:
    - `message` (string): Human-readable description of the error.
    - `category` (string): A classification from `M.CATEGORY` (e.g., `VALIDATION`, `IO`).
    - `severity` (string): An indication of impact from `M.SEVERITY` (e.g., `ERROR`, `FATAL`).
    - `timestamp` (number): Unix timestamp when the error was created.
    - `traceback` (string, optional): Stack traceback captured at the point of error creation (if enabled).
    - `context` (table, optional): A key-value table holding arbitrary contextual information relevant to the error (e.g., function arguments, file paths).
    - `cause` (any, optional): The original error (which might be another error object or a raw value) that triggered this error.
    - `source_file` (string, optional): The source file where the error was generated.
    - `source_line` (number, optional): The line number where the error was generated.
    *Note: Error objects have a `__tostring` metamethod that simply returns the `message` field.*

- **Error Categories & Severities:** Predefined constants classify errors:
    - `M.CATEGORY`: `VALIDATION`, `IO`, `PARSE`, `RUNTIME`, `TIMEOUT`, `MEMORY`, `CONFIGURATION`, `UNKNOWN`, `TEST_EXPECTED`. These help categorize the nature of the problem. `TEST_EXPECTED` is crucial for test environments.
    - `M.SEVERITY`: `FATAL` (unrecoverable), `ERROR` (serious), `WARNING` (needs attention), `INFO`. This indicates the impact.

- **Error Creation:** While `M.create` is the base function, specialized constructors are preferred:
    - `M.validation_error(msg, ctx)`: For input validation failures (Category: `VALIDATION`).
    - `M.io_error(msg, ctx, cause)`: For filesystem/network errors (Category: `IO`).
    - `M.parser_error(msg, ctx, cause)`: For parsing failures (Category: `PARSE`).
    - `M.runtime_error(msg, ctx, cause)`: For general runtime issues (Category: `RUNTIME`).
    - `M.fatal_error(msg, cat, ctx, cause)`: For critical, unrecoverable errors (Severity: `FATAL`).
    - `M.test_expected_error(msg, ctx, cause)`: For errors deliberately triggered in tests (Category: `TEST_EXPECTED`).
    - Others include `timeout_error`, `config_error`, `not_found_error`.

- **Protected Execution (`M.try`):** This is the **cornerstone pattern** for handling potential errors safely in Firmo.
    - Signature: `local success, result_or_err = error_handler.try(function_to_call, arg1, arg2, ...)`
    - Behavior: It calls `function_to_call` using `pcall`.
        - If the function succeeds, it returns `true` followed by any return values from the function.
        - If the function errors, `pcall` catches the error. `M.try` then standardizes this into an error object (if it isn't already one), logs it via `M.log_error`, and returns `false, error_object`.
    - **This pattern should be used around almost any call that might fail.**

- **Safe I/O (`M.safe_io_operation`):** A specialized wrapper built on `M.try` specifically for filesystem operations.
    - Signature: `local result, err = M.safe_io_operation(fs_func, file_path, context?, transform_result?)`
    - Behavior: Calls `fs_func` (e.g., `fs.read_file`). If it returns an error, `safe_io_operation` automatically creates an `M.CATEGORY.IO` error, adds the `file_path` and any provided `context` to the error object, logs it, and returns `nil, error_object`. An optional `transform_result` function can process the successful result before returning.
    - **This is the required way to handle filesystem operations.**

- **Throwing/Asserting:**
    - `M.throw(msg, cat, sev, ctx, cause)`: Creates an error, logs it, then immediately throws it using `error()`. Should be used sparingly, typically only at entry points or when recovery isn't feasible.
    - `M.rethrow(err, ctx?)`: Takes an existing error, optionally merges new context, logs the combined error, and re-throws it using `error()`. Useful for adding context as errors propagate up the call stack.
    - `M.assert(condition, msg, cat?, ctx?, cause?)`: Checks `condition`. If falsey, creates an error (default Category: `VALIDATION`), logs it, and throws it using Lua's `assert()` or `error()` depending on configuration.

- **Integrated Logging (`M.log_error`):** Errors handled by `M.try`, `M.throw`, etc., are automatically passed to `M.log_error`, which then uses `lib/tools/logging`. This function implements complex suppression logic:
    - **Master Switch:** No logging occurs if `config.log_all_errors` is `false`.
    - **Total Test Suppression:** If `config.in_test_run` is `true` AND `config.suppress_all_logging_in_tests` is `true`, *all* console logging (including errors) is completely skipped. Captured errors are stored internally (`_G._firmo_test_errors`). This is typically enabled by the runner during test execution.
    - **`expect_error` Flag:** If `config.in_test_run` is `true` AND the current test metadata (set via `M.set_current_test_metadata`) has `expect_error = true`, then `ERROR` and `WARNING` severity logs are automatically downgraded to `DEBUG` level. This prevents expected failures from cluttering test output unless debug logging is explicitly enabled.
    - **Category Suppression:** If `config.in_test_run` is `true` AND `config.suppress_test_assertions` is `true` (and `expect_error` is *not* set), errors with category `VALIDATION` or `TEST_EXPECTED` are logged at `DEBUG` level instead of `ERROR` or `WARN`. This quiets noise from expected assertion failures or test-specific errors.

- **Configuration (`M.configure`, `M.configure_from_config`):** The module's behavior can be tuned:
    - `log_all_errors` (boolean): Master switch for logging errors.
    - `capture_backtraces` (boolean): Whether to capture stack traces.
    - `in_test_run` (boolean): **Crucial flag set by the test runner** indicating if tests are running.
    - `suppress_test_assertions` (boolean): Suppress `VALIDATION`/`TEST_EXPECTED` logging in tests (if `expect_error` isn't set).
    - `suppress_all_logging_in_tests` (boolean): Suppress ALL logging during tests (usually set by runner).
    The module integrates with `lib.core.central_config` to load these settings.

- **Test Context Integration:** This is vital for correct logging suppression.
    - `M.set_test_mode(boolean)`: Called by the test runner to set the `in_test_run` flag.
    - `M.set_current_test_metadata(metadata_table | nil)`: Called by the runner before/after each test. The `metadata_table` can include `{ expect_error = true, name = "..." }`, which influences logging via `M.log_error` and `M.is_expected_test_error`.
    - `M.is_expected_test_error(err)`: Checks if an error is expected based on category or `expect_error` metadata.
    - `M.get_expected_test_errors()` / `M.clear_expected_test_errors()`: Manage the list of errors captured during suppression.
    **Crucially, test mode detection relies *only* on explicit calls from the runner, not on unreliable filename matching.**

- **Inspection/Formatting:**
    - `M.is_error(value)`: Checks if a value appears to be a standardized error object.
    - `M.format_error(err, include_traceback?)`: Creates a detailed, multi-line string representation of an error object, suitable for display.

## Usage Examples / Patterns

### Pattern 1: Primary Error Handling with `M.try` (MOST COMMON)

```lua
--[[
  Safely call a function that might return an error or throw one.
]]
local error_handler = require("lib.tools.error_handler")
local my_module = require("lib.my_module")

-- Assume my_module.do_something(arg) might return (result, nil) or (nil, err_object)
-- or might throw an error.
local success, result_or_err = error_handler.try(my_module.do_something, "some_argument")

if not success then
  -- 'result_or_err' contains the standardized error object
  print("Operation failed: " .. result_or_err.message)
  -- Optionally add more context and rethrow or return the error
  -- return nil, error_handler.rethrow(result_or_err, { stage = "processing" })
  return nil, result_or_err -- Propagate the error object
else
  -- 'result_or_err' contains the successful result
  print("Operation succeeded: " .. tostring(result_or_err))
  return result_or_err
end
```

### Pattern 2: Creating and Returning Specific Errors

```lua
--[[
  Function performing validation and returning a specific error type.
]]
local error_handler = require("lib.tools.error_handler")

local function validate_input(data)
  if type(data) ~= "table" then
    return nil, error_handler.validation_error(
      "Input data must be a table",
      { provided_type = type(data) }
    )
  end
  if not data.id or type(data.id) ~= "number" then
    return nil, error_handler.validation_error(
      "Missing or invalid 'id' field (must be a number)",
      { provided_id = data.id }
    )
  end
  return true -- Indicates success
end

-- Usage:
local is_valid, err = validate_input({ name = "test" })
if not is_valid then
  print("Validation failed: " .. err.message)
  -- err is a standardized error object with category VALIDATION
end
```

### Pattern 3: Using `M.safe_io_operation`

```lua
--[[
  Safely reading a file using the dedicated I/O wrapper.
]]
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem") -- Assume filesystem module exists

local file_path = "data/config.txt"
local content, err = error_handler.safe_io_operation(
  function() return fs.read_file(file_path) end,
  file_path,
  { operation_context = "reading_main_config" }
)

if not content and err then
  -- err is a standardized error object with category IO
  -- and context includes { file_path = "data/config.txt", operation_context = "..." }
  print("Failed to read file: " .. err.message)
  -- Handle error
else
  -- Process file content
  print("File content read successfully.")
end
```

### Pattern 4: Using `M.assert`

```lua
--[[
  Using assert to check preconditions.
]]
local error_handler = require("lib.tools.error_handler")

local function process_user(user_table)
  -- Throws a validation error if user_table is nil or user_table.name is not a string
  error_handler.assert(user_table, "User table cannot be nil")
  error_handler.assert(type(user_table.name) == "string", "User name must be a string",
    error_handler.CATEGORY.VALIDATION, { user_id = user_table.id })

  print("Processing user: " .. user_table.name)
  -- ... proceed with processing ...
end

-- Example call that would throw:
-- error_handler.try(process_user, { id = 123, name = 456 })
```

## Related Components / Modules

- **`lib/tools/error_handler/init.lua`**: The source code implementation of this module.
- **`lib/tools/logging/knowledge.md`**: Used internally by `M.log_error` to perform the actual logging based on configured levels and suppression rules.
- **`lib/core/central_config/knowledge.md`**: The error handler loads its configuration (`log_all_errors`, `in_test_run`, etc.) from the central config system.
- **`scripts/runner.lua` Knowledge**: The test runner is crucially responsible for calling `M.set_test_mode()` and `M.set_current_test_metadata()` to ensure correct error handling behavior during tests.
- **All Other Modules**: Virtually every other module in Firmo *should* use `error_handler.try` or `error_handler.safe_io_operation` to handle potential failures and return standardized errors.

## Best Practices / Critical Rules (Optional)

- **Use `M.try` Extensively:** Wrap *any* function call that might realistically fail (due to external factors, invalid input, internal logic errors) in `error_handler.try`. This is the primary mechanism for robust error handling.
- **Return `nil, error_object`:** Functions that can fail should follow the standard Lua convention of returning `nil` plus an error value on failure. Ensure the error value is a standardized object created by this module.
- **Use Specific Constructors:** When creating an error, use the most specific constructor available (e.g., `M.validation_error`, `M.io_error`) rather than just `M.create`. This improves categorization and allows for more specific handling (like test suppression).
- **Use `M.safe_io_operation` for Filesystem:** Always use this wrapper for operations involving `lib/tools/filesystem` to ensure consistent IO error reporting with file path context.
- **Provide Context:** When creating errors, add relevant information to the `context` table (e.g., function arguments, relevant state variables, file paths). This significantly aids debugging.
- **Don't Overuse `M.throw`:** Only use `M.throw` when immediate termination of the current control flow is necessary and recovery at that level is impossible or undesirable. Prefer returning `nil, err` and letting callers handle it with `M.try`.

## Troubleshooting / Common Pitfalls (Optional)

- **Errors Not Being Logged/Reported:**
    - Check `config.log_all_errors`. Is it `true`?
    - Is `config.in_test_run` unexpectedly `true`?
    - Are test suppression flags (`suppress_all_logging_in_tests`, `suppress_test_assertions`) active when they shouldn't be?
    - Is the error severity below the configured threshold in `lib/tools/logging`?
    - Is the error category being suppressed in test mode (e.g., `VALIDATION`)?
- **Incorrect Error Category:** Ensure you're using the appropriate error constructor (`M.validation_error` vs `M.runtime_error`, etc.) or passing the correct category to `M.create`.
- **Test Suppression Logic Not Working:**
    - Verify the test runner (`scripts/runner.lua`) is correctly calling `M.set_test_mode(true)` before running tests and `M.set_test_mode(false)` after.
    - Verify the runner is correctly calling `M.set_current_test_metadata({...})` before each test (especially with `expect_error = true` if needed) and `M.set_current_test_metadata(nil)` after each test.
    - Check the error category being generated; suppression primarily targets `VALIDATION` and `TEST_EXPECTED` unless `expect_error` is active.
- **Missing Context:** If errors are hard to debug, ensure the code creating the error is adding relevant data to the `context` table.
