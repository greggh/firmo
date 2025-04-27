--- codefix_example.lua
--
-- This example demonstrates the `firmo.codefix` module, which can be used
-- to find and automatically fix common Lua code quality issues across
-- multiple files or entire directories. It shows:
-- - Finding Lua files using `run_cli({"find", ...})`.
-- - Fixing all Lua files in a directory using `fix_lua_files()`.
-- - Generating a JSON report of the fixes.
-- - Configuration via `central_config`.
-- - Integration with `temp_file` for managing example files.
--
-- Run this example directly: lua examples/codefix_example.lua
--

local firmo = require("firmo")

-- Load required modules
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")
local central_config = require("lib.core.central_config")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("CodefixExample")
-- NOTE: Commenting out logger calls due to internal error in logging module (table.concat / gsub issue).

logger.info("This example demonstrates the enhanced codefix module in firmo")
logger.info("The codefix module can be used to fix common Lua code quality issues across multiple files")

--- Creates a temporary directory and populates it with example Lua files
-- containing various code quality issues to be fixed.
-- @return string temp_dir_path The path to the created temp directory.
-- @return string[] files A list of relative paths to the created example files within the temp dir.
local function create_example_files()
  -- Create a temporary directory
  local temp_dir_path = temp_file.create_temp_directory("codefix_example_")
  if not temp_dir_path then
    logger.error("Failed to create temporary directory")
    -- print("ERROR: Failed to create temporary directory") -- Use print as logger is disabled
    return nil, nil
  end
  logger.info("Created example directory: " .. temp_dir_path)

  -- Create multiple files with different quality issues
  local files = {}

  -- File 1: Unused variables and arguments
  local filename1 = "unused_vars.lua"
  local content1 = [[
-- Example file with unused variables and arguments

local function test_function(param1, param2, param3)
  local unused_local = "test"
  local another_unused = 42
  return param1 + 10
end

local function another_test(a, b, c, d)
  local result = a * b
  return result
end

return {
  test_function = test_function,
  another_test = another_test
}
]]

  local file_path1 = fs.join_paths(temp_dir_path, filename1)
  local success, err = fs.write_file(file_path1, content1)
  if success then
    temp_file.register_file(file_path1) -- Register after successful write
    table.insert(files, filename1)
    logger.info("Created: " .. filename1)
  else
    logger.error("Error creating file: " .. (err or "unknown error")) -- Keep error log
    -- print("ERROR creating file: " .. (err or "unknown error"))
  end

  -- File 2: Trailing whitespace in multiline strings
  local filename2 = "whitespace.lua"
  local content2 = [=[
-- Example file with trailing whitespace issues

local function get_multiline_text()
  local text = [[
    This string has trailing whitespace
    on multiple lines
    that should be fixed
  ]]
  return text
end

local function get_another_text()
  return [[
    Another string with
    trailing whitespace
  ]]
end

return {
  get_multiline_text = get_multiline_text,
  get_another_text = get_another_text
}
]=]

  local file_path2 = fs.join_paths(temp_dir_path, filename2)
  local success, err = fs.write_file(file_path2, content2)
  if success then
    temp_file.register_file(file_path2) -- Register after successful write
    table.insert(files, filename2)
    logger.info("Created: " .. filename2)
  else
    logger.error("Error creating file: " .. (err or "unknown error")) -- Keep error log
    -- print("ERROR creating file: " .. (err or "unknown error"))
  end

  -- File 3: String concatenation issues
  local filename3 = "string_concat.lua"
  local content3 = [[
-- Example file with string concatenation issues

local function build_message(name, age)
  local greeting = "Hello " .. "there " .. name .. "!"
  local age_text = "You are " .. age .. " " .. "years " .. "old."
  return greeting .. " " .. age_text
end

local function build_html()
  return "<div>" .. "<h1>" .. "Title" .. "</h1>" .. "<p>" .. "Content" .. "</p>" .. "</div>"
end

return {
  build_message = build_message,
  build_html = build_html
}
]]

  local file_path3 = fs.join_paths(temp_dir_path, filename3)
  local success, err = fs.write_file(file_path3, content3)
  if success then
    temp_file.register_file(file_path3) -- Register after successful write
    table.insert(files, filename3)
    logger.info("Created: " .. filename3)
  else
    logger.error("Error creating file: " .. (err or "unknown error")) -- Keep error log
    -- print("ERROR creating file: " .. (err or "unknown error"))
  end

  return temp_dir_path, files
end

--- Runs various codefix operations (find, fix_lua_files) on the
-- files within the temporary directory and displays the results.
-- @param temp_dir_path string The path to the temp directory.
-- @param relative_files string[] A list of relative paths within the temp_dir.
local function run_multi_file_codefix(temp_dir_path, relative_files)
  logger.info("\nRunning enhanced codefix on multiple files")
  logger.info(string.rep("-", 60))

  -- Enable codefix via central_config
  central_config.set("codefix.enabled", true)
  central_config.set("codefix.verbose", true)

  -- 1. Demonstrate the find functionality
  logger.info("\n1. Finding Lua files in the directory:")
  logger.info(string.rep("-", 60))
  -- print("\n1. Finding Lua files in the directory:") -- Use print as logger disabled
  -- print(string.rep("-", 60))
  local cli_success = firmo.codefix.run_cli({ "find", temp_dir_path, "--include", "%.lua$" })
  if not cli_success then
    print("ERROR: 'find' command failed")
  end

  -- 2. Demonstrate directory-based fixing with options
  logger.info("\n2. Running codefix on directory with options:")
  -- print("\n2. Running codefix on directory with options:") -- Use print as logger disabled
  print(string.rep("-", 60))
  local options = {
    sort_by_mtime = true,
    generate_report = true,
    report_file = fs.join_paths(temp_dir_path, "codefix_report.json"),
  }

  -- Actually run fix_lua_files for the directory
  local dir_success, dir_results = firmo.codefix.fix_lua_files(temp_dir_path, options)

  if dir_success then
    print("✅ Directory checked/fixed successfully (fix_lua_files)")
  else
    print("❌ Directory check/fix failed (fix_lua_files)")
  end

  -- 3. Show results of fixed files (from directory fix)
  logger.info("\n3. Results of fixed files:")
  logger.info(string.rep("-", 60))
  -- print("\n3. Results of fixed files:") -- Use print as logger disabled
  -- print(string.rep("-", 60))
  for _, result in ipairs(dir_results or {}) do
    local path = result.file
    if result.success then
      print("  - Fixed/Checked:", path)
    elseif result.error then
      print("  - Error:", path, "(", result.error, ")")
    else
      print("  - Unknown status:", path) -- Handle case where result might be incomplete
    end
  end

  -- Display content of fixed files
  print("\nContent of fixed files:") -- Use print as logger disabled
  local absolute_files_to_show = {}
  for _, rel_file in ipairs(relative_files) do
    table.insert(absolute_files_to_show, fs.join_paths(temp_dir_path, rel_file))
  end
  for _, abs_filename in ipairs(absolute_files_to_show) do
    print("\nFile: " .. abs_filename)
    print(string.rep("-", 40))
    local content, err = fs.read_file(abs_filename)
    if content then
      print(content) -- Print content to show fixes
    else
      logger.error("Error reading file: " .. (err or "unknown error"))
      -- print("ERROR reading file: " .. (err or "unknown error"))
    end
  end

  -- 4. If a report was generated, show it
  if options.generate_report and options.report_file then
    logger.info("\n4. Generated report:")
    logger.info(string.rep("-", 60))
    -- print("\n4. Generated report:") -- Use print as logger disabled
    -- print(string.rep("-", 60))
    local report_content, err = fs.read_file(options.report_file)
    if report_content then
      print(report_content) -- Print report content
    else
      logger.error("Error reading report file: " .. (err or "unknown error"))
      -- print("ERROR reading report file: " .. (err or "unknown error"))
    end
  end
end -- Close run_multi_file_codefix function

-- Run the example
local temp_dir_path, relative_files = create_example_files()
if temp_dir_path and #relative_files > 0 then
  run_multi_file_codefix(temp_dir_path, relative_files)
  -- Cleanup is handled by temp_file.cleanup_all() below
end

logger.info("\nExample complete")
-- print("\nExample complete") -- Use print as logger disabled

-- Clean up all temporary files/directories created by temp_file
