# tests/fixtures/modules Knowledge

## Purpose

The `tests/fixtures/modules/` directory is a dedicated location within the test fixtures area for storing simple, self-contained Lua modules used specifically for testing purposes within the Firmo framework. These modules typically serve as mock dependencies, predictable targets for framework features (like code coverage or module resetting), or provide basic functionality needed by certain test scenarios.

## Key Concepts

- **Mock/Helper Modules:** The primary role of modules in this directory is to act as controlled subjects or simple dependencies for tests. They are intentionally kept basic to make test behavior predictable and easy to understand. They might mimic parts of a real module's interface or simply provide executable code paths for testing tools like the coverage analyzer.
- **`test_math.lua`:** Currently, the main example fixture module in this directory is `test_math.lua`.
    - **Functionality:** It provides three basic arithmetic functions: `add(a, b)`, `subtract(a, b)`, and `multiply(a, b)`.
    - **Use Cases:** It serves as a straightforward target for tests verifying function calls, return values, code coverage line counting within simple functions, or testing the `lib/core/module_reset` system's ability to reload basic modules.

## Usage Examples / Patterns

### Requiring and Using `test_math.lua` in a Test

```lua
--[[
  Example demonstrating how to require and use the test_math.lua
  fixture module within a Firmo test.
]]
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Require the fixture module using its path relative to tests/
local test_math = require("tests.fixtures.modules.test_math")

describe("Test Math Fixture Module", function()
  it("should add two numbers correctly", function()
    expect(test_math.add(10, 5)).to.equal(15)
    expect(test_math.add(-1, 1)).to.equal(0)
  end)

  it("should subtract two numbers correctly", function()
    expect(test_math.subtract(10, 5)).to.equal(5)
  end)

  it("should multiply two numbers correctly", function()
    expect(test_math.multiply(10, 5)).to.equal(50)
  end)
end)
```

## Related Components / Modules

- **Fixture Module(s):**
    - `tests/fixtures/modules/test_math.lua`
- **Parent Directory:**
    - `tests/fixtures/knowledge.md` (Overview of all test fixtures)
- **Potential Consumers (Examples):**
    - `tests/core/module_reset_test.lua` (Might use simple modules like `test_math` to verify reset behavior).
    - `tests/coverage/coverage_test.lua` (Might use `test_math` as a simple target to check line hit counts).

## Best Practices / Critical Rules (Optional)

- **Simplicity:** Keep modules added to this directory as simple as possible, containing only the logic necessary for the specific testing purpose they serve.
- **Statelessness:** Prefer making these fixture modules stateless (i.e., not storing data between function calls) to simplify test isolation. If state is absolutely necessary, ensure tests are aware of it and handle potential resets.
- **Clear Naming:** Use descriptive filenames (like `test_math.lua`) that clearly indicate the module's purpose or the component it might be mocking.
- **Location:** Place only reusable Lua *modules* here. Other types of fixtures (like data files, error generators) belong in the parent `tests/fixtures/` directory or other appropriate subdirectories.

## Troubleshooting / Common Pitfalls (Optional)

- **`require` Errors:** If a test fails with `module 'tests.fixtures.modules....' not found`, verify the `require` path in the test file is correct relative to the `tests/` directory base.
- **Fixture Logic Errors:** Since these modules are simple, errors are less likely, but if tests using them fail unexpectedly, briefly review the logic within the fixture module itself (e.g., `test_math.lua`) to ensure it's performing the expected basic operation.
