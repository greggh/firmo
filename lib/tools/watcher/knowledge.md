# lib/tools/watcher Knowledge

## Purpose

The `lib/tools/watcher` module provides functionality to detect changes (modifications, additions, deletions) within specified directories and files in the filesystem. Its current implementation relies on a **polling-based mechanism**: it takes an initial snapshot of file states and then periodically checks for differences when explicitly asked. It does **not** currently offer continuous, event-driven file monitoring. This module is intended to be used by higher-level components, such as Firmo's interactive mode (`lib/tools/interactive`) or the CLI's `--watch` flag implementation, which would be responsible for creating the polling loop that calls this module's checking function.

## Key Concepts

- **Polling Mechanism:** The core operational model involves two main steps, managed by the calling code:
    1.  **Initialization (`watcher.init()`):** This function is called once at the start. It scans the specified directories recursively, applies configured `watch_patterns` and exclude patterns, and stores the modification timestamp (`mtime`) of all initially matched files in an internal table (`file_timestamps`).
    2.  **Checking for Changes (`watcher.check_for_changes()`):** This function must be called periodically by the application loop (e.g., every second). It performs the following:
        - Checks if enough time has passed since the last check based on `config.check_interval`. If not, it returns `nil` immediately.
        - If the interval has passed, it rescans the monitored directories.
        - Compares the current modification times of known files against the stored `file_timestamps`. If a file's `mtime` is newer, it's marked as modified.
        - Identifies any files that were previously tracked but are now missing (marked as removed).
        - Identifies any new files in the scanned directories that match the `watch_patterns` (marked as added).
        - Updates the internal `file_timestamps` table with the new `mtime`s and adds new files / removes deleted ones.
        - Updates the `last_check_time`.
        - Returns an array containing the paths of all files detected as modified, added, or removed since the last check. Returns `nil` if no changes were found.

- **Configuration (`configure`):** Settings are loaded from `lib.core.central_config` and can be set via `watcher.configure(options)`. Key options:
    - `check_interval` (number, default: 1.0): The minimum time in seconds that must elapse between calls to `check_for_changes` before it actually performs a scan.
    - `watch_patterns` (string[], default: `{"%.lua$", "%.txt$", "%.json$"}`): An array of Lua patterns. Only files whose *full path* matches one of these patterns will be tracked.
    - `default_directory` (string, default: `.`): The directory used by `init` if no specific directories are provided.
    - `debug` / `verbose` (boolean): Control the verbosity of logging messages from the watcher module itself.

- **State Management:** The module maintains internal state:
    - `file_timestamps`: A Lua table mapping absolute file paths to their last known modification timestamp (numeric `mtime`).
    - `last_check_time`: The timestamp of the last time `check_for_changes` performed a scan.

- **`init(directories?, exclude_patterns?)` Function:**
    - Populates the initial `file_timestamps` state.
    - `directories`: A single path string or a table of path strings to scan. Defaults to `config.default_directory`.
    - `exclude_patterns`: Optional table of Lua patterns. Files/directories matching these during the initial scan are ignored.
    - Uses `lib.tools.filesystem.scan_directory` recursively.
    - Applies `config.watch_patterns` and `exclude_patterns`.
    - Gets `mtime` via `lib.tools.filesystem.get_modified_time`.
    - Returns `true, nil` on success or `nil, error_object` on critical failure (e.g., all specified directories were invalid).

- **`check_for_changes()` Function:**
    - The core polling function.
    - Compares current `mtime`s with stored `file_timestamps`.
    - Re-scans directories (currently hardcoded to `config.default_directory`) to find new/deleted files matching `watch_patterns`.
    - Updates internal state.
    - Returns `changed_paths_array` if changes occurred since the last valid check, otherwise `nil`. Returns `nil, error_object` on critical internal errors.

- **Other Implemented Functions:**
    - `add_patterns(patterns)`: Adds new patterns to the `config.watch_patterns` list (updates central config if possible).
    - `set_check_interval(interval)`: Updates the `config.check_interval` (updates central config if possible).
    - `reset()`: Resets local configuration (`config` table) to defaults.
    - `full_reset()`: Performs `reset()` and also attempts to reset the `watcher` section in `central_config`. Clears `file_timestamps`.
    - `debug_config()`: Returns a table containing current configuration and state for debugging.

- **Unimplemented Functions:** The following functions, though potentially documented in source comments or suggested by the module's name, are **NOT IMPLEMENTED** in the current `init.lua`:
    - `on_change`: There is no mechanism to register callbacks for change events.
    - `watch`: There is no function to start a continuous, self-contained watching loop within this module.
    - `stop`: No loop to stop.
    - `get_watched_files`: No public function to retrieve the internal state.
    - `add_directory` / `add_file`: No functions to dynamically add specific items after `init`.
    - `is_watching`: No active watching state to check.

## Usage Examples / Patterns

### Pattern 1: Implementing a Polling Loop (Correct Usage)

```lua
--[[
  Demonstrates the correct way to use the watcher via polling.
  This loop would typically be implemented in the CLI or interactive mode.
]]
local watcher = require("lib.tools.watcher")
local error_handler = require("lib.tools.error_handler")
local socket = require("socket") -- For sleep

-- Configure (optional, might be done via central_config)
watcher.configure({ check_interval = 0.5 }) -- Check every 0.5 seconds

-- Initialize by scanning target directories (e.g., 'src' and 'tests')
local init_ok, init_err = watcher.init({ "src", "tests" }, { "%.git/", "node_modules/" })

if not init_ok then
  print("Watcher initialization failed: " .. init_err.message)
  return
end

print("Watcher initialized. Starting polling loop (press Ctrl+C to stop)...")

local running = true
while running do
  local changed_files, check_err = watcher.check_for_changes()

  if check_err then
    print("Error checking for changes: " .. check_err.message)
    -- Decide whether to stop or continue polling based on error severity
    running = false -- Example: Stop on error
  elseif changed_files then
    print("Detected changes in:")
    for _, file_path in ipairs(changed_files) do
      print("- " .. file_path)
    end
    -- Trigger action based on changes (e.g., rerun tests)
    print("... Triggering action (e.g., re-running tests) ...")
    -- Example: Rerun all tests if any change detected
    -- local success, runner_err = error_handler.try(some_runner_function)
    -- if not success then print("Runner error:", runner_err.message) end
  end

  -- Wait before the next check (using configured interval as a base)
  -- Use a non-blocking sleep if possible in a real application
  socket.sleep(watcher.debug_config().local_config.check_interval or 1.0)

  -- Add logic here to check for user input to stop the loop if needed
  -- e.g., if io.stdin:read(0) then running = false end
end

print("Watcher loop stopped.")
```

### Pattern 2: Adding Watch Patterns

```lua
local watcher = require("lib.tools.watcher")

-- Add patterns for .md and .yml files
local added_ok, add_err = watcher.add_patterns({ "%.md$", "%.yml$" })

if not added_ok then
    print("Failed to add patterns:", add_err.message)
end

-- Configuration now includes the new patterns for subsequent init/check calls
-- print(watcher.debug_config().local_config.watch_patterns)
```

**Note:** Examples using `watcher.watch(...)` or `watcher.on(...)` found elsewhere are incorrect based on the current implementation and should be disregarded.

## Related Components / Modules

- **`lib/tools/watcher/init.lua`**: The source code implementation.
- **`lib/tools/filesystem/knowledge.md`**: **Crucial dependency.** Provides functions like `scan_directory` and `get_modified_time` used internally for polling.
- **`lib/tools/error_handler/knowledge.md`**: Used for safe execution (`try`, `safe_io_operation`) during filesystem interactions and for returning structured errors.
- **`lib/tools/logging/knowledge.md`**: Used for internal logging of configuration, initialization steps, detected changes, and errors. Verbosity controlled by `debug`/`verbose` config.
- **`lib/core/central_config/knowledge.md`**: Manages the watcher's configuration settings (`check_interval`, `watch_patterns`, etc.).
- **`lib/tools/interactive/knowledge.md` / `lib/tools/cli/knowledge.md`**: These modules are the expected consumers that would implement the actual polling loop using `watcher.init` and `watcher.check_for_changes` to provide the user-facing watch mode functionality.

## Best Practices / Critical Rules (Optional)

- **Understand Polling:** Recognize that this module detects changes only when `check_for_changes()` is called. It's not an instant, event-driven system. The `check_interval` is a trade-off between responsiveness and the performance cost of rescanning.
- **Implement the Loop Externally:** The code using this module is responsible for creating and managing the loop that periodically calls `check_for_changes()` and decides what action to take when changes are reported.
- **Scope Scans Appropriately:** Provide specific directories to `init()` and use focused `watch_patterns` and `exclude_patterns` to minimize the number of files scanned during each `check_for_changes()` call, especially on large projects.
- **Handle Errors:** Robustly check the error returns from `init()` and `check_for_changes()` to handle filesystem issues or internal errors gracefully.
- **Acknowledge Unimplemented Features:** Do not rely on or attempt to use the `watch()`, `on_change()`, `stop()`, `add_directory()`, etc., functions as they are not currently implemented.

## Troubleshooting / Common Pitfalls (Optional)

- **Changes Not Detected:**
    - Check `watch_patterns`: Ensure they correctly match the paths of the files you expect to monitor (use Lua pattern syntax).
    - Check `check_interval`: If too long, detection will be delayed.
    - Check Logs: Enable verbose/debug logging (`--verbose-watcher` or configure) to see which files are scanned, matched, excluded, and if any errors occur during `init` or `check_for_changes` (e.g., permission denied getting `mtime`).
    - `mtime` Granularity: On some filesystems, modification times might only update every second or two. Very rapid changes within the `check_interval` might occasionally be missed if the `mtime` hasn't updated yet when `check_for_changes` runs.
- **High CPU Usage during Watch Mode:**
    - `check_interval` might be too short, causing constant rescanning. Increase the interval.
    - Too many files being scanned. Refine `init` directories, `watch_patterns`, and `exclude_patterns` to reduce the scope.
- **Errors from `init` or `check_for_changes`:**
    - Usually related to `lib.tools.filesystem`. Check if the specified directories exist and if the process has read permissions for the directories and the files within them. Check the returned error object and logs for details.
- **Confusion about Event-Driven Watching:** Users expecting OS-level file event notifications (like `inotify` on Linux) will be disappointed. This implementation purely polls by comparing timestamps and rescanning. Clarify this limitation if necessary.
