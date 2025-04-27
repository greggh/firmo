--- LPegLabel Loader
---
--- This module attempts to load or compile the LPegLabel C module, which provides
--- extended functionality for LPeg including labeled failures and other captures.
--- Includes a fallback to a pure Lua implementation if loading/building fails.
--- Original C source: https://github.com/sqmedeiros/lpeglabel
---
--- @module lib.tools.vendor.lpeglabel
--- @license MIT

---@class lpeglabel The LPegLabel API (interface defined by the C module or fallback).
---@field _VERSION string Module version string (e.g., "1.0.0").
---@field match fun(pattern: table, subject: string, init?: number): any, ... Matches `subject` against LPeg `pattern`. Returns captures or `nil`.
---@field type fun(v: any): string Returns "pattern" if `v` is an LPeg pattern object, otherwise returns Lua type.
---@field P fun(p: string|table|number|boolean|function): table Creates an LPeg pattern from various inputs. Returns pattern object.
---@field S fun(set: string): table Creates a pattern matching any character in the set. Returns pattern object.
---@field R fun(range: string, ...): table Creates a pattern matching character ranges. Returns pattern object.
---@field V fun(v: string|number): table Creates a pattern variable (reference to grammar rule). Returns pattern object.
---@field C fun(p: table): table Creates a simple capture pattern. Returns pattern object.
---@field Cc fun(...): table Creates a constant capture pattern. Returns pattern object.
---@field Cp fun(): table Creates a position capture pattern. Returns pattern object.
---@field Cmt fun(p: table, f: function): table Creates a match-time capture pattern. Returns pattern object.
---@field Ct fun(p: table): table Creates a table capture pattern. Returns pattern object.
---@field T fun(l: string|number): table Creates a labeled failure point (LPegLabel specific). Returns pattern object.
---@field B fun(p: table): table Creates a back reference pattern. Returns pattern object.
---@field Carg fun(n: number): table Creates an argument capture pattern. Returns pattern object.
---@field Cb fun(name: string): table Creates a back capture pattern (captures previously named group). Returns pattern object.
---@field Cf fun(p: table, f: function): table Creates a fold capture pattern. Returns pattern object.
---@field Cg fun(p: table, name?: string): table Creates a group capture pattern. Returns pattern object.
---@field Cs fun(p: table): table Creates a substitution capture pattern. Returns pattern object.
---@field Lc fun(p: table): table Creates a labeled failure capture pattern (LPegLabel specific). Returns pattern object.
---@field setlabels fun(labels: table<string, string>): table Sets the mapping of labels (used by `T` and `Lc`) to error messages. Returns self.
---@field locale fun(t?: table): table Gets or sets the current locale table used for character sets like `[:alpha:]`. Returns current locale table.
---@field version fun(): string Gets the LPegLabel version string.
---@field setmaxstack fun(n: number): boolean Sets the maximum stack size for the LPeg VM. Returns `true`. @throws error If n is invalid.
---@field ispatterntable fun(p: any): boolean Checks if a value is an LPeg pattern object.

local M = {}

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _fs

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

-- Detect operating system
local is_windows = package.config:sub(1, 1) == "\\"
local extension = is_windows and "dll" or "so"

-- Define paths
local script_path = debug.getinfo(1, "S").source:sub(2):match("(.+/)[^/]+$") or "./"
local vendor_dir = script_path
-- Ensure paths are strings
if type(vendor_dir) ~= "string" then
  vendor_dir = "./"
  print("Warning: vendor_dir is not a string, using './' instead")
end
-- Use direct string concatenation instead of get_fs().join_paths
local module_path = vendor_dir .. "lpeglabel." .. extension
local build_log_path = vendor_dir .. "build.log"

-- Debug paths
print("LPegLabel paths:")
print("- script_path: " .. tostring(script_path))
print("- vendor_dir: " .. tostring(vendor_dir))
print("- module_path: " .. tostring(module_path) .. " (type: " .. type(module_path) .. ")")
print("- build_log_path: " .. tostring(build_log_path) .. " (type: " .. type(build_log_path) .. ")")

--- Checks if the compiled LPegLabel module file exists.
---@return boolean needs_build `true` if the module file doesn't exist, `false` otherwise.
---@throws table If filesystem operations (`get_fs().file_exists`) fail critically.
---@private
local function needs_build()
  return not get_fs().file_exists(module_path)
end

--- Determines the current platform ("windows", "macosx", "linux").
---@return "windows"|"macosx"|"linux" platform The platform string.
---@throws error If `io.popen("uname")` fails (though handled by pcall).
---@private
local function get_platform()
  if is_windows then
    return "windows"
  end

  -- Check if we're on macOS
  local success, result = pcall(function()
    local handle = io.popen("uname")
    if not handle then
      return "linux"
    end

    local output = handle:read("*a")
    handle:close()
    return output:match("Darwin") and "macosx" or "linux"
  end)

  return success and result or "linux"
end

--- Attempts to build the LPegLabel C module using `make` or `mingw32-make`.
--- Writes build output to `build.log`.
---@return boolean success `true` if the build succeeded (module file exists afterwards).
---@return string? error Error message string if the build failed.
---@throws table If filesystem operations (`write_file`, `append_file`, `change_dir`) fail critically.
---@private
local function build_module()
  -- Create or empty the log file
  local log_content = "Building LPegLabel module at " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"

  -- Ensure we have a valid path before writing
  if type(build_log_path) ~= "string" then
    print("Error: build_log_path is not a string: " .. tostring(build_log_path))
    return false, "Invalid build log path (not a string)"
  end

  local write_success = get_fs().write_file(build_log_path, log_content)

  if not write_success then
    return false, "Could not create build log file"
  end

  -- Get current directory
  local current_dir = get_fs().get_absolute_path(".")

  -- Get platform (windows, linux, macosx)
  local platform = get_platform()
  log_content = log_content .. "Detected platform: " .. platform .. "\n"
  get_fs().append_file(build_log_path, "Detected platform: " .. platform .. "\n")

  -- Change to the vendor directory
  local original_dir = get_fs().get_current_dir()
  if not get_fs().change_dir(vendor_dir) then
    get_fs().append_file(build_log_path, "Failed to change to vendor directory: " .. vendor_dir .. "\n")
    return false, "Failed to change to vendor directory"
  end

  -- Build the command
  local command
  local normalized_current_dir = get_fs().normalize_path(current_dir)

  -- Run the appropriate build command
  get_fs().append_file(build_log_path, "Running " .. platform .. " build command\n")

  local success, output
  if platform == "windows" then
    success, output = pcall(function()
      command = 'mingw32-make windows LUADIR="' .. normalized_current_dir .. '" 2>&1'
      local handle = io.popen(command)
      local result = handle:read("*a")
      handle:close()
      return result
    end)
  else
    success, output = pcall(function()
      command = "make " .. platform .. ' LUADIR="' .. normalized_current_dir .. '" 2>&1'
      local handle = io.popen(command)
      local result = handle:read("*a")
      handle:close()
      return result
    end)
  end

  -- Log the command and its output
  if command then
    get_fs().append_file(build_log_path, "Executing: " .. command .. "\n")
  end

  if not success then
    get_fs().append_file(build_log_path, "Error executing build command: " .. tostring(output) .. "\n")
  elseif output then
    get_fs().append_file(build_log_path, output .. "\n")
  end

  -- Change back to the original directory
  get_fs().change_dir(original_dir)

  -- Check if build succeeded
  if get_fs().file_exists(module_path) then
    get_fs().append_file(build_log_path, "Build succeeded. Module created at: " .. module_path .. "\n")
    return true
  else
    get_fs().append_file(build_log_path, "Build failed. Module not created at: " .. module_path .. "\n")
    return false, "Failed to build LPegLabel module"
  end
end

--- Loads the compiled LPegLabel C module.
--- Attempts to `package.loadlib` the pre-existing module file.
--- If loading fails or the file doesn't exist, it attempts to build the module using `build_module`
--- and then tries loading again. Falls back to a pure Lua implementation if all else fails.
---@return table lpeglabel The loaded LPegLabel module (either C or fallback).
---@throws error If building and loading both fail.
---@private
local function load_module()
  if package.loaded.lpeglabel then
    return package.loaded.lpeglabel
  end

  -- Check if C module already exists
  if get_fs().file_exists(module_path) then
    -- Try to load the module directly
    local ok, result = pcall(function()
      -- Use package.loadlib for better error messages
      local loader = package.loadlib(module_path, "luaopen_lpeglabel")
      if not loader then
        error("Failed to load lpeglabel library: Invalid loader")
      end
      return loader()
    end)

    if ok then
      package.loaded.lpeglabel = result
      return result
    else
      print("Warning: Failed to load existing lpeglabel module: " .. tostring(result))
      -- If loading failed, try rebuilding
      if needs_build() then
        local build_success, build_err = build_module()
        if not build_success then
          error("Failed to build lpeglabel module: " .. tostring(build_err))
        end
        -- Try loading again after rebuild
        return load_module()
      end
    end
  else
    -- Module doesn't exist, try to build it
    if needs_build() then
      local build_success, build_err = build_module()
      if not build_success then
        error("Failed to build lpeglabel module: " .. tostring(build_err))
      end
      -- Try loading again after build
      return load_module()
    end
  end

  error("Failed to load lpeglabel module after all attempts")
end

-- Attempt to load the module or build it on first use
local ok, result = pcall(load_module)
if not ok then
  -- Log and fallback if C module loading/building fails
  print("LPegLabel loading error: " .. tostring(result))
  print("Using fallback implementation with limited functionality")
  return require("lib.tools.vendor.lpeglabel.fallback")
end
-- Return the loaded module
return result
