# lib/tools/date Knowledge

## Purpose

The `lib/tools/date` module is a comprehensive and powerful date and time manipulation library for Lua, originally based on `date.lua` version 2.2.1 by Jas Latrix and Thijs Schreijer. It provides a rich set of functionalities for creating, parsing (including ISO 8601), formatting, comparing, calculating with, and converting date and time values, including handling of time zones. Within the Firmo framework, this module is essential for tasks requiring precise time management, such as timestamping logs, generating accurate report times, calculating test durations in the benchmark tool, or handling time-sensitive operations.

## Key Concepts

- **`DateObject`:** This is the central class representing a specific point in time. Instances are created via the `date()` constructor. While some methods modify the object in place (e.g., `tolocal()`, `toutc()`, `normalize()`), many manipulation methods (`add*`, `set*`) return the modified object itself, and comparison/arithmetic operations typically return new `DateObject` instances (e.g., `a - b` returns a duration `DateObject`). Use the `:copy()` method to ensure immutability when needed.

- **Internal Representation:** `DateObject`s internally store time using two numbers:
    - `daynum`: An integer representing the number of days since the epoch 0001-01-01 (proleptic Gregorian calendar).
    - `dayfrc`: An integer representing the fraction of the current day, measured in 'ticks'.
    The number of ticks per second is configurable using `date.ticks(t)`, with a default of 1,000,000 (microseconds), allowing for high precision. The `normalize()` method handles carry-over between `dayfrc` and `daynum`.

- **Constructors (`date()`):** The main `date()` function is highly versatile for creating `DateObject` instances:
    - `date()` or `date(false)`: Current local time.
    - `date(true)`: Current UTC time.
    - `date(number)`: Seconds since the OS epoch (usually 1970-01-01 00:00:00 UTC).
    - `date(string)`: Parses a date/time string (tries ISO 8601 first, then a flexible format).
    - `date(table)`: Uses an `os.date` style table (e.g., `{year=Y, month=M, day=D, ...}`).
    - `date(DateObject)`: Creates a copy of an existing `DateObject`.
    - `date(Y, M, D, [h], [m], [s], [t])`: Creates from numerical components (Year, Month, Day, Hour, Minute, Second, Ticks). Month can be number (1-12) or name/abbreviation.
    Additionally, `date.time(h, m, s, t)` creates a time-only object (date part is epoch default), and `date.isodate(Y, W, D)` creates from ISO week date components.

- **Parsing:** The string parser is robust, prioritizing ISO 8601 format (`YYYY-MM-DDTHH:MM:SSZ` or with offset `+/-hh:mm`) but also handling various common formats with different separators and component orders. `date.setcenturyflip(yy)` can configure how 2-digit years are interpreted (e.g., `date.setcenturyflip(70)` means years `< 70` become 20xx, `>= 70` become 19xx).

- **Formatting (`DateObject:fmt()`):** Provides flexible formatting similar to C's `strftime` or Lua's `os.date`, but with extensions. Common specifiers include `%Y` (year), `%m` (month), `%d` (day), `%H` (hour 24), `%M` (minute), `%S` (second). Notable extensions:
    - `%\f`: Seconds with fractional part (e.g., `15.123456`).
    - `%\b`: Year including "BCE" marker if applicable.
    - `%z`: Timezone offset from UTC (e.g., `+0100`, `-0500`).
    - Group formats like `${iso}` (`%Y-%m-%dT%T`), `${http}`, `${rfc1123}` simplify common standards.
    `date.fmt(str)` gets or sets the default format string used when `:fmt()` is called without arguments or when `tostring(dateObject)` is used.

- **Manipulation (`add*`, `set*`):** A suite of methods allows modifying date/time components: `addyears`, `addmonths`, `adddays`, `addhours`, `addminutes`, `addseconds`, `addticks`. Corresponding `set*` methods exist: `setyear`, `setmonth`, `setday`, `sethours`, `setminutes`, `setseconds`, `setticks`. ISO components can also be set/modified using `setisoyear`, `setisoweeknumber`, `setisoweekday`.

- **Calculations & Getters:** Methods are available to retrieve individual components (`getyear`, `getmonth`, `getday`, `gethours`, `getminutes`, `getseconds`, `getticks`, `getfracsec`). Others provide calendar information: `getweekday` (1=Sun), `getyearday` (1-366), `getisoweekday` (1=Mon), `getisoweeknumber`, `getisoyear`, `getisodate`. Total spans since the internal epoch (0001-01-01) can be retrieved using `spandays`, `spanhours`, `spanminutes`, `spanseconds`, `spanticks`.

- **Time Zone Handling:**
    - `DateObject:tolocal()`: Converts the date (assumed UTC) to the system's local time *in place*.
    - `DateObject:toutc()`: Converts the date (assumed local) to UTC *in place*.
    - `DateObject:getbias()`: Returns the local time zone offset from UTC in minutes for the date (assumed local).
    - `DateObject:gettzname()`: Returns the local time zone name (e.g., "EST").
    These rely on the underlying OS functions (`os.date`, `os.time`) and their accuracy/limitations, especially for dates far in the past or future.

- **Comparison & Arithmetic:** Standard comparison operators (`<`, `<=`, `==`) work as expected between `DateObject` instances. Subtraction (`d1 - d2`) returns a new `DateObject` representing the duration. Addition (`d1 + duration`) also returns a new `DateObject`.

- **Configuration & Limits:** `date.daynummin()` and `date.daynummax()` get or set the valid range for the internal `daynum`, preventing calculations from going too far into the past or future (defaults allow a very wide range).

## Usage Examples / Patterns

### Pattern 1: Creating Date Objects

```lua
--[[
  Demonstrates various ways to create date objects.
]]
local date = require("lib.tools.date")

-- Current local time
local now_local = date()
print("Local:", now_local)

-- Current UTC time
local now_utc = date(true)
print("UTC:", now_utc)

-- From seconds since OS epoch (e.g., from os.time())
local epoch_sec = os.time()
local d_from_sec = date(epoch_sec)
print("From Seconds:", d_from_sec)

-- From an ISO 8601 string (UTC)
local d_iso = date("2024-04-24T15:30:00.123Z")
print("ISO:", d_iso)

-- From numerical components (Year, Month, Day, Hour, Minute)
local d_comp = date(2024, 4, 24, 15, 30) -- Month is 1-based
print("Components:", d_comp)

-- From numerical components including fractional seconds via ticks
-- (assuming 1,000,000 ticks/sec)
local d_ticks = date(2024, 4, 24, 15, 30, 5, 500000) -- 15:30:05.500000
print("With Ticks:", d_ticks)
```

### Pattern 2: Formatting Dates

```lua
--[[
  Showcasing different formatting options.
]]
local date = require("lib.tools.date")
local d = date(2024, 12, 25, 9, 5, 30, 123456)

-- Common format
print(d:fmt("%Y/%m/%d %H:%M:%S")) -- Output: 2024/12/25 09:05:30

-- Include fractional seconds using %\f
print(d:fmt("%Y-%m-%d %H:%M:%\f")) -- Output: 2024-12-25 09:05:30.123456

-- Default format (can be changed via date.fmt(new_default))
print(tostring(d))

-- ISO standard group format
print(d:fmt("${iso}")) -- Output: 2024-12-25T09:05:30

-- Get timezone offset (assumes 'd' is local time)
-- print(d:fmt("%z"))
```

### Pattern 3: Manipulation and Copying

```lua
--[[
  Adding time and modifying components.
]]
local date = require("lib.tools.date")
local d1 = date(2024, 1, 31)

-- Add 7 days
d1:adddays(7)
print("After 7 days:", d1:fmt("%Y-%m-%d")) -- Output: 2024-02-07

-- Add 1 month (correctly handles end of month)
local d_next_month = d1:copy():addmonths(1)
print("Next month:", d_next_month:fmt("%Y-%m-%d")) -- Output: 2024-03-07

-- Set the year (returns self)
d1:setyear(2025)
print("Year set:", d1:fmt("%Y-%m-%d")) -- Output: 2025-02-07
```

### Pattern 4: Comparison and Duration

```lua
--[[
  Comparing dates and calculating differences.
]]
local date = require("lib.tools.date")
local start_time = date()

-- Simulate some work
os.execute("sleep 1.5") -- Platform dependent, just for example

local end_time = date()

if start_time < end_time then
  print("End is after start.")
end

-- Calculate duration
local duration = end_time - start_time -- Returns a duration DateObject
print("Duration (total seconds):", duration:spanseconds()) -- e.g., 1.5xxxxxx
print("Duration (total ticks):", duration:spanticks())

-- Extract components from duration (relative to epoch 0001-01-01)
print("Duration components:", duration:gethours(), duration:getminutes(), duration:getfracsec())
```

### Pattern 5: Time Zone Conversion

```lua
--[[
  Converting between local time and UTC.
]]
local date = require("lib.tools.date")

local utc_now = date(true)
print("UTC Now:", utc_now)

-- Convert UTC to local time (modifies utc_now IN PLACE)
utc_now:tolocal()
print("Local Time:", utc_now)
print("TZ Name:", utc_now:gettzname())
print("Bias (min):", utc_now:getbias())

-- Convert back to UTC (modifies utc_now IN PLACE)
utc_now:toutc()
print("Back to UTC:", utc_now)
```

## Related Components / Modules

- **`lib/tools/date/init.lua`**: The source code implementation of this module.
- **`lib/tools/logging/knowledge.md`**: The logging module likely uses `lib/tools/date` for timestamping log entries.
- **`lib/reporting/knowledge.md`**: Reporting modules may use `lib/tools/date` to record test execution times or report generation timestamps.
- **`lib/tools/benchmark/knowledge.md`**: The benchmark module uses high-resolution timing, potentially leveraging or complementing this module for measuring durations.

## Best Practices / Critical Rules (Optional)

- **Prefer ISO 8601:** For exchanging date/time information as strings (e.g., in logs, configuration, APIs), use the ISO 8601 format (`YYYY-MM-DDTHH:MM:SSZ` or `YYYY-MM-DDTHH:MM:SS+hh:mm`) for maximum clarity and reliability in parsing.
- **Beware In-Place Modification:** Methods like `tolocal()`, `toutc()`, and `normalize()` modify the `DateObject` instance directly. If you need to preserve the original value, use `:copy()` before calling these methods (e.g., `local local_copy = utc_date:copy():tolocal()`). Most `add*` and `set*` methods also return `self`, allowing chaining, but they modify the object in place.
- **UTC for Storage:** When storing timestamps or performing calculations across different time zones, it's generally best practice to work with UTC (`date(true)`, dates parsed with `Z` or offset) and convert to local time only for display purposes.

## Troubleshooting / Common Pitfalls (Optional)

- **String Parsing Failures:** If `date("some string")` fails, ensure the string format is reasonably standard. ISO 8601 is the most reliable. Check for ambiguous formats (e.g., `01/02/03` could be M/D/Y or D/M/Y depending on locale assumptions the parser might make, although ISO is preferred). Use explicit components `date(Y,M,D,...)` if unsure.
- **Time Zone Issues:** Time zone conversions (`tolocal`, `toutc`, `getbias`, `gettzname`) depend heavily on the underlying operating system's C library functions (`localtime`, `gmtime`, `mktime`). Accuracy, especially for historical dates or future DST changes, relies on the OS having up-to-date timezone information. Behavior might differ slightly across OSes.
- **Performance:** While powerful, creating and manipulating many `DateObject` instances in very tight loops might incur performance overhead compared to raw `os.time()` or `os.clock()` if only simple timing is needed. However, for complex date math, parsing, or formatting, this module is generally preferred.
