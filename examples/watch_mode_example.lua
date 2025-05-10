--- Example demonstrating Firmo's watch mode for continuous testing.
---
--- This file contains a simple test suite designed to be run with the
--- `--watch` flag of the Firmo test runner (`test.lua`). Watch mode detects
--- file changes and automatically re-runs the relevant tests.
---
--- @module examples.watch_mode_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see docs/guides/cli.md (for runner flags)
--- @usage
--- Run tests in watch mode:
--- ```bash
--- lua firmo.lua --watch examples/watch_mode_example.lua
--- ```
--- Or watch a directory:
--- ```bash
--- lua firmo.lua --watch examples/
--- ```
--- Then, modify and save this file (or others being watched) to see tests re-run.

-- Extract the testing functions we need
local firmo = require("firmo")
local logging = require("lib.tools.logging") -- Added missing require

-- Setup logger
local logger = logging.get_logger("WatchModeExample")

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
    logger.info("Running 'should pass a simple test'")
    expect(1 + 1).to.equal(2)
  end)

  --- Another simple passing test.
  it("should handle string operations", function()
    logger.info("Running 'should handle string operations'")
    expect("hello").to.match("^h")
    expect("hello").to.contain("ell")
    expect(#"hello").to.equal(5)
  end)

  -- Test that will fail (uncomment this block to see watch mode detect failures)
  --[[
  it("should fail when uncommented", function()
    logger.info("Running 'should fail when uncommented'")
    expect(true).to.be(false)
  end)
  --]]

  --- Nested test suite.
  --- @within examples.watch_mode_example
  describe("Nested tests", function()
    --- Simple test within a nested suite.
    it("should support nesting", function()
      logger.info("Running nested test 'should support nesting'")
      expect(true).to.be(true)
    end)

    --- Another nested test.
    it("should handle tables", function()
      local t = { a = 1, b = 2 }
      expect(t.a).to.equal(1)
      expect(t.b).to.equal(2)
      expect(t).to.have_property("a")
    end)
  end)
end)

-- If running this file directly (not via test runner), print usage instructions
-- Note: Using logger, which should be available if run via test.lua
if arg and arg[0] and arg[0]:match("watch_mode_example%.lua$") then
  logger.info("\n--- Watch Mode Example ---")
  logger.info("========================")
  logger.info("This file demonstrates the watch mode functionality for continuous testing.")
  logger.info("")
  logger.info("To run with watch mode, use:")
  logger.info("  lua firmo.lua --watch examples/watch_mode_example.lua")
  logger.info("Or watch the whole directory:")
  logger.info("  lua firmo.lua --watch examples/")
  logger.info("\nWatch mode will:")
  logger.info("1. Run the initial tests.")
  logger.info("2. Watch for changes to Lua files.")
  logger.info("3. Automatically re-run tests when changes are detected.")
  logger.info("4. Continue until you press Ctrl+C.")
  logger.info("\nTry editing this file (e.g., uncomment the failing test) while watch mode is running.")
end

-- Note: Actual test execution is handled by the test runner (`test.lua`), not this file directly.
