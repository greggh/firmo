--- Example demonstrating the Firmo codefix module for finding and fixing Lua code quality issues.
---
--- This example showcases the `lib.tools.codefix` module:
--- - Creates temporary Lua files with various code style/quality issues (unused variables, trailing whitespace, string concatenation).
--- - Uses `firmo.codefix.run_cli({"find", ...})` to locate Lua files within the temporary directory.
--- - Runs `firmo.codefix.fix_lua_files()` on the temporary directory to automatically fix identified issues.
--- - Configures codefix behavior (e.g., report generation) using `central_config.set()`.
--- - Displays the content of the files before and after fixing (implicitly, by showing final state).
--- - Shows the generated JSON report file content.
--- - Uses `temp_file` module for automatic cleanup of the temporary directory and files.
---
--- @module examples.codefix_example
--- @see lib.tools.codefix
--- @see lib.core.central_config
--- @see lib.tools.filesystem.temp_file
--- @usage
--- Run this example directly to see code fixing in action:
--- ```bash
--- lua examples/codefix_example.lua
--- ```

local firmo = require("firmo")

-- Load required modules
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")
local central_config = require("lib.core.central_config")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("CodefixExample")
-- NOTE: Using print() as fallback due to potential internal logger errors observed previously.

print("--- Firmo Codefix Module Example ---") -- Use print as logger fallback
print("Demonstrates finding and fixing Lua code quality issues.")

--- Creates a temporary directory and populates it with example Lua files
-- containing various code quality issues (unused vars, whitespace, etc.).
-- Register  -- Create a temporary directory, automatically registered for cleanup
local temp_dir_path, create_err = temp_file.create_temp_directory("codefix_example_")
if not temp_dir_path then
  print("ERROR: Failed to create temporary directory: " .. tostring(create_err or "unknown error")) -- Use print
  return nil, nil
end
print("Created temporary example directory: " .. temp_dir_path) -- Use print

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
  -- No need to register, create_temp_directory handles dir cleanup
  table.insert(files, filename1)
  print("Created example file: " .. filename1) -- Use print
else
  print("ERROR creating file '" .. filename1 .. "': " .. tostring(err or "unknown error")) -- Use print
end

-- File 2: Trailing whitespace and mixed indentation
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
  -- No need to register file
  table.insert(files, filename2)
  print("Created example file: " .. filename2) -- Use print
else
  print("ERROR creating file '" .. filename2 .. "': " .. tostring(err or "unknown error")) -- Use print
end

-- File 3: String concatenation and potential formatting issues
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
  -- No need to register file
  table.insert(files, filename3)
  print("Created example file: " .. filename3) -- Use print
else
  print("ERROR creating file '" .. filename3 .. "': " .. tostring(err or "unknown error")) -- Use print
end

-- Only return if directory creation was successful
if #files == 3 then -- Check if all files were intended to be created
  return temp_dir_path, files
else
  return nil, nil -- Indicate failure
end

--- Runs various codefix operations (`run_cli("find", ...)`, `fix_lua_files()`) on the
-- files within the temporary directory and displays the results and fixed content.
-- @param temp_dir_path string The path to the temporary directory containing example files.
-- @param relative_files string[] A list of relative paths to the example files within the `temp_dir_path`.
--- @within examples.codefix_example
local function run_multi_file_codefix(temp_dir_path, relative_files)
  print("\n--- Running Codefix on Example Files ---") -- Use print
  print(string.rep("-", 60))

  -- Configure codefix via central_config before running operations
  central_config.set("codefix.enabled", true)
  central_config.set("codefix.verbose", true) -- Show details during fixing
  central_config.set("codefix.fixers", { -- Explicitly enable fixers (optional, defaults are usually fine)
    unused_vars = true,
    trailing_whitespace = true,
    string_concat = true,
    formatting = true, -- Enable general formatting via stylua
  })
  central_config.set("codefix.stylua.enabled", true) -- Ensure stylua is enabled

  -- 1. Demonstrate the find functionality via run_cli
  print("\n1. Finding Lua files using run_cli('find', ...):") -- Use print
  print(string.rep("-", 60))
  -- The `find` command prints results directly to stdout when verbose is enabled.
  local find_success = firmo.codefix.run_cli({ "find", temp_dir_path, "--include", "%.lua$" })
  if not find_success then
    print("ERROR: codefix 'find' command failed")
  end

  -- 2. Demonstrate directory-based fixing using fix_lua_files()
  print("\n2. Running fix_lua_files() on directory with report generation:") -- Use print
  print(string.rep("-", 60))
  local report_path = fs.join_paths(temp_dir_path, "codefix_report.json")
  local options = {
    sort_by_mtime = true,
    generate_report = true,
    sort_by_mtime = true, -- Example option
    generate_report = true,
    report_file = report_path,
  }

  -- Run the fixing process on the entire directory
  local dir_fixed_successfully, dir_results = firmo.codefix.fix_lua_files(temp_dir_path, options)

  if dir_fixed_successfully then
    print("\n✅ Directory check/fix completed successfully via fix_lua_files().")
  else
    print("\n❌ Directory check/fix failed or had errors via fix_lua_files().")
  end

  -- 3. Display summary results from fix_lua_files() return value
  print("\n3. Summary of fix_lua_files() results:") -- Use print
  print(string.rep("-", 60))
  for _, result in ipairs(dir_results or {}) do
    local path = result.file
    if result.success then
      print("  - Fixed/Checked:", path)
    elseif result.error then
      print("  - Error:", path, "(", result.error, ")")
    elseif result.error then
      print(string.format("  - ❌ Error fixing %s: %s", path, tostring(result.error)))
    elseif result.skipped then
      print(string.format("  - ⏩ Skipped %s: %s", path, result.reason or "No reason given"))
    else
      print("  - ? Unknown status for:", path) -- Handle unexpected case
    end
  end

  -- Display content of potentially fixed files
  print("\n--- Content of files AFTER codefix ---") -- Use print
  for _, rel_filename in ipairs(relative_files) do
    local abs_filename = fs.join_paths(temp_dir_path, rel_filename)
    print("\nFile: " .. abs_filename)
    print("\n--- File: " .. rel_filename .. " ---")
    print(string.rep("-", 40))
    local content, read_err = fs.read_file(abs_filename)
    if content then
      print(content) -- Print file content to show the result of fixes
    else
      print("ERROR reading file '" .. abs_filename .. "': " .. tostring(read_err or "unknown error")) -- Use print
    end
    print(string.rep("-", 40))
  end

  -- 4. Display the generated JSON report file content
  if options.generate_report and options.report_file and fs.file_exists(options.report_file) then
    print("\n4. Content of Generated Report (" .. options.report_file .. "):") -- Use print
    print(string.rep("-", 60))
    local report_content, report_read_err = fs.read_file(options.report_file)
    if report_content then
      print(report_content) -- Print report JSON content
    else
      print("ERROR reading report file: " .. tostring(report_read_err or "unknown error")) -- Use print
    end
  else
    print("\nReport file was not generated or not found at:", options.report_file)
  end
end

-- Main execution flow
local temp_dir_path, relative_files = create_example_files()

if temp_dir_path and relative_files and #relative_files > 0 then
  run_multi_file_codefix(temp_dir_path, relative_files)
else
  print("\nSkipping codefix run due to errors creating example files.")
end

print("\n--- Codefix Example Complete ---") -- Use print

-- Cleanup is handled automatically by temp_file module if files/dirs were registered.
-- Explicitly calling cleanup_all() ensures cleanup even if run outside test runner.
temp_file.cleanup_all()
print("Temporary files and directories cleaned up.") -- Use print
