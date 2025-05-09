--- Firmo Quality Level Checkers
---
--- This module contains the core evaluation logic for Firmo's test quality validation system.
--- It defines specialized validation functions (`evaluate_level_*`, `check_*`) for each
--- defined quality level (1-5) and their specific criteria.
--- It evaluates test metadata (as `QualityTestInfo` objects) against defined requirements
--- (`QualityRequirements`) for each level. This module is used by `lib.quality` to perform
--- the actual quality assessments.
---
--- @module lib.quality.level_checkers
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.2.0

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _logging

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
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
    return logging.get_logger("level_checkers")
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


local M = {}

---@class QualityTestInfo Test metadata and metrics used for quality evaluation.
---@field name string Test name (usually full path including describe blocks).
---@field file_path? string Path to the test file.
---@field assertion_count number Number of assertions dynamically tracked or statically analyzed for the test.
---@field assertion_types table<string, number> Map of assertion type categories (e.g., "equality", "type_checking") to their counts for this test. Populated by `lib.quality.track_assertion` or static analysis.
---@field patterns_found table<string, boolean> Map of pattern categories (e.g., "should", "boundary") found in the test name or content. Populated by `lib.quality.track_assertion` or static analysis.
---@field has_describe boolean Whether the test is considered to be within a `describe` block (typically passed as context or analyzed).
---@field has_it boolean Whether the test is an `it` block (typically true if this structure is for an `it` block, passed as context or analyzed).
---@field has_proper_name boolean Whether the test name follows conventions (e.g., includes "should", based on analysis in `lib.quality`).
---@field has_before_after boolean Whether `before` or `after` hooks are associated with the test context (passed as context or analyzed).
---@field nesting_level number Depth of `describe` nesting for this test (passed as context or analyzed).
---@field has_mock_verification boolean Whether mock/spy verification patterns were found (based on analysis in `lib.quality`).
---@field has_performance_tests boolean Whether performance testing patterns were found (based on analysis in `lib.quality`).
---@field has_security_tests boolean Whether security testing patterns were found (based on analysis in `lib.quality`).
---@field issues string[] List of quality issue description strings accumulated for this test during evaluation.
---@field quality_level number The highest quality level this specific test has successfully met.
---@field scores? table<number, number> A map where keys are level numbers (1-5) and values are scores (0-100) achieved at each evaluated level (optional).

---@class QualityRequirements Defines the criteria for a specific quality level.
---@field min_assertions_per_test? number Minimum required assertions per test.
---@field assertion_types_required? string[] Array of required assertion type categories.
---@field assertion_types_required_count? number Minimum number of distinct required assertion types needed.
---@field test_organization? {require_describe_block?: boolean, require_it_block?: boolean, max_assertions_per_test?: number, require_test_name?: boolean, require_before_after?: boolean, require_context_nesting?: boolean, require_mock_verification?: boolean, require_coverage_threshold?: number, require_performance_tests?: boolean, require_security_tests?: boolean} Table defining organizational requirements.
---@field required_patterns? string[] Array of required pattern categories.
---@field forbidden_patterns? string[] Array of forbidden pattern categories.

-- Helper Functions ------------------------------------------------------

--- Check if a string value contains the specified Lua pattern
---@private
---@param value string The value to check for pattern matching.
---@param pattern string The Lua pattern to search for in the value.
---@return boolean contains `true` if `value` contains the `pattern`, `false` otherwise.
local function contains_pattern(value, pattern)
  if type(value) ~= "string" then
    return false
  end
  return string.find(value, pattern) ~= nil
end

--- Check if a string value contains any of the specified Lua patterns
---@private
---@param value string The value to check for pattern matching.
---@param patterns string[] Array of Lua patterns to search for in the value.
---@return boolean contains `true` if `value` contains any of the `patterns`, `false` otherwise.
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

-- Level Requirement Checkers --------------------------------------------

--- Check if a test has enough assertions
---@param test_info QualityTestInfo The test info object containing assertion data.
---@param requirements QualityRequirements The requirements for the specified quality level.
---@return boolean is_valid `true` if the assertion count meets the requirements, `false` otherwise.
---@return string? issue An issue description string if requirements are not met, `nil` otherwise.
function M.check_assertion_count(test_info, requirements)
  local min_required = requirements.min_assertions_per_test or 1
  local max_allowed = (requirements.test_organization and requirements.test_organization.max_assertions_per_test) or 15

  if test_info.assertion_count < min_required then
    return false,
      string.format("Too few assertions: found %d, need at least %d", test_info.assertion_count, min_required)
  end

  if test_info.assertion_count > max_allowed then
    return false, string.format("Too many assertions: found %d, maximum is %d", test_info.assertion_count, max_allowed)
  end

  return true
end

--- Check if a test uses required assertion types
---@param test_info QualityTestInfo The test info object containing assertion type data.
---@param requirements QualityRequirements The requirements for the specified quality level.
---@return boolean is_valid `true` if the assertion type requirements are met, `false` otherwise.
---@return string? issue An issue description string if requirements are not met, `nil` otherwise.
function M.check_assertion_types(test_info, requirements)
  local required_types = requirements.assertion_types_required or {}
  local min_types_required = requirements.assertion_types_required_count or 1

  local found_types = 0
  local types_found = {}

  for _, required_type in ipairs(required_types) do
    if test_info.assertion_types[required_type] and test_info.assertion_types[required_type] > 0 then
      found_types = found_types + 1
      types_found[required_type] = true
    end
  end

  if found_types < min_types_required then
    local missing_types = {}
    for _, required_type in ipairs(required_types) do
      if not types_found[required_type] then
        table.insert(missing_types, required_type)
      end
    end

    return false,
      string.format(
        "Missing required assertion types: need %d type(s), found %d. Missing: %s",
        min_types_required,
        found_types,
        table.concat(missing_types, ", ")
      )
  end

  return true
end

--- Check if test organization meets requirements
---@param test_info QualityTestInfo The test info object containing organization data.
---@param requirements QualityRequirements The requirements for the specified quality level.
---@return boolean is_valid `true` if all applicable organization requirements are met, `false` otherwise.
---@return string[]? issues An array of issue description strings if requirements are not met, `nil` otherwise.
function M.check_organization(test_info, requirements)
  if not requirements.test_organization then
    return true
  end

  local org = requirements.test_organization
  local is_valid = true
  local issues = {}

  -- Check for describe blocks
  if org.require_describe_block and not test_info.has_describe then
    table.insert(issues, "Missing describe block")
    is_valid = false
  end

  -- Check for it blocks
  if org.require_it_block and not test_info.has_it then
    table.insert(issues, "Missing it block")
    is_valid = false
  end

  -- Check for proper test naming
  if org.require_test_name and not test_info.has_proper_name then
    table.insert(issues, "Test doesn't have a proper descriptive name")
    is_valid = false
  end

  -- Check for before/after blocks
  if org.require_before_after and not test_info.has_before_after then
    table.insert(issues, "Missing setup/teardown with before/after blocks")
    is_valid = false
  end

  -- Check for context nesting
  if org.require_context_nesting and test_info.nesting_level < 2 then
    table.insert(issues, "Insufficient context nesting (need at least 2 levels)")
    is_valid = false
  end

  -- Check for mock verification
  if org.require_mock_verification and not test_info.has_mock_verification then
    table.insert(issues, "Missing mock/spy verification")
    is_valid = false
  end

  -- Check for performance tests
  if org.require_performance_tests and not test_info.has_performance_tests then
    table.insert(issues, "Missing performance tests")
    is_valid = false
  end

  -- Check for security tests
  if org.require_security_tests and not test_info.has_security_tests then
    table.insert(issues, "Missing security tests")
    is_valid = false
  end

  return is_valid, issues
end

--- Check for coverage threshold requirements
---@param test_info QualityTestInfo The test info object.
---@param requirements QualityRequirements The requirements for the specified quality level, expected to contain `test_organization.require_coverage_threshold`.
---@param coverage_data? table Optional coverage data. Expected to be a table from `coverage.get_data().summary` (containing `coverage_percent`) or `coverage.summary_report()` (containing `overall_pct`).
---@return boolean is_valid `true` if coverage requirements are met, not applicable (no threshold or no data), or if coverage data is malformed but check doesn't fail open. `false` if threshold explicitly not met.
---@return string? issue An issue description string if threshold is not met, `nil` otherwise.
function M.check_coverage(test_info, requirements, coverage_data)
  -- Skip if no coverage requirements or no coverage data
  if
    not requirements.test_organization
    or not requirements.test_organization.require_coverage_threshold
    or not coverage_data
  then
    return true
  end

  local threshold = requirements.test_organization.require_coverage_threshold

  -- Get overall coverage percentage
  local overall_pct = 0
  if coverage_data.summary and coverage_data.summary.coverage_percent then
    overall_pct = coverage_data.summary.coverage_percent
  elseif coverage_data.overall_pct then
    overall_pct = coverage_data.overall_pct
  end

  if overall_pct < threshold then
    return false, string.format("Insufficient code coverage: %.2f%% (threshold: %d%%)", overall_pct, threshold)
  end

  return true
end

--- Check for required patterns
---@param test_info QualityTestInfo The test info object containing `patterns_found`.
---@param requirements QualityRequirements The requirements for the specified quality level (must contain `required_patterns`).
---@return boolean is_valid `true` if all required patterns are found, `false` otherwise.
---@return string? issue An issue description string if requirements are not met, `nil` otherwise.
function M.check_required_patterns(test_info, requirements)
  local current_patterns_found = test_info.patterns_found or {}
  local required_pattern_categories = requirements.required_patterns or {}
  if #required_pattern_categories == 0 then
    return true
  end

  local is_valid = true
  local missing_patterns = {}

  for _, pattern_category in ipairs(required_pattern_categories) do
    if not current_patterns_found[pattern_category] then
      table.insert(missing_patterns, pattern_category)
      is_valid = false
    end
  end

  if #missing_patterns > 0 then
    return false, string.format("Missing required patterns: %s", table.concat(missing_patterns, ", "))
  end

  return true
end

--- Check for forbidden patterns
---@param test_info QualityTestInfo The test info object containing `patterns_found`.
---@param requirements QualityRequirements The requirements for the specified quality level (must contain `forbidden_patterns`).
---@return boolean is_valid `true` if no forbidden patterns are found, `false` otherwise.
---@return string? issue An issue description string if forbidden patterns are found, `nil` otherwise.
function M.check_forbidden_patterns(test_info, requirements)
  local current_patterns_found = test_info.patterns_found or {}
  local forbidden_pattern_categories = requirements.forbidden_patterns or {}
  if #forbidden_pattern_categories == 0 then
    return true
  end

  local is_valid = true
  local found_forbidden = {}

  for _, pattern_category in ipairs(forbidden_pattern_categories) do
    if current_patterns_found[pattern_category] then
      table.insert(found_forbidden, pattern_category)
      is_valid = false
    end
  end

  if #found_forbidden > 0 then
    return false, string.format("Found forbidden patterns: %s", table.concat(found_forbidden, ", "))
  end

  return true
end

-- Level-Specific Evaluation Functions -----------------------------------

--- Evaluates a test against Level 1 (Basic) requirements.
---@param test_info QualityTestInfo The test info object with test metadata.
---@param coverage_data? table Optional coverage summary table.
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results.
function M.evaluate_level_1(test_info, coverage_data)
  local requirements = {
    min_assertions_per_test = 1,
    assertion_types_required = { "equality", "truth" },
    assertion_types_required_count = 1,
    test_organization = {
      require_describe_block = true,
      require_it_block = true,
      max_assertions_per_test = 15,
      require_test_name = true,
    },
    required_patterns = {},
    forbidden_patterns = { "SKIP", "TODO", "FIXME" },
  }

  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Evaluates a test against Level 2 (Standard) requirements.
---@param test_info QualityTestInfo The test info object with test metadata.
---@param coverage_data? table Optional coverage summary table.
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results.
function M.evaluate_level_2(test_info, coverage_data)
  local requirements = {
    min_assertions_per_test = 2,
    assertion_types_required = { "equality", "truth", "type_checking" },
    assertion_types_required_count = 2,
    test_organization = {
      require_describe_block = true,
      require_it_block = true,
      max_assertions_per_test = 10,
      require_test_name = true,
      require_before_after = false,
    },
    required_patterns = { "should" },
    forbidden_patterns = { "SKIP", "TODO", "FIXME" },
  }

  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Evaluates a test against Level 3 (Comprehensive) requirements.
---@param test_info QualityTestInfo The test info object with test metadata.
---@param coverage_data? table Optional coverage summary table.
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results.
function M.evaluate_level_3(test_info, coverage_data)
  local requirements = {
    min_assertions_per_test = 3,
    assertion_types_required = { "equality", "truth", "type_checking", "error_handling", "edge_cases" },
    assertion_types_required_count = 3,
    test_organization = {
      require_describe_block = true,
      require_it_block = true,
      max_assertions_per_test = 8,
      require_test_name = true,
      require_before_after = true,
      require_context_nesting = true,
    },
    required_patterns = { "should", "when" },
    forbidden_patterns = { "SKIP", "TODO", "FIXME" },
  }

  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Evaluates a test against Level 4 (Advanced) requirements.
---@param test_info QualityTestInfo The test info object with test metadata.
---@param coverage_data? table Optional coverage summary table.
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results.
function M.evaluate_level_4(test_info, coverage_data)
  local requirements = {
    min_assertions_per_test = 4,
    assertion_types_required = {
      "equality",
      "truth",
      "type_checking",
      "error_handling",
      "mock_verification",
      "edge_cases",
      "boundary",
    },
    assertion_types_required_count = 4,
    test_organization = {
      require_describe_block = true,
      require_it_block = true,
      max_assertions_per_test = 6,
      require_test_name = true,
      require_before_after = true,
      require_context_nesting = true,
      require_mock_verification = true,
    },
    required_patterns = { "should", "when", "boundary" },
    forbidden_patterns = { "SKIP", "TODO", "FIXME" },
  }

  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Evaluates a test against Level 5 (Complete) requirements.
---@param test_info QualityTestInfo The test info object with test metadata.
---@param coverage_data? table Optional coverage summary table.
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results.
function M.evaluate_level_5(test_info, coverage_data)
  local requirements = {
    min_assertions_per_test = 5,
    assertion_types_required = {
      "equality",
      "truth",
      "type_checking",
      "error_handling",
      "mock_verification",
      "edge_cases",
      "boundary",
      "performance",
      "security",
    },
    assertion_types_required_count = 5,
    test_organization = {
      require_describe_block = true,
      require_it_block = true,
      max_assertions_per_test = 5,
      require_test_name = true,
      require_before_after = true,
      require_context_nesting = true,
      require_mock_verification = true,
      require_coverage_threshold = 90, -- Match our new standard threshold
      require_performance_tests = true,
      require_security_tests = true,
    },
    required_patterns = { "should", "when", "boundary", "security", "performance" },
    forbidden_patterns = { "SKIP", "TODO", "FIXME" },
  }

  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Core evaluation function that checks test against a set of requirements
---@param test_info QualityTestInfo The test info object with test metadata.
---@param requirements QualityRequirements The requirements to check against.
---@param coverage_data? table Optional coverage summary table.
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Summary of the evaluation, including pass status, score, issues, and requirement counts.
function M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
  -- Initialize result object
  local result = {
    passes = true,
    score = 0,
    issues = {},
    requirements_met = 0,
    total_requirements = 5, -- Five main requirement categories
  }

  -- 1. Check assertion count
  local assertion_count_valid, assertion_count_issue = M.check_assertion_count(test_info, requirements)
  if assertion_count_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    if assertion_count_issue then
      table.insert(result.issues, assertion_count_issue)
    end
  end

  -- 2. Check assertion types
  local assertion_types_valid, assertion_types_issue = M.check_assertion_types(test_info, requirements)
  if assertion_types_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    if assertion_types_issue then
      table.insert(result.issues, assertion_types_issue)
    end
  end

  -- 3. Check organization requirements
  local organization_valid, organization_issues = M.check_organization(test_info, requirements)
  if organization_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    -- Add all organization issues
    if organization_issues then
      for _, issue in ipairs(organization_issues) do
        table.insert(result.issues, issue)
      end
    end
  end

  -- 4. Check coverage requirements if coverage data is available
  local coverage_valid, coverage_issue = M.check_coverage(test_info, requirements, coverage_data)
  if coverage_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    if coverage_issue then
      table.insert(result.issues, coverage_issue)
    end
  end

  -- 5. Check required patterns
  local required_patterns_valid, required_patterns_issue = M.check_required_patterns(test_info, requirements)
  if required_patterns_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    if required_patterns_issue then
      table.insert(result.issues, required_patterns_issue)
    end
  end

  -- 6. Check forbidden patterns
  local forbidden_patterns_valid, forbidden_patterns_issue = M.check_forbidden_patterns(test_info, requirements)
  if not forbidden_patterns_valid then
    result.passes = false
    if forbidden_patterns_issue then
      table.insert(result.issues, forbidden_patterns_issue)
    end
  end

  -- Calculate score as percentage of requirements met
  result.score = (result.requirements_met / result.total_requirements) * 100

  get_logger().debug("Evaluated test against requirements", {
    passes = result.passes,
    score = result.score,
    requirements_met = result.requirements_met,
    total_requirements = result.total_requirements,
    issues_count = #result.issues,
  })

  return result
end

--- Get a level checker function for a specific quality level.
--- Each returned function expects `(test_info: QualityTestInfo, coverage_data?: table)`
--- and returns ` {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number}`.
---@param level number Quality level number (1-5) for which to get the checker.
---@return function|nil checker The corresponding `evaluate_level_X` function for the specified level, or `nil` if the level number is invalid.
function M.get_level_checker(level)
  if level == 1 then
    return M.evaluate_level_1
  elseif level == 2 then
    return M.evaluate_level_2
  elseif level == 3 then
    return M.evaluate_level_3
  elseif level == 4 then
    return M.evaluate_level_4
  elseif level == 5 then
    return M.evaluate_level_5
  else
    get_logger().warn("Invalid quality level requested", { level = level })
    return nil
  end
end

--- Get the requirements for a specific level
---@param level number Quality level (1-5).
---@return QualityRequirements|nil requirements The requirements table (`QualityRequirements`) for the level, or `nil` if the level is invalid.
function M.get_level_requirements(level)
  if level == 1 then
    return {
      min_assertions_per_test = 1,
      assertion_types_required = { "equality", "truth" },
      assertion_types_required_count = 1,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 15,
        require_test_name = true,
      },
      required_patterns = {},
      forbidden_patterns = { "SKIP", "TODO", "FIXME" },
    }
  elseif level == 2 then
    return {
      min_assertions_per_test = 2,
      assertion_types_required = { "equality", "truth", "type_checking" },
      assertion_types_required_count = 2,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 10,
        require_test_name = true,
        require_before_after = false,
      },
      required_patterns = { "should" },
      forbidden_patterns = { "SKIP", "TODO", "FIXME" },
    }
  elseif level == 3 then
    return {
      min_assertions_per_test = 3,
      assertion_types_required = { "equality", "truth", "type_checking", "error_handling", "edge_cases" },
      assertion_types_required_count = 3,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 8,
        require_test_name = true,
        require_before_after = true,
        require_context_nesting = true,
      },
      required_patterns = { "should", "when" },
      forbidden_patterns = { "SKIP", "TODO", "FIXME" },
    }
  elseif level == 4 then
    return {
      min_assertions_per_test = 4,
      assertion_types_required = {
        "equality",
        "truth",
        "type_checking",
        "error_handling",
        "mock_verification",
        "edge_cases",
        "boundary",
      },
      assertion_types_required_count = 4,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 6,
        require_test_name = true,
        require_before_after = true,
        require_context_nesting = true,
        require_mock_verification = true,
      },
      required_patterns = { "should", "when", "boundary" },
      forbidden_patterns = { "SKIP", "TODO", "FIXME" },
    }
  elseif level == 5 then
    return {
      min_assertions_per_test = 5,
      assertion_types_required = {
        "equality",
        "truth",
        "type_checking",
        "error_handling",
        "mock_verification",
        "edge_cases",
        "boundary",
        "performance",
        "security",
      },
      assertion_types_required_count = 5,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 5,
        require_test_name = true,
        require_before_after = true,
        require_context_nesting = true,
        require_mock_verification = true,
        require_coverage_threshold = 90,
        require_performance_tests = true,
        require_security_tests = true,
      },
      required_patterns = { "should", "when", "boundary", "security", "performance" },
      forbidden_patterns = { "SKIP", "TODO", "FIXME" },
    }
  else
    get_logger().warn("Invalid quality level requested", { level = level })
    return nil
  end
end

-- Return the module
return M
