# Core Module Guide

This guide explains how to use Firmo's core testing functionality for organizing and structuring your tests.

## Introduction

The core module provides the essential building blocks for writing tests with Firmo. These include functions for organizing tests into groups, defining individual test cases, and setting up test environments.

## Basic Test Structure

A Firmo test suite consists of nested `describe` blocks containing individual test cases defined with `it` functions.

### Setting Up a Test File

A typical test file starts by requiring Firmo and extracting the core functions:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
-- Test groups and cases go here
```

### Organizing Tests with Describe

The `describe` function creates a group of related tests:

```lua
describe("String utilities", function()
  -- Tests related to string operations go here
end)
```

### Writing Individual Tests

Inside a `describe` block, use `it` to define specific test cases:

```lua
describe("String utilities", function()
  it("concatenates strings correctly", function()
    expect("Hello" .. " World").to.equal("Hello World")
  end)

  it("converts to uppercase", function()
    expect(string.upper("hello")).to.equal("HELLO")
  end)
end)
```

## Nested Test Groups

You can nest `describe` blocks to create a hierarchical structure:

```lua
describe("Math operations", function()
  describe("Addition", function()
    it("adds positive numbers", function()
      expect(1 + 1).to.equal(2)
    end)

    it("adds negative numbers", function()
      expect(-1 + (-1)).to.equal(-2)
    end)
  end)

  describe("Subtraction", function()
    it("subtracts positive numbers", function()
      expect(5 - 3).to.equal(2)
    end)

    it("subtracts negative numbers", function()
      expect(5 - (-3)).to.equal(8)
    end)
  end)
end)
```

This hierarchical structure helps organize your tests and make the output more readable.

## Test Setup and Teardown

Firmo provides `before` and `after` functions for setting up and cleaning up test environments.

### Setting Up with Before

The `before` function runs before each test in the current `describe` block:

```lua
describe("File operations", function()
  local file_path = "temp_test.txt"
  local file

  before(function()
    -- This runs before each test
    file = io.open(file_path, "w")
    file:write("Initial content")
    file:close()
  end)

  it("reads file content", function()
    local f = io.open(file_path, "r")
    local content = f:read("*all")
    f:close()
    expect(content).to.equal("Initial content")
  end)

  it("appends to file", function()
    local f = io.open(file_path, "a")
    f:write(" plus more")
    f:close()

    f = io.open(file_path, "r")
    local content = f:read("*all")
    f:close()
    expect(content).to.equal("Initial content plus more")
  end)
end)
```

### Cleaning Up with After

The `after` function runs after each test in the current `describe` block:

```lua
describe("Database operations", function()
  local db

  before(function()
    -- Set up database
    db = Database.connect("test_db")
  end)

  it("inserts a record", function()
    local success = db:insert("users", {name = "John"})
    expect(success).to.be.truthy()
  end)

  it("queries a record", function()
    db:insert("users", {name = "Alice"})
    local result = db:query("SELECT * FROM users WHERE name = 'Alice'")
    expect(result).to.have_length(1)
  end)

  after(function()
    -- Clean up after each test
    db:execute("DELETE FROM users")
  end)

  -- This runs at the end of all tests in this describe block
  after(function()
    db:disconnect()
  end)
end)
```

### Hook Execution Order

When using nested `describe` blocks, hooks execute in the following order:

1. Parent `before` hooks
2. Child `before` hooks
3. Test function
4. Child `after` hooks
5. Parent `after` hooks

```lua
describe("Parent", function()
  before(function() print("Parent before") end)
  after(function() print("Parent after") end)

  describe("Child", function()
    before(function() print("Child before") end)
    after(function() print("Child after") end)

    it("runs a test", function()
      print("Test running")
    end)
  end)
end)
-- Output:
-- Parent before
-- Child before
-- Test running
-- Child after
-- Parent after
```

## Test Aliases

Firmo provides some aliases for improved readability:

```lua
local test = firmo.test  -- Alias for firmo.it
test("adds two numbers", function()
  expect(1 + 1).to.equal(2)
end)
```

## Advanced Test Organization

### Using Tags for Test Categories

Tags allow you to categorize and selectively run tests:

```lua
describe("API Client", function()
  -- Apply tags to a describe block
  firmo.tags("integration", "api")

  it("fetches user data", function()
    -- This test has the "integration" and "api" tags
  end)

  describe("Authentication", function()
    -- This describe inherits parent tags
    -- and adds a new one
    firmo.tags("auth")

    it("logs in with valid credentials", function()
      -- This test has "integration", "api", and "auth" tags
    end)
  end)
end)
```

### Shared Setup Across Tests

For setup that's common across multiple test files, you can create shared setup modules:

```lua
-- test_helpers.lua
local TestHelpers = {}
function TestHelpers.create_test_db()
  local db = Database.connect("test_db")
  db:execute("CREATE TABLE IF NOT EXISTS users (id INTEGER, name TEXT)")
  return db
end
function TestHelpers.cleanup_test_db(db)
  db:execute("DROP TABLE IF EXISTS users")
  db:disconnect()
end
return TestHelpers
```

Then in your tests:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local helpers = require("test_helpers")
describe("User Repository", function()
  local db

  before(function()
    db = helpers.create_test_db()
  end)

  -- Tests here

  after(function()
    helpers.cleanup_test_db(db)
  end)
end)
```

## Best Practices

### Test Naming

Names should clearly describe the expected behavior, not the implementation:

```lua
-- Good: describes behavior
it("returns user's full name when both first and last names are provided", function()
  local user = {first_name = "John", last_name = "Doe"}
  expect(get_full_name(user)).to.equal("John Doe")
end)
-- Bad: describes implementation
it("concatenates first_name and last_name with a space", function()
  local user = {first_name = "John", last_name = "Doe"}
  expect(get_full_name(user)).to.equal("John Doe")
end)
```

### Test Structure

Each test should focus on a single aspect of behavior:

```lua
-- Good: separate tests for different behaviors
describe("User validation", function()
  it("requires name to be at least 2 characters", function()
    expect(validate_user({name = "A"})).to.be_falsy()
    expect(validate_user({name = "AB"})).to.be_truthy()
  end)

  it("requires email to have an @ symbol", function()
    expect(validate_user({name = "John", email = "invalid"})).to.be_falsy()
    expect(validate_user({name = "John", email = "john@example.com"})).to.be_truthy()
  end)
end)
-- Bad: multiple behaviors in one test
it("validates user data", function()
  expect(validate_user({name = "A"})).to.be_falsy()
  expect(validate_user({name = "AB"})).to.be_truthy()
  expect(validate_user({name = "John", email = "invalid"})).to.be_falsy()
  expect(validate_user({name = "John", email = "john@example.com"})).to.be_truthy()
end)
```

### Setup and Teardown

Use `before` and `after` hooks consistently:

```lua
describe("File operations", function()
  local test_file = "test.txt"

  -- Good: create in before, clean up in after
  before(function()
    local f = io.open(test_file, "w")
    f:write("test data")
    f:close()
  end)

  it("reads file content", function()
    local f = io.open(test_file, "r")
    local content = f:read("*all")
    f:close()
    expect(content).to.equal("test data")
  end)

  after(function()
    os.remove(test_file)
  end)
end)
```

### Test Independence

Each test should be independent of others:

```lua
describe("Counter", function()
  local counter

  -- Good: reset state before each test
  before(function()
    counter = {value = 0}
  end)

  it("increments correctly", function()
    counter.value = counter.value + 1
    expect(counter.value).to.equal(1)
  end)

  it("decrements correctly", function()
    counter.value = counter.value - 1
    expect(counter.value).to.equal(-1)
  end)
end)
```

## Common Patterns

### Test for Errors

Test that functions throw errors when expected:

```lua
describe("Division function", function()
  it("divides two numbers", function()
    expect(divide(10, 2)).to.equal(5)
  end)

  it("throws error when dividing by zero", function()
    expect(function() divide(10, 0) end).to.fail()
  end)

  it("throws specific error message", function()
    expect(function() divide(10, 0) end).to.fail.with("Cannot divide by zero")
  end)
end)
```

### Conditional Tests

Sometimes you may need to conditionally run tests:

```lua
describe("Platform-specific features", function()
  if os.getenv("OS") == "Windows_NT" then
    it("accesses Windows registry", function()
      -- Windows-specific test
    end)
  else
    it("accesses Unix permissions", function()
      -- Unix-specific test
    end)
  end
end)
```

## Troubleshooting

### Test Not Running

If your test isn't running:

1. Check for typos in `describe` or `it` function names
2. Verify that you're properly requiring and importing functions
3. Check if the test is being filtered out by tags or patterns

### Setup/Teardown Issues

If setup or teardown isn't working as expected:

1. Ensure `before` and `after` functions are inside the correct `describe` block
2. Check for errors in the setup/teardown code
3. Verify that resources are properly created and cleaned up

### Test Independence Problems

If tests affect each other:

1. Reset state in `before` hooks
2. Ensure cleanup in `after` hooks
3. Don't rely on global state unless it's explicitly part of the test

## Conclusion

The core module provides the fundamental building blocks for organizing and writing tests with Firmo. By using `describe`, `it`, `before`, and `after` effectively, you can create well-structured, maintainable test suites that clearly document your code's behavior.
For practical examples, see the [core examples](/examples/core_examples.md) file.
