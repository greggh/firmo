-- Path mapping tests for v3 coverage system
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local path_mapping = require("lib.coverage.v3.path_mapping")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Coverage v3 Path Mapping", function()
  -- Test directory for each test
  local test_dir

  before(function()
    -- Create fresh test directory
    test_dir = test_helper.create_temp_test_directory()
  end)

  it("should map temp file path to original path", function()
    -- Create original file
    local original_path = fs.join_paths(test_dir.path, "original.lua")
    test_dir.create_file("original.lua", "-- test content")

    -- Create temp file
    local temp_path = test_dir.create_file("instrumented/original.lua", "-- instrumented content")

    -- Register mapping
    local success = path_mapping.register_path_pair(original_path, temp_path)
    expect(success).to.be_truthy()

    -- Test mapping
    local mapped_path = path_mapping.get_original_path(temp_path)
    expect(mapped_path).to.equal(original_path)

    -- Test reverse mapping
    local temp_mapped_path = path_mapping.get_temp_path(original_path)
    expect(temp_mapped_path).to.equal(temp_path)
  end)

  it("should handle multiple files", function()
    -- Create multiple original files
    local original1 = fs.join_paths(test_dir.path, "file1.lua")
    local original2 = fs.join_paths(test_dir.path, "file2.lua")
    test_dir.create_file("file1.lua", "-- test content 1")
    test_dir.create_file("file2.lua", "-- test content 2")

    -- Create temp files
    local temp1 = test_dir.create_file("instrumented/file1.lua", "-- instrumented 1")
    local temp2 = test_dir.create_file("instrumented/file2.lua", "-- instrumented 2")

    -- Register mappings
    path_mapping.register_path_pair(original1, temp1)
    path_mapping.register_path_pair(original2, temp2)

    -- Test mappings
    expect(path_mapping.get_original_path(temp1)).to.equal(original1)
    expect(path_mapping.get_original_path(temp2)).to.equal(original2)
    expect(path_mapping.get_temp_path(original1)).to.equal(temp1)
    expect(path_mapping.get_temp_path(original2)).to.equal(temp2)
  end)

  it("should handle nested directories", function()
    -- Create nested original structure
    local original = fs.join_paths(test_dir.path, "src/module/file.lua")
    test_dir.create_file("src/module/file.lua", "-- test content")

    -- Create nested temp structure
    local temp = test_dir.create_file("instrumented/src/module/file.lua", "-- instrumented")

    -- Register mapping
    path_mapping.register_path_pair(original, temp)

    -- Test mapping
    expect(path_mapping.get_original_path(temp)).to.equal(original)
    expect(path_mapping.get_temp_path(original)).to.equal(temp)
  end)

  it("should handle symlinks", { expect_error = true }, function()
    -- Create original file
    local original = fs.join_paths(test_dir.path, "real.lua")
    test_dir.create_file("real.lua", "-- test content")

    -- Create symlink (if supported)
    local symlink = fs.join_paths(test_dir.path, "link.lua")
    local result, err = test_helper.with_error_capture(function()
      return os.execute(string.format("ln -s %s %s", original, symlink))
    end)()

    -- Only test if symlinks are supported
    if result then
      -- Create temp file
      local temp = test_dir.create_file("instrumented/link.lua", "-- instrumented")

      -- Register mapping using symlink path
      path_mapping.register_path_pair(symlink, temp)

      -- Should map to real path
      expect(path_mapping.get_original_path(temp)).to.equal(original)
    end
  end)

  it("should handle missing mappings gracefully", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return path_mapping.get_original_path("/nonexistent/temp/path")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("No mapping found")
  end)

  it("should validate paths", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return path_mapping.register_path_pair(nil, "/some/path")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Invalid path")
  end)

  it("should clear mappings", function()
    -- Create and register a mapping
    local original = fs.join_paths(test_dir.path, "file.lua")
    local temp = test_dir.create_file("instrumented/file.lua", "-- content")
    path_mapping.register_path_pair(original, temp)

    -- Clear mappings
    path_mapping.clear()

    -- Should no longer find mapping
    local result, err = test_helper.with_error_capture(function()
      return path_mapping.get_original_path(temp)
    end)()
    expect(result).to_not.exist()
    expect(err).to.exist()
  end)

  it("should normalize paths before mapping", function()
    -- Create paths with different representations
    local original = fs.join_paths(test_dir.path, "dir/../file.lua")
    local temp = test_dir.create_file("instrumented/./file.lua", "-- content")

    -- Register with non-normalized paths
    path_mapping.register_path_pair(original, temp)

    -- Should still map correctly using filesystem's normalize_path
    local normalized_original = fs.normalize_path(original)
    local normalized_temp = fs.normalize_path(temp)

    expect(path_mapping.get_original_path(temp)).to.equal(normalized_original)
    expect(path_mapping.get_temp_path(original)).to.equal(normalized_temp)
  end)
end)