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

local firmo = require("firmo")

-- Import the test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

--- Main test suite demonstrating various extended assertions.
describe("Extended Assertions Demo", function()
  --- Tests assertions related to collections (tables, strings).
  describe("Collection Assertions", function()
    it("demonstrates length and size assertions", function()
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

  --- Tests assertions related to numeric properties.
  describe("Numeric Assertions", function()
    it("demonstrates numeric property assertions", function()
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

  --- Tests assertions related to string properties like case.
  describe("String Assertions", function()
    it("demonstrates string case assertions", function()
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

  --- Tests assertions related to the structure and content of tables (objects).
  describe("Object Structure Assertions", function()
    it("demonstrates property existence checks", function()
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

    it("demonstrates schema validation", function()
      -- Object with nested structure
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
  describe("Function Behavior Assertions", function()
    it("demonstrates change assertions", function()
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

    it("demonstrates increase and decrease assertions", function()
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

  --- Tests the `deep_equal` assertion for comparing complex nested tables.
  describe("Deep Equality Assertions", function()
    it("demonstrates deep equality with complex objects", function()
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
