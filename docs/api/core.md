# Core Aggregator Module (`lib.core`)

This module acts as a central point for accessing several core utility submodules within Firmo. It attempts to safely load these submodules and re-exports them, along with some convenience functions.

## Overview

The `lib.core` module aggregates functionality from:

- `lib.core.type_checking`: Utilities for advanced type validation.
- `lib.core.version`: Version information for the Firmo framework.

If a submodule fails to load (e.g., due to missing dependencies or errors during loading), its corresponding fields in the returned `core` table will be `nil`.

## Usage

```lua
---@type core
local core = require("lib.core")

if core.version then
  print("Firmo Version (from core):", core.version._VERSION)
end

if core.type_checking then
  local is_str = core.is_exact_type("hello", "string") -- true
  print("Is 'hello' a string?", is_str)
end

-- Direct convenience access (if type_checking loaded)
if core.is_instance_of then
  -- Assume MyClass and instance exist
  local is_inst = core.is_instance_of(instance, MyClass)
  print("Is instance of MyClass?", is_inst)
end
```

## API Reference

The `core` table returned by `require("lib.core")` contains the following fields:

### `core.type_checking`

- **Type:** `table` | `nil`
- **Description:** The loaded `lib.core.type_checking` module, providing functions like `is_exact_type`, `is_instance_of`, `implements`, etc. Will be `nil` if the submodule failed to load.
- **See:** `docs/api/type_checking.md` (Note: This file might not exist yet or might need creation/update)

### `core.version`

- **Type:** `table` | `nil`
- **Description:** The loaded `lib.core.version` module, containing version information like `_VERSION`, `major`, `minor`, `patch`, and comparison functions. Will be `nil` if the submodule failed to load.
- **See:** `docs/api/version.md` (Note: This file might not exist yet or might need creation/update)

### `core.is_exact_type(value, expected_type)`

- **Type:** `function` | `nil`
- **Description:** Convenience alias for `core.type_checking.is_exact_type`. Checks if `value` has the exact primitive type specified by `expected_type` (string). Available only if `lib.core.type_checking` loaded successfully.
- **Returns:** `boolean`

### `core.is_instance_of(object, class)`

- **Type:** `function` | `nil`
- **Description:** Convenience alias for `core.type_checking.is_instance_of`. Checks if `object`'s metatable indicates it's an instance of `class`. Available only if `lib.core.type_checking` loaded successfully.
- **Returns:** `boolean`

### `core.implements(object, interface)`

- **Type:** `function` | `nil`
- **Description:** Convenience alias for `core.type_checking.implements`. Checks if `object` has all the methods defined in the `interface` table. Available only if `lib.core.type_checking` loaded successfully.
- **Returns:** `boolean`

### `core._VERSION`

- **Type:** `string`
- **Description:** The version identifier for the `lib.core` aggregator module itself (e.g., `"0.3.0"`).
