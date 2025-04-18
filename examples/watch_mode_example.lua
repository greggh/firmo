-- Example of using watch mode in firmo
-- Run with: lua scripts/run_tests.lua --watch examples/watch_mode_example.lua

-- Load firmo
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Create a simple test suite
describe("Watch Mode Example", function()
  
  -- Simple passing test
  it("should pass a simple test", function()
    expect(1 + 1).to.equal(2)
  end)
  
  -- Another passing test
  it("should handle string operations", function()
    expect("hello").to.match("^h")
    expect("hello").to.contain("ell")
    expect(#"hello").to.equal(5)
  end)
  
  -- Test that will fail (uncomment to see watch mode detect failures)
  -- it("should fail when uncommented", function()
  --   expect(true).to.be(false)
  -- end)
  
  describe("Nested tests", function()
    it("should support nesting", function()
      expect(true).to.be(true)
    end)
    
    it("should handle tables", function()
      local t = {a = 1, b = 2}
      expect(t.a).to.equal(1)
      expect(t.b).to.equal(2)
      expect(t).to.have_field("a")
    end)
  end)
end)

-- If running this file directly, show usage instructions
if arg[0]:match("watch_mode_example%.lua$") then
  firmo.log.info({ message = "Watch Mode Example" })
  firmo.log.info({ message = "=================" })
  firmo.log.info({ message = "This file demonstrates the watch mode functionality for continuous testing." })
  firmo.log.info({ message = "" })
  firmo.log.info({ message = "To run with watch mode, use:" })
  firmo.log.info({ message = "  lua scripts/run_tests.lua --watch examples/watch_mode_example.lua" })
  firmo.log.info({ message = "" })
  firmo.log.info({ message = "Watch mode will:" })
  firmo.log.info({ message = "1. Run the tests in this file" })
  firmo.log.info({ message = "2. Watch for changes to any files" })
  firmo.log.info({ message = "3. Automatically re-run tests when changes are detected" })
  firmo.log.info({ message = "4. Continue until you press Ctrl+C" })
  firmo.log.info({ message = "" })
  firmo.log.info({ message = "Try editing this file while watch mode is running to see the tests automatically re-run." })
  firmo.log.info({ message = "" })
  firmo.log.info({ message = "Tips:" })
  firmo.log.info({ message = "- Uncomment the 'failing test' sections to see failure detection" })
  firmo.log.info({ message = "- Add new tests to see them get picked up automatically" })
  firmo.log.info({ message = "- Try changing test assertions to see how the system responds" })
end

-- Note: Tests are run by scripts/runner.lua or run_all_tests.lua, not by explicit call
