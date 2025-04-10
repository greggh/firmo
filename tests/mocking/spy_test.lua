-- Spy Module Tests
-- Tests for the spy functionality in the mocking system

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local spy_module = require("lib.mocking.spy")
local test_helper = require("lib.tools.test_helper")

describe("Spy Module", function()
  it("creates a standalone spy function", function()
    local spy = spy_module.new()

    expect(spy).to.be.a("function")
    expect(spy._is_firmo_spy).to.be_truthy()

    -- Call the spy
    local result = spy(1, 2, 3)

    -- Default spy returns nil
    expect(result).to_not.exist()

    -- Verify it tracked the call
    expect(spy.called).to.be_truthy()
    expect(spy.call_count).to.equal(1)
    expect(spy.calls[1].args).to.exist()
    expect(spy.calls[1].args[1]).to.equal(1)
    expect(spy.calls[1].args[2]).to.equal(2)
    expect(spy.calls[1].args[3]).to.equal(3)
  end)

  it("creates a spy with an explicit return value", function()
    local spy = spy_module.new(function()
      return "test result"
    end)

    expect(spy).to.be.a("function")

    -- Call the spy
    local result = spy()

    -- Should return the specified value
    expect(result).to.equal("test result")

    -- Verify it tracked the call
    expect(spy.called).to.be_truthy()
    expect(spy.call_count).to.equal(1)
  end)

  it("spies on an object method", function()
    local obj = {
      method = function(self, arg)
        return "original: " .. arg
      end,
    }

    -- Create a spy on the method
    local method_spy = spy_module.on(obj, "method")

    -- Call the method
    local result = obj:method("test")

    -- Should still return the original result
    expect(result).to.equal("original: test")

    -- Verify it tracked the call
    expect(method_spy.called).to.be_truthy()
    expect(method_spy.call_count).to.equal(1)
    expect(method_spy.calls[1].args[1]).to.equal(obj) -- self
    expect(method_spy.calls[1].args[2]).to.equal("test")

    -- Verify the original method was preserved
    expect(method_spy.original).to.be.a("function")
  end)

  it("spies on a table function", function()
    local module = {
      function_name = function(arg)
        return "module result: " .. arg
      end,
    }

    -- Create a spy on the function
    local fn_spy = spy_module.on(module, "function_name")

    -- Call the function
    local result = module.function_name("test")

    -- Should still return the original result
    expect(result).to.equal("module result: test")

    -- Verify it tracked the call
    expect(fn_spy.called).to.be_truthy()
    expect(fn_spy.call_count).to.equal(1)
    expect(fn_spy.calls[1].args[1]).to.equal("test")
  end)

  it("resets a spy", function()
    local spy = spy_module.new()

    -- Call the spy
    spy(1, 2, 3)

    -- Verify call was tracked
    expect(spy.called).to.be_truthy()
    expect(spy.call_count).to.equal(1)

    -- Reset the spy
    spy:reset()

    -- Verify it was reset
    expect(spy.called).to_not.be_truthy()
    expect(spy.call_count).to.equal(0)
    expect(#spy.calls).to.equal(0)
  end)

  it("provides call history", function()
    local spy = spy_module.new()

    -- Call the spy multiple times with different arguments
    spy("call1")
    spy("call2", "extra")
    spy(1, 2, 3)

    -- Verify call history
    expect(spy.call_count).to.equal(3)
    expect(#spy.calls).to.equal(3)

    -- Check first call
    expect(spy.calls[1].args[1]).to.equal("call1")

    -- Check second call
    expect(spy.calls[2].args[1]).to.equal("call2")
    expect(spy.calls[2].args[2]).to.equal("extra")

    -- Check third call
    expect(spy.calls[3].args[1]).to.equal(1)
    expect(spy.calls[3].args[2]).to.equal(2)
    expect(spy.calls[3].args[3]).to.equal(3)
  end)

  it("tracks call timestamps", function()
    local spy = spy_module.new()

    -- Call the spy
    spy()

    -- Verify timestamp was recorded
    expect(spy.calls[1].timestamp).to.exist()
    expect(type(spy.calls[1].timestamp)).to.equal("number")
  end)

  it("provides call args helpers", function()
    local spy = spy_module.new()

    -- Call the spy
    spy("arg1", "arg2", { key = "value" })

    -- Verify args helpers
    expect(spy:arg(1, 1)).to.equal("arg1")
    expect(spy:arg(1, 2)).to.equal("arg2")
    expect(spy:arg(1, 3).key).to.equal("value")

    -- Check last call helpers
    expect(spy:lastArg(1)).to.equal("arg1")
    expect(spy:lastArg(2)).to.equal("arg2")
    expect(spy:lastArg(3).key).to.equal("value")

    -- Check nil handling
    expect(spy:arg(1, 4)).to_not.exist()
    expect(spy:arg(2, 1)).to_not.exist() -- No second call
  end)

  it("handles error in spied function", { expect_error = true }, function()
    local fn = function()
      error("Test error")
    end

    local spy = spy_module.new(fn)

    -- Call the spy which should trigger the error
    local result, err = test_helper.with_error_capture(function()
      return spy()
    end)()

    -- Verify error was propagated
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err).to.match("Test error")

    -- Call should still be recorded despite the error
    expect(spy.called).to.be_truthy()
    expect(spy.call_count).to.equal(1)
  end)

  it("handles nil, boolean, and other return values", function()
    -- Test nil return
    local nil_fn = function()
      return nil
    end
    local nil_spy = spy_module.new(nil_fn)

    local nil_result = nil_spy()
    expect(nil_result).to_not.exist()

    -- Test boolean return
    local bool_fn = function()
      return true
    end
    local bool_spy = spy_module.new(bool_fn)

    local bool_result = bool_spy()
    expect(bool_result).to.be_truthy()

    -- Test multiple return values
    local multi_fn = function()
      return "first", "second", "third"
    end
    local multi_spy = spy_module.new(multi_fn)

    local first, second, third = multi_spy()
    expect(first).to.equal("first")
    expect(second).to.equal("second")
    expect(third).to.equal("third")
  end)

  it("detects if an object is a spy", function()
    local spy = spy_module.new()
    local not_spy = function() end

    expect(spy_module.is_spy(spy)).to.be_truthy()
    expect(spy_module.is_spy(not_spy)).to_not.be_truthy()
  end)

  -- Add more tests for error handling
  describe("Error handling", function()
    it("handles invalid spy creation scenarios", { expect_error = true }, function()
      -- Try to spy on a non-function
      local result, err = test_helper.expect_error(function()
        spy_module.new("not a function")
      end)
      
      expect(result).to_not.exist("Should fail with non-function")
      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Expected a function", "Error message should indicate the issue")
      
      -- Try to spy on a non-table object
      local result2, err2 = test_helper.expect_error(function()
        spy_module.on("not a table", "method")
      end)
      
      expect(result2).to_not.exist("Should fail with non-table")
      expect(err2).to.exist("Error object should be returned")
      expect(err2.message).to.match("Expected an object", "Error message should indicate the issue")
      
      -- Try to spy on a non-existing method
      local obj = { method = function() end }
      local result3, err3 = test_helper.expect_error(function()
        spy_module.on(obj, "non_existent_method")
      end)
      
      expect(result3).to_not.exist("Should fail with non-existent method")
      expect(err3).to.exist("Error object should be returned")
      expect(err3.message).to.match("Method does not exist", "Error message should indicate the issue")
      
      -- Try to spy on a non-function property
      local obj2 = { property = "string value" }
      local result4, err4 = test_helper.expect_error(function()
        spy_module.on(obj2, "property")
      end)
      
      expect(result4).to_not.exist("Should fail with non-function property")
      expect(err4).to.exist("Error object should be returned")
      expect(err4.message).to.match("Property is not a function", "Error message should indicate the issue")
    end)
    
    it("handles error during spy reset", { expect_error = true }, function()
      -- Create a spy
      local spy = spy_module.new()
      
      -- Intentionally corrupt the spy by removing a required field
      spy.calls = nil
      
      -- Attempt to reset the corrupted spy
      local result, err = test_helper.expect_error(function()
        spy:reset()
      end)
      
      expect(result).to_not.exist("Should fail with corrupted spy")
      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Invalid spy state", "Error message should indicate the issue")
    end)
    
    it("handles error cases for argument access", { expect_error = true }, function()
      local spy = spy_module.new()
      
      -- Call once
      spy("first_call")
      
      -- Try to access non-existent call
      local result, err = test_helper.expect_error(function()
        spy:arg(99, 1) -- Call 99 doesn't exist
      end)
      
      expect(result).to_not.exist("Should fail with non-existent call")
      expect(err).to.exist("Error object should be returned")
      expect(err.message).to.match("Call index out of bounds", "Error message should indicate the issue")
      
      -- Try to access non-existent argument
      local result2, err2 = test_helper.expect_error(function()
        spy:arg(1, 99) -- Argument 99 doesn't exist in call 1
      end)
      
      expect(result2).to_not.exist("Should fail with non-existent argument")
      expect(err2).to.exist("Error object should be returned")
      expect(err2.message).to.match("Argument index out of bounds", "Error message should indicate the issue")
      
      -- Try to access lastArg when no calls made
      spy:reset() -- Clear calls
      local result3, err3 = test_helper.expect_error(function()
        spy:lastArg(1)
      end)
      
      expect(result3).to_not.exist("Should fail with no calls")
      expect(err3).to.exist("Error object should be returned")
      expect(err3.message).to.match("No calls recorded", "Error message should indicate the issue")
    end)
    
    it("handles invalid spy restoration", { expect_error = true }, function()
      local obj = {
        method = function() return "original" end
      }
      
      -- Create a spy
      local spy = spy_module.on(obj, "method")
      
      -- Verify spy is working
      local result = obj.method()
      expect(result).to.equal("original")
      expect(spy.called).to.be_truthy()
      
      -- Intentionally corrupt the spy by removing the original function reference
      spy.original = nil
      
      -- Try to restore the corrupted spy
      local restore_result, restore_err = test_helper.expect_error(function()
        spy:restore()
      end)
      
      expect(restore_result).to_not.exist("Should fail with corrupted spy")
      expect(restore_err).to.exist("Error object should be returned")
      expect(restore_err.message).to.match("Cannot restore", "Error message should indicate the issue")
    end)
    
    it("validates arguments to CallPattern functions", { expect_error = true }, function()
      local spy = spy_module.new()
      
      -- Call the spy
      spy("arg1", "arg2")
      
      -- Try to use a non-existent call pattern function
      local result, err = test_helper.expect_error(function()
        spy:non_existent_function()
      end)
      
      expect(result).to_not.exist("Should fail with non-existent function")
      expect(err).to.exist("Error object should be returned")
      
      -- Try to use calledWith with no arguments
      local result2, err2 = test_helper.expect_error(function()
        spy:calledWith()
      end)
      
      expect(result2).to_not.exist("Should fail with missing arguments")
      expect(err2).to.exist("Error object should be returned")
      expect(err2.message).to.match("Missing expected arguments", "Error message should indicate the issue")
    end)
  end)
  
  -- Add more tests for other spy functionality
end)
