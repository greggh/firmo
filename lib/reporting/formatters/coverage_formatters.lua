--- Coverage Formatter Registry
---
--- Provides access to all registered coverage formatter modules (HTML, LCOV, JSON, Cobertura).
--- Allows retrieving a specific formatter by name or getting a list of all available ones.
---
--- @module lib.reporting.formatters.coverage_formatters
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0


-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

---@class CoverageFormatters The public API for the coverage formatter registry.
---@field _VERSION string Version of this module.
---@field html table HTML formatter module (`lib.reporting.formatters.html`).
---@field lcov table LCOV formatter module (`lib.reporting.formatters.lcov`).
---@field json table JSON formatter module (`lib.reporting.formatters.json`).
---@field cobertura table Cobertura formatter module (`lib.reporting.formatters.cobertura`).
---@field junit table JUnit formatter module (`lib.reporting.formatters.junit`).
---@field get_formatter fun(format: string): table|nil Gets a specific formatter module by its name (e.g., "html", "lcov").
---@field get_available_formats fun(): string[] Gets a sorted list of available formatter names.
local M = {}

-- Version
M._VERSION = "1.0.0"

-- Load formatters
M.html = try_require("lib.reporting.formatters.html")
M.lcov = try_require("lib.reporting.formatters.lcov")
M.json = try_require("lib.reporting.formatters.json")
M.cobertura = try_require("lib.reporting.formatters.cobertura")
M.junit = try_require("lib.reporting.formatters.junit")

-- Formatter mapping (for name lookup)
local formatters = {
  html = M.html,
  lcov = M.lcov,
  json = M.json,
  cobertura = M.cobertura,
  junit = M.junit,
}

--- Gets a formatter by name
---@param format string The name of the desired format (e.g., "html", "lcov"). Case-sensitive.
---@return table|nil formatter The corresponding formatter module table (e.g., `M.html`), or `nil` if the format name is not found.
function M.get_formatter(format)
  return formatters[format]
end

--- Gets a list of available formatters
---@return string[] formats A new table containing a sorted list of available coverage formatter names (e.g., `{"cobertura", "html", "json", "lcov"}`).
function M.get_available_formats()
  local formats = {}
  for format, _ in pairs(formatters) do
    table.insert(formats, format)
  end
  table.sort(formats)
  return formats
end

return M
