--- This example provides a comprehensive demonstration of Firmo's mocking system,
--- including spies, mocks, stubs, and the `with_mocks` context manager.
--
-- It covers:
-- - Using `firmo.spy` to track function calls.
-- - Using `firmo.mock` to create mock objects and stub methods.
-- - Verifying mock/spy calls using `.called`, `.call_count`, `:called_with()`.
-- - Using `with_mocks` for automatic mock restoration.
-- - Testing error conditions by stubbing methods to return errors.
-- - Real-world patterns for testing modules with dependencies.
--
-- @module examples.mocking_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see firmo
-- @see lib.mocking
-- @see lib.tools.error_handler
-- @see lib.tools.test_helper
-- @usage
-- Run embedded tests: lua firmo.lua examples/mocking_example.lua
--

local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("MockingExample")

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
local mock, spy, stub, with_mocks = firmo.mock, firmo.spy, firmo.stub, firmo.with_mocks

--- A sample "database" module used to demonstrate mocking dependencies.
--- @class DatabaseModule
--- @field connect fun(db_name: string): table|nil, table|nil Simulates connecting.
--- @field query fun(db: table, query_string: string): table|nil, table|nil Simulates querying.
--- @field disconnect fun(db: table): boolean|nil, table|nil Simulates disconnecting.
--- @within examples.mocking_example

---@class DBConnection
---@field connected boolean
---@field name string

---@class DBQueryResult
---@field rows table[]
---@field count number

local database = {
  --- Simulates connecting to a database.
  -- @param db_name string The name of the database.
  -- @return DBConnection|nil connection A simulated connection object on success, or `nil`.
  -- @return table|nil err A validation error object on failure.
  connect = function(db_name)
    if type(db_name) ~= "string" or db_name == "" then
      return nil,
        error_handler.validation_error(
          "Database name must be a non-empty string",
          { parameter = "db_name", provided_type = type(db_name) }
        )
    end

    -- In a real implementation, this would actually connect to a database
    print("Actually connecting to real database: " .. db_name)
    return {
      connected = true,
      name = db_name,
    }
  end,

  --- Simulates executing a query on a database connection.
  -- @param db DBConnection The database connection object.
  -- @param query_string string The SQL query string.
  -- @return DBQueryResult|nil result A simulated result table on success, or `nil`.
  -- @return table|nil err A validation or database error object on failure.
  query = function(db, query_string)
    if type(db) ~= "table" or not db.connected then
      return nil,
        error_handler.validation_error("Database connection required", { parameter = "db", provided_type = type(db) })
    end

    if type(query_string) ~= "string" or query_string == "" then
      return nil,
        error_handler.validation_error(
          "Query must be a non-empty string",
          { parameter = "query_string", provided_type = type(query_string) }
        )
    end

    -- In a real implementation, this would execute the query
    print("Actually executing query on " .. db.name .. ": " .. query_string)

    -- Simulate errors
    if query_string:match("ERROR") then
      return nil, error_handler.database_error("Database query failed", { query = query_string, db_name = db.name })
    end

    return {
      rows = { { id = 1, name = "test" }, { id = 2, name = "sample" } },
      count = 2,
    }
  end,

  --- Simulates disconnecting from a database.
  -- @param db DBConnection The database connection object.
  -- @return boolean|nil success `true` on success, or `nil`.
  -- @return table|nil err A validation error object on failure.
  disconnect = function(db)
    if type(db) ~= "table" then
      return nil,
        error_handler.validation_error("Database connection required", { parameter = "db", provided_type = type(db) })
    end

    -- In a real implementation, this would disconnect
    print("Actually disconnecting from " .. db.name)
    db.connected = false
    return true
  end,
}

--- A sample "user service" module that depends on the `database` module.
-- Used to demonstrate testing with mocked dependencies.
--- @class UserService
--- @field get_users fun(): table|nil, table|nil Fetches all users.
--- @field find_user fun(id: number): table|nil, table|nil Finds a user by ID.
--- @field create_user fun(user: table): table|nil, table|nil Creates a new user.
--- @within examples.mocking_example
local UserService = {
  --- Fetches all users from the database by calling `database.connect`, `database.query`, and `database.disconnect`.
  -- @return table|nil users An array of user row tables on success, or `nil`.
  -- @return table|nil err An error object (potentially wrapped) on failure.
  get_users = function()
    local db, connect_err = database.connect("users")
    if not db then
      -- Check connection error first
      return nil,
        error_handler.runtime_error(
          "Database connection failed in get_users",
          { operation = "get_users" },
          connect_err -- Original connection error as cause
        )
    end

    -- Query the database
    local result, query_err = database.query(db, "SELECT * FROM users")

    -- Always disconnect after query attempt
    database.disconnect(db)

    -- Check query error
    if not result then
      return nil,
        error_handler.runtime_error(
          "Failed to fetch users",
          { operation = "get_users" },
          query_err -- Original query error as cause
        )
    end

    -- Success: return rows
    return result.rows
  end, -- Removed comma

  --- Finds a user by their ID by calling `database.connect`, `database.query`, and `database.disconnect`.
  -- @param id number The user ID to find.
  -- @return table|nil user The user row table if found, or `nil`.
  -- @return table|nil err An error object (validation or wrapped DB error) on failure.
  find_user = function(id)
    if type(id) ~= "number" or id < 1 then
      return nil,
        error_handler.validation_error("User ID must be a positive number", { parameter = "id", provided_value = id })
    end

    local db, connect_err = database.connect("users")
    if not db then
      return nil,
        error_handler.create(
          "Failed to connect for find_user",
          error_handler.CATEGORY.RUNTIME,
          nil,
          { operation = "find_user" },
          connect_err
        )
    end

    local result, query_err = database.query(db, "SELECT * FROM users WHERE id = " .. id)
    if not result then
      database.disconnect(db)
      return nil,
        error_handler.create(
          "Failed to find user",
          error_handler.CATEGORY.RUNTIME,
          nil,
          { operation = "find_user", user_id = id },
          query_err
        )
    end

    database.disconnect(db)
    return result.rows[1]
  end,

  --- Creates a new user in the database by calling `database.connect`, `database.query`, and `database.disconnect`.
  -- @param user table A table containing user data (expects a `name` field).
  -- @return table|nil result A table `{ success = true, id = number }` on success, or `nil`.
  -- @return table|nil err An error object (validation or wrapped DB error) on failure.
  create_user = function(user)
    if type(user) ~= "table" or not user.name then
      return nil,
        error_handler.validation_error(
          "User must be a table with a name field",
          { parameter = "user", provided_type = type(user) }
        )
    end

    local db, connect_err = database.connect("users")
    if not db then
      return nil,
        error_handler.create(
          "Failed to connect for create_user",
          error_handler.CATEGORY.RUNTIME,
          nil,
          { operation = "create_user" },
          connect_err
        )
    end

    local query = "INSERT INTO users (name) VALUES ('" .. user.name .. "')"
    local result, query_err = database.query(db, query)
    if not result then
      database.disconnect(db)
      return nil,
        error_handler.create(
          "Failed to create user",
          error_handler.CATEGORY.RUNTIME,
          nil,
          { operation = "create_user", user_name = user.name },
          query_err
        )
    end

    database.disconnect(db)
    return { success = true, id = 3 } -- In a real implementation, this would be dynamic
  end, -- Removed comma
}

-- Tests demonstrating various mocking techniques
--- Test suite for demonstrating Firmo's mocking features (`spy`, `mock`, `stub`, `with_mocks`).
--- @within examples.mocking_example
describe("Mocking Examples", function()
  --- Tests demonstrating the use of `firmo.spy` for tracking function calls without altering behavior.
  --- @within examples.mocking_example
  describe("Basic Spy Functionality", function()
    --- Tests spying on a standalone function.
    it("tracks calls to a standalone function", function()
      -- Create a simple spy on a function
      local fn = function(x)
        return x * 2
      end
      local spied_fn = spy(fn)

      -- Call the function a few times
      spied_fn(5)
      spied_fn(10)

      -- Verify calls were tracked
      expect(spied_fn.call_count).to.equal(2)
      expect(spied_fn.calls[1].args[1]).to.equal(5) -- Access args table
      expect(spied_fn.calls[2].args[1]).to.equal(10)
    end)

    --- Tests spying on a method within a table (object).
    it("can spy on object methods", function()
      local calculator = {
        add = function(self, a, b)
          return a + b
        end,
        multiply = function(self, a, b)
          return a * b
        end,
      }

      -- Spy on the add method - use spy.on for object methods
      local add_spy = spy.on(calculator, "add")

      -- Use the method
      local result = calculator:add(3, 4)

      -- Original functionality still works
      expect(result).to.equal(7)

      -- But calls are tracked
      expect(add_spy.called).to.be_truthy()
      expect(add_spy.calls[1].args[1]).to.equal(calculator) -- First arg is 'self'
      expect(add_spy.calls[1].args[2]).to.equal(3) -- Second arg is 'a'
      expect(add_spy.calls[1].args[3]).to.equal(4) -- Third arg is 'b'

      -- Restore original method
      add_spy:restore()
    end)
  end)

  --- Tests demonstrating `firmo.mock` to create mock objects and `mock_obj:stub()` to define behavior.
  --- @within examples.mocking_example
  describe("Mock Object Functionality", function()
    --- Tests mocking an entire object (`database`) and stubbing its methods for testing `UserService`.
    it("can mock an entire object and stub methods", function()
      -- Create a mock of the database object
      local db_mock = mock(database)

      -- Stub methods with our test implementations
      db_mock:stub("connect", function(name)
        return { name = name, connected = true }
      end)

      db_mock:stub("query", function()
        return {
          rows = { { id = 1, name = "mocked_user" } },
          count = 1,
        }
      end)

      db_mock:stub("disconnect", function()
        return true
      end)

      -- Use the UserService which depends on the database
      local users = UserService.get_users()

      -- Verify our mocked data was returned
      expect(users[1].name).to.equal("mocked_user")

      -- Verify our mocks were called by accessing the spy attached to the mock
      expect(db_mock._spies.connect.called).to.be_truthy()
      expect(db_mock._spies.query.called).to.be_truthy()
      expect(db_mock._spies.disconnect.called).to.be_truthy()
      -- Firmo mocks do not have a built-in `:verify()` method for all stubs.
      -- Verification is done via specific assertions on `.called`, `.call_count`, `:called_with()` on the spy.

      -- Restore original methods (though typically done via `with_mocks` or `after` hook)
      db_mock:restore()
    end)

    --- Tests stubbing a method to return a specific predefined value using `.returns()`.
    it("can stub methods with specific return values using .returns()", function()
      -- Create a mock and stub a method with a simple return value
      local db_mock = mock(database)

      -- Stub connect to return a specific table
      db_mock:stub("connect", { name = "test_db", connected = true }) -- Pass return value directly

      -- Call the stubbed method (via the original object, as the stub replaces it)
      local connection = database.connect("any_name")

      -- The return value should be our stubbed value
      expect(connection.name).to.equal("test_db")

      -- Clean up
      db_mock:restore()
    end)
  end)

  --- Tests demonstrating `firmo.with_mocks` for automatic mock creation and restoration.
  --- @within examples.mocking_example
  describe("Using with_mocks Context Manager", function()
    --- Tests that mocks created within `with_mocks` are automatically restored afterward.
    it("automatically restores original functions after the block", { expect_error = true }, function()
      local original_connect = database.connect

      with_mocks(function(mock_fn)
        -- Create mock inside the context
        local db_mock = mock_fn(database)

        -- Stub methods
        db_mock:stub("connect", function()
          return { name = "context_db", connected = true }
        end)

        -- Use the mocked function
        local connection = database.connect("unused")
        expect(connection.name).to.equal("context_db")

        -- No need to restore - it happens automatically
      end)

      -- Outside the context, original function should be restored
      -- We'll verify behavior is back to normal by checking both error and success cases

      -- Temporarily replace print to prevent actual output during test
      local original_print = _G.print
      _G.print = function(msg) end -- Stub print to do nothing

      -- Test failure case: invalid inputs should return nil, error after mock restoration
      local result, err = test_helper.with_error_capture(function()
        return database.connect("") -- This should return nil, error
      end)()

      -- Verify error is returned properly
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("non%-empty string")
      expect(err.category).to.exist()
      -- Now test success case: valid inputs behave as expected
      local success_result, success_err = test_helper.with_error_capture(function()
        local connection = database.connect("test_db")
        if connection then
          -- Remember the important properties to test after returning
          return {
            name = connection.name,
            connected = connection.connected,
          }
        end
        return nil, "Failed to create connection"
      end)()

      -- Restore print function
      _G.print = original_print

      -- Verify success case works as expected
      -- The success result should not be nil
      expect(success_err).to_not.exist()
      expect(success_result).to.exist()
      expect(success_result.name).to.equal("test_db")
      expect(success_result.connected).to.be_truthy()
    end)
  end)

  --- Tests using mocks to simulate error conditions from dependencies.
  --- @within examples.mocking_example
  describe("Error Testing with Mocks", function()
    --- Tests how `UserService.get_users` handles a connection error from the mocked `database.connect`.
    it("can test database connection errors", { expect_error = true }, function()
      with_mocks(function(mock_fn)
        local db_mock = mock_fn(database)

        -- Stub connect to return an error
        db_mock:stub("connect", function()
          -- Use a standard error type if connection_error doesn't exist
          return nil, error_handler.io_error("Database connection refused", { host = "localhost", port = 5432 })
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

    --- Tests input validation within `UserService` itself (no mocking needed here).
    it("tests UserService input validation errors", { expect_error = true }, function()
      -- Test with invalid user ID
      local result, err = test_helper.with_error_capture(function()
        return UserService.find_user("not_a_number")
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("must be a positive number")
    end)
  end)

  --- Tests demonstrating more realistic interaction patterns between services and mocked dependencies.
  --- @within examples.mocking_example
  describe("Real-world Testing Patterns", function()
    --- Tests the successful path of `UserService.create_user`, verifying interactions with the mocked database.
    it("tests successful user creation path", function()
      with_mocks(function(mock_fn)
        -- Create mocks for the database
        local db_mock = mock_fn(database)

        -- Track function calls
        local connect_calls = {}
        local query_calls = {}

        -- Stub connect
        db_mock:stub("connect", function(db_name)
          table.insert(connect_calls, { db_name = db_name })
          return { name = db_name, connected = true }
        end)

        -- Stub query
        db_mock:stub("query", function(db, query)
          table.insert(query_calls, { db = db, query = query })
          return { rows = {}, count = 1 }
        end)

        -- Stub disconnect
        db_mock:stub("disconnect", function()
          return true
        end)

        -- Execute the method we're testing
        local result = UserService.create_user({ name = "New User" })

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

    --- Tests how `UserService` handles a database query error during user creation.
    it("tests database query error during user creation", { expect_error = true }, function()
      with_mocks(function(mock_fn)
        local db_mock = mock_fn(database)

        -- Stub connect - successful connection
        db_mock:stub("connect", function(db_name)
          return { name = db_name, connected = true }
        end)

        -- Stub query - unconditionally return an error
        db_mock:stub("query", function(db, query)
          return nil, error_handler.runtime_error("Simulated database error", { query = query })
        end)

        -- Stub disconnect - always succeeds
        db_mock:stub("disconnect", function()
          return true
        end)

        -- Test calling create_user when the underlying query fails
        local result, err = test_helper.with_error_capture(function()
          return UserService.create_user({ name = "Error User" }) -- Call the service method
        end)()

        -- Verify error handling
        expect(result).to_not.exist()
        expect(err).to.exist()
        expect(err.message).to.match("Failed to create user") -- Check the wrapped error message
      end)
    end)
  end)
end)

logger.info("\n=== Mocking Examples ===")
logger.info("This example demonstrates:")
logger.info("1. Creating spies to track function calls")
logger.info("2. Mocking objects to isolate components for testing")
logger.info("3. Verifying call patterns and arguments")
logger.info("4. Testing error conditions with mocked functions")
logger.info("5. Using the with_mocks context manager for clean testing")
logger.info("6. Implementing robust error handling with mocks")
logger.info("\nRun this example with:")
logger.info("lua firmo.lua examples/mocking_example.lua")
