-- Instrumentation tests for v3 coverage system
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local instrumentation = require("lib.coverage.v3.instrumentation")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Coverage v3 Instrumentation", function()
  -- Test directory for each test
  local test_dir

  before(function()
    -- Create fresh test directory
    test_dir = test_helper.create_temp_test_directory()
  end)

  it("should instrument a simple file", function()
    -- Create original file
    local original_content = [[
      local x = 1
      local y = 2
      return x + y
    ]]
    local original_path = fs.join_paths(test_dir.path, "simple.lua")
    test_dir.create_file("simple.lua", original_content)

    -- Instrument the file
    local result = instrumentation.instrument_file(original_path)
    expect(result).to.exist()
    expect(result.instrumented_path).to.exist()
    expect(result.source_map).to.exist()

    -- Check instrumented content
    local instrumented_content = fs.read_file(result.instrumented_path)
    expect(instrumented_content).to.match("_firmo_coverage.track")
    expect(instrumented_content).to.match("local x = 1")
    expect(instrumented_content).to.match("local y = 2")
    expect(instrumented_content).to.match("return x %+ y")

    -- Original file should be unchanged
    local original_after = fs.read_file(original_path)
    expect(original_after).to.equal(original_content)
  end)

  it("should handle functions and blocks", function()
    -- Create original file with functions and blocks
    local original_content = [[
      local function add(a, b)
        return a + b
      end

      local function sub(a, b)
        local result = a - b
        if result < 0 then
          return 0
        end
        return result
      end

      return add(10, 20)
    ]]
    local original_path = fs.join_paths(test_dir.path, "functions.lua")
    test_dir.create_file("functions.lua", original_content)

    -- Instrument the file
    local result = instrumentation.instrument_file(original_path)
    expect(result).to.exist()

    -- Check instrumented content
    local instrumented_content = fs.read_file(result.instrumented_path)
    -- Should have tracking before function definitions
    expect(instrumented_content).to.match("_firmo_coverage.track.-local function add")
    expect(instrumented_content).to.match("_firmo_coverage.track.-local function sub")
    -- Should have tracking inside functions
    expect(instrumented_content).to.match("_firmo_coverage.track.-return a %+ b")
    expect(instrumented_content).to.match("_firmo_coverage.track.-local result = a %- b")
    -- Should have tracking before if statement
    expect(instrumented_content).to.match("_firmo_coverage.track.-if result < 0")
    -- Should have tracking before returns
    expect(instrumented_content).to.match("_firmo_coverage.track.-return 0")
    expect(instrumented_content).to.match("_firmo_coverage.track.-return result")
  end)

  it("should handle edge cases", function()
    -- Create original file with edge cases
    local original_content = [[
      -- Empty function
      local function empty() end

      -- One-liner
      local function one() return 1 end

      -- Multiple returns
      local function multi(x)
        if x < 0 then return -1
        elseif x > 0 then return 1
        else return 0 end
      end

      -- Nested functions
      local function outer()
        local function inner()
          return true
        end
        return inner()
      end
    ]]
    local original_path = fs.join_paths(test_dir.path, "edge_cases.lua")
    test_dir.create_file("edge_cases.lua", original_content)

    -- Instrument the file
    local result = instrumentation.instrument_file(original_path)
    expect(result).to.exist()

    -- Check instrumented content
    local instrumented_content = fs.read_file(result.instrumented_path)
    -- Should handle empty function
    expect(instrumented_content).to.match("function empty%(%)")
    -- Should handle one-liner
    expect(instrumented_content).to.match("_firmo_coverage.track.-return 1")
    -- Should handle multiple returns
    expect(instrumented_content).to.match("_firmo_coverage.track.-return %-1")
    expect(instrumented_content).to.match("_firmo_coverage.track.-return 1")
    expect(instrumented_content).to.match("_firmo_coverage.track.-return 0")
    -- Should handle nested functions
    expect(instrumented_content).to.match("_firmo_coverage.track.-function outer")
    expect(instrumented_content).to.match("_firmo_coverage.track.-function inner")
  end)

  it("should handle syntax errors gracefully", { expect_error = true }, function()
    -- Create file with syntax error
    local original_content = [[
      local x = -- incomplete statement
      return x
    ]]
    local original_path = fs.join_paths(test_dir.path, "syntax_error.lua")
    test_dir.create_file("syntax_error.lua", original_content)

    -- Try to instrument the file
    local result, err = test_helper.with_error_capture(function()
      return instrumentation.instrument_file(original_path)
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("syntax error")
  end)

  it("should handle missing files gracefully", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return instrumentation.instrument_file("/nonexistent/file.lua")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("file not found")
  end)

  it("should create instrumented files in temp directory", function()
    -- Create original file
    local original_content = "return true"
    local original_path = fs.join_paths(test_dir.path, "temp_test.lua")
    test_dir.create_file("temp_test.lua", original_content)

    -- Instrument the file
    local result = instrumentation.instrument_file(original_path)
    expect(result).to.exist()

    -- Check that instrumented file is in temp directory
    local instrumented_path = result.instrumented_path
    expect(instrumented_path).to_not.match(test_dir.path) -- Not in test dir
    expect(instrumented_path).to.match("instrumented") -- In instrumented subdir

    -- Check that temp file is registered for cleanup
    local exists_before = fs.file_exists(instrumented_path)
    expect(exists_before).to.be_truthy()

    -- Trigger cleanup
    test_helper.cleanup_temp_files()

    -- File should be gone
    local exists_after = fs.file_exists(instrumented_path)
    expect(exists_after).to.be_falsy()
  end)

  it("should handle require statements", function()
    -- Create a module file
    local module_content = [[
      local M = {}
      function M.add(a, b) return a + b end
      return M
    ]]
    local module_path = fs.join_paths(test_dir.path, "math.lua")
    test_dir.create_file("math.lua", module_content)

    -- Create main file that requires the module
    local main_content = [[
      local math = require("math")
      return math.add(2, 3)
    ]]
    local main_path = fs.join_paths(test_dir.path, "main.lua")
    test_dir.create_file("main.lua", main_content)

    -- Instrument both files
    local math_result = instrumentation.instrument_file(module_path)
    local main_result = instrumentation.instrument_file(main_path)
    expect(math_result).to.exist()
    expect(main_result).to.exist()

    -- Check that require statement is preserved
    local main_instrumented = fs.read_file(main_result.instrumented_path)
    expect(main_instrumented).to.match('require%("math"%)')

    -- Check that module functions are instrumented
    local math_instrumented = fs.read_file(math_result.instrumented_path)
    expect(math_instrumented).to.match("_firmo_coverage.track.-function M.add")
  end)

  it("should preserve comments and whitespace", function()
    -- Create file with various comments and whitespace
    local original_content = [[
      -- Header comment

      local x = 1 -- Line comment

      --[=[ Another
           block comment ]=]
      return x -- Final comment
    ]]

    local original_path = fs.join_paths(test_dir.path, "comments.lua")
    test_dir.create_file("comments.lua", original_content)

    -- Instrument the file
    local result = instrumentation.instrument_file(original_path)
    expect(result).to.exist()

    -- Check instrumented content
    local instrumented_content = fs.read_file(result.instrumented_path)
    -- Comments should be preserved
    expect(instrumented_content).to.match("%-%-[^%[]") -- Line comments
    expect(instrumented_content).to.match("%-%-[[") -- Block comment start
    expect(instrumented_content).to.match("block comment") -- Block comment content
    expect(instrumented_content).to.match("Final comment") -- End line comment
    -- Whitespace should be preserved
    expect(instrumented_content).to.match("\n\n") -- Empty lines
    expect(instrumented_content).to.match("  ") -- Indentation
  end)

  it("should handle all Lua syntax elements", function()
    -- Create file with comprehensive Lua syntax
    local original_content = [[
      -- Variables and values
      local a, b, c = 1, "two", true
      local t = {
        x = 10,
        ["y"] = 20,
        [1] = 30
      }

      -- Control structures
      while a < 10 do
        a = a + 1
      end

      repeat
        b = b .. "2"
      until #b > 5

      for i = 1, 10 do
        if i % 2 == 0 then
          t[i] = i
        end
      end

      for k, v in pairs(t) do
        if type(v) == "number" then
          t[k] = v * 2
        end
      end

      -- Functions
      local function f1(x, y, ...)
        return x + y, ...
      end

      local f2 = function(...)
        return select(1, ...)
      end

      -- Metatables
      local mt = {
        __index = function(t, k)
          return k * 2
        end,
        __newindex = function(t, k, v)
          rawset(t, k, v * 2)
        end
      }
      setmetatable(t, mt)

      -- Error handling
      local ok, err = pcall(function()
        error("test error")
      end)

      return t
    ]]
    local original_path = fs.join_paths(test_dir.path, "comprehensive.lua")
    test_dir.create_file("comprehensive.lua", original_content)

    -- Instrument the file
    local result = instrumentation.instrument_file(original_path)
    expect(result).to.exist()

    -- Check instrumented content
    local instrumented_content = fs.read_file(result.instrumented_path)
    -- Should have tracking before each statement type
    expect(instrumented_content).to.match("_firmo_coverage.track.-local a, b, c")
    expect(instrumented_content).to.match("_firmo_coverage.track.-while a < 10")
    expect(instrumented_content).to.match("_firmo_coverage.track.-repeat")
    expect(instrumented_content).to.match("_firmo_coverage.track.-for i = 1")
    expect(instrumented_content).to.match("_firmo_coverage.track.-for k, v in pairs")
    expect(instrumented_content).to.match("_firmo_coverage.track.-local function f1")
    expect(instrumented_content).to.match("_firmo_coverage.track.-local f2 = function")
    expect(instrumented_content).to.match("_firmo_coverage.track.-setmetatable")
    expect(instrumented_content).to.match("_firmo_coverage.track.-local ok, err = pcall")
    -- Should preserve all syntax
    expect(instrumented_content).to.match("local t = {")
    expect(instrumented_content).to.match('%["y"%] = 20')
    expect(instrumented_content).to.match("until #b > 5")
    expect(instrumented_content).to.match("function%(%.%.%.")
    expect(instrumented_content).to.match("__index = function")
  end)
end)
