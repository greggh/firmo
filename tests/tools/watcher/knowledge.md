# File Watcher Tests


This directory contains tests for the firmo file watching system. The watcher module enables continuous testing by detecting file changes and automatically running tests.

## Directory Contents



- **watch_mode_test.lua** - Tests for file watching functionality


## File Watcher Features


The firmo watcher module provides:


- **Automatic file change detection** - Monitor files for changes
- **Continuous test execution** - Run tests when files change
- **Configurable directories** - Customize which directories to watch
- **Exclusion patterns** - Ignore specific files or patterns
- **Debounce mechanism** - Prevent multiple runs on rapid changes
- **Event filtering** - Filter by event type (create, modify, delete)
- **Resource efficiency** - Minimal CPU and memory usage while watching
- **Cross-platform support** - Works on Windows, macOS, and Linux


## Watch Mode Patterns


Watch mode can be enabled via:


```lua
-- Command-line
lua test.lua --watch tests/
-- API
firmo.run_tests({
  path = "tests/",
  watch = true,
  watch_dirs = {"lib/", "tests/"},
  watch_ignore = {"*.tmp", "*.log"}
})
```



## Watch Events


The watcher responds to different file events:


- **Create** - New files are created
- **Modify** - Existing files are modified
- **Delete** - Files are deleted
- **Rename** - Files are renamed (detected as delete + create)


## Running Tests


To run all watcher tests:


```text
lua test.lua tests/tools/watcher/
```


To run a specific watcher test:


```text
lua test.lua tests/tools/watcher/watch_mode_test.lua
```


To run tests in watch mode:


```text
lua test.lua --watch tests/
```


See the [Watcher API Documentation](/docs/api/watcher.md) for more information.
