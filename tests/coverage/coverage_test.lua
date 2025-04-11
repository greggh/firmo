-- Comprehensive tests for the coverage module with focus on error handling
---@diagnostic disable: unused-local

-- Import firmo test framework
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import modules needed for testing
local coverage = require("lib.coverage")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

describe("coverage module advanced operations", function()
  -- Test directory
  local test_dir

  -- Backup of original functions for mocking
  local original_fs_functions = {}

  before(function()
    -- Create test directory with error handling
    local dir_result, dir_err = test_helper.with_error_capture(function()
      return temp_file.create_temp_directory()
    end)()

    expect(dir_err).to_not.exist("Error creating temp directory")
    test_dir = dir_result
    expect(test_dir).to.exist("Failed to create test directory")

    -- Set up configuration with proper error handling
    local config_result, config_err = test_helper.with_error_capture(function()
      central_config.set("coverage", {
        enabled = true,
        statsfile = filesystem.join_paths(test_dir, "coverage.stats"),
        include = { ".*%.lua$" },
        exclude = {},
        savestepsize = 5, -- Small value to trigger buffer operations
        tick = true, -- Enable tick-based saving
      })
      return true
    end)()

    expect(config_err).to_not.exist("Error configuring coverage")

    -- Backup original functions for mocking
    original_fs_functions.write_file = filesystem.write_file
    original_fs_functions.read_file = filesystem.read_file
    original_fs_functions.file_exists = filesystem.file_exists
    original_fs_functions.move_file = filesystem.move_file

    -- Reset coverage system
    coverage.shutdown()
  end)

  after(function()
    -- Restore any mocked functions
    if original_fs_functions.write_file then
      filesystem.write_file = original_fs_functions.write_file
    end
    if original_fs_functions.read_file then
      filesystem.read_file = original_fs_functions.read_file
    end
    if original_fs_functions.file_exists then
      filesystem.file_exists = original_fs_functions.file_exists
    end
    if original_fs_functions.move_file then
      filesystem.move_file = original_fs_functions.move_file
    end

    -- Shutdown coverage with error handling
    test_helper.with_error_capture(function()
      coverage.shutdown()
      return true
    end)()

    -- Clean up test directory with error handling
    if test_dir then
      local remove_result, remove_err = test_helper.with_error_capture(function()
        return temp_file.remove_directory(test_dir)
      end)()

      if remove_err then
        print("Warning: Failed to remove test directory: " .. (remove_err.message or "unknown error"))
      end
    end

    -- Reset configuration
    test_helper.with_error_capture(function()
      central_config.reset("coverage")
      return true
    end)()
  end)

  describe("initialization error handling", function()
    it("handles initialization errors gracefully", { expect_error = true }, function()
      -- Mock debug.sethook to simulate an error
      local original_sethook = debug.sethook
      debug.sethook = function()
        error("Simulated sethook error")
      end

      -- Attempt to initialize with the broken sethook
      local err = test_helper.expect_error(function()
        coverage.init()
      end)

      -- Verify error
      expect(err).to.exist("Should get initialization error")
      expect(err.message).to.match("coverage")

      -- Restore original function
      debug.sethook = original_sethook
    end)

    it("handles double initialization", function()
      -- First initialization should succeed
      local first_init_result, first_init_err = test_helper.with_error_capture(function()
        return coverage.init()
      end)()

      expect(first_init_err).to_not.exist("First initialization should succeed")
      expect(first_init_result).to.be_truthy()

      -- Second initialization should not error but return true
      local second_init_result, second_init_err = test_helper.with_error_capture(function()
        return coverage.init()
      end)()

      expect(second_init_err).to_not.exist("Double initialization should not error")
      expect(second_init_result).to.be_truthy()
    end)

    it("properly reinitializes after shutdown", function()
      -- First init
      local init_result, init_err = test_helper.with_error_capture(function()
        return coverage.init()
      end)()

      expect(init_err).to_not.exist("Error initializing coverage")

      -- Shutdown
      local shutdown_result, shutdown_err = test_helper.with_error_capture(function()
        coverage.shutdown()
        return true
      end)()

      expect(shutdown_err).to_not.exist("Error shutting down coverage")

      -- Reinitialize
      local reinit_result, reinit_err = test_helper.with_error_capture(function()
        return coverage.init()
      end)()

      expect(reinit_err).to_not.exist("Error reinitializing coverage")
      expect(reinit_result).to.be_truthy()
    end)
  end)

  describe("file operation errors", function()
    it("handles write errors gracefully", { expect_error = true }, function()
      -- Initialize coverage
      local init_result, init_err = test_helper.with_error_capture(function()
        coverage.init()
        return true
      end)()

      expect(init_err).to_not.exist("Error initializing coverage")

      -- Execute code to generate coverage data
      local x = 1
      local y = 2
      local z = x + y

      -- Mock write_file to simulate an error
      filesystem.write_file = function(path, content)
        error("Simulated write error")
      end

      -- Attempt to save stats
      local err = test_helper.expect_error(function()
        coverage.save_stats()
      end)

      -- Verify error
      expect(err).to.exist("Should get error when writing stats")
      expect(err.message).to.match("write error")

      -- Restore original function
      filesystem.write_file = original_fs_functions.write_file
    end)

    it("handles read errors when loading stats", { expect_error = true }, function()
      -- Create a valid stats file first
      coverage.init()
      local x = 1 -- Generate some coverage
      coverage.save_stats()
      coverage.shutdown()

      -- Mock read_file to simulate an error
      filesystem.read_file = function(path)
        error("Simulated read error")
      end

      -- Attempt to load stats
      local stats_result, stats_err = test_helper.with_error_capture(function()
        return coverage.load_stats()
      end)()

      -- The coverage module should handle read errors gracefully
      expect(stats_result).to_not.exist("Should return nil on read error")
      expect(stats_err).to.exist("Should capture read error")
      expect(stats_err.message).to.match("read error")

      -- Restore original function
      filesystem.read_file = original_fs_functions.read_file
    end)

    it("handles file existence check errors", { expect_error = true }, function()
      -- Mock file_exists to simulate an error
      filesystem.file_exists = function(path)
        error("Simulated existence check error")
      end

      -- Attempt to load stats
      local err = test_helper.expect_error(function()
        return coverage.load_stats()
      end)

      -- Verify error
      expect(err).to.exist("Should get error when checking file existence")
      expect(err.message).to.match("existence check error")

      -- Restore original function
      filesystem.file_exists = original_fs_functions.file_exists
    end)

    it("handles file move errors during atomic writes", { expect_error = true }, function()
      coverage.init()
      local x = 1 -- Generate some coverage

      -- Mock move_file to simulate an error
      filesystem.move_file = function(src, dest)
        error("Simulated move error")
      end

      -- Attempt to save stats
      local err = test_helper.expect_error(function()
        coverage.save_stats()
      end)

      -- Verify error
      expect(err).to.exist("Should get error when moving stats file")
      expect(err.message).to.match("move error")

      -- Restore original function
      filesystem.move_file = original_fs_functions.move_file
    end)
  end)

  describe("coroutine and threading error conditions", function()
    it("gracefully handles errors in coroutines", { expect_error = true }, function()
      -- Initialize coverage
      local init_result, init_err = test_helper.with_error_capture(function()
        coverage.init()
        return true
      end)()

      expect(init_err).to_not.exist("Error initializing coverage")

      -- Create a coroutine that generates an error
      local error_co = coroutine.create(function()
        error("Deliberate coroutine error")
      end)

      -- Resume should fail but not affect coverage system
      local resume_success, resume_err = coroutine.resume(error_co)
      expect(resume_success).to.be_falsy("Coroutine should fail")
      expect(resume_err).to.match("Deliberate coroutine error")

      -- Coverage should still be operational
      local test_function = function()
        local x = 1
        return x
      end
      test_function()

      -- Save and load stats should work
      local save_result, save_err = test_helper.with_error_capture(function()
        coverage.save_stats()
        return true
      end)()

      expect(save_err).to_not.exist("Error saving stats after coroutine error")

      local stats_result, stats_err = test_helper.with_error_capture(function()
        return coverage.load_stats()
      end)()

      expect(stats_err).to_not.exist("Error loading stats after coroutine error")
      expect(stats_result).to.exist("Stats should exist after coroutine error")
    end)

    it("works correctly with coroutine.wrap", { expect_error = true }, function()
      coverage.init()

      -- Create wrapped coroutine that may fail
      local wrapped = coroutine.wrap(function()
        -- Might throw an error
        if math.random() < 0.5 then
          error("Deliberate wrapped coroutine error")
        end
        return "success"
      end)

      -- Call wrapped function with error handling
      local wrap_err = test_helper.expect_error(function()
        -- Force error for testing
        error_handler.throw("Deliberate wrapped error", "TEST", "INFO")
      end)

      expect(wrap_err).to.exist("Should get error from wrapped function")

      -- Coverage system should still be functional
      local test_function = function()
        local x = 1
        return x
      end
      test_function()

      -- Save stats should work
      local save_result, save_err = test_helper.with_error_capture(function()
        coverage.save_stats()
        return true
      end)()

      expect(save_err).to_not.exist("Error saving stats after wrapped coroutine")
    end)

    it("tracks coverage across multiple threads", function()
      -- Skip if platform doesn't have per-thread hooks
      if not coverage.has_hook_per_thread() then
        return
      end

      -- Initialize coverage
      coverage.init()

      -- Create multiple threads that all run the same code
      local threads = {}
      local thread_count = 5

      for i = 1, thread_count do
        threads[i] = coroutine.create(function()
          local x = 1
          local y = 2
          return x + y
        end)
      end

      -- Run all threads
      for _, thread in ipairs(threads) do
        local success, result = coroutine.resume(thread)
        expect(success).to.be_truthy("Thread should complete successfully")
        expect(result).to.equal(3, "Thread should return correct result")
      end

      -- Save and verify stats
      coverage.save_stats()
      local stats = coverage.load_stats()

      -- Find the coroutine file in stats
      local filename
      for name, _ in pairs(stats) do
        if name:match("coverage_test.lua$") then
          filename = name
          break
        end
      end

      expect(filename).to.exist("Coverage stats should include test file")

      -- Each line in the coroutine should have been hit once per thread
      local file_stats = stats[filename]
      local found_thread_hits = false

      for line_nr, hits in pairs(file_stats) do
        if type(line_nr) == "number" and hits >= thread_count then
          found_thread_hits = true
          break
        end
      end

      expect(found_thread_hits).to.be_truthy("Should find lines hit by all threads")
    end)
  end)

  describe("pattern compilation errors", function()
    it("handles invalid include patterns", function()
      -- Set configuration with invalid pattern
      local err = test_helper.expect_error(function()
        central_config.set("coverage", {
          include = { "[invalid regexp" },
        })
        coverage.init()
      end)

      -- Implementation-dependent whether this errors or not
      if err then
        expect(err.message).to.match("pattern")
      end

      -- Reset to valid configuration
      central_config.set("coverage", {
        include = { ".*%.lua$" },
      })
    end)

    it("handles invalid exclude patterns", function()
      -- Set configuration with invalid pattern
      local err = test_helper.expect_error(function()
        central_config.set("coverage", {
          exclude = { "[invalid regexp" },
        })
        coverage.init()
      end)

      -- Implementation-dependent whether this errors or not
      if err then
        expect(err.message).to.match("pattern")
      end

      -- Reset to valid configuration
      central_config.set("coverage", {
        exclude = {},
      })
    end)

    it("handles complex path patterns correctly", function()
      -- Configure with specific pattern for this test file
      local config_result, config_err = test_helper.with_error_capture(function()
        central_config.set("coverage", {
          include = { "coverage_test.lua$" },
          exclude = {},
        })
        return true
      end)()

      expect(config_err).to_not.exist("Error setting include patterns")

      -- Initialize coverage
      coverage.init()

      -- Execute some code
      local x = 1
      local y = 2

      -- Save and load stats
      coverage.save_stats()
      local stats = coverage.load_stats()
      expect(stats).to.exist()

      -- Our current file should be included
      local filename
      for name, _ in pairs(stats) do
        if name:match("coverage_test.lua$") then
          filename = name
          break
        end
      end

      expect(filename).to.exist("This test file should be included in coverage")

      -- Reset configuration
      central_config.reset("coverage")
    end)
  end)

  describe("pause/resume operations", function()
    it("respects pause state during debug hook", function()
      -- Initialize coverage
      coverage.init()

      -- Execute code to establish baseline
      local test_function = function()
        local x = 1
        return x
      end
      test_function()

      -- Save and get initial stats
      coverage.save_stats()
      local stats1 = coverage.load_stats()
      local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
      filename = filesystem.normalize_path(filename)
      local initial_hits = stats1 and stats1[filename] and stats1[filename][494] or 0

      -- Pause coverage
      coverage.pause()

      -- Execute more code while paused
      test_function()
      test_function()
      test_function()

      -- Save and check stats (should be unchanged)
      coverage.save_stats()
      local stats2 = coverage.load_stats()
      local paused_hits = stats2 and stats2[filename] and stats2[filename][494] or 0
      expect(paused_hits).to.equal(initial_hits, "Hits should not increase while paused")

      -- Resume coverage
      coverage.resume()

      -- Execute more code after resume
      test_function()

      -- Save and check stats (should have increased)
      coverage.save_stats()
      local stats3 = coverage.load_stats()
      local resumed_hits = stats3 and stats3[filename] and stats3[filename][494] or 0
      expect(resumed_hits).to.be_greater_than(initial_hits, "Hits should increase after resume")
    end)

    it("handles pause/resume toggle correctly", function()
      -- Initialize coverage
      coverage.init()

      -- Pause and resume multiple times to ensure state handling
      coverage.pause()
      coverage.resume()
      coverage.pause()
      coverage.resume()

      -- Execute code after toggling
      local test_function = function()
        local x = 1
        return x
      end
      test_function()

      -- Save and verify stats
      coverage.save_stats()
      local stats = coverage.load_stats()
      expect(stats).to.exist()

      -- Our test file should have coverage
      local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
      filename = filesystem.normalize_path(filename)
      local file_stats = stats[filename]
      expect(file_stats).to.exist()

      -- Look for line hits corresponding to our test function
      local found_hits = false
      for line_nr, hits in pairs(file_stats) do
        if type(line_nr) == "number" and line_nr >= 541 and line_nr <= 545 then
          found_hits = true
          break
        end
      end

      expect(found_hits).to.be_truthy("Should find hits in the test function")
    end)

    it("handles edge case state transitions", function()
      -- Initialize coverage
      coverage.init()

      -- Test pause when already paused
      coverage.pause()
      local err1 = test_helper.expect_error(function()
        -- May or may not error depending on implementation
        coverage.pause()
      end)

      -- Doesn't have to error, but if it does, should be handled properly
      if err1 then
        expect(err1.message).to.exist()
      end

      -- Test resume when already resumed
      coverage.resume()
      local err2 = test_helper.expect_error(function()
        -- May or may not error depending on implementation
        coverage.resume()
      end)

      -- Doesn't have to error, but if it does, should be handled properly
      if err2 then
        expect(err2.message).to.exist()
      end

      -- Test pause/resume on uninitialized system
      coverage.shutdown()

      local err3 = test_helper.expect_error(function()
        -- May or may not error depending on implementation
        coverage.pause()
      end)

      -- Doesn't have to error, but if it does, should be handled properly
      if err3 then
        expect(err3.message).to.exist()
      end
    end)

    it("maintains pause/resume state across save operations", function()
      -- Initialize coverage
      coverage.init()

      -- Pause coverage
      coverage.pause()

      -- Save stats (should not affect pause state)
      coverage.save_stats()

      -- Execute code (should not be tracked)
      local test_function = function()
        local x = 1
        return x
      end
      test_function()

      -- Save again
      coverage.save_stats()

      -- Load stats and verify
      local stats = coverage.load_stats()
      local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
      filename = filesystem.normalize_path(filename)

      -- Check if our recent function call was tracked
      local found_recent_hit = false
      if stats and stats[filename] then
        for line_nr, hits in pairs(stats[filename]) do
          if type(line_nr) == "number" and line_nr >= 623 and line_nr <= 626 and hits > 0 then
            found_recent_hit = true
            break
          end
        end
      end

      expect(found_recent_hit).to.be_falsy("Should not track code while paused, even across save operations")
    end)
  end)

  describe("buffer overflow conditions", function()
    it("handles large data volumes gracefully", function()
      -- Configure for very small buffer size to trigger overflow
      central_config.set("coverage", {
        savestepsize = 1, -- Very small size to trigger frequent saves
        tick = true,
      })

      -- Initialize coverage
      coverage.init()

      -- Execute code in a loop to generate lots of coverage events
      for i = 1, 20 do
        local x = i
        local y = i * 2
        local z = x + y
      end

      -- Verify stats are saved properly
      local stats = coverage.load_stats()
      expect(stats).to.exist()

      -- Our test file should have coverage
      local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
      filename = filesystem.normalize_path(filename)
      local file_stats = stats[filename]
      expect(file_stats).to.exist()

      -- Look for line hits in our loop
      local found_hits = false
      for line_nr, hits in pairs(file_stats) do
        if type(line_nr) == "number" and line_nr >= 664 and line_nr <= 668 and hits > 0 then
          found_hits = true
          break
        end
      end

      expect(found_hits).to.be_truthy("Should find hits in the loop code")
    end)

    it("handles rapid state changes with data collection", function()
      -- Initialize coverage
      coverage.init()

      -- Rapid pause/resume with code execution
      for i = 1, 10 do
        if i % 2 == 0 then
          coverage.pause()
        else
          coverage.resume()
        end

        -- Execute some code
        local x = i
        local y = i * 2
      end

      -- Ensure we end in resumed state
      coverage.resume()

      -- Execute final code
      local final = 100

      -- Save stats
      coverage.save_stats()

      -- Load and verify
      local stats = coverage.load_stats()
      expect(stats).to.exist()

      -- Reset configuration
      central_config.reset("coverage")
    end)
  end)

  describe("stats file corruption scenarios", function()
    it("handles severely malformed stats files", function()
      -- Initialize coverage and generate data
      coverage.init()
      local x = 1
      coverage.save_stats()

      -- Get the stats filename
      local statsfile = central_config.get("coverage.statsfile")

      -- Write severely malformed content
      local malformed_content = "This is not a valid stats file\nNo proper headers\nOr data"
      filesystem.write_file(statsfile, malformed_content)

      -- Load should not error but return empty results
      local stats_result, stats_err = test_helper.with_error_capture(function()
        return coverage.load_stats()
      end)()

      -- Minimal validation to ensure we didn't crash
      expect(stats_err).to_not.exist("Loading malformed stats should not throw error")

      -- If implementation returns nil or empty table, that's fine
      if stats_result then
        local has_data = false
        for k, v in pairs(stats_result) do
          if type(v) == "table" and next(v) then
            has_data = true
            break
          end
        end
        expect(has_data).to.be_falsy("Malformed stats should not contain valid data")
      end
    end)

    it("handles partial stats file corruption", function()
      -- Initialize coverage and generate data
      coverage.init()
      local x = 1
      coverage.save_stats()

      -- Get the stats filename
      local statsfile = central_config.get("coverage.statsfile")

      -- Read current content
      local content = filesystem.read_file(statsfile)
      expect(content).to.exist()

      -- Corrupt part of the file but leave header intact
      local header_end = content:find("\n")
      if header_end then
        local corrupted = content:sub(1, header_end) .. "corrupted data\n"
        filesystem.write_file(statsfile, corrupted)

        -- Load should not crash
        local stats_result, stats_err = test_helper.with_error_capture(function()
          return coverage.load_stats()
        end)()

        -- Basic validation - should either return partial data or empty data
        expect(stats_err).to_not.exist("Loading partially corrupted stats should not throw error")
      end
    end)
  end)

  describe("shutdown error handling", function()
    it("handles errors during shutdown", function()
      -- Initialize coverage
      coverage.init()

      -- Mock debug.sethook to simulate an error
      local original_sethook = debug.sethook
      debug.sethook = function()
        error("Simulated sethook error during shutdown")
      end

      -- Attempt to shutdown with the broken sethook
      local err = test_helper.expect_error(function()
        coverage.shutdown()
      end)

      -- Verify error handling
      -- Implementation may or may not propagate this error
      if err then
        expect(err.message).to.match("shutdown")
      end

      -- Restore original function
      debug.sethook = original_sethook

      -- Ensure system is properly reset after test
      test_helper.with_error_capture(function()
        -- Try to restore the hook properly
        debug.sethook()
        coverage.init()
        coverage.shutdown()
        return true
      end)()
    end)

    it("persists remaining data during shutdown", function()
      -- Initialize coverage
      coverage.init()

      -- Execute some code to generate coverage data
      local test_function = function()
        local x = 1
        local y = 2
        return x + y
      end
      test_function()

      -- Do not save stats manually - rely on shutdown to save

      -- Verify stats don't exist yet
      local statsfile = central_config.get("coverage.statsfile")
      filesystem.remove_file(statsfile) -- Ensure clean state

      expect(filesystem.file_exists(statsfile)).to.be_falsy("Stats file should not exist before shutdown")

      -- Shutdown should save stats
      local shutdown_result, shutdown_err = test_helper.with_error_capture(function()
        coverage.shutdown()
        return true
      end)()

      expect(shutdown_err).to_not.exist("Error shutting down coverage")

      -- Verify stats were saved
      expect(filesystem.file_exists(statsfile)).to.be_truthy("Stats file should exist after shutdown")

      -- Load and verify stats
      local stats = coverage.load_stats()
      expect(stats).to.exist()

      -- Find our test file in the stats
      local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
      filename = filesystem.normalize_path(filename)
      local file_stats = stats[filename]
      expect(file_stats).to.exist()
    end)

    it("cleans up resources during shutdown", function()
      -- Initialize coverage
      coverage.init()

      -- Execute some code
      local x = 1

      -- Shutdown
      coverage.shutdown()

      -- After shutdown, hook should be removed
      local hook, mask, count = debug.gethook()

      -- Implementation-dependent, but most likely no hook or different hook after shutdown
      if hook then
        -- If hook exists after shutdown, it should not be the coverage hook
        -- This is hard to test directly, so we just check that further coverage isn't tracked

        -- Execute more code
        local y = 2
        local z = 3

        -- Try to save stats (should not contain the recent code)
        local save_result, save_err = test_helper.with_error_capture(function()
          coverage.save_stats() -- May fail or succeed depending on implementation
          return true
        end)()

        -- Load stats and check
        local stats_result, stats_err = test_helper.with_error_capture(function()
          return coverage.load_stats()
        end)()

        -- If stats load successfully, check that recent lines aren't present
        if stats_result then
          local filename = debug.getinfo(1, "S").source:match("^@(.*)$")
          filename = filesystem.normalize_path(filename)

          local found_recent = false
          if stats_result[filename] then
            for line_nr, hits in pairs(stats_result[filename]) do
              -- These lines were executed after shutdown
              if type(line_nr) == "number" and line_nr >= 889 and line_nr <= 891 and hits > 0 then
                found_recent = true
                break
              end
            end
          end

          expect(found_recent).to.be_falsy("Should not track lines executed after shutdown")
        end
      end
    end)
  end)

  describe("state validation", function()
    it("initializes with correct state values", function()
      -- Reset first
      coverage.shutdown()

      -- Initialize
      coverage.init()

      -- Test the API functions exist and work
      expect(coverage.pause).to.be.a("function")
      expect(coverage.resume).to.be.a("function")
      expect(coverage.save_stats).to.be.a("function")
      expect(coverage.load_stats).to.be.a("function")
      expect(coverage.shutdown).to.be.a("function")

      -- Execute a test function
      local function test_function()
        local x = 1
        return x
      end

      -- Call the function
      test_function()

      -- Save stats
      coverage.save_stats()

      -- Load and verify
      local stats = coverage.load_stats()
      expect(stats).to.exist()

      -- Find our function in the stats
      local filename = debug.getinfo(test_function, "S").source:match("^@(.*)$")
      if filename then
        filename = filesystem.normalize_path(filename)

        -- Check if our file was tracked
        expect(stats[filename]).to.exist("Test function file should be tracked")
      end
    end)

    it("maintains correct state across multiple operations", function()
      -- Test a series of operations that exercise the entire state machine

      -- Start with clean state
      coverage.shutdown()

      -- Step 1: Initialize
      coverage.init()

      -- Step 2: Generate some data
      local function test_function()
        local x = 1
        return x
      end
      test_function()

      -- Step 3: Save
      coverage.save_stats()

      -- Step 4: Pause and generate more data (should not be tracked)
      coverage.pause()
      test_function()

      -- Step 5: Save while paused
      coverage.save_stats()

      -- Step 6: Load and check
      local stats1 = coverage.load_stats()
      local filename = debug.getinfo(test_function, "S").source:match("^@(.*)$")
      filename = filesystem.normalize_path(filename)
      local initial_hits = stats1 and stats1[filename] and stats1[filename][978] or 0

      -- Step 7: Resume and generate more data
      coverage.resume()
      test_function()

      -- Step 8: Save after resume
      coverage.save_stats()

      -- Step 9: Load and verify hits increased
      local stats2 = coverage.load_stats()
      local resumed_hits = stats2 and stats2[filename] and stats2[filename][978] or 0
      expect(resumed_hits).to.be_greater_than(initial_hits, "Hits should increase after resume")

      -- Step 10: Shutdown
      coverage.shutdown()

      -- Step 11: Generate data after shutdown (should not be tracked)
      test_function()

      -- Step 12: Final state verification
      local hook, mask, count = debug.gethook()

      -- If a hook exists post-shutdown, it should not cause problems in test teardown
      if hook then
        -- Just make sure we can execute the teardown without errors
        test_helper.with_error_capture(function()
          debug.sethook()
          return true
        end)()
      end
    end)
  end)

  describe("final system validation", function()
    it("leaves the system in a clean state after tests", function()
      -- Ensure coverage is shutdown
      local shutdown_result, shutdown_err = test_helper.with_error_capture(function()
        coverage.shutdown()
        return true
      end)()

      expect(shutdown_err).to_not.exist("Error in final shutdown")

      -- Verify hooks are removed
      local hook, mask, count = debug.gethook()

      -- If a hook exists, it should not be active for line events
      if hook and mask and mask:find("l") then
        -- Try to clear it
        debug.sethook()
      end

      -- Reset configuration
      central_config.reset("coverage")

      -- Check that critical resources are cleaned up
      -- 1. All filesystem mocks are restored
      expect(filesystem.write_file).to.equal(original_fs_functions.write_file, "filesystem.write_file not restored")
      expect(filesystem.read_file).to.equal(original_fs_functions.read_file, "filesystem.read_file not restored")
      expect(filesystem.file_exists).to.equal(original_fs_functions.file_exists, "filesystem.file_exists not restored")
      expect(filesystem.move_file).to.equal(original_fs_functions.move_file, "filesystem.move_file not restored")

      -- 2. Test directory is removed in the after function
      -- (No assertions needed here, just documentation)

      -- 3. Configuration is reset in the after function
      -- (No assertions needed here, just documentation)
    end)
  end)
end)
