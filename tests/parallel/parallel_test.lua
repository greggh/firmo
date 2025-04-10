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

-- Setup test files directory
local TEST_DIR = "/tmp/parallel_test_" .. tostring(os.time())
local TEST_FILES = {}

-- Function to create a test file with specified parameters
local function create_test_file(name, content)
  local file_path = fs.join_paths(TEST_DIR, name .. ".lua")
  local success, err = test_helper.with_error_capture(function()
    return fs.write_file(file_path, content)
  end)()
  
  if not success then
    return nil, err
  end
  
  TEST_FILES[#TEST_FILES + 1] = file_path
  return file_path
end

-- Function to cleanup test files
local function cleanup_test_files()
  -- Delete the test directory and all files with error handling
  local success, err = test_helper.with_error_capture(function()
    return fs.delete_directory(TEST_DIR, true)
  end)()
  
  if not success and err then
    firmo.log.warn("Failed to cleanup test files", { error = err })
  end
  
  -- Clear the test files table
  TEST_FILES = {}
end

describe("Parallel Execution Module", function()
  before(function()
    -- Create test directory with error handling
    local dir_success, dir_err = test_helper.with_error_capture(function()
      return fs.ensure_directory_exists(TEST_DIR)
    end)()
    
    expect(dir_err).to_not.exist("Failed to create test directory")
    
    -- Create test files with error handling
    local passing_path, passing_err = create_test_file("passing_test", [[
      local firmo = require("firmo")
      local describe, it, expect = firmo.describe, firmo.it, firmo.expect
      
      describe("Passing Test", function()
        it("should pass", function()
          expect(true).to.be_truthy()
        end)
      end)
    
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
    ]])
    
    create_test_file("slow_test", [[
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
      end)
    ]])
    
    expect(slow_err).to_not.exist("Failed to create slow test file")
    expect(slow_path).to.exist()
    
    -- Configure parallel options for testing
    local config_success, config_err = test_helper.with_error_capture(function()
      central_config.set({
        workers = 2,
        timeout = 10,
        output_buffer_size = 1024,
        verbose = false,
        show_worker_output = false, -- Don't show output during tests
        fail_fast = false,
        aggregate_coverage = true
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
  end)
  
  after(function()
    -- Clean up test files
    cleanup_test_files()
    
    -- Reset configuration
    central_config.reset()
  end)
  
  it("should initialize with default configuration", function()
    -- Test that the parallel module has default configuration values
    expect(parallel.options.workers).to.be_a("number")
    expect(parallel.options.timeout).to.be_a("number")
    expect(parallel.options.fail_fast).to.be_a("boolean")
  end)
  
  it("should correctly detect the number of available processor cores", function()
    local cores = parallel.get_processor_count()
    expect(cores).to.be_a("number")
    expect(cores).to.be_greater_than(0)
  end)
  
  it("should run tests in parallel and return aggregated results", function()
    -- Configure options just for this test
    local options = {
      workers = 2,
      timeout = 5,
      verbose = false,
      show_worker_output = false,
      fail_fast = false
    }
    
    -- Run the passing and slow tests in parallel
    local results = parallel.run_files({
      fs.join_paths(TEST_DIR, "passing_test.lua"),
      fs.join_paths(TEST_DIR, "slow_test.lua")
    }, options)
    
    -- Validate the results
    expect(results).to.exist()
    expect(results.total_files).to.equal(2)
    expect(results.passed_files).to.equal(2)
    expect(results.failed_files).to.equal(0)
    
    -- Check timing - parallel execution should be faster than sequential
    expect(results.execution_time).to.be_less_than(5) -- Should be close to 2 seconds, not 4
  end)
  
  it("should handle failures correctly", { expect_error = true }, function()
    -- Configure options just for this test
    local options = {
      workers = 2,
      timeout = 5,
      verbose = false,
      show_worker_output = false,
      fail_fast = false
    }
    
    -- Run the passing and failing tests in parallel
    local results = parallel.run_files({
      fs.join_paths(TEST_DIR, "passing_test.lua"),
      fs.join_paths(TEST_DIR, "failing_test.lua")
    }, options)
    
    -- Validate the results
    expect(results).to.exist()
    expect(results.total_files).to.equal(2)
    expect(results.passed_files).to.equal(1)
    expect(results.failed_files).to.equal(1)
  end)
  
  it("should stop execution on first failure when fail_fast is enabled", { expect_error = true }, function()
    -- Configure options just for this test
    local options = {
      workers = 2,
      timeout = 5,
      verbose = false,
      show_worker_output = false,
      fail_fast = true
    }
    -- Create an additional test file that would run if fail_fast didn't work
    local very_slow_path, very_slow_err = create_test_file("very_slow_test", [[
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
      end)
    ]])
    
    -- Run a failing test first (which should trigger fail_fast) and then the very slow test
    local results = parallel.run_files({
      fs.join_paths(TEST_DIR, "failing_test.lua"),
      fs.join_paths(TEST_DIR, "very_slow_test.lua")
    }, options)
    
    -- Validate the results - fail_fast should prevent the very slow test from completing
    expect(results).to.exist()
    expect(results.total_files).to.equal(2)
    expect(results.failed_files).to.be_greater_than(0)
    expect(results.execution_time).to.be_less_than(10) -- Should not wait for the very slow test
  end)
  
  it("should handle timeouts gracefully", { expect_error = true }, function()
    -- Configure options with a short timeout
    local options = {
      workers = 1,
      timeout = 1, -- 1 second timeout (our slow test takes 2 seconds)
      verbose = false,
      show_worker_output = false,
      fail_fast = false
    }
    
    -- Run the slow test with a short timeout
    local results = parallel.run_files({
      fs.join_paths(TEST_DIR, "slow_test.lua")
    }, options)
    
    -- Validate the results - the test should timeout and be considered a failure
    expect(results).to.exist()
    expect(results.timeout_files).to.be_greater_than(0)
  end)
end)

-- Tests are run by scripts/runner.lua or run_all_tests.lua, not by direct execution
