# lib/tools/interactive Knowledge

## Purpose

The `lib/tools/interactive` module implements the interactive command-line interface (REPL - Read-Eval-Print Loop) for the Firmo testing framework. Typically invoked via the main CLI using `test.lua --interactive`, this mode allows users to run tests, discover files, filter tests by various criteria (name patterns, focus keywords, tags), manage file watching, change test directories or patterns, view status, and execute other utility commands like code fixing, all within an active session without needing to restart the main Firmo script after each action.

## Key Concepts

- **REPL Structure:** The core of the interactive mode is the loop initiated by `M.start(firmo, options)`. This function performs initial setup (configures state, discovers tests), prints a header and status, and then enters the main loop. The loop repeatedly:
    1.  Displays a prompt (e.g., `>`).
    2.  Reads a line of user input using `read_line_with_history`.
    3.  Passes the input to `process_command` for parsing and execution.
    4.  Continues until `process_command` sets the internal `state.running` flag to `false` (usually via the `exit` command).

- **Command Processing (`process_command`):** This function is the central dispatcher. It takes the raw user input, parses it into a command (lowercase) and arguments, adds the command to history (`add_to_history`), and then calls the appropriate internal handler function based on the command string (e.g., `help` calls `print_help`, `run` calls `run_tests`, `watch` calls `start_watch_mode` or updates state, `dir` updates `state.test_dir` and calls `discover_test_files`, etc.). Unknown commands result in an error message.

- **State Management:** The module maintains its current configuration and runtime status in an internal `state` table. Key fields include `test_dir`, `test_pattern`, `focus_filter`, `tag_filter`, `watch_mode`, `watch_dirs`, `exclude_patterns`, `history`, `current_files`, etc.
    - `M.configure(options)`: Initializes the state by merging default values (`DEFAULT_CONFIG`), values loaded from `central_config` (if available), and options passed during startup (e.g., from the main CLI).
    - `M.reset()`: Resets the local `state` table back to the default configuration values and clears runtime info like history and filters.
    - `M.full_reset()`: Performs a local reset and also attempts to reset the "interactive" section within the `central_config` system.

- **Dependency Context (CRITICAL):** This module is specifically designed to be launched and managed *by* a higher-level script, typically the main Firmo CLI runner (`scripts/runner.lua`). This controlling script is responsible for:
    1.  Initializing and providing the main `firmo` framework instance to `M.start`.
    2.  Ensuring that core modules like `lib.core.runner` and `lib.tools.discover` are already loaded and available in the Lua environment.
    The `interactive` module itself **does not** directly `require` or manage the lifecycle of the `runner` or `discover` modules within this library context; it assumes they exist and calls functions like `runner.run_file`, `runner.run_all`, and `discover.find_tests` on these assumed global/upvalue references. Optional dependencies like `lib.tools.watcher` and `lib.tools.codefix` *are* loaded safely using an internal `load_module` function based on `error_handler.try`.

- **Test Execution & Discovery:** The internal `run_tests` function orchestrates test execution. Based on whether a specific file path is provided, it calls either `runner.run_file` or `runner.run_all`, passing the necessary file paths and the `firmo` instance. Similarly, `discover_test_files` calls `discover.find_tests` using the current `state.test_dir` and `state.test_pattern` to refresh the list of available tests (`state.current_files`).

- **Filtering:** Commands like `filter <pattern>`, `focus <name>`, and `tags <tag1,tag2>` update the corresponding fields in the `state` table (`focus_filter`, `tag_filter`). They also attempt to call methods on the provided `firmo` instance (`firmo.set_filter`, `firmo.focus`, `firmo.filter_tags`) to apply these filters for subsequent `run` commands. Clearing a filter is usually done by providing no arguments (e.g., `focus`).

- **Watch Mode:** The `watch` command (with `on`, `off`, or no args to toggle) controls the `state.watch_mode` flag. When enabled, `start_watch_mode` is invoked. This function uses the `lib.tools.watcher` module (if available) to monitor the directories listed in `state.watch_dirs` (excluding paths matching `state.exclude_patterns`) for changes. When changes are detected, it waits for a short debounce period (`debounce_time`) and then automatically triggers a full test run (`runner.run_all`). Watch mode continues until the user presses Enter (using a basic, potentially unreliable `io.read(0)` check). The `watch-dir` and `watch-exclude` commands modify the respective lists in the `state`.

- **Configuration Updates:** Commands that change configuration settings (e.g., `dir`, `pattern`, `watch`, `watch-dir`, `watch-exclude`) update the internal `state` table. They also attempt to persist these changes to the `lib.core.central_config` system if it's available, allowing settings to carry over between sessions.

- **History:** User commands are stored in the `state.history` table (up to a default limit of 100). The `history` command displays this list. The `read_line_with_history` function is currently a basic placeholder using `io.read("*l")` and lacks more advanced REPL features like command editing or navigation using arrow keys.

## Usage Examples / Patterns

*(These commands are typed at the interactive prompt, e.g., `> run`)*

```bash
# Show available commands
> help

# Run all discovered tests
> run

# Run a specific test file
> run tests/core/runner_test.lua

# List discovered test files
> list

# Filter tests: only run tests whose name contains "validation"
> filter validation
> run

# Clear the filter
> filter

# Focus tests: only run tests whose describe/it block name contains "User Login"
> focus User Login
> run

# Clear focus
> focus

# Run only tests tagged "@integration" or "@slow"
> tags @integration,@slow
> run

# Clear tag filter
> tags

# Enable watch mode (runs tests, then waits for changes)
> watch on
# ... tests run ...
# --- WATCHING FOR CHANGES (Press Enter to return to interactive mode) ---
# (Press Enter here)
>

# Disable watch mode
> watch off

# Change the directory where tests are discovered
> dir src/lua/tests

# Change the pattern used to discover test files
> pattern *.spec.lua

# Show the current settings (directory, pattern, filters, watch mode)
> status

# Show previously entered commands
> history

# Run codefix check on the 'lib' directory (requires codefix module)
> codefix check lib

# Clear the terminal screen
> clear

# Exit the interactive session
> exit
```

## Related Components / Modules

- **`lib/tools/interactive/init.lua`**: The source code implementation of this module.
- **`lib/tools/cli/knowledge.md`**: The main command-line interface module which typically invokes `interactive.start` when the `--interactive` flag is used.
- **`scripts/runner.lua` Knowledge**: The primary script context responsible for loading Firmo, initializing the `firmo` instance, loading core dependencies like `runner` and `discover`, and then passing them to `interactive.start`. **Crucial context provider.**
- **`lib/core/runner/knowledge.md`**: Provides the test execution functions (`run_file`, `run_all`) used indirectly by this module.
- **`lib/tools/discover/knowledge.md`**: Provides the test discovery function (`find_tests`) used indirectly by this module.
- **`lib/tools/watcher/knowledge.md`**: Optional dependency required for the `watch` command functionality.
- **`lib/tools/codefix/knowledge.md`**: Optional dependency required for the `codefix` command functionality.
- **`lib/core/central_config/knowledge.md`**: Used for loading and saving persistent configuration settings for the interactive mode.
- **`lib/tools/error_handler/knowledge.md`**: Used extensively for safe execution (`try`), validation, and reporting errors encountered during interactive commands.
- **`lib/tools/logging/knowledge.md`**: Used for detailed internal logging of operations, configuration changes, and errors.

## Best Practices / Critical Rules (Optional)

- **Launch via Main CLI:** Always start the interactive mode using the main Firmo script (`lua test.lua --interactive`) to ensure the environment and dependencies (like `runner` and `discover`) are correctly set up.
- **Understand Filter Persistence:** Filters set using `filter`, `focus`, or `tags` remain active for all subsequent `run` commands until explicitly cleared (e.g., `focus` with no arguments).
- **Use `status`:** Regularly use the `status` command to verify the current test directory, pattern, active filters, and watch mode settings.

## Troubleshooting / Common Pitfalls (Optional)

- **"Runner module not available" / "Discovery module not available" Errors:** This typically means the interactive mode was started incorrectly, without the main `scripts/runner.lua` environment properly loading these core modules before calling `interactive.start`. Ensure you are using `lua test.lua --interactive`.
- **Watch Mode Issues:**
    - `"Watch module not available"` error: The optional `lib/tools/watcher` module is missing or failed to load.
    - Watch mode doesn't detect changes: Check the directories being watched (`status` command or `state.watch_dirs`), ensure they are correct. Check `state.exclude_patterns`. Filesystem event handling can sometimes be unreliable depending on the OS and environment.
    - Cannot exit watch mode: The check for the Enter key (`io.read(0)`) is basic and might not work reliably in all terminals or non-interactive environments. Try Ctrl+C as a fallback (which usually terminates the whole script).
- **Command History Navigation:** The current `read_line_with_history` function is rudimentary. Features like using Up/Down arrow keys to navigate history are not implemented in the current version described in the source.
- **Configuration Inconsistencies:** If settings changed directly in a `.firmo-config.lua` file don't seem to apply, you might need to restart the interactive session. While there's a change listener for `central_config`, its effectiveness might vary. Using commands like `reset` or `full_reset` can help resync state.
