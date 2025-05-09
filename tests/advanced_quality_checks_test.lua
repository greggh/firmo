-- tests/advanced_quality_checks_test.lua
local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

-- Scenario 1: Test with an unrestored spy
describe("Spy Restoration Checks", function()
  local target_object = {
    method_to_spy_on = function(self, val) return val * 2 end -- Added self parameter
  }
  local a_spy -- This spy will be created in one test and potentially not restored

  it("should trigger an unrestored spy issue if spy is not restored", function()
    a_spy = firmo.spy.on(target_object, "method_to_spy_on")
    expect(target_object:method_to_spy_on(5)).to.equal(10) -- Use colon for method call
    expect(a_spy:called_with(target_object, 5)).to.be_truthy() -- Correct assertion syntax
    -- Deliberately not calling a_spy:restore() here
    -- This test should still pass functionally, but the quality module should flag an unrestored spy.
  end)

  it("should NOT trigger an unrestored spy issue if spy IS restored", function()
    local another_spy = firmo.spy.on(target_object, "method_to_spy_on")
    expect(target_object:method_to_spy_on(3)).to.equal(6) -- Use colon for method call
    expect(another_spy:called_with(target_object, 3)).to.be_truthy() -- Correct assertion syntax
    another_spy:restore() -- Correctly restoring this spy
  end)

  -- Cleanup for the first test's spy, if it wasn't restored.
  -- This 'after' hook runs after each 'it' block in this 'describe'.
  -- The unrestored spy issue for the first 'it' block should already have been recorded by quality.end_test().
  after(function()
    if a_spy and a_spy.target and a_spy.restore then -- Check if a_spy is a valid spy object
      -- Only restore if it's still spying on our target_object's method.
      -- This is a simplified check; a more robust system might involve unique spy IDs.
      if type(target_object.method_to_spy_on) == "table" and target_object.method_to_spy_on._is_firmo_spy == true then
        -- Check if the current method is indeed our spy 'a_spy'
        -- This comparison might be tricky if the spy wrapper is a new function instance.
        -- A more reliable way is to check if a_spy's target and name match.
        if a_spy.target == target_object and a_spy.name == "method_to_spy_on" then
            pcall(function() a_spy:restore() end)
            a_spy = nil -- Clear it so this after hook doesn't try to restore it again for other tests
        end
      end
    end
  end)
end)

-- Scenario 2: Empty describe block
describe("This Describe Block is Intentionally Empty", function()
  -- No 'it' blocks here.
  -- The quality module should flag this describe block as an issue.
end)

describe("This Describe Block is NOT Empty", function()
  it("contains a test, so it's not empty", function()
    expect(true).to.be_truthy()
  end)
end)

-- Scenario 3: Nested describe blocks, one of which is empty
describe("Nesting with an Empty Describe", function()
  describe("Outer Populated Describe", function()
    it("has a test in the outer populated describe", function()
      expect(1).to.equal(1)
    end)

    describe("Inner Empty Describe", function()
      -- This inner describe is empty and should be flagged.
    end)

    describe("Another Inner Populated Describe", function()
      it("has a test in the second inner populated describe", function()
        expect(2).to.equal(2)
      end)
    end)
  end)
end)

