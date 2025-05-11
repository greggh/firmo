# scripts/ Knowledge

## Purpose

The `scripts/` directory houses a collection of standalone Lua scripts used for various tasks related to the development, maintenance, and utility operations for the Firmo framework. These scripts focus on tasks like code quality checks, version management, documentation fixing, and other development aids. The primary test execution entry point has moved to `firmo.lua` (utilizing `lib/tools/cli`).

## Key Concepts

- **Standalone Execution:** Most scripts in this directory are intended to be executed directly from the command line using the Lua interpreter (e.g., `lua scripts/check_syntax.lua lib/`). They often perform a specific, self-contained task.
- **Development & Maintenance Aids:** Many scripts function as tools for developers working on Firmo. They automate checks (syntax, assertion patterns, print statements), help with repetitive tasks (version bumping, markdown fixing), or assist in debugging (monitoring temp files).

## Usage Examples / Patterns

### General Execution Pattern

```bash
# General pattern for executing scripts from the project root directory
lua scripts/script_name.lua [arguments...]
```

### Specific Examples

```bash
# Example: Check syntax of all Lua files in the 'lib' directory
lua scripts/check_syntax.lua lib/

# Example: Find print statements in test files
lua scripts/find_print_statements.lua tests/

# Example: Bump the patch version of the project
# lua scripts/version_bump.lua patch

```

## Related Components / Modules (Scripts in this Directory)

- **`check_assertion_patterns.lua`**: Scans specified Lua test files using the `lib/tools/parser` to detect potentially incorrect or outdated assertion styles (e.g., Busted-style `assert.*` instead of Firmo's `expect.*`).
- **`check_syntax.lua`**: Uses the external Lua compiler command (`luac -p`) to perform a basic syntax check on Lua files within given paths. Helps catch syntax errors quickly without full execution.
- **`cleanup_temp_files.lua`**: Attempts to locate and delete temporary files that might have been left behind by Firmo's temporary file system (`lib/tools/filesystem/temp_file.lua`), using common temporary directory locations as a heuristic.
- **`find_print_statements.lua`**: Searches specified Lua files for calls to `print()` or `io.write()`, often used to identify leftover debugging statements.
- **`fix_markdown.lua`**: An entry point script to invoke the Markdown fixing capabilities provided by `lib/tools/markdown`. Takes file or directory paths as arguments.
- **`monitor_temp_files.lua`**: Periodically lists files found in typical system temporary directories. Useful for debugging issues related to temporary file creation or cleanup during test development.
- **`version_bump.lua`**: Increments the project version number (major, minor, or patch) stored within `lib/core/version.lua`. Requires an argument specifying the type of bump.
- **`version_check.lua`**: Reads the current version string from `lib/core/version.lua` and prints it to the console.
- **`utilities/`** (Subdirectory): Contains additional, potentially more specialized or experimental utility scripts. See **`scripts/utilities/knowledge.md`** for details.

## Best Practices / Critical Rules (Optional)

- **Understand Script Purpose:** Before running any script, especially those that might modify files (`fix_markdown.lua`, `version_bump.lua`), understand its function and potential side effects.
- **Check Usage/Arguments:** Many scripts accept command-line arguments (paths, flags). Review the script's source code comments or try running it with `--help` (if implemented) to understand expected arguments.
- **Run from Project Root:** Most scripts assume they are executed from the Firmo project's root directory to ensure correct `require` paths for accessing the `lib/` modules.

## Troubleshooting / Common Pitfalls (Optional)

- **Script Errors:**
  - Check console output for Lua error messages and stack traces.
  - **Incorrect Arguments:** Ensure you are passing the correct type and number of arguments (e.g., file paths) to the script.
  - **Missing Dependencies:**
    - Firmo Libraries: If a script fails with a `module 'lib....' not found` error, ensure you are running the script from the project root directory.
    - External Tools: Some scripts rely on external commands (e.g., `check_syntax.lua` needs `luac`). Ensure these tools are installed and available in your system's PATH.
  - **Permissions:** Scripts reading or writing files (`check_syntax.lua`, `fix_markdown.lua`, etc.) might fail due to filesystem permissions. Ensure the user running the script has appropriate access.
- **Unexpected Behavior:**
  - Verify the script's logic matches your expectations.
  - Double-check the arguments you provided.
  - Add `print()` statements within the script (temporarily) for debugging if needed.
