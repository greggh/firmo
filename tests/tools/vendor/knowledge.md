# tests/tools/vendor Knowledge

## Purpose

The `tests/tools/vendor/` directory is designated for containing automated tests that validate the third-party libraries included ("vendored") within the `lib/tools/vendor/` directory of the Firmo framework. The primary goal of these tests is to ensure that these external dependencies can be correctly loaded (including any build steps or fallbacks) and that their core functionality, particularly the aspects directly utilized by Firmo, operates as expected within the Firmo environment.

## Key Concepts

- **Testing Vendored Libraries:** The focus here is generally *not* on exhaustive testing of the third-party library itself (which is assumed to be covered by the library's own upstream tests). Instead, tests in this directory typically concentrate on:
    - **Load Verification:** Ensuring `require("lib.tools.vendor.<library>")` succeeds, correctly handling any C module compilation, loading, or fallback logic implemented in the vendor library's `init.lua`.
    - **Basic Functionality / Integration:** Verifying that a few essential functions or features of the library, which are known to be used by other Firmo modules, are present and return expected results for simple cases. This acts as a basic integration check and guards against major regressions introduced during vendor library updates.
    - **Version Compatibility:** Implicitly verifies that the specific vendored version of the library is compatible with the Lua version and environment used by Firmo.

- **`lpeglabel_test.lua`:** This is currently the main test file in this directory. Its scope includes:
    - Testing the successful loading of the `lpeglabel` library via `require("lib.tools.vendor.lpeglabel")`. This implicitly tests the complex loading logic in `lpeglabel/init.lua` which attempts to load/build the C module and resorts to a limited Lua fallback if necessary.
    - Verifying the presence of core LPeg functions (like `lpeglabel.P`, `lpeglabel.match`) and LPegLabel-specific additions (like `lpeglabel.T`) in the loaded module table.
    - Executing very basic LPeg pattern matching operations to confirm minimal functionality, especially if the C module is loaded, as `lib/tools/parser` depends heavily on this. It might include checks for `lpeglabel.is_fallback` to adjust expectations.

## Usage Examples / Patterns (Illustrative Test Snippets from `lpeglabel_test.lua`)

### Testing LPegLabel Loading and Basic Usage

```lua
--[[
  Conceptual test verifying lpeglabel loading and basic pattern matching.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Vendored Library: LPegLabel", function()
  local lpeglabel -- To store loaded module
  local load_error -- To store any error during require

  before_all(function()
    -- Use pcall to safely attempt loading, capturing potential errors
    local ok
    ok, lpeglabel = pcall(require, "lib.tools.vendor.lpeglabel")
    if not ok then
      load_error = lpeglabel -- Store the error message if require failed
      lpeglabel = nil -- Ensure lpeglabel is nil on failure
      print("CRITICAL ERROR loading lpeglabel:", load_error)
    elseif lpeglabel.is_fallback then
      print("WARNING: LPegLabel tests are running against the limited fallback implementation!")
    end
  end)

  it("should load successfully", function()
    expect(load_error).to_not.exist("Loading lpeglabel should not produce an error")
    expect(lpeglabel).to.be.a("table", "Loaded module should be a table")
  end)

  it("should provide core LPeg and LPegLabel functions", function()
    if load_error then firmo.pending("Skipped due to load error") end -- Skip if load failed
    expect(lpeglabel.P).to.be.a("function", "LPeg 'P' should exist")
    expect(lpeglabel.match).to.be.a("function", "LPeg 'match' should exist")
    expect(lpeglabel.T).to.be.a("function", "LPegLabel 'T' should exist") -- Specific to LPegLabel
  end)

  it("should perform basic pattern matching (if not fallback)", function()
    if load_error then firmo.pending("Skipped due to load error") end
    if lpeglabel.is_fallback then
      firmo.pending("Skipping complex pattern test in fallback mode")
    end

    -- Test only if C module loaded successfully
    local pattern = lpeglabel.P("test") + 1 -- Match "test" exactly
    expect(lpeglabel.match(pattern, "test")).to.equal(5) -- Returns end position + 1
    expect(lpeglabel.match(pattern, "testing")).to_not.exist()
  end)
end)
```

## Related Components / Modules

- **Library Being Tested:** `lib/tools/vendor/lpeglabel/knowledge.md`
- **Test File:** `tests/tools/vendor/lpeglabel_test.lua`
- **Parent Vendor Directory:** `lib/tools/vendor/knowledge.md` (Provides overview and vendoring policy)
- **Parent Test Directory:** `tests/tools/knowledge.md` (Overview of tool tests)
- **Primary Consumer:** `lib/tools/parser/knowledge.md` (The Lua parser heavily relies on `lpeglabel`)

## Best Practices / Critical Rules (Optional)

- **Focus on Loading and Basic Integration:** Keep tests for vendored libraries primarily focused on ensuring they load correctly (including build/fallback steps) and that the core functions used by Firmo are present and minimally functional.
- **Avoid Duplicating Upstream Tests:** Do not attempt to replicate the comprehensive test suite of the original third-party library. Rely on upstream testing for core correctness.
- **Test the Fallback (If Applicable):** For libraries like `lpeglabel` with a fallback mechanism, include tests that explicitly check the `is_fallback` flag and verify the expected (limited) behavior when the fallback is active.
- **Update Tests on Vendor Upgrade:** When updating the version of a library in the `vendor` directory, ensure the corresponding tests in `tests/tools/vendor` are run and pass. Update the tests if necessary to reflect any API changes relevant to Firmo's usage.

## Troubleshooting / Common Pitfalls (Optional)

- **Loading Errors (`require` fails):**
    - **Cause:** Often related to the C module component of the vendored library. Could be build failures (missing compiler/make, errors in C code), architecture mismatches (32-bit vs 64-bit), or missing runtime dependencies for the compiled library.
    - **Debugging:** Check the specific error message from `require`. For `lpeglabel`, examine `lib/tools/vendor/lpeglabel/build.log` for compilation errors. Refer to the troubleshooting section in the specific library's knowledge file (e.g., `lib/tools/vendor/lpeglabel/knowledge.md`).
- **Basic Functionality Test Failures:**
    - **Cause:** Could indicate a regression in the specific version of the vendored library or an incompatibility introduced with Firmo's Lua version or environment. It might also occur if the limited fallback version was loaded unexpectedly (see below).
    - **Debugging:** Verify the test logic is correct. Compare behavior with previous versions of the vendored library if possible. Consult the library's original documentation.
- **Tests Failing Due to Fallback Mode:**
    - **Cause:** The C module failed to load/build, and the test is attempting to use functionality not available in the limited Lua fallback.
    - **Debugging:** Check logs for the "Using fallback implementation" warning. Address the C module loading/building issues first. Modify tests to check `library.is_fallback` and skip or adjust assertions for features unavailable in the fallback.
