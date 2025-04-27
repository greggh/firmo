# lib/tools Knowledge

## Purpose

The `lib/tools` directory serves as the central location for various utility modules within the Firmo framework. These modules provide common, reusable functionality needed to support the core testing framework, command-line interface, reporting, and other features. The tools cover a wide range of areas including filesystem interaction, error handling, logging, CLI argument parsing, data serialization (JSON), hashing, date/time manipulation, code analysis and fixing, performance benchmarking, interactive sessions, file watching, and managing third-party vendor libraries.

## Key Concepts

- **Reusable Utilities:** Each module under `lib/tools` aims to encapsulate a specific piece of functionality (e.g., handling files, parsing arguments, logging messages) in a reusable way, promoting modularity and reducing code duplication across the framework.
- **Focused Responsibility:** Tools are generally designed to have a clear, focused responsibility, making them easier to understand, maintain, and test independently.
- **Core Dependencies:** Certain tools are fundamental to the operation of almost all other parts of Firmo. Notably, `error_handler`, `filesystem`, and `logging` provide essential services relied upon throughout the codebase.

## Usage Examples / Patterns

### General Pattern: Requiring and Using a Tool

```lua
--[[
  Demonstrates the general pattern for requiring and using a module
  from the lib/tools directory. Specific function names and arguments
  will vary based on the tool.
]]
-- Replace 'tool_name' with the actual name (e.g., 'filesystem', 'logging')
local tool_name = require("lib.tools.tool_name")
local error_handler = require("lib.tools.error_handler") -- Often needed

-- Call functions provided by the tool
-- Many tool functions return (result, err) or need try()
local success, result_or_err = error_handler.try(tool_name.some_function, "arg1")

if not success then
  -- Handle the error object returned by error_handler.try
  print("Tool operation failed: " .. result_or_err.message)
else
  -- Use the successful result
  print("Tool operation succeeded: " .. tostring(result_or_err))
end

-- Some tools might provide objects or require configuration first
-- e.g., local logger = require("lib.tools.logging").get_logger("my_component")
-- logger:info("Starting process")
```

## Related Components / Modules

This directory contains the following primary utility modules:

**Core Support:**
- **`lib/tools/error_handler/knowledge.md`**: Provides the standardized error creation, handling (`try`, `safe_io_operation`), and logging framework used throughout Firmo.
- **`lib/tools/filesystem/knowledge.md`**: Offers a cross-platform API for file and directory operations, including temporary file management for tests.
- **`lib/tools/logging/knowledge.md`**: Implements the structured, leveled logging system used for diagnostics and reporting.
- **`lib/tools/utils/knowledge.md`**: General utility functions, including `try_require`.

**Framework Interaction:**
- **`lib/tools/cli/knowledge.md`**: Handles parsing of command-line arguments for the main `test.lua` script and orchestrates different execution modes.
- **`lib/tools/discover/knowledge.md`**: Implements the logic for finding test files based on configured patterns and rules.
- **`lib/tools/interactive/knowledge.md`**: Provides the interactive REPL mode (`--interactive`) for running tests and managing the environment dynamically.
- **`lib/tools/watcher/knowledge.md`**: Implements file watching capabilities used by the `--watch` mode to trigger test reruns on changes.

**Data Handling:**
- **`lib/tools/json/knowledge.md`**: Provides basic JSON encoding and decoding functionality (with limitations).
- **`lib/tools/hash/knowledge.md`**: Offers fast, non-cryptographic hashing (FNV-1a) for strings and files.
- **`lib/tools/parser/knowledge.md`**: Contains utilities for parsing Lua code into an Abstract Syntax Tree (AST).
- **`lib/tools/date/knowledge.md`**: A comprehensive library for date and time manipulation, parsing, formatting, and calculations.

**Developer Utilities:**
- **`lib/tools/benchmark/knowledge.md`**: Includes tools for measuring the performance (time, basic memory) of Lua functions and generating large test suites for framework benchmarking.
- **`lib/tools/codefix/knowledge.md`**: Integrates external tools (StyLua, Luacheck) and custom fixers for automated code quality checks and fixes.
- **`lib/tools/markdown/knowledge.md`**: Contains utilities specifically for fixing or manipulating Markdown files (partially implemented).
- **`lib/tools/test_helper/knowledge.md`**: Provides utility functions specifically designed to aid in writing Firmo tests themselves.

**Execution:**
- **`lib/tools/parallel/knowledge.md`**: Contains logic related to running tests in parallel (partially implemented).

**External/Vendor:**
- **`lib/tools/vendor/knowledge.md`**: Serves as a container for third-party libraries included directly in the source tree.
  - **`lib/tools/vendor/lpeglabel/knowledge.md`**: Documentation for the included `lpeglabel` library (an extension for the LPeg parsing library).

## Best Practices / Critical Rules

When using modules from `lib/tools`:
- **Prefer Tools Over Raw Functions:** Whenever a tool exists for a task (e.g., filesystem access, logging, error handling), prefer using the tool module over raw Lua functions like `io.*` or `os.*` to ensure consistency, cross-platform compatibility, and integration with framework features (like standardized error handling).
- **Mandatory Error Handling:** Always assume functions from tool modules can fail. Check return values and handle potential errors, typically by wrapping calls in `error_handler.try` or, specifically for filesystem I/O, `error_handler.safe_io_operation`.
- **Consult Specific Knowledge:** Before using a tool extensively, consult its dedicated `knowledge.md` file (linked above) to understand its full API, specific configuration options, potential limitations (e.g., JSON's Unicode support), and best practices related to that particular tool.
