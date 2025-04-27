# API Knowledge Snippets

## Purpose

This document serves as a quick reference or cheat sheet, providing concise code snippets for common API usage patterns across the Firmo framework.

## Key Concepts

This document touches upon key areas of the Firmo API:

-   **Test Structure:** Defining tests using `describe`, `it`, `before`, `after`.
-   **Assertions:** Verifying behavior using the `expect` API.
-   **Async Testing:** Handling asynchronous operations in tests.
-   **Parallel Operations:** Running async functions concurrently.
-   **Module Reset:** Managing module state isolation between tests.
-   **Mocking:** Using test doubles (mocks, stubs).
-   **Coverage & Quality:** Configuring code coverage and quality validation.
-   **Reporting:** Generating reports from test results or coverage data.
-   **Error Handling:** Using the standardized error handling system.

### Key Modules Overview

-   **Core:** Test structure (`describe`, `it`), configuration (`central_config`), module reset (`module_reset`), runner (`runner`), error handling (`error_handler`).
-   **Assertions:** Verification (`expect`).
-   **Async:** Asynchronous operations (`it_async`, `await`, `wait_until`, `parallel_async`).
-   **Coverage:** Code coverage tracking.
-   **Quality:** Test quality validation.
-   **Reporting:** Output format generation (HTML, JSON, JUnit, etc.).
-   **Mocking:** Test doubles (`spy`, `stub`, `mock`).
-   **Tools:** Utilities like `filesystem`, `logging`, `parser`, `test_helper`, `discover`, `benchmark`, etc.

## Usage Examples / Patterns

### Test Structure & Assertions

```lua
--[[
  Basic test structure with setup, teardown, and assertions.
  Assumes firmo, describe, it, expect, before, after are available.
]]
describe("Group", function()
  before(function()
    -- Setup
  end)

  it("test case", function()
    expect(value).to.exist()
    expect(value).to.equal(expected)
    expect(value).to.be.truthy()
    expect(tbl).to.contain.key("id")
    expect(str).to.start_with("prefix")
  end)

  after(function()
    -- Cleanup
  end)
end)
```

### Async Testing

```lua
--[[
  Defining and waiting for an asynchronous test.
  Assumes firmo, it_async, expect, async_operation are available.
]]
local it_async = firmo.it_async -- Import if not global
it_async("async test", function(done)
  async_operation(function(result) -- Your async function call
    expect(result).to.exist()
    done() -- Signal completion
  end)
end)
```

### Parallel Operations

```lua
--[[
  Running multiple async functions concurrently.
  Assumes firmo, parallel_async, await are available.
]]
local parallel_async = firmo.parallel_async
local await = firmo.await
local results = parallel_async({
  function() await(100); return "first" end,
  function() await(200); return "second" end
})
-- results = {"first", "second"}
```

### Module Reset

```lua
--[[
  Resetting modules using the enhanced system.
  This is often handled automatically by the runner if configured.
]]
-- Module Reset (using enhanced system)
local module_reset = require("lib.core.module_reset")
-- Typically configured globally via central_config/runner
-- module_reset.configure({ reset_modules = true })
-- Manually reset all non-protected modules
module_reset.reset_all()
```

### Mocking

```lua
--[[
  Creating a simple mock object and stubbing a method.
]]
-- Mocking
local mocking = require("lib.mocking")
local expect = require("firmo").expect -- Import expect separately
local mock = mocking.mock({}) -- Mock an empty table for simplicity
mock:stub("method", "mocked")
expect(mock.method()).to.equal("mocked")
```

### Coverage & Quality Configuration

```lua
--[[
  Configuring coverage and quality via central_config.
]]
-- Coverage & Quality Configuration (via central_config)
local central_config = require("lib.core.central_config")
central_config.set("coverage.enabled", true)
central_config.set("coverage.include", {"src/*.lua"})
central_config.set("quality.enabled", true)
central_config.set("quality.level", 3)
```

### Reporting

```lua
--[[
  Generating report content and saving it using the reporting module.
]]
-- Reporting (Generating and Saving)
local reporting = require("lib.reporting")
-- Assuming coverage_data exists from a coverage run
if coverage_data then
  local html_content = reporting.format_coverage(coverage_data, "html")
  if html_content then
    -- Requires filesystem module for writing
    local fs = require("lib.tools.filesystem")
    reporting.write_file("./reports/coverage.html", html_content)
  end
end
```

### Error Handling

```lua
--[[
  Using the standard try/catch pattern and testing error conditions.
]]
-- Standard error pattern
local error_handler = require("lib.core.error_handler")
local logger = require("lib.tools.logging").get_logger("example")
local test_helper = require("lib.tools.test_helper")

local success, result, err = error_handler.try(function()
  return risky_operation()
end)
if not success then
  logger.error("Operation failed", {
    error = error_handler.format_error(result), -- Use format_error on the error object
    category = result.category
  })
  -- return nil, result -- Propagate structured error object
end

-- Test error handling
it("handles errors", { expect_error = true }, function()
  local result, err_obj = test_helper.with_error_capture(function()
    return function_that_throws()
  end)()
  expect(err_obj).to.exist()
  expect(err_obj.category).to.equal("VALIDATION")
end)
```

## Related Components / Modules

-   Core Testing: [`docs/guides/core.md`](../guides/core.md), [`docs/api/core.md`](core.md)
-   Assertions: [`docs/guides/assertion.md`](../guides/assertion.md), [`docs/api/assertion.md`](assertion.md)
-   Async: [`docs/guides/async.md`](../guides/async.md), [`docs/api/async.md`](async.md)
-   Mocking: [`docs/guides/mocking.md`](../guides/mocking.md), [`docs/api/mocking.md`](mocking.md)
-   Module Reset: [`docs/guides/module_reset.md`](../guides/module_reset.md), [`docs/api/module_reset.md`](module_reset.md)
-   Coverage: [`docs/guides/coverage.md`](../guides/coverage.md), [`docs/api/coverage.md`](coverage.md)
-   Quality: [`docs/guides/quality.md`](../guides/quality.md), [`docs/api/quality.md`](quality.md)
-   Reporting: [`docs/guides/reporting.md`](../guides/reporting.md), [`docs/api/reporting.md`](reporting.md)
-   Configuration: [`docs/guides/central_config.md`](../guides/central_config.md), [`docs/api/central_config.md`](central_config.md)
-   Error Handling: [`docs/guides/error_handling.md`](../guides/error_handling.md), [`docs/api/error_handling.md`](error_handling.md)
-   Utilities: See relevant API docs in `docs/api/` (e.g., `filesystem.md`, `logging.md`, `parser.md`).
