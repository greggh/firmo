--[[
  Spy Module Tests
  
  Tests for the spy functionality in the Firmo mocking system.
  The spy module provides function and method spying capabilities 
  that track calls without changing behavior.
  
  The test suite covers:
  - Basic spy creation and configuration
  - Call counting and argument tracking
  - Call order verification
  - Error handling and restoration
  
  @module tests.mocking.spy_test
  @copyright 2023-2025 Firmo Team
]]

-- Adjust path to find modules
package.path = "../?.lua;../lib/?.lua;../lib/?/init.lua;" .. package.path

-- Import firmo
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import the spy module and error handling modules
local spy_module = require("lib.mocking.spy")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Initialize module logger to prevent nil errors
local logger = logging.get_logger("spy_test")
logging.configure_from_config("spy_test")


-- Spy alias for convenience in tests
local spy = spy_module.create or spy_module.new
describe("Spy Module", function()
  -- Setup and teardown for all tests
  before(function()
    -- Reset any module state
    if spy_module._next_sequence then
      spy_module._next_sequence = 0
    end
  end)

  after(function()
    -- Clean up any remaining spies
    if spy_module.reset_all then
      spy_module.reset_all()
    end
  end)

  describe("Basic Functionality", function()
    it("creates a basic spy function", function()
      local spy_fn = spy()
      
      expect(spy_fn).to.exist()
      expect(spy_fn).to.be.a("function")
      expect(spy_fn._is_firmo_spy).to.be_truthy()

      -- Call the spy
      local result = spy_fn(1, 2, 3)

      -- Default spy returns nil
      expect(result).to_not.exist()

      -- Verify it tracked the call
      expect(spy_fn.called).to.be_truthy()
      expect(spy_fn.call_count).to.equal(1)
      expect(spy_fn.calls).to.exist()
      expect(spy_fn.calls[1]).to.exist()
      expect(spy_fn.calls[1].args).to.exist()
      expect(spy_fn.calls[1].args[1]).to.equal(1)
      expect(spy_fn.calls[1].args[2]).to.equal(2)
      expect(spy_fn.calls[1].args[3]).to.equal(3)
    end)

    it("creates a spy with an explicit return value", function()
      local spy_fn = spy(function()
        return "test result"
      end)

      -- Verify spy was created successfully
      expect(spy_fn).to.exist()
      expect(spy_fn).to.be.a("function")

      -- Call the spy
      local result = spy_fn()

      -- Should return the specified value
      expect(result).to.exist()
      expect(result).to.equal("test result")

      -- Verify it tracked the call
      expect(spy_fn.called).to.be_truthy()
      expect(spy_fn.call_count).to.equal(1)
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
      local spy_fn = spy()
      local not_spy = function() end

      -- Use appropriate checking function based on available methods
      if spy_module.is_spy then
        expect(spy_module.is_spy(spy_fn)).to.be_truthy()
        expect(spy_module.is_spy(not_spy)).to_not.be_truthy()
      else
        -- Alternative: check for spy properties
        expect(spy_fn._is_firmo_spy).to.be_truthy()
        expect(not_spy._is_firmo_spy).to_not.exist()
      end
    end) -- End of "detects if an object is a spy" test
  end) -- End of "Basic Functionality" describe block
  describe("Method Spying", function()
    it("spies on an object method", function()
      local obj = {
        method = function(self, arg)
          return "original: " .. arg
        end,
      }

      -- Create a spy on the method
      local method_spy = spy_module.on(obj, "method")
      expect(method_spy).to.exist()

      -- Call the method
      local result = obj:method("test")

      -- Should still return the original result
      expect(result).to.exist()
      expect(result).to.equal("original: test")

      -- Verify it tracked the call
      expect(method_spy.called).to.be_truthy()
      expect(method_spy.call_count).to.equal(1)
      expect(method_spy.calls).to.exist()
      expect(method_spy.calls[1]).to.exist()
      expect(method_spy.calls[1].args).to.exist()
      expect(method_spy.calls[1].args[1]).to.equal(obj) -- self
      expect(method_spy.calls[1].args[2]).to.equal("test")

      -- Verify the original method was preserved
      expect(method_spy.original).to.exist()
      expect(method_spy.original).to.be.a("function")
    end)

    it("spies on a table function", function()
      local module = {
        function_name = function(arg)
          return "module result: " .. tostring(arg)
        end,
      }

      -- Create a spy on the function
      local fn_spy = spy_module.on(module, "function_name")
      expect(fn_spy).to.exist()

      -- Call the function
      local result = module.function_name("test")

      -- Should still return the original result
      expect(result).to.exist()
      expect(result).to.equal("module result: test")

      -- Verify it tracked the call
      expect(fn_spy.called).to.be_truthy()
      expect(fn_spy.call_count).to.equal(1)
      expect(fn_spy.calls).to.exist()
      expect(fn_spy.calls[1]).to.exist()
      expect(fn_spy.calls[1].args).to.exist()
      expect(fn_spy.calls[1].args[1]).to.equal("test")
    end)
  end)

  describe("Call Tracking", function()
    it("resets a spy", function()
      local spy_fn = spy()
      expect(spy_fn).to.exist()

      -- Call the spy
      spy_fn(1, 2, 3)

      -- Verify call was tracked
      expect(spy_fn.called).to.be_truthy()
      expect(spy_fn.call_count).to.equal(1)
      expect(#spy_fn.calls).to.be_greater_than(0)


      -- Reset the spy - handle both method and function styles
      if type(spy_fn.reset) == "function" then
        spy_fn:reset()
      elseif type(spy_module.reset) == "function" then
        spy_module.reset(spy_fn)
      else
        -- Fallback manual reset
        spy_fn.called = false
        spy_fn.call_count = 0
        spy_fn.calls = {}
      end

      -- Verify it was reset
      expect(spy_fn.called).to_not.be_truthy()
      expect(#spy_fn.calls).to.equal(0)
    end)

    it("provides call args helpers", function()
      local spy_fn = spy()
      expect(spy_fn).to.exist()

      -- Call the spy
      spy_fn("arg1", "arg2", { key = "value" })

      -- Verify args helpers - handle both method and function styles
      local arg_func
      
      if type(spy_fn.arg) == "function" then
        arg_func = function(call_idx, arg_idx)
          return spy_fn:arg(call_idx, arg_idx)
        end
      elseif type(spy_module.get_arg) == "function" then
        arg_func = function(call_idx, arg_idx)
          return spy_module.get_arg(spy_fn, call_idx, arg_idx)
        end
      else
        -- Fallback direct access
        arg_func = function(call_idx, arg_idx)
          return spy_fn.calls[call_idx].args[arg_idx]
        end
      end
      
      expect(arg_func(1, 1)).to.exist()
      expect(arg_func(1, 1)).to.equal("arg1")
      expect(arg_func(1, 2)).to.equal("arg2")
      
      -- Handle the table value argument
      local table_arg = arg_func(1, 3)
      expect(table_arg).to.exist()
      expect(table_arg.key).to.equal("value")

      -- Check last call helpers
      expect(spy_fn:lastArg(1)).to.equal("arg1")
      expect(spy_fn:lastArg(2)).to.equal("arg2")
      expect(spy_fn:lastArg(3).key).to.equal("value")

      -- Check nil handling
      expect(spy_fn:arg(1, 4)).to_not.exist()
      expect(spy_fn:arg(2, 1)).to_not.exist() -- No second call
    end)

    it("tracks call order between multiple spies", function()
      local spy1 = spy()
      local spy2 = spy()
      
      -- Call in specific order
      spy1("first")
      spy2("second")
      spy1("third")
      
      -- Verify ordering
      expect(spy1.called_before(spy2)).to.be_truthy()
      expect(spy2.called_after(spy1)).to.be_truthy()
    end)
    
    it("provides argument verification helpers", function()
      local spy_fn = spy()
      
      -- Call spy with various arguments
      spy_fn("first", 123)
      spy_fn("second", 456)
      
      -- Verify calls with specific arguments
      expect(spy_fn.called_with("first", 123)).to.be_truthy()
      expect(spy_fn.called_with("second", 456)).to.be_truthy()
      expect(spy_fn.called_with("not_called")).to_not.be_truthy()
    end)

    it("can reset call history", function()
      local spy_fn = spy()
      
      -- Make some calls
      spy_fn(1, 2, 3)
      spy_fn(4, 5, 6)
      
      -- Verify calls were tracked
      expect(spy_fn.call_count).to.equal(2)
      
      
      -- Reset the spy - handle both method and function styles
      if type(spy_fn.reset) == "function" then
        spy_fn:reset()
      elseif type(spy_module.reset) == "function" then
        spy_module.reset(spy_fn)
      else
        -- Fallback manual reset
        spy_fn.called = false
        spy_fn.call_count = 0
        spy_fn.calls = {}
      end
      -- Verify state was reset
      expect(spy_fn.called).to_not.be_truthy()
      expect(spy_fn.call_count).to.equal(0)
      expect(#spy_fn.calls).to.equal(0)
    end)
  end)

  describe("Error Handling", function()
    it("handles thrown errors from original functions", { expect_error = true }, function()
      local error_fn = function() 
        error("Test error")
      end
      
      local spy_fn = spy(error_fn)
      
      -- The spy should propagate the error
      local success, result = pcall(function()
        spy_fn()
      end)
      
      expect(success).to.equal(false)
      expect(result).to.match("Test error")
      
      -- Use test_helper consistently for error handling
      local result, err = test_helper.with_error_capture(function()
        spy_fn()  
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err).to.match("Test error")
      
      -- Even when errors are thrown, the call is still tracked
      expect(spy_fn.called).to.be_truthy()
      expect(spy_fn.call_count).to.equal(2)
    end)

    it("handles validation errors gracefully", { expect_error = true }, function()
      -- Try to spy on nil object
      local result, err = test_helper.with_error_capture(function()
        return spy_module.on(nil, "method")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err).to.match("Cannot create spy on nil object")
      
      -- Try to spy on non-existent method
      local obj = {}
      local result2, err2 = test_helper.with_error_capture(function()
        return spy_module.on(obj, "non_existent")
      end)()
      
      expect(result2).to_not.exist()
      expect(err2).to.exist()
      expect(err2).to.match("Method does not exist")
    end)
    
    it("properly handles errors during spy creation", { expect_error = true }, function()
      -- Create an object with a problematic property
      local obj = {}
      
      -- Make a property that's not a function
      obj.property = "string value"
      
      -- Try to spy on a property that's not a function
      local result, err = test_helper.with_error_capture(function()
        return spy_module.on(obj, "property")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err).to.match("not a function")
    end)
  end)

  describe("Restoration", function()
    it("restores spied methods to their original implementation", function()
      local obj = {
        method = function() return "original" end
      }
      
      -- Spy on the method
      local spy_method = spy_module.on(obj, "method")
      
      -- Call the method through the spy
      local result = obj.method()
      expect(result).to.equal("original")
      expect(spy_method.called).to.be_truthy()
      expect(spy_method.call_count).to.equal(1)
      
      -- Restore the original method
      local success = spy_method:restore()
      expect(success).to.be_truthy()
      
      -- Reset spy state and call again
      spy_method.called = false
      spy_method.call_count = 0
      spy_method.calls = {}
      
      -- Call after restoration - should not be tracked
      result = obj.method()
      expect(result).to.equal("original")
      expect(spy_method.called).to.equal(false)
      expect(spy_method.call_count).to.equal(0)
    end)
    
    it("handles restoration of multiple spies", function()
      local obj = {
        method1 = function() return "method1" end,
        method2 = function() return "method2" end
      }
      
      -- Spy on both methods
      local spy1 = spy_module.on(obj, "method1")
      local spy2 = spy_module.on(obj, "method2")
      
      -- Call both methods
      expect(obj.method1()).to.equal("method1")
      expect(obj.method2()).to.equal("method2")
      
      -- Verify both spies recorded calls
      expect(spy1.call_count).to.equal(1)
      expect(spy2.call_count).to.equal(1)
      
      -- Restore both spies
      spy1:restore()
      spy2:restore()
      
      -- Reset spy state
      spy1.call_count = 0
      spy2.call_count = 0
      
      -- Call methods after restoration - should not affect spy objects
      obj.method1()
      obj.method2()
      
      -- Verify spies didn't record calls after restoration
      expect(spy1.call_count).to.equal(0)
      expect(spy2.call_count).to.equal(0)
    end)
    
    it("handles errors during restoration gracefully", { expect_error = true }, function()
      -- Create a spy on an object
      local obj = {
        method = function() return "original" end
      }
      
      local spy_method = spy_module.on(obj, "method")
      
      -- Corrupt the spy by removing the original function reference
      spy_method.original = nil
      
      -- Try to restore the corrupted spy
      local result, err = test_helper.with_error_capture(function()
        return spy_method:restore()
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err).to.match("Cannot restore")
    end)
  end)

  describe("Advanced Features", function()
    -- Use before/after for each test in this block
    local test_spies = {}
    
    before(function()
      -- Reset spies before each test
      test_spies = {}
    end)
    
    after(function()
      -- Clean up spies after each test
      for _, spy_obj in ipairs(test_spies) do
        if spy_obj and spy_obj.restore then
          pcall(function() spy_obj:restore() end)
        end
      end
    end)
    
    it("handles error cases for argument access", { expect_error = true }, function()
      local spy_fn = spy()
      table.insert(test_spies, spy_fn)
      
      -- Call once
      spy_fn("first_call")
      
      -- Try to access non-existent call
      local result, err = test_helper.with_error_capture(function()
        spy_fn:arg(99, 1) -- Call 99 doesn't exist
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err).to.match("index out of bounds")
      
      -- Try to access non-existent argument
      local result2, err2 = test_helper.with_error_capture(function()
        spy_fn:arg(1, 99) -- Argument 99 doesn't exist in call 1
      end)()
      
      expect(result2).to_not.exist()
      expect(err2).to.exist()
      expect(err2).to.match("index out of bounds")
      
      -- Try to access lastArg when no calls made
      spy_fn:reset() -- Clear calls
      
      local result3, err3 = test_helper.with_error_capture(function()
        spy_fn:lastArg(1)
      end)()
      
      expect(result3).to_not.exist()
      expect(err3).to.exist()
      expect(err3).to.match("No calls")
    end)
    
    it("supports complex spy chaining", function()
      local obj = {
        method1 = function() return "one" end,
        method2 = function() return "two" end
      }
      
      -- Create spies on both methods
      local spy1 = spy_module.on(obj, "method1")
      local spy2 = spy_module.on(obj, "method2")
      table.insert(test_spies, spy1)
      table.insert(test_spies, spy2)
      
      -- Call methods in specific order
      obj.method1() -- First call to method1
      obj.method2() -- First call to method2
      obj.method1() -- Second call to method1
      
      -- Verify call order
      expect(spy1.called_before(spy2, 1)).to.be_truthy()
      expect(spy1.called_before(spy2)).to.be_truthy()
      expect(spy2.called_after(spy1)).to.be_truthy()
      
      -- Verify that spy1 was called twice 
      expect(spy1.call_count).to.equal(2)
      
      -- Verify that spy2 was called once
      expect(spy2.call_count).to.equal(1)
    end)
  end) -- End of "Advanced Features" describe block
end) -- End of "Spy Module" describe block
