---@diagnostic disable: missing-parameter, param-type-mismatch
--- Coverage System Tests
---
--- Tests the debug hook based coverage system (`lib.coverage`), including:
--- - Basic line coverage tracking.
--- - Error handling during atomic writes (`save_stats`).
--- - Handling of invalid stats files (`load_stats`).
--- - Include/exclude pattern filtering (`central_config`).
--- - Uses `test_helper.execute_string` for running code within coverage context.
--- - Uses `before`/`after` hooks for setup and teardown.
---
--- @author Firmo Team
--- @test

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after

local test_helper = require("lib.tools.test_helper")
local coverage = require("lib.coverage")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")

-- Constants for consistent field values
local COVERAGE_STATS_FILE = ".coverage-stats"
local TEST_EXPECTED = "TEST_EXPECTED"

--- Helper to create a string of Lua code with a test identification comment.
--- Used for testing string-based coverage tracking.
---@param name string A unique name for this test code snippet.
---@param code string The Lua code to include.
---@return string The combined code string with the test identifier comment prepended.
---@private
local function create_test_string(name, code)
  return string.format("--[test:%s]\n%s", name, code)
end

describe("coverage", function()
  -- Setup for each test
  before(function()
    -- Ensure coverage is stopped and cleaned up
    coverage.shutdown()
    -- Reset configuration first
    central_config.reset()
    -- Then set coverage config correctly
    central_config.set("coverage.track_strings", true)
    central_config.set("coverage.normalize_strings", true)
  end)

  -- Cleanup after each test
  after(function()
    coverage.shutdown()
    central_config.reset()
  end)

  it("tracks basic line coverage", function()
    coverage.start()

    -- Execute test code with proper identification
    local code = create_test_string(
      "basic_test",
      [[
      local x = 1
      if x > 0 then
        return "positive"
      else
        return "negative"
      end
    ]]
    )
    local result = test_helper.execute_string(code)
    expect(result).to.equal("positive")
    coverage.stop()

    -- Check coverage data
    local stats = coverage.get_current_data()
    expect(stats).to.be.a("table")

    -- Look for our specific test file in the stats
    local found = false
    for filename, file_data in pairs(stats) do
      if filename:match("basic_test") and type(file_data) == "table" then
        found = true
        expect(file_data.hits).to.be.greater_than(0)
        break
      end
    end
    expect(found).to.be_truthy()
  end)

  it("handles file move errors during atomic writes", function()
    coverage.start()
    test_helper.execute_string(create_test_string("move_error_test", "local x = 1; return x + 1"))
    coverage.stop()

    -- Mock the move_file function to throw an error
    local original_move = filesystem.move_file
    filesystem.move_file = function()
      error(TEST_EXPECTED .. ": Simulated move error")
    end

    -- Should handle move error
    local success, err = pcall(function()
      coverage.save_stats()
    end)
    expect(success).to.be_falsy()
    expect(err).to.match("Simulated move error")

    -- Restore original function
    filesystem.move_file = original_move
  end)

  it("handles invalid stats file", function()
    -- Create invalid stats file
    local f = io.open(COVERAGE_STATS_FILE, "w")
    f:write("invalid json")
    f:close()

    local stats = coverage.load_stats()
    expect(stats).to.be.a("table")
    expect(next(stats)).to.be(nil)
  end)

  it("respects include/exclude patterns", function()
    -- Set up string tracking and patterns
    central_config.set("coverage.track_strings", true)
    central_config.set("coverage.normalize_strings", true)
    central_config.set("coverage.include", { "include_test" })
    central_config.set("coverage.exclude", { "exclude_test" })

    coverage.start()

    -- File that should be included
    local included_code = create_test_string(
      "include_test",
      [[
      local x = 1
      return x + 1
    ]]
    )
    test_helper.execute_string(included_code)

    -- File that should be excluded
    local excluded_code = create_test_string(
      "exclude_test",
      [[
      local y = 2
      return y + 1
    ]]
    )
    test_helper.execute_string(excluded_code)

    coverage.stop()

    -- Check coverage data
    local stats = coverage.get_current_data()
    expect(stats).to.be.a("table")

    -- Look specifically for our included test file
    local found_included = false
    for filename, file_data in pairs(stats) do
      if filename:match("include_test") and type(file_data) == "table" then
        found_included = true
        expect(file_data.hits).to.be.greater_than(0)
        break
      end
    end
    expect(found_included).to.be_truthy()
  end)
end)
