--- Firmo Parallel Test Execution Module
--- @module lib.tools.parallel
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.1

local parallel = {}
parallel._VERSION = "1.0.1"

local _error_handler, _logging, _fs
local function try_require(module_name)
  local s, r = pcall(require, module_name)
  if not s then
    print("Warning: Failed to load module:", module_name, "Error:", r)
    return nil
  end
  return r
end
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
end
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end
local function get_logger()
  local l = get_logging()
  if l then
    return l.get_logger("parallel")
  end
  return {
    error = function(...)
      print("[ERROR] parallel:", ...)
    end,
    warn = function(...)
      print("[WARN] parallel:", ...)
    end,
    info = function(...)
      print("[INFO] parallel:", ...)
    end,
    debug = function(...)
      print("[DEBUG] parallel:", ...)
    end,
    trace = function(...)
      print("[TRACE] parallel:", ...)
    end,
  }
end

local DEFAULT_CONFIG = {
  workers = 4,
  timeout = 60,
  output_buffer_size = 10240,
  verbose = false,
  show_worker_output = true,
  fail_fast = false,
  aggregate_coverage = true,
  debug = false,
}
parallel.options = {}
for k, v in pairs(DEFAULT_CONFIG) do
  parallel.options[k] = v
end
local central_config = try_require("lib.core.central_config")
local json = try_require("lib.tools.json")

if central_config then
  central_config.register_module("parallel", {
    field_types = {
      workers = "number",
      timeout = "number",
      output_buffer_size = "number",
      verbose = "boolean",
      show_worker_output = "boolean",
      fail_fast = "boolean",
      aggregate_coverage = "boolean",
      debug = "boolean",
    },
    field_ranges = { workers = { min = 1, max = 64 }, timeout = { min = 1 }, output_buffer_size = { min = 1024 } },
  }, DEFAULT_CONFIG)
end
local function register_change_listener()
  if not central_config then
    return false
  end
  central_config.on_change("parallel", function(p, ov, nv)
    get_logger().debug("Config change", { path = p })
    local pc = central_config.get("parallel")
    if pc then
      for k, v in pairs(pc) do
        if parallel.options[k] ~= nil and parallel.options[k] ~= v then
          parallel.options[k] = v
          get_logger().debug("Updated config", { key = k, value = v })
        end
      end
      if get_logging().configure_from_options then
        get_logging().configure_from_options(
          "parallel",
          { debug = parallel.options.debug, verbose = parallel.options.verbose }
        )
      end
      get_logger().debug("Applied central config changes")
    end
  end)
  get_logger().debug("Registered change listener")
  return true
end
function parallel.configure(opts)
  opts = opts or {}
  get_logger().debug("Configuring parallel", { options_passed = opts })
  local cs = central_config and central_config.get("parallel") or DEFAULT_CONFIG
  for k, dv in pairs(DEFAULT_CONFIG) do
    parallel.options[k] = cs[k] ~= nil and cs[k] or dv
  end
  if central_config then
    register_change_listener()
  end
  for k, v in pairs(opts) do
    if parallel.options[k] ~= nil then
      parallel.options[k] = v
      if central_config then
        central_config.set("parallel." .. k, v)
      end
    end
  end
  if get_logging().configure_from_options then
    get_logging().configure_from_options(
      "parallel",
      { debug = parallel.options.debug, verbose = parallel.options.verbose }
    )
  end
  get_logger().debug("Config complete", parallel.options)
  return parallel
end
parallel.configure()
parallel.firmo = nil
local Results = {}
Results.__index = Results
function Results.new()
  local s = setmetatable({}, Results)
  s.passed, s.failed, s.skipped, s.pending, s.total = 0, 0, 0, 0, 0
  s.errors, s.elapsed, s.coverage = {}, 0, {}
  s.files_run, s.worker_outputs = {}, {}
  return s
end
function Results:add_file_result(f, wr, ro)
  local rs = wr.result
  self.total = self.total + (rs.total or 0)
  self.passed = self.passed + (rs.passed or 0)
  self.failed = self.failed + (rs.failed or 0)
  self.skipped = self.skipped + (rs.skipped or 0)
  self.pending = self.pending + (rs.pending or 0)
  if wr.elapsed then
    self.elapsed = self.elapsed + wr.elapsed
  end
  table.insert(self.files_run, f)
  if ro then
    table.insert(self.worker_outputs, ro)
  end
  if rs.errors and #rs.errors > 0 then
    for _, e in ipairs(rs.errors) do
      table.insert(self.errors, { file = f, message = e.message, traceback = e.traceback })
    end
  elseif not wr.success and rs.failed > 0 then
    table.insert(self.errors, { file = f, message = "One or more tests failed." })
  end
  if rs.coverage and parallel.options.aggregate_coverage then
    for fn, fd in pairs(rs.coverage) do
      if not self.coverage[fn] then
        self.coverage[fn] = fd
      else
        if fd.lines then
          for l, c in pairs(fd.lines) do
            self.coverage[fn].lines[l] = (self.coverage[fn].lines[l] or 0) + c
          end
        end
      end
    end
  end
end

local function run_test_file(file, options)
  local cmd = "lua firmo.lua " .. file
  if options.coverage then
    cmd = cmd .. " --coverage"
  end
  if options.tags and #options.tags > 0 then
    for _, tag in ipairs(options.tags) do
      cmd = cmd .. " --tag " .. tag
    end
  end
  if options.filter then
    cmd = cmd .. ' --filter "' .. options.filter .. '"'
  end
  -- cmd = cmd .. " --results-format json --verbose" -- No longer need --results-format json here
  cmd = cmd .. " --verbose" -- Keep worker verbose for its own logs if needed

  local timeout_val = options.timeout or parallel.options.timeout or 60
  local timeout_cmd = ""
  if package.config:sub(1, 1) == "\\" then
    timeout_cmd = "timeout /T " .. timeout_val .. " /NOBREAK > NUL & "
  else
    timeout_cmd = "timeout " .. timeout_val .. " "
  end
  cmd = timeout_cmd .. cmd

  local start_time = os.clock()
  local temp_file_module = try_require("lib.tools.filesystem.temp_file")
  local worker_log_capture_path
  local worker_json_output_path

  if temp_file_module and temp_file_module.generate_temp_path then
    worker_log_capture_path = temp_file_module.generate_temp_path("parallel_worker_log_out")
    worker_json_output_path = temp_file_module.generate_temp_path("parallel_worker_json_out")
    if temp_file_module.register_temp_file then
      temp_file_module.register_temp_file(worker_log_capture_path)
      temp_file_module.register_temp_file(worker_json_output_path)
    end
  else
    get_logger().error("Temp file module not available for worker output. Using fallback names.")
    local ts = os.time()
    local rand = math.random(10000)
    worker_log_capture_path = "./parallel_worker_log_out_" .. ts .. "_" .. rand .. ".log"
    worker_json_output_path = "./parallel_worker_json_out_" .. ts .. "_" .. rand .. ".json"
    get_logger().warn("Using fallback log path: " .. worker_log_capture_path)
    get_logger().warn("Using fallback JSON path: " .. worker_json_output_path)
  end

  cmd = cmd .. ' --output-json-file "' .. worker_json_output_path .. '"' -- Pass dedicated JSON output file to worker
  cmd = cmd .. ' > "' .. worker_log_capture_path .. '" 2>&1' -- Redirect worker stdout/stderr to log capture file

  if options.verbose or parallel.options.verbose then
    get_logger().debug("Executing worker command", { command = cmd, file = file })
  end

  local exit_code = os.execute(cmd)
  local elapsed = os.clock() - start_time

  local worker_log_output = ""
  local fs_module = get_fs()
  if fs_module and fs_module.read_file then
    local content, err_read = fs_module.read_file(worker_log_capture_path)
    if content then
      worker_log_output = content
    else
      get_logger().warn("Failed to read worker log capture file", { path = worker_log_capture_path, error = err_read })
    end
  else
    get_logger().error("Filesystem module not available for reading worker log output.", { path = worker_log_capture_path })
  end

  local json_data_str
  if fs_module and fs_module.read_file then
    json_data_str, err_read = fs_module.read_file(worker_json_output_path)
    if not json_data_str then
      get_logger().warn("Failed to read worker JSON output file (or file is empty).", { path = worker_json_output_path, error = err_read })
    end
  else
     get_logger().error("Filesystem module not available for reading worker JSON output.", { path = worker_json_output_path })
  end

  -- Cleanup non-managed fallback files if they were created
  if not (temp_file_module and temp_file_module.is_registered and temp_file_module.is_registered(worker_log_capture_path)) then
    if fs_module and fs_module.delete_file then fs_module.delete_file(worker_log_capture_path) end
  end
  if not (temp_file_module and temp_file_module.is_registered and temp_file_module.is_registered(worker_json_output_path)) then
    if fs_module and fs_module.delete_file then fs_module.delete_file(worker_json_output_path) end
  end

  get_logger().debug("Worker log output for file: " .. file, { output_length = #worker_log_output })

  local result_summary = {
    total = 0, passed = 0, failed = 0, skipped = 0, pending = 0,
    errors = {}, elapsed = elapsed, success = (exit_code == 0 or exit_code == true),
  }

  if json and json_data_str and #json_data_str > 0 then
    local decoded_json, decode_err = json.decode(json_data_str)
    if decoded_json then
      get_logger().debug("Successfully decoded JSON from worker's dedicated file.", { file = file })
      result_summary.passed = tonumber(decoded_json.passes) or tonumber(decoded_json.passed_count) or 0
      result_summary.failed = tonumber(decoded_json.errors) or tonumber(decoded_json.failed_count) or 0
      result_summary.skipped = tonumber(decoded_json.skipped) or tonumber(decoded_json.skipped_count) or 0
      if decoded_json.total and tonumber(decoded_json.total) then
        result_summary.total = tonumber(decoded_json.total)
      else
        result_summary.total = (result_summary.passed + result_summary.failed + result_summary.skipped)
      end
      result_summary.success = (result_summary.failed == 0) -- Override success based on test failures
      if decoded_json.error_details and type(decoded_json.error_details) == "table" then
        result_summary.errors = decoded_json.error_details
      end
      if not (result_summary.total > 0 or result_summary.passed > 0 or result_summary.failed > 0 or result_summary.skipped > 0) then
         get_logger().debug("JSON decoded but reported zero tests. Worker log might have details.", { file = file })
      end
    else
      get_logger().warn("Failed to decode JSON from worker's dedicated file.", {
        file = file, error_msg = decode_err and (decode_err.message or tostring(decode_err)) or "Unknown decode error",
        json_preview = json_data_str:sub(1,100)
      })
      -- No text parsing fallback here as JSON file should be definitive or empty/error
      result_summary.success = false -- Assume failure if JSON was expected but failed to parse
      table.insert(result_summary.errors, {message = "Failed to parse JSON results from worker: " .. (decode_err and decode_err.message or "Unknown")})
    end
  else
    get_logger().warn("No JSON data found in worker's dedicated output file or JSON module not loaded.", { file = file, json_module_loaded = json ~= nil })
    result_summary.success = false -- Assume failure if no JSON data file
    table.insert(result_summary.errors, {message = "Worker did not produce a valid JSON output file."})
  end

  -- Final success state based on parsed results, if any test was counted
  if result_summary.total > 0 then
    result_summary.success = (result_summary.failed == 0)
  -- If no tests were counted but exit_code indicated an error, maintain failure
  elseif not (exit_code == 0 or exit_code == true) then
    result_summary.success = false
  end

  return { result = result_summary, output = worker_log_output, elapsed = elapsed, success = result_summary.success }
end

function parallel.run_tests(files, options_override)
  local eo = {}
  for k, v in pairs(parallel.options) do
    eo[k] = v
  end
  if options_override then
    for k, v in pairs(options_override) do
      eo[k] = v
    end
  end
  get_logger().info(
    "Starting parallel test execution",
    { file_count = #files, worker_count = eo.workers, timeout = eo.timeout, fail_fast = eo.fail_fast }
  )
  local results = Results.new()
  local ost = os.clock()
  if #files == 0 then
    get_logger().warn("No files to run.")
    results.elapsed = os.clock() - ost
    return results
  end
  for i, fp in ipairs(files) do
    if eo.verbose then
      io.write("Processing file (" .. i .. "/" .. #files .. "): " .. fp .. "\n")
    end
    local wo =
      { coverage = eo.coverage, tags = eo.tags, filter = eo.filter, timeout = eo.timeout, verbose = eo.verbose }
    local wrr = run_test_file(fp, wo)
    results:add_file_result(fp, wrr, wrr.output)
    if eo.show_worker_output and wrr.output then
      io.write("\n--- Output from " .. fp .. " ---\n" .. wrr.output .. "--- End output from " .. fp .. " ---\n\n")
    end
    if not wrr.success and eo.fail_fast then
      get_logger().warn("Fail fast triggered.", { file = fp })
      break
    end
  end
  results.elapsed = os.clock() - ost
  get_logger().info("Parallel-style execution finished.", { total_elapsed = results.elapsed })
  return results
end
function parallel.register_with_firmo(fi)
  parallel.firmo = fi
  if fi then
    fi.parallel = parallel
  end
  get_logger().info("Parallel module registered with firmo.")
  return parallel
end
function parallel.reset()
  get_logger().debug("Resetting parallel local config.")
  for k, v in pairs(DEFAULT_CONFIG) do
    parallel.options[k] = v
  end
  if get_logging().configure_from_options then
    get_logging().configure_from_options(
      "parallel",
      { debug = parallel.options.debug, verbose = parallel.options.verbose }
    )
  end
  return parallel
end
function parallel.full_reset()
  parallel.reset()
  if central_config and central_config.reset then
    central_config.reset("parallel")
    get_logger().debug("Reset central config for parallel.")
  end
  return parallel
end
function parallel.debug_config()
  local di = {
    local_config = {},
    using_central_config = central_config ~= nil,
    central_config_values = central_config and central_config.get("parallel") or nil,
  }
  for k, v in pairs(parallel.options) do
    di.local_config[k] = v
  end
  get_logger().info("Parallel module current config", di)
  return di
end
return parallel
