# Coverage Module Knowledge

## Purpose

This document outlines key internal concepts, implementation patterns, and design considerations for the `lib/coverage` module, intended for developers working on or understanding Firmo's code coverage system. The system uses a debug hook approach based on LuaCov.

## Key Concepts

-   **Debug Hook (`debug.sethook`):** The core mechanism relies on Lua's built-in `debug.sethook` with the `"l"` (line) event. The hook function (`lib/coverage/hook.lua`) is called by the Lua VM for each executed line of Lua code.
-   **LuaCov Integration:** The design is heavily based on LuaCov, reusing its logic for tracking execution counts per line within each file.
-   **Stats Collection (`lib/coverage/stats.lua`):** This component manages the in-memory storage of coverage data (hit counts per file/line). It handles loading previous stats, merging new stats, and saving stats periodically or on shutdown.
-   **Assertion Integration (`mark_line_covered`):** The assertion module (`lib/assertion`) calls `coverage.mark_line_covered(file, line)` when an assertion passes. This allows distinguishing lines merely executed versus those covered by a successful assertion, enabling richer reporting (though the core stats currently focus on hit counts).
-   **Reporting Integration:** The coverage module does not generate reports itself. It provides collected coverage data (`coverage.get_data()` or `get_stats()`) to the `lib/reporting` module, which uses specialized formatters (HTML, JSON, LCOV, Cobertura, Summary) to create the final reports.
-   **Configuration (`central_config`):** All settings (`enabled`, `include`, `exclude`, `statsfile`, `savestepsize`, etc.) are managed via the central configuration system.
-   **Lifecycle (`init`, `start`, `stop`, `shutdown`, `reset`, `pause`, `resume`):** The `lib/coverage/init.lua` module provides functions to manage the coverage lifecycle, typically invoked by the test runner (`scripts/runner.lua`).

## Usage Examples / Patterns

### Basic Coverage Workflow (Conceptual Runner Logic)

```lua
--[[
  Illustrates the typical flow handled by the test runner.
]]
local coverage = require("lib.coverage")
local central_config = require("lib.core.central_config")
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

-- 1. Configure (typically via central_config or CLI flags -> central_config)
central_config.set("coverage", {
  enabled = true,
  include = { "src/.*%.lua$" },
  exclude = { "src/vendor/.*" },
  statsfile = ".coverage_stats"
})
coverage.init() -- Applies config

-- 2. Start coverage before running tests
coverage.start()

-- 3. Run tests (code execution triggers the debug hook)
-- require("my_test_suite")
-- firmo.run(...)

-- 4. Stop coverage after tests
coverage.stop()

-- 5. Get coverage data
local coverage_data = coverage.get_data() -- Or get_stats() for raw data

-- 6. Generate and save reports using the reporting module
if coverage_data then
  local html_content = reporting.format_coverage(coverage_data, "html")
  if html_content then
    reporting.write_file("./coverage-reports/coverage.html", html_content)
  end

  local lcov_content = reporting.format_coverage(coverage_data, "lcov")
  if lcov_content then
    reporting.write_file("./coverage-reports/coverage.lcov", lcov_content)
  end
end

-- 7. Shutdown (optional, ensures final save)
coverage.shutdown()
```

### Coverage Tracking Within Tests (Manual Control)

```lua
--[[
  Demonstrates manually controlling coverage tracking within tests,
  useful for specific scenarios but generally handled by the runner.
  Assumes necessary modules and test functions are available.
]]
describe("Coverage tracking", function()
  before(function()
    coverage.init({ include = { "src/calculator.lua" } }) -- Configure for this test
    coverage.reset() -- Clear previous stats
    coverage.start() -- Start tracking for this describe block
  end)

  it("tracks line coverage", function()
    local calc = require("src.calculator") -- Execution tracked by hook
    calc.add(2, 3)

    local stats = coverage.get_stats() -- Get raw hit counts
    -- Note: stats structure might differ slightly from get_data()
    expect(stats.files["src/calculator.lua"].lines).to.exist()
    -- Check specific line hits based on calculator.lua content
  end)

  it("tracks different execution paths", function()
    local calc = require("src.calculator")
    calc.divide(6, 2)  -- Success path
    pcall(calc.divide, 1, 0) -- Error path (use pcall to handle error)

    local stats = coverage.get_stats()
    -- Check line hits for both paths
  end)

  after(function()
    coverage.stop() -- Stop tracking after tests in this block
  end)
end)
```

### Safe Coverage Start/Stop

```lua
--[[
  Demonstrates safe start/stop patterns using error handling.
]]
local error_handler = require("lib.core.error_handler")
local logger = require("lib.tools.logging").get_logger("coverage-example")

-- Safely start coverage
local function safe_start(options)
  local success, err = error_handler.try(function()
    coverage.init(options)
    coverage.start()
  end)
  if not success then
    logger.error("Coverage start failed", { error = error_handler.format_error(err) })
    return false, err
  end
  return true
end

-- Safely stop and get data
local function safe_stop_and_get()
  local success, data, err = error_handler.try(function()
    coverage.stop()
    return coverage.get_data()
  end)
  if not success then
    logger.error("Coverage stop/get failed", { error = error_handler.format_error(data) }) -- Error is in 'data' on failure
    return nil, data
  end
  return data
end

-- Usage
safe_start({ include = {"src/.*"} })
-- Run tests...
local coverage_data = safe_stop_and_get()
-- Process data...
coverage.shutdown()
```

### Debug Hook System (Conceptual)

```lua
--[[
  Conceptual illustration of the debug hook mechanism.
  The actual implementation is in lib/coverage/hook.lua.
]]
local coverage_stats = require("lib.coverage.stats")

local function coverage_line_hook(event, line)
  -- 'event' will be "line"
  -- 'line' is the line number being executed

  -- Get info about the currently executing code
  local info = debug.getinfo(2, "S") -- Level 2 gets the caller of the hook
  if info and info.source and info.source:sub(1,1) == "@" then
    local filename = info.source:sub(2) -- Remove "@" prefix

    -- Check if this file should be tracked based on include/exclude patterns
    if should_track_file(filename) then
      -- Record the hit for this file and line number
      coverage_stats.record_hit(filename, line)
    end
  end
end

local function setup_debug_hook()
  -- Store original hook if it exists
  local original_hook, original_mask, original_count = debug.gethook()

  -- Set our coverage hook to trigger on line events
  debug.sethook(coverage_line_hook, "l", 0)

  -- Return a function to restore the original hook
  return function()
    debug.sethook(original_hook, original_mask, original_count)
  end
end

-- Usage:
-- local restore_hook = setup_debug_hook()
-- -- Run code...
-- restore_hook()
```

## Related Components / Modules

-   **Source:** [`lib/coverage/init.lua`](init.lua), [`lib/coverage/hook.lua`](hook.lua), [`lib/coverage/stats.lua`](stats.lua)
-   **Usage Guide:** [`docs/guides/coverage.md`](../../docs/guides/coverage.md)
-   **API Reference:** [`docs/api/coverage.md`](../../docs/api/coverage.md)
-   **Reporting:** [`lib/reporting/init.lua`](../reporting/init.lua) - Consumes coverage data to generate reports.
-   **Assertions:** [`lib/assertion/init.lua`](../assertion/init.lua) - Calls `mark_line_covered`.
-   **Configuration:** [`lib/core/central_config.lua`](../core/central_config.lua) - Provides configuration settings.
-   **Error Handling:** [`lib/core/error_handler/init.lua`](../core/error_handler/init.lua) - Used for internal error management.
