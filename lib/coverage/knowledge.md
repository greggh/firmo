# Coverage Knowledge

## Purpose
Track and analyze code coverage during test execution.

## Coverage Usage
```lua
-- Enable coverage tracking
local coverage = require("lib.coverage")
coverage.start({
  include = { "src/**/*.lua" },
  exclude = { "tests/" },
  threshold = 90
})

-- Track specific file
coverage.track_file("src/module.lua", {
  track_lines = true,
  track_branches = true,
  track_functions = true
})

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
      include = { "src/calculator.lua" },
      track_branches = true
    })
  end)
  
  it("tracks function coverage", function()
    local calc = require("src.calculator")
    calc.add(2, 3)
    
    local stats = coverage.get_stats()
    expect(stats.functions.covered).to.be_greater_than(0)
  end)
  
  it("tracks branch coverage", function()
    local calc = require("src.calculator")
    calc.divide(6, 2)  -- Success path
    calc.divide(1, 0)  -- Error path
    
    local stats = coverage.get_stats()
    expect(stats.branches.covered).to.equal(2)
  end)
  
  after_each(function()
    coverage.stop()
  end)
end)
```

## Three-State Coverage
```lua
-- Coverage states
local states = {
  COVERED = "green",    -- Executed + verified by assertions
  EXECUTED = "yellow",  -- Run but not verified
  NOT_COVERED = "red"   -- Never executed
}

-- Coverage classification
local function classify_line(line)
  if line.covered then return "COVERED"
  elseif line.executed then return "EXECUTED"
  else return "NOT_COVERED" end
end

-- Coverage data structure
local coverage_data = {
  files = {
    ["file.lua"] = {
      lines = {
        [1] = { executed = true, covered = true },
        [2] = { executed = true, covered = false },
        [3] = { executed = false, covered = false }
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

-- Handle instrumentation errors
local function safe_instrument(file_path)
  if not fs.file_exists(file_path) then
    return nil, error_handler.io_error(
      "File not found",
      { path = file_path }
    )
  end
  
  local success, err = coverage.instrument_file(file_path)
  if not success then
    logger.error("Instrumentation failed", {
      file = file_path,
      error = err
    })
    return nil, err
  end
  
  return true
end
```

## Critical Rules
- NEVER import in test files
- NEVER manually set coverage
- NEVER create workarounds
- ALWAYS use central_config
- NEVER modify coverage data
- ALWAYS run via test.lua
- NEVER skip error handling
- ALWAYS clean up state

## Best Practices
- Use central configuration
- Handle large files
- Clean up coverage data
- Use appropriate formatters
- Monitor memory usage
- Track branches
- Verify assertions
- Document exclusions
- Handle edge cases
- Clean up resources

## Performance Tips
- Stream large reports
- Use efficient tracking
- Clean up data
- Monitor memory
- Handle timeouts
- Optimize storage
- Cache results
- Batch operations