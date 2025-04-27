# lib/tools/codefix Knowledge

## Purpose

The `lib/tools/codefix` module is designed to enhance Lua code quality and enforce consistency within the Firmo project and potentially user projects. It achieves this by integrating external linting (Luacheck) and formatting (StyLua) tools, alongside applying a set of built-in and potentially custom automated code transformations (fixers). This module provides both a command-line interface (CLI) for direct use and programmatic APIs for integration into other processes, such as the Firmo test reporting phase.

## Key Concepts

- **External Tool Integration:** The module acts as a wrapper around common Lua development tools:
    - **StyLua (Formatter):** It can automatically format Lua code according to specified style rules. The module checks if StyLua is available (`check_stylua`), finds its configuration file (`stylua.toml` or `.stylua.toml`) via `find_stylua_config`, and executes it using the system shell (`execute_command`).
    - **Luacheck (Linter):** It identifies potential issues like unused variables, syntax errors, and style violations. The module checks for its availability (`check_luacheck`), finds its configuration (`.luacheckrc`) via `find_luacheck_config`, executes it (`execute_command`), and parses its output (`parse_luacheck_output`) into a structured format for use by custom fixers.
    *Note: Both StyLua and Luacheck must be installed separately and accessible in the system's PATH for this integration to work.*

- **Custom Fixers:** Beyond external tools, the module includes several built-in automated code fixes:
    - `fix_trailing_whitespace`: Removes trailing whitespace from multiline strings (enabled by default).
    - `fix_unused_variables`: Prefixes unused local variables/arguments identified by Luacheck with `_` (enabled by default).
    - `fix_string_concat`: Performs basic optimization of string concatenations (enabled by default).
    - `fix_type_annotations`: **Experimental**, attempts to add basic JSDoc type hints (disabled by default).
    - `fix_lua_version_compat`: Applies basic fixes for Lua 5.1 compatibility (e.g., comments `goto`) (disabled by default).
    The module also allows registering new custom fixers via `register_custom_fixer`.

- **Fixing Pipeline (`fix_file`):** When fixing a file, the module applies a specific sequence:
    1.  **Backup:** Creates a `.bak` copy of the original file (if `config.backup` is true).
    2.  **Run Luacheck:** Executes Luacheck to gather issue information (needed for `fix_unused_variables`).
    3.  **Run Custom Fixers:** Applies all enabled custom fixers sequentially (e.g., `fix_trailing_whitespace`, `fix_unused_variables`).
    4.  **Run StyLua:** Formats the code using StyLua (if enabled).
    5.  **Run Luacheck (Verification):** Runs Luacheck again to ensure the fixes didn't introduce new errors or warnings.

- **File Discovery & Processing:**
    - `fix_lua_files`: This function orchestrates fixing multiple files. It uses `find_files` to locate `.lua` files within a directory based on include/exclude patterns defined in the configuration.
    - `find_files`: Relies on `lib/tools/filesystem` (`discover_files` or a Lua-based fallback) for recursive file searching and pattern matching.
    - `fix_files`: Iterates through the list of found files and calls `fix_file` on each.
    The `fix_lua_files` function supports options to sort files by modification time, limit the number processed, and generate a JSON report (`codefix_report.json`).

- **Configuration (`M.config`):** The module's behavior is controlled through the `M.config` table. Key settings include:
    - `enabled`: Master switch for the module.
    - `verbose`/`debug`: Control logging levels.
    - `use_stylua`/`stylua_path`/`stylua_config`: StyLua integration settings.
    - `use_luacheck`/`luacheck_path`/`luacheck_config`: Luacheck integration settings.
    - `custom_fixers`: A table enabling/disabling specific built-in fixers.
    - `include`/`exclude`: Lua patterns for file discovery.
    - `backup`/`backup_ext`: Backup file settings.

- **CLI Usage (`run_cli`):** Provides command-line access:
    - `fix [path]`: Finds and fixes Lua files in the directory or fixes a single file.
    - `check [path]`: Runs Luacheck without applying fixes.
    - `find [path]`: Lists files matching include/exclude patterns.
    - `help`: Displays usage information.
    Common options include `--verbose`, `--debug`, `--no-backup`, `--no-stylua`, `--no-luacheck`, `--limit N`, `--include PATTERN`, `--exclude PATTERN`, `--generate-report`.

- **Firmo Integration (`register_with_firmo`):** Allows integrating `codefix` into the main Firmo framework:
    - Registers the `fix`, `check`, and `find` commands with Firmo's CLI handler.
    - Can register a custom reporter that automatically runs `codefix` on tested source files after a test run, if configured via test options.

- **Backup System:** If `M.config.backup` is `true` (the default), a backup copy of the original file with the extension specified by `M.config.backup_ext` (default `.bak`) is created before any modifications are written.

- **Limitations/Unimplemented:** Several functions documented in the source file's header comments (e.g., `fix_directory`, `unregister_custom_fixer`, `restore_backup`, `get_custom_fixers`, `validate_lua_syntax`, `format_issues`) are placeholders and **not currently implemented**.

## Usage Examples / Patterns

### Pattern 1: Fixing Files via CLI

```bash
# Fix all Lua files in the src/ directory (uses default settings)
lua run_codefix.lua fix src/

# Fix a single file, disable backups
lua run_codefix.lua fix path/to/file.lua --no-backup

# Check (lint) files in lib/ but don't use Luacheck (only custom checks if any)
lua run_codefix.lua check lib/ --no-luacheck

# Find all .spec.lua files in the tests/ directory
lua run_codefix.lua find tests/ --include="%.spec%.lua$"

# Fix all files in current dir, generate JSON report
lua run_codefix.lua fix . --generate-report
```
*(Note: Assumes a `run_codefix.lua` script that requires and calls `lib.tools.codefix.run_cli(arg)`)*

### Pattern 2: Programmatic Fixing

```lua
--[[
  Requires the codefix module and fixes all Lua files in 'src/'
]]
local codefix = require("lib.tools.codefix")

-- Optional: Configure codefix before running
-- codefix.init({
--   verbose = true,
--   backup = false,
--   custom_fixers = { trailing_whitespace = false }
-- })
codefix.config.enabled = true -- Ensure it's enabled

local success, results = codefix.fix_lua_files("src/", {
  generate_report = true, -- Optional: generate a report
  report_file = "my_codefix_report.json"
})

if success then
  print("All files fixed successfully!")
else
  print("Some files failed to fix. See report/logs.")
end
```

## Related Components / Modules

- **`lib/tools/codefix/init.lua`**: The source code implementation of this module.
- **`lib/tools/filesystem/knowledge.md`**: Used extensively for finding files (`discover_files`, `scan_directory`), reading (`read_file`), writing (`write_file`), copying (`copy_file`), and path manipulation (`get_absolute_path`, etc.).
- **`lib/tools/logging/knowledge.md`**: Used for providing verbose/debug output and logging errors/warnings.
- **`lib/tools/error_handler/knowledge.md`**: Used for robust error handling, validation, and safe execution of I/O operations and external commands.
- **`lib/tools/json/knowledge.md`**: Used for generating the optional JSON report file.
- **External Tools:** Requires `stylua` and `luacheck` to be installed and available in the system's PATH for full functionality.
- **`docs/guides/configuration-details/knowledge.md`**: Provides context on external tool configuration files like `.luacheckrc` and `stylua.toml` which `codefix` tries to locate and use.

## Best Practices / Critical Rules (Optional)

- **Verify Tool Installation:** Ensure StyLua and Luacheck are installed correctly and accessible in your PATH if you intend to use them. Use `check_stylua()` and `check_luacheck()` or the CLI `--verbose` flag to confirm.
- **Review Backups:** If backups are enabled (default), periodically review the `.bak` files after running fixes, especially when enabling new fixers, to ensure changes are as expected. Delete old `.bak` files once confirmed.
- **Configure External Tools:** Use standard configuration files (`.luacheckrc`, `stylua.toml`) to define the specific rules and styles you want Luacheck and StyLua to enforce. `codefix` respects these configurations.
- **Use Version Control:** Always run `codefix` on code managed by a version control system (like Git) so changes can be easily reviewed and reverted if necessary.

## Troubleshooting / Common Pitfalls (Optional)

- **Tool Not Found Errors:** If you see errors related to StyLua or Luacheck not being found, ensure they are installed correctly and their installation directory is included in your system's PATH environment variable. You can specify explicit paths in `M.config.stylua_path` or `M.config.luacheck_path`.
- **Fixes Not Applied:** If expected fixes aren't happening:
    - Check if the module is enabled (`M.config.enabled = true`).
    - Verify the specific fixer is enabled in `M.config.custom_fixers`.
    - Ensure the relevant external tool (`stylua`, `luacheck`) is enabled if the fix depends on it.
    - Check include/exclude patterns to ensure the target file is being processed.
    - Use `--verbose` or `--debug` CLI flags (or configure programmatically) for detailed logs.
- **Incorrect Fixes:** Some custom fixers (like `fix_type_annotations`) are experimental. If fixes produce incorrect code, disable the specific fixer in the configuration. Report issues if they seem like bugs.
- **Permissions Issues:** Errors during file reading, writing, or backup creation might indicate filesystem permission problems. Ensure the process running `codefix` has the necessary permissions for the target files/directories.
