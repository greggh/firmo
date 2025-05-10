--- Example demonstrating Firmo's interactive test runner mode.
---
--- This file contains a simple test suite designed to be run with the
--- `--interactive` flag of the Firmo test runner (`test.lua`). It allows
--- users to experiment with interactive commands like filtering tests by tags,
--- focusing specific tests, re-running tests, and using watch mode within
--- the interactive session.
---
--- @note The interactive mode itself (`lib/tools/interactive`) is partially implemented.
--- This example primarily serves to provide a target test file for using the
--- `--interactive` runner flag.
---
--- @module examples.interactive_mode_example
--- @see lib.tools.interactive (Partially implemented)
--- @see docs/guides/cli.md (For runner flags)
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @usage
--- Start the interactive runner with this file:
--- ```bash
--- lua firmo.lua --interactive examples/interactive_mode_example.lua
--- ```
--- Inside the interactive prompt, try commands like:
--- - `run` or `r` (run all tests)
--- - `tags basic` (run tests tagged 'basic')
--- - `focus "should pass"` (run only the test matching "should pass")
--- - `watch` or `w` (enter watch mode within the interactive session)
--- - `help` or `h` (show available commands)
--- - `quit` or `q` (exit the interactive runner)

-- local interactive = require("lib.tools.interactive") -- Not directly used in the example tests
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("InteractiveExample")

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after
---@diagnostic disable: undefined-global -- tags/focus might be injected
local tags, focus = firmo.tags, firmo.focus

-- Define a simple set of tests
--- Example test suite for demonstrating interactive mode features.
--- @within examples.interactive_mode_example
describe("Example Tests for Interactive Mode", function()
  --- Runs before each test case in this suite.
  before(function()
    -- Setup code runs before each test
    logger.debug("Setting up test environment...")
  end)

  --- Runs after each test case in this suite.
  after(function()
    -- Cleanup code runs after each test
    logger.debug("Cleaning up test environment...")
  end)

  --- A simple passing test case.
  --- @tags basic demo
  it("should pass a simple test", function()
    tags("basic", "demo") -- Add multiple tags
    expect(2 + 2).to.equal(4)
  end)

  --- A test case tagged with 'basic'. Use `tags basic` in interactive mode to run only this.
  --- @tags basic
  it("can be tagged with 'basic'", function()
    tags("basic") -- Apply the tag
    expect(true).to.be_truthy()
  end)

  --- A test case tagged with 'advanced'. Use `tags advanced` in interactive mode.
  --- @tags advanced
  it("can be tagged with 'advanced'", function()
    tags("advanced") -- Apply the tag
    expect(false).to_not.be_truthy()
  end)

  --- Demonstrates various basic assertions.
  --- @tags assertions demo
  it("demonstrates basic expect assertions", function()
    tags("assertions", "demo")
    expect(5).to.be.a("number")
    expect("test").to_not.be.a("number")
    expect(true).to.be_truthy()
    expect(false).to_not.be_truthy()
  end)

  --- Example of a nested test suite.
  --- @within examples.interactive_mode_example
  describe("Nested test group", function()
    --- A test within a nested group. Use `focus "support focused"` in interactive mode to run only this.
    --- @focus Use `focus 'support focused'` to run this.
    it("should support focused tests", function()
      logger.info("Running nested test 'should support focused tests'...")
      expect(4 * 4).to.equal(16)
    end)

    --- Demonstrates basic mocking within a test.
    --- @tags mocking demo
    it("demonstrates mocking (basic)", function()
      tags("mocking", "demo")

      -- Create a simple function to spy on
      local original_func = function(x)
        return x * 2
      end

      -- Use a spy to track calls without replacing functionality
      local spy_func = firmo.spy(original_func)

      -- Call the spied function
      local result1 = spy_func(10)
      local result2 = spy_func(20)

      -- Verify original function still works
      expect(result1).to.equal(20)
      expect(result2).to.equal(40)

      -- Verify calls were tracked
      expect(spy_func.call_count).to.equal(2)
      expect(spy_func:called_with(10)).to.be_truthy()
      expect(spy_func:called_with(20)).to.be_truthy()
    end)
  end)
end)

-- Log usage instructions if run directly
if arg and arg[0] and arg[0]:match("interactive_mode_example%.lua$") then
  logger.info("This file contains tests designed to be run using Firmo's interactive mode.")
  logger.info("Run with:")
  logger.info("  lua firmo.lua --interactive examples/interactive_mode_example.lua")
  logger.info(
    "\nOnce in interactive mode, try commands like 'run', 'tags basic', 'focus \"should pass\"', 'watch', 'help', 'quit'."
  )
end
