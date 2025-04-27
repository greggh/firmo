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
