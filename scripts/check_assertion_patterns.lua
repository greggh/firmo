#!/usr/bin/env lua
--- Check Assertion Patterns Script
---
--- Scans Lua files in a specified directory (default: `tests`) for potentially
--- incorrect or outdated assertion patterns based on Firmo's `expect` style
--- and suggests replacements.
---
--- Usage: lua scripts/check_assertion_patterns.lua [directory]
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

--- Array of pattern definitions to check.
--- Each entry contains: name, description, pattern (Lua string pattern), suggestion.
---@type {name: string, description: string, pattern: string, suggestion: string}[]
local PATTERNS = {
  {
    name = "Numeric to.be",
    description = "Use .to.equal() instead of .to.be() for numeric equality",
    pattern = [[expect%([^)]+%)%.to%.be%(%s*%-?%d+%.?%d*%s*[%),]],
    suggestion = "expect(value).to.equal(number)",
  },
  {
    name = "Numeric to_not.be",
    description = "Use .to_not.equal() instead of .to_not.be() for numeric equality",
    pattern = [[expect%([^)]+%)%.to_not%.be%(%s*%-?%d+%.?%d*%s*[%),]],
    suggestion = "expect(value).to_not.equal(number)",
  },

  -- Prefer .be_nil()-style helper instead of plain comparison to nil
  {
    name = "Nil to.be",
    description = "Use .to.be.nil() for nil checks (or .to_not.exist() for the opposite)",
    pattern = [[expect%([^)]+%)%.to%.be%(%s*nil%s*[%),]],
    suggestion = "expect(value).to.be.nil()",
  },
  {
    name = "Nil to_not.be",
    description = "Use .to_not.be.nil() for nil checks (or .to.exist())",
    pattern = [[expect%([^)]+%)%.to_not%.be%(%s*nil%s*[%),]],
    suggestion = "expect(value).to_not.be.nil()",
  },

  ----------------------------------------------------------------------
  -- Truthiness helpers ------------------------------------------------
  ----------------------------------------------------------------------

  {
    name = "Boolean true comparison",
    description = "Use .to.be_truthy() instead of .to.be(true)",
    pattern = [[expect%([^)]+%)%.to%.be%(%s*true%s*[%),]],
    suggestion = "expect(value).to.be_truthy()",
  },
  {
    name = "Boolean false comparison",
    description = "Use .to_not.be_truthy() (or .to.be_falsy()) instead of .to.be(false)",
    pattern = [[expect%([^)]+%)%.to%.be%(%s*false%s*[%),]],
    suggestion = "expect(value).to_not.be_truthy()",
  },

  -- Catch accidental use of the chaining form `.to.be.truthy()` instead
  -- of the dedicated helper `.to.be_truthy()`
  {
    name = "Chained truthy helper",
    description = "Prefer .be_truthy() helper over .be.truthy() chain",
    pattern = [[expect%([^)]+%)%.to%.be%.truthy%(%s*%)]],
    suggestion = "expect(value).to.be_truthy()",
  },
  {
    name = "Chained falsy helper",
    description = "Prefer .be_falsy() helper over .be.falsy() chain",
    pattern = [[expect%([^)]+%)%.to%.be%.falsy%(%s*%)]],
    suggestion = "expect(value).to.be_falsy()  -- or .to.be_falsey()",
  },

  ----------------------------------------------------------------------
  -- Range / numeric comparison helpers --------------------------------
  ----------------------------------------------------------------------

  {
    name = "Manual greater-than comparison",
    description = "Use .to.be_greater_than() helper",
    pattern = [[expect%([^)]+%)%.to%.be%_greater%_than?%s*==?]], -- any relic pattern
    suggestion = "expect(number).to.be_greater_than(other)",
  },
  {
    name = "Manual less-than comparison",
    description = "Use .to.be_less_than() helper",
    pattern = [[expect%([^)]+%)%.to%.be%_less%_than?%s*==?]],
    suggestion = "expect(number).to.be_less_than(other)",
  },

  ----------------------------------------------------------------------
  -- String helpers ----------------------------------------------------
  ----------------------------------------------------------------------

  {
    name = "Starts-with Lua pattern",
    description = "Prefer .to.start_with() over string.match at assertion site",
    pattern = [[expect%([^)]+%)%.to%.match%(%s*"%^]],
    suggestion = "expect(str).to.start_with(prefix)",
  },
  {
    name = "Ends-with Lua pattern",
    description = "Prefer .to.end_with() over string.match at assertion site",
    pattern = [[expect%([^)]+%)%.to%.match%(%s*".-%$"]],
    suggestion = "expect(str).to.end_with(suffix)",
  },

  ----------------------------------------------------------------------
  -- Legacy Busted helpers ---------------------------------------------
  ----------------------------------------------------------------------

  {
    name = "Busted assert.equals",
    description = "Use expect(actual).to.equal(expected)",
    pattern = [[assert%.equals%s*%([^%)]*]], -- any call
    suggestion = "expect(actual).to.equal(expected)",
  },
  {
    name = "Busted assert.are.equal",
    description = "Use expect(actual).to.equal(expected)",
    pattern = [[assert%.are%.equal%s*%([^%)]*]],
    suggestion = "expect(actual).to.equal(expected)",
  },
  {
    name = "Busted assert.is_true",
    description = "Use expect(value).to.be_truthy()",
    pattern = [[assert%.is_true%s*%([^%)]*]],
    suggestion = "expect(value).to.be_truthy()",
  },
  {
    name = "Busted assert.is_false",
    description = "Use expect(value).to_not.be_truthy()",
    pattern = [[assert%.is_false%s*%([^%)]*]],
    suggestion = "expect(value).to_not.be_truthy()",
  },
  {
    name = "Busted assert.is_nil",
    description = "Use expect(value).to.be.nil()",
    pattern = [[assert%.is_nil%s*%([^%)]*]],
    suggestion = "expect(value).to.be.nil()",
  },
  {
    name = "Busted assert.is_not_nil",
    description = "Use expect(value).to.exist()",
    pattern = [[assert%.is_not_nil%s*%([^%)]*]],
    suggestion = "expect(value).to.exist()",
  },
}

--- ANSI color codes for terminal output.
---@type table<string, string>
local colors = {
  reset = "\27[0m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  magenta = "\27[35m",
  cyan = "\27[36m",
  white = "\27[37m",
}

--- Checks a single file for incorrect assertion patterns defined in `PATTERNS`.
--- Reads the file line by line and applies regex matching.
---@param file_path string The path to the Lua file.
---@return table[] findings An array of finding objects, where each object contains:
---  `pattern` (string): Name of the matched pattern definition.
---  `description` (string): Description of the pattern issue.
---  `line_number` (number): Line number where the pattern was found.
---  `line` (string): The content of the line (trimmed).
---  `suggestion` (string): Suggested replacement pattern.
---  `file_path` (string): Path of the file where the finding occurred.
--- Returns an empty table if no patterns are found or if the file cannot be read.
local function check_file(file_path)
  local content = get_fs().read_file(file_path)
  if not content then
    print(colors.red .. "Could not read file: " .. file_path .. colors.reset)
    return {}
  end

  local findings = {}
  local line_number = 1
  local lines = {}

  -- Split content into lines
  for line in content:gmatch("([^\n]*)\n?") do
    lines[line_number] = line
    line_number = line_number + 1
  end

  -- Check each line for each pattern
  for line_num, line in pairs(lines) do
    for _, pattern_def in ipairs(PATTERNS) do
      if line:match(pattern_def.pattern) then
        table.insert(findings, {
          pattern = pattern_def.name,
          description = pattern_def.description,
          line_number = line_num,
          line = line:gsub("^%s+", ""):gsub("%s+$", ""),
          suggestion = pattern_def.suggestion,
          file_path = file_path,
        })
      end
    end
  end

  return findings
end

--- Scans a directory recursively for Lua files (using `get_fs().discover_files`, excluding vendor folders)
--- and aggregates findings from `check_file` for each found file.
---@param dir_path string The directory path to scan.
---@return table[] findings An array of finding summary objects per file, where each object contains:
---  `file_path` (string): Path of the file with findings.
---  `findings` (table[]): An array of finding objects returned by `check_file` for this file.
--- Returns an empty table if no files with issues are found.
local function scan_directory(dir_path)
  local findings = {}
  local files = get_fs().discover_files({ dir_path }, { "*.lua" })

  for _, file_path in ipairs(files) do
    -- Skip vendor directories and non-test files
    if not file_path:match("/vendor/") then
      local file_findings = check_file(file_path)

      if #file_findings > 0 then
        table.insert(findings, {
          file_path = file_path,
          findings = file_findings,
        })
      end
    end
  end

  return findings
end

--- Main function for the script.
--- Parses command line argument (directory), scans files using `scan_directory`,
--- prints formatted results (using colors) to the console, and returns an exit code.
---@return number exit_code 0 if no issues found, 1 if issues found.
local function main()
  local dir_path = arg[1] or "tests"
  print(colors.cyan .. "Checking for assertion patterns in: " .. dir_path .. colors.reset)

  local findings = scan_directory(dir_path)

  -- Print findings
  if #findings == 0 then
    print(colors.green .. "No incorrect assertion patterns found!" .. colors.reset)
    return 0
  end

  -- Format output
  print(colors.yellow .. string.format("Found %d files with incorrect assertion patterns:", #findings) .. colors.reset)

  local total_issues = 0
  for _, file_data in ipairs(findings) do
    print(colors.blue .. "\nFile: " .. file_data.file_path .. colors.reset)

    for _, finding in ipairs(file_data.findings) do
      total_issues = total_issues + 1
      print(colors.yellow .. string.format("  Line %d: %s", finding.line_number, finding.pattern) .. colors.reset)
      print(colors.white .. string.format("    %s", finding.line) .. colors.reset)
      print(colors.green .. string.format("    Suggestion: %s", finding.suggestion) .. colors.reset)
    end
  end

  print(colors.red .. string.format("\nTotal issues found: %d in %d files", total_issues, #findings) .. colors.reset)
  return 1
end

-- Run main function
os.exit(main())
