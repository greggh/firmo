#!/usr/bin/env lua
--- Monitor Temporary Files Script
---
--- Monitors the system's temporary directory at regular intervals, counting the number
--- of files and directories matching a specified pattern (default: `firmo_test`)
--- and calculating their total size. Logs results to a CSV file.
---
--- Usage: lua scripts/monitor_temp_files.lua [options]
---
--- Options:
---   --interval=seconds    Seconds between checks (default: 2)
---   --temp-dir=/path      Path to temporary directory (default: /tmp)
---   --pattern=pattern     File pattern to search for (default: firmo_test)
---   --max-runtime=seconds Maximum runtime in seconds (default: 300)
---   --output=filename     Output log file (default: temp_file_monitor.log)
---   --help, -h            Show this help message
---
--- @author Firmo Team
--- @version 1.0.0
--- @script

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

--- Script configuration settings, initialized with defaults and updated by command-line arguments.
---@type {interval: number, temp_dir: string, pattern: string, max_runtime: number, output_file: string}
local settings = {
  interval = 2, -- seconds between checks
  temp_dir = "/tmp", -- default temp directory
  pattern = "firmo_test", -- file pattern to look for
  max_runtime = 300, -- maximum runtime in seconds
  output_file = "temp_file_monitor.log",
}

-- Parse command line arguments
for i = 1, #arg do
  local param = arg[i]
  if param:match("^%-%-interval=") then
    settings.interval = tonumber(param:match("^%-%-interval=(.+)"))
  elseif param:match("^%-%-temp%-dir=") then
    settings.temp_dir = param:match("^%-%-temp%-dir=(.+)")
  elseif param:match("^%-%-pattern=") then
    settings.pattern = param:match("^%-%-pattern=(.+)")
  elseif param:match("^%-%-max%-runtime=") then
    settings.max_runtime = tonumber(param:match("^%-%-max%-runtime=(.+)"))
  elseif param:match("^%-%-output=") then
    settings.output_file = param:match("^%-%-output=(.+)")
  elseif param == "--help" or param == "-h" then
    print("Usage: lua scripts/monitor_temp_files.lua [options]")
    print("Options:")
    print("  --interval=seconds    Seconds between checks (default: 2)")
    print("  --temp-dir=/path      Path to temporary directory (default: /tmp)")
    print("  --pattern=pattern     File pattern to search for (default: firmo_test)")
    print("  --max-runtime=seconds Maximum runtime in seconds (default: 300)")
    print("  --output=filename     Output log file (default: temp_file_monitor.log)")
    print("  --help, -h            Show this help message")
    os.exit(0)
  end
end

print("Monitoring temporary files with pattern '" .. settings.pattern .. "' in " .. settings.temp_dir)
print("Interval: " .. settings.interval .. " seconds, Max runtime: " .. settings.max_runtime .. " seconds")
print("Output file: " .. settings.output_file)
print("Press Ctrl+C to stop monitoring")

-- Initialize log file
local log_file = io.open(settings.output_file, "w")
if not log_file then
  print("Error: Unable to open output file for writing: " .. settings.output_file)
  os.exit(1)
end

log_file:write("Timestamp,Files,Directories,Total Size (bytes)\n")
log_file:flush()

--- Counts files and directories in the temporary directory that match the configured pattern
--- and calculates their total size.
---@return number file_count Number of matching files found.
---@return number dir_count Number of matching directories found.
---@return number total_size Total size in bytes of the matching files.
---@return string? error Error message if listing the directory failed.
---@private
local function count_temp_resources()
  local file_count = 0
  local dir_count = 0
  local total_size = 0

  -- List all entries in the temp directory
  local entries, err = get_fs().get_directory_contents(settings.temp_dir)
  if not entries then
    return 0, 0, 0, "Failed to list directory: " .. tostring(err)
  end

  -- Count matching files and directories
  for _, entry in ipairs(entries) do
    local full_path = settings.temp_dir .. "/" .. entry

    if entry:match(settings.pattern) then
      if get_fs().file_exists(full_path) then
        file_count = file_count + 1
        local size = get_fs().get_file_size(full_path) or 0
        total_size = total_size + size
      elseif get_fs().directory_exists(full_path) then
        dir_count = dir_count + 1
      end
    end
  end

  return file_count, dir_count, total_size
end

-- Monitor loop
local start_time = os.time()
local run_time = 0

while run_time < settings.max_runtime do
  -- Count resources
  local files, dirs, size, err = count_temp_resources()
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")

  if err then
    print(timestamp .. " ERROR: " .. err)
    log_file:write(timestamp .. ",ERROR,ERROR,ERROR," .. err .. "\n")
  else
    -- Print current status
    print(string.format("%s - Files: %d, Directories: %d, Total size: %.2f KB", timestamp, files, dirs, size / 1024))

    -- Log to file
    log_file:write(string.format("%s,%d,%d,%d\n", timestamp, files, dirs, size))
  end

  log_file:flush()

  -- Sleep for the specified interval
  os.execute("sleep " .. settings.interval)

  -- Update runtime
  run_time = os.difftime(os.time(), start_time)
end

log_file:close()
print("Monitoring completed after " .. run_time .. " seconds.")
print("Results saved to " .. settings.output_file)
