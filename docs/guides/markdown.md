# Markdown Module User Guide

The Markdown module provides tools for fixing and improving Markdown formatting in documentation files. This guide explains how to use the module to maintain consistent, high-quality documentation across your project.

## Table of Contents

- [Getting Started](#getting-started)
- [Basic Usage](#basic-usage)
- [Fixing Specific Issues](#fixing-specific-issues)
- [Working with Multiple Files](#working-with-multiple-files)
- [Integration with Codefix](#integration-with-codefix)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Getting Started

### Installation

The Markdown module provides the following capabilities:

- Finding Markdown files within a directory (`find_markdown_files`).
- Fixing heading level hierarchies (`fix_heading_levels`).
- Correcting ordered list numbering (`fix_list_numbering`).
- Applying multiple fixes comprehensively (`fix_comprehensive`).
- Fixing all Markdown files in a directory (`fix_all_in_directory`).
- Integrating with the codefix module (`register_with_codefix`).

The module requires:

- The Firmo filesystem module (`lib.tools.filesystem`)
- The Firmo logging module (`lib.tools.logging`)
- The Firmo error_handler module (`lib.tools.error_handler`)

These dependencies are automatically loaded when you require the markdown module.

## Basic Usage

### Reading and Fixing Content

To read Markdown content, apply fixes, and write it back:

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

1. **CI/CD pipeline**: Run Markdown fixes as part of continuous integration:

```yaml
- name: Fix Markdown formatting
  run: lua -e 'require("lib.tools.markdown").fix_all_in_directory("docs")'
```

2. **Build process**: Run Markdown fixes before generating documentation:

```lua
-- In build script
local markdown = require("lib.tools.markdown")
markdown.fix_all_in_directory("docs")
-- Continue with documentation generation
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
2. Look at the example files (if available) for guidance on specific use cases.
## Conclusion

The Markdown module offers basic tools for maintaining consistent documentation in your Lua projects by fixing heading levels and list numbering. By integrating it into your workflow, you can automate these specific formatting tasks.
