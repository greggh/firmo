# Getting Started with Firmo


This guide will help you get started with Firmo, a lightweight and powerful testing framework for Lua.

## Installation


### Method 1: Copy the File


The simplest way to use Firmo is to copy the `firmo.lua` file directly into your project.


1. Download the `firmo.lua` file from the repository
2. Place it in your project directory or in a lib/vendor directory


### Method 2: LuaRocks (Coming Soon)



```bash
luarocks install firmo
```



## Basic Usage


### 1. Create Your First Test File


Create a file named `example_test.lua` with the following content:


```lua
-- Require the Firmo library
local firmo = require("firmo")
-- Import the core functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
-- Define a test suite
describe("Math operations", function()
  -- Define a test
  it("adds two numbers correctly", function()
    expect(1 + 1).to.equal(2)
  end)
  -- Define another test
  it("subtracts two numbers correctly", function()
    expect(5 - 3).to.equal(2)
  end)
  -- Test for errors
  it("raises an error when dividing by zero", function()
    expect(function() 
      return 5 / 0 
    end).to.fail()
  end)
end)
```



### 2. Run the Test


Run the test using the main `test.lua` script:

```bash
lua firmo.lua example_test.lua
```


You should see output similar to:


```text
Math operations
 PASS adds two numbers correctly
 PASS subtracts two numbers correctly
 PASS raises an error when dividing by zero
```


Note: Tests are run by `scripts/runner.lua` or `run_all_tests.lua`, not by directly executing the test file.

## Writing Tests


### Test Structure


Firmo uses a BDD-style syntax with describe and it blocks:


- `describe(name, fn)`: Groups related tests
- `it(name, fn)`: Defines an individual test
- `expect(value)`: Creates assertions about a value


### Assertions


Firmo provides a rich set of assertions:


```lua
-- Basic assertions
expect(value).to.exist()
expect(value).to.equal(expected)
expect(value).to.be.truthy()
expect(value).to.be.a("string")
-- Table assertions
expect(table).to.contain.key("id")
expect(table).to.contain.value("example")
-- String assertions
expect(str).to.start_with("hello")
expect(str).to.end_with("world")
expect(str).to.be.uppercase()
expect(str).to.be.lowercase()
-- Numeric assertions
expect(num).to.be_greater_than(5)
expect(num).to.be_approximately(0.3, 0.0001)
expect(num).to.be.positive()
expect(num).to.be.negative()
expect(num).to.be.integer()
-- Collection assertions
expect(str).to.have_length(5)
expect(array).to.have_size(10)
expect(empty_table).to.be.empty()
-- Object assertions
expect(object).to.have_property("name")
expect(object).to.have_property("age", 30)
expect(object).to.match_schema({name = "string", age = "number"})
-- Function behavior assertions
expect(function() counter.value = counter.value + 1 end)
  .to.change(function() return counter.value end)
expect(function() counter.value = counter.value + 1 end)
  .to.increase(function() return counter.value end)
expect(function() counter.value = counter.value - 1 end)
  .to.decrease(function() return counter.value end)
-- Error assertions
expect(function() error("oops") end).to.fail()
expect(function() error("invalid") end).to.throw.error_matching("invalid")
-- Deep equality
expect(complex_object).to.deep_equal(expected_object)
```



### Before and After Hooks


First import the hooks, then use them for setup and teardown:


```lua
-- Import hooks along with other test functions
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
describe("Database tests", function()
  local db
  before(function()
    -- Set up database connection before each test
    db = Database.connect()
    -- Use structured logging for setup information
    print("Database connected") -- Simple output for example
  end)

  it("queries data", function()
    local result = db:query("SELECT * FROM users")
    expect(#result).to.be_greater_than(0)
  end)

  after(function()
    -- Clean up after each test
    db:disconnect()
    print("Database disconnected") -- Simple output for example
  end)
end)
end)
```



## Organizing Tests


### Nested Describe Blocks


You can nest `describe` blocks to organize your tests:


```lua
describe("User module", function()
  describe("Authentication", function()
    it("logs in valid users", function()
      -- Test code
    end)
    it("rejects invalid credentials", function()
      -- Test code
    end)
  end)
  describe("Profile", function()
    it("updates user information", function()
      -- Test code
    end)
  end)
end)
```



### Tagging Tests


You can add tags to your tests for filtering:


```lua
describe("User module", function()
  firmo.tags("unit")
  it("validates username format", function()
    -- Fast unit test
  end)
  firmo.tags("integration", "slow")
  it("stores user in database", function()
    -- Slower integration test
  end)
end)
```



## Running Tests


### Running a Single Test File



```bash
lua firmo.lua tests/example_test.lua
```



### Running Multiple Test Files


Create a directory for your tests (e.g., `tests`) and use Firmo's test discovery:

Use the standard runner, passing the directory path:

```bash
lua firmo.lua tests/
```



### Filtering Tests
Run only tests matching a name pattern using `--filter`:

```bash
lua firmo.lua --filter authentication tests/example_test.lua
```

Filtering by tags directly via the command line (`--tags`) is not currently supported. Use programmatic filtering (`firmo.only_tags(...)`) in your test setup or custom scripts for tag-based execution control.
```



### Running Tests with Watch Mode


For continuous testing that automatically reruns tests when files change:


```bash
lua firmo.lua --watch tests/example_test.lua
```



## Asynchronous Testing


For testing asynchronous code, use the async testing support:


```lua
firmo.it_async("fetches data asynchronously", function()
  local result = nil
  -- Start async operation
  fetchData(function(data) 
    result = data
  end)
  -- Wait for operation to complete
  firmo.wait_until(function() return result ~= nil end)
  -- Make assertions on the result
  expect(result).to.exist()
  expect(result.status).to.equal("success")
end)
```



## Mocking


For isolating your tests, use the mocking system:


```lua
local mocking = require("lib.mocking")
-- Create a mock database
local db_mock = mocking.mock(database)
-- Stub methods with test implementations
db_mock:stub("query", function(query_string)
  return {
    rows = {{id = 1, name = "test"}}
  }
end)
-- Test code that uses the database
local users = UserService.get_users()
-- Optionally verify calls using expect(spy).to.be.called() if using spies
-- Restore original methods
db_mock:restore()
```



## Next Steps


Now that you understand the basics of Firmo, you can:


1. Explore the [API Reference](../api/README.md) for detailed documentation.
2. Browse the [Examples Index](examples.md) for practical usage scenarios.
3. Check out [Advanced Topics](../guides/advanced-topics.md) for advanced features.

Happy testing!
