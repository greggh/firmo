--- Temporary File Module Stress Tests
---
--- Pushes the limits of the `lib.tools.filesystem.temp_file` module with extremely
--- large file counts (5000+) and deeply nested directory structures (5 levels).
--- Focuses on ensuring the module remains stable and performs reasonably under heavy load,
--- including creation and cleanup operations. Measures and reports execution times.
--- Includes a high timeout value to accommodate potentially long-running operations.
---
--- @author Firmo Team
--- @test

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after

local temp_file = require("lib.tools.filesystem.temp_file")
local temp_file_integration = require("lib.tools.filesystem.temp_file_integration")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

-- Set very high timeout for these tests
local VERY_HIGH_TIMEOUT = 120 -- seconds

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
  io.write(string.format("\n=== Starting: %s ===\n", operation_name))
  io.flush()

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

describe("temp_file_stress_test", function()
  -- Ensure firmo integration is initialized
  before(function()
    _G.firmo = firmo
    temp_file_integration.initialize()
    math.randomseed(os.time())
  end)

  -- Clean up any leftover files from previous test runs
  before(function()
    temp_file.cleanup_all()
  end)

  describe("extreme_file_count", function()
    it("should handle 5000+ files without timeout", { timeout = VERY_HIGH_TIMEOUT }, function()
      local file_count = 5000 -- Very large number of files
      local file_paths = {}

      -- Create a base directory for all files to make cleanup easier to observe
      local base_dir, err = temp_file.create_temp_directory()
      expect(err).to_not.exist()

      -- Measure time for creating many files
      local create_time = measure_time("Creating " .. file_count .. " files", function()
        for i = 1, file_count do
          local content = "minimal content " .. i -- Keep content minimal for speed
          local file_path = base_dir .. "/file_" .. i .. ".txt"
          local success, err = fs.write_file(file_path, content)
          expect(success).to.be_truthy("Failed to create file: " .. tostring(err))
          temp_file.register_file(file_path)

          -- Log progress periodically to show test is running
          if i % 1000 == 0 then
            io.write(string.format("Created %d/%d files...\n", i, file_count))
            io.flush()
          end
        end
      end)

      -- Simple validation that files exist
      for i = 1, 50 do -- Check a sample of files
        local index = math.random(1, file_count)
        local file_path = base_dir .. "/file_" .. index .. ".txt"
        expect(fs.file_exists(file_path)).to.be_truthy("File " .. index .. " should exist")
      end

      -- Report file creation stats
      io.write(string.format("File creation rate: %.2f files/second\n", file_count / create_time))
      io.flush()

      -- Before cleaning up, count files to verify
      local file_count_actual = 0
      local entries = fs.get_directory_contents(base_dir)
      if entries then
        file_count_actual = #entries
      end

      io.write(string.format("Verified %d files exist before cleanup\n", file_count_actual))
      io.flush()

      -- Measure time for a complete cleanup of all files
      local cleanup_time, success, errors =
        measure_time("Cleaning up " .. file_count .. " files", temp_file.cleanup_all)

      expect(success).to.be_truthy("Cleanup should succeed")

      -- Verify all files are gone
      expect(fs.directory_exists(base_dir)).to.be_falsy("Base directory should be removed")

      -- Report cleanup stats
      io.write(string.format("Cleanup rate: %.2f files/second\n", file_count / cleanup_time))
      io.flush()
    end)
  end)

  describe("very_complex_structure", function()
    it("should handle extremely complex directory structures", { timeout = VERY_HIGH_TIMEOUT }, function()
      -- Create a complex nested structure with a reasonable number of files
      local depth = 5 -- Maximum directory depth
      local width = 3 -- Directories per level
      local files_per_dir = 5 -- Files in each directory

      local base_dir, err = temp_file.create_temp_directory()
      expect(err).to_not.exist()

      local total_expected_dirs = 0
      local total_expected_files = 0

      -- Calculate expected totals
      for i = 0, depth do
        local dirs_at_level = width ^ i
        total_expected_dirs = total_expected_dirs + dirs_at_level
        total_expected_files = total_expected_files + (dirs_at_level * files_per_dir)
      end

      io.write(
        string.format(
          "Creating complex structure: %d directories and %d files\n",
          total_expected_dirs,
          total_expected_files
        )
      )
      io.flush()
      --- Recursively creates a nested directory structure with files in each directory.
      --- Registers created files and directories with the `temp_file` module.
      ---@param path string The current directory path to build within.
      ---@param current_depth number The current nesting depth.
      ---@return nil
      ---@private
      ---@throws table If file or directory creation fails critically (via `expect`).
      local function create_dirs(path, current_depth)
        if current_depth > depth then
          return
        end

        -- Create files in this directory
        for f = 1, files_per_dir do
          local file_path = path .. "/file_" .. f .. ".txt"
          local success, err = fs.write_file(file_path, "Content " .. current_depth .. "_" .. f)
          expect(success).to.be_truthy("Failed to create file: " .. tostring(err))
          temp_file.register_file(file_path)
        end

        -- Create subdirectories
        for d = 1, width do
          local subdir_path = path .. "/dir_" .. d
          local success, err = fs.create_directory(subdir_path)
          expect(success).to.be_truthy("Failed to create directory: " .. tostring(err))
          temp_file.register_directory(subdir_path)

          -- Recurse into subdirectory
          create_dirs(subdir_path, current_depth + 1)
        end
      end

      -- Create the structure and measure time
      local create_time = measure_time("Creating complex directory structure", function()
        create_dirs(base_dir, 1)
      end)

      -- Verify base directory exists
      expect(fs.directory_exists(base_dir)).to.be_truthy()

      -- Report creation stats
      io.write(string.format("Structure creation rate: %.2f files/second\n", total_expected_files / create_time))
      io.flush()

      -- Measure cleanup time
      local cleanup_time, success, errors =
        measure_time("Cleaning up complex directory structure", temp_file.cleanup_all)

      expect(success).to.be_truthy("Cleanup should succeed")

      -- Verify base directory is gone
      expect(fs.directory_exists(base_dir)).to.be_falsy()

      -- Report cleanup stats
      io.write(string.format("Structure cleanup rate: %.2f files/second\n", total_expected_files / cleanup_time))
      io.flush()
    end)
  end)

  describe("parallel_temp_contexts", function()
    it("should handle multiple contexts efficiently", { timeout = VERY_HIGH_TIMEOUT }, function()
      -- Create multiple independent contexts and files associated with them
      local context_count = 20
      local files_per_context = 50

      local contexts = {}
      local all_files = {}

      -- Create all contexts and files
      local create_time = measure_time(
        "Creating " .. context_count .. " contexts with " .. files_per_context .. " files each",
        function()
          for c = 1, context_count do
            local context = "test_context_" .. c
            table.insert(contexts, context)

            -- Create files for this context
            for f = 1, files_per_context do
              local file_path, err =
                temp_file.create_with_content("Content for context " .. c .. ", file " .. f, "txt", context)
              expect(err).to_not.exist()
              table.insert(all_files, file_path)
            end

            -- Log progress periodically
            if c % 20 == 0 then
              io.write(string.format("Created %d/%d contexts...\n", c, context_count))
              io.flush()
            end
          end
        end
      )

      -- Report creation stats
      local total_files = context_count * files_per_context
      io.write(string.format("Context file creation rate: %.2f files/second\n", total_files / create_time))
      io.flush()

      -- Verify some random files exist
      for i = 1, 50 do
        local index = math.random(1, #all_files)
        expect(fs.file_exists(all_files[index])).to.be_truthy()
      end

      -- Clean up contexts individually and measure time
      local total_cleanup_time = 0

      for c, context in ipairs(contexts) do
        local cleanup_time, success, errors =
          measure_time("Cleaning up context " .. c, temp_file.cleanup_test_context, context)

        expect(success).to.be_truthy("Cleanup for context " .. context .. " should succeed")
        total_cleanup_time = total_cleanup_time + cleanup_time

        -- Log progress periodically
        if c % 20 == 0 then
          io.write(string.format("Cleaned up %d/%d contexts...\n", c, context_count))
          io.flush()
        end
      end

      -- Report cleanup stats
      io.write(string.format("Individual context cleanup - total time: %.6f seconds\n", total_cleanup_time))
      io.write(string.format("Average cleanup time per context: %.6f seconds\n", total_cleanup_time / context_count))
      io.flush()

      -- Verify all files are gone
      for _, file_path in ipairs(all_files) do
        expect(fs.file_exists(file_path)).to.be_falsy()
      end
    end)
  end)
end)
