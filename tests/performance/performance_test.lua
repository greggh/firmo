-- Performance tests for firmo
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import filesystem module
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

-- Try to load benchmark module
local benchmark_loaded, benchmark = pcall(require, "lib.tools.benchmark")
local module_reset_loaded, module_reset = pcall(require, "lib.core.module_reset")

-- Load fixtures
local fixtures_path = "./tests/fixtures/common_errors.lua"
local fixtures_loaded, fixtures = pcall(dofile, fixtures_path)

describe("Performance Tests", function()

  if not benchmark_loaded then
    it("requires the benchmark module", function()
      firmo.pending("benchmark module not available")
    end)
    return
  end
  
  if not module_reset_loaded then
    it("requires the module_reset module", function()
      firmo.pending("module_reset module not available")
    end)
    return
  end
  
  if not fixtures_loaded then
    it("requires test fixtures", function()
      firmo.pending("fixtures not available: " .. tostring(fixtures))
    end)
    return
  end
  
  -- Register modules with firmo
  benchmark.register_with_firmo(firmo)
  module_reset.register_with_firmo(firmo)
  
  describe("Test suite isolation", function()
    it("should measure performance impact of module reset", function()
      -- Set up test modules with some mutable state
      local module_count = 10
      local modules = {}
      
      for i = 1, module_count do
        local name = "bench_module_" .. i
        local path = fs.join_paths("/tmp", name .. ".lua")
        
        -- Create module with some state
        local module_content = [[
          local ]] .. name .. [[ = {
            counter = 0,
            data = {},
            name = "]] .. name .. [["
          }
          
          function ]] .. name .. [[.increment()
            ]] .. name .. [[.counter = ]] .. name .. [[.counter + 1
            return ]] .. name .. [[.counter
          end
          
          function ]] .. name .. [[.add_data(key, value)
            ]] .. name .. [[.data[key] = value
            return ]] .. name .. [[.data
          end
          
          return ]] .. name .. [[
        ]]
        
        local success, err = test_helper.with_error_capture(function()
          return fs.write_file(path, module_content)
        end)()
        
        if not success then
          firmo.log.error({ message = "Failed to create test module", module = name, path = path, error = err })
          return
        end
        table.insert(modules, {name = name, path = path})
      end
      
      -- Ensure modules can be loaded
      package.path = "/tmp/?.lua;" .. package.path
      
      -- Benchmark with module reset disabled
      local function run_without_reset()
        -- Configure to disable module reset
        firmo.module_reset.configure({
          reset_modules = false
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
          reset_modules = true
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
      
      -- Run benchmarks
      local without_reset_results = firmo.benchmark.measure(run_without_reset, nil, {
        iterations = 10,
        warmup = 2,
        label = "Without module reset"
      })
      
      local with_reset_results = firmo.benchmark.measure(run_with_reset, nil, {
        iterations = 10,
        warmup = 2,
        label = "With module reset"
      })
      
      -- Compare results
      local comparison = firmo.benchmark.compare(without_reset_results, with_reset_results)
      
      -- Clean up test modules
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
        output_dir = "/tmp/small_benchmark_tests"
      })
      
      -- Generate a larger test suite for benchmarking
      local large_suite = firmo.benchmark.generate_large_test_suite({
        file_count = 10,
        tests_per_file = 20,
        output_dir = "/tmp/large_benchmark_tests"
      })
      
      -- Function to test memory usage when running test suites
      local function run_test_suite(suite_dir, with_reset)
        -- Configure module reset
        firmo.module_reset.configure({
          reset_modules = with_reset
        })
        
        -- Get test files
        local files = {}
        local all_files, err = test_helper.with_error_capture(function()
          return fs.list_files(suite_dir)
        end)()
        
        if not all_files then
          firmo.log.error({ message = "Failed to list test files", directory = suite_dir, error = err })
          return
        end
        -- Filter to only Lua files
        for _, file in ipairs(all_files) do
          if file:match("%.lua$") then
            table.insert(files, fs.join_paths(suite_dir, file))
          end
        end
        
        -- Run each test file
        for _, file in ipairs(files) do
          firmo.reset()
          dofile(file)
        end
        
        -- Clean up
        collectgarbage("collect")
      end
      
      -- Benchmark small suite without reset
      local small_without_reset = firmo.benchmark.measure(
        run_test_suite, 
        {small_suite.output_dir, false}, 
        {label = "Small suite without reset"}
      )
      
      -- Benchmark small suite with reset
      local small_with_reset = firmo.benchmark.measure(
        run_test_suite, 
        {small_suite.output_dir, true}, 
        {label = "Small suite with reset"}
      )
      
      -- Benchmark large suite without reset
      local large_without_reset = firmo.benchmark.measure(
        run_test_suite, 
        {large_suite.output_dir, false}, 
        {label = "Large suite without reset"}
      )
      
      -- Benchmark large suite with reset
      local large_with_reset = firmo.benchmark.measure(
        run_test_suite, 
        {large_suite.output_dir, true}, 
        {label = "Large suite with reset"}
      )
      
      -- Compare results
      firmo.benchmark.compare(small_without_reset, small_with_reset)
      firmo.benchmark.compare(large_without_reset, large_with_reset)
      
      -- Clean up test files
      fs.remove_dir(small_suite.output_dir)
      fs.remove_dir(large_suite.output_dir)
      
      -- Verify memory usage is back to reasonable levels
      collectgarbage("collect")
      local final_memory = collectgarbage("count")
      
      -- Check that memory doesn't grow too much
      local memory_growth = final_memory - initial_memory
      firmo.log.info({ message = "Memory usage statistics", growth_kb = memory_growth })
      expect(memory_growth).to.be_less_than(1000) -- 1MB is a reasonable limit
    end)
  end)
  
  describe("Error handling performance", function()
    it("should measure error handling performance", { expect_error = true }, function()
      -- Only run if fixtures are available
      if not fixtures_loaded then return end
      
      -- Test error handling speed with proper error capture
      local function handle_errors()
        -- Try various error types
        local error_types = {
          "nil_access",
          "type_error",
          "custom_error",
          "assertion_error",
          "upvalue_capture_error"
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
      local error_perf = firmo.benchmark.measure(
        handle_errors, 
        nil,
        {
          iterations = 100, 
          label = "Error handling performance"
        }
      )
      
      -- Print results
      firmo.benchmark.print_result(error_perf)
      
      -- Make sure the benchmark ran successfully
      expect(error_perf.time_stats.mean).to.be_greater_than(0)
    end)
  end)
end)
