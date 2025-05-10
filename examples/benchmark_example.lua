--- Comprehensive example demonstrating the Firmo benchmark module.
---
--- This example showcases various features of the `lib.tools.benchmark` module:
--- - Basic benchmarking of a single function using `benchmark.measure()`.
--- - Benchmarking functions with arguments.
--- - Comparing the performance of multiple implementations by running individual benchmarks.
--- - Configuring benchmark runs (iterations, warmup iterations, name).
--- - Example concepts for measuring memory usage during benchmarks (not a built-in feature).
--- - Example concepts for performing statistical analysis on benchmark results (percentiles, outliers - not built-in features).
--- - Integrating benchmark runs into Firmo tests (`describe`, `it`) and making performance assertions (`expect(...).to.be_less_than`).
--- - Demonstrates best practices like warming up the JIT compiler.
---
--- @module examples.benchmark_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
--- @see lib.tools.benchmark
--- @usage
--- Run this example directly to see benchmark output printed to the console:
--- ```bash
--- lua examples/benchmark_example.lua
--- ```
--- Run the embedded performance tests using the Firmo test runner:
--- ```bash
--- lua firmo.lua examples/benchmark_example.lua
--- ```

-- Import required modules
local benchmark = require("lib.tools.benchmark")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

-- Set up logging
local logger = logging.get_logger("BenchmarkExample")

logger.info("\n== BENCHMARK MODULE EXAMPLE ==\n")
logger.info("PART 1: Basic Benchmarking\n")

-- Example 1: Simple function benchmark
logger.info("Example 1: Simple Function Benchmark")
--- Simple function for demonstrating benchmarking: concatenates strings using `..`.
--- @param count number The number of times to concatenate 'x'.
--- @return string The resulting concatenated string.
--- @within examples.benchmark_example
function concat_strings(count)
  local result = ""
  for i = 1, count do
    result = result .. "x"
  end
  return result
end

-- Benchmark the function using benchmark.measure
local concat_result = benchmark.measure(
  function()
    return concat_strings(1000)
  end, -- Function to benchmark
  nil, -- No specific arguments needed here for the outer function
  { iterations = 1000, label = "String Concatenation" } -- Options: iterations and label
)

-- Display benchmark results using the correct stats structure
logger.info("\nString Concatenation Results:")
if concat_result and concat_result.time_stats then
  print("Total time: " .. (concat_result.time_stats.total * 1000) .. " ms") -- Convert seconds to ms
  print("Average time: " .. (concat_result.time_stats.mean * 1000) .. " ms per iteration")
  print("Iterations: " .. concat_result.iterations)
  print("Min time: " .. (concat_result.time_stats.min * 1000) .. " ms")
  print("Max time: " .. (concat_result.time_stats.max * 1000) .. " ms")
  print("Standard deviation: " .. (concat_result.time_stats.std_dev * 1000) .. " ms")
else
  print("Error: Benchmark result or time_stats missing.")
end

-- Example 2: Function with arguments
logger.info("\nExample 2: Function with Arguments")
--- Simple recursive factorial function for benchmarking.
--- @param n number The non-negative integer to calculate the factorial of.
--- @return number The factorial of n.
--- @within examples.benchmark_example
function calculate_factorial(n)
  if n <= 1 then
    return 1
  end
  return n * calculate_factorial(n - 1)
end

-- Benchmark with different arguments
local factorial_results = {}
for n = 5, 25, 5 do
  -- Benchmark using measure, passing 'n' as an argument via the args table
  local result = benchmark.measure(
    calculate_factorial, -- The function itself
    { n }, -- Arguments table
    { iterations = 100, label = "Factorial " .. n } -- Options
  )
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
  if result and result.time_stats then
    print(string.format(
      "%-15d %-15.6f %-15.6f %-15.6f",
      n,
      result.time_stats.mean * 1000, -- Convert to ms
      result.time_stats.min * 1000, -- Convert to ms
      result.time_stats.max * 1000 -- Convert to ms
    ))
  else
    print(string.format("%-15d %-15s %-15s %-15s", n, "ERROR", "ERROR", "ERROR"))
  end
end

-- Example 3: Benchmarking different implementations
logger.info("\nExample 3: Comparing Different Implementations")
--- String building implementation using basic concatenation (`..`).
--- @param count number The number of times to concatenate 'x'.
--- @return string The resulting string.
--- @within examples.benchmark_example
function string_concat(count)
  local result = ""
  for i = 1, count do
    result = result .. "x"
  end
  return result
end

--- String building implementation using table insertion and `table.concat`. Generally faster for many concatenations.
--- @param count number The number of times to insert 'x' into the table.
--- @return string The resulting string.
--- @within examples.benchmark_example
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

-- Measure each implementation individually
local comparison_results = {}
for name, func in pairs(implementations) do
  local result = benchmark.measure(func, nil, { iterations = 100, label = name })
  comparison_results[name] = result
end

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

-- Find the fastest average time for relative speed calculation
local fastest_time = nil
for _, result in pairs(comparison_results) do
  if result and result.time_stats then
    if fastest_time == nil or result.time_stats.mean < fastest_time then
      fastest_time = result.time_stats.mean
    end
  end
end

-- Print the comparison table
for name, result in pairs(comparison_results) do
  if result and result.time_stats and fastest_time and fastest_time > 0 and result.time_stats.mean > 0 then
    local relative_speed = fastest_time / result.time_stats.mean
    print(string.format(
      "%-25s %-15.6f %-15.6f %-15.6f %-15.2fx",
      name,
      result.time_stats.mean * 1000, -- ms
      result.time_stats.min * 1000, -- ms
      result.time_stats.max * 1000, -- ms
      relative_speed
    ))
  else
    print(string.format("%-25s %-15s %-15s %-15s %-15s", name, "ERROR", "ERROR", "ERROR", "ERROR"))
  end
end

-- PART 2: Advanced Benchmarking
logger.info("\nPART 2: Advanced Benchmarking\n")

-- Example 4: Memory Usage Benchmarking
logger.info("Example 4: Memory Usage Benchmarking")
--- Gets the current memory usage reported by Lua's garbage collector.
--- Performs a full garbage collection cycle before reporting the count.
--- @return number The amount of memory currently used by Lua, in kilobytes.
--- @within examples.benchmark_example
function get_memory_usage()
  collectgarbage("collect") -- Force garbage collection
  return collectgarbage("count") -- Return memory usage in KB
end

--- Example function to benchmark the memory usage of another function.
--- This measures memory before, during (peak), and after execution and garbage collection.
--- Note: This is a conceptual example; actual memory profiling is complex.
--- @param func function The function to benchmark for memory usage.
--- @param config? table Optional configuration: `{ iterations?: number, warmup_iterations?: number }`.
--- @return table results A table containing memory usage metrics: `{ peak_memory: number, peak_increase: number, retained_memory: number, iterations: number }`.
--- @within examples.benchmark_example
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
--- Example bubble sort implementation for benchmarking comparison. Sorts a copy of the input array.
--- @param array number[] The array to sort.
--- @return number[] A new table containing the sorted elements.
--- @within examples.benchmark_example
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
--- Example insertion sort implementation for benchmarking comparison. Sorts a copy of the input array.
--- @param array number[] The array to sort.
--- @return number[] A new table containing the sorted elements.
--- @within examples.benchmark_example
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
--- Wrapper around Lua's native `table.sort` for benchmarking comparison. Sorts a copy of the input array.
--- @param array number[] The array to sort.
--- @return number[] A new table containing the sorted elements.
--- @within examples.benchmark_example
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
--- Helper function to generate an array of random numbers for sorting benchmarks.
--- @param size number The desired size of the array.
--- @return number[] An array containing `size` random integers between 1 and 1000.
--- @within examples.benchmark_example
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

-- Measure each sort function individually
local sort_results = {}
for name, func in pairs(sort_funcs) do
  local result = benchmark.measure(
    func, -- The sort function
    nil, -- No extra args needed for the wrapper
    { iterations = 10, warmup = 3, label = name } -- Options
  )
  sort_results[name] = result
end

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

-- Find the fastest average sort time
local fastest_sort_time = nil
for _, result in pairs(sort_results) do
  if result and result.time_stats then
    if fastest_sort_time == nil or result.time_stats.mean < fastest_sort_time then
      fastest_sort_time = result.time_stats.mean
    end
  end
end

-- Print the sort comparison table
for name, result in pairs(sort_results) do
  if result and result.time_stats and fastest_sort_time and fastest_sort_time > 0 and result.time_stats.mean > 0 then
    local relative_speed = fastest_sort_time / result.time_stats.mean
    print(string.format(
      "%-20s %-15.6f %-15.6f %-15.6f %-15.2fx",
      name,
      result.time_stats.mean * 1000, -- ms
      result.time_stats.min * 1000, -- ms
      result.time_stats.max * 1000, -- ms
      relative_speed
    ))
  else
    print(string.format("%-20s %-15s %-15s %-15s %-15s", name, "ERROR", "ERROR", "ERROR", "ERROR"))
  end
end

-- Example 6: Profiling Call Frequency
logger.info("\nExample 6: Profiling Call Frequency")
-- Create a profiler to track function calls
local call_counter = {}
setmetatable(call_counter, { __mode = "k" }) -- Weak keys

function track_call(func_name)
  call_counter[func_name] = (call_counter[func_name] or 0) + 1
end

--- Simple recursive Fibonacci implementation for profiling call counts.
--- @param n number The index of the Fibonacci number to calculate.
--- @return number The nth Fibonacci number.
--- @within examples.benchmark_example
function fibonacci_recursive(n)
  track_call("fibonacci_recursive")
  if n <= 1 then
    return n
  end
  return fibonacci_recursive(n - 1) + fibonacci_recursive(n - 2)
end

--- Iterative Fibonacci implementation for profiling call counts.
--- @param n number The index of the Fibonacci number to calculate.
--- @return number The nth Fibonacci number.
--- @within examples.benchmark_example
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
--- Calculates specified percentiles from a list of timing measurements.
--- Note: This is a simple percentile calculation example. More robust methods exist.
--- @param times number[] An array of numerical timing measurements (e.g., in milliseconds).
--- @param percentiles number[] An array of percentile values to calculate (e.g., `{50, 90, 99}`).
--- @return table A table mapping each requested percentile (number) to its corresponding value from the sorted times array.
--- @within examples.benchmark_example
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
--- Detects outliers in a list of timings based on a simple standard deviation threshold (e.g., 3 standard deviations).
--- Note: This is a basic outlier detection method. More sophisticated techniques exist.
--- @param times number[] An array of numerical timing measurements.
--- @param mean number The pre-calculated mean (average) of the `times`.
--- @param std_dev number The pre-calculated standard deviation of the `times`.
--- @return table outliers An array of tables, where each table represents an outlier: `{ index: number, value: number }`.
--- @return number lower_bound The calculated lower threshold (mean - 3 * std_dev).
--- @return number upper_bound The calculated upper threshold (mean + 3 * std_dev).
--- @within examples.benchmark_example
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

  -- Display clean statistics
  logger.info("\nStatistics without outliers:")
  print("\nStatistics without outliers:") -- Keep print for results
  print("Mean execution time: " .. clean_mean .. " ms")
end

-- PART 4: Benchmarking in Tests
logger.info("\nPART 4: Benchmarking in Tests\n")

-- Example 9: Performance Testing with Firmo
logger.info("Example 9: Performance Testing with Firmo")
--- Example module with string utility functions to be tested for performance.
--- @class StringUtils
--- @field join fun(strings: table, separator?: string): string|nil, table|nil Joins strings.
--- @field split fun(str: string, separator?: string): table|nil, table|nil Splits a string.
--- @field trim fun(str: string): string|nil, table|nil Trims whitespace.
--- @within examples.benchmark_example
local string_utils = {
  --- Joins a table of strings with a specified separator. Uses `table.concat`.
  -- @param strings table An array-like table of strings to join.
  -- @param separator? string The separator string to use (default: ",").
  -- @return string|nil The concatenated string, or `nil` on error.
  -- @return table|nil An error object if `strings` is not a table.
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

  --- Splits a string into a table of substrings using a separator pattern. Uses `gmatch`.
  -- @param str string The input string to split.
  -- @param separator? string The separator pattern (default: ","). Note: Lua pattern characters should be escaped if literal matching is needed.
  -- @return table|nil An array-like table of substrings, or `nil` on error.
  -- @return table|nil An error object if `str` is not a string.
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

  --- Trims leading and trailing whitespace from a string using string patterns.
  -- @param str string The input string.
  -- @return string|nil The trimmed string, or `nil` on error.
  -- @return table|nil An error object if `str` is not a string.
  trim = function(str)
    if type(str) ~= "string" then
      return nil, error_handler.validation_error("Expected string", { parameter = "str", provided_type = type(str) })
    end

    return str:match("^%s*(.-)%s*$")
  end,
}

-- Performance tests with assertions
--- Test suite demonstrating how to integrate benchmarks into Firmo tests
-- with performance assertions using `expect`.
--- @within examples.benchmark_example
describe("String Utils Performance", function()
  --- Tests the performance of the `string_utils.join` function.
  it("joins 1000 strings efficiently", function()
    -- Create test data (array of 1000 strings)
    local strings = {}
    for i = 1, 1000 do
      strings[i] = "item" .. i
    end

    -- Benchmark join using measure
    local result = benchmark.measure(
      string_utils.join, -- Function
      { strings, "," }, -- Arguments table
      { iterations = 100, label = "String Join" } -- Options
    )

    -- Assert performance requirements using correct stats path
    expect(result.time_stats.mean * 1000).to.be_less_than(10, "Join operation too slow")

    -- Output performance info
    logger.info("\nJoin Performance:")
    print("\nJoin Performance:") -- Keep print for results
    print("Average time (join): " .. (result.time_stats.mean * 1000) .. " ms")
  end)

  --- Tests the performance of the `string_utils.split` function.
  it("splits a long string efficiently", function()
    -- Create test data (a long comma-separated string)
    local items = {}
    for i = 1, 1000 do
      items[i] = "item" .. i
    end
    local joined_string = table.concat(items, ",") -- Generate the actual string

    -- Benchmark split using measure
    local result = benchmark.measure(
      string_utils.split, -- Function
      { joined_string, "," }, -- Arguments table: pass the generated string
      { iterations = 100, label = "String Split" } -- Options
    )

    -- Assert performance requirements using correct stats path
    expect(result.time_stats.mean * 1000).to.be_less_than(20, "Split operation too slow")
    print("Average time (split): " .. (result.time_stats.mean * 1000) .. " ms")
  end)
end)
