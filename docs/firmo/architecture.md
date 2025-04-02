# Firmo Architecture

## Overview (Updated 2025-03-27)

Firmo is a comprehensive testing framework for Lua projects that provides BDD-style nested test blocks, detailed assertions, setup/teardown hooks, advanced mocking, asynchronous testing, code coverage analysis, and test quality validation.

## Core Architecture

The framework is built with modularity and extensibility in mind, with a clear separation of concerns:

```
firmo.lua                  # Main entry point and public API
|
├── lib/                   # Core framework modules
│   ├── core/              # Fundamental components
│   │   ├── central_config.lua   # Centralized configuration system
│   │   ├── version.lua    # Version information
│   │   └── utils.lua      # Core utilities
│   │
│   ├── assertion/         # Assertion system
│   │   ├── expect.lua     # Expect-style assertions
│   │   └── matchers/      # Individual matcher implementations
│   │
│   ├── coverage/          # Code coverage system
│   │   ├── init.lua       # Coverage API and lifecycle management
│   │   ├── v3/            # v3 instrumentation-based coverage
│   │   │   ├── init.lua   # v3 API entry point
│   │   │   ├── instrumentation/  # Code instrumentation
│   │   │   │   ├── parser.lua    # Lua source parser
│   │   │   │   ├── transformer.lua # Code transformer
│   │   │   │   └── sourcemap.lua # Source mapping
│   │   │   ├── loader/    # Module loading
│   │   │   │   ├── hook.lua    # Module loader hook
│   │   │   │   └── cache.lua   # Instrumented module cache
│   │   │   ├── runtime/   # Runtime tracking
│   │   │   │   ├── tracker.lua    # Execution tracker
│   │   │   │   └── data_store.lua # Data storage
│   │   │   ├── assertion/ # Assertion integration
│   │   │   │   ├── hook.lua      # Assertion hook
│   │   │   │   └── analyzer.lua  # Stack analyzer
│   │   │   └── report/    # Reporting
│   │   │       ├── html.lua      # HTML reporter
│   │   │       └── json.lua      # JSON reporter
│   │   ├── report/        # Report generation (legacy)
│   │   │   ├── html.lua   # HTML report formatter
│   │   │   ├── json.lua   # JSON report formatter
│   │   │   └── lcov.lua   # LCOV report formatter
│   │
│   ├── tools/             # Utility tools
│   │   ├── logging/       # Structured logging system
│   │   ├── error_handler.lua # Standardized error handling
│   │   ├── filesystem.lua    # Filesystem operations
│   │   ├── benchmark.lua     # Performance benchmarking
│   │   ├── codefix.lua       # Code quality checking and fixing
│   │   ├── watcher.lua       # File watching for live reload
│   │   └── parser.lua        # Lua code parsing
│   │
│   ├── mocking/           # Mocking system
│   │   ├── spy.lua        # Function spying
│   │   ├── stub.lua       # Function stubbing
│   │   └── mock.lua       # Object mocking
│   │
│   ├── quality/           # Test quality validation
│   │   ├── init.lua       # Quality API
│   │   ├── rules/         # Quality rule definitions
│   │   └── report/        # Quality report generators
│   │
│   └── reporting/         # Test reporting
│       ├── init.lua       # Report coordination
│       └── formatters/    # Report formatters
│           ├── html.lua   # HTML test reports
│           ├── json.lua   # JSON test reports
│           ├── junit.lua  # JUnit XML reports
│           ├── lcov.lua   # LCOV reports
│           ├── cobertura.lua # Cobertura XML reports
│           ├── tap.lua    # TAP format reports
│           └── csv.lua    # CSV reports
│
├── scripts/               # Utilities and runners
│   ├── runner.lua         # Test runner
│   └── tools/             # Development tools
│
└── test.lua               # Main test runner script
```

## Key Components

### 1. Central Configuration System

The central configuration system (`lib/core/central_config.lua`) is the backbone of the framework, providing a unified way to configure all aspects of the system. It:

- Loads configuration from `.firmo-config.lua` files
- Provides sensible defaults for all settings
- Handles configuration merging from multiple sources
- Exposes a consistent API for all modules to access configuration
- Supports environment variable overrides

The central_config module MUST be used by all other modules to retrieve configuration values, ensuring consistency across the framework.

```lua
-- Example of proper configuration usage
local central_config = require("lib.core.central_config")
local config = central_config.get_config()

-- Access configuration values
local include = config.coverage.include
local exclude = config.coverage.exclude
local report_format = config.coverage.report.format
```

### 2. Instrumentation-Based Coverage System (v3)

The coverage system has been completely redesigned to use code instrumentation rather than debug hooks, with a focus on safety through temporary file usage. This provides:

- More accurate coverage tracking
- Support for complex code patterns
- Better performance
- Detailed execution data
- Three-state coverage model (covered, executed, not covered)
- Safe instrumentation through temporary files
- Automatic cleanup of instrumented files

#### 2.1 Key Coverage Components

- **Instrumentation Engine**: Transforms Lua code to insert tracking statements
  - **Parser**: Parses Lua source code into an AST
  - **Transformer**: Adds tracking calls to the code
  - **Sourcemap**: Maps instrumented code back to original source
  - **Temp File Manager**: Handles safe file operations through test_helper

- **Module Loading Integration**: Hooks into Lua's module loading system
  - **Loader Hook**: Intercepts require calls
  - **Cache**: Caches instrumented modules
  - **Path Mapper**: Maps between original and temp paths

- **Runtime Tracking**: Tracks code execution at runtime
  - **Tracker**: Records execution and coverage events
  - **Data Store**: Stores and manages tracking data
  - **Path Resolution**: Maps temp paths back to originals

- **Assertion Integration**: Connects assertions to the code they verify
  - **Assertion Hook**: Hooks into firmo's assertion system
  - **Stack Analyzer**: Analyzes stack traces to identify covered lines

- **Reporting System**: Generates coverage reports in various formats
  - Supports HTML, JSON, LCOV, Cobertura, JUnit, TAP, and CSV formats
  - Visualizes the three-state coverage model

#### 2.2 Coverage Data Flow

1. **Source Copy**: Original source file is copied to temporary location
2. **Instrumentation**: Temporary copy is transformed to include tracking
3. **Module Loading**: Instrumented temp file is loaded instead of original
4. **Execution Tracking**: As code runs, execution data is stored
5. **Coverage Tracking**: When assertions run, coverage data is recorded
6. **Path Mapping**: All paths are mapped back to original source
7. **Report Generation**: Coverage reports use original source paths
8. **Cleanup**: Temporary files are automatically cleaned up

#### 2.3 Edge Case Handling

The v3 system handles various edge cases:

- **Dynamically Generated Code**: Tracks code generated via `load` and `loadstring`
- **Metaprogramming Patterns**: Handles metatables and delegation patterns
- **Multi-line Constructs**: Tracks complex, multi-line statements and expressions
- **Asynchronous Code**: Works with coroutines and async execution patterns

#### 2.4 Memory Management

The v3 system includes memory optimization strategies:

- **Minimal Code Injection**: Adds only essential tracking calls
- **Lazy Instrumentation**: Only instruments modules when loaded
- **Compact Data Structures**: Uses efficient data representations
- **Periodic Cleanup**: Removes tracking for unused modules

#### 2.5 Error Recovery

The v3 system provides robust error handling:

- **Parser Recovery**: Handles syntax errors gracefully
- **Tracking Error Isolation**: Prevents tracking errors from affecting tests
- **Graceful Degradation**: Falls back to partial coverage when needed

### 3. Assertion System

The assertion system provides a fluent, expect-style API for making assertions:

```lua
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
expect(value).to.be_truthy()
```

The assertion system is integrated with the coverage system to track which lines are verified by assertions (covered) versus just executed.

### 4. Mocking System

The mocking system provides comprehensive capabilities for isolating tests from dependencies:

- **Spies**: Track function calls without changing behavior
- **Stubs**: Replace functions with test implementations
- **Mocks**: Create mock objects with customized behavior
- **Sequence Mocking**: Define sequences of return values
- **Verification**: Verify call counts, arguments, and order

### 5. Error Handling

All errors in the framework use a standardized error handling pattern:

```lua
-- Error creation
local err = error_handler.validation_error(
  "Invalid parameter",
  {parameter_name = "file_path", operation = "track_file"}
)

-- Error propagation
return nil, err

-- Error handling
local success, result, err = error_handler.try(function()
  return some_operation()
end)

if not success then
  logger.error("Operation failed", {
    error = error_handler.format_error(result)
  })
  return nil, result
end
```

### 6. Quality Validation

The quality module validates that tests meet specified quality criteria:

- Multiple quality levels (from basic to complete)
- Customizable quality rules
- Quality report generation
- Integration with the test runner

### 7. Utility Modules

Several utility modules provide supporting functionality:

- **Filesystem**: Cross-platform file operations with:
  - Consistent handling of hidden files in directory operations
  - Standardized function aliases (e.g., remove_directory → delete_directory)
  - Unified directory listing through a single implementation
  - Comprehensive path manipulation functions
- **Logging**: Structured, level-based logging
- **Watcher**: File monitoring for live reloading
- **Benchmark**: Performance measurement and analysis
- **CodeFix**: Code quality checking and fixing
- **Parser**: Lua code parsing and analysis

## Component Status

### Completed Components

- ✅ Assertion system
- ✅ Mocking system
- ✅ Central configuration system
- ✅ Error handling patterns
- ✅ Filesystem module
- ✅ Structured logging system
- ✅ Test runner

### In-Progress Components

- 🔄 v3 Instrumentation-based coverage system (high priority)
- 🔄 Enhanced HTML report visualization (high priority)
- 🔄 Quality validation module (medium priority)
- 🔄 File watcher module (medium priority)
- 🔄 CodeFix module (medium priority)
- 🔄 Benchmark module (medium priority)

## Implementation Timeline (Spring 2025)

### Current Work (3-Week Timeline)

- **Days 1-15**: Complete v3 coverage system implementation
- **Days 16-17**: Complete quality module
- **Days 18-19**: Complete watcher module
- **Day 20**: Complete HTML coverage report enhancements

### Interaction Between Components

```
                        +----------------+
                        | central_config |<-------+
                        +-------+--------+        |
                                |                 |
            +------------------+-----------------+|
            |                  |                 ||
+-----------v----------+ +-----v------+   +------v+-----+
|  Coverage System     | |  Quality   |   |  Reporting  |
| (instrumentation)    | |  Module    |   |  System     |
+-----------+----------+ +-----+------+   +------+------+
            |                  |                 |
            v                  v                 v
      +-----------+      +-----------+    +-----------+
      | Assertion |<---->|   Test    |<-->|  Mocking  |
      |  System   |      |  Runner   |    |  System   |
      +-----------+      +-----+-----+    +-----------+
                               |
                         +----+-----+
                         | Utilities |
                         +----------+
```

## Key Architectural Principles

1. **No Special Case Code**: All solutions must be general purpose without special handling for specific files or situations
2. **Consistent Error Handling**: All modules use structured error objects with standardized patterns
3. **Central Configuration**: All modules retrieve configuration from the central_config system
4. **Clean Abstractions**: Components interact through well-defined interfaces
5. **Extensive Documentation**: All components have comprehensive API documentation, guides, and examples
6. **Memory Efficiency**: Components are designed to minimize memory usage and clean up resources
7. **Error Recovery**: Systems handle errors gracefully and provide robust recovery mechanisms

## Module Dependencies

- **Core Modules**: central_config, version, utils, error_handler
- **Assertion**: core, error_handler
- **Coverage**: core, central_config, error_handler, filesystem, assertion
- **Mocking**: core, error_handler
- **Quality**: core, central_config, error_handler
- **Reporting**: core, central_config, error_handler, filesystem
- **Utilities**: core, error_handler