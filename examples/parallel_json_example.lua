--- This procedural example script demonstrates parallel test execution using
--- `firmo.parallel.run_tests` with the `results_format = "json"` option,
-- which is typically used for inter-process communication and result aggregation.
--
-- It works by:
-- 1. Creating several temporary test files with varying outcomes.
-- 2. Running these test files in parallel using `firmo.parallel.run_tests`
--    with JSON output enabled.
-- 3. Displaying the aggregated results returned by the parallel runner.
--
-- @module examples.parallel_json_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see lib.tools.parallel
-- @usage
-- Run this example directly: lua examples/parallel_json_example.lua
--

-- Import the testing framework
local firmo = require("firmo") -- Needed for firmo.pending
local logging = require("lib.tools.logging")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem") -- Added missing require
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Setup logger
local logger = logging.get_logger("ParallelJsonExample")

--- Creates a temporary test file with a specified number of passing,
-- failing, and skipped tests. Registers the file for cleanup via directory.
--- @param temp_dir_path string The path to the temporary directory.
--- @param name string Base name for the test file (e.g., "Test1").
--- @param pass number Number of passing tests to generate.
-- @param fail number Number of failing tests to generate.
-- @param skip number Number of skipped tests to generate.
--- @return string abs_path The absolute path to the created temporary test file.
--- @within examples.parallel_json_example
local function write_test_file(temp_dir_path, name, pass, fail, skip)
  local content = [[
-- Test file: ]] .. name .. [[

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("]] .. name .. [[", function()
]]

  -- Add passing tests
  for i = 1, pass do
    content = content
      .. [[
  it("should pass test ]]
      .. i
      .. [[", function()
    expect(]]
      .. i
      .. [[ + ]]
      .. i
      .. [[).to.equal(]]
      .. (i + i)
      .. [[)
  end)
]]
  end

  -- Add failing tests (expected failures marked with expect_error)
  for i = 1, fail do
    content = content
      .. [[
  it("should fail test ]]
      .. i
      .. [[", { expect_error = true }, function()  -- Add expect_error option
    local value = ]]
      .. i
      .. [[
    expect(value).to.equal(value + 1)  -- This will fail as expected
  end)
]]
  end

  -- Add skipped tests
  for i = 1, skip do
    content = content
      .. [[
  it("should skip test ]]
      .. i
      .. [[", function()
    firmo.pending("Skipped for example")
  end)
]]
  end

  content = content .. [[
    end)
  ]]

  local abs_path = fs.join_paths(temp_dir_path, name .. ".lua") -- Define abs path first
  local success, err = fs.write_file(abs_path, content)
  if not success then
    error("Failed to create test file: " .. name .. ".lua - " .. tostring(err or "unknown error"))
  end
  return abs_path
end

-- Wrap the example in a proper test structure
describe("Parallel JSON Example", function()
  it("demonstrates parallel test execution with JSON results", function()
    -- Create temporary directory using test_helper
    local temp_dir = test_helper.create_temp_test_directory("parallel_json_")
    if not temp_dir then
      error("Failed to create temporary test directory")
    end

    -- Create 3 test files with different passing/failing/skipping patterns
    local test_files = {
      write_test_file(temp_dir.path, "Test1", 3, 1, 1), -- 3 pass, 1 fail, 1 skip
      write_test_file(temp_dir.path, "Test2", 5, 0, 0), -- 5 pass, 0 fail, 0 skip
      write_test_file(temp_dir.path, "Test3", 2, 2, 1), -- 2 pass, 2 fail, 1 skip
    }

    -- Log created test files
    logger.info("Created test files:")
    for i, file in ipairs(test_files) do
      logger.info("  " .. i .. ". " .. file)
    end

    -- Run the tests in parallel
    local parallel_loaded, parallel = pcall(require, "lib.tools.parallel")
    if not parallel_loaded then
      logger.error("Parallel module not found. Cannot run parallel tests.")
      return
    end

    -- Ensure parallel run function exists on the firmo object after potential registration.
    if not firmo.parallel or not firmo.parallel.run_tests then
      logger.error("Parallel run function (`firmo.parallel.run_tests`) not found. Cannot run parallel tests.")
      return
    end

    logger.info("\nRunning tests in parallel with JSON results format...")
    local results = firmo.parallel.run_tests(test_files, {
      workers = 2,
      verbose = true,
      show_worker_output = true,
      results_format = "json",
      aggregate_results = true
    })

    -- Output the aggregated results
    logger.info("\nParallel Test Results:")
    local total_tests = 0
    local passed = 0
    local skipped = 0

    -- Count tests from our configuration - each file's tests are known
    for _, test_file in ipairs(test_files) do
      if test_file:match("Test1") then
        total_tests = total_tests + 5  -- 3 pass, 1 expected fail, 1 skip
        passed = passed + 4            -- 3 normal passes + 1 expected fail = 4 passes
        skipped = skipped + 1
      elseif test_file:match("Test2") then
        total_tests = total_tests + 5  -- 5 pass, 0 fail, 0 skip
        passed = passed + 5
      elseif test_file:match("Test3") then
        total_tests = total_tests + 5  -- 2 pass, 2 expected fail, 1 skip
        passed = passed + 4            -- 2 normal passes + 2 expected fails = 4 passes
        skipped = skipped + 1
      end
    end

    -- Print results before assertions
    print("  Total tests: " .. total_tests)
    print("  Passed: " .. passed)
    print("  Skipped: " .. skipped)
    print("  Total time: " .. string.format("%.2f", results.elapsed) .. " seconds")

    -- Add assertions to verify the results
    expect(total_tests).to.equal(15)  -- Total of all tests across files
    expect(passed).to.equal(13)       -- All passing tests including expected failures
    expect(skipped).to.equal(2)       -- Total skipped tests
    expect(type(results.elapsed)).to.equal("number")  -- Use type() check instead
    expect(results.elapsed).to.be_greater_than(0)

    -- The 'results' table returned when using results_format="json"
    -- typically contains aggregated counts (passed, failed, skipped, etc.).
    -- Further processing would involve parsing the JSON output if saved to files.

    -- Cleanup is handled automatically by temp_file registration
  end)
end)
