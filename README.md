<div align="center">
THIS IS ALPHA SOFTWARE, DO NOT USE UNLESS YOU UNDERSTAND THAT, AND ARE LOOKING TO HELP.

# Firmo

[![CI](https://github.com/greggh/firmo/actions/workflows/ci.yml/badge.svg?style=flat-square)](https://github.com/greggh/firmo/actions/workflows/ci.yml)
[![Documentation](https://github.com/greggh/firmo/actions/workflows/docs.yml/badge.svg?style=flat-square)](https://github.com/greggh/firmo/actions/workflows/docs.yml)
[![GitHub License](https://img.shields.io/github/license/greggh/firmo?style=flat-square)](https://github.com/greggh/firmo/blob/main/LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/greggh/firmo?style=flat-square)](https://github.com/greggh/firmo/stargazers)
[![Version](https://img.shields.io/badge/Version-0.7.5-blue?style=flat-square)](https://github.com/greggh/firmo/releases/tag/v0.7.5)
[![Discussions](https://img.shields.io/github/discussions/greggh/firmo?style=flat-square&logo=github)](https://github.com/greggh/firmo/discussions)

_A powerful testing library for Lua projects. This enhanced fork of [lust](https://github.com/bjornbytes/lust) adds significant new functionality while maintaining the simplicity and elegance of the original._

[Features](#features) •
[Installation](#installation) •
[Quick Start](#quick-start) •
[Documentation](#documentation) •
[Contributing](#contributing) •
[License](#license) •
[Discussions](https://github.com/greggh/firmo/discussions)

</div>

## Features

- 🧪 **Familiar Syntax** - BDD-style `describe`/`it` blocks for intuitive test organization
- ✅ **Rich Assertions** - Extensive expect-style assertion library with detailed diffs
- 🕵️ **Function Spies** - Track function calls and arguments
- 🔄 **Before/After Hooks** - For setup and teardown
- 🧩 **Module Management** - Reset and reload modules with `reset_module()` for clean state
- 🔍 **Automatic Test Discovery** - Find and run tests without manual configuration
- 🏷️ **Filtering & Tagging** - Run specific test groups or tagged tests
- 🎯 **Focused Tests** - Run only specific tests with `fdescribe`/`fit`
- ⏸️ **Excluded Tests** - Skip specific tests with `xdescribe`/`xit`
- 📊 **Enhanced Reporting** - Clear, colorful summaries of test results
- 🎨 **Output Formatting** - Multiple output styles including dot notation and compact mode
- ⏱️ **Async Support** - Test asynchronous code with parallel operations and conditions
- 👁️ **Watch Mode** - Continuous testing with automatic file change detection
- 🤖 **Mocking System** - Create and manage mocks for dependencies
- 💻 **Cross-Platform** - Works in console and non-console environments
- 📈 **Code Coverage** - Track and report code coverage with multiple output formats
- 🔬 **Quality Validation** - Validate test quality with customizable levels
- 📋 **Modular Reporting** - Centralized reporting system with robust fallbacks
- 🧹 **Code Fixing** - Fix common Lua code issues with custom fixers and tool integration (StyLua, Luacheck)
- ⚙️ **Central Configuration** - Unified configuration system across all modules
- ⚡ **Parallel Execution** - Run tests in parallel for improved performance
- 📝 **Structured Logging** - Comprehensive logging with multiple output formats
- 🔌 **Interactive Mode** - Command-line interface for interactive test running

## Quick Start

Copy the `firmo.lua` file to your project and require it:

### Option 1: Expose all functions globally (new in v0.7.1)

```lua
local firmo = require('firmo')
firmo.expose_globals() -- Makes all test functions available globally
describe('my project', function()
  before_each(function()
    -- This gets run before every test.
  end)
  describe('module1', function() -- Can be nested
    it('feature1', function()
      assert.equal('expected value', 'expected value') -- New assertion helper
      assert.is_true(true) -- Another assertion helper
    end)
    it('feature2', function()
      expect(nil).to.exist() -- The standard expect API still works
    end)
  end)
end)
```

### Option 2: Import specific functions (traditional approach)

```lua
local firmo = require 'firmo'
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
describe('my project', function()
  firmo.before(function()
    -- This gets run before every test.
  end)
  describe('module1', function() -- Can be nested
    it('feature1', function()
      expect(1).to.be.a('number') -- Pass
      expect('astring').to.equal('astring') -- Pass
    end)
    it('feature2', function()
      expect(nil).to.exist() -- Fail
    end)
  end)
end)
```

## Configuration and Customization

Firmo provides extensive configuration options through its central configuration system:

```lua
-- Create or modify .firmo-config.lua in your project root
return {
  -- Test discovery configuration
  discovery = {
    include = {"*_test.lua", "test_*.lua"},
    exclude = {"*_fixture.lua"}
  },
  
  -- Coverage configuration
  coverage = {
    enabled = true,
    include = function(file_path)
      return file_path:match("^src/") ~= nil
    end,
    exclude = function(file_path)
      return file_path:match("^src/vendor/") ~= nil
    end,
    threshold = 80,
    output_dir = "./coverage-reports"
  },
  
  -- Reporting configuration
  reporting = {
    format = "html",
    formatters = {
      html = {
        theme = "dark",
        show_line_numbers = true
      }
    }
  },
  
  -- Parallel execution configuration
  parallel = {
    workers = 4,
    timeout = 60,
    fail_fast = true
  },
  
  -- Logging configuration
  logging = {
    level = "INFO",
    output_file = "test-log.txt"
  }
}
```

For detailed configuration options, see the [Configuration Details](docs/guides/configuration-details/README.md) directory.

## Command Line Interface

Firmo provides a comprehensive command line interface:

```bash
# Run all tests in the tests directory
lua test.lua tests/

# Run with coverage and generate HTML report
lua test.lua --coverage --format=html tests/

# Run in watch mode
lua test.lua --watch tests/

# Run in parallel with 8 workers
lua test.lua --parallel --workers=8 tests/

# Run with quality validation
lua test.lua --quality --quality-level=3 tests/

# Run in interactive mode
lua test.lua --interactive

# Run with focused tags
lua test.lua --tags="unit,fast" tests/

# Filter tests by pattern
lua test.lua --pattern="database" tests/
```

## Documentation

Comprehensive documentation is available in the [docs](docs/) directory:

### Getting Started
- [Getting Started Guide](docs/guides/getting-started.md) - Detailed guide for beginners
- [Migration Guide](docs/guides/migrating.md) - Migrating from other test frameworks

### API Reference
- [Core API](docs/api/core.md) - Core testing functionality
- [Assertions API](docs/api/assertions.md) - Assertion functions and matchers
- [Mocking API](docs/api/mocking.md) - Mocking, stubbing, and spying
- [Async API](docs/api/async.md) - Asynchronous testing
- [Logging API](docs/api/logging.md) - Structured logging

### Configuration
- [Central Configuration Guide](docs/guides/central_config.md) - Unified configuration system
- [Configuration Details](docs/guides/configuration-details/README.md) - Detailed module-specific configuration

### Advanced Features
- [Coverage Guide](docs/guides/coverage.md) - Code coverage tracking and reporting
- [Quality Validation](docs/guides/quality.md) - Ensuring test quality
- [Parallel Execution](docs/guides/parallel.md) - Running tests in parallel

### Example Code
- [Examples Directory](examples/) - Example scripts demonstrating features

## Core Functions

### Test Definition

```lua
describe("math operations", function()
  -- Regular test group - runs normally
end)

fdescribe("focused group", function()
  -- Focused test group - these tests ALWAYS run even when others are focused
end)

xdescribe("excluded group", function()
  -- Excluded test group - these tests NEVER run
end)

it("adds two numbers correctly", function()
  -- Regular test - runs normally
  expect(2 + 2).to.equal(4)
end)

fit("important test", function()
  -- Focused test - this test ALWAYS runs even when others are focused
  expect(true).to.be.truthy()
end)

xit("work in progress", function()
  -- Excluded test - this test NEVER runs
  expect(false).to.be.truthy() -- Won't fail since it's excluded
end)
```

### Lifecycle Hooks

```lua
describe("database tests", function()
  before(function()
    -- Set up database connection before each test
  end)
  
  after(function()
    -- Close database connection after each test
  end)
  
  it("queries data correctly", function()
    -- Test here
  end)
end)
```

### Assertions

Firmo uses "expect style" assertions that can be chained for readable tests:

```lua
-- Basic assertions
expect(value).to.exist()
expect(value).to.equal(expected)
expect(value).to.be.truthy()
expect(value).to.be.a("string")
expect(value).to.match("pattern")

-- Negated assertions
expect(value).to_not.equal(unexpected)
expect(value).to_not.be.nil()

-- Table assertions
expect(table).to.contain.key("id")
expect(table).to.contain.value("example")

-- Numeric assertions
expect(value).to.be_greater_than(minimum)
expect(value).to.be_less_than(maximum)
expect(value).to.be_between(min, max)

-- Error assertions
expect(function_that_throws).to.fail()
expect(function_that_throws).to.fail.with("pattern")
```

### Mocking

```lua
-- Create a spy to track function calls
local spy = firmo.spy(myFunction)
spy(1, 2, 3)
expect(spy.called).to.be.truthy()
expect(spy.call_count).to.equal(1)

-- Create a stub that returns a fixed value
local stub = firmo.stub(42)
expect(stub()).to.equal(42)

-- Create a mock with specific behaviors
local db_mock = firmo.mock(database)
db_mock:stub("query", function(query_string)
  return {rows = {{id = 1, name = "Test"}}}
end)

-- Use the mock in your tests
local result = database.query("SELECT * FROM users")
expect(result.rows[1].name).to.equal("Test")
expect(db_mock.query:called_with("SELECT * FROM users")).to.be.truthy()
```

### Async Testing

```lua
-- Test asynchronous code
it_async("fetches data asynchronously", function()
  local result = nil
  
  -- Start async operation
  start_async_operation(function(data)
    result = data
  end)
  
  -- Wait for completion
  firmo.await(100) -- Wait 100ms
  
  -- Make assertions
  expect(result).to.exist()
  expect(result.status).to.equal("success")
end)

-- Wait for a condition
it_async("waits for a condition", function()
  local completed = false
  
  -- Start operation
  setTimeout(function() completed = true end, 50)
  
  -- Wait until condition is true or timeout after 200ms
  firmo.wait_until(function() return completed end, 200)
  
  -- Assert condition was met
  expect(completed).to.be.truthy()
end)
```

## Installation

### Method 1: Direct File

Simply copy `firmo.lua` into your project directory:

```bash
# Download the file
curl -O https://raw.githubusercontent.com/greggh/firmo/main/firmo.lua

# Or clone and copy
git clone https://github.com/greggh/firmo.git
cp firmo/firmo.lua your-project/
```

### Method 2: LuaRocks

```bash
luarocks install firmo
```

### Method 3: As a Git Submodule

```bash
# Add as submodule
git submodule add https://github.com/greggh/firmo.git deps/firmo

# Update your package path in your main Lua file
package.path = package.path .. ";./deps/firmo/?.lua"
```

### Method 4: With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'greggh/firmo',
  ft = 'lua',
  cmd = { 'FirmoRun' }
}
```

### Method 5: With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'greggh/firmo',
  ft = 'lua',
  cmd = { 'FirmoRun' },
}
```

## Usage with Non-Console Environments

If Lua is embedded in an application without ANSI color support:

```lua
local firmo = require('firmo').nocolor()
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT, see [LICENSE](LICENSE) for details.

## Acknowledgments

firmo builds on the original [Lust](https://github.com/bjornbytes/lust) testing framework and takes inspiration from several excellent Lua testing libraries:

- [lunarmodules/busted](https://github.com/lunarmodules/busted) - A powerful, flexible testing framework with rich features
- [lunarmodules/luassert](https://github.com/lunarmodules/luassert) - An extensible assertion library with advanced matching capabilities
  We're grateful to these projects for advancing the state of Lua testing and providing inspiration for firmo's enhanced features.

---

<div align="center">
  <p>Made with ❤️ by <a href="https://github.com/greggh">Gregg Housh</a></p>
</div>