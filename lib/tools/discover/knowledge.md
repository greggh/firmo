# lib/tools/discover Knowledge

## Purpose

The `lib/tools/discover` module is responsible for locating Lua test files within a project structure. It scans a specified directory (defaulting to `tests/`) based on a set of configurable rules, including include/exclude patterns, directory ignores, and file extensions. Its primary consumer within Firmo is the test runner (`lib/core/runner`), which uses this module to determine the list of files to load and execute.

## Key Concepts

- **Discovery Process:** The core workflow involves these steps:
    1.  **List Files:** Uses the `lib/tools/filesystem` module (`list_files` or `list_files_recursive`) to get a list of all files within the target directory, potentially including subdirectories based on the `recursive` configuration.
    2.  **Initial Filtering (`M.is_test_file`):** Each file path obtained is passed through the `M.is_test_file` function, which applies configured exclusion, inclusion, and extension rules (see below).
    3.  **Optional Pattern Filtering:** If the main `M.discover` function was called with an additional `pattern` argument (a glob-like string), this pattern is applied as a final filter *only* to the files that passed the `is_test_file` check.
    4.  **Sort & Return:** The resulting list of absolute file paths is sorted alphabetically and returned, along with counts.

- **Configuration (`M.configure`):** The module's behavior is controlled by an internal `config` table, which can be modified using `M.configure(options)`. Key options and their defaults are:
    - `ignore` (string[]): An array of directory *names* (not full paths) to completely ignore during traversal. Default: `{"node_modules", ".git", "vendor"}`.
    - `include` (string[]): An array of glob-like patterns that filenames *must* match to be considered. Default: `{"*_test.lua", "*_spec.lua", "test_*.lua", "spec_*.lua"}`.
    - `exclude` (string[]): An array of glob-like patterns for filenames to explicitly exclude, even if they match an include pattern. Default: `{}`.
    - `recursive` (boolean): If `true`, search subdirectories recursively. Default: `true`.
    - `extensions` (string[]): An array of file extensions (including the dot) that are allowed. Default: `{".lua"}`.
    The `M.add_include_pattern(pattern)` and `M.add_exclude_pattern(pattern)` functions provide a convenient way to add patterns to the respective lists.

- **Filtering Logic (`M.is_test_file`):** This function determines if a given file path represents a valid test file according to the configuration. It applies checks in this specific order:
    1.  Does the path match any `config.exclude` pattern? If yes, return `false` (excluded).
    2.  Does the path contain any directory name listed in `config.ignore` (e.g., `/node_modules/` or `vendor/`)? If yes, return `false` (ignored directory).
    3.  Does the path end with any extension listed in `config.extensions`? If no, return `false` (invalid extension).
    4.  Does the filename part of the path match at least one pattern in `config.include`? If yes, return `true` (valid test file). Otherwise, return `false`.

- **`M.discover(dir?, pattern?)` Function:** This is the main public function for initiating discovery.
    - **Inputs:** Takes an optional `dir` string (path to the directory to search, defaults to `"tests"`) and an optional `pattern` string (a glob-like pattern for additional filtering).
    - **Process:** Validates the directory exists, calls the filesystem module to list files, iterates through them applying `M.is_test_file`, and then applies the `pattern` argument (if provided) to the results of `is_test_file`.
    - **Output:**
        - On success: Returns a table like `{ files = {sorted_absolute_paths...}, matched = final_count, total = final_count }`.
          *Important Note:* The current implementation sets `total` to be equal to `matched`, representing the final count *after* all filters (including the `pattern` argument) have been applied. It does *not* represent the count before the final `pattern` filter was applied.
        - On failure (e.g., directory doesn't exist, filesystem error): Returns `nil` and an error object from `lib/tools/error_handler`.

- **Glob Patterns:** The `include`, `exclude`, and `pattern` arguments use a simplified glob-like syntax where only the asterisk (`*`) is treated as a special character. It is converted internally to the Lua pattern `.*` (match zero or more of any character). All other characters that have special meaning in Lua patterns (e.g., `^ $ % . [ ] + - ?`) are automatically escaped.

- **Dependencies:** The module has a critical dependency on `lib/tools/filesystem` for directory traversal and file listing. It also uses `lib/tools/logging` for informative messages and warnings, and `lib/tools/error_handler` for creating standardized error objects.

## Usage Examples / Patterns

### Pattern 1: Basic Discovery

```lua
--[[
  Discover test files in the default 'tests/' directory using default settings.
]]
local discover = require("lib.tools.discover")

local results, err = discover.discover()

if results then
  print("Found " .. results.matched .. " test files:")
  for i, file_path in ipairs(results.files) do
    print(i .. ": " .. file_path)
  end
else
  print("Error discovering tests: " .. tostring(err))
end
```

### Pattern 2: Custom Directory and Non-Recursive

```lua
--[[
  Discover test files only in the top level of the 'src/' directory.
]]
local discover = require("lib.tools.discover")

discover.configure({ recursive = false })
local results = discover.discover("src/")
-- Process results...
```

### Pattern 3: Discovery with Additional Filtering Pattern

```lua
--[[
  Find test files in 'tests/' that match default include patterns
  AND also contain the substring "core" somewhere in their path.
]]
local discover = require("lib.tools.discover")

-- The pattern "*core*" is applied AFTER the standard include/exclude/extension checks.
local results = discover.discover("tests/", "*core*")
-- Process results...
```

### Pattern 4: Adding Include/Exclude Patterns

```lua
--[[
  Add a pattern to include '.spec.lua' files and exclude '_fixture.lua' files.
]]
local discover = require("lib.tools.discover")

discover.add_include_pattern("*.spec.lua")
discover.add_exclude_pattern("*_fixture.lua")

local results = discover.discover()
-- Process results...
```

### Pattern 5: Checking a Single File

```lua
--[[
  Check if a specific file path is considered a test file
  based on the current discovery configuration.
]]
local discover = require("lib.tools.discover")

local path1 = "tests/core/runner_test.lua"
local path2 = "src/utils.lua"
local path3 = "tests/fixtures/helper_fixture.lua"

discover.add_exclude_pattern("*_fixture.lua") -- Assume this was added

print(path1 .. " is test file? " .. tostring(discover.is_test_file(path1))) -- Should be true (by default)
print(path2 .. " is test file? " .. tostring(discover.is_test_file(path2))) -- Should be false (not in include, maybe wrong dir)
print(path3 .. " is test file? " .. tostring(discover.is_test_file(path3))) -- Should be false (matches exclude)
```

## Related Components / Modules

- **`lib/tools/discover/init.lua`**: The source code implementation of this module.
- **`lib/tools/filesystem/knowledge.md`**: Provides the underlying functions (`list_files`, `list_files_recursive`, `is_directory`) used for finding files and checking directories. **Crucial dependency.**
- **`lib/core/runner/knowledge.md`**: The primary consumer of this module. The runner calls `discover.discover()` to get the list of test files it needs to load and execute.
- **`lib/tools/cli/knowledge.md`**: The command-line interface module uses `discover.discover()` when test paths are not explicitly provided, potentially passing the `--pattern` argument from the command line to the `discover` function.
- **`lib/tools/logging/knowledge.md`**: Used for logging discovery start/completion and warnings.
- **`lib/tools/error_handler/knowledge.md`**: Used for handling errors, particularly related to filesystem access.

## Best Practices / Critical Rules (Optional)

- **Specificity:** Keep `include` and `exclude` patterns reasonably specific to avoid accidentally including non-test files or excluding valid tests. Relying on common naming conventions like `_test.lua` or `_spec.lua` is recommended.
- **Performance:** On very large projects with deep directory structures, overly broad `include` patterns combined with `recursive = true` might lead to performance overhead during discovery. Consider organizing tests logically and potentially using more specific target directories if discovery seems slow.
- **Naming Conventions:** Adhering to consistent test file naming conventions (e.g., `*_test.lua`) simplifies configuration and makes the `include` patterns more effective.

## Troubleshooting / Common Pitfalls (Optional)

- **Test Files Not Found:**
    - Verify the target directory exists and is correct.
    - Check `config.include` patterns: Do they match your filenames? Use `M.is_test_file(path)` to debug.
    - Check `config.extensions`: Does it include the correct extension (e.g., `.lua`)?
    - Check `config.recursive`: Should it be `true` if tests are in subdirectories?
    - Check `config.ignore`: Is the directory containing your tests accidentally listed?
    - Check `config.exclude`: Is an exclude pattern unintentionally matching your test files?
- **Too Many Files Found:**
    - Add more specific `exclude` patterns to filter out unwanted files (e.g., `"*_helper.lua"`).
    - Add irrelevant directory names (like `build/`, `dist/`) to `config.ignore`.
    - Make `config.include` patterns more specific.
- **Errors During Discovery:** Usually indicates a filesystem issue.
    - Check directory permissions for the user running Firmo.
    - Ensure the target directory path passed to `discover()` is valid. Check logs for details from `error_handler`.
- **`pattern` Argument Not Working:** Remember the `pattern` argument in `M.discover(dir, pattern)` is applied *after* the file has already passed the main `M.is_test_file` check (include/exclude/extension/ignore rules). It's an additional filter on the *results* of the primary discovery logic.
