--- This example demonstrates how to configure various report formatters
--- (HTML, JSON, Summary, CSV) using Firmo's `central_config` system.
--
-- It shows:
-- - Setting configuration options for specific formatters using `central_config.set`.
-- - Retrieving formatter configuration using `central_config.get`.
-- - Verifying that configuration changes are applied.
--
-- @module examples.formatter_config_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see lib.core.central_config
-- @usage
-- Run embedded tests: lua firmo.lua examples/formatter_config_example.lua
--

local central_config = require("lib.core.central_config")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("FormatterConfigExample")

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

logger.info("--- Formatter Configuration Example ---")
logger.info("===============================")
logger.info("This example demonstrates how to configure formatters using the central configuration system")

-- Configure HTML formatter
logger.info("\n1. Configuring HTML formatter with light theme:")
central_config.set("reporting.formatters.html", {
  theme = "light", -- Light theme (default is dark)
  show_line_numbers = true, -- Show line numbers in source view
  collapsible_sections = true, -- Allow sections to be collapsed
  highlight_syntax = true, -- Apply syntax highlighting
  include_legend = true, -- Show legend explaining colors
})

-- Get HTML formatter configuration
logger.info("HTML formatter configuration:")
local html_config = central_config.get("reporting.formatters.html") or {}
if next(html_config) == nil then
  logger.warn("HTML config not found or empty")
else
  for k, v in pairs(html_config) do
    print(string.format("  %s = %s", k, tostring(v)))
  end
end

-- Configure JSON formatter
logger.info("\n2. Configuring JSON formatter:")
central_config.set("reporting.formatters.json", {
  pretty = true, -- Pretty-print JSON (indented)
  schema_version = "1.1", -- Schema version to include
})

-- Get JSON formatter configuration
logger.info("JSON formatter configuration:")
local json_config = central_config.get("reporting.formatters.json") or {}
if not json_config or next(json_config) == nil then
  logger.warn("JSON config not found or empty")
else
  for k, v in pairs(json_config) do
    print(string.format("  %s = %s", k, tostring(v)))
  end
end

-- Configure multiple formatters at once using separate set calls
logger.info("\n3. Configuring multiple formatters at once:")
central_config.set("reporting.formatters.summary", {
  detailed = true, -- Show detailed summary output
  show_files = true, -- Include file information
  colorize = true, -- Use colorized output when available
})
central_config.set("reporting.formatters.csv", {
  delimiter = ",",
  quote = '"',
  include_header = true,
})

-- Verify configuration using central_config directly
logger.info("\n4. Verifying configuration using central_config:")
local formatter_config = central_config.get("reporting.formatters") or {}
logger.info("All formatter configurations from central_config:")
if not formatter_config or next(formatter_config) == nil then
  logger.warn("No formatter configurations found in central_config")
else
  for formatter, config in pairs(formatter_config) do
    print("- " .. formatter .. ":")
    for k, v in pairs(config) do
      print(string.format("  %s = %s", k, tostring(v)))
    end
  end
end

logger.info("\n5. Basic test suite for demonstration:")
--- Basic test suite included to allow running this file with the test runner
-- and potentially see effects of configuration on output formats like summary.
--- @within examples.formatter_config_example
describe("Basic test", function()
  --- A simple passing test.
  it("should pass", function()
    expect(true).to.be.truthy()
  end)

  --- Another simple passing test.
  it("should have proper equality", function()
    expect({ 1, 2, 3 }).to.equal({ 1, 2, 3 })
  end)
end)

logger.info("\nTo see HTML output with configured light theme, use:")
logger.info("lua firmo.lua --format=html examples/formatter_config_example.lua")

logger.info("\nNOTE: Run this example using the standard test runner:")
logger.info("lua firmo.lua examples/formatter_config_example.lua")
