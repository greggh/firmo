# Discovery Tests

This directory contains tests for the firmo test discovery system. The discovery module locates and loads test files based on patterns and directory structures.

## Directory Contents

- **discovery_test.lua** - Tests for test file discovery mechanisms

## Discovery Features

The firmo discovery system provides:

- Recursive directory scanning
- Pattern-based file matching
- Proper handling of nested test directories
- Integration with the filesystem module
- Support for exclude patterns
- Efficient file loading mechanisms

## Discovery Patterns

Test discovery uses glob-style patterns to match files:

- `*.lua` - Match all Lua files in the current directory
- `**/*.lua` - Match all Lua files recursively
- `*_test.lua` - Match files ending with _test.lua
- `{tests,spec}/**/*.lua` - Match files in tests/ or spec/ directories

## Discovery Configuration

The discovery system can be configured through:

- Command-line arguments
- Configuration files
- API options when calling from code

## Running Tests

To run all discovery tests:
```
lua test.lua tests/discovery/
```

To run a specific discovery test:
```
lua test.lua tests/discovery/discovery_test.lua
```

See the [Discovery API Documentation](/docs/api/discovery.md) for more information.