--- This procedural example script demonstrates parallel test execution using
--- `firmo.parallel.run_tests`. It works by:
-- 1. Creating several temporary test files, each with simulated delays.
-- 2. Running these test files sequentially using `dofile` (for baseline timing).
-- 3. Running the same test files in parallel using `firmo.parallel.run_tests`.
-- 4. Comparing the execution times to show the potential speedup.
--
-- @module examples.parallel_execution_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see lib.tools.parallel
-- @usage
-- Run this example directly: lua examples/parallel_execution_example.lua
--

local firmo = require("firmo")
local logging = require("lib.tools.logging")
local temp_file = require("lib.tools.filesystem.temp_file")
local fs = require("lib.tools.filesystem") -- Needed for join_paths

-- Setup logger
local logger = logging.get_logger("ParallelExecExample")

-- Load the parallel module and register it with firmo
local parallel_loaded, parallel = pcall(require, "lib.tools.parallel")
if not parallel_loaded then
  logger.warn("Could not load parallel module. Parallel demo will not run.")
else
  -- Assuming registration happens via adding to firmo table or similar mechanism
  -- Check if parallel is now available on the firmo object after require
  if firmo.parallel and firmo.parallel.run_tests then
    logger.info("Parallel module loaded and integrated with firmo.")
  else
    logger.warn("Parallel module loaded but not integrated correctly with firmo object.")
    parallel_loaded = false -- Treat as not available if integration failed
  end
end

logger.info("firmo Parallel Test Execution Example")
logger.info("------------------------------------------")

-- Create a simple test to demonstrate parallel execution (used by runner if run that way)
--- Basic test suite included for context, primarily used if run via `test.lua`.
firmo.describe("Parallel Test Execution Demo", function()
  firmo.it("can run tests in parallel", function()
    firmo.expect(1 + 1).to.equal(2)
  end)

  firmo.it("can also run this test", function()
    firmo.expect("test").to.be.a("string")
  end)

  firmo.it("demonstrates a longer-running test", function()
    -- Simulate a test that takes some time
    --- Busy-wait sleep for simulation ONLY. Do not use in real code.
    local function sleep(sec)
      local start = os.clock()
      while os.clock() - start < sec do
      end
    end

    sleep(0.1) -- Sleep for 100ms
    firmo.expect(true).to.be.truthy()
  end)
end)

-- If running this file directly, print usage instructions
if arg[0]:match("parallel_execution_example%.lua$") then
  -- Run a small demo to showcase parallel execution
  logger.info("\nDemonstrating parallel test execution...")
  logger.info("----------------------------------------")

  --- Creates multiple temporary test files with simulated delays.
  --- Creates multiple temporary test files, each containing simple tests with simulated delays.
  --- Registers created files with `temp_file` for cleanup implicitly via directory registration.
  --- @param temp_dir_path string The path to the temporary directory where files should be created.
  --- @param count number The number of test files to create.
  --- @return string[] files A list of absolute paths to the created test files.
  --- @within examples.parallel_execution_example
  local function create_test_files(temp_dir_obj, count)
    -- Create a few test files
    local files = {}
    for i = 1, count do
      local filename = "test_" .. i .. ".lua"
      local file_path = fs.join_paths(temp_dir_obj.path, filename) -- Used for potential dofile reference if needed
      local delay = math.random() * 0.3 -- Random delay between 0-300ms

      -- Build file content
      local content = "-- Generated test file #" .. i .. "\n"
      content = content .. "local firmo = require('firmo')\n"
      content = content .. "local describe, it, expect = firmo.describe, firmo.it, firmo.expect\n\n"
      -- Removed duplicate require
      content = content .. "-- Simulate work by sleeping\n"
      content = content .. "--- Busy-wait sleep for simulation ONLY.\n"
      content = content .. "local function sleep(sec)\n"
      content = content .. "  local start = os.clock()\n"
      content = content .. "  while os.clock() - start < sec do end\n"
      content = content .. "end\n\n"
      content = content .. "describe('Test File " .. i .. "', function()\n"
      -- Create a few test cases in each file
      for j = 1, 3 do
        content = content .. "  it('test case " .. j .. "', function()\n"
        content = content .. "    sleep(" .. string.format("%.3f", delay) .. ") -- Sleep to simulate work\n"
        content = content .. "    expect(1 + " .. j .. ").to.equal(" .. (1 + j) .. ")\n"
        content = content .. "  end)\n"
      end

      content = content .. "end)\n"

      -- Write the file using fs.write_file
      local abs_path = fs.join_paths(temp_dir_path, filename) -- Define abs path first
      local success, err = fs.write_file(abs_path, content)
      if success then
        table.insert(files, abs_path) -- Store absolute path
      else
        print("Error writing test file: " .. (err or "unknown error")) -- Use print for consistency
      end
    end

    return files
  end

  -- Create 10 test files in a temporary directory
  local temp_dir, err = temp_file.create_temp_directory("parallel_example_")
  if not temp_dir then
    logger.error("Failed to create temporary directory for parallel demo: " .. tostring(err))
    return -- Cannot proceed without temp dir
  end

  local files = create_test_files(temp_dir, 10)

  -- Report what we created
  logger.info("Created " .. #files .. " test files in " .. temp_dir)

  -- Basic sequential execution demo (SIMULATED - dofile doesn't run tests properly)
  logger.info("\n== Simulating sequential execution (for timing comparison) ==")
  local start_time = os.clock()
  local total_delay = 0
  for i = 1, #files do
    -- Estimate delay based on file content (fragile, just for demo)
    local content = fs.read_file(files[i])
    local delay_str = content:match("sleep%(([%d%.]+)%)")
    local delay = tonumber(delay_str) or 0
    total_delay = total_delay + (delay * 3) -- 3 tests per file
  end
  local sequential_time = total_delay -- Approximate total time
  print("Estimated sequential execution time: " .. string.format("%.3f", sequential_time) .. " seconds")

  -- Parallel execution demo
  if firmo.parallel and parallel_loaded then
    logger.info("\n== Running tests in parallel ==")
    local parallel_start = os.clock()

    -- Use the absolute paths returned by create_test_files

    -- Run tests in parallel
    -- NOTE: Verify API signature.
    -- Ensure the function exists before calling
    if not firmo.parallel or not firmo.parallel.run_tests then
      error("firmo.parallel.run_tests function not found after require.")
    end
    local results = firmo.parallel.run_tests(files, {
      workers = 4, -- Use 4 worker processes
      show_worker_output = true, -- Show individual worker output for the demo
      verbose = true, -- Display verbose output for the demo
    })
    local parallel_time = os.clock() - parallel_start
    print("Parallel execution time: " .. string.format("%.3f", parallel_time) .. " seconds")

    -- Show speedup
    if parallel_time > 0 then -- Avoid division by zero if timing is too fast/low resolution
      local speedup = sequential_time / parallel_time
      print("\nParallel execution was " .. string.format("%.2fx", speedup) .. " faster")
    end
    print("\nParallel execution results:")
    print("  Total tests: " .. results.total)
    print("  Passed: " .. results.passed)
    print("  Failed: " .. results.failed)
    print("  Skipped: " .. results.skipped)
  else
    logger.info("\nParallel module not available. Cannot demonstrate parallel execution.")
  end

  -- Cleanup is handled by temp_file.cleanup_all() below

  logger.info("\nParallel Test Execution Example Complete")
  logger.info("To use parallel execution in your own tests, run:")
  logger.info("  lua firmo.lua --parallel --workers 4 tests/")
end

-- Cleanup is handled automatically by temp_file registration
