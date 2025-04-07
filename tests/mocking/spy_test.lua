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

  -- Add more tests for other spy functionality
end)
