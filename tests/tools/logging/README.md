# Logging Module Tests

This directory contains tests for the firmo logging system. The logging module provides structured logging capabilities for debugging, monitoring, and auditing.

## Directory Contents

- **logging_test.lua** - Tests for logging functionality

## Logging System Features

The firmo logging module provides:

- **Multiple severity levels** - FATAL, ERROR, WARN, INFO, DEBUG, TRACE
- **Module-specific configuration** - Configure logging per module
- **Colored output** - Color-coded console output by severity
- **File output** - Write logs to files with rotation
- **Structured logging** - Support for structured data in log entries
- **Filtering** - Filter logs by level, module, or custom criteria
- **Rotation** - Size-based log rotation with configurable thresholds
- **Buffering** - Optional log buffering for performance
- **Export** - Export logs to external systems
- **Search** - Find log entries matching criteria
- **Formatter integration** - Integrate with test formatters

## Logging Patterns

```lua
local logging = require "lib.tools.logging"

-- Basic logging
logging.info("Simple message")

-- Structured logging with parameters
logging.debug("Operation completed", {
  duration = 1234,
  status = "success",
  module = "coverage"
})

-- Module-specific configuration
logging.configure({
  module = "coverage",
  level = "DEBUG",
  file = "coverage.log"
})

-- Log with context
logging.error("Failed to open file", {
  file = filename,
  error = err
})
```

## Logging Style Guide

The logging module follows a consistent style guide:

- Use verbs in past tense for completed actions
- Use clear, descriptive messages
- Separate message content from contextual data
- Include relevant parameters for debugging
- Use appropriate severity levels
- Maintain consistent naming in parameter tables

## Running Tests

To run all logging tests:
```
lua test.lua tests/tools/logging/
```

To run a specific logging test:
```
lua test.lua tests/tools/logging/logging_test.lua
```

See the [Logging API Documentation](/docs/api/logging.md) and [Logging Style Guide](/docs/api/logging_style_guide.md) for more information.