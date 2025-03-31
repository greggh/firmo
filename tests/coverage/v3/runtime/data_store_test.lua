-- Coverage data store tests for v3 coverage system
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local data_store = require("lib.coverage.v3.runtime.data_store")
local path_mapping = require("lib.coverage.v3.path_mapping")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Coverage v3 Data Store", function()
  -- Test directory for each test
  local test_dir

  before(function()
    -- Create fresh test directory
    test_dir = test_helper.create_temp_test_directory()
    -- Reset data store
    data_store.reset()
  end)

  after(function()
    -- Reset data store
    data_store.reset()
  end)

  it("should store execution data", function()
    -- Create original file
    local original_path = fs.join_paths(test_dir.path, "simple.lua")
    test_dir.create_file("simple.lua", [[
      local x = 1
      local y = 2
      return x + y
    ]])

    -- Create instrumented file
    local temp_path = test_dir.create_file("instrumented/simple.lua", [[
      _firmo_coverage.track(1)
      local x = 1
      _firmo_coverage.track(2)
      local y = 2
      _firmo_coverage.track(3)
      return x + y
    ]])

    -- Register path mapping
    path_mapping.register_path_pair(original_path, temp_path)

    -- Record some executions
    data_store.record_execution(temp_path, 1)  -- Line 1
    data_store.record_execution(temp_path, 2)  -- Line 2
    data_store.record_execution(temp_path, 1)  -- Line 1 again

    -- Get data
    local data = data_store.get_data()
    expect(data).to.exist()
    expect(data[original_path]).to.exist()
    expect(data[original_path][1].count).to.equal(2)  -- Line 1 executed twice
    expect(data[original_path][2].count).to.equal(1)  -- Line 2 executed once
    expect(data[original_path][3]).to_not.exist()     -- Line 3 not executed
  end)

  it("should store coverage state", function()
    -- Create original file
    local original_path = fs.join_paths(test_dir.path, "states.lua")
    test_dir.create_file("states.lua", [[
      local function add(a, b)
        return a + b
      end
      return add
    ]])

    -- Create instrumented file
    local temp_path = test_dir.create_file("instrumented/states.lua", [[
      _firmo_coverage.track(1)
      local function add(a, b)
        _firmo_coverage.track(2)
        return a + b
      end
      _firmo_coverage.track(4)
      return add
    ]])

    -- Register path mapping
    path_mapping.register_path_pair(original_path, temp_path)

    -- Record different states
    data_store.record_execution(temp_path, 1)  -- Just executed
    data_store.record_execution(temp_path, 2)  -- Will be covered
    data_store.record_coverage(temp_path, 2)   -- Now covered
    data_store.record_execution(temp_path, 4)  -- Just executed

    -- Get data
    local data = data_store.get_data()
    expect(data).to.exist()
    expect(data[original_path]).to.exist()
    expect(data[original_path][1].state).to.equal("executed")  -- Only executed
    expect(data[original_path][2].state).to.equal("covered")   -- Executed and covered
    expect(data[original_path][4].state).to.equal("executed")  -- Only executed
  end)

  it("should handle multiple files", function()
    -- Create first file
    local original1 = fs.join_paths(test_dir.path, "file1.lua")
    test_dir.create_file("file1.lua", [[
      local x = 1
      return x
    ]])

    -- Create second file
    local original2 = fs.join_paths(test_dir.path, "file2.lua")
    test_dir.create_file("file2.lua", [[
      local y = 2
      return y
    ]])

    -- Create instrumented files
    local temp1 = test_dir.create_file("instrumented/file1.lua", [[
      _firmo_coverage.track(1)
      local x = 1
      _firmo_coverage.track(2)
      return x
    ]])
    local temp2 = test_dir.create_file("instrumented/file2.lua", [[
      _firmo_coverage.track(1)
      local y = 2
      _firmo_coverage.track(2)
      return y
    ]])

    -- Register path mappings
    path_mapping.register_path_pair(original1, temp1)
    path_mapping.register_path_pair(original2, temp2)

    -- Record executions in both files
    data_store.record_execution(temp1, 1)  -- file1 line 1
    data_store.record_execution(temp1, 2)  -- file1 line 2
    data_store.record_execution(temp2, 1)  -- file2 line 1

    -- Get data
    local data = data_store.get_data()
    expect(data).to.exist()
    expect(data[original1]).to.exist()
    expect(data[original2]).to.exist()

    -- Check file1 coverage
    expect(data[original1][1].state).to.equal("executed")
    expect(data[original1][2].state).to.equal("executed")

    -- Check file2 coverage
    expect(data[original2][1].state).to.equal("executed")
    expect(data[original2][2]).to_not.exist()  -- Not executed
  end)

  it("should handle missing files gracefully", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return data_store.record_execution("/nonexistent/file.lua", 1)
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("No mapping found")
  end)

  it("should validate line numbers", { expect_error = true }, function()
    -- Create files
    local original = fs.join_paths(test_dir.path, "validate.lua")
    test_dir.create_file("validate.lua", "return true")
    
    local temp = test_dir.create_file("instrumented/validate.lua",
      "_firmo_coverage.track(1)\nreturn true")

    -- Register mapping
    path_mapping.register_path_pair(original, temp)

    -- Try invalid line number
    local result, err = test_helper.with_error_capture(function()
      return data_store.record_execution(temp, 999)
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Invalid line number")
  end)

  it("should persist data across resets", function()
    -- Create files
    local original = fs.join_paths(test_dir.path, "persist.lua")
    test_dir.create_file("persist.lua", [[
      local x = 1
      return x
    ]])
    
    local temp = test_dir.create_file("instrumented/persist.lua", [[
      _firmo_coverage.track(1)
      local x = 1
      _firmo_coverage.track(2)
      return x
    ]])

    -- Register mapping
    path_mapping.register_path_pair(original, temp)

    -- Record some data
    data_store.record_execution(temp, 1)
    data_store.record_coverage(temp, 2)

    -- Get initial data
    local data1 = data_store.get_data()
    expect(data1[original][1].state).to.equal("executed")
    expect(data1[original][2].state).to.equal("covered")

    -- Reset store
    data_store.reset()

    -- Record more data
    data_store.record_coverage(temp, 1)  -- Upgrade line 1 to covered

    -- Get final data
    local data2 = data_store.get_data()
    expect(data2[original][1].state).to.equal("covered")   -- Should be upgraded
    expect(data2[original][2].state).to.equal("covered")   -- Should persist
  end)

  it("should aggregate data correctly", function()
    -- Create files
    local original = fs.join_paths(test_dir.path, "aggregate.lua")
    test_dir.create_file("aggregate.lua", [[
      local function test(x)
        if x > 0 then
          return x
        else
          return -x
        end
      end
      return test
    ]])
    
    local temp = test_dir.create_file("instrumented/aggregate.lua", [[
      _firmo_coverage.track(1)
      local function test(x)
        _firmo_coverage.track(2)
        if x > 0 then
          _firmo_coverage.track(3)
          return x
        else
          _firmo_coverage.track(4)
          return -x
        end
      end
      _firmo_coverage.track(7)
      return test
    ]])

    -- Register mapping
    path_mapping.register_path_pair(original, temp)

    -- Record executions with different paths
    -- First run: x > 0
    data_store.record_execution(temp, 1)  -- Function definition
    data_store.record_execution(temp, 2)  -- if condition
    data_store.record_execution(temp, 3)  -- true branch
    data_store.record_execution(temp, 7)  -- return statement

    -- Second run: x <= 0
    data_store.record_execution(temp, 2)  -- if condition again
    data_store.record_execution(temp, 4)  -- false branch
    data_store.record_coverage(temp, 4)   -- false branch covered

    -- Get aggregated data
    local data = data_store.get_data()
    expect(data[original]).to.exist()

    -- Check execution counts
    expect(data[original][1].count).to.equal(1)  -- Function defined once
    expect(data[original][2].count).to.equal(2)  -- Condition checked twice
    expect(data[original][3].count).to.equal(1)  -- True branch once
    expect(data[original][4].count).to.equal(1)  -- False branch once
    expect(data[original][7].count).to.equal(1)  -- Return once

    -- Check coverage states
    expect(data[original][1].state).to.equal("executed")  -- Just executed
    expect(data[original][2].state).to.equal("executed")  -- Just executed
    expect(data[original][3].state).to.equal("executed")  -- Just executed
    expect(data[original][4].state).to.equal("covered")   -- Executed and covered
    expect(data[original][7].state).to.equal("executed")  -- Just executed
  end)

  it("should handle cleanup", function()
    -- Create files
    local original = fs.join_paths(test_dir.path, "cleanup.lua")
    test_dir.create_file("cleanup.lua", "return true")
    
    local temp = test_dir.create_file("instrumented/cleanup.lua",
      "_firmo_coverage.track(1)\nreturn true")

    -- Register mapping
    path_mapping.register_path_pair(original, temp)

    -- Record some data
    data_store.record_execution(temp, 1)

    -- Get data before cleanup
    local data1 = data_store.get_data()
    expect(data1[original]).to.exist()
    expect(data1[original][1].state).to.equal("executed")

    -- Trigger cleanup
    test_helper.cleanup_temp_files()

    -- Get data after cleanup - should still have data
    local data2 = data_store.get_data()
    expect(data2[original]).to.exist()
    expect(data2[original][1].state).to.equal("executed")

    -- Reset store
    data_store.reset()

    -- Get data after reset - should be empty
    local data3 = data_store.get_data()
    expect(data3[original]).to_not.exist()
  end)

  it("should handle serialization", function()
    -- Create files
    local original = fs.join_paths(test_dir.path, "serialize.lua")
    test_dir.create_file("serialize.lua", [[
      local x = 1
      return x
    ]])
    
    local temp = test_dir.create_file("instrumented/serialize.lua", [[
      _firmo_coverage.track(1)
      local x = 1
      _firmo_coverage.track(2)
      return x
    ]])

    -- Register mapping
    path_mapping.register_path_pair(original, temp)

    -- Record some data
    data_store.record_execution(temp, 1)
    data_store.record_coverage(temp, 2)

    -- Serialize data
    local serialized = data_store.serialize()
    expect(serialized).to.exist()

    -- Reset store
    data_store.reset()

    -- Deserialize data
    local success = data_store.deserialize(serialized)
    expect(success).to.be_truthy()

    -- Check data was restored
    local data = data_store.get_data()
    expect(data[original]).to.exist()
    expect(data[original][1].state).to.equal("executed")
    expect(data[original][2].state).to.equal("covered")
  end)
end)