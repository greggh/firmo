# lib/tools/vendor/lpeglabel Knowledge

## Purpose

This document describes the vendored **LPegLabel** library located in `lib/tools/vendor/lpeglabel`. LPegLabel is an extension of the standard LPeg library (Parsing Expression Grammars for Lua). Its primary enhancement is the addition of "labeled failures," allowing grammar rules to associate specific labels with failure points. These labels can then be mapped to informative error messages, greatly improving the quality of error reporting when parsing fails.

Within the Firmo framework, LPegLabel is a **critical dependency** for the Lua parser module (`lib/tools/parser`), which uses it to define and execute the grammar for parsing Lua source code into an Abstract Syntax Tree (AST).

## Key Concepts

- **Loading Mechanism (`init.lua`):** Firmo attempts to load LPegLabel using a prioritized strategy defined in `init.lua`:
    1.  **Check for Pre-compiled:** It first checks if a pre-compiled native C library file exists (`lpeglabel.so` on Linux/macOS, `lpeglabel.dll` on Windows).
    2.  **Load C Library:** If found, it attempts to load this C library using `package.loadlib`. This provides the full, intended functionality and performance.
    3.  **Attempt Build:** If the C library is missing or fails to load, `init.lua` attempts to compile the included C source code (`*.c`, `*.h`) using the provided `makefile`. This requires a suitable C compiler (GCC, Clang) and `make` (or `mingw32-make` on Windows) to be present in the system's PATH. Build progress and errors are logged to `lib/tools/vendor/lpeglabel/build.log`.
    4.  **Load Newly Built Library:** If the build is successful, it tries again to load the newly created C library file.
    5.  **Lua Fallback:** If all attempts to load or build the C library fail, `init.lua` logs a warning and loads a pure Lua fallback implementation (`fallback.lua`).

- **Build Process (`makefile`):** The automatic build step relies on the `makefile` included in this directory. It contains targets for `linux`, `macosx`, and `windows`. The `init.lua` script selects the appropriate target based on the detected platform and executes `make <platform>` or `mingw32-make windows`.

- **Lua Fallback Limitations (`fallback.lua`):** **CRITICAL:** The pure Lua fallback implementation (`fallback.lua`) is **severely limited** and primarily exists to prevent `require` errors when the C module isn't available.
    - It provides placeholder functions for most of the LPeg/LPegLabel API.
    - Its `match` function only supports extremely basic literal string matching and **cannot handle complex grammars**.
    - Features like labeled failures (`T` pattern), advanced captures (table, position, back references, etc.), and grammar variables (`V`) are **not functionally implemented** in the fallback.
    - **Consequence:** If Firmo ends up using the fallback, the Lua parser (`lib/tools/parser`) will almost certainly fail to parse any non-trivial Lua code correctly, leading to failures in features that depend on it (like code coverage). A warning message "Using fallback implementation..." is printed if this occurs.

- **Labeled Failures (`T` Pattern):** The main feature added by LPegLabel (in its C implementation) is the `T(label)` pattern constructor. When used in a grammar, if matching fails at this point, the `label` is captured. The `setlabels({ label = "Error message" })` function can then be used to associate these labels with user-friendly error messages, allowing the parser to report *why* parsing failed, not just where. This is used by `lib/tools/parser/grammar.lua`.

## Usage Examples / Patterns

### Requiring LPegLabel (Typical Usage by Parser)

```lua
--[[
  This shows how the library is typically required.
  The complex loading/building/fallback logic is handled internally by init.lua.
  Users of the parser generally don't need to do this directly.
]]
local lpeglabel, load_err = pcall(require, "lib.tools.vendor.lpeglabel")

if not lpeglabel then
  print("FATAL: Could not load LPegLabel (C or fallback): " .. tostring(load_err))
  -- Abort or handle critical failure
elseif lpeglabel.is_fallback then
  print("WARNING: Using limited LPegLabel fallback. Parsing functionality will be severely impaired.")
end

-- If loaded successfully (ideally the C version), the parser can use it:
-- local P, V, T = lpeglabel.P, lpeglabel.V, lpeglabel.T
-- local grammar = P{ ... using P, V, T ... }
-- local ast = lpeglabel.match(grammar, source_code)

-- Note: For detailed examples of how to USE LPegLabel patterns (P, V, C, T etc.),
-- please refer to the official LPeg and LPegLabel documentation linked below.
```

## Related Components / Modules

- **Source Files:**
    - `lib/tools/vendor/lpeglabel/init.lua`: Loader script with build logic and fallback mechanism.
    - `lib/tools/vendor/lpeglabel/fallback.lua`: Limited pure Lua fallback implementation.
    - `lib/tools/vendor/lpeglabel/lpeglabel.c` (et al.): Core C source code for the library.
    - `lib/tools/vendor/lpeglabel/makefile`: Build instructions for `make`.
- **Firmo Modules:**
    - `lib/tools/vendor/knowledge.md`: Overview of the parent vendor directory.
    - **`lib/tools/parser/knowledge.md`**: The primary consumer of this library within Firmo. It relies heavily on LPegLabel (ideally the C version) to function correctly.
- **External Documentation:**
    - **LPegLabel Repository:** [https://github.com/sqmedeiros/lpeglabel](https://github.com/sqmedeiros/lpeglabel) (Original source and basic documentation)
    - **LPeg Documentation:** [http://www.inf.puc-rio.br/~roberto/lpeg/](http://www.inf.puc-rio.br/~roberto/lpeg/) (Essential reference for understanding the base LPeg patterns and concepts upon which LPegLabel builds)

## Best Practices / Critical Rules (Optional)

- **Do Not Modify:** As with all vendored code, **do not modify** the files within `lib/tools/vendor/lpeglabel` directly. Report issues or contribute fixes upstream.
- **Check for Fallback (If Necessary):** If a Firmo feature relies heavily on correct parsing (e.g., complex static analysis), it might defensively check `require("lib.tools.vendor.lpeglabel").is_fallback` and warn the user or disable the feature if only the limited fallback is available.
- **Refer to External Docs for Usage:** This knowledge file explains how LPegLabel is integrated and loaded within Firmo. For details on how to *write* LPeg or LPegLabel grammars and patterns, consult the official LPeg and LPegLabel documentation linked above.

## Troubleshooting / Common Pitfalls (Optional)

- **Build Fails During `require`:**
    - **Symptom:** An error message occurs when `require("lib.tools.vendor.lpeglabel")` is first called, indicating a build failure.
    - **Cause:** The system likely lacks the necessary tools to compile the C code (a C compiler like GCC or Clang, and the `make` utility, or `mingw32-make` on Windows).
    - **Debugging:** Examine the contents of `lib/tools/vendor/lpeglabel/build.log`. It should contain the output from the `make` command, including specific compiler errors (e.g., missing headers, syntax errors, linker issues).
    - **Solution:** Install the required build tools (e.g., `build-essential` on Debian/Ubuntu, Xcode Command Line Tools on macOS, MinGW/MSYS2 on Windows) and try running Firmo again.
- **Loading Fails During `require` (even if `lpeglabel.so`/`.dll` exists):**
    - **Symptom:** An error occurs during `require`, potentially mentioning `package.loadlib` or shared library issues.
    - **Cause 1:** Architecture mismatch. The pre-compiled `.so`/`.dll` might be for a different architecture (e.g., 32-bit vs 64-bit) than the Lua interpreter being used.
    - **Cause 2:** Missing runtime dependencies. The compiled C library might depend on other system libraries that are not installed.
    - **Debugging:** The error message from `pcall(require, ...)` might contain clues. Verify Lua interpreter architecture matches the library. Try manually deleting the `.so`/`.dll` file and the `*.o` files and let Firmo attempt to rebuild it on the next run.
- **Parser Module Fails / Incorrect Results:**
    - **Symptom:** The `lib/tools/parser` module reports errors even on valid Lua code, or features relying on it (like coverage) behave incorrectly.
    - **Cause:** The limited Lua fallback (`fallback.lua`) was loaded instead of the functional C module. The fallback cannot correctly parse complex Lua grammars.
    - **Debugging:** Check the application's startup logs for the warning message: "Using fallback implementation with limited functionality".
    - **Solution:** Address the underlying reason why the C module failed to load or build (see points above). Ensure a working C compiler and `make` are available.
