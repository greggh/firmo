-- Source map for mapping instrumented code back to original source
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.instrumentation.sourcemap")

---@class StatementBoundary
---@field start number Start line of the statement
---@field finish number End line of the statement

---@class SourceMapStructure
---@field path string Normalized path to the original file
---@field original_to_instrumented table<number, number> Maps original line numbers to instrumented line numbers
---@field instrumented_to_original table<number, number> Maps instrumented line numbers to original line numbers
---@field statement_boundaries table<number, StatementBoundary> Records multi-line statement boundaries
---@field original_line_count number Number of lines in the original file
---@field instrumented_line_count number Number of lines in the instrumented file
---@field tracking_lookup table<number, number> Records which instrumented lines contain tracking code and their positions
---@class coverage_v3_instrumentation_sourcemap
---@field create fun(path: string, original_content: string, instrumented_content: string): SourceMapStructure|nil Create a source map
---@field get_instrumented_line fun(map: SourceMapStructure, original_line: number): number|nil Map original line to instrumented line
---@field get_original_line fun(map: SourceMapStructure, instrumented_line: number): number|nil Map instrumented line to original line
---@field serialize fun(map: SourceMapStructure): string Serialize source map to string
---@field deserialize fun(serialized: string): SourceMapStructure|nil Deserialize source map from string
---@field validate fun(map: SourceMapStructure): boolean|nil, string? Validate source map structure
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0",
  create = nil, -- Will be defined below
  get_instrumented_line = nil, -- Will be defined below
  get_original_line = nil, -- Will be defined below
  serialize = nil, -- Will be defined below
  deserialize = nil, -- Will be defined below 
  validate = nil -- Will be defined below
}

-- Helper function to normalize content for comparison
local function normalize_content(line)
  -- Remove "Original" text that might have been added
  line = line:gsub("Original ", "")
  -- Remove trailing whitespace
  line = line:gsub("%s+$", "")
  -- Remove leading whitespace
  line = line:gsub("^%s+", "")
  return line
end

-- Helper function to get core content without annotations
local function get_core_content(line)
  -- Remove comments
  line = line:gsub("%-%-.*$", "")
  -- Remove tracking calls
  line = line:gsub("_firmo_coverage%.track%([^)]*%)", "")
  -- Remove whitespace
  line = line:gsub("%s+", "")
  return line
end

-- Validate inputs
local function validate_inputs(path, original_content, instrumented_content)
  if not path or type(path) ~= "string" or path == "" then
    return nil, error_handler.validation_error("Invalid path", { path = path })
  end
  if not original_content or type(original_content) ~= "string" then
    return nil, error_handler.validation_error("Invalid content", { content = original_content })
  end
  if not instrumented_content or type(instrumented_content) ~= "string" then
    return nil, error_handler.validation_error("Invalid content", { content = instrumented_content })
  end
  return true
end

-- Create a source map
---@param path string Path to the original file
---@param original_content string Content of original file
---@param instrumented_content string Content of instrumented file
---@return SourceMapStructure|nil map Source map object, or nil if creation failed
---@return string? error Error message if creation failed
M.create = function(path, original_content, instrumented_content)
  -- Validate inputs
  local ok, err = validate_inputs(path, original_content, instrumented_content)
  if not ok then
    return nil, err
  end

  -- Create map structure
  -- Create map structure
  local map = {
    path = fs.normalize_path(path),
    original_to_instrumented = {}, -- Map original lines to instrumented lines
    instrumented_to_original = {}, -- Map instrumented lines to original lines
    statement_boundaries = {}, -- Record multi-line statement boundaries
    tracking_lookup = {}, -- Record which instrumented lines contain tracking code and their positions
  }
  -- Split content into lines - preserve all lines including empty ones
  local original_lines = {}
  for line in (original_content .. "\n"):gmatch("([^\n]*)[\\n]") do
    table.insert(original_lines, line)
  end
  local instrumented_lines = {}
  for line in (instrumented_content .. "\n"):gmatch("([^\n]*)[\\n]") do
    table.insert(instrumented_lines, line)
  end
  map.original_line_count = #original_lines
  map.instrumented_line_count = #instrumented_lines

  logger.debug("Creating source map", {
    path = path,
    original_lines = #original_lines,
    instrumented_lines = #instrumented_lines
  })

  -- Build line mappings
  -- Initialize tracking variables for multi-line statements
  local current_stmt_start = nil
  local in_multiline_statement = false

  -- Build tracking lookup table - directly store line numbers where tracking calls exist
  for i, line in ipairs(instrumented_lines) do
    if line:match("_firmo_coverage%.track") then
      -- Store the actual line number, not just a boolean
      map.tracking_lookup[i] = i
      logger.debug("Found tracking line", {
        instrumented_line = i,
        content = line
      })
    end
  end
  
  local tracking_count = 0
  for _ in pairs(map.tracking_lookup) do
    tracking_count = tracking_count + 1
  end
  
  logger.debug("Initial tracking analysis", {
    tracking_count = tracking_count
  })

  -- First pass: Map lines without tracking lines
  -- Process original lines and find their instrumented matches
  local orig_i = 1
  local inst_i = 1

  while orig_i <= #original_lines and inst_i <= #instrumented_lines do
    local orig_line = original_lines[orig_i]
    local inst_line = instrumented_lines[inst_i]

    -- Skip tracking lines
    if map.tracking_lookup[inst_i] then
      logger.debug("Skipping tracking line during mapping", {
        instrumented_line = inst_i
      })
      inst_i = inst_i + 1
      goto continue
    end
    -- Full content comparison (using exact content, not truncated)
    
    -- Handle empty lines - map directly with exact comparison
    if orig_line == "" and inst_line == "" then
      map.original_to_instrumented[orig_i] = inst_i
      map.instrumented_to_original[inst_i] = orig_i
      logger.debug("Mapped empty line", {
        original_line = orig_i,
        instrumented_line = inst_i
      })
      orig_i = orig_i + 1
      inst_i = inst_i + 1

    -- Handle comments - using normalized content for better matching
    elseif orig_line:match("^%s*%-%-") and inst_line:match("^%s*%-%-") and
           (orig_line == inst_line or 
            normalize_content(orig_line) == normalize_content(inst_line)) then
      map.original_to_instrumented[orig_i] = inst_i
      map.instrumented_to_original[inst_i] = orig_i
      logger.debug("Mapped comment line", {
        original_line = orig_i,
        instrumented_line = inst_i,
        content = orig_line
      })
      orig_i = orig_i + 1
      inst_i = inst_i + 1

    -- Code lines - if exact match, map directly
    elseif orig_line == inst_line or 
           normalize_content(orig_line) == normalize_content(inst_line) then
      map.original_to_instrumented[orig_i] = inst_i
      map.instrumented_to_original[inst_i] = orig_i
      logger.debug("Mapped exact matching line", {
        original_line = orig_i,
        instrumented_line = inst_i
      })
      
      -- Handle multi-line statement tracking
      local norm_orig_line = orig_line:gsub("^%s+", ""):gsub("%s+$", "")
      
      -- Check if this is the start of a multi-line statement
      if not in_multiline_statement and (
          norm_orig_line:match("[%(%{%[]%s*$") or -- Opens with (, {, [ at the end
          norm_orig_line:match("[%+%-%*%/%^]%s*$") or -- Ends with operator
          norm_orig_line:match("%=%s*$") -- Ends with =
        ) then
        in_multiline_statement = true
        current_stmt_start = orig_i
        logger.debug("Starting multi-line statement", {
          line = orig_i,
          content = norm_orig_line
        })
      end
      
      -- Check if this is the end of a multi-line statement
      if in_multiline_statement and (
          norm_orig_line:match("^%s*[%)%}%]]") or -- Starts with closing bracket
          norm_orig_line:match(";%s*$") or -- Ends with semicolon
          (not norm_orig_line:match("[%(%{%[]%s*$") and 
           not norm_orig_line:match("[%+%-%*%/%^]%s*$") and
           not norm_orig_line:match("%=%s*$"))
        ) then
        -- End the multi-line statement and record boundaries
        if current_stmt_start and current_stmt_start < orig_i then
          map.statement_boundaries[current_stmt_start] = {
            start = current_stmt_start,
            finish = orig_i
          }
          logger.debug("Completed multi-line statement", {
            start = current_stmt_start,
            finish = orig_i,
            content = norm_orig_line
          })
        end
        in_multiline_statement = false
        current_stmt_start = nil
      end
      
      orig_i = orig_i + 1
      inst_i = inst_i + 1
      
    -- Try comparing the core content of lines
    elseif get_core_content(orig_line) == get_core_content(inst_line) then
      map.original_to_instrumented[orig_i] = inst_i
      map.instrumented_to_original[inst_i] = orig_i
      logger.debug("Mapped line ignoring whitespace", {
        original_line = orig_i,
        instrumented_line = inst_i
      })
      orig_i = orig_i + 1
      inst_i = inst_i + 1
      
    else
      -- Lines don't match - look ahead for potential matches
      local found_match = false
      
      -- Look ahead in instrumented file for exact or normalized matches
      for look_ahead = 1, 5 do -- Increased look ahead range for better matching
        if inst_i + look_ahead <= #instrumented_lines then
          local ahead_line = instrumented_lines[inst_i + look_ahead]
          if ahead_line == orig_line or 
             normalize_content(ahead_line) == normalize_content(orig_line) or
             get_core_content(ahead_line) == get_core_content(orig_line) then
            -- Found match, update indices
            inst_i = inst_i + look_ahead
            map.original_to_instrumented[orig_i] = inst_i
            map.instrumented_to_original[inst_i] = orig_i
            
            logger.debug("Found match after instrumented look-ahead", {
              original_line = orig_i,
              instrumented_line = inst_i,
              look_ahead = look_ahead
            })
            
            found_match = true
            orig_i = orig_i + 1
            inst_i = inst_i + 1
            break
          end
        end
      end
      
      -- If no match found in instrumented, look ahead in original
      if not found_match then
        for look_ahead = 1, 5 do
          if orig_i + look_ahead <= #original_lines then
            local ahead_line = original_lines[orig_i + look_ahead]
            if ahead_line == inst_line or 
               normalize_content(ahead_line) == normalize_content(inst_line) or
               get_core_content(ahead_line) == get_core_content(inst_line) then
              -- Found match, update indices
              orig_i = orig_i + look_ahead
              map.original_to_instrumented[orig_i] = inst_i
              map.instrumented_to_original[inst_i] = orig_i
              
              logger.debug("Found match after original look-ahead", {
                original_line = orig_i,
                instrumented_line = inst_i,
                look_ahead = look_ahead
              })
              
              found_match = true
              orig_i = orig_i + 1
              inst_i = inst_i + 1
              break
            end
          end
        end
      end
      
      -- If still no match found, log warning and increment both counters
      if not found_match then
        logger.warn("No match found for lines, skipping", {
          original_line = orig_i,
          instrumented_line = inst_i,
          original_content = orig_line,
          instrumented_content = inst_line
        })
        
        -- Try one more time with normalized content and core content comparison before giving up
        if normalize_content(orig_line):match("^%-%-") and normalize_content(inst_line):match("^%-%-") then
          -- For comments, use normalized comparison
          logger.debug("Attempting comment normalization", {
            original = normalize_content(orig_line),
            instrumented = normalize_content(inst_line)
          })
          map.original_to_instrumented[orig_i] = inst_i
          map.instrumented_to_original[inst_i] = orig_i
          found_match = true
        elseif get_core_content(orig_line) ~= "" and get_core_content(inst_line) ~= "" and
               #get_core_content(orig_line) > 3 and #get_core_content(inst_line) > 3 and
               (get_core_content(orig_line):find(get_core_content(inst_line), 1, true) or
                get_core_content(inst_line):find(get_core_content(orig_line), 1, true)) then
          -- Core content partial match for substantial code lines
          logger.debug("Found partial core content match", {
            original = get_core_content(orig_line),
            instrumented = get_core_content(inst_line)
          })
          map.original_to_instrumented[orig_i] = inst_i
          map.instrumented_to_original[inst_i] = orig_i
          found_match = true
        end
        
        -- If we still couldn't match, increment counters
        if not found_match then
          orig_i = orig_i + 1
          inst_i = inst_i + 1
        else
          orig_i = orig_i + 1
          inst_i = inst_i + 1
        end
      end
    end
    
    ::continue::
  end -- end of while loop
    
    -- Handle any remaining multi-line statement at EOF
    if in_multiline_statement and current_stmt_start then
      map.statement_boundaries[current_stmt_start] = {
        start = current_stmt_start,
        finish = orig_i - 1
      }
      logger.debug("Completed multi-line statement at EOF", {
        start = current_stmt_start,
        finish = orig_i - 1
      })
    end
  
  -- Process multi-line statement boundaries with simplified tracking handling
  for _, stmt_boundary in pairs(map.statement_boundaries) do
    local start_line = stmt_boundary.start
    local finish_line = stmt_boundary.finish
    
    -- Ensure all lines in multi-line statements have proper mappings
    local first_instrumented = map.original_to_instrumented[start_line]
    if first_instrumented then
      -- For each line in the multi-line statement
      for line = start_line + 1, finish_line do
        if not map.original_to_instrumented[line] then
          -- For unmapped lines in a multi-line statement
          local line_offset = line - start_line
          
          -- Calculate how many tracking lines exist between start and target position
          -- Calculate how many tracking lines exist between start and target position
          local tracking_count = 0
          local last_mapped_orig = nil
          local last_mapped_inst = nil
          
          -- Find the last mapped line before this one
          for l = line - 1, start_line, -1 do
            if map.original_to_instrumented[l] then
              last_mapped_orig = l
              last_mapped_inst = map.original_to_instrumented[l]
              break
            end
          end
          
          -- If we found a previous mapping, use that as reference
          if last_mapped_orig and last_mapped_inst then
            -- Calculate how many tracking lines exist in the range
            local search_end = last_mapped_inst + (line - last_mapped_orig) * 2
            
            for i = last_mapped_inst + 1, search_end do
              if map.tracking_lookup[i] then
                tracking_count = tracking_count + 1
              end
            end
            
            -- Map this line, accounting for tracking lines
            local line_offset = line - last_mapped_orig
            local instrumented_line = last_mapped_inst + line_offset + tracking_count
            map.original_to_instrumented[line] = instrumented_line
            map.instrumented_to_original[instrumented_line] = line
            logger.debug("Mapped multi-line statement line from last mapped", {
              original_line = line,
              instrumented_line = instrumented_line,
              last_mapped_orig = last_mapped_orig,
              last_mapped_inst = last_mapped_inst,
              tracking_count = tracking_count
            })
          else
            -- If no previous mapping found, use the start line as reference
            -- If no previous mapping found, use the start line as reference
            local orig_offset = line - start_line
            
            -- Count tracking lines between first_instrumented and target position
            local search_end = first_instrumented + orig_offset * 2
            
            for i = first_instrumented + 1, search_end do
              if map.tracking_lookup[i] then
                tracking_count = tracking_count + 1
              end
            end
            
            -- Map this line, accounting for tracking lines
            local instrumented_line = first_instrumented + orig_offset + tracking_count
            map.original_to_instrumented[line] = instrumented_line
            map.instrumented_to_original[instrumented_line] = line
            logger.debug("Mapped multi-line statement line from start", {
              original_line = line,
              instrumented_line = instrumented_line,
              first_instrumented = first_instrumented,
              orig_offset = orig_offset,
              tracking_count = tracking_count
            })
          end
        end
      end
    end
  end
  
  -- Count how many actual mappings we have
  local mapping_count = 0
  for _ in pairs(map.original_to_instrumented) do
    mapping_count = mapping_count + 1
  end
  
  local boundary_count = 0
  for _ in pairs(map.statement_boundaries) do
    boundary_count = boundary_count + 1
  end
  
  logger.debug("Created source map", {
    path = path,
    original_lines = #original_lines,
    instrumented_lines = #instrumented_lines,
    mappings = mapping_count,
    statement_boundaries = boundary_count
  })

  -- Log source map statistics
  if central_config and central_config.get and central_config.get("logging.level") == "debug" then
    local final_tracking_count = 0
    for _ in pairs(map.tracking_lookup) do
      final_tracking_count = final_tracking_count + 1
    end
    
    logger.debug("Source map created with final statistics", {
      original_lines = map.original_line_count,
      instrumented_lines = map.instrumented_line_count,
      tracking_lines = final_tracking_count
    })
  end

  return map
end -- Close the M.create function that started at line 81

-- Map original line to instrumented line, considering statement boundaries
---@param map SourceMapStructure Source map object
---@param original_line number Line number in original file
---@return number|nil instrumented_line Line number in instrumented file, or nil if not found
---@return string? error Error message if mapping failed
M.get_instrumented_line = function(map, original_line)
  if not map or type(map) ~= "table" then
    return nil, error_handler.validation_error("Invalid source map")
  end
  if not original_line or type(original_line) ~= "number" then
    return nil, error_handler.validation_error("Invalid line number", { line = original_line })
  end
  
  -- Check if this is part of a multi-line statement
  for start_line, boundary in pairs(map.statement_boundaries) do
    if original_line >= boundary.start and original_line <= boundary.finish then
      -- Use the mapping for the first line of the statement
      local instrumented_line = map.original_to_instrumented[boundary.start]
      if instrumented_line then
        -- Return the instrumented line for this statement boundary
        logger.debug("Mapped multi-line statement", {
          original_line = original_line,
          statement_start = boundary.start,
          statement_end = boundary.finish,
          instrumented_line = instrumented_line
        })
        return instrumented_line
      end
    end
  end
  
  -- Regular line mapping
  local instrumented_line = map.original_to_instrumented[original_line]
  if not instrumented_line then
    -- Try to find a nearby mapping if exact match doesn't exist
    local nearest_line = nil
    local nearest_distance = math.huge
    
    -- Look for nearest mapping within a small range
    for mapped_line, inst_line in pairs(map.original_to_instrumented) do
      local distance = math.abs(mapped_line - original_line)
      if distance < nearest_distance and distance <= 2 then
        nearest_line = mapped_line
        nearest_distance = distance
      end
    end
    
    if nearest_line then
      instrumented_line = map.original_to_instrumented[nearest_line]
      logger.debug("Using nearest line mapping", {
        original_line = original_line,
        nearest_line = nearest_line,
        instrumented_line = instrumented_line,
        distance = nearest_distance
      })
    else
      logger.warn("No mapping found for original line", { 
        line = original_line, 
        path = map.path,
        total_mappings = 0
      })
      return nil, error_handler.runtime_error("Invalid line number", { line = original_line })
    end
  end
  
  logger.debug("Mapped original line to instrumented", {
    original_line = original_line,
    instrumented_line = instrumented_line
  })
  
  return instrumented_line
end

M.get_original_line = function(map, instrumented_line)
  if not map or type(map) ~= "table" then
    return nil, error_handler.validation_error("Invalid source map")
  end
  if not instrumented_line or type(instrumented_line) ~= "number" then
    return nil, error_handler.validation_error("Invalid line number", { line = instrumented_line })
  end

  local original_line = map.instrumented_to_original[instrumented_line]

  -- Check if this is a tracking line
  if instrumented_line > 0 and instrumented_line <= map.instrumented_line_count then
    -- Check if this is a tracking line (tracking_lookup stores line numbers, not booleans)
    if map.tracking_lookup[instrumented_line] then
      logger.debug("Skipping mapping for tracking line", { 
        line = instrumented_line
      })
      return nil, error_handler.runtime_error("Cannot map tracking line", { line = instrumented_line })
    end
  end
  
  if not original_line then
    logger.warn("No mapping found for instrumented line", { 
      line = instrumented_line, 
      path = map.path,
      total_mappings = 0
    })
    return nil, error_handler.runtime_error("No mapping for instrumented line", { line = instrumented_line })
  end
  
  logger.debug("Mapped instrumented line to original", {
    instrumented_line = instrumented_line,
    original_line = original_line
  })
  
  return original_line
end

-- Helper function to count tracking lines between two instrumented lines
---@param map SourceMapStructure Source map object
---@param start_line number Start line in instrumented file
---@param end_line number End line in instrumented file
---@return number count Number of tracking lines in the range
local function count_tracking_lines(map, start_line, end_line)
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  
  local count = 0
  for line = start_line, end_line do
    if map.tracking_lookup[line] then
      count = count + 1
    end
  end
  
  return count
end

---@param map table Source map object
---@return string|nil serialized Serialized source map
M.serialize = function(map)
  local json = require("lib.tools.json")
  return json.encode(map)
end

-- Deserialize source map from string
---@param serialized string Serialized source map
---@return table|nil map Source map object, or nil if deserialization failed
---@return string? error Error message if deserialization failed
M.deserialize = function(serialized)
  local json = require("lib.tools.json")
  
  if not serialized or type(serialized) ~= "string" then
    return nil, error_handler.validation_error("Invalid serialized source map")
  end
  
  local success, map = pcall(json.decode, serialized)
  if not success then
    return nil, error_handler.runtime_error("Failed to decode source map", { error = map })
  end
  
  -- Validate the deserialized map
  local is_valid, err = M.validate(map)
  if not is_valid then
    return nil, error_handler.runtime_error("Invalid source map structure after deserialization", { error = err })
  end
  
  -- Reconstruct any missing fields or fix types
  if not map.statement_boundaries then
    map.statement_boundaries = {}
  end
  
  -- Verify mappings are symmetric
  local valid_mappings = true
  for orig_line, inst_line in pairs(map.original_to_instrumented) do
    local back_mapped = map.instrumented_to_original[inst_line]
    if back_mapped ~= orig_line then
      logger.warn("Asymmetric mapping in source map", {
        original_line = orig_line,
        instrumented_line = inst_line,
        back_mapped = back_mapped
      })
      valid_mappings = false
    end
  end
  
  if not valid_mappings then
    logger.warn("Fixing asymmetric mappings")
    -- Rebuild mappings to ensure symmetry
    local orig_to_inst = {}
    for orig_line, inst_line in pairs(map.original_to_instrumented) do
      orig_to_inst[orig_line] = inst_line
      map.instrumented_to_original[inst_line] = orig_line
    end
    map.original_to_instrumented = orig_to_inst
  end
  
  return map
end
-- Validate source map structure
---@param map any Source map to validate
---@return boolean|nil is_valid True if valid, nil if invalid
---@return string? error Error message if validation failed
M.validate = function(map)
  if not map or type(map) ~= "table" then
    return nil, error_handler.validation_error("Invalid source map structure")
  end
  
  -- Check required fields
  local required_fields = {
    "path", "original_to_instrumented", "instrumented_to_original", 
    "original_line_count", "instrumented_line_count"
  }
  
  for _, field in ipairs(required_fields) do
    if map[field] == nil then
      return nil, error_handler.validation_error(
        "Missing required field in source map", { field = field }
      )
    end
  end
  
  -- Check field types
  if type(map.path) ~= "string" then
    return nil, error_handler.validation_error("Invalid path field type")
  end
  
  if type(map.original_to_instrumented) ~= "table" then
    return nil, error_handler.validation_error("Invalid original_to_instrumented field type")
  end
  
  if type(map.instrumented_to_original) ~= "table" then
    return nil, error_handler.validation_error("Invalid instrumented_to_original field type")
  end
  
  if type(map.original_line_count) ~= "number" then
    return nil, error_handler.validation_error("Invalid original_line_count field type")
  end
  
  if type(map.instrumented_line_count) ~= "number" then
    return nil, error_handler.validation_error("Invalid instrumented_line_count field type")
  end
  
  -- Check tracking_lookup structure
  if map.tracking_lookup == nil then
    -- Initialize tracking_lookup if missing
    map.tracking_lookup = {}
    logger.debug("Initialized missing tracking_lookup field")
  elseif type(map.tracking_lookup) ~= "table" then
    return nil, error_handler.validation_error("Invalid tracking_lookup field type")
  end
  
  -- Convert any boolean tracking_lookup values to line numbers for backward compatibility
  for i, val in pairs(map.tracking_lookup) do
    if type(val) == "boolean" then
      map.tracking_lookup[i] = i
    end
  end
  
  return true
end

return M
