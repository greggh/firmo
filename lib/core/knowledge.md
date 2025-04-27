# Core Modules Knowledge

## Purpose

This document provides internal knowledge, patterns, and guidelines for developers working with Firmo's core modules located in `lib/core/`. These modules provide the foundational functionality for the entire framework.

## Key Concepts

-   **`central_config`:** The single source of truth for all framework configuration. Handles loading, saving, validation, defaults, and change notifications. All modules MUST use this.
-   **`module_reset`:** Manages Lua's `package.loaded` cache to provide test isolation by resetting module state between tests or on demand. Allows protection of core modules.
-   **`type_checking`:** Provides advanced type validation utilities beyond Lua's basic `type()`, including schema validation and custom type checks. Used internally by other modules like `central_config`.
-   **`error_handler`:** Defines the standardized structure for error objects and provides utilities like `try` and `safe_io_operation` for consistent error handling across the framework.
-   **`test_definition`:** Implements the core BDD functions (`describe`, `it`, `before`, `after`, `tags`, `fdescribe`, `fit`, etc.) and manages the test execution state (hooks, results, focus mode, filters).
-   **`runner`:** Core logic for executing test files, integrating with other modules like `test_definition`, `module_reset`, `coverage`, and `reporting`.
-   **`version`:** Contains framework version information.
-   **`fix_expect`:** Utility related to the assertion system.
-   **`init.lua`:** Aggregates and exports parts of the other core modules.

## Usage Examples / Patterns

### Configuration System (`central_config`)

```lua
--[[
  Demonstrates getting/setting config, registering a module schema/defaults,
  and watching for changes using central_config.
]]
local config = require("lib.core.central_config")
local logger = require("lib.tools.logging").get_logger("core-example") -- Example logger

-- Load config from file (optional, often handled by runner)
-- config.load_from_file(".firmo-config.lua")

-- Get and set values
local threshold = config.get("coverage.threshold", 80) -- Get with default
config.set("coverage.threshold", 90)

-- Register module config (schema and defaults)
config.register_module("my_db_module", {
  -- Schema
  field_types = { host = "string", port = "number", timeout = "number" },
  required_fields = {"host", "port"}
}, {
  -- Defaults
  host = "localhost", port = 5432, timeout = 5000
})

-- Watch for changes
config.on_change("my_db_module.timeout", function(path, old, new_val)
  logger.info("DB Timeout changed", { old = old, new = new_val })
end)
```

### Module Reset System (`module_reset`)

```lua
--[[
  Demonstrates using the enhanced module reset system.
  Note: Resetting is often handled automatically by the test runner if configured.
]]
local module_reset = require("lib.core.module_reset")
local logger = require("lib.tools.logging").get_logger("core-example")
local error_handler = require("lib.core.error_handler")

-- Typically called once at startup by the runner
module_reset.init()
module_reset.configure({ reset_modules = true }) -- Enable auto-reset

-- Manually reset all non-protected modules (e.g., in a custom setup)
local reset_count = module_reset.reset_all({ verbose = true })
print("Reset " .. reset_count .. " modules")

-- Manually reset modules matching a pattern
local service_count = module_reset.reset_pattern("app%.services%.")
print("Reset " .. service_count .. " service modules")

-- Protect essential modules from being reset
module_reset.protect({"app.config", "app.logger"})
```

### Type Validation (`type_checking`)

```lua
--[[
  Shows basic and schema-based type validation.
  Note: expect().to.be.a() uses M.isa which wraps type_checking logic.
]]
local type_checker = require("lib.core.type_checking")
local error_handler = require("lib.core.error_handler")
local expect = require("firmo").expect -- Assuming expect is available

-- Basic type checks (often done via assertions)
expect("hello").to.be.a("string")
expect(123).to.be.a("number")

-- Custom type registration (e.g., for specific validation rules)
type_checker.register_type("positive_number", function(value)
  return type(value) == "number" and value > 0
end)
-- expect(5).to.be.a("positive_number") -- If assertion paths were extended

-- Schema validation
local schema = {
  name = "string",
  age = "number",
  email = "string?",  -- Optional field
  settings = { theme = "string", notifications = "boolean" }
}
local function validate_user(user)
  local valid, errors = type_checker.validate(user, schema)
  if not valid then
    return nil, error_handler.validation_error(
      "Invalid user data", { errors = errors }
    )
  end
  return true
end

local user_data = { name = "Test", age = 30, settings = { theme = "dark", notifications = true } }
local is_valid, err = validate_user(user_data)
expect(is_valid).to.be_truthy()
```

## Related Components / Modules

-   **Source Files:** [`lib/core/`](.)
-   **Guides:**
    -   [`docs/guides/central_config.md`](../../docs/guides/central_config.md)
    -   [`docs/guides/module_reset.md`](../../docs/guides/module_reset.md)
    -   [`docs/guides/core.md`](../../docs/guides/core.md)
    -   [`docs/guides/error_handling.md`](../../docs/guides/error_handling.md)
-   **API Reference:**
    -   [`docs/api/central_config.md`](../../docs/api/central_config.md)
    -   [`docs/api/module_reset.md`](../../docs/api/module_reset.md)
    -   [`docs/api/type_checking.md`](../../docs/api/type_checking.md)
    -   [`docs/api/error_handling.md`](../../docs/api/error_handling.md)
    -   [`docs/api/test_definition.md`](../../docs/api/test_definition.md)
    -   [`docs/api/runner.md`](../../docs/api/runner.md)
    -   [`docs/api/core.md`](../../docs/api/core.md)
