--- parallel_json_example.lua
--
-- This procedural example script demonstrates parallel test execution using
-- `firmo.parallel.run_tests` with the `results_format = "json"` option,
-- which is typically used for inter-process communication and result aggregation.
--
-- It works by:
-- 1. Creating several temporary test files with varying outcomes.
-- 2. Running these test files in parallel using `firmo.parallel.run_tests`
--    with JSON output enabled.
-- 3. Displaying the aggregated results returned by the parallel runner.
--
-- Run this example directly: lua examples/parallel_json_example.lua
--

-- Import the testing framework
local firmo = require("firmo") -- Needed for firmo.pending
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local temp_file = require("lib.tools.filesystem.temp_file")

-- Setup logger
local logger = logging.get_logger("ParallelJsonExample")

--- Creates a temporary test file with a specified number of passing,
-- failing, and skipped tests.
-- @param temp_dir_obj table The temp_file directory object.
-- @param name string Base name for the test file (e.g., "Test1").
-- @param pass number Number of passing tests to generate.
-- @param fail number Number of failing tests to generate.
-- @param skip number Number of skipped tests to generate.
-- @return string abs_path The absolute path to the created temporary test file.
local function write_test_file(temp_dir_obj, name, pass, fail, skip)
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

  -- Add failing tests
  for i = 1, fail do
    content = content
      .. [[
  it("should fail test ]]
      .. i
      .. [[", function()
    expect(]]
      .. i
      .. [[).to.equal(]]
      .. (i + 1)
      .. [[)
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

  local abs_path, err = temp_dir_obj:create_file(name .. ".lua", content)
  if not abs_path then
    error("Failed to create test file: " .. name .. ".lua - " .. (err and err.message or "unknown error"))
  end
  return abs_path
end

-- Create temporary directory
local temp_dir, err = temp_file.create_temp_directory("parallel_json_")
if not temp_dir then
  logger.error("Failed to create temporary directory: " .. tostring(err))
  return
end

-- Create 3 test files with different passing/failing/skipping patterns
local test_files = {
  write_test_file(temp_dir, "Test1", 3, 1, 1), -- 3 pass, 1 fail, 1 skip
  write_test_file(temp_dir, "Test2", 5, 0, 0), -- 5 pass, 0 fail, 0 skip
  write_test_file(temp_dir, "Test3", 2, 2, 1), -- 2 pass, 2 fail, 1 skip
}

logger.info("Created test files:")
for i, file in ipairs(test_files) do
  logger.info("  " .. i .. ". " .. file)
end

-- Run the tests in parallel
local parallel_loaded, parallel = pcall(require, "lib.tools.parallel")
if not parallel_loaded then
  logger.error("Parallel module not found. Cannot run parallel tests.")
  temp_file.cleanup_all()
  return
end

-- NOTE: Verify API signature.
parallel.register_with_firmo(firmo)

-- NOTE: Verify API signature.
local results = parallel.run_tests(test_files, {
  workers = 2,
  verbose = true,
  show_worker_output = true,
  results_format = "json", -- Enable JSON output
})

-- Removed manual cleanup loop

-- Output the aggregated results
logger.info("\nParallel Test Results:")
print("  Total tests: " .. (results.passed + results.failed + results.skipped)) -- Keep result print
print("  Passed: " .. results.passed)
print("  Failed: " .. results.failed)
print("  Skipped: " .. results.skipped)
print("  Total time: " .. string.format("%.2f", results.elapsed) .. " seconds")

-- Removed manual counting verification block

-- Cleanup temporary files
temp_file.cleanup_all()
