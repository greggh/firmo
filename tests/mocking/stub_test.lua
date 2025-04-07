-- Stub Module Tests
-- Tests for the stub functionality in the mocking system

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local stub_module = require("lib.mocking.stub")
local test_helper = require("lib.tools.test_helper")

describe("Stub Module", function()
  it("creates a standalone stub function", function()
    local stub = stub_module.new()

    expect(stub).to.be.a("function")
    expect(stub._is_firmo_stub).to.be_truthy()

    -- Call the stub
    local result = stub(1, 2, 3)

    -- Default stub returns nil
    expect(result).to_not.exist()

    -- Verify it tracked the call
    expect(stub.called).to.be_truthy()
    expect(stub.call_count).to.equal(1)
    expect(stub.calls[1].args).to.exist()
    expect(stub.calls[1].args[1]).to.equal(1)
    expect(stub.calls[1].args[2]).to.equal(2)
    expect(stub.calls[1].args[3]).to.equal(3)
  end)

  it("creates a stub with a return value", function()
    local stub = stub_module.new(function()
      return "test result"
    end)

    expect(stub).to.be.a("function")

    -- Call the stub
    local result = stub()

    -- Should return the specified value
    expect(result).to.equal("test result")

    -- Verify it tracked the call
    expect(stub.called).to.be_truthy()
    expect(stub.call_count).to.equal(1)
  end)

  it("creates a stub with a fixed return value", function()
    local stub = stub_module.new(true)

    -- Call the stub
    local result = stub()

    -- Should return the fixed value
    expect(result).to.equal(true)
  end)

  it("stubs an object method", function()
    local obj = {
      method = function(self, arg)
        return "original: " .. arg
      end,
    }

    -- Create a stub on the method
    local method_stub = stub_module.on(obj, "method", "stubbed result")

    -- Call the method
    local result = obj:method("test")

    -- Should return the stub result, not the original
    expect(result).to.equal("stubbed result")

    -- Verify it tracked the call
    expect(method_stub.called).to.be_truthy()
    expect(method_stub.call_count).to.equal(1)
    expect(method_stub.calls[1].args[1]).to.equal(obj) -- self
    expect(method_stub.calls[1].args[2]).to.equal("test")

    -- Verify the original method was preserved
    expect(method_stub.original).to.be.a("function")
  end)

  it("stubs a table function", function()
    local module = {
      function_name = function(arg)
        return "module result: " .. arg
      end,
    }

    -- Create a stub on the function that returns a fixed value
    local fn_stub = stub_module.on(module, "function_name", "stubbed value")

    -- Call the function
    local result = module.function_name("test")

    -- Should return the stub value, not the original
    expect(result).to.equal("stubbed value")

    -- Verify it tracked the call
    expect(fn_stub.called).to.be_truthy()
    expect(fn_stub.call_count).to.equal(1)
    expect(fn_stub.calls[1].args[1]).to.equal("test")
  end)

  it("resets a stub", function()
    local stub = stub_module.new()

    -- Call the stub
    stub(1, 2, 3)

    -- Verify call was tracked
    expect(stub.called).to.be_truthy()
    expect(stub.call_count).to.equal(1)

    -- Reset the stub
    stub:reset()

    -- Verify it was reset
    expect(stub.called).to_not.be_truthy()
    expect(stub.call_count).to.equal(0)
    expect(#stub.calls).to.equal(0)
  end)

  it("returns values in sequence", function()
    local stub = stub_module.new():returns_in_sequence({ 1, 2, 3 })

    -- Call the stub multiple times
    local result1 = stub()
    local result2 = stub()
    local result3 = stub()
    local result4 = stub() -- Sequence exhausted

    -- Verify the sequence of return values
    expect(result1).to.equal(1)
    expect(result2).to.equal(2)
    expect(result3).to.equal(3)
    expect(result4).to_not.exist() -- Default behavior for exhausted sequence
  end)

  it("cycles sequence values when configured", function()
    local stub = stub_module.new():returns_in_sequence({ 1, 2, 3 }):cycle_sequence(true)

    -- Call the stub multiple times
    local result1 = stub()
    local result2 = stub()
    local result3 = stub()
    local result4 = stub() -- Should cycle back to start
    local result5 = stub()

    -- Verify the sequence with cycling
    expect(result1).to.equal(1)
    expect(result2).to.equal(2)
    expect(result3).to.equal(3)
    expect(result4).to.equal(1) -- Cycling back to start
    expect(result5).to.equal(2)
  end)

  it("handles sequence exhaustion according to configuration", function()
    -- Test nil behavior (default)
    local nil_stub = stub_module.new():returns_in_sequence({ 1, 2 }):when_exhausted("nil")

    nil_stub()
    nil_stub() -- Use up sequence
    expect(nil_stub()).to_not.exist()

    -- Test error behavior
    local error_stub = stub_module.new():returns_in_sequence({ 1, 2 }):when_exhausted("error")

    error_stub()
    error_stub() -- Use up sequence

    local result, err = test_helper.with_error_capture(function()
      return error_stub()
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()

    -- Test custom value behavior
    local custom_stub = stub_module.new():returns_in_sequence({ 1, 2 }):when_exhausted("custom", "exhausted")

    custom_stub()
    custom_stub() -- Use up sequence
    expect(custom_stub()).to.equal("exhausted")
  end)

  it("stubs based on argument matchers", function()
    local stub = stub_module.new()

    -- Configure different return values based on arguments
    stub:when_called_with("test1"):returns("result1")
    stub:when_called_with("test2"):returns("result2")
    stub:when_called_with(1, 2, 3):returns("numbers")

    -- Call with different arguments
    local result1 = stub("test1")
    local result2 = stub("test2")
    local result3 = stub(1, 2, 3)
    local result4 = stub("unknown") -- No match

    -- Verify matched return values
    expect(result1).to.equal("result1")
    expect(result2).to.equal("result2")
    expect(result3).to.equal("numbers")
    expect(result4).to_not.exist() -- Default for no match
  end)

  it("handles complex argument matching", function()
    local stub = stub_module.new()

    -- Configure with a match function
    stub
      :when(function(a, b)
        return type(a) == "string" and type(b) == "number" and b > 5
      end)
      :returns("complex match")

    -- Call with matching and non-matching arguments
    local result1 = stub("string", 10) -- Should match
    local result2 = stub("string", 3) -- b <= 5
    local result3 = stub(5, 10) -- a is not string

    -- Verify matching
    expect(result1).to.equal("complex match")
    expect(result2).to_not.equal("complex match")
    expect(result3).to_not.equal("complex match")
  end)

  it("can throw errors", function()
    local stub = stub_module.new():throws("Test error")

    -- Call the stub and expect error
    local result, err = test_helper.with_error_capture(function()
      return stub()
    end)()

    -- Verify error
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err).to.match("Test error")

    -- Call should still be recorded
    expect(stub.called).to.be_truthy()
    expect(stub.call_count).to.equal(1)
  end)

  it("can conditionally throw errors", function()
    local stub = stub_module.new()

    -- Configure to throw error only for specific arguments
    stub:when_called_with("trigger_error"):throws("Conditional error")
    stub:when_called_with("normal"):returns("Normal result")

    -- Test normal case
    local normal_result = stub("normal")
    expect(normal_result).to.equal("Normal result")

    -- Test error case
    local result, err = test_helper.with_error_capture(function()
      return stub("trigger_error")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err).to.match("Conditional error")
  end)

  it("detects if an object is a stub", function()
    local stub = stub_module.new()
    local not_stub = function() end

    expect(stub_module.is_stub(stub)).to.be_truthy()
    expect(stub_module.is_stub(not_stub)).to_not.be_truthy()
  end)

  it("returns the original function when restored", function()
    local obj = {
      method = function()
        return "original"
      end,
    }

    -- Create a stub
    local method_stub = stub_module.on(obj, "method", "stubbed")

    -- Verify stub is working
    expect(obj.method()).to.equal("stubbed")

    -- Restore original
    method_stub:restore()

    -- Verify original is restored
    expect(obj.method()).to.equal("original")
  end)

  -- Add more tests for other stub functionality
end)
