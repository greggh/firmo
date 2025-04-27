--- module_reset_example.lua
--
-- This procedural example script demonstrates the problem of persistent module state
-- between simulated test runs and introduces Firmo's module reset feature as the
-- solution for ensuring test isolation.
--
-- It shows:
-- - A simple module with internal state (`counter`).
-- - How state changes persist across calls without reset.
-- - A *manual* reset implementation using `package.loaded` and `dofile` (for demo only).
-- - How to check for and potentially use Firmo's built-in `module_reset` functionality.
--
-- Run this example directly: lua examples/module_reset_example.lua
--

local firmo = require("firmo") -- Keep for context, though not used directly here
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem") -- Keep for context if needed, though replaced
local logging = require("lib.tools.logging")
local temp_file = require("lib.tools.filesystem.temp_file")

-- Setup logger
local logger = logging.get_logger("ModuleResetExample")

logger.info("firmo Module Reset Example")
logger.info("----------------------------")

-- Check if the enhanced module_reset is available
local module_reset_available = false
local reset_module_func -- Store the function if found
local success, mr = pcall(require, "lib.core.module_reset")
if success then
  module_reset_available = true
  reset_module_func = mr -- Assuming require returns the module table/functions
end

--- Creates a temporary Lua module file with the given content.
-- @param name string Base name for the temp file.
-- @param content string Lua code content for the module.
-- @return string file_path The absolute path to the created temporary file.
local function create_test_module(name, content)
  local file_path, err = temp_file.create_with_content(content, name .. ".lua")
  if not file_path then
    error("Failed to create test module: " .. (err and err.message or "unknown error"))
  end
  return file_path -- Return the absolute path
end

-- Forward declaration for the module instance
local module_a

-- Create test module A
local module_a_path = create_test_module(
  "a",
  [[
  local module_a = {}
  module_a.counter = 0
  module_a.name = "Module A"

  function module_a.increment()
    module_a.counter = module_a.counter + 1
    return module_a.counter
  end

  print("Module A loaded with counter = " .. module_a.counter)

  return module_a
]]
)

-- Load module_a using dofile (since it's not in the standard require path)
module_a = dofile(module_a_path)

--- Simulates running a test that interacts with `module_a`.
local function run_test_1()
  logger.info("\nRunning Test 1:")
  logger.info("  Initial counter value: " .. module_a.counter)
  logger.info("  Incrementing counter")
  module_a.increment()
  logger.info("  Counter after test: " .. module_a.counter)
end

--- Simulates running a second test that interacts with `module_a`.
local function run_test_2()
  logger.info("\nRunning Test 2:")
  logger.info("  Initial counter value: " .. module_a.counter)
  logger.info("  Incrementing counter twice")
  module_a.increment()
  module_a.increment()
  logger.info("  Counter after test: " .. module_a.counter)
end

--- Simulates resetting `module_a` by clearing `package.loaded` and reloading via `dofile`.
-- @note This manual approach using `package.loaded` and `dofile` is for demonstration
--       purposes ONLY to illustrate the concept. Real tests should use Firmo's
--       built-in module reset capabilities provided by `lib.core.module_reset`
--       (if available) or test runner features, and avoid direct `package.loaded` manipulation.
-- @param module_path string The absolute path to the module file to reload.
-- @return table The reloaded module instance.
local function reset_modules(module_path)
  logger.info("\nResetting modules (manual demo)...")

  -- Basic reset method - remove from package.loaded and reload via dofile
  -- This requires knowing the *original* path used by require/dofile if it differs.
  -- NOTE: This is simplified; real module reset needs to handle complex dependencies.
  package.loaded[module_path] = nil -- Attempt to clear cache entry by path
  collectgarbage("collect")

  -- Reload module using dofile
  logger.info("Reloading module from: " .. module_path)
  return dofile(module_path)
end

-- Run test demo
logger.info("\n== Demo: Running Tests Without Module Reset ==")
logger.info("This demonstrates how state persists between tests when not using module reset.")

run_test_1() -- Should start with counter = 0
run_test_2() -- Will start with counter = 1 from previous test

logger.info("\n== Demo: Running Tests With Module Reset ==")
logger.info("This demonstrates how module reset ensures each test starts with fresh state.")

-- Manually reset the loaded module_a before running Test 1 again
module_a = reset_modules(module_a_path)
run_test_1() -- Should start with counter = 0

module_a = reset_modules(module_a_path) -- Reset again before Test 2
run_test_2() -- Should also start with counter = 0 due to reset

-- Information about the enhanced module reset system
logger.info("\n== Enhanced Module Reset System ==")
if module_reset_available then
  logger.info("The enhanced module reset system is available in firmo.")
  logger.info("This provides automatic module reset between test files when using the test runner.")
  logger.info("\nTo use it in your test runner:")
  logger.info("1. Require the module: local module_reset = require('lib.core.module_reset')")
  logger.info("2. Register with firmo: module_reset.register_with_firmo(firmo)")
  logger.info("3. Configure options: module_reset.configure({ reset_modules = true })")
  logger.info("\nThe standard test runner (`test.lua`) typically handles this automatically.")
  -- Example using the function if available (optional demonstration)
  -- if reset_module_func and reset_module_func.reset then
  --   logger.info("Demonstrating enhanced reset (if available)...")
  --   reset_module_func.reset({module_a_path}) -- Pass path or module name
  --   logger.info("Enhanced reset complete.")
  -- end
else
  logger.info("The enhanced module reset system ('lib.core.module_reset') was not found.")
  logger.info("The demonstration above used a simplified manual method for module reset.")
end

-- Cleanup is handled by temp_file.cleanup_all()

-- Clean up all temporary files created by temp_file
temp_file.cleanup_all()
