# CLI Handling Refactoring Plan

## 1. Goal

Consolidate all command-line argument parsing, help generation, and command dispatch logic into the `lib/tools/cli/init.lua` module. This module will become the single source of truth for CLI handling, used by both the `scripts/runner.lua` (invoked by `test.lua`) and `firmo.lua` (when run directly or programmatically).

The primary objectives are:

- Eliminate redundant CLI parsing logic currently present in `scripts/runner.lua` and `lib/tools/cli/init.lua`.
- Ensure no loss of functionality; all currently supported CLI arguments and behaviors from both systems must be preserved or consciously unified.
- Make `scripts/runner.lua` a thinner wrapper that delegates CLI tasks to `lib/tools/cli/init.lua`.
- Verify that `firmo.lua` continues to use `lib/tools/cli/init.lua` correctly for its direct execution and programmatic CLI API.
- Maintain the primary user entry point `lua firmo.lua ...`.

## 2. Current State Analysis (Phase I)

- **Task 2.1: Detailed Comparison of CLI Handlers** [/] (Findings documented in section 8)
  - [x] Review `scripts/runner.lua` (`Runner:parse_arguments` and related logic in `main`).
    - [x] List all supported arguments, their types (flag, value), and how they map to `options` and subsequently to module configurations or runner behavior.
    - [x] Document how it handles test paths (single file, directory, multiple arguments).
    - [x] Document its help message generation (if any, or reliance on external docs).
  - [x] Review `lib/tools/cli/init.lua` (`M.parse_args`, `M.run`, `M.show_help`).
    - [x] List all supported arguments, their types, and how they map to `CommandLineOptions` and module configurations.
    - [x] Document its help message content.
    - [x] Note unique features (e.g., `--config <path>`, `--create-config`, direct dispatch to watch/interactive modes).
  - [x] Create a feature matrix comparing both parsers to identify: (Effectively done via the documented findings in section 8)
    - [x] Common arguments and behaviors.
    - [x] Arguments unique to `scripts/runner.lua`.
    - [x] Arguments unique to `lib/tools/cli/init.lua`.
    - [x] Differences in default values or behavior for common arguments.
  - [x] Analyze how `test.lua` invokes `scripts/runner.lua` (currently via `os.execute("lua scripts/runner.lua ...")`). (Analysis based on previous file reads documented in section 8)
  - [x] Analyze how `firmo.lua` invokes `lib/tools/cli/init.lua` (via `__call` metamethod). (Analysis based on previous file reads documented in section 8)

## 3. Design Consolidated CLI Module (Phase II)

- **Task 3.1: Define Unified Argument Set & Behavior** [/] (Design documented below)

  - [x] Based on the comparison, create a definitive list of all CLI arguments the consolidated `lib/tools/cli/init.lua` will support.
  - [x] For any conflicting arguments or behaviors, decide on the unified approach (e.g., which default value to use, which flag name is canonical). Prioritize the richer or more flexible option where sensible.
  - [x] Define the structure of the `options` table that the enhanced `parse_args` in `lib/tools/cli/init.lua` will produce. This table must contain all necessary information for `scripts/runner.lua` and other parts of the system to function.
  - **Proposed Unified CLI Argument Set & Behavior (Design Document):**
    _(This will serve as the specification for the new `lib/tools/cli/init.lua` parser)_

    **General Syntax Conventions:**

    - Flags: `--long-form`, `-s` (short form)
    - Options with values: `--option=value`, `--option value` (both should be supported)
    - Path arguments: Can be multiple files or directories, processed after flags.

    **Unified Arguments:**

    | Argument(s)                   | From                   | Type        | Unified Behavior & Notes                                                                                                                                                 | Target `options` Key (example)          |
    | ----------------------------- | ---------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------- |
    | `[paths...]`                  | Both                   | Positional  | List of files/directories. If dirs present, first is primary `options.dir`, rest + files go into `options.files_to_run`.                                                 | `options.paths_to_run`                  |
    | `--help`, `-h`                | Both                   | Flag        | Display comprehensive help message and exit.                                                                                                                             | `options.show_help`                     |
    | `--version`, `-V`             | Both                   | Flag        | Display Firmo version and exit.                                                                                                                                          | `options.show_version`                  |
    | `--verbose`, `-v`             | Both                   | Flag        | Enable verbose logging output across modules.                                                                                                                            | `options.verbose`                       |
    | `--coverage`, `-c`            | Both                   | Flag        | Enable code coverage.                                                                                                                                                    | `options.coverage_enabled`              |
    | `--coverage-debug`            | runner.lua             | Flag        | Enable debug logging specifically for the coverage module.                                                                                                               | `options.coverage_debug`                |
    | `--quality`, `-q`             | Both                   | Flag        | Enable test quality validation.                                                                                                                                          | `options.quality_enabled`               |
    | `--quality-level=<level>`     | Both                   | Value (int) | Set target quality level (1-5).                                                                                                                                          | `options.quality_level`                 |
    | `--threshold=<number>`        | runner.lua             | Value (int) | Generic threshold (0-100), primarily for coverage. Quality levels define their own internal criteria.                                                                    | `options.coverage_threshold`            |
    | `--watch`, `-w`               | Both                   | Flag        | Enable watch mode.                                                                                                                                                       | `options.watch_mode`                    |
    | `--interactive`, `-i`         | cli/init.lua           | Flag        | Enable interactive REPL mode.                                                                                                                                            | `options.interactive_mode`              |
    | `--parallel`, `-p`            | cli/init.lua           | Flag        | Enable parallel test execution (if supported by runner).                                                                                                                 | `options.parallel_execution`            |
    | `--pattern=<glob_pattern>`    | Both                   | Value (str) | Glob pattern for **test file discovery** (e.g., `*_test.lua`, `specs/**/*.lua`).                                                                                         | `options.file_discovery_pattern`        |
    | `--filter=<lua_pattern>`      | runner.lua             | Value (str) | Lua pattern to filter **test names/descriptions** (e.g., "core", "^should").                                                                                             | `options.test_name_filter`              |
    | `--config=<path>`             | cli/init.lua           | Value (str) | Load a specific Firmo configuration file.                                                                                                                                | `options.config_file_path`              |
    | `--create-config`             | cli/init.lua           | Flag        | Create a default `.firmo-config.lua` file and exit.                                                                                                                      | `options.create_default_config`         |
    | `--console-format=<type>`     | cli/init.lua (concept) | Value (str) | Set console output style (e.g., "default", "dot", "summary"). Renamed from `cli/init.lua`'s `--format`.                                                                  | `options.console_format`                |
    | `--report-formats=<csv_list>` | runner.lua (concept)   | Value (str) | Comma-separated list of formats for **generated report files** (e.g., "html,json,md"). Replaces `runner.lua`'s single `--format` and `cli/init.lua`'s `--report-format`. | `options.report_file_formats` (array)   |
    | `--report-dir=<path>`         | runner.lua             | Value (str) | Output directory for all generated reports.                                                                                                                              | `options.report_output_dir`             |
    | `--report`, `-r`              | cli/init.lua           | Flag        | General flag to trigger generation of configured file reports (coverage, quality) after tests run.                                                                       | `options.generate_reports`              |
    | `--json`                      | runner.lua             | Flag        | Shorthand/alias for `--console-format=json_results_dump`. Outputs a specific JSON stream for test results to console. Distinct from file reports.                        | `options.console_json_dump`             |
    | `--<key>=<value>`             | cli/init.lua           | Key-Value   | Generic mechanism to set arbitrary `central_config` values. Key is `config_key`, value is `config_value`.                                                                | `options.extra_config_settings` (table) |

    **Path Argument Handling:**

    - All positional arguments not matching a flag/option format will be considered paths.
    - If one or more directories are provided, the first directory becomes the primary `options.base_test_dir`.
    - All provided file paths and any remaining directory paths (after the first) are collected into `options.specific_paths_to_run`.
    - If no paths are provided, `options.base_test_dir` defaults to a standard location (e.g., `./tests/` or from config).

    **Default Values:**

    - Default values for options like `report_output_dir`, `file_discovery_pattern`, `quality_level`, etc., will be sourced from `central_config` first, then module-defined defaults. CLI flags override all.

    **Help Message (`--help`):**

    - Will be generated dynamically based on the defined arguments, their types, and descriptions.
    - Should clearly distinguish between file discovery patterns (`--pattern`) and test name filters (`--filter`).
    - Should clearly explain the two types of format flags (`--console-format` and `--report-formats`).

- **Task 3.2: Design `lib/tools/cli/init.lua` Enhancements** [/] (Design documented below)

  - [x] Plan modifications to `lib/tools/cli/init.lua`'s `M.parse_args` to support the unified argument set.
  - [x] Plan modifications to `lib/tools/cli/init.lua`'s `M.run` (or a new dispatch function if needed) to:
    - [x] Correctly initialize and configure all necessary Firmo modules (core, runner, coverage, quality, central_config, logging, etc.) based on parsed options. This might involve it taking over some initialization tasks currently in `scripts/runner.lua`.
    - [x] Execute tests (via `lib.core.runner` for normal runs), or dispatch to watch/interactive modes.
    - [x] Handle report generation.
    - [x] Return a success status suitable for `os.exit()`.
  - [x] Plan updates to `M.show_help` to reflect the unified argument set.
  - **Design Document for `lib/tools/cli/init.lua` Enhancements:**

    **A. `M.parse_args(args)` Function Enhancements:**

    - **Input**: Receives the raw `args` table from the command line (e.g., `_G.arg`).
    - **Output**: Produces a comprehensive `options` table adhering to the structure defined in "Proposed Unified CLI Argument Set" (Task 3.1, e.g., `options.coverage_enabled`, `options.report_file_formats`, etc.).
    - **Core Logic**:
      1.  Initialize `options` by merging:
          - Module-defined hardcoded defaults.
          - Values from `central_config` (if `.firmo-config.lua` or a file from `--config` is loaded).
      2.  Iterate through the input `args` table:
          - Implement robust parsing to support:
            - Short flags (e.g., `-c`, `-v`).
            - Long flags (e.g., `--coverage`, `--verbose`).
            - Options with values using space separator (e.g., `--quality-level 3`).
            - Options with values using equals separator (e.g., `--pattern=*_spec.lua`).
            - Generic key-value pairs (`--<key>=<value>`) to be stored in `options.extra_config_settings`.
          - Populate the `options` table fields based on parsed arguments, overriding defaults/config values.
          - **Path Argument Handling**: Collect all positional arguments (not matching flag/option syntax) into a temporary list. After all flags are parsed, process this list:
            - Identify directories and files.
            - If directories are specified, the first one becomes `options.base_test_dir`.
            - All specified files and any subsequent directories are added to `options.specific_paths_to_run` (array).
            - If no paths are provided, `options.base_test_dir` defaults to a standard value (e.g., `./tests/` or from `central_config`).
          - **Conflicting/Renamed Flags**:
            - Handle `--format` (from `scripts/runner.lua`, for report files) by parsing its value(s) into `options.report_file_formats` (array). This will be renamed to `--report-formats`.
            - Handle `--format` (from `lib/tools/cli/init.lua`, for console output) by parsing its value into `options.console_format`. This will be renamed to `--console-format`.
            - Handle `--report-format` (from `lib/tools/cli/init.lua`) by parsing its value into `options.report_file_formats`, potentially merging if `--report-formats` is also used.
          - **Early Exit Flags**:
            - If `--config <path>` is found, attempt to load it into `central_config` immediately so subsequent args can override it.
            - If `--create-config` is found, set a flag like `options.perform_create_config = true` for `M.run` to handle.
            - If `--help` or `--version` found, set `options.show_help = true` or `options.show_version = true`.
      3.  Return the populated `options` table.
    - **Error Handling**: Collect parsing errors (e.g., missing value for an option) into an `options.parse_errors` list.

    **B. `M.run(args_or_options)` Function Enhancements:**

    - **Input**: Can accept either a raw `args` table (it will call `M.parse_args` internally) or a pre-parsed `options` table.
    - **Core Logic**:
      1.  **Parse Arguments**: If raw `args` received, call `M.parse_args(args)` to get the `options` table. If `options.parse_errors` is populated, print errors and exit.
      2.  **Handle Early Exits**:
          - If `options.show_help`, call `M.show_help()` and exit successfully.
          - If `options.show_version`, print version from `version_module` and exit successfully.
          - If `options.perform_create_config`, attempt to create `.firmo-config.lua` using `central_config` defaults and exit.
      3.  **Apply Generic Config Settings**: If `options.extra_config_settings` has entries, apply them using `central_config.set(key, value)`.
      4.  **Initialize Core Modules**:
          - **Logging**: Configure based on `options.verbose` (and potentially other future logging flags).
          - **Firmo Instance**: `local firmo = require("firmo")`. This instance will be passed to runner functions.
          - **Coverage Module**: If `options.coverage_enabled`:
            - `require("lib.coverage")`.
            - Configure it using `central_config` values for "coverage" (which reflect defaults + `.firmo-config.lua` + `--config` file + generic `key=value` args), and then specifically override with `options.coverage_threshold`, `options.coverage_debug`.
            - Call `coverage.init(...)` and `coverage.start()`.
            - Store the coverage instance in `options.coverage_instance`.
          - **Quality Module**: If `options.quality_enabled`:
            - `require("lib.quality")`.
            - Configure it using `central_config` values for "quality", and override with `options.quality_level` and `options.coverage_instance` (if coverage active).
            - Call `quality.init(...)`.
            - Store the quality instance in `options.quality_instance`.
            - Register `quality.reset` with `firmo`.
          - (Initialize other modules like watcher, interactive, parallel as needed based on options).
      5.  **Dispatch to Execution Mode**:
          - If `options.watch_mode`, call `M.watch(firmo_instance, options)` (new signature for `M.watch`).
          - If `options.interactive_mode`, call `M.interactive(firmo_instance, options)` (new signature for `M.interactive`).
          - Else (normal test run):
            - **Determine Target Files**:
              - If `options.specific_paths_to_run` is populated, use these.
              - Else, use `discover_module.find_tests(options.base_test_dir, options.file_discovery_pattern, options.exclude_patterns_from_config_or_cli)`.
            - **Apply Test Name Filter**: If `options.test_name_filter` is set, call `firmo.set_filter(options.test_name_filter)` (or equivalent on `test_definition`).
            - **Execute Tests**:
              - Call `runner_module.run_all(target_files, firmo_instance, cli_options_for_runner)` or `runner_module.run_file(single_target_file, firmo_instance, cli_options_for_runner)`.
              - `cli_options_for_runner` will be a subset of `options` relevant to the runner (e.g., console format, quality/coverage instances).
              - Collect the overall success status from the runner.
      6.  **Reporting Phase**:
          - If `options.coverage_enabled` and `options.coverage_instance`, call `coverage_instance.shutdown()` and get coverage data.
          - If `options.quality_enabled` and `options.quality_instance`, call `quality_instance.get_report_data()`.
          - If `options.generate_reports` is true and `options.report_file_formats` is populated:
            - `require("lib.reporting")`.
            - Call `reporting.auto_save_reports` with the collected data, `options.report_output_dir`, `options.report_file_formats`, and other necessary context (like primary test file path for naming single reports).
            - Update overall success based on reporting success.
      7.  **Console Output**: Ensure appropriate summary (passes, fails, skipped, time) is printed to console based on `options.console_format`. The `runner_module` might handle this, or `lib/tools/cli/init.lua` could do a final summary.
      8.  **Return Success**: Return final boolean success status (e.g., `true` if all tests passed and all operations like reporting succeeded).

    **C. `M.show_help()` Function Updates:**

    - Modify `M.show_help()` to dynamically generate or display a comprehensive help message based on the full unified argument set defined in Task 3.1.
    - The help text should clearly distinguish between `--file-discovery-pattern` (for finding test files) and `--test-name-filter` (for filtering tests by their describe/it names).
    - It must explain the difference between `--console-format` (for stdout styling) and `--report-formats` (for generated report files).
    - List all supported short and long forms of arguments.

- **Task 3.3: Design `scripts/runner.lua` Interface** [/] (Design documented below)

  - [x] Define how `scripts/runner.lua`'s `main` function will interact with the refactored `lib/tools/cli/init.lua`. It should essentially pass the raw `arg` table from `test.lua` to `cli_module.run()` and use its return value for `os.exit()`.
  - [x] Identify any setup (e.g., `package.path` adjustments, global error handlers) currently in `scripts/runner.lua` that needs to be preserved, moved to `lib/tools/cli/init.lua`, or handled by `test.lua`.
  - **Design Document for `scripts/runner.lua` Interface:**

    The `scripts/runner.lua` script will be significantly simplified. Its primary role will be to act as a thin wrapper that captures the raw command-line arguments and passes them to the consolidated `lib/tools/cli/init.lua` module for processing and execution.

    **A. `runner.main(args)` Function (in `scripts/runner.lua`):**

    - **Input**: Receives the raw `args` table (command-line arguments, typically from `_G.arg` via `test.lua`).
    - **Core Logic**:
      1.  **Require Consolidated CLI Module**:
          ```lua
          local cli_module = require("lib.tools.cli") -- Or use a try_require for robustness
          if not cli_module or not cli_module.run then
            print("ERROR: Firmo CLI module (lib/tools/cli/init.lua) could not be loaded or is missing the 'run' function.")
            os.exit(2) -- Indicate a framework error
          end
          ```
      2.  **Essential Early Setup (Minimal)**:
          - Review any existing top-level setup in `scripts/runner.lua` (e.g., `package.path` modifications specifically for `scripts/` context, very early global error handling if any).
          - Most initialization logic (logging, central_config, module loading like `firmo` main instance, coverage, quality) should be moved into `lib/tools/cli/init.lua`'s `run` function.
    - The goal is to keep `scripts/runner.lua` as lean as possible. It might only need to ensure `lib/` is in `package.path` if not already handled by `test.lua` or the execution environment. 3. **Delegate to Consolidated CLI**: - Call `local success = cli_module.run(args)`. The `args` table passed should be the raw command-line arguments. 4. **Exit**: - Call `os.exit(success and 0 or 1)` based on the boolean result from `cli_module.run()`.

    **B. Removed Functionality from `scripts/runner.lua` (If it becomes a wrapper):**

    - The `runner.parse_arguments` function will be removed entirely.
    - The `runner.print_usage` function will be removed (help is handled by `lib/tools/cli/init.lua`).
    - Most of the logic within `runner.main` concerning argument interpretation, module initialization (coverage, quality), report triggering, and mode dispatching (watch mode) will be removed as these responsibilities move to `lib/tools/cli/init.lua`.
    - Helper functions like `runner.run_file`, `runner.run_all`, `runner.find_test_files`, `runner.watch_mode` will be removed from `scripts/runner.lua` as their core logic will reside in or be called by `lib/tools/cli/init.lua` (which uses `lib.core.runner` for actual test execution).

    **C. Interaction with `test.lua` (Revised Approach):**

    - `test.lua` currently uses `os.execute("lua scripts/runner.lua " .. table.concat(args, " "))`.
    - **Revised strategy**: Modify `test.lua` to directly call `lua firmo.lua " .. table.concat(args, " ")`. This makes `firmo.lua` (which uses the consolidated `lib/tools/cli`) the single script entry point invoked by `test.lua`.

    **D. Implication for `scripts/runner.lua` (Revised Approach):**

    - With `test.lua` calling `firmo.lua` directly, `scripts/runner.lua` becomes redundant and can be deleted.

## 4. Implementation (Phase III)

- **Task 4.1: Refactor `lib/tools/cli/init.lua`** [/] (In Progress - core functions done, unit tests pending)
  - [x] Implement the enhanced `M.parse_args` to support the unified argument set. (Completed via manual edits by user)
  - [x] Implement the enhanced `M.run` (or new dispatcher) to handle all initialization, configuration, and execution logic. (Completed via manual edits by user)
  - [x] Update `M.show_help`. (Completed via manual edits by user)
  - [ ] Add comprehensive unit tests for the new parsing and dispatch logic within `lib/tools/cli/init.lua`. (Remains To Do)
- **Task 4.2: Modify `test.lua` to Invoke `firmo.lua`** [x] (User manually changed `os.execute` in `test.lua` to call `"lua firmo.lua ..."`. Verified with `lua firmo.lua --help` on 2025-05-10.)
  - [x] Change the `os.execute(...)` line in `test.lua` to construct and execute a command like `lua firmo.lua ...args...` instead of `lua scripts/runner.lua ...args...`.
- **Task 4.3: Delete `scripts/runner.lua`** [x] (User confirmed manual deletion.)
  - [x] Remove the `scripts/runner.lua` file from the project as it will no longer be used. (User confirmed manual deletion.)
- **Task 4.4: Delete `test.lua`** [x] (User confirmed manual deletion.)
  - [x] Remove the `test.lua` file from the project root, as `firmo.lua` is now the sole CLI script entry point. (User confirmed manual deletion.)
- **Task 4.5: Verify `firmo.lua` as Sole CLI Entry Point** [/] (In Progress - basic verification done, further testing in Phase IV)
  - [x] Confirm that `firmo.lua` correctly handles CLI arguments when invoked directly (e.g., `lua firmo.lua tests/ --coverage`). (Verified for `--help` and simple test run with `lua firmo.lua tests/simple_test.lua --verbose`)
  - [x] Ensure exit codes are correctly propagated. (Verified for basic cases; further testing in Phase IV)

## 5. Testing and Validation (Phase IV)

**Status: IN PROGRESS (as of 2025-05-11). CLI test file has been comprehensively updated.**

- **Task 5.1: Unit Tests for CLI Module** [/]

  - [x] Ensure `lib/tools/cli/init.lua` has robust unit tests covering argument parsing variations and option combinations:
    - [x] Basic flag parsing (long-form, short-form, combined)
    - [x] Options with values (space separator, equals separator)
    - [x] Path argument handling
    - [x] Special flags (help, version)
    - [x] Report format parsing
  - [x] Add tests for module initialization and configuration:
    - [x] Coverage module initialization
    - [x] Quality module initialization
    - [x] File discovery configuration
    - [x] Report generation
    - [x] Parallel execution
    - [x] Watch mode setup
  - [x] Add error handling tests:
    - [x] Invalid argument parsing
    - [x] Missing required modules
    - [x] Config file errors
    - [x] Path validation errors
    - [x] Report generation errors
  - [x] Add output format tests:
    - [x] Default format
    - [x] Dot format
    - [x] JSON output handling

- **Task 5.2: Integration Tests** [/]

  - [x] Test basic CLI scenarios using `lua firmo.lua ...`:
    - [x] Default run (no args, with path)
    - [x] Help (`--help`, `-h`)
    - [x] Version (`--version`, `-V`)
    - [x] Coverage (`--coverage`, `-c`)
    - [x] Quality (`--quality`, `--quality-level`)
    - [x] Watch mode (`--watch`, `-w`)
    - [x] Pattern filtering (`--pattern`)
    - [x] Report generation (`--report`, different formats)
    - [x] Specific file/directory arguments
    - [x] Verbose mode (`--verbose`)
    - [x] Parallel mode (`--parallel`)
  - [ ] Test edge cases and advanced scenarios:
    - [ ] Interactive mode (`--interactive`)
    - [ ] Config file loading/creation
    - [ ] Complex path combinations
    - [ ] Multiple format specifications
  - [ ] Test programmatic invocation of `require("firmo"):cli_run(...)`.

- **Task 5.3: Regression Testing** [/]
  - [x] Initial verification of output formats (console, reports)
  - [x] Basic error handling verification
  - [ ] Exit code verification across all scenarios
  - [ ] Full system integration testing (coverage + quality + watch + reports)

**Next Steps:**

1. Complete remaining integration tests for edge cases and advanced scenarios
2. Perform comprehensive regression testing
3. Document any behavioral changes or improvements in relevant docs

## 6. Documentation Update (Phase V)

- **Task 6.1: Update JSDoc**
  - [x] lib/tools/cli/init.lua (New JSDoc generated and applied manually by user)
  - [x] scripts/runner.lua (N/A - File deleted)
  - [ ] firmo.lua (Review JSDoc for CLI interaction points)
  - [x] test.lua (N/A - File deleted)
- **Task 6.2: Update Markdown Documentation**
  - [x] docs/guides/cli.md (Updated for new CLI structure and firmo.lua entry point)
  - [x] lib/tools/cli/knowledge.md (Updated to reflect new JSDoc and CLI functionality)
  - [x] scripts/knowledge.md (Updated to remove references to deleted runner.lua/test.lua)
  - [x] Review and update other key documentation files:
    - [x] `CLAUDE.md` (Updated CLI commands and descriptions)
    - [x] Root `knowledge.md` (Updated CLI commands and descriptions)
    - [x] `docs/api/cli.md` (Rewritten to reflect current CLI module API)
    - [x] `README.md` (Updated CLI command examples)
- **Task 6.3: Update This Plan**
  - [x] Update This Plan (Marking recent documentation updates as complete, noting skipped Phase IV)

## 7. Potential Challenges and Considerations

- **Behavioral Subtleties**: Ensure subtle differences in how arguments are currently processed (e.g., order of precedence, error handling for invalid args) are understood and handled consistently in the unified parser.
- **Global State/Initialization Order**: The refactoring might change when and how certain modules (logging, central_config, firmo instance itself) are initialized. This needs careful management to avoid issues.
- **Performance**: Ensure the new CLI parsing and dispatch are efficient.
- **Backward Compatibility**: While the goal is unification, consider if any very specific CLI behaviors relied upon by existing user scripts (if any beyond the standard `lua firmo.lua`) need special handling or clear deprecation. (Likely not a major issue for an internal refactor).

This plan provides a structured approach to consolidate CLI handling, improve maintainability, and establish a clear, single point for future CLI feature development.

## 8. Knowledge and Context from Analysis Phase

(Findings from Task 2.1 will be documented here as they are discovered.)

### Task 2.1 Findings: Detailed Comparison of CLI Handlers (Initial Review)

This section documents the initial findings from reviewing `scripts/runner.lua` and `lib/tools/cli/init.lua`.

#### A. `scripts/runner.lua` Analysis (`Runner:parse_arguments` & `main`)

- **Invocation**: Primarily invoked by `lua firmo.lua ...` which uses `os.execute("lua scripts/runner.lua ...args")`.
- **Argument Parsing (`runner.parse_arguments`):**
  - Supports flags like `--verbose` (`-v`), `--coverage` (`-c`), `--quality` (`-q`), `--watch` (`-w`), `--json` (`-j` for console JSON test results).
  - Supports options with values in forms `--option=value` or `--option value` for:
    - `--pattern=<value>`: For test file discovery pattern (passed to `find_test_files`).
    - `--filter=<value>`: For filtering specific test names/descriptions (passed to `firmo.set_filter`).
    - `--report-dir=<value>`: Output directory for reports.
    - `--quality-level=<value>`: Sets quality level.
    - `--threshold=<value>`: Generic threshold, seems intended for coverage/quality.
    - `--format=<value>`: For specifying **report file formats** (e.g., "html", "json"). Critically, this is stored in `options.formats` as a table, implying it can handle one format specified this way (overwrites default list).
  - Positional arguments: The first non-flag argument is treated as the primary `path` (file or directory). Does not robustly handle multiple path arguments.
  - Help: `--help` / `-h` triggers `runner.print_usage()` for a manually crafted help text.
  - Version: `--version` / `-V` prints version from `lib.core.version` and exits.
- **Execution Logic (`runner.main`):**
  - Loads `central_config` and `.firmo-config.lua`.
  - Uses CLI `options.formats` to set `reporting.formats_override` in `central_config` for coverage and quality reports.
  - Initializes `coverage_module` (if `--coverage`) and `quality_module` (if `--quality`), configuring them with CLI options and `central_config` values.
  - Dispatches to `runner.watch_mode`, `runner.run_all` (for directories), or `runner.run_file`.
  - Manages coverage lifecycle (`start`, `shutdown`).
  - Triggers report generation for coverage (multiple formats via `reporting.save_coverage_report`) and quality (multiple formats via `reporting.auto_save_reports`). Quality reports for directory runs are generated per-file within `run_file`.

#### B. `lib/tools/cli/init.lua` Analysis (`M.parse_args`, `M.run`, `M.show_help`)

- **Invocation**:
  - When `firmo.lua` is run as a script (`lua path/to/firmo.lua ...`), its `__call` metamethod invokes `cli_module.run(arg)`.
  - Functions (`parse_args`, `show_help`, `cli_run`) are exposed on the `require("firmo")` table for programmatic use.
- **Argument Parsing (`M.parse_args`):**
  - Supports flags: `--help` (`-h`), `--parallel` (`-p`), `--watch` (`-w`), `--interactive` (`-i`), `--coverage` (`-c`), `--quality` (`-q`), `--version` (`-V`), `--verbose` (`-v`), `--report` (`-r`).
  - Supports options with values (typically `--option <value>` form):
    - `--pattern <value>`: Test file discovery pattern.
    - `--quality-level <value>`: Sets quality level.
    - `--format <value>`: For **console output format** (e.g., "default", "dot", "summary").
    - `--report-format <value>`: For specifying **report file formats** (e.g., "html", "junit").
    - `--config <path>`: Loads an external Firmo configuration file into `central_config`.
    - `--create-config`: Creates a default `.firmo-config.lua` file.
  - Supports generic `--key=value` arguments, which are passed to `central_config.set(key, value)`.
  - Positional arguments: Collects all into `options.files`. If directories are present, the first becomes `options.dir`.
- **Help Generation (`M.show_help`):**
  - Prints a manually crafted help message, different in content and style from `scripts/runner.lua`'s help.
- **Execution Logic (`M.run`):**
  - Loads all core modules. Parses args. Handles help/version.
  - Configures `coverage_module` and `quality_module` based on options and `central_config`.
  - Dispatches to `M.watch(options)` or `M.interactive(options)` if those flags are set.
  - Configures `runner_module` (from `lib.core.runner`) with console format, parallel, coverage, etc.
  - Calls `runner_module.run_tests(options.files, ...)` or `runner_module.run_discovered(options.dir, options.pattern)`.
  - Calls `M.report(options)` if `options.report` is true, which in turn calls `coverage_module.report()` and `quality_module.report()`.

#### C. Initial Comparison & Key Differences

- **Invocation Paths**: Two distinct CLI entry points (`lua test.lua` vs. `lua firmo.lua`).
- **Argument Syntax**:
  - `runner.lua`: Supports `--opt=val` and `--opt val`.
  - `cli/init.lua`: Primarily `--opt val`, but also generic `--key=val`.
- **Path Handling**:
  - `runner.lua`: Single primary path argument.
  - `cli/init.lua`: More flexible with multiple files/directories via `options.files` and `options.dir`.
- **`--format` Flag**: **Critical conflict.**
  - `runner.lua`: For report file formats (e.g., html, json output to files). Stored in `options.formats` array.
  - `cli/init.lua`: For console output style (e.g., dot, summary). Stored in `options.format` string.
- **Report Generation Control**:
  - `runner.lua`: Implicit based on `--coverage` or `--quality`. File formats from `--format`. Directory from `--report-dir`.
  - `cli/init.lua`: Generic `--report` flag. File formats from `--report-format`. Output directory not explicitly controlled by a dedicated flag in its parser, relies on `options.dir` or module defaults.
- **Unique Arguments to `cli/init.lua`**:
  - `--interactive`, `-i`
  - `--parallel`, `-p`
  - `--config <path>`
  - `--create-config`
  - Generic `--key=value` for `central_config`.
  - `--report-format <value>`
  - `--report`, `-r`
- **Unique Arguments to `runner.lua`**:
  - `--threshold <value>` (generic)
  - `--json`, `-j` (for console JSON dump of test results)
  - `--coverage-debug`, `-cd`
  - `--filter <value>` (for test name/description filtering, distinct from file pattern)
  - `--report-dir <value>`
- **Module Initialization**: Both perform module initialization, but the consolidated CLI should centralize this.
- **Help Messages**: Different content and style.

#### D. Summary for Consolidation Strategy

- The unified CLI in `lib/tools/cli/init.lua` needs to incorporate all functionalities.
- **Argument syntax**: Standardize on supporting both `--opt=val` and `--opt val`.
- **Path handling**: Adopt `lib/tools/cli/init.lua`'s more flexible multi-file/dir approach.
- **Disambiguate `--format`**: Use distinct flags like `--console-format` (for stdout style) and `--report-formats` (for file outputs, supporting multiple values like `runner.lua`'s current `options.formats`).
- **Merge unique arguments**: All unique useful flags from both should be supported by the unified parser.
- **Centralize initialization**: `lib/tools/cli/init.lua` should handle all module initializations (Firmo, coverage, quality, logging, central_config) based on final parsed options.
- `scripts/runner.lua` should become a very thin wrapper, primarily passing `arg` to the `run` function of the consolidated `lib/tools/cli/init.lua`.
- `test.lua` can likely remain unchanged if `scripts/runner.lua` is refactored carefully.
- `firmo.lua`'s usage of `lib/tools/cli/init.lua` seems largely compatible but will benefit from the consolidated features.
