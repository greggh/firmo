# lib/tools/vendor Knowledge

## Purpose

The `lib/tools/vendor` directory serves as the designated location within the Firmo source code repository for including third-party libraries directly. This practice, known as "vendoring," ensures that specific, known-working versions of essential external dependencies are always available to the framework during development, testing, and distribution, without requiring users to install them separately via external package managers (like LuaRocks) or system repositories.

## Key Concepts

- **Dependency Management:** Vendoring is a strategy to bundle dependencies with the main project. It provides greater control over the exact versions used and guarantees their availability, simplifying the build and deployment process for Firmo itself and potentially for projects using Firmo.
- **Version Control:** The specific versions of the libraries included in the `vendor` directory are managed and tracked directly within Firmo's Git repository. Updates to vendored libraries are handled as deliberate code changes.
- **Immutability (No Direct Modification):** A critical principle is that the code within the `vendor` subdirectories should generally be treated as immutable. Direct modifications should be avoided. If changes or patches are absolutely necessary, they should ideally be contributed back to the original upstream project. If local patches are maintained, they must be clearly documented and potentially kept separate to facilitate easier updates of the underlying vendor library later.

## Usage Examples / Patterns

### Requiring a Vendored Library

```lua
--[[
  Standard pattern for requiring a library included in the vendor directory.
  Use the full path starting from 'lib.tools.vendor'.
]]
-- Example: Requiring the vendored LPegLabel library
local lpeglabel, load_err = pcall(require, "lib.tools.vendor.lpeglabel")

if not lpeglabel then
  -- Handle the error (e.g., log it) - this shouldn't happen if vendoring is correct
  print("Critical Error: Failed to load vendored library lpeglabel: " .. tostring(load_err))
else
  -- Now use functions provided by the loaded library
  local P, V = lpeglabel.P, lpeglabel.V
  -- ... use P, V to define LPegLabel patterns ...
end
```

## Related Components / Modules

This directory currently contains the following vendored libraries:

- **`lib/tools/vendor/lpeglabel/knowledge.md`**: Provides the LPegLabel library, an extension for the LPeg parsing library, which is crucially used by Firmo's Lua parser (`lib/tools/parser`).

*(If other libraries are added to the `vendor` directory in the future, they should be listed here with a link to their respective `knowledge.md` file.)*

## Best Practices / Critical Rules

- **Require via Full Path:** Always use the full Lua path starting from `lib.tools.vendor.` when requiring a vendored library (e.g., `require("lib.tools.vendor.lpeglabel")`). Avoid relying on global modifications to `package.path`.
- **Do Not Modify Vendor Code:** Treat the contents of subdirectories within `lib/tools/vendor` as read-only. If you encounter a bug or need a feature, report it or contribute to the library's original upstream source repository. Avoid making direct local changes.
- **Refer to Original Documentation:** For detailed information on how to *use* a specific vendored library (its API, features, limitations), consult the library's original documentation. The `knowledge.md` file within its vendor subdirectory might provide a brief overview and links.
- **Check Licensing:** Be aware of and comply with the software license terms of each library included in the `vendor` directory. License information should typically be included within the library's subdirectory (e.g., in a `LICENSE` or `COPYING` file).
