---@diagnostic disable: missing-parameter, param-type-mismatch
--- Extended Assertion Tests
---
--- Tests for additional Firmo `expect` assertions beyond the core set, including:
--- - Collection: `have_length`, `have_size`, `be.empty`
--- - Numeric: `be.positive`, `be.negative`, `be.integer`
--- - String: `be.uppercase`, `be.lowercase`
--- - Table/Object: `have_property`, `match_schema`
--- - Function Behavior: `to.change`, `to.increase`, `to.decrease`
--- - Aliases: `deep_equal`
---
--- @author Firmo Team
--- @test

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

describe("Extended Assertions", function()
  describe("Collection Assertions", function()
    it("checks for length with have_length", function()
      -- String length
      expect("hello").to.have_length(5)
      expect("").to.have_length(0)
      expect("hello").to_not.have_length(3)

      -- Table length
      expect({ 1, 2, 3 }).to.have_length(3)
      expect({}).to.have_length(0)
      expect({ 1, 2 }).to_not.have_length(3)
    end)

    it("checks for size with have_size", function()
      -- String size (alias for length)
      expect("world").to.have_size(5)
      expect("").to.have_size(0)

      -- Table size (alias for length)
      expect({ 1, 2, 3, 4 }).to.have_size(4)
      expect({}).to.have_size(0)
    end)

    it("checks for emptiness with be.empty", function()
      -- Empty string
      expect("").to.be.empty()
      expect("hello").to_not.be.empty()

      -- Empty table
      expect({}).to.be.empty()
      expect({ 1, 2, 3 }).to_not.be.empty()
      expect({ a = 1 }).to_not.be.empty()
    end)
  end)

  describe("Numeric Assertions", function()
    it("checks for positive numbers", function()
      expect(5).to.be.positive()
      expect(0.1).to.be.positive()
      expect(0).to_not.be.positive()
      expect(-5).to_not.be.positive()
    end)

    it("checks for negative numbers", function()
      expect(-5).to.be.negative()
      expect(-0.1).to.be.negative()
      expect(0).to_not.be.negative()
      expect(5).to_not.be.negative()
    end)

    it("checks for integers", function()
      expect(5).to.be.integer()
      expect(-10).to.be.integer()
      expect(0).to.be.integer()
      expect(5.5).to_not.be.integer()
      expect(-0.1).to_not.be.integer()
    end)
  end)

  describe("String Assertions", function()
    it("checks for uppercase strings", function()
      expect("HELLO").to.be.uppercase()
      expect("Hello").to_not.be.uppercase()
      expect("").to.be.uppercase() -- empty string is considered uppercase
    end)

    it("checks for lowercase strings", function()
      expect("hello").to.be.lowercase()
      expect("Hello").to_not.be.lowercase()
      expect("").to.be.lowercase() -- empty string is considered lowercase
    end)
  end)

  describe("Table/Object Structure Assertions", function()
    it("checks for property existence with have_property", function()
      local obj = { name = "John", age = 30 }

      expect(obj).to.have_property("name")
      expect(obj).to.have_property("age")
      expect(obj).to_not.have_property("address")
    end)

    it("checks for property value with have_property", function()
      local obj = { name = "John", age = 30 }

      expect(obj).to.have_property("name", "John")
      expect(obj).to.have_property("age", 30)
      expect(obj).to_not.have_property("name", "Jane")
    end)

    it("validates object schema with match_schema", function()
      local user = {
        name = "John",
        age = 30,
        isActive = true,
        address = {
          city = "New York",
        },
      }

      -- Simple type schema
      expect(user).to.match_schema({
        name = "string",
        age = "number",
        isActive = "boolean",
      })

      -- Value schema
      expect(user).to.match_schema({
        name = "John",
        isActive = true,
      })

      -- Combined schema
      expect(user).to.match_schema({
        name = "string",
        age = 30,
      })

      -- Schema with missing property
      expect(user).to_not.match_schema({
        name = "string",
        email = "string", -- missing in user
      })
    end)
  end)

  describe("Function Behavior Assertions", function()
    it("checks if a function changes a value", function()
      local obj = { count = 0 }

      local increment = function()
        obj.count = obj.count + 1
      end

      expect(increment).to.change(function()
        return obj.count
      end)

      -- Reset for next test
      obj.count = 5
      local noop = function() end

      expect(noop).to_not.change(function()
        return obj.count
      end)
    end)

    it("checks if a function increases a value", function()
      local obj = { count = 10 }

      local increment = function()
        obj.count = obj.count + 1
      end

      expect(increment).to.increase(function()
        return obj.count
      end)

      -- Reset for next test
      obj.count = 5
      local decrement = function()
        obj.count = obj.count - 1
      end

      expect(decrement).to_not.increase(function()
        return obj.count
      end)
    end)

    it("checks if a function decreases a value", function()
      local obj = { count = 10 }

      local decrement = function()
        obj.count = obj.count - 1
      end

      expect(decrement).to.decrease(function()
        return obj.count
      end)

      -- Reset for next test
      obj.count = 5
      local increment = function()
        obj.count = obj.count + 1
      end

      expect(increment).to_not.decrease(function()
        return obj.count
      end)
    end)
  end)

  describe("Alias Assertions", function()
    it("provides deep_equal as an alias for equal", function()
      local obj1 = { a = 1, b = { c = 2 } }
      local obj2 = { a = 1, b = { c = 2 } }
      local obj3 = { a = 1, b = { c = 3 } }

      expect(obj1).to.deep_equal(obj2)
      expect(obj1).to_not.deep_equal(obj3)
    end)
  end)
end)
