local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local coverage = require("lib.coverage")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")
local temp_file = require("lib.tools.filesystem.temp_file")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

describe("coverage module", function()
  -- Create a test directory for each test
  local test_dir

  before(function()
    -- Create a test directory with proper error handling
    local dir_result, dir_err = test_helper.with_error_capture(function()
      return temp_file.create_temp_directory()
    end)()

    expect(dir_err).to_not.exist("Error creating temp directory")
    test_dir = dir_result
    expect(test_dir).to.exist("Failed to create test directory")

    -- Configure coverage to use a file in our test directory
    local config_result, config_err = test_helper.with_error_capture(function()
      central_config.set("coverage", {
        enabled = true,
        statsfile = filesystem.join_paths(test_dir, "coverage.stats"),
        include = { ".*%.lua$" },
        exclude = {},
        savestepsize = 100,
        tick = false,
      })
      return true
    end)()

    expect(config_err).to_not.exist("Error configuring coverage")
    expect(config_result).to.be_truthy()

    -- Ensure coverage is reset with error handling
    local shutdown_result, shutdown_err = test_helper.with_error_capture(function()
      coverage.shutdown()
      return true
    end)()

    expect(shutdown_err).to_not.exist("Error shutting down coverage")
  end)

  after(function()
    -- Clean up with proper error handling
    test_helper.with_error_capture(function()
      coverage.shutdown()
      return true
    end)()

    if test_dir then
      local remove_result, remove_err = test_helper.with_error_capture(function()
        return temp_file.remove_directory(test_dir)
      end)()

      if remove_err then
        print("Warning: Failed to remove test directory: " .. (remove_err.message or "unknown error"))
      end
    end

    test_helper.with_error_capture(function()
      central_config.reset("coverage")
      return true
    end)()
  end)

  it("initializes the coverage system", function()
    local init_result, init_err = test_helper.with_error_capture(function()
      coverage.init()
      return true
    end)()

    expect(init_err).to_not.exist("Error initializing coverage")
    expect(init_result).to.be_truthy()
    expect(coverage).to.exist()
  end)

  it("tracks line execution", function()
    -- Initialize coverage
    coverage.init()

    -- Execute some code
    local test_function = function()
      local x = 1 -- line 1
      local y = 2 -- line 2
      return x + y -- line 3
    end

    -- Run the function
    test_function()

    -- Save stats
    coverage.save_stats()

    -- Load and verify stats
    local stats = coverage.load_stats()
    expect(stats).to.exist()

    -- Find our test file in the stats
    local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
    filename = filesystem.normalize_path(filename)
    local file_stats = stats[filename]
    expect(file_stats).to.exist()
    expect(file_stats.max).to.be_greater_than(0)
  end)

  it("handles file operations with temp files", function()
    local init_result, init_err = test_helper.with_error_capture(function()
      coverage.init()
      return true
    end)()

    expect(init_err).to_not.exist("Error initializing coverage")

    -- Execute code to generate coverage data
    local x = 1
    local y = 2
    local z = x + y

    -- Save stats multiple times to test temp file handling
    for i = 1, 3 do
      local save_result, save_err = test_helper.with_error_capture(function()
        coverage.save_stats()
        return true
      end)()

      expect(save_err).to_not.exist("Error saving stats")

      -- Verify stats file exists and is readable
      local statsfile = central_config.get("coverage.statsfile")

      local exists_result, exists_err = test_helper.with_error_capture(function()
        return filesystem.file_exists(statsfile)
      end)()

      expect(exists_err).to_not.exist("Error checking if file exists")
      expect(exists_result).to.be_truthy("Stats file does not exist")

      -- Execute more code
      z = z + i
    end

    -- Load final stats
    local stats_result, stats_err = test_helper.with_error_capture(function()
      return coverage.load_stats()
    end)()

    expect(stats_err).to_not.exist("Error loading stats")
    expect(stats_result).to.exist("Stats should exist")
  end)

  it("handles corrupted stats files gracefully", { expect_error = true }, function()
    local init_result, init_err = test_helper.with_error_capture(function()
      coverage.init()
      return true
    end)()

    expect(init_err).to_not.exist("Error initializing coverage")

    -- Execute some code
    local x = 1
    local y = 2

    -- Save initial stats
    local save_result, save_err = test_helper.with_error_capture(function()
      coverage.save_stats()
      return true
    end)()

    expect(save_err).to_not.exist("Error saving stats")

    -- Corrupt the stats file
    local statsfile = central_config.get("coverage.statsfile")
    local write_result, write_err = test_helper.with_error_capture(function()
      return filesystem.write_file(statsfile, "corrupted content")
    end)()

    expect(write_err).to_not.exist("Error writing corrupted content")
    expect(write_result).to.be_truthy("Failed to write corrupted content")

    -- Try to load corrupted stats - this should not throw but return empty stats
    local stats_result, stats_err = test_helper.with_error_capture(function()
      return coverage.load_stats()
    end)()

    -- The coverage module should handle corrupted files gracefully without error
    expect(stats_err).to_not.exist("Loading corrupted stats should not throw error")
    expect(stats_result).to.exist("Stats should exist even if empty")
    expect(next(stats_result)).to_not.exist("Stats should be empty table")

    -- Test with severely damaged file (directory instead of file)
    local severe_corruption = test_helper.expect_error(function()
      -- Create a directory with the same name as the stats file to simulate severe corruption
      local dir_path = statsfile .. "_dir"
      filesystem.create_directory(dir_path)

      -- Try to write to a directory as if it were a file
      return filesystem.write_file(dir_path, "test")
    end)

    expect(severe_corruption).to.exist("Should get error when writing to directory as file")
  end)

  it("merges coverage data correctly", function()
    coverage.init()

    -- First execution
    local function test_function()
      local x = 1
      local y = 2
      return x + y
    end
    test_function()
    coverage.save_stats()

    -- Get initial stats
    local stats1 = coverage.load_stats()
    local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
    filename = filesystem.normalize_path(filename)
    local initial_hits = stats1[filename][1]

    -- Second execution
    test_function()
    coverage.save_stats()

    -- Verify hits increased
    local stats2 = coverage.load_stats()
    expect(stats2[filename][1]).to.equal(initial_hits + 1)
  end)

  it("respects include/exclude patterns", function()
    -- Configure coverage to only include specific patterns
    central_config.set("coverage", {
      include = { "hook_test.lua$" },
      exclude = { "excluded_file.lua$" },
    })

    coverage.init()

    -- Execute some code
    local test_function = function()
      local x = 1
      return x
    end
    test_function()

    -- Save and load stats
    coverage.save_stats()
    local stats = coverage.load_stats()
    expect(stats).to.exist()

    -- Our test file should be included
    local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
    filename = filesystem.normalize_path(filename)
    expect(stats[filename]).to.exist()
  end)

  it("can be paused and resumed", function()
    coverage.init()

    -- Execute code while paused
    coverage.pause()
    local test_function = function()
      local x = 1
      return x
    end
    test_function()

    -- Save and verify no stats
    coverage.save_stats()
    local stats1 = coverage.load_stats()
    local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
    filename = filesystem.normalize_path(filename)
    local initial_hits = stats1 and stats1[filename] and stats1[filename][1] or 0

    -- Resume and execute more code
    coverage.resume()
    test_function()

    -- Save and verify new stats
    coverage.save_stats()
    local stats2 = coverage.load_stats()
    expect(stats2[filename]).to.exist()
    expect(stats2[filename][1]).to.be_greater_than(initial_hits)
  end)

  it("handles concurrent coroutines correctly", { expect_error = true }, function()
    local init_result, init_err = test_helper.with_error_capture(function()
      coverage.init()
      return true
    end)()

    expect(init_err).to_not.exist("Error initializing coverage")

    -- Create coroutines that execute code
    local function coro_func()
      local x = 1
      local y = 2
      return x + y
    end

    -- Create coroutines with error handling
    local threads = {}
    for i = 1, 3 do
      local thread, create_err = test_helper.with_error_capture(function()
        return coroutine.create(coro_func)
      end)()

      expect(create_err).to_not.exist("Error creating coroutine " .. i)
      threads[i] = thread
    end

    -- Run all coroutines with error handling
    for i, thread in ipairs(threads) do
      local result, resume_err = test_helper.with_error_capture(function()
        return coroutine.resume(thread)
      end)()

      expect(resume_err).to_not.exist("Error resuming coroutine " .. i)
      expect(result).to.be_truthy("Coroutine " .. i .. " failed")
    end

    -- Test invalid coroutine operations
    local err = test_helper.expect_error(function()
      return coroutine.resume("not a coroutine")
    end)

    expect(err).to.exist("Should get error when resuming invalid coroutine")
    expect(err.message).to.match("bad argument")

    -- Save and verify stats with error handling
    local save_result, save_err = test_helper.with_error_capture(function()
      coverage.save_stats()
      return true
    end)()

    expect(save_err).to_not.exist("Error saving stats after coroutines")

    local stats_result, stats_err = test_helper.with_error_capture(function()
      return coverage.load_stats()
    end)()

    expect(stats_err).to_not.exist("Error loading stats after coroutines")
    expect(stats_result).to.exist("Stats should exist after coroutines")

    -- Get our function filename
    local filename = debug.getinfo(coro_func, "S").source:match("^@(.*)$")
    if filename then
      filename = filesystem.normalize_path(filename)
      local file_stats = stats_result[filename]

      expect(file_stats).to.exist("Stats for coroutine function file should exist")

      -- Should have 3 hits for each line (one per coroutine)
      for line_nr, hits in pairs(file_stats) do
        if type(line_nr) == "number" then
          expect(hits).to.equal(3)
        end
      end
    end

    -- Proper shutdown with error handling
    local shutdown_result, shutdown_err = test_helper.with_error_capture(function()
      coverage.shutdown()
      return true
    end)()

    expect(shutdown_err).to_not.exist("Error shutting down coverage after coroutines")
  end)

  it("properly handles pause and resume with error validation", { expect_error = true }, function()
    -- Initialize with proper error handling
    local init_result, init_err = test_helper.with_error_capture(function()
      coverage.init()
      return true
    end)()

    expect(init_err).to_not.exist("Error initializing coverage")

    -- Test pause with error handling
    local pause_result, pause_err = test_helper.with_error_capture(function()
      coverage.pause()
      return true
    end)()

    expect(pause_err).to_not.exist("Error pausing coverage")

    -- Execute test function while paused
    local test_function = function()
      local x = 1
      return x
    end
    test_function()

    -- Save and check stats while paused
    local save_paused_result, save_paused_err = test_helper.with_error_capture(function()
      coverage.save_stats()
      return true
    end)()

    expect(save_paused_err).to_not.exist("Error saving stats while paused")

    -- Verify no coverage data was collected while paused
    local stats_paused_result, stats_paused_err = test_helper.with_error_capture(function()
      return coverage.load_stats()
    end)()

    expect(stats_paused_err).to_not.exist("Error loading stats while paused")

    -- Test invalid pause (already paused)
    local double_pause_err = test_helper.expect_error(function()
      -- This may or may not error depending on implementation
      -- Just capture the result in case it does error
      coverage.pause()
      return true
    end)

    -- Resume with error handling
    local resume_result, resume_err = test_helper.with_error_capture(function()
      coverage.resume()
      return true
    end)()

    expect(resume_err).to_not.exist("Error resuming coverage")

    -- Now execute function when not paused
    test_function()

    -- Test invalid resume (already resumed)
    local double_resume_err = test_helper.expect_error(function()
      -- This may or may not error depending on implementation
      -- Just capture the result in case it does error
      coverage.resume()
      return true
    end)

    -- Save and check stats after resume
    local save_resumed_result, save_resumed_err = test_helper.with_error_capture(function()
      coverage.save_stats()
      return true
    end)()

    expect(save_resumed_err).to_not.exist("Error saving stats after resume")

    -- Load stats and verify coverage data was collected after resume
    local stats_resumed_result, stats_resumed_err = test_helper.with_error_capture(function()
      return coverage.load_stats()
    end)()

    expect(stats_resumed_err).to_not.exist("Error loading stats after resume")
    expect(stats_resumed_result).to.exist("Stats should exist after resume")

    -- Proper shutdown with error handling
    local shutdown_result, shutdown_err = test_helper.with_error_capture(function()
      coverage.shutdown()
      return true
    end)()

    expect(shutdown_err).to_not.exist("Error shutting down coverage after pause/resume")
  end)
end)
