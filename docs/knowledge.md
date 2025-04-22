# Firmo Knowledge Base


## Core Principles



1. NO DEBUG HOOKS - The v3 coverage system must never use debug hooks (debug.sethook). All coverage tracking must be done through source code instrumentation.
2. Three-State Coverage - The system must properly distinguish between:
   - Covered (green): Code verified by assertions
   - Executed (orange): Code that ran but wasn't verified
   - Not covered (red): Code that didn't run
3. No Special Cases - All solutions must be general purpose without special handling for specific files
4. Clean Abstractions - Components must interact through well-defined interfaces


## Implementation Guidelines



1. Use the parser in lib/tools/parser/grammar.lua for parsing Lua code
2. Use source code instrumentation to track coverage:
   - Parse source into AST
   - Transform AST to add tracking
   - Generate instrumented code
   - Create source map
3. Use central_config for all configuration
4. Handle errors consistently using error_handler
5. Use structured logging with the logging module


## Testing Requirements


After every change:


1. Run tests: `lua test.lua tests/`
2. Check coverage: `lua test.lua --coverage tests/`
3. Validate types: `lua test.lua --types`


## Common Issues



1. Debug hooks are unreliable and cannot properly track coverage - use instrumentation instead
2. The parser may need high stack size for complex code - use lpeg.setmaxstack(1000)
3. Source maps are critical for error reporting - always maintain accurate source maps


## Architecture


See docs/firmo/architecture.md for detailed architecture documentation.

## Examples


See examples/ directory for example code, especially:


- instrumentation_example.lua: Shows how to use instrumentation
- coverage_example.lua: Shows three-state coverage tracking
