-- Test for processing large files with the debug hook-based coverage system
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import modules for testing
local coverage = require("lib.coverage")
local filesystem = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local temp_file = require("lib.tools.temp_file")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("performance_test")

-- Get memory usage in KB
local function get_memory_usage()
  return collectgarbage("count")
end

describe("Large File Performance", function()
  -- Test directory
  local test_dir
  
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
        savestepsize = 1000, -- Larger buffer for performance
      })
      return true
    end)()

    expect(config_err).to_not.exist("Error configuring coverage")

    -- Ensure coverage is reset
    coverage.shutdown()
  end)
  
  after(function()
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
  
  it("should efficiently track coverage for the largest file in the project", function()
    -- Process the largest file in our project: firmo.lua
    local project_root = filesystem.get_absolute_path(".")
    local file_path = filesystem.join_paths(project_root, "firmo.lua")
    
    -- Track memory before coverage
    local start_memory = get_memory_usage()
    
    -- Start coverage
    local init_time_start = os.clock()
    local init_result, init_err = test_helper.with_error_capture(function()
      return coverage.init()
    end)()
    local init_time = os.clock() - init_time_start
    
    expect(init_err).to_not.exist("Error initializing coverage")
    expect(init_result).to.be_truthy()
    
    logger.info("Coverage initialization", { 
      duration_seconds = string.format("%.4f", init_time)
    })
    
    -- Load the target file to track coverage
    local load_time_start = os.clock()
    local loaded_module = dofile(file_path) -- Execute the file to trigger coverage tracking
    local load_time = os.clock() - load_time_start
    
    logger.info("Loaded and tracked large file", { 
      file = file_path,
      duration_seconds = string.format("%.4f", load_time)
    })
    
    -- Track memory after coverage collection
    local post_execution_memory = get_memory_usage()
    
    -- Save stats and measure time
    local save_time_start = os.clock()
    local save_result, save_err = test_helper.with_error_capture(function()
      coverage.save_stats()
      return true
    end)()
    local save_time = os.clock() - save_time_start
    
    expect(save_err).to_not.exist("Error saving coverage stats")
    
    logger.info("Saved coverage stats", { 
      duration_seconds = string.format("%.4f", save_time)
    })
    
    -- Load stats and measure performance
    local load_stats_time_start = os.clock()
    local stats_result, stats_err = test_helper.with_error_capture(function()
      return coverage.load_stats()
    end)()
    local load_stats_time = os.clock() - load_stats_time_start
    
    expect(stats_err).to_not.exist("Error loading coverage stats")
    expect(stats_result).to.exist("Coverage stats should exist")
    
    -- Track final memory usage
    local end_memory = get_memory_usage()
    
    -- Verify coverage data for the target file
    local normalized_path = filesystem.normalize_path(file_path)
    local file_stats = stats_result[normalized_path]
    expect(file_stats).to.exist("Coverage data should exist for target file")
    
    -- Count total lines and covered lines
    local total_lines = 0
    local covered_lines = 0
    
    for line_nr, hits in pairs(file_stats) do
      if type(line_nr) == "number" then
        total_lines = total_lines + 1
        if hits > 0 then
          covered_lines = covered_lines + 1
        end
      end
    end
    
    -- Log comprehensive performance metrics
    logger.info("Coverage performance metrics", { 
      file = file_path,
      total_lines = total_lines,
      covered_lines = covered_lines,
      coverage_percentage = string.format("%.2f%%", (covered_lines / total_lines) * 100),
      init_time_seconds = string.format("%.4f", init_time),
      load_time_seconds = string.format("%.4f", load_time),
      save_time_seconds = string.format("%.4f", save_time),
      load_stats_time_seconds = string.format("%.4f", load_stats_time),
      memory_before_kb = string.format("%.2f", start_memory),
      memory_after_execution_kb = string.format("%.2f", post_execution_memory),
      memory_final_kb = string.format("%.2f", end_memory),
      memory_increase_kb = string.format("%.2f", end_memory - start_memory)
    })
    
    -- Verify general performance expectations
    expect(load_time).to.be_less_than(5, "Loading large file should be reasonably fast")
    expect(save_time).to.be_less_than(1, "Saving stats should be fast")
    expect(end_memory - start_memory).to.be_less_than(start_memory * 2, "Memory usage should not more than double")
  end)
  
  it("should handle multiple coverage operations efficiently", function()
    -- Initialize coverage with proper error handling
    local init_result, init_err = test_helper.with_error_capture(function()
      return coverage.init()
    end)()
    
    expect(init_err).to_not.exist("Error initializing coverage")
    expect(init_result).to.be_truthy("Coverage initialization should succeed")
    
    -- Create a test function that we'll execute many times
    local function test_function()
      local sum = 0
      for i = 1, 1000 do
        sum = sum + i
      end
      return sum
    end
    
    -- Get function info for later coverage verification
    local function_info = debug.getinfo(test_function, "S")
    local function_file = function_info.source:match("^@(.*)$")
    local function_line = function_info.linedefined
    
    -- Ensure function file is normalized for proper lookup
    function_file = filesystem.normalize_path(function_file)
    
    logger.info("Test function details", {
      function_file = function_file,
      function_line = function_line
    })
    
    -- Ensure coverage is running (not paused)
    coverage.resume()
    
    -- Test performance with many executions
    local iterations = 100
    local start_time = os.clock()
    
    for i = 1, iterations do
      test_function()
    end
    
    local execution_time = os.clock() - start_time
    
    -- Save stats with proper error handling
    local save_time_start = os.clock()
    local save_result, save_err = test_helper.with_error_capture(function()
      coverage.save_stats()
      return true
    end)()
    local save_time = os.clock() - save_time_start
    
    expect(save_err).to_not.exist("Error saving coverage stats")
    expect(save_result).to.be_truthy("Saving coverage stats should succeed")
    
    -- Log performance data
    logger.info("Multiple executions performance", { 
      iterations = iterations,
      execution_time_seconds = string.format("%.4f", execution_time),
      time_per_iteration_ms = string.format("%.4f", (execution_time / iterations) * 1000),
      save_time_seconds = string.format("%.4f", save_time)
    })
    
    -- Load stats with proper error handling
    local stats_result, stats_err = test_helper.with_error_capture(function()
      return coverage.load_stats()
    end)()
    
    expect(stats_err).to_not.exist("Error loading coverage stats")
    expect(stats_result).to.exist("Coverage stats should exist")
    
    -- Get test file stats
    local this_file = debug.getinfo(1, "S").source:match("^@(.*)$")
    this_file = filesystem.normalize_path(this_file)
    local this_file_stats = stats_result[this_file]
    
    -- Log all collected stats files for debugging
    local stats_files = {}
    for filename, _ in pairs(stats_result) do
      table.insert(stats_files, filename)
    end
    
    logger.info("Coverage stats files", {
      files_count = #stats_files,
      files = stats_files
    })
    
    -- Check if our file was tracked
    expect(this_file_stats).to.exist("Coverage data should exist for test file")
    
    -- Find lines with coverage hits in the entire file
    local lines_with_hits = {}
    local max_hits = 0
    local max_hits_line = 0
    
    for line, hits in pairs(this_file_stats) do
      if type(line) == "number" and hits > 0 then
        lines_with_hits[line] = hits
        if hits > max_hits then
          max_hits = hits
          max_hits_line = line
        end
      end
    end
    
    logger.info("Function execution verification", {
      function_file = function_file,
      function_line = function_line,
      covered_lines_count = #lines_with_hits,
      max_hits = max_hits,
      max_hits_line = max_hits_line,
      test_function_hits = this_file_stats[function_line] or 0
    })
    
    -- Check if we have coverage data for this file
    expect(next(lines_with_hits)).to.exist("Should have some lines with coverage hits")
    
    -- Verify that the file shows some coverage
    expect(max_hits).to.be_greater_than(0, "Some line should have been covered")
  end)
end)
