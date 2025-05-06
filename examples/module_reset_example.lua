--- This procedural example script demonstrates the problem of persistent module state
--- between simulated test runs and introduces Firmo's module reset feature as the
-- solution for ensuring test isolation.
--
-- It shows:
-- - A simple module with internal state (`counter`).
-- - How state changes persist across calls without reset.
-- - A *manual* reset implementation using `package.loaded` and `dofile` (for demo only).
-- - How to check for and potentially use Firmo's built-in `module_reset` functionality.
--
-- @module examples.module_reset_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see lib.core.module_reset
-- @usage
-- Run this example directly: lua examples/module_reset_example.lua
--

local logging = require("lib.tools.logging")
local temp_file = require("lib.tools.filesystem.temp_file")
local fs = require("lib.tools.filesystem") -- Added missing require

-- Setup logger
local logger = logging.get_logger("ModuleResetExample")

print("--- Firmo Module Reset Example ---") -- Use print for direct execution clarity
print("----------------------------------")

-- Check if the enhanced module_reset system is available
local module_reset_available = false
local module_reset_module -- Store the loaded module if found
local load_ok, loaded_module = pcall(require, "lib.core.module_reset")
if load_ok then
  module_reset_available = true
  module_reset_module = loaded_module
  print("Found Firmo's module_reset system (lib.core.module_reset).")
else
  print("Firmo's module_reset system (lib.core.module_reset) not found. Manual demo will proceed.")
end

--- Creates a temporary Lua module file with the given content.
--- Registers the file with `temp_file` for automatic cleanup.
--- @param name string Base name for the temp file (e.g., "module_a").
--- @param content string Lua code content for the module.
--- @return string|nil file_path The absolute path to the created temporary file, or `nil` on error.
--- @within examples.module_reset_example
local function create_test_module(name, content)
  local file_path, err = temp_file.create_with_content(content, name .. ".lua")
  if not file_path then
    print("ERROR: Failed to create test module '" .. name .. "': " .. tostring(err or "unknown error"))
    return nil
  end
  return file_path
end

-- Forward declaration for the module instance
local module_a -- Will hold the loaded module instance
local module_a_path -- Holds the path to the temporary module file

-- Create test module A file content
local module_a_content = [[
-- Temporary module 'module_a' for reset demonstration

local M = {}
M.counter = 0 -- State variable
M.name = "Module A"

function M.increment()
  M.counter = M.counter + 1
  return M.counter
end

print("[Module A] Loaded/Re-loaded. Initial Counter:", M.counter)

return M
]]

-- Create the temporary file
module_a_path = create_test_module("module_a", module_a_content)
if not module_a_path then
  return
end -- Exit if creation failed

-- Load module_a for the first time using dofile (since it's not in a package path)
-- dofile executes the file and returns its result
print("\nLoading module_a for the first time...")
module_a = dofile(module_a_path)
if not module_a then
  error("Failed to load module_a via dofile")
end

--- Simulates running a test that interacts with the loaded `module_a`.
--- @within examples.module_reset_example
local function run_test_1()
  print("\n--- Running Test 1 ---")
  print("  Initial counter value:", module_a.counter)
  print("  Incrementing counter...")
  module_a.increment()
  print("  Counter after Test 1:", module_a.counter)
end

--- Simulates running a second test that interacts with the loaded `module_a`.
--- @within examples.module_reset_example
local function run_test_2()
  print("\n--- Running Test 2 ---")
  print("  Initial counter value:", module_a.counter)
  print("  Incrementing counter twice...")
  module_a.increment()
  module_a.increment()
  print("  Counter after Test 2:", module_a.counter)
end

--- Simulates manually resetting `module_a` by clearing `package.loaded` and reloading via `dofile`.
--- @warning **DEMONSTRATION ONLY!** This manual approach is fragile and incomplete.
--- Real test environments should use the test runner's built-in isolation, which leverages
--- `lib.core.module_reset` for reliable state clearing between test files.
--- Do **NOT** replicate this manual `package.loaded` manipulation in production tests.
--- @param module_path string The absolute path to the module file to reload.
--- @return table|nil The reloaded module instance, or `nil` on error.
--- @within examples.module_reset_example
local function manual_reset_demonstration(module_path)
  print("\nAttempting Manual Reset (DEMO ONLY)...")

  -- Basic reset method - remove from package.loaded and reload via dofile.
  -- NOTE: This only works reliably for simple, self-contained modules loaded via
  -- an absolute path with `dofile`. It doesn't handle `require`, relative paths,
  -- or complex dependencies correctly. Use Firmo's built-in reset instead.
  package.loaded[module_path] = nil
  collectgarbage("collect")

  -- Reload module using dofile
  print("Reloading module from:", module_path)
  local ok, reloaded_module_or_err = pcall(dofile, module_path)
  if not ok then
    print("ERROR during manual reload:", reloaded_module_or_err)
    return nil
  end
  return reloaded_module_or_err
end

-- Run test demo
print("\n== Demo: Running Tests WITHOUT Module Reset ==")
print("Observe how the counter state persists across tests.")

run_test_1() -- Starts at 0, ends at 1
run_test_2() -- Starts at 1, ends at 3

print("\n== Demo: Running Tests WITH Manual Module Reset (DEMO ONLY) ==")
print("Observe how the counter is reset before each test.")
print("**WARNING: This manual reset is for illustration only. Use Firmo's built-in reset.**")

-- Manually reset the loaded module_a before running Test 1 again
module_a = manual_reset_demonstration(module_a_path)
if not module_a then
  return
end -- Stop if reset failed
run_test_1() -- Should start at 0, end at 1

-- Manually reset again before Test 2
module_a = manual_reset_demonstration(module_a_path)
if not module_a then
  return
end -- Stop if reset failed
run_test_2() -- Should also start at 0, end at 2

-- Information about the proper module reset system
print("\n== Firmo's Built-in Module Reset System ==")
if module_reset_available then
  print("The built-in module reset system (`lib.core.module_reset`) IS available.")
  print("It provides automatic module state reset between test *files* when using the test runner (`test.lua`).")
  print("It handles complex dependencies and `require` correctly.")
  print("\nUsage (typically handled by the runner automatically):")
  print("1. `local module_reset = require('lib.core.module_reset')`")
  print("2. `module_reset.register_with_firmo(firmo)`")
  print("3. `module_reset.configure({ reset_modules = true })`")
  print("4. The runner calls `firmo.reset()` between files, triggering `module_reset.reset_all()`.")
else
  print("The built-in module reset system (`lib.core.module_reset`) was NOT found.")
  print("The demonstration above used a simplified *manual* method which should NOT be used in real tests.")
end

print("\n--- Module Reset Example Complete ---")

-- Cleanup is handled automatically by temp_file registration
print("Temporary files will be cleaned up automatically.")
