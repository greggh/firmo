# Tools Module Tests

This directory contains tests for the various utility modules in the `lib/tools` directory.

## Parser Tests

The `parser_test.lua` file contains tests for the parser module, which is responsible for parsing Lua code into an abstract syntax tree (AST) and extracting information about the code structure.

The parser module provides functions for:
- Parsing Lua code into an AST
- Pretty printing the AST for debugging
- Detecting executable lines for coverage analysis
- Finding functions and their parameters
- Creating a code map of the source code

## Vendor Module Tests

The `vendor` directory contains tests for third-party libraries used by Firmo:

### LPegLabel Tests

The `vendor/lpeglabel_test.lua` file contains tests for the LPegLabel module, which is an extension of the LPeg (Parsing Expression Grammars for Lua) library that adds support for labeled failures.

LPegLabel is used by Firmo for parsing Lua code and implementing various code analysis features. The tests verify:
- Basic LPeg functionality
- Captures and pattern matching
- Grammar definition support
- Error label handling

## Other Tools Tests

Additional tests for filesystem operations, logging, error handling, and other utilities are organized in their respective directories under the tests directory.
