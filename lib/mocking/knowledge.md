# Mocking Knowledge

## Purpose
Provides mocking, stubbing, and spying capabilities for tests.

## Mock Types and Usage
```lua
-- Function spy
local spy = firmo.spy(function(x) return x * 2 end)
spy(5)
expect(spy).to.be.called()
expect(spy[1][1]).to.equal(5)

-- Method stub
local stub = firmo.stub.on(table, "method")
  .returns("stubbed value")
expect(table.method()).to.equal("stubbed value")

-- Full mock
local mock = firmo.mock.new()
mock.method.returns("mocked")
expect(mock.method()).to.equal("mocked")

-- Return sequence
local sequence = firmo.mock.sequence()
  .returns(1)
  .returns(2)
  .raises("error")

-- Complex mocking scenario
describe("Database operations", function()
  local db, api, service
  
  before_each(function()
    -- Create mocks
    db = firmo.mock.new()
    api = firmo.mock.new()
    
    -- Configure mock behavior
    db.connect.returns({ connected = true })
    db.query.returns({ rows = 5 })
    api.fetch.returns({ data = "test" })
    
    -- Create service with mocks
    service = create_service(db, api)
  end)
  
  it("processes data correctly", function()
    local result = service.process_data()
    
    expect(db.connect).to.be.called()
    expect(db.query).to.be.called_with("SELECT * FROM data")
    expect(api.fetch).to.be.called()
    expect(result.success).to.be_truthy()
  end)
end)
```

## Mock Verification
```lua
-- Call count verification
expect(spy.call_count).to.equal(1)

-- Arguments verification
expect(spy).to.be.called_with(5)

-- Call order verification
expect(mock).to.be.called_in_order({
  {method = "first", args = {1}},
  {method = "second", args = {2}}
})

-- Complex expectations
mock.expect("method")
  .with(1, 2)
  .to.be.called.times(2)
  .returns("result")

-- Verify all expectations
mock:verify()
```

## Error Handling
```lua
-- Mock error handling
it("handles mock errors", { expect_error = true }, function()
  local mock = firmo.mock.new()
  mock.method.raises("test error")
  
  local result, err = test_helper.with_error_capture(function()
    return mock.method()
  end)()
  
  expect(err).to.exist()
  expect(err.message).to.equal("test error")
end)

-- Handle verification errors
it("verifies all calls", { expect_error = true }, function()
  local mock = firmo.mock.new()
  mock.expect("method").to.be.called()
  
  local _, err = test_helper.with_error_capture(function()
    mock:verify()
  end)()
  
  expect(err).to.exist()
  expect(err.message).to.match("expected method to be called")
end)

-- Resource cleanup
local function with_mock(callback)
  local mock = firmo.mock.new()
  local result, err = error_handler.try(function()
    return callback(mock)
  end)
  
  mock:restore()
  
  if not result then
    return nil, err
  end
  return result
end
```

## Critical Rules
- Clean up mocks after use
- Verify all expectations
- Keep mocks simple
- Document behavior
- Handle cleanup properly
- Test thoroughly
- Monitor performance
- Handle errors

## Best Practices
- Use appropriate mock type
- Verify call counts
- Check arguments
- Clean up resources
- Document behavior
- Handle errors
- Test edge cases
- Keep mocks focused
- Follow patterns
- Use helpers

## Performance Tips
- Minimize mock complexity
- Clean up promptly
- Use simple stubs
- Avoid deep chains
- Clear state between tests
- Cache results
- Monitor memory
- Handle timeouts