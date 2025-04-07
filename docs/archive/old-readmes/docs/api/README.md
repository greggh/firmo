# Firmo API Reference
This section contains detailed API documentation for all Firmo functionality.

## Table of Contents

- [Core Functions](core.md) - Essential test functions (`describe`, `it`, etc.)
- [Assertions](assertion.md) - Assertion functions for test verification
- [Async Testing](async.md) - APIs for testing asynchronous code
- [Mocking](mocking.md) - Mocking, spying, and stubbing capabilities
- [Module Reset](module_reset.md) - Module management utilities for clean test state
- [Coverage](coverage.md) - Code coverage tracking and reporting
- [Quality](quality.md) - Test quality validation
- [Reporting](reporting.md) - Report generation and file operations
- [Codefix](codefix.md) - Code quality checking and fixing
- [Test Filtering](filtering.md) - Test filtering and tagging support
- [CLI](cli.md) - Command-line interface and options
- [Test Discovery](discovery.md) - Automatic test discovery capabilities

## API Overview
Firmo provides a comprehensive API for testing Lua code. The API is designed to be simple, intuitive, and powerful.

### Core Functions

```lua
-- Define a test group
firmo.describe("Group name", function()
  -- Define a test
  firmo.it("Test name", function()
    -- Test code here
  end)
end)
-- Setup and teardown
firmo.before(function() -- Run before each test end)
firmo.after(function() -- Run after each test end)

```

### Assertions

```lua
-- Basic assertions
expect(value).to.exist()
expect(value).to.equal(expected)
expect(value).to.be.truthy()
-- Table assertions
expect(table).to.contain.key("id")
expect(table).to.contain.values({"a", "b"})
-- String assertions
expect(str).to.start_with("prefix")

```

### Async Testing

```lua
-- Async test
firmo.it_async("Async test", function()
  local result = nil
  firmo.await(100) -- Wait 100ms
  expect(result).to.exist()
end)
-- Run async operations in parallel
local results = firmo.parallel_async(
  function() firmo.await(100); return "first" end,
  function() firmo.await(200); return "second" end
)

```

### Module Reset

```lua
-- Reset and reload a module
local fresh_module = firmo.reset_module("app.module")
-- Run test with a fresh module
firmo.with_fresh_module("app.module", function(mod)
  -- Test using the fresh module
end)

```

### Mocking

```lua
-- Create a mock
local mock_obj = firmo.mock(dependencies)
mock_obj:stub("method", function() return "mocked" end)
-- Create a spy
local spy = firmo.spy(function() end)

```

### Coverage and Quality

```lua
-- Enable coverage tracking
firmo.coverage_options.enabled = true
firmo.coverage_options.include = {"src/*.lua"}
firmo.coverage_options.exclude = {"tests/*.lua"}
-- Run tests with coverage
lua test.lua tests/ --coverage
-- Generate a coverage report
lua test.lua tests/ --coverage --format html
-- Enable quality validation
firmo.quality_options.enabled = true
firmo.quality_options.level = 3 -- Comprehensive quality level
-- Generate a quality report
firmo.generate_quality_report("html", "./quality-report.html")

```

### Reporting

```lua
-- Get the reporting module
local reporting = require("src.reporting")
-- Format and save reports
local coverage_data = firmo.get_coverage_data()
local quality_data = firmo.get_quality_data()
-- Auto-save all report formats
reporting.auto_save_reports(coverage_data, quality_data, "./reports")

```

### Code Quality and Fixing

```lua
-- Enable code fixing
firmo.codefix_options.enabled = true
-- Fix a specific file
firmo.fix_file("path/to/file.lua")
-- Fix multiple files
firmo.fix_files({"file1.lua", "file2.lua"})
-- Find and fix all Lua files in a directory
firmo.fix_lua_files("src")

```
See the individual sections for detailed documentation on each API area.

