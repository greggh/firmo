--- Demonstrates the usage of the Firmo Type Checking module (`lib.core.type_checking`).
---
--- This module provides functions for advanced type validation beyond Lua's basic `type()`,
--- including checking exact primitive types, class instances via metatables,
--- interface implementation (duck typing), container membership, and error throwing behavior.
---
--- Note: These functions typically throw errors on validation failure. The `test_helper`
--- module is used here to demonstrate and verify this error-throwing behavior.
---
--- @module examples.type_checking_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025

-- Import core Firmo test functions
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import the module being demonstrated
local tc = require("lib.core.type_checking")

-- Import test_helper to assert error conditions
local test_helper = require("lib.tools.test_helper")

describe("Type Checking Examples", function()
  it("is_exact_type: validates primitive types", function()
    -- Success cases
    expect(tc.is_exact_type("hello", "string")).to.be_truthy()
    expect(tc.is_exact_type(123, "number")).to.be_truthy()
    expect(tc.is_exact_type({}, "table")).to.be_truthy()
    expect(tc.is_exact_type(true, "boolean")).to.be_truthy()
    expect(tc.is_exact_type(function() end, "function")).to.be_truthy()
    expect(tc.is_exact_type(nil, "nil")).to.be_truthy()

    -- Failure case (throws error)
    test_helper.expect_error(function()
      tc.is_exact_type(123, "string")
    end, "Expected value to be exactly of type 'string', but got 'number'")
  end)

  -- Setup mock classes for instance_of tests
  local Animal = {}
  Animal.__index = Animal
  Animal.__name = "Animal"
  function Animal:new(name)
    local instance = setmetatable({}, self)
    instance.name = name
    return instance
  end

  local Dog = setmetatable({}, Animal)
  Dog.__index = Dog
  Dog.__name = "Dog"
  function Dog:bark()
    return "Woof!"
  end

  local Cat = setmetatable({}, Animal)
  Cat.__index = Cat
  Cat.__name = "Cat"
  function Cat:meow()
    return "Meow!"
  end

  it("is_instance_of: validates class instances (metatables)", function()
    local my_dog = Dog:new("Rex")
    local my_cat = Cat:new("Whiskers")
    local plain_table = {}

    -- Success cases
    expect(tc.is_instance_of(my_dog, Dog)).to.be_truthy() -- Direct instance
    expect(tc.is_instance_of(my_dog, Animal)).to.be_truthy() -- Inherited instance
    expect(tc.is_instance_of(my_cat, Cat)).to.be_truthy()
    expect(tc.is_instance_of(my_cat, Animal)).to.be_truthy()

    -- Failure cases (throws error)
    test_helper.expect_error(function()
      tc.is_instance_of(my_dog, Cat) -- Wrong class
    end, "Expected object to be an instance of Cat, but it is an instance of Dog")

    test_helper.expect_error(function()
      tc.is_instance_of(plain_table, Animal) -- No metatable
    end, "Expected object to be an instance of Animal, but it has no metatable")

    test_helper.expect_error(function()
      tc.is_instance_of("not a table", Animal) -- Not a table
    end, "Expected object to be a table %(got string%)")
  end)

  -- Setup interface and objects for implements tests
  local Writable = {
    write = function() end,
    flush = function() end,
    path = "",
  }

  local File = {
    path = "/tmp/file.log",
    write = function(self, data)
      -- Simulate writing
    end,
    flush = function(self)
      -- Simulate flushing
    end,
  }

  local NetworkStream = {
    write = function(self, data)
      -- Simulate network write
    end,
    -- Missing 'flush' and 'path'
  }

  it("implements: validates interface implementation (duck typing)", function()
    -- Success case
    expect(tc.implements(File, Writable)).to.be_truthy()

    -- Failure cases (throws error)
    test_helper.expect_error(function()
      tc.implements(NetworkStream, Writable)
    end, "Object does not implement interface: missing: flush, path") -- Order might vary

    test_helper.expect_error(function()
      tc.implements("not an object", Writable)
    end, "Expected object to be a table %(got string%)")
  end)

  it("contains: validates item presence in tables and strings", function()
    local my_list = { "apple", "banana", "orange" }
    local my_string = "the quick brown fox"

    -- Success cases
    expect(tc.contains(my_list, "banana")).to.be_truthy()
    expect(tc.contains(my_string, "quick")).to.be_truthy()
    expect(tc.contains(my_string, "fox")).to.be_truthy()

    -- Failure cases (throws error)
    test_helper.expect_error(function()
      tc.contains(my_list, "grape")
    end, "Expected table to contain grape")

    test_helper.expect_error(function()
      tc.contains(my_string, "lazy")
    end, "Expected string 'the quick brown fox' to contain 'lazy'")

    test_helper.expect_error(function()
      tc.contains(123, "a") -- Invalid container type
    end, "Cannot check containment in a number")
  end)

  it("has_error: validates that a function throws", function()
    local function might_throw(should_throw)
      if should_throw then
        error("Intended error!")
      end
      return "No error"
    end

    -- Success case: function throws as expected
    local captured_err = tc.has_error(function()
      might_throw(true)
    end)
    expect(captured_err).to.match("Intended error!")

    -- Failure case: function does NOT throw (throws error)
    test_helper.expect_error(function()
      tc.has_error(function()
        might_throw(false)
      end)
    end, "Expected function to throw an error, but it did not")

    -- Failure case: invalid input type (throws error)
    test_helper.expect_error(function()
      tc.has_error("not a function")
    end, "Expected a function to test for errors")
  end)
end)
