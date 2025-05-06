--- Example demonstrating the Markdown fixing utilities.
---
--- This example showcases how to use the `lib.tools.markdown` module to automatically
--- fix common formatting issues in Markdown files, such as inconsistent heading levels,
--- incorrect list numbering, and improper spacing around code blocks and headings.
---
--- It uses the `test_helper` module to create temporary Markdown files with known issues,
--- then runs the fixers (`fix_all_in_directory` and `fix_comprehensive`) and displays
--- the results.
---
--- @module examples.markdown_fixer_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.tools.markdown
--- @see lib.tools.filesystem.temp_file
--- @see lib.tools.test_helper
--- @usage
--- Run this example directly to see the fixing process:
--- ```bash
--- lua examples/markdown_fixer_example.lua
--- ```

-- Import required modules
local markdown = require("lib.tools.markdown")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("MarkdownFixerExample")

--- Helper function to log file content before and after fixing.
--- @param description string Description of the content stage (e.g., "Initial", "Fixed").
--- @param file_path string Path to the file.
local function log_file_content(description, file_path)
  local content, read_err = fs.read_file(file_path)
  if content then
    logger.info("\n--- " .. description .. " Content: " .. file_path .. " ---")
    print(content) -- Use print for direct multi-line output
    logger.info("-------------------------------------")
  else
    logger.error("Failed to read file for logging", { path = file_path, error = tostring(read_err) })
  end
end

-- Check if running directly
if arg and arg[0] and arg[0]:match("markdown_fixer_example%.lua$") then
  logger.info("=== Markdown Fixer Example ===")
  logger.info("Demonstrating fixing common Markdown issues.")

  -- 1. Create temporary directory and files with issues
  local temp_dir = test_helper.create_temp_test_directory("markdown_fixer_")
  if not temp_dir then
    logger.error("Failed to create temporary directory. Exiting.")
    return
  end
  logger.info("\nCreated temporary directory: " .. temp_dir.path)

  -- File 1: Heading issues (skipped levels, incorrect start)
  local content1 = [[
## Second Level Heading (Should become #)

Some text.

#### Fourth Level Heading (Should become ##)

More text.

### Third Level (Should become ##)
]]
  local file1_path = temp_dir:create_file("headings.md", content1)

  -- File 2: List numbering issues (incorrect order, mixed indentation)
  local content2 = [[
Regular paragraph.

1. First item.
3. Third item (should be 2).
2. Second item (should be 3).
    1. Nested item A.
    3. Nested item C (should be B).
4. Fourth item.

Another paragraph.
* Bullet item
* Another bullet
]]
  local file2_path = temp_dir:create_file("lists.md", content2)

  -- File 3: Spacing issues (missing lines around blocks)
  local content3 = [[
Text before heading.
# Heading
Text immediately after heading.
* List item 1
* List item 2
Text immediately after list.
```lua
local x = 1
```
Text immediately after code block.
]]
  local file3_path = temp_dir:create_file("spacing.md", content3)

  logger.info("\nCreated sample markdown files with issues.")

  -- Log initial contents
  log_file_content("Initial", file1_path)
  log_file_content("Initial", file2_path)
  log_file_content("Initial", file3_path)

  -- 2. Run fix_all_in_directory
  logger.info("\nRunning markdown.fix_all_in_directory on: " .. temp_dir.path)
  local fixed_count, fix_err = markdown.fix_all_in_directory(temp_dir.path)

  if fixed_count then
    logger.info("Fixing process completed. Files fixed/checked: " .. tostring(fixed_count))
  else
    logger.error("Error during fix_all_in_directory", { error = tostring(fix_err) })
  end

  -- Log final contents
  log_file_content("Fixed", file1_path)
  log_file_content("Fixed", file2_path)
  log_file_content("Fixed", file3_path)

  -- 3. Demonstrate fix_comprehensive on a string
  logger.info("\nDemonstrating markdown.fix_comprehensive on a string:")
  local raw_string = "## Bad Heading\n1. Item one\n3. Item three\n```\ncode\n```\nText"
  logger.info("\n--- Initial String ---")
  print(raw_string)
  logger.info("----------------------")

  local fixed_string, string_fix_err = markdown.fix_comprehensive(raw_string)
  if fixed_string then
    logger.info("\n--- Fixed String ---")
    print(fixed_string)
    logger.info("--------------------")
  else
    logger.error("Error fixing string", { error = tostring(string_fix_err) })
  end

  -- 4. Cleanup
  logger.info("\nExample complete. Temporary files will be cleaned up automatically.")
  -- logger.info("Cleanup finished.") -- No longer needed as it's automatic
else
  -- This part runs if the file is required, e.g., by the test runner
  -- We can include dummy tests so the file is runnable by `test.lua`
  local firmo = require("firmo")
  firmo.describe("Markdown Fixer Example Placeholder", function()
    firmo.it("should load without errors", function()
      firmo.expect(markdown).to.exist()
      firmo.expect(markdown.fix_comprehensive).to.be.a("function")
    end)
  end)
end
