--- Example demonstrating the Firmo date and time module.
---
--- This example showcases the comprehensive features of the `lib.tools.date` module,
--- including:
--- - Creating DateObject instances using various inputs (current time, components, strings, tables, epoch seconds).
--- - Getting date/time components (year, month, day, hour, minute, second, ticks, weekday, yearday).
--- - Setting date/time components individually.
--- - Performing date/time arithmetic (adding/subtracting years, months, days, hours, minutes, seconds, ticks).
--- - Comparing DateObject instances.
--- - Formatting dates and times using `strftime`-like specifiers and custom groups.
--- - Working with ISO 8601 week dates.
--- - Basic time zone conversions (`tolocal`, `toutc`).
--- - Utility functions (`isleapyear`, `epoch`).
--- - Parsing date strings (implicitly via the constructor).
---
--- @module examples.date_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.tools.date
--- @see lib.tools.error_handler
--- @usage
--- Run the embedded tests:
--- ```bash
--- lua test.lua examples/date_example.lua
--- ```

-- Import necessary modules
local date = require("lib.tools.date")
local logging = require("lib.tools.logging") -- Add require

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

-- Setup logger
local logger = logging.get_logger("DateExample") -- Add logger instance

--- Main test suite for the date module.
--- @within examples.date_example
describe("Date Module Examples", function()
  --- Tests for creating DateObject instances using the date() constructor.
  --- @within examples.date_example
  describe("Date Object Creation", function()
    --- Tests creating a date object representing the current local time.
    it("creates current local time with no arguments or false", function()
      local now = date()
      local now_f = date(false)
      expect(now).to.exist()
      expect(now_f).to.exist()
      -- Check if they are close (within a second)
      expect(math.abs(now:spanseconds() - now_f:spanseconds())).to.be_less_than(1)
    end)

    --- Tests creating a date object representing the current UTC time.
    it("creates current UTC time with true argument", function()
      local utc_now = date(true)
      expect(utc_now).to.exist()
      -- Further validation could involve comparing with os.date("!*t")
    end)

    --- Tests creating a date object from year, month, day components.
    it("creates a date from YMD components", function()
      local d = date(2024, 5, 17) -- May 17, 2024
      expect(d:getyear()).to.equal(2024)
      expect(d:getmonth()).to.equal(5)
      expect(d:getday()).to.equal(17)
      expect(d:gethours()).to.equal(0) -- Defaults to midnight
    end)

    --- Tests creating a date object from YMDHMS components.
    it("creates a date from YMDHMS components", function()
      local dt = date(2024, 5, 17, 14, 30, 15) -- May 17, 2024, 14:30:15
      expect(dt:getyear()).to.equal(2024)
      expect(dt:getmonth()).to.equal(5)
      expect(dt:getday()).to.equal(17)
      expect(dt:gethours()).to.equal(14)
      expect(dt:getminutes()).to.equal(30)
      expect(dt:getseconds()).to.equal(15)
    end)

    --- Tests creating a date object from a parsable date string (ISO format).
    it("creates a date from an ISO date string", function()
      local d = date("2024-05-17T10:00:00Z")
      expect(d:getyear()).to.equal(2024)
      expect(d:getmonth()).to.equal(5)
      expect(d:getday()).to.equal(17)
      expect(d:gethours()).to.equal(10)
    end)

    --- Tests creating a date object from an os.date style table.
    it("creates a date from an os.date style table", function()
      local tbl = { year = 2024, month = 5, day = 17, hour = 11, min = 30, sec = 0 }
      local d = date(tbl)
      expect(d:getyear()).to.equal(2024)
      expect(d:getmonth()).to.equal(5)
      expect(d:getday()).to.equal(17)
      expect(d:gethours()).to.equal(11)
      expect(d:getminutes()).to.equal(30)
    end)

    --- Tests creating a date object from epoch seconds.
    it("creates a date from epoch seconds", function()
      local epoch_date = date.epoch() -- Get the module's epoch date
      local d = date(0) -- Seconds since OS epoch
      -- This check is approximate as OS epoch might differ slightly from module's internal 0001-01-01
      -- A better check would involve os.time reference if possible and reliable.
      expect(d:getyear()).to.equal(epoch_date:getyear())
      expect(d:getmonth()).to.equal(epoch_date:getmonth())
      expect(d:getday()).to.equal(epoch_date:getday())
    end)

    --- Tests creating a date object by copying another instance.
    it("creates a copy of another date object", function()
      local original = date(2024, 1, 1)
      local copy = date(original)
      expect(copy).to.equal(original) -- Verify initial equality (same value)
      -- We'll prove these are different objects by modifying one and showing it doesn't affect the other
      copy:adddays(1)
      expect(copy).to_not.equal(original) -- Verifies they are separate objects since modifying copy doesn't affect original
    end)
  end)

  --- Tests for getting date/time components.
  --- @within examples.date_example
  describe("Getting Components", function()
    local dt = date(2024, 10, 31, 18, 45, 59, 123456) -- Halloween evening

    --- Tests standard YMD HMS getters.
    it("gets standard date and time components", function()
      expect(dt:getyear()).to.equal(2024)
      expect(dt:getmonth()).to.equal(10)
      expect(dt:getday()).to.equal(31)
      expect(dt:gethours()).to.equal(18)
      expect(dt:getminutes()).to.equal(45)
      expect(dt:getseconds()).to.equal(59)
      expect(dt:getticks()).to.equal(123456)
    end)

    --- Tests weekday and yearday getters.
    it("gets weekday and yearday", function()
      -- October 31, 2024 is a Thursday
      expect(dt:getweekday()).to.equal(5) -- Lua weekday: 1=Sun, 5=Thu
      -- 2024 is a leap year. Oct 31 is day 305 (31+29+31+30+31+30+31+31+30+31)
      expect(dt:getyearday()).to.equal(305)
    end)
  end)

  --- Tests for setting date/time components.
  --- @within examples.date_example
  describe("Setting Components", function()
    local dt

    --- Resets the date object before each test in this block.
    before(function()
      dt = date(2024, 1, 1, 0, 0, 0) -- Start of 2024
    end)

    --- Tests setting the year.
    it("sets the year", function()
      dt:setyear(2025)
      expect(dt:getyear()).to.equal(2025)
    end)

    --- Tests setting the month.
    it("sets the month", function()
      dt:setmonth(12) -- Set to December
      expect(dt:getmonth()).to.equal(12)
      dt:setmonth("Feb") -- Set using abbreviation
      expect(dt:getmonth()).to.equal(2)
    end)

    --- Tests setting the day.
    it("sets the day", function()
      dt:setday(15)
      expect(dt:getday()).to.equal(15)
    end)

    --- Tests setting the hour.
    it("sets the hours", function()
      dt:sethours(23)
      expect(dt:gethours()).to.equal(23)
    end)

    --- Tests setting the minutes.
    it("sets the minutes", function()
      dt:setminutes(59)
      expect(dt:getminutes()).to.equal(59)
    end)

    --- Tests setting the seconds.
    it("sets the seconds", function()
      dt:setseconds(58)
      expect(dt:getseconds()).to.equal(58)
    end)

    --- Tests setting the ticks.
    it("sets the ticks", function()
      dt:setticks(999999)
      expect(dt:getticks()).to.equal(999999)
    end)

    --- Tests setting multiple components at once.
    it("sets multiple components", function()
      dt:setyear(2023, 6, 15) -- Set Y, M, D
      dt:sethours(10, 30, 45) -- Set H, M, S
      expect(dt:fmt0("%F %T")).to.equal("2023-06-15 10:30:45")
    end)
  end)

  --- Tests for date/time arithmetic.
  --- @within examples.date_example
  describe("Date Arithmetic", function()
    local dt

    --- Resets the date object before each test in this block.
    before(function()
      dt = date(2024, 2, 28, 12, 0, 0) -- Near end of Feb in a leap year
    end)

    --- Tests adding days.
    it("adds days", function()
      dt:adddays(1)
      expect(dt:getday()).to.equal(29) -- Feb 29 (leap year)
      dt:adddays(1)
      expect(dt:getday()).to.equal(1) -- Mar 1
      expect(dt:getmonth()).to.equal(3)
    end)

    --- Tests adding months.
    it("adds months", function()
      dt:addmonths(1) -- Feb 28 -> Mar 28
      expect(dt:getmonth()).to.equal(3)
      expect(dt:getday()).to.equal(28)
      dt:addmonths(12) -- Mar 28 -> Mar 28 next year
      expect(dt:getyear()).to.equal(2025)
      expect(dt:getmonth()).to.equal(3)
    end)

    --- Tests adding years.
    it("adds years", function()
      dt:addyears(1)
      expect(dt:getyear()).to.equal(2025)
      -- Feb 28, 2025 (not a leap year)
    end)

    --- Tests adding hours.
    it("adds hours", function()
      dt:addhours(13) -- 12:00 + 13 hours = 01:00 next day
      expect(dt:gethours()).to.equal(1)
      expect(dt:getday()).to.equal(29)
    end)

    --- Tests adding minutes.
    it("adds minutes", function()
      dt:addminutes(90) -- 12:00 + 90 mins = 13:30
      expect(dt:gethours()).to.equal(13)
      expect(dt:getminutes()).to.equal(30)
    end)

    --- Tests adding seconds.
    it("adds seconds", function()
      dt:addseconds(125) -- 12:00:00 + 125s = 12:02:05
      expect(dt:getminutes()).to.equal(2)
      expect(dt:getseconds()).to.equal(5)
    end)

    --- Tests adding ticks.
    it("adds ticks", function()
      local ticks_per_second = date.ticks() -- Usually 1,000,000
      dt:addticks(ticks_per_second * 2.5) -- Add 2.5 seconds worth of ticks
      expect(dt:getseconds()).to.equal(2)
      expect(dt:getticks()).to.equal(ticks_per_second * 0.5)
    end)

    --- Tests subtracting dates using the `diff` method (or `-` operator).
    it("subtracts dates using diff", function()
      local d1 = date(2024, 1, 10)
      local d2 = date(2024, 1, 1)
      local diff = date.diff(d1, d2) -- or d1 - d2
      expect(diff:spandays()).to.be_near(9, 0.0001) -- Difference is 9 days
      expect(diff:spanhours()).to.be_near(9 * 24, 0.0001) -- Difference in hours
    end)
  end)

  --- Tests for date comparison.
  --- @within examples.date_example
  describe("Date Comparison", function()
    local d1 = date(2024, 5, 17, 12, 0, 0)
    local d2 = date(2024, 5, 17, 13, 0, 0)
    local d3 = date(2024, 5, 18, 12, 0, 0)
    local d1_copy = d1:copy()

    --- Tests equality and inequality.
    it("compares dates for equality", function()
      expect(d1 == d1_copy).to.be_truthy()
      expect(d1 == d2).to.be_falsy()
      expect(d1 ~= d2).to.be_truthy()
    end)

    --- Tests less than/greater than comparisons.
    it("compares dates chronologically (less/greater)", function()
      expect(d1 < d2).to.be_truthy()
      expect(d2 < d3).to.be_truthy()
      expect(d1 < d3).to.be_truthy()
      expect(d2 > d1).to.be_truthy()
      expect(d3 > d1).to.be_truthy()
      expect(d1 >= d1_copy).to.be_truthy()
      expect(d2 <= d3).to.be_truthy()
    end)
  end)

  --- Tests for date formatting.
  --- @within examples.date_example
  describe("Date Formatting", function()
    local dt = date(2024, 12, 25, 9, 5, 30) -- Christmas morning

    --- Tests formatting with common specifiers.
    it("formats dates using common specifiers", function()
      expect(dt:fmt("%Y-%m-%d")).to.equal("2024-12-25") -- ISO Date
      expect(dt:fmt("%H:%M:%S")).to.equal("09:05:30") -- Time
      expect(dt:fmt("%a, %d %b %Y")).to.equal("Wed, 25 Dec 2024") -- Abbreviated
      expect(dt:fmt("%A, %B %d, %Y")).to.equal("Wednesday, December 25, 2024") -- Full
      expect(dt:fmt("%Y/%j")).to.equal("2024/360") -- Year/DayOfYear (2024 is leap)
    end)

    --- Tests formatting using custom groups like ${iso} and ${http}.
    it("formats dates using custom groups", function()
      expect(dt:fmt("${iso}")).to.equal("2024-12-25T09:05:30")
      -- Note: ${http} assumes UTC, convert first if needed
      local dt_utc = dt:copy():toutc()
      expect(dt_utc:fmt("${http}")).to.match("Wed, 25 Dec 2024 14:05:30 GMT") -- Expect UTC time
    end)
  end)

  --- Tests for ISO 8601 week date functions.
  --- @within examples.date_example
  describe("ISO Week Dates", function()
    local d1 = date(2024, 1, 1) -- Jan 1, 2024 (Monday, Week 1)
    local d2 = date(2023, 12, 31) -- Dec 31, 2023 (Sunday, Week 52 of 2023)
    local d3 = date(2026, 1, 1) -- Jan 1, 2026 (Thursday, Week 1 of 2026)

    --- Tests getting ISO components.
    it("gets ISO year, week, and weekday", function()
      local y1, w1, wd1 = d1:getisodate()
      expect(y1).to.equal(2024)
      expect(w1).to.equal(1)
      expect(wd1).to.equal(1) -- Monday

      local y2, w2, wd2 = d2:getisodate()
      expect(y2).to.equal(2023)
      expect(w2).to.equal(52)
      expect(wd2).to.equal(7) -- Sunday

      local y3, w3, wd3 = d3:getisodate()
      expect(y3).to.equal(2026)
      expect(w3).to.equal(1)
      expect(wd3).to.equal(4) -- Thursday
    end)

    --- Tests creating a date from ISO components.
    it("creates dates using date.isodate()", function()
      local iso_d1 = date.isodate(2024, 1, 1) -- 2024-W01-1
      expect(iso_d1).to.equal(d1)

      local iso_d2 = date.isodate(2023, 52, 7) -- 2023-W52-7
      expect(iso_d2).to.equal(d2)

      local iso_d3 = date.isodate(2026, 1, 4) -- 2026-W01-4
      expect(iso_d3).to.equal(d3)
    end)

    --- Tests setting date components using ISO values.
    it("sets dates using ISO components", function()
      local dt = date(2024, 1, 1)
      dt:setisoyear(2023, 52, 7) -- Set to 2023-W52-7
      expect(dt).to.equal(d2)
    end)
  end)

  --- Tests for time zone conversion (results may vary by system).
  --- @within examples.date_example
  describe("Time Zone Conversion", function()
    --- Tests converting UTC to local and back.
    it("converts between UTC and local time", function()
      local utc_dt = date(2024, 7, 4, 12, 0, 0, 0):toutc() -- Assume 12:00 local on July 4th -> convert to UTC
      local local_dt = utc_dt:copy():tolocal() -- Convert back to local

      logger.info("UTC Time: " .. utc_dt:fmt("${iso}"))
      logger.info("Local Time: " .. local_dt:fmt("${iso} %Z"))
      logger.info("Bias (minutes): " .. tostring(local_dt:getbias()))

      -- Basic check: the local hour should likely differ from the UTC hour (unless system is UTC)
      -- Cannot reliably assert specific offset due to system differences.
      expect(local_dt:gethours()).to.be.a("number")
    end)
  end)

  --- Tests utility functions.
  --- @within examples.date_example
  describe("Utility Functions", function()
    --- Tests date.isleapyear().
    it("checks for leap years using date.isleapyear()", function()
      expect(date.isleapyear(2024)).to.be_truthy()
      expect(date.isleapyear(2023)).to.be_falsy()
      expect(date.isleapyear(2000)).to.be_truthy()
      expect(date.isleapyear(1900)).to.be_falsy()
    end)

    --- Tests date.epoch().
    it("gets the OS epoch date using date.epoch()", function()
      local epoch = date.epoch()
      expect(epoch).to.exist()
      -- Common OS epoch is 1970-01-01 UTC
      expect(epoch:getyear()).to.equal(1970)
      expect(epoch:getmonth()).to.equal(1)
      expect(epoch:getday()).to.equal(1)
      -- Note: Time components might vary slightly based on OS/Lua time implementation details
    end)
  end)
end)
