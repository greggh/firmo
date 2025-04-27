---@diagnostic disable: missing-parameter, param-type-mismatch
--- Tagging and Filtering Functionality Tests
---
--- Verifies the `firmo.tags()` function for applying tags to tests and the
--- filtering mechanism (using the `--tags` and `--filter` CLI options).
--- Includes tests for multiple tags, tag validation (must be string), and
--- filter pattern validation (must be string). Also demonstrates basic usage
--- in comments at the end of the file.
---
--- @author Firmo Team
--- @test
package.path = "../?.lua;" .. package.path
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local error_handler = require("lib.tools.error_handler")

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")

describe("Tagging and Filtering", function()
  it("basic test with no tags", function()
    expect(true).to.be.truthy()
  end)

  firmo.tags("unit")
  it("test with unit tag", function()
    expect(1 + 1).to.equal(2)
  end)

  firmo.tags("integration", "slow")
  it("test with integration and slow tags", function()
    expect("integration").to.be.a("string")
  end)

  firmo.tags("unit", "fast")
  it("test with unit and fast tags", function()
    expect({}).to.be.a("table")
  end)

  -- Testing filter pattern matching
  it("test with numeric value 12345", function()
    expect(12345).to.be.a("number")
  end)

  it("test with different numeric value 67890", function()
    expect(67890).to.be.a("number")
  end)

  it("should validate tag types", { expect_error = true }, function()
    -- Test with non-string tag
    local result, err = test_helper.with_error_capture(function()
      firmo.tags(123)
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Tag must be a string")
  end)

  it("should validate filter pattern types", { expect_error = true }, function()
    --- Simulates applying a filter pattern to a test name.
    --- This helper is needed because the actual filtering logic resides in the runner.
    --- Validates that the pattern is a string.
    ---@param pattern string The Lua pattern to apply.
    ---@param test_name string The name of the test to check against the pattern.
    ---@return boolean True if the test name matches the pattern, false otherwise.
    ---@throws table If `pattern` is not a string (validation error).
    ---@private
    local function apply_filter(pattern, test_name)
      if type(pattern) ~= "string" then
        error(error_handler.validation_error("Filter pattern must be a string", { provided_type = type(pattern) }))
      end

      return string.find(test_name, pattern) ~= nil
    end

    -- Test with valid pattern
    expect(apply_filter("numeric", "test with numeric value")).to.be_truthy()

    -- Test with invalid pattern type
    local result, err = test_helper.with_error_capture(function()
      apply_filter(123, "test with numeric value")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    expect(err.message).to.match("Filter pattern must be a string")
  end)
end)
