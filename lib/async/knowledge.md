# Async Knowledge

## Purpose
Provides asynchronous testing capabilities for time-dependent operations.

## Async Test Patterns
```lua
-- Basic async test
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

-- Complex async scenario
describe("Database operations", function()
  local db
  
  before_each(function()
    db = require("database")
    db.connect()
  end)
  
  it.async("handles concurrent operations", function(done)
    local results = {}
    local pending = 3
    
    local function check_done()
      pending = pending - 1
      if pending == 0 then
        expect(#results).to.equal(3)
        done()
      end
    end
    
    -- Start multiple async operations
    db.query("SELECT 1", function(err, result)
      if not err then table.insert(results, result) end
      check_done()
    end)
    
    db.query("SELECT 2", function(err, result)
      if not err then table.insert(results, result) end
      check_done()
    end)
    
    db.query("SELECT 3", function(err, result)
      if not err then table.insert(results, result) end
      check_done()
    end)
  end)
  
  after_each(function()
    db.disconnect()
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

-- Complex error scenario
it.async("handles complex errors", { expect_error = true }, function(done)
  local db = require("database")
  
  -- Start transaction
  db.begin_transaction(function(err)
    if err then return done(err) end
    
    -- Perform operations
    db.query("INSERT ...", function(err)
      if err then
        -- Rollback on error
        return db.rollback_transaction(function()
          expect(err).to.exist()
          done()
        end)
      end
      
      -- Commit if successful
      db.commit_transaction(function(commit_err)
        if commit_err then
          return db.rollback_transaction(function()
            expect(commit_err).to.exist()
            done()
          end)
        end
        done()
      end)
    end)
  end)
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

## Performance Tips
- Set appropriate timeouts
- Use parallel operations
- Clean up resources
- Monitor memory
- Handle race conditions
- Batch operations
- Cache results
- Use efficient checks