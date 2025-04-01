-- Runtime tracker tests for v3 coverage system
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local tracker = require("lib.coverage.v3.runtime.tracker")
local path_mapping = require("lib.coverage.v3.path_mapping")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Coverage v3 Runtime Tracker", function()
  -- Test directory for each test
  local test_dir

  before(function()
    -- Create fresh test directory
    test_dir = test_helper.create_temp_test_directory()
    -- Start tracking
    tracker.start()
  end)

  after(function()
    -- Stop tracking and reset
    tracker.stop()
    tracker.reset()
  end)

  it("should track line execution", function()
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

    -- Execute some lines
    tracker.track(1, "executed")  -- Line 1
    tracker.track(2, "executed")  -- Line 2
    tracker.track(1, "executed")  -- Line 1 again

    -- Get execution data
    local data = tracker.get_data()
    expect(data).to.exist()
    expect(data[original_path]).to.exist()
    expect(data[original_path][1]).to.equal(2)  -- Line 1 executed twice
    expect(data[original_path][2]).to.equal(1)  -- Line 2 executed once
    expect(data[original_path][3]).to_not.exist()  -- Line 3 not executed
  end)

  it("should track assertion coverage", function()
    -- Create original file
    local original_path = fs.join_paths(test_dir.path, "assertions.lua")
    test_dir.create_file("assertions.lua", [[
      local function add(a, b)
        return a + b
      end
      return add
    ]])

    -- Create instrumented file
    local temp_path = test_dir.create_file("instrumented/assertions.lua", [[
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

    -- Execute and verify some lines
    tracker.track(1, "executed")  -- Function definition
    tracker.track(2, "executed")  -- Inside function
    tracker.track(2, "covered")   -- Line verified by assertion
    tracker.track(4, "executed")  -- Return statement

    -- Get coverage data
    local data = tracker.get_data()
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

    -- Execute some lines in both files
    tracker.track(1, "executed", temp1)  -- file1 line 1
    tracker.track(2, "executed", temp1)  -- file1 line 2
    tracker.track(1, "executed", temp2)  -- file2 line 1

    -- Get coverage data
    local data = tracker.get_data()
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
      return tracker.track(1, "executed", "/nonexistent/file.lua")
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
      return tracker.track(999, "executed", temp)
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Invalid line number")
  end)

  it("should validate coverage state", { expect_error = true }, function()
    -- Create files
    local original = fs.join_paths(test_dir.path, "state.lua")
    test_dir.create_file("state.lua", "return true")
    
    local temp = test_dir.create_file("instrumented/state.lua",
      "_firmo_coverage.track(1)\nreturn true")

    -- Register mapping
    path_mapping.register_path_pair(original, temp)

    -- Try invalid state
    local result, err = test_helper.with_error_capture(function()
      return tracker.track(1, "invalid", temp)
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Invalid coverage state")
  end)

  it("should handle start/stop/reset", function()
    -- Create files
    local original = fs.join_paths(test_dir.path, "lifecycle.lua")
    test_dir.create_file("lifecycle.lua", [[
      local x = 1
      return x
    ]])
    
    local temp = test_dir.create_file("instrumented/lifecycle.lua", [[
      _firmo_coverage.track(1)
      local x = 1
      _firmo_coverage.track(2)
      return x
    ]])

    -- Register mapping
    path_mapping.register_path_pair(original, temp)

    -- Track while stopped
    tracker.stop()
    tracker.track(1, "executed", temp)  -- Should be ignored

    -- Get data - should be empty
    local data1 = tracker.get_data()
    expect(data1[original]).to_not.exist()

    -- Start and track
    tracker.start()
    tracker.track(1, "executed", temp)
    tracker.track(2, "executed", temp)

    -- Get data - should have coverage
    local data2 = tracker.get_data()
    expect(data2[original]).to.exist()
    expect(data2[original][1].state).to.equal("executed")
    expect(data2[original][2].state).to.equal("executed")

    -- Reset and check data is cleared
    tracker.reset()
    local data3 = tracker.get_data()
    expect(data3[original]).to_not.exist()
  end)

  it("should persist coverage state", function()
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

    -- Track some lines
    tracker.track(1, "executed", temp)
    tracker.track(2, "covered", temp)

    -- Stop tracking and get data
    tracker.stop()
    local data1 = tracker.get_data()

    -- Reset and restart
    tracker.reset()
    tracker.start()

    -- Track more lines
    tracker.track(1, "covered", temp)  -- Upgrade line 1 to covered

    -- Get final data
    local data2 = tracker.get_data()

    -- Line 1 should be upgraded to covered
    expect(data2[original][1].state).to.equal("covered")
    -- Line 2 should still be covered
    expect(data2[original][2].state).to.equal("covered")
  end)

  it("should handle cleanup", function()
    -- Create files
    local original = fs.join_paths(test_dir.path, "cleanup.lua")
    test_dir.create_file("cleanup.lua", "return true")
    
    local temp = test_dir.create_file("instrumented/cleanup.lua",
      "_firmo_coverage.track(1)\nreturn true")

    -- Register mapping
    path_mapping.register_path_pair(original, temp)

    -- Track a line
    tracker.track(1, "executed", temp)

    -- Get data before cleanup
    local data1 = tracker.get_data()
    expect(data1[original]).to.exist()

    -- No need to manually cleanup - test_helper and temp_file_integration 
    -- will handle cleanup automatically through test contexts

    -- Get data after reset - should be empty
    tracker.reset()
    local data3 = tracker.get_data()
    expect(data3[original]).to_not.exist()
  end)
end)