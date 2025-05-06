--- Example demonstrating specialized assertion types in Firmo.
---
--- This example showcases assertions beyond the basic types, including:
--- - Date validation (`to.be_date`, `to.be_iso_date`) and comparison (`to.be_before`, `to.be_after`, `to.be_same_day_as`).
--- - Advanced regular expression matching with options (`to.match_regex`).
--- - Asynchronous assertions for promises (`to.complete`, `to.complete_within`, `to.resolve_with`, `to.reject`).
---
--- @module examples.specialized_assertions_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.assertion.expect
--- @see lib.async
--- @usage
--- Run the embedded tests:
--- ```bash
--- lua test.lua examples/specialized_assertions_example.lua
--- ```

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
local async = require("lib.async")
local it_async = firmo.it_async -- Added missing import for async tests
local test_helper = require("lib.tools.test_helper")

--- Main test suite showing specialized assertions in action.
--- @within examples.specialized_assertions_example
describe("Specialized Assertions Examples", function()
  --- Tests related to validating and comparing date strings.
  --- @within examples.specialized_assertions_example
  describe("Date Assertions", function()
    --- Tests `to.be_date` for various common date formats.
    it("validates different common date string formats", function()
      -- ISO format dates
      expect("2023-04-15").to.be_date()
      expect("2023-04-15T14:30:00Z").to.be_date()

      -- US format dates (MM/DD/YYYY)
      expect("04/15/2023").to.be_date()

      -- European format dates (DD/MM/YYYY)
      expect("15/04/2023").to.be_date()
    end)

    --- Tests `to.be_iso_date` for validating ISO 8601 formats.
    it("validates ISO 8601 date format specifically", function()
      expect("2023-04-15").to.be_iso_date()
      expect("2023-04-15T14:30:00Z").to.be_iso_date()

      -- Non-ISO dates
      expect("04/15/2023").to_not.be_iso_date()
    end)

    --- Tests date comparison assertions: `to.be_before`, `to.be_after`, `to.be_same_day_as`.
    it("compares dates chronologically", function()
      -- Comparing dates
      expect("2022-01-01").to.be_before("2023-01-01")
      expect("2023-01-01").to.be_after("2022-01-01")

      -- Checking if dates are on the same day
      expect("2023-04-15T09:00:00Z").to.be_same_day_as("2023-04-15T18:30:00Z")
    end)
  end)

  --- Tests advanced regular expression matching using `to.match_regex`.
  --- @within examples.specialized_assertions_example
  describe("Advanced Regex Assertions", function()
    --- Tests `to.match_regex` with case-insensitive and multiline options.
    it("matches patterns with case-insensitive and multiline options", function()
      -- Basic regex
      expect("hello world").to.match_regex("world$")

      -- Case-insensitive matching
      expect("HELLO WORLD").to.match_regex("hello", { case_insensitive = true })

      -- Multiline matching
      local multiline_text = [[
First line
Second line
Third line
]]
      -- In this context, the ^ matches the start of each line with multiline option
      expect(multiline_text).to.match_regex("^Second", { multiline = true })
    end)
  end)

  --- Tests assertions specifically designed for asynchronous operations (promises).
  --- @within examples.specialized_assertions_example
  describe("Async Assertions", function()
    --- Helper async function that resolves after a delay.
    --- @param ms? number Delay in milliseconds (default 50).
    --- @param value? any Value to resolve with (default "success").
    --- @return table promise A promise object.
    --- @within examples.specialized_assertions_example
    local function delayed_success(ms, value)
      -- Return an executor function directly using async.async
      return async.async(function()
        async.await(ms or 50)
        return value or "success"
      end)() -- Note the immediate call `()` to get the executor
    end

    --- Helper async function that rejects after a delay.
    --- @param ms? number Delay in milliseconds (default 50).
    --- @param reason? any Reason for rejection (default "error").
    --- @return table promise A promise object.
    --- @within examples.specialized_assertions_example
    local function delayed_error(ms, reason)
      -- Return the async function without executing it
      return async.async(function()
        async.await(ms or 50)
        error(reason or "Delayed error occurred")
      end)  -- Remove the () to match how we use it
    end

    --- Tests successful completion and timing.
    it_async(
      "checks if an async function completes successfully (or within time)",
      { timeout = 200 },
      async.async(function() -- Wrap in async function to use await
        local result = async.await(delayed_success(50))
        expect(result).to.equal("success")

        -- Test completion within a timeframe
        local start_time = os.clock()
        local quick_result = async.await(delayed_success(10))
        local elapsed = (os.clock() - start_time) * 1000
        expect(quick_result).to.equal("success")
        expect(elapsed).to.be_less_than(100)
      end)
    )

    --- Tests checking the result value.
    it_async("checks the resolution value of an async function", 
      async.async(function()
        local result = async.await(delayed_success(10, "expected result"))
        expect(result).to.equal("expected result")

        local default_result = async.await(delayed_success(10))
        expect(default_result).to.equal("success")
      end)
    )

    --- Tests rejection using test_helper.expect_async_error.
    --- Note: Async errors include additional context about parallel operations.
    it_async("checks if an async function rejects (optionally with a reason)", function()
      -- Pass the delayed_error function directly
      local err = test_helper.expect_async_error(delayed_error(10, "Specific Reason"), 50, "Specific Reason")
      expect(err).to.exist()
      expect(err.message).to.match("Specific Reason")

      -- Test default error message
      local err2 = test_helper.expect_async_error(delayed_error(10), 50, "Delayed error occurred")
      expect(err2).to.exist()
      expect(err2.message).to.match("Delayed error occurred")
    end)
  end)
end)
