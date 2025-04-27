--- Firmo Test Runner Entry Point
---
--- This script acts as a simple redirector to the main test runner script located
--- at `scripts/runner.lua`. Its primary purpose is to provide a convenient and
--- consistent way to execute tests from the project's root directory using `lua test.lua ...`.
---
--- It validates that it's being run directly (not required as a module) and forwards
--- all command-line arguments to the actual runner, ensuring proper quoting for
--- arguments containing spaces. The script exits with the same status code as the
--- underlying runner.
---
--- @script test.lua
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

-- Check if we're running directly
if not arg or not arg[0]:match("test%.lua$") then
  error("This script must be run directly, not required.")
end

-- Forward all arguments to the proper runner
local args = {}
for i = 1, #arg do
  -- Quote arguments that have spaces
  if arg[i]:find(" ") then
    table.insert(args, '"' .. arg[i] .. '"')
  else
    table.insert(args, arg[i])
  end
end
local cmd = "lua scripts/runner.lua " .. table.concat(args, " ")
local success = os.execute(cmd)

-- Exit with the same status code
os.exit(success and 0 or 1)