# Performance Knowledge

## Purpose
Test performance measurement capabilities and benchmarking.

## Benchmarking Patterns
```lua
-- Basic benchmark
local benchmark = firmo.benchmark.new("operation_name")
benchmark.run(function()
  -- Code to benchmark
end)
benchmark.report()

-- Advanced configuration
local benchmark = firmo.benchmark.new("operation_name", {
  iterations = 1000,
  warmup = 100,
  report_memory = true,
  timeout = 5000
})

-- Memory tracking
local usage = benchmark.track_memory(function()
  local large_table = {}
  for i = 1, 1000000 do
    large_table[i] = i
  end
end)

expect(usage.peak).to.be_greater_than(0)
expect(usage.final - usage.initial).to.be_greater_than(0)

-- Complex benchmarking scenario
describe("Performance testing", function()
  local function setup_test_data(size)
    local data = {}
    for i = 1, size do
      data[i] = string.rep("x", 100)
    end
    return data
  end
  
  it("measures processing performance", function()
    local sizes = {1000, 10000, 100000}
    local results = {}
    
    for _, size in ipairs(sizes) do
      local data = setup_test_data(size)
      
      local bench = benchmark.measure(function()
        return process_data(data)
      end, nil, {
        iterations = 10,
        label = "size_" .. size
      })
      
      results[size] = bench
    end
    
    -- Compare results
    local comparison = benchmark.compare(results[1000], results[10000])
    expect(comparison.ratio).to.be_less_than(10)
  end)
end)
```

## Memory Management
```lua
-- Track memory leaks
local function check_memory_leak()
  local initial = collectgarbage("count")
  
  -- Run operation multiple times
  for i = 1, 1000 do
    local result = operation()
    result = nil
  end
  
  collectgarbage("collect")
  local final = collectgarbage("count")
  
  return final - initial
end

-- Monitor resource usage
local function monitor_resources(fn)
  local stats = {
    memory_initial = collectgarbage("count"),
    time_start = os.clock()
  }
  
  local result = fn()
  
  stats.time_end = os.clock()
  collectgarbage("collect")
  stats.memory_final = collectgarbage("count")
  
  return result, stats
end
```

## Critical Rules
- Set baselines
- Handle variations
- Clean up resources
- Document metrics
- Test consistency

## Best Practices
- Use warmup runs
- Clean up between tests
- Monitor memory
- Handle timeouts
- Document thresholds
- Test edge cases
- Verify results
- Handle errors
- Clean up resources
- Monitor trends

## Performance Tips
- Use appropriate iterations
- Clean up resources
- Monitor memory
- Handle timeouts
- Document thresholds
- Batch operations
- Cache results