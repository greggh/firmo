local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local coverage = require("lib.coverage")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

describe("coverage module", function()
  -- Create a test directory for each test
  local test_dir

  before(function()
    -- Create a test directory
    test_dir = temp_file.create_temp_directory()
    expect(test_dir).to.exist("Failed to create test directory")

    -- Configure coverage to use a file in our test directory
    central_config.set("coverage", {
      enabled = true,
      statsfile = filesystem.join_paths(test_dir, "coverage.stats"),
      include = {".*%.lua$"},
      exclude = {},
      savestepsize = 100,
      tick = false
    })

    -- Ensure coverage is reset
    coverage.shutdown()
  end)

  after(function()
    -- Clean up
    coverage.shutdown()
    if test_dir then
      temp_file.remove_directory(test_dir)
    end
    central_config.reset("coverage")
  end)

  it("initializes the coverage system", function()
    coverage.init()
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
    coverage.init()

    -- Execute code to generate coverage data
    local x = 1
    local y = 2
    local z = x + y

    -- Save stats multiple times to test temp file handling
    for i = 1, 3 do
      coverage.save_stats()
      
      -- Verify stats file exists and is readable
      local statsfile = central_config.get("coverage.statsfile")
      expect(filesystem.file_exists(statsfile)).to.be_truthy()
      
      -- Execute more code
      z = z + i
    end

    -- Load final stats
    local stats = coverage.load_stats()
    expect(stats).to.exist()
  end)

  it("handles corrupted stats files gracefully", function()
    coverage.init()

    -- Execute some code
    local x = 1
    local y = 2

    -- Save initial stats
    coverage.save_stats()

    -- Corrupt the stats file
    local statsfile = central_config.get("coverage.statsfile")
    local ok = filesystem.write_file(statsfile, "corrupted content")
    expect(ok).to.be_truthy()

    -- Try to load corrupted stats
    local stats = coverage.load_stats()
    expect(stats).to.exist() -- Should return empty stats rather than failing
    expect(next(stats)).to_not.exist() -- Should be empty table
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
      include = {"hook_test.lua$"},
      exclude = {"excluded_file.lua$"}
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

  it("handles concurrent coroutines correctly", function()
    coverage.init()

    -- Create coroutines that execute code
    local function coro_func()
      local x = 1
      local y = 2
      return x + y
    end

    local threads = {}
    for i = 1, 3 do
      threads[i] = coroutine.create(coro_func)
    end

    -- Run all coroutines
    for _, thread in ipairs(threads) do
      local success = coroutine.resume(thread)
      expect(success).to.be_truthy()
    end

    -- Save and verify stats
    coverage.save_stats()
    local stats = coverage.load_stats()
    expect(stats).to.exist()

    -- Our function should be tracked
    local filename = debug.getinfo(coro_func, "S").source:match("^@(.*)$")
    filename = filesystem.normalize_path(filename)
    local file_stats = stats[filename]
    expect(file_stats).to.exist()
    -- Should have 3 hits for each line (one per coroutine)
    for line_nr, hits in pairs(file_stats) do
      if type(line_nr) == "number" then
        expect(hits).to.equal(3)
      end
    end
  end)
end)

