---@diagnostic disable: missing-parameter, param-type-mismatch
--- Specialized Assertion Tests
---
--- Tests for specialized Firmo `expect` assertions, including:
--- - Date assertions: `be_date`, `be_iso_date`, `be_before`, `be_after`, `be_same_day_as`
--- - Advanced Regex: `match_regex` with options
--- - Asynchronous assertions: `complete`, `complete_within`, `resolve_with`, `reject`
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

local test_helper = require("lib.tools.test_helper")

describe("Specialized Assertions", function()
  describe("Date Assertions", function()
    it("validates date strings with be_date", function()
      -- Valid date formats
      expect("2023-10-15").to.be_date()
      expect("10/15/2023").to.be_date()
      expect("15/10/2023").to.be_date()
      expect("2023-10-15T14:30:15Z").to.be_date()
    end)

    it("reject invalid date strings with be_date", { expect_error = true }, function()
      -- Invalid dates
      expect("not-a-date").to_not.be_date()
      expect("2023/13/45").to_not.be_date()
      expect(123).to_not.be_date()
      expect({}).to_not.be_date()
    end)

    it("validates ISO date strings with be_iso_date", function()
      -- Valid ISO dates
      expect("2023-10-15").to.be_iso_date()
      expect("2023-10-15T14:30:15Z").to.be_iso_date()
      expect("2023-10-15T14:30:15+01:00").to.be_iso_date()

      -- Non-ISO dates
      expect("10/15/2023").to_not.be_iso_date()
      expect("15/10/2023").to_not.be_iso_date()
      expect("2023/10/15").to_not.be_iso_date()
      expect("not-a-date").to_not.be_iso_date()
    end)

    it("compares dates with be_before", function()
      -- Earlier date is before later date
      expect("2022-01-01").to.be_before("2023-01-01")
      expect("01/01/2022").to.be_before("01/01/2023")

      -- Same dates are not before each other
      expect("2022-01-01").to_not.be_before("2022-01-01")

      -- Later date is not before earlier date
      expect("2023-01-01").to_not.be_before("2022-01-01")
    end)

    it("compares dates with be_after", function()
      -- Later date is after earlier date
      expect("2023-01-01").to.be_after("2022-01-01")
      expect("01/01/2023").to.be_after("01/01/2022")

      -- Same dates are not after each other
      expect("2022-01-01").to_not.be_after("2022-01-01")

      -- Earlier date is not after later date
      expect("2022-01-01").to_not.be_after("2023-01-01")
    end)

    it("checks if dates are on the same day with be_same_day_as", function()
      -- Same day, different times
      expect("2022-01-01T10:30:00Z").to.be_same_day_as("2022-01-01T15:45:00Z")
      expect("01/01/2022 10:30").to.be_same_day_as("01/01/2022 15:45")

      -- Different days
      expect("2022-01-01").to_not.be_same_day_as("2022-01-02")
      expect("01/01/2022").to_not.be_same_day_as("01/02/2022")
    end)

    it("handles error cases in date assertions", { expect_error = true }, function()
      -- Invalid left operand
      local result, err = test_helper.with_error_capture(function()
        expect(123).to.be_before("2023-01-01")
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Expected a date string")

      -- Invalid right operand
      local result2, err2 = test_helper.with_error_capture(function()
        expect("2023-01-01").to.be_before(123)
      end)()

      expect(result2).to_not.exist()
      expect(err2).to.exist()
      expect(err2.message).to.match("Expected a date string")
    end)
  end)

  describe("Advanced Regex Assertions", function()
    it("matches patterns with options using match_regex", function()
      -- Basic matching
      expect("hello world").to.match_regex("hello")
      expect("HELLO WORLD").to_not.match_regex("hello")

      -- Case insensitive matching
      expect("HELLO WORLD").to.match_regex("hello", { case_insensitive = true })
      expect("Hello World").to.match_regex("^h.*d$", { case_insensitive = true })

      -- Multiline matching
      local multiline_text = "First line\nSecond line\nThird line"
      expect(multiline_text).to.match_regex("^Second", { multiline = true })
      expect(multiline_text).to_not.match_regex("^Second") -- Without multiline option

      -- Both options together
      expect("FIRST LINE\nsecond LINE").to.match_regex("^first.*\n^second", {
        case_insensitive = true,
        multiline = true,
      })
    end)

    it("handles error cases in regex assertions", { expect_error = true }, function()
      -- Invalid operand
      local result, err = test_helper.with_error_capture(function()
        expect(123).to.match_regex("pattern")
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Expected a string")

      -- Invalid pattern
      local result2, err2 = test_helper.with_error_capture(function()
        expect("text").to.match_regex(123)
      end)()

      expect(result2).to_not.exist()
      expect(err2).to.exist()
      expect(err2.message).to.match("Expected a string pattern")

      -- Invalid options
      local result3, err3 = test_helper.with_error_capture(function()
        expect("text").to.match_regex("pattern", "not a table")
      end)()

      expect(result3).to_not.exist()
      expect(err3).to.exist()
      expect(err3.message).to.match("Expected options to be a table")
    end)
  end)

  describe("Async Assertions", function()
    -- Helper function to get access to the async module
    local async = error_handler.try_require("lib.async")

    -- Create test async functions
    --- Helper function to create a promise that resolves after a delay.
    ---@param delay? number Delay in milliseconds (default 10).
    ---@param value? any Value to resolve with (default "success").
    ---@return table promise A promise object that resolves with `value`.
    ---@private
    local function async_success(delay, value)
      return async.create_promise(function(resolve)
        async.set_timeout(function()
          resolve(value or "success")
        end, delay or 10)
      end)
    end

    --- Helper function to create a promise that rejects after a delay.
    ---@param delay? number Delay in milliseconds (default 10).
    ---@param message? any Error message to reject with (default "error occurred").
    ---@return table promise A promise object that rejects with `message`.
    ---@private
    local function async_failure(delay, message)
      return async.create_promise(function(_, reject)
        async.set_timeout(function()
          reject(message or "error occurred")
        end, delay or 10)
      end)
    end

    --- Simple synchronous function for testing non-promise cases.
    ---@return string The string "sync result".
    ---@private
    local function sync_function()
      return "sync result"
    end

    it("checks if async function completes with complete", function()
      -- This test must be in an async context
      async.async(function()
        -- Promise that resolves
        expect(async_success()).to.complete()

        -- Promise that rejects should not complete successfully
        expect(async_failure()).to_not.complete()
      end)
    end)

    it("checks if async function completes within time limit", function()
      async.async(function()
        -- Promise that resolves quickly
        expect(async_success(5)).to.complete_within(50)

        -- Promise that takes too long
        expect(async_success(100)).to_not.complete_within(20)

        -- Promise that rejects quickly still doesn't "complete" successfully
        expect(async_failure(5)).to_not.complete_within(50)
      end)
    end)

    it("checks if async function resolves with expected value", function()
      async.async(function()
        -- Promise that resolves with specific value
        expect(async_success(5, "expected value")).to.resolve_with("expected value")

        -- Promise that resolves with different value
        expect(async_success(5, "wrong value")).to_not.resolve_with("expected value")

        -- Promise that rejects
        expect(async_failure(5)).to_not.resolve_with("anything")
      end)
    end)

    it("checks if async function rejects", function()
      async.async(function()
        -- Promise that rejects
        expect(async_failure()).to.reject()

        -- Promise that resolves
        expect(async_success()).to_not.reject()

        -- Promise that rejects with specific message
        expect(async_failure(5, "specific error")).to.reject("specific error")

        -- Promise that rejects with different message
        expect(async_failure(5, "wrong error")).to_not.reject("specific error")
      end)
    end)

    it("detects when async assertions are used in non-async contexts", { expect_error = true }, function()
      -- Create a stub function that doesn't rely on async.create_promise
      local stub_async_fn = function() end

      -- Should fail because we're not in an async.test context
      local result, err = test_helper.with_error_capture(function()
        expect(stub_async_fn).to.complete()
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Async assertions can only be used in async test contexts")
    end)

    it("fails when non-promises are used with async assertions", function()
      async.async(function()
        -- Should fail because sync_function is not a promise
        local result, err = test_helper.with_error_capture(function()
          expect(sync_function).to.complete()
        end)()

        expect(result).to_not.exist()
        expect(err).to.exist()
        expect(err.message).to.match("Expected a promise")
      end)
    end)
  end)
end)
