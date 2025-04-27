---@diagnostic disable: undefined-global, redundant-parameter
--- assertions_example.lua
--
-- This file provides a comprehensive demonstration of the various assertion
-- functions available in the Firmo testing framework. It covers basic
-- equality, type checking, string manipulation, numeric comparisons,
-- table inspections, error handling, and more complex scenarios.
--

-- Comprehensive example of Firmo's assertion functionality
---@type Firmo
local firmo = require("firmo")
---@type TestHelperModule
local test_helper = require("lib.tools.test_helper")
---@type ErrorHandlerModule
local error_handler = require("lib.tools.error_handler")

-- Extract the testing functions we need
---@type fun(description: string, callback: function) describe Test suite container function
---@type fun(description: string, options: table|nil, callback: function) it Test case function with optional parameters
---@type fun(value: any) expect Assertion generator function
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
---@type fun(callback: function) after Teardown function that runs after each test
local before, after = firmo.before, firmo.after

-- Helper function to organize a test series
---@param name string Name of the assertion group
---@param assertions table[] Array of assertion objects with desc and test properties
---@return nil
local function test_assertion_group(name, assertions)
  describe(name, function()
    for _, assertion in ipairs(assertions) do
      it(assertion.desc, assertion.options, assertion.test)
    end
  end)
end

-- Start the demonstration
print("=== Firmo Assertions Example ===\n")
print("This example demonstrates the complete range of assertions available in Firmo.")
print("Run this example with: lua test.lua examples/assertions_example.lua\n")

-- Core example data we'll use throughout our tests
local sample_string = "Testing with Firmo"
local sample_number = 42
local sample_table = { foo = "bar", nested = { value = 123 } }
local sample_array = { "one", "two", "three" }
local sample_function = function()
  return true
end
local sample_error_function = function()
  error("Intentional test error")
end

-- Main test suite for assertions
--- Main test suite for demonstrating various assertion types provided by Firmo.
describe("Firmo Assertions", function()
  -- Basic Existence Assertions
  test_assertion_group("Existence and Type Assertions", {
    {
      desc = "expect().to.exist() checks for non-nil values",
      test = function()
        expect(sample_string).to.exist()
        expect(sample_table).to.exist()
        expect(false).to.exist() -- even false exists (it's not nil)
        expect(nil).to_not.exist()
      end,
    },
    {
      desc = "expect().to.be.a() checks types",
      test = function()
        expect(sample_string).to.be.a("string")
        expect(sample_number).to.be.a("number")
        expect(sample_table).to.be.a("table")
        expect(sample_function).to.be.a("function")

        -- Negated version
        expect(sample_string).to_not.be.a("number")
        expect(sample_number).to_not.be.a("string")
      end,
    },
    --]]
  })

  -- Equality Assertions
  test_assertion_group("Equality Assertions", {
    {
      desc = "expect().to.equal() compares values",
      test = function()
        expect(sample_number).to.equal(42)
        expect(sample_string).to.equal("Testing with Firmo")
        expect(1 + 1).to.equal(2)

        -- Negated version
        expect(sample_number).to_not.equal(100)
        expect(sample_string).to_not.equal("different string")
      end,
    },
    {
      desc = "expect().to.equal() performs deep equality for tables",
      test = function()
        expect(sample_table).to.equal({ foo = "bar", nested = { value = 123 } })
        expect(sample_array).to.equal({ "one", "two", "three" })

        -- Negated version
        expect(sample_table).to_not.equal({ foo = "different", nested = { value = 123 } })
      end,
    },
    --]]
  })

  -- Truth and Boolean Assertions
  test_assertion_group("Truth and Boolean Assertions", {
    {
      desc = "expect().to.be_truthy() checks for Lua truth values",
      test = function()
        expect(true).to.be_truthy()
        expect(1).to.be_truthy()
        expect("string").to.be_truthy()
        expect(sample_table).to.be_truthy()

        expect(false).to_not.be_truthy()
        expect(nil).to_not.be_truthy()
      end,
    },
    {
      desc = "expect().to.be_falsy() is the opposite of be_truthy",
      test = function()
        expect(false).to.be_falsy()
        expect(nil).to.be_falsy()

        expect(true).to_not.be_falsy()
        expect(1).to_not.be_falsy()
        expect("string").to_not.be_falsy()
      end,
    },
    --]]
  })

  -- String Assertions
  test_assertion_group("String Assertions", {
    {
      desc = "expect().to.match() tests strings against patterns",
      test = function()
        expect(sample_string).to.match("Testing")
        expect(sample_string).to.match("with%s+Firmo")
        expect("abc123").to.match("%a+%d+")

        expect(sample_string).to_not.match("Unknown")
        expect(sample_string).to_not.match("^Firmo")
      end,
    },
    {
      desc = "expect().to.contain() checks for substrings",
      test = function()
        expect(sample_string).to.contain("Firmo")
        expect("Multiple words in text").to.contain("words")

        expect(sample_string).to_not.contain("Unknown")
      end,
    },
    {
      desc = "expect().to.start_with() checks string prefix",
      test = function()
        expect(sample_string).to.start_with("Testing")
        expect("abc123").to.start_with("abc")

        expect(sample_string).to_not.start_with("Firmo")
      end,
    },
    {
      desc = "expect().to.end_with() checks string suffix",
      test = function()
        expect(sample_string).to.end_with("Firmo")
        expect("abc123").to.end_with("123")

        expect(sample_string).to_not.end_with("Testing")
      end,
    },
    --]]
  })

  -- Numeric Assertions
  test_assertion_group("Numeric Assertions", {
    {
      desc = "expect().to.be_greater_than() compares numbers",
      test = function()
        expect(sample_number).to.be_greater_than(10)
        expect(100).to.be_greater_than(sample_number)

        expect(10).to_not.be_greater_than(sample_number)
      end,
    },
    {
      desc = "expect().to.be_less_than() compares numbers",
      test = function()
        expect(sample_number).to.be_less_than(100)
        expect(10).to.be_less_than(sample_number)

        expect(100).to_not.be_less_than(sample_number)
      end,
    },
    {
      desc = "expect().to.be_between() checks ranges",
      test = function()
        expect(sample_number).to.be_between(40, 50)
        expect(5).to.be_between(1, 10)

        expect(sample_number).to_not.be_between(0, 10)
      end,
    },
    {
      desc = "expect().to.be_near() checks approximate equality",
      test = function()
        expect(5.001).to.be_near(5, 0.01)
        expect(100).to.be_near(99, 1)

        expect(10).to_not.be_near(20, 5)
      end,
    },
    --]]
  })

  -- Table Assertions
  test_assertion_group("Table Assertions", {
    {
      desc = "expect().to.contain_key() checks for table keys",
      test = function()
        expect(sample_table).to.contain_key("foo")
        expect(sample_table).to.contain_key("nested")

        expect(sample_table).to_not.contain_key("unknown")
      end,
    },
    {
      desc = "expect().to.contain_value() checks for array values",
      test = function()
        expect(sample_array).to.contain_value("one")
        expect(sample_array).to.contain_value("three")

        expect(sample_array).to_not.contain_value("four")
      end,
    },
    {
      desc = "expect().to.have_length() checks table/array length",
      test = function()
        expect(sample_array).to.have_length(3)
        expect({}).to.have_length(0)

        expect(sample_array).to_not.have_length(5)
      end,
    },
    {
      desc = "expect().to.have_deep_key() checks nested tables",
      test = function()
        expect(sample_table).to.have_deep_key("nested.value")

        expect(sample_table).to_not.have_deep_key("nested.unknown")
      end,
    },
    --]]
  })

  -- Function and Error Assertions
  test_assertion_group("Function and Error Assertions", {
    {
      desc = "expect().to.fail() checks if functions throw errors",
      test = function()
        expect(sample_error_function).to.fail()
        expect(function()
          error("Test error")
        end).to.fail()

        expect(sample_function).to_not.fail()
      end,
    },
    {
      desc = "expect().to.fail_with_message() checks error messages",
      test = function()
        expect(function()
          error("Specific error")
        end).to.fail_with_message("Specific")

        expect(function()
          error("Wrong message")
        end).to_not.fail_with_message("Missing")
      end,
    },
    {
      desc = "Testing error handling with expect_error flag",
      options = { expect_error = true },
      test = function()
        local result, err = test_helper.with_error_capture(function()
          return nil, error_handler.validation_error({ param = "value" })
        end)()

        expect(result).to_not.exist()
        expect(err).to.exist()
        expect(err.message).to.match("Invalid parameter")
        expect(err.category).to.exist()
      end,
    },
  })

  -- Enhanced Table Assertions (from original example)
  --- Demonstrates assertions specifically designed for inspecting table keys, values,
  -- subsets, and exact structures.
  describe("Enhanced Table Assertions", function()
    it("demonstrates key and value assertions", function()
      local user = {
        id = 1,
        name = "John",
        email = "john@example.com",
        roles = { "admin", "user" },
      }

      -- Check for specific key
      expect(user).to.contain.key("id")
      expect(user).to.contain.key("name")

      -- Check for multiple keys
      expect(user).to.contain.keys({ "id", "name", "email" })

      -- Check for specific value
      expect(user).to.contain.value("John")

      -- Check for multiple values
      expect(user.roles).to.contain.values({ "admin", "user" })

      -- Subset testing
      local partial_user = { id = 1, name = "John" }
      expect(partial_user).to.contain.subset(user)

      expect(partial_user).to.contain.subset(user)

      -- Exact keys testing
      expect({ a = 1, b = 2 }).to.contain.exactly({ "a", "b" })
    end)
  end) -- Close describe("Enhanced Table Assertions", ...)
  -- Advanced Type Assertions
  -- comparable, and iterable, beyond basic Lua types.
  describe("Advanced Type Assertions", function()
    it("demonstrates advanced type checking", function()
      -- Basic callable check
      local function my_func()
        return true
      end
      expect(my_func).to.be_type("callable")

      -- Callable tables (with metatable)
      local callable_obj = setmetatable({}, {
        __call = function(self, ...)
          return "called"
        end,
      })
      expect(callable_obj).to.be_type("callable")

      -- Comparable values
      expect(1).to.be_type("comparable")
      expect("abc").to.be_type("comparable")

      -- Iterable values
      expect({ 1, 2, 3 }).to.be_type("iterable")
      expect({ a = 1, b = 2 }).to.be_type("iterable")
    end)
  end)

  -- Real world example - API response validation
  -- Real world example - API response validation
  --- Shows a practical application of various assertions to validate the structure
  -- and content of a complex, nested table representing a mock API response.
  describe("Real-world Example: API Response Validation", function()
    local api_response = {
      success = true,
      data = {
        users = {
          { id = 1, name = "Alice", active = true },
          { id = 2, name = "Bob", active = false },
          { id = 3, name = "Charlie", active = true },
        },
        pagination = {
          page = 1,
          per_page = 10,
          total = 3,
        },
      },
      meta = {
        generated_at = "2023-05-01T12:34:56Z",
        version = "1.0",
      },
    }

    it("validates complex API response structure", function()
      -- Basic response validation
      expect(api_response).to.contain.keys({ "success", "data", "meta" })
      expect(api_response.success).to.be_truthy()

      -- Data structure validation
      expect(api_response.data).to.contain.keys({ "users", "pagination" })

      -- Array length validation
      expect(#api_response.data.users).to.equal(3)

      -- Check specific values
      expect(api_response.data.pagination).to.contain.key("page")
      expect(api_response.data.pagination.page).to.equal(1)

      -- Check for a user with specific ID
      local found_user = false
      for _, user in ipairs(api_response.data.users) do
        if user.id == 2 then
          found_user = user
          break
        end
      end

      expect(found_user).to.exist()
      expect(found_user).to.contain.key("name")
      expect(found_user.name).to.equal("Bob")

      -- Type validations
      expect(api_response.meta.version).to.be.a("string")
      expect(api_response.meta.generated_at).to.start_with("2023")
    end)
  end)
end)

-- Also show output from test execution at the end
print("\nExample of expected test run output:\n")
print([[-----------------------------------------
Firmo Assertions
  Existence and Type Assertions
    ✓ expect().to.exist() checks for non-nil values
    ✓ expect().to.be.a() checks types
  Equality Assertions
    ✓ expect().to.equal() compares values
    ✓ expect().to.equal() performs deep equality for tables
  Truth and Boolean Assertions
    ✓ expect().to.be_truthy() checks for Lua truth values
    ✓ expect().to.be_falsy() is the opposite of be_truthy
  String Assertions
    ✓ expect().to.match() tests strings against patterns
    ✓ expect().to.contain() checks for substrings
    ✓ expect().to.start_with() checks string prefix
    ✓ expect().to.end_with() checks string suffix
  Numeric Assertions
    ✓ expect().to.be_greater_than() compares numbers
    ✓ expect().to.be_less_than() compares numbers
    ✓ expect().to.be_between() checks ranges
    ✓ expect().to.be_near() checks approximate equality
  Table Assertions
    ✓ expect().to.contain_key() checks for table keys
    ✓ expect().to.contain_value() checks for array values
    ✓ expect().to.have_length() checks table/array length
    ✓ expect().to.have_deep_key() checks nested tables
  Function and Error Assertions
    ✓ expect().to.fail() checks if functions throw errors
    ✓ expect().to.fail_with_message() checks error messages
    ✓ Testing error handling with expect_error flag
  Enhanced Table Assertions
    ✓ demonstrates key and value assertions
  Advanced Type Assertions
    ✓ demonstrates advanced type checking
  Real-world Example: API Response Validation
    ✓ validates complex API response structure
-----------------------------------------
25 tests, 0 failures]])
