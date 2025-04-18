-- Example demonstrating comprehensive mocking functionality
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")

-- Extract testing functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local mock, spy, stub, with_mocks = firmo.mock, firmo.spy, firmo.stub, firmo.with_mocks

-- A sample "database" module we'll use to demonstrate mocking
local database = {
  connect = function(db_name)
    if type(db_name) ~= "string" or db_name == "" then
      return nil, error_handler.validation_error(
        "Database name must be a non-empty string",
        {parameter = "db_name", provided_type = type(db_name)}
      )
    end
    
    -- In a real implementation, this would actually connect to a database
    print("Actually connecting to real database: " .. db_name)
    return {
      connected = true,
      name = db_name
    }
  end,
  
  query = function(db, query_string)
    if type(db) ~= "table" or not db.connected then
      return nil, error_handler.validation_error(
        "Database connection required",
        {parameter = "db", provided_type = type(db)}
      )
    end
    
    if type(query_string) ~= "string" or query_string == "" then
      return nil, error_handler.validation_error(
        "Query must be a non-empty string",
        {parameter = "query_string", provided_type = type(query_string)}
      )
    end
    
    -- In a real implementation, this would execute the query
    print("Actually executing query on " .. db.name .. ": " .. query_string)
    
    -- Simulate errors
    if query_string:match("ERROR") then
      return nil, error_handler.database_error(
        "Database query failed",
        {query = query_string, db_name = db.name}
      )
    end
    
    return {
      rows = { {id = 1, name = "test"}, {id = 2, name = "sample"} },
      count = 2
    }
  end,
  
  disconnect = function(db)
    if type(db) ~= "table" then
      return nil, error_handler.validation_error(
        "Database connection required",
        {parameter = "db", provided_type = type(db)}
      )
    end
    
    -- In a real implementation, this would disconnect
    print("Actually disconnecting from " .. db.name)
    db.connected = false
    return true
  end
}

-- A "user service" module that depends on the database
local UserService = {
  get_users = function()
    local db, connect_err = database.connect("users")
    if not db then
      return nil, error_handler.wrap_error(
        connect_err,
        "Failed to connect to users database",
        {operation = "get_users"}
      )
    end
    
    local result, query_err = database.query(db, "SELECT * FROM users")
    if not result then
      database.disconnect(db)
      return nil, error_handler.wrap_error(
        query_err,
        "Failed to fetch users",
        {operation = "get_users"}
      )
    end
    
    database.disconnect(db)
    return result.rows
  end,
  
  find_user = function(id)
    if type(id) ~= "number" or id < 1 then
      return nil, error_handler.validation_error(
        "User ID must be a positive number",
        {parameter = "id", provided_value = id}
      )
    end
    
    local db, connect_err = database.connect("users")
    if not db then
      return nil, error_handler.wrap_error(connect_err)
    end
    
    local result, query_err = database.query(db, "SELECT * FROM users WHERE id = " .. id)
    if not result then
      database.disconnect(db)
      return nil, error_handler.wrap_error(query_err)
    end
    
    database.disconnect(db)
    return result.rows[1]
  end,
  
  create_user = function(user)
    if type(user) ~= "table" or not user.name then
      return nil, error_handler.validation_error(
        "User must be a table with a name field",
        {parameter = "user", provided_type = type(user)}
      )
    end
    
    local db, connect_err = database.connect("users")
    if not db then
      return nil, error_handler.wrap_error(connect_err)
    end
    
    local query = "INSERT INTO users (name) VALUES ('" .. user.name .. "')"
    local result, query_err = database.query(db, query)
    if not result then
      database.disconnect(db)
      return nil, error_handler.wrap_error(query_err)
    end
    
    database.disconnect(db)
    return {success = true, id = 3}  -- In a real implementation, this would be dynamic
  end
}

-- Tests demonstrating various mocking techniques
describe("Mocking Examples", function()
  
  describe("Basic Spy Functionality", function()
    it("tracks function calls", function()
      -- Create a simple spy on a function
      local fn = function(x) return x * 2 end
      local spied_fn = spy(fn)
      
      -- Call the function a few times
      spied_fn(5)
      spied_fn(10)
      
      -- Verify calls were tracked
      expect(spied_fn.call_count).to.equal(2)
      expect(spied_fn.calls[1][1]).to.equal(5)  -- First call, first argument
      expect(spied_fn.calls[2][1]).to.equal(10) -- Second call, first argument
    end)
    
    it("can spy on object methods", function()
      local calculator = {
        add = function(a, b) return a + b end,
        multiply = function(a, b) return a * b end
      }
      
      -- Spy on the add method
      local add_spy = spy(calculator, "add")
      
      -- Use the method
      local result = calculator.add(3, 4)
      
      -- Original functionality still works
      expect(result).to.equal(7)
      
      -- But calls are tracked
      expect(add_spy.called).to.be_truthy()
      expect(add_spy:called_with(3, 4)).to.be_truthy()
      
      -- Restore original method
      add_spy:restore()
    end)
  end)
  
  describe("Mock Object Functionality", function()
    it("can mock an entire object", function()
      -- Create a mock of the database object
      local db_mock = mock(database)
      
      -- Stub methods with our test implementations
      db_mock:stub("connect", function(name)
        return {name = name, connected = true}
      end)
      
      db_mock:stub("query", function()
        return {
          rows = {{id = 1, name = "mocked_user"}},
          count = 1
        }
      end)
      
      db_mock:stub("disconnect", function() return true end)
      
      -- Use the UserService which depends on the database
      local users = UserService.get_users()
      
      -- Verify our mocked data was returned
      expect(users[1].name).to.equal("mocked_user")
      
      -- Verify our mocks were called
      expect(db_mock._stubs.connect.called).to.be_truthy()
      expect(db_mock._stubs.query.called).to.be_truthy()
      expect(db_mock._stubs.disconnect.called).to.be_truthy()
      
      -- Verify the entire mock (all methods were called)
      expect(db_mock:verify()).to.be_truthy()
      
      -- Restore original methods
      db_mock:restore()
    end)
    
    it("can stub methods with return values", function()
      -- Create a mock and stub a method with a simple return value
      local db_mock = mock(database)
      
      -- Stub connect to return a simple value
      db_mock:stub("connect", {name = "test_db", connected = true})
      
      -- Call the stubbed method
      local connection = database.connect("any_name")
      
      -- The return value should be our stubbed value
      expect(connection.name).to.equal("test_db")
      
      -- Clean up
      db_mock:restore()
    end)
  end)
  
  describe("Using with_mocks Context Manager", function()
    it("automatically cleans up mocks", function()
      local original_connect = database.connect
      
      with_mocks(function(mock_fn)
        -- Create mock inside the context
        local db_mock = mock_fn(database)
        
        -- Stub methods
        db_mock:stub("connect", function() 
          return {name = "context_db", connected = true} 
        end)
        
        -- Use the mocked function
        local connection = database.connect("unused")
        expect(connection.name).to.equal("context_db")
        
        -- No need to restore - it happens automatically
      end)
      
      -- Outside the context, original function should be restored
      expect(database.connect).to.equal(original_connect)
    end)
  end)
  
  describe("Error Testing with Mocks", function()
    it("can test error conditions with mocked functions", { expect_error = true }, function()
      with_mocks(function(mock_fn)
        local db_mock = mock_fn(database)
        
        -- Stub connect to return an error
        db_mock:stub("connect", function()
          return nil, error_handler.connection_error(
            "Database connection refused",
            {host = "localhost", port = 5432}
          )
        end)
        
        -- Attempt to get users, which should fail due to the mocked connection error
        local result, err = test_helper.with_error_capture(function()
          return UserService.get_users()
        end)()
        
        -- Verify error handling
        expect(result).to_not.exist()
        expect(err).to.exist()
        expect(err.message).to.match("Failed to connect")
        expect(err.context).to.exist()
        expect(err.context.operation).to.equal("get_users")
      end)
    end)
    
    it("tests validation error handling", { expect_error = true }, function()
      -- Test with invalid user ID
      local result, err = test_helper.with_error_capture(function()
        return UserService.find_user("not_a_number")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("must be a positive number")
    end)
  end)
  
  describe("Real-world Testing Patterns", function()
    it("tests successful user creation with mocks", function()
      with_mocks(function(mock_fn)
        -- Create mocks for the database
        local db_mock = mock_fn(database)
        
        -- Track function calls
        local connect_calls = {}
        local query_calls = {}
        
        -- Stub connect
        db_mock:stub("connect", function(db_name)
          table.insert(connect_calls, {db_name = db_name})
          return {name = db_name, connected = true}
        end)
        
        -- Stub query
        db_mock:stub("query", function(db, query)
          table.insert(query_calls, {db = db, query = query})
          return {rows = {}, count = 1}
        end)
        
        -- Stub disconnect
        db_mock:stub("disconnect", function() return true end)
        
        -- Execute the method we're testing
        local result = UserService.create_user({name = "New User"})
        
        -- Verify the result
        expect(result.success).to.be_truthy()
        
        -- Verify the right calls were made
        expect(#connect_calls).to.equal(1)
        expect(connect_calls[1].db_name).to.equal("users")
        
        expect(#query_calls).to.equal(1)
        expect(query_calls[1].query).to.match("INSERT INTO users")
        expect(query_calls[1].query).to.match("New User")
      end)
    end)
    
    it("tests database error handling in user service", { expect_error = true }, function()
      with_mocks(function(mock_fn)
        local db_mock = mock_fn(database)
        
        -- Stub connect - successful connection
        db_mock:stub("connect", function(db_name)
          return {name = db_name, connected = true}
        end)
        
        -- Stub query - return error for query containing "ERROR"
        db_mock:stub("query", function(db, query)
          if query:match("ERROR") then
            return nil, error_handler.database_error(
              "Simulated database error",
              {query = query}
            )
          end
          return {rows = {}, count = 0}
        end)
        
        -- Stub disconnect - always succeeds
        db_mock:stub("disconnect", function() return true end)
        
        -- Test with a query that will trigger the error
        local result, err = test_helper.with_error_capture(function()
          -- Modify the query to include ERROR to trigger our mock error
          database.query({name = "test", connected = true}, "SELECT ERROR")
        end)()
        
        -- Verify error handling
        expect(result).to_not.exist()
        expect(err).to.exist()
        expect(err.message).to.match("Simulated database error")
      end)
    end)
  end)
end)

print("\n=== Mocking Examples ===")
print("This example demonstrates:")
print("1. Creating spies to track function calls")
print("2. Mocking objects to isolate components for testing")
print("3. Verifying call patterns and arguments") 
print("4. Testing error conditions with mocked functions")
print("5. Using the with_mocks context manager for clean testing")
print("6. Implementing robust error handling with mocks")
print("\nRun this example with:")
print("lua test.lua examples/mocking_example.lua")