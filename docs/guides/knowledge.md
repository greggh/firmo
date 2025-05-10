# Firmo Guides Knowledge Snippets

## Purpose

This document serves as a quick reference or cheat sheet, providing concise code snippets for common patterns and techniques demonstrated in the detailed Firmo **Usage Guides** (`docs/guides/`).

## Key Concepts (Pattern Areas)

This document provides quick examples related to:

-   Basic Test Structure (`describe`, `it`, `before`, `after`, `expect`)
-   Resource Cleanup Patterns
-   Asynchronous Testing (`it_async`, `done`)
-   Mocking (`mock`, `stub`)
-   CI Integration Commands (`lua firmo.lua ...`)

## Usage Examples / Patterns

### Basic Test Structure & Error Testing

```lua
--[[
  Basic test structure with setup, teardown, assertions, and error testing.
  Assumes firmo, describe, it, expect, before, after, test_helper are available.
]]
local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after
local test_helper = require("lib.tools.test_helper") -- Needed for error capture

describe("Calculator", function()
  local calculator

  before(function()
    calculator = {
      add = function(a, b) return a + b end,
      subtract = function(a, b) return a - b end
      -- No divide method assumed for error test
    }
  end)

  it("adds numbers", function()
    expect(calculator.add(2, 2)).to.equal(4)
  end)

  it("handles errors", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      -- Simulate error for missing method or invalid operation
      error("Division by zero")
    end)()
    expect(err).to.exist()
    expect(err.message).to.match("Division by zero")
  end)
end)
```

### Resource Cleanup Pattern

```lua
--[[
  Using before/after for resource setup and teardown.
  Assumes firmo, describe, it, expect, before, after, database are available.
]]
describe("Database tests", function()
  local db

  before(function()
    db = require("database") -- Placeholder for your db module
    db.connect()
  end)

  after(function()
    db.disconnect()
  end)

  it("saves data", function()
    local id = db.insert({ data = "test" })
    local result = db.find(id)
    expect(result.data).to.equal("test")
  end)
end)
```

### Async Pattern

```lua
--[[
  Defining and waiting for an asynchronous test.
  Assumes firmo, it_async, expect, start_async_operation are available.
]]
local firmo = require("firmo") -- Assuming firmo provides it_async globally
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local start_async_operation -- Placeholder for your async function

describe("Async Operations", function()
  it_async("handles async operations", function(done)
    start_async_operation(function(result) -- Your async function call
      expect(result).to.exist()
      done() -- Signal completion
    end)
  end)
end)

```

### Mocking Pattern

```lua
--[[
  Using a mock object with stubbed methods.
  Assumes firmo, describe, it, expect, before are available.
]]
local mocking = require("lib.mocking")
local firmo = require("firmo") -- For describe, it, expect, before
local describe, it, expect, before = firmo.describe, firmo.it, firmo.expect, firmo.before
local create_service -- Placeholder for your service constructor

describe("Service tests", function()
  local service, mock_db

  before(function()
    mock_db = mocking.mock({}) -- Mock an empty table or mock the actual db dependency
    service = create_service(mock_db) -- Assuming this function uses the db object
  end)

  it("processes data", function()
    -- Stub the query method on the mock
    mock_db:stub("query"):returns({ rows = 5 })
    local result = service.process()
    expect(result.count).to.equal(5)
    -- Optionally verify call
    local success, err = mock_db:verify()
    expect(success).to.be_truthy(err and err.message or "Verify failed")
  end)
end)
```

### CI Integration Commands

```bash
# Run tests with coverage
lua firmo.lua --coverage tests/

# Generate HTML and JSON report files (via reporting module)
lua firmo.lua --coverage --format html,json tests/

# Run with quality checks at level 3
lua firmo.lua --quality --quality-level=3 tests/

# Run tests filtering by name pattern "integration"
lua firmo.lua --filter integration tests/
```

## Related Components / Modules

For more detailed explanations and examples, refer to the specific usage guides:

-   **Guides Index:** [`docs/guides/README.md`](README.md)
-   **Core Testing:** [`docs/guides/core.md`](core.md)
-   **Assertions:** [`docs/guides/assertion.md`](assertion.md)
-   **Mocking:** [`docs/guides/mocking.md`](mocking.md)
-   **Async Testing:** [`docs/guides/async.md`](async.md)
-   **CI Integration:** [`docs/guides/ci_integration.md`](ci_integration.md)
-   **Coverage:** [`docs/guides/coverage.md`](coverage.md)
-   **Quality:** [`docs/guides/quality.md`](quality.md)
-   **Reporting:** [`docs/guides/reporting.md`](reporting.md)
-   **Configuration:** [`docs/guides/central_config.md`](central_config.md)
