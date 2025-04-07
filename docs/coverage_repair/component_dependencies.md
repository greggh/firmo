# Coverage v3 Component Dependencies

This document outlines the dependencies between components in the v3 instrumentation-based coverage system.

## Component Dependency Graph

```
                           +----------------+
                           |                |
                           |   init.lua     |  (Public API)
                           |                |
                           +-------+--------+
                                   |
                                   | depends on
                                   v
       +------------------------------------------------------+
       |                                                      |
+------+--------+   +---------------+   +------------------+  |
|               |   |               |   |                  |  |
| data_store.lua+-->+ transformer.lua+-->+ loader/hook.lua +--+
|               |   |               |   |                  |
+------+--------+   +-------+-------+   +------------------+
       ^                    |                     |
       |                    | uses                | uses
       |                    v                     v
       |            +-------+-------+   +------------------+
       |            |               |   |                  |
       |            |   parser.lua  |   | loader/cache.lua |
       |            |               |   |                  |
       |            +---------------+   +------------------+
       |
       |            +---------------+
       |            |               |
       +------------+ tracker.lua   |
       |            |               |
       |            +---------------+
       |
       |            +----------------+   +------------------+
       |            |                |   |                  |
       +------------+ assertion/hook +-->+ assertion/analyzer
       |            |                |   |                  |
       |            +----------------+   +------------------+
       |
       |            +----------------+   +------------------+
       |            |                |   |                  |
       +------------+ report/html.lua|   | report/json.lua  |
                    |                |   |                  |
                    +----------------+   +------------------+
```

## Component Dependency Table

| Component | Depends On | Dependency Type |
|-----------|------------|-----------------|
| **init.lua** | data_store.lua | Core data model |
| | loader/hook.lua | Module instrumentation |
| | assertion/hook.lua | Assertion tracking |
| | report/html.lua | HTML reporting |
| | report/json.lua | JSON reporting |
| **data_store.lua** | tracker.lua | Data collection |
| **transformer.lua** | parser.lua | Code parsing |
| | sourcemap.lua | Line mapping |
| **loader/hook.lua** | transformer.lua | Code transformation |
| | loader/cache.lua | Module caching |
| **assertion/hook.lua** | assertion/analyzer.lua | Stack analysis |
| **report/html.lua** | data_store.lua | Coverage data |
| **report/json.lua** | data_store.lua | Coverage data |

## Implementation Order

Based on the dependencies, the implementation should follow this order:

1. **First Layer** (No dependencies):
   - parser.lua
   - sourcemap.lua
   - loader/cache.lua
   - assertion/analyzer.lua

2. **Second Layer** (Depends on First Layer):
   - data_store.lua
   - transformer.lua 
   - tracker.lua

3. **Third Layer** (Depends on Second Layer):
   - loader/hook.lua
   - assertion/hook.lua
   - report/html.lua
   - report/json.lua

4. **Fourth Layer** (Depends on Third Layer):
   - init.lua (Public API)

## Component Implementations

### Core Components

#### data_store.lua
- **Purpose**: Stores and manages coverage data
- **Dependencies**: tracker.lua
- **Key Responsibilities**:
  - Maintain the three-state data structure
  - Track line execution and coverage status
  - Normalize data for reporting

#### tracker.lua
- **Purpose**: Provides global tracking functions
- **Dependencies**: None
- **Key Responsibilities**:
  - Expose tracking functions globally
  - Record line execution events
  - Update data store

### Instrumentation Components

#### parser.lua
- **Purpose**: Parses Lua code into AST
- **Dependencies**: None
- **Key Responsibilities**:
  - Parse Lua code accurately
  - Handle all Lua syntax constructs
  - Identify logical code lines

#### transformer.lua
- **Purpose**: Transforms Lua code to add tracking calls
- **Dependencies**: parser.lua, sourcemap.lua
- **Key Responsibilities**:
  - Insert tracking calls at appropriate points
  - Preserve original code semantics
  - Generate sourcemaps for line mapping

#### sourcemap.lua
- **Purpose**: Maps between original and transformed code
- **Dependencies**: None
- **Key Responsibilities**:
  - Track line number transformations
  - Map error locations back to original code
  - Support error reporting

### Module Loading Components

#### loader/hook.lua
- **Purpose**: Hooks into Lua module loading
- **Dependencies**: transformer.lua, loader/cache.lua
- **Key Responsibilities**:
  - Intercept module loading
  - Instrument modules on load
  - Manage module loading lifecycle

#### loader/cache.lua
- **Purpose**: Caches instrumented modules
- **Dependencies**: None
- **Key Responsibilities**:
  - Store instrumented modules
  - Provide fast lookup of transformed code
  - Manage cache lifecycle

### Assertion Integration Components

#### assertion/hook.lua
- **Purpose**: Hooks into assertion system
- **Dependencies**: assertion/analyzer.lua
- **Key Responsibilities**:
  - Intercept assertion calls
  - Capture stack traces for assertions
  - Mark verified lines as covered

#### assertion/analyzer.lua
- **Purpose**: Analyzes assertion coverage
- **Dependencies**: None
- **Key Responsibilities**:
  - Analyze stack traces
  - Determine which lines are verified by assertions
  - Connect assertions to executed code

### Reporting Components

#### report/html.lua
- **Purpose**: Generates HTML coverage reports
- **Dependencies**: data_store.lua
- **Key Responsibilities**:
  - Generate visual three-state reports
  - Create file navigation
  - Show detailed line information

#### report/json.lua
- **Purpose**: Generates JSON coverage data
- **Dependencies**: data_store.lua
- **Key Responsibilities**:
  - Generate machine-readable coverage data
  - Support external tools integration
  - Include detailed metadata

### Public API

#### init.lua
- **Purpose**: Provides main public API
- **Dependencies**: All components
- **Key Responsibilities**:
  - Initialize all components
  - Manage coverage lifecycle
  - Provide user-facing functions

## Parallel Development Opportunities

Components that can be developed in parallel:

1. **Parser & Transformer Team**:
   - parser.lua
   - transformer.lua
   - sourcemap.lua

2. **Runtime Tracking Team**:
   - data_store.lua
   - tracker.lua

3. **Module Loading Team**:
   - loader/hook.lua
   - loader/cache.lua

4. **Assertion Integration Team**:
   - assertion/hook.lua
   - assertion/analyzer.lua

5. **Reporting Team**:
   - report/html.lua
   - report/json.lua

## Integration Points

Critical integration points that need careful coordination:

1. **Data Model Integration**:
   - All components must use consistent data structures
   - Data normalization must be consistent

2. **Instrumentation & Module Loading**:
   - Transformer must produce code compatible with module loader
   - Sourcemaps must be created and passed correctly

3. **Assertion & Runtime Tracking**:
   - Assertion hooks must correctly identify executed lines
   - Runtime tracker must expose appropriate hooks for assertions

4. **Reporting & Data Model**:
   - Reporters must handle all possible data states
   - Three-state distinction must be preserved in reports