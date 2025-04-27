--- Date and Time Calculations Module (date.lua v2.2.1)
---
--- Provides comprehensive date and time manipulation, parsing, formatting,
--- and calculations, including time zone handling and ISO 8601 support.
--- Based on date.lua by Jas Latrix and Thijs Schreijer.
---
--- @module lib.tools.date
--- @version 2.2.1
--- @copyright (C) 2005-2006, by Jas Latrix (jastejada@yahoo.com)
--- @copyright (C) 2013-2021, by Thijs Schreijer
--- @license MIT (http://opensource.org/licenses/MIT)

--[[ CONSTANTS ]]
--
local HOURPERDAY = 24
local MINPERHOUR = 60
local MINPERDAY = 1440 -- 24*60
local SECPERMIN = 60
local SECPERHOUR = 3600 -- 60*60
local SECPERDAY = 86400 -- 24*60*60
local TICKSPERSEC = 1000000
local TICKSPERDAY = 86400000000
local TICKSPERHOUR = 3600000000
local TICKSPERMIN = 60000000
local DAYNUM_MAX = 365242500 -- Sat Jan 01 1000000 00:00:00
local DAYNUM_MIN = -365242500 -- Mon Jan 01 1000000 BCE 00:00:00
local DAYNUM_DEF = 0 -- Mon Jan 01 0001 00:00:00
local _
--[[ GLOBAL SETTINGS ]]
--
local centuryflip = 0 -- year >= centuryflip == 1900, < centuryflip == 2000
--[[ LOCAL ARE FASTER ]]
--
local type = type
local pairs = pairs
local error = error
local assert = assert
local tonumber = tonumber
local tostring = tostring
local string = string
local math = math
local os = os
local unpack = unpack or table.unpack
local setmetatable = setmetatable
local getmetatable = getmetatable
--[[ EXTRA FUNCTIONS ]]
--
local fmt = string.format
local lwr = string.lower
local rep = string.rep
local len = string.len -- luacheck: ignore
local sub = string.sub
local gsub = string.gsub
local gmatch = string.gmatch or string.gfind
local find = string.find
local ostime = os.time
local osdate = os.date
local floor = math.floor
local ceil = math.ceil
local abs = math.abs
--- Truncates a number towards zero (like `math.trunc`).
---@param n number Input number.
---@return number Integer part of n, or nil if input not a number.
---@private
local function fix(n)
  n = tonumber(n)
  return n and ((n > 0 and floor or ceil)(n))
end
--- Returns the modulo n % d.
---@param n number Dividend.
---@param d number Divisor.
---@return number The result of `n mod d`.
---@private
local function mod(n, d)
  return n - d * floor(n / d)
end
--- Checks if `str` (case-insensitive prefix) is in string list `tbl`.
---@param str string String to search for.
---@param tbl table Table where keys are indices and values are strings to check against.
---@param ml? number Minimum length `str` must have (default 0).
---@param tn? table Optional output table; `tn[0]` will be set to the *key* (not value) of the matched string in `tbl`.
---@return number|nil Key of the matched entry in `tbl`, or nil if no match found.
---@private
local function inlist(str, tbl, ml, tn)
  local sl = len(str)
  if sl < (ml or 0) then
    return nil
  end
  str = lwr(str)
  for k, v in pairs(tbl) do
    if str == lwr(sub(v, 1, sl)) then
      if tn then
        tn[0] = k
      end
      return k
    end
  end
end
--- No-operation function.
---@private
local function fnil() end
--[[ DATE FUNCTIONS ]]
--
local DATE_EPOCH -- to be set later
local sl_weekdays = {
  [0] = "Sunday",
  [1] = "Monday",
  [2] = "Tuesday",
  [3] = "Wednesday",
  [4] = "Thursday",
  [5] = "Friday",
  [6] = "Saturday",
  [7] = "Sun",
  [8] = "Mon",
  [9] = "Tue",
  [10] = "Wed",
  [11] = "Thu",
  [12] = "Fri",
  [13] = "Sat",
}
local sl_meridian = { [-1] = "AM", [1] = "PM" }
local sl_months = {
  [00] = "January",
  [01] = "February",
  [02] = "March",
  [03] = "April",
  [04] = "May",
  [05] = "June",
  [06] = "July",
  [07] = "August",
  [08] = "September",
  [09] = "October",
  [10] = "November",
  [11] = "December",
  [12] = "Jan",
  [13] = "Feb",
  [14] = "Mar",
  [15] = "Apr",
  [16] = "May",
  [17] = "Jun",
  [18] = "Jul",
  [19] = "Aug",
  [20] = "Sep",
  [21] = "Oct",
  [22] = "Nov",
  [23] = "Dec",
}
-- added the '.2'  to avoid collision, use `fix` to remove
local sl_timezone = {
  [000] = "utc",
  [0.2] = "gmt",
  [300] = "est",
  [240] = "edt",
  [360] = "cst",
  [300.2] = "cdt",
  [420] = "mst",
  [360.2] = "mdt",
  [480] = "pst",
  [420.2] = "pdt",
}
--- Sets the number of 'ticks' per second used for internal time representation.
--- Updates related constants (TICKS_PER_DAY, etc.). Default is 1,000,000 (microseconds).
---@param t number The number of ticks per second.
---@return nil
---@private
local function setticks(t)
  TICKSPERSEC = t
  TICKSPERDAY = SECPERDAY * TICKSPERSEC
  TICKSPERHOUR = SECPERHOUR * TICKSPERSEC
  TICKSPERMIN = SECPERMIN * TICKSPERSEC
end
--- Checks if a given year is a leap year in the Gregorian calendar.
---@param y integer The year (must be an integer).
---@return boolean `true` if `y` is a leap year, `false` otherwise.
---@private
local function isleapyear(y) -- y must be int!
  return (mod(y, 4) == 0 and (mod(y, 100) ~= 0 or mod(y, 400) == 0))
end
--- Calculates the number of days from 0000-03-01 (proleptic Gregorian) to YYYY-03-01.
---@param y integer The year (must be an integer).
---@return integer The number of days.
---@private
local function dayfromyear(y) -- y must be int!
  return 365 * y + floor(y / 4) - floor(y / 100) + floor(y / 400)
end
--- Calculates the internal day number (days since 0001-01-01) from year, month, day.
---@param y integer Year.
---@param m integer Month (0-based, January = 0).
---@param d integer Day (1-based).
---@return integer The calculated day number.
---@private
local function makedaynum(y, m, d)
  local mm = mod(mod(m, 12) + 10, 12)
  return dayfromyear(y + floor(m / 12) - floor(mm / 10)) + floor((mm * 306 + 5) / 10) + d - 307
  --local yy = y + floor(m/12) - floor(mm/10)
  --return dayfromyear(yy) + floor((mm*306 + 5)/10) + (d - 1)
end
--- Converts an internal day number back into year, month (0-based), day.
---@param g integer The day number (days since 0001-01-01).
---@return integer y Year.
---@return integer m Month (0-based, January = 0).
---@return integer d Day (1-based).
---@private
local function breakdaynum(g)
  local g = g + 306
  local y = floor((10000 * g + 14780) / 3652425)
  local d = g - dayfromyear(y)
  if d < 0 then
    y = y - 1
    d = g - dayfromyear(y)
  end
  local mi = floor((100 * d + 52) / 3060)
  return (floor((mi + 2) / 12) + y), mod(mi + 2, 12), (d - floor((mi * 306 + 5) / 10) + 1)
end
--[[ for floats or int32 Lua Number data type
  local function breakdaynum2(g)
    local g, n = g + 306;
    local n400 = floor(g/DI400Y);n = mod(g,DI400Y);
    local n100 = floor(n/DI100Y);n = mod(n,DI100Y);
    local n004 = floor(n/DI4Y);   n = mod(n,DI4Y);
    local n001 = floor(n/365);   n = mod(n,365);
    local y = (n400*400) + (n100*100) + (n004*4) + n001  - ((n001 == 4 or n100 == 4) and 1 or 0)
    local d = g - dayfromyear(y)
    local mi = floor((100*d + 52)/3060)
    return (floor((mi + 2)/12) + y), mod(mi + 2,12), (d - floor((mi*306 + 5)/10) + 1)
  end
  ]]
--- Calculates the internal day fraction (in ticks) from hour, minute, second, ticks.
---@param h number Hour (0-23).
---@param r number Minute (0-59).
---@param s number Second (0-59).
---@param t number Ticks (0-TICKSPERSEC-1).
---@return number The calculated day fraction in ticks.
---@private
local function makedayfrc(h, r, s, t)
  return ((h * 60 + r) * 60 + s) * TICKSPERSEC + t
end
--- Converts an internal day fraction (in ticks) back into hour, minute, second, ticks.
---@param df number The day fraction in ticks.
---@return number h Hour (0-23).
---@return number r Minute (0-59).
---@return number s Second (0-59).
---@return number t Ticks (0-TICKSPERSEC-1).
---@private
local function breakdayfrc(df)
  return mod(floor(df / TICKSPERHOUR), HOURPERDAY),
    mod(floor(df / TICKSPERMIN), MINPERHOUR),
    mod(floor(df / TICKSPERSEC), SECPERMIN),
    mod(df, TICKSPERSEC)
end
--- Calculates the weekday (0=Sunday, 1=Monday, ..., 6=Saturday) from the internal day number.
---@param dn integer The day number.
---@return integer Weekday (0-6).
---@private
local function weekday(dn)
  return mod(dn + 1, 7)
end
--- Calculates the day of the year (0-based, Jan 1st = 0) from the internal day number.
---@param dn integer The day number.
---@return integer Day of the year (0-365).
---@private
local function yearday(dn)
  return dn - dayfromyear((breakdaynum(dn)) - 1)
end
--- Parses a value as a month, accepting month number (1-12) or name/abbreviation.
---@param v number|string The value to parse.
---@return integer|nil month The month number (0-based, Jan=0), or nil if unparseable.
---@private
local function getmontharg(v)
  local m = tonumber(v)
  return (m and fix(m - 1)) or inlist(tostring(v) or "", sl_months, 2)
end
--- Calculates the internal day number of the first day (Monday) of ISO week 1 of year `y`.
---@param y integer The year.
---@return integer The day number of the start of ISO week 1.
---@private
local function isow1(y)
  local f = makedaynum(y, 0, 4) -- get the date for the 4-Jan of year `y`
  local d = weekday(f)
  d = d == 0 and 7 or d -- get the ISO day number, 1 == Monday, 7 == Sunday
  return f + (1 - d)
end
--- Calculates the ISO week number (1-53) and ISO week-numbering year for a given day number.
---@param dn integer The day number.
---@return integer week The ISO week number.
---@return integer year The ISO week-numbering year.
---@private
local function isowy(dn)
  local w1
  local y = (breakdaynum(dn))
  if dn >= makedaynum(y, 11, 29) then
    w1 = isow1(y + 1)
    if dn < w1 then
      w1 = isow1(y)
    else
      y = y + 1
    end
  else
    w1 = isow1(y)
    if dn < w1 then
      w1 = isow1(y - 1)
      y = y - 1
    end
  end
  return floor((dn - w1) / 7) + 1, y
end
--- Calculates the ISO week-numbering year for a given day number.
---@param dn integer The day number.
---@return integer year The ISO week-numbering year.
---@private
local function isoy(dn)
  local y = (breakdaynum(dn))
  return y + (((dn >= makedaynum(y, 11, 29)) and (dn >= isow1(y + 1))) and 1 or (dn < isow1(y) and -1 or 0))
end
--- Calculates the internal day number from ISO year, week number, and weekday.
---@param y integer ISO year.
---@param w integer ISO week number (1-53).
---@param d integer ISO weekday (1=Monday, 7=Sunday).
---@return integer The calculated day number.
---@private
local function makedaynum_isoywd(y, w, d)
  return isow1(y) + 7 * w + d - 8 -- simplified: isow1(y) + ((w-1)*7) + (d-1)
end
--[[ THE DATE MODULE ]]
--
---@class DateModule The main date module and constructor.
--- Use `date()` to create new DateObject instances.
--- Provides utility functions and configuration settings.
---@field version number Module version (e.g., 20020001 for 2.2.1).
---@field time fun(h?: number, r?: number, s?: number, t?: number): DateObject Creates a DateObject representing only time (date part is epoch default). Throws error on invalid args.
---@field diff fun(a: DateObject|number|string|table|boolean, b: DateObject|number|string|table|boolean): DateObject Calculates the difference between two dates. Throws error on invalid args.
---@field isleapyear fun(v: number|DateObject|string|table|boolean): boolean Checks if the year of the given value is a leap year. Returns false on invalid input.
---@field epoch fun(): DateObject Returns a copy of the date representing the OS epoch (usually 1970-01-01 00:00:00 UTC). Throws error if epoch detection failed.
---@field isodate fun(y: number, w?: number, d?: number): DateObject Creates a DateObject from ISO year, week, day. Throws error on invalid args.
---@field setcenturyflip fun(y: number): nil Sets the century flip year (0-99) for 2-digit year parsing. Throws error on invalid args.
---@field getcenturyflip fun(): number Gets the current century flip year.
---@field fmt fun(str?: string): string Gets or sets the default format string used by `DateObject:fmt()` and `tostring()`.
---@field daynummin fun(n?: number): number|DateObject Gets or sets the minimum allowed internal day number. Returns number if setting, DateObject if getting.
---@field daynummax fun(n?: number): number|DateObject Gets or sets the maximum allowed internal day number. Returns number if setting, DateObject if getting.
---@field ticks fun(t?: number): number Gets or sets the number of ticks per second (default 1,000,000).
---@field __call fun(self: DateModule, arg1?: number|string|table|boolean, ...): DateObject Constructor. Parses various inputs (number=seconds since OS epoch, string=parsable date, table=os.date like, boolean=current UTC/local time, y,m,d,h,m,s,t numbers). Returns new DateObject. Throws error on invalid input.
local fmtstr = "%x %X"
--#if not DATE_OBJECT_AFX then
local date = {}
setmetatable(date, date)
-- Version:  VMMMRRRR; V-Major, M-Minor, R-Revision;  e.g. 5.45.321 == 50450321
do
  local major = 2
  local minor = 2
  local revision = 1
  date.version = major * 10000000 + minor * 10000 + revision
end
--#end -- not DATE_OBJECT_AFX
--[[ THE DATE OBJECT ]]
--
---@class DateObject Represents a specific date and time.
--- Instances are created using the `date()` constructor function.
---@field daynum integer Internal representation: number of days since 0001-01-01 (Gregorian).
---@field dayfrc integer Internal representation: fraction of the day in 'ticks' (microseconds by default).
---@field normalize fun(self: DateObject): DateObject Normalizes internal representation after changes. Throws error if date is outside limits.
---@field getdate fun(self: DateObject): number, number, number Returns year, month (1-12), day (1-31).
---@field gettime fun(self: DateObject): number, number, number, number Returns hour (0-23), minute (0-59), second (0-59), ticks (0-999999).
---@field getclockhour fun(self: DateObject): number Returns hour in 12-hour format (1-12).
---@field getyearday fun(self: DateObject): number Returns day of the year (1-366).
---@field getweekday fun(self: DateObject): number Returns day of the week (Lua format: 1=Sunday, 7=Saturday).
---@field getyear fun(self: DateObject): number Returns the year.
---@field getmonth fun(self: DateObject): number Returns the month (1-12).
---@field getday fun(self: DateObject): number Returns the day of the month (1-31).
---@field gethours fun(self: DateObject): number Returns the hour (0-23).
---@field getminutes fun(self: DateObject): number Returns the minute (0-59).
---@field getseconds fun(self: DateObject): number Returns the second (0-59).
---@field getfracsec fun(self: DateObject): number Returns seconds including the fractional part (e.g., 59.123456).
---@field getticks fun(self: DateObject, u?: number): number Returns the ticks part of the time (0-999999). Optionally scales to `u` units per second.
---@field getweeknumber fun(self: DateObject, wdb?: number): number Calculates week number (Sunday start default 00-53). `wdb` sets first day of week (1=Sun, 2=Mon...).
---@field getisoweekday fun(self: DateObject): number Returns ISO 8601 weekday (1=Monday, 7=Sunday).
---@field getisoweeknumber fun(self: DateObject): number Returns ISO 8601 week number (01-53).
---@field getisoyear fun(self: DateObject): number Returns ISO 8601 week-numbering year.
---@field getisodate fun(self: DateObject): number, number, number Returns ISO year, ISO week number, ISO weekday.
---@field setisoyear fun(self: DateObject, y?: number, w?: number, d?: number): DateObject Sets date using ISO year, week, day. Throws error on invalid args.
---@field setisoweekday fun(self: DateObject, d: number): DateObject Sets ISO weekday. Throws error on invalid args.
---@field setisoweeknumber fun(self: DateObject, w: number, d?: number): DateObject Sets ISO week number (and optionally day). Throws error on invalid args.
---@field setyear fun(self: DateObject, y?: number, m?: number|string, d?: number): DateObject Sets year, month, day. Throws error on invalid args.
---@field setmonth fun(self: DateObject, m: number|string, d?: number): DateObject Sets month (and optionally day). Throws error on invalid args.
---@field setday fun(self: DateObject, d: number): DateObject Sets day of month. Throws error on invalid args.
---@field sethours fun(self: DateObject, h?: number, m?: number, s?: number, t?: number): DateObject Sets hour, minute, second, ticks. Throws error on invalid args.
---@field setminutes fun(self: DateObject, m?: number, s?: number, t?: number): DateObject Sets minute (and optionally second, ticks). Throws error on invalid args.
---@field setseconds fun(self: DateObject, s?: number, t?: number): DateObject Sets second (and optionally ticks). Throws error on invalid args.
---@field setticks fun(self: DateObject, t?: number): DateObject Sets ticks. Throws error on invalid args.
---@field spanticks fun(self: DateObject): number Returns total ticks since epoch 0001-01-01.
---@field spanseconds fun(self: DateObject): number Returns total seconds since epoch 0001-01-01.
---@field spanminutes fun(self: DateObject): number Returns total minutes since epoch 0001-01-01.
---@field spanhours fun(self: DateObject): number Returns total hours since epoch 0001-01-01.
---@field spandays fun(self: DateObject): number Returns total days since epoch 0001-01-01 (can have fractional part).
---@field addyears fun(self: DateObject, y?: number, m?: number, d?: number): DateObject Adds years, months, days. Throws error on invalid args.
---@field addmonths fun(self: DateObject, m?: number, d?: number): DateObject Adds months (and optionally days). Throws error on invalid args.
---@field adddays fun(self: DateObject, n: number): DateObject Adds days. Throws error on invalid args.
---@field addhours fun(self: DateObject, n: number): DateObject Adds hours. Throws error on invalid args.
---@field addminutes fun(self: DateObject, n: number): DateObject Adds minutes. Throws error on invalid args.
---@field addseconds fun(self: DateObject, n: number): DateObject Adds seconds. Throws error on invalid args.
---@field addticks fun(self: DateObject, n: number): DateObject Adds ticks. Throws error on invalid args.
---@field fmt fun(self: DateObject, str?: string): string Formats the date/time according to `str` (similar to C `strftime` and os.date). Uses default format if `str` omitted.
---@field copy fun(self: DateObject): DateObject Returns a new copy of the DateObject.
---@field tolocal fun(self: DateObject): DateObject Converts the date (assumed UTC) to local time. Returns self. Throws error if conversion fails.
---@field toutc fun(self: DateObject): DateObject Converts the date (assumed local) to UTC time. Returns self. Throws error if conversion fails.
---@field getbias fun(self: DateObject): number Returns local time zone offset from UTC in minutes. Throws error if conversion fails.
---@field gettzname fun(self: DateObject): string Returns local time zone name (e.g., "EST"). Returns "" on error.
local dobj = {}
dobj.__index = dobj
dobj.__metatable = dobj
-- shout invalid arg
--- Throws a standard "invalid argument(s)" error.
---@private
---@throws string Always throws an error.
local function date_error_arg()
  return error("invalid argument(s)", 0)
end
--- Creates a new DateObject instance with given internal values.
---@param dn integer Day number.
---@param df integer Day fraction (ticks).
---@return DateObject The new instance.
---@private
local function date_new(dn, df)
  return setmetatable({ daynum = dn, dayfrc = df }, dobj)
end

--#if not NO_LOCAL_TIME_SUPPORT then
-- magic year table
local date_epoch, yt
--- Calculates a 'magic' equivalent year for handling OS date/time limits.
--- Builds a cache `yt` mapping weekday/leap year combinations to a working year.
---@param y integer The original year.
---@return integer The equivalent year from the cache.
---@private
local function getequivyear(y)
  assert(not yt)
  yt = {}
  local de = date_epoch:copy()
  local dw, dy
  for _ = 0, 3000 do
    de:setyear(de:getyear() + 1, 1, 1)
    dy = de:getyear()
    dw = de:getweekday() * (isleapyear(dy) and -1 or 1)
    if not yt[dw] then
      yt[dw] = dy
    end --print(de)
    if
      yt[1]
      and yt[2]
      and yt[3]
      and yt[4]
      and yt[5]
      and yt[6]
      and yt[7]
      and yt[-1]
      and yt[-2]
      and yt[-3]
      and yt[-4]
      and yt[-5]
      and yt[-6]
      and yt[-7]
    then
      getequivyear = function(y)
        return yt[(weekday(makedaynum(y, 0, 1)) + 1) * (isleapyear(y) and -1 or 1)]
      end
      return getequivyear(y)
    end
  end
end
-- TimeValue from date and time
--- Converts year, month, day, hour, minute, second to OS time value (seconds since OS epoch).
---@param y integer Year.
---@param m integer Month (0-based).
---@param d integer Day.
---@param h integer Hour.
---@param r integer Minute.
---@param s integer Second.
---@return number Time value (seconds since epoch).
---@private
local function totv(y, m, d, h, r, s)
  return (makedaynum(y, m, d) - DATE_EPOCH) * SECPERDAY + ((h * 60 + r) * 60 + s)
end
-- TimeValue from TimeTable
--- Converts an `os.date` style time table to OS time value.
---@param tm table Time table with `year`, `month` (1-based), `day`, `hour`, `min`, `sec`.
---@return number Time value (seconds since epoch).
---@private
local function tmtotv(tm)
  return tm and totv(tm.year, tm.month - 1, tm.day, tm.hour, tm.min, tm.sec)
end
-- Returns the bias in seconds of utc time daynum and dayfrc
--- Calculates the local time zone bias (offset from UTC) in seconds for a given UTC DateObject.
---@param self DateObject The date object (assumed to be in UTC).
---@return number bias Bias in seconds (UTC = local + bias).
---@return number tvu Original time value (UTC seconds since OS epoch).
---@return number tvl Calculated local time value (seconds since OS epoch).
---@throws string If bias calculation fails (e.g., `os.date` fails).
---@private
local function getbiasutc2(self)
  local y, m, d = breakdaynum(self.daynum)
  local h, r, s = breakdayfrc(self.dayfrc)
  local tvu = totv(y, m, d, h, r, s) -- get the utc TimeValue of date and time
  local tml = osdate("*t", tvu) -- get the local TimeTable of tvu
  if (not tml) or (tml.year > (y + 1) or tml.year < (y - 1)) then -- failed try the magic
    y = getequivyear(y)
    tvu = totv(y, m, d, h, r, s)
    tml = osdate("*t", tvu)
  end
  local tvl = tmtotv(tml)
  if tvu and tvl then
    return tvu - tvl, tvu, tvl
  else
    return error("failed to get bias from utc time")
  end
end
-- Returns the bias in seconds of local time daynum and dayfrc
--- Calculates the local time zone bias (offset from UTC) in seconds for given local date/time components.
---@param daynum integer Internal day number (local time).
---@param dayfrc integer Internal day fraction (local time).
---@return number bias Bias in seconds (UTC = local + bias).
---@return number tvu Calculated UTC time value (seconds since OS epoch).
---@return number tvl Original local time value (seconds since OS epoch).
---@throws string If bias calculation fails (e.g., `os.time` fails).
---@private
local function getbiasloc2(daynum, dayfrc)
  local tvu
  -- extract date and time
  local y, m, d = breakdaynum(daynum)
  local h, r, s = breakdayfrc(dayfrc)
  -- get equivalent TimeTable
  local tml = { year = y, month = m + 1, day = d, hour = h, min = r, sec = s }
  -- get equivalent TimeValue
  local tvl = tmtotv(tml)

  local function chkutc()
    tml.isdst = nil
    local tvug = ostime(tml)
    if tvug and (tvl == tmtotv(osdate("*t", tvug))) then
      tvu = tvug
      return
    end
    tml.isdst = true
    local tvud = ostime(tml)
    if tvud and (tvl == tmtotv(osdate("*t", tvud))) then
      tvu = tvud
      return
    end
    tvu = tvud or tvug
  end
  chkutc()
  if not tvu then
    tml.year = getequivyear(y)
    tvl = tmtotv(tml)
    chkutc()
  end
  return ((tvu and tvl) and (tvu - tvl)) or error("failed to get bias from local time"), tvu, tvl
end
--#end -- not NO_LOCAL_TIME_SUPPORT

--#if not DATE_OBJECT_AFX then
--- String walker helper class for parsing date strings.
---@class strwalker
---@field s string The string being walked.
---@field i number Current position index.
---@field e number Position index before the last successful match.
---@field c number Length of the string `s`.
---@field __index strwalker
---@private
local strwalker = {} -- ^Lua regular expression is not as powerful as Perl$
strwalker.__index = strwalker
--- Creates a new string walker instance.
---@param s string The string to walk.
---@return strwalker The new instance.
---@private
local function newstrwalker(s)
  return setmetatable({ s = s, i = 1, e = 1, c = len(s) }, strwalker)
end
--- Debug helper: returns string with '^' pointing to current error position. @private
function strwalker:aimchr()
  return "\n" .. self.s .. "\n" .. rep(".", self.e - 1) .. "^"
end
--- Checks if the walker has reached the end of the string. @return boolean @private
function strwalker:finish()
  return self.i > self.c
end
--- Moves the current position `i` back to the position `e` before the last match. @return self @private
function strwalker:back()
  self.i = self.e
  return self
end
--- Resets the walker to the beginning of the string. @return self @private
function strwalker:restart()
  self.i, self.e = 1, 1
  return self
end
--- Checks if pattern `s` matches at the current position `i`. @param s string Pattern. @return any Matches from `string.find`. @private
function strwalker:match(s)
  return (find(self.s, s, self.i))
end
--- Attempts to match pattern `s` from current position. Advances position on match.
---@param s string Pattern to match.
---@param f? function Optional function to call with captures on match.
---@return self|nil Returns self on match, nil otherwise.
---@private
function strwalker:__call(s, f) -- print("strwalker:__call "..s..self:aimchr())
  local is, ie
  is, ie, self[1], self[2], self[3], self[4], self[5] = find(self.s, s, self.i)
  if is then
    self.e, self.i = self.i, 1 + ie
    if f then
      f(unpack(self))
    end
    return self
  end
end
--- Parses a date/time string into a DateObject.
--- Attempts ISO 8601 format first, then falls back to a more flexible parser.
---@param str string The date/time string to parse.
---@return DateObject The parsed date object.
---@throws string If the string cannot be parsed as a valid date/time.
---@private
local function date_parse(str)
  local y, m, d, h, r, s, z, w, u, j, e, x, c, dn, df
  local sw = newstrwalker(gsub(gsub(str, "(%b())", ""), "^(%s*)", "")) -- remove comment, trim leading space
  --local function error_out() print(y,m,d,h,r,s) end
  local function error_dup(q) --[[error_out()]]
    error("duplicate value: " .. (q or "") .. sw:aimchr())
  end
  local function error_syn(q) --[[error_out()]]
    error("syntax error: " .. (q or "") .. sw:aimchr())
  end
  local function error_inv(q) --[[error_out()]]
    error("invalid date: " .. (q or "") .. sw:aimchr())
  end
  local function sety(q)
    y = y and error_dup() or tonumber(q)
  end
  local function setm(q)
    m = (m or w or j) and error_dup(m or w or j) or tonumber(q)
  end
  local function setd(q)
    d = d and error_dup() or tonumber(q)
  end
  local function seth(q)
    h = h and error_dup() or tonumber(q)
  end
  local function setr(q)
    r = r and error_dup() or tonumber(q)
  end
  local function sets(q)
    s = s and error_dup() or tonumber(q)
  end
  local function adds(q)
    s = s + tonumber("." .. string.sub(q, 2, -1))
  end
  local function setj(q)
    j = (m or w or j) and error_dup() or tonumber(q)
  end
  local function setz(q)
    z = (z ~= 0 and z) and error_dup() or q
  end
  local function setzn(zs, zn)
    zn = tonumber(zn)
    setz(((zn < 24) and (zn * 60) or (mod(zn, 100) + floor(zn / 100) * 60)) * (zs == "+" and -1 or 1))
  end
  local function setzc(zs, zh, zm)
    setz(((tonumber(zh) * 60) + tonumber(zm)) * (zs == "+" and -1 or 1))
  end

  if
    not (
      sw("^(%d%d%d%d)", sety)
      and (sw("^(%-?)(%d%d)%1(%d%d)", function(_, a, b)
        setm(tonumber(a))
        setd(tonumber(b))
      end) or sw("^(%-?)[Ww](%d%d)%1(%d?)", function(_, a, b)
        w, u = tonumber(a), tonumber(b or 1)
      end) or sw("^%-?(%d%d%d)", setj) or sw("^%-?(%d%d)", function(a)
        setm(a)
        setd(1)
      end))
      and (
        (
          sw("^%s*[Tt]?(%d%d):?", seth)
          and sw("^(%d%d):?", setr)
          and sw("^(%d%d)", sets)
          and sw("^([,%.]%d+)", adds)
          and sw("%s*([+-])(%d%d):?(%d%d)%s*$", setzc)
        )
        or sw:finish()
        or (
          sw("^%s*$")
          or sw("^%s*[Zz]%s*$")
          or sw("^%s-([%+%-])(%d%d):?(%d%d)%s*$", setzc)
          or sw("^%s*([%+%-])(%d%d)%s*$", setzn)
        )
      )
    )
  then --print(y,m,d,h,r,s,z,w,u,j)
    sw:restart()
    y, m, d, h, r, s, z, w, u, j = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    repeat -- print(sw:aimchr())
      if sw("^[tT:]?%s*(%d%d?):", seth) then --print("$Time")
        _ = sw("^%s*(%d%d?)", setr) and sw("^%s*:%s*(%d%d?)", sets) and sw("^([,%.]%d+)", adds)
      elseif sw("^(%d+)[/\\%s,-]?%s*") then --print("$Digits")
        x, c = tonumber(sw[1]), len(sw[1])
        if (x >= 70) or (m and d and not y) or (c > 3) then
          sety(x + ((x >= 100 or c > 3) and 0 or x < centuryflip and 2000 or 1900))
        else
          if m then
            setd(x)
          else
            m = x
          end
        end
      elseif sw("^(%a+)[/\\%s,-]?%s*") then --print("$Words")
        x = sw[1]
        if inlist(x, sl_months, 2, sw) then
          if m and not d and not y then
            d, m = m, false
          end
          setm(mod(sw[0], 12) + 1)
        elseif inlist(x, sl_timezone, 2, sw) then
          c = fix(sw[0]) -- ignore gmt and utc
          if c ~= 0 then
            setz(c)
          end
        elseif not inlist(x, sl_weekdays, 2, sw) then
          sw:back()
          -- am pm bce ad ce bc
          if sw("^([bB])%s*(%.?)%s*[Cc]%s*(%2)%s*[Ee]%s*(%2)%s*") or sw("^([bB])%s*(%.?)%s*[Cc]%s*(%2)%s*") then
            e = e and error_dup() or -1
          elseif sw("^([aA])%s*(%.?)%s*[Dd]%s*(%2)%s*") or sw("^([cC])%s*(%.?)%s*[Ee]%s*(%2)%s*") then
            e = e and error_dup() or 1
          elseif sw("^([PApa])%s*(%.?)%s*[Mm]?%s*(%2)%s*") then
            x = lwr(sw[1]) -- there should be hour and it must be correct
            if (not h) or (h > 12) or (h < 0) then
              return error_inv()
            end
            if x == "a" and h == 12 then
              h = 0
            end -- am
            if x == "p" and h ~= 12 then
              h = h + 12
            end -- pm
          else
            error_syn()
          end
        end
      elseif not (sw("^([+-])(%d%d?):(%d%d)", setzc) or sw("^([+-])(%d+)", setzn) or sw("^[Zz]%s*$")) then -- sw{"([+-])",{"(%d%d?):(%d%d)","(%d+)"}}
        error_syn("?")
      end
      sw("^%s*")
    until sw:finish()
    --else print("$Iso(Date|Time|Zone)")
  end
  -- if date is given, it must be complete year, month & day
  if (not y and not h) or ((m and not d) or (d and not m)) or ((m and w) or (m and j) or (j and w)) then
    return error_inv("!")
  end
  -- fix month
  if m then
    m = m - 1
  end
  -- fix year if we are on BCE
  if e and e < 0 and y > 0 then
    y = 1 - y
  end
  --  create date object
  dn = (y and ((w and makedaynum_isoywd(y, w, u)) or (j and makedaynum(y, 0, j)) or makedaynum(y, m, d))) or DAYNUM_DEF
  df = makedayfrc(h or 0, r or 0, s or 0, 0) + ((z or 0) * TICKSPERMIN)
  --print("Zone",h,r,s,z,m,d,y,df)
  return date_new(dn, df) -- no need to :normalize();
end
--- Creates a DateObject from an `os.date` style table.
---@param v table Table with fields like `year`, `month` (1-based), `day`, `hour`, `min`, `sec`, `ticks`.
---@return DateObject|nil The created date object, or nil if table is incomplete or invalid.
---@throws string If the table contains incomplete date information (e.g., month without year/day).
---@private
local function date_fromtable(v)
  local y, m, d = fix(v.year), getmontharg(v.month), fix(v.day)
  local h, r, s, t = tonumber(v.hour), tonumber(v.min), tonumber(v.sec), tonumber(v.ticks)
  -- atleast there is time or complete date
  if (y or m or d) and not (y and m and d) then
    return error("incomplete table")
  end
  return (y or h or r or s or t)
    and date_new(y and makedaynum(y, m, d) or DAYNUM_DEF, makedayfrc(h or 0, r or 0, s or 0, t or 0))
end
local tmap = {
  ["number"] = function(v)
    return date_epoch:copy():addseconds(v)
  end,
  ["string"] = function(v)
    return date_parse(v)
  end,
  ["boolean"] = function(v)
    return date_fromtable(osdate(v and "!*t" or "*t"))
  end,
  ["table"] = function(v)
    local ref = getmetatable(v) == dobj
    return ref and v or date_fromtable(v), ref
  end,
}
--- Converts various input types into a normalized DateObject.
--- Handles numbers (seconds since OS epoch), strings (via `date_parse`), booleans (current time), `os.date` tables, and existing DateObjects.
---@param v number|string|boolean|table|DateObject The value to convert.
---@return DateObject obj The resulting DateObject.
---@return boolean? ref `true` if the input `v` was already a DateObject reference (not a copy).
---@throws string If the input value `v` is invalid or cannot be converted.
---@private
local function date_getdobj(v)
  local o, r = (tmap[type(v)] or fnil)(v)
  return (o and o:normalize() or error("invalid date time value")), r -- if r is true then o is a reference to a date obj
end
--#end -- not DATE_OBJECT_AFX
--- Creates a DateObject directly from numerical date/time components.
---@param arg1 number Year.
---@param arg2 number|string Month (1-12 or name/abbreviation).
---@param arg3 number Day (1-31).
---@param arg4? number Hour (0-23, default 0).
---@param arg5? number Minute (0-59, default 0).
---@param arg6? number Second (0-59, default 0).
---@param arg7? number Ticks (0-TICKSPERSEC-1, default 0).
---@return DateObject The created and normalized DateObject.
---@throws string If arguments are invalid or incomplete.
---@private
local function date_from(arg1, arg2, arg3, arg4, arg5, arg6, arg7)
  local y, m, d = fix(arg1), getmontharg(arg2), fix(arg3)
  local h, r, s, t = tonumber(arg4 or 0), tonumber(arg5 or 0), tonumber(arg6 or 0), tonumber(arg7 or 0)
  if y and m and d and h and r and s and t then
    return date_new(makedaynum(y, m, d), makedayfrc(h, r, s, t)):normalize()
  else
    return date_error_arg()
  end
end

--[[ THE DATE OBJECT METHODS ]]
--
--- Normalizes the internal `daynum` and `dayfrc` values after arithmetic operations.
--- Handles carry-over from day fraction to day number. Ensures date stays within MIN/MAX limits.
---@param self DateObject
---@return DateObject self The normalized DateObject.
---@throws string If the resulting date is outside the imposed limits (`DAYNUM_MIN`/`DAYNUM_MAX`).
function dobj:normalize()
  local dn, df = fix(self.daynum), self.dayfrc
  self.daynum, self.dayfrc = dn + floor(df / TICKSPERDAY), mod(df, TICKSPERDAY)
  return (dn >= DAYNUM_MIN and dn <= DAYNUM_MAX) and self or error("date beyond imposed limits:" .. self)
end

---@param self DateObject @return number year @return number month (1-12) @return number day (1-31)
function dobj:getdate()
  local y, m, d = breakdaynum(self.daynum)
  return y, m + 1, d
end
---@param self DateObject @return number hour (0-23) @return number min (0-59) @return number sec (0-59) @return number ticks (0-TICKSPERSEC-1)
function dobj:gettime()
  return breakdayfrc(self.dayfrc)
end

---@param self DateObject @return number hour (1-12)
function dobj:getclockhour()
  local h = self:gethours()
  return h > 12 and mod(h, 12) or (h == 0 and 12 or h)
end

---@param self DateObject @return number day of year (1-366)
function dobj:getyearday()
  return yearday(self.daynum) + 1
end
---@param self DateObject @return number weekday (1=Sunday, 7=Saturday)
function dobj:getweekday()
  return weekday(self.daynum) + 1
end -- in lua weekday is sunday = 1, monday = 2 ...

---@param self DateObject @return number year
function dobj:getyear()
  local r, _, _ = breakdaynum(self.daynum)
  return r
end
---@param self DateObject @return number month (1-12)
function dobj:getmonth()
  local _, r, _ = breakdaynum(self.daynum)
  return r + 1
end -- in lua month is 1 base
---@param self DateObject @return number day (1-31)
function dobj:getday()
  local _, _, r = breakdaynum(self.daynum)
  return r
end
---@param self DateObject @return number hour (0-23)
function dobj:gethours()
  return mod(floor(self.dayfrc / TICKSPERHOUR), HOURPERDAY)
end
---@param self DateObject @return number minute (0-59)
function dobj:getminutes()
  return mod(floor(self.dayfrc / TICKSPERMIN), MINPERHOUR)
end
---@param self DateObject @return number second (0-59)
function dobj:getseconds()
  return mod(floor(self.dayfrc / TICKSPERSEC), SECPERMIN)
end
---@param self DateObject @return number Seconds including fractional part (e.g., 59.123)
function dobj:getfracsec()
  return mod(floor(self.dayfrc / TICKSPERSEC), SECPERMIN) + (mod(self.dayfrc, TICKSPERSEC) / TICKSPERSEC)
end
---@param self DateObject @param u? number Optional scaling factor (units per second). @return number Ticks part (0-TICKSPERSEC-1), optionally scaled.
function dobj:getticks(u)
  local x = mod(self.dayfrc, TICKSPERSEC)
  return u and ((x * u) / TICKSPERSEC) or x
end
--- Calculates week number (00-53). Default assumes week starts Sunday.
---@param self DateObject
---@param wdb? number Optional first day of week (1=Sun, 2=Mon, ...).
---@return number week Week number (00-53).
---@throws string If `wdb` is provided but invalid.
function dobj:getweeknumber(wdb)
  local wd, yd = weekday(self.daynum), yearday(self.daynum)
  if wdb then
    wdb = tonumber(wdb)
    if wdb then
      wd = mod(wd - (wdb - 1), 7) -- shift the week day base
    else
      return date_error_arg()
    end
  end
  return (yd < wd and 0) or (floor(yd / 7) + ((mod(yd, 7) >= wd) and 1 or 0))
end

---@param self DateObject @return number ISO 8601 weekday (1=Monday, 7=Sunday).
function dobj:getisoweekday()
  return mod(weekday(self.daynum) - 1, 7) + 1
end -- sunday = 7, monday = 1 ...
---@param self DateObject @return number ISO 8601 week number (01-53).
function dobj:getisoweeknumber()
  return (isowy(self.daynum))
end
---@param self DateObject @return number ISO 8601 week-numbering year.
function dobj:getisoyear()
  return isoy(self.daynum)
end
---@param self DateObject @return number iso_year @return number iso_week @return number iso_weekday (1=Mon, 7=Sun)
function dobj:getisodate()
  local w, y = isowy(self.daynum)
  return y, w, self:getisoweekday()
end
--- Sets the date using ISO 8601 year, week number, and weekday.
--- Partially updates if arguments are omitted (e.g., `setisoyear(2024)` sets only year).
---@param self DateObject
---@param y? number ISO year.
---@param w? number ISO week number (1-53).
---@param d? number ISO weekday (1=Mon, 7=Sun).
---@return DateObject self The modified DateObject.
---@throws string If any provided argument is invalid.
function dobj:setisoyear(y, w, d)
  local cy, cw, cd = self:getisodate()
  if y then
    cy = fix(tonumber(y))
  end
  if w then
    cw = fix(tonumber(w))
  end
  if d then
    cd = fix(tonumber(d))
  end
  if cy and cw and cd then
    self.daynum = makedaynum_isoywd(cy, cw, cd)
    return self:normalize()
  else
    return date_error_arg()
  end
end

---@param self DateObject @param d number ISO weekday (1=Mon, 7=Sun). @return DateObject self @throws string
function dobj:setisoweekday(d)
  return self:setisoyear(nil, nil, d)
end
---@param self DateObject @param w number ISO week number (1-53). @param d? number ISO weekday (1=Mon, 7=Sun). @return DateObject self @throws string
function dobj:setisoweeknumber(w, d)
  return self:setisoyear(nil, w, d)
end

--- Sets the year, month, and day. Partially updates if arguments are omitted.
---@param self DateObject
---@param y? number Year.
---@param m? number|string Month (1-12 or name/abbreviation).
---@param d? number Day (1-31).
---@return DateObject self The modified DateObject.
---@throws string If any provided argument is invalid.
function dobj:setyear(y, m, d)
  local cy, cm, cd = breakdaynum(self.daynum)
  if y then
    cy = fix(tonumber(y))
  end
  if m then
    cm = getmontharg(m)
  end
  if d then
    cd = fix(tonumber(d))
  end
  if cy and cm and cd then
    self.daynum = makedaynum(cy, cm, cd)
    return self:normalize()
  else
    return date_error_arg()
  end
end

---@param self DateObject @param m number|string Month (1-12 or name/abbr). @param d? number Day (1-31). @return DateObject self @throws string
function dobj:setmonth(m, d)
  return self:setyear(nil, m, d)
end
---@param self DateObject @param d number Day (1-31). @return DateObject self @throws string
function dobj:setday(d)
  return self:setyear(nil, nil, d)
end

--- Sets the hour, minute, second, and ticks. Partially updates if arguments are omitted.
---@param self DateObject
---@param h? number Hour (0-23).
---@param m? number Minute (0-59).
---@param s? number Second (0-59).
---@param t? number Ticks (0-TICKSPERSEC-1).
---@return DateObject self The modified DateObject.
---@throws string If any provided argument is invalid.
function dobj:sethours(h, m, s, t)
  local ch, cm, cs, ck = breakdayfrc(self.dayfrc)
  ch, cm, cs, ck = tonumber(h or ch), tonumber(m or cm), tonumber(s or cs), tonumber(t or ck)
  if ch and cm and cs and ck then
    self.dayfrc = makedayfrc(ch, cm, cs, ck)
    return self:normalize()
  else
    return date_error_arg()
  end
end

---@param self DateObject @param m? number Minute (0-59). @param s? number Second (0-59). @param t? number Ticks (0-TICKSPERSEC-1). @return DateObject self @throws string
function dobj:setminutes(m, s, t)
  return self:sethours(nil, m, s, t)
end
---@param self DateObject @param s? number Second (0-59). @param t? number Ticks (0-TICKSPERSEC-1). @return DateObject self @throws string
function dobj:setseconds(s, t)
  return self:sethours(nil, nil, s, t)
end
---@param self DateObject @param t? number Ticks (0-TICKSPERSEC-1). @return DateObject self @throws string
function dobj:setticks(t)
  return self:sethours(nil, nil, nil, t)
end

---@param self DateObject @return number Total ticks since epoch 0001-01-01.
function dobj:spanticks()
  return (self.daynum * TICKSPERDAY + self.dayfrc)
end
---@param self DateObject @return number Total seconds since epoch 0001-01-01.
function dobj:spanseconds()
  return (self.daynum * TICKSPERDAY + self.dayfrc) / TICKSPERSEC
end
---@param self DateObject @return number Total minutes since epoch 0001-01-01.
function dobj:spanminutes()
  return (self.daynum * TICKSPERDAY + self.dayfrc) / TICKSPERMIN
end
---@param self DateObject @return number Total hours since epoch 0001-01-01.
function dobj:spanhours()
  return (self.daynum * TICKSPERDAY + self.dayfrc) / TICKSPERHOUR
end
---@param self DateObject @return number Total days since epoch 0001-01-01 (can have fractional part).
function dobj:spandays()
  return (self.daynum * TICKSPERDAY + self.dayfrc) / TICKSPERDAY
end

--- Adds years, months, and days to the date.
---@param self DateObject
---@param y? number Number of years to add (default 0).
---@param m? number Number of months to add (default 0).
---@param d? number Number of days to add (default 0).
---@return DateObject self The modified DateObject.
---@throws string If any argument is invalid.
function dobj:addyears(y, m, d)
  local cy, cm, cd = breakdaynum(self.daynum)
  if y then
    y = fix(tonumber(y))
  else
    y = 0
  end
  if m then
    m = fix(tonumber(m))
  else
    m = 0
  end
  if d then
    d = fix(tonumber(d))
  else
    d = 0
  end
  if y and m and d then
    self.daynum = makedaynum(cy + y, cm + m, cd + d)
    return self:normalize()
  else
    return date_error_arg()
  end
end

--- Adds months and days to the date.
---@param self DateObject
---@param m? number Number of months to add (default 0).
---@param d? number Number of days to add (default 0).
---@return DateObject self The modified DateObject.
---@throws string If any argument is invalid.
function dobj:addmonths(m, d)
  return self:addyears(nil, m, d)
end

local function dobj_adddayfrc(self, n, pt, pd)
  n = tonumber(n)
  if n then
    local x = floor(n / pd)
    self.daynum = self.daynum + x
    self.dayfrc = self.dayfrc + (n - x * pd) * pt
    return self:normalize()
  else
    return date_error_arg()
  end
end
---@param self DateObject @param n number Days to add. @return DateObject self @throws string
function dobj:adddays(n)
  return dobj_adddayfrc(self, n, TICKSPERDAY, 1)
end
---@param self DateObject @param n number Hours to add. @return DateObject self @throws string
function dobj:addhours(n)
  return dobj_adddayfrc(self, n, TICKSPERHOUR, HOURPERDAY)
end
---@param self DateObject @param n number Minutes to add. @return DateObject self @throws string
function dobj:addminutes(n)
  return dobj_adddayfrc(self, n, TICKSPERMIN, MINPERDAY)
end
---@param self DateObject @param n number Seconds to add. @return DateObject self @throws string
function dobj:addseconds(n)
  return dobj_adddayfrc(self, n, TICKSPERSEC, SECPERDAY)
end
---@param self DateObject @param n number Ticks to add. @return DateObject self @throws string
function dobj:addticks(n)
  return dobj_adddayfrc(self, n, 1, TICKSPERDAY)
end
local tvspec = {
  -- Abbreviated weekday name (Sun)
  ["%a"] = function(self)
    return sl_weekdays[weekday(self.daynum) + 7]
  end,
  -- Full weekday name (Sunday)
  ["%A"] = function(self)
    return sl_weekdays[weekday(self.daynum)]
  end,
  -- Abbreviated month name (Dec)
  ["%b"] = function(self)
    return sl_months[self:getmonth() - 1 + 12]
  end,
  -- Full month name (December)
  ["%B"] = function(self)
    return sl_months[self:getmonth() - 1]
  end,
  -- Year/100 (19, 20, 30)
  ["%C"] = function(self)
    return fmt("%.2d", fix(self:getyear() / 100))
  end,
  -- The day of the month as a number (range 1 - 31)
  ["%d"] = function(self)
    return fmt("%.2d", self:getday())
  end,
  -- year for ISO 8601 week, from 00 (79)
  ["%g"] = function(self)
    return fmt("%.2d", mod(self:getisoyear(), 100))
  end,
  -- year for ISO 8601 week, from 0000 (1979)
  ["%G"] = function(self)
    return fmt("%.4d", self:getisoyear())
  end,
  -- same as %b
  ["%h"] = function(self)
    return self:fmt0("%b")
  end,
  -- hour of the 24-hour day, from 00 (06)
  ["%H"] = function(self)
    return fmt("%.2d", self:gethours())
  end,
  -- The  hour as a number using a 12-hour clock (01 - 12)
  ["%I"] = function(self)
    return fmt("%.2d", self:getclockhour())
  end,
  -- The day of the year as a number (001 - 366)
  ["%j"] = function(self)
    return fmt("%.3d", self:getyearday())
  end,
  -- Month of the year, from 01 to 12
  ["%m"] = function(self)
    return fmt("%.2d", self:getmonth())
  end,
  -- Minutes after the hour 55
  ["%M"] = function(self)
    return fmt("%.2d", self:getminutes())
  end,
  -- AM/PM indicator (AM)
  ["%p"] = function(self)
    return sl_meridian[self:gethours() > 11 and 1 or -1]
  end, --AM/PM indicator (AM)
  -- The second as a number (59, 20 , 01)
  ["%S"] = function(self)
    return fmt("%.2d", self:getseconds())
  end,
  -- ISO 8601 day of the week, to 7 for Sunday (7, 1)
  ["%u"] = function(self)
    return self:getisoweekday()
  end,
  -- Sunday week of the year, from 00 (48)
  ["%U"] = function(self)
    return fmt("%.2d", self:getweeknumber())
  end,
  -- ISO 8601 week of the year, from 01 (48)
  ["%V"] = function(self)
    return fmt("%.2d", self:getisoweeknumber())
  end,
  -- The day of the week as a decimal, Sunday being 0
  ["%w"] = function(self)
    return self:getweekday() - 1
  end,
  -- Monday week of the year, from 00 (48)
  ["%W"] = function(self)
    return fmt("%.2d", self:getweeknumber(2))
  end,
  -- The year as a number without a century (range 00 to 99)
  ["%y"] = function(self)
    return fmt("%.2d", mod(self:getyear(), 100))
  end,
  -- Year with century (2000, 1914, 0325, 0001)
  ["%Y"] = function(self)
    return fmt("%.4d", self:getyear())
  end,
  -- Time zone offset, the date object is assumed local time (+1000, -0230)
  ["%z"] = function(self)
    local b = -self:getbias()
    local x = abs(b)
    return fmt("%s%.4d", b < 0 and "-" or "+", fix(x / 60) * 100 + floor(mod(x, 60)))
  end,
  -- Time zone name, the date object is assumed local time
  ["%Z"] = function(self)
    return self:gettzname()
  end,
  -- Misc --
  -- Year, if year is in BCE, prints the BCE Year representation, otherwise result is similar to "%Y" (1 BCE, 40 BCE)
  ["%\b"] = function(self)
    local x = self:getyear()
    return fmt("%.4d%s", x > 0 and x or (-x + 1), x > 0 and "" or " BCE")
  end,
  -- Seconds including fraction (59.998, 01.123)
  ["%\f"] = function(self)
    local x = self:getfracsec()
    return fmt("%s%.9f", x >= 10 and "" or "0", x)
  end,
  -- percent character %
  ["%%"] = function(self)
    return "%"
  end,
  -- Group Spec --
  -- 12-hour time, from 01:00:00 AM (06:55:15 AM); same as "%I:%M:%S %p"
  ["%r"] = function(self)
    return self:fmt0("%I:%M:%S %p")
  end,
  -- hour:minute, from 01:00 (06:55); same as "%I:%M"
  ["%R"] = function(self)
    return self:fmt0("%I:%M")
  end,
  -- 24-hour time, from 00:00:00 (06:55:15); same as "%H:%M:%S"
  ["%T"] = function(self)
    return self:fmt0("%H:%M:%S")
  end,
  -- month/day/year from 01/01/00 (12/02/79); same as "%m/%d/%y"
  ["%D"] = function(self)
    return self:fmt0("%m/%d/%y")
  end,
  -- year-month-day (1979-12-02); same as "%Y-%m-%d"
  ["%F"] = function(self)
    return self:fmt0("%Y-%m-%d")
  end,
  -- The preferred date and time representation;  same as "%x %X"
  ["%c"] = function(self)
    return self:fmt0("%x %X")
  end,
  -- The preferred date representation, same as "%a %b %d %\b"
  ["%x"] = function(self)
    return self:fmt0("%a %b %d %\b")
  end,
  -- The preferred time representation, same as "%H:%M:%\f"
  ["%X"] = function(self)
    return self:fmt0("%H:%M:%\f")
  end,
  -- GroupSpec --
  -- Iso format, same as "%Y-%m-%dT%T"
  ["${iso}"] = function(self)
    return self:fmt0("%Y-%m-%dT%T")
  end,
  -- http format, same as "%a, %d %b %Y %T GMT"
  ["${http}"] = function(self)
    return self:fmt0("%a, %d %b %Y %T GMT")
  end,
  -- ctime format, same as "%a %b %d %T GMT %Y"
  ["${ctime}"] = function(self)
    return self:fmt0("%a %b %d %T GMT %Y")
  end,
  -- RFC850 format, same as "%A, %d-%b-%y %T GMT"
  ["${rfc850}"] = function(self)
    return self:fmt0("%A, %d-%b-%y %T GMT")
  end,
  -- RFC1123 format, same as "%a, %d %b %Y %T GMT"
  ["${rfc1123}"] = function(self)
    return self:fmt0("%a, %d %b %Y %T GMT")
  end,
  -- asctime format, same as "%a %b %d %T %Y"
  ["${asctime}"] = function(self)
    return self:fmt0("%a %b %d %T %Y")
  end,
}
--- Formats the date according to `strftime` specifiers (helper, does not handle `${...}` groups). @private
---@param self DateObject @param str string Format string. @return string Formatted string.
function dobj:fmt0(str)
  return (gsub(str, "%%[%a%%\b\f]", function(x)
    local f = tvspec[x]
    return (f and f(self)) or x
  end))
end
--- Formats the date according to `strftime` specifiers and custom `${...}` groups (e.g., `${iso}`).
---@param self DateObject
---@param str? string Format string (defaults to module default `fmtstr`).
---@return string Formatted date/time string.
function dobj:fmt(str)
  str = str or self.fmtstr or fmtstr
  return self:fmt0((gmatch(str, "${%w+}")) and (gsub(str, "${%w+}", function(x)
    local f = tvspec[x]
    return (f and f(self)) or x
  end)) or str)
end

function dobj.__lt(a, b)
  if a.daynum == b.daynum then
    return (a.dayfrc < b.dayfrc)
  else
    return (a.daynum < b.daynum)
  end
end
function dobj.__le(a, b)
  if a.daynum == b.daynum then
    return (a.dayfrc <= b.dayfrc)
  else
    return (a.daynum <= b.daynum)
  end
end
function dobj.__eq(a, b)
  return (a.daynum == b.daynum) and (a.dayfrc == b.dayfrc)
end
function dobj.__sub(a, b)
  local d1, d2 = date_getdobj(a), date_getdobj(b)
  local d0 = d1 and d2 and date_new(d1.daynum - d2.daynum, d1.dayfrc - d2.dayfrc)
  return d0 and d0:normalize()
end
function dobj.__add(a, b)
  local d1, d2 = date_getdobj(a), date_getdobj(b)
  local d0 = d1 and d2 and date_new(d1.daynum + d2.daynum, d1.dayfrc + d2.dayfrc)
  return d0 and d0:normalize()
end
function dobj.__concat(a, b)
  return tostring(a) .. tostring(b)
end
---@return string Default string representation (uses default format).
function dobj:__tostring()
  return self:fmt()
end

--- Creates a new DateObject instance with the same date/time value.
---@param self DateObject
---@return DateObject copy The new copy.
function dobj:copy()
  return date_new(self.daynum, self.dayfrc)
end

--[[ THE LOCAL DATE OBJECT METHODS ]]
--
--- Converts this DateObject (assumed to be in UTC) to the local time zone in place.
---@param self DateObject
---@return DateObject self The modified DateObject (now in local time).
---@throws string If bias calculation fails.
function dobj:tolocal()
  local dn, df = self.daynum, self.dayfrc
  local bias = getbiasutc2(self)
  if bias then
    -- utc = local + bias; local = utc - bias
    self.daynum = dn
    self.dayfrc = df - bias * TICKSPERSEC
    return self:normalize()
  else
    return nil
  end
end

--- Converts this DateObject (assumed to be in local time) to UTC in place.
---@param self DateObject
---@return DateObject self The modified DateObject (now in UTC).
---@throws string If bias calculation fails.
function dobj:toutc()
  local dn, df = self.daynum, self.dayfrc
  local bias = getbiasloc2(dn, df)
  if bias then
    -- utc = local + bias;
    self.daynum = dn
    self.dayfrc = df + bias * TICKSPERSEC
    return self:normalize()
  else
    return nil
  end
end

--- Returns the local time zone offset from UTC in minutes for this date object (assumed local).
---@param self DateObject
---@return number offset Offset in minutes (positive for west of UTC, negative for east).
---@throws string If bias calculation fails.
function dobj:getbias()
  return (getbiasloc2(self.daynum, self.dayfrc)) / SECPERMIN
end

--- Returns the local time zone name (e.g., "EST", "PST") for this date object (assumed local).
---@param self DateObject
---@return string tz_name Time zone name, or "" on error.
function dobj:gettzname()
  local _, tvu, _ = getbiasloc2(self.daynum, self.dayfrc)
  return tvu and osdate("%Z", tvu) or ""
end

--#if not DATE_OBJECT_AFX then
--- Creates a DateObject representing only a time of day (date part is set to 0001-01-01).
---@param h? number Hour (0-23, default 0).
---@param r? number Minute (0-59, default 0).
---@param s? number Second (0-59, default 0).
---@param t? number Ticks (0-TICKSPERSEC-1, default 0).
---@return DateObject The new DateObject.
---@throws string If any argument is invalid.
function date.time(h, r, s, t)
  h, r, s, t = tonumber(h or 0), tonumber(r or 0), tonumber(s or 0), tonumber(t or 0)
  if h and r and s and t then
    return date_new(DAYNUM_DEF, makedayfrc(h, r, s, t))
  else
    return date_error_arg()
  end
end

--- Constructor for creating DateObjects. Accepts various input types:
--- - No arguments: Current local time.
--- - `false`: Current local time.
--- - `true`: Current UTC time.
--- - number: Seconds since the OS epoch (usually 1970-01-01 UTC).
--- - string: Date/time string (parsed via ISO 8601 or flexible format).
--- - table: `os.date` style table ({year, month, day,...}).
--- - DateObject: Returns a copy.
--- - 3-7 numbers: Year, Month, Day, [Hour], [Minute], [Second], [Ticks].
---@param self DateModule
---@param arg1? number|string|table|boolean|DateObject First argument (type determines parsing).
---@param ... number Additional arguments if creating from components (month, day, h, m, s, t).
---@return DateObject The new DateObject instance.
---@throws string|table If arguments are invalid or parsing fails.
function date:__call(arg1, ...)
  local arg_count = select("#", ...) + (arg1 == nil and 0 or 1)
  if arg_count > 1 then
    return (date_from(arg1, ...))
  elseif arg_count == 0 then
    return (date_getdobj(false))
  else
    local o, r = date_getdobj(arg1)
    return r and o:copy() or o
  end
end

--- Calculates the difference between two dates. Alias for `a - b`.
---@param a DateObject|number|string|table|boolean First date/time value.
---@param b DateObject|number|string|table|boolean Second date/time value.
---@return DateObject A new DateObject representing the duration/difference.
---@throws string If arguments are invalid.
date.diff = dobj.__sub

--- Checks if the year of the given value is a leap year.
---@param v number|DateObject|string|table|boolean Value containing year information.
---@return boolean `true` if the year is a leap year, `false` otherwise or on invalid input.
function date.isleapyear(v)
  local y = fix(v)
  if not y then
    y = date_getdobj(v)
    y = y and y:getyear()
  end
  return isleapyear(y + 0)
end

--- Returns a copy of the DateObject representing the OS epoch (usually 1970-01-01 00:00:00 UTC).
---@return DateObject The epoch DateObject.
---@throws string If the OS epoch could not be determined during module load.
function date.epoch()
  return date_epoch:copy()
end

--- Creates a DateObject from ISO 8601 year, week number, and weekday.
---@param y number ISO year.
---@param w? number ISO week number (1-53, default 1).
---@param d? number ISO weekday (1=Mon, 7=Sun, default 1).
---@return DateObject The new DateObject.
---@throws string If arguments are invalid.
function date.isodate(y, w, d)
  return date_new(makedaynum_isoywd(y + 0, w and (w + 0) or 1, d and (d + 0) or 1), 0)
end
--- Sets the century flip year (0-99) used for parsing 2-digit years.
--- If year >= flip, assumes 19xx; otherwise assumes 20xx.
---@param y number The flip year (0-99).
---@return nil
---@throws string If `y` is not an integer between 0 and 99.
function date.setcenturyflip(y)
  if y ~= floor(y) or y < 0 or y > 100 then
    date_error_arg()
  end
  centuryflip = y
end
--- Gets the current century flip year used for parsing 2-digit years.
---@return number The current century flip year (0-99).
function date.getcenturyflip()
  return centuryflip
end

--- Gets or sets the default format string used by `DateObject:fmt()` and `tostring()`.
---@param str? string If provided, sets the new default format string.
---@return string The current (or newly set) default format string.
function date.fmt(str)
  if str then
    fmtstr = str
  end
  return fmtstr
end
--- Gets or sets the minimum allowed internal day number. Returns the number if setting, or a DateObject representing the limit if getting.
---@param n? number Optional new minimum day number. Must be less than current max.
---@return number|DateObject The new minimum day number if `n` was provided, otherwise a DateObject representing the current minimum date.
function date.daynummin(n)
  DAYNUM_MIN = (n and n < DAYNUM_MAX) and n or DAYNUM_MIN
  return n and DAYNUM_MIN or date_new(DAYNUM_MIN, 0):normalize()
end
--- Gets or sets the maximum allowed internal day number. Returns the number if setting, or a DateObject representing the limit if getting.
---@param n? number Optional new maximum day number. Must be greater than current min.
---@return number|DateObject The new maximum day number if `n` was provided, otherwise a DateObject representing the current maximum date.
function date.daynummax(n)
  DAYNUM_MAX = (n and n > DAYNUM_MIN) and n or DAYNUM_MAX
  return n and DAYNUM_MAX or date_new(DAYNUM_MAX, 0):normalize()
end
--- Gets or sets the number of ticks per second used for internal time representation. Default 1,000,000.
---@param t? number Optional new number of ticks per second.
---@return number The current (or newly set) number of ticks per second.
function date.ticks(t)
  if t then
    setticks(t)
  end
  return TICKSPERSEC
end
--#end -- not DATE_OBJECT_AFX

local tm = osdate("!*t", 0)
if tm then
  date_epoch = date_new(makedaynum(tm.year, tm.month - 1, tm.day), makedayfrc(tm.hour, tm.min, tm.sec, 0))
  -- the distance from our epoch to os epoch in daynum
  DATE_EPOCH = date_epoch and date_epoch:spandays()
else -- error will be raise only if called!
  date_epoch = setmetatable({}, {
    __index = function()
      error("failed to get the epoch date")
    end,
  })
end

--#if not DATE_OBJECT_AFX then
return date
--#else
--$return date_from
--#end
