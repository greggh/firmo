--- formatter_config_example.lua
--
-- This example demonstrates how to configure various report formatters
-- (HTML, JSON, Summary, CSV) using Firmo's `central_config` system.
--
-- It shows:
-- - Setting configuration options for specific formatters using `central_config.set`.
-- - Retrieving formatter configuration using `central_config.get`.
-- - Verifying that configuration changes are applied.
--
-- Run embedded tests: lua test.lua examples/formatter_config_example.lua
--

local firmo = require("firmo")
local central_config = require("lib.core.central_config")
local error_handler = require("lib.tools.error_handler")
local reporting = require("lib.reporting") -- Keep for context, though direct config calls removed
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("FormatterConfigExample")

-- Test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

logger.info("Formatter Configuration Example")
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
  logger.warn("HTML config not found")
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
if next(json_config) == nil then
  logger.warn("JSON config not found")
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
if next(formatter_config) == nil then
  logger.warn("No formatter configurations found in central_config")
else
  for formatter, config in pairs(formatter_config) do
    print("- " .. formatter .. ":")
    for k, v in pairs(config) do
      print(string.format("  %s = %s", k, tostring(v)))
    end
  end
end

logger.info("\n5. Simple test for demonstration:")
-- Write a simple test
--- Basic test suite included for demonstration purposes.
describe("Basic test", function()
  it("should pass", function()
    expect(true).to.be.truthy()
  end)

  it("should have proper equality", function()
    expect({ 1, 2, 3 }).to.equal({ 1, 2, 3 })
  end)
end)

logger.info("\nTo see HTML output with configured light theme, use:")
logger.info("lua test.lua --format=html examples/formatter_config_example.lua")

logger.info("\nNOTE: Run this example using the standard test runner:")
logger.info("lua test.lua examples/formatter_config_example.lua")
