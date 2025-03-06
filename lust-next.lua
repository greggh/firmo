-- lust-next v0.7.0 - Enhanced Lua test framework
-- https://github.com/greggh/lust-next
-- MIT LICENSE
-- Based on lust by Bjorn Swenson (https://github.com/bjornbytes/lust)
--
-- Features:
-- * BDD-style nested test blocks (describe/it)
-- * Assertions with detailed error messages
-- * Setup and teardown with before/after hooks
-- * Advanced mocking and spying system
-- * Tag-based filtering for selective test execution
-- * Focus mode for running only specific tests (fdescribe/fit)
-- * Skip mode for excluding tests (xdescribe/xit)
-- * Asynchronous testing support
-- * Code coverage analysis and reporting

-- Try to require optional modules
local function try_require(name)
  local ok, mod = pcall(require, name)
  if ok then
    return mod
  else
    return nil
  end
end

-- Optional coverage module
local coverage = try_require("src.coverage")
-- Also try to load the JSON module needed for coverage reporting
local json = try_require("src.json")

local lust_next = {}
lust_next.level = 0
lust_next.passes = 0
lust_next.errors = 0
lust_next.befores = {}
lust_next.afters = {}
lust_next.version = "0.7.0"
lust_next.active_tags = {}
lust_next.current_tags = {}
lust_next.filter_pattern = nil
lust_next.running_async = false
lust_next.async_timeout = 5000 -- Default timeout in ms
lust_next.focus_mode = false -- Tracks if any focused tests are present

-- Coverage options
lust_next.coverage_options = {
  enabled = false,            -- Whether coverage is enabled
  include = {".*%.lua$"},     -- Files to include in coverage
  exclude = {"test_", "_spec%.lua$", "_test%.lua$"}, -- Files to exclude
  threshold = 80,             -- Coverage threshold percentage
  format = "summary",         -- Report format (summary, json, html, lcov)
  output = nil,               -- Output file path (nil for console)
}

-- Output formatting options
lust_next.format_options = {
  use_color = true,          -- Whether to use color codes in output
  indent_char = '\t',        -- Character to use for indentation (tab or spaces)
  indent_size = 1,           -- How many indent_chars to use per level
  show_trace = false,        -- Show stack traces for errors
  show_success_detail = true, -- Show details for successful tests
  compact = false,           -- Use compact output format (less verbose)
  dot_mode = false,          -- Use dot mode (. for pass, F for fail)
  summary_only = false       -- Show only summary, not individual tests
}

-- Set up colors based on format options
local red = string.char(27) .. '[31m'
local green = string.char(27) .. '[32m'
local yellow = string.char(27) .. '[33m'
local blue = string.char(27) .. '[34m'
local magenta = string.char(27) .. '[35m'
local cyan = string.char(27) .. '[36m'
local normal = string.char(27) .. '[0m'

-- Helper function for indentation with configurable char and size
local function indent(level) 
  level = level or lust_next.level
  local indent_char = lust_next.format_options.indent_char
  local indent_size = lust_next.format_options.indent_size
  return string.rep(indent_char, level * indent_size) 
end

-- Disable colors (for non-terminal output or color-blind users)
function lust_next.nocolor()
  lust_next.format_options.use_color = false
  red, green, yellow, blue, magenta, cyan, normal = '', '', '', '', '', '', ''
  return lust_next
end

-- Configure output formatting options
function lust_next.format(options)
  for k, v in pairs(options) do
    if lust_next.format_options[k] ~= nil then
      lust_next.format_options[k] = v
    else
      error("Unknown format option: " .. k)
    end
  end
  
  -- Update colors if needed
  if not lust_next.format_options.use_color then
    lust_next.nocolor()
  else
    red = string.char(27) .. '[31m'
    green = string.char(27) .. '[32m'
    yellow = string.char(27) .. '[33m'
    blue = string.char(27) .. '[34m'
    magenta = string.char(27) .. '[35m'
    cyan = string.char(27) .. '[36m'
    normal = string.char(27) .. '[0m'
  end
  
  return lust_next
end

-- The main describe function with support for focus and exclusion
function lust_next.describe(name, fn, options)
  options = options or {}
  local focused = options.focused or false
  local excluded = options.excluded or false
  
  -- If this is a focused describe block, mark that we're in focus mode
  if focused then
    lust_next.focus_mode = true
  end
  
  -- Only print in non-summary mode and non-dot mode
  if not lust_next.format_options.summary_only and not lust_next.format_options.dot_mode then
    -- Print description with appropriate formatting
    if excluded then
      print(indent() .. yellow .. "SKIP" .. normal .. " " .. name)
    else
      local prefix = focused and cyan .. "FOCUS " .. normal or ""
      print(indent() .. prefix .. name)
    end
  end
  
  -- If excluded, don't execute the function
  if excluded then
    return
  end
  
  lust_next.level = lust_next.level + 1
  
  -- Save current tags and focus state to restore them after the describe block
  local prev_tags = {}
  for i, tag in ipairs(lust_next.current_tags) do
    prev_tags[i] = tag
  end
  
  -- Store the current focus state at this level
  local prev_focused = options._parent_focused or focused
  
  -- Run the function with updated context
  local success, err = pcall(function()
    fn()
  end)
  
  -- Reset current tags to what they were before the describe block
  lust_next.current_tags = prev_tags
  
  lust_next.befores[lust_next.level] = {}
  lust_next.afters[lust_next.level] = {}
  lust_next.level = lust_next.level - 1
  
  -- If there was an error in the describe block, report it
  if not success then
    lust_next.errors = lust_next.errors + 1
    
    if not lust_next.format_options.summary_only then
      print(indent() .. red .. "ERROR" .. normal .. " in describe '" .. name .. "'")
      
      if lust_next.format_options.show_trace then
        -- Show the full stack trace
        print(indent(lust_next.level + 1) .. red .. debug.traceback(err, 2) .. normal)
      else
        -- Show just the error message
        print(indent(lust_next.level + 1) .. red .. tostring(err) .. normal)
      end
    elseif lust_next.format_options.dot_mode then
      -- In dot mode, print an 'E' for error
      io.write(red .. "E" .. normal)
    end
  end
end

-- Focused version of describe
function lust_next.fdescribe(name, fn)
  return lust_next.describe(name, fn, {focused = true})
end

-- Excluded version of describe
function lust_next.xdescribe(name, fn)
  -- Use an empty function to ensure none of the tests within it ever run
  -- This is more robust than just marking it excluded
  return lust_next.describe(name, function() end, {excluded = true})
end

-- Set tags for the current describe block or test
function lust_next.tags(...)
  local tags = {...}
  lust_next.current_tags = tags
  return lust_next
end

-- Filter tests to only run those matching specific tags
function lust_next.only_tags(...)
  local tags = {...}
  lust_next.active_tags = tags
  return lust_next
end

-- Filter tests by name pattern
function lust_next.filter(pattern)
  lust_next.filter_pattern = pattern
  return lust_next
end

-- Reset all filters
function lust_next.reset_filters()
  lust_next.active_tags = {}
  lust_next.filter_pattern = nil
  return lust_next
end

-- Check if a test should run based on tags and pattern filtering
local function should_run_test(name, tags)
  -- If no filters are set, run everything
  if #lust_next.active_tags == 0 and not lust_next.filter_pattern then
    return true
  end

  -- Check pattern filter
  if lust_next.filter_pattern and not name:match(lust_next.filter_pattern) then
    return false
  end
  
  -- If we have tags filter but no tags on this test, skip it
  if #lust_next.active_tags > 0 and #tags == 0 then
    return false
  end
  
  -- Check tag filters
  if #lust_next.active_tags > 0 then
    for _, activeTag in ipairs(lust_next.active_tags) do
      for _, testTag in ipairs(tags) do
        if activeTag == testTag then
          return true
        end
      end
    end
    return false
  end
  
  return true
end

function lust_next.it(name, fn, options)
  options = options or {}
  local focused = options.focused or false
  local excluded = options.excluded or false
  
  -- If this is a focused test, mark that we're in focus mode
  if focused then
    lust_next.focus_mode = true
  end
  
  -- Save current tags for this test
  local test_tags = {}
  for _, tag in ipairs(lust_next.current_tags) do
    table.insert(test_tags, tag)
  end
  
  -- Determine if this test should be run
  -- Skip if:
  -- 1. It's explicitly excluded, or
  -- 2. Focus mode is active but this test is not focused, or
  -- 3. It doesn't match the filter pattern or tags
  local should_skip = excluded or
                     (lust_next.focus_mode and not focused) or
                     (not should_run_test(name, test_tags))
  
  if should_skip then
    -- Skip test but still print it as skipped
    lust_next.skipped = lust_next.skipped + 1
    
    if not lust_next.format_options.summary_only and not lust_next.format_options.dot_mode then
      local skip_reason = ""
      if excluded then
        skip_reason = " (excluded)"
      elseif lust_next.focus_mode and not focused then
        skip_reason = " (not focused)"
      end
      print(indent() .. yellow .. 'SKIP' .. normal .. ' ' .. name .. skip_reason)
    elseif lust_next.format_options.dot_mode then
      -- In dot mode, print an 'S' for skipped
      io.write(yellow .. "S" .. normal)
    end
    return
  end
  
  -- Run before hooks
  for level = 1, lust_next.level do
    if lust_next.befores[level] then
      for i = 1, #lust_next.befores[level] do
        lust_next.befores[level][i](name)
      end
    end
  end

  -- Handle both regular and async tests (returned from lust_next.async())
  local success, err
  if type(fn) == "function" then
    success, err = pcall(fn)
  else
    -- If it's not a function, it might be the result of an async test that already completed
    success, err = true, fn
  end
  
  if success then 
    lust_next.passes = lust_next.passes + 1 
  else 
    lust_next.errors = lust_next.errors + 1 
  end
  
  -- Output based on format options
  if lust_next.format_options.dot_mode then
    -- In dot mode, just print a dot for pass, F for fail
    if success then
      io.write(green .. "." .. normal)
    else
      io.write(red .. "F" .. normal)
    end
  elseif not lust_next.format_options.summary_only then 
    -- Full output mode
    local color = success and green or red
    local label = success and 'PASS' or 'FAIL'
    local prefix = focused and cyan .. "FOCUS " .. normal or ""
    
    -- Only show successful tests details if configured to do so
    if success and not lust_next.format_options.show_success_detail then
      if not lust_next.format_options.compact then
        print(indent() .. color .. "." .. normal)
      end
    else
      print(indent() .. color .. label .. normal .. ' ' .. prefix .. name)
    end
    
    -- Show error details
    if err and not success then
      if lust_next.format_options.show_trace then
        -- Show the full stack trace
        print(indent(lust_next.level + 1) .. red .. debug.traceback(err, 2) .. normal)
      else
        -- Show just the error message
        print(indent(lust_next.level + 1) .. red .. tostring(err) .. normal)
      end
    end
  end
  
  -- Run after hooks
  for level = 1, lust_next.level do
    if lust_next.afters[level] then
      for i = 1, #lust_next.afters[level] do
        lust_next.afters[level][i](name)
      end
    end
  end
  
  -- Clear current tags after test
  lust_next.current_tags = {}
end

-- Focused version of it
function lust_next.fit(name, fn)
  return lust_next.it(name, fn, {focused = true})
end

-- Excluded version of it
function lust_next.xit(name, fn)
  -- Important: Replace the function with a dummy that never runs
  -- This ensures the test is completely skipped, not just filtered
  return lust_next.it(name, function() end, {excluded = true})
end

function lust_next.before(fn)
  lust_next.befores[lust_next.level] = lust_next.befores[lust_next.level] or {}
  table.insert(lust_next.befores[lust_next.level], fn)
end

function lust_next.after(fn)
  lust_next.afters[lust_next.level] = lust_next.afters[lust_next.level] or {}
  table.insert(lust_next.afters[lust_next.level], fn)
end

-- Assertions
local function isa(v, x)
  if type(x) == 'string' then
    return type(v) == x,
      'expected ' .. tostring(v) .. ' to be a ' .. x,
      'expected ' .. tostring(v) .. ' to not be a ' .. x
  elseif type(x) == 'table' then
    if type(v) ~= 'table' then
      return false,
        'expected ' .. tostring(v) .. ' to be a ' .. tostring(x),
        'expected ' .. tostring(v) .. ' to not be a ' .. tostring(x)
    end

    local seen = {}
    local meta = v
    while meta and not seen[meta] do
      if meta == x then return true end
      seen[meta] = true
      meta = getmetatable(meta) and getmetatable(meta).__index
    end

    return false,
      'expected ' .. tostring(v) .. ' to be a ' .. tostring(x),
      'expected ' .. tostring(v) .. ' to not be a ' .. tostring(x)
  end

  error('invalid type ' .. tostring(x))
end

local function has(t, x)
  for k, v in pairs(t) do
    if v == x then return true end
  end
  return false
end

local function eq(t1, t2, eps)
  if type(t1) ~= type(t2) then return false end
  if type(t1) == 'number' then return math.abs(t1 - t2) <= (eps or 0) end
  if type(t1) ~= 'table' then return t1 == t2 end
  for k, _ in pairs(t1) do
    if not eq(t1[k], t2[k], eps) then return false end
  end
  for k, _ in pairs(t2) do
    if not eq(t2[k], t1[k], eps) then return false end
  end
  return true
end

-- Enhanced stringify function with better formatting for different types
local function stringify(t, depth)
  depth = depth or 0
  local indent_str = string.rep("  ", depth)
  
  -- Handle basic types directly
  if type(t) == 'string' then 
    return "'" .. tostring(t) .. "'" 
  elseif type(t) == 'number' or type(t) == 'boolean' or type(t) == 'nil' then
    return tostring(t)
  elseif type(t) ~= 'table' or (getmetatable(t) and getmetatable(t).__tostring) then 
    return tostring(t) 
  end
  
  -- Handle empty tables
  if next(t) == nil then
    return "{}"
  end
  
  -- Handle tables with careful formatting
  local strings = {}
  local multiline = false
  
  -- Format array part first
  for i, v in ipairs(t) do
    if type(v) == 'table' and next(v) ~= nil and depth < 2 then
      multiline = true
      strings[#strings + 1] = indent_str .. "  " .. stringify(v, depth + 1)
    else
      strings[#strings + 1] = stringify(v, depth + 1)
    end
  end
  
  -- Format hash part next
  local hash_entries = {}
  for k, v in pairs(t) do
    if type(k) ~= 'number' or k > #t or k < 1 then
      local key_str = type(k) == 'string' and k or '[' .. stringify(k, depth + 1) .. ']'
      
      if type(v) == 'table' and next(v) ~= nil and depth < 2 then
        multiline = true
        hash_entries[#hash_entries + 1] = indent_str .. "  " .. key_str .. " = " .. stringify(v, depth + 1)
      else
        hash_entries[#hash_entries + 1] = key_str .. " = " .. stringify(v, depth + 1)
      end
    end
  end
  
  -- Combine array and hash parts
  for _, entry in ipairs(hash_entries) do
    strings[#strings + 1] = entry
  end
  
  -- Format based on content complexity
  if multiline and depth == 0 then
    return "{\n  " .. table.concat(strings, ",\n  ") .. "\n" .. indent_str .. "}"
  elseif #strings > 5 or multiline then
    return "{ " .. table.concat(strings, ", ") .. " }"
  else
    return "{ " .. table.concat(strings, ", ") .. " }"
  end
end

-- Generate a simple diff between two values
local function diff_values(v1, v2)
  if type(v1) ~= 'table' or type(v2) ~= 'table' then
    return "Expected: " .. stringify(v2) .. "\nGot:      " .. stringify(v1)
  end
  
  local differences = {}
  
  -- Check for missing keys in v1
  for k, v in pairs(v2) do
    if v1[k] == nil then
      table.insert(differences, "Missing key: " .. stringify(k) .. " (expected " .. stringify(v) .. ")")
    elseif not eq(v1[k], v, 0) then
      table.insert(differences, "Different value for key " .. stringify(k) .. ":\n  Expected: " .. stringify(v) .. "\n  Got:      " .. stringify(v1[k]))
    end
  end
  
  -- Check for extra keys in v1
  for k, v in pairs(v1) do
    if v2[k] == nil then
      table.insert(differences, "Extra key: " .. stringify(k) .. " = " .. stringify(v))
    end
  end
  
  if #differences == 0 then
    return "Values appear equal but are not identical (may be due to metatable differences)"
  end
  
  return "Differences:\n  " .. table.concat(differences, "\n  ")
end

local paths = {
  [''] = { 'to', 'to_not' },
  to = { 'have', 'equal', 'be', 'exist', 'fail', 'match', 'contain', 'start_with', 'end_with', 'be_type', 'be_greater_than', 'be_less_than', 'be_between', 'be_approximately', 'throw' },
  to_not = { 'have', 'equal', 'be', 'exist', 'fail', 'match', 'contain', 'start_with', 'end_with', 'be_type', 'be_greater_than', 'be_less_than', 'be_between', 'be_approximately', 'throw', chain = function(a) a.negate = not a.negate end },
  a = { test = isa },
  an = { test = isa },
  be = { 'a', 'an', 'truthy',
    test = function(v, x)
      return v == x,
        'expected ' .. tostring(v) .. ' and ' .. tostring(x) .. ' to be the same',
        'expected ' .. tostring(v) .. ' and ' .. tostring(x) .. ' to not be the same'
    end
  },
  exist = {
    test = function(v)
      return v ~= nil,
        'expected ' .. tostring(v) .. ' to exist',
        'expected ' .. tostring(v) .. ' to not exist'
    end
  },
  truthy = {
    test = function(v)
      return v,
        'expected ' .. tostring(v) .. ' to be truthy',
        'expected ' .. tostring(v) .. ' to not be truthy'
    end
  },
  equal = {
    test = function(v, x, eps)
      local equal = eq(v, x, eps)
      local comparison = ''
      
      if not equal then
        if type(v) == 'table' or type(x) == 'table' then
          -- For tables, generate a detailed diff
          comparison = '\n' .. indent(lust_next.level + 1) .. diff_values(v, x)
        else
          -- For primitive types, show a simple comparison
          comparison = '\n' .. indent(lust_next.level + 1) .. 'Expected: ' .. stringify(x) 
                     .. '\n' .. indent(lust_next.level + 1) .. 'Got:      ' .. stringify(v)
        end
      end

      return equal,
        'Values are not equal: ' .. comparison,
        'expected ' .. stringify(v) .. ' and ' .. stringify(x) .. ' to not be equal'
    end
  },
  have = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. stringify(v) .. ' to be a table')
      end

      -- Create a formatted table representation for better error messages
      local table_str = stringify(v)
      local content_preview = #table_str > 70 
          and table_str:sub(1, 67) .. "..." 
          or table_str

      return has(v, x),
        'expected table to contain ' .. stringify(x) .. '\nTable contents: ' .. content_preview,
        'expected table not to contain ' .. stringify(x) .. ' but it was found\nTable contents: ' .. content_preview
    end
  },
  fail = { 'with',
    test = function(v)
      return not pcall(v),
        'expected ' .. tostring(v) .. ' to fail',
        'expected ' .. tostring(v) .. ' to not fail'
    end
  },
  with = {
    test = function(v, pattern)
      local ok, message = pcall(v)
      return not ok and message:match(pattern),
        'expected ' .. tostring(v) .. ' to fail with error matching "' .. pattern .. '"',
        'expected ' .. tostring(v) .. ' to not fail with error matching "' .. pattern .. '"'
    end
  },
  match = {
    test = function(v, p)
      if type(v) ~= 'string' then v = tostring(v) end
      local result = string.find(v, p)
      return result ~= nil,
        'expected ' .. v .. ' to match pattern [[' .. p .. ']]',
        'expected ' .. v .. ' to not match pattern [[' .. p .. ']]'
    end
  },
  
  -- New table assertions
  contain = { 'keys', 'values', 'key', 'value', 'subset', 'exactly',
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. tostring(v) .. ' to be a table')
      end
      
      -- Default behavior is to check if the value is in the table (similar to have)
      return has(v, x),
        'expected ' .. tostring(v) .. ' to contain ' .. tostring(x),
        'expected ' .. tostring(v) .. ' to not contain ' .. tostring(x)
    end
  },
  
  -- Check if a table contains all specified keys
  keys = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. tostring(v) .. ' to be a table')
      end
      
      if type(x) ~= 'table' then
        error('expected ' .. tostring(x) .. ' to be a table containing keys to check for')
      end
      
      for _, key in ipairs(x) do
        if v[key] == nil then
          return false, 
            'expected ' .. stringify(v) .. ' to contain key ' .. tostring(key),
            'expected ' .. stringify(v) .. ' to not contain key ' .. tostring(key)
        end
      end
      
      return true,
        'expected ' .. stringify(v) .. ' to contain keys ' .. stringify(x),
        'expected ' .. stringify(v) .. ' to not contain keys ' .. stringify(x)
    end
  },
  
  -- Check if a table contains a specific key
  key = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. tostring(v) .. ' to be a table')
      end
      
      return v[x] ~= nil,
        'expected ' .. stringify(v) .. ' to contain key ' .. tostring(x),
        'expected ' .. stringify(v) .. ' to not contain key ' .. tostring(x)
    end
  },
  
  -- Check if a table contains all specified values
  values = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. tostring(v) .. ' to be a table')
      end
      
      if type(x) ~= 'table' then
        error('expected ' .. tostring(x) .. ' to be a table containing values to check for')
      end
      
      local found = {}
      for _, val in ipairs(x) do
        found[val] = false
        for _, v_val in pairs(v) do
          if eq(val, v_val) then
            found[val] = true
            break
          end
        end
        
        if not found[val] then
          return false,
            'expected ' .. stringify(v) .. ' to contain value ' .. tostring(val),
            'expected ' .. stringify(v) .. ' to not contain value ' .. tostring(val)
        end
      end
      
      return true,
        'expected ' .. stringify(v) .. ' to contain values ' .. stringify(x),
        'expected ' .. stringify(v) .. ' to not contain values ' .. stringify(x)
    end
  },
  
  -- Check if a table contains a specific value
  value = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. tostring(v) .. ' to be a table')
      end
      
      for _, val in pairs(v) do
        if eq(val, x) then
          return true,
            'expected ' .. stringify(v) .. ' to contain value ' .. tostring(x),
            'expected ' .. stringify(v) .. ' to not contain value ' .. tostring(x)
        end
      end
      
      return false,
        'expected ' .. stringify(v) .. ' to contain value ' .. tostring(x),
        'expected ' .. stringify(v) .. ' to not contain value ' .. tostring(x)
    end
  },
  
  -- Check if a table is a subset of another table
  subset = {
    test = function(v, x)
      if type(v) ~= 'table' or type(x) ~= 'table' then
        error('both arguments must be tables')
      end
      
      for k, val in pairs(v) do
        if not eq(x[k], val) then
          return false,
            'expected ' .. stringify(v) .. ' to be a subset of ' .. stringify(x),
            'expected ' .. stringify(v) .. ' to not be a subset of ' .. stringify(x)
        end
      end
      
      return true,
        'expected ' .. stringify(v) .. ' to be a subset of ' .. stringify(x),
        'expected ' .. stringify(v) .. ' to not be a subset of ' .. stringify(x)
    end
  },
  
  -- Check if a table contains exactly the specified keys
  exactly = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. tostring(v) .. ' to be a table')
      end
      
      if type(x) ~= 'table' then
        error('expected ' .. tostring(x) .. ' to be a table containing expected keys')
      end
      
      -- Check if all keys in x are in v
      for _, key in ipairs(x) do
        if v[key] == nil then
          return false,
            'expected ' .. stringify(v) .. ' to contain exactly keys ' .. stringify(x) .. ' (missing ' .. tostring(key) .. ')',
            'expected ' .. stringify(v) .. ' to not contain exactly keys ' .. stringify(x)
        end
      end
      
      -- Check if all keys in v are in x
      local x_set = {}
      for _, key in ipairs(x) do
        x_set[key] = true
      end
      
      for k, _ in pairs(v) do
        if not x_set[k] then
          return false,
            'expected ' .. stringify(v) .. ' to contain exactly keys ' .. stringify(x) .. ' (unexpected ' .. tostring(k) .. ')',
            'expected ' .. stringify(v) .. ' to not contain exactly keys ' .. stringify(x)
        end
      end
      
      return true,
        'expected ' .. stringify(v) .. ' to contain exactly keys ' .. stringify(x),
        'expected ' .. stringify(v) .. ' to not contain exactly keys ' .. stringify(x)
    end
  },
  
  -- String assertions
  start_with = {
    test = function(v, x)
      if type(v) ~= 'string' then
        error('expected ' .. tostring(v) .. ' to be a string')
      end
      
      if type(x) ~= 'string' then
        error('expected ' .. tostring(x) .. ' to be a string')
      end
      
      return v:sub(1, #x) == x,
        'expected "' .. v .. '" to start with "' .. x .. '"',
        'expected "' .. v .. '" to not start with "' .. x .. '"'
    end
  },
  
  end_with = {
    test = function(v, x)
      if type(v) ~= 'string' then
        error('expected ' .. tostring(v) .. ' to be a string')
      end
      
      if type(x) ~= 'string' then
        error('expected ' .. tostring(x) .. ' to be a string')
      end
      
      return v:sub(-#x) == x,
        'expected "' .. v .. '" to end with "' .. x .. '"',
        'expected "' .. v .. '" to not end with "' .. x .. '"'
    end
  },
  
  -- Type checking assertions beyond the basic types
  be_type = { 'callable', 'comparable', 'iterable',
    test = function(v, expected_type)
      if expected_type == 'callable' then
        local is_callable = type(v) == 'function' or 
                           (type(v) == 'table' and getmetatable(v) and getmetatable(v).__call)
        return is_callable,
          'expected ' .. tostring(v) .. ' to be callable',
          'expected ' .. tostring(v) .. ' to not be callable'
      elseif expected_type == 'comparable' then
        local success = pcall(function() return v < v end)
        return success,
          'expected ' .. tostring(v) .. ' to be comparable',
          'expected ' .. tostring(v) .. ' to not be comparable'
      elseif expected_type == 'iterable' then
        local success = pcall(function() 
          for _ in pairs(v) do break end
        end)
        return success,
          'expected ' .. tostring(v) .. ' to be iterable',
          'expected ' .. tostring(v) .. ' to not be iterable'
      else
        error('unknown type check: ' .. tostring(expected_type))
      end
    end
  },
  
  -- Numeric comparison assertions
  be_greater_than = {
    test = function(v, x)
      if type(v) ~= 'number' then
        error('expected ' .. tostring(v) .. ' to be a number')
      end
      
      if type(x) ~= 'number' then
        error('expected ' .. tostring(x) .. ' to be a number')
      end
      
      return v > x,
        'expected ' .. tostring(v) .. ' to be greater than ' .. tostring(x),
        'expected ' .. tostring(v) .. ' to not be greater than ' .. tostring(x)
    end
  },
  
  be_less_than = {
    test = function(v, x)
      if type(v) ~= 'number' then
        error('expected ' .. tostring(v) .. ' to be a number')
      end
      
      if type(x) ~= 'number' then
        error('expected ' .. tostring(x) .. ' to be a number')
      end
      
      return v < x,
        'expected ' .. tostring(v) .. ' to be less than ' .. tostring(x),
        'expected ' .. tostring(v) .. ' to not be less than ' .. tostring(x)
    end
  },
  
  be_between = {
    test = function(v, min, max)
      if type(v) ~= 'number' then
        error('expected ' .. tostring(v) .. ' to be a number')
      end
      
      if type(min) ~= 'number' or type(max) ~= 'number' then
        error('expected min and max to be numbers')
      end
      
      return v >= min and v <= max,
        'expected ' .. tostring(v) .. ' to be between ' .. tostring(min) .. ' and ' .. tostring(max),
        'expected ' .. tostring(v) .. ' to not be between ' .. tostring(min) .. ' and ' .. tostring(max)
    end
  },
  
  be_approximately = {
    test = function(v, x, delta)
      if type(v) ~= 'number' then
        error('expected ' .. tostring(v) .. ' to be a number')
      end
      
      if type(x) ~= 'number' then
        error('expected ' .. tostring(x) .. ' to be a number')
      end
      
      delta = delta or 0.0001
      
      return math.abs(v - x) <= delta,
        'expected ' .. tostring(v) .. ' to be approximately ' .. tostring(x) .. ' (±' .. tostring(delta) .. ')',
        'expected ' .. tostring(v) .. ' to not be approximately ' .. tostring(x) .. ' (±' .. tostring(delta) .. ')'
    end
  },
  
  -- Enhanced error assertions
  throw = { 'error', 'error_matching', 'error_type',
    test = function(v)
      if type(v) ~= 'function' then
        error('expected ' .. tostring(v) .. ' to be a function')
      end
      
      local ok, err = pcall(v)
      return not ok, 
        'expected function to throw an error',
        'expected function to not throw an error'
    end
  },
  
  error = {
    test = function(v)
      if type(v) ~= 'function' then
        error('expected ' .. tostring(v) .. ' to be a function')
      end
      
      local ok, err = pcall(v)
      return not ok, 
        'expected function to throw an error',
        'expected function to not throw an error'
    end
  },
  
  error_matching = {
    test = function(v, pattern)
      if type(v) ~= 'function' then
        error('expected ' .. tostring(v) .. ' to be a function')
      end
      
      if type(pattern) ~= 'string' then
        error('expected pattern to be a string')
      end
      
      local ok, err = pcall(v)
      if ok then
        return false, 
          'expected function to throw an error matching pattern "' .. pattern .. '"',
          'expected function to not throw an error matching pattern "' .. pattern .. '"'
      end
      
      err = tostring(err)
      return err:match(pattern) ~= nil,
        'expected error "' .. err .. '" to match pattern "' .. pattern .. '"',
        'expected error "' .. err .. '" to not match pattern "' .. pattern .. '"'
    end
  },
  
  error_type = {
    test = function(v, expected_type)
      if type(v) ~= 'function' then
        error('expected ' .. tostring(v) .. ' to be a function')
      end
      
      local ok, err = pcall(v)
      if ok then
        return false,
          'expected function to throw an error of type ' .. tostring(expected_type),
          'expected function to not throw an error of type ' .. tostring(expected_type)
      end
      
      -- Try to determine the error type
      local error_type
      if type(err) == 'string' then
        error_type = 'string'
      elseif type(err) == 'table' then
        error_type = err.__name or 'table'
      else
        error_type = type(err)
      end
      
      return error_type == expected_type,
        'expected error of type ' .. error_type .. ' to be of type ' .. expected_type,
        'expected error of type ' .. error_type .. ' to not be of type ' .. expected_type
    end
  }
}

function lust_next.expect(v)
  local assertion = {}
  assertion.val = v
  assertion.action = ''
  assertion.negate = false

  setmetatable(assertion, {
    __index = function(t, k)
      if has(paths[rawget(t, 'action')], k) then
        rawset(t, 'action', k)
        local chain = paths[rawget(t, 'action')].chain
        if chain then chain(t) end
        return t
      end
      return rawget(t, k)
    end,
    __call = function(t, ...)
      if paths[t.action].test then
        local res, err, nerr = paths[t.action].test(t.val, ...)
        if assertion.negate then
          res = not res
          err = nerr or err
        end
        if not res then
          error(err or 'unknown failure', 2)
        end
      end
    end
  })

  return assertion
end

-- Mocking and Spy system
-- Global registry to track mocks for cleanup
local _mocks = {}

-- Helper function to check if a table is a mock
local function is_mock(obj)
  return type(obj) == "table" and obj._is_lust_mock == true
end

-- Helper function to register a mock for cleanup
local function register_mock(mock)
  table.insert(_mocks, mock)
  return mock
end

-- Helper function to restore all mocks
local function restore_all_mocks()
  for _, mock in ipairs(_mocks) do
    mock:restore()
  end
  _mocks = {}
end

-- Deep comparison of tables for equality
local function tables_equal(t1, t2)
  if type(t1) ~= "table" or type(t2) ~= "table" then
    return t1 == t2
  end
  
  -- Check each key-value pair in t1
  for k, v in pairs(t1) do
    if not tables_equal(v, t2[k]) then
      return false
    end
  end
  
  -- Check for any extra keys in t2
  for k, _ in pairs(t2) do
    if t1[k] == nil then
      return false
    end
  end
  
  return true
end

-- Convert value to string representation for error messages
local function value_to_string(value, max_depth)
  max_depth = max_depth or 3
  if max_depth < 0 then return "..." end
  
  if type(value) == "string" then
    return '"' .. value .. '"'
  elseif type(value) == "table" then
    if max_depth == 0 then return "{...}" end
    
    local parts = {}
    for k, v in pairs(value) do
      local key_str = type(k) == "string" and k or "[" .. tostring(k) .. "]"
      table.insert(parts, key_str .. " = " .. value_to_string(v, max_depth - 1))
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
  elseif type(value) == "function" then
    return "function(...)"
  else
    return tostring(value)
  end
end

-- Argument matcher system
lust_next.arg_matcher = {}

-- Base matcher class
local function create_matcher(match_fn, description)
  return {
    _is_matcher = true,
    match = match_fn,
    description = description,
    __matcher_value = true
  }
end

-- Match any value
function lust_next.arg_matcher.any()
  return create_matcher(function() return true end, "any value")
end

-- Type-based matchers
function lust_next.arg_matcher.string()
  return create_matcher(function(val) return type(val) == "string" end, "string value")
end

function lust_next.arg_matcher.number()
  return create_matcher(function(val) return type(val) == "number" end, "number value")
end

function lust_next.arg_matcher.boolean()
  return create_matcher(function(val) return type(val) == "boolean" end, "boolean value")
end

function lust_next.arg_matcher.table()
  return create_matcher(function(val) return type(val) == "table" end, "table value")
end

function lust_next.arg_matcher.func()
  return create_matcher(function(val) return type(val) == "function" end, "function value")
end

-- Table containing specific keys/values
function lust_next.arg_matcher.table_containing(partial)
  return create_matcher(function(val)
    if type(val) ~= "table" then return false end
    
    for k, v in pairs(partial) do
      if val[k] == nil then return false end
      
      -- If v is a matcher, use its match function
      if type(v) == "table" and v._is_matcher then
        if not v.match(val[k]) then return false end
      -- Otherwise do a direct comparison
      elseif val[k] ~= v then
        return false
      end
    end
    
    return true
  end, "table containing " .. value_to_string(partial))
end

-- Custom matcher with user-provided function
function lust_next.arg_matcher.custom(fn, description)
  return create_matcher(fn, description or "custom matcher")
end

-- Helper to check if value matches the matcher
local function matches_arg(expected, actual)
  -- If expected is a matcher, use its match function
  if type(expected) == "table" and expected._is_matcher then
    return expected.match(actual)
  end
  
  -- If both are tables, do deep comparison
  if type(expected) == "table" and type(actual) == "table" then
    return tables_equal(expected, actual)
  end
  
  -- Otherwise do direct comparison
  return expected == actual
end

-- Check if args match a set of expected args (with potential matchers)
local function args_match(expected_args, actual_args)
  if #expected_args ~= #actual_args then
    return false
  end
  
  for i, expected in ipairs(expected_args) do
    if not matches_arg(expected, actual_args[i]) then
      return false
    end
  end
  
  return true
end

-- Format args for error messages
local function format_args(args)
  local parts = {}
  for i, arg in ipairs(args) do
    if type(arg) == "table" and arg._is_matcher then
      table.insert(parts, arg.description)
    else
      table.insert(parts, value_to_string(arg))
    end
  end
  return table.concat(parts, ", ")
end

-- Spy function with enhanced features
function lust_next.spy(target, name, run)
  local spy = {
    calls = {},
    called = false,
    call_count = 0,
    original = nil,
    target = nil,
    name = nil,
    call_sequence = {}, -- Track call sequence numbers for order verification
    call_timestamps = {} -- Kept for backward compatibility
  }
  
  local subject

  local function capture(...)
    -- Update call tracking state
    spy.called = true
    spy.call_count = spy.call_count + 1
    
    -- Record arguments
    local args = {...}
    table.insert(spy.calls, args)
    
    -- Instead of relying purely on clock time, we'll use a global sequence counter
-- that increases for every call across all spies, guaranteeing a strict ordering
if not _G._lust_next_sequence_counter then
    _G._lust_next_sequence_counter = 0
end
_G._lust_next_sequence_counter = _G._lust_next_sequence_counter + 1

-- Store a sequence number that ensures strict ordering
-- This ensures exact ordering regardless of system clock precision
local sequence_number = _G._lust_next_sequence_counter
    table.insert(spy.call_sequence, sequence_number)
    
    -- Also store in timestamps for backward compatibility
    table.insert(spy.call_timestamps, sequence_number)
    
    -- Call the original or stubbed function
    if subject then
      return subject(...)
    end
    return nil
  end

  if type(target) == 'table' then
    spy.target = target
    spy.name = name
    spy.original = target[name]
    subject = spy.original
    target[name] = capture
  else
    run = name
    subject = target or function() end
  end

  -- Add spy methods
  function spy:restore()
    if self.target and self.name then
      self.target[self.name] = self.original
    end
  end
  
  function spy:called_with(...)
    local expected_args = {...}
    local found = false
    local matching_call_index = nil
    
    for i, call_args in ipairs(self.calls) do
      if args_match(expected_args, call_args) then
        found = true
        matching_call_index = i
        break
      end
    end
    
    -- If no matching call was found, return false
    if not found then
      return false
    end
    
    -- Return an object with chainable methods
    local result = {
      result = true,
      call_index = matching_call_index,
      
      -- Check if this call came before another spy's call
      called_before = function(other_spy)
        if type(other_spy) == "table" and other_spy.call_timestamps then
          -- Make sure other spy has been called
          if #other_spy.call_timestamps == 0 then
            return false
          end
          
          -- Compare timestamps
          return spy.call_timestamps[matching_call_index] < other_spy.call_timestamps[1]
        end
        return false
      end,
      
      -- Check if this call came after another spy's call
      called_after = function(other_spy)
        if type(other_spy) == "table" and other_spy.call_timestamps then
          -- Make sure other spy has been called
          if #other_spy.call_timestamps == 0 then
            return false
          end
          
          -- Compare timestamps
          local other_timestamp = other_spy.call_timestamps[#other_spy.call_timestamps]
          return spy.call_timestamps[matching_call_index] > other_timestamp
        end
        return false
      end
    }
    
    -- Make it work in boolean contexts
    setmetatable(result, {
      __call = function() return true end,
      __tostring = function() return "true" end
    })
    
    return result
  end
  
  function spy:called_times(n)
    return self.call_count == n
  end
  
  function spy:not_called()
    return self.call_count == 0
  end
  
  function spy:called_once()
    return self.call_count == 1
  end
  
  function spy:last_call()
    if #self.calls > 0 then
      return self.calls[#self.calls]
    end
    return nil
  end
  
  -- Check if a call happened before another spy's call
  function spy:called_before(other_spy, call_index)
    call_index = call_index or 1
    
    -- Safety checks
    if not other_spy or type(other_spy) ~= "table" then
      error("called_before requires a spy object as argument")
    end
    
    if not other_spy.call_sequence then
      error("called_before requires a spy object with call_sequence")
    end
    
    -- Make sure both spies have been called
    if self.call_count == 0 or other_spy.call_count == 0 then
      return false
    end
    
    -- Make sure other_spy has been called enough times
    if other_spy.call_count < call_index then
      return false
    end
    
    -- Get sequence number of the other spy's call
    local other_sequence = other_spy.call_sequence[call_index]
    if not other_sequence then
      return false
    end
    
    -- Check if any of this spy's calls happened before that
    for _, sequence in ipairs(self.call_sequence) do
      if sequence < other_sequence then
        return true
      end
    end
    
    return false
  end
  
  -- Check if a call happened after another spy's call
  function spy:called_after(other_spy, call_index)
    call_index = call_index or 1
    
    -- Safety checks
    if not other_spy or type(other_spy) ~= "table" then
      error("called_after requires a spy object as argument")
    end
    
    if not other_spy.call_sequence then
      error("called_after requires a spy object with call_sequence")
    end
    
    -- Make sure both spies have been called
    if self.call_count == 0 or other_spy.call_count == 0 then
      return false
    end
    
    -- Make sure other_spy has been called enough times
    if other_spy.call_count < call_index then
      return false
    end
    
    -- Get sequence of the other spy's call
    local other_sequence = other_spy.call_sequence[call_index]
    if not other_sequence then
      return false
    end
    
    -- Check if any of this spy's calls happened after that
    local last_self_sequence = self.call_sequence[self.call_count]
    if last_self_sequence > other_sequence then
      return true
    end
    
    return false
  end
  
  -- NEW: Find call index for a specific set of arguments
  function spy:find_call_index(...)
    local expected_args = {...}
    
    for i, call_args in ipairs(self.calls) do
      if args_match(expected_args, call_args) then
        return i
      end
    end
    
    return nil
  end
  
  -- NEW: Check if any calls match a specific pattern of arguments
  function spy:has_calls_with(...)
    local expected_pattern = {...}
    
    for _, call_args in ipairs(self.calls) do
      if #call_args >= #expected_pattern then
        local match = true
        for i, pattern_arg in ipairs(expected_pattern) do
          if not matches_arg(pattern_arg, call_args[i]) then
            match = false
            break
          end
        end
        
        if match then
          return true
        end
      end
    end
    
    return false
  end

  -- Set up call method
  setmetatable(spy, {
    __call = function(_, ...)
      return capture(...)
    end
  })

  if run then run() end

  return spy
end

-- Create an expectation object for mock expectations
local function create_expectation(mock, method_name)
  local expectation = {
    method = method_name,
    min_calls = nil,
    max_calls = nil,
    exact_calls = nil,
    args = nil,
    return_value = nil,
    required_before = nil,
    required_after = nil
  }
  
  -- Add expectation to mock's list
  if not mock._expectations then
    mock._expectations = {}
  end
  table.insert(mock._expectations, expectation)
  
  -- Create fluent interface for setting expectations
  local fluent = {}
  
  -- Base 'to' connector for fluent API
  fluent.to = {
    be = {
      called = {
        -- Set exact number of times
        times = function(n)
          expectation.exact_calls = n
          return fluent
        end,
        
        -- Must be called exactly once
        once = function()
          expectation.exact_calls = 1
          return fluent
        end,
        
        -- Called at least n times
        at_least = function(n)
          expectation.min_calls = n
          return fluent
        end,
        
        -- Called at most n times
        at_most = function(n)
          expectation.max_calls = n
          return fluent
        end,
        
        -- With specific arguments
        with = function(...)
          expectation.args = {...}
          return fluent
        end,
        
        -- Should be called after another method
        after = function(other_method)
          expectation.required_after = other_method
          return fluent
        end
      }
    }
  }
  
  -- Short form for setting arguments
  fluent.with = function(...)
    expectation.args = {...}
    return fluent
  end
  
  -- Shorthand for called once
  fluent.once = function()
    expectation.exact_calls = 1
    return fluent
  end
  
  -- Set return value
  fluent.and_return = function(value)
    expectation.return_value = value
    -- Also stub the method to return this value
    mock:stub(method_name, value)
    return fluent
  end
  
  -- Negative expectations
  fluent.to.not_be = {
    called = function()
      expectation.exact_calls = 0
      return fluent
    end
  }
  
  return fluent
end

-- Create a mock object with verifiable behavior
function lust_next.mock(target, options)
  options = options or {}
  
  local mock = {
    _is_lust_mock = true,
    target = target,
    _stubs = {},
    _originals = {},
    _expectations = {},
    _verify_all_expectations_called = options.verify_all_expectations_called ~= false
  }
  
  -- Method to stub a function with a return value or implementation
  function mock:stub(name, implementation_or_value)
    self._originals[name] = self.target[name]
    
    local implementation
    if type(implementation_or_value) == "function" then
      implementation = implementation_or_value
    else
      implementation = function() return implementation_or_value end
    end
    
    local spy = lust_next.spy(implementation)
    self._stubs[name] = spy
    self.target[name] = spy
    
    return self
  end
  
  -- Restore a specific stub
  function mock:restore_stub(name)
    if self._originals[name] then
      self.target[name] = self._originals[name]
      self._originals[name] = nil
      self._stubs[name] = nil
    end
  end
  
  -- Restore all stubs for this mock
  function mock:restore()
    for name, _ in pairs(self._originals) do
      self.target[name] = self._originals[name]
    end
    self._stubs = {}
    self._originals = {}
  end
  
  -- Verify all expected stubs were called
  function mock:verify()
    local failures = {}
    
    if self._verify_all_expectations_called then
      for name, stub in pairs(self._stubs) do
        if not stub.called then
          table.insert(failures, "Expected " .. name .. " to be called, but it was not")
        end
      end
    end
    
    if #failures > 0 then
      error("Mock verification failed:\n  " .. table.concat(failures, "\n  "), 2)
    end
    
    return true
  end
  
  -- NEW: Set expectation for a method
  function mock:expect(method_name)
    return create_expectation(self, method_name)
  end
  
  -- NEW: Verify that all expectations were met
  function mock:verify_expectations()
    if not self._expectations then
      return true
    end
    
    for _, expectation in ipairs(self._expectations) do
      local stub = self._stubs[expectation.method]
      
      -- If stub doesn't exist, create one that tracks calls to original method
      if not stub then
        self:stub(expectation.method, self.target[expectation.method])
        stub = self._stubs[expectation.method]
      end
      
      -- Check call count expectations
      if expectation.exact_calls ~= nil then
        if stub.call_count ~= expectation.exact_calls then
          error("Expectation failed: Method '" .. expectation.method .. 
                "' expected to be called exactly " .. expectation.exact_calls .. 
                " times but was called " .. stub.call_count .. " times")
        end
      end
      
      if expectation.min_calls ~= nil and stub.call_count < expectation.min_calls then
        error("Expectation failed: Method '" .. expectation.method .. 
              "' expected to be called at least " .. expectation.min_calls .. 
              " times but was called only " .. stub.call_count .. " times")
      end
      
      if expectation.max_calls ~= nil and stub.call_count > expectation.max_calls then
        error("Expectation failed: Method '" .. expectation.method .. 
              "' expected to be called at most " .. expectation.max_calls .. 
              " times but was called " .. stub.call_count .. " times")
      end
      
      -- Check argument expectations
      if expectation.args and stub.called then
        local arg_match_found = false
        for _, call_args in ipairs(stub.calls) do
          if args_match(expectation.args, call_args) then
            arg_match_found = true
            break
          end
        end
        
        if not arg_match_found then
          local expected_str = format_args(expectation.args)
          local actual_calls = {}
          for _, call_args in ipairs(stub.calls) do
            table.insert(actual_calls, "(" .. format_args(call_args) .. ")")
          end
          
          error("Expectation failed: Method '" .. expectation.method .. 
                "' expected to be called with (" .. expected_str .. 
                ") but was called with " .. table.concat(actual_calls, ", "))
        end
      end
      
      -- Check sequence expectations
      if expectation.required_after then
        local other_stub = self._stubs[expectation.required_after]
        if not other_stub then
          error("Expectation failed: Method '" .. expectation.method .. 
                "' expected to be called after '" .. expectation.required_after .. 
                "' but '" .. expectation.required_after .. "' was never stubbed")
        end
        
        -- Make sure both stubs have been called
        if not stub.called or not other_stub.called then
          if not stub.called then
            error("Expectation failed: Method '" .. expectation.method .. 
                  "' expected to be called after '" .. expectation.required_after .. 
                  "' but was never called")
          else
            error("Expectation failed: Method '" .. expectation.method .. 
                  "' expected to be called after '" .. expectation.required_after .. 
                  "' but '" .. expectation.required_after .. "' was never called")
          end
        end
        
        -- Check if the sequence numbers indicate the correct order
        local last_stub_sequence = stub.call_sequence[stub.call_count]
        local first_other_sequence = other_stub.call_sequence[1]
        
        if last_stub_sequence < first_other_sequence then
          local stub_sequences = {}
          for _, seq in ipairs(stub.call_sequence) do
            table.insert(stub_sequences, tostring(seq))
          end
          
          local other_sequences = {}
          for _, seq in ipairs(other_stub.call_sequence) do
            table.insert(other_sequences, tostring(seq))
          end
          
          error("Expectation failed: Method '" .. expectation.method .. 
                "' expected to be called after '" .. expectation.required_after .. 
                "' but was called before it.\n" ..
                "Method '" .. expectation.method .. "' called at sequences: " .. table.concat(stub_sequences, ", ") .. 
                "\nMethod '" .. expectation.required_after .. "' called at sequences: " .. table.concat(other_sequences, ", "))
        end
      end
    end
    
    return true
  end
  
  -- Verify a specific sequence of method calls
  function mock:verify_sequence(expected_sequence)
    local actual_calls = {}
    
    -- First, make sure all the expected methods have stubs
    for _, expected in ipairs(expected_sequence) do
      if not self._stubs[expected.method] then
        error("Method '" .. expected.method .. "' is expected in sequence but was never stubbed")
      end
    end
    
    -- Build a flattened list of all calls across methods
    for name, stub in pairs(self._stubs) do
      for i, call_args in ipairs(stub.calls) do
        if stub.call_sequence and stub.call_sequence[i] then
          table.insert(actual_calls, {
            method = name,
            args = call_args,
            sequence = stub.call_sequence[i],
            timestamp = stub.call_timestamps and stub.call_timestamps[i] -- For backward compatibility
          })
        end
      end
    end
    
    -- Sort by sequence number to get the actual sequence
    table.sort(actual_calls, function(a, b)
      return a.sequence < b.sequence
    end)
    
    -- Debug info for troubleshooting
    local debug_sequence = {}
    for _, actual in ipairs(actual_calls) do
      table.insert(debug_sequence, actual.method .. " (sequence #" .. tostring(actual.sequence) .. ")")
    end
    
    -- If no calls happened but sequence expects some, fail
    if #actual_calls == 0 and #expected_sequence > 0 then
      local expected_methods = {}
      for _, expected in ipairs(expected_sequence) do
        table.insert(expected_methods, expected.method)
      end
      error("Expected methods to be called in sequence: " .. 
            table.concat(expected_methods, ", ") .. 
            " but no methods were called")
    end
    
    -- If fewer calls happened than expected, fail
    if #actual_calls < #expected_sequence then
      local expected_methods = {}
      for _, expected in ipairs(expected_sequence) do
        table.insert(expected_methods, expected.method)
      end
      local actual_methods = {}
      for _, actual in ipairs(actual_calls) do
        table.insert(actual_methods, actual.method)
      end
      error("Expected sequence of " .. #expected_sequence .. 
            " method calls: " .. table.concat(expected_methods, ", ") .. 
            " but only " .. #actual_calls .. " happened: " .. 
            table.concat(actual_methods, ", "))
    end
    
    -- Check each call in the expected sequence
    for i, expected in ipairs(expected_sequence) do
      local actual = actual_calls[i]
      
      -- Check method name first
      if actual.method ~= expected.method then
        error("Call sequence mismatch at position " .. i .. 
              ": Expected method '" .. expected.method .. 
              "' but got '" .. actual.method .. "'" ..
              "\nActual sequence was: " .. table.concat(debug_sequence, ", "))
      end
      
      -- Check arguments if specified
      if expected.args then
        if not args_match(expected.args, actual.args) then
          local expected_str = format_args(expected.args)
          local actual_str = format_args(actual.args)
          
          error("Call sequence argument mismatch at position " .. i .. 
                " for method '" .. expected.method .. 
                "': Expected (" .. expected_str .. 
                ") but got (" .. actual_str .. ")")
        end
      end
    end
    
    return true
  end
  
  -- Register for auto-cleanup
  register_mock(mock)
  
  return mock
end

-- Create a standalone stub function
function lust_next.stub(return_value_or_implementation)
  if type(return_value_or_implementation) == "function" then
    return lust_next.spy(return_value_or_implementation)
  else
    return lust_next.spy(function() return return_value_or_implementation end)
  end
end

-- Context manager for mocks that auto-restores
function lust_next.with_mocks(fn)
  local prev_mocks = _mocks
  _mocks = {}
  
  local ok, result = pcall(fn, lust_next.mock)
  
  -- Always restore mocks, even on failure
  for _, mock in ipairs(_mocks) do
    mock:restore()
  end
  
  _mocks = prev_mocks
  
  if not ok then
    error(result, 2)
  end
  
  return result
end

-- Register hook to clean up mocks after tests
local original_it = lust_next.it
function lust_next.it(name, fn)
  local wrapped_fn = function()
    local prev_mocks = _mocks
    _mocks = {}
    
    local result = fn()
    
    -- Restore any mocks created during the test
    for _, mock in ipairs(_mocks) do
      mock:restore()
    end
    
    _mocks = prev_mocks
    
    return result
  end
  
  return original_it(name, wrapped_fn)
end

-- Test Discovery System
-- Simplified test discovery for self-running
function lust_next.discover(root_dir, pattern)
  root_dir = root_dir or "."
  pattern = pattern or "**/*_test.lua"
  
  -- For better test discovery, use scripts/run_tests.lua
  if pattern ~= "**/*_test.lua" and pattern ~= "*_test.lua" then
    print("Warning: Complex pattern matching not fully supported in built-in discover")
    print("For better test discovery, use scripts/run_tests.lua")
  end
  
  local test_files = {}
  
  -- Platform-specific directory listing implementation
  local function list_directory(dir)
    local files = {}
    local handle, err
    
    if package.config:sub(1,1) == '\\' then
      -- Windows implementation
      local result = io.popen('dir /b "' .. dir .. '"')
      if result then
        for name in result:lines() do
          table.insert(files, name)
        end
        result:close()
      end
    else
      -- Unix implementation
      local result = io.popen('ls -a "' .. dir .. '" 2>/dev/null')
      if result then
        for name in result:lines() do
          if name ~= "." and name ~= ".." then
            table.insert(files, name)
          end
        end
        result:close()
      end
    end
    
    return files
  end
  
  -- Get file type (directory or file)
  local function get_file_type(path)
    local success, result
    
    if package.config:sub(1,1) == '\\' then
      -- Windows implementation
      local cmd = 'if exist "' .. path .. '\\*" (echo directory) else (echo file)'
      success, result = pcall(function()
        local p = io.popen(cmd)
        local output = p:read('*l')
        p:close()
        return output
      end)
    else
      -- Unix implementation
      success, result = pcall(function()
        local p = io.popen('test -d "' .. path .. '" && echo directory || echo file')
        local output = p:read('*l')
        p:close()
        return output
      end)
    end
    
    if success and result then
      return result:match("directory") and "directory" or "file"
    else
      -- Default to file if we can't determine
      return "file"
    end
  end
  
  -- Simple pattern matching (supports basic glob patterns)
  local function match_pattern(name, pattern)
    -- For simplicity, we'll do a more direct pattern match for now
    if pattern == "**/*_test.lua" then
      return name:match("_test%.lua$") ~= nil
    elseif pattern == "*_test.lua" then
      return name:match("_test%.lua$") ~= nil
    else
      -- Fallback to basic ending match
      local ending = pattern:gsub("*", "")
      return name:match(ending:gsub("%.", "%%.") .. "$") ~= nil
    end
  end
  
  -- Get test files directly using os.execute and capturing output
  local files = {}
  
  -- Determine the command to run based on the platform
  local command
  if package.config:sub(1,1) == '\\' then
    -- Windows
    command = 'dir /s /b "' .. root_dir .. '\\*_test.lua" > lust_temp_files.txt'
  else
    -- Unix
    command = 'find "' .. root_dir .. '" -name "*_test.lua" -type f > lust_temp_files.txt'
  end
  
  -- Execute the command
  os.execute(command)
  
  -- Read the results from the temporary file
  local file = io.open("lust_temp_files.txt", "r")
  if file then
    for line in file:lines() do
      if line:match("_test%.lua$") then
        table.insert(files, line)
      end
    end
    file:close()
    os.remove("lust_temp_files.txt")
  end
  
  return files
end

-- Process a single test file
local function process_test_file(file, results)
  -- Reset state before each file
  local prev_passes = lust_next.passes
  local prev_errors = lust_next.errors
  
  print("\nFile: " .. file)
  local success, err = pcall(function()
    dofile(file)
  end)
  
  if not success then
    results.failed_files = results.failed_files + 1
    table.insert(results.failures, {
      file = file,
      error = "Error loading file: " .. err
    })
    print(red .. "ERROR: " .. err .. normal)
  else
    local file_passes = lust_next.passes - prev_passes
    local file_errors = lust_next.errors - prev_errors
    
    results.total_tests = results.total_tests + file_passes + file_errors
    results.passed_tests = results.passed_tests + file_passes
    results.failed_tests = results.failed_tests + file_errors
    
    if file_errors > 0 then
      results.failed_files = results.failed_files + 1
    else
      results.passed_files = results.passed_files + 1
    end
  end
end

-- Run discovered tests
function lust_next.run_discovered(root_dir, pattern, options)
  options = options or {}
  
  -- Reset all state before running tests
  lust_next.focus_mode = false
  lust_next.skipped = 0
  lust_next.current_tags = {}
  lust_next.active_tags = {}
  lust_next.filter_pattern = nil
  
  -- Apply filters if specified in options
  if options.tags then
    if type(options.tags) == "string" then
      lust_next.only_tags(options.tags)
    elseif type(options.tags) == "table" then
      -- Use table.unpack for Lua 5.2+ or unpack for Lua 5.1
      local unpack_func = table.unpack or unpack
      lust_next.only_tags(unpack_func(options.tags))
    end
  end
  
  if options.filter then
    lust_next.filter(options.filter)
  end
  
  local files = lust_next.discover(root_dir, pattern)
  local results = {
    total_files = #files,
    passed_files = 0,
    failed_files = 0,
    total_tests = 0,
    passed_tests = 0,
    failed_tests = 0,
    skipped_tests = 0,
    failures = {}
  }
  
  -- Initial pass/error counters
  local initial_passes = lust_next.passes
  local initial_errors = lust_next.errors
  
  -- Build filter information for summary
  local filter_info = ""
  if #lust_next.active_tags > 0 then
    filter_info = filter_info .. " (filtered by tags: " .. table.concat(lust_next.active_tags, ", ") .. ")"
  end
  if lust_next.filter_pattern then
    filter_info = filter_info .. " (filtered by pattern: " .. lust_next.filter_pattern .. ")"
  end
  
  print("\n" .. green .. "Running " .. #files .. " test files" .. normal .. filter_info)
  print(string.rep("-", 70))
  
  -- Process each file
  for _, file in ipairs(files) do
    process_test_file(file, results)
  end
  
  -- Print summary
  print("\n" .. string.rep("-", 70))
  print("Test Summary:")
  print(string.rep("-", 70))
  
  -- File statistics
  local total_color = results.failed_files > 0 and red or green
  print("Files:  " .. total_color .. results.passed_files .. "/" 
       .. results.total_files .. normal 
       .. " (" .. (results.total_files > 0 and math.floor(results.passed_files/results.total_files*100) or 0) .. "% passed)")
  
  -- Test statistics
  total_color = results.failed_tests > 0 and red or green
  print("Tests:  " .. total_color .. results.passed_tests .. "/" 
       .. results.total_tests .. normal 
       .. " (" .. (results.total_tests > 0 and math.floor(results.passed_tests/results.total_tests*100) or 0) .. "% passed)")
  
  -- Print skipped tests if we have any
  if results.skipped_tests and results.skipped_tests > 0 then
    print("Skipped: " .. results.skipped_tests .. " tests due to filtering")
  end
  
  -- List failures
  if #results.failures > 0 then
    print("\n" .. red .. "Failures:" .. normal)
    for i, failure in ipairs(results.failures) do
      print(i .. ") " .. failure.file)
      if failure.error then
        print("   " .. failure.error)
      end
    end
  end
  
  print(string.rep("-", 70))
  
  if results.failed_tests > 0 then
    print(red .. "✖ Tests Failed" .. normal)
  else
    print(green .. "✓ All Tests Passed" .. normal)
  end
  
  print(string.rep("-", 70) .. "\n")
  
  -- Reset filters after run
  lust_next.reset_filters()
  
  return results
end

-- Track skipped tests directly in the lust_next object
lust_next.skipped = 0

-- Run a single test file
function lust_next.run_file(file_path)
  local prev_passes = lust_next.passes
  local prev_errors = lust_next.errors
  local prev_skipped = lust_next.skipped
  
  -- Important: Reset state before running the file
  lust_next.skipped = 0
  lust_next.focus_mode = false
  
  print("\nRunning file: " .. file_path)
  local success, err = pcall(function()
    -- Set the package path to include the directory of the test file
    local dir = file_path:match("(.*[/\\])")
    package.path = dir .. "?.lua;" .. dir .. "../?.lua;" .. package.path
    dofile(file_path)
  end)
  
  local results = {
    success = success,
    error = err,
    passes = lust_next.passes - prev_passes,
    errors = lust_next.errors - prev_errors,
    skipped = lust_next.skipped,
    focus_mode = lust_next.focus_mode
  }
  
  if not success then
    print(red .. "ERROR: " .. err .. normal)
  else
    local summary = green .. "Completed with " .. results.passes .. " passes, " 
                  .. results.errors .. " failures" .. normal
    
    if lust_next.skipped > 0 then
      summary = summary .. " (" .. lust_next.skipped .. " skipped)"
    end
    
    if lust_next.focus_mode then
      summary = summary .. " [FOCUS MODE ACTIVE]"
    end
    
    print(summary)
  end
  
  -- Reset state after the run
  lust_next.focus_mode = false
  -- Important: Also reset all other state that might affect future runs
  lust_next.current_tags = {}
  lust_next.active_tags = {}
  lust_next.filter_pattern = nil
  
  return results
end

-- CLI runner that finds and runs tests
function lust_next.cli_run(dir, options)
  dir = dir or "./tests"
  options = options or {}
  
  -- Reset state before running any tests
  lust_next.focus_mode = false
  lust_next.skipped = 0
  lust_next.current_tags = {}
  lust_next.active_tags = {}
  lust_next.filter_pattern = nil
  
  -- Initialize coverage if enabled
  if lust_next.coverage_options.enabled and coverage then
    coverage.init(lust_next.coverage_options)
    coverage.reset()
    coverage.start()
  end
  
  -- Apply filters if specified in options
  if options.tags then
    if type(options.tags) == "string" then
      lust_next.only_tags(options.tags)
    elseif type(options.tags) == "table" then
      -- Use table.unpack for Lua 5.2+ or unpack for Lua 5.1
      local unpack_func = table.unpack or unpack
      lust_next.only_tags(unpack_func(options.tags))
    end
  end
  
  if options.filter then
    lust_next.filter(options.filter)
  end
  
  local files = lust_next.discover(dir)
  
  -- Build filter information for summary
  local filter_info = ""
  if #lust_next.active_tags > 0 then
    filter_info = filter_info .. " (filtered by tags: " .. table.concat(lust_next.active_tags, ", ") .. ")"
  end
  if lust_next.filter_pattern then
    filter_info = filter_info .. " (filtered by pattern: " .. lust_next.filter_pattern .. ")"
  end
  
  print(green .. "Running " .. #files .. " test files" .. normal .. filter_info)
  
  local passed = 0
  local failed = 0
  local skipped = 0
  
  for _, file in ipairs(files) do
    -- Each file runs with clean state
    local results = lust_next.run_file(file)
    if results.success and results.errors == 0 then
      passed = passed + 1
    else
      failed = failed + 1
    end
    if results.skipped then
      skipped = skipped + (results.skipped or 0)
    end
  end
  
  -- Add a line break after dot mode output
  if lust_next.format_options.dot_mode then
    print("\n")
  end
  
  print("\n" .. string.rep("-", 70))
  print("TEST SUMMARY")
  print(string.rep("-", 70))
  
  print("Results:  " .. green .. passed .. " passed" .. normal .. ", " .. 
        (failed > 0 and red or green) .. failed .. " failed" .. normal .. 
        (skipped > 0 and ", " .. yellow .. skipped .. " skipped" .. normal or ""))
  
  -- Calculate percentage
  local total = passed + failed
  local percentage = total > 0 and math.floor((passed / total) * 100) or 100
  local percent_color = percentage >= 90 and green or (percentage >= 75 and yellow or red)
  
  print("Success:  " .. percent_color .. percentage .. "%" .. normal)
  print("Duration: " .. string.format("%.2f", os.clock()) .. "s")
  
  if lust_next.focus_mode then
    print(cyan .. "FOCUS MODE: Only focused tests were run" .. normal)
  end
  
  print(string.rep("-", 70))
  
  -- Stop coverage collection if enabled
  if lust_next.coverage_options.enabled and coverage then
    coverage.stop()
    
    -- Generate and display coverage report
    local report_format = lust_next.coverage_options.format or "summary"
    local report_content = coverage.report(report_format)
    
    -- Print coverage header
    print("\n" .. string.rep("-", 70))
    print("COVERAGE REPORT")
    print(string.rep("-", 70))
    
    -- Handle report output
    if lust_next.coverage_options.output then
      -- Save to file
      local success, err = coverage.save_report(lust_next.coverage_options.output, report_format)
      if success then
        print("Coverage report saved to: " .. lust_next.coverage_options.output)
      else
        print("Error saving coverage report: " .. (err or "unknown error"))
      end
    else
      -- Print to console (only for summary and small reports)
      if report_format == "summary" then
        local report = coverage.summary_report()
        local threshold = lust_next.coverage_options.threshold or 80
        local overall_color = report.overall_pct >= threshold and green or red
        
        print("Overall:   " .. overall_color .. string.format("%.2f%%", report.overall_pct) .. normal)
        print("Lines:     " .. string.format("%d/%d (%.2f%%)", 
          report.covered_lines, report.total_lines, report.lines_pct))
        print("Functions: " .. string.format("%d/%d (%.2f%%)", 
          report.covered_functions, report.total_functions, report.functions_pct))
        print("Files:     " .. string.format("%d/%d (%.2f%%)", 
          report.covered_files, report.total_files, report.files_pct))
        
        -- Check threshold
        if report.overall_pct < threshold then
          print(red .. "✖ COVERAGE BELOW THRESHOLD " .. normal .. 
                "(" .. string.format("%.2f%% < %.2f%%", report.overall_pct, threshold) .. ")")
          print(string.rep("-", 70))
        else
          print(green .. "✓ COVERAGE MEETS THRESHOLD " .. normal ..
                "(" .. string.format("%.2f%% >= %.2f%%", report.overall_pct, threshold) .. ")")
          print(string.rep("-", 70))
        end
      elseif report_format == "json" then
        print("JSON Report:")
        print(report_content)
        print(string.rep("-", 70))
      elseif report_format == "lcov" then
        print("LCOV Report generated")
        print(string.rep("-", 70))
      elseif report_format == "html" then
        print("HTML Report generated")
        print("Use --coverage-output to save the report to a file")
        print(string.rep("-", 70))
      end
    end
    
    -- Check if coverage meets threshold
    local threshold = lust_next.coverage_options.threshold or 80
    local meets_threshold = coverage.meets_threshold(threshold)
    
    -- Return negative result if coverage doesn't meet threshold, regardless of test results
    if not meets_threshold then
      if failed == 0 then
        -- Tests passed but coverage failed
        print(yellow .. "⚠ TESTS PASSED BUT COVERAGE FAILED" .. normal)
      end
      lust_next.reset_filters()
      lust_next.focus_mode = false
      return false
    end
  end
  
  if failed > 0 then
    print(red .. "✖ FAILED " .. normal .. "(" .. failed .. " of " .. total .. " tests failed)")
    lust_next.reset_filters()
    lust_next.focus_mode = false
    return false
  else
    print(green .. "✓ SUCCESS " .. normal .. "(" .. passed .. " of " .. total .. " tests passed)")
    lust_next.reset_filters()
    lust_next.focus_mode = false
    return true
  end
end

-- Async testing implementation
local clock
if os.clock then
  clock = os.clock
else
  -- Fallback for environments without os.clock
  clock = function()
    return os.time()
  end
end

-- Wrapper to create an async test function
function lust_next.async(fn, timeout)
  return function(...)
    local args = {...}
    return function()
      lust_next.running_async = true
      
      -- Create the coroutine for this test
      local co = coroutine.create(function()
        -- Use table.unpack for Lua 5.2+ or unpack for Lua 5.1
        local unpack_func = table.unpack or unpack
        return fn(unpack_func(args))
      end)
      
      -- Set timeout (use provided timeout or default)
      local test_timeout = timeout or lust_next.async_timeout
      local start_time = clock() * 1000
      local is_complete = false
      
      -- First resume to start the coroutine
      local success, result = coroutine.resume(co)
      
      -- Handle immediate completion or error
      if coroutine.status(co) == "dead" then
        is_complete = true
        lust_next.running_async = false
        
        if not success then
          error(result, 2) -- Propagate the error
        end
        return result
      end
      
      -- Loop until coroutine completes or times out
      while coroutine.status(co) ~= "dead" do
        -- Check for timeout
        local current_time = clock() * 1000
        if current_time - start_time > test_timeout then
          lust_next.running_async = false
          error("Async test timed out after " .. test_timeout .. "ms", 2)
        end
        
        -- Sleep a little to avoid hogging CPU
        lust_next.sleep(10)
        
        -- Resume the coroutine
        success, result = coroutine.resume(co)
        
        if not success then
          lust_next.running_async = false
          error(result, 2) -- Propagate the error
        end
      end
      
      lust_next.running_async = false
      return result
    end
  end
end

-- Wait for a specified time in milliseconds
function lust_next.await(ms)
  if not lust_next.running_async then
    error("lust_next.await() can only be called within an async test", 2)
  end
  
  local start = clock() * 1000
  while (clock() * 1000) - start < ms do
    coroutine.yield()
  end
end

-- Wait until a condition function returns true or timeout
function lust_next.wait_until(condition_fn, timeout, check_interval)
  if not lust_next.running_async then
    error("lust_next.wait_until() can only be called within an async test", 2)
  end
  
  timeout = timeout or lust_next.async_timeout
  check_interval = check_interval or 10
  
  local start_time = clock() * 1000
  
  while not condition_fn() do
    if (clock() * 1000) - start_time > timeout then
      error("Timeout waiting for condition after " .. timeout .. "ms", 2)
    end
    lust_next.await(check_interval)
  end
end

-- Simple sleep function that works in any environment
function lust_next.sleep(ms)
  local start = clock()
  local duration = ms / 1000 -- convert to seconds
  while clock() - start < duration do
    -- Busy wait
  end
end

-- Set global default timeout for async tests
function lust_next.set_timeout(ms)
  lust_next.async_timeout = ms
  return lust_next
end

-- Async version of 'it' for easier test writing
function lust_next.it_async(name, fn, timeout)
  return lust_next.it(name, lust_next.async(fn, timeout)())
end

-- Aliases and exports
lust_next.test = lust_next.it
lust_next.test_async = lust_next.it_async
lust_next.paths = paths

-- Command-line runner with enhanced options
-- Only run this if we're invoked directly (not through require)
local debug_info = debug.getinfo(3, "S")
local is_main = debug_info and debug_info.source == arg[0]

if is_main and arg and (arg[0]:match("lust_next.lua$") or arg[0]:match("lust%-next.lua$")) then
  local options = {}
  local dir = "./tests"
  local specific_file = nil
  
  -- Parse command line arguments
  local i = 1
  while i <= #arg do
    if arg[i] == "--dir" and arg[i+1] then
      dir = arg[i+1]
      i = i + 2
    elseif arg[i] == "--tags" and arg[i+1] then
      options.tags = {}
      -- Split tags by comma
      for tag in arg[i+1]:gmatch("[^,]+") do
        table.insert(options.tags, tag:match("^%s*(.-)%s*$")) -- Trim whitespace
      end
      i = i + 2
    elseif arg[i] == "--filter" and arg[i+1] then
      options.filter = arg[i+1]
      i = i + 2
    elseif arg[i] == "--format" and arg[i+1] then
      local format_name = arg[i+1]
      if format_name == "dot" then
        lust_next.format({ dot_mode = true })
      elseif format_name == "compact" then
        lust_next.format({ compact = true, show_success_detail = false })
      elseif format_name == "summary" then
        lust_next.format({ summary_only = true })
      elseif format_name == "detailed" then
        lust_next.format({ show_success_detail = true, show_trace = true })
      elseif format_name == "plain" then
        lust_next.format({ use_color = false })
      else
        print("Unknown format: " .. format_name)
        os.exit(1)
      end
      i = i + 2
    elseif arg[i] == "--indent" and arg[i+1] then
      if arg[i+1] == "space" or arg[i+1] == "spaces" then
        lust_next.format({ indent_char = ' ', indent_size = 2 })
      elseif arg[i+1] == "tab" or arg[i+1] == "tabs" then
        lust_next.format({ indent_char = '\t', indent_size = 1 })
      else
        local num = tonumber(arg[i+1])
        if num then
          lust_next.format({ indent_char = ' ', indent_size = num })
        else
          print("Invalid indent: " .. arg[i+1])
          os.exit(1)
        end
      end
      i = i + 2
    elseif arg[i] == "--no-color" then
      lust_next.nocolor()
      i = i + 1
    elseif arg[i]:match("%.lua$") then
      specific_file = arg[i]
      i = i + 1
    elseif arg[i] == "--coverage" then
      lust_next.coverage_options.enabled = true
      i = i + 1
    elseif arg[i] == "--coverage-include" and arg[i+1] then
      lust_next.coverage_options.include = {}
      for pattern in arg[i+1]:gmatch("[^,]+") do
        table.insert(lust_next.coverage_options.include, pattern:match("^%s*(.-)%s*$")) -- Trim whitespace
      end
      i = i + 2
    elseif arg[i] == "--coverage-exclude" and arg[i+1] then
      lust_next.coverage_options.exclude = {}
      for pattern in arg[i+1]:gmatch("[^,]+") do
        table.insert(lust_next.coverage_options.exclude, pattern:match("^%s*(.-)%s*$")) -- Trim whitespace
      end
      i = i + 2
    elseif arg[i] == "--coverage-threshold" and arg[i+1] then
      lust_next.coverage_options.threshold = tonumber(arg[i+1]) or 80
      i = i + 2
    elseif arg[i] == "--coverage-format" and arg[i+1] then
      lust_next.coverage_options.format = arg[i+1]
      i = i + 2
    elseif arg[i] == "--coverage-output" and arg[i+1] then
      lust_next.coverage_options.output = arg[i+1]
      i = i + 2
    elseif arg[i] == "--help" or arg[i] == "-h" then
      print("lust-next test runner v" .. lust_next.version)
      print("Usage:")
      print("  lua lust-next.lua [options] [file.lua]")
      
      print("\nTest Selection Options:")
      print("  --dir DIR        Directory to search for tests (default: ./tests)")
      print("  --tags TAG1,TAG2 Only run tests with matching tags")
      print("  --filter PATTERN Only run tests with names matching pattern")
      
      print("\nOutput Format Options:")
      print("  --format FORMAT  Output format (dot, compact, summary, detailed, plain)")
      print("  --indent TYPE    Indentation style (space, tab, or number of spaces)")
      print("  --no-color       Disable colored output")
      
      print("\nCoverage Options:")
      print("  --coverage                   Enable code coverage tracking")
      print("  --coverage-include PATTERNS  Comma-separated file patterns to include (default: *.lua)")
      print("  --coverage-exclude PATTERNS  Comma-separated file patterns to exclude (default: test_*,*_spec.lua,*_test.lua)")
      print("  --coverage-threshold N       Minimum coverage percentage required (default: 80)")
      print("  --coverage-format FORMAT     Coverage report format (summary, json, html, lcov) (default: summary)")
      print("  --coverage-output FILE       Output file for coverage report (default: console output)")
      
      print("\nSpecial Test Functions:")
      print("  describe/it      Regular test functions")
      print("  fdescribe/fit    Focused tests (only these will run)")
      print("  xdescribe/xit    Excluded tests (these will be skipped)")
      
      print("\nExamples:")
      print("  lua lust-next.lua --dir tests --format dot")
      print("  lua lust-next.lua --tags unit,api --format compact")
      print("  lua lust-next.lua tests/specific_test.lua --format detailed")
      os.exit(0)
    else
      i = i + 1
    end
  end
  
  if specific_file then
    -- Run a specific test file
    local results = lust_next.run_file(specific_file)
    if not results.success or results.errors > 0 then
      os.exit(1)
    else
      os.exit(0)
    end
  else
    -- Run tests with options
    local success = lust_next.cli_run(dir, options)
    os.exit(success and 0 or 1)
  end
end

-- Backward compatibility for users upgrading from lust
local lust = setmetatable({}, {
  __index = function(_, key)
    print("Warning: Using 'lust' directly is deprecated, please use 'lust_next' instead")
    return lust_next[key]
  end
})

return lust_next
