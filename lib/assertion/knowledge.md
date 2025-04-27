# Assertion Module Knowledge

## Purpose

This document explains key internal concepts, implementation patterns, and design considerations for the `lib/assertion` module. It's intended for developers working on or extending Firmo's assertion system.

The module provides the core `expect()` API for BDD-style assertions, handles deep equality checks, type validation, and integrates with the `error_handler` and `coverage` systems. It is designed to be relatively standalone, using lazy-loading for dependencies like `error_handler`, `logging`, and `coverage` to prevent circular dependencies within the core framework.

## Key Concepts

-   **`expect()` Entry Point:** The primary function `M.expect(v)` initiates an assertion chain. It returns a new `ExpectChain` object holding the value `v` and initial state (`action = ""`, `negate = false`). It also increments the global `M.assertion_count` for test metrics.

-   **Chainable API (`paths` table & `ExpectChain` Metatable):**
    -   The `M.paths` table defines the valid structure of assertion chains (e.g., `expect(v).to.equal(x)`). It's a nested table where keys represent chainable words (`to`, `be`, `equal`, `a`, etc.).
    -   The `ExpectChain` object uses a metatable with an `__index` function. When a property (like `.to` or `.equal`) is accessed on the `ExpectChain` object, the `__index` function:
        -   Validates if the accessed property (`k`) is a valid next step in the chain based on the current `action` and the `M.paths` definition.
        -   Updates the `action` field of the `ExpectChain` object to the accessed property (`k`).
        -   Handles the special `.to_not` case by setting the `negate` flag.
        -   Returns the `ExpectChain` object itself, allowing further chaining.

-   **Negation (`to_not`):** Accessing the `.to_not` property on the `ExpectChain` object sets its internal `negate` flag to `true`. The final test function execution checks this flag and inverts the test result if `negate` is true, also selecting the appropriate error message (`nerr` vs `err`).

-   **Test Functions (`test` field):**
    -   Assertion endpoints (like `equal`, `exist`, `be_a`) are defined in the `M.paths` table with a `test` field containing a function.
    -   When an assertion chain is *called* (e.g., `expect(v).to.equal(x)` calls the `equal` endpoint), the `__call` metamethod of the `ExpectChain` object executes the corresponding `test` function.
    -   The `test` function receives the actual value (`t.val`) and any arguments passed during the call (`...`).
    -   It performs the assertion logic and **must** return three values: `success (boolean), success_message (string), failure_message (string)`. The messages are used when generating assertion errors.

-   **Deep Equality (`M.eq`):** This internal function performs deep equality checks, primarily used by `expect().to.equal()`. It handles:
    -   Basic type comparisons.
    -   Recursive table comparisons.
    -   Cycle detection (using a `visited` table tracking `tostring(t1)..":"..tostring(t2)` pairs).
    -   Optional epsilon comparison for numbers (`eps` parameter).
    -   String/number coercion comparison (`tostring(v1) == tostring(v2)`).

-   **Type Checking (`M.isa`):** Used by `expect().to.be.a()` and `expect().to.be.an()`. It checks:
    -   Basic Lua types via `type(v) == x` if `x` is a string.
    -   Class/metatable inheritance if `x` is a table by traversing the metatable chain (`getmetatable(meta).__index`).

-   **Stringification (`stringify`, `diff_values`):** Internal helper functions for creating readable error messages.
    -   `stringify`: Converts any Lua value to a string, handling tables recursively with indentation and cycle detection (`[Circular Reference]`).
    -   `diff_values`: Compares two values (primarily tables) and generates a string highlighting the differences, used within the `equal` assertion's failure message.

-   **Error Handling Integration:**
    -   If an assertion's `test` function returns `false`, the `__call` metamethod generates a structured error using `error_handler.create`.
    -   Context provided includes `expected`, `actual`, `action`, and `negate`.
    -   The appropriate error message (`err` or `nerr` from the `test` function) is used.
    -   Internal operations (like number comparisons in `M.eq`) use `pcall` or `error_handler.try` for safety.

-   **Coverage Integration:**
    *   Upon successful assertion completion, the `__call` metamethod attempts to get the coverage module via lazy-loading (`get_coverage()`).
    *   If available, it calls `coverage.mark_line_covered(file_path, line_number)`, passing the source file and line number obtained from `debug.getinfo(3, "Sl")` (level 3 points to the caller of the assertion function).
    *   This marks the line containing the `expect(...)` call as 'covered' in coverage reports.

-   **Extensibility:** New assertions can be added by defining new entries in the `M.paths` table. An entry should include a `test` function following the required signature (`function(v, ...)` returning `boolean, string, string`). Chainable words (like `be` or `have`) can be added as simple table entries containing an array of the valid next steps.

## Usage Examples / Patterns

### Adding a Custom Assertion

```lua
--[[
  Example of adding a new assertion `.to.be_positive()` to the paths table.
]]
local assertion = require("lib.assertion") -- Assuming access to the module table

-- Define the test function
local function test_positive(v)
  local is_positive = type(v) == "number" and v > 0
  return is_positive,
         "expected " .. tostring(v) .. " to be positive",
         "expected " .. tostring(v) .. " to not be positive"
end

-- Add the assertion to the paths table under the 'be' chain
assertion.paths.be.positive = { test = test_positive }

-- Now it can be used:
-- expect(5).to.be.positive()   -- Passes
-- expect(-1).to.be.positive()  -- Fails
-- expect(0).to_not.be.positive() -- Passes
```

### Simplified Internal Flow for `expect(a).to.equal(b)`

1.  `expect(a)`: Returns `ExpectChain{ val = a, action = "", negate = false }`.
2.  `.to`: `__index` validates `to` is allowed after `""`, sets `action = "to"`, returns `ExpectChain`.
3.  `.equal`: `__index` validates `equal` is allowed after `to`, sets `action = "equal"`, returns `ExpectChain`.
4.  `(b)`: `__call` executes `paths.equal.test(a, b)`.
    a.  `paths.equal.test` calls `M.eq(a, b)`.
    b.  `M.eq` performs deep comparison.
    c.  `paths.equal.test` returns `result, success_msg, failure_msg`.
5.  `__call` checks `negate` flag (false in this case).
6.  If `result` is `false`, `__call` uses `failure_msg` and context (`a`, `b`, "equal", `false`) to create and throw a structured error via `error_handler.create`.
7.  If `result` is `true`, `__call` calls `coverage.mark_line_covered()`, resets `action` to `""`, and returns the `ExpectChain` object.

## Related Components / Modules

-   **Source:** [`lib/assertion/init.lua`](init.lua)
-   **Usage Guide:** [`docs/guides/assertion.md`](../../docs/guides/assertion.md)
-   **API Reference:** [`docs/api/assertion.md`](../../docs/api/assertion.md)
-   **Error Handling:** [`lib/core/error_handler/init.lua`](../core/error_handler/init.lua) - Used to generate structured assertion errors.
-   **Coverage:** [`lib/coverage/init.lua`](../coverage/init.lua) - Used to mark lines covered by successful assertions.
-   **Logging:** [`lib/tools/logging/init.lua`](../tools/logging/init.lua) - Used internally for trace/debug logging within the assertion module.
-   **Type Checking:** [`lib/core/type_checking.lua`](../core/type_checking.lua) - `M.isa` relies on this for class checks (though currently implemented inline).

