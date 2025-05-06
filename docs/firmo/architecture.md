# Firmo Architecture

## Overview (Updated 2025-03-27)

Firmo is a comprehensive testing framework for Lua projects that provides BDD-style nested test blocks, detailed assertions, setup/teardown hooks, advanced mocking, asynchronous testing, code coverage analysis, and test quality validation.

## Core Architecture

The framework is built with modularity and extensibility in mind, with a clear separation of concerns:

```text
firmo.lua                  # Main entry point and public API
|
├── lib/                   # Core framework modules
│   ├── core/              # Fundamental components
│   │   ├── init.lua           # Core aggregator
│   │   ├── central_config.lua # Centralized configuration system
│   │   ├── module_reset.lua   # Module isolation system
│   │   ├── runner.lua         # Core test execution logic
│   │   ├── test_definition.lua # BDD functions (describe, it, etc.)
│   │   ├── type_checking.lua  # Advanced type validation
│   │   └── version.lua        # Version information
│   │
│   ├── assertion/         # Assertion system
│   │   ├── init.lua     # Expect-style assertions
│   │
│   ├── coverage/          # Code coverage system
│   │   └── init.lua       # Coverage API and lifecycle management
│   │
│   ├── tools/             # Utility tools
│   │   ├── benchmark/     # Performance benchmarking
│   │   ├── cli/           # Command-line argument parsing
│   │   ├── codefix/       # Code quality checking and fixing (Partially Implemented)
│   │   ├── date/          # Date/time utilities
│   │   ├── discover/      # Test file discovery
│   │   ├── error_handler/ # Standardized error handling
│   │   ├── filesystem/    # Filesystem operations (includes temp_file)
│   │   ├── hash/          # Hashing utilities
│   │   ├── interactive/   # Interactive mode (Partially Implemented)
│   │   ├── json/          # JSON encoding/decoding
│   │   ├── logging/       # Structured logging system (includes export, search, formatter_integration)
│   │   ├── markdown/      # Markdown fixing utilities (Partially Implemented)
│   │   ├── parallel/      # Parallel test execution
│   │   ├── parser/        # Lua code parsing
│   │   ├── test_helper/   # Utilities for writing tests
│   │   ├── watcher/       # File watching for live reload (Partially Implemented)
│   │   └── vendor/        # Third-party libraries (e.g., lpeglabel)
│   │
│   ├── mocking/           # Mocking system
│   │   ├── stub.lua       # Function stubbing
│   │   ├── mock.lua       # Object mocking
│   │   └── spy.lua        # Spy module
│   │
│   ├── reporting/         # Test reporting
│   │   ├── init.lua       # Report coordination
│   │   └── formatters/    # Report formatters
│   │       ├── html.lua      # HTML test reports
│   │       ├── json.lua      # JSON test/coverage/quality reports
│   │       ├── junit.lua     # JUnit XML test reports
│   │       ├── lcov.lua      # LCOV coverage reports
│   │       ├── cobertura.lua # Cobertura XML coverage reports
│   │       ├── tap.lua       # TAP format test reports
│   │       ├── summary.lua   # Text summary reports (coverage/quality)
│   │       └── csv.lua       # CSV test reports
│   │
│   ├── async/             # Asynchronous testing utilities (it_async, describe_async, etc.)
│   │   └── init.lua
│   │
│   └── quality/           # Test quality validation (Partially Implemented)
│       ├── init.lua       # Quality API
│       └── level_checkers.lua # Logic for different quality levels
│
├── scripts/               # Utilities and runners
│   └── runner.lua         # Test runner
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

### 2. Debug Hook-Based Coverage System

The coverage system integrates LuaCov's proven debug hook approach, enhanced with firmo's robust file operations, error handling, and reporting capabilities. This provides:

- Reliable coverage tracking through Lua's debug hooks
- Support for complex code patterns
- Comprehensive execution data
- Detailed coverage reporting
- Integration with firmo's reporting system
- All file operations through firmo's filesystem module
- Standardized error handling

#### 2.1 Key Coverage Components

- **Debug Hook Integration**: Uses Lua's debug hooks to track line execution
  - **Hook Management**: Proper hook setup and teardown
  - **Thread Safety**: Support for coroutines and multiple threads
  - **Lifecycle Management**: Clean start, stop, and reset operations
- **File Operations**: Uses firmo's filesystem module
  - **Path Handling**: Standardized path operations
  - **File Access**: Safe file reading and writing
  - **Temp Files**: Proper temporary file management through temp_file module
- **Statistics Collection**: Tracks and stores coverage data
  - **Data Store**: Efficient storage of coverage information
  - **Persistence**: Proper saving and loading of data
  - **Normalization**: Clean data structures for reporting
- **Configuration Management**: Uses central_config for all settings
  - **Include/Exclude Patterns**: Control what files are tracked
  - **Output Settings**: Configure report formats and locations
  - **Hook Behavior**: Configure the debug hook system
- **Reporting System**: Generates coverage reports in various formats
  - **HTML Format**: Interactive reports with syntax highlighting, color-coded line coverage, and collapsible file views
  - **JSON Format**: Structured data with configurable pretty printing for easy parsing.
  - **LCOV Format**: Standard format compatible with external LCOV tools.
  - **Cobertura XML Format**: CI/CD compatible format.
  - **Summary Format**: Text-based summary for console output.

#### 2.2 Coverage Data Flow

1. **Hook Setup**: Debug hooks registered at the start of test runs
2. **Execution Tracking**: Debug hooks record each line execution
3. **Data Collection**: Coverage data collected in memory
4. **Data Persistence**: Coverage data saved to files through filesystem module
5. **Report Generation**: Coverage reports generated using firmo's reporting system
6. **Hook Cleanup**: Debug hooks properly removed when coverage tracking ends

#### 2.3 Edge Case Handling

The coverage system handles various edge cases:

- **Coroutines**: Properly tracks code running in coroutines
- **Module Loading**: Works with various module loading patterns
- **Error Conditions**: Properly recovers from errors during tracking
- **Large Codebases**: Efficiently handles large projects

#### 2.4 Memory Management

The coverage system includes memory optimization strategies:

- **Efficient Data Structures**: Uses compact representations for coverage data
- **Smart Persistence**: Only saves data when needed
- **Resource Cleanup**: Proper cleanup of all resources
- **Minimal Overhead**: Low impact on application performance

#### 2.5 Error Recovery

The coverage system provides robust error handling:

- **Hook Error Isolation**: Prevents hook errors from affecting tests
- **File Operation Safety**: Safe handling of all file operations
- **Graceful Degradation**: Falls back to partial coverage when needed
- **Error Context**: Detailed error information for troubleshooting

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

- ✅ Core (`central_config`, `error_handler`, `test_definition`, `runner`, etc.)
- ✅ Assertion system
- ✅ Mocking system
- ✅ Filesystem (including `temp_file`)
- ✅ Logging (including `export`, `search`, `formatter_integration`)
- ✅ Coverage (LuaCov integration, basic reporting)
- ✅ Reporting (Core system, formatters: HTML, JSON, LCOV, Cobertura, JUnit, TAP, CSV, Summary)
- ✅ Parser
- ✅ Async
- ✅ Benchmark
- ✅ Discover
- ✅ Hash
- ✅ JSON
- ✅ Date

### Partially Implemented / In-Progress Components

- 🔄 **Quality Validation (`lib/quality`)**: Core API exists (`--quality` flag), but specific rule implementations and reporting are likely incomplete or placeholder.
- 🔄 **Watcher (`lib/tools/watcher`)**: `--watch` flag exists, but reliability, performance, and integration with all test features might be incomplete. Several API functions are unimplemented.
- 🔄 **CodeFix (`lib/tools/codefix`)**: Primarily conceptual; no significant implementation exists beyond potential parser tools and basic integrations (StyLua/Luacheck).
- 🔄 **Markdown Fixer (`lib/tools/markdown`, `scripts/fix_markdown.lua`)**: Exists as a script with heading/list fixing, but may lack robustness or full integration with the framework API.
- 🔄 **Interactive Mode (`lib/tools/interactive`)**: Likely conceptual; no known implementation exists beyond a basic module structure.
- 🔄 **Parallel (`lib/parallel`)**: Core module (`lib/parallel/`) exists, but actual parallel execution via the runner (`test.lua`) is not implemented or documented.

## Change History

- 2025-04-28: Removed duplicate JSON reporter reference (now consolidated in tools/json/init.lua)

## Implementation Timeline (Spring 2025)

### Current Work (3-Week Timeline)

- **Days 1-15**: Complete LuaCov integration for coverage system
- **Days 16-17**: Complete quality module
- **Days 18-19**: Complete watcher module
- **Day 20**: Complete HTML coverage report enhancements

### Interaction Between Components

```text
                        +----------------+
                        | central_config |<-------+
                        +-------+--------+        |
                                |                 |
            +------------------+-----------------+|
            |                  |                 ||
+-----------v----------+ +-----v------+   +------v+-----+
|  Coverage System     | |  Quality   |   |  Reporting  |
|   (debug hook)       | |  Module    |   |  System     |
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
