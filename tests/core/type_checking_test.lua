---@diagnostic disable: missing-parameter, param-type-mismatch
--- Enhanced Type Checking Tests
---
--- Verifies functionality related to enhanced type checking, including:
--- - Exact primitive type checking (`expect(...).to.be.a` and `is_exact_type`)
--- - Instance checking using `is_instance_of`
--- - Interface implementation checking using `implements`
--- - Containment assertion using `contains`
--- Tests cover correct identification, error cases, and error message verification.
--- Uses local classes `TestClass`, `TestSubclass`, and `TestInterface` for testing.
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

local test_helper = require("lib.tools.test_helper")
local type_checking = require("lib.core.type_checking")

--- Test class for instance checking.
---@class TestClass
---@field new fun(): TestClass Constructor.
local TestClass = {}
TestClass.__index = TestClass
TestClass.__name = "TestClass" -- Allow for nice error messages

function TestClass.new()
  local self = {}
  setmetatable(self, TestClass)
  return self
end

--- Test subclass inheriting from TestClass for instance checking.
---@class TestSubclass : TestClass
---@field new fun(): TestSubclass Constructor.
local TestSubclass = {}
TestSubclass.__index = TestSubclass
TestSubclass.__name = "TestSubclass"
setmetatable(TestSubclass, { __index = TestClass }) -- Inherit from TestClass

function TestSubclass.new()
  local self = {}
  setmetatable(self, TestSubclass)
  return self
end

--- Test interface table for implementation checking.
---@type table
local TestInterface = {
  required_method = function() end,
  required_property = "value",
}

describe("Enhanced Type Checking", function()
  describe("Exact Type Checking", function()
    it("correctly identifies exact primitive types", function()
      -- Direct validation using type_checking module
      expect(type_checking.is_exact_type("string value", "string")).to.be_truthy()
      expect(type_checking.is_exact_type(123, "number")).to.be_truthy()
      expect(type_checking.is_exact_type(true, "boolean")).to.be_truthy()
      expect(type_checking.is_exact_type(nil, "nil")).to.be_truthy()
      expect(type_checking.is_exact_type({}, "table")).to.be_truthy()
      expect(type_checking.is_exact_type(function() end, "function")).to.be_truthy()

      -- Using built-in expect style
      expect("string value").to.be.a("string")
      expect(true).to.be.a("boolean")
      expect(nil).to_not.exist()
      expect({}).to.be.a("table")
      expect(function() end).to.be.a("function")
    end)

    it("fails when types don't match exactly", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        type_checking.is_exact_type(123, "string")
      end)
      expect(err).to.exist()
      expect(err.message).to.match("Expected.*type.*string.*got.*number")

      err = test_helper.expect_error(function()
        type_checking.is_exact_type("123", "number")
      end)
      expect(err).to.exist()
      expect(err.message).to.match("Expected.*type.*number.*got.*string")
    end)

    it("handles error messages correctly", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        type_checking.is_exact_type(123, "string", "Custom error message")
      end)
      expect(err).to.exist()
      expect(err.message).to.match("Custom error message")

      local result2, err2 = test_helper.with_error_capture(function()
        expect(123).to.be.a("string")
      end)()

      expect(result2).to_not.exist()
      expect(err2).to.exist()
      expect(err2.message).to.match("expected.*to be a string")
    end)
  end)

  describe("Instance Checking", function()
    it("correctly identifies direct instances", function()
      local instance = TestClass.new()
      expect(type_checking.is_instance_of(instance, TestClass)).to.be_truthy()
    end)

    it("correctly identifies instances of parent classes", function()
      local instance = TestSubclass.new()
      expect(type_checking.is_instance_of(instance, TestClass)).to.be_truthy()
      expect(type_checking.is_instance_of(instance, TestSubclass)).to.be_truthy()
    end)

    it("fails when object is not an instance of class", { expect_error = true }, function()
      local instance = TestClass.new()
      local err = test_helper.expect_error(function()
        type_checking.is_instance_of(instance, TestSubclass)
      end)
      expect(err).to.exist()
      expect(err.message).to.match("Expected.*instance of.*TestSubclass")

      err = test_helper.expect_error(function()
        type_checking.is_instance_of({}, TestClass)
      end)
      expect(err).to.exist()
      expect(err.message).to.match("Expected.*instance of.*TestClass")
    end)

    it("fails when non-table values are provided", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        type_checking.is_instance_of("string", TestClass)
      end)
      expect(err).to.exist()
      expect(err.message).to.match("Expected object to be a table")

      err = test_helper.expect_error(function()
        type_checking.is_instance_of(TestClass.new(), "not a class")
      end)
      expect(err).to.exist()
      expect(err.message).to.match("Expected class to be a.*table")
    end)
  end)

  describe("Interface Implementation Checking", function()
    it("passes when all interface requirements are met", function()
      local obj = {
        required_method = function()
          return true
        end,
        required_property = "some value",
        extra_property = 123, -- Extra properties are allowed
      }

      expect(type_checking.implements(obj, TestInterface)).to.be_truthy()
    end)

    it("fails when required properties are missing", { expect_error = true }, function()
      local obj = {
        required_method = function()
          return true
        end,
        -- Missing required_property
      }

      -- Direct negative assertion instead of expecting error
      expect(type_checking.implements(obj, TestInterface)).to.be_falsy()
    end)

    it("fails when method types don't match", { expect_error = true }, function()
      local obj = {
        required_method = "not a function", -- Wrong type
        required_property = "value",
      }

      -- Direct negative assertion instead of expecting error
      expect(type_checking.implements(obj, TestInterface)).to.be_falsy()
    end)

    it("reports missing keys and wrong types in error messages", { expect_error = true }, function()
      local obj = {
        required_method = "string instead of function",
        -- Missing required_property
      }

      --- Helper to check implementation and throw detailed error.
      ---@param obj table Object to check.
      ---@param interface table Interface table.
      ---@return boolean Returns true if implements.
      ---@throws string If object does not implement interface.
      ---@private
      local function implements_with_error(obj, interface)
        if type(obj) ~= "table" or type(interface) ~= "table" then
          error("Both object and interface must be tables")
        end

        local missing = {}
        local wrong_types = {}

        for key, value in pairs(interface) do
          if obj[key] == nil then
            table.insert(missing, key)
          elseif type(obj[key]) ~= type(value) then
            table.insert(wrong_types, key)
          end
        end

        if #missing > 0 or #wrong_types > 0 then
          local err_msg = "Object does not implement interface"
          if #missing > 0 then
            err_msg = err_msg .. ": missing: " .. table.concat(missing, ", ")
          end
          if #wrong_types > 0 then
            err_msg = err_msg .. ": wrong types: " .. table.concat(wrong_types, ", ")
          end
          error(err_msg)
        end

        return true
      end

      local result, err = test_helper.with_error_capture(function()
        implements_with_error(obj, TestInterface)
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("missing: required_property")
      expect(err.message).to.match("wrong types: required_method")
    end)
  end)

  describe("The enhanced contains assertion", function()
    it("works with tables", { expect_error = true }, function()
      local t = { 1, 2, 3, "test" }
      ---@return boolean @private

      expect(type_checking.contains(t, 2)).to.be_truthy()
      expect(type_checking.contains(t, "test")).to.be_truthy()

      -- Direct negative assertion instead of expecting error
      expect(type_checking.contains(t, 5)).to.be_falsy()
    end)

    it("works with strings", { expect_error = true }, function()
      local s = "This is a test string"

      expect(type_checking.contains(s, "test")).to.be_truthy()
      expect(type_checking.contains(s, "This")).to.be_truthy()
      expect(type_checking.contains(s, " is ")).to.be_truthy()

      -- Direct negative assertion instead of expecting error
      expect(type_checking.contains(s, "banana")).to.be_falsy()
    end)

    it("converts non-string values to strings for string containment", function()
      expect(type_checking.contains("Testing 123", 123)).to.be_truthy()
      expect(type_checking.contains("true value", true)).to.be_truthy()
    end)

    it("fails with appropriate error messages", { expect_error = true }, function()
      local result1, err1 = test_helper.with_error_capture(function()
        type_checking.contains("test string", "banana")
      end)()

      expect(result1).to_not.exist()
      expect(err1).to.exist()
      expect(err1.message).to.match("Expected string 'test string' to contain 'banana'")

      local result2, err2 = test_helper.with_error_capture(function()
        type_checking.contains({ 1, 2, 3 }, 5)
      end)()

      expect(result2).to_not.exist()
      expect(err2).to.exist()
      expect(err2.message).to.match("Expected table to contain 5")
    end)
  end)

  describe("Integration with expect-style assertions", function()
    it("works alongside other assertions", function()
      local instance = TestClass.new()

      -- Chain assertions
      expect(true).to.be_truthy()
      expect(instance).to.be.a("table")
      expect(getmetatable(instance)).to.equal(TestClass)
      expect(instance).to.exist()
    end)
  end)
end)
