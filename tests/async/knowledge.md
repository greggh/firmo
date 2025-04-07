# Async Testing Knowledge

## Purpose
Test asynchronous operations with proper timing and execution.

## Async Test Patterns
```lua
-- Basic async test with callback
it.async("completes async operation", function(done)
  start_async_operation(function(result)
    expect(result).to.exist()
    done()
  end)
end)

-- Using wait_until for conditions
it.async("waits for condition", function()
  local value = false
  setTimeout(function() value = true end, 50)
  
  firmo.wait_until(function() 
    return value 
  end, 200) -- 200ms timeout
  
  expect(value).to.be_truthy()
end)

-- Custom timeouts
it("tests with custom timeout", firmo.async(function()
  firmo.await(500)
  expect(true).to.be_truthy()
end, 1000)) -- 1 second timeout

-- Parallel operations
it.async("handles parallel operations", function()
  local function op1() await(100); return "op1" end
  local function op2() await(200); return "op2" end
  
  local results = parallel_async({op1, op2})
  expect(#results).to.equal(2)
end)

-- Database operations example
it.async("handles database operations", function(done)
  local db = require("database")
  
  -- Setup test data
  before_each(function()
    db.connect()
    db.clear_test_data()
  end)
  
  -- Cleanup
  after_each(function()
    db.disconnect()
  end)
  
  -- Test async operation
  db.insert({ id = 1 }, function(err, result)
    expect(err).to_not.exist()
    expect(result.id).to.equal(1)
    done()
  end)
end)
```

## Error Handling
```lua
-- Async error handling
it.async("handles async errors", { expect_error = true }, function(done)
  start_async_operation(function(result, err)
    if err then
      expect(err).to.exist()
      expect(err.message).to.match("timeout")
      done()
      return
    end
    done(err) -- Fail test if no error
  end)
end)

-- Timeout handling
it.async("handles timeouts", { timeout = 1000 }, function(done)
  firmo.wait_until(function()
    return check_condition()
  end, 500, function(success)
    expect(success).to.be_truthy()
    done()
  end)
end)

-- Resource cleanup
it.async("cleans up resources", function(done)
  local resources = {}
  
  after(function()
    for _, resource in ipairs(resources) do
      resource:cleanup()
    end
  end)
  
  -- Test code...
  done()
end)
```

## Critical Rules
- ALWAYS call done() callback
- NEVER forget timeouts
- ALWAYS clean up resources
- NEVER leave hanging operations
- ALWAYS handle errors
- NEVER skip error cases
- ALWAYS verify async state
- NEVER assume operation order

## Best Practices
- Set appropriate timeouts
- Clean up resources
- Handle both success/error
- Test edge cases
- Document async flow
- Use helper functions
- Monitor performance
- Handle race conditions
- Test error paths
- Verify final state

## Common Pitfalls
```lua
-- WRONG:
it.async("forgets done", function(done)
  async_op(function()
    expect(true).to.be_truthy()
    -- Forgot to call done()
  end)
end)

-- CORRECT:
it.async("calls done properly", function(done)
  async_op(function()
    expect(true).to.be_truthy()
    done()
  end)
end)
```