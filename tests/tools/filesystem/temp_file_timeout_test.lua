--- Temporary File Module Timeout Investigation Tests
---
--- This file focuses on testing the `temp_file` module with larger file counts,
--- deep nesting, and large file sizes to identify potential timeout issues or
--- significant performance bottlenecks during creation and cleanup.
--- Sets a high timeout value for tests. Measures and reports execution times.
---
--- @author Firmo Team
--- @test

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local temp_file = require("lib.tools.filesystem.temp_file")
local temp_file_integration = require("lib.tools.filesystem.temp_file_integration")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

-- Set high timeout for these tests
local HIGH_TIMEOUT = 30 -- seconds

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack_table = table.unpack or unpack

--- Measures the execution time of a given function and prints the result.
--- Uses `os.clock()` for timing.
---@param operation_name string A descriptive name for the operation being measured.
---@param func function The function to execute and time.
---@param ... any Arguments to pass to the `func`.
---@return number elapsed The elapsed time in seconds.
---@return ... any The return values from the executed `func`.
---@private
local function measure_time(operation_name, func, ...)
  local start_time = os.clock()
  local results = { func(...) }
  local end_time = os.clock()
  local elapsed = end_time - start_time

  -- Write to console immediately for visibility
  io.write(string.format("\n=== PERFORMANCE: %s took %.6f seconds ===\n", operation_name, elapsed))
  io.flush()
  -- Use compatibility unpack
  local unpack_table = table.unpack or unpack
  return elapsed, unpack_table(results)
end

--- Generates pseudo-random text content of a specified size.
---@param size_kb number The approximate target size in kilobytes.
---@return string content The generated content string.
---@private
local function generate_content(size_kb)
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  local content = ""
  local line_length = 80
  local lines_per_kb = 13 -- ~80 chars * 13 lines ≈ 1KB

  for i = 1, size_kb * lines_per_kb do
    local line = ""
    for j = 1, line_length do
      local random_index = math.random(1, #chars)
      line = line .. string.sub(chars, random_index, random_index)
    end
    content = content .. line .. "\n"
  end

  return content
end

describe("temp_file_timeout_investigation", function()
  -- Ensure firmo integration is initialized
  before(function()
    _G.firmo = firmo
    temp_file_integration.initialize()
    math.randomseed(os.time()) -- Initialize random seed
  end)

  describe("large_file_count", function()
    it("should handle 1000+ files without timeout", { timeout = HIGH_TIMEOUT }, function()
      local file_count = 1000 -- Large number of files
      local file_paths = {}

      -- Measure time for creating many files
      local create_time = measure_time("Creating " .. file_count .. " files", function()
        for i = 1, file_count do
          local content = "file " .. i .. " content\n" -- Keep content minimal
          local file_path, err = temp_file.create_with_content(content, "txt")
          expect(err).to_not.exist()
          table.insert(file_paths, file_path)

          -- Log progress periodically to show test is running
          if i % 200 == 0 then
            io.write(string.format("Created %d/%d files...\n", i, file_count))
            io.flush()
          end
        end
      end)

      -- Verify file count matches expected
      expect(#file_paths).to.equal(file_count)

      -- Sample check - verify some files exist
      for i = 1, 10 do
        local index = math.random(1, file_count)
        expect(fs.file_exists(file_paths[index])).to.be_truthy()
      end

      -- Measure cleanup time
      local cleanup_time = measure_time("Cleaning up " .. file_count .. " files", function()
        local success, errors = temp_file.cleanup_all()
        expect(success).to.be_truthy()
      end)

      -- Sample check - verify some files are gone
      for i = 1, 10 do
        local index = math.random(1, file_count)
        expect(fs.file_exists(file_paths[index])).to.be_falsy()
      end

      -- Report efficiency metrics
      print(
        string.format(
          "Average time per file: create=%.6f sec, cleanup=%.6f sec",
          create_time / file_count,
          cleanup_time / file_count
        )
      )
    end)
  end)

  describe("deep_directory_nesting", function()
    it("should handle deeply nested directories without timeout", { timeout = HIGH_TIMEOUT }, function()
      local nesting_depth = 20 -- Very deep nesting
      local base_dir, err = temp_file.create_temp_directory()
      expect(err).to_not.exist()

      -- Create deeply nested structure
      local elapsed_time, deepest_path = measure_time(
        "Creating deeply nested structure with depth " .. nesting_depth,
        function()
          local current_path = base_dir

          for i = 1, nesting_depth do
            current_path = current_path .. "/level" .. i
            local success, err = fs.create_directory(current_path)
            expect(success).to.be_truthy("Failed to create directory: " .. tostring(err))

            -- Add a file at each level
            local file_path = current_path .. "/file.txt"
            local success, err = fs.write_file(file_path, "Content at level " .. i)
            expect(success).to.be_truthy("Failed to write file: " .. tostring(err))
            temp_file.register_file(file_path)

            io.write("Created level " .. i .. " of " .. nesting_depth .. "\n")
            io.flush()
          end

          return current_path
        end
      )

      -- Verify deepest directory exists
      expect(fs.directory_exists(deepest_path)).to.be_truthy()

      -- Measure cleanup time
      local cleanup_time = measure_time("Cleaning up deeply nested structure", function()
        local success, errors = temp_file.cleanup_all()
        expect(success).to.be_truthy()
      end)

      -- Verify base directory is gone
      expect(fs.directory_exists(base_dir)).to.be_falsy()
    end)
  end)

  describe("large_file_sizes", function()
    it("should handle large file sizes without timeout", { timeout = HIGH_TIMEOUT }, function()
      local file_sizes = { 1, 5, 10, 50, 100 } -- Sizes in KB
      local file_paths = {}

      for _, size in ipairs(file_sizes) do
        local content = generate_content(size)
        local expected_size = string.len(content)

        -- Create file with large content
        local create_time, file_path, err =
          measure_time("Creating " .. size .. "KB file", temp_file.create_with_content, content, "dat")

        expect(err).to_not.exist()
        table.insert(file_paths, file_path)

        -- Verify file exists and has correct size
        expect(fs.file_exists(file_path)).to.be_truthy()
        local file_size = fs.get_file_size(file_path)
        expect(file_size).to.be_approximately(expected_size, expected_size * 0.1)

        print(string.format("File size: %d bytes, Creation time: %.6f seconds", file_size, create_time))
      end

      -- Measure cleanup time
      local cleanup_time = measure_time("Cleaning up files of various sizes", function()
        local success, errors = temp_file.cleanup_all()
        expect(success).to.be_truthy()
      end)

      -- Verify all files are gone
      for _, path in ipairs(file_paths) do
        expect(fs.file_exists(path)).to.be_falsy()
      end
    end)
  end)

  describe("complex_mixed_structure", function()
    it("should handle complex mixed structures without timeout", { timeout = HIGH_TIMEOUT }, function()
      local base_dirs = {}
      local structure_count = 5
      local files_per_structure = 200
      local max_depth = 10

      -- Create multiple complex structures with mixed file sizes and depths
      local create_time = measure_time(
        "Creating "
          .. structure_count
          .. " complex structures with "
          .. (structure_count * files_per_structure)
          .. " total files",
        function()
          for s = 1, structure_count do
            local base_dir, err = temp_file.create_temp_directory()
            expect(err).to_not.exist()
            table.insert(base_dirs, base_dir)

            -- Track progress
            io.write(string.format("Creating structure %d/%d...\n", s, structure_count))
            io.flush()

            -- Create files with varying depths and sizes
            for f = 1, files_per_structure do
              -- Randomly determine depth (0 = base directory)
              local depth = math.random(0, max_depth)
              local dir_path = base_dir

              -- Create nested path if depth > 0
              if depth > 0 then
                for d = 1, depth do
                  dir_path = dir_path .. "/dir" .. d

                  -- Create directory if it doesn't exist
                  if not fs.directory_exists(dir_path) then
                    local success, err = fs.create_directory(dir_path)
                    expect(success).to.be_truthy()
                    temp_file.register_directory(dir_path)
                  end
                end
              end

              -- Randomly determine file size (0.1 - 5 KB)
              local file_size = (math.random(1, 50) / 10)
              local content = generate_content(file_size)

              -- Create file
              local file_path = dir_path .. "/file" .. f .. ".txt"
              local success, err = fs.write_file(file_path, content)
              expect(success).to.be_truthy()
              temp_file.register_file(file_path)

              -- Log progress periodically
              if f % 50 == 0 then
                io.write(string.format("  Created %d/%d files in structure %d\n", f, files_per_structure, s))
                io.flush()
              end
            end
          end
        end
      )

      -- Verify base directories exist
      for _, path in ipairs(base_dirs) do
        expect(fs.directory_exists(path)).to.be_truthy()
      end

      -- Measure cleanup time
      local cleanup_time = measure_time(
        "Cleaning up complex mixed structures with " .. (structure_count * files_per_structure) .. " total files",
        function()
          local success, errors = temp_file.cleanup_all()
          expect(success).to.be_truthy()
        end
      )

      -- Verify base directories are gone
      for _, path in ipairs(base_dirs) do
        expect(fs.directory_exists(path)).to.be_falsy()
      end

      -- Report overall metrics
      local total_files = structure_count * files_per_structure
      print(string.format("Performance summary for %d total files:", total_files))
      print(string.format("- Creation: %.6f sec (%.6f sec per file)", create_time, create_time / total_files))
      print(string.format("- Cleanup: %.6f sec (%.6f sec per file)", cleanup_time, cleanup_time / total_files))
    end)
  end)
end)
