# Markdown Module User Guide


The Markdown module provides tools for fixing and improving Markdown formatting in documentation files. This guide explains how to use the module to maintain consistent, high-quality documentation across your project.

## Table of Contents



- [Getting Started](#getting-started)
- [Basic Usage](#basic-usage)
- [Fixing Specific Issues](#fixing-specific-issues)
- [Working with Multiple Files](#working-with-multiple-files)
- [Integration with Codefix](#integration-with-codefix)
- [Common Formatting Scenarios](#common-formatting-scenarios)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)


## Getting Started


### Installation


The Markdown module is included as part of the Firmo framework. To use it, simply require the module:


```lua
local markdown = require("lib.tools.markdown")
```



### Prerequisites


The module requires:


- The Firmo filesystem module (`lib.tools.filesystem`)
- The Firmo logging module (`lib.tools.logging`)
- The Firmo error_handler module (`lib.tools.error_handler`)

These dependencies are automatically loaded when you require the markdown module.

## Basic Usage


### Fixing a Single File


To fix formatting issues in a single Markdown file:


```lua
local markdown = require("lib.tools.markdown")
local success, err = markdown.fix_file("docs/README.md")
if success then
  print("README.md fixed successfully")
else
  print("Error fixing README.md: " .. (err and err.message or "unknown error"))
end
```



### Reading and Fixing Content


To fix Markdown content directly:


```lua
local fs = require("lib.tools.filesystem")
local markdown = require("lib.tools.markdown")
-- Read file content
local content, read_err = fs.read_file("docs/guide.md")
if not content then
  print("Error reading file: " .. (read_err or "unknown error"))
  return
end
-- Fix the content
local fixed_content, fix_err = markdown.fix_comprehensive(content)
if not fixed_content then
  print("Error fixing content: " .. (fix_err and fix_err.message or "unknown error"))
  return
end
-- Write the fixed content back
local success, write_err = fs.write_file("docs/guide.md", fixed_content)
if not success then
  print("Error writing file: " .. (write_err or "unknown error"))
  return
end
print("File fixed successfully")
```



## Fixing Specific Issues


The Markdown module provides functions for fixing specific types of issues:

### Fixing Heading Levels


Ensures proper heading hierarchy (h1 > h2 > h3):


```lua
local fixed_content = markdown.fix_heading_levels(content)
```



#### Before:



```markdown

# Main Heading


Some text

### This skips h2 level


Some more text

## Now back to h2


```



#### After:



```markdown

# Main Heading


Some text

## This was h3, now properly h2


Some more text

## Now back to h2


```



### Fixing List Numbering


Ensures ordered lists use sequential numbering:


```lua
local fixed_content = markdown.fix_list_numbering(content)
```



#### Before:



```markdown


1. First item
1. Second item
1. Third item

Another list:


1. Item A
3. Item B
7. Item C

```



#### After:



```markdown


1. First item
2. Second item
3. Third item

Another list:


1. Item A
2. Item B
3. Item C

```



### Fixing Spacing


Ensures proper spacing around Markdown elements:


```lua
local fixed_content = markdown.fix_spacing(content)
```



#### Before:



```markdown

# Heading


Paragraph right after heading without space

## Another heading



* List item 1
* List item 2

Paragraph right after list without space
```



#### After:



```markdown

# Heading


Paragraph right after heading without space

## Another heading



* List item 1
* List item 2

Paragraph right after list without space
```



### Fixing Code Blocks


Ensures code blocks use proper formatting:


```lua
local fixed_content = markdown.fix_code_blocks(content)
```



#### Before:



```markdown
Some code:
```text


function example()
  return true
end


```text
With improper spacing:
```


Another function()


```text

```



#### After:



```markdown
Some code:
```lua


function example()
  return true
end


```text
With improper spacing:
```


Another function()


```text

```



## Working with Multiple Files


### Finding Markdown Files


To find all Markdown files in a directory:


```lua
local files, err = markdown.find_markdown_files("docs")
if not files then
  print("Error finding Markdown files: " .. (err and err.message or "unknown error"))
  return
end
print("Found " .. #files .. " Markdown files")
for i, file_path in ipairs(files) do
  print(i .. ". " .. file_path)
end
```



### Fixing All Files in a Directory


To fix all Markdown files in a directory:


```lua
local fixed_count, err = markdown.fix_all_in_directory("docs")
if err then
  print("Error fixing Markdown files: " .. err.message)
else
  print("Fixed " .. fixed_count .. " files")
end
```


This will:


1. Find all .md files in the directory and subdirectories
2. Apply comprehensive fixes to each file
3. Skip files that don't need changes
4. Return the count of files that were modified


## Integration with Codefix


The Markdown module can be integrated with the codefix module to automatically format Markdown files as part of code quality checks.

### Registering with Codefix



```lua
local codefix = require("lib.tools.codefix")
local markdown = require("lib.tools.markdown")
-- Register markdown fixer with codefix
local result, err = markdown.register_with_codefix(codefix)
if not result then
  print("Error registering markdown fixer: " .. (err and err.message or "unknown error"))
end
-- Now codefix can automatically fix markdown files
codefix.fix_file("docs/README.md")
-- Or fix all markdown files in a directory
codefix.fix_lua_files("docs", {
  include = { "%.md$" },
  exclude = { "node_modules", "%.git" }
})
```



### Using with Codefix CLI


Once registered with codefix, you can use codefix CLI commands to fix Markdown files:


```text
> codefix fix docs --include "%.md$"
```


This integrates Markdown fixing into your code quality workflow.

## Common Formatting Scenarios


### Creating a Table of Contents


Generate a table of contents from document headings:


```lua
local toc, err = markdown.generate_table_of_contents(content)
if toc then
  -- Insert TOC at the beginning of the document
  local content_with_toc = "# Table of Contents\n\n" .. toc .. "\n\n" .. content
  fs.write_file("docs/guide.md", content_with_toc)
end
```



### Extracting and Analyzing Headings


Extract and analyze heading structure:


```lua
local headings = markdown.extract_headings(content)
-- Print heading hierarchy
for i, heading in ipairs(headings) do
  print(string.rep("  ", heading.level - 1) .. 
        "- " .. heading.text .. " (Level " .. heading.level .. ")")
end
-- Check for heading level jumps
local prev_level = 0
for i, heading in ipairs(headings) do
  if heading.level > prev_level + 1 then
    print("Warning: Heading level jump at line " .. heading.line)
  end
  prev_level = heading.level
end
```



### Validating Markdown


Check for common Markdown issues:


```lua
local is_valid, issues = markdown.validate_markdown(content)
if not is_valid then
  print("Markdown validation failed:")
  for _, issue in ipairs(issues) do
    print("Line " .. issue.line .. ": " .. issue.message)
  end
end
```



## Best Practices


### Workflow Integration


For best results, integrate Markdown formatting into your workflow:


1. **Pre-commit hooks**: Run Markdown fixes before committing changes to ensure consistent documentation:


```bash
#!/bin/sh

# pre-commit hook for Markdown files


LUA_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.md$')
if [ -n "$LUA_FILES" ]; then
  lua -e 'require("lib.tools.markdown").fix_all_in_directory(".")'
  git add $LUA_FILES
fi
```



1. **CI/CD pipeline**: Validate Markdown formatting as part of continuous integration:


```yaml


- name: Check Markdown formatting

  run: lua -e 'require("lib.tools.markdown").validate_all("docs")'
```



1. **Build process**: Run Markdown fixes before generating documentation:


```lua
-- In build script
local markdown = require("lib.tools.markdown")
markdown.fix_all_in_directory("docs")
-- Continue with documentation generation
```



### Project-Wide Configuration


Configure the module for project-wide use:


```lua
-- In your project setup script
local central_config = require("lib.core.central_config")
local markdown = require("lib.tools.markdown")
-- Configure markdown module via central_config
central_config.set("markdown", {
  -- Custom configuration options
  spacing_style = "loose",     -- Controls spacing between elements
  code_block_style = "fenced", -- Use ``` for code blocks
  heading_style = "atx",       -- Use # style headings (not === style)
  fix_on_save = true           -- Fix markdown files on save
})
-- Register with codefix if available
local codefix_success, codefix = pcall(require, "lib.tools.codefix")
if codefix_success then
  markdown.register_with_codefix(codefix)
end
```



## Troubleshooting


### Common Issues and Solutions


#### Files Not Being Found


If Markdown files aren't being found:


```lua
-- Specify absolute path
local files = markdown.find_markdown_files("/absolute/path/to/docs")
-- Debug the search path
local fs = require("lib.tools.filesystem")
local abs_path = fs.get_absolute_path("docs")
print("Searching in: " .. abs_path)
```



#### Formatting Not Applied


If formatting isn't being applied:


```lua
-- Enable verbose logging
local logging = require("lib.tools.logging")
logging.configure_from_options("Markdown", {
  verbose = true,
  debug = true
})
-- Then try fixing again
markdown.fix_file("docs/README.md")
```



#### Formatting Errors


If you encounter errors during formatting:


```lua
-- Enable error capture to see the specific issue
local error_handler = require("lib.tools.error_handler")
local success, result, err = error_handler.try(function()
  return markdown.fix_comprehensive(content)
end)
if not success then
  print("Formatting error: " .. error_handler.format_error(result))
end
```



#### Preserving Special Content


If certain parts of your Markdown should be preserved exactly as-is:


```markdown
<!-- markdown-preserve -->
This content will not be modified by the markdown fixer.


1. These numbers will stay the same
1. Even though they're not sequential

<!-- end-markdown-preserve -->
```



### Getting Help


For more detailed information:


1. Enable debug logging to see exactly what the module is doing:


```lua
local logging = require("lib.tools.logging")
logging.configure_from_options("Markdown", {
  debug = true,
  verbose = true
})
```



1. Check the full documentation in the [API Reference](../api/markdown.md).
2. Look at the [example files](../../examples/markdown_examples.md) for guidance on specific use cases.
