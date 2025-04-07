# Firmo Configuration Details

This directory contains comprehensive documentation for configuring various modules in the Firmo testing framework. Each document provides detailed information about configuration options, examples, best practices, and troubleshooting guidance.

## Overview

Firmo uses a centralized configuration system that allows you to configure all modules consistently through:

1. The `.firmo-config.lua` file in your project root
2. Programmatic configuration via module-specific `configure()` methods
3. Command-line arguments for runtime configuration

The documents in this directory explain how to configure each module in detail.

## Available Configuration Documentation

| Module | File | Description |
|--------|------|-------------|
| **Core Modules** | | |
| Quality Validation | [quality.md](./quality.md) | Configure test quality requirements and validation |
| Async Testing | [async.md](./async.md) | Configure asynchronous testing behavior |
| Error Handler | [error_handler.md](./error_handler.md) | Configure error handling and reporting |
| **Test Execution** | | |
| Parallel Execution | [parallel.md](./parallel.md) | Configure parallel test execution |
| File Watcher | [watcher.md](./watcher.md) | Configure automatic file watching for tests |
| Test Discovery | [discovery.md](./discovery.md) | Configure test file discovery patterns |
| **User Interface** | | |
| Command Line Interface | [cli.md](./cli.md) | Configure command-line interface options |
| Interactive Mode | [interactive.md](./interactive.md) | Configure interactive test running mode |
| **Reporting** | | |
| Report Formatters | [formatters.md](./formatters.md) | Configure coverage report formats |
| **Utilities** | | |
| Logging | [logging.md](./logging.md) | Configure logging behavior and output |
| Benchmark | [benchmark.md](./benchmark.md) | Configure performance benchmarking |
| Temporary Files | [temp_file.md](./temp_file.md) | Configure temporary file management |

## Common Configuration Patterns

All Firmo modules follow these configuration patterns:

### Configuration in .firmo-config.lua

```lua
-- .firmo-config.lua
return {
  module_name = {
    option1 = value1,
    option2 = value2,
    nested_options = {
      nested1 = value3,
      nested2 = value4
    }
  }
}
```

### Programmatic Configuration

```lua
local module = require("lib.module_name")

-- Configure with options table
module.configure({
  option1 = value1,
  option2 = value2
})

-- Method chaining (when supported)
module.set_option1(value1)
      .set_option2(value2)
```

### Command-Line Configuration

```bash
# Use command-line flags for runtime configuration
lua test.lua --module-option1=value1 --module-option2=value2
```

## Environment-Specific Configuration

You can create environment-specific configuration files:

```
.firmo-config.lua             # Default configuration
.firmo-config.development.lua # Development environment
.firmo-config.ci.lua          # Continuous integration
.firmo-config.production.lua  # Production testing
```

Load a specific configuration with:

```bash
lua test.lua --config=.firmo-config.ci.lua tests/
```

Or programmatically:

```lua
local central_config = require("lib.core.central_config")
central_config.load_from_file(".firmo-config.ci.lua")
```

## Validation and Debugging

All configuration options are validated when loaded. You can debug configuration issues with:

```lua
-- Get a module's current configuration
local config = module.debug_config()
print(config.using_central_config)  -- Whether central_config is being used
print(config.local_config.option1)  -- Current value of option1
```

## See Also

For a general overview of Firmo's configuration system, see:
- [Central Configuration Guide](../central_config.md)

For specific configuration examples, see:
- [Configuration Examples](../../../examples/config_examples.md)