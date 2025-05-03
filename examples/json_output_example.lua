--- json_output_example.lua
--
-- This file demonstrates tests with different outcomes (pass, fail, skip/pending).
-- It is intended to be run with the `--format=json` flag to showcase the
-- JSON test results output format used by Firmo, which is particularly relevant
-- for inter-process communication, such as aggregating results from parallel
-- test runners.
--
-- Run with JSON output: lua test.lua --format=json examples/json_output_example.lua
--

local logging = require("lib.tools.logging")

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
  it("should pass this test", function()
    expect(1 + 1).to.equal(2)
  end)

  --- Another simple passing test.
  it("should pass this test too", function()
    expect(true).to.be(true)
  end)

  --- Example of a skipped test using `firmo.pending`.
  -- @pending This test is intentionally skipped using firmo.pending.
  it("should skip this test using firmo.pending", function()
    firmo.pending("Skipping for the example")
  end)

  --- A test designed to fail to show the 'failure' structure in JSON output.
  it("should fail this test for demonstration", function()
    expect(1).to.equal(2) -- This assertion will fail
  end)
end)

-- Log usage instructions
logger.info("\n-- JSON Output Example --")
logger.info("This file demonstrates tests with different outcomes (pass, fail, skip).")
logger.info("Run with the JSON results formatter to see the output structure:")
logger.info("  lua test.lua --format=json examples/json_output_example.lua")
logger.info(
  "(Note: The '--format' flag controls the *final* report format, not the inter-process format used by parallel execution, which is typically JSON internally.)"
)
