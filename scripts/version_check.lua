#!/usr/bin/env lua
--- Version Check Script
---
--- Validates that the version number is consistent across various project files,
--- comparing them against the canonical version defined in `src/version.lua`.
--- Reports mismatches or missing versions in required files.
---
--- Usage: lua scripts/version_check.lua [project_name]
--- Example: lua scripts/version_check.lua my_project
---
--- @author Firmo Team
--- @version 1.1.0
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
    return logging.get_logger("scripts.version_check")
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

-- Set script version
local VERSION = "1.1.0"
get_logger().debug("Version check script initialized", {
  version = VERSION,
})

--- Script configuration. Defines files to check, patterns to find the version,
--- and whether the file is required to exist and contain the pattern.
---@type {version_files: {path: string, pattern: string, required: boolean}[]}
local config = {
  -- Known files that should contain version information
  version_files = {
    -- Main source of truth (path corrected, pattern updated for extraction logic)
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

--- Reads a file's content using the filesystem module.
---@param path string The path to the file.
---@return string|nil content The file content, or nil if reading failed.
---@return string? error_message Error message if reading failed.
---@private
local function read_file(path)
  get_logger().debug("Reading file", {
    path = path,
  })

  local content, err = get_fs().read_file(path)
  if not content then
    get_logger().warn("Failed to open file for reading", {
      path = path,
      error = err,
    })
    return nil, err
  end

  get_logger().debug("File read successfully", {
    path = path,
    content_length = #content,
  })

  return content
end

--- Extracts the version string from a file's content using a specified pattern.
--- Handles patterns with multiple captures (e.g., structured version.lua) and
--- alternative patterns separated by '|'.
---@param path string The path to the file (used for logging).
---@param pattern string The Lua pattern to match the version. May include captures and '|'.
---@return string|nil version The extracted version string, or nil if not found or read error.
---@return string? error_message Error message if file could not be read.
---@private
local function extract_version(path, pattern)
  get_logger().debug("Extracting version", {
    path = path,
    pattern = pattern,
  })

  local content, err = read_file(path)
  if not content then
    local error_msg = "Could not read " .. path .. ": " .. tostring(err)
    get_logger().error("Version extraction failed", {
      path = path,
      error = error_msg,
    })
    return nil, error_msg
  end

  -- First, check for structured version with major.minor.patch format
  local major, minor, patch = content:match(pattern)
  if major and minor and patch then
    local version = major .. "." .. minor .. "." .. patch
    get_logger().debug("Extracted structured version", {
      path = path,
      major = major,
      minor = minor,
      patch = patch,
      version = version,
    })
    return version
  end

  -- Handle multiple capture patterns (separated by |)
  local version
  if pattern:find("|") then
    get_logger().debug("Processing multi-pattern version extraction", {
      path = path,
    })

    for p in pattern:gmatch("([^|]+)") do
      version = content:match(p)
      if version then
        get_logger().debug("Pattern matched", {
          path = path,
          pattern = p,
          version = version,
        })
        break
      end
    end
  else
    version = content:match(pattern)
  end

  -- Also handle multiple captures in a single pattern
  if type(version) ~= "string" then
    if version then
      get_logger().debug("Processing multiple captures", {
        path = path,
        capture_type = type(version),
      })

      for i, v in pairs(version) do
        if v and v ~= "" then
          version = v
          get_logger().debug("Selected capture", {
            path = path,
            capture_index = i,
            value = v,
          })
          break
        end
      end
    end
  end

  if version then
    get_logger().debug("Version extracted successfully", {
      path = path,
      version = version,
    })
  else
    get_logger().warn("No version found in file", {
      path = path,
      pattern = pattern,
    })
  end

  return version
end

--- Formats a path template string by replacing '%s' with the project name.
---@param path_template string The path string containing '%s'.
---@return string The formatted path string.
---@private
local function format_path(path_template)
  local formatted = path_template:format(project_name)

  get_logger().debug("Formatted path template", {
    template = path_template,
    project = project_name,
    result = formatted,
  })

  return formatted
end

--- Checks if a file exists using the filesystem module.
---@param path string The path to check.
---@return boolean True if the file exists, false otherwise.
---@private
local function file_exists(path)
  get_logger().debug("Checking if file exists", {
    path = path,
  })

  local exists = get_fs().file_exists(path)

  if exists then
    get_logger().debug("File exists", {
      path = path,
    })
  else
    get_logger().debug("File does not exist", {
      path = path,
    })
  end

  return exists
end

--- Main function to perform the version consistency check across configured files.
--- Reads the canonical version, then iterates through other files, comparing versions.
--- Logs results and collects errors.
---@return boolean success True if all versions are consistent (or files skipped appropriately), false if mismatches or errors occurred.
---@return string[]? errors An array of error message strings if `success` is false.
---@return string[]? errors An array of error message strings if `success` is false.
---@private
local function check_versions()
  ---@diagnostic disable-next-line: unused-local
  local versions = {}
  local errors = {}
  local canonical_version

  get_logger().info("Starting version consistency check", {
    project = project_name,
    files_to_check = #config.version_files,
  })

  -- First, get the canonical version via require
  ---@diagnostic disable-next-line: unused-local
  local version_module = try_require("lib.core.version")

  canonical_version = version_module.string
  if not canonical_version then
    local error_msg = "Canonical version string not found in module: lib.core.version"
    table.insert(errors, error_msg)
    get_logger().error("Version check failed", {
      error = "missing_canonical_version_string",
      module = "lib.core.version",
    })
    return false, errors
  end

  get_logger().info("Canonical version loaded via require", {
    version = canonical_version,
    source_module = "lib.core.version",
  })

  -- Check each file defined in config
  local files_checked = 0
  local matches = 0
  local mismatches = 0
  local skipped = 0

  for _, file_config in ipairs(config.version_files) do
    local path = format_path(file_config.path)

    -- Skip checking the canonical file itself using the extraction method
    if path == "lib/core/version.lua" then
      goto continue_loop -- Skip to the next iteration
    end

    get_logger().debug("Checking file for version consistency", {
      file = path,
      pattern = file_config.pattern,
      required = file_config.required,
    })

    if file_exists(path) then
      files_checked = files_checked + 1
      local version = extract_version(path, file_config.pattern)

      if version then
        if version ~= canonical_version then
          local error_msg =
            string.format("Version mismatch in %s: expected %s, found %s", path, canonical_version, version)
          table.insert(errors, error_msg)
          mismatches = mismatches + 1

          get_logger().warn("Version mismatch detected", {
            file = path,
            expected = canonical_version,
            found = version,
          })
        else
          matches = matches + 1
          get_logger().info("Version match confirmed", {
            file = path,
            version = version,
          })
        end
        ---@diagnostic disable-next-line: unused-local
        versions[path] = version
      else
        if file_config.required then
          local error_msg = "Could not find version in " .. path
          table.insert(errors, error_msg)
          get_logger().error("Version pattern not found in required file", {
            file = path,
            pattern = file_config.pattern,
          })
        else
          skipped = skipped + 1
          get_logger().info("Skipping optional file", {
            file = path,
            reason = "version_pattern_not_found",
          })
        end
      end
    else
      if file_config.required then
        local error_msg = "Required file not found: " .. path
        table.insert(errors, error_msg)
        get_logger().error("Required file not found", {
          file = path,
        })
      else
        skipped = skipped + 1
        get_logger().info("Skipping optional file", {
          file = path,
          reason = "file_not_found",
        })
      end
    end
    ::continue_loop:: -- Label for the goto statement
  end

  -- Output results
  if #errors > 0 then
    get_logger().error("Version check failed", {
      error_count = #errors,
      files_checked = files_checked,
      matches = matches,
      mismatches = mismatches,
      skipped = skipped,
    })

    for i, err in ipairs(errors) do
      get_logger().error("Version error details", {
        index = i,
        error = err,
      })
    end

    return false, errors
  else
    get_logger().info("Version check completed successfully", {
      canonical_version = canonical_version,
      files_checked = files_checked,
      matches = matches,
      skipped = skipped,
      status = "all_consistent",
    })

    return true, nil
  end
end

-- Run the version check
get_logger().debug("Starting version check script execution", {
  project = project_name,
})

local success, errors = check_versions()

if not success then
  get_logger().error("Version check failed, exiting with error code 1", {
    error_count = #errors,
  })
  os.exit(1)
else
  get_logger().info("Version check passed", {
    exit_code = 0,
  })
end

return success
