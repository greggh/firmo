# Filesystem Module Duplication X-Ref

This document provides a cross-reference of duplicated or similar functions in the filesystem module, organized by function group and type of duplication.

## Directory Operations

| Function Name | Implementation Status | Duplication Type | Notes |
|--------------|---------------------|-----------------|-------|
| `fs.delete_directory` | Implemented (line 549-589) | Aliased | Primary implementation |
| `fs.remove_directory` | Not implemented | JSDoc only | Declared in JSDoc (line 56) as alias for `delete_directory` |

## File Operations

| Function Name | Implementation Status | Duplication Type | Notes |
|--------------|---------------------|-----------------|-------|
| `fs.delete_file` | Implemented (line 409-422) | Primary implementation | |
| `fs.remove_file` | Not implemented | JSDoc only | Declared in JSDoc (line 58) as alias for `delete_file` |

## Path Components

| Function Name | Implementation Status | Duplication Type | Notes |
|--------------|---------------------|-----------------|-------|
| `fs.get_directory_name` | Implemented (line 824-860) | Primary implementation | Full implementation with special case handling |
| `fs.dirname` | Implemented (line 866-869) | Aliased | Direct alias that calls `get_directory_name` |
| `fs.get_directory` | Not implemented | JSDoc only | Declared in JSDoc (line 77) as alias for `get_directory_name` |

| Function Name | Implementation Status | Duplication Type | Notes |
|--------------|---------------------|-----------------|-------|
| `fs.get_file_name` | Implemented (line 892-929) | Primary implementation | Full implementation with error handling |
| `fs.basename` | Implemented (line 1521-1524) | Aliased | Direct alias that calls `get_file_name` |
| `fs.get_filename` | Not implemented | JSDoc only | Declared in JSDoc (line 80) as alias for `get_file_name` |

## Timestamp Functions

| Function Name | Implementation Status | Duplication Type | Notes |
|--------------|---------------------|-----------------|-------|
| `fs.get_file_modified_time` | Not implemented | JSDoc only | Declared in JSDoc (line 67) |
| `fs.get_modified_time` | Implemented (line 1802-1834) | Primary implementation | Full implementation that works on both files and directories |

## File Listing and Discovery

| Function Name | Implementation Status | Duplication Type | Notes |
|--------------|---------------------|-----------------|-------|
| `fs.get_directory_contents` | Implemented (line 617-645) | Primary implementation | Returns all directory items without filtering |
| `fs.get_directory_items` | Not implemented | JSDoc only | Declared in JSDoc (line 61) |
| `fs.list_directory` | Implemented (line 1578-1613) | Different implementation | Similar to `get_directory_contents` but with different command execution |

## Summary of Duplication Types

1. **Aliased Functions** - Implemented multiple times with same behavior:
   - `fs.dirname` → `fs.get_directory_name`
   - `fs.basename` → `fs.get_file_name`

2. **JSDoc-only Functions** - Declared in documentation but not implemented:
   - `fs.remove_directory`
   - `fs.remove_file`
   - `fs.get_directory`
   - `fs.get_filename`
   - `fs.get_file_modified_time` 
   - `fs.get_directory_items`

3. **Different Implementations** - Similar functionality with different implementations:
   - `fs.list_directory` vs `fs.get_directory_contents`

## Recommendations

1. Implement missing aliases declared in JSDoc comments
2. Consider consolidating duplicate directory listing functions
3. Update JSDoc to clearly identify which function is primary and which are aliases
4. Add cross-references in function documentation

