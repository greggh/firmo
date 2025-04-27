--- Lua Syntax Checker Script
---
--- This script analyzes a Lua file to identify common syntax errors, structural issues,
--- and potential problems. It provides detailed feedback about:
---
--- 1. Basic syntax validation using Lua's loadfile
--- 2. Block structure analysis (balanced function/if/for/while/repeat blocks with end statements)
--- 3. Detection of suspicious patterns that might indicate errors (like JavaScript-style closing braces)
---
--- Usage:
---   lua scripts/check_syntax.lua <file_path>
---
--- Example:
---   lua scripts/check_syntax.lua lib/core/runner.lua
---
--- Features:
--- - Comprehensive block balance checking
--- - Line-by-line analysis
--- - Function stack tracing for unbalanced blocks
--- - Suspicious pattern identification
---
--- @author Firmo Team
--- @version 1.1.0
--- @script

-- Get the file path from command-line arguments
local file_path = arg[1]
if not file_path then
  print("Please provide a file path")
  os.exit(1)
end

--- Reads the content of a file. Exits script if the file cannot be opened.
---@param path string The path to the file to read.
---@return string content The file contents as a string.
---@throws string If file cannot be opened (exits script).
---@private
local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    print("Error: Could not open file " .. path)
    os.exit(1)
  end
  local content = file:read("*all")
  file:close()
  return content
end

--- Analyzes file content for block balancing (do/end, function/end, etc.) and
--- suspicious closing brace patterns. Prints warnings to the console.
--- NOTE: This analysis is basic and may produce false positives/negatives.
---@param content string The file content to analyze.
---@return nil
---@private
local function analyze_braces(content)
  -- Split the content into lines for line-by-line analysis
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local function_stack = {}
  local open_blocks = 0
  local in_comment_block = false

  for line_num, line in ipairs(lines) do
    -- Skip lines in comment blocks
    if line:match("^%s*%-%-%[%[") then
      in_comment_block = true
    end

    if in_comment_block then
      if line:match("%]%]") then
        in_comment_block = false
      end
      goto continue
    end

    -- Skip comment lines
    if line:match("^%s*%-%-") then
      goto continue
    end

    -- Check for function starts (but not in strings)
    local function_match = line:match("[^\"']-function[%s%(]")
    if
      function_match and not (line:match("^%s*%-%-") or line:match('".-function.-"') or line:match("'.-function.-'"))
    then
      table.insert(function_stack, { line = line_num, text = line })
      open_blocks = open_blocks + 1
    end

    -- Check for if/for/while/repeat/do blocks (but not in strings or comments)
    if
      (
        line:match("[^\"']-if%s+")
        or line:match("[^\"']-for%s+")
        or line:match("[^\"']-while%s+")
        or line:match("[^\"']-repeat%s+")
        or line:match("[^\"']-do%s*$")
      )
      and not (
        line:match("^%s*%-%-")
        or line:match('".-if.-"')
        or line:match("'.-if.-'")
        or line:match('".-for.-"')
        or line:match("'.-for.-'")
        or line:match('".-while.-"')
        or line:match("'.-while.-'")
        or line:match('".-repeat.-"')
        or line:match("'.-repeat.-'")
        or line:match('".-do.-"')
        or line:match("'.-do.-'")
      )
    then
      open_blocks = open_blocks + 1
    end

    -- Check for end statements (but not in strings or comments)
    local end_count = 0
    if not line:match("^%s*%-%-") then
      -- Count end statements not in strings
      local clean_line = line:gsub('".-"', ""):gsub("'.-'", "")
      for _ in clean_line:gmatch("end[%s%)%;,]") do
        end_count = end_count + 1
      end
      for _ in clean_line:gmatch("end$") do
        end_count = end_count + 1
      end
    end

    open_blocks = open_blocks - end_count

    if end_count > 0 and #function_stack > 0 then
      table.remove(function_stack)
    end

    -- Check for suspicious closing braces that might be mistaken for 'end'
    -- Skip if the line is a valid table closing or within a table definition
    local is_suspicious_brace = line:match("}%s*$")
      and not (
        line:match("{")
        or line:match("function")
        or line:match("if")
        or line:match("for")
        or line:match("while")
        or line:match("repeat")
        or line:match("return%s+[{]") -- Return statement with table
        or line:match("=%s*[{]") -- Assignment with table
        or line:match(",%s*[{]") -- Table element with subtable
        or line:match("%([^)]*[{]")
      ) -- Function call with table arg

    if is_suspicious_brace and not (line:match("^%s*%-%-") or line:match('".-}.-"') or line:match("'.-}.-'")) then
      -- Do a deeper check for common Lua table patterns
      local prev_line_index = line_num - 1
      if prev_line_index > 0 then
        local prev_line = lines[prev_line_index]
        -- Skip if previous line has table opening or contains table key pattern
        if prev_line and (prev_line:match("[{]") or prev_line:match("[%w_]+%s*=%s*")) then
          goto continue
        end
      end

      print(string.format("WARNING: Line %d has suspicious closing brace: %s", line_num, line))
    end

    ::continue::
  end

  -- Report on block balance
  if open_blocks > 0 then
    print(string.format("WARNING: Unbalanced blocks: %d more 'function/if/for/while/repeat' than 'end'", open_blocks))
    for _, func in ipairs(function_stack) do
      print(string.format("  Unclosed function at line %d: %s", func.line, func.text))
    end
  elseif open_blocks < 0 then
    print(string.format("WARNING: Unbalanced blocks: %d more 'end' than 'function/if/for/while/repeat'", -open_blocks))
  else
    print("Block structure looks balanced")
  end
end

-- Main execution
local content = read_file(file_path)
print("Analyzing file: " .. file_path)
analyze_braces(content)

-- Try to load the file and check for syntax errors
local result, err = loadfile(file_path)
if result then
  print("Syntax check passed: No syntax errors found")
else
  print("Syntax error found: " .. err)
end
