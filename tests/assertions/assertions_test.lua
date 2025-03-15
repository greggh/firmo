-- Tests for the core assertions in firmo
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Core Assertions", function()
  describe("Basic Assertions", function()
    it("checks for equality", function()
      expect(5).to.equal(5)
      expect("test").to.equal("test")
      expect(true).to.equal(true)
      expect(nil).to.equal(nil)
      expect({ 1, 2, 3 }).to.equal({ 1, 2, 3 })
    end)

    it("checks for truthiness", function()
      expect(true).to.be_truthy()
      expect(1).to.be_truthy()
      expect("string").to.be_truthy()
      expect({}).to.be_truthy()
      expect(function() end).to.be_truthy()
    end)

    it("checks for falsiness", function()
      expect(false).to.be_falsey()
      expect(nil).to.be_falsey()
      expect(false).to_not.be_truthy()
      expect(nil).to_not.be_truthy()
    end)

    it("checks for existence", function()
      expect(true).to.exist()
      expect(false).to.exist()
      expect(0).to.exist()
      expect("").to.exist()
      expect({}).to.exist()
      expect(nil).to_not.exist()
    end)

    it("checks for values with be", function()
      expect(5).to.equal(5)
      expect("test").to.equal("test")
      expect(true).to.equal(true)
    end)
  end)

  describe("String Pattern Assertions", function()
    it("checks for pattern matching", function()
      expect("hello world").to.match("he..o")
      expect("testing 123").to.match("%d+")
      expect("hello").to_not.match("%d")
    end)
  end)

  describe("Function Assertions", function()
    it("checks if a function fails", function()
      local function fails()
        error("error message")
      end
      local function succeeds()
        return true
      end

      expect(fails).to.fail()
      expect(succeeds).to_not.fail()
    end)
  end)

  describe("Type Assertions", function()
    it("checks types with a and an", function()
      expect(5).to.be.a("number")
      expect("test").to.be.a("string")
      expect(true).to.be.a("boolean")
      expect({}).to.be.a("table")
      expect(function() end).to.be.a("function")

      expect({}).to_not.be.a("string")
      expect("test").to_not.be.a("number")
    end)
  end)

  describe("Negated Assertions", function()
    it("negates assertions with to_not", function()
      expect(5).to_not.equal(10)
      expect("test").to_not.equal("other")
      expect(true).to_not.equal(false)
      expect(nil).to_not.equal(false)

      expect(5).to_not.equal(10)
      expect(false).to_not.be_truthy()
      expect(true).to_not.be_falsey()
    end)
  end)
end)

-- Tests are run by scripts/runner.lua or run_all_tests.lua, not by direct execution
