--- Firmo Version Module
---
--- This module serves as the single source of truth for the Firmo project version.
--- It defines the current MAJOR.MINOR.PATCH version components and provides functions
--- for parsing and comparing semantic version strings according to the SemVer 2.0.0 specification.
--- See: https://semver.org/
---
--- @module lib.core.version
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.7.5

---@class version The public API of the version module.
---@field major number Major version component (e.g., 0).
---@field minor number Minor version component (e.g., 7).
---@field patch number Patch version component (e.g., 5).
---@field string string Combined version string (e.g., "0.7.5").
---@field parse fun(version_string: string): {major: number, minor: number, patch: number, string: string}|nil, table? Parses a "MAJOR.MINOR.PATCH" string into a table. Returns `version_table, nil` on success, `nil, error_object` on failure. Throws error on validation failure.
---@throws table If validation fails.
---@field compare fun(version1: string|table, version2: string|table): number|nil, table? Compares two versions. Returns `-1` (v1 < v2), `0` (v1 == v2), `1` (v1 > v2), or `nil, error_object` on failure. Throws error on validation failure.
---@throws table If validation fails.
---@field satisfies_requirement fun(required_version: string|table): boolean|nil, table? Checks if the current module version (`M`) is >= `required_version`. Returns `true/false, nil` on success, `nil, error_object` on failure. Throws error on validation failure.
---@throws table If validation fails.

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the success handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

---@type version
local M = {}

-- Individual version components
M.major = 0
M.minor = 7
M.patch = 5

-- Combined semantic version
M.string = string.format("%d.%d.%d", M.major, M.minor, M.patch)

--- Parse a semantic version string into its components
--- This function takes a version string in the format "MAJOR.MINOR.PATCH" and
--- parses it into a table with separate numeric components. It validates the
--- format and returns appropriate error objects if the parsing fails.
---
---@param version_string string Version string to parse in format "MAJOR.MINOR.PATCH"
---@return table|nil parsed_version Table with major, minor, patch components or nil on error
---@return table|nil error Error object if operation failed (e.g., invalid format).
---@throws table If `version_string` validation fails (nil or wrong type).
---
---@usage
--- -- Parse a version string
--- local version, err = version.parse("1.2.3")
--- if version then
---   print(string.format("Major: %d, Minor: %d, Patch: %d",
---     version.major, version.minor, version.patch))
--- else
---   print("Error parsing version: " .. err.message)
--- end
---
--- -- Error handling for invalid format
--- local invalid, err = version.parse("1.2")
--- if not invalid then
---   print("Invalid format: " .. err.message)
--- end
function M.parse(version_string)
  -- Parameter validation
  if version_string == nil then
    local err = get_error_handler().validation_error("Version string cannot be nil", { function_name = "version.parse" })
    log.debug("version.parse validation failed", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  if type(version_string) ~= "string" then
    local err = get_error_handler().validation_error("Version string must be a string", {
      function_name = "version.parse",
      provided_type = type(version_string),
    })
    log.debug("version.parse validation failed", {
      error = get_error_handler().format_error(err),
      provided_type = type(version_string),
    })
    return nil, err
  end

  -- Parse semantic version
  local major, minor, patch = version_string:match("^(%d+)%.(%d+)%.(%d+)$")
  if not (major and minor and patch) then
    local err = get_error_handler().validation_error("Invalid version format, must be MAJOR.MINOR.PATCH", {
      function_name = "version.parse",
      provided_version = version_string,
      expected_format = "MAJOR.MINOR.PATCH",
    })
    log.debug("version.parse invalid format", {
      error = get_error_handler().format_error(err),
      version_string = version_string,
    })
    return nil, err
  end

  -- Convert to numbers
  local result = {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
    string = version_string,
  }

  log.debug("Parsed version string", {
    version_string = version_string,
    major = result.major,
    minor = result.minor,
    patch = result.patch,
  })

  return result
end

--- Compare two semantic versions
--- This function compares two version numbers and determines their relative order
--- according to semantic versioning rules. It can accept either version strings or
--- version tables and returns a comparison result (-1, 0, or 1) indicating which
--- version is newer. The function follows semantic versioning precedence rules where
--- major versions are compared first, then minor versions, and finally patch versions.
---
---@param version1 string|table First version to compare (string or version table)
---@param version2 string|table Second version to compare (string or version table)
---@return number|nil comparison -1 if v1 < v2, 0 if equal, 1 if v1 > v2, nil on error
---@return table|nil error Error object if operation failed (e.g., invalid format in input versions).
---@throws table If `version1` or `version2` validation fails (nil or wrong type/structure).
---
---@usage
--- -- Compare two version strings
--- local result, err = version.compare("1.2.3", "1.3.0")
--- if result then
---   if result < 0 then
---     print("1.2.3 is older than 1.3.0")
---   elseif result > 0 then
---     print("1.2.3 is newer than 1.3.0")
---   else
---     print("Versions are equal")
---   end
--- end
---
--- -- Compare with version tables
--- local v1 = {major = 2, minor = 0, patch = 0}
--- local result = version.compare(v1, "1.9.9")
--- -- result will be 1 (v1 is newer)
---
--- -- Error handling
--- local result, err = version.compare("invalid", "1.0.0")
--- if not result then
---   print("Comparison error: " .. err.message)
--- end
function M.compare(version1, version2)
  -- Parameter validation
  if version1 == nil then
    local err = get_error_handler().validation_error("First version cannot be nil", { function_name = "version.compare" })
    log.debug("version.compare validation failed", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  if version2 == nil then
    local err = get_error_handler().validation_error("Second version cannot be nil", { function_name = "version.compare" })
    log.debug("version.compare validation failed", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  -- Parse versions if they're strings
  local v1, v1_err
  local v2, v2_err

  if type(version1) == "string" then
    v1, v1_err = M.parse(version1)
    if not v1 then
      return nil, v1_err
    end
  elseif type(version1) == "table" and version1.major and version1.minor and version1.patch then
    v1 = version1
  else
    local err = get_error_handler().validation_error("First version must be a string or a properly formatted version table", {
      function_name = "version.compare",
      provided_type = type(version1),
    })
    log.debug("version.compare validation failed", {
      error = get_error_handler().format_error(err),
      version1 = version1,
    })
    return nil, err
  end

  if type(version2) == "string" then
    v2, v2_err = M.parse(version2)
    if not v2 then
      return nil, v2_err
    end
  elseif type(version2) == "table" and version2.major and version2.minor and version2.patch then
    v2 = version2
  else
    local err =
      get_error_handler().validation_error("Second version must be a string or a properly formatted version table", {
        function_name = "version.compare",
        provided_type = type(version2),
      })
    log.debug("version.compare validation failed", {
      error = get_error_handler().format_error(err),
      version2 = version2,
    })
    return nil, err
  end

  -- Compare major version
  if v1.major > v2.major then
    return 1
  elseif v1.major < v2.major then
    return -1
  end

  -- Compare minor version (if major versions are equal)
  if v1.minor > v2.minor then
    return 1
  elseif v1.minor < v2.minor then
    return -1
  end

  -- Compare patch version (if major and minor versions are equal)
  if v1.patch > v2.patch then
    return 1
  elseif v1.patch < v2.patch then
    return -1
  end

  -- Versions are equal
  return 0
end

--- Check if current version satisfies a minimum required version
--- This function determines if the current Firmo version meets or exceeds
--- a minimum version requirement. It's useful for feature detection and
--- compatibility checks within code that depends on the Firmo framework.
--- The function compares the current version against the provided requirement
--- and returns a boolean result indicating if the requirement is satisfied.
---
---@param required_version string|table Minimum required version (string or version table)
---@return boolean|nil satisfies True if current version satisfies requirement, nil on error
---@return table|nil error Error object if operation failed (e.g., invalid format in `required_version`).
---@throws table If `required_version` validation fails (nil or wrong type/structure).
---
---@usage
--- -- Check if current version is compatible with a requirement
--- local compatible, err = version.satisfies_requirement("0.5.0")
--- if compatible then
---   -- Use features introduced in 0.5.0
---   use_new_feature()
--- else
---   -- Use fallback for older versions
---   use_fallback()
--- end
---
--- -- Handle errors in version requirement check
--- local compatible, err = version.satisfies_requirement("invalid")
--- if not compatible then
---   if err then
---     print("Requirement check error: " .. err.message)
---   else
---     print("Requirement not satisfied")
---   end
--- end
---
--- -- Check against a version table
--- local req = {major = 0, minor = 6, patch = 0}
--- if version.satisfies_requirement(req) then
---   -- Code for version 0.6.0 and above
--- end
function M.satisfies_requirement(required_version)
  -- Parameter validation
  if required_version == nil then
    local err = get_error_handler().validation_error(
      "Required version cannot be nil",
      { function_name = "version.satisfies_requirement" }
    )
    log.debug("version.satisfies_requirement validation failed", {
      error = get_error_handler().format_error(err),
    })
    return nil, err
  end

  local comparison, err = M.compare(M, required_version)
  if not comparison then
    return nil, err
  end

  -- Current version is greater or equal to required version
  return comparison >= 0
end

return M
