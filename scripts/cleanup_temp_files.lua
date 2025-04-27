--- Cleanup Script for Firmo Temporary Files
---
--- Scans the system's temporary directory for files/directories potentially
--- created and orphaned by the Firmo testing framework and removes them.
--- Includes pattern matching and optional age checks.
---
--- Usage: lua scripts/cleanup_temp_files.lua [--dry-run] [--with-age-check] [--temp-dir=/path]
---
--- @author Firmo Team
--- @version 1.0.0
--- @script

--- @class TempFileInfo Information about a potential temporary file/directory.
--- @field path string Full path to the item.
--- @field name string Base name of the item.
--- @field is_dir boolean True if the item is a directory.

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
    logging.configure({
      console = {
        enabled = true,
        level = "INFO",
      },
    })
    return logging.get_logger("temp_file_cleanup")
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

local temp_file = require("lib.tools.filesystem.temp_file")

--- Determines the system's temporary directory path.
--- Uses os.tmpname() to find the path, then removes the temporary file created.
---@return string tempdir The path to the temporary directory (e.g., "/tmp").
---@private
local function get_temp_dir()
  local tempfile = os.tmpname()
  local tempdir = tempfile:match("^(.*)/") or "/tmp"
  os.remove(tempfile)
  return tempdir
end

--- Finds all potentially orphaned Firmo temporary files in a given directory.
--- Uses platform-specific commands (`ls` or `dir`) to list directory contents and then filters
--- based on predefined patterns (`lua_*`, `*.tmp`, etc.).
---@param temp_dir string The path to the temporary directory to scan.
---@return TempFileInfo[] files An array of tables, each describing a potential orphaned file or directory. Returns empty table on error listing directory.
---@private
local function find_orphaned_files(temp_dir)
  get_logger().info("Scanning for orphaned temporary files in: " .. temp_dir)
  -- Define patterns for Firmo temporary files
  local patterns = {
    "^lua_", -- Standard Lua temporary files created by os.tmpname()
    "^lua_.*_dir$", -- Directories created by temp_file module
    "^.*%.tmp$", -- Files with .tmp extension
    "^.*%.lua$", -- Lua files in temp directory
    "^luac_", -- Lua compiled files
    ".*%.luac$", -- Lua compiled files with extension
  }

  -- Get all files in temp directory
  local all_files = {}
  local file_count = 0
  local dir_count = 0

  -- List files in the temp directory
  local ok, err = pcall(function()
    -- Use os.execute to list directories since get_fs().list_directory might not be available
    local temp_file_list = os.tmpname()

    -- Use different commands based on platform
    local command
    if package.config:sub(1, 1) == "\\" then
      -- Windows
      command = 'dir /b "' .. temp_dir .. '" > ' .. temp_file_list
    else
      -- Unix
      command = 'ls -1 "' .. temp_dir .. '" > ' .. temp_file_list
    end

    -- Execute the command
    os.execute(command)

    -- Read the file list
    local f = io.open(temp_file_list, "r")
    if f then
      for line in f:lines() do
        local entry = line:match("^%s*(.-)%s*$") -- Trim whitespace
        if entry and entry ~= "" then
          local path = temp_dir .. "/" .. entry
          local is_dir = false

          -- Check if it's a directory
          local stat_cmd
          if package.config:sub(1, 1) == "\\" then
            -- Windows
            is_dir = get_fs().directory_exists and get_fs().directory_exists(path)
          else
            -- Unix
            -- Use test command to check if it's a directory
            local handle = io.popen('test -d "' .. path .. '" && echo "dir" || echo "file"')
            local result = handle:read("*a")
            handle:close()
            is_dir = result:match("dir") ~= nil
          end

          if is_dir then
            dir_count = dir_count + 1
          else
            file_count = file_count + 1
          end

          table.insert(all_files, {
            path = path,
            name = entry,
            is_dir = is_dir,
          })
        end
      end
      f:close()
    end

    -- Clean up temp file
    os.remove(temp_file_list)
  end)

  if not ok then
    get_logger().error("Failed to list files in temp directory", {
      directory = temp_dir,
      error = tostring(err),
    })
    return {}
  end

  get_logger().info("Found files in temp directory", {
    total = #all_files,
    files = file_count,
    directories = dir_count,
  })

  -- Filter for potential Firmo files
  local potential_files = {}
  for _, file in ipairs(all_files) do
    for _, pattern in ipairs(patterns) do
      if file.name:match(pattern) then
        table.insert(potential_files, file)
        break
      end
    end
  end

  get_logger().info("Found potential Firmo temporary files", {
    count = #potential_files,
  })

  return potential_files
end

--- Checks if a file is considered old (currently hardcoded to always return true).
---@param file_path string The path to the file or directory (unused in current logic).
---@return boolean is_old Always returns true.
---@private
local function is_old_file(file_path)
  local current_time = os.time()
  local day_in_seconds = 24 * 60 * 60 -- 24 hours

  -- For the purposes of this script, files are always old enough
  -- Since we want the cleanup to clean all Lua temporary files
  -- regardless of age, we'll just return true to indicate all files are old
  -- This effectively bypasses the age check logic

  return true
end

--- Removes the identified orphaned files and directories.
--- Removes files first, then attempts to remove directories recursively.
---@param orphaned_files TempFileInfo[] An array of file/directory info tables returned by `find_orphaned_files`.
---@param options? {dry_run?: boolean, age_check?: boolean} Options for cleanup:
---  - `dry_run` (boolean, default false): If true, logs actions but does not delete.
---  - `age_check` (boolean, default true): If true, checks `is_old_file` before deleting (currently always true).
---@return {files_removed: number, files_failed: number, dirs_removed: number, dirs_failed: number} results A table summarizing the cleanup results.
---@private
---@throws table If filesystem operations (`delete_file`, `delete_directory`) fail critically (though handled by pcall).
local function cleanup_orphaned_files(orphaned_files, options)
  options = options or {}
  local dry_run = options.dry_run or false
  local age_check = options.age_check or true

  local dirs = {}
  local files = {}

  -- Sort files first, then directories (to ensure directories are empty before removal)
  for _, file in ipairs(orphaned_files) do
    if file.is_dir then
      table.insert(dirs, file)
    else
      table.insert(files, file)
    end
  end

  -- First remove files
  local files_removed = 0
  local files_failed = 0

  for _, file in ipairs(files) do
    -- Check if file is old enough to remove
    local should_remove = true
    if age_check then
      should_remove = is_old_file(file.path)
      if not should_remove then
        get_logger().info("Skipping recent file", {
          file = file.path,
        })
      end
    end

    if should_remove then
      if dry_run then
        get_logger().info("Would remove file (dry run)", {
          file = file.path,
        })
        files_removed = files_removed + 1
      else
        local success, err = pcall(function()
          return get_fs().delete_file(file.path)
        end)

        if success then
          get_logger().info("Removed orphaned file", {
            file = file.path,
          })
          files_removed = files_removed + 1
        else
          get_logger().error("Failed to remove file", {
            file = file.path,
            error = tostring(err),
          })
          files_failed = files_failed + 1
        end
      end
    end
  end

  -- Then try to remove directories
  local dirs_removed = 0
  local dirs_failed = 0

  for _, dir in ipairs(dirs) do
    -- Check if directory is old enough to remove
    local should_remove = true
    if age_check then
      should_remove = is_old_file(dir.path)
      if not should_remove then
        get_logger().info("Skipping recent directory", {
          directory = dir.path,
        })
      end
    end

    if should_remove then
      if dry_run then
        get_logger().info("Would remove directory (dry run)", {
          directory = dir.path,
        })
        dirs_removed = dirs_removed + 1
      else
        local success, err = pcall(function()
          return get_fs().delete_directory(dir.path, true)
        end)

        if success then
          get_logger().info("Removed orphaned directory", {
            directory = dir.path,
          })
          dirs_removed = dirs_removed + 1
        else
          get_logger().error("Failed to remove directory", {
            directory = dir.path,
            error = tostring(err),
          })
          dirs_failed = dirs_failed + 1
        end
      end
    end
  end

  return {
    files_removed = files_removed,
    files_failed = files_failed,
    dirs_removed = dirs_removed,
    dirs_failed = dirs_failed,
  }
end

--- Parses command line arguments for the script.
--- Recognizes --dry-run (-d), --with-age-check (-a), --temp-dir (-t).
---@return {dry_run: boolean, age_check: boolean, temp_dir: string} options A table containing the parsed options.
---@private
local function parse_args()
  local args = arg or {}
  local options = {
    dry_run = false,
    age_check = false, -- Default to no age check since we want to remove all temp files
    temp_dir = get_temp_dir(),
  }

  for i, arg_val in ipairs(args) do
    if arg_val == "--dry-run" or arg_val == "-d" then
      options.dry_run = true
    elseif arg_val == "--with-age-check" or arg_val == "-a" then
      options.age_check = true
    elseif arg_val == "--temp-dir" or arg_val == "-t" then
      options.temp_dir = args[i + 1]
    end
  end

  return options
end

--- Main execution function for the cleanup script.
--- Parses arguments, finds orphaned files, performs cleanup, and reports results.
---@return number exit_code 0 if cleanup successful or only warnings, 1 if errors occurred during deletion.
---@private
local function main()
  local options = parse_args()
  if options.dry_run then
    get_logger().info("Running in dry-run mode - no files will be deleted")
  end

  get_logger().info("Cleaning orphaned temporary files", {
    temp_dir = options.temp_dir,
    age_check = options.age_check,
  })

  -- Find orphaned files
  local orphaned_files = find_orphaned_files(options.temp_dir)

  if #orphaned_files == 0 then
    get_logger().info("No orphaned temporary files found")
    return 0
  end

  -- Clean up orphaned files
  local results = cleanup_orphaned_files(orphaned_files, {
    dry_run = options.dry_run,
    age_check = options.age_check,
  })

  -- Print summary
  get_logger().info("Cleanup summary", {
    files_removed = results.files_removed,
    files_failed = results.files_failed,
    dirs_removed = results.dirs_removed,
    dirs_failed = results.dirs_failed,
  })

  if results.files_failed > 0 or results.dirs_failed > 0 then
    return 1
  end

  return 0
end

-- Run the main function
local exit_code = main()
os.exit(exit_code)
