-- tests/temp_quality_examples_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Issue: Too few assertions
it("is a test with too few assertions", function()
  expect(true).to.be_truthy()
  -- This test will likely trigger "Too few assertions" based on default quality levels (e.g. level 2+ requires more)
end)

-- Issue: Missing describe block (This one is tricky to trigger in isolation for a single test if the file itself is a test.
-- We will rely on other tests to show this if it's a global issue in a report, or simulate by how `firmo` processes it)
-- For now, let's focus on issues within tests.

-- Issue: Missing it block (This cannot be directly created as an "issue" in a runnable test file,
-- as the test runner expects 'it' blocks. This issue is more about test file structure.)

describe("Demonstrating Quality Issues", function()
  -- Issue: Missing required assertion types (e.g., missing 'error_handling' or 'type_checking')
  it("should show diverse assertions but might miss some required types", function()
    expect("hello").to.equal("hello") -- equality
    expect(123).to.be.a("number")   -- type_checking (might satisfy one requirement)
    -- If 'error_handling' is required by a level, this test would miss it.
  end)

  -- Issue: Test doesn't have a proper descriptive name (Simulated, as 'has_proper_name' logic is in quality.lua)
  -- The name below is okay, but imagine if quality.lua flagged it. We need an issue that WILL be flagged.
  -- Let's make a very generic name that might be flagged by stricter "proper name" checks if they exist.
  it("test 123", function()
    expect(1).to.equal(1)
    expect(2).to.equal(2)
  end)

  -- Issue: Missing setup/teardown with before/after blocks
  -- This is a contextual issue. If a level requires before/after, a describe block without them would fail.
  -- This describe block intentionally lacks before/after to potentially trigger this for its tests.
  it("should exist in a describe block that might need before/after", function()
    expect(true).to.be_truthy()
    expect(false).to.be_falsy()
  end)

  -- Issue: Insufficient context nesting
  -- This describe block itself is only 1 level deep. If a test inside needs 2 levels, it would trigger.
  it("might have insufficient nesting for some quality levels", function()
    expect(1+1).to.equal(2)
    expect(2+2).to.equal(4)
  end)

  -- Issue: Found forbidden patterns (e.g. TODO)
  it("should not have TODO in its name", function() -- Intentionally okay name
    -- Imagine the test name or description had "TODO" or "SKIP"
    expect(true).to.be_truthy()
    expect(1).to.equal(1)
  end)
  -- Let's actually add one that will trigger 'Found forbidden patterns'
  it("TODO: This test needs to be fixed -- example of forbidden pattern", function()
    expect(true).to.be_truthy()
  end)

  -- Issue: Too many assertions
  it("should demonstrate having too many assertions", function()
    expect(1).to.equal(1)
    expect(2).to.equal(2)
    expect(3).to.equal(3)
    expect(4).to.equal(4)
    expect(5).to.equal(5)
    expect(6).to.equal(6)
    expect(7).to.equal(7)
    expect(8).to.equal(8)
    expect(9).to.equal(9)
    expect(10).to.equal(10)
    expect(11).to.equal(11) -- Likely to exceed default max (e.g., 10 for level 2)
  end)

end)

describe("Nested Context For Nesting Check", function()
  describe("Second Level of Nesting", function()
    it("should satisfy a 2-level nesting requirement", function()
      expect(true).to.be_truthy()
      expect(1).to.equal(1)
    end)
  end)
end)

-- Note: "Missing mock/spy verification" and "Insufficient code coverage" are harder to reliably trigger
-- in a generic example test file without specific code to mock or analyze for coverage.
-- The existing examples for those in ISSUE_FIX_EXAMPLES will serve as the basis for their display.

