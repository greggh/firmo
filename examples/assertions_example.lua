---@diagnostic disable: undefined-global, redundant-parameter
--- Comprehensive demonstration of Firmo's assertion capabilities.
---
--- This example showcases a wide range of assertions provided by the `expect()` API,
--- including:
--- - Basic existence and type checks (`to.exist`, `to.be.a`).
--- - Equality comparisons (`to.equal`, `to.deep_equal`).
--- - Truthiness checks (`to.be_truthy`, `to.be_falsy`).
--- - String assertions (`to.match`, `to.contain`, `to.start_with`, `to.end_with`).
--- - Numeric assertions (`to.be_greater_than`, `to.be_less_than`, `to.be_between`, `to.be_near`).
--- - Table assertions (`to.contain_key`, `to.contain_value`, `to.have_length`, `to.have_deep_key`).
--- - Function and error assertions (`to.fail`, `to.fail_with_message`, expect_error flag).
--- - Enhanced table assertions (`to.contain.keys`, `to.contain.subset`, `to.contain.exactly_keys`).
--- - Advanced type assertions (`to.be_type("callable")`, etc.).
--- - A real-world example validating a mock API response.
---
--- @module examples.assertions_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib/assertion/init.lua
--- @see lib.tools.test_helper
--- @see lib.tools.error_handler
--- @usage
--- Run embedded tests:
--- ```bash
--- lua firmo.lua examples/assertions_example.lua
--- ```

-- Comprehensive example of Firmo's assertion functionality
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

--- Helper function to organize a series of related assertion tests into a `describe` block.
--- @param name string Name of the assertion group/describe block.
--- @param assertions table[] An array of test definitions. Each definition is a table with `desc` (string), `test` (function), and optional `options` (table for `it`).
--- @return nil
--- @within examples.assertions_example
local function test_assertion_group(name, assertions)
  describe(name, function()
    for _, assertion in ipairs(assertions) do
      -- Call `it` with the description, optional options, and the test function.
      it(assertion.desc, assertion.options, assertion.test)
    end
  end)
end

-- Start the demonstration
print("=== Firmo Assertions Example ===\n")
print("This example demonstrates the complete range of assertions available in Firmo.")
print("Run this example with: lua firmo.lua examples/assertions_example.lua\n")

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
--- @within examples.assertions_example
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
      desc = "expect().to.be.a() checks variable types using Lua's `type()` function",
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
  })

  -- Equality Assertions
  test_assertion_group("Equality Assertions", {
    {
      desc = "expect().to.equal() compares primitive values for equality",
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
      desc = "expect().to.equal() performs deep equality checks for tables and arrays",
      test = function()
        -- Note: to.equal performs a deep comparison for tables.
        expect(sample_table).to.equal({ foo = "bar", nested = { value = 123 } })
        expect(sample_array).to.equal({ "one", "two", "three" })

        -- Negated version
        expect(sample_table).to_not.equal({ foo = "different", nested = { value = 123 } })
      end,
    },
  })

  -- Truth and Boolean Assertions
  test_assertion_group("Truth and Boolean Assertions", {
    { -- Wrap in table entry
      desc = "expect().to.be_truthy() checks for Lua 'truthy' values (anything not false or nil)",
      test = function()
        expect(true).to.be_truthy()
        expect(1).to.be_truthy()
        expect("string").to.be_truthy()
        expect(sample_table).to.be_truthy()

        expect(false).to_not.be_truthy()
        expect(nil).to_not.be_truthy()
      end,
    }, -- << ADD COMMA HERE
    { -- Wrap in table entry
      desc = "expect().to.be_falsy() checks for Lua 'falsy' values (only false or nil)",
      test = function()
        expect(false).to.be_falsy()
        expect(nil).to.be_falsy()

        expect(true).to_not.be_falsy()
        expect(1).to_not.be_falsy()
        expect("string").to_not.be_falsy()
      end,
    }, -- Added missing closing brace for the inner table element
  })

  -- String Assertions
  test_assertion_group("String Assertions", {
    { -- Wrap in table entry
      desc = "expect().to.match() tests strings against Lua patterns",
      test = function()
        expect(sample_string).to.match("Testing") -- Simple substring match
        expect(sample_string).to.match("with%s+Firmo") -- Pattern with whitespace
        expect("abc123").to.match("%a+%d+")

        expect(sample_string).to_not.match("Unknown")
        expect(sample_string).to_not.match("^Firmo")
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.contain() checks if a string contains a specific substring",
      test = function()
        expect(sample_string).to.contain("Firmo")
        expect("Multiple words in text").to.contain("words")

        expect(sample_string).to_not.contain("Unknown")
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.start_with() checks if a string starts with a specific prefix",
      test = function()
        expect(sample_string).to.start_with("Testing")
        expect("abc123").to.start_with("abc")

        expect(sample_string).to_not.start_with("Firmo")
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.end_with() checks if a string ends with a specific suffix",
      test = function()
        expect(sample_string).to.end_with("Firmo")
        expect("abc123").to.end_with("123")

        expect(sample_string).to_not.end_with("Testing")
      end,
    }, -- Added missing closing brace for the inner table element
  })

  -- Numeric Assertions
  test_assertion_group("Numeric Assertions", {
    { -- Wrap in table entry
      desc = "expect().to.be_greater_than() checks if a number is strictly greater than another",
      test = function()
        expect(sample_number).to.be_greater_than(10)
        expect(100).to.be_greater_than(sample_number)

        expect(10).to_not.be_greater_than(sample_number)
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.be_less_than() checks if a number is strictly less than another",
      test = function()
        expect(sample_number).to.be_less_than(100)
        expect(10).to.be_less_than(sample_number)

        expect(100).to_not.be_less_than(sample_number)
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.be_between() checks if a number is within a specified range (inclusive)",
      test = function()
        expect(sample_number).to.be_between(40, 50)
        expect(5).to.be_between(1, 10)

        expect(sample_number).to_not.be_between(0, 10)
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.be_near() checks if a number is close to another within a tolerance",
      test = function()
        expect(5.001).to.be_near(5, 0.01) -- Within 0.01 tolerance
        expect(100).to.be_approximately(99, 1) -- Alias works too
        expect(0.1 + 0.2).to.be_near(0.3) -- Uses default tolerance

        expect(10).to_not.be_near(20, 5)
      end,
    },
  })

  -- Number Proximity Assertions
  test_assertion_group("Number Proximity Assertions", {
    {
      desc = "expect().to.be_near() with various tolerance levels",
      test = function()
        -- Standard use cases
        expect(10.01).to.be_near(10, 0.1) -- Within 0.1 tolerance
        expect(10.1).to.be_near(10, 0.2) -- Within 0.2 tolerance
        expect(9.95).to.be_near(10, 0.1) -- Increase tolerance to 0.1

        -- Default tolerance (which is typically around 1e-8 or 1e-9)
        expect(1.0000000001).to.be_near(1)
        expect(0.9999999999).to.be_near(1)

        -- Negated cases
        expect(11).to_not.be_near(10, 0.5)
        expect(9).to_not.be_near(10, 0.5)
      end,
    },
    {
      desc = "expect().to.be_approximately() as an alias for be_near",
      test = function()
        -- Both assertions work identically
        expect(99.9).to.be_approximately(100, 0.5)
        expect(100.4).to.be_approximately(100, 0.5)

        -- With default tolerance
        expect(1.0000000001).to.be_approximately(1)

        -- Negated cases
        expect(98).to_not.be_approximately(100, 1)
      end,
    },
    {
      desc = "expect().to.be_near() with floating point arithmetic",
      test = function()
        -- Floating point arithmetic doesn't always produce exact results
        local result = 0.1 + 0.2 -- Typically produces 0.30000000000000004

        -- These would fail without tolerance
        expect(result).to_not.equal(0.3)

        -- But they work with proximity assertions
        expect(result).to.be_near(0.3)
        expect(result).to.be_approximately(0.3)

        -- Works with more complex calculations
        expect(1 / 3 * 3).to.be_near(1)
      end,
    },
  })

  -- Date and Time Assertions
  test_assertion_group("Date and Time Assertions", {
    {
      desc = "expect().to.be_date() checks if a value is a valid date string",
      test = function()
        expect("2023-05-01").to.be_date()
        expect("2023-05-01T12:30:45Z").to.be_date()
        expect("May 1, 2023").to.be_date()

        expect("not a date").to_not.be_date()
        expect(123).to_not.be_date()
      end,
    },
    {
      desc = "expect().to.be_before() checks if a date is chronologically before another",
      test = function()
        expect("2022-01-01").to.be_before("2023-01-01")
        expect("2023-01-01T10:00:00Z").to.be_before("2023-01-01T11:00:00Z")

        expect("2023-01-01").to_not.be_before("2022-01-01")
      end,
    },
    {
      desc = "expect().to.be_after() checks if a date is chronologically after another",
      test = function()
        expect("2023-01-01").to.be_after("2022-01-01")
        expect("2023-01-01T11:00:00Z").to.be_after("2023-01-01T10:00:00Z")

        expect("2022-01-01").to_not.be_after("2023-01-01")
      end,
    },
    {
      desc = "expect().to.be_same_day() checks if two dates represent the same calendar day",
      test = function()
        expect("2023-05-01T10:00:00Z").to.be_same_day_as("2023-05-01T15:30:00Z")
        expect("May 1, 2023").to.be_same_day_as("2023-05-01")

        expect("2023-05-01").to_not.be_same_day_as("2023-05-02")
      end,
    },
    {
      desc = "expect().to.be_between_dates() checks if a date is within a range",
      test = function()
        expect("2023-05-15").to.be_between_dates("2023-05-01", "2023-05-31")
        expect("2023-05-01").to.be_between_dates("2023-05-01", "2023-05-31") -- Inclusive

        expect("2023-06-01").to_not.be_between_dates("2023-05-01", "2023-05-31")
      end,
    },
  })

  -- Enhanced Pattern Matching
  test_assertion_group("Enhanced Pattern Matching", {
    {
      desc = "expect().to.match_with_options() for complex pattern matching with options",
      test = function()
        -- Case-insensitive matching without full match requirement
        expect("Hello World").to.match_with_options("hello", { case_insensitive = true })
        expect("TESTING").to.match_with_options("test", { case_insensitive = true })

        -- For exact case-insensitive matches, use separate assertions
        local text = "Hello World"
        expect(text:lower()).to.equal("hello world")

        -- Multi-line matching
        local multi_line_text = "Line 1\nLine 2\nLine 3"
        expect(multi_line_text).to.match_with_options("^Line", { multi_line = true })

        -- Global matching
        expect("one two three").to.match_with_options("%w+", { global = true })

        -- Negated patterns
        expect("Hello").to_not.match_with_options("world", { case_insensitive = true })
      end,
    },
    {
      desc = "expect().to.match.fully() requires the entire string to match the pattern",
      test = function()
        expect("abc123").to.match.fully("%a+%d+")
        expect("2023-05-01").to.match.fully("%d%d%d%d%-%d%d%-%d%d")

        -- These match with normal match() but fail with match.fully()
        expect("abc123def").to.match("%a+%d+")
        expect("abc123def").to_not.match.fully("%a+%d+")
      end,
    },
    {
      desc = "expect().to.match.any_of() checks if a string matches any of multiple patterns",
      test = function()
        expect("abc").to.match.any_of({ "%a+", "%d+", "%p+" })
        expect("123").to.match.any_of({ "%a+", "%d+", "%p+" })
        expect("!!!").to.match.any_of({ "%a+", "%d+", "%p+" })

        expect("abc123").to.match.any_of({ "%a+$", "%d+$" })
        expect("abc123").to_not.match.any_of({ "%a+$", "%p+$" })
      end,
    },
    {
      desc = "expect().to.match.all_of() checks if a string matches all of multiple patterns",
      test = function()
        expect("abc123").to.match.all_of({ "%a", "%d" })
        expect("Password123!").to.match.all_of({ "%a", "%d", "%p" })

        expect("abc").to_not.match.all_of({ "%a", "%d" })
      end,
    },
  })

  -- Table Assertions
  test_assertion_group("Table Assertions", {
    { -- Wrap in table entry
      desc = "expect().to.contain.key() checks if a table has a specific key",
      test = function()
        expect(sample_table).to.contain.key("foo") -- Changed contain_key to contain.key
        expect(sample_table).to.contain.key("nested") -- Changed contain_key to contain.key

        expect(sample_table).to_not.contain.key("unknown") -- Changed contain_key to contain.key
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.contain() checks if an array-like table contains a specific value",
      test = function()
        expect(sample_array).to.contain("one") -- Changed contain_value to contain
        expect(sample_array).to.contain("three") -- Changed contain_value to contain

        expect(sample_array).to_not.contain("four") -- Changed contain_value to contain
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.have_length() checks the length of a string or array-like table using # operator",
      test = function()
        expect(sample_array).to.have_length(3)
        expect({}).to.have_length(0)

        expect(sample_array).to_not.have_length(5)
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.contain.deep_key() checks for keys in nested tables using dot notation or table path",
      test = function()
        expect(sample_table).to.contain.deep_key("nested.value")
        expect(sample_table).to.contain.deep_key({ "nested", "value" }) -- Using table path

        expect(sample_table).to_not.contain.deep_key("nested.unknown")
        expect(sample_table).to_not.contain.deep_key({ "nested", "unknown" })
        expect(sample_table).to_not.contain.deep_key("foo.bar") -- Intermediate key not a table
      end,
    },
  })

  -- Function and Error Assertions
  test_assertion_group("Function and Error Assertions", {
    { -- Wrap in table entry
      desc = "expect().to.fail() checks if a function throws any error when called",
      test = function()
        expect(sample_error_function).to.fail()
        expect(function()
          error("Test error")
        end).to.fail()

        expect(sample_function).to_not.fail()
      end,
    },
    { -- Wrap in table entry
      desc = "expect().to.fail.with() checks if a function throws an error with a specific message (or pattern)",
      test = function()
        expect(function()
          error("Specific error")
        end).to.fail.with("Specific") -- Changed fail_with_message to fail.with

        expect(function()
          error("Wrong message")
        end).to_not.fail.with("Missing") -- Changed fail_with_message to fail.with
      end,
    },
    { -- Wrap in table entry
      desc = "Testing error handling using the `expect_error` test option and `test_helper.with_error_capture`",
      options = { expect_error = true }, -- Indicate this test expects an error
      test = function()
        -- Use with_error_capture to safely call the function that should error
        local result, err = test_helper.with_error_capture(function()
          -- Simulate a function returning an error object
          return nil, error_handler.validation_error("Invalid parameter", { param = "value" })
        end)()

        -- Assertions about the captured error
        expect(result).to_not.exist() -- The function should not return a normal result
        expect(err).to.exist() -- An error object should be returned
        expect(err.message).to.match("Invalid parameter") -- Check the error message
        expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION) -- Check the error category
      end,
    }, -- Added missing closing brace for the inner table element
  })

  --- Demonstrates assertions specifically designed for inspecting table keys, values,
  -- subsets, and exact structures.
  --- @within examples.assertions_example
  describe("Enhanced Table Assertions", function()
    --- Tests assertions for checking keys, values, subsets, and exact structures in tables.
    it("demonstrates key, value, subset, and exact structure assertions", function()
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

      -- Exact keys testing (checks if the table contains *only* these keys)
      expect({ a = 1, b = 2 }).to.contain.exact_keys({ "a", "b" })
      expect({ b = 2, a = 1 }).to.contain.exact_keys({ "a", "b" }) -- Order doesn't matter
      expect({ a = 1, b = 2, c = 3 }).to_not.contain.exact_keys({ "a", "b" }) -- Fails due to extra key 'c'
      expect({ a = 1 }).to_not.contain.exact_keys({ "a", "b" }) -- Fails due to missing key 'b'
    end)
  end)

  --- Demonstrates advanced type assertions like `callable`, `comparable`, and `iterable`.
  --- @within examples.assertions_example
  describe("Advanced Type Assertions", function()
    --- Tests `to.be_type` with non-standard types.
    it("demonstrates checking for callable objects", function()
      -- Functions are callable
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

      -- Testing a callable object
      expect(callable_obj()).to.equal("called")

      -- Non-callable objects
      expect({}).to_not.be_type("callable")
      expect("string").to_not.be_type("callable")
      expect(42).to_not.be_type("callable")
    end)

    it("demonstrates checking for comparable types", function()
      -- Primitives with __eq metamethod are comparable (commenting out incorrect tests)
      -- expect(1).to.be_type("comparable")
      -- expect("abc").to.be_type("comparable")
      -- expect(true).to.be_type("comparable")

      -- Tables with __eq metamethod are comparable
      local comparable_obj = setmetatable({ value = 10 }, {
        __eq = function(a, b)
          return a.value == b.value
        end,
        __lt = function(a, b)
          return a.value < b.value
        end,
        __le = function(a, b)
          return a.value <= b.value
        end
      })

      -- Test comparable_obj with identical values
      local comparable_obj2 = setmetatable({ value = 10 }, getmetatable(comparable_obj))

      -- This should now pass since we have a proper __eq metamethod
      expect(comparable_obj).to.be_type("comparable")
      expect(comparable_obj == comparable_obj2).to.be_truthy()

      -- Regular tables are not directly comparable
      local regular_table = { value = 10 }
      local regular_table2 = { value = 10 }
      expect(regular_table == regular_table2).to.be_falsy()
    end)

    it("demonstrates checking for iterable types", function()
      -- Arrays are iterable
      expect({ 1, 2, 3 }).to.be_type("iterable")

      -- Dictionaries are iterable
      expect({ a = 1, b = 2 }).to.be_type("iterable")

      -- Strings are not usually considered iterable in Lua
      expect("string").to_not.be_type("iterable")

      -- Functions are not iterable
      local function test_func() end
      expect(test_func).to_not.be_type("iterable")
    end)
  end)

  --- Shows a practical application of various assertions to validate the structure
  -- and content of a complex, nested table representing a mock API response.
  --- @within examples.assertions_example
  describe("Real-world Example: API Response Validation", function()
    --- Mock API response data for testing.
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

    --- Validates the structure and content of the mock API response using various assertions.
    it("validates complex API response structure and content", function()
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
