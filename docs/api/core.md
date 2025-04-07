# Core Functions
This document describes the core functions provided by Firmo for defining and organizing tests.

## Test Structure Functions

### describe(name, fn)
Creates a group of tests with a descriptive name.
**Parameters:**

- `name` (string): Name of the test group
- `fn` (function): Function containing the test definitions
**Returns:** None
**Example:**

```lua
describe("Math operations", function()
  -- Tests go here
end)

```
**Notes:**

- `describe` blocks can be nested to create a hierarchical structure
- Before/after hooks are scoped to their respective `describe` block
- Test names should be descriptive of the functionality being tested

### it(name, fn)
Defines an individual test case.
**Parameters:**

- `name` (string): Name of the test
- `fn` (function): Function containing the test code
**Returns:** None
**Example:**

```lua
it("adds two numbers correctly", function()
  expect(1 + 1).to.equal(2)
end)

```
**Notes:**

- Test names should describe the expected behavior, not the implementation
- Each test should focus on a single aspect of behavior
- Use `expect` within tests to make assertions

## Setup and Teardown

### before(fn)
Registers a function to run before each test in the current describe block.
**Parameters:**

- `fn` (function): Function to run before each test
**Returns:** None
**Example:**

```lua
describe("Database tests", function()
  before(function()
    -- Set up database connection
    db = Database.connect()
  end)
  it("queries records", function()
    -- Test using the db connection
  end)
end)

```
**Notes:**

- `before` hooks run in the order they are defined
- Each `before` hook has access to the test's name via its parameter
- `before` hooks are scoped to their describe block and nested describe blocks

### after(fn)
Registers a function to run after each test in the current describe block.
**Parameters:**

- `fn` (function): Function to run after each test
**Returns:** None
**Example:**

```lua
describe("File operations", function()
  after(function()
    -- Clean up temporary files
    os.remove("temp.txt")
  end)
  it("writes to a file", function()
    -- Test that creates temp.txt
  end)
end)

```
**Notes:**

- `after` hooks run in the order they are defined
- Each `after` hook has access to the test's name via its parameter
- `after` hooks are useful for cleanup operations
- `after` hooks run even if the test fails

## Aliases
The following aliases are provided for convenience:

- `firmo.test` - Alias for `firmo.it`

## Examples

### Basic Test Structure

```lua
describe("Calculator", function()
  local calc
  before(function()
    calc = Calculator.new()
  end)
  describe("Addition", function()
    it("adds positive numbers", function()
      expect(calc:add(2, 3)).to.equal(5)
    end)
    it("adds negative numbers", function()
      expect(calc:add(-2, -3)).to.equal(-5)
    end)
  end)
  describe("Subtraction", function()
    it("subtracts numbers", function()
      expect(calc:subtract(5, 2)).to.equal(3)
    end)
  end)
  after(function()
    calc:shutdown()
  end)
end)

```

### Test Organization Best Practices

1. Group related tests with `describe`
2. Use nested `describe` blocks for sub-features
3. Keep test functions small and focused
4. Use `before` for common setup
5. Use `after` for cleanup
6. Give tests descriptive names that explain the expected behavior

