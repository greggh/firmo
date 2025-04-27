# tests/discovery Knowledge

## Purpose

The `tests/discovery/` directory contains tests dedicated to verifying the functionality of Firmo's test file discovery mechanism, implemented in the `lib/tools/discover` module. These tests ensure that the `discover.discover()` function accurately identifies and returns the correct list of test files based on various configurations, including include/exclude patterns, directory ignore rules, recursion settings, file extensions, and additional filtering patterns.

## Key Concepts

The primary test file, `discovery_test.lua`, covers the following aspects of the discovery module:

- **Pattern Matching (`include`/`exclude`):** Tests verify that files are correctly included or excluded based on the patterns provided in the configuration. This includes checking matches against filenames. **Note:** The current implementation of `lib/tools/discover` only supports the `*` character as a wildcard in patterns (converted to Lua's `.*`), not more complex glob syntax like `**` or `?`. Tests should reflect this limitation.
- **Directory Ignoring (`ignore`):** Tests ensure that files located within directories whose names match entries in the `ignore` configuration list (e.g., `node_modules`, `.git`) are correctly skipped during discovery, regardless of include/exclude patterns.
- **Recursion (`recursive`):** Tests validate the difference in behavior when `recursive` is set to `true` (scan subdirectories) versus `false` (scan only the top-level directory).
- **Extension Filtering (`extensions`):** Tests confirm that only files ending with an extension present in the `extensions` configuration list (default `.lua`) are considered potential test files.
- **Additional Filtering (`pattern` argument):** Tests verify that the optional second `pattern` argument passed to `discover.discover()` correctly filters the list of files *after* the initial include/exclude/ignore/extension rules have been applied. This pattern also uses the simple `*` wildcard.
- **Error Handling:** Tests cover scenarios where discovery might fail, such as attempting to discover files in a non-existent directory, ensuring that `discover.discover()` returns `nil, error_object` with the appropriate category (e.g., `IO`).
- **Test Environment Setup:** The tests heavily rely on `lib/tools/test_helper` (specifically `with_temp_test_directory`) to create temporary directory structures containing files with specific names and locations. This allows for precise control over the input conditions for each discovery test case, ensuring reliable and isolated validation of the discovery rules.

## Usage Examples / Patterns (Illustrative Test Snippets from `discovery_test.lua`)

### Basic Include/Exclude/Ignore Test

```lua
--[[
  Conceptual test verifying include, exclude, and ignore rules.
]]
local test_helper = require("lib.tools.test_helper")
local discover = require("lib.tools.discover")
local expect = require("lib.assertion.expect").expect

it("should discover correct files based on patterns and ignores", function()
  local file_structure = {
    ["a_test.lua"] = "-- test A",
    ["b_spec.lua"] = "-- test B",
    ["helper.lua"] = "-- not a test",
    ["ignored/c_test.lua"] = "-- should be ignored",
    [".git/config"] = "-- git file",
  }

  test_helper.with_temp_test_directory(file_structure, function(dir_path)
    -- Configure discover (resetting defaults if necessary)
    discover.configure({
      include = { "*_test.lua", "*_spec.lua" }, -- Default patterns
      exclude = { "helper.lua" },
      ignore = { ".git", "ignored" },           -- Default includes .git
      recursive = true,
      extensions = { ".lua" },                 -- Default
    })

    local results, err = discover.discover(dir_path)

    expect(err).to_not.exist()
    expect(results).to.exist()
    expect(results.files).to.be.a("table")
    expect(#results.files).to.equal(2)
    -- Check that returned paths are absolute and contain the expected files
    expect(results.files[1]).to.match("a_test%.lua$")
    expect(results.files[2]).to.match("b_spec%.lua$")
    -- Verify helper.lua and ignored/c_test.lua are NOT included
  end)
end)
```

### Non-Recursive Test

```lua
--[[
  Conceptual test verifying non-recursive discovery.
]]
-- Similar setup as above using with_temp_test_directory...
it("should not find files in subdirs if recursive is false", function()
  -- ... setup temp dir with file_structure ...
  test_helper.with_temp_test_directory(file_structure, function(dir_path)
    discover.configure({
      include = { "*_test.lua" },
      exclude = {},
      ignore = {}, -- Don't ignore 'ignored' dir for this test
      recursive = false, -- Key change
      extensions = { ".lua" },
    })

    local results, err = discover.discover(dir_path)

    expect(err).to_not.exist()
    expect(results).to.exist()
    expect(#results.files).to.equal(1) -- Only finds a_test.lua
    expect(results.files[1]).to.match("a_test%.lua$")
  end)
end)
```

### `pattern` Argument Test

```lua
--[[
  Conceptual test verifying the additional pattern argument.
]]
-- Similar setup as above using with_temp_test_directory...
it("should filter results using the pattern argument", function()
  -- ... setup temp dir with 'a_test.lua' and 'b_spec.lua' ...
  test_helper.with_temp_test_directory(file_structure, function(dir_path)
    discover.configure({ -- Use default include/exclude/etc.
      include = { "*_test.lua", "*_spec.lua" },
      exclude = { "helper.lua" },
      ignore = { ".git", "ignored" },
      recursive = true,
      extensions = { ".lua" },
    })

    -- Discover, but apply an additional filter for files starting with "a_"
    local results, err = discover.discover(dir_path, "a_*")

    expect(err).to_not.exist()
    expect(results).to.exist()
    expect(#results.files).to.equal(1) -- Only a_test.lua should match
    expect(results.files[1]).to.match("a_test%.lua$")
  end)
end)
```

### Error Handling Test

```lua
--[[
  Conceptual test verifying error on non-existent directory.
]]
local test_helper = require("lib.tools.test_helper")
local discover = require("lib.tools.discover")
local expect = require("lib.assertion.expect").expect

it("should return error if directory does not exist", function()
  local dir_path = "path/that/does/not/exist"
  local results, err = discover.discover(dir_path)

  expect(results).to_not.exist()
  expect(err).to.exist()
  expect(err.category).to.equal("IO")
  expect(err.message).to.match("Directory not found")
  expect(err.context.directory).to.equal(dir_path)
end)
```

## Related Components / Modules

- **Module Under Test:** `lib/tools/discover/knowledge.md` (and `lib/tools/discover/init.lua`)
- **Test File:** `tests/discovery/discovery_test.lua`
- **Helper Modules:**
    - **`lib/tools/test_helper/knowledge.md`**: Provides `with_temp_test_directory`, crucial for creating controlled filesystem environments for these tests.
    - **`lib/tools/filesystem/knowledge.md`**: The underlying module used by `lib/tools/discover` to perform directory scanning and file checks.
    - **`lib/tools/error_handler/knowledge.md`**: Used by `lib/tools/discover` to generate structured error objects for failures.
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Use `test_helper` for Isolation:** Always use utilities like `with_temp_test_directory` to create a clean, predictable filesystem structure for each test case. Avoid relying on the actual project's file layout, which can change and make tests brittle.
- **Test Pattern Variations:** Include tests covering different scenarios for `include`, `exclude`, and the `pattern` argument, such as patterns matching the start, middle, or end of filenames, multiple wildcards (`*`), and combinations of include/exclude rules.
- **Verify Absolute Paths:** Discovery should return absolute paths. Tests should verify this to ensure consistency for the test runner.
- **Test Edge Cases:** Include tests for empty directories, directories containing only non-matching files, directories matching `ignore` rules, and files with incorrect extensions.

## Troubleshooting / Common Pitfalls (Optional)

- **Incorrect Test Results (Finding Too Many/Few Files):**
    - **Cause 1:** The temporary directory structure created by `with_temp_test_directory` doesn't match the test's assumptions. **Solution:** Carefully check the `files_map` passed to `with_temp_test_directory`.
    - **Cause 2:** The `discover.configure()` call within the test is setting incorrect `include`, `exclude`, `ignore`, `recursive`, or `extensions` options. **Solution:** Verify the configuration applied just before calling `discover.discover()`.
    - **Cause 3:** Misunderstanding the pattern matching logic in `lib/tools/discover/init.lua`, especially the fact that only `*` is supported as a wildcard and how it's converted to a Lua pattern (`.*`). **Solution:** Review the `glob_to_pattern` function and test with simple patterns first.
- **Filesystem Errors During Tests:**
    - **Cause:** The test might be failing due to errors when `test_helper` tries to create or clean up the temporary directory/files, often due to filesystem permissions.
    - **Solution:** Check the error messages returned by `with_temp_test_directory` itself, or look for errors from `lib/tools/filesystem` or `lib/tools/error_handler` in the test output or logs. Ensure the test process has write permissions in the system's temporary directory location.
- **Discovery Error Not Handled:** If a test expects discovery to fail (e.g., non-existent directory) but doesn't check the returned error object correctly, the test might pass incorrectly or fail unexpectedly later. Use `expect(err).to.exist()` and potentially check `err.category`.
