#!/usr/bin/env lua
--- interactive_mode_example.lua
--
-- This example file contains a set of tests designed to be explored using
-- Firmo's interactive Command Line Interface (CLI) mode. The tests demonstrate
-- basic assertions, tagging, and mocking features within the context of the
-- interactive runner.
--
-- Run this example using the interactive flag:
--   lua test.lua --interactive examples/interactive_mode_example.lua
--
-- Once inside the interactive mode, you can experiment with commands like
-- 'run', 'tags basic', 'focus "<test name>"', 'watch', 'help', etc.
--

-- Load firmo and the interactive module
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local interactive = require("lib.tools.interactive") -- Keep for context, though start() removed
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("InteractiveExample")

-- Extract test functions for cleaner code
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local tags, focus = firmo.tags, firmo.focus

-- Define a simple set of tests
--- Example test suite for demonstrating interactive mode features.
describe("Example Tests for Interactive Mode", function()
  before(function()
    -- Setup code runs before each test
    logger.debug("Setting up test environment...")
  end)

  after(function()
    -- Cleanup code runs after each test
    logger.debug("Cleaning up test environment...")
  end)

  it("should pass a simple test", function()
    expect(2 + 2).to.equal(4)
  end)

  it("can be tagged with 'basic'", function()
    tags("basic")
    expect(true).to.be_truthy()
  end)

  it("can be tagged with 'advanced'", function()
    tags("advanced")
    expect(false).to_not.be_truthy()
  end)

  it("demonstrates expect assertions", function()
    expect(5).to.be.a("number")
    expect("test").to_not.be.a("number")
    expect(true).to.be_truthy()
    expect(false).to_not.be_truthy()
  end)

  --- Example of a nested test suite.
  describe("Nested test group", function()
    it("should support focused tests", function()
      -- To focus this test in interactive mode, use: focus "Nested test group should support focused tests"
      expect(4 * 4).to.equal(16)
    end)

    it("demonstrates mocking", function()
      local original_func = function(x)
        return x * 2
      end
      local mock = firmo.mock(original_func)

      -- Setup the mock to return a specific value
      mock.returns(42)

      -- Call the mocked function
      local result = mock(10)

      -- Verify the mock worked
      expect(result).to.equal(42)
      expect(mock.called).to.be_truthy()
      expect(mock.calls[1][1]).to.equal(10)
    end)
  end)
end)

-- Log usage instructions
logger.info("\n-- Interactive Mode Example --")
logger.info("This file contains tests designed to be run using Firmo's interactive mode.")
logger.info("Run with:")
logger.info("  lua test.lua --interactive examples/interactive_mode_example.lua")
logger.info(
  "\nOnce in interactive mode, try commands like 'run', 'tags basic', 'focus \"Nested test group should support focused tests\"', 'watch', 'help', 'quit'."
)
