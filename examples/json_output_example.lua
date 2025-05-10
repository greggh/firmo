--- This file demonstrates tests with different outcomes (pass, fail, skip/pending).
--- It is intended to be run with the `--format=json` flag to showcase the
-- JSON test results output format used by Firmo, which is particularly relevant
-- for inter-process communication, such as aggregating results from parallel
-- test runners.
--
-- @module examples.json_output_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see lib.reporting.formatters.json
-- @usage
-- Run with JSON output: lua firmo.lua --format=json examples/json_output_example.lua
--

local logging = require("lib.tools.logging")
local test_helper = require("lib.tools.test_helper")

-- Setup logger
local logger = logging.get_logger("JSONOutputExample")

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

-- Example test suite
--- Test suite containing examples of passing, failing, and skipped tests
-- specifically to demonstrate the structure of the JSON output format.
--- @within examples.json_output_example
describe("JSON Output Example", function()
  --- A simple passing test.
  --- @tags json demo pass
  it("should pass this test", function()
    firmo.tags("json", "demo", "pass")
    expect(1 + 1).to.equal(2)
  end)

  --- Another simple passing test.
  --- @tags json demo pass
  it("should pass this test too", function()
    firmo.tags("json", "demo", "pass")
    expect(true).to.be(true)
  end)

  --- Example of a skipped test using `firmo.pending`.
  -- @pending This test is intentionally skipped using firmo.pending.
  --- @tags json demo skip
  it("should skip this test using firmo.pending", function()
    firmo.tags("json", "demo", "skip")
    firmo.pending("Skipping for the example")
  end)

  --- A test designed to fail to show the 'failure' structure in JSON output.
  --- @tags json demo fail
  it("should fail this test for demonstration", { expect_error = true }, function()
    firmo.tags("json", "demo", "fail")
    local result, err = test_helper.with_error_capture(function()
      expect(1).to.equal(2) -- This assertion will fail
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("expected 1 to equal 2")
  end)
end)

-- Log usage instructions
logger.info("\n-- JSON Output Example --")
logger.info("This file demonstrates tests with different outcomes (pass, fail, skip).")
logger.info("Run with the JSON results formatter to see the output structure:")
logger.info("  lua firmo.lua --format=json examples/json_output_example.lua")
logger.info(
  "(Note: The '--format' flag controls the *final* report format, not the inter-process format used by parallel execution, which is typically JSON internally.)"
)
