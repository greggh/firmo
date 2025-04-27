--- benchmark_example.lua
--
-- This file provides a comprehensive demonstration of the `lib.tools.benchmark`
-- module in Firmo. It covers various aspects of benchmarking, including:
-- - Basic benchmark execution using `benchmark.run()`.
-- - Comparing different function implementations using `benchmark.compare()`.
-- - Configuring benchmarks (iterations, warmup).
-- - Concepts for measuring memory usage (example implementation).
-- - Concepts for statistical analysis of results (percentiles, outliers - example implementations).
-- - Integrating benchmark runs into Firmo tests with performance assertions.
-- - Best practices for effective benchmarking.
--
-- Run this example directly: lua examples/benchmark_example.lua
-- Run embedded tests: lua test.lua examples/benchmark_example.lua
--

-- Import required modules
local firmo = require("firmo")
local benchmark = require("lib.tools.benchmark")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Set up test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Set up logging
local logger = logging.get_logger("BenchmarkExample")

logger.info("\n== BENCHMARK MODULE EXAMPLE ==\n")
logger.info("PART 1: Basic Benchmarking\n")

-- Example 1: Simple function benchmark
logger.info("Example 1: Simple Function Benchmark")
--- Simple function for demonstrating benchmarking: concatenates strings.
-- @param count number The number of times to concatenate 'x'.
-- @return string The resulting concatenated string.
function concat_strings(count)
  local result = ""
  for i = 1, count do
    result = result .. "x"
  end
  return result
end

-- Benchmark the function
local concat_result = benchmark.run(function()
  return concat_strings(1000)
end, { iterations = 1000, name = "String Concatenation" })

-- Display benchmark results
logger.info("\nString Concatenation Results:")
print("Total time: " .. concat_result.total_time .. " ms")
print("Average time: " .. concat_result.average_time .. " ms per iteration")
print("Iterations: " .. concat_result.iterations)
print("Min time: " .. concat_result.min_time .. " ms")
print("Max time: " .. concat_result.max_time .. " ms")
print("Standard deviation: " .. concat_result.standard_deviation .. " ms")

-- Example 2: Function with arguments
logger.info("\nExample 2: Function with Arguments")
--- Simple recursive factorial function for benchmarking.
-- @param n number The number to calculate the factorial of.
-- @return number The factorial of n.
function calculate_factorial(n)
  if n <= 1 then
    return 1
  end
  return n * calculate_factorial(n - 1)
end

-- Benchmark with different arguments
local factorial_results = {}
for n = 5, 25, 5 do
  local result = benchmark.run(function()
    return calculate_factorial(n)
  end, { iterations = 100, name = "Factorial " .. n })

  factorial_results[n] = result
end

-- Compare results
logger.info("\nFactorial Performance Comparison:")
print(string.format("%-15s %-15s %-15s %-15s", "Input Size", "Avg Time (ms)", "Min Time (ms)", "Max Time (ms)"))
print(
  string.format("%-15s %-15s %-15s %-15s", "---------------", "---------------", "---------------", "---------------")
)
for n = 5, 25, 5 do
  local result = factorial_results[n]
  print(string.format("%-15d %-15.6f %-15.6f %-15.6f", n, result.average_time, result.min_time, result.max_time))
end

-- Example 3: Benchmarking different implementations
logger.info("\nExample 3: Comparing Different Implementations")
--- String building using basic concatenation (`..`).
-- @param count number The number of times to concatenate 'x'.
-- @return string The resulting string.
function string_concat(count)
  local result = ""
  for i = 1, count do
    result = result .. "x"
  end
  return result
end

--- String building using table insertion and `table.concat`.
-- @param count number The number of times to insert 'x' into the table.
-- @return string The resulting string.
function table_concat(count)
  local t = {}
  for i = 1, count do
    t[i] = "x"
  end
  return table.concat(t)
end

-- Benchmark both implementations
local size = 10000
local implementations = {
  ["String Concatenation"] = function()
    return string_concat(size)
  end,
  ["Table Concat"] = function()
    return table_concat(size)
  end,
}

-- Run comparison
local comparison = benchmark.compare(implementations, { iterations = 100 })

-- Display results
logger.info("\nString Building Comparison (" .. size .. " characters):")
print(
  string.format(
    "%-25s %-15s %-15s %-15s %-15s",
    "Implementation",
    "Avg Time (ms)",
    "Min Time (ms)",
    "Max Time (ms)",
    "Relative Speed"
  )
)
print(
  string.format(
    "%-25s %-15s %-15s %-15s %-15s",
    "-------------------------",
    "---------------",
    "---------------",
    "---------------",
    "---------------"
  )
)

local fastest_time = nil
for name, result in pairs(comparison) do
  if fastest_time == nil or result.average_time < fastest_time then
    fastest_time = result.average_time
  end
end

for name, result in pairs(comparison) do
  local relative_speed = fastest_time / result.average_time
  print(
    string.format(
      "%-25s %-15.6f %-15.6f %-15.6f %-15.2fx",
      name,
      result.average_time,
      result.min_time,
      result.max_time,
      relative_speed
    )
  )
end

-- PART 2: Advanced Benchmarking
logger.info("\nPART 2: Advanced Benchmarking\n")

-- Example 4: Memory Usage Benchmarking
logger.info("Example 4: Memory Usage Benchmarking")
---@return number The amount of memory in use (in kilobytes)
function get_memory_usage()
  collectgarbage("collect")
  return collectgarbage("count")
end

---@private
---@param func function The function to benchmark
---@param config? {iterations?: number, warmup_iterations?: number} Optional configuration
---@return {peak_memory: number, peak_increase: number, retained_memory: number, iterations: number} Benchmark results
---@nodoc This is an example implementation for demonstrating memory analysis concepts.
function benchmark_memory(func, config)
  config = config or {}
  local iterations = config.iterations or 100
  local warmup_iterations = config.warmup_iterations or 5

  -- Warmup to ensure JIT compilation
  for i = 1, warmup_iterations do
    func()
  end

  -- Collect garbage and get baseline memory
  collectgarbage("collect")
  local start_memory = collectgarbage("count")

  -- Run the benchmark
  for i = 1, iterations do
    func()
  end

  -- Get final memory and collect garbage again
  local end_memory = collectgarbage("count")
  collectgarbage("collect")
  local final_memory = collectgarbage("count")

  -- Calculate results
  return {
    peak_memory = end_memory,
    peak_increase = end_memory - start_memory,
    retained_memory = final_memory - start_memory,
    iterations = iterations,
  }
end

-- Benchmark memory usage for different string sizes
local memory_results = {}
local string_sizes = { 1000, 10000, 100000, 1000000 }

for _, size in ipairs(string_sizes) do
  local result = benchmark_memory(function()
    return string.rep("x", size)
  end, { iterations = 10 })

  memory_results[size] = result
end

-- Display memory benchmark results
logger.info("\nMemory Usage Comparison (String Creation):")
print(
  string.format("%-15s %-20s %-20s %-20s", "String Size", "Peak Memory (KB)", "Peak Increase (KB)", "Retained (KB)")
)
print("---------------", "--------------------", "--------------------", "--------------------")

for _, size in ipairs(string_sizes) do
  local result = memory_results[size]
  print(
    string.format(
      "%-15d %-20.2f %-20.2f %-20.2f",
      size,
      result.peak_memory,
      result.peak_increase,
      result.retained_memory
    )
  )
end

-- Example 5: Benchmarking with Warmup
logger.info("\nExample 5: Benchmarking with Warmup")
---@param array number[] The array to sort
---@return number[] The sorted array (copy of the original)
---@nodoc Example bubble sort implementation for benchmarking.
function bubble_sort(array)
  local n = #array
  local arr = {}
  for i = 1, n do
    arr[i] = array[i]
  end -- Copy the array

  for i = 1, n do
    for j = 1, n - i do
      if arr[j] > arr[j + 1] then
        arr[j], arr[j + 1] = arr[j + 1], arr[j]
      end
    end
  end
  return arr
end

---@private
---@param array number[] The array to sort
---@return number[] The sorted array (copy of the original)
---@nodoc Example insertion sort implementation for benchmarking.
function insertion_sort(array)
  local n = #array
  local arr = {}
  for i = 1, n do
    arr[i] = array[i]
  end -- Copy the array

  for i = 2, n do
    local key = arr[i]
    local j = i - 1
    while j > 0 and arr[j] > key do
      arr[j + 1] = arr[j]
      j = j - 1
    end
    arr[j + 1] = key
  end
  return arr
end

---@private
---@param array number[] The array to sort
---@return number[] The sorted array (copy of the original)
---@nodoc Wrapper around Lua's native `table.sort` for benchmarking comparison.
function native_sort(array)
  local n = #array
  local arr = {}
  for i = 1, n do
    arr[i] = array[i]
  end -- Copy the array

  table.sort(arr)
  return arr
end

---@private
---@param size number The size of the array to generate
---@return number[] An array filled with random numbers
---@nodoc Helper function to generate data for sorting benchmarks.
function generate_random_array(size)
  local array = {}
  for i = 1, size do
    array[i] = math.random(1, 1000)
  end
  return array
end

-- Run benchmark with warmup
local sort_data = generate_random_array(1000)
local sort_funcs = {
  ["Bubble Sort"] = function()
    return bubble_sort(sort_data)
  end,
  ["Insertion Sort"] = function()
    return insertion_sort(sort_data)
  end,
  ["Native Sort"] = function()
    return native_sort(sort_data)
  end,
}

local sort_comparison = benchmark.compare(sort_funcs, {
  iterations = 10,
  warmup_iterations = 3,
  name = "Sorting Algorithms",
})

-- Display results
logger.info("\nSorting Algorithm Comparison (1000 elements):")
print(
  string.format(
    "%-20s %-15s %-15s %-15s %-15s",
    "Algorithm",
    "Avg Time (ms)",
    "Min Time (ms)",
    "Max Time (ms)",
    "Relative Speed"
  )
)
print(
  string.format(
    "%-20s %-15s %-15s %-15s %-15s",
    "--------------------",
    "---------------",
    "---------------",
    "---------------",
    "---------------"
  )
)

local fastest_sort_time = nil
for name, result in pairs(sort_comparison) do
  if fastest_sort_time == nil or result.average_time < fastest_sort_time then
    fastest_sort_time = result.average_time
  end
end

for name, result in pairs(sort_comparison) do
  local relative_speed = fastest_sort_time / result.average_time
  print(
    string.format(
      "%-20s %-15.6f %-15.6f %-15.6f %-15.2fx",
      name,
      result.average_time,
      result.min_time,
      result.max_time,
      relative_speed
    )
  )
end

-- Example 6: Profiling Call Frequency
logger.info("\nExample 6: Profiling Call Frequency")
-- Create a profiler to track function calls
local call_counter = {}
setmetatable(call_counter, { __mode = "k" }) -- Weak keys

function track_call(func_name)
  call_counter[func_name] = (call_counter[func_name] or 0) + 1
end

-- Functions with different call patterns
---@nodoc Example recursive Fibonacci implementation for profiling.
function fibonacci_recursive(n)
  track_call("fibonacci_recursive")
  if n <= 1 then
    return n
  end
  return fibonacci_recursive(n - 1) + fibonacci_recursive(n - 2)
end

---@nodoc Example iterative Fibonacci implementation for profiling.
function fibonacci_iterative(n)
  track_call("fibonacci_iterative")
  if n <= 1 then
    return n
  end

  local a, b = 0, 1
  for i = 2, n do
    track_call("fibonacci_iterative_loop")
    a, b = b, a + b
  end
  return b
end

-- Reset and run profiling
call_counter = {}
fibonacci_recursive(10)
local recursive_calls = call_counter["fibonacci_recursive"] or 0

call_counter = {}
fibonacci_iterative(10)
local iterative_calls = call_counter["fibonacci_iterative"] or 0
local loop_calls = call_counter["fibonacci_iterative_loop"] or 0

-- Display profiling results
logger.info("\nFunction Call Profiling (Fibonacci n=10):")
logger.info("Recursive fibonacci calls: " .. tostring(recursive_calls))
logger.info("Iterative fibonacci calls: " .. tostring(iterative_calls))
logger.info("Iterative loop iterations: " .. tostring(loop_calls))
-- PART 3: Statistical Analysis
logger.info("\nPART 3: Statistical Analysis\n")

-- Example 7: Analyzing Benchmark Distribution
logger.info("Example 7: Analyzing Benchmark Distribution")
---@param times number[] Array of timing measurements in milliseconds
---@param percentiles number[] Array of percentile values to calculate (0-100)
---@return table<number, number> A table mapping each percentile to its value
---@nodoc This is an example implementation for demonstrating percentile calculation.
function calculate_percentiles(times, percentiles)
  -- Sort the times
  table.sort(times)

  local results = {}
  for _, p in ipairs(percentiles) do
    local index = math.ceil(#times * (p / 100))
    if index < 1 then
      index = 1
    end
    if index > #times then
      index = #times
    end
    results[p] = times[index]
  end

  return results
end

-- Run a benchmark with many iterations for distribution analysis
local distribution_times = {}
local iterations = 1000

for i = 1, iterations do
  local start_time = os.clock()
  local result = string.rep("x", 10000)
  local end_time = os.clock()
  distribution_times[i] = (end_time - start_time) * 1000 -- ms
end

-- Calculate statistics
local sum = 0
for _, time in ipairs(distribution_times) do
  sum = sum + time
end
local mean = sum / #distribution_times

local sum_squared_diff = 0
for _, time in ipairs(distribution_times) do
  local diff = time - mean
  sum_squared_diff = sum_squared_diff + (diff * diff)
end
local variance = sum_squared_diff / #distribution_times
local std_dev = math.sqrt(variance)

-- Calculate percentiles
local percentiles = { 50, 90, 95, 99, 99.9 }
local percentile_values = calculate_percentiles(distribution_times, percentiles)

-- Display distribution statistics
logger.info("\nDistribution Analysis - String Repetition (n=" .. iterations .. "):")
print("Mean execution time: " .. mean .. " ms")

logger.info("\nPercentile Values:")
print("\nPercentile Values:") -- Keep print for table output
for _, p in ipairs(percentiles) do
  print(string.format("P%-6s %-10.6f ms", p .. ":", percentile_values[p]))
end

-- Example 8: Outlier Detection
logger.info("\nExample 8: Outlier Detection")
---@param times number[] Array of timing measurements
---@param mean number The mean value of the timing measurements
---@param std_dev number The standard deviation of the timing measurements
---@return {index: number, value: number}[] Array of outliers
---@return number lower_bound The lower threshold for outlier detection
---@return number upper_bound The upper threshold for outlier detection
---@nodoc This is an example implementation for demonstrating outlier detection (using 3 std devs).
function detect_outliers(times, mean, std_dev)
  local outliers = {}
  local lower_bound = mean - 3 * std_dev
  local upper_bound = mean + 3 * std_dev

  for i, time in ipairs(times) do
    if time < lower_bound or time > upper_bound then
      table.insert(outliers, { index = i, value = time })
    end
  end

  return outliers, lower_bound, upper_bound
end

-- Find outliers in our distribution
local outliers, lower_bound, upper_bound = detect_outliers(distribution_times, mean, std_dev)

-- Display outlier information
logger.info("\nOutlier Detection (3 standard deviations):")
print("\nOutlier Detection (3 standard deviations):") -- Keep print for results
print("Lower bound: " .. lower_bound .. " ms")

if #outliers > 0 then
  logger.info("\nSample outliers:")
  print("\nSample outliers:") -- Keep print for results
  for i = 1, math.min(5, #outliers) do
    print(string.format("Outlier #%d: %f ms (iteration %d)", i, outliers[i].value, outliers[i].index))
  end
end

-- Calculate statistics without outliers
if #outliers > 0 then
  local clean_times = {}

  -- Create a set of outlier indices for quick lookup
  local outlier_indices = {}
  for _, o in ipairs(outliers) do
    outlier_indices[o.index] = true
  end

  -- Collect non-outlier times
  for i, time in ipairs(distribution_times) do
    if not outlier_indices[i] then
      table.insert(clean_times, time)
    end
  end

  -- Calculate clean statistics
  local clean_sum = 0
  for _, time in ipairs(clean_times) do
    clean_sum = clean_sum + time
  end
  local clean_mean = clean_sum / #clean_times

  local clean_sum_squared_diff = 0
  for _, time in ipairs(clean_times) do
    local diff = time - clean_mean
    clean_sum_squared_diff = clean_sum_squared_diff + (diff * diff)
  end
  local clean_variance = clean_sum_squared_diff / #clean_times
  local clean_std_dev = math.sqrt(clean_variance)
end

-- Display clean statistics
logger.info("\nStatistics without outliers:")
print("\nStatistics without outliers:") -- Keep print for results
print("Mean execution time: " .. clean_mean .. " ms")

-- PART 4: Benchmarking in Tests
logger.info("\nPART 4: Benchmarking in Tests\n")

-- Example 9: Performance Testing with Firmo
logger.info("Example 9: Performance Testing with Firmo")
local string_utils = {
  --- Joins a table of strings with a specified separator.
  -- @param strings table A table of strings to join.
  -- @param separator string|nil The separator to use (default: ",").
  -- @return string|nil The joined string, or nil + error on invalid input.
  -- @return table|nil An error object if input validation fails.
  join = function(strings, separator)
    if type(strings) ~= "table" then
      return nil,
        error_handler.validation_error(
          "Expected table of strings",
          { parameter = "strings", provided_type = type(strings) }
        )
    end

    separator = separator or ","
    return table.concat(strings, separator)
  end,

  --- Splits a string into a table of substrings using a separator.
  -- @param str string The string to split.
  -- @param separator string|nil The separator to use (default: ",").
  -- @return table|nil A table of substrings, or nil + error on invalid input.
  -- @return table|nil An error object if input validation fails.
  split = function(str, separator)
    if type(str) ~= "string" then
      return nil, error_handler.validation_error("Expected string", { parameter = "str", provided_type = type(str) })
    end

    separator = separator or ","
    local result = {}
    for match in (str .. separator):gmatch("(.-)" .. separator) do
      table.insert(result, match)
    end
    return result
  end,

  --- Trims leading and trailing whitespace from a string.
  -- @param str string The string to trim.
  -- @return string|nil The trimmed string, or nil + error on invalid input.
  -- @return table|nil An error object if input validation fails.
  trim = function(str)
    if type(str) ~= "string" then
      return nil, error_handler.validation_error("Expected string", { parameter = "str", provided_type = type(str) })
    end

    return str:match("^%s*(.-)%s*$")
  end,
}

-- Performance tests with assertions
--- Test suite demonstrating how to integrate benchmarks into Firmo tests
-- with performance assertions.
describe("String Utils Performance", function()
  -- Test join performance
  it("joins strings efficiently", function()
    -- Create test data
    local strings = {}
    for i = 1, 1000 do
      strings[i] = "item" .. i
    end

    -- Benchmark join
    local result = benchmark.run(function()
      return string_utils.join(strings, ",")
    end, { iterations = 100, name = "String Join" })

    -- Assert performance requirements
    expect(result.average_time).to.be_less_than(10, "Join operation too slow")

    -- Output performance info

    -- Output performance info
    logger.info("\nJoin Performance:")
    print("\nJoin Performance:") -- Keep print for results

    -- Output performance info
    logger.info("\nJoin Performance:")
    print("\nJoin Performance:") -- Keep print for results
    print("Average time: " .. result.average_time .. " ms")
      -- Create array of 1000 items
      (function()
        local arr = {}
        for i = 1, 1000 do
          arr[i] = "item" .. i
        end
        return arr
      end)
      ()

    -- Benchmark split
    local result = benchmark.run(function()
      return string_utils.split(joined, ",")
    end, { iterations = 100, name = "String Split" })

    -- Assert performance requirements
    expect(result.average_time).to.be_less_than(20, "Split operation too slow")

    -- Output performance info

    -- Output performance info
    logger.info("\nSplit Performance:")
    print("\nSplit Performance:") -- Keep print for results
  end)
end)
