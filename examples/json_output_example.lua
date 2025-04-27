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

-- Import the testing framework
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("JSONOutputExample")

-- Define aliases
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Example test suite
--- Test suite containing examples of passing, failing, and skipped tests.
describe("JSON Output Example", function()
  it("should pass this test", function()
    expect(1 + 1).to.equal(2)
  end)

  it("should pass this test too", function()
    expect(true).to.be(true)
  end)

  --- Example of a skipped test using `firmo.pending`.
  -- @pending This test is intentionally skipped using firmo.pending.
  it("should skip this test", function()
    firmo.pending("Skipping for the example")
  end)

  it("should fail this test for demonstration", function()
    expect(1).to.equal(2) -- This will fail
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
