-- Example of using specialized assertions in firmo

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local async = require("lib.async")

-- Example test suite showing specialized assertions in action
describe("Specialized Assertions Examples", function()
  -- Date assertions
  describe("Date Assertions", function()
    it("validates different date formats", function()
      -- ISO format dates
      expect("2023-04-15").to.be_date()
      expect("2023-04-15T14:30:00Z").to.be_date()

      -- US format dates (MM/DD/YYYY)
      expect("04/15/2023").to.be_date()

      -- European format dates (DD/MM/YYYY)
      expect("15/04/2023").to.be_date()
    end)

    it("validates ISO date format specifically", function()
      expect("2023-04-15").to.be_iso_date()
      expect("2023-04-15T14:30:00Z").to.be_iso_date()

      -- Non-ISO dates
      expect("04/15/2023").to_not.be_iso_date()
    end)

    it("compares dates", function()
      -- Comparing dates
      expect("2022-01-01").to.be_before("2023-01-01")
      expect("2023-01-01").to.be_after("2022-01-01")

      -- Checking if dates are on the same day
      expect("2023-04-15T09:00:00Z").to.be_same_day_as("2023-04-15T18:30:00Z")
    end)
  end)

  -- Advanced regex assertions
  describe("Advanced Regex Assertions", function()
    it("matches patterns with options", function()
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

  -- Async assertions
  describe("Async Assertions", function()
    -- Example async function that resolves after a delay
    local function delayed_success(ms, value)
      return async.create_promise(function(resolve)
        async.set_timeout(function()
          resolve(value or "success")
        end, ms or 50)
      end)
    end

    -- Example async function that rejects after a delay
    local function delayed_error(ms, reason)
      return async.create_promise(function(_, reject)
        async.set_timeout(function()
          reject(reason or "error")
        end, ms or 50)
      end)
    end

    it("checks if an async function completes", function()
      async.test(function()
        -- Check if the function completes successfully
        expect(delayed_success()).to.complete()

        -- Check if the function completes within a time limit
        expect(delayed_success(10)).to.complete_within(100)

        -- Long operation should not complete within short timeout
        expect(delayed_success(200)).to_not.complete_within(50)
      end)
    end)

    it("checks the resolution value of an async function", function()
      async.test(function()
        -- Check if the function resolves with an expected value
        expect(delayed_success(10, "expected result")).to.resolve_with("expected result")

        -- Should not match a different value
        expect(delayed_success(10, "actual result")).to_not.resolve_with("wrong result")
      end)
    end)

    it("checks if an async function rejects with an error", function()
      async.test(function()
        -- Check if the function rejects
        expect(delayed_error()).to.reject()

        -- Check if the function rejects with a specific message
        expect(delayed_error(10, "validation failed")).to.reject("validation failed")

        -- Should not match a different error message
        expect(delayed_error(10, "actual error")).to_not.reject("wrong error")
      end)
    end)
  end)
end)
