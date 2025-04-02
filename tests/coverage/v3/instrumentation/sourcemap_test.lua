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

  it("should properly populate and use tracking_lookup field", function()
    -- Create original file with known line positions
    local original_content = [[
      local x = 1  -- Line 1
      local y = 2  -- Line 2
      
      if x > 0 then  -- Line 4
        y = y + 1    -- Line 5
      end            -- Line 6
      
      return y       -- Line 8
    ]]
    local original_path = fs.join_paths(test_dir.path, "tracking_lookup.lua")
    test_dir.create_file("tracking_lookup.lua", original_content)
    
    -- Create instrumented file with tracking calls
    local instrumented_content = [[
      _firmo_coverage.track(1)
      local x = 1  -- Original Line 1
      _firmo_coverage.track(2)
      local y = 2  -- Original Line 2
      
      _firmo_coverage.track(3)
      if x > 0 then  -- Original Line 4
        _firmo_coverage.track(4)
        y = y + 1    -- Original Line 5
      end            -- Original Line 6
      
      _firmo_coverage.track(5)
      return y       -- Original Line 8
    ]]
    local instrumented_path = test_dir.create_file("instrumented/tracking_lookup.lua", instrumented_content)
    
    -- Create source map
    local map = sourcemap.create(original_path, original_content, instrumented_content)
    expect(map).to.exist()
    
    -- Verify tracking_lookup field exists and contains correct data
    expect(map.tracking_lookup).to.exist()
    
    -- Verify specific lookups from the tracking_lookup table
    -- Each entry should show where a tracking call was inserted
    expect(map.tracking_lookup[1]).to.equal(1) -- First tracking before line 1
    expect(map.tracking_lookup[2]).to.equal(3) -- Second tracking before line 2
    expect(map.tracking_lookup[3]).to.equal(6) -- Third tracking before line 4
    expect(map.tracking_lookup[4]).to.equal(8) -- Fourth tracking before line 5
    expect(map.tracking_lookup[5]).to.equal(11) -- Fifth tracking before line 8

    -- Test line mappings exactly as specified in the plan
    expect(sourcemap.get_instrumented_line(map, 1)).to.equal(2) -- line 1 → instrumented line 2
    expect(sourcemap.get_instrumented_line(map, 2)).to.equal(4) -- line 2 → instrumented line 4
    expect(sourcemap.get_instrumented_line(map, 4)).to.equal(7) -- line 4 → instrumented line 7
    expect(sourcemap.get_instrumented_line(map, 5)).to.equal(9) -- line 5 → instrumented line 9
    expect(sourcemap.get_instrumented_line(map, 8)).to.equal(12) -- line 8 → instrumented line 12
    
    -- Test reverse mapping
    expect(sourcemap.get_original_line(map, 2)).to.equal(1)
    expect(sourcemap.get_original_line(map, 4)).to.equal(2)
    expect(sourcemap.get_original_line(map, 7)).to.equal(4)
    expect(sourcemap.get_original_line(map, 9)).to.equal(5)
    expect(sourcemap.get_original_line(map, 12)).to.equal(8)
  end)
  
  it("should handle complex multi-line statements with tracking calls", function()
    -- Create original file with complex multi-line statements
    local original_content = [[
      local result = (1 +           -- Line 1
                     2) *           -- Line 2
                    (function()     -- Line 3
                      return 3 +    -- Line 4
                             4      -- Line 5
                     end)()         -- Line 6
                     
      if (result > 10 and          -- Line 8
          result < 20) then        -- Line 9
        result = result + 5        -- Line 10
      end                          -- Line 11
    ]]
    local original_path = fs.join_paths(test_dir.path, "complex_multiline.lua")
    test_dir.create_file("complex_multiline.lua", original_content)
    
    -- Create instrumented file with tracking calls at appropriate boundaries
    local instrumented_content = [[
      _firmo_coverage.track(1)
      local result = (1 +           -- Original Line 1
                     2) *           -- Original Line 2
                    (function()     -- Original Line 3
                      _firmo_coverage.track(2)
                      return 3 +    -- Original Line 4
                             4      -- Original Line 5
                     end)()         -- Original Line 6
                     
      _firmo_coverage.track(3)
      if (result > 10 and          -- Original Line 8
          result < 20) then        -- Original Line 9
        _firmo_coverage.track(4)
        result = result + 5        -- Original Line 10
      end                          -- Original Line 11
    ]]
    local instrumented_path = test_dir.create_file("instrumented/complex_multiline.lua", instrumented_content)
    
    -- Create source map
    local map = sourcemap.create(original_path, original_content, instrumented_content)
    expect(map).to.exist()
    
    -- Check tracking_lookup table
    expect(map.tracking_lookup).to.exist()
    expect(map.tracking_lookup[1]).to.equal(1)  -- First tracking call at line 1
    expect(map.tracking_lookup[2]).to.equal(5)  -- Second tracking call inside function
    expect(map.tracking_lookup[3]).to.equal(9)  -- Third tracking call before if statement
    expect(map.tracking_lookup[4]).to.equal(12) -- Fourth tracking call inside if body
    
    -- Test multi-line statement boundaries
    -- The first statement spans lines 1-6 in original
    expect(sourcemap.get_instrumented_line(map, 1)).to.equal(2)  -- Start of assignment
    expect(sourcemap.get_instrumented_line(map, 3)).to.equal(4)  -- Function declaration
    expect(sourcemap.get_instrumented_line(map, 4)).to.equal(6)  -- Inside function
    expect(sourcemap.get_instrumented_line(map, 6)).to.equal(8)  -- End of function call
    
    -- The if statement spans lines 8-11 in original
    expect(sourcemap.get_instrumented_line(map, 8)).to.equal(10)  -- Start of if condition
    expect(sourcemap.get_instrumented_line(map, 10)).to.equal(13) -- Inside if body
    
    -- Test that tracking calls are correctly positioned before statements
    -- by checking if the instrumented line for a statement is always the tracking line + 1
    local tracking_positions = {
      { tracking_idx = 1, orig_line = 1, expected_inst_line = 2 },
      { tracking_idx = 2, orig_line = 4, expected_inst_line = 6 },
      { tracking_idx = 3, orig_line = 8, expected_inst_line = 10 },
      { tracking_idx = 4, orig_line = 10, expected_inst_line = 13 }
    }
    
    for _, pos in ipairs(tracking_positions) do
      local tracking_line = map.tracking_lookup[pos.tracking_idx]
      local instrumented_line = sourcemap.get_instrumented_line(map, pos.orig_line)
      
      -- Verify tracking call is right before the statement
      expect(instrumented_line).to.equal(pos.expected_inst_line)
      expect(instrumented_line).to.equal(tracking_line + 1)
    end
  end)
  
  it("should verify precise line mappings according to the plan", function()
    -- Create test file specifically to match line mappings from the plan
    local original_content = [[
      -- Line 1: Comment
      local x = 1  -- Line 2: matches instrumented line 3
      local y = 2  -- Line 3
      local z = 3  -- Line 4: matches instrumented line 6
      x = x + 1    -- Line 5: matches instrumented line 8
      y = y + 1    -- Line 6
      z = z + 1    -- Line 7
      return x+y+z -- Line 8: matches instrumented line 11
    ]]
    local original_path = fs.join_paths(test_dir.path, "plan_mapping.lua")
    test_dir.create_file("plan_mapping.lua", original_content)
    
    -- Create instrumented version with tracking calls positioned to match plan
    local instrumented_content = [[
      -- Line 1: Comment
      _firmo_coverage.track(1)  -- Added tracking line
      local x = 1  -- Original line 2 → instrumented line 3
      _firmo_coverage.track(2)  -- Added tracking line
      _firmo_coverage.track(3)  -- Added tracking line
      local z = 3  -- Original line 4 → instrumented line 6
      _firmo_coverage.track(4)  -- Added tracking line
      x = x + 1    -- Original line 5 → instrumented line 8
      _firmo_coverage.track(5)  -- Added tracking line
      _firmo_coverage.track(6)  -- Added tracking line
      return x+y+z -- Original line 8 → instrumented line 11
    ]]
    local instrumented_path = test_dir.create_file("instrumented/plan_mapping.lua", instrumented_content)
    
    -- Create source map
    local map = sourcemap.create(original_path, original_content, instrumented_content)
    expect(map).to.exist()
    
    -- Verify tracking_lookup values
    expect(map.tracking_lookup).to.exist()
    
    -- Test the EXACT mappings specified in the plan
    expect(sourcemap.get_instrumented_line(map, 2)).to.equal(3)  -- Line 2 maps to instrumented line 3
    expect(sourcemap.get_instrumented_line(map, 4)).to.equal(6)  -- Line 4 maps to instrumented line 6
    expect(sourcemap.get_instrumented_line(map, 5)).to.equal(8)  -- Line 5 maps to instrumented line 8
    expect(sourcemap.get_instrumented_line(map, 8)).to.equal(11) -- Line 8 maps to instrumented line 11
    
    -- Test reverse mappings too
    expect(sourcemap.get_original_line(map, 3)).to.equal(2)
    expect(sourcemap.get_original_line(map, 6)).to.equal(4)
    expect(sourcemap.get_original_line(map, 8)).to.equal(5)
    expect(sourcemap.get_original_line(map, 11)).to.equal(8)
  end)
end)
