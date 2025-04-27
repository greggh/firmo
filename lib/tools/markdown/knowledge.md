# lib/tools/markdown Knowledge

## Purpose

The `lib/tools/markdown` module provides basic utilities aimed at finding and automatically fixing common formatting inconsistencies within Markdown (`.md`) files. Currently, its primary implemented features focus on normalizing heading levels (e.g., `#`, `##`) and correcting numbering in ordered lists (`1.`, `2.`). It can process individual content strings or operate on all `.md` files within a directory. The module is also designed to integrate with the `lib/tools/codefix` system, allowing these markdown fixes to be part of a broader code quality workflow.

**Important Note:** This module is currently **partially implemented**. Many functions documented in the source code comments are placeholders and do not yet provide functionality (see "Unimplemented Features" below).

## Key Concepts

- **`find_markdown_files(dir?)`:** Locates `.md` files within a specified directory (defaulting to `.`) using the `lib.tools.filesystem.discover_files` function. It handles recursive searching and returns a list of found file paths or `nil, error_object` on failure (e.g., directory not found).

- **`fix_heading_levels(content)`:** Parses Markdown content to identify ATX-style headings (`#`, `##`, etc.). It attempts to:
    1.  Normalize the highest-level heading found to `#` (level 1).
    2.  Adjust subsequent heading levels proportionally.
    3.  Ensure that heading levels do not skip (e.g., prevent a `#` followed directly by `###` by adjusting the `###` to `##`).
    Returns the modified content string or `nil, error_object` if processing fails.

- **`fix_list_numbering(content)`:** Parses content to find ordered list items (`1.`, `2.`, etc.). It corrects the numbering sequence for each list, restarting the count for new lists. It respects indentation levels to correctly handle nested ordered lists, restarting numbering for sub-lists. Returns the modified content string or `nil, error_object` on failure.

- **`fix_comprehensive(content)`:** Acts as a primary fixing function that applies multiple implemented fixes:
    1.  Calls `fix_heading_levels`.
    2.  Calls `fix_list_numbering` on the result.
    3.  Includes logic to preserve code blocks (content within ` ``` ` fences) during list/heading processing.
    4.  Applies some basic spacing rules, such as adding blank lines around headings and code blocks.
    Returns the comprehensively fixed content string or `nil, error_object`.

- **`fix_all_in_directory(dir?)`:** Orchestrates fixing multiple files:
    1.  Calls `find_markdown_files` to get a list of `.md` files.
    2.  Iterates through each file path.
    3.  Reads the file content (using `error_handler.safe_io_operation`).
    4.  Applies `fix_comprehensive` to the content (using `error_handler.try`).
    5.  If the content was modified, writes it back to the original file (using `error_handler.safe_io_operation`).
    6.  Logs progress and errors using `lib/tools/logging`.
    Returns the count of successfully fixed files or `nil, error_object` if the initial file finding fails significantly.

- **`register_with_codefix(codefix)`:** Provides a mechanism to register the `fix_comprehensive` function as a custom fixer within the `lib.tools.codefix` module. This allows `.md` files to be processed automatically when running `codefix`.

- **Error Handling:** Functions generally follow the standard Firmo pattern, returning `result, err` where `err` is a structured error object from `lib/tools/error_handler`. File I/O uses `safe_io_operation`, while processing logic often uses `try` internally.

- **Unimplemented Features:** The following functions listed in the source code's `@class` documentation are **currently placeholders and NOT IMPLEMENTED**:
    - `validate_markdown`
    - `fix_code_blocks` (beyond basic preservation)
    - `fix_links`
    - `fix_tables`
    - `fix_spacing` (beyond basic rules in `fix_comprehensive`)
    - `fix_file` (use `fix_comprehensive` on content instead)
    - `generate_table_of_contents`
    - `extract_headings`
    *Users should not expect these functions to work until they are explicitly implemented.*

## Usage Examples / Patterns

### Pattern 1: Applying Comprehensive Fixes to a String

```lua
--[[
  Fix headings and list numbering in a Markdown string.
]]
local markdown = require("lib.tools.markdown")
local error_handler = require("lib.tools.error_handler")

local content = [[
## Section 1
Some text.

### Subsection 1.1
1. Item A
3. Item B  -- Incorrect number

## Section 2
10. Item C -- Should start at 1
]]

local success, fixed_content_or_err = error_handler.try(markdown.fix_comprehensive, content)

if success then
  print("Fixed Content:\n" .. fixed_content_or_err)
  -- Expected output (roughly):
  -- # Section 1
  --
  -- Some text.
  --
  -- ## Subsection 1.1
  --
  -- 1. Item A
  -- 2. Item B
  --
  -- # Section 2
  --
  -- 1. Item C
else
  print("Error fixing markdown: " .. fixed_content_or_err.message)
end
```

### Pattern 2: Fixing All Markdown Files in a Directory

```lua
--[[
  Find and apply comprehensive fixes to all .md files in the 'docs/' directory.
]]
local markdown = require("lib.tools.markdown")
local error_handler = require("lib.tools.error_handler")

print("Starting markdown fix process...")
local fixed_count, err = markdown.fix_all_in_directory("docs/")

if err then
  print("Error during markdown fixing process: " .. err.message)
elseif fixed_count then
  print("Successfully processed markdown files. Files fixed: " .. fixed_count)
else
  print("Markdown fixing completed, but encountered issues finding files.")
end
```

### Pattern 3: Integration with `codefix`

```lua
--[[
  Conceptual example of how registration might look (actual usage is via codefix CLI).
]]
-- Assuming 'codefix' module is loaded and initialized elsewhere
-- local codefix = require("lib.tools.codefix")
-- local markdown = require("lib.tools.markdown")

-- markdown.register_with_codefix(codefix)

-- After registration, running 'codefix fix .' or similar would automatically
-- apply markdown.fix_comprehensive to any .md files found.
```

## Related Components / Modules

- **`lib/tools/markdown/init.lua`**: The source code implementation of this module.
- **`lib/tools/filesystem/knowledge.md`**: Relied upon by `find_markdown_files` and `fix_all_in_directory` for file discovery, reading, and writing operations.
- **`lib/tools/error_handler/knowledge.md`**: Used extensively for handling errors during file operations and content processing, returning standardized error objects.
- **`lib/tools/logging/knowledge.md`**: Used for logging progress, warnings, and errors during file processing (`fix_all_in_directory`).
- **`lib/tools/codefix/knowledge.md`**: The target module for integration via `register_with_codefix`, allowing markdown fixes within the code quality workflow.

## Best Practices / Critical Rules (Optional)

- **Understand Scope:** Be aware that the module currently only fixes heading levels and ordered list numbering, along with basic spacing. Do not rely on it for more complex Markdown validation or fixing (links, tables, etc.).
- **Use Version Control:** Before running `fix_all_in_directory` on important documents, ensure they are committed to a version control system (like Git). This allows you to easily review the automated changes and revert them if necessary.
- **Prefer `codefix` Integration:** For applying fixes consistently across a project, integrating this module with `lib.tools.codefix` (via `register_with_codefix`) and running the main `codefix` tool is generally the preferred workflow.

## Troubleshooting / Common Pitfalls (Optional)

- **`fix_all_in_directory` returns `nil` or `0` with errors:** This usually indicates a problem finding or accessing files. Check the error message returned (the second return value) and logs. Common causes include the target directory not existing, insufficient read/write permissions, or errors from the underlying `filesystem` module.
- **Unexpected Formatting Results:** The heading and list fixing logic might produce unexpected output on very complex or non-standard Markdown constructs, especially involving deeply nested lists, mixed list types, or unusual spacing within code blocks. Review the changes made by the tool, especially on complex files.
- **Expecting Unimplemented Features:** Users might mistakenly assume the module can fix links, tables, code block syntax, etc., based on outdated documentation or the placeholder function names. Refer to the "Unimplemented Features" list in the Key Concepts section to understand the actual current capabilities.
