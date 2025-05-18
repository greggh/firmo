print("PERF_TEST: File loaded")
---@diagnostic disable: missing-parameter, param-type-mismatch
--- Firmo Performance Tests
---
--- Contains tests designed to measure the performance characteristics of Firmo,
--- specifically focusing on:
--- - The performance overhead and memory impact of the module reset feature.
--- - General memory usage when running small and large test suites.
--- - Performance of the error handling mechanisms.
--- Uses the `lib.tools.benchmark` module for measurements and `lib.core.module_reset`
--- for testing isolation features. Relies on fixtures for error generation.
--- Skips tests if the benchmark, module_reset, or fixtures modules are unavailable.
---
--- @author Firmo Team
--- @test
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local logging = require("lib.tools.logging")

-- Import utility modules
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

-- Create logger for performance tests
local logger = logging.get_logger("performance_test")

-- Try to load benchmark module
local benchmark = require("lib.tools.benchmark")
local module_reset = require("lib.core.module_reset")

-- Load fixtures
local fixtures_path = "./tests/fixtures/common_errors.lua"
local fixtures = dofile(fixtures_path)

describe("Performance Tests", function()
  -- Register modules with firmo
  benchmark.register_with_firmo(firmo)
  module_reset.register_with_firmo(firmo)

  describe("Test suite isolation", function()
    print("PERF_TEST: First describe block entered")
    it("should measure performance impact of module reset", function()
      print("PERF_TEST: First 'it' block entered")
      -- Memory usage before tests
      local initial_memory = collectgarbage("count")

      -- Set up test modules with some mutable state
      local module_count = 10
      local modules = {}

      local module_content_template = [[
        local M = {{}} -- Use double curlies to escape for string.format
        M.data = {{}}
        M.counter = 0
        function M.increment() M.counter = M.counter + 1 end
        function M.add_data(k, v) M.data[k] = v end
        function M.get_counter() return M.counter end
        function M.get_data() return M.data end
        function M.get_name() return "%s" end -- To ensure each module can report its name
        return M
      ]]

      for i = 1, module_count do
        -- Create a temporary module for testing module reset
        local name = "test_module_" .. i
        local path = "/tmp/" .. name .. ".lua"
        -- local success, err = pcall(dofile, file) -- `file` was undefined, and dofile not needed here.

        -- Write module file
        local err_obj, write_success = test_helper.with_error_capture(function()
          local current_module_content = string.format(module_content_template, name)
          return fs.write_file(path, current_module_content)
        end)()

        if err_obj or not write_success then
          logger.error("Failed to write module file", {
            name = name,
            path = path,
            error = err_obj or "write_file returned false",
            context = "module_creation",
          })
          goto continue
        end
        table.insert(modules, { name = name, path = path })
        ::continue::
      end

      -- Ensure modules can be loaded
      package.path = "/tmp/?.lua;" .. package.path

      -- Benchmark with module reset disabled
      local function run_without_reset()
        -- Configure to disable module reset
        firmo.module_reset.configure({
          reset_modules = false,
        })

        -- Load all modules and update state
        for _, mod in ipairs(modules) do
          local m = require(mod.name)
          m.increment()
          m.add_data("key" .. math.random(100), "value" .. math.random(100))
        end

        -- Run a normal firmo reset
        firmo.reset()
        collectgarbage("collect")
      end

      -- Benchmark with module reset enabled
      local function run_with_reset()
        -- Configure to enable module reset
        firmo.module_reset.configure({
          reset_modules = true,
        })

        -- Load all modules and update state
        for _, mod in ipairs(modules) do
          local m = require(mod.name)
          m.increment()
          m.add_data("key" .. math.random(100), "value" .. math.random(100))
        end

        -- Run a reset that includes module reset
        firmo.reset()
        collectgarbage("collect")
      end

      print("PERF_TEST: First 'it' block - before critical section")

      -- Run benchmarks
      local without_reset_results = firmo.benchmark.measure(run_without_reset, nil, {
        iterations = 10,
        warmup = 2,
        label = "Without module reset",
      })

      local with_reset_results = firmo.benchmark.measure(run_with_reset, nil, {
        iterations = 10,
        warmup = 2,
        label = "With module reset",
      })

      -- Memory usage after tests
      collectgarbage("collect")
      local final_memory = collectgarbage("count")
      local memory_growth = final_memory - initial_memory

      logger.info("Memory usage statistics", {
        growth_kb = memory_growth,
        context = "module_reset_testing",
        test_phase = "completion",
      })
      expect(memory_growth).to.be_less_than(1000) -- 1MB is a reasonable limit
      for _, mod in ipairs(modules) do
        fs.delete_file(mod.path)
      end

      -- Reset package path
      package.path = package.path:gsub("/tmp/?.lua;", "")

      -- Make sure results are reasonable
      expect(with_reset_results.time_stats.mean).to.be_greater_than(0)
      expect(without_reset_results.time_stats.mean).to.be_greater_than(0)
    end)
  end)

  describe("Memory usage optimization", function()
    it("should track and compare memory usage of large test suites", function()
      -- Memory usage before generating test files
      local initial_memory = collectgarbage("count")

      -- Generate a small test suite for benchmarking
      local small_suite = firmo.benchmark.generate_large_test_suite({
        file_count = 5,
        tests_per_file = 10,
        output_dir = "/tmp/small_benchmark_tests",
      })

      -- Generate a larger test suite for benchmarking
      local large_suite = firmo.benchmark.generate_large_test_suite({
        file_count = 10,
        tests_per_file = 20,
        output_dir = "/tmp/large_benchmark_tests",
      })

      -- Function to test memory usage when running test suites
      local function run_test_suite(suite_dir, with_reset)
        -- Configure module reset
        firmo.module_reset.configure({
          reset_modules = with_reset,
        })

        -- Get test files
        local files = {}
        local all_files, err = test_helper.with_error_capture(function()
          return fs.list_files(suite_dir)
        end)()

        if not all_files then
          logger.error("Failed to list test files", { directory = suite_dir, error = err })
          return
        end

        -- Filter to only Lua files and construct proper paths
        for _, file in ipairs(all_files) do
          if file:match("%.lua$") then
            -- Create proper path without duplication
            local file_path = fs.join_paths(suite_dir, file)
            table.insert(files, file_path)

            -- Log the file path for debugging
            logger.debug("Added test file to run")
          end
        end

        -- Run each test file
        for i, file in ipairs(files) do
          firmo.reset()

          -- Use pcall with dofile for safer execution
          local success, err = pcall(dofile, file)
          if not success then
            logger.error("Failed to run test file")
          end
        end

        -- Clean up
        collectgarbage("collect")
      end

      -- Benchmark small suite without reset
      local small_without_reset = firmo.benchmark.measure(
        run_test_suite,
        { small_suite.output_dir, false },
        { label = "Small suite without reset" }
      )

      -- Benchmark small suite with reset
      local small_with_reset = firmo.benchmark.measure(
        run_test_suite,
        { small_suite.output_dir, true },
        { label = "Small suite with reset" }
      )

      -- Benchmark large suite without reset
      local large_without_reset = firmo.benchmark.measure(
        run_test_suite,
        { large_suite.output_dir, false },
        { label = "Large suite without reset" }
      )

      -- Benchmark large suite with reset
      local large_with_reset = firmo.benchmark.measure(
        run_test_suite,
        { large_suite.output_dir, true },
        { label = "Large suite with reset" }
      )

      -- Memory measurement after tests
      collectgarbage("collect")
      local final_memory = collectgarbage("count")
      local memory_growth = final_memory - initial_memory

      logger.info("Memory usage statistics", {
        growth_kb = memory_growth,
        context = "memory_tracking",
        test_phase = "completion",
      })
      expect(memory_growth).to.be_less_than(1000) -- 1MB is a reasonable limit

      -- Clean up test files
      fs.remove_dir(small_suite.output_dir)
      fs.remove_dir(large_suite.output_dir)
    end)
  end)

  describe("Error handling performance", function()
    it("should measure error handling performance", { expect_error = true }, function()
      -- Only run if fixtures are available

      -- Test error handling speed with proper error capture
      local function handle_errors()
        -- Try various error types
        local error_types = {
          "nil_access",
          "type_error",
          "custom_error",
          "assertion_error",
          "upvalue_capture_error",
        }

        for _, error_type in ipairs(error_types) do
          local result, err = test_helper.with_error_capture(function()
            return fixtures[error_type]()
          end)()

          -- Verify error was caught
          expect(err).to.exist()
        end
      end
      -- Measure error handling performance
      local error_perf = firmo.benchmark.measure(handle_errors, nil, {
        iterations = 100,
        label = "Error handling performance",
      })

      -- Log benchmark results
      logger.info("Error handling benchmark results", {
        mean_time = error_perf.time_stats.mean,
        min_time = error_perf.time_stats.min,
        max_time = error_perf.time_stats.max,
        context = "error_handling_performance",
      })

      -- Make sure the benchmark ran successfully
      expect(error_perf.time_stats.mean).to.be_greater_than(0)
    end)
  end)
end)
