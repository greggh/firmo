# lib/tools/cli Knowledge

## Purpose

    The `lib/tools/cli` module serves as the primary command-line interface (CLI) handler for the Firmo testing framework. It is typically invoked by the main `firmo.lua` script (or a similar top-level script like `run_tests.lua` in some project setups). Its main responsibilities are to parse the command-line arguments provided by the user, interpret these arguments to understand the desired action (e.g., run tests normally, enable coverage, watch for changes, show help), configure other Firmo modules based on these options, and then initiate the appropriate test execution flow or informational display. With recent refactoring, it has taken on more direct responsibility for orchestrating test runs, integrating functionality previously found in scripts like `test.lua` and `scripts/runner.lua`.

## Key Concepts

- **Argument Parsing (`parse_args`):** This core function processes the command-line arguments (usually Lua's global `_G.arg` table). It identifies various argument types:

  - **Flags:** Standalone options like `--coverage` or the short form `-c`. Combined short flags like `-vcq` are also supported.
  - **Options with Values:** Arguments that take a value, parsed in formats like `--pattern core`, `--pattern=core`, or `-k value`.
  - **Key-Value Pairs:** Unrecognized long options like `--some.custom.setting=value` are collected and can be used to set values in `central_config`.
  - **Positional Arguments:** Arguments without a preceding dash. The first such argument, if it's a directory, is often treated as the `base_test_dir` for discovery. Subsequent positional arguments are typically treated as specific file or directory paths to test.

  The `M.parse_args` function merges parsed options with a set of `default_options` (defined within `lib/tools/cli/init.lua`) and also integrates with `lib.core.central_config`. If a `--config <path>` argument is provided and `central_config` is available, the specified configuration file is loaded, and its settings can influence the default values for CLI options. The CLI also supports `--create-config` to generate a new `.firmo-config.lua` file with default settings.

  Errors encountered during parsing (e.g., unknown flags) are collected in the `parse_errors` field of the returned options table. The final output is a comprehensive options table (see `default_options` in the source and the JSDoc for `M.parse_args` for details on expected fields like `coverage_enabled`, `test_name_filter`, `console_format`, `report_file_formats`, `output_json_filepath`, etc.).

- **Execution Modes:** The main `M.run` function orchestrates different execution modes based on the parsed options:

  - **Standard Run:** This is the default mode when no specific mode flag (like `--watch` or `--interactive`) is present. `M.run` directly configures and utilizes `lib.core.runner` to execute tests. Test targets are determined either from explicit positional arguments (files or directories) or by discovering test files (e.g., matching `*_test.lua`) within the `base_test_dir` using `lib.tools.discover`. Various CLI options (`--coverage`, `--quality`, `--parallel`, `--filter` for test names, `--console-format`, etc.) modify the runner's behavior and how results are processed and displayed.
  - **Watch Mode (`--watch` or `-w`):** When this flag is present, `M.run` delegates to `M.watch`. This function, if the `lib.tools.watcher` module is available, monitors the specified test files/directories (typically `base_test_dir`) for changes. Upon detecting a file modification, it re-triggers a test run, again using `lib.core.runner` with the prevailing options. This mode is useful for continuous testing during development.
  - **Interactive Mode (`--interactive` or `-i`):** Activated by this flag, `M.run` delegates to `M.interactive`. This function, if the `lib.tools.interactive` module is available, is intended to launch a more interactive test management interface (e.g., a terminal user interface or REPL) allowing the user to browse, select, and run tests.

- **Help & Version:** The flags `--help` (`-h`) and `--version` (`-V`) are handled early in `M.run`. They trigger the display of usage information (via `M.show_help`) or the Firmo version string, respectively, and then cause the script to exit without running tests.

- **Configuration Integration:** The CLI module interacts closely with `lib.core.central_config` (if available). It can load configuration from a specified file (`--config`), potentially set specific config values based on unknown `--key=value` arguments, and applies relevant CLI options (like coverage settings, quality level, runner format) to configure other modules (e.g., `coverage_module`, `quality_module`, `runner_module`) before execution begins. CLI options generally override those from `central_config` if both are specified for the same setting.

- **Report Generation (`--report` or `-r`):** If the `--report` (or `-r`) flag is used and report formats are specified (e.g., via `--report-formats`), the CLI, after tests complete, will invoke `lib.reporting.auto_save_reports`. This function uses the collected data from enabled features (like coverage and quality) to generate and save report files in the specified formats (e.g., HTML, JSON, LCOV) to the configured `report_output_dir`.

- **Dependency Management:** The module uses an internal `try_require` function to safely load its dependencies, particularly those for optional features like watch mode (`lib.tools.watcher`), interactive mode (`lib.tools.interactive`), coverage (`lib.coverage`), quality (`lib.quality`), JSON processing (`lib.tools.json`), etc. This allows the core CLI functionality (parsing args, running basic tests via runner) to work even if some optional modules are not installed or available, providing graceful degradation. Key dependencies include `lib.core.runner`, `lib.tools.discover`, `lib.core.central_config`, `lib.tools.logging`, `lib.tools.error_handler`, and `lib.core.version`.

## Usage Examples / Patterns

    The CLI is typically used via the main `firmo.lua` script.

### Pattern 1: Run All Tests

    (Runs all tests found within the default test directory, e.g., `tests/`, using default settings)

```bash
  lua firmo.lua
```

### Pattern 2: Run with Code Coverage

```bash
lua firmo.lua --coverage tests/
# or shorthand:
lua firmo.lua -c tests/
```

_(Runs tests and collects code coverage data)_

### Pattern 3: Filter Tests by Name Pattern

    (Runs test files matching \*\_spec.lua and only tests whose names contain "User Login")

```bash
  lua firmo.lua --pattern="*_spec.lua" --filter="User Login" ./tests/
```

### Pattern 4: Run in Watch Mode

```bash
lua firmo.lua --watch ./tests/
# or shorthand:
lua firmo.lua -w ./tests/
```

_(Runs tests initially, then watches files in `tests/` and reruns tests automatically on changes)_

### Pattern 5: Run Specific Files or Directories

```bash
lua firmo.lua ./tests/unit/ ./tests/integration/specific_feature_test.lua
```

_(Runs only the specified tests)_

### Pattern 6: Show Help Message

```bash
lua firmo.lua --help
# or shorthand:
lua firmo.lua -h
```

_(Displays usage instructions and available options)_

### Pattern 7: Show Version

```bash
lua firmo.lua --version
# or shorthand:
lua firmo.lua -V
```

_(Displays the installed Firmo version)_

### Pattern 8: Combine Multiple Options

```bash
lua firmo.lua -c -q --report --report-formats=html,lcov --pattern="api/*_test.lua" ./tests/
```

_(Runs tests matching "api", enables coverage and quality checks, and generates an HTML report afterwards)_

### Pattern 9: Using a Custom Config File

```bash
lua firmo.lua --config=./config/ci.firmo-config.lua ./tests/
```

### Pattern 10: Output Test Results as JSON to Console

```bash
lua firmo.lua --json ./tests/specific_test.lua
```

## Related Components / Modules

    - **`lib/tools/cli/init.lua`**: The source code implementation of this module.
    - **`firmo.lua`**: The main script that typically requires and uses `lib.tools.cli.run()` to start the testing process based on command-line arguments.
    - **`lib/core/runner/knowledge.md`**: The test runner module, orchestrated by the CLI for standard and watch mode execution.
    - **`lib/tools/watcher/knowledge.md`**: Used by the CLI's watch mode (`-w`) to monitor file changes.
    - **`lib/tools/interactive/knowledge.md`**: Used by the CLI's interactive mode (`-i`) to provide a TUI/REPL.
    - **`lib/coverage/knowledge.md`**: The coverage system, enabled and configured via CLI flags (`-c`) and potentially triggered for reporting (`-r`).
    - **`lib/quality/knowledge.md`**: The quality validation system, enabled via CLI flags (`-q`) and potentially triggered for reporting (`-r`).
    - **`lib/core/central_config/knowledge.md`**: The central configuration system, used by the CLI to load configuration (`--config`) and apply settings.
    - **`lib/tools/discover/knowledge.md`**: Used by the CLI (via the runner or directly) to find test files when none are specified explicitly.
    - **`lib/tools/logging/knowledge.md`**: Provides logging capabilities used throughout the CLI module.
    - **`lib/tools/error_handler/knowledge.md`**: Used for robust error handling during module loading and execution.
    - **`lib/tools/json/knowledge.md`**: Used for encoding results to JSON, especially for the `--json` flag or worker communication in parallel mode.
    - **`lib/reporting/knowledge.md`**: The reporting system, invoked by the CLI (`--report`) to generate various output files.
