# Coverage Module

---@diagnostic disable: unused-local

The Coverage module provides comprehensive code coverage tracking for Lua code. It uses a LuaCov-inspired debug hook system for line execution tracking, integrated with Firmo's framework components like central configuration, filesystem, error handling, and logging.

## Overview

The coverage system leverages Lua's debug hook mechanism to provide reliable and efficient code coverage tracking. By using debug hooks instead of source code instrumentation, the system offers better performance, improved reliability with coroutines, and seamless integration with firmo's reporting capabilities.

## Architecture

The coverage system consists of several integrated components:

1. **Debug Hook System**:
   - **Line Hook**: Tracks which lines of code are executed via debug.sethook
   - **Coroutine Support**: Properly tracks coverage across coroutines
   - **Thread Safety**: Ensures reliable operation in multi-threaded environments
2. **File Operations**:
   - **Filesystem Module**: All file access through firmo's filesystem module
   - **Stats Management**: Saves and loads coverage statistics between runs
   - **Temporary File Handling**: Uses temp_file module for reliable operations
3. **Configuration Management**:
   - **Central Config**: Settings managed by central_config system
   - **Pattern Matching**: Flexible file include/exclude with pattern matching
   - **Threshold Configuration**: Configurable coverage thresholds
4. **Reporting System**:
   - **Integration**: Integration with Firmo's main reporting system (`lib.reporting`) for report generation in various formats.
   - **Data Normalization**: Internal coverage data is processed into a standard structure before being passed to the reporting system.

## API Reference

### Coverage Module

```lua
local coverage = require("lib.coverage")
```

#### Public Functions

- `coverage.init()`
  - **Description:** Initializes the coverage system and hooks. Resets state, compiles patterns, sets hooks.
  - **Returns:** `boolean` (success, always true).
  - **Throws:** Errors if pattern compilation fails.

- `coverage.has_hook_per_thread()`
  - **Description:** Checks if per-thread hooks are used (this implementation always patches coroutines).
  - **Returns:** `boolean` (always true).

- `coverage.pause()`
  - **Description:** Pauses coverage collection. Line hits will not be recorded. Idempotent.
  - **Returns:** `boolean` (success, true if system was running and is now paused).

- `coverage.get_stats_file()`
  - **Description:** Gets the configured path for the statistics file.
  - **Returns:** `string|nil` (The configured path or nil).

- `coverage.get_current_data()`
  - **Description:** Gets the current in-memory coverage data. Intended for debugging. Structure: `{[filename] = { [line]=hits, max=maxline, max_hits=maxhits }}`.
  - **Returns:** `table` (The raw coverage data).

- `coverage.resume()`
  - **Description:** Resumes coverage collection if paused. Line hits will be recorded again. Idempotent.
  - **Returns:** `boolean` (success, true if system was paused and is now running).

- `coverage.save_stats()`
  - **Description:** Saves collected stats to the configured file (`coverage.statsfile`). Uses atomic write (temp file + rename). Tracks write failures and pauses coverage if threshold reached.
  - **Returns:** `boolean` (success), `string|nil` (error message for non-critical errors like threshold reached).
  - **Throws:** `table` Error object if critical filesystem operations fail.

- `coverage.load_stats()`
  - **Description:** Loads coverage stats from the configured file. Merges with existing data if coverage is initialized. Returns empty table if file not found/empty/invalid header.
  - **Returns:** `table` (Loaded coverage data).
  - **Throws:** `table` Error object if critical filesystem operations fail.

- `coverage.shutdown()`
  - **Description:** Shuts down the coverage system. Attempts to save stats, removes hooks, resets state.
  - **Returns:** `nil`.

- `coverage.start()`
  - **Description:** Convenience function. Ensures system is initialized (`init`) and resumed (`resume`).
  - **Returns:** `boolean` (success).

- `coverage.stop()`
  - **Description:** Convenience function. Performs a full shutdown (`shutdown`).
  - **Returns:** `boolean` (success, always true).

- `coverage.is_paused()`
  - **Description:** Checks if coverage collection is currently paused.
  - **Returns:** `boolean` (paused state).

- `coverage.process_line_hit(filename, line_nr)`
  - **Description:** Manually records a line hit. Primarily for testing the coverage module itself.
  - **Parameters:** `filename` (string, normalized path), `line_nr` (number).
  - **Returns:** `nil`.

### Configuration

Coverage settings are controlled via the central configuration system:

```lua
-- .firmo-config.lua
return {
  coverage = {
    enabled = true,                -- Enable coverage tracking

    -- Include/exclude patterns (Lua patterns)
    include = { ".*%.lua$" },       -- Include all .lua files by default
    exclude = {                      -- Exclude tests and vendor files
      "tests/.*",
      ".*_test%.lua$",
      "vendor/.*"
    },

    -- Stats file settings
    statsfile = ".coverage-stats",   -- Path to save/load coverage statistics
    savestepsize = 100,              -- Save stats approx every N line hits (used if tick=true)
    tick = false,                    -- Use hit count saving trigger (vs buffer size)
    max_write_failures = 3,          -- Pause coverage after N consecutive save failures

    -- Other settings
    codefromstrings = false,         -- Track code loaded from strings (usually false)
    threshold = 90,                  -- Coverage threshold % (used by quality module)
  }
}
```

## Usage Examples

### Basic Usage

```lua
-- Load necessary modules
local coverage = require("lib.coverage")
local firmo = require("firmo") -- Or your test runner entry point

-- Optionally load previous stats
coverage.load_stats() -- Errors are thrown on critical IO failure

-- Start coverage tracking
coverage.start()

-- Run tests
-- firmo.run_tests(...)

-- Stop coverage tracking (implicitly saves stats via shutdown)
coverage.stop()

-- Note: Report generation and threshold validation are handled by
-- the `lib.reporting` and `lib.quality` modules, typically
---invoked by the test runner script based on configuration.
-- Example (conceptual, usually in runner script):
-- local reporting = require("lib.reporting")
-- reporting.save_coverage_report(coverage.get_current_data(), "html", "./coverage-reports/report.html")
```
