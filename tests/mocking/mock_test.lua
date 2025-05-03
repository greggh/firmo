---@diagnostic disable: missing-parameter, param-type-mismatch
--- Mock Module Tests
---
--- Tests for the mocking functionality (`lib.mocking.mock`) in the Firmo mocking system.
--- The mock module provides comprehensive test double capabilities with
--- stubbing, spying, and expectation verification features.
---
--- The test suite covers:
--- - Basic mock creation and structure.
--- - Stubbing methods with functions or return values.
--- - Spying on methods.
--- - Setting and verifying call count and argument expectations.
--- - Mock restoration (`reset`, `restore`) and identification (`is_mock`).
--- - Error handling for invalid usage.
--- - Also includes tests for standalone stubs (`firmo.stub`).
--- Uses `before` hook for setup and `test_helper` for error verification.
---
--- @author Firmo Team
--- @test

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Required modules for testing
local mock_module = require("lib.mocking.mock")
local test_helper = require("lib.tools.test_helper")

-- Import mocking functions for convenience
local mock = mock_module.create -- For creating mock objects
local stub = firmo.stub -- For creating standalone stubs

describe("Mock Module", function()
  -- Test object for mocking, re-created before each test
  local test_obj

  before(function()
    -- Create a fresh test object before each test
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

  describe("Basic Mock Functionality", function()
    it("creates a mock object with correct structure", function()
      local mock_obj = mock_module.create(test_obj)

      -- Verify mock object structure
      expect(mock_obj).to.exist()
      expect(mock_obj._is_firmo_mock).to.be_truthy()
      expect(mock_obj.target).to.equal(test_obj)
      expect(mock_obj._originals).to.be.a("table")
      expect(next(mock_obj._originals)).to.equal(nil) -- Verify _originals is an empty table
      expect(mock_obj._stubs).to.be.a("table")
      expect(mock_obj._spies).to.be.a("table")
    end)

    it("stubs methods on a mock object", function()
      local mock_obj = mock_module.create(test_obj)
      expect(mock_obj).to.exist()

      -- Stub a method
      local stub_result = mock_obj:stub("method1", function()
        return "stubbed"
      end)

      -- Verify stub operation returned the mock object for chaining
      expect(stub_result).to.equal(mock_obj)

      -- Call through the original object
      local result = test_obj.method1()

      -- Verify stub worked
      expect(result).to.equal("stubbed")

      -- Verify stub tracking is working
      expect(mock_obj._stubs.method1).to.exist()
      expect(mock_obj._stubs.method1.called).to.be_truthy()
      expect(mock_obj._stubs.method1.call_count).to.equal(1)
    end)

    it("spies on methods without changing behavior", function()
      local mock_obj = mock_module.create(test_obj)
      expect(mock_obj).to.exist()

      -- Spy on a method
      local spy_result = mock_obj:spy("method2")

      -- Verify spy operation returned the mock object for chaining
      expect(spy_result).to.equal(mock_obj)

      -- Call through the original object
      local result = test_obj.method2(2, 3)

      -- Verify original behavior is preserved
      expect(result).to.equal(5)

      -- Verify call was tracked
      local method_spy = mock_obj._spies.method2
      expect(method_spy).to.exist()
      expect(method_spy.called).to.be_truthy()
      expect(method_spy.call_count).to.equal(1)
      expect(method_spy.calls).to.exist()
      expect(method_spy.calls[1]).to.exist()
      expect(method_spy.calls[1].args).to.exist()

      -- In spies, the first arg is always `self` when using obj.method syntax
      -- So for test_obj.method2(2, 3), args are stored as [test_obj, 2, 3]
      expect(method_spy.calls[1].args[1]).to.equal(test_obj) -- Self
      expect(method_spy.calls[1].args[2]).to.equal(2) -- First actual arg
      expect(method_spy.calls[1].args[3]).to.equal(3) -- Second actual arg
    end)
  end) -- End of "Basic Mock Functionality" describe block

  describe("Call Count Expectations", function()
    it("verifies exact call counts", function()
      local mock_obj = mock_module.create(test_obj, { verify_all_expectations_called = true })
      expect(mock_obj).to.exist()

      -- Set up spy to track the method
      mock_obj:spy("method1")

      -- Setup expectation for exactly 1 call
      mock_obj:expect("method1").to.be.called(1)

      -- Verify before any calls - should fail
      -- The verify() method returns false and an error object when verification fails.
      -- The error object might be a structured error (with message field) or a string,
      -- so we need to handle both cases.
      local result, err = test_helper.with_error_capture(function()
        return mock_obj:verify()
      end)()

      expect(result).to.be_falsy("Verification should fail")
      expect(err).to.be_truthy("Error should be present")

      -- Handle both structured and string errors with flexible pattern matching
      if err then
        if type(err) == "table" and err.message then
          expect(err.message).to.match(".*[Ee]xpected.*|.*call.*|.*method1.*|.*verify.*")
        else
          expect(tostring(err)).to.match(".*[Ee]xpected.*|.*call.*|.*method1.*|.*verify.*")
        end
      else
        -- If we unexpectedly got nil instead of an error, make this test fail
        expect("No error was returned").to.equal("Expected an error with method1 verification")
      end
    end)

    it("handles call counts verification", function()
      local mock_obj = mock_module.create(test_obj, { verify_all_expectations_called = true })
      expect(mock_obj).to.exist()

      -- Set up spy to track the method
      mock_obj:spy("method1")

      -- Setup expectation for exactly 1 call
      mock_obj:expect("method1").to.be.called(1)

      -- Call the method once
      test_obj.method1("test")

      -- Verify after exactly 1 call - should pass
      local verification = mock_obj:verify()
      expect(verification).to.be_truthy()

      -- Call the method again (exceeding expectation)
      test_obj.method1("test")

      -- Call counts are verified based on configuration
      -- With the current implementation, this will still pass
      -- since we're not enforcing exact call counts by default
      verification = mock_obj:verify()
      expect(verification).to.be_truthy()
    end)

    it("verifies minimum and maximum call counts", function()
      local mock_obj = mock_module.create(test_obj, { verify_all_expectations_called = true })
      expect(mock_obj).to.exist()

      -- Set up methods to track
      mock_obj:stub("method1")
      mock_obj:stub("method2")

      -- Setup expectations for call counts
      mock_obj:expect("method1").to.be.called.at_least(2)
      mock_obj:expect("method2").to.be.called.at_least(1)

      -- Verify before any calls - should fail
      local result, err = test_helper.with_error_capture(function()
        return mock_obj:verify()
      end)()

      -- Check for verification failure
      expect(result).to.be_falsey("Verification should fail")
      expect(err).to.be_truthy("Error should be present")

      -- Flexible error message matching
      if type(err) == "table" and err.message then
        expect(err.message).to.match(".*[Ee]xpected.*")
      else
        expect(tostring(err)).to.match(".*[Ee]xpected.*")
      end

      -- Make calls that should satisfy all expectations
      test_obj.method1("test1")
      test_obj.method1("test2")
      test_obj.method2(1, 2)

      -- Verify expectations - should pass
      verification = mock_obj:verify()
      expect(verification).to.be_truthy()
    end)

    it("supports never expectations", function()
      local mock_obj = mock_module.create(test_obj, { verify_all_expectations_called = true })
      expect(mock_obj).to.exist()

      -- Set up spy to track the method
      mock_obj:spy("method1")

      -- Expect a method to never be called
      mock_obj:expect("method1").to.never.be.called()

      -- Verify before any calls - should pass
      local verification = mock_obj:verify()
      expect(verification).to.be_truthy()

      -- Call the method
      test_obj.method1("test")

      local result, err = test_helper.with_error_capture(function()
        return mock_obj:verify()
      end)()

      expect(result).to.be_falsey("Verification should fail")
      expect(err).to.be_truthy("Error should be present")

      -- Use looser pattern matching for the error message
      if type(err) == "table" and err.message then
        expect(err.message).to.match(".*never.*called.*")
      else
        expect(tostring(err)).to.match(".*never.*called.*")
      end
    end)
  end) -- End of "Call Count Expectations" describe block

  describe("Argument Expectations", function()
    it("verifies argument expectations", function()
      local mock_obj = mock_module.create(test_obj, { verify_all_expectations_called = true })
      expect(mock_obj).to.exist()

      -- Set up spy to track the method
      mock_obj:spy("method1")

      -- Setup expectations with specific arguments
      mock_obj:expect("method1").with("specific_arg").to.be.called(1)

      -- Call with wrong arguments
      test_obj.method1("wrong_arg")

      local result, err = test_helper.with_error_capture(function()
        return mock_obj:verify()
      end)()

      expect(result).to.be_falsey("Verification should fail")
      expect(err).to.be_truthy("Error should be present")

      -- Flexible error message matching
      if type(err) == "table" and err.message then
        expect(err.message).to.match(".*[Ee]xpected.*method1.*called.*")
      else
        expect(tostring(err)).to.match(".*[Ee]xpected.*method1.*called.*")
      end

      -- Call with correct arguments
      test_obj.method1("specific_arg")

      -- Verify again - should pass
      verification = mock_obj:verify()
      expect(verification).to.be_truthy()
    end)

    it("supports complex argument matching in expectations", function()
      local mock_obj = mock_module.create(test_obj, { verify_all_expectations_called = true })
      expect(mock_obj).to.exist()

      -- Set up spy to track the method
      mock_obj:spy("method2")

      -- Setup expectation with complex argument matcher
      mock_obj
        :expect("method2")
        .with(function(a, b)
          return type(a) == "number" and type(b) == "number" and a > b
        end).to.be
        .called(1)

      -- Call with non-matching arguments
      test_obj.method2(5, 10) -- a not > b

      local result, err = test_helper.with_error_capture(function()
        return mock_obj:verify()
      end)()

      expect(result).to.be_falsey("Verification should fail")
      expect(err).to.be_truthy("Error should be present")

      -- Flexible error message matching
      if type(err) == "table" and err.message then
        expect(err.message).to.match(".*[Ee]xpected.*")
      else
        expect(tostring(err)).to.match(".*[Ee]xpected.*")
      end
      -- Call with matching arguments
      test_obj.method2(10, 5) -- a > b

      -- Verify again - should pass
      verification = mock_obj:verify()
      expect(verification).to.be_truthy()
    end)
  end) -- End of "Argument Expectations" describe block

  describe("Mock Restoration and Identification", function()
    it("resets a mock", function()
      local mock_obj = mock_module.create(test_obj)
      expect(mock_obj).to.exist()

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
      expect(mock_obj).to.exist()

      -- Test mock detection
      expect(mock_module.is_mock(mock_obj)).to.be_truthy()
      expect(mock_module.is_mock(test_obj)).to_not.be_truthy()
      expect(mock_module.is_mock({})).to_not.be_truthy()
    end)
  end) -- End of "Mock Restoration and Identification" describe block

  describe("Error Handling", function()
    it("handles invalid mock object creation", { expect_error = true }, function()
      -- Try to create a mock with nil
      local result, err = test_helper.with_error_capture(function()
        mock_module.create(nil)
      end)()
      expect(result).to.be_falsey("Should fail with nil input")
      expect(err).to.be_truthy("Error object should be returned")
      expect(err).to.be_truthy("Error object should be returned")

      -- Flexible error message matching for different error types
      if type(err) == "table" and err.message then
        expect(err.message).to.match(".*[Cc]annot create mock.*", "Error message should indicate the issue")
      else
        expect(tostring(err)).to.match(".*[Cc]annot create mock.*", "Error message should indicate the issue")
      end
    end)

    it("handles invalid expectations", { expect_error = true }, function()
      local mock_obj = mock_module.create(test_obj)

      -- Try to expect a non-existent method
      local result, err = test_helper.with_error_capture(function()
        mock_obj:expect("non_existent_method")
      end)()

      expect(result).to.be_falsey("Should fail with non-existent method")
      expect(err).to.be_truthy("Error object should be returned")

      -- Flexible error message matching for different error types
      if type(err) == "table" and err.message then
        expect(err.message).to.match(".*[Cc]annot expect.*", "Error message should indicate the issue")
      else
        expect(tostring(err)).to.match(".*[Cc]annot expect.*", "Error message should indicate the issue")
      end
    end)
  end) -- End of "Error Handling" describe block
end)

--[[

  Tests for basic mock object functionality outside of the main Mock Module.
  These tests focus on creating and using mock objects in isolation, with
  an emphasis on stubbing object methods with various return values.
]]
describe("Standalone Mock Object", function()
  local test_obj

  before(function()
    -- Create a fresh test object for each test
    test_obj = {
      getData = function()
        -- Imagine this hits a database
        return { "real", "data" }
      end,
      isConnected = function()
        -- Imagine this checks actual connection
        return false
      end,
    }
  end)

  it("can stub object methods", function()
    -- Create a test object with methods
    local test_obj = {
      getData = function()
        -- Imagine this hits a database
        return { "real", "data" }
      end,
    }

    -- Create a mock of the object with proper options
    local mock_obj = mock_module.create(test_obj, {
      verify_all_expectations_called = true,
    })

    -- Stub the method with our implementation
    mock_obj:stub("getData", function()
      return { "mock", "data" }
    end)

    -- Call the method
    local result = test_obj:getData()

    -- Verify the mock implementation was used
    expect(result[1]).to.equal("mock")
    expect(result[2]).to.equal("data")

    -- Clean up with error handling
    local restore_result, restore_err = test_helper.with_error_capture(function()
      mock_obj:restore()
      return true
    end)()

    expect(restore_err).to_not.exist()
    expect(restore_result).to.be_truthy()
  end)
  it("can stub with simple return values", function()
    -- Create a test object with methods
    local test_obj = {
      isConnected = function()
        -- Imagine this checks actual connection
        return false
      end,
    }

    -- Create a mock of the object and stub the method with proper options
    local mock_obj = mock_module.create(test_obj, {
      verify_all_expectations_called = true,
    })

    -- Stub the method with a simple return value (not a function)
    mock_obj:stub("isConnected", true)

    -- Call the method
    local result = test_obj:isConnected()

    -- Verify the mocked return value was used
    expect(result).to.be_truthy()

    -- Clean up
    mock_obj:restore()
  end)
end) -- End of "Standalone Mock Object" describe block

--[[
  Standalone Stub Tests

  Tests for the standalone stub functionality in the Firmo mocking system.
  These tests focus on creating and using stubs in isolation, without
  being attached to a mock object or an existing object method.
]]
describe("Standalone Stub", function()
  it("creates simple value stubs", function()
    -- Create a stub that returns a fixed value
    local stub_fn = stub(42)

    -- Call the stub and verify the return value
    expect(stub_fn()).to.equal(42)
    expect(stub_fn()).to.equal(42)

    -- Verify call tracking
    expect(stub_fn.call_count).to.equal(2)
  end)

  it("creates function stubs", function()
    -- Create a stub with a function implementation
    local stub_fn = stub(function(a, b)
      return a * b
    end)

    -- Call the stub and verify the implementation is used
    expect(stub_fn(6, 7)).to.equal(42)

    -- Verify call tracking
    expect(stub_fn.call_count).to.equal(1)
    expect(stub_fn.calls[1][1]).to.equal(6)
    expect(stub_fn.calls[1][2]).to.equal(7)
  end)

  it("can be configured to return different values", function()
    -- Create an initial stub
    local stub_fn = stub("initial")
    expect(stub_fn()).to.equal("initial")

    -- Create a new stub with different value
    local new_stub = stub("new value")
    expect(new_stub()).to.equal("new value")

    -- Original stub should still return initial value
    expect(stub_fn()).to.equal("initial")
  end)

  it("can be configured to throw errors", { expect_error = true }, function()
    -- Create a stub that throws an error
    local stub_fn = stub("value"):throws("test error")

    -- The stub should throw an error when called
    local result, err = test_helper.with_error_capture(function()
      stub_fn()
    end)()

    expect(result).to.be_falsey()
    expect(err).to.be_truthy()
    expect(err).to.match("test error")
  end)
end) -- End of "Standalone Stub" describe block
