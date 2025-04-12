# Coverage Knowledge

## Purpose
Track and analyze code coverage during test execution using a debug hook-based system adapted from LuaCov.

## Coverage Usage
```lua
-- Enable coverage tracking
local coverage = require("lib.coverage")
coverage.start({
  include = { "src/**/*.lua" },
  exclude = { "tests/" },
  threshold = 90
})

-- Since we're using a debug hook system, files are automatically tracked
-- when they're loaded/executed, no need to explicitly track files

-- Generate reports
coverage.report({
  format = "html",
  output = "coverage/index.html",
  include_source = true
})

-- Complex coverage example
describe("Coverage tracking", function()
  before_each(function()
    coverage.reset()
    coverage.start({
      include = { "src/calculator.lua" }
    })
  end)
  
  it("tracks line coverage", function()
    local calc = require("src.calculator")
    calc.add(2, 3)
    
    local stats = coverage.get_stats()
    expect(stats.lines.covered).to.be_greater_than(0)
  end)
  
  it("tracks different execution paths", function()
    local calc = require("src.calculator")
    calc.divide(6, 2)  -- Success path
    calc.divide(1, 0)  -- Error path
    
    local stats = coverage.get_stats()
    expect(stats.lines.covered).to.be_greater_than(4) -- Assuming at least 5 lines are covered
  end)
  
  after_each(function()
    coverage.stop()
  end)
end)
```

## Coverage Data Structure
```lua
-- Coverage states (for visualization)
local states = {
  COVERED = "green",    -- Executed during test runs
  NOT_COVERED = "red"   -- Never executed
}

-- Coverage classification
local function classify_line(line, hits)
  if hits > 0 then return "COVERED"
  else return "NOT_COVERED" end
end

-- Coverage data structure (using the debug hook approach)
local coverage_data = {
  stats = {
    lines = { total = 0, covered = 0 }
  },
  files = {
    ["file.lua"] = {
      lines = {
        [1] = 5,  -- Line was hit 5 times
        [2] = 3,  -- Line was hit 3 times
        [3] = 0   -- Line was never hit
      }
    }
  }
}
```

## Error Handling
```lua
-- Safe coverage tracking
local function with_coverage(callback)
  coverage.start()
  
  local result, err = error_handler.try(function()
    return callback()
  end)
  
  coverage.stop()
  
  if not result then
    return nil, err
  end
  return result
end

-- Handle debug hook errors
local function safe_coverage_run(options)
  local success, err = pcall(function()
    coverage.start(options)
  end)
  
  if not success then
    logger.error("Coverage start failed", {
      error = err
    })
    return nil, err
  end
  
  return true
end
```

## Debug Hook System
```lua
-- How the debug hook system works
local function setup_debug_hook()
  -- Store original hook if it exists
  local original_hook = debug.gethook()
  
  -- Set our coverage hook
  debug.sethook(function(event, line)
    if event == "line" then
      -- Record that this line was executed
      record_line_execution(line)
    end
  end, "l")
  
  -- Return a function to restore the original hook
  return function()
    if original_hook then
      debug.sethook(original_hook)
    else
      debug.sethook()
    end
  end
end
```

## Critical Rules
- NEVER import coverage in test files directly
- NEVER manually modify coverage data
- NEVER create workarounds for the debug hook
- ALWAYS use central_config for coverage settings
- ALWAYS run tests via test.lua (which handles coverage setup)
- NEVER skip error handling when working with debug hooks
- ALWAYS clean up state by stopping coverage
- NEVER set your own debug hooks that might interfere with coverage

## Best Practices
- Use central configuration for all coverage settings
- Be aware of the performance impact of debug hooks
- Clean up coverage data between test runs
- Use appropriate formatters for different report types
- Monitor memory usage with large codebases
- Run coverage in isolated environments when possible
- Document file exclusions with clear reasons
- Handle edge cases in multi-threaded/coroutine code
- Clean up resources by explicitly stopping coverage
- Be careful when using other debug hook-based tools

## Performance Tips
- Limit coverage scope to relevant files only
- Stream large reports to avoid memory issues
- Clean up coverage data between test runs
- Monitor memory usage with large codebases
- Handle potential slowdowns in debug hook execution
- Optimize storage of coverage data for large files
- Cache results when generating multiple reports
- Consider the performance impact of debug hooks on recursive functions
- Disable coverage for performance-critical tests when necessary
