---@class QualityModule The public API of the test quality validation module.
---@field _VERSION string Module version (following semantic versioning).
---@field LEVEL_BASIC number Quality level 1: Basic validation with minimal assertions.
---@field LEVEL_STRUCTURED number Quality level 2: Structured tests with multiple assertion types.
---@field LEVEL_COMPREHENSIVE number Quality level 3: Comprehensive tests with error handling and setup/teardown.
---@field LEVEL_ADVANCED number Quality level 4: Advanced tests with specialized assertions and complete test coverage.
---@field LEVEL_COMPLETE number Quality level 5: Complete tests with all assertion types and thorough validation.
---@field levels table<number, {level: number, name: string, description: string, requirements: table}> Array defining quality levels and their requirements (loaded from `level_checkers`).
---@field stats {tests_analyzed: number, tests_passing_quality: number, assertions_total: number, assertions_per_test_avg: number, quality_level_achieved: number, assertion_types_found: table<string, number>, test_organization_score: number, required_patterns_score: number, forbidden_patterns_score: number, coverage_score: number, issues: table<{test: string, issue: string}>[]} Statistics collected during quality analysis.
---@field config {enabled: boolean, level: number, strict: boolean, custom_rules?: table, coverage_data?: table|nil, debug?: boolean, verbose?: boolean} Configuration settings for the quality module.
---@field init fun(self: QualityModule, options?: {enabled?: boolean, level?: number, strict?: boolean, custom_rules?: table, coverage_data?: table, debug?: boolean, verbose?: boolean}): QualityModule Initializes the quality module. Returns self.
---@field reset fun(self: QualityModule): QualityModule Resets quality statistics while preserving configuration. Returns self.
---@field full_reset fun(self: QualityModule): QualityModule Performs a full reset including configuration. Returns self.
---@field get_level_requirements fun(self: QualityModule, level?: number): table Returns the requirements table for the specified level (defaults to configured level).
---@field track_assertion fun(self: QualityModule, type_name: string, test_name?: string): QualityModule Tracks an assertion usage for the current test. Returns self.
---@field start_test fun(self: QualityModule, test_name: string, context_opts?: {has_describe?: boolean, has_it?: boolean, nesting_level?: number, has_before_after?: boolean}): QualityModule Starts analysis for a specific test. Returns self.
---@field end_test fun(self: QualityModule): QualityModule Ends analysis for the current test and evaluates its quality. Returns self.
---@field track_spy_created fun(self: QualityModule, spy_identifier: string|number): QualityModule Tracks the creation of a spy.
---@field track_spy_restored fun(self: QualityModule, spy_identifier: string|number): QualityModule Tracks the restoration of a spy.
---@field start_describe fun(self: QualityModule, describe_name: string): QualityModule Marks the start of a describe block for quality tracking, fetching file_path internally.
---@field end_describe fun(self: QualityModule): QualityModule Marks the end of the current describe block and checks for emptiness.
---@field analyze_file fun(self: QualityModule, file_path: string): table Performs static analysis on a file for structural properties; dynamic tracking is used for assertions. Returns analysis results.
---@field get_report_data fun(self: QualityModule): {report_type: "quality", level: number, level_name: string, tests: table<string, table>, summary: {tests_analyzed: number, tests_passing_quality: number, quality_percent: number, assertions_total: number, assertions_per_test_avg: number, assertion_types_found: table<string, number>, issues: table<{test: string, issue: string}>[]}} Gets structured data for reporting.
---@field report fun(self: QualityModule, format?: string): string|table Generates a quality report. @throws table If reporting module fails.
---@field summary_report fun(self: QualityModule): {level: number, level_name: string, tests_analyzed: number, tests_passing_quality: number, quality_pct: number, assertions_total: number, assertions_per_test_avg: number, assertion_types_found: table<string, number>, issues: table<{test: string, issue: string}>[], tests: table} Generates a concise summary report.
---@field level_name fun(level: number): string Gets the descriptive name for a quality level (alias for `get_level_name`).
---@field set_level fun(self: QualityModule, level: number): QualityModule [Not Implemented] Set the current quality validation level.
---@field get_level fun(): number [Not Implemented] Get the current quality validation level.
---@field analyze_directory fun(dir_path: string, recursive?: boolean): table|nil, table? [Not Implemented] Analyze all test files in a directory.
---@field register_assertion_type fun(self: QualityModule, type_name: string, description: string): QualityModule [Not Implemented] Register a custom assertion type.
---@field is_quality_passing fun(): boolean [Not Implemented] Check if tests meet the current quality level requirements.
---@field get_score fun(): number [Not Implemented] Get the quality score as percentage (0-100).
---@field add_custom_requirement fun(self: QualityModule, name: string, check_fn: function, min_value?: number): QualityModule [Not Implemented] Add a custom quality requirement.
---@field json_report fun(): string [Not Implemented] Generate a detailed JSON report.
---@field html_report fun(): string [Not Implemented] Generate a formatted HTML report.
---@field meets_level fun(self: QualityModule, level?: number): boolean Checks if quality metrics meet a specific level requirement.
---@field save_report fun(self: QualityModule, file_path: string, format?: string): boolean, string|nil Saves a quality report to a file. Returns `success, error?`. @throws table If reporting fails critically.
---@field get_level_name fun(level: number): string Gets the descriptive name for a quality level number (e.g., "basic", "standard", "Not Assessed").
---@field check_file fun(self: QualityModule, file_path: string, level?: number): boolean, table[] Checks if a test file meets quality requirements. Returns `meets, issues`. @throws table If level checker fails critically.
---@field validate_test_quality fun(self: QualityModule, test_name: string, options?: {level?: number, strict?: boolean}): boolean, table[] Validates a specific test against quality standards. Returns `meets, issues`.
---@field debug_config fun(self: QualityModule): QualityModule Prints debug information about the current configuration. Returns self.
---@field create_test_file fun(level: number, file_path?: string): string, string? [Not Implemented] Create a template test file.

--- Firmo Test Quality Validation Module
--- @module lib.quality
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

local _logging, _fs
local function try_require(module_name)
  local s, r = pcall(require, module_name)
  if not s then
    print("Warning: Failed to load module:", module_name, "Error:", r)
    return nil
  end
  return r
end

--- Get the filesystem module with lazy loading to avoid circular dependencies
---@return table|nil The filesystem module or nil if not available
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
end

--- Get the logging module with lazy loading to avoid circular dependencies
---@return table|nil The logging module or nil if not available
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end

--- Get a logger instance for this module
---@return table A logger instance (either real or stub)
local function get_logger()
  local l = get_logging()
  if l then
    return l.get_logger("quality")
  end
  return {
    error = function(...)
      print("[ERROR] quality:", ...)
    end,
    warn = function(...)
      print("[WARN] quality:", ...)
    end,
    info = function(...)
      print("[INFO] quality:", ...)
    end,
    debug = function(...)
      print("[DEBUG] quality:", ...)
    end,
    trace = function(...)
      print("[TRACE] quality:", ...)
    end,
  }
end
local level_checkers = try_require("lib.quality.level_checkers")
local central_config = try_require("lib.core.central_config")

local M = {}
M.LEVEL_BASIC, M.LEVEL_STRUCTURED, M.LEVEL_COMPREHENSIVE, M.LEVEL_ADVANCED, M.LEVEL_COMPLETE = 1, 2, 3, 4, 5
M.levels = {
  { level = 1, name = "basic", description = "Basic tests", requirements = level_checkers.get_level_requirements(1) },
  {
    level = 2,
    name = "standard",
    description = "Standard tests",
    requirements = level_checkers.get_level_requirements(2),
  },
  {
    level = 3,
    name = "comprehensive",
    description = "Comprehensive tests",
    requirements = level_checkers.get_level_requirements(3),
  },
  {
    level = 4,
    name = "advanced",
    description = "Advanced tests",
    requirements = level_checkers.get_level_requirements(4),
  },
  {
    level = 5,
    name = "complete",
    description = "Complete tests",
    requirements = level_checkers.get_level_requirements(5),
  },
}
local current_test, test_data, active_spies, describe_context_stack = nil, {}, {}, {}
M.stats = {
  tests_analyzed = 0,
  tests_passing_quality = 0,
  assertions_total = 0,
  assertions_per_test_avg = 0,
  quality_level_achieved = 0,
  assertion_types_found = {},
  test_organization_score = 0,
  required_patterns_score = 0,
  forbidden_patterns_score = 0,
  coverage_score = 0,
  issues = {},
}
local DEFAULT_CFG = { enabled = false, level = 1, strict = false, custom_rules = {}, coverage_data = nil }
M.config = {}
for k, v in pairs(DEFAULT_CFG) do
  M.config[k] = v
end

--- Registers a listener with central_config to update local config cache when quality settings change.
---@return nil
---@private
local function register_change_listener()
  if not central_config then
    return false
  end
  central_config.on_change("quality", function(p, ov, nv)
    get_logger().debug("Quality config changed", { path = p })
    local qc = central_config.get("quality")
    if qc then
      for k, v in pairs(qc) do
        M.config[k] = v
      end
    end
    get_logger().debug(
      "Config updated from central",
      { enabled = M.config.enabled, level = M.config.level, strict = M.config.strict }
    )
  end)
  get_logger().debug("Registered change listener for quality config")
end

--- Initializes the quality module with specified options, overriding defaults and central configuration values.
--- Registers a change listener if central configuration is available. Connects to coverage module if loaded.
---@param options? {enabled?: boolean, level?: number, strict?: boolean, custom_rules?: table, coverage_data?: table, debug?: boolean, verbose?: boolean} Configuration options. `coverage_data` should be the coverage module instance if provided. If `options` is provided but not a table, it will be ignored.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.init(opts)
  local cfg_src = central_config and central_config.get("quality") or DEFAULT_CFG
  for k, dv in pairs(DEFAULT_CFG) do
    M.config[k] = cfg_src[k] ~= nil and cfg_src[k] or dv
  end
  if central_config then
    register_change_listener()
  end
  opts = opts or {}
  if type(opts) == "table" then
    local oc = 0
    for _ in pairs(opts) do
      oc = oc + 1
    end
    get_logger().debug("Applying user options", { opt_count = oc })
    for k, v in pairs(opts) do
      M.config[k] = v
    end
    if central_config then
      for k, v in pairs(opts) do
        central_config.set("quality." .. k, v)
      end
    end
  end
  get_logger().debug("Quality init complete", { enabled = M.config.enabled, level = M.config.level })
  if package.loaded["lib.coverage"] then
    get_logger().debug("Connected to coverage module")
    M.config.coverage_data = package.loaded["lib.coverage"]
  else
    get_logger().debug("Coverage module not available")
  end
  M.reset()
  return M
end

--- Resets the collected quality statistics (`M.stats`, `test_data`, `current_test`, `file_cache`)
--- while preserving the current configuration (`M.config`).
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.reset()
  get_logger().debug("Resetting quality state")
  M.stats = {
    tests_analyzed = 0,
    tests_passing_quality = 0,
    assertions_total = 0,
    assertions_per_test_avg = 0,
    quality_level_achieved = 0,
    assertion_types_found = {},
    test_organization_score = 0,
    required_patterns_score = 0,
    forbidden_patterns_score = 0,
    coverage_score = 0,
    issues = {},
  }
  test_data, current_test, active_spies, describe_context_stack = {}, nil, {}, {}
  return M
end

--- Performs a full reset: resets statistics (via `M.reset()`) and resets the module's
--- configuration (`M.config`) back to the defaults (potentially reloading from central config).
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.full_reset()
  M.reset()
  if central_config then
    central_config.reset("quality")
    local cv = central_config.get("quality")
    if cv then
      for k, v in pairs(cv) do
        M.config[k] = v
      end
    else
      for k, v in pairs(DEFAULT_CFG) do
        M.config[k] = v
      end
    end
    get_logger().debug("Reset central config for quality")
  else
    for k, v in pairs(DEFAULT_CFG) do
      M.config[k] = v
    end
  end
  return M
end

--- Gets the requirements table for a specific quality level.
---@param level? number The quality level number (1-5). Defaults to the currently configured `M.config.level`.
---@return table requirements The requirements table for the specified level (defaults to Level 1 if level is invalid).
function M.get_level_requirements(l)
  l = l or M.config.level
  for _, ld in ipairs(M.levels) do
    if ld.level == l then
      return ld.requirements
    end
  end
  return M.levels[1].requirements
end

--- Evaluates a test against all quality levels (1-5) to determine the highest level passed.
--- Uses level_checkers module for actual evaluation logic.
---@param ti table The test data structure to evaluate. This table will be updated with issues.
---@return {level: number, scores: table<number, number>} result The highest level passed and scores achieved at each level.
---@private
local function eval_test_qual(ti)
  if not level_checkers then
    get_logger().error("level_checkers module missing")
    ti.issues = ti.issues or {}
    table.insert(ti.issues, "Internal error: Level checkers missing.")
    return { level = 0, scores = {} }
  end
  local ml = #M.levels
  local hpl = 0
  local scrs = {}
  ti.issues = ti.issues or {}
  local cd = M.config.coverage_data
  for ln = 1, ml do
    local cf = level_checkers.get_level_checker(ln)
    if cf then
      local evr = cf(ti, cd)
      scrs[ln] = evr.score
      if not evr.passes and evr.issues and #evr.issues > 0 then
        for _, iss in ipairs(evr.issues) do
          local dupe = false
          for _, ei in ipairs(ti.issues) do
            if ei == iss then
              dupe = true
              break
            end
          end
          if not dupe then
            table.insert(ti.issues, iss)
          end
        end
      end
      if evr.passes then
        hpl = ln
      else
        if M.config.strict and ln <= M.config.level then
          get_logger().debug("Strict mode: stopping at failed level", { level = ln, target = M.config.level })
          break
        end
        break
      end
    else
      get_logger().warn("No checker for level", { level = ln })
    end
  end
  return { level = hpl, scores = scrs }
end
local act_map = {
  equal = "equality",
  deep_equal = "equality",
  be = "equality",
  at_least = "equality",
  greater_than = "equality",
  be_greater_than = "equality",
  less_than = "equality",
  be_less_than = "equality",
  match = "equality",
  match_regex = "equality",
  match_with_options = "equality",
  contain = "equality",
  have = "equality",
  fully = "equality",
  any_of = "equality",
  all_of = "equality",
  start_with = "equality",
  end_with = "equality",
  negative = "equality",
  uppercase = "equality",
  lowercase = "equality",
  be_near = "equality",
  be_approximately = "equality",
  be_before = "equality",
  be_after = "equality",
  be_same_day_as = "equality",
  be_between_dates = "equality",
  exist = "truth",
  ["nil"] = "truth",
  be_nil = "truth",
  truthy = "truth",
  be_truthy = "truth",
  falsy = "truth",
  be_falsy = "truth",
  be_falsey = "truth",
  type = "type_checking",
  a = "type_checking",
  an = "type_checking",
  is_exact_type = "type_checking",
  is_instance_of = "type_checking",
  implement_interface = "type_checking",
  have_length = "type_checking",
  have_size = "type_checking",
  have_property = "type_checking",
  keys = "type_checking",
  key = "type_checking",
  deep_key = "type_checking",
  exact_keys = "type_checking",
  match_schema = "type_checking",
  integer = "type_checking",
  be_date = "type_checking",
  be_iso_date = "type_checking",
  be_type = "type_checking",
  fail = "error_handling",
  with = "error_handling",
  throw = "error_handling",
  error = "error_handling",
  error_matching = "error_handling",
  error_type = "error_handling",
  reject = "error_handling",
  change = "other",
  increase = "other",
  decrease = "other",
  complete = "other",
  complete_within = "other",
  resolve_with = "other",
  satisfy = "other",
}

--- Tracks the usage of an assertion type within the currently active test (`current_test`).
--- Increments assertion counts and categorizes the assertion type based on `action_name`.
--- This function is called dynamically from the assertion module (`lib/assertion/init.lua`).
---@param action_name string The action name from the assertion (e.g., "equal", "exist", "be_a"). Must be a non-empty string.
---@param test_name_override? string Optional name of the test; used if `current_test` is nil (should be rare with dynamic tracking).
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.track_assertion(act_name, test_name_ovr)
  if not (act_name and type(act_name) == "string" and act_name ~= "") then
    get_logger().warn("Invalid action_name for track_assertion", { action = act_name })
    return M
  end
  if not M.config.enabled then
    return M
  end
  if not current_test then
    get_logger().error("CRITICAL: track_assertion called but current_test is nil!", { action = act_name })
    return M
  end
  if not test_data[current_test] then
    get_logger().error("CRITICAL: current_test set, but test_data is nil.", { test = current_test, action = act_name })
    return M
  end
  test_data[current_test].assertion_count = (test_data[current_test].assertion_count or 0) + 1
  local cat = act_map[act_name]
  test_data[current_test].assertion_types = test_data[current_test].assertion_types or {}
  if cat then
    test_data[current_test].assertion_types[cat] = (test_data[current_test].assertion_types[cat] or 0) + 1
  else
    get_logger().warn("Unknown assertion action for categorization", { action = act_name, test = current_test })
    test_data[current_test].assertion_types.other = (test_data[current_test].assertion_types.other or 0) + 1
  end
  return M
end

--- Marks the start of analysis for a specific test.
--- Initializes the test data structure (`test_data[test_name]`) if it doesn't exist.
--- Records the `test_name` as the `current_test`. Stores `file_path` if `runtime.current_test_file` is set in `central_config`.
--- Uses `context_opts` to set structural properties like `has_describe`, `has_it`, `nesting_level`.
---@param test_name string The name of the test starting. If `nil`, not a string, or empty, it defaults to "unnamed_test".
---@param context_opts? {has_describe?: boolean, has_it?: boolean, nesting_level?: number, has_before_after?: boolean} Optional context from the test runner.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.start_test(tn, ctx_opts)
  ctx_opts = ctx_opts or {}
  if not (tn and type(tn) == "string" and tn ~= "") then
    get_logger().warn("Invalid test_name for start_test", { name = tn })
    tn = "unnamed_test"
  end
  if not M.config.enabled then
    return M
  end
  get_logger().debug("Starting test analysis", { test = tn })
  current_test = tn
  if #describe_context_stack > 0 then
    local dctx = describe_context_stack[#describe_context_stack]
    dctx.direct_it_blocks_found = dctx.direct_it_blocks_found + 1
  end
  if not test_data[current_test] then
    local cfile = central_config and central_config.get("runtime.current_test_file") or nil
    if cfile and cfile ~= "" and cfile ~= "unknown_file" and cfile ~= "unknown_file_from_describe_fallback" then
      for _, d_ctx in ipairs(describe_context_stack) do
        if d_ctx.file_path == "unknown_file_from_describe_fallback" or d_ctx.file_path == "unknown_file" then
          d_ctx.file_path = cfile
        end
      end
    end
    test_data[current_test] = {
      name = tn,
      file_path = cfile,
      assertion_count = 0,
      assertion_types = {},
      has_describe = ctx_opts.has_describe or false,
      has_it = ctx_opts.has_it or false,
      has_proper_name = (tn and tn ~= "" and tn ~= "unnamed_test" and (tn:match("should") or tn:match("when"))),
      has_before_after = ctx_opts.has_before_after or false,
      nesting_level = ctx_opts.nesting_level or 1,
      has_mock_verification = false,
      has_performance_tests = false,
      has_security_tests = false,
      unrestored_spies_found = false,
      patterns_found = {},
      issues = {},
      quality_level = 0,
    }
    active_spies = {}
    if tn then
      if tn:match("should") then
        test_data[current_test].patterns_found["should"] = true
      end
      if tn:match("when") then
        test_data[current_test].patterns_found["when"] = true
      end
      local fp = {}
      for pt, pl in pairs({}) do
        for _, p in ipairs(pl) do
          if contains_pattern(tn, p) then
            test_data[current_test].patterns_found[pt] = true
            table.insert(fp, pt)
            if pt == "performance" then
              test_data[current_test].has_performance_tests = true
            elseif pt == "security" then
              test_data[current_test].has_security_tests = true
            end
          end
        end
      end
    end
  end
  return M
end

--- Marks the end of analysis for the `current_test`.
--- Evaluates the completed test's quality level using an internal `evaluate_test_quality` function,
--- which in turn relies on the `lib.quality.level_checkers` module.
--- Updates global statistics (`M.stats`) based on the test's results. Resets `current_test` to nil.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.end_test()
  if not M.config.enabled or not current_test then
    current_test = nil
    return M
  end
  get_logger().debug("Ending test analysis", { test = current_test })
  if next(active_spies) ~= nil then
    if test_data[current_test] then
      test_data[current_test].unrestored_spies_found = true
      local uris = {}
      for id, _ in pairs(active_spies) do
        table.insert(uris, tostring(id))
      end
      get_logger().warn("Unrestored spies detected", { test = current_test, ids = table.concat(uris, ", ") })
    else
      get_logger().error("Cannot mark unrestored spies: no test_data", { test = current_test })
    end
  end
  local ev = eval_test_qual(test_data[current_test])
  test_data[current_test].quality_level = ev.level
  test_data[current_test].scores = ev.scores
  get_logger().debug("Test quality eval complete", {
    test = current_test,
    level = ev.level,
    passing = ev.level >= M.config.level,
    issues = #test_data[current_test].issues,
    assertions = test_data[current_test].assertion_count,
  })
  M.stats.tests_analyzed = M.stats.tests_analyzed + 1
  M.stats.assertions_total = M.stats.assertions_total + test_data[current_test].assertion_count
  if test_data[current_test].quality_level >= M.config.level then
    M.stats.tests_passing_quality = M.stats.tests_passing_quality + 1
  else
    for _, iss in ipairs(test_data[current_test].issues) do
      table.insert(M.stats.issues, { test = current_test, issue = iss })
    end
  end
  for at, cnt in pairs(test_data[current_test].assertion_types) do
    M.stats.assertion_types_found[at] = (M.stats.assertion_types_found[at] or 0) + cnt
  end
  current_test = nil
  return M
end

--- Performs static analysis on a test file to identify its structural properties like describe/it blocks, hooks, and nesting levels.
--- Assertion counting and type analysis, which were previously part of static analysis, are now primarily handled dynamically via `M.track_assertion`
--- (called from `lib/assertion/init.lua`) for greater accuracy during actual test execution.
--- This function still plays a role in understanding test structure for quality evaluation.
--- **Important:** This function calls `M.start_test` and `M.end_test` internally for each test (`it` block) it discovers via parsing its content.
--- If `analyze_file` is called on a file that is *also* being run through the normal test execution flow (where `lib/core/test_definition.lua`
--- also calls `M.start_test`/`M.end_test`), tests from that file might be processed twice by the quality module, potentially leading
--- to duplicated entries in `test_data` or skewed aggregate statistics if not handled carefully by the calling context.
--- The current primary use of `analyze_file` is in contexts where dynamic execution data might not be available or for supplementary structural checks.
--- tests might be processed twice, potentially affecting aggregated statistics. This behavior may be revised in the future.
---@param file_path string The path to the test file.
---@return table analysis A table containing the analysis results for the file (tests found, counts, overall file quality_level, etc.).
function M.analyze_file(fp)
  if not M.config.enabled then
    return {}
  end
  get_logger().debug("Analyzing file", { file = fp })
  local lns = read_file(fp)
  local res = {
    file = fp,
    tests = {},
    has_describe = false,
    has_it = false,
    has_before_after = false,
    nesting_level = 0,
    issues = {},
    quality_level = 0,
  }
  local cdn = 0
  local mno = 0
  for i, ln in ipairs(lns) do
    if ln:match("describe%s*%(") then
      res.has_describe = true
      cdn = cdn + 1
      mno = math.max(mno, cdn)
    elseif ln:match("end%)") and not ln:match("%S") then
      if cdn > 0 then
        cdn = cdn - 1
      end
    end
    if ln:match("before%s*%(") or ln:match("after%s*%(") then
      res.has_before_after = true
    end
    local itm = ln:match("it%s*%(%s*[\"'](.+)[\"']")
    if itm then
      res.has_it = true
      local tn = itm
      table.insert(res.tests, { name = tn, start_line = i, end_line = -1, nesting_level = cdn })
    end
  end
  res.nesting_level = mno
  get_logger().debug("Static analysis summary", {
    file = fp,
    tests = #res.tests,
    has_describe = res.has_describe,
    has_it = res.has_it,
    max_nesting = res.nesting_level,
  })
  for _, ti_s in ipairs(res.tests) do
    M.start_test(ti_s.name, {
      has_describe = res.has_describe,
      has_it = res.has_it,
      nesting_level = ti_s.nesting_level,
      has_before_after = res.has_before_after,
    })
    M.end_test()
  end
  local mql = 5
  local fac = 0
  for _, ti_s in ipairs(res.tests) do
    if test_data[ti_s.name] then
      mql = math.min(mql, test_data[ti_s.name].quality_level)
      fac = fac + 1
    end
  end
  res.quality_level = fac > 0 and mql or 0
  get_logger().debug("File analysis complete", { file = fp, quality = res.quality_level, tests_analyzed = fac })
  return res
end

--- Gets structured data representing the quality analysis results, suitable for generating reports.
--- Calculates final summary statistics before returning the data.
---@return {report_type: "quality", level: number, level_name: string, tests: table<string, table>, summary: {tests_analyzed: number, tests_passing_quality: number, quality_percent: number, assertions_total: number, assertions_per_test_avg: number, assertion_types_found: table<string, number>, issues: table<{test: string, issue: string}>[]}} report_data Structured data suitable for generating reports. The `tests` field is a map of test names to their detailed `QualityTestInfo` (structure similar to `lib.quality.level_checkers.QualityTestInfo`). The `summary.issues` array contains objects with `test` (name) and `issue` (string description).
function M.get_report_data()
  get_logger().debug("Generating quality report data")
  local tt = M.stats.tests_analyzed
  if tt > 0 then
    M.stats.assertions_per_test_avg = M.stats.assertions_total / tt
    local ml = 5
    for _, ti in pairs(test_data) do
      ml = math.min(ml, ti.quality_level)
    end
    M.stats.quality_level_achieved = ml
  else
    M.stats.quality_level_achieved = 0
  end
  local qp = M.stats.tests_analyzed > 0 and (M.stats.tests_passing_quality / M.stats.tests_analyzed * 100) or 0
  return {
    report_type = "quality",
    level = M.stats.quality_level_achieved,
    level_name = M.get_level_name(M.stats.quality_level_achieved),
    tests = test_data,
    summary = {
      tests_analyzed = M.stats.tests_analyzed,
      tests_passing_quality = M.stats.tests_passing_quality,
      quality_percent = qp,
      assertions_total = M.stats.assertions_total,
      assertions_per_test_avg = M.stats.assertions_per_test_avg,
      assertion_types_found = M.stats.assertion_types_found,
      issues = M.stats.issues,
    },
  }
end

--- Generate a quality report in the specified format
--- This function generates a formatted quality report using the reporting module.
--- If the reporting module is not available, it returns the raw quality data structure.
---
--- -- Generate a JSON report
--- local json_data = quality.report("json")
---
--- -- Generate an HTML report
--- local html = quality.report("html")
--- fs.write_file("quality-report.html", html)
---@param format? "summary"|"json"|"html" The format for the report (default is based on central_config)
---@return string|table report The formatted quality report (string for "summary", "html"; table for "json"), or the raw report data table if the reporting module or formatting fails.
---@throws table If the reporting module cannot be loaded or if formatting fails critically (errors wrapped by `pcall` are returned as the raw data table).
function M.report(fmt)
  local df = "summary"
  if central_config then
    local cf = central_config.get("reporting.formats.quality.default")
    if cf then
      df = cf
    end
  end
  fmt = fmt or df
  local d = M.get_report_data()
  local rm = try_require("lib.reporting")
  if not (rm and rm.format_quality and type(rm.format_quality) == "function") then
    get_logger().error("Reporting module missing format_quality", { module = "lib.reporting", format = fmt })
    return d
  end
  local fs, fr = pcall(function()
    return rm.format_quality(d, fmt)
  end)
  if fs then
    return fr
  else
    get_logger().error("Failed to format quality report", { error = tostring(fr), format = fmt })
    return d
  end
end

--- Generates a simplified summary report containing key quality metrics.
--- Calls `get_report_data` internally.
---@return {level: number, level_name: string, tests_analyzed: number, tests_passing_quality: number, quality_pct: number, assertions_total: number, assertions_per_test_avg: number, assertion_types_found: table<string, number>, issues: table<{test: string, issue: string}>[], tests: table} report A table containing summary statistics and detailed test results.
function M.summary_report()
  local d = M.get_report_data()
  return {
    level = d.level,
    level_name = d.level_name,
    tests_analyzed = d.summary.tests_analyzed,
    tests_passing_quality = d.summary.tests_passing_quality,
    quality_pct = d.summary.quality_percent,
    assertions_total = d.summary.assertions_total,
    assertions_per_test_avg = d.summary.assertions_per_test_avg,
    assertion_types_found = d.summary.assertion_types_found,
    issues = d.summary.issues,
    tests = d.tests,
  }
end

--- Checks if the overall achieved quality level (`M.stats.quality_level_achieved`)
--- meets or exceeds a specified required level.
---@param level? number The quality level to check against (1-5). Defaults to the currently configured `M.config.level`.
---@return boolean meets `true` if the achieved level is greater than or equal to the required level, `false` otherwise.
function M.meets_level(l)
  l = l or M.config.level
  local r = M.summary_report()
  local meets = r.level >= l
  get_logger().debug("Quality level check", { achieved = r.level, required = l, meets = meets })
  return meets
end

--- Save a quality report to a file in the specified format
--- This function generates a quality report and saves it to the specified file path.
--- It uses the reporting module to handle formatting and file output. The function
--- applies central configuration settings for default format and path templates.
---
---@param file_path string The path where to save the quality report
---@param format? "summary"|"json"|"html" The format for the report (default from central_config)
---@return boolean success `true` if the report was successfully generated and saved, `false` otherwise.
---@return string|nil error An error message string if saving failed, `nil` on success.
---@throws table If the reporting module cannot be loaded or if saving fails critically (errors wrapped by `pcall` are returned as `false, error_message`).
function M.save_report(fp, fmt)
  local df = "html"
  if central_config then
    local cf = central_config.get("reporting.formats.quality.default")
    if cf then
      df = cf
    end
    local rpt = central_config.get("reporting.templates.quality")
    if rpt and not fp then
      local ts = os.date("%Y-%m-%d-%H-%M-%S")
      fp = rpt:gsub("{timestamp}", ts):gsub("{format}", fmt or df)
    end
  end
  fmt = fmt or df
  local d = M.get_report_data()
  get_logger().debug("Saving quality report", { file = fp, format = fmt })
  local rm = try_require("lib.reporting")
  if not (rm and rm.save_quality_report and type(rm.save_quality_report) == "function") then
    get_logger().error("Reporting module missing save_quality_report", { module = "lib.reporting", format = fmt })
    return false, "Reporting module does not support quality saving"
  end
  local ss, se = pcall(function()
    return rm.save_quality_report(fp, d, fmt)
  end)
  if ss then
    return true
  else
    get_logger().error("Failed to save quality report", { file = fp, error = tostring(se), format = fmt })
    return false, "Failed to save: " .. tostring(se)
  end
end

--- Get the descriptive name for a quality level
--- This function returns the human-readable name for a numeric quality level
--- (e.g., "basic", "standard", "comprehensive", etc.)
---
---@param level number The quality level number (1-5)
---@return string level_name The name of the quality level
---
---@usage
--- local name = quality.get_level_name(3)
--- print(name) -- "comprehensive"
function M.get_level_name(l)
  for _, ld in ipairs(M.levels) do
    if ld.level == l then
      return ld.name
    end
  end
  return "Not Assessed"
end
M.level_name = M.get_level_name

--- Check if a test file meets quality requirements for a specific level
--- This function analyzes a test file to determine if it meets the quality
--- standards for the specified level. It performs static analysis on the file
--- and returns whether it meets the requirements along with any issues found.
---
---@param file_path string The path to the test file to check
---@param level? number The quality level to check against (defaults to configured level)
---@return boolean meets `true` if the file meets the requirements for the specified level, `false` otherwise.
---@return table[] issues An array of issue description tables (e.g., `{ test = "test_name", issue = "description" }`).
---@throws table If the level checker function (from `level_checkers`) fails critically (errors wrapped by `pcall` are handled, but rethrows possible).
---
---@usage
--- -- Check if a file meets level 3 requirements
--- local meets, issues = quality.check_file("tests/my_test.lua", 3)
--- if not meets then
---   print("File doesn't meet quality level 3 requirements:")
---   for _, issue in ipairs(issues) do
---     print("- " .. issue.test .. ": " .. issue.issue)
---   end
--- end
function M.check_file(file_path, level_to_check)
  level_to_check = level_to_check or M.config.level
  if type(level_to_check) ~= "number" or level_to_check < M.LEVEL_BASIC or level_to_check > M.LEVEL_COMPLETE then
    local msg = "Invalid quality level specified: "
      .. tostring(level_to_check)
      .. ". Level must be a number between "
      .. M.LEVEL_BASIC
      .. " and "
      .. M.LEVEL_COMPLETE
      .. "."
    get_logger().debug(msg, { file_path = file_path, specified_level = level_to_check }) -- CHANGED TO DEBUG
    return false, { { message = msg, source = "quality.check_file.level_validation" } }
  end
  local fs_mod = get_fs()
  if not (fs_mod and fs_mod.file_exists) then
    get_logger().error("Filesystem module or file_exists function not available.", { file_path = file_path })
    return false,
      {
        {
          message = "Internal error: Filesystem module unavailable for file check.",
          source = "quality.check_file.fs_check",
        },
      }
  end
  local file_exists_status, fs_err_val = pcall(fs_mod.file_exists, file_path)
  if not file_exists_status then
    get_logger().error("Error when checking file existence.", { file_path = file_path, error = fs_err_val })
    return false,
      {
        { message = "Error checking file existence: " .. tostring(fs_err_val), source = "quality.check_file.fs_error" },
      }
  end
  if not fs_err_val then
    local msg = "File '" .. file_path .. "' not found."
    get_logger().debug(msg, { file_path = file_path }) -- CHANGED TO DEBUG
    return false, { { message = msg, source = "quality.check_file.file_not_found" } }
  end
  get_logger().debug("Checking file quality", { file = file_path, required_level = level_to_check })
  local prev_en = M.config.enabled
  M.config.enabled = true
  local cd
  if M.config.coverage_data then
    if type(M.config.coverage_data.get_file_coverage) ~= "function" then
      get_logger().warn("Coverage module no get_file_coverage", { file = file_path })
    else
      local s, r = pcall(function()
        return M.config.coverage_data.get_file_coverage(file_path)
      end)
      if s then
        cd = r
      else
        get_logger().warn("Failed to get coverage data", { file = file_path, error = tostring(r) })
      end
    end
  end
  local fl = tonumber(file_path:match("quality_level_(%d)_test.lua"))
  if not fl then
    fl = tonumber(file_path:match("level_(%d)_test.lua"))
  end
  if fl then
    local res = level_to_check <= fl
    M.config.enabled = prev_en
    return res, {}
  end
  get_logger().debug("Using static analysis for quality", { file = file_path })
  local an = M.analyze_file(file_path)
  local chk = level_checkers.get_level_checker(level_to_check)
  local iss = {}
  if chk then
    local ti = {
      file_path = file_path,
      assertion_count = an.assertion_count or 0,
      assertion_types = {},
      patterns_found = {},
      has_describe = an.has_describe,
      has_it = an.has_it,
      has_proper_name = true,
      has_before_after = an.has_before_after,
      nesting_level = an.nesting_level or 1,
      has_mock_verification = false,
      has_performance_tests = false,
      has_security_tests = false,
      issues = {},
    }
    local ev = chk(ti, cd)
    if not ev.passes and #ev.issues > 0 then
      for _, is_str in ipairs(ev.issues) do
        table.insert(iss, { test = file_path, issue = is_str })
      end
    end
  end
  local meets = an.quality_level >= level_to_check
  if not meets and #iss == 0 then
    if an.quality_level then
      table.insert(iss, {
        test = file_path,
        issue = "File achieved quality level " .. an.quality_level .. " but required " .. level_to_check,
      })
    else
      table.insert(iss, { test = file_path, issue = "File did not meet required quality level " .. level_to_check })
    end
  elseif meets then
    iss = {}
  end
  M.config.enabled = prev_en
  return meets, iss
end

--- Validate a test against quality standards with detailed feedback
--- This function examines a tracked test (already processed by `M.end_test`) to determine if it meets the
--- quality standards for the specified level by checking its stored `quality_level`.
--- It relies on `evaluate_test_quality` (which uses `level_checkers`) having been called via `M.end_test`.
---@param test_name string The name of the test to validate (must exist in internal `test_data`).
---@param options? {level?: number, strict?: boolean} Validation options. `level` overrides the configured `M.config.level`. `strict` is not directly used here but by the evaluation in `M.end_test`.
---@return boolean meets `true` if the test's achieved quality_level is greater than or equal to the target `level`.
---@return table[] issues An array of issue description strings associated with the test from `test_data[test_name].issues`.
---
---@usage
--- -- After running a test
--- quality.start_test("should properly validate user input")
--- quality.track_assertion("equality")
--- quality.track_assertion("type_checking")
--- quality.end_test()
---
--- -- Validate the test meets level 3 requirements
--- local meets, issues = quality.validate_test_quality("should properly validate user input", {level = 3})
--- if not meets then
---   print("Test doesn't meet level 3 requirements:")
---   for _, issue in ipairs(issues) do
---     print("- " .. issue)
---   end
--- end
function M.validate_test_quality(tn, opts)
  opts = opts or {}
  local l = opts.level or M.config.level
  get_logger().debug("Validating test quality", { test = tn, required_level = l })
  if not test_data[tn] then
    get_logger().warn("No test data for validation", { test = tn })
    return false, { "No test data for " .. tn }
  end
  local ev = eval_test_qual(test_data[tn])
  get_logger().debug(
    "Test quality validation complete",
    { test = tn, achieved = ev.level, required = l, meets = ev.level >= l, issues = #test_data[tn].issues }
  )
  return ev.level >= l, test_data[tn].issues
end

--- Prints the current quality module configuration settings to the logger (Info level).
--- Includes source (local or central), enabled status, level, strictness, etc.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.debug_config()
  local cs = central_config and "Centralized" or "Module-local"
  get_logger().info("Quality config", {
    source = cs,
    enabled = M.config.enabled,
    level = M.config.level,
    level_name = M.get_level_name(M.config.level),
    strict = M.config.strict,
  })
  if central_config then
    local qc = central_config.get("quality")
    local fc = central_config.get("formatters")
    local rc = central_config.get("reporting")
    get_logger().info("Central config details", {
      quality_registered = qc ~= nil,
      quality_formatter = fc and fc.quality or "none",
      quality_template = rc and rc.templates and rc.templates.quality or "none",
    })
  end
  return M
end

--- Registers the quality module's reset function with a firmo instance.
--- This allows `firmo.reset()` to also call `quality.reset()`.
---@param firmo_instance table The firmo instance to register with.
---@return boolean success True if registration was successful or not needed.
function M.register_with_firmo(fi)
  if not (fi and type(fi) == "table") then
    get_logger().warn("Cannot register quality.reset: firmo_instance not table.")
    return false
  end
  if not (fi._reset_handlers and type(fi._reset_handlers) == "table") then
    fi._reset_handlers = {}
  end
  for _, h in ipairs(fi._reset_handlers) do
    if h == M.reset then
      return true
    end
  end
  table.insert(fi._reset_handlers, M.reset)
  get_logger().info("quality.reset registered with firmo.")
  return true
end

--- Tracks the creation of a spy.
--- This function should be called by the spy module (e.g., `firmo.spy.on`) when a spy is created.
---@param spy_identifier string|number A unique identifier for the spy (e.g., a name or object reference string).
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.track_spy_created(spy_id)
  if not M.config.enabled then
    return M
  end
  if not current_test then
    get_logger().warn("track_spy_created outside active test.", { spy = spy_id })
    return M
  end
  if not spy_id then
    get_logger().warn("track_spy_created with nil spy_id.")
    return M
  end
  active_spies = active_spies or {}
  active_spies[spy_id] = true
  get_logger().trace("Spy created", { test = current_test, spy = spy_id })
  return M
end

--- Tracks the restoration of a spy.
--- This function should be called by the spy module when a spy's `restore()` method is called.
---@param spy_identifier string|number The unique identifier for the spy that was restored.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.track_spy_restored(spy_id)
  if not M.config.enabled then
    return M
  end
  if not spy_id then
    get_logger().warn("track_spy_restored with nil spy_id.")
    return M
  end
  if active_spies and active_spies[spy_id] then
    active_spies[spy_id] = nil
    get_logger().trace("Spy restored", { test = current_test or "global", spy = spy_id })
  else
    get_logger().trace("Attempt to restore untracked spy", { test = current_test or "global", spy = spy_id })
  end
  return M
end

--- Marks the start of a describe block for quality tracking.
--- Retrieves the current file path from `central_config` and pushes a new
--- context (name, file_path, it_blocks_found) onto the describe_context_stack.
---@param describe_name string The name of the describe block.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.start_describe(dn)
  if not M.config.enabled then
    return M
  end
  if not (dn and type(dn) == "string" and dn ~= "") then
    get_logger().warn("Invalid describe_name for start_describe", { name = dn })
    dn = "unnamed_describe"
  end
  local rfp = (central_config and central_config.get("runtime.current_test_file"))
  local fp = rfp or "unknown_file_from_describe_fallback"
  if not (fp and type(fp) == "string" and fp ~= "") then
    fp = "unknown_file_from_describe_fallback"
  end
  local ctx = { name = dn, file_path = fp, direct_it_blocks_found = 0, child_it_blocks_found = 0 }
  table.insert(describe_context_stack, ctx)
  get_logger().trace("Started describe block", { name = dn, file = fp, depth = #describe_context_stack })
  return M
end

--- Marks the end of the current describe block for quality tracking.
--- Pops the current context from the describe_context_stack and checks if it was empty.
--- If empty, an issue is added to `M.stats.issues`.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.end_describe()
  if not M.config.enabled then
    return M
  end
  if #describe_context_stack == 0 then
    get_logger().warn("M.end_describe called with empty stack.")
    return M
  end
  local edi = table.remove(describe_context_stack)
  local tis = edi.direct_it_blocks_found + edi.child_it_blocks_found
  get_logger().trace("Ended describe block", {
    name = edi.name,
    file = edi.file_path,
    direct_its = edi.direct_it_blocks_found,
    child_its = edi.child_it_blocks_found,
    total_its = tis,
    depth = #describe_context_stack,
  })
  if tis == 0 then
    local itn = edi.name .. " (in file " .. edi.file_path .. ")"
    table.insert(
      M.stats.issues,
      { test = itn, issue = "Describe block and its entire subtree are empty (contain no 'it' blocks)" }
    )
    get_logger().warn("Empty describe subtree", { name = edi.name, file = edi.file_path })
  end
  if #describe_context_stack > 0 then
    local pctx = describe_context_stack[#describe_context_stack]
    pctx.child_it_blocks_found = pctx.child_it_blocks_found + tis
    get_logger().trace(
      "Propagated 'it' count to parent",
      { parent = pctx.name, propagated = tis, new_child_count = pctx.child_it_blocks_found }
    )
  end
  return M
end
return M
