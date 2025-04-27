# tests/coverage Knowledge

## Purpose

The `tests/coverage/` directory houses unit and integration tests specifically designed to validate Firmo's code coverage system, which is implemented primarily within the `lib/coverage/` module and its sub-modules. These tests aim to ensure the accuracy and reliability of the coverage measurement process, including the correct installation and operation of the Lua debug hook, precise tracking of executed code lines, proper handling of configuration options (like include/exclude patterns), and the generation of valid coverage statistics.

## Key Concepts

The tests in this directory cover the essential components of the coverage system:

- **Core Coverage API (`coverage_test.lua`):** This file likely tests the main public interface of the coverage module. Tests typically involve:
    - Configuring the module (e.g., setting `include` or `exclude` patterns) using `coverage.configure()`.
    - Starting coverage collection using `coverage.start()`.
    - Executing some target Lua code (often requiring a simple module like `lib/samples/calculator.lua`).
    - Stopping coverage collection using `coverage.stop()`.
    - Retrieving the collected coverage statistics using `coverage.get_stats()`.
    - Asserting that the structure and content of the returned statistics (e.g., hit counts for specific lines, inclusion/exclusion of files) are correct based on the executed code and configuration.

- **Debug Hook Mechanism (`hook_test.lua`):** This file focuses on the lower-level integration with Lua's `debug` library, specifically the functionality within `lib/coverage/hook.lua`. Tests here verify:
    - That the debug hook is correctly installed via `debug.sethook` when coverage starts and removed when it stops.
    - That the custom hook function accurately intercepts line execution events.
    - That the hook correctly increments hit counts in the internal statistics table (`stats.lua`) for the corresponding file and line number upon execution.
    These tests might involve more direct manipulation or mocking related to the `debug` library or the hook state.

- **General Test Focus:** Across these files, common testing strategies include:
    - Using simple, well-understood target code (like `lib/samples/calculator.lua`) where the expected execution paths and line numbers are clear.
    - Testing various Lua constructs (functions, loops, conditional `if`/`elseif`/`else` blocks, local vs. global scope) to ensure lines within them are counted correctly.
    - Verifying that lines in files matching exclude patterns (or not matching include patterns) are correctly ignored and do not appear in the results.
    - Testing edge cases like empty files or files with only comments.

## Usage Examples / Patterns (Illustrative Test Snippets)

### Basic Hit Count Verification

```lua
--[[
  Conceptual test verifying line hit counts after running sample code.
]]
local coverage = require("lib.coverage")
local calculator = require("lib.samples.calculator") -- Target code
local expect = require("lib.assertion.expect").expect

it("should count hits for executed lines in calculator.add", function()
  coverage.start() -- Start coverage
  local result = calculator.add(2, 3) -- Execute target code
  coverage.stop() -- Stop coverage

  local stats = coverage.get_stats()
  local calc_file_stats = stats["lib/samples/calculator.lua"] -- Adjust path as needed

  expect(result).to.equal(5)
  expect(calc_file_stats).to.exist()
  -- Assuming line 24 is 'local result = a + b' inside calculator.add
  expect(calc_file_stats.lines[24]).to.equal(1)
  -- Assuming line 25 is 'return result' inside calculator.add
  expect(calc_file_stats.lines[25]).to.equal(1)
  -- Assuming line 17 ('local calculator = {}') is not counted as executable by parser
  expect(calc_file_stats.lines[17]).to_not.exist()
end)
```

### Testing File Exclusion

```lua
--[[
  Conceptual test verifying that excluded files are ignored.
]]
local coverage = require("lib.coverage")
local calculator = require("lib.samples.calculator")
local expect = require("lib.assertion.expect").expect

it("should exclude files matching exclude patterns", function()
  coverage.configure({ exclude = { "lib/samples/calculator.lua" } }) -- Exclude the calculator
  coverage.start()
  calculator.add(1, 1) -- Execute code in the excluded file
  coverage.stop()

  local stats = coverage.get_stats()

  -- Assert that no stats were collected for the excluded file
  expect(stats["lib/samples/calculator.lua"]).to_not.exist()
end)
```

### Hook Verification Test (Conceptual)

*(Actual implementation in `hook_test.lua` might be more complex)*
```lua
--[[
  Conceptual test focusing on the hook's counting mechanism.
]]
local hook_module = require("lib.coverage.hook")
local stats_module = require("lib.coverage.stats")
local expect = require("lib.assertion.expect").expect

it("hook handler should increment line count", function()
  -- Setup: Ensure stats are clean, potentially mock debug.getinfo
  stats_module.reset()
  local mock_info = { source = "test.lua", currentline = 5 }

  -- Simulate the hook being called for line 5 of test.lua
  hook_module.line_hook_handler("line", mock_info)

  -- Assert: Check if the internal stats were updated correctly
  local file_stats = stats_module.get_file_stats("test.lua")
  expect(file_stats).to.exist()
  expect(file_stats.lines[5]).to.equal(1)
end)
```

## Related Components / Modules

- **Module Under Test:**
    - `lib/coverage/knowledge.md` (Overview)
    - `lib/coverage/init.lua` (Main API)
    - `lib/coverage/hook.lua` (Debug hook integration)
    - `lib/coverage/stats.lua` (Data storage)
- **Test Files:**
    - `tests/coverage/coverage_test.lua`
    - `tests/coverage/hook_test.lua`
- **Dependencies & Related Modules:**
    - `lib/samples/calculator.lua`: Often used as the target code for coverage measurement in tests.
    - `lib/tools/parser/knowledge.md`: Used by the coverage system to identify executable lines. Issues here can affect coverage accuracy.
    - `lib/tools/test_helper/knowledge.md`: Provides utilities potentially used within these tests.
    - `lib/tools/filesystem/knowledge.md`: May be used if tests involve temporary files or specific file structures.
    - Lua `debug` library: The standard Lua library providing `debug.sethook`, which is fundamental to the coverage mechanism.
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Use Simple Targets:** Employ straightforward sample code (like `lib/samples/calculator.lua`) for testing basic coverage counting, where identifying executable lines and expected hit counts is unambiguous.
- **Isolate Hook Tests:** Tests specifically targeting the debug hook (`hook_test.lua`) should be carefully constructed to avoid interfering with any coverage collection potentially performed by the test runner itself. They might need to directly manipulate hook state or use mocks.
- **Verify Configuration Effects:** Tests should explicitly configure relevant options (e.g., `include`, `exclude`) and assert that the coverage results correctly reflect those settings.
- **Consider Runner Coverage:** Be aware that running the entire test suite *with* coverage enabled (`lua test.lua --coverage tests/`) can add noise or interfere with tests *of* the coverage system. These tests might need special handling or should be run without global coverage enabled (`lua test.lua tests/coverage/`) when debugging specific issues.

## Troubleshooting / Common Pitfalls (Optional)

- **Inaccurate Hit Counts:**
    - **Cause:** May indicate a bug in the `lib/coverage/hook.lua` logic, incorrect line number reporting from `debug.getinfo`, or inaccuracies in `lib/tools/parser`'s identification of executable lines for the target code.
    - **Debugging:** Inspect the detailed statistics (`stats` object). Add logging within the hook handler (`hook_module.line_hook_handler`) to see what file/line is reported by `debug.getinfo` when specific target lines are executed. Compare with the AST and executable lines map generated by the parser for the target file.
- **Configuration Not Working (Includes/Excludes):**
    - **Cause:** Lua patterns in `include` or `exclude` might be incorrect. Configuration might not be applied correctly before `coverage.start()` is called. File paths might not be normalized consistently.
    - **Debugging:** Verify the Lua patterns used. Ensure `coverage.configure()` is called *before* `coverage.start()`. Use logging to inspect the effective configuration and the file paths being checked against patterns within the coverage module.
- **Hook Conflicts / Errors:**
    - **Symptom:** Errors mentioning `debug.sethook` or unexpected behavior related to debugging.
    - **Cause:** Multiple parts of the code (e.g., the test itself, the runner, another module) might be trying to install or manage the debug hook simultaneously.
    - **Solution:** Ensure only one component manages the hook at a time. Tests directly manipulating the hook need careful setup and teardown.
- **Interference from Runner Coverage:**
    - **Symptom:** Tests in this directory pass when run individually (`lua test.lua tests/coverage/some_test.lua`) but fail when run as part of `lua test.lua --coverage tests/`.
    - **Cause:** The global coverage hooks installed by the runner interfere with the hooks managed by the test itself.
    - **Solution:** Try running the test file without global coverage. If the test needs to manage hooks itself, it might require logic to temporarily disable or work around the runner's hooks, or it might be inherently incompatible with being run under global coverage.
