# tests/tools/watcher Knowledge

## Purpose

The `tests/tools/watcher/` directory contains automated tests for validating Firmo's file change detection utility, implemented in `lib/tools/watcher`. It's important to note that the current implementation uses a **polling-based mechanism**. These tests ensure that this polling system correctly identifies added, modified, and deleted files between checks, based on configured patterns and time intervals. They do **not** test for continuous, event-driven file monitoring, as that functionality is not currently implemented in `lib/tools/watcher/init.lua`.

## Key Concepts

The tests within `watch_mode_test.lua` focus on verifying the implemented polling logic:

- **Initialization (`watcher.init()`):** Tests confirm that calling `init` correctly scans the specified directories, filters files using `watch_patterns` and `exclude_patterns`, and records the initial modification times (`mtime`) of the relevant files into its internal state (`file_timestamps`).
- **Change Detection (`watcher.check_for_changes()`):** The core validation target. Tests ensure that calling this function:
    - Detects files whose `mtime` has changed since the last check/initialization.
    - Detects new files created in the watched directories that match the patterns.
    - Detects tracked files that have been deleted.
    - Returns an array containing the absolute paths of all detected changes.
    - Returns `nil` if no changes are detected *or* if called again before the `check_interval` has elapsed.
- **Check Interval (`check_interval`):** Tests verify that the watcher respects the minimum time delay configured between consecutive scans performed by `check_for_changes()`.
- **Configuration:** Tests validate that changing configuration options via `watcher.configure` or `watcher.add_patterns`, such as `watch_patterns`, `exclude_patterns`, and `check_interval`, correctly affects the results of `init` and `check_for_changes`.
- **Test Environment:** Tests make crucial use of `lib/tools/test_helper` (specifically `with_temp_test_directory`) to create temporary files and directories in a controlled manner. File changes are *simulated* within tests by programmatically calling `fs.write_file` (to update `mtime`), creating new files, or calling `fs.delete_file` between the calls to `watcher.init()` and `watcher.check_for_changes()`.

## Usage Examples / Patterns (Illustrative Test Snippets from `watch_mode_test.lua`)

### Testing Change Detection via Polling

```lua
--[[
  Conceptual test demonstrating the polling workflow verification.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local watcher = require("lib.tools.watcher")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local socket = require("socket") -- For sleep

it("should detect added, modified, and deleted files via polling", function()
  test_helper.with_temp_test_directory({
    ["a.lua"] = "original content a",
    ["b.lua"] = "original content b",
    ["ignored/c.lua"] = "ignored content",
  }, function(dir_path)
    local path_a = fs.join_paths(dir_path, "a.lua")
    local path_b = fs.join_paths(dir_path, "b.lua")
    local path_d = fs.join_paths(dir_path, "d_new.lua")

    -- Configure watcher (use default lua pattern, ignore 'ignored' dir)
    watcher.configure({ check_interval = 0.05 }) -- Use a short interval for test
    local init_ok, init_err = watcher.init({dir_path}, { "ignored/" })
    expect(init_err).to_not.exist()
    expect(init_ok).to.be_truthy()

    -- Simulate changes AFTER init
    error_handler.safe_io_operation(fs.write_file, path_a, "modified content a") -- Modify
    error_handler.safe_io_operation(fs.delete_file, path_b)                 -- Delete
    error_handler.safe_io_operation(fs.write_file, path_d, "new file content") -- Add

    -- Wait for longer than the check interval
    socket.sleep(0.1)

    -- Poll for changes
    local changed_files, check_err = watcher.check_for_changes()

    -- Assert the detected changes
    expect(check_err).to_not.exist()
    expect(changed_files).to.be.a("table")
    expect(#changed_files).to.equal(3)
    -- Need a helper like contain_path or sort and compare paths carefully
    expect(changed_files).to.contain_path(fs.get_absolute_path(path_a)) -- Modified
    expect(changed_files).to.contain_path(fs.get_absolute_path(path_b)) -- Deleted
    expect(changed_files).to.contain_path(fs.get_absolute_path(path_d)) -- Added
  end)
end)
```

### Testing `check_interval`

```lua
--[[ Conceptual test for check_interval logic. ]]
it("should return nil if check_for_changes is called too soon", function()
  test_helper.with_temp_test_directory({ ["file.lua"]="-" }, function(dir_path)
    watcher.configure({ check_interval = 0.2 }) -- 200ms interval
    watcher.init({dir_path})

    -- First check immediately after init might return changes if init itself took time,
    -- but subsequent calls within interval should return nil if no FS changes occur.
    watcher.check_for_changes() -- Perform initial check to set last_check_time

    -- Call again immediately (within interval)
    local changed_files_too_soon, err_soon = watcher.check_for_changes()
    expect(err_soon).to_not.exist()
    expect(changed_files_too_soon).to.be_nil("Should return nil if interval not met")

    -- Wait longer than interval
    socket.sleep(0.3)
    local changed_files_later, err_later = watcher.check_for_changes()
    expect(err_later).to_not.exist()
    -- Expect nil if no actual file changes happened, or a table if they did
    -- expect(changed_files_later).to.be_nil()
  end)
end)
```

**Note:** Examples showing continuous `watcher.watch(...)` or event callbacks like `watcher.on(...)` are **incorrect** based on the current implementation and should be disregarded.

## Related Components / Modules

- **Module Under Test:** `lib/tools/watcher/knowledge.md` (and `lib/tools/watcher/init.lua`).
- **Test File:** `tests/tools/watcher/watch_mode_test.lua`.
- **Crucial Dependencies:**
    - **`lib/tools/test_helper/knowledge.md`**: Essential for creating and manipulating temporary files/directories to simulate filesystem changes within tests.
    - **`lib/tools/filesystem/knowledge.md`**: Provides the underlying `scan_directory` and `get_modified_time` functions used by the watcher's polling mechanism, and functions like `write_file`, `delete_file` used by tests to simulate changes.
    - **`lib/tools/error_handler/knowledge.md`**: Used internally by the watcher and `test_helper` for robust filesystem operations.
- **Parent Overview:** `tests/tools/knowledge.md`.

## Best Practices / Critical Rules (Optional)

- **Test the Polling Cycle:** Ensure tests explicitly follow the Init -> Simulate Change -> Wait -> Check cycle to validate the polling detection logic accurately.
- **Reliably Update `mtime`:** Use `fs.write_file` (even writing the same content might work on some OSes, but writing different content is safer) to reliably update the modification timestamp for testing detection of modified files. Use `fs.delete_file` for deletions and `fs.write_file` to a new path for additions.
- **Control Timing:** Use `socket.sleep` (or equivalent available in the test environment) carefully to manage time intervals relative to `config.check_interval` when testing the interval logic. Account for potential imprecision in sleep durations.
- **Verify Absolute Paths:** The watcher should deal with absolute paths internally. Tests asserting the contents of the `changed_files` list should check against expected absolute paths.

## Troubleshooting / Common Pitfalls (Optional)

- **Changes Not Detected:**
    - **Cause:** `mtime` didn't change sufficiently between checks (filesystem granularity issue, or file content wasn't actually changed by `fs.write_file`). `check_for_changes` was called before `check_interval` elapsed. Incorrect `watch_patterns` or `exclude_patterns` applied during `init`. Filesystem errors during scanning in `check_for_changes`.
    - **Debugging:** Log the `mtime` values before and after simulated changes. Log `os.clock()` values before/after `socket.sleep` and compare with `check_interval`. Enable verbose logging in the watcher module to see scanned files, stored timestamps, and comparison results. Check error returns from `init` and `check_for_changes`.
- **Flaky Tests Due to Timing:**
    - **Cause:** Reliance on short `socket.sleep` durations that might be inaccurate under load, causing `check_for_changes` to sometimes run too early or too late relative to the intended interval.
    - **Mitigation:** Use slightly larger sleep durations than the minimum required `check_interval`. Increase `check_interval` itself if high precision isn't needed. Accept some tolerance in timing-related assertions.
- **Confusion with Event-Driven Watchers:**
    - **Cause:** Expecting instant notification of changes, similar to systems using `inotify` or other OS-level events.
    - **Clarification:** Remember this module *only* detects changes when `check_for_changes()` is explicitly called and enough time has passed. Changes occurring between polls are only detected on the *next* successful poll.
