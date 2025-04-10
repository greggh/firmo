#!/usr/bin/env lua
-- Simple redirector to scripts/runner.lua
-- This file provides a convenient entry point for running tests

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