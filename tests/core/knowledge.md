# tests/core Knowledge

## Purpose

The `tests/core/` directory contains crucial unit and integration tests that validate the fundamental components of the Firmo framework, primarily those residing in the `lib/core/` directory. These tests ensure the stability and correctness of foundational features like the central configuration system, the main `firmo` object API and test definition functions (`describe`, `it`), module state isolation between tests, test tagging and filtering, internal type checking utilities, and version management. Failures in these tests often indicate significant issues within the framework's core logic.

## Key Concepts

The tests in this directory cover several key areas of Firmo's core functionality:

- **Central Configuration (`config_test.lua`):** Validates the loading of configuration from `.firmo-config.lua` files, the application of default values, overriding settings (e.g., via simulated CLI options or direct calls), schema validation for configuration values, and potentially saving configuration state.
- **Main Firmo API (`firmo_test.lua`):** Verifies that the main `firmo` object, typically obtained via `require("firmo")`, correctly initializes and exposes the essential framework functions like `firmo.describe`, `firmo.it`, `firmo.expect`, `firmo.before`, `firmo.after`, `firmo.configure`, etc. It ensures the basic structure for defining tests is functional.
- **Module Reset (`module_reset_test.lua`):** Tests the critical `lib/core/module_reset.lua` system. It verifies that resetting a module effectively clears its cached state in `package.loaded` and forces a fresh reload on the next `require`, ensuring test isolation. Tests may cover handling of simple and potentially complex/circular dependencies.
- **Tagging & Filtering (`tagging_test.lua`):** Focuses on the test execution filtering mechanism based on tags. It likely tests how tags are associated with `describe` or `it` blocks (e.g., `@tag` in description or options table) and verifies that the test runner correctly includes or excludes tests based on tag filters provided via configuration or CLI arguments.
- **Type Checking (`type_checking_test.lua`):** Validates the internal utility functions found in `lib/core/type_checking.lua`. These functions are used throughout Firmo to check function arguments and configuration values against expected Lua types (string, number, table, function) or custom validation predicates (e.g., "positive_number", "callable").
- **Versioning (`version_integration_test.lua`):** Tests the retrieval and potentially the format of the framework's version information, likely sourced from `lib/core/version.lua`.

## Usage Examples / Patterns (Illustrative Test Snippets)

### Configuration Test Examples (from `config_test.lua`)

```lua
--[[
  Examples showing tests for the central configuration system.
]]
local expect = require("lib.assertion.expect").expect
local central_config = require("lib.core.central_config") -- Assuming reset between tests

describe("Central Configuration", function()
  it("loads defaults correctly", function()
    local cfg = central_config.get_config()
    expect(cfg.runner.format).to.equal("detailed") -- Check a default value
  end)

  it("overrides defaults with provided options", function()
    central_config.configure({ runner = { format = "tap" } })
    local cfg = central_config.get_config()
    expect(cfg.runner.format).to.equal("tap")
  end)

  it("validates configuration values against schema", function()
    local ok, err = central_config.configure({ coverage = { threshold = "not-a-number" } })
    expect(ok).to_not.be_truthy()
    expect(err).to.exist()
    expect(err.category).to.equal("VALIDATION") -- Check error type
  end)
end)
```

### Module Reset Test Examples (from `module_reset_test.lua`)

```lua
--[[
  Examples demonstrating tests for the module reset functionality.
]]
local expect = require("lib.assertion.expect").expect
local module_reset = require("lib.core.module_reset")
-- Assume 'setup_mock_module' creates a dummy module file for testing

describe("Module Reset", function()
  local module_path = "tests.core.temp_mock_module"
  local original_module

  before_each(function()
    setup_mock_module(module_path, { initial_state = true })
    original_module = require(module_path)
  end)

  it("provides a fresh module instance after reset", function()
    original_module.initial_state = false -- Modify the loaded module
    local fresh_module = module_reset.reset_module(module_path)
    expect(fresh_module).to.exist()
    expect(fresh_module.initial_state).to.be_truthy() -- Should have default value
    expect(original_module.initial_state).to.be_falsey() -- Original remains modified
  end)
end)
```

### Tagging Test Examples (Conceptual, from `tagging_test.lua`)

```lua
--[[
  Conceptual example showing how tagging and filtering might be tested.
  Actual tests might involve running Firmo subprocesses with filters.
]]
local expect = require("lib.assertion.expect").expect

describe("Tagging and Filtering @core", function()
  it("runs core tests", function()
    -- This test has the '@core' tag inherited from describe
    expect(true).to.be_truthy()
  end)

  it("runs specific feature test @feature_x", function()
    -- This test has both '@core' and '@feature_x' tags
    expect(true).to.be_truthy()
  end)

  -- Tests would then verify that running with '--tags=@core' includes both,
  -- while '--tags=@feature_x' includes only the second one.
end)
```

### Error Handling Test Examples (within Core Tests)

```lua
--[[
  Example showing how tests verify error handling for core functions.
]]
local expect = require("lib.assertion.expect").expect
local test_helper = require("lib.tools.test_helper")
local central_config = require("lib.core.central_config")

it("throws validation error for invalid config path type", function()
  local err = test_helper.expect_error(function()
    -- Try to set a path with an invalid type
    central_config.configure({ reporting = { output_dir = 123 } })
  end, "Expected string") -- Match error message pattern

  expect(err).to.exist()
  expect(err.cause.category).to.equal("VALIDATION") -- Check original error category
end)
```

## Related Components / Modules

- **Modules Under Test:**
    - `lib/core/knowledge.md` (Overview)
    - `lib/core/central_config.lua`
    - `lib/core/runner.lua` (Tested indirectly via `firmo_test.lua`, `tagging_test.lua`)
    - `lib/core/test_definition.lua` (Tested indirectly via `firmo_test.lua`, `tagging_test.lua`)
    - `lib/core/module_reset.lua`
    - `lib/core/type_checking.lua`
    - `lib/core/version.lua`
    - `firmo.lua` (Main entry point object)
- **Test Files in this Directory:**
    - `config_test.lua`
    - `firmo_test.lua`
    - `module_reset_test.lua`
    - `tagging_test.lua`
    - `type_checking_test.lua`
    - `version_integration_test.lua`
- **Helper Modules:**
    - `lib/tools/test_helper/knowledge.md` (Used for `expect_error`, `with_error_capture`, temp files).
- **Parent Overview:** `tests/knowledge.md`

## Best Practices / Critical Rules (Optional)

- **Robustness is Key:** Tests for core components must be thorough and cover edge cases, as failures here can destabilize the entire framework.
- **Maintain Isolation:** Strictly ensure tests do not interfere with each other. Leverage the `module_reset` functionality (or `before_each`/`after_each` hooks that use it) when testing components that maintain state.
- **Verify Interactions:** Include tests that specifically verify how different core components interact (e.g., how the runner retrieves configuration from `central_config`, how `test_definition` interacts with tagging).
- **Test Error Paths:** Use `test_helper.expect_error` or `test_helper.with_error_capture` to explicitly test scenarios where core functions are expected to fail or throw validation errors.

## Troubleshooting / Common Pitfalls (Optional)

- **Test Failures:** Failures within `tests/core/` usually indicate significant bugs in Firmo's fundamental logic. Debugging requires a good understanding of the specific core component (`lib/core/...`) being tested.
- **State Leakage:** If tests pass when run individually (`lua firmo.lua tests/core/specific_test.lua`) but fail when run as part of a larger suite or with other core tests, suspect state leakage between tests. Ensure the module state is correctly reset using `module_reset` or appropriate test lifecycle hooks (`before_each`, `after_each`). Check `module_reset_test.lua` for examples.
- **Configuration Conflicts:** Tests modifying global configuration state might interfere with each other. Ensure configuration changes made within a test are properly reverted using `after_each` or by utilizing module reset for `central_config`.
