-- Mock Module Tests
-- Tests for the mock functionality in the mocking system

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local mock_module = require("lib.mocking.mock")
local test_helper = require("lib.tools.test_helper")

describe("Mock Module", function()
  -- Create a test object for mocking
  local test_obj

  before(function()
    test_obj = {
      method1 = function(self, arg)
        return "method1: " .. arg
      end,
      method2 = function(self, a, b)
        return a + b
      end,
      property = "original value",
    }
  end)

  it("creates a mock object", function()
    local mock_obj = mock_module.create(test_obj)

    expect(mock_obj).to.exist()
    expect(mock_obj._is_firmo_mock).to.be_truthy()
    expect(mock_obj.target).to.equal(test_obj)
    expect(mock_obj._originals).to.be.a("table")
    expect(next(mock_obj._originals)).to.equal(nil) -- Verify _originals is an empty table
  end)

  it("stubs methods on a mock object", function()
    local mock_obj = mock_module.create(test_obj)

    -- Stub a method
    mock_obj:stub("method1", function()
      return "stubbed"
    end)

    -- Call through the original object
    local result = test_obj.method1()

    -- Verify stub worked
    expect(result).to.equal("stubbed")
  end)

  it("spies on methods without changing behavior", function()
    local mock_obj = mock_module.create(test_obj)

    -- Spy on a method
    mock_obj:spy("method2")

    -- Call through the original object
    local result = test_obj.method2(2, 3)

    -- Verify original behavior
    expect(result).to.equal(5)

    -- Verify call was tracked
    local method_spy = mock_obj._spies.method2
    expect(method_spy.called).to.be_truthy()
    expect(method_spy.call_count).to.equal(1)
    
    -- In spies, the first arg is always `self` when using obj.method syntax
    -- So for test_obj.method2(2, 3), args are stored as [test_obj, 2, 3]
    expect(method_spy.calls[1].args[1]).to.equal(test_obj) -- Self
    expect(method_spy.calls[1].args[2]).to.equal(2) -- First actual arg
    expect(method_spy.calls[1].args[3]).to.equal(3) -- Second actual arg
  end)

  it("verifies expectations with default settings", function()
    local mock_obj = mock_module.create(test_obj)

    -- Setup expectations - by default any method can be called any number of times
    local verification = mock_obj:verify()

    -- Should pass with no calls
    expect(verification).to.be_truthy()

    -- Call a method
    test_obj.method1("test")

    -- Should still pass
    verification = mock_obj:verify()
    expect(verification).to.be_truthy()
  end)

  it("verifies explicit expectations", function()
    local mock_obj = mock_module.create(test_obj)

    -- Setup explicit expectations
    mock_obj:expect("method1").to.be.called(1)

    -- Verify before meeting expectations
    local verification = mock_obj:verify()
    expect(verification).to_not.be_truthy()

    -- Call the method
    test_obj.method1("test")

    -- Verify after meeting expectations
    verification = mock_obj:verify()
    expect(verification).to.be_truthy()

    -- Call again (exceeding expectation)
    test_obj.method1("test")

    -- Verify after exceeding expectations
    verification = mock_obj:verify()
    expect(verification).to_not.be_truthy()
  end)

  it("verifies call count expectations", function()
    local mock_obj = mock_module.create(test_obj)

    -- Setup expectations for multiple call counts
    mock_obj:expect("method1").to.be.called.at_least(2)
    mock_obj:expect("method2").to.be.called.at_most(1)

    -- Call the methods
    test_obj.method1("test")
    test_obj.method1("test")
    test_obj.method2(1, 2)

    -- Verify expectations
    local verification = mock_obj:verify()
    expect(verification).to.be_truthy()

    -- Exceed the at_most expectation
    test_obj.method2(3, 4)

    -- Verify again
    verification = mock_obj:verify()
    expect(verification).to_not.be_truthy()
  end)

  it("verifies argument expectations", function()
    local mock_obj = mock_module.create(test_obj)

    -- Setup expectations with specific arguments
    mock_obj:expect("method1").with("specific_arg").to.be.called(1)

    -- Call with wrong arguments
    test_obj.method1("wrong_arg")

    -- Verify - should fail because arguments don't match
    local verification = mock_obj:verify()
    expect(verification).to_not.be_truthy()

    -- Call with correct arguments
    test_obj.method1("specific_arg")

    -- Verify again
    verification = mock_obj:verify()
    expect(verification).to.be_truthy()
  end)

  it("allows stubbing method properties", function()
    local mock_obj = mock_module.create(test_obj)

    -- Stub a property
    mock_obj:stub_property("property", "new value")

    -- Check the property value
    expect(test_obj.property).to.equal("new value")
  end)

  it("resets a mock", function()
    local mock_obj = mock_module.create(test_obj)

    -- Stub a method and property
    mock_obj:stub("method1", function()
      return "stubbed"
    end)
    mock_obj:stub_property("property", "new value")

    -- Verify stub is working
    expect(test_obj.method1()).to.equal("stubbed")
    expect(test_obj.property).to.equal("new value")

    -- Reset the mock
    mock_obj:reset()

    -- Verify originals are restored
    expect(test_obj.method1("test")).to.equal("method1: test")
    expect(test_obj.property).to.equal("original value")
  end)

  it("detects if an object is a mock", function()
    local mock_obj = mock_module.create(test_obj)

    expect(mock_module.is_mock(mock_obj)).to.be_truthy()
    expect(mock_module.is_mock(test_obj)).to_not.be_truthy()
    expect(mock_module.is_mock({})).to_not.be_truthy()
  end)

  it("supports complex argument matching in expectations", function()
    local mock_obj = mock_module.create(test_obj)

    -- Setup expectation with complex argument matcher
    mock_obj
      :expect("method2")
      .with(function(a, b)
        return type(a) == "number" and type(b) == "number" and a > b
      end).to.be
      .called(1)

    -- Call with non-matching arguments
    test_obj.method2(5, 10) -- a not > b

    -- Verify - should fail because arguments don't match expectation
    local verification = mock_obj:verify()
    expect(verification).to_not.be_truthy()

    -- Call with matching arguments
    test_obj.method2(10, 5) -- a > b

    -- Verify again
    verification = mock_obj:verify()
    expect(verification).to.be_truthy()
  end)

  it("supports never expectations", function()
    local mock_obj = mock_module.create(test_obj)

    -- Expect a method to never be called
    mock_obj:expect("method1").to.never.be.called()

    -- Verify before any calls
    local verification = mock_obj:verify()
    expect(verification).to.be_truthy()

    -- Call the method
    test_obj.method1("test")

    -- Verify after calling - should fail
    verification = mock_obj:verify()
    expect(verification).to_not.be_truthy()
  end)

  it("handles multiple mocks with global reset", function()
    local obj1 = {
      method = function()
        return "obj1"
      end,
    }
    local obj2 = {
      method = function()
        return "obj2"
      end,
    }

    -- Create two separate mocks
    local mock1 = mock_module.create(obj1)
    local mock2 = mock_module.create(obj2)

    -- Stub both mocks
    mock1:stub("method", function()
      return "stubbed1"
    end)
    mock2:stub("method", function()
      return "stubbed2"
    end)

    -- Verify stubs are working
    expect(obj1.method()).to.equal("stubbed1")
    expect(obj2.method()).to.equal("stubbed2")

    -- Reset all mocks
    mock_module.reset_all()

    -- Verify all originals are restored
    expect(obj1.method()).to.equal("obj1")
    expect(obj2.method()).to.equal("obj2")
  end)

  it("handles invalid stub operations", { expect_error = true }, function()
    local mock_obj = mock_module.create(test_obj)

    -- This test verifies that trying to stub a non-existent method produces
    -- an appropriate error. Using expect_error = true to ensure proper error handling.
    local result, err = test_helper.expect_error(function()
      mock_obj:stub("non_existent_method", function() end)
    end)

    expect(result).to_not.exist("Operation should fail with an error")
    expect(err).to.exist("Error object should be returned")
    expect(err.message).to.match("Cannot stub non%-existent method", "Error message should indicate the issue")
  end)

  it("handles invalid property operations", { expect_error = true }, function()
    local mock_obj = mock_module.create(test_obj)

    -- This test verifies that trying to stub a non-existent property produces
    -- an appropriate error. Using expect_error = true to ensure proper error handling.
    local result, err = test_helper.expect_error(function()
      mock_obj:stub_property("non_existent_property", "value")
    end)

    expect(result).to_not.exist("Operation should fail with an error")
    expect(err).to.exist("Error object should be returned")
    expect(err.message).to.match("Cannot stub non%-existent property", "Error message should indicate the issue")
  end)

  it("handles invalid argument matchers", { expect_error = true }, function()
    local mock_obj = mock_module.create(test_obj)

    -- This test verifies that using an invalid argument matcher produces
    -- an appropriate error. Using expect_error = true to ensure proper error handling.
    local result, err = test_helper.expect_error(function()
      mock_obj:expect("method1").with(123) -- Should be function or value
    end)

    expect(result).to_not.exist("Operation should fail with an error")
    expect(err).to.exist("Error object should be returned")
    expect(err.message).to.match("Invalid argument matcher", "Error message should indicate the issue")
  end)

  -- Add more tests for error handling
  describe("Error handling", function()
    it("handles invalid mock object creation", { expect_error = true }, function()
      -- Try to create a mock with nil
      local result, err = test_helper.expect_error(function()
        mock_module.create(nil)
      end)

      expect(result).to_not.exist("Should fail with nil input")
      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Cannot create mock from nil", "Error message should indicate the issue")

      -- Try to create a mock with a non-table value
      local result2, err2 = test_helper.expect_error(function()
        mock_module.create("string value")
      end)

      expect(result2).to_not.exist("Should fail with string input")
      expect(err2).to.exist("Error object should be returned")
      expect(err2.message).to.match("Cannot create mock from non%-table", "Error message should indicate the issue")
    end)

    it("handles invalid expectation chaining", { expect_error = true }, function()
      local mock_obj = mock_module.create(test_obj)

      -- Try to chain expect after with (missing .to.)
      local result, err = test_helper.expect_error(function()
        mock_obj:expect("method1").with("arg").called(1)
      end)

      expect(result).to_not.exist("Should fail with invalid chain")
      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Invalid expectation chain", "Error message should indicate the issue")

      -- Try to chain invalid expectation properties
      local result2, err2 = test_helper.expect_error(function()
        mock_obj:expect("method1").invalid_property()
      end)

      expect(result2).to_not.exist("Should fail with invalid property")
      expect(err2).to.exist("Error object should be returned")
    end)

    it("handles errors during expectation verification", { expect_error = true }, function()
      local mock_obj = mock_module.create(test_obj)

      -- Set up conflicting expectations
      mock_obj:expect("method1").to.be.called(1)
      mock_obj:expect("method1").to.never.be.called()

      -- Verify should fail due to conflicting expectations
      local result, err = test_helper.expect_error(function()
        mock_obj:verify()
      end)

      expect(result).to_not.exist("Should fail with conflicting expectations")
      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Conflicting expectations", "Error message should indicate the issue")
    end)

    it("handles invalid mock reset scenarios", { expect_error = true }, function()
      -- Create a mock
      local mock_obj = mock_module.create(test_obj)

      -- Intentionally corrupt the mock by removing a required field
      mock_obj._original = nil

      -- Attempt to reset the corrupted mock
      local result, err = test_helper.expect_error(function()
        mock_obj:reset()
      end)

      expect(result).to_not.exist("Should fail with corrupted mock")
      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Invalid mock state", "Error message should indicate the issue")
    end)

    it("validates method existence during expectations", { expect_error = true }, function()
      local mock_obj = mock_module.create(test_obj)

      -- Try to set expectation on non-existent method
      local result, err = test_helper.expect_error(function()
        mock_obj:expect("non_existent_method")
      end)

      expect(result).to_not.exist("Should fail with non-existent method")
      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Cannot expect non%-existent method", "Error message should indicate the issue")
    end)
  end)

  -- Add more tests for other mock functionality
end)
