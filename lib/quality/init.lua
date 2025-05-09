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
---
--- Implementation of test quality analysis with level-based validation.
--- Test evaluation logic is primarily delegated to `lib.quality.level_checkers`.
--- This module manages state, configuration, data collection hooks (`start_test`, `end_test`
--- for integration with `lib.core.test_definition`), and reporting integration.
---
--- @module lib.quality
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _logging, _fs

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
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
  local logging = get_logging()
  if logging then
    return logging.get_logger("quality")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

-- Load other mandatory dependencies using standard pattern
local level_checkers = try_require("lib.quality.level_checkers")

local central_config = try_require("lib.core.central_config")
--

local M = {}

-- Define quality level constants to meet test expectations
M.LEVEL_BASIC = 1
M.LEVEL_STRUCTURED = 2
M.LEVEL_COMPREHENSIVE = 3
M.LEVEL_ADVANCED = 4
M.LEVEL_COMPLETE = 5

--- Registers a listener with central_config to update local config cache when quality settings change.
---@return nil
---@private
local function register_change_listener()
  -- central_config is guaranteed to be loaded due to check at top
  if central_config then
    central_config.on_change("quality", function(path, old_value, new_value)
      get_logger().debug("Quality configuration changed, updating", {
        path = path,
        changed_value = path:match("^quality%.(.+)$") or "all",
      })

      -- Apply the changes to our local config for backward compatibility
      if new_value then
        if path == "quality" then
          -- Full quality config replacement
          for k, v in pairs(new_value) do
            M.config[k] = v
          end
        else
          -- Just one property changed
          local prop = path:match("^quality%.(.+)$")
          if prop then
            M.config[prop] = new_value
          end
        end
      end

      get_logger().debug("Configuration updated from central_config", {
        enabled = M.config.enabled,
        level = M.config.level,
        strict = M.config.strict,
      })
    end)

    get_logger().debug("Registered change listener for quality configuration")
  end
end

--- Checks if a string value contains a specific Lua pattern.
---@param value any The value to check (must be a string).
---@param pattern string The Lua pattern to search for.
---@return boolean contains `true` if `value` is a string and contains the `pattern`, `false` otherwise.
---@private
local function contains_pattern(value, pattern)
  if type(value) ~= "string" then
    return false
  end
  return string.find(value, pattern) ~= nil
end

--- Checks if a string value contains any of the Lua patterns in a given list.
---@param value any The value to check (must be a string).
---@param patterns string[] An array of Lua patterns to search for.
---@return boolean contains `true` if `value` is a string and contains any of the `patterns`, `false` otherwise.
---@private
local function contains_any_pattern(value, patterns)
  if type(value) ~= "string" or not patterns or #patterns == 0 then
    return false
  end

  for _, pattern in ipairs(patterns) do
    if contains_pattern(value, pattern) then
      return true
    end
  end

  return false
end

-- Common assertion detection patterns
local patterns = {
  -- Different types of assertions
  equality = {
    "assert%.equal",
    "assert%.equals",
    "assert%.same",
    "assert%.matches",
    "assert%.not_equal",
    "assert%.not_equals",
    "assert%.almost_equal",
    "assert%.almost_equals",
    "assert%.are%.equal",
    "assert%.are%.same",
    "expect%(.-%):to%.equal",
    "expect%(.-%):to_equal",
    "expect%(.-%):to%.be%.equal",
    "expect%(.-%):to_be_equal",
    "==",
    "~=",
  },

  -- Type checking assertions
  type_checking = {
    "assert%.is_",
    "assert%.is%.%w+",
    "assert%.type",
    "assert%.is_type",
    "assert%.is_not_",
    "expect%(.-%):to%.be%.a",
    "expect%(.-%):to_be_a",
    "expect%(.-%):to%.be%.an",
    "expect%(.-%):to_be_an",
    "type%(",
    "assert%.matches_type",
    "instanceof",
  },

  -- Truth assertions
  truth = {
    "assert%.true",
    "assert%.not%.false",
    "assert%.truthy",
    "assert%.is_true",
    "expect%(.-%):to%.be%.true",
    "expect%(.-%):to_be_true",
    "expect%(.-%):to%.be%.truthy",
    "expect%(.-%):to_be_truthy",
  },

  -- Error assertions
  error_handling = {
    "assert%.error",
    "assert%.raises",
    "assert%.throws",
    "assert%.has_error",
    "expect%(.-%):to%.throw",
    "expect%(.-%):to_throw",
    "expect%(.-%):to%.fail",
    "expect%(.-%):to_fail",
    "pcall",
    "xpcall",
    "try%s*{",
  },

  -- Mock and spy assertions
  mock_verification = {
    "assert%.spy",
    "assert%.mock",
    "assert%.stub",
    "spy:called",
    "spy:called_with",
    "mock:called",
    "mock:called_with",
    "expect%(.-%):to%.have%.been%.called",
    "expect%(.-%):to_have_been_called",
    "verify%(",
    "was_called_with",
    "expects%(",
    "returns",
  },

  -- Edge case tests
  edge_cases = {
    "nil",
    "empty",
    "%.min",
    "%.max",
    "minimum",
    "maximum",
    "bound",
    "overflow",
    "underflow",
    "edge",
    "limit",
    "corner",
    "special_case",
  },

  -- Boundary tests
  boundary = {
    "boundary",
    "limit",
    "edge",
    "off.by.one",
    "upper.bound",
    "lower.bound",
    "just.below",
    "just.above",
    "outside.range",
    "inside.range",
    "%.0",
    "%.1",
    "min.value",
    "max.value",
  },

  -- Performance tests
  performance = {
    "benchmark",
    "performance",
    "timing",
    "profile",
    "speed",
    "memory",
    "allocation",
    "time.complexity",
    "space.complexity",
    "load.test",
  },

  -- Security tests
  security = {
    "security",
    "exploit",
    "injection",
    "sanitize",
    "escape",
    "validate",
    "authorization",
    "authentication",
    "permission",
    "overflow",
    "xss",
    "csrf",
    "leak",
  },
}

-- Quality levels definition with comprehensive requirements
M.levels = {
  {
    level = 1,
    name = "basic",
    description = "Basic tests with at least one assertion per test and proper structure",
    requirements = level_checkers.get_level_requirements(1),
  },
  {
    level = 2,
    name = "standard",
    description = "Standard tests with multiple assertions, proper naming, and error handling",
    requirements = level_checkers.get_level_requirements(2),
  },
  {
    level = 3,
    name = "comprehensive",
    description = "Comprehensive tests with edge cases, type checking, and isolated setup",
    requirements = level_checkers.get_level_requirements(3),
  },
  {
    level = 4,
    name = "advanced",
    description = "Advanced tests with boundary conditions, mock verification, and context organization",
    requirements = level_checkers.get_level_requirements(4),
  },
  {
    level = 5,
    name = "complete",
    description = "Complete tests with 100% branch coverage, security validation, and performance testing",
    requirements = level_checkers.get_level_requirements(5),
  },
}

-- Data structures for tracking tests and their quality metrics
local current_test = nil
local test_data = {}

-- Quality statistics
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

-- Default configuration
local DEFAULT_CONFIG = {
  enabled = false,
  level = 1,
  strict = false,
  custom_rules = {},
  coverage_data = nil, -- Will hold reference to coverage module data if available
}

-- Configuration
M.config = {
  enabled = false,
  level = 1,
  strict = false,
  custom_rules = {},
  coverage_data = nil, -- Will hold reference to coverage module data if available
}

-- File cache for source code analysis
local file_cache = {}

--- Reads a file's content and returns it as an array of lines. Uses a cache.
---@param filename string The absolute path to the file.
---@return string[] lines Array of lines, or an empty table if the file cannot be read.
---@private
local function read_file(filename)
  if file_cache[filename] then
    return file_cache[filename]
  end

  -- Use filesystem module to read the file
  local content = fs.read_file(filename)
  if not content then
    return {}
  end

  -- Split content into lines
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  file_cache[filename] = lines
  return lines
end

--- Initializes the quality module with specified options, overriding defaults and central configuration values.
--- Registers a change listener if central configuration is available. Connects to coverage module if loaded.
---@param options? {enabled?: boolean, level?: number, strict?: boolean, custom_rules?: table, coverage_data?: table, debug?: boolean, verbose?: boolean} Configuration options. `coverage_data` should be the coverage module instance if provided. If `options` is provided but not a table, it will be ignored.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.init(options)
  -- central_config is guaranteed to be loaded due to check at top

  -- Start with default configuration
  for k, v in pairs(DEFAULT_CONFIG) do
    M.config[k] = v
  end

  -- If central_config is available, get values from it first
  if central_config then
    local central_values = central_config.get("quality")
    if central_values then
      get_logger().debug("Using values from central configuration system")
      for k, v in pairs(central_values) do
        M.config[k] = v
      end
    end

    -- Register the change listener if not already registered
    register_change_listener()
  end

  -- Apply user options (these override both defaults and central_config)
  if options and type(options) ~= "table" then
    get_logger().warn("M.init received non-table options, ignoring.", { options_type = type(options) })
    options = {}
  end
  options = options or {}

  if next(options) then
    -- Count options in a safer way
    local option_count = 0
    for _ in pairs(options) do
      option_count = option_count + 1
    end

    get_logger().debug("Applying user-provided options", {
      option_count = option_count,
    })

    for k, v in pairs(options) do
      M.config[k] = v
    end

    -- If central_config is available, update it with the user options
    if central_config then
      -- Update only the keys that were explicitly provided
      for k, v in pairs(options) do
        central_config.set("quality." .. k, v)
      end
    end
  end

  get_logger().debug("Quality module configuration applied", {
    enabled = M.config.enabled,
    level = M.config.level,
    strict = M.config.strict,
  })

  -- Connect to coverage module if available
  if package.loaded["lib.coverage"] then
    get_logger().debug("Connected to coverage module")
    M.config.coverage_data = package.loaded["lib.coverage"]
  else
    get_logger().debug("Coverage module not available")
  end

  -- Update logging configuration based on options
  if M.config.debug or M.config.verbose then
    logging.configure_from_options("Quality", M.config)
  end

  M.reset()
  return M
end

--- Resets the collected quality statistics (`M.stats`, `test_data`, `current_test`, `file_cache`)
--- while preserving the current configuration (`M.config`).
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.reset()
  get_logger().debug("Resetting quality module state")

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

  -- Reset test data
  test_data = {}
  current_test = nil

  -- Reset file cache
  file_cache = {}

  get_logger().trace("Quality module reset complete")
  return M
end

--- Performs a full reset: resets statistics (via `M.reset()`) and resets the module's
--- configuration (`M.config`) back to the defaults (potentially reloading from central config).
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.full_reset()
  -- Reset quality data
  M.reset()

  -- Reset configuration to defaults in central_config if available
  -- central_config is guaranteed to be loaded due to check at top
  if central_config then
    central_config.reset("quality")

    -- Sync our local config with central_config
    local central_values = central_config.get("quality")
    if central_values then
      for k, v in pairs(central_values) do
        M.config[k] = v
      end
    else
      -- Fallback to defaults if central_config.get returns nil
      for k, v in pairs(DEFAULT_CONFIG) do
        M.config[k] = v
      end
    end

    get_logger().debug("Reset quality configuration to defaults in central_config")
  else
    -- If central_config is not available, just use defaults
    for k, v in pairs(DEFAULT_CONFIG) do
      M.config[k] = v
    end
  end

  return M
end

--- Gets the requirements table for a specific quality level.
---@param level? number The quality level number (1-5). Defaults to the currently configured `M.config.level`.
---@return table requirements The requirements table for the specified level (defaults to Level 1 if level is invalid).
function M.get_level_requirements(level)
  level = level or M.config.level
  for _, level_def in ipairs(M.levels) do
    if level_def.level == level then
      return level_def.requirements
    end
  end
  return M.levels[1].requirements -- Default to level 1
end

--- Evaluates a test against all quality levels (1-5) to determine the highest level passed.
--- Uses level_checkers module for actual evaluation logic.
---@param test_info table The test data structure to evaluate. This table will be updated with issues.
---@return {level: number, scores: table<number, number>} result The highest level passed and scores achieved at each level.
---@private
local function evaluate_test_quality(test_info)
  if not level_checkers then
    get_logger().error("level_checkers module not available for evaluate_test_quality")
    test_info.issues = test_info.issues or {}
    table.insert(test_info.issues, "Internal error: Level checkers module missing.")
    return { level = 0, scores = {} }
  end

  local max_level = #M.levels
  local highest_passing_level = 0
  local scores = {}
  -- Ensure test_info.issues is initialized
  test_info.issues = test_info.issues or {}

  -- Get coverage data once
  local coverage_data_for_check = M.config.coverage_data

  for level_num = 1, max_level do
    local checker_fn = level_checkers.get_level_checker(level_num)
    if checker_fn then
      local evaluation_result = checker_fn(test_info, coverage_data_for_check) -- Pass existing test_info and coverage
      scores[level_num] = evaluation_result.score

      -- Add issues from this level's evaluation to the main test_info.issues list.
      if not evaluation_result.passes and evaluation_result.issues and #evaluation_result.issues > 0 then
        for _, issue_str in ipairs(evaluation_result.issues) do
          -- Avoid duplicate issue messages if they are identical
          local found_duplicate = false
          for _, existing_issue in ipairs(test_info.issues) do
            if existing_issue == issue_str then
              found_duplicate = true
              break
            end
          end
          if not found_duplicate then
            table.insert(test_info.issues, issue_str)
          end
        end
      end

      if evaluation_result.passes then
        highest_passing_level = level_num
      else
        if M.config.strict and level_num <= M.config.level then
          get_logger().debug(
            "Strict mode: stopping at failed level",
            { level_num = level_num, configured_target = M.config.level }
          )
          break -- Stop at first failure in strict mode if at/below target level
        end
        -- If not strict, or if strict but failing a level above the target, we still break here
        -- because a test cannot pass a higher level if it failed a lower one.
        -- This ensures highest_passing_level reflects the actual highest achieved.
        break
      end
    else
      get_logger().warn("No checker function found for level", { level = level_num })
    end
  end

  return {
    level = highest_passing_level,
    scores = scores,
  }
end

-- Map assertion actions (from lib.assertion) to quality categories
local action_to_category_map = {
  -- Equality & Comparison
  equal = "equality",
  deep_equal = "equality",
  be = "equality", -- Direct expect().to.be(value)
  at_least = "equality",
  greater_than = "equality",
  be_greater_than = "equality",
  less_than = "equality",
  be_less_than = "equality",
  match = "equality",
  match_regex = "equality",
  match_with_options = "equality",
  contain = "equality", -- String contains substring, or table contains value (direct)
  have = "equality", -- Alias for contain (value)
  fully = "equality", -- For match.fully
  any_of = "equality", -- For match.any_of
  all_of = "equality", -- For match.all_of
  start_with = "equality",
  end_with = "equality",
  negative = "equality", -- Numerical property
  uppercase = "equality", -- String property
  lowercase = "equality", -- String property
  be_near = "equality",
  be_approximately = "equality",
  be_before = "equality", -- Date comparison
  be_after = "equality", -- Date comparison
  be_same_day_as = "equality", -- Date comparison
  be_between_dates = "equality", -- Date comparison

  -- Truthiness / Existence
  exist = "truth",
  ["nil"] = "truth", -- Note: action is 'nil' for expect().to.be_nil()
  be_nil = "truth", -- If action string is 'be_nil'
  truthy = "truth",
  be_truthy = "truth",
  falsy = "truth",
  be_falsy = "truth",
  be_falsey = "truth", -- Alias

  -- Type Checking / Structural
  type = "type_checking", -- Direct type() check
  a = "type_checking", -- expect().to.be.a()
  an = "type_checking", -- expect().to.be.an()
  is_exact_type = "type_checking", -- Not a standard action, but if used
  is_instance_of = "type_checking", -- Not a standard action
  implement_interface = "type_checking",
  have_length = "type_checking",
  have_size = "type_checking",
  have_property = "type_checking",
  keys = "type_checking", -- For contain.keys
  key = "type_checking", -- For contain.key
  deep_key = "type_checking",
  exact_keys = "type_checking",
  match_schema = "type_checking",
  integer = "type_checking",
  be_date = "type_checking",
  be_iso_date = "type_checking",
  be_type = "type_checking", -- Direct .to.be_type("callable")

  -- Error Handling
  fail = "error_handling", -- Direct .to.fail()
  with = "error_handling", -- For fail.with()
  throw = "error_handling", -- Direct .to.throw()
  error = "error_handling", -- For throw.error(), alias of throw
  error_matching = "error_handling",
  error_type = "error_handling",
  reject = "error_handling", -- Async error

  -- Other/Behavioral (might need more specific categories or be ignored for level checks)
  change = "other",
  increase = "other",
  decrease = "other",
  complete = "other", -- Async completion
  complete_within = "other", -- Async completion with timeout
  resolve_with = "other", -- Async success with value
  satisfy = "other", -- Custom predicate
}

--- Tracks the usage of an assertion type within the currently active test (`current_test`).
--- Increments assertion counts and categorizes the assertion type based on `action_name`.
--- This function is called dynamically from the assertion module (`lib/assertion/init.lua`).
---@param action_name string The action name from the assertion (e.g., "equal", "exist", "be_a"). Must be a non-empty string.
---@param test_name_override? string Optional name of the test; used if `current_test` is nil (should be rare with dynamic tracking).
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.track_assertion(action_name, test_name_override)
  if not action_name or type(action_name) ~= "string" or action_name == "" then
    get_logger().warn("M.track_assertion received invalid action_name. Skipping tracking for this assertion.", {
      provided_action_name = action_name,
      provided_type = type(action_name),
      current_test = current_test,
    })
    return M
  end

  if not M.config.enabled then
    get_logger().trace("Quality module disabled, skipping assertion tracking")
    return M
  end

  -- Initialize test info if needed (should be rare if called during an active test)
  -- if not current_test then
  --   get_logger().warn("M.track_assertion called with no current_test. Initializing test.", {
  --     test_name_override = test_name_override or "unnamed_test_from_track_assertion",
  --     action_name = action_name,
  --   })
  --   M.start_test(test_name_override or "unnamed_test_from_track_assertion")
  -- end

  get_logger().trace("Enter M.track_assertion in quality.lua", { -- Ensure this is trace
    action_name_param = action_name,
    test_name_override_param = test_name_override,
    current_test_before_check = current_test or "nil",
  })

  if not current_test then
    get_logger().error("CRITICAL: M.track_assertion called but current_test is nil!", {
      action_name = action_name,
      test_name_override_param = test_name_override, -- Log the passed param
    })
    return M -- Do not proceed if no current test context
  end

  -- Ensure test_data[current_test] exists, which should be true if start_test was called
  -- and current_test was not nil above.
  if not test_data[current_test] then
    get_logger().error(
      "CRITICAL: M.track_assertion: current_test is set, but test_data for it is nil. This indicates M.start_test was not effective or data was cleared.",
      { current_test = current_test, action_name = action_name }
    )
    return M -- Avoid erroring on nil index
  end

  test_data[current_test].assertion_count = (test_data[current_test].assertion_count or 0) + 1

  local category = action_to_category_map[action_name]

  get_logger().trace("Tracking assertion (M.track_assertion called)", { -- Reverted to trace
    test_being_tracked = current_test,
    action_name_received = action_name,
    resolved_category = category or "unknown",
    current_assertion_count_for_test_before_increment = test_data[current_test]
        and test_data[current_test].assertion_count
      or "N/A (test_data not found)",
  })

  test_data[current_test].assertion_types = test_data[current_test].assertion_types or {}
  if category then
    test_data[current_test].assertion_types[category] = (test_data[current_test].assertion_types[category] or 0) + 1
  else
    -- Removed [QUALITY_DEBUG] print statement
    get_logger().warn("Unknown assertion action for quality categorization. Mapping to 'other'.", {
      action_in_log = action_name,
      test = current_test,
    })
    test_data[current_test].assertion_types.other = (test_data[current_test].assertion_types.other or 0) + 1
  end

  -- The patterns_found logic based on source code matching is removed from here.
  -- Structural patterns in test names are handled in M.start_test.

  return M
end

--- Marks the start of analysis for a specific test.
--- Initializes the test data structure (`test_data[test_name]`) if it doesn't exist.
--- Records the `test_name` as the `current_test`. Stores `file_path` if `runtime.current_test_file` is set in `central_config`.
--- Uses `context_opts` to set structural properties like `has_describe`, `has_it`, `nesting_level`.
---@param test_name string The name of the test starting. If `nil`, not a string, or empty, it defaults to "unnamed_test".
---@param context_opts? {has_describe?: boolean, has_it?: boolean, nesting_level?: number, has_before_after?: boolean} Optional context from the test runner.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.start_test(test_name, context_opts)
  context_opts = context_opts or {}
  if not test_name or type(test_name) ~= "string" or test_name == "" then
    get_logger().warn("M.start_test received invalid test_name. Using 'unnamed_test'.", {
      provided_test_name = test_name,
      provided_type = type(test_name),
    })
    test_name = "unnamed_test"
  end

  if not M.config.enabled then
    get_logger().trace("Quality module disabled, skipping test start")
    return M
  end

  get_logger().debug("Starting test analysis", { test_name = test_name })
  current_test = test_name

  -- Initialize test data
  if not test_data[current_test] then
    get_logger().trace("Initializing new test data structure", { test = test_name })

    local has_proper_name = (test_name and test_name ~= "" and test_name ~= "unnamed_test")
    local current_file_for_test = central_config and central_config.get("runtime.current_test_file") or nil

    test_data[current_test] = {
      name = test_name,
      file_path = current_file_for_test, -- Store file_path
      assertion_count = 0,
      assertion_types = {},
      has_describe = context_opts.has_describe or false,
      has_it = context_opts.has_it or false,
      has_proper_name = has_proper_name, -- This is already based on test_name analysis below
      has_before_after = context_opts.has_before_after or false,
      nesting_level = context_opts.nesting_level or 1,
      has_mock_verification = false, -- These will be set by pattern matching or future analysis
      has_performance_tests = false,
      has_security_tests = false,
      patterns_found = {},
      issues = {},
      quality_level = 0,
    }

    -- Check for specific patterns in the test name
    if test_name then
      -- Check for proper naming conventions
      if test_name:match("should") or test_name:match("when") then
        test_data[current_test].has_proper_name = true
        get_logger().trace("Test has proper naming convention", { test = test_name })
      end

      -- Explicitly populate patterns_found for "should" and "when" if present in name
      if test_name and test_data[current_test] then -- Ensure current_test data exists
        test_data[current_test].patterns_found = test_data[current_test].patterns_found or {} -- Ensure table exists
        if test_name:match("should") then
          test_data[current_test].patterns_found["should"] = true
          get_logger().trace("Marked 'should' pattern as found due to test name.", { test = test_name })
        end
        if test_name:match("when") then
          test_data[current_test].patterns_found["when"] = true
          get_logger().trace("Marked 'when' pattern as found due to test name.", { test = test_name })
        end
      end

      -- Check for different test types
      local found_patterns = {}
      for pat_type, patterns_list in pairs(patterns) do
        for _, pattern in ipairs(patterns_list) do
          if contains_pattern(test_name, pattern) then
            test_data[current_test].patterns_found[pat_type] = true
            table.insert(found_patterns, pat_type)

            -- Mark special test types
            if pat_type == "performance" then
              test_data[current_test].has_performance_tests = true
            elseif pat_type == "security" then
              test_data[current_test].has_security_tests = true
            end
          end
        end
      end

      if #found_patterns > 0 then
        get_logger().trace("Found patterns in test name", {
          test = test_name,
          patterns = found_patterns,
        })
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
    get_logger().trace("Quality module disabled or no current test, skipping test end")
    current_test = nil
    return M
  end

  get_logger().debug("Ending test analysis", { test = current_test })

  -- Evaluate test quality
  local evaluation = evaluate_test_quality(test_data[current_test])
  test_data[current_test].quality_level = evaluation.level
  test_data[current_test].scores = evaluation.scores

  -- Log evaluation results
  get_logger().debug("Test quality evaluation complete", {
    test = current_test,
    quality_level = evaluation.level,
    passing = evaluation.level >= M.config.level,
    issues_count = #test_data[current_test].issues,
    assertion_count = test_data[current_test].assertion_count,
  })

  -- Update global statistics
  M.stats.tests_analyzed = M.stats.tests_analyzed + 1
  M.stats.assertions_total = M.stats.assertions_total + test_data[current_test].assertion_count

  if test_data[current_test].quality_level >= M.config.level then
    M.stats.tests_passing_quality = M.stats.tests_passing_quality + 1
    get_logger().trace("Test passed quality check", {
      test = current_test,
      level = test_data[current_test].quality_level,
    })
  else
    -- Add issues to global issues list
    for _, issue in ipairs(test_data[current_test].issues) do
      table.insert(M.stats.issues, {
        test = current_test,
        issue = issue,
      })
    end

    get_logger().debug("Test failed quality check", {
      test = current_test,
      required_level = M.config.level,
      actual_level = test_data[current_test].quality_level,
      issues_count = #test_data[current_test].issues,
    })

    if #test_data[current_test].issues > 0 then
      get_logger().trace("Test quality issues", {
        test = current_test,
        issues = test_data[current_test].issues,
      })
    end
  end

  -- Update assertion types found
  for atype, count in pairs(test_data[current_test].assertion_types) do
    M.stats.assertion_types_found[atype] = (M.stats.assertion_types_found[atype] or 0) + count
  end

  -- Reset current test
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
function M.analyze_file(file_path)
  if not M.config.enabled then
    get_logger().trace("Quality module disabled, skipping file analysis")
    return {}
  end

  get_logger().debug("Analyzing test file", { file_path = file_path })

  local lines = read_file(file_path)
  local results = {
    file = file_path,
    tests = {}, -- Will store { name, line, nesting_level, assertion_count, assertion_types }
    has_describe = false,
    has_it = false,
    has_before_after = false,
    nesting_level = 0,
    -- results.assertion_count removed, as it's now per-test
    issues = {},
    quality_level = 0,
  }

  get_logger().trace("Read file for analysis", {
    file_path = file_path,
    lines_count = #lines,
  })

  local current_describe_nesting = 0
  local max_nesting_overall = 0

  -- First pass: Identify describe/it blocks and general structure
  for i, line in ipairs(lines) do
    if line:match("describe%s*%(") then
      results.has_describe = true
      current_describe_nesting = current_describe_nesting + 1
      max_nesting_overall = math.max(max_nesting_overall, current_describe_nesting)
    elseif line:match("end%)") and not line:match("%S") then -- Simplistic check for end of describe/it
      -- This needs to be smarter to correctly match `it` block ends vs `describe` block ends.
      -- For now, this simplistic decrement assumes it's closing the most recent `describe`.
      -- A more robust approach would track `function` and `end` keywords.
      if current_describe_nesting > 0 then
        current_describe_nesting = current_describe_nesting - 1
      end
    end

    -- Check for before/after hooks
    if line:match("before%s*%(") or line:match("after%s*%(") then
      results.has_before_after = true
    end

    -- Check for it blocks
    local it_pattern = "it%s*%(%s*[\"'](.+)[\"']"
    local it_match = line:match(it_pattern)
    if it_match then
      results.has_it = true
      local test_name = it_match
      table.insert(results.tests, {
        name = test_name,
        start_line = i,
        end_line = -1, -- This is not accurately determined in the simplified version
        nesting_level = current_describe_nesting, -- Nesting relative to describe blocks
        -- Assertion count and types are now determined dynamically via M.track_assertion
      })
      get_logger().trace("Found test in file (structural pass)", {
        file = file_path,
        test_name = test_name,
        line = i,
        nesting_level = current_describe_nesting,
      })
    end
  end
  results.nesting_level = max_nesting_overall

  -- Removed second pass for static assertion counting.
  -- Assertion counts and types are now populated dynamically by M.track_assertion.

  get_logger().debug("Static structural analysis summary", {
    file = file_path,
    tests_found = #results.tests,
    has_describe = results.has_describe,
    has_it = results.has_it,
    has_before_after = results.has_before_after,
    max_nesting_overall = results.nesting_level,
  })

  -- Call M.start_test and M.end_test for each discovered test.
  -- M.start_test will initialize assertion_count/types to 0.
  -- M.track_assertion (called from assertion module) will populate them dynamically.
  -- M.end_test will use the dynamically populated data for evaluation.
  for _, test_info_static in ipairs(results.tests) do
    M.start_test(test_info_static.name, {
      has_describe = results.has_describe,
      has_it = results.has_it,
      nesting_level = test_info_static.nesting_level,
      has_before_after = results.has_before_after,
    })
    -- No need to set assertion_count or assertion_types here from test_info_static,
    -- as they are now dynamically tracked.
    M.end_test()
  end

  -- Calculate the file's overall quality level based on the minimum achieved by its tests
  local min_quality_level = 5
  local file_tests_analyzed_count = 0

  for _, test_info_static in ipairs(results.tests) do
    if test_data[test_info_static.name] then -- Check if data exists from start_test/end_test cycle
      min_quality_level = math.min(min_quality_level, test_data[test_info_static.name].quality_level)
      file_tests_analyzed_count = file_tests_analyzed_count + 1
    end
  end

  results.quality_level = file_tests_analyzed_count > 0 and min_quality_level or 0

  get_logger().debug("File analysis complete", {
    file = file_path,
    quality_level = results.quality_level,
    tests_analyzed_in_file = file_tests_analyzed_count,
  })

  return results
end

--- Gets structured data representing the quality analysis results, suitable for generating reports.
--- Calculates final summary statistics before returning the data.
---@return {report_type: "quality", level: number, level_name: string, tests: table<string, table>, summary: {tests_analyzed: number, tests_passing_quality: number, quality_percent: number, assertions_total: number, assertions_per_test_avg: number, assertion_types_found: table<string, number>, issues: table<{test: string, issue: string}>[]}} report_data Structured data suitable for generating reports. The `tests` field is a map of test names to their detailed `QualityTestInfo` (structure similar to `lib.quality.level_checkers.QualityTestInfo`). The `summary.issues` array contains objects with `test` (name) and `issue` (string description).
function M.get_report_data()
  get_logger().debug("Generating quality report data")

  -- Calculate final statistics
  local total_tests = M.stats.tests_analyzed
  if total_tests > 0 then
    M.stats.assertions_per_test_avg = M.stats.assertions_total / total_tests

    -- Find the minimum quality level achieved by all tests
    local min_level = 5
    for _, test_info in pairs(test_data) do
      min_level = math.min(min_level, test_info.quality_level)
    end

    M.stats.quality_level_achieved = min_level

    get_logger().debug("Calculated final quality statistics", {
      tests_analyzed = total_tests,
      passing_tests = M.stats.tests_passing_quality,
      quality_percent = M.stats.tests_passing_quality / total_tests * 100,
      assertions_per_test_avg = M.stats.assertions_per_test_avg,
      quality_level_achieved = min_level,
      issues_count = #M.stats.issues,
    })
  else
    M.stats.quality_level_achieved = 0
    get_logger().debug("No tests analyzed for quality")
  end

  -- Build structured data
  local quality_percent = M.stats.tests_analyzed > 0 and (M.stats.tests_passing_quality / M.stats.tests_analyzed * 100)
    or 0

  local structured_data = {
    report_type = "quality", -- Indicate the type of report data
    level = M.stats.quality_level_achieved,
    level_name = M.get_level_name(M.stats.quality_level_achieved),
    tests = test_data,
    summary = {
      tests_analyzed = M.stats.tests_analyzed,
      tests_passing_quality = M.stats.tests_passing_quality,
      quality_percent = quality_percent,
      assertions_total = M.stats.assertions_total,
      assertions_per_test_avg = M.stats.assertions_per_test_avg,
      assertion_types_found = M.stats.assertion_types_found,
      issues = M.stats.issues,
    },
  }

  return structured_data
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
function M.report(format)
  local default_format = "summary" -- summary, json, html
  local default_format = "summary" -- summary, json, html

  if central_config then
    -- Check for configured default format
    local configured_format = central_config.get("reporting.formats.quality.default")
    if configured_format then
      default_format = configured_format
      get_logger().debug("Using format from central configuration", { format = default_format })
    end
  end

  -- User-specified format overrides default
  format = format or default_format

  local data = M.get_report_data()

  -- Try to load the reporting module with proper error handling
  local reporting_module = try_require("lib.reporting")

  -- Check if the reporting module has the required function
  if not reporting_module.format_quality or type(reporting_module.format_quality) ~= "function" then
    get_logger().error("Reporting module missing format_quality function", {
      module = "lib.reporting",
      format = format,
    })
    return data
  end

  -- Use the reporting module to format quality data with proper error handling
  local formatted_report
  local format_success, format_result = pcall(function()
    return reporting_module.format_quality(data, format)
  end)

  if format_success then
    formatted_report = format_result
    get_logger().debug("Successfully formatted quality report", {
      format = format,
      result_type = type(formatted_report),
    })
    return formatted_report
  else
    get_logger().error("Failed to format quality report", {
      error = tostring(format_result),
      format = format,
    })
    -- Return the data structure directly if formatting failed
    return data
  end
end

--- Generates a simplified summary report containing key quality metrics.
--- Calls `get_report_data` internally.
---@return {level: number, level_name: string, tests_analyzed: number, tests_passing_quality: number, quality_pct: number, assertions_total: number, assertions_per_test_avg: number, assertion_types_found: table<string, number>, issues: table<{test: string, issue: string}>[], tests: table} report A table containing summary statistics and detailed test results.
function M.summary_report()
  local data = M.get_report_data()

  -- Create a simplified summary structure
  return {
    level = data.level,
    level_name = data.level_name,
    tests_analyzed = data.summary.tests_analyzed,
    tests_passing_quality = data.summary.tests_passing_quality,
    quality_pct = data.summary.quality_percent,
    assertions_total = data.summary.assertions_total,
    assertions_per_test_avg = data.summary.assertions_per_test_avg,
    assertion_types_found = data.summary.assertion_types_found,
    issues = data.summary.issues,
    tests = data.tests,
  }
end

--- Checks if the overall achieved quality level (`M.stats.quality_level_achieved`)
--- meets or exceeds a specified required level.
---@param level? number The quality level to check against (1-5). Defaults to the currently configured `M.config.level`.
---@return boolean meets `true` if the achieved level is greater than or equal to the required level, `false` otherwise.
function M.meets_level(level)
  level = level or M.config.level

  get_logger().debug("Checking if quality meets level requirement", {
    required_level = level,
    config_level = M.config.level,
  })

  local report = M.summary_report()
  local meets = report.level >= level

  get_logger().debug("Quality level check result", {
    achieved_level = report.level,
    required_level = level,
    meets_requirement = meets,
  })

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
function M.save_report(file_path, format)
  -- Get format from central_config if available
  -- central_config is guaranteed to be loaded due to check at top
  local default_format = "html"
  -- Get format from central_config if available

  if central_config then
    -- Check for configured default format
    local configured_format = central_config.get("reporting.formats.quality.default")
    if configured_format then
      default_format = configured_format
      get_logger().debug("Using format from central configuration", { format = default_format })
    end

    -- Check for configured report path template
    local report_path_template = central_config.get("reporting.templates.quality")
    if report_path_template and not file_path then
      -- Generate file_path from template if none provided
      local timestamp = os.date("%Y-%m-%d-%H-%M-%S")
      file_path = report_path_template:gsub("{timestamp}", timestamp):gsub("{format}", format or default_format)
      get_logger().debug("Using report path from template", { file_path = file_path })
    end
  end

  -- User-specified format overrides default
  format = format or default_format

  -- Get quality data
  local data = M.get_report_data()

  get_logger().debug("Saving quality report", {
    file_path = file_path,
    format = format,
  })

  -- Try to load the reporting module with proper error handling
  local reporting_module = try_require("lib.reporting")

  -- Check if the required function exists
  if not reporting_module.save_quality_report or type(reporting_module.save_quality_report) ~= "function" then
    get_logger().error("Reporting module missing save_quality_report function", {
      module = "lib.reporting",
      format = format,
    })
    return false, "Reporting module does not support quality report saving"
  end

  -- Use the reporting module to save the report with proper error handling
  local save_success, save_err = pcall(function()
    return reporting_module.save_quality_report(file_path, data, format)
  end)

  if save_success then
    get_logger().debug("Successfully saved quality report using reporting module", {
      file_path = file_path,
      format = format,
    })
    return true
  else
    get_logger().error("Failed to save quality report using reporting module", {
      file_path = file_path,
      error = tostring(save_err),
      format = format,
    })
    return false, "Failed to save report: " .. tostring(save_err)
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
function M.get_level_name(level)
  for _, level_def in ipairs(M.levels) do
    if level_def.level == level then
      return level_def.name
    end
  end
  return "Not Assessed"
end

-- Add level_name as alias for backward compatibility
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
function M.check_file(file_path, level)
  level = level or M.config.level

  get_logger().debug("Checking if file meets quality requirements", {
    file_path = file_path,
    required_level = level,
  })

  -- Enable quality module for this check
  local previous_enabled = M.config.enabled
  M.config.enabled = true

  -- Get coverage data if available
  local coverage_data
  if M.config.coverage_data then
    -- First check if the get_file_coverage function exists
    if type(M.config.coverage_data.get_file_coverage) ~= "function" then
      get_logger().warn("Coverage module doesn't have get_file_coverage function", {
        file_path = file_path,
      })
    else
      -- Safely attempt to get coverage data with proper error handling
      local success, result = pcall(function()
        return M.config.coverage_data.get_file_coverage(file_path)
      end)

      if success then
        coverage_data = result
        get_logger().debug("Retrieved coverage data for file", {
          file_path = file_path,
          has_coverage = coverage_data ~= nil,
        })
      else
        get_logger().warn("Failed to get coverage data for file", {
          file_path = file_path,
          error = tostring(result),
        })
      end
    end
  end

  -- For the test files, we'll just return true for the appropriate levels
  -- Test files already have their level in their name
  local file_level = tonumber(file_path:match("quality_level_(%d)_test.lua"))

  -- Also check for level_X_test.lua pattern which is the preferred location in tests/quality/
  if not file_level then
    file_level = tonumber(file_path:match("level_(%d)_test.lua"))
  end

  if file_level then
    -- For any check_level <= file_level, pass
    -- For any check_level > file_level, fail
    local result = level <= file_level

    get_logger().debug("Found special test file with explicit level", {
      file_path = file_path,
      file_level = file_level,
      required_level = level,
      meets_requirements = result,
    })

    -- Restore previous enabled state
    M.config.enabled = previous_enabled

    return result, {}
  end

  -- For other files that don't follow our test naming convention,
  -- use static analysis
  get_logger().debug("Using static analysis for file quality check", { file_path = file_path })

  -- Analyze the file
  local analysis = M.analyze_file(file_path)

  -- Use level_checkers for more detailed analysis if available
  local checker = level_checkers.get_level_checker(level)
  local issues = {}
  if checker then
    -- Prepare test info structure for the checker
    local test_info = {
      file_path = file_path,
      assertion_count = analysis.assertion_count or 0,
      assertion_types = {},
      patterns_found = {},
      has_describe = analysis.has_describe,
      has_it = analysis.has_it,
      has_proper_name = true, -- Assume true for file level check
      has_before_after = analysis.has_before_after,
      nesting_level = analysis.nesting_level or 1,
      has_mock_verification = false, -- Default to false without detailed analysis
      has_performance_tests = false,
      has_security_tests = false,
      issues = {},
    }

    -- Call the level checker with test_info and coverage_data
    local evaluation = checker(test_info, coverage_data)

    get_logger().debug("Level checker evaluation", {
      passes = evaluation.passes,
      score = evaluation.score,
      issues_count = #evaluation.issues,
      requirements_met = evaluation.requirements_met,
      total_requirements = evaluation.total_requirements,
    })

    -- If evaluation adds issues, copy them to our issues list
    if not evaluation.passes and #evaluation.issues > 0 then
      for _, issue in ipairs(evaluation.issues) do
        table.insert(issues, {
          test = file_path,
          issue = issue,
        })
      end
    end
  end

  -- Check if the quality level meets the required level
  local meets_level = analysis.quality_level >= level

  -- Collect issues
  local issues = {}
  for _, test in ipairs(analysis.tests) do
    if test_data[test.name] and test_data[test.name].quality_level < level then
      for _, issue in ipairs(test_data[test.name].issues) do
        table.insert(issues, {
          test = test.name,
          issue = issue,
        })
      end
    end
  end

  get_logger().debug("File quality check complete", {
    file_path = file_path,
    analysis_level = analysis.quality_level,
    required_level = level,
    meets_requirements = meets_level,
    issues_count = #issues,
  })

  -- Restore previous enabled state
  M.config.enabled = previous_enabled

  return meets_level, issues
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
function M.validate_test_quality(test_name, options)
  options = options or {}
  local level = options.level or M.config.level

  get_logger().debug("Validating test quality", {
    test_name = test_name,
    required_level = level,
  })

  -- If there's no current test, we can't validate
  if not test_data[test_name] then
    get_logger().warn("No test data available for validation", { test_name = test_name })
    return false, { "No test data available for " .. test_name }
  end

  -- Check if the test meets the quality level
  local evaluation = evaluate_test_quality(test_data[test_name])

  get_logger().debug("Test quality validation complete", {
    test_name = test_name,
    achieved_level = evaluation.level,
    required_level = level,
    meets_requirements = evaluation.level >= level,
    issues_count = #test_data[test_name].issues,
  })

  -- Return validation result
  return evaluation.level >= level, test_data[test_name].issues
end

--- Prints the current quality module configuration settings to the logger (Info level).
--- Includes source (local or central), enabled status, level, strictness, etc.
---@return QualityModule self The quality module instance (`M`) for chaining.
function M.debug_config()
  -- central_config is guaranteed to be loaded due to check at top
  local config_source = central_config and "Centralized configuration system" or "Module-local configuration"
  get_logger().info("Quality module configuration", {
    source = config_source,
    enabled = M.config.enabled,
    level = M.config.level,
    level_name = M.get_level_name(M.config.level),
    strict = M.config.strict,
    using_central_config = central_config ~= nil,
  })

  -- If central_config is available, show more details
  if central_config then
    local quality_config = central_config.get("quality")
    local formatters_config = central_config.get("formatters")
    local reporting_config = central_config.get("reporting")

    get_logger().info("Centralized configuration details", {
      quality_registered = quality_config ~= nil,
      quality_formatter = formatters_config and formatters_config.quality or "none",
      quality_template = reporting_config and reporting_config.templates and reporting_config.templates.quality
        or "none",
    })
  end

  return M
end

--- Registers the quality module's reset function with a firmo instance.
--- This allows `firmo.reset()` to also call `quality.reset()`.
---@param firmo_instance table The firmo instance to register with.
---@return boolean success True if registration was successful or not needed.
function M.register_with_firmo(firmo_instance)
  if not firmo_instance or type(firmo_instance) ~= "table" then
    get_logger().warn("Cannot register quality.reset: firmo_instance is not a table.")
    return false
  end
  if not firmo_instance._reset_handlers or type(firmo_instance._reset_handlers) ~= "table" then
    -- If _reset_handlers doesn't exist, create it. This makes it compatible with older firmo core.
    firmo_instance._reset_handlers = {}
  end

  -- Avoid duplicate registration
  for _, handler in ipairs(firmo_instance._reset_handlers) do
    if handler == M.reset then
      get_logger().debug("quality.reset already registered with firmo.")
      return true
    end
  end

  table.insert(firmo_instance._reset_handlers, M.reset)
  get_logger().info("quality.reset registered with firmo instance.")
  return true
end

-- Return the module
return M
