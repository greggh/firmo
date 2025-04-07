# Markdown Module API Reference

The Markdown module provides utilities for fixing and improving Markdown formatting in documentation files. It can be used standalone or integrated with the codefix module for automatic formatting as part of code quality checks.

## Table of Contents

- [Module Overview](#module-overview)
- [Core Functions](#core-functions)
- [Formatting Functions](#formatting-functions)
- [Integration Functions](#integration-functions)

## Module Overview

The Markdown module provides the following capabilities:

- Finding Markdown files within a directory
- Fixing heading level hierarchies
- Correcting ordered list numbering
- Fixing spacing around elements
- Handling code blocks correctly during formatting
- Comprehensive formatting that combines multiple fixes
- Integration with the codefix module

## Core Functions

### find_markdown_files

Find all markdown files in a directory.

```lua
function markdown.find_markdown_files(dir)
```

**Parameters:**
- `dir` (string, optional): Directory to search in (defaults to current directory)

**Returns:**
- (string[]|nil): List of markdown files found, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local files, err = markdown.find_markdown_files("docs")
if files then
  for _, file_path in ipairs(files) do
    print(file_path)
  end
else
  print("Error finding markdown files: " .. err.message)
end
```

### fix_file

Fix a specific markdown file.

```lua
function markdown.fix_file(file_path)
```

**Parameters:**
- `file_path` (string): Path to the markdown file to fix

**Returns:**
- (boolean): Whether the file was successfully fixed
- (table, optional): Error object if operation failed

**Example:**
```lua
local success, err = markdown.fix_file("docs/README.md")
if success then
  print("File fixed successfully")
else
  print("Error fixing file: " .. err.message)
end
```

### fix_all_in_directory

Fix all markdown files in a directory.

```lua
function markdown.fix_all_in_directory(dir)
```

**Parameters:**
- `dir` (string, optional): Directory to search for markdown files to fix (defaults to current directory)

**Returns:**
- (number): Number of files that were fixed
- (table, optional): Error object if operation failed

**Example:**
```lua
local fixed_count, err = markdown.fix_all_in_directory("docs")
if err then
  print("Error fixing markdown files: " .. err.message)
else
  print("Fixed " .. fixed_count .. " files")
end
```

## Formatting Functions

### fix_heading_levels

Fix heading levels in markdown content to ensure proper hierarchy.

```lua
function markdown.fix_heading_levels(content)
```

**Parameters:**
- `content` (string): The markdown content to fix

**Returns:**
- (string|nil): The fixed markdown content, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local fixed_content, err = markdown.fix_heading_levels(original_content)
if fixed_content then
  print("Headings fixed")
else
  print("Error fixing headings: " .. err.message)
end
```

This function ensures that:
1. Headings start at level 1 (# Heading)
2. Heading levels increase by at most one level at a time (no jumping from h1 to h3)
3. Heading hierarchy is properly maintained throughout the document

### fix_list_numbering

Fix list numbering in markdown content.

```lua
function markdown.fix_list_numbering(content)
```

**Parameters:**
- `content` (string): The markdown content to fix

**Returns:**
- (string|nil): The fixed markdown content, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local fixed_content, err = markdown.fix_list_numbering(original_content)
if fixed_content then
  print("List numbering fixed")
else
  print("Error fixing list numbering: " .. err.message)
end
```

This function:
1. Correctly numbers ordered lists starting from 1
2. Preserves indentation levels for nested lists
3. Properly handles lists interrupted by other content
4. Preserves numbering inside code blocks

### fix_code_blocks

Fix markdown code blocks (remove redundant language specifiers).

```lua
function markdown.fix_code_blocks(content)
```

**Parameters:**
- `content` (string): The markdown content to fix

**Returns:**
- (string|nil): The fixed markdown content, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local fixed_content, err = markdown.fix_code_blocks(original_content)
if fixed_content then
  print("Code blocks fixed")
else
  print("Error fixing code blocks: " .. err.message)
end
```

### fix_spacing

Fix spacing issues in markdown content.

```lua
function markdown.fix_spacing(content)
```

**Parameters:**
- `content` (string): The markdown content to fix

**Returns:**
- (string|nil): The fixed markdown content, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local fixed_content, err = markdown.fix_spacing(original_content)
if fixed_content then
  print("Spacing fixed")
else
  print("Error fixing spacing: " .. err.message)
end
```

This function ensures proper spacing:
1. Between headings and surrounding content
2. Before and after lists
3. Before and after code blocks
4. Between paragraphs

### fix_tables

Fix table formatting in markdown content.

```lua
function markdown.fix_tables(content)
```

**Parameters:**
- `content` (string): The markdown content to fix

**Returns:**
- (string|nil): The fixed markdown content, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local fixed_content, err = markdown.fix_tables(original_content)
if fixed_content then
  print("Tables fixed")
else
  print("Error fixing tables: " .. err.message)
end
```

### fix_links

Fix broken links in markdown content.

```lua
function markdown.fix_links(content)
```

**Parameters:**
- `content` (string): The markdown content to fix

**Returns:**
- (string|nil): The fixed markdown content, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local fixed_content, err = markdown.fix_links(original_content)
if fixed_content then
  print("Links fixed")
else
  print("Error fixing links: " .. err.message)
end
```

### fix_comprehensive

Comprehensive markdown fixing - combines heading, list, and spacing fixes.

```lua
function markdown.fix_comprehensive(content)
```

**Parameters:**
- `content` (string): The markdown content to comprehensively fix

**Returns:**
- (string|nil): The fixed markdown content, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local fixed_content, err = markdown.fix_comprehensive(original_content)
if fixed_content then
  print("Markdown comprehensively fixed")
else
  print("Error fixing markdown: " .. err.message)
end
```

This function:
1. Extracts code blocks to prevent modifying their content
2. Fixes heading levels
3. Fixes list numbering
4. Applies spacing improvements
5. Restores code blocks
6. Ensures proper formatting throughout the document

## Integration Functions

### register_with_codefix

Register markdown fixing functionality with the codefix module.

```lua
function markdown.register_with_codefix(codefix)
```

**Parameters:**
- `codefix` (table): The codefix module to register with

**Returns:**
- (table|nil): The codefix module with markdown fixer registered, or nil on error
- (table, optional): Error object if registration failed

**Example:**
```lua
local codefix = require("lib.tools.codefix")
local result, err = markdown.register_with_codefix(codefix)
if result then
  print("Markdown fixer registered with codefix")
else
  print("Error registering markdown fixer: " .. err.message)
end
```

When registered with codefix, the markdown module adds a custom fixer that:
1. Automatically detects `.md` files
2. Applies comprehensive markdown fixes
3. Works with the codefix CLI commands
4. Integrates with the codefix workflow

### validate_markdown

Validate markdown content for common issues.

```lua
function markdown.validate_markdown(content)
```

**Parameters:**
- `content` (string): The markdown content to validate

**Returns:**
- (boolean): Whether the markdown is valid
- (table, optional): Error object with validation issues if invalid

**Example:**
```lua
local is_valid, issues = markdown.validate_markdown(content)
if not is_valid then
  for _, issue in ipairs(issues) do
    print(issue.line .. ": " .. issue.message)
  end
end
```

### extract_headings

Extract headings from markdown content.

```lua
function markdown.extract_headings(content)
```

**Parameters:**
- `content` (string): The markdown content to extract headings from

**Returns:**
- (table<number, {level: number, text: string, line: number}>): Table of heading information

**Example:**
```lua
local headings = markdown.extract_headings(content)
for i, heading in ipairs(headings) do
  print(string.rep("#", heading.level) .. " " .. heading.text .. 
        " (line " .. heading.line .. ")")
end
```

### generate_table_of_contents

Generate table of contents from headings.

```lua
function markdown.generate_table_of_contents(content)
```

**Parameters:**
- `content` (string): The markdown content to generate TOC from

**Returns:**
- (string|nil): The generated table of contents, or nil on error
- (table, optional): Error object if operation failed

**Example:**
```lua
local toc, err = markdown.generate_table_of_contents(content)
if toc then
  print("Generated TOC:")
  print(toc)
else
  print("Error generating TOC: " .. err.message)
end
```