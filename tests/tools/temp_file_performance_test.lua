-- Performance tests for temp_file module

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local temp_file = require("lib.tools.temp_file")
local temp_file_integration = require("lib.tools.temp_file_integration")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack_table = table.unpack or unpack

-- Helper function for measuring execution time
local function measure_time(operation_name, func, ...)
  local start_time = os.clock()
  local results = { func(...) }
  local end_time = os.clock()
  local elapsed = end_time - start_time

  -- Write to console immediately for visibility
  io.write(string.format("\n=== PERFORMANCE: %s took %.6f seconds ===\n", operation_name, elapsed))
  io.flush()

  return elapsed, unpack_table(results)
end

describe("temp_file_performance", function()
  -- Ensure firmo integration is initialized
  before(function()
    _G.firmo = firmo
    temp_file_integration.initialize()
  end)

  describe("file creation performance", function()
    it("should create and track files efficiently", function()
      local file_count = 50 -- Number of files to create
      local file_paths = {}

      -- Measure time for creating many files
      local create_time = measure_time("Creating " .. file_count .. " files", function()
        for i = 1, file_count do
          local content = string.rep("line " .. i .. "\n", 10) -- 10 lines per file
          local file_path, err = temp_file.create_with_content(content, "txt")
          expect(err).to_not.exist()
          table.insert(file_paths, file_path)
        end
      end)

      -- Verify all files exist
      for _, path in ipairs(file_paths) do
        expect(fs.file_exists(path)).to.be_truthy()
      end

      -- Measure cleanup time
      local cleanup_time = measure_time("Cleaning up " .. file_count .. " files", function()
        local success, errors = temp_file.cleanup_all()
        expect(success).to.be_truthy()
      end)

      -- Verify all files are gone
      for _, path in ipairs(file_paths) do
        expect(fs.file_exists(path)).to.be_falsy()
      end
    end)
  end)

  describe("directory creation performance", function()
    it("should create and track directories efficiently", function()
      local dir_count = 30 -- Number of directories to create
      local dir_paths = {}

      -- Measure time for creating many directories
      local create_time = measure_time("Creating " .. dir_count .. " directories with files", function()
        for i = 1, dir_count do
          local dir_path, err = temp_file.create_temp_directory()
          expect(err).to_not.exist()
          table.insert(dir_paths, dir_path)

          -- Create a few files in each directory
          for j = 1, 5 do
            local file_path = dir_path .. "/file_" .. j .. ".txt"
            local content = string.rep("line " .. j .. "\n", 5) -- 5 lines per file
            local success, err = fs.write_file(file_path, content)
            expect(success).to.be_truthy()
            temp_file.register_file(file_path)
          end
        end
      end)

      -- Verify all directories exist
      for _, path in ipairs(dir_paths) do
        expect(fs.directory_exists(path)).to.be_truthy()
      end

      -- Measure cleanup time
      local cleanup_time = measure_time("Cleaning up " .. dir_count .. " directories with files", function()
        local success, errors = temp_file.cleanup_all()
        expect(success).to.be_truthy()
      end)

      -- Verify all directories are gone
      for _, path in ipairs(dir_paths) do
        expect(fs.directory_exists(path)).to.be_falsy()
      end
    end)
  end)

  describe("complex directory structure performance", function()
    it("should handle complex directory structures efficiently", function()
      local structure_count = 10 -- Number of complex structures to create
      local base_paths = {}

      -- Measure time for creating complex directory structures
      local create_time = measure_time("Creating " .. structure_count .. " complex directory structures", function()
        for i = 1, structure_count do
          local test_dir = test_helper.create_temp_test_directory()
          table.insert(base_paths, test_dir.path)

          -- Create 3 levels of nested directories with files
          for j = 1, 3 do
            for k = 1, 3 do
              for l = 1, 3 do
                local dir_path = string.format("level%d/level%d/level%d", j, k, l)
                for m = 1, 2 do
                  test_dir.create_file(dir_path .. "/file_" .. m .. ".txt", string.rep("content line " .. m .. "\n", 3))
                end
              end
            end
          end
        end
      end)

      -- Report creation time
      print(
        "PERFORMANCE: Created "
          .. structure_count
          .. " complex directory structures in "
          .. string.format("%.6f", create_time)
          .. " seconds ("
          .. string.format("%.6f", create_time / structure_count)
          .. " seconds per structure)"
      )

      -- Verify base directories exist
      for _, path in ipairs(base_paths) do
        expect(fs.directory_exists(path)).to.be_truthy()
      end

      -- Measure cleanup time
      local cleanup_time = measure_time("Cleaning up " .. structure_count .. " complex directory structures", function()
        local success, errors = temp_file.cleanup_all()
        expect(success).to.be_truthy()
      end)

      -- Report cleanup time
      print(
        "PERFORMANCE: Cleaned up "
          .. structure_count
          .. " complex directory structures in "
          .. string.format("%.6f", cleanup_time)
          .. " seconds ("
          .. string.format("%.6f", cleanup_time / structure_count)
          .. " seconds per structure)"
      )

      -- Verify all directories are gone
      for _, path in ipairs(base_paths) do
        expect(fs.directory_exists(path)).to.be_falsy()
      end
    end)
  end)
end)
