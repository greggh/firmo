--- extended_assertions_example.lua
--
-- This example demonstrates various extended assertions provided by Firmo
-- beyond the basic equality and type checks. It covers assertions for:
-- - Collections (length, emptiness).
-- - Numeric properties (positive, negative, integer).
-- - String casing (uppercase, lowercase).
-- - Object structure (property existence, schema matching).
-- - Function behavior (change detection, increase/decrease).
-- - Deep equality comparison for nested tables.
--
-- Run embedded tests: lua test.lua examples/extended_assertions_example.lua
--

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

--- Main test suite demonstrating various extended assertions provided by Firmo.
--- @within examples.extended_assertions_example
describe("Extended Assertions Demo", function()
  --- Tests assertions related to collections (tables, strings) like length and emptiness.
  --- @within examples.extended_assertions_example
  describe("Collection Assertions", function()
    --- Tests `to.have_length`, `to.have_size`, and `to.be.empty`.
    it("demonstrates length, size, and emptiness assertions", function()
      -- String length checks
      local name = "Alice"
      expect(name).to.have_length(5)
      expect(name).to.have_size(5) -- alias for have_length

      -- Table length checks
      local numbers = { 10, 20, 30, 40, 50 }
      expect(numbers).to.have_length(5)

      -- Table emptiness checks
      local empty_table = {}
      expect(empty_table).to.be.empty()
      expect(numbers).to_not.be.empty()

      -- String emptiness checks
      local empty_string = ""
      expect(empty_string).to.be.empty()
    end)
  end)

  --- Tests assertions related to numeric properties like sign and integer status.
  --- @within examples.extended_assertions_example
  describe("Numeric Assertions", function()
    --- Tests `to.be.positive`, `to.be.negative`, and `to.be.integer`.
    it("demonstrates positive, negative, and integer assertions", function()
      -- Positive number check
      local positive = 42
      expect(positive).to.be.positive()

      -- Negative number check
      local negative = -10
      expect(negative).to.be.negative()

      -- Integer check
      local integer = 100
      expect(integer).to.be.integer()

      -- Non-integer check
      local float = 3.14
      expect(float).to_not.be.integer()
    end)
  end)

  --- Tests assertions related to string properties like casing.
  --- @within examples.extended_assertions_example
  describe("String Assertions", function()
    --- Tests `to.be.uppercase` and `to.be.lowercase`.
    it("demonstrates string case assertions (uppercase/lowercase)", function()
      -- Uppercase check
      local uppercase = "HELLO WORLD"
      expect(uppercase).to.be.uppercase()

      -- Lowercase check
      local lowercase = "hello world"
      expect(lowercase).to.be.lowercase()

      -- Mixed case (not uppercase or lowercase)
      local mixed = "Hello World"
      expect(mixed).to_not.be.uppercase()
      expect(mixed).to_not.be.lowercase()
    end)
  end)

  --- Tests assertions related to the structure and content of tables (often used like objects).
  --- @within examples.extended_assertions_example
  describe("Object Structure Assertions", function()
    --- Tests `to.have_property` for checking key existence and optionally value equality.
    it("demonstrates property existence and value checks", function()
      -- Property existence
      local user = {
        name = "John",
        age = 30,
        email = "john@example.com",
      }

      expect(user).to.have_property("name")
      expect(user).to.have_property("age")
      expect(user).to_not.have_property("address")

      -- Property value checks
      expect(user).to.have_property("name", "John")
      expect(user).to.have_property("age", 30)
      expect(user).to_not.have_property("name", "Jane")
    end)

    --- Tests `to.match_schema` for validating table structure against expected types and values.
    it("demonstrates schema validation using match_schema", function()
      -- Example object with nested structure
      local product = {
        id = "prod-123",
        name = "Laptop",
        price = 999.99,
        in_stock = true,
        tags = { "electronics", "computers" },
        specs = {
          cpu = "3.2 GHz",
          memory = "16 GB",
        },
      }

      -- Type checking schema
      expect(product).to.match_schema({
        id = "string",
        name = "string",
        price = "number",
        in_stock = "boolean",
        tags = "table",
      })

      -- Value checking schema (subset of properties) - values must match exactly
      expect(product).to.match_schema({
        name = "Laptop",
        in_stock = true,
      })

      -- Combined type and value schema
      expect(product).to.match_schema({
        id = "string",
        name = "Laptop", -- exact value check
        price = "number", -- type check
      })

      -- Should fail (missing required property)
      expect(product).to_not.match_schema({
        id = "string",
        description = "string", -- product doesn't have this property
      })
    end)
  end)

  --- Tests assertions that check the behavior or side effects of functions.
  --- @within examples.extended_assertions_example
  describe("Function Behavior Assertions", function()
    --- Tests `to.change` and `to_not.change` for detecting side effects.
    it("demonstrates detecting changes using change()", function()
      local counter = { value = 10 }

      -- Function that changes a value
      local increment = function()
        counter.value = counter.value + 1
      end

      -- Check if function changes a value
      expect(increment).to.change(function()
        return counter.value
      end)

      -- Reset counter
      counter.value = 5

      -- Function that doesn't change anything
      local noop = function() end

      -- Check that function doesn't change a value
      expect(noop).to_not.change(function()
        return counter.value
      end)
    end)

    --- Tests `to.increase` and `to.decrease` for checking changes in numeric values.
    it("demonstrates detecting increase/decrease in values", function()
      local counter = { value = 10 }

      -- Function that increases a value
      local increment = function()
        counter.value = counter.value + 5
      end

      -- Check if function increases a value
      expect(increment).to.increase(function()
        return counter.value
      end)

      -- Reset counter
      counter.value = 20

      -- Function that decreases a value
      local decrement = function()
        counter.value = counter.value - 7
      end

      -- Check if function decreases a value
      expect(decrement).to.decrease(function()
        return counter.value
      end)
    end)
  end)

  --- Tests the `to.deep_equal` assertion for comparing complex nested tables recursively.
  --- @within examples.extended_assertions_example
  describe("Deep Equality Assertions", function()
    --- Tests `to.deep_equal` with identical and modified nested tables.
    it("demonstrates deep equality comparison for complex objects", function()
      -- Two objects with the same nested structure
      local obj1 = {
        user = {
          profile = {
            name = "Alice",
            settings = {
              theme = "dark",
              notifications = true,
            },
          },
          permissions = { "read", "write" },
        },
      }

      local obj2 = {
        user = {
          profile = {
            name = "Alice",
            settings = {
              theme = "dark",
              notifications = true,
            },
          },
          permissions = { "read", "write" },
        },
      }

      -- Objects with same structure should be deeply equal
      expect(obj1).to.deep_equal(obj2)

      -- Modify a nested property
      obj2.user.profile.settings.theme = "light"

      -- Objects should no longer be deeply equal
      expect(obj1).to_not.deep_equal(obj2)
    end)
  end)
end)
