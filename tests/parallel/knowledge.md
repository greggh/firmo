# Parallel Knowledge

## Purpose
Test multi-process test execution and parallel operations.

## Parallel Test Patterns
```lua
-- Basic parallel execution
firmo.run_tests({
  path = "tests/",
  parallel = true,
  process_count = 4
})

-- With shared resources
describe("Database tests", function()
  -- Use unique database for each process
  before(function()
    local process_id = firmo.get_process_id()
    db.connect("test_db_" .. process_id)
  end)
  
  after(function()
    db.disconnect()
  end)
end)

-- Parallel async tests
it.async("runs in parallel", function(done)
  local results = parallel_async({
    function() return heavy_task_1() end,
    function() return heavy_task_2() end
  })
  expect(#results).to.equal(2)
  done()
end)

-- Resource management
local function get_temp_path()
  local process_id = firmo.get_process_id()
  return os.tmpname() .. "_" .. process_id
end

-- Database connections
local function get_db_name()
  return "test_db_" .. firmo.get_process_id()
end

-- Complex parallel scenario
describe("Parallel file processing", function()
  local files = {}
  
  before_all(function()
    -- Create test files
    for i = 1, 100 do
      local path = get_temp_path()
      fs.write_file(path, "content " .. i)
      table.insert(files, path)
    end
  end)
  
  it("processes files in parallel", function()
    local results = parallel.map(files, function(file)
      local content = fs.read_file(file)
      return process_content(content)
    end, {
      chunk_size = 10,
      timeout = 5000
    })
    
    expect(#results).to.equal(100)
  end)
  
  after_all(function()
    -- Clean up files
    for _, file in ipairs(files) do
      fs.delete_file(file)
    end
  end)
end)
```

## Error Handling
```lua
-- Handle parallel errors
it("handles parallel errors", { expect_error = true }, function()
  local results = parallel_async({
    function() error("test error") end,
    function() return "success" end
  })
  
  expect(results.errors[1]).to.exist()
  expect(results[2]).to.equal("success")
end)

-- Handle timeouts
it("handles timeouts", function()
  local results = parallel.run_with_timeout({
    slow_task = function() 
      os.execute("sleep 10")
    end
  }, 1000)
  
  expect(results.timeouts.slow_task).to.be_truthy()
end)
```

## Critical Rules
- Handle shared resources
- Manage timeouts
- Merge results properly
- Clean up processes
- Ensure test isolation

## Best Practices
- Use process IDs
- Handle resources
- Set timeouts
- Check results
- Clean up properly
- Monitor memory
- Handle errors
- Document patterns
- Test thoroughly
- Verify isolation

## Performance Tips
- Set chunk sizes
- Monitor resources
- Handle timeouts
- Clean up promptly
- Use batching
- Cache results