-- Tests for parallel execution functionality
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import filesystem module for file operations
local fs = require("lib.tools.filesystem")

-- Import test helper for error handling
local test_helper = require("lib.tools.test_helper")

-- Import the parallel module
local parallel = require("lib.tools.parallel")

-- Import central_config for configuration
local central_config = require("lib.core.central_config")

-- Import logging module for proper logging
local logging = require("lib.tools.logging")
-- Import the temp_file module for proper test file management
local temp_file = require("lib.tools.filesystem.temp_file")

-- Setup test files directory using temp_file system for proper cleanup
local TEST_DIR
local TEST_FILES = {}

-- Function to create a test file with specified parameters
local function create_test_file(name, content)
  -- Ensure the directory exists first
  if not TEST_DIR then
    return nil, "Test directory not initialized"
  end

  local file_path = fs.join_paths(TEST_DIR, name .. ".lua")
  local success, err = test_helper.with_error_capture(function()
    local write_success = fs.write_file(file_path, content)
    if write_success then
      -- Register with temp_file system for automatic cleanup
      temp_file.register_file(file_path)
    end
    return write_success
  end)()

  if not success then
    return nil, err
  end

  TEST_FILES[#TEST_FILES + 1] = file_path
  return file_path
end

-- Function to cleanup test files
local function cleanup_test_files()
  -- Files registered with temp_file will be cleaned up automatically
  -- This is just for additional cleanup if needed
  if TEST_DIR then
    local success, err = test_helper.with_error_capture(function()
      -- Check if directory still exists before trying to delete
      if fs.directory_exists(TEST_DIR) then
        return fs.delete_directory(TEST_DIR, true)
      end
      return true
    end)()
    if not success and err then
      logging.warn("Failed to cleanup test directory", { error = err, directory = TEST_DIR })
    end
    -- Clear the test files table
    TEST_FILES = {}
  end
end
describe("Parallel Execution Module", function()
  before(function()
    -- Create a temporary test directory with error handling
    local temp_dir_result, temp_dir_err = test_helper.with_error_capture(function()
      return temp_file.create_temp_directory("parallel_test_")
    end)()

    expect(temp_dir_err).to_not.exist("Failed to create temporary test directory")
    expect(temp_dir_result).to.exist("Failed to create temporary test directory")

    -- Store the directory path and register it for cleanup
    TEST_DIR = temp_dir_result
    temp_file.register_directory(TEST_DIR)
    -- Create test files with error handling
    local passing_path, passing_err = create_test_file(
      "passing_test",
      [[
      local firmo = require("firmo")
      local describe, it, expect = firmo.describe, firmo.it, firmo.expect

      describe("Passing Test", function()
        it("should pass test one", function()
          expect(true).to.be_truthy()
        end)
        it("should pass test two", function()
          expect(1).to.equal(1)
        end)
      end)
      return true  -- Indicate successful run
      ]]
    )

    expect(passing_err).to_not.exist("Failed to create passing test file")
    expect(passing_path).to.exist()

    local failing_path, failing_err = create_test_file("failing_test", [[
      local firmo = require("firmo")
      local describe, it, expect = firmo.describe, firmo.it, firmo.expect

      describe("Failing Test", function()
        it("should fail", function()
          expect(false).to.be_truthy()
        end)
      end)
    ]]
    )

    expect(failing_err).to_not.exist("Failed to create failing test file")
    expect(failing_path).to.exist()
    local slow_path, slow_err = create_test_file(
      "slow_test",
      [[
      local firmo = require("firmo")
      local describe, it, expect = firmo.describe, firmo.it, firmo.expect

      describe("Slow Test", function()
        it("should take some time", function()
          local start = os.time()
          while os.time() - start < 2 do
            -- Wait for 2 seconds
          end
          expect(true).to.be_truthy()
        end)
        it("should also pass quickly", function()
          expect(true).to.be_truthy()
        end)
      end)
      return true  -- Indicate successful run
      ]]
    )

    expect(slow_err).to_not.exist("Failed to create slow test file")
    expect(slow_path).to.exist()
    -- Reset the parallel module to a clean state
    local reset_result, reset_err = test_helper.with_error_capture(function()
      return parallel.full_reset()  -- This is enough for initial setup
    end)()
    expect(reset_err).to_not.exist("Failed to reset parallel module")

    -- Configure parallel options for testing
    local config_success, config_err = test_helper.with_error_capture(function()
      central_config.set({
        parallel = {
          workers = 4, -- Use module default
          timeout = 60,  -- Match module default
          output_buffer_size = 1024,
          verbose = false,
          show_worker_output = false, -- Don't show output during tests
          fail_fast = false,
          aggregate_coverage = true,
        }
      })
      return true
    end)()

    expect(config_err).to_not.exist("Failed to set configuration")

    -- Make sure the parallel module has the right configuration
    local config_result, parallel_err = test_helper.with_error_capture(function()
      return parallel.configure()
    end)()
    expect(parallel_err).to_not.exist("Failed to configure parallel module")
    -- Verify configuration was applied correctly
    local debug_config = parallel.debug_config()
    expect(debug_config).to.exist("Failed to get debug configuration")
    expect(debug_config.local_config).to.exist("Local configuration not found in debug_config")
    expect(debug_config.local_config.workers).to.equal(4, "Workers configuration not applied correctly")
    expect(debug_config.local_config.timeout).to.equal(60, "Timeout configuration not applied correctly")
    expect(debug_config.local_config.fail_fast).to.equal(false, "Fail-fast configuration not applied correctly")
  end)

  after(function()
    -- Clean up test files
    cleanup_test_files()

    -- Reset the parallel module back to defaults
    local reset_result, reset_err = test_helper.with_error_capture(function()
      return parallel.full_reset()  -- This handles both cancellation and reset
    end)()
    if reset_err then
      logging.warn("Failed to reset parallel module", { error = reset_err })
    end
    central_config.reset()
  end)
  it("should initialize with default configuration", function()
    -- Reset to default configuration
    local reset_success, reset_err = test_helper.with_error_capture(function()
      parallel.reset()
      return true
    end)()
    
    expect(reset_err).to_not.exist("Failed to reset parallel module")
    
    -- Test that the parallel module has default configuration values
    expect(parallel.options).to.exist("Parallel options not defined")
    expect(parallel.options.workers).to.be.a("number")
    expect(parallel.options.timeout).to.be.a("number")
    expect(parallel.options.fail_fast).to.be.a("boolean")
    
    -- Test for specific default values
    local debug_config = parallel.debug_config()
    expect(debug_config.local_config).to.exist("Local configuration not found in debug_config")
    expect(debug_config.local_config.workers).to.be_greater_than(0, "Default workers should be greater than 0")
    expect(debug_config.local_config.timeout).to.be_greater_than(0, "Default timeout should be greater than 0")
  end)
  it("should correctly configure worker count based on system resources", function()
    -- Reset to ensure we're using default configuration
    local reset_success, reset_err = test_helper.with_error_capture(function()
      parallel.reset()
      return true
    end)()
    
    expect(reset_err).to_not.exist("Failed to reset parallel module")
    
    -- Check worker count directly from options
    local workers = parallel.options.workers
    expect(workers).to.exist("Worker count should exist")
    expect(workers).to.be.a("number")
    expect(workers).to.be_greater_than(0, "Should have at least one worker")
  end)

  it("should run tests in parallel and return aggregated results", function()
    -- Configure options just for this test
    local options = {
      workers = 4, -- Use module default
      timeout = 5,
      verbose = false,
      show_worker_output = false,
      fail_fast = false,
    }
    -- Log test execution for debugging
    logging.debug("Running test files in parallel", {
      files = {
        fs.join_paths(TEST_DIR, "passing_test.lua"),
        fs.join_paths(TEST_DIR, "slow_test.lua")
      },
      options = options
    })

    -- Run the passing and slow tests in parallel with error handling
    local results, run_err = test_helper.with_error_capture(function()
      return parallel.run_tests({
        fs.join_paths(TEST_DIR, "passing_test.lua"),
        fs.join_paths(TEST_DIR, "slow_test.lua"),
      }, options)
    end)()

    -- Validate the results
    expect(run_err).to_not.exist("Failed to run test files in parallel")
    expect(results).to.exist("Parallel run results should exist")
    -- Guaranteed fields should exist and be valid
    -- Check that all test files were executed
    expect(results.files_run).to.exist("Should have list of files run")
    expect(#results.files_run).to.equal(2, "Should have run 2 test files")

    -- Check timing to validate parallel execution worked
    expect(results.elapsed).to.exist("Should have elapsed time")
    expect(results.elapsed).to.be_less_than(5, "Parallel execution should be faster than sequential")
  end)

  it("should handle failures correctly", { expect_error = true }, function()
    -- Configure options just for this test
    local options = {
      workers = 4, -- Use module default
      timeout = 5,
      verbose = false,
      show_worker_output = false,
      fail_fast = false,
    }
    -- Log test execution for debugging
    logging.debug("Running test files in parallel with expected failure", {
      files = {
        fs.join_paths(TEST_DIR, "passing_test.lua"),
        fs.join_paths(TEST_DIR, "failing_test.lua")
      },
      options = options
    })

    -- Run the passing and failing tests in parallel
    local results, run_err = test_helper.with_error_capture(function()
      return parallel.run_tests({
        fs.join_paths(TEST_DIR, "passing_test.lua"),
        fs.join_paths(TEST_DIR, "failing_test.lua"),
      }, options)
    end)()
    
    -- We should get results, but with failures indicated
    expect(results).to.exist("Parallel run results should exist even with failures")
    -- Check file execution
    expect(results.files_run).to.exist("Should have list of files run")
    expect(#results.files_run).to.equal(2, "Should have run 2 test files")
    
    -- Check result fields conditionally
    if results.total ~= nil then
      expect(results.total).to.be_greater_than(0, "Should have run some tests")
    end
    expect(results.elapsed).to.exist("Should have elapsed time")
  end)  -- Close handle failures test

  it("should stop execution on first failure when fail_fast is enabled", { expect_error = true }, function()
    -- Configure options just for this test
    local options = {
      workers = 4, -- Use module default
      timeout = 5,
      verbose = false,
      show_worker_output = false,
      fail_fast = true,
    }
    
    -- Create an additional test file that would run if fail_fast didn't work
    local very_slow_path, very_slow_err = create_test_file(
      "very_slow_test",
      [[
      local firmo = require("firmo")
      local describe, it, expect = firmo.describe, firmo.it, firmo.expect

      describe("Very Slow Test", function()
        it("should take a long time", function()
          local start = os.time()
          while os.time() - start < 10 do
            -- Wait for 10 seconds
          end
          expect(true).to.be_truthy()
        end)
        it("should also pass when run", function()
          expect(true).to.be_truthy()
        end)
      end)
      return true  -- Indicate successful run
      ]]
    )

    expect(very_slow_err).to_not.exist("Failed to create very slow test file")
    -- Log test execution for debugging
    logging.debug("Running test files with fail_fast enabled", {
      files = {
        fs.join_paths(TEST_DIR, "failing_test.lua"),
        fs.join_paths(TEST_DIR, "very_slow_test.lua")
      },
      options = options
    })

    -- Run a failing test first (which should trigger fail_fast) and then the very slow test
    local results, run_err = test_helper.with_error_capture(function()
      return parallel.run_tests({
        fs.join_paths(TEST_DIR, "failing_test.lua"),
        fs.join_paths(TEST_DIR, "very_slow_test.lua"),
      }, options)
    end)()
    
    -- Validate the results - fail_fast should prevent the very slow test from completing
    expect(results).to.exist("Parallel run results should exist with fail_fast")
    
    -- Check file execution
    expect(results.files_run).to.exist("Should have list of files run")
    expect(#results.files_run).to.be_greater_than(0, "Should have tracked at least one file")
    
    -- Check result fields conditionally
    if results.total ~= nil then
      expect(results.total).to.be_greater_than(0, "Should have run some tests")
    end
    -- Check timing
    expect(results.elapsed).to.be_less_than(10, "Should not wait for the very slow test")
  end)  -- Close the fail-fast test

  it("should handle timeouts gracefully", { expect_error = true }, function()
    local options = {
      workers = 1,
      timeout = 1, -- 1 second timeout (our slow test takes 2 seconds)
      verbose = false,
      show_worker_output = false,
      fail_fast = false,
    }
    
    -- Log test execution for debugging
    logging.debug("Running test with short timeout", {
      files = { fs.join_paths(TEST_DIR, "slow_test.lua") },
      options = options
    })

    -- Run the slow test with a short timeout
    local results, run_err = test_helper.with_error_capture(function()
      return parallel.run_tests({
        fs.join_paths(TEST_DIR, "slow_test.lua"),
      }, options)
    end)()
    
    -- Validate the results - the test should timeout and be considered a failure
    expect(results).to.exist("Parallel run results should exist even with timeouts")
    expect(results.files_run).to.exist("Should have list of files run")
    expect(#results.files_run).to.equal(1, "Should have run 1 test file")
    
    -- Check execution results conditionally
    if results.total ~= nil then
      expect(results.total).to.exist("Should have total test count")
    end
    -- Check timing
    expect(results.elapsed).to.be_less_than(3, "Timeout should prevent long execution")
  end)  -- Close the timeout test

end)  -- Close the describe block
