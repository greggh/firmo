-- Module loader tests for v3 coverage system
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local loader = require("lib.coverage.v3.loader.hook")
local path_mapping = require("lib.coverage.v3.path_mapping")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Coverage v3 Module Loader", function()
  -- Test directory for each test
  local test_dir

  before(function()
    -- Create fresh test directory
    test_dir = test_helper.create_temp_test_directory()
    -- Install loader hook
    loader.install()
  end)

  after(function()
    -- Uninstall loader hook
    loader.uninstall()
  end)

  it("should load and instrument a simple module", function()
    -- Create module file
    local module_content = [[
      local M = {}
      function M.add(a, b) return a + b end
      return M
    ]]
    local module_path = fs.join_paths(test_dir.path, "math.lua")
    test_dir.create_file("math.lua", module_content)

    -- Add test directory to package.path
    package.path = test_dir.path .. "/?.lua;" .. package.path

    -- Load the module
    local math = require("math")
    expect(math).to.exist()
    expect(math.add).to.be.a("function")
    expect(math.add(2, 3)).to.equal(5)

    -- Original file should be unchanged
    local original_content = fs.read_file(module_path)
    expect(original_content).to.equal(module_content)

    -- Should create instrumented file in temp directory
    local temp_path = path_mapping.get_temp_path(module_path)
    expect(temp_path).to.exist()
    expect(temp_path).to.match("instrumented")
    
    -- Instrumented file should have tracking calls
    local instrumented_content = fs.read_file(temp_path)
    expect(instrumented_content).to.match("_firmo_coverage.track")
  end)

  it("should handle module with dependencies", function()
    -- Create dependency module
    local dep_content = [[
      local M = {}
      function M.double(x) return x * 2 end
      return M
    ]]
    local dep_path = fs.join_paths(test_dir.path, "util.lua")
    test_dir.create_file("util.lua", dep_content)

    -- Create main module that requires dependency
    local main_content = [[
      local util = require("util")
      local M = {}
      function M.quadruple(x) return util.double(util.double(x)) end
      return M
    ]]
    local main_path = fs.join_paths(test_dir.path, "main.lua")
    test_dir.create_file("main.lua", main_content)

    -- Add test directory to package.path
    package.path = test_dir.path .. "/?.lua;" .. package.path

    -- Load the main module
    local main = require("main")
    expect(main).to.exist()
    expect(main.quadruple).to.be.a("function")
    expect(main.quadruple(2)).to.equal(8)

    -- Both modules should be instrumented
    local dep_temp = path_mapping.get_temp_path(dep_path)
    local main_temp = path_mapping.get_temp_path(main_path)
    expect(dep_temp).to.exist()
    expect(main_temp).to.exist()

    -- Both instrumented files should have tracking calls
    local dep_instrumented = fs.read_file(dep_temp)
    local main_instrumented = fs.read_file(main_temp)
    expect(dep_instrumented).to.match("_firmo_coverage.track")
    expect(main_instrumented).to.match("_firmo_coverage.track")
  end)

  it("should handle circular dependencies", function()
    -- Create module A that requires B
    local a_content = [[
      local M = {}
      M.name = "a"
      function M.init()
        local B = require("b")
        M.other = B.name
      end
      return M
    ]]
    local a_path = fs.join_paths(test_dir.path, "a.lua")
    test_dir.create_file("a.lua", a_content)

    -- Create module B that requires A
    local b_content = [[
      local M = {}
      M.name = "b"
      function M.init()
        local A = require("a")
        M.other = A.name
      end
      return M
    ]]
    local b_path = fs.join_paths(test_dir.path, "b.lua")
    test_dir.create_file("b.lua", b_content)

    -- Add test directory to package.path
    package.path = test_dir.path .. "/?.lua;" .. package.path

    -- Load both modules
    local a = require("a")
    local b = require("b")
    expect(a).to.exist()
    expect(b).to.exist()

    -- Initialize both modules
    a.init()
    b.init()

    -- Check circular references work
    expect(a.other).to.equal("b")
    expect(b.other).to.equal("a")

    -- Both modules should be instrumented
    local a_temp = path_mapping.get_temp_path(a_path)
    local b_temp = path_mapping.get_temp_path(b_path)
    expect(a_temp).to.exist()
    expect(b_temp).to.exist()
  end)

  it("should handle syntax errors gracefully", { expect_error = true }, function()
    -- Create module with syntax error
    local content = [[
      local x = -- incomplete statement
      return x
    ]]
    local module_path = fs.join_paths(test_dir.path, "error.lua")
    test_dir.create_file("error.lua", content)

    -- Add test directory to package.path
    package.path = test_dir.path .. "/?.lua;" .. package.path

    -- Try to load the module
    local result, err = test_helper.with_error_capture(function()
      return require("error")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("syntax error")
  end)

  it("should handle missing modules gracefully", { expect_error = true }, function()
    -- Try to load non-existent module
    local result, err = test_helper.with_error_capture(function()
      return require("nonexistent")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("module '.-' not found")
  end)

  it("should use cached instrumented files", function()
    -- Create module file
    local content = "return { value = 42 }"
    local module_path = fs.join_paths(test_dir.path, "cached.lua")
    test_dir.create_file("cached.lua", content)

    -- Add test directory to package.path
    package.path = test_dir.path .. "/?.lua;" .. package.path

    -- Load module first time
    local first = require("cached")
    expect(first.value).to.equal(42)

    -- Get instrumented file info
    local temp_path = path_mapping.get_temp_path(module_path)
    local first_mtime = fs.get_file_modified_time(temp_path)

    -- Wait a moment to ensure different timestamp
    os.execute("sleep 1")

    -- Load module second time
    package.loaded["cached"] = nil  -- Clear package.loaded
    local second = require("cached")
    expect(second.value).to.equal(42)

    -- Should use cached instrumented file
    local second_mtime = fs.get_file_modified_time(temp_path)
    expect(second_mtime).to.equal(first_mtime)
  end)

  it("should handle package.config paths", function()
    -- Create module in a package path
    local dir = fs.join_paths(test_dir.path, "pkg/lib/lua")
    fs.create_directory(dir)
    
    local content = "return { name = 'pkg' }"
    local module_path = fs.join_paths(dir, "pkg.lua")
    test_dir.create_file("pkg/lib/lua/pkg.lua", content)

    -- Add package path
    package.path = dir .. "/?.lua;" .. package.path

    -- Load the module
    local pkg = require("pkg")
    expect(pkg).to.exist()
    expect(pkg.name).to.equal("pkg")

    -- Should create instrumented file
    local temp_path = path_mapping.get_temp_path(module_path)
    expect(temp_path).to.exist()
    expect(temp_path).to.match("instrumented")
  end)

  it("should handle preloaded modules", function()
    -- Create module
    local content = "return { preloaded = true }"
    local module_path = fs.join_paths(test_dir.path, "preload.lua")
    test_dir.create_file("preload.lua", content)

    -- Add test directory to package.path
    package.path = test_dir.path .. "/?.lua;" .. package.path

    -- Preload the module
    package.preload["preload"] = function()
      return require("preload")
    end

    -- Load the module
    local mod = require("preload")
    expect(mod).to.exist()
    expect(mod.preloaded).to.be_truthy()

    -- Should still instrument the file
    local temp_path = path_mapping.get_temp_path(module_path)
    expect(temp_path).to.exist()
    expect(temp_path).to.match("instrumented")
  end)

  it("should cleanup instrumented files", function()
    -- Create module
    local content = "return true"
    local module_path = fs.join_paths(test_dir.path, "cleanup.lua")
    test_dir.create_file("cleanup.lua", content)

    -- Add test directory to package.path
    package.path = test_dir.path .. "/?.lua;" .. package.path

    -- Load the module
    local result = require("cleanup")
    expect(result).to.be_truthy()

    -- Get instrumented file path
    local temp_path = path_mapping.get_temp_path(module_path)
    expect(temp_path).to.exist()

    -- File should exist
    local exists_before = fs.file_exists(temp_path)
    expect(exists_before).to.be_truthy()

    -- Trigger cleanup
    test_helper.cleanup_temp_files()

    -- File should be gone
    local exists_after = fs.file_exists(temp_path)
    expect(exists_after).to.be_falsy()
  end)
end)