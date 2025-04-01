-- Source map tests for v3 coverage system
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local sourcemap = require("lib.coverage.v3.instrumentation.sourcemap")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Coverage v3 Source Map", function()
  -- Test directory for each test
  local test_dir

  before(function()
    -- Create fresh test directory
    test_dir = test_helper.create_temp_test_directory()
  end)

  it("should map line numbers between original and instrumented code", function()
    -- Create original file with known line positions
    local original_content = [[
      -- Line 1: Comment
      local x = 1  -- Line 2

      local function test()  -- Line 4
        return x + 1  -- Line 5
      end  -- Line 6

      return test()  -- Line 8
    ]]
    local original_path = fs.join_paths(test_dir.path, "original.lua")
    test_dir.create_file("original.lua", original_content)

    -- Create instrumented file with tracking calls
    local instrumented_content = [[
      -- Line 1: Original comment
      _firmo_coverage.track(1)  -- Added line
      local x = 1  -- Original line 2

      _firmo_coverage.track(2)  -- Added line
      local function test()  -- Original line 4
        _firmo_coverage.track(3)  -- Added line
        return x + 1  -- Original line 5
      end  -- Original line 6

      _firmo_coverage.track(4)  -- Added line
      return test()  -- Original line 8
    ]]
    local instrumented_path = test_dir.create_file("instrumented/original.lua", instrumented_content)

    -- Create source map
    local map = sourcemap.create(original_path, original_content, instrumented_content)
    expect(map).to.exist()

    -- Test original to instrumented line mapping
    expect(sourcemap.get_instrumented_line(map, 2)).to.equal(3) -- x = 1
    expect(sourcemap.get_instrumented_line(map, 4)).to.equal(6) -- function test()
    expect(sourcemap.get_instrumented_line(map, 5)).to.equal(8) -- return x + 1
    expect(sourcemap.get_instrumented_line(map, 8)).to.equal(11) -- return test()

    -- Test instrumented to original line mapping
    expect(sourcemap.get_original_line(map, 3)).to.equal(2) -- x = 1
    expect(sourcemap.get_original_line(map, 6)).to.equal(4) -- function test()
    expect(sourcemap.get_original_line(map, 8)).to.equal(5) -- return x + 1
    expect(sourcemap.get_original_line(map, 11)).to.equal(8) -- return test()
  end)

  it("should handle multi-line statements", function()
    -- Create original file with multi-line statements
    local original_content = [[
      local x = (1 +
                2 +
                3)

      local result = x *
                    (4 +
                     5)
    ]]
    local original_path = fs.join_paths(test_dir.path, "multiline.lua")
    test_dir.create_file("multiline.lua", original_content)

    -- Create instrumented version
    local instrumented_content = [[
      _firmo_coverage.track(1)
      local x = (1 +
                2 +
                3)

      _firmo_coverage.track(2)
      local result = x *
                    (4 +
                     5)
    ]]
    local instrumented_path = test_dir.create_file("instrumented/multiline.lua", instrumented_content)

    -- Create source map
    local map = sourcemap.create(original_path, original_content, instrumented_content)
    expect(map).to.exist()

    -- Test mapping of multi-line statement start
    expect(sourcemap.get_instrumented_line(map, 1)).to.equal(2) -- x = (1 +
    expect(sourcemap.get_instrumented_line(map, 5)).to.equal(7) -- result = x *

    -- Test mapping back to original
    expect(sourcemap.get_original_line(map, 2)).to.equal(1)
    expect(sourcemap.get_original_line(map, 7)).to.equal(5)
  end)

  it("should handle empty lines and comments", function()
    -- Create original file with empty lines and comments
    local original_content = [[
      -- Header comment

      local x = 1

      -- Another comment
      return x
    ]]

    local original_path = fs.join_paths(test_dir.path, "comments.lua")
    test_dir.create_file("comments.lua", original_content)

    -- Create instrumented version
    local instrumented_content = [[
      -- Header comment

      _firmo_coverage.track(1)
      local x = 1

      -- Another comment
      _firmo_coverage.track(2)
      return x
    ]]

    local instrumented_path = test_dir.create_file("instrumented/comments.lua", instrumented_content)

    -- Create source map
    local map = sourcemap.create(original_path, original_content, instrumented_content)
    expect(map).to.exist()

    -- Test mapping with comments
    expect(sourcemap.get_instrumented_line(map, 6)).to.equal(7) -- local x = 1
    expect(sourcemap.get_instrumented_line(map, 9)).to.equal(11) -- return x

    -- Test mapping back to original
    expect(sourcemap.get_original_line(map, 7)).to.equal(6)
    expect(sourcemap.get_original_line(map, 11)).to.equal(9)
  end)

  it("should handle error locations", function()
    -- Create original file with potential error locations
    local original_content = [[
      local function might_error()
        error("Something went wrong")
      end

      local ok, err = pcall(might_error)
    ]]
    local original_path = fs.join_paths(test_dir.path, "errors.lua")
    test_dir.create_file("errors.lua", original_content)

    -- Create instrumented version
    local instrumented_content = [[
      _firmo_coverage.track(1)
      local function might_error()
        _firmo_coverage.track(2)
        error("Something went wrong")
      end

      _firmo_coverage.track(3)
      local ok, err = pcall(might_error)
    ]]
    local instrumented_path = test_dir.create_file("instrumented/errors.lua", instrumented_content)

    -- Create source map
    local map = sourcemap.create(original_path, original_content, instrumented_content)
    expect(map).to.exist()

    -- Test error location mapping
    local error_line = 2 -- Line with error() call in original
    local instrumented_error_line = sourcemap.get_instrumented_line(map, error_line)
    expect(instrumented_error_line).to.equal(4)

    -- Test mapping error location back to original
    local original_error_line = sourcemap.get_original_line(map, instrumented_error_line)
    expect(original_error_line).to.equal(error_line)
  end)

  it("should handle missing line mappings gracefully", { expect_error = true }, function()
    -- Create a minimal source map
    local original_path = fs.join_paths(test_dir.path, "minimal.lua")
    local original_content = "local x = 1\n"
    local instrumented_content = "_firmo_coverage.track(1)\nlocal x = 1\n"

    local map = sourcemap.create(original_path, original_content, instrumented_content)
    expect(map).to.exist()

    -- Try to map non-existent lines
    local result, err = test_helper.with_error_capture(function()
      return sourcemap.get_instrumented_line(map, 999)
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Invalid line number")
  end)

  it("should validate inputs", { expect_error = true }, function()
    -- Try to create map with invalid inputs
    local result, err = test_helper.with_error_capture(function()
      return sourcemap.create(nil, "", "")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Invalid path")

    -- Try with missing content
    result, err = test_helper.with_error_capture(function()
      return sourcemap.create("file.lua", nil, "")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Invalid content")
  end)

  it("should handle source maps for multiple files", function()
    -- Create first file
    local original1 = fs.join_paths(test_dir.path, "file1.lua")
    local content1 = "local x = 1\nreturn x\n"
    test_dir.create_file("file1.lua", content1)

    local instrumented1 = test_dir.create_file(
      "instrumented/file1.lua",
      "_firmo_coverage.track(1)\nlocal x = 1\n_firmo_coverage.track(2)\nreturn x\n"
    )

    -- Create second file
    local original2 = fs.join_paths(test_dir.path, "file2.lua")
    local content2 = "local y = 2\nreturn y\n"
    test_dir.create_file("file2.lua", content2)

    local instrumented2 = test_dir.create_file(
      "instrumented/file2.lua",
      "_firmo_coverage.track(1)\nlocal y = 2\n_firmo_coverage.track(2)\nreturn y\n"
    )

    -- Create source maps for both files
    local map1 = sourcemap.create(original1, content1, fs.read_file(instrumented1))
    local map2 = sourcemap.create(original2, content2, fs.read_file(instrumented2))

    expect(map1).to.exist()
    expect(map2).to.exist()

    -- Test mappings for first file
    expect(sourcemap.get_instrumented_line(map1, 1)).to.equal(2) -- local x = 1
    expect(sourcemap.get_instrumented_line(map1, 2)).to.equal(4) -- return x

    -- Test mappings for second file
    expect(sourcemap.get_instrumented_line(map2, 1)).to.equal(2) -- local y = 2
    expect(sourcemap.get_instrumented_line(map2, 2)).to.equal(4) -- return y
  end)

  it("should preserve source map across serialization", function()
    -- Create original file
    local original_path = fs.join_paths(test_dir.path, "serialize.lua")
    local original_content = "local x = 1\nreturn x\n"
    test_dir.create_file("serialize.lua", original_content)

    -- Create instrumented file
    local instrumented_content = [[
      _firmo_coverage.track(1)
      local x = 1
      _firmo_coverage.track(2)
      return x
    ]]
    local instrumented_path = test_dir.create_file("instrumented/serialize.lua", instrumented_content)

    -- Create source map
    local map = sourcemap.create(original_path, original_content, instrumented_content)
    expect(map).to.exist()

    -- Serialize and deserialize the map
    local serialized = sourcemap.serialize(map)
    expect(serialized).to.exist()

    local deserialized = sourcemap.deserialize(serialized)
    expect(deserialized).to.exist()

    -- Test that mappings still work
    expect(sourcemap.get_instrumented_line(deserialized, 1)).to.equal(2) -- local x = 1
    expect(sourcemap.get_instrumented_line(deserialized, 2)).to.equal(4) -- return x
  end)
end)
