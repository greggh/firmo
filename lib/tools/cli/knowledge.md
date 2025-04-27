# lib/tools/cli Knowledge

## Purpose

The `lib/tools/cli` module serves as the primary command-line interface (CLI) handler for the Firmo testing framework. It is typically invoked by the main `test.lua` script. Its main responsibilities are to parse the command-line arguments provided by the user, interpret these arguments to understand the desired action (e.g., run tests normally, enable coverage, watch for changes, show help), configure other Firmo modules based on these options, and then initiate the appropriate test execution flow or informational display.

## Key Concepts

- **Argument Parsing (`parse_args`):** This core function processes the command-line arguments (usually Lua's global `arg` table). It identifies various argument types:
    - **Flags:** Standalone options like `--coverage` or the short form `-c`.
    - **Options with Values:** Arguments followed by a value, like `--pattern core` or `--format=detailed`.
    - **Key-Value Pairs:** Specific options like `--key=value` which might be passed to `central_config`.
    - **Positional Arguments:** Arguments without a preceding dash, typically interpreted as test files or directories to run (e.g., `tests/my_test.lua`).
    The function merges parsed options with defaults and returns a structured `CommandLineOptions` table. It includes special handling for `--config <path>` to load an external configuration file via `central_config`, and `--create-config` to generate a default configuration file.

- **Execution Modes:** The main `M.run` function orchestrates different execution modes based on the parsed options:
    - **Standard Run:** The default mode executed when no specific mode flag (like `--watch` or `--interactive`) is present. It uses `lib.core.runner` to execute tests. Tests are either specified explicitly as positional arguments or discovered using `lib.tools.discover` in the target directory (default `tests`). Flags like `--coverage`, `--quality`, `--parallel`, `--pattern`, and `--format` modify the runner's behavior.
    - **Watch Mode (`--watch` or `-w`):** When this flag is present, `M.run` delegates to `M.watch`. This function uses the `lib.tools.watcher` module (if available) to monitor the specified test files/directories for changes. Upon detecting a change, it re-triggers a test run using `lib.core.runner`. This mode requires the `lib.tools.watcher` module to be present.
    - **Interactive Mode (`--interactive` or `-i`):** Activated by this flag, `M.run` delegates to `M.interactive`. This function uses the `lib.tools.interactive` module (if available) to launch a terminal user interface (TUI) that allows the user to browse, select, and run tests interactively. This mode requires the `lib.tools.interactive` module.

- **Help & Version:** The flags `--help` (`-h`) and `--version` (`-V`) are handled early in `M.run`. They trigger the display of usage information (via `M.show_help`) or the Firmo version string, respectively, and then cause the script to exit without running tests.

- **Configuration Integration:** The CLI module interacts closely with `lib.core.central_config` (if available). It can load configuration from a specified file (`--config`), potentially set specific config values based on unknown `--key=value` arguments, and applies relevant CLI options (like coverage settings, quality level, runner format) to configure other modules (e.g., `coverage_module`, `quality_module`, `runner_module`) before execution begins.

- **Report Generation (`--report` or `-r`):** If this flag is used, the `M.report` function is called after the test run completes. This function, in turn, invokes the `report()` methods on the `coverage_module` and `quality_module`, if they are enabled and available, to generate the respective reports (e.g., HTML coverage report).

- **Dependency Management:** The module uses an internal `try_require` function to safely load its dependencies, particularly those for optional features like watch mode (`lib.tools.watcher`), interactive mode (`lib.tools.interactive`), coverage (`lib.coverage`), quality (`lib.quality`), etc. This allows the core CLI functionality (parsing args, running basic tests via runner) to work even if some optional modules are not installed or available, providing graceful degradation. Key dependencies include `lib.core.runner`, `lib.tools.discover`, `lib.core.central_config`, `lib.tools.logging`, and `lib.tools.error_handler`.

## Usage Examples / Patterns

The CLI is typically used via the main `test.lua` script.

### Pattern 1: Run All Tests

```bash
lua test.lua tests/
```
*(Runs all tests found within the `tests/` directory using default settings)*

### Pattern 2: Run with Code Coverage

```bash
lua test.lua --coverage tests/
# or shorthand:
lua test.lua -c tests/
```
*(Runs tests and collects code coverage data)*

### Pattern 3: Filter Tests by Name Pattern

```bash
lua test.lua --pattern="core" tests/
```
*(Runs only tests whose describe/it blocks or filenames match the Lua pattern "core")*

### Pattern 4: Run in Watch Mode

```bash
lua test.lua --watch tests/
# or shorthand:
lua test.lua -w tests/
```
*(Runs tests initially, then watches files in `tests/` and reruns tests automatically on changes)*

### Pattern 5: Run Specific Files or Directories

```bash
lua test.lua tests/unit/ test_file.lua path/to/another_test.lua
```
*(Runs only the specified tests)*

### Pattern 6: Show Help Message

```bash
lua test.lua --help
# or shorthand:
lua test.lua -h
```
*(Displays usage instructions and available options)*

### Pattern 7: Show Version

```bash
lua test.lua --version
# or shorthand:
lua test.lua -V
```
*(Displays the installed Firmo version)*

### Pattern 8: Combine Multiple Options

```bash
lua test.lua -c -q --report --report-format=html --pattern="api" tests/
```
*(Runs tests matching "api", enables coverage and quality checks, and generates an HTML report afterwards)*

## Related Components / Modules

- **`lib/tools/cli/init.lua`**: The source code implementation of this module.
- **`test.lua`**: The main script that typically requires and uses `lib.tools.cli.run()` to start the testing process based on command-line arguments.
- **`lib/core/runner/knowledge.md`**: The test runner module, orchestrated by the CLI for standard and watch mode execution.
- **`lib/tools/watcher/knowledge.md`**: Used by the CLI's watch mode (`-w`) to monitor file changes.
- **`lib/tools/interactive/knowledge.md`**: Used by the CLI's interactive mode (`-i`) to provide a TUI.
- **`lib/coverage/knowledge.md`**: The coverage system, enabled and configured via CLI flags (`-c`) and potentially triggered for reporting (`-r`).
- **`lib/quality/knowledge.md`**: The quality validation system, enabled via CLI flags (`-q`) and potentially triggered for reporting (`-r`).
- **`lib/core/central_config/knowledge.md`**: The central configuration system, used by the CLI to load configuration (`--config`) and apply settings.
- **`lib/tools/discover/knowledge.md`**: Used by the CLI (via the runner) to find test files when none are specified explicitly.
- **`lib/tools/logging/knowledge.md`**: Provides logging capabilities used throughout the CLI module.
- **`lib/tools/error_handler/knowledge.md`**: Used for robust error handling during module loading and execution.
