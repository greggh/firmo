---@class CoverageFormatters
---@field html table HTML formatter module
---@field lcov table LCOV formatter module
---@field json table JSON formatter module
---@field cobertura table Cobertura formatter module
---@field get_formatter fun(format: string): table|nil Gets a formatter by name
---@field get_available_formats fun(): string[] Gets a list of available formatters
---@field _VERSION string Version of this module
local M = {}

-- Version
M._VERSION = "1.0.0"

-- Load formatters
M.html = require("lib.reporting.formatters.html")
M.lcov = require("lib.reporting.formatters.lcov") 
M.json = require("lib.reporting.formatters.json")
M.cobertura = require("lib.reporting.formatters.cobertura")

-- Formatter mapping (for name lookup)
local formatters = {
  html = M.html,
  lcov = M.lcov,
  json = M.json,
  cobertura = M.cobertura
}

--- Gets a formatter by name
---@param format string The format name
---@return table|nil formatter The formatter module or nil if not found
function M.get_formatter(format)
  return formatters[format]
end

--- Gets a list of available formatters
---@return string[] formats List of available format names
function M.get_available_formats()
  local formats = {}
  for format, _ in pairs(formatters) do
    table.insert(formats, format)
  end
  table.sort(formats)
  return formats
end

return M