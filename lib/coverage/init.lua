--- Coverage module for firmo
-- Integrates LuaCov's debug hook system with firmo's ecosystem
-- @module coverage

local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

-- Module constants for better performance and clarity
local STATS_FILE_HEADER = "FIRMO_COVERAGE_1.0\n"
local MAX_BUFFER_SIZE = 10000
local MIN_SAVE_INTERVAL = 50
local DEFAULT_SAVE_STEPS = 100

local coverage = {}

-- Register with central_config
central_config.register_module("coverage", {
  -- Schema definition
  field_types = {
    enabled = "boolean",
    include = "table",
    exclude = "table",
    statsfile = "string",
    savestepsize = "number",
    tick = "boolean",
    codefromstrings = "boolean",
    threshold = "number",
  },
}, {
  -- Default values
  enabled = true,
  include = { ".*%.lua$" }, -- Include all Lua files by default
  exclude = {}, -- No excludes by default
  statsfile = ".coverage-stats",
  savestepsize = 100, -- Save stats every 100 lines
  tick = false, -- Don't use tick-based saving by default
  codefromstrings = false, -- Don't track code loaded from strings
  threshold = 90, -- Default coverage threshold percentage
})

-- Module state with optimized structure
local state = {
  initialized = false,
  data = {}, -- Coverage data by filename
  paused = true, -- Start paused
  buffer = { -- Performance optimization buffer
    size = 0,
    changes = 0,
    last_save = os.time(),
  },
}

-- Fast lookup tables for better performance
local ignored_files = {}
local file_patterns = {
  include = {},
  exclude = {},
}

-- Precompile patterns for better performance
local function compile_patterns()
  local config = central_config.get("coverage")
  if not config then
    return
  end

  -- Clear existing patterns
  file_patterns.include = {}
  file_patterns.exclude = {}

  -- Compile include patterns
  for _, pattern in ipairs(config.include or {}) do
    table.insert(file_patterns.include, {
      raw = pattern,
      compiled = pattern,
    })
  end

  -- Compile exclude patterns
  for _, pattern in ipairs(config.exclude or {}) do
    table.insert(file_patterns.exclude, {
      raw = pattern,
      compiled = pattern,
    })
  end
end

-- Optimized file pattern matching
local function should_track_file(filename)
  -- Quick lookup for previously checked files
  if ignored_files[filename] then
    return false
  end

  -- Check include patterns
  local included = #file_patterns.include == 0 -- Include all if no patterns
  for _, pattern in ipairs(file_patterns.include) do
    if filename:match(pattern.compiled) then
      included = true
      break
    end
  end

  -- Check exclude patterns if included
  if included then
    for _, pattern in ipairs(file_patterns.exclude) do
      if filename:match(pattern.compiled) then
        ignored_files[filename] = true
        return false
      end
    end
  end

  return included
end

-- Optimized debug hook function
local function debug_hook(_, line_nr, level)
  -- Skip if not initialized or paused
  if not state.initialized or state.paused then
    return
  end

  level = level or 2

  -- Get source file info
  local info = debug.getinfo(level, "S")
  if not info then
    return
  end

  local name = info.source
  local prefixed_name = name:match("^@(.*)")

  if prefixed_name then
    name = filesystem.normalize_path(prefixed_name)
  elseif not central_config.get("coverage.codefromstrings") then
    return -- Skip code from strings unless enabled
  end

  -- Get or create file data with buffering
  local file = state.data[name]
  if not file then
    -- Check if we should track this file
    if not should_track_file(name) then
      ignored_files[name] = true
      return
    end

    file = {
      max = 0,
      max_hits = 0,
    }
    state.data[name] = file
    state.buffer.changes = state.buffer.changes + 1
  end

  -- Update line stats
  if line_nr > file.max then
    file.max = line_nr
  end

  local hits = (file[line_nr] or 0) + 1
  file[line_nr] = hits

  if hits > file.max_hits then
    file.max_hits = hits
  end

  -- Update buffer stats
  state.buffer.size = state.buffer.size + 1
  state.buffer.changes = state.buffer.changes + 1

  -- Check if we should save stats
  local config = central_config.get("coverage")
  if config and config.tick and state.buffer.changes >= (config.savestepsize or DEFAULT_SAVE_STEPS) then
    coverage.save_stats()
    state.buffer.changes = 0
    state.buffer.last_save = os.time()
  elseif state.buffer.size >= MAX_BUFFER_SIZE then
    coverage.save_stats()
    state.buffer.size = 0
  end
end

-- Initialize coverage system
function coverage.init()
  if state.initialized then
    return true
  end

  local success, err = error_handler.try(function()
    -- Set debug hook
    debug.sethook(debug_hook, "l", 0)

    -- Handle hook per thread if needed
    if coverage.has_hook_per_thread() then
      -- Patch coroutine.create
      local raw_create = coroutine.create
      coroutine.create = function(...)
        local co = raw_create(...)
        debug.sethook(co, debug_hook, "l", 0)
        return co
      end

      -- Patch coroutine.wrap
      local raw_wrap = coroutine.wrap
      coroutine.wrap = function(...)
        local co = raw_create(...)
        debug.sethook(co, debug_hook, "l", 0)
        return function(...)
          local success, result = coroutine.resume(co, ...)
          if not success then
            error(result, 0)
          end
          return result
        end
      end
    end

    -- Initialize tracking state
    state.initialized = true
    state.paused = false
    state.data = {}
    state.buffer = {
      size = 0,
      changes = 0,
      last_save = os.time(),
    }

    -- Clear lookup tables
    ignored_files = {}

    -- Compile patterns from config
    compile_patterns()

    return true
  end)

  if not success then
    error_handler.throw(
      "Failed to initialize coverage system: " .. err.message,
      error_handler.CATEGORY.RUNTIME,
      error_handler.SEVERITY.ERROR,
      { error = err }
    )
    return false
  end

  return true
end

-- Check if debug hooks are per-thread
function coverage.has_hook_per_thread()
  -- Get current hook with all parameters
  local old_hook, old_mask, old_count = debug.gethook()

  -- Set a test hook
  local test_hook = function() end
  debug.sethook(test_hook, "l", 0)

  -- Check if hook is same in new thread
  local thread_hook = coroutine.wrap(function()
    return debug.gethook()
  end)()

  -- Restore original hook with proper parameters
  if old_hook then
    debug.sethook(old_hook, old_mask or "", old_count or 0)
  else
    debug.sethook()
  end

  -- Different hooks means per-thread hooks
  return thread_hook ~= test_hook
end

-- Pause coverage collection
function coverage.pause()
  state.paused = true
end

-- Resume coverage collection
function coverage.resume()
  state.paused = false
end

--- Save collected coverage statistics to a file
-- @return boolean success Whether stats were saved successfully
-- @return string|nil error Error message if saving failed
function coverage.save_stats()
  -- Always try to save stats even if buffer is small
  if state.buffer.size == 0 and state.buffer.changes == 0 then
    return true -- Nothing to save
  end

  -- Get config
  local config = central_config.get("coverage")
  if not config then
    return false, "Coverage configuration not found"
  end

  local statsfile = config.statsfile
  if not statsfile then
    return false, "Stats file path not configured"
  end

  -- Use temp file for atomic write with automatic cleanup
  local result, err = temp_file.with_temp_file("", function(temp_stats)
    -- Write file header
    local ok, write_err = filesystem.write_file(temp_stats, STATS_FILE_HEADER)
    if not ok then
      return false, write_err
    end

    -- Load existing stats if they exist
    local old_stats = coverage.load_stats() or {}

    -- Merge current stats with old stats
    for name, data in pairs(state.data) do
      old_stats[name] = old_stats[name] or {}
      local file_data = old_stats[name]

      -- Update file stats
      file_data.max = math.max(file_data.max or 0, data.max or 0)
      file_data.max_hits = math.max(file_data.max_hits or 0, data.max_hits or 0)

      -- Merge line hits
      for line, hits in pairs(data) do
        if type(line) == "number" then
          file_data[line] = (file_data[line] or 0) + hits
        end
      end
    end

    -- Sort filenames for consistent output
    local filenames = {}
    for name in pairs(old_stats) do
      table.insert(filenames, name)
    end
    table.sort(filenames)

    local content = {}
    for _, name in ipairs(filenames) do
      local file_data = old_stats[name]
      table.insert(content, string.format("%d:%s\n", file_data.max, name))

      local line_stats = {}
      for i = 1, file_data.max do
        table.insert(line_stats, tostring(file_data[i] or 0))
      end
      table.insert(content, table.concat(line_stats, " ") .. "\n")
    end

    -- Write to temp file
    local ok, write_err = filesystem.write_file(temp_stats, table.concat(content))
    if not ok then
      return false, write_err
    end

    -- Move temp file to final location
    local move_ok, move_err = filesystem.move_file(temp_stats, statsfile)
    if not move_ok then
      return false, move_err
    end

    return true
  end, "coverage-stats")

  if not result then
    return false, err or "Failed to save coverage stats"
  end
  -- Clear current data
  state.data = {}

  return true
end

-- Load coverage stats from file
function coverage.load_stats()
  local statsfile = central_config.get("coverage.statsfile")

  -- Check if stats file exists
  if not filesystem.file_exists(statsfile) then
    return nil
  end

  -- Read stats file content
  local content, read_err = filesystem.read_file(statsfile)
  if not content then
    error_handler.throw(
      "Failed to read coverage stats: " .. (read_err or "unknown error"),
      error_handler.CATEGORY.IO,
      error_handler.SEVERITY.ERROR
    )
    return nil
  end

  local stats = {}

  -- Process file content line by line
  local lines = {}
  for line in content:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  local i = 1
  while i <= #lines do
    -- Parse header line
    local max, filename = lines[i]:match("(%d+):(.*)")
    if not max or not filename then
      break
    end
    max = tonumber(max)

    -- Move to data line
    i = i + 1
    if i > #lines then
      break
    end

    -- Initialize file stats
    stats[filename] = {
      max = max,
      max_hits = 0,
    }

    -- Parse line hits
    local hits = {}
    for hit in lines[i]:gmatch("%d+") do
      table.insert(hits, tonumber(hit))
    end

    -- Store non-zero hits
    for line_nr, hit_count in ipairs(hits) do
      if hit_count > 0 then
        stats[filename][line_nr] = hit_count
        stats[filename].max_hits = math.max(stats[filename].max_hits, hit_count)
      end
    end

    i = i + 1
  end

  return stats
end

-- Clean shutdown
function coverage.shutdown()
  if state.initialized then
    coverage.save_stats()
    debug.sethook()
    state.initialized = false
    state.paused = true
  end
end

-- Start coverage collection
function coverage.start()
  -- Initialize if not already done
  if not coverage.init() then
    return false
  end
  
  -- Resume collection
  coverage.resume()
  return true
end

-- Stop coverage collection
function coverage.stop()
  -- Save any remaining stats
  coverage.save_stats()
  
  -- Pause collection
  coverage.pause()
  
  -- Perform full shutdown
  coverage.shutdown()
  
  return true
end

return coverage
