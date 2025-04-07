# Core Framework Tests

This directory contains tests for the core components of the firmo testing framework. These tests validate the fundamental functionality upon which all other features are built.

## Directory Contents

- **config_test.lua** - Tests for configuration management
- **firmo_test.lua** - Tests for core framework functionality
- **module_reset_test.lua** - Tests for module reset system
- **tagging_test.lua** - Tests for test tagging functionality
- **type_checking_test.lua** - Tests for type validation utilities

## Core Framework Components

The firmo core provides the foundational structure:

- Nested describe/it blocks (BDD-style)
- Test lifecycle hooks (before/after)
- Tagging and filtering
- Configuration management
- Module isolation and reset
- Type validation utilities
- Test runner integration

## Module Reset System

The module reset system ensures proper test isolation by clearing require caches between test runs. This prevents state from one test affecting subsequent tests.

## Configuration System

The configuration system provides a centralized way to manage test settings across the framework, with support for:

- File-based configuration (.firmo-config.lua)
- Command-line overrides
- Environment variable integration
- Hierarchical configuration structure

## Running Tests

To run all core tests:
```
lua test.lua tests/core/
```

To run a specific core test:
```
lua test.lua tests/core/config_test.lua
```

See the [Core API Documentation](/docs/api/core.md) for more information.