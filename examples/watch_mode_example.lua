--- Example demonstrating Firmo's watch mode for continuous testing.
---
--- This file contains a simple test suite designed to be run with the
--- `--watch` flag of the Firmo test runner (`test.lua`). Watch mode detects
--- file changes and automatically re-runs the relevant tests.
---
--- @module examples.watch_mode_example
--- @see docs/guides/cli.md (for runner flags)
--- @usage
--- Run tests in watch mode:
--- ```bash
--- lua test.lua --watch examples/watch_mode_example.lua
--- ```
--- Or watch a directory:
--- ```bash
--- lua test.lua --watch examples/
--- ```
--- Then, modify and save this file (or others being watched) to see tests re-run.

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

--- Simple test suite for demonstrating watch mode.
--- @within examples.watch_mode_example
describe("Watch Mode Example", function()
  --- A simple passing test.
  it("should pass a simple test", function()
    firmo.log.info("Running 'should pass a simple test'")
    expect(1 + 1).to.equal(2)
  end)

  --- Another simple passing test.
  it("should handle string operations", function()
    firmo.log.info("Running 'should handle string operations'")
    expect("hello").to.match("^h")
    expect("hello").to.contain("ell")
    expect(#"hello").to.equal(5)
  end)

  -- Test that will fail (uncomment this block to see watch mode detect failures)
  --[[
  it("should fail when uncommented", function()
    firmo.log.info("Running 'should fail when uncommented'")
    expect(true).to.be(false)
  end)
  --]]

  --- Nested test suite.
  --- @within examples.watch_mode_example
  describe("Nested tests", function()
    --- Simple test within a nested suite.
    it("should support nesting", function()
      firmo.log.info("Running nested test 'should support nesting'")
      expect(true).to.be(true)
    end)

    --- Another nested test.
    it("should handle tables", function()
      local t = { a = 1, b = 2 }
      expect(t.a).to.equal(1)
      expect(t.b).to.equal(2)
      expect(t).to.have_field("a")
    end)
  end)
end)

-- If running this file directly (not via test runner), print usage instructions
-- Note: Using print as logger might not be initialized when run directly.
if arg and arg[0] and arg[0]:match("watch_mode_example%.lua$") then
  print("\n--- Watch Mode Example ---")
  print("========================")
  print("This file demonstrates the watch mode functionality for continuous testing.")
  firmo.log.info({ message = "" })
  firmo.log.info({ message = "To run with watch mode, use:" })
  print("\nTo run with watch mode, use:")
  print("  lua test.lua --watch examples/watch_mode_example.lua")
  print("Or watch the whole directory:")
  print("  lua test.lua --watch examples/")
  print("\nWatch mode will:")
  print("1. Run the initial tests.")
  print("2. Watch for changes to Lua files.")
  print("3. Automatically re-run tests when changes are detected.")
  print("4. Continue until you press Ctrl+C.")
  print("\nTry editing this file (e.g., uncomment the failing test) while watch mode is running.")
end

-- Note: Actual test execution is handled by the test runner (`test.lua`), not this file directly.
