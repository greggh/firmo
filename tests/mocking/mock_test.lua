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
    local mock_obj = mock_module.new(test_obj)

    expect(mock_obj).to.exist()
    expect(mock_obj._is_firmo_mock).to.be_truthy()
    expect(mock_obj._original).to.equal(test_obj)
  end)

  it("stubs methods on a mock object", function()
    local mock_obj = mock_module.new(test_obj)

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
    local mock_obj = mock_module.new(test_obj)

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
    expect(method_spy.calls[1].args[2]).to.equal(2) -- First arg after self
    expect(method_spy.calls[1].args[3]).to.equal(3) -- Second arg after self
  end)

  it("verifies expectations with default settings", function()
    local mock_obj = mock_module.new(test_obj)

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
    local mock_obj = mock_module.new(test_obj)

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
    local mock_obj = mock_module.new(test_obj)

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
    local mock_obj = mock_module.new(test_obj)

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
    local mock_obj = mock_module.new(test_obj)

    -- Stub a property
    mock_obj:stub_property("property", "new value")

    -- Check the property value
    expect(test_obj.property).to.equal("new value")
  end)

  it("resets a mock", function()
    local mock_obj = mock_module.new(test_obj)

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
    local mock_obj = mock_module.new(test_obj)

    expect(mock_module.is_mock(mock_obj)).to.be_truthy()
    expect(mock_module.is_mock(test_obj)).to_not.be_truthy()
    expect(mock_module.is_mock({})).to_not.be_truthy()
  end)

  it("supports complex argument matching in expectations", function()
    local mock_obj = mock_module.new(test_obj)

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
    local mock_obj = mock_module.new(test_obj)

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
    local mock1 = mock_module.new(obj1)
    local mock2 = mock_module.new(obj2)

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

  -- Add more tests for other mock functionality
end)
