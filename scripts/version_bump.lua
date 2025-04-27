#!/usr/bin/env lua
--- Version Bump Script
---
--- Updates the version number consistently across various project files, including
--- the core version module, README, CHANGELOG, rockspec, and package.json.
--- Parses the new version from command-line arguments.
---
--- Usage: lua scripts/version_bump.lua [project_name] <new_version>
--- Example: lua scripts/version_bump.lua my_project 1.2.3
---
--- @author Firmo Team
--- @version 1.0.0
--- @script

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _logging, _fs

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the filesystem module with lazy loading to avoid circular dependencies
---@return table|nil The filesystem module or nil if not available
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
end

--- Get the logging module with lazy loading to avoid circular dependencies
---@return table|nil The logging module or nil if not available
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end

--- Get a logger instance for this module
---@return table A logger instance (either real or stub)
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("version_bump")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

--- Script configuration. Defines files to check for version strings,
--- patterns to find the version, and how to replace it.
---@type {version_files: {path: string, pattern: string, replacement: function|string, complex?: boolean}[]}
local config = {
  -- Known files that should contain version information
  version_files = {
    -- Main source of truth (path corrected)
    { path = "lib/core/version.lua", pattern = "M.major = (%d+).-M.minor = (%d+).-M.patch = (%d+)", required = true },
    -- Documentation files
    { path = "README.md", pattern = "Version: v([%d%.]+)", required = true },
    { path = "CHANGELOG.md", pattern = "## %[([%d%.]+)%]", required = true },
    -- Package files
    { path = "%s.rockspec", pattern = 'version = "([%d%.]+)"', required = false },
    { path = "package.json", pattern = '"version": "([%d%.]+)"', required = false },
  },
}

-- Get the project name from the script argument or from the current directory
local project_name = arg[1]
if not project_name then
  local pwd = get_fs().get_absolute_path(".")
  ---@diagnostic disable-next-line: need-check-nil
  local project_name_with_path = pwd:match("/([^/]+)$")
  project_name = project_name_with_path:gsub("%-", "_")
end

-- Get the new version from the command line
local new_version = arg[2]
if not new_version then
  -- Usage info should be printed directly to stdout, regardless of log level
  print("Usage: lua version_bump.lua [project_name] <new_version>")
  print("Example: lua version_bump.lua 1.2.3")
  os.exit(1)
end

-- Validate version format
if not new_version:match("^%d+%.%d+%.%d+$") then
  get_logger().error("Version must be in the format X.Y.Z (e.g., 1.2.3)")
  os.exit(1)
end

-- Get the current date for CHANGELOG updates
local current_date = os.date("%Y-%m-%d")
-- Parse arguments
local args = parse_args()
--- Handles both simple version patterns and structured patterns (e.g., in version.lua).
---@param path string The path to the file.
---@param pattern string The Lua pattern to match the version. Should capture the version string(s).
---@return string|nil version The extracted version string (e.g., "1.2.3"), or nil if not found or error reading file.
---@return string? error_message Error message if file read failed.
---@private
local function extract_version(path, pattern)
  local content, err = get_fs().read_file(path)
  if not content then
    return nil, "Could not read " .. path .. ": " .. tostring(err)
  end

  -- Handle patterns that return multiple captures (like the structured version.lua)
  local major, minor, patch = content:match(pattern)
  if major and minor and patch then
    -- This is a structured version with multiple components
    return major .. "." .. minor .. "." .. patch
  end

  -- Regular single capture pattern
  local version = content:match(pattern)
  return version
end

--- Formats a path template string by replacing '%s' with the project name.
---@param path_template string The path string containing '%s'.
---@return string The formatted path string.
---@private
local function format_path(path_template)
  return path_template:format(project_name)
end

--- Checks if a file exists using the filesystem module.
---@param path string The path to check.
---@return boolean success True if the version was updated successfully.
---@private
local function update_version(path, pattern, new_version_str, new_version)
  get_logger().debug("Updating version in file", {
    path = path,
    pattern = pattern,
    new_version = new_version_str,
  })

  local content, read_err = read_file(path)
  if not content then
    local error_msg = "Could not read " .. path .. " to update version: " .. tostring(read_err)
    get_logger().error("Version update failed", {
      path = path,
      error = error_msg,
    })
    return false, error_msg
  end

  local updated_content
  local match_found = false
  local replacement_count = 0

  -- Handle the canonical version file (lib/core/version.lua) with structured replacement
  if path == "lib/core/version.lua" and new_version then
    -- Robust pattern to capture prefixes, numbers, and suffixes (including newlines/whitespace)
    local structured_pattern = "(M%.major%s*=%s*)(%d+)(.-)(M%.minor%s*=%s*)(%d+)(.-)(M%.patch%s*=%s*)(%d+)"
    updated_content, replacement_count = content:gsub(
      structured_pattern,
      function(p1, _, s1, p2, _, s2, p3, _)
        match_found = true -- Mark as found if gsub callback executes
        -- Reconstruct using captured prefixes/suffixes and new version numbers
        return string.format(
          "%s%d%s%s%d%s%s%d",
          p1,
          new_version.major,
          s1,
          p2,
          new_version.minor,
          s2,
          p3,
          new_version.patch
        )
      end,
      1 -- Replace only the first occurrence
    )
    if match_found then
      get_logger().debug("Structured version pattern matched and replaced", {
        path = path,
        pattern_used = structured_pattern,
        new_version = new_version_str,
        replacements = replacement_count,
      })
    end
  else
    -- Handle other files with potentially simpler capture patterns (e.g., single version string)
    -- Need to ensure we replace only the captured group, not the whole match line
    updated_content, replacement_count = content:gsub(pattern, function(...)
      local captures = { ... }
      local full_match = captures[1] -- The full string matched by the pattern
      local version_capture -- Find the capture group that holds the version number
      -- Iterate through captures; assume the version is the first non-nil simple capture
      for i = 2, #captures - 1 do -- Exclude the last two captures (position, string) from gsub
        if captures[i] ~= nil then
          version_capture = captures[i]
          break
        end
      end

      if version_capture then
        match_found = true
        get_logger().debug("Simple version pattern matched", {
          path = path,
          pattern = pattern,
          full_match = full_match,
          matched_version = version_capture,
          new_version = new_version_str,
          replacements = replacement_count + 1, -- Increment within callback
        })
        -- Replace the old version within the full match with the new version
        return full_match:gsub(version_capture:gsub("%%", "%%%%"), new_version_str:gsub("%%", "%%%%"), 1)
      else
        -- If no capture group found, return the original full match (no change)
        get_logger().warn(
          "Pattern matched but no version capture group found",
          { path = path, pattern = pattern, match = full_match }
        )
        return full_match
      end
    end, 1) -- Replace only the first occurrence that yields a valid capture
  end

  -- Ensure replacement actually happened (replacement_count > 0 includes the gsub execution check)
  if replacement_count == 0 then
    match_found = false -- Correct match_found if gsub didn't replace anything
  end

  if not match_found then
    local error_msg = "Could not find or replace version pattern '" .. pattern .. "' in " .. path
    get_logger().warn("Version update skipped or failed", {
      path = path,
      pattern = pattern,
      reason = "pattern_not_found_or_replaced",
      replacement_count = replacement_count,
    })
    -- Treat pattern not found/replaced in optional files as non-fatal
    -- Find if the current path is required
    local is_required = false
    for _, file_config in ipairs(config.version_files) do
      if format_path(file_config.path) == path then
        is_required = file_config.required
        break
      end
    end
    if is_required then
      get_logger().error("Required file pattern mismatch", { path = path, pattern = pattern })
      return false, error_msg
    else
      return true -- Indicate success (no error), but nothing was changed
    end
  end

  -- Write the updated content back to the file
  local success, write_err = get_fs().write_file(path, updated_content)
  if not success then
    local error_msg = "Could not write updated version to " .. path .. ": " .. tostring(write_err)
    get_logger().error("Version update failed", {
      path = path,
      error = error_msg,
    })
    return false, error_msg
  end

  get_logger().info("Successfully updated version", {
    path = path,
    new_version = new_version_str,
  })

  return true
end

--- Main function to orchestrate the version update across all configured files.
--- Validates the canonical version file, updates each file, logs results, and prints commit/tag instructions.
---@param new_version string The new version string to set.
---@return boolean success True if all applicable files were updated successfully, false otherwise.
---@private
local function bump_version(new_version)
  get_logger().info("Bumping version to: " .. new_version)

  local all_success = true

  -- First, update the canonical version
  local version_file_config = config.version_files[1]
  local version_file_path = format_path(version_file_config.path)

  if not file_exists(version_file_path) then
    get_logger().error("❌ Canonical version file not found: " .. version_file_path)

    -- Ask if we should create it
    io.write("Would you like to create it? (y/n): ")
    local answer = io.read()
    if answer:lower() == "y" or answer:lower() == "yes" then
      -- Get the directory path
      local dir_path = version_file_path:match("(.+)/[^/]+$")
      if dir_path then
        get_fs().ensure_directory_exists(dir_path)
        get_fs().write_file(version_file_path, string.format('return "%s"', new_version))
        get_logger().info("✅ Created version file: " .. version_file_path)
      else
        get_logger().error("❌ Could not determine directory path for: " .. version_file_path)
        return false
      end
    else
      return false
    end
  end

  -- Update each file
  for _, file_config in ipairs(config.version_files) do
    local success = update_version(file_config, new_version)
    if not success then
      all_success = false
    end
  end

  if all_success then
    get_logger().info("\n🎉 Version bumped to " .. new_version .. " successfully!")
    get_logger().info("\nRemember to:")
    get_logger().info("1. Review the changes, especially in CHANGELOG.md")
    get_logger().info('2. Commit the changes: git commit -m "Release: Version ' .. new_version .. '"')
    get_logger().info("3. Create a tag: git tag -a v" .. new_version .. ' -m "Version ' .. new_version .. '"')
    get_logger().info("4. Push the changes: git push && git push --tags")
    return true
  else
    get_logger().warn("\n⚠️ Version bump completed with some errors.")
    return false
  end
end

-- Run the version bump
local success = bump_version(new_version)
if not success then
  os.exit(1)
end
